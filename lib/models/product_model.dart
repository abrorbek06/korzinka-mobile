class Product {
  final String id;
  final String sku;
  final String name;
  final String? barcode;
  final String? unit;
  final String? brand;
  final int? price;
  final bool isActive;

  const Product({
    required this.id,
    required this.sku,
    required this.name,
    this.barcode,
    this.unit,
    this.brand,
    this.price,
    this.isActive = true,
  });

  static String _parseString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value.trim();
    if (value is num) return value.toString();
    return '';
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? double.tryParse(value)?.toInt();
    }
    return null;
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    if (value is num) return value != 0;
    return false;
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    final rawName = json['name'];
    String name = _parseString(json['sku']);

    if (rawName is String && rawName.trim().isNotEmpty) {
      name = rawName.trim();
    } else if (rawName is Map<String, dynamic>) {
      name = _parseString(rawName['uz']).isNotEmpty
          ? _parseString(rawName['uz'])
          : _parseString(rawName['ru']);
    }

    if (name.isEmpty) {
      name = 'Unknown product';
    }

    return Product(
      id: _parseString(json['id']).isNotEmpty
          ? _parseString(json['id'])
          : _parseString(json['productId']).isNotEmpty
          ? _parseString(json['productId'])
          : _parseString(json['sku']),
      sku: _parseString(json['sku']),
      name: name,
      barcode: _parseString(json['barcode']).isNotEmpty
          ? _parseString(json['barcode'])
          : null,
      unit: _parseString(json['unit']).isNotEmpty
          ? _parseString(json['unit'])
          : null,
      brand: _parseString(json['brand']).isNotEmpty
          ? _parseString(json['brand'])
          : null,
      price: _parseInt(json['price']),
      isActive: _parseBool(json['isActive'] ?? true),
    );
  }
}
