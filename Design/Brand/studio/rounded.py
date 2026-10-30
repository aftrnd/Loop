"""Line outlines for a Truchet swatch with flat ends whose two corners are filleted exactly
(tangent to the flat cut and to the concentric side arc). Rings stay plain annuli."""
import math
from kit import f, C

def swatch_arcs(grid, x0, c):
    out = []
    for j, row in enumerate(grid):
        for i, o in enumerate(row):
            x, y = x0 + i * c, x0 + j * c
            cs = [((x, y), 0, 90), ((x + c, y + c), 180, 270)] if o == 0 else [((x + c, y), 90, 180), ((x, y + c), 270, 360)]
            out += cs
    return out

def outlines(grid, x0, c, w, rho, center=(C, C)):
    r = c / 2; d = w / 2; span = c * len(grid)
    arcs = swatch_arcs(grid, x0, c)
    P = lambda V, a, R=r: (V[0] + R * math.cos(math.radians(a)), V[1] + R * math.sin(math.radians(a)))
    key = lambda p: (round(p[0], 3), round(p[1], 3))
    ends = {}
    for k, (V, a0, a1) in enumerate(arcs):
        for a in (a0, a1):
            ends.setdefault(key(P(V, a)), []).append(k)
    on_edge = lambda p: min(abs(p[0] - x0), abs(p[0] - x0 - span), abs(p[1] - x0), abs(p[1] - x0 - span)) < 1e-6
    used = set(); chains = []; rings = []
    for k, (V, a0, a1) in enumerate(arcs):
        if k in used: continue
        # walk to one end of this chain
        start_k, start_a = k, a0
        chain = []
        # find a boundary end by walking backwards
        cur_k, cur_a = k, a0
        seen = {k}
        while True:
            p = key(P(arcs[cur_k][0], cur_a))
            nxt = [m for m in ends[p] if m != cur_k]
            if not nxt or nxt[0] in seen: break
            m = nxt[0]; seen.add(m)
            Vm, b0, b1 = arcs[m]
            cur_a = b1 if key(P(Vm, b0)) == p else b0
            cur_k = m
        closed = nxt and nxt[0] == k and len(seen) > 1 or (nxt and nxt[0] in seen and not on_edge(P(arcs[cur_k][0], cur_a)))
        # walk forward from (cur_k, cur_a) collecting (V, a_from, a_to)
        walk = []; wk, wa = cur_k, cur_a
        visited = set()
        while wk not in visited:
            visited.add(wk)
            V, b0, b1 = arcs[wk]
            frm = wa; to = b1 if wa == b0 else b0
            walk.append((V, frm, to))
            p = key(P(V, to))
            nxt = [m for m in ends[p] if m != wk]
            if not nxt: break
            m = nxt[0]; Vm, c0, c1 = arcs[m]
            wa = c0 if key(P(Vm, c0)) == p else c1
            wk = m
        used |= visited
        if on_edge(P(walk[0][0], walk[0][1])) and on_edge(P(walk[-1][0], walk[-1][2])):
            chains.append(walk)
        else:
            rings.append(walk)
    paths = []
    def arc_cmd(R, sweep, to):
        return f'A{f(R)} {f(R)} 0 0 {sweep} {f(to[0])} {f(to[1])}'
    def fillet(V, E, R, outer):
        """fillet between the circle (V, R) and the boundary line through E; returns (tangent on circle, center, tangent on line)"""
        ux, uy = (E[0] - V[0]) / r, (E[1] - V[1]) / r
        nx, ny = -uy, ux
        if (center[0] - E[0]) * nx + (center[1] - E[1]) * ny < 0: nx, ny = -nx, -ny
        x = math.sqrt((R - rho) ** 2 - rho ** 2) if outer else math.sqrt((R + rho) ** 2 - rho ** 2)
        Cc = (V[0] + x * ux + rho * nx, V[1] + x * uy + rho * ny)
        dist = (R - rho) if outer else (R + rho)
        Tc = (V[0] + (Cc[0] - V[0]) * R / dist, V[1] + (Cc[1] - V[1]) * R / dist)
        Tl = (V[0] + x * ux, V[1] + x * uy)
        return Tc, Cc, Tl
    def fsweep(Cc, s, e):
        return 1 if (s[0] - Cc[0]) * (e[1] - Cc[1]) - (s[1] - Cc[1]) * (e[0] - Cc[0]) > 0 else 0
    for walk in chains:
        sw = [1 if ((to - frm) % 360) == 90 else 0 for V, frm, to in walk]
        RA = [r - d if s else r + d for s in sw]; RB = [r + d if s else r - d for s in sw]
        V0, a0s, _ = walk[0]; Vn, _, anE = walk[-1]
        E0 = P(V0, a0s); En = P(Vn, anE)
        fA0 = fillet(V0, E0, RA[0], RA[0] > r); fB0 = fillet(V0, E0, RB[0], RB[0] > r)
        fAn = fillet(Vn, En, RA[-1], RA[-1] > r); fBn = fillet(Vn, En, RB[-1], RB[-1] > r)
        dd = f'M{f(fA0[0][0])} {f(fA0[0][1])}'
        for i, (V, frm, to) in enumerate(walk):
            end = fAn[0] if i == len(walk) - 1 else P(V, to, RA[i])
            dd += arc_cmd(RA[i], sw[i], end)
        dd += f'A{f(rho)} {f(rho)} 0 0 {fsweep(fAn[1], fAn[0], fAn[2])} {f(fAn[2][0])} {f(fAn[2][1])}'
        dd += f'L{f(fBn[2][0])} {f(fBn[2][1])}'
        dd += f'A{f(rho)} {f(rho)} 0 0 {fsweep(fBn[1], fBn[2], fBn[0])} {f(fBn[0][0])} {f(fBn[0][1])}'
        for i in range(len(walk) - 1, -1, -1):
            V, frm, to = walk[i]
            end = fB0[0] if i == 0 else P(V, frm, RB[i])
            dd += arc_cmd(RB[i], 1 - sw[i], end)
        dd += f'A{f(rho)} {f(rho)} 0 0 {fsweep(fB0[1], fB0[0], fB0[2])} {f(fB0[2][0])} {f(fB0[2][1])}'
        dd += f'L{f(fA0[2][0])} {f(fA0[2][1])}'
        dd += f'A{f(rho)} {f(rho)} 0 0 {fsweep(fA0[1], fA0[2], fA0[0])} {f(fA0[0][0])} {f(fA0[0][1])}Z'
        paths.append(dd)
    ring_d = []
    for walk in rings:
        V = walk[0][0]
        if all(w[0] == V for w in walk):
            for R in (r + d, r - d):
                ring_d.append(f'M{f(V[0]-R)} {f(V[1])}a{f(R)} {f(R)} 0 1 0 {f(2*R)} 0a{f(R)} {f(R)} 0 1 0 {f(-2*R)} 0Z')
    return paths, ring_d

if __name__ == '__main__':
    from c4 import configs
    from kit import M
    g = configs()[4]; cc = 2 * M; x0 = C - 2 * cc
    p, rd = outlines(g, x0, cc, cc / 4, 32 * 0.2174)
    print(len(p), 'open lines', len(rd) // 2, 'rings')
    rho = 32 * 0.2174
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024"><rect width="1024" height="1024" fill="#fff"/><path d="{"".join(p)}" fill="#0b0b0b"/><path d="{"".join(rd)}" fill="#e85a10" fill-rule="evenodd"/></svg>'
    open('rounded-check.svg', 'w').write(svg)
    # zoom on one end, the top edge
    z = svg.replace('viewBox="0 0 1024 1024"', f'viewBox="{x0+20} {x0-12} 120 120"')
    open('rounded-zoom.svg', 'w').write(z)
