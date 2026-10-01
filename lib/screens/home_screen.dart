import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../dialogs/add_edit_menu_dialog.dart';
import '../dialogs/image_cropper_dialog.dart';
import '../dialogs/manage_sub_category_dialog.dart';
import '../dialogs/menu_detail_dialog.dart';
import '../models/category_type.dart';
import '../models/layout_mode.dart';
import '../models/menu_item_model.dart';
import '../models/sub_category_model.dart';
import '../models/sub_category_view_mode.dart';
import '../services/database_service.dart';
import '../services/preference_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/custom_image_view.dart';
import '../widgets/folder_card_large.dart';
import '../widgets/folder_card_medium.dart';
import '../widgets/folder_card_small.dart';
import '../widgets/menu_card_large.dart';
import '../widgets/menu_card_medium.dart';
import '../widgets/menu_card_small.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final DatabaseService _db = DatabaseService.instance;

  CategoryType _activeType = CategoryType.food;
  LayoutMode _layoutMode = LayoutMode.medium; // Default 2 columns (Sedang)
  SubCategoryViewMode _subCategoryViewMode = SubCategoryViewMode.tab; // Default Tab

  List<SubCategoryModel> _foodSubCategories = const [];
  List<SubCategoryModel> _drinkSubCategories = const [];
  Map<int, int> _subCategoryCounts = {};

  SubCategoryModel? _selectedFoodSubCategory;
  SubCategoryModel? _selectedDrinkSubCategory;

  List<MenuItemModel> _menuItems = const [];
  bool _isLoading = true;

  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);

    _initData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging || _tabController.index != _activeType.index) {
      setState(() {
        _activeType = _tabController.index == 0 ? CategoryType.food : CategoryType.drink;
      });
      _loadSubCategories();
      _loadMenuItems();
    }
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    try {
      final savedMode = await PreferenceService.getLayoutMode();
      final savedViewMode = await PreferenceService.getSubCategoryViewMode();
      _layoutMode = savedMode;
      _subCategoryViewMode = savedViewMode;

      await _db.initialize();
      await _loadSubCategories();
      await _loadMenuItems();
    } catch (e) {
      debugPrint('Error during _initData: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadSubCategories() async {
    try {
      final foodSubs = await _db.getSubCategories(CategoryType.food);
      final drinkSubs = await _db.getSubCategories(CategoryType.drink);
      final counts = await _db.getSubCategoryItemCounts(_activeType);

      if (mounted) {
        setState(() {
          _foodSubCategories = foodSubs;
          _drinkSubCategories = drinkSubs;
          _subCategoryCounts = counts;

          // Verify active selected sub categories still exist
          if (_selectedFoodSubCategory != null &&
              !_foodSubCategories.any((s) => s.id == _selectedFoodSubCategory!.id)) {
            _selectedFoodSubCategory = null;
          }
          if (_selectedDrinkSubCategory != null &&
              !_drinkSubCategories.any((s) => s.id == _selectedDrinkSubCategory!.id)) {
            _selectedDrinkSubCategory = null;
          }
        });
      }
    } catch (e) {
      debugPrint('Error in _loadSubCategories: $e');
    }
  }

  Future<void> _loadMenuItems() async {
    try {
      final activeSub = _activeType == CategoryType.food
          ? _selectedFoodSubCategory
          : _selectedDrinkSubCategory;

      final items = await _db.getMenuItems(
        type: _activeType,
        subCategoryId: activeSub?.id,
        searchQuery: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      );

      final counts = await _db.getSubCategoryItemCounts(_activeType);

      if (mounted) {
        setState(() {
          _menuItems = items;
          _subCategoryCounts = counts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error in _loadMenuItems: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        _loadMenuItems();
      }
    });
  }

  void _changeLayoutMode(LayoutMode mode) {
    setState(() {
      _layoutMode = mode;
    });
    PreferenceService.saveLayoutMode(mode);
  }

  void _changeSubCategoryViewMode(SubCategoryViewMode mode) {
    setState(() {
      _subCategoryViewMode = mode;
    });
    PreferenceService.saveSubCategoryViewMode(mode);
  }

  List<SubCategoryModel> get _currentSubCategories =>
      _activeType == CategoryType.food ? _foodSubCategories : _drinkSubCategories;

  SubCategoryModel? get _currentSelectedSubCategory =>
      _activeType == CategoryType.food ? _selectedFoodSubCategory : _selectedDrinkSubCategory;

  Future<void> _selectSubCategory(SubCategoryModel? sub) async {
    try {
      final items = await _db.getMenuItems(
        type: _activeType,
        subCategoryId: sub?.id,
        searchQuery: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      );
      final counts = await _db.getSubCategoryItemCounts(_activeType);

      if (mounted) {
        setState(() {
          if (_activeType == CategoryType.food) {
            _selectedFoodSubCategory = sub;
          } else {
            _selectedDrinkSubCategory = sub;
          }
          _menuItems = items;
          _subCategoryCounts = counts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error in _selectSubCategory: $e');
      if (mounted) {
        setState(() {
          if (_activeType == CategoryType.food) {
            _selectedFoodSubCategory = sub;
          } else {
            _selectedDrinkSubCategory = sub;
          }
        });
        _loadMenuItems();
      }
    }
  }

  // ==================== DIALOG TRIGGERS ====================

  final ImagePicker _imagePicker = ImagePicker();

  Future<void> _pickImageSource(ImageSource source, {required Function(String path) onPicked}) async {
    try {
      final XFile? file = await _imagePicker.pickImage(
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

  void _showImageSourceSheet({
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
                  _pickImageSource(ImageSource.camera, onPicked: onPicked);
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
                  _pickImageSource(ImageSource.gallery, onPicked: onPicked);
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

  void _openPhotoPickerForCategory(SubCategoryModel subCategory) {
    final hasPhoto = subCategory.imagePath != null && subCategory.imagePath!.isNotEmpty;
    _showImageSourceSheet(
      hasPhoto: hasPhoto,
      onPicked: (path) async {
        final updated = subCategory.copyWith(imagePath: path);
        await _db.updateSubCategory(updated);
        await _loadSubCategories();
        _showFeedback('Foto kategori "${subCategory.name}" berhasil diubah');
      },
      onRemove: () async {
        final updated = subCategory.copyWith(clearImage: true);
        await _db.updateSubCategory(updated);
        await _loadSubCategories();
        _showFeedback('Foto kategori dikembalikan ke icon default');
      },
    );
  }

  void _showCategoryActionSheet(SubCategoryModel subCategory) {
    final count = _subCategoryCounts[subCategory.id] ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 38,
                  height: 4.5,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),

                // Category Preview Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppTheme.softPinkBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFFFD1DC),
                            width: 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: CustomImageView(
                            imagePath: subCategory.imagePath,
                            type: subCategory.type,
                            isCategory: true,
                            width: 46,
                            height: 46,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subCategory.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: AppTheme.textDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Kategori ${_activeType.displayName} • $count menu',
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFF0F0F2)),
                const SizedBox(height: 4),

                // Action 1: Ubah Nama Kategori
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                  leading: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppTheme.softPinkBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      color: AppTheme.primaryPinkDark,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Ubah Nama Kategori',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppTheme.textDark,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    _openEditSubCategoryDialog(subCategory);
                  },
                ),

                // Action 2: Ganti Foto Kategori
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                  leading: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppTheme.softPinkBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.add_a_photo_outlined,
                      color: AppTheme.primaryPinkDark,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Ganti Foto Kategori',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppTheme.textDark,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    _openPhotoPickerForCategory(subCategory);
                  },
                ),

                // Action 3: Hapus Kategori
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                  leading: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppTheme.dangerRed,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Hapus Kategori',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppTheme.dangerRed,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    _confirmDeleteSubCategory(subCategory);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDeleteSubCategory(SubCategoryModel subCategory) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Hapus Kategori?',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus kategori "${subCategory.name}"? Semua menu di dalam kategori ini juga akan ikut terhapus.',
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: AppTheme.textMedium)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            onPressed: () async {
              Navigator.pop(ctx);
              if (subCategory.id != null) {
                await _db.deleteSubCategory(subCategory.id!);
                await _loadSubCategories();
                await _loadMenuItems();
                if (mounted) {
                  _showFeedback('Kategori "${subCategory.name}" dihapus', isError: true);
                }
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _openEditSubCategoryDialog(SubCategoryModel subCategory) {
    final nameController = TextEditingController(text: subCategory.name);
    String? currentImagePath = subCategory.imagePath;
    bool clearImage = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
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
                  GestureDetector(
                    onTap: () {
                      _showImageSourceSheet(
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
                          width: 80,
                          height: 80,
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
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            color: AppTheme.primaryPink,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: () {
                      _showImageSourceSheet(
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
                      hasImg ? 'Ganti Foto' : 'Pilih Foto',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryPink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Nama Kategori',
                      prefixIcon: Icon(subCategory.type.icon, color: AppTheme.primaryPinkLight),
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
                onPressed: () async {
                  final newName = nameController.text.trim();
                  if (newName.isNotEmpty) {
                    Navigator.pop(ctx);
                    final updated = subCategory.copyWith(
                      name: newName,
                      imagePath: currentImagePath,
                      clearImage: clearImage,
                    );
                    await _db.updateSubCategory(updated);
                    await _loadSubCategories();
                    await _loadMenuItems();
                    _showFeedback('Kategori "$newName" berhasil diperbarui');
                  }
                },
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openManageSubCategories() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return ManageSubCategoryDialog(
          activeType: _activeType,
          subCategories: _currentSubCategories,
          onAdd: (name, imagePath) async {
            final newSub = SubCategoryModel(
              name: name,
              type: _activeType,
              imagePath: imagePath,
            );
            await _db.insertSubCategory(newSub);
            await _loadSubCategories();
            if (bottomSheetContext.mounted) {
              Navigator.pop(bottomSheetContext);
            }
            if (mounted) {
              _showFeedback('Kategori "$name" berhasil ditambahkan');
            }
          },
          onEdit: (subCategory, newName, newImagePath, clearImage) async {
            final updated = subCategory.copyWith(
              name: newName,
              imagePath: newImagePath,
              clearImage: clearImage,
            );
            await _db.updateSubCategory(updated);
            await _loadSubCategories();
            await _loadMenuItems();
            if (bottomSheetContext.mounted) {
              Navigator.pop(bottomSheetContext);
            }
            if (mounted) {
              _showFeedback('Kategori "$newName" diperbarui');
            }
          },
          onDelete: (subCategory) async {
            if (subCategory.id != null) {
              await _db.deleteSubCategory(subCategory.id!);
              await _loadSubCategories();
              await _loadMenuItems();
              if (bottomSheetContext.mounted) {
                Navigator.pop(bottomSheetContext);
              }
              if (mounted) {
                _showFeedback('Kategori dihapus', isError: true);
              }
            }
          },
        );
      },
    );
  }

  void _openAddSubCategoryQuick() {
    final nameController = TextEditingController();
    String? categoryImagePath;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final isFood = _activeType == CategoryType.food;
          final categoryIcon = _activeType.icon;

          return AlertDialog(
            backgroundColor: AppTheme.surfaceWhite,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.softPinkBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(categoryIcon, color: AppTheme.primaryPinkDark, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  'Tambah Kategori ${_activeType.displayName}',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      _showImageSourceSheet(
                        hasPhoto: categoryImagePath != null,
                        onPicked: (path) {
                          setDialogState(() {
                            categoryImagePath = path;
                          });
                        },
                        onRemove: () {
                          setDialogState(() {
                            categoryImagePath = null;
                          });
                        },
                      );
                    },
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: AppTheme.softPinkBackground,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: categoryImagePath != null ? AppTheme.primaryPink : const Color(0xFFFFD1DC),
                              width: 1.5,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: CustomImageView(
                              imagePath: categoryImagePath,
                              type: _activeType,
                              isCategory: true,
                              width: 76,
                              height: 76,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            color: AppTheme.primaryPink,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: () {
                      _showImageSourceSheet(
                        hasPhoto: categoryImagePath != null,
                        onPicked: (path) {
                          setDialogState(() {
                            categoryImagePath = path;
                          });
                        },
                        onRemove: () {
                          setDialogState(() {
                            categoryImagePath = null;
                          });
                        },
                      );
                    },
                    icon: const Icon(Icons.photo_camera_outlined, size: 16, color: AppTheme.primaryPink),
                    label: Text(
                      categoryImagePath != null ? 'Ganti Foto' : 'Pilih Foto (Opsional)',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryPink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Nama Kategori',
                      hintText: isFood ? 'Contoh: Makanan Utama, Snack...' : 'Contoh: Kopi, Jus Segar...',
                      prefixIcon: Icon(categoryIcon, color: AppTheme.primaryPinkLight),
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
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isNotEmpty) {
                    Navigator.pop(ctx);
                    final newSub = SubCategoryModel(
                      name: name,
                      type: _activeType,
                      imagePath: categoryImagePath,
                    );
                    await _db.insertSubCategory(newSub);
                    await _loadSubCategories();
                    _showFeedback('Kategori "$name" berhasil dibuat');
                  }
                },
                child: const Text('Simpan Kategori'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openAddMenuDialog({MenuItemModel? itemToEdit, SubCategoryModel? presetSubCategory}) {
    if (_currentSubCategories.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surfaceWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text(
            'Buat Kategori Dahulu',
            style: TextStyle(fontFamily: AppTheme.fontFamily, fontWeight: FontWeight.w700),
          ),
          content: Text(
            'Untuk menambahkan menu ${_activeType.displayName}, Anda perlu membuat minimal satu kategori terlebih dahulu.',
            style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Nanti', style: TextStyle(color: AppTheme.textMedium)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _openManageSubCategories();
              },
              child: const Text('Buat Kategori'),
            ),
          ],
        ),
      );
      return;
    }

    final defaultSub = presetSubCategory ?? _currentSelectedSubCategory ?? _currentSubCategories.first;

    showModalBottomSheet<MenuItemModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return AddEditMenuDialog(
          activeType: _activeType,
          subCategories: _currentSubCategories,
          defaultSubCategory: defaultSub,
          itemToEdit: itemToEdit,
        );
      },
    ).then((resultItem) async {
      if (resultItem != null) {
        if (itemToEdit != null) {
          await _db.updateMenuItem(resultItem);
          _showFeedback('Menu "${resultItem.name}" berhasil diperbarui');
        } else {
          await _db.insertMenuItem(resultItem);
          _showFeedback('Menu "${resultItem.name}" berhasil ditambahkan');
        }
        await _loadSubCategories();
        await _loadMenuItems();
      }
    });
  }

  void _openDetailDialog(MenuItemModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return MenuDetailDialog(
          item: item,
          onEdit: () => _openAddMenuDialog(itemToEdit: item),
          onDelete: () => _confirmDeleteMenu(item),
          onToggleStatus: () async {
            if (item.id != null) {
              await _db.toggleAvailability(item.id!, item.isAvailable);
              await _loadMenuItems();
            }
          },
        );
      },
    );
  }

  void _confirmDeleteMenu(MenuItemModel item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Hapus Menu?',
          style: TextStyle(fontFamily: AppTheme.fontFamily, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus "${item.name}" dari katalog?',
          style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: AppTheme.textMedium)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            onPressed: () async {
              Navigator.pop(ctx);
              if (item.id != null) {
                await _db.deleteMenuItem(item.id!);
                await _loadSubCategories();
                await _loadMenuItems();
                _showFeedback('Menu berhasil dihapus', isError: true);
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _showFeedback(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        backgroundColor: isError ? AppTheme.dangerRed : AppTheme.primaryPinkDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPad = Responsive.horizontalPadding(context);
    final isSearching = _searchController.text.trim().isNotEmpty;
    final isCategoryViewMode = _subCategoryViewMode == SubCategoryViewMode.category;
    final isViewingInsideCategory = isCategoryViewMode && _currentSelectedSubCategory != null && !isSearching;
    final isViewingCategoryList = isCategoryViewMode && _currentSelectedSubCategory == null && !isSearching;

    return PopScope(
      canPop: !isViewingInsideCategory && !_isSearchOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isSearchOpen) {
          setState(() {
            _isSearchOpen = false;
            _searchController.clear();
          });
          _loadMenuItems();
          return;
        }
        if (isViewingInsideCategory) {
          _selectSubCategory(null);
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            // Category Pills Horizontal Bar (Shown only in Tab Mode)
            if (_subCategoryViewMode == SubCategoryViewMode.tab && !isSearching)
              _buildSubCategoryBar(),

            // Category Breadcrumb (Shown only in Category Mode when inside a category)
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: isViewingInsideCategory
                  ? _buildCategoryBreadcrumb()
                  : const SizedBox.shrink(),
            ),

            // Search Bar (if opened)
            if (_isSearchOpen) _buildSearchBar(),

            // Status Bar (View Mode Toggle & Layout Mode Switcher)
            _buildStatusBar(isViewingCategoryList: isViewingCategoryList),

            // Main Catalog Grid / List with Clean Fade In / Fade Out Transition
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                reverseDuration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      ...previousChildren,
                      ?currentChild,
                    ],
                  );
                },
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                child: RefreshIndicator(
                  key: ValueKey(
                    isViewingCategoryList
                        ? 'category_grid_${_activeType.name}_${_layoutMode.name}'
                        : 'menu_grid_${_currentSelectedSubCategory?.id}_${_activeType.name}_${_layoutMode.name}_$isSearching',
                  ),
                  color: AppTheme.primaryPink,
                  backgroundColor: Colors.white,
                  onRefresh: () async {
                    await _loadSubCategories();
                    await _loadMenuItems();
                  },
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: AppTheme.primaryPink),
                        )
                      : isViewingCategoryList
                          ? (_currentSubCategories.isEmpty
                              ? _buildEmptyCategoryState()
                              : _buildCategoryGrid(horizontalPad))
                          : (_menuItems.isEmpty
                              ? _buildEmptyMenuState(isInsideCategory: isViewingInsideCategory)
                              : _buildMenuGrid(horizontalPad)),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: _buildFloatingActionButton(isViewingCategoryList: isViewingCategoryList),
      ),
    );
  }

  // ==================== APP BAR ====================

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/app_logo.png',
              width: 28,
              height: 28,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          const Text('My Catalog'),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Cari Menu',
          icon: Icon(
            _isSearchOpen ? Icons.search_off_rounded : Icons.search_rounded,
            color: Colors.white,
          ),
          onPressed: () {
            setState(() {
              _isSearchOpen = !_isSearchOpen;
              if (!_isSearchOpen) {
                _searchController.clear();
                _loadMenuItems();
              }
            });
          },
        ),
        IconButton(
          tooltip: _subCategoryViewMode == SubCategoryViewMode.tab
              ? 'Tampilan Tab'
              : 'Tampilan Kategori',
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(scale: anim, child: child),
            ),
            child: Icon(
              _subCategoryViewMode == SubCategoryViewMode.tab
                  ? Icons.tab_rounded
                  : Icons.category_rounded,
              key: ValueKey(_subCategoryViewMode),
              color: Colors.white,
            ),
          ),
          onPressed: () {
            final nextMode = _subCategoryViewMode == SubCategoryViewMode.tab
                ? SubCategoryViewMode.category
                : SubCategoryViewMode.tab;
            _changeSubCategoryViewMode(nextMode);
          },
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(58),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(25),
          ),
          child: TabBar(
            controller: _tabController,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              color: Colors.white,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            labelColor: AppTheme.primaryPinkDark,
            unselectedLabelColor: Colors.white,
            tabs: const [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.restaurant_rounded, size: 16),
                    SizedBox(width: 6),
                    Text('Makanan'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_bar_rounded, size: 16),
                    SizedBox(width: 6),
                    Text('Minuman'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== CATEGORY BAR (TAB MODE) ====================

  Widget _buildSubCategoryBar() {
    final subCategories = _currentSubCategories;
    final selectedSub = _currentSelectedSubCategory;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFFFEBF0), width: 1),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          _buildFilterChip(
            label: 'Semua',
            count: null,
            isSelected: selectedSub == null,
            onTap: () => _selectSubCategory(null),
          ),
          const SizedBox(width: 8),
          ...subCategories.map((sub) {
            final isSelected = selectedSub?.id == sub.id;
            final count = _subCategoryCounts[sub.id] ?? 0;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildFilterChip(
                label: sub.name,
                count: count,
                isSelected: isSelected,
                onTap: () => _selectSubCategory(sub),
              ),
            );
          }),
          ActionChip(
            avatar: const Icon(Icons.settings_outlined, size: 15, color: AppTheme.primaryPink),
            label: const Text(
              'Kelola Kategori',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryPink,
              ),
            ),
            backgroundColor: AppTheme.softPinkBackground,
            side: const BorderSide(color: Color(0xFFFFD1DC), width: 1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            onPressed: () => _openManageSubCategories(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    int? count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final text = count != null ? '$label ($count)' : label;
    return FilterChip(
      label: Text(
        text,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? Colors.white : AppTheme.textMedium,
        ),
      ),
      selected: isSelected,
      showCheckmark: false,
      backgroundColor: const Color(0xFFF7F5F6),
      selectedColor: AppTheme.primaryPink,
      side: BorderSide(
        color: isSelected ? AppTheme.primaryPink : const Color(0xFFEFECEE),
        width: 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      onSelected: (_) => onTap(),
    );
  }

  // ==================== CATEGORY BREADCRUMB (INSIDE CATEGORY) ====================

  Widget _buildCategoryBreadcrumb() {
    final sub = _currentSelectedSubCategory;
    if (sub == null) return const SizedBox.shrink();

    final categoryIcon = _activeType.icon;
    final count = _menuItems.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFFFEBF0), width: 1),
        ),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => _selectSubCategory(null),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.softPinkBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFD1DC), width: 1),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                size: 18,
                color: AppTheme.primaryPinkDark,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Icon(categoryIcon, size: 18, color: AppTheme.primaryPink),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              sub.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F5F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count menu',
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== SEARCH BAR ====================

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: Colors.white,
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13.5),
        decoration: InputDecoration(
          hintText: 'Cari menu ${_activeType.displayName.toLowerCase()}...',
          prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryPink),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18, color: AppTheme.textLight),
                  onPressed: () {
                    _searchController.clear();
                    _loadMenuItems();
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          fillColor: AppTheme.softPinkBackground.withValues(alpha: 0.4),
          filled: true,
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  // ==================== STATUS & CONTROLS BAR ====================

  Widget _buildStatusBar({required bool isViewingCategoryList}) {
    final subName = _currentSelectedSubCategory?.name ?? 'Semua';
    final isSearching = _searchController.text.trim().isNotEmpty;

    String statusText;
    if (isSearching) {
      statusText = '${_menuItems.length} hasil pencarian';
    } else if (isViewingCategoryList) {
      // Formatted as requested: "3 Kategori Makanan" or "3 Kategori Minuman"
      statusText = '${_currentSubCategories.length} Kategori ${_activeType.displayName}';
    } else {
      statusText = '$subName (${_menuItems.length} menu)';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left Status Label
          Expanded(
            child: Text(
              statusText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMedium,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Right Controls: Layout Mode Switcher (1 baris, 2 jajar, 3 jajar)
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: AppTheme.softPinkBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFE0E6), width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLayoutIconButton(LayoutMode.large),
                _buildLayoutIconButton(LayoutMode.medium),
                _buildLayoutIconButton(LayoutMode.small),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLayoutIconButton(LayoutMode mode) {
    final isSelected = _layoutMode == mode;
    return Tooltip(
      message: '${mode.label} (${mode.subtitle})',
      child: GestureDetector(
        onTap: () => _changeLayoutMode(mode),
        child: Container(
          padding: const EdgeInsets.all(4),
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryPink : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            mode.icon,
            size: 15,
            color: isSelected ? Colors.white : AppTheme.textLight,
          ),
        ),
      ),
    );
  }

  // ==================== CATEGORY GRID / LIST (PERBARIS, JAJAR 2, JAJAR 3) ====================

  Widget _buildCategoryGrid(double horizontalPad) {
    final subCategories = _currentSubCategories;

    if (_layoutMode == LayoutMode.large) {
      // 1 Kolom / Perbaris (List View)
      return ListView.separated(
        padding: EdgeInsets.only(
          left: horizontalPad,
          right: horizontalPad,
          top: 4,
          bottom: 90,
        ),
        itemCount: subCategories.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final sub = subCategories[index];
          final count = _subCategoryCounts[sub.id] ?? 0;
          return FolderCardLarge(
            key: ValueKey(sub.id),
            subCategory: sub,
            itemCount: count,
            onTap: () => _selectSubCategory(sub),
            onLongPress: () => _showCategoryActionSheet(sub),
          );
        },
      );
    }

    // 2 Kolom (Jajar 2) or 3 Kolom (Jajar 3)
    final aspectRatio = Responsive.getCardAspectRatio(
      context: context,
      columns: _layoutMode.columns,
    );

    return GridView.builder(
      padding: EdgeInsets.only(
        left: horizontalPad,
        right: horizontalPad,
        top: 4,
        bottom: 90,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _layoutMode.columns,
        crossAxisSpacing: _layoutMode == LayoutMode.small ? 8 : 12,
        mainAxisSpacing: _layoutMode == LayoutMode.small ? 8 : 12,
        childAspectRatio: aspectRatio,
      ),
      itemCount: subCategories.length,
      itemBuilder: (context, index) {
        final sub = subCategories[index];
        final count = _subCategoryCounts[sub.id] ?? 0;

        if (_layoutMode == LayoutMode.small) {
          return FolderCardSmall(
            key: ValueKey(sub.id),
            subCategory: sub,
            itemCount: count,
            onTap: () => _selectSubCategory(sub),
            onLongPress: () => _showCategoryActionSheet(sub),
          );
        }

        return FolderCardMedium(
          key: ValueKey(sub.id),
          subCategory: sub,
          itemCount: count,
          onTap: () => _selectSubCategory(sub),
          onLongPress: () => _showCategoryActionSheet(sub),
        );
      },
    );
  }

  // ==================== MENU GRID / LIST (PERBARIS, JAJAR 2, JAJAR 3) ====================

  Widget _buildMenuGrid(double horizontalPad) {
    final aspectRatio = Responsive.getCardAspectRatio(
      context: context,
      columns: _layoutMode.columns,
    );

    if (_layoutMode == LayoutMode.large) {
      return ListView.separated(
        padding: EdgeInsets.only(
          left: horizontalPad,
          right: horizontalPad,
          top: 4,
          bottom: 90,
        ),
        itemCount: _menuItems.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = _menuItems[index];
          return MenuCardLarge(
            key: ValueKey(item.id),
            item: item,
            onTap: () => _openDetailDialog(item),
          );
        },
      );
    }

    return GridView.builder(
      padding: EdgeInsets.only(
        left: horizontalPad,
        right: horizontalPad,
        top: 4,
        bottom: 90,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _layoutMode.columns,
        crossAxisSpacing: _layoutMode == LayoutMode.small ? 8 : 12,
        mainAxisSpacing: _layoutMode == LayoutMode.small ? 8 : 12,
        childAspectRatio: aspectRatio,
      ),
      itemCount: _menuItems.length,
      itemBuilder: (context, index) {
        final item = _menuItems[index];
        if (_layoutMode == LayoutMode.small) {
          return MenuCardSmall(
            key: ValueKey(item.id),
            item: item,
            onTap: () => _openDetailDialog(item),
          );
        }

        return MenuCardMedium(
          key: ValueKey(item.id),
          item: item,
          onTap: () => _openDetailDialog(item),
        );
      },
    );
  }

  // ==================== EMPTY STATES ====================

  Widget _buildEmptyCategoryState() {
    final categoryIcon = _activeType.icon;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppTheme.softPinkBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(categoryIcon, size: 48, color: AppTheme.primaryPinkDark),
            ),
            const SizedBox(height: 16),
            Text(
              'Belum ada kategori ${_activeType.displayName.toLowerCase()}',
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Buat kategori untuk mengelompokkan katalog menu Anda.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13,
                color: AppTheme.textMedium,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('Tambah Kategori ${_activeType.displayName} Baru'),
              onPressed: _openAddSubCategoryQuick,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyMenuState({bool isInsideCategory = false}) {
    final subName = _currentSelectedSubCategory?.name;
    final categoryIcon = _activeType.icon;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppTheme.softPinkBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(categoryIcon, size: 48, color: AppTheme.primaryPinkDark),
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty
                  ? 'Menu tidak ditemukan'
                  : isInsideCategory
                      ? 'Belum ada menu di kategori "$subName"'
                      : 'Belum ada menu ${_activeType.displayName.toLowerCase()}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchController.text.isNotEmpty
                  ? 'Coba kata kunci lain atau bersihkan pencarian.'
                  : isInsideCategory
                      ? 'Tambahkan menu baru langsung ke dalam kategori ini.'
                      : 'Mulai tambahkan menu favorit untuk katalog Anda.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13,
                color: AppTheme.textMedium,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                isInsideCategory
                    ? 'Tambah Menu di Kategori Ini'
                    : 'Tambah ${_activeType.displayName} Baru',
              ),
              onPressed: () => _openAddMenuDialog(presetSubCategory: _currentSelectedSubCategory),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== FLOATING ACTION BUTTON ====================

  Widget _buildFloatingActionButton({required bool isViewingCategoryList}) {
    if (isViewingCategoryList) {
      return FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryPink,
        foregroundColor: Colors.white,
        elevation: 3,
        highlightElevation: 6,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text(
          'Tambah Kategori ${_activeType.displayName}',
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
          ),
        ),
        onPressed: _openAddSubCategoryQuick,
      );
    }

    return FloatingActionButton.extended(
      backgroundColor: AppTheme.primaryPink,
      foregroundColor: Colors.white,
      elevation: 3,
      highlightElevation: 6,
      icon: const Icon(Icons.add_rounded, size: 22),
      label: Text(
        'Tambah ${_activeType.displayName}',
        style: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 13.5,
        ),
      ),
      onPressed: () => _openAddMenuDialog(presetSubCategory: _currentSelectedSubCategory),
    );
  }
}
