import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/order_model.dart';
import '../providers/auth_provider.dart';
import '../providers/orders_provider.dart';
import '../services/orders_service.dart';
import '../theme/app_theme.dart';
import '../widgets/order_card.dart';
import 'order_detail_screen.dart';

class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load orders: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Filtrlar',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              _selectedStatuses.clear();
                              _selectedPaymentStatus = null;
                              _selectedPaymentType = null;
                            });
                          },
                          child: const Text(
                            'Tozalash',
                            style: TextStyle(color: AppTheme.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Buyurtma holati',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: OrderStatus.values.map((s) {
                        final selected = _selectedStatuses.contains(s);
                        return ChoiceChip(
                          label: Text(s.displayName),
                          selected: selected,
                          selectedColor: s.color.withOpacity(0.3),
                          onSelected: (val) {
                            setModalState(() {
                              if (val)
                                _selectedStatuses.add(s);
                              else
                                _selectedStatuses.remove(s);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Toʻlov holati',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: PaymentStatus.values.map((s) {
                        final selected = _selectedPaymentStatus == s;
                        return ChoiceChip(
                          label: Text(s.displayName),
                          selected: selected,
                          selectedColor: s.color.withOpacity(0.3),
                          onSelected: (val) {
                            setModalState(() {
                              _selectedPaymentStatus = val ? s : null;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Toʻlov turi',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: PaymentType.values.map((t) {
                        final selected = _selectedPaymentType == t;
                        return ChoiceChip(
                          label: Text(t.displayName),
                          selected: selected,
                          selectedColor: AppTheme.primary.withOpacity(0.3),
                          onSelected: (val) {
                            setModalState(() {
                              _selectedPaymentType = val ? t : null;
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
                          Navigator.pop(context);
                          setState(() {});
                          _fetchOrders(refresh: true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Filtrni qo\'llash',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
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
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Buyurtmalar'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: const InputDecoration(
                        hintText: 'Kod yoki mijozni qidirish...',
                        hintStyle: TextStyle(
                          color: AppTheme.onSurfaceMuted,
                          fontSize: 14,
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
                      children: const [
                        SizedBox(height: 120),
                        Center(
                          child: Text(
                            'Hech qanday buyurtma topilmadi.',
                            style: TextStyle(
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
                padding: const EdgeInsets.all(16),
                itemCount: _orders.length + (_hasMore ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == _orders.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final order = _orders[index];
                  return OrderCard(
                    order: order,
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
