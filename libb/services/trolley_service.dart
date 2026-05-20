import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';

class Trolley {
  final int number;
  final String code; // AR-01, AR-02...
  String? assignedOrderId;
  String? assignedOrderCode;

  Trolley({
    required this.number,
    required this.code,
    this.assignedOrderId,
    this.assignedOrderCode,
  });

  bool get isFree => assignedOrderId == null;

  static String codeFromNumber(int n) => 'AR-${n.toString().padLeft(2, '0')}';

  static List<Trolley> generateAll() =>
      List.generate(AppConfig.trolleyCount, (i) {
        final n = i + 1;
        return Trolley(number: n, code: codeFromNumber(n));
      });
}

class TrolleyService {
  // orderId → trolleyCode mapping
  Map<String, String> _assignments = {};

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConfig.trolleyKey);
    if (raw != null) {
      _assignments = Map<String, String>.from(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConfig.trolleyKey, jsonEncode(_assignments));
  }

  String? getTrolleyForOrder(String orderId) => _assignments[orderId];

  String? getOrderForTrolley(String trolleyCode) {
    for (final e in _assignments.entries) {
      if (e.value == trolleyCode) return e.key;
    }
    return null;
  }

  Future<void> assign({required String orderId, required String trolleyCode}) async {
    // Unassign any previous trolley for this order
    _assignments.removeWhere((k, v) => k == orderId);
    _assignments[orderId] = trolleyCode;
    await _save();
  }

  Future<void> unassign(String orderId) async {
    _assignments.remove(orderId);
    await _save();
  }

  List<Trolley> getAllWithState(Map<String, String> orderCodeMap) {
    return Trolley.generateAll().map((t) {
      final orderId = getOrderForTrolley(t.code);
      t.assignedOrderId = orderId;
      t.assignedOrderCode = orderId != null ? orderCodeMap[orderId] : null;
      return t;
    }).toList();
  }
}
