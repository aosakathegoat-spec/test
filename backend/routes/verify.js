const express = require('express');
const crypto = require('crypto');
const noblox = require('noblox.js');
const db = require('../database');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

// Get current verification status and code
router.get('/status', requireAuth, (req, res) => {
  const link = db.prepare('SELECT * FROM roblox_links WHERE user_id = ?').get(req.user.id);
  if (!link) return res.json({ linked: false });
  res.json({
    linked: true,
    verified: link.verified === 1,
    robloxUsername: link.roblox_username,
    verificationCode: link.verified ? null : link.verification_code,
  });
});

// Start verification: register a Roblox username and get a code
router.post('/start', requireAuth, async (req, res) => {
  const { robloxUsername } = req.body;
  if (!robloxUsername) return res.status(400).json({ error: 'Roblox username required' });

  // Check another user isn't already verified with this account
  let robloxUserId;
  try {
    robloxUserId = await noblox.getIdFromUsername(robloxUsername);
  } catch {
    return res.status(400).json({ error: 'Roblox username not found' });
  }

  const alreadyVerified = db.prepare(
    'SELECT id FROM roblox_links WHERE roblox_user_id = ? AND verified = 1 AND user_id != ?'
  ).get(robloxUserId.toString(), req.user.id);
  if (alreadyVerified) return res.status(400).json({ error: 'This Roblox account is already linked to another user' });

  const code = 'ESCROW-' + crypto.randomBytes(4).toString('hex').toUpperCase();

  // Upsert link record
  db.prepare(`
    INSERT INTO roblox_links (user_id, roblox_user_id, roblox_username, verification_code, verified)
    VALUES (?, ?, ?, ?, 0)
    ON CONFLICT(user_id) DO UPDATE SET
      roblox_user_id = excluded.roblox_user_id,
      roblox_username = excluded.roblox_username,
      verification_code = excluded.verification_code,
      verified = 0,
      verified_at = NULL
  `).run(req.user.id, robloxUserId.toString(), robloxUsername, code);

  res.json({ code, robloxUsername });
});

// Confirm: check bio contains the code
router.post('/confirm', requireAuth, async (req, res) => {
  const link = db.prepare('SELECT * FROM roblox_links WHERE user_id = ? AND verified = 0').get(req.user.id);
  if (!link) return res.status(400).json({ error: 'No pending verification found' });

  let info;
  try {
    info = await noblox.getPlayerInfo(parseInt(link.roblox_user_id));
  } catch {
    return res.status(500).json({ error: 'Could not fetch Roblox profile' });
  }

  const bio = (info.blurb || '').toLowerCase();
  if (!bio.includes(link.verification_code.toLowerCase())) {
    return res.status(400).json({ error: 'Code not found in bio. Add it to your Roblox profile About section and try again.' });
  }

  db.prepare('UPDATE roblox_links SET verified = 1, verified_at = unixepoch() WHERE user_id = ?').run(req.user.id);
  res.json({ success: true, robloxUsername: link.roblox_username });
});

module.exports = router;
