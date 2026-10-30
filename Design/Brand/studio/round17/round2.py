from waves import *
from glass1 import wheel_body

BG = ({"automatic-gradient": gray(0.45)}, {"solid": INK})

def sine(c, t, A=128, lam=512, x0=128, x1=896, sign=1, caps=True, rot=0):
    pts = [(x0 + i * (x1 - x0) / 800, 512 - sign * A * math.sin(2 * math.pi * (x0 + i * (x1 - x0) / 800 - 512) / lam)) for i in range(801)]
    d = 'M' + 'L'.join(f'{f(x)} {f(y)}' for x, y in pts)
    cap = ''.join(f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(t / 2)}"/>' for x, y in (pts[0], pts[-1])) if caps else ''
    return f'<g fill="{c}" transform="rotate({rot} 512 512)"><path d="{d}" fill="none" stroke="{c}" stroke-width="{f(t)}"/>{cap}</g>'

def pair(out_el, in_el, cut_el, glass_only_cut=False):
    """lower: the outside mark, minus the cut shape. upper: the cut shape (glass), minus the inside mark."""
    lower = f'<defs><mask id="mb"><rect width="1024" height="1024" fill="#fff"/>{cut_el("#000")}</mask></defs><g mask="url(#mb)">{out_el("#000")}</g>'
    upper = f'<defs><mask id="mc"><rect width="1024" height="1024" fill="#fff"/>{in_el("#000")}</mask></defs><g mask="url(#mc)">{cut_el("#000")}</g>'
    return [dict(name='loop', body=upper, glass=True, light=WHITE, dark=WHITE, group=0, trans=0.5, shadow=0.3, refract=0.15),
            dict(name='mark', body=lower, glass=True, light=WHITE, dark=WHITE, group=1, trans=0.5, shadow=0.2, refract=0)]

disc = lambda r: (lambda c: f'<circle cx="512" cy="512" r="{f(r)}" fill="{c}"/>')
ring = lambda r, w: (lambda c: f'<circle cx="512" cy="512" r="{f(r)}" fill="none" stroke="{c}" stroke-width="{f(w)}"/>')
T = 64
V = {
  'E1-base':      pair(lambda c: sine(c, T), lambda c: sine(c, T), disc(256)),
  'E2-reflected': pair(lambda c: sine(c, T), lambda c: sine(c, T, sign=-1, caps=False), disc(256)),
  'E3-magnified': pair(lambda c: sine(c, T, A=64), lambda c: sine(c, T, A=128, caps=False), disc(256)),
  'E4-ring':      pair(lambda c: sine(c, T), lambda c: sine(c, T), ring(256, 102.4)),
  'E5-diagonal':  pair(lambda c: sine(c, T, rot=-45), lambda c: sine(c, T, rot=-45), disc(256)),
  'E6-inside':    pair(lambda c: '', lambda c: sine(c, T, x0=256, x1=768, caps=False), disc(256)),
  'W1-wheel':     [dict(name='wheel', body=f'<g fill="#000">{wheel_body(1.6)}</g>', glass=True, light=WHITE, dark=WHITE, group=0, trans=0.5, shadow=0.3, refract=0)],
  'W2-neg256':    pair(lambda c: f'<g fill="{c}">{wheel_body(1.6)}</g>', lambda c: f'<g fill="{c}">{wheel_body(1.6)}</g>', disc(256)),
  'W3-neg205':    pair(lambda c: f'<g fill="{c}">{wheel_body(1.6)}</g>', lambda c: f'<g fill="{c}">{wheel_body(1.6)}</g>', disc(204.8)),
}
if __name__ == '__main__':
    for k, layers in V.items():
        write(k, layers, bg=BG, renditions=('Default', 'Dark', 'TintedDark'), sizes=((512, 1, ''), (60, 3, '-180'), (29, 3, '-87')))
    print(' '.join(V))
