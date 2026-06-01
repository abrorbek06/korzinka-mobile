import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/audit_log_model.dart';
import '../models/order_model.dart';
import '../theme/app_theme.dart';

class AuditLogTile extends StatelessWidget {
  final AuditLog log;
  final bool isFirst;
  final bool isLast;

  const AuditLogTile({
    super.key,
    required this.log,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline indicator
          SizedBox(
            width: 32,
            child: Column(
              children: [
                if (!isFirst)
                  Container(width: 2, height: 12, color: AppTheme.border),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _dotColor(),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.surface, width: 2),
                  ),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 2, color: AppTheme.border)),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Action label
                  Text(
                    log.actionLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Performer + time
                  Row(
                    children: [
                      if (log.performedByName != null) ...[
                        Icon(
                          Icons.person_outline,
                          size: 12,
                          color: AppTheme.onSurfaceMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          log.performedByName!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.onSurfaceMuted,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(
                            color: AppTheme.onSurfaceMuted,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                      Text(
                        DateFormat('dd MMM yyyy, HH:mm').format(log.createdAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.onSurfaceMuted,
                        ),
                      ),
                    ],
                  ),

                  // Notes
                  if (log.notes != null && log.notes!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Text(
                        log.notes!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.onSurfaceMuted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _dotColor() {
    if (log.toStatus != null) {
      try {
        return OrderStatus.values
            .firstWhere((s) => s.name == log.toStatus)
            .color;
      } catch (_) {}
    }
    return AppTheme.primary;
  }
}
