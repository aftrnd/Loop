"""Single Truchet loops: the boundary of the region around a set S of same-parity grid vertices,
built only from quarter arcs of radius c/2."""
import math
from studio import *

def region_arcs(S, c):
    """Return list of (cx, cy, a0, a1) quarter arcs in grid units (vertex coords), y down."""
    S = set(S)
    xs = [v[0] for v in S]; ys = [v[1] for v in S]
    arcs = []
    for i in range(min(xs) - 1, max(xs) + 1):
        for j in range(min(ys) - 1, max(ys) + 1):
            TL, TR, BL, BR = (i, j), (i + 1, j), (i, j + 1), (i + 1, j + 1)
            ins = [v for v in (TL, TR, BL, BR) if v in S]
            # quarter of each corner inside this cell, as screen angles from that corner
            quad = {TL: (0, 90), TR: (90, 180), BR: (180, 270), BL: (270, 360)}
            if len(ins) == 1:
                v = ins[0]; arcs.append((v, quad[v]))
            elif len(ins) == 2:
                if set(ins) == {TL, BR}:
                    arcs += [(TR, quad[TR]), (BL, quad[BL])]
                else:
                    arcs += [(TL, quad[TL]), (BR, quad[BR])]
    return arcs

def loop_path(S, c, ox, oy):
    # chain arcs into one closed path
    arcs = region_arcs(S, c)
    def ends(a):
        (vx, vy), (a0, a1) = a
        p = lambda ang: (round(vx + 0.5 * math.cos(math.radians(ang)), 6), round(vy + 0.5 * math.sin(math.radians(ang)), 6))
        return p(a0), p(a1)
    segs = [(a, *ends(a)) for a in arcs]
    path = [segs.pop(0)]
    cur = path[0][2]
    rev = [False]
    while segs:
        for k, (a, p0, p1) in enumerate(segs):
            if p0 == cur:
                path.append((a, p0, p1)); rev.append(False); cur = p1; segs.pop(k); break
            if p1 == cur:
                path.append((a, p1, p0)); rev.append(True); cur = p0; segs.pop(k); break
        else:
            raise ValueError('open chain')
    X = lambda p: ox + p[0] * c
    Y = lambda p: oy + p[1] * c
    r = c / 2
    d = f'M{f(X(path[0][1]))} {f(Y(path[0][1]))}'
    for (a, p0, p1), rv in zip(path, rev):
        d += f'A{f(r)} {f(r)} 0 0 {0 if rv else 1} {f(X(p1))} {f(Y(p1))}'
    return d + 'Z'

def tloop(S, c=None, span=640, s=M, filled=False):
    xs = [v[0] for v in S]; ys = [v[1] for v in S]
    w = max(xs) - min(xs) + 1; h = max(ys) - min(ys) + 1
    if c is None: c = span / max(w, h)
    ox = C - (min(xs) - 0.5 + w / 2) * c
    oy = C - (min(ys) - 0.5 + h / 2) * c
    d = loop_path(S, c, ox, oy)
    if filled: return lambda ink, g: fill(d, ink)
    return lambda ink, g: stroke(d, s, ink)

if __name__ == '__main__':
    peanut = [(0, 0), (1, 1)]
    boomer = [(0, 0), (1, 1), (2, 0)]
    chevron = [(0, 0), (1, 1), (0, 2)]
    zig = [(0, 0), (1, 1), (2, 0), (3, 1)]
    sheet([
        ('peanut fill', tloop(peanut, filled=True)),
        ('peanut', tloop(peanut)),
        ('boomerang fill', tloop(boomer, filled=True)),
        ('boomerang', tloop(boomer)),
    ], 'sheet7.svg')
    sheet([
        ('boomerang c=3m', tloop(boomer, c=3*M)),
        ('chevron', tloop(chevron)),
        ('zigzag fill', tloop(zig, filled=True)),
        ('zigzag', tloop(zig, s=48)),
    ], 'sheet8.svg')
