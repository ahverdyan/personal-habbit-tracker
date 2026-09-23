import 'package:shared_preferences/shared_preferences.dart';

class AuthManager {
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _userNameKey = 'user_name';

  static Future<void> saveLoginState(bool isLoggedIn, {String? userName}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, isLoggedIn);

    if (userName != null) {
      await prefs.setString(_userNameKey, userName);
    }
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userNameKey);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, false);
  }
}