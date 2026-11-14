#!/usr/bin/env bash
# Fresh-database rehearsal of the device-rebind recovery flow.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB="${NEXUS_E2E_DB:-nexus_recovery}"
MAIL="$(mktemp -t nexus-mail-XXXXXX.log)"
export PATH="/home/user/workspace/toolchains/go/bin:$PATH"
cd "$ROOT/backend-go"
sudo -n -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${DB}'" | grep -q 1 \
  || sudo -n -u postgres createdb "${DB}"
sudo -n -u postgres psql -q -d "${DB}" < "$ROOT/backend-go/migrations/000001_init.up.sql"
sudo -n -u postgres psql -q -d "${DB}" < "$ROOT/backend-go/migrations/000002_activity.up.sql"
sudo -n -u postgres psql -q -d "${DB}" < "$ROOT/backend-go/migrations/000003_source_metadata.up.sql"
K1=$(head -c32 /dev/urandom | base64 -w0); K2=$(head -c32 /dev/urandom | base64 -w0); K3=$(head -c32 /dev/urandom | base64 -w0)
export NEXUS_ENV=development \
       NEXUS_DATABASE_URL="postgres:///${DB}?host=/var/run/postgresql&sslmode=disable" \
       NEXUS_JWT_KEY="$K1" NEXUS_ENCRYPTION_KEY="$K2" NEXUS_LOOKUP_KEY="$K3" \
       NEXUS_EMAIL_FROM=no-reply@nexus.local NEXUS_EMAIL_SINK_FILE="$MAIL" \
       NEXUS_ADDR=127.0.0.1:18085 NEXUS_RATE_LIMIT_DISABLED=1
go build -o /tmp/recovery-api ./cmd/api
/tmp/recovery-api >/tmp/recovery-api.log 2>&1 &
APIPID=$!
trap 'kill $APIPID 2>/dev/null || true; rm -f "$MAIL"' EXIT
for _ in $(seq 1 60); do curl -fsS http://127.0.0.1:18085/healthz >/dev/null 2>&1 && break; sleep 0.2; done
NEXUS_E2E_MAIL="$MAIL" NEXUS_E2E_API=http://127.0.0.1:18085 python3 "$ROOT/scripts/e2e-recovery.py"
