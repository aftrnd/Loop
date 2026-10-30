"""Ring glass at radius 2m (margin 16 all around, 15.5 clear between the two), gentle refraction."""
import json, os, subprocess, textwrap
from kit import *
os.makedirs('r5', exist_ok=True)
arcs = cell_arcs(R); ALL = ''.join(d for _, d in arcs); W = 32
CL, CD = gray(1, 0.08), gray(1, 0.06)
flat = lambda body: G([L('mark', body, glass=False)], glass=False, shadow=0, trans=0, spec=False)
def dome(r): return ''.join(f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r)}" fill="#000"/>' for x, y in RINGS)
def band(r0, r1):
    d = ''.join(f'M{f(x-r1)} {f(y)}a{f(r1)} {f(r1)} 0 1 0 {f(2*r1)} 0a{f(r1)} {f(r1)} 0 1 0 {f(-2*r1)} 0Z'
                f'M{f(x-r0)} {f(y)}a{f(r0)} {f(r0)} 0 1 0 {f(2*r0)} 0a{f(r0)} {f(r0)} 0 1 0 {f(-2*r0)} 0Z' for x, y in RINGS)
    return f'<path d="{d}" fill="#000" fill-rule="evenodd"/>'
ideas = []
def idea(key, title, pitch, body, refract):
    write(key, [G([L('glass', body, fill=CL, dark=CD)], shadow=0.12, trans=0.9, refract=refract), flat(P(ALL, W))], folder='r5')
    ideas.append((key, title, pitch))
for v in (0.08, 0.14, 0.2):
    idea(f'dome-{int(v*100)}', f'Dome r 2m, bend {v}', 'Glass disc of radius 2m on each ring: 16 clear all around.', dome(128), (v, v))
for v in (0.08, 0.14):
    idea(f'band-{int(v*100)}', f'Band, bend {v}', 'Glass band 64 to 128: 16 beyond the line on both sides.', band(64, 128), (v, v))
idea('dome-0', 'Dome r 2m, no bend', 'The glass alone, for reference.', dome(128), None)
idea('band-0', 'Band, no bend', 'The band alone, for reference.', band(64, 128), None)
json.dump(ideas, open('r5/ideas.json', 'w'), indent=1)
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
    open(f'r5/wall-{mode}.svg', 'w').write(f'<svg xmlns="http://www.w3.org/2000/svg" width="{Wd}" height="{Wd}" viewBox="0 0 {Wd} {Wd}">' + ''.join(body) + '</svg>')
    subprocess.run(['qlmanage', '-t', '-s', str(Wd), '-o', 'r5', f'r5/wall-{mode}.svg'], capture_output=True)
