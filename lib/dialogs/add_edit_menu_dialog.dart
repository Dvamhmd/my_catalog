import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'image_cropper_dialog.dart';
import '../models/category_type.dart';
import '../models/menu_item_model.dart';
import '../models/sub_category_model.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/custom_image_view.dart';

class AddEditMenuDialog extends StatefulWidget {
  final CategoryType activeType;
  final List<SubCategoryModel> subCategories;
  final SubCategoryModel? defaultSubCategory;
  final MenuItemModel? itemToEdit;

  const AddEditMenuDialog({
    super.key,
    required this.activeType,
    required this.subCategories,
    this.defaultSubCategory,
    this.itemToEdit,
  });

  @override
  State<AddEditMenuDialog> createState() => _AddEditMenuDialogState();
}

class _AddEditMenuDialogState extends State<AddEditMenuDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _descriptionController;

  SubCategoryModel? _selectedSubCategory;
  String? _imagePath;
  bool _isAvailable = true;

  final ImagePicker _picker = ImagePicker();


  @override
  void initState() {
    super.initState();
    final edit = widget.itemToEdit;

    _nameController = TextEditingController(text: edit?.name ?? '');
    _priceController = TextEditingController(
      text: edit != null ? edit.price.toInt().toString() : '',
    );
    _descriptionController = TextEditingController(text: edit?.description ?? '');
    _imagePath = edit?.imagePath;
    _isAvailable = edit?.isAvailable ?? true;

    // Determine initial selected sub category
    if (edit != null) {
      _selectedSubCategory = widget.subCategories.firstWhere(
        (sc) => sc.id == edit.subCategoryId,
        orElse: () => widget.subCategories.isNotEmpty
            ? widget.subCategories.first
            : SubCategoryModel(
                name: edit.subCategoryName,
                type: widget.activeType,
              ),
      );
    } else if (widget.defaultSubCategory != null) {
      _selectedSubCategory = widget.defaultSubCategory;
    } else if (widget.subCategories.isNotEmpty) {
      _selectedSubCategory = widget.subCategories.first;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (pickedFile != null && mounted) {
        final cropped = await ImageCropperDialog.cropImage(
          context,
          file: pickedFile,
          title: 'Sesuaikan Foto Menu',
        );
        if (cropped != null && mounted) {
          setState(() {
            _imagePath = cropped;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih gambar: $e'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
      }
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
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
                    'Pilih Foto Menu',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.softPinkBackground,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: AppTheme.primaryPink),
                  ),
                  title: const Text(
                    'Buka Galeri',
                    style: TextStyle(fontFamily: AppTheme.fontFamily, fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.softPinkBackground,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: AppTheme.primaryPink),
                  ),
                  title: const Text(
                    'Ambil Foto Kamera',
                    style: TextStyle(fontFamily: AppTheme.fontFamily, fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                if (_imagePath != null)
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.delete_outline_rounded, color: AppTheme.dangerRed),
                    ),
                    title: const Text(
                      'Hapus Gambar',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        color: AppTheme.dangerRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _imagePath = null;
                      });
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSubCategory == null || _selectedSubCategory!.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih kategori terlebih dahulu'),
          backgroundColor: AppTheme.warningOrange,
        ),
      );
      return;
    }

    final price = Formatters.parseCurrencyInput(_priceController.text);
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harga menu harus lebih besar dari 0'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    final menuItem = MenuItemModel(
      id: widget.itemToEdit?.id,
      name: _nameController.text.trim(),
      price: price,
      imagePath: _imagePath,
      subCategoryId: _selectedSubCategory!.id!,
      subCategoryName: _selectedSubCategory!.name,
      type: widget.activeType,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      isAvailable: _isAvailable,
      createdAt: widget.itemToEdit?.createdAt,
    );

    Navigator.of(context).pop(menuItem);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.itemToEdit != null;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: bottomInset),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: (MediaQuery.sizeOf(context).height - bottomInset).clamp(280.0, MediaQuery.sizeOf(context).height * 0.9),
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
                            isEditing ? 'Edit Menu' : 'Tambah Menu Baru',
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textDark,
                            ),
                          ),
                          Text(
                            'Kategori ${widget.activeType.displayName}',
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

            // Form Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image Picker Card
                      Center(
                        child: GestureDetector(
                          onTap: _showImagePickerOptions,
                          child: Stack(
                            children: [
                              Container(
                                width: 140,
                                height: 130,
                                decoration: BoxDecoration(
                                  color: AppTheme.softPinkBackground,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: AppTheme.primaryPink.withValues(alpha: 0.3),
                                    width: 1.5,
                                    style: BorderStyle.solid,
                                  ),
                                ),
                                child: _imagePath != null
                                    ? CustomImageView(
                                        imagePath: _imagePath,
                                        type: widget.activeType,
                                        borderRadius: BorderRadius.circular(16),
                                        width: 140,
                                        height: 130,
                                      )
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: AppTheme.primaryPink.withValues(alpha: 0.15),
                                                  blurRadius: 8,
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.add_a_photo_rounded,
                                              color: AppTheme.primaryPink,
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'Foto Menu\n(Opsional)',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontFamily: AppTheme.fontFamily,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.primaryPinkDark,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryPink,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Kategori Dropdown (Auto sync)
                      const Text(
                        'Kategori',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceWhite,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFE0E6), width: 1.2),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<SubCategoryModel>(
                            value: _selectedSubCategory,
                            isExpanded: true,
                            hint: const Text(
                              'Pilih Kategori',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 14,
                                color: AppTheme.textLight,
                              ),
                            ),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.primaryPink),
                            items: widget.subCategories.map((sub) {
                              return DropdownMenuItem<SubCategoryModel>(
                                value: sub,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: AppTheme.primaryPink,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      sub.name,
                                      style: const TextStyle(
                                        fontFamily: AppTheme.fontFamily,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedSubCategory = val;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Nama Menu (Wajib)
                      const Row(
                        children: [
                          Text(
                            'Nama Menu',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark,
                            ),
                          ),
                          Text(' *', style: TextStyle(color: AppTheme.dangerRed, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Misal: Nasi Goreng Spesial',
                          prefixIcon: Icon(Icons.restaurant_menu_rounded, color: AppTheme.primaryPinkLight),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nama menu wajib diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Harga (Wajib)
                      const Row(
                        children: [
                          Text(
                            'Harga Menu',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark,
                            ),
                          ),
                          Text(' *', style: TextStyle(color: AppTheme.dangerRed, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryPinkDark,
                        ),
                        decoration: const InputDecoration(
                          hintText: '25000',
                          prefixText: 'Rp ',
                          prefixStyle: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryPink,
                          ),
                          prefixIcon: Icon(Icons.payments_outlined, color: AppTheme.primaryPinkLight),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Harga menu wajib diisi';
                          }
                          final parsed = double.tryParse(value);
                          if (parsed == null || parsed <= 0) {
                            return 'Harga harus berupa angka valid';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Deskripsi (Opsional)
                      const Text(
                        'Deskripsi / Catatan (Opsional)',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 2,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Keterangan porsi, bahan atau rasa...',
                          prefixIcon: Icon(Icons.notes_rounded, color: AppTheme.primaryPinkLight),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Status Ketersediaan Switch (Hanya tampil saat Edit Menu agar saat tambah menu baru lebih compact)
                      if (isEditing) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.softPinkBackground.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFFE0E6)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _isAvailable ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                    color: _isAvailable ? AppTheme.successGreen : AppTheme.textLight,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _isAvailable ? 'Menu Tersedia' : 'Menu Habis',
                                        style: TextStyle(
                                          fontFamily: AppTheme.fontFamily,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: _isAvailable ? AppTheme.textDark : AppTheme.textMedium,
                                        ),
                                      ),
                                      Text(
                                        _isAvailable ? 'Dapat dipesan pelanggan' : 'Disembunyikan / tidak aktif',
                                        style: const TextStyle(
                                          fontFamily: AppTheme.fontFamily,
                                          fontSize: 11,
                                          color: AppTheme.textLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Switch.adaptive(
                                value: _isAvailable,
                                activeTrackColor: AppTheme.primaryPink,
                                onChanged: (val) {
                                  setState(() {
                                    _isAvailable = val;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ] else ...[
                        const SizedBox(height: 8),
                      ],

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.textMedium,
                                side: const BorderSide(color: Color(0xFFFFD1DC)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                'Batal',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: _submit,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_rounded, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    isEditing ? 'Simpan Perubahan' : 'Tambah Menu',
                                    style: const TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
