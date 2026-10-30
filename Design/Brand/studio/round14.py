"""Round fourteen: refraction as the idea, not a garnish. Each concept uses the glass differently on the Wheel."""
import json, os, shutil, subprocess
from round12 import IC, gray
from round13 import outline, arcs_within, reach
from wordmark import ring, circle

INK, WHITE = gray(0.04314), gray(1)
OUT = '../round14'
SVG = lambda body: f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">{body}</svg>'
WHEEL = outline([a for a in arcs_within(230.8) if reach(a) > 64.5])
FIELD = outline([a for a in arcs_within(320) if reach(a) > 64.5])
RING = ring(512, 512, 64, 32)
disc = lambda r: f'<circle cx="512" cy="512" r="{r}" fill="#000"/>'
annulus = lambda r0, r1: f'<path d="{circle(512, 512, r1)}{circle(512, 512, r0, cw=False)}" fill="#000"/>'
path = lambda d: f'<path d="{d}" fill="#000"/>'


def layer(name, body, light=INK, dark=WHITE, glass=False):
    return dict(name=name, body=body, light=light, dark=dark, glass=glass)


def glass(name, body, light=gray(1, 0.08), dark=gray(1, 0.06), refract=0.15, shadow=0.15, trans=0.9):
    return dict(layers=[layer(name, body, light, dark, True)], glass=True, refract=refract, shadow=shadow, trans=trans)


def flat(*layers):
    return dict(layers=list(layers), glass=False)


def write(name, groups, scale=4 / 3):
    out = f'{OUT}/{name}.icon'
    shutil.rmtree(out, ignore_errors=True); os.makedirs(f'{out}/Assets')
    gs = []
    for g in groups:
        ls = []
        for l in g['layers']:
            open(f"{out}/Assets/{l['name']}.svg", 'w').write(SVG(l['body']))
            ls.append({"name": l['name'], "image-name": f"{l['name']}.svg", "glass": l['glass'],
                       "fill-specializations": [{"value": {"solid": l['light']}}, {"appearance": "dark", "value": {"solid": l['dark']}},
                                                {"appearance": "tinted", "value": {"solid": WHITE}}],
                       "opacity-specializations": [{"value": 1}], "position": {"scale": scale, "translation-in-points": [0, 0]}})
        grp = {"layers": ls, "lighting": "individual"}
        if g['glass']:
            grp.update({"shadow": {"kind": "neutral", "opacity": g['shadow']}, "specular": True,
                        "translucency": {"enabled": True, "value": g['trans']}})
            if g['refract']:
                grp["refractivity"] = {"enabled": True, "depth": g['refract'], "strength": g['refract']}
        else:
            grp.update({"shadow": {"kind": "none", "opacity": 0}, "specular": False, "translucency": {"enabled": False, "value": 0}})
        gs.append(grp)
    json.dump({"fill-specializations": [{"value": {"solid": WHITE}}, {"appearance": "dark", "value": {"solid": INK}}],
               "groups": gs, "supported-platforms": {"squares": "shared"}}, open(f'{out}/icon.json', 'w'), indent=2)
    for r in ('Default', 'Dark'):
        for size, sc, tag in ((1024, 1, ''), (60, 3, '-180')):
            subprocess.run([IC, out, '--export-image', '--output-file', f'{OUT}/{name}-{r}{tag}.png', '--platform', 'iOS', '--rendition', r,
                            '--width', str(size), '--height', str(size), '--scale', str(sc)], capture_output=True)


CONCEPTS = [
    ('a-marble', 'Marble (control)', [glass('lens', disc(224)), flat(layer('ring', path(RING))), flat(layer('lines', path(WHEEL)))]),
    ('b-marble-body', 'Marble with a body', [glass('lens', disc(224), gray(1, 0.45), gray(1, 0.14), shadow=0.5, trans=0.6),
                                             flat(layer('ring', path(RING))), flat(layer('lines', path(WHEEL)))]),
    ('c-ring-on-marble', 'Ring floating on the marble', [flat(layer('ring', path(RING))), glass('lens', disc(224), gray(1, 0.3), gray(1, 0.12), shadow=0.5),
                                                         flat(layer('lines', path(WHEEL)))]),
    ('d-glass-loop', 'Glass loop (the ring is glass)', [glass('loop', annulus(56, 168), gray(1, 0.3), gray(1, 0.12), shadow=0.5, trans=0.7),
                                                        flat(layer('lines', path(WHEEL)))]),
    ('e-glass-loop-wide', 'Glass loop, wide band', [glass('loop', annulus(48, 208), gray(1, 0.25), gray(1, 0.1), shadow=0.5, trans=0.7),
                                                    flat(layer('lines', path(WHEEL)))]),
    ('f-glass-over-ring', 'Glass torus over the ring', [glass('loop', annulus(32, 160), gray(1, 0.12), gray(1, 0.08), shadow=0.4),
                                                        flat(layer('ring', path(RING))), flat(layer('lines', path(WHEEL)))]),
    ('g-field', 'The field and the loop', [glass('lens', disc(256), gray(1, 0.1), gray(1, 0.06), shadow=0.4), flat(layer('ring', path(RING))),
                                           flat(layer('lines', path(WHEEL))), flat(layer('field', path(FIELD), gray(0.84), gray(0.24)))]),
    ('h-field-loop', 'Field under a glass loop', [glass('loop', annulus(96, 256), gray(1, 0.1), gray(1, 0.06), shadow=0.4), flat(layer('ring', path(RING))),
                                                  flat(layer('lines', path(FIELD)))]),
]

if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for key, _, groups in CONCEPTS:
        write(key, groups)
    for mode, bg, fg in (('Default', '#e9e9eb', '#111'), ('Dark', '#151517', '#eee')):
        body = [f'<rect width="1800" height="1800" fill="{bg}"/>']
        for k, (key, title, _) in enumerate(CONCEPTS):
            x, y = 12 + (k % 4) * 447, 10 + (k // 4) * 895
            body.append(f'<text x="{x}" y="{y+22}" font-family="Helvetica Neue" font-size="18" font-weight="500" fill="{fg}">{title}</text>')
            body.append(f'<image href="{key}-{mode}.png" x="{x}" y="{y+36}" width="425" height="425"/>')
            body.append(f'<image href="{key}-{mode}-180.png" x="{x}" y="{y+480}" width="180" height="180"/>')
            body.append(f'<image href="{key}-{mode}-180.png" x="{x+200}" y="{y+480}" width="87" height="87"/>')
            body.append(f'<image href="{key}-{mode}-180.png" x="{x+200}" y="{y+585}" width="60" height="60"/>')
            body.append(f'<image href="{key}-{mode}-180.png" x="{x+275}" y="{y+585}" width="40" height="40"/>')
        open(f'{OUT}/wall-{mode}.svg', 'w').write('<svg xmlns="http://www.w3.org/2000/svg" width="1800" height="1800" viewBox="0 0 1800 1800">' + ''.join(body) + '</svg>')
        subprocess.run(['qlmanage', '-t', '-s', '1800', '-o', OUT, f'{OUT}/wall-{mode}.svg'], capture_output=True)
