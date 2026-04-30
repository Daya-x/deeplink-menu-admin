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

  String get uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void dispose() {
    categoryController.dispose();
    nameController.dispose();
    descController.dispose();
    priceController.dispose();
    normalController.dispose();
    fullController.dispose();
    super.dispose();
  }

  void showMessage(String message, {bool success = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: success ? const Color(0xFF00D1FF) : Colors.redAccent,
        content: Text(
          message,
          style: TextStyle(
            color: success ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }

  bool isValidPrice(String value) {
    final price = double.tryParse(value.trim());
    return price != null && price >= 0;
  }

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
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery);

      if (file != null) {
        selectedImage = await file.readAsBytes();
        if (mounted) setState(() {});
      }
    } catch (e) {
      showMessage('Failed to pick image. Please try again.');
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
    final decoded = jsonDecode(data);

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(decoded['error']?['message'] ?? 'Image upload failed');
    }

    final secureUrl = decoded['secure_url'];

    if (secureUrl == null || secureUrl.toString().isEmpty) {
      throw Exception('Image upload failed. No image URL returned.');
    }

    return secureUrl.toString();
  }

  Future<void> addCategory() async {
    final uid = currentUid;
    final categoryName = categoryController.text.trim();

    if (uid == null) {
      showMessage('Session expired. Please login again.');
      return;
    }

    if (categoryName.isEmpty) {
      showMessage('Enter a category name.');
      return;
    }

    try {
      final existing = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(uid)
          .collection('categories')
          .where('nameLower', isEqualTo: categoryName.toLowerCase())
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        showMessage('This category already exists.');
        return;
      }

      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(uid)
          .collection('categories')
          .add({
        'name': categoryName,
        'nameLower': categoryName.toLowerCase(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      categoryController.clear();

      showMessage('Category added.', success: true);
    } catch (e) {
      showMessage('Failed to add category. Please try again.');
    }
  }

  Future<void> addItem() async {
    final uid = currentUid;

    if (uid == null) {
      showMessage('Session expired. Please login again.');
      return;
    }

    final name = nameController.text.trim();
    final description = descController.text.trim();
    final price = priceController.text.trim();
    final normalPrice = normalController.text.trim();
    final fullPrice = fullController.text.trim();

    if (name.isEmpty) {
      showMessage('Enter item name.');
      return;
    }

    if (selectedCategory.isEmpty) {
      showMessage('Select a category first.');
      return;
    }

    if (!hasSizes && !isValidPrice(price)) {
      showMessage('Enter a valid price.');
      return;
    }

    if (hasSizes) {
      if (!isValidPrice(normalPrice)) {
        showMessage('Enter a valid normal price.');
        return;
      }

      if (!isValidPrice(fullPrice)) {
        showMessage('Enter a valid full price.');
        return;
      }
    }

    setState(() => uploading = true);

    try {
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
        'name': name,
        'description': description,
        'hasSizeOptions': hasSizes,
        'price': hasSizes ? '' : price,
        'normalPrice': hasSizes ? normalPrice : '',
        'fullPrice': hasSizes ? fullPrice : '',
        'isAvailable': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      nameController.clear();
      descController.clear();
      priceController.clear();
      normalController.clear();
      fullController.clear();

      setState(() {
        selectedImage = null;
        hasSizes = false;
      });

      showMessage('Menu item added.', success: true);
    } catch (e) {
      showMessage('Failed to add menu item. Please try again.');
    } finally {
      if (mounted) {
        setState(() => uploading = false);
      }
    }
  }

  Future<void> deleteItem(String id) async {
    final uid = currentUid;

    if (uid == null) {
      showMessage('Session expired. Please login again.');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0B101B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Delete Item',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Are you sure you want to delete this menu item?',
            style: TextStyle(color: Color(0xFF9FB3C8)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(uid)
          .collection('menuItems')
          .doc(id)
          .delete();

      showMessage('Menu item deleted.', success: true);
    } catch (e) {
      showMessage('Failed to delete item. Please try again.');
    }
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
    bool editSaving = false;
    Uint8List? editImage;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> updateItem() async {
              final uid = currentUid;

              if (uid == null) {
                showMessage('Session expired. Please login again.');
                return;
              }

              final name = editName.text.trim();
              final description = editDesc.text.trim();
              final price = editPrice.text.trim();
              final normalPrice = editNormal.text.trim();
              final fullPrice = editFull.text.trim();

              if (name.isEmpty) {
                showMessage('Enter item name.');
                return;
              }

              if (!editHasSizes && !isValidPrice(price)) {
                showMessage('Enter a valid price.');
                return;
              }

              if (editHasSizes) {
                if (!isValidPrice(normalPrice)) {
                  showMessage('Enter a valid normal price.');
                  return;
                }

                if (!isValidPrice(fullPrice)) {
                  showMessage('Enter a valid full price.');
                  return;
                }
              }

              setDialogState(() {
                editSaving = true;
              });

              try {
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
                  'name': name,
                  'description': description,
                  'hasSizeOptions': editHasSizes,
                  'price': editHasSizes ? '' : price,
                  'normalPrice': editHasSizes ? normalPrice : '',
                  'fullPrice': editHasSizes ? fullPrice : '',
                  'isAvailable': editAvailable,
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                if (!mounted) return;

                Navigator.pop(context);
                showMessage('Menu item updated.', success: true);
              } catch (e) {
                showMessage('Failed to update item. Please try again.');
              } finally {
                setDialogState(() {
                  editSaving = false;
                });
              }
            }

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
                        onPressed: editSaving
                            ? null
                            : () async {
                                try {
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
                                } catch (e) {
                                  showMessage(
                                    'Failed to pick image. Please try again.',
                                  );
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
                        onChanged: editSaving
                            ? (_) {}
                            : (v) {
                                setDialogState(() {
                                  editHasSizes = v;
                                });
                              },
                      ),
                      if (!editHasSizes)
                        TextField(
                          controller: editPrice,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Color(0xFFEAF8FF)),
                          decoration: inputDecoration('Price'),
                        ),
                      if (editHasSizes) ...[
                        TextField(
                          controller: editNormal,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Color(0xFFEAF8FF)),
                          decoration: inputDecoration('Normal Price'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: editFull,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Color(0xFFEAF8FF)),
                          decoration: inputDecoration('Full Price'),
                        ),
                      ],
                      const SizedBox(height: 12),
                      neonSwitch(
                        title: 'Available',
                        value: editAvailable,
                        onChanged: editSaving
                            ? (_) {}
                            : (v) {
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
                              onPressed:
                                  editSaving ? null : () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _FullGradientButton(
                              text: editSaving ? 'Updating...' : 'Update',
                              icon: Icons.check_rounded,
                              onTap: editSaving ? null : updateItem,
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
    if (uid.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF050B16),
        body: Center(
          child: Text(
            'Session expired. Please login again.',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

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
                          .orderBy('createdAt', descending: false)
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
                      onPressed: uploading ? null : pickImage,
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
                      onChanged: uploading
                          ? (_) {}
                          : (v) {
                              setState(() {
                                hasSizes = v;
                              });
                            },
                    ),
                    if (!hasSizes)
                      TextField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Color(0xFFEAF8FF)),
                        decoration: inputDecoration('Price'),
                      ),
                    if (hasSizes) ...[
                      TextField(
                        controller: normalController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Color(0xFFEAF8FF)),
                        decoration: inputDecoration('Normal Price'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: fullController,
                        keyboardType: TextInputType.number,
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
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 76,
                        height: 76,
                        color: const Color(0xFF111827),
                        child: const Icon(
                          Icons.broken_image,
                          color: Color(0xFF00D1FF),
                        ),
                      );
                    },
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