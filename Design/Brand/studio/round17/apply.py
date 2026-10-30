"""Write the app icon in Icon Composer's own format: R = 7.5u, centers 6.5u apart, lifted u/4; Dark on system-dark."""
import json, os, shutil, sys
import final
U = final.U
final.R = 7.5 * U
d = 6.5 / 2 * U
final.SAID = (512 - d, 512 - d - U / 4)
final.ECHO = (512 + d, 512 + d - U / 4)
dst = sys.argv[1]
os.makedirs(f'{dst}/Assets', exist_ok=True)
for f in os.listdir(f'{dst}/Assets'): os.remove(f'{dst}/Assets/{f}')
open(f'{dst}/Assets/said.svg', 'w').write(final.svg(final.path(final.SAID)))
open(f'{dst}/Assets/echo.svg', 'w').write(final.svg(final.path(final.ECHO, mirror=True)))
# The sheen: a pale thin-film rim inside the echo, strongest toward the light (sheen.swift, 2048 px, inset 9, sigma 4, palette 35% toward white).
import subprocess, irid
json.dump({'pts': irid.echo_outline(1600), 'center': final.ECHO}, open('irid/echo.json', 'w'))
subprocess.run(['./sheen', 'irid/echo.json', f'{dst}/Assets/sheen.png', '2048', '9', '4', '1.0', '0.35'], check=True)
g = final.gray
def fills(light, dark, tinted):
    return [{"value": {"solid": light}}, {"appearance": "dark", "value": {"solid": dark}}, {"appearance": "tinted", "value": {"solid": tinted}}]
defaults = {"shadow": {"kind": "neutral", "opacity": 0.5}, "translucency": {"enabled": True, "value": 0.3}}
doc = {
  "features": ["refractivity"],
  "fill-specializations": [{"value": {"solid": final.WHITE}}, {"appearance": "dark", "value": "system-dark"}],
  "groups": [
    dict(name="Echo", layers=[{"blend-mode-specializations": [{"value": "normal"}, {"appearance": "dark", "value": "plus-lighter"}],
                               "glass": False, "hidden-specializations": [{"value": False}, {"appearance": "tinted", "value": True}],
                               "image-name": "sheen.png", "name": "sheen",
                               "opacity-specializations": [{"value": 0.45}, {"appearance": "dark", "value": 0.55}],
                               "position": {"scale": 0.5, "translation-in-points": [0, 0]}},
                              {"fill-specializations": fills(g(0.04314, 0.16), g(1, 0.14), g(1, 0.1)), "glass": True, "image-name": "echo.svg", "name": "echo"}],
         refractivity={"depth": 0.4, "enabled": True, "strength": 0.25}, **{"blur-material": 0.05}, **defaults),
    dict(name="Said", layers=[{"fill-specializations": fills(final.INK, final.WHITE, final.WHITE), "glass": True, "image-name": "said.svg", "name": "said"}], **defaults),
  ],
  "supported-platforms": {"squares": "shared"},
}
open(f'{dst}/icon.json', 'w').write(json.dumps(doc, indent=2, sort_keys=True, separators=(',', ' : ')))
print(open(f'{dst}/Assets/said.svg').read()[-130:])
