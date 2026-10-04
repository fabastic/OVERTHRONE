extends "res://scripts/attacks/attack.gd"
## A telegraphed circle that erupts after a delay. One script, four looks:
##   pillar (Hellfire Pillar) · meteor (Falling Star) · frost (Frost Bloom, slows) · drop (Crimson Rain).
## Counter: get out of the circle before it erupts.

var radius := 1.3
var delay := 0.6
var style := "pillar"
var slow_time := 0.0
var counter_label := "ROLL"
var t := 0.0
var erupted := false
var disk_mat: StandardMaterial3D
var blast: Node3D
var rock: MeshInstance3D
var rock_start := Vector3(3.0, 16.0, 2.0)  # relative start of the falling/thrown rock
var rock_size := 0.7

const ROCK_START := Vector3(3.0, 16.0, 2.0)


func launch() -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.02
	cm.radial_segments = 20
	disk_mat = Fx.mat(color, 2.0, 0.45)
	var disk := MeshInstance3D.new()
	disk.mesh = cm
	disk.material_override = disk_mat
	disk.position.y = 0.03
	add_child(disk)
	if style == "meteor":
		rock = Fx.sphere(rock_size, Fx.mat(color, 3.0), rock_start)
		add_child(rock)
		rock.add_child(Fx.particles(color, 30, 0.4, 1.0, 0.15))
	notify_hero()


func _physics_process(delta: float) -> void:
	t += delta
	if not erupted:
		disk_mat.albedo_color.a = 0.2 + 0.35 * absf(sin(t * 14.0))
		if rock:
			var k := t / delay
			rock.position = rock_start.lerp(Vector3(0, 0.6, 0), k) + Vector3(0, sin(k * PI) * 3.0 * (1.0 if rock_start.y < 8.0 else 0.0), 0)
		if t >= delay:
			_erupt()
		return
	var e := t - delay
	if blast:
		blast.scale.y = maxf(0.01, 1.0 - e * 1.8)
	if e > 0.6:
		finish()
		queue_free()


func _erupt() -> void:
	erupted = true
	disk_mat.albedo_color.a = 0.1
	blast = Node3D.new()
	add_child(blast)
	match style:
		"pillar", "drop":
			var h := 5.0 if style == "pillar" else 2.5
			blast.add_child(Fx.cylinder(radius * 0.75, radius * 0.9, h, Fx.mat(color, 5.0, 0.8), Vector3(0, h * 0.5, 0)))
		"meteor":
			if rock:
				rock.visible = false
			blast.add_child(Fx.sphere(radius, Fx.mat(color, 4.0, 0.6), Vector3(0, 0.5, 0)))
			game.boss.shake(0.6)
			Sfx.play("slam", 2.0)
		"frost":
			var ice := Fx.mat(color, 1.5, 0.9)
			for i in 9:
				var a := TAU * i / 9.0
				var r := radius * (0.3 + randf() * 0.6)
				var crystal := Fx.box(Vector3(0.18, randf_range(0.6, 1.2), 0.18), ice, Vector3(cos(a) * r, 0.4, sin(a) * r))
				crystal.rotation = Vector3(randf_range(-0.5, 0.5), a, randf_range(-0.5, 0.5))
				blast.add_child(crystal)
	game.spawn_burst(global_position + Vector3(0, 0.3, 0), color, 12 if style == "drop" else 24)
	if flat_dist_to_hero() < radius + 0.2:
		hit_hero()
		if slow_time > 0.0 and hero_ok():
			hero.slow(slow_time)


func hero_counter(h) -> void:
	roll_out(h, radius, counter_label)
