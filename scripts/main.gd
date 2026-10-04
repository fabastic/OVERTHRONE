extends Node
## OVERTHRONE. You are the final boss; the hero is an AI that learns your skills.
## Seven days in the city of Vael (overworld.gd), and six nights at the corner table of the Hollow
## Flagon, where a man in white plays the BOARD (board.gd) with you: the Hollow King is a piece
## walking the map of his own life. Each region ends in a CHALLENGER: one of his former selves.
## This node builds the pixelated 3D hall, the board and the city, the HUDs and the Throne, and drives:
##   title -> DAY (walk Vael) -> DUSK (the Stranger comes) -> NIGHT: the board, with his line
##   -> challenger -> fights, with the Throne between his deaths, until he conquers you:
##     0 stars  -> TRY AGAIN from the last checkpoint (every 3 fights)
##     1+ stars -> PRESTIGE -> MEMORY restored -> you WAKE -> Remembrance -> the next day
##   ... night 7: no board. The final fight is against the Stranger himself -> the ending.
## Combat runs on 0.25s ticks (GameState.TICK): each tick, boss.on_tick_begin -> hero.on_tick
## -> bolts land -> boss.on_tick_end.
##
## Command-line (after `--`): --autoplay  bot plays the boss (for testing)
##                            --fast      run at 4x speed
##                            --quit-at-end  quit after the ending card

const HeroScript := preload("res://scripts/hero.gd")
const BossScript := preload("res://scripts/boss.gd")
const ThroneTreeScript := preload("res://scripts/ui/throne_tree.gd")
const HotbarScript := preload("res://scripts/ui/hotbar.gd")
const UiArt := preload("res://scripts/ui/ui_art.gd")
const PrestigeScript := preload("res://scripts/ui/prestige_screen.gd")
const StarBarScript := preload("res://scripts/ui/star_bar.gd")
const HeroBoltScript := preload("res://scripts/hero_bolt.gd")
const Fx := preload("res://scripts/fx.gd")
const ZoneScript := preload("res://scripts/attacks/zone.gd")
const BoardScript := preload("res://scripts/board.gd")
const Story := preload("res://scripts/story.gd")
const SlamScript := preload("res://scripts/attacks/slam.gd")
const OverworldScript := preload("res://scripts/overworld.gd")
const Dialogue := preload("res://scripts/dialogue.gd")
const ATTACKS := {
	"fireball": preload("res://scripts/attacks/fireball.gd"),
	"volley": preload("res://scripts/attacks/fireball.gd"),
	"lance": preload("res://scripts/attacks/lance.gd"),
	"slam": preload("res://scripts/attacks/slam.gd"),
	"tide": preload("res://scripts/attacks/slam.gd"),
	"spikes": preload("res://scripts/attacks/spikes.gd"),
	"chains": preload("res://scripts/attacks/chains.gd"),
	"lightning": preload("res://scripts/attacks/lightning.gd"),
	"well": preload("res://scripts/attacks/well.gd"),
	"eclipse": preload("res://scripts/attacks/eclipse.gd"),
	"pillar": ZoneScript,
	"meteor": ZoneScript,
	"bloom": ZoneScript,
	"wall": preload("res://scripts/attacks/wall.gd"),
	"doom": preload("res://scripts/attacks/doom.gd"),
	"rain": preload("res://scripts/attacks/rain.gd"),
	"timerend": preload("res://scripts/attacks/timerend.gd"),
	"siphon": preload("res://scripts/attacks/siphon.gd"),
	"hands": preload("res://scripts/attacks/hands.gd"),
	"maw": preload("res://scripts/attacks/maw.gd"),
	"hex": preload("res://scripts/attacks/hex.gd"),
	"ghouls": preload("res://scripts/attacks/ghouls.gd"),
	"cinder": preload("res://scripts/attacks/slam.gd"),
	"stomp": preload("res://scripts/attacks/slam.gd"),
	"bonecage": preload("res://scripts/attacks/chains.gd"),
	"glacier": preload("res://scripts/attacks/lance.gd"),
	"thunder": preload("res://scripts/attacks/lightning.gd"),
	"nullorb": preload("res://scripts/attacks/fireball.gd"),
	"leech": preload("res://scripts/attacks/ghouls.gd"),
	"sweep": preload("res://scripts/attacks/sweep.gd"),
	"grasp": preload("res://scripts/attacks/grasp.gd"),
	"masonry": ZoneScript,
}

const TEXT := Color(0.88, 0.84, 0.78)
const DIM := Color(0.6, 0.56, 0.52)
const GOLD := Color(0.95, 0.75, 0.4)
const BLOOD := Color(0.9, 0.2, 0.18)

var state := "title"
var pixel_scales := [3, 4, 2]
var pixel_index := 0
var quit_at_end := false

# World
var view_container: SubViewportContainer
var sub_viewport: SubViewport
var world: Node3D
var env: Environment
var world_env: WorldEnvironment
var ow  # the city of Vael (by day)
var tick_acc := 0.0
var lights: Array = []  # [light, base_energy, flickers]
var darkness := 0.0
var darkness_target := 0.0
var boss
var hero
var boss_hp := 120.0
var boss_max := 120.0

# UI
var theme_res: Theme
var hud: Control
var hero_title: Label
var hero_bar: ProgressBar
var boss_bar: ProgressBar
var boss_label: Label
var dread_label: Label
var level_label: Label
var insight_rows: Array = []
var insight_box: VBoxContainer
var message_label: Label
var sub_message_label: Label
var message_tween: Tween
var hurt_overlay: ColorRect
var flash_overlay: ColorRect
var overlay_layer: CanvasLayer
var overlay: Control
var card_button: Button

# Throne
var preview_focus := ""
var preview_rite := false
var hotbar
var star_bar
var throne_mode := "between"  # "between" fights, or "prestige" (spending Crowns before the next hero)
var auto_parry_done := false
var auto_lean_t := 0.0
var auto_lean_dir := 0.0

# Board
var board
var board_hud: Control
var chapter_label: Label
var board_info: Label
var narration: Label
var narr_tween: Tween
var banner: Label
var banner_tween: Tween
var board_prompt: Label
var last_chapter_shown := -1

# Tutorial
var tut_panel: PanelContainer
var tut_label: Label
var tut_tween: Tween
var tut_casts := 0
var base_time_scale := 1.0

# Remembrance (choose skills from your past at the start of each chapter)
var rem_selected: Array = []
var rem_buttons := {}
var rem_go: Button
var rem_after: Callable

# Autoplay
var auto_t := 0.0

# Nights and the last night
var night_shown := -1          # the night whose Stranger card has been shown
var fog_revealed := 0          # board regions whose fog has rolled back
var final_fight := false
var final_phase := 0
var final_bonus := 1.0
var final_forgot := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	GameState.autoplay = args.has("--autoplay")
	quit_at_end = args.has("--quit-at-end")
	if args.has("--fast"):
		Engine.time_scale = 4.0
		Engine.physics_ticks_per_second = 240
	base_time_scale = Engine.time_scale
	GameState.reset_run()
	GameState.mastery_milestone.connect(_on_mastery_milestone)
	theme_res = _make_theme()
	_build_world()
	_build_hud()
	_build_board()
	_build_board_hud()
	_build_tutorial()
	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 5
	add_child(overlay_layer)
	_build_overworld()
	for a in args:
		if a.begins_with("--level="):
			# Debug: start previews on a later day (memories restored up to it).
			GameState.level = int(a.trim_prefix("--level="))
			for c in GameState.level - 1:
				GameState.memories.append(str(c))
			GameState.revealed = GameState.level > 5
			boss.apply_purity(GameState.purity())
	for a in args:
		if a.begins_with("--shot="):
			# Debug: save a screenshot after a few seconds, then quit (--shot-delay=N to change when).
			var delay := 6.0
			for b in args:
				if b.begins_with("--shot-delay="):
					delay = float(b.trim_prefix("--shot-delay="))
			get_tree().create_timer(delay, true, false, true).timeout.connect(func():
				get_viewport().get_texture().get_image().save_png(a.trim_prefix("--shot="))
				get_tree().quit())
	if args.has("--preview-day"):
		_enter_day()
		return
	if args.has("--preview-final"):
		GameState.level = GameState.max_level() + 1
		GameState.memories.assign(["0", "1", "2", "3", "4", "5"])
		GameState.owned = {"fireball": 4, "slam": 4, "spikes": 4, "lance": 3}
		GameState.loadout.assign(["fireball", "slam", "spikes", "lance"])
		_show_final_intro()
		return
	if args.has("--preview-board"):
		GameState.board_tile = 2 + 5 * (GameState.level - 1)
		_enter_board()
		return
	if args.has("--pure"):
		# Debug: show the hands fully purified (as after all six memories).
		GameState.memories.assign(["0", "1", "2", "3", "4", "5"])
		boss.apply_purity(GameState.purity())
	if args.has("--preview-prestige"):
		GameState.attempt = 10
		GameState.level_damage = 2600.0
		GameState.level_parries = 7
		GameState.on_boss_defeated(false)
		_show_prestige()
		return
	if args.has("--preview-heroes"):
		_setup_hero_preview()
		return
	if args.has("--preview-throne") or args.has("--preview-rite"):
		_setup_preview(args.has("--preview-rite"))
		return
	_show_title()


## Debug: line up all three hero forms near the throne (a model viewer).
func _setup_hero_preview() -> void:
	state = "preview"
	_release_mouse()
	boss.pitch = -0.42
	var poses := ["preview", "windup", "victory"]
	for i in 3:
		GameState.level = i + 1
		var st := GameState.hero_stats()
		var h = HeroScript.new()
		h.game = self
		h.form = st["form"]
		h.hero_scale = st["scale"]
		h.armor_color = st["armor"]
		h.cape_color = st["cape"]
		h.windup_time = 9999.0
		world.add_child(h)
		h.position = Vector3(-1.5 + i * 1.5, 0, -4.2)
		h.state = poses[i]
	GameState.level = 1


## Debug: jump straight to a mid-run Throne screen (used for screenshots).
func _setup_preview(rite: bool) -> void:
	GameState.dread = 160.0
	GameState.attempt = 5
	GameState.owned["lance"] = 1
	GameState.owned["eclipse"] = 1
	GameState.owned["fireball"] = 3
	GameState.loadout = ["fireball", "slam", "spikes", "eclipse"]
	GameState.fights = {"fireball": 5.0, "slam": 4.0, "spikes": 3.0, "lance": 1.0}
	GameState.crowns = 30
	GameState.perks = {"vigor": true, "haste": true}
	preview_focus = "" if rite else "fireball"
	preview_rite = rite
	_open_throne()


# =============================================================================
# World
# =============================================================================

func _build_world() -> void:
	view_container = SubViewportContainer.new()
	view_container.stretch = true
	view_container.stretch_shrink = pixel_scales[pixel_index]
	view_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view_container)
	view_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	sub_viewport = SubViewport.new()
	sub_viewport.msaa_3d = Viewport.MSAA_DISABLED
	sub_viewport.process_mode = Node.PROCESS_MODE_PAUSABLE
	view_container.add_child(sub_viewport)
	world = Node3D.new()
	sub_viewport.add_child(world)

	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.012, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.3, 0.5)
	env.ambient_light_energy = 0.4
	env.fog_enabled = true
	env.fog_light_color = Color(0.07, 0.04, 0.09)
	env.fog_density = 0.03
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.05
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	world_env = we

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-60, 25, 0)
	moon.light_color = Color(0.55, 0.55, 0.85)
	moon.light_energy = 0.35
	moon.shadow_enabled = true
	world.add_child(moon)
	lights.append([moon, 0.35, false])

	var spot := SpotLight3D.new()
	spot.position = Vector3(0, 10, -8)
	spot.rotation_degrees = Vector3(-90, 0, 0)
	spot.spot_range = 14.0
	spot.spot_angle = 42.0
	spot.light_color = Color(1.0, 0.85, 0.7)
	spot.light_energy = 3.0
	spot.shadow_enabled = true
	world.add_child(spot)
	lights.append([spot, 3.0, false])

	var throne_glow := OmniLight3D.new()
	throne_glow.position = Vector3(0, 1.2, -1.2)
	throne_glow.light_color = Color(0.9, 0.15, 0.1)
	throne_glow.omni_range = 5.0
	throne_glow.light_energy = 1.2
	world.add_child(throne_glow)
	lights.append([throne_glow, 1.2, true])

	_build_arena()

	boss = BossScript.new()
	boss.game = self
	world.add_child(boss)


func _build_arena() -> void:
	var floor_mat := Fx.textured(Fx.stone_texture(Color(0.24, 0.22, 0.26), Color(0.19, 0.17, 0.21), 32, 4), Vector3(9, 9, 1))
	var wall_mat := Fx.textured(Fx.stone_texture(Color(0.2, 0.17, 0.2), Color(0.12, 0.1, 0.13), 32, 4, true), Vector3(4, 2, 1))
	var dais_mat := Fx.textured(Fx.stone_texture(Color(0.3, 0.12, 0.12), Color(0.22, 0.08, 0.09), 16, 2), Vector3(3, 1, 1))

	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(20, 20)
	var fl := MeshInstance3D.new()
	fl.mesh = floor_mesh
	fl.material_override = floor_mat
	fl.position = Vector3(0, 0, -8)
	world.add_child(fl)

	# Dais and steps under the throne.
	world.add_child(Fx.box(Vector3(7, 0.4, 3.2), dais_mat, Vector3(0, 0.2, 0.1)))
	world.add_child(Fx.box(Vector3(5, 0.2, 0.6), dais_mat, Vector3(0, 0.1, -1.75)))

	# Walls
	world.add_child(Fx.box(Vector3(20, 9, 1), wall_mat, Vector3(0, 4.5, -18.5)))
	for s in [-1.0, 1.0]:
		world.add_child(Fx.box(Vector3(1, 9, 20), wall_mat, Vector3(s * 9.5, 4.5, -8)))

	# Pillars with flickering sconces.
	for z in [-3.5, -7.5, -11.5, -15.5]:
		for s in [-1.0, 1.0]:
			var x: float = s * 7.8
			world.add_child(Fx.box(Vector3(1.0, 8, 1.0), wall_mat, Vector3(x, 4, z)))
			world.add_child(Fx.box(Vector3(0.12, 0.2, 0.12), Fx.mat(Color(1.0, 0.55, 0.15), 6.0), Vector3(x - s * 0.6, 2.4, z)))
			var l := OmniLight3D.new()
			l.position = Vector3(x - s * 0.9, 2.5, z)
			l.light_color = Color(1.0, 0.55, 0.25)
			l.omni_range = 5.0
			l.light_energy = 1.1
			world.add_child(l)
			lights.append([l, 1.1, true])

	# A faint summoning circle where the hero fights.
	var circle := TorusMesh.new()
	circle.inner_radius = 3.3
	circle.outer_radius = 3.45
	circle.rings = 48
	circle.ring_segments = 4
	var rune := MeshInstance3D.new()
	rune.mesh = circle
	rune.material_override = Fx.mat(Color(0.6, 0.1, 0.12), 1.5, 0.6)
	rune.position = Vector3(0, 0.01, -8)
	rune.scale = Vector3(1, 0.05, 1)
	world.add_child(rune)


func set_darkness(on: bool) -> void:
	darkness_target = 1.0 if on else 0.0


func clamp_arena(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, -6.5, 6.5), 0, clampf(p.z, -14.0, -1.8))


func spawn_burst(pos: Vector3, color: Color, amount: int = 16) -> void:
	var p := Fx.particles(color, amount, 0.5, 4.0, 0.09, true)
	world.add_child(p)
	p.global_position = pos
	var l := OmniLight3D.new()
	l.light_color = color
	l.omni_range = 4.0
	l.light_energy = 3.0
	world.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.25)
	tw.tween_callback(l.queue_free)
	get_tree().create_timer(1.2, false).timeout.connect(p.queue_free)


func popup_text(pos: Vector3, text: String, color: Color, size: float = 1.0) -> void:
	var l := Label3D.new()
	l.text = text
	l.modulate = color
	l.outline_modulate = Color.BLACK
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.font_size = 32
	l.outline_size = 8
	l.pixel_size = 0.0016 * size
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	world.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(l, "global_position", pos + Vector3(0, 0.8, 0), 0.9)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.5)
	tw.tween_callback(l.queue_free)


func flash(color: Color, strength: float) -> void:
	flash_overlay.color = Color(color.r, color.g, color.b, strength)


# =============================================================================
# Fight loop
# =============================================================================

func _start_attempt() -> void:
	_clear_overlay()
	for n in get_tree().get_nodes_in_group("attacks"):
		n.queue_free()
	GameState.eclipse_active = false
	darkness = 0.0
	darkness_target = 0.0
	if is_instance_valid(hero):
		hero.queue_free()
	boss_max = GameState.boss_max_hp()
	boss_hp = boss_max
	boss.reset_cooldowns()
	boss.select(0)
	if not final_fight and (GameState.checkpoint.is_empty() or (GameState.is_checkpoint_attempt() and GameState.checkpoint_attempt() != GameState.attempt)):
		GameState.save_checkpoint()

	var st := GameState.hero_stats() if not final_fight else _stranger_stats()
	hero = HeroScript.new()
	hero.game = self
	hero.max_hp = st["hp"]
	hero.hp = st["hp"]
	hero.speed = st["speed"]
	hero.strike_damage = st["strike"]
	hero.windup_time = st["windup"]
	hero.armor_color = st["armor"]
	hero.cape_color = st["cape"]
	hero.form = st["form"]
	# He rises above you: bigger with every return, brighter, and later he descends through light.
	hero.hero_scale = st["scale"] * (1.0 + minf(0.25, 0.03 * (GameState.attempt - 1)))
	hero.tier = mini(GameState.level, 6)
	hero.power = (mini(GameState.level, 6) - 1) * 0.8 + (GameState.attempt - 1) * 0.35
	hero.descend = GameState.attempt > 1 or GameState.level >= 4
	hero.position = Vector3(randf_range(-2.0, 2.0), 0, -13.5 if not hero.descend else -11.0)
	if final_fight:
		_arm_stranger(hero)
	world.add_child(hero)
	hero.died.connect(_on_hero_died)
	hero.struck_boss.connect(_on_hero_struck)

	_rebuild_hud_rows()
	boss.apply_purity(GameState.purity())
	_set_daylight(false)
	_use_board_camera(false)
	board_hud.visible = false
	hud.visible = true
	star_bar.visible = not final_fight
	state = "fight"
	tick_acc = 0.0
	auto_parry_done = false
	_capture_mouse()
	if final_fight:
		show_message("THE STRANGER", "\"Let's see if you can surprise yourself.\"", 3.0)
		print("[FINAL] stranger hp %d strike %.1f style %s" % [int(st["hp"]), st["strike"], GameState.playstyle()])
		return
	var title: String = GameState.hero_data()["title"]
	var cp := "   ·   CHECKPOINT SAVED" if GameState.checkpoint_attempt() == GameState.attempt and GameState.attempt > 1 else ""
	if GameState.attempt == 1 and GameState.level == 1:
		tutorial("cast", "Aim with the MOUSE. LEFT-CLICK casts the selected skill at your crosshair.")
	elif GameState.attempt == 2:
		tutorial("stars", "The bar under his health is your progress. Outlast 5 of his lives for a STAR. You need a star to move on.")
	elif cp != "":
		tutorial("checkpoint", "CHECKPOINT saved. If he conquers you before you earn a star, you restart from here.")
	if GameState.attempt == 1:
		show_message(title + " APPROACHES", "He has come for your throne.", 3.0)
	elif not GameState.pending_lessons.is_empty():
		var learned: Array[String] = []
		for l in GameState.pending_lessons:
			var sk: Dictionary = GameState.SKILLS[l[0]]
			learned.append(("%s (MASTERED)" if l[1] >= 3 else "%s") % sk["counter"])
		show_message(title + " RETURNS. HE LEARNED.", "He will now " + ", ".join(learned) + cp, 3.0)
		tutorial("adapt", "He has ADAPTED to one of your skills. Visit the Grimoire between fights and swap in something he has not seen.")
		Sfx.play("learn")
		GameState.pending_lessons = []
	else:
		show_message(title + " RETURNS", ("Fight %d. He remembers every death." % GameState.attempt) + cp, 2.5)
	print("[ATTEMPT] L%d A%d hero hp %d strike %.1f speed %.2f" % [GameState.level, GameState.attempt, int(st["hp"]), st["strike"], st["speed"]])


func can_cast() -> bool:
	return state == "fight"


func spawn_attack(id: String) -> bool:
	if not can_cast() or not is_instance_valid(hero) or hero.dead:
		return false
	var dmg := GameState.damage_for(id) * final_bonus
	GameState.cast_count += 1
	if GameState.perks.has("surge") and GameState.cast_count % 5 == 0:
		dmg *= 1.0 + GameState.asc_mult()
		popup_text(boss.hand_tip() + Vector3(0, 0.4, -1.0), "SURGE", Color(1.0, 0.85, 0.4), 1.0)
	# The Stranger turns every few of your casts back on you (if you live by your skills).
	if hero.mirror_every > 0 and GameState.cast_count % hero.mirror_every == 0:
		popup_text(hero.center() + Vector3(0, 1.0, 0), "MIRRORED", Color(0.8, 0.3, 1.0), 1.2)
		spawn_burst(hero.center(), Color(0.8, 0.3, 1.0), 20)
		Sfx.play("parry", -4.0, 0.6)
		_take_blow(dmg * 0.4, false)
		tutorial("mirror", "He turned your own spell back on you. He reflects every few casts: mix in parries and leans, not just skills.")
		return true
	tut_casts += 1
	if tut_casts == 4:
		tutorial("select", "Press 1-4 (or scroll) to switch skills. Each one is countered differently, and he learns each separately.")
	var atk = ATTACKS[id].new()
	atk.setup(id, dmg, hero, self)
	atk.add_to_group("attacks")
	world.add_child(atk)
	var aim: Vector3 = boss.aim_point(hero)
	var hp: Vector3 = hero.global_position
	match id:
		"fireball", "lance", "volley":
			var from: Vector3 = boss.hand_tip()
			atk.global_position = from
			atk.dir = (aim - from).normalized()
		"spikes", "chains", "well", "pillar", "meteor", "bloom", "maw":
			atk.global_position = clamp_arena(aim)
		"slam", "tide", "stomp":
			atk.global_position = Vector3(boss_x(), 0, -1.6)
		"cinder", "bonecage", "masonry":
			atk.global_position = clamp_arena(aim)
		"glacier", "nullorb":
			var from2: Vector3 = boss.hand_tip()
			atk.global_position = from2
			atk.dir = (aim - from2).normalized()
		"sweep":
			atk.global_position = Vector3(boss_x(), 0, -0.6)
		"leech":
			atk.global_position = Vector3(boss_x(), 0, -2.4)
		"wall":
			atk.global_position = Vector3(0, 0, clampf(maxf(aim.z, hp.z + 1.8), -12.0, -3.2))
		"ghouls":
			atk.global_position = Vector3(boss_x(), 0, -2.4)
		_:
			atk.global_position = Vector3(hp.x, 0, hp.z)
	match id:
		"pillar":
			atk.radius = 1.3
			atk.delay = 0.55
		"meteor":
			atk.radius = 3.0
			atk.delay = 1.3
			atk.style = "meteor"
			atk.counter_label = "SPRINT"
		"bloom":
			atk.radius = 2.0
			atk.delay = 0.7
			atk.style = "frost"
			atk.slow_time = 2.5
		"cinder":
			atk.speed = 9.0
			atk.max_radius = 7.0
		"stomp":
			atk.speed = 12.0
			atk.max_radius = 12.0
			boss.shake(0.5)
		"bonecage":
			atk.radius = 1.6
			atk.hold = 2.0
		"nullorb":
			atk.homing = 2.2
			atk.speed = 6.0
			atk.size = 1.6
			atk.life = 7.0
		"leech":
			atk.count = 5
			atk.scale_g = 0.6
		"masonry":
			atk.radius = 2.0
			atk.delay = 0.9
			atk.style = "meteor"
			atk.counter_label = "SPRINT"
			atk.rock_size = 0.5
			atk.rock_start = boss.hand_tip() - atk.global_position
	atk.launch()
	if id == "volley" or id == "glacier":
		# Two more projectiles fanned out either side.
		for a in [-0.2, 0.2]:
			var extra = ATTACKS[id].new()
			extra.setup(id, dmg, hero, self)
			extra.add_to_group("attacks")
			world.add_child(extra)
			extra.global_position = atk.global_position
			extra.dir = (atk.dir as Vector3).rotated(Vector3.UP, a)
			extra.launch()
	elif id == "tide":
		get_tree().create_timer(0.45, false).timeout.connect(_second_tide)
	elif id == "thunder":
		get_tree().create_timer(0.55, false).timeout.connect(_second_thunder)
	Sfx.play("cast", -8.0, randf_range(0.8, 1.3))
	GameState.level_skills_used[id] = true
	return true


func _second_tide() -> void:
	if state != "fight" or not is_instance_valid(hero) or hero.dead:
		return
	var atk = ATTACKS["tide"].new()
	atk.setup("tide", GameState.damage_for("tide"), hero, self)
	atk.add_to_group("attacks")
	world.add_child(atk)
	atk.global_position = Vector3(boss_x(), 0, -1.6)
	atk.launch()


func _second_thunder() -> void:
	if state != "fight" or not is_instance_valid(hero) or hero.dead:
		return
	var atk = ATTACKS["thunder"].new()
	atk.setup("thunder", GameState.damage_for("thunder"), hero, self)
	atk.add_to_group("attacks")
	world.add_child(atk)
	var hp: Vector3 = hero.global_position
	atk.global_position = Vector3(hp.x, 0, hp.z)
	atk.launch()


## Your position along the dais (you can lean with A/D).
func boss_x() -> float:
	return boss.position.x


func spawn_hero_bolt(from: Vector3, dmg: float) -> void:
	if state != "fight":
		return
	tutorial("bolt", "A HOLY BOLT flies at your face. PARRY it as it arrives, or LEAN out of its path.", true)
	var b = HeroBoltScript.new()
	b.game = self
	b.damage = dmg
	b.target = boss.head.global_position + Vector3(0, -0.2, -0.6)
	b.add_to_group("attacks")
	b.add_to_group("hero_bolts")
	world.add_child(b)
	b.global_position = from


func heal_boss(amount: float) -> void:
	if state != "fight":
		return
	boss_hp = minf(boss_max, boss_hp + amount)
	popup_text(Vector3(0, 1.6, -1.8), "+%d WILL" % int(amount), Color(1.0, 0.3, 0.35), 1.0)


func on_hero_damaged(h, dmg: float, skill_id: String) -> void:
	if GameState.active_class == "blood" and state == "fight":
		boss_hp = minf(boss_max, boss_hp + dmg * 0.1)
	var col: Color = GameState.SKILLS[skill_id]["color"]
	popup_text(h.center() + Vector3(randf_range(-0.3, 0.3), 0.9, 0), str(int(round(dmg))), col, 1.2)


func _on_hero_struck(dmg: float) -> void:
	_take_blow(dmg, true)


func on_hero_struck_ranged(dmg: float, target: Vector3) -> void:
	# A bolt aimed where your head WAS: lean out of its path and it only grazes you.
	if absf(target.x - boss.head.global_position.x) > 1.0:
		popup_text(target, "GRAZED", Color(0.8, 0.9, 1.0), 1.0)
		dmg *= GameState.graze_taken()
	_take_blow(dmg, false)


## Every blow he lands on you. Inside your parry window it only grazes a lesser part of you.
func _take_blow(dmg: float, melee: bool) -> void:
	if state != "fight":
		return
	var parried: bool = boss.is_parrying()
	if parried and melee and is_instance_valid(hero) and hero.unparryable:
		parried = false
		popup_text(Vector3(0, 2.0, -1.6), "UNPARRYABLE", Color(0.8, 0.3, 1.0), 1.2)
		tutorial("violet", "A VIOLET blade cannot be parried. LEAN out of it with A / D.")
	if parried:
		dmg *= GameState.parry_taken()
		GameState.on_parry()
		boss.parried()
		Sfx.play("parry")
		flash(Color(1.0, 0.95, 0.7), 0.25)
		spawn_burst(Vector3(0, 1.9, -1.3), Color(1.0, 0.9, 0.5), 26)
		popup_text(Vector3(0, 2.0, -1.6), "PARRIED · ONLY %d" % int(round(dmg)), Color(1.0, 0.92, 0.6), 1.2)
		if melee and GameState.perks.has("riposte") and is_instance_valid(hero) and not hero.dead:
			hero.stun(1.0)
			hero.announce("STAGGERED")
	else:
		boss.hurt()
		Sfx.play("boss_hurt")
		hurt_overlay.color.a = 0.5
		spawn_burst(Vector3(0, 1.8, -1.4), Color(1, 0.3, 0.2), 14)
	boss_hp -= dmg
	print("[STRIKE] hero hits boss for %.1f (parried=%s), boss %d/%d" % [dmg, parried, int(boss_hp), int(boss_max)])
	if boss_hp <= 0.0:
		boss_hp = 0.0
		_on_boss_defeated()


func _on_hero_died() -> void:
	if state != "fight":
		return
	if final_fight:
		_final_won()
		return
	state = "hero_fallen"
	Sfx.play("death")
	GameState.on_hero_death()
	tutorial("learn", "He died... and he remembers. Every skill he saw, he learns a little. After about 5 fights he masters it.")
	show_message("THE HERO FALLS", "...but he will return. He remembers.", 2.4)
	get_tree().create_timer(2.4).timeout.connect(_open_throne)


func _on_boss_defeated() -> void:
	state = "boss_fallen"
	for n in get_tree().get_nodes_in_group("attacks"):
		n.queue_free()
	GameState.eclipse_active = false
	set_darkness(false)
	hero.celebrate()
	if final_fight:
		_final_lost()
		return
	GameState.on_boss_defeated(not hero.took_damage)
	hurt_overlay.color.a = 0.8
	Sfx.play("slam", 4.0, 0.6)
	if GameState.last_stars == 0:
		show_message("CONQUERED TOO SOON", "He needed only %d deaths. You need a star to pass him." % (GameState.attempt - 1), 2.8)
		get_tree().create_timer(3.0).timeout.connect(_show_try_again)
	else:
		show_message("CONQUERED", "He stands over you... and ascends.", 2.8)
		get_tree().create_timer(3.0).timeout.connect(_show_prestige)


## Lessons are announced when he returns (see _start_attempt); here we just update his scars.
func _on_mastery_milestone(_skill_id: String, _tier: int) -> void:
	if is_instance_valid(hero):
		hero.refresh_sigils()


# =============================================================================
# Input & per-frame
# =============================================================================

func _input(event: InputEvent) -> void:
	if state == "board" and not is_instance_valid(overlay):
		if event is InputEventKey and event.pressed and not event.echo:
			match event.keycode:
				KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
					_board_advance()
				KEY_T:
					throne_mode = "board"
					_open_throne()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_board_advance()
		return
	if state == "fight" and not get_tree().paused and not is_instance_valid(overlay):
		if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			boss.look(event.relative)
		elif event is InputEventMouseButton and event.pressed:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				_capture_mouse()
			elif event.button_index == MOUSE_BUTTON_LEFT:
				boss.try_cast(boss.selected_id())
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				boss.try_parry()
			elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
				boss.cycle(-1)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				boss.cycle(1)
		elif event is InputEventKey and event.pressed and not event.echo:
			match event.keycode:
				KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
					boss.select(event.keycode - KEY_1)
				KEY_ESCAPE:
					_pause()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F2:
			pixel_index = (pixel_index + 1) % pixel_scales.size()
			view_container.stretch_shrink = pixel_scales[pixel_index]


func _process(delta: float) -> void:
	# Lighting: flicker + eclipse darkness.
	darkness = move_toward(darkness, darkness_target, delta * 2.5)
	env.ambient_light_energy = 0.4 * (1.0 - 0.9 * darkness)
	for entry in lights:
		var l: Light3D = entry[0]
		var flick := (0.85 + randf() * 0.15) if entry[2] else 1.0
		l.light_energy = entry[1] * flick * (1.0 - 0.92 * darkness)

	hurt_overlay.color.a = move_toward(hurt_overlay.color.a, 0.0, delta * 1.5)
	flash_overlay.color.a = move_toward(flash_overlay.color.a, 0.0, delta * 2.0)

	if state == "fight" or state == "hero_fallen" or state == "boss_fallen":
		_update_hud()
	var lean := 0.0
	if state == "fight" and not get_tree().paused:
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			lean -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			lean += 1.0
	if state == "fight" and is_instance_valid(hero) and not hero.dead:
		if hero.state == "windup":
			tutorial("parry", "His blade glows RED: he is about to strike. RIGHT-CLICK to PARRY and take only 15%.", true)
			if GameState.attempt >= 2 or GameState.level > 1:
				tutorial("lean", "Or LEAN with A / D as he swings. Out of his reach, his blow only grazes you (30%).", true)
		elif hero.state == "lunge_charge":
			tutorial("lunge", "He crouches to LUNGE from range. Parry or lean when he lands.", true)
		elif hero.state == "leap_charge":
			tutorial("leap", "He is about to LEAP onto your dais. A heavy blow. Parry or lean as he lands.", true)
	if state == "fight" and GameState.autoplay:
		_autoplay_fight(delta)
		if auto_lean_t > 0.0:
			auto_lean_t -= delta
			lean = auto_lean_dir
	boss.lean_input = lean
	# The combat clock.
	if state == "fight" and not get_tree().paused:
		tick_acc += delta
		while tick_acc >= GameState.TICK and state == "fight":
			tick_acc -= GameState.TICK
			_fight_tick()
		if final_fight and state == "fight" and is_instance_valid(hero) and not hero.dead:
			if final_phase == 0 and hero.hp < hero.max_hp * 0.66:
				_final_phase_card()
			elif final_phase == 1 and hero.hp < hero.max_hp * 0.33:
				_final_phase_card()
	if state == "board" and GameState.autoplay and not is_instance_valid(overlay):
		auto_t -= delta
		if auto_t <= 0.0:
			auto_t = 0.7
			_board_advance()


## One combat tick: your queued cast/parry, his thinking, holy bolts landing, then cooldowns.
func _fight_tick() -> void:
	boss.on_tick_begin()
	if state == "fight" and is_instance_valid(hero) and not hero.dead:
		hero.on_tick()
	for b in get_tree().get_nodes_in_group("hero_bolts"):
		if b.arrived and state == "fight":
			b.resolve()
	boss.on_tick_end()


func _autoplay_fight(delta: float) -> void:
	if not is_instance_valid(hero) or hero.dead:
		return
	var lead: Vector3 = hero.center() + hero.last_vel * 0.45
	boss.look_toward(lead, delta)
	_autoplay_parry()
	auto_t -= delta
	if auto_t > 0.0:
		return
	auto_t = randf_range(0.25, 0.6)
	if OS.get_cmdline_user_args().has("--passive"):
		return  # Test mode: never attack, so the hero conquers early (exercises TRY AGAIN).
	var ready: Array[String] = []
	for id in GameState.loadout:
		if boss.cooldown_left(id) <= 0.0:
			ready.append(id)
	if not ready.is_empty():
		var id: String = ready.pick_random()
		boss.select(GameState.loadout.find(id))
		boss.try_cast(id)


## Bot parries most blows: queued on the tick before his swing lands (his countdown reads 1),
## or as a holy bolt arrives. A violet (unparryable) blade it leans out of instead.
func _autoplay_parry() -> void:
	var due := false
	if hero.state == "windup" and hero.windup_ticks - hero.state_ticks <= 1:
		due = true
	elif hero.state == "leap" and hero.state_t > hero.LEAP_TIME - GameState.TICK:
		due = true
	for b in get_tree().get_nodes_in_group("hero_bolts"):
		if b.ticks_left() <= 0:
			due = true
	if due and not auto_parry_done:
		auto_parry_done = true
		var r := randf()
		if hero.state == "windup" and hero.unparryable_next():
			auto_lean_dir = 1.0 if boss_x() < 0.5 else -1.0
			auto_lean_t = 0.6
		elif r < 0.5:
			boss.try_parry()
		elif r < 0.75 and hero.state == "windup":
			# Lean out of the way instead.
			auto_lean_dir = 1.0 if boss_x() < 0.5 else -1.0
			auto_lean_t = 0.45
	elif not due:
		auto_parry_done = false


func _pause() -> void:
	get_tree().paused = true
	_show_card("PAUSED", "Your thoughts are still.", "RESUME", func():
		get_tree().paused = false
		_clear_overlay()
		_capture_mouse())


func _capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# =============================================================================
# Theme & widget helpers
# =============================================================================

func _make_theme() -> Theme:
	# Pixel bitmap font everywhere (native 8px; sizes are snapped to multiples of 8 in _label).
	var th := Theme.new()
	th.default_font = UiArt.pixel_font()
	th.default_font_size = 16
	th.set_color("font_color", "Label", TEXT)
	th.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.8))
	th.set_constant("shadow_offset_x", "Label", 2)
	th.set_constant("shadow_offset_y", "Label", 2)
	th.set_constant("line_spacing", "Label", 4)
	th.set_stylebox("normal", "Button", UiArt.pill_box(Color("a8302a")))
	th.set_stylebox("hover", "Button", UiArt.pill_box(Color("e0503a")))
	th.set_stylebox("pressed", "Button", UiArt.pill_box(Color("ff7a4a")))
	th.set_stylebox("disabled", "Button", UiArt.pill_box(Color("3a2a2e")))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", Color("fff0d0"))
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", Color(0.5, 0.45, 0.45))
	th.set_stylebox("panel", "PanelContainer", UiArt.frame_box(Color("f29a2e"), Color(0.06, 0.035, 0.09, 0.94)))
	return th


func _sb(bg: Color, border: Color, margin: float = 8.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_content_margin_all(margin)
	return sb


func _label(text: String, size: int = 18, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", maxi(16, int(round(size / 8.0)) * 8))
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _bar(fill: Color, w: float, h: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(w, h)
	b.max_value = 1.0
	b.step = 0.0
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.03, 0.05, 0.85)
	bg.border_color = Color(0.35, 0.27, 0.2)
	bg.set_border_width_all(2)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	return b


func _button(text: String, cb: Callable, min_w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(min_w, 40)
	b.pressed.connect(cb)
	return b


func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


# =============================================================================
# HUD
# =============================================================================

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	hud = Control.new()
	hud.theme = theme_res
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	hurt_overlay = ColorRect.new()
	hurt_overlay.color = Color(0.6, 0.0, 0.0, 0.0)
	hurt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hurt_overlay)
	hurt_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_overlay = ColorRect.new()
	flash_overlay.color = Color(1, 1, 1, 0)
	flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(flash_overlay)
	flash_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Hero: top center
	var top := VBoxContainer.new()
	_anchor(top, 0.5, 0.0, 0.5, 0.0, -240, 14, 240, 130)
	hud.add_child(top)
	hero_title = _label("", 22, GOLD)
	hero_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(hero_title)
	hero_bar = _bar(Color(0.85, 0.78, 0.5), 480, 14)
	top.add_child(hero_bar)
	star_bar = StarBarScript.new()
	top.add_child(star_bar)

	# Boss: bottom center
	var bottom := VBoxContainer.new()
	_anchor(bottom, 0.5, 1.0, 0.5, 1.0, -290, -176, 290, -4)
	bottom.add_theme_constant_override("separation", 6)
	hud.add_child(bottom)
	boss_label = _label("YOUR WILL", 16, BLOOD)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(boss_label)
	boss_bar = _bar(Color(0.7, 0.08, 0.1), 500, 14)
	bottom.add_child(boss_bar)
	hotbar = HotbarScript.new()
	hotbar.boss = boss
	bottom.add_child(hotbar)

	# Top-left: run info
	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", 8)
	_anchor(info, 0, 0, 0, 0, 16, 12, 320, 60)
	hud.add_child(info)
	var flame := TextureRect.new()
	flame.texture = UiArt.icon("dread")
	flame.custom_minimum_size = Vector2(40, 40)
	flame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	info.add_child(flame)
	dread_label = _label("", 32, Color(0.56, 0.85, 1.0))
	info.add_child(dread_label)
	level_label = _label("", 16, DIM)
	level_label.visible = false

	# Right: what the hero knows about each equipped skill.
	var insight_panel := PanelContainer.new()
	_anchor(insight_panel, 1, 0, 1, 0, -236, 12, -12, 60)
	hud.add_child(insight_panel)
	insight_box = VBoxContainer.new()
	insight_panel.add_child(insight_box)

	# Crosshair
	for r in [Rect2(-1, -7, 2, 14), Rect2(-7, -1, 14, 2)]:
		var c := ColorRect.new()
		c.color = Color(1, 0.9, 0.8, 0.7)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_anchor(c, 0.5, 0.5, 0.5, 0.5, r.position.x, r.position.y, r.end.x, r.end.y)
		hud.add_child(c)

	# Center messages
	var msg := VBoxContainer.new()
	_anchor(msg, 0, 0.22, 1, 0.22, 0, 0, 0, 100)
	hud.add_child(msg)
	message_label = _label("", 40, GOLD)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_constant_override("outline_size", 8)
	msg.add_child(message_label)
	sub_message_label = _label("", 20, TEXT)
	sub_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_child(sub_message_label)
	msg.modulate.a = 0.0
	hud.visible = false


func _anchor(c: Control, al: float, at: float, ar: float, ab: float, ol: float, ot: float, orr: float, ob: float) -> void:
	c.anchor_left = al
	c.anchor_top = at
	c.anchor_right = ar
	c.anchor_bottom = ab
	c.offset_left = ol
	c.offset_top = ot
	c.offset_right = orr
	c.offset_bottom = ob


func show_message(main: String, sub: String = "", duration: float = 2.0) -> void:
	message_label.text = main
	sub_message_label.text = sub
	var box: Control = message_label.get_parent()
	if message_tween:
		message_tween.kill()
	message_tween = create_tween()
	box.modulate.a = 1.0
	message_tween.tween_interval(duration)
	message_tween.tween_property(box, "modulate:a", 0.0, 0.6)


func _rebuild_hud_rows() -> void:
	_clear(insight_box)
	insight_rows.clear()
	insight_box.add_child(_label("HE KNOWS", 16, GOLD))
	for id in GameState.loadout:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 8)
		var ic := TextureRect.new()
		ic.texture = UiArt.icon(id)
		ic.custom_minimum_size = Vector2(24, 24)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		top.add_child(ic)
		var tl := _label("", 16)
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(tl)
		row.add_child(top)
		var bar := _bar(Color(1, 0.5, 0.2), 190, 4)
		row.add_child(bar)
		insight_box.add_child(row)
		insight_rows.append({"id": id, "tier": tl, "bar": bar})


func _update_hud() -> void:
	var L: Dictionary = GameState.level_data()
	level_label.text = "CHAPTER %d / %d  ·  CROWNS %d" % [GameState.level, GameState.max_level(), GameState.crowns]
	dread_label.text = "%d" % int(GameState.dread)
	if is_instance_valid(hero):
		hero_title.text = "THE STRANGER  ·  THE LAST NIGHT" if final_fight else "%s  ·  FIGHT %d" % [L["title"], GameState.attempt]
		hero_bar.value = hero.hp / hero.max_hp
	boss_bar.value = boss_hp / boss_max
	boss_label.text = "YOUR WILL  %d / %d" % [int(ceil(boss_hp)), int(boss_max)]

	for r in insight_rows:
		var m := GameState.get_mastery(r["id"])
		var tr := GameState.tier(m)
		var tl: Label = r["tier"]
		tl.text = GameState.TIER_NAMES[tr]
		tl.add_theme_color_override("font_color", GameState.TIER_COLORS[tr])
		r["bar"].value = m


# =============================================================================
# Overlay cards (title, intros, results, ending, pause)
# =============================================================================

func _clear_overlay() -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null


func _new_overlay(alpha: float = 0.82) -> Control:
	_clear_overlay()
	var o := ColorRect.new()
	o.color = Color(0.01, 0.0, 0.02, alpha)
	o.theme = theme_res
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_layer.add_child(o)
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay = o
	_release_mouse()
	return o


func _show_card(title: String, body: String, button_text: String, on_press: Callable, title_color: Color = GOLD) -> void:
	var o := _new_overlay()
	var center := CenterContainer.new()
	o.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	panel.add_child(vb)
	var tl := _label(title, 40 if title.length() <= 22 else 24, title_color)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.custom_minimum_size = Vector2(700, 0)
	vb.add_child(tl)
	var bl := _label(body, 18)
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bl.custom_minimum_size = Vector2(700, 0)
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(bl)
	var b := _button(button_text, on_press, 260)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(b)
	card_button = b
	if GameState.autoplay and title != "PAUSED":
		get_tree().create_timer(1.0).timeout.connect(_auto_press_card)


## An Inscryption-style event card with several choices. options: [[label, Callable], ...]
func _show_choice(title: String, body: String, icon_id: String, options: Array) -> void:
	var o := _new_overlay(0.7)
	var center := CenterContainer.new()
	o.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)
	if icon_id != "":
		var ic := TextureRect.new()
		ic.texture = UiArt.icon(icon_id)
		ic.custom_minimum_size = Vector2(72, 72)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vb.add_child(ic)
	var tl := _label(title, 32, GOLD)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(tl)
	var bl := _label(body, 16)
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bl.custom_minimum_size = Vector2(640, 0)
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(bl)
	var first := true
	for opt in options:
		var b := _button(str(opt[0]), opt[1], 560)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vb.add_child(b)
		if first:
			card_button = b
			first = false
	if GameState.autoplay:
		get_tree().create_timer(1.0).timeout.connect(_auto_press_card)


func _auto_press_card() -> void:
	if is_instance_valid(card_button):
		card_button.pressed.emit()


func _show_title() -> void:
	state = "title"
	last_chapter_shown = -1
	_show_card("OVERTHRONE",
		"You are the Hollow King: a tyrant the city of Vael is terrified of.\n\n"
		+ "By day you walk its streets. By night, at the corner table of the Hollow Flagon, a man in white "
		+ "plays a board game with you: the map of your own life. At the end of every road a hero comes to take "
		+ "your throne. Each one that falls comes back, and learns.\n\n"
		+ "Seven days. Six nights. Somewhere in all of it is the man you used to be.",
		"WAKE", _show_wake)


func _show_level_intro() -> void:
	if state == "intro":
		return  # already shown (the landing timer and a board click can both ask)
	state = "intro"
	var H: Dictionary = GameState.hero_data()
	var moves: Array[String] = []
	for m in H["moves"]:
		moves.append({"strike": "STRIKE", "lunge": "LUNGE", "bolt": "HOLY BOLT", "leap": "JUDGMENT LEAP"}.get(m, m))
	var body: String = H["lore"] + "\n\nHIS MOVES: " + ", ".join(moves)
	body += "\nSTARS AT 5 / 8 / 11 OF HIS DEATHS  ·  CHECKPOINT EVERY 3 FIGHTS"
	_show_card("CHALLENGER %d / %d: %s" % [GameState.level, GameState.max_level(), H["title"]], body, "LET HIM COME", _start_attempt)


func _show_try_again() -> void:
	state = "try_again"
	hud.visible = false
	var deaths := GameState.attempt - 1
	var body := "%s conquered you after only %d death%s.\n" % [GameState.hero_data()["title"], deaths, "" if deaths == 1 else "s"]
	body += "You need a star (5 of his deaths) to pass him.\n\n"
	body += "Return to your checkpoint: FIGHT %d.\nHis memory, your Dread, perks and rites roll back to that moment." % GameState.checkpoint_attempt()
	_show_card("NOT YET WORTHY", body, "TRY AGAIN", _retry_from_checkpoint, BLOOD)


func _retry_from_checkpoint() -> void:
	GameState.restore_checkpoint()
	_start_attempt()


func _show_prestige() -> void:
	state = "prestige"
	hud.visible = false
	_clear_overlay()
	var p = PrestigeScript.new()
	p.theme = theme_res
	p.setup(GameState.hero_data()["title"], GameState.last_crowns, GameState.last_crowns_total, GameState.next_hero_data(), GameState.is_final_hero(), GameState.last_stars)
	overlay_layer.add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.finished.connect(_after_prestige)
	overlay = p
	_release_mouse()


func _after_prestige() -> void:
	var chapter := GameState.level - 1
	var ch: Dictionary = Story.CHAPTERS[chapter]
	GameState.restore_memory(chapter, ch["relic"])
	GameState.prestige()
	var relic: Dictionary = GameState.RELICS[ch["relic"]]
	var body: String = ch["memory"] + "\n\nRELIC RESTORED: %s  (%s)" % [relic["name"].to_upper(), relic["desc"]]
	if chapter + 1 < Story.CHAPTERS.size():
		body += "\n\nTHE ROAD TO %s OPENS." % Story.CHAPTERS[chapter + 1]["region"]
	else:
		body += "\n\nEvery name is remembered. Across the table, the Stranger has stopped smiling."
	Sfx.play("reveal")
	_show_card("MEMORY RESTORED: " + str(ch["memory_title"]), body, "SLEEP", _show_wake)


# =============================================================================
# Days and nights: wake in Vael, walk it until dusk, then the Stranger and the board
# =============================================================================

func _build_overworld() -> void:
	ow = OverworldScript.new()
	ow.game = self
	world.add_child(ow)
	ow.position = Vector3(0, 0, 600)
	ow.dusk_met.connect(_on_dusk_met)


## By day the arena's lights go dark and Vael's own sun and sky take over.
func _set_daylight(on: bool) -> void:
	for entry in lights:
		(entry[0] as Light3D).visible = not on
	world_env.environment = ow.env if on else env
	if on != ow.active:
		ow.set_active(on)


func _show_wake() -> void:
	state = "wake"
	hud.visible = false
	board_hud.visible = false
	var w: Array = Dialogue.WAKE[clampi(GameState.level - 1, 0, Dialogue.WAKE.size() - 1)]
	var body: String = w[1]
	if GameState.level == 1:
		body += "\n\nYou do not remember how you got here. You do remember the crown. It is still on your head."
	elif GameState.is_final_night():
		body += "\n\nThe last day. Tonight there will be no board."
	_show_card("DAY %d" % GameState.level, body, "RISE", func(): _show_remembrance(_enter_day))


func _enter_day() -> void:
	state = "day"
	_clear_overlay()
	hud.visible = false
	board_hud.visible = false
	_set_daylight(true)
	ow.begin_day()
	_capture_mouse()
	print("[DAY] %d begins, dread %d, deeds %d, weapon %s" % [GameState.level, int(GameState.dread), GameState.deeds.size(), GameState.weapon])


## The Stranger has reached you at dusk.
func _on_dusk_met() -> void:
	if state != "day":
		return
	print("[DUSK] day %d over, deeds %d, dread %d" % [GameState.level, GameState.deeds.size(), int(GameState.dread)])
	if GameState.is_final_night():
		_set_daylight(false)
		_show_final_intro()
		return
	state = "dusk"
	var line: Array = Dialogue.STRANGER_NIGHT[clampi(GameState.level - 1, 0, Dialogue.STRANGER_NIGHT.size() - 1)]
	_show_card("THE HOLLOW FLAGON · NIGHT %d" % GameState.level, "%s\n\n%s" % [line[0], line[1]], "SIT DOWN", _enter_night)


func _enter_night() -> void:
	_set_daylight(false)
	if GameState.level == 5 and not GameState.revealed:
		GameState.revealed = true
		board.refresh()
		Sfx.play("reveal", 0.0, 0.7)
		_show_card("HE LOWERS HIS HOOD", Dialogue.REVEAL, "PLAY", _enter_night)
		return
	night_shown = GameState.level
	_enter_board()
	board.peek_stranger()
	if GameState.level - 1 > fog_revealed:
		fog_revealed = GameState.level - 1
		board.reveal_chapter(GameState.level - 1)
		narrate("The fog thins. I remember a little more. My hands feel... cleaner.")
	tutorial("stranger", "Each night you play the board against the Stranger. Your piece walks the road of your life; at its end, a challenger waits.")


# =============================================================================
# The last night: no board. The Stranger has watched every move you made all week.
# =============================================================================

func _show_final_intro() -> void:
	state = "final_intro"
	hud.visible = false
	board_hud.visible = false
	var line: Array = Dialogue.STRANGER_NIGHT[Dialogue.STRANGER_NIGHT.size() - 1]
	var ps := GameState.playstyle()
	var fav := GameState.favorite_skill()
	var read: String = {
		"parry": "You raise your guard on the beat, every time. Every third blow of his will burn violet: it cannot be parried.",
		"lean": "You lean out of everything. His blade will follow you wherever you lean.",
		"caster": "You live by your skills. %s will not touch him, he blinks out of what you throw, and every fifth spell comes back at you." % str(GameState.SKILLS[fav]["name"]) if fav != "" else "You live by your skills.",
	}[ps]
	var heart := ""
	if GameState.kindness > GameState.cruelty + 2:
		heart = "\n\n\"You paid when they were too frightened to ask. I noticed.\""
	elif GameState.cruelty > GameState.kindness + 2:
		heart = "\n\n\"You took their coin because you could. I carried that too.\""
	_show_card("THE LAST NIGHT", "%s\n\n%s\n\nHE HAS STUDIED YOU: %s%s" % [line[0], line[1], read, heart], "FACE HIM", _start_final)


func _start_final() -> void:
	final_fight = true
	final_phase = 0
	final_bonus = 1.0
	final_forgot = false
	GameState.attempt = 1
	# Everything you can do, he has already seen: he knows it all well, your favorite perfectly.
	var fav := GameState.favorite_skill()
	for id in GameState.SKILLS:
		GameState.fights[id] = GameState.fights_to_master() - 0.5
	if fav != "":
		GameState.fights[fav] = GameState.fights_to_master()
	_start_attempt()


func _stranger_stats() -> Dictionary:
	var c := GameState.stranger_corruption()
	return {
		"hp": 700.0 + 40.0 * GameState.deeds.size(),
		"strike": 30.0,
		"speed": 4.4,
		"windup": 0.42,
		"armor": Color(0.15, 0.1, 0.18),
		"cape": Color(0.94, 0.93, 0.9).lerp(Color(0.08, 0.06, 0.1), c),
		"form": 4,
		"scale": 1.2,
	}


## His counters are built from how you fought all week (GameState.playstyle).
func _arm_stranger(h) -> void:
	h.stranger = true
	h.descend = true
	match GameState.playstyle():
		"parry":
			h.unparryable_every = 3
		"lean":
			h.always_track = true
		_:
			h.nullify_skill = GameState.favorite_skill()
			h.mirror_every = 5
			h.blink = true


## At 66% and 33% of his life the fight stops, and you choose what to become.
func _final_phase_card() -> void:
	final_phase += 1
	get_tree().paused = true
	var fav := GameState.favorite_skill()
	var opts: Array = []
	if not final_forgot and fav != "":
		opts.append(["LET HIM FORGET: he loses all he knows of %s" % str(GameState.SKILLS[fav]["name"]).to_upper(), _final_choice.bind("forget")])
	else:
		opts.append(["LET HIM FORGET: everything he knows of you is halved", _final_choice.bind("forget_all")])
	opts.append(["REMEMBER WHO YOU WERE: restore half your Will", _final_choice.bind("will")])
	opts.append(["BECOME SOMEONE NEW: your skills deal +35% damage tonight", _final_choice.bind("power")])
	var line := "\"You're better than you think. Worse, too.\" He staggers, and smiles." if final_phase == 1 else "\"There it is. That's the man I've been carrying all week.\""
	_show_choice("THE STRANGER FALTERS", line, "", opts)


func _final_choice(kind: String) -> void:
	match kind:
		"forget":
			var fav := GameState.favorite_skill()
			GameState.fights[fav] = 0.0
			GameState.temp.erase(fav)
			final_forgot = true
			if is_instance_valid(hero):
				if hero.nullify_skill == fav:
					hero.nullify_skill = ""
				hero.refresh_sigils()
		"forget_all":
			for id in GameState.fights:
				GameState.fights[id] *= 0.5
			if is_instance_valid(hero):
				hero.refresh_sigils()
		"will":
			boss_hp = minf(boss_max, boss_hp + boss_max * 0.5)
		"power":
			final_bonus += 0.35
	print("[FINAL] phase %d choice %s" % [final_phase, kind])
	get_tree().paused = false
	_clear_overlay()
	_capture_mouse()


func _final_won() -> void:
	state = "ending"
	final_fight = false
	Sfx.play("death")
	for n in get_tree().get_nodes_in_group("attacks"):
		n.queue_free()
	print("[FINAL] won")
	show_message("HE KNEELS", "", 2.4)
	get_tree().create_timer(2.6).timeout.connect(func():
		_show_card("HE KNEELS",
			"The Stranger goes down on one knee, and laughs, and for once it is not a sad sound.\n\n"
			+ "\"There you are.\" He takes your hands. The rot runs out of his and does not come back into yours. "
			+ "It simply ends.\n\nThen there is only one of you, and you are not alone in your skin any more.",
			"STAND UP", _show_ending))


func _final_lost() -> void:
	print("[FINAL] lost")
	show_message("HE KNOWS YOU TOO WELL", "", 2.4)
	get_tree().create_timer(2.8).timeout.connect(func():
		_show_card("HE KNOWS YOU TOO WELL", "\"Again. You can do better than you. I've seen it.\"\n\nHe resets the night. Everything he learned, he keeps.", "AGAIN", _start_final, BLOOD))


func _show_ending() -> void:
	state = "ending"
	hud.visible = false
	var body: String = Story.ENDING
	body += "\n\nYou carry %d Crowns, every unlocked class and every Eternity upgrade into the next cycle." % GameState.crowns
	body += "\n\n— END OF CHAPTER ONE —"
	GameState.runs_completed += 1
	print("[ENDING] crowns=%d total deaths=%d" % [GameState.crowns, GameState.total_deaths])
	_show_card("THE KING IS WHOLE", body, "BEGIN A NEW CYCLE", func():
		if quit_at_end:
			get_tree().quit()
			return
		GameState.reset_run()
		night_shown = -1
		fog_revealed = 0
		_show_title())


# =============================================================================
# The Throne of Thought: a pixel-art Tree of Life (see ui/throne_tree.gd)
# =============================================================================

func _open_throne() -> void:
	state = "throne"
	hud.visible = false
	_clear_overlay()
	var tree = ThroneTreeScript.new()
	tree.game = self
	tree.theme = theme_res
	if throne_mode == "prestige":
		tree.page = "eternity"
		tree.go_label = "MEET " + str(GameState.hero_data()["title"])
	elif throne_mode == "board":
		tree.go_label = "RETURN TO THE BOARD"
	if throne_mode == "between":
		tutorial("rite", "Between his deaths: spend DREAD at the RITE (the roots) for powers he has never seen. Equip them on the GRIMOIRE page.")
	else:
		tutorial("throne", "The Throne of Thought. Q / E switch pages: GRIMOIRE (skills & classes), ASCENSION (perks), ETERNITY (permanent).")
	overlay_layer.add_child(tree)
	tree.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tree.let_him_come.connect(_close_throne)
	overlay = tree
	_release_mouse()
	if preview_focus != "":
		tree.focus = tree.node_index("skill", preview_focus)
		tree.lock_focus = true
	if preview_rite:
		tree._open_rite()


func _close_throne() -> void:
	if state != "throne":
		return
	if throne_mode == "prestige":
		throne_mode = "between"
		_show_level_intro()
		return
	if throne_mode == "board":
		throne_mode = "between"
		_enter_board()
		return
	_start_attempt()


# =============================================================================
# The Board: the Hollow King's journey (see board.gd and story.gd)
# =============================================================================

func _build_board() -> void:
	board = BoardScript.new()
	board.game = self
	world.add_child(board)
	board.position = Vector3(300, 0, 0)
	board.arrived.connect(_on_tile)


func _use_board_camera(on: bool) -> void:
	board.cam.current = on
	boss.cam.current = not on


func _build_board_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	board_hud = Control.new()
	board_hud.theme = theme_res
	board_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(board_hud)
	board_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var info := VBoxContainer.new()
	_anchor(info, 0, 0, 0, 0, 20, 16, 700, 140)
	board_hud.add_child(info)
	chapter_label = _label("", 24, GOLD)
	info.add_child(chapter_label)
	board_info = _label("", 16, TEXT)
	info.add_child(board_info)
	narration = _label("", 24, Color(0.95, 0.9, 0.8))
	narration.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	narration.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_anchor(narration, 0.5, 1.0, 0.5, 1.0, -520, -150, 520, -60)
	board_hud.add_child(narration)
	board_prompt = _label("SPACE / CLICK: ADVANCE    ·    T: THRONE OF THOUGHT", 16, DIM)
	board_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anchor(board_prompt, 0.5, 1.0, 0.5, 1.0, -400, -40, 400, -16)
	board_hud.add_child(board_prompt)
	banner = _label("", 40, GOLD)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anchor(banner, 0, 0.3, 1, 0.3, 0, 0, 0, 60)
	banner.modulate.a = 0.0
	board_hud.add_child(banner)
	board_hud.visible = false


func _enter_board() -> void:
	state = "board"
	_clear_overlay()
	hud.visible = false
	board_hud.visible = true
	_release_mouse()
	_use_board_camera(true)
	board.refresh()
	board.snap_to_current()
	_update_board_hud()
	boss.apply_purity(GameState.purity())
	if GameState.board_tile < 0 and last_chapter_shown < 0:
		narrate("\"Your move,\" he says. This board is my life. Somewhere on it, I lost myself.")
		_chapter_banner(0)
	tutorial("board", "This board is your life. SPACE or CLICK moves your piece one tile. T opens the Throne of Thought.")
	if GameState.memories.size() >= 1:
		tutorial("crowns", "CROWNS are forever. Spend them in the Throne: unlock CLASSES on their sigils, and buy ETERNITY upgrades.")


func _update_board_hud() -> void:
	var c := clampi(GameState.level - 1, 0, Story.CHAPTERS.size() - 1)
	var roman := ["I", "II", "III", "IV", "V", "VI"]
	chapter_label.text = "CHAPTER %s · %s" % [roman[c], Story.CHAPTERS[c]["region"]]
	var relic_names: Array[String] = []
	for r in GameState.relics:
		relic_names.append(GameState.RELICS[r]["name"])
	board_info.text = "MEMORIES %d / %d   ·   FRAGMENTS %d   ·   CROWNS %d   ·   CLASS %s" % [
		GameState.memories.size(), Story.CHAPTERS.size(), GameState.fragments, GameState.crowns,
		GameState.CLASSES[GameState.active_class]["name"]]
	if not relic_names.is_empty():
		board_info.text += "\nRELICS: " + ", ".join(relic_names)
	var nxt: int = board.next_index()
	board_prompt.text = "SPACE / CLICK: ADVANCE    ·    T: THRONE OF THOUGHT" if nxt >= 0 else "T: THRONE OF THOUGHT"


func narrate(text: String) -> void:
	narration.text = "\"" + text + "\""
	narration.visible_ratio = 0.0
	if narr_tween:
		narr_tween.kill()
	narr_tween = create_tween()
	narr_tween.tween_property(narration, "visible_ratio", 1.0, clampf(text.length() * 0.025, 0.4, 2.5))


func _chapter_banner(c: int) -> void:
	last_chapter_shown = c
	var roman := ["I", "II", "III", "IV", "V", "VI"]
	banner.text = "CHAPTER %s\n%s" % [roman[c], Story.CHAPTERS[c]["region"]]
	if banner_tween:
		banner_tween.kill()
	banner_tween = create_tween()
	banner.modulate.a = 0.0
	banner_tween.tween_property(banner, "modulate:a", 1.0, 0.5)
	banner_tween.tween_interval(1.6)
	banner_tween.tween_property(banner, "modulate:a", 0.0, 0.8)
	Sfx.play("levelup", -6.0, 0.8)


func _board_advance() -> void:
	if board.moving:
		return
	if not board.advance():
		var td: Dictionary = board.current_tile()
		if not td.is_empty() and td["data"]["type"] == "demon" and td["chapter"] == GameState.level - 1:
			_show_level_intro()
		elif td.is_empty() or td["data"]["type"] != "demon":
			narrate("The road ahead is lost in fog. I must face what waits here first.")


## A tile was landed on: resolve it.
func _on_tile(td: Dictionary) -> void:
	var data: Dictionary = td["data"]
	var c: int = td["chapter"]
	if c != last_chapter_shown:
		_chapter_banner(c)
	_update_board_hud()
	match data["type"]:
		"story":
			GameState.crowns += 2
			Sfx.play("coin", -6.0)
			narrate(data["text"])
			_update_board_hud()
		"event":
			var opts: Array = []
			for o in data["options"]:
				opts.append([o[0], _resolve_effects.bind(str(data["title"]), str(o[1]))])
			_show_choice(data["title"], data["text"], "fate", opts)
			tutorial("event", "Events let you shape your run. Every choice gives something, and some ask something back.")
		"treasure":
			narrate(data["text"])
			_resolve_effects("TREASURE", data["effect"])
		"altar":
			_show_altar(data["text"])
		"demon":
			narrate(Story.CHAPTERS[c].get("arrive", "Someone waits on this square."))
			get_tree().create_timer(1.4).timeout.connect(_show_level_intro)


func _resolve_effects(title: String, effects: String) -> void:
	var lines: Array[String] = []
	for e in effects.split("|"):
		var line := GameState.apply_effect(e)
		if line != "":
			lines.append(line)
	for k in lines.size():
		get_tree().create_timer(0.12 * k).timeout.connect(func(): Sfx.play("coin", -2.0, 1.0 + k * 0.1))
	_show_card(title, "\n".join(lines), "CONTINUE", _enter_board)


func _show_altar(text: String) -> void:
	var locked: Array = []
	for cid in GameState.CLASSES:
		if not GameState.class_unlocked(cid):
			locked.append(cid)
	locked.sort_custom(func(a, b): return GameState.CLASSES[a]["cost"] < GameState.CLASSES[b]["cost"])
	var opts: Array = []
	for cid in locked.slice(0, 3):
		var cl: Dictionary = GameState.CLASSES[cid]
		var cost := int(cl["cost"] * 0.5)
		opts.append(["UNLOCK %s FOR %d CROWNS (HALF PRICE)" % [cl["name"], cost], _altar_unlock.bind(cid)])
	opts.append(["LEAVE THE ALTAR", _enter_board])
	var body := text + "\n\nYou have %d Crowns." % GameState.crowns
	if locked.is_empty():
		body += "\nEvery class already answers you."
	_show_choice("CLASS ALTAR", body, "rite", opts)


func _altar_unlock(cid: String) -> void:
	if GameState.unlock_class(cid, 0.5):
		GameState.set_active_class(cid)
		Sfx.play("crown")
		var cl: Dictionary = GameState.CLASSES[cid]
		_show_card("%s AWAKENS" % cl["name"], "PASSIVE: %s\n\nIts skills now answer the Rite of Summoning. It is your active class." % cl["passive"], "CONTINUE", _enter_board)
	else:
		Sfx.play("deny")
		_show_card("NOT ENOUGH CROWNS", "The altar's fire gutters. Come back richer.", "CONTINUE", _enter_board)


# =============================================================================
# Tutorial: one-time hints, shown the first time each thing matters
# =============================================================================

func _build_tutorial() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	tut_panel = PanelContainer.new()
	tut_panel.theme = theme_res
	tut_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(tut_panel, 0, 0.38, 0, 0.38, 16, 0, 380, 0)
	layer.add_child(tut_panel)
	var vb := VBoxContainer.new()
	tut_panel.add_child(vb)
	vb.add_child(_label("GUIDANCE", 16, GOLD))
	tut_label = _label("", 16, TEXT)
	tut_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tut_label.custom_minimum_size = Vector2(330, 0)
	vb.add_child(tut_label)
	tut_panel.modulate.a = 0.0


## Show a hint once. slowmo briefly slows the game so the player can react to what it describes.
func tutorial(key: String, text: String, slowmo: bool = false, duration: float = 7.0) -> void:
	if GameState.tutorial_seen.has(key):
		return
	GameState.tutorial_seen[key] = true
	tut_label.text = text
	tut_label.visible_ratio = 0.0
	if tut_tween:
		tut_tween.kill()
	tut_tween = create_tween()
	tut_tween.set_ignore_time_scale(true)
	tut_tween.tween_property(tut_panel, "modulate:a", 1.0, 0.25)
	tut_tween.parallel().tween_property(tut_label, "visible_ratio", 1.0, 0.8)
	tut_tween.tween_interval(duration)
	tut_tween.tween_property(tut_panel, "modulate:a", 0.0, 0.5)
	Sfx.play("click", -4.0, 1.5)
	if slowmo and not GameState.autoplay:
		Engine.time_scale = base_time_scale * 0.3
		get_tree().create_timer(1.4, true, false, true).timeout.connect(func(): Engine.time_scale = base_time_scale)


# =============================================================================
# Remembrance: your skills fade with each chapter. Choose a few to carry from your past,
# in the strongest version your ascension allows.
# =============================================================================

func _show_remembrance(after: Callable) -> void:
	var choices: Array[String] = GameState.remembrance_choices()
	if choices.is_empty():
		after.call()
		return
	state = "remembrance"
	rem_after = after
	rem_selected = []
	rem_buttons = {}
	var o := _new_overlay(0.88)
	var center := CenterContainer.new()
	o.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)
	var tl := _label("REMEMBRANCE", 40, GOLD)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(tl)
	var body := _label("A new chapter. Your powers have faded back to their first form.\nChoose %d to carry from your past. Having ascended, you may recall them up to rank %s." % [GameState.remembrance_slots(), GameState.roman(GameState.remembrance_rank_cap())], 16)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(760, 0)
	vb.add_child(body)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	vb.add_child(grid)
	for id in choices.slice(0, 15):
		var r := GameState.remembrance_rank(id)
		var b := _button("%s %s" % [str(GameState.SKILLS[id]["name"]).to_upper(), GameState.roman(r)], _toggle_remembrance.bind(id), 250)
		b.icon = UiArt.icon(id)
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 32)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(250, 48)
		grid.add_child(b)
		rem_buttons[id] = b
	rem_go = _button("", _finish_remembrance, 360)
	rem_go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(rem_go)
	_refresh_remembrance()
	Sfx.play("reveal", -6.0, 0.8)
	if GameState.autoplay:
		for id in choices.slice(0, GameState.remembrance_slots()):
			_toggle_remembrance(id)
		get_tree().create_timer(1.0).timeout.connect(_finish_remembrance)


func _toggle_remembrance(id: String) -> void:
	if rem_selected.has(id):
		rem_selected.erase(id)
	elif rem_selected.size() < GameState.remembrance_slots():
		rem_selected.append(id)
		Sfx.play("coin", -6.0)
	else:
		Sfx.play("deny", -6.0)
	_refresh_remembrance()


func _refresh_remembrance() -> void:
	for id in rem_buttons:
		var b: Button = rem_buttons[id]
		var on := rem_selected.has(id)
		b.add_theme_stylebox_override("normal", UiArt.pill_box(Color("c8902a") if on else Color("3a2230")))
		b.add_theme_color_override("font_color", Color.WHITE if on else Color(0.8, 0.75, 0.7))
	rem_go.text = "BEGIN THE CHAPTER  (%d / %d CHOSEN)" % [rem_selected.size(), GameState.remembrance_slots()]


func _finish_remembrance() -> void:
	if state != "remembrance":
		return
	GameState.apply_remembrance(rem_selected)
	Sfx.play("levelup", -4.0)
	rem_after.call()
