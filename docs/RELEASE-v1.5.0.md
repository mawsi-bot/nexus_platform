# v1.5.0 — Production deploy package

Date: 2026-11-14 · Flutter `1.4.2+5` · backend migration head `000007`

## Deliverables in this release

| Item | State | Where |
|---|---|---|
| GitHub push | **blocked in sandbox** — no credentials; remote configured, one-command script ready | `docs/GITHUB-PUSH.md`, `scripts/push-to-github.sh` |
| CI/CD pipeline | **written and validated** | `.github/workflows/ci.yml` |
| APK / AAB build | **cannot run here** — no Android SDK; pipeline job + local commands provided | `.github/workflows/ci.yml` (`android`), `docs/BUILD_VERIFICATION.md` |
| Play icon 512×512 32-bit | **generated** | `store/icon-512.png` |
| Feature graphic 1024×500 | **generated** | `store/feature-graphic-1024x500.png` |
| Phone screenshots | **must be captured on a device** — no emulator here | `scripts/capture-store-screenshots.sh` |
| Privacy policy | **written** | `docs/privacy-policy.md` |
| Store listing + Data safety answers | **written** | `store/listing.md` |
| Backend deploy runbook | **written** | `docs/DEPLOY.md` |

## CI jobs

| Job | Trigger | Gate |
|---|---|---|
| `backend` | push/PR | vet, build, migrations up + down/up, `go test -race`, gofmt |
| `flutter` | push/PR | analyzer at fatal-infos, full suite, **coverage ≥ 91 %** |
| `web` | push/PR | release web build |
| `android` | tag/manual | signed per-ABI APKs + AAB, `apksigner verify`, artefacts |
| `design-guard` | push/PR | approved design HTML unchanged |
| `secrets` | push/PR | gitleaks clean |

The `android` job emits a `::notice::` and skips when signing secrets are absent,
so a fork or a fresh clone never fails the pipeline for missing credentials.

## Order of operations for go-live

1. `GH_TOKEN=… ./scripts/push-to-github.sh` — first push, tags included.
2. Add the four `NEXUS_ANDROID_*` secrets and the `NEXUS_API_URL` variable.
3. `git tag -a v1.5.0 -m "Nexus v1.5.0" && git push origin v1.5.0` — the pipeline
   builds the signed AAB and APKs.
4. Deploy the backend per `docs/DEPLOY.md`, run the smoke test.
5. Capture screenshots with `scripts/capture-store-screenshots.sh`.
6. Publish `docs/privacy-policy.md` (GitHub Pages serves it as
   `https://mawsimailbox-debug.github.io/social_nexus/privacy-policy`) and put
   that URL in Play Console.
7. Upload the AAB to internal testing → closed testing (12 testers, 14 days) →
   production 10 % → 100 %.

## Honest limits of this environment

- No Android SDK and no Xcode: no APK, AAB or IPA exists yet. The pipeline builds
  them on a runner, and the local commands are in `docs/BUILD_VERIFICATION.md`.
- No GitHub credentials: nothing was pushed from here, and no secret was written
  into the repository.
- No emulator or browser: the two Play screenshots cannot be produced here without
  fabricating them, which would be worse than leaving them to the device run.
