require('dotenv').config();

const express = require('express');
const cors = require('cors');
const noblox = require('noblox.js');

const authRoutes = require('./routes/auth');
const verifyRoutes = require('./routes/verify');
const inventoryRoutes = require('./routes/inventory');
const withdrawRoutes = require('./routes/withdraw');
const { startMonitoring } = require('./services/tradeMonitor');

const app = express();
app.use(cors());
app.use(express.json());

app.use('/api/auth', authRoutes);
app.use('/api/verify', verifyRoutes);
app.use('/api/inventory', inventoryRoutes);
app.use('/api/withdraw', withdrawRoutes);

app.get('/api/health', (req, res) => res.json({ status: 'ok' }));

// Bot status endpoint
app.get('/api/bot/status', async (req, res) => {
  try {
    const info = await noblox.getPlayerInfo(parseInt(process.env.BOT_USER_ID));
    res.json({ online: true, username: info.username });
  } catch {
    res.json({ online: false });
  }
});

async function main() {
  if (!process.env.BOT_COOKIE) {
    console.warn('[WARN] BOT_COOKIE not set — trade monitoring disabled');
  } else {
    try {
      await noblox.setCookie(process.env.BOT_COOKIE);
      const currentUser = await noblox.getCurrentUser();
      console.log(`[Bot] Logged in as ${currentUser.UserName} (${currentUser.UserID})`);
      startMonitoring();
    } catch (err) {
      console.error('[Bot] Login failed:', err.message);
    }
  }

  const port = process.env.PORT || 3001;
  app.listen(port, () => console.log(`[Server] Running on http://localhost:${port}`));
}

main();
