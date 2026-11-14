import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/offline/action_queue.dart';
import '../../data/offline/cache_store.dart';
import '../../data/offline/connectivity.dart';

/// Defaults are in-memory so widget tests and plain `flutter run` work without
/// platform plugins. `main()` overrides them with the durable stores.
final cacheStoreProvider = Provider<CacheStore>((ref) => MemoryCacheStore());
final actionQueueProvider = Provider<ActionQueue>(
  (ref) => MemoryActionQueue(),
);
final connectivityProvider = Provider<ConnectivityMonitor>(
  (ref) => MemoryConnectivityMonitor(),
);

final onlineProvider = StreamProvider<bool>((ref) async* {
  final monitor = ref.watch(connectivityProvider);
  yield await monitor.isOnline;
  yield* monitor.changes;
});

final pendingWritesProvider = FutureProvider<int>(
  (ref) => ref.watch(actionQueueProvider).length(),
);
