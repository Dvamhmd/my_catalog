import 'dart:async';
import 'package:flutter/material.dart';
import '../dialogs/add_edit_menu_dialog.dart';
import '../dialogs/manage_sub_category_dialog.dart';
import '../dialogs/menu_detail_dialog.dart';
import '../models/category_type.dart';
import '../models/layout_mode.dart';
import '../models/menu_item_model.dart';
import '../models/sub_category_model.dart';
import '../services/database_service.dart';
import '../services/preference_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
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

  List<SubCategoryModel> _foodSubCategories = const [];
  List<SubCategoryModel> _drinkSubCategories = const [];

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
      _loadMenuItems();
    }
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    try {
      final savedMode = await PreferenceService.getLayoutMode();
      _layoutMode = savedMode;

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

      if (mounted) {
        setState(() {
          _foodSubCategories = foodSubs;
          _drinkSubCategories = drinkSubs;

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

      if (mounted) {
        setState(() {
          _menuItems = items;
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

  List<SubCategoryModel> get _currentSubCategories =>
      _activeType == CategoryType.food ? _foodSubCategories : _drinkSubCategories;

  SubCategoryModel? get _currentSelectedSubCategory =>
      _activeType == CategoryType.food ? _selectedFoodSubCategory : _selectedDrinkSubCategory;

  void _selectSubCategory(SubCategoryModel? sub) {
    setState(() {
      if (_activeType == CategoryType.food) {
        _selectedFoodSubCategory = sub;
      } else {
        _selectedDrinkSubCategory = sub;
      }
    });
    _loadMenuItems();
  }

  // ==================== DIALOG TRIGGERS ====================

  void _openManageSubCategories() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return ManageSubCategoryDialog(
          activeType: _activeType,
          subCategories: _currentSubCategories,
          onAdd: (name) async {
            final newSub = SubCategoryModel(
              name: name,
              type: _activeType,
            );
            await _db.insertSubCategory(newSub);
            await _loadSubCategories();
            if (bottomSheetContext.mounted) {
              Navigator.pop(bottomSheetContext);
            }
            if (mounted) {
              _openManageSubCategories();
              _showFeedback('Sub kategori "$name" berhasil ditambahkan');
            }
          },
          onEdit: (subCategory, newName) async {
            final updated = subCategory.copyWith(name: newName);
            await _db.updateSubCategory(updated);
            await _loadSubCategories();
            await _loadMenuItems();
            if (bottomSheetContext.mounted) {
              Navigator.pop(bottomSheetContext);
            }
            if (mounted) {
              _openManageSubCategories();
              _showFeedback('Nama sub kategori diperbarui');
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
                _openManageSubCategories();
                _showFeedback('Sub kategori dihapus', isError: true);
              }
            }
          },
        );
      },
    );
  }

  void _openAddMenuDialog({MenuItemModel? itemToEdit}) {
    if (_currentSubCategories.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surfaceWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text(
            'Buat Sub Kategori Dahulu',
            style: TextStyle(fontFamily: AppTheme.fontFamily, fontWeight: FontWeight.w700),
          ),
          content: Text(
            'Untuk menambahkan menu ${_activeType.displayName}, Anda perlu membuat minimal satu sub kategori terlebih dahulu.',
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
              child: const Text('Buat Sub Kategori'),
            ),
          ],
        ),
      );
      return;
    }

    showModalBottomSheet<MenuItemModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return AddEditMenuDialog(
          activeType: _activeType,
          subCategories: _currentSubCategories,
          defaultSubCategory: _currentSelectedSubCategory ?? _currentSubCategories.first,
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

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Sub Category Pills Horizontal Bar
          _buildSubCategoryBar(),

          // Search Bar (if opened)
          if (_isSearchOpen) _buildSearchBar(),

          // Info Header (Count & Layout summary)
          _buildStatusBar(),

          // Main Catalog Grid / List
          Expanded(
            child: RefreshIndicator(
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
                  : _menuItems.isEmpty
                      ? _buildEmptyState()
                      : _buildMenuGrid(horizontalPad),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
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
        onPressed: () => _openAddMenuDialog(),
      ),
    );
  }

  // ==================== APP BAR ====================

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 20),
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
                    Text('🍱', style: TextStyle(fontSize: 15)),
                    SizedBox(width: 6),
                    Text('Makanan'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('🍹', style: TextStyle(fontSize: 15)),
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

  // ==================== SUB CATEGORY BAR ====================

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
            isSelected: selectedSub == null,
            onTap: () => _selectSubCategory(null),
          ),
          const SizedBox(width: 8),
          ...subCategories.map((sub) {
            final isSelected = selectedSub?.id == sub.id;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildFilterChip(
                label: sub.name,
                isSelected: isSelected,
                onTap: () => _selectSubCategory(sub),
              ),
            );
          }),
          ActionChip(
            avatar: const Icon(Icons.add_rounded, size: 16, color: AppTheme.primaryPink),
            label: const Text(
              'Sub Kategori',
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
            onPressed: _openManageSubCategories,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Text(
        label,
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

  // ==================== STATUS & LAYOUT INFO BAR ====================

  Widget _buildStatusBar() {
    final subName = _currentSelectedSubCategory?.name ?? 'Semua';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                '$subName (${_menuItems.length} menu)',
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMedium,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.softPinkBackground,
              borderRadius: BorderRadius.circular(8),
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
    return GestureDetector(
      onTap: () => _changeLayoutMode(mode),
      child: Container(
        padding: const EdgeInsets.all(4),
        margin: const EdgeInsets.symmetric(horizontal: 2),
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
    );
  }

  // ==================== MENU GRID / LIST ====================

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
            onEdit: () => _openAddMenuDialog(itemToEdit: item),
            onDelete: () => _confirmDeleteMenu(item),
            onToggleStatus: () async {
              if (item.id != null) {
                await _db.toggleAvailability(item.id!, item.isAvailable);
                await _loadMenuItems();
              }
            },
          );
        }

        return MenuCardMedium(
          key: ValueKey(item.id),
          item: item,
          onTap: () => _openDetailDialog(item),
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

  // ==================== EMPTY STATE ====================

  Widget _buildEmptyState() {
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
              child: Text(
                _activeType.emoji,
                style: const TextStyle(fontSize: 48),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty
                  ? 'Menu tidak ditemukan'
                  : 'Belum ada menu ${_activeType.displayName.toLowerCase()}',
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
                  ? 'Coba kata kunci lain'
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
              label: Text('Tambah ${_activeType.displayName} Baru'),
              onPressed: () => _openAddMenuDialog(),
            ),
          ],
        ),
      ),
    );
  }
}
