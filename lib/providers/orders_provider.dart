import 'package:flutter/foundation.dart';
import '../models/order_model.dart';
import '../models/audit_log_model.dart';
import '../services/orders_service.dart';
import '../services/socket_service.dart';

class OrdersProvider extends ChangeNotifier {
  late OrdersService _ordersService;
  final SocketService _socketService = SocketService();

  String _toUserMessage(Object error) {
    if (error is ApiException) {
      final message = error.message.trim();
      final lower = message.toLowerCase();

      if (message.contains('Sessiya muddati tugadi')) {
        return 'Sessiyangiz tugadi. Iltimos, qayta kirib keting.';
      }
      if (lower.contains('timed out') || message.contains('504')) {
        return 'Serverga ulanish vaqti tugadi. Iltimos, birozdan keyin qayta urinib ko‘ring.';
      }
      if (lower.contains('not found') || lower.contains('topilmadi')) {
        return 'Ma’lumot topilmadi.';
      }
      if (lower.contains(
            'order items cannot be changed while the order is paid',
          ) ||
          lower.contains(
            'quantity cannot be changed while the order is paid',
          )) {
        return 'Buyurtma to‘langanligi sababli mahsulot sonini o‘zgartirib bo‘lmaydi. Avval to‘lovni bekor qiling.';
      }
      if (lower.contains(
            'cash/card orders cannot be created with paymentstatus=paid',
          ) ||
          lower.contains(
            'cash/card orders cannot be created with payment status=paid',
          )) {
        return 'Naqd yoki kartali buyurtma yaratishda oldindan to‘lov belgilanmaydi. Buyurtma tayyor holatga kelgach, to‘lovni belgilang.';
      }
      if (lower.contains('must be marked paid before ready') ||
          lower.contains('order must be marked paid')) {
        return 'Buyurtma yakunlanishidan oldin to‘lov tasdiqlanishi kerak.';
      }
      if (lower.contains('ready ->') &&
          lower.contains('blocked for paid cash/card orders')) {
        return 'Bu buyurtma allaqachon to‘langanligi sababli qaytib kelish ishlovi bekor qilindi. Avval to‘lovni bekor qiling.';
      }
      if (lower.contains('transition') && lower.contains('not allowed')) {
        return 'Bu holat o‘zgartirish mumkin emas. Iltimos, boshqa bosqichga o‘ting.';
      }
      if (lower.contains('picker') && lower.contains('required')) {
        return 'Tanlov uchun picker tanlang.';
      }
      if (lower.contains('backordered') || lower.contains('backorder')) {
        return 'Qoldiq mahsulotlarni oldin to‘g‘ri belgilang.';
      }
      if (lower.contains('must have at least one active contract')) {
        return 'Buyurtma uchun kamida bitta faol shartnoma bo‘lishi kerak.';
      }
      if (lower.contains('already exists') ||
          lower.contains('already active')) {
        return 'Bu ma’lumot allaqachon mavjud.';
      }
      if (lower.contains('forbidden') || lower.contains('ruxsat')) {
        return 'Ushbu amal uchun sizga ruxsat yo‘q.';
      }
      if (message.isNotEmpty) {
        return message;
      }
    }

    final message = error.toString();
    final lower = message.toLowerCase();
    if (lower.contains('socketexception') ||
        lower.contains('handshakeexception') ||
        lower.contains('clientexception')) {
      return 'Internet aloqasi mavjud emas. Iltimos, tarmoqni tekshirib qayta urinib ko‘ring.';
    }
    if (lower.contains('formatexception')) {
      return 'Ma’lumot formati noto‘g‘ri.';
    }
    if (lower.contains('timeoutexception')) {
      return 'So‘rov vaqti tugadi. Iltimos, qayta urinib ko‘ring.';
    }

    return 'Xatolik yuz berdi. Iltimos, qayta urinib ko‘ring.';
  }

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
      _error = _toUserMessage(e);
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
      _error = _toUserMessage(e);
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
    String? notes,
  }) async {
    try {
      final updated = await _ordersService.transition(
        orderId: orderId,
        nextStatus: nextStatus,
        pickerId: pickerId,
        trolleyId: trolleyId,
        backorderedItems: backorderedItems,
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
      _error = _toUserMessage(e);
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
      _error = _toUserMessage(e);
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
      _error = _toUserMessage(e);
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
      _error = _toUserMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> attachCart({
    required String orderId,
    required List<String> cartIds,
  }) async {
    try {
      final updated = await _ordersService.attachCart(
        orderId: orderId,
        cartIds: cartIds,
      );
      _updateInColumns(updated);
      await _loadAuditLogs(orderId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = _toUserMessage(e);
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
      _error = _toUserMessage(e);
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
      _error = _toUserMessage(e);
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
      // Don't call _updateInColumns to avoid triggering column refresh
      // Only update the specific item in selectedOrder to preserve order
      if (_selectedOrder?.id == updated.id) {
        final itemIndex = _selectedOrder!.items.indexWhere(
          (i) => i.id == itemId,
        );
        if (itemIndex != -1) {
          final updatedItem = updated.items.firstWhere((i) => i.id == itemId);
          // Update the item in-place to preserve order
          _selectedOrder!.items[itemIndex] = updatedItem;
          // Use copyWith to update immutable fields while preserving items order
          _selectedOrder = _selectedOrder!.copyWith(
            status: updated.status,
            backorderedItemsCount: updated.backorderedItemsCount,
            carts: updated.carts,
            items: _selectedOrder!.items, // Keep original order
          );
        }
      }
      await _loadAuditLogs(orderId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = _toUserMessage(e);
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
