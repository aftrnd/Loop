"""Loop marks from waves, on Apple's icon grid (1024 canvas, 8 x 8 cells of 128, keylines r 409.6 / 256 / 102.4)."""
import json, math, os, shutil, subprocess, sys

IC = "/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"
C = 512
K_OUT, K_MID, K_IN = 409.6, 256.0, 102.4
W = 1024 / 20                    # stroke: a quarter of the inner keyline's diameter
gray = lambda v, a=1: f"extended-gray:{v:.5f},{a:.5f}"
INK, WHITE = gray(0.04314), gray(1)
f = lambda v: ('%.2f' % v).rstrip('0').rstrip('.')


def polar(rfun, n=1440, phase=0):
    pts = []
    for i in range(n):
        t = 2 * math.pi * i / n
        r = rfun(t)
        pts.append((C + r * math.cos(t + phase), C + r * math.sin(t + phase)))
    return 'M' + 'L'.join(f'{f(x)} {f(y)}' for x, y in pts) + 'Z'


def wave(R, A, n, sign=1, phase=-math.pi / 2):
    return polar(lambda t: R + sign * A * math.sin(n * t), phase=phase)


def stroke(d, w=W):
    return f'<path d="{d}" fill="none" stroke="#000" stroke-width="{f(w)}" stroke-linejoin="round"/>'


def fill(d, rule='evenodd'):
    return f'<path d="{d}" fill="#000" fill-rule="{rule}"/>'


def svg(body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">{body}</svg>'


def write(name, layers, out='icons', bg=(WHITE, INK), sizes=((512, 1, ''), (29, 3, '-87')), renditions=('Default', 'Dark')):
    """layers: top first. Each: dict(name, body, glass=False, light=INK, dark=WHITE, group=k, refract=0.15, op=1)."""
    doc = f'{out}/{name}.icon'
    shutil.rmtree(doc, ignore_errors=True); os.makedirs(f'{doc}/Assets')
    groups = {}
    for L in layers:
        open(f"{doc}/Assets/{L['name']}.svg", 'w').write(svg(L['body']))
        entry = {"name": L['name'], "image-name": f"{L['name']}.svg", "glass": L.get('glass', False),
                 "fill-specializations": [{"value": {"solid": L.get('light', INK)}}, {"appearance": "dark", "value": {"solid": L.get('dark', WHITE)}},
                                          {"appearance": "tinted", "value": {"solid": L.get('tinted', WHITE)}}],
                 "opacity-specializations": [{"value": L.get('op', 1)}], "position": {"scale": 1, "translation-in-points": [0, 0]}}
        groups.setdefault(L.get('group', 0), []).append((entry, L))
    gs = []
    for k in sorted(groups):
        entries = groups[k]
        glassy = any(L.get('glass') for _, L in entries)
        g = {"layers": [e for e, _ in entries], "lighting": "individual"}
        if glassy:
            L0 = entries[0][1]
            g.update({"shadow": {"kind": "neutral", "opacity": L0.get('shadow', 0.3)}, "specular": True,
                      "translucency": {"enabled": True, "value": L0.get('trans', 0.6)}})
            if L0.get('refract', 0.15):
                g["refractivity"] = {"enabled": True, "depth": L0.get('refract', 0.15), "strength": L0.get('refract', 0.15)}
        else:
            g.update({"shadow": {"kind": "none", "opacity": 0}, "specular": False, "translucency": {"enabled": False, "value": 0}})
        gs.append(g)
    bgs = [{"value": bg[0] if isinstance(bg[0], dict) else {"solid": bg[0]}},
           {"appearance": "dark", "value": bg[1] if isinstance(bg[1], dict) else {"solid": bg[1]}}]
    json.dump({"fill-specializations": bgs, "groups": gs, "supported-platforms": {"squares": "shared"}}, open(f'{doc}/icon.json', 'w'), indent=2)
    for r in renditions:
        for size, sc, tag in sizes:
            extra = ['--tint-color', '0.6', '--tint-strength', '0.8'] if r.startswith('Tinted') else []
            subprocess.run([IC, doc, '--export-image', '--output-file', f'{out}/{name}-{r}{tag}.png', '--platform', 'iOS', '--rendition', r,
                            '--width', str(size), '--height', str(size), '--scale', str(sc)] + extra, capture_output=True)
    return doc
