import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nexus/data/offline/action_queue.dart';
import 'package:nexus/data/offline/cache_store.dart';
import 'package:nexus/data/offline/hive_action_queue.dart';
import 'package:nexus/data/offline/hive_cache_store.dart';
import 'package:nexus/data/offline/offline_repository.dart';
import 'package:nexus/domain/repository.dart';

class _Repo implements NexusRepository {
  bool offline = false;
  int getCalls = 0;
  final sent = <String>[];

  @override
  bool get isDemo => false;
  @override
  void cancelPending() {}
  @override
  Future<Map<String, dynamic>> deviceLogin(String phone) async => {};
  @override
  Future<void> emailVerify(String phone, String email) async {}
  @override
  Future<void> confirm(String otp) async {}
  @override
  Future<Map<String, dynamic>> register(String p, String e) async => {};
  @override
  Future<bool> restoreSession() async => false;
  @override
  Future<String> uploadMedia(String filePath) async => '/api/v1/media/x';
  @override
  Future<String?> currentDeviceId() async => 'device';
  @override
  Future<void> logout() async {}

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String> query = const {},
  }) async {
    getCalls++;
    if (offline) throw const SocketException('offline');
    return {'items': <dynamic>[], 'next_cursor': 'n1'};
  }

  @override
  Future<Map<String, dynamic>> send(
    String path,
    Map<String, dynamic> body, {
    String method = 'POST',
  }) async {
    if (offline) throw const SocketException('offline');
    sent.add('$method $path');
    return {'id': '1'};
  }
}

void main() {
  group('cache keys', () {
    test('query order does not change the key', () {
      expect(
        cacheKeyFor('/feed', {'b': '2', 'a': '1'}),
        cacheKeyFor('/feed', {'a': '1', 'b': '2'}),
      );
      expect(cacheKeyFor('/feed', const {}), '/feed');
    });
  });

  group('MemoryCacheStore', () {
    test('stores, reads back and expires', () async {
      final clock = DateTime(2026, 1, 1);
      var now = clock;
      final store = MemoryCacheStore(clock: () => now);
      await store.write('/a', {'x': 1});
      expect((await store.read('/a'))?['x'], 1);
      now = clock.add(const Duration(days: 9));
      expect(await store.read('/a'), isNull);
      expect(store.misses, 1);
      expect(store.hits, 1);
      await store.clear();
      expect(store.length, 0);
    });
  });

  group('OfflineRepository', () {
    test('caches a GET and serves it when the transport dies', () async {
      final inner = _Repo();
      final cache = MemoryCacheStore();
      final repo = OfflineRepository(
        inner,
        cache: cache,
        queue: MemoryActionQueue(),
      );
      final fresh = await repo.get('/feed');
      expect(fresh['_cached'], isNull);
      await Future<void>.delayed(Duration.zero);
      inner.offline = true;
      final stale = await repo.get('/feed');
      expect(stale['_cached'], isTrue);
      expect(repo.cachedReads, 1);
    });

    test('rethrows when nothing is cached', () async {
      final inner = _Repo()..offline = true;
      final repo = OfflineRepository(
        inner,
        cache: MemoryCacheStore(),
        queue: MemoryActionQueue(),
      );
      expect(repo.get('/feed'), throwsA(isA<SocketException>()));
    });

    test('queues an offline write and reports it', () async {
      final inner = _Repo()..offline = true;
      final queue = MemoryActionQueue();
      QueuedAction? reported;
      final repo = OfflineRepository(
        inner,
        cache: MemoryCacheStore(),
        queue: queue,
        onQueued: (a) => reported = a,
      );
      final result = await repo.send('/feed', {'body': 'hi'});
      expect(result['_queued'], isTrue);
      expect(await queue.length(), 1);
      expect(reported?.path, '/feed');
    });

    test('logout clears cache and queue', () async {
      final cache = MemoryCacheStore();
      final queue = MemoryActionQueue();
      final repo = OfflineRepository(_Repo(), cache: cache, queue: queue);
      await cache.write('/x', {'a': 1});
      await queue.add(path: '/y', body: const {});
      await repo.logout();
      expect(await cache.read('/x'), isNull);
      expect(await queue.length(), 0);
    });
  });

  group('ActionQueuePump', () {
    test('drains in order and stops at the first failure', () async {
      final inner = _Repo();
      final queue = MemoryActionQueue();
      await queue.add(path: '/a', body: const {});
      await queue.add(path: '/b', body: const {});
      final pump = ActionQueuePump(queue: queue, repo: inner);
      expect(await pump.drain(), 2);
      expect(inner.sent, ['POST /a', 'POST /b']);
      expect(await queue.length(), 0);

      await queue.add(path: '/c', body: const {});
      inner.offline = true;
      expect(await pump.drain(), 0);
      expect(await queue.length(), 1);
    });
  });

  group('Hive stores', () {
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('nexus_hive');
      Hive.init(dir.path);
    });
    tearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    test('cache round-trips and ignores corrupt rows', () async {
      final box = await Hive.openBox<dynamic>('cache');
      final store = HiveCacheStore(box);
      await store.write('/feed', {'items': <dynamic>[], 'next_cursor': 'x'});
      expect((await store.read('/feed'))?['next_cursor'], 'x');
      await box.put('/feed', 'not json');
      expect(await store.read('/feed'), isNull);
      await store.clear();
      expect(box.length, 0);
    });

    test('queue persists, sorts and deletes', () async {
      final box = await Hive.openBox<dynamic>('queue');
      final queue = HiveActionQueue(box);
      final a = await queue.add(path: '/a', body: const {'n': 1});
      await queue.add(path: '/b', body: const {}, method: 'PUT');
      expect(await queue.length(), 2);
      final all = await queue.all();
      expect(all.first.path, '/a');
      expect(all.first.body['n'], 1);
      await queue.remove(a.id);
      expect(await queue.length(), 1);
      await queue.clear();
      expect(await queue.length(), 0);
    });
  });
}
