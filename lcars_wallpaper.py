#!/usr/bin/env python3
"""Compose a LCARS-framed wallpaper.

Canvas 3840x2400 (2x the 1920x1200 panel), black background, centre art
centred, LCARS border segments (Okuda-style elbows and bars) around the edge,
labels in Anton black-on-colour. The frame never changes: argv[2] picks the
centre art (the Voyager source by default), argv[1] the output file.
"""

import os
import sys
from PIL import Image, ImageDraw, ImageFont

W, H = 3840, 2400
BW = 124            # band width
R = 250             # elbow outer radius (~2 x band)
GAP = 26            # black gap between segments
HERE = os.path.dirname(os.path.abspath(__file__))
_bundled = os.path.join(HERE, "fonts", "Anton-Regular.ttf")
FONT_PATH = _bundled if os.path.exists(_bundled) \
    else os.path.expanduser("~/.local/share/fonts/Anton-Regular.ttf")
SHIP = os.path.join(HERE, "voyager-source.jpg")
OUT = sys.argv[1] if len(sys.argv) > 1 \
    else os.path.join(HERE, "wallpapers", "lcars-voyager.png")
SRC = sys.argv[2] if len(sys.argv) > 2 else SHIP

# LCARS colours
ORANGE = (255, 156, 0)
PEACH  = (255, 204, 102)
AMBER  = (255, 204, 153)
LAV    = (201, 153, 204)
BLUE   = (153, 153, 255)
STEEL  = (102, 129, 204)
PINK   = (255, 153, 153)
BLACK  = (0, 0, 0)

img = Image.new("RGB", (W, H), BLACK)

# ── centre art ───────────────────────────────────────────────────────────────
ship = Image.open(SRC).convert("RGB")
# Fit the centre box: the Voyager source fills the width exactly as before,
# while portraits and tall scene stills letterbox inside the box instead of
# overrunning the canvas.
box_w, box_h = 2850, 1900
scale = min(box_w / ship.width, box_h / ship.height)
ship = ship.resize((round(ship.width * scale), round(ship.height * scale)), Image.LANCZOS)

# feather the edges so any non-black pixels in the source vanish into the canvas
try:
    import numpy as np
    a = np.asarray(ship).astype(np.float32)
    h, w = a.shape[:2]
    fx = np.ones(w, np.float32)
    fy = np.ones(h, np.float32)
    # Wider than the ship needed: photo scenes have bright backgrounds, and
    # the long ramp carries them into the black canvas without a visible
    # rectangle edge.
    f = min(340, w // 5, h // 5)
    ramp = np.linspace(0, 1, f)
    fx[:f] = ramp
    fx[-f:] = ramp[::-1]
    fy[:f] = ramp
    fy[-f:] = ramp[::-1]
    mask = np.minimum.outer(fy, fx)
    a *= mask[..., None]
    ship = Image.fromarray(a.clip(0, 255).astype("uint8"))
except ImportError:
    pass

img.paste(ship, ((W - ship.width) // 2, (H - ship.height) // 2))

d = ImageDraw.Draw(img)
font_path = FONT_PATH


def elbow(corner, color):
    """Quarter-annulus corner band with the outer sweep rounded."""
    if corner == "tl":
        cx, cy, a1, a2 = R, R, 180, 270
    elif corner == "tr":
        cx, cy, a1, a2 = W - R, R, 270, 360
    elif corner == "bl":
        cx, cy, a1, a2 = R, H - R, 90, 180
    else:  # br
        cx, cy, a1, a2 = W - R, H - R, 0, 90
    d.pieslice([cx - R, cy - R, cx + R, cy + R], a1, a2, fill=color)
    d.pieslice([cx - (R - BW), cy - (R - BW), cx + (R - BW), cy + (R - BW)],
               a1, a2, fill=BLACK)


def bar(x0, y0, x1, y1, color, cap=None):
    """Axis-aligned band; cap in {'t','b','l','r'} rounds the free end."""
    d.rectangle([x0, y0, x1 - 1, y1 - 1], fill=color)
    if cap == "l":
        d.pieslice([x0, y0, x0 + BW, y1 - 1], 90, 270, fill=color)
    elif cap == "r":
        d.pieslice([x1 - BW, y0, x1 - 1, y1 - 1], 270, 90, fill=color)
    elif cap == "t":
        d.pieslice([x0, y0, x1 - 1, y0 + BW], 180, 360, fill=color)
    elif cap == "b":
        d.pieslice([x0, y1 - BW, x1 - 1, y1 - 1], 0, 180, fill=color)


def label_h(text, box, color, size=74, pad=30):
    """Horizontal label, drawn in black on the bar colour, centred in box."""
    font = ImageFont.truetype(font_path, size)
    x0, y0, x1, y1 = box
    bbox = d.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    tile = Image.new("RGB", (tw + 2, th + 2), color)
    ImageDraw.Draw(tile).text((-bbox[0] + 1, -bbox[1] + 1), text, font=font, fill=BLACK)
    tx = x0 + (x1 - x0 - tw) // 2
    ty = y0 + (y1 - y0 - th) // 2 - bbox[1]
    img.paste(tile, (tx, ty))


def label_v(text, box, color, size=74, ccw=True):
    """Vertical label; ccw reads bottom-to-top (left edge), else top-to-bottom."""
    font = ImageFont.truetype(font_path, size)
    x0, y0, x1, y1 = box
    bbox = d.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    tile = Image.new("RGB", (tw + 2, th + 2), color)
    ImageDraw.Draw(tile).text((-bbox[0] + 1, -bbox[1] + 1), text, font=font, fill=BLACK)
    tile = tile.rotate(90 if ccw else -90, expand=True)
    tx = x0 + (x1 - x0 - tile.width) // 2
    ty = y0 + (y1 - y0 - tile.height) // 2
    img.paste(tile, (tx, ty))


# ── segments ─────────────────────────────────────────────────────────────────
# v3 layout rule: the TOP and LEFT edges are the active console — the shell
# reserves them (62 px strips), so windows start outside them; the BOTTOM and
# RIGHT are decorative and windows cover them flush.
#
# left column: the top elbow is the corner arch (the shell draws the CPU/RAM
# gauge and the astrometrics target over it), then a plain orange tile — no
# label: the taskbar sits directly on it, bottom-anchored at y=700 and
# growing up to the arch — then STARFLEET COMMAND, vertical, where the
# terminal button sits.
elbow("tl", ORANGE)
bar(0, R, BW, 1400, ORANGE)

bar(0, 1426, BW, H - BW, PEACH)
label_v("STARFLEET COMMAND", (0, 1426, BW, H - BW), PEACH)

# bottom band: decorative, no elbows of its own any more — it fills the
# bottom-left corner the left column no longer owns. These labels are art.
bar(0, H - BW, 1120, H, BLUE)
label_h("USS VOYAGER", (0, H - BW, 1120, H), BLUE)

bar(1146, H - BW, 2060, H, STEEL)
label_h("DELTA QUADRANT", (1146, H - BW, 2060, H), STEEL)

bar(2086, H - BW, 2800, H, LAV)
label_h("NCC-74656", (2086, H - BW, 2800, H), LAV)

bar(2826, H - BW, W - R, H, PINK)
elbow("br", PINK)
label_h("READY ROOM", (2826, H - BW, W - R, H), PINK)

# right column — decorative: windows cover it (the meter lives in the
# corner arch now, not on LCARS 91).
bar(W - BW, 1400, W, H - R - GAP, BLUE)
label_v("INTREPID CLASS", (W - BW, 1400, W, H - R - GAP), BLUE, ccw=False)

bar(W - BW, 600, W, 1374, LAV, cap="t")
label_v("LCARS 91", (W - BW, 600, W, 1374), LAV, ccw=False)

# top band: owns the top-right elbow. The steel runs to x=600 (logical) and
# tucks under the island's left edge (the capsule starts near x=534 and
# covers the tail), so band and island read as one console strip. The middle
# and right are left black — the island floats there, black on black.
bar(R + GAP, 0, 1200, BW, STEEL)
label_h("CAPTAIN'S LOG", (R + GAP, 0, 1200, BW), STEEL)

elbow("tr", BLUE)

img.save(OUT, quality=92)
print("wrote", OUT, img.size)
