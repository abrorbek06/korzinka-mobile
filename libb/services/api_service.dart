import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/user_model.dart';
import '../models/order_model.dart';

// ─── Auth ─────────────────────────────────────────────────────────────────────

class AuthService {
  Future<({String token, PickerUser user})> login(
    String username,
    String password,
  ) async {
    final res = await http.post(
      Uri.parse('${AppConfig.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      final d = jsonDecode(res.body) as Map<String, dynamic>;
      return (
        token: d['accessToken'] as String,
        user: PickerUser.fromJson(d['user'] as Map<String, dynamic>),
      );
    } else if (res.statusCode == 401) {
      throw AppException(AppStrings.loginError);
    }
    throw AppException(AppStrings.networkError);
  }

  Future<PickerUser> getMe(String token) async {
    final res = await http.get(
      Uri.parse('${AppConfig.baseUrl}/auth/me'),
      headers: _bearer(token),
    );
    if (res.statusCode == 200) {
      return PickerUser.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw AppException('Sessiya tugagan. Qayta kiring.');
  }

  Map<String, String> _bearer(String t) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $t',
  };
}

// ─── Orders ───────────────────────────────────────────────────────────────────

class OrdersService {
  final String token;
  OrdersService({required this.token});

  Map<String, String> get _h => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  // Picker only sees their assigned orders
  Future<List<OrderSummary>> getMyOrders() async {
    final uri = Uri.parse('${AppConfig.baseUrl}/orders').replace(
      queryParameters: {
        'limit': '200',
        'statuses': [
          OrderStatus.DRAFT.name,
          OrderStatus.CONFIRMED.name,
          OrderStatus.IN_COLLECTION.name,
          OrderStatus.PARTIAL.name,
          OrderStatus.READY.name,
        ].join(','),
      },
    );
    final res = await http.get(uri, headers: _h);
    _check(res);
    final body = jsonDecode(res.body);
    final list = _extractOrderList(body);
    return list
        .map((j) => OrderSummary.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  List<dynamic> _extractOrderList(dynamic body) {
    if (body is List) return body;
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is List) return data;
      if (data is Map<String, dynamic>) {
        if (data['items'] is List) return data['items'] as List<dynamic>;
        if (data['data'] is List) return data['data'] as List<dynamic>;
        if (data['orders'] is List) return data['orders'] as List<dynamic>;
      }
      return (body['items'] as List<dynamic>?) ??
          (body['orders'] as List<dynamic>?) ??
          [];
    }
    return [];
  }

  Future<OrderDetail> getOrder(String id) async {
    final res = await http.get(
      Uri.parse('${AppConfig.baseUrl}/orders/$id'),
      headers: _h,
    );
    _check(res);
    return OrderDetail.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<OrderDetail> transition({
    required String orderId,
    required OrderStatus nextStatus,
    String? notes,
    List<String>? arrivedItemIds,
  }) async {
    final res = await http.post(
      Uri.parse('${AppConfig.baseUrl}/orders/$orderId/transitions'),
      headers: _h,
      body: jsonEncode({
        'nextStatus': nextStatus.name,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (arrivedItemIds != null) 'arrivedItemIds': arrivedItemIds,
      }),
    );
    _check(res);
    return OrderDetail.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  void _check(http.Response res) {
    if (res.statusCode >= 400) {
      final d = jsonDecode(res.body) as Map<String, dynamic>?;
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

      throw AppException(
        parseString(d?['message']) ?? 'Xatolik yuz berdi (${res.statusCode})',
      );
    }
  }
}

class AppException implements Exception {
  final String message;
  const AppException(this.message);
  @override
  String toString() => message;
}
