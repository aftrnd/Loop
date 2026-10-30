"""Crystal size: 256 (inscribed), 224, 192."""
import subprocess
from kit import *
from c4 import configs
from rounded import outlines
g = configs()[4]; cc = 2 * M; x0 = C - 2 * cc; w = cc / 4
lines, ring = outlines(g, x0, cc, w, w * 0.2174)
LINES, RING = ''.join(lines), ''.join(ring)
ORANGE = ("display-p3:0.98000,0.40000,0.06000,1.00000", "display-p3:1.00000,0.50000,0.16000,1.00000")
for rr in (256, 224, 192):
    write(f'crystal-{rr}', [G([L('lens', f'<circle cx="{C}" cy="{C}" r="{rr}" fill="#000"/>', fill=gray(1, 0.08), dark=gray(1, 0.06))], shadow=0.15, trans=0.9, refract=(0.15, 0.15)),
                         G([L('ring', f'<path d="{RING}" fill="#000" fill-rule="evenodd"/>', glass=False, fill=ORANGE[0], dark=ORANGE[1])], glass=False, shadow=0, trans=0, spec=False),
                         G([L('lines', f'<path d="{LINES}" fill="#000"/>', glass=False)], glass=False, shadow=0, trans=0, spec=False)], folder='r11')
body = ['<rect width="1800" height="1800" fill="#ececec"/><rect y="900" width="1800" height="900" fill="#151517"/>']
for k, rr in enumerate((256, 224, 192)):
    x = 20 + k * 600
    body.append(f'<text x="{x}" y="34" font-family="Helvetica Neue" font-size="22" font-weight="500" fill="#111">r {rr}{" (now)" if rr == 256 else ""}</text>')
    body.append(f'<image href="crystal-{rr}-Default.png" x="{x}" y="50" width="560" height="560"/>')
    body.append(f'<image href="crystal-{rr}-Default-87.png" x="{x}" y="640" width="87" height="87"/>')
    body.append(f'<image href="crystal-{rr}-Dark.png" x="{x}" y="920" width="560" height="560"/>')
    body.append(f'<image href="crystal-{rr}-Dark-87.png" x="{x}" y="1510" width="87" height="87"/>')
open('r11/size.svg', 'w').write('<svg xmlns="http://www.w3.org/2000/svg" width="1800" height="1800" viewBox="0 0 1800 1800">' + ''.join(body) + '</svg>')
subprocess.run(['qlmanage', '-t', '-s', '1800', '-o', 'r11', 'r11/size.svg'], capture_output=True)
