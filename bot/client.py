"""HTTP client for communicating with the Node.js backend."""
import logging
import requests
import config

log = logging.getLogger("client")

HEADERS = {"X-Bot-Key": config.BOT_API_KEY, "Content-Type": "application/json"}


def _get(path):
    try:
        r = requests.get(config.BACKEND_URL + path, headers=HEADERS, timeout=10)
        r.raise_for_status()
        return r.json()
    except Exception as e:
        log.error("GET %s failed: %s", path, e)
        return None


def _post(path, data):
    try:
        r = requests.post(config.BACKEND_URL + path, json=data, headers=HEADERS, timeout=10)
        r.raise_for_status()
        return r.json()
    except Exception as e:
        log.error("POST %s failed: %s", path, e)
        return None


def get_pending_deposits():
    """Returns list of deposit sessions with roblox_username."""
    data = _get("/api/bot/pending-deposits")
    return data.get("sessions", []) if data else []


def get_pending_withdrawals():
    """Returns list of withdrawal requests grouped by user."""
    data = _get("/api/bot/pending-withdrawals")
    return data.get("withdrawals", []) if data else []


def mark_in_trade(roblox_username: str):
    _post("/api/bot/session-in-trade", {"roblox_username": roblox_username})


def report_deposit(roblox_username: str, pets: list):
    """
    pets: list of dicts with keys pet_name, neon_status, age
    """
    result = _post("/api/bot/deposit-complete", {
        "roblox_username": roblox_username,
        "pets": pets,
    })
    if result and result.get("success"):
        log.info("Deposit recorded: %s (%d pets)", roblox_username, len(pets))
    else:
        log.error("Failed to record deposit for %s", roblox_username)


def report_withdrawal_complete(withdrawal_ids: list):
    result = _post("/api/bot/withdrawal-complete", {"withdrawal_ids": withdrawal_ids})
    if result and result.get("success"):
        log.info("Withdrawal complete: %s", withdrawal_ids)
    else:
        log.error("Failed to record withdrawal: %s", withdrawal_ids)
