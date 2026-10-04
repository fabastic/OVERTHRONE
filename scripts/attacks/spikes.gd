extends "res://scripts/attacks/attack.gd"
## Bone Spires: a telegraphed circle that erupts after a delay. Counter: ROLL out of it.

var radius := 1.8
var delay := 0.85
var t := 0.0
var erupted := false
var disk_mat: StandardMaterial3D
var spires: Node3D


func launch() -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.02
	cm.radial_segments = 20
	disk_mat = Fx.mat(Color(1.0, 0.15, 0.1), 2.0, 0.5)
	var disk := MeshInstance3D.new()
	disk.mesh = cm
	disk.material_override = disk_mat
	disk.position.y = 0.03
	add_child(disk)
	spires = Node3D.new()
	spires.position.y = -1.7
	add_child(spires)
	var bone := Fx.mat(color, 0.3)
	for i in 9:
		var a := randf() * TAU
		var r := sqrt(randf()) * radius * 0.9
		var h := randf_range(1.0, 1.6)
		var s := Fx.cylinder(0.0, 0.17, h, bone, Vector3(cos(a) * r, h * 0.5, sin(a) * r))
		s.rotation = Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
		spires.add_child(s)
	notify_hero()


func _physics_process(delta: float) -> void:
	t += delta
	if not erupted:
		disk_mat.albedo_color.a = 0.25 + 0.4 * absf(sin(t * 14.0))
		if t >= delay:
			erupted = true
			disk_mat.albedo_color.a = 0.15
			game.spawn_burst(global_position + Vector3(0, 0.2, 0), color, 20)
			if flat_dist_to_hero() < radius + 0.25:
				hit_hero()
		return
	var e := t - delay
	if e < 0.6:
		spires.position.y = lerpf(-1.7, 0.0, clampf(e / 0.08, 0.0, 1.0))
	else:
		spires.position.y = lerpf(0.0, -1.7, clampf((e - 0.6) / 0.3, 0.0, 1.0))
	if e > 0.95:
		finish()
		queue_free()


func hero_counter(h) -> void:
	var d := flat_dist_to_hero()
	if d > radius + 0.6:
		return
	var away := away_from_me(h)
	var dist := radius + 0.8 - d
	var hp: Vector3 = h.position
	var dest := hp + away * dist
	if absf(dest.x) > 6.3 or dest.z < -13.8 or dest.z > -2.0:
		away = -away  # Cornered: roll through instead.
		dist = radius + 0.8 + d
	h.dash(away, dist, 0.28)
	h.announce("ROLL")
	countered = true
