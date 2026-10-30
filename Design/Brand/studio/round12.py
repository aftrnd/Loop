"""Round twelve: make the crystal read as glass at home-screen size.

The app icon's lens is 8% white glass on a white tile, so at 60 pt only the bent lines show it.
Each variant copies the app icon's artwork and changes only icon.json.
"""
import copy, json, os, shutil, subprocess
from fields import IC

SRC = '../../../loop-icon.icon'
OUT = '../round12'
gray = lambda v, a=1: f"extended-gray:{v:.5f},{a:.5f}"
base = json.load(open(f'{SRC}/icon.json'))


def variant(name, fn):
    d = copy.deepcopy(base)
    lens, ring, lines = d['groups']
    fn(d, lens, ring, lines)
    out = f'{OUT}/{name}.icon'
    shutil.rmtree(out, ignore_errors=True)
    shutil.copytree(f'{SRC}/Assets', f'{out}/Assets')
    json.dump(d, open(f'{out}/icon.json', 'w'), indent=2)
    for r in ('Default', 'Dark'):
        for size, scale, tag in ((1024, 1, ''), (60, 3, '-180'), (60, 1, '-60')):
            subprocess.run([IC, out, '--export-image', '--output-file', f'{OUT}/{name}-{r}{tag}.png', '--platform', 'iOS',
                            '--rendition', r, '--width', str(size), '--height', str(size), '--scale', str(scale)], capture_output=True)


def fill(layer, light, dark):
    layer['layers'][0]['fill-specializations'][0]['value'] = {"solid": light}
    layer['layers'][0]['fill-specializations'][1]['value'] = {"solid": dark}


def lifted(d, lens, ring, lines):
    lens['shadow'] = {"kind": "neutral", "opacity": 0.6}


def smoke(d, lens, ring, lines):
    fill(lens, gray(0.04314, 0.10), gray(1, 0.12))
    lens['shadow'] = {"kind": "neutral", "opacity": 0.4}


def frosted(d, lens, ring, lines):
    lens['blur-material'] = 0.5
    lens['shadow'] = {"kind": "neutral", "opacity": 0.4}


def gray_ground(d, lens, ring, lines):
    d['fill-specializations'][0]['value'] = {"automatic-gradient": gray(0.90)}
    fill(lens, gray(1, 0.55), gray(1, 0.12))
    lens['shadow'] = {"kind": "neutral", "opacity": 0.4}


def ring_on_glass(d, lens, ring, lines):
    d['groups'] = [ring, lens, lines]
    lens['shadow'] = {"kind": "neutral", "opacity": 0.5}
    fill(lens, gray(1, 0.35), gray(1, 0.10))


def deep(d, lens, ring, lines):
    lens['refractivity'] = {"enabled": True, "depth": 0.4, "strength": 0.15}
    lens['shadow'] = {"kind": "neutral", "opacity": 0.4}


def strong(d, lens, ring, lines):
    lens['refractivity'] = {"enabled": True, "depth": 0.15, "strength": 0.3}
    lens['shadow'] = {"kind": "neutral", "opacity": 0.4}


def milk(d, lens, ring, lines):
    fill(lens, gray(1, 0.6), gray(1, 0.18))
    lens['translucency'] = {"enabled": True, "value": 0.5}
    lens['shadow'] = {"kind": "neutral", "opacity": 0.5}


def ink_ground(d, lens, ring, lines):
    # Dark tile in both appearances: the crystal's specular rim reads on ink, as in the Dark render.
    d['fill-specializations'][0]['value'] = {"solid": gray(0.04314)}
    fill(lines, gray(1), gray(1))
    fill(lens, gray(1, 0.08), gray(1, 0.06))
    lens['shadow'] = {"kind": "neutral", "opacity": 0.5}


def ink_milk(d, lens, ring, lines):
    d['fill-specializations'][0]['value'] = {"solid": gray(0.04314)}
    fill(lines, gray(1), gray(1))
    fill(lens, gray(1, 0.16), gray(1, 0.16))
    lens['shadow'] = {"kind": "neutral", "opacity": 0.6}


VARIANTS = [
    ('01-now', 'Now', lambda *a: None),
    ('02-lifted', 'Lifted (shadow 0.6)', lifted),
    ('03-smoke', 'Smoke body', smoke),
    ('04-frosted', 'Frosted', frosted),
    ('05-gray', 'Gray ground, white crystal', gray_ground),
    ('06-ring-on', 'Ring on the glass', ring_on_glass),
    ('07-deep', 'Depth 0.4', deep),
    ('08-strong', 'Strength 0.3', strong),
    ('09-milk', 'Milk glass', milk),
    ('10-ink', 'Ink tile always', ink_ground),
    ('11-ink-milk', 'Ink tile, milk glass', ink_milk),
]

if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for key, _, fn in VARIANTS:
        variant(key, fn)
    W, cw, ch = 1800, 600, 450
    for mode, bg, fg in (('Default', '#e9e9eb', '#111'), ('Dark', '#151517', '#eee')):
        body = [f'<rect width="{W}" height="{W}" fill="{bg}"/>']
        for k, (key, title, _) in enumerate(VARIANTS):
            x, y = (k % 3) * cw + 20, (k // 3) * ch + 16
            body.append(f'<text x="{x}" y="{y + 22}" font-family="Helvetica Neue" font-size="22" font-weight="500" fill="{fg}">{key[:2]}  {title}</text>')
            body.append(f'<image href="{key}-{mode}.png" x="{x}" y="{y + 36}" width="380" height="380"/>')
            body.append(f'<image href="{key}-{mode}-180.png" x="{x + 396}" y="{y + 36}" width="180" height="180"/>')
            body.append(f'<image href="{key}-{mode}-180.png" x="{x + 396}" y="{y + 236}" width="60" height="60"/>')
            body.append(f'<image href="{key}-{mode}-60.png" x="{x + 476}" y="{y + 236}" width="60" height="60"/>')
        open(f'{OUT}/wall-{mode}.svg', 'w').write(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{W}" viewBox="0 0 {W} {W}">' + ''.join(body) + '</svg>')
        subprocess.run(['qlmanage', '-t', '-s', str(W), '-o', OUT, f'{OUT}/wall-{mode}.svg'], capture_output=True)
