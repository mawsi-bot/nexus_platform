import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/data/vault.dart';
import 'package:nexus/domain/models.dart';
import 'package:nexus/presentation/controllers/theme_mode.dart';

import 'support/plugins.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => clearMock(secureStorageChannel));

  group('SecureVault', () {
    test('creates and caches a device id', () async {
      final store = installSecureStorage();
      final vault = SecureVault();
      final first = await vault.deviceId();
      expect(first, isNotEmpty);
      expect(store['nexus.device'], first);
      expect(await vault.deviceId(), first);
    });

    test('reuses an existing device id', () async {
      installSecureStorage({'nexus.device': 'device-123'});
      expect(await SecureVault().deviceId(), 'device-123');
    });

    test('saves, reads back and clears a session', () async {
      final store = installSecureStorage();
      final vault = SecureVault();
      expect(await vault.session(), isNull);
      await vault.save(const Session(jwt: 'jwt-1', refresh: 'ref-1'));
      expect(jsonDecode(store['nexus.session']!)['jwt'], 'jwt-1');
      final back = await vault.session();
      expect(back?.jwt, 'jwt-1');
      expect(back?.refresh, 'ref-1');
      await vault.clear();
      expect(await vault.session(), isNull);
      expect(store.containsKey('nexus.session'), isFalse);
    });

    test('serialises overlapping writes without dropping the last one', () async {
      installSecureStorage();
      final vault = SecureVault();
      await Future.wait([
        vault.save(const Session(jwt: 'a', refresh: 'a')),
        vault.save(const Session(jwt: 'b', refresh: 'b')),
        vault.save(const Session(jwt: 'c', refresh: 'c')),
      ]);
      expect((await vault.session())?.jwt, 'c');
    });

    test('surfaces corrupt stored JSON instead of pretending to be signed in', () async {
      installSecureStorage({'nexus.session': 'not-json'});
      expect(SecureVault().session(), throwsA(anything));
    });

    test('MemoryVault mirrors the interface', () async {
      final vault = MemoryVault();
      expect(await vault.session(), isNull);
      expect(await vault.deviceId(), isNotEmpty);
      await vault.save(const Session(jwt: 'x', refresh: 'y'));
      expect((await vault.session())?.jwt, 'x');
      await vault.clear();
      expect(await vault.session(), isNull);
    });
  });

  group('ThemeModeController', () {
    test('defaults to system and loads the stored preference', () async {
      installSecureStorage({'nexus.theme': 'dark'});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(themeModeProvider), ThemeMode.system);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(themeModeProvider), ThemeMode.dark);
    });

    test('set persists the choice and toggle flips it', () async {
      final store = installSecureStorage();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final c = container.read(themeModeProvider.notifier);
      await c.set(ThemeMode.light);
      expect(store['nexus.theme'], 'light');
      await c.toggle();
      expect(container.read(themeModeProvider), ThemeMode.dark);
      expect(store['nexus.theme'], 'dark');
      await c.set(ThemeMode.system);
      expect(store['nexus.theme'], 'system');
    });

    test('an unknown stored value falls back to following the system', () async {
      installSecureStorage({'nexus.theme': 'sepia'});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(themeModeProvider);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(themeModeProvider), ThemeMode.system);
    });

    test('storage failures never break the toggle', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureStorageChannel, (call) async {
            throw PlatformException(code: 'boom');
          });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final c = container.read(themeModeProvider.notifier);
      await c.set(ThemeMode.dark);
      expect(container.read(themeModeProvider), ThemeMode.dark);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(themeModeProvider), ThemeMode.dark);
    });
  });
}
