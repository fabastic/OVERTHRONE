extends Node3D
## A person of Vael. Box-built and pixelated like everything else, but they react to you:
##   FEAR  (you are still the Hollow King): they back away, hunch, raise their hands.
##   WARY  : they watch you, and turn to face you.
##   SAINT : they bow, then kneel as you pass.
## Named NPCs (npc_id set) can be talked to with E; townsfolk just mutter as you pass.
## Townsfolk wander between waypoints.
## Built like the folk of a pixel dungeon crawler: a big block head with a painted pixel face, a
## chunky body in pixel cloth, and an outfit of their own (OUTFITS); townsfolk roll a random one.

const Fx := preload("res://scripts/fx.gd")
const Dialogue := preload("res://scripts/dialogue.gd")
const PixTex := preload("res://scripts/pixtex.gd")

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
		name_label.position = Vector3(0, 1.95, 0)
		name_label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		name_label.visible = false
		add_child(name_label)


# What each named person wears: hat, face style, apron, extras. Townsfolk roll their own.
const OUTFITS := {
	"marta": {"hat": "kerchief", "hat_col": Color(0.95, 0.92, 0.85), "apron": Color(0.95, 0.93, 0.88), "hair": Color(0.45, 0.25, 0.12)},
	"hennik": {"face": "beard", "hair": Color(0.6, 0.58, 0.55), "bald": true, "apron": Color(0.3, 0.2, 0.12), "bulk": 1.15},
	"ivy": {"hat": "wimple", "hat_col": Color(0.08, 0.08, 0.1), "hair": Color(0.2, 0.15, 0.1), "robe": true},
	"pip": {"hat": "cap", "hat_col": Color(0.35, 0.28, 0.2), "hair": Color(0.65, 0.45, 0.2), "face": "stubble_kid"},
	"rolan": {"hat": "helm", "face": "stubble", "plate": true, "hair": Color(0.25, 0.18, 0.12)},
	"greta": {"hat": "bandana", "hat_col": Color(0.7, 0.18, 0.15), "apron": Color(0.55, 0.4, 0.25), "hair": Color(0.7, 0.3, 0.12)},
	"liore": {"hat": "tophat", "hat_col": Color(0.2, 0.18, 0.22), "face": "goggles", "hair": Color(0.85, 0.85, 0.9)},
	"oswin": {"hat": "feather", "hat_col": Color(0.6, 0.15, 0.25), "face": "stubble", "lute": true, "hair": Color(0.85, 0.6, 0.25)},
	"ansel": {"hat": "veil", "hat_col": Color(0.08, 0.08, 0.1), "face": "veil", "robe": true, "hair": Color(0.3, 0.3, 0.32)},
	"toms": {"face": "beard", "apron": Color(0.85, 0.8, 0.7), "hair": Color(0.35, 0.22, 0.12), "bulk": 1.12},
	"edda": {"hat": "shawl", "hat_col": Color(0.4, 0.3, 0.5), "hair": Color(0.88, 0.88, 0.9), "robe": true},
}


func _cloth_mat(c: Color) -> StandardMaterial3D:
	return PixTex.mat(PixTex.cloth(c, int(c.r * 97 + c.g * 31)), 0.45, false)


func _build() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash(npc_id) if npc_id != "" else randi()
	var o: Dictionary = OUTFITS.get(npc_id, {})
	if o.is_empty():
		# A citizen of Vael: random hair, face, hat
		o = {"hair": [Color(0.3, 0.18, 0.08), Color(0.12, 0.1, 0.08), Color(0.75, 0.55, 0.25), Color(0.55, 0.3, 0.12), Color(0.6, 0.6, 0.62)][r.randi() % 5],
			"face": ["", "", "stubble", "beard"][r.randi() % 4],
			"hat": ["", "", "cap", "hood", "straw", "kerchief"][r.randi() % 6],
			"hat_col": [Color(0.4, 0.3, 0.2), Color(0.3, 0.35, 0.25), Color(0.75, 0.65, 0.35), Color(0.5, 0.2, 0.2)][r.randi() % 4]}
		if r.randf() < 0.3:
			o["apron"] = Color(0.8, 0.75, 0.62)
	var bulk: float = o.get("bulk", 1.0)
	var skin_col := [Color(0.92, 0.72, 0.56), Color(0.8, 0.58, 0.42), Color(0.6, 0.42, 0.3), Color(0.98, 0.8, 0.66)][r.randi() % 4] as Color
	var hair: Color = o.get("hair", Color(0.3, 0.2, 0.1))
	rig = Node3D.new()
	add_child(rig)
	var skin := PixTex.mat(PixTex.grain(skin_col, 3), 0.4, false)
	var cl := _cloth_mat(cloth)
	var ac := _cloth_mat(accent)
	var dark := _cloth_mat(cloth.darkened(0.45))
	var boot := PixTex.mat(PixTex.grain(Color(0.25, 0.16, 0.1), 4), 0.4, false)
	# Legs: short and chunky, with boots
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.11, 0.62, 0)
		rig.add_child(leg)
		leg.add_child(Fx.box(Vector3(0.16, 0.5, 0.18), dark, Vector3(0, -0.26, 0)))
		leg.add_child(Fx.box(Vector3(0.18, 0.14, 0.24), boot, Vector3(0, -0.56, -0.03)))
		if side < 0.0:
			leg_l = leg
		else:
			leg_r = leg
	torso = Node3D.new()
	torso.position = Vector3(0, 0.62, 0)
	rig.add_child(torso)
	var w := 0.46 * bulk
	torso.add_child(Fx.box(Vector3(w, 0.56, 0.28 * bulk), cl, Vector3(0, 0.28, 0)))
	if o.get("robe", false):
		torso.add_child(Fx.box(Vector3(w + 0.06, 0.62, 0.34 * bulk), cl, Vector3(0, -0.22, 0)))  # a robe to the ankles
	else:
		torso.add_child(Fx.box(Vector3(w + 0.02, 0.22, 0.3 * bulk), dark, Vector3(0, -0.05, 0)))
	# Belt with a buckle
	torso.add_child(Fx.box(Vector3(w + 0.03, 0.06, 0.3 * bulk + 0.02), PixTex.mat(PixTex.grain(Color(0.3, 0.18, 0.1), 5), 0.4, false), Vector3(0, 0.06, 0)))
	torso.add_child(Fx.box(Vector3(0.06, 0.05, 0.02), Fx.mat(Color(0.85, 0.7, 0.3), 0.3), Vector3(0, 0.06, -0.16 * bulk)))
	if o.has("apron"):
		torso.add_child(Fx.box(Vector3(w * 0.75, 0.62, 0.02), _cloth_mat(o["apron"]), Vector3(0, 0.0, -0.155 * bulk)))
	if o.get("plate", false):
		var plate := PixTex.mat(PixTex.metal(Color(0.6, 0.62, 0.68)), 0.3, false)
		torso.add_child(Fx.box(Vector3(w + 0.04, 0.4, 0.32), plate, Vector3(0, 0.36, 0)))
		for sx in [-1.0, 1.0]:
			torso.add_child(Fx.box(Vector3(0.18, 0.12, 0.3), plate, Vector3(sx * 0.3, 0.55, 0)))
	# A little Vael tech: a glowing brooch on most citizens
	torso.add_child(Fx.box(Vector3(0.05, 0.05, 0.02), Fx.mat(accent.lightened(0.3), 3.0), Vector3(0.12, 0.44, -0.15 * bulk)))
	# The head: a big block with a pixel face painted on the front and a cap of hair
	head = Node3D.new()
	head.position = Vector3(0, 0.56, 0)
	torso.add_child(head)
	var hs := 0.34
	head.add_child(Fx.box(Vector3(hs, hs, hs), skin, Vector3(0, hs * 0.5, 0)))
	var face_style: String = o.get("face", "")
	if face_style == "stubble_kid":
		face_style = ""
	var hair_c := hair if not o.get("bald", false) else Color(0, 0, 0, 0)
	var ftex := PixTex.face(skin_col, hair_c, [Color(0.2, 0.15, 0.1), Color(0.2, 0.35, 0.6), Color(0.25, 0.45, 0.25)][r.randi() % 3], face_style, r.randi() % 50)
	var fq := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(hs, hs)
	fq.mesh = qm
	fq.material_override = PixTex.decal(ftex)
	fq.position = Vector3(0, hs * 0.5, -hs * 0.5 - 0.002)
	fq.rotation.y = PI
	head.add_child(fq)
	if not o.get("bald", false):
		var hm := PixTex.mat(PixTex.grain(hair, 6), 0.3, false)
		head.add_child(Fx.box(Vector3(hs + 0.02, 0.08, hs + 0.02), hm, Vector3(0, hs + 0.02, 0)))
		head.add_child(Fx.box(Vector3(hs + 0.02, hs * 0.8, 0.06), hm, Vector3(0, hs * 0.58, hs * 0.5)))
	_build_hat(o, hs)
	# Arms
	for side in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(side * (w * 0.5 + 0.06), 0.5, 0)
		torso.add_child(arm)
		arm.add_child(Fx.box(Vector3(0.12, 0.42, 0.13), cl if not o.get("plate", false) else PixTex.mat(PixTex.metal(Color(0.6, 0.62, 0.68)), 0.3, false), Vector3(0, -0.2, 0)))
		arm.add_child(Fx.box(Vector3(0.11, 0.1, 0.11), skin, Vector3(0, -0.46, 0)))
		if side < 0.0:
			arm_l = arm
		else:
			arm_r = arm
	if o.get("lute", false):
		var lute := Node3D.new()
		lute.position = Vector3(0.1, 0.25, 0.18)
		lute.rotation.z = 0.6
		torso.add_child(lute)
		lute.add_child(Fx.sphere(0.15, PixTex.mat(PixTex.planks(Color(0.6, 0.38, 0.18)), 0.4, false), Vector3(0, -0.1, 0)))
		lute.add_child(Fx.box(Vector3(0.05, 0.4, 0.04), PixTex.mat(PixTex.grain(Color(0.3, 0.18, 0.1)), 0.3, false), Vector3(0, 0.2, 0)))


func _build_hat(o: Dictionary, hs: float) -> void:
	var hat: String = o.get("hat", "")
	if hat == "":
		return
	var hc: Color = o.get("hat_col", Color(0.4, 0.3, 0.2))
	var hm := _cloth_mat(hc)
	match hat:
		"cap":
			head.add_child(Fx.box(Vector3(hs + 0.04, 0.08, hs + 0.04), hm, Vector3(0, hs + 0.04, 0)))
			head.add_child(Fx.box(Vector3(hs * 0.8, 0.03, 0.14), hm, Vector3(0, hs, -hs * 0.55)))
		"hood":
			head.add_child(Fx.box(Vector3(hs + 0.06, 0.1, hs + 0.06), hm, Vector3(0, hs + 0.04, 0.0)))
			for sx in [-1.0, 1.0]:
				head.add_child(Fx.box(Vector3(0.04, hs, hs + 0.06), hm, Vector3(sx * (hs * 0.5 + 0.03), hs * 0.5, 0.0)))
			head.add_child(Fx.box(Vector3(hs + 0.06, hs, 0.06), hm, Vector3(0, hs * 0.5, hs * 0.5 + 0.03)))
		"straw":
			var sm := PixTex.mat(PixTex.planks(Color(0.85, 0.72, 0.4)), 0.3, false)
			head.add_child(Fx.box(Vector3(hs + 0.24, 0.03, hs + 0.24), sm, Vector3(0, hs + 0.02, 0)))
			head.add_child(Fx.box(Vector3(hs * 0.8, 0.1, hs * 0.8), sm, Vector3(0, hs + 0.08, 0)))
		"kerchief", "bandana":
			head.add_child(Fx.box(Vector3(hs + 0.03, 0.1, hs + 0.03), hm, Vector3(0, hs + 0.01, 0.01)))
			head.add_child(Fx.box(Vector3(0.08, 0.1, 0.08), hm, Vector3(0, hs - 0.05, hs * 0.5 + 0.05)))
		"wimple", "veil", "shawl":
			head.add_child(Fx.box(Vector3(hs + 0.06, 0.08, hs + 0.06), hm, Vector3(0, hs + 0.04, 0)))
			head.add_child(Fx.box(Vector3(hs + 0.08, hs + 0.15, 0.08), hm, Vector3(0, hs * 0.45, hs * 0.5 + 0.04)))
			for sx in [-1.0, 1.0]:
				head.add_child(Fx.box(Vector3(0.05, hs + 0.1, hs * 0.9), hm, Vector3(sx * (hs * 0.5 + 0.03), hs * 0.45, 0.02)))
			if hat == "wimple":
				head.add_child(Fx.box(Vector3(hs + 0.07, 0.05, 0.02), _cloth_mat(Color(0.95, 0.95, 0.95)), Vector3(0, hs - 0.02, -hs * 0.5 - 0.01)))
		"helm":
			var hm2 := PixTex.mat(PixTex.metal(Color(0.6, 0.62, 0.68)), 0.3, false)
			head.add_child(Fx.box(Vector3(hs + 0.06, 0.14, hs + 0.06), hm2, Vector3(0, hs + 0.03, 0)))
			head.add_child(Fx.box(Vector3(0.05, 0.16, 0.05), hm2, Vector3(0, hs * 0.55, -hs * 0.5 - 0.03)))  # nose guard
			head.add_child(Fx.box(Vector3(0.04, 0.12, 0.2), Fx.mat(Color(0.4, 0.8, 1.0), 2.0), Vector3(0, hs + 0.15, 0)))  # aether crest
		"tophat":
			head.add_child(Fx.box(Vector3(hs + 0.12, 0.03, hs + 0.12), hm, Vector3(0, hs + 0.02, 0)))
			head.add_child(Fx.box(Vector3(hs * 0.8, 0.26, hs * 0.8), hm, Vector3(0, hs + 0.15, 0)))
			head.add_child(Fx.cylinder(0.05, 0.05, 0.03, Fx.mat(Color(0.85, 0.65, 0.25), 0.6), Vector3(hs * 0.42, hs + 0.12, 0)))
		"feather":
			head.add_child(Fx.box(Vector3(hs + 0.08, 0.08, hs + 0.04), hm, Vector3(0.03, hs + 0.04, 0)))
			var fe := Fx.box(Vector3(0.03, 0.3, 0.08), _cloth_mat(Color(0.95, 0.85, 0.35)), Vector3(-0.12, hs + 0.2, 0.05))
			fe.rotation.z = 0.5
			head.add_child(fe)


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
	torso.position.y = 0.62 + sin(t * 2.0) * 0.008
