const express = require('express');
const db = require('../database');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

// Request withdrawal of one or more items
router.post('/', requireAuth, (req, res) => {
  const { itemIds } = req.body;
  if (!Array.isArray(itemIds) || itemIds.length === 0) {
    return res.status(400).json({ error: 'itemIds array required' });
  }

  // Verify all items belong to this user and are available
  for (const id of itemIds) {
    const item = db.prepare(
      "SELECT id FROM deposited_items WHERE id = ? AND user_id = ? AND status = 'deposited'"
    ).get(id, req.user.id);
    if (!item) return res.status(400).json({ error: `Item ${id} not found or not available for withdrawal` });
  }

  // Create withdrawal records and mark items as withdrawing
  const insertWithdrawal = db.prepare('INSERT INTO withdrawals (user_id, item_id) VALUES (?, ?)');
  const markWithdrawing = db.prepare("UPDATE deposited_items SET status = 'withdrawing' WHERE id = ?");

  db.transaction(() => {
    for (const id of itemIds) {
      insertWithdrawal.run(req.user.id, id);
      markWithdrawing.run(id);
    }
  })();

  res.json({ success: true, message: 'Withdrawal requested. The bot will send you a trade offer shortly.' });
});

// Get withdrawal history
router.get('/history', requireAuth, (req, res) => {
  const history = db.prepare(`
    SELECT w.id, w.requested_at, w.status, di.asset_name, di.roblox_asset_id
    FROM withdrawals w
    JOIN deposited_items di ON w.item_id = di.id
    WHERE w.user_id = ?
    ORDER BY w.requested_at DESC
    LIMIT 50
  `).all(req.user.id);

  res.json({ history });
});

module.exports = router;
