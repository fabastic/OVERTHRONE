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
const Swords := preload("res://scripts/swords.gd")
const PixTex := preload("res://scripts/pixtex.gd")
const Side := preload("res://scripts/sidestory.gd")
const CompassScript := preload("res://scripts/ui/compass.gd")
const MapScript := preload("res://scripts/ui/vael_map.gd")
const Parchment := preload("res://scripts/ui/parchment.gd")
const Vox := preload("res://scripts/vox.gd")
const MAP_PX := 256        # the map of Vael is a 256-pixel parchment over the world square
const MAP_WORLD := 100.0   # it covers -100..100 in x and z

const WALL := 38.0
const BOUND := 95.0
const DAY_SECONDS := 300.0
const AUTO_DAY_SECONDS := 70.0
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
var rect_tops := PackedFloat32Array()  # how tall each solid is: low ones you can step or climb onto
var inventory
var water_depth := {}        # Vector2i cell -> metres of water (shallows you can wade, deeps you cannot)
var water_mat: ShaderMaterial
var clouds: Array = []
var story_marker: Node3D
var story_label: Label3D
var ping_t := 0.0
var ping_node: Node3D
var letterbox: Array = []
var chat_asked := {}
const CELL := 2.0
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
var quest_foes: Array = []
var quest_spawned := false
var secret_nodes := {}        # secret id -> prop node
var page_nodes := {}          # page index -> prop node
var crier: Node3D
var crier_t := 8.0
var crier_i := 0
var ambushes := {}            # which of today's ambushes have happened
var stump_sword: Node3D
var map_labels: Array = []     # [position, name] for the map
var minimap
var big_map: Control
var map_open := false
var map_footer: Label
var sea_rects := {}            # collision rects that are water (the map does not ink them as walls)
var _clears: Array = []
var map_seed := -1             # chosen in _pick_seed: the parchment whose stains suit the land best

# HUD
var hud_layer: CanvasLayer
var hud: Control
var dread_label: Label
var day_label: Label
var clock_bar: ProgressBar
var will_bar: ProgressBar
var will_label: Label
var prompt_label: Label
var toast: Label
var toast_sub: Label
var toast_tween: Tween
var boss_box: VBoxContainer
var boss_name: Label
var boss_bar: ProgressBar
var boss_hp_label: Label
var crowns_label: Label
var tracker: RichTextLabel
var swing_bar: ProgressBar
var beat: ColorRect
var prompt_box: PanelContainer
var toast_box: PanelContainer
var compass
var hurt_overlay: ColorRect
var hotbar

# Autoplay
var bot_t := 0.0
var bot_inventory_done := false
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
	_build_island()
	_build_walls()
	_build_city()
	_build_outside()
	_build_lairs()
	_build_tech()
	_build_people()
	map_labels.append([Vector3(-18, 0, -22), "CLOCKTOWER"])
	map_labels.append([Vector3(-24, 0, -12), "THE FORGE"])
	map_labels.append([Vector3(26, 0, 24), "STABLES"])
	map_labels.append([Vector3(0, 0, 0), "FOUNTAIN"])
	_build_chests()
	_build_swords()
	_build_secrets()
	# Everything else that is a plain flat colour gets a pixel grain (people and foes are drawn their own way)
	_build_horizon()
	var skip: Array = npcs.values() + townsfolk + [crier]
	PixTex.pixelize(self, skip, 1.0)
	_build_clouds()
	walker = BossScript.new()
	walker.walker = true
	walker.ow = self
	walker.game = game
	add_child(walker)
	walker.cam.current = false
	walker.cam.far = 420.0  # far enough for the mountains on the horizon
	walker.right_hand.scale = Vector3.ONE * 1.25  # smaller on foot than on the throne
	walker.left_hand.scale = Vector3.ONE * 1.25
	stranger = StrangerScript.new()
	add_child(stranger)
	stranger.visible = false
	_build_hud()
	_build_story_marker()
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
	bot_inventory_done = false
	if day == 1:
		opened.clear()
	GameState.day_time = 0.0
	dusk_state = ""
	map_open = false
	big_map.visible = false
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
	quest_foes.clear()
	quest_spawned = false
	ambushes.clear()
	crier_t = 6.0
	crier_i = 0
	if GameState.autoplay and _quest() != {} and GameState.quest_state == "":
		GameState.quest_state = "active"  # the bot always says yes to Edda
	_refresh_props()
	for id in npcs:
		npcs[id].visible = true
	_update_sky()
	var tod := "DAY %d" % day
	show_toast(tod + (" · THE LAST DAY" if GameState.is_final_night() else ""), _objective_text(), 4.0)
	game.tutorial("day", "This is Vael, by day. WASD walk, SHIFT runs. LMB swings your blade on the beat, Q casts your selected skill, RMB parries, E talks and opens. At DUSK, someone will come for you.", false, 10.0)


func _day_length() -> float:
	return AUTO_DAY_SECONDS if GameState.autoplay else DAY_SECONDS


func busy() -> bool:
	return not active or map_open or is_instance_valid(game.overlay) or get_tree().paused


## Recolour what the theme cannot reach (the toast title) when the King's purity changes.
func refresh_theme() -> void:
	if toast:
		toast.add_theme_color_override("font_color", game.title_color())


## The full map: the world holds still while you read it.
func _toggle_map() -> void:
	map_open = not map_open
	big_map.visible = map_open
	Sfx.play("click", -4.0, 0.7 if map_open else 0.9)
	game.tutorial("map", "The map of Vael. Red X: today's boss. Gold star: the Lamplighter's errand. Violet diamonds: secrets you have found.")


func _process(delta: float) -> void:
	if not active:
		return
	t += delta
	_update_hud()
	_update_floaters(delta)
	for c in clouds:
		c.position.x += delta * 1.6
		if c.position.x > 280.0:
			c.position.x = -280.0
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
	_update_story_marker(delta)
	_update_quest()
	_update_crier(delta)
	_update_ambush()
	# Input
	if GameState.autoplay:
		_autoplay(delta)
	elif dusk_state == "walking":
		_cutscene_walk(delta)
	elif dusk_state == "":
		walker.move_input = Input.get_vector("move_left", "move_right", "move_back", "move_forward")
		walker.sprint = Input.is_action_pressed("sprint")
		walker.crouch = Input.is_action_pressed("crouch")
		walker.jump_held = Input.is_action_pressed("jump")
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
	_separate()
	_find_interact()
	var floor_a := 0.0
	if will_max > 0.0 and will / will_max < 0.3:
		floor_a = 0.18 + 0.14 * maxf(0.0, sin(t * 8.0))
	hurt_overlay.color.a = maxf(floor_a, move_toward(hurt_overlay.color.a, 0.0, delta * 1.2))


## Vael lives inside the pixelating SubViewport, whose container ignores the mouse, so main.gd
## forwards every input event here while the day is active (see main._input).
func handle_input(event: InputEvent) -> void:
	if active and map_open and event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.is_action_pressed("map")):
		_toggle_map()
		get_viewport().set_input_as_handled()
		return
	if busy() or dusk_state != "":
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		walker.look(event.screen_relative)
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		game._capture_mouse()
		return
	if event.is_action_pressed("day_swing"):
		swing_queued = true
	elif event.is_action_pressed("parry"):
		walker.try_parry()
	elif event.is_action_pressed("day_cast"):
		walker.try_cast(walker.selected_id())
	elif event.is_action_pressed("jump"):
		walker.try_jump()
	elif event.is_action_pressed("dodge"):
		walker.try_dodge()
	elif event.is_action_pressed("interact"):
		_interact()
	elif event.is_action_pressed("map"):
		_toggle_map()
	elif event.is_action_pressed("inventory"):
		open_inventory()
	elif event.is_action_pressed("throne"):
		game.open_throne_from_day()
	elif event.is_action_pressed("ping"):
		ping_story()
	elif event.is_action_pressed("skill_prev"):
		walker.cycle(-1)
	elif event.is_action_pressed("skill_next"):
		walker.cycle(1)
	else:
		for k in 5:
			if event.is_action_pressed("skill_%d" % (k + 1)):
				walker.select(k)


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
	walker.start_swing(Swords.swing_style(GameState.weapon), clampf(int(W["ticks"]) * GameState.TICK * 0.9, 0.3, 1.0))
	Sfx.play(Swords.swing_sound(GameState.weapon), -3.0, randf_range(0.9, 1.1))
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
	Sfx.play("cast", -12.0, randf_range(0.8, 1.3))
	Sfx.cast_school(GameState.SKILLS[id]["school"])
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
	if walker.is_dodging():
		game.popup_text(walker.head.global_position + Vector3(0, 0.2, -1.2), "DODGED", Color(0.7, 0.95, 1.0), 1.0)
		Sfx.play("dodge", -6.0)
		return
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
		hurt_overlay.color.a = maxf(hurt_overlay.color.a, 0.45 + 0.5 * clampf(dmg / maxf(1.0, will_max) * 6.0, 0.0, 1.0))
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
	if e.elite:
		show_toast(e.display_name, "Of the Crownless. The empty crown on its mask glows when it looks at you.", 3.0)
		Sfx.play("learn", -6.0, 1.0)
		return
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
	if quest_foes.has(e):
		quest_foes.erase(e)
		GameState.add_dread(10.0 + 4.0 * day + (30.0 if e.elite else 0.0))
		if quest_foes.is_empty() and GameState.quest_state == "active":
			_quest_won()
		return
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
	# He steps into view AHEAD of you: somewhere in your vision cone with a clear line to you.
	var fwd := Vector3(-sin(walker.yaw), 0, -cos(walker.yaw))
	var p: Vector3 = walker.position + fwd * 10.0
	var found := false
	for dist in [11.0, 9.0, 13.0, 7.0]:
		for off in [0.0, 0.25, -0.25, 0.5, -0.5]:
			var cand: Vector3 = walker.position + fwd.rotated(Vector3.UP, off) * dist
			if not blocked(cand) and water_depth_at(cand) <= 0.0 and _clear_line(cand, walker.position):
				p = cand
				found = true
				break
		if found:
			break
	if not found:
		var a0 := randf() * TAU
		for k in 12:
			var a := a0 + TAU * k / 12.0
			var cand2: Vector3 = walker.position + Vector3(cos(a), 0, sin(a)) * 9.0
			if _clear_line(cand2, walker.position):
				p = cand2
				break
	_letterbox(true)
	chat_asked = {}
	var ring := Fx.particles(Color(1.0, 0.95, 0.85), 30, 1.2, 1.2, 0.05, true)
	add_child(ring)
	ring.global_position = p + Vector3(0, 1.0, 0)
	stranger.position = p
	stranger_last = p
	stranger_stuck_t = 0.0
	stranger.refresh()
	stranger.visible = true
	stranger.walking = false
	stranger.rotation.y = atan2(walker.position.x - p.x, walker.position.z - p.z) + PI
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
	# He waits, watching you come (he takes a step or two himself near the end).
	var to := Vector3(walker.position.x - stranger.position.x, 0, walker.position.z - stranger.position.z)
	var d := to.length()
	stranger.rotation.y = lerp_angle(stranger.rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-delta * 4.0))
	stranger.walking = d > 2.6 and d < 5.0
	if stranger.walking:
		stranger.position = resolve(stranger.position, stranger.position + to.normalized() * 0.9 * delta, 0.4)
	if d > 2.4:
		return
	stranger.walking = false
	dusk_state = "met"
	walker.move_input = Vector2.ZERO
	get_tree().create_timer(0.4, false).timeout.connect(_stranger_chat)


## The dusk cutscene: you walk slowly toward him, your eyes drawn to his face.
func _cutscene_walk(delta: float) -> void:
	var head_p: Vector3 = stranger.global_position + Vector3(0, 1.62, 0)
	walker.look_toward(head_p, delta * 0.6)
	var to := Vector3(stranger.position.x - walker.position.x, 0, stranger.position.z - walker.position.z)
	var ang := absf(wrapf(atan2(-to.x, -to.z) - walker.yaw, -PI, PI))
	walker.sprint = false
	walker.crouch = false
	walker.move_input = Vector2(0, 0.42 if ang < 0.5 else 0.0)


## He talks to you: tonight's line, two questions you can ask him, then the game.
func _stranger_chat() -> void:
	if dusk_state != "met":
		return
	game.dialogue_speaker = stranger
	game._release_mouse()
	var n := clampi(GameState.level - 1, 0, Dialogue.STRANGER_NIGHT.size() - 1)
	var line: Array = Dialogue.STRANGER_NIGHT[n]
	var chat: Array = Dialogue.STRANGER_CHAT[n]
	var name := "YOURSELF" if GameState.revealed else "THE STRANGER"
	var body: String = str(line[1]) if chat_asked.is_empty() else "\"Anything else?\""
	var opts: Array = []
	for k in chat.size() - 1:
		if not chat_asked.has(k):
			opts.append([chat[k][0], _stranger_answer.bind(k)])
	opts.append([chat[chat.size() - 1], _stranger_done])
	game._show_choice(name, body, "", opts)


func _stranger_answer(k: int) -> void:
	chat_asked[k] = true
	var n := clampi(GameState.level - 1, 0, Dialogue.STRANGER_CHAT.size() - 1)
	var chat: Array = Dialogue.STRANGER_CHAT[n]
	game._show_choice("YOURSELF" if GameState.revealed else "THE STRANGER", str(chat[k][1]), "", [["...", _stranger_chat]])


func _stranger_done() -> void:
	game.dialogue_speaker = null
	game._clear_overlay()
	_letterbox(false)
	dusk_met.emit()


## Cinema bars for the dusk walk.
func _letterbox(on: bool) -> void:
	for b in letterbox:
		var tw: Tween = (b as Control).create_tween()
		if b.get_meta("top"):
			tw.tween_property(b, "offset_bottom", 74.0 if on else 0.0, 0.8)
		else:
			tw.tween_property(b, "offset_top", -74.0 if on else 0.0, 0.8)


# =============================================================================
# The story marker: a gold diamond over the next step of the story; G pings it.
# =============================================================================

func story_target() -> Dictionary:
	if dusk_state != "":
		return {}
	if is_instance_valid(day_boss) and not day_boss.dead:
		return {"pos": day_boss.position, "label": str(_boss_data().get("name", "TODAY'S FOE"))}
	var q := _quest()
	if not q.is_empty() and GameState.quest_state == "active":
		return {"pos": q["where"], "label": "THE LAMPLIGHTER'S ERRAND"}
	if not q.is_empty() and GameState.quest_state == "" and npcs.has("edda"):
		return {"pos": npcs["edda"].position, "label": "EDDA THE LAMPLIGHTER"}
	return {"pos": SPOTS["flagon"], "label": "THE HOLLOW FLAGON · WAIT FOR DUSK"}


func _build_story_marker() -> void:
	story_marker = Node3D.new()
	add_child(story_marker)
	story_label = Label3D.new()
	story_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	story_label.no_depth_test = true
	story_label.fixed_size = true
	story_label.pixel_size = 0.0018
	story_label.font = UiArt.pixel_font()
	story_label.font_size = 32
	story_label.outline_size = 8
	story_label.modulate = Color(1.0, 0.82, 0.35)
	story_label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	story_marker.add_child(story_label)


func _update_story_marker(delta: float) -> void:
	if story_marker == null:
		return
	var tg := story_target()
	ping_t = maxf(0.0, ping_t - delta)
	if tg.is_empty():
		story_marker.visible = false
		return
	var pos: Vector3 = tg["pos"]
	var d := Vector2(pos.x - walker.position.x, pos.z - walker.position.z).length()
	story_marker.visible = d > 6.0
	story_marker.position = pos + Vector3(0, 3.4 + sin(t * 2.5) * 0.15, 0)
	story_label.text = "◆\n%s · %dM" % [str(tg["label"]), int(d)] if ping_t > 0.0 else "◆ %dM" % int(d)
	story_label.pixel_size = 0.0024 if ping_t > 0.0 else 0.0016
	if is_instance_valid(ping_node):
		ping_node.position = Vector3(pos.x, 0, pos.z)


## G: a beam of light and a ring race out from the next story step, seen through walls.
func ping_story() -> void:
	var tg := story_target()
	if tg.is_empty():
		return
	ping_t = 6.0
	Sfx.play("reveal", -8.0, 1.6)
	if is_instance_valid(ping_node):
		ping_node.queue_free()
	ping_node = Node3D.new()
	add_child(ping_node)
	var pos: Vector3 = tg["pos"]
	ping_node.position = Vector3(pos.x, 0, pos.z)
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color(1.0, 0.82, 0.35, 0.45)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.no_depth_test = true
	var beam := Fx.cylinder(0.35, 0.35, 70.0, bm, Vector3(0, 35.0, 0))
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ping_node.add_child(beam)
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.0
	tm.rings = 32
	tm.ring_segments = 4
	var ring := MeshInstance3D.new()
	ring.mesh = tm
	ring.material_override = bm
	ring.position.y = 0.2
	ping_node.add_child(ring)
	var tw := ping_node.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(14, 1, 14), 1.6).set_ease(Tween.EASE_OUT)
	tw.tween_property(bm, "albedo_color:a", 0.0, 6.0).set_delay(1.0)
	tw.chain().tween_callback(ping_node.queue_free)
	show_toast("THE STORY", "%s · %dM %s" % [str(tg["label"]), int(Vector2(pos.x - walker.position.x, pos.z - walker.position.z).length()), _compass(pos - walker.position)], 3.0)


## Points of interest for the map: what is what, and where.
func map_pois() -> Array:
	var out: Array = []
	for ml in map_labels:
		var lbl := str(ml[1])
		var kind := ""
		if "FLAGON" in lbl or "COG" in lbl or "LENS" in lbl or "TAVERN" in lbl:
			kind = "tavern"
		elif "FORGE" in lbl:
			kind = "forge"
		elif "CATHEDRAL" in lbl:
			kind = "church"
		elif "CLOCK" in lbl:
			kind = "clock"
		elif "STABLE" in lbl:
			kind = "stable"
		elif "FOUNTAIN" in lbl:
			kind = "fountain"
		elif "BRIDGE" in lbl:
			kind = "bridge"
		if kind != "":
			out.append({"pos": ml[0], "kind": kind, "label": lbl})
	for g in GATES:
		var gp: Vector3 = (GATES[g][0] + GATES[g][1]) * 0.5
		out.append({"pos": gp, "kind": "gate", "label": "%s GATE" % str(g).to_upper()})
	for id in npcs:
		if is_instance_valid(npcs[id]):
			out.append({"pos": npcs[id].position, "kind": "npc", "label": _npc_name(id).get_slice(",", 0)})
	for c in chests:
		if not opened.has(c["id"]):
			out.append({"pos": c["pos"], "kind": "chest", "label": "CHEST"})
	return out


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
			interact_target = {"kind": "npc", "id": id, "label": "TALK TO " + _npc_name(id)}
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
	for sec in Side.SECRETS:
		var sp: Vector3 = sec["pos"]
		var d4 := Vector2(sp.x - p.x, sp.z - p.z).length()
		if d4 < best and _facing(sp, fwd):
			best = d4
			interact_target = {"kind": "secret", "s": sec, "label": "EXAMINE: " + str(sec["title"])}
	for i in Side.PAGES.size():
		if GameState.pages.has(i):
			continue
		var pp: Vector3 = Side.PAGES[i]["pos"]
		var d5 := Vector2(pp.x - p.x, pp.z - p.z).length()
		if d5 < best and _facing(pp, fwd):
			best = d5
			interact_target = {"kind": "page", "i": i, "label": "PICK UP A TORN PAGE"}
	var dm := Vector2(mirror_pos.x - p.x, mirror_pos.z - p.z).length()
	if dm < best and _facing(mirror_pos, fwd):
		interact_target = {"kind": "mirror", "label": "LOOK INTO THE MIRROR"}
	prompt_label.text = str(interact_target["label"]) if not interact_target.is_empty() else ""


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
		"secret":
			_read_secret(interact_target["s"])
		"page":
			_read_page(interact_target["i"])


func _close_dialogue() -> void:
	game.dialogue_speaker = null
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


func _npc_name(id: String) -> String:
	return str(Side.EDDA["name"]) if id == "edda" else str(Dialogue.NPCS[id]["name"])


func _talk(id: String) -> void:
	if id == "edda":
		_talk_edda()
		return
	var N: Dictionary = Dialogue.NPCS[id]
	var tone := Dialogue.tone()
	if npcs.has(id):
		npcs[id].talk()
		game.dialogue_speaker = npcs[id]
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
	if npcs.has(id):
		game.dialogue_speaker = npcs[id]
		npcs[id].talk()
	game._show_choice(_npc_name(id), text, "", [["Thank them", _close_dialogue], ["Talk more", _talk.bind(id)]])


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
			if not GameState.tune_weapon():
				GameState.dread += cost
				_reply(id, "\"Any more aether in that blade and it'll start thinking for itself.\" (Fully tuned)")
				return
			served[service] = true
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
	if npcs.has("hennik"):
		game.dialogue_speaker = npcs["hennik"]
	var opts: Array = []
	for wid in Dialogue.WEAPONS:
		var W: Dictionary = Dialogue.WEAPONS[wid]
		if int(W["tier"]) > day or GameState.weapons.has(wid) or int(W["cost"]) < 0:
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
	GameState.give_weapon(wid)
	GameState.equip_weapon(wid)
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
		if int(Dialogue.WEAPONS[wid]["cost"]) < 0:
			continue
		if not GameState.weapons.has(wid) and tr > cur_tier and tr <= day + (1 if sealed else 0) and (better == "" or tr > int(Dialogue.WEAPONS[better]["tier"])):
			better = wid
	var r := randf()
	if better != "" and r < (0.5 if sealed else 0.3):
		GameState.give_weapon(better)
		GameState.equip_weapon(better)
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

## A solid footprint. h = how tall it is: anything under 0.45 you step over, anything up to about
## 2.3 you can jump and climb onto (crates, stalls, the fountain rim, low walls), taller blocks you.
func _solid(c: Vector2, size: Vector2, h: float = 99.0) -> void:
	rects.append(Rect2(c - size * 0.5, size))
	rect_tops.append(h)


func blocked(lp: Vector3) -> bool:
	if absf(lp.x) > BOUND or absf(lp.z) > BOUND:
		return true
	for i in rects.size():
		if rect_tops[i] > lp.y + 0.45 and rects[i].has_point(Vector2(lp.x, lp.z)):
			return true
	return false


## The height you stand at here: the top of a low solid under you, else the ground.
func ground_at(p: Vector3, r: float) -> float:
	var g := 0.0
	for i in rects.size():
		var top := rect_tops[i]
		if top <= p.y + 0.45 and top > g and rects[i].grow(r * 0.5).has_point(Vector2(p.x, p.z)):
			g = top
	return g


## A ledge just in front of you that you could climb: its top, or -1.
func ledge_top(p: Vector3, fwd: Vector3) -> float:
	var q := Vector2(p.x + fwd.x * 0.7, p.z + fwd.z * 0.7)
	var best := -1.0
	for i in rects.size():
		var top := rect_tops[i]
		if top > p.y + 0.3 and top <= p.y + 2.35 and rects[i].has_point(q):
			best = maxf(best, top)
	if best < 0.0:
		return -1.0
	# Nothing taller standing right where you would land
	for i in rects.size():
		if rect_tops[i] > best + 0.45 and rects[i].has_point(q):
			return -1.0
	return best


## Slide a body of radius r from `from` toward `to`, pushed out of every solid rectangle taller
## than it can step (y = the body's feet; people and foes walk at 0, you can stand on things).
func resolve(from: Vector3, to: Vector3, r: float, y: float = 0.0) -> Vector3:
	var p := to
	p.x = clampf(p.x, -BOUND, BOUND)
	p.z = clampf(p.z, -BOUND, BOUND)
	for pass_i in 2:
		for i in rects.size():
			if rect_tops[i] <= y + 0.45:
				continue
			var rc := rects[i]
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


## Bodies never stand inside each other: people, foes, the Stranger and you push apart, then
## anyone pushed is slid back out of buildings and props.
func _separate() -> void:
	var bodies: Array = []
	for n in npcs.values():
		if is_instance_valid(n):
			bodies.append([n, 0.38, 1.0])
	for n in townsfolk:
		if is_instance_valid(n):
			bodies.append([n, 0.36, 1.0])
	for e in enemies:
		if is_instance_valid(e) and not e.dead:
			bodies.append([e, 0.45 * e.scale.x, 0.6 if e.is_boss else 1.0])
	if is_instance_valid(stranger) and stranger.visible:
		bodies.append([stranger, 0.4, 0.3])
	bodies.append([walker, 0.42, 0.0])
	var moved := {}
	for i in bodies.size():
		var a: Array = bodies[i]
		var na: Node3D = a[0]
		for j in range(i + 1, bodies.size()):
			var b: Array = bodies[j]
			var nb: Node3D = b[0]
			var d := Vector2(nb.position.x - na.position.x, nb.position.z - na.position.z)
			var min_d: float = a[1] + b[1]
			var dl := d.length()
			if dl >= min_d:
				continue
			if dl < 0.001:
				d = Vector2(randf_range(-1, 1), randf_range(-1, 1))
				dl = d.length()
			var push := d / dl * (min_d - dl)
			var wa: float = a[2]
			var wb: float = b[2]
			var tot := maxf(0.001, wa + wb)
			if wa > 0.0:
				na.position -= Vector3(push.x, 0, push.y) * (wa / tot)
				moved[na] = a[1]
			if wb > 0.0:
				nb.position += Vector3(push.x, 0, push.y) * (wb / tot)
				moved[nb] = b[1]
	for n in moved:
		if n != walker:
			n.position = resolve(n.position, n.position, moved[n])


## The inventory of blades (I): equip one, or upgrade it with Crowns.
func open_inventory() -> void:
	if busy() or dusk_state != "":
		return
	var inv = load("res://scripts/ui/inventory.gd").new()
	inv.ow = self
	inv.theme = game.theme_res
	game.overlay_layer.add_child(inv)
	game.overlay = inv
	game._release_mouse()
	inv.closed.connect(func():
		game.overlay = null
		_build_weapon()
		game._capture_mouse())


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
	e.fog_density = 0.0032
	e.fog_sky_affect = 0.25
	e.fog_aerial_perspective = 0.55     # far things take the sky's colour: depth
	e.fog_height = 1.2                  # a low mist that pools in the hollows and over water
	e.fog_height_density = 0.05
	e.ssao_enabled = true               # contact shadows in every corner and under every voxel
	e.ssao_radius = 1.4
	e.ssao_intensity = 2.4
	e.ssao_detail = 0.6
	e.ssil_enabled = false
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
	if water_mat:
		water_mat.set_shader_parameter("tint", 0.45 + 0.55 * sin(dt * PI) if dusk_state == "" else 0.4)
	env.fog_height_density = 0.06 * (1.0 - sin(dt * PI)) + 0.015  # morning and evening mist
	sun.rotation_degrees = Vector3(-lerpf(12.0, 168.0, dt), 35.0, 0.0)
	var warm := Color(1.0, 0.72, 0.5)
	sun.light_color = warm.lerp(Color(1.0, 0.96, 0.9), sin(dt * PI))
	sun.light_energy = 0.35 + 0.85 * sin(dt * PI) if dusk_state == "" else 0.2
	env.ambient_light_energy = 0.35 + 0.35 * sin(dt * PI)


# =============================================================================
# Building Vael
# =============================================================================

# =============================================================================
# The island: the map's dark stains are Vael's sea and lakes, its light paper the land
# =============================================================================

func world_px(p: Vector3) -> Vector2:
	return Vector2((p.x + MAP_WORLD) / (2.0 * MAP_WORLD) * MAP_PX, (p.z + MAP_WORLD) / (2.0 * MAP_WORLD) * MAP_PX)


## Places that must stay dry (in map pixels): the city, the lairs, the roads, everything you can visit.
func island_clears() -> Array:
	if not _clears.is_empty():
		return _clears
	var k := MAP_PX / (2.0 * MAP_WORLD)
	var add := func(p: Vector3, r: float): _clears.append([world_px(p), r * k])
	# The walled city (a ring of dry ground around its square)
	add.call(Vector3.ZERO, 50.0)
	for cx in [-1.0, 0.0, 1.0]:
		for cz in [-1.0, 0.0, 1.0]:
			if cx != 0.0 or cz != 0.0:
				add.call(Vector3(cx * 40.0, 0, cz * 40.0), 13.0)
	for lk in LAIRS:
		add.call(LAIRS[lk], 15.0)
	add.call(Vector3(-60, 0, 15), 12.0)
	for seg in _roads():
		var a: Vector3 = seg[0]
		var b: Vector3 = seg[1]
		var n := int(a.distance_to(b) / 5.0) + 1
		for i in n + 1:
			add.call(a.lerp(b, float(i) / n), 5.5)
	for sec in Side.SECRETS:
		add.call(sec["pos"], 5.0)
	for pg in Side.PAGES:
		add.call(pg["pos"], 5.0)
	for q in Side.QUEST:
		add.call(q["where"], 10.0)
	for c in [Vector3(-33, 0, -33), Vector3(33, 0, 33), Vector3(-3, 0, -35), Vector3(-26, 0, 6), Vector3(70, 0, -32), Vector3(-70, 0, -30),
			Vector3(6, 0, 66), Vector3(-56, 0, 55), Vector3(55, 0, 52), Vector3(8, 0, -86), Vector3(-64, 0, 20)]:
		add.call(c, 7.0)
	add.call(Vector3(0, 0, 72), 8.0)  # the bridge
	return _clears


## Choose the parchment whose stains suit Vael: plenty of water (about 38% of the land) but none
## of it drowning the city or a lair before the dry zones are even applied. Deterministic.
func _pick_seed() -> int:
	var best := 7
	var best_score := INF
	var keys: Array[Vector3] = [Vector3.ZERO, Vector3(30, 0, 30), Vector3(-30, 0, 30), Vector3(30, 0, -30), Vector3(-30, 0, -30)]
	for lk in LAIRS:
		keys.append(LAIRS[lk])
	for sd in range(1, 61):
		var score := 0.0
		for kp in keys:
			var px := world_px(kp)
			score += maxf(0.0, Parchment.wetness(px.x, px.y, MAP_PX, sd, true) + 0.05) * 10.0
		var wet := 0
		for gz in 20:
			for gx in 20:
				if Parchment.wetness((gx + 0.5) * MAP_PX / 20.0, (gz + 0.5) * MAP_PX / 20.0, MAP_PX, sd, true) > Parchment.WET:
					wet += 1
		score += absf(wet / 400.0 - 0.38) * 8.0
		if score < best_score:
			best_score = score
			best = sd
	print("[ISLAND] parchment seed %d (score %.2f)" % [best, best_score])
	return best


func wet_at(p: Vector3) -> float:
	var px := world_px(p)
	if map_seed < 0:
		map_seed = _pick_seed()
	return Parchment.wetness(px.x, px.y, MAP_PX, map_seed, true, Parchment.clear_field(MAP_PX, island_clears()))


## The island, built from 2 m voxel columns: grass and sand land at the surface, and wherever the
## map is wet the seabed steps down with depth (shallows near the shore, deeps further out).
## One water surface lies just under the land; the water shader colours it by real depth.
## Shallows (under 0.9 m) can be waded; deeper water is a wall.
func _build_island() -> void:
	var cell := CELL
	var sand := PixTex.mat(PixTex.ground(Color(0.8, 0.7, 0.48), "sand", 15), 2.0)
	var grass := PixTex.mat(PixTex.ground(Color(0.3, 0.48, 0.2), "grass"), 2.0)
	var silt := PixTex.mat(PixTex.ground(Color(0.42, 0.4, 0.3), "dirt", 16), 2.0)
	var rockbed := PixTex.mat(PixTex.cobbles(Color(0.3, 0.32, 0.34), 17), 2.0)
	var dirt := PixTex.mat(PixTex.ground(Color(0.5, 0.38, 0.24), "dirt"), 2.0)
	var lists := {"grass": [], "sand": [], "dirt": [], "shallow": [], "silt": [], "rock": []}
	var roads := _roads()
	var n := int(2.0 * MAP_WORLD / cell)
	var deep_cells := 0
	for iz in n:
		var run_start := -1
		for ix in n + 1:
			var deep := false
			if ix < n:
				var p := Vector3(-MAP_WORLD + (ix + 0.5) * cell, 0, -MAP_WORLD + (iz + 0.5) * cell)
				var w := wet_at(p)
				var river := absf(p.z - 72.0) < 4.0
				if w > Parchment.WET or river:
					var d := 1.6 if river else 0.35 + clampf((w - Parchment.WET) / 0.22, 0.0, 1.0) * 2.8
					d = snappedf(d, 0.25)
					water_depth[Vector2i(ix, iz)] = d
					var kind := "shallow" if d < 1.0 else ("silt" if d < 2.2 else "rock")
					lists[kind].append(p - Vector3(0, d, 0))
					deep = true  # nobody wades in Vael: every water cell is a wall
					if deep:
						deep_cells += 1
				else:
					var on_road := false
					for seg in roads:
						if _seg_dist(p, seg[0], seg[1]) < 1.8:
							on_road = true
							break
					if on_road:
						lists["dirt"].append(p)
					elif w > Parchment.SHORE:
						lists["sand"].append(p)
					else:
						lists["grass"].append(p)
			# Merge runs of deep water along the row into one solid rectangle (the river has its own)
			if deep and run_start < 0:
				run_start = ix
			elif not deep and run_start >= 0:
				var x0 := -MAP_WORLD + run_start * cell
				var rect := Rect2(Vector2(x0 + 0.3, -MAP_WORLD + iz * cell), Vector2((ix - run_start) * cell - 0.6, cell))
				if absf(rect.get_center().y - 72.0) > 4.5:
					rects.append(rect)
					rect_tops.append(99.0)
					sea_rects[rect] = true
				run_start = -1
	var mats := {"grass": grass, "sand": sand, "dirt": dirt, "shallow": sand, "silt": silt, "rock": rockbed}
	for kind in lists:
		var cells: Array = lists[kind]
		if cells.is_empty():
			continue
		# Each column is a 2 m box whose top is the surface: the sides fill the step down to the bed.
		var bm := BoxMesh.new()
		bm.size = Vector3(cell, 3.0, cell)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = bm
		mm.instance_count = cells.size()
		for i in cells.size():
			mm.set_instance_transform(i, Transform3D(Basis(), cells[i] + Vector3(0, -1.5, 0)))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mats[kind]
		add_child(mmi)
	# The water surface: the whole map and out to the horizon, just below the land
	water_mat = ShaderMaterial.new()
	water_mat.shader = load("res://scripts/water.gdshader")
	var wp := PlaneMesh.new()
	wp.size = Vector2(900, 900)
	wp.subdivide_width = 0
	var wmi := MeshInstance3D.new()
	wmi.mesh = wp
	wmi.material_override = water_mat
	wmi.position = Vector3(0, -0.14, 0)
	wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wmi)
	# Beyond the island the seabed falls away into the open sea
	var deep_floor := Fx.box(Vector3(900, 1.0, 900), Fx.mat(Color(0.08, 0.12, 0.16)), Vector3(0, -6.0, 0))
	add_child(deep_floor)
	print("[ISLAND] %d water cells (%d deep), %d shore cells" % [water_depth.size(), deep_cells, (lists["sand"] as Array).size()])


## Metres of water here (0 on land).
func water_depth_at(p: Vector3) -> float:
	var ix := int(floor((p.x + MAP_WORLD) / CELL))
	var iz := int(floor((p.z + MAP_WORLD) / CELL))
	return water_depth.get(Vector2i(ix, iz), 0.0)


## Mountains ringing the island, stepped like everything else, fading blue into the distance.
func _build_horizon() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var rock := PixTex.mat(PixTex.cobbles(Color(0.42, 0.44, 0.5), 31), 6.0)
	var dark_rock := PixTex.mat(PixTex.cobbles(Color(0.3, 0.32, 0.38), 32), 6.0)
	var snow := PixTex.mat(PixTex.plaster(Color(0.92, 0.94, 0.98), 33), 6.0)
	for k in 30:
		var a := TAU * k / 30.0 + rng.randf_range(-0.08, 0.08)
		var dist := rng.randf_range(170.0, 240.0)
		var base := Vector3(cos(a) * dist, -2.0, sin(a) * dist)
		var h := rng.randf_range(35.0, 80.0)
		var w := rng.randf_range(40.0, 70.0)
		var tiers := 5
		for t2 in tiers:
			var f := 1.0 - float(t2) / tiers
			var th := h / tiers
			var m: Material = snow if t2 >= tiers - 1 and h > 50.0 else (rock if t2 % 2 == 0 else dark_rock)
			var b := Fx.box(Vector3(w * f, th, w * f * rng.randf_range(0.7, 1.0)), m, base + Vector3(rng.randf_range(-3, 3), th * (t2 + 0.5), rng.randf_range(-3, 3)))
			b.rotation.y = rng.randf() * PI
			b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(b)


## Slow pixel clouds high over Vael.
func _build_clouds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 505
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.albedo_color = Color(1, 1, 1, 0.75)
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for k in 16:
		var c := Node3D.new()
		c.position = Vector3(rng.randf_range(-260, 260), rng.randf_range(55, 85), rng.randf_range(-260, 260))
		for j in 4:
			var b := Fx.box(Vector3(rng.randf_range(14, 30), rng.randf_range(3, 6), rng.randf_range(10, 22)), cm,
				Vector3(rng.randf_range(-12, 12), rng.randf_range(-1, 2), rng.randf_range(-8, 8)))
			b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			c.add_child(b)
		add_child(c)
		clouds.append(c)


func _build_ground() -> void:
	var cobble := PixTex.mat(PixTex.cobbles(Color(0.5, 0.47, 0.43)), 2.4)
	var cm := PlaneMesh.new()
	cm.size = Vector2(WALL * 2.0, WALL * 2.0)
	var c := MeshInstance3D.new()
	c.mesh = cm
	c.material_override = cobble
	c.position.y = 0.01
	add_child(c)
	# Dirt roads to every lair (and around the walls to the Dawnspire)
	# (Dirt roads are painted onto the 2 m grid in _build_island, so they line up with the land.)
	# The river and its bridge
	_solid(Vector2(-49.5, 72), Vector2(93, 8))
	_solid(Vector2(49.5, 72), Vector2(93, 8))
	_build_old_bridge()


## THE OLD BRIDGE, where Ser Corvin was ordered to hold to the last man and led his company
## home instead. The far span fell the next spring and was never rebuilt: the near span ends in a
## broken edge over the river, rubble in the water below, a stub on the far bank. A plaque at the
## bridgehead tells the story. You can walk out to the broken edge; you cannot cross.
func _build_old_bridge() -> void:
	var stone := PixTex.mat(PixTex.bricks(Color(0.52, 0.5, 0.47), 21), 2.0)
	var mossy := PixTex.mat(PixTex.bricks(Color(0.42, 0.46, 0.38), 22), 2.0)
	# The near span: z 66 -> 73, on the grid
	add_child(Fx.box(Vector3(6, 0.4, 7), stone, Vector3(0, 0.2, 69.5)))
	add_child(Fx.box(Vector3(6.4, 0.9, 1.2), stone, Vector3(0, -0.25, 67.0)))   # the pier on the near bank
	for s in [-1.0, 1.0]:
		add_child(Fx.box(Vector3(0.4, 1.0, 7), stone, Vector3(s * 3.0, 0.7, 69.5)))
		_solid(Vector2(s * 3.1, 69.5), Vector2(0.4, 7), 1.2)
		# Lamp posts at the bridgehead
		add_child(Fx.box(Vector3(0.25, 2.6, 0.25), Fx.mat(Color(0.2, 0.19, 0.2)), Vector3(s * 3.0, 1.5, 66.4)))
		add_child(Fx.box(Vector3(0.4, 0.4, 0.4), Fx.mat(Color(0.5, 0.85, 1.0), 4.0), Vector3(s * 3.0, 2.9, 66.4)))
	_solid(Vector2(0, 69.5), Vector2(5.6, 7.0), 0.42)   # the deck: you walk on it
	# The broken edge: jagged stones, a rail snapped off, rubble half-sunk in the river
	var rng := RandomNumberGenerator.new()
	rng.seed = 72
	for k in 6:
		var w := rng.randf_range(0.6, 1.3)
		add_child(Fx.box(Vector3(w, rng.randf_range(0.3, 0.6), 0.5), stone, Vector3(-2.5 + k * 1.0, 0.15, 73.0 + rng.randf_range(-0.1, 0.25))))
	for k in 7:
		var b := Fx.box(Vector3.ONE * rng.randf_range(0.6, 1.2), mossy, Vector3(rng.randf_range(-3, 3), -0.35, rng.randf_range(73.8, 76.0)))
		b.rotation = Vector3(rng.randf() * 0.6, rng.randf() * PI, rng.randf() * 0.6)
		add_child(b)
	_solid(Vector2(0, 74.7), Vector2(6.4, 3.4))   # no stepping off into the river
	# The stub of the far span on the south bank
	add_child(Fx.box(Vector3(6, 0.4, 2), mossy, Vector3(0, 0.2, 77.0)))
	add_child(Fx.box(Vector3(0.4, 1.0, 1.4), mossy, Vector3(-3.0, 0.7, 77.3)))
	# The plaque
	add_child(Fx.box(Vector3(0.18, 1.1, 0.18), Fx.mat(Color(0.3, 0.2, 0.12)), Vector3(4.2, 0.55, 64.6)))
	add_child(Fx.box(Vector3(0.9, 0.6, 0.08), PixTex.mat(PixTex.planks(Color(0.55, 0.4, 0.22)), 1.0), Vector3(4.2, 1.25, 64.55)))
	_solid(Vector2(4.2, 64.6), Vector2(0.3, 0.3))
	var lbl := Label3D.new()
	lbl.text = "THE OLD BRIDGE"
	lbl.font = UiArt.pixel_font()
	lbl.font_size = 32
	lbl.pixel_size = 0.006
	lbl.modulate = Color(0.15, 0.1, 0.06)
	lbl.position = Vector3(4.2, 1.3, 64.5)
	lbl.rotation.y = PI
	add_child(lbl)
	readables.append({"pos": Vector3(4.2, 0, 64.0), "title": "THE OLD BRIDGE",
		"text": "\"Hold the bridge to the last man,\" the king said.\n\nSer Corvin looked at his men, soaked and seventeen and terrified, and led them home instead. They lived. He was branded a traitor and stripped of his name.\n\nThe far span fell into the river the next spring. Nobody rebuilt it. Nobody wanted to cross to where the war was.\n\n(Someone has scratched underneath: HE WAS RIGHT.)"})
	map_labels.append([Vector3(0, 0, 69), "THE OLD BRIDGE"])


func _roads() -> Array:
	var E: Vector3 = GATES["east"][1]
	var W: Vector3 = GATES["west"][1]
	var S: Vector3 = GATES["south"][1]
	return [[E, LAIRS["farm"]], [E, LAIRS["pyre"]], [W, LAIRS["pit"]], [W, LAIRS["shrine"]], [S, LAIRS["bridge"]],
		[E, Vector3(46, 0, -46)], [Vector3(46, 0, -46), LAIRS["spire"]], [W, Vector3(-56, 0, 15)],
		[S, Vector3(-46, 0, 46)], [S, Vector3(46, 0, 46)], [W, Vector3(-46, 0, -46)], [Vector3(-46, 0, -46), LAIRS["spire"]]]


func _build_walls() -> void:
	var wall_mat := PixTex.mat(PixTex.bricks(Color(0.55, 0.52, 0.48), 31), 2.5)
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
	var tower := PixTex.mat(PixTex.bricks(Color(0.46, 0.43, 0.4), 32, 4, 3), 2.5)
	var roof := PixTex.mat(PixTex.shingles(Color(0.55, 0.2, 0.15)), 1.5)
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
	# Light walls are plaster over brick; dark ones are bare stone
	var light := wall_col.get_luminance() > 0.45
	var wm := PixTex.mat(PixTex.plaster(wall_col, int(c.x * 7 + c.y)) if light else PixTex.bricks(wall_col, int(c.x * 3 + c.y)), 2.0)
	n.add_child(Fx.box(Vector3(size.x, h, size.y), wm, Vector3(0, h * 0.5, 0)))
	# Timber beams
	var beam := PixTex.mat(PixTex.planks(Color(0.3, 0.19, 0.11)), 1.5)
	n.add_child(Fx.box(Vector3(size.x + 0.1, 0.25, size.y + 0.1), beam, Vector3(0, h * 0.55, 0)))
	if light:
		# Timber framing: corner posts and a cross-beam on every face
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				n.add_child(Fx.box(Vector3(0.3, h, 0.3), beam, Vector3(sx * size.x * 0.5, h * 0.5, sz * size.y * 0.5)))
		n.add_child(Fx.box(Vector3(size.x + 0.12, 0.22, size.y + 0.12), beam, Vector3(0, h - 0.15, 0)))
	var roof_m := PixTex.mat(PixTex.shingles(roof_col.lightened(0.1), int(c.x + c.y * 3)), 1.5)
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
	var door_box := Fx.box(Vector3(1.4, 2.4, 0.2) if dir.x == 0.0 else Vector3(0.2, 2.4, 1.4), PixTex.mat(PixTex.planks(Color(0.36, 0.22, 0.12), 41), 1.0), face + dir * 0.05 + Vector3(0, 1.2, 0))
	n.add_child(door_box)
	var glass := Fx.mat(Color(1.0, 0.8, 0.45), 2.0)
	var across := Vector3(dir.z, 0, dir.x).abs()
	for s in [-1.0, 1.0]:
		var wpos: Vector3 = face + dir * 0.05 + across * s * minf(2.4, (size.x if dir.x == 0.0 else size.y) * 0.3) + Vector3(0, 2.0, 0)
		n.add_child(Fx.box(Vector3(0.8, 0.8, 0.12) if dir.x == 0.0 else Vector3(0.12, 0.8, 0.8), glass, wpos))
	if sign_text != "":
		map_labels.append([Vector3(c.x, 0, c.y), sign_text])
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
	_solid(Vector2.ZERO, Vector2(4.2, 4.2), 0.9)
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
	clock.add_child(Fx.box(Vector3(5, 16, 5), PixTex.mat(PixTex.bricks(dark_wall, 51), 2.0), Vector3(0, 8, 0)))
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
	_solid(Vector2(-23, -11.8), Vector2(1.0, 0.6), 0.9)
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
	_solid(Vector2(-9, -8), Vector2(4, 1.4), 1.2)
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
	var tomb := PixTex.mat(PixTex.bricks(Color(0.52, 0.52, 0.54), 71, 2, 1), 1.0)
	for gx in 4:
		for gz in 3:
			var tp := gy + Vector3(-5 + gx * 3.0, 0, -3 + gz * 3.0)
			add_child(Fx.box(Vector3(0.8, 1.0, 0.2), tomb, tp + Vector3(0, 0.5, 0)))
			_solid(Vector2(tp.x, tp.z), Vector2(0.8, 0.3), 1.0)
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
	var trunk := PixTex.mat(PixTex.bark(Color(0.36, 0.24, 0.14)), 1.0)
	var leaves := [PixTex.mat(PixTex.leaves(Color(0.22, 0.42, 0.17), 61), 1.0), PixTex.mat(PixTex.leaves(Color(0.28, 0.46, 0.19), 62), 1.0), PixTex.mat(PixTex.leaves(Color(0.36, 0.44, 0.16), 63), 1.0)]
	var roads := _roads()
	var placed := 0
	var tries := 0
	while placed < 110 and tries < 900:
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
		if ok and wet_at(p) > Parchment.SHORE - 0.03:
			ok = false  # no trees in the water or on the sand
		for seg in roads:
			if _seg_dist(p, seg[0], seg[1]) < 5.0:
				ok = false
		if not ok:
			continue
		placed += 1
		# Voxel trees made in Blender: oaks in the lowlands, pines (some snow-dusted) to the north
		var pine := p.z < -40.0 and rng.randf() < 0.7
		var model := ("tree_pine_%d" % (rng.randi() % 2)) if pine else ("tree_oak_%d" % (rng.randi() % 3))
		var tree := Vox.prop(model)
		if tree:
			tree.position = p
			tree.rotation.y = rng.randi_range(0, 3) * PI * 0.5
			tree.scale = Vector3.ONE * rng.randf_range(0.85, 1.25)
			add_child(tree)
		else:
			var hgt := rng.randf_range(2.5, 4.5)
			add_child(Fx.box(Vector3(0.4, hgt, 0.4), trunk, p + Vector3(0, hgt * 0.5, 0)))
			var lm: Material = leaves[rng.randi() % leaves.size()]
			add_child(Fx.box(Vector3(2.4, 1.6, 2.4), lm, p + Vector3(0, hgt + 0.4, 0)))
		_solid(Vector2(p.x, p.z), Vector2(0.6, 0.6))
	# Rocks and bushes in the wilds, barrels and crates by the doors of the city
	var scatter := 0
	tries = 0
	while scatter < 70 and tries < 800:
		tries += 1
		var p2 := Vector3(rng.randf_range(-88, 88), 0, rng.randf_range(-88, 64))
		if absf(p2.x) < WALL + 3.0 and absf(p2.z) < WALL + 3.0:
			continue
		if wet_at(p2) > Parchment.SHORE - 0.02 or blocked(p2):
			continue
		var near_road := false
		for seg in roads:
			if _seg_dist(p2, seg[0], seg[1]) < 3.0:
				near_road = true
		if near_road:
			continue
		var is_rock := rng.randf() < 0.45
		var prop := Vox.prop(("rock_%d" % (rng.randi() % 3)) if is_rock else "bush")
		if prop == null:
			break
		prop.position = p2
		prop.rotation.y = rng.randf() * TAU
		prop.scale = Vector3.ONE * rng.randf_range(0.7, 1.3)
		add_child(prop)
		if is_rock:
			_solid(Vector2(p2.x, p2.z), Vector2(1.2, 1.2) * prop.scale.x, 0.8 * prop.scale.x)
		scatter += 1
	for spot in [Vector3(-11.5, 0, 10.5), Vector3(-12.5, 0, 11.2), Vector3(13.5, 0, -10.5), Vector3(12.8, 0, -11.4),
			Vector3(-20.5, 0, -9.5), Vector3(-27.5, 0, -10.0), Vector3(-6.5, 0, -9.6), Vector3(9.5, 0, 13.5), Vector3(30.5, 0, 4.5)]:
		var is_barrel := rng.randf() < 0.55
		var thing := Vox.prop("barrel" if is_barrel else "crate")
		if thing == null or blocked(spot):
			continue
		thing.position = spot
		thing.rotation.y = rng.randf() * TAU
		add_child(thing)
		_solid(Vector2(spot.x, spot.z), Vector2(0.75, 0.75), 0.8 if is_barrel else 0.76)


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
				var sand := PixTex.mat(PixTex.ground(Color(0.78, 0.65, 0.42), "sand"), 2.0)
				node.add_child(Fx.cylinder(9.0, 9.0, 0.05, sand, Vector3(0, 0.03, 0)))
				var wallm := PixTex.mat(PixTex.bricks(Color(0.55, 0.43, 0.32), 81), 2.0)
				for k in 14:
					if k == 3:
						continue  # the entrance
					var a := TAU * k / 14.0
					var seg := Fx.box(Vector3(4.2, 2.2, 0.6), wallm, Vector3(cos(a) * 10.0, 1.1, sin(a) * 10.0))
					seg.rotation.y = -a + PI / 2.0
					node.add_child(seg)
					_solid(Vector2(c.x + cos(a) * 10.0, c.z + sin(a) * 10.0), Vector2(2.2, 2.2), 2.2)
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
	var cond := Fx.mat(Color(0.3, 0.85, 1.0), 1.1)
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
	var edda = NpcScript.new()
	edda.npc_id = "edda"
	edda.display_name = Side.EDDA["name"]
	edda.cloth = Side.EDDA["look"][0]
	edda.accent = Side.EDDA["look"][1]
	edda.ow = self
	edda.position = Side.EDDA["spot"]
	add_child(edda)
	npcs["edda"] = edda
	# Edda's long lamplighter's pole
	var pole := Fx.box(Vector3(0.05, 2.6, 0.05), Fx.mat(Color(0.3, 0.2, 0.12)), Vector3(0.35, 1.3, -0.1))
	edda.add_child(pole)
	edda.add_child(Fx.box(Vector3(0.12, 0.12, 0.12), Fx.mat(Color(1.0, 0.8, 0.4), 4.0), Vector3(0.35, 2.65, -0.1)))
	crier = NpcScript.new()
	crier.cloth = Color(0.55, 0.15, 0.15)
	crier.accent = Color(0.95, 0.8, 0.3)
	crier.ow = self
	crier.position = Vector3(-3.5, 0, -10)
	add_child(crier)
	crier.add_child(Fx.cylinder(0.12, 0.08, 0.18, Fx.mat(Color(0.85, 0.65, 0.2), 0.4), Vector3(0.32, 1.0, -0.2)))
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
		_solid(Vector2(p.x, p.z), Vector2(1.0, 0.65), 0.7)


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
		"cultist":
			e.max_hp = 50.0 * g
			e.dmg = 7.0 * (1.0 + 0.25 * (day - 1))
			e.speed = 3.0
			e.cloth = Color(0.85, 0.83, 0.8)
			e.tech = Color(0.75, 0.55, 1.0)
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
	e.model_id = d["id"]
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
	weapon_node = Swords.build(GameState.weapon, 0.34 + float(W["reach"]) * 0.07, GameState.weapon_tune)
	# A hammer grip: the handle runs across the palm under the curled fingers and the blade
	# leaves the fist on the thumb side (-X for the right hand), angled a little forward.
	weapon_node.position = Vector3(0.0, -0.03, -0.085)
	weapon_node.rotation = Vector3(0, PI / 2.0 - 0.3, 0)
	walker.set_weapon(weapon_node, W["color"])


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
	hurt_overlay.color = Color(0.75, 0.02, 0.02, 0.0)
	hurt_overlay.material = Fx.vignette_material()
	hurt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hurt_overlay)
	hurt_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Letterbox bars for the dusk cutscene (closed until then)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0, 1)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.add_child(bar)
		bar.anchor_left = 0.0
		bar.anchor_right = 1.0
		bar.anchor_top = 0.0 if top else 1.0
		bar.anchor_bottom = 0.0 if top else 1.0
		bar.offset_top = 0.0
		bar.offset_bottom = 0.0
		bar.set_meta("top", top)
		letterbox.append(bar)

	# Top-left: purse and clock
	var tl: PanelContainer = game.hud_panel()
	game._anchor(tl, 0, 0, 0, 0, 12, 10, 300, 10)
	hud.add_child(tl)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	tl.add_child(info)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	info.add_child(row)
	row.add_child(_icon("dread", 32))
	dread_label = game._label("", 24, Color(0.56, 0.85, 1.0))
	dread_label.custom_minimum_size = Vector2(90, 0)
	row.add_child(dread_label)
	row.add_child(_icon("crown", 28))
	crowns_label = game._label("", 24, GOLD)
	row.add_child(crowns_label)
	day_label = game._label("", 16, GOLD)
	info.add_child(day_label)
	clock_bar = game._bar(Color(1.0, 0.75, 0.35), 260, 8)
	info.add_child(clock_bar)
	var dusk_mark := ColorRect.new()
	dusk_mark.color = Color(0.7, 0.3, 0.9)
	dusk_mark.custom_minimum_size = Vector2(4, 8)
	clock_bar.add_child(dusk_mark)
	dusk_mark.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	dusk_mark.offset_left = -4

	# Top-centre: the compass, and under it a boss bar when one is fighting you
	compass = CompassScript.new()
	compass.ow = self
	game._anchor(compass, 0.5, 0, 0.5, 0, -220, 6, 220, 52)
	hud.add_child(compass)
	boss_box = VBoxContainer.new()
	game._anchor(boss_box, 0.5, 0, 0.5, 0, -250, 62, 250, 112)
	hud.add_child(boss_box)
	boss_name = game._label("", 16, GOLD)
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_box.add_child(boss_name)
	var bb: Array = game.labeled_bar(Color(0.85, 0.45, 0.25), 500, 16)
	boss_bar = bb[0]
	boss_hp_label = bb[1]
	boss_box.add_child(boss_bar)
	boss_box.visible = false

	# Top-right: what today holds
	var tr: PanelContainer = game.hud_panel()
	game._anchor(tr, 1, 0, 1, 0, -360, 10, -12, 10)
	tr.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hud.add_child(tr)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 2)
	tr.add_child(tv)
	tracker = RichTextLabel.new()
	tracker.bbcode_enabled = true
	tracker.fit_content = true
	tracker.scroll_active = false
	tracker.autowrap_mode = TextServer.AUTOWRAP_OFF
	tracker.custom_minimum_size = Vector2(330, 0)
	tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tracker.add_theme_font_override("normal_font", UiArt.pixel_font())
	tracker.add_theme_font_size_override("normal_font_size", 16)
	tracker.add_theme_color_override("default_color", TEXT)
	tracker.add_theme_constant_override("line_separation", 4)
	tracker.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	tracker.add_theme_constant_override("shadow_offset_x", 2)
	tracker.add_theme_constant_override("shadow_offset_y", 2)
	tv.add_child(tracker)

	# Bottom-centre: Will and the skill bar, nothing else
	var bottom := VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 2)
	game._anchor(bottom, 0.5, 1, 0.5, 1, -300, -160, 300, -4)
	hud.add_child(bottom)
	var will_row := HBoxContainer.new()
	will_row.add_theme_constant_override("separation", 6)
	will_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_child(will_row)
	will_row.add_child(game.heart_icon())
	var wb: Array = game.labeled_bar(Color(0.72, 0.1, 0.1), 480, 14)
	will_bar = wb[0]
	will_label = wb[1]
	will_row.add_child(will_bar)
	hotbar = HotbarScript.new()
	hotbar.boss = walker
	hotbar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bottom.add_child(hotbar)

	# Bottom-right: the minimap, on parchment in a wooden frame
	var mp: PanelContainer = game.hud_panel(4.0)
	game._anchor(mp, 1, 1, 1, 1, -178, -178, -12, -12)
	hud.add_child(mp)
	minimap = MapScript.new()
	minimap.ow = self
	minimap.mini = true
	minimap.custom_minimum_size = Vector2(150, 150)
	mp.add_child(minimap)
	# The full map (M): a big sheet of parchment over everything
	big_map = game.hud_panel(8.0)
	game._anchor(big_map, 0.5, 0.5, 0.5, 0.5, -330, -340, 330, 340)
	hud.add_child(big_map)
	var bmv := VBoxContainer.new()
	big_map.add_child(bmv)
	var bm = MapScript.new()
	bm.ow = self
	bm.custom_minimum_size = Vector2(620, 620)
	bmv.add_child(bm)
	map_footer = game._label("", 16, Color(1.0, 0.85, 0.6))
	map_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bmv.add_child(map_footer)
	big_map.visible = false

	# Centre: crosshair, the tick beat, and the interact prompt
	for r in [Rect2(-1, -7, 2, 14), Rect2(-7, -1, 14, 2)]:
		var c := ColorRect.new()
		c.color = Color(1, 0.9, 0.8, 0.7)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		game._anchor(c, 0.5, 0.5, 0.5, 0.5, r.position.x, r.position.y, r.end.x, r.end.y)
		hud.add_child(c)
	beat = ColorRect.new()
	beat.color = Color(1.0, 0.85, 0.5, 0.0)
	beat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	beat.rotation = PI / 4.0
	beat.pivot_offset = Vector2(3, 3)
	game._anchor(beat, 0.5, 0.5, 0.5, 0.5, -3, 14, 3, 20)
	hud.add_child(beat)
	# Your blade's readiness: a hair-thin bar under the crosshair that fills between swings
	swing_bar = game._bar(Color(1.0, 0.9, 0.7, 0.8), 28, 3)
	game._anchor(swing_bar, 0.5, 0.5, 0.5, 0.5, -14, 24, 14, 27)
	hud.add_child(swing_bar)
	prompt_box = game.hud_panel(6.0)
	game._anchor(prompt_box, 0.5, 0.5, 0.5, 0.5, -200, 34, 200, 34)
	prompt_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud.add_child(prompt_box)
	var prow := HBoxContainer.new()
	prow.alignment = BoxContainer.ALIGNMENT_CENTER
	prow.add_theme_constant_override("separation", 8)
	prompt_box.add_child(prow)
	var key: Label = game._label(" E ", 16, Color(0.1, 0.05, 0.05))
	var ksb := StyleBoxFlat.new()
	ksb.bg_color = Color("ffd27a")
	ksb.set_content_margin_all(2)
	key.add_theme_stylebox_override("normal", ksb)
	key.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	prow.add_child(key)
	prompt_label = game._label("", 16, Color(1.0, 0.9, 0.6))
	prow.add_child(prompt_label)
	prompt_box.visible = false

	# Toasts: big news on a wooden sign that sizes itself to the words
	toast_box = game.hud_panel(12.0)
	game._anchor(toast_box, 0.5, 0.33, 0.5, 0.33, -200, 0, 200, 0)
	toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud.add_child(toast_box)
	var tvb := VBoxContainer.new()
	toast_box.add_child(tvb)
	toast = game._label("", 40, GOLD)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tvb.add_child(toast)
	toast_sub = game._label("", 16, TEXT)
	toast_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_sub.custom_minimum_size = Vector2(560, 0)
	tvb.add_child(toast_sub)
	hud.move_child(big_map, -1)  # the open map sits over everything else
	toast_box.modulate.a = 0.0


func _icon(id: String, px: int) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = UiArt.icon(id)
	tr.custom_minimum_size = Vector2(px, px)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func show_toast(main: String, sub: String = "", duration: float = 3.0) -> void:
	toast.text = main
	toast_sub.text = sub
	var box: Control = toast_box
	if toast_tween:
		toast_tween.kill()
	toast_tween = create_tween()
	box.modulate.a = 1.0
	toast_tween.tween_interval(duration)
	toast_tween.tween_property(box, "modulate:a", 0.0, 0.6)


## A person says something out loud: a speech line over their head.
func say(n: Node3D, text: String, duration: float = 2.4) -> void:
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
	tw.tween_interval(duration)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func _objective_text() -> String:
	if dusk_state != "":
		return "DUSK\nSOMEONE IS COMING FOR YOU"
	if GameState.is_final_night():
		return "THE LAST DAY. NO BOSS TODAY.\nAT DUSK, HE COMES."
	var d := _boss_data()
	if d.is_empty():
		return ""
	if GameState.day_boss_slain:
		return "DEED DONE: %s\nWALK THE CITY UNTIL DUSK" % _short(d["name"], 22)
	var to: Vector3 = LAIRS[d["lair"]] - walker.position
	return "%s\n%dM %s · %s" % [d["name"], int(Vector2(to.x, to.z).length()), _compass_short(to), LAIR_NAMES[d["lair"]]]


func _compass(v: Vector3) -> String:
	var a := atan2(v.x, -v.z)
	var names := ["NORTH", "NORTHEAST", "EAST", "SOUTHEAST", "SOUTH", "SOUTHWEST", "WEST", "NORTHWEST"]
	return names[posmod(roundi(a / (TAU / 8.0)), 8)]


func _update_hud() -> void:
	dread_label.text = "%d" % int(GameState.dread)
	crowns_label.text = "%d" % GameState.crowns
	var dt := GameState.day_time
	var phase := "MORNING" if dt < 0.3 else ("NOON" if dt < 0.5 else ("AFTERNOON" if dt < 0.75 else ("EVENING" if dt < 1.0 else "DUSK")))
	day_label.text = "DAY %d OF 7  ·  %s" % [day, phase]
	clock_bar.value = clampf(dt, 0.0, 1.0)
	will_bar.value = will / maxf(1.0, will_max)
	will_label.text = "YOUR WILL  %d / %d" % [int(ceil(will)), int(will_max)]
	var W := _weapon()
	swing_bar.value = 1.0 - float(swing_cd) / maxf(1.0, float(W["ticks"]))
	var txt := "[color=#ff9a8a]%s[/color]\n[color=#ffd98a]%s[/color]" % [_track_boss(), _track_errand()]
	if txt != tracker.text:
		tracker.text = txt
	if map_open:
		map_footer.text = "%s  ·  SECRETS %d/%d  ·  PAGES %d/%d  ·  BOONS %d  ·  M: CLOSE" % [
			str(W["name"]).to_upper(), GameState.secrets.size(), Side.SECRETS.size(), GameState.pages.size(), Side.PAGES.size(), GameState.boons.size()]
	if is_instance_valid(engaged) and not engaged.dead:
		boss_bar.value = engaged.hp / engaged.max_hp
		boss_hp_label.text = "%d / %d" % [int(ceil(engaged.hp)), int(engaged.max_hp)]
	beat.color.a = walker.tick_flash * 0.9
	prompt_box.visible = prompt_label.text != ""
	compass.markers = _markers()


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
		_cutscene_walk(delta)
		return
	# Once a day: look over the blades (exercises the inventory and upgrades).
	if not bot_inventory_done and t > 2.0:
		bot_inventory_done = true
		open_inventory()
		return
	# Hop now and then, and roll out of a charge.
	if walker.on_ground and randf() < delta * 0.3:
		walker.try_jump()
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
	var q := _quest()
	if foe != null:
		goal = foe.position
	elif GameState.quest_state == "active" and not q.is_empty():
		goal = q["where"]  # Edda's errand first
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


# =============================================================================
# The Lamplighter's story (sidestory.gd)
# =============================================================================

func _quest() -> Dictionary:
	var i := GameState.quest_step
	if i >= Side.QUEST.size():
		return {}
	return Side.QUEST[i]


func _quest_text() -> String:
	var q := _quest()
	if q.is_empty():
		return "EVERY LAMP IN VAEL IS LIT\n"
	match GameState.quest_state:
		"":
			return "%s\nSPEAK TO EDDA BY THE PLAZA" % q["title"]
		"active":
			var to: Vector3 = q["where"] - walker.position
			var left := "" if quest_foes.is_empty() else " · %d LEFT" % quest_foes.size()
			return "%s%s\n%dM %s · %s" % [q["title"], left, int(Vector2(to.x, to.z).length()), _compass_short(to), _short(str(q["where_name"]).split(",")[0], 18)]
	return "%s\nDONE. EDDA THANKS YOU" % q["title"]


## The tracker's two lines: today's boss, and Edda's errand. Short enough to glance at.
func _track_boss() -> String:
	if dusk_state != "":
		return "DUSK · SOMEONE IS COMING"
	var d := _boss_data()
	if d.is_empty():
		return "THE LAST DAY · NO BOSS"
	if GameState.day_boss_slain:
		return "DEED DONE · %s" % _short(d["name"], 20)
	var to: Vector3 = LAIRS[d["lair"]] - walker.position
	return "%s · %dM %s" % [_short(str(d["name"]).split(" THE ")[0], 18), int(Vector2(to.x, to.z).length()), _compass_short(to)]


func _track_errand() -> String:
	var q := _quest()
	if q.is_empty():
		return "EVERY LAMP IS LIT"
	match GameState.quest_state:
		"":
			return "EDDA WAITS · THE PLAZA"
		"active":
			var to: Vector3 = q["where"] - walker.position
			var left := "" if quest_foes.is_empty() else " · %d LEFT" % quest_foes.size()
			return "%s · %dM %s%s" % [_short(q["title"], 16), int(Vector2(to.x, to.z).length()), _compass_short(to), left]
	return "%s · DONE" % _short(q["title"], 18)


func _short(text: String, n: int) -> String:
	return text if text.length() <= n else text.substr(0, n - 1) + "."


func _compass_short(v: Vector3) -> String:
	var a := atan2(v.x, -v.z)
	return ["N", "NE", "E", "SE", "S", "SW", "W", "NW"][posmod(roundi(a / (TAU / 8.0)), 8)]


func _talk_edda() -> void:
	var tone := Dialogue.tone()
	npcs["edda"].talk()
	game.dialogue_speaker = npcs["edda"]
	Sfx.play("click", -4.0, 0.8)
	var q := _quest()
	var opts: Array = []
	var body: String = Side.EDDA["greet"][tone]
	var title := str(Side.EDDA["name"])
	if q.is_empty():
		body += "\n\nEvery lamp in Vael is lit. Every one."
	elif GameState.quest_state == "":
		title = "THE LAMPLIGHTER · " + str(q["title"])
		body = str(q["ask"])
		opts.append(["I'll go. (%s)" % q["where_name"], _accept_quest])
	elif GameState.quest_state == "active":
		body = "%s\n\n(%s)" % ["Still out there, are they? Go on. I'll keep the lamp lit for you.", q["where_name"]]
	else:
		body = str(Side.EDDA["done"])
	opts.append(["Ask about the man in white", _ask_stranger.bind("edda")])
	opts.append(["Leave", _close_dialogue])
	game._show_choice(title, body, "", opts)


func _accept_quest() -> void:
	GameState.quest_state = "active"
	_close_dialogue()
	var q := _quest()
	show_toast(str(q["title"]), "THE LAMPLIGHTER'S ERRAND: " + str(q["where_name"]), 3.5)
	game.tutorial("quest", "Edda's errands are fights you can WIN. Each one earns a BOON that makes you stronger against the challengers at night. The gold marker on the compass shows the way.")


func _update_quest() -> void:
	if GameState.quest_state != "active" or dusk_state != "":
		return
	var q := _quest()
	if q.is_empty():
		return
	var where: Vector3 = q["where"]
	var d := Vector2(where.x - walker.position.x, where.z - walker.position.z).length()
	if (q["foes"] as Array).is_empty():
		if d < 4.0:
			_quest_won()
		return
	if quest_spawned or d > 28.0:
		return
	quest_spawned = true
	for f in q["foes"]:
		for k in int(f[1]):
			var a := randf() * TAU
			var e = _spawn_enemy(f[0], where + Vector3(cos(a), 0, sin(a)) * randf_range(2.0, 6.0))
			e.aggro = true
			quest_foes.append(e)
	if str(q["elite"]) != "":
		var el = _spawn_enemy("cultist", where)
		el.elite = true
		el.display_name = q["elite"]
		el.max_hp *= 4.0
		el.dmg *= 1.6
		el.hp = el.max_hp
		el.reach = 2.2
		quest_foes.append(el)
	say(quest_foes[0], Side.AMBUSH_SHOUTS.pick_random())
	show_toast(str(q["title"]), "The Crownless are waiting for you.", 2.5)


func _quest_won() -> void:
	GameState.quest_state = "won"
	var q := _quest()
	var boon: String = q["boon"]
	GameState.boons[boon] = true
	print("[QUEST] step %d won: %s, boon %s" % [GameState.quest_step, q["title"], boon])
	Sfx.play("crown")
	var B: Dictionary = GameState.BOONS[boon]
	game._show_choice("THE LAMPLIGHTER · " + str(q["title"]), "%s\n\nBOON OF VAEL: %s\n%s" % [q["won"], str(B["name"]).to_upper(), B["desc"]], "crown",
		[["CONTINUE", _close_dialogue]])


# =============================================================================
# The town crier and the Crownless ambushes
# =============================================================================

func _update_crier(delta: float) -> void:
	crier_t -= delta
	if crier_t > 0.0:
		return
	crier_t = 22.0
	if crier.position.distance_to(walker.position) > 30.0:
		return
	var lines: Array = Side.CRIER[clampi(day - 1, 0, Side.CRIER.size() - 1)]
	say(crier, str(lines[crier_i % lines.size()]), 5.0)
	crier_i += 1


func _update_ambush() -> void:
	if dusk_state != "" or day < 2:
		return
	for mark in [0.3, 0.62]:
		if GameState.day_time < mark or ambushes.has(mark):
			continue
		ambushes[mark] = true
		var back := Vector3(sin(walker.yaw), 0, cos(walker.yaw))
		var n := 2 + day / 3
		var first = null
		for k in n:
			var side := Vector3(-back.z, 0, back.x) * (k - (n - 1) * 0.5) * 2.0
			var e = _spawn_enemy("cultist" if randf() < 0.6 else "thug", walker.position + back * 9.0 + side)
			e.aggro = true
			if first == null:
				first = e
		if first != null:
			say(first, Side.AMBUSH_SHOUTS.pick_random())
		show_toast("AMBUSH", "Masked figures step out of the crowd behind you.", 2.0)
		Sfx.play("learn", -4.0, 1.2)
		game.tutorial("ambush", "The Crownless hunt you by day. Fight them off for Dread, or run for the gates.")


# =============================================================================
# Secrets of Vael and the Chronicle (sidestory.gd)
# =============================================================================

func _build_secrets() -> void:
	var stone := Fx.mat(Color(0.55, 0.53, 0.5))
	for sec in Side.SECRETS:
		var n := Node3D.new()
		n.position = sec["pos"]
		add_child(n)
		secret_nodes[sec["id"]] = n
		match str(sec["id"]):
			"wren_sword":
				n.add_child(Fx.cylinder(0.45, 0.55, 0.6, Fx.mat(Color(0.15, 0.1, 0.08)), Vector3(0, 0.3, 0)))
				stump_sword = Swords.build("borrowed", 1.2)
				stump_sword.rotation.x = -PI / 2.0  # tip down, into the wood
				stump_sword.position = Vector3(0, 1.25, 0)
				n.add_child(stump_sword)
				var shine := OmniLight3D.new()
				shine.light_color = Color(1.0, 0.95, 0.8)
				shine.light_energy = 0.8
				shine.omni_range = 3.0
				shine.position = Vector3(0, 1.6, 0)
				n.add_child(shine)
			"corvin_shield":
				var sh := Fx.box(Vector3(0.9, 1.1, 0.08), Fx.mat(Color(0.2, 0.3, 0.6)), Vector3(0, 0.45, 0))
				sh.rotation = Vector3(-0.5, 0.4, 0.15)
				n.add_child(sh)
				n.add_child(Fx.box(Vector3(0.06, 1.1, 0.1), Fx.mat(Color(0.1, 0.08, 0.06)), Vector3(0.05, 0.47, 0.02)))
			"lion_laurel":
				var tm := TorusMesh.new()
				tm.inner_radius = 0.22
				tm.outer_radius = 0.3
				var lr := MeshInstance3D.new()
				lr.mesh = tm
				lr.material_override = Fx.mat(Color(0.45, 0.42, 0.2))
				lr.position = Vector3(0, 0.05, 0)
				n.add_child(lr)
				n.add_child(Fx.box(Vector3(0.25, 0.01, 0.12), Fx.mat(Color(0.9, 0.85, 0.7)), Vector3(0.45, 0.02, 0.1)))
			"ashe_ledger":
				n.add_child(Fx.box(Vector3(0.5, 0.12, 0.38), Fx.mat(Color(0.3, 0.12, 0.1)), Vector3(0, 0.06, 0)))
				n.add_child(Fx.box(Vector3(0.46, 0.13, 0.34), Fx.mat(Color(0.85, 0.8, 0.65)), Vector3(0.01, 0.07, 0)))
			"alder_mask":
				var m := Fx.box(Vector3(0.36, 0.46, 0.1), Fx.mat(Color(0.95, 0.93, 0.88), 0.3), Vector3(0, 0.3, 0))
				m.rotation.x = -0.4
				n.add_child(m)
				for sx in [-0.08, 0.08]:
					n.add_child(Fx.box(Vector3(0.06, 0.03, 0.12), Fx.mat(Color(0.05, 0.03, 0.04)), Vector3(sx, 0.36, -0.01)))
			"empty_throne":
				var glass := Fx.mat(Color(0.08, 0.04, 0.1), 0.6)
				n.add_child(Fx.box(Vector3(1.6, 0.8, 1.4), glass, Vector3(0, 0.4, 0)))
				n.add_child(Fx.box(Vector3(1.6, 2.8, 0.3), glass, Vector3(0, 1.4, -0.6)))
				for k in 5:
					n.add_child(Fx.box(Vector3(0.12, 0.4, 0.12), glass, Vector3(-0.6 + k * 0.3, 3.0, -0.6)))
				_solid(Vector2(n.position.x, n.position.z), Vector2(1.6, 1.4))
			"statue":
				n.add_child(Fx.box(Vector3(1.6, 1.0, 1.6), stone, Vector3(0, 0.5, 0)))
				var fig := Node3D.new()
				fig.position = Vector3(0, 1.0, 0)
				n.add_child(fig)
				fig.add_child(Fx.box(Vector3(0.6, 1.2, 0.4), stone, Vector3(0, 0.9, 0)))
				fig.add_child(Fx.box(Vector3(0.5, 0.9, 0.35), stone, Vector3(0, 0.0, 0)))
				fig.add_child(Fx.box(Vector3(0.32, 0.36, 0.32), Fx.mat(Color(0.5, 0.48, 0.45)), Vector3(0, 1.72, 0)))
				fig.add_child(Fx.box(Vector3(0.18, 0.7, 0.18), stone, Vector3(0.42, 1.65, 0)))
				var sw := Swords.build("sunedge", 1.6)
				sw.rotation.x = PI / 2.0
				sw.position = Vector3(0.42, 2.1, 0)
				fig.add_child(sw)
				_solid(Vector2(n.position.x, n.position.z), Vector2(1.6, 1.6))
			"pip_drawing", "flagon_table", "thirteen":
				var lbl := Label3D.new()
				lbl.text = {"pip_drawing": "( o )  ( o )\n /|\\--/|\\\n  KING + FRIEND", "flagon_table": "W.  &  W.", "thirteen": "XIII"}[sec["id"]]
				lbl.font = UiArt.pixel_font()
				lbl.font_size = 32
				lbl.pixel_size = 0.01
				lbl.modulate = Color(0.95, 0.95, 0.9) if sec["id"] == "pip_drawing" else Color(0.3, 0.2, 0.12)
				lbl.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				lbl.position = {"pip_drawing": Vector3(1.32, 1.4, 0), "flagon_table": Vector3(-0.53, 1.6, 0), "thirteen": Vector3(0, 1.4, 0)}[sec["id"]]
				lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED if sec["id"] == "thirteen" else BaseMaterial3D.BILLBOARD_DISABLED
				lbl.rotation.y = {"pip_drawing": -PI / 2.0, "flagon_table": PI / 2.0, "thirteen": 0.0}[sec["id"]]
				n.add_child(lbl)
			"bell":
				var bell := Fx.cylinder(0.45, 0.8, 1.1, Fx.mat(Color(0.6, 0.42, 0.2), 0.2), Vector3(0, 0.55, 0))
				bell.rotation.z = 0.25
				n.add_child(bell)
				_solid(Vector2(n.position.x, n.position.z), Vector2(1.4, 1.4), 1.1)
			"river_ring":
				var rt := TorusMesh.new()
				rt.inner_radius = 0.07
				rt.outer_radius = 0.11
				var rr := MeshInstance3D.new()
				rr.mesh = rt
				rr.material_override = Fx.mat(Color(0.2, 0.17, 0.15))
				rr.position = Vector3(0, 0.03, 0)
				n.add_child(rr)
		# A faint glint marks something worth a look
		var glint := Fx.particles(Color(1.0, 0.95, 0.75), 3, 1.5, 0.2, 0.03)
		glint.position = Vector3(0, 0.6, 0)
		glint.gravity = Vector3(0, 0.3, 0)
		n.add_child(glint)
	for i in Side.PAGES.size():
		var pn := Node3D.new()
		pn.position = Side.PAGES[i]["pos"]
		add_child(pn)
		var page := Fx.box(Vector3(0.3, 0.01, 0.4), Fx.mat(Color(0.92, 0.86, 0.7), 0.6), Vector3(0, 0.05, 0))
		page.rotation.y = i * 0.7
		pn.add_child(page)
		var pg := Fx.particles(Color(1.0, 0.9, 0.6), 4, 1.2, 0.3, 0.03)
		pg.position = Vector3(0, 0.3, 0)
		pg.gravity = Vector3(0, 0.6, 0)
		pn.add_child(pg)
		page_nodes[i] = pn


## Hide what has been taken (pages, the sword in the stump) after a new day or a new run.
func _refresh_props() -> void:
	for i in page_nodes:
		page_nodes[i].visible = not GameState.pages.has(i)
	if stump_sword:
		stump_sword.visible = not GameState.secrets.has("wren_sword")


func _read_secret(sec: Dictionary) -> void:
	var id: String = sec["id"]
	var unlocked := GameState.memories.size() >= int(sec["need"])
	Sfx.play("reveal", -8.0, 0.9 if unlocked else 0.6)
	if not unlocked:
		game._show_card(sec["title"], str(sec["locked"]) + "\n\n(Something here is waiting for you to remember more.)", "STEP AWAY", _close_dialogue)
		return
	var text: String = sec["text"]
	if not GameState.secrets.has(id):
		GameState.secrets[id] = true
		GameState.crowns += 4
		text += "\n\nSECRET %d / %d FOUND  ·  +4 CROWNS" % [GameState.secrets.size(), Side.SECRETS.size()]
		print("[SECRET] %s (%d / %d)" % [id, GameState.secrets.size(), Side.SECRETS.size()])
		if sec.has("weapon"):
			GameState.give_weapon(sec["weapon"])
			GameState.equip_weapon(sec["weapon"])
			_build_weapon()
			_refresh_props()
			text += "\nYOU TAKE UP %s" % str(Dialogue.WEAPONS[sec["weapon"]]["name"]).to_upper()
		if GameState.secrets.size() == Side.SECRETS.size():
			GameState.crowns += 25
			text += "\n\nEVERY SECRET OF VAEL: +25 CROWNS"
	game._show_card(sec["title"], text, "STEP AWAY", _close_dialogue)


func _read_page(i: int) -> void:
	GameState.pages[i] = true
	GameState.crowns += 2
	_refresh_props()
	Sfx.play("coin", -4.0, 0.8)
	var text: String = Side.PAGES[i]["text"] + "\n\nCHRONICLE PAGE %d / %d  ·  +2 CROWNS" % [GameState.pages.size(), Side.PAGES.size()]
	if GameState.pages.size() == Side.PAGES.size():
		GameState.crowns += 20
		text += "\n\nTHE CHRONICLE OF VAEL IS WHOLE: +20 CROWNS"
	print("[PAGE] %d (%d / %d)" % [i, GameState.pages.size(), Side.PAGES.size()])
	game._show_card("THE CHRONICLE OF VAEL", text, "KEEP IT", _close_dialogue)


# =============================================================================
# Swords on display: the forge racks, the Watch armoury, the Flagon wall, the pit graves
# =============================================================================

func _build_swords() -> void:
	# Hennik's rack against the back wall of the forge
	var rack := Node3D.new()
	rack.position = Vector3(-24, 0, -14.4)
	add_child(rack)
	var wood := Fx.mat(Color(0.3, 0.2, 0.12))
	rack.add_child(Fx.box(Vector3(5.0, 0.12, 0.2), wood, Vector3(0, 0.5, 0.2)))
	rack.add_child(Fx.box(Vector3(5.0, 0.12, 0.2), wood, Vector3(0, 2.0, 0.2)))
	var ids := ["falchion", "runeblade", "greatsword", "lionfang", "arcbrand", "sunedge"]
	for k in ids.size():
		var sw := Swords.build(ids[k], 1.4 if ids[k] != "greatsword" else 1.8)
		sw.rotation.x = PI / 2.0  # tip up
		sw.position = Vector3(-2.2 + k * 0.85, 0.75, 0.3)
		rack.add_child(sw)
		tech.append([sw, int(Dialogue.WEAPONS[ids[k]]["tier"])])  # new blades arrive as the city rises
	# Crossed swords over the Hollow Flagon's door
	for s in [-1.0, 1.0]:
		var fs := Swords.build("runeblade" if s < 0.0 else "falchion", 1.6)
		fs.position = Vector3(16 + s * 0.2, 4.2, -9.75)
		fs.rotation = Vector3(0, 0, s * 0.7)
		fs.rotate_object_local(Vector3.RIGHT, PI / 2.0)
		add_child(fs)
	# The Watch armoury by the east gate
	var arm := Node3D.new()
	arm.position = Vector3(34.5, 0, -7.5)
	add_child(arm)
	arm.add_child(Fx.box(Vector3(2.4, 0.1, 0.5), wood, Vector3(0, 0.3, 0)))
	for k in 4:
		var aw := Swords.build("falchion", 1.3)
		aw.rotation.x = PI / 2.0
		aw.rotation.z = (k - 1.5) * 0.06
		aw.position = Vector3(-0.9 + k * 0.6, 0.35, 0)
		arm.add_child(aw)
	_solid(Vector2(34.5, -7.5), Vector2(2.4, 0.6))
	# Gladiators' graves at the Sunfield Pit: blades planted in the sand
	var pit: Vector3 = LAIRS["pit"]
	for k in 5:
		var a := TAU * k / 5.0 + 0.4
		var gs := Swords.build(["shortsword", "falchion", "lionfang", "greatsword", "runeblade"][k], 1.3)
		gs.rotation.x = -PI / 2.0 + 0.12
		gs.position = pit + Vector3(cos(a) * 6.5, 1.1, sin(a) * 6.5)
		add_child(gs)


## Compass markers: today's boss, the Lamplighter's errand (or Edda herself), and at dusk, nothing.
func _markers() -> Array:
	var out: Array = []
	if dusk_state != "":
		return out
	if is_instance_valid(day_boss) and not day_boss.dead:
		out.append({"pos": day_boss.position, "color": Color(1.0, 0.35, 0.25), "label": "BOSS"})
	var q := _quest()
	if not q.is_empty():
		if GameState.quest_state == "":
			out.append({"pos": Side.EDDA["spot"], "color": Color(1.0, 0.85, 0.4), "label": "EDDA"})
		elif GameState.quest_state == "active":
			out.append({"pos": q["where"], "color": Color(1.0, 0.85, 0.4), "label": "ERRAND"})
	return out
