extends Control
## Hero progress bar: how many fights you have outlasted him this hero.
## Stars light up at 5 / 8 / 11 hero deaths (one star is needed to pass him);
## small diamonds mark the checkpoints every 3 fights.

const UiArt := preload("res://scripts/ui/ui_art.gd")

var font: Font


func _ready() -> void:
	font = UiArt.pixel_font()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(480, 46)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var goal: int = GameState.STAR_DEATHS[-1]
	var deaths := GameState.attempt - 1
	var w := size.x - 40.0
	var x0 := 20.0
	var y := 22.0
	draw_rect(Rect2(x0 - 2, y - 2, w + 4, 10), Color("12060a"))
	draw_rect(Rect2(x0, y, w, 6), Color("2a1626"))
	draw_rect(Rect2(x0, y, w * clampf(float(deaths) / goal, 0.0, 1.0), 6), Color("f29a2e"))
	# Checkpoints
	var cp := GameState.CHECKPOINT_EVERY
	var k := cp
	while k < goal:
		var cx := x0 + w * float(k) / goal
		var on := deaths >= k
		draw_rect(Rect2(cx - 3, y - 1, 6, 8), Color("ffd27a") if on else Color("5a3a34"))
		k += cp
	# Stars
	for i in GameState.STAR_DEATHS.size():
		var sd: int = GameState.STAR_DEATHS[i]
		var cx := x0 + w * float(sd) / goal
		var lit := deaths >= sd
		var s := 30.0 if lit else 24.0
		draw_texture_rect(UiArt.icon("star"), Rect2(cx - s * 0.5, y + 3 - s * 0.5, s, s), false, Color.WHITE if lit else Color(0.3, 0.25, 0.35))
	var stars := GameState.current_stars()
	var text := "%s   ·   CHECKPOINT %d" % ["★".repeat(stars) if stars > 0 else "NO STAR YET", GameState.checkpoint_attempt()]
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var pos := Vector2((size.x - tw) * 0.5, 44)
	draw_string(font, pos + Vector2(2, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0, 0, 0, 0.75))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ffd27a") if stars > 0 else Color("c87060"))
