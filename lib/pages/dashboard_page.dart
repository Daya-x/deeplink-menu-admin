import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'menu_page.dart';
import 'qr_generator_page.dart';
import 'business_settings_page.dart';
import 'profile_page.dart';
import 'auth_page.dart';
import 'subscription_page.dart';
import 'admin_code_generator_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  static const String superAdminUid = 'u8fwPxUGESfVGeeQzuVbpkDSWWi1';

  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;

  void openPage(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => page,
      ),
    );
  }

  Future<void> logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();

      if (!context.mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const AuthWrapper(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Failed to logout. Please try again.'),
        ),
      );
    }
  }

  String getPlanName(String plan) {
    if (plan == 'test_2min') return '2 Minute Test';
    if (plan == 'one_day') return '1 Day Trial';
    if (plan == 'six_months') return '6 Months';
    if (plan == 'one_year') return '1 Year';
    return 'No Plan';
  }

  String formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final uid = currentUid;

    if (uid == null) {
      return const AuthWrapper();
    }

    final isSuperAdmin = uid == superAdminUid;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('businesses')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            backgroundColor: Color(0xFF050B16),
            body: Center(
              child: Text(
                'Failed to load dashboard.',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF050B16),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF00D1FF),
              ),
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const AuthWrapper();
        }

        final data = snapshot.data!.data();
        final businessName = data?['businessName'] ?? 'Business';

        final subscription = data?['subscription'] as Map<String, dynamic>?;

        final plan = subscription?['plan'] ?? 'none';
        final status = subscription?['status'] ?? 'inactive';
        final expiresAt = subscription?['expiresAt'];

        final planName = getPlanName(plan);

        String expiryText = 'Not active';
        int daysLeft = 0;
        bool isExpiringSoon = false;

        if (expiresAt is Timestamp) {
          final expiryDate = expiresAt.toDate();
          daysLeft = expiryDate.difference(DateTime.now()).inDays;
          expiryText = formatDate(expiryDate);
          isExpiringSoon = daysLeft <= 7;
        }

        return Scaffold(
          backgroundColor: const Color(0xFF050B16),
          body: SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: -90,
                  right: -80,
                  child: _GlowCircle(
                    color: const Color(0xFF00D1FF),
                    size: 230,
                  ),
                ),
                Positioned(
                  bottom: -110,
                  left: -90,
                  child: _GlowCircle(
                    color: const Color(0xFF0057FF),
                    size: 260,
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    18,
                    20,
                    30,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00D4FF)
                                      .withOpacity(.28),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.asset(
                                'assets/images/deeplink_menu.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'DeepLink Menu',
                              style: TextStyle(
                                color: Color(0xFFEAF8FF),
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => logout(context),
                            icon: const Icon(
                              Icons.logout_rounded,
                              color: Color(0xFF00D1FF),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF111827),
                              Color(0xFF0A1020),
                            ],
                          ),
                          border: Border.all(
                            color: const Color(0xFF00D1FF).withOpacity(.16),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00D1FF).withOpacity(.14),
                              blurRadius: 38,
                              spreadRadius: 2,
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(.45),
                              blurRadius: 30,
                              offset: const Offset(0, 18),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'WELCOME BACK',
                              style: TextStyle(
                                color: Color(0xFF00D1FF),
                                fontSize: 11,
                                letterSpacing: 3.4,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              businessName,
                              style: const TextStyle(
                                color: Color(0xFFEAF8FF),
                                fontSize: 38,
                                height: 1,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Manage your digital menu, QR code, and business profile from one place.',
                              style: TextStyle(
                                color: Color(0xFF9FB3C8),
                                fontSize: 15,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 22),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isExpiringSoon
                                    ? Colors.orange.withOpacity(.12)
                                    : const Color(0xFF00D1FF)
                                        .withOpacity(.10),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isExpiringSoon
                                      ? Colors.orangeAccent
                                      : const Color(0xFF00D1FF)
                                          .withOpacity(.35),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Subscription: $planName',
                                    style: const TextStyle(
                                      color: Color(0xFFEAF8FF),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Status: $status • Expires: $expiryText',
                                    style: TextStyle(
                                      color: isExpiringSoon
                                          ? Colors.orangeAccent
                                          : const Color(0xFF9FB3C8),
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (expiresAt is Timestamp) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      daysLeft >= 0
                                          ? '$daysLeft days remaining'
                                          : 'Plan expired',
                                      style: TextStyle(
                                        color: isExpiringSoon
                                            ? Colors.orangeAccent
                                            : const Color(0xFF9FB3C8),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                  if (isExpiringSoon) ...[
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Your plan is expiring soon. Please upgrade or renew.',
                                      style: TextStyle(
                                        color: Colors.orangeAccent,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 14),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 44,
                                    child: OutlinedButton.icon(
                                      onPressed: () => openPage(
                                        context,
                                        const SubscriptionPage(),
                                      ),
                                      icon: const Icon(
                                        Icons.upgrade_rounded,
                                        size: 18,
                                      ),
                                      label: const Text(
                                        'Upgrade / Renew Plan',
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            const Color(0xFF00D1FF),
                                        side: const BorderSide(
                                          color: Color(0xFF00D1FF),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        'Quick Actions',
                        style: TextStyle(
                          color: Color(0xFFEAF8FF),
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _GlassActionTile(
                        icon: Icons.menu_book_rounded,
                        title: 'Manage Menu',
                        subtitle: 'Add, edit and update food items',
                        gradient: const [
                          Color(0xFF00E5FF),
                          Color(0xFF0057FF),
                        ],
                        onTap: () => openPage(
                          context,
                          const MenuPage(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _GlassActionTile(
                        icon: Icons.qr_code_2_rounded,
                        title: 'Menu QR Code',
                        subtitle: 'Generate one QR for your digital menu',
                        gradient: const [
                          Color(0xFF131D32),
                          Color(0xFF0B101B),
                        ],
                        onTap: () => openPage(
                          context,
                          const QrGeneratorPage(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _GlassActionTile(
                        icon: Icons.storefront_rounded,
                        title: 'Business Settings',
                        subtitle: 'Social links, logo and cover details',
                        gradient: const [
                          Color(0xFF101A38),
                          Color(0xFF090D16),
                        ],
                        onTap: () => openPage(
                          context,
                          const BusinessSettingsPage(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _GlassActionTile(
                        icon: Icons.person_outline_rounded,
                        title: 'Account Profile',
                        subtitle: 'Business profile and security settings',
                        gradient: const [
                          Color(0xFF101A38),
                          Color(0xFF090D16),
                        ],
                        onTap: () => openPage(
                          context,
                          const ProfilePage(),
                        ),
                      ),

                      if (isSuperAdmin) ...[
                        const SizedBox(height: 14),
                        _GlassActionTile(
                          icon: Icons.admin_panel_settings_rounded,
                          title: 'Admin Code Generator',
                          subtitle: 'Generate payment activation codes',
                          gradient: const [
                            Color(0xFF101A38),
                            Color(0xFF090D16),
                          ],
                          onTap: () => openPage(
                            context,
                            const AdminCodeGeneratorPage(),
                          ),
                        ),
                      ],

                      const SizedBox(height: 36),
                      const Center(
                        child: Column(
                          children: [
                            Text(
                              'POWERED BY',
                              style: TextStyle(
                                color: Color(0xFF52677A),
                                fontSize: 10,
                                letterSpacing: 3,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'DEEPLINK',
                              style: TextStyle(
                                color: Color(0xFF00D1FF),
                                fontSize: 13,
                                letterSpacing: 4,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

class _GlassActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _GlassActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPrimary = gradient.first == const Color(0xFF00E5FF);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            border: Border.all(
              color: isPrimary
                  ? const Color(0xFF00D1FF).withOpacity(.55)
                  : Colors.white.withOpacity(.10),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00D1FF)
                    .withOpacity(isPrimary ? .28 : .14),
                blurRadius: isPrimary ? 32 : 22,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(.4),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPrimary
                      ? Colors.black.withOpacity(.14)
                      : const Color(0xFF00D1FF).withOpacity(.12),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: isPrimary
                      ? const Color(0xFF050B16)
                      : const Color(0xFF00D1FF),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isPrimary
                            ? const Color(0xFF050B16)
                            : const Color(0xFFEAF8FF),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isPrimary
                            ? const Color(0xFF050B16).withOpacity(.65)
                            : const Color(0xFF9FB3C8),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: isPrimary
                    ? const Color(0xFF050B16)
                    : const Color(0xFF00D1FF),
              ),
            ],
          ),
        ),
      ),
    );
  }
}