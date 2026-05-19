import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import '../providers/orders_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
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
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrdersProvider>().loadOrderDetail(widget.orderId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersProvider = context.watch<OrdersProvider>();
    final authProvider = context.watch<AuthProvider>();
    final order = ordersProvider.selectedOrder;
    final user = authProvider.user!;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(order?.code ?? 'Order Detail'),
        actions: [
          if (order != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _StatusBadge(status: order.status),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Refresh',
            onPressed: () =>
                context.read<OrdersProvider>().loadOrderDetail(widget.orderId),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.onSurfaceMuted,
          indicatorColor: AppTheme.primary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'Items'),
            Tab(text: 'Details'),
            Tab(text: 'Audit'),
          ],
        ),
      ),
      floatingActionButton:
          (order != null &&
              (user.role.canManageTransitions ||
                  user.role == UserRole.ACCOUNTANT))
          ? FloatingActionButton.extended(
              onPressed: () =>
                  TransitionSheet.show(context, order: order, user: user),
              backgroundColor: AppTheme.primary,
              foregroundColor: AppTheme.background,
              icon: const Icon(Icons.arrow_forward),
              label: const Text(
                'Actions',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
      body: (ordersProvider.error != null && order == null)
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Error: ${ordersProvider.error}'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => context
                        .read<OrdersProvider>()
                        .loadOrderDetail(widget.orderId),
                    child: const Text('Retry'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back'),
                  ),
                ],
              ),
            )
          : order == null
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _ItemsTab(order: order),
                _DetailsTab(order: order, user: user),
                _AuditTab(orderId: widget.orderId),
              ],
            ),
    );
  }
}

// ─── Details Tab ─────────────────────────────────────────────────────────────

class _DetailsTab extends StatelessWidget {
  final OrderDetail order;
  final AuthenticatedUser user;
  const _DetailsTab({required this.order, required this.user});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy, HH:mm');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        _SectionCard(
          title: 'Order Info',
          icon: Icons.receipt_outlined,
          children: [
            _InfoRow('Code', order.code ?? '—'),
            _InfoRow('Status', order.status.displayName),
            _InfoRow('Payment', order.paymentStatus.displayName),
            _InfoRow('Payment Type', order.paymentType.displayName),
            _InfoRow('Created', fmt.format(order.createdAt)),
            if (order.endDate != null)
              _InfoRow('End Date', fmt.format(order.endDate!)),
            if (order.completedAt != null)
              _InfoRow('Completed', fmt.format(order.completedAt!)),
          ],
        ),
        const SizedBox(height: 12),
        if (order.customer != null)
          _SectionCard(
            title: 'Customer',
            icon: Icons.person_outline,
            children: [
              _InfoRow('Name', order.customer!.name),
              if (order.customer!.phone != null)
                _InfoRow('Phone', order.customer!.phone!),
              if (order.customer!.email != null)
                _InfoRow('Email', order.customer!.email!),
            ],
          ),
        if (order.customer != null) const SizedBox(height: 12),
        _SectionCard(
          title: 'Assignment',
          icon: Icons.assignment_ind_outlined,
          children: [
            _InfoRow('Branch', order.branchName ?? '—'),
            _InfoRow('Sales Manager', order.salesManagerName ?? '—'),
            _InfoRow('Picker', order.picker?.username ?? '—'),
            if (user.role == UserRole.PICKER &&
                order.status == OrderStatus.IN_COLLECTION)
              _TrolleyAssignment(order: order)
            else
              _InfoRow('Trolley', order.trolleyId ?? '—'),
          ],
        ),
        const SizedBox(height: 12),
        if (order.backorderedItemsCount > 0)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFF59E0B).withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.hourglass_bottom,
                  color: Color(0xFFF59E0B),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  '${order.backorderedItemsCount} backordered item(s)',
                  style: const TextStyle(
                    color: Color(0xFFF59E0B),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─── Items Tab ────────────────────────────────────────────────────────────────

class _ItemsTab extends StatelessWidget {
  final OrderDetail order;
  const _ItemsTab({required this.order});

  @override
  Widget build(BuildContext context) {
    if (order.items.isEmpty) {
      return const Center(
        child: Text(
          'No items found',
          style: TextStyle(color: AppTheme.onSurfaceMuted),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: order.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = order.items[index];
        return Container(
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: item.status.color, width: 3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.productName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.onSurface,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: item.status.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: item.status.color.withOpacity(0.4),
                        ),
                      ),
                      child: Text(
                        item.status.displayName,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: item.status.color,
                        ),
                      ),
                    ),
                  ],
                ),
                if (item.productSku != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    'SKU: ${item.productSku}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.onSurfaceMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    _ItemStat('Qty', '${item.quantity}'),
                    if (item.backorderedQuantity != null &&
                        item.backorderedQuantity! > 0)
                      _ItemStat(
                        'Backordered',
                        '${item.backorderedQuantity}',
                        warn: true,
                      ),
                    const Spacer(),
                    _ItemStat(
                      'Unit Price',
                      '\$${item.unitPrice.toStringAsFixed(2)}',
                    ),
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

class _ItemStat extends StatelessWidget {
  final String label;
  final String value;
  final bool warn;
  const _ItemStat(this.label, this.value, {this.warn = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.onSurfaceMuted,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: warn ? const Color(0xFFF59E0B) : AppTheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Audit Tab ────────────────────────────────────────────────────────────────

class _AuditTab extends StatelessWidget {
  final String orderId;
  const _AuditTab({required this.orderId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrdersProvider>();

    if (provider.logsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.auditLogs.isEmpty) {
      return const Center(
        child: Text(
          'No audit history',
          style: TextStyle(color: AppTheme.onSurfaceMuted),
        ),
      );
    }

    final logs = provider.auditLogs;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
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

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: AppTheme.onSurfaceMuted),
              const SizedBox(width: 7),
              Text(
                title.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          const Divider(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.onSurfaceMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrolleyAssignment extends StatefulWidget {
  final OrderDetail order;

  const _TrolleyAssignment({required this.order});

  @override
  State<_TrolleyAssignment> createState() => _TrolleyAssignmentState();
}

class _TrolleyAssignmentState extends State<_TrolleyAssignment> {
  final _trolleyController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _trolleyController.dispose();
    super.dispose();
  }

  Future<void> _assignTrolley() async {
    final trolleyId = _trolleyController.text.trim();
    if (trolleyId.isEmpty) return;

    setState(() => _saving = true);
    try {
      // We need to add a method to update trolley ID
      // For now, this is a placeholder - we'll need to add the API endpoint
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trolley assignment feature needs backend endpoint'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to assign trolley: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _trolleyController,
              decoration: InputDecoration(
                labelText: 'Trolley ID',
                hintText: widget.order.trolleyId ?? 'Enter trolley ID',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _saving ? null : _assignTrolley,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Assign'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final OrderStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: status.color.withOpacity(0.4)),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: status.color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
