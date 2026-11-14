# Nexus v1.4.1 — Test coverage pass (no feature-code change)

Release date: 2026-11-14 · Flutter `1.4.0+4` unchanged · no `lib/` file modified

## What changed
Test-only release. Every item below is new code under `app-flutter/test/`.

1. **Secure-storage channel mocked** (`test/vault_theme_test.dart`)
   `MethodChannel('plugins.it_nomads.com/flutter_secure_storage')` is backed by an
   in-memory map, so `SecureVault` and `ThemeModeController` run through the real plugin
   code path instead of failing with `MissingPluginException`.
   Covered: device-id creation and reuse, session save/read/clear, overlapping writes
   resolving in order, corrupt stored JSON surfacing, and theme preference
   loading / persisting / degrading when storage throws.

2. **Four sheet surfaces widget-tested** (`test/sheets_test.dart`)
   | Surface | Paths exercised |
   |---|---|
   | `CommentsSheet` | list render, reply target, comment like, send |
   | `ShareSheet` | copy link, copy text, save post, QR dialog, repost → composer |
   | `sheets.dart` | `openSheet`, `openComposer` |
   | `NotificationsPanel` | mark-all-read, group/business routing, comment → thread, generic toast |

3. **Boot fallback test** (`test/boot_platform_test.dart`)
   `openOfflineStorage()` with no platform directory → memory stores (`durable: false`);
   with a temp directory → durable Hive cache + queue round-trip. Also covers
   `onlineFrom` result shapes, `MemoryConnectivityMonitor` transitions,
   `PluginConnectivityMonitor` against a mocked channel, `device_actions` launch
   success/refusal, and `startTelemetry` without a DSN.

4. **Supporting suites**: `test/states_test.dart` (every `friendlyError` branch, empty and
   error states, shimmer skeleton, segmented control, pills, badge) and
   `test/settings_scoped_test.dart` (`ScopedRepository` forwarding, cancellation after the
   account is dropped, `SettingsScreen` build + theme toggle).

## Result
| Check | Before | After |
|---|---|---|
| `flutter analyze --fatal-infos --fatal-warnings` | clean | **clean** |
| `flutter test` | 101 passed | **141 passed** |
| Hand-written Dart line coverage | 69.2 % | **81.1 %** |

Coverage comes from `coverage/lcov.info` with generated `.g.dart` / `.freezed.dart` files
excluded (codegen, not hand-written logic).

## Finding for v1.4.2 (feature code, deliberately not changed here)
`SettingsScreen` nests bordered `ListTile`s inside a `DecoratedBox` that has a background
colour. In debug mode Flutter asserts, once per tile:
*"ListTile background color or ink splashes may be invisible."* Release builds are
unaffected; the visible symptom is missing ripple feedback. Fix: wrap each tile in a
`Material` (or drop the intermediate background). The test intercepts exactly that message
through `FlutterError.onError`, counts it and asserts it happened; every other error still
fails the suite.
