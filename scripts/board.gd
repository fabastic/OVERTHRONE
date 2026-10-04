extends Node3D
## The tabletop: the Hollow King's life as a candlelit board game (Inscryption-style).
## The King is a carved piece. The path snakes across six regions, one per chapter of his past.
## Regions beyond the next demon lie under fog. Landing on a tile emits `arrived`; main.gd
## resolves it (story, event, treasure, altar, or the DEMON fight).
## The table is the corner table of the Hollow Flagon: tankards, a lantern, and across from you,
## seated, the Stranger (stranger.gd), playing the other side.

signal arrived(tile: Dictionary)

const Story := preload("res://scripts/story.gd")
const Fx := preload("res://scripts/fx.gd")
const HeroScript := preload("res://scripts/hero.gd")
const UiArt := preload("res://scripts/ui/ui_art.gd")
const StrangerScript := preload("res://scripts/stranger.gd")
const ROW_GAP := 2.7
const COL_GAP := 2.1
const START := Vector3(-4.2, 0, 2.6)

var game
var cam: Camera3D
var piece: Node3D
var gem_root: Node3D
var tiles: Array = []
var candle_lights: Array = []
var fog: Array = []  # per chapter: Node3D of fog puffs
var signs: Array = []  # per chapter: Label3D region sign
var moving := false
var hop_from := Vector3.ZERO
var hop_to := Vector3.ZERO
var hop_target := -1
var cam_focus := Vector3.ZERO
var t := 0.0
var stranger


func _ready() -> void:
	tiles = Story.tiles_flat()
	_build_table()
	for i in tiles.size():
		_build_tile(i)
	for c in Story.CHAPTERS.size():
		_build_region(c)
	_build_piece()
	_build_tavern()
	cam = Camera3D.new()
	cam.fov = 48.0
	cam.far = 60.0
	add_child(cam)
	snap_to_current()
	refresh()


# =============================================================================
# Layout
# =============================================================================

func tile_pos(i: int) -> Vector3:
	if i < 0:
		return START
	var c: int = tiles[i]["chapter"]
	var k: int = tiles[i]["index"]
	var dir := 1.0 if c % 2 == 0 else -1.0
	return Vector3((k * COL_GAP - 2.0 * COL_GAP) * dir, 0, -c * ROW_GAP)


func current_tile() -> Dictionary:
	var i := GameState.board_tile
	return tiles[i] if i >= 0 and i < tiles.size() else {}


## The next tile, or -1 if the road is closed (the demon ahead has not been passed yet).
func next_index() -> int:
	var i := GameState.board_tile + 1
	if i >= tiles.size():
		return -1
	if tiles[i]["chapter"] > GameState.level - 1:
		return -1
	return i


# =============================================================================
# Building
# =============================================================================

func _build_table() -> void:
	var wood := Fx.textured(Fx.stone_texture(Color(0.22, 0.13, 0.08), Color(0.18, 0.1, 0.06), 32, 2, true), Vector3(10, 10, 1))
	var table := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	table.mesh = pm
	table.material_override = wood
	table.position = Vector3(0, -0.2, -6)
	add_child(table)
	var parchment := Fx.textured(Fx.stone_texture(Color(0.42, 0.36, 0.26), Color(0.38, 0.32, 0.23), 32, 8), Vector3(6, 8, 1))
	add_child(Fx.box(Vector3(13.5, 0.2, 19.0), parchment, Vector3(0, -0.1, -5.6)))
	var trim := Fx.mat(Color(0.35, 0.12, 0.08))
	for s in [-1.0, 1.0]:
		add_child(Fx.box(Vector3(0.3, 0.3, 19.2), trim, Vector3(s * 6.85, -0.05, -5.6)))
		add_child(Fx.box(Vector3(13.9, 0.3, 0.3), trim, Vector3(0, -0.05, -5.6 + s * 9.6)))
	# The start plinth
	add_child(Fx.cylinder(0.75, 0.85, 0.25, Fx.mat(Color(0.3, 0.1, 0.1)), START + Vector3(0, 0.12, 0)))
	# Candles at the corners of the table
	for cp in [Vector3(-8.5, 0, 3.5), Vector3(8.5, 0, 3.5), Vector3(-8.5, 0, -14), Vector3(8.5, 0, -14), Vector3(7.8, 0, -5)]:
		add_child(Fx.cylinder(0.25, 0.3, 1.4, Fx.mat(Color(0.85, 0.8, 0.65)), cp + Vector3(0, 0.5, 0)))
		add_child(Fx.box(Vector3(0.14, 0.26, 0.14), Fx.mat(Color(1.0, 0.65, 0.25), 6.0), cp + Vector3(0, 1.35, 0)))
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.65, 0.35)
		l.omni_range = 11.0
		l.light_energy = 1.6
		l.position = cp + Vector3(0, 1.8, 0)
		l.shadow_enabled = true
		add_child(l)
		candle_lights.append(l)
	# A skull and a stack of cards, for company
	var bone := Fx.mat(Color(0.85, 0.82, 0.7))
	add_child(Fx.sphere(0.6, bone, Vector3(-8.2, 0.4, -6.5)))
	add_child(Fx.box(Vector3(0.7, 0.35, 0.5), bone, Vector3(-8.2, 0.05, -6.0)))
	for k in 6:
		var card := Fx.box(Vector3(1.0, 0.03, 1.4), Fx.mat(Color(0.75, 0.68, 0.55) if k < 5 else Color(0.4, 0.1, 0.1)), Vector3(8.3, k * 0.035, 0.5))
		card.rotation.y = randf_range(-0.15, 0.15)
		add_child(card)
	var warm := SpotLight3D.new()
	warm.position = Vector3(0, 14, -3)
	warm.rotation_degrees = Vector3(-80, 0, 0)
	warm.spot_range = 30.0
	warm.spot_angle = 40.0
	warm.light_energy = 1.4
	warm.light_color = Color(1.0, 0.85, 0.65)
	add_child(warm)


func _build_tile(i: int) -> void:
	var td: Dictionary = tiles[i]
	var c: int = td["chapter"]
	var data: Dictionary = td["data"]
	var tint: Color = Story.CHAPTERS[c]["color"]
	var node := Node3D.new()
	node.position = tile_pos(i)
	add_child(node)
	var mat := Fx.mat(tint.darkened(0.35))
	var stone := Fx.box(Vector3(1.55, 0.2, 1.55), mat, Vector3(0, 0.1, 0))
	node.add_child(stone)
	var marker := Node3D.new()
	marker.position.y = 0.2
	node.add_child(marker)
	match data["type"]:
		"story":
			var scroll := Fx.cylinder(0.12, 0.12, 0.7, Fx.mat(Color(0.92, 0.86, 0.7)), Vector3(0, 0.15, 0))
			scroll.rotation.z = PI / 2.0
			marker.add_child(scroll)
		"event":
			var q := Label3D.new()
			q.text = "?"
			q.font = UiArt.pixel_font()
			q.font_size = 64
			q.pixel_size = 0.012
			q.modulate = Color(1.0, 0.8, 0.3)
			q.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			q.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			q.position.y = 0.6
			marker.add_child(q)
		"treasure":
			marker.add_child(Fx.box(Vector3(0.6, 0.35, 0.42), Fx.mat(Color(0.4, 0.22, 0.1)), Vector3(0, 0.18, 0)))
			marker.add_child(Fx.box(Vector3(0.64, 0.12, 0.46), Fx.mat(Color(0.85, 0.65, 0.2), 0.6), Vector3(0, 0.4, 0)))
		"altar":
			marker.add_child(Fx.box(Vector3(0.35, 0.8, 0.35), Fx.mat(Color(0.3, 0.28, 0.32)), Vector3(0, 0.4, 0)))
			marker.add_child(Fx.box(Vector3(0.18, 0.28, 0.18), Fx.mat(Color(0.6, 0.4, 1.0), 6.0), Vector3(0, 0.95, 0)))
		"demon":
			var hd: Dictionary = GameState.HEROES[mini(c, GameState.HEROES.size() - 1)]
			var fig = HeroScript.new()
			fig.figurine = true
			fig.form = hd["form"]
			fig.armor_color = hd["armor"]
			fig.cape_color = hd["cape"]
			fig.hero_scale = 0.42
			marker.add_child(fig)
			fig.rotation.y = PI
			fig.sigils.visible = false
			var ring := Fx.cylinder(0.75, 0.75, 0.03, Fx.mat(Color(0.9, 0.15, 0.1), 2.5, 0.6), Vector3(0, 0.02, 0))
			marker.add_child(ring)
			mat.albedo_color = Color(0.35, 0.08, 0.08)
	td["node"] = node
	td["mat"] = mat
	td["marker"] = marker
	td["tint"] = tint


func _build_region(c: int) -> void:
	var ch: Dictionary = Story.CHAPTERS[c]
	var z := -c * ROW_GAP
	var side := -1.0 if c % 2 == 0 else 1.0  # props on the side the row starts from
	var base := Vector3(side * 5.9, 0, z)
	var dark := Fx.mat(Color(ch["color"]).darkened(0.5))
	var lit := Fx.mat(ch["color"], 0.4)
	match ch["prop"]:
		"village":
			for k in 3:
				var h := base + Vector3(0, 0, -0.7 + k * 0.7)
				add_child(Fx.box(Vector3(0.45, 0.35, 0.45), Fx.mat(Color(0.18, 0.12, 0.1)), h + Vector3(0, 0.17, 0)))
				var roof := Fx.box(Vector3(0.36, 0.36, 0.5), Fx.mat(Color(0.12, 0.08, 0.06)), h + Vector3(0, 0.42, 0))
				roof.rotation.z = PI / 4.0
				add_child(roof)
		"keep":
			add_child(Fx.cylinder(0.4, 0.45, 1.6, dark, base + Vector3(0, 0.8, 0)))
			for k in 6:
				var a := TAU * k / 6.0
				add_child(Fx.box(Vector3(0.15, 0.2, 0.15), dark, base + Vector3(cos(a) * 0.4, 1.7, sin(a) * 0.4)))
		"arena":
			var tm := TorusMesh.new()
			tm.inner_radius = 0.5
			tm.outer_radius = 0.8
			tm.rings = 24
			tm.ring_segments = 6
			var ar := MeshInstance3D.new()
			ar.mesh = tm
			ar.material_override = lit
			ar.position = base + Vector3(0, 0.15, 0)
			ar.scale = Vector3(1, 1.5, 1)
			add_child(ar)
		"cathedral":
			add_child(Fx.box(Vector3(0.6, 0.9, 1.0), lit, base + Vector3(0, 0.45, 0)))
			add_child(Fx.cylinder(0.0, 0.3, 1.2, lit, base + Vector3(0, 1.5, -0.3)))
		"peaks":
			for k in 3:
				var pk := base + Vector3(0, 0, -0.6 + k * 0.6)
				var hgt := 0.9 + k % 2 * 0.5
				add_child(Fx.cylinder(0.0, 0.45, hgt, dark, pk + Vector3(0, hgt * 0.5, 0)))
				add_child(Fx.cylinder(0.0, 0.16, hgt * 0.3, Fx.mat(Color(0.95, 0.95, 1.0)), pk + Vector3(0, hgt * 0.87, 0)))
		"spire":
			add_child(Fx.box(Vector3(0.35, 2.6, 0.35), Fx.mat(ch["color"], 2.0), base + Vector3(0, 1.3, 0)))
			var l := OmniLight3D.new()
			l.light_color = ch["color"]
			l.omni_range = 4.0
			l.light_energy = 1.5
			l.position = base + Vector3(0, 2.8, 0)
			add_child(l)
	var label := Label3D.new()
	label.text = ch["region"]
	label.font = UiArt.pixel_font()
	label.font_size = 32
	label.pixel_size = 0.009
	label.modulate = Color(ch["color"]).lightened(0.3)
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 6
	label.position = base + Vector3(0, 1.9, 0)  # a floating sign above the region's landmark
	add_child(label)
	signs.append(label)
	# Fog over regions not yet reached
	var f := Node3D.new()
	add_child(f)
	var fog_mat := Fx.mat(Color(0.16, 0.13, 0.2), 0.0, 0.6)
	for k in 11:
		f.add_child(Fx.sphere(randf_range(0.5, 0.8), fog_mat, Vector3(-5.0 + k * 1.0, 0.35, z + randf_range(-0.35, 0.35))))
	fog.append(f)


func _build_piece() -> void:
	piece = Node3D.new()
	add_child(piece)
	var gold := Fx.mat(Color(0.8, 0.6, 0.2), 0.3)
	var robe := Fx.mat(Color(0.25, 0.1, 0.3))
	var skin := Fx.mat(Color(0.42, 0.37, 0.5))
	piece.add_child(Fx.cylinder(0.32, 0.36, 0.12, gold, Vector3(0, 0.06, 0)))
	piece.add_child(Fx.cylinder(0.14, 0.3, 0.75, robe, Vector3(0, 0.5, 0)))
	piece.add_child(Fx.box(Vector3(0.5, 0.12, 0.2), robe, Vector3(0, 0.82, 0)))
	piece.add_child(Fx.sphere(0.14, skin, Vector3(0, 1.0, 0)))
	for s in [-1.0, 1.0]:
		piece.add_child(Fx.box(Vector3(0.03, 0.03, 0.01), Fx.mat(Color(1.0, 0.2, 0.1), 5.0), Vector3(s * 0.05, 1.02, -0.135)))
	piece.add_child(Fx.cylinder(0.15, 0.15, 0.06, gold, Vector3(0, 1.13, 0)))
	for k in 5:
		var a := TAU * k / 5.0
		piece.add_child(Fx.box(Vector3(0.04, 0.1, 0.04), gold, Vector3(cos(a) * 0.13, 1.2, sin(a) * 0.13)))
	gem_root = Node3D.new()
	gem_root.position = Vector3(0, 1.14, 0)
	piece.add_child(gem_root)
	var aura := OmniLight3D.new()
	aura.light_color = Color(0.7, 0.3, 1.0)
	aura.omni_range = 2.2
	aura.light_energy = 0.8
	aura.position = Vector3(0, 1.4, 0)
	piece.add_child(aura)


## The Hollow Flagon around the board: the Stranger seated across the table, tankards, a lantern,
## and the dark of the tavern behind him.
func _build_tavern() -> void:
	stranger = StrangerScript.new()
	stranger.seated = true
	add_child(stranger)
	stranger.scale = Vector3.ONE * 5.0
	stranger.position = Vector3(0, -3.9, -18.6)
	stranger.rotation.y = PI  # facing you, down the table
	var pewter := Fx.mat(Color(0.55, 0.55, 0.6))
	var ale := Fx.mat(Color(0.75, 0.5, 0.15), 0.4)
	for tp in [Vector3(-8.0, 0, -12.0), Vector3(8.6, 0, -10.0), Vector3(-7.6, 0, 1.8)]:
		add_child(Fx.cylinder(0.45, 0.45, 1.2, pewter, tp + Vector3(0, 0.5, 0)))
		add_child(Fx.cylinder(0.38, 0.38, 0.05, ale, tp + Vector3(0, 1.08, 0)))
		var handle := Fx.box(Vector3(0.15, 0.7, 0.15), pewter, tp + Vector3(0.6, 0.55, 0))
		add_child(handle)
	# A lantern on his side of the table
	add_child(Fx.box(Vector3(0.8, 1.3, 0.8), Fx.mat(Color(0.15, 0.12, 0.1)), Vector3(5.5, 0.55, -14.5)))
	add_child(Fx.box(Vector3(0.55, 0.8, 0.55), Fx.mat(Color(1.0, 0.75, 0.4), 4.0), Vector3(5.5, 0.6, -14.5)))
	var ll := OmniLight3D.new()
	ll.light_color = Color(1.0, 0.7, 0.4)
	ll.omni_range = 9.0
	ll.light_energy = 1.4
	ll.position = Vector3(5.5, 1.6, -14.5)
	add_child(ll)
	# The tavern behind him: a back wall, a shelf of bottles, a hearth glow.
	var wallm := Fx.textured(Fx.stone_texture(Color(0.22, 0.15, 0.1), Color(0.18, 0.12, 0.08), 32, 4, true), Vector3(8, 3, 1))
	add_child(Fx.box(Vector3(40, 16, 1), wallm, Vector3(0, 2.0, -27)))
	add_child(Fx.box(Vector3(10, 0.3, 1.2), Fx.mat(Color(0.3, 0.2, 0.12)), Vector3(-9, 5.0, -26.2)))
	for k in 8:
		add_child(Fx.cylinder(0.18, 0.22, 0.9, Fx.mat([Color(0.2, 0.5, 0.25), Color(0.5, 0.2, 0.15), Color(0.3, 0.3, 0.55)][k % 3], 0.3), Vector3(-13 + k * 1.1, 5.6, -26.2)))
	var hearth := OmniLight3D.new()
	hearth.light_color = Color(1.0, 0.45, 0.2)
	hearth.omni_range = 14.0
	hearth.light_energy = 1.6
	hearth.position = Vector3(12, 1.0, -24)
	add_child(hearth)
	candle_lights.append(hearth)


## On a new night, the camera starts on him and drifts back to your piece.
func peek_stranger() -> void:
	cam_focus = Vector3(0, 0, -12.5)


# =============================================================================
# State
# =============================================================================

## Re-color tiles for locked / reachable / visited, hide fog over open regions, set crown gems.
func refresh() -> void:
	for i in tiles.size():
		var td: Dictionary = tiles[i]
		var c: int = td["chapter"]
		var open: bool = c <= GameState.level - 1
		var visited: bool = i <= GameState.board_tile
		var mat: StandardMaterial3D = td["mat"]
		var marker: Node3D = td["marker"]
		var tint: Color = td["tint"]
		var is_demon: bool = td["data"]["type"] == "demon"
		var passed: bool = is_demon and c < GameState.level - 1
		if not open:
			mat.albedo_color = Color(0.12, 0.1, 0.12)
			mat.emission_enabled = false
		elif passed:
			mat.albedo_color = Color(0.75, 0.6, 0.25)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.8, 0.3)
			mat.emission_energy_multiplier = 0.6
		elif visited:
			mat.albedo_color = tint.darkened(0.6)
			mat.emission_enabled = false
		else:
			mat.albedo_color = Color(0.35, 0.08, 0.08) if is_demon else tint.darkened(0.2)
			mat.emission_enabled = i == next_index()
			mat.emission = tint
			mat.emission_energy_multiplier = 0.5
		marker.visible = open and (not visited or is_demon)
	for c in fog.size():
		(fog[c] as Node3D).visible = c > GameState.level - 1
		(signs[c] as Label3D).visible = c <= GameState.level  # this region and the next
	if stranger:
		stranger.refresh()
	for g in gem_root.get_children():
		g.queue_free()
	var gem_cols := [Color(0.9, 0.3, 0.2), Color(0.3, 0.5, 1.0), Color(1.0, 0.8, 0.2), Color(0.9, 0.9, 1.0), Color(0.5, 0.9, 1.0), Color(1.0, 0.6, 0.3)]
	for k in GameState.relics.size():
		var a := TAU * k / 6.0
		gem_root.add_child(Fx.box(Vector3.ONE * 0.05, Fx.mat(gem_cols[k % gem_cols.size()], 5.0), Vector3(cos(a) * 0.155, 0.0, sin(a) * 0.155)))


## Fog rolls back over a newly opened region, tile by tile.
func reveal_chapter(c: int) -> void:
	var f: Node3D = fog[c]
	f.visible = true
	var tw := create_tween()
	for puff in f.get_children():
		tw.parallel().tween_property(puff, "scale", Vector3.ONE * 0.01, 1.2).set_delay(randf() * 0.4)
	tw.tween_callback(func(): f.visible = false)
	var k := 0
	for td in tiles:
		if td["chapter"] != c:
			continue
		var node: Node3D = td["node"]
		node.position.y = -0.6
		var tt := create_tween()
		tt.tween_interval(0.3 + k * 0.18)
		tt.tween_property(node, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tt.tween_callback(func(): Sfx.play("coin", -8.0, 1.0 + k * 0.08))
		k += 1
	refresh()


func snap_to_current() -> void:
	piece.position = tile_pos(GameState.board_tile) + Vector3(0, 0.2, 0)
	cam_focus = piece.position


## Hop the piece to the next tile. Returns false if the road is closed.
func advance() -> bool:
	if moving:
		return false
	var nxt := next_index()
	if nxt < 0:
		return false
	moving = true
	hop_from = piece.position
	hop_to = tile_pos(nxt) + Vector3(0, 0.2, 0)
	hop_target = nxt
	var tw := create_tween()
	tw.tween_method(_hop, 0.0, 1.0, 0.42)
	tw.tween_callback(_land)
	Sfx.play("dodge", -10.0, 0.6)
	return true


func _hop(k: float) -> void:
	piece.position = hop_from.lerp(hop_to, k) + Vector3(0, sin(k * PI) * 0.7, 0)
	piece.rotation.y = lerp_angle(piece.rotation.y, atan2(hop_from.x - hop_to.x, hop_from.z - hop_to.z), 0.2)


func _land() -> void:
	moving = false
	GameState.board_tile = hop_target
	Sfx.play("click", -2.0, 0.6)
	refresh()
	arrived.emit(tiles[hop_target])


func _process(delta: float) -> void:
	t += delta
	for l in candle_lights:
		(l as OmniLight3D).light_energy = 1.6 * (0.85 + randf() * 0.15)
	cam_focus = cam_focus.lerp(piece.position, 1.0 - exp(-delta * 3.0))
	cam.position = cam_focus + Vector3(0.0, 6.2, 5.6)
	cam.look_at(to_global(cam_focus + Vector3(0, 0, -1.6)), Vector3.UP)  # look_at takes world space
	gem_root.rotation.y += delta * 0.8
	# Bob the event markers
	for td in tiles:
		if td["data"]["type"] == "event":
			(td["marker"] as Node3D).position.y = 0.2 + sin(t * 2.5 + td["index"]) * 0.08
