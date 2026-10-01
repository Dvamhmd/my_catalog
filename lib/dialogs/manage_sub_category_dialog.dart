import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'image_cropper_dialog.dart';
import '../models/category_type.dart';
import '../models/sub_category_model.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_image_view.dart';

class ManageSubCategoryDialog extends StatefulWidget {
  final CategoryType activeType;
  final List<SubCategoryModel> subCategories;
  final Function(String name, String? imagePath) onAdd;
  final Function(SubCategoryModel subCategory, String newName, String? newImagePath, bool clearImage) onEdit;
  final Function(SubCategoryModel subCategory) onDelete;

  const ManageSubCategoryDialog({
    super.key,
    required this.activeType,
    required this.subCategories,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<ManageSubCategoryDialog> createState() => _ManageSubCategoryDialogState();
}

class _ManageSubCategoryDialogState extends State<ManageSubCategoryDialog> {
  final _addController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  String? _newCategoryImagePath;

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source, {required Function(String path) onPicked}) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (file != null && mounted) {
        final cropped = await ImageCropperDialog.cropImage(
          context,
          file: file,
          title: 'Sesuaikan Foto Kategori',
        );
        if (cropped != null) {
          onPicked(cropped);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih foto: $e'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
      }
    }
  }

  void _showImageSourcePicker({
    required Function(String path) onPicked,
    VoidCallback? onRemove,
    bool hasPhoto = false,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Pilih Foto / Icon Kategori',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.softPinkBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: AppTheme.primaryPink),
                ),
                title: const Text(
                  'Ambil dari Kamera',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera, onPicked: onPicked);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.softPinkBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: AppTheme.primaryPink),
                ),
                title: const Text(
                  'Pilih dari Galeri',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery, onPicked: onPicked);
                },
              ),
              if (hasPhoto && onRemove != null)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: AppTheme.dangerRed),
                  ),
                  title: const Text(
                    'Hapus Foto (Gunakan Icon Default)',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppTheme.dangerRed,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    onRemove();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleAdd() {
    if (!_formKey.currentState!.validate()) return;
    final name = _addController.text.trim();
    widget.onAdd(name, _newCategoryImagePath);
    _addController.clear();
    setState(() {
      _newCategoryImagePath = null;
    });
  }

  void _showEditPrompt(SubCategoryModel subCategory) {
    final editController = TextEditingController(text: subCategory.name);
    String? currentImagePath = subCategory.imagePath;
    bool clearImage = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final hasImg = !clearImage && (currentImagePath != null && currentImagePath!.isNotEmpty);

            return AlertDialog(
              backgroundColor: AppTheme.surfaceWhite,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text(
                'Ubah Kategori',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  // Photo Preview & Picker
                  GestureDetector(
                    onTap: () {
                      _showImageSourcePicker(
                        hasPhoto: hasImg,
                        onPicked: (path) {
                          setDialogState(() {
                            currentImagePath = path;
                            clearImage = false;
                          });
                        },
                        onRemove: () {
                          setDialogState(() {
                            currentImagePath = null;
                            clearImage = true;
                          });
                        },
                      );
                    },
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: AppTheme.softPinkBackground,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFFFD1DC), width: 1.5),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: CustomImageView(
                              imagePath: hasImg ? currentImagePath : null,
                              type: subCategory.type,
                              isCategory: true,
                              width: 84,
                              height: 84,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppTheme.primaryPink,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: () {
                      _showImageSourcePicker(
                        hasPhoto: hasImg,
                        onPicked: (path) {
                          setDialogState(() {
                            currentImagePath = path;
                            clearImage = false;
                          });
                        },
                        onRemove: () {
                          setDialogState(() {
                            currentImagePath = null;
                            clearImage = true;
                          });
                        },
                      );
                    },
                    icon: const Icon(Icons.photo_camera_outlined, size: 16, color: AppTheme.primaryPink),
                    label: Text(
                      hasImg ? 'Ganti Foto' : 'Tambah Foto',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryPink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: editController,
                    autofocus: false,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Nama Kategori',
                      prefixIcon: Icon(subCategory.type.icon, color: AppTheme.primaryPinkLight, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal', style: TextStyle(color: AppTheme.textMedium)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final newName = editController.text.trim();
                    if (newName.isNotEmpty) {
                      Navigator.pop(ctx);
                      widget.onEdit(subCategory, newName, currentImagePath, clearImage);
                    }
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeletePrompt(SubCategoryModel subCategory) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text(
            'Hapus Kategori?',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          content: Text(
            'Menghapus "${subCategory.name}" juga akan menghapus semua menu yang ada di dalam kategori ini.',
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              color: AppTheme.textMedium,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: AppTheme.textMedium)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
              onPressed: () {
                Navigator.pop(ctx);
                widget.onDelete(subCategory);
              },
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final isFood = widget.activeType == CategoryType.food;
    final categoryIcon = widget.activeType.icon;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: bottomInset),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: (MediaQuery.sizeOf(context).height - bottomInset).clamp(280.0, MediaQuery.sizeOf(context).height * 0.85),
        ),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          // Drag Handle & Header
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.softPinkBackground,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        widget.activeType.emoji,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kelola Kategori ${widget.activeType.displayName}',
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textDark,
                          ),
                        ),
                        Text(
                          '${widget.subCategories.length} kategori terdaftar',
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            color: AppTheme.textMedium,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: AppTheme.textLight),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFFFE5EC)),

          // Add New Category Input Box with Photo Picker
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Photo Picker Button
                      GestureDetector(
                        onTap: () {
                          _showImageSourcePicker(
                            hasPhoto: _newCategoryImagePath != null,
                            onPicked: (path) {
                              setState(() {
                                _newCategoryImagePath = path;
                              });
                            },
                            onRemove: () {
                              setState(() {
                                _newCategoryImagePath = null;
                              });
                            },
                          );
                        },
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: AppTheme.softPinkBackground,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _newCategoryImagePath != null
                                      ? AppTheme.primaryPink
                                      : const Color(0xFFFFD1DC),
                                  width: 1.2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: CustomImageView(
                                  imagePath: _newCategoryImagePath,
                                  type: widget.activeType,
                                  isCategory: true,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(3.5),
                              decoration: const BoxDecoration(
                                color: AppTheme.primaryPink,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 11,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Text Field
                      Expanded(
                        child: TextFormField(
                          controller: _addController,
                          textCapitalization: TextCapitalization.words,
                          style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13.5),
                          decoration: InputDecoration(
                            hintText: isFood ? 'Contoh: Makanan Utama, Snack...' : 'Contoh: Kopi, Jus Segar...',
                            prefixIcon: Icon(categoryIcon, color: AppTheme.primaryPinkLight, size: 20),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Masukkan nama kategori';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Submit Add Button
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onPressed: _handleAdd,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_rounded, size: 18),
                            SizedBox(width: 4),
                            Text(
                              'Tambah',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_newCategoryImagePath != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const SizedBox(width: 4),
                        const Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.successGreen),
                        const SizedBox(width: 5),
                        const Text(
                          'Foto kategori terpasang',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 11.5,
                            color: AppTheme.successGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _newCategoryImagePath = null;
                            });
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Text(
                              'Batal Foto',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 11.5,
                                color: AppTheme.dangerRed,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // List of Existing Categories Header
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Daftar Kategori',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textLight,
                ),
              ),
            ),
          ),

          Flexible(
            child: widget.subCategories.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Belum ada kategori.\nBuat kategori pertama di atas!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        color: AppTheme.textLight,
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 6,
                      bottom: 16,
                    ),
                    itemCount: widget.subCategories.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final sub = widget.subCategories[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.softPinkBackground.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFE5EC)),
                        ),
                        child: Row(
                          children: [
                            // Category Image / Icon thumbnail (Tappable for Quick Photo Change)
                            GestureDetector(
                              onTap: () {
                                _showImageSourcePicker(
                                  hasPhoto: sub.imagePath != null && sub.imagePath!.isNotEmpty,
                                  onPicked: (path) {
                                    widget.onEdit(sub, sub.name, path, false);
                                  },
                                  onRemove: () {
                                    widget.onEdit(sub, sub.name, null, true);
                                  },
                                );
                              },
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppTheme.softPinkBackground,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFFFFD1DC),
                                        width: 1,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(9),
                                      child: CustomImageView(
                                        imagePath: sub.imagePath,
                                        type: sub.type,
                                        isCategory: true,
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(2.5),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.primaryPink,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.edit,
                                      size: 9,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sub.name,
                                    style: const TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                  if (sub.imagePath != null && sub.imagePath!.isNotEmpty)
                                    const Text(
                                      'Foto kustom aktif',
                                      style: TextStyle(
                                        fontFamily: AppTheme.fontFamily,
                                        fontSize: 11,
                                        color: AppTheme.primaryPinkDark,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_a_photo_outlined, size: 18, color: AppTheme.primaryPinkDark),
                              tooltip: 'Ganti Foto',
                              onPressed: () {
                                _showImageSourcePicker(
                                  hasPhoto: sub.imagePath != null && sub.imagePath!.isNotEmpty,
                                  onPicked: (path) {
                                    widget.onEdit(sub, sub.name, path, false);
                                  },
                                  onRemove: () {
                                    widget.onEdit(sub, sub.name, null, true);
                                  },
                                );
                              },
                              visualDensity: VisualDensity.compact,
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.textMedium),
                              tooltip: 'Ubah Kategori',
                              onPressed: () => _showEditPrompt(sub),
                              visualDensity: VisualDensity.compact,
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.dangerRed),
                              tooltip: 'Hapus Kategori',
                              onPressed: () => _showDeletePrompt(sub),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}
}

