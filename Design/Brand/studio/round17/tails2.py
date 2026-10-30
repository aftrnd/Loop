from tails import *

def flick2(xL, yb, rx, h, tip_out=0.06, drop=0.04, rho=0.25, rise=None):
    """Tail at a rounded corner (center C, radius rx). Outer: arc tangent to the straight side, sweeping out to the tip.
    Inner: arc through the tip, externally tangent to the corner circle."""
    C = (xL + rx, yb - rx)
    T = (xL - tip_out * h, yb + drop * h)
    P1 = (xL, yb - max(rx, (rise or 0) * h))
    s = ((T[0] - xL) ** 2 + (T[1] - P1[1]) ** 2) / (-2 * (T[0] - xL))
    K1 = (xL - s, P1[1])
    outer = arc_pts(K1, s, 0.0, math.atan2(T[1] - K1[1], T[0] - K1[0]))
    r = rho * h
    dx, dy = T[0] - C[0], T[1] - C[1]; d = math.hypot(dx, dy); base = math.atan2(dy, dx)
    a = rx + r
    ang = math.acos(max(-1, min(1, (d * d + a * a - r * r) / (2 * d * a))))
    sols = [(C[0] + a * math.cos(base + sg * ang), C[1] + a * math.sin(base + sg * ang)) for sg in (1, -1)]
    K = max(sols, key=lambda k: k[0] + k[1])
    P2 = (C[0] + (K[0] - C[0]) * rx / a, C[1] + (K[1] - C[1]) * rx / a)
    t0 = math.atan2(T[1] - K[1], T[0] - K[0]); t1 = math.atan2(P2[1] - K[1], P2[0] - K[0])
    if abs(t1 - t0) > math.pi: t1 += 2 * math.pi if t1 < t0 else -2 * math.pi
    inner = arc_pts(K, r, t0, t1)
    return [C] + outer + inner[1:] + [C]

def rb(cx, cy, w, h, rx, flip=False, **kw):
    body = f'<rect x="{f(cx - w / 2)}" y="{f(cy - h / 2)}" width="{f(w)}" height="{f(h)}" rx="{f(rx)}"/>'
    tail = flick2(cx - w / 2, cy + h / 2, rx, h, **kw)
    if flip: tail = mirror(tail, cx)
    return body + f'<path d="{poly(tail)}"/>'

def pair_xor(said, echo, refract=0.15):
    said_body = (f'<defs><mask id="m"><rect width="1024" height="1024" fill="#fff"/><g fill="#000">{echo}</g></mask></defs><g mask="url(#m)">{said}</g>')
    echo_body = (f'<defs><mask id="n"><rect width="1024" height="1024" fill="#fff"/><g fill="#000">{said}</g></mask></defs><g mask="url(#n)">{echo}</g>')
    return [g(echo_body, refract=refract), ink(said_body)]

V = {
  'N1-rrect': pair2(rb(420, 420, 448, 336, 112), rb(604, 596, 448, 336, 112, flip=True)),
  'N2-capsule': pair2(rb(416, 436, 480, 288, 144), rb(608, 596, 480, 288, 144, flip=True)),
  'N3-rrect-flick': pair2(rb(424, 420, 416, 352, 96, tip_out=0.09, drop=0.06, rho=0.2), rb(600, 596, 416, 352, 96, flip=True, tip_out=0.09, drop=0.06, rho=0.2)),
  'N4-rrect-negative': pair_xor(rb(420, 420, 448, 336, 112), rb(604, 596, 448, 336, 112, flip=True)),
  'N5-ios-ratio': pair2(rb(420, 420, 448, 352, 352 * 0.2237 * 1.6), rb(604, 596, 448, 352, 352 * 0.2237 * 1.6, flip=True)),
}
if __name__ == '__main__':
    for k, layers in V.items():
        write(k, layers, renditions=('Default', 'Dark'), sizes=((512, 1, ''), (60, 3, '-180')))
    print(' '.join(V))
