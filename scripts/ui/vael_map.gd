extends Control
## The map of Vael, inked on old, coffee-stained parchment (parchment.gd): the walls and gates,
## every building and tree, the river and its bridge, the roads to the six lairs, and live marks
## for you, today's boss, the Lamplighter's errand and the secrets you have found.
## mini = true: a north-up minimap centred on you (clipped to its box); otherwise the whole map.

const UiArt := preload("res://scripts/ui/ui_art.gd")
const Parchment := preload("res://scripts/ui/parchment.gd")
const INK := Color(0.24, 0.13, 0.06, 0.92)
const INK_SOFT := Color(0.3, 0.17, 0.08, 0.55)
const WATER := Color(0.22, 0.34, 0.4, 0.5)
const RED := Color(0.62, 0.1, 0.06)
const WORLD := 100.0

var ow
var mini := false
var font: Font
var tex: Texture2D
var s := 1.0
var origin := Vector2.ZERO
var focus := Vector2.ZERO


func _ready() -> void:
	font = UiArt.pixel_font()
	# The same parchment the island was made from: dark stains are water, light paper is land.
	tex = Parchment.texture(ow.MAP_PX, ow.MAP_PX, ow.map_seed, true, ow.island_clears())
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func w2m(p: Vector3) -> Vector2:
	return origin + (Vector2(p.x, p.z) - focus) * s


func _draw() -> void:
	if ow == null or ow.walker == null:
		return
	var wp: Vector3 = ow.walker.position
	if mini:
		s = 2.4
		focus = Vector2(wp.x, wp.z)
		origin = size * 0.5
	else:
		s = minf(size.x, size.y) / (WORLD * 2.0)
		focus = Vector2.ZERO
		origin = size * 0.5
	# The paper
	var tl := w2m(Vector3(-WORLD, 0, -WORLD))
	draw_texture_rect(tex, Rect2(tl, Vector2(WORLD * 2.0, WORLD * 2.0) * s), false)
	# The river, in a wash of grey-blue ink with ripples
	var r0 := w2m(Vector3(-WORLD, 0, 68))
	draw_rect(Rect2(r0, Vector2(WORLD * 2.0 * s, 8.0 * s)), WATER)
	for k in 12:
		var x := -WORLD + 8.0 + k * 16.0
		draw_line(w2m(Vector3(x, 0, 71)), w2m(Vector3(x + 5, 0, 70.5)), Color(0.2, 0.3, 0.35, 0.6), 1.0)
		draw_line(w2m(Vector3(x + 5, 0, 70.5)), w2m(Vector3(x + 10, 0, 71.5)), Color(0.2, 0.3, 0.35, 0.6), 1.0)
	# Roads: dashed ink
	for seg in ow._roads():
		var a: Vector3 = seg[0]
		var b: Vector3 = seg[1]
		var n := int(a.distance_to(b) / 3.0)
		for k in n:
			if k % 2 == 0:
				draw_line(w2m(a.lerp(b, float(k) / n)), w2m(a.lerp(b, float(k + 1) / n)), INK_SOFT, maxf(1.0, s * 0.8))
	# Everything solid: walls and buildings as inked blocks, trees as little rings
	for r in ow.rects:
		var rr: Rect2 = r
		if (rr.size.x > 50.0 and rr.size.y == 8.0) or ow.sea_rects.has(rr):
			continue  # the river (drawn above) and the sea (the stains themselves)
		var area := rr.size.x * rr.size.y
		if area < 0.2:
			continue  # lamp posts
		var c := w2m(Vector3(rr.get_center().x, 0, rr.get_center().y))
		if area < 0.5:
			draw_arc(c, maxf(1.5, 1.1 * s), 0.0, TAU, 8, Color(0.25, 0.32, 0.12, 0.8), 1.0)
			continue
		var p0 := w2m(Vector3(rr.position.x, 0, rr.position.y))
		var box := Rect2(p0, rr.size * s)
		draw_rect(box, Color(0.36, 0.2, 0.09, 0.45))
		draw_rect(box, INK, false, 1.0)
	# The graveyard: little crosses
	for k in 6:
		var gp := w2m(Vector3(-64 + (k % 3) * 4.0, 0, 12 + (k / 3) * 5.0))
		draw_line(gp + Vector2(0, -3), gp + Vector2(0, 3), INK, 1.0)
		draw_line(gp + Vector2(-2, -1), gp + Vector2(2, -1), INK, 1.0)
	# Lairs: a ring, a name, and a red cross on today's
	var today = ow._boss_data()
	for lk in ow.LAIRS:
		var lp: Vector3 = ow.LAIRS[lk]
		var c2 := w2m(lp)
		var red: bool = not today.is_empty() and today["lair"] == lk and not GameState.day_boss_slain
		draw_arc(c2, 7.0 * s, 0.0, TAU, 20, RED if red else INK, 2.0 if red else 1.0)
		if red:
			draw_line(c2 + Vector2(-5, -5), c2 + Vector2(5, 5), RED, 2.0)
			draw_line(c2 + Vector2(-5, 5), c2 + Vector2(5, -5), RED, 2.0)
		if not mini:
			_text(c2 + Vector2(-100, 7.0 * s + 2), str(ow.LAIR_NAMES[lk]), RED if red else INK, 200)
	if not mini:
		for ml in ow.map_labels:
			if ml[1] in ["FOUNTAIN", "THE FORGE", "STABLES"]:
				continue  # too crowded inside the walls at this size
			_text(w2m(ml[0]) + Vector2(-120, -6), ml[1], INK, 240)
		_text(w2m(Vector3(0, 0, -44)) + Vector2(-100, -8), "VAEL", RED, 200, 24)
		_text(w2m(Vector3(-60, 0, 22)) + Vector2(-60, 0), "THE GRAVES", INK, 120)
		_text(w2m(Vector3(-40, 0, 80)) + Vector2(-60, 0), "THE RIVER", Color(0.2, 0.3, 0.35), 120)
		_compass_rose(Vector2(size.x - 60, 60))
	# Marks: the secrets you have found, the errand, today's boss, and you
	for sec in ow.Side.SECRETS:
		if GameState.secrets.has(sec["id"]):
			var sp := w2m(sec["pos"])
			draw_colored_polygon(PackedVector2Array([sp + Vector2(0, -4), sp + Vector2(4, 0), sp + Vector2(0, 4), sp + Vector2(-4, 0)]), Color(0.55, 0.35, 0.75))
	for m in ow._markers():
		var mp := w2m(m["pos"])
		var col: Color = m["color"].darkened(0.25)
		_star(mp, 6.0, col)
		if not mini:
			_text(mp + Vector2(-60, 6), m["label"], col, 120)
	var me := w2m(wp)
	var fwd := Vector2(-sin(ow.walker.yaw), -cos(ow.walker.yaw))
	var side := Vector2(-fwd.y, fwd.x)
	draw_colored_polygon(PackedVector2Array([me + fwd * 9.0, me - fwd * 5.0 + side * 5.0, me - fwd * 2.0, me - fwd * 5.0 - side * 5.0]), RED)
	draw_polyline(PackedVector2Array([me + fwd * 9.0, me - fwd * 5.0 + side * 5.0, me - fwd * 2.0, me - fwd * 5.0 - side * 5.0, me + fwd * 9.0]), Color(0.15, 0.05, 0.02), 1.0)
	if mini:
		_text(Vector2(4, 2), "N", RED, 20)


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI / 2.0 + TAU * k / 10.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, col)
	pts.append(pts[0])
	draw_polyline(pts, Color(0.15, 0.06, 0.02), 1.0)


func _compass_rose(c: Vector2) -> void:
	draw_arc(c, 30, 0.0, TAU, 24, INK, 1.0)
	draw_arc(c, 24, 0.0, TAU, 24, INK_SOFT, 1.0)
	for k in 4:
		var a := -PI / 2.0 + TAU * k / 4.0
		var d := Vector2(cos(a), sin(a))
		var n := Vector2(-d.y, d.x)
		draw_colored_polygon(PackedVector2Array([c + d * 34.0, c + n * 5.0, c - n * 5.0]), RED if k == 0 else INK)
	_text(c + Vector2(-20, -54), "N", RED, 40)


func _text(pos: Vector2, text: String, col: Color, width: float, fsize: int = 16) -> void:
	var base := pos + Vector2(0, fsize * 0.85)
	draw_string(font, base + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_CENTER, width, fsize, Color(0.95, 0.88, 0.7, 0.6))
	draw_string(font, base, text, HORIZONTAL_ALIGNMENT_CENTER, width, fsize, col)
