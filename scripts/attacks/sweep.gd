extends "res://scripts/attacks/attack.gd"
## Titan Sweep: your vast arm sweeps an arc across the floor in front of the dais.
## Counter: LEAP over the arm as it passes.

const TELEGRAPH := 0.6
const SWEEP := 0.55
const A0 := -1.45
const A1 := 1.45
const R_IN := 1.2
const R_OUT := 8.0

var t := 0.0
var pivot: Node3D
var band_mat: StandardMaterial3D
var last_angle := A0
var done_hit := false


func launch() -> void:
	band_mat = Fx.mat(Color(1.0, 0.25, 0.15), 2.0, 0.35)
	for r in [R_IN, R_OUT]:
		var tm := TorusMesh.new()
		tm.inner_radius = r - 0.1
		tm.outer_radius = r
		tm.rings = 48
		tm.ring_segments = 4
		var ring := MeshInstance3D.new()
		ring.mesh = tm
		ring.material_override = band_mat
		ring.scale = Vector3(1, 0.1, 1)
		ring.position.y = 0.04
		add_child(ring)
	pivot = Node3D.new()
	pivot.position = Vector3(0, 0.6, 0)
	pivot.rotation.y = -A0
	pivot.visible = false
	add_child(pivot)
	var skin := Fx.mat(Color(0.42, 0.37, 0.5), 0.3)
	var claw := Fx.mat(color, 3.0)
	pivot.add_child(Fx.box(Vector3(1.0, 0.7, R_OUT - 0.5), skin, Vector3(0, 0, -(R_OUT + 0.5) * 0.5)))
	for f in 4:
		pivot.add_child(Fx.box(Vector3(0.25, 0.25, 0.9), claw, Vector3(-0.36 + f * 0.24, -0.2, -R_OUT - 0.2)))
	notify_hero()


func _hero_polar() -> Vector2:
	var hp: Vector3 = hero.global_position
	var dx := hp.x - global_position.x
	var dz := hp.z - global_position.z
	return Vector2(atan2(dx, -dz), Vector2(dx, dz).length())


func _physics_process(delta: float) -> void:
	t += delta
	band_mat.albedo_color.a = 0.2 + 0.3 * absf(sin(t * 12.0))
	if t < TELEGRAPH:
		return
	pivot.visible = true
	var k := clampf((t - TELEGRAPH) / SWEEP, 0.0, 1.0)
	var a := lerpf(A0, A1, k)
	pivot.rotation.y = -a
	if not done_hit and hero_ok():
		var hp := _hero_polar()
		if hp.y > R_IN and hp.y < R_OUT and hp.x > last_angle and hp.x <= a and not hero.is_airborne():
			done_hit = true
			hit_hero()
			game.boss.shake(0.3)
	last_angle = a
	if k >= 1.0 and t > TELEGRAPH + SWEEP + 0.2:
		finish()
		queue_free()


func hero_counter(h) -> void:
	var hp := _hero_polar()
	if hp.y < R_IN or hp.y > R_OUT:
		return
	var t_hit := TELEGRAPH + (hp.x - A0) / (A1 - A0) * SWEEP
	if t_hit - t < 0.05:
		return
	h.jump_after(maxf(0.0, t_hit - t - 0.25))
	h.announce("LEAP")
	countered = true
