import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/category_type.dart';
import '../models/layout_mode.dart';
import '../models/menu_item_model.dart';
import '../models/sub_category_model.dart';
import '../models/sub_category_view_mode.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';
import '../services/preference_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/responsive.dart';
import '../widgets/app_drawer.dart';
import '../widgets/custom_image_view.dart';
import '../widgets/folder_card_large.dart';
import '../widgets/folder_card_medium.dart';
import '../widgets/folder_card_small.dart';
import '../widgets/kasir_menu_card_large.dart';
import '../widgets/kasir_menu_card_medium.dart';
import '../widgets/kasir_menu_card_small.dart';
import 'home_screen.dart';
import 'transaction_history_screen.dart';

enum PaymentMethod {
  cash('Cash', Icons.payments_rounded),
  qris('QRIS', Icons.qr_code_scanner_rounded);

  final String title;
  final IconData icon;
  const PaymentMethod(this.title, this.icon);
}


class KasirScreen extends StatefulWidget {
  const KasirScreen({super.key});

  @override
  State<KasirScreen> createState() => _KasirScreenState();
}

class _KasirScreenState extends State<KasirScreen> with TickerProviderStateMixin {
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

  // Cart: Map of MenuItemModel.id -> quantity
  final Map<int, int> _cart = {};
  // Registry info menu untuk item-item keranjang secara global lintas kategori/tab
  final Map<int, MenuItemModel> _cartItemDetails = {};

  // GlobalKey for cart target bounce and fly animation
  final GlobalKey _cartTargetKey = GlobalKey();
  late final AnimationController _cartBounceController;
  late final Animation<double> _cartBounceAnimation;

  // Active overlay entries to clean up safely on dispose
  final List<OverlayEntry> _activeFlyOverlays = [];
  final List<AnimationController> _activeFlyControllers = [];

  @override
  void initState() {
    super.initState();
    PreferenceService.saveLastActiveMenu(AppDrawerMenu.kasir);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);

    _cartBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _cartBounceAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.25)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.25, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 55,
      ),
    ]).animate(_cartBounceController);

    _initData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    _cartBounceController.dispose();

    for (final overlay in _activeFlyOverlays) {
      try {
        overlay.remove();
      } catch (_) {}
    }
    _activeFlyOverlays.clear();

    for (final controller in _activeFlyControllers) {
      try {
        controller.dispose();
      } catch (_) {}
    }
    _activeFlyControllers.clear();

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
      final allItems = await _db.getAllMenuItems();
      for (final item in allItems) {
        if (item.id != null) {
          _cartItemDetails[item.id!] = item;
        }
      }
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
        for (final item in items) {
          if (item.id != null) {
            _cartItemDetails[item.id!] = item;
          }
        }
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
        for (final item in items) {
          if (item.id != null) {
            _cartItemDetails[item.id!] = item;
          }
        }
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

  int get _totalItemsInCart => _cart.values.fold(0, (sum, qty) => sum + qty);

  double get _totalPriceInCart {
    double total = 0;
    for (final entry in _cart.entries) {
      final item = _findItemById(entry.key);
      if (item != null) {
        total += item.price * entry.value;
      }
    }
    return total;
  }

  MenuItemModel? _findItemById(int id) {
    if (_cartItemDetails.containsKey(id)) {
      return _cartItemDetails[id];
    }
    final match = _menuItems.where((m) => m.id == id);
    if (match.isNotEmpty) {
      _cartItemDetails[id] = match.first;
      return match.first;
    }
    final dbItem = _db.getCachedMenuItemById(id);
    if (dbItem != null) {
      _cartItemDetails[id] = dbItem;
      return dbItem;
    }
    return null;
  }

  // ==================== CART ACTIONS & JUMP-TO-CART ANIMATION ====================

  void _onAddToCartTapped(MenuItemModel item, BuildContext sourceContext) {
    if (item.id == null) return;
    if (item.stock <= 0 || !item.isAvailable) {
      StockLimitPopup.show(
        context,
        itemName: item.name,
        maxStock: 0,
        isOutOfStock: true,
      );
      return;
    }

    final currentQty = _cart[item.id!] ?? 0;
    if (currentQty >= item.stock) {
      StockLimitPopup.show(
        context,
        itemName: item.name,
        maxStock: item.stock,
      );
      return;
    }

    if (item.id != null) {
      _cartItemDetails[item.id!] = item;
    }

    // Trigger physical fly-to-cart jumping and shrinking animation
    _playFlyToCartAnimation(item, sourceContext);

    // Update cart state immediately for 0ms tactile responsiveness
    HapticFeedback.lightImpact();
    setState(() {
      _cart[item.id!] = currentQty + 1;
    });
  }

  void _decrementCart(int itemId) {
    final currentQty = _cart[itemId] ?? 0;
    if (currentQty <= 1) {
      setState(() => _cart.remove(itemId));
    } else {
      setState(() => _cart[itemId] = currentQty - 1);
    }
    HapticFeedback.lightImpact();
  }

  void _clearCart() {
    setState(() => _cart.clear());
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13),
        ),
        backgroundColor: AppTheme.textDark,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _playFlyToCartAnimation(MenuItemModel item, BuildContext sourceContext) {
    if (!mounted) return;

    final renderBox = sourceContext.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.attached) return;

    final startPos = renderBox.localToGlobal(Offset.zero);
    final startSize = renderBox.size;
    final startCenter = startPos + Offset(startSize.width / 2, startSize.height / 2);

    // Target position is the bottom cart summary / checkout button
    Offset targetCenter;
    final cartTargetBox = _cartTargetKey.currentContext?.findRenderObject() as RenderBox?;
    if (cartTargetBox != null && cartTargetBox.attached) {
      targetCenter = cartTargetBox.localToGlobal(Offset.zero) +
          Offset(cartTargetBox.size.width / 2, cartTargetBox.size.height / 2);
    } else {
      final screenSize = MediaQuery.sizeOf(context);
      targetCenter = Offset(screenSize.width - 55, screenSize.height - 42);
    }

    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    final flyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );

    _activeFlyControllers.add(flyController);

    entry = OverlayEntry(
      builder: (ctx) {
        return AnimatedBuilder(
          animation: flyController,
          builder: (context, child) {
            final t = flyController.value;

            // Parabolic jump arc: lifts item upwards by up to 110px before diving down
            final jumpOffset = 110.0 * math.sin(math.pi * t);

            // Smooth cubic horizontal and quad downward motion
            final currentX = lerpDouble(
              startCenter.dx,
              targetCenter.dx,
              Curves.easeInOutCubic.transform(t),
            )!;
            final baseY = lerpDouble(
              startCenter.dy,
              targetCenter.dy,
              Curves.easeInQuad.transform(t),
            )!;
            final currentY = baseY - jumpOffset;

            // Shrink ("mengecil"): slight bounce pop in first 12% then drops to 0.18
            final double scale;
            if (t < 0.12) {
              scale = lerpDouble(1.0, 1.10, t / 0.12)!;
            } else {
              scale = lerpDouble(1.10, 0.18, (t - 0.12) / 0.88)!;
            }

            // Natural rotational tilt while airborne
            final rotation = math.sin(math.pi * t) * 0.28;

            // Smooth fade out when entering the basket
            final opacity = t > 0.88 ? (1.0 - (t - 0.88) / 0.12).clamp(0.0, 1.0) : 1.0;

            const boxSize = 64.0;
            return Positioned(
              left: currentX - (boxSize / 2),
              top: currentY - (boxSize / 2),
              child: IgnorePointer(
                child: Opacity(
                  opacity: opacity,
                  child: Transform.rotate(
                    angle: rotation,
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        width: boxSize,
                        height: boxSize,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.primaryPink, width: 2.2),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryPink.withValues(alpha: 0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: CustomImageView(
                            imagePath: item.imagePath,
                            type: item.type,
                            width: boxSize,
                            height: boxSize,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    _activeFlyOverlays.add(entry);
    overlay.insert(entry);

    flyController.forward().then((_) {
      if (mounted) {
        // Impact feedback when menu enters the cart
        _cartBounceController.forward(from: 0.0);
        HapticFeedback.lightImpact();
      }
      try {
        entry.remove();
      } catch (_) {}
      _activeFlyOverlays.remove(entry);
      _activeFlyControllers.remove(flyController);
      flyController.dispose();
    });
  }

  // ==================== CHECKOUT & RECEIPT ====================

  void _openCheckoutSheet() async {
    if (_cart.isEmpty) {
      _showToast('Pilih menu terlebih dahulu');
      return;
    }

    final allItems = await _db.getAllMenuItems();
    for (final item in allItems) {
      if (item.id != null) {
        _cartItemDetails[item.id!] = item;
      }
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CheckoutModal(
        cart: Map.from(_cart),
        menuItems: allItems,
        itemResolver: (id) => _findItemById(id),
        onUpdateQty: (id, qty) {
          setState(() {
            if (qty <= 0) {
              _cart.remove(id);
            } else {
              _cart[id] = qty;
            }
          });
        },
        onCheckoutSuccess: (orderItems, method, cashGiven, change) {
          _clearCart();
          _loadMenuItems();
          _showReceiptDialog(orderItems, method, cashGiven, change);
        },
      ),
    );
  }

  void _showReceiptDialog(
    List<_OrderItemSummary> orderItems,
    PaymentMethod method,
    double cashGiven,
    double change,
  ) {
    final now = DateTime.now();
    final formattedTime =
        '${now.day}/${now.month}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final total = orderItems.fold(0.0, (sum, i) => sum + (i.price * i.qty));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.successGreen,
                  size: 36,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Pembayaran Berhasil!',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formattedTime,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  color: AppTheme.textLight,
                ),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFEAEAEA)),
              const SizedBox(height: 10),

              // Itemized list
              ...orderItems.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '${item.name} x${item.qty}',
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ),
                        Text(
                          Formatters.currency(item.price * item.qty),
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textDark,
                          ),
                        ),
                      ],
                    ),
                  )),

              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFEAEAEA)),
              const SizedBox(height: 10),

              // Total Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Tagihan',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                  ),
                  Text(
                    Formatters.currency(total),
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryPinkDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Metode',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      color: AppTheme.textMedium,
                    ),
                  ),
                  Text(
                    method.title,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                ],
              ),
              if (method == PaymentMethod.cash) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Uang Tunai',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        color: AppTheme.textMedium,
                      ),
                    ),
                    Text(
                      Formatters.currency(cashGiven),
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Kembalian',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.successGreen,
                      ),
                    ),
                    Text(
                      Formatters.currency(change),
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.successGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Transaksi Baru'),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== BUILD UI ====================

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
        drawer: AppDrawer(
          activeMenu: AppDrawerMenu.kasir,
          onSelectMenu: (menu) {
            PreferenceService.saveLastActiveMenu(menu);
            if (menu == AppDrawerMenu.admin) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
            } else if (menu == AppDrawerMenu.riwayatTransaksi) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const TransactionHistoryScreen()),
              );
            }
          },
          onDataChanged: () {
            _loadSubCategories();
            _loadMenuItems();
          },
        ),
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

            // Main Catalog Grid / List with Clean Fade Transition
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

            // Bottom Sticky Order Bar (Cart)
            _buildBottomOrderBar(),
          ],
        ),
      ),
    );
  }

  // ==================== APP BAR ====================

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/app_logo.webp',
              width: 28,
              height: 28,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          const Flexible(
            child: Text(
              'Menu Kasir',
              overflow: TextOverflow.ellipsis,
            ),
          ),
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
        if (_cart.isNotEmpty)
          IconButton(
            tooltip: 'Kosongkan Pesanan',
            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Kosongkan Pesanan?'),
                  content: const Text('Semua pilihan menu dalam pesanan ini akan dihapus.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _clearCart();
                      },
                      child: const Text('Kosongkan'),
                    ),
                  ],
                ),
              );
            },
          ),
        const SizedBox(width: 6),
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

  // ==================== CATEGORY GRID / LIST ====================

  Widget _buildCategoryGrid(double horizontalPad) {
    final subCategories = _currentSubCategories;

    if (_layoutMode == LayoutMode.large) {
      // 1 Kolom / Perbaris (List View)
      return ListView.separated(
        padding: EdgeInsets.only(
          left: horizontalPad,
          right: horizontalPad,
          top: 4,
          bottom: 110,
        ),
        itemCount: subCategories.length,
        separatorBuilder: (context, index) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          final sub = subCategories[index];
          final count = _subCategoryCounts[sub.id] ?? 0;
          return FolderCardLarge(
            key: ValueKey(sub.id),
            subCategory: sub,
            itemCount: count,
            onTap: () => _selectSubCategory(sub),
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
        bottom: 110,
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
          );
        }

        return FolderCardMedium(
          key: ValueKey(sub.id),
          subCategory: sub,
          itemCount: count,
          onTap: () => _selectSubCategory(sub),
        );
      },
    );
  }

  // ==================== MENU GRID / LIST (KASIR CARDS) ====================

  Widget _buildMenuGrid(double horizontalPad) {
    if (_layoutMode == LayoutMode.large) {
      return ListView.separated(
        padding: EdgeInsets.only(
          left: horizontalPad,
          right: horizontalPad,
          top: 4,
          bottom: 110,
        ),
        itemCount: _menuItems.length,
        separatorBuilder: (context, index) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          final item = _menuItems[index];
          final cartQty = _cart[item.id] ?? 0;
          return KasirMenuCardLarge(
            key: ValueKey(item.id),
            item: item,
            cartQty: cartQty,
            onAddToCart: (cardCtx) => _onAddToCartTapped(item, cardCtx),
            onDecrement: () => _decrementCart(item.id!),
          );
        },
      );
    }

    final aspectRatio = Responsive.getCardAspectRatio(
      context: context,
      columns: _layoutMode.columns,
    );

    return GridView.builder(
      padding: EdgeInsets.only(
        left: horizontalPad,
        right: horizontalPad,
        top: 4,
        bottom: 110,
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
        final cartQty = _cart[item.id] ?? 0;

        if (_layoutMode == LayoutMode.small) {
          return KasirMenuCardSmall(
            key: ValueKey(item.id),
            item: item,
            cartQty: cartQty,
            onAddToCart: (cardCtx) => _onAddToCartTapped(item, cardCtx),
            onDecrement: () => _decrementCart(item.id!),
          );
        }

        return KasirMenuCardMedium(
          key: ValueKey(item.id),
          item: item,
          cartQty: cartQty,
          onAddToCart: (cardCtx) => _onAddToCartTapped(item, cardCtx),
          onDecrement: () => _decrementCart(item.id!),
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
              'Silakan tambahkan kategori di Menu Admin.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13,
                color: AppTheme.textMedium,
              ),
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
                  : 'Silakan tambahkan menu di Menu Admin.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13,
                color: AppTheme.textMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== STICKY BOTTOM ORDER BAR ====================

  Widget _buildBottomOrderBar() {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 250),
      crossFadeState: _cart.isNotEmpty ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      secondChild: const SizedBox.shrink(),
      firstChild: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(top: BorderSide(color: Color(0xFFFFD1DC))),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryPink.withValues(alpha: 0.14),
                blurRadius: 14,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Order summary counter
              Expanded(
                child: InkWell(
                  onTap: _openCheckoutSheet,
                  borderRadius: BorderRadius.circular(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: AppTheme.softPinkBackground,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$_totalItemsInCart Item',
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryPinkDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Ketuk untuk rincian',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 10.5,
                              color: AppTheme.textLight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        Formatters.currency(_totalPriceInCart),
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryPinkDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Animated Bayar Button with target key for flying item
              ScaleTransition(
                scale: _cartBounceAnimation,
                child: Container(
                  key: _cartTargetKey,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _openCheckoutSheet,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shopping_cart_checkout_rounded, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Bayar',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderItemSummary {
  final int id;
  final String name;
  final double price;
  final int qty;

  const _OrderItemSummary({
    required this.id,
    required this.name,
    required this.price,
    required this.qty,
  });
}

class _CheckoutModal extends StatefulWidget {
  final Map<int, int> cart;
  final List<MenuItemModel> menuItems;
  final MenuItemModel? Function(int id)? itemResolver;
  final Function(int id, int qty) onUpdateQty;
  final Function(
    List<_OrderItemSummary> orderItems,
    PaymentMethod method,
    double cashGiven,
    double change,
  ) onCheckoutSuccess;

  const _CheckoutModal({
    required this.cart,
    required this.menuItems,
    this.itemResolver,
    required this.onUpdateQty,
    required this.onCheckoutSuccess,
  });

  @override
  State<_CheckoutModal> createState() => _CheckoutModalState();
}

class _CheckoutModalState extends State<_CheckoutModal> {
  late Map<int, int> _localCart;
  PaymentMethod _selectedMethod = PaymentMethod.cash;
  late TextEditingController _cashInputController;
  bool _isProcessing = false;
  bool _hasCashError = false;

  @override
  void initState() {
    super.initState();
    _localCart = Map.from(widget.cart);
    _cashInputController = TextEditingController();
  }

  @override
  void dispose() {
    _cashInputController.dispose();
    super.dispose();
  }

  MenuItemModel? _findItem(int id) {
    if (widget.itemResolver != null) {
      final item = widget.itemResolver!(id);
      if (item != null) return item;
    }
    final list = widget.menuItems.where((m) => m.id == id);
    if (list.isNotEmpty) return list.first;
    return DatabaseService.instance.getCachedMenuItemById(id);
  }

  double get _totalAmount {
    double total = 0;
    for (final entry in _localCart.entries) {
      final item = _findItem(entry.key);
      if (item != null) total += item.price * entry.value;
    }
    return total;
  }

  double get _cashGiven {
    if (_selectedMethod != PaymentMethod.cash) return _totalAmount;
    final parsed = Formatters.parseCurrencyInput(_cashInputController.text);
    return parsed ?? 0;
  }

  double get _changeAmount => (_cashGiven - _totalAmount).clamp(0, 999999999);

  Future<void> _processPayment() async {
    if (_localCart.isEmpty) return;

    final total = _totalAmount;
    if (_selectedMethod == PaymentMethod.cash) {
      final textTrim = _cashInputController.text.trim();
      final isNotEntered = textTrim.isEmpty || _cashGiven == 0;
      if (isNotEntered) {
        setState(() => _hasCashError = true);
        CashWarningPopup.show(
          context,
          title: 'Uang Belum Diinput',
          message: 'Silakan masukkan nominal uang tunai yang diterima.',
        );
        return;
      }
      if (_cashGiven < total) {
        setState(() => _hasCashError = true);
        final shortage = total - _cashGiven;
        CashWarningPopup.show(
          context,
          title: 'Nominal Uang Kurang',
          message: 'Uang tunai kurang ${Formatters.currency(shortage)} dari total tagihan.',
        );
        return;
      }
    }

    setState(() => _isProcessing = true);

    try {
      final success = await DatabaseService.instance.checkoutOrder(_localCart);
      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal memproses transaksi. Cek stok produk.'),
              backgroundColor: AppTheme.dangerRed,
            ),
          );
          setState(() => _isProcessing = false);
        }
        return;
      }

      final List<_OrderItemSummary> orderSummary = [];
      final List<TransactionItemModel> transactionItems = [];
      for (final entry in _localCart.entries) {
        final item = _findItem(entry.key);
        if (item != null) {
          orderSummary.add(_OrderItemSummary(
            id: item.id!,
            name: item.name,
            price: item.price,
            qty: entry.value,
          ));
          transactionItems.add(TransactionItemModel(
            menuId: item.id,
            name: item.name,
            price: item.price,
            quantity: entry.value,
            totalPrice: item.price * entry.value,
            imagePath: item.imagePath,
            categoryType: item.type,
          ));
        }
      }

      // Simpan ke riwayat transaksi database
      final now = DateTime.now();
      final invoiceNum = 'TRX-${now.millisecondsSinceEpoch.toString().substring(5)}';
      final actualCashGiven = _selectedMethod == PaymentMethod.cash ? _cashGiven : total;
      final actualChange = _selectedMethod == PaymentMethod.cash ? _changeAmount : 0.0;

      final transactionRecord = TransactionModel(
        invoiceNumber: invoiceNum,
        createdAt: now,
        totalAmount: total,
        paymentMethod: _selectedMethod.title,
        cashGiven: actualCashGiven,
        change: actualChange,
        items: transactionItems,
      );

      await DatabaseService.instance.saveTransaction(transactionRecord);

      if (mounted) {
        Navigator.pop(context); // close modal
        widget.onCheckoutSuccess(
          orderSummary,
          _selectedMethod,
          actualCashGiven,
          actualChange,
        );
      }
    } catch (e) {
      debugPrint('Checkout error: $e');
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final total = _totalAmount;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: bottomInset),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Rincian Pesanan',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textDark,
                    ),
                  ),
                  Text(
                    '${_localCart.values.fold(0, (sum, q) => sum + q)} item dipilih',
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      color: AppTheme.textMedium,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFFFEBF0)),

            // Cart Items List
            Flexible(
              child: _localCart.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Keranjang kosong',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          color: AppTheme.textMedium,
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      itemCount: _localCart.length,
                      separatorBuilder: (context, index) => const Divider(height: 12, color: Color(0xFFF5F0F2)),
                      itemBuilder: (context, index) {
                        final itemId = _localCart.keys.elementAt(index);
                        final qty = _localCart[itemId]!;
                        final item = _findItem(itemId);
                        if (item == null) return const SizedBox.shrink();

                        return Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CustomImageView(
                                imagePath: item.imagePath,
                                type: item.type,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 6,
                                    runSpacing: 2,
                                    children: [
                                      Text(
                                        Formatters.currency(item.price),
                                        style: const TextStyle(
                                          fontFamily: AppTheme.fontFamily,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textMedium,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: AppTheme.softPinkBackground,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFFFD1DC), width: 0.8),
                                        ),
                                        child: Text(
                                          'Total: ${Formatters.currency(item.price * qty)}',
                                          style: const TextStyle(
                                            fontFamily: AppTheme.fontFamily,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.primaryPinkDark,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Qty selector
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (qty <= 1) {
                                        _localCart.remove(itemId);
                                      } else {
                                        _localCart[itemId] = qty - 1;
                                      }
                                    });
                                    widget.onUpdateQty(itemId, qty - 1);
                                  },
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: AppTheme.softPinkBackground,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFFFFD1DC)),
                                    ),
                                    child: const Icon(Icons.remove_rounded, size: 14, color: AppTheme.primaryPinkDark),
                                  ),
                                ),
                                SizedBox(
                                  width: 30,
                                  child: Text(
                                    '$qty',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    if (qty >= item.stock) {
                                      StockLimitPopup.show(
                                        context,
                                        itemName: item.name,
                                        maxStock: item.stock,
                                      );
                                      return;
                                    }
                                    setState(() {
                                      _localCart[itemId] = qty + 1;
                                    });
                                    widget.onUpdateQty(itemId, qty + 1);
                                  },
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: qty >= item.stock ? Colors.grey.shade400 : AppTheme.primaryPink,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
            ),

            const Divider(height: 1, color: Color(0xFFFFEBF0)),

            // Payment Options Section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Metode Pembayaran',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: PaymentMethod.values.map((m) {
                      final isSel = _selectedMethod == m;
                      final isFirst = m == PaymentMethod.values.first;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: isFirst ? 8 : 0),
                          child: InkWell(
                            onTap: () => setState(() {
                              _selectedMethod = m;
                              _hasCashError = false;
                            }),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSel ? AppTheme.primaryPink : AppTheme.softPinkBackground,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSel ? AppTheme.primaryPinkDark : const Color(0xFFFFD1DC),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    m.icon,
                                    size: 16,
                                    color: isSel ? Colors.white : AppTheme.primaryPinkDark,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    m.title,
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 12,
                                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w600,
                                      color: isSel ? Colors.white : AppTheme.textDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  if (_selectedMethod == PaymentMethod.cash) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _cashInputController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [CurrencyInputFormatter()],
                            onChanged: (_) {
                              if (_hasCashError) {
                                setState(() => _hasCashError = false);
                              } else {
                                setState(() {});
                              }
                            },
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Uang Diterima',
                              prefixText: 'Rp ',
                              prefixStyle: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryPink,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              hintText: '0',
                              errorText: _hasCashError
                                  ? (_cashInputController.text.trim().isEmpty || _cashGiven == 0
                                      ? 'Uang belum diinput'
                                      : 'Uang kurang ${Formatters.currency((total - _cashGiven) > 0 ? (total - _cashGiven) : 0.0)}')
                                  : null,
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                onPressed: () {
                                  _cashInputController.clear();
                                  setState(() => _hasCashError = false);
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Uang Pas button
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            side: const BorderSide(color: AppTheme.primaryPink),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            _cashInputController.text = Formatters.formatNumber(total);
                            setState(() => _hasCashError = false);
                          },
                          child: const Text(
                            'Uang Pas',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryPink,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Kembalian calculation indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Kembalian:',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            color: AppTheme.textMedium,
                          ),
                        ),
                        Text(
                          Formatters.currency(_changeAmount),
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _cashGiven >= total ? AppTheme.successGreen : AppTheme.dangerRed,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Total & Bayar Button
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Tagihan',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 11,
                              color: AppTheme.textMedium,
                            ),
                          ),
                          Text(
                            Formatters.currency(total),
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryPinkDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _localCart.isEmpty || _isProcessing ? null : _processPayment,
                          child: _isProcessing
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Proses Pembayaran',
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pop up notifikasi batas stok yang tampil mengambang di bagian atas layar
/// menggunakan root overlay sehingga tidak pernah tertutup oleh modal bottom sheet / form.
class StockLimitPopup {
  static OverlayEntry? _activeEntry;
  static Timer? _dismissTimer;

  static void dismiss() {
    _dismissTimer?.cancel();
    try {
      _activeEntry?.remove();
    } catch (_) {}
    _activeEntry = null;
  }

  static void show(
    BuildContext context, {
    required String itemName,
    required int maxStock,
    bool isOutOfStock = false,
  }) {
    HapticFeedback.heavyImpact();

    dismiss();
    CashWarningPopup.dismiss();

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _StockLimitPopupWidget(
        itemName: itemName,
        maxStock: maxStock,
        isOutOfStock: isOutOfStock,
        onDismiss: () {
          _dismissTimer?.cancel();
          try {
            entry.remove();
          } catch (_) {}
          if (_activeEntry == entry) _activeEntry = null;
        },
      ),
    );

    _activeEntry = entry;
    overlay.insert(entry);

    _dismissTimer = Timer(const Duration(milliseconds: 2800), () {
      try {
        entry.remove();
      } catch (_) {}
      if (_activeEntry == entry) _activeEntry = null;
    });
  }
}

class _StockLimitPopupWidget extends StatefulWidget {
  final String itemName;
  final int maxStock;
  final bool isOutOfStock;
  final VoidCallback onDismiss;

  const _StockLimitPopupWidget({
    required this.itemName,
    required this.maxStock,
    required this.isOutOfStock,
    required this.onDismiss,
  });

  @override
  State<_StockLimitPopupWidget> createState() => _StockLimitPopupWidgetState();
}

class _StockLimitPopupWidgetState extends State<_StockLimitPopupWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    ));
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _dismiss() async {
    if (!mounted) return;
    await _animController.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: _dismiss,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0F3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFFB3C1), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.14),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                        BoxShadow(
                          color: AppTheme.dangerRed.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppTheme.dangerRed,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.inventory_2_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.isOutOfStock ? 'Stok Telah Habis' : 'Maksimal Stok Tercapai',
                                style: const TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF900C3F),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.isOutOfStock
                                    ? '"${widget.itemName}" saat ini tidak tersedia.'
                                    : 'Pesanan "${widget.itemName}" mencapai batas maksimal (${widget.maxStock} porsi).',
                                style: const TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textDark,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _dismiss,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.06),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: AppTheme.textMedium,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CashWarningPopup {
  static OverlayEntry? _activeEntry;
  static Timer? _dismissTimer;

  static void dismiss() {
    _dismissTimer?.cancel();
    try {
      _activeEntry?.remove();
    } catch (_) {}
    _activeEntry = null;
  }

  static void show(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    HapticFeedback.heavyImpact();

    StockLimitPopup.dismiss();
    dismiss();

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _CashWarningPopupWidget(
        title: title,
        message: message,
        onDismiss: () {
          _dismissTimer?.cancel();
          try {
            entry.remove();
          } catch (_) {}
          if (_activeEntry == entry) _activeEntry = null;
        },
      ),
    );

    _activeEntry = entry;
    overlay.insert(entry);

    _dismissTimer = Timer(const Duration(milliseconds: 2800), () {
      try {
        entry.remove();
      } catch (_) {}
      if (_activeEntry == entry) _activeEntry = null;
    });
  }
}

class _CashWarningPopupWidget extends StatefulWidget {
  final String title;
  final String message;
  final VoidCallback onDismiss;

  const _CashWarningPopupWidget({
    required this.title,
    required this.message,
    required this.onDismiss,
  });

  @override
  State<_CashWarningPopupWidget> createState() => _CashWarningPopupWidgetState();
}

class _CashWarningPopupWidgetState extends State<_CashWarningPopupWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    ));
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _dismiss() async {
    if (!mounted) return;
    await _animController.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: _dismiss,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0F3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFFB3C1), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.14),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                        BoxShadow(
                          color: AppTheme.dangerRed.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppTheme.dangerRed,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.payments_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: const TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF900C3F),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.message,
                                style: const TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textDark,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _dismiss,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.06),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: AppTheme.textMedium,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

