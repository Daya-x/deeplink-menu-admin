import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'dashboard_page.dart';
import 'subscription_page.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  static const String superAdminUid = 'u8fwPxUGESfVGeeQzuVbpkDSWWi1';

  bool isSubscriptionActive(Map<String, dynamic> data) {
    final subscription = data['subscription'];

    if (subscription == null || subscription is! Map) {
      return false;
    }

    final status = subscription['status'];
    final expiresAt = subscription['expiresAt'];

    if (status != 'active') {
      return false;
    }

    if (expiresAt == null || expiresAt is! Timestamp) {
      return false;
    }

    return expiresAt.toDate().isAfter(DateTime.now());
  }

  Future<void> markExpiredIfNeeded(
    DocumentReference<Map<String, dynamic>> businessRef,
    Map<String, dynamic> data,
  ) async {
    final subscription = data['subscription'];

    if (subscription == null || subscription is! Map) return;

    final expiresAt = subscription['expiresAt'];

    if (expiresAt is Timestamp) {
      final expiryDate = expiresAt.toDate();

      if (DateTime.now().isAfter(expiryDate)) {
        await businessRef.update({
          'subscription.status': 'expired',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        final user = authSnapshot.data;

        if (user == null) {
          return const AuthPage();
        }

        if (user.uid == superAdminUid) {
          return const DashboardPage();
        }

        final businessRef =
            FirebaseFirestore.instance.collection('businesses').doc(user.uid);

        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: businessRef.get(),
          builder: (context, businessSnapshot) {
            if (businessSnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingScreen();
            }

            if (businessSnapshot.hasError) {
              FirebaseAuth.instance.signOut();
              return const AuthPage();
            }

            if (!businessSnapshot.hasData || !businessSnapshot.data!.exists) {
              FirebaseAuth.instance.signOut();
              return const AuthPage();
            }

            final businessData = businessSnapshot.data!.data();

            if (businessData == null) {
              FirebaseAuth.instance.signOut();
              return const AuthPage();
            }

            final active = isSubscriptionActive(businessData);

            if (!active) {
              markExpiredIfNeeded(businessRef, businessData);
              return const SubscriptionPage();
            }

            return const DashboardPage();
          },
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF030712),
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFF00D4FF),
        ),
      ),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool isLogin = true;
  bool loading = false;
  bool obscurePassword = true;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final businessController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    businessController.dispose();
    super.dispose();
  }

  void showMessage(String message, {bool success = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: success ? const Color(0xFF00D4FF) : Colors.redAccent,
        content: Text(
          message,
          style: TextStyle(
            color: success ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }

  String getFirebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }

  bool validateInputs() {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final businessName = businessController.text.trim();

    if (!isLogin && businessName.isEmpty) {
      showMessage('Please enter your cafe / hotel name.');
      return false;
    }

    if (email.isEmpty) {
      showMessage('Please enter your email address.');
      return false;
    }

    if (!email.contains('@')) {
      showMessage('Please enter a valid email address.');
      return false;
    }

    if (password.isEmpty) {
      showMessage('Please enter your password.');
      return false;
    }

    if (!isLogin && password.length < 6) {
      showMessage('Password should be at least 6 characters.');
      return false;
    }

    return true;
  }

  Future<void> submit() async {
    if (!validateInputs()) return;

    setState(() {
      loading = true;
    });

    try {
      final email = emailController.text.trim();
      final password = passwordController.text.trim();
      final businessName = businessController.text.trim();

      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        final userCredential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        final user = userCredential.user;

        if (user == null) {
          throw FirebaseAuthException(
            code: 'user-null',
            message: 'Account created, but user data was not found.',
          );
        }

        await FirebaseFirestore.instance
            .collection('businesses')
            .doc(user.uid)
            .set({
          'businessName': businessName,
          'email': email,
          'ownerName': '',
          'logoUrl': '',
          'coverUrl': '',
          'facebookUrl': '',
          'instagramUrl': '',
          'tiktokUrl': '',
          'googleReviewUrl': '',
          'trialUsed': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseAuthException catch (e) {
      showMessage(getFirebaseErrorMessage(e));
    } catch (e) {
      showMessage('Something went wrong. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> resetPassword() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      showMessage('Enter your email first.');
      return;
    }

    if (!email.contains('@')) {
      showMessage('Please enter a valid email address.');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      showMessage('Password reset email sent.', success: true);
    } on FirebaseAuthException catch (e) {
      showMessage(getFirebaseErrorMessage(e));
    } catch (e) {
      showMessage('Something went wrong. Please try again.');
    }
  }

  InputDecoration fieldDecoration(String label, IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(
        icon,
        color: const Color(0xFF00D4FF),
      ),
      labelText: label,
      labelStyle: const TextStyle(
        color: Color(0xFF8AA7C2),
      ),
      filled: true,
      fillColor: const Color(0xFF081222),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(
          color: Color(0xFF133354),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(
          color: Color(0xFF133354),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(
          color: Color(0xFF00D4FF),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -90,
              right: -90,
              child: _GlowCircle(
                color: const Color(0xFF00D4FF),
                size: 240,
              ),
            ),
            Positioned(
              bottom: -120,
              left: -100,
              child: _GlowCircle(
                color: const Color(0xFF0057FF),
                size: 270,
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 430,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(26),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(34),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF071426),
                          Color(0xFF020817),
                        ],
                      ),
                      border: Border.all(
                        color: const Color(0xFF14375C),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00D4FF).withOpacity(.10),
                          blurRadius: 35,
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    const Color(0xFF00D4FF).withOpacity(.30),
                                blurRadius: 28,
                              )
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.asset(
                              'assets/images/deeplink_menu.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          "DEEPLINK",
                          style: TextStyle(
                            color: Color(0xFF00D4FF),
                            fontSize: 12,
                            letterSpacing: 4,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isLogin ? "Welcome Back" : "Create Account",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFEAF8FF),
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isLogin
                              ? "Manage your restaurant digitally."
                              : "Launch your premium digital menu.",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF8AA7C2),
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 30),
                        if (!isLogin) ...[
                          TextField(
                            controller: businessController,
                            style: const TextStyle(
                              color: Colors.white,
                            ),
                            decoration: fieldDecoration(
                              'Cafe / Hotel Name',
                              Icons.storefront,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(
                            color: Colors.white,
                          ),
                          decoration: fieldDecoration(
                            'Email Address',
                            Icons.email,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: passwordController,
                          obscureText: obscurePassword,
                          style: const TextStyle(
                            color: Colors.white,
                          ),
                          decoration: fieldDecoration(
                            'Password',
                            Icons.lock,
                          ).copyWith(
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  obscurePassword = !obscurePassword;
                                });
                              },
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: const Color(0xFF8AA7C2),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (isLogin)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: loading ? null : resetPassword,
                              child: const Text(
                                "Forgot Password?",
                                style: TextStyle(
                                  color: Color(0xFF00D4FF),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                        _GradientButton(
                          text: loading
                              ? "Please wait..."
                              : isLogin
                                  ? "Sign In"
                                  : "Create Business Account",
                          icon: isLogin ? Icons.login : Icons.rocket_launch,
                          onTap: loading ? null : submit,
                        ),
                        const SizedBox(height: 22),
                        TextButton(
                          onPressed: loading
                              ? null
                              : () {
                                  setState(() {
                                    isLogin = !isLogin;
                                  });
                                },
                          child: Text(
                            isLogin
                                ? "Don't have an account? Create one"
                                : "Already have an account? Sign in",
                            style: const TextStyle(
                              color: Color(0xFF00D4FF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          "POWERED BY DEEPLINK",
                          style: TextStyle(
                            color: Color(0xFF52677A),
                            fontSize: 10,
                            letterSpacing: 3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
          )
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback? onTap;

  const _GradientButton({
    required this.text,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? .55 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF00E5FF),
                Color(0xFF0057FF),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00D4FF).withOpacity(.28),
                blurRadius: 25,
              )
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: const Color(0xFF030712),
              ),
              const SizedBox(width: 10),
              Text(
                text,
                style: const TextStyle(
                  color: Color(0xFF030712),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}