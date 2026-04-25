import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() =>
      _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {

  final businessController =
      TextEditingController();

  final ownerController =
      TextEditingController();

  bool loading = true;
  bool saving = false;

  String email = '';

  String get uid =>
      FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {

    final doc =
      await FirebaseFirestore.instance
        .collection('businesses')
        .doc(uid)
        .get();

    final data = doc.data();

    businessController.text =
        data?['businessName'] ?? '';

    ownerController.text =
        data?['ownerName'] ?? '';

    email = FirebaseAuth
            .instance
            .currentUser
            ?.email ??
        '';

    setState(() {
      loading = false;
    });
  }

  Future<void> saveProfile() async {

    setState(() {
      saving = true;
    });

    await FirebaseFirestore.instance
        .collection('businesses')
        .doc(uid)
        .update({
      'businessName':
          businessController.text.trim(),

      'ownerName':
          ownerController.text.trim(),

      'updatedAt':
          FieldValue.serverTimestamp(),
    });

    setState(() {
      saving = false;
    });

    ScaffoldMessenger.of(context)
      .showSnackBar(
        const SnackBar(
          content:
            Text('Profile Updated'),
        ),
      );
  }

  Future<void> resetPassword() async {

    await FirebaseAuth.instance
      .sendPasswordResetEmail(
        email: email,
      );

    ScaffoldMessenger.of(context)
      .showSnackBar(
        const SnackBar(
          content: Text(
            'Password reset email sent',
          ),
        ),
      );
  }

  Future<void> logoutUser() async {

    final confirm =
      await showDialog<bool>(
        context: context,
        builder: (_) {
          return AlertDialog(
            backgroundColor:
              const Color(0xFF081222),

            shape: RoundedRectangleBorder(
              borderRadius:
                BorderRadius.circular(22),
            ),

            title: const Text(
              "Logout",
              style: TextStyle(
                color: Colors.white,
              ),
            ),

            content: const Text(
              "Are you sure you want to sign out?",
              style: TextStyle(
                color: Color(0xFF8AA7C2),
              ),
            ),

            actions: [

              TextButton(
                onPressed: (){
                  Navigator.pop(
                    context,
                    false,
                  );
                },
                child:
                 const Text("Cancel"),
              ),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                    Colors.redAccent,
                ),
                onPressed: (){
                  Navigator.pop(
                    context,
                    true,
                  );
                },
                child:
                  const Text("Logout"),
              ),
            ],
          );
        },
      );

    if(confirm == true){

      await FirebaseAuth.instance
          .signOut();

      if(!mounted) return;

      Navigator.of(context)
        .pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_)
               => const AuthWrapper(),
          ),
          (route) => false,
      );
    }
  }

  InputDecoration fieldStyle(
    String label,
    IconData icon,
  ) {

    return InputDecoration(
      prefixIcon: Icon(
        icon,
        color:
         const Color(0xFF00D4FF),
      ),

      labelText: label,

      labelStyle: const TextStyle(
        color: Color(0xFF8AA7C2),
      ),

      filled: true,
      fillColor:
         const Color(0xFF081222),

      border: OutlineInputBorder(
        borderRadius:
         BorderRadius.circular(20),
        borderSide:
           BorderSide.none,
      ),
    );
  }

  Widget actionTile(
    IconData icon,
    String title,
    VoidCallback onTap, {
    Color iconColor =
       const Color(0xFF00D4FF),
  }) {

    return Container(
      margin:
       const EdgeInsets.only(
         bottom:14,
       ),

      decoration: BoxDecoration(
        color:
         const Color(0xFF081222),

        borderRadius:
         BorderRadius.circular(22),

        border: Border.all(
          color:
           const Color(0xFF14375C),
        ),
      ),

      child: ListTile(
        leading: Icon(
          icon,
          color: iconColor,
        ),

        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight:
               FontWeight.w600,
          ),
        ),

        trailing: const Icon(
          Icons.chevron_right,
          color:
             Color(0xFF8AA7C2),
        ),

        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    if(loading){
      return const Scaffold(
        backgroundColor:
         Color(0xFF030712),
        body: Center(
          child:
           CircularProgressIndicator(
             color:
              Color(0xFF00D4FF),
           ),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
        const Color(0xFF030712),

      appBar: AppBar(
        backgroundColor:
           Colors.transparent,
        elevation:0,

        title: const Text(
          "Account",
          style: TextStyle(
            color: Colors.white,
          ),
        ),

        iconTheme:
         const IconThemeData(
            color: Colors.white,
         ),
      ),

      body: SingleChildScrollView(
        padding:
         const EdgeInsets.all(20),

        child: Column(
          children: [

            Container(
              padding:
               const EdgeInsets.all(28),

              decoration: BoxDecoration(
                gradient:
                 const LinearGradient(
                   colors:[
                    Color(0xFF071426),
                    Color(0xFF020817),
                   ],
                 ),

                borderRadius:
                  BorderRadius.circular(
                    30,
                  ),

                border: Border.all(
                  color:
                   const Color(0xFF14375C),
                ),
              ),

              child: Column(
                children: [

                  Container(
                    width:90,
                    height:90,

                    decoration:
                     BoxDecoration(
                      borderRadius:
                        BorderRadius.circular(
                           28,
                        ),

                      boxShadow:[
                        BoxShadow(
                          color:
                           const Color(
                             0xFF00D4FF,
                           ).withOpacity(.3),
                          blurRadius:25,
                        )
                      ],
                     ),

                    child: ClipRRect(
                      borderRadius:
                        BorderRadius.circular(
                           28,
                        ),
                      child: Image.asset(
                        'assets/images/deeplink_menu.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height:16,
                  ),

                  Text(
                    businessController.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize:28,
                      fontWeight:
                        FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height:8,
                  ),

                  Text(
                    email,
                    style: const TextStyle(
                      color:
                        Color(0xFF8AA7C2),
                    ),
                  ),

                ],
              ),
            ),

            const SizedBox(
              height:28,
            ),

            Container(
              padding:
                const EdgeInsets.all(22),

              decoration: BoxDecoration(
                color:
                 const Color(0xFF071426),

                borderRadius:
                  BorderRadius.circular(
                    28,
                  ),

                border: Border.all(
                  color:
                   const Color(0xFF14375C),
                ),
              ),

              child: Column(
                children: [

                  TextField(
                    controller:
                      businessController,

                    style:
                     const TextStyle(
                       color: Colors.white,
                     ),

                    decoration:
                     fieldStyle(
                      'Cafe / Hotel Name',
                      Icons.storefront,
                     ),
                  ),

                  const SizedBox(
                    height:18,
                  ),

                  TextField(
                    controller:
                      ownerController,

                    style:
                     const TextStyle(
                      color: Colors.white,
                     ),

                    decoration:
                      fieldStyle(
                       'Owner Name',
                       Icons.person,
                      ),
                  ),

                  const SizedBox(
                    height:24,
                  ),

                  InkWell(
                    onTap:
                      saving
                       ? null
                       : saveProfile,

                    child: Container(
                      width:
                        double.infinity,
                      height:56,

                      decoration:
                        BoxDecoration(
                          borderRadius:
                           BorderRadius.circular(
                              18,
                           ),

                          gradient:
                           const LinearGradient(
                            colors:[
                              Color(0xFF00E5FF),
                              Color(0xFF0057FF),
                            ],
                           ),
                        ),

                      child: Center(
                        child: Text(
                          saving
                           ? "Saving..."
                           : "Save Profile",

                          style:
                           const TextStyle(
                             fontWeight:
                               FontWeight.bold,
                             color:
                               Color(0xFF030712),
                           ),
                        ),
                      ),
                    ),
                  ),

                ],
              ),
            ),

            const SizedBox(
              height:28,
            ),

            actionTile(
              Icons.lock_reset,
              "Reset Password",
              resetPassword,
            ),

            actionTile(
              Icons.logout,
              "Logout",
              logoutUser,
              iconColor:
                 Colors.redAccent,
            ),

            const SizedBox(
              height:20,
            ),

            const Text(
              "POWERED BY DEEPLINK",
              style: TextStyle(
                color:
                 Color(0xFF52677A),
                fontSize:10,
                letterSpacing:3,
              ),
            ),

          ],
        ),
      ),
    );
  }
}