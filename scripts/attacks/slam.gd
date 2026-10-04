extends "res://scripts/attacks/attack.gd"
## Throne Quake: an expanding shockwave ring along the floor. Counter: LEAP over it.

var radius := 0.6
var speed := 8.5
var max_radius := 16.0
var ring: MeshInstance3D
var ring_mat: StandardMaterial3D


func launch() -> void:
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.0
	tm.rings = 48
	tm.ring_segments = 6
	ring_mat = Fx.mat(color, 3.0, 0.9)
	ring = MeshInstance3D.new()
	ring.mesh = tm
	ring.material_override = ring_mat
	ring.position.y = 0.15
	add_child(ring)
	game.boss.shake(0.35)
	game.spawn_burst(global_position + Vector3(0, 0.3, 0), color, 24)
	notify_hero()


func _physics_process(delta: float) -> void:
	if finished:
		return
	radius += speed * delta
	ring.scale = Vector3(radius, 3.0, radius)
	ring_mat.albedo_color.a = clampf(1.0 - radius / max_radius, 0.0, 1.0)
	if not landed and hero_ok():
		var d := flat_dist_to_hero()
		if absf(d - radius) < 0.5 and not hero.is_airborne():
			hit_hero()
	if radius >= max_radius:
		finish()
		queue_free()


func hero_counter(h) -> void:
	var eta := (flat_dist_to_hero() - radius) / speed
	if eta < 0.05:
		return
	h.jump_after(maxf(0.0, eta - 0.26))
	h.announce("LEAP")
	countered = true
