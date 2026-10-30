from sound import *

def lens(r, cx=512, cy=512): return f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r)}"/>'
V = {
  'V1-w32-r256': doc(bars(sinc_heights()), lens(256), 0.15),
  'V2-w40-r256': doc(bars(sinc_heights(), w=40), lens(256), 0.15),
  'V3-w40-r256-25': doc(bars(sinc_heights(), w=40), lens(256), 0.25),
  'V4-w40-r192': doc(bars(sinc_heights(), w=40), lens(192), 0.2),
  'V5-grille': doc(bars(grille(r=384), w=32), lens(256), 0.15),
  'V6-sine': doc(bars(sine_heights(H=576), w=40), lens(256), 0.15),
  'V7-echo-lens': doc(bars(sinc_heights(n=13, s=0.3), w=40), lens(160, cx=512 + 64 * 4.5), 0.25),
  'V8-w40-r320': doc(bars(sinc_heights(H=704), w=40), lens(320), 0.15),
}
if __name__ == '__main__':
    for k, layers in V.items():
        write(k, layers, renditions=('Default', 'Dark'), sizes=((512, 1, ''), (60, 3, '-180')))
    print(' '.join(V))
