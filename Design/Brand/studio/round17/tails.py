"""Message bubbles with constructed tails: tangent lines and arcs, no free-hand curves."""
from echoed import *
import iosmask
Q = iosmask.outline()

def arc_pts(K, rho, a0, a1, n=48):
    return [(K[0] + rho * math.cos(a0 + (a1 - a0) * i / n), K[1] + rho * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n + 1)]

def poly(pts): return 'M' + 'L'.join(f'{f(x)} {f(y)}' for x, y in pts) + 'Z'

def circle_tail(cx, cy, R, tip=(-0.62, 1.12), rho=0.55):
    """Outer edge: the tangent from the tip to the circle. Inner edge: an arc of radius rho*R through the tip, tangent to the circle."""
    T = (cx + tip[0] * R, cy + tip[1] * R); rho *= R
    # tangent point on the circle, the one on the outer (left) side
    dx, dy = T[0] - cx, T[1] - cy; d = math.hypot(dx, dy); base = math.atan2(dy, dx); off = math.acos(R / d)
    P1 = (cx + R * math.cos(base + off), cy + R * math.sin(base + off))
    # inner arc: circle K with |K - T| = rho and |K - C| = R + rho, on the bubble's bottom side
    a, b = R + rho, rho
    ang = math.acos((d * d + a * a - b * b) / (2 * d * a))
    sols = [(cx + a * math.cos(base + s * ang), cy + a * math.sin(base + s * ang)) for s in (1, -1)]
    K = max(sols, key=lambda k: k[0])                       # the one toward the bubble's bottom-right
    P2 = (cx + (K[0] - cx) * R / a, cy + (K[1] - cy) * R / a)
    t0 = math.atan2(T[1] - K[1], T[0] - K[0]); t1 = math.atan2(P2[1] - K[1], P2[0] - K[0])
    if abs(t1 - t0) > math.pi: t1 += 2 * math.pi if t1 < t0 else -2 * math.pi
    return [(cx, cy), P1, T] + arc_pts(K, rho, t0, t1)

def flick_tail(xL, yb, w, tip_out=0.10, drop=0.12, rise=0.30, rho_in=0.62):
    """For a body with a straight left side at xL and bottom at yb (size w). Outer arc leaves the side tangentially and sweeps
    out to the tip; inner arc returns tangent to the bottom edge."""
    T = (xL - tip_out * w, yb + drop * w)
    P1 = (xL, yb - rise * w)
    # outer arc: tangent to the vertical side at P1, center at (xL - s, P1y), passing through T
    s = ((T[0] - xL) ** 2 + (T[1] - P1[1]) ** 2 + 2 * (T[0] - xL) * 0) / (2 * (xL - T[0])) if T[0] < xL else 1e6
    # solve |K - T| = s with K = (xL - s, P1y): (T.x - xL + s)^2 + (T.y - P1y)^2 = s^2
    s = ((T[0] - xL) ** 2 + (T[1] - P1[1]) ** 2) / (-2 * (T[0] - xL))
    K1 = (xL - s, P1[1])
    o0, o1 = 0.0, math.atan2(T[1] - K1[1], T[0] - K1[0])
    outer = arc_pts(K1, s, o0, o1)
    # inner arc: tangent to the bottom edge at P2, center below it at (P2x, yb + r), through T
    r = rho_in * w
    P2x = T[0] + math.sqrt(max(r * r - (yb + r - T[1]) ** 2, 0))
    K2 = (P2x, yb + r)
    i0, i1 = math.atan2(T[1] - K2[1], T[0] - K2[0]), -math.pi / 2
    if i1 < i0: i1 += 2 * math.pi
    inner = arc_pts(K2, r, i0, i1)
    return [(xL + 0.5 * w, yb - rise * w)] + outer + inner[1:] + [(P2x, yb - rise * w)]

def mirror(pts, cx): return [(2 * cx - x, y) for x, y in pts]

def circle_bubble(cx, cy, R, flip=False):
    tail = circle_tail(cx, cy, R)
    if flip: tail = mirror(tail, cx)
    return f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(R)}"/><path d="{poly(tail)}"/>'

def squircle_bubble(cx, cy, s, flip=False):
    k = s / 1024
    body = poly([(cx + (x - 512) * k, cy + (y - 512) * k) for x, y in Q])
    tail = flick_tail(cx - s / 2, cy + s / 2, s)
    if flip: tail = mirror(tail, cx)
    return f'<path d="{body}"/><path d="{poly(tail)}"/>'

def rrect_bubble(cx, cy, w, h, rx, flip=False):
    body = f'<rect x="{f(cx - w / 2)}" y="{f(cy - h / 2)}" width="{f(w)}" height="{f(h)}" rx="{f(rx)}"/>'
    tail = flick_tail(cx - w / 2, cy + h / 2, h)
    if flip: tail = mirror(tail, cx)
    return body + f'<path d="{poly(tail)}"/>'

def pair2(said, echo, refract=0.15):
    return [g(f'<g>{echo}</g>', refract=refract), ink(said)]

V = {
  'M1-circle-tangent': pair2(circle_bubble(432, 424, 216), circle_bubble(592, 584, 216, flip=True)),
  'M2-squircle-flick': pair2(squircle_bubble(428, 420, 400), squircle_bubble(596, 588, 400, flip=True)),
  'M3-rrect-flick': pair2(rrect_bubble(420, 416, 448, 352, 128), rrect_bubble(604, 592, 448, 352, 128, flip=True)),
  'M4-capsule-flick': pair2(rrect_bubble(420, 432, 480, 288, 144), rrect_bubble(604, 592, 480, 288, 144, flip=True)),
}
if __name__ == '__main__':
    for k, layers in V.items():
        write(k, layers, renditions=('Default', 'Dark'), sizes=((512, 1, ''), (60, 3, '-180')))
    print(' '.join(V))
