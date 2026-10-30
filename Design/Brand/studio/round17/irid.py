"""Iridescence studies on the echo: a soap-film rim or a dispersion fringe, baked as a separate layer above the glass."""
import colorsys, json, math, os, shutil, subprocess, sys
import final
U = final.U
final.R = 7.5 * U
d = 6.5 / 2 * U
final.SAID = (512 - d, 512 - d - U / 4)
final.ECHO = (512 + d, 512 + d - U / 4)
IC = final.IC
SRC = '/Users/nick/Library/CloudStorage/Dropbox/Developer/Xcode/Loop/loop-icon.icon'

def echo_outline(n=900):
    O = final.ECHO; g = final.geometry(O); R = final.R
    def arcpts(K, r, p, q, cw, m):
        a = math.atan2(p[1]-K[1], p[0]-K[0]); b = math.atan2(q[1]-K[1], q[0]-K[0])
        dd = (b - a) % (2*math.pi)
        if not cw: dd -= 2*math.pi
        return [(K[0]+r*math.cos(a+dd*i/m), K[1]+r*math.sin(a+dd*i/m)) for i in range(m)]
    pts = arcpts(O, R, g['P1'], g['Si'], True, n) + arcpts(g['Ki'], g['ri'], g['Si'], g['Qi'], False, n // 8) + arcpts(g['T'], g['rt'], g['Qi'], g['P2'], True, n // 8)
    pts += [(g['P2'][0] + (g['P1'][0]-g['P2'][0])*i/40, g['P2'][1] + (g['P1'][1]-g['P2'][1])*i/40) for i in range(40)]
    return [(2*O[0]-x, y) for x, y in pts]    # mirrored like the echo

def offset(pts, dist):
    """Offset a closed outline along its inward normals (negative = outward)."""
    out = []; n = len(pts)
    cx = sum(p[0] for p in pts) / n; cy = sum(p[1] for p in pts) / n
    for i in range(n):
        (x0, y0), (x1, y1) = pts[i - 3], pts[(i + 3) % n]
        tx, ty = x1 - x0, y1 - y0; L = math.hypot(tx, ty) or 1
        nx, ny = -ty / L, tx / L
        if (cx - pts[i][0]) * nx + (cy - pts[i][1]) * ny < 0: nx, ny = -nx, -ny
        out.append((pts[i][0] + nx * dist, pts[i][1] + ny * dist))
    return out

def hexc(h, s, l):
    r, g, b = colorsys.hls_to_rgb(h % 1, l, s); return '#%02x%02x%02x' % (int(r*255), int(g*255), int(b*255))

def segs(pts, width, color_at, opacity=1):
    O = final.ECHO; out = []
    for i in range(len(pts)):
        p, q = pts[i], pts[(i + 1) % len(pts)]
        ang = math.atan2((p[1] + q[1]) / 2 - O[1], (p[0] + q[0]) / 2 - O[0])
        out.append(f'<line x1="{p[0]:.2f}" y1="{p[1]:.2f}" x2="{q[0]:.2f}" y2="{q[1]:.2f}" stroke="{color_at(ang)}" stroke-width="{width}" stroke-linecap="round" stroke-opacity="{opacity}"/>')
    return ''.join(out)

def film(width=14, inset=9, sat=0.75, light=0.62, cycles=2, phase=0.55):
    pts = offset(echo_outline(), inset)
    return segs(pts, width, lambda a: hexc(cycles * a / (2 * math.pi) + phase, sat, light))

def dispersion(gap=4.5, width=5, warm=('#ff7a3d', '#ff3f86'), cool=('#2fc8ff', '#6b6bff')):
    base = echo_outline()
    lit = lambda a: 0.5 + 0.5 * math.cos(a - math.radians(-135))     # strongest toward the light (top left) and fading away
    def grad(c0, c1):
        def f(a):
            t = (math.sin(a) + 1) / 2
            r0, g0, b0 = (int(c0[i:i+2], 16) for i in (1, 3, 5)); r1, g1, b1 = (int(c1[i:i+2], 16) for i in (1, 3, 5))
            return '#%02x%02x%02x' % (int(r0 + (r1 - r0) * t), int(g0 + (g1 - g0) * t), int(b0 + (b1 - b0) * t))
        return f
    return segs(offset(base, -gap), width, grad(*warm)) + segs(offset(base, gap + 2), width, grad(*cool))

def build(name, body, blend, opacity, out='irid'):
    doc = f'{out}/{name}.icon'
    shutil.rmtree(doc, ignore_errors=True); shutil.copytree(SRC, doc)
    open(f'{doc}/Assets/sheen.svg', 'w').write(f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">{body}</svg>')
    j = json.load(open(f'{doc}/icon.json'))
    layer = {"name": "sheen", "image-name": "sheen.svg", "glass": False, "blend-mode": blend,
             "opacity-specializations": [{"value": opacity}],
             "hidden-specializations": [{"value": False}, {"appearance": "tinted", "value": True}]}
    j['groups'].insert(0, {"name": "Sheen", "layers": [layer], "shadow": {"kind": "none", "opacity": 0}, "specular": False,
                           "translucency": {"enabled": False, "value": 0}})
    open(f'{doc}/icon.json', 'w').write(json.dumps(j, indent=2, sort_keys=True, separators=(',', ' : ')))
    for r in ('Default', 'Dark'):
        subprocess.run([IC, doc, '--export-image', '--output-file', f'{out}/{name}-{r}.png', '--platform', 'iOS', '--rendition', r,
                        '--width', '1024', '--height', '1024', '--scale', '1'], capture_output=True)
        subprocess.run([IC, doc, '--export-image', '--output-file', f'{out}/{name}-{r}-180.png', '--platform', 'iOS', '--rendition', r,
                        '--width', '60', '--height', '60', '--scale', '3'], capture_output=True)

if __name__ == '__main__':
    os.makedirs('irid', exist_ok=True)
    build('film-soft', film(), 'soft-light', 0.9)
    build('film-plus', film(light=0.55), 'plus-lighter', 0.35)
    build('film-normal', film(), 'normal', 0.45)
    build('disp-plus', dispersion(), 'plus-lighter', 0.6)
    build('disp-normal', dispersion(), 'normal', 0.55)
