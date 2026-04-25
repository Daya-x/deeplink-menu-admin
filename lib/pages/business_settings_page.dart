import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BusinessSettingsPage extends StatefulWidget {
  const BusinessSettingsPage({super.key});

  @override
  State<BusinessSettingsPage> createState() =>
      _BusinessSettingsPageState();
}

class _BusinessSettingsPageState
    extends State<BusinessSettingsPage> {

  final facebookController = TextEditingController();
  final instagramController = TextEditingController();
  final tiktokController = TextEditingController();
  final googleController = TextEditingController();

  Uint8List? selectedLogo;
  Uint8List? selectedCover;

  String logoUrl = '';
  String coverUrl = '';

  bool loading = true;
  bool saving = false;

  String get uid =>
      FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    loadBusiness();
  }

  Future<void> loadBusiness() async {
    final doc = await FirebaseFirestore.instance
        .collection('businesses')
        .doc(uid)
        .get();

    final data = doc.data();

    facebookController.text =
        data?['facebookUrl'] ?? '';

    instagramController.text =
        data?['instagramUrl'] ?? '';

    tiktokController.text =
        data?['tiktokUrl'] ?? '';

    googleController.text =
        data?['googleReviewUrl'] ?? '';

    logoUrl = data?['logoUrl'] ?? '';
    coverUrl = data?['coverUrl'] ?? '';

    setState(() {
      loading = false;
    });
  }

  Future<void> pickLogo() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );

    if (file != null) {
      selectedLogo = await file.readAsBytes();
      setState(() {});
    }
  }

  Future<void> pickCover() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );

    if (file != null) {
      selectedCover = await file.readAsBytes();
      setState(() {});
    }
  }

  Future<String> uploadImage(
      Uint8List bytes) async {

    final req = http.MultipartRequest(
      'POST',
      Uri.parse(
        'https://api.cloudinary.com/v1_1/dbe63rr9s/image/upload',
      ),
    );

    req.fields['upload_preset'] =
        'deeplink_menu';

    req.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: 'upload.jpg',
      ),
    );

    final res = await req.send();

    final body =
        await res.stream.bytesToString();

    return jsonDecode(body)['secure_url'];
  }

  Future<void> saveAll() async {
    setState(() {
      saving = true;
    });

    String finalLogo = logoUrl;
    String finalCover = coverUrl;

    if (selectedLogo != null) {
      finalLogo =
          await uploadImage(selectedLogo!);
    }

    if (selectedCover != null) {
      finalCover =
          await uploadImage(selectedCover!);
    }

    await FirebaseFirestore.instance
        .collection('businesses')
        .doc(uid)
        .update({
      'logoUrl': finalLogo,
      'coverUrl': finalCover,
      'facebookUrl':
          facebookController.text.trim(),
      'instagramUrl':
          instagramController.text.trim(),
      'tiktokUrl':
          tiktokController.text.trim(),
      'googleReviewUrl':
          googleController.text.trim(),
      'updatedAt':
          FieldValue.serverTimestamp(),
    });

    setState(() {
      saving = false;
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xff00D4FF),
        content: Text(
          'Business settings updated',
          style: TextStyle(
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  Widget socialField(
      String label,
      IconData icon,
      TextEditingController controller) {
    return Container(
      margin:
          const EdgeInsets.only(bottom:16),
      decoration: BoxDecoration(
        color: const Color(0xff081222),
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xff133354),
        ),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(
          color: Colors.white,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: Icon(
            icon,
            color:
                const Color(0xff00D4FF),
          ),
          labelText: label,
          labelStyle: const TextStyle(
            color: Color(0xff8AA7C2),
          ),
          contentPadding:
              const EdgeInsets.all(22),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    if (loading) {
      return const Scaffold(
        backgroundColor: Color(0xff030712),
        body: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          const Color(0xff030712),

      appBar: AppBar(
        backgroundColor:
            const Color(0xff02060E),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Business Settings",
          style: TextStyle(
            color: Color(0xff00D4FF),
            fontWeight:
                FontWeight.w600,
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding:
            const EdgeInsets.all(22),
        child: Column(
          children: [

            Container(
              padding:
                  const EdgeInsets.all(26),
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(
                        34),
                gradient:
                    const LinearGradient(
                  colors: [
                    Color(0xff071426),
                    Color(0xff020817),
                  ],
                ),
                border: Border.all(
                  color:
                      const Color(0xff14375C),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyan
                        .withOpacity(.08),
                    blurRadius: 25,
                  )
                ],
              ),

              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [

                  const Text(
                    "BRAND IDENTITY",
                    style: TextStyle(
                      color: Color(
                          0xff00D4FF),
                      letterSpacing: 4,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                      height: 18),

                  const Text(
                    "Logo & Cover",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                      height: 12),

                  const Text(
                    "Upload your business logo and hero banner.",
                    style: TextStyle(
                      color:
                          Color(0xff9CB6D2),
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(
                      height: 30),

                  _UploadCard(
                    title:
                        "Cafe / Hotel Logo",
                    subtitle:
                        "Square logo image",
                    icon:
                        Icons.storefront,
                    imageBytes:
                        selectedLogo,
                    imageUrl: logoUrl,
                    circle: true,
                    onTap: pickLogo,
                  ),

                  const SizedBox(
                      height: 18),

                  _UploadCard(
                    title:
                        "Cover Banner",
                    subtitle:
                        "Wide hero image",
                    icon:
                        Icons.wallpaper,
                    imageBytes:
                        selectedCover,
                    imageUrl: coverUrl,
                    circle: false,
                    onTap: pickCover,
                  ),
                ],
              ),
            ),

            const SizedBox(height:25),

            Container(
              padding:
                  const EdgeInsets.all(26),
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(
                        34),
                color:
                    const Color(0xff071426),
                border: Border.all(
                  color:
                      const Color(0xff14375C),
                ),
              ),

              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [

                  const Text(
                    "SOCIAL LINKS",
                    style: TextStyle(
                      color: Color(
                          0xff00D4FF),
                      letterSpacing:4,
                    ),
                  ),

                  const SizedBox(
                      height:18),

                  socialField(
                    "Facebook",
                    Icons.facebook,
                    facebookController,
                  ),

                  socialField(
                    "Instagram",
                    Icons.camera_alt,
                    instagramController,
                  ),

                  socialField(
                    "TikTok",
                    Icons.music_note,
                    tiktokController,
                  ),

                  socialField(
                    "Google Reviews",
                    Icons.star,
                    googleController,
                  ),
                ],
              ),
            ),

            const SizedBox(height:30),

            SizedBox(
              width: double.infinity,
              height:58,
              child: ElevatedButton(
                onPressed:
                    saving ? null : saveAll,

                style:
                    ElevatedButton.styleFrom(
                  elevation:0,
                  backgroundColor:
                      const Color(
                          0xff00D4FF),
                  foregroundColor:
                      Colors.black,
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                            18),
                  ),
                ),

                child: saving
                    ? const SizedBox(
                        width:24,
                        height:24,
                        child:
                         CircularProgressIndicator(
                          strokeWidth:2,
                          color: Colors.black,
                        ),
                      )
                    : const Text(
                        "Save Business Settings",
                        style: TextStyle(
                          fontSize:16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height:40),
          ],
        ),
      ),
    );
  }
}

class _UploadCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Uint8List? imageBytes;
  final String imageUrl;
  final bool circle;
  final VoidCallback onTap;

  const _UploadCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.imageBytes,
    required this.imageUrl,
    required this.circle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageBytes != null || imageUrl.isNotEmpty;

    final buttonText = circle ? 'Change Logo' : 'Change Cover';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xff0A1322),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xff183C60),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(circle ? 100 : 18),
            child: SizedBox(
              width: circle ? 105 : 145,
              height: circle ? 105 : 92,
              child: hasImage
                  ? imageBytes != null
                      ? Image.memory(
                          imageBytes!,
                          fit: BoxFit.cover,
                        )
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                        )
                  : Container(
                      color: const Color(0xff111B2A),
                      child: Icon(
                        icon,
                        size: 34,
                        color: const Color(0xff00D4FF),
                      ),
                    ),
            ),
          ),

          const SizedBox(width: 20),

          Expanded(
            child: SizedBox(
              height: circle ? 105 : 92,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    circle ? 'Cafe / Hotel Logo' : 'Cover Picture',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const Spacer(),

                  Align(
                    alignment: Alignment.bottomRight,
                    child: OutlinedButton.icon(
                      onPressed: onTap,
                      icon: const Icon(
                        Icons.upload_rounded,
                        size: 18,
                      ),
                      label: Text(buttonText),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xff00D4FF),
                        side: const BorderSide(
                          color: Color(0xff00D4FF),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}