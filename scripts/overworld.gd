extends Node3D
## VAEL: the city you walk by day. Medieval stone, threaded with aether-tech that grows every day.
##
## You are the Hollow King on foot (boss.gd in WALKER mode): WASD walks, SHIFT runs, the mouse looks.
## LMB swings your blade, Q casts the selected skill, RMB parries, E talks / opens / reads.
## Everything that fights runs on the same 0.25s combat tick as the arena: your swings, your casts,
## your parry window and every foe's windup (the red countdown over its head).
##
## The city: walls at ±38 with east, west and south gates, a fountain plaza at the heart, the
## Hollow Flagon (where the Stranger waits each night), the Rusted Cog, the Lantern & Lens, the
## Cathedral of Gears, a clocktower, a forge, stables and houses. Outside: a graveyard, a river with
## a bridge, and the six LAIRS where each day's boss waits. People react to you by TONE (dialogue.gd).
##
## A day lasts DAY_SECONDS. At dusk the Stranger walks up to you, and main takes you to the board.
## Lives at world (0, 0, 600); everything here is in this node's local space.

signal dusk_met

const Fx := preload("res://scripts/fx.gd")
const Dialogue := preload("res://scripts/dialogue.gd")
const NpcScript := preload("res://scripts/npc.gd")
const EnemyScript := preload("res://scripts/day_enemy.gd")
const StrangerScript := preload("res://scripts/stranger.gd")
const BossScript := preload("res://scripts/boss.gd")
const HotbarScript := preload("res://scripts/ui/hotbar.gd")
const UiArt := preload("res://scripts/ui/ui_art.gd")

const WALL := 38.0
const BOUND := 95.0
const DAY_SECONDS := 300.0
const AUTO_DAY_SECONDS := 40.0
const GOLD := Color(0.95, 0.75, 0.4)
const TEXT := Color(0.88, 0.84, 0.78)

const LAIRS := {
	"farm": Vector3(62, 0, -40), "bridge": Vector3(0, 0, 62), "pit": Vector3(-62, 0, -40),
	"pyre": Vector3(62, 0, 40), "shrine": Vector3(-62, 0, 45), "spire": Vector3(0, 0, -80),
}
const LAIR_NAMES := {
	"farm": "THE BURNED FARM", "bridge": "THE OLD BRIDGE", "pit": "THE SUNFIELD PIT",
	"pyre": "THE PYRE", "shrine": "THE GILDED SHRINE", "spire": "THE DAWNSPIRE",
}
# Where each named person stands (Dialogue.NPCS[id]["spot"]).
const SPOTS := {
	"bakery": Vector3(-9, 0, -6.2), "forge": Vector3(-24, 0, -7.4), "cathedral": Vector3(3, 0, -16.4),
	"alley": Vector3(24, 0, 7), "gate": Vector3(33, 0, -2.5), "cog": Vector3(-16, 0, 8.4),
	"clock": Vector3(-18, 0, -18), "plaza": Vector3(5, 0, 6), "graves": Vector3(-56, 0, 15),
	"flagon": Vector3(16, 0, -8.4),
}
# Where you wake each morning (Dialogue.WAKE[day - 1][0]).
const WAKE_SPOTS := {
	"fountain": Vector3(0, 0, 7), "stables": Vector3(26, 0, 18), "bridge": Vector3(0, 0, 58),
	"cathedral": Vector3(0, 0, -15), "wall": Vector3(-33, 0, 2), "cog": Vector3(-16, 0, 7.5),
	"gate": Vector3(35, 0, 1),
}
# Gates: [inside point, outside point]
const GATES := {
	"east": [Vector3(33, 0, 2.5), Vector3(45, 0, 2.5)],
	"west": [Vector3(-33, 0, 2.5), Vector3(-45, 0, 2.5)],
	"south": [Vector3(2.5, 0, 33), Vector3(2.5, 0, 45)],
}
# Skills by how they behave by day.
const DAY_PROJ := ["fireball", "volley", "lance", "glacier", "nullorb", "masonry", "leech", "siphon", "chains", "bonecage", "hex", "ghouls", "rain"]
const DAY_NOVA := ["slam", "tide", "stomp", "sweep", "grasp", "wall"]
const DAY_STAGGER := ["bloom", "timerend", "chains", "bonecage", "hex", "slam", "stomp", "tide", "wall", "grasp"]

var game
var walker
var env: Environment
var sun: DirectionalLight3D
var active := false
var day := 1
var rects: Array[Rect2] = []
var npcs := {}
var townsfolk: Array = []
var enemies: Array = []
var chests: Array = []        # {node, lid, pos, sealed, id}
var opened := {}
var readables: Array = []     # {pos, title, text}  (graffiti, signs, the grave)
var mirror_pos := Vector3(12, 0, 10.6)
var tech: Array = []          # [node, min_day]
var floaters: Array = []
var airship: Node3D
var weapon_node: Node3D
var stranger
var dusk_state := ""          # "" | "walking" | "met"
var glimpse_t := -1.0
var stranger_last := Vector3.ZERO
var stranger_stuck_t := 0.0
var glimpse_done := false
var day_boss
var engaged
var will := 100.0
var will_max := 100.0
var tick_acc := 0.0
var swing_cd := 0
var swing_queued := false
var bolts: Array = []         # enemy bolts: {node, target, dmg, arrived, ticks}
var strikes: Array = []       # pending ground strikes: {pos, ticks, id, dmg, radius, ring}
var tribute := {}
var served := {}              # once-a-day services already used
var interact_target := {}
var t := 0.0
var regen_block := 0.0

# HUD
var hud_layer: CanvasLayer
var hud: Control
var dread_label: Label
var day_label: Label
var clock_bar: ProgressBar
var will_bar: ProgressBar
var will_label: Label
var weapon_label: Label
var prompt_label: Label
var objective_label: Label
var toast: Label
var toast_sub: Label
var toast_tween: Tween
var boss_box: VBoxContainer
var boss_name: Label
var boss_bar: ProgressBar
var hurt_overlay: ColorRect
var hotbar

# Autoplay
var bot_t := 0.0
var bot_last := Vector3.ZERO
var bot_stuck_t := 0.0
var bot_side := 0.0
var bot_side_t := 0.0


func _ready() -> void:
	env = _make_env()
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)
	_build_ground()
	_build_walls()
	_build_city()
	_build_outside()
	_build_lairs()
	_build_tech()
	_build_people()
	_build_chests()
	walker = BossScript.new()
	walker.walker = true
	walker.ow = self
	walker.game = game
	add_child(walker)
	walker.cam.current = false
	walker.cam.far = 140.0
	walker.right_hand.scale = Vector3.ONE * 1.25  # smaller on foot than on the throne
	walker.left_hand.scale = Vector3.ONE * 1.25
	stranger = StrangerScript.new()
	add_child(stranger)
	stranger.visible = false
	_build_hud()
	set_active(false)


# =============================================================================
# Activation and the day
# =============================================================================

func set_active(on: bool) -> void:
	active = on
	visible = on
	process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	hud.visible = on
	if on:
		walker.cam.current = true


## Start a new day: wake somewhere in Vael, fresh foes outside the walls, today's boss in its lair.
func begin_day() -> void:
	day = GameState.level
	if day == 1:
		opened.clear()
	GameState.day_time = 0.0
	dusk_state = ""
	glimpse_done = false
	glimpse_t = -1.0
	tribute.clear()
	served.clear()
	engaged = null
	boss_box.visible = false
	stranger.visible = false
	stranger.walking = false
	stranger.seated = false
	stranger.refresh()
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	for b in bolts:
		if is_instance_valid(b["node"]):
			b["node"].queue_free()
	bolts.clear()
	for s in strikes:
		if is_instance_valid(s["ring"]):
			s["ring"].queue_free()
	strikes.clear()
	var wake: String = Dialogue.WAKE[clampi(day - 1, 0, Dialogue.WAKE.size() - 1)][0]
	walker.position = WAKE_SPOTS.get(wake, Vector3(0, 0, 7))
	walker.yaw = PI if walker.position.z < -10.0 else 0.0
	walker.pitch = -0.05
	walker.vel = Vector3.ZERO
	walker.reset_cooldowns()
	walker.select(0)
	walker.apply_purity(GameState.purity())
	will_max = GameState.boss_max_hp()
	will = will_max
	swing_cd = 0
	swing_queued = false
	_build_weapon()
	_apply_tech()
	_spawn_wilds()
	_spawn_day_boss()
	for id in npcs:
		npcs[id].visible = true
	_update_sky()
	var tod := "DAY %d" % day
	show_toast(tod + (" · THE LAST DAY" if GameState.is_final_night() else ""), _objective_text(), 4.0)
	game.tutorial("day", "This is Vael, by day. WASD walk, SHIFT runs. LMB swings your blade on the beat, Q casts your selected skill, RMB parries, E talks and opens. At DUSK, someone will come for you.", false, 10.0)


func _day_length() -> float:
	return AUTO_DAY_SECONDS if GameState.autoplay else DAY_SECONDS


func busy() -> bool:
	return not active or is_instance_valid(game.overlay) or get_tree().paused


func _process(delta: float) -> void:
	if not active:
		return
	t += delta
	_update_hud()
	_update_floaters(delta)
	if busy():
		walker.move_input = Vector2.ZERO
		walker.sprint = false
		return
	# The clock. Dialogue and cards stop it.
	if dusk_state == "":
		GameState.day_time += delta / _day_length()
		if GameState.day_time >= 1.0:
			_begin_dusk()
		elif not glimpse_done and GameState.day_time > 0.45:
			_glimpse()
	_update_sky()
	_update_stranger(delta)
	# Input
	if GameState.autoplay:
		_autoplay(delta)
	elif dusk_state != "met":
		var mv := Vector2.ZERO
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			mv.y += 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			mv.y -= 1.0
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			mv.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			mv.x += 1.0
		walker.move_input = mv
		walker.sprint = Input.is_key_pressed(KEY_SHIFT)
	else:
		walker.move_input = Vector2.ZERO
	# Ticks
	tick_acc += delta
	while tick_acc >= GameState.TICK:
		tick_acc -= GameState.TICK
		_tick()
	# Rest: Will slowly returns when nothing is hunting you.
	regen_block = maxf(0.0, regen_block - delta)
	if regen_block <= 0.0:
		will = minf(will_max, will + delta * 3.0)
	var wm := GameState.boss_max_hp()
	if wm != will_max:
		will += maxf(0.0, wm - will_max)
		will_max = wm
	_find_interact()
	hurt_overlay.color.a = move_toward(hurt_overlay.color.a, 0.0, delta * 1.5)


func _input(event: InputEvent) -> void:
	if busy() or dusk_state == "met":
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		walker.look(event.relative)
	elif event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			game._capture_mouse()
			return
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				swing_queued = true
			MOUSE_BUTTON_RIGHT:
				walker.try_parry()
			MOUSE_BUTTON_WHEEL_UP:
				walker.cycle(-1)
			MOUSE_BUTTON_WHEEL_DOWN:
				walker.cycle(1)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_E:
				_interact()
			KEY_Q:
				walker.try_cast(walker.selected_id())
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
				walker.select(event.keycode - KEY_1)
			KEY_ESCAPE:
				game._pause()


# =============================================================================
# Ticks: your swings and casts, every foe's thinking, bolts and ground strikes
# =============================================================================

func _tick() -> void:
	walker.on_tick_begin()
	swing_cd = maxi(0, swing_cd - 1)
	if swing_queued and swing_cd <= 0:
		swing_queued = false
		_swing()
	for e in enemies.duplicate():
		if is_instance_valid(e) and not e.dead:
			e.on_tick()
	for i in range(strikes.size() - 1, -1, -1):
		var s: Dictionary = strikes[i]
		s["ticks"] -= 1
		if s["ticks"] <= 0:
			strikes.remove_at(i)
			_detonate(s)
	for i in range(bolts.size() - 1, -1, -1):
		var b: Dictionary = bolts[i]
		if b["arrived"]:
			bolts.remove_at(i)
			_resolve_bolt(b)
	walker.on_tick_end()


func _weapon() -> Dictionary:
	return Dialogue.WEAPONS.get(GameState.weapon, Dialogue.WEAPONS["shortsword"])


func weapon_damage() -> float:
	var W := _weapon()
	return float(W["dmg"]) * (1.0 + 0.2 * GameState.weapon_tune) * (1.0 + 0.1 * GameState.deeds.size())


## Your blade: everything in an arc in front of you, within reach.
func _swing() -> void:
	var W := _weapon()
	swing_cd = int(W["ticks"])
	walker.anim_r = 1.0
	Sfx.play("dodge", -4.0, 0.6 + randf() * 0.2)
	var fwd := Vector3(-sin(walker.yaw), 0, -cos(walker.yaw))
	var hit := false
	for e in enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		var to := Vector3(e.position.x - walker.position.x, 0, e.position.z - walker.position.z)
		var d := to.length()
		if d > float(W["reach"]) + 0.4 * e.scale.x:
			continue
		if d > 0.6 and to.normalized().dot(fwd) < 0.35:
			continue
		e.take_hit(weapon_damage(), walker.position)
		hit = true
	if hit:
		Sfx.play("hit", -2.0)
		walker.shake(0.12)


## A skill cast by day (called by the walker on a tick). Returns false if it could not be cast.
func spawn_day_attack(id: String) -> bool:
	if not active or dusk_state == "met":
		return false
	var dmg := GameState.damage_for(id) * 1.4
	var col: Color = GameState.SKILLS[id]["color"]
	Sfx.play("cast", -8.0, randf_range(0.8, 1.3))
	if id in DAY_NOVA:
		var r := 5.0 if id in ["tide", "stomp", "sweep"] else 4.0
		_strike_area(walker.position, id, dmg, r)
		walker.shake(0.4)
		return true
	var aim := _aim_point()
	if id in DAY_PROJ:
		var from: Vector3 = walker.hand_tip()
		var dir := (aim - from).normalized()
		var spread := [0.0]
		if id == "volley" or id == "glacier":
			spread = [-0.12, 0.0, 0.12]
		elif id == "leech" or id == "ghouls" or id == "rain":
			spread = [-0.2, -0.07, 0.07, 0.2]
		for a in spread:
			_shoot(id, from, dir.rotated(Vector3.UP, a), dmg / (1.0 if spread.size() == 1 else spread.size() * 0.6), col)
		return true
	# Ground strikes: a ring marks the spot, then it erupts a tick or a few later.
	var lp := to_local(aim)
	lp.y = 0.0
	var rad := 2.6
	var ticks := 1
	match id:
		"meteor", "hands":
			rad = 3.6
			ticks = 4
		"pillar", "lightning", "thunder":
			rad = 1.8
		"well", "maw", "doom":
			rad = 3.0
			ticks = 2
		"eclipse", "timerend":
			rad = 6.0
	var ring := _ring(lp, rad, col)
	strikes.append({"pos": lp, "ticks": ticks, "id": id, "dmg": dmg, "radius": rad, "ring": ring})
	if id == "thunder":
		strikes.append({"pos": lp, "ticks": ticks + 2, "id": id, "dmg": dmg, "radius": rad, "ring": null})
	return true


func _aim_point() -> Vector3:
	var cam: Camera3D = walker.cam
	var origin := cam.global_position
	var dir := -cam.global_transform.basis.z
	var best_d := 1.6
	var best := Vector3.INF
	for e in enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		var c: Vector3 = e.center()
		var along := (c - origin).dot(dir)
		if along <= 0.0 or along > 40.0:
			continue
		var off := (origin + dir * along).distance_to(c)
		if off < best_d * e.scale.x:
			best_d = off
			best = c
	if best != Vector3.INF:
		return best
	var floor_y := global_position.y
	if dir.y < -0.01:
		return origin + dir * minf((floor_y - origin.y) / dir.y, 30.0)
	return origin + dir * 30.0


func _shoot(id: String, from: Vector3, dir: Vector3, dmg: float, col: Color) -> void:
	var s := Shot.new()
	s.ow = self
	s.id = id
	s.dmg = dmg
	s.dir = dir
	s.radius = 1.6 if id in ["fireball", "volley", "masonry", "nullorb"] else 0.0
	s.homing = 3.0 if id == "nullorb" else 0.0
	s.speed = 14.0 if id == "nullorb" else 24.0
	s.life = 2.5
	add_child(s)
	s.global_position = from
	s.add_child(Fx.sphere(0.16 if id != "masonry" else 0.3, Fx.mat(col, 6.0)))
	s.add_child(Fx.sphere(0.3, Fx.mat(col, 2.0, 0.3)))
	var l := OmniLight3D.new()
	l.light_color = col
	l.omni_range = 3.0
	l.light_energy = 1.5
	s.add_child(l)


## A shot struck something (or ran out): hurt what it hit and anything in its blast.
func explode(gpos: Vector3, id: String, dmg: float, radius: float, direct) -> void:
	var col: Color = GameState.SKILLS[id]["color"]
	game.spawn_burst(gpos, col, 12)
	var dealt := 0.0
	if direct != null and is_instance_valid(direct) and not direct.dead:
		direct.take_hit(dmg, walker.position)
		dealt += dmg
		if id in DAY_STAGGER and not direct.is_boss:
			direct._go("stagger")
	if radius > 0.0:
		for e in enemies:
			if e == direct or not is_instance_valid(e) or e.dead:
				continue
			if e.center().distance_to(gpos) < radius:
				e.take_hit(dmg * 0.6, walker.position)
				dealt += dmg * 0.6
	if id == "siphon" and dealt > 0.0:
		will = minf(will_max, will + dealt * 0.5)
	if dealt > 0.0:
		Sfx.play("hit", -4.0)


func enemy_near(gpos: Vector3, r: float):
	for e in enemies:
		if is_instance_valid(e) and not e.dead and e.center().distance_to(gpos) < r * e.scale.x:
			return e
	return null


func nearest_enemy(gpos: Vector3, r: float):
	var best = null
	var bd := r
	for e in enemies:
		if is_instance_valid(e) and not e.dead:
			var d: float = e.center().distance_to(gpos)
			if d < bd:
				bd = d
				best = e
	return best


func _detonate(s: Dictionary) -> void:
	if is_instance_valid(s["ring"]):
		s["ring"].queue_free()
	_strike_area(s["pos"], s["id"], s["dmg"], s["radius"])


func _strike_area(lp: Vector3, id: String, dmg: float, radius: float) -> void:
	var col: Color = GameState.SKILLS[id]["color"]
	var gp := to_global(lp)
	game.spawn_burst(gp + Vector3(0, 0.4, 0), col, 24)
	var col_mesh := Fx.cylinder(radius, radius, 0.3, Fx.mat(col, 4.0, 0.5), lp + Vector3(0, 0.15, 0))
	add_child(col_mesh)
	var tw := col_mesh.create_tween()
	tw.tween_property(col_mesh, "scale", Vector3(1.1, 6.0, 1.1), 0.15)
	tw.tween_property(col_mesh, "scale", Vector3(0.01, 0.01, 0.01), 0.25)
	tw.tween_callback(col_mesh.queue_free)
	Sfx.play("slam", -6.0, 1.2)
	var dealt := 0.0
	for e in enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		var d := Vector2(e.position.x - lp.x, e.position.z - lp.z).length()
		if d < radius + 0.4 * e.scale.x:
			e.take_hit(dmg, lp)
			dealt += dmg
			if id in DAY_STAGGER and is_instance_valid(e) and not e.dead:
				e._go("stagger")
	if id == "siphon" and dealt > 0.0:
		will = minf(will_max, will + dealt * 0.5)


func _ring(lp: Vector3, r: float, col: Color) -> MeshInstance3D:
	var tm := TorusMesh.new()
	tm.inner_radius = maxf(0.1, r - 0.15)
	tm.outer_radius = r
	tm.rings = 32
	tm.ring_segments = 4
	var m := MeshInstance3D.new()
	m.mesh = tm
	m.material_override = Fx.mat(col, 3.0, 0.8)
	m.position = lp + Vector3(0, 0.05, 0)
	m.scale = Vector3(1, 0.1, 1)
	add_child(m)
	return m


# --- Foes hitting you ---------------------------------------------------------------

func enemy_strike(e, dmg: float) -> void:
	_take_blow(dmg, e)


func enemy_bolt(e, from: Vector3, dmg: float) -> void:
	var b := Node3D.new()
	add_child(b)
	b.global_position = from
	var col: Color = e.tech
	b.add_child(Fx.sphere(0.14, Fx.mat(col, 6.0)))
	b.add_child(Fx.sphere(0.26, Fx.mat(col, 2.0, 0.3)))
	var target: Vector3 = walker.head.global_position + Vector3(0, -0.25, 0)
	var entry := {"node": b, "target": target, "dmg": dmg, "arrived": false}
	bolts.append(entry)
	var dist := from.distance_to(target)
	var tw := b.create_tween()
	tw.tween_property(b, "global_position", target, maxf(0.25, dist / 14.0))
	tw.tween_callback(func(): entry["arrived"] = true)
	Sfx.play("cast", -10.0, 1.7)


func _resolve_bolt(b: Dictionary) -> void:
	var node: Node3D = b["node"]
	if is_instance_valid(node):
		game.spawn_burst(node.global_position, Color(1.0, 0.6, 0.3), 8)
		node.queue_free()
	if walker.head.global_position.distance_to(b["target"]) > 1.3:
		game.popup_text(b["target"], "MISSED", Color(0.8, 0.9, 1.0), 0.8)
		return
	_take_blow(b["dmg"], null)


func _take_blow(dmg: float, from) -> void:
	if dusk_state == "met":
		return
	regen_block = 6.0
	if walker.is_parrying():
		dmg *= GameState.parry_taken()
		GameState.style["parries"] += 1
		GameState.add_dread(2.0)
		walker.parried()
		Sfx.play("parry")
		game.popup_text(walker.head.global_position + Vector3(0, 0.2, -1.2), "PARRIED", Color(1.0, 0.92, 0.6), 1.0)
		if from != null and is_instance_valid(from) and not from.dead:
			from._go("stagger")
		game.tutorial("day_parry", "A clean parry. Foes by day are staggered by it, and their next blow comes later.")
	else:
		walker.hurt()
		Sfx.play("boss_hurt", -4.0)
		hurt_overlay.color.a = 0.45
		game.tutorial("day_hurt", "The red number over a foe counts the ticks until its blow lands. RIGHT-CLICK on the last beat to parry, or step out of its reach.")
	will -= dmg
	if will <= 0.0:
		_collapse()


## Your Will breaks by day: you wake back where you started, poorer, and later.
func _collapse() -> void:
	will = 0.0
	walker.move_input = Vector2.ZERO
	var lost := int(GameState.dread * 0.2)
	GameState.dread -= lost
	game._show_card("YOU COLLAPSE", "The streets go dark. When you open your eyes, the sun has moved and your purse is lighter (-%d DREAD)." % lost,
		"GET UP", _get_up, Color(0.9, 0.2, 0.18))


func _get_up() -> void:
	GameState.day_time = minf(0.95, GameState.day_time + 0.12)
	var wake: String = Dialogue.WAKE[clampi(day - 1, 0, Dialogue.WAKE.size() - 1)][0]
	walker.position = WAKE_SPOTS.get(wake, Vector3(0, 0, 7))
	will = will_max * 0.6
	for e in enemies:
		if is_instance_valid(e) and not e.is_boss:
			e.aggro = false
			e._go("idle")
	_close_dialogue()


func popup(gpos: Vector3, text: String, col: Color) -> void:
	game.popup_text(gpos, text, col, 0.9)


func burst(gpos: Vector3, col: Color) -> void:
	game.spawn_burst(gpos, col, 16)


func boss_engaged(e) -> void:
	engaged = e
	boss_box.visible = true
	boss_name.text = e.display_name
	var d := _boss_data()
	show_toast(e.display_name, str(d.get("intro", "")), 4.0)
	Sfx.play("learn", -4.0, 0.8)
	game.tutorial("day_boss", "Today's boss. Beat it before dusk for a DEED: you are stronger every night after (+10% damage, +25 Will), and it pays Crowns at your next prestige.")


func summon_adds(e, n: int) -> void:
	for k in n:
		var a := randf() * TAU
		var p: Vector3 = e.position + Vector3(cos(a), 0, sin(a)) * 2.5
		var add = _spawn_enemy("thug", p)
		add.aggro = true


func _on_enemy_died(e) -> void:
	enemies.erase(e)
	if e.is_boss:
		print("[DEED] day %d: %s slain" % [day, e.display_name])
		GameState.deeds.append(_boss_data()["id"])
		GameState.day_boss_slain = true
		GameState.add_dread(60.0 + 10.0 * day)
		boss_box.visible = false
		engaged = null
		Sfx.play("crown")
		game._show_choice(e.display_name + " FALLS", str(_boss_data()["defeat"]) + "\n\nA DEED DONE BY DAY: +10% damage and +25 Will from tonight on.", "crown",
			[["CONTINUE", _close_dialogue]])
		return
	GameState.add_dread(6.0 + 3.0 * day)
	game.popup_text(e.center() + Vector3(0, 0.8, 0), "+%d DREAD" % int(6 + 3 * day), Color(0.56, 0.85, 1.0), 0.9)


# =============================================================================
# Dusk and the Stranger
# =============================================================================

## Halfway through the day: a man in white, far off, watching you. Gone when you get close.
func _glimpse() -> void:
	glimpse_done = true
	var fwd := Vector3(-sin(walker.yaw), 0, -cos(walker.yaw))
	var p := resolve(walker.position, walker.position + fwd * 22.0, 0.5)
	if p.distance_to(walker.position) < 14.0:
		return
	stranger.position = p
	stranger.walking = false
	stranger.visible = true
	stranger.rotation.y = atan2(-(walker.position.x - p.x), -(walker.position.z - p.z))
	glimpse_t = 10.0


func _begin_dusk() -> void:
	GameState.day_time = 1.0
	dusk_state = "walking"
	boss_box.visible = false
	engaged = null
	# The streets empty. Foes melt into the dark.
	for e in enemies:
		if is_instance_valid(e) and not e.dead:
			game.spawn_burst(e.center(), Color(0.3, 0.2, 0.4), 10)
			e.queue_free()
	enemies.clear()
	for b in bolts:
		if is_instance_valid(b["node"]):
			b["node"].queue_free()
	bolts.clear()
	# He comes from somewhere with a clear line to you.
	var a0 := randf() * TAU
	var p: Vector3 = walker.position
	for k in 12:
		var a := a0 + TAU * k / 12.0
		var cand: Vector3 = walker.position + Vector3(cos(a), 0, sin(a)) * 13.0
		if _clear_line(cand, walker.position):
			p = cand
			break
	stranger.position = p
	stranger_last = p
	stranger_stuck_t = 0.0
	stranger.refresh()
	stranger.visible = true
	stranger.walking = true
	glimpse_t = -1.0
	var line := "A man in white walks toward you through the crowd. No one else seems to see him."
	if GameState.revealed:
		line = "He walks toward you. You know his walk now. It is yours."
	if GameState.is_final_night():
		line = "Dusk. He is not walking toward a table tonight. He is walking toward you."
	show_toast("DUSK", line, 4.0)
	Sfx.play("reveal", -6.0, 0.6)


func _update_stranger(delta: float) -> void:
	if glimpse_t > 0.0 and dusk_state == "":
		glimpse_t -= delta
		if glimpse_t <= 0.0 or stranger.position.distance_to(walker.position) < 12.0:
			game.spawn_burst(stranger.global_position + Vector3(0, 1.0, 0), Color(1.0, 0.95, 0.85), 18)
			stranger.visible = false
			glimpse_t = -1.0
			game.tutorial("glimpse", "A man in white. Gone, the moment you looked closer.")
		return
	if dusk_state != "walking":
		return
	var to := Vector3(walker.position.x - stranger.position.x, 0, walker.position.z - stranger.position.z)
	var d := to.length()
	stranger.rotation.y = atan2(-to.x, -to.z)
	if d > 2.2:
		var step: Vector3 = stranger.position + to.normalized() * 2.4 * delta
		# If something is in his way for too long, he simply is not stopped by it.
		stranger.position = step if stranger_stuck_t > 1.0 else resolve(stranger.position, step, 0.4)
		stranger_stuck_t += delta
		if stranger.position.distance_to(stranger_last) > 0.8:
			stranger_last = stranger.position
			stranger_stuck_t = 0.0
		return
	stranger.walking = false
	dusk_state = "met"
	walker.move_input = Vector2.ZERO
	# Face him.
	var head_p: Vector3 = stranger.global_position + Vector3(0, 1.6, 0)
	var dd: Vector3 = head_p - walker.head.global_position
	walker.yaw = atan2(-dd.x, -dd.z)
	walker.pitch = -0.05
	get_tree().create_timer(0.6, false).timeout.connect(func(): dusk_met.emit())


# =============================================================================
# Talking, opening, reading
# =============================================================================

func _find_interact() -> void:
	interact_target = {}
	var p: Vector3 = walker.position
	var fwd := Vector3(-sin(walker.yaw), 0, -cos(walker.yaw))
	var best := 3.2
	for id in npcs:
		var n: Node3D = npcs[id]
		var d := Vector2(n.position.x - p.x, n.position.z - p.z).length()
		if d < best and _facing(n.position, fwd):
			best = d
			interact_target = {"kind": "npc", "id": id, "label": "TALK TO " + str(Dialogue.NPCS[id]["name"])}
	for c in chests:
		if opened.has(c["id"]):
			continue
		var d2 := Vector2(c["pos"].x - p.x, c["pos"].z - p.z).length()
		if d2 < best and _facing(c["pos"], fwd):
			best = d2
			interact_target = {"kind": "chest", "chest": c, "label": "BREAK THE DREAD SEAL (%d)" % c["sealed"] if c["sealed"] > 0 else "OPEN THE CHEST"}
	for r in readables:
		var d3 := Vector2(r["pos"].x - p.x, r["pos"].z - p.z).length()
		if d3 < best and _facing(r["pos"], fwd):
			best = d3
			interact_target = {"kind": "read", "r": r, "label": "READ"}
	var dm := Vector2(mirror_pos.x - p.x, mirror_pos.z - p.z).length()
	if dm < best and _facing(mirror_pos, fwd):
		interact_target = {"kind": "mirror", "label": "LOOK INTO THE MIRROR"}
	prompt_label.text = ("E: " + str(interact_target["label"])) if not interact_target.is_empty() else ""


func _facing(target: Vector3, fwd: Vector3) -> bool:
	var to := Vector3(target.x - walker.position.x, 0, target.z - walker.position.z)
	return to.length() < 1.0 or to.normalized().dot(fwd) > 0.25


func _interact() -> void:
	if interact_target.is_empty():
		return
	match interact_target["kind"]:
		"npc":
			_talk(interact_target["id"])
		"chest":
			_open_chest(interact_target["chest"])
		"read":
			var r: Dictionary = interact_target["r"]
			Sfx.play("click")
			game._show_card(r["title"], r["text"], "STEP AWAY", _close_dialogue)
		"mirror":
			_mirror()


func _close_dialogue() -> void:
	game._clear_overlay()
	if active:
		game._capture_mouse()


## What a service costs: nothing if they fear you (but you may pay anyway), full price if they
## are wary, half if they think you are a saint.
func _price(base: int) -> int:
	match Dialogue.tone():
		0:
			return 0
		2:
			return int(base * 0.5)
	return base


func _talk(id: String) -> void:
	var N: Dictionary = Dialogue.NPCS[id]
	var tone := Dialogue.tone()
	if npcs.has(id):
		npcs[id].talk()
	GameState.npc_met[id] = true
	Sfx.play("click", -4.0, 0.8)
	var opts: Array = []
	var service: String = N["service"]
	var label: String = str(Dialogue.SERVICES[service]).split(" · ")[0]
	var base := {"bread": 6, "bless": 25, "drink": 15, "tune": 35}.get(service, 0) as int
	if base > 0:
		if served.has(service) and service != "bread":
			opts.append([label + "  (ALREADY TODAY)", _talk.bind(id)])
		elif tone == 0:
			opts.append([label + " · FREE (THEY ARE AFRAID)", _do_service.bind(id, 0, false)])
			opts.append(["Pay anyway · %d DREAD" % base, _do_service.bind(id, base, true)])
		else:
			opts.append([label + " · %d DREAD%s" % [_price(base), " (SAINT'S DISCOUNT)" if tone == 2 else ""], _do_service.bind(id, _price(base), false)])
	else:
		opts.append([str(Dialogue.SERVICES[service]), _do_service.bind(id, 0, false)])
	opts.append(["Ask about the man in white", _ask_stranger.bind(id)])
	if tone < 2 and not tribute.has(id) and service != "give":
		opts.append([Dialogue.INTIMIDATE, _intimidate.bind(id)])
	opts.append(["Leave", _close_dialogue])
	var body: String = N["greet"][tone]
	body += "\n\n(YOUR DREAD: %d · THE CITY %s YOU)" % [int(GameState.dread), ["FEARS", "IS WARY OF", "BLESSES"][tone]]
	game._show_choice(N["name"], body, "", opts)


func _reply(id: String, text: String) -> void:
	game._show_choice(Dialogue.NPCS[id]["name"], text, "", [["Thank them", _close_dialogue], ["Talk more", _talk.bind(id)]])


func _do_service(id: String, cost: int, kind: bool) -> void:
	var service: String = Dialogue.NPCS[id]["service"]
	if cost > 0 and GameState.dread < cost:
		Sfx.play("deny")
		_reply(id, "You do not have %d Dread." % cost)
		return
	GameState.dread -= cost
	if kind:
		GameState.kindness += 1
	if cost > 0:
		Sfx.play("coin")
	var tone := Dialogue.tone()
	match service:
		"bread":
			will = minf(will_max, will + 60.0)
			_reply(id, ["She drops the loaf in your hands and backs away." if not kind else "She stares at the coins. Then at you. \"...Thank you, my lord.\"",
				"Warm bread. You feel your Will steady (+60).", "\"Eat, eat! You're too thin for a saint.\" (+60 Will)"][tone])
		"weapons":
			_forge()
			return
		"bless":
			served[service] = true
			GameState.tonight_will += 40.0
			_reply(id, "She lays a hand on your brow, %s. (+40 Will tonight)" % ["trembling" if tone == 0 else "steady"])
		"give":
			if GameState.dread < 10:
				Sfx.play("deny")
				_reply(id, "You have nothing to give.")
				return
			GameState.dread -= 10
			GameState.kindness += 1
			Sfx.play("coin")
			_reply(id, ["The child snatches the coins and runs. Then stops, and looks back.", "\"For me? Really?\" Pip bites one to check.",
				"Pip hugs your leg. \"I'm going to buy bread for EVERYONE.\""][tone])
		"bounty":
			var d := _boss_data()
			if d.is_empty() or GameState.day_boss_slain:
				_reply(id, "Quiet past the walls today. Whatever you did, it worked.")
			else:
				_reply(id, "%s. Out by %s, %s of the walls. Bring it down before dusk, and the city will remember it." % [d["name"], LAIR_NAMES[d["lair"]], _compass(LAIRS[d["lair"]] - walker.position)])
		"drink":
			served[service] = true
			GameState.tonight_will += 25.0
			_reply(id, ["She pours with both hands shaking. (+25 Will tonight)", "Hot ale, a seat by the cog-fire. (+25 Will tonight)", "The whole bar raises a glass to you. (+25 Will tonight)"][tone])
		"tune":
			if GameState.weapon_tune >= 3:
				GameState.dread += cost
				_reply(id, "\"Any more aether in that blade and it'll start thinking for itself.\" (Fully tuned)")
				return
			served[service] = true
			GameState.weapon_tune += 1
			_build_weapon()
			_reply(id, "The blade drinks the light from the conduits. It hums. (Weapon damage +20%%, tuned %d / 3)" % GameState.weapon_tune)
		"song":
			_reply(id, _song())
		"grave":
			if not GameState.npc_met.has("grave_knelt"):
				GameState.npc_met["grave_knelt"] = true
				GameState.fragments += 1
				_reply(id, "You kneel at the empty grave marked WREN. You remember mud, a borrowed sword, a mother calling a name.\n\nMEMORY FRAGMENT FOUND.")
			else:
				_reply(id, "The grass on the empty grave has been cut. Someone in white tends it, Ansel says.")
		"wait":
			_close_dialogue()
			if dusk_state == "":
				GameState.day_time = 0.999
			return


func _song() -> String:
	if GameState.revealed:
		return "\"Two men at a table, one in white, one in black,\nOne carries the other, and neither looks back...\"\n\nThe tavern goes quiet. Oswin will not look at you."
	match Dialogue.tone():
		0:
			return "\"Oh the Hollow King, so great, so wise...\"\n\nHe is sweating."
		1:
			return "\"A man in white at the corner table,\nPlays every night as long as he's able...\"\n\nHe watches you while he sings it."
	return "\"Lay down the crown and the crown lays down you,\nThe saint of Vael walks the old road through...\"\n\nChildren sing the last line with him."


func _ask_stranger(id: String) -> void:
	var hints: Array = Dialogue.STRANGER_HINTS[clampi(day - 1, 0, Dialogue.STRANGER_HINTS.size() - 1)]
	_reply(id, str(hints.pick_random()))


func _intimidate(id: String) -> void:
	tribute[id] = true
	GameState.dread += 20.0
	GameState.cruelty += 1
	Sfx.play("coin", -2.0, 0.7)
	_reply(id, ["They empty their pockets into your hand without a word.", "They pay. They will not look at you again today."][mini(Dialogue.tone(), 1)])


func _forge() -> void:
	var opts: Array = []
	for wid in Dialogue.WEAPONS:
		var W: Dictionary = Dialogue.WEAPONS[wid]
		if int(W["tier"]) > day or wid == GameState.weapon:
			continue
		var cost := _price(int(W["cost"]))
		opts.append(["%s · %d DMG / %d TICKS · %s" % [str(W["name"]).to_upper(), int(W["dmg"]), int(W["ticks"]), ("%d DREAD" % cost) if cost > 0 else "FREE"],
			_buy_weapon.bind(wid, cost)])
	var cur := _weapon()
	var body := "Steel on the walls, aether in the quench-tank. New blades come in as the city rises.\n\nYOU CARRY: %s (%d DMG, A SWING EVERY %d TICKS)\nYOUR DREAD: %d" % [str(cur["name"]).to_upper(), int(weapon_damage()), int(cur["ticks"]), int(GameState.dread)]
	if opts.is_empty():
		body += "\n\nNothing better on the rack today."
	opts.append(["Leave the forge", _close_dialogue])
	game._show_choice("OLD HENNIK'S FORGE", body, "", opts)


func _buy_weapon(wid: String, cost: int) -> void:
	if GameState.dread < cost:
		Sfx.play("deny")
		_reply("hennik", "You do not have %d Dread." % cost)
		return
	GameState.dread -= cost
	GameState.weapon = wid
	GameState.weapon_tune = 0
	_build_weapon()
	Sfx.play("crown", -4.0)
	var W: Dictionary = Dialogue.WEAPONS[wid]
	_reply("hennik", "%s\n\nYou take up the %s." % [W["desc"], str(W["name"]).to_upper()])


func _open_chest(c: Dictionary) -> void:
	if c["sealed"] > 0:
		game._show_choice("A SEALED CHEST", "Black wax over the lock, still warm. It hungers for Dread.\n\nYOUR DREAD: %d" % int(GameState.dread), "dread",
			[["Break the seal · %d DREAD" % c["sealed"], _break_seal.bind(c)], ["Leave it", _close_dialogue]])
		return
	_loot(c)


func _break_seal(c: Dictionary) -> void:
	if GameState.dread < c["sealed"]:
		Sfx.play("deny")
		game._show_card("NOT ENOUGH DREAD", "The seal drinks what you offer and wants more.", "STEP AWAY", _close_dialogue)
		return
	GameState.dread -= c["sealed"]
	_loot(c)


func _loot(c: Dictionary) -> void:
	opened[c["id"]] = true
	var lid: Node3D = c["lid"]
	var tw := lid.create_tween()
	tw.tween_property(lid, "rotation:x", -1.6, 0.4).set_trans(Tween.TRANS_BACK)
	Sfx.play("coin")
	var sealed: bool = c["sealed"] > 0
	var line := ""
	var better := ""
	var cur_tier := int(_weapon()["tier"])
	for wid in Dialogue.WEAPONS:
		var tr := int(Dialogue.WEAPONS[wid]["tier"])
		if tr > cur_tier and tr <= day + (1 if sealed else 0) and (better == "" or tr > int(Dialogue.WEAPONS[better]["tier"])):
			better = wid
	var r := randf()
	if better != "" and r < (0.5 if sealed else 0.3):
		GameState.weapon = better
		GameState.weapon_tune = 0
		_build_weapon()
		line = "Wrapped in oilcloth: the %s.\n%s" % [str(Dialogue.WEAPONS[better]["name"]).to_upper(), Dialogue.WEAPONS[better]["desc"]]
	elif r < 0.65:
		var amt := (20.0 + 10.0 * day) * (2.0 if sealed else 1.0)
		GameState.dread += amt
		line = "Dread, pooled in the bottom like dark water. +%d DREAD" % int(amt)
	elif r < 0.85:
		var cr := (3 + 2 * day) * (2 if sealed else 1)
		GameState.crowns += cr
		line = "Old crowns, stamped with a face that looks like yours. +%d CROWNS" % cr
	else:
		line = GameState.apply_effect("rank")
	game._show_card("THE CHEST OPENS", line, "TAKE IT", _close_dialogue)


func _mirror() -> void:
	Sfx.play("reveal", -8.0, 1.4)
	var p := GameState.purity()
	var text := ""
	if GameState.is_final_night():
		text = "One face in the glass. No crown. No hood. Just a tired man who is ready."
	elif GameState.revealed:
		text = "Two faces in the glass: one wearing a crown, one wearing a hood. Only one of them is standing in front of the mirror."
	elif p < 0.2:
		text = "A hollow thing looks back. Thorns through the skin, a crown too big for its head.\n\nFor a moment, over its shoulder, a man in white. Then nothing."
	elif p < 0.5:
		text = "Your face, mostly. The eyes are clearer than you remember.\n\nThe reflection blinks a moment after you do."
	else:
		text = "The reflection is wearing white.\n\nYou are not."
	game._show_card("THE LANTERN & LENS MIRROR", text, "STEP AWAY", _close_dialogue)


# =============================================================================
# Collision: everything solid is a rectangle on the ground (x, z).
# =============================================================================

func _solid(c: Vector2, size: Vector2) -> void:
	rects.append(Rect2(c - size * 0.5, size))


func blocked(lp: Vector3) -> bool:
	if absf(lp.x) > BOUND or absf(lp.z) > BOUND:
		return true
	for r in rects:
		if r.has_point(Vector2(lp.x, lp.z)):
			return true
	return false


## Slide a body of radius r from `from` toward `to`, pushed out of every solid rectangle.
func resolve(from: Vector3, to: Vector3, r: float) -> Vector3:
	var p := to
	p.x = clampf(p.x, -BOUND, BOUND)
	p.z = clampf(p.z, -BOUND, BOUND)
	for pass_i in 2:
		for rc in rects:
			var e := rc.grow(r)
			if not e.has_point(Vector2(p.x, p.z)):
				continue
			var dl := p.x - e.position.x
			var dr := e.end.x - p.x
			var dt := p.z - e.position.y
			var db := e.end.y - p.z
			var m := minf(minf(dl, dr), minf(dt, db))
			if m == dl:
				p.x = e.position.x - 0.001
			elif m == dr:
				p.x = e.end.x + 0.001
			elif m == dt:
				p.z = e.position.y - 0.001
			else:
				p.z = e.end.y + 0.001
	p.y = from.y
	return p


func _clear_line(a: Vector3, b: Vector3) -> bool:
	for k in 13:
		if blocked(a.lerp(b, k / 12.0)):
			return false
	return true


func _inside(p: Vector3) -> bool:
	return absf(p.x) < WALL and absf(p.z) < WALL


# =============================================================================
# Sky: its own sun and sky, by time of day
# =============================================================================

func _make_env() -> Environment:
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.6
	e.fog_enabled = true
	e.fog_density = 0.0025
	e.fog_sky_affect = 0.3
	e.glow_enabled = true
	e.glow_intensity = 0.35
	e.glow_bloom = 0.03
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	return e


func _update_sky() -> void:
	var dt := clampf(GameState.day_time, 0.0, 1.0)
	var sm: ProceduralSkyMaterial = env.sky.sky_material
	var dawn := Color(0.95, 0.6, 0.45)
	var noon := Color(0.42, 0.62, 0.95)
	var dusk := Color(0.55, 0.28, 0.45)
	var top := dawn.lerp(noon, clampf(dt * 4.0, 0.0, 1.0)).lerp(dusk, clampf((dt - 0.7) / 0.3, 0.0, 1.0))
	var horizon := top.lerp(Color(1.0, 0.8, 0.6), 0.45)
	if dusk_state != "":
		top = Color(0.15, 0.08, 0.2)
		horizon = Color(0.55, 0.22, 0.25)
	sm.sky_top_color = top
	sm.sky_horizon_color = horizon
	sm.ground_horizon_color = horizon.darkened(0.3)
	sm.ground_bottom_color = Color(0.12, 0.1, 0.1)
	env.fog_light_color = horizon
	sun.rotation_degrees = Vector3(-lerpf(12.0, 168.0, dt), 35.0, 0.0)
	var warm := Color(1.0, 0.72, 0.5)
	sun.light_color = warm.lerp(Color(1.0, 0.96, 0.9), sin(dt * PI))
	sun.light_energy = 0.35 + 0.85 * sin(dt * PI) if dusk_state == "" else 0.2
	env.ambient_light_energy = 0.35 + 0.35 * sin(dt * PI)


# =============================================================================
# Building Vael
# =============================================================================

func _build_ground() -> void:
	var grass := Fx.textured(Fx.stone_texture(Color(0.28, 0.4, 0.2), Color(0.25, 0.36, 0.18), 32, 8), Vector3(40, 40, 1))
	var pm := PlaneMesh.new()
	pm.size = Vector2(BOUND * 2.0 + 10.0, BOUND * 2.0 + 10.0)
	var g := MeshInstance3D.new()
	g.mesh = pm
	g.material_override = grass
	add_child(g)
	var cobble := Fx.textured(Fx.stone_texture(Color(0.45, 0.42, 0.4), Color(0.4, 0.37, 0.36), 32, 4), Vector3(30, 30, 1))
	var cm := PlaneMesh.new()
	cm.size = Vector2(WALL * 2.0, WALL * 2.0)
	var c := MeshInstance3D.new()
	c.mesh = cm
	c.material_override = cobble
	c.position.y = 0.01
	add_child(c)
	# Dirt roads to every lair (and around the walls to the Dawnspire)
	var dirt := Fx.mat(Color(0.42, 0.33, 0.22))
	for seg in _roads():
		var a: Vector3 = seg[0]
		var b: Vector3 = seg[1]
		var road := Fx.box(Vector3(3.2, 0.02, a.distance_to(b) + 3.0), dirt, (a + b) * 0.5 + Vector3(0, 0.012, 0))
		road.rotation.y = atan2(b.x - a.x, b.z - a.z)
		add_child(road)
	# The river and its bridge
	var water := Fx.mat(Color(0.2, 0.4, 0.6), 0.4, 0.85)
	add_child(Fx.box(Vector3(BOUND * 2.0 + 10.0, 0.05, 8.0), water, Vector3(0, 0.02, 72)))
	_solid(Vector2(-49.5, 72), Vector2(93, 8))
	_solid(Vector2(49.5, 72), Vector2(93, 8))
	var stone := Fx.mat(Color(0.5, 0.47, 0.44))
	add_child(Fx.box(Vector3(6, 0.4, 12), stone, Vector3(0, 0.2, 72)))
	for s in [-1.0, 1.0]:
		add_child(Fx.box(Vector3(0.4, 1.0, 12), stone, Vector3(s * 3.0, 0.7, 72)))
	_solid(Vector2(-3.1, 72), Vector2(0.4, 12))
	_solid(Vector2(3.1, 72), Vector2(0.4, 12))


func _roads() -> Array:
	var E: Vector3 = GATES["east"][1]
	var W: Vector3 = GATES["west"][1]
	var S: Vector3 = GATES["south"][1]
	return [[E, LAIRS["farm"]], [E, LAIRS["pyre"]], [W, LAIRS["pit"]], [W, LAIRS["shrine"]], [S, LAIRS["bridge"]],
		[E, Vector3(46, 0, -46)], [Vector3(46, 0, -46), LAIRS["spire"]], [W, Vector3(-56, 0, 15)],
		[S, Vector3(-46, 0, 46)], [S, Vector3(46, 0, 46)], [W, Vector3(-46, 0, -46)], [Vector3(-46, 0, -46), LAIRS["spire"]]]


func _build_walls() -> void:
	var wall_mat := Fx.textured(Fx.stone_texture(Color(0.5, 0.46, 0.42), Color(0.42, 0.38, 0.35), 32, 4, true), Vector3(20, 2, 1))
	var h := 6.0
	var th := 1.6
	# North (solid)
	_wall_seg(Vector2(-WALL, -WALL), Vector2(WALL, -WALL), h, th, wall_mat)
	# South, east, west: each with a gate gap of ±4
	_wall_seg(Vector2(-WALL, WALL), Vector2(-4, WALL), h, th, wall_mat)
	_wall_seg(Vector2(4, WALL), Vector2(WALL, WALL), h, th, wall_mat)
	for s in [-1.0, 1.0]:
		_wall_seg(Vector2(s * WALL, -WALL), Vector2(s * WALL, -4), h, th, wall_mat)
		_wall_seg(Vector2(s * WALL, 4), Vector2(s * WALL, WALL), h, th, wall_mat)
	# Towers at the corners and beside each gate
	var tower := Fx.mat(Color(0.4, 0.37, 0.34))
	var roof := Fx.mat(Color(0.45, 0.15, 0.12))
	var towers := [Vector2(-WALL, -WALL), Vector2(WALL, -WALL), Vector2(-WALL, WALL), Vector2(WALL, WALL),
		Vector2(WALL, -5.5), Vector2(WALL, 5.5), Vector2(-WALL, -5.5), Vector2(-WALL, 5.5), Vector2(-5.5, WALL), Vector2(5.5, WALL)]
	for tp in towers:
		add_child(Fx.cylinder(1.8, 2.0, 9.0, tower, Vector3(tp.x, 4.5, tp.y)))
		add_child(Fx.cylinder(0.0, 2.3, 3.0, roof, Vector3(tp.x, 10.5, tp.y)))
		_solid(tp, Vector2(4, 4))
	# Gate arches with banners
	for g in [[Vector3(WALL, 0, 0), 0.0], [Vector3(-WALL, 0, 0), 0.0], [Vector3(0, 0, WALL), PI / 2.0]]:
		var arch := Fx.box(Vector3(th + 0.4, 1.4, 8.0), tower, g[0] + Vector3(0, 6.3, 0))
		arch.rotation.y = g[1]
		add_child(arch)
		var banner := Fx.box(Vector3(0.1, 2.4, 1.4), Fx.mat(Color(0.55, 0.12, 0.15)), g[0] + Vector3(0, 4.4, 0))
		banner.rotation.y = g[1]
		add_child(banner)


func _wall_seg(a: Vector2, b: Vector2, h: float, th: float, m: Material) -> void:
	var c := (a + b) * 0.5
	var horiz := absf(a.y - b.y) < 0.01
	var length := a.distance_to(b)
	var size := Vector3(length, h, th) if horiz else Vector3(th, h, length)
	add_child(Fx.box(size, m, Vector3(c.x, h * 0.5, c.y)))
	_solid(c, Vector2(size.x, size.z))
	var n := int(length / 2.0)
	for k in n:
		var f := (k + 0.5) / n
		var p := a.lerp(b, f)
		add_child(Fx.box(Vector3(0.8, 0.7, th) if horiz else Vector3(th, 0.7, 0.8), m, Vector3(p.x, h + 0.35, p.y)))


## A building: walls, a pitched roof, a door, lit windows, and a hanging sign.
## door: which face the door is on ("n" = -z, "s" = +z, "e" = +x, "w" = -x).
func _building(c: Vector2, size: Vector2, h: float, wall_col: Color, roof_col: Color, door: String, sign_text: String = "") -> Node3D:
	var n := Node3D.new()
	n.position = Vector3(c.x, 0, c.y)
	add_child(n)
	var wm := Fx.textured(Fx.stone_texture(wall_col, wall_col.darkened(0.12), 32, 4, true), Vector3(size.x / 3.0, h / 3.0, 1))
	n.add_child(Fx.box(Vector3(size.x, h, size.y), wm, Vector3(0, h * 0.5, 0)))
	# Timber beams
	var beam := Fx.mat(Color(0.25, 0.16, 0.1))
	n.add_child(Fx.box(Vector3(size.x + 0.1, 0.25, size.y + 0.1), beam, Vector3(0, h * 0.55, 0)))
	var roof_m := Fx.mat(roof_col)
	var w := minf(size.x, size.y)
	var roof := Fx.box(Vector3(w * 0.75, w * 0.75, maxf(size.x, size.y) + 0.6), roof_m, Vector3(0, h, 0))
	if size.x >= size.y:
		roof.rotation = Vector3(0, PI / 2.0, PI / 4.0)
	else:
		roof.rotation.z = PI / 4.0
	n.add_child(roof)
	var dir := {"n": Vector3(0, 0, -1), "s": Vector3(0, 0, 1), "e": Vector3(1, 0, 0), "w": Vector3(-1, 0, 0)}[door] as Vector3
	var half := Vector3(size.x * 0.5, 0, size.y * 0.5)
	var face := Vector3(dir.x * half.x, 0, dir.z * half.z)
	var door_box := Fx.box(Vector3(1.4, 2.4, 0.2) if dir.x == 0.0 else Vector3(0.2, 2.4, 1.4), Fx.mat(Color(0.2, 0.12, 0.08)), face + dir * 0.05 + Vector3(0, 1.2, 0))
	n.add_child(door_box)
	var glass := Fx.mat(Color(1.0, 0.8, 0.45), 2.0)
	var across := Vector3(dir.z, 0, dir.x).abs()
	for s in [-1.0, 1.0]:
		var wpos: Vector3 = face + dir * 0.05 + across * s * minf(2.4, (size.x if dir.x == 0.0 else size.y) * 0.3) + Vector3(0, 2.0, 0)
		n.add_child(Fx.box(Vector3(0.8, 0.8, 0.12) if dir.x == 0.0 else Vector3(0.12, 0.8, 0.8), glass, wpos))
	if sign_text != "":
		var sign := Label3D.new()
		sign.text = sign_text
		sign.font = UiArt.pixel_font()
		sign.font_size = 32
		sign.pixel_size = 0.02
		sign.outline_size = 6
		sign.modulate = Color(1.0, 0.85, 0.5)
		sign.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sign.position = face + dir * 0.3 + Vector3(0, 3.3, 0)
		sign.rotation.y = atan2(dir.x, dir.z)
		n.add_child(sign)
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.7, 0.4)
		lamp.omni_range = 6.0
		lamp.light_energy = 1.2
		lamp.position = face + dir * 1.0 + Vector3(0, 2.8, 0)
		n.add_child(lamp)
	_solid(c, size)
	return n


func _build_city() -> void:
	# The fountain plaza
	var stone := Fx.mat(Color(0.6, 0.57, 0.52))
	add_child(Fx.cylinder(2.0, 2.2, 0.8, stone, Vector3(0, 0.4, 0)))
	add_child(Fx.cylinder(1.7, 1.7, 0.1, Fx.mat(Color(0.3, 0.55, 0.8), 0.6, 0.85), Vector3(0, 0.78, 0)))
	add_child(Fx.cylinder(0.3, 0.4, 2.4, stone, Vector3(0, 1.2, 0)))
	add_child(Fx.cylinder(0.8, 0.3, 0.3, stone, Vector3(0, 2.4, 0)))
	var spray := Fx.particles(Color(0.6, 0.85, 1.0), 30, 1.0, 2.5, 0.06)
	spray.direction = Vector3.UP
	spray.spread = 25.0
	spray.gravity = Vector3(0, -6.0, 0)
	spray.position = Vector3(0, 2.6, 0)
	add_child(spray)
	_solid(Vector2.ZERO, Vector2(4.2, 4.2))
	var plaza := Fx.cylinder(10.0, 10.0, 0.02, Fx.mat(Color(0.55, 0.5, 0.45)), Vector3(0, 0.02, 0))
	add_child(plaza)

	var plaster := Color(0.78, 0.72, 0.6)
	var dark_wall := Color(0.45, 0.4, 0.38)
	_building(Vector2(16, -14), Vector2(10, 8), 5.0, Color(0.42, 0.3, 0.22), Color(0.22, 0.12, 0.1), "s", "THE HOLLOW FLAGON")
	_building(Vector2(-16, 14), Vector2(10, 8), 5.0, Color(0.5, 0.35, 0.28), Color(0.4, 0.22, 0.12), "n", "THE RUSTED COG")
	var lens := _building(Vector2(16, 16), Vector2(8, 7), 4.5, Color(0.35, 0.4, 0.5), Color(0.15, 0.2, 0.3), "n", "LANTERN & LENS")
	lens.add_child(Fx.sphere(0.5, Fx.mat(Color(0.5, 0.9, 1.0), 3.0), Vector3(3.0, 5.0, -3.5)))
	# The mirror outside the Lantern & Lens
	var frame := Fx.mat(Color(0.75, 0.6, 0.25), 0.4)
	add_child(Fx.box(Vector3(1.4, 2.2, 0.15), frame, mirror_pos + Vector3(0, 1.3, 0)))
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.75, 0.82, 0.9)
	glass.metallic = 1.0
	glass.roughness = 0.05
	add_child(Fx.box(Vector3(1.15, 1.9, 0.05), glass, mirror_pos + Vector3(0, 1.3, -0.08)))
	_solid(Vector2(mirror_pos.x, mirror_pos.z), Vector2(1.4, 0.3))
	# Cathedral of Gears
	var cat := _building(Vector2(0, -27), Vector2(14, 18), 11.0, Color(0.62, 0.6, 0.58), Color(0.3, 0.3, 0.38), "s", "CATHEDRAL OF GEARS")
	cat.add_child(Fx.cylinder(0.0, 2.0, 9.0, Fx.mat(Color(0.3, 0.3, 0.38)), Vector3(0, 19.0, 5.0)))
	cat.add_child(Fx.box(Vector3(4.5, 14.0, 4.5), Fx.mat(Color(0.6, 0.58, 0.56)), Vector3(0, 7.0, 5.0)))
	var gear := TorusMesh.new()
	gear.inner_radius = 1.2
	gear.outer_radius = 1.7
	gear.rings = 12
	gear.ring_segments = 6
	var rose := MeshInstance3D.new()
	rose.mesh = gear
	rose.material_override = Fx.mat(Color(0.9, 0.7, 0.3), 1.5)
	rose.rotation.x = PI / 2.0
	rose.position = Vector3(0, 8.5, 9.1)
	cat.add_child(rose)
	# Clocktower
	var clock := Node3D.new()
	clock.position = Vector3(-18, 0, -22)
	add_child(clock)
	clock.add_child(Fx.box(Vector3(5, 16, 5), Fx.textured(Fx.stone_texture(dark_wall, dark_wall.darkened(0.1), 32, 4, true), Vector3(2, 6, 1)), Vector3(0, 8, 0)))
	clock.add_child(Fx.cylinder(0.0, 3.6, 4.0, Fx.mat(Color(0.25, 0.2, 0.3)), Vector3(0, 18.0, 0)))
	var face := Fx.cylinder(1.6, 1.6, 0.2, Fx.mat(Color(0.95, 0.9, 0.75), 0.6), Vector3(0, 12.5, 2.55))
	face.rotation.x = PI / 2.0
	clock.add_child(face)
	var hand := Fx.box(Vector3(0.12, 1.3, 0.05), Fx.mat(Color(0.1, 0.08, 0.08)), Vector3(0, 12.9, 2.7))
	clock.add_child(hand)
	tech.append([hand, -1])  # (the hand spins in _update_floaters)
	_solid(Vector2(-18, -22), Vector2(5, 5))
	# Forge: an open shed with a hearth
	var forge := Node3D.new()
	forge.position = Vector3(-24, 0, -12)
	add_child(forge)
	var beam := Fx.mat(Color(0.25, 0.16, 0.1))
	forge.add_child(Fx.box(Vector3(8, 4, 0.5), Fx.mat(dark_wall), Vector3(0, 2, -2.8)))
	for px in [-3.8, 3.8]:
		for pz in [-2.8, 2.8]:
			forge.add_child(Fx.box(Vector3(0.3, 4, 0.3), beam, Vector3(px, 2, pz)))
	var froof := Fx.box(Vector3(8.6, 0.3, 6.6), Fx.mat(Color(0.3, 0.18, 0.12)), Vector3(0, 4.1, 0))
	froof.rotation.x = 0.15
	forge.add_child(froof)
	forge.add_child(Fx.box(Vector3(2.2, 1.2, 1.4), Fx.mat(Color(0.3, 0.28, 0.28)), Vector3(-2, 0.6, -1.8)))
	forge.add_child(Fx.box(Vector3(1.6, 0.4, 1.0), Fx.mat(Color(1.0, 0.45, 0.1), 5.0), Vector3(-2, 1.3, -1.8)))
	forge.add_child(Fx.box(Vector3(0.9, 0.7, 0.45), Fx.mat(Color(0.2, 0.2, 0.22)), Vector3(1.0, 0.35, 0.2)))
	var sparks := Fx.particles(Color(1.0, 0.6, 0.2), 16, 0.6, 2.5, 0.05)
	sparks.position = Vector3(-2, 1.5, -1.8)
	forge.add_child(sparks)
	var heat := OmniLight3D.new()
	heat.light_color = Color(1.0, 0.5, 0.2)
	heat.light_energy = 2.0
	heat.omni_range = 7.0
	heat.position = Vector3(-2, 2.0, -1.0)
	forge.add_child(heat)
	_solid(Vector2(-24, -14.8), Vector2(8, 0.6))
	_solid(Vector2(-26, -13.8), Vector2(2.4, 1.6))
	_solid(Vector2(-23, -11.8), Vector2(1.0, 0.6))
	# Bakery stall
	var stall := Node3D.new()
	stall.position = Vector3(-9, 0, -8)
	add_child(stall)
	stall.add_child(Fx.box(Vector3(4, 1.0, 1.4), Fx.mat(Color(0.45, 0.3, 0.18)), Vector3(0, 0.5, 0)))
	var awning := Fx.box(Vector3(4.4, 0.1, 2.0), Fx.mat(Color(0.8, 0.3, 0.25)), Vector3(0, 2.6, 0.2))
	awning.rotation.x = -0.2
	stall.add_child(awning)
	for k in 5:
		stall.add_child(Fx.box(Vector3(0.45, 0.2, 0.3), Fx.mat(Color(0.85, 0.6, 0.3)), Vector3(-1.6 + k * 0.8, 1.1, 0)))
	_solid(Vector2(-9, -8), Vector2(4, 1.4))
	# Stables
	var stab := Node3D.new()
	stab.position = Vector3(26, 0, 24)
	add_child(stab)
	stab.add_child(Fx.box(Vector3(10, 3.5, 0.4), Fx.mat(Color(0.4, 0.28, 0.18)), Vector3(0, 1.75, 3)))
	var sroof := Fx.box(Vector3(10.5, 0.3, 6.5), Fx.mat(Color(0.35, 0.22, 0.12)), Vector3(0, 3.6, 0))
	sroof.rotation.x = -0.12
	stab.add_child(sroof)
	for px in [-5.0, 0.0, 5.0]:
		stab.add_child(Fx.box(Vector3(0.3, 3.5, 0.3), beam, Vector3(px, 1.75, -2.8)))
	for k in 3:
		stab.add_child(Fx.box(Vector3(1.2, 0.8, 0.9), Fx.mat(Color(0.85, 0.75, 0.35)), Vector3(-3.5 + k * 1.3, 0.4, 2.0)))
	# A horse
	var hide := Fx.mat(Color(0.35, 0.22, 0.14))
	stab.add_child(Fx.box(Vector3(0.6, 0.7, 1.8), hide, Vector3(2.5, 1.3, 0.5)))
	stab.add_child(Fx.box(Vector3(0.35, 0.8, 0.4), hide, Vector3(2.5, 1.9, -0.4)))
	stab.add_child(Fx.box(Vector3(0.3, 0.35, 0.6), hide, Vector3(2.5, 2.2, -0.75)))
	for lx in [-0.2, 0.2]:
		for lz in [-0.6, 0.6]:
			stab.add_child(Fx.box(Vector3(0.14, 1.0, 0.14), hide, Vector3(2.5 + lx, 0.5, 0.5 + lz)))
	_solid(Vector2(26, 26), Vector2(10, 2.4))
	_solid(Vector2(28.5, 24.5), Vector2(1.0, 2.2))
	# Houses
	var houses := [Vector2(-30, -26), Vector2(-30, 22), Vector2(-20, 28), Vector2(-8, 26), Vector2(8, 26), Vector2(30, -16),
		Vector2(30, -28), Vector2(-14, -32), Vector2(14, -31), Vector2(-30, 14), Vector2(30, 10), Vector2(-30, -16)]
	var roofs := [Color(0.45, 0.18, 0.12), Color(0.3, 0.22, 0.15), Color(0.25, 0.25, 0.3), Color(0.5, 0.3, 0.15)]
	for i in houses.size():
		var hp: Vector2 = houses[i]
		var door := "e" if hp.x < -20 else ("w" if hp.x > 20 else ("n" if hp.y > 0 else "s"))
		_building(hp, Vector2(6, 6), 4.0 + (i % 3) * 0.7, plaster.darkened((i % 4) * 0.08), roofs[i % roofs.size()], door)
	# Graffiti on the walls
	var g_spots := [
		[Vector3(-WALL + 0.85, 2.6, 14), PI / 2.0], [Vector3(20, 2.6, -WALL + 0.85), 0.0], [Vector3(10.9, 2.0, -14), -PI / 2.0],
		[Vector3(-20, 2.6, WALL - 0.85), PI], [Vector3(WALL - 0.85, 2.6, -20), -PI / 2.0], [Vector3(-18, 3.0, -19.45), 0.0]]
	for i in g_spots.size():
		var gl := Label3D.new()
		gl.text = Dialogue.GRAFFITI[i]
		gl.font = UiArt.pixel_font()
		gl.font_size = 32
		gl.pixel_size = 0.012
		gl.modulate = [Color(0.85, 0.15, 0.15), Color(0.95, 0.95, 0.95), Color(0.3, 0.6, 1.0)][i % 3]
		gl.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		gl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gl.width = 260.0
		gl.position = g_spots[i][0]
		gl.rotation.y = g_spots[i][1]
		add_child(gl)
		var fwd := Vector3(sin(g_spots[i][1]), 0, cos(g_spots[i][1]))
		readables.append({"pos": Vector3(gl.position.x, 0, gl.position.z) + fwd * 0.6, "title": "SCRAWLED ON THE WALL", "text": "\"" + Dialogue.GRAFFITI[i] + "\"\n\nThe paint is fresh. It is your handwriting."})


func _build_outside() -> void:
	# The graveyard
	var gy := Vector3(-60, 0, 15)
	var fence := Fx.mat(Color(0.2, 0.18, 0.2))
	for k in 9:
		add_child(Fx.box(Vector3(0.12, 1.2, 0.12), fence, gy + Vector3(-8 + k * 2, 0.6, -6)))
		add_child(Fx.box(Vector3(0.12, 1.2, 0.12), fence, gy + Vector3(-8 + k * 2, 0.6, 6)))
	var tomb := Fx.mat(Color(0.5, 0.5, 0.52))
	for gx in 4:
		for gz in 3:
			var tp := gy + Vector3(-5 + gx * 3.0, 0, -3 + gz * 3.0)
			add_child(Fx.box(Vector3(0.8, 1.0, 0.2), tomb, tp + Vector3(0, 0.5, 0)))
			_solid(Vector2(tp.x, tp.z), Vector2(0.8, 0.3))
	var wren := Label3D.new()
	wren.text = "WREN"
	wren.font = UiArt.pixel_font()
	wren.font_size = 32
	wren.pixel_size = 0.008
	wren.modulate = Color(0.15, 0.12, 0.12)
	wren.position = gy + Vector3(-5, 0.75, 3.11)
	add_child(wren)
	readables.append({"pos": gy + Vector3(-5, 0, 3.8), "title": "A GRAVE MARKED WREN", "text": "No dates. No body, Ansel says. Fresh flowers, white ones, every morning."})
	add_child(Fx.box(Vector3(3, 3, 3), Fx.mat(Color(0.35, 0.33, 0.35)), gy + Vector3(5, 1.5, -3)))
	_solid(Vector2(gy.x + 5, gy.z - 3), Vector2(3, 3))
	# Trees, kept off the roads and lairs
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var trunk := Fx.mat(Color(0.3, 0.2, 0.12))
	var leaves := [Fx.mat(Color(0.2, 0.38, 0.16)), Fx.mat(Color(0.25, 0.42, 0.18)), Fx.mat(Color(0.32, 0.4, 0.15))]
	var roads := _roads()
	var placed := 0
	var tries := 0
	while placed < 70 and tries < 600:
		tries += 1
		var p := Vector3(rng.randf_range(-90, 90), 0, rng.randf_range(-90, 66))
		if absf(p.x) < WALL + 5.0 and absf(p.z) < WALL + 5.0:
			continue
		var ok := true
		for lk in LAIRS:
			if p.distance_to(LAIRS[lk]) < 12.0:
				ok = false
		if p.distance_to(gy) < 11.0:
			ok = false
		for seg in roads:
			if _seg_dist(p, seg[0], seg[1]) < 5.0:
				ok = false
		if not ok:
			continue
		placed += 1
		var hgt := rng.randf_range(2.5, 4.5)
		add_child(Fx.box(Vector3(0.4, hgt, 0.4), trunk, p + Vector3(0, hgt * 0.5, 0)))
		var lm: Material = leaves[rng.randi() % leaves.size()]
		add_child(Fx.box(Vector3(2.4, 1.6, 2.4), lm, p + Vector3(0, hgt + 0.4, 0)))
		add_child(Fx.box(Vector3(1.5, 1.0, 1.5), lm, p + Vector3(0, hgt + 1.5, 0)))
		_solid(Vector2(p.x, p.z), Vector2(0.6, 0.6))


func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var ap := Vector2(p.x - a.x, p.z - a.z)
	var k := clampf(ap.dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return (ap - ab * k).length()


func _build_lairs() -> void:
	for lk in LAIRS:
		var c: Vector3 = LAIRS[lk]
		var node := Node3D.new()
		node.position = c
		add_child(node)
		match lk:
			"farm":
				var burnt := Fx.mat(Color(0.12, 0.1, 0.09))
				node.add_child(Fx.box(Vector3(7, 3, 5), burnt, Vector3(0, 1.5, -6)))
				var r := Fx.box(Vector3(3.5, 3.5, 5.5), burnt, Vector3(-1, 3.2, -6))
				r.rotation.z = PI / 4.0 + 0.3
				node.add_child(r)
				for k in 8:
					node.add_child(Fx.box(Vector3(0.15, 1.0, 0.15), burnt, Vector3(-8 + k * 2.2, 0.5, 5)))
				var embers := Fx.particles(Color(1.0, 0.4, 0.1), 20, 1.6, 1.0, 0.06)
				embers.gravity = Vector3(0, 0.8, 0)
				embers.position = Vector3(0, 2.0, -6)
				node.add_child(embers)
				_solid(Vector2(c.x, c.z - 6), Vector2(7, 5))
			"bridge":
				for s in [-1.0, 1.0]:
					node.add_child(Fx.box(Vector3(1.2, 4.0, 1.2), Fx.mat(Color(0.45, 0.42, 0.4)), Vector3(s * 4.0, 2.0, 3.0)))
					node.add_child(Fx.sphere(0.4, Fx.mat(Color(0.4, 0.7, 1.0), 4.0), Vector3(s * 4.0, 4.4, 3.0)))
					_solid(Vector2(c.x + s * 4.0, c.z + 3.0), Vector2(1.2, 1.2))
			"pit":
				var sand := Fx.mat(Color(0.75, 0.62, 0.4))
				node.add_child(Fx.cylinder(9.0, 9.0, 0.05, sand, Vector3(0, 0.03, 0)))
				var wallm := Fx.mat(Color(0.5, 0.4, 0.3))
				for k in 14:
					if k == 3:
						continue  # the entrance
					var a := TAU * k / 14.0
					var seg := Fx.box(Vector3(4.2, 2.2, 0.6), wallm, Vector3(cos(a) * 10.0, 1.1, sin(a) * 10.0))
					seg.rotation.y = -a + PI / 2.0
					node.add_child(seg)
					_solid(Vector2(c.x + cos(a) * 10.0, c.z + sin(a) * 10.0), Vector2(2.2, 2.2))
			"pyre":
				node.add_child(Fx.box(Vector3(0.4, 5.0, 0.4), Fx.mat(Color(0.3, 0.2, 0.12)), Vector3(0, 2.5, -4)))
				for k in 6:
					var log := Fx.box(Vector3(3.0, 0.4, 0.4), Fx.mat(Color(0.35, 0.22, 0.12)), Vector3(0, 0.3 + (k / 2) * 0.35, -4))
					log.rotation.y = k * 0.6
					node.add_child(log)
				var fire := Fx.particles(Color(1.0, 0.7, 0.3), 30, 1.0, 2.0, 0.1)
				fire.gravity = Vector3(0, 2.0, 0)
				fire.position = Vector3(0, 1.0, -4)
				node.add_child(fire)
				var fl := OmniLight3D.new()
				fl.light_color = Color(1.0, 0.6, 0.3)
				fl.light_energy = 2.5
				fl.omni_range = 10.0
				fl.position = Vector3(0, 2.5, -4)
				node.add_child(fl)
				_solid(Vector2(c.x, c.z - 4), Vector2(2.4, 2.4))
			"shrine":
				var gilt := Fx.mat(Color(0.9, 0.75, 0.35), 0.5)
				node.add_child(Fx.box(Vector3(8, 0.5, 6), Fx.mat(Color(0.85, 0.82, 0.75)), Vector3(0, 0.25, -6)))
				for px in [-3.5, -1.2, 1.2, 3.5]:
					node.add_child(Fx.cylinder(0.3, 0.35, 4.0, Fx.mat(Color(0.95, 0.92, 0.85)), Vector3(px, 2.5, -4)))
					_solid(Vector2(c.x + px, c.z - 4), Vector2(0.8, 0.8))
				node.add_child(Fx.box(Vector3(8.6, 0.6, 6.6), gilt, Vector3(0, 4.8, -6)))
				node.add_child(Fx.sphere(0.8, Fx.mat(Color(1.0, 0.95, 0.6), 4.0), Vector3(0, 2.2, -7)))
				_solid(Vector2(c.x, c.z - 7.5), Vector2(8, 3))
			"spire":
				var glassm := Fx.mat(Color(0.15, 0.05, 0.2), 0.6)
				node.add_child(Fx.cylinder(0.0, 3.0, 30.0, glassm, Vector3(0, 15.0, -6)))
				node.add_child(Fx.sphere(1.0, Fx.mat(Color(1.0, 0.2, 0.3), 6.0), Vector3(0, 22.0, -6)))
				var rl := OmniLight3D.new()
				rl.light_color = Color(1.0, 0.2, 0.3)
				rl.omni_range = 18.0
				rl.light_energy = 2.0
				rl.position = Vector3(0, 6.0, -3)
				node.add_child(rl)
				_solid(Vector2(c.x, c.z - 6), Vector2(5, 5))
		var sign := Label3D.new()
		sign.text = LAIR_NAMES[lk]
		sign.font = UiArt.pixel_font()
		sign.font_size = 32
		sign.pixel_size = 0.03
		sign.outline_size = 8
		sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sign.modulate = Color(1.0, 0.85, 0.5)
		sign.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sign.position = Vector3(0, 7.0 if lk != "spire" else 12.0, 0)
		node.add_child(sign)


## The aether-tech of Vael: it grows a little every day.
func _build_tech() -> void:
	var post := Fx.mat(Color(0.2, 0.18, 0.2))
	var flame := Fx.mat(Color(1.0, 0.6, 0.2), 5.0)
	var globe := Fx.mat(Color(0.4, 0.85, 1.0), 5.0)
	var lamps: Array[Vector3] = []
	for k in range(-30, 31, 10):
		if k == 0:
			continue
		lamps.append(Vector3(k, 0, -5.2))
		lamps.append(Vector3(k, 0, 5.2))
	for k in range(10, 31, 10):
		lamps.append(Vector3(-5.2, 0, k))
		lamps.append(Vector3(5.2, 0, k))
	for lp in lamps:
		add_child(Fx.box(Vector3(0.18, 3.2, 0.18), post, lp + Vector3(0, 1.6, 0)))
		var f := Fx.box(Vector3(0.25, 0.35, 0.25), flame, lp + Vector3(0, 3.4, 0))
		add_child(f)
		tech.append([f, 0])  # torches: day 1 only (min_day 0 = until day 2, see _apply_tech)
		var g := Fx.sphere(0.28, globe, lp + Vector3(0, 3.45, 0))
		add_child(g)
		tech.append([g, 2])
		_solid(Vector2(lp.x, lp.z), Vector2(0.3, 0.3))
	# Conduits: glowing aether lines along the avenues (day 3+)
	var cond := Fx.mat(Color(0.3, 0.9, 1.0), 3.0)
	for s in [-1.0, 1.0]:
		var a := Fx.box(Vector3(WALL * 2.0 - 4.0, 0.05, 0.15), cond, Vector3(0, 0.03, s * 4.2))
		add_child(a)
		tech.append([a, 3])
		var b := Fx.box(Vector3(0.15, 0.05, WALL + 18.0), cond, Vector3(s * 4.2, 0.03, 10.0))
		add_child(b)
		tech.append([b, 3])
	# Floating lanterns over the plaza (day 4+)
	for k in 10:
		var a2 := TAU * k / 10.0
		var fl := Fx.sphere(0.25, Fx.mat(Color(1.0, 0.85, 0.5), 4.0), Vector3(cos(a2) * 7.0, 5.0 + (k % 3), sin(a2) * 7.0))
		add_child(fl)
		tech.append([fl, 4])
		floaters.append(fl)
	# Holo banners (day 5+)
	for hb in [[Vector3(0, 13.0, -17.6), "VAEL ASCENDANT"], [Vector3(-18, 15.5, -19.3), "THE HOUR IS NEAR"]]:
		var bl := Label3D.new()
		bl.text = hb[1]
		bl.font = UiArt.pixel_font()
		bl.font_size = 32
		bl.pixel_size = 0.025
		bl.modulate = Color(0.4, 0.95, 1.0, 0.85)
		bl.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		bl.position = hb[0]
		add_child(bl)
		tech.append([bl, 5])
	# An airship (day 6+)
	airship = Node3D.new()
	add_child(airship)
	airship.add_child(Fx.box(Vector3(2.0, 1.2, 7.0), Fx.mat(Color(0.4, 0.25, 0.15)), Vector3(0, 0, 0)))
	var bag := Fx.sphere(2.5, Fx.mat(Color(0.8, 0.75, 0.65)), Vector3(0, 3.0, 0))
	bag.scale = Vector3(1.0, 0.9, 2.4)
	airship.add_child(bag)
	airship.add_child(Fx.box(Vector3(0.3, 0.3, 0.3), Fx.mat(Color(0.4, 0.9, 1.0), 6.0), Vector3(0, -0.2, 3.6)))
	tech.append([airship, 6])


func _apply_tech() -> void:
	for entry in tech:
		var n: Node3D = entry[0]
		var md: int = entry[1]
		if md < 0:
			continue
		n.visible = (day < 2) if md == 0 else day >= md


func _update_floaters(delta: float) -> void:
	for i in floaters.size():
		var f: Node3D = floaters[i]
		f.position.y = 5.0 + (i % 3) + sin(t * 1.3 + i) * 0.4
	if airship and airship.visible:
		var a := t * 0.05
		airship.position = Vector3(cos(a) * 45.0, 30.0, sin(a) * 45.0)
		airship.rotation.y = -a
	for entry in tech:
		if entry[1] == -1:
			(entry[0] as Node3D).rotation.z = -GameState.day_time * TAU * 2.0


func _build_people() -> void:
	for id in Dialogue.NPCS:
		var N: Dictionary = Dialogue.NPCS[id]
		var n = NpcScript.new()
		n.npc_id = id
		n.display_name = N["name"]
		n.cloth = N["look"][0]
		n.accent = N["look"][1]
		n.small = N.get("small", false)
		n.ow = self
		n.position = SPOTS.get(N["spot"], Vector3.ZERO)
		add_child(n)
		npcs[id] = n
	# Townsfolk wander the avenues
	var palette := [[Color(0.5, 0.35, 0.25), Color(0.7, 0.6, 0.4)], [Color(0.3, 0.35, 0.5), Color(0.5, 0.7, 0.9)],
		[Color(0.55, 0.5, 0.4), Color(0.8, 0.4, 0.3)], [Color(0.35, 0.45, 0.3), Color(0.9, 0.8, 0.5)]]
	var routes := [
		[Vector3(-30, 0, -2.5), Vector3(-8, 0, -2.5), Vector3(-6, 0, 6), Vector3(-30, 0, 2.5)],
		[Vector3(30, 0, 2.5), Vector3(8, 0, 2.5), Vector3(6, 0, -6), Vector3(30, 0, -2.5)],
		[Vector3(-2.5, 0, 30), Vector3(-2.5, 0, 8), Vector3(2.5, 0, -14), Vector3(2.5, 0, 30)],
		[Vector3(-7, 0, -7), Vector3(7, 0, -7), Vector3(7, 0, 7), Vector3(-7, 0, 7)],
	]
	for k in 14:
		var n = NpcScript.new()
		var pal: Array = palette[k % palette.size()]
		n.cloth = pal[0]
		n.accent = pal[1]
		n.ow = self
		var route: Array = routes[k % routes.size()]
		n.waypoints = route
		n.wp = k % route.size()
		n.position = route[(k + 1) % route.size()] + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
		add_child(n)
		townsfolk.append(n)


func _build_chests() -> void:
	# [position, dread seal cost (0 = open)]
	var spots := [
		[Vector3(-33, 0, -33), 0], [Vector3(33, 0, 33), 25], [Vector3(-3, 0, -35), 40], [Vector3(-26, 0, 6), 0],
		[Vector3(70, 0, -32), 0], [Vector3(-70, 0, -30), 30], [Vector3(6, 0, 66), 0], [Vector3(-56, 0, 55), 50],
		[Vector3(55, 0, 52), 0], [Vector3(8, 0, -86), 60], [Vector3(-64, 0, 20), 0],
	]
	for i in spots.size():
		var p: Vector3 = spots[i][0]
		var sealed: int = spots[i][1]
		var node := Node3D.new()
		node.position = p
		add_child(node)
		var wood := Fx.mat(Color(0.4, 0.24, 0.12))
		var band := Fx.mat(Color(0.85, 0.65, 0.2), 0.6)
		node.add_child(Fx.box(Vector3(1.0, 0.55, 0.65), wood, Vector3(0, 0.28, 0)))
		node.add_child(Fx.box(Vector3(1.04, 0.08, 0.7), band, Vector3(0, 0.45, 0)))
		var lid := Node3D.new()
		lid.position = Vector3(0, 0.56, 0.32)
		node.add_child(lid)
		lid.add_child(Fx.box(Vector3(1.04, 0.22, 0.68), wood, Vector3(0, 0.1, -0.33)))
		if sealed > 0:
			lid.add_child(Fx.box(Vector3(0.22, 0.22, 0.06), Fx.mat(Color(0.3, 0.6, 1.0), 4.0), Vector3(0, 0.0, -0.69)))
		chests.append({"node": node, "lid": lid, "pos": p, "sealed": sealed, "id": i})
		_solid(Vector2(p.x, p.z), Vector2(1.0, 0.65))


# =============================================================================
# Foes
# =============================================================================

func _spawn_enemy(kind: String, p: Vector3):
	var e = EnemyScript.new()
	e.ow = self
	e.kind = kind
	var g := 1.0 + 0.35 * (day - 1)
	match kind:
		"archer":
			e.max_hp = 30.0 * g
			e.dmg = 6.0 * (1.0 + 0.25 * (day - 1))
			e.cloth = Color(0.3, 0.35, 0.25)
		"automaton":
			e.max_hp = 75.0 * g
			e.dmg = 9.0 * (1.0 + 0.25 * (day - 1))
			e.speed = 2.0
			e.cloth = Color(0.45, 0.32, 0.22)
			e.tech = Color(0.4, 0.8, 1.0)
		_:
			e.max_hp = 40.0 * g
			e.dmg = 6.0 * (1.0 + 0.25 * (day - 1))
	e.position = resolve(p, p, 0.5)
	add_child(e)
	e.died.connect(_on_enemy_died)
	enemies.append(e)
	return e


func _spawn_wilds() -> void:
	var n := 4 + day * 2
	var lairs := LAIRS.values()
	for k in n:
		var kind := "thug"
		var r := randf()
		if day >= 2 and r < 0.3:
			kind = "archer"
		elif day >= 3 and r < 0.5:
			kind = "automaton"
		var base: Vector3 = lairs[k % lairs.size()]
		var a := randf() * TAU
		var p := base + Vector3(cos(a), 0, sin(a)) * randf_range(10.0, 18.0)
		_spawn_enemy(kind, p)


func _boss_data() -> Dictionary:
	if day < 1 or day > Dialogue.DAY_BOSSES.size():
		return {}
	return Dialogue.DAY_BOSSES[day - 1]


func _spawn_day_boss() -> void:
	day_boss = null
	var d := _boss_data()
	if d.is_empty():
		return
	var e = EnemyScript.new()
	e.ow = self
	e.kind = d["kind"]
	e.is_boss = true
	e.display_name = d["name"]
	e.max_hp = d["hp"]
	e.dmg = d["dmg"]
	e.speed = d["speed"]
	e.reach = 2.4
	e.cloth = d["color"]
	e.tech = d["tech"]
	e.position = LAIRS[d["lair"]]
	add_child(e)
	e.died.connect(_on_enemy_died)
	enemies.append(e)
	day_boss = e


# =============================================================================
# Your blade
# =============================================================================

func _build_weapon() -> void:
	if is_instance_valid(weapon_node):
		weapon_node.queue_free()
	var W := _weapon()
	weapon_node = Node3D.new()
	weapon_node.position = Vector3(0.0, 0.03, -0.08)
	weapon_node.rotation = Vector3(0.75, 0.15, 0)  # tip up and forward, into view
	walker.right_hand.add_child(weapon_node)
	var steel := Fx.mat(W["color"], float(W["glow"]) + 0.6 * GameState.weapon_tune)
	var grip := Fx.mat(Color(0.25, 0.15, 0.1))
	var length := 0.22 + float(W["reach"]) * 0.1
	weapon_node.add_child(Fx.box(Vector3(0.03, 0.03, 0.12), grip, Vector3(0, 0, 0.02)))
	weapon_node.add_child(Fx.box(Vector3(0.14, 0.025, 0.025), Fx.mat(Color(0.75, 0.6, 0.25)), Vector3(0, 0, -0.05)))
	if W["kind"] == "axe":
		weapon_node.add_child(Fx.box(Vector3(0.02, 0.02, length), grip, Vector3(0, 0, -0.06 - length * 0.5)))
		weapon_node.add_child(Fx.box(Vector3(0.015, 0.12, 0.09), steel, Vector3(0, 0.04, -0.06 - length * 0.9)))
	else:
		weapon_node.add_child(Fx.box(Vector3(0.045, 0.014, length), steel, Vector3(0, 0, -0.06 - length * 0.5)))


# =============================================================================
# HUD
# =============================================================================

func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 1
	game.add_child(hud_layer)  # outside the pixelated SubViewport, like the arena HUD
	hud = Control.new()
	hud.theme = game.theme_res
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hurt_overlay = ColorRect.new()
	hurt_overlay.color = Color(0.6, 0.0, 0.0, 0.0)
	hurt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hurt_overlay)
	hurt_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var info := VBoxContainer.new()
	game._anchor(info, 0, 0, 0, 0, 16, 12, 420, 120)
	hud.add_child(info)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	info.add_child(row)
	var flame := TextureRect.new()
	flame.texture = UiArt.icon("dread")
	flame.custom_minimum_size = Vector2(40, 40)
	flame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(flame)
	dread_label = game._label("", 32, Color(0.56, 0.85, 1.0))
	row.add_child(dread_label)
	day_label = game._label("", 16, GOLD)
	info.add_child(day_label)
	clock_bar = game._bar(Color(1.0, 0.75, 0.35), 220, 6)
	info.add_child(clock_bar)

	objective_label = game._label("", 16, TEXT)
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	game._anchor(objective_label, 1, 0, 1, 0, -460, 14, -16, 90)
	hud.add_child(objective_label)

	boss_box = VBoxContainer.new()
	game._anchor(boss_box, 0.5, 0, 0.5, 0, -240, 14, 240, 70)
	hud.add_child(boss_box)
	boss_name = game._label("", 22, GOLD)
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_box.add_child(boss_name)
	boss_bar = game._bar(Color(0.85, 0.5, 0.3), 480, 12)
	boss_box.add_child(boss_bar)
	boss_box.visible = false

	var bottom := VBoxContainer.new()
	game._anchor(bottom, 0.5, 1.0, 0.5, 1.0, -290, -196, 290, -4)
	bottom.add_theme_constant_override("separation", 6)
	hud.add_child(bottom)
	weapon_label = game._label("", 16, TEXT)
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(weapon_label)
	will_label = game._label("", 16, Color(0.9, 0.2, 0.18))
	will_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(will_label)
	will_bar = game._bar(Color(0.7, 0.08, 0.1), 500, 12)
	bottom.add_child(will_bar)
	hotbar = HotbarScript.new()
	hotbar.boss = walker
	bottom.add_child(hotbar)

	for r in [Rect2(-1, -7, 2, 14), Rect2(-7, -1, 14, 2)]:
		var c := ColorRect.new()
		c.color = Color(1, 0.9, 0.8, 0.7)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		game._anchor(c, 0.5, 0.5, 0.5, 0.5, r.position.x, r.position.y, r.end.x, r.end.y)
		hud.add_child(c)
	prompt_label = game._label("", 16, Color(1.0, 0.9, 0.6))
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game._anchor(prompt_label, 0.5, 0.5, 0.5, 0.5, -300, 26, 300, 50)
	hud.add_child(prompt_label)

	var msg := VBoxContainer.new()
	game._anchor(msg, 0, 0.2, 1, 0.2, 0, 0, 0, 120)
	hud.add_child(msg)
	toast = game._label("", 40, GOLD)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_child(toast)
	toast_sub = game._label("", 16, TEXT)
	toast_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_sub.custom_minimum_size = Vector2(800, 0)
	toast_sub.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	msg.add_child(toast_sub)
	msg.modulate.a = 0.0


func show_toast(main: String, sub: String = "", duration: float = 3.0) -> void:
	toast.text = main
	toast_sub.text = sub
	var box: Control = toast.get_parent()
	if toast_tween:
		toast_tween.kill()
	toast_tween = create_tween()
	box.modulate.a = 1.0
	toast_tween.tween_interval(duration)
	toast_tween.tween_property(box, "modulate:a", 0.0, 0.6)


## A person says something out loud: a speech line over their head.
func say(n: Node3D, text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = UiArt.pixel_font()
	l.font_size = 32
	l.pixel_size = 0.0011
	l.fixed_size = true
	l.outline_size = 8
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Color(1.0, 0.95, 0.85)
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.position = Vector3(0, 2.4, 0)
	n.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(2.4)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func _objective_text() -> String:
	if dusk_state != "":
		return "DUSK · SOMEONE IS COMING FOR YOU"
	if GameState.is_final_night():
		return "THE LAST DAY · NO BOSS WALKS VAEL TODAY\nMAKE YOUR PEACE. AT DUSK, HE COMES."
	var d := _boss_data()
	if d.is_empty():
		return ""
	if GameState.day_boss_slain:
		return "DEED DONE · %s IS SLAIN\nWALK THE CITY UNTIL DUSK" % d["name"]
	var to: Vector3 = LAIRS[d["lair"]] - walker.position
	return "TODAY: %s\n%s · %dM %s" % [d["name"], LAIR_NAMES[d["lair"]], int(Vector2(to.x, to.z).length()), _compass(to)]


func _compass(v: Vector3) -> String:
	var a := atan2(v.x, -v.z)
	var names := ["NORTH", "NORTHEAST", "EAST", "SOUTHEAST", "SOUTH", "SOUTHWEST", "WEST", "NORTHWEST"]
	return names[posmod(roundi(a / (TAU / 8.0)), 8)]


func _update_hud() -> void:
	dread_label.text = "%d" % int(GameState.dread)
	var dt := GameState.day_time
	var phase := "MORNING" if dt < 0.3 else ("NOON" if dt < 0.5 else ("AFTERNOON" if dt < 0.75 else ("EVENING" if dt < 1.0 else "DUSK")))
	day_label.text = "DAY %d · %s" % [day, phase]
	clock_bar.value = clampf(dt, 0.0, 1.0)
	will_bar.value = will / maxf(1.0, will_max)
	will_label.text = "YOUR WILL  %d / %d" % [int(ceil(will)), int(will_max)]
	var W := _weapon()
	weapon_label.text = "%s%s · LMB SWING · Q CAST · RMB PARRY" % [str(W["name"]).to_upper(), (" +%d" % GameState.weapon_tune) if GameState.weapon_tune > 0 else ""]
	objective_label.text = _objective_text()
	if is_instance_valid(engaged) and not engaged.dead:
		boss_bar.value = engaged.hp / engaged.max_hp


# =============================================================================
# Autoplay: walk out to today's boss and fight it (and anything on the way)
# =============================================================================

func _autoplay(delta: float) -> void:
	walker.sprint = true
	if OS.get_cmdline_user_args().has("--trace-bot") and int(t * 2.0) != int((t - delta) * 2.0):
		print("[BOT] t=%.1f pos=%s state=%s foes=%d" % [t, walker.position.snapped(Vector3.ONE * 0.1), dusk_state, enemies.size()])
	if dusk_state == "met":
		walker.move_input = Vector2.ZERO
		return
	if dusk_state == "walking":
		walker.move_input = Vector2.ZERO
		walker.look_toward(stranger.global_position + Vector3(0, 1.6, 0), delta)
		return
	# Parry anything about to land.
	for e in enemies:
		if is_instance_valid(e) and not e.dead and e.state == "windup" and e.windup_ticks - e.state_ticks <= 1:
			if Vector2(e.position.x - walker.position.x, e.position.z - walker.position.z).length() < e.reach + 0.8:
				walker.try_parry()
	for b in bolts:
		if b["arrived"]:
			walker.try_parry()
	var foe = nearest_enemy(walker.head.global_position, 9.0)
	var goal: Vector3
	if foe != null:
		goal = foe.position
	elif is_instance_valid(day_boss) and not day_boss.dead:
		goal = day_boss.position
	else:
		goal = Vector3(0, 0, 6)
	if foe != null:
		var to := Vector3(foe.position.x - walker.position.x, 0, foe.position.z - walker.position.z)
		walker.look_toward(foe.center(), delta)
		var reach := float(_weapon()["reach"])
		walker.move_input = Vector2(0, 1.0 if to.length() > reach * 0.8 else -0.3)
		if to.length() < reach + 0.3:
			swing_queued = true
		bot_t -= delta
		if bot_t <= 0.0:
			bot_t = 0.8
			var id: String = GameState.loadout.pick_random()
			walker.select(GameState.loadout.find(id))
			walker.try_cast(id)
		return
	var wp := _bot_waypoint(goal)
	var dir := Vector3(wp.x - walker.position.x, 0, wp.z - walker.position.z)
	if dir.length() < 1.0:
		walker.move_input = Vector2.ZERO
		return
	walker.look_toward(walker.head.global_position + dir.normalized() * 5.0, delta)
	walker.move_input = Vector2(bot_side, 1.0)
	# Unstick: if barely moving, sidestep for a moment.
	bot_stuck_t += delta
	bot_side_t = maxf(0.0, bot_side_t - delta)
	if bot_side_t <= 0.0:
		bot_side = 0.0
	if bot_stuck_t > 1.5:
		if walker.position.distance_to(bot_last) < 1.0:
			bot_side = -1.0 if randf() < 0.5 else 1.0
			bot_side_t = 0.8
		bot_last = walker.position
		bot_stuck_t = 0.0


## The next point to walk to on the way to `goal`: out along the avenues, through a gate, and
## around the walls if they are in the way.
func _bot_waypoint(goal: Vector3) -> Vector3:
	var p: Vector3 = walker.position
	var pin := _inside(p)
	var gin := _inside(goal)
	if pin and gin:
		return goal
	if pin:
		var gate := "south" if goal.z > 40.0 and absf(goal.x) < 20.0 else ("east" if goal.x >= 0.0 else "west")
		var inner: Vector3 = GATES[gate][0]
		var outer: Vector3 = GATES[gate][1]
		if p.distance_to(inner) < 2.0 or (p - inner).dot(outer - inner) > 0.0:
			return outer
		var on_ew := absf(p.z) < 3.5
		var on_ns := absf(p.x) < 3.5
		if not on_ew and not on_ns:
			return Vector3(p.x, 0, 2.5) if absf(p.z) < absf(p.x) else Vector3(2.5, 0, p.z)
		if gate == "south":
			return inner if on_ns else Vector3(2.5, 0, 2.5)
		return inner if on_ew else Vector3(2.5, 0, 2.5)
	if gin:
		# Coming home: make for the nearest gate, then walk in.
		var bg := "east"
		for gk in GATES:
			if p.distance_to(GATES[gk][1]) < p.distance_to(GATES[bg][1]):
				bg = gk
		var o: Vector3 = GATES[bg][1]
		if p.distance_to(o) < 2.5 or ((p - o).dot(GATES[bg][0] - o) > 0.0 and p.distance_to(o) < 14.0):
			return GATES[bg][0]
		goal = GATES[bg][1]
	# Outside: go around the city if it lies between us.
	var mid_hit := false
	for k in range(1, 10):
		var q := p.lerp(goal, k / 10.0)
		if absf(q.x) < WALL + 3.0 and absf(q.z) < WALL + 3.0:
			mid_hit = true
			break
	if not mid_hit:
		return goal
	var best := goal
	var bd := INF
	for c in [Vector3(46, 0, -46), Vector3(46, 0, 46), Vector3(-46, 0, -46), Vector3(-46, 0, 46)]:
		var d: float = p.distance_to(c) + c.distance_to(goal)
		if d < bd and p.distance_to(c) > 2.0:
			bd = d
			best = c
	return best


## A boss skill flying through the streets of Vael.
class Shot extends Node3D:
	var ow
	var id := ""
	var dmg := 10.0
	var dir := Vector3.FORWARD
	var speed := 24.0
	var life := 2.5
	var radius := 0.0
	var homing := 0.0

	func _physics_process(delta: float) -> void:
		life -= delta
		if homing > 0.0:
			var e = ow.nearest_enemy(global_position, 14.0)
			if e != null:
				dir = dir.lerp((e.center() - global_position).normalized(), clampf(homing * delta, 0.0, 1.0)).normalized()
		global_position += dir * speed * delta
		var hit = ow.enemy_near(global_position, 1.0)
		var lp: Vector3 = ow.to_local(global_position)
		if hit != null or life <= 0.0 or lp.y < 0.05 or ow.blocked(lp):
			ow.explode(global_position, id, dmg, radius, hit)
			queue_free()
