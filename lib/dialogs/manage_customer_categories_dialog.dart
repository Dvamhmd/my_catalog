import 'package:flutter/material.dart';
import '../models/customer_category_model.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class ManageCustomerCategoriesDialog extends StatefulWidget {
  final VoidCallback? onCategoriesChanged;

  const ManageCustomerCategoriesDialog({
    super.key,
    this.onCategoriesChanged,
  });

  @override
  State<ManageCustomerCategoriesDialog> createState() =>
      _ManageCustomerCategoriesDialogState();
}

class _ManageCustomerCategoriesDialogState
    extends State<ManageCustomerCategoriesDialog> {
  final DatabaseService _db = DatabaseService.instance;
  List<CustomerCategoryModel> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final list = await _db.getCustomerCategories();
    if (mounted) {
      setState(() {
        _categories = list;
        _isLoading = false;
      });
    }
  }

  IconData _getCategoryIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('member') || lower.contains('vip')) {
      return Icons.card_membership_rounded;
    }
    if (lower.contains('gofood') || lower.contains('grab') || lower.contains('shopee') || lower.contains('food')) {
      return Icons.delivery_dining_rounded;
    }
    if (lower.contains('karyawan') || lower.contains('staff') || lower.contains('pegawai')) {
      return Icons.badge_outlined;
    }
    return Icons.people_outline_rounded;
  }

  Color _getCategoryColor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('gofood')) return const Color(0xFF00AA13);
    if (lower.contains('grab')) return const Color(0xFF00B14F);
    if (lower.contains('member') || lower.contains('vip')) return AppTheme.primaryPink;
    if (lower.contains('karyawan')) return const Color(0xFF1976D2);
    return const Color(0xFF7B1FA2);
  }

  void _showAddDialog() {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Tambah Kategori Pelanggan',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppTheme.textDark,
          ),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nama Kategori Pelanggan',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMedium,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Contoh: Reseller, ShopeeFood, VIP',
                  hintStyle: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    color: AppTheme.textLight,
                  ),
                  prefixIcon: const Icon(Icons.label_outline_rounded, color: AppTheme.primaryPink),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  filled: true,
                  fillColor: AppTheme.softPinkBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFFFD1DC)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFFFD1DC)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primaryPink, width: 1.5),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Nama kategori tidak boleh kosong';
                  }
                  final trimmed = val.trim().toLowerCase();
                  if (trimmed == 'reguler' || trimmed == 'umum') {
                    return 'Nama reguler / umum adalah harga bawaan';
                  }
                  if (_categories.any((c) => c.name.toLowerCase() == trimmed)) {
                    return 'Kategori "$val" sudah ada';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(fontFamily: AppTheme.fontFamily, color: AppTheme.textMedium)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPink,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final name = controller.text.trim();
                Navigator.pop(ctx);
                final res = await _db.insertCustomerCategory(name);
                if (res != -1) {
                  await _loadCategories();
                  widget.onCategoriesChanged?.call();
                }
              }
            },
            child: const Text(
              'Simpan',
              style: TextStyle(fontFamily: AppTheme.fontFamily, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(CustomerCategoryModel category) {
    final controller = TextEditingController(text: category.name);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Ubah Nama Kategori',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppTheme.textDark,
          ),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nama Kategori Pelanggan',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMedium,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  filled: true,
                  fillColor: AppTheme.softPinkBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFFFD1DC)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFFFD1DC)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primaryPink, width: 1.5),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Nama kategori tidak boleh kosong';
                  }
                  final trimmed = val.trim().toLowerCase();
                  if (trimmed == 'reguler' || trimmed == 'umum') {
                    return 'Nama reguler / umum adalah harga bawaan';
                  }
                  if (_categories.any((c) => c.id != category.id && c.name.toLowerCase() == trimmed)) {
                    return 'Kategori "$val" sudah ada';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(fontFamily: AppTheme.fontFamily, color: AppTheme.textMedium)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPink,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () async {
              if (formKey.currentState!.validate() && category.id != null) {
                final newName = controller.text.trim();
                Navigator.pop(ctx);
                final success = await _db.updateCustomerCategory(category.id!, newName);
                if (success) {
                  await _loadCategories();
                  widget.onCategoriesChanged?.call();
                }
              }
            },
            child: const Text(
              'Perbarui',
              style: TextStyle(fontFamily: AppTheme.fontFamily, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(CustomerCategoryModel category) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Hapus Kategori Pelanggan?',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppTheme.textDark,
          ),
        ),
        content: Text(
          'Kategori "${category.name}" akan dihapus. Menu yang memiliki harga khusus untuk kategori ini akan kembali menggunakan harga normal saat transaksi.',
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 13,
            color: AppTheme.textMedium,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(fontFamily: AppTheme.fontFamily, color: AppTheme.textMedium)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              if (category.id != null) {
                await _db.deleteCustomerCategory(category.id!);
                await _loadCategories();
                widget.onCategoriesChanged?.call();
              }
            },
            child: const Text(
              'Hapus',
              style: TextStyle(fontFamily: AppTheme.fontFamily, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmResetDefaults() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Reset Kategori Default?',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppTheme.textDark,
          ),
        ),
        content: const Text(
          'Daftar kategori pelanggan akan dikembalikan ke default: Member, GoFood, GrabFood, dan Karyawan.',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 13,
            color: AppTheme.textMedium,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(fontFamily: AppTheme.fontFamily, color: AppTheme.textMedium)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPink,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _db.resetCustomerCategoriesToDefault();
              await _loadCategories();
              widget.onCategoriesChanged?.call();
            },
            child: const Text(
              'Reset',
              style: TextStyle(fontFamily: AppTheme.fontFamily, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 14, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.softPinkBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.badge_rounded,
                      color: AppTheme.primaryPink,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kategori Pelanggan',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textDark,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Kelola tingkatan harga transaksi',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            color: AppTheme.textMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textMedium),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF0F0F5)),

            // Info Banner
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFE0E8)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.primaryPink),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Harga menu dapat dibedakan per kategori di form menu dan akan otomatis dihitung saat dipilih di kasir.',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11.5,
                          color: AppTheme.textDark,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.primaryPink),
                    )
                  : _categories.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.group_off_rounded, size: 44, color: AppTheme.textLight),
                              const SizedBox(height: 10),
                              const Text(
                                'Belum ada kategori pelanggan',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textMedium,
                                ),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _confirmResetDefaults,
                                icon: const Icon(Icons.restore_rounded, size: 16),
                                label: const Text('Muat Kategori Default'),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          itemCount: _categories.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final cat = _categories[index];
                            final color = _getCategoryColor(cat.name);
                            final icon = _getCategoryIcon(cat.name);

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceWhite,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFF0F0F5)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 6,
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
                                      color: color.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(icon, color: color, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          cat.name,
                                          style: const TextStyle(
                                            fontFamily: AppTheme.fontFamily,
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.textDark,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          cat.isDefault ? 'Kategori bawaan' : 'Kategori kustom',
                                          style: const TextStyle(
                                            fontFamily: AppTheme.fontFamily,
                                            fontSize: 11,
                                            color: AppTheme.textLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.textMedium),
                                    tooltip: 'Ubah Nama',
                                    onPressed: () => _showEditDialog(cat),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.dangerRed),
                                    tooltip: 'Hapus Kategori',
                                    onPressed: () => _confirmDelete(cat),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),

            const Divider(height: 1, color: Color(0xFFF0F0F5)),

            // Footer Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      side: const BorderSide(color: Color(0xFFFFD1DC)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _confirmResetDefaults,
                    icon: const Icon(Icons.restart_alt_rounded, size: 16, color: AppTheme.textMedium),
                    label: const Text(
                      'Reset Default',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMedium,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPink,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _showAddDialog,
                      icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                      label: const Text(
                        'Tambah Kategori',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
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
  }
}
