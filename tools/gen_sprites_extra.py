"""gen_sprites_extra.py — tiles + enemies for swamp, ruins, volcano."""
import sys, math, os
import numpy as np
from PIL import Image, ImageDraw

TILE_DIR = r"C:\!DB\game_ai\assets\tilesets"
SPR_DIR  = r"C:\!DB\game_ai\assets\sprites"
SIZE = 64
OUTLINE = (18, 14, 22)
OW = 2

def _img(w, h):
    return np.zeros((h, w, 4), dtype=np.uint8)

def _save(a, path):
    Image.fromarray(a, "RGBA").save(path)
    print("  ->", os.path.basename(path))

def sphere(a, cx, cy, r, rgb):
    H, W = a.shape[:2]
    for py in range(max(0,int(cy-r)-1), min(H,int(cy+r)+2)):
        for px in range(max(0,int(cx-r)-1), min(W,int(cx+r)+2)):
            dx=px-cx; dy=py-cy
            if dx*dx+dy*dy > r*r: continue
            d2=dx*dx+dy*dy
            dz=math.sqrt(max(0,r*r-d2))/r
            edge=max(0.0,dz**0.42)
            nx=dx/r; ny=dy/r; nz=dz
            lx,ly,lz=-0.5,-0.7,0.8
            ln=math.sqrt(lx*lx+ly*ly+lz*lz); lx/=ln; ly/=ln; lz/=ln
            diff=max(0,nx*lx+ny*ly+nz*lz)
            spec=max(0,nz)**14*0.5
            col=tuple(int(min(255,rgb[i]*(0.25+0.75*diff)*edge+255*spec)) for i in range(3))
            hx=cx-r*0.35; hy=cy-r*0.38
            if math.sqrt((px-hx)**2+(py-hy)**2)<r*0.22:
                t=1-math.sqrt((px-hx)**2+(py-hy)**2)/(r*0.22)
                col=tuple(int(min(255,col[i]*(1-t*0.7)+255*t*0.7)) for i in range(3))
            a[py,px]=[col[0],col[1],col[2],255]

def oval(a, cx, cy, rx, ry, rgb):
    H, W = a.shape[:2]
    for py in range(max(0,int(cy-ry)-1), min(H,int(cy+ry)+2)):
        for px in range(max(0,int(cx-rx)-1), min(W,int(cx+rx)+2)):
            ex=(px-cx)/rx; ey=(py-cy)/ry
            if ex*ex+ey*ey>1: continue
            dz=math.sqrt(max(0,1-ex*ex-ey*ey))
            edge=max(0.0,dz**0.42)
            nx=ex; ny=ey; nz=dz
            lx,ly,lz=-0.5,-0.7,0.8
            ln=math.sqrt(lx*lx+ly*ly+lz*lz); lx/=ln; ly/=ln; lz/=ln
            diff=max(0,nx*lx+ny*ly+nz*lz)
            spec=max(0,nz)**14*0.5
            col=tuple(int(min(255,rgb[i]*(0.25+0.75*diff)*edge+255*spec)) for i in range(3))
            a[py,px]=[col[0],col[1],col[2],255]

def O_sphere(a, cx, cy, r, rgb):
    sphere(a, cx, cy, r+OW, OUTLINE); sphere(a, cx, cy, r, rgb)

def O_oval(a, cx, cy, rx, ry, rgb):
    oval(a, cx, cy, rx+OW, ry+OW, OUTLINE); oval(a, cx, cy, rx, ry, rgb)

_W = ((0,0),(3,1),(0,0),(-3,1))

def _shadow(a):
    for py in range(56,64):
        for px in range(22,42):
            t=1-abs(px-32)/10; s=1-abs(py-60)/4
            if t>0 and s>0: a[py,px,3]=int(min(255,a[py,px,3]+60*t*s))

# ── Tiles ─────────────────────────────────────────────────────────────────

def floor_tile(r, g, b):
    a = _img(32, 32)
    img = Image.fromarray(a, "RGBA"); draw = ImageDraw.Draw(img)
    draw.rectangle([0,0,31,31], fill=(r,g,b,255))
    rng = np.random.RandomState(r+g*3+b*7)
    for _ in range(14):
        x=int(rng.randint(0,32)); y=int(rng.randint(0,32))
        dr=int(rng.randint(-18,18)); dg=int(rng.randint(-18,18)); db=int(rng.randint(-18,18))
        draw.ellipse([x-3,y-3,x+3,y+3],
            fill=(max(0,min(255,r+dr)),max(0,min(255,g+dg)),max(0,min(255,b+db)),255))
    return np.array(img)

def wall_tile(r, g, b):
    a = _img(32, 40)
    img = Image.fromarray(a, "RGBA"); draw = ImageDraw.Draw(img)
    top = (min(255,r+28), min(255,g+28), min(255,b+28), 255)
    draw.rectangle([0,0,31,10], fill=top)
    draw.rectangle([0,10,31,39], fill=(r,g,b,255))
    dark = (max(0,r-22), max(0,g-22), max(0,b-22), 255)
    for y in [14,20,26,32,38]: draw.line([(0,y),(31,y)], fill=dark, width=1)
    for x in [0,10,21]: draw.line([(x,10),(x,39)], fill=dark, width=1)
    return np.array(img)

def tile_water():
    a = _img(32, 40)
    img = Image.fromarray(a, "RGBA"); draw = ImageDraw.Draw(img)
    draw.rectangle([0,0,31,39], fill=(18,42,62,255))
    for y in [8,18,28]: draw.arc([3,y,26,y+7], 0, 180, fill=(32,65,88,255), width=2)
    draw.ellipse([2,4,11,9],   fill=(38,68,32,255))
    draw.ellipse([19,23,28,28],fill=(38,68,32,255))
    draw.ellipse([5,30,14,36], fill=(38,68,32,255))
    return np.array(img)

def tile_wall_volcano():
    a = _img(32, 40)
    img = Image.fromarray(a, "RGBA"); draw = ImageDraw.Draw(img)
    draw.rectangle([0,0,31,10],  fill=(42,16,6,255))
    draw.rectangle([0,10,31,39], fill=(26,10,4,255))
    lava = (200,78,10,255)
    draw.line([(5,13),(10,20),(7,30)],  fill=lava, width=1)
    draw.line([(20,12),(25,22),(21,34)],fill=lava, width=1)
    draw.line([(14,10),(18,17)],        fill=lava, width=1)
    return np.array(img)

# ── Enemies ───────────────────────────────────────────────────────────────

def swamp_shaman(frame, attack=False):
    a=_img(SIZE,SIZE); dx,dy=_W[frame%4]
    SK=(50,125,50); RO=(105,38,140); EY=(240,210,0)
    O_oval(a,32+dx,46+dy,10,12,RO)
    O_oval(a,27+dx,55+dy,4,6,RO); O_oval(a,37+dx,55+dy,4,6,RO)
    ax=3 if attack else 1
    O_oval(a,18+dx+ax,42+dy,5,7,SK); O_oval(a,46+dx-ax,42+dy,5,7,SK)
    if attack:
        for py in range(28,58):
            for px in range(12,15):
                if 0<=py<SIZE and 0<=px<SIZE: a[py,px]=[75,48,18,255]
        O_sphere(a,13+dx,26+dy,6,(0,195,175))
    O_sphere(a,32+dx,26+dy,12,SK)
    O_sphere(a,27+dx,24+dy,3,EY); O_sphere(a,37+dx,24+dy,3,EY)
    _shadow(a); return a

def swamp_golem(frame, attack=False):
    a=_img(SIZE,SIZE); dx,dy=_W[frame%4]
    MU=(88,62,32); DK=(52,36,16); EY=(0,195,75)
    O_oval(a,32+dx,44+dy,16,14,MU)
    sl=6 if attack else 0
    O_oval(a,12+dx-sl,44+dy,9,11,DK); O_oval(a,52+dx+sl,44+dy,9,11,DK)
    O_oval(a,24+dx,56+dy,7,7,MU); O_oval(a,40+dx,56+dy,7,7,MU)
    O_sphere(a,32+dx,24+dy,14,MU)
    O_sphere(a,24+dx,22+dy,4,EY); O_sphere(a,40+dx,22+dy,4,EY)
    _shadow(a); return a

def ghost(frame, attack=False):
    a=_img(SIZE,SIZE); dx,dy=_W[frame%4]
    GH=(138,168,218); GL=(175,198,252); EY=(48,96,200)
    O_oval(a,32+dx,44+dy,10,14,GH)
    O_oval(a,32+dx,55+dy,7,8,GH)
    O_oval(a,18+dx,42+dy,6,8,GH); O_oval(a,46+dx,42+dy,6,8,GH)
    O_sphere(a,32+dx,25+dy,13,GL)
    O_sphere(a,26+dx,23+dy,4,EY); O_sphere(a,38+dx,23+dy,4,EY)
    for py in range(SIZE):
        for px in range(SIZE):
            if a[py,px,3]>0: a[py,px,3]=min(255,int(a[py,px,3]*0.80))
    if attack: O_sphere(a,50+dx,34+dy,6,(95,145,255))
    _shadow(a); return a

def lich(frame, attack=False):
    a=_img(SIZE,SIZE); dx,dy=_W[frame%4]
    RO=(52,18,78); BO=(218,208,182); EY=(175,0,250)
    O_oval(a,32+dx,46+dy,11,13,RO)
    ax=4 if attack else 0
    O_oval(a,17+dx+ax,40+dy,5,8,BO); O_oval(a,47+dx-ax,40+dy,5,8,BO)
    O_sphere(a,32+dx,23+dy,13,BO)
    O_sphere(a,26+dx,21+dy,4,(18,0,28)); O_sphere(a,38+dx,21+dy,4,(18,0,28))
    O_sphere(a,26+dx,21+dy,2,EY); O_sphere(a,38+dx,21+dy,2,EY)
    if attack: O_sphere(a,50+dx,32+dy,6,(95,0,175))
    _shadow(a); return a

def fire_imp(frame, attack=False):
    a=_img(SIZE,SIZE); dx,dy=_W[frame%4]
    SK=(208,68,14); DK=(138,28,4); EY=(255,215,0)
    O_oval(a,32+dx,46+dy,8,10,SK)
    O_oval(a,26+dx,56+dy,4,5,DK); O_oval(a,38+dx,56+dy,4,5,DK)
    ax=5 if attack else 1
    O_oval(a,20+dx+ax,42+dy,4,6,SK); O_oval(a,44+dx-ax,42+dy,4,6,SK)
    O_sphere(a,32+dx,30+dy,11,SK)
    O_oval(a,25+dx,20+dy,3,5,DK); O_oval(a,39+dx,20+dy,3,5,DK)
    O_sphere(a,28+dx,29+dy,3,EY); O_sphere(a,36+dx,29+dy,3,EY)
    _shadow(a); return a

def magma_titan(frame, attack=False):
    a=_img(SIZE,SIZE); dx,dy=_W[frame%4]
    RK=(68,24,8); LA=(215,88,18); EY=(255,175,0)
    O_oval(a,32+dx,44+dy,18,16,RK)
    for bx,by,br in [(26,38,3),(38,40,4),(30,50,2),(36,48,3)]: O_sphere(a,bx+dx,by+dy,br,LA)
    sl=8 if attack else 2
    O_oval(a,10+dx-sl,42+dy,10,12,RK); O_oval(a,54+dx+sl,42+dy,10,12,RK)
    O_sphere(a,10+dx-sl,53+dy,7,LA); O_sphere(a,54+dx+sl,53+dy,7,LA)
    O_sphere(a,32+dx,22+dy,15,RK)
    O_sphere(a,25+dx,20+dy,5,EY); O_sphere(a,39+dx,20+dy,5,EY)
    _shadow(a); return a

def main():
    os.makedirs(TILE_DIR, exist_ok=True)
    os.makedirs(SPR_DIR,  exist_ok=True)

    print("=== Tiles ===")
    _save(floor_tile(58,80,36),  f"{TILE_DIR}/tile_floor_swamp.png")
    _save(tile_water(),          f"{TILE_DIR}/tile_water.png")
    _save(floor_tile(105,98,82), f"{TILE_DIR}/tile_floor_ruins.png")
    _save(wall_tile(68,62,52),   f"{TILE_DIR}/tile_wall_ruins.png")
    _save(floor_tile(55,22,8),   f"{TILE_DIR}/tile_floor_volcano.png")
    _save(tile_wall_volcano(),   f"{TILE_DIR}/tile_wall_volcano.png")

    print("=== Swamp Shaman ===")
    for i in range(4): _save(swamp_shaman(i),     f"{SPR_DIR}/enemy_shaman_walk_{i}.png")
    _save(swamp_shaman(0, True),                   f"{SPR_DIR}/enemy_shaman_attack_0.png")

    print("=== Swamp Golem (boss) ===")
    for i in range(4): _save(swamp_golem(i),       f"{SPR_DIR}/enemy_golem_walk_{i}.png")
    _save(swamp_golem(0, True),                    f"{SPR_DIR}/enemy_golem_attack_0.png")

    print("=== Ghost ===")
    for i in range(4): _save(ghost(i),             f"{SPR_DIR}/enemy_ghost_walk_{i}.png")
    _save(ghost(0, True),                          f"{SPR_DIR}/enemy_ghost_attack_0.png")

    print("=== Lich (boss) ===")
    for i in range(4): _save(lich(i),              f"{SPR_DIR}/enemy_lich_walk_{i}.png")
    _save(lich(0, True),                           f"{SPR_DIR}/enemy_lich_attack_0.png")

    print("=== Fire Imp ===")
    for i in range(4): _save(fire_imp(i),          f"{SPR_DIR}/enemy_imp_walk_{i}.png")
    _save(fire_imp(0, True),                       f"{SPR_DIR}/enemy_imp_attack_0.png")

    print("=== Magma Titan (boss) ===")
    for i in range(4): _save(magma_titan(i),       f"{SPR_DIR}/enemy_magma_walk_{i}.png")
    _save(magma_titan(0, True),                    f"{SPR_DIR}/enemy_magma_attack_0.png")

    print("\nDone! 36 files.")

if __name__ == "__main__":
    main()
