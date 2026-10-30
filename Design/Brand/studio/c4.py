"""4 x 4 swatches with 90 degree rotational symmetry about the center corner and a ring around it."""
import itertools
from studio import M, C, f, sheet
from swatch import swatch, cycles

def configs():
    orbits = [[(0, 0), (3, 0), (3, 3), (0, 3)], [(1, 0), (3, 1), (2, 3), (0, 2)], [(2, 0), (3, 2), (1, 3), (0, 1)]]
    out = []
    for bits in itertools.product([0, 1], repeat=3):
        g = [[None] * 4 for _ in range(4)]
        # center orbit: (1,1)=0 so its bottom-right corner (the center) gets an arc; rotation flips orientation
        for k, (i, j) in enumerate([(1, 1), (2, 1), (2, 2), (1, 2)]):
            g[j][i] = k % 2 if True else 0
        for b, orb in zip(bits, orbits):
            for k, (i, j) in enumerate(orb):
                g[j][i] = (b + k) % 2
        out.append(g)
    return out

if __name__ == '__main__':
    cs = configs()
    for g in cs: print(g, 'loops', sorted(cycles(g)))
    rows = [(f'c4-{k} loops {sorted(cycles(g))}', swatch(g, span=512, w=32)) for k, g in enumerate(cs)]
    sheet(rows[:4], 'c4a.svg'); sheet(rows[4:], 'c4b.svg')
