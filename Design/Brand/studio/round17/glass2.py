from waves import *
from glass1 import wheel_neg, circle_d
import iosmask

Q = iosmask.outline()            # the measured iOS icon outline, 1024 units

def tile_d(x0, y0, s):
    k = s / 1024
    return 'M' + 'L'.join(f'{f(x0 + x * k)} {f(y0 + y * k)}' for x, y in Q) + 'Z'

def xor_pair(base, cut, base_name, cut_name, refract=0.15, base_glass=False):
    """Two layers whose union is base XOR cut. base and cut are functions color -> SVG elements; the cut piece is the glass on top."""
    lower = (f'<defs><mask id="mb"><rect width="1024" height="1024" fill="#fff"/>{cut("#000")}</mask></defs>'
             f'<g mask="url(#mb)">{base("#000")}</g>')
    upper = (f'<defs><mask id="mc"><rect width="1024" height="1024" fill="#fff"/>{base("#000")}</mask></defs>'
             f'<g mask="url(#mc)">{cut("#000")}</g>')
    return [dict(name=cut_name, body=upper, glass=True, light=gray(0.04314, 1), dark=gray(1, 1), group=0, trans=0.25, shadow=0.3, refract=refract),
            dict(name=base_name, body=lower, glass=base_glass, light=gray(0.04314, 1), dark=gray(1, 1), group=1, trans=0.25, shadow=0.2, refract=0)]

def annulus(r0, r1):
    return circle_d(r1) + circle_d(r0, ccw=True)

def posts(gap, rc=256, w=102.4, span=(128, 896)):
    s = (span[1] - span[0] - gap) / 2
    tiles = ''.join(tile_d(x, y, s) for x in (span[0], span[0] + s + gap) for y in (span[0], span[0] + s + gap))
    return xor_pair(lambda c: f'<path d="{tiles}" fill="{c}"/>',
                    lambda c: f'<circle cx="512" cy="512" r="{f(rc)}" fill="none" stroke="{c}" stroke-width="{f(w)}"/>', 'tiles', 'loop', base_glass=True)

def echo(lam=512, A=102.4, t=102.4, r=256):
    pts = [(128 + i * 768 / 600, 512 - A * math.sin(2 * math.pi * (128 + i * 768 / 600 - 512) / lam)) for i in range(601)]
    d = 'M' + 'L'.join(f'{f(x)} {f(y)}' for x, y in pts)
    band = lambda c: f'<path d="{d}" fill="none" stroke="{c}" stroke-width="{f(t)}" stroke-linecap="round"/>'
    disc = lambda c: f'<circle cx="512" cy="512" r="{f(r)}" fill="{c}"/>'
    return xor_pair(band, disc, 'wave', 'lens')

V = {
  'posts-g48': posts(48), 'posts-g96': posts(96), 'posts-g128-r288': posts(128, rc=288),
  'echo-256': echo(), 'echo-205': echo(r=204.8), 'echo-thin': echo(t=76.8, A=89.6),
}
if __name__ == '__main__':
    for k, layers in V.items():
        write(k, layers, renditions=('Default', 'Dark'))
    print(' '.join(V))
