"""The iOS icon mask, measured from ictool's own render (mask/edge2.txt, 2048 px), and concentric insets of it."""
import math

def _quadrant():
    rows = {}
    for line in open('mask/edge2.txt').read().split('\n')[1:]:
        if not line.strip(): continue
        y, x = line.split(); rows[int(y)] = float(x)
    # left edge x(y) in 1024 units, sampled at row centers
    left = [(rows[y] / 2, (y + 0.5) / 2) for y in range(1024) if rows[y] >= 0]
    left = [(x, y) for x, y in left if y <= 512]
    # keep the steep half (below the diagonal), mirror it for the shallow half
    steep = [(x, y) for x, y in left if y >= x]
    shallow = [(y, x) for x, y in reversed(steep)]
    pts = shallow + steep
    # dedupe and order from top edge to left edge
    pts = [(512.0, 0.0)] + [p for p in pts if p[0] < 511 and p[1] < 511] + [(0.0, 512.0)]
    return rdp(pts, 0.04)

def rdp(pts, eps):
    if len(pts) < 3: return pts
    (x0, y0), (x1, y1) = pts[0], pts[-1]
    L = math.hypot(x1 - x0, y1 - y0) or 1e-9
    dmax, k = 0, 0
    for i in range(1, len(pts) - 1):
        x, y = pts[i]
        d = abs((y1 - y0) * x - (x1 - x0) * y + x1 * y0 - y1 * x0) / L
        if d > dmax: dmax, k = d, i
    if dmax <= eps: return [pts[0], pts[-1]]
    return rdp(pts[:k + 1], eps)[:-1] + rdp(pts[k:], eps)

def outline(inset=0.0):
    q = _quadrant()  # top-left corner, from the top edge to the left edge
    # full closed outline clockwise starting top-left corner region
    tl = q
    tr = [(1024 - y, x) for x, y in q]          # rotate 90 degrees: (x, y) -> (1024 - y, x)
    br = [(1024 - x, 1024 - y) for x, y in q]
    bl = [(y, 1024 - x) for x, y in q]
    # q runs from the top edge (small y) down to the left edge (small x); reverse so the path goes clockwise
    ring = list(reversed(tl)) + list(reversed(tr)) + list(reversed(br)) + list(reversed(bl))
    if inset:
        # resample at 1 unit along the outline so normals are even, then offset along smoothed normals
        dense = []
        n = len(ring)
        for i in range(n):
            (x0, y0), (x1, y1) = ring[i], ring[(i + 1) % n]
            L = math.hypot(x1 - x0, y1 - y0); k = max(1, int(L))
            for t in range(k):
                dense.append((x0 + (x1 - x0) * t / k, y0 + (y1 - y0) * t / k))
        n = len(dense); moved = []; w = 6
        for i in range(n):
            (x0, y0), (x1, y1) = dense[i - w], dense[(i + w) % n]
            tx, ty = x1 - x0, y1 - y0; L = math.hypot(tx, ty)
            nx, ny = -ty / L, tx / L
            if (512 - dense[i][0]) * nx + (512 - dense[i][1]) * ny < 0: nx, ny = -nx, -ny
            moved.append((dense[i][0] + nx * inset, dense[i][1] + ny * inset))
        ring = rdp_closed(moved, 0.04)
    return ring

def path(inset=0.0):
    pts = outline(inset)
    return 'M' + 'L'.join('%.2f %.2f' % p for p in pts) + 'Z'

if __name__ == '__main__':
    q = _quadrant()
    print('points', len(q), 'first', q[0], 'last', q[-1])
    d = path(); print(len(d), d[:120])

def rdp_closed(pts, eps):
    # split at the four extreme points so each piece is open
    n = len(pts)
    idx = sorted({min(range(n), key=lambda i: pts[i][0]), max(range(n), key=lambda i: pts[i][0]),
                  min(range(n), key=lambda i: pts[i][1]), max(range(n), key=lambda i: pts[i][1])})
    out = []
    for a, b in zip(idx, idx[1:] + [idx[0] + n]):
        seg = [pts[i % n] for i in range(a, b + 1)]
        out += rdp(seg, eps)[:-1]
    return out
