extends Node3D
## A Holy Bolt thrown by the hero at your face. Parry it as it arrives.

const Fx := preload("res://scripts/fx.gd")

var game
var damage := 10.0
var target := Vector3(0, 2.3, 0.4)
var speed := 11.0
var done := false


func _ready() -> void:
	var gold := Color(1.0, 0.85, 0.4)
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
		done = true
		game.on_hero_struck_ranged(damage, target)
		queue_free()
		return
	global_position += to.normalized() * speed * delta
