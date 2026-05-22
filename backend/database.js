const Database = require('better-sqlite3');
const path = require('path');

const db = new Database(path.join(__dirname, 'escrow.db'));

db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    created_at INTEGER NOT NULL DEFAULT (unixepoch())
  );

  CREATE TABLE IF NOT EXISTS roblox_links (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id),
    roblox_user_id TEXT UNIQUE NOT NULL,
    roblox_username TEXT NOT NULL,
    verification_code TEXT NOT NULL,
    verified INTEGER NOT NULL DEFAULT 0,
    verified_at INTEGER,
    UNIQUE(user_id)
  );

  CREATE TABLE IF NOT EXISTS deposited_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id),
    roblox_asset_id INTEGER NOT NULL,
    asset_name TEXT NOT NULL,
    uaid INTEGER NOT NULL UNIQUE,
    deposited_at INTEGER NOT NULL DEFAULT (unixepoch()),
    status TEXT NOT NULL DEFAULT 'deposited'
  );

  CREATE TABLE IF NOT EXISTS withdrawals (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id),
    item_id INTEGER NOT NULL REFERENCES deposited_items(id),
    requested_at INTEGER NOT NULL DEFAULT (unixepoch()),
    status TEXT NOT NULL DEFAULT 'pending'
  );

  CREATE TABLE IF NOT EXISTS processed_trades (
    trade_id INTEGER PRIMARY KEY,
    processed_at INTEGER NOT NULL DEFAULT (unixepoch())
  );
`);

module.exports = db;
