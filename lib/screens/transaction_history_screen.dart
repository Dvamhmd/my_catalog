import 'package:flutter/material.dart';
import '../models/category_type.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';
import '../services/preference_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/responsive.dart';
import '../widgets/app_drawer.dart';
import '../widgets/custom_image_view.dart';
import 'home_screen.dart';
import 'kasir_screen.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final DatabaseService _db = DatabaseService.instance;
  List<TransactionModel> _allTransactions = [];
  List<TransactionModel> _filteredTransactions = [];
  bool _isLoading = true;

  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatusFilter = 'Semua'; // 'Semua', 'Selesai', 'Belum Selesai'

  @override
  void initState() {
    super.initState();
    PreferenceService.saveLastActiveMenu(AppDrawerMenu.riwayatTransaksi);
    _loadTransactions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      final list = await _db.getTransactions();
      if (mounted) {
        setState(() {
          _allTransactions = list;
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading transactions: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();

    List<TransactionModel> result = _allTransactions.where((t) {
      // 1. Status Filter
      if (_selectedStatusFilter == 'Selesai' && !t.isCompleted) return false;
      if (_selectedStatusFilter == 'Belum Selesai' && !t.isPending) return false;

      // 2. Search Query (invoice number, payment method, customer category, item name, or status)
      if (query.isNotEmpty) {
        final matchInvoice = t.invoiceNumber.toLowerCase().contains(query);
        final matchMethod = t.paymentMethod.toLowerCase().contains(query);
        final matchItem = t.items.any((i) => i.name.toLowerCase().contains(query));
        final matchCat = t.customerCategory?.toLowerCase().contains(query) ?? false;
        final matchStatus = (t.isCompleted ? 'selesai' : 'belum selesai').contains(query);
        return matchInvoice || matchMethod || matchItem || matchCat || matchStatus;
      }

      return true;
    }).toList();

    setState(() {
      _filteredTransactions = result;
    });
  }

  int get _completedCount => _allTransactions.where((t) => t.isCompleted).length;
  int get _pendingCount => _allTransactions.where((t) => t.isPending).length;

  double get _totalRevenue => _filteredTransactions
      .where((t) => t.isCompleted)
      .fold(0.0, (sum, t) => sum + t.totalAmount);

  int get _totalItemsSold => _filteredTransactions
      .where((t) => t.isCompleted)
      .fold(0, (sum, t) => sum + t.totalItemsCount);

  void _showTransactionDetail(TransactionModel trx) {
    showDialog(
      context: context,
      builder: (ctx) => _ReceiptDetailDialog(
        transaction: trx,
        onDeleted: () {
          _loadTransactions();
        },
        onUpdated: () {
          _loadTransactions();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPad = Responsive.horizontalPadding(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      drawer: AppDrawer(
        activeMenu: AppDrawerMenu.riwayatTransaksi,
        onSelectMenu: (menu) {
          PreferenceService.saveLastActiveMenu(menu);
          if (menu == AppDrawerMenu.admin) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          } else if (menu == AppDrawerMenu.kasir) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const KasirScreen()),
            );
          }
        },
        onDataChanged: _loadTransactions,
      ),
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        color: AppTheme.primaryPink,
        backgroundColor: Colors.white,
        onRefresh: _loadTransactions,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryPink))
            : CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Search Bar if open
                  if (_isSearchOpen)
                    SliverToBoxAdapter(
                      child: _buildSearchBar(),
                    ),

                  // Sales Summary Banner Card
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(horizontalPad, 12, horizontalPad, 8),
                      child: _buildSummaryCard(),
                    ),
                  ),

                  // Status Filter Bar (Semua, Selesai, Belum Selesai)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(horizontalPad, 4, horizontalPad, 8),
                      child: _buildStatusFilterBar(),
                    ),
                  ),


                  // Transactions List or Empty State
                  if (_filteredTransactions.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(horizontalPad, 0, horizontalPad, 40),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final trx = _filteredTransactions[index];
                            return _buildTransactionCard(trx);
                          },
                          childCount: _filteredTransactions.length,
                        ),
                      ),
                    ),
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
              'Riwayat Transaksi',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Cari Transaksi',
          icon: Icon(
            _isSearchOpen ? Icons.search_off_rounded : Icons.search_rounded,
            color: Colors.white,
          ),
          onPressed: () {
            setState(() {
              _isSearchOpen = !_isSearchOpen;
              if (!_isSearchOpen) {
                _searchController.clear();
                _applyFilter();
              }
            });
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13.5),
        decoration: InputDecoration(
          hintText: 'Cari no. invoice, menu, atau metode...',
          prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryPink),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18, color: AppTheme.textLight),
                  onPressed: () {
                    _searchController.clear();
                    _applyFilter();
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          fillColor: AppTheme.softPinkBackground.withValues(alpha: 0.4),
          filled: true,
        ),
        onChanged: (_) => _applyFilter(),
      ),
    );
  }

  // ==================== SUMMARY CARD ====================

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFF5277),
            Color(0xFFFF7E9C),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF5277).withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.query_stats_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Ringkasan Penjualan',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_filteredTransactions.length} Transaksi',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            Formatters.currency(_totalRevenue),
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, color: Colors.white70, size: 15),
                      const SizedBox(width: 5),
                      Text(
                        'Selesai: ${_filteredTransactions.where((t) => t.isCompleted).length}',
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 16, color: Colors.white24),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.restaurant_menu_rounded, color: Colors.white70, size: 15),
                      const SizedBox(width: 5),
                      Text(
                        'Terjual: $_totalItemsSold',
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_filteredTransactions.any((t) => t.isPending)) ...[
                  Container(width: 1, height: 16, color: Colors.white24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.pending_actions_rounded, color: Color(0xFFFFE082), size: 15),
                        const SizedBox(width: 5),
                        Text(
                          'Pending: ${_filteredTransactions.where((t) => t.isPending).length}',
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            color: Color(0xFFFFE082),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== STATUS FILTER BAR ====================

  Widget _buildStatusFilterBar() {
    final filters = [
      {'title': 'Semua', 'count': _allTransactions.length},
      {'title': 'Selesai', 'count': _completedCount},
      {'title': 'Belum Selesai', 'count': _pendingCount},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final title = f['title'] as String;
          final count = f['count'] as int;
          final isSel = _selectedStatusFilter == title;
          final isPendingChip = title == 'Belum Selesai';

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isPendingChip) ...[
                    Icon(
                      Icons.pending_actions_rounded,
                      size: 14,
                      color: isSel ? Colors.white : (count > 0 ? const Color(0xFFE65100) : AppTheme.textMedium),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    isPendingChip ? '$title ($count)' : title,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                      color: isSel
                          ? Colors.white
                          : (isPendingChip && count > 0 ? const Color(0xFFE65100) : AppTheme.textMedium),
                    ),
                  ),
                ],
              ),
              selected: isSel,
              showCheckmark: false,
              backgroundColor: isPendingChip && count > 0 && !isSel
                  ? const Color(0xFFFFF3E0)
                  : Colors.white,
              selectedColor: isPendingChip ? const Color(0xFFE65100) : AppTheme.primaryPink,
              side: BorderSide(
                color: isSel
                    ? (isPendingChip ? const Color(0xFFE65100) : AppTheme.primaryPink)
                    : (isPendingChip && count > 0 ? const Color(0xFFFFB74D) : const Color(0xFFE8E5E7)),
                width: 1,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              onSelected: (_) {
                setState(() {
                  _selectedStatusFilter = title;
                  _applyFilter();
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }




  // ==================== TRANSACTION CARD ====================

  Widget _buildTransactionCard(TransactionModel trx) {
    final dateStr =
        '${trx.createdAt.day.toString().padLeft(2, '0')}/${trx.createdAt.month.toString().padLeft(2, '0')}/${trx.createdAt.year}  •  ${trx.createdAt.hour.toString().padLeft(2, '0')}:${trx.createdAt.minute.toString().padLeft(2, '0')}';

    final itemsSummary = trx.items.map((i) => '${i.name} (${i.quantity}x)').join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: trx.isPending ? const Color(0xFFFFFDF9) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: trx.isPending ? const Color(0xFFFFB74D) : const Color(0xFFFFE0E8),
          width: trx.isPending ? 1.2 : 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: trx.isPending
                ? const Color(0xFFE65100).withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showTransactionDetail(trx),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Invoice No & Payment/Status Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: trx.isPending ? const Color(0xFFFFF3E0) : AppTheme.softPinkBackground,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            trx.isPending ? Icons.pending_actions_rounded : Icons.receipt_long_rounded,
                            size: 16,
                            color: trx.isPending ? const Color(0xFFE65100) : AppTheme.primaryPink,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          trx.invoiceNumber,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textDark,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (trx.customerCategory != null &&
                            trx.customerCategory!.isNotEmpty &&
                            trx.customerCategory != 'Reguler') ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFC8E6C9), width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.badge_outlined, size: 12, color: Color(0xFF2E7D32)),
                                const SizedBox(width: 4),
                                Text(
                                  trx.customerCategory!,
                                  style: const TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (trx.paymentMethod.isNotEmpty && trx.paymentMethod != 'Belum Dibayar') ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: AppTheme.softPinkBackground,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFFCCD8), width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getPaymentIcon(trx.paymentMethod),
                                  size: 13,
                                  color: AppTheme.primaryPinkDark,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  trx.paymentMethod,
                                  style: const TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primaryPinkDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (trx.isPending)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFFB74D), width: 0.8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.hourglass_top_rounded,
                                  size: 12,
                                  color: Color(0xFFE65100),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Belum Selesai',
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFE65100),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Item description preview
                Text(
                  itemsSummary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textMedium,
                    height: 1.3,
                  ),
                ),
                if (trx.customerPhone != null && trx.customerPhone!.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.phone_android_rounded, size: 12, color: AppTheme.textMedium),
                      const SizedBox(width: 4),
                      Text(
                        trx.customerPhone!,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF7F3F5)),
                const SizedBox(height: 10),

                // Bottom row: Date & Total Amount
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 14, color: AppTheme.textLight),
                        const SizedBox(width: 5),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 11,
                            color: AppTheme.textLight,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          Formatters.currency(trx.totalAmount),
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: trx.isPending ? const Color(0xFFE65100) : AppTheme.primaryPinkDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (trx.isPending)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE65100),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Selesaikan',
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 3),
                                Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.white),
                              ],
                            ),
                          )
                        else
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 12,
                            color: AppTheme.primaryPink,
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  IconData _getPaymentIcon(String method) {
    final lower = method.toLowerCase();
    if (lower.contains('qris')) return Icons.qr_code_scanner_rounded;
    if (lower.contains('transfer')) return Icons.account_balance_rounded;
    if (lower.contains('debit') || lower.contains('edc')) return Icons.credit_card_rounded;
    return Icons.payments_rounded;
  }

  // ==================== EMPTY STATE ====================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.softPinkBackground,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFD1DC), width: 1.5),
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                size: 40,
                color: AppTheme.primaryPink,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Belum Ada Riwayat Transaksi',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Transaksi yang Anda proses melalui Menu Kasir akan tercatat secara rapi di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12.5,
                color: AppTheme.textLight,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const KasirScreen()),
                );
              },
              icon: const Icon(Icons.point_of_sale_rounded, size: 16),
              label: const Text('Buka Menu Kasir'),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== RECEIPT DETAIL DIALOG (STRUK NOTA) ====================

class _ReceiptDetailDialog extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback onDeleted;
  final VoidCallback? onUpdated;

  const _ReceiptDetailDialog({
    required this.transaction,
    required this.onDeleted,
    this.onUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${transaction.createdAt.day.toString().padLeft(2, '0')}/${transaction.createdAt.month.toString().padLeft(2, '0')}/${transaction.createdAt.year}  ${transaction.createdAt.hour.toString().padLeft(2, '0')}:${transaction.createdAt.minute.toString().padLeft(2, '0')}';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Store Header
              ClipOval(
                child: Image.asset(
                  'assets/images/app_logo.webp',
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'My Catalog',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryPinkDark,
                ),
              ),
              const Text(
                'Katalog & Kasir POS',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textLight,
                ),
              ),
              const SizedBox(height: 14),

              // Pending Warning Banner if transaction is uncompleted
              if (transaction.isPending) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFB74D), width: 1),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.hourglass_top_rounded, color: Color(0xFFE65100), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TRANSAKSI BELUM SELESAI',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFE65100),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Transaksi ini tersimpan sementara saat kasir ditutup. Selesaikan pembayaran atau lanjutkan di kasir.',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 11,
                                color: Color(0xFFBF360C),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Invoice No & Date
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: transaction.isPending
                      ? const Color(0xFFFFF8E1)
                      : AppTheme.softPinkBackground.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: transaction.isPending ? const Color(0xFFFFD54F) : const Color(0xFFFFE0E8),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      transaction.invoiceNumber,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textDark,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11,
                        color: AppTheme.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              const SizedBox(height: 12),

              // Itemized Header
              const Row(
                children: [
                  Expanded(
                    child: Text(
                      'ITEM PESANAN',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textLight,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Text(
                    'SUBTOTAL',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textLight,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Items List
              ...transaction.items.map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.imagePath != null && item.imagePath!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: CustomImageView(
                              imagePath: item.imagePath,
                              type: item.categoryType ?? CategoryType.food,
                              width: 34,
                              height: 34,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${Formatters.currency(item.price)} x ${item.quantity}',
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 11.5,
                                color: AppTheme.textLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        Formatters.currency(item.totalPrice),
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              const SizedBox(height: 12),

              // Payment Details
              _buildDetailRow(
                'Total Tagihan',
                Formatters.currency(transaction.totalAmount),
                isBold: true,
                valueColor: transaction.isPending ? const Color(0xFFE65100) : AppTheme.primaryPinkDark,
                valueSize: 16,
              ),
              const SizedBox(height: 6),
              _buildDetailRow(
                'Metode Pembayaran',
                transaction.paymentMethod,
              ),
              if (transaction.cashGiven > 0) ...[
                const SizedBox(height: 6),
                _buildDetailRow(
                  'Uang Tunai',
                  Formatters.currency(transaction.cashGiven),
                ),
                if (transaction.change > 0 || transaction.isCompleted) ...[
                  const SizedBox(height: 6),
                  _buildDetailRow(
                    'Kembalian',
                    Formatters.currency(transaction.change),
                    valueColor: AppTheme.successGreen,
                  ),
                ],
              ],
              if (transaction.customerCategory != null &&
                  transaction.customerCategory!.isNotEmpty &&
                  transaction.customerCategory != 'Reguler') ...[
                const SizedBox(height: 6),
                _buildDetailRow(
                  'Kategori Pelanggan',
                  transaction.customerCategory!,
                  valueColor: AppTheme.primaryPinkDark,
                ),
              ],
              if (transaction.customerPhone != null &&
                  transaction.customerPhone!.isNotEmpty) ...[
                const SizedBox(height: 6),
                _buildDetailRow(
                  'No. Telepon',
                  transaction.customerPhone!,
                ),
              ],
              if (transaction.displayLoyaltyDiscount != null) ...[
                const SizedBox(height: 6),
                _buildDetailRow(
                  'Diskon Loyalty',
                  transaction.displayLoyaltyDiscount!,
                  valueColor: const Color(0xFF2E7D32),
                ),
              ],

              const SizedBox(height: 18),

              // Action Buttons
              if (transaction.isPending) ...[
                // For pending transaction: options to complete or continue in cashier
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE65100),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: const Text(
                      'Selesaikan Pembayaran Sekarang',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    onPressed: () {
                      _showCompletePaymentDialog(context);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryPinkDark,
                      side: const BorderSide(color: AppTheme.primaryPink, width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.point_of_sale_rounded, size: 18),
                    label: const Text(
                      'Buka & Lanjutkan di Kasir',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    onPressed: () {
                      Navigator.pop(context); // Close receipt
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => KasirScreen(resumeTransaction: transaction),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Hapus Transaksi',
                      icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.dangerRed, size: 20),
                      onPressed: () => _confirmDelete(context),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Tutup', style: TextStyle(color: AppTheme.textMedium)),
                    ),
                  ],
                ),
              ] else ...[
                // For completed transaction: regular Close & Delete
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Hapus Transaksi',
                      icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.dangerRed, size: 20),
                      onPressed: () {
                        _confirmDelete(context);
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Tutup Struk'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showCompletePaymentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _CompletePaymentDialog(
        transaction: transaction,
        onSuccess: () {
          Navigator.pop(context); // Close receipt detail dialog
          onUpdated?.call();
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Catatan Transaksi?'),
        content: Text('Riwayat "${transaction.invoiceNumber}" akan dihapus secara permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            onPressed: () async {
              Navigator.pop(ctx); // Close confirm
              Navigator.pop(context); // Close detail dialog
              if (transaction.id != null) {
                await DatabaseService.instance.deleteTransaction(transaction.id!);
                onDeleted();
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
    double valueSize = 13,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 12.5,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
            color: isBold ? AppTheme.textDark : AppTheme.textMedium,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: valueSize,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
            color: valueColor ?? AppTheme.textDark,
          ),
        ),
      ],
    );
  }
}

// ==================== COMPLETE PAYMENT DIALOG ====================

class _CompletePaymentDialog extends StatefulWidget {
  final TransactionModel transaction;
  final VoidCallback onSuccess;

  const _CompletePaymentDialog({
    required this.transaction,
    required this.onSuccess,
  });

  @override
  State<_CompletePaymentDialog> createState() => _CompletePaymentDialogState();
}

class _CompletePaymentDialogState extends State<_CompletePaymentDialog> {
  String _selectedMethod = 'Tunai';
  final TextEditingController _cashController = TextEditingController();
  bool _isProcessing = false;
  double _cashGiven = 0;

  @override
  void initState() {
    super.initState();
    final initialMethod = widget.transaction.paymentMethod.toLowerCase().contains('qris') ? 'QRIS' : 'Tunai';
    _selectedMethod = initialMethod;
    if (widget.transaction.cashGiven > 0) {
      _cashGiven = widget.transaction.cashGiven;
    } else {
      _cashGiven = widget.transaction.totalAmount;
    }
    _cashController.text = Formatters.formatNumber(_cashGiven);
  }

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  double get _change => (_cashGiven - widget.transaction.totalAmount).clamp(0, double.infinity);
  bool get _isCashValid => _selectedMethod != 'Tunai' || _cashGiven >= widget.transaction.totalAmount;

  Future<void> _processPayment() async {
    if (!_isCashValid || _isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      // 1. Deduct stock for the items
      final Map<int, int> quantities = {};
      for (final item in widget.transaction.items) {
        if (item.menuId != null) {
          quantities[item.menuId!] = item.quantity;
        }
      }
      if (quantities.isNotEmpty) {
        await DatabaseService.instance.checkoutOrder(quantities);
      }

      // 2. Update transaction status to selesai
      final completedTrx = widget.transaction.copyWith(
        status: TransactionModel.statusSelesai,
        paymentMethod: _selectedMethod,
        cashGiven: _selectedMethod == 'Tunai' ? _cashGiven : widget.transaction.totalAmount,
        change: _selectedMethod == 'Tunai' ? _change : 0,
      );

      await DatabaseService.instance.updateTransaction(completedTrx);

      if (mounted) {
        Navigator.pop(context); // Close this dialog
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pembayaran ${widget.transaction.invoiceNumber} berhasil diselesaikan!'),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyelesaikan pembayaran: $e'),
            backgroundColor: AppTheme.dangerRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.payment_rounded, color: Color(0xFFE65100), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Selesaikan Pembayaran',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textDark,
                          ),
                        ),
                        Text(
                          widget.transaction.invoiceNumber,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            color: AppTheme.textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.textLight),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Total Amount Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.softPinkBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFCCD8), width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Tagihan',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMedium,
                      ),
                    ),
                    Text(
                      Formatters.currency(widget.transaction.totalAmount),
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryPinkDark,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Payment Method Selection
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
                children: [
                  Expanded(
                    child: _buildMethodChip('Tunai', Icons.payments_rounded),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMethodChip('QRIS', Icons.qr_code_scanner_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Cash Inputs if Tunai
              if (_selectedMethod == 'Tunai') ...[
                const Text(
                  'Uang Diterima',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _cashController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [CurrencyInputFormatter()],
                  decoration: InputDecoration(
                    prefixText: 'Rp ',
                    prefixStyle: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primaryPink, width: 1.5),
                    ),
                  ),
                  onChanged: (val) {
                    final parsed = Formatters.parseCurrencyInput(val) ?? 0;
                    setState(() => _cashGiven = parsed);
                  },
                ),
                const SizedBox(height: 10),

                // Quick Cash Buttons
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildQuickCashPill(widget.transaction.totalAmount, 'Uang Pas'),
                    _buildQuickCashPill(50000, '50.000'),
                    _buildQuickCashPill(100000, '100.000'),
                  ],
                ),
                const SizedBox(height: 12),

                // Change Row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9F9F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Kembalian',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMedium,
                        ),
                      ),
                      Text(
                        Formatters.currency(_change),
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _cashGiven >= widget.transaction.totalAmount
                              ? AppTheme.successGreen
                              : AppTheme.dangerRed,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_cashGiven < widget.transaction.totalAmount) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Nominal uang kurang dari total tagihan',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      color: AppTheme.dangerRed,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
              ],

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isCashValid && !_isProcessing ? _processPayment : null,
                  child: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Konfirmasi Pembayaran Selesai',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
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

  Widget _buildMethodChip(String label, IconData icon) {
    final isSelected = _selectedMethod == label;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedMethod = label;
          if (label == 'QRIS') {
            _cashGiven = widget.transaction.totalAmount;
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.softPinkBackground : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryPink : const Color(0xFFE0E0E0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppTheme.primaryPinkDark : AppTheme.textMedium,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? AppTheme.primaryPinkDark : AppTheme.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickCashPill(double amount, String label) {
    return ActionChip(
      label: Text(
        label,
        style: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.textDark,
        ),
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      side: const BorderSide(color: Color(0xFFE0E0E0), width: 0.8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      onPressed: () {
        setState(() {
          _cashGiven = amount;
          _cashController.text = Formatters.formatNumber(amount);
        });
      },
    );
  }
}

