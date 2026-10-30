"""Pitch wall: twelve ideas around the symmetric rings swatch, each with its own use of glass."""
import json, math, os, shutil, subprocess
from studio import M, C, f
from truchet import arc
from fields import IC

R = [[0, 1, 1], [1, 0, 1], [1, 1, 0]]
c = 3 * M; X0 = C - 1.5 * c
RINGS = [(X0 + c, X0 + c), (X0 + 2 * c, X0 + 2 * c)]
INK, WHITE = "extended-gray:0.04314,1.00000", "extended-gray:1.00000,1.00000"
gray = lambda v, a=1: f"extended-gray:{v:.5f},{a:.5f}"

def cell_arcs(grid, x0=X0, cc=c, rads=None):
    out = []
    for j, row in enumerate(grid):
        for i, o in enumerate(row):
            x, y = x0 + i * cc, x0 + j * cc
            cs = [((x, y), 0, 90), ((x + cc, y + cc), 180, 270)] if o == 0 else [((x + cc, y), 90, 180), ((x, y + cc), 270, 360)]
            for (vx, vy), a0, a1 in cs:
                for r in (rads or [cc / 2]):
                    out.append(((vx, vy), arc(vx, vy, r, a0, a1)))
    return out

def P(d, w, cap='butt', extra=''):
    return f'<path d="{d}" fill="none" stroke="#000" stroke-width="{f(w)}" stroke-linecap="{cap}" {extra}/>'

def svg(body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">{body}</svg>'

def L(name, body, glass=True, fill=None, dark=None, op=1, tinted=WHITE):
    return dict(name=name, body=body, glass=glass, fill=fill or INK, dark=dark or WHITE, op=op, tinted=tinted)

def G(layers, glass=True, shadow=0.5, trans=0.5, refract=None, blur=None, spec=True):
    return dict(layers=layers, glass=glass, shadow=shadow, trans=trans, refract=refract, blur=blur, spec=spec)

def write(name, groups, bg_light=WHITE, bg_dark=INK):
    out = f'pitch/{name}.icon'
    shutil.rmtree(out, ignore_errors=True); os.makedirs(f'{out}/Assets')
    gs = []
    for g in groups:
        ls = []
        for l in g['layers']:
            open(f"{out}/Assets/{l['name']}.svg", 'w').write(svg(l['body']))
            fl = l['fill'] if isinstance(l['fill'], dict) else {"solid": l['fill']}
            fd = l['dark'] if isinstance(l['dark'], dict) else {"solid": l['dark']}
            ls.append({"name": l['name'], "image-name": f"{l['name']}.svg", "glass": l['glass'],
                       "fill-specializations": [{"value": fl}, {"appearance": "dark", "value": fd}, {"appearance": "tinted", "value": {"solid": l['tinted']}}],
                       "opacity-specializations": [{"value": l['op']}], "position": {"scale": 1, "translation-in-points": [0, 0]}})
        grp = {"layers": ls, "lighting": "individual",
               "shadow": {"kind": "neutral", "opacity": g['shadow']} if g['shadow'] else {"kind": "none", "opacity": 0},
               "specular": g['spec'], "translucency": {"enabled": bool(g['trans']), "value": g['trans'] or 0}}
        if g['refract']: grp["refractivity"] = {"enabled": True, "depth": g['refract'][0], "strength": g['refract'][1]}
        if g['blur'] is not None: grp["blur-material"] = g['blur']
        gs.append(grp)
    json.dump({"fill-specializations": [{"value": {"solid": bg_light}}, {"appearance": "dark", "value": {"solid": bg_dark}}],
               "groups": gs, "supported-platforms": {"squares": "shared"}}, open(f'{out}/icon.json', 'w'), indent=2)
    for r in ('Default', 'Dark'):
        subprocess.run([IC, out, '--export-image', '--output-file', f'pitch/{name}-{r}.png', '--platform', 'iOS', '--rendition', r, '--width', '1024', '--height', '1024', '--scale', '1'], capture_output=True)
        subprocess.run([IC, out, '--export-image', '--output-file', f'pitch/{name}-{r}-87.png', '--platform', 'iOS', '--rendition', r, '--width', '29', '--height', '29', '--scale', '3'], capture_output=True)

os.makedirs('pitch', exist_ok=True)
arcs = cell_arcs(R)
ALL = ''.join(d for _, d in arcs)
RING = ''.join(d for v, d in arcs if v in RINGS)
THREAD = ''.join(d for v, d in arcs if v not in RINGS)
W = 32

ideas = []
def idea(key, title, pitch, groups, **kw):
    write(key, groups, **kw); ideas.append((key, title, pitch))

# 01 control
idea('01-two', 'Two', 'The control. Two rings, the conversation around them, plain glass.',
     [G([L('mark', P(ALL, W))])])

# 02 lenses: two glass discs refracting the threads behind them
discs = ''.join(f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(c/2 + W/2)}" fill="#000"/>' for x, y in RINGS)
idea('02-lenses', 'Lenses', 'Each person is a lens. The conversation bends as it passes through them.',
     [G([L('lens', discs, fill=gray(1, 0.18), dark=gray(1, 0.14))], shadow=0.35, trans=0.9, refract=(0.9, 0.9)),
      G([L('threads', P(ALL, W), glass=False)], glass=False, shadow=0, trans=0, spec=False)])

# 03 lifted: rings float above, threads stay on the ground
idea('03-lifted', 'Lifted', 'The people float. The conversation stays on the ground. Tilt the phone and they part.',
     [G([L('rings', P(RING, W))], shadow=0.7),
      G([L('threads', P(THREAD, W), op=0.35)], shadow=0, trans=0.6)])

# 04 inlay: a slab, the lines inlaid in the opposite ink
slab = f'<rect x="{f(X0-48)}" y="{f(X0-48)}" width="{f(3*c+96)}" height="{f(3*c+96)}" rx="72" fill="#000"/>'
idea('04-inlay', 'Inlay', 'A single tile of black glass with the lines inlaid in white. An object you could hold.',
     [G([L('lines', P(ALL, W), glass=False, fill=WHITE, dark=INK)], glass=False, shadow=0, trans=0, spec=False),
      G([L('slab', slab, fill=INK, dark=WHITE)], shadow=0.6, trans=0.2)])

# 05 the turn: nine tiles, the center one caught mid-turn
gap, rx = 10, 22
def tile_rect(i, j): return f'<rect x="{f(X0+i*c+gap/2)}" y="{f(X0+j*c+gap/2)}" width="{f(c-gap)}" height="{f(c-gap)}" rx="{rx}" fill="#000"/>'
stat = [(i, j) for j in range(3) for i in range(3) if (i, j) != (1, 1)]
tiles = ''.join(tile_rect(i, j) for i, j in stat)
lines = ''.join(d for (v, d), k in zip(arcs, range(len(arcs))) if (k // 2) % 9 != 4)
centre_arcs = ''.join(d for k, (v, d) in enumerate(arcs) if k // 2 == 4)
rot = f'transform="rotate(-24 {C} {C})"'
idea('05-turn', 'The turn', 'Loop is one tile, turning. The icon catches it halfway, so the loop is about to close.',
     [G([L('turn-lines', f'<g {rot}>{P(centre_arcs, W)}</g>', glass=False, fill=WHITE, dark=INK)], glass=False, shadow=0, trans=0, spec=False),
      G([L('turn-tile', f'<g {rot}>{tile_rect(1, 1)}</g>', fill=INK, dark=WHITE)], shadow=0.8, trans=0.15),
      G([L('lines', P(lines, W), glass=False, fill=WHITE, dark=INK)], glass=False, shadow=0, trans=0, spec=False),
      G([L('tiles', tiles, fill=INK, dark=WHITE, op=1)], shadow=0.3, trans=0.15)])

# 06 op art: three strands
ALL3 = ''.join(d for _, d in cell_arcs(R, rads=[c/2 - 24, c/2, c/2 + 24]))
idea('06-op', 'Op art', 'Three strands per line. Vasarely, cut to the size of a thumbnail.',
     [G([L('mark', P(ALL3, 12))])])

# 07 two-tone: the regions, not the lines
def regions(grid):
    d = []
    for j, row in enumerate(grid):
        for i, o in enumerate(row):
            x, y = X0 + i * c, X0 + j * c
            corners = [(x, y, 0), (x + c, y + c, 180)] if o == 0 else [(x + c, y, 90), (x, y + c, 270)]
            vx0 = corners[0][0]; vy0 = corners[0][1]
            parity = int(round((vx0 - X0) / c + (vy0 - X0) / c)) % 2
            pies = ''
            for vx, vy, a0 in corners:
                a, b = math.radians(a0), math.radians(a0 + 90)
                pies += f'M{f(vx)} {f(vy)}L{f(vx + c/2*math.cos(a))} {f(vy + c/2*math.sin(a))}A{f(c/2)} {f(c/2)} 0 0 1 {f(vx + c/2*math.cos(b))} {f(vy + c/2*math.sin(b))}Z'
            if parity == 0:
                d.append(f'<path d="{pies}" fill="#000"/>')
            else:
                d.append(f'<path d="M{f(x)} {f(y)}h{f(c)}v{f(c)}h{f(-c)}Z{pies}" fill="#000" fill-rule="evenodd"/>')
    return ''.join(d)
idea('07-twotone', 'Two-tone', 'Stop drawing lines. Every curve becomes the border between two sides.',
     [G([L('regions', regions(R))])])

# 08 porthole: a round window onto the endless pattern, with a dial's rim
big = [[R[j % 3][i % 3] for i in range(5)] for j in range(5)]
bx0 = C - 2.5 * c
port = ''.join(d for _, d in cell_arcs(big, x0=bx0))
clip = f'<defs><clipPath id="p"><circle cx="{C}" cy="{C}" r="300"/></clipPath></defs>'
idea('08-porthole', 'Porthole', 'An instrument. A round window onto a pattern that never ends.',
     [G([L('rim', f'<circle cx="{C}" cy="{C}" r="316" fill="none" stroke="#000" stroke-width="12"/>')], shadow=0.4),
      G([L('field', clip + f'<g clip-path="url(#p)">{P(port, W)}</g>')], shadow=0.3)])

# 09 crop marks: show the construction
cm = ''
a, b, k = X0 - 40, X0 + 3 * c + 40, 28
for (px, py, sx, sy) in [(X0, X0, -1, -1), (X0 + 3*c, X0, 1, -1), (X0, X0 + 3*c, -1, 1), (X0 + 3*c, X0 + 3*c, 1, 1)]:
    cm += f'M{f(px)} {f(py + sy*16)}v{f(sy*k)}M{f(px + sx*16)} {f(py)}h{f(sx*k)}'
for t in range(1, 3):
    cm += f'M{f(X0 + t*c)} {f(X0 - 16)}v-14M{f(X0 + t*c)} {f(X0 + 3*c + 16)}v14M{f(X0 - 16)} {f(X0 + t*c)}h-14M{f(X0 + 3*c + 16)} {f(X0 + t*c)}h14'
idea('09-cropmarks', 'Crop marks', 'Show the construction. The ruler marks are part of the mark, like a proof sheet.',
     [G([L('mark', P(ALL, W))]),
      G([L('marks', P(cm, 6), glass=False, op=0.55)], glass=False, shadow=0, trans=0, spec=False)])

# 10 thick and thin
idea('10-hierarchy', 'Hierarchy', 'The people in bold, the conversation in fine line. Read it in one glance.',
     [G([L('rings', P(RING, 56))], shadow=0.6),
      G([L('threads', P(THREAD, 12), glass=False, op=0.8)], glass=False, shadow=0, trans=0, spec=False)])

# 11 diamond
rot45 = f'transform="rotate(45 {C} {C}) translate({C} {C}) scale(0.78) translate({-C} {-C})"'
idea('11-diamond', 'Diamond', 'Turn the whole tile 45°. It stops being a grid and becomes a jewel.',
     [G([L('mark', f'<g {rot45}>{P(ALL, W/0.78)}</g>')])])

# 12 smoke: monochrome gradient glass
grad_l = {"linear-gradient": [INK, gray(0.04314, 0.25)], "orientation": {"start": {"x": 0.5, "y": 0}, "stop": {"x": 0.5, "y": 1}}}
grad_d = {"linear-gradient": [WHITE, gray(1, 0.2)], "orientation": {"start": {"x": 0.5, "y": 0}, "stop": {"x": 0.5, "y": 1}}}
idea('12-smoke', 'Smoke', 'Ink at the top, air at the bottom. The loop fades out the way a conversation does.',
     [G([L('mark', P(ALL, W), fill=grad_l, dark=grad_d)], trans=0.7)])

json.dump(ideas, open('pitch/ideas.json', 'w'), indent=1)
print(len(ideas), 'ideas')
