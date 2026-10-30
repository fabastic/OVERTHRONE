extends Node3D
## The Stranger: a man in white who is always where you end up. He is you, the pure part of you,
## carrying the rot away. As your hands purify, his corrupt (GameState.stranger_corruption):
## his robe greys then blackens, his hands darken and sprout thorns, red light grows under his hood
## and an iron shackle closes on his wrist. After the night-5 reveal (GameState.revealed) the hood is
## down and you see the face you had before the crown.
## Used walking up to you at dusk (overworld.gd) and seated across the board at the Hollow Flagon (board.gd).

const Fx := preload("res://scripts/fx.gd")
const PixTex := preload("res://scripts/pixtex.gd")
const Vox := preload("res://scripts/vox.gd")

var seated := false
var walking := false
var t := 0.0
var corruption := 0.0
var rig: Node3D
var torso: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var robe_mat: StandardMaterial3D
var trim_mat: StandardMaterial3D
var skin_mat: StandardMaterial3D
var vein_mat: StandardMaterial3D
var eye_mat: StandardMaterial3D
var hood: Node3D
var face: Node3D
var thorns: Array[Node3D] = []
var shackles: Array[Node3D] = []
var glow: OmniLight3D
var vox_variant := -1


func _ready() -> void:
	t = randf() * 5.0
	# Pixel cloth and skin in neutral greys, tinted by refresh(): the rot shows in the colour
	robe_mat = PixTex.mat(PixTex.cloth(Color(0.95, 0.95, 0.95), 91), 0.4, false)
	trim_mat = Fx.mat(Color(0.85, 0.7, 0.35), 0.4)
	skin_mat = PixTex.mat(PixTex.grain(Color(0.95, 0.95, 0.95), 92), 0.3, false)
	vein_mat = Fx.mat(Color(1.0, 0.1, 0.15), 2.5)
	eye_mat = Fx.mat(Color(1.0, 0.85, 0.5), 5.0)
	_build()
	refresh()


func _build() -> void:
	rig = Node3D.new()
	add_child(rig)
	var dark := Fx.mat(Color(0.08, 0.06, 0.08))
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.11, 0.84, 0)
		rig.add_child(leg)
		leg.add_child(Fx.box(Vector3(0.16, 0.8, 0.18), robe_mat, Vector3(0, -0.4, 0)))
		leg.add_child(Fx.box(Vector3(0.16, 0.08, 0.24), dark, Vector3(0, -0.8, -0.03)))
		if side < 0.0:
			leg_l = leg
		else:
			leg_r = leg
	torso = Node3D.new()
	torso.position = Vector3(0, 0.84, 0)
	rig.add_child(torso)
	# A long robe falling past the knees, a sash, a trim down the front.
	torso.add_child(Fx.box(Vector3(0.5, 0.7, 0.32), robe_mat, Vector3(0, 0.3, 0)))
	torso.add_child(Fx.box(Vector3(0.54, 0.62, 0.36), robe_mat, Vector3(0, -0.25, 0)))
	torso.add_child(Fx.box(Vector3(0.06, 1.1, 0.02), trim_mat, Vector3(0, 0.05, -0.19)))
	torso.add_child(Fx.box(Vector3(0.52, 0.07, 0.34), trim_mat, Vector3(0, 0.02, 0)))
	head = Node3D.new()
	head.position = Vector3(0, 0.66, 0)
	torso.add_child(head)
	# The face beneath: your younger face (seen once the hood is down).
	face = Node3D.new()
	head.add_child(face)
	face.add_child(Fx.box(Vector3(0.22, 0.25, 0.22), skin_mat, Vector3(0, 0.13, 0)))
	face.add_child(Fx.box(Vector3(0.25, 0.09, 0.25), Fx.mat(Color(0.3, 0.2, 0.12)), Vector3(0, 0.28, 0.01)))
	face.add_child(Fx.box(Vector3(0.25, 0.18, 0.06), Fx.mat(Color(0.3, 0.2, 0.12)), Vector3(0, 0.2, 0.11)))
	for s in [-1.0, 1.0]:
		face.add_child(Fx.box(Vector3(0.035, 0.03, 0.01), eye_mat, Vector3(s * 0.05, 0.15, -0.112)))
	# The hood: a deep cowl and a shadowed opening with two eyes in it.
	hood = Node3D.new()
	head.add_child(hood)
	hood.add_child(Fx.box(Vector3(0.34, 0.36, 0.32), robe_mat, Vector3(0, 0.17, 0.03)))
	hood.add_child(Fx.box(Vector3(0.24, 0.26, 0.04), Fx.mat(Color(0.02, 0.01, 0.03)), Vector3(0, 0.13, -0.135)))
	hood.add_child(Fx.box(Vector3(0.2, 0.12, 0.12), robe_mat, Vector3(0, 0.37, 0.1)))
	for s in [-1.0, 1.0]:
		hood.add_child(Fx.box(Vector3(0.04, 0.025, 0.01), eye_mat, Vector3(s * 0.05, 0.15, -0.16)))
	# Arms in long sleeves, hands bare. Thorns and a shackle grow on them as he takes your rot.
	for side in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(side * 0.3, 0.56, 0)
		torso.add_child(arm)
		arm.add_child(Fx.box(Vector3(0.15, 0.5, 0.16), robe_mat, Vector3(0, -0.24, 0)))
		arm.add_child(Fx.box(Vector3(0.18, 0.1, 0.19), robe_mat, Vector3(0, -0.47, 0)))
		arm.add_child(Fx.box(Vector3(0.1, 0.14, 0.1), skin_mat, Vector3(0, -0.6, 0)))
		arm.add_child(Fx.box(Vector3(0.012, 0.1, 0.01), vein_mat, Vector3(side * 0.02, -0.58, -0.052)))
		for k in 3:
			var th := Fx.cylinder(0.0, 0.014, 0.06, Fx.mat(Color(0.05, 0.02, 0.05)), Vector3(side * 0.05, -0.56 - k * 0.04, 0.0))
			th.rotation.z = -side * 0.9
			arm.add_child(th)
			thorns.append(th)
		var sh := Fx.box(Vector3(0.14, 0.06, 0.14), Fx.mat(Color(0.22, 0.2, 0.24)), Vector3(0, -0.52, 0))
		arm.add_child(sh)
		shackles.append(sh)
		if side < 0.0:
			arm_l = arm
		else:
			arm_r = arm
	glow = OmniLight3D.new()
	glow.omni_range = 3.0
	glow.position = Vector3(0, 1.8, -0.4)
	add_child(glow)


## The voxel Stranger (Blender): three versions, white, grey and black, chosen by corruption.
func _apply_vox() -> void:
	var v := clampi(roundi(GameState.stranger_corruption() * 2.0), 0, 2)
	if v == vox_variant:
		return
	vox_variant = v
	var keep: Array = []
	keep.append_array(thorns)
	keep.append_array(shackles)
	Vox.voxify("stranger_%d" % v, {"leg_l": leg_l, "leg_r": leg_r, "torso": torso, "arm_l": arm_l, "arm_r": arm_r,
		"face": face, "hood": hood}, keep)


## Where the face is, for the conversation portrait.
func portrait_height() -> float:
	return 1.68


## Re-read the run state: how much rot he carries, and whether you know who he is.
func refresh() -> void:
	corruption = GameState.stranger_corruption()
	_apply_vox()
	var c := corruption
	var robe := Color(0.94, 0.93, 0.9).lerp(Color(0.5, 0.48, 0.5), clampf(c * 1.6, 0.0, 1.0))
	robe = robe.lerp(Color(0.07, 0.05, 0.09), clampf(c * 1.6 - 0.6, 0.0, 1.0))
	robe_mat.albedo_color = robe
	trim_mat.albedo_color = Color(0.85, 0.7, 0.35).lerp(Color(0.5, 0.08, 0.1), c)
	trim_mat.emission = trim_mat.albedo_color
	skin_mat.albedo_color = Color(0.86, 0.72, 0.6).lerp(Color(0.16, 0.08, 0.2), c)
	vein_mat.albedo_color = Color(1.0, 0.1, 0.15)
	vein_mat.emission_energy_multiplier = 0.0 if c < 0.2 else 1.0 + 2.5 * c
	var eye := Color(1.0, 0.85, 0.5).lerp(Color(1.0, 0.15, 0.1), c)
	eye_mat.albedo_color = eye
	eye_mat.emission = eye
	eye_mat.emission_energy_multiplier = 3.0 + 4.0 * c
	var keep := roundi(c * thorns.size())
	for k in thorns.size():
		thorns[k].visible = k < keep
	for s in shackles:
		s.visible = c >= 0.5
	glow.light_color = eye
	glow.light_energy = 0.3 + 0.9 * c
	hood.visible = not GameState.revealed
	face.visible = GameState.revealed


func _process(delta: float) -> void:
	t += delta
	var stride := sin(t * 8.0) if walking else 0.0
	if seated:
		leg_l.rotation.x = 1.45
		leg_r.rotation.x = 1.45
		rig.position.y = -0.4
		torso.rotation.x = 0.18 + sin(t * 1.3) * 0.02
		# Hands forward, resting on the table, the left one shuffling the pieces now and then.
		arm_l.rotation.x = 1.25 + sin(t * 2.3) * 0.08 * maxf(0.0, sin(t * 0.4))
		arm_r.rotation.x = 1.2
		head.rotation.x = 0.25 + sin(t * 0.7) * 0.05
		return
	leg_l.rotation.x = stride * 0.6
	leg_r.rotation.x = -stride * 0.6
	rig.position.y = absf(stride) * 0.03
	torso.rotation.x = 0.0
	arm_l.rotation.x = -stride * 0.4
	arm_r.rotation.x = stride * 0.4
	head.rotation.x = sin(t * 0.9) * 0.04
