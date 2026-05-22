const express = require('express');
const db = require('../database');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

const SESSION_TTL_SECONDS = 10 * 60; // 10-minute window

// Start a deposit session — tells the bot to accept the next trade from this user
router.post('/start', requireAuth, (req, res) => {
  const link = db.prepare('SELECT * FROM roblox_links WHERE user_id = ? AND verified = 1').get(req.user.id);
  if (!link) return res.status(400).json({ error: 'You must verify your Roblox account first' });

  // Cancel any existing waiting session
  db.prepare("UPDATE deposit_sessions SET status = 'cancelled' WHERE user_id = ? AND status = 'waiting'").run(req.user.id);

  const expiresAt = Math.floor(Date.now() / 1000) + SESSION_TTL_SECONDS;
  const result = db.prepare(
    "INSERT INTO deposit_sessions (user_id, expires_at, status) VALUES (?, ?, 'waiting')"
  ).run(req.user.id, expiresAt);

  res.json({ sessionId: result.lastInsertRowid, expiresAt, robloxUsername: link.roblox_username });
});

// Cancel the current waiting deposit session
router.post('/cancel', requireAuth, (req, res) => {
  db.prepare("UPDATE deposit_sessions SET status = 'cancelled' WHERE user_id = ? AND status = 'waiting'").run(req.user.id);
  res.json({ success: true });
});

// Get current deposit session status
router.get('/status', requireAuth, (req, res) => {
  const session = db.prepare(
    "SELECT * FROM deposit_sessions WHERE user_id = ? AND status IN ('waiting','in_trade') ORDER BY id DESC LIMIT 1"
  ).get(req.user.id);
  res.json({ session: session || null });
});

module.exports = router;
