extends Node3D
## A person of Vael. Box-built and pixelated like everything else, but they react to you:
##   FEAR  (you are still the Hollow King): they back away, hunch, raise their hands.
##   WARY  : they watch you, and turn to face you.
##   SAINT : they bow, then kneel as you pass.
## Named NPCs (npc_id set) can be talked to with E; townsfolk just mutter as you pass.
## Townsfolk wander between waypoints.

const Fx := preload("res://scripts/fx.gd")
const Dialogue := preload("res://scripts/dialogue.gd")

const MUTTER := [
	["Don't look at him.", "Get inside. Now.", "Saints, it's HIM.", "Hide the children.", "Please, not today."],
	["That's the King.", "He paid Marta, I heard.", "Keep walking.", "He looks... tired.", "Is it true he helped the Watch?"],
	["Bless you, my lord!", "The saint walks among us!", "Did you see? He smiled!", "Light keep you, lord.", "Thank you, for everything."],
]

var npc_id := ""
var display_name := ""
var cloth := Color(0.5, 0.4, 0.3)
var accent := Color(0.7, 0.6, 0.4)
var small := false
var ow  # the overworld
var waypoints: Array = []
var wp := 0
var home := Vector3.ZERO
var t := 0.0
var talk_t := 0.0
var mutter_cd := 0.0
var rig: Node3D
var torso: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var name_label: Label3D
var kneel := 0.0
var cower := 0.0


func _ready() -> void:
	t = randf() * 10.0
	home = position
	if small:
		scale = Vector3.ONE * 0.7
	_build()
	if npc_id != "":
		name_label = Label3D.new()
		name_label.text = display_name
		name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		name_label.fixed_size = true
		name_label.pixel_size = 0.0012
		name_label.font_size = 32
		name_label.outline_size = 8
		name_label.modulate = Color(1.0, 0.85, 0.5)
		name_label.position = Vector3(0, 2.15, 0)
		name_label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		name_label.visible = false
		add_child(name_label)


func _build() -> void:
	rig = Node3D.new()
	add_child(rig)
	var skin := Fx.mat(Color(0.85, 0.66, 0.5).darkened(randf() * 0.4))
	var cl := Fx.mat(cloth)
	var ac := Fx.mat(accent)
	var dark := Fx.mat(cloth.darkened(0.5))
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.1, 0.8, 0)
		rig.add_child(leg)
		leg.add_child(Fx.box(Vector3(0.14, 0.72, 0.16), dark, Vector3(0, -0.38, 0)))
		leg.add_child(Fx.box(Vector3(0.15, 0.1, 0.22), Fx.mat(Color(0.2, 0.14, 0.1)), Vector3(0, -0.76, -0.03)))
		if side < 0.0:
			leg_l = leg
		else:
			leg_r = leg
	torso = Node3D.new()
	torso.position = Vector3(0, 0.8, 0)
	rig.add_child(torso)
	torso.add_child(Fx.box(Vector3(0.42, 0.55, 0.26), cl, Vector3(0, 0.28, 0)))
	torso.add_child(Fx.box(Vector3(0.44, 0.08, 0.28), ac, Vector3(0, 0.05, 0)))
	torso.add_child(Fx.box(Vector3(0.46, 0.3, 0.3), cl, Vector3(0, -0.1, 0)))
	# A little tech: a glowing brooch / lens on most citizens of Vael
	torso.add_child(Fx.box(Vector3(0.05, 0.05, 0.02), Fx.mat(accent.lightened(0.3), 3.0), Vector3(0.1, 0.42, -0.14)))
	head = Node3D.new()
	head.position = Vector3(0, 0.6, 0)
	torso.add_child(head)
	head.add_child(Fx.box(Vector3(0.22, 0.24, 0.22), skin, Vector3(0, 0.12, 0)))
	head.add_child(Fx.box(Vector3(0.24, 0.07, 0.24), Fx.mat(Color(0.25, 0.15, 0.08).lightened(randf() * 0.5)), Vector3(0, 0.26, 0.01)))
	for s in [-1.0, 1.0]:
		head.add_child(Fx.box(Vector3(0.03, 0.03, 0.01), Fx.mat(Color(0.1, 0.08, 0.08)), Vector3(s * 0.05, 0.14, -0.112)))
	for side in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(side * 0.27, 0.52, 0)
		torso.add_child(arm)
		arm.add_child(Fx.box(Vector3(0.11, 0.5, 0.12), cl, Vector3(0, -0.24, 0)))
		arm.add_child(Fx.box(Vector3(0.09, 0.09, 0.09), skin, Vector3(0, -0.53, 0)))
		if side < 0.0:
			arm_l = arm
		else:
			arm_r = arm


func talk() -> void:
	talk_t = 0.6


func _process(delta: float) -> void:
	t += delta
	talk_t = maxf(0.0, talk_t - delta)
	mutter_cd = maxf(0.0, mutter_cd - delta)
	if ow == null or ow.walker == null:
		return
	var pp: Vector3 = ow.walker.position
	var to := Vector3(pp.x - position.x, 0, pp.z - position.z)
	var d := to.length()
	var tone := Dialogue.tone()
	var moving := false
	var want_kneel := 0.0
	var want_cower := 0.0
	if name_label:
		name_label.visible = d < 7.0
	if d < 6.0:
		# React to the King.
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-delta * 6.0))
		if tone == 0:
			want_cower = 1.0
			if d < 3.5 and npc_id == "":
				var away := -to.normalized()
				position = ow.resolve(position, position + away * 1.8 * delta, 0.3)
				moving = true
		elif tone == 2 and d < 4.0:
			want_kneel = 1.0
		if npc_id == "" and d < 4.5 and mutter_cd <= 0.0:
			mutter_cd = 9.0 + randf() * 6.0
			ow.say(self, MUTTER[tone].pick_random())
	elif not waypoints.is_empty():
		var target: Vector3 = waypoints[wp]
		var dir := Vector3(target.x - position.x, 0, target.z - position.z)
		if dir.length() < 0.5:
			wp = (wp + 1) % waypoints.size()
		else:
			var v := dir.normalized() * 1.3
			position = ow.resolve(position, position + v * delta, 0.3)
			rotation.y = lerp_angle(rotation.y, atan2(-v.x, -v.z), 1.0 - exp(-delta * 5.0))
			moving = true
	kneel = move_toward(kneel, want_kneel, delta * 2.5)
	cower = move_toward(cower, want_cower, delta * 3.0)
	var stride := sin(t * 9.0) if moving else 0.0
	leg_l.rotation.x = stride * 0.6 - kneel * 1.4
	leg_r.rotation.x = -stride * 0.6 + kneel * 0.2
	rig.position.y = -kneel * 0.38 + absf(stride) * 0.03
	torso.rotation.x = kneel * 0.35 + cower * 0.3
	head.rotation.x = kneel * 0.4 - cower * 0.1 + (sin(t * 14.0) * 0.12 if talk_t > 0.0 else 0.0)
	# Fear: hands raised before the face, trembling. Saint: hands clasped. Otherwise they swing.
	var tremble := sin(t * 30.0) * 0.06 * cower
	arm_l.rotation.x = lerpf(-stride * 0.5, 2.0, cower) + tremble + kneel * 0.9
	arm_r.rotation.x = lerpf(stride * 0.5, 2.0, cower) - tremble + kneel * 0.9
	arm_l.rotation.z = -0.4 * cower - 0.3 * kneel
	arm_r.rotation.z = 0.4 * cower + 0.3 * kneel
	torso.position.y = 0.8 + sin(t * 2.0) * 0.008
