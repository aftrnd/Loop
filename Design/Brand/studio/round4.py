"""Ring glass, centered on each ring with an even margin all around."""
import json, os, subprocess, textwrap, math
from kit import *
os.makedirs('r4', exist_ok=True)
arcs = cell_arcs(R); ALL = ''.join(d for _, d in arcs); W = 32
CL, CD = gray(1, 0.08), gray(1, 0.06)
# clearance check: nearest thread edge to each ring center
thread_centers = [v for v, _ in arcs if v not in RINGS]
near = min(math.dist(v, RINGS[0]) for v in thread_centers) - c / 2 - W / 2
print('nearest thread edge from ring center', round(near, 1), 'ring outer edge', c / 2 + W / 2)
flat = lambda body: G([L('mark', body, glass=False)], glass=False, shadow=0, trans=0, spec=False)
def dome(r): return ''.join(f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r)}" fill="#000"/>' for x, y in RINGS)
def band(r0, r1):
    d = ''.join(f'M{f(x-r1)} {f(y)}a{f(r1)} {f(r1)} 0 1 0 {f(2*r1)} 0a{f(r1)} {f(r1)} 0 1 0 {f(-2*r1)} 0Z'
                f'M{f(x-r0)} {f(y)}a{f(r0)} {f(r0)} 0 1 0 {f(2*r0)} 0a{f(r0)} {f(r0)} 0 1 0 {f(-2*r0)} 0Z' for x, y in RINGS)
    return f'<path d="{d}" fill="#000" fill-rule="evenodd"/>'
ideas = []
def idea(key, title, pitch, glass_body, refract, shadow=0.15):
    write(key, [G([L('glass', glass_body, fill=CL, dark=CD)], shadow=shadow, trans=0.9, refract=refract), flat(P(ALL, W))], folder='r4')
    ideas.append((key, title, pitch))
ro = c / 2 + W / 2   # ring outer edge, 112
idea('dome24', 'Dome, margin 24', 'Glass disc centered on the ring, 24 clear all around.', dome(ro + 24), (0.5, 0.5))
idea('dome32', 'Dome, margin 32', 'Half a module of glass all around the ring.', dome(ro + 32), (0.5, 0.5))
idea('dome32s', 'Dome, margin 32, subtle', 'Same dome, less bend.', dome(ro + 32), (0.3, 0.3))
idea('dome32n', 'Dome, margin 32, no bend', 'The glass alone, no refraction, for reference.', dome(ro + 32), None)
idea('band40', 'Band, 40 each side', 'A glass band centered on the ring line, 40 inside and 40 outside.', band(c / 2 - 40, c / 2 + 40), (0.5, 0.5))
idea('band40s', 'Band, 40 each side, subtle', 'Same band, less bend.', band(c / 2 - 40, c / 2 + 40), (0.3, 0.3))
idea('band24', 'Band, 24 each side', 'A thinner band hugging the line.', band(c / 2 - 24, c / 2 + 24), (0.5, 0.5))
idea('band40n', 'Band, no bend', 'The band alone, no refraction, for reference.', band(c / 2 - 40, c / 2 + 40), None)
json.dump(ideas, open('r4/ideas.json', 'w'), indent=1)
for mode in ('Dark', 'Default'):
    bg, fg, fg2 = ('#111113', '#f2f2f2', '#9a9a9a') if mode == 'Dark' else ('#ececec', '#0b0b0b', '#666')
    Wd = 1800; cw = 435
    body = [f'<rect width="{Wd}" height="{Wd}" fill="{bg}"/>']
    for k, (key, title, pitch) in enumerate(ideas):
        col, row = k % 4, k // 4
        x = 22 + col * (cw + 10); y = 30 + row * 590
        body.append(f'<image href="{key}-{mode}.png" x="{x+30}" y="{y}" width="375" height="375"/>')
        body.append(f'<image href="{key}-{mode}-87.png" x="{x+30}" y="{y+390}" width="58" height="58"/>')
        body.append(f'<text x="{x+104}" y="{y+410}" font-family="Helvetica Neue" font-size="20" font-weight="500" fill="{fg}">{title}</text>')
        for n, line in enumerate(textwrap.wrap(pitch, 36)):
            body.append(f'<text x="{x+104}" y="{y+436+n*21}" font-family="Helvetica Neue" font-size="15" fill="{fg2}">{line}</text>')
    open(f'r4/wall-{mode}.svg', 'w').write(f'<svg xmlns="http://www.w3.org/2000/svg" width="{Wd}" height="{Wd}" viewBox="0 0 {Wd} {Wd}">' + ''.join(body) + '</svg>')
    subprocess.run(['qlmanage', '-t', '-s', str(Wd), '-o', 'r4', f'r4/wall-{mode}.svg'], capture_output=True)
