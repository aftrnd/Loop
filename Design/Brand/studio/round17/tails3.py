"""Soft tails: the tip is a circle; every edge is an arc tangent to its neighbors."""
from tails2 import *

def arc_between(K, r, p, q, pick, ref):
    a0, a1 = math.atan2(p[1] - K[1], p[0] - K[0]), math.atan2(q[1] - K[1], q[0] - K[0])
    cands = []
    for end in (a1, a1 + 2 * math.pi, a1 - 2 * math.pi):
        if abs(end - a0) <= 2 * math.pi: cands.append(end)
    best = None
    for end in cands:
        mid = (a0 + end) / 2
        m = (K[0] + r * math.cos(mid), K[1] + r * math.sin(mid))
        score = {'short': abs(end - a0), 'far': -math.hypot(m[0] - ref[0], m[1] - ref[1])}[pick]
        if best is None or score < best[0]: best = (score, end)
    return arc_pts(K, r, a0, best[1], n=64)

def soft_tail(xL, yb, rx, h, tip=(-0.03, 0.03), rt=0.065, y1=None, rho=0.16):
    C = (xL + rx, yb - rx)
    Tc = (xL + tip[0] * h, yb + tip[1] * h); rt *= h; rho *= h
    S = (xL, y1 if y1 is not None else yb - rx)
    dx, dy = Tc[0] - xL, Tc[1] - S[1]
    s = (dx * dx + dy * dy - rt * rt) / (2 * (rt - dx))          # outer arc: tangent to the side at S, external to the tip circle
    K1 = (xL - s, S[1])
    Q1 = (K1[0] + (Tc[0] - K1[0]) * s / (s + rt), K1[1] + (Tc[1] - K1[1]) * s / (s + rt))
    # inner fillet: external to the corner circle and to the tip circle
    a, b = rx + rho, rt + rho
    ddx, ddy = Tc[0] - C[0], Tc[1] - C[1]; d = math.hypot(ddx, ddy); base = math.atan2(ddy, ddx)
    ang = math.acos(max(-1, min(1, (d * d + a * a - b * b) / (2 * d * a))))
    sols = [(C[0] + a * math.cos(base + sg * ang), C[1] + a * math.sin(base + sg * ang)) for sg in (1, -1)]
    K2 = max(sols, key=lambda k: k[0] + k[1])
    P2 = (C[0] + (K2[0] - C[0]) * rx / a, C[1] + (K2[1] - C[1]) * rx / a)
    Q2 = (Tc[0] + (K2[0] - Tc[0]) * rt / b, Tc[1] + (K2[1] - Tc[1]) * rt / b)
    outer = arc_between(K1, s, S, Q1, 'short', C)
    tipa = arc_between(Tc, rt, Q1, Q2, 'far', C)
    inner = arc_between(K2, rho, Q2, P2, 'short', C)
    return [C] + outer + tipa[1:] + inner[1:] + [C]

def sb(cx, cy, w, h, rx, flip=False, **kw):
    body = f'<rect x="{f(cx - w / 2)}" y="{f(cy - h / 2)}" width="{f(w)}" height="{f(h)}" rx="{f(rx)}"/>'
    tail = soft_tail(cx - w / 2, cy + h / 2, rx, h, **kw)
    if flip: tail = mirror(tail, cx)
    return body + f'<path d="{poly(tail)}"/>'

def cb(cx, cy, R, flip=False, **kw):
    tail = soft_tail(cx - R, cy + R, R, 2 * R, **kw)
    if flip: tail = mirror(tail, cx)
    return f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(R)}"/><path d="{poly(tail)}"/>'

V = {
  'O1-rrect-soft': pair2(sb(420, 420, 448, 336, 112), sb(604, 596, 448, 336, 112, flip=True)),
  'O2-rrect-defined': pair2(sb(424, 416, 448, 336, 112, tip=(-0.06, 0.07), rt=0.08, y1=416 + 168 - 150), sb(600, 592, 448, 336, 112, flip=True, tip=(-0.06, 0.07), rt=0.08, y1=592 + 168 - 150)),
  'O3-capsule': pair2(sb(416, 436, 480, 288, 144, tip=(-0.02, 0.05), rt=0.09), sb(608, 596, 480, 288, 144, flip=True, tip=(-0.02, 0.05), rt=0.09)),
  'O4-soft-rect': pair2(sb(424, 420, 416, 352, 148, tip=(-0.05, 0.06), rt=0.08), sb(600, 596, 416, 352, 148, flip=True, tip=(-0.05, 0.06), rt=0.08)),
  'O5-circle': pair2(cb(432, 424, 212, tip=(0.06, -0.02), rt=0.05, rho=0.12), cb(592, 588, 212, flip=True, tip=(0.06, -0.02), rt=0.05, rho=0.12)),
}
if __name__ == '__main__':
    for k, layers in V.items():
        write(k, layers, renditions=('Default', 'Dark'), sizes=((512, 1, ''), (60, 3, '-180')))
    print(' '.join(V))
