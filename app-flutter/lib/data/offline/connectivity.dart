import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

abstract interface class ConnectivityMonitor {
  Stream<bool> get changes;
  Future<bool> get isOnline;
}

/// connectivity_plus 5, 6 and 7 return different shapes (a single enum or a
/// list). String-matching the result keeps one implementation valid across all
/// of them instead of pinning the app to one version.
bool onlineFrom(dynamic value) {
  if (value is List) {
    return value.any((e) => !'$e'.endsWith('none'));
  }
  return value != null && !'$value'.endsWith('none');
}

class PluginConnectivityMonitor implements ConnectivityMonitor {
  PluginConnectivityMonitor([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();
  final Connectivity _connectivity;

  @override
  Stream<bool> get changes =>
      _connectivity.onConnectivityChanged.map(onlineFrom).distinct();

  @override
  Future<bool> get isOnline async {
    try {
      return onlineFrom(await _connectivity.checkConnectivity());
    } catch (_) {
      // A platform without the plugin must not look offline.
      return true;
    }
  }
}

class MemoryConnectivityMonitor implements ConnectivityMonitor {
  MemoryConnectivityMonitor({bool online = true}) {
    _online = online;
  }
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  late bool _online;
  bool get current => _online;
  set online(bool value) {
    if (_online == value) return;
    _online = value;
    if (!_controller.isClosed) _controller.add(value);
  }

  @override
  Stream<bool> get changes => _controller.stream;

  @override
  Future<bool> get isOnline async => _online;

  Future<void> dispose() => _controller.close();
}
