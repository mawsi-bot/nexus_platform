# Reset the local development database (Windows / Docker on port 5433).
# Usage:  .\scripts\dev-reset.ps1
#   override with -Dsn "postgresql://nexus:nexus@127.0.0.1:5433/nexus"
param(
  [string]$Dsn = $env:NEXUS_DATABASE_URL
)
$ErrorActionPreference = "Stop"
if (-not $Dsn) { $Dsn = "postgresql://nexus:nexus@127.0.0.1:5433/nexus" }
$sql = Join-Path $PSScriptRoot "dev-reset.sql"
$psql = Get-Command psql -ErrorAction SilentlyContinue
if ($psql) {
  & $psql.Source $Dsn -v ON_ERROR_STOP=1 -f $sql
} else {
  # Fall back to the client inside the Docker container.
  Write-Host "psql not found; using the postgres container"
  Get-Content $sql | docker exec -i nexus-postgres psql -U nexus -d nexus -v ON_ERROR_STOP=1
}
if ($LASTEXITCODE -ne 0) { throw "reset failed" }
Write-Host "dev database reset"
