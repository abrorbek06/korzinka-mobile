import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/constants.dart';
import '../models/order_model.dart';
import '../providers/picker_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/product_tile.dart';
import '../widgets/status_badge.dart';
import '../widgets/trolley_sheet.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PickerProvider>().loadDetail(widget.orderId);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PickerProvider>();
    final order = provider.detail;
    final trolley = order != null ? provider.getTrolley(order.id) : null;

    if (provider.detailLoading || order == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: AppColors.surface),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(order.code ?? '---'),
        actions: [
          StatusBadge(status: order.status),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, size: 22),
            onPressed: () {},
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: Column(
        children: [
          // Order meta info
          _OrderMeta(order: order, trolleyCode: trolley),

          // Tabs
          Container(
            color: AppColors.surface,
            child: TabBar(
              controller: _tabs,
              tabs: [
                Tab(text: '${AppStrings.products} (${order.products.length})'),
                const Tab(text: '${AppStrings.comments} (0)'),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _ProductsTab(order: order),
                const _CommentsTab(),
              ],
            ),
          ),
        ],
      ),

      // Bottom: status change button
      bottomNavigationBar: _BottomAction(order: order),
    );
  }
}

// ─── Order Meta Card ─────────────────────────────────────────────────────────

class _OrderMeta extends StatelessWidget {
  final OrderDetail order;
  final String? trolleyCode;

  const _OrderMeta({required this.order, this.trolleyCode});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd.MM.yyyy HH:mm');
    final provider = context.read<PickerProvider>();

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        children: [
          _MetaRow(
            label: AppStrings.customer,
            value: order.customerName ?? '—',
          ),
          const SizedBox(height: 10),
          _MetaRow(
            label: AppStrings.date,
            value: fmt.format(order.createdAt),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  AppStrings.trolley,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (trolleyCode != null)
                Text(
                  trolleyCode!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontFamily: 'Nunito',
                  ),
                )
              else
                const Text(
                  '—',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontFamily: 'Nunito',
                  ),
                ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => TrolleyPickerSheet.show(
                  context,
                  orderId: order.id,
                  currentTrolley: trolleyCode,
                ),
                child: Text(
                  AppStrings.change,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Nunito',
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;
  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontFamily: 'Nunito',
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Products Tab ─────────────────────────────────────────────────────────────

class _ProductsTab extends StatelessWidget {
  final OrderDetail order;
  const _ProductsTab({required this.order});

  @override
  Widget build(BuildContext context) {
    if (order.products.isEmpty) {
      return Center(
        child: Text(AppStrings.noProducts,
            style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Nunito')),
      );
    }
    return Container(
      color: AppColors.surface,
      child: ListView.builder(
        itemCount: order.products.length,
        itemBuilder: (_, i) => ProductItemTile(product: order.products[i]),
      ),
    );
  }
}

// ─── Comments Tab ─────────────────────────────────────────────────────────────

class _CommentsTab extends StatelessWidget {
  const _CommentsTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        AppStrings.noItems,
        style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Nunito'),
      ),
    );
  }
}

// ─── Bottom Action Button ─────────────────────────────────────────────────────

class _BottomAction extends StatefulWidget {
  final OrderDetail order;
  const _BottomAction({required this.order});

  @override
  State<_BottomAction> createState() => _BottomActionState();
}

class _BottomActionState extends State<_BottomAction> {
  bool _loading = false;

  bool get _canMarkReady =>
      widget.order.status == OrderStatus.IN_COLLECTION ||
      widget.order.status == OrderStatus.PARTIAL;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PickerProvider>();
    final collected = provider.totalCollected;
    final total = provider.totalRequired;

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [AppTheme.bottomBarShadow],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress indicator
          if (total > 0) ...[
            Row(
              children: [
                Text(
                  '$collected/$total mahsulot yig\'ildi',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${((collected / total) * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: total > 0 ? collected / total : 0,
                backgroundColor: AppColors.primaryLight,
                color: AppColors.primary,
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: (_loading || !_canMarkReady) ? null : _showStatusSheet,
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _canMarkReady
                              ? AppStrings.changeStatus
                              : widget.order.status.uzName,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        if (_canMarkReady) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showStatusSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _StatusChangeSheet(
        order: widget.order,
        onConfirm: _doTransition,
      ),
    );
  }

  Future<void> _doTransition(String? notes) async {
    Navigator.pop(context); // close sheet
    setState(() => _loading = true);
    final provider = context.read<PickerProvider>();
    final ok = await provider.markReady(notes: notes);
    setState(() => _loading = false);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Xatolik yuz berdi'),
          backgroundColor: AppColors.bekorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      provider.clearError();
    } else if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Buyurtma tayyor deb belgilandi!',
                style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w600)),
          ]),
          backgroundColor: AppColors.yangiColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
}

// ─── Status Change Confirmation Sheet ────────────────────────────────────────

class _StatusChangeSheet extends StatefulWidget {
  final OrderDetail order;
  final Future<void> Function(String? notes) onConfirm;

  const _StatusChangeSheet({required this.order, required this.onConfirm});

  @override
  State<_StatusChangeSheet> createState() => _StatusChangeSheetState();
}

class _StatusChangeSheetState extends State<_StatusChangeSheet> {
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PickerProvider>();
    final allDone = provider.allCollected;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Icon + title
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.tayyorColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.inventory_2_outlined,
                      size: 22, color: AppColors.tayyorColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppStrings.readyTitle,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        '${widget.order.code} → Tayyor',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Warning if not all collected
            if (!allDone)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF9C3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.qismanColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppColors.qismanColor, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Barcha mahsulotlar yig\'ilmagan. Baribir davom etasizmi?',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.qismanColor,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Nunito',
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (!allDone) const SizedBox(height: 14),

            // Notes field
            TextField(
              controller: _notesCtrl,
              decoration: InputDecoration(
                labelText: AppStrings.note,
                hintText: AppStrings.notePlaceholder,
                prefixIcon: const Icon(Icons.notes_outlined, size: 18),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(AppStrings.cancel,
                        style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => widget.onConfirm(
                        _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.tayyorColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(AppStrings.yes,
                        style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
