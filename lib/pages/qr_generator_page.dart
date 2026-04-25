import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrGeneratorPage extends StatelessWidget {
  const QrGeneratorPage({super.key});

  String get uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    final menuUrl =
        'https://deeplink-menu.vercel.app/menu/$uid';

    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Menu QR Code',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(34),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF071426),
                      Color(0xFF020817),
                    ],
                  ),
                  border: Border.all(
                    color: Color(0xFF14375C),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00D4FF).withOpacity(.12),
                      blurRadius: 35,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'CUSTOMER MENU ACCESS',
                      style: TextStyle(
                        color: Color(0xFF00D4FF),
                        fontSize: 11,
                        letterSpacing: 3,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 14),

                    const Text(
                      'Your Menu QR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      'Customers can scan this QR code to open your digital menu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF8AA7C2),
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 30),

                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00D4FF).withOpacity(.25),
                            blurRadius: 35,
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: menuUrl,
                        size: 260,
                        backgroundColor: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 24),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF081222),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF14375C),
                        ),
                      ),
                      child: SelectableText(
                        menuUrl,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF8AA7C2),
                          fontSize: 13,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    InkWell(
                      onTap: () async {
                        await Clipboard.setData(
                          ClipboardData(text: menuUrl),
                        );

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: Color(0xFF00D4FF),
                            content: Text(
                              'Menu link copied',
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF00E5FF),
                              Color(0xFF0057FF),
                            ],
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.copy_rounded,
                              color: Color(0xFF030712),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Copy Menu Link',
                              style: TextStyle(
                                color: Color(0xFF030712),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    const Text(
                      'After deployment, make sure this URL matches your live customer menu domain.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF52677A),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}