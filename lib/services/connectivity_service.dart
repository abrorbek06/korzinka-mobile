import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

enum ConnectivityStatus { online, offline }

class ConnectivityService extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  ConnectivityStatus _status = ConnectivityStatus.online;
  DateTime? _lastOnlineTime;
  DateTime? _lastOfflineTime;

  ConnectivityStatus get status => _status;
  bool get isOnline => _status == ConnectivityStatus.online;
  bool get isOffline => _status == ConnectivityStatus.offline;
  DateTime? get lastOnlineTime => _lastOnlineTime;
  DateTime? get lastOfflineTime => _lastOfflineTime;

  ConnectivityService() {
    _initializeConnectivity();
  }

  Future<void> _initializeConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectivityStatus(result);

      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _updateConnectivityStatus,
      );
    } catch (e) {
      debugPrint('Connectivity initialization error: $e');
      // Assume online if we can't check
      _status = ConnectivityStatus.online;
    }
  }

  void _updateConnectivityStatus(ConnectivityResult result) {
    final previousStatus = _status;

    if (result == ConnectivityResult.none) {
      _status = ConnectivityStatus.offline;
      if (previousStatus == ConnectivityStatus.online) {
        _lastOfflineTime = DateTime.now();
        debugPrint('🔴 Network connection lost');
      }
    } else {
      _status = ConnectivityStatus.online;
      if (previousStatus == ConnectivityStatus.offline) {
        _lastOnlineTime = DateTime.now();
        debugPrint('🟢 Network connection restored');
      }
    }

    notifyListeners();
  }

  Future<bool> checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectivityStatus(result);
      return isOnline;
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
