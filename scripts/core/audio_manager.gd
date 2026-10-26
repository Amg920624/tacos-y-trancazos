extends Node
## Autoload "AudioManager": every sound is synthesized at startup, so no audio file can be missing.
## Optional override: put res://assets/audio/<name>.ogg (or .wav) and it replaces the synth version.
## Music (cumbia-style loops for day and night) is generated on a worker thread.

const RATE := 22050
const MUSIC_RATE := 16000
const SETTINGS_PATH := "user://settings.cfg"
const MUSIC_DB := -10.0

var sfx: Dictionary = {}
var music: Dictionary = {}
var players: Array = []
var music_player: AudioStreamPlayer
var muted := false
var current_music := ""
var _wanted_music := ""
var _music_task := -1
var _music_bytes: Dictionary = {}
var _noise := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_noise.seed = 1337
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = MUSIC_DB
	add_child(music_player)
	_load_settings()
	_build_sfx()
	if DisplayServer.get_name() != "headless":
		_music_task = WorkerThreadPool.add_task(_build_music_threaded)


func _process(_delta: float) -> void:
	if _music_task >= 0 and WorkerThreadPool.is_task_completed(_music_task):
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1
		for key in _music_bytes.keys():
			music[key] = _bytes_to_wav(_music_bytes[key], MUSIC_RATE, true)
		_music_bytes.clear()
		if _wanted_music != "":
			var w := _wanted_music
			current_music = ""
			play_music(w)


# ---------------------------------------------------------------- public API

func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	if muted:
		return
	var s: AudioStream = sfx.get(sound)
	if s == null:
		return
	var player: AudioStreamPlayer = players[0]
	for p in players:
		if not p.playing:
			player = p
			break
	player.stream = s
	player.volume_db = volume_db
	player.pitch_scale = clampf(pitch, 0.5, 2.0)
	player.play()


func play_music(kind: String) -> void:
	_wanted_music = kind
	if kind == current_music and music_player.playing:
		return
	var override := _override_stream("music_" + kind)
	var stream: AudioStream = override if override else music.get(kind)
	if stream == null:
		return  # Still generating (or headless); it will start when ready.
	current_music = kind
	music_player.stream = stream
	if not muted:
		music_player.play()


func stop_music() -> void:
	_wanted_music = ""
	current_music = ""
	music_player.stop()


func set_muted(value: bool) -> void:
	muted = value
	AudioServer.set_bus_mute(0, muted)
	if muted:
		music_player.stop()
	elif _wanted_music != "":
		current_music = ""
		play_music(_wanted_music)
	_save_settings()


func toggle_mute() -> void:
	set_muted(not muted)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("mute"):
		toggle_mute()


# ---------------------------------------------------------------- settings

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		muted = bool(cfg.get_value("audio", "muted", false))
	AudioServer.set_bus_mute(0, muted)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("audio", "muted", muted)
	cfg.save(SETTINGS_PATH)


func _override_stream(sound: String) -> AudioStream:
	for ext in [".ogg", ".wav"]:
		var path: String = "res://assets/audio/" + sound + ext
		if ResourceLoader.exists(path):
			var res = load(path)
			if res is AudioStream:
				return res
	return null


# ---------------------------------------------------------------- synthesis

func _buf(sec: float, rate := RATE) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * rate))
	return b


func _osc(wave: String, phase: float, rng: RandomNumberGenerator) -> float:
	var p := fmod(phase, 1.0)
	match wave:
		"square":
			return 1.0 if p < 0.5 else -1.0
		"tri":
			return 4.0 * absf(p - 0.5) - 1.0
		"saw":
			return 2.0 * p - 1.0
		"noise":
			return rng.randf_range(-1.0, 1.0)
	return sin(TAU * phase)


func _tone(buf: PackedFloat32Array, start: float, dur: float, f0: float, f1: float, vol: float,
		wave := "sine", decay := 4.0, rate := RATE, rng: RandomNumberGenerator = null) -> void:
	if rng == null:
		rng = _noise
	var n0 := int(start * rate)
	var n := int(dur * rate)
	var phase := 0.0
	var attack := 0.004 * rate
	for i in n:
		var idx := n0 + i
		if idx >= buf.size():
			break
		var t := float(i) / n
		phase += lerpf(f0, f1, t) / rate
		var env := exp(-decay * t) * minf(1.0, i / attack) * minf(1.0, (n - i) / attack)
		buf[idx] += _osc(wave, phase, rng) * vol * env


func _bytes(buf: PackedFloat32Array, normalize := false) -> PackedByteArray:
	var peak := 1.0
	if normalize:
		peak = 0.001
		for v in buf:
			peak = maxf(peak, absf(v))
		peak /= 0.8
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i] / peak, -1.0, 1.0) * 32000.0))
	return data


func _bytes_to_wav(data: PackedByteArray, rate: int, loop := false) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = data.size() / 2
	return w


func _store(sound: String, buf: PackedFloat32Array) -> void:
	var override := _override_stream(sound)
	sfx[sound] = override if override else _bytes_to_wav(_bytes(buf), RATE)


func _build_sfx() -> void:
	var b := _buf(0.16)
	_tone(b, 0.0, 0.06, 660, 660, 0.25, "square", 3)
	_tone(b, 0.06, 0.09, 880, 880, 0.25, "square", 3)
	_store("order", b)

	b = _buf(0.1)
	_tone(b, 0.0, 0.05, 0, 0, 0.5, "noise", 10)
	_tone(b, 0.0, 0.07, 180, 90, 0.4, "sine", 6)
	_store("chop", b)

	b = _buf(0.45)
	_tone(b, 0.0, 0.03, 0, 0, 0.4, "noise", 20)
	_tone(b, 0.03, 0.35, 1760, 1760, 0.3, "sine", 6)
	_tone(b, 0.08, 0.32, 2637, 2637, 0.25, "sine", 6)
	_store("cash", b)

	b = _buf(0.3)
	var arp := [523.0, 659.0, 784.0, 1047.0]
	for i in arp.size():
		_tone(b, i * 0.055, 0.08, arp[i], arp[i], 0.16, "square", 2)
	_store("aura", b)

	b = _buf(0.35)
	_tone(b, 0.0, 0.3, 1319, 1319, 0.3, "sine", 5)
	_tone(b, 0.05, 0.28, 1976, 1976, 0.2, "sine", 5)
	_store("perfect", b)

	b = _buf(0.42)
	_tone(b, 0.0, 0.4, 330, 140, 0.22, "square", 1.5)
	_store("fail", b)

	b = _buf(0.75)
	for k in 2:
		_tone(b, k * 0.17, 0.5, 2093, 2093, 0.28, "sine", 7)
		_tone(b, k * 0.17, 0.5, 2637, 2637, 0.18, "sine", 7)
	_store("bell", b)

	b = _buf(0.16)
	_tone(b, 0.0, 0.15, 0, 0, 0.3, "noise", 3)
	_tone(b, 0.0, 0.12, 500, 200, 0.12, "tri", 3)
	_store("attack", b)

	b = _buf(0.18)
	_tone(b, 0.0, 0.16, 140, 55, 0.6, "sine", 6)
	_tone(b, 0.0, 0.05, 0, 0, 0.3, "noise", 15)
	_store("hit", b)

	b = _buf(0.26)
	_tone(b, 0.0, 0.12, 440, 660, 0.22, "sine", 3)
	_tone(b, 0.1, 0.14, 660, 880, 0.22, "sine", 3)
	_store("happy", b)

	b = _buf(0.32)
	_tone(b, 0.0, 0.3, 170, 120, 0.2, "square", 2)
	_store("angry", b)

	b = _buf(1.0)
	var fan := [523.0, 659.0, 784.0, 1047.0]
	for i in fan.size():
		_tone(b, i * 0.12, 0.5 if i == 3 else 0.14, fan[i], fan[i], 0.17, "square", 2)
	_store("shift_end", b)

	b = _buf(0.65)
	var n := int(0.6 * RATE)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		ph += (2800.0 + 140.0 * sin(TAU * 32.0 * t)) / RATE
		b[i] += sin(TAU * ph) * 0.22 * minf(1.0, i / 80.0) * minf(1.0, (n - i) / 400.0)
	_store("whistle", b)

	b = _buf(0.36)
	_tone(b, 0.0, 0.35, 0, 0, 0.12, "noise", 2)
	_store("sizzle", b)

	b = _buf(0.22)
	_tone(b, 0.0, 0.2, 300, 900, 0.28, "sine", 2)
	_store("pina", b)

	b = _buf(0.3)
	_tone(b, 0.0, 0.26, 392, 392, 0.14, "square", 0.5)
	_tone(b, 0.0, 0.26, 494, 494, 0.11, "square", 0.5)
	_store("honk", b)

	b = _buf(0.05)
	_tone(b, 0.0, 0.035, 990, 990, 0.12, "square", 5)
	_store("ui_move", b)

	b = _buf(0.12)
	_tone(b, 0.0, 0.045, 660, 660, 0.15, "square", 3)
	_tone(b, 0.045, 0.06, 990, 990, 0.15, "square", 3)
	_store("ui_ok", b)

	b = _buf(0.9)
	var ach := [784.0, 988.0, 1175.0, 1568.0]
	for i in ach.size():
		_tone(b, i * 0.08, 0.5 if i == 3 else 0.1, ach[i], ach[i], 0.25, "tri", 2)
	_store("achievement", b)

	b = _buf(0.14)
	_tone(b, 0.0, 0.08, 0, 0, 0.2, "noise", 4)
	_tone(b, 0.0, 0.12, 620, 300, 0.15, "sine", 3)
	_store("throw", b)

	b = _buf(0.16)
	_tone(b, 0.0, 0.12, 1250, 900, 0.12, "square", 8)
	_tone(b, 0.0, 0.04, 0, 0, 0.2, "noise", 12)
	_store("can", b)

	b = _buf(0.4)
	_tone(b, 0.0, 0.12, 430, 300, 0.25, "square", 3)
	_tone(b, 0.18, 0.12, 430, 300, 0.25, "square", 3)
	_store("dog", b)


# ---------------------------------------------------------------- music (worker thread)

func _build_music_threaded() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var out := {}
	out["day"] = _bytes(_compose(false, rng), true)
	out["night"] = _bytes(_compose(true, rng), true)
	_music_bytes = out


func _midi(n: float) -> float:
	return 440.0 * pow(2.0, (n - 69.0) / 12.0)


## A little cumbia: bass on 1 and 3 with fifth pickups, güiro scrapes, cencerro and a marimba/accordion line.
func _compose(night: bool, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var bpm := 92.0 if night else 100.0
	var beat := 60.0 / bpm
	var bars := 8
	var rate := MUSIC_RATE
	var buf := _buf(bars * 4 * beat, rate)
	# Chords as MIDI roots plus triad quality.
	var prog: Array
	if night:
		prog = [[57, "m"], [57, "m"], [52, "M"], [52, "M"], [50, "m"], [50, "m"], [52, "M"], [57, "m"]]
	else:
		prog = [[48, "M"], [48, "M"], [55, "M"], [55, "M"], [53, "M"], [53, "M"], [55, "M"], [48, "M"]]
	var rhythm := [0.0, 0.75, 1.5, 2.0, 2.75, 3.5]
	var contour := [0, 1, 2, 1, 2, 3, 2, 0, 1, 2, 3, 4, 3, 2, 1, 0]
	var ci := 0
	for bar in bars:
		var t0 := bar * 4 * beat
		var root: int = prog[bar][0]
		var third := 3 if prog[bar][1] == "m" else 4
		var triad := [0, third, 7, 12, 12 + third]
		var bass_root := root - 12 if root > 50 else root
		# Bass
		_tone(buf, t0, beat * 0.9, _midi(bass_root), _midi(bass_root), 0.42, "tri", 2.5, rate, rng)
		_tone(buf, t0 + beat * 1.5, beat * 0.45, _midi(bass_root + 7), _midi(bass_root + 7), 0.32, "tri", 3, rate, rng)
		_tone(buf, t0 + beat * 2.0, beat * 0.9, _midi(bass_root), _midi(bass_root), 0.42, "tri", 2.5, rate, rng)
		_tone(buf, t0 + beat * 3.5, beat * 0.45, _midi(bass_root + 7), _midi(bass_root + 7), 0.32, "tri", 3, rate, rng)
		for bt in 4:
			var tb := t0 + bt * beat
			# Kick-ish thump on 1 and 3
			if bt % 2 == 0:
				_tone(buf, tb, 0.12, 95, 50, 0.45, "sine", 5, rate, rng)
			# Güiro: long scrape + two short ones
			_tone(buf, tb, beat * 0.32, 0, 0, 0.07, "noise", 1.2, rate, rng)
			_tone(buf, tb + beat * 0.5, beat * 0.12, 0, 0, 0.06, "noise", 3, rate, rng)
			_tone(buf, tb + beat * 0.75, beat * 0.12, 0, 0, 0.06, "noise", 3, rate, rng)
			# Cencerro on the off-beat
			_tone(buf, tb + beat * 0.5, 0.07, 800, 800, 0.05, "square", 9, rate, rng)
		# Melody
		var wave := "tri" if night else "sine"
		for r in rhythm:
			if rng.randf() < 0.12:
				ci += 1
				continue
			var step: int = contour[ci % contour.size()]
			ci += 1
			var note: int = root + 12 + triad[step % triad.size()]
			var dur := beat * (0.7 if night else 0.45)
			var st := t0 + float(r) * beat
			_tone(buf, st, dur, _midi(note), _midi(note), 0.2, wave, 3.5 if not night else 2.0, rate, rng)
			_tone(buf, st, dur * 0.6, _midi(note + 12), _midi(note + 12), 0.05, "sine", 6, rate, rng)
			if night:
				_tone(buf, st + beat * 0.5, dur, _midi(note), _midi(note), 0.07, wave, 3, rate, rng)
	return buf
