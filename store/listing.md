# Play Store listing — Nexus

## Short description (80 characters max)
```
Your neighbourhood feed, groups, shops and chat — all in one place.
```
(60 characters)

## Full description (4000 characters max)
```
Nexus is a calm social app for your city: a feed that shows what is actually
happening nearby, the groups you belong to, the small businesses you buy from,
and one-to-one chat — without the noise.

WHAT YOU CAN DO
• Feed — a photo, video, feeling or place, posted in two taps. Filter to your
  neighbourhood when you want local, or switch to For You for everything.
• Reactions, not just likes — long-press any post for ❤️ Love, 🤗 Hug or 💪
  Strong, and see exactly who reacted.
• Comments that stay in place — reply inside the post, mention people with @,
  and never lose your place in a thread.
• Groups — join local communities, follow their updates, meet the people behind
  them.
• Shops — browse nearby businesses, see their products, save the ones you like.
• Chat — text, photos and stickers in a thread that stays in sync.
• Your space — profile grid, saved posts, light and dark themes.

BUILT TO WORK OFFLINE
Nexus keeps the last feed you read on your device and queues what you post while
you are out of coverage, sending it the moment you reconnect. An honest banner
tells you what is pending instead of failing silently.

PRIVACY BY DESIGN
• Sign in with your phone number — your device is the primary credential, so
  there is no password to steal.
• Your recovery email is optional and only used when you move to a new device.
• Contact details are stored encrypted; the server keeps a hashed lookup value
  rather than a searchable copy.
• Location is used only when you choose to add a place to a post, and you can
  decline it and keep posting.
• We do not sell data and we do not run third-party ad tracking.

WHAT WE ASK FOR
• Photos and videos you choose to attach
• Approximate location, only while composing a place post
• Basic crash reports, so a broken screen gets fixed

Nexus is for people who want to know their neighbourhood, not to perform for it.
```
(~1850 characters)

## Category and contact
| Field | Value |
|---|---|
| App name | Nexus |
| Category | Social |
| Tags | Social, Community, Local |
| Contact email | support@nexus.app *(replace with your real support address)* |
| Website | https://nexus.app *(replace)* |
| Privacy policy | https://nexus.app/privacy *(or the GitHub Pages URL below)* |

## Graphics checklist
| Asset | Requirement | File |
|---|---|---|
| App icon | 512×512, 32-bit PNG, no transparency | `store/icon-512.png` (generated) |
| Feature graphic | 1024×500 PNG, no device frames | `store/feature-graphic-1024x500.png` (generated) |
| Phone screenshots | 2–8 images, 16:9 or 9:16, 320–3840 px | `store/screenshots/*.png` — capture on a device with `scripts/capture-store-screenshots.sh` |
| Adaptive icon | 108 dp foreground + background | already in `app-flutter/android/app/src/main/res/mipmap-anydpi-v26/` |

## Data safety form (answer exactly as below)
| Question | Answer |
|---|---|
| Does your app collect or share user data? | **Yes — collected, not shared** |
| Is data encrypted in transit? | **Yes** (HTTPS only; the client refuses any non-HTTPS origin) |
| Can users request data deletion? | **Yes** — sign out removes the device session; account deletion via support@nexus.app |
| Personal info → Phone number | Collected · Account management · Optional? No |
| Personal info → Email address | Collected · Account management · Optional? Yes |
| Personal info → Name, bio | Collected · App functionality · Optional? Yes |
| Location → Approximate location | Collected · App functionality · Optional? Yes |
| Photos and videos | Collected · App functionality · Optional? Yes |
| Messages → In-app messages | Collected · App functionality · Optional? Yes |
| App activity → Other user-generated content | Collected · App functionality · Optional? Yes |
| Device or other IDs | Collected · Account management, Fraud prevention · Optional? No |
| Crash logs / diagnostics | Collected · App functionality · Optional? Yes |
| Data sold to third parties | **No** |
| Data used for advertising | **No** |

## Content rating questionnaire (IARC)
- Violence, sexuality, language, controlled substances: **none**
- User-generated content and user interaction: **yes** → the app provides
  reporting, hiding and blocking-adjacent controls; moderation contact published
- Shares location: **yes, user-initiated only**
- Digital purchases: **no**

## Release track plan
1. **Internal testing** — 1 tester, verify sign-in, feed, composer upload, chat.
2. **Closed testing** — 12+ testers, 14 days (required for new personal accounts).
3. **Production** — staged rollout 10% → 50% → 100%.
