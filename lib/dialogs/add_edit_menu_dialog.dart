import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'image_cropper_dialog.dart';
import '../models/category_type.dart';
import '../models/customer_category_model.dart';
import '../models/menu_item_model.dart';
import '../models/sub_category_model.dart';
import '../services/database_service.dart';
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
  late TextEditingController _stockController;
  late TextEditingController _descriptionController;

  SubCategoryModel? _selectedSubCategory;
  String? _imagePath;
  bool _isAvailable = true;

  final ImagePicker _picker = ImagePicker();

  List<CustomerCategoryModel> _customerCategories = [];
  final Map<String, TextEditingController> _customerPriceControllers = {};
  bool _isCustomerPricesExpanded = false;
  bool _isProcessingImage = false;

  @override
  void initState() {
    super.initState();
    final edit = widget.itemToEdit;

    _nameController = TextEditingController(text: edit?.name ?? '');
    _priceController = TextEditingController(
      text: edit != null ? Formatters.formatNumber(edit.price.toInt()) : '',
    );
    _stockController = TextEditingController(
      text: edit != null ? edit.stock.toString() : '20',
    );
    _descriptionController = TextEditingController(text: edit?.description ?? '');
    _imagePath = edit?.imagePath;
    _isAvailable = edit?.isAvailable ?? true;

    // Initialize customer categories and prices
    _customerCategories = List.from(DatabaseService.instance.cachedCustomerCategories);
    _initCustomerPriceControllers();
    _loadCustomerCategoriesAsync();

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

  void _initCustomerPriceControllers() {
    final existingPrices = widget.itemToEdit?.customerPrices ?? {};
    for (final cat in _customerCategories) {
      if (!_customerPriceControllers.containsKey(cat.name)) {
        final customPrice = existingPrices[cat.name];
        _customerPriceControllers[cat.name] = TextEditingController(
          text: customPrice != null ? Formatters.formatNumber(customPrice.toInt()) : '',
        );
      }
    }
    if (existingPrices.isNotEmpty) {
      _isCustomerPricesExpanded = true;
    }
  }

  Future<void> _loadCustomerCategoriesAsync() async {
    final cats = await DatabaseService.instance.getCustomerCategories();
    if (mounted) {
      setState(() {
        _customerCategories = cats;
        _initCustomerPriceControllers();
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _descriptionController.dispose();
    for (final c in _customerPriceControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _isProcessingImage = true);
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 88,
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
    } finally {
      if (mounted) {
        setState(() => _isProcessingImage = false);
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

    final stock = int.tryParse(_stockController.text.trim()) ?? 0;

    // Collect custom customer category prices
    final customerPrices = <String, double>{};
    for (final entry in _customerPriceControllers.entries) {
      final parsed = Formatters.parseCurrencyInput(entry.value.text);
      if (parsed != null && parsed > 0) {
        customerPrices[entry.key] = parsed;
      }
    }

    final menuItem = MenuItemModel(
      id: widget.itemToEdit?.id,
      name: _nameController.text.trim(),
      price: price,
      customerPrices: customerPrices,
      imagePath: _imagePath,
      subCategoryId: _selectedSubCategory!.id!,
      subCategoryName: _selectedSubCategory!.name,
      type: widget.activeType,
      stock: stock,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      isAvailable: _isAvailable && stock > 0,
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
                                height: 140,
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
                                        height: 140,
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
                              if (_isProcessingImage)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.4),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: const Center(
                                      child: SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.8,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      ),
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

                      // Nama Menu & Harga Menu (Sejajar dalam 1 Baris)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Nama Menu (Wajib)
                          Expanded(
                            flex: 6,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                                  decoration: InputDecoration(
                                    hintText: 'masukkan nama menu',
                                    prefixIcon: Icon(
                                      widget.activeType == CategoryType.drink
                                          ? Icons.local_drink_rounded
                                          : Icons.restaurant_menu_rounded,
                                      color: AppTheme.primaryPinkLight,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Nama menu wajib diisi';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Harga (Wajib)
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                                  inputFormatters: [CurrencyInputFormatter()],
                                  style: const TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primaryPinkDark,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: '25.000',
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
                                    final parsed = Formatters.parseCurrencyInput(value);
                                    if (parsed == null || parsed <= 0) {
                                      return 'Harga harus berupa angka valid';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Harga Khusus Kategori Pelanggan (Opsional)
                      _buildCustomerPricesSection(),
                      const SizedBox(height: 16),

                      // Stok Menu & Status Ketersediaan (Sejajar pada mode Edit Menu)
                      if (isEditing) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Stok Menu (Kiri)
                            Expanded(
                              flex: 6,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Text(
                                        'Stok Menu',
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
                                  Row(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: AppTheme.softPinkBackground,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFFFFE0E6)),
                                        ),
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(Icons.remove_rounded, color: AppTheme.primaryPinkDark, size: 20),
                                          onPressed: () {
                                            final current = int.tryParse(_stockController.text) ?? 0;
                                            if (current > 0) {
                                              _stockController.text = (current - 1).toString();
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: SizedBox(
                                          height: 44,
                                          child: TextFormField(
                                            controller: _stockController,
                                            keyboardType: TextInputType.number,
                                            textAlign: TextAlign.center,
                                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                            style: const TextStyle(
                                              fontFamily: AppTheme.fontFamily,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.textDark,
                                            ),
                                            decoration: const InputDecoration(
                                              hintText: '0',
                                              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                                            ),
                                            validator: (value) {
                                              if (value == null || value.trim().isEmpty) {
                                                return 'Stok wajib diisi';
                                              }
                                              final parsed = int.tryParse(value);
                                              if (parsed == null || parsed < 0) {
                                                return 'Angka valid';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        width: 38,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: AppTheme.softPinkBackground,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFFFFE0E6)),
                                        ),
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(Icons.add_rounded, color: AppTheme.primaryPinkDark, size: 20),
                                          onPressed: () {
                                            final current = int.tryParse(_stockController.text) ?? 0;
                                            _stockController.text = (current + 1).toString();
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Menu Tersedia Toggle (Kanan)
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Status Menu',
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    height: 44,
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: _isAvailable
                                          ? const Color(0xFFE8F5E9)
                                          : AppTheme.softPinkBackground.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _isAvailable ? const Color(0xFFC8E6C9) : const Color(0xFFFFE0E6),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Icon(
                                                _isAvailable ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                                color: _isAvailable ? AppTheme.successGreen : AppTheme.textLight,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  _isAvailable ? 'Tersedia' : 'Habis',
                                                  style: TextStyle(
                                                    fontFamily: AppTheme.fontFamily,
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: _isAvailable ? AppTheme.textDark : AppTheme.textMedium,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Transform.scale(
                                          scale: 0.8,
                                          child: Switch.adaptive(
                                            value: _isAvailable,
                                            activeTrackColor: AppTheme.primaryPink,
                                            onChanged: (val) {
                                              setState(() {
                                                _isAvailable = val;
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _isAvailable ? 'Dapat dipesan pelanggan' : 'Disembunyikan / tidak aktif',
                                    style: const TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 10.5,
                                      color: AppTheme.textLight,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        // Tambah Menu Baru: Stok Menu (Tampilan full-width)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Text(
                                  'Stok Menu',
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
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: AppTheme.softPinkBackground,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFFFE0E6)),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.remove_rounded, color: AppTheme.primaryPinkDark, size: 20),
                                onPressed: () {
                                  final current = int.tryParse(_stockController.text) ?? 0;
                                  if (current > 0) {
                                    _stockController.text = (current - 1).toString();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _stockController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                style: const TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textDark,
                                ),
                                decoration: const InputDecoration(
                                  hintText: '0',
                                  suffixText: 'porsi',
                                  suffixStyle: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 12,
                                    color: AppTheme.textMedium,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Stok wajib diisi';
                                  }
                                  final parsed = int.tryParse(value);
                                  if (parsed == null || parsed < 0) {
                                    return 'Stok harus berupa angka';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: AppTheme.softPinkBackground,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFFFE0E6)),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.add_rounded, color: AppTheme.primaryPinkDark, size: 20),
                                onPressed: () {
                                  final current = int.tryParse(_stockController.text) ?? 0;
                                  _stockController.text = (current + 1).toString();
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
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
                      const SizedBox(height: 20),

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

  Widget _buildCustomerPricesSection() {
    if (_customerCategories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEBE8ED), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              setState(() {
                _isCustomerPricesExpanded = !_isCustomerPricesExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: AppTheme.softPinkBackground,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.loyalty_outlined,
                      size: 15,
                      color: AppTheme.primaryPink,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Harga Khusus Kategori',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isCustomerPricesExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOutCubic,
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppTheme.textLight,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              child: _isCustomerPricesExpanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 1, color: Color(0xFFEBE8ED)),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Kosongkan kolom bila harga sama dengan harga normal menu.',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 11,
                                  color: AppTheme.textLight,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Builder(
                                builder: (context) {
                                  final orderedCats = List<CustomerCategoryModel>.from(_customerCategories);
                                  orderedCats.sort((a, b) {
                                    int getPriority(String name) {
                                      final lower = name.toLowerCase();
                                      if (lower.contains('member')) return 1;
                                      if (lower.contains('karyawan')) return 2;
                                      if (lower.contains('gofood')) return 3;
                                      if (lower.contains('grab')) return 4;
                                      return 5;
                                    }

                                    final pA = getPriority(a.name);
                                    final pB = getPriority(b.name);
                                    if (pA != pB) return pA.compareTo(pB);
                                    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
                                  });

                                  final List<List<CustomerCategoryModel>> pairs = [];
                                  for (int i = 0; i < orderedCats.length; i += 2) {
                                    pairs.add([
                                      orderedCats[i],
                                      if (i + 1 < orderedCats.length) orderedCats[i + 1],
                                    ]);
                                  }

                                  return Column(
                                    children: pairs.map((pair) {
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: _buildCategoryPriceField(pair[0]),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: pair.length > 1
                                                  ? _buildCategoryPriceField(pair[1])
                                                  : const SizedBox.shrink(),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : const SizedBox(width: double.infinity, height: 0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPriceField(CustomerCategoryModel cat) {
    final controller = _customerPriceControllers.putIfAbsent(
      cat.name,
      () => TextEditingController(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          cat.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 4),
        // Price Input Field directly beneath
        SizedBox(
          height: 38,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [CurrencyInputFormatter()],
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryPinkDark,
            ),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              hintText: 'Sama normal',
              hintStyle: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 11,
                color: AppTheme.textLight,
                fontWeight: FontWeight.normal,
              ),
              prefixText: 'Rp ',
              prefixStyle: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryPink,
              ),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E0E6)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E0E6)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.primaryPink, width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
