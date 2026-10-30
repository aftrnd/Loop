"""Pitch wall: twelve ideas around the symmetric rings swatch, each with its own use of glass."""
import json, math, os, shutil, subprocess
from studio import M, C, f
from truchet import arc
from fields import IC

R = [[0, 1, 1], [1, 0, 1], [1, 1, 0]]
c = 3 * M; X0 = C - 1.5 * c
RINGS = [(X0 + c, X0 + c), (X0 + 2 * c, X0 + 2 * c)]
INK, WHITE = "extended-gray:0.04314,1.00000", "extended-gray:1.00000,1.00000"
gray = lambda v, a=1: f"extended-gray:{v:.5f},{a:.5f}"

def cell_arcs(grid, x0=X0, cc=c, rads=None):
    out = []
    for j, row in enumerate(grid):
        for i, o in enumerate(row):
            x, y = x0 + i * cc, x0 + j * cc
            cs = [((x, y), 0, 90), ((x + cc, y + cc), 180, 270)] if o == 0 else [((x + cc, y), 90, 180), ((x, y + cc), 270, 360)]
            for (vx, vy), a0, a1 in cs:
                for r in (rads or [cc / 2]):
                    out.append(((vx, vy), arc(vx, vy, r, a0, a1)))
    return out

def P(d, w, cap='butt', extra=''):
    return f'<path d="{d}" fill="none" stroke="#000" stroke-width="{f(w)}" stroke-linecap="{cap}" {extra}/>'

def svg(body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">{body}</svg>'

def L(name, body, glass=True, fill=None, dark=None, op=1, tinted=WHITE):
    return dict(name=name, body=body, glass=glass, fill=fill or INK, dark=dark or WHITE, op=op, tinted=tinted)

def G(layers, glass=True, shadow=0.5, trans=0.5, refract=None, blur=None, spec=True):
    return dict(layers=layers, glass=glass, shadow=shadow, trans=trans, refract=refract, blur=blur, spec=spec)

def write(name, groups, bg_light=WHITE, bg_dark=INK, folder='pitch'):
    out = f'{folder}/{name}.icon'
    shutil.rmtree(out, ignore_errors=True); os.makedirs(f'{out}/Assets')
    gs = []
    for g in groups:
        ls = []
        for l in g['layers']:
            open(f"{out}/Assets/{l['name']}.svg", 'w').write(svg(l['body']))
            fl = l['fill'] if isinstance(l['fill'], dict) else {"solid": l['fill']}
            fd = l['dark'] if isinstance(l['dark'], dict) else {"solid": l['dark']}
            ls.append({"name": l['name'], "image-name": f"{l['name']}.svg", "glass": l['glass'],
                       "fill-specializations": [{"value": fl}, {"appearance": "dark", "value": fd}, {"appearance": "tinted", "value": {"solid": l['tinted']}}],
                       "opacity-specializations": [{"value": l['op']}], "position": {"scale": 1, "translation-in-points": [0, 0]}})
        grp = {"layers": ls, "lighting": "individual",
               "shadow": {"kind": "neutral", "opacity": g['shadow']} if g['shadow'] else {"kind": "none", "opacity": 0},
               "specular": g['spec'], "translucency": {"enabled": bool(g['trans']), "value": g['trans'] or 0}}
        if g['refract']: grp["refractivity"] = {"enabled": True, "depth": g['refract'][0], "strength": g['refract'][1]}
        if g['blur'] is not None: grp["blur-material"] = g['blur']
        gs.append(grp)
    json.dump({"fill-specializations": [{"value": {"solid": bg_light}}, {"appearance": "dark", "value": {"solid": bg_dark}}],
               "groups": gs, "supported-platforms": {"squares": "shared"}}, open(f'{out}/icon.json', 'w'), indent=2)
    for r in ('Default', 'Dark'):
        subprocess.run([IC, out, '--export-image', '--output-file', f'{folder}/{name}-{r}.png', '--platform', 'iOS', '--rendition', r, '--width', '1024', '--height', '1024', '--scale', '1'], capture_output=True)
        subprocess.run([IC, out, '--export-image', '--output-file', f'{folder}/{name}-{r}-87.png', '--platform', 'iOS', '--rendition', r, '--width', '29', '--height', '29', '--scale', '3'], capture_output=True)

