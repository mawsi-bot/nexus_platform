import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../domain/repository.dart';
import 'action_queue.dart';
import 'cache_store.dart';

/// Transport failures only. A 4xx/5xx is a server answer and must surface.
bool isOfflineError(Object error) =>
    error is SocketException ||
    error is http.ClientException ||
    error is TimeoutException;

/// Read-through cache + write-behind queue in front of the real repository.
///
/// * GET  → success refreshes the cache; a transport failure serves the last
///          good page (marked `_cached: true`).
/// * POST → a transport failure queues the write and returns `_queued: true`
///          so the UI can show the optimistic result immediately.
class OfflineRepository implements NexusRepository {
  OfflineRepository(
    this.delegate, {
    required this.cache,
    required this.queue,
    this.onQueued,
  });
  final NexusRepository delegate;
  final CacheStore cache;
  final ActionQueue queue;
  final void Function(QueuedAction action)? onQueued;
  int cachedReads = 0;

  @override
  bool get isDemo => delegate.isDemo;
  @override
  void cancelPending() => delegate.cancelPending();
  @override
  Future<Map<String, dynamic>> deviceLogin(String phone) =>
      delegate.deviceLogin(phone);
  @override
  Future<void> emailVerify(String phone, String email) =>
      delegate.emailVerify(phone, email);
  @override
  Future<void> confirm(String otp) => delegate.confirm(otp);
  @override
  Future<Map<String, dynamic>> register(String phone, String email) =>
      delegate.register(phone, email);
  @override
  Future<bool> restoreSession() => delegate.restoreSession();
  @override
  Future<String> uploadMedia(String filePath) => delegate.uploadMedia(filePath);
  @override
  Future<String?> currentDeviceId() => delegate.currentDeviceId();
  @override
  Future<void> logout() async {
    await queue.clear();
    await cache.clear();
    await delegate.logout();
  }

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String> query = const {},
  }) async {
    final key = cacheKeyFor(path, query);
    try {
      final data = await delegate.get(path, query: query);
      unawaited(cache.write(key, data));
      return data;
    } catch (error) {
      if (!isOfflineError(error)) rethrow;
      final hit = await cache.read(key);
      if (hit == null) rethrow;
      cachedReads++;
      return {...hit, '_cached': true};
    }
  }

  @override
  Future<Map<String, dynamic>> send(
    String path,
    Map<String, dynamic> body, {
    String method = 'POST',
  }) async {
    try {
      return await delegate.send(path, body, method: method);
    } catch (error) {
      if (!isOfflineError(error) || method == 'GET') rethrow;
      final action = await queue.add(path: path, body: body, method: method);
      onQueued?.call(action);
      return {'_queued': true};
    }
  }
}
