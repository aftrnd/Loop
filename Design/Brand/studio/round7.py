"""Tangent bands with refraction: is the bend even all around the ring?"""
import json, os, subprocess, math
from kit import *
os.makedirs('r7', exist_ok=True)
arcs = cell_arcs(R); ALL = ''.join(d for _, d in arcs); W = 32
r = c / 2; hw = r * (math.sqrt(2) - 1); r0, r1 = r - hw, r + hw
CL, CD = gray(1, 0.08), gray(1, 0.06)
flat = lambda body: G([L('mark', body, glass=False)], glass=False, shadow=0, trans=0, spec=False)
def band(a, b):
    d = ''.join(f'M{f(x-b)} {f(y)}a{f(b)} {f(b)} 0 1 0 {f(2*b)} 0a{f(b)} {f(b)} 0 1 0 {f(-2*b)} 0Z'
                f'M{f(x-a)} {f(y)}a{f(a)} {f(a)} 0 1 0 {f(2*a)} 0a{f(a)} {f(a)} 0 1 0 {f(-2*a)} 0Z' for x, y in RINGS)
    return f'<path d="{d}" fill="#000" fill-rule="evenodd"/>'
keys = []
for v in (0.05, 0.1, 0.15, 0.2, 0.25):
    for dep in (v,):
        k = f'tb-{int(v*100):02d}'
        write(k, [G([L('band', band(r0, r1), fill=CL, dark=CD)], shadow=0.12, trans=0.9, refract=(dep, v)), flat(P(ALL, W))], folder='r7')
        keys.append(k)
# depth versus strength split at 0.15
for dep, st in ((0.4, 0.1), (0.1, 0.4)):
    k = f'tb-d{int(dep*100)}-s{int(st*100)}'
    write(k, [G([L('band', band(r0, r1), fill=CL, dark=CD)], shadow=0.12, trans=0.9, refract=(dep, st)), flat(P(ALL, W))], folder='r7')
    keys.append(k)
json.dump(keys, open('r7/keys.json', 'w'))
# contact: full icon plus a 3x crop of the top-left ring, light and dark
x0 = int(RINGS[0][0] - r1 - 24); y0 = x0; s = int(2 * (r1 + 24))
body = ['<rect width="1800" height="1800" fill="#e6e6e6"/>']
for k, key in enumerate(keys):
    y = 10 + k * 255
    body.append(f'<text x="10" y="{y+20}" font-family="Menlo" font-size="15" fill="#333">{key}</text>')
    for j, m in enumerate(('Default', 'Dark')):
        X = 160 + j * 820
        body.append(f'<image href="{key}-{m}.png" x="{X}" y="{y}" width="240" height="240"/>')
        body.append(f'<svg x="{X+260}" y="{y}" width="540" height="240" viewBox="{x0 - (s*2.25-s)/2} {y0} {s*2.25} {s}"><image href="{key}-{m}.png" width="1024" height="1024"/></svg>')
open('r7/zoom.svg', 'w').write('<svg xmlns="http://www.w3.org/2000/svg" width="1800" height="1800" viewBox="0 0 1800 1800">' + ''.join(body) + '</svg>')
subprocess.run(['qlmanage', '-t', '-s', '1800', '-o', 'r7', 'r7/zoom.svg'], capture_output=True)
