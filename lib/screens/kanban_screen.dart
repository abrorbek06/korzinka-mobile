import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:korzinkab_mobile/screens/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
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
  bool _assignedOnly = false;

  @override
  void initState() {
    super.initState();
    _loadHiddenStatuses();
  }

  Future<void> _loadHiddenStatuses() async {
    final prefs = await SharedPreferences.getInstance();
    final hiddenStatusesJson = prefs.getString(AppConfig.hiddenStatusesKey);
    if (hiddenStatusesJson != null) {
      final List<String> statusStrings =
          (jsonDecode(hiddenStatusesJson) as List).cast<String>();
      setState(() {
        _hiddenStatuses.clear();
        for (final statusStr in statusStrings) {
          final status = OrderStatus.values
              .where((s) => s.name == statusStr)
              .firstOrNull;
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
    await prefs.setString(
      AppConfig.hiddenStatusesKey,
      jsonEncode(statusStrings),
    );
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

  List<OrderListItem> _applyAssignedFilter(
    List<OrderListItem> items,
    AuthenticatedUser user,
  ) {
    if (!_assignedOnly) return items;
    if (user.role == UserRole.PICKER) {
      return items.where((item) => item.pickerId == user.id).toList();
    }
    return items.where((item) => item.salesManagerId == user.id).toList();
  }

  Future<void> _onOrderDrop(
    OrderListItem orderListItem,
    OrderStatus targetStatus,
  ) async {
    final auth = context.read<AuthProvider>();
    final user = auth.user!;

    // Check if the user has permission to transition to the target status
    final allowedTransitions = availableTransitions(
      orderListItem.status,
      user.role.name,
    );
    final hasPermission = allowedTransitions.any((t) => t.to == targetStatus);

    // Also allow any picker user to perform transitions that explicitly
    // list PICKER in the transition roles, even when they are not the
    // currently assigned picker. This enables branch pickers to claim
    // and act on orders without being pre-assigned.
    bool pickerRoleAllowed = false;
    if (!hasPermission && user.role == UserRole.PICKER) {
      pickerRoleAllowed = kTransitionRules.any((t) =>
          t.from == orderListItem.status && t.to == targetStatus && t.roles.contains('PICKER'));
    }

    // Allow an assigned picker to perform the picker-scoped transitions
    // even if the static role map doesn't include PICKER. This covers the
    // common case where the picker assigned to the order is the actor.
    bool pickerOverride = false;
    if (!hasPermission && user.role == UserRole.PICKER) {
      // The picker may act on their assigned order for these transitions:
      // IN_COLLECTION -> READY, IN_COLLECTION -> PARTIAL, PARTIAL -> READY
      final from = orderListItem.status;
      if (orderListItem.pickerId == user.id) {
        if (from == OrderStatus.IN_COLLECTION &&
            (targetStatus == OrderStatus.READY ||
                targetStatus == OrderStatus.PARTIAL)) {
          pickerOverride = true;
        }
        if (from == OrderStatus.PARTIAL && targetStatus == OrderStatus.READY) {
          pickerOverride = true;
        }
      }
    }

    if (!hasPermission && !pickerOverride && !pickerRoleAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You do not have permission to move to ${targetStatus.displayName}',
          ),
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
          SnackBar(
            content: Text('Failed to load order: ${ordersProvider.error}'),
          ),
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

    final filteredColumns = {
      for (final status in _visibleStatuses)
        status: _applyAssignedFilter(orders.columns[status] ?? [], user),
    };
    final visibleOrderCount = filteredColumns.values.fold<int>(
      0,
      (sum, list) => sum + list.length,
    );
    // Compute assigned count independent of the current `_assignedOnly` toggle
    final allOrdersFlat = orders.columns.values.expand((e) => e).toList();
    final assignedCount = user.role == UserRole.PICKER
        ? allOrdersFlat.where((item) => item.pickerId == user.id).length
        : allOrdersFlat.where((item) => item.salesManagerId == user.id).length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leadingWidth: 0,
        title: const Text('Kanban'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Qidiruv funktsiyasi hozircha mavjud emas.'),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bildirishnomalar sahifasi tayyor emas.'),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthProvider>().logout();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _TabPill(
                        label: "Barchasi",
                        count: orders.totalOrdersCount(),
                        selected: !_assignedOnly,
                        onTap: () => setState(() => _assignedOnly = false),
                      ),
                      const SizedBox(width: 8),
                      // Mine filter chip
                      _TabPill(
                        label: "Menga biriktirilgan",
                        count: assignedCount,
                        selected: _assignedOnly,
                        onTap: () => setState(() => _assignedOnly = true),
                      ),
                      const Spacer(),
                      // Filter icon
                      GestureDetector(
                        onTap: () =>
                            setState(() => _showFilters = !_showFilters),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _showFilters
                                ? AppColors.primary.withOpacity(0.4)
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Icon(
                            Icons.tune_rounded,
                            size: 18,
                            color: _showFilters
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (_showFilters)
            _ColumnFilters(
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
          if (orders.error != null)
            MaterialBanner(
              content: Text(orders.error!),
              backgroundColor: const Color(0xFFFEF3C7),
              actions: [
                TextButton(
                  onPressed: orders.clearError,
                  child: const Text('Yopish'),
                ),
              ],
            ),
          Expanded(
            child: orders.loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: orders.refreshAll,
                    color: AppTheme.primary,
                    backgroundColor: AppTheme.surface,
                    child: visibleOrderCount == 0
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            children: [
                              const SizedBox(height: 92),
                              Container(
                                width: 94,
                                height: 94,
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                child: const Icon(
                                  Icons.inbox_outlined,
                                  size: 42,
                                  color: Color(0xFF8B95A1),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Buyurtmalar yuklanmadi',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextButton.icon(
                                onPressed: orders.refreshAll,
                                icon: const Icon(
                                  Icons.refresh,
                                  color: Color(0xFF6D5BFF),
                                ),
                                label: const Text(
                                  'Yangilash',
                                  style: TextStyle(
                                    color: Color(0xFF6D5BFF),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : _KanbanBoard(
                            columns: filteredColumns,
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
                return dateToCheck.isAfter(today) ||
                    dateToCheck.isAtSameMomentAs(today);
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
                color: visible
                    ? status.color.withOpacity(0.15)
                    : AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: visible
                      ? status.color.withOpacity(0.5)
                      : AppTheme.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    visible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
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

class _TabPill extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _TabPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppColors.primary.withOpacity(0.4)
                : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.primary : AppColors.textSecondary,
                fontFamily: 'Nunito',
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : AppColors.textMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontFamily: 'Nunito',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
