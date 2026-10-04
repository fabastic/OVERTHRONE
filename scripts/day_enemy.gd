extends Node3D
## A foe in the streets and wilds of Vael by day. Thinks on combat ticks like everything else:
## a red countdown over its head shows the ticks until its blow lands. Parry on that beat (RMB)
## or step out of reach.
## Kinds: "thug" (raider), "automaton" (rust-bound, tough), "archer" (shoots), and the day bosses:
## "brute" (charges), "shield" (blocks unless it is recovering), "summoner" (calls thugs),
## "caster" (fire from range), "blinker" (teleports beside you).

signal died(enemy)

const Fx := preload("res://scripts/fx.gd")

var ow
var kind := "thug"
var display_name := ""
var is_boss := false
var max_hp := 40.0
var hp := 40.0
var dmg := 6.0
var speed := 2.6
var reach := 1.8
var cloth := Color(0.4, 0.25, 0.2)
var tech := Color(1.0, 0.4, 0.1)
var home := Vector3.ZERO
var aggro := false
var dead := false
var state := "idle"
var state_ticks := 0
var windup_ticks := 3
var special_cd := 10
var t := 0.0
var flash_t := 0.0
var knock := Vector3.ZERO
var charge_dir := Vector3.ZERO
var rig: Node3D
var torso: Node3D
var arm_r: Node3D
var arm_l: Node3D
var leg_l: Node3D
var leg_r: Node3D
var edge_mat: StandardMaterial3D
var body_mats: Array[StandardMaterial3D] = []
var countdown: Label3D
var name_label: Label3D


func _ready() -> void:
	home = position
	t = randf() * 5.0
	hp = max_hp
	if is_boss:
		scale = Vector3.ONE * 1.55
	_build()
	countdown = Label3D.new()
	countdown.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	countdown.no_depth_test = true
	countdown.fixed_size = true
	countdown.pixel_size = 0.0022
	countdown.font_size = 48
	countdown.outline_size = 10
	countdown.modulate = Color(1.0, 0.25, 0.2)
	countdown.position = Vector3(0, 2.3, 0)
	countdown.visible = false
	add_child(countdown)
	if is_boss:
		name_label = Label3D.new()
		name_label.text = display_name
		name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		name_label.fixed_size = true
		name_label.pixel_size = 0.0013
		name_label.font_size = 32
		name_label.outline_size = 8
		name_label.modulate = tech.lightened(0.3)
		name_label.position = Vector3(0, 2.7, 0)
		add_child(name_label)


func _m(c: Color, e: float = 0.0) -> StandardMaterial3D:
	var m := Fx.mat(c, e)
	if e <= 0.0:
		m.emission_enabled = true
		m.emission = Color.WHITE
		m.emission_energy_multiplier = 0.0
		body_mats.append(m)
	return m


func _build() -> void:
	rig = Node3D.new()
	add_child(rig)
	var metal := _m(Color(0.32, 0.3, 0.33) if kind != "automaton" else Color(0.45, 0.32, 0.22))
	var cl := _m(cloth)
	var glow := _m(tech, 4.0)
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.12, 0.82, 0)
		rig.add_child(leg)
		leg.add_child(Fx.box(Vector3(0.17, 0.78, 0.19), metal if kind == "automaton" else cl, Vector3(0, -0.4, 0)))
		leg.add_child(Fx.box(Vector3(0.05, 0.3, 0.02), glow, Vector3(side * 0.06, -0.45, -0.1)))
		if side < 0.0:
			leg_l = leg
		else:
			leg_r = leg
	torso = Node3D.new()
	torso.position = Vector3(0, 0.82, 0)
	rig.add_child(torso)
	torso.add_child(Fx.box(Vector3(0.5, 0.62, 0.3), cl, Vector3(0, 0.3, 0)))
	torso.add_child(Fx.box(Vector3(0.52, 0.32, 0.32), metal, Vector3(0, 0.42, 0)))
	torso.add_child(Fx.box(Vector3(0.12, 0.12, 0.02), glow, Vector3(0, 0.42, -0.17)))  # an aether core
	var head := Node3D.new()
	head.position = Vector3(0, 0.66, 0)
	torso.add_child(head)
	head.add_child(Fx.box(Vector3(0.27, 0.28, 0.27), metal, Vector3(0, 0.14, 0)))
	head.add_child(Fx.box(Vector3(0.22, 0.04, 0.02), glow, Vector3(0, 0.16, -0.14)))  # visor slit
	if is_boss:
		for i in 3:
			var horn := Fx.cylinder(0.0, 0.04, 0.22, glow, Vector3(-0.1 + i * 0.1, 0.36, 0))
			head.add_child(horn)
	for side in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(side * 0.33, 0.56, 0)
		torso.add_child(arm)
		arm.add_child(Fx.box(Vector3(0.2, 0.14, 0.26), metal, Vector3(side * 0.03, 0.04, 0)))
		arm.add_child(Fx.box(Vector3(0.12, 0.55, 0.13), cl, Vector3(0, -0.28, 0)))
		if side < 0.0:
			arm_l = arm
		else:
			arm_r = arm
	# Weapon: iron with an aether edge (axe for brutes/thugs, a staff for casters, a bow for archers).
	edge_mat = Fx.mat(tech, 2.5)
	var w := Node3D.new()
	w.position = Vector3(0, -0.55, 0)
	arm_r.add_child(w)
	match kind:
		"caster", "summoner":
			w.add_child(Fx.cylinder(0.025, 0.025, 1.3, metal, Vector3(0, 0.2, 0)))
			w.add_child(Fx.sphere(0.12, edge_mat, Vector3(0, 0.9, 0)))
		"archer":
			w.add_child(Fx.box(Vector3(0.04, 1.0, 0.06), metal, Vector3(0, 0.1, -0.1)))
			w.add_child(Fx.box(Vector3(0.01, 0.9, 0.01), edge_mat, Vector3(0, 0.1, -0.16)))
		"shield":
			w.add_child(Fx.box(Vector3(0.06, 0.06, 0.9), metal, Vector3(0, 0, -0.45)))
			w.add_child(Fx.box(Vector3(0.03, 0.08, 0.7), edge_mat, Vector3(0, 0, -0.5)))
			var sh := Fx.box(Vector3(0.6, 0.8, 0.08), metal, Vector3(0.05, -0.3, -0.25))
			arm_l.add_child(sh)
			arm_l.add_child(Fx.box(Vector3(0.4, 0.06, 0.02), edge_mat, Vector3(0.05, -0.2, -0.3)))
		_:
			w.add_child(Fx.box(Vector3(0.05, 0.05, 0.8), Fx.mat(Color(0.3, 0.2, 0.12)), Vector3(0, 0, -0.35)))
			w.add_child(Fx.box(Vector3(0.04, 0.3, 0.22), metal, Vector3(0, 0.08, -0.7)))
			w.add_child(Fx.box(Vector3(0.045, 0.32, 0.03), edge_mat, Vector3(0, 0.08, -0.82)))


func center() -> Vector3:
	return global_position + Vector3(0, 1.1 * scale.y, 0)


func take_hit(amount: float, from: Vector3) -> void:
	if dead:
		return
	aggro = true
	if kind == "shield" and state != "recover" and state != "stagger":
		amount *= 0.35
		ow.popup(center() + Vector3(0, 0.6, 0), "BLOCKED", Color(0.6, 0.8, 1.0))
	hp -= amount
	flash_t = 0.12
	ow.popup(center() + Vector3(randf_range(-0.3, 0.3), 0.8, 0), str(int(round(amount))), Color(1.0, 0.9, 0.6))
	var away := Vector3(position.x - from.x, 0, position.z - from.z)
	if away.length() > 0.01 and not is_boss:
		knock = away.normalized() * 4.0
	if hp <= 0.0:
		_die()
	elif state == "windup" and not is_boss and randf() < 0.5:
		_go("stagger")


func _die() -> void:
	dead = true
	countdown.visible = false
	var tw := create_tween()
	tw.tween_property(rig, "rotation:x", 1.5, 0.45).set_trans(Tween.TRANS_BACK)
	tw.tween_property(rig, "position:y", -0.3, 0.6)
	tw.tween_interval(2.5)
	tw.tween_callback(queue_free)
	died.emit(self)


func _go(s: String) -> void:
	state = s
	state_ticks = 0


## Decisions, once per tick.
func on_tick() -> void:
	if dead:
		return
	state_ticks += 1
	special_cd -= 1
	var pp: Vector3 = ow.walker.position
	var d := Vector2(pp.x - position.x, pp.z - position.z).length()
	if not aggro and d < (14.0 if is_boss else 9.0):
		aggro = true
		if is_boss:
			ow.boss_engaged(self)
	match state:
		"idle", "chase":
			if not aggro:
				return
			_go("chase")
			if special_cd <= 0:
				_special(d)
				return
			if kind in ["archer", "caster"]:
				if d < 16.0 and state_ticks % 6 == 0:
					_go("shoot")
				return
			if d < reach:
				windup_ticks = 2 if is_boss and ow.day >= 4 else 3
				_go("windup")
		"windup":
			if state_ticks >= windup_ticks:
				if d < reach + 0.6:
					ow.enemy_strike(self, dmg)
				_go("recover")
		"shoot":
			if state_ticks >= 3:
				ow.enemy_bolt(self, center() + Vector3(0, 0.3, 0), dmg * 0.8)
				_go("recover")
		"charge":
			if state_ticks >= 6 or d < reach:
				windup_ticks = 2
				_go("windup")
		"recover", "stagger":
			if state_ticks >= (3 if state == "recover" else 4):
				_go("chase")


func _special(d: float) -> void:
	match kind:
		"brute":
			if d > 4.0 and d < 14.0:
				special_cd = 14
				charge_dir = Vector3(ow.walker.position.x - position.x, 0, ow.walker.position.z - position.z).normalized()
				ow.popup(center() + Vector3(0, 1.0, 0), "CHARGE", tech)
				_go("charge")
				return
		"summoner":
			special_cd = 18
			ow.summon_adds(self, 2)
			ow.popup(center() + Vector3(0, 1.0, 0), "TO ME!", tech)
			return
		"caster":
			special_cd = 9
			for k in 3:
				ow.enemy_bolt(self, center() + Vector3((k - 1) * 0.8, 0.5, 0), dmg * 0.6)
			return
		"blinker":
			special_cd = 12
			var pp: Vector3 = ow.walker.position
			var a := randf() * TAU
			ow.burst(center(), tech)
			position = ow.resolve(position, pp + Vector3(cos(a), 0, sin(a)) * 1.6, 0.4)
			ow.burst(center(), tech)
			windup_ticks = 2
			_go("windup")
			return
	special_cd = 6


func _physics_process(delta: float) -> void:
	t += delta
	flash_t = maxf(0.0, flash_t - delta)
	for m in body_mats:
		m.emission_energy_multiplier = 3.0 if flash_t > 0.0 else 0.0
	if dead or ow == null or ow.walker == null:
		return
	var pp: Vector3 = ow.walker.position
	var to := Vector3(pp.x - position.x, 0, pp.z - position.z)
	var d := to.length()
	var v := Vector3.ZERO
	match state:
		"idle":
			v = Vector3(sin(t * 0.4), 0, cos(t * 0.3)) * 0.6
			if Vector2(position.x - home.x, position.z - home.z).length() > 4.0:
				v = Vector3(home.x - position.x, 0, home.z - position.z).normalized()
		"chase":
			if kind in ["archer", "caster"]:
				v = to.normalized() * speed * (1.0 if d > 9.0 else (-0.8 if d < 6.0 else 0.0))
				v += Vector3(-to.z, 0, to.x).normalized() * sin(t * 1.3) * speed * 0.5
			elif d > reach * 0.8:
				v = to.normalized() * speed
		"charge":
			v = charge_dir * speed * 3.2
	v += knock
	knock = knock.move_toward(Vector3.ZERO, delta * 14.0)
	position = ow.resolve(position, position + v * delta, 0.45 * scale.x)
	if d > 0.1 and state != "idle":
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-delta * 8.0))
	elif v.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-v.x, -v.z), 1.0 - exp(-delta * 4.0))
	# Animate
	var moving := v.length() > 0.4
	var stride := sin(t * (14.0 if state == "charge" else 9.0)) if moving else 0.0
	leg_l.rotation.x = stride * 0.7
	leg_r.rotation.x = -stride * 0.7
	var raise := 0.0
	if state == "windup":
		raise = 2.6
	elif state == "shoot":
		raise = 1.5
	elif state == "recover" and state_ticks == 0:
		raise = -0.4
	arm_r.rotation.x = lerp_angle(arm_r.rotation.x, raise if raise != 0.0 else stride * 0.5, 1.0 - exp(-delta * 18.0))
	arm_l.rotation.x = lerp_angle(arm_l.rotation.x, (1.2 if kind == "shield" and state != "recover" else -stride * 0.5), 1.0 - exp(-delta * 10.0))
	torso.rotation.x = 0.4 if state == "stagger" else (0.15 if state == "charge" else 0.0)
	var telegraph := state in ["windup", "shoot"]
	edge_mat.emission = Color(1.0, 0.2, 0.15) if telegraph else tech
	edge_mat.emission_energy_multiplier = 6.0 if telegraph else 2.5
	countdown.visible = state == "windup"
	if countdown.visible:
		countdown.text = str(maxi(1, windup_ticks - state_ticks))
