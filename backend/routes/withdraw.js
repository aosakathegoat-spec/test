const express = require('express');
const db = require('../database');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

// Request withdrawal of selected pets
router.post('/', requireAuth, (req, res) => {
  const { petIds } = req.body;
  if (!Array.isArray(petIds) || petIds.length === 0) {
    return res.status(400).json({ error: 'petIds array required' });
  }

  for (const id of petIds) {
    const pet = db.prepare(
      "SELECT id FROM deposited_pets WHERE id = ? AND user_id = ? AND status = 'deposited'"
    ).get(id, req.user.id);
    if (!pet) return res.status(400).json({ error: `Pet ${id} not found or not available` });
  }

  const insertWithdrawal = db.prepare('INSERT INTO withdrawals (user_id, pet_id) VALUES (?, ?)');
  const markPet = db.prepare("UPDATE deposited_pets SET status = 'withdrawing' WHERE id = ?");

  db.transaction(() => {
    for (const id of petIds) {
      insertWithdrawal.run(req.user.id, id);
      markPet.run(id);
    }
  })();

  res.json({ success: true, message: 'Withdrawal requested. Join the bot\'s Adopt Me server and the bot will trade you your pets back.' });
});

// Withdrawal history
router.get('/history', requireAuth, (req, res) => {
  const history = db.prepare(`
    SELECT w.id, w.requested_at, w.status, dp.pet_name, dp.neon_status, dp.age
    FROM withdrawals w
    JOIN deposited_pets dp ON w.pet_id = dp.id
    WHERE w.user_id = ?
    ORDER BY w.requested_at DESC
    LIMIT 50
  `).all(req.user.id);

  res.json({ history });
});

module.exports = router;
