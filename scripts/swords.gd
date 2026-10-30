extends RefCounted
## Builds detailed low-poly blades from code: wrapped grips, pommels, quillons, fullers, edge bevels,
## glowing runes, curved sabres, geared axes, halberds and a plasma edge. Used for the blade in your
## hand by day, on Hennik's racks, on tavern walls, and stuck in a stump at the Burned Farm.
##
## build(id, length, level): the grip is at the origin and the blade points along -Z. `length` is the
## whole weapon's length in local units (about 0.5 in your hand, 1.0+ in the world).
## LEVEL (0..3, bought with Crowns in the inventory) reshapes the blade:
##   I   ETCHED     a glowing rune channel down the blade and a gem in the pommel
##   II  AWAKENED   burning edges, a winged guard and a ring of aether around the hilt
##   III ASCENDED   shards that orbit the blade (child "Orbit", spun by whoever holds it) and an aura
## Every weapon has a child marker "Tip" at its point (used for swing trails).

const Fx := preload("res://scripts/fx.gd")
const Dialogue := preload("res://scripts/dialogue.gd")


static func build(id: String, length: float, tune: int = 0) -> Node3D:
	var W: Dictionary = Dialogue.WEAPONS.get(id, Dialogue.WEAPONS["shortsword"])
	var root := Node3D.new()
	var L := length
	var col: Color = W["color"]
	var glow: float = float(W["glow"]) + 0.6 * tune
	var steel := Fx.mat(col, glow * 0.25)
	steel.metallic = 0.6
	steel.roughness = 0.35
	var edge := Fx.mat(col.lightened(0.45), glow * 0.4 + 0.2)
	var dark := Fx.mat(col.darkened(0.45))
	var rune := Fx.mat(col.lightened(0.2), 3.0 + glow)
	var leather := Fx.mat(Color(0.28, 0.16, 0.09))
	var wrap := Fx.mat(Color(0.45, 0.3, 0.15))
	var gold := Fx.mat(Color(0.85, 0.65, 0.22), 0.3)
	gold.metallic = 0.8
	var iron := Fx.mat(Color(0.3, 0.29, 0.31))
	match str(W["kind"]):
		"axe":
			_haft(root, L * 0.95, leather, wrap, iron)
			var head := Node3D.new()
			head.position = Vector3(0, 0, -L * 0.78)
			root.add_child(head)
			head.add_child(Fx.box(Vector3(L * 0.03, L * 0.26, L * 0.16), steel, Vector3(0, L * 0.1, 0)))
			head.add_child(Fx.box(Vector3(L * 0.034, L * 0.3, L * 0.03), edge, Vector3(0, L * 0.12, -L * 0.085)))
			head.add_child(Fx.box(Vector3(L * 0.05, L * 0.08, L * 0.08), iron, Vector3(0, -L * 0.02, 0)))
			# The gear: a toothed ring around the socket
			var gear := TorusMesh.new()
			gear.inner_radius = L * 0.05
			gear.outer_radius = L * 0.075
			gear.rings = 10
			gear.ring_segments = 4
			var gm := MeshInstance3D.new()
			gm.mesh = gear
			gm.material_override = gold
			gm.rotation.z = PI / 2.0
			head.add_child(gm)
			for k in 8:
				var a := TAU * k / 8.0
				head.add_child(Fx.box(Vector3(L * 0.03, L * 0.025, L * 0.025), gold, Vector3(0, cos(a) * L * 0.085, sin(a) * L * 0.085)))
			if glow > 0.0:
				head.add_child(Fx.box(Vector3(L * 0.036, L * 0.02, L * 0.02), rune, Vector3(0, 0, 0)))
		"halberd":
			_haft(root, L * 1.4, leather, wrap, iron)
			var hb := Node3D.new()
			hb.position = Vector3(0, 0, -L * 1.3)
			root.add_child(hb)
			hb.add_child(Fx.box(Vector3(L * 0.025, L * 0.04, L * 0.34), steel, Vector3(0, 0, -L * 0.12)))
			hb.add_child(Fx.box(Vector3(L * 0.028, L * 0.22, L * 0.16), steel, Vector3(0, L * 0.12, 0.0)))
			hb.add_child(Fx.box(Vector3(L * 0.03, L * 0.24, L * 0.02), edge, Vector3(0, L * 0.13, -L * 0.08)))
			var hook := Fx.box(Vector3(L * 0.025, L * 0.1, L * 0.04), steel, Vector3(0, -L * 0.07, L * 0.02))
			hook.rotation.x = -0.6
			hb.add_child(hook)
			hb.add_child(Fx.box(Vector3(L * 0.012, L * 0.012, L * 0.4), rune, Vector3(0, L * 0.03, -L * 0.1)))
		_:
			_hilt(root, L, W, leather, wrap, gold, iron, rune, glow)
			_blade(root, L, str(W["kind"]), id, steel, edge, dark, rune, glow)
	_upgrades(root, L, W, tune, col)
	var tipm := Marker3D.new()
	tipm.name = "Tip"
	var reach_z := {"axe": 0.92, "halberd": 1.55}
	tipm.position = Vector3(0, 0, -L * float(reach_z.get(str(W["kind"]), 0.98)))
	root.add_child(tipm)
	if glow >= 2.5:
		var l := OmniLight3D.new()
		l.light_color = col
		l.omni_range = L * 2.0
		l.light_energy = 0.5 + glow * 0.1
		l.position = Vector3(0, 0, -L * 0.6)
		root.add_child(l)
	return root


## Upgrade parts, layered on top of any blade.
static func _upgrades(root: Node3D, L: float, W: Dictionary, level: int, col: Color) -> void:
	if level <= 0:
		return
	var kind := str(W["kind"])
	var z0 := -L * (0.25 if kind in ["sword", "sabre", "great", "plasma"] else 0.7)
	var z1 := -L * (0.92 if kind != "halberd" else 1.45)
	var bright := col.lightened(0.35)
	var rune := Fx.mat(bright, 4.0 + level)
	var th := L * 0.02
	# I: a rune channel down the middle of the blade, and a pommel gem
	var n := 6
	for k in n:
		var z := lerpf(z0, z1, (k + 0.5) / n)
		root.add_child(Fx.box(Vector3(L * 0.018, th * 1.4, L * 0.04), rune, Vector3(0, 0, z)))
	root.add_child(Fx.box(Vector3.ONE * L * 0.05, Fx.mat(bright, 6.0), Vector3(0, 0, L * 0.16)))
	if level >= 2:
		# II: burning edges and a winged guard
		var edge := Fx.mat(bright, 6.0, 0.85)
		for s in [-1.0, 1.0]:
			root.add_child(Fx.box(Vector3(L * 0.008, th * 0.8, absf(z1 - z0)), edge, Vector3(s * L * 0.04, 0, (z0 + z1) * 0.5)))
			var wing := Fx.box(Vector3(L * 0.14, L * 0.02, L * 0.035), Fx.mat(col.darkened(0.2), 1.5), Vector3(s * L * 0.18, 0, -L * 0.13))
			wing.rotation.y = s * 0.6
			root.add_child(wing)
			root.add_child(Fx.box(Vector3.ONE * L * 0.028, rune, Vector3(s * L * 0.25, 0, -L * 0.17)))
		var ring := TorusMesh.new()
		ring.inner_radius = L * 0.07
		ring.outer_radius = L * 0.085
		ring.rings = 12
		ring.ring_segments = 4
		var rm := MeshInstance3D.new()
		rm.mesh = ring
		rm.material_override = Fx.mat(bright, 4.0, 0.8)
		rm.position = Vector3(0, 0, -L * 0.2)
		rm.rotation.x = PI / 2.0
		root.add_child(rm)
	if level >= 3:
		# III: orbiting shards and an aura of motes rising off the blade
		var orbit := Node3D.new()
		orbit.name = "Orbit"
		orbit.position = Vector3(0, 0, (z0 + z1) * 0.5)
		root.add_child(orbit)
		for k in 3:
			var a := TAU * k / 3.0
			var shard := Fx.box(Vector3(L * 0.025, L * 0.025, L * 0.09), Fx.mat(bright, 7.0), Vector3(cos(a) * L * 0.12, sin(a) * L * 0.12, 0))
			shard.rotation.z = a
			orbit.add_child(shard)
		var aura := Fx.particles(bright, 18, 0.7, 0.15, L * 0.02)
		aura.gravity = Vector3(0, 0.3, 0)
		aura.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		aura.emission_box_extents = Vector3(L * 0.03, L * 0.02, absf(z1 - z0) * 0.5)
		aura.position = Vector3(0, 0, (z0 + z1) * 0.5)
		aura.local_coords = true
		root.add_child(aura)
		var l3 := OmniLight3D.new()
		l3.light_color = bright
		l3.omni_range = L * 2.5
		l3.light_energy = 0.8
		l3.position = Vector3(0, 0, (z0 + z1) * 0.5)
		root.add_child(l3)


const LEVEL_NAMES := ["", "ETCHED", "AWAKENED", "ASCENDED"]

# How each blade cuts (boss.gd SWINGS) and sounds.
const STYLE := {
	"shortsword": "slash", "borrowed": "diagonal", "falchion": "backhand", "runeblade": "overhead",
	"cogaxe": "chop", "greatsword": "sweep", "arcbrand": "thrust2", "lionfang": "flourish",
	"halberd": "lunge_sweep", "sunedge": "rising",
}
const STYLE_NAMES := {
	"slash": "QUICK SLASH, FOREHAND THEN BACKHAND", "diagonal": "YOUR FATHER'S DIAGONAL CUT", "backhand": "BACKHAND FLICK",
	"overhead": "OVERHEAD CLEAVE", "chop": "WOUND-UP CHOP", "sweep": "WIDE SWEEP", "thrust2": "DOUBLE THRUST",
	"flourish": "TWIRL AND RISING CUT", "lunge_sweep": "LUNGE, THEN SWEEP", "rising": "RISING PLASMA ARC",
}


static func swing_style(id: String) -> String:
	return STYLE.get(id, "diagonal")


static func swing_sound(id: String) -> String:
	var W: Dictionary = Dialogue.WEAPONS.get(id, Dialogue.WEAPONS["shortsword"])
	match str(W["kind"]):
		"axe", "great", "halberd":
			return "swing_heavy"
		"plasma":
			return "swing_plasma"
	if float(W["glow"]) >= 2.5:
		return "swing_arc"
	return "swing_light"


static func _haft(root: Node3D, len_h: float, leather: Material, wrap: Material, iron: Material) -> void:
	var th := len_h * 0.035
	root.add_child(Fx.box(Vector3(th, th, len_h), Fx.mat(Color(0.35, 0.22, 0.12)), Vector3(0, 0, -len_h * 0.45)))
	for k in 4:
		root.add_child(Fx.box(Vector3(th * 1.25, th * 1.25, len_h * 0.03), wrap, Vector3(0, 0, -k * len_h * 0.05)))
	root.add_child(Fx.box(Vector3(th * 1.6, th * 1.6, th * 1.6), iron, Vector3(0, 0, len_h * 0.06)))


static func _hilt(root: Node3D, L: float, W: Dictionary, leather: Material, wrap: Material, gold: Material, iron: Material, rune: Material, glow: float) -> void:
	var kind := str(W["kind"])
	var grip_len := L * (0.3 if kind == "great" else 0.2)
	var g := L * 0.045
	# Grip, with a leather wrap in bands
	root.add_child(Fx.box(Vector3(g, g, grip_len), leather, Vector3(0, 0, 0)))
	var bands := 5 if kind == "great" else 4
	for k in bands:
		var z := -grip_len * 0.5 + grip_len * (k + 0.5) / bands
		root.add_child(Fx.box(Vector3(g * 1.18, g * 1.18, grip_len * 0.08), wrap, Vector3(0, 0, z)))
	# Pommel, with a gem on glowing blades
	var pm: Material = gold if kind != "plasma" else iron
	root.add_child(Fx.box(Vector3(g * 1.9, g * 1.9, g * 1.5), pm, Vector3(0, 0, grip_len * 0.5 + g * 0.6)))
	if glow > 0.0:
		root.add_child(Fx.box(Vector3(g, g, g * 0.6), rune, Vector3(0, 0, grip_len * 0.5 + g * 1.4)))
	# Guard: a bar with quillons that dip toward the blade
	var gw := L * (0.36 if kind == "great" else 0.26)
	var gz := -grip_len * 0.5 - g * 0.4
	root.add_child(Fx.box(Vector3(gw, g * 1.1, g * 1.3), gold, Vector3(0, 0, gz)))
	for s in [-1.0, 1.0]:
		var q := Fx.box(Vector3(g * 1.3, g * 1.3, g * 1.8), gold, Vector3(s * gw * 0.5, 0, gz - g * 0.5))
		q.rotation.y = s * 0.5
		root.add_child(q)
	root.add_child(Fx.box(Vector3(g * 1.6, g * 1.6, g * 1.2), gold, Vector3(0, 0, gz)))


static func _blade(root: Node3D, L: float, kind: String, id: String, steel: Material, edge: Material, dark: Material, rune: Material, glow: float) -> void:
	var grip_len := L * (0.3 if kind == "great" else 0.2)
	var base := -grip_len * 0.5 - L * 0.045
	var bl := L - grip_len - L * 0.06
	var w := L * (0.11 if kind == "great" else (0.085 if kind == "sabre" else 0.075))
	var th := L * 0.016
	if kind == "plasma":
		# A gold frame of two rails around a core of light
		var core := Fx.mat(Color(1.0, 0.85, 0.5), 6.0)
		var frame := Fx.mat(Color(0.85, 0.65, 0.22), 0.4)
		for s in [-1.0, 1.0]:
			root.add_child(Fx.box(Vector3(w * 0.22, th * 1.6, bl * 0.92), frame, Vector3(s * w * 0.55, 0, base - bl * 0.46)))
		root.add_child(Fx.box(Vector3(w * 0.8, th * 0.6, bl), core, Vector3(0, 0, base - bl * 0.5)))
		root.add_child(Fx.box(Vector3(w * 1.3, th * 0.3, bl * 1.02), Fx.mat(Color(1.0, 0.9, 0.6), 3.0, 0.35), Vector3(0, 0, base - bl * 0.5)))
		return
	var segs := 4 if kind == "sabre" else 1
	var seg_len := bl / segs
	var pos := Vector3(0, 0, base)
	var ang := 0.0
	for k in segs:
		var piece := Node3D.new()
		piece.position = pos
		piece.rotation.x = ang
		root.add_child(piece)
		var taper := 1.0 - 0.12 * k
		piece.add_child(Fx.box(Vector3(w * taper, th, seg_len * 1.02), steel, Vector3(0, 0, -seg_len * 0.5)))
		# Edge bevels and the fuller (a dark groove down the middle)
		for s in [-1.0, 1.0]:
			piece.add_child(Fx.box(Vector3(w * 0.14, th * 0.7, seg_len * 1.02), edge, Vector3(s * w * taper * 0.47, 0, -seg_len * 0.5)))
		if kind != "sabre" or k < 2:
			piece.add_child(Fx.box(Vector3(w * 0.22, th * 1.15, seg_len * 0.75), dark, Vector3(0, 0, -seg_len * 0.45)))
		if glow > 0.0:
			for r in 3:
				piece.add_child(Fx.box(Vector3(w * 0.12, th * 1.3, seg_len * 0.06), rune, Vector3(0, 0, -seg_len * (0.2 + r * 0.22))))
		pos += Vector3(0, -sin(ang) * seg_len, -cos(ang) * seg_len)
		if kind == "sabre":
			ang -= 0.09  # the curve
	# The point: a diamond turned edge-on, so it reads as a tapering tip
	var tip := Fx.box(Vector3(w * 0.7, th, w * 0.7), steel, pos + Vector3(0, -sin(ang) * w * 0.1, -cos(ang) * w * 0.1))
	tip.rotation = Vector3(ang, PI / 4.0, 0)
	tip.scale = Vector3(1.0, 1.0, 1.0)
	root.add_child(tip)
	if id == "shortsword":
		# Rust and nicks
		var rust := Fx.mat(Color(0.45, 0.25, 0.12))
		for k in 4:
			root.add_child(Fx.box(Vector3(w * 0.3, th * 1.2, bl * 0.05), rust, Vector3((k % 2 - 0.5) * w * 0.5, 0, base - bl * (0.2 + k * 0.17))))
	if kind == "great":
		# A ricasso: an unsharpened stretch above the guard, wrapped in leather
		root.add_child(Fx.box(Vector3(w * 0.7, th * 1.6, bl * 0.12), Fx.mat(Color(0.28, 0.16, 0.09)), Vector3(0, 0, base - bl * 0.06)))
