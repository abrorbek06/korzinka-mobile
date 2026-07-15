import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:korzinkab_mobile/l10n/app_localizations.dart';
import '../models/order_model.dart';
import '../theme/app_theme.dart';

class OrderCard extends StatelessWidget {
  final OrderListItem order;
  final VoidCallback onTap;
  final ValueChanged<OrderStatus>? onStatusSelected;

  const OrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.onStatusSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          // border: Border.all(color: AppTheme.border),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    order.code ?? 'DRAFT',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: order.code != null
                          ? AppTheme.onSurface
                          : AppTheme.onSurfaceMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // const SizedBox(width: 8),
                if (onStatusSelected != null)
                  PopupMenuButton<OrderStatus>(
                    onSelected: onStatusSelected,
                    itemBuilder: (_) => OrderStatus.values
                        .where((status) {
                          final hiddenStatuses = {
                            OrderStatus.DRAFT,
                            OrderStatus.CONFIRMED,
                            OrderStatus.OUT_FOR_DELIVERY,
                            OrderStatus.COMPLETED,
                            OrderStatus.CANCELLED,
                          };

                          return status != order.status &&
                              !hiddenStatuses.contains(status);
                        })
                        .map(
                          (status) => PopupMenuItem<OrderStatus>(
                            value: status,
                            child: Row(
                              children: [
                                Icon(
                                  status.icon,
                                  size: 16,
                                  color: status.color,
                                ),
                                const SizedBox(width: 8),
                                Text(status.displayName),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: order.status.lightColor,
                          // border: Border.all(color: order.status.color, width: 1.5),
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
                    ),
                  ),
              ],
            ),
            // if (order.customerName != null)
            //   Text(
            //     'Mijoz: ${order.customerName!}',
            //     style: const TextStyle(
            //       fontSize: 13,
            //       fontWeight: FontWeight.w600,
            //     ),
            //   ),
            // if (order.pickerId != null)
            //   Row(
            //     children: [
            //       SizedBox(
            //         width: 80,
            //         child: Text(
            //           AppLocalizations.of(context)!.picker,
            //           style: const TextStyle(
            //             fontSize: 12,
            //             color: Color(0xFF6B7280),
            //             fontWeight: FontWeight.w500,
            //           ),
            //         ),
            //       ),
            //       Expanded(
            //         child: Text(
            //           order.pickerName ?? '—',
            //           overflow: TextOverflow.ellipsis,
            //           maxLines: 1,
            //           style: TextStyle(
            //             fontSize: 12,
            //             fontWeight: FontWeight.w700,
            //             color: Colors.black87,
            //           ),
            //         ),
            //       ),
            //     ],
            //   ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  order.totalItems > 0
                      ? AppLocalizations.of(context)!.productCount(order.totalItems)
                      : order.backorderedItemsCount > 0
                      ? AppLocalizations.of(context)!.productsNeeded(order.backorderedItemsCount)
                      : AppLocalizations.of(context)!.productCount(0),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.onSurfaceMuted,
                  ),
                ),
                    Text(
                      order.pickerName ?? '—',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
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
            const SizedBox(height: 14),
            Divider(),
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
                Text(
                  order.endDate != null
                      ? DateFormat('HH:mm | d MMM, y').format(order.endDate!)
                      : DateFormat('HH:mm | d MMM, y').format(order.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.onSurfaceMuted,
                  ),
                ),

                // Container(
                //   padding: const EdgeInsets.symmetric(
                //     horizontal: 8,
                //     vertical: 4,
                //   ),
                //   decoration: BoxDecoration(
                //     color: order.paymentStatus.color.withAlpha(
                //       (0.15 * 255).round(),
                //     ),
                //     borderRadius: BorderRadius.circular(10),
                //   ),
                //   child: Text(
                //     order.paymentStatus.displayName,
                //     style: TextStyle(
                //       fontSize: 11,
                //       fontWeight: FontWeight.w700,
                //       color: order.paymentStatus.color,
                //     ),
                //   ),
                // ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
