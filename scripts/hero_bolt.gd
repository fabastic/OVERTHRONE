extends Node3D
## A Holy Bolt thrown by the hero at your face. It flies continuously but only LANDS on a tick:
## once it reaches you it hangs there, burning, until main resolves it (resolve()). Parry on that beat.

const Fx := preload("res://scripts/fx.gd")

var game
var damage := 10.0
var target := Vector3(0, 2.3, 0.4)
var speed := 11.0
var done := false
var arrived := false
var color := Color(1.0, 0.85, 0.4)
var returned := false   # one of YOUR attacks, parried back at you


func _ready() -> void:
	var gold := color
	if returned:
		speed = 13.0
		add_child(Fx.sphere(0.42, Fx.mat(Color.WHITE, 2.0, 0.25)))
	add_child(Fx.sphere(0.18, Fx.mat(gold, 8.0)))
	add_child(Fx.sphere(0.32, Fx.mat(gold, 3.0, 0.35)))
	var light := OmniLight3D.new()
	light.light_color = gold
	light.omni_range = 5.0
	light.light_energy = 3.0
	add_child(light)
	add_child(Fx.particles(gold, 24, 0.3, 0.5, 0.06))
	Sfx.play("cast", -4.0, 1.6)


func _physics_process(delta: float) -> void:
	if done:
		return
	var to := target - global_position
	if to.length() < 0.6:
		arrived = true
		return
	global_position += to.normalized() * minf(speed * delta, to.length() - 0.5)


## Ticks until it lands (0 = it lands on the next tick). Used by autoplay to time a parry.
func ticks_left() -> int:
	if arrived:
		return 0
	return int((target - global_position).length() / (speed * GameState.TICK))


func resolve() -> void:
	if done:
		return
	done = true
	game.on_hero_struck_ranged(damage, target, returned)
	queue_free()
