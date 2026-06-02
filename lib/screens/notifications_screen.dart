import 'package:flutter/material.dart';
import 'package:korzinkab_mobile/providers/notifications_provider.dart';
import 'package:korzinkab_mobile/services/notifications_api.dart';
import 'package:korzinkab_mobile/theme/app_theme.dart';
import 'package:korzinkab_mobile/utils/snackbar_utils.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationItem> _items = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) return;
    setState(() => _loading = true);
    try {
      final items = await NotificationsApi.fetchNotifications(auth.token!);
      setState(() => _items = items);
    } catch (_) {
      // ignore
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _markReadNotification(NotificationItem notification) async {
    final auth = context.read<AuthProvider>();
    try {
      await NotificationsApi.markRead(auth.token!, notification.id);
      setState(() {
        _items = _items.map((e) {
          if (e.id == notification.id) {
            return NotificationItem(
              id: e.id,
              notificationId: e.notificationId,
              type: e.type,
              entityType: e.entityType,
              entityId: e.entityId,
              title: e.title,
              body: e.body,
              createdAt: e.createdAt,
              isRead: true,
            );
          }
          return e;
        }).toList();
      });
      await context.read<NotificationsProvider>().refreshCount();
      context.showTopSnackBar(const Text('Bildirishnoma o‘qildi'));
    } catch (_) {
      context.showTopSnackBar(const Text('Belgilashda xatolik yuz berdi'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Bildirishnomalar'),
        backgroundColor: AppTheme.surface,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemBuilder: (ctx, i) {
                  final n = _items[i];
                  return GestureDetector(
                    onTap: n.isRead ? null : () => _markReadNotification(n),
                    child: Container(
                      width: double.infinity,
                      height: 80,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: n.isRead ? AppTheme.border : AppTheme.primary,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.all(14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Text(
                                n.title,
                                style: TextStyle(
                                  color: AppTheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                n.body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppTheme.onSurfaceMuted,
                                  fontSize: 13,
                                  fontWeight: n.isRead
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Text(_formatTime(n.createdAt)),
                        ],
                      ),
                    ),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemCount: _items.length,
              ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${dt.year}/${dt.month}/${dt.day}';
  }
}
