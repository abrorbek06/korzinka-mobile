import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/order_model.dart';
import '../providers/auth_provider.dart';
import '../providers/orders_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/kanban_column.dart';
import '../widgets/transition_sheet.dart';
import 'order_detail_screen.dart';

class KanbanScreen extends StatefulWidget {
  const KanbanScreen({super.key});

  @override
  State<KanbanScreen> createState() => _KanbanScreenState();
}

class _KanbanScreenState extends State<KanbanScreen> {
  // Which columns to show (terminal columns hidden by default for cleaner view)
  final Set<OrderStatus> _hiddenStatuses = {};
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _loadHiddenStatuses();
  }

  Future<void> _loadHiddenStatuses() async {
    final prefs = await SharedPreferences.getInstance();
    final hiddenStatusesJson = prefs.getString(AppConfig.hiddenStatusesKey);
    if (hiddenStatusesJson != null) {
      final List<String> statusStrings = (jsonDecode(hiddenStatusesJson) as List).cast<String>();
      setState(() {
        _hiddenStatuses.clear();
        for (final statusStr in statusStrings) {
          final status = OrderStatus.values.where((s) => s.name == statusStr).firstOrNull;
          if (status != null) {
            _hiddenStatuses.add(status);
          }
        }
      });
    }
  }

  Future<void> _saveHiddenStatuses() async {
    final prefs = await SharedPreferences.getInstance();
    final statusStrings = _hiddenStatuses.map((s) => s.name).toList();
    await prefs.setString(AppConfig.hiddenStatusesKey, jsonEncode(statusStrings));
  }

  static const List<OrderStatus> _columnOrder = [
    OrderStatus.DRAFT,
    OrderStatus.CONFIRMED,
    OrderStatus.IN_COLLECTION,
    OrderStatus.PARTIAL,
    OrderStatus.READY,
    OrderStatus.COMPLETED,
    // OrderStatus.CANCELLED,
  ];

  List<OrderStatus> get _visibleStatuses =>
      _columnOrder.where((s) => !_hiddenStatuses.contains(s)).toList();

  Future<void> _onOrderDrop(OrderListItem orderListItem, OrderStatus targetStatus) async {
    final auth = context.read<AuthProvider>();
    final user = auth.user!;

    // Check if the user has permission to transition to the target status
    final allowedTransitions = availableTransitions(orderListItem.status, user.role.name);
    final hasPermission = allowedTransitions.any((t) => t.to == targetStatus);

    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You do not have permission to move to ${targetStatus.displayName}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final ordersProvider = context.read<OrdersProvider>();
    
    // Show a loading dialog temporarily while fetching details
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    await ordersProvider.loadOrderDetail(orderListItem.id);
    if (mounted) Navigator.pop(context); // Close loading
    
    if (ordersProvider.error != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load order: ${ordersProvider.error}')),
        );
      }
      return;
    }

    final orderDetail = ordersProvider.selectedOrder;
    if (orderDetail != null && mounted) {
      TransitionSheet.show(
        context,
        order: orderDetail,
        user: user,
        initialTarget: targetStatus,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final orders = context.watch<OrdersProvider>();
    final user = auth.user!;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leadingWidth: 20,
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.view_kanban_outlined, color: Color(0xFF0F1923), size: 16),
            ),
            const SizedBox(width: 10),
            const Text('Kanban'),
            if (orders.refreshing) ...[
              const SizedBox(width: 10),
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
              ),
            ],
          ],
        ),
        actions: [
          // Total count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(
                  '${orders.totalOrdersCount()} orders',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurfaceMuted,
                  ),
                ),
              ),
            ),
          ),
          // Filter toggle
          IconButton(
            icon: Icon(
              _showFilters ? Icons.filter_list_off : Icons.filter_list,
              color: _showFilters ? AppTheme.primary : null,
            ),
            tooltip: 'Toggle Columns',
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
          // Refresh
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Refresh',
            onPressed: orders.loading ? null : () => orders.refreshAll(),
          ),
          // User menu
          PopupMenuButton<String>(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                    ),
                    child: Center(
                      child: Text(
                        user.username[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.username,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(
                      user.role.displayName,
                      style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceMuted),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'logout', child: Text('Sign Out')),
            ],
            onSelected: (value) async {
              if (value == 'logout') await auth.logout();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Column visibility filters
          if (_showFilters) _ColumnFilters(
            visibleStatuses: _visibleStatuses,
            onToggle: (status) {
              setState(() {
                if (_hiddenStatuses.contains(status)) {
                  _hiddenStatuses.remove(status);
                } else {
                  _hiddenStatuses.add(status);
                }
              });
              _saveHiddenStatuses();
            },
          ),

          // Error banner
          if (orders.error != null)
            MaterialBanner(
              content: Text(orders.error!),
              backgroundColor: const Color(0xFFEF4444).withOpacity(0.15),
              actions: [
                TextButton(
                  onPressed: orders.clearError,
                  child: const Text('Dismiss'),
                ),
              ],
            ),

          // Kanban board
          Expanded(
            child: orders.loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: orders.refreshAll,
                    color: AppTheme.primary,
                    backgroundColor: AppTheme.surface,
                    child: _KanbanBoard(
                      columns: orders.columns,
                      visibleStatuses: _visibleStatuses,
                      onOrderTap: (order) => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChangeNotifierProvider.value(
                            value: orders,
                            child: OrderDetailScreen(orderId: order.id),
                          ),
                        ),
                      ),
                      onOrderDrop: _onOrderDrop,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _KanbanBoard extends StatefulWidget {
  final Map<OrderStatus, List<OrderListItem>> columns;
  final List<OrderStatus> visibleStatuses;
  final void Function(OrderListItem) onOrderTap;
  final void Function(OrderListItem, OrderStatus) onOrderDrop;

  const _KanbanBoard({
    required this.columns,
    required this.visibleStatuses,
    required this.onOrderTap,
    required this.onOrderDrop,
  });

  @override
  State<_KanbanBoard> createState() => _KanbanBoardState();
}

class _KanbanBoardState extends State<_KanbanBoard> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: widget.visibleStatuses.map((status) {
            List<OrderListItem> columnOrders = widget.columns[status] ?? [];
            
            // Only show completed orders from today
            if (status == OrderStatus.COMPLETED) {
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              columnOrders = columnOrders.where((o) {
                final dateToCheck = o.endDate ?? o.createdAt;
                return dateToCheck.isAfter(today) || dateToCheck.isAtSameMomentAs(today);
              }).toList();
            }

            return KanbanColumn(
              status: status,
              orders: columnOrders,
              onOrderTap: widget.onOrderTap,
              onOrderDrop: widget.onOrderDrop,
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ColumnFilters extends StatelessWidget {
  final List<OrderStatus> visibleStatuses;
  final void Function(OrderStatus) onToggle;

  const _ColumnFilters({required this.visibleStatuses, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      color: AppTheme.surface,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: OrderStatus.values.map((status) {
          final visible = visibleStatuses.contains(status);
          return GestureDetector(
            onTap: () => onToggle(status),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: visible ? status.color.withOpacity(0.15) : AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: visible ? status.color.withOpacity(0.5) : AppTheme.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 12,
                    color: visible ? status.color : AppTheme.onSurfaceMuted,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    status.displayName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: visible ? status.color : AppTheme.onSurfaceMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
