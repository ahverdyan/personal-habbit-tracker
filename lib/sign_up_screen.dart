import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pht/sign_in_screen.dart';
import 'email_verification_screen.dart';
import 'user_service.dart';

class SignUpScreen extends StatefulWidget {
  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  bool _isLoading = false;
  String? _nameError;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }


  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите имя';
    }
    if (value.length < 2) {
      return 'Имя слишком короткое';
    }
    return null;
  }


  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите email';
    }
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Неверный формат email';
    }
    return null;
  }

 
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите пароль';
    }
    if (value.length < 6) {
      return 'Пароль должен быть не менее 6 символов';
    }
    return null;
  }


  void _registerUser() async {
    final nameError = _validateName(_nameController.text);
    final emailError = _validateEmail(_emailController.text);
    final passwordError = _validatePassword(_passwordController.text);

    setState(() {
      _nameError = nameError;
      _emailError = emailError;
      _passwordError = passwordError;
      _isLoading = true;
    });

    if (nameError != null || emailError != null || passwordError != null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      print(' Начинаем регистрацию...');

    
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final userId = credential.user!.uid;
      final userEmail = credential.user!.email;

      print('Пользователь создан в Auth!');
      print('Email: $userEmail');
      print('UID: $userId');

      await UserService().savePendingRegistration(
        uid: userId,
        name: _nameController.text.trim(),
      );

      await UserService().sendEmailVerification();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => EmailVerificationScreen()),
      );

    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);

      print(' Ошибка Firebase Auth: ${e.code}');

      String errorMessage = 'Ошибка регистрации';

      if (e.code == 'email-already-in-use') {
        errorMessage = 'Этот email уже зарегистрирован';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Неверный формат email';
      } else if (e.code == 'operation-not-allowed') {
        errorMessage = 'Регистрация отключена';
      } else if (e.code == 'weak-password') {
        errorMessage = 'Слишком слабый пароль';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );

    } catch (e) {
      setState(() => _isLoading = false);
      print('Неизвестная ошибка: $e');

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
                  _buildIconSignUpContainer(),

                  SizedBox(height: 40),
                  _buildTextSignUpContainer(),

                  SizedBox(height: 60),
                  _buildNameSignUpContainer(),

                  SizedBox(height: 30),
                  _buildMailSignUpContainer(),

                  SizedBox(height: 30),
                  _buildPasswordSignUpContainer(),

                  // 📝 СООБЩЕНИЯ ОБ ОШИБКАХ
                  SizedBox(height: 20),
                  _buildErrorMessagesContainer(),

                  SizedBox(height: 40),
                  _isLoading
                      ? CircularProgressIndicator(color: Colors.blueAccent)
                      : _buildButtonSignUpContainer(),

                  SizedBox(height: 60),
                  _buildButtonTransitionSignUpContainer(),
                ],
              ),
            ),
          )
      ),
    );
  }


  Widget _buildIconSignUpContainer() {
    return Container(
      width: 75,
      height: 75,
      child: Image.asset('assets/signup.png'),
    );
  }


  Widget _buildTextSignUpContainer() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Регистрация',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent,
              fontSize: 32,
            ),
          ),

          SizedBox(height: 10,),

          Text(
            'Получи возможность стать лучше, чем вчера',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildNameSignUpContainer() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            keyboardType: TextInputType.name,
            decoration: InputDecoration(
              hintText: 'Придумайте никнейм',
              hintStyle: TextStyle(color: Colors.grey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _nameError != null ? Colors.red : Colors.white,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _nameError != null ? Colors.red : Colors.purple,
                ),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              errorText: _nameError,
              errorStyle: TextStyle(color: Colors.red),
            ),
            style: TextStyle(color: Colors.black),
            onChanged: (value) {
              if (_nameError != null) {
                setState(() {
                  _nameError = _validateName(value);
                });
              }
            },
          ),
        ],
      ),
    );
  }


  Widget _buildMailSignUpContainer() {
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
              hintText: 'Ваша почта',
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


  Widget _buildPasswordSignUpContainer() {
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
              hintText: 'Придумайте пароль',
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


  Widget _buildErrorMessagesContainer() {
    List<Widget> errorWidgets = [];

    if (_nameError != null) {
      errorWidgets.add(
          Text('❌ $_nameError', style: TextStyle(color: Colors.red, fontSize: 14))
      );
    }
    if (_emailError != null) {
      errorWidgets.add(
          Text('❌ $_emailError', style: TextStyle(color: Colors.red, fontSize: 14))
      );
    }
    if (_passwordError != null) {
      errorWidgets.add(
          Text('❌ $_passwordError', style: TextStyle(color: Colors.red, fontSize: 14))
      );
    }

    if (errorWidgets.isEmpty) return SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: errorWidgets,
      ),
    );
  }

  Widget _buildButtonSignUpContainer() {
    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _registerUser,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          minimumSize: Size(0, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          'Зарегистрироваться',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildButtonTransitionSignUpContainer() {
    return Container(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Уже есть аккаунт?',
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
                    pageBuilder: (context, animation, secondaryAnimation) => SignInScreen(),
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
                'Войти',
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