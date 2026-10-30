from social import *

SMOKE_L, SMOKE_D = gray(0.04314, 0.16), gray(1, 0.14)
def g(body, refract=0.15, name='echo', group=0):
    return glass_layer(body, refract=refract, name=name, group=group, light=SMOKE_L, dark=SMOKE_D)

def bars_in(cx, cy, r, n=5, w=32, pitch=64, H=None):
    hs = [abs(sinc((i - n // 2) * 0.45)) for i in range(n)]
    H = H or r * 1.1
    x0 = cx - pitch * (n - 1) / 2
    return ''.join(f'<rect x="{f(x0 + i * pitch - w / 2)}" y="{f(cy - max(h * H, w) / 2)}" width="{f(w)}" height="{f(max(h * H, w))}" rx="{f(w / 2)}"/>' for i, h in enumerate(hs))

R = 224
V = {
  'C1-diagonal': [g(f'<path d="{bubble(592, 592, R, mirror=True)}"/>'), ink(f'<path d="{bubble(432, 432, R)}"/>')],
  'C2-facing': [g(f'<path d="{bubble(640, 512, R, mirror=True)}"/>'), ink(f'<path d="{bubble(384, 512, R)}"/>')],
  'C3-fading': [g(f'<path d="{bubble(640, 640, 128, mirror=True)}"/>', name='echo2'), g(f'<path d="{bubble(560, 560, 192, mirror=True)}"/>', name='echo1', group=1),
                ink(f'<path d="{bubble(432, 432, R)}"/>', group=2)],
  'C4-voice': [g(f'<path d="{bubble(592, 592, R, mirror=True)}"/>', refract=0.2),
               ink(f'<defs><mask id="m"><rect width="1024" height="1024" fill="#fff"/><g fill="#000">{bars_in(432, 432, R)}</g></mask></defs><path d="{bubble(432, 432, R)}" mask="url(#m)"/>')],
  'C5-diagonal-bars': [g(f'<path d="{bubble(592, 592, R, mirror=True)}"/>', refract=0.2),
               ink(f'<path d="{bubble(432, 432, R)}"/>' + f'<g>{bars_in(592, 592, R, n=5)}</g>')],
}
if __name__ == '__main__':
    for k, layers in V.items():
        write(k, layers, renditions=('Default', 'Dark'), sizes=((512, 1, ''), (60, 3, '-180')))
    print(' '.join(V))
