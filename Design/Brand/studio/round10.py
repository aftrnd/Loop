"""c4-4 with rounded ends (rho = stroke x 0.2174, the iOS corner ratio): icons and the flat logo."""
import json, os, subprocess
from kit import *
from c4 import configs
from rounded import outlines
os.makedirs('r10', exist_ok=True)
g = configs()[4]; cc = 2 * M; x0 = C - 2 * cc; w = cc / 4; rho = w * 0.2174
lines, ring = outlines(g, x0, cc, w, rho)
LINES = ''.join(lines); RING = ''.join(ring)
ORANGE = ("display-p3:0.98000,0.40000,0.06000,1.00000", "display-p3:1.00000,0.50000,0.16000,1.00000")
CL, CD = gray(1, 0.08), gray(1, 0.06)
lens = f'<circle cx="{C}" cy="{C}" r="{2 * cc}" fill="#000"/>'
def icon(key, ring_fill=None, crystal=True):
    rl = L('ring', f'<path d="{RING}" fill="#000" fill-rule="evenodd"/>', glass=False, **({'fill': ring_fill[0], 'dark': ring_fill[1]} if ring_fill else {}))
    groups = [G([rl], glass=False, shadow=0, trans=0, spec=False),
              G([L('lines', f'<path d="{LINES}" fill="#000"/>', glass=False)], glass=False, shadow=0, trans=0, spec=False)]
    if crystal:
        groups.insert(0, G([L('lens', lens, fill=CL, dark=CD)], shadow=0.15, trans=0.9, refract=(0.15, 0.15)))
    write(key, groups, folder='r10')
    IC = "/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"
    subprocess.run([IC, f'r10/{key}.icon', '--export-image', '--output-file', f'r10/{key}-Tinted.png', '--platform', 'iOS', '--rendition', 'TintedDark', '--width', '1024', '--height', '1024', '--scale', '1', '--tint-color', '0.6', '--tint-strength', '0.8'], capture_output=True)
    for r in ('Default', 'Dark'):
        subprocess.run([IC, f'r10/{key}.icon', '--export-image', '--output-file', f'r10/{key}-{r}-180.png', '--platform', 'iOS', '--rendition', r, '--width', '60', '--height', '60', '--scale', '3'], capture_output=True)
icon('crystal-o', ORANGE)
icon('crystal')
icon('flat-o', ORANGE, crystal=False)
# the flat logo as standalone SVG, cropped to the swatch (512 square), for the web
vb = f'{x0} {x0} {4 * cc} {4 * cc}'
for name, ink, you in (('logo-ink', '#0b0b0b', '#0b0b0b'), ('logo-white', '#ffffff', '#ffffff'), ('logo-ink-orange', '#0b0b0b', 'color(display-p3 0.98 0.4 0.06)')):
    open(f'r10/{name}.svg', 'w').write(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vb}"><path d="{LINES}" fill="{ink}"/><path d="{RING}" fill="{you}" fill-rule="evenodd"/></svg>')
json.dump({'lines': LINES, 'ring': RING, 'viewBox': vb, 'rho': rho}, open('r10/logo-paths.json', 'w'))
print('rho', round(rho, 3), 'viewBox', vb, 'chars', len(LINES) + len(RING))
