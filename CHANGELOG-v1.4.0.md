# Nexus v1.4.0 — Offline-First + Full Section 1–5

Release date: 2026-11-14 · Flutter `1.4.0+4` · backend unchanged (`v1.2.0` API, migration `000007`)

## Added — Section 2 (composer media)
- Photo picker with a hard cap of **4** images, per-image removal, thumbnail strip.
- Video picker validated on-device: **≤ 25 MB and ≤ 60 s** (`MediaRules.validateVideo`).
  Duration is read with `video_player`; an unreadable clip is refused instead of uploaded.
- Images are re-encoded to **WebP** (max edge 1440 px, q82) before upload, so a 4 MB
  camera JPEG travels as ~700 KB. Videos are not re-encoded on device.
- Media is uploaded **before** the post is created, so a queued post never references a
  file the server does not have.
- Cards render a swipeable carousel with a counter (`1/4`) and page dots.

## Added — Section 3 (engagement)
- **Inline comment**: the comment button expands a thread inside the card, with an input,
  optimistic append and per-comment likes. No sheet, no navigation.
- **Report / Hide** in a per-post overflow menu; hide removes the card immediately.
- **@mention**: inline suggestion strip in the composer, comment field and chat
  (`activeMention` / `suggestMentions` / `applyMention`), and mention highlighting in
  post bodies.
- **Reactions**: flat action bar (`react · comment · share · save · more`), long-press
  reaction picker (`❤️ 🤗 💪`), optimistic counts with rollback on failure, summary bar
  (`❤️ 128 · 🤗 24`) and a filterable who-reacted sheet.

## Added — Section 4 (chat)
- Attachment sheet: **Photo** (compressed WebP → `POST /media` → message with `kind=image`)
  and **Sticker** (three bundled packs, 36 glyphs, works offline).
- Stickers render free-floating at 46 px; images render as 210 px rounded thumbnails.
- Failed sends remove the optimistic bubble instead of leaving a ghost message.

## Added — Section 5 (pagination)
- Cursor pagination on `/feed` (`?cursor=&limit=20`), de-duplicated by post id, with a
  prefetch at 400 px from the bottom and a spinner row while a page loads.
- `next_cursor` empty ⇒ `hasMore=false`; demo data is a single page.

## Added — Offline-first
| Layer | File | Behaviour |
|---|---|---|
| Cache | `lib/data/offline/cache_store.dart`, `hive_cache_store.dart` | Every successful GET is written to Hive (capped at 200 entries, 7-day TTL). |
| Decorator | `offline_repository.dart` | Transport failure ⇒ serve the last good page (`_cached: true`); 4xx/5xx still surface. |
| Queue | `action_queue.dart`, `hive_action_queue.dart` | A write made offline is stored durably and replayed oldest-first. |
| Pump | `ActionQueuePump` | Stops at the first failure so ordering is preserved. |
| Connectivity | `connectivity.dart` | `connectivity_plus`, version-agnostic result parsing, memory fake for tests. |
| Banner | `widgets/offline_banner.dart` | “Offline — N changes will sync…” / “Back online — sending N…”. |

## Added — Lightweight update
- Android **per-ABI split APKs** (`armeabi-v7a`, `arm64-v8a`, `x86_64`) and
  `isMinifyEnabled` + `isShrinkResources` in `android/app/build.gradle.kts`.
- **AAB** documented as the store artefact; WebP uploads; **code obfuscation** via
  `--obfuscate --split-debug-info` in `docs/BUILD_VERIFICATION.md §8`.

## Added — Error reporting
- `sentry_flutter` via `lib/data/telemetry.dart`. Without `--dart-define=SENTRY_DSN` the app
  runs normally with telemetry disabled (no crash, no silent failure).
- `RequestCancelled` / `SocketException` / `ClientException` are dropped in `beforeSend`:
  going offline is expected behaviour, not a crash.

## Verification
| Check | Result |
|---|---|
| `flutter analyze --fatal-infos --fatal-warnings` | **No issues found** |
| `flutter test` | **101 / 101 passed** |
| `go test ./...` | **8 / 8 packages ok** |
| Line coverage (hand-written Dart) | **69.2 %** — target 80 % **not met** |

### Coverage gap (honest)
Uncovered: `bootstrap.dart`, `telemetry.dart` (both startup-only, need integration runs),
`comments_sheet.dart`, `share_sheet.dart`, `sheets.dart`, `notifications.dart`,
`device_actions.dart`, `vault.dart`, `theme_mode.dart`, `connectivity.dart` plugin path,
`profile_grid.dart`, and parts of `states.dart`. Reaching 80 % needs widget tests for the
sheet/menu surfaces plus a mocked `flutter_secure_storage` channel.

## Known limitations
- No APK/IPA is produced in this environment (no Android SDK, no Xcode).
- Video duration check uses `video_player`, which needs a real device/emulator to verify.
- Sticker packs are glyph-based, not artwork PNGs.
- Offline video upload is not queued (the media upload happens before the post).
