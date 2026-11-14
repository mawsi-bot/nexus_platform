# Pushing this repository to GitHub

The sandbox that produced these commits has **no GitHub credentials**: `gh auth
status` reports no login, and `git push` fails with
`could not read Username for 'https://github.com'`. Nothing was pushed from here,
and no token was stored in `.git/config`.

The remote is already configured:

```
origin  https://github.com/mawsimailbox-debug/social_nexus.git
```

## One command, from your machine

```bash
cd nexus
GH_TOKEN=github_pat_xxxxxxxx ./scripts/push-to-github.sh
```

The script:

1. verifies the token can read `mawsimailbox-debug/social_nexus`,
2. pushes the current branch to `main` with `--follow-tags`,
3. pushes every `v*` tag (v0.1.0-rc1 … v1.5.0),
4. prints the remote tags so you can confirm.

It passes the token as an ephemeral credential in the URL — it is never written to
git config or to a file.

## Manual equivalent

```bash
git remote set-url origin https://github.com/mawsimailbox-debug/social_nexus.git
git push -u origin main
git push origin --tags
```

## After the first push

1. **Settings → Actions → General** — allow workflows to run.
2. **Settings → Secrets and variables → Actions**, add:

| Kind | Name | Value |
|---|---|---|
| Secret | `NEXUS_ANDROID_KEYSTORE_BASE64` | `base64 -w0 nexus-release.jks` |
| Secret | `NEXUS_ANDROID_KEYSTORE_PASSWORD` | keystore password |
| Secret | `NEXUS_ANDROID_KEY_ALIAS` | `nexus` |
| Secret | `NEXUS_ANDROID_KEY_PASSWORD` | key password |
| Secret | `SENTRY_DSN` | optional, enables crash reporting |
| Variable | `NEXUS_API_URL` | e.g. `https://api.nexus.app` |

3. **Branch protection on `main`** — require `backend`, `flutter`, `design-guard`
   and `secrets` to pass before merging.
4. Push a tag to produce signed artefacts: `git tag -a v1.5.0 -m "…" && git push origin v1.5.0`.
   The `android` job is skipped with a visible notice when the signing secrets are
   absent (it does not fail the pipeline).

## What the pipeline runs

| Job | Trigger | What it proves |
|---|---|---|
| `backend` | every push/PR | `go vet`, build, migrations 000001–000007 up **and** down/up round-trip, `go test -race`, gofmt clean |
| `flutter` | every push/PR | `flutter analyze --fatal-infos --fatal-warnings`, full test suite, **coverage gate ≥ 91 %** |
| `web` | every push/PR | `flutter build web --release` |
| `android` | tag or manual | signed per-ABI APKs + AAB, signature verified with `apksigner`, artefacts + symbols uploaded |
| `design-guard` | every push/PR | the approved design HTML md5 is unchanged |
| `secrets` | every push/PR | gitleaks finds no committed secret |
