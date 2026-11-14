import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);
const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
const geolocatorChannel = MethodChannel('flutter.baseflow.com/geolocator');

void clearMock(MethodChannel channel) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null);
}

/// In-memory flutter_secure_storage, so the real plugin code path runs.
Map<String, String> installSecureStorage([Map<String, String>? seed]) {
  final store = <String, String>{...?seed};
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(secureStorageChannel, (call) async {
        final args = Map<String, dynamic>.from(
          (call.arguments as Map?) ?? const {},
        );
        final key = args['key'] as String?;
        switch (call.method) {
          case 'read':
            return store[key];
          case 'write':
            store[key!] = '${args['value']}';
            return null;
          case 'delete':
            store.remove(key);
            return null;
          case 'deleteAll':
            store.clear();
            return null;
          case 'readAll':
            return store;
        }
        return null;
      });
  return store;
}

void installPathProvider(String path) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(pathProviderChannel, (call) async => path);
}

/// Geolocator fake. [permission] / [afterRequest] are LocationPermission
/// indices: 0 denied, 1 deniedForever, 2 whileInUse, 3 always.
void installGeolocator({
  bool serviceEnabled = true,
  int permission = 2,
  int? afterRequest,
  Map<String, dynamic>? position,
  bool throwOnCall = false,
}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(geolocatorChannel, (call) async {
        if (throwOnCall) throw PlatformException(code: 'no_plugin');
        switch (call.method) {
          case 'isLocationServiceEnabled':
            return serviceEnabled;
          case 'checkPermission':
            return permission;
          case 'requestPermission':
            return afterRequest ?? permission;
          case 'getCurrentPosition':
          case 'getLastKnownPosition':
            return position;
        }
        return null;
      });
}

Map<String, dynamic> fakePosition({double lat = 16.8, double lng = 96.15}) => {
  'latitude': lat,
  'longitude': lng,
  'timestamp': DateTime.now().millisecondsSinceEpoch,
  'accuracy': 5.0,
  'altitude': 0.0,
  'altitudeAccuracy': 0.0,
  'heading': 0.0,
  'headingAccuracy': 0.0,
  'speed': 0.0,
  'speedAccuracy': 0.0,
  'isMocked': false,
};
