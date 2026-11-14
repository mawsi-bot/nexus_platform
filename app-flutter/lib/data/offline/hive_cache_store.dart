import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import 'cache_store.dart';

/// Hive-backed cache. Entries are JSON strings so a schema change can never
/// break an old box, and the box is capped so it cannot grow without bound.
class HiveCacheStore implements CacheStore {
  HiveCacheStore(this.box);
  final Box<dynamic> box;
  static const maxEntries = 200;

  static Future<HiveCacheStore> open([String name = 'nexus_cache']) async =>
      HiveCacheStore(await Hive.openBox<dynamic>(name));

  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    await box.put(
      cacheKeyFor(key, const {}),
      jsonEncode({
        'at': DateTime.now().toUtc().toIso8601String(),
        'value': value,
      }),
    );
    if (box.length > maxEntries) await _trim();
  }

  Future<void> _trim() async {
    final entries = <MapEntry<dynamic, String>>[];
    for (final k in box.keys) {
      final raw = box.get(k);
      if (raw is! String) continue;
      try {
        final at = (jsonDecode(raw) as Map)['at'];
        entries.add(MapEntry(k, '$at'));
      } catch (_) {
        await box.delete(k);
      }
    }
    entries.sort((a, b) => a.value.compareTo(b.value));
    for (final e in entries.take(box.length - maxEntries)) {
      await box.delete(e.key);
    }
  }

  @override
  Future<Map<String, dynamic>?> read(
    String key, {
    Duration maxAge = const Duration(days: 7),
  }) async {
    final raw = box.get(cacheKeyFor(key, const {}));
    if (raw is! String) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final at = DateTime.parse('${decoded['at']}');
      if (DateTime.now().toUtc().difference(at) > maxAge) return null;
      return Map<String, dynamic>.from(decoded['value'] as Map);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clear() => box.clear();
}
