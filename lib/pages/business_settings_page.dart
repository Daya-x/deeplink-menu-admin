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
  State<BusinessSettingsPage> createState() => _BusinessSettingsPageState();
}

class _BusinessSettingsPageState extends State<BusinessSettingsPage> {
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

  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    loadBusiness();
  }

  @override
  void dispose() {
    facebookController.dispose();
    instagramController.dispose();
    tiktokController.dispose();
    googleController.dispose();
    super.dispose();
  }

  void showMessage(String message, {bool success = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: success ? const Color(0xff00D4FF) : Colors.redAccent,
        content: Text(
          message,
          style: TextStyle(
            color: success ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }

  Future<void> loadBusiness() async {
    final uid = currentUid;

    if (uid == null) {
      if (mounted) setState(() => loading = false);
      showMessage('Session expired. Please login again.');
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(uid)
          .get();

      final data = doc.data();

      facebookController.text = data?['facebookUrl'] ?? '';
      instagramController.text = data?['instagramUrl'] ?? '';
      tiktokController.text = data?['tiktokUrl'] ?? '';
      googleController.text = data?['googleReviewUrl'] ?? '';

      logoUrl = data?['logoUrl'] ?? '';
      coverUrl = data?['coverUrl'] ?? '';
    } catch (e) {
      showMessage('Failed to load business settings.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> pickLogo() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );

      if (file != null) {
        selectedLogo = await file.readAsBytes();
        if (mounted) setState(() {});
      }
    } catch (e) {
      showMessage('Failed to pick logo. Please try again.');
    }
  }

  Future<void> pickCover() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );

      if (file != null) {
        selectedCover = await file.readAsBytes();
        if (mounted) setState(() {});
      }
    } catch (e) {
      showMessage('Failed to pick cover image. Please try again.');
    }
  }

  Future<String> uploadImage(Uint8List bytes) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse(
        'https://api.cloudinary.com/v1_1/dbe63rr9s/image/upload',
      ),
    );

    req.fields['upload_preset'] = 'deeplink_menu';

    req.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: 'upload.jpg',
      ),
    );

    final res = await req.send();
    final body = await res.stream.bytesToString();
    final decoded = jsonDecode(body);

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(decoded['error']?['message'] ?? 'Image upload failed');
    }

    final secureUrl = decoded['secure_url'];

    if (secureUrl == null || secureUrl.toString().isEmpty) {
      throw Exception('Image upload failed. No image URL returned.');
    }

    return secureUrl.toString();
  }

  Future<void> saveAll() async {
    final uid = currentUid;

    if (uid == null) {
      showMessage('Session expired. Please login again.');
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      String finalLogo = logoUrl;
      String finalCover = coverUrl;

      if (selectedLogo != null) {
        finalLogo = await uploadImage(selectedLogo!);
      }

      if (selectedCover != null) {
        finalCover = await uploadImage(selectedCover!);
      }

      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(uid)
          .update({
        'logoUrl': finalLogo,
        'coverUrl': finalCover,
        'facebookUrl': facebookController.text.trim(),
        'instagramUrl': instagramController.text.trim(),
        'tiktokUrl': tiktokController.text.trim(),
        'googleReviewUrl': googleController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        logoUrl = finalLogo;
        coverUrl = finalCover;
        selectedLogo = null;
        selectedCover = null;
      });

      showMessage('Business settings updated.', success: true);
    } catch (e) {
      showMessage('Failed to save settings. Please try again.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget socialField(
    String label,
    IconData icon,
    TextEditingController controller,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xff081222),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xff133354),
        ),
      ),
      child: TextField(
        controller: controller,
        enabled: !saving,
        keyboardType: TextInputType.url,
        style: const TextStyle(
          color: Colors.white,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: Icon(
            icon,
            color: const Color(0xff00D4FF),
          ),
          labelText: label,
          labelStyle: const TextStyle(
            color: Color(0xff8AA7C2),
          ),
          contentPadding: const EdgeInsets.all(22),
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
          child: CircularProgressIndicator(
            color: Color(0xff00D4FF),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xff030712),
      appBar: AppBar(
        backgroundColor: const Color(0xff02060E),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xff00D4FF),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Business Settings",
          style: TextStyle(
            color: Color(0xff00D4FF),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(34),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xff071426),
                    Color(0xff020817),
                  ],
                ),
                border: Border.all(
                  color: const Color(0xff14375C),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyan.withOpacity(.08),
                    blurRadius: 25,
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "BRAND IDENTITY",
                    style: TextStyle(
                      color: Color(0xff00D4FF),
                      letterSpacing: 4,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    "Logo & Cover",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Upload your business logo and hero banner.",
                    style: TextStyle(
                      color: Color(0xff9CB6D2),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 30),
                  _UploadCard(
                    title: "Cafe / Hotel Logo",
                    subtitle: "Square logo image",
                    icon: Icons.storefront,
                    imageBytes: selectedLogo,
                    imageUrl: logoUrl,
                    circle: true,
                    onTap: saving ? null : pickLogo,
                  ),
                  const SizedBox(height: 18),
                  _UploadCard(
                    title: "Cover Banner",
                    subtitle: "Wide hero image",
                    icon: Icons.wallpaper,
                    imageBytes: selectedCover,
                    imageUrl: coverUrl,
                    circle: false,
                    onTap: saving ? null : pickCover,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(34),
                color: const Color(0xff071426),
                border: Border.all(
                  color: const Color(0xff14375C),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "SOCIAL LINKS",
                    style: TextStyle(
                      color: Color(0xff00D4FF),
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 18),
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
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                onPressed: saving ? null : saveAll,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: const Color(0xff00D4FF),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: saving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Text(
                        "Save Business Settings",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 40),
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
  final VoidCallback? onTap;

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

    Widget imageWidget({
      required double width,
      required double height,
    }) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(circle ? 100 : 18),
        child: SizedBox(
          width: width,
          height: height,
          child: hasImage
              ? imageBytes != null
                  ? Image.memory(
                      imageBytes!,
                      fit: BoxFit.cover,
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: const Color(0xff111B2A),
                          child: Icon(
                            Icons.broken_image,
                            size: 34,
                            color: const Color(0xff00D4FF),
                          ),
                        );
                      },
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
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xff0A1322),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xff183C60),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmall = constraints.maxWidth < 430;

          if (isSmall) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: imageWidget(
                    width: circle ? 120 : double.infinity,
                    height: circle ? 120 : 145,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xff9CB6D2),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              imageWidget(
                width: circle ? 105 : 145,
                height: circle ? 105 : 92,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: SizedBox(
                  height: circle ? 105 : 92,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xff9CB6D2),
                          fontSize: 13,
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
          );
        },
      ),
    );
  }
}