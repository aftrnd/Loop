"""Sound bars under a clear glass loop. Bars on the 64 half-cell rhythm of Apple's 8 x 8 icon grid."""
from waves import *
import sys

CLEAR_L, CLEAR_D = gray(1, 0.12), gray(1, 0.08)

def sinc(u): return 1.0 if u == 0 else math.sin(math.pi * u) / (math.pi * u)

def bars(heights, w=32, pitch=64):
    n = len(heights); x0 = 512 - pitch * (n - 1) / 2
    out = ''
    for i, h in enumerate(heights):
        h = max(h, w)
        out += f'<rect x="{f(x0 + i * pitch - w / 2)}" y="{f(512 - h / 2)}" width="{f(w)}" height="{f(h)}" rx="{f(w / 2)}"/>'
    return out

def sinc_heights(n=13, H=640, s=0.35):
    return [H * abs(sinc((i - n // 2) * s)) for i in range(n)]

def sine_heights(n=13, H=640, lam=512, pitch=64):
    return [H * abs(math.cos(2 * math.pi * (i - n // 2) * pitch / lam)) for i in range(n)]

def grille(n=13, r=384, pitch=64):
    # straight slots clipped to a circle: each bar spans the chord at its x
    hs = []
    for i in range(n):
        x = (i - n // 2) * pitch
        hs.append(2 * math.sqrt(max(r * r - x * x, 0)))
    return hs

def glass_disc(r): return f'<circle cx="512" cy="512" r="{f(r)}"/>'
def glass_ring(r, w): return f'<circle cx="512" cy="512" r="{f(r)}" fill="none" stroke="#000" stroke-width="{f(w)}"/>'

def doc(bar_body, glass_body, refract, ink_light=INK, bg=(WHITE, INK), trans=0.4):
    return [dict(name='loop', body=glass_body, glass=True, light=CLEAR_L, dark=CLEAR_D, tinted=gray(1, 0.1), group=0, trans=trans, shadow=0.15, refract=refract),
            dict(name='sound', body=f'<g>{bar_body}</g>', light=ink_light, dark=WHITE, group=1)]

V = {
  'S1-sinc-disc15': doc(bars(sinc_heights()), glass_disc(256), 0.15),
  'S2-sinc-disc35': doc(bars(sinc_heights()), glass_disc(256), 0.35),
  'S3-sinc-disc60': doc(bars(sinc_heights()), glass_disc(256), 0.6),
  'S4-sinc-ring35': doc(bars(sinc_heights()), glass_ring(256, 112), 0.35),
  'S5-sine-ring35': doc(bars(sine_heights()), glass_ring(256, 112), 0.35),
  'S6-grille-disc35': doc(bars(grille(), w=28), glass_disc(256), 0.35),
}
if __name__ == '__main__':
    for k, layers in V.items():
        write(k, layers, renditions=('Default', 'Dark'), sizes=((512, 1, ''), (60, 3, '-180'), (29, 3, '-87')))
    print(' '.join(V))
