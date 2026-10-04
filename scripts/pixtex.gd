extends RefCounted
## Pixel-art textures, drawn in code, for everything that is not the player: chunky stone bricks
## with dark mortar, cobbles, planks, shingles, grass, dirt, bark, leaves, plaster, plate metal,
## cloth, big floor tiles, sand and water; and little pixel FACES for every person in the world.
## Low resolution, high contrast, nearest-filtered: the look of a pixel dungeon crawler.
##
## mat(tex, metres): a material that maps the texture in world space (triplanar), so a brick is
## the same size on every wall however big the wall is. Use world=false for things that move.

static var _cache := {}


static func _rng(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r


static func _done(key: String, img: Image) -> ImageTexture:
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


static func _shade(c: Color, k: float) -> Color:
	return c.lightened(k) if k > 0.0 else c.darkened(-k)


## A material for a pixel texture. metres = how much world one repeat of the texture covers.
static func mat(tex: Texture2D, metres: float = 2.0, world: bool = true, tint: Color = Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = tint
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_triplanar = true
	m.uv1_world_triplanar = world
	m.uv1_scale = Vector3.ONE / metres
	m.roughness = 1.0
	return m


## A material for a decal quad (a face, a belt, an emblem): the texture fills the quad exactly.
static func decal(tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.roughness = 1.0
	return m


# --- Surfaces -----------------------------------------------------------------------------------

static func bricks(base: Color, seed: int = 1, rows: int = 4, cols: int = 2) -> ImageTexture:
	var key := "bricks_%s_%d_%d_%d" % [base.to_html(), seed, rows, cols]
	if _cache.has(key):
		return _cache[key]
	var n := 32
	var img := Image.create_empty(n, n, true, Image.FORMAT_RGB8)
	var r := _rng(seed)
	var bh := n / rows
	var bw := n / cols
	var mortar := base.darkened(0.6)
	var shades := []
	for k in rows * cols * 2:
		shades.append(r.randf_range(-0.16, 0.14))
	for y in n:
		var row := y / bh
		var off := (bw / 2) if row % 2 == 1 else 0
		for x in n:
			var xx := (x + off) % n
			var col := xx / bw
			var yy := y % bh
			var xi := xx % bw
			var c := _shade(base, shades[(row * cols + col) % shades.size()])
			if yy == 0 or xi == 0:
				c = mortar
			elif yy == 1:
				c = c.lightened(0.12)    # top edge catches the light
			elif yy == bh - 1:
				c = c.darkened(0.2)      # bottom edge in shadow
			elif r.randf() < 0.12:
				c = _shade(c, r.randf_range(-0.12, 0.08))
			if r.randf() < 0.012:
				c = mortar.lightened(0.1)  # a chip
			img.set_pixel(x, y, c)
	return _done(key, img)


static func cobbles(base: Color, seed: int = 2) -> ImageTexture:
	var key := "cob_%s_%d" % [base.to_html(), seed]
	if _cache.has(key):
		return _cache[key]
	var n := 32
	var img := Image.create_empty(n, n, true, Image.FORMAT_RGB8)
	var r := _rng(seed)
	var pts: Array[Vector2] = []
	var tone: Array[float] = []
	for k in 18:
		pts.append(Vector2(r.randf() * n, r.randf() * n))
		tone.append(r.randf_range(-0.18, 0.14))
	for y in n:
		for x in n:
			var best := 999.0
			var second := 999.0
			var bi := 0
			for k in pts.size():
				for dx in [-n, 0, n]:
					for dy in [-n, 0, n]:
						var d := Vector2(x, y).distance_to(pts[k] + Vector2(dx, dy))
						if d < best:
							second = best
							best = d
							bi = k
						elif d < second:
							second = d
			var c := _shade(base, tone[bi])
			if second - best < 1.3:
				c = base.darkened(0.55)
			elif best < 2.0:
				c = c.lightened(0.08)
			img.set_pixel(x, y, c)
	return _done(key, img)


static func planks(base: Color, seed: int = 3) -> ImageTexture:
	var key := "plk_%s_%d" % [base.to_html(), seed]
	if _cache.has(key):
		return _cache[key]
	var n := 32
	var img := Image.create_empty(n, n, true, Image.FORMAT_RGB8)
	var r := _rng(seed)
	var pw := 8
	var shades := [0.0, -0.1, 0.06, -0.05]
	for y in n:
		for x in n:
			var p := x / pw
			var c := _shade(base, shades[p % 4])
			var xi := x % pw
			if xi == 0:
				c = base.darkened(0.55)
			elif xi == 1:
				c = c.lightened(0.1)
			# grain: streaks along the plank
			if (y + p * 7) % 9 == 0 and xi > 2 and xi < pw - 1:
				c = c.darkened(0.18)
			if r.randf() < 0.05:
				c = c.darkened(0.1)
			# plank ends and nails
			var seam := (p * 13) % n
			if y == seam:
				c = base.darkened(0.5)
			if (y == seam + 2) and (xi == 3 or xi == 5):
				c = Color(0.2, 0.18, 0.18)
			img.set_pixel(x, y, c)
	return _done(key, img)


static func shingles(base: Color, seed: int = 4) -> ImageTexture:
	var key := "shg_%s_%d" % [base.to_html(), seed]
	if _cache.has(key):
		return _cache[key]
	var n := 32
	var img := Image.create_empty(n, n, true, Image.FORMAT_RGB8)
	var r := _rng(seed)
	var rh := 6
	var tw := 8
	for y in n:
		var row := y / rh
		var off := (tw / 2) if row % 2 == 1 else 0
		for x in n:
			var xx := (x + off) % n
			var yi := y % rh
			var t := (row * 5 + xx / tw) % 4
			var c := _shade(base, [0.0, -0.08, 0.06, -0.14][t])
			if yi == rh - 1:
				c = base.darkened(0.55)  # the shadow under each row
			elif yi == 0:
				c = c.lightened(0.12)
			if xx % tw == 0 and yi < rh - 1:
				c = c.darkened(0.3)
			if r.randf() < 0.06:
				c = c.darkened(0.12)
			img.set_pixel(x, y, c)
	return _done(key, img)


## Noisy ground: grass (tufts and blades), dirt (pebbles) or sand.
static func ground(base: Color, kind: String = "grass", seed: int = 5) -> ImageTexture:
	var key := "gnd_%s_%s_%d" % [base.to_html(), kind, seed]
	if _cache.has(key):
		return _cache[key]
	var n := 32
	var img := Image.create_empty(n, n, true, Image.FORMAT_RGB8)
	var r := _rng(seed)
	for y in n:
		for x in n:
			img.set_pixel(x, y, _shade(base, r.randf_range(-0.07, 0.06)))
	match kind:
		"grass":
			for k in 40:
				var x := r.randi() % n
				var y := r.randi() % n
				var c := base.lightened(0.2) if k % 2 == 0 else base.darkened(0.25)
				img.set_pixel(x, y, c)
				img.set_pixel(x, (y + 1) % n, c.darkened(0.1))
			for k in 4:
				# a little flower
				var fx := r.randi() % n
				var fy := r.randi() % n
				img.set_pixel(fx, fy, [Color(0.95, 0.9, 0.4), Color(0.9, 0.4, 0.5), Color(0.9, 0.9, 0.95)][k % 3])
		"dirt":
			for k in 24:
				var x := r.randi() % n
				var y := r.randi() % n
				img.set_pixel(x, y, base.lightened(0.18))
				img.set_pixel((x + 1) % n, y, base.darkened(0.3))
		"sand":
			for k in 30:
				img.set_pixel(r.randi() % n, r.randi() % n, base.lightened(0.12))
	return _done(key, img)


static func bark(base: Color, seed: int = 6) -> ImageTexture:
	var key := "bark_%s_%d" % [base.to_html(), seed]
	if _cache.has(key):
		return _cache[key]
	var n := 16
	var img := Image.create_empty(n, n, true, Image.FORMAT_RGB8)
	var r := _rng(seed)
	for x in n:
		var s := r.randf_range(-0.15, 0.1)
		for y in n:
			var c := _shade(base, s)
			if x % 4 == 0 or r.randf() < 0.08:
				c = base.darkened(0.45)
			img.set_pixel(x, y, c)
	return _done(key, img)


static func leaves(base: Color, seed: int = 7) -> ImageTexture:
	var key := "leaf_%s_%d" % [base.to_html(), seed]
	if _cache.has(key):
		return _cache[key]
	var n := 16
	var img := Image.create_empty(n, n, true, Image.FORMAT_RGB8)
	var r := _rng(seed)
	for y in n:
		for x in n:
			var v := r.randf()
			var c := base
			if v < 0.22:
				c = base.darkened(0.4)
			elif v > 0.82:
				c = base.lightened(0.22)
			img.set_pixel(x, y, c)
	return _done(key, img)


static func plaster(base: Color, seed: int = 8) -> ImageTexture:
	var key := "pls_%s_%d" % [base.to_html(), seed]
	if _cache.has(key):
		return _cache[key]
	var n := 32
	var img := Image.create_empty(n, n, true, Image.FORMAT_RGB8)
	var r := _rng(seed)
	for y in n:
		for x in n:
			var c := _shade(base, r.randf_range(-0.05, 0.04))
			img.set_pixel(x, y, c)
	# a crack or two, and a patch where it has fallen away to show brick
	for k in 2:
		var x := r.randi() % n
		var y := r.randi() % n
		for s in 6:
			img.set_pixel((x + s) % n, (y + (s / 2)) % n, base.darkened(0.35))
	return _done(key, img)


static func metal(base: Color, seed: int = 9) -> ImageTexture:
	var key := "mtl_%s_%d" % [base.to_html(), seed]
	if _cache.has(key):
		return _cache[key]
	var n := 16
	var img := Image.create_empty(n, n, true, Image.FORMAT_RGB8)
	var r := _rng(seed)
	for y in n:
		for x in n:
			var c := _shade(base, r.randf_range(-0.05, 0.05))
			if x == 0 or y == 0:
				c = base.darkened(0.45)
			elif x == 1 or y == 1:
				c = base.lightened(0.2)
			if (x == 3 or x == 12) and (y == 3 or y == 12):
				c = base.lightened(0.35)  # rivets
			img.set_pixel(x, y, c)
	return _done(key, img)


## Woven cloth: pixel folds and a weave, for clothes and robes.
static func cloth(base: Color, seed: int = 10) -> ImageTexture:
	var key := "clt_%s_%d" % [base.to_html(), seed]
	if _cache.has(key):
		return _cache[key]
	var n := 16
	var img := Image.create_empty(n, n, true, Image.FORMAT_RGB8)
	var r := _rng(seed)
	for y in n:
		for x in n:
			var c := base
			if x % 5 == 0:
				c = base.darkened(0.2)     # a fold
			elif x % 5 == 1:
				c = base.lightened(0.1)
			if (x + y) % 2 == 0 and r.randf() < 0.3:
				c = c.darkened(0.06)       # the weave
			img.set_pixel(x, y, c)
	return _done(key, img)


static func tiles(base: Color, seed: int = 11) -> ImageTexture:
	var key := "til_%s_%d" % [base.to_html(), seed]
	if _cache.has(key):
		return _cache[key]
	var n := 32
	var img := Image.create_empty(n, n, true, Image.FORMAT_RGB8)
	var r := _rng(seed)
	var tone := [0.0, -0.1, 0.05, -0.05]
	for y in n:
		for x in n:
			var t := (x / 16 + (y / 16) * 2)
			var c := _shade(base, tone[t])
			var xi := x % 16
			var yi := y % 16
			if xi == 0 or yi == 0:
				c = base.darkened(0.5)
			elif xi == 1 or yi == 1:
				c = c.lightened(0.15)
			elif xi == 15 or yi == 15:
				c = c.darkened(0.2)
			elif r.randf() < 0.07:
				c = c.darkened(0.1)
			img.set_pixel(x, y, c)
	return _done(key, img)


static func water(base: Color, seed: int = 12) -> ImageTexture:
	var key := "wat_%s_%d" % [base.to_html(), seed]
	if _cache.has(key):
		return _cache[key]
	var n := 32
	var img := Image.create_empty(n, n, true, Image.FORMAT_RGB8)
	var r := _rng(seed)
	img.fill(base)
	for k in 14:
		var x := r.randi() % n
		var y := r.randi() % n
		for s in 4:
			img.set_pixel((x + s) % n, y, base.lightened(0.3))
	return _done(key, img)


# --- Faces ----------------------------------------------------------------------------------------

## A 10x10 pixel face: hair fringe, brows, eyes (white and iris), nose shade, mouth, and an
## optional beard. hair = Color(0,0,0,0) for bald. style: "", "stubble", "beard", "veil", "mask",
## "goggles", "bandana", "hood".
static func face(skin: Color, hair: Color, eye: Color, style: String = "", seed: int = 0) -> ImageTexture:
	var key := "face_%s_%s_%s_%s_%d" % [skin.to_html(), hair.to_html(), eye.to_html(), style, seed]
	if _cache.has(key):
		return _cache[key]
	var n := 10
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var r := _rng(seed + 77)
	img.fill(skin)
	var shadow := skin.darkened(0.18)
	var bald := hair.a < 0.5
	# Hair fringe
	if not bald:
		for x in n:
			img.set_pixel(x, 0, hair)
			if r.randf() < 0.6 or x < 1 or x > 8:
				img.set_pixel(x, 1, hair)
	# Brows
	var brow := hair.darkened(0.2) if not bald else skin.darkened(0.45)
	for x in [2, 3, 6, 7]:
		img.set_pixel(x, 3, brow)
	# Eyes: white, then iris toward the centre
	for y in [4, 5]:
		img.set_pixel(2, y, Color(0.95, 0.93, 0.9))
		img.set_pixel(3, y, eye)
		img.set_pixel(6, y, eye)
		img.set_pixel(7, y, Color(0.95, 0.93, 0.9))
	# Nose and cheeks
	img.set_pixel(4, 5, shadow)
	img.set_pixel(5, 6, shadow)
	img.set_pixel(4, 6, shadow)
	img.set_pixel(0, 6, shadow)
	img.set_pixel(9, 6, shadow)
	# Mouth
	for x in [3, 4, 5, 6]:
		img.set_pixel(x, 8, skin.darkened(0.45).lerp(Color(0.5, 0.15, 0.12), 0.4))
	for x in n:
		img.set_pixel(x, 9, shadow)
	match style:
		"stubble":
			for y in [7, 8, 9]:
				for x in n:
					if r.randf() < 0.45 and not (y == 8 and x >= 3 and x <= 6):
						img.set_pixel(x, y, skin.darkened(0.35))
		"beard":
			var bc := hair if not bald else Color(0.55, 0.52, 0.5)
			for y in range(6, 10):
				for x in n:
					if y == 8 and x >= 3 and x <= 6:
						continue
					if y >= 7 or x <= 1 or x >= 8:
						img.set_pixel(x, y, bc if r.randf() < 0.85 else bc.darkened(0.2))
			for x in [3, 4, 5, 6]:
				img.set_pixel(x, 7, bc)  # moustache
		"veil":
			for y in range(0, 6):
				for x in n:
					if y < 3 or (x < 2 or x > 7):
						img.set_pixel(x, y, Color(0.08, 0.08, 0.1))
		"mask":
			var pm := Color(0.94, 0.92, 0.86)
			for y in n:
				for x in n:
					img.set_pixel(x, y, pm)
			for x in [2, 3, 6, 7]:
				img.set_pixel(x, 4, Color(0.05, 0.02, 0.06))
			for x in [1, 3, 5, 7, 8]:
				img.set_pixel(x, 1, Color(0.6, 0.4, 0.9))  # the scratched, empty crown
			for x in range(1, 9):
				img.set_pixel(x, 2, Color(0.6, 0.4, 0.9))
			img.set_pixel(4, 7, pm.darkened(0.25))
			img.set_pixel(5, 7, pm.darkened(0.25))
		"goggles":
			for x in range(1, 9):
				img.set_pixel(x, 4, Color(0.35, 0.25, 0.15))
			for x in [2, 3, 6, 7]:
				img.set_pixel(x, 4, Color(0.3, 0.95, 0.85))
				img.set_pixel(x, 5, Color(0.2, 0.7, 0.65))
		"bandana":
			for y in range(6, 10):
				for x in n:
					img.set_pixel(x, y, Color(0.65, 0.12, 0.1) if (x + y) % 3 != 0 else Color(0.5, 0.08, 0.06))
		"hood":
			for y in n:
				for x in n:
					if x < 1 or x > 8 or y < 2:
						img.set_pixel(x, y, Color(0.1, 0.08, 0.06))
	return _done(key, img)


## Generic pixel grain: 2x2-pixel blocks of light and shade, a hard dark edge on each block now
## and then. Any flat colour becomes pixel art with this.
static func grain(base: Color, seed: int = 13) -> ImageTexture:
	var key := "grn_%s_%d" % [base.to_html(), seed]
	if _cache.has(key):
		return _cache[key]
	var n := 16
	var img := Image.create_empty(n, n, true, Image.FORMAT_RGB8)
	var r := _rng(seed)
	for by in n / 2:
		for bx in n / 2:
			var c := _shade(base, r.randf_range(-0.12, 0.08))
			if r.randf() < 0.08:
				c = base.darkened(0.3)
			for y in 2:
				for x in 2:
					img.set_pixel(bx * 2 + x, by * 2 + y, c)
	for x in n:
		img.set_pixel(x, 0, base.lightened(0.08))
		img.set_pixel(x, n - 1, base.darkened(0.25))
	return _done(key, img)


## Give every plain, flat-coloured, opaque material under `root` a pixel grain (in world space),
## so props built from simple boxes read as pixel art. Glowing, glassy and textured materials,
## and anything under a node in `skip`, are left as they are.
static func pixelize(root: Node, skip: Array = [], metres: float = 1.0) -> void:
	var swapped := {}
	_pixelize_rec(root, skip, metres, swapped)


static func _pixelize_rec(n: Node, skip: Array, metres: float, swapped: Dictionary) -> void:
	if n in skip:
		return
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var m := mi.material_override as StandardMaterial3D
		if m != null and m.albedo_texture == null and not m.emission_enabled and m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and m.metallic < 0.5:
			if not swapped.has(m):
				var nm := mat(grain(Color(m.albedo_color.r, m.albedo_color.g, m.albedo_color.b)), metres)
				swapped[m] = nm
			mi.material_override = swapped[m]
	for c in n.get_children():
		_pixelize_rec(c, skip, metres, swapped)
