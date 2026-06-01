import 'package:flutter/foundation.dart';
import '../models/order_model.dart';
import '../models/audit_log_model.dart';
import '../services/orders_service.dart';
import '../services/socket_service.dart';

class OrdersProvider extends ChangeNotifier {
  late OrdersService _ordersService;
  final SocketService _socketService = SocketService();

  // Kanban data: status → orders
  final Map<OrderStatus, List<OrderListItem>> _columns = {
    for (final s in OrderStatus.values) s: [],
  };

  bool _loading = false;
  bool _refreshing = false;
  String? _error;
  OrderDetail? _selectedOrder;
  List<AuditLog> _auditLogs = [];
  bool _logsLoading = false;

  Map<OrderStatus, List<OrderListItem>> get columns => _columns;
  bool get loading => _loading;
  bool get refreshing => _refreshing;
  String? get error => _error;
  OrderDetail? get selectedOrder => _selectedOrder;
  List<AuditLog> get auditLogs => _auditLogs;
  bool get logsLoading => _logsLoading;

  int totalOrdersCount() => _columns.values.fold(0, (s, l) => s + l.length);

  void init(String token) {
    _ordersService = OrdersService(token: token);
    _socketService.connect(token);
    _socketService.addHandler(_onSocketMessage);
    loadAllColumns();
  }

  void _onSocketMessage(String type, Map<String, dynamic> payload) {
    if (type == 'orders.changed') {
      // Full refresh hint
      refreshAll();
    } else if (type == 'order.changed') {
      String? parseString(dynamic value) {
        if (value == null) return null;
        if (value is String) {
          final trimmed = value.trim();
          return trimmed.isEmpty ? null : trimmed;
        }
        if (value is num) return value.toString();
        if (value is List && value.isNotEmpty) {
          return value.first.toString();
        }
        return null;
      }

      final orderId = parseString(payload['id']);
      if (orderId != null) {
        _refreshSingleOrder(orderId);
      }
    }
  }

  Future<void> loadAllColumns() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _ordersService.getOrders(limit: 100);
      print(
        '[OrdersProvider] loaded ${result.items.length} items from service',
      );
      _distributeToColumns(result.items);
      _error = null;
    } catch (e) {
      print('[OrdersProvider] loadAllColumns error: $e');
      _error = e.toString();
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> refreshAll() async {
    if (_refreshing) return;
    _refreshing = true;
    notifyListeners();

    try {
      final result = await _ordersService.getOrders(limit: 100);
      _distributeToColumns(result.items);
    } catch (_) {}

    _refreshing = false;
    notifyListeners();
  }

  void _distributeToColumns(List<OrderListItem> items) {
    for (final status in OrderStatus.values) {
      _columns[status] = [];
    }
    print('[OrdersProvider] distributing ${items.length} items');
    for (final item in items) {
      _columns[item.status]?.add(item);
    }
    // Sort each column newest first
    for (final list in _columns.values) {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
  }

  Future<void> _refreshSingleOrder(String orderId) async {
    try {
      final updated = await _ordersService.getOrder(orderId);
      // Remove from old column
      for (final list in _columns.values) {
        list.removeWhere((o) => o.id == orderId);
      }
      // Add to new column
      _columns[updated.status]?.insert(0, updated);

      // Update selected order if open
      if (_selectedOrder?.id == orderId) {
        _selectedOrder = updated;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadOrderDetail(String orderId) async {
    _selectedOrder = null;
    _auditLogs = [];
    _error = null;
    notifyListeners();

    try {
      _selectedOrder = await _ordersService.getOrder(orderId);
      notifyListeners();
      await _loadAuditLogs(orderId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> _loadAuditLogs(String orderId) async {
    _logsLoading = true;
    notifyListeners();
    try {
      _auditLogs = await _ordersService.getOrderLogs(orderId);
    } catch (_) {}
    _logsLoading = false;
    notifyListeners();
  }

  Future<bool> performTransition({
    required String orderId,
    required OrderStatus nextStatus,
    String? pickerId,
    String? trolleyId,
    List<Map<String, dynamic>>? backorderedItems,
    List<String>? arrivedItemIds,
    String? notes,
  }) async {
    try {
      final updated = await _ordersService.transition(
        orderId: orderId,
        nextStatus: nextStatus,
        pickerId: pickerId,
        trolleyId: trolleyId,
        backorderedItems: backorderedItems,
        arrivedItemIds: arrivedItemIds,
        notes: notes,
      );

      // Update columns
      for (final list in _columns.values) {
        list.removeWhere((o) => o.id == orderId);
      }
      _columns[updated.status]?.insert(0, updated);
      _selectedOrder = updated;

      // Refresh logs
      await _loadAuditLogs(orderId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> markPaid(String orderId) async {
    try {
      final updated = await _ordersService.markPaid(orderId);
      _updateInColumns(updated);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> unmarkPaid(String orderId) async {
    try {
      final updated = await _ordersService.unmarkPaid(orderId);
      _updateInColumns(updated);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateDetails({
    required String orderId,
    String? trolleyId,
    bool clearTrolley = false,
    DateTime? endDate,
  }) async {
    try {
      final updated = await _ordersService.updateDetails(
        orderId: orderId,
        trolleyId: trolleyId,
        clearTrolley: clearTrolley,
        endDate: endDate,
      );
      _updateInColumns(updated);
      await _loadAuditLogs(orderId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> attachCart({
    required String orderId,
    required String cartId,
  }) async {
    try {
      final updated = await _ordersService.attachCart(
        orderId: orderId,
        cartId: cartId,
      );
      _updateInColumns(updated);
      await _loadAuditLogs(orderId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> detachCart({
    required String orderId,
    required String cartId,
  }) async {
    try {
      final updated = await _ordersService.detachCart(
        orderId: orderId,
        cartId: cartId,
      );
      _updateInColumns(updated);
      await _loadAuditLogs(orderId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchAvailableCarts({
    String? branchId,
  }) async {
    try {
      final raw = await _ordersService.getAvailableCarts(branchId: branchId);
      return raw;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  Future<bool> updateOrderItem({
    required String orderId,
    required String itemId,
    double? quantity,
    String? status,
    double? backorderedQuantity,
  }) async {
    try {
      final updated = await _ordersService.updateItem(
        orderId: orderId,
        itemId: itemId,
        quantity: quantity,
        status: status,
        backorderedQuantity: backorderedQuantity,
      );
      _updateInColumns(updated);
      await _loadAuditLogs(orderId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void _updateInColumns(OrderDetail updated) {
    for (final list in _columns.values) {
      list.removeWhere((o) => o.id == updated.id);
    }
    _columns[updated.status]?.insert(0, updated);
    if (_selectedOrder?.id == updated.id) {
      _selectedOrder = updated;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _socketService.disconnect();
    super.dispose();
  }
}
