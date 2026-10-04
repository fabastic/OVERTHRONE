extends "res://scripts/attacks/attack.gd"
## Eclipse of Self: the hall goes dark. A blind hero reacts badly and every attack hits harder.
## Counter: KINDLE a torch so he can read you again.

var duration := 4.5
var t := 0.0
var hp_start := 0.0


func launch() -> void:
	if hero_ok():
		hp_start = hero.hp
	notify_hero()
	GameState.eclipse_active = true
	game.set_darkness(true)


func _physics_process(delta: float) -> void:
	t += delta
	if t >= duration and not finished:
		GameState.eclipse_active = false
		game.set_darkness(false)
		if hero_ok():
			landed = hero.hp < hp_start
			hero.extinguish()
		finish()
		queue_free()


func hero_counter(h) -> void:
	h.kindle()
	h.announce("KINDLE")
	countered = true
