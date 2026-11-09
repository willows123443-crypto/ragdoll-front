extends Node
# Sounds are generated at startup (no audio files needed) and played through a pool of 3D players.

const RATE = 22050
var s_shot: AudioStreamWAV
var s_boom: AudioStreamWAV
var s_whizz: AudioStreamWAV
var s_rico: AudioStreamWAV
var s_whistle: AudioStreamWAV
var s_step: AudioStreamWAV
var s_hit: AudioStreamWAV
var s_rocket: AudioStreamWAV
var players: Array = []
var pi = 0
var ui_player: AudioStreamPlayer

func _ready() -> void:
	var bus = AudioServer.bus_count
	AudioServer.add_bus(bus)
	AudioServer.set_bus_name(bus, "World")
	AudioServer.set_bus_send(bus, "Master")
	var rev = AudioEffectReverb.new()
	rev.room_size = 0.55
	rev.damping = 0.6
	rev.wet = 0.18
	rev.dry = 1.0
	AudioServer.add_bus_effect(bus, rev)
	s_shot = _noise(0.32, 0.055, 0.45, 2.2)
	s_boom = _noise(1.8, 0.35, 0.08, 1.0, 55.0)
	s_whizz = _noise(0.12, 0.03, 0.9, 1.0)
	s_rico = _sweep(2400.0, 800.0, 0.28, 0.25)
	s_whistle = _sweep(1400.0, 380.0, 1.15, 0.22)
	s_step = _noise(0.06, 0.02, 0.15, 1.0)
	s_hit = _sweep(1400.0, 1200.0, 0.05, 0.25)
	s_rocket = _noise(0.7, 0.25, 0.3, 1.0)
	for i in range(28):
		var p = AudioStreamPlayer3D.new()
		p.bus = "World"
		p.unit_size = 12.0
		p.max_distance = 260.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		players.append(p)
	ui_player = AudioStreamPlayer.new()
	add_child(ui_player)
	set_volume(G.settings["volume"])

func set_volume(v: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.001)))

func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data = PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

# decaying filtered noise; thump adds a low sine for punch
func _noise(len_s: float, decay: float, bright: float, punch: float, thump: float = 0.0) -> AudioStreamWAV:
	var n = int(len_s * RATE)
	var out = PackedFloat32Array()
	out.resize(n)
	var lp = 0.0
	for i in range(n):
		var t = float(i) / RATE
		var env = exp(-t / decay) * minf(1.0, t * 800.0)
		lp += (randf() * 2.0 - 1.0 - lp) * bright
		var v = lp * env * punch
		if thump > 0.0:
			v += sin(TAU * thump * t * (1.0 - t * 0.3)) * exp(-t / (decay * 1.5)) * 0.8
		out[i] = v
	return _wav(out)

func _sweep(f0: float, f1: float, len_s: float, vol: float) -> AudioStreamWAV:
	var n = int(len_s * RATE)
	var out = PackedFloat32Array()
	out.resize(n)
	var ph = 0.0
	for i in range(n):
		var k = float(i) / n
		var f = f0 * pow(f1 / f0, k)
		ph += TAU * f / RATE
		out[i] = sin(ph) * vol * (1.0 - k) * minf(1.0, k * 50.0)
	return _wav(out)

func play(stream: AudioStream, pos: Vector3, vol_db: float = 0.0, pitch: float = 1.0, delay: float = 0.0) -> void:
	if delay > 0.01:
		get_tree().create_timer(delay, false).timeout.connect(func(): play(stream, pos, vol_db, pitch, 0.0))
		return
	var p: AudioStreamPlayer3D = players[pi]
	pi = (pi + 1) % players.size()
	p.stream = stream
	p.global_position = pos
	p.volume_db = vol_db
	p.pitch_scale = pitch * randf_range(0.93, 1.07)
	p.play()

func cam_dist(pos: Vector3) -> float:
	var cam = get_viewport().get_camera_3d()
	return cam.global_position.distance_to(pos) if cam else 0.0

func shot(pos: Vector3, w: Dictionary) -> void:
	var d = cam_dist(pos)
	play(s_shot, pos, w["snd_vol"], w["snd_pitch"], minf(d / 343.0, 0.4))

func boom(pos: Vector3) -> void:
	play(s_boom, pos, 6.0, 1.0, minf(cam_dist(pos) / 343.0, 0.5))

func rocket(pos: Vector3) -> void:
	play(s_rocket, pos, 2.0, 0.8)

func whizz(pos: Vector3) -> void:
	play(s_whizz, pos, -2.0, randf_range(1.2, 1.8))

func ricochet(pos: Vector3) -> void:
	if cam_dist(pos) < 25.0:
		play(s_rico, pos, -10.0, randf_range(0.8, 1.2))

func whistle(pos: Vector3) -> void:
	play(s_whistle, pos, 2.0, 1.0)

func step(pos: Vector3) -> void:
	if cam_dist(pos) < 12.0:
		play(s_step, pos, -14.0, randf_range(0.8, 1.2))

func hit_tick(kill: bool) -> void:
	ui_player.stream = s_hit
	ui_player.pitch_scale = 0.6 if kill else 1.0
	ui_player.volume_db = -4.0 if kill else -8.0
	ui_player.play()
