"""Said and echoed, soft circle bodies with a defined message tail built from tangent arcs."""
from tails3 import *
from echoed2 import bub_ios

def circ_tail(cx, cy, R, theta=135, dT=1.18, rt=0.10, rho=0.26, phi=172):
    C = (cx, cy)
    th, ph = math.radians(theta), math.radians(phi)
    Tc = (cx + dT * R * math.cos(th), cy + dT * R * math.sin(th)); rt *= R; rho *= R
    S = (cx + R * math.cos(ph), cy + R * math.sin(ph)); u = (math.cos(ph), math.sin(ph))
    v = (S[0] - Tc[0], S[1] - Tc[1])
    s = (v[0] ** 2 + v[1] ** 2 - rt * rt) / (2 * (u[0] * v[0] + u[1] * v[1] - rt))   # outer arc tangent to the body at S, holding the tip circle
    K1 = (S[0] - u[0] * s, S[1] - u[1] * s)
    Q1 = (K1[0] + (Tc[0] - K1[0]) * s / (s - rt), K1[1] + (Tc[1] - K1[1]) * s / (s - rt))
    a, b = R + rho, rt + rho
    ddx, ddy = Tc[0] - cx, Tc[1] - cy; d = math.hypot(ddx, ddy); base = math.atan2(ddy, ddx)
    ang = math.acos(max(-1, min(1, (d * d + a * a - b * b) / (2 * d * a))))
    sols = [(cx + a * math.cos(base + sg * ang), cy + a * math.sin(base + sg * ang)) for sg in (1, -1)]
    K2 = min(sols, key=lambda k: math.atan2(k[1] - cy, k[0] - cx) % (2 * math.pi))      # the one toward the bottom (smaller angle)
    P2 = (cx + (K2[0] - cx) * R / a, cy + (K2[1] - cy) * R / a)
    Q2 = (Tc[0] + (K2[0] - Tc[0]) * rt / b, Tc[1] + (K2[1] - Tc[1]) * rt / b)
    outer = arc_between(K1, s, S, Q1, 'short', C)
    tipa = arc_between(Tc, rt, Q1, Q2, 'far', C)
    inner = arc_between(K2, rho, Q2, P2, 'short', C)
    return [C] + outer + tipa[1:] + inner[1:] + [C]

def cbub(cx, cy, R, flip=False, **kw):
    tail = circ_tail(cx, cy, R, **kw)
    if flip: tail = mirror(tail, cx)
    return f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(R)}"/><path d="{poly(tail)}"/>'

R = 224
def P(**kw): return pair2(cbub(432, 432, R, **kw), cbub(592, 592, R, flip=True, **kw))
V = {
  'E0-round20': pair(bub_ios(432, 432, R), bub_ios(592, 592, R, 'br')),
  'E1-hint': P(theta=135, dT=1.12, rt=0.14, rho=0.34, phi=176),
  'E2-defined': P(theta=130, dT=1.18, rt=0.11, rho=0.26, phi=172),
  'E3-more': P(theta=127, dT=1.24, rt=0.09, rho=0.22, phi=170),
}
if __name__ == '__main__':
    for k, layers in V.items():
        write(k, layers, renditions=('Default', 'Dark'), sizes=((512, 1, ''), (60, 3, '-180')))
    print(' '.join(V))
