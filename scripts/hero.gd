extends Node3D
## The hero: an AI that walks up to your throne and strikes you.
## His THINKING runs on combat ticks (on_tick, every 0.25s): windups, charges, recoveries and
## reactions are counted in ticks, so his blows land on a beat you can learn. His MOVEMENT is
## continuous: he weaves on the approach, circles you at range, rolls out of your attacks
## (hero_evasion), backsteps when hurt, FEINTS if you parry too much and TRACKS your lean if you
## lean too much. Form 4 is the Stranger (the last night), with counters built from your playstyle.
## Every boss attack is announced to him via notify_threat(). Whether he reacts, and how fast,
## depends on how well he has learned that skill (GameState.mastery). The attack itself
## decides what the right counter is (hero_counter) and calls back into the verbs below.

signal died
signal struck_boss(damage: float)

const Fx := preload("res://scripts/fx.gd")
const PixTex := preload("res://scripts/pixtex.gd")
const STRIKE_POINT := Vector3(0, 0, -2.15)
const BOUND_X := 6.5
const BOUND_Z_MIN := -14.0
const BOUND_Z_MAX := -2.0
const JUMP_TIME := 0.6
const JUMP_HEIGHT := 1.1

var game
var max_hp := 100.0
var hp := 100.0
var speed := 3.0
var strike_damage := 10.0
var windup_time := 0.6
var armor_color := Color(0.5, 0.52, 0.56)
var cape_color := Color(0.55, 0.12, 0.1)

var state := "enter"
var state_t := 0.0
var t := 0.0
var phase := 0.0
var action := ""
var action_t := 0.0
var action_vel := Vector3.ZERO
var last_vel := Vector3.ZERO
var jump_t := -1.0
var jump_wait := -1.0
var parry_t := 0.0
var ward_t := 0.0
var root_t := 0.0
var anchor_t := 0.0
var flash_t := 0.0
var invuln_t := 0.0
var torch_lit := false
var dead := false
var took_damage := false
var pending: Array = []

# Statuses inflicted by boss skills
var slow_t := 0.0
var stun_t := 0.0
var hex_t := 0.0
var vault_ok := false
var swing_t := 0.0

# His own moves (unlocked by hero tier): lunge, holy bolt, judgment leap
var hero_scale := 1.0
var lunge_cd := 12   # ticks
var bolt_cd := 14
var leap_cd := 20
var short_windup := false
var leap_from := Vector3.ZERO
const LEAP_TIME := 1.0
const LEAP_HEIGHT := 3.2

var figurine := false  # a static miniature on the board: no brain, no physics
var state_ticks := 0
var windup_ticks := 3
var recover_ticks := 3
var strafe_len := 4
var strafe_dir := 1.0
var dodge_cd := 0
var roll_t := 0.0
var roll_dur := 0.3
var roll_side := 1.0
var weave_amt := 0.0
var countdown: Label3D
var leap_landed := false
# The Stranger's counters (form 4), built from how you fight
var stranger := false
var nullify_skill := ""
var unparryable_every := 0   # every Nth blow cannot be parried (blade burns violet)
var strike_count := 0
var always_track := false
var mirror_every := 0        # every Nth cast you make is reflected at you
var blink := false           # teleports out of projectiles
var unparryable := false
# Escalation: how far above you he has risen. tier = which challenger (1-6), power grows with every return.
var tier := 1
var power := 0.0
var descend := false   # returns from death by descending in a pillar of light
var hover := 0.0       # late challengers float above the floor
var flinch_t := 0.0
var aura: MeshInstance3D
var aura_mat: StandardMaterial3D
var aura_light: OmniLight3D
var motes: CPUParticles3D
var wings: Array[Node3D] = []
var pillar: MeshInstance3D
var eye_mats: Array[StandardMaterial3D] = []
var strike_x := 0.0      # where the boss was when he committed to the blow
var leap_to := Vector3.ZERO
var hex_aura: MeshInstance3D
var ice: MeshInstance3D
var hand_glow: OmniLight3D

# 1 = Squire (bare head, leather, buckler), 2 = Knight (great helm, plume, kite shield),
# 3 = Champion (winged crown, halo, burning blade).
var form := 1

var rig: Node3D
var torso: Node3D
var head: Node3D
var leg_l: Node3D
var leg_r: Node3D
var arm_r: Node3D
var elbow_r: Node3D
var wrist_r: Node3D
var arm_l: Node3D
var elbow_l: Node3D
var shield: Node3D
var cape_upper: Node3D
var cape_lower: Node3D
var halo: MeshInstance3D
var blade_mat: StandardMaterial3D
var blade_base := Color(0.85, 0.88, 0.95)
var blade_base_energy := 0.3
var ward_bubble: MeshInstance3D
var torch: OmniLight3D
var flame: MeshInstance3D
var sigils: Node3D
var body_mats: Array[StandardMaterial3D] = []


func _ready() -> void:
	phase = randf() * TAU
	scale = Vector3.ONE * hero_scale
	_build()
	refresh_sigils()
	hex_aura = Fx.sphere(0.6, Fx.mat(Color(0.8, 0.3, 0.6), 2.0, 0.3), Vector3(0, 1.1, 0))
	hex_aura.visible = false
	add_child(hex_aura)
	ice = Fx.box(Vector3(0.9, 2.1, 0.9), Fx.mat(Color(0.6, 0.85, 1.0), 1.5, 0.45), Vector3(0, 1.0, 0))
	ice.visible = false
	add_child(ice)
	hand_glow = OmniLight3D.new()
	hand_glow.light_color = Color(1.0, 0.85, 0.4)
	hand_glow.omni_range = 3.0
	hand_glow.light_energy = 0.0
	hand_glow.position = Vector3(0.4, 1.4, -0.4)
	add_child(hand_glow)
	if not figurine:
		_build_escalation()
		countdown = Label3D.new()
		countdown.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		countdown.no_depth_test = true
		countdown.fixed_size = true
		countdown.pixel_size = 0.0025
		countdown.font_size = 48
		countdown.outline_size = 10
		countdown.modulate = Color(1.0, 0.25, 0.2)
		countdown.position = Vector3(0, 2.7, 0)
		countdown.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		add_child(countdown)


# --- Construction -------------------------------------------------------------

func _m(color: Color) -> StandardMaterial3D:
	# Pixel-art surfaces: a grain of light and shade over the colour (mapped to the model, so it
	# moves with him). Emission stays free for the white hit-flash.
	var m := PixTex.mat(PixTex.grain(color, int(color.r * 50 + color.b * 20)), 0.3, false)
	m.emission_enabled = true
	m.emission = Color.WHITE
	m.emission_energy_multiplier = 0.0
	body_mats.append(m)
	return m


func _build() -> void:
	rig = Node3D.new()
	add_child(rig)
	var armor := _m(armor_color)
	var armor_hi := _m(armor_color.lightened(0.25))
	var dark := _m(armor_color.darkened(0.55))
	var leather := _m(Color(0.33, 0.2, 0.12))
	var cloth := _m(cape_color)
	var gold := _m(Color(0.85, 0.62, 0.2))

	# Legs: thigh, knee cop, greave, boot. Pivots sit at the hips so they can swing.
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.12, 0.84, 0)
		rig.add_child(leg)
		leg.add_child(Fx.box(Vector3(0.17, 0.4, 0.2), leather if form == 1 else dark, Vector3(0, -0.2, 0)))
		leg.add_child(Fx.box(Vector3(0.14, 0.08, 0.06), armor_hi, Vector3(0, -0.42, -0.1)))
		leg.add_child(Fx.box(Vector3(0.16, 0.32, 0.19), armor, Vector3(0, -0.6, 0)))
		leg.add_child(Fx.box(Vector3(0.18, 0.12, 0.28), leather, Vector3(0, -0.78, -0.04)))
		if side < 0.0:
			leg_l = leg
		else:
			leg_r = leg

	torso = Node3D.new()
	torso.position = Vector3(0, 0.84, 0)
	rig.add_child(torso)
	torso.add_child(Fx.box(Vector3(0.48, 0.18, 0.3), dark, Vector3(0, -0.07, 0)))
	torso.add_child(Fx.box(Vector3(0.28, 0.32, 0.03), cloth, Vector3(0, -0.14, -0.16)))
	torso.add_child(Fx.box(Vector3(0.47, 0.1, 0.31), leather, Vector3(0, 0.04, 0)))
	torso.add_child(Fx.box(Vector3(0.08, 0.08, 0.04), gold, Vector3(0, 0.04, -0.16)))
	torso.add_child(Fx.box(Vector3(0.48, 0.48, 0.3), armor, Vector3(0, 0.32, 0)))
	if form >= 2:
		torso.add_child(Fx.box(Vector3(0.38, 0.3, 0.06), armor_hi, Vector3(0, 0.4, -0.15)))
	# Tabard with his emblem. The Champion's emblem burns.
	torso.add_child(Fx.box(Vector3(0.26, 0.46, 0.02), cloth, Vector3(0, 0.27, -0.19)))
	var emblem := Fx.mat(Color(1.0, 0.8, 0.3), 3.0 if form == 3 else 0.0)
	torso.add_child(Fx.box(Vector3(0.05, 0.2, 0.02), emblem, Vector3(0, 0.3, -0.205)))
	torso.add_child(Fx.box(Vector3(0.14, 0.05, 0.02), emblem, Vector3(0, 0.34, -0.205)))
	torso.add_child(Fx.box(Vector3(0.26, 0.08, 0.24), dark, Vector3(0, 0.6, 0)))
	if form == 4:
		# A long robe over everything, falling to the floor.
		torso.add_child(Fx.box(Vector3(0.54, 0.9, 0.36), cloth, Vector3(0, -0.4, 0)))
		torso.add_child(Fx.box(Vector3(0.5, 0.56, 0.34), cloth, Vector3(0, 0.3, 0)))
		torso.add_child(Fx.box(Vector3(0.06, 0.5, 0.02), Fx.mat(Color(0.9, 0.2, 0.25), 2.0), Vector3(0, 0.1, -0.19)))

	head = Node3D.new()
	head.position = Vector3(0, 0.66, 0)
	torso.add_child(head)
	_build_head(armor, armor_hi, cloth, gold)

	# Cape in two hinged segments so it can billow.
	cape_upper = Node3D.new()
	cape_upper.position = Vector3(0, 0.6, 0.17)
	torso.add_child(cape_upper)
	cape_upper.add_child(Fx.box(Vector3(0.46, 0.5, 0.04), cloth, Vector3(0, -0.25, 0)))
	cape_lower = Node3D.new()
	cape_lower.position = Vector3(0, -0.5, 0)
	cape_upper.add_child(cape_lower)
	cape_lower.add_child(Fx.box(Vector3(0.5, 0.42 if form > 1 else 0.25, 0.04), cloth, Vector3(0, -0.2 if form > 1 else -0.12, 0)))

	var r := _build_arm(1.0, armor, armor_hi, dark, leather)
	arm_r = r[0]
	elbow_r = r[1]
	var l := _build_arm(-1.0, armor, armor_hi, dark, leather)
	arm_l = l[0]
	elbow_l = l[1]
	_build_sword(gold, leather)
	_build_shield(armor, armor_hi, cloth, gold)

	ward_bubble = Fx.sphere(1.05, Fx.mat(Color(0.5, 0.85, 1.0), 2.0, 0.3), Vector3(0, 1.0, 0))
	ward_bubble.visible = false
	add_child(ward_bubble)

	torch = OmniLight3D.new()
	torch.light_color = Color(1.0, 0.7, 0.35)
	torch.omni_range = 6.0
	torch.light_energy = 2.5
	torch.position = Vector3(-0.4, 2.0, -0.2)
	torch.visible = false
	add_child(torch)
	flame = Fx.box(Vector3(0.12, 0.2, 0.12), Fx.mat(Color(1.0, 0.6, 0.2), 6.0), Vector3(-0.42, 1.5, -0.2))
	flame.visible = false
	add_child(flame)

	sigils = Node3D.new()
	sigils.position = Vector3(0, 2.25, 0)
	add_child(sigils)


func _build_head(armor: Material, armor_hi: Material, cloth: Material, gold: Material) -> void:
	# The visor / eyes glow so you can always find him, even in the dark.
	var glow := Fx.mat(Color(1.0, 0.85, 0.4) if form == 3 else Color(0.7, 0.9, 1.0), 6.0)
	eye_mats.append(glow)
	if form == 1:
		var skin := _m(Color(0.86, 0.68, 0.52))
		var hair := _m(Color(0.35, 0.2, 0.1))
		head.add_child(Fx.box(Vector3(0.22, 0.24, 0.22), skin, Vector3(0, 0.12, 0)))
		# A painted pixel face: the boy who borrowed his father's sword
		var fq := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.22, 0.24)
		fq.mesh = qm
		fq.material_override = PixTex.decal(PixTex.face(Color(0.86, 0.68, 0.52), Color(0.35, 0.2, 0.1), Color(0.3, 0.45, 0.7), "", 3))
		fq.position = Vector3(0, 0.12, -0.112)
		fq.rotation.y = PI
		head.add_child(fq)
		head.add_child(Fx.box(Vector3(0.25, 0.08, 0.25), hair, Vector3(0, 0.27, 0.01)))
		head.add_child(Fx.box(Vector3(0.25, 0.16, 0.06), hair, Vector3(0, 0.18, 0.11)))
		for s in [-1.0, 1.0]:
			head.add_child(Fx.box(Vector3(0.035, 0.03, 0.01), glow, Vector3(s * 0.05, 0.14, -0.112)))
		head.add_child(Fx.box(Vector3(0.28, 0.07, 0.27), cloth, Vector3(0, 0.0, 0)))
		return
	if form == 4:
		# The Stranger: a deep hood, a shadowed face, two eyes. Your eyes.
		var shade := _m(Color(0.03, 0.02, 0.04))
		head.add_child(Fx.box(Vector3(0.24, 0.26, 0.24), shade, Vector3(0, 0.13, 0)))
		head.add_child(Fx.box(Vector3(0.34, 0.36, 0.32), cloth, Vector3(0, 0.17, 0.03)))
		head.add_child(Fx.box(Vector3(0.24, 0.26, 0.04), shade, Vector3(0, 0.13, -0.15)))
		head.add_child(Fx.box(Vector3(0.2, 0.12, 0.1), cloth, Vector3(0, 0.38, 0.1)))
		var red := Fx.mat(Color(1.0, 0.2, 0.15), 7.0)
		eye_mats.append(red)
		for s in [-1.0, 1.0]:
			head.add_child(Fx.box(Vector3(0.04, 0.025, 0.01), red, Vector3(s * 0.05, 0.15, -0.172)))
		var crown := Fx.mat(Color(0.25, 0.1, 0.3), 1.5)
		for i in 5:
			head.add_child(Fx.box(Vector3(0.03, 0.07, 0.03), crown, Vector3(-0.1 + i * 0.05, 0.4, -0.06)))
		return
	head.add_child(Fx.box(Vector3(0.28, 0.3, 0.28), armor_hi if form == 3 else armor, Vector3(0, 0.15, 0)))
	head.add_child(Fx.box(Vector3(0.3, 0.04, 0.3), armor_hi, Vector3(0, 0.05, 0)))
	head.add_child(Fx.box(Vector3(0.22, 0.035, 0.02), glow, Vector3(0, 0.17, -0.145)))
	head.add_child(Fx.box(Vector3(0.04, 0.12, 0.02), armor_hi, Vector3(0, 0.08, -0.145)))
	if form == 2:
		# Plume arcing back over the helm.
		var pts := [Vector3(0, 0.33, -0.06), Vector3(0, 0.37, 0.04), Vector3(0, 0.35, 0.13), Vector3(0, 0.27, 0.2)]
		for p in pts:
			head.add_child(Fx.box(Vector3(0.05, 0.09, 0.1), cloth, p))
		return
	# Champion: crown, wings, halo.
	head.add_child(Fx.box(Vector3(0.31, 0.05, 0.31), gold, Vector3(0, 0.3, 0)))
	for i in 5:
		var x := -0.12 + i * 0.06
		head.add_child(Fx.box(Vector3(0.035, 0.08 + (0.05 if i == 2 else 0.0), 0.035), gold, Vector3(x, 0.36, -0.14)))
	var wing := Fx.mat(Color(0.95, 0.95, 1.0), 0.8)
	for s in [-1.0, 1.0]:
		var w := Fx.box(Vector3(0.02, 0.18, 0.28), wing, Vector3(s * 0.17, 0.25, 0.06))
		w.rotation = Vector3(-0.3, 0, -s * 0.5)
		head.add_child(w)
	var tm := TorusMesh.new()
	tm.inner_radius = 0.15
	tm.outer_radius = 0.19
	tm.rings = 16
	tm.ring_segments = 4
	halo = MeshInstance3D.new()
	halo.mesh = tm
	halo.material_override = Fx.mat(Color(1.0, 0.85, 0.4), 5.0)
	halo.position = Vector3(0, 0.52, 0.04)
	halo.rotation.x = 0.25
	head.add_child(halo)


## Shoulder pivot -> pauldron + upper arm, elbow pivot -> forearm + gauntlet. Returns [shoulder, elbow].
func _build_arm(side: float, armor: Material, armor_hi: Material, dark: Material, leather: Material) -> Array:
	var shoulder := Node3D.new()
	shoulder.position = Vector3(side * 0.31, 0.56, 0)
	torso.add_child(shoulder)
	if form == 1:
		shoulder.add_child(Fx.box(Vector3(0.17, 0.1, 0.24), leather, Vector3(side * 0.03, 0.03, 0)))
	else:
		shoulder.add_child(Fx.box(Vector3(0.24, 0.16, 0.32), armor_hi, Vector3(side * 0.04, 0.04, 0)))
		shoulder.add_child(Fx.box(Vector3(0.2, 0.08, 0.3), armor, Vector3(side * 0.06, -0.07, 0)))
	shoulder.add_child(Fx.box(Vector3(0.11, 0.26, 0.12), dark, Vector3(0, -0.15, 0)))
	var elbow := Node3D.new()
	elbow.position = Vector3(0, -0.3, 0)
	shoulder.add_child(elbow)
	elbow.add_child(Fx.box(Vector3(0.12, 0.24, 0.13), armor, Vector3(0, -0.12, 0)))
	elbow.add_child(Fx.box(Vector3(0.13, 0.1, 0.14), leather, Vector3(0, -0.28, 0)))
	return [shoulder, elbow]


func _build_sword(gold: Material, leather: Material) -> void:
	wrist_r = Node3D.new()
	wrist_r.position = Vector3(0, -0.3, 0)
	elbow_r.add_child(wrist_r)
	var length: float = [0.7, 0.9, 1.05, 1.0][form - 1]
	if form == 4:
		blade_base = Color(0.7, 0.2, 1.0)
		blade_base_energy = 3.0
	if form == 3:
		blade_base = Color(1.0, 0.85, 0.45)
		blade_base_energy = 2.5
	blade_mat = Fx.mat(blade_base, blade_base_energy)
	wrist_r.add_child(Fx.box(Vector3(0.04, 0.04, 0.16), leather, Vector3(0, 0, 0.01)))
	wrist_r.add_child(Fx.box(Vector3(0.06, 0.06, 0.05), gold, Vector3(0, 0, 0.11)))
	wrist_r.add_child(Fx.box(Vector3(0.24, 0.04, 0.05), gold, Vector3(0, 0, -0.08)))
	wrist_r.add_child(Fx.box(Vector3(0.07, 0.025, length), blade_mat, Vector3(0, 0, -0.1 - length * 0.5)))
	wrist_r.add_child(Fx.box(Vector3(0.02, 0.03, length * 0.75), Fx.mat(blade_base.lightened(0.3), blade_base_energy + 0.3), Vector3(0, 0, -0.1 - length * 0.45)))


func _build_shield(armor: Material, armor_hi: Material, cloth: Material, gold: Material) -> void:
	shield = Node3D.new()
	shield.position = Vector3(-0.04, -0.16, -0.1)
	elbow_l.add_child(shield)
	if form == 1:
		# A round wooden buckler with an iron boss.
		var wood := _m(Color(0.42, 0.27, 0.15))
		var disc := Fx.cylinder(0.2, 0.2, 0.05, wood)
		disc.rotation.x = PI / 2.0
		shield.add_child(disc)
		shield.add_child(Fx.sphere(0.06, armor, Vector3(0, 0, -0.03)))
		return
	shield.add_child(Fx.box(Vector3(0.38, 0.4, 0.05), armor_hi if form == 3 else cloth, Vector3(0, 0.05, 0)))
	var point := Fx.box(Vector3(0.27, 0.27, 0.05), armor_hi if form == 3 else cloth, Vector3(0, -0.15, 0))
	point.rotation.z = PI / 4.0
	shield.add_child(point)
	shield.add_child(Fx.box(Vector3(0.4, 0.04, 0.06), gold, Vector3(0, 0.25, -0.005)))
	var emblem := Fx.mat(Color(1.0, 0.8, 0.3), 3.0 if form == 3 else 0.2)
	shield.add_child(Fx.box(Vector3(0.06, 0.32, 0.02), emblem, Vector3(0, 0.0, -0.035)))
	shield.add_child(Fx.box(Vector3(0.24, 0.06, 0.02), emblem, Vector3(0, 0.08, -0.035)))


## Everything that shows he is rising above you: an aura, rising motes, spikes, wings, levitation,
## and a pillar of light he descends through when he returns. Scales with tier and power.
func _build_escalation() -> void:
	var tint := Color(1.0, 0.85, 0.45) if tier >= 3 else Color(0.7, 0.85, 1.0)
	aura_mat = Fx.mat(tint, 0.35, 0.0)
	aura = Fx.sphere(1.0, aura_mat, Vector3(0, 1.0, 0))
	aura.scale = Vector3(0.75, 1.25, 0.75)
	add_child(aura)
	aura_light = OmniLight3D.new()
	aura_light.light_color = tint
	aura_light.omni_range = 4.0 + power
	aura_light.light_energy = 0.3 + 0.35 * power
	aura_light.position = Vector3(0, 1.4, 0)
	add_child(aura_light)
	motes = Fx.particles(tint, int(6 + 8 * power), 1.4, 0.8, 0.05)
	motes.direction = Vector3.UP
	motes.spread = 25.0
	motes.gravity = Vector3(0, 1.2, 0)
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	motes.emission_sphere_radius = 0.6
	motes.position = Vector3(0, 0.6, 0)
	add_child(motes)
	# Gold spikes on the shoulders: one more per tier
	var gold := _m(Color(0.95, 0.75, 0.25))
	for side in [-1.0, 1.0]:
		var sh: Node3D = arm_r if side > 0.0 else arm_l
		for k in mini(tier - 1, 4):
			var spike := Fx.cylinder(0.0, 0.035, 0.16 + k * 0.03, gold, Vector3(side * (0.06 + k * 0.05), 0.15, -0.08 + k * 0.06))
			spike.rotation.z = -side * 0.4
			sh.add_child(spike)
	# Wings from the third challenger onward, bigger with every tier
	if tier >= 3:
		var feather := _m(Color(1.0, 0.97, 0.9) if tier < 6 else Color(1.0, 0.85, 0.5))
		var span := 0.5 + 0.22 * (tier - 3)
		for side in [-1.0, 1.0]:
			var w := Node3D.new()
			w.position = Vector3(side * 0.12, 0.5, 0.2)
			torso.add_child(w)
			for f in 5:
				var flen := span * (1.0 - f * 0.12)
				var fb := Fx.box(Vector3(flen, 0.06, 0.12), feather, Vector3(side * flen * 0.5, 0.1 - f * 0.11, 0.02 * f))
				fb.rotation.z = side * (0.5 - f * 0.18)
				w.add_child(fb)
			wings.append(w)
	if tier >= 4:
		hover = 0.3 + 0.1 * (tier - 4)
	pillar = Fx.cylinder(0.9, 0.9, 14.0, Fx.mat(tint, 4.0, 0.0), Vector3(0, 7.0, 0))
	add_child(pillar)
	if descend:
		position.y = 7.0
		state = "descend"


## One glowing sigil orbits his head for every skill he has ADAPTED to. These are his scars.
func refresh_sigils() -> void:
	if sigils == null:
		return
	for c in sigils.get_children():
		c.queue_free()
	var ids: Array[String] = []
	for id in GameState.SKILLS:
		if GameState.tier(GameState.get_mastery(id)) >= 2:
			ids.append(id)
	for i in ids.size():
		var a := TAU * i / ids.size()
		var col: Color = GameState.SKILLS[ids[i]]["color"]
		var s := Fx.box(Vector3.ONE * 0.11, Fx.mat(col, 4.0), Vector3(cos(a) * 0.4, 0, sin(a) * 0.4))
		s.rotation = Vector3(0.6, 0.6, 0)
		sigils.add_child(s)


# --- Queries ------------------------------------------------------------------

func center() -> Vector3:
	return global_position + Vector3(0, 1.0 * hero_scale, 0)


func is_airborne() -> bool:
	return position.y - hover > 0.25


func is_blind() -> bool:
	return GameState.eclipse_active and not torch_lit


# --- Perception ---------------------------------------------------------------

## Called by every boss attack the moment it is cast.
func notify_threat(attack) -> void:
	if dead or stun_t > 0.0:
		return
	var m := GameState.get_mastery(attack.skill_id)
	var chance := 0.06 + m * 0.92 + GameState.hero_instinct()
	var delay := lerpf(0.5, 0.0, m)
	if GameState.perks.has("fog"):
		delay *= 1.0 + 0.3 * GameState.asc_mult()
		delay += 0.1
	if is_blind():
		chance *= 0.3
		delay += 0.25
	if randf() < clampf(chance, 0.0, 0.96):
		pending.append({"t": delay, "attack": attack})


func later(delay: float, fn: Callable) -> void:
	pending.append({"t": delay, "call": fn})


func _tick_pending(delta: float) -> void:
	for p in pending:
		p["t"] -= delta


## Reactions only happen on a tick.
func _run_pending() -> void:
	for i in range(pending.size() - 1, -1, -1):
		var p: Dictionary = pending[i]
		if p["t"] > 0.0:
			continue
		pending.remove_at(i)
		if p.has("attack"):
			var atk = p["attack"]
			if is_instance_valid(atk) and not atk.finished:
				atk.hero_counter(self)
		elif p.has("call"):
			var fn: Callable = p["call"]
			if fn.is_valid():
				fn.call()


# --- Counter verbs (called by attacks) ----------------------------------------

func dash(dir: Vector3, dist: float, dur: float = 0.22) -> void:
	if dead or root_t > 0.0:
		return
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = Vector3.RIGHT
	action = "dash"
	action_t = dur
	action_vel = dir.normalized() * (dist / dur)
	if state == "windup":
		_set_state("approach")


func jump_after(delay: float) -> void:
	if jump_t < 0.0:
		jump_wait = delay


func parry(dur: float) -> void:
	parry_t = dur


func ward(dur: float) -> void:
	ward_t = dur


func anchor(dur: float) -> void:
	anchor_t = dur


func root(dur: float) -> void:
	root_t = dur
	action = ""
	if state == "windup":
		_set_state("approach")


func kindle() -> void:
	torch_lit = true
	torch.visible = true
	flame.visible = true


func extinguish() -> void:
	torch_lit = false
	torch.visible = false
	flame.visible = false


func slow(dur: float) -> void:
	slow_t = maxf(slow_t, dur)


func stun(dur: float) -> void:
	stun_t = maxf(stun_t, dur)
	action = ""
	if state == "windup" or state.ends_with("charge") or state == "lunge":
		_set_state("approach")


func hex(dur: float) -> void:
	hex_t = dur


func cleanse() -> void:
	hex_t = 0.0


func swing() -> void:
	swing_t = 0.25


func announce(text: String) -> void:
	if text != "PARRIED":
		Sfx.play("dodge", -8.0)
	game.popup_text(global_position + Vector3(0, 2.5, 0), text, Color(0.6, 0.9, 1.0), 0.8)


# --- Damage -------------------------------------------------------------------

func take_hit(dmg: float, skill_id: String) -> bool:
	if dead or invuln_t > 0.0 or state == "victory":
		return false
	if skill_id != "" and skill_id == nullify_skill:
		game.popup_text(center() + Vector3(0, 0.9, 0), "NULLIFIED", Color(0.8, 0.3, 1.0), 1.1)
		return false
	hp -= dmg
	took_damage = true
	invuln_t = 0.12
	flash_t = 0.12
	flinch_t = 0.2
	GameState.on_hero_hit(skill_id, dmg)
	game.on_hero_damaged(self, dmg, skill_id)
	if hp <= 0.0:
		_die()
		return true
	# The more he has died, the more often he simply walks through your blows.
	if state == "leap" or randf() < GameState.hero_poise():
		return true
	if state == "windup" or state == "feint":
		_set_state("approach")
	if root_t <= 0.0:
		action = "knockback"
		action_t = 0.18
		action_vel = Vector3(position.x, 0, position.z).normalized() * 5.0
	return true


func _die() -> void:
	dead = true
	hp = 0.0
	pending.clear()
	extinguish()
	ward_bubble.visible = false
	var tw := create_tween()
	tw.tween_property(rig, "rotation:x", 1.45, 0.5).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(self, "position:y", 0.0, 0.3)
	tw.tween_property(rig, "position:y", -0.25, 0.8)
	game.spawn_burst(center(), Color(0.7, 0.9, 1.0), 30)
	died.emit()


func celebrate() -> void:
	state = "victory"
	action = ""
	pending.clear()
	jump_t = -1.0
	if pillar:
		var pm: StandardMaterial3D = pillar.material_override
		var tw := create_tween()
		tw.tween_property(pm, "albedo_color:a", 0.35, 0.6)


# --- Brain --------------------------------------------------------------------

func _set_state(s: String) -> void:
	state = s
	state_t = 0.0
	state_ticks = 0
	if s == "windup":
		strike_x = strike_point().x


func _physics_process(delta: float) -> void:
	if figurine:
		return
	t += delta
	if dead:
		return
	_tick_timers(delta)
	ice.visible = stun_t > 0.0
	hex_aura.visible = hex_t > 0.0
	if stun_t > 0.0:
		return  # Frozen in time: no thought, no movement, pose held.
	_tick_pending(delta)

	var vel := Vector3.ZERO
	if action != "":
		vel = action_vel
		action_t -= delta
		if action_t <= 0.0:
			action = ""
	elif root_t <= 0.0:
		vel = _move(delta)
	else:
		state_t += delta
	for w in get_tree().get_nodes_in_group("wells"):
		var pull: Vector3 = w.pull_on(global_position)
		vel += pull * (0.12 if anchor_t > 0.0 else 1.0)
	vel = _check_walls(vel, delta)

	position.x = clampf(position.x + vel.x * delta, -BOUND_X, BOUND_X)
	position.z = clampf(position.z + vel.z * delta, BOUND_Z_MIN, BOUND_Z_MAX)
	if state == "leap":
		var s := clampf(state_t / LEAP_TIME, 0.0, 1.0)
		position.y = 4.0 * LEAP_HEIGHT * s * (1.0 - s) + hover
	elif state == "descend":
		# Returning from death: he comes down through a pillar of light.
		position.y = maxf(hover, position.y - delta * 6.0)
		if position.y <= hover + 0.01:
			game.spawn_burst(global_position + Vector3(0, 0.3, 0), Color(1.0, 0.9, 0.6), 30)
			game.boss.shake(0.25)
			_set_state("approach")
	elif state == "victory":
		# He rises above you.
		position.y = lerpf(position.y, 1.8 + hover, 1.0 - exp(-delta * 1.5))
	else:
		_update_jump(delta)
	last_vel = vel
	_animate(delta, vel)


func _tick_timers(delta: float) -> void:
	parry_t = maxf(0.0, parry_t - delta)
	ward_t = maxf(0.0, ward_t - delta)
	root_t = maxf(0.0, root_t - delta)
	anchor_t = maxf(0.0, anchor_t - delta)
	flash_t = maxf(0.0, flash_t - delta)
	invuln_t = maxf(0.0, invuln_t - delta)
	slow_t = maxf(0.0, slow_t - delta)
	stun_t = maxf(0.0, stun_t - delta)
	hex_t = maxf(0.0, hex_t - delta)
	swing_t = maxf(0.0, swing_t - delta)
	flinch_t = maxf(0.0, flinch_t - delta)
	roll_t = maxf(0.0, roll_t - delta)
	if jump_wait >= 0.0:
		jump_wait -= delta
		if jump_wait < 0.0:
			jump_t = 0.0


func _update_jump(delta: float) -> void:
	var rest := hover + (sin(t * 2.0) * 0.08 if hover > 0.0 else 0.0)
	if jump_t < 0.0:
		position.y = rest
		return
	jump_t += delta
	var s := jump_t / JUMP_TIME
	if s >= 1.0:
		jump_t = -1.0
		position.y = rest
	else:
		position.y = 4.0 * JUMP_HEIGHT * s * (1.0 - s) + rest


## Walls block him unless he has learned to vault them.
func _check_walls(vel: Vector3, delta: float) -> Vector3:
	for w in get_tree().get_nodes_in_group("walls"):
		if not w.active():
			continue
		var wz: float = w.wall_z()
		if position.z >= wz - 0.3 or position.z + vel.z * delta < wz - 0.7 or is_airborne():
			continue
		if vault_ok:
			if jump_t < 0.0 and jump_wait < 0.0:
				jump_t = 0.0
				announce("VAULT")
		else:
			position.z = minf(position.z, wz - 0.7)
			vel.z = minf(vel.z, 0.0)
			w.note_blocked(delta)
	return vel


## Where he has to stand to hit you. You can lean along the dais, so it follows you.
func strike_point() -> Vector3:
	return Vector3(game.boss_x() if game else 0.0, 0, STRIKE_POINT.z)


func _strike(dmg: float) -> void:
	if dead or state == "victory":
		return
	if hex_t > 0.0:
		dmg *= 0.5
	strike_count += 1
	unparryable = unparryable_every > 0 and strike_count % unparryable_every == 0
	# He reads your lean: the more you lean out of his blows, the more often he follows you.
	if game and absf(game.boss_x() - strike_x) > GameState.whiff_tolerance():
		var track := clampf(GameState.fight_grazes * 0.12 + 0.05 * (GameState.attempt - 1), 0.0, 0.7)
		if always_track or randf() < track:
			strike_x = game.boss_x()
			announce("READ YOU")
	# You leaned away mid-swing: his blade only grazes you.
	if game and absf(game.boss_x() - strike_x) > GameState.whiff_tolerance():
		announce("GRAZED")
		Sfx.play("dodge", -2.0, 0.7)
		GameState.on_graze()
		if GameState.perks.has("phantom"):
			stun(GameState.TICK * roundi(2 * GameState.asc_mult() + 0.4))
		struck_boss.emit(dmg * GameState.graze_taken())
		return
	Sfx.play("hero_strike", -2.0)
	struck_boss.emit(dmg)


func unparryable_next() -> bool:
	return unparryable_every > 0 and (strike_count + 1) % unparryable_every == 0


func _fire_bolt() -> void:
	var hand: Vector3 = global_position + Vector3(0, 1.5 * hero_scale, 0)
	game.spawn_hero_bolt(hand, strike_damage * (0.5 if hex_t > 0.0 else 1.0) * 0.6)


func _flat_dist_to_throne() -> float:
	var sp := strike_point()
	return Vector2(position.x, position.z).distance_to(Vector2(sp.x, sp.z))


## Decisions, once per combat tick.
func on_tick() -> void:
	if figurine or dead or state == "victory" or stun_t > 0.0:
		return
	state_ticks += 1
	dodge_cd = maxi(0, dodge_cd - 1)
	lunge_cd -= 1
	bolt_cd -= 1
	leap_cd -= 1
	_run_pending()
	var quick := GameState.level >= 4 or stranger
	match state:
		"enter":
			if state_ticks >= 3:
				_set_state("approach")
		"lunge_charge":
			if state_ticks >= (1 if quick else 2):
				_set_state("lunge")
		"lunge":
			if _flat_dist_to_throne() < 0.7 or state_ticks >= 4:
				_begin_windup(1)
		"bolt_charge":
			if state_ticks >= (2 if quick else 3):
				hand_glow.light_energy = 0.0
				_fire_bolt()
				_after_attack()
		"leap_charge":
			if state_ticks >= (2 if quick else 3):
				leap_from = position
				leap_to = strike_point()
				strike_x = leap_to.x
				_set_state("leap")
				announce("JUDGMENT")
		"leap":
			if state_t >= LEAP_TIME:
				position.y = hover
				game.boss.shake(0.6)
				game.spawn_burst(Vector3(position.x, 0.3, position.z), Color(1.0, 0.85, 0.4), 30)
				_strike(strike_damage * 1.8)
				if state == "leap":
					recover_ticks = 3
					_set_state("recover")
		"approach":
			_decide_approach()
		"strafe":
			if state_ticks >= strafe_len:
				_set_state("approach")
		"backstep":
			if state_ticks >= 2:
				if GameState.has_move("bolt") and bolt_cd <= 0:
					bolt_cd = 14 if quick else 20
					_set_state("bolt_charge")
				else:
					_start_strafe()
		"feint":
			# A false windup to bait your parry. Then the real blow, fast.
			if state_ticks >= 2:
				announce("FEINT")
				_begin_windup(2)
		"windup":
			if state_ticks >= windup_ticks:
				_strike(strike_damage)
				if state == "windup":  # the blow may have won the fight (state is now "victory")
					recover_ticks = 3 if GameState.level < 4 else 2
					_set_state("recover")
		"recover":
			if state_ticks >= recover_ticks:
				_after_attack()
	if state in ["approach", "strafe", "recover", "backstep", "enter"]:
		_try_evade()


func _begin_windup(ticks: int) -> void:
	windup_ticks = maxi(1, ticks)
	_set_state("windup")


func _decide_approach() -> void:
	var dist := _flat_dist_to_throne()
	var quick := GameState.level >= 4 or stranger
	if dist < 0.6:
		# He reads your parries: lean on them, and he starts to feint.
		var feint := clampf(GameState.fight_parries * 0.08 + 0.03 * (GameState.attempt - 1), 0.0, 0.45)
		if stranger and GameState.playstyle() == "parry":
			feint = 0.5
		if GameState.attempt >= 2 and randf() < feint:
			_set_state("feint")
		else:
			_begin_windup(GameState.windup_ticks(windup_time))
		return
	if GameState.has_move("leap") and leap_cd <= 0 and dist > 5.0 and dist < 10.0:
		leap_cd = 28 if quick else 36
		_set_state("leap_charge")
		return
	if GameState.has_move("bolt") and bolt_cd <= 0 and dist > 5.5:
		bolt_cd = 16 if quick else 20
		_set_state("bolt_charge")
		return
	if GameState.has_move("lunge") and lunge_cd <= 0 and dist > 3.0 and dist < 6.5:
		lunge_cd = 18 if quick else 24
		_set_state("lunge_charge")
		return
	# Sometimes he circles you instead of walking straight in.
	if dist > 6.0 and randf() < 0.04 + 0.01 * GameState.attempt:
		_start_strafe()


## After a blow or a bolt: press on, circle, or back off to range when hurt.
func _after_attack() -> void:
	var r := randf()
	if hp < max_hp * 0.4 and r < 0.5:
		_set_state("backstep")
		jump_t = 0.0
		announce("BACKSTEP")
	elif r < 0.25 + 0.03 * GameState.attempt:
		_start_strafe()
	else:
		_set_state("approach")


func _start_strafe() -> void:
	strafe_len = randi_range(4, 9)
	strafe_dir = -1.0 if randf() < 0.5 else 1.0
	_set_state("strafe")


## Reads your attacks in flight and rolls out of them, even ones he has never studied.
func _try_evade() -> void:
	if dodge_cd > 0 or action != "" or root_t > 0.0 or is_airborne():
		return
	var gp := global_position
	for a in get_tree().get_nodes_in_group("attacks"):
		if not is_instance_valid(a) or a.is_in_group("hero_bolts") or not ("finished" in a) or a.finished:
			continue
		var ap: Vector3 = a.global_position
		var threat := false
		var side := Vector3.ZERO
		if "dir" in a and a.dir is Vector3 and (a.dir as Vector3).length() > 0.1:
			var dir: Vector3 = a.dir
			var along := (gp - ap).dot(dir)
			var closest := ap + dir * along
			if along > 0.0 and along < 7.0 and Vector2(closest.x - gp.x, closest.z - gp.z).length() < 1.3:
				threat = true
				side = Vector3(-dir.z, 0, dir.x).normalized()
				if (gp - closest).dot(side) < 0.0:
					side = -side
		elif Vector2(ap.x - gp.x, ap.z - gp.z).length() < 2.6:
			threat = true
			side = Vector3(gp.x - ap.x, 0, gp.z - ap.z)
			if side.length() < 0.1:
				side = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
			side = side.normalized()
		if not threat:
			continue
		dodge_cd = 3
		var chance := GameState.hero_evasion() + (0.25 if stranger else 0.0)
		if randf() < chance:
			if absf(position.x + side.x * 2.6) > 6.2:
				side.x = -side.x
			if blink:
				position += side * 3.0
				game.spawn_burst(center(), Color(0.7, 0.2, 1.0), 16)
				announce("BLINK")
			else:
				dash(side, 2.6, 0.3)
				roll_t = 0.3
				roll_dur = 0.3
				roll_side = signf(side.x) if absf(side.x) > 0.1 else 1.0
				announce("ROLL" if randf() < 0.5 else "DODGE")
		return


## Movement for the current state (continuous; decisions happen in on_tick).
func _move(delta: float) -> Vector3:
	state_t += delta
	var spd := speed * (0.5 if is_blind() else 1.0) * (0.5 if slow_t > 0.0 else 1.0)
	weave_amt = move_toward(weave_amt, 0.0, delta * 2.0)
	match state:
		"enter":
			return Vector3(0, 0, 1) * spd * 0.6
		"lunge":
			return (strike_point() - Vector3(position.x, 0, position.z)).normalized() * 13.0
		"bolt_charge":
			hand_glow.light_energy = 3.0 * minf(state_t, 1.0)
			return Vector3.ZERO
		"leap":
			var s := clampf(state_t / LEAP_TIME, 0.0, 1.0)
			var target := Vector3(leap_from.x, 0, leap_from.z).lerp(leap_to, s)
			position.x = target.x
			position.z = target.z
			return Vector3.ZERO
		"approach":
			# Weave side to side while far away, commit to a straight line up close.
			var depth := clampf((-position.z - 2.5) / 9.0, 0.0, 1.0)
			var sp := strike_point()
			var target := Vector3(sin(t * 1.4 + phase) * 4.5 * depth + sp.x * (1.0 - depth), 0, sp.z)
			var to := target - Vector3(position.x, 0, position.z)
			var v := to.normalized() * spd
			var dist := _flat_dist_to_throne()
			if dist > 2.2 and dist < 7.5:
				# Bob and weave: a lateral sway that makes him hard to aim at.
				weave_amt = 1.0
				var lat := Vector3(-to.z, 0, to.x).normalized()
				v += lat * sin(t * 6.5 + phase) * spd * 0.7
			if is_blind():
				v = v.rotated(Vector3.UP, sin(t * 3.0) * 0.9)
			return v
		"strafe":
			# Circle the throne at range.
			var sp2 := strike_point()
			var rel := Vector3(position.x - sp2.x, 0, position.z - sp2.z)
			var r := rel.length()
			var tangent := Vector3(-rel.z, 0, rel.x).normalized() * strafe_dir
			var radial := rel.normalized() * (6.5 - r) * 0.8
			if absf(position.x) > 5.8:
				strafe_dir = -signf(position.x) * signf(tangent.x) * strafe_dir if tangent.x != 0.0 else strafe_dir
			return (tangent * spd * 0.95 + radial)
		"backstep":
			var away := Vector3(position.x, 0, position.z) - strike_point()
			return away.normalized() * spd * 1.4
		"recover":
			return Vector3(sin(phase) * 0.3, 0, -1).normalized() * spd * 0.9
	return Vector3.ZERO


# --- Animation ----------------------------------------------------------------

func _animate(delta: float, vel: Vector3) -> void:
	rotation.y = atan2(position.x, position.z)
	var spd := Vector2(vel.x, vel.z).length()
	var moving := spd > 0.3 and action == ""
	var k := 1.0 - exp(-delta * 16.0)
	var stride := sin(t * 11.0) if moving else 0.0

	leg_l.rotation.x = lerpf(leg_l.rotation.x, stride * 0.7, k)
	leg_r.rotation.x = lerpf(leg_r.rotation.x, -stride * 0.7, k)
	if roll_t <= 0.0:
		rig.position.y = absf(stride) * 0.05
	torso.scale.y = 1.0 + sin(t * 2.2) * 0.012

	var squash := action == "dash" and roll_t <= 0.0
	rig.scale = rig.scale.lerp(Vector3(1.15, 0.8, 1.15) if squash else Vector3.ONE, 1.0 - exp(-delta * 20.0))
	# Roll: a full tumble sideways. Weave: the torso sways and dips.
	if roll_t > 0.0:
		rig.rotation.z = -roll_side * TAU * (1.0 - roll_t / roll_dur)
		rig.position.y = 0.35 * sin(PI * (1.0 - roll_t / roll_dur))
	else:
		rig.rotation.z = lerpf(rig.rotation.z, 0.0, 1.0 - exp(-delta * 20.0))
	torso.rotation.z = sin(t * 6.5 + phase) * 0.32 * weave_amt
	head.rotation.z = -torso.rotation.z * 0.5
	if state == "strafe":
		torso.rotation.y = lerpf(torso.rotation.y, -strafe_dir * 0.5, k)
	else:
		torso.rotation.y = lerpf(torso.rotation.y, 0.0, k)
	if countdown:
		if state == "windup" or state == "feint":
			var left := (windup_ticks if state == "windup" else 3) - state_ticks
			countdown.text = str(maxi(1, left))
			countdown.modulate = Color(0.8, 0.3, 1.0) if unparryable_next() else Color(1.0, 0.25, 0.2)
			countdown.visible = true
		else:
			countdown.visible = false

	# Pose targets: [lean, sword shoulder, sword elbow, sword wrist, shield shoulder, shield elbow]
	var striking := (state == "recover" and state_t < 0.22) or swing_t > 0.0
	var pose := [-0.18 if moving else 0.0, 0.35 - stride * 0.35, 0.6, 0.0, 0.3 + stride * 0.35, 0.9]
	if state == "windup":
		pose = [0.12, 2.7, 0.4, 0.0, 0.5, 0.9]
	elif striking:
		pose = [-0.3, 1.1, 0.1, -1.8, 0.2, 0.7]
	elif state == "lunge_charge":
		pose = [-0.45, 0.2, 1.2, 0.3, 0.6, 1.0]
	elif state == "lunge":
		pose = [-0.5, 1.4, 0.0, -0.1, 0.3, 0.8]
	elif state == "bolt_charge":
		pose = [0.1, 0.35, 0.6, 0.0, 2.6, -0.2]
	elif state == "leap_charge" or state == "leap":
		pose = [0.2, 2.9, 0.3, 0.0, 0.8, 0.6]
	elif state == "victory":
		pose = [0.05, 3.1, 0.0, -1.53, 0.2, 0.6]
	elif state == "feint":
		pose = [0.1, 2.4, 0.6, 0.0, 0.5, 0.9]
	elif state == "backstep":
		pose = [0.25, 0.8, 0.8, 0.0, 1.2, 0.4]
	if parry_t > 0.0:
		pose[1] = 1.2
		pose[2] = 0.6
		pose[3] = -0.2
	if ward_t > 0.0 or anchor_t > 0.0:
		pose[4] = 1.3
		pose[5] = 0.4
	if root_t > 0.0:
		pose[0] = sin(t * 18.0) * 0.08
		pose[1] = 0.8 + sin(t * 20.0) * 0.3
		pose[4] = 0.8 - sin(t * 20.0) * 0.3
	var arm_k := 1.0 - exp(-delta * (30.0 if striking else 18.0))
	torso.rotation.x = lerpf(torso.rotation.x, pose[0], k)
	arm_r.rotation.x = lerp_angle(arm_r.rotation.x, pose[1], arm_k)
	elbow_r.rotation.x = lerp_angle(elbow_r.rotation.x, pose[2], arm_k)
	wrist_r.rotation.x = lerp_angle(wrist_r.rotation.x, pose[3], arm_k)
	arm_l.rotation.x = lerp_angle(arm_l.rotation.x, pose[4], k)
	elbow_l.rotation.x = lerp_angle(elbow_l.rotation.x, pose[5], k)
	# Keep the shield face pointed at the throne whatever the arm is doing.
	shield.rotation.x = -(arm_l.rotation.x + elbow_l.rotation.x + torso.rotation.x)

	# The cape billows with speed and flutters at the hem.
	cape_upper.rotation.x = lerpf(cape_upper.rotation.x, -(0.08 + minf(spd, 6.0) * 0.1), k)
	cape_lower.rotation.x = -minf(spd, 6.0) * 0.06 + sin(t * 9.0) * 0.08
	if halo:
		halo.rotation.y += delta * 2.0

	# Telegraph: the blade burns red before any blow that will land on you (your parry cue).
	if state in ["windup", "feint"] and unparryable_next():
		blade_mat.emission = Color(0.75, 0.2, 1.0)  # violet: this one cannot be parried, lean out of it
		blade_mat.emission_energy_multiplier = 6.0
	elif state in ["windup", "feint", "lunge_charge", "lunge", "leap_charge", "leap"]:
		blade_mat.emission = Color(1.0, 0.15, 0.1)
		blade_mat.emission_energy_multiplier = 4.0
	elif parry_t > 0.0:
		blade_mat.emission = Color.WHITE
		blade_mat.emission_energy_multiplier = 6.0
	else:
		blade_mat.emission = blade_base
		blade_mat.emission_energy_multiplier = blade_base_energy

	ward_bubble.visible = ward_t > 0.0
	var flash_e := 3.0 if flash_t > 0.0 else 0.0
	for m in body_mats:
		m.emission_energy_multiplier = flash_e
	if torch_lit:
		torch.light_energy = 2.2 + randf() * 0.6
	sigils.rotation.y += delta * (6.0 if state == "victory" else 1.5)
	if aura:
		var pulse := 0.5 + 0.5 * sin(t * 3.0)
		aura_mat.albedo_color.a = clampf(0.015 + 0.012 * power, 0.015, 0.1) * (0.7 + 0.3 * pulse) + (0.12 if state == "victory" else 0.0)
		aura_light.light_energy = (0.3 + 0.35 * power) * (0.8 + 0.2 * pulse) + (3.0 if state == "victory" else 0.0)
		for m in eye_mats:
			m.emission_energy_multiplier = 6.0 + power * 2.0
		var flap := sin(t * (9.0 if state in ["leap", "descend", "victory"] else 3.0))
		for i in wings.size():
			wings[i].rotation.y = (0.35 + flap * 0.35) * (1.0 if i == 0 else -1.0)
		if state == "descend" and pillar:
			var pm: StandardMaterial3D = pillar.material_override
			pm.albedo_color.a = 0.35
		elif state != "victory" and pillar:
			var pm2: StandardMaterial3D = pillar.material_override
			pm2.albedo_color.a = maxf(0.0, pm2.albedo_color.a - delta * 0.6)
	rig.rotation.x = lerpf(rig.rotation.x, 0.35 if flinch_t > 0.0 else 0.0, 1.0 - exp(-delta * 20.0))
