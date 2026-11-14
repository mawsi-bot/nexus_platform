# Nexus v1.2.0 — SMS Gateway Restored

Release date: 2026-11-14 · Tag `v1.2.0`

Per owner decision (2026-11-13): SMS is back. `SMS_FROM` + Twilio credentials are
read from the environment; a missing configuration is a 503, never a silent success.

## Added

| Area | Change |
|---|---|
| `internal/sms` | Twilio Messages REST client (HTTPS, Basic auth, 8 s timeout). No SDK dependency. `FromEnv()` builds it from `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `SMS_FROM`. |
| `POST /api/v1/users/me/phone/verification` | Sends a 5-minute one-time code to the account's own number. `202 CHECK_SMS`; `503 unavailable` when unconfigured; `429` on the second request inside a minute. |
| `POST /api/v1/users/me/phone/confirm` | Redeems the code and sets `users.phone_verified`. Single use, 5 attempts, never touches the device binding. |
| Migration `000006_phone_verified` | `users.phone_verified boolean NOT NULL DEFAULT false`. |
| Media references | `POST /feed` accepts `media_url` **only** as `/api/v1/media/{32-hex}` minted by this API, stored in `items.metadata`. |

## Tests

- `internal/sms`: form encoding, Basic auth, provider 401 surfaces as an error, partial config yields a nil sender.
- `internal/auth`: SMS delivered to the right number, code redeems → `phone_verified`, single use, wrong code rejected, one message per minute, unconfigured → 503-class error, provider failure is fail-closed.
- `internal/httpapi`: unconfigured endpoint returns 503; configured returns 202 and sends exactly one message.

## Verification

- `go vet ./...` clean, `go test ./...` 9/9 packages pass (new `internal/sms`).
- Migration round-trip on PostgreSQL 16: up 1→6, down, up.
- `flutter analyze --fatal-infos --fatal-warnings` clean, `flutter test` 45/45 — Flutter untouched.

## Still open (Flutter Sections 1–3)

Media picker UI, post spinner polish, theme switching, long-press reactions, radar
controls, privacy UI, provider split, compression/caching, pagination and the offline
queue are **not** in this release. See the delivery report for the plan.
