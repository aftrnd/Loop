"""Round two: the symmetric rings swatch, three orientations, glass treatments, flat logo."""
import json, os, subprocess
from kit import *
from iosmask import path as mask_path

os.makedirs('r2', exist_ok=True)
arcs = cell_arcs(R)
ALL = ''.join(d for _, d in arcs)
RING = ''.join(d for v, d in arcs if v in RINGS)
THREAD = ''.join(d for v, d in arcs if v not in RINGS)
W = 32
SLAB = f'<path d="{mask_path(160)}" fill="#000"/>'

ORIENT = {'S': '', 'D': f'rotate(45 {C} {C}) translate({C} {C}) scale(0.75) translate({-C} {-C})',
          'O': f'rotate(-45 {C} {C}) translate({C} {C}) scale(0.75) translate({-C} {-C})'}
def g(o, body):
    return f'<g transform="{ORIENT[o]}">{body}</g>' if ORIENT[o] else body
def wid(o): return W / (0.75 if o != 'S' else 1)

def discs(o, r):
    return g(o, ''.join(f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r)}" fill="#000"/>' for x, y in RINGS))

ideas = []
def idea(key, title, pitch, groups):
    write(key, groups, folder='r2'); ideas.append((key, title, pitch))

for o, oname in (('S', 'Square'), ('D', 'Diamond'), ('O', 'Side by side')):
    w = wid(o)
    idea(f'{o}-lifted', f'{oname}, lifted', 'Rings float in front of the lines. Tilt the phone and they part.',
         [G([L('rings', g(o, P(RING, w)))], shadow=0.7),
          G([L('threads', g(o, P(THREAD, w)), op=0.35)], shadow=0, trans=0.6)])
    idea(f'{o}-lenses', f'{oname}, lenses', 'Each person is a lens. The conversation bends through them.',
         [G([L('lens', discs(o, 96 + 16), fill=gray(1, 0.18), dark=gray(1, 0.14))], shadow=0.35, trans=0.9, refract=(0.9, 0.9)),
          G([L('threads', g(o, P(THREAD, w)), glass=False)], glass=False, shadow=0, trans=0, spec=False)])
    idea(f'{o}-inlay', f'{oname}, inlay', 'A slab cut concentric to the iOS corner, the lines inlaid.',
         [G([L('lines', g(o, P(ALL, w)), glass=False, fill=WHITE, dark=INK)], glass=False, shadow=0, trans=0, spec=False),
          G([L('slab', SLAB, fill=INK, dark=WHITE)], shadow=0.6, trans=0.2)])
# the combination: glass lenses over an inlaid slab
idea('S-lens-inlay', 'Square, lenses on a slab', 'Both: a concentric slab with the lines inlaid, and two lenses resting on it.',
     [G([L('lens', discs('S', 96 + 16), fill=gray(1, 0.16), dark=gray(0.04314, 0.16))], shadow=0.4, trans=0.9, refract=(0.9, 0.9)),
      G([L('lines', P(THREAD, W), glass=False, fill=WHITE, dark=INK)], glass=False, shadow=0, trans=0, spec=False),
      G([L('slab', SLAB, fill=INK, dark=WHITE)], shadow=0.6, trans=0.2)])
json.dump(ideas, open('r2/ideas.json', 'w'), indent=1)

# flat logo, standalone: positive and negative, logo sizes
rows = []
for o in ('S', 'D', 'O'):
    rows.append(g(o, P(ALL, wid(o))))
def flat(body, ink, ground, x, y, size):
    return f'<g transform="translate({x} {y}) scale({size/1024})"><rect width="1024" height="1024" fill="{ground}"/><g fill="none" stroke="{ink}">{body.replace("#000", ink)}</g></g>'
body = ['<rect width="1800" height="1800" fill="#f0f0f0"/>']
for k, b in enumerate(rows):
    y = 40 + k * 590
    body.append(flat(b, '#0b0b0b', '#ffffff', 40, y, 540))
    body.append(flat(b, '#ffffff', '#0b0b0b', 600, y, 540))
    x = 1170
    for s in (256, 64, 32, 16):
        body.append(flat(b, '#0b0b0b', '#ffffff', x, y, s)); x += s + 24
    x = 1170
    for s in (256, 64, 32, 16):
        body.append(flat(b, '#ffffff', '#0b0b0b', x, y + 280, s)); x += s + 24
open('r2/flat.svg', 'w').write('<svg xmlns="http://www.w3.org/2000/svg" width="1800" height="1800" viewBox="0 0 1800 1800">' + ''.join(body) + '</svg>')
subprocess.run(['qlmanage', '-t', '-s', '1800', '-o', 'r2', 'r2/flat.svg'], capture_output=True)
print(len(ideas))
