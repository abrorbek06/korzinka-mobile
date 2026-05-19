import 'package:flutter/material.dart';
import '../models/order_model.dart';

class StatusBadge extends StatelessWidget {
  final OrderStatus status;
  final bool small;

  const StatusBadge({super.key, required this.status, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: status.lightColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.uzName,
        style: TextStyle(
          fontSize: small ? 11 : 12,
          fontWeight: FontWeight.w700,
          color: status.color,
          fontFamily: 'Nunito',
        ),
      ),
    );
  }
}
