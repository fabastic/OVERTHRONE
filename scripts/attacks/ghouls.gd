extends "res://scripts/attacks/attack.gd"
## Ghoul Brood: three ghouls crawl from the dais and burst on him.
## Counter: CLEAVE them apart before they reach him.

var ghouls: Array = []
var count := 3
var scale_g := 1.0
var cleave := false
var announced := false
var t := 0.0


func launch() -> void:
	var flesh := Fx.mat(Color(0.45, 0.55, 0.35))
	var dark := Fx.mat(Color(0.25, 0.3, 0.2))
	var eye := Fx.mat(Color(1.0, 0.2, 0.1), 5.0)
	for i in count:
		var g := Node3D.new()
		g.scale = Vector3.ONE * scale_g
		g.add_child(Fx.box(Vector3(0.4, 0.35, 0.55), flesh, Vector3(0, 0.45, 0)))
		g.add_child(Fx.box(Vector3(0.28, 0.25, 0.25), flesh, Vector3(0, 0.6, -0.35)))
		for s in [-1.0, 1.0]:
			g.add_child(Fx.box(Vector3(0.08, 0.4, 0.08), dark, Vector3(s * 0.22, 0.2, -0.15)))
			g.add_child(Fx.box(Vector3(0.08, 0.35, 0.08), dark, Vector3(s * 0.18, 0.18, 0.2)))
			g.add_child(Fx.box(Vector3(0.05, 0.05, 0.02), eye, Vector3(s * 0.07, 0.65, -0.48)))
		add_child(g)
		g.global_position = global_position + Vector3((i - (count - 1) * 0.5) * 1.2, 0, 0)
		ghouls.append({"node": g, "alive": true, "phase": randf() * TAU})
	game.spawn_burst(global_position + Vector3(0, 0.4, 0), color, 20)
	notify_hero()


func _physics_process(delta: float) -> void:
	t += delta
	var alive := 0
	for g in ghouls:
		if not g["alive"]:
			continue
		alive += 1
		var node: Node3D = g["node"]
		if not hero_ok():
			continue
		var hp: Vector3 = hero.global_position
		var to := Vector3(hp.x - node.global_position.x, 0, hp.z - node.global_position.z)
		var d := to.length()
		if cleave and d < 1.7:
			_kill(g, false)
			continue
		if d < 0.8:
			hit_hero()
			_kill(g, true)
			continue
		var wobble := Vector3(-to.z, 0, to.x).normalized() * sin(t * 6.0 + g["phase"]) * 0.6
		node.global_position += (to.normalized() + wobble).normalized() * 4.2 * delta
		node.look_at(Vector3(hp.x, 0, hp.z), Vector3.UP)
		node.position.y = absf(sin(t * 14.0 + g["phase"])) * 0.12
	if alive == 0 or t > 8.0:
		finish()
		queue_free()


func _kill(g: Dictionary, burst_on_him: bool) -> void:
	g["alive"] = false
	var node: Node3D = g["node"]
	game.spawn_burst(node.global_position + Vector3(0, 0.5, 0), color if burst_on_him else Color(0.8, 1.0, 0.6), 16)
	node.visible = false
	if not burst_on_him and not announced and hero_ok():
		announced = true
		hero.announce("CLEAVE")
		hero.swing()


func hero_counter(_h) -> void:
	cleave = true
	countered = true
