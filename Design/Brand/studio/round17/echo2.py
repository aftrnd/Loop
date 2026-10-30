"""Echo: a sine wave passes through a glass loop and comes back inverted.
Grid: wavelength 512 (the 50% keyline's diameter), amplitude 128 (one cell); crests, troughs and zero crossings sit on grid nodes."""
from waves import *
import sys

BG = ({"automatic-gradient": gray(0.45)}, {"solid": INK})

def wave_pts(lam=512, A=128, x0=128, x1=896, n=800, sign=1):
    return [(x0 + i * (x1 - x0) / n, 512 - sign * A * math.sin(2 * math.pi * (x0 + i * (x1 - x0) / n - 512) / lam)) for i in range(n + 1)]

def wave_el(c, t, **kw):
    pts = wave_pts(**kw)
    d = 'M' + 'L'.join(f'{f(x)} {f(y)}' for x, y in pts)
    caps = ''.join(f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(t / 2)}" fill="{c}"/>' for x, y in (pts[0], pts[-1]))
    return f'<path d="{d}" fill="none" stroke="{c}" stroke-width="{f(t)}"/>' + caps

def echo2(t=64, r=256, rim=0, light=WHITE, dark=WHITE, tr=0.5, **kw):
    disc = lambda c, rr=r: f'<circle cx="512" cy="512" r="{f(rr)}" fill="{c}"/>'
    # wave outside the loop; with a rim, it also runs under the glass rim before turning negative
    lower = (f'<defs><mask id="mb"><rect width="1024" height="1024" fill="#fff"/>{disc("#000", r - rim)}</mask></defs>'
             f'<g mask="url(#mb)">{wave_el("#000", t, **kw)}</g>')
    inner = (f'<defs><clipPath id="ci"><circle cx="512" cy="512" r="{f(r - rim)}"/></clipPath>'
             f'<mask id="mc"><rect width="1024" height="1024" fill="#fff"/><g clip-path="url(#ci)">{wave_el("#000", t, **kw)}</g></mask></defs>'
             f'<g mask="url(#mc)">{disc("#000")}</g>')
    return [dict(name='loop', body=inner, glass=True, light=light, dark=dark, group=0, trans=tr, shadow=0.3, refract=0.15),
            dict(name='wave', body=lower, glass=True, light=light, dark=dark, group=1, trans=tr, shadow=0.2, refract=0)]

V = {
  'e-t64': echo2(t=64), 'e-t77': echo2(t=76.8), 'e-t64-rim': echo2(t=64, rim=28), 'e-t77-rim': echo2(t=76.8, rim=28),
  'e-t51': echo2(t=51.2), 'e-ink': echo2(t=64, light=INK, dark=WHITE),
}
if __name__ == '__main__':
    for k, layers in V.items():
        write(k, layers, bg=BG if k != 'e-ink' else (WHITE, INK), renditions=('Default', 'Dark'), sizes=((512, 1, ''), (60, 3, '-180'), (29, 3, '-87')))
    print(' '.join(V))
