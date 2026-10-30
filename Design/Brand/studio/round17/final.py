"""Said and echoed, final geometry: each bubble is one closed path of exact arcs and one tangent line.

u = 32 (a quarter of Apple's 128 grid cell). R = 7u. Said at (13u, 13u); echo mirrored at (19u, 19u).
Tip circle R/8 filleting the bounding-square corner; outer edge the common tangent of bubble and tip;
underside an arc of radius R/2 tangent to bubble and tip."""
import json, math, os, shutil, subprocess
from bubble_math import two_circle
from bubble_math2 import ext_tangent

IC = "/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"
U = 32; R = 7 * U
SAID, ECHO = (13 * U, 13 * U), (19 * U, 19 * U)
fx = lambda v: f'{v:.3f}'.rstrip('0').rstrip('.')

def geometry(O, kt=1 / 8, ki=1 / 2):
    rt, ri = R * kt, R * ki
    T = (O[0] - R + rt, O[1] + R - rt)
    P1, P2 = ext_tangent(O, R, T, rt, pick=lambda n: n[0] + n[1])
    Ki = max(two_circle(O, R + ri, T, rt + ri), key=lambda k: k[1])
    Si = (O[0] + (Ki[0] - O[0]) * R / (R + ri), O[1] + (Ki[1] - O[1]) * R / (R + ri))
    Qi = (T[0] + (Ki[0] - T[0]) * rt / (rt + ri), T[1] + (Ki[1] - T[1]) * rt / (rt + ri))
    return dict(O=O, T=T, rt=rt, Ki=Ki, ri=ri, P1=P1, P2=P2, Si=Si, Qi=Qi)

def sweep(K, p, q, cw):
    """Angle travelled from p to q around K, clockwise on screen (y down) if cw."""
    a = math.atan2(p[1] - K[1], p[0] - K[0]); b = math.atan2(q[1] - K[1], q[0] - K[0])
    d = (b - a) % (2 * math.pi)
    return d if cw else 2 * math.pi - d

def arc(K, r, p, q, cw):
    s = sweep(K, p, q, cw)
    return f'A{fx(r)} {fx(r)} 0 {1 if s > math.pi else 0} {1 if cw else 0} {fx(q[0])} {fx(q[1])}'

def path(O, mirror=False):
    g = geometry(O)
    m = (lambda p: (2 * O[0] - p[0], p[1])) if mirror else (lambda p: p)
    cw = lambda c: (not c) if mirror else c
    P1, P2, Si, Qi, T, Ki = (m(g[k]) for k in ('P1', 'P2', 'Si', 'Qi', 'T', 'Ki'))
    # body the long way round (clockwise), fillet back toward the tip (counterclockwise), tip around its outside (clockwise), then the tangent line
    return (f'M{fx(P1[0])} {fx(P1[1])}' + arc(m(O), R, P1, Si, cw(True)) + arc(Ki, g['ri'], Si, Qi, cw(False))
            + arc(T, g['rt'], Qi, P2, cw(True)) + 'Z')

def svg(d):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024"><path d="{d}"/></svg>'

gray = lambda v, a=1: f"extended-gray:{v:.5f},{a:.5f}"
INK, WHITE = gray(0.04314), gray(1)

def write(name, strength=0.25, depth=0.4, apple_defaults=True, out='final'):
    doc = f'{out}/{name}.icon'
    shutil.rmtree(doc, ignore_errors=True); os.makedirs(f'{doc}/Assets')
    open(f'{doc}/Assets/echo.svg', 'w').write(svg(path(ECHO, mirror=True)))
    open(f'{doc}/Assets/said.svg', 'w').write(svg(path(SAID)))
    def layer(n, light, dark, tinted):
        return {"name": n, "image-name": f"{n}.svg", "glass": True,
                "fill-specializations": [{"value": {"solid": light}}, {"appearance": "dark", "value": {"solid": dark}},
                                         {"appearance": "tinted", "value": {"solid": tinted}}]}
    echo = {"name": "Echo", "layers": [layer('echo', gray(0.04314, 0.16), gray(1, 0.14), gray(1, 0.1))],
            "refractivity": {"enabled": True, "depth": depth, "strength": strength}}
    said = {"name": "Said", "layers": [layer('said', INK, WHITE, WHITE)]}
    if not apple_defaults:
        echo.update({"lighting": "individual", "shadow": {"kind": "neutral", "opacity": 0.15}, "specular": True, "translucency": {"enabled": True, "value": 0.4}})
        said.update({"lighting": "individual", "shadow": {"kind": "neutral", "opacity": 0.2}, "specular": True, "translucency": {"enabled": True, "value": 0.2}})
    json.dump({"fill-specializations": [{"value": {"solid": WHITE}}, {"appearance": "dark", "value": {"solid": INK}}],
               "groups": [echo, said], "supported-platforms": {"squares": "shared"}}, open(f'{doc}/icon.json', 'w'), indent=2)
    return doc

def render(doc, tag, rends=('Default', 'Dark', 'TintedDark'), sizes=((1024, 1, ''), (60, 3, '-180'), (29, 3, '-87'))):
    for r in rends:
        extra = ['--tint-color', '0.6', '--tint-strength', '0.8'] if r.startswith('Tinted') else []
        for size, sc, t in sizes:
            subprocess.run([IC, doc, '--export-image', '--output-file', f'final/{tag}-{r}{t}.png', '--platform', 'iOS', '--rendition', r,
                            '--width', str(size), '--height', str(size), '--scale', str(sc)] + extra, capture_output=True)

if __name__ == '__main__':
    os.makedirs('final', exist_ok=True)
    for name, ad in (('exact-apple', True), ('exact-custom', False)):
        render(write(name, apple_defaults=ad), name)
    print(path(SAID))
