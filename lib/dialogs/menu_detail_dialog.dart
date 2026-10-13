import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/menu_item_model.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/custom_image_view.dart';

class MenuDetailDialog extends StatefulWidget {
  final MenuItemModel item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleStatus;
  final ValueChanged<int>? onUpdateStock;

  const MenuDetailDialog({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStatus,
    this.onUpdateStock,
  });

  @override
  State<MenuDetailDialog> createState() => _MenuDetailDialogState();
}

class _MenuDetailDialogState extends State<MenuDetailDialog> {
  late int _currentStock;
  late bool _isAvailable;

  @override
  void initState() {
    super.initState();
    _currentStock = widget.item.stock;
    _isAvailable = widget.item.isAvailable;
  }

  void _showQuickStockDialog(BuildContext context) {
    int tempStock = _currentStock;
    final TextEditingController stockController = TextEditingController(text: '$tempStock');

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
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
                  child: const Icon(Icons.inventory_2_rounded, color: AppTheme.primaryPink, size: 22),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Kelola Stok Menu',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.item.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMedium,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Stock Stepper + Manual Keyboard Number Input
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.softPinkBackground.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFFE0E6)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Decrement Button
                        IconButton.filledTonal(
                          onPressed: tempStock > 0
                              ? () {
                                  final next = (tempStock - 1).clamp(0, 999999);
                                  setDialogState(() {
                                    tempStock = next;
                                    stockController.text = '$next';
                                    stockController.selection = TextSelection.fromPosition(
                                      TextPosition(offset: stockController.text.length),
                                    );
                                  });
                                }
                              : null,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.primaryPinkDark,
                          ),
                          icon: const Icon(Icons.remove_rounded),
                        ),

                        // Editable Number Field (Keyboard Number)
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IntrinsicWidth(
                                child: TextField(
                                  controller: stockController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textDark,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    hintText: '0',
                                  ),
                                  onChanged: (value) {
                                    final parsed = int.tryParse(value) ?? 0;
                                    setDialogState(() {
                                      tempStock = parsed;
                                    });
                                  },
                                ),
                              ),
                              const Text(
                                'porsi',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textMedium,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Increment Button
                        IconButton.filledTonal(
                          onPressed: () {
                            final next = (tempStock + 1).clamp(0, 999999);
                            setDialogState(() {
                              tempStock = next;
                              stockController.text = '$next';
                              stockController.selection = TextSelection.fromPosition(
                                TextPosition(offset: stockController.text.length),
                              );
                            });
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.primaryPinkDark,
                          ),
                          icon: const Icon(Icons.add_rounded),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Ketuk angka di atas untuk mengetik manual',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      color: AppTheme.textLight,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Quick Increment Chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildStockAddChip('+5', () {
                        final next = tempStock + 5;
                        setDialogState(() {
                          tempStock = next;
                          stockController.text = '$next';
                          stockController.selection = TextSelection.fromPosition(
                            TextPosition(offset: stockController.text.length),
                          );
                        });
                      }),
                      _buildStockAddChip('+10', () {
                        final next = tempStock + 10;
                        setDialogState(() {
                          tempStock = next;
                          stockController.text = '$next';
                          stockController.selection = TextSelection.fromPosition(
                            TextPosition(offset: stockController.text.length),
                          );
                        });
                      }),
                      _buildStockAddChip('+20', () {
                        final next = tempStock + 20;
                        setDialogState(() {
                          tempStock = next;
                          stockController.text = '$next';
                          stockController.selection = TextSelection.fromPosition(
                            TextPosition(offset: stockController.text.length),
                          );
                        });
                      }),
                      _buildStockAddChip('+50', () {
                        final next = tempStock + 50;
                        setDialogState(() {
                          tempStock = next;
                          stockController.text = '$next';
                          stockController.selection = TextSelection.fromPosition(
                            TextPosition(offset: stockController.text.length),
                          );
                        });
                      }),
                      _buildStockAddChip(
                        'Habis (0)',
                        () {
                          setDialogState(() {
                            tempStock = 0;
                            stockController.text = '0';
                            stockController.selection = TextSelection.fromPosition(
                              TextPosition(offset: stockController.text.length),
                            );
                          });
                        },
                        isDestructive: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () {
                  final finalStock = int.tryParse(stockController.text.trim()) ?? tempStock;
                  Navigator.pop(dialogCtx);

                  setState(() {
                    _currentStock = finalStock;
                    _isAvailable = finalStock > 0;
                  });

                  widget.onUpdateStock?.call(finalStock);
                },
                child: const Text('Simpan Stok'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStockAddChip(String label, VoidCallback onTap, {bool isDestructive = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDestructive ? const Color(0xFFFFEBEE) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDestructive ? const Color(0xFFFFCDD2) : const Color(0xFFFFD1DC),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: isDestructive ? AppTheme.dangerRed : AppTheme.primaryPinkDark,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top drag indicator
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Image header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Stack(
                  children: [
                    CustomImageView(
                      imagePath: widget.item.imagePath,
                      type: widget.item.type,
                      height: 220,
                      width: double.infinity,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Text(
                          widget.item.subCategoryName,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryPinkDark,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: _currentStock > 0
                                  ? const Color(0xFF2E7D32)
                                  : AppTheme.dangerRed,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _currentStock > 0 ? 'Stok: $_currentStock' : 'Stok: 0',
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: (_isAvailable && _currentStock > 0)
                                  ? AppTheme.successGreen
                                  : AppTheme.dangerRed,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              (_isAvailable && _currentStock > 0) ? 'Tersedia' : 'Habis',
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.item.name,
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          Formatters.currency(widget.item.price),
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: (!_isAvailable || _currentStock <= 0)
                                ? AppTheme.primaryPink.withValues(alpha: 0.38)
                                : AppTheme.primaryPink,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Stock Management Row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.softPinkBackground.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFFE0E6)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.inventory_2_rounded, color: AppTheme.primaryPink, size: 20),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Stok Menu',
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 11,
                                      color: AppTheme.textMedium,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '$_currentStock porsi tersisa',
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _currentStock > 0 ? AppTheme.textDark : AppTheme.dangerRed,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (widget.onUpdateStock != null)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: const BorderSide(color: Color(0xFFFFD1DC)),
                                ),
                              ),
                              onPressed: () => _showQuickStockDialog(context),
                              icon: const Icon(Icons.edit_note_rounded, size: 16, color: AppTheme.primaryPinkDark),
                              label: const Text(
                                'Ubah Stok',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryPinkDark,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (widget.item.description != null && widget.item.description!.isNotEmpty) ...[
                      const Text(
                        'Deskripsi',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.item.description!,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13,
                          color: AppTheme.textMedium,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    const Divider(color: Color(0xFFFFE5EC)),
                    const SizedBox(height: 8),

                    // Actions Row
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: (_isAvailable && _currentStock > 0)
                                  ? AppTheme.warningOrange
                                  : AppTheme.successGreen,
                              side: BorderSide(
                                color: (_isAvailable && _currentStock > 0)
                                    ? AppTheme.warningOrange
                                    : AppTheme.successGreen,
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: Icon(
                              (_isAvailable && _currentStock > 0)
                                  ? Icons.remove_circle_outline
                                  : Icons.check_circle_outline,
                              size: 18,
                            ),
                            label: Text(
                              (_isAvailable && _currentStock > 0) ? 'Tandai Habis' : 'Tandai Tersedia',
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              widget.onToggleStatus();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          style: IconButton.styleFrom(
                            backgroundColor: AppTheme.softPinkBackground,
                            foregroundColor: AppTheme.primaryPink,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onEdit();
                          },
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.red.shade50,
                            foregroundColor: AppTheme.dangerRed,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onDelete();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
