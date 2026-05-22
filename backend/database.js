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

  -- Deposit sessions: user clicks "Deposit" on site, bot sees this and
  -- accepts the next trade request from that Roblox account
  CREATE TABLE IF NOT EXISTS deposit_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id),
    created_at INTEGER NOT NULL DEFAULT (unixepoch()),
    expires_at INTEGER NOT NULL,
    status TEXT NOT NULL DEFAULT 'waiting'
    -- waiting | in_trade | completed | expired | cancelled
  );

  -- Pets held in escrow by the bot
  CREATE TABLE IF NOT EXISTS deposited_pets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id),
    pet_name TEXT NOT NULL,
    neon_status TEXT NOT NULL DEFAULT 'normal',
    age TEXT NOT NULL DEFAULT 'newborn',
    deposited_at INTEGER NOT NULL DEFAULT (unixepoch()),
    status TEXT NOT NULL DEFAULT 'deposited'
    -- deposited | withdrawing | withdrawn
  );

  -- Withdrawal requests
  CREATE TABLE IF NOT EXISTS withdrawals (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id),
    pet_id INTEGER NOT NULL REFERENCES deposited_pets(id),
    requested_at INTEGER NOT NULL DEFAULT (unixepoch()),
    status TEXT NOT NULL DEFAULT 'pending'
    -- pending | trade_sent | completed
  );
`);

module.exports = db;
