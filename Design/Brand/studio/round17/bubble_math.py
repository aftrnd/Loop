"""Said and echoed: a speech bubble built only from tangent circles in simple ratios, on Apple's icon grid.

u = 32 (a quarter of the 128 grid cell). Bubble radius R = 7u. Said at (14u, 14u), echo one grid cell down-right at (18u, 18u).
Tail: tip circle r_t = R * kt at the corner of the bubble's bounding square; outer edge an arc of radius R * ko internally
tangent to the bubble and the tip; inner edge an arc of radius R * ki externally tangent to both."""
from tails3 import arc_between, arc_pts, poly, mirror, pair2, f, math
from waves import write

U = 32
R = 7 * U

def two_circle(c1, r1, c2, r2):
    """Centers at distance r1 from c1 and r2 from c2."""
    dx, dy = c2[0] - c1[0], c2[1] - c1[1]; d = math.hypot(dx, dy)
    a = (r1 * r1 - r2 * r2 + d * d) / (2 * d); h = math.sqrt(max(r1 * r1 - a * a, 0))
    mx, my = c1[0] + a * dx / d, c1[1] + a * dy / d
    return [(mx + h * dy / d, my - h * dx / d), (mx - h * dy / d, my + h * dx / d)]

def tail(O, R=R, kt=1 / 8, ko=2, ki=1 / 2):
    """Tail at the bottom-left. Returns the closed tail region and the construction circles."""
    T = (O[0] - R, O[1] + R); rt = R * kt
    ro, ri = R * ko, R * ki
    # outer: circle of radius ro containing the bubble and the tip circle, tangent to both
    Ko = min(two_circle(O, ro - R, T, ro - rt), key=lambda k: k[0] - k[1])      # the left, upper solution: the edge runs down the left side
    # inner: circle of radius ri outside both, tangent to both
    Ki = max(two_circle(O, R + ri, T, rt + ri), key=lambda k: k[1] - k[0] * 0)  # the lower solution, under the bubble
    Ki = max(two_circle(O, R + ri, T, rt + ri), key=lambda k: k[1])
    So = (Ko[0] + (O[0] - Ko[0]) * ro / (ro - R), Ko[1] + (O[1] - Ko[1]) * ro / (ro - R))   # outer arc meets the bubble
    Qo = (Ko[0] + (T[0] - Ko[0]) * ro / (ro - rt), Ko[1] + (T[1] - Ko[1]) * ro / (ro - rt))  # outer arc meets the tip
    Si = (O[0] + (Ki[0] - O[0]) * R / (R + ri), O[1] + (Ki[1] - O[1]) * R / (R + ri))       # inner arc meets the bubble
    Qi = (T[0] + (Ki[0] - T[0]) * rt / (rt + ri), T[1] + (Ki[1] - T[1]) * rt / (rt + ri))   # inner arc meets the tip
    pts = [O] + arc_between(Ko, ro, So, Qo, 'short', O) + arc_between(T, rt, Qo, Qi, 'far', O)[1:] + arc_between(Ki, ri, Qi, Si, 'short', O)[1:] + [O]
    return pts, dict(T=T, rt=rt, Ko=Ko, ro=ro, Ki=Ki, ri=ri, So=So, Si=Si)

def bubble(O, flip=False, **kw):
    pts, _ = tail(O, **kw)
    if flip: pts = mirror(pts, O[0])
    return f'<circle cx="{f(O[0])}" cy="{f(O[1])}" r="{f(R)}"/><path d="{poly(pts)}"/>'

SAID, ECHO = (13 * U, 13 * U), (19 * U, 19 * U)
def P(**kw): return pair2(bubble(SAID, **kw), bubble(ECHO, flip=True, **kw))

V = {
  'G1-t8-o2-i2': P(),
  'G2-t6-o2-i2': P(kt=1 / 6),
  'G3-t8-o3-i3': P(ko=3, ki=1 / 3),
  'G4-t12-o2-i2': P(kt=1 / 12),
}
if __name__ == '__main__':
    for k, layers in V.items():
        write(k, layers, renditions=('Default', 'Dark'), sizes=((512, 1, ''), (60, 3, '-180')))
    pts, c = tail(SAID)
    print({k: tuple(round(x, 1) for x in v) if isinstance(v, tuple) else round(v, 1) for k, v in c.items()})
