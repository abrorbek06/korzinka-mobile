import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/notification_detail_screen.dart';
import '../services/notifications_api.dart';
import '../theme/app_theme.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Bildirishnomalar'),
        backgroundColor: AppTheme.surface,
        elevation: 1,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemBuilder: (ctx, i) {
                  final n = _items[i];
                  return ListTile(
                    tileColor: n.isRead ? AppTheme.surface : AppTheme.primary.withOpacity(0.06),
                    leading: n.isRead
                        ? null
                        : Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                    title: Text(
                      n.title,
                      style: TextStyle(
                        fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: Text(_formatTime(n.createdAt)),
                    onTap: () async {
                      final marked = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => NotificationDetailScreen(notification: n),
                        ),
                      );
                      if (marked == true) {
                        setState(() {
                          _items = _items.map((e) {
                            if (e.id == n.id) {
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
                      }
                    },
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
