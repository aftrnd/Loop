from kit import *
import sys
off = int(sys.argv[1])
rings = ''.join(f'<circle cx="{C}" cy="{C}" r="{r}" fill="none" stroke="#000" stroke-width="1.2"/>' for r in range(192 + off, 257, 8))
write(f'cal2-{off}', [G([L('lens', f'<circle cx="{C}" cy="{C}" r="256" fill="#000"/>', fill=gray(1, 0.08), dark=gray(1, 0.06))], shadow=0, trans=0.9, refract=(0.15, 0.15)),
              G([L('rings', rings, glass=False)], glass=False, shadow=0, trans=0, spec=False)], folder='cal')
