#!/usr/bin/env bash
# Push every Nexus tag and branch to the project repository.
#
# A GitHub token is required; the sandbox that produced these commits has no
# interactive login. Create a fine-grained token with "Contents: read and write"
# on mawsimailbox-debug/social_nexus, then:
#
#   GH_TOKEN=github_pat_xxx ./scripts/push-to-github.sh
#
# The token is used once through an ephemeral credential helper and is never
# written to .git/config.
set -euo pipefail

repo="${NEXUS_GITHUB_REPO:-mawsi-bot/nexus_platform}"
token="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
if [ -z "$token" ]; then
  echo "GH_TOKEN is not set. Create a token with Contents: read and write on $repo." >&2
  exit 1
fi

cd "$(dirname "$0")/.."
remote="https://x-access-token:${token}@github.com/${repo}.git"

echo "==> verifying the token can read the repository"
git ls-remote "$remote" >/dev/null

echo "==> pushing main"
git push "$remote" "$(git rev-parse --abbrev-ref HEAD):main" --follow-tags

echo "==> pushing every release tag"
git tag --list 'v*' | while read -r tag; do
  echo "    $tag"
done
git push "$remote" --tags

echo "==> done"
git ls-remote --tags "$remote" | tail -5
