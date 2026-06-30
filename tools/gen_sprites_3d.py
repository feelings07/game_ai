#!/usr/bin/env python3
"""
Generate 3D-shaded top-down NPC sprites using Phong shading via numpy.
Viewer angle: ~60° from above (2.5D top-down perspective).
"""
import os, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SIZE = 48
OUT = r"C:\!DB\game_ai\assets\sprites"
os.makedirs(OUT, exist_ok=True)

# Light direction: upper-left-front, normalized
_L = np.array([0.45, -0.55, 0.70], dtype=np.float64)
_L /= np.linalg.norm(_L)


def _new():
    return np.zeros((SIZE, SIZE, 4), dtype=np.uint8)


def sphere(a, cx, cy, r, rgb, amb=0.18):
    """Phong-shaded sphere drawn onto numpy RGBA array (overwrites pixels inside)."""
    pad = int(r) + 2
    y0, y1 = max(0, int(cy) - pad), min(SIZE, int(cy) + pad + 1)
    x0, x1 = max(0, int(cx) - pad), min(SIZE, int(cx) + pad + 1)
    if y0 >= y1 or x0 >= x1:
        return
    ys, xs = np.mgrid[y0:y1, x0:x1]
    dx = (xs - cx) / r
    dy = (ys - cy) / r
    d2 = dx * dx + dy * dy
    m = d2 <= 1.0
    dz = np.where(m, np.sqrt(np.clip(1.0 - d2, 0.0, 1.0)), 0.0)
    dot = np.clip(_L[0]*dx + _L[1]*dy + _L[2]*dz, 0.0, 1.0)
    diff = np.where(m, amb + (1.0 - amb) * dot, 0.0)
    rz = 2.0 * dot * dz - _L[2]                         # reflection z toward viewer
    spec = np.where(m, np.clip(rz, 0, 1) ** 18 * 0.55, 0.0)
    for i, c in enumerate(rgb):
        ch = np.clip(c * diff + 255.0 * spec * 0.80, 0, 255)
        a[y0:y1, x0:x1, i] = np.where(m, ch, a[y0:y1, x0:x1, i])
    a[y0:y1, x0:x1, 3] = np.where(m, 255, a[y0:y1, x0:x1, 3])


def ellipse(a, cx, cy, rx, ry, rgb, amb=0.20):
    """Cylinder-shaded ellipse (shading from horizontal normal)."""
    px, py = int(rx) + 2, int(ry) + 2
    y0, y1 = max(0, int(cy) - py), min(SIZE, int(cy) + py + 1)
    x0, x1 = max(0, int(cx) - px), min(SIZE, int(cx) + px + 1)
    if y0 >= y1 or x0 >= x1:
        return
    ys, xs = np.mgrid[y0:y1, x0:x1]
    ex = (xs - cx) / rx
    ey = (ys - cy) / ry
    m = ex * ex + ey * ey <= 1.0
    nx = ex
    nz = np.sqrt(np.clip(1.0 - nx * nx, 0.0, 1.0))
    diff = np.where(m,
                    np.clip(amb + (1.0 - amb) * np.clip(_L[0]*nx + _L[2]*nz, 0, 1), 0, 1),
                    0.0)
    for i, c in enumerate(rgb):
        ch = np.clip(c * diff, 0, 255)
        a[y0:y1, x0:x1, i] = np.where(m, ch, a[y0:y1, x0:x1, i])
    a[y0:y1, x0:x1, 3] = np.where(m, 255, a[y0:y1, x0:x1, 3])


def _save(img, name):
    path = os.path.join(OUT, name)
    img.save(path)
    print(f"  {name}")


def _arr(a): return Image.fromarray(a, 'RGBA')


# ── SHADOWS ──────────────────────────────────────────────────────────────────

def make_shadow(name, w, h):
    img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = SIZE // 2, SIZE // 2 + 3
    d.ellipse([cx - w, cy - h, cx + w, cy + h], fill=(0, 0, 0, 68))
    img = img.filter(ImageFilter.GaussianBlur(3))
    _save(img, name)


# ── PLAYER ───────────────────────────────────────────────────────────────────
# Blue armored knight viewed from ~60° above.

_HELM  = (165, 172, 188)   # silver helmet
_ARMOR = (82, 106, 198)    # blue armor
_LEGS  = (56, 74, 140)     # dark blue legs
_VISOR = (28, 33, 44)      # dark visor

# Walk offsets: frame → (leg_lr, body_bob)
_WALK = ((0, 0), (2, 1), (0, 0), (-2, 1))


def player_frame(frame: int) -> Image.Image:
    lx, by = _WALK[frame]
    a = _new()
    sphere(a, 20 + lx, 37 + by, 5.5, _LEGS)
    sphere(a, 28 - lx, 37 + by, 5.5, _LEGS)
    ellipse(a, 24, 28 + by, 9, 8, _ARMOR)
    sphere(a, 15, 25 + by, 5.0, _HELM)
    sphere(a, 33, 25 + by, 5.0, _HELM)
    sphere(a, 24, 17, 10, _HELM)
    img = _arr(a)
    d = ImageDraw.Draw(img)
    d.rectangle([18, 16, 30, 20], fill=(*_VISOR, 210))
    return img


# ── GOBLIN ───────────────────────────────────────────────────────────────────
# Small, hunched, green skin, orange eyes.

_GSKIN  = (85, 155, 65)
_GDARK  = (50, 105, 35)
_GEYE   = (255, 148, 0)
_GCLOTH = (112, 76, 26)


def goblin_frame(frame: int, attack: bool = False) -> Image.Image:
    lx, by = _WALK[frame]
    a = _new()
    sphere(a, 20 + lx, 38 + by, 5.0, _GDARK)
    sphere(a, 28 - lx, 38 + by, 5.0, _GDARK)
    ellipse(a, 24, 30 + by, 8, 7, _GCLOTH)
    ellipse(a, 24, 25 + by, 7, 6, _GSKIN)
    sphere(a, 24, 17, 11, _GSKIN)
    sphere(a, 20, 15, 3.0, _GEYE)
    sphere(a, 28, 15, 3.0, _GEYE)
    if attack:
        ellipse(a, 36, 26, 4, 10, (90, 58, 28))   # wooden club
    img = _arr(a)
    d = ImageDraw.Draw(img)
    d.ellipse([19, 14, 22, 17], fill=(0, 0, 0, 255))
    d.ellipse([27, 14, 30, 17], fill=(0, 0, 0, 255))
    return img


# ── SKELETON ARCHER ───────────────────────────────────────────────────────────
# Bone-colored skull, ragged cloth, bow drawn to side when attacking.

_SBONE  = (232, 222, 197)
_SDARK  = (155, 145, 126)
_SCLOTH = (75, 62, 46)
_SEYE   = (12, 10, 10)


def skeleton_frame(frame: int, attack: bool = False) -> Image.Image:
    lx, by = _WALK[frame]
    a = _new()
    sphere(a, 21 + lx, 38 + by, 4.5, _SDARK)
    sphere(a, 27 - lx, 38 + by, 4.5, _SDARK)
    ellipse(a, 24, 30 + by, 7, 8, _SCLOTH)
    ellipse(a, 24, 26 + by, 6, 6, _SBONE)
    sphere(a, 24, 17, 10, _SBONE)
    sphere(a, 20, 15, 3.5, _SEYE)
    sphere(a, 28, 15, 3.5, _SEYE)
    img = _arr(a)
    d = ImageDraw.Draw(img)
    if attack:
        d.arc([35, 8, 46, 38], start=-65, end=65, fill=(132, 86, 42, 255), width=2)
        d.line([41, 8, 41, 38], fill=(215, 192, 152, 190), width=1)
    return img


# ── CASTLE BOSS ───────────────────────────────────────────────────────────────
# Large dark-red armored knight, orange glowing eyes, huge shoulders.

_BARMOR = (68, 18, 18)
_BDARK  = (40, 10, 10)
_BHELM  = (85, 26, 26)
_BEYE   = (255, 92, 0)
_BMETAL = (108, 94, 94)


def boss_frame(frame: int, attack: bool = False) -> Image.Image:
    lx, by = _WALK[frame]
    a = _new()
    sphere(a, 19 + lx, 38 + by, 7.0, _BDARK)
    sphere(a, 29 - lx, 38 + by, 7.0, _BDARK)
    ellipse(a, 24, 28 + by, 12, 10, _BARMOR)
    sphere(a, 11, 24 + by, 7.5, _BMETAL)
    sphere(a, 37, 24 + by, 7.5, _BMETAL)
    sphere(a, 24, 15, 12, _BHELM)
    sphere(a, 19, 12,  4.0, _BEYE)
    sphere(a, 29, 12,  4.0, _BEYE)
    if attack:
        ellipse(a, 40, 22, 4, 14, _BMETAL)   # greatsword
    return _arr(a)


# ── GENERATE ALL ─────────────────────────────────────────────────────────────

def main():
    print("Generating 3D NPC sprites (Phong shading)...")

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

    print(f"\nDone! {2 + 4 + 5 + 5 + 5} sprites -> {OUT}")


if __name__ == "__main__":
    main()
