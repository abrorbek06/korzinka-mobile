import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:korzinkab_mobile/l10n/app_localizations.dart';
import '../providers/settings_provider.dart';
import '../utils/l10n_extensions.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/orders_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/kanban_column.dart';
import '../widgets/transition_sheet.dart';
import '../utils/snackbar_utils.dart';
import 'order_detail_screen.dart';

class KanbanScreen extends StatefulWidget {
  const KanbanScreen({super.key});

  @override
  State<KanbanScreen> createState() => _KanbanScreenState();
}

class _KanbanScreenState extends State<KanbanScreen> {
  // Which columns to show (terminal columns hidden by default for cleaner view)
  bool _assignedOnly = false;
  OrderStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _selectedStatus = _columnOrder.firstWhere(
      (s) => s != OrderStatus.CANCELLED,
      orElse: () => OrderStatus.DRAFT,
    );
  }

  OrderStatus _currentSelectedStatus(SettingsProvider settings) {
    final visible = settings.visibleStatuses;
    if (visible.isEmpty) {
      return OrderStatus.DRAFT;
    }
    if (_selectedStatus == null || !visible.contains(_selectedStatus)) {
      return visible.first;
    }
    return _selectedStatus!;
  }

  void _setSelectedStatus(OrderStatus status) {
    setState(() {
      _selectedStatus = status;
    });
  }

  static const List<OrderStatus> _columnOrder = [
    OrderStatus.DRAFT,
    OrderStatus.CONFIRMED,
    OrderStatus.IN_COLLECTION,
    OrderStatus.PARTIAL,
    OrderStatus.READY,
    OrderStatus.OUT_FOR_DELIVERY,
    OrderStatus.COMPLETED,
    OrderStatus.CANCELLED,
  ];

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

  int _getVisibleStatusCount(
    OrderStatus status,
    List<OrderListItem> items,
    AuthenticatedUser user,
  ) {
    final filteredItems = _applyAssignedFilter(items, user);
    if (status != OrderStatus.COMPLETED) {
      return filteredItems.length;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return filteredItems.where((item) {
      final dateToCheck = item.completedAt ?? item.endDate ?? item.createdAt;
      return dateToCheck.isAfter(today) || dateToCheck.isAtSameMomentAs(today);
    }).length;
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
      pickerRoleAllowed = kTransitionRules.any(
        (t) =>
            t.from == orderListItem.status &&
            t.to == targetStatus &&
            t.roles.contains('PICKER'),
      );
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
      context.showTopSnackBar(
        Text('No permission to move to ${targetStatus.localizedName(context)}'),
        backgroundColor: Theme.of(context).colorScheme.error,
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
        context.showTopSnackBar(
          Text('Failed to load order: ${ordersProvider.error}'),
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
    final settings = context.watch<SettingsProvider>();
    final user = auth.user!;

    final boardStatuses = settings.statusChangeViaDropdown
        ? [_currentSelectedStatus(settings)]
        : settings.visibleStatuses;
    final filteredColumns = {
      for (final status in boardStatuses)
        status: _applyAssignedFilter(orders.columns[status] ?? [], user),
    };
    final statusCounts = {
      for (final status in settings.visibleStatuses)
        status: _getVisibleStatusCount(
          status,
          orders.columns[status] ?? [],
          user,
        ),
    };
    final visibleOrderCount = filteredColumns.values.fold<int>(
      0,
      (sum, list) => sum + list.length,
    );

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        leadingWidth: 0,
        elevation: 0,
        title: Text(
          AppLocalizations.of(context)!.kanban,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          // IconButton(
          //   icon: const Icon(CupertinoIcons.search),
          //   onPressed: () {
          //     context.showTopSnackBar(
          //       Text(AppLocalizations.of(context)!.searchNotAvailable),
          //     );
          //   },
          // ),
          // Assigned to me toggle
          IconButton(
            icon: Icon(
              _assignedOnly ? Icons.all_inbox : Icons.all_inbox_outlined,
              color: _assignedOnly ? AppTheme.primary : null,
            ),
            tooltip: AppLocalizations.of(context)!.assignedToMe,
            onPressed: () {
              setState(() => _assignedOnly = !_assignedOnly);
            },
          ),
        ],
      ),

      // bottom: PreferredSize(
      //   preferredSize: const Size.fromHeight(52),
      //   child: Container(
      //     color: AppColors.surface,
      //     padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      //     child: Row(
      //       children: [
      //         Expanded(
      //           child: Row(
      //             mainAxisSize: MainAxisSize.min,
      //             children: [

      //               const Spacer(),
      //               // Filter icon
      //               GestureDetector(
      //                 onTap: () =>
      //                     setState(() => _showFilters = !_showFilters),
      //                 child: Container(
      //                   width: 36,
      //                   height: 36,
      //                   decoration: BoxDecoration(
      //                     color: _showFilters
      //                         ? AppColors.primary.withOpacity(0.4)
      //                         : AppColors.background,
      //                     borderRadius: BorderRadius.circular(10),
      //                     border: Border.all(color: AppColors.border),
      //                   ),
      //                   child: Icon(
      //                     Icons.tune_rounded,
      //                     size: 18,
      //                     color: _showFilters
      //                         ? AppColors.primary
      //                         : AppColors.textSecondary,
      //                   ),
      //                 ),
      //               ),
      //             ],
      //           ),
      //         ),
      //       ],
      //     ),
      //   ),
      // ),
      // ),
      body: Column(
        children: [
          if (settings.statusChangeViaDropdown &&
              settings.visibleStatuses.isNotEmpty)
            _StatusTabRow(
              statuses: settings.visibleStatuses,
              selectedStatus: _currentSelectedStatus(settings),
              statusCounts: statusCounts,
              onStatusTap: _setSelectedStatus,
            ),
          // if (orders.error != null)
          //   MaterialBanner(
          //     content: Text(orders.error!),
          //     backgroundColor: const Color(0xFFFEF3C7),
          //     actions: [
          //       TextButton(
          //         onPressed: orders.clearError,
          //         child: const Text('Yopish'),
          //       ),
          //     ],
          //   ),
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
                                AppLocalizations.of(context)!.ordersNotLoaded,
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
                                label: Text(
                                  AppLocalizations.of(context)!.refresh,
                                  style: const TextStyle(
                                    color: Color(0xFF6D5BFF),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : _KanbanBoard(
                            columns: filteredColumns,
                            visibleStatuses: boardStatuses,
                            onOrderTap: (order) => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ChangeNotifierProvider.value(
                                  value: orders,
                                  child: OrderDetailScreen(orderId: order.id),
                                ),
                              ),
                            ),
                            onOrderDrop: settings.statusChangeViaDropdown
                                ? null
                                : _onOrderDrop,
                            onStatusSelected: settings.statusChangeViaDropdown
                                ? _onOrderDrop
                                : null,
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
  final void Function(OrderListItem, OrderStatus)? onStatusSelected;
  final void Function(OrderListItem, OrderStatus)? onOrderDrop;

  const _KanbanBoard({
    required this.columns,
    required this.visibleStatuses,
    required this.onOrderTap,
    this.onStatusSelected,
    this.onOrderDrop,
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
    final bool expandColumn = widget.visibleStatuses.length <= 1;
    final double fullColumnWidth =
        MediaQuery.of(context).size.width - 32; // padding on both sides

    final columnWidgets = widget.visibleStatuses.map((status) {
      List<OrderListItem> columnOrders = widget.columns[status] ?? [];

      // Only show completed orders from today
      if (status == OrderStatus.COMPLETED) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        columnOrders = columnOrders.where((o) {
          final dateToCheck = o.completedAt ?? o.endDate ?? o.createdAt;
          return dateToCheck.isAfter(today) ||
              dateToCheck.isAtSameMomentAs(today);
        }).toList();
      }

      return KanbanColumn(
        status: status,
        orders: columnOrders,
        onOrderTap: widget.onOrderTap,
        onStatusSelected: widget.onStatusSelected,
        onOrderDrop: widget.onOrderDrop,
        width: expandColumn ? fullColumnWidth : 240,
        hideHeader: expandColumn && widget.onStatusSelected != null,
        addRightMargin: !expandColumn,
      );
    }).toList();

    if (widget.visibleStatuses.length <= 1) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(width: fullColumnWidth, child: columnWidgets.first),
      );
    }

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: columnWidgets,
        ),
      ),
    );
  }
}

class _StatusTabRow extends StatelessWidget {
  final List<OrderStatus> statuses;
  final OrderStatus selectedStatus;
  final Map<OrderStatus, int> statusCounts;
  final void Function(OrderStatus) onStatusTap;

  const _StatusTabRow({
    required this.statuses,
    required this.selectedStatus,
    required this.statusCounts,
    required this.onStatusTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double minPillWidth = 150;
        final useExpanded =
            statuses.isNotEmpty &&
            (statuses.length * minPillWidth) <= constraints.maxWidth;

        if (useExpanded) {
          return Container(
            height: 54,
            color: AppTheme.surface,
            padding: const EdgeInsets.only(
              left: 12,
              right: 8,
              top: 10,
              bottom: 10,
            ),
            child: Row(
              children: statuses.map((status) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: _TabStatus(
                      label: status.displayName,
                      selected: status == selectedStatus,
                      count: statusCounts[status],
                      onTap: () => onStatusTap(status),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }

        return Container(
          height: 54,
          color: AppTheme.surface,
          padding: const EdgeInsets.only(
            left: 12,
            right: 8,
            top: 10,
            bottom: 10,
          ),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: statuses.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final status = statuses[index];
              return SizedBox(
                width: minPillWidth,
                child: _TabStatus(
                  label: status.localizedName(context),
                  selected: status == selectedStatus,
                  count: statusCounts[status],
                  onTap: () => onStatusTap(status),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _TabStatus extends StatelessWidget {
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  const _TabStatus({
    required this.label,
    this.count,
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
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppColors.primary.withOpacity(0.4)
                : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected
                    ? AppColors.primaryLight
                    : AppColors.textSecondary,
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
