extends Node
## Procedural sound effects: every sound is synthesized in code into an AudioStreamWAV,
## so the prototype needs no audio files. Sfx.play("coin").

const RATE := 22050

var streams := {}
var players: Array[AudioStreamPlayer] = []
var next_player := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 16:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	# Each sound: a list of segments [freq_start, freq_end, seconds, wave, volume, noise]
	streams["cast"] = _make([[220, 660, 0.1, "saw", 0.25, 0.25]])
	streams["hit"] = _make([[160, 60, 0.12, "square", 0.35, 0.5]])
	streams["boss_hurt"] = _make([[90, 35, 0.35, "sine", 0.9, 0.35]])
	streams["parry"] = _make([[1900, 1700, 0.05, "square", 0.35, 0.6], [2600, 2500, 0.3, "sine", 0.5, 0.0]])
	streams["dodge"] = _make([[500, 900, 0.08, "sine", 0.12, 0.6]])
	streams["death"] = _make([[440, 70, 0.6, "square", 0.35, 0.1]])
	streams["slam"] = _make([[70, 30, 0.45, "sine", 0.9, 0.6]])
	streams["coin"] = _make([[1320, 1320, 0.05, "square", 0.25, 0.0], [1760, 1760, 0.12, "square", 0.25, 0.0]])
	streams["levelup"] = _make([[523, 523, 0.08, "square", 0.3, 0.0], [659, 659, 0.08, "square", 0.3, 0.0],
		[784, 784, 0.08, "square", 0.3, 0.0], [1046, 1046, 0.3, "square", 0.3, 0.0]])
	streams["crown"] = _make([[65, 40, 0.5, "sine", 1.0, 0.5], [523, 523, 0.12, "square", 0.25, 0.0], [784, 784, 0.4, "square", 0.25, 0.0]])
	streams["reveal"] = _make([[392, 392, 0.07, "square", 0.25, 0.0], [523, 523, 0.07, "square", 0.25, 0.0],
		[659, 659, 0.07, "square", 0.25, 0.0], [1046, 1318, 0.45, "sine", 0.35, 0.0]])
	streams["click"] = _make([[900, 700, 0.04, "square", 0.2, 0.0]])
	streams["deny"] = _make([[180, 140, 0.12, "square", 0.25, 0.0]])
	streams["learn"] = _make([[330, 220, 0.25, "saw", 0.25, 0.0], [220, 165, 0.3, "saw", 0.25, 0.0]])
	streams["hero_strike"] = _make([[300, 120, 0.1, "saw", 0.35, 0.4]])
	# Blades: a light whistle, a heavy whoosh, a crackling arc, a plasma hum
	streams["swing_light"] = _make([[900, 400, 0.13, "sine", 0.18, 0.75]])
	streams["swing_heavy"] = _make([[260, 90, 0.28, "sine", 0.35, 0.8]])
	streams["swing_arc"] = _make([[1400, 500, 0.12, "square", 0.12, 0.6], [2400, 1800, 0.08, "square", 0.08, 0.7]])
	streams["swing_plasma"] = _make([[180, 520, 0.22, "saw", 0.22, 0.25], [520, 300, 0.14, "sine", 0.2, 0.1]])
	# Moving through Vael
	streams["step"] = _make([[120, 80, 0.05, "sine", 0.3, 0.85]])
	streams["jump"] = _make([[220, 420, 0.1, "sine", 0.2, 0.4]])
	streams["land"] = _make([[110, 50, 0.14, "sine", 0.5, 0.7]])
	streams["roll"] = _make([[300, 120, 0.22, "sine", 0.22, 0.85]])
	streams["slide"] = _make([[500, 200, 0.45, "sine", 0.12, 0.92]])
	streams["splash"] = _make([[700, 150, 0.3, "sine", 0.25, 0.9]])
	# Chests and the forge
	streams["chest_shake"] = _make([[90, 70, 0.08, "square", 0.25, 0.6], [100, 80, 0.08, "square", 0.25, 0.6]])
	streams["chest_open"] = _make([[180, 260, 0.2, "saw", 0.2, 0.3], [784, 784, 0.06, "square", 0.2, 0.0], [1046, 1046, 0.2, "square", 0.2, 0.0]])
	streams["chest_legendary"] = _make([[523, 523, 0.09, "square", 0.25, 0.0], [659, 659, 0.09, "square", 0.25, 0.0], [784, 784, 0.09, "square", 0.25, 0.0],
		[1046, 1046, 0.09, "square", 0.25, 0.0], [1318, 1568, 0.6, "sine", 0.35, 0.0]])
	streams["forge"] = _make([[1800, 1700, 0.04, "square", 0.3, 0.5], [2200, 2100, 0.25, "sine", 0.3, 0.1]])
	# Menus
	streams["ui_hover"] = _make([[1500, 1500, 0.02, "square", 0.12, 0.0]])
	streams["menu_open"] = _make([[400, 800, 0.12, "sine", 0.25, 0.0]])
	streams["menu_close"] = _make([[800, 400, 0.12, "sine", 0.25, 0.0]])
	# Impacts
	streams["impact"] = _make([[140, 40, 0.25, "sine", 0.7, 0.55]])
	streams["block"] = _make([[2600, 2400, 0.04, "square", 0.3, 0.4], [1200, 1100, 0.2, "sine", 0.3, 0.0]])
	# One voice per school of magic (cast sounds)
	streams["fire"] = _make([[160, 420, 0.3, "saw", 0.22, 0.75]])
	streams["ice"] = _make([[2200, 2600, 0.06, "sine", 0.2, 0.2], [3000, 1800, 0.18, "sine", 0.2, 0.4]])
	streams["zap"] = _make([[3000, 600, 0.15, "square", 0.18, 0.55]])
	streams["bone"] = _make([[260, 180, 0.05, "square", 0.3, 0.7], [200, 120, 0.1, "square", 0.25, 0.7]])
	streams["void"] = _make([[80, 40, 0.5, "sine", 0.5, 0.15], [60, 30, 0.3, "saw", 0.2, 0.0]])
	streams["blood"] = _make([[200, 90, 0.25, "sine", 0.35, 0.5]])
	streams["quake"] = _make([[55, 30, 0.5, "sine", 0.8, 0.6]])


## The voice of each school of magic, played as the spell leaves your hand.
const SCHOOL := {"HELLFIRE": "fire", "BONE": "bone", "RIME": "ice", "STORM": "zap", "VOID": "void", "BLOOD": "blood", "WARLORD": "quake"}


func cast_school(school: String) -> void:
	play(SCHOOL.get(school, "cast"), -6.0, randf_range(0.9, 1.15))


func play(sound: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not streams.has(sound):
		return
	var p := players[next_player]
	next_player = (next_player + 1) % players.size()
	p.stream = streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = pitch * randf_range(0.97, 1.03)
	p.play()


func _make(segments: Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	var phase := 0.0
	for seg in segments:
		var f0: float = seg[0]
		var f1: float = seg[1]
		var dur: float = seg[2]
		var wave: String = seg[3]
		var vol: float = seg[4]
		var noise: float = seg[5]
		var n := int(dur * RATE)
		for i in n:
			var s := float(i) / n
			var f := lerpf(f0, f1, s)
			phase += f / RATE
			var x := 0.0
			match wave:
				"sine":
					x = sin(phase * TAU)
				"square":
					x = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
				"saw":
					x = fmod(phase, 1.0) * 2.0 - 1.0
			x = lerpf(x, randf_range(-1.0, 1.0), noise)
			# Quick attack, exponential-ish decay.
			var env := minf(1.0, s * 40.0) * pow(1.0 - s, 2.0)
			var v := int(clampf(x * env * vol, -1.0, 1.0) * 30000.0)
			data.append(v & 0xFF)
			data.append((v >> 8) & 0xFF)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
