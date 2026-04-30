import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_page.dart';

import 'dashboard_page.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  bool loading = false;

  String selectedPlan = '';
  String selectedPlanName = '';
  String selectedAmount = '';

  final codeController = TextEditingController();

  String? get uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void dispose() {
    codeController.dispose();
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

  void selectPlan(String plan, String name, String amount) {
    setState(() {
      selectedPlan = plan;
      selectedPlanName = name;
      selectedAmount = amount;
      codeController.clear();
    });
  }

  DateTime calculateExpiryDate(String plan, DateTime baseDate) {
    if (plan == 'test_2min') {
      return baseDate.add(const Duration(minutes: 2));
    }

    if (plan == 'one_day') {
      return baseDate.add(const Duration(days: 1));
    }

    if (plan == 'six_months') {
      return DateTime(baseDate.year, baseDate.month + 6, baseDate.day);
    }

    if (plan == 'one_year') {
      return DateTime(baseDate.year + 1, baseDate.month, baseDate.day);
    }

    return baseDate;
  }

  Future<void> activateTestPlan() async {
    final userId = uid;

    if (userId == null) {
      showMessage('Session expired. Please login again.');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final businessRef =
          FirebaseFirestore.instance.collection('businesses').doc(userId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final businessDoc = await transaction.get(businessRef);

        if (!businessDoc.exists) {
          throw Exception('business-not-found');
        }

        final newExpiry = DateTime.now().add(const Duration(minutes: 2));

        transaction.update(businessRef, {
          'subscription': {
            'plan': 'test_2min',
            'status': 'active',
            'startedAt': FieldValue.serverTimestamp(),
            'expiresAt': Timestamp.fromDate(newExpiry),
            'lastPaymentId': 'test_mode',
          },
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;

      showMessage('2 minute test plan activated.', success: true);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const DashboardPage(),
        ),
      );
    } catch (e) {
      showMessage('Failed to activate test plan.');
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> activateOneDayTrial() async {
    final userId = uid;

    if (userId == null) {
      showMessage('Session expired. Please login again.');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final businessRef =
          FirebaseFirestore.instance.collection('businesses').doc(userId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final businessDoc = await transaction.get(businessRef);

        if (!businessDoc.exists) {
          throw Exception('business-not-found');
        }

        final businessData = businessDoc.data() as Map<String, dynamic>?;

        if (businessData?['trialUsed'] == true) {
          throw Exception('trial-used');
        }

        final existingSub = businessData?['subscription'];

        if (existingSub != null &&
            existingSub is Map &&
            existingSub['status'] == 'active' &&
            existingSub['expiresAt'] != null &&
            existingSub['expiresAt'] is Timestamp) {
          final currentExpiry =
              (existingSub['expiresAt'] as Timestamp).toDate();

          final currentPlan = existingSub['plan'];

          if (currentExpiry.isAfter(DateTime.now()) &&
              currentPlan != 'one_day') {
            throw Exception('paid-plan-active');
          }
        }

        final newExpiry = DateTime.now().add(const Duration(days: 1));

        transaction.update(businessRef, {
          'trialUsed': true,
          'subscription': {
            'plan': 'one_day',
            'status': 'active',
            'startedAt': FieldValue.serverTimestamp(),
            'expiresAt': Timestamp.fromDate(newExpiry),
            'lastPaymentId': 'free_trial',
          },
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;

      showMessage('1 Day Trial activated.', success: true);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const DashboardPage(),
        ),
      );
    } catch (e) {
      final error = e.toString();

      if (error.contains('trial-used')) {
        showMessage('Free trial already used.');
      } else if (error.contains('paid-plan-active')) {
        showMessage('You already have an active paid subscription.');
      } else {
        showMessage('Failed to activate trial.');
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> openWhatsApp() async {
    if (selectedPlan.isEmpty) {
      showMessage('Please select a plan first.');
      return;
    }

    if (selectedPlan == 'test_2min') {
      showMessage('Test plan is free. Activate it directly.');
      return;
    }

    if (selectedPlan == 'one_day') {
      showMessage('1 Day Trial is free. Activate it directly.');
      return;
    }

    final message =
        'Hi, I paid for DeepLink Menu subscription.\n'
        'Plan: $selectedPlanName\n'
        'Amount: $selectedAmount\n'
        'Bank: Commercial Bank\n'
        'Account No: 8010511554\n'
        'Account Name: Dayalan\n\n'
        'I will send the receipt here. Please send me the confirmation code.';

    final url = Uri.parse(
      'https://wa.me/94769672586?text=${Uri.encodeComponent(message)}',
    );

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      showMessage('Could not open WhatsApp.');
    }
  }

  Future<void> verifyCodeAndActivate() async {
    final userId = uid;
    final enteredCode = codeController.text.trim().toUpperCase();

    if (userId == null) {
      showMessage('Session expired. Please login again.');
      return;
    }

    if (selectedPlan.isEmpty) {
      showMessage('Please select a plan first.');
      return;
    }

    if (selectedPlan == 'test_2min') {
      await activateTestPlan();
      return;
    }

    if (selectedPlan == 'one_day') {
      await activateOneDayTrial();
      return;
    }

    if (enteredCode.isEmpty) {
      showMessage('Enter your confirmation code.');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final codeRef =
          FirebaseFirestore.instance.collection('paymentCodes').doc(enteredCode);

      final businessRef =
          FirebaseFirestore.instance.collection('businesses').doc(userId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final codeDoc = await transaction.get(codeRef);

        if (!codeDoc.exists) {
          throw Exception('invalid-code');
        }

        final codeData = codeDoc.data() as Map<String, dynamic>?;

        if (codeData == null) {
          throw Exception('invalid-code');
        }

        if (codeData['status'] != 'unused') {
          throw Exception('code-used');
        }

        if (codeData['plan'] != selectedPlan) {
          throw Exception('wrong-plan');
        }

        final businessDoc = await transaction.get(businessRef);

        if (!businessDoc.exists) {
          throw Exception('business-not-found');
        }

        final businessData = businessDoc.data() as Map<String, dynamic>?;
        final existingSub = businessData?['subscription'];

        DateTime baseDate = DateTime.now();

        if (existingSub != null &&
            existingSub is Map &&
            existingSub['expiresAt'] != null &&
            existingSub['expiresAt'] is Timestamp) {
          final currentExpiry =
              (existingSub['expiresAt'] as Timestamp).toDate();

          if (currentExpiry.isAfter(DateTime.now())) {
            baseDate = currentExpiry;
          }
        }

        final newExpiry = calculateExpiryDate(selectedPlan, baseDate);

        transaction.update(businessRef, {
          'subscription': {
            'plan': selectedPlan,
            'status': 'active',
            'startedAt': FieldValue.serverTimestamp(),
            'expiresAt': Timestamp.fromDate(newExpiry),
            'lastPaymentId': enteredCode,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        });

        transaction.update(codeRef, {
          'status': 'used',
          'usedBy': userId,
          'usedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;

      showMessage('Subscription activated successfully.', success: true);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const DashboardPage(),
        ),
      );
    } catch (e) {
      final error = e.toString();

      if (error.contains('invalid-code')) {
        showMessage('Invalid confirmation code.');
      } else if (error.contains('code-used')) {
        showMessage('This confirmation code was already used.');
      } else if (error.contains('wrong-plan')) {
        showMessage('This code is not valid for the selected plan.');
      } else {
        showMessage('Failed to activate subscription.');
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Widget planCard({
    required String title,
    required String subtitle,
    required String price,
    required String plan,
    required IconData icon,
  }) {
    final selected = selectedPlan == plan;

    return InkWell(
      onTap: loading ? null : () => selectPlan(plan, title, price),
      borderRadius: BorderRadius.circular(28),
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF09283A) : const Color(0xFF071426),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color:
                selected ? const Color(0xFF00D4FF) : const Color(0xFF14375C),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF00D4FF), size: 36),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFFEAF8FF),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF8AA7C2),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    price,
                    style: const TextStyle(
                      color: Color(0xFF00D4FF),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: Color(0xFF00D4FF)),
          ],
        ),
      ),
    );
  }

  Widget paymentBox() {
    if (selectedPlan.isEmpty) {
      return const SizedBox();
    }

    if (selectedPlan == 'test_2min') {
      return freePlanBox(
        title: '2 Minute Test',
        description: 'For testing only. This plan expires after 2 minutes.',
        buttonText: 'Activate 2 Minute Test',
        onTap: activateTestPlan,
      );
    }

    if (selectedPlan == 'one_day') {
      return freePlanBox(
        title: 'Free Trial',
        description:
            'No payment required. Activate your 1 day trial instantly. This can only be used once.',
        buttonText: 'Activate 1 Day Trial',
        onTap: activateOneDayTrial,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF071426),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFF00D4FF).withOpacity(.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Instructions',
            style: TextStyle(
              color: Color(0xFFEAF8FF),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Selected Plan: $selectedPlanName',
            style: const TextStyle(color: Color(0xFF8AA7C2)),
          ),
          const SizedBox(height: 6),
          Text(
            'Amount: $selectedAmount',
            style: const TextStyle(color: Color(0xFF00D4FF)),
          ),
          const SizedBox(height: 18),
          const Text(
            'Bank: Commercial Bank\n'
            'Account No: 8010511554\n'
            'Account Name: Dayalan',
            style: TextStyle(
              color: Color(0xFFEAF8FF),
              height: 1.6,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: loading ? null : openWhatsApp,
              icon: const Icon(Icons.chat),
              label: const Text('Send Receipt on WhatsApp'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Enter Confirmation Code',
            style: TextStyle(
              color: Color(0xFFEAF8FF),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: codeController,
            enabled: !loading,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: selectedPlan == 'six_months'
                  ? 'Example: DL6M001'
                  : 'Example: DL1Y001',
              hintStyle: const TextStyle(color: Color(0xFF52677A)),
              filled: true,
              fillColor: const Color(0xFF081222),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: loading ? null : verifyCodeAndActivate,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D4FF),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                loading ? 'Checking...' : 'Activate Subscription',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget freePlanBox({
    required String title,
    required String description,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF071426),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFF00D4FF).withOpacity(.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFEAF8FF),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              color: Color(0xFF8AA7C2),
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: loading ? null : onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D4FF),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                loading ? 'Activating...' : buttonText,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030712),
     appBar: AppBar(
  backgroundColor: Colors.transparent,
  elevation: 0,
  title: const Text(
    'Choose Subscription',
    style: TextStyle(color: Colors.white),
  ),
  iconTheme: const IconThemeData(
    color: Colors.white,
  ),
  actions: [
    IconButton(
      onPressed: () async {
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
          (route) => false,
        );
      },
      icon: const Icon(Icons.logout, color: Color(0xFF00D4FF)),
    ),
  ],
),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DeepLink Plans',
              style: TextStyle(
                color: Color(0xFFEAF8FF),
                fontSize: 34,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select a plan. Paid plans require bank transfer, WhatsApp receipt, and confirmation code.',
              style: TextStyle(
                color: Color(0xFF8AA7C2),
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            planCard(
              title: '2 Minute Test',
              subtitle: 'For testing expiry flow only.',
              price: 'FREE',
              plan: 'test_2min',
              icon: Icons.timer_rounded,
            ),
            planCard(
              title: '1 Day Trial',
              subtitle: 'Free instant access for one day. One use only.',
              price: 'Free',
              plan: 'one_day',
              icon: Icons.flash_on_rounded,
            ),
            planCard(
              title: '6 Months',
              subtitle: 'Best for small restaurants starting out.',
              price: 'LKR 4,999',
              plan: 'six_months',
              icon: Icons.calendar_month_rounded,
            ),
            planCard(
              title: '1 Year',
              subtitle: 'Best value for long-term businesses.',
              price: 'LKR 8,999',
              plan: 'one_year',
              icon: Icons.workspace_premium_rounded,
            ),
            const SizedBox(height: 10),
            paymentBox(),
          ],
        ),
      ),
    );
  }
}