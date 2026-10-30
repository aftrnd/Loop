from dirs import write_icon
from fields import contact
from swatch import swatch

def body(grid, w, strands=1, gap=None):
    return swatch(grid, w=w, strands=strands, gap=gap)('#000', '#fff')

B = [[0, 1, 0], [1, 1, 0], [0, 0, 1]]
S = [[0, 0, 1], [0, 0, 0], [1, 0, 0]]
cands = {
    's-b32': body(B, 32),
    's-sym32': body(S, 32),
    's-sym3': body(S, 12, 3, 12),
    's-b3': body(B, 12, 3, 12),
}
for n, b in cands.items():
    write_icon(n, [[('mark', b, True, 1)]])
contact(list(cands), 'swatch-glass.svg')
