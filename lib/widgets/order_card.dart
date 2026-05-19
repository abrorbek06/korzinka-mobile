import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import '../theme/app_theme.dart';

class OrderCard extends StatelessWidget {
  final OrderListItem order;
  final VoidCallback onTap;

  const OrderCard({super.key, required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = order.status;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    order.code ?? 'DRAFT',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: order.code != null
                          ? AppTheme.onSurface
                          : AppTheme.onSurfaceMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  order.endDate != null
                      ? DateFormat('HH:mm').format(order.endDate!)
                      : DateFormat('HH:mm').format(order.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.onSurfaceMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (order.customerName != null)
              Text(
                'Mijoz: ${order.customerName!}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  size: 14,
                  color: AppTheme.onSurfaceMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  '${order.totalItems} ta mahsulot',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.onSurfaceMuted,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: status.lightColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    status.displayName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: status.color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  order.paymentType.icon,
                  size: 14,
                  color: AppTheme.onSurfaceMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  order.paymentType.displayName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.onSurfaceMuted,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: order.paymentStatus.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    order.paymentStatus.displayName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: order.paymentStatus.color,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
