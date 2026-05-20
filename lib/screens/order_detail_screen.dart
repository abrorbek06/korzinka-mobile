import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/order_model.dart';
import '../providers/orders_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/audit_log_tile.dart';
import '../widgets/transition_sheet.dart';

class TrolleyOption {
  final String id;
  final String code;
  final String name;

  const TrolleyOption({
    required this.id,
    required this.code,
    required this.name,
  });
}

const List<TrolleyOption> _trolleys = [
  TrolleyOption(
    id: '11111111-1111-1111-1111-111111111111',
    code: 'TR-001',
    name: 'Arava 1',
  ),
  TrolleyOption(
    id: '22222222-2222-2222-2222-222222222222',
    code: 'TR-002',
    name: 'Arava 2',
  ),
  TrolleyOption(
    id: '33333333-3333-3333-3333-333333333333',
    code: 'TR-003',
    name: 'Arava 3',
  ),
];

class OrderDetailScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrdersProvider>().loadOrderDetail(widget.orderId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showTrolleyAssignment(BuildContext context, OrderDetail order) {
    showDialog(
      context: context,
      builder: (dialogCtx) => _TrolleyDialog(
        order: order,
        onAssign: (trolleyId) async {
          final success = await context.read<OrdersProvider>().updateDetails(
            orderId: order.id,
            trolleyId: trolleyId,
          );
          if (success) {
            if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Arava muvaffaqiyatli o'zgartirildi"),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } else {
            if (context.mounted) {
              final error = context.read<OrdersProvider>().error;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Xatolik yuz berdi: $error"),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ordersProvider = context.watch<OrdersProvider>();
    final authProvider = context.watch<AuthProvider>();
    final order = ordersProvider.selectedOrder;
    final user = authProvider.user!;

    if (ordersProvider.error != null && order == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error: ${ordersProvider.error}'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => context.read<OrdersProvider>().loadOrderDetail(
                  widget.orderId,
                ),
                child: const Text('Retry'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Orqaga'),
              ),
            ],
          ),
        ),
      );
    }

    if (order == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
          ),
        ),
      );
    }

    final trolleyText = order.trolleyId != null
        ? _trolleys
              .firstWhere(
                (t) => t.id == order.trolleyId,
                orElse: () => TrolleyOption(
                  id: order.trolleyId!,
                  code: order.trolleyId!,
                  name: order.trolleyId!,
                ),
              )
              .code
        : '—';

    final canUpdateTrolley =
        user.role == UserRole.ADMIN ||
        user.role == UserRole.STORE_MANAGER ||
        user.role == UserRole.SALES_MANAGER ||
        (user.role == UserRole.PICKER &&
            order.status == OrderStatus.IN_COLLECTION);

    final baseHas = availableTransitions(order.status, user.role.name).isNotEmpty;
    final pickerRoleAllowed = user.role == UserRole.PICKER && kTransitionRules.any(
      (t) => t.from == order.status && t.roles.contains('PICKER'),
    );
    final hasTransitionAccess = baseHas || pickerRoleAllowed;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black87),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 4),
                Text(
                  order.code ?? 'Order Detail',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                _StatusBadge(status: order.status),
                // IconButton(
                //   icon: const Icon(Icons.more_vert, color: Colors.black87),
                //   onPressed: () {},
                // ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: hasTransitionAccess
          ? Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 12,
                top: 12,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () =>
                    TransitionSheet.show(context, order: order, user: user),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Statusni o\'zgartirish',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.keyboard_arrow_up, size: 20),
                  ],
                ),
              ),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary block
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Column(
              children: [
                _SummaryRow(
                  'Mijoz',
                  order.customer?.name ?? '—',
                  isBoldValue: true,
                ),
                const SizedBox(height: 12),
                _SummaryRow(
                  'Sana',
                  DateFormat('dd.MM.yyyy HH:mm').format(order.createdAt),
                ),
                const SizedBox(height: 12),
                _SummaryRow(
                  'Arava',
                  trolleyText,
                  trailing: canUpdateTrolley
                      ? GestureDetector(
                          onTap: () => _showTrolleyAssignment(context, order),
                          child: const Text(
                            "O'zgartirish",
                            style: TextStyle(
                              color: Color(0xFF6366F1),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          // Custom TabBar
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF6366F1),
            unselectedLabelColor: const Color(0xFF9CA3AF),
            indicatorColor: const Color(0xFF6366F1),
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            tabs: [
              Tab(text: 'Mahsulotlar (${order.items.length})'),
              Tab(text: 'Audit (${ordersProvider.auditLogs.length})'),
            ],
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          // TabBarView
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ItemsTab(order: order, user: user),
                _AuditTab(orderId: widget.orderId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Trolley Assignment Dialog ───────────────────────────────────────────────────

class _TrolleyDialog extends StatelessWidget {
  final OrderDetail order;
  final ValueChanged<String?> onAssign;

  const _TrolleyDialog({required this.order, required this.onAssign});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Arava biriktirish",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Ushbu buyurtma uchun arava tanlang:",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 16),
            ..._trolleys.map(
              (t) => ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                title: Text(t.name),
                subtitle: Text(t.code),
                trailing: order.trolleyId == t.id
                    ? const Icon(Icons.check_circle, color: Color(0xFF6366F1))
                    : null,
                onTap: () => onAssign(t.id),
              ),
            ),
            if (order.trolleyId != null) ...[
              const Divider(),
              ListTile(
                title: const Text(
                  "Aravani olib tashlash",
                  style: TextStyle(color: Colors.red),
                ),
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                onTap: () => onAssign(null),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  "Bekor qilish",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Summary Row Helper ──────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBoldValue;
  final Widget? trailing;

  const _SummaryRow(
    this.label,
    this.value, {
    this.isBoldValue = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBoldValue ? FontWeight.w700 : FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}

// ─── Items Tab ───────────────────────────────────────────────────────────────────

class _ItemsTab extends StatefulWidget {
  final OrderDetail order;
  final AuthenticatedUser user;

  const _ItemsTab({required this.order, required this.user});

  @override
  State<_ItemsTab> createState() => _ItemsTabState();
}

class _ItemsTabState extends State<_ItemsTab> {
  final Map<String, bool> _updatingItems = {};

  Future<void> _updateQuantity(OrderItem item, int newCollected) async {
    final itemId = item.id;
    if (_updatingItems[itemId] == true) return;

    setState(() => _updatingItems[itemId] = true);
    try {
      final nextBackQty =
          widget.order.items.firstWhere((i) => i.id == itemId).quantity -
          newCollected;

      final nextStatus = nextBackQty == 0 ? 'available' : 'backordered';

      final success = await context.read<OrdersProvider>().updateOrderItem(
        orderId: widget.order.id,
        itemId: itemId,
        status: nextStatus,
        backorderedQuantity: nextStatus == 'backordered'
            ? nextBackQty.toDouble()
            : null,
      );

      if (!success && mounted) {
        final error = context.read<OrdersProvider>().error;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Xatolik: $error')));
      }
    } finally {
      if (mounted) {
        setState(() => _updatingItems[itemId] = false);
      }
    }
  }

  Color _getItemStatusColor(OrderItem item) {
    final collected = item.quantity - (item.backorderedQuantity ?? 0);
    if (collected == item.quantity) {
      return const Color(0xFF10B981); // Green
    } else if (collected > 0) {
      return const Color(0xFFF59E0B); // Orange
    } else {
      return const Color(0xFFEF4444); // Red
    }
  }

  Widget _getItemStatusBadge(OrderItem item) {
    final collected = item.quantity - (item.backorderedQuantity ?? 0);
    if (collected == item.quantity) {
      return Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          color: Color(0xFF10B981),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, color: Colors.white, size: 14),
      );
    } else if (collected > 0) {
      return Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          color: Color(0xFFF59E0B),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Text(
          "J",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    } else {
      return Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          color: Color(0xFFEF4444),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Text(
          "I",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }
  }

  Widget _getProductIcon(String productName) {
    final name = productName.toLowerCase();
    IconData iconData;
    Color color;
    Color bg;

    if (name.contains("suv") || name.contains("water")) {
      iconData = Icons.local_drink_outlined;
      color = const Color(0xFF3B82F6);
      bg = const Color(0xFFEFF6FF);
    } else if (name.contains("cola")) {
      iconData = Icons.local_drink;
      color = const Color(0xFFEF4444);
      bg = const Color(0xFFFFF5F5);
    } else if (name.contains("musa") || name.contains("пельмени")) {
      iconData = Icons.rice_bowl_outlined;
      color = const Color(0xFFD97706);
      bg = const Color(0xFFFEF3C7);
    } else if (name.contains("томаты") || name.contains("tomat")) {
      iconData = Icons.inventory_2_outlined;
      color = const Color(0xFFEC4899);
      bg = const Color(0xFFFDF2F8);
    } else if (name.contains("banana") || name.contains("banan")) {
      iconData = Icons.shopping_basket_outlined;
      color = const Color(0xFFEAB308);
      bg = const Color(0xFFFEFCE8);
    } else {
      iconData = Icons.shopping_bag_outlined;
      color = const Color(0xFF6B7280);
      bg = const Color(0xFFF3F4F6);
    }

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(iconData, color: color, size: 28),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.order.items.isEmpty) {
      return const Center(
        child: Text(
          'Mahsulotlar topilmadi',
          style: TextStyle(color: Color(0xFF9CA3AF)),
        ),
      );
    }

    // Checking edit permission
    final canEdit =
        widget.user.role == UserRole.ADMIN ||
        widget.user.role == UserRole.STORE_MANAGER ||
        widget.user.role == UserRole.SALES_MANAGER ||
        widget.user.role == UserRole.PICKER;

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: widget.order.items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = widget.order.items[index];
        final collected = item.quantity - (item.backorderedQuantity ?? 0);
        final isUpdating = _updatingItems[item.id] == true;

        return Container(
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
            border: Border.all(color: const Color(0xFFF3F4F6)),
          ),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: _getItemStatusColor(item), width: 4),
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.productName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (item.productSku != null) ...[
                        Text(
                          'SKU: ${item.productSku}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        'Kerak: ${item.quantity.toInt()} ${item.productName.toLowerCase().contains("banana") || item.productName.toLowerCase().contains("вес") ? "kg" : "dona"}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Quantity controller container
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap:
                                    (!canEdit || isUpdating || collected <= 0)
                                    ? null
                                    : () =>
                                          _updateQuantity(item, collected - 1),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  child: const Text(
                                    "—",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                              ),
                              if (isUpdating)
                                const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Padding(
                                    padding: EdgeInsets.all(6),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF6366F1),
                                    ),
                                  ),
                                )
                              else
                                Text(
                                  '$collected',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              GestureDetector(
                                onTap:
                                    (!canEdit ||
                                        isUpdating ||
                                        collected >= item.quantity)
                                    ? null
                                    : () =>
                                          _updateQuantity(item, collected + 1),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  child: const Text(
                                    "+",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _getItemStatusBadge(item),
                      ],
                    ),
                  //   if (collected == 0 && !isUpdating) ...[
                  //     const SizedBox(height: 4),
                  //     const Padding(
                  //       padding: EdgeInsets.only(right: 0.0),
                  //       child: Text(
                  //         "Yo'q",
                  //         style: TextStyle(
                  //           color: Color(0xFFEF4444),
                  //           fontWeight: FontWeight.w700,
                  //           fontSize: 11,
                  //         ),
                  //       ),
                  //     ),
                  //   ],
                  //   if (collected > 0 && collected < item.quantity && !isUpdating) ...[
                  //     const SizedBox(height: 4),
                  //     const Padding(
                  //       padding: EdgeInsets.only(right: 0.0),
                  //       child: Text(
                  //         "Qisman mavjud",
                  //         style: TextStyle(
                  //           color: Color(0xFFF59E0B),
                  //           fontWeight: FontWeight.w700,
                  //           fontSize: 11,
                  //         ),
                  //       ),
                  //     ),
                  // ],
                  ]
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Audit Tab ───────────────────────────────────────────────────────────────────

class _AuditTab extends StatelessWidget {
  final String orderId;

  const _AuditTab({required this.orderId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrdersProvider>();

    if (provider.logsLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
        ),
      );
    }

    if (provider.auditLogs.isEmpty) {
      return const Center(
        child: Text(
          'Harakatlar tarixi yo\'q',
          style: TextStyle(color: Color(0xFF9CA3AF)),
        ),
      );
    }

    final logs = provider.auditLogs;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        return AuditLogTile(
          log: logs[index],
          isFirst: index == 0,
          isLast: index == logs.length - 1,
        );
      },
    );
  }
}

// ─── Status Badge Widget ─────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final OrderStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (status) {
      case OrderStatus.IN_COLLECTION:
        bg = const Color(0xFFEEEAFE);
        fg = const Color(0xFF6366F1);
        break;
      case OrderStatus.CONFIRMED:
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0284C7);
        break;
      case OrderStatus.PARTIAL:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        break;
      case OrderStatus.READY:
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF059669);
        break;
      case OrderStatus.COMPLETED:
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF047857);
        break;
      case OrderStatus.CANCELLED:
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        break;
      case OrderStatus.DRAFT:
        bg = const Color(0xFFF3F4F6);
        fg = const Color(0xFF4B5563);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.displayNameUz,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
