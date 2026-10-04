extends "res://scripts/attacks/attack.gd"
## Sky Lash: tracks him and strikes after a short charge. Can't be outrun. Counter: raise a WARD in time.

var charge := 0.45
var t := 0.0
var struck := false
var spark: MeshInstance3D
var light: OmniLight3D


func launch() -> void:
	spark = Fx.sphere(0.25, Fx.mat(color, 8.0), Vector3(0, 6.5, 0))
	add_child(spark)
	light = OmniLight3D.new()
	light.light_color = color
	light.omni_range = 7.0
	light.position = Vector3(0, 5.0, 0)
	add_child(light)
	notify_hero()


func _physics_process(delta: float) -> void:
	t += delta
	if not struck:
		if hero_ok():
			var hp: Vector3 = hero.global_position
			global_position = Vector3(hp.x, 0, hp.z)
		spark.scale = Vector3.ONE * (0.5 + t / charge)
		light.light_energy = randf() * 2.5
		if t >= charge:
			_strike()
	elif t > charge + 0.25:
		finish()
		queue_free()


func _strike() -> void:
	struck = true
	spark.visible = false
	var bolt_mat := Fx.mat(Color(0.85, 0.9, 1.0), 10.0)
	var prev := Vector3(0, 7.0, 0)
	for i in 6:
		var y := 7.0 - (i + 1) * (7.0 / 6.0)
		var nxt := Vector3(randf_range(-0.4, 0.4), y, randf_range(-0.4, 0.4)) if i < 5 else Vector3(0, 0.6, 0)
		var seg := Fx.box(Vector3(0.1, 0.1, prev.distance_to(nxt)), bolt_mat, (prev + nxt) * 0.5)
		seg.basis = Basis.looking_at((nxt - prev).normalized(), Vector3.RIGHT)
		add_child(seg)
		prev = nxt
	light.position = Vector3(0, 2.0, 0)
	light.omni_range = 12.0
	light.light_energy = 8.0
	game.flash(Color(0.8, 0.85, 1.0), 0.3)
	if hero_ok() and hero.ward_t > 0.0:
		countered = true
		hero.announce("WARDED")
		game.spawn_burst(hero.center(), color, 16)
	else:
		hit_hero()


func hero_counter(h) -> void:
	var remaining := charge - t
	if remaining < 0.03:
		return
	h.ward(remaining + 0.25)
	h.announce("WARD")
