"""Generate the Open Graph / README banner from the real Gnomarchy mark.

The previous banner was an AI-rendered fantasy desk presented on the site as
"Gnomarchy GNOME 50 Desktop Interface". It was not a screenshot of anything,
so it has been replaced by a plain brand card that claims nothing.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

W, H = 1200, 630
SS = 3                      # supersample factor

GROUND = (26, 27, 38)
BLUE = (122, 162, 247)
DEEP = (90, 127, 212)
PURPLE = (187, 154, 247)
TEXT = (233, 236, 250)
MUTED = (154, 165, 200)

# A humanist sans for the name, a mono for the URL. The first readable
# candidate wins, so this runs on Linux and on Windows.
def pick_font(candidates):
    for path in candidates:
        if os.path.exists(path):
            return path
    sys.exit("No usable font found; tried: " + ", ".join(candidates))


FONT_BOLD = pick_font([
    "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "C:/Windows/Fonts/segoeuib.ttf",
])
FONT_REG = pick_font([
    "/usr/share/fonts/TTF/DejaVuSans.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "C:/Windows/Fonts/segoeui.ttf",
])
FONT_MONO = pick_font([
    "/usr/share/fonts/TTF/DejaVuSansMono.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
    "C:/Windows/Fonts/consola.ttf",
])

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                   "..", "site", "assets", "banner.png")

# Mark geometry on its own 128 unit field (see assets/LOGO.md).
CELL, GAP, OFF, CX, CY, R = 38, 12, 15, 88, 88, 30


def draw_mark(d, x, y, size):
    """Paint the mark with its top-left at (x, y), scaled to `size` units."""
    k = size / 128.0
    for bx, by, colour in ((OFF, OFF, BLUE),
                           (OFF + CELL + GAP, OFF, DEEP),
                           (OFF, OFF + CELL + GAP, BLUE)):
        d.rectangle([x + bx * k, y + by * k,
                     x + (bx + CELL) * k, y + (by + CELL) * k], fill=colour)
    d.ellipse([x + (CX - R) * k, y + (CY - R) * k,
               x + (CX + R) * k, y + (CY + R) * k], fill=PURPLE)


img = Image.new("RGB", (W * SS, H * SS), GROUND)
d = ImageDraw.Draw(img)

# A single accent hairline along the top, echoing the grid rather than a glow.
d.rectangle([0, 0, W * SS, 6 * SS], fill=BLUE)

name = ImageFont.truetype(FONT_BOLD, 108 * SS)
tag = ImageFont.truetype(FONT_REG, 33 * SS)
mono = ImageFont.truetype(FONT_MONO, 25 * SS)

MARK = 228
LEFT = 96
GUTTER = 64
text_x = (LEFT + MARK + GUTTER) * SS

# Lay the text block out first, then centre the mark against its true height.
name_top, tag_top, tag2_top = 0, 132, 186
block_h = tag2_top + 44
block_top = (H - block_h) / 2 - 14

d.text((text_x, (block_top + name_top) * SS), "Gnomarchy", font=name, fill=TEXT)
d.text((text_x + 6 * SS, (block_top + tag_top) * SS),
       "Arch Linux, rolling, with a tuned GNOME 50 desktop.", font=tag, fill=MUTED)
d.text((text_x + 6 * SS, (block_top + tag2_top) * SS),
       "Btrfs rollbacks  ·  22 themes  ·  one CLI", font=tag, fill=MUTED)

mark_y = block_top + (block_h - MARK) / 2
draw_mark(d, LEFT * SS, mark_y * SS, MARK * SS)

d.text((LEFT * SS, (H - 86) * SS), "gnomarchy.pages.dev", font=mono, fill=BLUE)

img.resize((W, H), Image.LANCZOS).save(os.path.normpath(OUT), optimize=True)
print("wrote", os.path.normpath(OUT))
