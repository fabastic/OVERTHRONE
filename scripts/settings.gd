extends Node
## Player settings (autoload "Settings"): rebindable controls, mouse, audio and video.
## Saved to user://settings.cfg. Every control in the game is an InputMap action defined here,
## so the settings menu (ui/settings_menu.gd) can rebind any of them to a key or a mouse button.

signal changed

const PATH := "user://settings.cfg"

# [action, label, section, default events]. Events: "K:<keycode>" or "M:<mouse button index>".
const ACTIONS := [
	["move_forward", "MOVE FORWARD", "MOVEMENT", ["K:%d" % KEY_W, "K:%d" % KEY_UP]],
	["move_back", "MOVE BACK", "MOVEMENT", ["K:%d" % KEY_S, "K:%d" % KEY_DOWN]],
	["move_left", "MOVE / LEAN LEFT", "MOVEMENT", ["K:%d" % KEY_A, "K:%d" % KEY_LEFT]],
	["move_right", "MOVE / LEAN RIGHT", "MOVEMENT", ["K:%d" % KEY_D, "K:%d" % KEY_RIGHT]],
	["jump", "JUMP / CLIMB", "MOVEMENT", ["K:%d" % KEY_SPACE]],
	["sprint", "SPRINT", "MOVEMENT", ["K:%d" % KEY_SHIFT]],
	["crouch", "CROUCH / SLIDE", "MOVEMENT", ["K:%d" % KEY_CTRL]],
	["dodge", "DODGE ROLL", "MOVEMENT", ["K:%d" % KEY_C]],
	["day_swing", "SWING BLADE", "IN THE CITY", ["M:%d" % MOUSE_BUTTON_LEFT]],
	["day_cast", "CAST SKILL", "IN THE CITY", ["K:%d" % KEY_Q]],
	["interact", "TALK / OPEN", "IN THE CITY", ["K:%d" % KEY_E]],
	["inventory", "INVENTORY", "IN THE CITY", ["K:%d" % KEY_I]],
	["map", "MAP", "IN THE CITY", ["K:%d" % KEY_M, "K:%d" % KEY_TAB]],
	["ping", "PING THE STORY MARKER", "IN THE CITY", ["K:%d" % KEY_G]],
	["fight_cast", "CAST SKILL", "IN THE FIGHT", ["M:%d" % MOUSE_BUTTON_LEFT]],
	["fight_swing", "SWING BLADE", "IN THE FIGHT", ["K:%d" % KEY_F]],
	["parry", "PARRY", "COMBAT", ["M:%d" % MOUSE_BUTTON_RIGHT]],
	["skill_1", "SKILL 1", "COMBAT", ["K:%d" % KEY_1]],
	["skill_2", "SKILL 2", "COMBAT", ["K:%d" % KEY_2]],
	["skill_3", "SKILL 3", "COMBAT", ["K:%d" % KEY_3]],
	["skill_4", "SKILL 4", "COMBAT", ["K:%d" % KEY_4]],
	["skill_5", "SKILL 5", "COMBAT", ["K:%d" % KEY_5]],
	["skill_prev", "PREVIOUS SKILL", "COMBAT", ["M:%d" % MOUSE_BUTTON_WHEEL_UP]],
	["skill_next", "NEXT SKILL", "COMBAT", ["M:%d" % MOUSE_BUTTON_WHEEL_DOWN]],
	["throne", "THRONE OF THOUGHT", "COMBAT", ["K:%d" % KEY_T]],
]

var sensitivity := 1.0     # multiplier on mouse look
var invert_y := false
var master_volume := 0.8   # 0..1
var fullscreen := false
var pixel_size := 3        # 2 = sharp, 4 = chunky
var show_beat := true
var binds := {}            # action -> Array[String] of event codes


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in ACTIONS:
		binds[a[0]] = (a[3] as Array).duplicate()
	_load()
	apply()


func defaults() -> void:
	for a in ACTIONS:
		binds[a[0]] = (a[3] as Array).duplicate()
	sensitivity = 1.0
	invert_y = false
	master_volume = 0.8
	fullscreen = false
	pixel_size = 3
	show_beat = true


## Push everything into the engine: InputMap, the master bus, the window.
func apply() -> void:
	for a in ACTIONS:
		var act: String = a[0]
		if not InputMap.has_action(act):
			InputMap.add_action(act, 0.2)
		InputMap.action_erase_events(act)
		for code in binds[act]:
			var ev := event_from(code)
			if ev:
				InputMap.action_add_event(act, ev)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_mute(0, master_volume <= 0.001)
	if DisplayServer.get_name() != "headless":
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want:
			DisplayServer.window_set_mode(want)
	changed.emit()


func event_from(code: String) -> InputEvent:
	var parts := code.split(":")
	if parts.size() != 2:
		return null
	if parts[0] == "K":
		var k := InputEventKey.new()
		k.physical_keycode = int(parts[1]) as Key
		return k
	var m := InputEventMouseButton.new()
	m.button_index = int(parts[1]) as MouseButton
	return m


## Turn a captured input event into a bind code (or "" if it cannot be bound).
func code_for(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var kc: Key = ev.physical_keycode if ev.physical_keycode != KEY_NONE else ev.keycode
		return "K:%d" % kc
	if ev is InputEventMouseButton:
		return "M:%d" % ev.button_index
	return ""


func label_for(code: String) -> String:
	var parts := code.split(":")
	if parts.size() != 2:
		return "?"
	if parts[0] == "K":
		return OS.get_keycode_string(int(parts[1]) as Key).to_upper()
	match int(parts[1]):
		MOUSE_BUTTON_LEFT: return "LMB"
		MOUSE_BUTTON_RIGHT: return "RMB"
		MOUSE_BUTTON_MIDDLE: return "MMB"
		MOUSE_BUTTON_WHEEL_UP: return "WHEEL UP"
		MOUSE_BUTTON_WHEEL_DOWN: return "WHEEL DOWN"
		MOUSE_BUTTON_XBUTTON1: return "MOUSE 4"
		MOUSE_BUTTON_XBUTTON2: return "MOUSE 5"
	return "MOUSE %s" % parts[1]


## The first binding of an action, for prompts ("E: TALK").
func key_name(action: String) -> String:
	var b: Array = binds.get(action, [])
	return label_for(b[0]) if not b.is_empty() else "--"


func bind_text(action: String) -> String:
	var out: Array[String] = []
	for c in binds.get(action, []):
		out.append(label_for(c))
	return " / ".join(out) if not out.is_empty() else "UNBOUND"


## Rebind: the new event becomes the primary binding. It is taken off any other action in the
## same context so one key never does two things at once.
func rebind(action: String, code: String) -> void:
	var sec := _section(action)
	for a in ACTIONS:
		if a[0] != action and _shares_context(sec, a[2]):
			(binds[a[0]] as Array).erase(code)
	var list: Array = binds[action]
	list.erase(code)
	list.insert(0, code)
	if list.size() > 2:
		list.resize(2)
	apply()
	save()


func _section(action: String) -> String:
	for a in ACTIONS:
		if a[0] == action:
			return a[2]
	return ""


## The city and the fight never run at once, so their keys may overlap.
func _shares_context(a: String, b: String) -> bool:
	if a == b:
		return true
	var city := ["IN THE CITY"]
	var fight := ["IN THE FIGHT"]
	if (a in city and b in fight) or (a in fight and b in city):
		return false
	return true


func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	sensitivity = cf.get_value("mouse", "sensitivity", sensitivity)
	invert_y = cf.get_value("mouse", "invert_y", invert_y)
	master_volume = cf.get_value("audio", "master", master_volume)
	fullscreen = cf.get_value("video", "fullscreen", fullscreen)
	pixel_size = cf.get_value("video", "pixel_size", pixel_size)
	show_beat = cf.get_value("video", "show_beat", show_beat)
	for a in ACTIONS:
		var v = cf.get_value("binds", a[0], null)
		if v is Array:
			binds[a[0]] = v


func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("mouse", "sensitivity", sensitivity)
	cf.set_value("mouse", "invert_y", invert_y)
	cf.set_value("audio", "master", master_volume)
	cf.set_value("video", "fullscreen", fullscreen)
	cf.set_value("video", "pixel_size", pixel_size)
	cf.set_value("video", "show_beat", show_beat)
	for a in ACTIONS:
		cf.set_value("binds", a[0], binds[a[0]])
	cf.save(PATH)
