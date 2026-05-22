import os

# ── Backend connection ────────────────────────────────────────────────────────
BACKEND_URL = os.environ.get("BACKEND_URL", "http://localhost:3001")
BOT_API_KEY  = os.environ.get("BOT_API_KEY", "CHANGE_ME")   # must match backend .env

# ── Roblox window title (exact match shown in taskbar) ───────────────────────
ROBLOX_WINDOW_TITLE = "Roblox"

# ── How often to take a screenshot and check for trade requests (seconds) ────
POLL_INTERVAL = 1.5

# ── Screen regions — all values are fractions of the Roblox window size ──────
# Tweak these once you've run capture_regions.py to see what they cover.
#
# Format: (left, top, width, height)  — all 0.0 to 1.0

# Where trade-request notifications pop up (bottom-centre of Adopt Me screen)
TRADE_NOTIF_REGION = (0.25, 0.82, 0.50, 0.12)

# The "Accept" button inside the trade-request notification
TRADE_ACCEPT_BTN_REGION = (0.35, 0.88, 0.15, 0.06)

# The "Decline" button
TRADE_DECLINE_BTN_REGION = (0.50, 0.88, 0.15, 0.06)

# Trade UI — sender's pet list (left side)
TRADE_SENDER_PETS_REGION = (0.04, 0.30, 0.43, 0.55)

# Trade UI — bot's side (right side) — where bot adds items for withdrawal
TRADE_BOT_PETS_REGION    = (0.53, 0.30, 0.43, 0.55)

# "Confirm / Accept Trade" green button after both sides are ready
TRADE_CONFIRM_BTN_REGION = (0.38, 0.88, 0.24, 0.07)

# Inventory search bar (for finding specific pets during withdrawal)
INVENTORY_SEARCH_REGION  = (0.54, 0.32, 0.20, 0.05)

# Trade result / "Trade Accepted!" overlay
TRADE_RESULT_REGION      = (0.20, 0.20, 0.60, 0.60)

# ── OCR confidence threshold (0–100) — raise if you get false positives ──────
OCR_CONFIDENCE = 55

# ── Seconds to wait after clicking before taking next screenshot ─────────────
CLICK_DELAY = 0.8

# ── Seconds to wait for the trade UI to fully open after clicking Accept ─────
TRADE_OPEN_DELAY = 2.0

# ── How long the bot waits for the other party to accept (withdrawal) ────────
WITHDRAWAL_ACCEPT_TIMEOUT = 120  # seconds
