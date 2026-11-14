# Production deploy — Nexus backend

## 1. Required environment

| Variable | Required | Notes |
|---|---|---|
| `NEXUS_DATABASE_URL` | yes | `postgres://…?sslmode=require` in production |
| `NEXUS_JWT_KEY` | yes | 32 random bytes, base64. Rotating it signs everyone out |
| `NEXUS_ENCRYPTION_KEY` | yes | 32 bytes base64 — encrypts phone/email columns. **Losing it loses recoverability** |
| `NEXUS_LOOKUP_KEY` | yes | 32 bytes base64 — keyed hash for contact lookup |
| `NEXUS_ENV` | yes | `production` |
| `NEXUS_EMAIL_FROM` | yes | sender for recovery mail |
| `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `SMS_FROM` | for SMS | omit and the endpoint answers `503` instead of pretending |
| `NEXUS_REDIS_URL` | recommended | rate limits / cache; the client degrades to a no-op |
| `NEXUS_MEDIA_DIR` | yes | volume for uploaded media, backed up daily |
| `SENTRY_DSN` (Flutter) | optional | crash reporting in the app build |

Generate keys: `head -c 32 /dev/urandom | base64 -w0` — three different values.

## 2. Database

```bash
cd backend-go
NEXUS_DATABASE_URL=… go run ./cmd/migrate up     # applies 000001..000007
NEXUS_DATABASE_URL=… go run ./cmd/migrate status
```

Migrations are forward-only in production; the CI job proves the up → down → up
round-trip on a clean database before a release tag is cut.

Confirm the geo index exists (PostGIS is not required):

```sql
SELECT indexname FROM pg_indexes WHERE tablename = 'items' AND indexname = 'items_geo_idx';
```
A missing `items_geo_idx` silently degrades "Nearby" to a full scan.

## 3. Build and run

```bash
cd backend-go
CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o nexus-api ./cmd/api
./nexus-api        # reads the environment above; listens on :8080
```

Run it behind TLS termination. The app refuses a non-HTTPS origin, so a plain
HTTP deployment cannot connect at all.

Health check: `GET /healthz` → `200`. Readiness for the database is reported by
`GET /healthz?db=1`.

## 4. Smoke test after deploy

```bash
BASE=https://api.nexus.app/api/v1
curl -sf "$BASE/../healthz"                                   # 200
curl -s -o /dev/null -w '%{http_code}\n' -X POST "$BASE/auth/register" \
  -H 'content-type: application/json' \
  -d '{"phone_number":"+959000000000","email":"","device_id":"smoke-device"}'
# 200 with jwt+refresh, then repeat with the same device_id to prove the unique index
curl -s -o /dev/null -w '%{http_code}\n' -X POST "$BASE/media"  # 401 without a token
```

Then install the APK built by the pipeline and sign in with a real number.

## 5. Rollback

| Situation | Action |
|---|---|
| Bad app release | halt the staged rollout in Play Console; the previous APK stays live |
| Bad API deploy | redeploy the previous binary; migrations are additive so the old binary still reads the schema |
| Bad migration | restore the pre-deploy snapshot — `go run ./cmd/migrate down` is for CI, not production |
| Suspected key leak | rotate `NEXUS_JWT_KEY` (all sessions end), then `NEXUS_ENCRYPTION_KEY` with a re-encrypt job |

## 6. Backups

Nightly `pg_dump` plus a media volume snapshot, kept 30 days, restore-tested
monthly. The encryption key is stored in the secret manager, **not** in the
backup bucket — a backup without the key cannot recover contact details.
