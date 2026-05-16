-- =====================================================================
-- AWS 3-Tier Application — Database Schema
-- Run this against:
--   • Local docker-compose MySQL (auto-loaded via /docker-entrypoint-initdb.d)
--   • AWS RDS MySQL after creation:
--       mysql -h <RDS_ENDPOINT> -u admin -p < database/schema.sql
-- =====================================================================

CREATE DATABASE IF NOT EXISTS appdb
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE appdb;

CREATE TABLE IF NOT EXISTS users (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(100) NOT NULL,
  email       VARCHAR(150) NOT NULL UNIQUE,
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_email (email),
  INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Seed sample data
INSERT IGNORE INTO users (name, email) VALUES
  ('Alice Johnson', 'alice@example.com'),
  ('Bob Smith',     'bob@example.com'),
  ('Charlie Davis', 'charlie@example.com');
