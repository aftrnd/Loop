"""c4-4, the counterclockwise pinwheel: refraction you can see, still symmetric."""
import json, os, subprocess, textwrap, math
from kit import *
from c4 import configs
from round8 import dist_to_center, ORANGE, disc, CL, CD, cc, S0, W
os.makedirs('r9', exist_ok=True)
g = configs()[4]
arcs = cell_arcs(g, x0=S0, cc=cc)
ring = ''.join(d for v, d in arcs if v == (C, C)); rest = ''.join(d for v, d in arcs if v != (C, C))
dmin = dist_to_center(arcs)
loupe = dmin + W / 2 + 16
print('c4-4', g, 'nearest line', round(dmin, 1), 'loupe', round(loupe, 1))
ideas = []
def mk(key, title, pitch, lens_r, refract, ring_fill=None, frost=False):
    rl = L('ring', P(ring, W), glass=False, fill=ring_fill[0], dark=ring_fill[1]) if ring_fill else L('ring', P(ring, W), glass=False)
    groups = [G([rl], glass=False, shadow=0, trans=0, spec=False), G([L('lines', P(rest, W), glass=False)], glass=False, shadow=0, trans=0, spec=False)]
    if lens_r:
        fl, fd = (gray(1, 0.3), gray(1, 0.1)) if frost else (CL, CD)
        groups.insert(0, G([L('lens', disc(lens_r), fill=fl, dark=fd)], shadow=0.15, trans=0.9, refract=refract))
    write(key, groups, folder='r9'); ideas.append((key, title, pitch))
mk('flat', 'Flat', 'The pinwheel, counterclockwise, no glass.', None, None)
mk('loupe', f'Loupe {loupe:.0f}, 0.15', 'Lens rim just past the nearest lines.', loupe, (0.15, 0.15))
mk('mid', 'Lens 2m, 0.15', 'A lens of radius 2m: half the swatch bends.', 2 * cc, (0.15, 0.15))
mk('crystal', 'Crystal, 0.15', 'A crystal inscribed in the swatch: everything bends, four ways alike.', 2 * cc, (0.15, 0.15))
mk('crystal12', 'Crystal, 0.12', 'The same crystal, a little gentler.', 2 * cc, (0.12, 0.12))
mk('loupe-o', 'Loupe, you in orange', 'The hue lives only under the glass.', loupe, (0.15, 0.15), ORANGE)
mk('crystal-o', 'Crystal, you in orange', 'Everything bends; you stay the one color.', 2 * cc, (0.15, 0.15), ORANGE)
mk('crystal-frost', 'Crystal, frosted', 'More body in the glass, so the lens itself reads.', 2 * cc, (0.15, 0.15), ORANGE, frost=True)
json.dump(ideas, open('r9/ideas.json', 'w'), indent=1)
IC = "/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"
for key, _, _ in ideas:
    subprocess.run([IC, f'r9/{key}.icon', '--export-image', '--output-file', f'r9/{key}-Tinted.png', '--platform', 'iOS', '--rendition', 'TintedDark', '--width', '1024', '--height', '1024', '--scale', '1', '--tint-color', '0.6', '--tint-strength', '0.8'], capture_output=True)
for half, part in (('a', ideas[:4]), ('b', ideas[4:])):
    body = ['<rect width="1800" height="1800" fill="#e6e6e6"/>']
    for k, (key, title, pitch) in enumerate(part):
        y = 12 + k * 445
        body.append(f'<text x="14" y="{y+24}" font-family="Helvetica Neue" font-size="20" font-weight="500" fill="#111">{title}</text>')
        for n2, line in enumerate(textwrap.wrap(pitch, 26)):
            body.append(f'<text x="14" y="{y+50+n2*20}" font-family="Helvetica Neue" font-size="14" fill="#555">{line}</text>')
        for j, m in enumerate(('Default', 'Dark', 'Tinted')):
            body.append(f'<rect x="{250+j*445}" y="{y}" width="430" height="430" fill="{"#f4f4f4" if m == "Default" else "#151517"}"/>')
            body.append(f'<image href="{key}-{m}.png" x="{255+j*445}" y="{y+5}" width="420" height="420"/>')
        body.append(f'<image href="{key}-Default-87.png" x="{250+3*445-130}" y="{y+60}" width="87" height="87"/>')
        body.append(f'<rect x="{250+3*445-140}" y="{y+180}" width="107" height="107" fill="#151517"/>')
        body.append(f'<image href="{key}-Dark-87.png" x="{250+3*445-130}" y="{y+190}" width="87" height="87"/>')
    open(f'r9/{half}.svg', 'w').write('<svg xmlns="http://www.w3.org/2000/svg" width="1800" height="1800" viewBox="0 0 1800 1800">' + ''.join(body) + '</svg>')
    subprocess.run(['qlmanage', '-t', '-s', '1800', '-o', 'r9', f'r9/{half}.svg'], capture_output=True)
