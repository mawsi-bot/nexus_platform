import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexus/data/api_client.dart';
import 'package:nexus/data/offline/hive_action_queue.dart';
import 'package:nexus/data/offline/hive_cache_store.dart';
import 'package:nexus/data/real_repository.dart';
import 'package:nexus/data/vault.dart';
import 'package:nexus/domain/models.dart';

const base = 'https://api.nexus.test';

MockClient client(
  Map<String, dynamic> Function(http.Request request) handler, {
  void Function(http.Request request)? onRequest,
}) => MockClient((request) async {
  onRequest?.call(request);
  final result = handler(request);
  final status = result['_status'] as int? ?? 200;
  final body = Map<String, dynamic>.from(result)..remove('_status');
  return http.Response(jsonEncode(body), status, headers: {
    'content-type': 'application/json',
  });
});

RealRepository repoFor(
  Map<String, dynamic> Function(http.Request) handler, {
  Vault? vault,
  void Function(http.Request)? onRequest,
}) => RealRepository(
  ApiClient(base, vault ?? MemoryVault(), client: client(handler, onRequest: onRequest)),
);

void main() {
  group('RealRepository.get', () {
    test('maps every documented backend response shape', () async {
      final repo = repoFor((r) {
        switch (r.url.path) {
          case '/api/v1/users/me':
            return {'id': 7, 'name': 'Me', 'bio': 'b', 'email_verified': true};
          case '/api/v1/feed':
            return {
              'items': [
                {'id': 1, 'body': 'one', 'author_id': 7},
              ],
              'next_cursor': 'c1',
            };
          case '/api/v1/notifications':
            return {
              'items': [
                {'id': 2, 'body': 'liked', 'kind': 'like', 'read': false},
              ],
            };
          case '/api/v1/shops/5':
            return {'id': 5, 'name': 'Cafe', 'visibility': 'public'};
          case '/api/v1/groups/6':
            return {'id': 6, 'name': 'Runners'};
          default:
            return {
              'items': [
                {'id': 9, 'kind': 'shop', 'name': 'Tea', 'price_minor': 100},
              ],
            };
        }
      });

      expect((await repo.get('/users/me'))['title'], 'Me');
      final feed = await repo.get('/feed');
      expect((feed['items'] as List).length, 1);
      expect(feed['next_cursor'], 'c1');
      expect((await repo.get('/notifications'))['items'], isNotEmpty);
      expect((await repo.get('/shops/5'))['reviews'], isEmpty);
      expect((await repo.get('/groups/6'))['rules'], isEmpty);
      final list = await repo.get('/discover', query: {'type': 'shops'});
      expect((list['items'] as List).length, 1);
    });

    test('an unmapped response is a format error, not silent data loss',
        () async {
      final repo = repoFor((_) => {'unexpected': true});
      expect(repo.get('/mystery'), throwsFormatException);
    });
  });

  group('RealRepository.send', () {
    test('maps the profile response and id-bearing responses', () async {
      final repo = repoFor((r) {
        if (r.url.path.endsWith('/users/me')) {
          return {'id': 7, 'name': 'Me', 'bio': 'new'};
        }
        return {'id': 12};
      });
      final profile = await repo.send('/users/me', {'bio': 'new'}, method: 'PATCH');
      expect(profile['bio'], 'new');
      final created = await repo.send('/feed', {'body': 'x'});
      expect(created['id'], '12');
      final plain = await repoFor((_) => {'ok': true}).send('/x', {});
      expect(plain['ok'], isTrue);
    });

    test('no body is sent when the map is empty', () async {
      String? method;
      String? body;
      final repo = repoFor((r) {
        method = r.method;
        body = r.body;
        return {'ok': true};
      });
      await repo.send('/items/1/like', {}, method: 'PUT');
      expect(method, 'PUT');
      expect(body, isEmpty);
    });
  });

  group('RealRepository session and media', () {
    test('restoreSession is false without a stored session', () async {
      final repo = repoFor((_) => {'ok': true});
      expect(await repo.restoreSession(), isFalse);
    });

    test('restoreSession rotates and stores the session', () async {
      final vault = MemoryVault();
      await vault.save(const Session(jwt: 'old', refresh: 'r1'));
      final repo = repoFor((r) {
        expect(r.url.path, '/api/v1/auth/refresh');
        return {'jwt': 'new', 'refresh': 'r2'};
      }, vault: vault);
      expect(await repo.restoreSession(), isTrue);
      expect((await vault.session())?.jwt, 'new');
    });

    test('restoreSession treats a revoked session as signed out', () async {
      final vault = MemoryVault();
      await vault.save(const Session(jwt: 'old', refresh: 'r1'));
      final repo = repoFor(
        (_) => {'_status': 401, 'error': 'REFRESH_REJECTED'},
        vault: vault,
      );
      expect(await repo.restoreSession(), isFalse);
      expect(await vault.session(), isNull);
    });

    test('uploadMedia returns the media reference or fails loudly', () async {
      final dir = await Directory.systemTemp.createTemp('nexus_upload');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/a.webp')..writeAsBytesSync([1, 2, 3]);

      final ok = RealRepository(ApiClient(base, MemoryVault(),
          client: MockClient((_) async => http.Response(
              jsonEncode({'url': '/api/v1/media/${'c' * 32}'}), 201))));
      expect(await ok.uploadMedia(file.path), startsWith('/api/v1/media/'));

      final missing = RealRepository(ApiClient(base, MemoryVault(),
          client: MockClient((_) async => http.Response('{}', 200))));
      expect(missing.uploadMedia(file.path), throwsFormatException);
    });

    test('logout clears the vault even when the call fails', () async {
      final vault = MemoryVault();
      await vault.save(const Session(jwt: 'j', refresh: 'r'));
      final repo = repoFor(
        (_) => {'_status': 500, 'error': 'DOWN'},
        vault: vault,
      );
      await expectLater(repo.logout(), throwsA(isA<ApiException>()));
      expect(await vault.session(), isNull);
    });

    test('device id is exposed for the settings screen', () async {
      final vault = MemoryVault();
      final repo = repoFor((_) => {'ok': true}, vault: vault);
      expect(await repo.currentDeviceId(), await vault.deviceId());
      expect(repo.isDemo, isFalse);
      repo.cancelPending();
    });
  });

  group('ApiClient.uploadFile', () {
    test('posts multipart and returns the decoded body', () async {
      final dir = await Directory.systemTemp.createTemp('nexus_api_upload');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/a.webp')..writeAsBytesSync([9, 9, 9]);
      final vault = MemoryVault();
      await vault.save(const Session(jwt: 'jwt', refresh: 'ref'));
      String? contentType;
      final api = ApiClient(base, vault, client: MockClient((r) async {
        contentType = r.headers['content-type'];
        return http.Response(jsonEncode({'url': '/api/v1/media/x'}), 201);
      }));
      final data = await api.uploadFile(file.path, 'file');
      expect(data['url'], '/api/v1/media/x');
      expect(contentType, contains('multipart/form-data'));
    });

    test('an upload error surfaces the server code', () async {
      final dir = await Directory.systemTemp.createTemp('nexus_api_upload2');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/a.webp')..writeAsBytesSync([1]);
      final api = ApiClient(base, MemoryVault(),
          client: MockClient((_) async =>
              http.Response(jsonEncode({'error': 'UNSUPPORTED_MEDIA'}), 415)));
      expect(
        api.uploadFile(file.path, 'file'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'UNSUPPORTED_MEDIA')),
      );
    });
  });

  group('Hive store limits', () {
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('nexus_limits');
      Hive.init(dir.path);
    });
    tearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    test('the cache trims itself once it passes the cap', () async {
      final box = await Hive.openBox<dynamic>('cap_cache');
      final store = HiveCacheStore(box);
      for (var i = 0; i < HiveCacheStore.maxEntries + 5; i++) {
        await store.write('/k$i', {'i': i});
      }
      expect(box.length, lessThanOrEqualTo(HiveCacheStore.maxEntries));
      expect(await store.read('/k${HiveCacheStore.maxEntries + 4}'), isNotNull);
    });

    test('the queue drops the oldest actions past its cap', () async {
      final box = await Hive.openBox<dynamic>('cap_queue');
      final queue = HiveActionQueue(box);
      for (var i = 0; i < HiveActionQueue.maxActions + 3; i++) {
        await queue.add(path: '/p$i', body: {'i': i});
      }
      expect(await queue.length(), lessThanOrEqualTo(HiveActionQueue.maxActions));
      final all = await queue.all();
      expect(all.last.path, '/p${HiveActionQueue.maxActions + 2}');
    });
  });

  group('ApiClient guards', () {
    test('rejects a non-HTTPS or decorated origin', () {
      for (final bad in [
        'http://api.nexus.test',
        'https://api.nexus.test?x=1',
        'https://user:pw@api.nexus.test',
        'https:///nohost',
      ]) {
        expect(() => ApiClient(bad, MemoryVault()), throwsArgumentError,
            reason: bad);
      }
      // A path on the origin is accepted; the client owns the /api/v1 prefix.
      expect(() => ApiClient('https://api.nexus.test/path', MemoryVault()),
          returnsNormally);
    });

    test('rejects a traversal path before any request is made', () async {
      final api = ApiClient(base, MemoryVault(), client: client((_) => {}));
      expect(api.request('GET', 'users/me'), throwsArgumentError);
      expect(api.request('GET', '/a/../b'), throwsArgumentError);
    });

    test('an empty body answers with an empty map', () async {
      final api = ApiClient(base, MemoryVault(),
          client: MockClient((_) async => http.Response('', 204)));
      expect(await api.request('GET', '/feed'), containsPair('_status', 204));
    });

    test('refresh without a session is a login error', () async {
      final api = ApiClient(base, MemoryVault(), client: client((_) => {}));
      expect(
        api.refreshNow(),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'LOGIN_REQUIRED')),
      );
    });

    test('invalidating requests cancels an in-flight call', () async {
      final api = ApiClient(base, MemoryVault(), client: client((_) => {}));
      api.invalidateRequests();
      expect(() => api.checkEpoch(0), throwsA(isA<RequestCancelled>()));
      expect(() => api.checkEpoch(api.epoch), returnsNormally);
    });

    test('a 5xx on a mutation is surfaced, never retried', () async {
      var calls = 0;
      final api = ApiClient(base, MemoryVault(), client: client((_) {
        calls++;
        return {'_status': 503, 'error': 'UNAVAILABLE'};
      }));
      await expectLater(
        api.request('POST', '/feed', body: const {'body': 'x'}),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 503)),
      );
      expect(calls, 1);
    });
  });
}
