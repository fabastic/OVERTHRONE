extends "res://scripts/attacks/attack.gd"
## Grasping Chains: telegraphed snare that roots him in place. Counter: BREAK AWAY before it closes.

var radius := 1.5
var delay := 0.6
var hold := 1.7
var t := 0.0
var sprung := false
var disk_mat: StandardMaterial3D
var links: Node3D


func launch() -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.02
	cm.radial_segments = 16
	disk_mat = Fx.mat(color, 2.0, 0.45)
	var disk := MeshInstance3D.new()
	disk.mesh = cm
	disk.material_override = disk_mat
	disk.position.y = 0.03
	add_child(disk)
	links = Node3D.new()
	links.position.y = -1.6
	add_child(links)
	var iron := Fx.mat(Color(0.3, 0.28, 0.35), 0.4)
	for i in 6:
		var a := TAU * i / 6.0
		var post := Node3D.new()
		post.position = Vector3(cos(a) * radius * 0.8, 0, sin(a) * radius * 0.8)
		post.rotation = Vector3(0, -a, 0.35)
		for k in 5:
			var link_size := Vector3(0.09, 0.22, 0.04 if k % 2 == 0 else 0.12)
			post.add_child(Fx.box(link_size, iron, Vector3(0, 0.15 + k * 0.24, 0)))
		links.add_child(post)
	notify_hero()


func _physics_process(delta: float) -> void:
	t += delta
	if not sprung:
		disk_mat.albedo_color.a = 0.2 + 0.35 * absf(sin(t * 12.0))
		if t >= delay:
			sprung = true
			game.spawn_burst(global_position + Vector3(0, 0.3, 0), color, 14)
			if flat_dist_to_hero() < radius + 0.2:
				hit_hero()
				if hero_ok():
					hero.root(hold)
					hero.announce("BOUND")
		return
	var e := t - delay
	if e < hold:
		links.position.y = lerpf(-1.6, 0.0, clampf(e / 0.1, 0.0, 1.0))
		links.rotation.y = sin(e * 30.0) * 0.03
	else:
		links.position.y = lerpf(0.0, -1.6, clampf((e - hold) / 0.3, 0.0, 1.0))
	if e > hold + 0.35:
		finish()
		queue_free()


func hero_counter(h) -> void:
	var d := flat_dist_to_hero()
	if d > radius + 0.5:
		return
	h.dash(away_from_me(h), radius + 0.8 - d, 0.25)
	h.announce("BREAK AWAY")
	countered = true
