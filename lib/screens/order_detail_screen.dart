import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:korzinkab_mobile/l10n/app_localizations.dart';
import '../utils/l10n_extensions.dart';
import '../models/user_model.dart';
import '../models/order_model.dart';
import '../providers/orders_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/audit_log_tile.dart';
import '../widgets/transition_sheet.dart';

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
        onAssign: (String trolleyId) async {
          final success = await context.read<OrdersProvider>().attachCart(
            orderId: order.id,
            cartId: trolleyId,
          );
          if (success) {
            if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
            if (context.mounted) {
              context.showTopSnackBar(
                const Text("Arava muvaffaqiyatli biriktirildi"),
                backgroundColor: Colors.green,
              );
            }
          } else {
            if (context.mounted) {
              final error = context.read<OrdersProvider>().error;
              context.showTopSnackBar(
                Text("Xatolik yuz berdi: $error"),
                backgroundColor: Colors.red,
              );
            }
          }
        },
        onRemove: (cartId) async {
          final success = await context.read<OrdersProvider>().detachCart(
            orderId: order.id,
            cartId: cartId,
          );
          if (success) {
            if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
            if (context.mounted) {
              context.showTopSnackBar(
                const Text("Arava olib tashlandi"),
                backgroundColor: Colors.green,
              );
            }
          } else {
            if (context.mounted) {
              final error = context.read<OrdersProvider>().error;
              context.showTopSnackBar(
                Text("Xatolik yuz berdi: $error"),
                backgroundColor: Colors.red,
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
              Text(
                'Internet Aloqasini tekshirib ko\'ring',
                // '${ordersProvider.error}'
              ),
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

    // trolleyText removed — summary now renders order.carts directly

    final canUpdateTrolley =
        user.role == UserRole.ADMIN ||
        user.role == UserRole.STORE_MANAGER ||
        (user.role == UserRole.PICKER &&
            order.status == OrderStatus.IN_COLLECTION &&
            order.pickerId == user.id);

    final baseHas = availableTransitions(
      order.status,
      user.role.name,
    ).isNotEmpty;
    final pickerRoleAllowed =
        user.role == UserRole.PICKER &&
        kTransitionRules.any(
          (t) => t.from == order.status && t.roles.contains('PICKER'),
        );
    final pickerAssignedTransitionAllowed =
        user.role == UserRole.PICKER &&
        order.pickerId == user.id &&
        (order.status == OrderStatus.IN_COLLECTION ||
            order.status == OrderStatus.PARTIAL);
    final hasTransitionAccess =
        baseHas || pickerRoleAllowed || pickerAssignedTransitionAllowed;

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
                _StatusBadge(status: order.status, order: order),
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
                const Text(
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
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary block
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Column(
                children: [
                  _SummaryRow(
                    AppLocalizations.of(context)!.customer,
                    order.customer?.name ?? '—',
                    isBoldValue: true,
                  ),
                  const SizedBox(height: 12),
                  _SummaryRow(
                    AppLocalizations.of(context)!.date,
                    DateFormat('dd.MM.yyyy HH:mm').format(order.createdAt),
                  ),
                  const SizedBox(height: 12),
                  // Attached carts list
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(
                          AppLocalizations.of(context)!.trolley,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (order.carts.isEmpty)
                              const Text('—')
                            else
                              ...order.carts.map(
                                (ct) => Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: 6,
                                    right: 12.0,
                                  ),
                                  child: Text(
                                    "${ct.name ?? ct.code},",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (canUpdateTrolley)
                        GestureDetector(
                          onTap: () => _showTrolleyAssignment(context, order),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Text(
                              AppLocalizations.of(context)!.change,
                              style: const TextStyle(
                                color: Color(0xFF6366F1),
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                    ],
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
                Tab(text: '${AppLocalizations.of(context)!.products} (${order.items.length})'),
                Tab(text: '${AppLocalizations.of(context)!.audit} (${ordersProvider.auditLogs.length})'),
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
      ),
    );
  }
}

// ─── Trolley Assignment Dialog (backend-backed) ───────────────────────────────

class _TrolleyDialog extends StatefulWidget {
  final OrderDetail order;
  final ValueChanged<String> onAssign;
  final ValueChanged<String> onRemove;

  const _TrolleyDialog({
    required this.order,
    required this.onAssign,
    required this.onRemove,
  });

  @override
  State<_TrolleyDialog> createState() => _TrolleyDialogState();
}

class _TrolleyDialogState extends State<_TrolleyDialog> {
  bool _loading = true;
  List<Map<String, dynamic>> _carts = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCarts();
  }

  Future<void> _loadCarts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final provider = context.read<OrdersProvider>();
      final list = await provider.fetchAvailableCarts(
        branchId: widget.order.branchId,
      );
      setState(() {
        _carts = list;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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
            Text(
              AppLocalizations.of(context)!.attachTrolley,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.selectTrolley,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text('Error: $_error'),
              )
            else if (_carts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(AppLocalizations.of(context)!.noTrolleysFound),
              )
            else
              ..._carts.map((c) {
                final id = c['id']?.toString() ?? c['cartId']?.toString() ?? '';
                final code =
                    c['code']?.toString() ?? c['cartNumber']?.toString() ?? id;
                final name = c['name']?.toString() ?? code;
                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  title: Text(name),
                  // subtitle: Text(code),
                  trailing:
                      (widget.order.carts.isNotEmpty &&
                          widget.order.carts.any((ct) => ct.id == id))
                      ? const Icon(Icons.check_circle, color: Color(0xFF6366F1))
                      : null,
                  onTap: () => widget.onAssign(id),
                );
              }),
            if (widget.order.carts.isNotEmpty) ...[
              const Divider(),
              ...widget.order.carts.map(
                (ct) => ListTile(
                  title: Text(ct.name ?? ct.code),
                  subtitle: Text(ct.code),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => widget.onRemove(ct.id),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  AppLocalizations.of(context)!.cancel,
                  style: const TextStyle(color: Colors.grey),
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
  // final Widget? trailing;

  const _SummaryRow(this.label, this.value, {this.isBoldValue = false});

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
        // if (trailing != null) ...[const Spacer(), trailing!],
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
  final Map<String, TextEditingController> _quantityControllers = {};
  final Map<String, FocusNode> _quantityFocusNodes = {};
  final Set<String> _quantityFocusListenersAttached = {};

  @override
  void dispose() {
    for (final controller in _quantityControllers.values) {
      controller.dispose();
    }
    for (final node in _quantityFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _updateQuantity(OrderItem item, int newCollected) async {
    final itemId = item.id;
    if (_updatingItems[itemId] == true) return;
    // Pickers are not allowed to change item quantities (only backorder fields).
    if (widget.user.role == UserRole.PICKER) {
      if (context.mounted) {
        context.showTopSnackBar(
          const Text('Pickers cannot change item quantities.'),
          backgroundColor: Colors.red,
        );
      }
      return;
    }

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
        context.showTopSnackBar(Text('Xatolik: $error'));
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
      return Center(
        child: Text(
          AppLocalizations.of(context)!.noOrdersFound,
          style: const TextStyle(color: Color(0xFF9CA3AF)),
        ),
      );
    }

    // Checking edit permission.
    // Pickers may only edit their own assigned order while it is in
    // IN_COLLECTION or PARTIAL, and they only update stock/backorder state.
    final canEdit = widget.user.role == UserRole.PICKER
        ? widget.order.pickerId == widget.user.id &&
              (widget.order.status == OrderStatus.IN_COLLECTION ||
                  widget.order.status == OrderStatus.PARTIAL)
        : widget.user.role == UserRole.ADMIN ||
              widget.user.role == UserRole.STORE_MANAGER ||
              widget.user.role == UserRole.SALES_MANAGER;

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: widget.order.items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = widget.order.items[index];
        final collected = item.quantity - (item.backorderedQuantity ?? 0);
        final isUpdating = _updatingItems[item.id] == true;
        final controller = _quantityControllers.putIfAbsent(
          item.id,
          () => TextEditingController(text: collected.toString()),
        );
        final focusNode = _quantityFocusNodes.putIfAbsent(
          item.id,
          () => FocusNode(),
        );
        // Commit on focus lost so tapping away saves the typed value.
        if (!_quantityFocusListenersAttached.contains(item.id)) {
          focusNode.addListener(() {
            if (!focusNode.hasFocus) {
              final parsed = int.tryParse(controller.text) ?? collected;
              final next = parsed.clamp(1, item.quantity.toInt());
              if (next != collected) {
                _updateQuantity(item, next);
              }
            }
          });
          _quantityFocusListenersAttached.add(item.id);
        }
        // Sync controller only when the field is not focused to avoid
        // clobbering user input while typing.
        if (!focusNode.hasFocus && controller.text != collected.toString()) {
          controller.text = collected.toString();
          controller.selection = TextSelection.fromPosition(
            TextPosition(offset: controller.text.length),
          );
        }

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
                        '${AppLocalizations.of(context)!.needed}: ${item.quantity.toInt()} ${item.productName.toLowerCase().contains("banana") || item.productName.toLowerCase().contains("вес") ? "kg" : AppLocalizations.of(context)!.units}',
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
                            crossAxisAlignment: CrossAxisAlignment.center,
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
                                SizedBox(
                                  width: 56,
                                  height: 34,
                                  child: TextField(
                                    enabled: canEdit,
                                    focusNode: focusNode,
                                    controller: controller,
                                    textAlign: TextAlign.center,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        vertical: 8,
                                        horizontal: 4,
                                      ),
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      focusColor: Colors.transparent,
                                      fillColor: Colors.transparent,
                                      border: InputBorder.none,
                                    ),
                                    onChanged: (value) {
                                      final parsed = int.tryParse(value) ?? 0;
                                      final next = parsed.clamp(
                                        0,
                                        item.quantity.toInt(),
                                      );
                                      if (next.toString() != value) {
                                        controller.text = next.toString();
                                        controller.selection =
                                            TextSelection.fromPosition(
                                              TextPosition(
                                                offset: controller.text.length,
                                              ),
                                            );
                                      }
                                      setState(() {});
                                    },
                                    onEditingComplete: () {
                                      if (!canEdit) return;
                                      final parsed =
                                          int.tryParse(controller.text) ??
                                          collected;
                                      final next = parsed.clamp(
                                        1,
                                        item.quantity.toInt(),
                                      );
                                      if (next != collected) {
                                        _updateQuantity(item, next);
                                      }
                                      FocusScope.of(context).unfocus();
                                    },
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
                  ],
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
      return Center(
        child: Text(
          AppLocalizations.of(context)!.noHistory,
          style: const TextStyle(color: Color(0xFF9CA3AF)),
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
  final OrderListItem order;
  final OrderStatus status;

  const _StatusBadge({required this.status, required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: order.status.lightColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.localizedName(context),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: order.status.color),
      ),
    );
  }
}
