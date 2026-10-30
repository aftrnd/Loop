"""Loop mark: concentric rings with one aligned radial slot. Every dimension is constructed:

  Outer diameter   canvas / phi
  Pitch            outer radius / (rings + 1/phi)   (the innermost ring keeps a counter of one pitch / phi)
  Line             pitch / phi                      (line : gap = phi : 1)
  Slot             a straight-sided band at 45 degrees; its faces are exact lines, not stroke caps

Each ring is a filled shape: the annulus between r - line/2 and r + line/2, minus the slot band.
"""
import math

PHI = (1 + 5 ** 0.5) / 2


def f(v):
    return f"{v:.3f}"


def ring_with_slot(cx, cy, r, line, slot, angle):
    """Annulus (r +- line/2) minus a band of width `slot` along the ray from the centre at `angle` (radians,
    y down). Returns an SVG path. The cut faces are segments of the band's two edge lines."""
    ro, ri = r + line / 2, r - line / 2
    ux, uy = math.cos(angle), math.sin(angle)           # ray direction
    nx, ny = -uy, ux                                    # band normal
    h = slot / 2

    def hit(radius, side):
        # point on the circle of `radius` where the band edge (offset side*h along n) crosses it, on the ray's side
        t = math.sqrt(max(radius * radius - h * h, 0.0))
        return cx + side * h * nx + t * ux, cy + side * h * ny + t * uy

    o1, o2 = hit(ro, +1), hit(ro, -1)
    i1, i2 = hit(ri, +1), hit(ri, -1)
    # Outer arc from the +edge round the long way to the -edge, straight face in, inner arc back, straight face out
    return (f"M{f(o1[0])} {f(o1[1])}A{f(ro)} {f(ro)} 0 1 1 {f(o2[0])} {f(o2[1])}"
            f"L{f(i2[0])} {f(i2[1])}A{f(ri)} {f(ri)} 0 1 0 {f(i1[0])} {f(i1[1])}Z")


def mark(rings=7, slot_scale=1.0, angle_deg=-45, size=1024, color="#FFFFFF", center_dot=False):
    c = size / 2
    outer = size / PHI / 2
    pitch = outer / (rings + 1 / PHI)
    line = pitch / PHI
    gap = pitch - line
    slot = slot_scale * pitch
    a = math.radians(angle_deg)
    paths = []
    for k in range(rings):
        r = outer - line / 2 - k * pitch
        if r - line / 2 <= slot / 2 + 1e-6:
            break                                      # ring too small to survive the slot
        paths.append(ring_with_slot(c, c, r, line, slot, a))
    body = "".join(f'<path d="{d}" fill="{color}"/>' for d in paths)
    if center_dot:
        body += f'<circle cx="{f(c)}" cy="{f(c)}" r="{f(line / 2 * PHI)}" fill="{color}"/>'
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {size} {size}" width="{size}" height="{size}">'
            f'{body}</svg>\n'), dict(pitch=pitch, line=line, gap=gap, slot=slot)
