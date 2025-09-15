CREATE TABLE IF NOT EXISTS users (
  id       VARCHAR(64) PRIMARY KEY,
  pw_hash  TEXT        NOT NULL
);
INSERT INTO users(id, pw_hash) VALUES ('demo', 'demo') ON CONFLICT DO NOTHING;
