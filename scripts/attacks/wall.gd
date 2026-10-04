extends "res://scripts/attacks/attack.gd"
## Ossuary Wall: a wall of bones across the hall. He is stuck behind it (free hits for you)
## until it sinks. Counter: VAULT over it.

var duration := 3.6
var t := 0.0
var blocked_time := 0.0
var bones: Node3D


func launch() -> void:
	add_to_group("walls")
	bones = Node3D.new()
	bones.position.y = -2.2
	add_child(bones)
	var bone := Fx.mat(color, 0.25)
	var x := -7.0
	while x <= 7.0:
		var h := randf_range(1.3, 2.0)
		var b := Fx.box(Vector3(0.35, h, 0.4), bone, Vector3(x, h * 0.5, randf_range(-0.12, 0.12)))
		b.rotation.z = randf_range(-0.2, 0.2)
		bones.add_child(b)
		bones.add_child(Fx.sphere(0.2, bone, Vector3(x, h + 0.1, 0)))
		x += 0.45
	game.boss.shake(0.2)
	notify_hero()


func active() -> bool:
	return t < duration and not finished


func wall_z() -> float:
	return global_position.z


func note_blocked(delta: float) -> void:
	blocked_time += delta


func _physics_process(delta: float) -> void:
	t += delta
	if t < 0.25:
		bones.position.y = lerpf(-2.2, 0.0, t / 0.25)
	elif t > duration:
		bones.position.y = lerpf(0.0, -2.2, clampf((t - duration) / 0.4, 0.0, 1.0))
		if t > duration + 0.4:
			landed = blocked_time > 0.8
			remove_from_group("walls")
			finish()
			queue_free()


func hero_counter(h) -> void:
	h.vault_ok = true
	countered = true
