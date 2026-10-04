extends "res://scripts/attacks/attack.gd"
## Gravemaw: a void that drags him in, then collapses. Counter: ANCHOR his sword, then dash out.

const PULL_RANGE := 8.0

var duration := 2.2
var t := 0.0
var collapsed := false
var halo: MeshInstance3D


func launch() -> void:
	add_to_group("wells")
	add_child(Fx.sphere(0.32, Fx.mat(Color(0.03, 0.0, 0.05)), Vector3(0, 0.9, 0)))
	halo = Fx.sphere(0.5, Fx.mat(color, 3.0, 0.4), Vector3(0, 0.9, 0))
	add_child(halo)
	var p := Fx.particles(color, 40, 0.8, 0.0, 0.06)
	p.local_coords = true
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 3.0
	p.radial_accel_min = -14.0
	p.radial_accel_max = -10.0
	p.gravity = Vector3.ZERO
	p.position = Vector3(0, 0.9, 0)
	add_child(p)
	var light := OmniLight3D.new()
	light.light_color = color
	light.omni_range = 5.0
	light.light_energy = 2.0
	light.position = Vector3(0, 1.0, 0)
	add_child(light)
	notify_hero()


func pull_on(pos: Vector3) -> Vector3:
	if collapsed:
		return Vector3.ZERO
	var to := Vector3(global_position.x - pos.x, 0, global_position.z - pos.z)
	var d := to.length()
	if d < 0.2 or d > PULL_RANGE:
		return Vector3.ZERO
	return to / d * lerpf(5.0, 1.5, d / PULL_RANGE)


func _physics_process(delta: float) -> void:
	t += delta
	if not collapsed:
		halo.scale = Vector3.ONE * (1.0 + t * 0.8 + sin(t * 20.0) * 0.1)
		if t >= duration:
			collapsed = true
			remove_from_group("wells")
			halo.visible = false
			game.spawn_burst(global_position + Vector3(0, 0.9, 0), color, 36)
			game.boss.shake(0.2)
			if flat_dist_to_hero() < 2.4:
				hit_hero()
	elif t > duration + 0.3:
		finish()
		queue_free()


func hero_counter(h) -> void:
	if flat_dist_to_hero() > PULL_RANGE:
		return
	var remaining := duration - t
	h.anchor(remaining)
	h.later(maxf(0.0, remaining - 0.45), _escape.bind(h))
	h.announce("ANCHOR")
	countered = true


func _escape(h) -> void:
	if not is_instance_valid(h) or h.dead:
		return
	var d := flat_dist_to_hero()
	if d < 2.8:
		h.dash(away_from_me(h), 3.3 - d, 0.25)
