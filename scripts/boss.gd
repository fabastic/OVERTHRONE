extends Node3D
## You: a vast tyrant on the throne, seen in first person. Only your hands are visible, and they
## tell the story. At first they are corrupted: black-violet skin, red veins, thorns, an iron
## shackle with a broken chain, smoke, twitching claws. With every memory restored they purify:
## the skin warms, the veins turn gold then white, the thorns fall away, the shackle becomes a
## gold bracelet, claws become nails, smoke becomes light. (apply_purity, 0..1)
## The fingertips glow in the selected skill's color. A/D lean you along the dais.
##
## TICKS: clicks only QUEUE an action. On each 0.25s tick (driven by main or the overworld) the
## queued cast or parry resolves; cooldowns, the global cooldown and the parry window count ticks.
## WALKER: the same hands, by daylight. In walker mode the camera sits at eye height and WASD walks
## you through the city of Vael (overworld.gd handles collisions and casting).

const Fx := preload("res://scripts/fx.gd")
const R_REST := Vector3(0.4, -0.24, -0.55)
const L_REST := Vector3(-0.4, -0.24, -0.55)
const LEAN_LIMIT := 2.6
const HAND_SCALE := 1.75
const YAW_LIMIT := 0.95
const PITCH_MIN := -0.8
const PITCH_MAX := 0.25
const SENSITIVITY := 0.0025

# Which hand performs each skill: "r", "l" or "both".
const HAND_FOR := {
	"fireball": "r", "lance": "r", "lightning": "r", "volley": "r", "doom": "r", "rain": "r", "siphon": "r",
	"spikes": "l", "chains": "l", "well": "l", "pillar": "l", "bloom": "l", "maw": "l", "hex": "l", "ghouls": "l",
	"glacier": "r", "thunder": "r", "nullorb": "r", "sweep": "r", "grasp": "r", "masonry": "r",
	"cinder": "l", "bonecage": "l", "leech": "l", "stomp": "both",
	"slam": "both", "eclipse": "both", "meteor": "both", "wall": "both", "tide": "both", "timerend": "both", "hands": "both",
}
const PARRY_COOLDOWN := 0.9

var game
var head: Node3D
var cam: Camera3D
var yaw := 0.0
var pitch := -0.42
var lean_input := 0.0  # -1..1, set by main from A/D
var right_hand: Node3D
var left_hand: Node3D
var skin_mat: StandardMaterial3D
var orb_mat: StandardMaterial3D
var orb: MeshInstance3D
var orb_light: OmniLight3D
var gem_mat: StandardMaterial3D
var claw_mat: StandardMaterial3D
var vein_mat: StandardMaterial3D
var thorn_mat: StandardMaterial3D
var purity := 0.0
var hand_parts: Array = []  # per hand: {thorns, shackle, chain, bracelet, smoke, motes, tips, joints}
var anim_r := 0.0
var anim_l := 0.0
var anim_both := 0.0
var recoil := 0.0
var shake_amt := 0.0
var t := 0.0
var cooldowns := {}   # ticks left per skill
var selected := 0
# Parry: right-click raises a guard for a few ticks. Blows that land inside it hit a lesser part of you.
var parry_t := 0.0     # ticks the guard stays up
var parry_cd := 0.0    # ticks until you can parry again
var guard := 0.0
var gcd := 0
var queued_cast := ""
var queued_parry := false
var tick_flash := 0.0
# Walker (daytime) mode
var walker := false
var ow                 # the overworld, when walking
var move_input := Vector2.ZERO
var sprint := false
var walk_t := 0.0
var vel := Vector3.ZERO


func _ready() -> void:
	head = Node3D.new()
	head.position = Vector3(0, 1.65, 0) if walker else Vector3(0, 3.5, 1.0)
	add_child(head)
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.02
	cam.far = 80.0
	head.add_child(cam)
	cam.current = true

	skin_mat = Fx.mat(Color(0.42, 0.37, 0.5))
	skin_mat.emission_enabled = true
	skin_mat.emission_energy_multiplier = 0.25
	claw_mat = Fx.mat(Color(0.08, 0.05, 0.07), 1.0)
	vein_mat = Fx.mat(Color(1.0, 0.1, 0.15), 2.5)
	thorn_mat = Fx.mat(Color(0.06, 0.03, 0.06))

	right_hand = _make_hand(1.0)
	right_hand.position = R_REST
	right_hand.rotation = Vector3(0.45, 0.25, -0.35)
	right_hand.scale = Vector3.ONE * HAND_SCALE
	cam.add_child(right_hand)
	left_hand = _make_hand(-1.0)
	left_hand.position = L_REST
	left_hand.rotation = Vector3(0.45, -0.25, 0.35)
	left_hand.scale = Vector3.ONE * HAND_SCALE
	cam.add_child(left_hand)

	# An invisible marker between the right fingertips: projectiles launch from here.
	orb_mat = Fx.mat(Color.WHITE, 1.0)
	orb = Fx.sphere(0.028, orb_mat, Vector3(0, 0.02, -0.17))
	orb.visible = false
	right_hand.add_child(orb)
	orb_light = OmniLight3D.new()
	orb_light.omni_range = 2.5
	orb_light.light_energy = 1.2
	orb_light.position = Vector3(0, 0.12, -0.15)
	right_hand.add_child(orb_light)

	# Left hand: a crooked wand with a gem.
	var wand := Node3D.new()
	wand.position = Vector3(0.02, 0.03, -0.05)
	wand.rotation = Vector3(-0.9, 0.2, 0)
	left_hand.add_child(wand)
	var wood := Fx.mat(Color(0.25, 0.15, 0.1))
	wand.add_child(Fx.cylinder(0.01, 0.016, 0.3, wood, Vector3(0, 0.12, 0)))
	var tip := Fx.cylinder(0.008, 0.01, 0.12, wood, Vector3(0.025, 0.31, 0))
	tip.rotation.z = -0.4
	wand.add_child(tip)
	gem_mat = Fx.mat(Color.WHITE, 5.0)
	wand.add_child(Fx.box(Vector3.ONE * 0.035, gem_mat, Vector3(0.05, 0.37, 0)))
	apply_purity(GameState.purity())


func _make_hand(side: float) -> Node3D:
	var h := Node3D.new()
	var parts := {"thorns": [], "tips": [], "joints": []}
	var iron := Fx.mat(Color(0.22, 0.2, 0.24))
	var gold := Fx.mat(Color(0.85, 0.65, 0.2), 0.6)
	# Forearm, with veins running down it
	h.add_child(Fx.box(Vector3(0.1, 0.09, 0.45), skin_mat, Vector3(0, -0.01, 0.28)))
	for k in 3:
		var v := Fx.box(Vector3(0.008, 0.006, 0.16), vein_mat, Vector3(-0.03 + k * 0.03, 0.036, 0.3 + (k % 2) * 0.05))
		v.rotation.y = (k - 1) * 0.25
		h.add_child(v)
	# Thorns breaking through the skin (corruption)
	for k in 5:
		var th := Fx.cylinder(0.0, 0.012, 0.05 + (k % 3) * 0.015, thorn_mat, Vector3(side * 0.045 * (1 if k % 2 == 0 else -0.6), 0.05, 0.18 + k * 0.07))
		th.rotation.z = -side * 0.5 * (1 if k % 2 == 0 else -1)
		h.add_child(th)
		parts["thorns"].append(th)
	# Iron shackle with a broken chain (corruption) / gold bracelet (purity)
	var shackle := Node3D.new()
	shackle.position = Vector3(0, -0.01, 0.12)
	h.add_child(shackle)
	shackle.add_child(Fx.box(Vector3(0.13, 0.12, 0.07), iron))
	var chain := Node3D.new()
	shackle.add_child(chain)
	for k in 3:
		chain.add_child(Fx.box(Vector3(0.02 if k % 2 == 0 else 0.008, 0.035, 0.02), iron, Vector3(0, -0.07 - k * 0.03, 0)))
	var bracelet := Node3D.new()
	bracelet.position = Vector3(0, -0.01, 0.13)
	h.add_child(bracelet)
	bracelet.add_child(Fx.box(Vector3(0.115, 0.105, 0.035), gold))
	bracelet.add_child(Fx.box(Vector3.ONE * 0.022, Fx.mat(Color(1.0, 0.9, 0.5), 5.0), Vector3(0, 0.06, 0)))
	# Hand: palm, veins on the back of the hand, knuckles
	h.add_child(Fx.box(Vector3(0.14, 0.045, 0.14), skin_mat))
	for k in 3:
		var v2 := Fx.box(Vector3(0.006, 0.005, 0.09), vein_mat, Vector3(-0.035 + k * 0.035, 0.024, 0.0))
		v2.rotation.y = (k - 1) * 0.3
		h.add_child(v2)
	# Fingers in two segments, so they can curl and twitch
	for i in 4:
		var x := -0.05 + i * 0.033
		h.add_child(Fx.box(Vector3(0.028, 0.02, 0.022), skin_mat, Vector3(x, 0.022, -0.06)))
		var finger := Node3D.new()
		finger.position = Vector3(x, 0, -0.07)
		finger.rotation.x = -0.3
		finger.rotation.y = (i - 1.5) * 0.06
		finger.add_child(Fx.box(Vector3(0.026, 0.026, 0.055), skin_mat, Vector3(0, 0, -0.027)))
		var joint := Node3D.new()
		joint.position = Vector3(0, 0, -0.055)
		joint.rotation.x = -0.35
		finger.add_child(joint)
		joint.add_child(Fx.box(Vector3(0.022, 0.022, 0.05), skin_mat, Vector3(0, 0, -0.025)))
		var tip := Node3D.new()
		tip.position = Vector3(0, -0.004, -0.05)
		joint.add_child(tip)
		tip.add_child(Fx.box(Vector3(0.017, 0.016, 0.05), claw_mat, Vector3(0, 0, -0.022)))
		h.add_child(finger)
		parts["joints"].append(joint)
		parts["tips"].append(tip)
	var thumb := Node3D.new()
	thumb.position = Vector3(-side * 0.075, -0.005, -0.01)
	thumb.rotation.y = side * 0.7
	thumb.add_child(Fx.box(Vector3(0.028, 0.028, 0.08), skin_mat, Vector3(0, 0, -0.04)))
	var ttip := Node3D.new()
	ttip.position = Vector3(0, -0.004, -0.08)
	thumb.add_child(ttip)
	ttip.add_child(Fx.box(Vector3(0.02, 0.02, 0.04), claw_mat, Vector3(0, 0, -0.018)))
	parts["tips"].append(ttip)
	h.add_child(thumb)
	# Smoke rising off a corrupted arm; motes of light around a pure one
	var smoke := Fx.particles(Color(0.12, 0.04, 0.14), 18, 1.2, 0.25, 0.04)
	smoke.gravity = Vector3(0, 0.4, 0)
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	smoke.emission_box_extents = Vector3(0.05, 0.03, 0.2)
	smoke.position = Vector3(0, 0.04, 0.25)
	(smoke.mesh as BoxMesh).material = Fx.mat(Color(0.1, 0.03, 0.12), 0.0, 0.7)
	h.add_child(smoke)
	var motes := Fx.particles(Color(1.0, 0.9, 0.55), 14, 1.4, 0.15, 0.025)
	motes.gravity = Vector3(0, 0.25, 0)
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(0.08, 0.05, 0.25)
	motes.position = Vector3(0, 0.05, 0.15)
	h.add_child(motes)
	parts["shackle"] = shackle
	parts["chain"] = chain
	parts["bracelet"] = bracelet
	parts["smoke"] = smoke
	parts["motes"] = motes
	hand_parts.append(parts)
	return h


## 0 = corrupted, 1 = enlightened. Called when memories are restored.
func apply_purity(p: float) -> void:
	purity = clampf(p, 0.0, 1.0)
	skin_mat.albedo_color = Color(0.16, 0.08, 0.2).lerp(Color(0.92, 0.82, 0.72), purity)
	skin_mat.emission = Color(0.3, 0.0, 0.1).lerp(Color(1.0, 0.85, 0.6), purity)
	skin_mat.emission_energy_multiplier = 0.15 + 0.25 * purity
	var vc := Color(1.0, 0.1, 0.15).lerp(Color(1.0, 0.75, 0.25), clampf(purity * 2.0, 0.0, 1.0))
	vc = vc.lerp(Color(1.0, 0.98, 0.9), clampf(purity * 2.0 - 1.0, 0.0, 1.0))
	vein_mat.albedo_color = vc
	vein_mat.emission = vc
	vein_mat.emission_energy_multiplier = 2.5 + purity * 2.0
	for parts in hand_parts:
		var thorns: Array = parts["thorns"]
		var keep := roundi((1.0 - purity) * thorns.size())
		for k in thorns.size():
			(thorns[k] as Node3D).visible = k < keep
		(parts["chain"] as Node3D).visible = purity < 0.17
		(parts["shackle"] as Node3D).visible = purity < 0.5
		(parts["bracelet"] as Node3D).visible = purity >= 0.5
		(parts["smoke"] as CPUParticles3D).emitting = purity < 0.84
		(parts["motes"] as CPUParticles3D).emitting = purity >= 0.34
		for tip in parts["tips"]:
			(tip as Node3D).scale = Vector3(1, 1, lerpf(1.3, 0.45, purity))


# --- Aiming -------------------------------------------------------------------

func look(relative: Vector2) -> void:
	if walker:
		yaw = wrapf(yaw - relative.x * SENSITIVITY, -PI, PI)
		pitch = clampf(pitch - relative.y * SENSITIVITY, -1.2, 1.1)
		return
	yaw = clampf(yaw - relative.x * SENSITIVITY, -YAW_LIMIT, YAW_LIMIT)
	pitch = clampf(pitch - relative.y * SENSITIVITY, PITCH_MIN, PITCH_MAX)


## Used by autoplay: smoothly turn the head toward a world point.
func look_toward(p: Vector3, delta: float) -> void:
	var d := p - head.global_position
	var want_yaw := atan2(-d.x, -d.z)
	if not walker:
		want_yaw = clampf(want_yaw, -YAW_LIMIT, YAW_LIMIT)
	var want_pitch := clampf(atan2(d.y, Vector2(d.x, d.z).length()), PITCH_MIN, PITCH_MAX)
	var k := 1.0 - exp(-delta * 8.0)
	yaw = lerp_angle(yaw, want_yaw, k)
	pitch = lerpf(pitch, want_pitch, k)


## Where the crosshair points: the hero if the ray passes close to him, else the floor.
func aim_point(hero) -> Vector3:
	var origin := cam.global_position
	var dir := -cam.global_transform.basis.z
	if is_instance_valid(hero) and not hero.dead:
		var hc: Vector3 = hero.center()
		var along := (hc - origin).dot(dir)
		if along > 0.0 and (origin + dir * along).distance_to(hc) < 1.0:
			return hc
	if dir.y < -0.01:
		return origin + dir * minf(-origin.y / dir.y, 40.0)
	return origin + dir * 30.0


func hand_tip() -> Vector3:
	return orb.global_position


# --- Casting ------------------------------------------------------------------

func selected_id() -> String:
	if GameState.loadout.is_empty():
		return ""
	selected = clampi(selected, 0, GameState.loadout.size() - 1)
	return GameState.loadout[selected]


func select(i: int) -> void:
	if i >= 0 and i < GameState.loadout.size():
		selected = i


func cycle(step: int) -> void:
	var n := GameState.loadout.size()
	if n > 0:
		selected = posmod(selected + step, n)


func cooldown_left(id: String) -> float:
	return cooldowns.get(id, 0) * GameState.TICK


func cooldown_frac(id: String) -> float:
	return clampf(float(cooldowns.get(id, 0)) / GameState.cooldown_ticks(id), 0.0, 1.0)


## Clicking only queues the cast; it happens on the next tick (see on_tick_begin). Mashing does nothing.
func try_cast(id: String) -> bool:
	if id == "" or cooldowns.get(id, 0) > 0:
		return false
	queued_cast = id
	return true


func try_parry() -> bool:
	if parry_cd > 0:
		return false
	queued_parry = true
	return true


## Start of a tick: resolve whatever was queued since the last one.
func on_tick_begin() -> void:
	tick_flash = 1.0
	if queued_parry and parry_cd <= 0:
		parry_t = GameState.parry_ticks()
		parry_cd = GameState.parry_cd_ticks() + parry_t
	queued_parry = false
	if queued_cast != "" and gcd <= 0:
		var id := queued_cast
		queued_cast = ""
		if cooldowns.get(id, 0) <= 0:
			_cast_now(id)


## End of a tick: everything counts down by one.
func on_tick_end() -> void:
	parry_t = maxf(0.0, parry_t - 1)
	parry_cd = maxf(0.0, parry_cd - 1)
	gcd = maxi(0, gcd - 1)
	for id in cooldowns.keys():
		cooldowns[id] = maxi(0, cooldowns[id] - 1)


func _cast_now(id: String) -> void:
	var ok: bool = ow.spawn_day_attack(id) if walker else game.spawn_attack(id)
	if not ok:
		return
	GameState.on_cast(id)
	cooldowns[id] = GameState.cooldown_ticks(id)
	gcd = GameState.GCD_TICKS
	if GameState.perks.has("echo") and randf() < 0.15 * GameState.asc_mult():
		cooldowns[id] = 0
		game.popup_text(hand_tip() + Vector3(0, 0.3, -1.0), "ECHO", Color(0.8, 0.7, 1.0), 0.8)
	match HAND_FOR.get(id, "r"):
		"r":
			anim_r = 1.0
		"l":
			anim_l = 1.0
		_:
			anim_both = 1.0


func reset_cooldowns() -> void:
	cooldowns.clear()
	if not walker:
		position.x = 0.0
	parry_t = 0.0
	parry_cd = 0.0
	gcd = 0
	queued_cast = ""
	queued_parry = false


func is_parrying() -> bool:
	return parry_t > 0.0


func parry_cd_frac() -> float:
	return clampf(parry_cd / float(GameState.parry_cd_ticks() + GameState.parry_ticks()), 0.0, 1.0)


## A successful parry: hands clash, sparks, a small kick.
func parried() -> void:
	guard = 1.0
	shake(0.25)


func shake(amount: float) -> void:
	shake_amt = maxf(shake_amt, amount)


func hurt() -> void:
	recoil = 1.0
	shake(0.5)


# --- Per-frame ----------------------------------------------------------------

func _process(delta: float) -> void:
	t += delta
	tick_flash = maxf(0.0, tick_flash - delta * 5.0)

	if walker:
		_walk(delta)
	else:
		# Lean along the dais.
		position.x = clampf(position.x + lean_input * GameState.lean_speed() * delta, -GameState.lean_limit(), GameState.lean_limit())
	head.rotation.y = yaw
	head.rotation.z = lerpf(head.rotation.z, -lean_input * 0.06, 1.0 - exp(-delta * 8.0))
	cam.rotation.x = pitch
	shake_amt = maxf(0.0, shake_amt - delta * 1.5)
	cam.h_offset = randf_range(-1.0, 1.0) * shake_amt * 0.06
	cam.v_offset = randf_range(-1.0, 1.0) * shake_amt * 0.06

	anim_r = maxf(0.0, anim_r - delta * 4.0)
	anim_l = maxf(0.0, anim_l - delta * 4.0)
	anim_both = maxf(0.0, anim_both - delta * 3.0)
	recoil = maxf(0.0, recoil - delta * 3.0)

	var bob := Vector3(0, sin(t * 1.7) * 0.008, 0)
	if walker:
		bob += Vector3(sin(walk_t * 0.5) * 0.012, absf(sin(walk_t)) * 0.02, 0)
	var thrust_r := Vector3(0, 0.03, -0.22) * _ease(anim_r)
	var thrust_l := Vector3(0, 0.05, -0.2) * _ease(anim_l)
	# Both-hands skills: raise, then slam down.
	var both := Vector3(0, sin(anim_both * PI) * 0.18 - _ease(anim_both) * 0.1, -0.1 * _ease(anim_both))
	var flinch := Vector3(0, -0.12, 0.12) * recoil
	# Guard: both hands sweep in and up across your face while the parry window is open.
	var g := 1.0 if parry_t > 0.0 else 0.0
	guard = maxf(guard - delta * 4.0, g)
	var guard_r := Vector3(-0.2, 0.14, -0.05) * _ease(clampf(guard, 0.0, 1.0))
	var guard_l := Vector3(0.2, 0.14, -0.05) * _ease(clampf(guard, 0.0, 1.0))
	right_hand.position = R_REST + bob + thrust_r + both + flinch + guard_r
	left_hand.position = L_REST + bob * 0.8 + thrust_l + both + flinch + guard_l

	var id := selected_id()
	var col: Color = GameState.SKILLS[id]["color"] if id != "" else Color.WHITE
	var ready := id != "" and cooldown_left(id) <= 0.0
	var pulse := 0.8 + sin(t * 6.0) * 0.2
	orb_mat.albedo_color = col
	orb_mat.emission = col
	orb_mat.emission_energy_multiplier = (1.4 if ready else 0.4) * pulse
	claw_mat.emission = col
	claw_mat.emission_energy_multiplier = (2.5 if ready else 0.4) * pulse
	# Corrupted fingers twitch and clench; pure ones rest.
	var unrest := 1.0 - purity
	for hi in hand_parts.size():
		var joints: Array = hand_parts[hi]["joints"]
		for j in joints.size():
			var tw := sin(t * (7.0 + j * 1.7 + hi) + j) * 0.18 * unrest
			if unrest > 0.3 and randf() < 0.004 * unrest:
				tw -= 0.5
			(joints[j] as Node3D).rotation.x = -0.35 + tw - _ease(anim_r if hi == 0 else anim_l) * 0.4
	orb_light.light_color = col
	orb_light.light_energy = (0.8 if ready else 0.25) * pulse
	gem_mat.albedo_color = col
	gem_mat.emission = col
	skin_mat.emission = (Color(0.3, 0.0, 0.1).lerp(Color(1.0, 0.85, 0.6), purity)).lerp(col, 0.2)


## Daytime: walk the streets of Vael. The overworld resolves collisions.
func _walk(delta: float) -> void:
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var want := (fwd * move_input.y + right * move_input.x)
	if want.length() > 1.0:
		want = want.normalized()
	var spd := 8.0 if sprint else 5.0
	vel = vel.lerp(want * spd, 1.0 - exp(-delta * 10.0))
	var np := position + vel * delta
	if ow:
		np = ow.resolve(position, np, 0.4)
	position = np
	var moving := Vector2(vel.x, vel.z).length()
	walk_t += delta * moving * 2.2
	head.position.y = 1.65 + absf(sin(walk_t)) * 0.05 * minf(1.0, moving / 5.0)


func _ease(a: float) -> float:
	return a * a * (3.0 - 2.0 * a)
