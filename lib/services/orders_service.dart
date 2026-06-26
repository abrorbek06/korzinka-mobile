import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/order_model.dart';
import '../models/audit_log_model.dart';

class OrdersService {
  final String _baseUrl = AppConfig.baseUrl;
  final String token;

  OrdersService({required this.token});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };


  String _mapPaymentType(PaymentType t) {
    switch (t) {
      case PaymentType.CASH:
        return 'cash';
      case PaymentType.CARD:
        return 'card';
      case PaymentType.BANK:
      default:
        // Backend expects bank_prepayment or bank_post_payment;
        // pick bank_prepayment as the default filter token for "bank".
        return 'bank_prepayment';
    }
  }

  // ─── List / Kanban feed ────────────────────────────────────────────────────

  Future<({List<OrderListItem> items, int total, int page})> getOrders({
    List<OrderStatus>? statuses,
    String? branchId,
    String? customerId,
    String? salesManagerId,
    DateTime? from,
    DateTime? to,
    String? search,
    PaymentStatus? paymentStatus,
    PaymentType? paymentType,
    int page = 1,
    int limit = AppConfig.defaultPageSize,
  }) async {
    final query = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      if (statuses != null && statuses.isNotEmpty)
        // Backend expects lowercase snake_case status names, e.g. 'in_collection'
        'statuses': statuses.map((s) => s.name.toLowerCase()).join(','),
      'branchId': ?branchId,
      'customerId': ?customerId,
      'salesManagerId': ?salesManagerId,
      if (from != null) 'from': from.toIso8601String(),
      if (to != null) 'to': to.toIso8601String(),
      if (search != null && search.isNotEmpty) 'search': search,
      if (paymentStatus != null)
        'paymentStatus': paymentStatus.name.toLowerCase(),
      if (paymentType != null) 'paymentType': _mapPaymentType(paymentType),
    };

    final uri = Uri.parse(
      '${AppConfig.baseUrl}/orders',
    ).replace(queryParameters: query);
    print('[OrdersService] Fetching orders from: ${uri.toString()}');
    late http.Response response;
    try {
      response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));
    } on TimeoutException catch (_) {
      throw ApiException('Request timed out', 504);
    }

    // Always print the raw response first to aid debugging (even on non-2xx)
    print('[OrdersService] response status: ${response.statusCode}');
    print('[OrdersService] raw response: ${response.body}');
    _checkStatus(response);
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (e) {
      print('[OrdersService] Failed to decode JSON: $e');
      rethrow;
    }

    List<dynamic> rawItems = [];
    int? total;
    int returnedPage = page;

    if (decoded is List) {
      rawItems = decoded;
      total = rawItems.length;
    } else if (decoded is Map<String, dynamic>) {
      rawItems = (decoded['data'] ?? decoded['items'] ?? []) as List<dynamic>;
      total = (decoded['total'] as int?) ?? rawItems.length;
      returnedPage = (decoded['page'] as int?) ?? page;
    } else {
      throw ApiException('Unexpected response shape', response.statusCode);
    }

    final items = <OrderListItem>[];
    for (final j in rawItems) {
      try {
        items.add(OrderListItem.fromJson(j as Map<String, dynamic>));
      } catch (e, st) {
        print('[OrdersService] Failed to parse item: $j');
        print(e);
        print(st);
      }
    }

    return (items: items, total: total ?? items.length, page: returnedPage);
  }

  // ─── Single order ──────────────────────────────────────────────────────────

  Future<OrderDetail> getOrder(String id) async {
    final uri = Uri.parse('$_baseUrl/orders/$id');
    print('[OrdersService] Fetching order detail from: ${uri.toString()}');
    late http.Response response;
    try {
      response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));
    } on TimeoutException catch (_) {
      throw ApiException('Request timed out', 504);
    }
    print('[OrdersService] getOrder status: ${response.statusCode}');
    print('[OrdersService] getOrder body: ${response.body}');
    _checkStatus(response);
    return _parseOrderDetailResponse(response.body, response.statusCode);
  }

  OrderDetail _parseOrderDetailResponse(String body, int statusCode) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      var payload = decoded['data'] as Map<String, dynamic>? ?? decoded;
      if (payload['order'] is Map<String, dynamic>) {
        final orderMap = Map<String, dynamic>.from(
          payload['order'] as Map<String, dynamic>,
        );
        if (payload.containsKey('items') && !orderMap.containsKey('items')) {
          orderMap['items'] = payload['items'];
        }
        if (payload.containsKey('orderItems') &&
            !orderMap.containsKey('orderItems')) {
          orderMap['orderItems'] = payload['orderItems'];
        }
        if (payload.containsKey('order_items') &&
            !orderMap.containsKey('order_items')) {
          orderMap['order_items'] = payload['order_items'];
        }
        payload = orderMap;
      }
      return OrderDetail.fromJson(payload);
    }
    throw ApiException('Unexpected order detail response shape', statusCode);
  }

  // ─── Audit logs ────────────────────────────────────────────────────────────

  Future<List<AuditLog>> getOrderLogs(String id) async {
    final uri = Uri.parse('$_baseUrl/orders/$id/logs');
    print('[OrdersService] Fetching order logs from: ${uri.toString()}');
    late http.Response response;
    try {
      response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));
    } on TimeoutException catch (_) {
      throw ApiException('Request timed out', 504);
    }
    print('[OrdersService] getOrderLogs status: ${response.statusCode}');
    print('[OrdersService] getOrderLogs body: ${response.body}');
    _checkStatus(response);
    final decoded = jsonDecode(response.body);
    if (decoded is List<dynamic>) {
      return decoded
          .map((j) => AuditLog.fromJson(j as Map<String, dynamic>))
          .toList();
    }
    if (decoded is Map<String, dynamic>) {
      final raw =
          decoded['data'] as List<dynamic>? ??
          decoded['logs'] as List<dynamic>?;
      if (raw != null) {
        return raw
            .map((j) => AuditLog.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    }
    throw ApiException(
      'Unexpected order logs response shape',
      response.statusCode,
    );
  }

  // ─── Transitions ───────────────────────────────────────────────────────────

  Future<OrderDetail> transition({
    required String orderId,
    required OrderStatus nextStatus,
    String? pickerId,
    String? trolleyId,
    List<Map<String, dynamic>>? backorderedItems,
    List<String>? arrivedItemIds,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      'nextStatus': nextStatus.name.toLowerCase(),
      'pickerId': ?pickerId,
      'trolleyId': ?trolleyId,
      'backorderedItems': ?backorderedItems,
      'arrivedItemIds': ?arrivedItemIds,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };

    late http.Response response;
    try {
      final uri = Uri.parse('$_baseUrl/orders/$orderId/transitions');
      final bodyJson = jsonEncode(body);
      print('[OrdersService] POST $uri');
      print('[OrdersService] request body: $bodyJson');
      response = await http
          .post(uri, headers: _headers, body: bodyJson)
          .timeout(const Duration(seconds: 10));
      print('[OrdersService] response status: ${response.statusCode}');
      print('[OrdersService] response body: ${response.body}');
    } on TimeoutException catch (_) {
      throw ApiException('Request timed out', 504);
    }
    _checkStatus(response);
    return _parseOrderDetailResponse(response.body, response.statusCode);
  }

  // ─── Mark paid / unpaid ────────────────────────────────────────────────────

  Future<OrderDetail> markPaid(String orderId) async {
    late http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$_baseUrl/orders/$orderId/mark-paid'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));
    } on TimeoutException catch (_) {
      throw ApiException('Request timed out', 504);
    }
    _checkStatus(response);
    return _parseOrderDetailResponse(response.body, response.statusCode);
  }

  Future<OrderDetail> unmarkPaid(String orderId) async {
    late http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$_baseUrl/orders/$orderId/unmark-paid'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));
    } on TimeoutException catch (_) {
      throw ApiException('Request timed out', 504);
    }
    _checkStatus(response);
    return _parseOrderDetailResponse(response.body, response.statusCode);
  }

  Future<OrderDetail> updateDetails({
    required String orderId,
    String? trolleyId,
    bool clearTrolley = false,
    DateTime? endDate,
  }) async {
    final body = <String, dynamic>{
      if (clearTrolley)
        'trolleyId': null
      else 'trolleyId': ?trolleyId,
      if (endDate != null) 'endDate': endDate.toIso8601String(),
    };
    late http.Response response;
    try {
      response = await http
          .patch(
            Uri.parse('$_baseUrl/orders/$orderId/details'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
    } on TimeoutException catch (_) {
      throw ApiException('Request timed out', 504);
    }
    _checkStatus(response);
    return _parseOrderDetailResponse(response.body, response.statusCode);
  }

  /// Attach a cart to the order (logistics attach, order must be IN_COLLECTION)
  Future<OrderDetail> attachCart({
    required String orderId,
    required String cartId,
  }) async {
    final body = jsonEncode({'cartId': cartId});
    late http.Response response;
    try {
      final uri = Uri.parse('$_baseUrl/orders/$orderId/carts');
      response = await http
          .post(uri, headers: _headers, body: body)
          .timeout(const Duration(seconds: 10));
    } on TimeoutException catch (_) {
      throw ApiException('Request timed out', 504);
    }
    _checkStatus(response);
    return _parseOrderDetailResponse(response.body, response.statusCode);
  }

  /// Detach a cart from the order
  Future<OrderDetail> detachCart({
    required String orderId,
    required String cartId,
  }) async {
    late http.Response response;
    try {
      final uri = Uri.parse('$_baseUrl/orders/$orderId/carts/$cartId');
      response = await http
          .delete(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));
    } on TimeoutException catch (_) {
      throw ApiException('Request timed out', 504);
    }
    _checkStatus(response);
    return _parseOrderDetailResponse(response.body, response.statusCode);
  }

  /// Fetch available carts for a branch (availability=available)
  Future<List<Map<String, dynamic>>> getAvailableCarts({
    String? branchId,
  }) async {
    final query = <String, String>{
      'branchId': ?branchId,
      'availability': 'available',
    };
    final uri = Uri.parse('$_baseUrl/carts').replace(queryParameters: query);
    late http.Response response;
    try {
      response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));
    } on TimeoutException catch (_) {
      throw ApiException('Request timed out', 504);
    }
    _checkStatus(response);
    final decoded = jsonDecode(response.body);
    if (decoded is List<dynamic>) {
      return decoded.cast<Map<String, dynamic>>();
    }
    if (decoded is Map<String, dynamic>) {
      final data =
          decoded['data'] as List<dynamic>? ??
          decoded['items'] as List<dynamic>?;
      if (data != null) return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<OrderDetail> updateItem({
    required String orderId,
    required String itemId,
    double? quantity,
    String? status,
    double? backorderedQuantity,
  }) async {
    final body = <String, dynamic>{
      'quantity': ?quantity,
      'status': ?status,
      if (backorderedQuantity != null)
        'backorderedQuantity': backorderedQuantity.toInt().toString(),
    };
    late http.Response response;
    try {
      response = await http
          .patch(
            Uri.parse('$_baseUrl/orders/$orderId/items/$itemId'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
    } on TimeoutException catch (_) {
      throw ApiException('Request timed out', 504);
    }
    _checkStatus(response);
    return _parseOrderDetailResponse(response.body, response.statusCode);
  }

  void _checkStatus(http.Response response) {
    if (response.statusCode == 401) {
      AppConfig.logout(); // Global logoutni chaqirish
      throw ApiException('Sessiya muddati tugadi', 401);
    }

    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body) as Map<String, dynamic>?;
      final msgVal = body?['message'];
      String message;
      if (msgVal is List) {
        message = msgVal.join(', ');
      } else {
        message =
            msgVal?.toString() ?? 'Request failed (${response.statusCode})';
      }
      throw ApiException(message, response.statusCode);
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;

  const ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}
