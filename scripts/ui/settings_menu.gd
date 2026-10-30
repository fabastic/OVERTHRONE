extends Control
## SETTINGS: rebind every control (keys or mouse buttons), mouse sensitivity and invert, volume,
## fullscreen and pixel size. Opened from the pause menu (ESC). Works while the game is paused.
## Click a binding, then press the new key or mouse button. ESC cancels a rebind; BACK closes.

signal closed

const UiArt := preload("res://scripts/ui/ui_art.gd")
const GOLD := Color(0.95, 0.75, 0.4)
const TEXT := Color(0.88, 0.84, 0.78)
const DIM := Color(0.6, 0.56, 0.52)

var game
var tab := "controls"
var waiting := ""
var content: VBoxContainer
var tab_buttons := {}
var wait_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.0, 0.02, 0.9)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(880, 600)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)
	var title := _label("SETTINGS", 40, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 10)
	vb.add_child(tabs)
	for t in [["controls", "CONTROLS"], ["mouse", "MOUSE & SOUND"], ["video", "VIDEO"]]:
		var b := _button(t[1], _set_tab.bind(t[0]), 240)
		tabs.add_child(b)
		tab_buttons[t[0]] = b
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(840, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	scroll.add_child(content)
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 16)
	vb.add_child(bottom)
	bottom.add_child(_button("RESET DEFAULTS", _reset, 280))
	bottom.add_child(_button("BACK", _close, 200))
	_rebuild()
	Sfx.play("menu_open", -6.0)


func _label(text: String, size: int = 16, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", maxi(16, int(round(size / 8.0)) * 8))
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, cb: Callable, w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, 40)
	b.pressed.connect(cb)
	b.mouse_entered.connect(func(): Sfx.play("ui_hover", -14.0))
	return b


func _set_tab(t: String) -> void:
	tab = t
	waiting = ""
	Sfx.play("click", -6.0)
	_rebuild()


func _rebuild() -> void:
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()
	for k in tab_buttons:
		(tab_buttons[k] as Button).add_theme_stylebox_override("normal", UiArt.pill_box(Color("c8902a") if k == tab else Color("3a2230")))
	match tab:
		"controls":
			var section := ""
			for a in Settings.ACTIONS:
				if a[2] != section:
					section = a[2]
					var h := _label(section, 16, GOLD)
					content.add_child(h)
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 12)
				var l := _label("   " + str(a[1]), 16, TEXT)
				l.custom_minimum_size = Vector2(400, 0)
				row.add_child(l)
				var b := _button(Settings.bind_text(a[0]), _start_rebind.bind(a[0]), 380)
				if waiting == a[0]:
					b.text = "PRESS A KEY OR BUTTON..."
					b.add_theme_stylebox_override("normal", UiArt.pill_box(Color("e0503a")))
					wait_button = b
				row.add_child(b)
				content.add_child(row)
			content.add_child(_label("Click a binding, then press the new key or mouse button. ESC cancels.", 16, DIM))
		"mouse":
			content.add_child(_slider("MOUSE SENSITIVITY", Settings.sensitivity, 0.2, 3.0, 0.05,
				func(v): Settings.sensitivity = v, "%.2fx"))
			content.add_child(_check("INVERT MOUSE Y", Settings.invert_y, func(v): Settings.invert_y = v))
			content.add_child(_slider("MASTER VOLUME", Settings.master_volume, 0.0, 1.0, 0.05,
				func(v): Settings.master_volume = v, "%d%%", 100.0))
		"video":
			content.add_child(_check("FULLSCREEN", Settings.fullscreen, func(v): Settings.fullscreen = v))
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			var l := _label("PIXEL SIZE", 16, TEXT)
			l.custom_minimum_size = Vector2(400, 0)
			row.add_child(l)
			for px in [2, 3, 4]:
				var b := _button(["", "", "SHARP", "CLASSIC", "CHUNKY"][px], _set_pixel.bind(px), 120)
				if Settings.pixel_size == px:
					b.add_theme_stylebox_override("normal", UiArt.pill_box(Color("c8902a")))
				row.add_child(b)
			content.add_child(row)
			content.add_child(_check("SHOW THE TICK BEAT", Settings.show_beat, func(v): Settings.show_beat = v))


func _slider(text: String, value: float, lo: float, hi: float, step: float, setter: Callable, fmt: String, mul: float = 1.0) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := _label(text, 16, TEXT)
	l.custom_minimum_size = Vector2(400, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(260, 32)
	s.focus_mode = Control.FOCUS_NONE
	row.add_child(s)
	var vl := _label(fmt % (value * mul), 16, GOLD)
	row.add_child(vl)
	s.value_changed.connect(func(v):
		setter.call(v)
		vl.text = fmt % (v * mul)
		Settings.apply()
		Settings.save())
	return row


func _check(text: String, value: bool, setter: Callable) -> Control:
	var row := HBoxContainer.new()
	var l := _label(text, 16, TEXT)
	l.custom_minimum_size = Vector2(400, 0)
	row.add_child(l)
	var c := CheckButton.new()
	c.button_pressed = value
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(func(v):
		setter.call(v)
		Settings.apply()
		Settings.save()
		Sfx.play("click", -6.0))
	row.add_child(c)
	return row


func _set_pixel(px: int) -> void:
	Settings.pixel_size = px
	Settings.apply()
	Settings.save()
	Sfx.play("click", -6.0)
	_rebuild()


func _start_rebind(action: String) -> void:
	waiting = action
	Sfx.play("click", -6.0)
	_rebuild()


func _input(event: InputEvent) -> void:
	if waiting == "":
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_close()
		return
	var code := ""
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			waiting = ""
			get_viewport().set_input_as_handled()
			_rebuild()
			return
		code = Settings.code_for(event)
	elif event is InputEventMouseButton and event.pressed:
		# The click that opened the rebind already happened (buttons fire on release), so this
		# press is the player's choice, even if it is the left mouse button.
		code = Settings.code_for(event)
	if code == "":
		return
	get_viewport().set_input_as_handled()
	Settings.rebind(waiting, code)
	waiting = ""
	Sfx.play("coin", -6.0)
	_rebuild()


func _reset() -> void:
	Settings.defaults()
	Settings.apply()
	Settings.save()
	waiting = ""
	Sfx.play("deny", -6.0)
	_rebuild()


func _close() -> void:
	Sfx.play("menu_close", -6.0)
	closed.emit()
	queue_free()
