# Nexus v1.1.0 — Go-Live Foundation

Release date: 2026-11-13 · Tag `v1.1.0` · Build `1.1.0+2`

## Backend (Go) — delivered in this release

| Spec | Item | Status |
|---|---|---|
| 1.1 | Media upload API: `POST /api/v1/media` (multipart, 25 MiB), magic-byte sniffing (JPEG/PNG/WebP/MP4), `GET /api/v1/media/{id}` immutable delivery | Done |
| 2.4 | Privacy module persisted: `PATCH /api/v1/users/me/privacy` (`private_account`, `comment_policy` everyone/friends/nobody, DB CHECK) | Done |
| 4.1 | Server-side text validation: length caps, profanity masking, link-spam rejection (>2 URLs) | Done (wire-in pending) |
| 4.4 | Rate limiting on auth + all `/api/*` (in-process, persistent table) | Done |
| 5.1 | Geospatial: `lat`/`lng` columns + **GiST index** `ll_to_earth` (earthdistance/cube — PostGIS absent on this deployment) | Done (index verified) |
| 5.2 | Connection pool: MaxOpen 40, MaxIdle 10, lifetime 30 min | Done |
| 5.3 | Redis cache client (dependency-free RESP2) + graceful degrade to no-cache when `NEXUS_REDIS_ADDR` unset | Done (client + wiring) |
| — | Migration `000005_golive` (media, reactions, geo, privacy, idempotency key, body_cipher) | Applied + rolled back + re-applied on PostgreSQL 16 |

## Flutter — unchanged in this build

The UI work in Sections 1.1–3.4 (media picker, reaction long-press, radar controls, provider split, pagination, offline queue) is **not** in this build. See the status matrix in the delivery message.

## Verification run for this release

- `go vet ./...` — clean
- `go test ./...` — 8/8 packages pass
- `flutter analyze --fatal-infos --fatal-warnings` — no issues
- `flutter test` — 45/45 pass
- Migration round-trip on PostgreSQL 16 — up (1→5), down, up

## Not verified

- APK/IPA build: **no Android SDK or Xcode in this environment** — must be built on a machine with the toolchain.
- Redis caching path against a live server: client compiled, not yet exercised end-to-end by a request.
