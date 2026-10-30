"""Round 18: a short pulse (sinc envelope, the spectrum of a short sound) under a clear glass loop that bends the bars at its rim.
Bars on the 64 half-cell rhythm from grid line 1 to 7, width 40; peak height 640 (2.5 cells each way)."""
from sound import *

def lens(r, cx=512, cy=512): return f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r)}"/>'
P = bars(sinc_heights(H=640), w=40)
GRAYBG = ({"automatic-gradient": gray(0.45)}, {"solid": INK})
V = {
  'P1-pulse-lens320': doc(P, lens(320), 0.15),
  'P2-pulse-lens256': doc(P, lens(256), 0.15),
  'P3-echo-lens': doc(bars(sinc_heights(n=13, s=0.3, H=640), w=40), lens(160, cx=512 + 64 * 4.5), 0.25),
  'P4-pulse-lens320-gray': doc(P, lens(320), 0.15, ink_light=WHITE),
}
if __name__ == '__main__':
    for k, layers in V.items():
        write(k, layers, bg=GRAYBG if k.endswith('gray') else (WHITE, INK), renditions=('Default', 'Dark', 'TintedDark'), sizes=((512, 1, ''), (60, 3, '-180')))
    print(' '.join(V))
