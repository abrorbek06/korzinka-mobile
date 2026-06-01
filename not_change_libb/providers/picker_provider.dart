import 'package:flutter/foundation.dart';
import '../models/order_model.dart';
import '../services/api_service.dart';
import '../services/trolley_service.dart';

class PickerProvider extends ChangeNotifier {
  late OrdersService _api;
  final TrolleyService trolleyService = TrolleyService();

  List<OrderSummary> _orders = [];
  OrderDetail? _detail;
  bool _loading = false;
  bool _detailLoading = false;
  String? _error;

  // Collected quantities: itemId → collected count
  final Map<String, int> _collected = {};

  List<OrderSummary> get orders => _orders;
  OrderDetail? get detail => _detail;
  bool get loading => _loading;
  bool get detailLoading => _detailLoading;
  String? get error => _error;

  // Orders grouped by status
  List<OrderSummary> byStatus(OrderStatus s) =>
      _orders.where((o) => o.status == s).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<OrderStatus> get activeStatuses => OrderStatus.values;

  // ─── Init ──────────────────────────────────────────────────────────────────

  Future<void> init(String token) async {
    _api = OrdersService(token: token);
    await trolleyService.load();
    await loadOrders();
  }

  // ─── Orders ────────────────────────────────────────────────────────────────

  Future<void> loadOrders() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _orders = await _api.getMyOrders();
    } on AppException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Buyurtmalar yuklanmadi';
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> loadDetail(String orderId) async {
    _detail = null;
    _collected.clear();
    _detailLoading = true;
    notifyListeners();
    try {
      _detail = await _api.getOrder(orderId);
      // Init collected quantities to required (optimistic)
      for (final p in _detail!.products) {
        _collected[p.id] = p.requiredQty;
      }
    } on AppException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Buyurtma yuklanmadi';
    }
    _detailLoading = false;
    notifyListeners();
  }

  // ─── Collected quantities ──────────────────────────────────────────────────

  int getCollected(String itemId) => _collected[itemId] ?? 0;

  void setCollected(String itemId, int value, {required int max}) {
    _collected[itemId] = value.clamp(0, max);
    notifyListeners();
  }

  void incrementCollected(String itemId, {required int max}) {
    final cur = _collected[itemId] ?? 0;
    if (cur < max) {
      _collected[itemId] = cur + 1;
      notifyListeners();
    }
  }

  void decrementCollected(String itemId) {
    final cur = _collected[itemId] ?? 0;
    if (cur > 0) {
      _collected[itemId] = cur - 1;
      notifyListeners();
    }
  }

  /// Icons status: 0=missing(red), 1=partial(orange), 2=full(green)
  int itemCollectedStatus(String itemId, int required) {
    final c = _collected[itemId] ?? 0;
    if (c == 0) return 0;
    if (c < required) return 1;
    return 2;
  }

  // Summary for bottom button
  int get totalRequired =>
      _detail?.products.fold<int>(0, (int s, p) => s + p.requiredQty) ?? 0;
  int get totalCollected => _collected.values.fold(0, (s, v) => s + v);
  bool get allCollected => _detail != null && totalCollected >= totalRequired;

  // ─── Trolley ───────────────────────────────────────────────────────────────

  String? getTrolley(String orderId) =>
      trolleyService.getTrolleyForOrder(orderId);

  Future<void> assignTrolley(String orderId, String trolleyCode) async {
    await trolleyService.assign(orderId: orderId, trolleyCode: trolleyCode);
    notifyListeners();
  }

  List<Trolley> getAllTrolleys() {
    final codeMap = {for (final o in _orders) o.id: o.code ?? o.id};
    return trolleyService.getAllWithState(codeMap);
  }

  // ─── Transitions ───────────────────────────────────────────────────────────

  Future<bool> markReady({String? notes}) async {
    if (_detail == null) return false;
    try {
      final updated = await _api.transition(
        orderId: _detail!.id,
        nextStatus: OrderStatus.READY,
        notes: notes,
      );
      _detail = updated;
      _updateInList(updated);
      notifyListeners();
      return true;
    } on AppException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  void _updateInList(OrderDetail d) {
    final idx = _orders.indexWhere((o) => o.id == d.id);
    if (idx != -1) {
      _orders[idx] = d;
    } else {
      _orders.insert(0, d);
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
