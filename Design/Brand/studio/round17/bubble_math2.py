"""Said and echoed. Bubble radius R = 7u (u = 32, a quarter grid cell); said at (14u, 14u), echo one cell away at (18u, 18u).
Tail: a tip circle of radius R*kt, first placed as the fillet of the bubble's bounding-square corner, then moved out along
the diagonal by R*kd. Outer edge: the straight common tangent of bubble and tip. Inner edge: an arc of radius R*ki tangent to both."""
from bubble_math import *

def ext_tangent(C1, r1, C2, r2, pick):
    dx, dy = C2[0] - C1[0], C2[1] - C1[1]; D = math.hypot(dx, dy); a = math.atan2(dy, dx)
    b = math.acos((r1 - r2) / D)
    ns = [(math.cos(a + s * b), math.sin(a + s * b)) for s in (1, -1)]
    n = min(ns, key=pick)
    return (C1[0] + r1 * n[0], C1[1] + r1 * n[1]), (C2[0] + r2 * n[0], C2[1] + r2 * n[1])

def tail2(O, kt=1 / 8, kd=0.0, ki=1 / 2):
    rt, ri = R * kt, R * ki
    s = R * kd / math.sqrt(2)
    T = (O[0] - R + rt - s, O[1] + R - rt + s)
    P1, P2 = ext_tangent(O, R, T, rt, pick=lambda n: n[0] + n[1])        # the outer (upper-left) tangent
    Ki = max(two_circle(O, R + ri, T, rt + ri), key=lambda k: k[1])
    Si = (O[0] + (Ki[0] - O[0]) * R / (R + ri), O[1] + (Ki[1] - O[1]) * R / (R + ri))
    Qi = (T[0] + (Ki[0] - T[0]) * rt / (rt + ri), T[1] + (Ki[1] - T[1]) * rt / (rt + ri))
    pts = [O, P1] + arc_between(T, rt, P2, Qi, 'far', O) + arc_between(Ki, ri, Qi, Si, 'short', O)[1:] + [O]
    return pts, dict(T=T, rt=rt, Ki=Ki, ri=ri, P1=P1, P2=P2, Si=Si, Qi=Qi)

def bubble2(O, flip=False, **kw):
    pts, _ = tail2(O, **kw)
    if flip: pts = mirror(pts, O[0])
    return f'<circle cx="{f(O[0])}" cy="{f(O[1])}" r="{f(R)}"/><path d="{poly(pts)}"/>'

def P2_(**kw): return pair2(bubble2(SAID, **kw), bubble2(ECHO, flip=True, **kw))
V = {
  'H1-corner': P2_(),
  'H2-out8': P2_(kd=1 / 8),
  'H3-out8-t6-i3': P2_(kd=1 / 8, kt=1 / 6, ki=1 / 3),
  'H4-out4': P2_(kd=1 / 4),
}
if __name__ == '__main__':
    for k, layers in V.items():
        write(k, layers, renditions=('Default', 'Dark'), sizes=((512, 1, ''), (60, 3, '-180')))
    print(' '.join(V))
