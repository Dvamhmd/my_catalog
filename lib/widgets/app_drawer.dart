import 'package:flutter/material.dart';
import '../screens/settings_screen.dart';
import '../theme/app_theme.dart';

enum AppDrawerMenu {
  admin,
  kasir,
  riwayatTransaksi,
}

class AppDrawer extends StatelessWidget {
  final AppDrawerMenu activeMenu;
  final ValueChanged<AppDrawerMenu> onSelectMenu;
  final VoidCallback? onDataChanged;

  const AppDrawer({
    super.key,
    required this.activeMenu,
    required this.onSelectMenu,
    this.onDataChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppTheme.surfaceWhite,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Header Drawer
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.of(context).padding.top + 24,
                20,
                22,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFFFF0F5),
                    Color(0xFFFFDDE6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border(
                  bottom: BorderSide(
                    color: Color(0xFFFFD1DC),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryPink.withValues(alpha: 0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: const Color(0xFFFFCCD8),
                        width: 1.5,
                      ),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/app_logo.webp',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'My Catalog',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryPinkDark,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFFFD1DC),
                              width: 0.8,
                            ),
                          ),
                          child: const Text(
                            'Katalog & Kasir POS',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryPinkDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Menu Content for safe responsive rendering on all screens
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),

                    // Section: Navigasi
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Text(
                        'MENU NAVIGASI',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textLight.withValues(alpha: 0.85),
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),

                    // 1. Menu Admin
                    _buildMenuItem(
                      context: context,
                      menu: AppDrawerMenu.admin,
                      title: 'Menu Admin',
                      subtitle: 'Kelola katalog menu & stok produk',
                      icon: Icons.inventory_2_rounded,
                      isActive: activeMenu == AppDrawerMenu.admin,
                    ),

                    const SizedBox(height: 4),

                    // 2. Menu Kasir
                    _buildMenuItem(
                      context: context,
                      menu: AppDrawerMenu.kasir,
                      title: 'Menu Kasir',
                      subtitle: 'Transaksi penjualan & pembayaran',
                      icon: Icons.point_of_sale_rounded,
                      isActive: activeMenu == AppDrawerMenu.kasir,
                    ),

                    const SizedBox(height: 4),

                    // 3. Menu Riwayat Transaksi
                    _buildMenuItem(
                      context: context,
                      menu: AppDrawerMenu.riwayatTransaksi,
                      title: 'Riwayat Transaksi',
                      subtitle: 'Daftar transaksi & detail struk',
                      icon: Icons.receipt_long_rounded,
                      isActive: activeMenu == AppDrawerMenu.riwayatTransaksi,
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Section: Settings Button
            const Divider(height: 1, color: Color(0xFFF2F2F5)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    Navigator.of(context).pop(); // Close drawer
                    final changed = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => SettingsScreen(
                          onDataChanged: onDataChanged,
                        ),
                      ),
                    );
                    if (changed == true) {
                      onDataChanged?.call();
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200, width: 1),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.softPinkBackground,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.settings_rounded,
                            size: 20,
                            color: AppTheme.primaryPink,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Pengaturan',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 13,
                          color: AppTheme.textLight,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required AppDrawerMenu menu,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isActive,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).pop(); // Close drawer
            if (!isActive) {
              onSelectMenu(menu);
            }
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isActive ? AppTheme.softPinkBackground : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isActive ? const Color(0xFFFFD1DC) : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isActive ? AppTheme.primaryPink : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: isActive ? Colors.white : AppTheme.textMedium,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 14.5,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                          color: isActive ? AppTheme.primaryPinkDark : AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: isActive
                              ? AppTheme.primaryPinkDark.withValues(alpha: 0.8)
                              : AppTheme.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isActive)
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppTheme.primaryPink,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
