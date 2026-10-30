import json, os, subprocess
from kit import *
from iosmask import path as mask_path
arcs = cell_arcs(R); ALL = ''.join(d for _, d in arcs); W = 32
CL, CD = gray(1, 0.08), gray(1, 0.06)
LENS = lambda r, cx=C, cy=C: f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r)}" fill="#000"/>'
flat = lambda body: G([L('mark', body, glass=False)], glass=False, shadow=0, trans=0, spec=False)
ideas = json.load(open('r3/ideas.json'))
new = []
for dep, st, s in ((0.3, 0.3, 'light'), (0.5, 0.5, 'soft')):
    write(f'over-{s}', [G([L('slab', f'<path d="{mask_path(160)}" fill="#000"/>', fill=CL, dark=CD)], shadow=0.35, trans=0.9, refract=(dep, st)), flat(P(ALL, W))], folder='r3')
    new.append((f'over-{s}', f'Tile over the mark, {s}', 'A concentric glass tile over the mark alone. Lines bend only where they meet its rim.'))
write('domes-light', [G([L('domes', LENS(c / 2 + W / 2, *RINGS[0]) + LENS(c / 2 + W / 2, *RINGS[1]), fill=CL, dark=CD)], shadow=0.3, trans=0.9, refract=(0.3, 0.3)), flat(P(ALL, W))], folder='r3')
new.append(('domes-light', 'Ring domes, light', 'A glass dome over each ring, exactly concentric, barely bending.'))
json.dump(new, open('r3/ideas-b.json', 'w'), indent=1)
