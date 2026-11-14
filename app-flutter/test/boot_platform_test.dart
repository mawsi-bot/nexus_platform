import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/data/offline/bootstrap.dart';
import 'package:nexus/data/offline/connectivity.dart';
import 'package:nexus/data/telemetry.dart';
import 'package:nexus/presentation/controllers/device_actions.dart';

const _pathChannel = MethodChannel('plugins.flutter.io/path_provider');
const _connectivityChannels = [
  'dev.fluttercommunity.plus/connectivity',
  'plugins.flutter.io/connectivity',
];
const _launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');

void mockPathProvider(String path) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_pathChannel, (call) async => path);
}

void clearPathProvider() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_pathChannel, null);
}

void mockConnectivity(List<String> result) {
  for (final name in _connectivityChannels) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(name), (call) async => result);
  }
}

void mockLauncher({required bool ok, bool throwInstead = false}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_launcherChannel, (call) async {
        if (throwInstead) {
          throw PlatformException(code: 'failed');
        }
        return ok;
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    clearPathProvider();
    for (final name in _connectivityChannels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), null);
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_launcherChannel, null);
  });

  group('openOfflineStorage', () {
    test('degrades to memory stores when the platform has no storage dir',
        () async {
      clearPathProvider();
      final storage = await openOfflineStorage();
      expect(storage.durable, isFalse);
      await storage.cache.write('/feed', {'v': 1});
      expect((await storage.cache.read('/feed'))?['v'], 1);
      await storage.queue.add(path: '/x', body: const {});
      expect(await storage.queue.length(), 1);
    });

    test('opens durable Hive stores when a directory is available', () async {
      final dir = await Directory.systemTemp.createTemp('nexus_boot');
      addTearDown(() => dir.delete(recursive: true));
      mockPathProvider(dir.path);
      final storage = await openOfflineStorage();
      expect(storage.durable, isTrue);
      await storage.cache.write('/feed', {'items': <dynamic>[]});
      expect(await storage.cache.read('/feed'), isNotNull);
      final action = await storage.queue.add(path: '/y', body: const {'n': 1});
      expect(await storage.queue.length(), greaterThanOrEqualTo(1));
      await storage.queue.remove(action.id);
      await storage.cache.clear();
    });
  });

  group('connectivity', () {
    test('parses every shape the plugin returns', () {
      expect(onlineFrom('wifi'), isTrue);
      expect(onlineFrom('none'), isFalse);
      expect(onlineFrom(['wifi', 'mobile']), isTrue);
      expect(onlineFrom(['none']), isFalse);
      expect(onlineFrom(null), isFalse);
    });

    test('memory monitor emits only real transitions', () async {
      final monitor = MemoryConnectivityMonitor();
      addTearDown(monitor.dispose);
      expect(await monitor.isOnline, isTrue);
      final seen = <bool>[];
      final sub = monitor.changes.listen(seen.add);
      monitor.online = true;
      monitor.online = false;
      monitor.online = true;
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(seen, [false, true]);
      expect(monitor.current, isTrue);
    });

    test('plugin monitor reads the platform channel', () async {
      mockConnectivity(['wifi']);
      final monitor = PluginConnectivityMonitor();
      expect(await monitor.isOnline, isTrue);
      // The plugin only emits on change; the check above covers the read path.
      expect(monitor.changes, isA<Stream<bool>>());
    });
  });

  group('device actions', () {
    test('launch success resolves', () async {
      mockLauncher(ok: true);
      await callShop();
      await directions();
    });

    test('a refused launch throws a readable state error', () async {
      mockLauncher(ok: false);
      expect(callShop(), throwsA(isA<StateError>()));
      expect(directions(), throwsA(isA<StateError>()));
    });
  });

  group('telemetry', () {
    test('runs the app without a DSN', () async {
      var ran = false;
      await startTelemetry(() async => ran = true);
      expect(ran, isTrue);
      expect(sentryDsn, isEmpty);
    });
  });
}
