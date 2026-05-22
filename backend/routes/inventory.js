const express = require('express');
const db = require('../database');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

router.get('/', requireAuth, (req, res) => {
  const pets = db.prepare(`
    SELECT id, pet_name, neon_status, age, deposited_at, status
    FROM deposited_pets
    WHERE user_id = ? AND status IN ('deposited', 'withdrawing')
    ORDER BY deposited_at DESC
  `).all(req.user.id);

  res.json({ pets });
});

module.exports = router;
