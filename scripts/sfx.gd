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
