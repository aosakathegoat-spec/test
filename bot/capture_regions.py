"""
Helper script — run this BEFORE the main bot to visually verify your region config.

It takes a screenshot of the Roblox window and draws coloured rectangles for
each configured region so you can check they cover the right areas.

Usage:
  1. Open Roblox and go into Adopt Me
  2. Run:  python capture_regions.py
  3. Open the saved  regions_preview.png  and check the boxes
  4. Adjust config.py regions if needed, then re-run until they look right
"""
import sys
from PIL import Image, ImageDraw

import screen
import config

REGIONS = {
    "TRADE_NOTIF (green)":        (config.TRADE_NOTIF_REGION,       (0,   200,   0, 120)),
    "TRADE_ACCEPT (blue)":        (config.TRADE_ACCEPT_BTN_REGION,  (0,   100, 255, 120)),
    "TRADE_DECLINE (red)":        (config.TRADE_DECLINE_BTN_REGION, (255,  50,  50, 120)),
    "SENDER_PETS (yellow)":       (config.TRADE_SENDER_PETS_REGION, (255, 220,   0, 120)),
    "BOT_PETS (cyan)":            (config.TRADE_BOT_PETS_REGION,    (0,   220, 220, 120)),
    "TRADE_CONFIRM (lime)":       (config.TRADE_CONFIRM_BTN_REGION, (100, 255, 100, 120)),
    "INVENTORY_SEARCH (magenta)": (config.INVENTORY_SEARCH_REGION,  (220,   0, 220, 120)),
    "TRADE_RESULT (orange)":      (config.TRADE_RESULT_REGION,      (255, 150,   0, 120)),
}

def main():
    full = screen.screenshot_full_window()
    overlay = Image.new("RGBA", full.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    rect = screen.get_window_rect()
    if rect is None:
        w, h = full.size
        wx, wy = 0, 0
    else:
        wx, wy, ww, wh = rect
        w, h = ww, wh

    for label, (region, colour) in REGIONS.items():
        lf, tf, wrf, hrf = region
        left   = int(lf  * w)
        top    = int(tf  * h)
        right  = int((lf + wrf) * w)
        bottom = int((tf + hrf) * h)
        draw.rectangle([left, top, right, bottom], fill=colour, outline=colour[:3])
        draw.text((left + 4, top + 4), label, fill=(255, 255, 255, 255))
        print(f"  {label}: ({left},{top}) → ({right},{bottom})")

    result = Image.alpha_composite(full.convert("RGBA"), overlay)
    out = "regions_preview.png"
    result.save(out)
    print(f"\nSaved to {out} — open it to check region placement.")


if __name__ == "__main__":
    main()
