# Nexus v1.4.2 — Settings tile fix + boot/telemetry tests

Release date: 2026-11-14 · Flutter `1.4.2+5`

## Fixed (feature code — the one change approved for this release)
**`SettingsScreen` ink assertion and invisible ripples.**
`_SettingsTile` wrapped a `ListTile` in a `Container` that carried both the background
colour and the border. Flutter asserts once per tile in debug mode:

> *"ListTile background color or ink splashes may be invisible."*

The wrapper is now `Padding` → `Material(color: surface, shape: RoundedRectangleBorder(
side: border), clipBehavior: antiAlias)` → `ListTile`. The `Material` owns the background,
border and ink, so the assertion is gone and ripples paint. Footer now reads `Nexus 1.4.2`.

## Added (test code)
- `test/settings_screen_test.dart` — **no `FlutterError.onError` interception**: the suite
  asserts `tester.takeException() == null` directly. Covers every group label, the truncated
  device id, back/edit-profile routing, the recovery-email dialog opening and closing,
  sign-out cancelled without tearing down the session, and the empty-email copy. A tall
  surface lays out rows below the fold instead of skipping them.
- `test/boot_test.dart` — starts the real `NexusApp`: auth screen with no session, home
  shell with a stored session, offline banner wrapping the app and clearing on reconnect.
  Telemetry: `startTelemetry` without a DSN, `sentryOptions` fields (dsn/release/
  environment/sample rate/PII), `isConnectivityNoise`, and `beforeSend` dropping transport
  noise while keeping a real crash.
- `test/location_test.dart` — `DeviceLocationService` over a mocked geolocator channel:
  fix returned, permission requested once then granted, service disabled, denied, denied
  forever, platform call throwing; `placeFixProvider`; label formatting.
- `test/chat_inline_test.dart` — chat send, photo attachment through the compressor
  pipeline, sticker pick, dismissed sheet; inline thread listing, sending, liking.
- `test/coverage_extra_test.dart` — `isOfflineError` classification, `OfflineRepository`
  passthrough for auth/upload/device calls (never cached or queued), `LocationTile` with and
  without a fix.
- `test/support/plugins.dart` — one shared set of secure-storage, path-provider and
  geolocator channel fakes.

## Result
| Check | v1.4.1 | v1.4.2 |
|---|---|---|
| `flutter analyze --fatal-infos --fatal-warnings` | clean | **clean** |
| `flutter test` | 141 passed | **168 passed** |
| Hand-written Dart line coverage | 81.10 % | **85.49 %** |
| Debug assertions from `SettingsScreen` | 1 per tile | **none** |

## Telemetry note
`SentryOptions.attachScreenshot` does not exist in the pinned `sentry_flutter`; the default
(off) applies and the assignment was removed rather than guessed at.
