import math
from studio import *

def arc(cx, cy, r, a0, a1):
    """screen-space arc from angle a0 to a1 (degrees, y down), sweep positive"""
    x0, y0 = cx + r*math.cos(math.radians(a0)), cy + r*math.sin(math.radians(a0))
    x1, y1 = cx + r*math.cos(math.radians(a1)), cy + r*math.sin(math.radians(a1))
    large = 1 if (a1 - a0) % 360 > 180 else 0
    sweep = 1 if a1 > a0 else 0
    return f'M{f(x0)} {f(y0)}A{f(r)} {f(r)} 0 {large} {sweep} {f(x1)} {f(y1)}'

def tiles(grid, x0, y0, c, s):
    """grid: rows of 0/1. 0 = arcs around top-left and bottom-right corners, 1 = top-right and bottom-left."""
    d = []
    for j, row in enumerate(grid):
        for i, t in enumerate(row):
            x, y = x0 + i*c, y0 + j*c
            if t == 0:
                d.append(arc(x, y, c/2, 0, 90)); d.append(arc(x+c, y+c, c/2, 180, 270))
            else:
                d.append(arc(x+c, y, c/2, 90, 180)); d.append(arc(x, y+c, c/2, 270, 360))
    return ''.join(d)

def truchet(grid, span=640, s=M, clip=True):
    n = len(grid); c = span / n; x0 = C - span/2
    d = tiles(grid, x0, x0, c, s)
    def draw(ink, g):
        cp = f'<clipPath id="cl{abs(hash(str(grid)))%9999}"><rect x="{f(x0)}" y="{f(x0)}" width="{f(span)}" height="{f(span)}"/></clipPath>'
        return cp + (f'<g clip-path="url(#cl{abs(hash(str(grid)))%9999})">' if clip else '<g>') + stroke(d, s, ink) + '</g>'
    return draw

def bleed(grid, s=M):
    n = len(grid); c = 1024 / n
    d = tiles(grid, 0, 0, c, s)
    return lambda ink, g: stroke(d, s, ink)

sheet([
    ('one tile, full bleed', bleed([[0]])),
    ('one tile, live area', truchet([[0]])),
    ('2x2 ring', truchet([[1,0],[0,1]])),
    ('2x2 wave', truchet([[0,0],[0,0]])),
], 'sheet5.svg')
sheet([
    ('3x3 a', truchet([[1,0,1],[0,1,0],[1,0,1]], s=48)),
    ('3x3 b', truchet([[0,1,0],[1,1,0],[0,0,1]], s=48)),
    ('2x2 bleed ring', bleed([[1,0],[0,1]])),
    ('4x4 bleed', bleed([[1,0,1,0],[0,1,1,1],[1,0,1,0],[0,0,0,1]], s=40)),
], 'sheet6.svg')
