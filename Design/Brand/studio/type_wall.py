"""Wordmark territories: the name set in sixteen real typefaces, outlined with outline.swift."""
import subprocess, sys
OUT, FONTS = '../wordmark', '/private/tmp/claude-501/-Users-nick-Library-CloudStorage-Dropbox-Developer-Xcode-Loop/3180a395-336a-4355-bca4-123c7e945a06/scratchpad/fonts'
TOOL = '/private/tmp/claude-501/-Users-nick-Library-CloudStorage-Dropbox-Developer-Xcode-Loop/3180a395-336a-4355-bca4-123c7e945a06/scratchpad/outline'
IDEAS = [
    ('01', 'SF Pro', 'native, the app\'s own voice', 'system:bold:standard', 'Loop', -0.03),
    ('02', 'SF Pro Expanded', 'native, wide and technical', 'system:bold:expanded', 'Loop', -0.02),
    ('03', 'New York', 'Apple\'s serif, editorial', 'serif:semibold', 'Loop', -0.02),
    ('04', 'SF Mono', 'native, engineered', 'mono:semibold', 'loop', -0.04),
    ('05', 'Geist', 'your site\'s face, Swiss', f'file:{FONTS}/Geist.ttf:wght=650', 'loop', -0.045),
    ('06', 'Geist Mono', 'instrument panel', f'file:{FONTS}/GeistMono.ttf:wght=600', 'loop', -0.04),
    ('07', 'Inter Display', 'neutral neo-grotesk', f'file:{FONTS}/Inter.ttf:wght=700,opsz=32', 'Loop', -0.045),
    ('08', 'Helvetica Neue', 'Swiss classic', 'name:HelveticaNeue-Bold', 'loop', -0.05),
    ('09', 'Unbounded', 'wide geometric display', f'file:{FONTS}/Unbounded.ttf:wght=600', 'loop', -0.03),
    ('10', 'Archivo Expanded', 'wide grotesk, caps', f'file:{FONTS}/Archivo.ttf:wght=800,wdth=125', 'LOOP', 0.0),
    ('11', 'Space Grotesk', 'quirky grotesk', f'file:{FONTS}/SpaceGrotesk.ttf:wght=700', 'loop', -0.04),
    ('12', 'Instrument Serif', 'condensed editorial serif', f'file:{FONTS}/InstrumentSerif.ttf', 'Loop', -0.02),
    ('13', 'Syne', 'eccentric, art school', f'file:{FONTS}/Syne.ttf:wght=700', 'Loop', -0.03),
    ('14', 'Bricolage Grotesque', 'ink-trapped, warm', f'file:{FONTS}/BricolageGrotesque.ttf:wght=700,opsz=96,wdth=85', 'loop', -0.01),
    ('15', 'Familjen Grotesk', 'compact, Scandinavian', f'file:{FONTS}/FamiljenGrotesk.ttf:wght=700', 'loop', -0.04),
    ('16', 'Futura', 'geometric classic', 'name:Futura-Bold', 'loop', -0.03),
]
res = subprocess.run([TOOL], input='\n'.join(f'{k}|{fnt}|{t}|{tr}' for k, _, _, fnt, t, tr in IDEAS), capture_output=True, text=True).stdout
paths = {}
for line in res.strip().split('\n'):
    k, box, d = line.split('|')
    paths[k] = ([float(v) for v in box.split()], d)

def word(k, x, y, h, ink):
    (x0, y0, x1, y1), d = paths[k]
    s = min(h / (y1 - y0), 395 / (x1 - x0))
    return f'<path transform="translate({x} {y}) scale({s:.5f}) translate({-x0:.1f} {-y0:.1f})" d="{d}" fill="{ink}"/>'

for light in (True, False):
    ink, card, sub, bg = ('#0b0b0b', '#fff', '#888', '#e9e9eb') if light else ('#fff', '#0b0b0b', '#777', '#151517')
    body = [f'<rect width="1800" height="1800" fill="{bg}"/>']
    for n, (k, title, note, *_ ) in enumerate(IDEAS):
        x, y = 12 + (n % 4) * 447, 12 + (n // 4) * 447
        body.append(f'<rect x="{x}" y="{y}" width="435" height="435" rx="16" fill="{card}"/>')
        body.append(f'<text x="{x+20}" y="{y+34}" font-family="Helvetica Neue" font-size="18" font-weight="500" fill="{ink}">{k}  {title}</text>')
        body.append(f'<text x="{x+20}" y="{y+56}" font-family="Helvetica Neue" font-size="14" fill="{sub}">{note}</text>')
        body.append(word(k, x + 20, y + 120, 120, ink))
        body.append(word(k, x + 20, y + 300, 54, ink))
        body.append(word(k, x + 20, y + 385, 22, ink))
    name = f'{OUT}/type-{"light" if light else "dark"}.svg'
    open(name, 'w').write('<svg xmlns="http://www.w3.org/2000/svg" width="1800" height="1800" viewBox="0 0 1800 1800">' + ''.join(body) + '</svg>')
    subprocess.run(['qlmanage', '-t', '-s', '1800', '-o', OUT, name], capture_output=True)
