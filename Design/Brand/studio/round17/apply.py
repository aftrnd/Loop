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
g = final.gray
def fills(light, dark, tinted):
    return [{"value": {"solid": light}}, {"appearance": "dark", "value": {"solid": dark}}, {"appearance": "tinted", "value": {"solid": tinted}}]
defaults = {"shadow": {"kind": "neutral", "opacity": 0.5}, "translucency": {"enabled": True, "value": 0.3}}
doc = {
  "features": ["refractivity"],
  "fill-specializations": [{"value": {"solid": final.WHITE}}, {"appearance": "dark", "value": "system-dark"}],
  "groups": [
    dict(name="Echo", layers=[{"fill-specializations": fills(g(0.04314, 0.16), g(1, 0.14), g(1, 0.1)), "glass": True, "image-name": "echo.svg", "name": "echo"}],
         refractivity={"depth": 0.4, "enabled": True, "strength": 0.25}, **{"blur-material": 0.05}, **defaults),
    dict(name="Said", layers=[{"fill-specializations": fills(final.INK, final.WHITE, final.WHITE), "glass": True, "image-name": "said.svg", "name": "said"}], **defaults),
  ],
  "supported-platforms": {"squares": "shared"},
}
open(f'{dst}/icon.json', 'w').write(json.dumps(doc, indent=2, sort_keys=True, separators=(',', ' : ')))
print(open(f'{dst}/Assets/said.svg').read()[-130:])
