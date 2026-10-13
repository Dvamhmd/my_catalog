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
  String _selectedDateFilter = 'Semua'; // 'Semua', 'Hari Ini', '7 Hari Terakhir'

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
    final now = DateTime.now();

    List<TransactionModel> result = _allTransactions.where((t) {
      // 1. Date Filter
      if (_selectedDateFilter == 'Hari Ini') {
        final isSameDay = t.createdAt.year == now.year &&
            t.createdAt.month == now.month &&
            t.createdAt.day == now.day;
        if (!isSameDay) return false;
      } else if (_selectedDateFilter == '7 Hari Terakhir') {
        final diff = now.difference(t.createdAt).inDays;
        if (diff > 7) return false;
      }

      // 2. Search Query (invoice number, payment method, or item name)
      if (query.isNotEmpty) {
        final matchInvoice = t.invoiceNumber.toLowerCase().contains(query);
        final matchMethod = t.paymentMethod.toLowerCase().contains(query);
        final matchItem = t.items.any((i) => i.name.toLowerCase().contains(query));
        return matchInvoice || matchMethod || matchItem;
      }

      return true;
    }).toList();

    setState(() {
      _filteredTransactions = result;
    });
  }

  double get _totalRevenue =>
      _filteredTransactions.fold(0.0, (sum, t) => sum + t.totalAmount);

  int get _totalItemsSold =>
      _filteredTransactions.fold(0, (sum, t) => sum + t.totalItemsCount);

  void _showTransactionDetail(TransactionModel trx) {
    showDialog(
      context: context,
      builder: (ctx) => _ReceiptDetailDialog(
        transaction: trx,
        onDeleted: () {
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

                  // Filter Pills (Semua, Hari Ini, 7 Hari Terakhir)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(horizontalPad, 4, horizontalPad, 10),
                      child: _buildDateFilterBar(),
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
                      const Icon(Icons.receipt_rounded, color: Colors.white70, size: 15),
                      const SizedBox(width: 6),
                      Text(
                        'Total: ${_filteredTransactions.length} Struk',
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
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.restaurant_menu_rounded, color: Colors.white70, size: 15),
                      const SizedBox(width: 6),
                      Text(
                        'Terjual: $_totalItemsSold Porsi',
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== DATE FILTER PILLS ====================

  Widget _buildDateFilterBar() {
    final filters = ['Semua', 'Hari Ini', '7 Hari Terakhir'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSel = _selectedDateFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                f,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                  color: isSel ? Colors.white : AppTheme.textMedium,
                ),
              ),
              selected: isSel,
              showCheckmark: false,
              backgroundColor: Colors.white,
              selectedColor: AppTheme.primaryPink,
              side: BorderSide(
                color: isSel ? AppTheme.primaryPink : const Color(0xFFE8E5E7),
                width: 1,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              onSelected: (_) {
                setState(() {
                  _selectedDateFilter = f;
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE0E8), width: 0.9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
                // Top row: Invoice No & Payment Method Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.softPinkBackground,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.receipt_long_rounded,
                            size: 16,
                            color: AppTheme.primaryPink,
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
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryPinkDark,
                          ),
                        ),
                        const SizedBox(width: 6),
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

  const _ReceiptDetailDialog({
    required this.transaction,
    required this.onDeleted,
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

              // Invoice No & Date
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.softPinkBackground.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFE0E8), width: 0.8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      transaction.invoiceNumber,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
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
                        fontWeight: FontWeight.w700,
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
                      fontWeight: FontWeight.w700,
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
                                fontWeight: FontWeight.w700,
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
                          fontWeight: FontWeight.w800,
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
                valueColor: AppTheme.primaryPinkDark,
                valueSize: 16,
              ),
              const SizedBox(height: 6),
              _buildDetailRow(
                'Metode Pembayaran',
                transaction.paymentMethod,
              ),
              if (transaction.paymentMethod.toLowerCase().contains('tunai') ||
                  transaction.paymentMethod.toLowerCase().contains('cash')) ...[
                const SizedBox(height: 6),
                _buildDetailRow(
                  'Uang Diterima',
                  Formatters.currency(transaction.cashGiven),
                ),
                const SizedBox(height: 6),
                _buildDetailRow(
                  'Kembalian',
                  Formatters.currency(transaction.change),
                  valueColor: AppTheme.successGreen,
                ),
              ],

              const SizedBox(height: 18),

              // Buttons (Tutup & Hapus)
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
          ),
        ),
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
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: isBold ? AppTheme.textDark : AppTheme.textMedium,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: valueSize,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
            color: valueColor ?? AppTheme.textDark,
          ),
        ),
      ],
    );
  }
}
