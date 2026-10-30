"""Said and echoed: a speech bubble in ink and its echo, the same bubble mirrored in smoked glass."""
from social2 import *

def bub(cx, cy, r, corner='bl', rc=0):
    top, right, bottom, left = (cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)
    corners = {'tr': (cx + r, cy - r), 'br': (cx + r, cy + r), 'bl': (cx - r, cy + r), 'tl': (cx - r, cy - r)}
    seq = [('tr', top, right), ('br', right, bottom), ('bl', bottom, left), ('tl', left, top)]
    d = f'M{f(top[0])} {f(top[1])}'
    for name, a, b in seq:
        if name == corner:
            kx, ky = corners[name]
            if rc:
                # round the tail tip: approach along a's edge, quarter arc, leave along b's edge
                ax, ay = kx + (a[0] - kx and math.copysign(rc, a[0] - kx)), ky + (a[1] - ky and math.copysign(rc, a[1] - ky))
                bx, by = kx + (b[0] - kx and math.copysign(rc, b[0] - kx)), ky + (b[1] - ky and math.copysign(rc, b[1] - ky))
                d += f'L{f(ax)} {f(ay)}A{f(rc)} {f(rc)} 0 0 1 {f(bx)} {f(by)}L{f(b[0])} {f(b[1])}'
            else:
                d += f'L{f(kx)} {f(ky)}L{f(b[0])} {f(b[1])}'
        else:
            d += f'A{f(r)} {f(r)} 0 0 1 {f(b[0])} {f(b[1])}'
    return d + 'Z'

def pair(said, echo, refract=0.15, xor=False):
    if xor:
        said_body = (f'<defs><mask id="m"><rect width="1024" height="1024" fill="#fff"/><path d="{echo}" fill="#000"/></mask></defs>'
                     f'<path d="{said}" mask="url(#m)"/>')
        echo_body = (f'<defs><mask id="n"><rect width="1024" height="1024" fill="#fff"/><path d="{said}" fill="#000"/></mask></defs>'
                     f'<path d="{echo}" mask="url(#n)"/>')
        return [g(echo_body, refract=refract), ink(said_body)]
    return [g(f'<path d="{echo}"/>', refract=refract), ink(f'<path d="{said}"/>')]

V = {
  'R0-round19': pair(bub(432, 432, 224), bub(592, 592, 224, 'br')),
  'R1-grid': pair(bub(384, 384, 256), bub(640, 640, 256, 'br')),
  'R2-quieter': pair(bub(432, 432, 256), bub(656, 656, 192, 'br')),
  'R3-points-back': pair(bub(400, 400, 240), bub(624, 624, 240, 'tl')),
  'R4-negative': pair(bub(384, 384, 256), bub(640, 640, 256, 'br'), xor=True),
  'R5-refract25': pair(bub(384, 384, 256), bub(640, 640, 256, 'br'), refract=0.25),
  'R6-soft-tail': pair(bub(384, 384, 256, rc=32), bub(640, 640, 256, 'br', rc=32)),
  'R7-same-way': pair(bub(384, 384, 256), bub(640, 640, 256, 'bl')),
}
if __name__ == '__main__':
    for k, layers in V.items():
        write(k, layers, renditions=('Default', 'Dark'), sizes=((512, 1, ''), (60, 3, '-180')))
    print(' '.join(V))
