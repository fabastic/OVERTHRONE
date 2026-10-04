extends "res://scripts/attacks/attack.gd"
## Time Rend: a clock closes around him and stops his moment for two seconds.
## Counter: RESIST, and he is held for only half a second.

var windup := 0.45
var t := 0.0
var fired := false
var resisted := false
var hold := 2.0
var clock: Node3D


func launch() -> void:
	clock = Node3D.new()
	add_child(clock)
	var tm := TorusMesh.new()
	tm.inner_radius = 1.9
	tm.outer_radius = 2.0
	tm.rings = 32
	tm.ring_segments = 4
	var ring := MeshInstance3D.new()
	ring.mesh = tm
	ring.material_override = Fx.mat(color, 3.0, 0.8)
	ring.rotation.x = PI / 2.0
	ring.position.y = 1.0
	clock.add_child(ring)
	for i in 12:
		var a := TAU * i / 12.0
		clock.add_child(Fx.box(Vector3(0.08, 0.25, 0.05), Fx.mat(color, 3.0), Vector3(cos(a) * 1.75, 1.0 + sin(a) * 1.75, 0)))
	notify_hero()


func _physics_process(delta: float) -> void:
	t += delta
	if hero_ok() and not fired:
		var hp: Vector3 = hero.global_position
		global_position = Vector3(hp.x, 0, hp.z)
		look_at(Vector3(0, 0, 0), Vector3.UP)
	if not fired:
		clock.scale = Vector3.ONE * lerpf(2.0, 0.7, t / windup)
		clock.rotation.z += delta * 6.0
		if t >= windup:
			fired = true
			hold = 0.5 if resisted else 2.0
			landed = not resisted
			if hero_ok():
				hero.stun(hold)
				hero.announce("RESISTED" if resisted else "FROZEN IN TIME")
			game.flash(color, 0.35)
			Sfx.play("parry", -2.0, 0.5)
		return
	if t >= windup + hold:
		finish()
		queue_free()


func hero_counter(_h) -> void:
	resisted = true
	countered = true
