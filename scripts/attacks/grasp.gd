extends "res://scripts/attacks/attack.gd"
## Crushing Grasp: your hand descends from above, follows him, locks, and closes.
## Only works if he is within your reach. Counter: ROLL out the moment it locks.

const REACH := 9.5
const TRACK := 0.7
const LOCK := 0.35

var t := 0.0
var locked := false
var closed := false
var escape := false
var held := 0.0
var ticks := 0
var hand: Node3D
var shadow_mat: StandardMaterial3D
var fingers: Array[Node3D] = []


func launch() -> void:
	var boss_pos := Vector3(game.boss_x(), 0, 0)
	if flat_dist_from(boss_pos) > REACH:
		game.popup_text(global_position + Vector3(0, 2.5, 0), "OUT OF REACH", Color(0.8, 0.7, 0.7), 1.0)
		finished = true
		queue_free()
		return
	shadow_mat = Fx.mat(Color(0.1, 0.0, 0.0), 0.0, 0.5)
	var sh := Fx.cylinder(1.4, 1.4, 0.02, shadow_mat, Vector3(0, 0.03, 0))
	add_child(sh)
	hand = Node3D.new()
	hand.position = Vector3(0, 6.0, 0)
	add_child(hand)
	var skin := Fx.mat(Color(0.42, 0.37, 0.5), 0.3)
	var claw := Fx.mat(color, 3.0)
	hand.add_child(Fx.box(Vector3(1.4, 0.4, 1.4), skin, Vector3.ZERO))
	for i in 5:
		var a := TAU * i / 5.0
		var f := Node3D.new()
		f.position = Vector3(cos(a) * 0.6, -0.1, sin(a) * 0.6)
		f.rotation.y = -a
		f.add_child(Fx.box(Vector3(0.22, 0.9, 0.22), skin, Vector3(0, -0.45, 0)))
		f.add_child(Fx.box(Vector3(0.16, 0.25, 0.16), claw, Vector3(0, -0.95, 0)))
		hand.add_child(f)
		fingers.append(f)
	notify_hero()


func flat_dist_from(p: Vector3) -> float:
	return Vector2(global_position.x - p.x, global_position.z - p.z).length()


func _physics_process(delta: float) -> void:
	if finished:
		return
	t += delta
	if not locked:
		if hero_ok():
			var hp: Vector3 = hero.global_position
			global_position = global_position.lerp(Vector3(hp.x, 0, hp.z), 1.0 - exp(-delta * 7.0))
		hand.position.y = lerpf(6.0, 2.4, t / TRACK)
		if t >= TRACK:
			locked = true
			Sfx.play("click")
			if escape:
				_escape()
		return
	if not closed:
		shadow_mat.albedo_color = Color(0.8, 0.1, 0.05, 0.4 + 0.4 * absf(sin(t * 30.0)))
		if t >= TRACK + LOCK:
			closed = true
			hand.position.y = 1.2
			for f in fingers:
				f.rotation.x = 0.6
			game.boss.shake(0.4)
			Sfx.play("slam", -2.0, 1.4)
			if flat_dist_to_hero() < 1.5:
				held = 1.4
				hero.root(1.5)
				hero.announce("CRUSHED")
				hit_hero(damage / 3.0)
				ticks = 1
		return
	if held > 0.0:
		held -= delta
		if ticks < 3 and held < 1.4 - ticks * 0.45:
			ticks += 1
			hit_hero(damage / 3.0)
		return
	hand.position.y += delta * 6.0
	if hand.position.y > 6.0:
		finish()
		queue_free()


func _escape() -> void:
	if not hero_ok():
		return
	hero.dash(away_from_me(hero), 2.6 - flat_dist_to_hero(), 0.25)
	hero.announce("ROLL")


func hero_counter(_h) -> void:
	escape = true
	countered = true
	if locked and not closed:
		_escape()
