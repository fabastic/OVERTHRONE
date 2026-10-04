extends "res://scripts/attacks/attack.gd"
## Hellfire Orb: a projectile you aim. Counter: SIDESTEP out of its path.

var dir := Vector3.FORWARD
var speed := 16.0
var life := 2.5
var homing := 0.0  # turn rate (rad/s) toward him; used by Null Orb
var size := 1.0


func launch() -> void:
	add_child(Fx.sphere(0.2 * size, Fx.mat(color, 6.0)))
	add_child(Fx.sphere(0.32 * size, Fx.mat(color, 2.0, 0.35)))
	var light := OmniLight3D.new()
	light.light_color = color
	light.omni_range = 4.0
	light.light_energy = 2.0
	add_child(light)
	add_child(Fx.particles(color, 24, 0.35, 0.6, 0.07))
	notify_hero()


func _physics_process(delta: float) -> void:
	if finished:
		return
	if homing > 0.0 and hero_ok():
		var want: Vector3 = (hero.center() - global_position).normalized()
		dir = dir.slerp(want, clampf(homing * delta, 0.0, 1.0)).normalized()
	global_position += dir * speed * delta
	life -= delta
	if hero_ok() and global_position.distance_to(hero.center()) < 0.7 * size:
		hit_hero()
		_explode()
		return
	if global_position.y <= 0.1 or life <= 0.0:
		if hero_ok() and global_position.distance_to(hero.center()) < 1.5:
			hit_hero(damage * 0.6)
		_explode()


func _explode() -> void:
	game.spawn_burst(global_position, color, 18)
	finish()
	queue_free()


func hero_counter(h) -> void:
	var c: Vector3 = h.center()
	var along := (c - global_position).dot(dir)
	if along < 0.0:
		return
	var closest := global_position + dir * along
	if closest.distance_to(c) > 1.8:
		return  # It was never going to hit him.
	var side := Vector3(-dir.z, 0, dir.x).normalized()
	if (c - closest).dot(side) < 0.0:
		side = -side
	if absf(h.position.x + side.x * 2.4) > 6.3:
		side = -side
	h.dash(side, 2.4, 0.2)
	h.announce("SIDESTEP")
	countered = true
