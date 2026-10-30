"""Wordmark construction: every letter is the icon's ring, part of it, or a straight stem.

Units: the stroke w is 1. The ring has centerline radius r (2 in the icon: arc radius 64, stroke 32),
so the x-height is 2r + w. Flat ends carry corner fillets of w * 0.2174, the icon's line-end ratio.
Coordinates are y-down with the baseline at y = 0. Shapes wind clockwise and holes counterclockwise,
so one nonzero path is the union of every part.
"""
import math

RHO = 0.2174
f = lambda v: ('%.3f' % v).rstrip('0').rstrip('.')


def rect(x0, y0, x1, y1, rho, corners='1111'):
    """Clockwise rectangle; corners flags (top left, top right, bottom right, bottom left), 1 filleted."""
    rho = min(rho, (x1 - x0) / 2, (y1 - y0) / 2)
    k = [rho if c == '1' else 0 for c in corners]
    a = lambda r, x, y: f'A{f(r)} {f(r)} 0 0 1 {f(x)} {f(y)}' if r else ''
    return (f'M{f(x0 + k[0])} {f(y0)}L{f(x1 - k[1])} {f(y0)}' + a(k[1], x1, y0 + k[1]) + f'L{f(x1)} {f(y1 - k[2])}' + a(k[2], x1 - k[2], y1)
            + f'L{f(x0 + k[3])} {f(y1)}' + a(k[3], x0, y1 - k[3]) + f'L{f(x0)} {f(y0 + k[0])}' + a(k[0], x0 + k[0], y0) + 'Z')


def circle(cx, cy, R, cw=True):
    s = 1 if cw else 0
    return f'M{f(cx - R)} {f(cy)}A{f(R)} {f(R)} 0 1 {s} {f(cx + R)} {f(cy)}A{f(R)} {f(R)} 0 1 {s} {f(cx - R)} {f(cy)}Z'


def ring(cx, cy, r, w):
    return circle(cx, cy, r + w / 2) + circle(cx, cy, r - w / 2, cw=False)


def band(cx, cy, r, w, a0, a1, rho, rho0=None, rho1=None):
    """Annular sector from screen angle a0 to a1 (degrees, clockwise), flat ends with exact fillets."""
    Ro, Ri = r + w / 2, r - w / 2
    rho0 = rho if rho0 is None else rho0
    rho1 = rho if rho1 is None else rho1
    def corner(a, R, outer, end):
        rho = rho1 if end else rho0
        if rho == 0:
            u = (math.cos(math.radians(a)), math.sin(math.radians(a)))
            p = (cx + R * u[0], cy + R * u[1])
            return p, p
        u = (math.cos(math.radians(a)), math.sin(math.radians(a)))
        t = (-u[1], u[0])
        n = (-t[0], -t[1]) if end else t
        dist = R - rho if outer else R + rho
        x = math.sqrt(dist ** 2 - rho ** 2)
        Cc = (cx + x * u[0] + rho * n[0], cy + x * u[1] + rho * n[1])
        Tc = (cx + (Cc[0] - cx) * R / dist, cy + (Cc[1] - cy) * R / dist)
        Tl = (cx + x * u[0], cy + x * u[1])
        return Tc, Tl
    large = 1 if (a1 - a0) % 360 > 180 else 0
    o0, o1, i1, i0 = corner(a0, Ro, True, False), corner(a1, Ro, True, True), corner(a1, Ri, False, True), corner(a0, Ri, False, False)
    P = lambda p: f'{f(p[0])} {f(p[1])}'
    fil = lambda p, r: f'A{f(r)} {f(r)} 0 0 1 {P(p)}' if r else ''
    return (f'M{P(o0[0])}A{f(Ro)} {f(Ro)} 0 {large} 1 {P(o1[0])}' + fil(o1[1], rho1) + f'L{P(i1[1])}' + fil(i1[0], rho1)
            + f'A{f(Ri)} {f(Ri)} 0 {large} 0 {P(i0[0])}' + fil(i0[1], rho0) + f'L{P(o0[1])}' + fil(o0[0], rho0) + 'Z')


class Spec:
    def __init__(self, r=2.0, w=1.0, asc=3.0, desc=3.0, track=1.0, foot=False, tail=False, stencil=False,
                 cap_l=False, l_bar=None, overshoot=0.0):
        self.r, self.w, self.asc, self.desc, self.track = r, w, asc, desc, track
        self.foot, self.tail, self.stencil, self.cap_l, self.l_bar, self.overshoot = foot, tail, stencil, cap_l, l_bar, overshoot
        self.R = r + w / 2
        self.X = 2 * self.R
        self.rho = w * RHO


def glyph_l(s, x):
    """Returns (path, right edge, right kind). Stem, optionally ending in a quarter of the ring (a foot)."""
    top = -(s.X + s.asc)
    if not s.foot:
        return rect(x, top, x + s.w, 0, s.rho), x + s.w, 'stem'
    cx, cy = x + s.w / 2 + s.r, -s.R
    d = rect(x, top, x + s.w, cy, s.rho, '1100')
    if s.l_bar:
        d += band(cx, cy, s.r, s.w, 90, 180, s.rho, 0, 0) + rect(cx, -s.w, cx + s.l_bar, 0, s.rho, '0110')
        return d, cx + s.l_bar, 'foot'
    d += band(cx, cy, s.r, s.w, 90, 180, s.rho, 0, s.rho)
    end = cx
    return d, end, 'foot'


def glyph_o(s, x, cut=False):
    cx, cy = x + s.R, -s.R
    R = s.R + s.overshoot
    if not s.stencil:
        return circle(cx, cy, R) + circle(cx, cy, s.r - s.w / 2, cw=False), x + 2 * s.R
    g = s.w * 0.18
    d = ''
    for a in (0, 90, 180, 270):
        da = math.degrees(g / 2 / s.r)
        d += band(cx, cy, s.r, s.w, a + da, a + 90 - da, s.rho * 0.5)
    return d, x + 2 * s.R


def glyph_p(s, x):
    cx, cy = x + s.R, -s.R
    d = circle(cx, cy, s.R + s.overshoot) + circle(cx, cy, s.r - s.w / 2, cw=False)
    top = cy if s.tail else -s.X
    d += rect(x, top, x + s.w, s.desc, s.rho, '0011' if s.tail else '1111')
    return d, x + 2 * s.R


def word(s, text='loop'):
    """Lays out the word with optical gaps: round to round g, stem or foot to round 1.2 g."""
    g = s.w * s.track
    x, d, prev = 0.0, '', None
    for ch in text:
        if ch in 'lL':
            p, right, kind = glyph_l(s, x)
            d += p; x = right; prev = kind
        else:
            gap = g if prev == 'round' else (g * 1.2 if prev == 'stem' else g * 0.9)
            x += gap
            p, right = glyph_o(s, x) if ch == 'o' else glyph_p(s, x)
            d += p; x = right; prev = 'round'
    top, bottom = -(s.X + s.asc), s.desc
    return d, (0, top, x, bottom)
