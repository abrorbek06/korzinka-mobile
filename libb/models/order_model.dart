import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../theme/app_theme.dart';

int _parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

String _normalizeEnumString(dynamic value) {
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

  return parseString(value)?.toUpperCase() ?? '';
}

// ─── Enums ───────────────────────────────────────────────────────────────────

enum OrderStatus {
  DRAFT,
  CONFIRMED,
  IN_COLLECTION,
  PARTIAL,
  READY,
  COMPLETED,
  CANCELLED;

  String get uzName {
    switch (this) {
      case DRAFT:
        return AppStrings.statusDraft;
      case CONFIRMED:
        return AppStrings.statusConfirmed;
      case IN_COLLECTION:
        return AppStrings.statusInCollection;
      case PARTIAL:
        return AppStrings.statusPartial;
      case READY:
        return AppStrings.statusReady;
      case COMPLETED:
        return AppStrings.statusCompleted;
      case CANCELLED:
        return AppStrings.statusCancelled;
    }
  }

  Color get color {
    switch (this) {
      case DRAFT:
        return AppColors.yangiColor;
      case CONFIRMED:
        return AppColors.tasdiqColor;
      case IN_COLLECTION:
        return AppColors.yigColor;
      case PARTIAL:
        return AppColors.qismanColor;
      case READY:
        return AppColors.tayyorColor;
      case COMPLETED:
        return AppColors.yakunColor;
      case CANCELLED:
        return AppColors.bekorColor;
    }
  }

  Color get lightColor {
    switch (this) {
      case DRAFT:
        return const Color(0xFFDCFCE7);
      case CONFIRMED:
        return const Color(0xFFDBEAFE);
      case IN_COLLECTION:
        return AppColors.primaryLight;
      case PARTIAL:
        return const Color(0xFFFEF9C3);
      case READY:
        return const Color(0xFFD1FAE5);
      case COMPLETED:
        return const Color(0xFFF1F5F9);
      case CANCELLED:
        return const Color(0xFFFEE2E2);
    }
  }

  bool get isPickerRelevant =>
      this == IN_COLLECTION || this == PARTIAL || this == READY;
}

enum PaymentStatus {
  PAID,
  UNPAID;

  String get uzName => this == PAID ? 'To\'langan' : 'To\'lanmagan';
  Color get color =>
      this == PAID ? AppColors.yangiColor : AppColors.qismanColor;
}

enum ItemStatus {
  AVAILABLE,
  BACKORDERED;

  String get uzName => this == AVAILABLE ? 'Mavjud' : 'Kutilmoqda';
}

// ─── Collected qty helper (local state) ──────────────────────────────────────

class CollectedItem {
  final String itemId;
  int collected;

  CollectedItem({required this.itemId, required this.collected});
}

// ─── Models ──────────────────────────────────────────────────────────────────

class OrderProduct {
  final String id;
  final String productId;
  final String productName;
  final String? productSku;
  final String? imageUrl;
  final int requiredQty;
  final String unit; // 'dona', 'kg', etc.
  final int? backorderedQuantity;
  final ItemStatus status;

  const OrderProduct({
    required this.id,
    required this.productId,
    required this.productName,
    this.productSku,
    this.imageUrl,
    required this.requiredQty,
    this.unit = 'dona',
    this.backorderedQuantity,
    required this.status,
  });

  factory OrderProduct.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>?;
    final statusRaw = _normalizeEnumString(json['status']);
    final quantity = _parseInt(json['quantity']);

    // Parse product name — handle both bilingual { uz, ru } and flat string formats
    String productName = 'Mahsulot';
    if (product != null) {
      final name = product['name'];
      if (name is Map) {
        // Bilingual format: { uz, ru }
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

        productName =
            parseString(name['uz']) ?? parseString(name['ru']) ?? 'Mahsulot';
      } else if (name is String) {
        // Flat string format
        productName = name;
      }
    }
    // Fallback to flat field
    if (productName == 'Mahsulot') {
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

      final flatName = parseString(json['productName']);
      if (flatName != null && flatName.isNotEmpty) {
        productName = flatName;
      }
    }

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

    return OrderProduct(
      id: json['id']?.toString() ?? '',
      productId:
          parseString(product?['id']) ?? parseString(json['productId']) ?? '',
      productName: productName,
      productSku: parseString(product?['sku']) ?? parseString(json['sku']),
      imageUrl: parseString(product?['imageUrl']),
      requiredQty: quantity > 0 ? quantity : 1,
      unit: parseString(json['unit']) ?? 'dona',
      backorderedQuantity: json['backorderedQuantity'] != null
          ? _parseInt(json['backorderedQuantity'])
          : null,
      status: ItemStatus.values.firstWhere(
        (s) => s.name == statusRaw,
        orElse: () => ItemStatus.AVAILABLE,
      ),
    );
  }
}

/// Trimmed list item
class OrderSummary {
  final String id;
  final String? code;
  final OrderStatus status;
  final PaymentStatus paymentStatus;
  final String? customerName;
  final String? salesManagerName;
  final DateTime createdAt;
  final DateTime? endDate;
  final int totalItems;
  final int backorderedCount;

  const OrderSummary({
    required this.id,
    this.code,
    required this.status,
    required this.paymentStatus,
    this.customerName,
    this.salesManagerName,
    required this.createdAt,
    this.endDate,
    required this.totalItems,
    required this.backorderedCount,
  });

  factory OrderSummary.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>?;
    final sm = json['salesManager'] as Map<String, dynamic>?;
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

    return OrderSummary(
      id: json['id']?.toString() ?? '',
      code: parseString(json['code']),
      status: OrderStatus.values.firstWhere(
        (s) => s.name == _normalizeEnumString(json['status']),
        orElse: () => OrderStatus.DRAFT,
      ),
      paymentStatus: PaymentStatus.values.firstWhere(
        (s) => s.name == _normalizeEnumString(json['paymentStatus']),
        orElse: () => PaymentStatus.UNPAID,
      ),
      customerName:
          parseString(customer?['name']) ??
          parseString(customer?['companyName']),
      salesManagerName: parseString(sm?['username']),
      createdAt: json['createdAt'] is String
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.fromMillisecondsSinceEpoch(_parseInt(json['createdAt'])),
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
      totalItems: _parseInt(json['totalItems']),
      backorderedCount: _parseInt(json['backorderedItemsCount']),
    );
  }
}

/// Full order detail
class OrderDetail extends OrderSummary {
  final List<OrderProduct> products;
  final String? customerPhone;

  const OrderDetail({
    required super.id,
    super.code,
    required super.status,
    required super.paymentStatus,
    super.customerName,
    super.salesManagerName,
    required super.createdAt,
    super.endDate,
    required super.totalItems,
    required super.backorderedCount,
    required this.products,
    this.customerPhone,
  });

  factory OrderDetail.fromJson(Map<String, dynamic> json) {
    final base = OrderSummary.fromJson(json);
    final customer = json['customer'] as Map<String, dynamic>?;
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final products = rawItems
        .map((j) => OrderProduct.fromJson(j as Map<String, dynamic>))
        .toList();

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

    return OrderDetail(
      id: base.id,
      code: base.code,
      status: base.status,
      paymentStatus: base.paymentStatus,
      customerName: base.customerName,
      salesManagerName: base.salesManagerName,
      createdAt: base.createdAt,
      endDate: base.endDate,
      totalItems: products.length,
      backorderedCount: products
          .where((p) => p.status == ItemStatus.BACKORDERED)
          .length,
      products: products,
      customerPhone: parseString(customer?['phone']),
    );
  }
}
