"""Social: a speech bubble (a circle with one squared corner as its tail) as the glass, over straight lines that it bends."""
from sound import *

RB = 409.6 / math.sqrt(2)          # tail tip lands on the 80% keyline

def bubble(cx=512, cy=512, r=RB, mirror=False):
    if not mirror:
        return (f'M{f(cx)} {f(cy - r)}A{f(r)} {f(r)} 0 0 1 {f(cx + r)} {f(cy)}A{f(r)} {f(r)} 0 0 1 {f(cx)} {f(cy + r)}'
                f'L{f(cx - r)} {f(cy + r)}L{f(cx - r)} {f(cy)}A{f(r)} {f(r)} 0 0 1 {f(cx)} {f(cy - r)}Z')
    return (f'M{f(cx)} {f(cy - r)}A{f(r)} {f(r)} 0 0 1 {f(cx + r)} {f(cy)}L{f(cx + r)} {f(cy + r)}L{f(cx)} {f(cy + r)}'
            f'A{f(r)} {f(r)} 0 0 1 {f(cx - r)} {f(cy)}A{f(r)} {f(r)} 0 0 1 {f(cx)} {f(cy - r)}Z')

def hlines(ys, x0, x1s, w=40):
    return ''.join(f'<rect x="{f(x0)}" y="{f(y - w / 2)}" width="{f(x1 - x0)}" height="{f(w)}" rx="{f(w / 2)}"/>' for y, x1 in zip(ys, x1s))

def glass_layer(body, refract=0.15, name='loop', group=0, light=CLEAR_L, dark=CLEAR_D):
    return dict(name=name, body=body, glass=True, light=light, dark=dark, tinted=gray(1, 0.1), group=group, trans=0.4, shadow=0.15, refract=refract)

def ink(body, name='marks', group=1):
    return dict(name=name, body=f'<g>{body}</g>', light=INK, dark=WHITE, group=group)

B0 = bubble()
V = {
  'A-bubble-bars': [glass_layer(f'<path d="{B0}"/>'), ink(bars(sinc_heights(H=640), w=40))],
  'B-bubble-text': [glass_layer(f'<path d="{B0}"/>'), ink(hlines([416, 512, 608], 128, [896, 768, 576]))],
  'C-two-bubbles': [glass_layer(f'<path d="{bubble(592, 592, 224, mirror=True)}"/>'), ink(f'<path d="{bubble(432, 432, 224)}"/>')],
  'D-bubble-of-bars': [glass_layer(f'<circle cx="512" cy="512" r="192"/>', refract=0.2),
                       ink(f'<defs><clipPath id="b"><path d="{B0}"/></clipPath></defs><g clip-path="url(#b)">{bars([1100] * 11, w=40)}</g>')],
}
if __name__ == '__main__':
    for k, layers in V.items():
        write(k, layers, renditions=('Default', 'Dark'), sizes=((512, 1, ''), (60, 3, '-180')))
    print(' '.join(V))
