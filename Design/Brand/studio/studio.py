"""Loop mark studio: candidate marks on a 1024 tile, 64-unit module, and contact sheets."""
import math, os, subprocess, sys

M = 64            # module
C = 512           # tile center
f = lambda v: ('%.2f' % v).rstrip('0').rstrip('.')

def se_path(n, r, cx=C, cy=C, steps=720):
    pts = []
    for i in range(steps):
        t = 2 * math.pi * i / steps
        c, s = math.cos(t), math.sin(t)
        pts.append((cx + r * math.copysign(abs(c) ** (2 / n), c), cy - r * math.copysign(abs(s) ** (2 / n), s)))
    return 'M' + 'L'.join(f(x) + ' ' + f(y) for x, y in pts) + 'Z'

TILE = se_path(5, 512)

def poly(pts, close=True):
    return 'M' + 'L'.join(f(x) + ' ' + f(y) for x, y in pts) + ('Z' if close else '')

def stroke(d, s, ink):
    return f'<path d="{d}" fill="none" stroke="{ink}" stroke-width="{f(s)}" stroke-linecap="round" stroke-linejoin="round"/>'

def fill(d, ink, rule='nonzero'):
    return f'<path d="{d}" fill="{ink}" fill-rule="{rule}"/>'

def circle_d(cx, cy, r):
    return f'M{f(cx-r)} {f(cy)}A{f(r)} {f(r)} 0 1 0 {f(cx+r)} {f(cy)}A{f(r)} {f(r)} 0 1 0 {f(cx-r)} {f(cy)}Z'

# ---------- candidates: each returns svg elements for a given ink and ground ----------

def lissajous(a=3, b=2, delta=math.pi/2, A=4.5*M, s=M, superN=None):
    def g(u):
        v = math.sin(u)
        return v if superN is None else math.copysign(abs(v) ** (2 / superN), v)
    pts = []
    N = 2000
    for i in range(N):
        t = 2 * math.pi * i / N
        pts.append((C + A * g(a * t + delta), C - A * g(b * t)))
    d = poly(pts)
    return lambda ink, ground: stroke(d, s, ink)

def vesica(r=3*M, s=M, lens=False, rings=True):
    c1, c2 = C - r / 2, C + r / 2
    h = r * math.sin(math.radians(60))
    lens_d = f'M{f(C)} {f(C-h)}A{f(r)} {f(r)} 0 0 1 {f(C)} {f(C+h)}A{f(r)} {f(r)} 0 0 1 {f(C)} {f(C-h)}Z'
    def draw(ink, ground):
        out = ''
        if lens: out += fill(lens_d, ink)
        if rings: out += stroke(circle_d(c1, C, r), s, ink) + stroke(circle_d(c2, C, r), s, ink)
        return out
    return draw

def quadrant(R=8*M, s=M):
    # corner at bottom left, centroid-balanced
    k = 4 * R / (3 * math.pi)
    x0, y0 = C - k, C + k     # put area centroid at tile center
    d = f'M{f(x0)} {f(y0-R)}L{f(x0)} {f(y0)}L{f(x0+R)} {f(y0)}A{f(R)} {f(R)} 0 0 0 {f(x0)} {f(y0-R)}Z'
    return lambda ink, ground: stroke(d, s, ink)

def capsule(w=9*M, h=4*M, s=M, angle=0):
    r = h / 2
    d = f'M{f(C-w/2+r)} {f(C-r)}L{f(C+w/2-r)} {f(C-r)}A{f(r)} {f(r)} 0 0 1 {f(C+w/2-r)} {f(C+r)}L{f(C-w/2+r)} {f(C+r)}A{f(r)} {f(r)} 0 0 1 {f(C-w/2+r)} {f(C-r)}Z'
    return lambda ink, ground: f'<g transform="rotate({angle} {C} {C})">' + stroke(d, s, ink) + '</g>'

# ---------- sheet ----------

def tile_svg(mark, dark, glyph_scale=1.0):
    ground = '#0b0b0b' if dark else '#ffffff'
    ink = '#ffffff' if dark else '#0b0b0b'
    edge = '' if dark else '<path d="%s" fill="none" stroke="#dcdcdc" stroke-width="4"/>' % TILE
    return (f'<path d="{TILE}" fill="{ground}"/>{edge}'
            f'<g transform="translate({C} {C}) scale({glyph_scale}) translate({-C} {-C})">{mark(ink, ground)}</g>')

def place(inner, x, y, size):
    return f'<g transform="translate({f(x)} {f(y)}) scale({f(size/1024)})">{inner}</g>'

def sheet(rows, path, W=1800):
    """rows: list of (label, mark). Each row: light 360, dark 360, light 180, dark 180, light 87, dark 87."""
    rh = 420
    H = W
    body = [f'<rect width="{W}" height="{H}" fill="#f0f0f0"/>']
    for i, (label, mark) in enumerate(rows):
        y = 40 + i * rh
        body.append(f'<text x="40" y="{y+16}" font-family="Menlo" font-size="18" fill="#555">{label}</text>')
        y += 36
        x = 40
        for size, dark in ((360, False), (360, True), (180, False), (180, True), (87, False), (87, True)):
            body.append(place(tile_svg(mark, dark), x, y, size))
            x += size + 36
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">' + ''.join(body) + '</svg>'
    open(path, 'w').write(svg)
    out = os.path.dirname(os.path.abspath(path)) or '.'
    subprocess.run(['qlmanage', '-t', '-s', str(W), '-o', out, path], capture_output=True)
    print('rendered', path + '.png')
