from kit import *
rings = ''.join(f'<circle cx="{C}" cy="{C}" r="{r}" fill="none" stroke="#000" stroke-width="2"/>' for r in range(16, 417, 16))
write('cal', [G([L('lens', f'<circle cx="{C}" cy="{C}" r="256" fill="#000"/>', fill=gray(1, 0.08), dark=gray(1, 0.06))], shadow=0, trans=0.9, refract=(0.15, 0.15)),
              G([L('rings', rings, glass=False)], glass=False, shadow=0, trans=0, spec=False)], folder='cal')
write('cal-flat', [G([L('rings', rings, glass=False)], glass=False, shadow=0, trans=0, spec=False)], folder='cal')
