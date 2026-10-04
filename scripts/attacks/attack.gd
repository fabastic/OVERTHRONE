extends Node3D
## Base for every boss skill. Each attack announces itself to the hero, decides what
## counter is "correct" for it (hero_counter), and reports at the end whether it landed
## or was countered so the hero can learn from it.

const Fx := preload("res://scripts/fx.gd")

var skill_id := ""
var damage := 10.0
var hero
var game
var color := Color.WHITE
var finished := false
var countered := false
var landed := false


func setup(p_skill: String, p_damage: float, p_hero, p_game) -> void:
	skill_id = p_skill
	damage = p_damage
	hero = p_hero
	game = p_game
	color = GameState.SKILLS[p_skill]["color"]


## Called once the attack has been positioned in the world.
func launch() -> void:
	pass


## Called by the hero, after his reaction delay, if he decided to respond.
func hero_counter(_h) -> void:
	pass


func hero_ok() -> bool:
	return is_instance_valid(hero) and not hero.dead


func notify_hero() -> void:
	if hero_ok():
		GameState.expose(skill_id)
		hero.notify_threat(self)


func hit_hero(dmg: float = -1.0) -> bool:
	if not hero_ok():
		return false
	var d := damage if dmg < 0.0 else dmg
	if GameState.eclipse_active:
		d *= 1.4
	if GameState.active_class == "rime" and (hero.slow_t > 0.0 or hero.stun_t > 0.0 or hero.root_t > 0.0):
		d *= 1.3
	if hero.take_hit(d, skill_id):
		landed = true
		Sfx.play("hit", -4.0)
		return true
	return false


func flat_dist_to_hero() -> float:
	if not hero_ok():
		return 999.0
	var hp: Vector3 = hero.global_position
	return Vector2(hp.x - global_position.x, hp.z - global_position.z).length()


func away_from_me(h) -> Vector3:
	var hp: Vector3 = h.global_position
	var away := Vector3(hp.x - global_position.x, 0, hp.z - global_position.z)
	if away.length() < 0.1:
		away = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	return away.normalized()


## Push him out of a circle of radius r around this attack (used by every "roll out" counter).
func roll_out(h, r: float, label: String) -> bool:
	var d := flat_dist_to_hero()
	if d > r + 0.6:
		return false
	var away := away_from_me(h)
	var dist := r + 0.8 - d
	var hp: Vector3 = h.position
	var dest := hp + away * dist
	if absf(dest.x) > 6.3 or dest.z < -13.8 or dest.z > -2.0:
		away = -away  # Cornered: roll through instead.
		dist = r + 0.8 + d
	h.dash(away, dist, clampf(dist / 9.0, 0.2, 0.42))
	h.announce(label)
	countered = true
	return true


func finish() -> void:
	if finished:
		return
	finished = true
	GameState.learn(skill_id, landed, countered)
