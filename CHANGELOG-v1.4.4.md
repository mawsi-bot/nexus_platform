# Nexus v1.4.4 — Profile and post-card interaction tests (no feature-code change)

Release date: 2026-11-14 · Flutter `1.4.2+5` unchanged · no `lib/` file modified

## Added (`test/profile_card_test.dart`)
### ProfileScreen
| Path | Assertion |
|---|---|
| Header | name, handle, bio and all three stats render; no badge on an unverified profile |
| Verified profile | `VerifiedBadge` tooltip present |
| Tab switch | Videos / Liked / Saved move `profileTab` and keep the grid intact |
| Settings overlay | routes to `settings` |
| Share overlay | platform share invoked through the mocked `share_plus` channel |
| My shop | routes to `business` |
| Edit profile → Cancel | dialog closes and **no** write reaches the API |
| Edit profile → Save | one PATCH, dialog closes, controller profile updated |
| Empty profile | falls back to "Your profile" and three zero stats |

### PostCard actions
| Path | Assertion |
|---|---|
| Long-press | reaction picker opens; choosing Hug sends `PUT /items/1/reaction` and the controller records `hug` as my reaction |
| Reaction summary | "See who reacted" opens the sheet, total 3, both authors listed |
| Share | the share sheet opens with the post's deep link |
| Hide | `PUT /items/1/hide`, card leaves the feed, confirmation toast shown |
| Save | `PUT /items/1/save` and `saved == true` on the post |

Two assertions target controller state rather than pixels, because these tests hand
`PostCard` a constant `Post`: the widget cannot repaint from provider state it does not
watch, so the stored result is the only truthful signal.

## Result
| Check | v1.4.3 | v1.4.4 |
|---|---|---|
| `flutter analyze --fatal-infos --fatal-warnings` | clean | **clean** |
| `flutter test` | 213 passed | **227 passed** |
| Hand-written Dart line coverage | 89.90 % | **91.58 %** (3055/3336) |
