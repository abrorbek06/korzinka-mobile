import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/constants.dart';
import '../models/order_model.dart';
import '../providers/picker_provider.dart';
import '../services/trolley_service.dart';
import '../theme/app_theme.dart';

class TrolleyPickerSheet extends StatefulWidget {
  final String orderId;
  final String? currentTrolley;

  const TrolleyPickerSheet({
    super.key,
    required this.orderId,
    this.currentTrolley,
  });

  static Future<void> show(
    BuildContext context, {
    required String orderId,
    String? currentTrolley,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TrolleyPickerSheet(
        orderId: orderId,
        currentTrolley: currentTrolley,
      ),
    );
  }

  @override
  State<TrolleyPickerSheet> createState() => _TrolleyPickerSheetState();
}

class _TrolleyPickerSheetState extends State<TrolleyPickerSheet> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentTrolley;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PickerProvider>();
    final trolleys = provider.getAllTrolleys();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (_, scroll) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shopping_cart_outlined,
                      size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.selectTrolley,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      AppStrings.trolleyHint,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Legend
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _LegendDot(color: AppColors.primary, label: 'Tanlangan'),
                const SizedBox(width: 16),
                _LegendDot(color: AppColors.yangiColor, label: 'Bo\'sh'),
                const SizedBox(width: 16),
                _LegendDot(color: AppColors.textMuted, label: 'Band'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                controller: scroll,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1,
                ),
                itemCount: trolleys.length,
                itemBuilder: (_, i) {
                  final t = trolleys[i];
                  final isSelected = _selected == t.code;
                  final isOther = t.assignedOrderId != null &&
                      t.assignedOrderId != widget.orderId;

                  return GestureDetector(
                    onTap: isOther ? null : () {
                      setState(() {
                        _selected = isSelected ? null : t.code;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : isOther
                                ? AppColors.background
                                : AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : isOther
                                  ? AppColors.border
                                  : AppColors.primaryLight,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${t.number}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? Colors.white
                                  : isOther
                                      ? AppColors.textMuted
                                      : AppColors.primary,
                              fontFamily: 'Nunito',
                            ),
                          ),
                          if (isOther)
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.textMuted.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'Band',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textMuted,
                                  fontFamily: 'Nunito',
                                ),
                              ),
                            ),
                          if (isSelected)
                            const Icon(Icons.check_circle,
                                size: 12, color: Colors.white),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Confirm button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selected == null
                      ? null
                      : () async {
                          await provider.assignTrolley(widget.orderId, _selected!);
                          if (context.mounted) Navigator.pop(context);
                        },
                  child: Text(_selected != null
                      ? '${AppStrings.confirm}: ${_selected}'
                      : AppStrings.selectTrolley),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(
          fontSize: 12, color: AppColors.textSecondary,
          fontWeight: FontWeight.w600, fontFamily: 'Nunito',
        )),
      ],
    );
  }
}
