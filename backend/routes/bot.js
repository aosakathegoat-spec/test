/**
 * Endpoints exclusively for the Python in-game bot.
 * All requests must include X-Bot-Key matching BOT_API_KEY in .env.
 */
const express = require('express');
const db = require('../database');

const router = express.Router();

function requireBotKey(req, res, next) {
  if (req.headers['x-bot-key'] !== process.env.BOT_API_KEY) {
    return res.status(401).json({ error: 'Invalid bot key' });
  }
  next();
}

router.use(requireBotKey);

// Bot polls this to know whose trades to accept (active deposit sessions)
router.get('/pending-deposits', (req, res) => {
  const now = Math.floor(Date.now() / 1000);

  // Expire old sessions
  db.prepare("UPDATE deposit_sessions SET status = 'expired' WHERE status = 'waiting' AND expires_at < ?").run(now);

  const sessions = db.prepare(`
    SELECT ds.id AS session_id, ds.user_id, ds.expires_at,
           rl.roblox_username, rl.roblox_user_id
    FROM deposit_sessions ds
    JOIN roblox_links rl ON ds.user_id = rl.user_id AND rl.verified = 1
    WHERE ds.status = 'waiting'
  `).all();

  res.json({ sessions });
});

// Bot polls this to get withdrawal requests it needs to fulfill in-game
router.get('/pending-withdrawals', (req, res) => {
  const rows = db.prepare(`
    SELECT w.id AS withdrawal_id, w.user_id,
           dp.id AS pet_id, dp.pet_name, dp.neon_status, dp.age,
           rl.roblox_username, rl.roblox_user_id
    FROM withdrawals w
    JOIN deposited_pets dp ON w.pet_id = dp.id
    JOIN roblox_links rl ON w.user_id = rl.user_id AND rl.verified = 1
    WHERE w.status = 'pending'
    ORDER BY w.requested_at ASC
  `).all();

  // Group by user
  const byUser = {};
  for (const row of rows) {
    if (!byUser[row.roblox_username]) {
      byUser[row.roblox_username] = {
        roblox_username: row.roblox_username,
        roblox_user_id: row.roblox_user_id,
        user_id: row.user_id,
        pets: [],
      };
    }
    byUser[row.roblox_username].pets.push({
      withdrawal_id: row.withdrawal_id,
      pet_id: row.pet_id,
      pet_name: row.pet_name,
      neon_status: row.neon_status,
      age: row.age,
    });
  }

  res.json({ withdrawals: Object.values(byUser) });
});

// Bot calls this after a deposit trade completes
// Body: { roblox_username, pets: [{pet_name, neon_status, age}] }
router.post('/deposit-complete', (req, res) => {
  const { roblox_username, pets } = req.body;
  if (!roblox_username || !Array.isArray(pets)) {
    return res.status(400).json({ error: 'roblox_username and pets[] required' });
  }

  const link = db.prepare('SELECT * FROM roblox_links WHERE roblox_username = ? AND verified = 1').get(roblox_username);
  if (!link) return res.status(400).json({ error: 'Roblox account not linked' });

  // Mark the active deposit session as completed
  db.prepare(
    "UPDATE deposit_sessions SET status = 'completed' WHERE user_id = ? AND status IN ('waiting','in_trade')"
  ).run(link.user_id);

  const insertPet = db.prepare(
    "INSERT INTO deposited_pets (user_id, pet_name, neon_status, age) VALUES (?, ?, ?, ?)"
  );

  db.transaction(() => {
    for (const pet of pets) {
      insertPet.run(
        link.user_id,
        pet.pet_name || 'Unknown Pet',
        pet.neon_status || 'normal',
        pet.age || 'newborn'
      );
    }
  })();

  console.log(`[Bot] Deposit from ${roblox_username}: ${pets.length} pet(s)`);
  res.json({ success: true, recorded: pets.length });
});

// Bot calls this after a withdrawal trade completes
// Body: { withdrawal_ids: [1, 2, ...] }
router.post('/withdrawal-complete', (req, res) => {
  const { withdrawal_ids } = req.body;
  if (!Array.isArray(withdrawal_ids)) return res.status(400).json({ error: 'withdrawal_ids[] required' });

  db.transaction(() => {
    for (const wid of withdrawal_ids) {
      const w = db.prepare('SELECT * FROM withdrawals WHERE id = ?').get(wid);
      if (!w) continue;
      db.prepare("UPDATE withdrawals SET status = 'completed' WHERE id = ?").run(wid);
      db.prepare("UPDATE deposited_pets SET status = 'withdrawn' WHERE id = ?").run(w.pet_id);
    }
  })();

  console.log(`[Bot] Withdrawal complete: ${withdrawal_ids.length} item(s)`);
  res.json({ success: true });
});

// Bot marks deposit session as "in_trade" when it accepts the request
router.post('/session-in-trade', (req, res) => {
  const { roblox_username } = req.body;
  const link = db.prepare('SELECT * FROM roblox_links WHERE roblox_username = ? AND verified = 1').get(roblox_username);
  if (!link) return res.status(400).json({ error: 'Not found' });
  db.prepare("UPDATE deposit_sessions SET status = 'in_trade' WHERE user_id = ? AND status = 'waiting'").run(link.user_id);
  res.json({ success: true });
});

module.exports = router;
