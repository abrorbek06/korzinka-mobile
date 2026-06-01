import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import '../theme/app_theme.dart';

class OrdersOrderCard extends StatelessWidget {
  final OrderListItem order;
  final VoidCallback onTap;
  final ValueChanged<OrderStatus>? onStatusSelected;
  final bool isDraggable;

  const OrdersOrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.onStatusSelected,
    this.isDraggable = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
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
            // const SizedBox(height: 12),
            // if (order.customerName != null)
            //   Text(
            //     'Mijoz: ${order.customerName!}',
            //     style: const TextStyle(
            //       fontSize: 13,
            //       fontWeight: FontWeight.w600,
            //     ),
            //   ),
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
                  order.totalItems > 0
                      ? '${order.totalItems} ta mahsulot'
                      : order.backorderedItemsCount > 0
                      ? '${order.backorderedItemsCount} ta mahsulot kerak'
                      : '0 ta mahsulot kerak',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.onSurfaceMuted,
                  ),
                ),
                // const Spacer(),
                // Container(
                //   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                //   decoration: BoxDecoration(
                //     color: order.status.lightColor,
                //     borderRadius: BorderRadius.circular(10),
                //   ),
                //   child: Text(
                //     order.status.displayName,
                //     style: TextStyle(
                //       fontSize: 11,
                //       fontWeight: FontWeight.w700,
                //       color: order.status.color,
                //     ),
                //   ),
                // ),
              ],
            ),
            const SizedBox(height: 10),
            if (onStatusSelected != null)
              PopupMenuButton<OrderStatus>(
                onSelected: onStatusSelected,
                itemBuilder: (_) => OrderStatus.values
                    .where((status) => status != order.status)
                    .map(
                      (status) => PopupMenuItem<OrderStatus>(
                        value: status,
                        child: Row(
                          children: [
                            Icon(status.icon, size: 16, color: status.color),
                            const SizedBox(width: 8),
                            Text(status.displayName),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: order.status.lightColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Text(
                        order.status.displayName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: order.status.color,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: 16,
                        color: order.status.color,
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: order.status.lightColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  order.status.displayName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: order.status.color,
                  ),
                ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: order.paymentStatus.color.withAlpha(
                      (0.15 * 255).round(),
                    ),
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
