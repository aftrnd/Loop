"""Generates Loop's identity from the N mark's geometry: the "loop." wordmark and the "o." app icon.

Every number comes from the N mark (nejack-site, src/scripts/glass/letter.ts):
  Tube radius 0.27 (stroke 0.54); ring centreline radius 0.72, so the "o" stands exactly as tall as the N (1.98);
  baseline 0.99; droplet r 0.13, set 0.12 off the stroke, resting on the baseline.

Wordmark: ascender and descender reach one stroke (0.54) past the x-height. Spacing is optical: a straight side
next to a round one gets 0.12 * sqrt(5) (about 0.27); two round sides get that divided by phi, because curves open
extra white space above and below their closest point. The full stop keeps the N's 0.12.

Icon: the wordmark's own "o" with its droplet. Layers sit on a 1024 canvas, mark 0.6 of the tile tall, centred on
its bounding box with the droplet included (the nejack.com icon rule, tools/icons.mjs).

Every shape is a filled outline (no strokes), so Icon Composer and any renderer draw it the same.

Run: python3 generate.py
"""
import math
import os

PHI = (1 + 5 ** 0.5) / 2
T = 0.27              # tube radius
S = 2 * T             # stroke
R = 0.72              # ring centreline radius
BASE = R + T          # baseline, 0.99
DROP_R, DROP_GAP = 0.13, 0.12
REACH = BASE + S      # ascender top and descender bottom, 1.53
GAP_STRAIGHT = DROP_GAP * math.sqrt(5)
GAP_ROUND = GAP_STRAIGHT / PHI


def f(v):
    return f"{v:.4f}"


def ring(cx, cy=0.0):
    ro, ri = R + T, R - T
    circle = lambda r: (f"M{f(cx - r)} {f(cy)}A{f(r)} {f(r)} 0 1 0 {f(cx + r)} {f(cy)}"
                        f"A{f(r)} {f(r)} 0 1 0 {f(cx - r)} {f(cy)}Z")
    return circle(ro) + circle(ri), "evenodd"


def stem(x, y0, y1):
    """Vertical round-capped stroke between centreline points (x, y0) and (x, y1), y0 above y1."""
    return (f"M{f(x - T)} {f(y0)}L{f(x - T)} {f(y1)}A{T} {T} 0 0 0 {f(x + T)} {f(y1)}"
            f"L{f(x + T)} {f(y0)}A{T} {T} 0 0 0 {f(x - T)} {f(y0)}Z"), "nonzero"


def drop(cx, cy=BASE - DROP_R):
    r = DROP_R
    return (f"M{f(cx - r)} {f(cy)}A{r} {r} 0 1 0 {f(cx + r)} {f(cy)}"
            f"A{r} {r} 0 1 0 {f(cx - r)} {f(cy)}Z"), "nonzero"


def wordmark():
    shapes = []
    x = T                                                  # "l"
    shapes.append(stem(x, -REACH + T, R))
    x += T + GAP_STRAIGHT + R + T                          # first "o"
    shapes.append(ring(x))
    x += (R + T) + GAP_ROUND + (R + T)                     # second "o"
    shapes.append(ring(x))
    x += (R + T) + GAP_STRAIGHT + (R + T)                  # "p": bowl plus stem down its left side
    shapes.append(ring(x))
    shapes.append(stem(x - R, 0.0, REACH - T))
    right = x + R + T
    shapes.append(drop(right + DROP_GAP + DROP_R))         # full stop
    return shapes, (0.0, right + DROP_GAP + 2 * DROP_R, -REACH, REACH)


def icon_mark():
    cx = R + T + DROP_GAP + DROP_R
    return [ring(0.0)], [drop(cx)], (-(R + T), cx + DROP_R, -BASE, BASE)


def paths(shapes, color):
    return "".join(f'<path d="{d}" fill="{color}" fill-rule="{rule}"/>' for d, rule in shapes)


def standalone(shapes, bounds, color="#111111", pad=0.06):
    l, r, t, b = bounds
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{l - pad:.3f} {t - pad:.3f} {r - l + 2 * pad:.3f} {b - t + 2 * pad:.3f}">'
            f'{paths(shapes, color)}</svg>\n')


def icon_layer(shapes, bounds, color="#FFFFFF", size=1024, mark_height=0.6):
    l, r, t, b = bounds
    k = mark_height * size / (b - t)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {size} {size}" width="{size}" height="{size}">'
            f'<g transform="translate({size / 2} {size / 2}) scale({k:.4f}) translate({-(l + r) / 2:.4f} {-(t + b) / 2:.4f})">'
            f'{paths(shapes, color)}</g></svg>\n')


if __name__ == "__main__":
    os.makedirs("icon", exist_ok=True)
    word, word_bounds = wordmark()
    o, d, mark_bounds = icon_mark()
    open("loop-wordmark.svg", "w").write(standalone(word, word_bounds))
    open("loop-mark.svg", "w").write(standalone(o + d, mark_bounds))
    open("icon/loop-o.svg", "w").write(icon_layer(o, mark_bounds))
    open("icon/loop-drop.svg", "w").write(icon_layer(d, mark_bounds))
    print(f"gaps: straight {GAP_STRAIGHT:.3f}, round {GAP_ROUND:.3f}; wordmark {word_bounds[1]:.3f} x {2 * REACH:.2f}")
