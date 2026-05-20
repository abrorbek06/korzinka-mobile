import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/constants.dart';
import '../providers/picker_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/order_list_tile.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  bool _showMineOnly = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PickerProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text(AppStrings.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, size: 22),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, size: 22),
            onPressed: () {},
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                // All filter chip
                _FilterChip(
                  label: AppStrings.filterAll,
                  count: provider.orders.length,
                  selected: !_showMineOnly,
                  onTap: () => setState(() => _showMineOnly = false),
                ),
                const SizedBox(width: 8),
                // Mine filter chip
                _FilterChip(
                  label: AppStrings.filterMine,
                  count: null,
                  selected: _showMineOnly,
                  onTap: () => setState(() => _showMineOnly = true),
                ),
                const Spacer(),
                // Filter icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.tune_rounded,
                      size: 18, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
      body: provider.loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: provider.loadOrders,
              color: AppColors.primary,
              child: _buildList(provider),
            ),
    );
  }

  Widget _buildList(PickerProvider provider) {
    final statuses = provider.activeStatuses;
    final sections = <Widget>[];

    for (final status in statuses) {
      var list = provider.byStatus(status);
      if (list.isEmpty) continue;

      sections.add(StatusSectionHeader(status: status, count: list.length));
      for (final order in list) {
        final trolley = provider.getTrolley(order.id);
        sections.add(OrderListTile(
          order: order,
          trolleyCode: trolley,
          onTap: () => _openDetail(order.id),
        ));
      }
    }

    if (sections.isEmpty) {
      final message = provider.error ?? AppStrings.noOrders;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.inbox_outlined, size: 34, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                fontFamily: 'Nunito',
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: provider.loadOrders,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text(AppStrings.refresh),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: sections,
    );
  }

  void _openDetail(String orderId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<PickerProvider>(),
          child: OrderDetailScreen(orderId: orderId),
        ),
      ),
    );
  }
}

// ─── Filter chip ─────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
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
            color: selected ? AppColors.primary.withOpacity(0.4) : AppColors.border,
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
