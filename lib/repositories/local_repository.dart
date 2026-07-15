import 'dart:convert';
import 'package:korzinkab_mobile/database/app_database.dart';
import 'package:korzinkab_mobile/models/order_model.dart';
import 'package:korzinkab_mobile/models/product_model.dart';
import 'package:korzinkab_mobile/models/user_model.dart';
import 'package:korzinkab_mobile/models/audit_log_model.dart';
import 'package:korzinkab_mobile/models/sync_models.dart';

class LocalRepository {
  final AppDatabase _database;

  LocalRepository(this._database);

  // Orders
  Future<List<OrderListItem>> getAllOrders() async {
    final localOrders = await _database.getAllOrders();
    return localOrders.map(_mapToOrderListItem).toList();
  }

  Future<List<OrderListItem>> getOrdersByStatus(OrderStatus status) async {
    final localOrders = await _database.getOrdersByStatus(status.name);
    return localOrders.map(_mapToOrderListItem).toList();
  }

  Future<OrderListItem?> getOrderById(String id) async {
    final localOrder = await _database.getOrderById(id);
    return localOrder != null ? _mapToOrderListItem(localOrder) : null;
  }

  Future<OrderDetail?> getOrderDetailById(String id) async {
    final localOrder = await _database.getOrderById(id);
    if (localOrder == null) return null;

    final localItems = await _database.getOrderItems(id);
    final items = localItems.map(_mapToOrderItem).toList();

    return OrderDetail(
      id: localOrder.id,
      code: localOrder.code,
      status: OrderStatus.fromRaw(localOrder.status),
      paymentStatus: PaymentStatus.fromRaw(localOrder.paymentStatus),
      paymentType: PaymentType.fromRaw(localOrder.paymentType),
      customerId: localOrder.customerId,
      customerName: localOrder.customerName,
      branchId: localOrder.branchId,
      branchName: localOrder.branchName,
      salesManagerId: localOrder.salesManagerId,
      salesManagerName: localOrder.salesManagerName,
      pickerId: localOrder.pickerId,
      pickerName: localOrder.pickerName,
      createdAt: localOrder.createdAt,
      endDate: localOrder.endDate,
      completedAt: localOrder.completedAt,
      backorderedItemsCount: localOrder.backorderedItemsCount,
      totalItems: localOrder.totalItems,
      trolleyId: localOrder.trolleyId,
      notes: localOrder.notes,
      deliveryType: DeliveryType.fromRaw(localOrder.deliveryType),
      isPostPayment: localOrder.isPostPayment,
      items: items,
    );
  }

  Future<void> insertOrder(OrderListItem order, {bool needsSync = true}) async {
    final localOrder = LocalOrder(
      id: order.id,
      code: order.code,
      status: order.status.name,
      paymentStatus: order.paymentStatus.name,
      paymentType: order.paymentType.name,
      customerId: order.customerId,
      customerName: order.customerName,
      branchId: order.branchId,
      branchName: order.branchName,
      salesManagerId: order.salesManagerId,
      salesManagerName: order.salesManagerName,
      pickerId: order.pickerId,
      pickerName: order.pickerName,
      createdAt: order.createdAt,
      endDate: order.endDate,
      completedAt: order.completedAt,
      backorderedItemsCount: order.backorderedItemsCount,
      totalItems: order.totalItems,
      trolleyId: order.trolleyId,
      notes: order.notes,
      deliveryType: order.deliveryType.name,
      isPostPayment: order.isPostPayment,
      updatedAt: DateTime.now(),
      syncedAt: needsSync ? null : DateTime.now(),
      needsSync: needsSync,
      syncStatus: needsSync ? 'pending' : 'synced',
    );

    await _database.insertOrder(localOrder);
  }

  Future<void> insertOrderDetail(
    OrderDetail order, {
    bool needsSync = true,
  }) async {
    // Insert order
    final localOrder = LocalOrder(
      id: order.id,
      code: order.code,
      status: order.status.name,
      paymentStatus: order.paymentStatus.name,
      paymentType: order.paymentType.name,
      customerId: order.customerId,
      customerName: order.customerName,
      branchId: order.branchId,
      branchName: order.branchName,
      salesManagerId: order.salesManagerId,
      salesManagerName: order.salesManagerName,
      pickerId: order.pickerId,
      pickerName: order.pickerName,
      createdAt: order.createdAt,
      endDate: order.endDate,
      completedAt: order.completedAt,
      backorderedItemsCount: order.backorderedItemsCount,
      totalItems: order.totalItems,
      trolleyId: order.trolleyId,
      notes: order.notes,
      deliveryType: order.deliveryType.name,
      isPostPayment: order.isPostPayment,
      updatedAt: DateTime.now(),
      syncedAt: needsSync ? null : DateTime.now(),
      needsSync: needsSync,
      syncStatus: needsSync ? 'pending' : 'synced',
    );

    await _database.insertOrder(localOrder);

    // Insert order items
    for (final item in order.items) {
      await insertOrderItem(item, order.id, needsSync: needsSync);
    }
  }

  Future<void> updateOrder(OrderListItem order, {bool needsSync = true}) async {
    final localOrder = LocalOrder(
      id: order.id,
      code: order.code,
      status: order.status.name,
      paymentStatus: order.paymentStatus.name,
      paymentType: order.paymentType.name,
      customerId: order.customerId,
      customerName: order.customerName,
      branchId: order.branchId,
      branchName: order.branchName,
      salesManagerId: order.salesManagerId,
      salesManagerName: order.salesManagerName,
      pickerId: order.pickerId,
      pickerName: order.pickerName,
      createdAt: order.createdAt,
      endDate: order.endDate,
      completedAt: order.completedAt,
      backorderedItemsCount: order.backorderedItemsCount,
      totalItems: order.totalItems,
      trolleyId: order.trolleyId,
      notes: order.notes,
      deliveryType: order.deliveryType.name,
      isPostPayment: order.isPostPayment,
      updatedAt: DateTime.now(),
      syncedAt: needsSync ? null : DateTime.now(),
      needsSync: needsSync,
      syncStatus: needsSync ? 'pending' : 'synced',
    );

    await _database.updateOrder(localOrder);
  }

  Future<void> updateOrderDetail(
    OrderDetail order, {
    bool needsSync = true,
  }) async {
    await updateOrder(order, needsSync: needsSync);

    // Update order items
    for (final item in order.items) {
      await updateOrderItem(item, order.id, needsSync: needsSync);
    }
  }

  Future<void> deleteOrder(String id) async {
    await _database.deleteOrder(id);
    // Delete associated order items
    final items = await _database.getOrderItems(id);
    for (final item in items) {
      await _database.deleteOrderItem(item.id);
    }
  }

  Future<List<OrderListItem>> getPendingSyncOrders() async {
    final localOrders = await _database.getPendingSyncOrders();
    return localOrders.map(_mapToOrderListItem).toList();
  }

  // Order Items
  Future<List<OrderItem>> getOrderItems(String orderId) async {
    final localItems = await _database.getOrderItems(orderId);
    return localItems.map(_mapToOrderItem).toList();
  }

  Future<void> insertOrderItem(
    OrderItem item,
    String orderId, {
    bool needsSync = true,
  }) async {
    final localItem = LocalOrderItem(
      id: item.id,
      orderId: orderId,
      productId: item.productId,
      productName: item.productName,
      productSku: item.productSku,
      quantity: item.quantity,
      backorderedQuantity: item.backorderedQuantity,
      status: item.status.name,
      unitPrice: item.unitPrice,
      updatedAt: DateTime.now(),
      syncedAt: needsSync ? null : DateTime.now(),
      needsSync: needsSync,
    );

    await _database.insertOrderItem(localItem);
  }

  Future<void> updateOrderItem(
    OrderItem item,
    String orderId, {
    bool needsSync = true,
  }) async {
    final localItem = LocalOrderItem(
      id: item.id,
      orderId: orderId,
      productId: item.productId,
      productName: item.productName,
      productSku: item.productSku,
      quantity: item.quantity,
      backorderedQuantity: item.backorderedQuantity,
      status: item.status.name,
      unitPrice: item.unitPrice,
      updatedAt: DateTime.now(),
      syncedAt: needsSync ? null : DateTime.now(),
      needsSync: needsSync,
    );

    await _database.updateOrderItem(localItem);
  }

  Future<void> deleteOrderItem(String id) async {
    await _database.deleteOrderItem(id);
  }

  // Products
  Future<List<Product>> getAllProducts() async {
    final localProducts = await _database.getAllProducts();
    return localProducts.map(_mapToProduct).toList();
  }

  Future<List<Product>> searchProducts(String query) async {
    final localProducts = await _database.searchProducts(query);
    return localProducts.map(_mapToProduct).toList();
  }

  Future<void> insertProduct(Product product, {bool needsSync = true}) async {
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
      syncedAt: needsSync ? null : DateTime.now(),
    );

    await _database.insertProduct(localProduct);
  }

  Future<void> updateProduct(Product product, {bool needsSync = true}) async {
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
      syncedAt: needsSync ? null : DateTime.now(),
    );

    await _database.updateProduct(localProduct);
  }

  // Customers
  Future<List<Customer>> getAllCustomers() async {
    final localCustomers = await _database.getAllCustomers();
    return localCustomers.map(_mapToCustomer).toList();
  }

  Future<Customer?> getCustomerById(String id) async {
    final localCustomer = await _database.getCustomerById(id);
    return localCustomer != null ? _mapToCustomer(localCustomer) : null;
  }

  Future<void> insertCustomer(
    Customer customer, {
    bool needsSync = true,
  }) async {
    final localCustomer = LocalCustomer(
      id: customer.id,
      name: customer.name,
      phone: customer.phone,
      email: customer.email,
      updatedAt: DateTime.now(),
      syncedAt: needsSync ? null : DateTime.now(),
    );

    await _database.insertCustomer(localCustomer);
  }

  Future<void> updateCustomer(
    Customer customer, {
    bool needsSync = true,
  }) async {
    final localCustomer = LocalCustomer(
      id: customer.id,
      name: customer.name,
      phone: customer.phone,
      email: customer.email,
      updatedAt: DateTime.now(),
      syncedAt: needsSync ? null : DateTime.now(),
    );

    await _database.updateCustomer(localCustomer);
  }

  // Users
  Future<List<AuthenticatedUser>> getAllUsers() async {
    final localUsers = await _database.getAllUsers();
    return localUsers.map(_mapToUser).toList();
  }

  Future<AuthenticatedUser?> getUserById(String id) async {
    final localUser = await _database.getUserById(id);
    return localUser != null ? _mapToUser(localUser) : null;
  }

  Future<void> insertUser(
    AuthenticatedUser user, {
    bool needsSync = true,
  }) async {
    final localUser = LocalUser(
      id: user.id,
      username: user.username,
      name: user.name,
      email: user.email,
      role: user.role.name,
      isActive: user.isActive,
      branchId: user.branchId,
      updatedAt: DateTime.now(),
      syncedAt: needsSync ? null : DateTime.now(),
    );

    await _database.insertUser(localUser);
  }

  Future<void> updateUser(
    AuthenticatedUser user, {
    bool needsSync = true,
  }) async {
    final localUser = LocalUser(
      id: user.id,
      username: user.username,
      name: user.name,
      email: user.email,
      role: user.role.name,
      isActive: user.isActive,
      branchId: user.branchId,
      updatedAt: DateTime.now(),
      syncedAt: needsSync ? null : DateTime.now(),
    );

    await _database.updateUser(localUser);
  }

  // Sync Queue
  Future<List<SyncOperationModel>> getPendingSyncOperations() async {
    final ops = await _database.getPendingSyncOperations();
    return ops.map(SyncOperationModel.fromDatabase).toList();
  }

  Future<List<SyncOperationModel>> getFailedSyncOperations() async {
    final ops = await _database.getFailedSyncOperations();
    return ops.map(SyncOperationModel.fromDatabase).toList();
  }

  Future<void> insertSyncOperation(SyncOperationModel operation) async {
    await _database.insertSyncOperation(operation.toDatabase());
  }

  Future<void> updateSyncOperation(SyncOperationModel operation) async {
    await _database.updateSyncOperation(operation.toDatabase());
  }

  Future<void> deleteSyncOperation(int id) async {
    await _database.deleteSyncOperation(id);
  }

  // Settings
  Future<String?> getSetting(String key) async {
    return await _database.getSettingValue(key);
  }

  Future<void> setSetting(String key, String value) async {
    await _database.setSettingValue(key, value);
  }

  // Audit Logs
  Future<List<AuditLog>> getAuditLogs(String orderId) async {
    final localLogs = await _database.getAuditLogs(orderId);
    return localLogs.map(_mapToAuditLog).toList();
  }

  Future<void> insertAuditLog(AuditLog log) async {
    final localLog = LocalAuditLog(
      id: 0, // Auto-increment
      orderId: log.id, // Use id as orderId for relationship
      action: log.action,
      fromStatus: log.fromStatus,
      toStatus: log.toStatus,
      performedById: log.performedById,
      performedByName: log.performedByName,
      notes: log.notes,
      metadata: log.metadata != null ? jsonEncode(log.metadata) : null,
      createdAt: log.createdAt,
      syncedAt: DateTime.now(),
    );

    await _database.insertAuditLog(localLog);
  }

  // Mapping functions
  OrderListItem _mapToOrderListItem(LocalOrder local) {
    return OrderListItem(
      id: local.id,
      code: local.code,
      status: OrderStatus.fromRaw(local.status),
      paymentStatus: PaymentStatus.fromRaw(local.paymentStatus),
      paymentType: PaymentType.fromRaw(local.paymentType),
      customerId: local.customerId,
      customerName: local.customerName,
      branchId: local.branchId,
      branchName: local.branchName,
      salesManagerId: local.salesManagerId,
      salesManagerName: local.salesManagerName,
      pickerId: local.pickerId,
      pickerName: local.pickerName,
      createdAt: local.createdAt,
      endDate: local.endDate,
      completedAt: local.completedAt,
      backorderedItemsCount: local.backorderedItemsCount,
      totalItems: local.totalItems,
      trolleyId: local.trolleyId,
      notes: local.notes,
      deliveryType: DeliveryType.fromRaw(local.deliveryType),
      isPostPayment: local.isPostPayment,
    );
  }

  OrderItem _mapToOrderItem(LocalOrderItem local) {
    return OrderItem(
      id: local.id,
      productId: local.productId,
      productName: local.productName,
      productSku: local.productSku,
      quantity: local.quantity,
      backorderedQuantity: local.backorderedQuantity,
      status: ItemStatus.fromRaw(local.status),
      unitPrice: local.unitPrice,
    );
  }

  Product _mapToProduct(LocalProduct local) {
    return Product(
      id: local.id,
      sku: local.sku,
      name: local.name,
      barcode: local.barcode,
      unit: local.unit,
      brand: local.brand,
      price: local.price,
      isActive: local.isActive,
    );
  }

  Customer _mapToCustomer(LocalCustomer local) {
    return Customer(
      id: local.id,
      name: local.name,
      phone: local.phone,
      email: local.email,
    );
  }

  AuthenticatedUser _mapToUser(LocalUser local) {
    return AuthenticatedUser(
      id: local.id,
      username: local.username,
      name: local.name,
      email: local.email,
      role: UserRole.values.firstWhere(
        (r) => r.name == local.role,
        orElse: () => UserRole.BASIC,
      ),
      isActive: local.isActive,
      branchId: local.branchId,
    );
  }

  AuditLog _mapToAuditLog(LocalAuditLog local) {
    return AuditLog(
      id: local.id.toString(),
      action: local.action,
      fromStatus: local.fromStatus,
      toStatus: local.toStatus,
      performedById: local.performedById,
      performedByName: local.performedByName,
      notes: local.notes,
      metadata: local.metadata != null
          ? jsonDecode(local.metadata!) as Map<String, dynamic>
          : null,
      createdAt: local.createdAt,
    );
  }
}
