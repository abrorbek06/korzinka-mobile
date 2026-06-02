import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/order_model.dart';

class SettingsProvider extends ChangeNotifier {
  static const _defaultHiddenStatuses = {OrderStatus.CANCELLED};

  final Set<OrderStatus> _hiddenStatuses = {..._defaultHiddenStatuses};
  bool _statusChangeViaDropdown = true;

  bool get statusChangeViaDropdown => _statusChangeViaDropdown;
  Set<OrderStatus> get hiddenStatuses => {..._hiddenStatuses};

  List<OrderStatus> get visibleStatuses => _columnOrder
      .where((status) => !_hiddenStatuses.contains(status))
      .toList();

  static const List<OrderStatus> _columnOrder = [
    OrderStatus.DRAFT,
    OrderStatus.CONFIRMED,
    OrderStatus.IN_COLLECTION,
    OrderStatus.PARTIAL,
    OrderStatus.READY,
    OrderStatus.COMPLETED,
    OrderStatus.CANCELLED,
  ];

  SettingsProvider() {
    load();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final hiddenStatusesJson = prefs.getString(AppConfig.hiddenStatusesKey);
    if (hiddenStatusesJson != null) {
      try {
        final statusStrings = (jsonDecode(hiddenStatusesJson) as List).cast<String>();
        _hiddenStatuses.clear();
        for (final statusStr in statusStrings) {
          final matching = OrderStatus.values
            .where((s) => s.name == statusStr)
            .toList();
        if (matching.isNotEmpty) {
          _hiddenStatuses.add(matching.first);
        }
        }
      } catch (_) {
        _hiddenStatuses
          ..clear()
          ..addAll(_defaultHiddenStatuses);
      }
    }

    final useDropdown = prefs.getBool(AppConfig.statusChangeMethodKey);
    if (useDropdown != null) {
      _statusChangeViaDropdown = useDropdown;
    }

    notifyListeners();
  }

  Future<void> setStatusChangeViaDropdown(bool value) async {
    _statusChangeViaDropdown = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConfig.statusChangeMethodKey, value);
  }

  Future<void> toggleStatusVisibility(OrderStatus status, bool visible) async {
    if (visible) {
      _hiddenStatuses.remove(status);
    } else {
      _hiddenStatuses.add(status);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final statusStrings = _hiddenStatuses.map((s) => s.name).toList();
    await prefs.setString(AppConfig.hiddenStatusesKey, jsonEncode(statusStrings));
  }

  bool isStatusVisible(OrderStatus status) => !_hiddenStatuses.contains(status);
}
