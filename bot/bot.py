"""
Adopt Me escrow bot — main entry point.

Run this on the same PC as Roblox with Adopt Me open.
The bot:
  1. Polls the website backend for pending deposits / withdrawals
  2. Monitors the Roblox window for incoming trade requests
  3. Routes each trade to the correct handler (deposit or withdrawal)

Usage:
  python bot.py

Environment variables (or set them in a .env file):
  BACKEND_URL   — default http://localhost:3001
  BOT_API_KEY   — must match backend .env
"""
import os
import sys
import time
import logging

# Load .env if present
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

import config
import screen
import trade
import client

# ── Logging setup ─────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(name)s  %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("bot")

# ── Sanity checks ─────────────────────────────────────────────────────────────

def preflight():
    import pytesseract
    try:
        pytesseract.get_tesseract_version()
    except Exception:
        log.error("Tesseract OCR is not installed or not on PATH.")
        log.error("Download from https://github.com/UB-Mannheim/tesseract/wiki")
        sys.exit(1)

    if config.BOT_API_KEY in ("CHANGE_ME", ""):
        log.error("BOT_API_KEY is not set — update config.py or set the env var.")
        sys.exit(1)

    win = screen.get_roblox_window()
    if win is None:
        log.warning("Roblox window not found — screen capture will use full screen.")
    else:
        log.info("Roblox window found: %s", win.title)


# ── Main loop ─────────────────────────────────────────────────────────────────

def main():
    preflight()
    log.info("Bot started. Monitoring for trade requests every %.1fs…", config.POLL_INTERVAL)

    while True:
        try:
            tick()
        except KeyboardInterrupt:
            log.info("Stopped.")
            break
        except Exception as e:
            log.exception("Unexpected error in main loop: %s", e)
            time.sleep(5)

        time.sleep(config.POLL_INTERVAL)


def tick():
    # 1. Who is waiting to deposit?
    pending_deposits = client.get_pending_deposits()
    deposit_usernames = {s["roblox_username"].lower() for s in pending_deposits}

    # 2. Who needs items back?
    pending_withdrawals = client.get_pending_withdrawals()
    withdrawal_map = {w["roblox_username"].lower(): w for w in pending_withdrawals}

    # 3. Check screen for a trade request
    sender = trade.detect_trade_request()
    if sender is None:
        return  # nothing happening right now

    sender_lower = sender.lower()
    log.info("Trade request from: %s", sender)

    # 4. Route the trade
    if sender_lower in withdrawal_map:
        # User wants their pets back
        trade.handle_withdrawal(sender, withdrawal_map[sender_lower])

    elif sender_lower in deposit_usernames:
        # User wants to deposit pets
        trade.handle_deposit(sender)

    else:
        # Unknown / unverified user — decline
        log.info("Declining trade from unrecognised user: %s", sender)
        trade.click_decline_trade_request()


if __name__ == "__main__":
    main()
