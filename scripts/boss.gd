extends Node3D
## You: a vast tyrant on the throne, seen in first person. Only your hands are visible, and they
## tell the story. At first they are corrupted: black-violet skin, red veins, thorns, an iron
## shackle with a broken chain, smoke, twitching claws. With every memory restored they purify:
## the skin warms, the veins turn gold then white, the thorns fall away, the shackle becomes a
## gold bracelet, claws become nails, smoke becomes light. (apply_purity, 0..1)
## The fingertips glow in the selected skill's color. A/D lean you along the dais.
##
## TICKS: clicks only QUEUE an action. On each 0.25s tick (driven by main or the overworld) the
## queued cast or parry resolves; cooldowns, the global cooldown and the parry window count ticks.
## WALKER: the same hands, by daylight. In walker mode the camera sits at eye height and WASD walks
## you through the city of Vael (overworld.gd handles collisions and casting).

const Fx := preload("res://scripts/fx.gd")
const Swords := preload("res://scripts/swords.gd")
const Dialogue := preload("res://scripts/dialogue.gd")
const Vox := preload("res://scripts/vox.gd")
# Hands held up before you, backs toward your eyes and fingers rising, the forearms dropping
# out of view below: the way the hands are framed in the reference studies.
const R_REST := Vector3(0.28, -0.37, -0.62)
const L_REST := Vector3(-0.28, -0.37, -0.62)
const LEAN_LIMIT := 2.6
const HAND_SCALE := 1.45
const YAW_LIMIT := 0.95
const PITCH_MIN := -0.8
const PITCH_MAX := 0.25
const SENSITIVITY := 0.0025

# Which hand performs each skill: "r", "l" or "both".
const HAND_FOR := {
	"fireball": "r", "lance": "r", "lightning": "r", "volley": "r", "doom": "r", "rain": "r", "siphon": "r",
	"spikes": "l", "chains": "l", "well": "l", "pillar": "l", "bloom": "l", "maw": "l", "hex": "l", "ghouls": "l",
	"glacier": "r", "thunder": "r", "nullorb": "r", "sweep": "r", "grasp": "r", "masonry": "r",
	"cinder": "l", "bonecage": "l", "leech": "l", "stomp": "both",
	"slam": "both", "eclipse": "both", "meteor": "both", "wall": "both", "tide": "both", "timerend": "both", "hands": "both",
}
const PARRY_COOLDOWN := 0.9

var game
var head: Node3D
var cam: Camera3D
var yaw := 0.0
var pitch := -0.42
var lean_input := 0.0  # -1..1, set by main from A/D
var right_hand: Node3D
var left_hand: Node3D
var skin_mat: StandardMaterial3D
var orb_mat: StandardMaterial3D
var orb: MeshInstance3D
var orb_light: OmniLight3D
var gem_mat: StandardMaterial3D
var claw_mat: StandardMaterial3D
var vein_mat: StandardMaterial3D
var thorn_mat: StandardMaterial3D
var sleeve_mat: StandardMaterial3D
var trim_mat: StandardMaterial3D
var scar_mat: StandardMaterial3D
var signet_mat: StandardMaterial3D
var ring_mark_mat: StandardMaterial3D
var crease_mat: StandardMaterial3D
var skin_mid_mat: StandardMaterial3D
var skin_tip_mat: StandardMaterial3D
var claw_cone_mat: StandardMaterial3D
var flap_mat: StandardMaterial3D
var purity := 0.0
# Voxel hands (Blender, tools/voxel_hands.py): neutral voxels tinted by these, synced in apply_purity
var vox_skin: StandardMaterial3D
var vox_mid: StandardMaterial3D
var vox_tip: StandardMaterial3D
var vox_vein: StandardMaterial3D
var vox_sleeve: StandardMaterial3D
var vox_trim: StandardMaterial3D
var hand_parts: Array = []  # per hand: {thorns, shackle, chain, bracelet, smoke, motes, tips, joints}
var anim_r := 0.0
var anim_l := 0.0
var anim_both := 0.0
var recoil := 0.0
var shake_amt := 0.0
var t := 0.0
var cooldowns := {}   # ticks left per skill
var selected := 0
# Parry: right-click raises a guard for a few ticks. Blows that land inside it hit a lesser part of you.
var parry_t := 0.0     # ticks the guard stays up
var parry_cd := 0.0    # ticks until you can parry again
var guard := 0.0
var gcd := 0
var queued_cast := ""
var queued_parry := false
var tick_flash := 0.0
# Parry feedback: a clean parry CLASHES (hands snap out, sparks, hit-stop); an empty one FUMBLES
var parry_hit := false
var clash_t := 0.0
var fumble_t := 0.0
# Walker (daytime) mode
var walker := false
var ow                 # the overworld, when walking
var move_input := Vector2.ZERO
var sprint := false
var walk_t := 0.0
var vel := Vector3.ZERO
# Spell gestures: every cast plays a gesture of the hand (see GESTURE_FOR / _gesture_offsets)
var gesture := ""
var gesture_t := 0.0     # 1 -> 0 over the gesture
var gesture_side := "r"  # "r", "l" or "both"
var gesture_col := Color.WHITE
var palm_glows: Array = []   # per hand: [mesh, light, sparks]
var fidget_t := 0.0
var fidget_hand := 0
var fidget_cd := 4.0
var wand: Node3D
var debug_freeze := -1.0     # debug: hold the gesture at this point (for screenshots)
var holding := false   # a blade in the right hand (the fingers close around its grip)
var swing := 0.0       # 1 -> 0 over a sword swing
var swing_rate := 2.5  # 1 / swing duration
var swing_style := "diagonal"
var swing_mirror := 1.0
var swing_count := 0
var weapon_node: Node3D
var weapon_tip: Node3D
var weapon_orbit: Node3D
var trail: CPUParticles3D
var arena_blade_t := 0.0   # arena: the summoned blade fades after the cut
# Traversal (walker)
var crouch := false
var jump_held := false
var vy := 0.0
var on_ground := true
var coyote := 0.0
var stamina := 100.0
var dodge_t := 0.0
var dodge_cd := 0.0
var dodge_dir := Vector3.ZERO
var dodge_side := 1.0
var slide_t := 0.0
var slide_dir := Vector3.ZERO
var mantle_t := 0.0
var mantle_from := Vector3.ZERO
var mantle_to := Vector3.ZERO
var eye := 1.65
var step_t := 0.0
var land_dip := 0.0

# Every blade has its own way of cutting: keyframes [progress, hand offset, hand rotation].
# "mirror" styles alternate direction on every other swing (a forehand, then a backhand).
const SWINGS := {
	"slash": {"mirror": true, "keys": [[0.0, Vector3.ZERO, Vector3.ZERO], [0.22, Vector3(0.16, 0.06, 0.06), Vector3(0.35, 0.9, -0.4)],
		[0.5, Vector3(-0.34, -0.02, -0.22), Vector3(-0.15, -0.95, 0.55)], [1.0, Vector3.ZERO, Vector3.ZERO]]},
	"diagonal": {"mirror": true, "keys": [[0.0, Vector3.ZERO, Vector3.ZERO], [0.2, Vector3(0.1, 0.22, 0.05), Vector3(0.75, 0.3, -0.3)],
		[0.55, Vector3(-0.4, -0.14, -0.2), Vector3(-0.9, -0.3, 0.9)], [1.0, Vector3.ZERO, Vector3.ZERO]]},
	"backhand": {"mirror": false, "keys": [[0.0, Vector3.ZERO, Vector3.ZERO], [0.18, Vector3(-0.22, 0.04, 0.04), Vector3(0.2, -0.85, 0.5)],
		[0.45, Vector3(0.36, -0.04, -0.2), Vector3(-0.1, 1.0, -0.6)], [0.7, Vector3(0.3, 0.0, -0.1), Vector3(0.0, 0.9, -0.5)], [1.0, Vector3.ZERO, Vector3.ZERO]]},
	"overhead": {"mirror": false, "keys": [[0.0, Vector3.ZERO, Vector3.ZERO], [0.3, Vector3(0.0, 0.32, 0.12), Vector3(1.3, 0.0, 0.0)],
		[0.55, Vector3(-0.04, -0.22, -0.3), Vector3(-1.05, 0.0, 0.05)], [1.0, Vector3.ZERO, Vector3.ZERO]]},
	"chop": {"mirror": false, "keys": [[0.0, Vector3.ZERO, Vector3.ZERO], [0.3, Vector3(0.06, 0.38, 0.22), Vector3(1.5, 0.25, 0.0)],
		[0.48, Vector3(0.07, 0.4, 0.24), Vector3(1.55, 0.25, 0.05)], [0.62, Vector3(0.0, -0.28, -0.32), Vector3(-1.25, 0.0, 0.1)],
		[0.8, Vector3(0.0, -0.26, -0.3), Vector3(-1.2, 0.0, 0.1)], [1.0, Vector3.ZERO, Vector3.ZERO]]},
	"sweep": {"mirror": true, "keys": [[0.0, Vector3.ZERO, Vector3.ZERO], [0.3, Vector3(0.42, -0.04, 0.14), Vector3(0.1, 1.2, -0.25)],
		[0.7, Vector3(-0.55, -0.06, -0.18), Vector3(-0.1, -1.3, 0.3)], [1.0, Vector3.ZERO, Vector3.ZERO]], "roll": 0.12},
	"thrust2": {"mirror": false, "keys": [[0.0, Vector3.ZERO, Vector3.ZERO], [0.1, Vector3(0.0, 0.0, 0.1), Vector3(0.0, 0.0, 0.0)],
		[0.25, Vector3(-0.05, 0.02, -0.4), Vector3(-0.35, -0.2, 0.0)], [0.42, Vector3(0.0, 0.0, 0.05), Vector3(0.0, 0.0, 0.0)],
		[0.6, Vector3(-0.08, 0.06, -0.42), Vector3(-0.4, -0.3, 0.2)], [1.0, Vector3.ZERO, Vector3.ZERO]]},
	"flourish": {"mirror": false, "spin": true, "keys": [[0.0, Vector3.ZERO, Vector3.ZERO], [0.35, Vector3(-0.1, -0.12, 0.0), Vector3(-0.4, -0.6, 0.6)],
		[0.62, Vector3(0.34, 0.24, -0.25), Vector3(0.9, 0.8, -0.7)], [1.0, Vector3.ZERO, Vector3.ZERO]]},
	"lunge_sweep": {"mirror": false, "keys": [[0.0, Vector3.ZERO, Vector3.ZERO], [0.15, Vector3(0.05, 0.0, 0.18), Vector3(0.1, 0.0, 0.0)],
		[0.35, Vector3(-0.05, 0.0, -0.55), Vector3(-0.3, 0.0, 0.0)], [0.7, Vector3(-0.5, -0.05, -0.3), Vector3(-0.1, -1.2, 0.5)], [1.0, Vector3.ZERO, Vector3.ZERO]]},
	"rising": {"mirror": false, "keys": [[0.0, Vector3.ZERO, Vector3.ZERO], [0.25, Vector3(-0.3, -0.25, 0.05), Vector3(-0.6, -0.6, 0.7)],
		[0.55, Vector3(0.35, 0.35, -0.25), Vector3(1.2, 0.7, -0.8)], [1.0, Vector3.ZERO, Vector3.ZERO]], "roll": -0.08},
}
const R_ROT := Vector3(1.0, 0.18, -0.22)
const L_ROT := Vector3(1.0, -0.18, 0.22)
# Holding a sword: the hand turns thumb-up, like a handshake, so the blade rises out of the fist.
const HOLD_ROT := Vector3(0.25, 0.2, -1.4)
const HOLD_POS := Vector3(0.3, -0.27, -0.5)


func _ready() -> void:
	head = Node3D.new()
	head.position = Vector3(0, 1.65, 0) if walker else Vector3(0, 3.5, 1.0)
	add_child(head)
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.02
	cam.far = 80.0
	head.add_child(cam)
	cam.current = true

	skin_mat = Fx.mat(Color(0.42, 0.37, 0.5))
	skin_mat.emission_enabled = true
	skin_mat.emission_energy_multiplier = 0.25
	claw_mat = Fx.mat(Color(0.08, 0.05, 0.07), 1.0)
	vein_mat = Fx.mat(Color(1.0, 0.1, 0.15), 2.5)
	thorn_mat = Fx.mat(Color(0.06, 0.03, 0.06))
	sleeve_mat = Fx.mat(Color(0.2, 0.08, 0.25))
	trim_mat = Fx.mat(Color(0.5, 0.1, 0.12), 0.4)
	scar_mat = Fx.mat(Color(0.6, 0.45, 0.5))
	signet_mat = Fx.mat(Color(0.9, 0.1, 0.15), 2.0)
	ring_mark_mat = Fx.mat(Color(0.8, 0.75, 0.72))
	crease_mat = Fx.mat(Color(0.1, 0.04, 0.1))
	skin_mid_mat = Fx.mat(Color(0.2, 0.16, 0.22))
	skin_tip_mat = Fx.mat(Color(0.06, 0.04, 0.07))
	claw_cone_mat = Fx.mat(Color(0.03, 0.02, 0.03))
	claw_cone_mat.roughness = 0.25
	claw_cone_mat.metallic = 0.3
	flap_mat = Fx.mat(Color(0.25, 0.22, 0.26))

	right_hand = _make_hand(1.0)
	right_hand.position = R_REST
	right_hand.rotation = R_ROT
	right_hand.scale = Vector3.ONE * HAND_SCALE
	cam.add_child(right_hand)
	left_hand = _make_hand(-1.0)
	left_hand.position = L_REST
	left_hand.rotation = L_ROT
	left_hand.scale = Vector3.ONE * HAND_SCALE
	cam.add_child(left_hand)

	# An invisible marker between the right fingertips: projectiles launch from here.
	orb_mat = Fx.mat(Color.WHITE, 1.0)
	orb = Fx.sphere(0.028, orb_mat, Vector3(0, 0.0, -0.16))
	orb.visible = false
	right_hand.add_child(orb)
	orb_light = OmniLight3D.new()
	orb_light.omni_range = 2.5
	orb_light.light_energy = 1.2
	orb_light.position = Vector3(0, 0.12, -0.15)
	right_hand.add_child(orb_light)

	# Left hand: a crooked wand held like a pencil, along the index finger and pinched by the
	# thumb, its butt resting against the web of the hand.
	wand = Node3D.new()
	wand.position = Vector3(0.03, -0.022, 0.0)
	wand.rotation = Vector3(0.12, -0.3, 0)
	left_hand.add_child(wand)
	var wood := Fx.mat(Color(0.25, 0.15, 0.1))
	var shaft := Fx.cylinder(0.006, 0.01, 0.26, wood, Vector3(0, 0, -0.09))
	shaft.rotation.x = PI / 2.0
	wand.add_child(shaft)
	for k in 3:
		# Knots in the wood
		wand.add_child(Fx.box(Vector3(0.014, 0.014, 0.012), wood, Vector3(0, 0, -0.02 - k * 0.07)))
	var tip := Fx.cylinder(0.004, 0.006, 0.07, wood, Vector3(0.008, 0.004, -0.245))
	tip.rotation = Vector3(PI / 2.0, 0, 0.3)
	wand.add_child(tip)
	gem_mat = Fx.mat(Color.WHITE, 5.0)
	wand.add_child(Fx.box(Vector3.ONE * 0.022, gem_mat, Vector3(0.012, 0.008, -0.285)))
	_voxify_wand()
	# A glow that gathers in each palm while a spell is being shaped, and a spray of sparks on release.
	for hnd in [right_hand, left_hand]:
		var pm := Fx.mat(Color.WHITE, 6.0, 0.85)
		var orbm := Fx.sphere(0.03, pm, Vector3(0, -0.034, -0.02))
		orbm.visible = false
		hnd.add_child(orbm)
		var pl := OmniLight3D.new()
		pl.omni_range = 1.6
		pl.light_energy = 0.0
		pl.position = Vector3(0, -0.06, -0.03)
		hnd.add_child(pl)
		var sp := Fx.particles(Color.WHITE, 14, 0.35, 0.6, 0.008, true)
		sp.emitting = false
		sp.local_coords = true
		sp.position = Vector3(0, -0.03, -0.04)
		hnd.add_child(sp)
		palm_glows.append([orbm, pl, sp, pm])
	apply_purity(GameState.purity())


## Builds one hand and forearm. Local axes: fingers point along -Z, the back of the hand is +Y,
## the palm faces -Y. `side` is +1 for the right hand (thumb on -X) and -1 for the left.
## Proportions follow life: the fingers are about as long as the palm, the middle finger longest,
## the pinky short and set lower, the knuckles on an arc, the thumb rooted at the heel of the hand.
## Every finger is three hinged segments, so the hand can be posed (see POSES and _pose_hands).
func _make_hand(side: float) -> Node3D:
	var h := Node3D.new()
	var parts := {"thorns": [], "tips": [], "fingers": [], "thumb": [], "segdata": [], "knobs": [], "nails": [], "claws": [], "flaps": []}
	var iron := Fx.mat(Color(0.22, 0.2, 0.24))
	iron.metallic = 0.7
	var gold := Fx.mat(Color(0.85, 0.65, 0.2), 0.6)
	gold.metallic = 0.8
	# Sleeve: the cuff of a robe (ragged violet when corrupt, white and gold when pure)
	var sleeve := Node3D.new()
	sleeve.position = Vector3(0, 0.0, 0.44)
	h.add_child(sleeve)
	sleeve.add_child(Fx.box(Vector3(0.15, 0.13, 0.14), sleeve_mat, Vector3(0, 0, 0)))
	sleeve.add_child(Fx.box(Vector3(0.158, 0.138, 0.02), trim_mat, Vector3(0, 0, -0.07)))
	var rags: Array = []
	for k in 3:
		var rag := Fx.box(Vector3(0.03, 0.06, 0.01), sleeve_mat, Vector3(-0.045 + k * 0.045, -0.085, -0.055 - (k % 2) * 0.015))
		rag.rotation.x = 0.3
		sleeve.add_child(rag)
		rags.append(rag)
	parts["rags"] = rags
	# Forearm: wider and rounder toward the elbow, flat and narrow at the wrist
	h.add_child(Fx.box(Vector3(0.088, 0.07, 0.17), skin_mat, Vector3(0, -0.004, 0.32)))
	h.add_child(Fx.box(Vector3(0.076, 0.056, 0.14), skin_mat, Vector3(0, -0.006, 0.17)))
	h.add_child(Fx.box(Vector3(0.04, 0.016, 0.22), skin_mat, Vector3(side * 0.016, 0.03, 0.29)))  # the muscle along the top
	for k in 3:
		var v := Fx.box(Vector3(0.006, 0.005, 0.13), vein_mat, Vector3(-0.024 + k * 0.024, 0.036, 0.25 + (k % 2) * 0.04))
		v.rotation.y = (k - 1) * 0.22
		h.add_child(v)
	for k in 2:
		var scar := Fx.box(Vector3(0.04, 0.004, 0.007), scar_mat, Vector3(side * 0.008, 0.038, 0.2 + k * 0.07))
		scar.rotation.y = 0.5 * side
		h.add_child(scar)
	# Thorns breaking through the skin (corruption)
	for k in 5:
		var th := Fx.cylinder(0.0, 0.01, 0.045 + (k % 3) * 0.012, thorn_mat, Vector3(side * 0.036 * (1 if k % 2 == 0 else -0.6), 0.036, 0.16 + k * 0.055))
		th.rotation.z = -side * 0.5 * (1 if k % 2 == 0 else -1)
		h.add_child(th)
		parts["thorns"].append(th)
	# Iron shackle with a broken chain (corruption) / gold bracelet (purity), at the wrist
	var shackle := Node3D.new()
	shackle.position = Vector3(0, -0.006, 0.105)
	h.add_child(shackle)
	shackle.add_child(Fx.box(Vector3(0.1, 0.085, 0.05), iron))
	for k in 3:
		shackle.add_child(Fx.box(Vector3(0.012, 0.012, 0.055), Fx.mat(Color(0.15, 0.13, 0.16)), Vector3(-0.035 + k * 0.035, 0.044, 0)))
	shackle.add_child(Fx.box(Vector3(0.024, 0.024, 0.024), iron, Vector3(side * 0.055, 0, 0)))
	var chain := Node3D.new()
	shackle.add_child(chain)
	for k in 4:
		chain.add_child(Fx.box(Vector3(0.018 if k % 2 == 0 else 0.007, 0.026, 0.018 if k % 2 == 1 else 0.007), iron, Vector3(0, -0.055 - k * 0.023, 0)))
	var bracelet := Node3D.new()
	bracelet.position = Vector3(0, -0.006, 0.105)
	h.add_child(bracelet)
	bracelet.add_child(Fx.box(Vector3(0.088, 0.072, 0.026), gold))
	bracelet.add_child(Fx.box(Vector3.ONE * 0.018, Fx.mat(Color(1.0, 0.9, 0.5), 5.0), Vector3(0, 0.042, 0)))
	# Wrist, then the palm: narrow at the heel, widest across the knuckles
	h.add_child(Fx.box(Vector3(0.07, 0.044, 0.04), skin_mat, Vector3(0, -0.006, 0.075)))
	h.add_child(Fx.box(Vector3(0.082, 0.034, 0.06), skin_mat, Vector3(0, -0.004, 0.03)))
	h.add_child(Fx.box(Vector3(0.1, 0.032, 0.06), skin_mat, Vector3(0, 0, -0.025)))
	# The heel of the thumb (thenar pad) and the outer heel (hypothenar), on the palm side
	h.add_child(Fx.box(Vector3(0.036, 0.024, 0.06), skin_mat, Vector3(-side * 0.03, -0.018, 0.035)))
	h.add_child(Fx.box(Vector3(0.026, 0.018, 0.06), skin_mat, Vector3(side * 0.034, -0.016, 0.03)))
	# Tendons fanning out to each knuckle on the back of the hand, and veins between them
	var knuckle_x := [-0.039, -0.013, 0.013, 0.038]
	var knuckle_z := [-0.056, -0.062, -0.058, -0.046]
	for k in 4:
		var kx: float = knuckle_x[k] * -side
		var tendon := Fx.box(Vector3(0.006, 0.006, 0.08), skin_mat, Vector3(kx * 0.7, 0.018, -0.012))
		tendon.rotation.y = kx * 2.5
		h.add_child(tendon)
	for k in 3:
		var v2 := Fx.box(Vector3(0.005, 0.004, 0.07), vein_mat, Vector3((-0.026 + k * 0.026), 0.017, 0.01))
		v2.rotation.y = (k - 1) * 0.3
		h.add_child(v2)
	# Fingers: [proximal, middle, distal] lengths. Index, middle, ring, pinky.
	var lens := [[0.044, 0.027, 0.021], [0.05, 0.031, 0.023], [0.046, 0.029, 0.021], [0.035, 0.021, 0.018]]
	var widths := [0.02, 0.021, 0.019, 0.016]
	for i in 4:
		var kx: float = knuckle_x[i] * -side   # index on the thumb side
		var w: float = widths[i]
		# The knuckle itself, a bump on the back of the hand
		h.add_child(Fx.box(Vector3(w * 1.12, 0.016, 0.018), skin_mat, Vector3(kx, 0.012, knuckle_z[i] + 0.004)))
		var segs: Array = []
		var parent: Node3D = h
		var pos := Vector3(kx, 0.0, knuckle_z[i])
		var prev_seg: Array = []
		for k in 3:
			var L: float = lens[i][k]
			var pivot := Node3D.new()
			pivot.position = pos
			parent.add_child(pivot)
			var ww := w * (1.0 - 0.1 * k)
			# Corruption creeps up from the fingertips: the outer segments are the darkest.
			var zone: Material = skin_mid_mat if k == 0 else skin_tip_mat
			var box := Fx.box(Vector3(ww, ww * 0.85, L + 0.002), zone, Vector3(0, 0, -L * 0.5))
			pivot.add_child(box)
			if k > 0:
				# A swollen, knobbly knuckle at the joint (it shrinks away as the hand heals)
				var knob := Fx.box(Vector3(ww * 1.3, ww * 1.1, 0.012), zone, Vector3(0, 0, 0))
				pivot.add_child(knob)
				parts["knobs"].append(knob)
			if k < 2:
				# A crease at each joint, on the back of the finger
				pivot.add_child(Fx.box(Vector3(ww * 0.8, 0.003, 0.004), crease_mat, Vector3(0, ww * 0.43, -L)))
			if not prev_seg.is_empty():
				prev_seg[3] = pivot
			prev_seg = [pivot, box, L, null, ww, false]  # [pivot, box, length, next node, width, next is the tip]
			parts["segdata"].append(prev_seg)
			segs.append(pivot)
			parent = pivot
			pos = Vector3(0, 0, -L)
		# The nail (pure) on the back of the last segment, and the claw (corrupt) growing out of it
		var dl: float = lens[i][2]
		var tip := Node3D.new()
		tip.position = Vector3(0, w * 0.42, -dl * 0.55)
		parent.add_child(tip)
		prev_seg[3] = tip
		prev_seg[5] = true
		var nail := Fx.box(Vector3(w * 0.78, 0.004, dl * 0.75), claw_mat, Vector3(0, 0, -dl * 0.18))
		tip.add_child(nail)
		parts["nails"].append(nail)
		var claw := Fx.cylinder(0.0, w * 0.34, 0.036, claw_cone_mat, Vector3(0, -w * 0.4, -0.016))
		claw.rotation.x = -PI / 2.0
		var claw_root := Node3D.new()
		claw_root.position = Vector3(0, 0, -dl * 0.3)
		tip.add_child(claw_root)
		claw_root.add_child(claw)
		parts["claws"].append(claw_root)
		parts["tips"].append(tip)
		parts["fingers"].append(segs)
		# Rings: a signet on the right index finger; a pale band where a ring used to be on the left ring finger
		if i == 0 and side > 0.0:
			segs[0].add_child(Fx.box(Vector3(w * 1.25, w * 1.1, 0.008), gold, Vector3(0, 0, -lens[i][0] * 0.6)))
			segs[0].add_child(Fx.box(Vector3(0.012, 0.007, 0.012), signet_mat, Vector3(0, w * 0.6, -lens[i][0] * 0.6)))
		elif i == 2 and side < 0.0:
			segs[0].add_child(Fx.box(Vector3(w * 1.06, w * 0.95, 0.006), ring_mark_mat, Vector3(0, 0, -lens[i][0] * 0.6)))
	# The thumb: rooted at the heel of the hand, angled out, three segments, a nail
	var tb := Node3D.new()
	tb.position = Vector3(-side * 0.036, -0.012, 0.045)
	tb.rotation = Vector3(0, side * 0.6, side * 0.5)
	h.add_child(tb)
	tb.add_child(Fx.box(Vector3(0.026, 0.024, 0.05), skin_mat, Vector3(0, 0, -0.025)))
	var t1 := Node3D.new()
	t1.position = Vector3(0, 0, -0.05)
	tb.add_child(t1)
	t1.add_child(Fx.box(Vector3(0.023, 0.021, 0.032), skin_mid_mat, Vector3(0, 0, -0.016)))
	var t2 := Node3D.new()
	t2.position = Vector3(0, 0, -0.032)
	t1.add_child(t2)
	t2.add_child(Fx.box(Vector3(0.021, 0.019, 0.026), skin_tip_mat, Vector3(0, 0, -0.013)))
	var ttip := Node3D.new()
	ttip.position = Vector3(0, 0.0095, -0.015)
	t2.add_child(ttip)
	var tnail := Fx.box(Vector3(0.016, 0.004, 0.02), claw_mat, Vector3(0, 0, -0.005))
	ttip.add_child(tnail)
	parts["nails"].append(tnail)
	var tclaw_root := Node3D.new()
	tclaw_root.position = Vector3(0, 0, -0.008)
	ttip.add_child(tclaw_root)
	var tclaw := Fx.cylinder(0.0, 0.009, 0.05, claw_cone_mat, Vector3(0, -0.009, -0.025))
	tclaw.rotation.x = -PI / 2.0
	tclaw_root.add_child(tclaw)
	parts["claws"].append(tclaw_root)
	parts["tips"].append(ttip)
	parts["thumb"] = [tb, t1, t2]
	# Peeling skin: torn flaps lifting off the forearm and the back of the hand
	for k in 6:
		var flap := Fx.box(Vector3(0.026, 0.003, 0.03), flap_mat, Vector3(side * (0.03 - (k % 3) * 0.028), 0.038 if k < 4 else 0.018, 0.32 - k * 0.055))
		flap.rotation = Vector3(0.35 + (k % 2) * 0.25, k * 0.9, 0.15 * side)
		h.add_child(flap)
		parts["flaps"].append(flap)
	# Cracks of red light in corrupted skin
	var cracks := Node3D.new()
	h.add_child(cracks)
	for k in 4:
		var c := Fx.box(Vector3(0.003, 0.003, 0.03 + k * 0.008), vein_mat, Vector3(side * (0.016 - k * 0.01), 0.037, 0.18 + k * 0.05))
		c.rotation.y = (0.6 if k % 2 == 0 else -0.5)
		cracks.add_child(c)
	parts["cracks"] = cracks
	# Smoke rising off a corrupted arm; motes of light around a pure one
	var smoke := Fx.particles(Color(0.12, 0.04, 0.14), 18, 1.2, 0.25, 0.035)
	smoke.gravity = Vector3(0, 0.4, 0)
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	smoke.emission_box_extents = Vector3(0.04, 0.025, 0.16)
	smoke.position = Vector3(0, 0.03, 0.22)
	(smoke.mesh as BoxMesh).material = Fx.mat(Color(0.1, 0.03, 0.12), 0.0, 0.7)
	h.add_child(smoke)
	var motes := Fx.particles(Color(1.0, 0.9, 0.55), 8, 1.4, 0.12, 0.01)
	motes.gravity = Vector3(0, 0.25, 0)
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(0.06, 0.04, 0.2)
	motes.position = Vector3(0, 0.04, 0.12)
	motes.local_coords = true
	h.add_child(motes)
	parts["shackle"] = shackle
	parts["chain"] = chain
	parts["bracelet"] = bracelet
	parts["smoke"] = smoke
	parts["motes"] = motes
	parts["side"] = side
	hand_parts.append(parts)
	_voxify_hand(h, parts, side)
	return h


func _vox_mat(src: Material, glow: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var base := src as BaseMaterial3D
	if base:
		m.albedo_texture = base.albedo_texture
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 0.9
	if glow:
		m.emission_enabled = true
		m.emission_texture = m.albedo_texture
		m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY  # tint the white vein texels (ADD would wash them white)
		m.emission_energy_multiplier = 2.5
	return m


## Swap the box skin of a hand for the Blender voxel hand (if it exists). The joints, claws,
## nails, knobs, thorns, shackle, bracelet, flaps and cracks stay: they are the purity story.
func _voxify_hand(h: Node3D, parts: Dictionary, side: float) -> void:
	var vp := Vox.parts("hand_r" if side > 0.0 else "hand_l")
	if vp.is_empty():
		return
	if vox_skin == null:
		var any: MeshInstance3D = vp.values()[0]
		var src := any.mesh.surface_get_material(0)
		vox_skin = _vox_mat(src, false)
		vox_mid = _vox_mat(src, false)
		vox_tip = _vox_mat(src, false)
		vox_sleeve = _vox_mat(src, false)
		vox_trim = _vox_mat(src, false)
		vox_vein = _vox_mat(src, true)
	var skins := [skin_mat, vein_mat, scar_mat]
	for c in h.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).material_override in skins:
			h.remove_child(c)
			c.queue_free()
	for nm in ["forearm", "palm"]:
		if vp.has(nm):
			_vox_attach(h, vp[nm], vox_skin)
	# The sleeve and its trim (the rags stay)
	for c in h.get_children():
		if c is Node3D and not (c is MeshInstance3D) and (c as Node3D).position.z > 0.4:
			for cc in c.get_children():
				if cc is MeshInstance3D and ((cc as MeshInstance3D).material_override == trim_mat or ((cc as MeshInstance3D).material_override == sleeve_mat and ((cc as MeshInstance3D).mesh as BoxMesh).size.x > 0.1)):
					c.remove_child(cc)
					cc.queue_free()
	if vp.has("sleeve"):
		_vox_attach(h, vp["sleeve"], vox_sleeve)
	if vp.has("trim"):
		_vox_attach(h, vp["trim"], vox_trim)
	# Finger segments: replace each skin box, keep the knob, nail and claw
	var segs: Array = parts["segdata"]
	for n in segs.size():
		var sd: Array = segs[n]
		var nm := "f%d_%d" % [n / 3, n % 3]
		if not vp.has(nm):
			continue
		var pivot: Node3D = sd[0]
		var box: MeshInstance3D = sd[1]
		box.queue_free()
		pivot.remove_child(box)
		for c in pivot.get_children():
			if c is MeshInstance3D and (c as MeshInstance3D).material_override == crease_mat:
				pivot.remove_child(c)
				c.queue_free()
		var part: MeshInstance3D = vp[nm]
		_vox_attach(pivot, part, vox_mid if n % 3 == 0 else vox_tip)
		part.set_meta("vox", true)
		sd[1] = part
	var thumb: Array = parts["thumb"]
	for k in 3:
		var tn: Node3D = thumb[k]
		for c in tn.get_children():
			if c is MeshInstance3D and (c as MeshInstance3D).material_override in [skin_mat, skin_mid_mat, skin_tip_mat]:
				tn.remove_child(c)
				c.queue_free()
		if vp.has("t%d" % k):
			_vox_attach(tn, vp["t%d" % k], [vox_skin, vox_mid, vox_tip][k])


func _vox_attach(parent: Node3D, part: MeshInstance3D, mat: StandardMaterial3D) -> void:
	parent.add_child(part)
	# Pick by material: the glowing (vein) surface is not always the second one.
	for s in part.mesh.get_surface_count():
		var sm := part.mesh.surface_get_material(s)
		var glow := sm != null and (str(sm.resource_name).ends_with("_glow") or ((sm as BaseMaterial3D) != null and (sm as BaseMaterial3D).emission_enabled))
		part.set_surface_override_material(s, vox_vein if glow else mat)


## The crooked wand as voxels (the glowing gem stays a live cube).
func _voxify_wand() -> void:
	var vp := Vox.parts("wand")
	if vp.is_empty() or not vp.has("wand"):
		return
	for c in wand.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).material_override != gem_mat:
			wand.remove_child(c)
			c.queue_free()
	wand.add_child(vp["wand"])


## Finger curls per pose, in radians toward the palm: [index, middle, ring, pinky] x [proximal,
## middle, distal]. "ty" swings the thumb out from the palm, "tc" curls its two outer joints.
## Drawn from life: a relaxed hand curls a little more toward the pinky; a sword is held in a full
## hammer grip with the thumb closed over the fingers; a wand in a pencil grip, pinched between
## the thumb and the side of the index finger, the ring and pinky tucked in.
const POSES := {
	"relaxed": {"f": [[0.08, 0.22, 0.16], [0.12, 0.26, 0.18], [0.18, 0.32, 0.22], [0.26, 0.4, 0.26]], "ty": 0.6, "tc": [0.12, 0.18], "spread": 1.3},
	"cast": {"f": [[0.0, 0.05, 0.04], [0.02, 0.06, 0.05], [0.05, 0.08, 0.06], [0.1, 0.1, 0.08]], "ty": 0.85, "tc": [0.0, 0.05], "spread": 2.2},
	"claw": {"f": [[0.15, 0.8, 0.7], [0.18, 0.85, 0.75], [0.22, 0.9, 0.8], [0.3, 0.95, 0.85]], "ty": 0.75, "tc": [0.4, 0.5], "spread": 2.4},
	"grip": {"f": [[1.15, 1.55, 0.95], [1.2, 1.6, 1.0], [1.25, 1.62, 1.0], [1.3, 1.6, 1.0]], "ty": 0.12, "tc": [0.55, 0.6], "spread": 0.2},
	"pinch": {"f": [[0.5, 0.45, 0.3], [0.8, 0.95, 0.55], [1.05, 1.25, 0.75], [1.15, 1.35, 0.85]], "ty": 0.32, "tc": [0.25, 0.3], "spread": 0.5},
	"guard": {"f": [[0.04, 0.04, 0.0], [0.04, 0.04, 0.0], [0.05, 0.05, 0.02], [0.08, 0.06, 0.04]], "ty": 0.95, "tc": [0.0, 0.0], "spread": 1.6},
	"point": {"f": [[0.0, 0.02, 0.0], [0.08, 0.1, 0.05], [1.3, 1.6, 1.0], [1.35, 1.6, 1.0]], "ty": 0.15, "tc": [0.6, 0.6], "spread": 0.4},
	"fist": {"f": [[1.35, 1.65, 1.05], [1.4, 1.65, 1.05], [1.42, 1.65, 1.05], [1.45, 1.6, 1.0]], "ty": 0.08, "tc": [0.7, 0.8], "spread": 0.1},
	"beckon": {"f": [[0.6, 1.1, 0.8], [0.7, 1.2, 0.85], [0.8, 1.25, 0.9], [0.9, 1.3, 0.9]], "ty": 0.5, "tc": [0.2, 0.2], "spread": 0.8},
}


## The gesture each skill is cast with, by school, with a few skills of their own.
const SCHOOL_GESTURE := {"HELLFIRE": "push", "BONE": "slam", "RIME": "point", "STORM": "point_up",
	"VOID": "grasp", "BLOOD": "beckon", "WARLORD": "sweep"}
const SKILL_GESTURE := {"eclipse": "rise", "timerend": "rise", "hands": "rise", "meteor": "rise",
	"wall": "slam", "tide": "slam", "stomp": "slam", "siphon": "beckon", "hex": "beckon", "chains": "grasp",
	"bonecage": "grasp", "spikes": "push", "lightning": "point_up", "thunder": "point_up", "lance": "point", "glacier": "point"}


func gesture_for(id: String) -> String:
	if SKILL_GESTURE.has(id):
		return SKILL_GESTURE[id]
	return SCHOOL_GESTURE.get(GameState.SKILLS[id]["school"], "push")


## Start a gesture: the hand(s) move, the fingers take its shape, the palm glows, sparks fly.
func play_gesture(id: String, side: String) -> void:
	gesture = gesture_for(id)
	gesture_t = 1.0
	gesture_col = GameState.SKILLS[id]["color"]
	if gesture in ["slam", "rise"]:
		side = "both"
	# By day the right hand holds your blade, so spells come from the left.
	if walker and holding and side == "r":
		side = "l"
	gesture_side = side
	for hi in 2:
		if _gesture_hand(hi):
			var sp: CPUParticles3D = palm_glows[hi][2]
			(sp.mesh as BoxMesh).material.albedo_color = gesture_col
			(sp.mesh as BoxMesh).material.emission = gesture_col
			sp.restart()


func _gesture_hand(hi: int) -> bool:
	return gesture_t > 0.0 and (gesture_side == "both" or (gesture_side == "r" and hi == 0) or (gesture_side == "l" and hi == 1))


## Where a gesture moves the hand and how it turns the wrist, at progress p (0 -> 1).
## Returns [position offset, rotation offset] in the camera's frame.
func _gesture_offsets(hi: int, p: float) -> Array:
	var side := 1.0 if hi == 0 else -1.0
	var e := sin(PI * p)                                       # rises and falls
	var hit := _ease(clampf((p - 0.25) / 0.3, 0.0, 1.0))      # the moment of release
	var wind := clampf(p / 0.25, 0.0, 1.0) * (1.0 - hit)       # drawing back first
	var pos := Vector3.ZERO
	var rot := Vector3.ZERO
	match gesture:
		"push":
			# Draw back, then thrust the open palm at him, wrist bent back so the palm faces out.
			pos = Vector3(-side * 0.05 * hit, 0.04 * e, 0.06 * wind - 0.24 * hit * (1.0 - p * 0.6))
			rot = Vector3(0.5 * e, 0, 0)
		"point":
			pos = Vector3(-side * 0.06 * e, 0.03 * e, -0.15 * hit * (1.0 - p * 0.5))
			rot = Vector3(-0.35 * e, side * 0.15 * e, 0)
		"point_up":
			# One finger raised to the sky; the bolt answers the snap.
			pos = Vector3(-side * 0.04 * e, 0.16 * e, -0.05 * e)
			rot = Vector3(0.45 * e, 0, -side * 0.2 * e)
		"grasp":
			# Reach out, claws spread, and close the fist on him.
			pos = Vector3(-side * 0.05 * e, 0.02 * e, -0.2 * e)
			rot = Vector3(-0.15 * e, 0, side * 0.25 * e)
		"beckon":
			# Turn the palm up and draw him in with curling fingers.
			pos = Vector3(-side * 0.06 * e, 0.06 * e, -0.06 * e)
			rot = Vector3(-0.3 * e, 0, side * 1.4 * e)
		"sweep":
			# A flat hand swept across the floor of the hall, outside to inside.
			pos = Vector3(side * 0.18 * (1.0 - hit) - side * 0.28 * hit, -0.04 * e, -0.12 * e)
			rot = Vector3(-0.4 * e, 0, side * (0.4 - 1.2 * hit) * e)
		"slam":
			pos = Vector3(-side * 0.06 * e, 0.12 * wind - 0.12 * hit * (1.0 - p), -0.08 * e)
			rot = Vector3(0.3 * wind - 0.5 * hit * e, 0, 0)
		"rise":
			# Both hands lifted high, palms turning to the sky.
			pos = Vector3(-side * 0.08 * e, 0.13 * e, -0.06 * e)
			rot = Vector3(0.3 * e, 0, side * 1.1 * e)
	return [pos, rot]


## The finger shape a gesture holds at progress p.
func _gesture_pose(p: float) -> String:
	match gesture:
		"push", "sweep", "rise":
			return "cast"
		"point":
			return "point"
		"point_up":
			return "point" if p < 0.7 else "fist"
		"grasp":
			return "claw" if p < 0.45 else "fist"
		"beckon":
			return "beckon" if fmod(p * 3.0, 1.0) > 0.5 else "cast"
		"slam":
			return "fist"
	return "cast"


## How each corrupted finger joint is bent out of true (radians, scaled by corruption).
const CROOK := [[0.12, -0.15, 0.25], [-0.08, 0.2, -0.1], [0.15, -0.05, 0.3], [-0.12, 0.25, 0.15]]


## Blend each hand toward its pose: what it is doing right now decides the pose.
func _pose_hands(delta: float) -> void:
	var k := 1.0 - exp(-delta * 18.0)
	var unrest := 1.0 - purity
	for hi in hand_parts.size():
		var parts: Dictionary = hand_parts[hi]
		var side: float = parts["side"]
		var pose_name := "relaxed"
		if parry_t > 0.0 or guard > 0.5:
			pose_name = "guard" if not (hi == 0 and walker and holding) else "grip"
		elif hi == 0 and walker and holding:
			pose_name = "grip"
		elif _gesture_hand(hi):
			pose_name = _gesture_pose(1.0 - gesture_t)
			if hi == 1 and gesture_side == "l" and gesture in ["point", "push", "point_up"]:
				pose_name = "pinch"  # the wand does the pointing
			elif pose_name == "cast" and purity < 0.4 and gesture != "rise":
				pose_name = "claw"  # a corrupted hand casts with its claws
		elif recoil > 0.4:
			pose_name = "cast"  # flinch: fingers fly open
		elif hi == 1:
			pose_name = "pinch"  # the wand
		var pose: Dictionary = POSES[pose_name]
		var fingers: Array = parts["fingers"]
		for f in 4:
			var segs: Array = fingers[f]
			var curls: Array = pose["f"][f]
			var tw := 0.0
			if fidget_t > 0.0 and hi == fidget_hand and pose_name in ["relaxed", "pinch"]:
				# Idle: the fingers roll in one after another, pinky first, then settle.
				tw += 0.7 * maxf(0.0, sin((1.0 - fidget_t) * PI * 2.0 - (3 - f) * 0.5))
			if pose_name in ["relaxed", "claw"]:
				# Corrupted fingers twitch and clench; pure ones rest.
				tw = sin(t * (7.0 + f * 1.7 + hi) + f) * 0.12 * unrest
				if unrest > 0.3 and randf() < 0.003 * unrest:
					tw += 0.5
			var splay: float = (1.5 - f) * 0.05 * float(pose["spread"]) * side + CROOK[f][0] * unrest * 0.4
			(segs[0] as Node3D).rotation.y = lerp_angle((segs[0] as Node3D).rotation.y, splay, k)
			for j in 3:
				var seg: Node3D = segs[j]
				var crook: float = CROOK[f][j] * unrest  # gnarled: every joint bends a little wrong
				seg.rotation.x = lerp_angle(seg.rotation.x, -(float(curls[j]) + crook + tw * (1.0 if j > 0 else 0.4)), k)
		var thumb: Array = parts["thumb"]
		var tb: Node3D = thumb[0]
		tb.rotation.y = lerp_angle(tb.rotation.y, side * float(pose["ty"]), k)
		(thumb[1] as Node3D).rotation.x = lerp_angle((thumb[1] as Node3D).rotation.x, -float(pose["tc"][0]), k)
		(thumb[2] as Node3D).rotation.x = lerp_angle((thumb[2] as Node3D).rotation.x, -float(pose["tc"][1]), k)


## 0 = corrupted, 1 = enlightened. Called when memories are restored.
func apply_purity(p: float) -> void:
	purity = clampf(p, 0.0, 1.0)
	var pure_skin := Color(0.92, 0.82, 0.72)
	skin_mat.albedo_color = Color(0.34, 0.31, 0.36).lerp(pure_skin, purity)  # grey, gaunt
	skin_mid_mat.albedo_color = Color(0.17, 0.13, 0.19).lerp(pure_skin, purity)
	skin_tip_mat.albedo_color = Color(0.05, 0.035, 0.06).lerp(pure_skin.darkened(0.03), purity)  # ink-dipped fingertips
	flap_mat.albedo_color = Color(0.22, 0.19, 0.23).lerp(pure_skin, purity)
	skin_mat.emission = Color(0.3, 0.0, 0.1).lerp(Color(1.0, 0.85, 0.6), purity)
	skin_mat.emission_energy_multiplier = 0.12 + 0.06 * purity  # a faint inner light, never a glare
	var vc := Color(1.0, 0.1, 0.15).lerp(Color(1.0, 0.75, 0.25), clampf(purity * 2.0, 0.0, 1.0))
	vc = vc.lerp(Color(1.0, 0.98, 0.9), clampf(purity * 2.0 - 1.0, 0.0, 1.0))
	vein_mat.albedo_color = vc
	vein_mat.emission = vc
	vein_mat.emission_energy_multiplier = 2.5 + purity * 2.0
	sleeve_mat.albedo_color = Color(0.2, 0.08, 0.25).lerp(Color(0.92, 0.9, 0.86), purity)
	trim_mat.albedo_color = Color(0.5, 0.1, 0.12).lerp(Color(0.95, 0.75, 0.3), purity)
	trim_mat.emission = trim_mat.albedo_color
	scar_mat.albedo_color = Color(0.6, 0.45, 0.5).lerp(Color(0.95, 0.85, 0.78), purity)
	var gem := Color(0.9, 0.1, 0.15).lerp(Color(1.0, 0.95, 0.8), purity)
	signet_mat.albedo_color = gem
	signet_mat.emission = gem
	ring_mark_mat.albedo_color = skin_mat.albedo_color.lightened(0.25)
	crease_mat.albedo_color = skin_mat.albedo_color.darkened(0.35)
	var c := 1.0 - purity
	if vox_skin:
		# Voxel hands: the neutral voxels take the same colours as the box skin did
		vox_skin.albedo_color = skin_mat.albedo_color * 1.08
		vox_mid.albedo_color = skin_mid_mat.albedo_color * 1.08
		vox_tip.albedo_color = skin_tip_mat.albedo_color * 1.08
		vox_sleeve.albedo_color = sleeve_mat.albedo_color * 1.08
		vox_trim.albedo_color = trim_mat.albedo_color * 1.08
		vox_vein.albedo_color = vc
		vox_vein.emission = vc
		vox_vein.emission_energy_multiplier = 2.0 + purity * 1.5
	for parts in hand_parts:
		# Corrupt fingers are long and thin (up to +35% length), with long black claws and swollen knuckles.
		for sd in parts["segdata"]:
			var L: float = float(sd[2]) * (1.0 + 0.35 * c)
			var ww: float = float(sd[4]) * (1.0 - 0.15 * c)
			var box: MeshInstance3D = sd[1]
			if box.has_meta("vox"):
				box.scale = Vector3(1.0 - 0.15 * c, 1.0 - 0.15 * c, 1.0 + 0.35 * c)
			else:
				(box.mesh as BoxMesh).size = Vector3(ww, ww * 0.85, L + 0.002)
				box.position.z = -L * 0.5
			var nxt: Node3D = sd[3]
			if nxt != null:
				nxt.position.z = -L * 0.55 if sd[5] else -L
		for knob in parts["knobs"]:
			(knob as Node3D).scale = Vector3.ONE * (0.75 + 0.35 * c)
		for cl in parts["claws"]:
			(cl as Node3D).visible = c > 0.08
			(cl as Node3D).scale = Vector3(1.0, 1.0, 0.5 + 0.9 * c)
		for nl in parts["nails"]:
			(nl as Node3D).visible = purity > 0.3
		for fl in parts["flaps"]:
			(fl as Node3D).visible = c > 0.45
		for rag in parts["rags"]:
			(rag as Node3D).visible = purity < 0.5
		(parts["cracks"] as Node3D).visible = purity < 0.34
		var thorns: Array = parts["thorns"]
		var keep := roundi((1.0 - purity) * thorns.size())
		for k in thorns.size():
			(thorns[k] as Node3D).visible = k < keep
		(parts["chain"] as Node3D).visible = purity < 0.17
		(parts["shackle"] as Node3D).visible = purity < 0.5
		(parts["bracelet"] as Node3D).visible = purity >= 0.5
		(parts["smoke"] as CPUParticles3D).emitting = purity < 0.84
		(parts["motes"] as CPUParticles3D).emitting = purity >= 0.34


# --- Aiming -------------------------------------------------------------------

func look(relative: Vector2) -> void:
	var sens := SENSITIVITY * Settings.sensitivity
	var dy := relative.y * (-1.0 if Settings.invert_y else 1.0)
	if walker:
		yaw = wrapf(yaw - relative.x * sens, -PI, PI)
		pitch = clampf(pitch - dy * sens, -1.2, 1.1)
		return
	yaw = clampf(yaw - relative.x * sens, -YAW_LIMIT, YAW_LIMIT)
	pitch = clampf(pitch - dy * sens, PITCH_MIN, PITCH_MAX)


## Used by autoplay: smoothly turn the head toward a world point.
func look_toward(p: Vector3, delta: float) -> void:
	var d := p - head.global_position
	var want_yaw := atan2(-d.x, -d.z)
	if not walker:
		want_yaw = clampf(want_yaw, -YAW_LIMIT, YAW_LIMIT)
	var want_pitch := clampf(atan2(d.y, Vector2(d.x, d.z).length()), PITCH_MIN, PITCH_MAX)
	var k := 1.0 - exp(-delta * 8.0)
	yaw = lerp_angle(yaw, want_yaw, k)
	pitch = lerpf(pitch, want_pitch, k)


## Where the crosshair points: the hero if the ray passes close to him, else the floor.
func aim_point(hero) -> Vector3:
	var origin := cam.global_position
	var dir := -cam.global_transform.basis.z
	if is_instance_valid(hero) and not hero.dead:
		var hc: Vector3 = hero.center()
		var along := (hc - origin).dot(dir)
		if along > 0.0 and (origin + dir * along).distance_to(hc) < 1.0:
			return hc
	if dir.y < -0.01:
		return origin + dir * minf(-origin.y / dir.y, 40.0)
	return origin + dir * 30.0


func hand_tip() -> Vector3:
	return orb.global_position


# --- Casting ------------------------------------------------------------------

func selected_id() -> String:
	if GameState.loadout.is_empty():
		return ""
	selected = clampi(selected, 0, GameState.loadout.size() - 1)
	return GameState.loadout[selected]


func select(i: int) -> void:
	if i >= 0 and i < GameState.loadout.size():
		selected = i


func cycle(step: int) -> void:
	var n := GameState.loadout.size()
	if n > 0:
		selected = posmod(selected + step, n)


func cooldown_left(id: String) -> float:
	return cooldowns.get(id, 0) * GameState.TICK


func cooldown_frac(id: String) -> float:
	return clampf(float(cooldowns.get(id, 0)) / GameState.cooldown_ticks(id), 0.0, 1.0)


## Clicking only queues the cast; it happens on the next tick (see on_tick_begin). Mashing does nothing.
func try_cast(id: String) -> bool:
	if id == "" or cooldowns.get(id, 0) > 0:
		return false
	queued_cast = id
	return true


func try_parry() -> bool:
	if parry_cd > 0:
		return false
	queued_parry = true
	return true


## Start of a tick: resolve whatever was queued since the last one.
func on_tick_begin() -> void:
	tick_flash = 1.0
	if queued_parry and parry_cd <= 0:
		parry_t = GameState.parry_ticks()
		parry_cd = GameState.parry_cd_ticks() + parry_t
		parry_hit = false
		Sfx.play("swing_light", -10.0, 1.4)
	queued_parry = false
	if queued_cast != "" and gcd <= 0:
		var id := queued_cast
		queued_cast = ""
		if cooldowns.get(id, 0) <= 0:
			_cast_now(id)


## End of a tick: everything counts down by one.
func on_tick_end() -> void:
	var was_up := parry_t > 0.0
	parry_t = maxf(0.0, parry_t - 1)
	if was_up and parry_t <= 0.0 and not parry_hit:
		_parry_missed()
	parry_cd = maxf(0.0, parry_cd - 1)
	gcd = maxi(0, gcd - 1)
	for id in cooldowns.keys():
		cooldowns[id] = maxi(0, cooldowns[id] - 1)


func _cast_now(id: String) -> void:
	var ok: bool = ow.spawn_day_attack(id) if walker else game.spawn_attack(id)
	if not ok:
		return
	GameState.on_cast(id)
	cooldowns[id] = GameState.cooldown_ticks(id)
	gcd = GameState.GCD_TICKS
	if GameState.perks.has("echo") and randf() < 0.15 * GameState.asc_mult():
		cooldowns[id] = 0
		game.popup_text(hand_tip() + Vector3(0, 0.3, -1.0), "ECHO", Color(0.8, 0.7, 1.0), 0.8)
	var side: String = {"r": "r", "l": "l"}.get(HAND_FOR.get(id, "r"), "both")
	play_gesture(id, side)


func reset_cooldowns() -> void:
	cooldowns.clear()
	if not walker:
		position.x = 0.0
	parry_t = 0.0
	parry_cd = 0.0
	gcd = 0
	queued_cast = ""
	queued_parry = false


func is_parrying() -> bool:
	return parry_t > 0.0


func parry_cd_frac() -> float:
	return clampf(parry_cd / float(GameState.parry_cd_ticks() + GameState.parry_ticks()), 0.0, 1.0)


## A successful parry: hands clash, sparks, a small kick.
func parried() -> void:
	guard = 1.0
	parry_hit = true
	clash_t = 1.0
	shake(0.3)
	# Sparks off both palms
	for pg in palm_glows:
		var sp: CPUParticles3D = pg[2]
		(sp.mesh as BoxMesh).material = Fx.mat(Color(1.0, 0.9, 0.55), 6.0)
		sp.restart()
		sp.emitting = true
	if game and game.has_method("hitstop"):
		game.hitstop(0.09)


## The guard came up and nothing struck it: the hands fumble and drop.
func _parry_missed() -> void:
	fumble_t = 1.0
	Sfx.play("deny", -8.0, 0.7)
	if game:
		game.popup_text(cam.global_position + (-cam.global_transform.basis.z) * 1.4 + Vector3(0, -0.35, 0), "MISSED", Color(0.75, 0.6, 0.6), 0.9)


## Offsets for the parry animations: [position, rotation] for one hand (side = +1 right, -1 left).
func _parry_fx(side: float) -> Array:
	var pos := Vector3.ZERO
	var rot := Vector3.ZERO
	if clash_t > 0.0:
		var k := 1.0 - clash_t
		var e := sin(PI * minf(1.0, k * 2.5)) * (1.0 - k * 0.6)
		pos += Vector3(side * 0.07, 0.06, -0.13) * e
		rot += Vector3(-0.5, side * 0.3, side * 0.25) * e
	if fumble_t > 0.0:
		var k2 := 1.0 - fumble_t
		var drop := sin(PI * k2)
		pos += Vector3(side * 0.03, -0.14 * drop, 0.06 * drop)
		rot += Vector3(0.45 * drop, 0.0, side * sin(k2 * 28.0) * 0.12 * (1.0 - k2))
	return [pos, rot]


func shake(amount: float) -> void:
	shake_amt = maxf(shake_amt, amount)


func hurt() -> void:
	recoil = 1.0
	shake(0.5)


# --- Per-frame ----------------------------------------------------------------

func _process(delta: float) -> void:
	t += delta
	tick_flash = maxf(0.0, tick_flash - delta * 5.0)

	if walker:
		_walk(delta)
	else:
		# Lean along the dais.
		position.x = clampf(position.x + lean_input * GameState.lean_speed() * delta, -GameState.lean_limit(), GameState.lean_limit())
	head.rotation.y = yaw
	head.rotation.z = lerpf(head.rotation.z, -lean_input * 0.06, 1.0 - exp(-delta * 8.0))
	cam.rotation.x = pitch
	shake_amt = maxf(0.0, shake_amt - delta * 1.5)
	cam.h_offset = randf_range(-1.0, 1.0) * shake_amt * 0.06
	cam.v_offset = randf_range(-1.0, 1.0) * shake_amt * 0.06

	anim_r = maxf(0.0, anim_r - delta * 4.0)
	anim_l = maxf(0.0, anim_l - delta * 4.0)
	anim_both = maxf(0.0, anim_both - delta * 3.0)
	recoil = maxf(0.0, recoil - delta * 3.0)

	var bob := Vector3(0, sin(t * 1.7) * 0.008, 0)
	if walker:
		bob += Vector3(sin(walk_t * 0.5) * 0.012, absf(sin(walk_t)) * 0.02, 0)
	var flinch := Vector3(0, -0.12, 0.12) * recoil
	# Guard: both hands sweep in and up across your face while the parry window is open,
	# palms out, crossing at the wrists.
	var g := 1.0 if parry_t > 0.0 else 0.0
	guard = maxf(guard - delta * 4.0, g)
	var ge := _ease(clampf(guard, 0.0, 1.0))
	var guard_r := Vector3(-0.17, 0.16, -0.02) * ge
	var guard_l := Vector3(0.17, 0.16, -0.02) * ge
	var guard_rot := Vector3(0.35, 0, 0) * ge
	# Spell gestures
	gesture_t = maxf(0.0, gesture_t - delta * 2.6) if debug_freeze < 0.0 else debug_freeze
	var gp := 1.0 - gesture_t
	var go_r := [Vector3.ZERO, Vector3.ZERO]
	var go_l := [Vector3.ZERO, Vector3.ZERO]
	if gesture_t > 0.0:
		if _gesture_hand(0):
			go_r = _gesture_offsets(0, gp)
		if _gesture_hand(1):
			go_l = _gesture_offsets(1, gp)
	# Idle fidgets: now and then one hand rolls its fingers; the wand turns slowly in the fingers.
	fidget_cd -= delta
	fidget_t = maxf(0.0, fidget_t - delta * 0.9)
	if fidget_cd <= 0.0:
		fidget_cd = randf_range(4.0, 9.0)
		fidget_t = 1.0
		fidget_hand = randi() % 2
	if wand:
		wand.rotation.z = sin(t * 0.7) * 0.25
	clash_t = maxf(0.0, clash_t - delta * 3.0)
	fumble_t = maxf(0.0, fumble_t - delta * 2.2)
	var pfx_r := _parry_fx(1.0)
	var pfx_l := _parry_fx(-1.0)
	right_hand.position = R_REST + bob + flinch + guard_r + go_r[0] + pfx_r[0]
	left_hand.position = L_REST + bob * 0.8 + flinch + guard_l + go_l[0] + pfx_l[0]
	var base_rot := R_ROT
	if walker and holding:
		base_rot = HOLD_ROT
		right_hand.position += HOLD_POS - R_REST
	var kk := 1.0 - exp(-delta * 14.0)
	# Sword swing: each blade's own choreography (SWINGS), with a glowing trail off the tip.
	swing = maxf(0.0, swing - delta * swing_rate)
	if trail:
		trail.emitting = swing > 0.08 and swing < 0.85
	var roll := 0.0
	if swing > 0.0:
		var k := 1.0 - swing
		var off := _swing_pose(k)
		var m := swing_mirror
		right_hand.position += Vector3(off[0].x * m, off[0].y, off[0].z)
		var r: Vector3 = off[1]
		right_hand.rotation = base_rot + Vector3(r.x, r.y * m, r.z * m)
		var st: Dictionary = SWINGS.get(swing_style, SWINGS["diagonal"])
		if st.get("spin", false) and k < 0.35:
			right_hand.rotation.z += TAU * (k / 0.35)
		roll = float(st.get("roll", 0.0)) * sin(PI * k) * m
	cam.rotation.z = lerpf(cam.rotation.z, roll + (_dodge_roll() if walker else 0.0), 1.0 - exp(-delta * 18.0))
	if is_instance_valid(weapon_orbit):
		weapon_orbit.rotation.z += delta * 4.0
	if arena_blade_t > 0.0:
		arena_blade_t -= delta
		if arena_blade_t <= 0.0 and not walker:
			set_weapon(null)
	if swing <= 0.0:
		var tr: Vector3 = base_rot + go_r[1] + (guard_rot if not (walker and holding) else Vector3.ZERO)
		right_hand.rotation = right_hand.rotation.lerp(tr, kk) + pfx_r[1] * 0.3
	left_hand.rotation = left_hand.rotation.lerp(L_ROT + go_l[1] + guard_rot, kk) + pfx_l[1] * 0.3
	# The palm glow swells as the spell is shaped and fades as it leaves the hand.
	for hi in 2:
		var pg: Array = palm_glows[hi]
		var amt := sin(PI * gp) if _gesture_hand(hi) else 0.0
		(pg[0] as MeshInstance3D).visible = amt > 0.03
		(pg[0] as MeshInstance3D).scale = Vector3.ONE * (0.6 + amt)
		var gm: StandardMaterial3D = pg[3]
		gm.albedo_color = Color(gesture_col.r, gesture_col.g, gesture_col.b, 0.85)
		gm.emission = gesture_col
		(pg[1] as OmniLight3D).light_color = gesture_col
		(pg[1] as OmniLight3D).light_energy = amt * 2.2

	var id := selected_id()
	var col: Color = GameState.SKILLS[id]["color"] if id != "" else Color.WHITE
	var ready := id != "" and cooldown_left(id) <= 0.0
	var pulse := 0.8 + sin(t * 6.0) * 0.2
	orb_mat.albedo_color = col
	orb_mat.emission = col
	orb_mat.emission_energy_multiplier = (1.4 if ready else 0.4) * pulse
	claw_mat.emission = col
	claw_mat.emission_energy_multiplier = (1.2 if ready else 0.2) * pulse
	_pose_hands(delta)
	orb_light.light_color = col
	orb_light.light_energy = (0.8 if ready else 0.25) * pulse
	gem_mat.albedo_color = col
	gem_mat.emission = col
	skin_mat.emission = (Color(0.3, 0.0, 0.1).lerp(Color(1.0, 0.85, 0.6), purity)).lerp(col, 0.2)


## Daytime: walk the streets of Vael. The overworld resolves collisions.
func _walk(delta: float) -> void:
	dodge_t = maxf(0.0, dodge_t - delta)
	dodge_cd = maxf(0.0, dodge_cd - delta)
	slide_t = maxf(0.0, slide_t - delta)
	coyote = maxf(0.0, coyote - delta)
	land_dip = move_toward(land_dip, 0.0, delta * 1.5)
	# Climbing a ledge: a short lift and pull, then you stand on it.
	if mantle_t > 0.0:
		mantle_t -= delta
		var s := clampf(1.0 - mantle_t / 0.38, 0.0, 1.0)
		var up := _ease(clampf(s * 1.6, 0.0, 1.0))
		var over := _ease(clampf((s - 0.45) / 0.55, 0.0, 1.0))
		position = Vector3(lerpf(mantle_from.x, mantle_to.x, over), lerpf(mantle_from.y, mantle_to.y, up), lerpf(mantle_from.z, mantle_to.z, over))
		head.position.y = eye - 0.25 * sin(PI * s)
		if mantle_t <= 0.0:
			on_ground = true
			vy = 0.0
		return
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var want := (fwd * move_input.y + right * move_input.x)
	if want.length() > 1.0:
		want = want.normalized()
	var flat := Vector2(vel.x, vel.z).length()
	# Sprint costs stamina; crouching slows you; crouch while sprinting to slide.
	var sprinting := sprint and stamina > 1.0 and want.length() > 0.1 and not crouch
	if crouch and sprint and on_ground and slide_t <= 0.0 and flat > 6.0 and stamina >= 12.0:
		slide_t = 0.7
		slide_dir = Vector3(vel.x, 0, vel.z).normalized()
		stamina -= 12.0
		Sfx.play("slide", -4.0)
	if sprinting:
		stamina = maxf(0.0, stamina - 14.0 * delta)
	elif dodge_t <= 0.0:
		stamina = minf(100.0, stamina + (30.0 if on_ground else 10.0) * delta)
	var spd := 8.5 if sprinting else (2.6 if crouch else 5.0)
	if slide_t > 0.0:
		vel = slide_dir * lerpf(3.0, 10.0, slide_t / 0.7)
	elif dodge_t > 0.0:
		vel = dodge_dir * 11.0 * (0.4 + 0.6 * dodge_t / 0.34)
	else:
		vel = vel.lerp(want * spd, 1.0 - exp(-delta * (10.0 if on_ground else 2.5)))
	# Vertical: gravity, ground under you (you can stand on low props), landing.
	var ground: float = ow.ground_at(position, 0.3) if ow else 0.0
	# Wading: the shallows pull you down and slow you, every step a splash.
	var wade: float = ow.water_depth_at(position) if ow else 0.0
	if wade > 0.0 and ground <= 0.01:
		ground = -minf(wade, 0.75)
		vel *= 1.0 - minf(0.6, wade) * delta * 4.0
	vy -= 20.0 * delta
	position.y += vy * delta
	if position.y <= ground:
		if not on_ground and vy < -5.0:
			land_dip = clampf(-vy * 0.02, 0.05, 0.25)
			Sfx.play("land", -4.0)
			shake(clampf(-vy * 0.02, 0.0, 0.3))
		position.y = ground
		vy = 0.0
		if not on_ground:
			on_ground = true
	elif on_ground and position.y - ground > 0.05:
		on_ground = false
		coyote = 0.12
	# Holding jump against a ledge in mid-air climbs it.
	if jump_held and not on_ground and vy < 2.0 and want.length() > 0.1:
		if _try_mantle():
			return
	var np := position + vel * delta
	if ow:
		np = ow.resolve(position, np, 0.4, position.y)
	position = Vector3(np.x, position.y, np.z)
	var moving := Vector2(vel.x, vel.z).length()
	if on_ground:
		walk_t += delta * moving * 2.2
		step_t += delta * moving
		if step_t > (2.4 if sprinting else 1.9) and slide_t <= 0.0:
			step_t = 0.0
			if ow and ow.water_depth_at(position) > 0.0:
				Sfx.play("splash", -10.0, randf_range(0.8, 1.2))
			else:
				Sfx.play("step", -16.0 if crouch else -11.0, randf_range(0.85, 1.1))
	var low := crouch or slide_t > 0.0
	eye = lerpf(eye, 1.0 if low else 1.65, 1.0 - exp(-delta * 12.0))
	head.position.y = eye - land_dip + absf(sin(walk_t)) * 0.05 * minf(1.0, moving / 5.0) * (1.0 if on_ground else 0.0)
	if sprinting:
		cam.fov = lerpf(cam.fov, 78.0, 1.0 - exp(-delta * 6.0))
	else:
		cam.fov = lerpf(cam.fov, 70.0, 1.0 - exp(-delta * 6.0))


# --- Blades ------------------------------------------------------------------

## Interpolated hand offset and rotation for the current swing at progress k (0..1).
func _swing_pose(k: float) -> Array:
	var keys: Array = SWINGS.get(swing_style, SWINGS["diagonal"])["keys"]
	for i in keys.size() - 1:
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if k <= b[0]:
			var s := _ease(clampf((k - a[0]) / maxf(0.001, b[0] - a[0]), 0.0, 1.0))
			return [(a[1] as Vector3).lerp(b[1], s), (a[2] as Vector3).lerp(b[2], s)]
	return [Vector3.ZERO, Vector3.ZERO]


## Put a blade in the right hand (or take it away with null). Finds its tip for the trail.
func set_weapon(node: Node3D, col: Color = Color.WHITE) -> void:
	if is_instance_valid(weapon_node):
		weapon_node.queue_free()
	weapon_node = node
	weapon_tip = null
	weapon_orbit = null
	trail = null
	holding = node != null
	if node == null:
		return
	right_hand.add_child(node)
	weapon_tip = node.get_node_or_null("Tip")
	weapon_orbit = node.get_node_or_null("Orbit")
	if weapon_tip:
		trail = Fx.particles(col, 40, 0.22, 0.05, 0.03)
		trail.gravity = Vector3.ZERO
		trail.spread = 5.0
		trail.emitting = false
		(trail.mesh as BoxMesh).material = Fx.mat(col, 5.0, 0.8)
		weapon_tip.add_child(trail)


## Start a swing in the style of this blade. duration in seconds.
func start_swing(style: String, duration: float) -> void:
	swing_style = style
	swing_rate = 1.0 / clampf(duration, 0.25, 1.2)
	swing = 1.0
	swing_count += 1
	var st: Dictionary = SWINGS.get(style, SWINGS["diagonal"])
	swing_mirror = -1.0 if st.get("mirror", false) and swing_count % 2 == 0 else 1.0


## The arena: the tyrant's blade appears in his hand for one cut, then fades.
func swing_blade(id: String) -> void:
	var W: Dictionary = Dialogue.WEAPONS.get(id, Dialogue.WEAPONS["shortsword"])
	if not is_instance_valid(weapon_node):
		var n := Swords.build(id, 0.42 + float(W["reach"]) * 0.06, GameState.weapon_tune)
		n.position = Vector3(0.0, -0.03, -0.085)
		n.rotation = Vector3(0, PI / 2.0 - 0.3, 0)
		set_weapon(n, W["color"])
		game.spawn_burst(hand_tip(), W["color"], 14)
	var dur := clampf(int(W["ticks"]) * GameState.TICK * 0.9, 0.35, 1.0)
	start_swing(Swords.swing_style(id), dur)
	arena_blade_t = dur + 0.25


# --- Traversal (walker) ---------------------------------------------------------

func try_jump() -> void:
	if mantle_t > 0.0 or slide_t > 0.0:
		return
	if (on_ground or coyote > 0.0) and stamina >= 8.0:
		vy = 7.0
		on_ground = false
		coyote = 0.0
		stamina -= 8.0
		Sfx.play("jump", -6.0)
		return
	_try_mantle()


func try_dodge() -> void:
	if dodge_cd > 0.0 or stamina < 25.0 or mantle_t > 0.0:
		return
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var d := fwd * move_input.y + right * move_input.x
	if d.length() < 0.1:
		d = -fwd
	dodge_dir = d.normalized()
	dodge_side = -1.0 if move_input.x < -0.1 else 1.0
	dodge_t = 0.34
	dodge_cd = 0.7
	stamina -= 25.0
	Sfx.play("roll", -4.0)


func is_dodging() -> bool:
	return dodge_t > 0.12


func _dodge_roll() -> float:
	if dodge_t <= 0.0:
		return 0.0
	return sin(PI * (1.0 - dodge_t / 0.34)) * 0.35 * dodge_side


## Climb onto a ledge in front of you (crates, stalls, low walls, the fountain rim).
func _try_mantle() -> bool:
	if ow == null:
		return false
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var top: float = ow.ledge_top(position, fwd)
	if top < 0.0:
		return false
	mantle_from = position
	mantle_to = Vector3(position.x + fwd.x * 0.8, top, position.z + fwd.z * 0.8)
	mantle_t = 0.38
	vy = 0.0
	stamina -= 6.0
	Sfx.play("land", -6.0, 1.3)
	return true


func _ease(a: float) -> float:
	return a * a * (3.0 - 2.0 * a)
