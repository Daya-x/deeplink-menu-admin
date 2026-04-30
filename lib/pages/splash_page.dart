import 'dart:async';
import 'package:flutter/material.dart';
import 'auth_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _timer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const AuthWrapper(),
        ),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      body: Stack(
        children: [
          Positioned(
            top: -90,
            right: -80,
            child: _GlowCircle(
              color: const Color(0xFF00D4FF),
              size: 240,
            ),
          ),
          Positioned(
            bottom: -120,
            left: -90,
            child: _GlowCircle(
              color: const Color(0xFF0057FF),
              size: 270,
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 125,
                  height: 125,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(34),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00D4FF).withOpacity(.35),
                        blurRadius: 40,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset(
                      'assets/images/deeplink_menu.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                const SizedBox(height: 26),

                const Text(
                  'DeepLink',
                  style: TextStyle(
                    color: Color(0xFFEAF8FF),
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.4,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'RESTAURANT OS',
                  style: TextStyle(
                    color: Color(0xFF00D4FF),
                    fontSize: 12,
                    letterSpacing: 4,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 36),

                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF00D4FF),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowCircle({
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(.18),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(.30),
            blurRadius: 120,
            spreadRadius: 55,
          ),
        ],
      ),
    );
  }
}