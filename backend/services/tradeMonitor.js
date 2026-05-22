const noblox = require('noblox.js');
const db = require('../database');

const BOT_USER_ID = parseInt(process.env.BOT_USER_ID);
const POLL_INTERVAL_MS = 30_000;

// ── Deposit detection ────────────────────────────────────────────────────────

async function checkInboundTrades() {
  let trades;
  try {
    trades = await noblox.getTrades('Inbound');
  } catch (err) {
    console.error('[TradeMonitor] Failed to fetch inbound trades:', err.message);
    return;
  }

  for (const trade of trades.data) {
    // Skip already-processed trades
    if (db.prepare('SELECT 1 FROM processed_trades WHERE trade_id = ?').get(trade.id)) continue;

    let tradeInfo;
    try {
      tradeInfo = await noblox.getTradeInfo(trade.id);
    } catch (err) {
      console.error(`[TradeMonitor] Could not get info for trade ${trade.id}:`, err.message);
      continue;
    }

    const botOffer = tradeInfo.offers.find(o => o.user.id === BOT_USER_ID);
    const userOffer = tradeInfo.offers.find(o => o.user.id !== BOT_USER_ID);

    if (!botOffer || !userOffer) continue;

    // Only accept pure deposits (bot gives nothing)
    if (botOffer.userAssets.length > 0 || botOffer.robux > 0) {
      console.log(`[TradeMonitor] Skipping trade ${trade.id}: bot would give items`);
      continue;
    }

    // Only accept trades from verified users
    const robloxLink = db.prepare(
      'SELECT * FROM roblox_links WHERE roblox_user_id = ? AND verified = 1'
    ).get(userOffer.user.id.toString());

    if (!robloxLink) {
      console.log(`[TradeMonitor] Skipping trade ${trade.id}: sender not verified`);
      continue;
    }

    try {
      await noblox.acceptTrade(trade.id);
      console.log(`[TradeMonitor] Accepted deposit trade ${trade.id} from user ${userOffer.user.name}`);
    } catch (err) {
      console.error(`[TradeMonitor] Failed to accept trade ${trade.id}:`, err.message);
      continue;
    }

    // Record each deposited item
    const insertItem = db.prepare(`
      INSERT OR IGNORE INTO deposited_items (user_id, roblox_asset_id, asset_name, uaid, status)
      VALUES (?, ?, ?, ?, 'deposited')
    `);

    db.transaction(() => {
      for (const asset of userOffer.userAssets) {
        insertItem.run(robloxLink.user_id, asset.assetId, asset.name, asset.userAssetId);
      }
      db.prepare('INSERT INTO processed_trades (trade_id) VALUES (?)').run(trade.id);
    })();

    console.log(`[TradeMonitor] Recorded ${userOffer.userAssets.length} item(s) for user ${robloxLink.user_id}`);
  }
}

// ── Withdrawal processing ────────────────────────────────────────────────────

async function processWithdrawals() {
  // Group pending withdrawals by user
  const pending = db.prepare(`
    SELECT w.id AS withdrawal_id, w.user_id, w.item_id,
           di.uaid, di.asset_name,
           rl.roblox_user_id
    FROM withdrawals w
    JOIN deposited_items di ON w.item_id = di.id
    JOIN roblox_links rl ON w.user_id = rl.user_id AND rl.verified = 1
    WHERE w.status = 'pending'
  `).all();

  const byUser = {};
  for (const row of pending) {
    if (!byUser[row.user_id]) byUser[row.user_id] = [];
    byUser[row.user_id].push(row);
  }

  for (const [userId, items] of Object.entries(byUser)) {
    const targetRobloxId = parseInt(items[0].roblox_user_id);

    try {
      await noblox.makeOffer(
        [
          { userId: BOT_USER_ID, userAssets: items.map(i => i.uaid), robux: 0 },
          { userId: targetRobloxId, userAssets: [], robux: 0 },
        ],
        targetRobloxId
      );

      db.transaction(() => {
        for (const item of items) {
          db.prepare("UPDATE withdrawals SET status = 'trade_sent' WHERE id = ?").run(item.withdrawal_id);
          db.prepare("UPDATE deposited_items SET status = 'withdrawn' WHERE id = ?").run(item.item_id);
        }
      })();

      console.log(`[TradeMonitor] Sent withdrawal trade to Roblox user ${targetRobloxId} (${items.length} item(s))`);
    } catch (err) {
      console.error(`[TradeMonitor] Failed to send withdrawal trade to ${targetRobloxId}:`, err.message);
    }
  }
}

// ── Start ────────────────────────────────────────────────────────────────────

function startMonitoring() {
  console.log('[TradeMonitor] Starting — polling every', POLL_INTERVAL_MS / 1000, 'seconds');

  const tick = async () => {
    await checkInboundTrades();
    await processWithdrawals();
  };

  tick(); // immediate first run
  setInterval(tick, POLL_INTERVAL_MS);
}

module.exports = { startMonitoring };
