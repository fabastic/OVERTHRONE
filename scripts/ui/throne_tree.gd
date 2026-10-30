extends Control
## The Throne of Thought, drawn as a pixel-art Tree of Life, in three pages:
##   GRIMOIRE   seven CLASSES, one per curved bough: skills along the bough, the class emblem at its tip.
##              Click an emblem to unlock the class (Crowns) or make it your active class.
##   ASCENSION  six perk boughs bought with Dread (they reset at dawn, 10% stronger each night)
##   ETERNITY   permanent upgrades bought with Crowns
## The crown of the tree is your LOADOUT, in any order you like: pick a skill up (click, or drag it)
## and drop it on a slot, or press 1-5 over a skill to put it in that slot. Right-click unequips.
## The roots hold the SUMMONING CHEST (Dread): open it for a new power (see GameState.pull).
## Every skill reads at a glance: SEALED (dark), OWNED (framed in its rarity), EQUIPPED (a glowing
## ring and its slot number) and SELECTED (bouncing brackets). A legend sits bottom-left.
## Laid out on a fixed 426x240 art grid scaled 3x, so it fits any window.

signal let_him_come

const UiArt := preload("res://scripts/ui/ui_art.gd")
const ClassArt := preload("res://scripts/ui/class_art.gd")
const S := 3
const W := 426
const H := 240
const TRUNK_X := 213
const CROWN_Y := 57
const ROOT_Y := 206
const TAB_Y := 33
const PAGES := ["grimoire", "ascension", "eternity"]
const PAGE_TITLES := ["GRIMOIRE", "ASCENSION", "ETERNITY"]
const CLASS_ORDER_L := ["pyro", "bone", "rime", "war"]
const CLASS_ORDER_R := ["storm", "void", "blood"]

# [label, ids]
const ASCENSION_L := [["TYRANNY", ["vigor", "wrath", "presence", "colossal"]], ["CUNNING", ["haste", "unreadable", "fog", "misdirect"]],
	["MOTION", ["fleet", "afterimage", "phantom", "widedais"]]]
const ASCENSION_R := [["HUNGER", ["harvest", "generous", "fated", "bottomless"]], ["GUARD", ["talons", "scale", "riposte", "bastion"]],
	["SORCERY", ["overflow", "echo", "surge", "archmage"]]]
const ETERNITY_L := [["MIGHT", ["colossus", "might"]], ["GRUDGE", ["grudge"]], ["FATE", ["fate"]]]
const ETERNITY_R := [["MIND", ["unknowable"]], ["HAND", ["finger"]], ["REFLEX", ["reflex"]]]
const NODE_SIZE := 21
const ROOT_SIZE := 27
const TIP_W := 384

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
var LINK_OFF := Color("3a2a3a")
var PANEL := Color("140c1c")
var CROWN_COL := Color("ffcf4a")
var EQUIP_COL := Color("fff2b0")

var game
var font: Font
var page := "grimoire"
var go_label := "LET HIM COME"
var nodes: Array = []
var boughs: Array = []     # {side, ids, kind, label, cls, s, c, e, node_t}
var focus := -1
var go_hot := false
var go_rect := Rect2()
var tab_rects: Array = []
var t := 0.0
var shakes := {}
var sparks: Array = []
var done := false
var lock_focus := false
var held := ""             # a skill picked up, to be dropped on a loadout slot
var drag_from := -1
var mouse := Vector2.ZERO

var rite := ""             # "", "shake", "open", "reveal"  (the summoning chest)
var rite_t := 0.0
var reveal := {}
var auto_t := 0.8


func _ready() -> void:
	font = UiArt.pixel_font()
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _backdrop == null:
		_backdrop = _make_backdrop()
	_build_nodes()


# =============================================================================
# Layout: curved boughs off the trunk
# =============================================================================

func set_page(p: String) -> void:
	page = p
	focus = -1
	held = ""
	_build_nodes()


func _bough_curve(side: float, idx: int, count: int) -> Array:
	var span := 104.0
	var step := span / maxf(1.0, count - 1)
	var ys := 192.0 - idx * step if count > 1 else 150.0
	var s := Vector2(TRUNK_X + side * 5.0, ys)
	var c := Vector2(TRUNK_X + side * 96.0, ys + 3.0)
	var e := Vector2(TRUNK_X + side * 178.0, ys - 30.0)
	return [s, c, e]


static func _bez(a: Vector2, b: Vector2, c: Vector2, u: float) -> Vector2:
	return a.lerp(b, u).lerp(b.lerp(c, u), u)


func _build_nodes() -> void:
	nodes.clear()
	boughs.clear()
	var n := GameState.loadout_size()
	for i in n:
		nodes.append({"kind": "slot", "id": "", "index": i, "pos": Vector2(TRUNK_X + (i - (n - 1) * 0.5) * 27, CROWN_Y), "size": 19})
	var rows_l: Array = []
	var rows_r: Array = []
	var kind := "skill"
	match page:
		"grimoire":
			for cid in CLASS_ORDER_L:
				rows_l.append([GameState.CLASSES[cid]["name"], _class_ids(cid), cid])
			for cid in CLASS_ORDER_R:
				rows_r.append([GameState.CLASSES[cid]["name"], _class_ids(cid), cid])
		"ascension":
			kind = "perk"
			rows_l = ASCENSION_L
			rows_r = ASCENSION_R
		"eternity":
			kind = "eternal"
			rows_l = ETERNITY_L
			rows_r = ETERNITY_R
	for pair in [[-1.0, rows_l], [1.0, rows_r]]:
		var side: float = pair[0]
		var rows: Array = pair[1]
		for i in rows.size():
			var row: Array = rows[i]
			var curve := _bough_curve(side, i, rows.size())
			var ids: Array = row[1]
			var b := {"side": side, "ids": ids, "kind": kind, "label": row[0], "cls": row[2] if row.size() > 2 else "",
				"s": curve[0], "c": curve[1], "e": curve[2], "ts": []}
			var cnt := ids.size()
			for k in cnt:
				var u := 0.2 + 0.68 * (k + 0.5) / maxf(cnt, 4.0) if cnt < 6 else 0.17 + 0.71 * (k + 0.5) / cnt
				b["ts"].append(u)
				nodes.append({"kind": kind, "id": ids[k], "pos": _bez(curve[0], curve[1], curve[2], u).round(), "size": NODE_SIZE, "bough": boughs.size()})
			if b["cls"] != "":
				nodes.append({"kind": "class", "id": b["cls"], "pos": curve[2].round(), "size": 25, "bough": boughs.size()})
			boughs.append(b)
	nodes.append({"kind": "rite", "id": "rite", "pos": Vector2(TRUNK_X, ROOT_Y), "size": ROOT_SIZE})


func _class_ids(cid: String) -> Array:
	var ids: Array[String] = GameState.class_skills(cid)
	ids.sort_custom(func(a, b): return GameState.SKILLS[a]["rarity"] < GameState.SKILLS[b]["rarity"])
	return ids


func node_index(kind: String, id: String) -> int:
	for i in nodes.size():
		if nodes[i]["kind"] == kind and nodes[i]["id"] == id:
			return i
	return -1


func _slot_node(i: int) -> int:
	for k in nodes.size():
		if nodes[k]["kind"] == "slot" and nodes[k]["index"] == i:
			return k
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
		if absf(d.x) + absf(d.y) <= n["size"] * 0.5 + 1.5:
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


## sealed / owned / equipped (skills); for others: dim / lit / avail / equip
func _node_state(n: Dictionary) -> String:
	var id: String = n["id"]
	match n["kind"]:
		"slot":
			return "equip" if n["index"] < GameState.loadout.size() else "dim"
		"skill":
			if not GameState.owned.has(id):
				return "sealed"
			return "equipped" if GameState.loadout.has(id) else "owned"
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


# =============================================================================
# Input
# =============================================================================

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse = event.position
		go_hot = go_rect.has_point(event.position)
		if rite == "" and not lock_focus:
			var f := _node_at(event.position)
			if f != focus and f >= 0:
				Sfx.play("ui_hover", -16.0)
			focus = f
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		accept_event()
		if rite != "":
			return
		if held != "":
			held = ""
			Sfx.play("menu_close", -8.0)
			return
		var ri := _node_at(event.position)
		if ri >= 0:
			_unequip_node(ri)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if not event.pressed:
			# Drag and drop: release a dragged skill over a slot
			if drag_from >= 0 and held != "":
				var over := _node_at(event.position)
				if over >= 0 and over != drag_from and nodes[over]["kind"] == "slot":
					_drop(nodes[over]["index"])
			drag_from = -1
			return
		if rite == "shake" or rite == "open":
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
			if held != "":
				drag_from = i


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not is_visible_in_tree() or key == null or not key.pressed or key.echo:
		return
	var handled := true
	match key.keycode:
		KEY_SPACE:
			if rite == "reveal":
				if GameState.can_pull():
					_open_rite()
				else:
					_close_rite()
			elif rite == "":
				if focus >= 0:
					_activate(focus)
				else:
					focus = _default_focus()
		KEY_ENTER, KEY_KP_ENTER:
			if rite == "":
				_go()
		KEY_ESCAPE:
			if rite == "reveal":
				_close_rite()
			elif held != "":
				held = ""
			else:
				handled = false
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
			# Put the skill under the cursor (or the one in hand) into that slot.
			var slot := key.keycode - KEY_1
			var id := held
			if id == "" and focus >= 0 and nodes[focus]["kind"] == "skill":
				id = nodes[focus]["id"]
			if id != "" and GameState.owned.has(id) and slot < GameState.loadout_size():
				held = id
				_drop(slot)
			else:
				handled = false
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
		Sfx.play("ui_hover", -16.0)


## Drop the skill in hand into loadout slot `slot` (swapping if it was elsewhere).
func _drop(slot: int) -> void:
	if held == "":
		return
	GameState.place_in_slot(held, slot)
	var si := _slot_node(mini(slot, GameState.loadout.size() - 1))
	if si >= 0:
		_burst(nodes[si]["pos"], GOLD, 16)
	Sfx.play("coin", -6.0)
	held = ""


func _unequip_node(i: int) -> void:
	var n: Dictionary = nodes[i]
	var id := ""
	if n["kind"] == "slot" and n["index"] < GameState.loadout.size():
		id = GameState.loadout[n["index"]]
	elif n["kind"] == "skill" and GameState.loadout.has(n["id"]):
		id = n["id"]
	if id == "" or GameState.loadout.size() <= 1:
		_deny(i)
		return
	GameState.unequip(id)
	_burst(n["pos"], ORANGE, 10)
	Sfx.play("menu_close", -6.0)


func _activate(i: int) -> void:
	var n: Dictionary = nodes[i]
	var id: String = n["id"]
	match n["kind"]:
		"slot":
			if held != "":
				_drop(n["index"])
			elif n["index"] < GameState.loadout.size():
				held = GameState.loadout[n["index"]]  # pick it up to move it
				Sfx.play("click", -4.0)
			else:
				_deny(i)
		"skill":
			if not GameState.owned.has(id):
				_deny(i)
				return
			if held == id:
				held = ""
				return
			held = id
			Sfx.play("click", -4.0)
			_burst(n["pos"], GOLD, 8)
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
				_build_nodes()
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


# --- The summoning chest ------------------------------------------------------

func _open_rite() -> void:
	if not GameState.can_pull():
		_deny(node_index("rite", "rite"))
		rite = ""
		return
	held = ""
	var rarity := GameState.roll_rarity()
	reveal = GameState.pull(rarity)
	reveal["t"] = 0.0
	rite = "shake"
	rite_t = 0.0
	Sfx.play("chest_shake", -4.0)


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
	if rite != "":
		var before := rite_t
		rite_t += delta
		if rite == "shake":
			# Rattles get faster and the light through the seams warms toward the rarity.
			var beat := 0.32 - 0.18 * minf(1.0, rite_t / 1.3)
			if fmod(rite_t, beat) < fmod(before, beat):
				Sfx.play("chest_shake", -6.0, 1.0 + rite_t * 0.3)
			if rite_t >= 1.4:
				rite = "open"
				rite_t = 0.0
				var r: int = reveal.get("rarity", 0)
				Sfx.play("chest_legendary" if r == 2 else "chest_open", 0.0)
				if game:
					game.flash(GameState.RARITY_COLORS[r], 0.35 + 0.1 * r)
				_burst(Vector2(TRUNK_X, 112), GameState.RARITY_COLORS[r], 30 + 20 * r)
		elif rite == "open" and rite_t >= 0.55:
			rite = "reveal"
			rite_t = 0.0
			reveal["t"] = 0.0
		elif rite == "reveal":
			reveal["t"] = rite_t
	if GameState.autoplay:
		_autoplay(delta)
	queue_redraw()


func _autoplay(delta: float) -> void:
	auto_t -= delta
	if auto_t > 0.0 or done:
		return
	auto_t = randf_range(0.3, 0.7)
	if rite == "shake" or rite == "open":
		return
	if rite == "reveal":
		_close_rite()
		return
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
	for rows in [ASCENSION_L, ASCENSION_R]:
		for row in rows:
			for id in row[1]:
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
	_draw_boughs()
	_draw_loadout_links()
	for i in nodes.size():
		_draw_node(i, nodes[i])
	for s in sparks:
		var c: Color = s["c"]
		c.a = clampf(s["life"] * 2.0, 0.0, 1.0)
		draw_rect(Rect2(_scr((s["p"] as Vector2).floor()), Vector2(S, S)), c)
	_draw_header()
	_draw_legend()
	if held != "" and rite == "":
		# The skill in hand follows the cursor
		var hp := mouse - Vector2(18, 18)
		draw_texture_rect(UiArt.diamond(NODE_SIZE, EQUIP_COL, Color("2a1626"), ORANGE), Rect2(hp - Vector2(13, 13), Vector2(NODE_SIZE, NODE_SIZE) * S), false, Color(1, 1, 1, 0.85))
		draw_texture_rect(UiArt.icon(held), Rect2(hp + Vector2(0, 0), Vector2(36, 36)), false)
		_str(mouse + Vector2(26, 6), "DROP ON A SLOT · 1-5", 16, GOLD)
	if rite != "":
		_draw_rite()
	elif focus >= 0 and focus < nodes.size():
		_draw_tooltip(nodes[focus])


func _hline(x0: float, x1: float, y: float, col: Color) -> void:
	draw_rect(Rect2(_scr(Vector2(minf(x0, x1), y)), Vector2(absf(x1 - x0) + 1.0, 1.0) * S), col)


func _vline(x: float, y0: float, y1: float, col: Color) -> void:
	draw_rect(Rect2(_scr(Vector2(x, minf(y0, y1))), Vector2(1.0, absf(y1 - y0) + 1.0) * S), col)


## Each bough: a tapering curved branch; the stretch up to the last owned node glows.
func _draw_boughs() -> void:
	_vline(TRUNK_X, CROWN_Y, ROOT_Y, ORANGE)
	for b in boughs:
		var s: Vector2 = b["s"]
		var c: Vector2 = b["c"]
		var e: Vector2 = b["e"]
		var ccol := TREE_HI
		var unlocked := true
		if b["cls"] != "":
			ccol = (GameState.CLASSES[b["cls"]]["color"] as Color)
			unlocked = GameState.class_unlocked(b["cls"])
		var steps := 28
		var prev := _scr(s)
		for k in range(1, steps + 1):
			var u := float(k) / steps
			var p := _scr(_bez(s, c, e, u))
			var w := lerpf(7.0, 3.0, u) * S
			draw_line(prev + Vector2(S, S), p + Vector2(S, S), TREE_SH, w)
			draw_line(prev, p, TREE if unlocked else Color("231f3a"), w)
			prev = p
		# The lit stretch: from the trunk to the furthest owned node
		var lit_u := 0.0
		var ids: Array = b["ids"]
		for k in ids.size():
			if _owned({"kind": b["kind"], "id": ids[k]}):
				lit_u = b["ts"][k]
		if b["cls"] != "" and unlocked:
			lit_u = maxf(lit_u, 0.06)
		if lit_u > 0.0:
			prev = _scr(s)
			var col := ccol if b["cls"] != "" else ORANGE
			for k in range(1, steps + 1):
				var u := lit_u * float(k) / steps
				var p := _scr(_bez(s, c, e, u))
				draw_line(prev, p, col, 1.5 * S)
				prev = p
		if b["cls"] != "" and not unlocked:
			# A chain across a sealed class's bough
			var mid := _bez(s, c, e, 0.12)
			for k in 3:
				var cp := _scr(mid + Vector2(0, -4 + k * 4))
				draw_rect(Rect2(cp - Vector2(4, 3), Vector2(8, 6)), Color("6a6a74"), false, 2.0)


## Thin gold threads from each equipped skill up to its loadout slot.
func _draw_loadout_links() -> void:
	if page != "grimoire":
		return
	for li in GameState.loadout.size():
		var id: String = GameState.loadout[li]
		var ni := node_index("skill", id)
		var si := _slot_node(li)
		if ni < 0 or si < 0:
			continue
		var a := _scr(nodes[ni]["pos"])
		var b := _scr(nodes[si]["pos"] + Vector2(0, 10))
		var col := Color(EQUIP_COL.r, EQUIP_COL.g, EQUIP_COL.b, 0.18 + 0.1 * sin(t * 3.0 + li))
		draw_line(a, b, col, 2.0)


func _frame_for(n: Dictionary, st: String) -> Array:
	match st:
		"sealed":
			return [Color("3a2a34"), Color("140e1a"), Color("1e1624")]
		"owned", "equipped":
			var rar: int = GameState.SKILLS[n["id"]]["rarity"]
			var rc: Color = GameState.RARITY_COLORS[rar]
			return [rc, Color("2a1626"), rc.darkened(0.45)]
		"equip":
			return [Color("ffe08a"), Color("3a1c22"), Color("f29a2e")]
		"lit":
			return [Color("f29a2e"), Color("2a1626"), Color("7a2a20")]
		"avail":
			return [Color("ff5a3a"), Color("2a1626"), Color("c03a28")]
	return [Color("5a3a34"), Color("1c1426"), Color("33222a")]


func _draw_node(i: int, n: Dictionary) -> void:
	var st := _node_state(n)
	var sz: int = n["size"]
	var p: Vector2 = n["pos"]
	if shakes.has(i):
		p.x += roundf(sin(shakes[i] * 70.0) * 2.0)
	var hot := i == focus
	var pulse := 0.5 + 0.5 * sin(t * 5.0)
	if n["kind"] == "class":
		_draw_emblem(n, p, st, hot)
		return
	if hot:
		sz += 4
	var fr := _frame_for(n, st)
	# EQUIPPED: a bright breathing ring outside the frame
	if st == "equipped" or (n["kind"] == "slot" and held != ""):
		var gs := sz + 8
		var ring_col := EQUIP_COL if st == "equipped" else GOLD
		draw_texture_rect(UiArt.diamond(gs, ring_col, ring_col, ring_col), Rect2(_scr(p - Vector2(gs - 1, gs - 1) * 0.5), Vector2(gs, gs) * S), false, Color(1, 1, 1, 0.25 + 0.3 * pulse))
	elif st == "avail":
		var gs2 := sz + 6
		draw_texture_rect(UiArt.diamond(gs2, fr[0], fr[0], fr[0]), Rect2(_scr(p - Vector2(gs2 - 1, gs2 - 1) * 0.5), Vector2(gs2, gs2) * S), false, Color(1, 1, 1, 0.18 * (0.6 + 0.4 * pulse)))
	draw_texture_rect(UiArt.diamond(sz, fr[0], fr[1], fr[2]), Rect2(_scr(p - Vector2(sz - 1, sz - 1) * 0.5), Vector2(sz, sz) * S), false)
	var icon_id := ""
	var mod := Color.WHITE
	match n["kind"]:
		"slot":
			if n["index"] < GameState.loadout.size():
				icon_id = GameState.loadout[n["index"]]
		"skill":
			icon_id = n["id"]
			if st == "sealed":
				mod = Color(0.12, 0.1, 0.16, 0.9)   # a dark silhouette: sealed
		"perk", "eternal":
			icon_id = n["id"]
			if st == "dim":
				mod = Color(0.45, 0.4, 0.5)
		"rite":
			icon_id = "chest" if UiArt.has_icon("chest") else "rite"
	var isz := 12 + (2 if hot else 0)
	if icon_id != "":
		draw_texture_rect(UiArt.icon(icon_id), Rect2(_scr(p - Vector2(isz, isz) * 0.5), Vector2(isz, isz) * S), false, mod)
	if st == "sealed":
		_text_c(p + Vector2(0, -4), "?", 16, Color("6a5a6a"))
	match n["kind"]:
		"skill":
			if GameState.owned.has(n["id"]):
				var tr := GameState.tier(GameState.get_mastery(n["id"]))
				for k in 3:
					var col := Color("3a2228")
					if tr > k:
						col = RED if tr < 3 else RED.lerp(Color("ff8a6a"), pulse)
					draw_rect(Rect2(_scr(Vector2(p.x - 4 + k * 3, p.y + 12)), Vector2(2, 2) * S), col)
				_pips_top(p, GameState.rank(n["id"]) - 1, GOLD)
			if st == "equipped":
				# The slot number, in a little gold tab at the top-left
				var slot := GameState.loadout.find(n["id"]) + 1
				var tp := _scr(p + Vector2(-12, -12))
				draw_rect(Rect2(tp, Vector2(18, 18)), EQUIP_COL)
				draw_rect(Rect2(tp + Vector2(2, 2), Vector2(14, 14)), Color("2a1626"))
				_str(tp + Vector2(5, 2), str(slot), 16, EQUIP_COL)
		"slot":
			_text_c(p + Vector2(0, 11), str(n["index"] + 1), 16, GOLD if n["index"] < GameState.loadout.size() else MUTED)
			if n["index"] >= GameState.loadout.size():
				_text_c(p + Vector2(0, -3), "+", 16, MUTED)
		"eternal":
			var costs: Array = GameState.ETERNITY[n["id"]]["costs"]
			var lv := GameState.eternity_level(n["id"])
			for k in costs.size():
				var col2 := CROWN_COL if k < lv else Color("3a2a22")
				draw_rect(Rect2(_scr(Vector2(p.x - (costs.size() - 1) * 1.5 + k * 3 - 1, p.y + 12)), Vector2(2, 2) * S), col2)
		"rite":
			_text_c(Vector2(p.x, p.y + 15), "SUMMONING CHEST · %d" % GameState.pull_cost(), 16, GOLD if GameState.can_pull() else MUTED)
	if hot:
		_brackets(p, sz)


## SELECTED: four corner brackets that breathe in and out.
func _brackets(p: Vector2, sz: int) -> void:
	var r := sz * 0.5 + 3.0 + sin(t * 8.0) * 1.2
	var col := Color.WHITE
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var c := p + Vector2(sx * r, sy * r)
			_hline(c.x, c.x - sx * 4.0, c.y, col)
			_vline(c.x, c.y, c.y - sy * 4.0, col)


## A class: a round medallion with its pixel emblem, lit in the class colour when unlocked.
func _draw_emblem(n: Dictionary, p: Vector2, st: String, hot: bool) -> void:
	var cid: String = n["id"]
	var ccol: Color = GameState.CLASSES[cid]["color"]
	var unlocked := GameState.class_unlocked(cid)
	var active := GameState.active_class == cid
	var r := 12.0 + (1.5 if hot else 0.0)
	var c := _scr(p)
	if active:
		draw_circle(c, (r + 4.0 + sin(t * 4.0)) * S, Color(CROWN_COL.r, CROWN_COL.g, CROWN_COL.b, 0.25))
	draw_circle(c, (r + 1.0) * S, Color("0c0810"))
	draw_circle(c, r * S, (ccol if unlocked else Color("4a4250")))
	draw_circle(c, (r - 2.0) * S, Color("1a1226"))
	var mod := Color.WHITE if unlocked else Color(0.35, 0.32, 0.4)
	draw_texture_rect(ClassArt.emblem(cid), Rect2(c - Vector2(8, 8) * S * 0.95, Vector2(16, 16) * S * 0.95), false, mod)
	if active:
		draw_texture_rect(UiArt.icon("crown"), Rect2(c + Vector2(-12, -r * S - 22), Vector2(24, 24)), false)
	elif not unlocked:
		# The price sits on a dark tab across the bottom of the medallion
		var cost: int = GameState.CLASSES[cid]["cost"]
		draw_rect(Rect2(_scr(p + Vector2(-8, 4)), Vector2(16, 7) * S), Color(0.05, 0.03, 0.08, 0.9))
		_text_c(p + Vector2(0, 4), "%d" % cost, 16, CROWN_COL if st == "avail" else MUTED)
	if hot:
		_brackets(p, int(r * 2.0))


func _pips_top(p: Vector2, count: int, col: Color) -> void:
	for k in count:
		draw_rect(Rect2(_scr(Vector2(p.x - (count - 1) * 1.5 + k * 3 - 1, p.y - 13)), Vector2(2, 2) * S), col)


func _draw_header() -> void:
	_text(Vector2(10, 5), "THE THRONE OF THOUGHT", 24, ORANGE)
	var deaths := GameState.attempt - 1
	var hero_title: String = GameState.hero_data()["title"]
	_text(Vector2(10, 15), "%s HAS FALLEN %d TIME%s." % [hero_title, deaths, "" if deaths == 1 else "S"], 16, MUTED)
	_text(Vector2(10, 22), "CLASS: %s" % GameState.CLASSES[GameState.active_class]["name"], 16, GOLD)
	var right := _scr(Vector2(W - 10, 3))
	_currency(right, "dread", "%d" % int(GameState.dread), "DREAD", Color("8fd8ff"))
	_currency(right + Vector2(0, 30), "crown", "%d" % GameState.crowns, "CROWNS", CROWN_COL)
	var label := "ENTER  %s ▶" % go_label
	var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var gsize := Vector2(lw + 48, 40)
	go_rect = Rect2(Vector2(right.x - gsize.x, _scr(Vector2(0, 24)).y), gsize)
	draw_style_box(UiArt.pill_box(Color("e0503a") if go_hot else RED), go_rect)
	_str(go_rect.position + Vector2(24, 12), label, 16, Color("fff0d0"))
	tab_rects.clear()
	var tw := 58.0
	var x0 := TRUNK_X - tw * 1.5
	for i in PAGES.size():
		var r := Rect2(_scr(Vector2(x0 + i * tw + 2, TAB_Y)), Vector2(tw - 4, 11) * S)
		tab_rects.append(r)
		var on: bool = PAGES[i] == page
		draw_style_box(UiArt.pill_box(Color("c03a28") if on else Color("3a2230")), r)
		var tl: String = PAGE_TITLES[i]
		var w := font.get_string_size(tl, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		_str(Vector2(roundf(r.get_center().x - w * 0.5), r.position.y + 10), tl, 16, Color("fff0d0") if on else MUTED)
	# Bough labels beside each tip
	for b in boughs:
		var e: Vector2 = b["e"]
		var lbl: String = b["label"]
		var col := MUTED
		if b["cls"] != "":
			col = (GameState.CLASSES[b["cls"]]["color"] as Color) if GameState.class_unlocked(b["cls"]) else Color("6a5a6a")
			if GameState.active_class == b["cls"]:
				col = GOLD
		var w := font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x / S
		var off := 17.0 if b["cls"] != "" else 6.0
		var y := e.y - 19.0 if b["cls"] != "" else e.y - 9.0
		if b["side"] < 0.0:
			_text(Vector2(clampf(e.x - w * 0.5, 2.0, W - w - 2.0), y - 2.0), lbl, 16, col)
		else:
			_text(Vector2(clampf(e.x - w * 0.5, 2.0, W - w - 2.0), y - 2.0), lbl, 16, col)
	if page == "eternity":
		_text_c(Vector2(TRUNK_X, 180), "PERMANENT · BOUGHT WITH CROWNS", 16, CROWN_COL)
	elif page == "ascension":
		_text_c(Vector2(TRUNK_X, 180), "UNTIL DAWN · +%d%% TONIGHT" % int(round((GameState.asc_mult() - 1.0) * 100)), 16, Color("ff8a6a"))
	var lw2 := font.get_string_size("LOADOUT", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x / S
	_text(Vector2(TRUNK_X - GameState.loadout_size() * 13.5 - 8 - lw2, CROWN_Y - 3), "LOADOUT", 16, MUTED)
	_text_c(Vector2(TRUNK_X, 231), "Q/E PAGES · CLICK OR DRAG A SKILL ONTO A SLOT · 1-5 SLOT · RMB UNEQUIP · ENTER CONTINUE", 16, MUTED)


## Bottom-left: what each frame means.
func _draw_legend() -> void:
	if page != "grimoire":
		return
	var x := 8.0
	var y := 186.0
	var rows := [["sealed", "SEALED"], ["owned", "OWNED (RARITY FRAME)"], ["equipped", "EQUIPPED (# = SLOT)"], ["hot", "SELECTED"]]
	for k in rows.size():
		var p := Vector2(x + 5, y + k * 11)
		var key: String = rows[k][0]
		if key == "hot":
			draw_texture_rect(UiArt.diamond(9, Color("5a3a34"), Color("1c1426"), Color("33222a")), Rect2(_scr(p - Vector2(4, 4)), Vector2(9, 9) * S), false)
			_brackets(p, 9)
		else:
			var fr: Array
			if key == "sealed":
				fr = [Color("3a2a34"), Color("140e1a"), Color("1e1624")]
			else:
				fr = [GameState.RARITY_COLORS[1], Color("2a1626"), GameState.RARITY_COLORS[1].darkened(0.45)]
			if key == "equipped":
				draw_texture_rect(UiArt.diamond(13, EQUIP_COL, EQUIP_COL, EQUIP_COL), Rect2(_scr(p - Vector2(6, 6)), Vector2(13, 13) * S), false, Color(1, 1, 1, 0.45))
			draw_texture_rect(UiArt.diamond(9, fr[0], fr[1], fr[2]), Rect2(_scr(p - Vector2(4, 4)), Vector2(9, 9) * S), false)
		_text(Vector2(x + 14, y + k * 11 - 4), rows[k][1], 16, MUTED)


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
	var portrait: bool = n["kind"] == "class"
	var h := 26.0 + (100.0 if portrait else 0.0)
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
	if portrait:
		# The class portrait, big
		var cid: String = n["id"]
		var pr := Rect2(x + TIP_W * 0.5 - 48, cy, 96, 96)
		draw_rect(pr.grow(4), GameState.CLASSES[cid]["color"])
		draw_rect(pr, Color("1a1226"))
		draw_texture_rect(ClassArt.emblem(cid), pr, false)
		cy += 106.0
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
				for w in _wrap("A power still in the dark. Open the Summoning Chest at the roots to call it."):
					out.append(_ln(w, TEXT))
				return out
			out.append(_ln(GameState.skill_title(id), GameState.RARITY_COLORS[rar], 24))
			var eq := GameState.loadout.find(id)
			out.append(_ln(("EQUIPPED · SLOT %d" % (eq + 1)) if eq >= 0 else "OWNED · NOT EQUIPPED", EQUIP_COL if eq >= 0 else MUTED))
			out.append(_ln("%s · %s · RANK %d" % [s["school"], GameState.RARITY_NAMES[rar], GameState.rank(id)], MUTED))
			for w in _wrap(s["desc"]):
				out.append(_ln(w, TEXT))
			var m := GameState.get_mastery(id)
			var tr := GameState.tier(m)
			out.append(_ln("HE KNOWS IT: %s %d%%" % [GameState.TIER_NAMES[tr], int(m * 100)], GameState.TIER_COLORS[tr]))
			out.append({"bar": m, "c": GameState.TIER_COLORS[tr], "s": 16})
			out.append(_ln("HE WILL %s IT" % s["counter"] if tr >= 2 else "HE CANNOT COUNTER IT YET", GameState.TIER_COLORS[tr] if tr >= 2 else Color("8ad08a")))
			out.append(_ln("CLICK/DRAG: TO A SLOT · 1-5: SLOT · RMB: UNEQUIP", GOLD))
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
				out.append(_ln("COST: %d CROWNS" % c["cost"], CROWN_COL if ok else Color("e05a4a")))
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
				out.append(_ln("COST: %d CROWNS" % cost, CROWN_COL if GameState.crowns >= cost else Color("e05a4a")))
		"slot":
			var i: int = n["index"]
			out.append(_ln("LOADOUT SLOT %d" % (i + 1), GOLD, 24))
			if i < GameState.loadout.size():
				out.append(_ln(GameState.skill_title(GameState.loadout[i]), TEXT))
				out.append(_ln("CLICK: PICK UP TO MOVE · RMB: UNEQUIP", MUTED))
			else:
				for w in _wrap("Empty. Drag a skill here from the Grimoire, or hover one and press %d." % (i + 1)):
					out.append(_ln(w, MUTED))
		"rite":
			out.append(_ln("SUMMONING CHEST", GOLD, 24))
			for w in _wrap("Open it for a power you do not have yet: 62% COMMON, 30% RARE, 8% LEGENDARY. If that rarity has nothing left for you, you get one from another pool, raised in rank by the difference (a legendary chest gives a RANK II rare or a RANK III common). Owning everything, it reforges your weakest skill."):
				out.append(_ln(w, TEXT))
			out.append(_ln("COST: %d DREAD" % GameState.pull_cost(), GOLD if GameState.can_pull() else Color("e05a4a")))
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


## The summoning chest: it rattles, light leaks through the seams (warming toward a rare or
## legendary colour), the lid bursts open, and the power rises out of it.
func _draw_rite() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.0, 0.04, 0.78))
	var r: int = reveal.get("rarity", 0)
	var rc: Color = GameState.RARITY_COLORS[r]
	var cx := float(TRUNK_X)
	var cy := 128.0
	_text_c(Vector2(cx, 58), "SUMMONING CHEST", 24, ORANGE)
	var leak := Color(1, 1, 1)
	var shake := 0.0
	var lid_up := 0.0
	if rite == "shake":
		var k := minf(1.0, rite_t / 1.4)
		shake = sin(rite_t * (30.0 + 40.0 * k)) * (1.0 + 2.5 * k)
		if r >= 1 and rite_t > 0.6:
			leak = GameState.RARITY_COLORS[1]
		if r >= 2 and rite_t > 1.0:
			leak = GameState.RARITY_COLORS[2]
		leak.a = 0.4 + 0.6 * k
	elif rite == "open":
		lid_up = minf(1.0, rite_t / 0.3)
		leak = rc
	else:
		lid_up = 1.0
		leak = rc
	# Rays once it is open
	if rite != "shake":
		var c := _scr(Vector2(cx, cy - 10))
		for k in 16:
			var a := t * 0.6 + k * TAU / 16.0
			draw_line(c, c + Vector2(cos(a), sin(a)) * 220.0, Color(rc.r, rc.g, rc.b, 0.16), 8.0)
	var bx := cx - 22 + shake
	# Body
	var wood := Color("6a3e1e")
	var band := Color("c8962a") if r < 2 else Color("ffd27a")
	draw_rect(Rect2(_scr(Vector2(bx, cy - 6)), Vector2(44, 24) * S), Color("2a160a"))
	draw_rect(Rect2(_scr(Vector2(bx + 1, cy - 5)), Vector2(42, 22) * S), wood)
	for k in 3:
		draw_rect(Rect2(_scr(Vector2(bx + 1, cy - 1 + k * 7)), Vector2(42, 1) * S), wood.darkened(0.3))
	for xx in [bx + 3, bx + 38]:
		draw_rect(Rect2(_scr(Vector2(xx, cy - 5)), Vector2(3, 22) * S), band)
	# Light from the seam
	draw_rect(Rect2(_scr(Vector2(bx + 1, cy - 7)), Vector2(42, 2) * S), leak)
	# Lid (lifts and tilts back)
	var ly := cy - 16 - lid_up * 14.0
	var lid := Rect2(_scr(Vector2(bx, ly)), Vector2(44, 10) * S)
	draw_rect(lid, Color("2a160a"))
	draw_rect(lid.grow(-S), wood.lightened(0.08))
	for xx in [bx + 3, bx + 38]:
		draw_rect(Rect2(_scr(Vector2(xx, ly + 1)), Vector2(3, 8) * S), band)
	draw_rect(Rect2(_scr(Vector2(bx + 19, ly + 6)), Vector2(6, 6) * S), band)  # the lock
	if rite == "shake":
		_text_c(Vector2(cx, cy + 26), "...", 24, MUTED)
		return
	# The power rises out of the chest
	var rt: float = reveal.get("t", 0.0) if rite == "reveal" else 0.0
	var rise := minf(1.0, rt / 0.35)
	var ip := Vector2(cx, cy - 18 - 22 * rise)
	var dsz := 31
	draw_texture_rect(UiArt.diamond(dsz, rc, Color("2a1626"), rc.darkened(0.4)), Rect2(_scr(ip - Vector2(dsz - 1, dsz - 1) * 0.5), Vector2(dsz, dsz) * S), false)
	draw_texture_rect(UiArt.icon(reveal.get("id", "fireball")), Rect2(_scr(ip - Vector2(10, 10)), Vector2(20, 20) * S), false)
	if rite != "reveal":
		return
	var s: Dictionary = GameState.SKILLS[reveal.get("id", "fireball")]
	var ir: int = reveal.get("item_rarity", r)
	_text_c(Vector2(cx, cy + 22), "%s CHEST" % GameState.RARITY_NAMES[r], 16, rc)
	_text_c(Vector2(cx, cy + 30), "%s %s" % [str(s["name"]).to_upper(), GameState.roman(reveal.get("rank", 1))], 24, GameState.RARITY_COLORS[ir])
	var sub := "NEW POWER · RANK %s" % GameState.roman(reveal.get("rank", 1))
	if reveal.get("maxed", false):
		sub = "EVERY POWER IS MASTERED · +%d CROWNS" % (5 + 5 * r)
	elif reveal.get("dup", false):
		sub = "REFORGED TO RANK %s · HE FORGETS" % GameState.roman(reveal.get("rank", 1))
	elif ir != r:
		sub = "THE %s POOL RAN DRY: A %s, RANK %s" % [GameState.RARITY_NAMES[r], GameState.RARITY_NAMES[ir], GameState.roman(reveal.get("rank", 1))]
	_text_c(Vector2(cx, cy + 42), sub, 16, GOLD)
	var again := "SPACE: OPEN ANOTHER (%d)   " % GameState.pull_cost() if GameState.can_pull() else ""
	_text_c(Vector2(cx, cy + 56), again + "ESC/CLICK: RETURN", 16, MUTED)


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
# Backdrop: the trunk, canopy and roots, painted once into a 426x240 image
# =============================================================================

func _make_backdrop() -> ImageTexture:
	var img := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	img.fill(BG)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 140:
		img.set_pixel(rng.randi_range(0, W - 1), rng.randi_range(0, H - 1), BG.lightened(0.15))
	var canopy := Color("221d3e")
	for i in 60:
		_disc(img, rng.randi_range(20, W - 20), rng.randi_range(46, 178), rng.randi_range(6, 16), canopy)
	for e in [Vector2(118, 238), Vector2(308, 238), Vector2(165, 240), Vector2(261, 240), Vector2(78, 232), Vector2(348, 232)]:
		_branch(img, Vector2(TRUNK_X, 212), Vector2((TRUNK_X + e.x) * 0.5, 220), e, 4.0, 1.0)
	_branch(img, Vector2(TRUNK_X, 239), Vector2(TRUNK_X - 10, 150), Vector2(TRUNK_X, 50), 10.0, 3.0)
	_band(img, 28, 150, W - 150)
	_band(img, 224, 56, W - 56)
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


func _band(img: Image, y: int, x0: int, x1: int) -> void:
	var red := Color("b8342a")
	var dark := Color("6a1c1a")
	for x in range(x0, x1 + 1):
		img.set_pixel(x, y, red)
		img.set_pixel(x, y + 1, dark)
	var mx := (x0 + x1) / 2
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var d := absi(dx) + absi(dy)
			if d <= 3:
				img.set_pixel(mx + dx, y + dy, Color("f29a2e") if d >= 2 else Color("ffd27a"))
