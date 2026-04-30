import 'dart:math';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class AdminCodeGeneratorPage extends StatefulWidget {
  const AdminCodeGeneratorPage({super.key});

  @override
  State<AdminCodeGeneratorPage> createState() => _AdminCodeGeneratorPageState();
}

class _AdminCodeGeneratorPageState extends State<AdminCodeGeneratorPage> {
  static const String superAdminUid = 'u8fwPxUGESfVGeeQzuVbpkDSWWi1';

  String selectedPlan = 'six_months';
  bool loading = false;
  String generatedCode = '';

  String? get uid => FirebaseAuth.instance.currentUser?.uid;

  void showMessage(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: success ? const Color(0xFF00D4FF) : Colors.redAccent,
        content: Text(
          message,
          style: TextStyle(color: success ? Colors.black : Colors.white),
        ),
      ),
    );
  }

  String generateCode() {
    final random = Random();
    final number = random.nextInt(9000) + 1000;

    if (selectedPlan == 'six_months') {
      return 'DL6M$number';
    }

    return 'DL1Y$number';
  }

  Future<void> createCode() async {
    if (uid != superAdminUid) {
      showMessage('Access denied.');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      String code = generateCode();

      final codeRef =
          FirebaseFirestore.instance.collection('paymentCodes').doc(code);

      final exists = await codeRef.get();

      if (exists.exists) {
        code = generateCode();
      }

      await FirebaseFirestore.instance.collection('paymentCodes').doc(code).set({
        'plan': selectedPlan,
        'status': 'unused',
        'createdAt': FieldValue.serverTimestamp(),
        'usedBy': '',
        'usedAt': null,
      });

      setState(() {
        generatedCode = code;
      });

      showMessage('Code generated successfully.', success: true);
    } catch (e) {
      showMessage('Failed to generate code.');
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void copyCode() {
    if (generatedCode.isEmpty) return;

    Clipboard.setData(
      ClipboardData(text: generatedCode),
    );

    showMessage('Code copied.', success: true);
  }

  String planLabel(String plan) {
    if (plan == 'six_months') return '6 Months';
    if (plan == 'one_year') return '1 Year';
    return plan;
  }

  @override
  Widget build(BuildContext context) {
    if (uid != superAdminUid) {
      return const Scaffold(
        backgroundColor: Color(0xFF030712),
        body: Center(
          child: Text(
            'Access denied',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'Code Generator',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Generate Payment Code',
              style: TextStyle(
                color: Color(0xFFEAF8FF),
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Use this after confirming customer bank payment.',
              style: TextStyle(
                color: Color(0xFF8AA7C2),
              ),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF071426),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0xFF14375C)),
              ),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedPlan,
                    dropdownColor: const Color(0xFF071426),
                    decoration: InputDecoration(
                      labelText: 'Select Plan',
                      labelStyle: const TextStyle(color: Color(0xFF8AA7C2)),
                      filled: true,
                      fillColor: const Color(0xFF081222),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                    items: const [
                      DropdownMenuItem(
                        value: 'six_months',
                        child: Text('6 Months'),
                      ),
                      DropdownMenuItem(
                        value: 'one_year',
                        child: Text('1 Year'),
                      ),
                    ],
                    onChanged: loading
                        ? null
                        : (value) {
                            if (value == null) return;

                            setState(() {
                              selectedPlan = value;
                              generatedCode = '';
                            });
                          },
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: loading ? null : createCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00D4FF),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        loading ? 'Generating...' : 'Generate Code',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (generatedCode.isNotEmpty) ...[
              const SizedBox(height: 26),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFF09283A),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: const Color(0xFF00D4FF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      planLabel(selectedPlan),
                      style: const TextStyle(
                        color: Color(0xFF8AA7C2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF071426),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFF00D4FF).withOpacity(.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              generatedCode,
                              style: const TextStyle(
                                color: Color(0xFF00D4FF),
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: copyCode,
                            icon: const Icon(
                              Icons.copy_rounded,
                              color: Color(0xFF00D4FF),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Copy this code and send it to the customer on WhatsApp.',
                      style: TextStyle(color: Color(0xFF8AA7C2)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}