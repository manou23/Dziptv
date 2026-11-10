import { Router } from "express";
import { z } from "zod";
import { Prisma } from "@prisma/client";
import { requireAuth } from "../middleware/auth";
import { prisma } from "../services/prisma";
import type { AuthenticatedRequest } from "../types";

const router = Router();
router.use(requireAuth);

const allowedKeys = ["favorites", "watch_history", "settings"] as const;
const syncSchema = z.object({
  value: z.union([z.record(z.unknown()), z.array(z.unknown())])
});

router.get("/", async (req: AuthenticatedRequest, res, next) => {
  try {
    const records = await prisma.syncRecord.findMany({
      where: { userId: req.userId!, key: { in: [...allowedKeys] } },
      select: { key: true, value: true, version: true, updatedAt: true }
    });
    res.json({ records });
  } catch (error) { next(error); }
});

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