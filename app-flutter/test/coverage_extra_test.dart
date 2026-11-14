import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nexus/data/location_service.dart';
import 'package:nexus/data/offline/action_queue.dart';
import 'package:nexus/data/offline/cache_store.dart';
import 'package:nexus/data/offline/offline_repository.dart';
import 'package:nexus/domain/repository.dart';
import 'package:nexus/presentation/theme.dart';
import 'package:nexus/presentation/widgets/location_tile.dart';


class Passthrough implements NexusRepository {
  final calls = <String>[];
  @override
  bool get isDemo => false;
  @override
  void cancelPending() {
    calls.add('cancel');
  }

  @override
  Future<Map<String, dynamic>> deviceLogin(String phone) async {
    calls.add('deviceLogin');
    return {'_status': 200};
  }

  @override
  Future<void> emailVerify(String phone, String email) async {
    calls.add('emailVerify');
  }

  @override
  Future<void> confirm(String otp) async {
    calls.add('confirm');
  }

  @override
  Future<Map<String, dynamic>> register(String p, String e) async {
    calls.add('register');
    return {};
  }

  @override
  Future<bool> restoreSession() async {
    calls.add('restore');
    return false;
  }

  @override
  Future<String> uploadMedia(String filePath) async {
    calls.add('upload');
    return '/api/v1/media/x';
  }

  @override
  Future<String?> currentDeviceId() async {
    calls.add('deviceId');
    return 'dev';
  }

  @override
  Future<void> logout() async {
    calls.add('logout');
  }

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String> query = const {},
  }) async => {'items': <dynamic>[]};

  @override
  Future<Map<String, dynamic>> send(
    String path,
    Map<String, dynamic> body, {
    String method = 'POST',
  }) async => {'id': '1'};
}

class FakeLocation implements LocationService {
  FakeLocation(this.fix);
  final LocationFix? fix;
  @override
  Future<LocationFix?> current() async => fix;
}

Widget tileHost(LocationService service) => ProviderScope(
  overrides: [locationServiceProvider.overrideWithValue(service)],
  child: MaterialApp(
    theme: buildTheme(Brightness.light),
    home: const Scaffold(body: Padding(padding: EdgeInsets.all(12), child: LocationTile())),
  ),
);

void main() {
  group('isOfflineError', () {
    test('classifies transport failures only', () {
      expect(isOfflineError(const SocketException('x')), isTrue);
      expect(isOfflineError(TimeoutException('x')), isTrue);
      expect(isOfflineError(http.ClientException('x')), isTrue);
      expect(isOfflineError(StateError('server')), isFalse);
      expect(isOfflineError(FormatException('bad')), isFalse);
    });
  });

  group('OfflineRepository passthrough', () {
    test('auth, upload and device calls are not cached or queued', () async {
      final inner = Passthrough();
      final repo = OfflineRepository(
        inner,
        cache: MemoryCacheStore(),
        queue: MemoryActionQueue(),
      );
      expect(repo.isDemo, isFalse);
      repo.cancelPending();
      await repo.deviceLogin('+959');
      await repo.emailVerify('+959', 'a@b.co');
      await repo.confirm('otp');
      await repo.register('+959', 'a@b.co');
      expect(await repo.restoreSession(), isFalse);
      expect(await repo.uploadMedia('/tmp/a.webp'), '/api/v1/media/x');
      expect(await repo.currentDeviceId(), 'dev');
      await repo.logout();
      expect(inner.calls, contains('deviceLogin'));
      expect(inner.calls, contains('logout'));
    });
  });

  group('LocationTile', () {
    testWidgets('renders a coordinate fix', (tester) async {
      await tester.pumpWidget(
        tileHost(FakeLocation(const LocationFix(lat: 16.8, lng: 96.15))),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('16.800'), findsWidgets);
    });

    testWidgets('degrades to a no-fix state', (tester) async {
      await tester.pumpWidget(tileHost(FakeLocation(null)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
