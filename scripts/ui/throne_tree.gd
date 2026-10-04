extends Control
## The Throne of Thought, drawn as a pixel-art Tree of Life, in three pages:
##   GRIMOIRE   seven CLASSES, one per bough: skills inward, the class sigil at the tip.
##              Click a sigil to unlock the class (Crowns) or make it your active class.
##   ASCENSION  four perk branches bought with Dread (kept for the whole run)
##   ETERNITY   permanent upgrades bought with Crowns (earned when a hero conquers you)
## On every page the crown is your loadout and the roots are the Rite of Summoning.
## Mouse: hover for details, click to equip / buy / perform the rite, click tabs to switch.
## Keys:  Q/E or TAB switch pages, arrows move, SPACE activates, ENTER continues, ESC leaves the rite.
## Laid out on a fixed 426x240 art grid scaled 3x, so it fits any window.

signal let_him_come

const UiArt := preload("res://scripts/ui/ui_art.gd")
const S := 3
const W := 426
const H := 240
const TRUNK_X := 213
const CROWN_Y := 48
const ROOT_Y := 198
const ROW_Y := [84, 111, 138, 165]
const LEFT_X := [162, 138, 114, 90, 66, 42]    # inner -> outer
const RIGHT_X := [264, 288, 312, 336, 360, 384]
# Class boughs: [side, row, class id]
const CLASS_ROWS := [["L", 0, "pyro"], ["L", 1, "bone"], ["L", 2, "rime"], ["L", 3, "war"],
	["R", 0, "storm"], ["R", 1, "void"], ["R", 2, "blood"]]
const PAGES := ["grimoire", "ascension", "eternity"]
const PAGE_TITLES := ["GRIMOIRE", "ASCENSION", "ETERNITY"]

# [side, row, label, ids inner -> outer]
const ASCENSION_ROWS := [
	["L", 0, "TYRANNY", ["vigor", "wrath", "presence", "colossal"]],
	["L", 1, "CUNNING", ["haste", "unreadable", "fog", "misdirect"]],
	["L", 2, "MOTION", ["fleet", "afterimage", "phantom", "widedais"]],
	["R", 0, "HUNGER", ["harvest", "generous", "fated", "bottomless"]],
	["R", 1, "GUARD", ["talons", "scale", "riposte", "bastion"]],
	["R", 2, "SORCERY", ["overflow", "echo", "surge", "archmage"]],
]
const ETERNITY_ROWS := [
	["L", 0, "", ["colossus", "might"]],
	["L", 1, "", ["grudge"]],
	["L", 2, "", ["fate"]],
	["R", 0, "", ["unknowable"]],
	["R", 1, "", ["finger"]],
	["R", 2, "", ["reflex"]],
]
const NODE_SIZE := 21
const ROOT_SIZE := 27
const TIP_W := 372

static var _backdrop: ImageTexture

var BG := Color("1a1430")
var TREE := Color("2e3560")
var TREE_HI := Color("4a5590")
var TREE_SH := Color("171b36")
var ORANGE := Color("f29a2e")
var GOLD := Color("ffd27a")
var RED := Color("c03a28")
var TEXT := Color("ecdfc8")
var MUTED := Color("9a8a9a")
var LINK_OFF := Color("4a2a2e")
var PANEL := Color("140c1c")
var CROWN_COL := Color("ffcf4a")
var FRAMES := {
	"lit": [Color("f29a2e"), Color("2a1626"), Color("7a2a20")],
	"equip": [Color("ffe08a"), Color("3a1c22"), Color("f29a2e")],
	"avail": [Color("ff5a3a"), Color("2a1626"), Color("c03a28")],
	"dim": [Color("5a3a34"), Color("1c1426"), Color("33222a")],
}

var game
var font: Font
var page := "grimoire"
var go_label := "LET HIM COME"
var nodes: Array = []
var rows: Array = []
var focus := -1
var go_hot := false
var go_rect := Rect2()
var tab_rects: Array = []
var t := 0.0
var shakes := {}
var sparks: Array = []
var done := false
var lock_focus := false  # set by previews so stray mouse events don't clear the tooltip

var rite := ""  # "", "spin", "reveal"
var rite_t := 0.0
var rite_speed := 1.5
var needle := 0.5
var reveal := {}
var auto_t := 0.8


func _ready() -> void:
	font = UiArt.pixel_font()
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _backdrop == null:
		_backdrop = _make_backdrop()
	_build_nodes()


# =============================================================================
# Layout
# =============================================================================

func set_page(p: String) -> void:
	page = p
	focus = -1
	_build_nodes()


func _build_nodes() -> void:
	nodes.clear()
	var n := GameState.loadout_size()
	for i in n:
		nodes.append({"kind": "slot", "id": "", "index": i, "pos": Vector2(TRUNK_X + (i - (n - 1) * 0.5) * 26, CROWN_Y), "size": 19})
	var kind := "skill"
	rows = _grimoire_rows()
	if page == "ascension":
		kind = "perk"
		rows = ASCENSION_ROWS
	elif page == "eternity":
		kind = "eternal"
		rows = ETERNITY_ROWS
	for row in rows:
		var ids: Array = row[3]
		for c in ids.size():
			nodes.append({"kind": kind, "id": ids[c], "pos": _row_pos(row, c), "size": NODE_SIZE})
		if row.size() > 4:
			nodes.append({"kind": "class", "id": row[4], "pos": _row_pos(row, ids.size()), "size": NODE_SIZE})
	nodes.append({"kind": "rite", "id": "rite", "pos": Vector2(TRUNK_X, ROOT_Y), "size": ROOT_SIZE})


func _grimoire_rows() -> Array:
	var out: Array = []
	for cr in CLASS_ROWS:
		var ids: Array[String] = GameState.class_skills(cr[2])
		ids.sort_custom(func(a, b): return GameState.SKILLS[a]["rarity"] < GameState.SKILLS[b]["rarity"])
		out.append([cr[0], cr[1], GameState.CLASSES[cr[2]]["name"], ids, cr[2]])
	return out


func _row_pos(row: Array, c: int) -> Vector2:
	var xs: Array = LEFT_X if row[0] == "L" else RIGHT_X
	return Vector2(xs[c], ROW_Y[row[1]])


func node_index(kind: String, id: String) -> int:
	for i in nodes.size():
		if nodes[i]["kind"] == kind and nodes[i]["id"] == id:
			return i
	return -1


func _origin() -> Vector2:
	return ((size - Vector2(W * S, H * S)) * 0.5).floor()


func _scr(p: Vector2) -> Vector2:
	return _origin() + p * S


func _art(screen: Vector2) -> Vector2:
	return (screen - _origin()) / S


func _node_at(screen: Vector2) -> int:
	var a := _art(screen)
	for i in nodes.size():
		var n: Dictionary = nodes[i]
		var d: Vector2 = a - n["pos"]
		if absf(d.x) + absf(d.y) <= n["size"] * 0.5 + 1.0:
			return i
	return -1


func _owned(n: Dictionary) -> bool:
	var id: String = n["id"]
	match n["kind"]:
		"skill":
			return GameState.owned.has(id)
		"perk":
			return GameState.perks.has(id)
		"eternal":
			return GameState.eternity_level(id) > 0
		"class":
			return GameState.class_unlocked(id)
	return true


func _node_state(n: Dictionary) -> String:
	var id: String = n["id"]
	match n["kind"]:
		"slot":
			return "equip" if n["index"] < GameState.loadout.size() else "dim"
		"skill":
			if not GameState.owned.has(id):
				return "dim"
			return "equip" if GameState.loadout.has(id) else "lit"
		"class":
			if GameState.active_class == id:
				return "equip"
			if GameState.class_unlocked(id):
				return "lit"
			return "avail" if GameState.crowns >= GameState.CLASSES[id]["cost"] else "dim"
		"perk":
			if GameState.perks.has(id):
				return "equip"
			if not GameState.perk_available(id):
				return "dim"
			return "avail" if GameState.dread >= GameState.PERKS[id]["cost"] else "lit"
		"eternal":
			var cost := GameState.eternity_cost(id)
			if cost < 0:
				return "equip"
			if GameState.crowns >= cost:
				return "avail"
			return "lit" if GameState.eternity_level(id) > 0 else "dim"
		"rite":
			return "avail" if GameState.can_pull() else "lit"
	return "lit"


func _icon_for(n: Dictionary) -> String:
	match n["kind"]:
		"slot":
			return GameState.loadout[n["index"]] if n["index"] < GameState.loadout.size() else ""
		"skill":
			return n["id"] if GameState.owned.has(n["id"]) else "locked"
		"perk", "eternal":
			return n["id"]
		"class":
			return GameState.CLASSES[n["id"]]["icon"]
	return "rite"


# =============================================================================
# Input
# =============================================================================

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		go_hot = go_rect.has_point(event.position)
		if rite == "" and not lock_focus:
			focus = _node_at(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if rite == "spin":
			_seal()
			return
		if rite == "reveal":
			_close_rite()
			return
		if go_rect.has_point(event.position):
			_go()
			return
		for i in tab_rects.size():
			if (tab_rects[i] as Rect2).has_point(event.position):
				set_page(PAGES[i])
				Sfx.play("click")
				return
		var i := _node_at(event.position)
		if i >= 0:
			focus = i
			_activate(i)


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not is_visible_in_tree() or key == null or not key.pressed or key.echo:
		return
	var handled := true
	match key.keycode:
		KEY_SPACE:
			if rite == "spin":
				_seal()
			elif rite == "reveal":
				if GameState.can_pull():
					_open_rite()
				else:
					_close_rite()
			elif focus >= 0:
				_activate(focus)
			else:
				focus = _default_focus()
		KEY_ENTER, KEY_KP_ENTER:
			if rite == "":
				_go()
		KEY_ESCAPE:
			if rite != "":
				_close_rite()
		KEY_Q:
			_cycle_page(-1)
		KEY_E, KEY_TAB:
			_cycle_page(1)
		KEY_LEFT, KEY_A:
			_move_focus(Vector2.LEFT)
		KEY_RIGHT, KEY_D:
			_move_focus(Vector2.RIGHT)
		KEY_UP, KEY_W:
			_move_focus(Vector2.UP)
		KEY_DOWN, KEY_S:
			_move_focus(Vector2.DOWN)
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _cycle_page(step: int) -> void:
	if rite != "":
		return
	set_page(PAGES[posmod(PAGES.find(page) + step, PAGES.size())])
	Sfx.play("click")


func _default_focus() -> int:
	for i in nodes.size():
		if nodes[i]["kind"] in ["skill", "perk", "eternal"]:
			return i
	return 0


func _move_focus(dir: Vector2) -> void:
	if rite != "":
		return
	if focus < 0:
		focus = _default_focus()
		return
	var from: Vector2 = nodes[focus]["pos"]
	var best := -1
	var best_score := INF
	for i in nodes.size():
		if i == focus:
			continue
		var d: Vector2 = nodes[i]["pos"] - from
		var along := d.dot(dir)
		if along <= 0.5:
			continue
		var score := along + absf(d.dot(Vector2(-dir.y, dir.x))) * 2.5
		if score < best_score:
			best_score = score
			best = i
	if best >= 0:
		focus = best


func _activate(i: int) -> void:
	var n: Dictionary = nodes[i]
	var id: String = n["id"]
	match n["kind"]:
		"slot":
			if n["index"] < GameState.loadout.size() and GameState.loadout.size() > 1:
				GameState.toggle_loadout(GameState.loadout[n["index"]])
				_burst(n["pos"], ORANGE, 10)
				Sfx.play("click")
			else:
				_deny(i)
		"skill":
			if not GameState.owned.has(id):
				_deny(i)
				return
			var before := GameState.loadout.has(id)
			GameState.toggle_loadout(id)
			if GameState.loadout.has(id) != before:
				_burst(n["pos"], GOLD, 14)
				Sfx.play("click")
			else:
				_deny(i)
		"class":
			if GameState.class_unlocked(id):
				GameState.set_active_class(id)
				_burst(n["pos"], GOLD, 20)
				Sfx.play("levelup", -6.0)
			elif GameState.unlock_class(id):
				GameState.set_active_class(id)
				_burst(n["pos"], CROWN_COL, 44)
				Sfx.play("crown", -2.0)
				if game:
					game.flash(CROWN_COL, 0.25)
			else:
				_deny(i)
		"perk":
			if GameState.buy_perk(id):
				_burst(n["pos"], Color("ff5a3a"), 28)
				Sfx.play("levelup", -4.0)
				if game:
					game.flash(ORANGE, 0.15)
			else:
				_deny(i)
		"eternal":
			if GameState.buy_eternity(id):
				_burst(n["pos"], CROWN_COL, 40)
				Sfx.play("crown", -2.0)
				_build_nodes()  # Fifth Finger adds a crown slot.
				if game:
					game.flash(CROWN_COL, 0.25)
			else:
				_deny(i)
		"rite":
			_open_rite()


func _deny(i: int) -> void:
	_shake(i)
	Sfx.play("deny", -6.0)


func _go() -> void:
	if done:
		return
	done = true
	Sfx.play("click")
	let_him_come.emit()


func _open_rite() -> void:
	if not GameState.can_pull():
		_deny(node_index("rite", "rite"))
		rite = ""
		return
	rite = "spin"
	rite_t = randf()
	rite_speed = randf_range(1.3, 1.9) * GameState.rite_speed_mult()
	Sfx.play("cast", -6.0, 0.6)


func _seal() -> void:
	var zones: Array = GameState.rite_zones()
	var off := absf(needle - 0.5)
	var rarity := 2 if off < zones[0] else (1 if off < zones[1] else 0)
	reveal = GameState.pull(rarity)
	reveal["t"] = 0.0
	rite = "reveal"
	Sfx.play("reveal" if rarity > 0 else "coin", 0.0, 1.0 + rarity * 0.1)
	if game:
		game.flash(GameState.RARITY_COLORS[rarity], 0.4)


func _close_rite() -> void:
	rite = ""
	reveal = {}


func _shake(i: int) -> void:
	if i >= 0:
		shakes[i] = 0.3


func _burst(art_pos: Vector2, col: Color, count: int) -> void:
	for k in count:
		var a := randf() * TAU
		var sp := randf_range(25.0, 70.0)
		sparks.append({"p": art_pos, "v": Vector2(cos(a), sin(a)) * sp, "life": randf_range(0.35, 0.8), "c": col})


# =============================================================================
# Per-frame
# =============================================================================

func _process(delta: float) -> void:
	t += delta
	for i in shakes.keys():
		shakes[i] -= delta
		if shakes[i] <= 0.0:
			shakes.erase(i)
	for i in range(sparks.size() - 1, -1, -1):
		var s: Dictionary = sparks[i]
		s["life"] -= delta
		if s["life"] <= 0.0:
			sparks.remove_at(i)
			continue
		s["v"] += Vector2(0, 90.0) * delta
		s["p"] += s["v"] * delta
	if rite == "spin":
		rite_t += delta * rite_speed
		needle = pingpong(rite_t, 1.0)
	elif rite == "reveal":
		reveal["t"] += delta
	if GameState.autoplay:
		_autoplay(delta)
	queue_redraw()


func _autoplay(delta: float) -> void:
	auto_t -= delta
	if auto_t > 0.0 or done:
		return
	auto_t = randf_range(0.3, 0.7)
	if rite == "spin":
		_seal()
		return
	if rite == "reveal":
		_close_rite()
		return
	# Spend Crowns first (cheapest upgrade), then Dread on rites, then perks, then continue.
	var cheapest := ""
	for id in GameState.ETERNITY:
		var c := GameState.eternity_cost(id)
		if c >= 0 and c <= GameState.crowns and (cheapest == "" or c < GameState.eternity_cost(cheapest)):
			cheapest = id
	for cid in GameState.CLASSES:
		if not GameState.class_unlocked(cid) and GameState.crowns >= GameState.CLASSES[cid]["cost"]:
			if page != "grimoire":
				set_page("grimoire")
			_activate(node_index("class", cid))
			return
	if cheapest != "":
		if page != "eternity":
			set_page("eternity")
		_activate(node_index("eternal", cheapest))
		return
	if GameState.can_pull():
		_open_rite()
		return
	for row in ASCENSION_ROWS:
		for id in row[3]:
			if GameState.perk_available(id) and GameState.dread >= GameState.PERKS[id]["cost"]:
				if page != "ascension":
					set_page("ascension")
				_activate(node_index("perk", id))
				return
	_go()


# =============================================================================
# Drawing
# =============================================================================

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	draw_texture_rect(_backdrop, Rect2(_origin(), Vector2(W, H) * S), false)
	_draw_links()
	for i in nodes.size():
		_draw_node(i, nodes[i])
	for s in sparks:
		var c: Color = s["c"]
		c.a = clampf(s["life"] * 2.0, 0.0, 1.0)
		draw_rect(Rect2(_scr((s["p"] as Vector2).floor()), Vector2(S, S)), c)
	_draw_header()
	if rite != "":
		_draw_rite()
	elif focus >= 0 and focus < nodes.size():
		_draw_tooltip(nodes[focus])


func _hline(x0: float, x1: float, y: float, col: Color) -> void:
	draw_rect(Rect2(_scr(Vector2(minf(x0, x1), y)), Vector2(absf(x1 - x0) + 1.0, 1.0) * S), col)


func _vline(x: float, y0: float, y1: float, col: Color) -> void:
	draw_rect(Rect2(_scr(Vector2(x, minf(y0, y1))), Vector2(1.0, absf(y1 - y0) + 1.0) * S), col)


func _dot(p: Vector2, col: Color) -> void:
	_hline(p.x - 1, p.x + 1, p.y, col)
	_vline(p.x, p.y - 1, p.y + 1, col)


func _draw_links() -> void:
	var n := GameState.loadout_size()
	_vline(TRUNK_X, CROWN_Y, ROOT_Y, ORANGE)
	_hline(TRUNK_X - (n - 1) * 13, TRUNK_X + (n - 1) * 13, CROWN_Y, ORANGE)
	var kind := "skill" if page == "grimoire" else ("perk" if page == "ascension" else "eternal")
	for row in rows:
		var ids: Array = row[3]
		if row.size() > 4:
			var ccol: Color = GameState.CLASSES[row[4]]["color"]
			var a0 := _row_pos(row, 0)
			var a1 := _row_pos(row, ids.size())
			var band := Rect2(_scr(Vector2(minf(a0.x, a1.x) - 13, a0.y - 12)), Vector2(absf(a1.x - a0.x) + 26, 24) * S)
			var on := GameState.class_unlocked(row[4])
			draw_rect(band, Color(ccol.r, ccol.g, ccol.b, 0.13 if on else 0.05))
			draw_rect(band, Color(ccol.r, ccol.g, ccol.b, 0.45 if on else 0.15), false, 2.0)
			_hline(_row_pos(row, ids.size() - 1).x, _row_pos(row, ids.size()).x, _row_pos(row, 0).y, ccol if on else LINK_OFF)
		var first := _row_pos(row, 0)
		var any := false
		for id in ids:
			any = any or _owned({"kind": kind, "id": id})
		_hline(first.x, TRUNK_X, first.y, ORANGE if any or kind != "skill" else LINK_OFF)
		for c in range(ids.size() - 1):
			var a := _owned({"kind": kind, "id": ids[c]})
			var b := _owned({"kind": kind, "id": ids[c + 1]})
			var lit := (a and b) if kind == "skill" else a
			_hline(_row_pos(row, c).x, _row_pos(row, c + 1).x, first.y, ORANGE if lit else LINK_OFF)
		_dot(Vector2(TRUNK_X, first.y), GOLD)


func _draw_node(i: int, n: Dictionary) -> void:
	var st := _node_state(n)
	var sz: int = n["size"]
	var p: Vector2 = n["pos"]
	if shakes.has(i):
		p.x += roundf(sin(shakes[i] * 70.0) * 2.0)
	var fr: Array = FRAMES[st]
	var hot := i == focus
	var pulse := 0.5 + 0.5 * sin(t * 6.0)
	if hot or st == "avail":
		var gs := sz + 6
		var glow := UiArt.diamond(gs, fr[0], fr[0], fr[0])
		var ga := (0.45 if hot else 0.18) * (0.6 + 0.4 * pulse)
		draw_texture_rect(glow, Rect2(_scr(p - Vector2(gs - 1, gs - 1) * 0.5), Vector2(gs, gs) * S), false, Color(1, 1, 1, ga))
	var tex := UiArt.diamond(sz, fr[0], fr[1], fr[2])
	draw_texture_rect(tex, Rect2(_scr(p - Vector2(sz - 1, sz - 1) * 0.5), Vector2(sz, sz) * S), false)
	var icon_id := _icon_for(n)
	if icon_id != "":
		var mod := Color(0.5, 0.42, 0.55) if st == "dim" else Color.WHITE
		draw_texture_rect(UiArt.icon(icon_id), Rect2(_scr(p - Vector2(6, 6)), Vector2(12, 12) * S), false, mod)

	match n["kind"]:
		"skill":
			if GameState.owned.has(n["id"]):
				# Bottom pips: how well the hero knows this skill. Top pips: its rank.
				var tr := GameState.tier(GameState.get_mastery(n["id"]))
				for k in 3:
					var col := Color("3a2228")
					if tr > k:
						col = RED if tr < 3 else RED.lerp(Color("ff8a6a"), pulse)
					draw_rect(Rect2(_scr(Vector2(p.x - 4 + k * 3, p.y + 12)), Vector2(2, 2) * S), col)
				_pips_top(p, GameState.rank(n["id"]) - 1, GOLD)
		"class":
			if GameState.active_class == n["id"]:
				draw_texture_rect(UiArt.icon("crown"), Rect2(_scr(Vector2(p.x - 4, p.y - 17)), Vector2(8, 8) * S * 0.75), false)
		"eternal":
			var costs: Array = GameState.ETERNITY[n["id"]]["costs"]
			var lv := GameState.eternity_level(n["id"])
			for k in costs.size():
				var col := CROWN_COL if k < lv else Color("3a2a22")
				draw_rect(Rect2(_scr(Vector2(p.x - (costs.size() - 1) * 1.5 + k * 3 - 1, p.y + 12)), Vector2(2, 2) * S), col)
		"rite":
			var label := "RITE · %d" % GameState.pull_cost()
			_text_c(Vector2(p.x, p.y + 16), label, 16, GOLD if GameState.can_pull() else MUTED)


func _pips_top(p: Vector2, count: int, col: Color) -> void:
	for k in count:
		draw_rect(Rect2(_scr(Vector2(p.x - (count - 1) * 1.5 + k * 3 - 1, p.y - 13)), Vector2(2, 2) * S), col)


func _draw_header() -> void:
	_text(Vector2(10, 5), "THE THRONE OF THOUGHT", 24, ORANGE)
	var deaths := GameState.attempt - 1
	var hero_title: String = GameState.hero_data()["title"]
	_text(Vector2(10, 16), "%s HAS FALLEN %d TIME%s." % [hero_title, deaths, "" if deaths == 1 else "S"], 16, MUTED)
	_text(Vector2(10, 23), "POISE NEXT TIME: %d%%" % int(GameState.hero_poise() * 100), 16, Color("c87060"))
	_text(Vector2(10, 30), "CLASS: %s" % GameState.CLASSES[GameState.active_class]["name"], 16, GOLD)

	# Currencies, top right: Dread (per hero) and Crowns (forever)
	var right := _scr(Vector2(W - 10, 3))
	_currency(right, "dread", "%d" % int(GameState.dread), "DREAD", Color("8fd8ff"))
	_currency(right + Vector2(0, 30), "crown", "%d" % GameState.crowns, "CROWNS", CROWN_COL)

	var label := "ENTER  %s ▶" % go_label
	var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var gsize := Vector2(lw + 48, 40)
	go_rect = Rect2(Vector2(right.x - gsize.x, _scr(Vector2(0, 24)).y), gsize)
	draw_style_box(UiArt.pill_box(Color("e0503a") if go_hot else RED), go_rect)
	_str(go_rect.position + Vector2(24, 12), label, 16, Color("fff0d0"))

	# Page tabs
	tab_rects.clear()
	var tw := 54.0
	var x0 := TRUNK_X - tw * 1.5
	for i in PAGES.size():
		var r := Rect2(_scr(Vector2(x0 + i * tw + 2, 60)), Vector2(tw - 4, 11) * S)
		tab_rects.append(r)
		var on: bool = PAGES[i] == page
		draw_style_box(UiArt.pill_box(Color("c03a28") if on else Color("3a2230")), r)
		var tl: String = PAGE_TITLES[i]
		var w := font.get_string_size(tl, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		_str(Vector2(roundf(r.get_center().x - w * 0.5), r.position.y + 10), tl, 16, Color("fff0d0") if on else MUTED)

	# Branch labels at the outer end of each row
	for row in rows:
		var lbl: String = row[2]
		if lbl == "":
			continue
		var ids: Array = row[3]
		var outer := _row_pos(row, ids.size() - 1 + (1 if row.size() > 4 else 0))
		var w := font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x / S
		var col := GOLD if row.size() > 4 and GameState.active_class == row[4] else MUTED
		if row[0] == "L" and outer.x - 13 - w >= 2:
			_text(Vector2(outer.x - 13 - w, outer.y - 2), lbl, 16, col)
		elif row[0] == "R" and outer.x + 13 + w <= W - 2:
			_text(Vector2(outer.x + 13, outer.y - 2), lbl, 16, col)
	if page == "eternity":
		_text_c(Vector2(TRUNK_X, 174), "PERMANENT · BOUGHT WITH CROWNS", 16, CROWN_COL)
	var lw2 := font.get_string_size("LOADOUT", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x / S
	_text(Vector2(TRUNK_X - GameState.loadout_size() * 13 - 6 - lw2, CROWN_Y - 3), "LOADOUT", 16, MUTED)
	_text_c(Vector2(TRUNK_X, 231), "Q/E PAGES · ARROWS MOVE · SPACE SELECT · ENTER CONTINUE", 16, MUTED)


func _currency(right_top: Vector2, icon_id: String, value: String, label: String, col: Color) -> void:
	var vw := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	_str(Vector2(right_top.x - vw, right_top.y + 2), value, 24, col)
	draw_texture_rect(UiArt.icon(icon_id), Rect2(Vector2(right_top.x - vw - 34, right_top.y), Vector2(30, 30)), false)
	var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	_str(Vector2(right_top.x - vw - 40 - lw, right_top.y + 8), label, 16, MUTED)


func _draw_tooltip(n: Dictionary) -> void:
	var lines := _tooltip_lines(n)
	if lines.is_empty():
		return
	var h := 26.0
	for l in lines:
		h += 30.0 if l["s"] == 24 else (14.0 if l.has("bar") else 20.0)
	var p: Vector2 = n["pos"]
	var half: float = n["size"] * 0.5 + 6.0
	var anchor := _scr(p)
	var x: float
	if n["kind"] == "slot":
		x = anchor.x - TIP_W * 0.5
	elif p.x <= TRUNK_X:
		x = anchor.x + half * S
	else:
		x = anchor.x - half * S - TIP_W
	var y := anchor.y - h * 0.5
	if n["kind"] == "slot":
		y = anchor.y + (half + 6) * S
	var o := _origin()
	y = clampf(y, o.y + 12, o.y + H * S - h - 12)
	x = clampf(x, o.x + 12, o.x + W * S - TIP_W - 12)
	draw_style_box(UiArt.frame_box(ORANGE, PANEL), Rect2(x, y, TIP_W, h))
	var cy := y + 14.0
	for l in lines:
		if l.has("bar"):
			draw_rect(Rect2(x + 22, cy, TIP_W - 44, 8), Color("2a1626"))
			draw_rect(Rect2(x + 22, cy, (TIP_W - 44) * l["bar"], 8), l["c"])
			cy += 14.0
			continue
		_str(Vector2(x + 22, cy), l["t"], l["s"], l["c"])
		cy += 30.0 if l["s"] == 24 else 20.0


func _tooltip_lines(n: Dictionary) -> Array:
	var out: Array = []
	var id: String = n["id"]
	match n["kind"]:
		"skill":
			var s: Dictionary = GameState.SKILLS[id]
			var rar: int = s["rarity"]
			if not GameState.class_unlocked(GameState.class_of(id)):
				out.append(_ln("SEALED", MUTED, 24))
				out.append(_ln("??? · %s" % GameState.RARITY_NAMES[rar], GameState.RARITY_COLORS[rar]))
				for w in _wrap("Unlock the %s class to summon this power." % GameState.CLASSES[GameState.class_of(id)]["name"]):
					out.append(_ln(w, TEXT))
				return out
			if not GameState.owned.has(id):
				out.append(_ln("SEALED", MUTED, 24))
				out.append(_ln("??? · %s · %s" % [s["school"], GameState.RARITY_NAMES[rar]], GameState.RARITY_COLORS[rar]))
				for w in _wrap("A power still in the dark. Perform the Rite of Summoning to call it."):
					out.append(_ln(w, TEXT))
				return out
			out.append(_ln(s["name"], GameState.RARITY_COLORS[rar], 24))
			out.append(_ln("%s · %s · RANK %d" % [s["school"], GameState.RARITY_NAMES[rar], GameState.rank(id)], MUTED))
			for w in _wrap(s["desc"]):
				out.append(_ln(w, TEXT))
			var m := GameState.get_mastery(id)
			var tr := GameState.tier(m)
			out.append(_ln("HE KNOWS IT: %s %d%%" % [GameState.TIER_NAMES[tr], int(m * 100)], GameState.TIER_COLORS[tr]))
			out.append({"bar": m, "c": GameState.TIER_COLORS[tr], "s": 16})
			var seen := int(GameState.fights_seen(id))
			var need := int(GameState.fights_to_master())
			out.append(_ln(("FACED IN %d OF %d FIGHTS TO MASTER" % [seen, need]) if seen < need else "FACED IN %d FIGHTS: HE HAS IT" % seen, MUTED))
			out.append(_ln("HE WILL %s IT" % s["counter"] if tr >= 2 else "HE CANNOT COUNTER IT YET", GameState.TIER_COLORS[tr] if tr >= 2 else Color("8ad08a")))
			out.append(_ln("CLICK: %s" % ("UNEQUIP" if GameState.loadout.has(id) else "EQUIP"), GOLD))
		"perk":
			var p: Dictionary = GameState.PERKS[id]
			var owned := GameState.perks.has(id)
			out.append(_ln(p["name"], GOLD if owned else TEXT, 24))
			for w in _wrap(GameState.perk_desc(id)):
				out.append(_ln(w, TEXT))
			out.append(_ln("LASTS UNTIL DAWN · 10% STRONGER EACH NIGHT", MUTED))
			if owned:
				out.append(_ln("✓ CLAIMED", Color("8ad08a")))
			elif not GameState.perk_available(id):
				out.append(_ln("REQUIRES %s" % GameState.PERKS[p["req"]]["name"], MUTED))
			else:
				var ok: bool = GameState.dread >= p["cost"]
				out.append(_ln("COST: %d DREAD" % p["cost"], GOLD if ok else Color("e05a4a")))
				if ok:
					out.append(_ln("CLICK: CLAIM", GOLD))
		"class":
			var c: Dictionary = GameState.CLASSES[id]
			var skills: Array[String] = GameState.class_skills(id)
			var have := 0
			for sid in skills:
				if GameState.owned.has(sid):
					have += 1
			out.append(_ln(c["name"], CROWN_COL if GameState.active_class == id else TEXT, 24))
			out.append(_ln("CLASS · %d / %d SKILLS SUMMONED" % [have, skills.size()], MUTED))
			for w in _wrap("PASSIVE (WHILE ACTIVE): " + c["passive"]):
				out.append(_ln(w, TEXT))
			if GameState.active_class == id:
				out.append(_ln("★ YOUR ACTIVE CLASS", GOLD))
			elif GameState.class_unlocked(id):
				out.append(_ln("CLICK: MAKE ACTIVE", GOLD))
			else:
				var ok: bool = GameState.crowns >= c["cost"]
				for w in _wrap("Unlocking adds its skills to the Rite of Summoning."):
					out.append(_ln(w, MUTED))
				out.append(_ln("COST: %d CROWNS" % c["cost"], CROWN_COL if ok else Color("e05a4a")))
				if ok:
					out.append(_ln("CLICK: UNLOCK", GOLD))
		"eternal":
			var e: Dictionary = GameState.ETERNITY[id]
			var lv := GameState.eternity_level(id)
			var mx: int = (e["costs"] as Array).size()
			out.append(_ln(e["name"], CROWN_COL, 24))
			for w in _wrap(e["desc"] + " per level."):
				out.append(_ln(w, TEXT))
			out.append(_ln("LEVEL %d / %d · PERMANENT" % [lv, mx], MUTED))
			var cost := GameState.eternity_cost(id)
			if cost < 0:
				out.append(_ln("✓ FULLY ASCENDED", Color("8ad08a")))
			else:
				var ok := GameState.crowns >= cost
				out.append(_ln("COST: %d CROWNS" % cost, CROWN_COL if ok else Color("e05a4a")))
				if ok:
					out.append(_ln("CLICK: ASCEND", GOLD))
		"slot":
			var i: int = n["index"]
			out.append(_ln("LOADOUT SLOT %d" % (i + 1), GOLD, 24))
			if i < GameState.loadout.size():
				out.append(_ln(GameState.SKILLS[GameState.loadout[i]]["name"], TEXT))
				out.append(_ln("CLICK: UNEQUIP", MUTED))
			else:
				for w in _wrap("Empty. Equip skills from the Grimoire page."):
					out.append(_ln(w, MUTED))
		"rite":
			out.append(_ln("RITE OF SUMMONING", GOLD, 24))
			for w in _wrap("Stop the needle in the GOLD for a legendary, the VIOLET for a rare. Duplicates reforge a skill: +1 rank, and he forgets two fights of it."):
				out.append(_ln(w, TEXT))
			var ok := GameState.can_pull()
			out.append(_ln("COST: %d DREAD" % GameState.pull_cost(), GOLD if ok else Color("e05a4a")))
	return out


func _ln(text: String, col: Color, fsize: int = 16) -> Dictionary:
	return {"t": text, "c": col, "s": fsize}


func _wrap(text: String) -> Array[String]:
	var max_chars := int((TIP_W - 44) / 12.0)
	var out: Array[String] = []
	var line := ""
	for word in text.split(" "):
		if line == "":
			line = word
		elif line.length() + 1 + word.length() <= max_chars:
			line += " " + word
		else:
			out.append(line)
			line = word
	if line != "":
		out.append(line)
	return out


func _draw_rite() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.0, 0.04, 0.72))
	var panel := Rect2(_scr(Vector2(98, 60)), Vector2(230, 120) * S)
	draw_style_box(UiArt.frame_box(ORANGE, PANEL), panel)
	_text_c(Vector2(TRUNK_X, 70), "RITE OF SUMMONING", 24, ORANGE)
	if rite == "spin":
		var zones: Array = GameState.rite_zones()
		_text_c(Vector2(TRUNK_X, 86), "SEAL THE NEEDLE IN THE DARK", 16, MUTED)
		var bx := 123.0
		var bw := 180.0
		var by := 102.0
		draw_rect(Rect2(_scr(Vector2(bx - 1, by - 1)), Vector2(bw + 2, 14) * S), Color("12060a"))
		draw_rect(Rect2(_scr(Vector2(bx, by)), Vector2(bw, 12) * S), Color("2a1f38"))
		draw_rect(Rect2(_scr(Vector2(bx + bw * (0.5 - zones[1]), by)), Vector2(bw * zones[1] * 2.0, 12) * S), Color("6a34a8"))
		draw_rect(Rect2(_scr(Vector2(bx + bw * (0.5 - zones[0]), by)), Vector2(bw * zones[0] * 2.0, 12) * S), Color("f2c040"))
		var nx := roundf(bx + needle * bw)
		draw_rect(Rect2(_scr(Vector2(nx - 1, by - 4)), Vector2(2, 20) * S), Color.WHITE)
		_text_c(Vector2(TRUNK_X, 124), "SPACE / CLICK: SEAL", 16, GOLD)
		_text_c(Vector2(TRUNK_X, 136), "GOLD = LEGENDARY   VIOLET = RARE", 16, MUTED)
		_text_c(Vector2(TRUNK_X, 160), "ESC: LEAVE THE RITE", 16, MUTED)
		return
	var rar: int = reveal.get("rarity", 0)
	var rc: Color = GameState.RARITY_COLORS[rar]
	var s: Dictionary = GameState.SKILLS[reveal.get("id", "fireball")]
	var c := _scr(Vector2(TRUNK_X, 106))
	var rt: float = reveal.get("t", 0.0)
	for k in 14:
		var a := rt * 0.7 + k * TAU / 14.0
		var ray_len := 150.0 * minf(1.0, rt * 3.0)
		draw_line(c, c + Vector2(cos(a), sin(a)) * ray_len, Color(rc.r, rc.g, rc.b, 0.18), 6.0)
	var dsz := 37
	draw_texture_rect(UiArt.diamond(dsz, rc, Color("2a1626"), rc.darkened(0.4)), Rect2(_scr(Vector2(TRUNK_X, 106) - Vector2(dsz - 1, dsz - 1) * 0.5), Vector2(dsz, dsz) * S), false)
	draw_texture_rect(UiArt.icon(reveal.get("id", "fireball")), Rect2(_scr(Vector2(TRUNK_X - 12, 94)), Vector2(24, 24) * S), false)
	_text_c(Vector2(TRUNK_X, 128), GameState.RARITY_NAMES[rar], 16, rc)
	_text_c(Vector2(TRUNK_X, 136), s["name"], 24, TEXT)
	var sub := "NEW POWER · ADDED TO YOUR GRIMOIRE"
	if reveal.get("dup", false):
		sub = "REFORGED TO RANK %d · HE FORGETS" % reveal.get("rank", 1)
	_text_c(Vector2(TRUNK_X, 148), sub, 16, GOLD)
	var again := "SPACE: AGAIN (%d)   " % GameState.pull_cost() if GameState.can_pull() else ""
	_text_c(Vector2(TRUNK_X, 164), again + "ESC/CLICK: RETURN", 16, MUTED)


# --- Text helpers (positions are the TOP-LEFT of the text) --------------------

func _str(screen_pos: Vector2, text: String, fsize: int, col: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	var px := fsize / 8.0
	var base := screen_pos + Vector2(0, 7.0 * px)
	draw_string(font, base + Vector2(px, px), text, align, width, fsize, Color(0, 0, 0, 0.75))
	draw_string(font, base, text, align, width, fsize, col)


func _text(art_pos: Vector2, text: String, fsize: int, col: Color) -> void:
	_str(_scr(art_pos), text, fsize, col)


func _text_c(art_center_top: Vector2, text: String, fsize: int, col: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	var p := _scr(art_center_top)
	_str(Vector2(roundf(p.x - w * 0.5), p.y), text, fsize, col)


# =============================================================================
# Backdrop: the tree itself, painted once into a 426x240 image
# =============================================================================

func _make_backdrop() -> ImageTexture:
	var img := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	img.fill(BG)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 110:
		img.set_pixel(rng.randi_range(0, W - 1), rng.randi_range(0, H - 1), BG.lightened(0.15))
	var canopy := Color("221d3e")
	for i in 44:
		_disc(img, rng.randi_range(34, W - 34), rng.randi_range(40, 172), rng.randi_range(5, 14), canopy)
	for e in [Vector2(118, 238), Vector2(308, 238), Vector2(165, 240), Vector2(261, 240), Vector2(78, 232), Vector2(348, 232)]:
		_branch(img, Vector2(TRUNK_X, 204), Vector2((TRUNK_X + e.x) * 0.5, 214), e, 4.0, 1.0)
	_branch(img, Vector2(TRUNK_X, 239), Vector2(TRUNK_X - 12, 150), Vector2(TRUNK_X, 36), 9.0, 3.0)
	for y in ROW_Y:
		_branch(img, Vector2(TRUNK_X, y + 15), Vector2(150, y + 18), Vector2(34, y - 10), 4.0, 1.0)
		_branch(img, Vector2(TRUNK_X, y + 15), Vector2(276, y + 18), Vector2(392, y - 10), 4.0, 1.0)
	_branch(img, Vector2(TRUNK_X, 72), Vector2(178, 62), Vector2(146, 36), 3.0, 1.0)
	_branch(img, Vector2(TRUNK_X, 72), Vector2(248, 62), Vector2(280, 36), 3.0, 1.0)
	_band(img, 31, 128, W - 128)
	_band(img, 222, 56, W - 56)
	return ImageTexture.create_from_image(img)


func _disc(img: Image, cx: float, cy: float, r: float, col: Color) -> void:
	for y in range(int(cy - r), int(cy + r) + 1):
		if y < 0 or y >= H:
			continue
		for x in range(int(cx - r), int(cx + r) + 1):
			if x < 0 or x >= W:
				continue
			if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r:
				img.set_pixel(x, y, col)


func _branch(img: Image, a: Vector2, c: Vector2, b: Vector2, r0: float, r1: float) -> void:
	var steps := maxi(8, int(a.distance_to(b) * 0.8))
	for layer in 3:
		for i in steps + 1:
			var s := float(i) / steps
			var p := a.lerp(c, s).lerp(c.lerp(b, s), s)
			var r := lerpf(r0, r1, s)
			if layer == 0:
				_disc(img, p.x + 1, p.y + 1, r, TREE_SH)
			elif layer == 1:
				_disc(img, p.x, p.y, r, TREE)
			elif r > 1.5:
				_disc(img, p.x - r * 0.45, p.y - 0.5, r * 0.3, TREE_HI)


## A red ornamental band: a rule line with alternating scrolls above and below, and a medallion.
func _band(img: Image, y: int, x0: int, x1: int) -> void:
	var red := Color("b8342a")
	var dark := Color("6a1c1a")
	for x in range(x0, x1 + 1):
		img.set_pixel(x, y, red)
		img.set_pixel(x, y + 1, dark)
	var scroll := ["..rrr..", ".r...r.", "r..r..r", "r.r.rr.", ".r....."]
	var x := x0 + 4
	var k := 0
	while x < x1 - 8:
		var flip := k % 2 == 1
		var above := k % 4 < 2
		for yy in scroll.size():
			var row: String = scroll[yy]
			for xx in row.length():
				if row[xx] != "r":
					continue
				var px := x + (row.length() - 1 - xx if flip else xx)
				var py := (y - 1 - (scroll.size() - 1 - yy)) if above else (y + 2 + (scroll.size() - 1 - yy))
				if px >= 0 and px < W and py >= 0 and py < H:
					img.set_pixel(px, py, red)
		x += 8
		k += 1
	var mx := (x0 + x1) / 2
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var d := absi(dx) + absi(dy)
			if d <= 4:
				img.set_pixel(mx + dx, y + dy, Color("f29a2e") if d >= 3 else (red if d >= 2 else Color("ffd27a")))
