from waves import *
R = (K_OUT + K_MID) / 2
A = (K_OUT - K_MID) / 2 - W / 2
SMOKE, FROST = gray(0.04314, 0.45), gray(1, 0.5)

def arcpath(R, A, n, sign, t0, t1, phase=-math.pi / 2, steps=240):
    pts = []
    for i in range(steps + 1):
        t = t0 + (t1 - t0) * i / steps
        r = R + sign * A * math.sin(n * t)
        pts.append((C + r * math.cos(t + phase), C + r * math.sin(t + phase)))
    return 'M' + 'L'.join(f'{f(x)} {f(y)}' for x, y in pts)

def rstroke(d): return f'<path d="{d}" fill="none" stroke="#000" stroke-width="{f(W)}" stroke-linecap="round" stroke-linejoin="round"/>'

def woven(n, weave=True):
    # crossings at t = k pi / n; A is split at its antinodes so that A passes over B at odd crossings
    over, under = '', ''
    for k in range(2 * n):
        t0, t1 = (k - 0.5) * math.pi / n, (k + 0.5) * math.pi / n
        d = arcpath(R, A, n, 1, t0, t1)
        if weave and k % 2: over += d
        else: under += d
    layers = []
    if over: layers.append(dict(name='a-over', body=rstroke(over), group=0))
    layers.append(dict(name='b-glass', body=stroke(wave(R, A, n, -1)), glass=True, light=SMOKE, dark=FROST, group=1, trans=0.5, shadow=0.25))
    layers.append(dict(name='a-under', body=rstroke(under), group=2))
    return layers

D = json.load(open('wheel.json'))['mark']
def wheel_body(k=1.6):
    return f'<g transform="translate(512 512) scale({k}) translate(-512 -512)"><path d="{D["arms"]}"/><path d="{D["ring"]}"/></g>'

def wheel_neg(r, k=1.6):
    outside = f'<defs><clipPath id="o"><path d="M0 0H1024V1024H0Z{circle_d(r, ccw=True)}" clip-rule="evenodd"/></clipPath></defs><g clip-path="url(#o)">{wheel_body(k)}</g>'
    disc = (f'<defs><clipPath id="d"><circle cx="512" cy="512" r="{f(r)}"/></clipPath>'
            f'<mask id="m"><rect width="1024" height="1024" fill="#fff"/><g fill="#000">{wheel_body(k)}</g></mask></defs>'
            f'<g clip-path="url(#d)"><rect width="1024" height="1024" mask="url(#m)"/></g>')
    return [dict(name='disc', body=disc, glass=True, light=gray(0.04314, 1), dark=gray(1, 1), group=0, trans=0.2, shadow=0.3),
            dict(name='arms', body=outside, group=1)]

def circle_d(r, ccw=False):
    s = 0 if ccw else 1
    return f'M{f(C - r)} {C}A{f(r)} {f(r)} 0 1 {s} {f(C + r)} {C}A{f(r)} {f(r)} 0 1 {s} {f(C - r)} {C}Z'

V0 = {
  'woven-n4': woven(4), 'woven-n5': woven(5), 'woven-n6': woven(6), 'over-n4': woven(4, False),
  'wheel-neg-256': wheel_neg(256), 'wheel-neg-205': wheel_neg(204.8),
}
if __name__ == "__main__":
  for k, layers in V0.items():
    write(k, layers, renditions=('Default', 'Dark'))
  print(' '.join(V0))
