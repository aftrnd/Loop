"""Round sixteen: other marks in the same vein.

1. The Wheel rule (whole arcs inside the swatch's inscribed circle) on each of the 8 symmetric 4 x 4 arrangements.
2. Closed loops only: from every symmetric 4 x 4 and 6 x 6 arrangement, keep just the strokes that close, so no line has an end.
"""
import itertools, math, subprocess
from c4 import configs
from round15 import arcs_for, reach, outline, C

OUT = '../round16'


def c4_grids(n):
    """Every n x n orientation grid with 90 degree rotational symmetry and a ring at the center corner."""
    rot = lambda i, j: (n - 1 - j, i)
    h = n // 2
    center = [(h - 1, h - 1), (h, h - 1), (h, h), (h - 1, h)]
    orbits, seen = [], set(center)
    for j in range(n):
        for i in range(n):
            if (i, j) in seen:
                continue
            orb, p = [], (i, j)
            for _ in range(4):
                orb.append(p); seen.add(p); p = rot(*p)
            orbits.append(orb)
    for bits in itertools.product([0, 1], repeat=len(orbits)):
        g = [[None] * n for _ in range(n)]
        for k, (i, j) in enumerate(center):
            g[j][i] = k % 2
        for b, orb in zip(bits, orbits):
            for k, (i, j) in enumerate(orb):
                g[j][i] = (b + k) % 2
        yield g


def components(arcs, r):
    key = lambda V, a: (round(V[0] + r * math.cos(math.radians(a)), 2), round(V[1] + r * math.sin(math.radians(a)), 2))
    ends = {}
    for k, (V, a0, a1) in enumerate(arcs):
        for a in (a0, a1):
            ends.setdefault(key(V, a), []).append(k)
    seen, comps = set(), []
    for k in range(len(arcs)):
        if k in seen:
            continue
        stack, comp = [k], []
        while stack:
            u = stack.pop()
            if u in seen:
                continue
            seen.add(u); comp.append(u)
            V, a0, a1 = arcs[u]
            for a in (a0, a1):
                stack += ends[key(V, a)]
        closed = all(len(ends[key(arcs[u][0], a)]) == 2 for u in comp for a in arcs[u][1:])
        comps.append((comp, closed))
    return comps


def closed_only(grid, cell=128):
    arcs = arcs_for(grid, cell)
    r = cell / 2
    keep = [arcs[u] for comp, closed in components(arcs, r) if closed for u in comp]
    return keep, r


def wheel_cut(grid, cell=128):
    r = cell / 2
    lim = cell * len(grid) / 2 - r / 4 + 0.5
    return [a for a in arcs_for(grid, cell) if reach(a, r) <= lim], r


def signature(arcs):
    return tuple(sorted((round(V[0]), round(V[1]), a0) for V, a0, a1 in arcs))


def flat_svg(arcs, r, w, span):
    d = outline(arcs, r, w)
    v = C - span / 2
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{v} {v} {span} {span}"><path d="{d}" fill="#0b0b0b"/></svg>', d


if __name__ == '__main__':
    import os, json
    os.makedirs(OUT, exist_ok=True)
    marks = []
    for k, g in enumerate(configs()):
        arcs, r = wheel_cut(g)
        marks.append((f'wheel-c4-{k}', arcs, r, 128 * 4))
    sigs = set()
    for n, cell in ((4, 128), (6, 96)):
        for g in c4_grids(n):
            arcs, r = closed_only(g, cell)
            if len(arcs) <= 4:
                continue
            s = signature(arcs)
            if s in sigs:
                continue
            sigs.add(s)
            marks.append((f'closed-{n}-{len(sigs)}', arcs, r, cell * n))
    print(len(marks), 'marks')
    json.dump([(name, len(a)) for name, a, r, s in marks], open(f'{OUT}/marks.json', 'w'))
    cols, cw = 8, 222
    rows = math.ceil(len(marks) / cols)
    H = rows * 250 + 10
    body = [f'<rect width="1800" height="{H}" fill="#fff"/>']
    for k, (name, arcs, r, span) in enumerate(marks):
        x, y = 10 + (k % cols) * cw, 10 + (k // cols) * 250
        d = outline(arcs, r, r / 2)
        v = C - span / 2
        body.append(f'<svg x="{x}" y="{y}" width="200" height="200" viewBox="{v} {v} {span} {span}"><path d="{d}" fill="#0b0b0b"/></svg>')
        body.append(f'<svg x="{x + 150}" y="{y + 205}" width="32" height="32" viewBox="{v} {v} {span} {span}"><path d="{d}" fill="#0b0b0b"/></svg>')
        body.append(f'<text x="{x}" y="{y + 228}" font-family="Helvetica Neue" font-size="13" fill="#555">{k:02d} {name} ({len(arcs)})</text>')
    open(f'{OUT}/shapes.svg', 'w').write(f'<svg xmlns="http://www.w3.org/2000/svg" width="1800" height="{H}" viewBox="0 0 1800 {H}">' + ''.join(body) + '</svg>')
    subprocess.run(['qlmanage', '-t', '-s', str(max(1800, H)), '-o', OUT, f'{OUT}/shapes.svg'], capture_output=True)
