# Nexus v1.4.3 — Plugin-channel tests (no feature-code change)

Release date: 2026-11-14 · Flutter `1.4.2+5` unchanged · no `lib/` file modified

## Added (test code only)
1. **PickerMediaSource** — `FakePicker extends ImagePicker` returns XFile paths with no
   platform dialog: zero remaining slots (picker never called), remaining count forwarded as
   `limit`, video path or null, single image path or null, permission error propagated
   rather than swallowed.
2. **WebPImageCompressor** — video paths pass through untouched; with `path_provider`
   mocked to a temp directory and no encoder registered, the real fallback branch runs and
   the original file is returned, so a post is never blocked by a missing encoder.
3. **videoSeconds** — a `FakeVideoPlatform` over the video_player platform interface
   reports a 47 s clip and the probe returns 47; the 60 s / 25 MB gates are asserted through
   MediaRules.
4. **RealRepository** — every mapped response shape (/users/me, /feed, /notifications,
   /shops/{id}, /groups/{id}, generic item lists), an unmapped payload raising
   FormatException, send mapping and empty-body suppression, session rotation,
   revoked-session sign-out, media upload reference and its failure, and logout clearing the
   vault even when the call fails.
5. **ApiClient guards** — non-HTTPS / decorated origins rejected (a bare path is accepted
   because the client owns the /api/v1 prefix), traversal paths rejected before a request,
   204 empty body => empty map, refresh without a session => LOGIN_REQUIRED, epoch
   invalidation cancelling in-flight work, a 5xx on a mutation surfaced and never retried,
   and uploadFile multipart success plus server error codes.
6. **Hive caps** — the cache trims past 200 entries and the queue past 100, newest kept.
7. **UI variants** — promo and group cards, the video placeholder, tags/music/repost credit,
   carousel counter and tap, video badge, empty carousel, composer add/remove photo,
   cancelled video picker, disabled and enabled publish, feed empty and error states, the
   filter switch, and the full common widget set.

## Result
| Check | v1.4.2 | v1.4.3 |
|---|---|---|
| `flutter analyze --fatal-infos --fatal-warnings` | clean | **clean** |
| `flutter test` | 168 passed | **213 passed** |
| Hand-written Dart line coverage | 85.49 % | **89.90 %** (2999/3336) |

## Deliberately not asserted
`VideoPlayerController` initialisation over a broken platform stream, and a `PageView`
drag inside a vertical scrollable, both leave timers pending / do not flip reliably in the
test binding. Those two cases were replaced with equivalent real branches instead of being
left flaky.
