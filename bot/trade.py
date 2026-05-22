"""
Detect and handle Adopt Me trade requests using screen capture + OCR.

Flow:
  deposit  — user sends trade to bot, bot accepts, user offers pets, bot records them
  withdrawal — bot sees user needs pets back, accepts their trade request, bot offers items
"""
import time
import re
import logging
from typing import Optional, List, Dict

import cv2
import numpy as np
import pytesseract
import pyautogui

import config
import screen
import client

log = logging.getLogger("trade")

# ── Helpers ───────────────────────────────────────────────────────────────────

def ocr(img, lang="eng", psm=6) -> str:
    """Run Tesseract OCR on a PIL image."""
    cfg = f"--oem 3 --psm {psm}"
    return pytesseract.image_to_string(img, lang=lang, config=cfg)


def click_region(region, rel_x=0.5, rel_y=0.5, delay=None):
    """Click the centre (or a relative point) of a fractional window region."""
    screen.focus_roblox()
    x, y = screen.region_to_screen_coords(region, rel_x, rel_y)
    pyautogui.click(x, y)
    time.sleep(delay or config.CLICK_DELAY)


def type_text(text: str):
    screen.focus_roblox()
    pyautogui.typewrite(text, interval=0.05)
    time.sleep(0.3)


# ── Trade-request detection ───────────────────────────────────────────────────

def detect_trade_request() -> Optional[str]:
    """
    Look at the trade-notification region.
    Returns the sender's Roblox username if a trade request is visible, else None.

    Adopt Me trade notifications say:  "<username> wants to trade with you!"
    We OCR the region and search for that pattern.
    """
    img = screen.screenshot_region(config.TRADE_NOTIF_REGION)
    text = ocr(img, psm=6)

    # Look for "wants to trade"
    match = re.search(r"([A-Za-z0-9_]+)\s+wants\s+to\s+trade", text, re.IGNORECASE)
    if match:
        username = match.group(1)
        log.info("Trade request detected from: %s", username)
        return username

    # Fallback: look for the word "Trade" in the region with high contrast
    lower = text.lower()
    if "trade" in lower and ("accept" in lower or "decline" in lower):
        # Pull out the first capitalised token as the username
        tokens = re.findall(r"[A-Z][A-Za-z0-9_]+", text)
        if tokens:
            log.info("Trade request (fallback) from: %s", tokens[0])
            return tokens[0]

    return None


# ── Pet reading ───────────────────────────────────────────────────────────────

_NEON_KEYWORDS = {"neon", "mega", "mega-neon", "mega neon"}
_AGE_KEYWORDS  = {"newborn", "junior", "pre-teen", "teen", "post-teen", "full grown"}


def parse_pet_name(raw: str) -> Dict:
    """
    Parse a raw OCR'd pet string like "Neon Dragon" or "Mega Unicorn (Full Grown)"
    into structured data.
    """
    raw = raw.strip()
    neon_status = "normal"
    age = "newborn"

    lower = raw.lower()
    if "mega" in lower:
        neon_status = "mega_neon"
    elif "neon" in lower:
        neon_status = "neon"

    for a in _AGE_KEYWORDS:
        if a in lower:
            age = a.replace("-", "_").replace(" ", "_")
            break

    # Strip neon/age qualifiers to get the base pet name
    name = re.sub(r"\b(mega[ -]neon|neon|mega)\b", "", raw, flags=re.IGNORECASE)
    for a in _AGE_KEYWORDS:
        name = re.sub(rf"\b{re.escape(a)}\b", "", name, flags=re.IGNORECASE)
    name = re.sub(r"[^A-Za-z0-9 ]", " ", name).strip()
    name = re.sub(r"\s+", " ", name)

    return {"pet_name": name, "neon_status": neon_status, "age": age}


def read_pets_from_region(region) -> List[Dict]:
    """
    OCR a trade-UI region and return a list of parsed pet dicts.
    Each line in the region is treated as a potential pet name.
    """
    img = screen.screenshot_region(region)
    text = ocr(img, psm=6)
    pets = []
    for line in text.splitlines():
        line = line.strip()
        if len(line) < 3:
            continue
        # Skip obvious non-pet lines
        if any(kw in line.lower() for kw in ("accept", "decline", "trade", "cancel", "your", "their")):
            continue
        pet = parse_pet_name(line)
        if pet["pet_name"]:
            pets.append(pet)
            log.debug("Parsed pet: %s", pet)
    return pets


# ── Trade actions ─────────────────────────────────────────────────────────────

def click_accept_trade_request():
    """Click the Accept button on the incoming trade-request notification."""
    click_region(config.TRADE_ACCEPT_BTN_REGION)
    log.info("Clicked Accept on trade request")
    time.sleep(config.TRADE_OPEN_DELAY)


def click_decline_trade_request():
    """Click the Decline button."""
    click_region(config.TRADE_DECLINE_BTN_REGION)
    log.info("Clicked Decline on trade request")
    time.sleep(config.CLICK_DELAY)


def click_confirm_trade():
    """Click the green Confirm/Accept button inside the trade UI."""
    click_region(config.TRADE_CONFIRM_BTN_REGION)
    log.info("Clicked Confirm Trade")


def search_inventory_for_pet(pet_name: str):
    """
    Type pet_name into Adopt Me's inventory search bar.
    The first result shown should be the pet we want.
    """
    click_region(config.INVENTORY_SEARCH_REGION)
    time.sleep(0.3)
    pyautogui.hotkey("ctrl", "a")  # clear existing text
    type_text(pet_name)
    time.sleep(0.8)


def add_pet_to_trade(pet: Dict) -> bool:
    """
    Search for a pet in the bot's inventory panel and double-click to add it.
    Returns True if we think it was added.
    """
    search_term = pet["pet_name"]
    if pet["neon_status"] == "neon":
        search_term = "Neon " + search_term
    elif pet["neon_status"] == "mega_neon":
        search_term = "Mega " + search_term

    log.info("Searching inventory for: %s", search_term)
    search_inventory_for_pet(search_term)

    # The first pet card visible in the bot inventory region — double-click it
    # (Adopt Me adds the pet to the trade on double-click)
    x, y = screen.region_to_screen_coords(config.TRADE_BOT_PETS_REGION, 0.12, 0.2)
    pyautogui.doubleClick(x, y)
    time.sleep(0.5)

    # Verify it appeared (re-OCR the bot side)
    pets_now = read_pets_from_region(config.TRADE_BOT_PETS_REGION)
    added = any(pet["pet_name"].lower() in p["pet_name"].lower() for p in pets_now)
    if added:
        log.info("Pet added to trade: %s", search_term)
    else:
        log.warning("Could not confirm pet was added: %s", search_term)
    return added


def wait_for_trade_result(timeout=30) -> bool:
    """Poll until 'Trade Accepted' or 'Trade' disappears from result region."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        img = screen.screenshot_region(config.TRADE_RESULT_REGION)
        text = ocr(img).lower()
        if "accepted" in text or "traded" in text:
            log.info("Trade completed successfully")
            return True
        if "failed" in text or "cancelled" in text or "declined" in text:
            log.warning("Trade failed/cancelled")
            return False
        time.sleep(1)
    log.warning("Timed out waiting for trade result")
    return False


# ── High-level handlers ───────────────────────────────────────────────────────

def handle_deposit(sender_username: str):
    """
    A verified user wants to deposit pets.
    Accept their trade, wait for them to add pets and confirm, then read what was given.
    """
    log.info("Handling deposit from %s", sender_username)
    client.mark_in_trade(sender_username)

    click_accept_trade_request()

    # Wait for the user to add their pets and both sides to confirm
    # We just watch the trade-result region for "Trade Accepted"
    # (the user and bot both need to click Accept in the trade UI —
    #  the bot clicks Confirm after a short grace period)
    log.info("Waiting for user to add pets and both sides to confirm…")
    time.sleep(5)  # give user time to add pets

    click_confirm_trade()

    success = wait_for_trade_result(timeout=config.WITHDRAWAL_ACCEPT_TIMEOUT)
    if not success:
        log.warning("Deposit trade did not complete for %s", sender_username)
        return

    # OCR the result screen to see what was given
    time.sleep(1)
    pets = read_pets_from_region(config.TRADE_RESULT_REGION)
    if not pets:
        log.warning("No pets parsed from result screen — recording 'Unknown Pet'")
        pets = [{"pet_name": "Unknown Pet", "neon_status": "normal", "age": "newborn"}]

    client.report_deposit(sender_username, pets)


def handle_withdrawal(sender_username: str, withdrawal_data: Dict):
    """
    User sent a trade to request their pets back.
    Bot adds their pets on its side, then both confirm.
    """
    log.info("Handling withdrawal for %s (%d pets)", sender_username, len(withdrawal_data["pets"]))
    click_accept_trade_request()

    # Add each requested pet to the bot's side of the trade
    for pet in withdrawal_data["pets"]:
        add_pet_to_trade(pet)
        time.sleep(0.5)

    time.sleep(1)
    click_confirm_trade()

    success = wait_for_trade_result(timeout=config.WITHDRAWAL_ACCEPT_TIMEOUT)
    if success:
        wids = [p["withdrawal_id"] for p in withdrawal_data["pets"]]
        client.report_withdrawal_complete(wids)
    else:
        log.warning("Withdrawal trade did not complete for %s", sender_username)
