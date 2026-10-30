"""The Hollow King's hands and wand as voxels, for boss.gd.

Run headless (after or instead of voxel_models.py):
    blender --background --factory-startup --python tools/voxel_hands.py -- <project dir>

Writes assets/models/hand_r.glb, hand_l.glb and wand.glb. The hands use a finer voxel (5 mm) than
the world, so the fingers stay readable up close. Skin, sleeve and trim are painted in NEUTRAL light
tones with pixel detail (pores, creases, knuckle highlights, weave); the game tints them every frame
from corrupted grey-violet to warm living skin (boss.gd apply_purity), so the purity story still
plays out on voxel hands. Veins are emissive voxels, tinted red -> gold -> white by the game.

Parts (origins match the joints in boss.gd _make_hand):
    forearm, palm, sleeve, trim          on the hand root
    f<finger>_<segment>  (0..3, 0..2)    on each finger joint, extending along -Z
    t0, t1, t2                           on the thumb joints
    wand                                 on the wand node (the gem stays a live glowing cube)
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voxel_models as vm  # noqa: E402

VH = 0.005  # 5 mm voxels

SKIN = (0.93, 0.9, 0.9)
PORE = (0.8, 0.77, 0.78)
CREASE = (0.62, 0.58, 0.6)
KNUCKLE = (0.98, 0.96, 0.96)
UNDER = (0.97, 0.95, 0.94)
SCAR = (1.0, 0.98, 0.98)
VEIN = (1.0, 1.0, 1.0)


class FreePart(vm.Part):
    """A part filled in real (Godot) coordinates around its own origin."""

    def __init__(self, name, seed=0):
        super().__init__(name, 1, 1, 1, "bottom", seed)
        self.v = VH

    def origin(self):
        return (0.0, 0.0, 0.0)

    def idx(self, x):
        return int(round(x / VH))

    def fill(self, cx, cy, cz, sx, sy, sz, col, glow=False, jit=0.06):
        i0, i1 = self.idx(cx - sx / 2), max(self.idx(cx - sx / 2) + 1, self.idx(cx + sx / 2))
        j0, j1 = self.idx(cy - sy / 2), max(self.idx(cy - sy / 2) + 1, self.idx(cy + sy / 2))
        k0, k1 = self.idx(cz - sz / 2), max(self.idx(cz - sz / 2) + 1, self.idx(cz + sz / 2))
        self.box(i0, j0, k0, i1, j1, k1, col, glow, jit)
        return (i0, j0, k0, i1, j1, k1)

    def skin_detail(self, rng, pore_rate=0.08):
        """Pores on the skin, a lighter underside: pixel texture."""
        for (i, j, k), (c, g) in list(self.vox.items()):
            if g:
                continue
            if rng.random() < pore_rate:
                self.put(i, j, k, PORE, jit=0.03)
            elif not self.has(i, j - 1, k) and rng.random() < 0.5:
                self.put(i, j, k, UNDER, jit=0.03)

    def top(self, i, k):
        """The highest voxel in column (i, k), or None."""
        ys = [j for (a, j, b) in self.vox if a == i and b == k]
        return max(ys) if ys else None


def hand(side):
    rng = random.Random(77 if side > 0 else 78)
    m = vm.Model("hand_r" if side > 0 else "hand_l")
    # --- forearm: tapering toward the wrist, a muscle along the top, veins and scars
    fa = m.add(FreePart("forearm", 1))
    fa.fill(0, -0.004, 0.32, 0.088, 0.07, 0.17, SKIN)
    fa.fill(0, -0.006, 0.17, 0.076, 0.056, 0.14, SKIN)
    fa.fill(side * 0.016, 0.03, 0.29, 0.04, 0.016, 0.22, SKIN)
    fa.skin_detail(rng)
    import math
    for k in range(2):
        # Two veins meandering down the forearm, set into the skin (continuous lines)
        x0 = -0.014 + k * 0.026
        for z in range(fa.idx(0.12), fa.idx(0.38)):
            xx = fa.idx(x0) + int(round(math.sin(z * 0.22 + k * 2.0) * 1.6))
            t = fa.top(xx, z)
            if t is not None:
                fa.put(xx, t, z, VEIN, glow=True, jit=0)
    for k in range(2):
        z0 = fa.idx(0.2 + k * 0.07)
        for d in range(6):
            x = fa.idx(side * 0.008) + d - 3
            t = fa.top(x, z0 + d // 2)
            if t is not None:
                fa.put(x, t, z0 + d // 2, SCAR, jit=0.02)
    # --- palm: wrist, the palm widening to the knuckles, the heels of the hand, knuckle bumps
    pa = m.add(FreePart("palm", 2))
    pa.fill(0, -0.006, 0.075, 0.07, 0.044, 0.04, SKIN)
    pa.fill(0, -0.004, 0.03, 0.082, 0.034, 0.06, SKIN)
    pa.fill(0, 0.0, -0.025, 0.1, 0.032, 0.06, SKIN)
    pa.fill(-side * 0.03, -0.018, 0.035, 0.036, 0.024, 0.06, SKIN)
    pa.fill(side * 0.034, -0.016, 0.03, 0.026, 0.018, 0.06, SKIN)
    knuckle_x = [-0.039, -0.013, 0.013, 0.038]
    knuckle_z = [-0.056, -0.062, -0.058, -0.046]
    widths = [0.02, 0.021, 0.019, 0.016]
    for k in range(4):
        kx = knuckle_x[k] * -side
        pa.fill(kx, 0.012, knuckle_z[k] + 0.004, widths[k] * 1.12, 0.016, 0.018, KNUCKLE)
    pa.skin_detail(rng, 0.06)
    # tendons: lighter lines fanning to each knuckle; veins between them
    for k in range(4):
        kx = knuckle_x[k] * -side
        for s in range(10):
            f = s / 9.0
            x = pa.idx(kx * (0.25 + 0.75 * f))
            z = pa.idx(0.03 - 0.075 * f)
            t = pa.top(x, z)
            if t is not None:
                pa.put(x, t, z, KNUCKLE, jit=0.02)
    for k in range(2):
        for z in range(pa.idx(-0.03), pa.idx(0.09)):
            x = pa.idx(-0.016 + k * 0.03) + int(round(math.sin(z * 0.3 + k) * 1.0))
            t = pa.top(x, z)
            if t is not None:
                pa.put(x, t, z, VEIN, glow=True, jit=0)
    # --- fingers: three segments each
    lens = [[0.044, 0.027, 0.021], [0.05, 0.031, 0.023], [0.046, 0.029, 0.021], [0.035, 0.021, 0.018]]
    for i in range(4):
        for k in range(3):
            L = lens[i][k]
            ww = widths[i] * (1.0 - 0.1 * k)
            f = m.add(FreePart("f%d_%d" % (i, k), 10 + i * 3 + k))
            f.fill(0, 0, -L / 2, ww, ww * 0.85, L, SKIN)
            f.skin_detail(rng, 0.05)
            # a crease across the back at the far joint, and a highlight on the knuckle end
            k_end = f.idx(-L)
            for (a, j, b) in list(f.vox):
                if b == k_end and not f.has(a, j + 1, b):
                    f.put(a, j, b, CREASE, jit=0.02)
                if b == f.idx(0) - 1 and not f.has(a, j + 1, b):
                    f.put(a, j, b, KNUCKLE, jit=0.02)
    # --- the thumb
    for k, (sz, zc) in enumerate([((0.026, 0.024, 0.05), -0.025), ((0.023, 0.021, 0.032), -0.016), ((0.021, 0.019, 0.026), -0.013)]):
        t = m.add(FreePart("t%d" % k, 30 + k))
        t.fill(0, 0, zc, sz[0], sz[1], sz[2], SKIN)
        t.skin_detail(rng, 0.05)
    # --- the sleeve (a woven cuff with a ragged hem) and its trim, both tinted by the game
    sl = m.add(FreePart("sleeve", 40))
    box = sl.fill(0, 0, 0.44, 0.15, 0.13, 0.14, (0.92, 0.92, 0.92))
    i0, j0, k0, i1, j1, k1 = box
    for (a, j, b) in list(sl.vox):
        if (b - k0) % 6 == 0:
            sl.put(a, j, b, (0.84, 0.84, 0.86), jit=0.02)  # stitched bands round the cuff
    tr = m.add(FreePart("trim", 41))
    tb = tr.fill(0, 0, 0.37, 0.158, 0.138, 0.02, (0.95, 0.95, 0.95))
    for (a, j, b) in list(tr.vox):
        if (a // 3 + j // 3) % 2 == 0:
            tr.put(a, j, b, (0.75, 0.75, 0.75), jit=0.02)  # a chequered border
    return m


def wand():
    rng = random.Random(90)
    m = vm.Model("wand")
    w = m.add(FreePart("wand", 50))
    wood = [(0.3, 0.18, 0.11), (0.25, 0.15, 0.09), (0.34, 0.21, 0.13)]
    # The shaft, thicker at the butt, with three knots, then a crooked tip
    n = 52
    for s in range(n):
        f = s / (n - 1)
        z = 0.04 - 0.26 * f
        r = 0.01 - 0.004 * f
        w.fill(0, 0, z, r * 2, r * 2, 0.005, rng.choice(wood), jit=0.04)
    for k in range(3):
        w.fill(0.002, 0.002, -0.02 - k * 0.07, 0.016, 0.016, 0.01, (0.2, 0.12, 0.07))
    for s in range(14):
        f = s / 13.0
        w.fill(0.002 + 0.01 * f, 0.004 * f, -0.22 - 0.06 * f, 0.007, 0.007, 0.006, rng.choice(wood), jit=0.04)
    # Silver bands near the grip
    for z in (0.02, 0.0):
        w.fill(0, 0, z, 0.022, 0.022, 0.005, (0.78, 0.8, 0.84))
    return m


def main():
    for m in (hand(1), hand(-1), wand()):
        vm.export(m)
    print("[VOX] hands done")


if __name__ == "__main__":
    main()
