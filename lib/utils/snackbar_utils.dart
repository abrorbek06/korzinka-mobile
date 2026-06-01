import 'dart:async';

import 'package:flutter/material.dart';

OverlayEntry? _currentTopOverlayEntry;
Timer? _currentTopOverlayTimer;

extension SnackbarUtils on BuildContext {
  void showTopSnackBar(
    Widget content, {
    Duration duration = const Duration(seconds: 3),
    Color backgroundColor = const Color(0xFF2DD06F),
  }) {
    final double topPadding = MediaQuery.of(this).viewPadding.top + 8.0;

    _showTopOverlay(
      content: content,
      topPadding: topPadding,
      duration: duration,
      backgroundColor: backgroundColor,
    );
  }

  /// Convenience when you only have a plain text message.
  void showTopMessage(
    String message, {
    Duration duration = const Duration(seconds: 3),
    Color backgroundColor = const Color(0xFF2DD06F),
    IconData icon = Icons.check_circle,
    Color iconColor = Colors.white,
    double iconSize = 18,
  }) {
    final double topPadding = MediaQuery.of(this).viewPadding.top + 8.0;
    _showTopOverlay(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: iconSize),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
      topPadding: topPadding,
      duration: duration,
      backgroundColor: backgroundColor,
    );
  }

  void _showTopOverlay({
    required Widget content,
    required double topPadding,
    required Duration duration,
    required Color backgroundColor,
  }) {
    final overlay = Overlay.of(this, rootOverlay: true);
    if (overlay == null) {
      return;
    }

    _currentTopOverlayEntry?.remove();
    _currentTopOverlayTimer?.cancel();

    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: topPadding,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: DefaultTextStyle(
              style: const TextStyle(color: Colors.white, fontSize: 14),
              child: content,
            ),
          ),
        ),
      ),
    );

    _currentTopOverlayEntry = overlayEntry;
    overlay.insert(overlayEntry);
    _currentTopOverlayTimer = Timer(duration, () {
      overlayEntry.remove();
      if (_currentTopOverlayEntry == overlayEntry) {
        _currentTopOverlayEntry = null;
      }
      _currentTopOverlayTimer = null;
    });
  }
}
