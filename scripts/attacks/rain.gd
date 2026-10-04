extends "res://scripts/attacks/attack.gd"
## Crimson Rain: a storm of small telegraphed drops around him over two seconds.
## Each drop is its own zone he has to WEAVE out of.

const ZoneScript := preload("res://scripts/attacks/zone.gd")

var drops := 7
var interval := 0.26
var t := 0.0
var spawned := 0


func _physics_process(delta: float) -> void:
	t += delta
	while spawned < drops and t >= spawned * interval:
		spawned += 1
		if not hero_ok():
			continue
		var z = ZoneScript.new()
		z.setup(skill_id, damage, hero, game)
		z.radius = 0.95
		z.delay = 0.6
		z.style = "drop"
		z.counter_label = "WEAVE"
		z.add_to_group("attacks")
		get_parent().add_child(z)
		var hp: Vector3 = hero.global_position
		var off := Vector2.from_angle(randf() * TAU) * randf_range(0.0, 1.3)
		z.global_position = game.clamp_arena(Vector3(hp.x + off.x, 0, hp.z + off.y))
		z.launch()
	if spawned >= drops:
		finish()
		queue_free()
