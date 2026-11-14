#!/usr/bin/env bash
# Reset the local development database. Never run this against production.
set -euo pipefail
: "${NEXUS_DATABASE_URL:?set NEXUS_DATABASE_URL first}"
if [[ "${NEXUS_ENV:-}" != "development" ]]; then
  echo "refusing: NEXUS_ENV must be development" >&2; exit 1
fi
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
psql "$NEXUS_DATABASE_URL" -v ON_ERROR_STOP=1 -f "$here/dev-reset.sql"
echo "dev database reset"
