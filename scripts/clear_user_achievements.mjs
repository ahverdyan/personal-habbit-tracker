/**
 * Полная очистка коллекции user_achievements в Firestore.
 *
 * Требуется ключ сервисного аккаунта Firebase Admin:
 * Firebase Console → Project Settings → Service accounts → Generate new private key
 *
 * Запуск:
 *   node scripts/clear_user_achievements.mjs --yes
 *   node scripts/clear_user_achievements.mjs --yes path/to/service-account.json
 *
 * Или переменная окружения:
 *   set GOOGLE_APPLICATION_CREDENTIALS=path\to\service-account.json
 */

import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import https from 'https';
import { fileURLToPath } from 'url';

const PROJECT_ID = 'phtb-336e3';
const COLLECTION = 'user_achievements';
const DATABASE = '(default)';
const BATCH_SIZE = 400;

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function parseArgs() {
  const args = process.argv.slice(2);
  const confirmed = args.includes('--yes') || args.includes('-y');
  const credPath = args.find((a) => !a.startsWith('-'));
  return { confirmed, credPath };
}

function resolveCredentialsPath(explicitPath) {
  const candidates = [
    explicitPath,
    process.env.GOOGLE_APPLICATION_CREDENTIALS,
    path.join(__dirname, 'service-account.json'),
    path.join(__dirname, 'firebase-service-account.json'),
  ].filter(Boolean);

  for (const candidate of candidates) {
    const resolved = path.resolve(candidate);
    if (fs.existsSync(resolved)) return resolved;
  }
  return null;
}

function base64url(input) {
  return Buffer.from(input)
    .toString('base64')
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');
}

function createSignedJwt(serviceAccount) {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const payload = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
    scope: 'https://www.googleapis.com/auth/datastore',
  };

  const unsigned = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(payload))}`;
  const sign = crypto.createSign('RSA-SHA256');
  sign.update(unsigned);
  sign.end();
  const signature = sign
    .sign(serviceAccount.private_key)
    .toString('base64')
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');

  return `${unsigned}.${signature}`;
}

function httpsRequest(options, body = null) {
  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          try {
            resolve(data ? JSON.parse(data) : {});
          } catch {
            resolve(data);
          }
        } else {
          reject(
            new Error(
              `HTTP ${res.statusCode}: ${data || res.statusMessage}`,
            ),
          );
        }
      });
    });
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

async function getAccessToken(serviceAccount) {
  const assertion = createSignedJwt(serviceAccount);
  const body = new URLSearchParams({
    grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
    assertion,
  }).toString();

  const response = await httpsRequest(
    {
      hostname: 'oauth2.googleapis.com',
      path: '/token',
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(body),
      },
    },
    body,
  );

  return response.access_token;
}

async function listAllDocuments(accessToken) {
  const documents = [];
  let pageToken = '';

  do {
    const query = new URLSearchParams({ pageSize: '500' });
    if (pageToken) query.set('pageToken', pageToken);

    const path = `/v1/projects/${PROJECT_ID}/databases/${DATABASE}/documents/${COLLECTION}?${query}`;

    const response = await httpsRequest({
      hostname: 'firestore.googleapis.com',
      path,
      method: 'GET',
      headers: { Authorization: `Bearer ${accessToken}` },
    });

    if (response.documents) documents.push(...response.documents);
    pageToken = response.nextPageToken || '';
  } while (pageToken);

  return documents;
}

async function batchDelete(accessToken, docNames) {
  const writes = docNames.map((name) => ({ delete: name }));
  const body = JSON.stringify({ writes });

  await httpsRequest(
    {
      hostname: 'firestore.googleapis.com',
      path: `/v1/projects/${PROJECT_ID}/databases/${DATABASE}/documents:batchWrite`,
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body),
      },
    },
    body,
  );
}

async function main() {
  const { confirmed, credPath } = parseArgs();

  if (!confirmed) {
    console.error(
      'Добавьте флаг --yes для подтверждения удаления ВСЕХ документов из user_achievements.',
    );
    console.error('Пример: node scripts/clear_user_achievements.mjs --yes');
    process.exit(1);
  }

  const credentialsPath = resolveCredentialsPath(credPath);
  if (!credentialsPath) {
    console.error('Не найден ключ сервисного аккаунта.');
    console.error('Положите JSON в один из путей:');
    console.error(`  ${path.join(__dirname, 'service-account.json')}`);
    console.error('  или укажите путь аргументом / GOOGLE_APPLICATION_CREDENTIALS');
    console.error('');
    console.error('Скачать ключ: Firebase Console → phtb-336e3 →');
    console.error('Project settings → Service accounts → Generate new private key');
    process.exit(1);
  }

  const serviceAccount = JSON.parse(fs.readFileSync(credentialsPath, 'utf8'));
  console.log(`Проект: ${PROJECT_ID}`);
  console.log(`Коллекция: ${COLLECTION}`);
  console.log(`Ключ: ${credentialsPath}`);
  console.log('Получение токена...');

  const accessToken = await getAccessToken(serviceAccount);
  console.log('Чтение документов...');

  const documents = await listAllDocuments(accessToken);
  const total = documents.length;

  if (total === 0) {
    console.log('Коллекция уже пуста (0 документов).');
    return;
  }

  console.log(`Найдено документов: ${total}. Удаление...`);

  const names = documents.map((d) => d.name);
  let deleted = 0;

  for (let i = 0; i < names.length; i += BATCH_SIZE) {
    const chunk = names.slice(i, i + BATCH_SIZE);
    await batchDelete(accessToken, chunk);
    deleted += chunk.length;
    console.log(`  удалено ${deleted} / ${total}`);
  }

  const remaining = await listAllDocuments(accessToken);
  console.log('');
  console.log(`Готово. Удалено: ${deleted}. Осталось в коллекции: ${remaining.length}`);
}

main().catch((err) => {
  console.error('Ошибка:', err.message);
  process.exit(1);
});
