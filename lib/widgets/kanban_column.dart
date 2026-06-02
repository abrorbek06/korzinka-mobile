import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../theme/app_theme.dart';
import 'long_press_move_card.dart';

class KanbanColumn extends StatelessWidget {
  final OrderStatus status;
  final List<OrderListItem> orders;
  final void Function(OrderListItem) onOrderTap;
  final void Function(OrderListItem, OrderStatus)? onStatusSelected;
  final void Function(OrderListItem, OrderStatus)? onOrderDrop;
  final double? width;
  final bool hideHeader;
  final bool addRightMargin;

  const KanbanColumn({
    super.key,
    required this.status,
    required this.orders,
    required this.onOrderTap,
    this.onStatusSelected,
    this.onOrderDrop,
    this.width,
    this.hideHeader = false,
    this.addRightMargin = true,
  });

  @override
  Widget build(BuildContext context) {
    final body = Container(
      width: width ?? 240,
      margin: addRightMargin
          ? const EdgeInsets.only(right: 12)
          : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!hideHeader) ...[
            // Column header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: status.color.withAlpha((0.12 * 255).round()),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: status.color.withAlpha((0.25 * 255).round()),
                ),
              ),
              child: Row(
                children: [
                  Icon(status.icon, size: 16, color: status.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      status.displayName.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: status.color,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: status.color,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      '${orders.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Cards list
          Expanded(
            child: orders.isEmpty
                ? _EmptyColumn(status: status)
                : ListView.separated(
                    itemCount: orders.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return LongPressMoveCard(
                        order: order,
                        onTap: () => onOrderTap(order),
                        onStatusSelected: onStatusSelected == null
                            ? null
                            : (targetStatus) =>
                                  onStatusSelected!(order, targetStatus),
                        isDraggable: onOrderDrop != null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );

    if (onOrderDrop == null) {
      return body;
    }

    return DragTarget<OrderListItem>(
      onWillAcceptWithDetails: (details) {
        return details.data.status != status;
      },
      onAcceptWithDetails: (details) {
        onOrderDrop!(details.data, status);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return Container(
          width: width ?? 240,
          margin: addRightMargin
              ? const EdgeInsets.only(right: 12)
              : EdgeInsets.zero,
          decoration: BoxDecoration(
            color: isHovered
                ? AppTheme.primary.withOpacity(0.05)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: body,
        );
      },
    );
  }
}

class _EmptyColumn extends StatelessWidget {
  final OrderStatus status;
  const _EmptyColumn({required this.status});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            status.icon,
            size: 28,
            color: AppTheme.onSurfaceMuted.withOpacity(0.4),
          ),
          const SizedBox(height: 8),
          Text(
            'No orders',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.onSurfaceMuted.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}
