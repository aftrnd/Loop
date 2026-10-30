"""Tangent bands: glass centered on each ring line, half-width r(sqrt2 - 1), so the two bands touch at the mark's center. No refraction."""
import json, os, subprocess, textwrap, math
from kit import *
os.makedirs('r6', exist_ok=True)
arcs = cell_arcs(R); ALL = ''.join(d for _, d in arcs); W = 32
RING = ''.join(d for v, d in arcs if v in RINGS); THREAD = ''.join(d for v, d in arcs if v not in RINGS)
r = c / 2; hw = r * (math.sqrt(2) - 1); r0, r1 = r - hw, r + hw
print('half-width', round(hw, 3), 'inner', round(r0, 3), 'outer', round(r1, 3), 'half center distance', round(c * math.sqrt(2) / 2, 3))
CL, CD = gray(1, 0.08), gray(1, 0.06)
flat = lambda body: G([L('mark', body, glass=False)], glass=False, shadow=0, trans=0, spec=False)
def band(a, b):
    d = ''.join(f'M{f(x-b)} {f(y)}a{f(b)} {f(b)} 0 1 0 {f(2*b)} 0a{f(b)} {f(b)} 0 1 0 {f(-2*b)} 0Z'
                f'M{f(x-a)} {f(y)}a{f(a)} {f(a)} 0 1 0 {f(2*a)} 0a{f(a)} {f(a)} 0 1 0 {f(-2*a)} 0Z' for x, y in RINGS)
    return f'<path d="{d}" fill="#000" fill-rule="evenodd"/>'
ideas = []
def idea(key, title, pitch, groups):
    write(key, groups, folder='r6'); ideas.append((key, title, pitch))
idea('tangent', 'Tangent bands', 'Clear glass on each ring line. The two bands touch at one point: the center of the mark.',
     [G([L('band', band(r0, r1), fill=CL, dark=CD)], shadow=0.12, trans=0.9), flat(P(ALL, W))])
idea('tangent-frost', 'Tangent bands, frosted', 'The same bands, a little more body to the glass.',
     [G([L('band', band(r0, r1), fill=gray(1, 0.35), dark=gray(1, 0.12))], shadow=0.15, trans=0.6), flat(P(ALL, W))])
idea('tangent-glassline', 'Tangent bands, glass rings', 'The ring lines themselves in glass, inside their bands; the threads stay flat ink.',
     [G([L('ring', P(RING, W))], shadow=0.3), G([L('band', band(r0, r1), fill=CL, dark=CD)], shadow=0.12, trans=0.9), flat(P(THREAD, W))])
idea('tangent-only', 'Glass only', 'No ink line under the band: the ring is the glass.',
     [G([L('band', band(r0, r1), fill=gray(0.04314, 0.85), dark=gray(1, 0.85))], shadow=0.3, trans=0.4), flat(P(THREAD, W))])
json.dump(ideas, open('r6/ideas.json', 'w'), indent=1)
IC = "/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"
for key, _, _ in ideas:
    subprocess.run([IC, f'r6/{key}.icon', '--export-image', '--output-file', f'r6/{key}-Tinted.png', '--platform', 'iOS', '--rendition', 'TintedDark', '--width', '1024', '--height', '1024', '--scale', '1', '--tint-color', '0.6', '--tint-strength', '0.8'], capture_output=True)
Wd = 1800
body = ['<rect width="1800" height="1800" fill="#e9e9e9"/><rect y="900" width="1800" height="900" fill="#151517"/>']
for k, (key, title, pitch) in enumerate(ideas):
    x = 20 + k * 445
    body.append(f'<image href="{key}-Default.png" x="{x}" y="20" width="420" height="420"/>')
    body.append(f'<image href="{key}-Default-87.png" x="{x}" y="460" width="87" height="87"/>')
    body.append(f'<text x="{x+105}" y="490" font-family="Helvetica Neue" font-size="20" font-weight="500" fill="#0b0b0b">{title}</text>')
    for n, line in enumerate(textwrap.wrap(pitch, 30)):
        body.append(f'<text x="{x+105}" y="{516+n*21}" font-family="Helvetica Neue" font-size="15" fill="#555">{line}</text>')
    body.append(f'<image href="{key}-Dark.png" x="{x}" y="920" width="420" height="420"/>')
    body.append(f'<image href="{key}-Dark-87.png" x="{x}" y="1360" width="87" height="87"/>')
    body.append(f'<image href="{key}-Tinted.png" x="{x+120}" y="1360" width="300" height="300"/>')
open('r6/wall.svg', 'w').write(f'<svg xmlns="http://www.w3.org/2000/svg" width="{Wd}" height="{Wd}" viewBox="0 0 {Wd} {Wd}">' + ''.join(body) + '</svg>')
subprocess.run(['qlmanage', '-t', '-s', str(Wd), '-o', 'r6', 'r6/wall.svg'], capture_output=True)
