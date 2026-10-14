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

enum _UnsavedAction { save, discard }

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
  bool _isProcessingImage = false;

  bool _allowPop = false;
  late final String _initialName;
  late final double? _initialPrice;
  late final int _initialStock;
  late final String _initialDescription;
  int? _initialSubCategoryId;
  String? _initialImagePath;
  late final bool _initialIsAvailable;
  final Map<String, double?> _initialCustomerPrices = {};

  @override
  void initState() {
    super.initState();
    final edit = widget.itemToEdit;

    _initialName = edit?.name ?? '';
    _initialPrice = edit?.price;
    _initialStock = edit?.stock ?? 20;
    _initialDescription = edit?.description ?? '';
    _initialImagePath = edit?.imagePath;
    _initialIsAvailable = edit?.isAvailable ?? true;

    _nameController = TextEditingController(text: _initialName);
    _priceController = TextEditingController(
      text: edit != null ? Formatters.formatNumber(edit.price.toInt()) : '',
    );
    _stockController = TextEditingController(
      text: edit != null ? edit.stock.toString() : '20',
    );
    _descriptionController = TextEditingController(text: _initialDescription);
    _imagePath = _initialImagePath;
    _isAvailable = _initialIsAvailable;

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
    _initialSubCategoryId = _selectedSubCategory?.id;
  }

  void _initCustomerPriceControllers() {
    final existingPrices = widget.itemToEdit?.customerPrices ?? {};
    for (final cat in _customerCategories) {
      if (!_customerPriceControllers.containsKey(cat.name)) {
        final customPrice = existingPrices[cat.name];
        _customerPriceControllers[cat.name] = TextEditingController(
          text: customPrice != null ? Formatters.formatNumber(customPrice.toInt()) : '',
        );
        _initialCustomerPrices[cat.name] = customPrice;
      }
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

  bool _hasUnsavedChanges() {
    if (widget.itemToEdit == null) {
      if (_nameController.text.trim().isNotEmpty) return true;
      final price = Formatters.parseCurrencyInput(_priceController.text);
      if (price != null && price > 0) return true;
      if (_descriptionController.text.trim().isNotEmpty) return true;
      if (_imagePath != null) return true;
      for (final controller in _customerPriceControllers.values) {
        final parsed = Formatters.parseCurrencyInput(controller.text);
        if (parsed != null && parsed > 0) return true;
      }
      return false;
    }

    if (_nameController.text.trim() != _initialName.trim()) return true;

    final currentPrice = Formatters.parseCurrencyInput(_priceController.text);
    if (currentPrice != _initialPrice) return true;

    final currentStock = int.tryParse(_stockController.text.trim()) ?? 0;
    if (currentStock != _initialStock) return true;

    if (_descriptionController.text.trim() != _initialDescription.trim()) return true;

    if (_selectedSubCategory?.id != _initialSubCategoryId) return true;

    if (_imagePath != _initialImagePath) return true;

    if (_isAvailable != _initialIsAvailable) return true;

    for (final cat in _customerCategories) {
      final currentCustom = Formatters.parseCurrencyInput(_customerPriceControllers[cat.name]?.text ?? '');
      final initialCustom = _initialCustomerPrices[cat.name];
      final cVal = (currentCustom != null && currentCustom > 0) ? currentCustom : null;
      final iVal = (initialCustom != null && initialCustom > 0) ? initialCustom : null;
      if (cVal != iVal) return true;
    }

    return false;
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

  bool _isPromptingUnsaved = false;

  void _handleBackOrClose() {
    if (_hasUnsavedChanges()) {
      _promptUnsavedChanges();
    } else {
      _allowPop = true;
      Navigator.of(context).pop();
    }
  }

  Future<void> _promptUnsavedChanges() async {
    if (_isPromptingUnsaved) return;
    _isPromptingUnsaved = true;

    try {
      final action = await showDialog<_UnsavedAction>(
        context: context,
        barrierDismissible: true,
        builder: (dialogCtx) {
          return Dialog(
            backgroundColor: AppTheme.surfaceWhite,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Container(
              width: 360,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFE65100),
                          size: 22,
                        ),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.close_rounded, color: AppTheme.textLight, size: 20),
                        onPressed: () => Navigator.pop(dialogCtx, null),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Perubahan Belum Disimpan',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Ada perubahan pada menu yang belum disimpan. Apakah Anda ingin menyimpan perubahan ini?',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.5,
                        color: AppTheme.textMedium,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.dangerRed,
                            side: const BorderSide(color: Color(0xFFFFCDD2)),
                            backgroundColor: const Color(0xFFFFF5F5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            minimumSize: const Size(0, 40),
                          ),
                          onPressed: () => Navigator.pop(dialogCtx, _UnsavedAction.discard),
                          child: const Text(
                            'Batal Ubah',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryPink,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            minimumSize: const Size(0, 40),
                          ),
                          onPressed: () => Navigator.pop(dialogCtx, _UnsavedAction.save),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_rounded, size: 16),
                              SizedBox(width: 5),
                              Text(
                                'Simpan',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
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
          );
        },
      );

      if (!mounted) return;

      if (action == _UnsavedAction.discard) {
        _allowPop = true;
        Navigator.of(context).pop();
      } else if (action == _UnsavedAction.save) {
        _allowPop = true;
        _submit();
        if (mounted) {
          _allowPop = false;
        }
      }
    } finally {
      _isPromptingUnsaved = false;
    }
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

    _allowPop = true;
    Navigator.of(context).pop(menuItem);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.itemToEdit != null;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomSafeArea = bottomInset > 0 ? 0.0 : MediaQuery.paddingOf(context).bottom;

    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_hasUnsavedChanges()) {
          _promptUnsavedChanges();
        } else {
          _allowPop = true;
          Navigator.of(context).pop();
        }
      },
      child: AnimatedPadding(
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
                      onPressed: _handleBackOrClose,
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
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: AppTheme.softPinkBackground,
                                  borderRadius: BorderRadius.circular(14),
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
                                        borderRadius: BorderRadius.circular(12.5),
                                        width: 100,
                                        height: 100,
                                      )
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(7),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: AppTheme.primaryPink.withValues(alpha: 0.15),
                                                  blurRadius: 6,
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.add_a_photo_rounded,
                                              color: AppTheme.primaryPink,
                                              size: 18,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          const Text(
                                            'Foto Menu\n(Opsional)',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontFamily: AppTheme.fontFamily,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.primaryPinkDark,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                              Positioned(
                                bottom: 2,
                                right: 2,
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryPink,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 1.5),
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              if (_isProcessingImage)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.4),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Center(
                                      child: SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
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
                      const SizedBox(height: 14),

                      // Kategori Dropdown (Auto sync)
                      const Text(
                        'Kategori',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceWhite,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFFE0E6), width: 1.2),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<SubCategoryModel>(
                            isDense: true,
                            value: _selectedSubCategory,
                            isExpanded: true,
                            hint: const Text(
                              'Pilih Kategori',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 12.5,
                                color: AppTheme.textLight,
                              ),
                            ),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.primaryPink, size: 20),
                            items: widget.subCategories.map((sub) {
                              return DropdownMenuItem<SubCategoryModel>(
                                value: sub,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                        color: AppTheme.primaryPink,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      sub.name,
                                      style: const TextStyle(
                                        fontFamily: AppTheme.fontFamily,
                                        fontSize: 12.5,
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
                                        fontSize: 12,
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
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                    prefixIconConstraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                                    hintText: 'masukkan nama menu',
                                    hintStyle: const TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 12.5,
                                      color: AppTheme.textLight,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    prefixIcon: Icon(
                                      widget.activeType == CategoryType.drink
                                          ? Icons.local_drink_rounded
                                          : Icons.restaurant_menu_rounded,
                                      color: AppTheme.primaryPinkLight,
                                      size: 18,
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
                                        fontSize: 12,
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
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primaryPinkDark,
                                  ),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                    prefixIconConstraints: BoxConstraints(minWidth: 34, minHeight: 34),
                                    hintText: '25.000',
                                    hintStyle: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 12.5,
                                      color: AppTheme.textLight,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    prefixText: 'Rp ',
                                    prefixStyle: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryPink,
                                    ),
                                    prefixIcon: Icon(Icons.payments_outlined, color: AppTheme.primaryPinkLight, size: 18),
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
                      // Stok Menu & Status Ketersediaan (Sejajar pada mode Edit Menu)
                      if (isEditing) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Stok Menu (Kiri)
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Text(
                                        'Stok Menu',
                                        style: TextStyle(
                                          fontFamily: AppTheme.fontFamily,
                                          fontSize: 12,
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
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: AppTheme.softPinkBackground,
                                          borderRadius: BorderRadius.circular(7),
                                          border: Border.all(color: const Color(0xFFFFE0E6)),
                                        ),
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          icon: const Icon(Icons.remove_rounded, color: AppTheme.primaryPinkDark, size: 15),
                                          onPressed: () {
                                            final current = int.tryParse(_stockController.text) ?? 0;
                                            if (current > 0) {
                                              _stockController.text = (current - 1).toString();
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: SizedBox(
                                          height: 32,
                                          child: TextFormField(
                                            controller: _stockController,
                                            keyboardType: TextInputType.number,
                                            textAlign: TextAlign.center,
                                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                            style: const TextStyle(
                                              fontFamily: AppTheme.fontFamily,
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.textDark,
                                            ),
                                            decoration: const InputDecoration(
                                              isDense: true,
                                              hintText: '0',
                                              contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 7),
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
                                      const SizedBox(width: 4),
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: AppTheme.softPinkBackground,
                                          borderRadius: BorderRadius.circular(7),
                                          border: Border.all(color: const Color(0xFFFFE0E6)),
                                        ),
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          icon: const Icon(Icons.add_rounded, color: AppTheme.primaryPinkDark, size: 15),
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
                            const SizedBox(width: 10),
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
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    height: 38,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: _isAvailable
                                          ? const Color(0xFFE8F5E9)
                                          : AppTheme.softPinkBackground.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(10),
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
                                                size: 16,
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  _isAvailable ? 'Tersedia' : 'Habis',
                                                  style: TextStyle(
                                                    fontFamily: AppTheme.fontFamily,
                                                    fontSize: 11.5,
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
                                          scale: 0.72,
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
                    ],
                  ),
                ),
              ),
            ),

            // Fixed Bottom Action Buttons
            Container(
              padding: EdgeInsets.fromLTRB(
                20,
                10,
                20,
                10 + bottomSafeArea,
              ),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceWhite,
                border: Border(
                  top: BorderSide(color: Color(0xFFFFE5EC), width: 1),
                ),
              ),
              child: Row(
                children: [
                    Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textMedium,
                        side: const BorderSide(color: Color(0xFFFFD1DC)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        minimumSize: const Size(0, 38),
                      ),
                      onPressed: _handleBackOrClose,
                      child: const Text(
                        'Batal',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        minimumSize: const Size(0, 38),
                      ),
                      onPressed: _submit,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_rounded, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            isEditing ? 'Simpan Perubahan' : 'Tambah Menu',
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildCustomerPricesSection() {
    if (_customerCategories.isEmpty) {
      return const SizedBox.shrink();
    }

    // Hitung berapa kategori yang memiliki harga khusus terisi
    int activeCustomCount = 0;
    for (final controller in _customerPriceControllers.values) {
      final parsed = Formatters.parseCurrencyInput(controller.text);
      if (parsed != null && parsed > 0) {
        activeCustomCount++;
      }
    }
    final bool hasCustomPrices = activeCustomCount > 0;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasCustomPrices ? AppTheme.primaryPink.withValues(alpha: 0.35) : const Color(0xFFEBE8ED),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _showCustomerPricesDialog,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.softPinkBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.loyalty_outlined,
                    size: 17,
                    color: AppTheme.primaryPink,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Harga Khusus Kategori',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textDark,
                            ),
                          ),
                          if (!hasCustomPrices) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F1F4),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFDCDAE0)),
                              ),
                              child: const Text(
                                '(Default)',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textMedium,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasCustomPrices
                            ? '$activeCustomCount kategori diatur harga khusus'
                            : 'Harga mengikuti harga menu normal (Default)',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11,
                          color: hasCustomPrices ? AppTheme.primaryPinkDark : AppTheme.textMedium,
                          fontWeight: hasCustomPrices ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasCustomPrices) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.softPinkBackground,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFFD1DC)),
                    ),
                    child: Text(
                      '$activeCustomCount Diatur',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryPinkDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F4F6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E0E6)),
                    ),
                    child: const Text(
                      '(Default)',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMedium,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textLight,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCustomerPricesDialog() async {
    // Simpan snapshot teks harga saat ini agar dapat dibatalkan jika pengguna memilih 'Batal'
    final snapshot = <String, String>{};
    for (final cat in _customerCategories) {
      snapshot[cat.name] = _customerPriceControllers[cat.name]?.text ?? '';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Dialog(
              backgroundColor: AppTheme.surfaceWhite,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Container(
                width: 440,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Dialog
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 10, 12),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppTheme.softPinkBackground,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.loyalty_outlined,
                              size: 17,
                              color: AppTheme.primaryPink,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Harga Khusus Kategori',
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Atur harga menu untuk setiap kategori pelanggan',
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 11,
                                    color: AppTheme.textMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: AppTheme.textLight, size: 20),
                            onPressed: () => Navigator.pop(dialogContext, false),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFEBE8ED)),

                    // Body Input Form Kategori (Layout 2 kolom rapi seperti sebelumnya)
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
                        child: Builder(
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
                              children: [
                                for (int i = 0; i < pairs.length; i++)
                                  Padding(
                                    padding: EdgeInsets.only(bottom: i < pairs.length - 1 ? 6 : 0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: _buildCategoryPriceField(pairs[i][0], setDialogState),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: pairs[i].length > 1
                                              ? _buildCategoryPriceField(pairs[i][1], setDialogState)
                                              : const SizedBox.shrink(),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),

                    const Divider(height: 1, color: Color(0xFFEBE8ED)),

                    // Tombol Batal & Selesai
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext, false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.textMedium,
                                side: const BorderSide(color: Color(0xFFE2E0E6)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 11),
                              ),
                              child: const Text(
                                'Batal',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(dialogContext, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryPink,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 11),
                              ),
                              child: const Text(
                                'Selesai',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed != true) {
      // Kembalikan ke nilai sebelumnya jika batal/tutup tanpa simpan
      for (final entry in snapshot.entries) {
        if (_customerPriceControllers.containsKey(entry.key)) {
          _customerPriceControllers[entry.key]!.text = entry.value;
        }
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildCategoryPriceField(CustomerCategoryModel cat, StateSetter setDialogState) {
    final controller = _customerPriceControllers.putIfAbsent(
      cat.name,
      () => TextEditingController(),
    );

    final parsedPrice = Formatters.parseCurrencyInput(controller.text);
    final bool hasCustom = parsedPrice != null && parsedPrice > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
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
            ),
            if (!hasCustom) ...[
              const SizedBox(width: 4),
              const Text(
                '(Default)',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textLight,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        // Price Input Field directly beneath
        SizedBox(
          height: 38,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [CurrencyInputFormatter()],
            onChanged: (val) => setDialogState(() {}),
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryPinkDark,
            ),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              hintText: 'Default',
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
