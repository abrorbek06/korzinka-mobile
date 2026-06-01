import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import '../theme/app_theme.dart';

class OrderListTile extends StatelessWidget {
  final OrderSummary order;
  final String? trolleyCode;
  final VoidCallback onTap;

  const OrderListTile({
    super.key,
    required this.order,
    this.trolleyCode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: [AppTheme.cardShadow],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order code + time
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          order.code ?? '#---',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            fontFamily: 'Nunito',
                          ),
                        ),
                        const Spacer(),
                        Text(
                          DateFormat('HH:mm').format(order.createdAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Customer
                    if (order.customerName != null)
                      Text(
                        'Mijoz: ${order.customerName}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                    const SizedBox(height: 5),

                    // Trolley assignment
                    if (trolleyCode != null)
                      Row(
                        children: [
                          const Icon(
                            Icons.shopping_cart_outlined,
                            size: 13,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Arava: $trolleyCode',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Nunito',
                            ),
                          ),
                        ],
                      )
                    else if (order.status == OrderStatus.IN_COLLECTION ||
                        order.status == OrderStatus.PARTIAL)
                      Row(
                        children: [
                          const Icon(
                            Icons.add_shopping_cart,
                            size: 13,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Arava tayinlanmagan',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Nunito',
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 6),

                    // Items count
                    Row(
                      children: [
                        Text(
                          _itemsText(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            fontFamily: 'Nunito',
                          ),
                        ),
                        if (order.backorderedCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.qismanColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${order.backorderedCount} kutilmoqda',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.qismanColor,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Nunito',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Arrow
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _itemsText() {
    if (order.status == OrderStatus.PARTIAL && order.backorderedCount > 0) {
      final ok = order.totalItems - order.backorderedCount;
      return '$ok/${order.totalItems} mahsulot';
    }
    return '${order.totalItems} mahsulot';
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class StatusSectionHeader extends StatelessWidget {
  final OrderStatus status;
  final int count;

  const StatusSectionHeader({
    super.key,
    required this.status,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        children: [
          Text(
            status.uzName,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: status.color,
              fontFamily: 'Nunito',
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: status.color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontFamily: 'Nunito',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
