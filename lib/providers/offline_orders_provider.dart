import 'package:flutter/foundation.dart';
import '../models/order_model.dart';
import '../models/audit_log_model.dart';
import '../services/orders_service.dart';
import '../services/socket_service.dart';
import '../services/connectivity_service.dart';
import '../services/sync_engine.dart';
import '../models/sync_models.dart';
import '../repositories/local_repository.dart';
import '../database/app_database.dart';

class OfflineOrdersProvider extends ChangeNotifier {
  late OrdersService _ordersService;
  final SocketService _socketService = SocketService();
  final LocalRepository _localRepository;
  final ConnectivityService _connectivityService;
  SyncEngine? _syncEngine;

  // Kanban data: status → orders
  final Map<OrderStatus, List<OrderListItem>> _columns = {
    for (final s in OrderStatus.values) s: [],
  };

  bool _loading = false;
  bool _refreshing = false;
  bool _syncing = false;
  String? _error;
  OrderDetail? _selectedOrder;
  List<AuditLog> _auditLogs = [];
  bool _logsLoading = false;
  int _pendingSyncCount = 0;

  Map<OrderStatus, List<OrderListItem>> get columns => _columns;
  bool get loading => _loading;
  bool get refreshing => _refreshing;
  bool get syncing => _syncing;
  String? get error => _error;
  OrderDetail? get selectedOrder => _selectedOrder;
  List<AuditLog> get auditLogs => _auditLogs;
  bool get logsLoading => _logsLoading;
  int get pendingSyncCount => _pendingSyncCount;
  bool get isOnline => _connectivityService.isOnline;

  int totalOrdersCount() => _columns.values.fold(0, (s, l) => s + l.length);

  OfflineOrdersProvider({
    required AppDatabase database,
    required ConnectivityService connectivityService,
    required String token,
  }) : _localRepository = LocalRepository(database),
       _connectivityService = connectivityService {
    _ordersService = OrdersService(token: token);
    _syncEngine = SyncEngine(
      database: database,
      connectivity: connectivityService,
      token: token,
    );

    _syncEngine!.addListener(_onSyncStatusChanged);
    _connectivityService.addListener(_onConnectivityChanged);

    _socketService.connect(token);
    _socketService.addHandler(_onSocketMessage);

    loadAllColumns();
  }

  void _onSyncStatusChanged() {
    _syncing = _syncEngine!.isSyncing;
    _pendingSyncCount = _syncEngine!.pendingOperationsCount;
    notifyListeners();
  }

  void _onConnectivityChanged() {
    notifyListeners();
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
      // Load from local database first (offline-first)
      final localOrders = await _localRepository.getAllOrders();
      _distributeToColumns(localOrders);

      // Try to fetch from server if online
      if (_connectivityService.isOnline) {
        try {
          final result = await _ordersService.getOrders(limit: 100);
          // Update local database with server data
          for (final item in result.items) {
            await _localRepository.insertOrder(item, needsSync: false);
          }
          _distributeToColumns(result.items);
        } catch (e) {
          debugPrint('Failed to fetch from server, using local data: $e');
        }
      }

      _error = null;
    } catch (e) {
      debugPrint('[OfflineOrdersProvider] loadAllColumns error: $e');
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
      if (_connectivityService.isOnline) {
        final result = await _ordersService.getOrders(limit: 100);
        // Update local database
        for (final item in result.items) {
          await _localRepository.insertOrder(item, needsSync: false);
        }
        _distributeToColumns(result.items);
      } else {
        // Refresh from local database
        final localOrders = await _localRepository.getAllOrders();
        _distributeToColumns(localOrders);
      }
    } catch (_) {}

    _refreshing = false;
    notifyListeners();
  }

  void _distributeToColumns(List<OrderListItem> items) {
    for (final status in OrderStatus.values) {
      _columns[status] = [];
    }
    debugPrint('[OfflineOrdersProvider] distributing ${items.length} items');
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
      if (_connectivityService.isOnline) {
        final updated = await _ordersService.getOrder(orderId);
        // Update local database
        await _localRepository.updateOrderDetail(updated, needsSync: false);
        _updateInColumns(updated);
      } else {
        // Refresh from local database
        final localOrder = await _localRepository.getOrderDetailById(orderId);
        if (localOrder != null) {
          _updateInColumns(localOrder);
        }
      }

      // Update selected order if open
      if (_selectedOrder?.id == orderId) {
        final localOrder = await _localRepository.getOrderDetailById(orderId);
        if (localOrder != null) {
          _selectedOrder = localOrder;
        }
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
      // Try local database first
      var localOrder = await _localRepository.getOrderDetailById(orderId);

      if (localOrder != null) {
        _selectedOrder = localOrder;
        notifyListeners();
      }

      // Try to fetch from server if online and local data is missing or stale
      if (_connectivityService.isOnline) {
        try {
          final serverOrder = await _ordersService.getOrder(orderId);
          _selectedOrder = serverOrder;
          // Update local database
          await _localRepository.updateOrderDetail(
            serverOrder,
            needsSync: false,
          );
          notifyListeners();
        } catch (e) {
          debugPrint('Failed to fetch from server, using local data: $e');
          if (localOrder == null) {
            _error = e.toString();
          }
        }
      } else if (localOrder == null) {
        _error = 'No internet connection and no local data available';
      }

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
      // Try local database first
      var localLogs = await _localRepository.getAuditLogs(orderId);
      _auditLogs = localLogs;

      // Try to fetch from server if online
      if (_connectivityService.isOnline) {
        try {
          final serverLogs = await _ordersService.getOrderLogs(orderId);
          _auditLogs = serverLogs;
          // Update local database
          for (final log in serverLogs) {
            await _localRepository.insertAuditLog(log);
          }
        } catch (e) {
          debugPrint('Failed to fetch audit logs from server: $e');
        }
      }
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
      // Update local database immediately (optimistic update)
      final currentOrder = await _localRepository.getOrderDetailById(orderId);
      if (currentOrder != null) {
        final updatedOrder = currentOrder.copyWith(
          status: nextStatus,
          pickerId: pickerId ?? currentOrder.pickerId,
          trolleyId: trolleyId ?? currentOrder.trolleyId,
          notes: notes ?? currentOrder.notes,
        );

        await _localRepository.updateOrderDetail(updatedOrder, needsSync: true);
        _updateInColumns(updatedOrder);
      }

      // Queue sync operation
      if (_syncEngine != null) {
        await _syncEngine!.queueOperation(
          SyncOperationModel(
            operationType: SyncOperationType.transition,
            entityType: SyncEntityType.order,
            entityId: orderId,
            payload: {
              'nextStatus': nextStatus.name.toLowerCase(),
              'pickerId': pickerId,
              'trolleyId': trolleyId,
              'backorderedItems': backorderedItems,
              'notes': notes,
            },
            createdAt: DateTime.now(),
          ),
        );
      }

      // Try to sync immediately if online
      if (_connectivityService.isOnline) {
        try {
          final updated = await _ordersService.transition(
            orderId: orderId,
            nextStatus: nextStatus,
            pickerId: pickerId,
            trolleyId: trolleyId,
            backorderedItems: backorderedItems,
            notes: notes,
          );

          // Update local database with server response
          await _localRepository.updateOrderDetail(updated, needsSync: false);
          _updateInColumns(updated);
          _selectedOrder = updated;

          // Refresh logs
          await _loadAuditLogs(orderId);
        } catch (e) {
          debugPrint('Server sync failed, operation queued: $e');
        }
      }

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
      // Update local database immediately
      final currentOrder = await _localRepository.getOrderById(orderId);
      if (currentOrder != null) {
        final updatedOrder = OrderListItem(
          id: currentOrder.id,
          code: currentOrder.code,
          status: currentOrder.status,
          paymentStatus: PaymentStatus.PAID,
          paymentType: currentOrder.paymentType,
          customerId: currentOrder.customerId,
          customerName: currentOrder.customerName,
          branchId: currentOrder.branchId,
          branchName: currentOrder.branchName,
          salesManagerId: currentOrder.salesManagerId,
          salesManagerName: currentOrder.salesManagerName,
          pickerId: currentOrder.pickerId,
          pickerName: currentOrder.pickerName,
          createdAt: currentOrder.createdAt,
          endDate: currentOrder.endDate,
          completedAt: currentOrder.completedAt,
          backorderedItemsCount: currentOrder.backorderedItemsCount,
          totalItems: currentOrder.totalItems,
          trolleyId: currentOrder.trolleyId,
          notes: currentOrder.notes,
          deliveryType: currentOrder.deliveryType,
          isPostPayment: currentOrder.isPostPayment,
        );

        await _localRepository.updateOrder(updatedOrder, needsSync: true);
        _updateInColumns(updatedOrder);
      }

      // Queue sync operation
      if (_syncEngine != null) {
        await _syncEngine!.queueOperation(
          SyncOperationModel(
            operationType: SyncOperationType.markPaid,
            entityType: SyncEntityType.order,
            entityId: orderId,
            payload: {},
            createdAt: DateTime.now(),
          ),
        );
      }

      // Try to sync immediately if online
      if (_connectivityService.isOnline) {
        try {
          final updated = await _ordersService.markPaid(orderId);
          await _localRepository.updateOrderDetail(updated, needsSync: false);
          _updateInColumns(updated);
        } catch (e) {
          debugPrint('Server sync failed, operation queued: $e');
        }
      }

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
      // Update local database immediately
      final currentOrder = await _localRepository.getOrderById(orderId);
      if (currentOrder != null) {
        final updatedOrder = OrderListItem(
          id: currentOrder.id,
          code: currentOrder.code,
          status: currentOrder.status,
          paymentStatus: PaymentStatus.UNPAID,
          paymentType: currentOrder.paymentType,
          customerId: currentOrder.customerId,
          customerName: currentOrder.customerName,
          branchId: currentOrder.branchId,
          branchName: currentOrder.branchName,
          salesManagerId: currentOrder.salesManagerId,
          salesManagerName: currentOrder.salesManagerName,
          pickerId: currentOrder.pickerId,
          pickerName: currentOrder.pickerName,
          createdAt: currentOrder.createdAt,
          endDate: currentOrder.endDate,
          completedAt: currentOrder.completedAt,
          backorderedItemsCount: currentOrder.backorderedItemsCount,
          totalItems: currentOrder.totalItems,
          trolleyId: currentOrder.trolleyId,
          notes: currentOrder.notes,
          deliveryType: currentOrder.deliveryType,
          isPostPayment: currentOrder.isPostPayment,
        );

        await _localRepository.updateOrder(updatedOrder, needsSync: true);
        _updateInColumns(updatedOrder);
      }

      // Queue sync operation
      if (_syncEngine != null) {
        await _syncEngine!.queueOperation(
          SyncOperationModel(
            operationType: SyncOperationType.unmarkPaid,
            entityType: SyncEntityType.order,
            entityId: orderId,
            payload: {},
            createdAt: DateTime.now(),
          ),
        );
      }

      // Try to sync immediately if online
      if (_connectivityService.isOnline) {
        try {
          final updated = await _ordersService.unmarkPaid(orderId);
          await _localRepository.updateOrderDetail(updated, needsSync: false);
          _updateInColumns(updated);
        } catch (e) {
          debugPrint('Server sync failed, operation queued: $e');
        }
      }

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
      // Update local database immediately
      final currentOrder = await _localRepository.getOrderById(orderId);
      if (currentOrder != null) {
        final updatedOrder = OrderListItem(
          id: currentOrder.id,
          code: currentOrder.code,
          status: currentOrder.status,
          paymentStatus: currentOrder.paymentStatus,
          paymentType: currentOrder.paymentType,
          customerId: currentOrder.customerId,
          customerName: currentOrder.customerName,
          branchId: currentOrder.branchId,
          branchName: currentOrder.branchName,
          salesManagerId: currentOrder.salesManagerId,
          salesManagerName: currentOrder.salesManagerName,
          pickerId: currentOrder.pickerId,
          pickerName: currentOrder.pickerName,
          createdAt: currentOrder.createdAt,
          endDate: endDate ?? currentOrder.endDate,
          completedAt: currentOrder.completedAt,
          backorderedItemsCount: currentOrder.backorderedItemsCount,
          totalItems: currentOrder.totalItems,
          trolleyId: clearTrolley
              ? null
              : (trolleyId ?? currentOrder.trolleyId),
          notes: currentOrder.notes,
          deliveryType: currentOrder.deliveryType,
          isPostPayment: currentOrder.isPostPayment,
        );

        await _localRepository.updateOrder(updatedOrder, needsSync: true);
        _updateInColumns(updatedOrder);
      }

      // Queue sync operation
      if (_syncEngine != null) {
        await _syncEngine!.queueOperation(
          SyncOperationModel(
            operationType: SyncOperationType.update,
            entityType: SyncEntityType.order,
            entityId: orderId,
            payload: {
              'trolleyId': clearTrolley ? null : trolleyId,
              'endDate': endDate?.toIso8601String(),
            },
            createdAt: DateTime.now(),
          ),
        );
      }

      // Try to sync immediately if online
      if (_connectivityService.isOnline) {
        try {
          final updated = await _ordersService.updateDetails(
            orderId: orderId,
            trolleyId: trolleyId,
            clearTrolley: clearTrolley,
            endDate: endDate,
          );
          await _localRepository.updateOrderDetail(updated, needsSync: false);
          _updateInColumns(updated);
          await _loadAuditLogs(orderId);
        } catch (e) {
          debugPrint('Server sync failed, operation queued: $e');
        }
      }

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
    required List<String> cartIds,
  }) async {
    try {
      // Queue sync operation
      if (_syncEngine != null) {
        await _syncEngine!.queueOperation(
          SyncOperationModel(
            operationType: SyncOperationType.attachCart,
            entityType: SyncEntityType.order,
            entityId: orderId,
            payload: {'cartIds': cartIds},
            createdAt: DateTime.now(),
          ),
        );
      }

      // Try to sync immediately if online
      if (_connectivityService.isOnline) {
        try {
          final updated = await _ordersService.attachCart(
            orderId: orderId,
            cartIds: cartIds,
          );
          await _localRepository.updateOrderDetail(updated, needsSync: false);
          _updateInColumns(updated);
          await _loadAuditLogs(orderId);
        } catch (e) {
          debugPrint('Server sync failed, operation queued: $e');
        }
      }

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
      // Queue sync operation
      if (_syncEngine != null) {
        await _syncEngine!.queueOperation(
          SyncOperationModel(
            operationType: SyncOperationType.detachCart,
            entityType: SyncEntityType.order,
            entityId: orderId,
            payload: {'cartId': cartId},
            createdAt: DateTime.now(),
          ),
        );
      }

      // Try to sync immediately if online
      if (_connectivityService.isOnline) {
        try {
          final updated = await _ordersService.detachCart(
            orderId: orderId,
            cartId: cartId,
          );
          await _localRepository.updateOrderDetail(updated, needsSync: false);
          _updateInColumns(updated);
          await _loadAuditLogs(orderId);
        } catch (e) {
          debugPrint('Server sync failed, operation queued: $e');
        }
      }

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
      if (_connectivityService.isOnline) {
        final raw = await _ordersService.getAvailableCarts(branchId: branchId);
        return raw;
      } else {
        // Return empty list when offline
        return [];
      }
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
    bool syncSucceeded = true;

    try {
      // Update local database immediately
      final currentOrder = await _localRepository.getOrderDetailById(orderId);
      if (currentOrder != null) {
        final itemIndex = currentOrder.items.indexWhere((i) => i.id == itemId);
        if (itemIndex != -1) {
          final updatedItem = OrderItem(
            id: currentOrder.items[itemIndex].id,
            productId: currentOrder.items[itemIndex].productId,
            productName: currentOrder.items[itemIndex].productName,
            productSku: currentOrder.items[itemIndex].productSku,
            quantity:
                quantity?.toInt() ?? currentOrder.items[itemIndex].quantity,
            backorderedQuantity:
                backorderedQuantity?.toInt() ??
                currentOrder.items[itemIndex].backorderedQuantity,
            status: status != null
                ? ItemStatus.fromRaw(status)
                : currentOrder.items[itemIndex].status,
            unitPrice: currentOrder.items[itemIndex].unitPrice,
          );

          await _localRepository.updateOrderItem(
            updatedItem,
            orderId,
            needsSync: true,
          );

          // Update selected order
          currentOrder.items[itemIndex] = updatedItem;
          _selectedOrder = currentOrder;
        }
      }

      // Queue sync operation
      if (_syncEngine != null) {
        await _syncEngine!.queueOperation(
          SyncOperationModel(
            operationType: SyncOperationType.updateItem,
            entityType: SyncEntityType.orderItem,
            entityId: itemId,
            payload: {
              'orderId': orderId,
              'itemId': itemId,
              'quantity': quantity,
              'status': status,
              'backorderedQuantity': backorderedQuantity,
            },
            createdAt: DateTime.now(),
          ),
        );
      }

      // Try to sync immediately if online
      if (_connectivityService.isOnline) {
        try {
          final updated = await _ordersService.updateItem(
            orderId: orderId,
            itemId: itemId,
            quantity: quantity,
            status: status,
            backorderedQuantity: backorderedQuantity,
          );
          await _localRepository.updateOrderDetail(updated, needsSync: false);

          if (_selectedOrder?.id == updated.id) {
            final itemIndex = _selectedOrder!.items.indexWhere(
              (i) => i.id == itemId,
            );
            if (itemIndex != -1) {
              final updatedItem = updated.items.firstWhere(
                (i) => i.id == itemId,
              );
              _selectedOrder!.items[itemIndex] = updatedItem;
              _selectedOrder = _selectedOrder!.copyWith(
                status: updated.status,
                backorderedItemsCount: updated.backorderedItemsCount,
                carts: updated.carts,
                items: _selectedOrder!.items,
              );
            }
          }

          await _loadAuditLogs(orderId);
        } catch (e) {
          syncSucceeded = false;
          debugPrint('Server sync failed, operation queued: $e');
        }
      }

      notifyListeners();
      return syncSucceeded;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void _updateInColumns(OrderListItem updated) {
    for (final list in _columns.values) {
      list.removeWhere((o) => o.id == updated.id);
    }
    _columns[updated.status]?.insert(0, updated);
    if (_selectedOrder?.id == updated.id) {
      if (updated is OrderDetail) {
        _selectedOrder = updated;
      } else {
        _selectedOrder = _selectedOrder!.copyWith(
          status: updated.status,
          paymentStatus: updated.paymentStatus,
          paymentType: updated.paymentType,
          customerId: updated.customerId,
          customerName: updated.customerName,
          branchId: updated.branchId,
          branchName: updated.branchName,
          salesManagerId: updated.salesManagerId,
          salesManagerName: updated.salesManagerName,
          pickerId: updated.pickerId,
          pickerName: updated.pickerName,
          createdAt: updated.createdAt,
          endDate: updated.endDate,
          backorderedItemsCount: updated.backorderedItemsCount,
          totalItems: updated.totalItems,
          trolleyId: updated.trolleyId,
          notes: updated.notes,
          completedAt: updated.completedAt,
          deliveryType: updated.deliveryType,
          isPostPayment: updated.isPostPayment,
        );
      }
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Force sync
  Future<void> forceSync() async {
    if (_syncEngine != null) {
      await _syncEngine!.forceSync();
    }
  }

  @override
  void dispose() {
    _socketService.disconnect();
    _syncEngine?.removeListener(_onSyncStatusChanged);
    _connectivityService.removeListener(_onConnectivityChanged);
    _syncEngine?.dispose();
    super.dispose();
  }
}
