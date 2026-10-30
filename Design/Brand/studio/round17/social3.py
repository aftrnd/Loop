from social2 import *
V = {
  'A2-bubble-bars': [g(f'<path d="{bubble(528, 496)}"/>'), ink(bars(sinc_heights(n=11, H=560, s=0.4), w=40))],
}
if __name__ == '__main__':
    for k, layers in V.items():
        write(k, layers, renditions=('Default', 'Dark', 'TintedDark'), sizes=((512, 1, ''), (60, 3, '-180')))
