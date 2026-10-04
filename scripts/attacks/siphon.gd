extends "res://scripts/attacks/attack.gd"
## Blood Siphon: a beam from your hand that drags toward him, drains him and heals your Will.
## Counter: BREAK LINE by dashing across it, twice.

var duration := 2.2
var t := 0.0
var tick := 0.0
var end_pos := Vector3.ZERO
var beam: MeshInstance3D
var beam_mat: StandardMaterial3D
var tip_light: OmniLight3D


func launch() -> void:
	if hero_ok():
		var hp: Vector3 = hero.global_position
		end_pos = Vector3(hp.x, 0, hp.z) + Vector3(randf_range(-2.0, 2.0), 0, -1.5)
	beam_mat = Fx.mat(color, 5.0, 0.85)
	beam = Fx.box(Vector3(0.12, 0.12, 1.0), beam_mat)
	add_child(beam)
	tip_light = OmniLight3D.new()
	tip_light.light_color = color
	tip_light.omni_range = 3.0
	tip_light.light_energy = 2.0
	add_child(tip_light)
	notify_hero()


func _physics_process(delta: float) -> void:
	t += delta
	if hero_ok():
		var hp: Vector3 = hero.global_position
		end_pos = end_pos.move_toward(Vector3(hp.x, 0, hp.z), 4.2 * delta)
	var a: Vector3 = game.boss.hand_tip()
	var b := end_pos + Vector3(0, 1.0, 0)
	var mid := (a + b) * 0.5
	beam.global_position = mid
	if a.distance_to(b) > 0.01:
		beam.global_basis = Basis.looking_at((b - a).normalized(), Vector3.UP)
	# Setting scale after the basis keeps the rotation.
	beam.scale = Vector3(1.0 + sin(t * 40.0) * 0.3, 1.0, a.distance_to(b))
	tip_light.global_position = b
	tick -= delta
	if tick <= 0.0:
		tick = 0.25
		if hero_ok() and end_pos.distance_to(Vector3(hero.global_position.x, 0, hero.global_position.z)) < 1.0:
			if hit_hero():
				game.heal_boss(damage)
	if t >= duration:
		finish()
		queue_free()


func hero_counter(h) -> void:
	_cut(h, 1.0)
	h.later(0.7, _cut.bind(h, -1.0))
	h.announce("BREAK LINE")
	countered = true


func _cut(h, side: float) -> void:
	if not is_instance_valid(h) or h.dead:
		return
	var hp: Vector3 = h.global_position
	var dir := Vector3(hp.x, 0, hp.z).normalized()
	var perp := Vector3(-dir.z, 0, dir.x) * side
	if absf(hp.x + perp.x * 2.6) > 6.3:
		perp = -perp
	h.dash(perp, 2.6, 0.22)
