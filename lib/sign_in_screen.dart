import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io'; // ← ДОБАВЬ ЭТОТ ИМПОРТ
import 'package:pht/sign_up_screen.dart';
import 'package:pht/main_app_screen.dart';
import 'package:pht/email_verification_screen.dart';
import 'package:pht/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';


class SignInScreen extends StatefulWidget {
  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  String? _emailError;
  String? _passwordError;

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }


  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Поле обязательно для заполнения';
    }

    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Введите корректный email';
    }

    return null;
  }


  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Поле обязательно для заполнения';
    }

    if (value.length < 6) {
      return 'Пароль должен быть не менее 6 символов';
    }

    return null;
  }

  void _signIn() async {
    final emailError = _validateEmail(_emailController.text);
    final passwordError = _validatePassword(_passwordController.text);

    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
      _isLoading = true;
    });

 
    if (emailError != null || passwordError != null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      print(' Пытаемся войти...');

     
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      await credential.user!.reload();
      final user = FirebaseAuth.instance.currentUser;

      if (user != null && !user.emailVerified) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => EmailVerificationScreen()),
        );
        return;
      }

      await UserService().ensureUserProfileExists();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MainAppScreen()),
      );

    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);

      String errorMessage = 'Ошибка входа';

      if (e.code == 'user-not-found') {
        errorMessage = 'Пользователь не найден. Зарегистрируйтесь';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Неверный пароль';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Неверный формат email';
      } else if (e.code == 'user-disabled') {
        errorMessage = 'Аккаунт отключен';
      } else if (e.code == 'too-many-requests') {
        errorMessage = 'Слишком много попыток. Попробуйте позже';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );

    } catch (e) {
      setState(() => _isLoading = false);
      print('Ошибка: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка подключения'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
          child: SingleChildScrollView(
            child: Center(
              child: Column(
                children: [
                  SizedBox(height: 80),
                  _buildIconSignInContainer(),

                  SizedBox(height: 40),
                  _buildTextSignInContainer(),

                  SizedBox(height: 90),
                  _buildMailSignInContainer(),

                  SizedBox(height: 30),
                  _buildPasswordSignInContainer(),

                  SizedBox(height: 80),
                  _isLoading
                      ? CircularProgressIndicator(color: Colors.blueAccent)
                      : _buildButtonSignInContainer(),

                  SizedBox(height: 60),
                  _buildButtonTransitionSignInContainer(),
                ],
              ),
            ),
          )
      ),
    );
  }


  Widget _buildIconSignInContainer() {
    return Container(
      width: 75,
      height: 75,
      child: Image.asset('assets/signin.png'),
    );
  }

  
  Widget _buildTextSignInContainer() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Войти',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent,
              fontSize: 32,
            ),
          ),

          SizedBox(height: 10,),

          Text(
            'Мотивация ничто перед дисциплиной',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

 
  Widget _buildMailSignInContainer() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'Почта',
              hintStyle: TextStyle(color: Colors.grey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _emailError != null ? Colors.red : Colors.white,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _emailError != null ? Colors.red : Colors.purple,
                ),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              errorText: _emailError,
              errorStyle: TextStyle(color: Colors.red),
            ),
            style: TextStyle(color: Colors.black),
            onChanged: (value) {
              if (_emailError != null) {
                setState(() {
                  _emailError = _validateEmail(value);
                });
              }
            },
          ),
        ],
      ),
    );
  }


  Widget _buildPasswordSignInContainer() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              hintText: 'Пароль',
              hintStyle: TextStyle(color: Colors.grey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _passwordError != null ? Colors.red : Colors.white,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _passwordError != null ? Colors.red : Colors.purple,
                ),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey[500],
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              errorText: _passwordError,
              errorStyle: TextStyle(color: Colors.red),
            ),
            style: TextStyle(color: Colors.black),
            onChanged: (value) {
              if (_passwordError != null) {
                setState(() {
                  _passwordError = _validatePassword(value);
                });
              }
            },
          ),
        ],
      ),
    );
  }

  
  Widget _buildButtonSignInContainer() {
    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _signIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          minimumSize: Size(0, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          'Войти',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }


  Widget _buildButtonTransitionSignInContainer() {
    return Container(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Нет аккаунта?',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
            TextButton(
             
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => SignUpScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return FadeTransition(
                        opacity: animation,
                        child: child,
                      );
                    },
                    transitionDuration: Duration(milliseconds: 300),
                  ),
                );
              },
              child: Text(
                'Регистрация',
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        )
    );
  }
}