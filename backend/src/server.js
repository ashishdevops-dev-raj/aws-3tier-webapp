require("dotenv").config();
const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const morgan = require("morgan");

const { testConnection, pool } = require("./config/db");
const userRoutes = require("./routes/userRoutes");
const { notFound, errorHandler } = require("./middleware/errorHandler");

const app = express();
const PORT = process.env.PORT || 5000;

app.use(helmet());
app.use(
  cors({
    origin: process.env.CORS_ORIGIN || "*",
    credentials: true,
  })
);
app.use(express.json());
app.use(morgan(process.env.NODE_ENV === "production" ? "combined" : "dev"));

app.get("/", (req, res) => {
  res.json({
    success: true,
    message: "AWS 3-Tier Backend API is running",
    version: "1.0.0",
  });
});

app.get("/api/health", async (req, res) => {
  try {
    await pool.query("SELECT 1");
    res.json({ success: true, status: "healthy", db: "connected" });
  } catch (err) {
    res.status(503).json({ success: false, status: "unhealthy", db: "disconnected" });
  }
});

app.use("/api/users", userRoutes);

app.use(notFound);
app.use(errorHandler);

async function start() {
  try {
    await testConnection();
    const server = app.listen(PORT, "0.0.0.0", () => {
      console.log(`[SERVER] Listening on port ${PORT} (${process.env.NODE_ENV || "development"})`);
    });

    const shutdown = async (signal) => {
      console.log(`[SERVER] ${signal} received, shutting down gracefully...`);
      server.close(async () => {
        await pool.end();
        console.log("[SERVER] Closed cleanly");
        process.exit(0);
      });
    };

    process.on("SIGTERM", () => shutdown("SIGTERM"));
    process.on("SIGINT", () => shutdown("SIGINT"));
  } catch (err) {
    console.error("[SERVER] Failed to start:", err.message);
    process.exit(1);
  }
}

start();
