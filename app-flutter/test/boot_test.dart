import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/data/offline/action_queue.dart';
import 'package:nexus/data/offline/cache_store.dart';
import 'package:nexus/data/offline/connectivity.dart';
import 'package:nexus/data/telemetry.dart';
import 'package:nexus/main.dart';
import 'package:nexus/presentation/controllers/offline_providers.dart';
import 'package:nexus/presentation/controllers/providers.dart';
import 'package:nexus/presentation/screens/auth_screen.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'support/harness.dart';
import 'support/plugins.dart';

Widget bootApp(NexusRepositoryStub repo, {ConnectivityMonitor? monitor}) =>
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        cacheStoreProvider.overrideWithValue(MemoryCacheStore()),
        actionQueueProvider.overrideWithValue(MemoryActionQueue()),
        connectivityProvider.overrideWithValue(
          monitor ?? MemoryConnectivityMonitor(),
        ),
      ],
      child: const NexusApp(),
    );

typedef NexusRepositoryStub = SheetRepo;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => clearMock(secureStorageChannel));

  group('app boot', () {
    testWidgets('NexusApp starts on the auth screen when no session exists', (
      tester,
    ) async {
      installSecureStorage();
      await tester.pumpWidget(bootApp(SheetRepo()));
      await tester.pumpAndSettle();
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a stored session goes straight to the home shell', (
      tester,
    ) async {
      installSecureStorage();
      await tester.pumpWidget(bootApp(SheetRepo(session: true)));
      await tester.pumpAndSettle();
      expect(find.byType(AuthScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the offline banner wraps the app when the device is offline', (
      tester,
    ) async {
      installSecureStorage();
      final monitor = MemoryConnectivityMonitor(online: false);
      addTearDown(monitor.dispose);
      await tester.pumpWidget(bootApp(SheetRepo(), monitor: monitor));
      await tester.pumpAndSettle();
      expect(find.textContaining('Offline'), findsWidgets);
      monitor.online = true;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('telemetry', () {
    test('runs the app untouched when no DSN is compiled in', () async {
      var ran = 0;
      await startTelemetry(() async => ran++);
      expect(ran, 1);
      expect(sentryDsn, isEmpty);
    });

    test('options carry the release, environment and privacy defaults', () {
      final options = sentryOptions(dsn: 'https://k@o0.ingest.sentry.io/1');
      expect(options.dsn, 'https://k@o0.ingest.sentry.io/1');
      expect(options.release, nexusRelease);
      expect(options.environment, 'production');
      expect(options.tracesSampleRate, 0.1);
      expect(options.sendDefaultPii, isFalse);
      expect(nexusRelease, contains('1.4.2'));
      final staging = sentryOptions(dsn: 'https://k@o0.ingest.sentry.io/1',
          environment: 'staging');
      expect(staging.environment, 'staging');
    });

    test('connectivity noise is classified', () {
      expect(isConnectivityNoise('SocketException: offline'), isTrue);
      expect(isConnectivityNoise('RequestCancelled'), isTrue);
      expect(isConnectivityNoise('ClientException: closed'), isTrue);
      expect(isConnectivityNoise('StateError: boom'), isFalse);
    });

    test('beforeSend drops noise and keeps real crashes', () async {
      final options = sentryOptions(dsn: 'https://k@o0.ingest.sentry.io/1');
      final send = options.beforeSend!;
      final noise = SentryEvent(
        exceptions: [SentryException(type: 'net', value: 'SocketException')],
      );
      final crash = SentryEvent(
        exceptions: [SentryException(type: 'bad', value: 'StateError: boom')],
      );
      expect(await send(noise, Hint()), isNull);
      expect(await send(crash, Hint()), same(crash));
      expect(await send(SentryEvent(), Hint()), isNotNull);
    });
  });
}
