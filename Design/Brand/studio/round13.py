"""Round thirteen: a round silhouette. Keep only the whole Truchet arcs within a circle concentric with the ring.

The c4-4 arcs fall in distance bands from the center (centerline maxima 64, 143.1, 192, 230.8, 263.9, 320),
so each cut is a set of complete arcs whose ends are tile-edge cuts, as in the square swatch.
"""
import math, subprocess
from c4 import configs
from rounded import swatch_arcs
from kit import M, C, f

g = configs()[4]; CC = 2 * M; X0 = C - 2 * CC; R = CC / 2; W = CC / 4
ARCS = swatch_arcs(g, X0, CC)

def reach(a):
    V, a0, a1 = a
    return max(math.hypot(V[0] + R * math.cos(math.radians(a0 + (a1 - a0) * t / 32)) - C,
                          V[1] + R * math.sin(math.radians(a0 + (a1 - a0) * t / 32)) - C) for t in range(33))

def arcs_within(limit):
    return [a for a in ARCS if reach(a) <= limit + 0.5]

def arc_d(a):
    V, a0, a1 = a
    p = lambda t: (V[0] + R * math.cos(math.radians(t)), V[1] + R * math.sin(math.radians(t)))
    s, e = p(a0), p(a1)
    return f'M{f(s[0])} {f(s[1])}A{f(R)} {f(R)} 0 0 1 {f(e[0])} {f(e[1])}'

def mark(limit, ink):
    return f'<path d="{"".join(arc_d(a) for a in arcs_within(limit))}" fill="none" stroke="{ink}" stroke-width="{f(W)}" stroke-linecap="butt"/>'

CUTS = [(143.1, 'Arms'), (192, 'Pinwheel'), (230.8, 'Wheel'), (263.9, 'Full round'), (320, 'Square (now)')]

if __name__ == '__main__':
    body = ['<rect width="1800" height="1800" fill="#e9e9eb"/><rect y="900" width="1800" height="900" fill="#151517"/>']
    for half, ink, card, fg in ((0, '#0b0b0b', '#fff', '#111'), (1, '#fff', '#0b0b0b', '#eee')):
        for k, (lim, name) in enumerate(CUTS):
            x, y = 12 + k * 357, half * 900 + 12
            n = len(arcs_within(lim))
            body.append(f'<rect x="{x}" y="{y}" width="345" height="876" rx="16" fill="{card}"/>')
            body.append(f'<text x="{x+18}" y="{y+34}" font-family="Helvetica Neue" font-size="19" font-weight="500" fill="{fg}">{name}</text>')
            body.append(f'<text x="{x+18}" y="{y+58}" font-family="Helvetica Neue" font-size="14" fill="#888">{n} arcs, reach {lim + W / 2:g}</text>')
            # large: the 640 x 640 window around the center scaled to 300
            body.append(f'<svg x="{x+22}" y="{y+80}" width="300" height="300" viewBox="192 192 640 640">{mark(lim, ink)}</svg>')
            for s, yy in ((96, 420), (48, 540), (32, 610), (20, 665), (16, 705)):
                body.append(f'<svg x="{x+22}" y="{y+yy}" width="{s}" height="{s}" viewBox="192 192 640 640">{mark(lim, ink)}</svg>')
                body.append(f'<svg x="{x+140}" y="{y+yy}" width="{s}" height="{s}" viewBox="192 192 640 640"><rect x="192" y="192" width="640" height="640" rx="143" fill="{ink}"/>{mark(lim, card)}</svg>')
    open('../round13/cuts.svg', 'w').write('<svg xmlns="http://www.w3.org/2000/svg" width="1800" height="1800" viewBox="0 0 1800 1800">' + ''.join(body) + '</svg>')
    subprocess.run(['qlmanage', '-t', '-s', '1800', '-o', '../round13', '../round13/cuts.svg'], capture_output=True)


# ---------- icon documents ----------

def outline(arcs, rho=W * 0.2174):
    """Filled outlines: one band per arc, filleted only at free ends; joined ends overlap half a degree."""
    from wordmark import band
    key = lambda V, a: (round(V[0] + R * math.cos(math.radians(a)), 2), round(V[1] + R * math.sin(math.radians(a)), 2))
    count = {}
    for V, a0, a1 in arcs:
        for a in (a0, a1):
            count[key(V, a)] = count.get(key(V, a), 0) + 1
    d = ''
    for V, a0, a1 in arcs:
        f0, f1 = count[key(V, a0)] == 1, count[key(V, a1)] == 1
        d += band(V[0], V[1], R, W, a0 - (0 if f0 else 0.5), a1 + (0 if f1 else 0.5), rho, rho if f0 else 0, rho if f1 else 0)
    return d


def icon(name, limit, lens_r, scale=4 / 3):
    import json, os, shutil
    from round12 import IC, gray
    src = '../../../loop-icon.icon'
    out = f'../round13/{name}.icon'
    shutil.rmtree(out, ignore_errors=True)
    shutil.copytree(f'{src}/Assets', f'{out}/Assets')
    lines = [a for a in arcs_within(limit) if reach(a) > 64.5]
    svg = lambda body: f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">{body}</svg>'
    open(f'{out}/Assets/lines.svg', 'w').write(svg(f'<path d="{outline(lines)}" fill="#000"/>'))
    open(f'{out}/Assets/lens.svg', 'w').write(svg(f'<circle cx="512" cy="512" r="{f(lens_r)}" fill="#000"/>'))
    d = json.load(open(f'{src}/icon.json'))
    for g in d['groups']:
        for l in g['layers']:
            l['position']['scale'] = scale
    json.dump(d, open(f'{out}/icon.json', 'w'), indent=2)
    for r in ('Default', 'Dark'):
        for size, sc, tag in ((1024, 1, ''), (60, 3, '-180'), (60, 1, '-60')):
            subprocess.run([IC, out, '--export-image', '--output-file', f'../round13/{name}-{r}{tag}.png', '--platform', 'iOS',
                            '--rendition', r, '--width', str(size), '--height', str(size), '--scale', str(sc)], capture_output=True)
