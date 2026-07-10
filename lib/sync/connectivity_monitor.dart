import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Abstracted so the sync engine depends on a boolean signal, not on the
/// connectivity_plus package — which keeps the engine testable with a fake.
abstract class ConnectivityMonitor {
  Future<bool> get isOnline;

  /// Fires once each time the device transitions from offline -> online.
  Stream<void> get onOnline;
}

class ConnectivityPlusMonitor implements ConnectivityMonitor {
  final Connectivity _connectivity;

  ConnectivityPlusMonitor([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  bool _mapOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  @override
  Future<bool> get isOnline async =>
      _mapOnline(await _connectivity.checkConnectivity());

  @override
  Stream<void> get onOnline => _connectivity.onConnectivityChanged
      .map(_mapOnline)
      .distinct() // only react to actual transitions
      .where((online) => online)
      .map((_) {});
}
