import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:drift/drift.dart';
import 'package:korzinkab_mobile/database/app_database.dart';
import 'package:korzinkab_mobile/models/sync_models.dart';
import 'package:korzinkab_mobile/services/connectivity_service.dart';
import 'package:korzinkab_mobile/config/app_config.dart';
import 'package:korzinkab_mobile/models/order_model.dart';
import 'package:korzinkab_mobile/models/product_model.dart';
import 'package:korzinkab_mobile/models/user_model.dart';

class SyncEngine extends ChangeNotifier {
  final AppDatabase _database;
  final ConnectivityService _connectivity;
  final String _token;

  Timer? _syncTimer;
  bool _isSyncing = false;
  int _pendingOperationsCount = 0;
  String? _lastSyncError;
  DateTime? _lastSuccessfulSync;

  bool get isSyncing => _isSyncing;
  int get pendingOperationsCount => _pendingOperationsCount;
  String? get lastSyncError => _lastSyncError;
  DateTime? get lastSuccessfulSync => _lastSuccessfulSync;

  SyncEngine({
    required AppDatabase database,
    required ConnectivityService connectivity,
    required String token,
  }) : _database = database,
       _connectivity = connectivity,
       _token = token {
    _initialize();
  }

  void _initialize() {
    // Listen to connectivity changes
    _connectivity.addListener(_onConnectivityChanged);

    // Start periodic sync every 30 seconds when online
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_connectivity.isOnline && !_isSyncing) {
        sync();
      }
    });

    // Initial sync check
    if (_connectivity.isOnline) {
      sync();
    }

    // Update pending count periodically
    Timer.periodic(const Duration(seconds: 5), (_) async {
      final pending = await _database.getPendingSyncOperations();
      _pendingOperationsCount = pending.length;
      notifyListeners();
    });
  }

  void _onConnectivityChanged() {
    if (_connectivity.isOnline && !_isSyncing) {
      // Start sync when connection is restored
      sync();
    }
  }

  Future<void> sync() async {
    if (_isSyncing) return;
    if (!_connectivity.isOnline) {
      debugPrint('🔄 Sync skipped: offline');
      return;
    }

    _isSyncing = true;
    _lastSyncError = null;
    notifyListeners();

    try {
      debugPrint('🔄 Starting synchronization...');

      // Step 1: Upload pending operations
      await _uploadPendingOperations();

      // Step 2: Download updated data (incremental sync)
      await _downloadUpdatedData();

      // Step 3: Clean up successful sync operations
      await _cleanupSuccessfulOperations();

      _lastSuccessfulSync = DateTime.now();
      debugPrint('✅ Synchronization completed successfully');
    } catch (e, stackTrace) {
      _lastSyncError = e.toString();
      debugPrint('❌ Synchronization failed: $e');
      debugPrint(stackTrace.toString());
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _uploadPendingOperations() async {
    final pendingOps = await _database.getPendingSyncOperations();

    if (pendingOps.isEmpty) {
      debugPrint('📤 No pending operations to upload');
      return;
    }

    debugPrint('📤 Uploading ${pendingOps.length} pending operations...');

    for (final dbOp in pendingOps) {
      final op = SyncOperationModel.fromDatabase(dbOp);

      try {
        // Mark as syncing
        await _database.updateSyncOperation(
          op
              .copyWith(
                syncStatus: SyncStatus.syncing,
                attemptedAt: DateTime.now(),
                retryCount: op.retryCount + 1,
              )
              .toDatabase(),
        );

        // Execute the operation
        final success = await _executeOperation(op);

        if (success) {
          // Mark as success
          await _database.updateSyncOperation(
            op
                .copyWith(
                  syncStatus: SyncStatus.success,
                  syncedAt: DateTime.now(),
                )
                .toDatabase(),
          );

          // Update the entity's sync status
          await _updateEntitySyncStatus(op);

          debugPrint(
            '✅ Operation succeeded: ${op.operationType.value} ${op.entityType.value} ${op.entityId}',
          );
        } else {
          throw Exception('Operation execution failed');
        }
      } catch (e) {
        // Mark as failed with exponential backoff
        final canRetry = op.canRetry;
        await _database.updateSyncOperation(
          op
              .copyWith(
                syncStatus: SyncStatus.failed,
                errorMessage: e.toString(),
              )
              .toDatabase(),
        );

        debugPrint(
          '❌ Operation failed: ${op.operationType.value} ${op.entityType.value} ${op.entityId} - $e',
        );

        if (!canRetry) {
          debugPrint('⚠️ Max retries reached for operation ${op.id}');
        }
      }
    }
  }

  Future<bool> _executeOperation(SyncOperationModel op) async {
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_token',
    };

    switch (op.entityType) {
      case SyncEntityType.order:
        return await _executeOrderOperation(op, headers);

      case SyncEntityType.orderItem:
        return await _executeOrderItemOperation(op, headers);

      case SyncEntityType.customer:
        return await _executeCustomerOperation(op, headers);

      case SyncEntityType.product:
        return await _executeProductOperation(op, headers);

      case SyncEntityType.user:
        return await _executeUserOperation(op, headers);

      case SyncEntityType.auditLog:
        // Audit logs are read-only from client perspective
        return true;
    }
  }

  Future<bool> _executeOrderOperation(
    SyncOperationModel op,
    Map<String, String> headers,
  ) async {
    switch (op.operationType) {
      case SyncOperationType.transition:
        final response = await http
            .post(
              Uri.parse(
                '${AppConfig.baseUrl}/orders/${op.entityId}/transitions',
              ),
              headers: headers,
              body: jsonEncode(op.payload),
            )
            .timeout(const Duration(seconds: 10));
        return response.statusCode >= 200 && response.statusCode < 300;

      case SyncOperationType.markPaid:
        final response = await http
            .post(
              Uri.parse('${AppConfig.baseUrl}/orders/${op.entityId}/mark-paid'),
              headers: headers,
            )
            .timeout(const Duration(seconds: 10));
        return response.statusCode >= 200 && response.statusCode < 300;

      case SyncOperationType.unmarkPaid:
        final response = await http
            .post(
              Uri.parse(
                '${AppConfig.baseUrl}/orders/${op.entityId}/unmark-paid',
              ),
              headers: headers,
            )
            .timeout(const Duration(seconds: 10));
        return response.statusCode >= 200 && response.statusCode < 300;

      case SyncOperationType.attachCart:
        final response = await http
            .post(
              Uri.parse('${AppConfig.baseUrl}/orders/${op.entityId}/carts'),
              headers: headers,
              body: jsonEncode(op.payload),
            )
            .timeout(const Duration(seconds: 10));
        return response.statusCode >= 200 && response.statusCode < 300;

      case SyncOperationType.detachCart:
        final cartId = op.payload['cartId'] as String;
        final response = await http
            .delete(
              Uri.parse(
                '${AppConfig.baseUrl}/orders/${op.entityId}/carts/$cartId',
              ),
              headers: headers,
            )
            .timeout(const Duration(seconds: 10));
        return response.statusCode >= 200 && response.statusCode < 300;

      case SyncOperationType.update:
        final response = await http
            .patch(
              Uri.parse('${AppConfig.baseUrl}/orders/${op.entityId}/details'),
              headers: headers,
              body: jsonEncode(op.payload),
            )
            .timeout(const Duration(seconds: 10));
        return response.statusCode >= 200 && response.statusCode < 300;

      default:
        return false;
    }
  }

  Future<bool> _executeOrderItemOperation(
    SyncOperationModel op,
    Map<String, String> headers,
  ) async {
    switch (op.operationType) {
      case SyncOperationType.updateItem:
        final response = await http
            .patch(
              Uri.parse(
                '${AppConfig.baseUrl}/orders/${op.entityId}/items/${op.payload['itemId']}',
              ),
              headers: headers,
              body: jsonEncode(op.payload),
            )
            .timeout(const Duration(seconds: 10));
        return response.statusCode >= 200 && response.statusCode < 300;

      default:
        return false;
    }
  }

  Future<bool> _executeCustomerOperation(
    SyncOperationModel op,
    Map<String, String> headers,
  ) async {
    // Customer operations - implement as needed
    return true;
  }

  Future<bool> _executeProductOperation(
    SyncOperationModel op,
    Map<String, String> headers,
  ) async {
    // Product operations - implement as needed
    return true;
  }

  Future<bool> _executeUserOperation(
    SyncOperationModel op,
    Map<String, String> headers,
  ) async {
    // User operations - implement as needed
    return true;
  }

  Future<void> _updateEntitySyncStatus(SyncOperationModel op) async {
    switch (op.entityType) {
      case SyncEntityType.order:
        final order = await _database.getOrderById(op.entityId);
        if (order != null) {
          await _database.updateOrder(
            order.copyWith(
              needsSync: false,
              syncStatus: 'synced',
              syncedAt: Value(DateTime.now()),
            ),
          );
        }
        break;

      case SyncEntityType.orderItem:
        final items = await _database.getOrderItems(op.entityId);
        for (final item in items) {
          await _database.updateOrderItem(
            item.copyWith(needsSync: false, syncedAt: Value(DateTime.now())),
          );
        }
        break;

      default:
        break;
    }
  }

  Future<void> _downloadUpdatedData() async {
    // Get last sync timestamp
    final lastSyncSetting = await _database.getSetting('last_sync_timestamp');
    final lastSync = lastSyncSetting != null
        ? DateTime.parse(lastSyncSetting.value)
        : DateTime.now().subtract(
            const Duration(days: 30),
          ); // Default to 30 days ago

    debugPrint('📥 Downloading data since $lastSync...');

    // Download orders
    await _downloadOrders(lastSync);

    // Download products
    await _downloadProducts(lastSync);

    // Download customers
    await _downloadCustomers(lastSync);

    // Download users
    await _downloadUsers(lastSync);

    // Update last sync timestamp
    await _database.setSettingValue(
      'last_sync_timestamp',
      DateTime.now().toIso8601String(),
    );
  }

  Future<void> _downloadOrders(DateTime since) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      };

      final uri = Uri.parse('${AppConfig.baseUrl}/orders').replace(
        queryParameters: {'from': since.toIso8601String(), 'limit': '100'},
      );

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> items = [];

        if (decoded is List) {
          items = decoded;
        } else if (decoded is Map<String, dynamic>) {
          items = decoded['data'] ?? decoded['items'] ?? [];
        }

        debugPrint('📥 Downloaded ${items.length} orders');

        for (final item in items) {
          try {
            final orderItem = OrderListItem.fromJson(
              item as Map<String, dynamic>,
            );

            // Check if order exists and resolve conflicts (last write wins)
            final existing = await _database.getOrderById(orderItem.id);

            final localOrder = LocalOrder(
              id: orderItem.id,
              code: orderItem.code,
              status: orderItem.status.name,
              paymentStatus: orderItem.paymentStatus.name,
              paymentType: orderItem.paymentType.name,
              customerId: orderItem.customerId,
              customerName: orderItem.customerName,
              branchId: orderItem.branchId,
              branchName: orderItem.branchName,
              salesManagerId: orderItem.salesManagerId,
              salesManagerName: orderItem.salesManagerName,
              pickerId: orderItem.pickerId,
              pickerName: orderItem.pickerName,
              createdAt: orderItem.createdAt,
              endDate: orderItem.endDate,
              completedAt: orderItem.completedAt,
              backorderedItemsCount: orderItem.backorderedItemsCount,
              totalItems: orderItem.totalItems,
              trolleyId: orderItem.trolleyId,
              notes: orderItem.notes,
              deliveryType: orderItem.deliveryType.name,
              isPostPayment: orderItem.isPostPayment,
              updatedAt: DateTime.now(),
              syncedAt: DateTime.now(),
              needsSync: false,
              syncStatus: 'synced',
            );

            if (existing != null) {
              // Conflict resolution: Last Write Wins based on syncedAt
              if (existing.syncedAt == null ||
                  localOrder.syncedAt!.isAfter(existing.syncedAt!)) {
                await _database.updateOrder(localOrder);
              }
            } else {
              await _database.insertOrder(localOrder);
            }
          } catch (e) {
            debugPrint('Error parsing order: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error downloading orders: $e');
    }
  }

  Future<void> _downloadProducts(DateTime since) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      };

      final uri = Uri.parse('${AppConfig.baseUrl}/products').replace(
        queryParameters: {'from': since.toIso8601String(), 'limit': '100'},
      );

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> items = [];

        if (decoded is List) {
          items = decoded;
        } else if (decoded is Map<String, dynamic>) {
          items = decoded['data'] ?? decoded['items'] ?? [];
        }

        debugPrint('📥 Downloaded ${items.length} products');

        for (final item in items) {
          try {
            final product = Product.fromJson(item as Map<String, dynamic>);

            final existing = await (_database.select(
              _database.products,
            )..where((tbl) => tbl.id.equals(product.id))).getSingleOrNull();

            final localProduct = LocalProduct(
              id: product.id,
              sku: product.sku,
              name: product.name,
              barcode: product.barcode,
              unit: product.unit,
              brand: product.brand,
              price: product.price,
              isActive: product.isActive,
              updatedAt: DateTime.now(),
              syncedAt: DateTime.now(),
            );

            if (existing != null) {
              await _database.updateProduct(localProduct);
            } else {
              await _database.insertProduct(localProduct);
            }
          } catch (e) {
            debugPrint('Error parsing product: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error downloading products: $e');
    }
  }

  Future<void> _downloadCustomers(DateTime since) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      };

      final uri = Uri.parse('${AppConfig.baseUrl}/customers').replace(
        queryParameters: {'from': since.toIso8601String(), 'limit': '100'},
      );

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> items = [];

        if (decoded is List) {
          items = decoded;
        } else if (decoded is Map<String, dynamic>) {
          items = decoded['data'] ?? decoded['items'] ?? [];
        }

        debugPrint('📥 Downloaded ${items.length} customers');

        for (final item in items) {
          try {
            final customer = Customer.fromJson(item as Map<String, dynamic>);

            final existing = await _database.getCustomerById(customer.id);

            final localCustomer = LocalCustomer(
              id: customer.id,
              name: customer.name,
              phone: customer.phone,
              email: customer.email,
              updatedAt: DateTime.now(),
              syncedAt: DateTime.now(),
            );

            if (existing != null) {
              await _database.updateCustomer(localCustomer);
            } else {
              await _database.insertCustomer(localCustomer);
            }
          } catch (e) {
            debugPrint('Error parsing customer: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error downloading customers: $e');
    }
  }

  Future<void> _downloadUsers(DateTime since) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      };

      final uri = Uri.parse('${AppConfig.baseUrl}/users').replace(
        queryParameters: {'from': since.toIso8601String(), 'limit': '100'},
      );

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> items = [];

        if (decoded is List) {
          items = decoded;
        } else if (decoded is Map<String, dynamic>) {
          items = decoded['data'] ?? decoded['items'] ?? [];
        }

        debugPrint('📥 Downloaded ${items.length} users');

        for (final item in items) {
          try {
            final user = AuthenticatedUser.fromJson(
              item as Map<String, dynamic>,
            );

            final existing = await _database.getUserById(user.id);

            final localUser = LocalUser(
              id: user.id,
              username: user.username,
              name: user.name,
              email: user.email,
              role: user.role.name,
              isActive: user.isActive,
              branchId: user.branchId,
              updatedAt: DateTime.now(),
              syncedAt: DateTime.now(),
            );

            if (existing != null) {
              await _database.updateUser(localUser);
            } else {
              await _database.insertUser(localUser);
            }
          } catch (e) {
            debugPrint('Error parsing user: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error downloading users: $e');
    }
  }

  Future<void> _cleanupSuccessfulOperations() async {
    await _database.clearPendingSyncOperations();
  }

  // Public method to queue a sync operation
  Future<void> queueOperation(SyncOperationModel operation) async {
    await _database.insertSyncOperation(operation.toDatabase());
    _pendingOperationsCount++;
    notifyListeners();

    // Try to sync immediately if online
    if (_connectivity.isOnline && !_isSyncing) {
      sync();
    }
  }

  // Force sync (manual trigger)
  Future<void> forceSync() async {
    await sync();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _connectivity.removeListener(_onConnectivityChanged);
    super.dispose();
  }
}
