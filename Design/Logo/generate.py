"""Generates the Loop mark: a speech bubble drawn as one loop of the N mark's tube, with the N's droplet as its full stop.

Every number comes from the N mark (nejack-site, src/scripts/glass/letter.ts):
  Tube radius        0.27   (stroke 0.54, three eighths of the letter's height)
  Centreline radius  0.72   (the N's half-height, so the ring stands exactly as tall as the N: 1.98)
  Baseline           0.99   (bottom edge of the stroke)
  Droplet            r 0.13, set 0.12 off the stroke, resting on the baseline

The tail runs straight down the ring's left side and lands on the baseline. The loop travels clockwise
from there and ends where it clears the tail by 0.12, the droplet's own gap, so every opening in the mark
has the same width.

Icon layers use the site's icon rule (tools/icons.mjs): the mark 0.6 of the tile tall, centred on its
bounding box, droplet included.

Run: python3 generate.py
"""
import math

TUBE = 0.27
R = 0.72
BASE = R + TUBE
DROP_R, GAP = 0.13, 0.12


def end_angle():
    """Angle (y down, clockwise from +x) where the loop stops, clearing the tail by GAP."""
    # The tail's centreline is the vertical line x = -R for y in [0, R]. The end cap centre sits on the ring
    # just past the bottom, so its clearance to the tail is R + R cos(theta) - 2 TUBE.
    return 2 * math.pi + math.acos((2 * TUBE + GAP) / R - 1)


def outline():
    """Filled outline of the round-capped stroke: tail, loop, and both caps."""
    theta = end_angle()
    ro, ri = R + TUBE, R - TUBE
    ox, oy = ro * math.cos(theta), ro * math.sin(theta)
    ix, iy = ri * math.cos(theta), ri * math.sin(theta)
    f = lambda v: f"{v:.4f}"
    return (f"M{f(-ro)} {f(R)}L{f(-ro)} 0"                       # tail, outer side, up to the ring
            f"A{f(ro)} {f(ro)} 0 1 1 {f(ox)} {f(oy)}"            # loop, outer edge
            f"A{TUBE} {TUBE} 0 0 1 {f(ix)} {f(iy)}"              # end cap
            f"A{f(ri)} {f(ri)} 0 1 0 {f(-ri)} 0"                 # loop, inner edge, back to the tail
            f"L{f(-ri)} {f(R)}"                                   # tail, inner side, down
            f"A{TUBE} {TUBE} 0 0 1 {f(-ro)} {f(R)}Z")            # tail cap on the baseline


def drop():
    cx, cy = R + TUBE + GAP + DROP_R, BASE - DROP_R
    return cx, cy, (f"M{cx - DROP_R:.4f} {cy:.4f}A{DROP_R} {DROP_R} 0 1 0 {cx + DROP_R:.4f} {cy:.4f}"
                    f"A{DROP_R} {DROP_R} 0 1 0 {cx - DROP_R:.4f} {cy:.4f}Z")


def bounds():
    cx, _, _ = drop()
    return -(R + TUBE), cx + DROP_R, -BASE, BASE  # left, right, top, bottom


def mark_svg(color="#111111"):
    l, r, t, b = bounds()
    pad = 0.06
    _, _, d = drop()
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{l - pad:.3f} {t - pad:.3f} {r - l + 2 * pad:.3f} {b - t + 2 * pad:.3f}">'
            f'<path d="{outline()}" fill="{color}"/><path d="{d}" fill="{color}"/></svg>\n')


def icon_layer(path_d, color="#FFFFFF", size=1024, mark_height=0.6):
    l, r, t, b = bounds()
    k = mark_height * size / (b - t)
    cx, cy = (l + r) / 2, (t + b) / 2
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {size} {size}" width="{size}" height="{size}">'
            f'<g transform="translate({size / 2} {size / 2}) scale({k:.4f}) translate({-cx:.4f} {-cy:.4f})">'
            f'<path d="{path_d}" fill="{color}"/></g></svg>\n')


if __name__ == "__main__":
    import os
    os.makedirs("icon", exist_ok=True)
    open("loop-mark.svg", "w").write(mark_svg())
    open("icon/loop-bubble.svg", "w").write(icon_layer(outline()))
    open("icon/loop-drop.svg", "w").write(icon_layer(drop()[2]))
    print(f"loop ends at {math.degrees(end_angle()) - 360:.2f} degrees; bounds {tuple(round(v, 3) for v in bounds())}")
