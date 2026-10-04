extends Control
## A compass strip for the top of the day HUD: the cardinal points slide past as you turn, and
## markers (today's boss, the Lamplighter's errand, the Hollow Flagon at dusk) sit at their bearing
## with their distance underneath. The overworld fills `markers` each frame:
##   [{"pos": Vector3 (local), "color": Color, "label": String}, ...]

const UiArt := preload("res://scripts/ui/ui_art.gd")
const FOV := PI * 0.75   # how much of the circle the strip shows

var ow
var markers: Array = []
var font: Font


func _ready() -> void:
	font = UiArt.pixel_font()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(440, 44)


func _process(_delta: float) -> void:
	queue_redraw()


func _x_for(bearing: float, yaw: float) -> float:
	# bearing: angle from north (-z), clockwise. yaw: the walker's yaw (0 = facing north).
	var d := wrapf(bearing + yaw, -PI, PI)
	if absf(d) > FOV * 0.5:
		return INF
	return size.x * 0.5 + d / (FOV * 0.5) * size.x * 0.5


func _draw() -> void:
	if ow == null or ow.walker == null:
		return
	var w := size.x
	draw_rect(Rect2(0, 6, w, 20), Color(0.04, 0.02, 0.06, 0.72))
	draw_rect(Rect2(0, 6, w, 2), Color(0.55, 0.35, 0.2, 0.9))
	draw_rect(Rect2(0, 24, w, 2), Color(0.55, 0.35, 0.2, 0.9))
	var yaw: float = ow.walker.yaw
	var names := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	for k in 16:
		var b := TAU * k / 16.0
		var x := _x_for(b, yaw)
		if x == INF:
			continue
		if k % 2 == 0:
			var label: String = names[k / 2]
			var c := Color("ffd27a") if label.length() == 1 else Color(0.75, 0.68, 0.6)
			_str(Vector2(x - 20, 8), label, c, 40)
		else:
			draw_rect(Rect2(x - 1, 12, 2, 8), Color(0.6, 0.5, 0.45, 0.7))
	var p: Vector3 = ow.walker.position
	for m in markers:
		var to: Vector3 = m["pos"] - p
		var b2 := atan2(to.x, -to.z)
		var x2 := _x_for(b2, yaw)
		var col: Color = m["color"]
		if x2 == INF:
			# Off the strip: pin it to the edge it is nearest, as an arrow.
			var d := wrapf(b2 + yaw, -PI, PI)
			x2 = 6.0 if d < 0.0 else w - 6.0
			draw_colored_polygon(PackedVector2Array([Vector2(x2, 10), Vector2(x2 + (-6 if d < 0.0 else 6), 16), Vector2(x2, 22)]), col)
			continue
		var y := 16.0
		draw_colored_polygon(PackedVector2Array([Vector2(x2, y - 7), Vector2(x2 + 7, y), Vector2(x2, y + 7), Vector2(x2 - 7, y)]), Color(0, 0, 0, 0.8))
		draw_colored_polygon(PackedVector2Array([Vector2(x2, y - 5), Vector2(x2 + 5, y), Vector2(x2, y + 5), Vector2(x2 - 5, y)]), col)
		var dist := int(Vector2(to.x, to.z).length())
		_str(Vector2(x2 - 70, 28), "%s %dM" % [m["label"], dist], col, 140)
	# The centre notch: where you are looking.
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.5 - 5, 0), Vector2(w * 0.5 + 5, 0), Vector2(w * 0.5, 7)]), Color("ffe08a"))


func _str(pos: Vector2, text: String, col: Color, width: float) -> void:
	var base := pos + Vector2(0, 14)
	draw_string(font, base + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_CENTER, width, 16, Color(0, 0, 0, 0.8))
	draw_string(font, base, text, HORIZONTAL_ALIGNMENT_CENTER, width, 16, col)
