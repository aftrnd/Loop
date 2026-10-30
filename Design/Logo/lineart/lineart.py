"""Engraving-style line art of 3D loops with true hidden-line gaps, for the Loop app icon.

Each form is a set of 3D curves. They are projected orthographically after a tilt chosen so a circle in the loop's
plane projects to an ellipse of ratio 1/phi. Wherever a nearer curve crosses in front of a farther one, the farther
curve is cut back by the nearer curve's half width plus a clearance, leaving real gaps (no painted halos), so the
result works as a single transparent Icon Composer layer.
"""
import math
from collections import defaultdict

PHI = (1 + 5 ** 0.5) / 2
TILT = math.acos(1 / PHI)            # ellipse ratio 1/phi


def rotate(p, tilt=TILT, azimuth=0.0):
    x, y, z = p
    x, y = x * math.cos(azimuth) - y * math.sin(azimuth), x * math.sin(azimuth) + y * math.cos(azimuth)
    y, z = y * math.cos(tilt) - z * math.sin(tilt), y * math.sin(tilt) + z * math.cos(tilt)
    return x, y, z                    # screen x, screen y (down after flip below), depth (larger is nearer)


def mobius(strands=9, half_width=1 / PHI ** 2, samples=720):
    curves = []
    for k in range(strands):
        v = -half_width + 2 * half_width * k / (strands - 1)
        if v < -1e-9:
            continue                  # a strand at v continues as -v after one turn; draw each pair once
        turns = 1 if abs(v) < 1e-9 else 2
        n = samples * turns
        pts = []
        for i in range(n + 1):
            u = 2 * math.pi * turns * i / n
            r = 1 + v * math.cos(u / 2)
            pts.append((r * math.cos(u), r * math.sin(u), v * math.sin(u / 2)))
        curves.append(pts)
    return curves


def torus(rings=34, tube=1 / PHI ** 2, samples=160):
    curves = []
    for k in range(rings):
        u = 2 * math.pi * k / rings
        pts = []
        for i in range(samples + 1):
            v = 2 * math.pi * i / samples
            r = 1 + tube * math.cos(v)
            pts.append((r * math.cos(u), r * math.sin(u), tube * math.sin(v)))
        curves.append(pts)
    return curves


def depth_buffer(surface, u_range, v_range, nu, nv, to_screen, res):
    """Rasterizes a parametric surface into a res x res buffer of the nearest depth (larger is nearer)."""
    buf = [[-1e9] * res for _ in range(res)]
    grid = [[to_screen(surface(u_range[0] + (u_range[1] - u_range[0]) * i / nu,
                               v_range[0] + (v_range[1] - v_range[0]) * j / nv))
             for j in range(nv + 1)] for i in range(nu + 1)]
    def tri(a, b, c):
        minx, maxx = max(0, int(min(a[0], b[0], c[0]))), min(res - 1, int(max(a[0], b[0], c[0])) + 1)
        miny, maxy = max(0, int(min(a[1], b[1], c[1]))), min(res - 1, int(max(a[1], b[1], c[1])) + 1)
        den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(den) < 1e-12:
            return
        for py in range(miny, maxy + 1):
            for px in range(minx, maxx + 1):
                x, y = px + 0.5, py + 0.5
                w1 = ((b[1] - c[1]) * (x - c[0]) + (c[0] - b[0]) * (y - c[1])) / den
                w2 = ((c[1] - a[1]) * (x - c[0]) + (a[0] - c[0]) * (y - c[1])) / den
                w3 = 1 - w1 - w2
                if w1 < -1e-6 or w2 < -1e-6 or w3 < -1e-6:
                    continue
                z = w1 * a[2] + w2 * b[2] + w3 * c[2]
                if z > buf[py][px]:
                    buf[py][px] = z
    for i in range(nu):
        for j in range(nv):
            p00, p10, p01, p11 = grid[i][j], grid[i + 1][j], grid[i][j + 1], grid[i + 1][j + 1]
            tri(p00, p10, p11); tri(p00, p11, p01)
    return buf


def render(curves, surface, u_range, v_range, azimuth, stroke, clearance, size=1024, fill=0.62, tilt=TILT,
           color="#FFFFFF", res=512, depth_margin=0.25, nu=360, nv=12, min_run=None, layers=False):
    """Projects `curves` (lying on `surface`) and cuts them wherever the surface is nearer than the curve by more
    than `depth_margin` within `clearance` points of it, so hidden parts vanish with a clean gap at every crossing."""
    proj = [[rotate(p, tilt=tilt, azimuth=azimuth) for p in c] for c in curves]
    xs = [p[0] for c in proj for p in c]; ys = [p[1] for c in proj for p in c]
    span = max(max(xs) - min(xs), max(ys) - min(ys))
    k = fill * size / span
    cx, cy = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
    def to_canvas(p):
        x, y, z = rotate(p, tilt=tilt, azimuth=azimuth)
        return size / 2 + (x - cx) * k, size / 2 - (y - cy) * k, z
    scale = res / size
    buf = depth_buffer(surface, u_range, v_range, nu, nv,
                       lambda p: (lambda q: (q[0] * scale, q[1] * scale, q[2]))(to_canvas(p)), res)
    reach = max(1, int(math.ceil((stroke / 2 + clearance) * scale)))
    offsets = [(dx, dy) for dx in range(-reach, reach + 1) for dy in range(-reach, reach + 1) if dx * dx + dy * dy <= reach * reach]
    paths = []
    min_len = min_run if min_run is not None else stroke * 3
    def keep(run):
        return sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(run, run[1:])) >= min_len
    for c in curves:
        start = len(paths)
        first_visible = None
        run = []
        for p in c:
            x, y, z = to_canvas(p)
            bx, by = int(x * scale), int(y * scale)
            hidden = False
            for dx, dy in offsets:
                qx, qy = bx + dx, by + dy
                if 0 <= qx < res and 0 <= qy < res and buf[qy][qx] > z + depth_margin:
                    hidden = True
                    break
            if hidden:
                if len(run) > 1 and keep(run): paths.append(run)
                run = []
            else:
                run.append((x, y, z))
        # A closed curve's last run and first run meet where the curve starts: join them into one line
        if len(run) > 1 and len(paths) > start and paths[start] and run[-1][:2] != run[0][:2]:
            fx, fy = paths[start][0][0], paths[start][0][1]
            if math.hypot(run[-1][0] - fx, run[-1][1] - fy) < stroke and len(paths) - start >= 1:
                paths[start] = run + paths[start][1:]
                run = []
        if len(run) > 1 and keep(run):
            paths.append(run)
    if layers:
        near = [r for r in paths if sum(p[2] for p in r) / len(r) >= 0]
        far = [r for r in paths if sum(p[2] for p in r) / len(r) < 0]
        return svg_paths(near, stroke, size, color), svg_paths(far, stroke, size, color)
    d = "".join("M" + "L".join(f"{p[0]:.1f} {p[1]:.1f}" for p in r) for r in paths)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {size} {size}" width="{size}" height="{size}">'
            f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{stroke:.2f}" stroke-linecap="round" stroke-linejoin="round"/></svg>\n')


def mobius_surface(half_width=1 / PHI ** 2):
    def f(u, v):
        r = 1 + v * math.cos(u / 2)
        return r * math.cos(u), r * math.sin(u), v * math.sin(u / 2)
    return f, (0, 2 * math.pi), (-half_width, half_width)


def torus_surface(tube=1 / PHI ** 2):
    def f(u, v):
        r = 1 + tube * math.cos(v)
        return r * math.cos(u), r * math.sin(u), tube * math.sin(v)
    return f, (0, 2 * math.pi), (0, 2 * math.pi)


def svg_paths(polylines, stroke, size=1024, color="#FFFFFF"):
    d = "".join("M" + "L".join(f"{p[0]:.1f} {p[1]:.1f}" for p in r) for r in polylines)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {size} {size}" width="{size}" height="{size}">'
            f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{stroke:.2f}" stroke-linecap="round" stroke-linejoin="round"/></svg>\n')


def loop_of_loops(count=24, size=1024, fill=0.62, stroke=6.0, samples=240):
    """`count` equal circles with centres evenly spaced on a smaller circle. Circle radius r and centre-ring radius a
    stand in golden ratio (a = r / phi), so the woven torus has an inner opening of r - a and an outer edge of r + a."""
    outer = fill * size / 2
    r = outer / (1 + 1 / PHI)
    a = r / PHI
    c = size / 2
    lines = []
    for k in range(count):
        t = 2 * math.pi * k / count
        ox, oy = c + a * math.cos(t), c + a * math.sin(t)
        lines.append([(ox + r * math.cos(2 * math.pi * i / samples), oy + r * math.sin(2 * math.pi * i / samples))
                      for i in range(samples + 1)])
    return svg_paths(lines, stroke, size)


def twisted_band(strands=9, size=1024, fill=0.62, stroke=7.0, clearance=7.0, samples=1440):
    """Concentric rings that trade inside for outside through a half twist at the bottom. Strand k sits at offset
    o_k across the band; its offset follows o_k * cos(theta / 2), so after a full turn it arrives at -o_k (the Mobius
    rule, flattened). Where strands cross, the strand rising toward the viewer stays whole and the other is cut."""
    c = size / 2
    outer = fill * size / 2
    half = outer / PHI ** 2                     # band half width
    R = outer - half
    pts = []
    for k in range(strands):
        o = -half + 2 * half * k / (strands - 1)
        turns = 1 if abs(o) < 1e-9 else 2
        if o < -1e-9:
            continue
        line = []
        for i in range(samples * turns + 1):
            th = 2 * math.pi * turns * i / (samples * turns) + math.pi / 2   # twist centred at the bottom
            off = o * math.cos((th - math.pi / 2) / 2)
            depth = o * math.sin((th - math.pi / 2) / 2)
            line.append((c + (R + off) * math.cos(th), c + (R + off) * math.sin(th), depth))
        pts.append(line)
    reach = stroke + clearance
    segs = [(li, i, p, q) for li, l in enumerate(pts) for i, (p, q) in enumerate(zip(l, l[1:]))]
    from collections import defaultdict
    grid = defaultdict(list)
    for s in segs:
        _, _, p, q = s
        for gx in range(int(min(p[0], q[0]) // reach) - 1, int(max(p[0], q[0]) // reach) + 2):
            for gy in range(int(min(p[1], q[1]) // reach) - 1, int(max(p[1], q[1]) // reach) + 2):
                grid[(gx, gy)].append(s)
    out = []
    for li, l in enumerate(pts):
        run = []
        for i, (x, y, z) in enumerate(l):
            hidden = False
            for (lj, j, p, q) in grid[(int(x // reach), int(y // reach))]:
                if lj == li and min(abs(j - i), len(l) - abs(j - i)) < 20:
                    continue
                dx, dy = q[0] - p[0], q[1] - p[1]
                L2 = dx * dx + dy * dy or 1e-9
                t = max(0.0, min(1.0, ((x - p[0]) * dx + (y - p[1]) * dy) / L2))
                if math.hypot(x - p[0] - dx * t, y - p[1] - dy * t) < reach and p[2] + (q[2] - p[2]) * t > z + half * 0.15:
                    hidden = True
                    break
            if hidden:
                if len(run) > 1: out.append(run)
                run = []
            else:
                run.append((x, y))
        if len(run) > 1:
            out.append(run)
    return svg_paths(out, stroke, size)
