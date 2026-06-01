import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../theme/app_theme.dart';
import 'order_card.dart';

/// A card wrapper that starts dragging after a 1 second long press.
/// Normal taps and scrolling remain unaffected.
class LongPressMoveCard extends StatefulWidget {
  final OrderListItem order;
  final VoidCallback onTap;
  final ValueChanged<OrderStatus>? onStatusSelected;
  final bool isDraggable;

  const LongPressMoveCard({
    super.key,
    required this.order,
    required this.onTap,
    this.onStatusSelected,
    this.isDraggable = true,
  });

  @override
  State<LongPressMoveCard> createState() => _LongPressMoveCardState();
}

class _LongPressMoveCardState extends State<LongPressMoveCard> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.isDraggable) {
      return _buildAnimatedCard(armed: false);
    }

    return LongPressDraggable<OrderListItem>(
      data: widget.order,
      delay: const Duration(milliseconds: 100),
      hapticFeedbackOnStart: true,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 240,
          child: Opacity(
            opacity: 0.95,
            child: _buildAnimatedCard(armed: true, forFeedback: true),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.25,
        child: _buildAnimatedCard(armed: false),
      ),
      onDragStarted: () {
        setState(() {
          _dragging = true;
        });
      },
      onDragEnd: (_) {
        setState(() {
          _dragging = false;
        });
      },
      child: _buildAnimatedCard(armed: _dragging),
    );
  }

  Widget _buildAnimatedCard({required bool armed, bool forFeedback = false}) {
    final double translateY = armed ? -8.0 : 0.0;
    final double scale = armed ? (forFeedback ? 1.02 : 1.01) : 1.0;
    final boxShadow = armed
        ? [
            BoxShadow(
              color: Colors.black.withAlpha((0.18 * 255).round()),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withAlpha((0.04 * 255).round()),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: armed ? AppTheme.primary.withAlpha(230) : AppTheme.border,
          width: armed ? 2.0 : 1.0,
        ),
        boxShadow: boxShadow,
      ),
      child: Transform.translate(
        offset: Offset(0.0, translateY),
        child: Transform.scale(
          scale: scale,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                OrderCard(
                  order: widget.order,
                  onTap: widget.onTap,
                  onStatusSelected: widget.onStatusSelected,
                ),
                if (armed)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.topCenter,
                            radius: 1.2,
                            colors: [
                              AppTheme.primary.withAlpha(15),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
