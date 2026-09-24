import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityProvider extends ChangeNotifier {
  bool _isOnline = true;
  bool get isOnline => _isOnline;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  ConnectivityProvider() {
    _initConnectivity();
    _subscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) {
      _updateConnectionStatus(result);
    });
  }

  Future<void> _initConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      debugPrint('Connectivity Error: $e');
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> result) {
    final bool isConnected = !result.contains(ConnectivityResult.none);
    if (_isOnline != isConnected) {
      _isOnline = isConnected;
      
      // Use microtask to ensure notifyListeners is called after the current build frame
      Future.microtask(() {
        notifyListeners();
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
