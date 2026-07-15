import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

@DataClassName('LocalOrder')
class Orders extends Table {
  TextColumn get id => text()();
  TextColumn get code => text().nullable()();
  TextColumn get status => text()();
  TextColumn get paymentStatus => text()();
  TextColumn get paymentType => text()();
  TextColumn get customerId => text().nullable()();
  TextColumn get customerName => text().nullable()();
  TextColumn get branchId => text().nullable()();
  TextColumn get branchName => text().nullable()();
  TextColumn get salesManagerId => text().nullable()();
  TextColumn get salesManagerName => text().nullable()();
  TextColumn get pickerId => text().nullable()();
  TextColumn get pickerName => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get backorderedItemsCount =>
      integer().withDefault(const Constant(0))();
  IntColumn get totalItems => integer().withDefault(const Constant(0))();
  TextColumn get trolleyId => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get deliveryType => text()();
  BoolColumn get isPostPayment =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  BoolColumn get needsSync => boolean().withDefault(const Constant(false))();
  TextColumn get syncStatus =>
      text().withDefault(const Constant('synced'))(); // synced, pending, failed

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalOrderItem')
class OrderItems extends Table {
  TextColumn get id => text()();
  TextColumn get orderId => text()();
  TextColumn get productId => text()();
  TextColumn get productName => text()();
  TextColumn get productSku => text().nullable()();
  IntColumn get quantity => integer()();
  IntColumn get backorderedQuantity => integer().nullable()();
  TextColumn get status => text()();
  RealColumn get unitPrice => real()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  BoolColumn get needsSync => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>>? get uniqueKeys => [
    {orderId, productId},
  ];
}

@DataClassName('LocalProduct')
class Products extends Table {
  TextColumn get id => text()();
  TextColumn get sku => text()();
  TextColumn get name => text()();
  TextColumn get barcode => text().nullable()();
  TextColumn get unit => text().nullable()();
  TextColumn get brand => text().nullable()();
  IntColumn get price => integer().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalCustomer')
class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalUser')
class Users extends Table {
  TextColumn get id => text()();
  TextColumn get username => text()();
  TextColumn get name => text()();
  TextColumn get email => text().nullable()();
  TextColumn get role => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get branchId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SyncOperation')
class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get operationType =>
      text()(); // create, update, delete, transition
  TextColumn get entityType => text()(); // order, order_item, customer, etc.
  TextColumn get entityId => text()();
  TextColumn get payload => text()(); // JSON string
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get attemptedAt => dateTime().nullable()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get syncStatus => text().withDefault(
    const Constant('pending'),
  )(); // pending, syncing, success, failed
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
}

@DataClassName('LocalSetting')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

@DataClassName('LocalAuditLog')
class AuditLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get orderId => text()(); // Relationship to order
  TextColumn get action => text()();
  TextColumn get fromStatus => text().nullable()();
  TextColumn get toStatus => text().nullable()();
  TextColumn get performedById => text().nullable()();
  TextColumn get performedByName => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get metadata => text().nullable()(); // JSON string
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
}

@DriftDatabase(
  tables: [
    Orders,
    OrderItems,
    Products,
    Customers,
    Users,
    SyncQueue,
    Settings,
    AuditLogs,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Add future migrations here
      },
    );
  }

  // Orders queries
  Future<List<LocalOrder>> getAllOrders() => select(orders).get();

  Future<List<LocalOrder>> getOrdersByStatus(String status) =>
      (select(orders)..where((tbl) => tbl.status.equals(status))).get();

  Future<LocalOrder?> getOrderById(String id) =>
      (select(orders)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Future<List<LocalOrder>> getPendingSyncOrders() =>
      (select(orders)..where((tbl) => tbl.needsSync.equals(true))).get();

  Future<int> insertOrder(LocalOrder order) => into(orders).insert(order);

  Future<bool> updateOrder(LocalOrder order) => update(orders).replace(order);

  Future<int> deleteOrder(String id) =>
      (delete(orders)..where((tbl) => tbl.id.equals(id))).go();

  // Order items queries
  Future<List<LocalOrderItem>> getOrderItems(String orderId) =>
      (select(orderItems)..where((tbl) => tbl.orderId.equals(orderId))).get();

  Future<int> insertOrderItem(LocalOrderItem item) =>
      into(orderItems).insert(item);

  Future<bool> updateOrderItem(LocalOrderItem item) =>
      update(orderItems).replace(item);

  Future<int> deleteOrderItem(String id) =>
      (delete(orderItems)..where((tbl) => tbl.id.equals(id))).go();

  // Products queries
  Future<List<LocalProduct>> getAllProducts() => select(products).get();

  Future<List<LocalProduct>> searchProducts(String query) => (select(
    products,
  )..where((tbl) => tbl.name.contains(query) | tbl.sku.contains(query))).get();

  Future<int> insertProduct(LocalProduct product) =>
      into(products).insert(product);

  Future<bool> updateProduct(LocalProduct product) =>
      update(products).replace(product);

  // Customers queries
  Future<List<LocalCustomer>> getAllCustomers() => select(customers).get();

  Future<LocalCustomer?> getCustomerById(String id) =>
      (select(customers)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Future<int> insertCustomer(LocalCustomer customer) =>
      into(customers).insert(customer);

  Future<bool> updateCustomer(LocalCustomer customer) =>
      update(customers).replace(customer);

  // Users queries
  Future<List<LocalUser>> getAllUsers() => select(users).get();

  Future<LocalUser?> getUserById(String id) =>
      (select(users)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Future<int> insertUser(LocalUser user) => into(users).insert(user);

  Future<bool> updateUser(LocalUser user) => update(users).replace(user);

  // Sync queue queries
  Future<List<SyncOperation>> getPendingSyncOperations() =>
      (select(syncQueue)
            ..where((tbl) => tbl.syncStatus.equals('pending'))
            ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]))
          .get();

  Future<List<SyncOperation>> getFailedSyncOperations() =>
      (select(syncQueue)
            ..where((tbl) => tbl.syncStatus.equals('failed'))
            ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]))
          .get();

  Future<int> insertSyncOperation(SyncOperation operation) =>
      into(syncQueue).insert(operation);

  Future<bool> updateSyncOperation(SyncOperation operation) =>
      update(syncQueue).replace(operation);

  Future<int> deleteSyncOperation(int id) =>
      (delete(syncQueue)..where((tbl) => tbl.id.equals(id))).go();

  Future<int> clearPendingSyncOperations() => (delete(
    syncQueue,
  )..where((tbl) => tbl.syncStatus.equals('success'))).go();

  // Settings queries
  Future<LocalSetting?> getSetting(String key) =>
      (select(settings)..where((tbl) => tbl.key.equals(key))).getSingleOrNull();

  Future<int> insertSetting(LocalSetting setting) =>
      into(settings).insert(setting);

  Future<bool> updateSetting(LocalSetting setting) =>
      update(settings).replace(setting);

  Future<String?> getSettingValue(String key) async {
    final setting = await getSetting(key);
    return setting?.value;
  }

  Future<void> setSettingValue(String key, String value) async {
    final existing = await getSetting(key);
    final now = DateTime.now();
    if (existing != null) {
      await updateSetting(LocalSetting(key: key, value: value, updatedAt: now));
    } else {
      await insertSetting(LocalSetting(key: key, value: value, updatedAt: now));
    }
  }

  // Audit logs queries
  Future<List<LocalAuditLog>> getAuditLogs(String orderId) =>
      (select(auditLogs)
            ..where((tbl) => tbl.orderId.equals(orderId))
            ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
          .get();

  Future<int> insertAuditLog(LocalAuditLog log) => into(auditLogs).insert(log);
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'korzinka.db'));

    // Enable foreign keys and WAL mode for better performance
    if (!await file.exists()) {
      // Create database with optimizations
    }

    return NativeDatabase.createInBackground(file);
  });
}

final database = AppDatabase(_openConnection());
