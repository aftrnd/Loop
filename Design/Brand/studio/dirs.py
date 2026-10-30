"""Glass renders for directions B (Thread) and C (Field)."""
import json, os, shutil, subprocess
from studio import M, C, f
from truchet import arc
from tloop import loop_path
from fields import IC, svg, contact

def write_icon(name, layers, plate_dark=True):
    """layers: list of groups, each a list of (layer name, svg body, glass, opacity); first group is frontmost."""
    out = f'{name}.icon'
    shutil.rmtree(out, ignore_errors=True); os.makedirs(f'{out}/Assets')
    INK, WHITE = "extended-gray:0.04314,1.00000", "extended-gray:1.00000,1.00000"
    groups = []
    for g in layers:
        ls = []
        glassy = any(l[2] for l in g)
        for n, body, glass, op in g:
            open(f'{out}/Assets/{n}.svg', 'w').write(svg(body))
            ls.append({"name": n, "image-name": f"{n}.svg", "glass": glass,
                       "fill-specializations": [{"value": {"solid": INK}}, {"appearance": "dark", "value": {"solid": WHITE}}, {"appearance": "tinted", "value": {"solid": WHITE}}],
                       "opacity-specializations": [{"value": op}], "position": {"scale": 1, "translation-in-points": [0, 0]}})
        groups.append({"layers": ls, "lighting": "individual",
                       "shadow": {"kind": "layer-color", "opacity": 0.5} if glassy else {"kind": "none", "opacity": 0},
                       "specular": glassy, "translucency": {"enabled": glassy, "value": 0.5 if glassy else 0}})
    json.dump({"fill-specializations": [{"value": {"solid": WHITE}}, {"appearance": "dark", "value": {"solid": INK}}],
               "groups": groups, "supported-platforms": {"squares": "shared"}}, open(f'{out}/icon.json', 'w'), indent=2)
    for r in ('Default', 'Dark'):
        subprocess.run([IC, out, '--export-image', '--output-file', f'renders/{name}-{r}.png', '--platform', 'iOS', '--rendition', r, '--width', '1024', '--height', '1024', '--scale', '1'], capture_output=True)
        subprocess.run([IC, out, '--export-image', '--output-file', f'renders/{name}-{r}-87.png', '--platform', 'iOS', '--rendition', r, '--width', '29', '--height', '29', '--scale', '3'], capture_output=True)

def stroke_body(d, w):
    return f'<path d="{d}" fill="none" stroke="#000" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"/>'

# B. Thread: four rings joined in a row, filled. Cell 3m keeps it inside the live area.
c = 3 * M
S = [(0, 0), (1, 1), (2, 0), (3, 1)]
w, h = 4, 2
ox, oy = C - (-0.5 + w / 2) * c, C - (-0.5 + h / 2) * c
thread = loop_path(S, c, ox, oy)
write_icon('d-thread', [[('thread', f'<path d="{thread}" fill="#000"/>', True, 1)]])

# C. Field: a full-bleed Smith tiling, every arc in glass. Cell 4m, fixed seed for a balanced field.
import random
random.seed(7)
c = 4 * M
o0 = C - c / 2
d = []
grid = {}
for j in range(-3, 3):
    for i in range(-3, 3):
        grid[(i, j)] = random.randint(0, 1)
for (i, j), o in grid.items():
    x, y = o0 + i * c, o0 + j * c
    corners = [((x, y), 0, 90), ((x + c, y + c), 180, 270)] if o == 0 else [((x + c, y), 90, 180), ((x, y + c), 270, 360)]
    for (vx, vy), a0, a1 in corners:
        if 0 < vx < 1024 and 0 < vy < 1024:
            d.append(arc(vx, vy, c / 2, a0, a1))
write_icon('d-field', [[('field', stroke_body(''.join(d), 48), True, 1)]])
contact(['f-rings', 'd-thread', 'd-field'], 'dirs.svg')
print(grid)
