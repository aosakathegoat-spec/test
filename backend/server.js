require('dotenv').config();

const express = require('express');
const cors = require('cors');
const noblox = require('noblox.js');

const authRoutes = require('./routes/auth');
const verifyRoutes = require('./routes/verify');
const inventoryRoutes = require('./routes/inventory');
const withdrawRoutes = require('./routes/withdraw');
const depositRoutes = require('./routes/deposit');
const botRoutes = require('./routes/bot');

const app = express();
app.use(cors());
app.use(express.json());

app.use('/api/auth', authRoutes);
app.use('/api/verify', verifyRoutes);
app.use('/api/inventory', inventoryRoutes);
app.use('/api/withdraw', withdrawRoutes);
app.use('/api/deposit', depositRoutes);
app.use('/api/bot', botRoutes);    // Python bot uses this

app.get('/api/health', (req, res) => res.json({ status: 'ok' }));

async function main() {
  // noblox.js is only used for Roblox bio verification (no trading)
  if (process.env.BOT_COOKIE) {
    try {
      await noblox.setCookie(process.env.BOT_COOKIE);
      const u = await noblox.getCurrentUser();
      console.log(`[Roblox] Bio-verify account: ${u.UserName}`);
    } catch (err) {
      console.warn('[Roblox] Cookie login failed (bio verification may not work):', err.message);
    }
  } else {
    console.warn('[Warn] BOT_COOKIE not set — Roblox bio verification disabled');
  }

  const port = process.env.PORT || 3001;
  app.listen(port, () => console.log(`[Server] http://localhost:${port}`));
}

main();
