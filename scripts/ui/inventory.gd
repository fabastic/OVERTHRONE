extends Control
## INVENTORY (I by day): every blade you own. Pick one to see it turning in the light, with its
## damage, speed, reach and swing. EQUIP carries it; UPGRADE spends Crowns to raise it a level,
## which reshapes the model (I ETCHED, II AWAKENED, III ASCENDED) and adds +20% damage.

signal closed

const UiArt := preload("res://scripts/ui/ui_art.gd")
const Swords := preload("res://scripts/swords.gd")
const Dialogue := preload("res://scripts/dialogue.gd")
const GOLD := Color(0.95, 0.75, 0.4)
const TEXT := Color(0.88, 0.84, 0.78)
const DIM := Color(0.6, 0.56, 0.52)
const CROWN := Color(1.0, 0.81, 0.29)
const LEVEL_DESC := ["", "A glowing rune channel down the blade, a gem in the pommel.",
	"Burning edges, a winged guard, a ring of aether around the hilt.",
	"Shards of light orbit the blade; it breathes out motes."]

var ow
var focus := ""
var list: VBoxContainer
var stats: Label
var title: Label
var equip_btn: Button
var up_btn: Button
var crowns_label: Label
var vp: SubViewport
var pivot: Node3D
var model: Node3D
var t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	focus = GameState.weapon
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.0, 0.02, 0.88)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)
	var head := HBoxContainer.new()
	root.add_child(head)
	var tl := _label("YOUR BLADES", 40, GOLD)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tl)
	crowns_label = _label("", 24, CROWN)
	head.add_child(crowns_label)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	root.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(380, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	body.add_child(right)
	# The 3D preview: its own little world, a slow turn under a warm light
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(440, 250)
	svc.stretch = true
	svc.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	right.add_child(svc)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.msaa_3d = Viewport.MSAA_DISABLED
	svc.add_child(vp)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.05, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.45, 0.55)
	env.ambient_light_energy = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.25
	env.glow_hdr_threshold = 1.4
	we.environment = env
	vp.add_child(we)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 2.3)
	cam.fov = 40.0
	vp.add_child(cam)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 30, 0)
	key.light_energy = 1.4
	vp.add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-1.5, 1.0, -1.0)
	rim.light_color = Color(1.0, 0.7, 0.4)
	rim.light_energy = 2.0
	rim.omni_range = 5.0
	vp.add_child(rim)
	pivot = Node3D.new()
	vp.add_child(pivot)
	title = _label("", 24, TEXT)
	right.add_child(title)
	stats = _label("", 16, TEXT)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.custom_minimum_size = Vector2(440, 0)
	right.add_child(stats)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 10)
	right.add_child(btns)
	equip_btn = _button("EQUIP", _equip, 150)
	btns.add_child(equip_btn)
	up_btn = _button("UPGRADE", _upgrade, 280)
	btns.add_child(up_btn)
	var close := _button("CLOSE  (%s / ESC)" % Settings.key_name("inventory"), _close, 380)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(close)
	_refresh()
	Sfx.play("menu_open", -6.0)
	if GameState.autoplay:
		get_tree().create_timer(1.0).timeout.connect(_auto)


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


func _owned_sorted() -> Array:
	var ids: Array = GameState.weapons.keys()
	ids.sort_custom(func(a, b): return int(Dialogue.WEAPONS[a]["tier"]) < int(Dialogue.WEAPONS[b]["tier"]))
	return ids


func _refresh() -> void:
	crowns_label.text = "CROWNS %d" % GameState.crowns
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	for id in _owned_sorted():
		var W: Dictionary = Dialogue.WEAPONS[id]
		var lv := int(GameState.weapons[id])
		var stars := "★".repeat(lv) + "·".repeat(GameState.WEAPON_MAX_LEVEL - lv)
		var tag := "  [CARRIED]" if id == GameState.weapon else ""
		var b := _button("%s %s%s" % [str(W["name"]).to_upper(), stars, tag], _select.bind(id), 370)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var on: bool = id == focus
		b.add_theme_stylebox_override("normal", UiArt.pill_box(Color("c8902a") if on else (Color("6a3a2a") if id == GameState.weapon else Color("3a2230"))))
		list.add_child(b)
	var W2: Dictionary = Dialogue.WEAPONS[focus]
	var lv2 := int(GameState.weapons.get(focus, 0))
	var lname: String = Swords.LEVEL_NAMES[lv2]
	title.text = str(W2["name"]).to_upper() + ("  ·  " + lname if lname != "" else "")
	title.add_theme_color_override("font_color", (W2["color"] as Color).lightened(0.3))
	var dmg := float(W2["dmg"]) * (1.0 + 0.2 * lv2)
	var lines: Array[String] = []
	lines.append(str(W2["desc"]))
	lines.append("DAMAGE %d   ·   A SWING EVERY %d TICKS   ·   REACH %.1f" % [int(dmg), int(W2["ticks"]), float(W2["reach"])])
	lines.append("SWING: %s" % Swords.STYLE_NAMES.get(Swords.swing_style(focus), ""))
	lines.append("AT NIGHT: +%d%% TO YOUR SPELLS (TIER %d)" % [5 * (int(W2["tier"]) - 1), int(W2["tier"])])
	var cost := GameState.weapon_upgrade_cost(focus)
	if cost >= 0:
		lines.append("NEXT: %s · %s" % [Swords.LEVEL_NAMES[lv2 + 1], LEVEL_DESC[lv2 + 1]])
		up_btn.text = "UPGRADE · %d CROWNS" % cost
		up_btn.disabled = GameState.crowns < cost
	else:
		lines.append("FULLY ASCENDED")
		up_btn.text = "MAX LEVEL"
		up_btn.disabled = true
	stats.text = "\n".join(lines)
	equip_btn.disabled = focus == GameState.weapon
	equip_btn.text = "CARRIED" if focus == GameState.weapon else "EQUIP"
	_show_model()


func _show_model() -> void:
	if is_instance_valid(model):
		model.queue_free()
	model = Swords.build(focus, 1.5, int(GameState.weapons.get(focus, 0)))
	model.rotation = Vector3(0, PI / 2.0, 0)
	model.position = Vector3(0.72, 0, 0)
	model.scale = Vector3.ONE * 1.0
	pivot.add_child(model)


func _select(id: String) -> void:
	focus = id
	Sfx.play("click", -6.0)
	_refresh()


func _equip() -> void:
	GameState.equip_weapon(focus)
	Sfx.play("swing_light", -4.0)
	_refresh()


func _upgrade() -> void:
	if GameState.upgrade_weapon(focus):
		Sfx.play("crown", -2.0)
		Sfx.play("forge", -4.0)
		_refresh()
	else:
		Sfx.play("deny", -6.0)


func _process(delta: float) -> void:
	t += delta
	if pivot:
		# A slow sway, mostly side-on, tilted so the whole blade reads diagonally
		pivot.rotation = Vector3(0.2 + sin(t * 0.7) * 0.08, sin(t * 0.6) * 0.7, 0.55)
	if is_instance_valid(model):
		var orbit := model.get_node_or_null("Orbit")
		if orbit:
			orbit.rotation.z += delta * 3.0


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.is_action_pressed("inventory")):
		get_viewport().set_input_as_handled()
		_close()


func _auto() -> void:
	# Autoplay: upgrade the carried blade if affordable, then close.
	focus = GameState.weapon
	if GameState.weapon_upgrade_cost(focus) >= 0 and GameState.crowns >= GameState.weapon_upgrade_cost(focus):
		_upgrade()
	_close()


func _close() -> void:
	if is_queued_for_deletion():
		return
	Sfx.play("menu_close", -6.0)
	closed.emit()
	queue_free()
