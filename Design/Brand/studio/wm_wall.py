"""Wordmark pitch wall: two type controls and ten constructions from the icon's parts."""
import subprocess
from wordmark import Spec, word, f

def mark_svg(d, box, h, ink):
    """A wordmark path scaled so its full height (ascender to descender) is h px, returned as (svg group, width)."""
    x0, y0, x1, y1 = box
    k = h / (y1 - y0)
    return f'<path transform="scale({f(k)}) translate({f(-x0)} {f(-y0)})" d="{d}" fill="{ink}"/>', (x1 - x0) * k

IDEAS = [
    ('01', 'SF Pro, bold', None, 'font:-apple-system:700:Loop:-0.02'),
    ('02', 'SF Pro Rounded, bold', None, 'font:ui-rounded:700:loop:-0.01'),
    ('03', 'Ring', 'The o is the icon ring. Stems three strokes past the x-height.', Spec()),
    ('04', 'Ring, tail p', 'The p is an o with a tangent stem.', Spec(tail=True)),
    ('05', 'One circle', 'Footed l and tailed p: every curve is the ring.', Spec(foot=True, tail=True)),
    ('06', 'Capital L', 'The foot runs on as the L\'s bar.', Spec(foot=True, tail=True, l_bar=1.0)),
    ('07', 'Light', 'One circle at stroke r / 3.', Spec(r=3.0, foot=True, tail=True)),
    ('08', 'Heavy', 'One circle at stroke r / 1.5.', Spec(r=1.5, foot=True, tail=True, track=0.8)),
    ('09', 'Wide', 'Round gap of two strokes.', Spec(foot=True, tail=True, track=2.2)),
    ('10', 'Tight', 'Round gap of half a stroke.', Spec(foot=True, tail=True, track=0.5)),
    ('11', 'Tiles', 'The o drawn as its four Truchet quarters.', Spec(foot=True, tail=True, stencil=True)),
    ('12', 'Short stems', 'Ascender and descender of two strokes.', Spec(foot=True, tail=True, asc=2.0, desc=2.0)),
]

def cell(idea, x, y, light=True):
    key, title, note, spec = idea
    ink, bg, sub = ('#0b0b0b', '#ffffff', '#777') if light else ('#ffffff', '#0b0b0b', '#888')
    out = [f'<rect x="{x}" y="{y}" width="580" height="420" rx="18" fill="{bg}"/>',
           f'<text x="{x+24}" y="{y+40}" font-family="Helvetica Neue" font-size="20" font-weight="500" fill="{ink}">{key}  {title}</text>']
    if note:
        out.append(f'<text x="{x+24}" y="{y+66}" font-family="Helvetica Neue" font-size="15" fill="{sub}">{note}</text>')
    for h, yy in ((150, y + 110), (66, y + 300), (22, y + 384)):
        if isinstance(spec, str):
            _, fam, wt, text, tr = spec.split(':')
            fs = h * 0.98
            out.append(f'<text x="{x+24}" y="{yy + h*0.74}" font-family="{fam}" font-weight="{wt}" font-size="{fs}" letter-spacing="{tr}em" fill="{ink}">{text}</text>')
        else:
            text = 'Loop' if spec.l_bar else 'loop'
            d, box = word(spec, text)
            g, w = mark_svg(d, box, h, ink)
            out.append(f'<g transform="translate({x+24} {yy})">{g}</g>')
    return ''.join(out)

for light in (True, False):
    body = [f'<rect width="1800" height="1800" fill="{"#e9e9eb" if light else "#151517"}"/>']
    for k, idea in enumerate(IDEAS):
        body.append(cell(idea, 15 + (k % 3) * 595, 15 + (k // 3) * 445, light))
    name = f'../wordmark/wall-{"light" if light else "dark"}.svg'
    open(name, 'w').write('<svg xmlns="http://www.w3.org/2000/svg" width="1800" height="1800" viewBox="0 0 1800 1800">' + ''.join(body) + '</svg>')
    subprocess.run(['qlmanage', '-t', '-s', '1800', '-o', '../wordmark', name], capture_output=True)
