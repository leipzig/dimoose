import re, sys
s = open('head-1.svg').read()
s = re.sub(r'<metadata>.*?</metadata>', '', s, flags=re.S)
paths = re.findall(r'<path[^>]*/>|<path[^>]*>.*?</path>', s, flags=re.S)
paths = [p for p in paths if 'd="M 0 0 L 2048 0' not in p]   # drop white background
head = "\n".join(paths)

TAN, INK = "#C99A4E", "#1F4D3A"
LEAF = "rgb(78,117,89)"
ANTLER = "#A67B65"
MOOSE = "#6E381B"
L, R = 230, 30   # every branch the same length, every dot the same size
SW = 14
WIDTH = {3: 46, 2: 32, 1: 22}           # taper: thick at the skull, thin at the tines
lines, nodes, tips = [], [], []
import math
def seg(x, y, nx, ny, side, w, bend=0.18):
    """Curved branch, bowed upward like an antler beam."""
    mx, my = (x+nx)/2, (y+ny)/2
    px, py = -(ny-y), (nx-x)            # perpendicular
    n = math.hypot(px, py) or 1
    if py > 0: px, py = -px, -py        # always bow upward
    cx, cy = mx + px/n*bend*L, my + py/n*bend*L
    lines.append((f"M {x:.0f} {y:.0f} Q {cx:.0f} {cy:.0f} {nx:.0f} {ny:.0f}", w))
def key(x, y, ang, depth, side):
    """Dichotomous key: each couplet node forks into exactly two leads.
    One lead carries the beam outward, the other rises as a tine."""
    nodes.append((x, y, depth))
    if depth == 0:
        tips.append((x, y)); return
    for a in (ang - FORK[depth][0], ang + FORK[depth][1]):
        r = math.radians(a)
        nx, ny = x + side*L*math.cos(r), y - L*math.sin(r)
        seg(x, y, nx, ny, side, WIDTH[depth])
        key(nx, ny, a, depth-1, side)
FORK = {3: (12, 38), 2: (14, 30), 1: (14, 22)}
T = (290, 700, 0.62)
bx, by = T[0] + T[2]*1150, T[1] + T[2]*470
for side in (-1, 1):
    sx, sy = bx + side*90, by - 90
    seg(bx, by+40, sx, sy, side, WIDTH[3]+10, bend=0)
    key(sx, sy, 18, 3, side)

g = []
for d, w in lines:
    g.append(f'<path d="{d}" fill="none" stroke="{ANTLER}" stroke-width="{w}" stroke-linecap="round"/>')
for x, y in tips:
    g.append(f'<circle cx="{x:.0f}" cy="{y:.0f}" r="{R}" fill="{ANTLER}"/>')
import colorsys
def _rgb(h): return tuple(int(h[i:i+2], 16)/255 for i in (1, 3, 5))
def recolor(m):
    """Map the head's greens onto MOOSE, keeping each shade's relative lightness."""
    c = tuple(int(v)/255 for v in m.group(1).split(","))
    h, l, s_ = colorsys.rgb_to_hls(*c)
    if s_ < 0.15 or l > 0.95: return m.group(0)   # leave whites/greys (eye, highlights)
    bh, bl, bs = colorsys.rgb_to_hls(*_rgb(MOOSE))
    base_l = colorsys.rgb_to_hls(31/255, 77/255, 58/255)[1]   # head's main green
    nl = bl * l/base_l if l <= base_l else bl + (1-bl)*(l-base_l)/(1-base_l)
    r, g, b = colorsys.hls_to_rgb(bh, min(nl, 0.95), bs if l <= base_l else bs*0.45)   # muted highlights
    return f'fill="rgb({r*255:.0f},{g*255:.0f},{b*255:.0f})"'
head = re.sub(r'fill="rgb\(([0-9,]+)\)"', recolor, head)
SNOUT = (1330, 1790, 760)   # y0, y1, x1 of the region allowed to break out of the ring
out = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 2048 2048" width="1024" height="1024">
<title>moose</title>
<defs><clipPath id="badge"><circle cx="1030" cy="1240" r="590"/><rect x="0" y="{SNOUT[0]}" width="{SNOUT[2]}" height="{SNOUT[1]-SNOUT[0]}"/></clipPath></defs>
<g>{"".join(g)}</g>
<circle cx="1030" cy="1240" r="590" fill="none" stroke="{MOOSE}" stroke-width="{SW}"/>
<g clip-path="url(#badge)"><g transform="translate({T[0]},{T[1]}) scale({T[2]})">
{head}
</g></g>
</svg>'''
import itertools
print('min tip gap', min(math.dist(a,b) for a,b in itertools.combinations(tips,2)) - 2*R)
open(sys.argv[1], 'w').write(out)
