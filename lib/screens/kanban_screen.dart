import 'dart:convert';
import 'package:flutter/material.dart';
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
import '../utils/snackbar_utils.dart';
import 'order_detail_screen.dart';

class KanbanScreen extends StatefulWidget {
  const KanbanScreen({super.key});

  @override
  State<KanbanScreen> createState() => _KanbanScreenState();
}

class _KanbanScreenState extends State<KanbanScreen> {
  // Which columns to show (terminal columns hidden by default for cleaner view)
  final Set<OrderStatus> _hiddenStatuses = {OrderStatus.CANCELLED};
  bool _assignedOnly = false;
  bool _statusChangeViaDropdown = true;
  OrderStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _selectedStatus = _columnOrder.firstWhere(
      (s) => !_hiddenStatuses.contains(s),
      orElse: () => OrderStatus.DRAFT,
    );
    _loadHiddenStatuses();
    _loadStatusChangePreference();
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
        if (_statusChangeViaDropdown &&
            !_visibleStatuses.contains(_selectedStatus)) {
          _selectedStatus = _visibleStatuses.isNotEmpty
              ? _visibleStatuses.first
              : OrderStatus.DRAFT;
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

  Future<void> _loadStatusChangePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final useDropdown = prefs.getBool(AppConfig.statusChangeMethodKey);
    if (useDropdown != null) {
      setState(() {
        _statusChangeViaDropdown = useDropdown;
        if (_statusChangeViaDropdown &&
            !_visibleStatuses.contains(_selectedStatus)) {
          _selectedStatus = _visibleStatuses.isNotEmpty
              ? _visibleStatuses.first
              : OrderStatus.DRAFT;
        }
      });
    }
  }

  OrderStatus get _currentSelectedStatus {
    final visible = _visibleStatuses;
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

  Future<void> _saveStatusChangePreference(bool useDropdown) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConfig.statusChangeMethodKey, useDropdown);
  }

  Future<void> _selectStatusChangeMethod(BuildContext context) async {
    var localSelection = _statusChangeViaDropdown;

    await showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Status o\'zgartirish usuli',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  RadioListTile<bool>(
                    title: const Text('Dropdown orqali'),
                    value: true,
                    groupValue: localSelection,
                    onChanged: (value) {
                      if (value != null) {
                        setModalState(() {
                          localSelection = value;
                        });
                      }
                    },
                  ),
                  RadioListTile<bool>(
                    title: const Text('Swipe/drag orqali'),
                    value: false,
                    groupValue: localSelection,
                    onChanged: (value) {
                      if (value != null) {
                        setModalState(() {
                          localSelection = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      setState(() {
                        _statusChangeViaDropdown = localSelection;
                      });
                      await _saveStatusChangePreference(localSelection);
                    },
                    child: const Text('Saqlash'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static const List<OrderStatus> _columnOrder = [
    OrderStatus.DRAFT,
    OrderStatus.CONFIRMED,
    OrderStatus.IN_COLLECTION,
    OrderStatus.PARTIAL,
    OrderStatus.READY,
    OrderStatus.COMPLETED,
    OrderStatus.CANCELLED,
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
        Text(
          'You do not have permission to move to ${targetStatus.displayName}',
        ),
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
    final user = auth.user!;

    final boardStatuses = _statusChangeViaDropdown
        ? [_currentSelectedStatus]
        : _visibleStatuses;
    final filteredColumns = {
      for (final status in boardStatuses)
        status: _applyAssignedFilter(orders.columns[status] ?? [], user),
    };
    final statusCounts = {
      for (final status in _visibleStatuses)
        status: _applyAssignedFilter(orders.columns[status] ?? [], user).length,
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
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        leadingWidth: 0,
        title: IconButton(
          icon: const Icon(Icons.account_circle_outlined),
          onPressed: () {
            // User profile and logout + quick tabs
            showModalBottomSheet(
              context: context,
              builder: (_) => StatefulBuilder(
                builder: (context, setModalState) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: AppTheme.primary,
                                  child: Text(
                                    user.username.substring(0, 1).toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.username,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      user.role.displayName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.onSurfaceMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            ElevatedButton(
                              style: ButtonStyle(
                                backgroundColor: WidgetStateProperty.all(
                                  Colors.transparent,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.logout,
                                    color: Colors.redAccent,
                                  ),
                                  // const SizedBox(width: 8),
                                  // Text(
                                  //   'Chiqish',
                                  //   style: TextStyle(
                                  //     fontSize: 14,
                                  //     fontWeight: FontWeight.w700,
                                  //     color: Colors.redAccent,
                                  //   ),
                                  // ),
                                ],
                              ),
                              onPressed: () {
                                context.read<AuthProvider>().logout();
                                Navigator.pushReplacementNamed(
                                  context,
                                  '/login',
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Row(
                        //   children: [
                        //     _TabPill(
                        //       label: "Menga biriktirilgan",
                        //       count: assignedCount,
                        //       selected: _assignedOnly,
                        //       onTap: () {
                        //         setModalState(() {});
                        //         setState(() => _assignedOnly = true);
                        //       },
                        //     ),
                        //     const SizedBox(width: 8),
                        //     _TabPill(
                        //       label: "Barchasi",
                        //       count: orders.totalOrdersCount(),
                        //       selected: !_assignedOnly,
                        //       onTap: () {
                        //         setModalState(() {});
                        //         setState(() => _assignedOnly = false);
                        //       },
                        //     ),
                        //   ],
                        // ),
                        // const SizedBox(height: 16),
                        // Align(
                        //   alignment: Alignment.centerLeft,
                        //   child: Text(
                        //     'Ko‘rinadigan statuslar',
                        //     style: TextStyle(
                        //       fontSize: 14,
                        //       fontWeight: FontWeight.w700,
                        //       color: AppTheme.onSurface,
                        //     ),
                        //   ),
                        // ),
                        // const SizedBox(height: 6),
                        // _ColumnFilters(
                        //   visibleStatuses: _visibleStatuses,
                        //   onToggle: (status) {
                        //     setModalState(() {});
                        //     setState(() {
                        //       if (_hiddenStatuses.contains(status)) {
                        //         _hiddenStatuses.remove(status);
                        //       } else {
                        //         _hiddenStatuses.add(status);
                        //       }
                        //       if (_statusChangeViaDropdown &&
                        //           !_visibleStatuses.contains(_selectedStatus)) {
                        //         _selectedStatus = _visibleStatuses.isNotEmpty
                        //             ? _visibleStatuses.first
                        //             : null;
                        //       }
                        //     });
                        //     _saveHiddenStatuses();
                        //   },
                        // ),
                        // const SizedBox(height: 12),
                        // Align(
                        //   alignment: Alignment.centerLeft,
                        //   child: Text(
                        //     'Status o\'zgartirish usuli',
                        //     style: TextStyle(
                        //       fontSize: 14,
                        //       fontWeight: FontWeight.w700,
                        //       color: AppTheme.onSurface,
                        //     ),
                        //   ),
                        // ),
                        // const SizedBox(height: 6),
                        // Row(
                        //   children: [
                        //     _TabPill(
                        //       label: "Dropdown",
                        //       selected: _statusChangeViaDropdown,
                        //       onTap: () async {
                        //         setModalState(() {});
                        //         setState(() {
                        //           _statusChangeViaDropdown = true;
                        //         });
                        //         await _saveStatusChangePreference(true);
                        //       },
                        //     ),
                        //     const SizedBox(width: 8),
                        //     _TabPill(
                        //       label: "Swipe",
                        //       selected: !_statusChangeViaDropdown,
                        //       onTap: () async {
                        //         setModalState(() {});
                        //         setState(() {
                        //           _statusChangeViaDropdown = false;
                        //         });
                        //         await _saveStatusChangePreference(false);
                        //       },
                        //     ),
                        //   ],
                        // ),
                        // const SizedBox(height: 8),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_outlined),
            onPressed: () {
              context.showTopSnackBar(
                const Text('Qidiruv funktsiyasi hozircha mavjud emas.'),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (_) => StatefulBuilder(
                  builder: (context, setModalState) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              _TabPill(
                                label: "Menga biriktirilgan",
                                count: assignedCount,
                                selected: _assignedOnly,
                                onTap: () {
                                  setModalState(() {});
                                  setState(() => _assignedOnly = true);
                                },
                              ),
                              const SizedBox(width: 8),
                              _TabPill(
                                label: "Barchasi",
                                count: orders.totalOrdersCount(),
                                selected: !_assignedOnly,
                                onTap: () {
                                  setModalState(() {});
                                  setState(() => _assignedOnly = false);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Ko‘rinadigan statuslar',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          _ColumnFilters(
                            visibleStatuses: _visibleStatuses,
                            onToggle: (status) {
                              setModalState(() {});
                              setState(() {
                                if (_hiddenStatuses.contains(status)) {
                                  _hiddenStatuses.remove(status);
                                } else {
                                  _hiddenStatuses.add(status);
                                }
                                if (_statusChangeViaDropdown &&
                                    !_visibleStatuses.contains(
                                      _selectedStatus,
                                    )) {
                                  _selectedStatus = _visibleStatuses.isNotEmpty
                                      ? _visibleStatuses.first
                                      : null;
                                }
                              });
                              _saveHiddenStatuses();
                            },
                          ),
                          const SizedBox(height: 24),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Status o\'zgartirish usuli',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _TabPill(
                                label: "Dropdown",
                                selected: _statusChangeViaDropdown,
                                onTap: () async {
                                  setModalState(() {});
                                  setState(() {
                                    _statusChangeViaDropdown = true;
                                  });
                                  await _saveStatusChangePreference(true);
                                },
                              ),
                              const SizedBox(width: 8),
                              _TabPill(
                                label: "Swipe",
                                selected: !_statusChangeViaDropdown,
                                onTap: () async {
                                  setModalState(() {});
                                  setState(() {
                                    _statusChangeViaDropdown = false;
                                  });
                                  await _saveStatusChangePreference(false);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],

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
      ),
      body: Column(
        children: [
          if (_statusChangeViaDropdown && _visibleStatuses.isNotEmpty)
            _StatusTabRow(
              statuses: _visibleStatuses,
              selectedStatus: _currentSelectedStatus,
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
                            visibleStatuses: boardStatuses,
                            onOrderTap: (order) => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ChangeNotifierProvider.value(
                                  value: orders,
                                  child: OrderDetailScreen(orderId: order.id),
                                ),
                              ),
                            ),
                            onOrderDrop: _statusChangeViaDropdown
                                ? null
                                : _onOrderDrop,
                            onStatusSelected: _statusChangeViaDropdown
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
          final dateToCheck = o.endDate ?? o.createdAt;
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
        hideHeader: expandColumn,
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
                  label: status.displayName,
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
        // padding: const EdgeInsets.symmetric(vertical: 8),
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
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  const _TabPill({
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
          color: selected ? AppColors.primaryLight : AppColors.background,
          borderRadius: BorderRadius.circular(6),
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

class _StatusChangeMethodTile extends StatelessWidget {
  final IconData icon;
  final String title;
  // final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _StatusChangeMethodTile({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected ? AppTheme.primary.withAlpha(25) : AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? AppTheme.primary : AppTheme.border,
          width: selected ? 1.6 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Container(
                //   width: 36,
                //   height: 36,
                //   decoration: BoxDecoration(
                //     color: selected
                //         ? AppTheme.primary.withAlpha(40)
                //         : AppTheme.surfaceVariant,
                //     shape: BoxShape.circle,
                //   ),
                //   child: Icon(
                //     icon,
                //     size: 18,
                //     color: selected
                //         ? AppTheme.primary
                //         : AppTheme.onSurfaceMuted,
                //   ),
                // ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? AppTheme.primary
                              : AppTheme.onSurface,
                        ),
                      ),
                      // if (subtitle != null) ...[
                      //   const SizedBox(height: 4),
                      //   Text(
                      //     subtitle!,
                      //     style: TextStyle(
                      //       fontSize: 13,
                      //       color: AppTheme.onSurfaceMuted,
                      //     ),
                      //   ),
                      // ],
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle, size: 20, color: AppTheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
