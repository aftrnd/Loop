from echoed import *
import iosmask
Q = iosmask.outline()

def ios_corner_pts(cx, cy, r, corner):
    """The iOS icon mask's own corner, scaled to a square of side 2r centered on the bubble, for one quadrant."""
    k = 2 * r / 1024
    sx, sy = {'bl': (-1, 1), 'br': (1, 1), 'tl': (-1, -1), 'tr': (1, -1)}[corner]
    pts = [(cx + (x - 512) * k, cy + (y - 512) * k) for x, y in Q if (x - 512) * sx >= -0.01 and (y - 512) * sy >= -0.01]
    return pts

def bub_ios(cx, cy, r, corner='bl'):
    top, right, bottom, left = (cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)
    seq = [('tr', top, right), ('br', right, bottom), ('bl', bottom, left), ('tl', left, top)]
    d = f'M{f(top[0])} {f(top[1])}'
    for name, a, b in seq:
        if name == corner:
            pts = ios_corner_pts(cx, cy, r, corner)
            # order from a to b
            pts.sort(key=lambda p: math.atan2(p[1] - cy, p[0] - cx))
            ang = lambda p: math.atan2(p[1] - cy, p[0] - cx)
            a0, b0 = ang(a), ang(b)
            if b0 < a0: b0 += 2 * math.pi
            pts = sorted(pts, key=lambda p: (ang(p) - a0) % (2 * math.pi))
            d += ''.join(f'L{f(x)} {f(y)}' for x, y in pts) + f'L{f(b[0])} {f(b[1])}'
        else:
            d += f'A{f(r)} {f(r)} 0 0 1 {f(b[0])} {f(b[1])}'
    return d + 'Z'

R = 224
V = {
  'T1-ios-corner': pair(bub_ios(432, 432, R), bub_ios(592, 592, R, 'br')),
  'T2-fillet-quarter': pair(bub(432, 432, R, rc=R / 4), bub(592, 592, R, 'br', rc=R / 4)),
  'T3-fillet-half': pair(bub(432, 432, R, rc=R / 2), bub(592, 592, R, 'br', rc=R / 2)),
  'T4-ios-negative': pair(bub_ios(432, 432, R), bub_ios(592, 592, R, 'br'), xor=True),
  'T5-ios-quieter': pair(bub_ios(448, 448, 240), bub_ios(640, 640, 176, 'br')),
}
if __name__ == '__main__':
    for k, layers in V.items():
        write(k, layers, renditions=('Default', 'Dark'), sizes=((512, 1, ''), (60, 3, '-180')))
    print(' '.join(V))
