import 'package:flutter/material.dart';

enum SyncStatus {
  synced,
  pending,
  syncing,
  failed,
}

class SyncStatusIndicator extends StatelessWidget {
  final SyncStatus status;
  final double? size;
  final bool showLabel;

  const SyncStatusIndicator({
    super.key,
    required this.status,
    this.size,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildIcon(),
        if (showLabel) ...[
          const SizedBox(width: 4),
          _buildLabel(),
        ],
      ],
    );
  }

  Widget _buildIcon() {
    switch (status) {
      case SyncStatus.synced:
        return Icon(
          Icons.check_circle,
          color: Colors.green,
          size: size ?? 16,
        );
      
      case SyncStatus.pending:
        return Icon(
          Icons.cloud_upload,
          color: Colors.orange,
          size: size ?? 16,
        );
      
      case SyncStatus.syncing:
        return SizedBox(
          width: size ?? 16,
          height: size ?? 16,
          child: const CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        );
      
      case SyncStatus.failed:
        return Icon(
          Icons.error,
          color: Colors.red,
          size: size ?? 16,
        );
    }
  }

  Widget _buildLabel() {
    String text;
    Color color;

    switch (status) {
      case SyncStatus.synced:
        text = 'Synced';
        color = Colors.green;
        break;
      case SyncStatus.pending:
        text = 'Pending Sync';
        color = Colors.orange;
        break;
      case SyncStatus.syncing:
        text = 'Syncing...';
        color = Colors.blue;
        break;
      case SyncStatus.failed:
        text = 'Sync Failed';
        color = Colors.red;
        break;
    }

    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class ConnectivityStatusIndicator extends StatelessWidget {
  final bool isOnline;
  final bool showLabel;

  const ConnectivityStatusIndicator({
    super.key,
    required this.isOnline,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isOnline ? Icons.wifi : Icons.wifi_off,
          color: isOnline ? Colors.green : Colors.red,
          size: 16,
        ),
        if (showLabel) ...[
          const SizedBox(width: 4),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              color: isOnline ? Colors.green : Colors.red,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class SyncStatusBar extends StatelessWidget {
  final bool isOnline;
  final bool isSyncing;
  final int pendingCount;
  final String? lastError;
  final VoidCallback? onRetry;

  const SyncStatusBar({
    super.key,
    required this.isOnline,
    required this.isSyncing,
    required this.pendingCount,
    this.lastError,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isOnline ? Colors.green.shade50 : Colors.red.shade50,
        border: Border(
          bottom: BorderSide(
            color: isOnline ? Colors.green.shade200 : Colors.red.shade200,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          ConnectivityStatusIndicator(isOnline: isOnline, showLabel: true),
          const Spacer(),
          if (pendingCount > 0) ...[
            SyncStatusIndicator(
              status: isSyncing ? SyncStatus.syncing : SyncStatus.pending,
              showLabel: true,
            ),
            const SizedBox(width: 8),
            Text(
              '$pendingCount pending',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
            ),
          ],
          if (lastError != null && onRetry != null) ...[
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
