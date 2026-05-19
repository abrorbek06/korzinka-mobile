import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/product_model.dart';

class ProductsService {
  final String token;
  final String _baseUrl = AppConfig.baseUrl;

  ProductsService({required this.token});

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<List<Product>> getProducts({int page = 1, int limit = 100}) async {
    final uri = Uri.parse('$_baseUrl/products').replace(queryParameters: {
      'page': page.toString(),
      'limit': limit.toString(),
    });

    late http.Response response;
    try {
      response = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 10));
    } on TimeoutException catch (_) {
      throw ApiException('Request timed out', 504);
    }

    _checkStatus(response);

    final decoded = jsonDecode(response.body);
    List<dynamic> rawItems = [];

    if (decoded is List) {
      rawItems = decoded;
    } else if (decoded is Map<String, dynamic>) {
      rawItems = (decoded['data'] ?? decoded['items'] ?? []) as List<dynamic>;
    } else {
      throw ApiException('Unexpected products response shape', response.statusCode);
    }

    return rawItems
        .whereType<Map<String, dynamic>>()
        .map((json) => Product.fromJson(json))
        .toList();
  }

  void _checkStatus(http.Response response) {
    if (response.statusCode >= 400) {
      final decoded = jsonDecode(response.body);
      final message = decoded is Map<String, dynamic>
          ? decoded['message'] as String? ?? 'Request failed (${response.statusCode})'
          : 'Request failed (${response.statusCode})';
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
