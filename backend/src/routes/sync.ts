import { Router } from "express";
import { z } from "zod";
import { Prisma } from "@prisma/client";
import { requireAuth } from "../middleware/auth";
import { prisma } from "../services/prisma";
import type { AuthenticatedRequest } from "../types";

const router = Router();
router.use(requireAuth);

const allowedKeys = ["favorites", "watch_history", "settings", "sync_meta", "profiles"] as const;
const valueSchema = z.union([z.record(z.unknown()), z.array(z.unknown())]);
const syncSchema = z.object({ value: valueSchema });
const batchSchema = z.object({
  records: z.record(z.object({
    value: valueSchema,
    expectedVersion: z.number().int().min(0)
  }))
});

class SyncConflictError extends Error {}

router.get("/", async (req: AuthenticatedRequest, res, next) => {
  try {
    const records = await prisma.syncRecord.findMany({
      where: { userId: req.userId!, key: { in: [...allowedKeys] } },
      select: { key: true, value: true, version: true, updatedAt: true }
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
    if (entries.some(([key]) => !allowedKeys.includes(key as typeof allowedKeys[number]))) {
      res.status(400).json({ error: "SYNC_KEY_NOT_ALLOWED" });
      return;
    }

    try {
      const records = await prisma.$transaction(async (tx) => {
        const saved = [];
        for (const [key, item] of entries) {
          const userId = req.userId!;
          const value = item.value as Prisma.InputJsonValue;
          if (item.expectedVersion === 0) {
            const record = await tx.syncRecord.create({
              data: { userId, key, value },
              select: { key: true, value: true, version: true, updatedAt: true }
            });
            saved.push(record);
          } else {
            const changed = await tx.syncRecord.updateMany({
              where: { userId, key, version: item.expectedVersion },
              data: { value, version: { increment: 1 } }
            });
            if (changed.count !== 1) throw new SyncConflictError();
            const record = await tx.syncRecord.findUniqueOrThrow({
              where: { userId_key: { userId, key } },
              select: { key: true, value: true, version: true, updatedAt: true }
            });
            saved.push(record);
          }
        }
        return saved;
      });
      res.json({ records });
    } catch (error) {
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
