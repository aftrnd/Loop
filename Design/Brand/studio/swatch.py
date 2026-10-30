"""Contained Truchet swatches: an n x n cut from the endless pattern, flat ends at the square."""
import itertools, math
from studio import *
from truchet import arc

def cell_arcs(o, x, y, c, r):
    if o == 0:
        return [(x, y, r, 0, 90), (x + c, y + c, r, 180, 270)]
    return [(x + c, y, r, 90, 180), (x, y + c, r, 270, 360)]

def swatch(grid, span=576, w=48, strands=1, gap=None):
    n = len(grid); c = span / n; x0 = C - span / 2
    d = []
    for j, row in enumerate(grid):
        for i, o in enumerate(row):
            if strands == 1:
                rs = [c / 2]
            else:
                g = gap if gap is not None else w
                rs = [c / 2 + (k - (strands - 1) / 2) * (w + g) for k in range(strands)]
            for r in rs:
                for (cx, cy, _, a0, a1) in cell_arcs(o, x0 + i * c, x0 + j * c, c, r):
                    d.append(arc(cx, cy, r, a0, a1))
    d = ''.join(d)
    return lambda ink, g: f'<path d="{d}" fill="none" stroke="{ink}" stroke-width="{f(w)}" stroke-linecap="butt"/>'

def cycles(grid):
    """count closed loops inside the swatch"""
    n = len(grid)
    adj = {}
    def mid(kind, i, j): return (kind, i, j)  # 'v' edge left of cell i in row j; 'h' edge above cell i in col
    for j, row in enumerate(grid):
        for i, o in enumerate(row):
            T, B, L, R = ('h', i, j), ('h', i, j + 1), ('v', i, j), ('v', i + 1, j)
            pairs = [(T, L), (B, R)] if o == 0 else [(T, R), (B, L)]
            for a, b in pairs:
                adj.setdefault(a, []).append(b); adj.setdefault(b, []).append(a)
    seen = set(); loops = []
    for s in adj:
        if s in seen: continue
        comp = []; stack = [s]
        while stack:
            u = stack.pop()
            if u in seen: continue
            seen.add(u); comp.append(u); stack += adj[u]
        if all(len(adj[u]) == 2 for u in comp): loops.append(len(comp))
    return loops

if __name__ == '__main__':
    found = []
    for bits in itertools.product([0, 1], repeat=9):
        g = [list(bits[0:3]), list(bits[3:6]), list(bits[6:9])]
        c2 = all(g[j][i] == g[2 - j][2 - i] for j in range(3) for i in range(3))
        diag = all(g[j][i] == g[i][j] for j in range(3) for i in range(3))
        anti = all(g[j][i] == g[2 - i][2 - j] for j in range(3) for i in range(3))
        L = cycles(g)
        found.append((g, c2, diag, anti, L))
    for g, c2, dg, an, L in found:
        if c2 and (dg or an):
            print(g, 'c2', 'diag' if dg else '', 'anti' if an else '', 'loops', L)
