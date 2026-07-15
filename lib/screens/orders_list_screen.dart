import 'dart:async';
import 'package:flutter/material.dart';
import 'package:korzinkab_mobile/widgets/orders_order_card.dart';
import 'package:provider/provider.dart';
import 'package:korzinkab_mobile/l10n/app_localizations.dart';
import '../utils/l10n_extensions.dart';
import '../models/order_model.dart';
import '../providers/auth_provider.dart';
import '../providers/orders_provider.dart';
import '../services/orders_service.dart';
import '../theme/app_theme.dart';
import '../utils/snackbar_utils.dart';
import 'order_detail_screen.dart';

class OrdersListScreen extends StatefulWidget {
  final void Function(OrderListItem, OrderStatus)? onStatusSelected;
  final void Function(OrderListItem, OrderStatus)? onOrderDrop;

  const OrdersListScreen({super.key, this.onStatusSelected, this.onOrderDrop});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  late OrdersService _ordersService;
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  List<OrderListItem> _orders = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;
  static const int _limit = 20;

  // Filters
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<OrderStatus> _selectedStatuses = [];
  PaymentStatus? _selectedPaymentStatus;
  PaymentType? _selectedPaymentType;

  @override
  void initState() {
    super.initState();
    final token = context.read<AuthProvider>().token!;
    _ordersService = OrdersService(token: token);
    _scrollController.addListener(_onScroll);
    _fetchOrders(refresh: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _fetchOrders(refresh: false);
    }
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchQuery != value) {
        setState(() {
          _searchQuery = value;
        });
        _fetchOrders(refresh: true);
      }
    });
  }

  Future<void> _fetchOrders({required bool refresh}) async {
    if (_loading) return;
    if (refresh) {
      setState(() {
        _page = 1;
        _hasMore = true;
        _loading = true;
        _orders.clear();
      });
    } else {
      if (!_hasMore) return;
      setState(() => _loading = true);
    }

    try {
      final result = await _ordersService.getOrders(
        page: _page,
        limit: _limit,
        search: _searchQuery,
        statuses: _selectedStatuses.isNotEmpty ? _selectedStatuses : null,
        paymentStatus: _selectedPaymentStatus,
        paymentType: _selectedPaymentType,
      );

      setState(() {
        if (refresh) {
          _orders = result.items;
        } else {
          _orders.addAll(result.items);
        }
        _hasMore = result.items.length >= _limit;
        if (_hasMore) _page++;
      });
    } catch (e) {
      if (mounted) {
        context.showTopSnackBar(Text('Failed to load orders: $e'));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showFilterModal() {
    // Use local copies so modal changes are staged and applied only on Save
    final localSelectedStatuses = List<OrderStatus>.from(_selectedStatuses);
    PaymentStatus? localSelectedPaymentStatus = _selectedPaymentStatus;
    PaymentType? localSelectedPaymentType = _selectedPaymentType;

    final maxSheetHeight = MediaQuery.of(context).size.height * 0.92;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxSheetHeight),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.filters,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                localSelectedStatuses.clear();
                                localSelectedPaymentStatus = null;
                                localSelectedPaymentType = null;
                              });
                            },
                            child: Text(
                              AppLocalizations.of(context)!.clear,
                              style: const TextStyle(color: AppTheme.primary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)!.orderStatus,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: OrderStatus.values.map((s) {
                          final selected = localSelectedStatuses.contains(s);
                          return ChoiceChip(
                            label: Text(s.localizedName(context)),
                            selected: selected,
                            backgroundColor: s.color.withOpacity(0.3),
                            selectedColor: s.color,
                            labelStyle: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : AppTheme.onSurface,
                            ),
                            onSelected: (val) {
                              setModalState(() {
                                if (val) {
                                  localSelectedStatuses.add(s);
                                } else {
                                  localSelectedStatuses.remove(s);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)!.paymentStatus,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: PaymentStatus.values.map((s) {
                          final selected = localSelectedPaymentStatus == s;
                          return ChoiceChip(
                            label: Text(s.localizedName(context)),
                            selected: selected,
                            backgroundColor: s.color.withOpacity(0.3),
                            selectedColor: s.color,
                            labelStyle: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : AppTheme.onSurface,
                            ),
                            onSelected: (val) {
                              setModalState(() {
                                localSelectedPaymentStatus = val ? s : null;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)!.paymentType,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: PaymentType.values.map((t) {
                          final selected = localSelectedPaymentType == t;
                          return ChoiceChip(
                            label: Text(t.localizedName(context)),
                            selected: selected,
                            backgroundColor: const Color.fromARGB(
                              255,
                              173,
                              170,
                              194,
                            ).withOpacity(0.3),
                            selectedColor: AppTheme.primary,
                            labelStyle: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : AppTheme.onSurface,
                            ),
                            onSelected: (val) {
                              setModalState(() {
                                localSelectedPaymentType = val ? t : null;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            // Commit staged selections to parent state
                            setState(() {
                              _selectedStatuses = List<OrderStatus>.from(
                                localSelectedStatuses,
                              );
                              _selectedPaymentStatus =
                                  localSelectedPaymentStatus;
                              _selectedPaymentType = localSelectedPaymentType;
                            });
                            Navigator.pop(context);
                            _fetchOrders(refresh: true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.applyFilter,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ordersProvider = context.watch<OrdersProvider>();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        elevation: 0,
        title: Text(AppLocalizations.of(context)!.orders),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.searchHint,
                      hintStyle: const TextStyle(
                        color: AppTheme.onSurfaceMuted,
                        fontSize: 14,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.primary),
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppTheme.onSurfaceMuted,
                        size: 20,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.filter_list, size: 20),
                    onPressed: _showFilterModal,
                    color:
                        (_selectedStatuses.isNotEmpty ||
                            _selectedPaymentStatus != null ||
                            _selectedPaymentType != null)
                        ? AppTheme.primary
                        : AppTheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchOrders(refresh: true),
        color: AppTheme.primary,
        backgroundColor: AppTheme.surface,
        child: _orders.isEmpty
            ? (_loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        SizedBox(height: 120),
                        Center(
                          child: Text(
                            AppLocalizations.of(context)!.noOrdersFound,
                            style: const TextStyle(
                              color: AppTheme.onSurfaceMuted,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ))
            : ListView.separated(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                itemCount: _orders.length + (_hasMore ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == _orders.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final order = _orders[index];
                  return OrdersOrderCard(
                    order: order,
                    onStatusSelected: widget.onStatusSelected == null
                        ? null
                        : (targetStatus) =>
                              widget.onStatusSelected!(order, targetStatus),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChangeNotifierProvider.value(
                          value: ordersProvider,
                          child: OrderDetailScreen(orderId: order.id),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
