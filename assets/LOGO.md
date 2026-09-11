# The Gnomarchy mark

A grid of hard blocks with one cell replaced by a circle that is too big for it.

The grid is Omarchy: a terminal aesthetic of axis-aligned blocks, the same
language as its own blocky wordmark. The circle is GNOME: soft geometry in a
place the grid did not leave room for. Gnomarchy is the point where those two
meet, so the mark is a grid that something round has grown through.

The circle is 58% wider than the cell it occupies. That is the whole idea: a
circle neatly inscribed in its cell reads as an accident, while one that breaks
the grid's outline reads as a decision.

## Why not the old one

The previous mark was, in the words of its own source comment, a "Stylized
GNOME Footprint fused with Arch Chevron". Both halves belong to other projects:
the foot is a GNOME Foundation trademark, the chevron is Arch Linux's.
Recombining two marks you do not own is not an identity, and shipping it in a
distribution invites a problem nobody needs.

Rejected on the way here, for the record:

- **An arch with a keystone.** Meaningful — an arch needs its keystone the way
  this needs both halves — but it looked like a broken croquet hoop.
- **A pixel-grid letter G.** Correct instinct, wrong letter: a blue and purple
  blocky G is a pixelated Google logo and nothing else.
- **Tiling panes in a frame.** Legible, and exactly what the distribution does,
  but any tiling window manager could use it.

## Files

| File | Use |
| :-- | :-- |
| `assets/logo.svg` | the mark, on transparency |
| `assets/logo-mono.svg` | single colour via `currentColor`; print, stencils, terminals |
| `site/assets/gnomarchy-icon.svg` | app icon, inset on the rounded square GNOME expects |
| `site/favicon.svg` | the same, smaller radius |

Four shapes, no gradients, no filters. `logo.svg` is under 400 bytes and needs
no rasterising at any size.

## Construction

On a 128 unit canvas:

- cells 38 wide, gaps of 12, grid origin at 15
- blocks at (15,15), (65,15) and (15,65)
- circle centred at (88,88), radius 30 — the centre is nudged 4 units down and
  right of the vacant cell so the overhang is even on both exposed sides
- the icon inset scales the mark to 0.82 about the centre, which keeps the
  circle clear of the rounded corner

Every edge lands on a whole unit, so the mark stays crisp when snapped to a
pixel grid at icon sizes.

## Colour

Tokyo Night, the default theme:

- blocks `#7aa2f7`, with the top-right one a step darker at `#5a7fd4` so the
  grid has depth rather than reading as a flat launcher icon
- circle `#bb9af7`
- icon ground `#1a1b26`

`logo-mono.svg` inherits `currentColor`. The tonal step is lost there, but the
shape carries the mark on its own.

## Still to do

`assets/banner.png` predates this and still carries the old footprint mark. It
is the README header and the site's Open Graph image, so it wants regenerating.

`site/assets/gnomarchy-wordmark.svg` is a rect-traced bitmap rather than
outlined type. Not derivative of anything, so not urgent, but not good either.
