extends Control
## The in-fight skill bar: diamond slots with pixel icons, a cooldown drain under each,
## the selected slot raised and gilded, the selected skill's name underneath, and your
## PARRY (right mouse) on the far right: gold while the guard is up, draining on cooldown.

const UiArt := preload("res://scripts/ui/ui_art.gd")
const S := 3
const SLOT_W := 80.0
const DIA := 21

var boss
var font: Font


func _ready() -> void:
	font = UiArt.pixel_font()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(6.4 * SLOT_W, 124)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if boss == null:
		return
	var n := GameState.loadout_size()
	var total := (n + 1.4) * SLOT_W
	var x0 := (size.x - total) * 0.5
	var half := DIA * S * 0.5
	for i in n:
		var cx := roundf(x0 + i * SLOT_W + SLOT_W * 0.5)
		var has := i < GameState.loadout.size()
		var id: String = GameState.loadout[i] if has else ""
		var sel: bool = has and i == boss.selected
		var cy := 54.0 - (6.0 if sel else 0.0)
		var left: float = boss.cooldown_left(id) if has else 0.0
		var ready := has and left <= 0.0
		var border := Color("ffe08a") if sel else (Color("f29a2e") if ready else Color("5a3a34"))
		var inner := Color("f29a2e") if sel else (Color("7a2a20") if ready else Color("33222a"))
		draw_texture_rect(UiArt.diamond(DIA, border, Color("2a1626"), inner), Rect2(cx - half, cy - half, DIA * S, DIA * S), false)
		_str(Vector2(cx - 30, cy - half - 20), str(i + 1), 16, Color("ffd27a") if sel else Color("9a8a9a"), 60)
		if not has:
			continue
		draw_texture_rect(UiArt.icon(id), Rect2(cx - 18, cy - 18, 36, 36), false, Color.WHITE if ready else Color(0.4, 0.35, 0.45))
		if not ready:
			_drain(cx, cy + half + 3, boss.cooldown_frac(id))
			_str(Vector2(cx - 30, cy - 7), "%.1f" % left, 16, Color.WHITE, 60)

	# Parry
	var px := roundf(x0 + (n + 0.9) * SLOT_W)
	var py := 54.0
	var up: bool = boss.is_parrying()
	var cd: float = boss.parry_cd
	var pready := cd <= 0.0
	var pb := Color("ffffff") if up else (Color("ffd27a") if pready else Color("5a3a34"))
	var pi := Color("ffd27a") if up else (Color("7a5a20") if pready else Color("33222a"))
	if up:
		var g := DIA + 6
		draw_texture_rect(UiArt.diamond(g, pb, pb, pb), Rect2(px - g * S * 0.5, py - g * S * 0.5, g * S, g * S), false, Color(1, 1, 1, 0.4))
	draw_texture_rect(UiArt.diamond(DIA, pb, Color("2a1626"), pi), Rect2(px - half, py - half, DIA * S, DIA * S), false)
	draw_texture_rect(UiArt.icon("parry"), Rect2(px - 18, py - 18, 36, 36), false, Color.WHITE if pready or up else Color(0.4, 0.35, 0.45))
	_str(Vector2(px - 40, py - half - 20), "RMB", 16, Color("ffd27a") if pready else Color("9a8a9a"), 80)
	if not pready and not up:
		_drain(px, py + half + 3, boss.parry_cd_frac())

	var sid: String = boss.selected_id()
	if sid != "":
		var col: Color = GameState.SKILLS[sid]["color"]
		_str(Vector2(x0, 104), GameState.skill_title(sid).to_upper(), 16, col, n * SLOT_W)


func _drain(cx: float, y: float, frac: float) -> void:
	draw_rect(Rect2(cx - 24, y, 48, 6), Color("1a0a10"))
	draw_rect(Rect2(cx - 24, y, 48.0 * (1.0 - frac), 6), Color("f29a2e"))


func _str(pos: Vector2, text: String, fsize: int, col: Color, width: float) -> void:
	var base := pos + Vector2(0, 7.0 * fsize / 8.0)
	draw_string(font, base + Vector2(2, 2), text, HORIZONTAL_ALIGNMENT_CENTER, width, fsize, Color(0, 0, 0, 0.75))
	draw_string(font, base, text, HORIZONTAL_ALIGNMENT_CENTER, width, fsize, col)
