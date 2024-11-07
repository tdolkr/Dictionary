// splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _bgController;
  late Animation<Color?> _backgroundColorAnimation;

  late AnimationController _iconController;
  late Animation<double> _iconScaleAnimation;

  late AnimationController _textController;
  late Animation<Offset> _titleSlideAnimation;
  late Animation<Offset> _subtitleSlideAnimation;

  @override
  void initState() {
    super.initState();

    // Background gradient animation
    _bgController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _backgroundColorAnimation = ColorTween(
      begin: Colors.indigo,
      end: Colors.blueAccent,
    ).animate(_bgController)
      ..addListener(() {
        setState(() {});
      });

    _bgController.repeat(reverse: true);

    // Logo scale animation (bounce effect)
    _iconController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _iconScaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.elasticOut),
    );
    _iconController.repeat(reverse: true);

    // Text slide-in animations
    _textController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _titleSlideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );
    _subtitleSlideAnimation = Tween<Offset>(begin: const Offset(0, 1.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );

    _textController.forward();

    // Navigate to the home screen after the splash screen
    Timer(const Duration(seconds: 4), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DictionaryHomePage()),
      );
    });
  }

  @override
  void dispose() {
    _bgController.dispose();
    _iconController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColorAnimation.value,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _iconScaleAnimation,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Circular loading animation around the icon
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.5)),
                    strokeWidth: 3.5,
                  ),
                  // Icon
                  Icon(Icons.book, size: 80.0, color: Colors.white),
                ],
              ),
            ),
            const SizedBox(height: 20.0),
            SlideTransition(
              position: _titleSlideAnimation,
              child: const Text(
                'ཚིག་མཛོད་',
                style: TextStyle(
                  fontSize: 30.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 10.0),
            SlideTransition(
              position: _subtitleSlideAnimation,
              child: const Text(
                'Learn new words every day!',
                style: TextStyle(
                  fontSize: 16.0,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
