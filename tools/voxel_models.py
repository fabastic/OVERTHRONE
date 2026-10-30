"""OVERTHRONE voxel models, built in Blender and exported as .glb for Godot.

Run headless:
    blender --background --factory-startup --python tools/voxel_models.py -- <project dir>

Everything is made of 1/16 m voxels with a pixel-palette texture (one texel per colour, nearest
filtering), in the chunky Barony style. Glowing voxels (eyes, visors, aether cores) use a second,
emissive material. Characters are exported as separate PARTS whose origins sit at the joints the
game animates (leg_l, leg_r, torso, head, arm_l, arm_r, and for the tall frame fore_l / fore_r),
so the procedural animation in npc.gd / hero.gd / day_enemy.gd / stranger.gd drives them unchanged.

Coordinates in the recipes are Godot's: x right, y up, -z forward (the face is at the front, k = 0).
"""
import bpy
import bmesh
import math
import os
import random
import sys
import zlib

V = 1.0 / 16.0  # voxel size in metres


def h32(x):
    """A stable hash (Python's own hash() changes every run)."""
    return zlib.crc32(repr(x).encode())

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
PROJECT = argv[0] if argv else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(PROJECT, "assets", "models")
os.makedirs(OUT, exist_ok=True)


def clamp01(x):
    return max(0.0, min(1.0, x))


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def dark(c, t):
    return mix(c, (0, 0, 0), t)


def light(c, t):
    return mix(c, (1, 1, 1), t)


def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


# ---------------------------------------------------------------------------------------------
# A part: a sparse voxel grid with a pivot
# ---------------------------------------------------------------------------------------------

class Part:
    """w, h, d = the nominal box in voxels. anchor 'top' hangs the box below the pivot (legs,
    arms), 'bottom' stands it on the pivot (torso, head). Voxels may go outside the box."""

    def __init__(self, name, w, h, d, anchor="bottom", seed=0):
        self.name = name
        self.w, self.h, self.d = w, h, d
        self.anchor = anchor
        self.vox = {}
        self.rng = random.Random(h32((name, seed)) & 0xFFFFFFFF)

    def put(self, i, j, k, c, glow=False, jit=0.07):
        if c is None:
            self.vox.pop((i, j, k), None)
            return
        if jit > 0:
            f = 1.0 + self.rng.uniform(-jit, jit)
            c = tuple(clamp01(x * f) for x in c)
        self.vox[(i, j, k)] = (c, glow)

    def box(self, i0, j0, k0, i1, j1, k1, c, glow=False, jit=0.07):
        """Fill the half-open box [i0,i1) x [j0,j1) x [k0,k1)."""
        for i in range(i0, i1):
            for j in range(j0, j1):
                for k in range(k0, k1):
                    self.put(i, j, k, c, glow, jit)

    def shell(self, c, jit=0.07):
        self.box(0, 0, 0, self.w, self.h, self.d, c, jit=jit)

    def front(self, i, j, c, glow=False, depth=0, jit=0.05):
        """Paint a voxel on the front face (k = depth) - an eye, a buckle, a stripe."""
        self.put(i, j, depth, c, glow, jit)

    def has(self, i, j, k):
        return (i, j, k) in self.vox

    def origin(self):
        oy = -self.h if self.anchor == "top" else 0
        return (-self.w / 2.0, oy, -self.d / 2.0)


# ---------------------------------------------------------------------------------------------
# Mesh + material building, export
# ---------------------------------------------------------------------------------------------

DIRS = [
    ((1, 0, 0), [(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)]),
    ((-1, 0, 0), [(0, 0, 1), (0, 1, 1), (0, 1, 0), (0, 0, 0)]),
    ((0, 1, 0), [(0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0)]),
    ((0, -1, 0), [(0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)]),
    ((0, 0, 1), [(1, 0, 1), (1, 1, 1), (0, 1, 1), (0, 0, 1)]),
    ((0, 0, -1), [(0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0)]),
]


def quant(c):
    return tuple(round(x * 40) / 40.0 for x in c)


class Model:
    def __init__(self, name):
        self.name = name
        self.parts = []

    def add(self, part):
        self.parts.append(part)
        return part

    def build(self):
        # Palette: every distinct (quantised) colour gets one texel
        keys = []
        index = {}
        for p in self.parts:
            for (c, g) in p.vox.values():
                q = quant(c)
                if q not in index:
                    index[q] = len(keys)
                    keys.append(q)
        size = 8
        while size * size < len(keys):
            size *= 2
        img = bpy.data.images.new(self.name + "_pal", size, size, alpha=False)
        px = [0.0] * (size * size * 4)
        for n, c in enumerate(keys):
            x, y = n % size, n // size
            o = (y * size + x) * 4
            # Blender images are linear; the texture is read as sRGB, so store sRGB values.
            px[o:o + 4] = [c[0], c[1], c[2], 1.0]
        img.pixels = px
        img.pack()
        mat_base = self._material(self.name + "_base", img, False)
        mat_glow = self._material(self.name + "_glow", img, True)
        objs = []
        for p in self.parts:
            objs.append(self._mesh(p, index, size, mat_base, mat_glow))
        return objs

    def _material(self, name, img, glow):
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        nt = m.node_tree
        bsdf = nt.nodes.get("Principled BSDF")
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = img
        tex.interpolation = "Closest"
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.95
        if glow:
            nt.links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
            bsdf.inputs["Emission Strength"].default_value = 4.0
        return m

    def _mesh(self, p, index, size, mat_base, mat_glow):
        ox, oy, oz = p.origin()
        vs = getattr(p, "v", V)  # parts may use their own voxel size (the hands are finer)
        verts, faces, uvs, mats = [], [], [], []
        for (i, j, k), (c, g) in p.vox.items():
            for (n, corners) in DIRS:
                if (i + n[0], j + n[1], k + n[2]) in p.vox:
                    continue
                base = len(verts)
                for (cx, cy, cz) in corners:
                    gx = (i + cx + ox) * vs
                    gy = (j + cy + oy) * vs
                    gz = (k + cz + oz) * vs
                    verts.append((gx, -gz, gy))  # Godot (x, y, z) -> Blender (x, -z, y)
                faces.append([base, base + 1, base + 2, base + 3])
                n_idx = index[quant(c)]
                u = (n_idx % size + 0.5) / size
                v = (n_idx // size + 0.5) / size  # Blender image rows start at the bottom
                uvs.append((u, v))
                mats.append(1 if g else 0)
        me = bpy.data.meshes.new(p.name)
        me.from_pydata(verts, [], faces)
        me.update()
        uv = me.uv_layers.new(name="UVMap")
        for f_i, poly in enumerate(me.polygons):
            poly.material_index = mats[f_i]
            for li in poly.loop_indices:
                uv.data[li].uv = uvs[f_i]
        me.materials.append(mat_base)
        me.materials.append(mat_glow)
        # The corner order in DIRS already winds every face outward (counter-clockwise seen from
        # outside). No normal recalculation: on separate quads it flips some of them inward.
        ob = bpy.data.objects.new(p.name, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


def reset_scene():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for item in list(coll):
            coll.remove(item)


def export(model):
    reset_scene()
    objs = model.build()
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objs:
        ob.select_set(True)
    path = os.path.join(OUT, model.name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=False, export_materials="EXPORT")
    print("[VOX] wrote", path, sum(len(p.vox) for p in model.parts), "voxels")


# ---------------------------------------------------------------------------------------------
# Shared painters
# ---------------------------------------------------------------------------------------------

SKINS = [hexc("eab78e"), hexc("cc946b"), hexc("9a6b4c"), hexc("f5cba8")]
BOOT = hexc("3e281a")
BELT = hexc("4a2c18")
GOLD = hexc("d9a636")
STEEL = hexc("9a9ea8")


def face(head, skin, hair, eyes=(0.12, 0.1, 0.1), style="", z=0, glow_eyes=None):
    """Paint a face on the front of a head (any width >= 5)."""
    w, h = head.w, head.h
    ey = h // 2
    lx, rx = w // 2 - 2, w - (w // 2 - 2) - 1
    for x in (lx, rx):
        if glow_eyes:
            head.front(x, ey, glow_eyes, glow=True, depth=z)
        else:
            head.front(x, ey, (0.95, 0.95, 0.92), depth=z)
            head.front(x + (1 if x == lx else -1) * 0, ey, eyes, depth=z)
    # brows
    for x in (lx, rx):
        head.front(x, ey + 1, dark(hair, 0.2) if hair else dark(skin, 0.25), depth=z)
    # nose (a voxel that sticks out) and mouth
    head.put(w // 2 - (0 if w % 2 else 1), ey - 1, z - 1, dark(skin, 0.08))
    if w % 2 == 0:
        head.put(w // 2, ey - 1, z - 1, dark(skin, 0.08))
    for x in range(w // 2 - 1, w - (w // 2 - 1)):
        head.front(x, 1, dark(skin, 0.35), depth=z)
    if style in ("beard", "stubble"):
        bc = hair if style == "beard" else dark(skin, 0.18)
        for x in range(0, w):
            head.front(x, 0, bc, depth=z)
            head.front(x, 1, bc if x in (0, w - 1) or style == "beard" else dark(skin, 0.35), depth=z)
        if style == "beard":
            for x in range(1, w - 1):
                head.put(x, 0, z - 1, bc)
                head.put(x, -1, z, bc)
            for x in range(w // 2 - 1, w - (w // 2 - 1)):
                head.front(x, 2, bc, depth=z - 1)  # mustache
    if style == "goggles":
        for x in range(0, w):
            head.front(x, ey, hexc("8a6a2a"), depth=z - 1)
        for x in (lx, rx):
            head.front(x, ey, hexc("6ff0e0"), glow=True, depth=z - 1)
    if style == "veil":
        for x in range(0, w):
            for y in range(0, h - 1):
                if not (y == ey and x in (lx, rx)):
                    head.front(x, y, hexc("1c1a20"), depth=z - 1)


def hair_cap(head, hair, long_hair=False):
    w, h, d = head.w, head.h, head.d
    head.box(0, h, 0, w, h + 1, d, hair)
    head.box(0, h - 1, 0, w, h, 1, hair)          # fringe
    head.box(0, 1 if long_hair else 2, d - 1, w, h, d, hair)
    for x in (0, w - 1):
        head.box(x, h - 3, 1, x + 1, h, d, hair)


def hat(head, kind, col):
    w, h, d = head.w, head.h, head.d
    if kind == "cap":
        head.box(0, h, 0, w, h + 2, d, col)
        head.box(0, h, -2, w, h + 1, 0, dark(col, 0.15))
    elif kind in ("kerchief", "bandana"):
        head.box(-1 if kind == "kerchief" else 0, h - 1, 0, w + (1 if kind == "kerchief" else 0), h + 1, d + 1, col)
        head.box(w // 2 - 1, h - 3, d, w // 2 + 1, h - 1, d + 2, col)
    elif kind in ("wimple", "veil", "shawl", "hood"):
        head.box(-1, h, -1, w + 1, h + 1, d + 1, col)
        head.box(-1, -1 if kind != "hood" else 0, 0, 0, h, d + 1, col)
        head.box(w, -1 if kind != "hood" else 0, 0, w + 1, h, d + 1, col)
        head.box(-1, -1, d, w + 1, h, d + 1, col)
        if kind == "wimple":
            head.box(0, h - 1, -1, w, h, 0, (0.95, 0.95, 0.95))
            for x in (-1, w):
                head.box(x, 0, -1, x + 1, h, 0, (0.95, 0.95, 0.95))
    elif kind == "helm":
        head.box(-1, h - 2, -1, w + 1, h + 1, d + 1, STEEL)
        head.box(w // 2, 1, -2, w // 2 + 1, h - 1, -1, STEEL)       # nose guard
        head.box(w // 2, h + 1, 0, w // 2 + 1, h + 2, d, hexc("66ccff"), glow=True)  # aether crest
    elif kind == "tophat":
        head.box(-2, h, -2, w + 2, h + 1, d + 2, col)
        head.box(0, h + 1, 0, w, h + 5, d, col)
        head.box(0, h + 1, 0, w, h + 2, d, GOLD)
    elif kind == "feather":
        head.box(-1, h, -1, w + 1, h + 2, d + 1, col)
        for t in range(5):
            head.put(-1 - t // 2, h + 2 + t, d // 2, hexc("f0d855"))
    elif kind == "straw":
        sc = hexc("d8b866")
        head.box(-3, h, -3, w + 3, h + 1, d + 3, sc)
        head.box(0, h + 1, 0, w, h + 3, d, sc)
        head.box(0, h + 1, 0, w, h + 2, d, hexc("8a3a2a"))


# ---------------------------------------------------------------------------------------------
# Townsfolk frame (npc.gd): legs pivot at 0.62, head on top of a 0.56 torso
# ---------------------------------------------------------------------------------------------

def npc_model(name, o, seed=0):
    rng = random.Random(seed)
    skin = o.get("skin", SKINS[rng.randrange(len(SKINS))])
    cloth = o["cloth"]
    accent = o["accent"]
    pants = dark(cloth, 0.45)
    hair = o.get("hair", hexc("4a2e14"))
    m = Model(name)
    bulk = o.get("bulk", 0)
    tw = 7 + bulk
    for side, nm in ((-1, "leg_l"), (1, "leg_r")):
        lg = m.add(Part(nm, 3, 10, 3, "top", seed))
        lg.shell(pants if not o.get("robe") else dark(cloth, 0.3))
        lg.box(0, 0, 0, 3, 3, 3, BOOT)
        lg.box(0, 0, -1, 3, 1, 0, BOOT)
    t = m.add(Part("torso", tw, 9, 4, "bottom", seed))
    t.shell(cloth)
    t.box(0, 0, 0, tw, 2, 4, dark(cloth, 0.35))
    t.box(0, 2, 0, tw, 3, 4, BELT)
    t.front(tw // 2, 2, GOLD)
    t.box(tw // 2 - 1, 8, 0, tw // 2 + 2, 9, 1, accent)    # collar
    t.front(tw - 2, 6, light(accent, 0.3), glow=True)      # a Vael brooch
    if o.get("robe"):
        t.box(-1, -10, -1, tw + 1, 2, 5, cloth)
        t.box(tw // 2, -10, -1, tw // 2 + 1, 8, 0, accent)  # trim down the front
    if o.get("apron"):
        ap = o["apron"]
        t.box(1, -4 if o.get("robe") else -2, -1, tw - 1, 7, 0, ap)
        if not o.get("robe"):
            # the apron hangs over the legs too
            for lg in m.parts[:2]:
                lg.box(0, 4, -1, 3, 10, 0, ap)
    if o.get("plate"):
        t.box(-1, 4, -1, tw + 1, 9, 5, STEEL)
        t.box(tw // 2 - 1, 5, -2, tw // 2 + 2, 8, -1, hexc("3a5a9a"))  # tabard emblem
    hd = m.add(Part("head", 6, 6, 6, "bottom", seed))
    hd.shell(skin)
    if not o.get("bald"):
        hair_cap(hd, hair, o.get("long", False))
    elif o.get("face") == "beard":
        for x in (0, 5):
            hd.box(x, 2, 2, x + 1, 4, 6, hair)
    face(hd, skin, hair if not o.get("bald") else None, style=o.get("face", ""))
    if o.get("hat"):
        hat(hd, o["hat"], o.get("hat_col", hexc("5a4630")))
    for nm in ("arm_l", "arm_r"):
        a = m.add(Part(nm, 2, 8, 2, "top", seed))
        a.shell(STEEL if o.get("plate") else cloth)
        a.box(0, 0, 0, 2, 2, 2, skin)
        a.box(0, 2, 0, 2, 3, 2, dark(cloth, 0.2) if not o.get("plate") else dark(STEEL, 0.2))  # cuff
    return m


NPCS = {
    "marta": {"cloth": hexc("8a5a3a"), "accent": hexc("e0c070"), "hat": "kerchief", "hat_col": hexc("f2ead8"),
              "apron": hexc("f2eee0"), "hair": hexc("72401e")},
    "hennik": {"cloth": hexc("3a3028"), "accent": hexc("c0702a"), "face": "beard", "hair": hexc("9a948c"), "bald": True,
               "apron": hexc("4c3220"), "bulk": 1},
    "ivy": {"cloth": hexc("1a1a22"), "accent": hexc("e8e8ee"), "hat": "wimple", "hat_col": hexc("141418"), "robe": True},
    "pip": {"cloth": hexc("6a5236"), "accent": hexc("9a7a4a"), "hat": "cap", "hat_col": hexc("5a4632"), "hair": hexc("a8742e")},
    "rolan": {"cloth": hexc("3a4a70"), "accent": hexc("66ccff"), "hat": "helm", "face": "stubble", "plate": True,
              "hair": hexc("3e2c1e")},
    "greta": {"cloth": hexc("3a6a3a"), "accent": hexc("c0a050"), "hat": "bandana", "hat_col": hexc("b02a22"),
              "apron": hexc("8a6a42"), "hair": hexc("b04c1e"), "long": True},
    "liore": {"cloth": hexc("4a3a62"), "accent": hexc("4ce8d0"), "hat": "tophat", "hat_col": hexc("2a2632"),
              "face": "goggles", "hair": hexc("d8d8e2")},
    "oswin": {"cloth": hexc("9a2a3a"), "accent": hexc("e0b030"), "hat": "feather", "hat_col": hexc("9a2a40"),
              "face": "stubble", "hair": hexc("d89a40")},
    "ansel": {"cloth": hexc("16161a"), "accent": hexc("4a4a52"), "hat": "veil", "hat_col": hexc("141418"), "face": "veil",
              "robe": True},
    "toms": {"cloth": hexc("d8d0c0"), "accent": hexc("6a3a22"), "face": "beard", "apron": hexc("d8ccb4"),
             "hair": hexc("5a3820"), "bulk": 1},
    "edda": {"cloth": hexc("5a4a7a"), "accent": hexc("e0c070"), "hat": "shawl", "hat_col": hexc("66507e"),
             "hair": hexc("e0e0e6"), "robe": True},
}


def townsfolk(n):
    rng = random.Random(1000 + n)
    cloths = ["7a5236", "4a6a3a", "6a3a3a", "3a4a6a", "8a7a52", "5a5a62", "6a4a7a", "9a6a3a"]
    hats = ["", "", "cap", "hood", "straw", "kerchief"]
    hairs = ["4a2e14", "1e1a14", "c08e40", "8a4c1e", "9a9a9e"]
    o = {"cloth": hexc(rng.choice(cloths)), "accent": hexc(rng.choice(["c0a050", "66ccff", "e07050", "8ad08a"])),
         "hair": hexc(rng.choice(hairs)), "face": rng.choice(["", "", "stubble", "beard"]),
         "hat": rng.choice(hats), "hat_col": hexc(rng.choice(["5a4630", "4a5a3e", "b0a058", "803030"])),
         "skin": SKINS[rng.randrange(len(SKINS))]}
    if rng.random() < 0.3:
        o["apron"] = hexc("cec0a0")
    if rng.random() < 0.25:
        o["long"] = True
    return npc_model("folk_%d" % n, o, 1000 + n)


# ---------------------------------------------------------------------------------------------
# Tall frame (hero.gd / stranger.gd / day_enemy.gd): legs pivot at 0.84, head 0.66 above the waist
# ---------------------------------------------------------------------------------------------

def tall_legs(m, thigh, knee, greave, boot, seed):
    for nm in ("leg_l", "leg_r"):
        lg = m.add(Part(nm, 3, 13, 3, "top", seed))
        lg.box(0, 6, 0, 3, 13, 3, thigh)
        lg.box(0, 2, 0, 3, 6, 3, greave)
        lg.box(0, 6, -1, 3, 7, 0, knee)
        lg.box(0, 0, 0, 3, 2, 3, boot)
        lg.box(0, 0, -1, 3, 1, 0, boot)


def tall_arms(m, upper, pauldron, fore, glove, seed, split=True, pauldron_on=True):
    """split: hero-style shoulder + elbow (arm_x, fore_x); else one piece (arm_x)."""
    for side, sx in (("l", -1), ("r", 1)):
        if split:
            a = m.add(Part("arm_" + side, 2, 5, 2, "top", seed))
            a.shell(upper)
            if pauldron_on:
                a.box(-1, 3, -1, 3, 6, 3, pauldron)
            f = m.add(Part("fore_" + side, 2, 5, 2, "top", seed))
            f.shell(fore)
            f.box(0, 0, 0, 2, 1, 2, glove)
            f.box(-1, 3, -1, 3, 4, 3, dark(fore, 0.15))
        else:
            a = m.add(Part("arm_" + side, 2, 9, 2, "top", seed))
            a.shell(upper)
            a.box(0, 0, 0, 2, 2, 2, glove)
            a.box(0, 2, 0, 2, 5, 2, fore)
            if pauldron_on:
                a.box(-1, 7, -1, 3, 10, 3, pauldron)


def hero_model(name, form, armor, cape, seed=7):
    m = Model(name)
    armor_hi = light(armor, 0.25)
    darkc = dark(armor, 0.55)
    leather = hexc("54331f")
    skin = SKINS[0]
    tall_legs(m, leather if form == 1 else darkc, armor_hi, armor, leather, seed)
    t = m.add(Part("torso", 8, 11, 5, "bottom", seed))
    t.box(0, 0, 0, 8, 3, 5, darkc)
    t.box(0, 3, 0, 8, 4, 5, leather)
    t.front(4, 3, GOLD)
    t.front(3, 3, GOLD)
    t.box(0, 4, 0, 8, 11, 5, armor)
    if form >= 2:
        t.box(1, 6, -1, 7, 10, 0, armor_hi)       # breastplate
    # tabard with his emblem
    t.box(2, -3, -1 if form < 2 else -2, 6, 9, 0 if form < 2 else -1, cape)
    ez = -1 if form < 2 else -2
    em_glow = form == 3
    for y in range(3, 8):
        t.put(3, y, ez - 1, hexc("ffcc4a"), glow=em_glow)
        t.put(4, y, ez - 1, hexc("ffcc4a"), glow=em_glow)
    for x in range(2, 6):
        t.put(x, 6, ez - 1, hexc("ffcc4a"), glow=em_glow)
    t.box(2, 11, 1, 6, 12, 4, darkc)               # gorget
    hd = m.add(Part("head", 5, 6, 5, "bottom", seed))
    eye_col = hexc("ffd866") if form == 3 else hexc("b0e6ff")
    if form == 1:
        hd.shell(skin)
        hair_cap(hd, hexc("5a3418"))
        face(hd, skin, hexc("5a3418"), glow_eyes=eye_col)
        hd.box(-1, 0, -1, 6, 1, 6, cape)             # a scarf
    else:
        hd.box(-1, 0, -1, 6, 7, 6, armor_hi if form == 3 else armor)
        hd.box(0, 3, -2, 5, 4, -1, eye_col, glow=True)  # visor slit
        hd.box(2, 0, -2, 3, 3, -1, armor_hi)           # nasal / face plate ridge
        if form == 2:
            for k in range(0, 6):
                hd.box(2, 7 + (1 if 1 <= k <= 3 else 0), k, 3, 8 + (1 if 1 <= k <= 3 else 0), k + 1, cape)
        else:
            hd.box(-1, 7, -1, 6, 8, 6, GOLD)            # crown band
            for x in (-1, 1, 2, 3, 5):
                hd.put(x, 8, -1, GOLD)
            hd.put(2, 9, -1, GOLD)
            for x in (-2, 6):
                hd.box(x, 3, 1, x + 1, 7, 5, hexc("f2f2ff"))  # wings on the helm
    tall_arms(m, darkc, armor_hi if form > 1 else leather, armor, leather, seed, split=True, pauldron_on=form > 1)
    return m


def stranger_model(name, c, seed=11):
    """The Stranger at corruption c (0 white, 0.5 grey, 1 black). Parts: hood and face are separate."""
    robe = mix(hexc("f0eee8"), hexc("807a80"), min(1.0, c * 2))
    robe = mix(robe, hexc("140e18"), max(0.0, c * 2 - 1))
    trim = mix(hexc("d8b05a"), hexc("801420"), c)
    skin = mix(hexc("dcb898"), hexc("2a1430"), c)
    eye = mix(hexc("ffd880"), hexc("ff2a1a"), c)
    m = Model(name)
    tall_legs(m, robe, robe, robe, hexc("141018"), seed)
    t = m.add(Part("torso", 8, 11, 5, "bottom", seed))
    t.shell(robe)
    t.box(-1, -10, -1, 9, 3, 6, robe)               # the robe falls past the knees
    t.box(0, 2, -1, 8, 3, 6, trim)                  # sash
    t.box(4, -10, -2, 5, 11, -1, trim)              # trim down the front
    hd = m.add(Part("face", 5, 6, 5, "bottom", seed))
    hd.shell(skin)
    hair_cap(hd, hexc("5a3418"))
    face(hd, skin, hexc("5a3418"), glow_eyes=eye)
    hood = m.add(Part("hood", 5, 6, 5, "bottom", seed))
    hood.box(-1, 0, -1, 6, 7, 6, robe)
    hood.box(0, 0, -1, 5, 6, 0, hexc("060408"))     # the dark opening
    for x in (1, 3):
        hood.put(x, 3, -1, eye, glow=True)
    hood.box(1, 7, 1, 4, 8, 6, robe)               # the point of the cowl
    tall_arms(m, robe, robe, robe, skin, seed, split=False, pauldron_on=False)
    for side in ("arm_l", "arm_r"):
        p = [x for x in m.parts if x.name == side][0]
        p.box(-1, 2, -1, 3, 3, 3, robe)            # wide sleeve cuffs
    return m


ENEMIES = {
    # id: (cloth, metal, tech, kind)
    "thug": (hexc("6a3a26"), hexc("54504e"), hexc("ff6a1a"), "thug"),
    "automaton": (hexc("6a4a30"), hexc("8a5a34"), hexc("ffa040"), "automaton"),
    "archer": (hexc("3a5a30"), hexc("54504e"), hexc("a0ff60"), "archer"),
    "cultist": (hexc("e2dcd0"), hexc("d8d2c8"), hexc("ff3a4a"), "cultist"),
    "mordrek": (hexc("4a2418"), hexc("3a3230"), hexc("ff5a14"), "brute"),
    "warden": (hexc("2a3456"), hexc("5a6a8a"), hexc("6ab4ff"), "shield"),
    "pitmaster": (hexc("8a6a2e"), hexc("6a5a40"), hexc("ffd04a"), "summoner"),
    "inquisitor": (hexc("c8c8d0"), hexc("a0a0aa"), hexc("ffd880"), "caster"),
    "prophet": (hexc("d8b452"), hexc("b08a3a"), hexc("fff2a0"), "blinker"),
    "herald": (hexc("241030"), hexc("1a1420"), hexc("ff2a4a"), "brute"),
}


def enemy_model(eid):
    cloth, metal, tech, kind = ENEMIES[eid]
    m = Model("foe_" + eid)
    seed = h32(eid) & 0xFFFF
    is_metal = kind in ("automaton",) or eid in ("warden", "herald")
    tall_legs(m, metal if is_metal else cloth, light(metal, 0.2), metal, BOOT if not is_metal else dark(metal, 0.3), seed)
    for lg in m.parts[:2]:
        lg.put(1, 6, -1, tech, glow=True)            # aether knee lamps
    t = m.add(Part("torso", 8, 11, 5, "bottom", seed))
    t.shell(cloth)
    t.box(0, 5, 0, 8, 10, 5, metal)
    t.box(0, 3, 0, 8, 4, 5, BELT)
    t.box(3, 6, -1, 5, 8, 0, tech, glow=True)        # an aether core in the chest
    if kind in ("caster", "blinker", "cultist", "summoner"):
        t.box(-1, -9, -1, 9, 4, 6, cloth)            # robes
        t.box(3, -9, -2, 5, 10, -1, light(tech, 0.2) if eid != "cultist" else hexc("aa1a22"))
    if eid == "pitmaster":
        t.box(1, 2, -2, 7, 8, -1, cloth)             # a big belly
    hd = m.add(Part("head", 5, 6, 5, "bottom", seed))
    if kind == "automaton":
        hd.box(-1, 0, -1, 6, 6, 6, metal)
        hd.box(2, 2, -2, 3, 4, -1, tech, glow=True)  # one big eye
        hd.box(-1, 6, 1, 6, 7, 4, dark(metal, 0.3))
    elif kind == "archer":
        hd.shell(SKINS[1])
        face(hd, SKINS[1], hexc("2a1a10"), style="stubble")
        hat(hd, "hood", cloth)
    elif kind == "cultist":
        hd.shell(SKINS[0])
        hat(hd, "hood", cloth)
        hd.box(0, 0, -1, 5, 6, 0, hexc("f2f0ea"))    # a white mask
        for x in (1, 3):
            hd.put(x, 3, -1, tech, glow=True)
    else:
        hd.box(-1, 0, -1, 6, 7, 6, metal)            # a helm with a visor slit
        hd.box(0, 3, -2, 5, 4, -1, tech, glow=True)
        if eid in ("mordrek", "herald"):
            for x in (-1, 5):
                for y in range(7, 10):
                    hd.put(x + (0 if y < 9 else (1 if x < 0 else -1)), y, 2, light(tech, 0.1) if eid == "herald" else hexc("d8d0c0"))
        if eid == "inquisitor":
            hd.box(0, 7, 0, 5, 11, 5, cloth)          # a tall mitre
            hd.box(2, 7, -1, 3, 11, 0, GOLD)
        if eid == "prophet":
            for x in range(-1, 6):
                hd.put(x, 8, 2, GOLD, glow=True)      # a gilded crown of light
            hd.box(0, 0, -2, 5, 6, -1, GOLD)          # the gilded mask
            for x in (1, 3):
                hd.put(x, 3, -2, tech, glow=True)
        if eid == "warden":
            hd.box(2, 7, -1, 3, 9, 6, tech, glow=True)
    tall_arms(m, cloth if not is_metal else metal, metal, metal if is_metal else dark(cloth, 0.2), dark(metal, 0.2), seed,
              split=False, pauldron_on=kind not in ("caster", "cultist", "archer"))
    return m


# ---------------------------------------------------------------------------------------------
# Props: trees, rocks, barrels, crates, lamps
# ---------------------------------------------------------------------------------------------

def blob(part, cx, cy, cz, r, cols, rng, squash=1.0):
    for i in range(int(cx - r - 1), int(cx + r + 2)):
        for j in range(int(cy - r - 1), int(cy + r + 2)):
            for k in range(int(cz - r - 1), int(cz + r + 2)):
                dd = ((i - cx) ** 2 + ((j - cy) / squash) ** 2 + (k - cz) ** 2) ** 0.5
                if dd <= r + rng.uniform(-0.6, 0.4):
                    part.put(i, j, k, rng.choice(cols))


def tree_oak(n):
    rng = random.Random(500 + n)
    m = Model("tree_oak_%d" % n)
    p = m.add(Part("model", 1, 1, 1, "bottom", n))
    bark = [hexc("5a3c22"), hexc("4a301a"), hexc("6a4628")]
    h = rng.randint(26, 36)
    for j in range(h):
        for i in range(-2, 2):
            for k in range(-2, 2):
                p.put(i, j, k, rng.choice(bark))
    for b in range(3):
        a = rng.uniform(0, math.tau)
        for t in range(8):
            p.put(int(math.cos(a) * t), h - 10 + t // 2 + b * 2, int(math.sin(a) * t), rng.choice(bark))
    leaves = [hexc("3e6a2a"), hexc("4a7a30"), hexc("2e5422"), hexc("5a8a3a")]
    blob(p, 0, h + 4, 0, 11, leaves, rng, 0.8)
    for b in range(4):
        a = rng.uniform(0, math.tau)
        blob(p, math.cos(a) * 9, h + rng.randint(-2, 3), math.sin(a) * 9, 6.5, leaves, rng, 0.8)
    for i in range(-3, 3):
        for k in range(-3, 3):
            if abs(i + 0.5) + abs(k + 0.5) > 3:
                p.put(i, 0, k, rng.choice(bark))      # roots
    return m


def tree_pine(n):
    rng = random.Random(600 + n)
    m = Model("tree_pine_%d" % n)
    p = m.add(Part("model", 1, 1, 1, "bottom", n))
    bark = [hexc("4a2e1a"), hexc("3a2414")]
    needles = [hexc("1e4a30"), hexc("245a38"), hexc("163a26")]
    h = rng.randint(40, 52)
    for j in range(h):
        for i in range(-1, 1):
            for k in range(-1, 1):
                p.put(i, j, k, rng.choice(bark))
    for tier in range(5):
        y0 = 10 + tier * 8
        r = 11 - tier * 2
        for j in range(y0, y0 + 7):
            rr = r * (1.0 - (j - y0) / 9.0)
            for i in range(-int(rr) - 1, int(rr) + 1):
                for k in range(-int(rr) - 1, int(rr) + 1):
                    if (i + 0.5) ** 2 + (k + 0.5) ** 2 <= rr * rr + rng.uniform(-2, 1):
                        p.put(i, j, k, rng.choice(needles))
    snow = n % 2 == 1
    if snow:
        for (i, j, k), (c, g) in list(p.vox.items()):
            if not p.has(i, j + 1, k) and c in needles and rng.random() < 0.6:
                p.put(i, j + 1, k, hexc("e8eef2"), jit=0.03)
    return m


def bush():
    rng = random.Random(700)
    m = Model("bush")
    p = m.add(Part("model", 1, 1, 1, "bottom", 0))
    blob(p, 0, 4, 0, 6, [hexc("3a6a2a"), hexc("4a7a32"), hexc("2e5422")], rng, 0.7)
    for _ in range(6):
        p.put(rng.randint(-5, 5), rng.randint(5, 8), rng.randint(-5, 5), hexc("e05a6a"))  # berries
    return m


def rock(n):
    rng = random.Random(800 + n)
    m = Model("rock_%d" % n)
    p = m.add(Part("model", 1, 1, 1, "bottom", n))
    cols = [hexc("6a6a70"), hexc("5a5a60"), hexc("7a7a80"), hexc("4e4e54")]
    blob(p, 0, 4, 0, 7 + n, cols, rng, 0.6)
    for (i, j, k), (c, g) in list(p.vox.items()):
        if not p.has(i, j + 1, k) and rng.random() < 0.35:
            p.put(i, j, k, hexc("4a6a34"))           # moss
    return m


def barrel():
    rng = random.Random(900)
    m = Model("barrel")
    p = m.add(Part("model", 1, 1, 1, "bottom", 0))
    staves = [hexc("8a5a30"), hexc("7a4e28"), hexc("9a6638")]
    for j in range(14):
        r = 5.0 + 0.8 * math.sin(math.pi * j / 13.0)
        for i in range(-6, 6):
            for k in range(-6, 6):
                if (i + 0.5) ** 2 + (k + 0.5) ** 2 <= r * r:
                    band = j in (2, 11)
                    p.put(i, j, k, hexc("4a4a4e") if band else staves[(i + 6) % 3])
    return m


def crate():
    m = Model("crate")
    p = m.add(Part("model", 12, 12, 12, "bottom", 0))
    plank = hexc("9a7040")
    frame = hexc("6a4a28")
    p.shell(plank)
    for i in range(12):
        for j in range(12):
            for k in range(12):
                edge = (i in (0, 11)) + (j in (0, 11)) + (k in (0, 11))
                if edge >= 2:
                    p.put(i, j, k, frame)
    for t in range(12):
        p.put(t, t, -1, frame)
    return m


def lamp():
    m = Model("lamp")
    p = m.add(Part("model", 1, 1, 1, "bottom", 0))
    iron = hexc("2e2a2e")
    for j in range(0, 52):
        p.box(-1, j, -1, 1, j + 1, 1, iron)
    p.box(-2, 0, -2, 2, 2, 2, iron)
    p.box(-3, 52, -3, 3, 53, 3, iron)
    p.box(-2, 53, -2, 2, 58, 2, hexc("8ae8ff"), glow=True)   # an aether globe
    p.box(-3, 58, -3, 3, 59, 3, iron)
    return m


def main():
    models = []
    for nid, o in NPCS.items():
        models.append(npc_model("npc_" + nid, o, h32(nid) & 0xFFFF))
    for n in range(8):
        models.append(townsfolk(n))
    heroes = [
        (1, hexc("80858f"), hexc("8c1e1a")), (2, hexc("738cbf"), hexc("1e2e80")), (3, hexc("e6d8a6"), hexc("ebebf2")),
        (2, hexc("d8e0f2"), hexc("d8a633")), (3, hexc("b3d8ff"), hexc("f2f2ff")), (3, hexc("ffd166"), hexc("cc1e1a")),
    ]
    for n, (form, armor, cape) in enumerate(heroes):
        models.append(hero_model("hero_%d" % (n + 1), form, armor, cape))
    for n, c in enumerate([0.0, 0.5, 1.0]):
        models.append(stranger_model("stranger_%d" % n, c))
    for eid in ENEMIES:
        models.append(enemy_model(eid))
    for n in range(3):
        models.append(tree_oak(n))
    for n in range(2):
        models.append(tree_pine(n))
    for n in range(3):
        models.append(rock(n))
    models += [bush(), barrel(), crate(), lamp()]
    only = os.environ.get("VOX_ONLY", "")
    for m in models:
        if only and only not in m.name:
            continue
        export(m)
    print("[VOX] done:", len(models), "models")


if __name__ == "__main__":
    main()
