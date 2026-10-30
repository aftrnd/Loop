import json, subprocess, textwrap, sys
ideas = json.load(open('ideas.json'))
mode = sys.argv[1]
bg, fg, fg2 = ('#111113', '#f2f2f2', '#9a9a9a') if mode == 'Dark' else ('#ececec', '#0b0b0b', '#666')
W = 1800; cw = 435; top = 30
body = [f'<rect width="{W}" height="{W}" fill="{bg}"/>']
for k, (key, title, pitch) in enumerate(ideas):
    col, row = k % 4, k // 4
    x = 22 + col * (cw + 10); y = top + row * 590
    body.append(f'<image href="{key}-{mode}.png" x="{x+30}" y="{y}" width="375" height="375"/>')
    body.append(f'<image href="{key}-{mode}-87.png" x="{x+30}" y="{y+390}" width="58" height="58"/>')
    body.append(f'<text x="{x+104}" y="{y+410}" font-family="Helvetica Neue" font-size="22" font-weight="500" fill="{fg}">{key[:2]}  {title}</text>')
    for n, line in enumerate(textwrap.wrap(pitch, 34)):
        body.append(f'<text x="{x+104}" y="{y+438+n*22}" font-family="Helvetica Neue" font-size="16" fill="{fg2}">{line}</text>')
open(f'wall-{mode}.svg', 'w').write(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{W}" viewBox="0 0 {W} {W}">' + ''.join(body) + '</svg>')
subprocess.run(['qlmanage', '-t', '-s', str(W), '-o', '.', f'wall-{mode}.svg'], capture_output=True)
