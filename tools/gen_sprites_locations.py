#!/usr/bin/env python3
"""
Generate location-specific assets:
  Tiles:   tile_floor_forest, tile_tree, tile_house_wall,
           tile_floor_cave, tile_wall_cave
  Bosses:  enemy_witch_walk/attack, enemy_dragon_walk/attack
  Bullets: magic_bolt, fireball
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

# ── Shared constants (Archero sprite size matches gen_sprites_archero.py) ────
SIZE    = 64
TILE_W  = 32
TILE_H  = 40   # wall tiles are taller than floor tiles
FLOOR_H = 32

SPRITES_OUT  = r"C:\!DB\game_ai\assets\sprites"
TILESETS_OUT = r"C:\!DB\game_ai\assets\tilesets"
os.makedirs(SPRITES_OUT,  exist_ok=True)
os.makedirs(TILESETS_OUT, exist_ok=True)

_L = np.array([0.50, -0.60, 0.63], dtype=np.float64)
_L /= np.linalg.norm(_L)
OUTLINE = (18, 14, 22)
OW = 2

def _save_sprite(img, name):
    img.save(os.path.join(SPRITES_OUT, name)); print(f"  sprites/{name}")

def _save_tile(img, name):
    img.save(os.path.join(TILESETS_OUT, name)); print(f"  tilesets/{name}")


# ── Tile helpers ──────────────────────────────────────────────────────────────

def _floor_tile(r, g, b, seed=7):
    rng   = np.random.default_rng(seed)
    noise = rng.integers(-10, 11, (FLOOR_H, TILE_W)).astype(np.int16)
    arr   = np.zeros((FLOOR_H, TILE_W, 4), dtype=np.uint8)
    for i, c in enumerate((r, g, b)):
        arr[:, :, i] = np.clip(c + noise, 0, 255).astype(np.uint8)
    arr[:, :, 3] = 255
    return Image.fromarray(arr, 'RGBA')


def _wall_tile(r, g, b, seed=13):
    rng    = np.random.default_rng(seed)
    rf, gf, bf = max(0, r - 22), max(0, g - 22), max(0, b - 22)
    rt, gt, bt = min(255, r + 10), min(255, g + 10), min(255, b + 10)
    arr = np.zeros((TILE_H, TILE_W, 4), dtype=np.uint8)
    nf  = rng.integers(-8, 9, (TILE_H - 8, TILE_W)).astype(np.int16)
    nt  = rng.integers(-5, 6, (8, TILE_W)).astype(np.int16)
    for i, (cf, ct) in enumerate(((rf, rt), (gf, gt), (bf, bt))):
        arr[8:, :, i] = np.clip(cf + nf, 0, 255).astype(np.uint8)
        arr[:8, :, i] = np.clip(ct + nt, 0, 255).astype(np.uint8)
    arr[:, :, 3] = 255
    return Image.fromarray(arr, 'RGBA')


# ── Location tiles ────────────────────────────────────────────────────────────

def make_forest_floor():
    return _floor_tile(58, 145, 35, seed=3)


def make_tree():
    img = Image.new('RGBA', (TILE_W, TILE_H), (58, 145, 35, 255))
    d   = ImageDraw.Draw(img)
    d.ellipse([1, 3, 31, 33], fill=(20, 70, 8, 255))          # dark canopy
    d.ellipse([6, 6, 26, 26], fill=(38, 100, 18, 255))        # mid canopy
    d.ellipse([11, 9, 21, 19], fill=(55, 130, 28, 200))       # highlight
    d.ellipse([11, 26, 21, 36], fill=(72, 48, 22, 255))       # trunk
    d.arc([1, 3, 31, 33], start=0, end=360, fill=(10, 45, 2, 255), width=2)
    return img


def make_house_wall():
    img = Image.new('RGBA', (TILE_W, TILE_H), (110, 74, 40, 255))
    d   = ImageDraw.Draw(img)
    # Front face planks
    for y in range(9, TILE_H, 7):
        d.line([(0, y), (TILE_W - 1, y)], fill=(75, 48, 22, 255), width=1)
    for x in range(8, TILE_W, 8):
        d.line([(x, 9), (x, TILE_H - 1)], fill=(88, 58, 28, 200), width=1)
    # Top face (lighter)
    d.rectangle([0, 0, TILE_W - 1, 8], fill=(140, 98, 55, 255))
    d.line([(0, 8), (TILE_W - 1, 8)], fill=(60, 38, 16, 255), width=1)
    return img


def make_cave_floor():
    return _floor_tile(30, 26, 20, seed=17)


def make_cave_wall():
    return _wall_tile(22, 18, 14, seed=19)


# ── Sprite primitives (same as gen_sprites_archero.py) ───────────────────────

def _new():    return np.zeros((SIZE, SIZE, 4), dtype=np.uint8)
def _img(a):   return Image.fromarray(a, 'RGBA')
def _arr(img): return np.array(img)

def _fill_circle(a, cx, cy, r, rgb):
    pad  = int(r) + 2
    y0, y1 = max(0, int(cy) - pad), min(SIZE, int(cy) + pad + 1)
    x0, x1 = max(0, int(cx) - pad), min(SIZE, int(cx) + pad + 1)
    if y0 >= y1 or x0 >= x1: return
    ys, xs = np.mgrid[y0:y1, x0:x1]
    m = (xs - cx) ** 2 + (ys - cy) ** 2 <= r * r
    for i, c in enumerate(rgb):
        a[y0:y1, x0:x1, i] = np.where(m, c, a[y0:y1, x0:x1, i])
    a[y0:y1, x0:x1, 3] = np.where(m, 255, a[y0:y1, x0:x1, 3])

def _fill_ellipse(a, cx, cy, rx, ry, rgb):
    px, py = int(rx) + 2, int(ry) + 2
    y0, y1 = max(0, int(cy) - py), min(SIZE, int(cy) + py + 1)
    x0, x1 = max(0, int(cx) - px), min(SIZE, int(cx) + px + 1)
    if y0 >= y1 or x0 >= x1: return
    ys, xs = np.mgrid[y0:y1, x0:x1]
    m = ((xs - cx) / rx) ** 2 + ((ys - cy) / ry) ** 2 <= 1.0
    for i, c in enumerate(rgb):
        a[y0:y1, x0:x1, i] = np.where(m, c, a[y0:y1, x0:x1, i])
    a[y0:y1, x0:x1, 3] = np.where(m, 255, a[y0:y1, x0:x1, 3])

def sphere(a, cx, cy, r, rgb, amb=0.08):
    pad  = int(r) + 2
    y0, y1 = max(0, int(cy) - pad), min(SIZE, int(cy) + pad + 1)
    x0, x1 = max(0, int(cx) - pad), min(SIZE, int(cx) + pad + 1)
    if y0 >= y1 or x0 >= x1: return
    ys, xs = np.mgrid[y0:y1, x0:x1]
    dx = (xs - cx) / r;  dy = (ys - cy) / r
    d2 = dx * dx + dy * dy
    m  = d2 <= 1.0
    dz = np.where(m, np.sqrt(np.clip(1.0 - d2, 0, 1)), 0.0)
    dot  = np.clip(_L[0]*dx + _L[1]*dy + _L[2]*dz, 0, 1)
    edge = np.where(m, dz ** 0.42, 0.0)
    shad = edge * (amb + (1.0 - amb) * dot)
    rz   = 2.0 * dot * dz - _L[2]
    spec = np.where(m, np.clip(rz, 0, 1) ** 30 * 0.65, 0.0)
    hx = (xs - (cx - r * 0.30)) / max(r * 0.36, 1)
    hy = (ys - (cy - r * 0.30)) / max(r * 0.36, 1)
    h2 = hx * hx + hy * hy
    hi = np.where(m & (h2 <= 1.0), np.clip(1.0 - h2, 0, 1) ** 2.5 * 0.50, 0.0)
    cr, cg, cb = rgb
    for i, c in enumerate(rgb):
        a[y0:y1, x0:x1, i] = np.where(m,
            np.clip(c*shad + 255.0*spec*0.5 + 255.0*hi, 0, 255), a[y0:y1, x0:x1, i])
    a[y0:y1, x0:x1, 3] = np.where(m, 255, a[y0:y1, x0:x1, 3])

def oval(a, cx, cy, rx, ry, rgb, amb=0.12):
    px, py = int(rx) + 2, int(ry) + 2
    y0, y1 = max(0, int(cy) - py), min(SIZE, int(cy) + py + 1)
    x0, x1 = max(0, int(cx) - px), min(SIZE, int(cx) + px + 1)
    if y0 >= y1 or x0 >= x1: return
    ys, xs = np.mgrid[y0:y1, x0:x1]
    ex = (xs - cx) / rx;  ey = (ys - cy) / ry
    e2 = ex * ex + ey * ey
    m  = e2 <= 1.0
    ez = np.where(m, np.sqrt(np.clip(1.0 - e2, 0, 1)), 0.0)
    nx = ex;  nz = np.sqrt(np.clip(1.0 - nx * nx, 0, 1))
    dot  = np.clip(_L[0]*nx + _L[2]*nz, 0, 1)
    edge = np.where(m, ez ** 0.42, 0.0)
    shad = edge * (amb + (1.0 - amb) * dot)
    for i, c in enumerate(rgb):
        a[y0:y1, x0:x1, i] = np.where(m, np.clip(c * shad, 0, 255), a[y0:y1, x0:x1, i])
    a[y0:y1, x0:x1, 3] = np.where(m, 255, a[y0:y1, x0:x1, 3])

def O_sphere(a, cx, cy, r, rgb):
    _fill_circle(a, int(cx), int(cy), r + OW, OUTLINE)
    sphere(a, cx, cy, r, rgb)

def O_oval(a, cx, cy, rx, ry, rgb):
    _fill_ellipse(a, int(cx), int(cy), rx + OW, ry + OW, OUTLINE)
    oval(a, cx, cy, rx, ry, rgb)

def _foot_shadow(a, alpha=60):
    sh = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    d  = ImageDraw.Draw(sh)
    d.ellipse([14, 57, 50, 64], fill=(0, 0, 0, alpha))
    sh = sh.filter(ImageFilter.GaussianBlur(3))
    return _arr(Image.alpha_composite(sh, _img(a)))

def _glow(a, cx, cy, r, color, strength=90):
    gl = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    d  = ImageDraw.Draw(gl)
    cr, cg, cb = color
    d.ellipse([int(cx-r), int(cy-r), int(cx+r), int(cy+r)], fill=(cr, cg, cb, strength))
    gl = gl.filter(ImageFilter.GaussianBlur(r * 0.9))
    return _arr(Image.alpha_composite(_img(a), gl))


_W = ((0, 0), (3, 1), (0, 0), (-3, 1))   # walk offsets (leg_x, body_y)


# ── WITCH ─────────────────────────────────────────────────────────────────────
_WLEG   = (88, 28, 115)
_WROBE  = (118, 38, 165)
_WSKIN  = (72, 192, 55)
_WEYE   = (255, 215, 0)
_WBRIM  = (25, 10, 40)
_WCON   = (48, 18, 72)
_WSTAFF = (98, 65, 30)


def witch_frame(frame: int, attack: bool = False) -> Image.Image:
    lx, by = _W[frame]
    a = _new()
    # Legs
    O_sphere(a, 25 + lx, 53 + by, 6, _WLEG)
    O_sphere(a, 39 - lx, 53 + by, 6, _WLEG)
    # Robe body
    O_oval(a, 32, 44 + by, 11, 9, _WROBE)
    # Hat cone (drawn before face so face overlays brim)
    _fill_ellipse(a, 32, 13, 7 + OW, 14 + OW, OUTLINE)
    oval(a, 32, 13, 7, 14, _WCON)
    # Face (green skin)
    O_sphere(a, 32, 29, 11, _WSKIN)
    # Hat brim (overlays top of face for 3D hat look)
    _fill_ellipse(a, 32, 23, 15, 4, OUTLINE)
    _fill_ellipse(a, 32, 23, 14, 3, _WBRIM)
    # Golden eyes
    _fill_circle(a, 26, 26, 4, OUTLINE); sphere(a, 26, 26, 3, _WEYE)
    _fill_circle(a, 38, 26, 4, OUTLINE); sphere(a, 38, 26, 3, _WEYE)
    # Eye glow
    a = _glow(a, 26, 26, 6, _WEYE, 70)
    a = _glow(a, 38, 26, 6, _WEYE, 70)
    if attack:
        # Magic orb burst to the right
        a = _glow(a, 50, 38 + by, 10, (180, 60, 255), 110)
        sphere(a, 50, 38 + by, 7, (200, 90, 255))
    a = _foot_shadow(a, alpha=55)
    return _img(a)


# ── DRAGON ────────────────────────────────────────────────────────────────────
_DWING  = (62, 50, 40)
_DBODY  = (158, 18, 18)
_DDARK  = (100, 10, 10)
_DHORN  = (30, 18, 18)
_DEYE   = (255, 108, 0)
_DMID   = (130, 14, 14)


def dragon_frame(frame: int, attack: bool = False) -> Image.Image:
    lx, by = _W[frame]
    a = _new()
    # Wings (behind body — drawn first)
    _fill_ellipse(a, 7,  38 + by, 16, 10, OUTLINE); oval(a, 7,  38 + by, 14, 9, _DWING)
    _fill_ellipse(a, 57, 38 + by, 16, 10, OUTLINE); oval(a, 57, 38 + by, 14, 9, _DWING)
    # Body (large)
    O_oval(a, 32, 42 + by, 14, 11, _DBODY)
    # Neck
    O_oval(a, 32, 30 + by, 9, 7, _DMID)
    # Head
    O_sphere(a, 32, 19, 13, _DBODY)
    # Horns
    _fill_ellipse(a, 25,  8, 3 + 1, 7 + 1, OUTLINE); oval(a, 25,  8, 3, 7, _DHORN)
    _fill_ellipse(a, 39,  8, 3 + 1, 7 + 1, OUTLINE); oval(a, 39,  8, 3, 7, _DHORN)
    # Glowing orange eyes
    a = _glow(a, 26, 15, 8, _DEYE, 95)
    a = _glow(a, 38, 15, 8, _DEYE, 95)
    _fill_circle(a, 26, 15, 5, OUTLINE); sphere(a, 26, 15, 4, _DEYE)
    _fill_circle(a, 38, 15, 5, OUTLINE); sphere(a, 38, 15, 4, _DEYE)
    _fill_circle(a, 26, 16, 2, (255, 200, 100))
    _fill_circle(a, 38, 16, 2, (255, 200, 100))
    if attack:
        # Fireball
        a = _glow(a, 52, 36 + by, 12, (255, 80, 0), 130)
        sphere(a, 52, 36 + by, 8, (255, 130, 0))
    a = _foot_shadow(a, alpha=78)
    return _img(a)


# ── Projectile sprites ────────────────────────────────────────────────────────

def make_magic_bolt():
    S = 18
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    gl  = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(gl).ellipse([0, 0, S-1, S-1], fill=(160, 50, 255, 110))
    gl  = gl.filter(ImageFilter.GaussianBlur(3.5))
    img = Image.alpha_composite(img, gl)
    ImageDraw.Draw(img).ellipse([4, 4, S-5, S-5], fill=(225, 145, 255, 255))
    return img

def make_fireball():
    S = 22
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    gl  = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(gl).ellipse([0, 0, S-1, S-1], fill=(255, 80, 0, 120))
    gl  = gl.filter(ImageFilter.GaussianBlur(4.5))
    img = Image.alpha_composite(img, gl)
    ImageDraw.Draw(img).ellipse([5, 5, S-6, S-6], fill=(255, 200, 55, 255))
    return img


# ── MAIN ─────────────────────────────────────────────────────────────────────

def main():
    print("Generating location tiles...")
    _save_tile(make_forest_floor(), "tile_floor_forest.png")
    _save_tile(make_tree(),         "tile_tree.png")
    _save_tile(make_house_wall(),   "tile_house_wall.png")
    _save_tile(make_cave_floor(),   "tile_floor_cave.png")
    _save_tile(make_cave_wall(),    "tile_wall_cave.png")

    print("Generating witch boss sprites...")
    for i in range(4):
        _save_sprite(witch_frame(i), f"enemy_witch_walk_{i}.png")
    _save_sprite(witch_frame(0, attack=True), "enemy_witch_attack_0.png")

    print("Generating dragon boss sprites...")
    for i in range(4):
        _save_sprite(dragon_frame(i), f"enemy_dragon_walk_{i}.png")
    _save_sprite(dragon_frame(0, attack=True), "enemy_dragon_attack_0.png")

    print("Generating projectiles...")
    _save_sprite(make_magic_bolt(), "magic_bolt.png")
    _save_sprite(make_fireball(),   "fireball.png")

    print("Done!")

if __name__ == "__main__":
    main()
