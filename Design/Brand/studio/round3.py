"""Round three: refraction that is centered and concentric, after Apple's iOS 27 icons."""
import json, os, subprocess, textwrap
from kit import *
from iosmask import path as mask_path

os.makedirs('r3', exist_ok=True)
arcs = cell_arcs(R)
ALL = ''.join(d for _, d in arcs)
W = 32
# the endless pattern: the swatch repeated, phased so the swatch's center cell stays at the icon center
big = [[R[(j + 1) % 3][(i + 1) % 3] for i in range(-3, 4)] for j in range(-3, 4)]
FIELD = ''.join(d for _, d in cell_arcs(big, x0=C - 3.5 * c))
LENS = lambda r, cx=C, cy=C: f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r)}" fill="#000"/>'
CLEAR_L, CLEAR_D = gray(1, 0.08), gray(1, 0.06)

ideas = []
def idea(key, title, pitch, groups):
    write(key, groups, folder='r3'); ideas.append((key, title, pitch))

flat = lambda body: G([L('mark', body, glass=False)], glass=False, shadow=0, trans=0, spec=False)

for k, (dep, st) in enumerate([(0.5, 0.5), (0.8, 0.8)]):
    s = 'soft' if k == 0 else 'strong'
    idea(f'center-{s}', f'Center lens, {s}', 'One lens on the axis of symmetry, where the two rings meet.',
         [G([L('lens', LENS(c * 0.75), fill=CLEAR_L, dark=CLEAR_D)], shadow=0.3, trans=0.9, refract=(dep, st)), flat(P(ALL, W))])
    idea(f'tile-{s}', f'Glass tile, {s}', 'A glass tile, concentric with the icon, lying on the endless pattern.',
         [G([L('slab', f'<path d="{mask_path(160)}" fill="#000"/>', fill=CLEAR_L, dark=CLEAR_D)], shadow=0.35, trans=0.9, refract=(dep, st)),
          G([L('field', P(FIELD, W), glass=False)], glass=False, shadow=0, trans=0, spec=False)])
    idea(f'domes-{s}', f'Ring domes, {s}', 'A glass dome over each ring, exactly concentric with it.',
         [G([L('domes', LENS(c / 2 + W / 2, *RINGS[0]) + LENS(c / 2 + W / 2, *RINGS[1]), fill=CLEAR_L, dark=CLEAR_D)], shadow=0.3, trans=0.9, refract=(dep, st)),
          flat(P(ALL, W))])
    idea(f'crystal-{s}', f'Watch crystal, {s}', 'One round crystal over the whole mark, the lines bending at its rim.',
         [G([L('crystal', LENS(1.5 * c * 1.18), fill=CLEAR_L, dark=CLEAR_D)], shadow=0.3, trans=0.9, refract=(dep, st)), flat(P(ALL, W))])
json.dump(ideas, open('r3/ideas.json', 'w'), indent=1)

for mode in ('Dark', 'Default'):
    bg, fg, fg2 = ('#111113', '#f2f2f2', '#9a9a9a') if mode == 'Dark' else ('#ececec', '#0b0b0b', '#666')
    Wd = 1800; cw = 435
    body = [f'<rect width="{Wd}" height="{Wd}" fill="{bg}"/>']
    order = [i for i in ideas if i[0].endswith('soft')] + [i for i in ideas if i[0].endswith('strong')]
    for k, (key, title, pitch) in enumerate(order):
        col, row = k % 4, k // 4
        x = 22 + col * (cw + 10); y = 30 + row * 590
        body.append(f'<image href="{key}-{mode}.png" x="{x+30}" y="{y}" width="375" height="375"/>')
        body.append(f'<image href="{key}-{mode}-87.png" x="{x+30}" y="{y+390}" width="58" height="58"/>')
        body.append(f'<text x="{x+104}" y="{y+410}" font-family="Helvetica Neue" font-size="20" font-weight="500" fill="{fg}">{title}</text>')
        for n, line in enumerate(textwrap.wrap(pitch, 36)):
            body.append(f'<text x="{x+104}" y="{y+436+n*21}" font-family="Helvetica Neue" font-size="15" fill="{fg2}">{line}</text>')
    open(f'r3/wall-{mode}.svg', 'w').write(f'<svg xmlns="http://www.w3.org/2000/svg" width="{Wd}" height="{Wd}" viewBox="0 0 {Wd} {Wd}">' + ''.join(body) + '</svg>')
    subprocess.run(['qlmanage', '-t', '-s', str(Wd), '-o', 'r3', f'r3/wall-{mode}.svg'], capture_output=True)
print(len(ideas))
