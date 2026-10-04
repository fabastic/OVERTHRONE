extends "res://scripts/attacks/attack.gd"
## Rime Lance: very fast projectile. Counter: PARRY it with his sword (needs quick reactions).

var dir := Vector3.FORWARD
var speed := 30.0
var life := 1.5
var vel := Vector3.ZERO
var deflected := false


func launch() -> void:
	var holder := Node3D.new()
	add_child(holder)
	holder.add_child(Fx.box(Vector3(0.07, 0.07, 0.9), Fx.mat(color, 5.0)))
	if absf(dir.y) < 0.98:
		holder.basis = Basis.looking_at(dir, Vector3.UP)
	var light := OmniLight3D.new()
	light.light_color = color
	light.omni_range = 3.0
	light.light_energy = 1.5
	add_child(light)
	add_child(Fx.particles(color, 16, 0.25, 0.3, 0.05))
	vel = dir * speed
	notify_hero()


func _physics_process(delta: float) -> void:
	if finished:
		return
	global_position += vel * delta
	life -= delta
	if deflected:
		if life <= 0.0:
			finish()
			queue_free()
		return
	if hero_ok() and global_position.distance_to(hero.center()) < 0.75:
		if hero.parry_t > 0.0:
			deflected = true
			countered = true
			vel = Vector3(randf_range(-6, 6), 14, 8)
			life = 0.6
			hero.announce("PARRIED")
			game.spawn_burst(global_position, Color.WHITE, 12)
		else:
			hit_hero()
			game.spawn_burst(global_position, color, 12)
			finish()
			queue_free()
		return
	if global_position.y <= 0.05 or life <= 0.0:
		game.spawn_burst(global_position, color, 8)
		finish()
		queue_free()


func hero_counter(h) -> void:
	var c: Vector3 = h.center()
	var along := (c - global_position).dot(dir)
	if along < 0.0 or (global_position + dir * along).distance_to(c) > 1.5:
		return
	h.parry(along / speed + 0.15)
	h.announce("PARRY")
