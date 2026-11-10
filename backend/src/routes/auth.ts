import { Router } from "express";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { z } from "zod";
import { prisma } from "../services/prisma";

const router = Router();
const credentialsSchema = z.object({
  email: z.string().trim().email().max(254).transform((v) => v.toLowerCase()),
  password: z.string().min(10).max(128).refine((value) => Buffer.byteLength(value, "utf8") <= 72, "Password must be at most 72 UTF-8 bytes")
});

function issueToken(userId: string): string {
  const secret = process.env.JWT_SECRET;
  if (!secret || secret.length < 32) throw new Error("JWT_SECRET must contain at least 32 characters");
  return jwt.sign({}, secret, {
    subject: userId,
    expiresIn: (process.env.JWT_EXPIRES_IN || "7d") as jwt.SignOptions["expiresIn"]
  });
}

router.post("/register", async (req, res, next) => {
  try {
    const parsed = credentialsSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: "INVALID_INPUT", details: parsed.error.flatten() });
      return;
    }
    const passwordHash = await bcrypt.hash(parsed.data.password, 12);
    const user = await prisma.user.create({
      data: { email: parsed.data.email, passwordHash },
      select: { id: true, email: true, createdAt: true }
    });
    res.status(201).json({ user, token: issueToken(user.id) });
  } catch (error) {
    if (typeof error === "object" && error !== null && "code" in error && error.code === "P2002") {
      res.status(409).json({ error: "EMAIL_ALREADY_REGISTERED" });
      return;
    }
    next(error);
  }
});

router.post("/login", async (req, res, next) => {
  try {
    const parsed = credentialsSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: "INVALID_INPUT", details: parsed.error.flatten() });
      return;
    }
    const user = await prisma.user.findUnique({ where: { email: parsed.data.email } });
    const valid = user ? await bcrypt.compare(parsed.data.password, user.passwordHash) : false;
    if (!user || !valid) {
      res.status(401).json({ error: "INVALID_CREDENTIALS" });
      return;
    }
    res.json({
      user: { id: user.id, email: user.email, createdAt: user.createdAt },
      token: issueToken(user.id)
    });
  } catch (error) {
    next(error);
  }
});

export default router;