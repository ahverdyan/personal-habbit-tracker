import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_service.dart';
import 'app_refresh.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final UserService _userService = UserService();

  bool _isLoading = true;
  bool _statsLoading = true;
  String _email = '';
  int _habitsCount = 0;
  int _streak = 0;
  int _awards = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    _email = user.email ?? '';

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 8));

      if (doc.exists && mounted) {
        final data = doc.data();
        _nameController.text = data?['name'] ?? '';
      }
    } catch (e) {
      print('Профиль: не удалось загрузить имя: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }

    _loadStats(user.uid);
    UserService().ensureUserProfileExists();
  }

  Future<void> _loadStats(String userId) async {
    try {
      final stats = await _userService
          .fetchUserStats(userId)
          .timeout(const Duration(seconds: 10));

      if (mounted) {
        setState(() {
          _habitsCount = stats.completedHabits;
          _streak = stats.streak;
          _awards = stats.awards;
          _statsLoading = false;
        });
      }
    } catch (e) {
      print('Ошибка загрузки статистики: $e');
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': _nameController.text.trim(),
        'email': _email,
      }, SetOptions(merge: true));

      if (mounted) {
        AppRefresh.notifyProfile();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Профиль обновлён'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, _nameController.text.trim());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка сохранения'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showChangePasswordDialog() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Сменить пароль'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentCtrl,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Текущий пароль'),
              ),
              TextField(
                controller: newCtrl,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Новый пароль'),
              ),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Повторите пароль'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              if (newCtrl.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Пароль не менее 6 символов'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              if (newCtrl.text != confirmCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Пароли не совпадают'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              try {
                await _userService.changePassword(
                  currentPassword: currentCtrl.text,
                  newPassword: newCtrl.text,
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Пароль изменён'),
                    backgroundColor: Colors.green,
                  ),
                );
              } on FirebaseAuthException catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_authErrorMessage(e)),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showChangeEmailDialog() {
    final passwordCtrl = TextEditingController();
    final emailCtrl = TextEditingController(text: _email);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Сменить почту'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: 'Новый email'),
              ),
              SizedBox(height: 12),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Текущий пароль'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _userService.changeEmail(
                  currentPassword: passwordCtrl.text,
                  newEmail: emailCtrl.text.trim(),
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Письмо отправлено на новый email'),
                    backgroundColor: Colors.green,
                  ),
                );
              } on FirebaseAuthException catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_authErrorMessage(e)),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('Отправить'),
          ),
        ],
      ),
    );
  }

  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Неверный пароль';
      case 'requires-recent-login':
        return 'Войдите снова и повторите попытку';
      case 'email-already-in-use':
        return 'Этот email уже занят';
      case 'invalid-email':
        return 'Неверный формат email';
      default:
        return e.message ?? 'Ошибка авторизации';
    }
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 5),
            )
          ],
        ),
        child: Column(
          children: [
            Text(
              _statsLoading ? '…' : value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 5),
            Text(title, style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text('Профиль', style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.purple))
          : Container(
              margin: EdgeInsets.only(top: 20),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 45,
                      backgroundColor: Colors.purple,
                      child: Icon(Icons.person, color: Colors.white, size: 45),
                    ),
                    SizedBox(height: 10),
                    Text(
                      _nameController.text.isEmpty
                          ? 'Пользователь'
                          : _nameController.text,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(_email, style: TextStyle(color: Colors.grey)),
                    SizedBox(height: 25),
                    Row(
                      children: [
                        _buildStatCard(
                          'Выполнено',
                          '$_habitsCount',
                          Colors.purple,
                        ),
                        SizedBox(width: 10),
                        _buildStatCard(
                          'Стрик',
                          '$_streak 🔥',
                          Colors.orange,
                        ),
                        SizedBox(width: 10),
                        _buildStatCard(
                          'Наград',
                          '$_awards 🏆',
                          Colors.green,
                        ),
                      ],
                    ),
                    SizedBox(height: 30),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Имя',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                    SizedBox(height: 25),
                    Container(
                      padding: EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(Icons.lock_outline,
                                color: Colors.purple),
                            title: Text('Сменить пароль'),
                            trailing: Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: _showChangePasswordDialog,
                          ),
                          Divider(),
                          ListTile(
                            leading:
                                Icon(Icons.email_outlined, color: Colors.blue),
                            title: Text('Сменить почту'),
                            trailing: Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: _showChangeEmailDialog,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 60),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: Text(
                          'Сохранить',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
