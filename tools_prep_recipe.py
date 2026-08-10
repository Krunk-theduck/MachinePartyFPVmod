#!/usr/bin/env python3
"""Normalize the Firearm-Factory recipe/gun sprite sheets into clean, uniform, centered,
transparent sheets the mod can draw without jitter. Originals are backed up in _src/.

Run from the mod's textures/recipe folder (or pass it as argv[1])."""
import os, sys, shutil, glob
import numpy as np
from PIL import Image

ROOT = sys.argv[1] if len(sys.argv) > 1 else "Jarunk-MachinePartyFPV/textures/recipe"
SRC = os.path.join(ROOT, "_src")
os.makedirs(SRC, exist_ok=True)

# back up whatever source files exist (once)
for f in ["great.png","gear.png","spring.png","strapped.png","pipe.png","glue1.png","glue2.png","gun.png"]:
    p = os.path.join(ROOT, f)
    if os.path.exists(p) and not os.path.exists(os.path.join(SRC, f)):
        shutil.copy(p, os.path.join(SRC, f))

def load(name):
    return Image.open(os.path.join(SRC, name)).convert("RGBA")

def alpha_from_black(im):
    a = np.array(im).astype(np.float32)
    lum = 0.299*a[:,:,0] + 0.587*a[:,:,1] + 0.114*a[:,:,2]
    a[:,:,3] = np.clip((lum-10.0)/(34.0-10.0), 0, 1) * 255.0
    return Image.fromarray(a.astype(np.uint8), "RGBA")

def cut_halo(im):
    a = np.array(im)
    a[:,:,3] = np.where(a[:,:,3] < 36, 0, a[:,:,3])
    return Image.fromarray(a, "RGBA")

def split(im, cols, rows):
    W,H = im.size; cw=W//cols; ch=H//rows
    return [im.crop((c*cw, r*ch, (c+1)*cw, (r+1)*ch)) for r in range(rows) for c in range(cols)]

def build(frames, cols, rows, out, fw=220, fh=220):
    sheet = Image.new("RGBA", (cols*fw, rows*fh), (0,0,0,0))
    for i, fr in enumerate(frames):
        bb = fr.getbbox()
        if bb: fr = fr.crop(bb)
        if fr.width==0 or fr.height==0: continue
        s = min(fw*0.92/fr.width, fh*0.92/fr.height)
        fr = fr.resize((max(1,round(fr.width*s)), max(1,round(fr.height*s))), Image.LANCZOS)
        r=i//cols; c=i%cols
        sheet.paste(fr, (c*fw + (fw-fr.width)//2, r*fh + (fh-fr.height)//2), fr)
    sheet.save(os.path.join(ROOT, out))
    print(f"  {out}: {cols}x{rows}")

# --- recipe items with transparent backgrounds ---
gear_src = "great.png" if os.path.exists(os.path.join(SRC,"great.png")) else "gear.png"
for src, cols, rows, out in [(gear_src,2,2,"gear.png"), ("spring.png",2,2,"spring.png"),
                             ("strapped.png",2,2,"strapped.png"), ("pipe.png",2,1,"pipe.png")]:
    build(split(cut_halo(load(src)), cols, rows), cols, rows, out)

# --- glue: two separate files -> a 2-frame sheet (opaque black bg) ---
build([alpha_from_black(load("glue1.png")), alpha_from_black(load("glue2.png"))], 2, 1, "glue.png")

# --- gun: 2-frame sheet (plain=ready, red-lit=reloading), opaque black bg -> its own aspect ---
build(split(alpha_from_black(load("gun.png")), 2, 1), 2, 1, "gun.png", fw=300, fh=200)

# tidy up loose source files so only the clean sheets remain in the folder
for f in ["great.png","glue1.png","glue2.png"]:
    p=os.path.join(ROOT,f)
    if os.path.exists(p): os.remove(p)
print("done")
