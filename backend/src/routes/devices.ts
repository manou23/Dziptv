import { Router } from "express";
import { z } from "zod";
import { requireAuth } from "../middleware/auth";
import { prisma } from "../services/prisma";
import type { AuthenticatedRequest } from "../types";

const router = Router();
router.use(requireAuth);

const deviceSchema = z.object({
  deviceKey: z.string().trim().min(8).max(128),
  name: z.string().trim().min(1).max(80),
  platform: z.enum(["android", "android_tv", "ios", "web", "other"])
});

router.get("/", async (req: AuthenticatedRequest, res, next) => {
  try {
    const devices = await prisma.device.findMany({
      where: { userId: req.userId! },
      orderBy: { lastSeenAt: "desc" },
      select: { id: true, deviceKey: true, name: true, platform: true, lastSeenAt: true, createdAt: true }
    });
    res.json({ devices });
  } catch (error) { next(error); }
});

router.post("/register", async (req: AuthenticatedRequest, res, next) => {
  try {
    const parsed = deviceSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: "INVALID_INPUT", details: parsed.error.flatten() });
      return;
    }
    const device = await prisma.device.upsert({
      where: { userId_deviceKey: { userId: req.userId!, deviceKey: parsed.data.deviceKey } },
      create: { ...parsed.data, userId: req.userId! },
      update: { name: parsed.data.name, platform: parsed.data.platform, lastSeenAt: new Date() },
      select: { id: true, deviceKey: true, name: true, platform: true, lastSeenAt: true }
    });
    res.status(200).json({ device });
  } catch (error) { next(error); }
});

router.delete("/:id", async (req: AuthenticatedRequest, res, next) => {
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