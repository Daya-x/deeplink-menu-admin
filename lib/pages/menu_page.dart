import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  final categoryController = TextEditingController();
  final nameController = TextEditingController();
  final descController = TextEditingController();
  final priceController = TextEditingController();
  final normalController = TextEditingController();
  final fullController = TextEditingController();

  bool hasSizes = false;
  bool uploading = false;
  String selectedCategory = '';
  Uint8List? selectedImage;

  String get uid => FirebaseAuth.instance.currentUser!.uid;

  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: const BorderSide(color: Color(0xFF1D2B44)),
  );

  InputDecoration inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF9FB3C8)),
      filled: true,
      fillColor: const Color(0xFF0B101B),
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF00D1FF)),
      ),
    );
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);

    if (file != null) {
      selectedImage = await file.readAsBytes();
      setState(() {});
    }
  }

  Future<String> uploadImage(Uint8List bytes) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.cloudinary.com/v1_1/dbe63rr9s/image/upload'),
    );

    req.fields['upload_preset'] = 'deeplink_menu';

    req.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: 'food.jpg',
      ),
    );

    final res = await req.send();
    final data = await res.stream.bytesToString();

    return jsonDecode(data)['secure_url'];
  }

  Future<void> addCategory() async {
    if (categoryController.text.trim().isEmpty) return;

    await FirebaseFirestore.instance
        .collection('businesses')
        .doc(uid)
        .collection('categories')
        .add({
      'name': categoryController.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    categoryController.clear();
  }

  Future<void> addItem() async {
    if (nameController.text.trim().isEmpty) return;
    if (selectedCategory.isEmpty) return;

    setState(() => uploading = true);

    String imageUrl = '';

    if (selectedImage != null) {
      imageUrl = await uploadImage(selectedImage!);
    }

    await FirebaseFirestore.instance
        .collection('businesses')
        .doc(uid)
        .collection('menuItems')
        .add({
      'image': imageUrl,
      'category': selectedCategory,
      'name': nameController.text.trim(),
      'description': descController.text.trim(),
      'hasSizeOptions': hasSizes,
      'price': hasSizes ? '' : priceController.text.trim(),
      'normalPrice': hasSizes ? normalController.text.trim() : '',
      'fullPrice': hasSizes ? fullController.text.trim() : '',
      'isAvailable': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    nameController.clear();
    descController.clear();
    priceController.clear();
    normalController.clear();
    fullController.clear();

    setState(() {
      selectedImage = null;
      uploading = false;
      hasSizes = false;
    });
  }

  Future<void> deleteItem(String id) async {
    await FirebaseFirestore.instance
        .collection('businesses')
        .doc(uid)
        .collection('menuItems')
        .doc(id)
        .delete();
  }

  Widget neonSwitch({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: const TextStyle(
          color: Color(0xFFEAF8FF),
          fontWeight: FontWeight.w600,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF050B16),
      activeTrackColor: const Color(0xFF00D1FF),
      inactiveThumbColor: const Color(0xFF9FB3C8),
      inactiveTrackColor: const Color(0xFF1D2B44),
    );
  }

  Future<void> showEditDialog(
    String itemId,
    Map<String, dynamic> item,
  ) async {
    final editName = TextEditingController(text: item['name'] ?? '');
    final editDesc = TextEditingController(text: item['description'] ?? '');
    final editPrice = TextEditingController(text: item['price'] ?? '');
    final editNormal = TextEditingController(text: item['normalPrice'] ?? '');
    final editFull = TextEditingController(text: item['fullPrice'] ?? '');

    bool editHasSizes = item['hasSizeOptions'] ?? false;
    bool editAvailable = item['isAvailable'] ?? true;
    Uint8List? editImage;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: 460,
                constraints: const BoxConstraints(maxHeight: 760),
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B101B),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: const Color(0xFF00D1FF).withOpacity(0.18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00D1FF).withOpacity(0.14),
                      blurRadius: 35,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.45),
                      blurRadius: 30,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Edit Item',
                          style: TextStyle(
                            color: Color(0xFFEAF8FF),
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      const SizedBox(height: 22),

                      if (editImage != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.memory(
                            editImage!,
                            height: 170,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        )
                      else if ((item['image'] ?? '').toString().isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.network(
                            item['image'],
                            height: 170,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),

                      const SizedBox(height: 16),

                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF00D1FF),
                          side: const BorderSide(color: Color(0xFF00D1FF)),
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: () async {
                          final picker = ImagePicker();
                          final file = await picker.pickImage(
                            source: ImageSource.gallery,
                          );

                          if (file != null) {
                            final bytes = await file.readAsBytes();
                            setDialogState(() {
                              editImage = bytes;
                            });
                          }
                        },
                        icon: const Icon(Icons.image),
                        label: const Text('Change Image'),
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: editName,
                        style: const TextStyle(color: Color(0xFFEAF8FF)),
                        decoration: inputDecoration('Item Name'),
                      ),

                      const SizedBox(height: 14),

                      TextField(
                        controller: editDesc,
                        style: const TextStyle(color: Color(0xFFEAF8FF)),
                        maxLines: 3,
                        decoration: inputDecoration('Description'),
                      ),

                      const SizedBox(height: 12),

                      neonSwitch(
                        title: 'Normal / Full Prices',
                        value: editHasSizes,
                        onChanged: (v) {
                          setDialogState(() {
                            editHasSizes = v;
                          });
                        },
                      ),

                      if (!editHasSizes)
                        TextField(
                          controller: editPrice,
                          style: const TextStyle(color: Color(0xFFEAF8FF)),
                          decoration: inputDecoration('Price'),
                        ),

                      if (editHasSizes) ...[
                        TextField(
                          controller: editNormal,
                          style: const TextStyle(color: Color(0xFFEAF8FF)),
                          decoration: inputDecoration('Normal Price'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: editFull,
                          style: const TextStyle(color: Color(0xFFEAF8FF)),
                          decoration: inputDecoration('Full Price'),
                        ),
                      ],

                      const SizedBox(height: 12),

                      neonSwitch(
                        title: 'Available',
                        value: editAvailable,
                        onChanged: (v) {
                          setDialogState(() {
                            editAvailable = v;
                          });
                        },
                      ),

                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF9FB3C8),
                                side: const BorderSide(
                                  color: Color(0xFF1D2B44),
                                ),
                                minimumSize: const Size(double.infinity, 52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _FullGradientButton(
                              text: 'Update',
                              icon: Icons.check_rounded,
                              onTap: () async {
                                String imageUrl = item['image'] ?? '';

                                if (editImage != null) {
                                  imageUrl = await uploadImage(editImage!);
                                }

                                await FirebaseFirestore.instance
                                    .collection('businesses')
                                    .doc(uid)
                                    .collection('menuItems')
                                    .doc(itemId)
                                    .update({
                                  'image': imageUrl,
                                  'name': editName.text.trim(),
                                  'description': editDesc.text.trim(),
                                  'hasSizeOptions': editHasSizes,
                                  'price': editHasSizes
                                      ? ''
                                      : editPrice.text.trim(),
                                  'normalPrice': editHasSizes
                                      ? editNormal.text.trim()
                                      : '',
                                  'fullPrice':
                                      editHasSizes ? editFull.text.trim() : '',
                                  'isAvailable': editAvailable,
                                  'updatedAt': FieldValue.serverTimestamp(),
                                });

                                Navigator.pop(context);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050B16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050B16),
        foregroundColor: const Color(0xFF00D1FF),
        title: const Text('Manage Menu'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;

            final form = _GlassPanel(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add Menu Item',
                      style: TextStyle(
                        color: Color(0xFFEAF8FF),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 18),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: categoryController,
                            style: const TextStyle(color: Color(0xFFEAF8FF)),
                            decoration: inputDecoration('New Category'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _GradientButton(
                          text: 'Add',
                          onTap: addCategory,
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('businesses')
                          .doc(uid)
                          .collection('categories')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox();

                        final cats = snapshot.data!.docs
                            .map<String>(
                              (e) => (e.data()
                                      as Map<String, dynamic>)['name']
                                  .toString(),
                            )
                            .toList();

                        if (cats.isEmpty) {
                          return const Text(
                            'Add category first',
                            style: TextStyle(color: Color(0xFF9FB3C8)),
                          );
                        }

                        if (selectedCategory.isEmpty ||
                            !cats.contains(selectedCategory)) {
                          selectedCategory = cats.first;
                        }

                        return DropdownButtonFormField<String>(
                          value: selectedCategory,
                          dropdownColor: const Color(0xFF0B101B),
                          style: const TextStyle(color: Color(0xFFEAF8FF)),
                          decoration: inputDecoration('Select Category'),
                          items: cats
                              .map(
                                (c) => DropdownMenuItem<String>(
                                  value: c,
                                  child: Text(c),
                                ),
                              )
                              .toList(),
                          onChanged: (String? v) {
                            setState(() {
                              selectedCategory = v!;
                            });
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 22),

                    if (selectedImage != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.memory(
                          selectedImage!,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),

                    if (selectedImage != null) const SizedBox(height: 12),

                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF00D1FF),
                        side: const BorderSide(color: Color(0xFF00D1FF)),
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: pickImage,
                      icon: const Icon(Icons.image),
                      label: const Text('Upload Food Image'),
                    ),

                    const SizedBox(height: 18),

                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Color(0xFFEAF8FF)),
                      decoration: inputDecoration('Item Name'),
                    ),

                    const SizedBox(height: 14),

                    TextField(
                      controller: descController,
                      style: const TextStyle(color: Color(0xFFEAF8FF)),
                      maxLines: 3,
                      decoration: inputDecoration('Description'),
                    ),

                    const SizedBox(height: 12),

                    neonSwitch(
                      title: 'Normal / Full Prices',
                      value: hasSizes,
                      onChanged: (v) {
                        setState(() {
                          hasSizes = v;
                        });
                      },
                    ),

                    if (!hasSizes)
                      TextField(
                        controller: priceController,
                        style: const TextStyle(color: Color(0xFFEAF8FF)),
                        decoration: inputDecoration('Price'),
                      ),

                    if (hasSizes) ...[
                      TextField(
                        controller: normalController,
                        style: const TextStyle(color: Color(0xFFEAF8FF)),
                        decoration: inputDecoration('Normal Price'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: fullController,
                        style: const TextStyle(color: Color(0xFFEAF8FF)),
                        decoration: inputDecoration('Full Price'),
                      ),
                    ],

                    const SizedBox(height: 22),

                    _FullGradientButton(
                      text: uploading ? 'Uploading...' : 'Add Menu Item',
                      icon: Icons.add,
                      onTap: uploading ? null : addItem,
                    ),
                  ],
                ),
              ),
            );

            final list = _GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Menu Items',
                    style: TextStyle(
                      color: Color(0xFFEAF8FF),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('businesses')
                          .doc(uid)
                          .collection('menuItems')
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF00D1FF),
                            ),
                          );
                        }

                        final docs = snapshot.data!.docs;

                        if (docs.isEmpty) {
                          return const Center(
                            child: Text(
                              'No menu items yet',
                              style: TextStyle(color: Color(0xFF9FB3C8)),
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final item = docs[index];
                            final data =
                                item.data() as Map<String, dynamic>;

                            final itemHasSizes =
                                data['hasSizeOptions'] ?? false;

                            final price = itemHasSizes
                                ? 'Normal ${data['normalPrice']} | Full ${data['fullPrice']}'
                                : 'Rs ${data['price']}';

                            final available = data['isAvailable'] ?? true;

                            return _MenuItemCard(
                              data: data,
                              price: price,
                              available: available,
                              onEdit: () => showEditDialog(item.id, data),
                              onDelete: () => deleteItem(item.id),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );

            if (isWide) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    SizedBox(width: 430, child: form),
                    const SizedBox(width: 20),
                    Expanded(child: list),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  form,
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 600,
                    child: list,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;

  const _GlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF111827),
            Color(0xFF0A1020),
          ],
        ),
        border: Border.all(
          color: Color(0xFF00D1FF).withOpacity(0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00D1FF).withOpacity(0.08),
            blurRadius: 28,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _GradientButton({
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF00E5FF),
              Color(0xFF0057FF),
            ],
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF050B16),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _FullGradientButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback? onTap;

  const _FullGradientButton({
    required this.text,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.55 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF00E5FF),
                Color(0xFF0057FF),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00D1FF).withOpacity(0.25),
                blurRadius: 24,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFF050B16), size: 20),
              const SizedBox(width: 8),
              Text(
                text,
                style: const TextStyle(
                  color: Color(0xFF050B16),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String price;
  final bool available;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MenuItemCard({
    required this.data,
    required this.price,
    required this.available,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B101B),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF1D2B44)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: (data['image'] ?? '') != ''
                ? Image.network(
                    data['image'],
                    width: 76,
                    height: 76,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 76,
                    height: 76,
                    color: const Color(0xFF111827),
                    child: const Icon(
                      Icons.fastfood,
                      color: Color(0xFF00D1FF),
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['name'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFEAF8FF),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data['category'] ?? '',
                  style: const TextStyle(
                    color: Color(0xFF00D1FF),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  price,
                  style: const TextStyle(
                    color: Color(0xFF9FB3C8),
                    fontSize: 12,
                  ),
                ),
                if (!available)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Sold Out',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Color(0xFF00D1FF)),
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}