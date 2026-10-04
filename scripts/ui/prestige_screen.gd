extends Control
## The prestige moment, played when a hero finally conquers you:
##   1. he ascends in a column of gold and dissolves into light
##   2. a giant crown slams down, then your stars pop in one by one
##   3. the Crown tally counts up line by line, coins fly into the total
##   4. the next, tougher hero's banner slides in with what he brings
## SPACE / click skips ahead, then continues. Emits `finished` at the end.

signal finished

const UiArt := preload("res://scripts/ui/ui_art.gd")
const S := 3
const W := 426
const H := 240
const T_CROWN := 1.6
const T_STARS := 2.1
const STAR_GAP := 0.35
const T_TALLY := 3.3
const ROW_GAP := 0.45
const ROLL_TIME := 1.0

const HERO_SHAPE := [
	"......##.........",
	".....####......#.",
	".....####.....##.",
	"......##.....##..",
	"...########.##...",
	"..###########....",
	"..##.####.##.....",
	"..##.####........",
	"..#..####........",
	".....####........",
	".....#..#........",
	".....#..#........",
	".....#..#........",
	"....##..##.......",
]

var font: Font
var t := 0.0
var hero_title := ""
var next: Dictionary = {}
var is_final := false
var stars := 0
var rows: Array = []
var total := 0
var shown_total := 0.0
var motes: Array = []
var coins: Array = []
var pinged := {}
var crown_landed := false
var done := false
var auto := false


func setup(p_hero_title: String, p_rows: Array, p_total: int, p_next: Dictionary, p_final: bool, p_stars: int) -> void:
	stars = p_stars
	hero_title = p_hero_title
	rows = p_rows
	total = p_total
	next = p_next
	is_final = p_final


func _ready() -> void:
	font = UiArt.pixel_font()
	mouse_filter = Control.MOUSE_FILTER_STOP
	auto = GameState.autoplay
	Sfx.play("levelup")


func _t_roll() -> float:
	return T_TALLY + rows.size() * ROW_GAP + 0.2


func _t_banner() -> float:
	return _t_roll() + ROLL_TIME + 0.4


func _t_end() -> float:
	return _t_banner() + 1.2


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		accept_event()
		_advance()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		_advance()


func _advance() -> void:
	if t < _t_end():
		t = _t_end()
		shown_total = total
		crown_landed = true
	elif not done:
		done = true
		Sfx.play("click")
		finished.emit()


func _process(delta: float) -> void:
	var before := t
	t += delta
	# Ascension motes rising out of the hero
	if t < T_CROWN + 0.6:
		for k in 3:
			motes.append({"p": Vector2(213 + randf_range(-10, 10), 150 - (t / T_CROWN) * 60 + randf_range(-20, 20)),
				"v": Vector2(randf_range(-6, 6), randf_range(-40, -20)), "life": randf_range(0.6, 1.2)})
	for i in range(motes.size() - 1, -1, -1):
		motes[i]["life"] -= delta
		motes[i]["p"] += motes[i]["v"] * delta
		if motes[i]["life"] <= 0.0:
			motes.remove_at(i)
	# Crown slam
	if before < T_CROWN + 0.35 and t >= T_CROWN + 0.35:
		crown_landed = true
		Sfx.play("crown")
	# Stars pop in, rising pitch for each one earned
	for k in 3:
		var ts := T_STARS + k * STAR_GAP
		if before < ts and t >= ts:
			if k < stars:
				Sfx.play("levelup", -4.0, 1.0 + k * 0.25)
			else:
				Sfx.play("deny", -10.0)
	# Tally rows, one coin ping each
	for r in rows.size():
		var tr := T_TALLY + r * ROW_GAP
		if before < tr and t >= tr:
			Sfx.play("coin", -2.0, 1.0 + r * 0.08)
	# Roll the total; coins fly from the rows into it
	var tr0 := _t_roll()
	if t >= tr0:
		var k := clampf((t - tr0) / ROLL_TIME, 0.0, 1.0)
		var target := total * k
		if int(target) > int(shown_total):
			if randf() < 0.6:
				coins.append({"p": Vector2(randf_range(150, 276), 132 + randf_range(0, rows.size() * 9)), "t": 0.0})
			if not pinged.has(int(target) / 3):
				pinged[int(target) / 3] = true
				Sfx.play("coin", -10.0, 1.4)
		shown_total = target
	for i in range(coins.size() - 1, -1, -1):
		coins[i]["t"] += delta * 2.5
		if coins[i]["t"] >= 1.0:
			coins.remove_at(i)
	if before < _t_banner() and t >= _t_banner():
		Sfx.play("reveal", -2.0)
	if auto and t > _t_end() + 0.8 and not done:
		_advance()
	queue_redraw()


# =============================================================================

func _origin() -> Vector2:
	return ((size - Vector2(W * S, H * S)) * 0.5).floor()


func _scr(p: Vector2) -> Vector2:
	return _origin() + p * S


func _str(pos: Vector2, text: String, fsize: int, col: Color) -> void:
	var px := fsize / 8.0
	var base := pos + Vector2(0, 7.0 * px)
	draw_string(font, base + Vector2(px, px), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(0, 0, 0, 0.8 * col.a))
	draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


func _text_c(art_y: float, text: String, fsize: int, col: Color, x_center: float = 213.0) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	var p := _scr(Vector2(x_center, art_y))
	_str(Vector2(roundf(p.x - w * 0.5), p.y), text, fsize, col)


func _draw() -> void:
	var gold := Color("ffcf4a")
	var shake := Vector2.ZERO
	var since_slam := t - (T_CROWN + 0.35)
	if since_slam > 0.0 and since_slam < 0.35:
		shake = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 10.0 * (1.0 - since_slam / 0.35)
	draw_set_transform(shake)
	draw_rect(Rect2(Vector2.ZERO, size), Color("0e0a1c"))

	# Rotating god-rays behind everything
	var c := _scr(Vector2(213, 92))
	var ray_a := clampf(t / 1.0, 0.0, 1.0)
	for k in 18:
		var a := t * 0.25 + k * TAU / 18.0
		draw_line(c, c + Vector2(cos(a), sin(a)) * 900.0, Color(1.0, 0.8, 0.3, 0.06 * ray_a), 28.0)

	# Opening flash
	if t < 0.6:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.95, 0.8, 1.0 - t / 0.6))

	# 1. The hero ascends
	if t < T_CROWN + 0.6:
		var rise := clampf(t / T_CROWN, 0.0, 1.0)
		var alpha := 1.0 - clampf((t - T_CROWN * 0.6) / (T_CROWN * 0.6), 0.0, 1.0)
		var top := Vector2(205, 128 - rise * 60.0)
		for y in HERO_SHAPE.size():
			var row: String = HERO_SHAPE[y]
			for x in row.length():
				if row[x] == "#":
					draw_rect(Rect2(_scr(top + Vector2(x, y)), Vector2(S, S)), Color(1.0, 0.92, 0.6, alpha))
		var title_chars := int(clampf(t / 0.9, 0.0, 1.0) * (hero_title + " HAS MOVED ON").length())
		_text_c(28, (hero_title + " HAS MOVED ON").substr(0, title_chars), 32, Color(1, 0.95, 0.85, alpha))
		_text_c(46, "HE BECOMES LEGEND", 16, Color(1, 0.85, 0.5, alpha * clampf(t - 0.6, 0.0, 1.0)))
	for m in motes:
		draw_rect(Rect2(_scr((m["p"] as Vector2).floor()), Vector2(S, S)), Color(1.0, 0.85, 0.4, clampf(m["life"], 0.0, 1.0)))

	# 2. The crown slams down
	if t >= T_CROWN:
		var k := clampf((t - T_CROWN) / 0.35, 0.0, 1.0)
		var y := lerpf(-40.0, 58.0, k * k)
		if crown_landed:
			y = 58.0 - absf(sin(minf(since_slam, 0.6) * 10.0)) * 4.0 * maxf(0.0, 1.0 - since_slam * 2.0)
		var cs := 5 * S
		draw_texture_rect(UiArt.icon("crown"), Rect2(_scr(Vector2(213, y)) - Vector2(6, 6) * cs, Vector2(12, 12) * cs), false)
		if crown_landed:
			_text_c(14, "YOU ENDURED", 32, gold)

	# Stars: earned ones slam in big and gold, missing ones stay as dim outlines
	for k in 3:
		var ts := T_STARS + k * STAR_GAP
		if t < ts:
			continue
		var pop := clampf((t - ts) / 0.18, 0.0, 1.0)
		var sz := (2.6 - 1.0 * pop) * 12.0 * S if k < stars else 12.0 * S
		var center := _scr(Vector2(173 + k * 40, 96))
		var col := Color.WHITE if k < stars else Color(0.25, 0.2, 0.3)
		draw_texture_rect(UiArt.icon("star"), Rect2(center - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), false, col)
	# 3. Tally
	if t >= T_TALLY:
		_text_c(112, "CROWNS EARNED", 16, Color("9a8a9a"))
		for r in rows.size():
			var appear := t - (T_TALLY + r * ROW_GAP)
			if appear < 0.0:
				continue
			var slide := (1.0 - clampf(appear / 0.2, 0.0, 1.0)) * 30.0
			var y := 121 + r * 9
			var a := clampf(appear / 0.2, 0.0, 1.0)
			_str(_scr(Vector2(130 + slide, y)), str(rows[r][0]), 16, Color(0.93, 0.88, 0.8, a))
			var amt := "+%d" % int(rows[r][1])
			var aw := font.get_string_size(amt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			_str(_scr(Vector2(296 + slide, y)) - Vector2(aw, 0), amt, 16, Color(gold.r, gold.g, gold.b, a))
		if t >= _t_roll():
			var ty := 123 + rows.size() * 9
			_text_c(ty, "%d" % int(shown_total), 40, gold)
			_text_c(ty + 16, "TOTAL: %d CROWNS" % (GameState.crowns + int(shown_total)), 16, Color("9a8a9a"))
	for coin in coins:
		var from: Vector2 = coin["p"]
		var to := Vector2(213, 123 + rows.size() * 9 + 6)
		var p := from.lerp(to, coin["t"]) - Vector2(0, sin(coin["t"] * PI) * 14.0)
		draw_texture_rect(UiArt.icon("crown"), Rect2(_scr(p) - Vector2(9, 9), Vector2(18, 18)), false)

	# 4. The next hero
	if t >= _t_banner():
		var k := clampf((t - _t_banner()) / 0.35, 0.0, 1.0)
		var slide := (1.0 - k * k) * 300.0
		var by := 199.0
		draw_rect(Rect2(_scr(Vector2(0 + slide, by - 4)), Vector2(W, 34) * S), Color(0.35, 0.06, 0.05, 0.85))
		draw_rect(Rect2(_scr(Vector2(0 + slide, by - 4)), Vector2(W, 1) * S), gold)
		draw_rect(Rect2(_scr(Vector2(0 + slide, by + 29)), Vector2(W, 1) * S), gold)
		if is_final:
			_text_c(by, "THE LAST OF YOUR PAST SELVES IS REMEMBERED", 24, Color("fff0d0"), 213 + slide)
			_text_c(by + 12, "ONE NIGHT LEFT. HE WILL NOT PLAY A GAME.", 16, gold, 213 + slide)
		else:
			_text_c(by, "A TOUGHER SOUL APPROACHES: %s" % next.get("title", ""), 24, Color("fff0d0"), 213 + slide)
			var cur: Dictionary = GameState.hero_data()
			var hp_x: float = next.get("hp", 1.0) / maxf(1.0, cur["hp"])
			var st_x: float = next.get("strike", 1.0) / maxf(1.0, cur["strike"])
			var chips := "VITALITY x%.1f · BLADE x%.1f" % [hp_x, st_x]
			for mv in next.get("moves", []):
				if not cur["moves"].has(mv):
					chips += " · NEW MOVE: %s" % {"lunge": "LUNGE", "bolt": "HOLY BOLT", "leap": "JUDGMENT LEAP"}.get(mv, mv)
			_text_c(by + 11, chips, 16, gold, 213 + slide)
			_text_c(by + 19, "HE DOES NOT KNOW YOU. YET. · ASCENSION RETURNS TO DUST BY DAWN", 16, Color("c8b0a0"), 213 + slide)
	if t >= _t_end():
		var blink := 0.6 + 0.4 * sin(t * 5.0)
		_text_c(232, "SPACE / CLICK: RECLAIM THE MEMORY ▶", 16, Color(1, 0.94, 0.8, blink))
	draw_set_transform(Vector2.ZERO)
