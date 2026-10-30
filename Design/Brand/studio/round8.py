"""In the loop: a ring at the center of a 4 x 4 swatch with 90 degree symmetry, a concentric lens, an optional accent."""
import json, os, subprocess, textwrap, math
from kit import *
from c4 import configs
os.makedirs('r8', exist_ok=True)
cc = 2 * M; S0 = C - 2 * cc; W = cc / 4          # cell 128, radius 64, stroke 32
cfg = configs()
def arcs_of(g):
    return cell_arcs(g, x0=S0, cc=cc)
def dist_to_center(arcs, skip=(C, C)):
    best = 1e9
    for (vx, vy), d in arcs:
        if (vx, vy) == skip: continue
        # sample the quarter arc from its path endpoints: parse the M x y and end point
        import re
        nums = list(map(float, re.findall(r'-?\d+\.?\d*', d)))
        x0, y0, x1, y1 = nums[0], nums[1], nums[-2], nums[-1]
        a0, a1 = math.atan2(y0 - vy, x0 - vx), math.atan2(y1 - vy, x1 - vx)
        da = (a1 - a0 + math.pi) % (2 * math.pi) - math.pi
        for t in range(41):
            a = a0 + da * t / 40
            best = min(best, math.hypot(vx + cc / 2 * math.cos(a) - C, vy + cc / 2 * math.sin(a) - C))
    return best
ORANGE = ("display-p3:0.98000,0.40000,0.06000,1.00000", "display-p3:1.00000,0.50000,0.16000,1.00000")
BLUE = ("display-p3:0.10000,0.40000,0.95000,1.00000", "display-p3:0.36000,0.62000,1.00000,1.00000")
CL, CD = gray(1, 0.08), gray(1, 0.06)
def disc(r): return f'<circle cx="{C}" cy="{C}" r="{f(r)}" fill="#000"/>'
ideas = []
for gi in (1, 5):
    g = cfg[gi]; arcs = arcs_of(g)
    ring = ''.join(d for v, d in arcs if v == (C, C)); rest = ''.join(d for v, d in arcs if v != (C, C))
    dmin = dist_to_center(arcs)
    gap_in = dmin - W / 2               # inner edge of the surrounding lines
    ro = cc / 2 + W / 2                 # ring outer edge, 80
    print(gi, 'nearest line centerline', round(dmin, 2), 'its inner edge', round(gap_in, 2), 'ring outer', ro)
    lens_even = (ro + gap_in) / 2       # rim halfway between the ring and the loop around it
    lens_loupe = dmin + W / 2 + 16      # rim just beyond the surrounding loop's inner edge line
    def mk(key, title, pitch, lens_r, ring_fill=None, refract=(0.12, 0.12)):
        rl = L('ring', P(ring, W), glass=False, fill=ring_fill[0], dark=ring_fill[1]) if ring_fill else L('ring', P(ring, W), glass=False)
        write(key, [G([L('lens', disc(lens_r), fill=CL, dark=CD)], shadow=0.12, trans=0.9, refract=refract),
                    G([rl], glass=False, shadow=0, trans=0, spec=False),
                    G([L('lines', P(rest, W), glass=False)], glass=False, shadow=0, trans=0, spec=False)], folder='r8')
        ideas.append((key, title, pitch))
    n = 'A' if gi == 1 else 'B'
    mk(f'{n}-flat', f'{n}: flat', 'No glass. You at the center, one loop around you.', 1, refract=None)
    mk(f'{n}-even', f'{n}: lens, even', f'Lens rim halfway between you and the loop ({lens_even:.0f}).', lens_even)
    mk(f'{n}-loupe', f'{n}: loupe', f'Lens rim just past the loop ({lens_loupe:.0f}): the loop bends four ways at once.', lens_loupe)
    mk(f'{n}-orange', f'{n}: lens, you in orange', 'The only hue is the ring under the glass.', lens_even, ORANGE)
    mk(f'{n}-loupe-orange', f'{n}: loupe, orange', 'Loupe, with the hue under the glass.', lens_loupe, ORANGE)
    mk(f'{n}-blue', f'{n}: lens, you in blue', 'The same, in blue.', lens_even, BLUE)
json.dump(ideas, open('r8/ideas.json', 'w'), indent=1)
IC = "/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"
for key, _, _ in ideas:
    subprocess.run([IC, f'r8/{key}.icon', '--export-image', '--output-file', f'r8/{key}-Tinted.png', '--platform', 'iOS', '--rendition', 'TintedDark', '--width', '1024', '--height', '1024', '--scale', '1', '--tint-color', '0.6', '--tint-strength', '0.8'], capture_output=True)
# sheet per config: rows = ideas, columns = light, dark, tinted, 87 light, 87 dark
for n in ('A', 'B'):
    row = [i for i in ideas if i[0].startswith(n + '-')]
    body = ['<rect width="1800" height="1800" fill="#e6e6e6"/>']
    for k, (key, title, pitch) in enumerate(row):
        y = 12 + k * 296
        body.append(f'<text x="14" y="{y+22}" font-family="Helvetica Neue" font-size="19" font-weight="500" fill="#111">{title}</text>')
        for n2, line in enumerate(textwrap.wrap(pitch, 30)):
            body.append(f'<text x="14" y="{y+48+n2*20}" font-family="Helvetica Neue" font-size="14" fill="#555">{line}</text>')
        for j, m in enumerate(('Default', 'Dark', 'Tinted')):
            body.append(f'<rect x="{300+j*420}" y="{y}" width="290" height="290" fill="{"#f4f4f4" if m == "Default" else "#151517"}"/>')
            body.append(f'<image href="{key}-{m}.png" x="{305+j*420}" y="{y+5}" width="280" height="280"/>')
        body.append(f'<image href="{key}-Default-87.png" x="{300+3*420-100+40}" y="{y+40}" width="87" height="87"/>')
        body.append(f'<rect x="{300+3*420-100+30}" y="{y+150}" width="107" height="107" fill="#151517"/>')
        body.append(f'<image href="{key}-Dark-87.png" x="{300+3*420-100+40}" y="{y+160}" width="87" height="87"/>')
    open(f'r8/{n}.svg', 'w').write('<svg xmlns="http://www.w3.org/2000/svg" width="1800" height="1800" viewBox="0 0 1800 1800">' + ''.join(body) + '</svg>')
    subprocess.run(['qlmanage', '-t', '-s', '1800', '-o', 'r8', f'r8/{n}.svg'], capture_output=True)
