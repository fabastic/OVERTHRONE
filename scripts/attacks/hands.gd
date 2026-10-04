extends "res://scripts/attacks/attack.gd"
## Phantom Hands: your true hands, vast and ghostly, fall from the dark and clap down on him.
## Counter: FALL BACK out of their reach.

var delay := 0.95
var reach := 2.2
var t := 0.0
var slammed := false
var hands: Array[Node3D] = []
var ghost: StandardMaterial3D
var marks: Array[MeshInstance3D] = []


func launch() -> void:
	ghost = Fx.mat(color, 2.5, 0.55)
	var warn := Fx.mat(Color(1.0, 0.2, 0.2), 2.0, 0.4)
	for s in [-1.0, 1.0]:
		var m := Fx.box(Vector3(1.4, 0.02, 2.4), warn, Vector3(s * 1.1, 0.03, 0))
		add_child(m)
		marks.append(m)
		var h := Node3D.new()
		h.add_child(Fx.box(Vector3(0.4, 1.8, 1.6), ghost, Vector3.ZERO))
		for f in 4:
			h.add_child(Fx.box(Vector3(0.3, 0.9, 0.3), ghost, Vector3(0, 1.3, -0.6 + f * 0.4)))
		h.add_child(Fx.box(Vector3(0.3, 0.7, 0.3), ghost, Vector3(0, 0.6, 0.95)))
		h.position = Vector3(s * 3.0, 9.0, 0)
		h.rotation.z = s * 0.25
		add_child(h)
		hands.append(h)
	notify_hero()


func _physics_process(delta: float) -> void:
	t += delta
	for m in marks:
		var mm: StandardMaterial3D = m.material_override
		mm.albedo_color.a = 0.2 + 0.35 * absf(sin(t * 14.0))
	if not slammed:
		var k := pow(clampf(t / delay, 0.0, 1.0), 3.0)
		for i in hands.size():
			var s := -1.0 if i == 0 else 1.0
			hands[i].position = Vector3(s * lerpf(3.0, 0.35, k), lerpf(9.0, 0.9, k), 0)
		if t >= delay:
			slammed = true
			game.boss.shake(0.7)
			game.spawn_burst(global_position + Vector3(0, 0.8, 0), color, 40)
			Sfx.play("slam", 3.0)
			if flat_dist_to_hero() < reach:
				hit_hero()
		return
	var e := t - delay
	ghost.albedo_color.a = maxf(0.0, 0.55 - e * 1.2)
	for i in hands.size():
		hands[i].position.y += delta * 3.0
	if e > 0.5:
		finish()
		queue_free()


func hero_counter(h) -> void:
	var hp: Vector3 = h.position
	var back := Vector3(hp.x, 0, hp.z).normalized()
	h.dash(back, 3.4, 0.35)
	h.announce("FALL BACK")
	countered = true
