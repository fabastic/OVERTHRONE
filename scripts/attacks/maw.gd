extends "res://scripts/attacks/attack.gd"
## Abyssal Rift: the floor splits along a lane running the length of the hall, then erupts.
## Counter: STEP OUT of the lane sideways.

var width := 2.6
var delay := 1.0
var t := 0.0
var erupted := false
var lane_mat: StandardMaterial3D
var shards: Node3D


func launch() -> void:
	global_position = Vector3(global_position.x, 0, -8.0)
	lane_mat = Fx.mat(color, 2.0, 0.45)
	add_child(Fx.box(Vector3(width, 0.02, 12.0), lane_mat, Vector3(0, 0.03, 0)))
	shards = Node3D.new()
	shards.position.y = -2.5
	add_child(shards)
	var dark := Fx.mat(color.darkened(0.3), 1.5)
	var z := -5.8
	while z <= 5.8:
		var h := randf_range(1.2, 2.4)
		var sh := Fx.cylinder(0.0, 0.3, h, dark, Vector3(randf_range(-width * 0.4, width * 0.4), h * 0.5, z))
		sh.rotation = Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
		shards.add_child(sh)
		z += 0.7
	notify_hero()


func _lane_offset() -> float:
	if not hero_ok():
		return 999.0
	return hero.global_position.x - global_position.x


func _physics_process(delta: float) -> void:
	t += delta
	if not erupted:
		lane_mat.albedo_color.a = 0.2 + 0.35 * absf(sin(t * 12.0))
		if t >= delay:
			erupted = true
			game.boss.shake(0.4)
			Sfx.play("slam", 0.0, 1.3)
			if absf(_lane_offset()) < width * 0.5 + 0.2:
				hit_hero()
		return
	var e := t - delay
	shards.position.y = lerpf(-2.5, 0.0, clampf(e / 0.1, 0.0, 1.0)) if e < 0.5 else lerpf(0.0, -2.5, clampf((e - 0.5) / 0.3, 0.0, 1.0))
	if e > 0.85:
		finish()
		queue_free()


func hero_counter(h) -> void:
	var off := _lane_offset()
	if absf(off) > width * 0.5 + 0.5:
		return
	var side := signf(off) if absf(off) > 0.05 else (1.0 if randf() < 0.5 else -1.0)
	var dist := width * 0.5 + 0.9 - absf(off)
	if absf(h.position.x + side * dist) > 6.3:
		side = -side
		dist = width * 0.5 + 0.9 + absf(off)
	h.dash(Vector3(side, 0, 0), dist, 0.28)
	h.announce("STEP OUT")
	countered = true
