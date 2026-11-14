# Nexus Privacy Policy

Last updated: 14 November 2026

Nexus ("we") operates the Nexus mobile application. This policy explains what we
collect, why, and what you can do about it. It describes the app as built in
v1.5.0; the source is public so this description can be checked against the code.

## What we collect

| Data | When | Why | Required |
|---|---|---|---|
| Phone number | At sign-up | Account identity and recovery | Yes |
| Device installation id | At first launch (random UUID) | Binds the session to this device; prevents account sharing | Yes |
| Recovery email | If you add one | Recovering the account on a new device | No |
| Name, handle, bio | If you fill them in | Shown on your profile | No |
| Posts, comments, reactions, messages | When you create them | The core product | No |
| Photos and videos | When you attach them | Displayed with your post or message | No |
| Approximate location | Only when you add a place to a post | Labels the post with coordinates you chose | No |
| Crash reports | On a crash, if telemetry is enabled in the build | Fixing defects | No |
| Server request logs (IP, request id, status) | Every request | Security, abuse prevention, debugging | Yes |

We do **not** collect contacts, calendars, SMS, precise background location,
advertising identifiers, or biometric data. We do **not** sell data and we run no
third-party advertising SDK.

## How it is stored

- Phone numbers and email addresses are stored **encrypted** at rest. Lookups use
  a keyed hash, so the database cannot be browsed by contact detail.
- Sessions use short-lived access tokens plus a rotating refresh token held in the
  platform keystore (iOS Keychain / Android EncryptedSharedPreferences).
- Media is stored under an unguessable identifier and served over HTTPS only.
- All traffic is HTTPS. The app refuses to start against a non-HTTPS API origin.

## Who can see it

- **Other users** see your profile fields, your posts, comments and reactions, and
  anything you send them directly. Private accounts are supported by the API; a
  private account's posts are not shown to non-followers.
- **Our operators** can see server logs and stored content when investigating
  abuse or a support request.
- **Processors** we rely on: a hosting provider for the API and database, an SMS
  provider for phone verification, and — only if enabled in the build — an error
  reporting provider that receives crash data without personal content.

We do not share data with anyone else unless legally compelled.

## Retention and deletion

- Posts, comments and messages stay until you delete them or ask us to.
- Signing out removes the session from the device.
- To delete your account and its content, email support@nexus.app from your
  recovery address or include your phone number. We delete within 30 days,
  except records we must keep for legal or fraud-prevention reasons.
- Crash reports are retained by the error provider for 30 days.

## Your choices

- Decline the location prompt and keep posting — the place label is optional.
- Decline the photo picker — text posts work without media.
- Turn off the theme preference at any time; it is stored locally.
- Clear local cache by signing out; queued offline posts are discarded with it.
- Ask us for a copy of your data at support@nexus.app.

## Children

Nexus is not directed to children under 13 (or the minimum age in your country).
We do not knowingly collect data from them. If you believe a child has created an
account, contact us and we will remove it.

## Changes

We will update this page and the "last updated" date when the policy changes
materially, and note the change in the app's release notes.

## Contact

support@nexus.app *(replace with the operating address before publishing)*
