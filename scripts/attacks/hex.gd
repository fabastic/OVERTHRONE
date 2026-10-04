extends "res://scripts/attacks/attack.gd"
## Hex of Frailty: a curse that halves his blade's damage for eight seconds.
## Counter: CLEANSE it almost immediately.

var duration := 8.0
var t := 0.0
var cleansed := false


func launch() -> void:
	if hero_ok():
		hero.hex(duration)
		game.spawn_burst(hero.center(), color, 20)
	notify_hero()


func _physics_process(delta: float) -> void:
	t += delta
	var gone: bool = not hero_ok() or hero.hex_t <= 0.0
	if t >= duration or (t > 0.2 and gone):
		landed = not cleansed
		finish()
		queue_free()


func hero_counter(h) -> void:
	h.cleanse()
	h.announce("CLEANSE")
	cleansed = true
	countered = true
