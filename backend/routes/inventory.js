const express = require('express');
const db = require('../database');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

// Get all deposited items for the logged-in user
router.get('/', requireAuth, (req, res) => {
  const items = db.prepare(`
    SELECT di.id, di.roblox_asset_id, di.asset_name, di.uaid, di.deposited_at, di.status
    FROM deposited_items di
    WHERE di.user_id = ? AND di.status IN ('deposited', 'withdrawing')
    ORDER BY di.deposited_at DESC
  `).all(req.user.id);

  res.json({ items });
});

module.exports = router;
