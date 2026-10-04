extends "res://scripts/attacks/attack.gd"
## Doom Mark: a sigil follows him, locks in place, then detonates.
## Counter: DASH out the moment it locks.

var track_time := 1.3
var lock_time := 0.5
var radius := 2.0
var t := 0.0
var locked := false
var escape := false
var ring_mat: StandardMaterial3D
var sigil: Node3D


func launch() -> void:
	sigil = Node3D.new()
	add_child(sigil)
	var tm := TorusMesh.new()
	tm.inner_radius = radius - 0.15
	tm.outer_radius = radius
	tm.rings = 32
	tm.ring_segments = 4
	ring_mat = Fx.mat(color, 2.5, 0.8)
	var ring := MeshInstance3D.new()
	ring.mesh = tm
	ring.material_override = ring_mat
	ring.scale = Vector3(1, 0.1, 1)
	ring.position.y = 0.05
	sigil.add_child(ring)
	for i in 2:
		var bar := Fx.box(Vector3(radius * 1.8, 0.02, 0.12), ring_mat, Vector3(0, 0.05, 0))
		bar.rotation.y = PI / 4.0 + i * PI / 2.0
		sigil.add_child(bar)
	notify_hero()


func _physics_process(delta: float) -> void:
	t += delta
	sigil.rotation.y += delta * (8.0 if locked else 2.5)
	if not locked:
		if hero_ok():
			var hp: Vector3 = hero.global_position
			global_position = global_position.lerp(Vector3(hp.x, 0, hp.z), 1.0 - exp(-delta * 6.0))
		if t >= track_time:
			locked = true
			ring_mat.emission_energy_multiplier = 6.0
			Sfx.play("click")
			if escape:
				_escape()
		return
	ring_mat.albedo_color.a = 0.4 + 0.6 * absf(sin(t * 25.0))
	if t >= track_time + lock_time:
		game.spawn_burst(global_position + Vector3(0, 0.5, 0), color, 36)
		game.boss.shake(0.35)
		Sfx.play("slam", -2.0)
		if flat_dist_to_hero() < radius:
			hit_hero()
		finish()
		queue_free()


func _escape() -> void:
	if not hero_ok():
		return
	var d := flat_dist_to_hero()
	hero.dash(away_from_me(hero), radius + 1.0 - d, 0.25)
	hero.announce("DASH")


func hero_counter(_h) -> void:
	escape = true
	countered = true
	if locked:
		_escape()
