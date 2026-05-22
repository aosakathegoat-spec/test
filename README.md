# Roblox Escrow Platform

A full-stack platform for Roblox item escrow — users deposit items via trade, items are tracked on the site, and they can withdraw them back at any time.

## How it works

1. User registers on the website
2. User links their Roblox account by pasting a generated code into their Roblox bio
3. User sends a trade to the bot account (user offers items, bot offers nothing)
4. Bot auto-accepts the trade — items appear in the user's dashboard
5. User clicks **Withdraw**, bot sends a trade offer back with the items

## Setup

### Prerequisites
- Node.js 18+
- A **dedicated bot Roblox account** (do not use your main account)

### 1. Backend

```bash
cd backend
npm install
cp .env.example .env
# Fill in .env (see table below)
npm run dev
```

**.env values:**

| Key | Description |
|-----|-------------|
| `BOT_COOKIE` | `.ROBLOSECURITY` cookie from your bot account's browser session |
| `BOT_USER_ID` | Numeric Roblox user ID of the bot account |
| `JWT_SECRET` | Long random string for signing tokens |
| `PORT` | Port to run the backend on (default `3001`) |

**Getting the `.ROBLOSECURITY` cookie:**
1. Log into roblox.com in a browser **as the bot account**
2. Open DevTools → Application → Cookies → `https://www.roblox.com`
3. Copy the value of `.ROBLOSECURITY`

### 2. Frontend

```bash
cd frontend
npm install
# Optional: create frontend/.env with VITE_BOT_USER_ID=<your-bot-id>
npm run dev
```

Frontend runs on `http://localhost:5173` and proxies `/api` to the backend.

## Project structure

```
backend/
  server.js            Express entry point + bot login
  database.js          SQLite schema + connection
  routes/
    auth.js            Register / login
    verify.js          Roblox bio verification
    inventory.js       Get deposited items
    withdraw.js        Request withdrawals
  services/
    tradeMonitor.js    Polls Roblox every 30s — accepts deposits, sends withdrawals
  middleware/
    auth.js            JWT middleware

frontend/
  src/
    pages/
      Login.jsx
      Register.jsx
      Verify.jsx        Bio-code verification flow
      Dashboard.jsx     Inventory + deposit/withdraw UI
    components/
      Navbar.jsx
      WithdrawModal.jsx
    api.js              Thin fetch wrapper
```

## Important notes

- The bot only accepts trades from **verified users**. If an unlinked account sends a trade, the bot ignores it.
- The bot only accepts pure deposit trades (it gives nothing). Trades where the bot would give items are skipped.
- Roblox's web trade API works for **catalog/limited items**. Adopt Me in-game pets/eggs use a separate in-game trade system that is NOT accessible via the web API — those trades must be done manually in-game.
