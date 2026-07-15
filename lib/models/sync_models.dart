import 'dart:convert';
import 'package:korzinkab_mobile/database/app_database.dart';

enum SyncOperationType {
  create,
  update,
  delete,
  transition,
  attachCart,
  detachCart,
  markPaid,
  unmarkPaid,
  updateItem,
}

enum SyncEntityType { order, orderItem, customer, product, user, auditLog }

enum SyncStatus { pending, syncing, success, failed }

extension SyncOperationTypeExtension on SyncOperationType {
  String get value {
    switch (this) {
      case SyncOperationType.create:
        return 'create';
      case SyncOperationType.update:
        return 'update';
      case SyncOperationType.delete:
        return 'delete';
      case SyncOperationType.transition:
        return 'transition';
      case SyncOperationType.attachCart:
        return 'attach_cart';
      case SyncOperationType.detachCart:
        return 'detach_cart';
      case SyncOperationType.markPaid:
        return 'mark_paid';
      case SyncOperationType.unmarkPaid:
        return 'unmark_paid';
      case SyncOperationType.updateItem:
        return 'update_item';
    }
  }

  static SyncOperationType fromString(String value) {
    return SyncOperationType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => SyncOperationType.update,
    );
  }
}

extension SyncEntityTypeExtension on SyncEntityType {
  String get value {
    switch (this) {
      case SyncEntityType.order:
        return 'order';
      case SyncEntityType.orderItem:
        return 'order_item';
      case SyncEntityType.customer:
        return 'customer';
      case SyncEntityType.product:
        return 'product';
      case SyncEntityType.user:
        return 'user';
      case SyncEntityType.auditLog:
        return 'audit_log';
    }
  }

  static SyncEntityType fromString(String value) {
    return SyncEntityType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => SyncEntityType.order,
    );
  }
}

extension SyncStatusExtension on SyncStatus {
  String get value {
    switch (this) {
      case SyncStatus.pending:
        return 'pending';
      case SyncStatus.syncing:
        return 'syncing';
      case SyncStatus.success:
        return 'success';
      case SyncStatus.failed:
        return 'failed';
    }
  }

  static SyncStatus fromString(String value) {
    return SyncStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => SyncStatus.pending,
    );
  }
}

class SyncOperationModel {
  final int? id;
  final SyncOperationType operationType;
  final SyncEntityType entityType;
  final String entityId;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final DateTime? attemptedAt;
  final int retryCount;
  final SyncStatus syncStatus;
  final String? errorMessage;
  final DateTime? syncedAt;

  SyncOperationModel({
    this.id,
    required this.operationType,
    required this.entityType,
    required this.entityId,
    required this.payload,
    required this.createdAt,
    this.attemptedAt,
    this.retryCount = 0,
    this.syncStatus = SyncStatus.pending,
    this.errorMessage,
    this.syncedAt,
  });

  factory SyncOperationModel.fromDatabase(SyncOperation dbOp) {
    return SyncOperationModel(
      id: dbOp.id,
      operationType: SyncOperationTypeExtension.fromString(dbOp.operationType),
      entityType: SyncEntityTypeExtension.fromString(dbOp.entityType),
      entityId: dbOp.entityId,
      payload: jsonDecode(dbOp.payload) as Map<String, dynamic>,
      createdAt: dbOp.createdAt,
      attemptedAt: dbOp.attemptedAt,
      retryCount: dbOp.retryCount,
      syncStatus: SyncStatusExtension.fromString(dbOp.syncStatus),
      errorMessage: dbOp.errorMessage,
      syncedAt: dbOp.syncedAt,
    );
  }

  SyncOperation toDatabase() {
    return SyncOperation(
      id: id ?? 0, // Auto-increment fields need a value, database will override
      operationType: operationType.value,
      entityType: entityType.value,
      entityId: entityId,
      payload: jsonEncode(payload),
      createdAt: createdAt,
      attemptedAt: attemptedAt,
      retryCount: retryCount,
      syncStatus: syncStatus.value,
      errorMessage: errorMessage,
      syncedAt: syncedAt,
    );
  }

  SyncOperationModel copyWith({
    int? id,
    SyncOperationType? operationType,
    SyncEntityType? entityType,
    String? entityId,
    Map<String, dynamic>? payload,
    DateTime? createdAt,
    DateTime? attemptedAt,
    int? retryCount,
    SyncStatus? syncStatus,
    String? errorMessage,
    DateTime? syncedAt,
  }) {
    return SyncOperationModel(
      id: id ?? this.id,
      operationType: operationType ?? this.operationType,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      attemptedAt: attemptedAt ?? this.attemptedAt,
      retryCount: retryCount ?? this.retryCount,
      syncStatus: syncStatus ?? this.syncStatus,
      errorMessage: errorMessage ?? this.errorMessage,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  bool get canRetry {
    return syncStatus == SyncStatus.failed && retryCount < 10;
  }

  Duration get timeSinceCreation {
    return DateTime.now().difference(createdAt);
  }

  Duration? get timeSinceLastAttempt {
    if (attemptedAt == null) return null;
    return DateTime.now().difference(attemptedAt!);
  }
}
