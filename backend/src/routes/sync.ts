import { Router } from "express";
import { rateLimit } from "express-rate-limit";
import { z } from "zod";
import { Prisma } from "@prisma/client";
import { requireAuth } from "../middleware/auth";
import { prisma } from "../services/prisma";
import type { AuthenticatedRequest } from "../types";

const router = Router();
const syncLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 300,
  keyGenerator: (req) => (req as AuthenticatedRequest).userId ?? "unauthenticated",
  standardHeaders: true,
  legacyHeaders: false,
});
router.use(requireAuth, syncLimiter);

const allowedKeys = ["favorites", "watch_history", "settings", "sync_meta", "profiles"] as const;
const valueSchema = z.union([z.record(z.unknown()), z.array(z.unknown())]);
const syncSchema = z.object({ value: valueSchema });
const batchItemSchema = z.object({
  value: valueSchema,
  expectedVersion: z.number().int().min(0),
  // The profile vault stays encrypted. This is non-sensitive quota metadata,
  // not a server-verified description of the encrypted contents.
  profileCount: z.number().int().min(0).max(100).optional(),
});
const batchSchema = z.object({ records: z.record(batchItemSchema) });

class SyncConflictError extends Error {}
class ProfileLimitError extends Error {}

router.get("/", async (req: AuthenticatedRequest, res, next) => {
  try {
    const records = await prisma.syncRecord.findMany({
      where: { userId: req.userId!, key: { in: [...allowedKeys] } },
      select: { key: true, value: true, version: true, profileCount: true, updatedAt: true }
    });
    res.json({ records });
  } catch (error) { next(error); }
});

// Atomic compare-and-swap batch: either all records are committed, or none are.
router.post("/batch", async (req: AuthenticatedRequest, res, next) => {
  try {
    const parsed = batchSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: "INVALID_INPUT" });
      return;
    }
    const entries = Object.entries(parsed.data.records);
    if (entries.length === 0 || entries.length > allowedKeys.length) {
      res.status(400).json({ error: "INVALID_INPUT" });
      return;
    }
    if (entries.some(([key, item]) =>
      !allowedKeys.includes(key as typeof allowedKeys[number]) ||
      (key !== "profiles" && item.profileCount !== undefined))) {
      res.status(400).json({ error: "SYNC_KEY_NOT_ALLOWED" });
      return;
    }

    try {
      const records = await prisma.$transaction(async (tx) => {
        const saved = [];
        for (const [key, item] of entries) {
          const userId = req.userId!;
          const value = item.value as Prisma.InputJsonValue;
          let profileCount: number | undefined;

          if (key === "profiles" && item.profileCount !== undefined) {
            profileCount = item.profileCount;
            const existing = await tx.syncRecord.findUnique({
              where: { userId_key: { userId, key } },
              select: { version: true, profileCount: true },
            });
            const previousCount = existing?.profileCount ?? null;
            const isExistingLegacyVault =
              existing !== null &&
              previousCount === null &&
              existing.version === item.expectedVersion &&
              item.expectedVersion > 0;
            const isGrandfatheredVault =
              previousCount !== null &&
              previousCount > 5 &&
              profileCount <= previousCount;

            // Existing encrypted vaults above the limit are grandfathered:
            // they may be edited or reduced, but cannot grow. New vaults cap at five.
            if (profileCount > 5 && !isExistingLegacyVault && !isGrandfatheredVault) {
              throw new ProfileLimitError();
            }
            if (previousCount !== null && previousCount > 5 && profileCount > previousCount) {
              throw new ProfileLimitError();
            }
          }

          if (item.expectedVersion === 0) {
            const record = await tx.syncRecord.create({
              data: { userId, key, value, ...(profileCount === undefined ? {} : { profileCount }) },
              select: { key: true, value: true, version: true, profileCount: true, updatedAt: true }
            });
            saved.push(record);
          } else {
            const changed = await tx.syncRecord.updateMany({
              where: { userId, key, version: item.expectedVersion },
              data: {
                value,
                version: { increment: 1 },
                ...(profileCount === undefined ? {} : { profileCount }),
              }
            });
            if (changed.count !== 1) throw new SyncConflictError();
            const record = await tx.syncRecord.findUniqueOrThrow({
              where: { userId_key: { userId, key } },
              select: { key: true, value: true, version: true, profileCount: true, updatedAt: true }
            });
            saved.push(record);
          }
        }
        return saved;
      });
      res.json({ records });
    } catch (error) {
      if (error instanceof ProfileLimitError) {
        res.status(409).json({ error: "PROFILE_LIMIT_REACHED", limit: 5 });
        return;
      }
      if (error instanceof SyncConflictError ||
          (typeof error === "object" && error !== null && "code" in error && error.code === "P2002")) {
        res.status(409).json({ error: "SYNC_VERSION_CONFLICT" });
        return;
      }
      throw error;
    }
  } catch (error) { next(error); }
});

// Backward-compatible endpoint for older installed app versions.
router.put("/:key", async (req: AuthenticatedRequest, res, next) => {
  try {
    if (!allowedKeys.includes(req.params.key as typeof allowedKeys[number])) {
      res.status(400).json({ error: "SYNC_KEY_NOT_ALLOWED" });
      return;
    }
    const parsed = syncSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: "INVALID_INPUT" });
      return;
    }
    const record = await prisma.syncRecord.upsert({
      where: { userId_key: { userId: req.userId!, key: req.params.key } },
      create: { userId: req.userId!, key: req.params.key, value: parsed.data.value as Prisma.InputJsonValue },
      update: { value: parsed.data.value as Prisma.InputJsonValue, version: { increment: 1 } },
      select: { key: true, value: true, version: true, updatedAt: true }
    });
    res.json({ record });
  } catch (error) { next(error); }
});

export default router;
