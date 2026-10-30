"""Field treatments for the Truchet loop, rendered through ictool."""
import json, os, shutil, subprocess
from studio import M, C, f
from truchet import arc
from tloop import loop_path

IC = "/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"
c = 4 * M
ox = oy = C - c / 2
LOOP = loop_path([(0, 1), (1, 0)], c, ox, oy)

# orientation 0: arcs around TL and BR; 1: around TR and BL. Central cell (0,0) must be 0.
ORIENT = {
    'checker': lambda i, j: {(0, 0): 0, (0, -1): 0, (1, -1): 1, (1, 0): 0, (-1, 0): 0, (-1, 1): 1, (0, 1): 0}.get((i, j), (i + j) % 2),
    'peanuts': lambda i, j: 1 if (i + j) % 2 == 0 and i % 2 else 0,
    'rings':   lambda i, j: 0 if (i, j) == (0, 0) or (i + j) % 2 else 1,
}

def field_arcs(orient, skip_loop=True):
    out = []
    for j in range(-3, 3):
        for i in range(-3, 3):
            x, y = ox + i * c, oy + j * c
            o = orient(i, j)
            corners = [((x, y), 0, 90), ((x + c, y + c), 180, 270)] if o == 0 else [((x + c, y), 90, 180), ((x, y + c), 270, 360)]
            for (vx, vy), a0, a1 in corners:
                if 0 < vx < 1024 and 0 < vy < 1024:
                    out.append(((vx, vy), arc(vx, vy, c / 2, a0, a1)))
    return out

def loop_arc_set():
    # arcs that belong to the mark, so the field can leave them out
    import re
    return LOOP

def svg(body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">{body}</svg>'

def build(name, orient, fw=12, fop=0.22, fglass=False, lw=M):
    out = f'{name}.icon'
    shutil.rmtree(out, ignore_errors=True); os.makedirs(f'{out}/Assets')
    open(f'{out}/Assets/loop.svg', 'w').write(svg(f'<path d="{LOOP}" fill="none" stroke="#000" stroke-width="{lw}" stroke-linecap="round" stroke-linejoin="round"/>'))
    fd = ''.join(d for _, d in field_arcs(ORIENT[orient]))
    open(f'{out}/Assets/field.svg', 'w').write(svg(f'<path d="{fd}" fill="none" stroke="#000" stroke-width="{fw}" stroke-linecap="round"/>'))
    INK, WHITE = "extended-gray:0.04314,1.00000", "extended-gray:1.00000,1.00000"
    def layer(n, glass, op):
        return {"name": n, "image-name": f"{n}.svg", "glass": glass,
                "fill-specializations": [{"value": {"solid": INK}}, {"appearance": "dark", "value": {"solid": WHITE}}, {"appearance": "tinted", "value": {"solid": WHITE}}],
                "opacity-specializations": [{"value": op}], "position": {"scale": 1, "translation-in-points": [0, 0]}}
    icon = {"fill-specializations": [{"value": {"solid": WHITE}}, {"appearance": "dark", "value": {"solid": INK}}],
            "groups": [{"layers": [layer("loop", True, 1)], "lighting": "individual", "shadow": {"kind": "layer-color", "opacity": 0.5}, "specular": True, "translucency": {"enabled": True, "value": 0.5}},
                       {"layers": [layer("field", fglass, fop)], "lighting": "individual", "shadow": {"kind": "none", "opacity": 0}, "specular": fglass, "translucency": {"enabled": fglass, "value": 0.5 if fglass else 0}}],
            "supported-platforms": {"squares": "shared"}}
    json.dump(icon, open(f'{out}/icon.json', 'w'), indent=2)
    os.makedirs('renders', exist_ok=True)
    for r in ('Default', 'Dark'):
        subprocess.run([IC, out, '--export-image', '--output-file', f'renders/{name}-{r}.png', '--platform', 'iOS', '--rendition', r, '--width', '1024', '--height', '1024', '--scale', '1'], capture_output=True)
        subprocess.run([IC, out, '--export-image', '--output-file', f'renders/{name}-{r}-87.png', '--platform', 'iOS', '--rendition', r, '--width', '29', '--height', '29', '--scale', '3'], capture_output=True)

def contact(names, path):
    # rows: name, Default 1024 at 380, Dark 1024 at 380, Default 87, Dark 87
    W = 1800; rh = 420
    body = [f'<rect width="{W}" height="{W}" fill="#e9e9e9"/>']
    for k, n in enumerate(names):
        y = 30 + k * rh
        body.append(f'<text x="30" y="{y+14}" font-family="Menlo" font-size="16" fill="#555">{n}</text>')
        body.append(f'<image href="{n}-Default.png" x="30" y="{y+24}" width="380" height="380"/>')
        body.append(f'<rect x="440" y="{y+24}" width="380" height="380" fill="#1c1c1e"/>')
        body.append(f'<image href="{n}-Dark.png" x="440" y="{y+24}" width="380" height="380"/>')
        body.append(f'<image href="{n}-Default-87.png" x="860" y="{y+170}" width="87" height="87"/>')
        body.append(f'<rect x="970" y="{y+150}" width="127" height="127" fill="#1c1c1e"/>')
        body.append(f'<image href="{n}-Dark-87.png" x="990" y="{y+170}" width="87" height="87"/>')
    open(f'renders/{path}', 'w').write(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{W}" viewBox="0 0 {W} {W}">' + ''.join(body) + '</svg>')
    subprocess.run(['qlmanage', '-t', '-s', str(W), '-o', 'renders', f'renders/{path}'], capture_output=True)

if __name__ == '__main__':
    build('f-peanuts', 'peanuts', fw=10, fop=0.18)
    build('f-rings', 'rings', fw=10, fop=0.18)
    build('f-checker-quiet', 'checker', fw=8, fop=0.12)
    build('f-peanuts-glass', 'peanuts', fw=24, fop=0.35, fglass=True)
    contact(['f-peanuts', 'f-rings', 'f-checker-quiet', 'f-peanuts-glass'], 'fields.svg')
    print('done')
