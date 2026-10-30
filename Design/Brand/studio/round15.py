"""Round fifteen: glass that means something. Each icon concept is a real Icon Composer document rendered with ictool."""
import itertools, json, math, os, random, shutil, subprocess
from c4 import configs
from rounded import swatch_arcs
from wordmark import band, circle, ring

IC = "/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"
OUT = '../round15'
C = 512
gray = lambda v, a=1: f"extended-gray:{v:.5f},{a:.5f}"
INK, WHITE = gray(0.04314), gray(1)
f = lambda v: ('%.2f' % v).rstrip('0').rstrip('.')


# ---------- geometry ----------

def c4_grid(n, seed, core=None):
    """n x n Truchet orientations with 90 degree rotational symmetry about the center corner, ring at the center."""
    rot = lambda i, j: (n - 1 - j, i)
    g = [[None] * n for _ in range(n)]
    rng = random.Random(seed)
    h = n // 2
    for k, (i, j) in enumerate([(h - 1, h - 1), (h, h - 1), (h, h), (h - 1, h)]):
        g[j][i] = k % 2
    if core:
        o = (n - len(core)) // 2
        for j, row in enumerate(core):
            for i, v in enumerate(row):
                g[j + o][i + o] = v
    for j in range(n):
        for i in range(n):
            if g[j][i] is not None:
                continue
            b = rng.randint(0, 1)
            p = (i, j)
            for k in range(4):
                g[p[1]][p[0]] = (b + k) % 2
                p = rot(*p)
    return g


def arcs_for(grid, cell):
    x0 = C - cell * len(grid) / 2
    return swatch_arcs(grid, x0, cell)


def reach(a, r):
    V, a0, a1 = a
    return max(math.hypot(V[0] + r * math.cos(math.radians(a0 + (a1 - a0) * t / 32)) - C,
                          V[1] + r * math.sin(math.radians(a0 + (a1 - a0) * t / 32)) - C) for t in range(33))


def outline(arcs, r, w, rho=None):
    """Filled outlines, one band per arc; fillets (stroke x 0.2174) only at free ends, joins overlap half a degree."""
    rho = w * 0.2174 if rho is None else rho
    key = lambda V, a: (round(V[0] + r * math.cos(math.radians(a)), 2), round(V[1] + r * math.sin(math.radians(a)), 2))
    count = {}
    for V, a0, a1 in arcs:
        for a in (a0, a1):
            count[key(V, a)] = count.get(key(V, a), 0) + 1
    d = ''
    for V, a0, a1 in arcs:
        f0, f1 = count[key(V, a0)] == 1, count[key(V, a1)] == 1
        d += band(V[0], V[1], r, w, a0 - (0 if f0 else 0.5), a1 + (0 if f1 else 0.5), rho, rho if f0 else 0, rho if f1 else 0)
    return d


def wheel(cell=128, limit=None, grid=None, center_ring=False):
    """Whole arcs within the inscribed circle of the swatch (the Wheel rule), without the center ring unless asked."""
    grid = grid or configs()[4]
    r = cell / 2
    limit = limit or cell * len(grid) / 2
    arcs = [a for a in arcs_for(grid, cell) if reach(a, r) <= limit - r / 4 + 0.5]
    if not center_ring:
        arcs = [a for a in arcs if reach(a, r) > r + 0.5]
    return arcs, r


def capsule(cx, cy, w, h):
    r = h / 2
    x0, x1, y0, y1 = cx - w / 2, cx + w / 2, cy - h / 2, cy + h / 2
    return (f'M{f(x0 + r)} {f(y0)}L{f(x1 - r)} {f(y0)}A{f(r)} {f(r)} 0 0 1 {f(x1 - r)} {f(y1)}'
            f'L{f(x0 + r)} {f(y1)}A{f(r)} {f(r)} 0 0 1 {f(x0 + r)} {f(y0)}Z')


annulus = lambda r0, r1: circle(C, C, r1) + circle(C, C, r0, cw=False)
disc = lambda r: circle(C, C, r)


# ---------- documents ----------

def L(name, d, light=INK, dark=WHITE, glass=False, rule='nonzero'):
    return dict(name=name, d=d, light=light, dark=dark, glass=glass, rule=rule)


def G(layers, glass=False, refract=0.15, shadow=0.15, trans=0.9):
    return dict(layers=layers, glass=glass, refract=refract, shadow=shadow, trans=trans)


def glass(name, d, light=gray(1, 0.08), dark=gray(1, 0.06), **kw):
    return G([L(name, d, light, dark, True)], glass=True, **kw)


def write(name, groups, scale=4 / 3, bg=(WHITE, INK), sizes=((512, 1, ''), (60, 3, '-180'))):
    out = f'{OUT}/{name}.icon'
    shutil.rmtree(out, ignore_errors=True); os.makedirs(f'{out}/Assets')
    gs = []
    for g in groups:
        ls = []
        for l in g['layers']:
            body = l['d'] if l['d'].startswith('<') else f'<path d="{l["d"]}" fill="#000" fill-rule="{l["rule"]}"/>'
            open(f"{out}/Assets/{l['name']}.svg", 'w').write(
                f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">{body}</svg>')
            ls.append({"name": l['name'], "image-name": f"{l['name']}.svg", "glass": l['glass'],
                       "fill-specializations": [{"value": {"solid": l['light']}}, {"appearance": "dark", "value": {"solid": l['dark']}},
                                                {"appearance": "tinted", "value": {"solid": WHITE}}],
                       "opacity-specializations": [{"value": 1}], "position": {"scale": scale, "translation-in-points": [0, 0]}})
        grp = {"layers": ls, "lighting": "individual"}
        if g['glass']:
            grp.update({"shadow": {"kind": "neutral", "opacity": g['shadow']}, "specular": True,
                        "translucency": {"enabled": True, "value": g['trans']}})
            if g['refract']:
                grp["refractivity"] = {"enabled": True, "depth": g['refract'], "strength": g['refract']}
        else:
            grp.update({"shadow": {"kind": "none", "opacity": 0}, "specular": False, "translucency": {"enabled": False, "value": 0}})
        gs.append(grp)
    json.dump({"fill-specializations": [{"value": {"solid": bg[0]}}, {"appearance": "dark", "value": {"solid": bg[1]}}],
               "groups": gs, "supported-platforms": {"squares": "shared"}}, open(f'{out}/icon.json', 'w'), indent=2)
    for r in ('Default', 'Dark'):
        for size, sc, tag in sizes:
            subprocess.run([IC, out, '--export-image', '--output-file', f'{OUT}/{name}-{r}{tag}.png', '--platform', 'iOS', '--rendition', r,
                            '--width', str(size), '--height', str(size), '--scale', str(sc)], capture_output=True)


# ---------- concepts ----------

def stroke(d, w):
    return f'<path d="{d}" fill="none" stroke="#000" stroke-width="{f(w)}" stroke-linecap="round" stroke-linejoin="round"/>'


def rays(R=224, hs=(56, 112, 168), x_out=C - 330, w=22):
    d = ''
    B = (C + R, C)
    for h in hs:
        for s in (1, -1):
            y = C + s * h
            x = C - math.sqrt(R * R - h * h)
            d += f'M{f(x_out)} {f(y)}L{f(x)} {f(y)}L{f(B[0])} {f(B[1])}'
    return stroke(d, w)


def nephroid(R, w):
    a = R / 4
    pts = [(C + a * (3 * math.cos(t) - math.cos(3 * t)), C + a * (3 * math.sin(t) - math.sin(3 * t)))
           for t in (2 * math.pi * k / 720 for k in range(721))]
    return stroke('M' + 'L'.join(f'{f(x)} {f(y)}' for x, y in pts), w)


WHEEL_ARCS, WR = wheel()
WHEEL = outline(WHEEL_ARCS, WR, 32)
RING = ring(C, C, 64, 32)
FIELD_GRID = c4_grid(8, seed=7, core=configs()[4])
FA, FR = wheel(cell=80, grid=FIELD_GRID)
FIELD = outline(FA, FR, 20)
FIELD_RINGLESS = outline([a for a in FA if reach(a, FR) > 2.5 * FR], FR, 20)

CONCEPTS = [
    ('01-waterline', 'Waterline', 'A glass bar across the Wheel: everything it covers is seen through glass.',
     [glass('bar', capsule(C, C, 600, 176), gray(1, 0.12), gray(1, 0.08), shadow=0.4), G([L('ring', RING)]), G([L('lines', WHEEL)])]),
    ('02-pencil', 'Pencil in water', 'One bold loop seen through a glass rod, the oldest refraction demo there is.',
     [glass('rod', capsule(C, C, 640, 208), gray(1, 0.12), gray(1, 0.08), shadow=0.4), G([L('loop', ring(C, C, 176, 72))])]),
    ('03-invisible', 'Invisible loop', 'The loop is only glass. You see it by how it bends the tiles under it.',
     [glass('loop', annulus(128, 288), gray(1, 0.1), gray(1, 0.06), shadow=0.4), G([L('field', FIELD)])]),
    ('04-lens-field', 'Lens on the field', 'A crystal over a fine field of tiles, the ring at its center.',
     [glass('lens', disc(224), shadow=0.3), G([L('ring', RING)]), G([L('field', FIELD_RINGLESS)])]),
    ('05-comes-back', 'It comes back', 'Light into a glass sphere returns to where it came from. Say something, hear it come back.',
     [glass('sphere', disc(224), gray(1, 0.12), gray(1, 0.08), shadow=0.4), G([L('rays', rays())])]),
    ('06-caustic', 'Coffee cup', 'Light inside a ring focuses into a caustic; the loop gathers what you say.',
     [glass('lens', disc(200), shadow=0.3), G([L('caustic', nephroid(232, 18))]), G([L('cup', ring(C, C, 232, 28))])]),
    ('07-lens-in-lens', 'Lens within lens', 'Two concentric crystals: the ring swells under the small one, the hooks fold under the large one.',
     [glass('bead', disc(101), shadow=0.3), glass('lens', disc(224), shadow=0.2), G([L('ring', RING)]), G([L('lines', WHEEL)])]),
    ('08-glass-ring', 'Glass ring', 'A glass loop around the ring; the arms bend at both of its edges.',
     [glass('band', annulus(101, 256), gray(1, 0.1), gray(1, 0.06), shadow=0.3), G([L('ring', RING)]), G([L('lines', WHEEL)])]),
]


def wall(items, name):
    for mode, bg, fg, sub in (('Default', '#e9e9eb', '#111', '#666'), ('Dark', '#151517', '#eee', '#999')):
        body = [f'<rect width="1800" height="1800" fill="{bg}"/>']
        for k, (key, title, note, _) in enumerate(items):
            x, y = 12 + (k % 4) * 447, 10 + (k // 4) * 895
            body.append(f'<text x="{x}" y="{y+22}" font-family="Helvetica Neue" font-size="18" font-weight="500" fill="{fg}">{key[:2]}  {title}</text>')
            body.append(f'<image href="{key}-{mode}.png" x="{x}" y="{y+36}" width="425" height="425"/>')
            body.append(f'<image href="{key}-{mode}-180.png" x="{x}" y="{y+480}" width="180" height="180"/>')
            body.append(f'<image href="{key}-{mode}-180.png" x="{x+200}" y="{y+480}" width="87" height="87"/>')
            body.append(f'<image href="{key}-{mode}-180.png" x="{x+200}" y="{y+585}" width="60" height="60"/>')
            body.append(f'<image href="{key}-{mode}-180.png" x="{x+275}" y="{y+585}" width="40" height="40"/>')
        open(f'{OUT}/{name}-{mode}.svg', 'w').write('<svg xmlns="http://www.w3.org/2000/svg" width="1800" height="1800" viewBox="0 0 1800 1800">' + ''.join(body) + '</svg>')
        subprocess.run(['qlmanage', '-t', '-s', '1800', '-o', OUT, f'{OUT}/{name}-{mode}.svg'], capture_output=True)


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for key, _, _, groups in CONCEPTS:
        write(key, groups)
    wall(CONCEPTS, 'icons')


# ---------- wordmarks in real glass ----------

GLYPHS = '/private/tmp/claude-501/-Users-nick-Library-CloudStorage-Dropbox-Developer-Xcode-Loop/3180a395-336a-4355-bca4-123c7e945a06/scratchpad/glyphs.out'


def word_layer():
    """Geist 650 'loop' scaled to 760 wide and centered on the 1024 canvas, plus the canvas centers of its two o's."""
    rows = {l.split('|')[0]: l.strip().split('|') for l in open(GLYPHS)}
    x0, y0, x1, y1 = map(float, rows['loop'][1].split())
    s = 760 / (x1 - x0)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    X = lambda x: C + (x - cx) * s
    Y = lambda y: C + (y - cy) * s
    ox0, oy0, ox1, oy1 = map(float, rows['o'][1].split())
    half = (ox1 - ox0) / 2
    o_r = (oy1 - oy0) / 2 * s
    o_y = Y((oy0 + oy1) / 2)
    os_ = [(X(float(rows[k][1].split()[2]) - half), o_y) for k in ('lo', 'loo')]
    body = f'<path transform="translate({f(C - cx * s)} {f(C - cy * s)}) scale({s:.5f})" d="{rows["loop"][2]}" fill="#000"/>'
    xh = (Y(0) + Y(oy0)) / 2
    return body, os_, o_r, dict(top=Y(y0), base=Y(0), bottom=Y(y1), xmid=xh, left=X(x0), right=X(x1))


def wordmarks():
    body, (o1, o2), o_r, m = word_layer()
    word = G([L('word', body)])
    bead = lambda c, r: circle(c[0], c[1], r)
    mid = ((o1[0] + o2[0]) / 2, o1[1])
    rod_h = (m['base'] - m['xmid']) * 2 * 0.5
    return [
        ('w0-plain', 'Geist 650', 'The shipped wordmark, for reference.', [word]),
        ('w1-beads', 'Glass o\'s', 'A bead concentric with each o; both loops swell at their rims.',
         [glass('beads', bead(o1, o_r * 1.2) + bead(o2, o_r * 1.2), shadow=0.3), word]),
        ('w2-echo', 'The echo', 'Only the second o is under glass: you say it, it comes back changed.',
         [glass('bead', bead(o2, o_r * 1.2), shadow=0.3), word]),
        ('w3-rod', 'The rod', 'The same glass rod as icon 02, through the x-height.',
         [glass('rod', capsule(C, m['xmid'], (m['right'] - m['left']) + 60, rod_h), gray(1, 0.12), gray(1, 0.08), shadow=0.35), word]),
        ('w4-waterline', 'Waterline', 'The word stands in glass from the middle of the x-height down.',
         [glass('water', capsule(C, (m['xmid'] + m['bottom'] + 24) / 2, (m['right'] - m['left']) + 80, m['bottom'] + 24 - m['xmid']),
                gray(1, 0.12), gray(1, 0.08), shadow=0.35), word]),
        ('w5-lens', 'One lens', 'One crystal over both o\'s, centered between them.',
         [glass('lens', bead(mid, (o2[0] - o1[0]) / 2 + o_r * 1.15), shadow=0.3), word]),
    ]


def wordmark_strips(items):
    for key, *_ in items:
        for r in ('Default', 'Dark'):
            src = f'{OUT}/{key}-{r}.png'
            subprocess.run(['sips', '--cropToHeightWidth', '440', '960', '--cropOffset', '292', '32', src, '--out', f'{OUT}/{key}-{r}-strip.png'], capture_output=True)
