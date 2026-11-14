import 'dart:convert';

/// Narrow JSON cache so the app stays usable without a network.
///
/// Values are plain maps, which keeps the Hive implementation and the
/// in-memory one used by tests behaviourally identical.
abstract interface class CacheStore {
  Future<void> write(String key, Map<String, dynamic> value);
  Future<Map<String, dynamic>?> read(
    String key, {
    Duration maxAge = const Duration(days: 7),
  });
  Future<void> clear();
}

/// Stable key for a GET, independent of query-parameter order.
String cacheKeyFor(String path, Map<String, String> query) {
  if (query.isEmpty) return path;
  final keys = query.keys.toList()..sort();
  return '$path?${keys.map((k) => '$k=${query[k]}').join('&')}';
}

class _Envelope {
  _Envelope(this.at, this.value);
  final DateTime at;
  final Map<String, dynamic> value;
}

class MemoryCacheStore implements CacheStore {
  MemoryCacheStore({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;
  final DateTime Function() _clock;
  final Map<String, _Envelope> _data = {};
  int writes = 0;
  int hits = 0;
  int misses = 0;
  int get length => _data.length;

  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    writes++;
    _data[key] = _Envelope(
      _clock(),
      jsonDecode(jsonEncode(value)) as Map<String, dynamic>,
    );
  }

  @override
  Future<Map<String, dynamic>?> read(
    String key, {
    Duration maxAge = const Duration(days: 7),
  }) async {
    final hit = _data[key];
    if (hit == null || _clock().difference(hit.at) > maxAge) {
      misses++;
      return null;
    }
    hits++;
    return hit.value;
  }

  @override
  Future<void> clear() async {
    _data.clear();
  }
}
