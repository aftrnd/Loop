"""Builds the Loop app icon: a Mobius band drawn as nine strands, written into the
Icon Composer document at the repo root (loop-icon.icon). Run from this folder: python3 build_icon.py"""
import json
import math
import os
import shutil
from lineart import mobius, mobius_surface, render

STRANDS, STROKE, CLEARANCE = 9, 10, 7
AZIMUTH = math.radians(-90)           # the half twist turns over on the right
ICON = os.path.join(os.path.dirname(__file__), "..", "..", "..", "loop-icon.icon")

surface, u_range, v_range = mobius_surface()
mark = render(mobius(STRANDS, samples=1440), surface, u_range, v_range, AZIMUTH, STROKE, CLEARANCE,
              res=2048, nu=1440, nv=16, fill=0.66)

assets = os.path.join(ICON, "Assets")
shutil.rmtree(assets, ignore_errors=True)
os.makedirs(assets)
open(os.path.join(assets, "loop.svg"), "w").write(mark)

INK, PAPER, PLATE, WHITE = "extended-gray:0.06667,1.00000", "extended-gray:1.00000,1.00000", "extended-gray:0.04314,1.00000", "extended-gray:1.00000,1.00000"
def layer(name, opacity):
    return {
        "name": name, "image-name": f"{name}.svg", "glass": True,
        "fill-specializations": [{"value": {"solid": INK}}, {"appearance": "dark", "value": {"solid": WHITE}},
                                 {"appearance": "tinted", "value": {"solid": WHITE}}],
        "opacity-specializations": [{"value": opacity}],
        "position": {"scale": 1, "translation-in-points": [0, 0]},
    }
icon = {
    "fill-specializations": [{"value": {"solid": PAPER}}, {"appearance": "dark", "value": {"solid": PLATE}}],
    "groups": [{
        "layers": [layer("loop", 1)],
        "lighting": "individual", "shadow": {"kind": "layer-color", "opacity": 0.5},
        "specular": True, "translucency": {"enabled": True, "value": 0.5},
    }],
    "supported-platforms": {"squares": "shared"},
}
json.dump(icon, open(os.path.join(ICON, "icon.json"), "w"), indent=2)
print("wrote", os.path.abspath(ICON))
