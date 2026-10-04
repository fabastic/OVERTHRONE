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
var holding := false   # walker: a blade in the right hand (the fingers close around its grip)
var swing := 0.0       # walker: 1 -> 0 over a sword swing (a diagonal slash across the view)
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
	return h


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
	for parts in hand_parts:
		# Corrupt fingers are long and thin (up to +35% length), with long black claws and swollen knuckles.
		for sd in parts["segdata"]:
			var L: float = float(sd[2]) * (1.0 + 0.35 * c)
			var ww: float = float(sd[4]) * (1.0 - 0.15 * c)
			var box: MeshInstance3D = sd[1]
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
	if walker:
		yaw = wrapf(yaw - relative.x * SENSITIVITY, -PI, PI)
		pitch = clampf(pitch - relative.y * SENSITIVITY, -1.2, 1.1)
		return
	yaw = clampf(yaw - relative.x * SENSITIVITY, -YAW_LIMIT, YAW_LIMIT)
	pitch = clampf(pitch - relative.y * SENSITIVITY, PITCH_MIN, PITCH_MAX)


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
	queued_parry = false
	if queued_cast != "" and gcd <= 0:
		var id := queued_cast
		queued_cast = ""
		if cooldowns.get(id, 0) <= 0:
			_cast_now(id)


## End of a tick: everything counts down by one.
func on_tick_end() -> void:
	parry_t = maxf(0.0, parry_t - 1)
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
	shake(0.25)


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
	right_hand.position = R_REST + bob + flinch + guard_r + go_r[0]
	left_hand.position = L_REST + bob * 0.8 + flinch + guard_l + go_l[0]
	var base_rot := R_ROT
	if walker and holding:
		base_rot = HOLD_ROT
		right_hand.position += HOLD_POS - R_REST
	var kk := 1.0 - exp(-delta * 14.0)
	# Sword swing: wind up high and to the right (blade cocked back over the shoulder), then cut
	# down and across to the left, the wrist rolling over as the blade passes.
	swing = maxf(0.0, swing - delta * 5.0)
	if swing > 0.0:
		var k := 1.0 - swing
		var e := _ease(clampf((k - 0.15) / 0.7, 0.0, 1.0))
		var lift := (1.0 - e) * clampf(k / 0.15, 0.0, 1.0)
		right_hand.position += Vector3(lerpf(0.1, -0.4, e), lerpf(0.2, -0.14, e) + lift * 0.05, -0.2 * sin(PI * e))
		right_hand.rotation = base_rot + Vector3(lerpf(0.7, -0.9, e), lerpf(0.3, -0.3, e), lerpf(-0.3, 0.9, e))
	else:
		var tr: Vector3 = base_rot + go_r[1] + (guard_rot if not (walker and holding) else Vector3.ZERO)
		right_hand.rotation = right_hand.rotation.lerp(tr, kk)
	left_hand.rotation = left_hand.rotation.lerp(L_ROT + go_l[1] + guard_rot, kk)
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
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var want := (fwd * move_input.y + right * move_input.x)
	if want.length() > 1.0:
		want = want.normalized()
	var spd := 8.0 if sprint else 5.0
	vel = vel.lerp(want * spd, 1.0 - exp(-delta * 10.0))
	var np := position + vel * delta
	if ow:
		np = ow.resolve(position, np, 0.4)
	position = np
	var moving := Vector2(vel.x, vel.z).length()
	walk_t += delta * moving * 2.2
	head.position.y = 1.65 + absf(sin(walk_t)) * 0.05 * minf(1.0, moving / 5.0)


func _ease(a: float) -> float:
	return a * a * (3.0 - 2.0 * a)
