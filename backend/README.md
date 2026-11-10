# MESUT IPTV Backend

Independent multi-tenant API service for MESUT IPTV. The Flutter app remains responsible for media playback and the user's IPTV provider connection.

## Stack

- Node.js 20+
- Express and TypeScript
- PostgreSQL with Prisma
- bcrypt password hashing and JWT authentication
- Helmet, CORS allow-list, request-size limits, and authentication rate limiting

## Local setup

1. Install Node.js 20+ and PostgreSQL.
2. Copy `.env.example` to `.env`.
3. Set `DATABASE_URL` and a random `JWT_SECRET` of at least 32 characters.
4. Install and generate the Prisma client:

   ```bash
   npm install
   npx prisma generate
   npx prisma migrate dev --name init
   npm run dev
   ```

The API listens on port 3000 by default. Health check: `GET /health`.

## API v1

| Method | Endpoint | Purpose |
| --- | --- | --- |
| POST | `/api/v1/auth/register` | Create a user account |
| POST | `/api/v1/auth/login` | Sign in and receive a JWT |
| GET | `/api/v1/devices` | List the signed-in user's devices |
| POST | `/api/v1/devices/register` | Register or refresh a device |
| DELETE | `/api/v1/devices/:id` | Remove one of the user's devices |
| GET | `/api/v1/sync` | Read the user's sync records |
| PUT | `/api/v1/sync/:key` | Write favorites, watch history, or settings |

Protected endpoints require `Authorization: Bearer <token>`.

Sync keys are allow-listed: `favorites`, `watch_history`, and `settings`. Every device and sync query is scoped to the authenticated user ID. IPTV provider credentials and stream URLs are deliberately not part of this API contract.

## Deployment notes

- Use a managed PostgreSQL database and TLS-enabled hosting.
- Configure secrets in the hosting provider; never commit `.env`.
- Set `CORS_ORIGIN` to the exact trusted app/web origins.
- Run `npm run build` and `npx prisma migrate deploy` during deployment.
- Configure backups, monitoring, and secret rotation before production launch.

This is the first backend foundation, not yet a production deployment. Email verification, password reset, refresh-token rotation, account/device limits, admin controls, and Flutter integration are subsequent milestones.
