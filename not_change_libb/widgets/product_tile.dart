import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/order_model.dart';
import '../providers/picker_provider.dart';
import '../theme/app_theme.dart';

class ProductItemTile extends StatelessWidget {
  final OrderProduct product;

  const ProductItemTile({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Consumer<PickerProvider>(
      builder: (context, provider, _) {
        final collected = provider.getCollected(product.id);
        final statusCode = provider.itemCollectedStatus(
          product.id,
          product.requiredQty,
        );

        return Container(
          padding: const EdgeInsets.fromLTRB(0, 14, 16, 14),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.divider, width: 1),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Product image
              Container(
                width: 52,
                height: 52,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: product.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          product.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const _ProductPlaceholder(),
                        ),
                      )
                    : const _ProductPlaceholder(),
              ),

              // Name + SKU + required
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.productName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontFamily: 'Nunito',
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (product.productSku != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'SKU: ${product.productSku}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Kerak: ${product.requiredQty} ${product.unit}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Nunito',
                      ),
                    ),
                    // Backordered warning
                    if (statusCode == 1 && collected > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          '${product.requiredQty - collected} ta yetishmaydi',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.qismanColor,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Nunito',
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Stepper
              Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StepBtn(
                        icon: Icons.remove,
                        onTap: () => provider.decrementCollected(product.id),
                        enabled: collected > 0,
                      ),
                      Container(
                        width: 40,
                        alignment: Alignment.center,
                        child: Text(
                          '$collected',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            fontFamily: 'Nunito',
                          ),
                        ),
                      ),
                      _StepBtn(
                        icon: Icons.add,
                        onTap: () => provider.incrementCollected(
                          product.id,
                          max: product.requiredQty,
                        ),
                        enabled: collected < product.requiredQty,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _StatusIcon(statusCode: statusCode),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  const _StepBtn({
    required this.icon,
    required this.onTap,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: enabled ? AppColors.primaryLight : AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled
                ? AppColors.primary.withOpacity(0.3)
                : AppColors.border,
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? AppColors.primary : AppColors.textMuted,
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final int statusCode;
  const _StatusIcon({required this.statusCode});

  @override
  Widget build(BuildContext context) {
    switch (statusCode) {
      case 2:
        return Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.itemGreen.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, size: 13, color: AppColors.itemGreen),
        );
      case 1:
        return Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.itemOrange.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.circle, size: 8, color: AppColors.itemOrange),
        );
      default:
        return Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.itemRed.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.priority_high,
            size: 13,
            color: AppColors.itemRed,
          ),
        );
    }
  }
}

class _ProductPlaceholder extends StatelessWidget {
  const _ProductPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.inventory_2_outlined,
      size: 24,
      color: AppColors.textMuted,
    );
  }
}
