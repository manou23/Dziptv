import "dotenv/config";
import express from "express";
import cors from "cors";
import helmet from "helmet";
import rateLimit from "express-rate-limit";
import authRoutes from "./routes/auth";
import deviceRoutes from "./routes/devices";
import syncRoutes from "./routes/sync";
import { prisma } from "./services/prisma";

const app = express();
const port = Number(process.env.PORT || 3000);

if (!process.env.DATABASE_URL) throw new Error("DATABASE_URL is required");
if (!process.env.JWT_SECRET || process.env.JWT_SECRET.length < 32) {
  throw new Error("JWT_SECRET must contain at least 32 characters");
}

app.disable("x-powered-by");
app.use(helmet());
const allowedOrigins = new Set([
  "https://manou23.github.io",
  ...(process.env.CORS_ORIGIN?.split(",").map((value) => value.trim()).filter(Boolean) ?? [])
]);
app.use(cors({
  origin: (origin, callback) => {
    // Native app requests may not include Origin. Browser access is limited
    // to the configured origins and the official MESUT GitHub Pages site.
    if (!origin || allowedOrigins.has(origin)) {
      callback(null, true);
      return;
    }
    callback(new Error("CORS origin not allowed"));
  },
  methods: ["GET", "POST", "PUT", "DELETE"],
  allowedHeaders: ["Content-Type", "Authorization"]
}));
app.use(express.json({ limit: "256kb" }));

app.get("/health", (_req, res) => res.json({ status: "ok", service: "mesut-iptv-api", apiVersion: 2 }));
app.get("/health/ready", async (_req, res) => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    res.json({ status: "ready", service: "mesut-iptv-api", database: "connected", apiVersion: 2 });
  } catch {
    res.status(503).json({ status: "not_ready", service: "mesut-iptv-api", database: "unavailable" });
  }
});
app.use("/api/v1/auth", rateLimit({ windowMs: 15 * 60 * 1000, max: 20, standardHeaders: true, legacyHeaders: false }), authRoutes);
app.use("/api/v1/devices", deviceRoutes);
app.use("/api/v1/sync", syncRoutes);

app.use((_req, res) => res.status(404).json({ error: "NOT_FOUND" }));
app.use((error: unknown, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  // Do not expose internal errors, SQL details, tokens, or credentials to clients.
  console.error("Unhandled API error");
  res.status(500).json({ error: "INTERNAL_SERVER_ERROR" });
});

const server = app.listen(port, () => {
  console.log(`MESUT IPTV API listening on port ${port}`);
});

async function shutdown(): Promise<void> {
  server.close(async () => {
    await prisma.$disconnect();
    process.exit(0);
  });
}
process.on("SIGINT", () => void shutdown());
process.on("SIGTERM", () => void shutdown());