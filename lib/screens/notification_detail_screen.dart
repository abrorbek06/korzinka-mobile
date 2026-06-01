import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notifications_provider.dart';
import '../services/notifications_api.dart';
import '../theme/app_theme.dart';
import '../utils/snackbar_utils.dart';

class NotificationDetailScreen extends StatefulWidget {
  const NotificationDetailScreen({super.key, required this.notification});

  final NotificationItem notification;

  @override
  State<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  late bool _isRead;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _isRead = widget.notification.isRead;
  }

  Future<void> _markRead() async {
    if (_isRead) return;
    final auth = context.read<AuthProvider>();
    setState(() => _saving = true);
    try {
      await NotificationsApi.markRead(auth.token!, widget.notification.id);
      setState(() {
        _isRead = true;
      });
      await context.read<NotificationsProvider>().refreshCount();
      context.showTopSnackBar(const Text('Bildirishnoma o‘qildi'));
      Navigator.of(context).pop(true);
    } catch (_) {
      context.showTopSnackBar(const Text('Belgilashda xatolik yuz berdi'));
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notification;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirishnoma detali'),
        backgroundColor: AppTheme.surface,
        elevation: 1,
      ),
      backgroundColor: AppTheme.background,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    n.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (!_isRead)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Yangi',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(n.body, style: const TextStyle(fontSize: 16, height: 1.5)),
            const SizedBox(height: 24),
            const Text(
              'Maʼlumotlar',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _buildMetaRow('Tur', n.type),
            _buildMetaRow('Entity', n.entityType),
            _buildMetaRow('Entity ID', n.entityId),
            _buildMetaRow('Yaratilgan', n.createdAt.toLocal().toString()),
            const Spacer(),
            if (!_isRead)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _markRead,
                  child: Text(
                    _saving ? 'Yozilmoqda...' : 'O‘qilgan deb belgilash',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(color: AppTheme.onSurfaceMuted),
            ),
          ),
        ],
      ),
    );
  }
}
