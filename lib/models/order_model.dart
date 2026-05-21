import 'package:flutter/material.dart';

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

String? _nestedTrolley(Map<String, dynamic> json) {
  final trolley = json['trolley'];
  if (trolley is Map<String, dynamic>) {
    return parseString(trolley['id']) ?? parseString(trolley['trolleyId']);
  }
  return null;
}

// ─── Enums ──────────────────────────────────────────────────────────────────

enum OrderStatus {
  DRAFT,
  CONFIRMED,
  IN_COLLECTION,
  PARTIAL,
  READY,
  COMPLETED,
  CANCELLED;

  static OrderStatus fromRaw(String? raw) {
    final normalized = raw
        ?.trim()
        .replaceAll(RegExp(r'[\s-]+'), '_')
        .toUpperCase();
    return OrderStatus.values.firstWhere(
      (s) => s.name == normalized,
      orElse: () => OrderStatus.DRAFT,
    );
  }

  String get displayName {
    switch (this) {
      case DRAFT:
        return 'Draft';
      case CONFIRMED:
        return 'Confirmed';
      case IN_COLLECTION:
        return 'In Collection';
      case PARTIAL:
        return 'Partial';
      case READY:
        return 'Ready';
      case COMPLETED:
        return 'Completed';
      case CANCELLED:
        return 'Cancelled';
    }
  }

  String get displayNameUz {
    switch (this) {
      case DRAFT:
        return "Yangi";
      case CONFIRMED:
        return "Tasdiqlangan";
      case IN_COLLECTION:
        return "Yig'ilmoqda";
      case PARTIAL:
        return "Qisman";
      case READY:
        return "Tayyor";
      case COMPLETED:
        return "Yakunlangan";
      case CANCELLED:
        return "Bekor qilingan";
    }
  }

  Color get color {
    switch (this) {
      case DRAFT:
        return const Color(0xFF78909C);
      case CONFIRMED:
        return const Color(0xFF1E88E5);
      case IN_COLLECTION:
        return const Color(0xFFF57C00);
      case PARTIAL:
        return const Color(0xFFFBC02D);
      case READY:
        return const Color(0xFF43A047);
      case COMPLETED:
        return const Color(0xFF00897B);
      case CANCELLED:
        return const Color(0xFFE53935);
    }
  }

  Color get lightColor {
    switch (this) {
      case DRAFT:
        return const Color(0xFFECEFF1);
      case CONFIRMED:
        return const Color(0xFFE3F2FD);
      case IN_COLLECTION:
        return const Color(0xFFFFF3E0);
      case PARTIAL:
        return const Color(0xFFFFFDE7);
      case READY:
        return const Color(0xFFE8F5E9);
      case COMPLETED:
        return const Color(0xFFE0F2F1);
      case CANCELLED:
        return const Color(0xFFFFEBEE);
    }
  }

  IconData get icon {
    switch (this) {
      case DRAFT:
        return Icons.edit_outlined;
      case CONFIRMED:
        return Icons.check_circle_outline;
      case IN_COLLECTION:
        return Icons.local_shipping_outlined;
      case PARTIAL:
        return Icons.hourglass_bottom_outlined;
      case READY:
        return Icons.inventory_2_outlined;
      case COMPLETED:
        return Icons.task_alt;
      case CANCELLED:
        return Icons.cancel_outlined;
    }
  }
}

enum PaymentStatus {
  PAID,
  UNPAID;

  static PaymentStatus fromRaw(String? raw) {
    final normalized = raw
        ?.trim()
        .replaceAll(RegExp(r'[\s-]+'), '_')
        .toUpperCase();
    return PaymentStatus.values.firstWhere(
      (s) => s.name == normalized,
      orElse: () => PaymentStatus.UNPAID,
    );
  }

  String get displayName => name[0] + name.substring(1).toLowerCase();

  Color get color =>
      this == PAID ? const Color(0xFF43A047) : const Color(0xFFF57C00);
}

enum PaymentType {
  BANK,
  CASH,
  CARD;

  static PaymentType fromRaw(String? raw) {
    final normalized = raw
        ?.trim()
        .replaceAll(RegExp(r'[\s-]+'), '_')
        .toUpperCase();
    if (normalized == 'BANK_PREPAYMENT' || normalized == 'BANK_POST_PAYMENT') {
      return PaymentType.BANK;
    }
    return PaymentType.values.firstWhere(
      (t) => t.name == normalized,
      orElse: () => PaymentType.CASH,
    );
  }

  String get displayName => name[0] + name.substring(1).toLowerCase();

  IconData get icon {
    switch (this) {
      case BANK:
        return Icons.account_balance_outlined;
      case CASH:
        return Icons.payments_outlined;
      case CARD:
        return Icons.credit_card_outlined;
    }
  }
}

enum ItemStatus {
  AVAILABLE,
  BACKORDERED;

  static ItemStatus fromRaw(String? raw) {
    final normalized = raw
        ?.trim()
        .replaceAll(RegExp(r'[\s-]+'), '_')
        .toUpperCase();
    return ItemStatus.values.firstWhere(
      (s) => s.name == normalized,
      orElse: () => ItemStatus.AVAILABLE,
    );
  }

  String get displayName => name[0] + name.substring(1).toLowerCase();
  Color get color =>
      this == AVAILABLE ? const Color(0xFF43A047) : const Color(0xFFF57C00);
}

// ─── Models ─────────────────────────────────────────────────────────────────

class OrderItem {
  final String id;
  final String productId;
  final String productName;
  final String? productSku;
  final int quantity;
  final int? backorderedQuantity;
  final ItemStatus status;
  final double unitPrice;

  const OrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    this.productSku,
    required this.quantity,
    this.backorderedQuantity,
    required this.status,
    required this.unitPrice,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>?;

    // Handle productName being either a string or a list
    String productName = 'Unknown';
    final rawProductName = json['productName'];
    if (rawProductName is String) {
      productName = rawProductName;
    } else if (rawProductName is List && rawProductName.isNotEmpty) {
      productName = rawProductName.first.toString();
    }

    String? resolveName(dynamic rawName) {
      if (rawName == null) return null;
      if (rawName is String) {
        final trimmed = rawName.trim();
        return trimmed.isEmpty ? null : trimmed;
      }
      if (rawName is List && rawName.isNotEmpty) {
        return resolveName(rawName.first);
      }
      if (rawName is Map<String, dynamic>) {
        final uz = resolveName(rawName['uz']);
        final ru = resolveName(rawName['ru']);
        return uz ?? ru;
      }
      return rawName.toString().trim().isEmpty ? null : rawName.toString();
    }

    if (product != null) {
      final productNameCandidate =
          resolveName(product['name']) ??
          resolveName(product['productName']) ??
          resolveName(product['title']);
      if (productNameCandidate != null) {
        productName = productNameCandidate;
      }
    }

    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        return int.tryParse(value) ?? double.tryParse(value)?.toInt() ?? 0;
      }
      return 0;
    }

    int? parseNullableInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        return int.tryParse(value) ?? double.tryParse(value)?.toInt();
      }
      return null;
    }

    double parseDouble(dynamic value) {
      if (value is double) return value;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return OrderItem(
      id: json['id']?.toString() ?? '',
      productId: json['productId']?.toString() ?? '',
      productName: productName,
      productSku: product?['sku']?.toString(),
      quantity: parseInt(json['quantity']),
      backorderedQuantity: parseNullableInt(json['backorderedQuantity']),
      status: ItemStatus.fromRaw(json['status']?.toString()),
      unitPrice: parseDouble(json['unitPrice']),
    );
  }
}

class Customer {
  final String id;
  final String name;
  final String? phone;
  final String? email;

  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.email,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    // Handle fields being either a string or a list
    String? parseStringField(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        final trimmed = value.trim();
        return trimmed.isEmpty ? null : trimmed;
      }
      if (value is List && value.isNotEmpty) {
        return value.first.toString();
      }
      return value.toString();
    }

    return Customer(
      id: parseStringField(json['id']) ?? '',
      name:
          parseStringField(json['name']) ??
          parseStringField(json['companyName']) ??
          'Unknown',
      phone: parseStringField(json['phone']),
      email: parseStringField(json['email']),
    );
  }
}

class Picker {
  final String id;
  final String username;

  const Picker({required this.id, required this.username});

  factory Picker.fromJson(Map<String, dynamic> json) {
    // Handle id and username being either a string or a list
    String idString;
    final id = json['id'];
    if (id is String) {
      idString = id;
    } else if (id is List && id.isNotEmpty) {
      idString = id.first.toString();
    } else {
      idString = '';
    }

    String usernameString;
    final username = json['username'];
    if (username is String) {
      usernameString = username;
    } else if (username is List && username.isNotEmpty) {
      usernameString = username.first.toString();
    } else {
      usernameString = '';
    }

    return Picker(id: idString, username: usernameString);
  }
}

/// Trimmed DTO used in the Kanban feed
class OrderListItem {
  final String id;
  final String? code;
  final OrderStatus status;
  final PaymentStatus paymentStatus;
  final PaymentType paymentType;
  final String? customerId;
  final String? customerName;
  final String? branchId;
  final String? branchName;
  final String? salesManagerId;
  final String? salesManagerName;
  final String? pickerId;
  final String? pickerName;
  final DateTime createdAt;
  final DateTime? endDate;
  final int backorderedItemsCount;
  final int totalItems;
  final String? trolleyId;
  final String? notes;

  const OrderListItem({
    required this.id,
    this.code,
    required this.status,
    required this.paymentStatus,
    required this.paymentType,
    this.customerId,
    this.customerName,
    this.branchId,
    this.branchName,
    this.salesManagerId,
    this.salesManagerName,
    this.pickerId,
    this.pickerName,
    required this.createdAt,
    this.endDate,
    required this.backorderedItemsCount,
    required this.totalItems,
    this.trolleyId,
    this.notes,
  });

  factory OrderListItem.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>?;
    final branch = json['branch'] as Map<String, dynamic>?;
    final salesManager = json['salesManager'] as Map<String, dynamic>?;
    final picker = json['picker'] as Map<String, dynamic>?;

    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        return int.tryParse(value) ?? double.tryParse(value)?.toInt();
      }
      return null;
    }

    dynamic resolveItems(dynamic raw) {
      if (raw is List) return raw;
      if (raw is Map<String, dynamic>) {
        return raw['data'] ?? raw['items'] ?? raw['orderItems'] ?? raw['order_items'];
      }
      return null;
    }

    final itemsList = resolveItems(json['items'] ?? json['orderItems'] ?? json['order_items']);
    final inferredTotalItems = itemsList is List
        ? itemsList.length
        : parseInt(json['totalItems']) ??
            parseInt(json['itemsCount']) ??
            parseInt(json['items_count']) ??
            parseInt(json['productCount']) ??
            parseInt(json['product_count']) ??
            0;

    return OrderListItem(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString(),
      status: OrderStatus.fromRaw(json['status']?.toString()),
      paymentStatus: PaymentStatus.fromRaw(json['paymentStatus']?.toString()),
      paymentType: PaymentType.fromRaw(json['paymentType']?.toString()),
      customerId: customer?['id']?.toString(),
      customerName:
          customer?['name']?.toString() ?? customer?['companyName']?.toString(),
      branchId: branch?['id']?.toString(),
      branchName: branch?['name']?.toString() ?? branch?['code']?.toString(),
      salesManagerId: salesManager?['id']?.toString(),
      salesManagerName:
          salesManager?['username']?.toString() ??
          salesManager?['name']?.toString(),
      pickerId: picker?['id']?.toString(),
      pickerName:
          picker?['name']?.toString() ?? picker?['username']?.toString(),
      createdAt: DateTime.parse(
        json['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
      ),
      endDate: json['endDate'] != null
          ? DateTime.parse(
              json['endDate']?.toString() ?? DateTime.now().toIso8601String(),
            )
          : null,
      backorderedItemsCount: json['backorderedItemsCount'] as int? ?? 0,
      totalItems: inferredTotalItems,
      trolleyId: parseString(json['trolleyId']) ?? _nestedTrolley(json),
      notes: json['notes']?.toString(),
    );
  }
}

/// Full order detail
class OrderDetail extends OrderListItem {
  final List<OrderItem> items;
  final Customer? customer;
  final Picker? picker;
  final DateTime? completedAt;

  const OrderDetail({
    required super.id,
    super.code,
    required super.status,
    required super.paymentStatus,
    required super.paymentType,
    super.customerId,
    super.customerName,
    super.branchId,
    super.branchName,
    super.salesManagerId,
    super.salesManagerName,
    super.pickerId,
    super.pickerName,
    required super.createdAt,
    super.endDate,
    required super.backorderedItemsCount,
    required super.totalItems,
    super.trolleyId,
    super.notes,
    required this.items,
    this.customer,
    this.picker,
    this.completedAt,
  });

  factory OrderDetail.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>?;
    final branch = json['branch'] as Map<String, dynamic>?;
    final salesManager = json['salesManager'] as Map<String, dynamic>?;
    final picker = json['picker'] as Map<String, dynamic>?;

    dynamic resolveItems(dynamic raw) {
      if (raw is List) return raw;
      if (raw is Map<String, dynamic>) {
        return raw['data'] ?? raw['items'] ?? raw['orderItems'] ?? raw['order_items'];
      }
      return null;
    }

    final itemsList = resolveItems(
      json['items'] ?? json['orderItems'] ?? json['order_items'],
    );
    final items = (itemsList as List<dynamic>?)
            ?.map((i) => OrderItem.fromJson(i as Map<String, dynamic>))
            .toList() ??
        [];

    final backorderedCount = items
        .where((i) => i.status == ItemStatus.BACKORDERED)
        .length;

    return OrderDetail(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString(),
      status: OrderStatus.fromRaw(json['status']?.toString()),
      paymentStatus: PaymentStatus.fromRaw(json['paymentStatus']?.toString()),
      paymentType: PaymentType.fromRaw(json['paymentType']?.toString()),
      customerId: customer?['id']?.toString(),
      customerName:
          customer?['name']?.toString() ?? customer?['companyName']?.toString(),
      branchId: branch?['id']?.toString(),
      branchName: branch?['name']?.toString() ?? branch?['code']?.toString(),
      salesManagerId: salesManager?['id']?.toString(),
      salesManagerName:
          salesManager?['username']?.toString() ??
          salesManager?['name']?.toString(),
      pickerId: picker?['id']?.toString(),
      pickerName:
          picker?['name']?.toString() ?? picker?['username']?.toString(),
      createdAt: DateTime.parse(
        json['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
      ),
      endDate: json['endDate'] != null
          ? DateTime.parse(
              json['endDate']?.toString() ?? DateTime.now().toIso8601String(),
            )
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(
              json['completedAt']?.toString() ??
                  DateTime.now().toIso8601String(),
            )
          : null,
      backorderedItemsCount: backorderedCount,
      totalItems: items.length,
      trolleyId: parseString(json['trolleyId']) ?? _nestedTrolley(json),
      notes: json['notes']?.toString(),
      items: items,
      customer: customer != null ? Customer.fromJson(customer) : null,
      picker: picker != null ? Picker.fromJson(picker) : null,
    );
  }
}

// ─── Transition helpers ──────────────────────────────────────────────────────

/// Defines which transitions are allowed from a given status
class TransitionDefinition {
  final OrderStatus from;
  final OrderStatus to;
  final List<String> roles; // UserRole names
  final bool requiresPickerId;
  final bool requiresTrolleyId;
  final bool requiresBackorderedItems;
  final bool requiresArrivedItemIds;
  final bool requiresPaid; // READY → COMPLETED

  const TransitionDefinition({
    required this.from,
    required this.to,
    required this.roles,
    this.requiresPickerId = false,
    this.requiresTrolleyId = false,
    this.requiresBackorderedItems = false,
    this.requiresArrivedItemIds = false,
    this.requiresPaid = false,
  });
}

const List<TransitionDefinition> kTransitionRules = [
  TransitionDefinition(
    from: OrderStatus.DRAFT,
    to: OrderStatus.CONFIRMED,
    roles: ['ADMIN', 'SCM'],
  ),
  TransitionDefinition(
    from: OrderStatus.DRAFT,
    to: OrderStatus.CANCELLED,
    roles: ['ADMIN', 'SALES_MANAGER'],
  ),
  TransitionDefinition(
    from: OrderStatus.CONFIRMED,
    to: OrderStatus.IN_COLLECTION,
    roles: ['ADMIN', 'STORE_MANAGER'],
    requiresPickerId: true,
  ),
  TransitionDefinition(
    from: OrderStatus.CONFIRMED,
    to: OrderStatus.CANCELLED,
    roles: ['ADMIN', 'SALES_MANAGER'],
  ),
  TransitionDefinition(
    from: OrderStatus.IN_COLLECTION,
    to: OrderStatus.READY,
    roles: ['ADMIN', 'STORE_MANAGER', 'PICKER'],
  ),
  TransitionDefinition(
    from: OrderStatus.IN_COLLECTION,
    to: OrderStatus.PARTIAL,
    roles: ['ADMIN', 'STORE_MANAGER', 'PICKER'],
    requiresBackorderedItems: true,
  ),
  TransitionDefinition(
    from: OrderStatus.IN_COLLECTION,
    to: OrderStatus.CANCELLED,
    roles: ['ADMIN', 'SALES_MANAGER'],
  ),
  TransitionDefinition(
    from: OrderStatus.PARTIAL,
    to: OrderStatus.READY,
    roles: ['ADMIN', 'STORE_MANAGER', 'SALES_MANAGER', 'PICKER'],
    requiresArrivedItemIds: true,
  ),
  TransitionDefinition(
    from: OrderStatus.PARTIAL,
    to: OrderStatus.IN_COLLECTION,
    roles: ['ADMIN', 'STORE_MANAGER', 'SALES_MANAGER'],
  ),
  TransitionDefinition(
    from: OrderStatus.PARTIAL,
    to: OrderStatus.CANCELLED,
    roles: ['ADMIN', 'SALES_MANAGER'],
  ),
  TransitionDefinition(
    from: OrderStatus.READY,
    to: OrderStatus.COMPLETED,
    roles: ['ADMIN', 'STORE_MANAGER'],
    requiresPaid: true,
  ),
  TransitionDefinition(
    from: OrderStatus.READY,
    to: OrderStatus.IN_COLLECTION,
    roles: ['ADMIN', 'STORE_MANAGER', 'SALES_MANAGER'],
  ),
  TransitionDefinition(
    from: OrderStatus.READY,
    to: OrderStatus.PARTIAL,
    roles: ['ADMIN', 'STORE_MANAGER', 'SALES_MANAGER'],
    requiresBackorderedItems: true,
  ),
];

List<TransitionDefinition> availableTransitions(
  OrderStatus from,
  String userRole,
) {
  return kTransitionRules
      .where((t) => t.from == from && t.roles.contains(userRole))
      .toList();
}
