# MESUT IPTV cloud deployment

This guide deploys the Node.js API on Render and PostgreSQL on Neon. It does not upload IPTV provider credentials or stream URLs.

## 1. Create the Neon database

1. Open [Neon Console](https://console.neon.tech/) and create a project.
2. Choose a region close to the Render service region.
3. Open **Connect** and copy both PostgreSQL connection strings.
4. Keep the pooled connection (hostname contains `-pooler`) for `DATABASE_URL`.
5. Keep the direct connection (hostname does not contain `-pooler`) for `DIRECT_URL`.
6. Both URLs should include `sslmode=require`. Never commit either URL or paste it into a public issue.

Prisma uses the pooled URL for normal API traffic and the direct URL for schema migrations.

## 2. Deploy the API on Render

1. Sign in to [Render](https://dashboard.render.com/).
2. Choose **New + → Blueprint**.
3. Connect the GitHub repository `manou23/Dziptv`.
4. Select the branch containing this deployment PR after it is merged to `main`.
5. Render detects the root `render.yaml` and creates the web service.
6. In the service's **Environment** settings, set:
   - `DATABASE_URL`: Neon pooled connection string.
   - `DIRECT_URL`: Neon direct connection string.
7. Keep the generated `JWT_SECRET` private. Render generates it from the Blueprint.
8. Wait for deployment. The start command applies Prisma migrations before starting the API.

The initial Blueprint uses Render's free web-service plan for a low-cost smoke test. Free services may sleep when idle and are not the recommended choice for a production streaming companion service; upgrade the service plan when continuous availability is required.

## 3. Verify the API

Open:

```text
https://YOUR-RENDER-SERVICE.onrender.com/health
```

Expected response:

```json
{"status":"ok","service":"mesut-iptv-api"}
```

Do not consider deployment complete until this endpoint responds successfully and Render logs show the service started after migrations.

## 4. Build Flutter with the API URL

After Render provides the real HTTPS service URL, build the Android APK with:

```bash
flutter pub get
flutter build apk --release --dart-define=MESUT_API_BASE_URL=https://YOUR-RENDER-SERVICE.onrender.com
```

The app's **Settings → MESUT cloud account** screen then supports account registration, login, device registration, and manual cloud sync.

## Cloud data and privacy

The cloud sync payload includes favorites, watch-history metadata (title, item key, position and duration), and selected app settings. It deliberately excludes IPTV usernames/passwords, playback URLs, and artwork URLs. Cloud session tokens are stored in Android secure storage.

The first sync merges favorites and watch-history metadata. Settings use a last-change timestamp so a new device can inherit the existing account settings. Cloud sync is currently manual from the MESUT account screen.

## Account quotas and request limits

- Each MESUT account can link up to **5 devices**. Existing devices can continue to check in; a sixth new device is rejected until an older device is removed from the account portal or the app's device-management screen.
- Each account can add up to **5 IPTV profiles**. Existing encrypted vaults that already contain more than five profiles are grandfathered so users do not lose access to their data; they can edit or reduce that list, but cannot grow it further.
- The profile vault remains encrypted end-to-end. The server stores only a non-sensitive `profileCount` value beside the ciphertext; it cannot decrypt the vault to independently verify that count. The official app and website enforce the limit before adding a profile.
- Authenticated sync requests are limited to 300 per account per 15 minutes. Device reads are limited to 90 and device registration/removal to 30 per account per 15 minutes. These in-process limits suit the current single-instance deployment; use a shared rate-limit store before scaling to multiple API instances.

## Before production

Add email verification and password reset, refresh-token rotation/revocation, database backups and restore drills, monitoring/alerts, and automated integration tests. Review the Render and Neon plan limits and configure a paid always-on API instance before relying on it for production availability.
