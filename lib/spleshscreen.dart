import 'package:flutter/material.dart';
import 'package:pht/sign_in_screen.dart';
import 'package:pht/main_app_screen.dart';
import 'package:pht/auth_sign.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ⏰ ЭКРАН ЗАГРУЗКИ (SPLASH SCREEN)
class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  _navigateToHome() async {
    await Future.delayed(Duration(seconds: 2));

    final user = FirebaseAuth.instance.currentUser;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
        user != null ? MainAppScreen() : SignInScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/splesh.png'),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}