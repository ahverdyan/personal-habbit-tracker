import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'calendar_logic.dart';
import 'habit_model.dart';
import 'app_refresh.dart';
import 'user_stats.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const _pendingNameKey = 'pending_user_name';
  static const _pendingUidKey = 'pending_user_uid';

  Future<void> savePendingRegistration({
    required String uid,
    required String name,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingUidKey, uid);
    await prefs.setString(_pendingNameKey, name);
  }

  Future<void> clearPendingRegistration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingUidKey);
    await prefs.remove(_pendingNameKey);
  }

  Future<void> createUserProfileAfterVerification() async {
    final user = _auth.currentUser;
    if (user == null || !user.emailVerified) return;

    final prefs = await SharedPreferences.getInstance();
    final pendingName = prefs.getString(_pendingNameKey);
    final name = (pendingName != null && pendingName.isNotEmpty)
        ? pendingName
        : (user.displayName ?? 'Пользователь');

    await _firestore.collection('users').doc(user.uid).set({
      'email': user.email,
      'name': name,
      'experience': 0,
      'level': 'beginner',
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await clearPendingRegistration();
  }

  Future<bool> ensureUserProfileExists() async {
    final user = _auth.currentUser;
    if (user == null || !user.emailVerified) return false;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) return true;

    await createUserProfileAfterVerification();
    return true;
  }

  int countCompletedHabits(List<Habit> habits) {
    int count = 0;
    for (final habit in habits) {
      if (CalendarLogic.isCompletedOnDay(habit, habit.scheduledDate)) {
        count++;
      }
    }
    return count;
  }

  Future<UserStats> fetchUserStats(String userId) async {
    final habitsFuture = _firestore
        .collection('habits')
        .where('userId', isEqualTo: userId)
        .get();

    final awardsFuture = _firestore
        .collection('user_achievements')
        .where('userId', isEqualTo: userId)
        .where('isUnlocked', isEqualTo: true)
        .count()
        .get();

    final results = await Future.wait<dynamic>([habitsFuture, awardsFuture]);

    final habitsSnap = results[0] as QuerySnapshot<Map<String, dynamic>>;
    final awardsSnap = results[1] as AggregateQuerySnapshot;

    final habits =
        habitsSnap.docs.map((d) => Habit.fromFirestore(d)).toList();
    final awardsCount = awardsSnap.count;

    return UserStats(
      completedHabits: countCompletedHabits(habits),
      streak: CalendarLogic.calculateStreak(habits),
      awards: awardsCount ?? 0,
    );
  }

  Future<void> resetUserProgress(String userId) async {
    final habitsSnap = await _firestore
        .collection('habits')
        .where('userId', isEqualTo: userId)
        .get();

    final achievementsSnap = await _firestore
        .collection('user_achievements')
        .where('userId', isEqualTo: userId)
        .get();

    final refs = <DocumentReference>[
      ...habitsSnap.docs.map((d) => d.reference),
      ...achievementsSnap.docs.map((d) => d.reference),
    ];

    for (var i = 0; i < refs.length; i += 450) {
      final batch = _firestore.batch();
      final chunk = refs.skip(i).take(450);
      for (final ref in chunk) {
        batch.delete(ref);
      }
      await batch.commit();
    }

    await _firestore.collection('users').doc(userId).set({
      'experience': 0,
      'level': 'beginner',
    }, SetOptions(merge: true));

    AppRefresh.notify();
  }

  Future<void> reauthenticate(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Пользователь не найден',
      );
    }
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await reauthenticate(currentPassword);
    await _auth.currentUser!.updatePassword(newPassword);
  }

  Future<void> changeEmail({
    required String currentPassword,
    required String newEmail,
  }) async {
    await reauthenticate(currentPassword);
    await _auth.currentUser!.verifyBeforeUpdateEmail(newEmail.trim());
  }

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }
}
