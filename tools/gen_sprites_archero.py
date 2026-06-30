#!/usr/bin/env python3
"""
Archero-style top-down sprites: dark outlines, saturated colors,
strong edge darkening, chibi proportions (large head), 64x64px.
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SIZE = 64
OUT  = r"C:\!DB\game_ai\assets\sprites"
os.makedirs(OUT, exist_ok=True)

# Light from upper-left-front
_L = np.array([0.50, -0.60, 0.63], dtype=np.float64)
_L /= np.linalg.norm(_L)

OUTLINE = (18, 14, 22)   # dark purple-black outline
OW      = 2              # outline width in px

def _new():      return np.zeros((SIZE, SIZE, 4), dtype=np.uint8)
def _img(a):     return Image.fromarray(a, 'RGBA')
def _arr(img):   return np.array(img)
def _save(img, name):
    img.save(os.path.join(OUT, name))
    print(f"  {name}")


# ── Low-level primitives ─────────────────────────────────────────────────────

def _fill_circle(a, cx, cy, r, rgb):
    """Flat filled circle (no shading)."""
    pad = int(r) + 2
    y0, y1 = max(0, int(cy) - pad), min(SIZE, int(cy) + pad + 1)
    x0, x1 = max(0, int(cx) - pad), min(SIZE, int(cx) + pad + 1)
    if y0 >= y1 or x0 >= x1: return
    ys, xs = np.mgrid[y0:y1, x0:x1]
    m = (xs - cx) ** 2 + (ys - cy) ** 2 <= r * r
    for i, c in enumerate(rgb):
        a[y0:y1, x0:x1, i] = np.where(m, c, a[y0:y1, x0:x1, i])
    a[y0:y1, x0:x1, 3] = np.where(m, 255, a[y0:y1, x0:x1, 3])


def _fill_ellipse(a, cx, cy, rx, ry, rgb):
    """Flat filled ellipse (no shading)."""
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
    """Archero-style sphere: edge darkening + Phong specular + highlight spot."""
    pad = int(r) + 2
    y0, y1 = max(0, int(cy) - pad), min(SIZE, int(cy) + pad + 1)
    x0, x1 = max(0, int(cx) - pad), min(SIZE, int(cx) + pad + 1)
    if y0 >= y1 or x0 >= x1: return
    ys, xs = np.mgrid[y0:y1, x0:x1]
    dx = (xs - cx) / r;  dy = (ys - cy) / r
    d2 = dx * dx + dy * dy
    m  = d2 <= 1.0
    dz = np.where(m, np.sqrt(np.clip(1.0 - d2, 0, 1)), 0.0)

    dot  = np.clip(_L[0]*dx + _L[1]*dy + _L[2]*dz, 0, 1)
    # Edge darkening: spheres are dark at silhouette edge (key for "toy ball" look)
    edge = np.where(m, dz ** 0.42, 0.0)
    shad = edge * (amb + (1.0 - amb) * dot)

    # Phong specular (tight highlight)
    rz   = 2.0 * dot * dz - _L[2]
    spec = np.where(m, np.clip(rz, 0, 1) ** 30 * 0.65, 0.0)

    # Fixed bright spot upper-left (Archero "ceramic" look)
    hx = (xs - (cx - r * 0.30)) / max(r * 0.36, 1)
    hy = (ys - (cy - r * 0.30)) / max(r * 0.36, 1)
    h2 = hx * hx + hy * hy
    hi = np.where(m & (h2 <= 1.0), np.clip(1.0 - h2, 0, 1) ** 2.5 * 0.50, 0.0)

    cr, cg, cb = rgb
    ro = np.clip(cr * shad + 255.0 * spec * 0.50 + 255.0 * hi, 0, 255)
    go = np.clip(cg * shad + 255.0 * spec * 0.50 + 255.0 * hi, 0, 255)
    bo = np.clip(cb * shad + 255.0 * spec * 0.50 + 255.0 * hi, 0, 255)
    for i, ch in enumerate([ro, go, bo]):
        a[y0:y1, x0:x1, i] = np.where(m, ch, a[y0:y1, x0:x1, i])
    a[y0:y1, x0:x1, 3] = np.where(m, 255, a[y0:y1, x0:x1, 3])


def oval(a, cx, cy, rx, ry, rgb, amb=0.12):
    """Archero-style shaded ellipse with edge darkening."""
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


# ── Outline wrappers (draw dark silhouette first, then shaded on top) ─────────

def O_sphere(a, cx, cy, r, rgb):
    _fill_circle(a, int(cx), int(cy), r + OW, OUTLINE)
    sphere(a, cx, cy, r, rgb)

def O_oval(a, cx, cy, rx, ry, rgb):
    _fill_ellipse(a, int(cx), int(cy), rx + OW, ry + OW, OUTLINE)
    oval(a, cx, cy, rx, ry, rgb)


def _foot_shadow(a, alpha=60):
    """Soft drop shadow composited under the character."""
    sh = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    d  = ImageDraw.Draw(sh)
    d.ellipse([14, 57, 50, 64], fill=(0, 0, 0, alpha))
    sh = sh.filter(ImageFilter.GaussianBlur(3))
    return _arr(Image.alpha_composite(sh, _img(a)))


def _glow(a, cx, cy, r, color, strength=90):
    """Soft glow blob (used for boss eyes etc.)."""
    gl = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    d  = ImageDraw.Draw(gl)
    cr, cg, cb = color
    d.ellipse([int(cx-r), int(cy-r), int(cx+r), int(cy+r)], fill=(cr, cg, cb, strength))
    gl = gl.filter(ImageFilter.GaussianBlur(r * 0.9))
    return _arr(Image.alpha_composite(_img(a), gl))


# ── Walk offsets: (leg_lr, body_bob) ─────────────────────────────────────────
_W = ((0, 0), (3, 1), (0, 0), (-3, 1))


# ── PLAYER KNIGHT ─────────────────────────────────────────────────────────────
# Vivid blue armor, silver helmet with dark visor, chibi proportions.

_HELM  = (205, 210, 220)   # silver
_ARMOR = (65, 110, 220)    # vivid blue
_LEGS  = (40, 68, 158)     # dark blue
_PAUL  = (172, 180, 198)   # pauldron silver
_VISOR = (22, 28, 38)


def player_frame(frame: int) -> Image.Image:
    lx, by = _W[frame]
    a = _new()
    # Legs
    O_sphere(a, 25 + lx, 52 + by, 7, _LEGS)
    O_sphere(a, 39 - lx, 52 + by, 7, _LEGS)
    # Body
    O_oval(a, 32, 40 + by, 12, 9, _ARMOR)
    # Shoulders
    O_sphere(a, 17, 36 + by, 7, _PAUL)
    O_sphere(a, 47, 36 + by, 7, _PAUL)
    # Helmet
    O_sphere(a, 32, 20, 14, _HELM)
    # Visor slit
    img = _img(a); d = ImageDraw.Draw(img)
    d.rectangle([23, 19, 41, 23], fill=(*_VISOR, 225))
    a = _foot_shadow(_arr(img))
    return _img(a)


# ── GOBLIN ─────────────────────────────────────────────────────────────────────
# Vivid green, big angry red eyes, hunched with a club.

_GSKIN  = (80, 205, 58)
_GDARK  = (45, 138, 28)
_GEYE   = (240, 38, 0)
_GCLOTH = (152, 96, 28)


def goblin_frame(frame: int, attack: bool = False) -> Image.Image:
    lx, by = _W[frame]
    a = _new()
    O_sphere(a, 26 + lx, 52 + by, 6, _GDARK)
    O_sphere(a, 38 - lx, 52 + by, 6, _GDARK)
    O_oval(a, 32, 42 + by, 10, 8, _GCLOTH)
    O_oval(a, 32, 36 + by, 9, 7, _GSKIN)
    O_sphere(a, 32, 20, 15, _GSKIN)
    # Big angry eyes with outline
    _fill_circle(a, 24, 15, 6, OUTLINE); sphere(a, 24, 15, 5, _GEYE)
    _fill_circle(a, 40, 15, 6, OUTLINE); sphere(a, 40, 15, 5, _GEYE)
    # Pupils
    _fill_circle(a, 25, 16, 2, (8, 6, 6))
    _fill_circle(a, 41, 16, 2, (8, 6, 6))
    if attack:
        O_oval(a, 47, 37 + by, 5, 13, (105, 68, 28))
    a = _foot_shadow(a)
    return _img(a)


# ── SKELETON ARCHER ────────────────────────────────────────────────────────────
# Ivory bones, pitch-black hollow eye sockets, dark ragged cloth.

_SBONE  = (245, 234, 210)
_SDARK  = (162, 152, 130)
_SCLOTH = (70, 56, 40)


def skeleton_frame(frame: int, attack: bool = False) -> Image.Image:
    lx, by = _W[frame]
    a = _new()
    O_sphere(a, 26 + lx, 52 + by, 5, _SDARK)
    O_sphere(a, 38 - lx, 52 + by, 5, _SDARK)
    O_oval(a, 32, 43 + by, 9, 8, _SCLOTH)
    O_oval(a, 32, 36 + by, 7, 6, _SBONE)
    O_sphere(a, 32, 20, 13, _SBONE)
    # Dark hollow eye sockets
    _fill_circle(a, 25, 16, 5, OUTLINE); sphere(a, 25, 16, 4, (12, 10, 8))
    _fill_circle(a, 39, 16, 5, OUTLINE); sphere(a, 39, 16, 4, (12, 10, 8))
    img = _img(a)
    if attack:
        d = ImageDraw.Draw(img)
        d.arc([49, 6, 61, 42], start=-65, end=65, fill=(138, 90, 46, 255), width=2)
        d.line([55, 6, 55, 42], fill=(222, 198, 158, 180), width=1)
    a = _foot_shadow(_arr(img))
    return _img(a)


# ── CASTLE BOSS ──────────────────────────────────────────────────────────────
# Massive dark-red armor, giant pauldrons, bright orange glowing eyes.

_BARMOR = (168, 18, 18)
_BDARK  = (88, 8,  8)
_BHELM  = (192, 24, 24)
_BEYE   = (255, 115, 0)
_BMETAL = (120, 105, 105)


def boss_frame(frame: int, attack: bool = False) -> Image.Image:
    lx, by = _W[frame]
    a = _new()
    # Legs (thick)
    O_sphere(a, 23 + lx, 52 + by, 9, _BDARK)
    O_sphere(a, 41 - lx, 52 + by, 9, _BDARK)
    # Wide body
    O_oval(a, 32, 40 + by, 16, 12, _BARMOR)
    # Huge pauldrons
    O_sphere(a, 12, 35 + by, 11, _BMETAL)
    O_sphere(a, 52, 35 + by, 11, _BMETAL)
    # Large helmet
    O_sphere(a, 32, 19, 16, _BHELM)
    # Glowing eyes
    a = _glow(a, 25, 14, 7, _BEYE, 100)
    a = _glow(a, 39, 14, 7, _BEYE, 100)
    _fill_circle(a, 25, 14, 6, OUTLINE); sphere(a, 25, 14, 5, _BEYE)
    _fill_circle(a, 39, 14, 6, OUTLINE); sphere(a, 39, 14, 5, _BEYE)
    _fill_circle(a, 25, 15, 2, (255, 225, 120))
    _fill_circle(a, 39, 15, 2, (255, 225, 120))
    if attack:
        O_oval(a, 52, 38 + by, 5, 16, _BMETAL)
    a = _foot_shadow(a, alpha=75)
    return _img(a)


# ── SHADOWS ──────────────────────────────────────────────────────────────────

def make_shadow(name, w, h):
    img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    d   = ImageDraw.Draw(img)
    cx, cy = SIZE // 2, SIZE // 2 + 2
    d.ellipse([cx - w, cy - h, cx + w, cy + h], fill=(0, 0, 0, 62))
    img = img.filter(ImageFilter.GaussianBlur(3))
    _save(img, name)


# ── MAIN ─────────────────────────────────────────────────────────────────────

def main():
    print("Generating Archero-style sprites (64x64)...")

    make_shadow("shadow_small.png", 10, 5)
    make_shadow("shadow_large.png", 16, 8)

    for i in range(4):
        _save(player_frame(i), f"player_walk_{i}.png")

    for i in range(4):
        _save(goblin_frame(i), f"enemy_goblin_walk_{i}.png")
    _save(goblin_frame(0, attack=True), "enemy_goblin_attack_0.png")

    for i in range(4):
        _save(skeleton_frame(i), f"enemy_skeleton_walk_{i}.png")
    _save(skeleton_frame(0, attack=True), "enemy_skeleton_attack_0.png")

    for i in range(4):
        _save(boss_frame(i), f"enemy_boss_walk_{i}.png")
    _save(boss_frame(0, attack=True), "enemy_boss_attack_0.png")

    print(f"Done! 21 sprites -> {OUT}")


if __name__ == "__main__":
    main()
