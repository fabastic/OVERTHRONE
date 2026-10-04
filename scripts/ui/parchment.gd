extends RefCounted
## Old, stained parchment, generated in code: a sepia wash in layered noise, coffee-ring stains
## with a dark tide-mark where each one dried, darker pooling inside them, fine speckle and fibre,
## and torn, bleached patches along the edges where the paper has worn through.
## Used for the map of Vael (vael_map.gd) and for the board, which is a map of the King's life.
##
## The map IS the land: wetness() is shared with overworld.gd, so every dark stain on the map is
## water in Vael (sea and lakes, with a sandy shore where the stain's tide-mark dries) and the light
## paper is the island. An island falloff darkens the paper toward its edges: the open sea.
## `clears` keeps places dry (the city, the lairs, the roads): [[centre in pixels, radius in pixels], ...]

const WET := 0.12      # wetter than this is water
const SHORE := 0.07    # between SHORE and WET: the shore

static var _cache := {}
static var _noise := {}


static func _stain_noise(seed: int, w: int) -> FastNoiseLite:
	var key := "%d_%d" % [seed, w]
	if not _noise.has(key):
		var stain := FastNoiseLite.new()
		stain.seed = seed + 11
		stain.noise_type = FastNoiseLite.TYPE_SIMPLEX
		stain.frequency = 3.2 / w
		stain.fractal_octaves = 4
		stain.fractal_gain = 0.55
		_noise[key] = stain
	return _noise[key]


## The dry zones rasterized once into a w*w field (the strongest pull toward dry at each pixel),
## so looking one up is free however many zones there are.
static func clear_field(w: int, clears: Array) -> PackedFloat32Array:
	var key := "field_%d_%d" % [w, clears.size()]
	if _cache.has(key):
		return _cache[key]
	var f := PackedFloat32Array()
	f.resize(w * w)
	for c in clears:
		var cp: Vector2 = c[0]
		var r: float = c[1]
		for y in range(maxi(0, int(cp.y - r)), mini(w, int(cp.y + r) + 1)):
			for x in range(maxi(0, int(cp.x - r)), mini(w, int(cp.x + r) + 1)):
				var dd := Vector2(x, y).distance_to(cp)
				if dd < r:
					var i := y * w + x
					f[i] = maxf(f[i], (1.0 - dd / r) * 1.2)
	_cache[key] = f
	return f


## How wet the paper (and the land) is at pixel (px, py) of a w-wide square map.
static func wetness(px: float, py: float, w: int, seed: int, island: bool, field: PackedFloat32Array = PackedFloat32Array()) -> float:
	var v := _stain_noise(seed, w).get_noise_2d(px, py)
	if island:
		var d := Vector2(px - w * 0.5, py - w * 0.5).length() / (w * 0.5)
		v += maxf(0.0, d - 0.74) * 2.2
	if not field.is_empty():
		var ix := clampi(int(px), 0, w - 1)
		var iy := clampi(int(py), 0, w - 1)
		v -= field[iy * w + ix]
	return v


static func texture(w: int, h: int, seed: int = 3, island: bool = false, clears: Array = []) -> ImageTexture:
	var key := "%d_%d_%d_%s_%d" % [w, h, seed, island, clears.size()]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGB8)
	var field := clear_field(w, clears) if not clears.is_empty() and w == h else PackedFloat32Array()
	var wash := FastNoiseLite.new()
	wash.seed = seed
	wash.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	wash.frequency = 2.2 / w
	wash.fractal_octaves = 5
	var grain := FastNoiseLite.new()
	grain.seed = seed + 23
	grain.frequency = 0.35
	var edge := FastNoiseLite.new()
	edge.seed = seed + 41
	edge.frequency = 6.0 / w
	edge.fractal_octaves = 3
	var light := Color(0.9, 0.8, 0.6)
	var mid := Color(0.74, 0.57, 0.34)
	var dark := Color(0.46, 0.3, 0.14)
	var ring := Color(0.32, 0.19, 0.08)
	var bare := Color(0.97, 0.95, 0.9)
	for y in h:
		for x in w:
			var n := wash.get_noise_2d(x, y) * 0.5 + 0.5
			var c := light.lerp(mid, clampf(n * 1.3 - 0.15, 0.0, 1.0))
			# Stains: inside a stain the paper darkens, and its border dries into a sharp dark ring.
			var sv := wetness(x, y, w, seed, island, field)
			if sv > 0.12:
				var depth := clampf((sv - 0.12) * 3.0, 0.0, 1.0)
				c = c.lerp(dark, 0.45 + 0.35 * depth)  # deep stains: the water
				var rim := 1.0 - clampf((sv - 0.12) / 0.035, 0.0, 1.0)
				c = c.lerp(ring, rim * 0.75)
			elif sv > 0.08:
				c = c.lerp(ring, (sv - 0.08) / 0.04 * 0.35)
			# Fibre and speckle
			var g := grain.get_noise_2d(x, y)
			c = c.darkened(maxf(0.0, g) * 0.08)
			if randf() < 0.004:
				c = c.lerp(ring, 0.5)
			# Worn-through patches along the edges: bleached paper with a brown, ragged border
			var bx := minf(float(x), float(w - 1 - x)) / w
			var by := minf(float(y), float(h - 1 - y)) / h
			var border := minf(bx * 1.4, by)
			var tear := edge.get_noise_2d(x, y) * 0.5 + 0.5
			var cut := 0.11 * tear - border
			if cut > 0.0:
				c = bare if cut > 0.012 else c.lerp(ring, 0.8)
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
