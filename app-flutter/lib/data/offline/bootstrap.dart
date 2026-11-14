import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'action_queue.dart';
import 'cache_store.dart';
import 'hive_action_queue.dart';
import 'hive_cache_store.dart';

class OfflineStorage {
  const OfflineStorage(this.cache, this.queue, {this.durable = true});
  final CacheStore cache;
  final ActionQueue queue;
  final bool durable;
}

/// Opens the durable stores. Any platform/plugin failure degrades to memory
/// stores so the app still starts (offline support is not a launch blocker).
Future<OfflineStorage> openOfflineStorage() async {
  try {
    await Hive.initFlutter();
    final cache = await HiveCacheStore.open();
    final queue = await HiveActionQueue.open();
    return OfflineStorage(cache, queue);
  } catch (error, stack) {
    debugPrint('Offline storage unavailable, using memory: $error\n$stack');
    return OfflineStorage(MemoryCacheStore(), MemoryActionQueue(), durable: false);
  }
}
