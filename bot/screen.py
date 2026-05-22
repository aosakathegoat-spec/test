"""
Window and screenshot utilities.
Works on Windows (pygetwindow) and falls back to full-screen capture on other OS.
"""
import time
import logging
from typing import Tuple, Optional

import numpy as np
from PIL import Image, ImageGrab

try:
    import pygetwindow as gw
    _HAS_PYGETWINDOW = True
except Exception:
    _HAS_PYGETWINDOW = False

import config

log = logging.getLogger("screen")


def get_roblox_window():
    """Return the Roblox window object, or None if not found."""
    if not _HAS_PYGETWINDOW:
        return None
    wins = gw.getWindowsWithTitle(config.ROBLOX_WINDOW_TITLE)
    return wins[0] if wins else None


def get_window_rect() -> Optional[Tuple[int, int, int, int]]:
    """Return (left, top, width, height) of the Roblox window."""
    win = get_roblox_window()
    if win is None:
        return None
    return (win.left, win.top, win.width, win.height)


def screenshot_region(region_fraction: Tuple[float, float, float, float]) -> Image.Image:
    """
    Capture a sub-region of the Roblox window.
    region_fraction: (left, top, width, height) as fractions 0..1 of the window.
    Falls back to full-screen if window position can't be determined.
    """
    rect = get_window_rect()
    if rect is None:
        # Fallback: grab full primary screen
        full = ImageGrab.grab()
        w, h = full.size
        rect = (0, 0, w, h)

    wx, wy, ww, wh = rect
    lf, tf, wrf, hrf = region_fraction

    left   = int(wx + lf * ww)
    top    = int(wy + tf * wh)
    right  = int(left + wrf * ww)
    bottom = int(top  + hrf * wh)

    return ImageGrab.grab(bbox=(left, top, right, bottom))


def screenshot_full_window() -> Image.Image:
    """Capture the full Roblox window."""
    rect = get_window_rect()
    if rect is None:
        return ImageGrab.grab()
    wx, wy, ww, wh = rect
    return ImageGrab.grab(bbox=(wx, wy, wx + ww, wy + wh))


def region_to_screen_coords(region_fraction: Tuple[float, float, float, float],
                             rel_x: float = 0.5, rel_y: float = 0.5) -> Tuple[int, int]:
    """
    Convert a fractional region to absolute screen coordinates.
    rel_x, rel_y are the relative position within the region (default = centre).
    """
    rect = get_window_rect()
    if rect is None:
        import pyautogui
        sw, sh = pyautogui.size()
        rect = (0, 0, sw, sh)

    wx, wy, ww, wh = rect
    lf, tf, wrf, hrf = region_fraction

    left = wx + lf * ww
    top  = wy + tf * wh
    x = int(left + rel_x * wrf * ww)
    y = int(top  + rel_y * hrf * wh)
    return x, y


def img_to_cv(img: Image.Image) -> np.ndarray:
    """Convert PIL Image to OpenCV BGR array."""
    import cv2
    return cv2.cvtColor(np.array(img), cv2.COLOR_RGB2BGR)


def focus_roblox():
    """Bring the Roblox window to the foreground."""
    win = get_roblox_window()
    if win:
        try:
            win.activate()
            time.sleep(0.3)
        except Exception as e:
            log.warning("Could not focus Roblox: %s", e)
