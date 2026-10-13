import 'package:flutter/material.dart';
import '../services/dummy_data_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onDataChanged;

  const SettingsScreen({
    super.key,
    this.onDataChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DummyDataService _dummyService = DummyDataService.instance;
  bool _isDummyActive = false;
  bool _isTogglingDummy = false;
  bool _hasChanged = false;

  @override
  void initState() {
    super.initState();
    _loadDummyState();
  }

  Future<void> _loadDummyState() async {
    final active = await _dummyService.isDummyDataEnabled();
    if (mounted) {
      setState(() {
        _isDummyActive = active;
      });
    }
  }

  Future<void> _handleToggleDummy(bool value) async {
    if (_isTogglingDummy) return;

    setState(() {
      _isTogglingDummy = true;
    });

    final success = await _dummyService.toggleDummyData(value);
    if (!mounted) return;

    setState(() {
      _isDummyActive = success ? value : _isDummyActive;
      _isTogglingDummy = false;
      _hasChanged = true;
    });

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              value ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value ? 'Data dummy diaktifkan' : 'Data dummy dinonaktifkan',
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: value ? AppTheme.primaryPinkDark : const Color(0xFF4A4A5A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(milliseconds: 2500),
      ),
    );

    widget.onDataChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceWhite,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppTheme.textDark,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(_hasChanged),
          tooltip: 'Kembali',
        ),
        title: const Text(
          'Pengaturan',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: const Color(0xFFF0F0F5),
            height: 1,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(
                'DATA & PENGUJIAN',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textLight.withValues(alpha: 0.85),
                  letterSpacing: 0.6,
                ),
              ),
            ),

            // Card Container for Settings Items
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF0F0F5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _isDummyActive
                            ? AppTheme.softPinkBackground
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        size: 20,
                        color: _isDummyActive
                            ? AppTheme.primaryPink
                            : AppTheme.textMedium,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'Data Dummy',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ),
                    if (_isTogglingDummy)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.primaryPink,
                          ),
                        ),
                      )
                    else
                      Switch(
                        value: _isDummyActive,
                        activeThumbColor: AppTheme.primaryPink,
                        activeTrackColor: const Color(0xFFFFCCD8),
                        inactiveThumbColor: Colors.grey.shade400,
                        inactiveTrackColor: Colors.grey.shade200,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: _handleToggleDummy,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
