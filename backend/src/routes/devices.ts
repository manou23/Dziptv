import { Router } from "express";
import { rateLimit } from "express-rate-limit";
import { z } from "zod";
import { requireAuth } from "../middleware/auth";
import { prisma } from "../services/prisma";
import type { AuthenticatedRequest } from "../types";

const router = Router();
router.use(requireAuth);

const deviceReadLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 90,
  keyGenerator: (req) => (req as AuthenticatedRequest).userId ?? "unauthenticated",
  standardHeaders: true,
  legacyHeaders: false,
});
const deviceWriteLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 30,
  keyGenerator: (req) => (req as AuthenticatedRequest).userId ?? "unauthenticated",
  standardHeaders: true,
  legacyHeaders: false,
});

const MAX_LINKED_DEVICES = 5;
const deviceSchema = z.object({
  deviceKey: z.string().trim().min(8).max(128),
  name: z.string().trim().min(1).max(80),
  platform: z.enum(["android", "android_tv", "ios", "web", "other"])
});

class DeviceLimitError extends Error {}

router.get("/", deviceReadLimiter, async (req: AuthenticatedRequest, res, next) => {
  try {
    const devices = await prisma.device.findMany({
      where: { userId: req.userId! },
      orderBy: { lastSeenAt: "desc" },
      select: { id: true, deviceKey: true, name: true, platform: true, lastSeenAt: true, createdAt: true }
    });
    res.json({ devices, limit: MAX_LINKED_DEVICES });
  } catch (error) { next(error); }
});

router.post("/register", deviceWriteLimiter, async (req: AuthenticatedRequest, res, next) => {
  try {
    const parsed = deviceSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: "INVALID_INPUT", details: parsed.error.flatten() });
      return;
    }
    const userId = req.userId!;
    const device = await prisma.$transaction(async (tx) => {
      // Serialize registrations per account so simultaneous devices cannot
      // both pass the linked-device quota check.
      await tx.$queryRaw`SELECT 1 WHERE pg_advisory_xact_lock(hashtext(${userId})) IS NULL`;
      const existing = await tx.device.findUnique({
        where: { userId_deviceKey: { userId, deviceKey: parsed.data.deviceKey } }
      });
      if (existing) {
        return tx.device.update({
          where: { id: existing.id },
          data: { name: parsed.data.name, platform: parsed.data.platform, lastSeenAt: new Date() },
          select: { id: true, deviceKey: true, name: true, platform: true, lastSeenAt: true }
        });
      }
      const count = await tx.device.count({ where: { userId } });
      if (count >= MAX_LINKED_DEVICES) throw new DeviceLimitError();
      return tx.device.create({
        data: { ...parsed.data, userId },
        select: { id: true, deviceKey: true, name: true, platform: true, lastSeenAt: true }
      });
    });
    res.status(200).json({ device, limit: MAX_LINKED_DEVICES });
  } catch (error) {
    if (error instanceof DeviceLimitError) {
      res.status(409).json({ error: "DEVICE_LIMIT_REACHED", limit: MAX_LINKED_DEVICES });
      return;
    }
    next(error);
  }
});

router.delete("/:id", deviceWriteLimiter, async (req: AuthenticatedRequest, res, next) => {
  try {
    const result = await prisma.device.deleteMany({
      where: { id: req.params.id, userId: req.userId! }
    });
    if (result.count === 0) {
      res.status(404).json({ error: "DEVICE_NOT_FOUND" });
      return;
    }
    res.status(204).send();
  } catch (error) { next(error); }
});

export default router;
