# Offline-first architecture (v1.4.0)

```
UI ──► NexusController ──► ScopedRepository ──► OfflineRepository ──► RealRepository ──► HTTP
                                                     │                    │
                                          HiveCacheStore        HiveActionQueue
                                          (last good GET)       (pending writes)
```

- **Reads** are cache-through. A successful `GET` writes `{at, value}` to the `nexus_cache`
  box. A `SocketException` / `ClientException` / `TimeoutException` serves that value and
  marks the payload `_cached: true`. Server errors (4xx/5xx) never fall back to cache —
  they surface, because they are answers.
- **Writes** are queue-behind. The same transport failures enqueue
  `{path, body, method, queued_at}` in `nexus_queue` and return `{_queued: true}`, so the UI
  can render the optimistic result immediately.
- **Replay** happens when connectivity returns: `OfflineScope` listens to the monitor and
  calls `NexusController.syncNow()`, which pumps the queue oldest-first and stops at the
  first failure (ordering over throughput).
- **Degradation**: if Hive cannot open (plugin/platform failure), `openOfflineStorage()`
  falls back to in-memory stores. The app still starts; only durability is lost.
- **Tests**: `MemoryCacheStore` / `MemoryActionQueue` / `MemoryConnectivityMonitor` are the
  defaults in the provider graph, so widget tests never touch a platform channel.
