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
var s_engine: AudioStreamWAV
var s_hammer: AudioStreamWAV
var s_kick: AudioStreamWAV
var s_glass: AudioStreamWAV
var players: Array = []
var pi = 0
var ui_player: AudioStreamPlayer
var ui_player2: AudioStreamPlayer

func _ready() -> void:
	var bus = AudioServer.bus_count
	AudioServer.add_bus(bus)
	AudioServer.set_bus_name(bus, "World")
	AudioServer.set_bus_send(bus, "Master")
	var rev = AudioEffectReverb.new()
	reverb = rev
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
	s_engine = _engine_loop()
	s_hammer = _noise(0.09, 0.025, 0.55, 3.0, 30.0)
	s_kick = _noise(0.35, 0.07, 0.12, 2.4, 70.0)
	s_glass = _glass_sound()
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
	ui_player2 = AudioStreamPlayer.new()
	add_child(ui_player2)
	s_far = _noise(2.2, 0.6, 0.04, 0.9, 40.0)
	_build_music.call_deferred()
	set_volume(G.settings["volume"])

# ---------------------------------------------------------------- battle music and the sound of the wider battle
# Three looping layers built at startup: a low drone, war drums and a tense string ostinato.
# They fade in as the fighting near the camera heats up.
const MRATE = 11025
var music: Array = []           # AudioStreamPlayer per layer
var intensity = 0.0
var heat = 0.0                  # recent fighting near the camera
var rumble_t = 3.0
var s_far: AudioStreamWAV
var reverb: AudioEffectReverb
var indoor = 0.0
var music_ready = false

func notice(pos: Vector3, amount: float) -> void:
	var d = cam_dist(pos)
	if d < 90.0:
		heat = minf(3.0, heat + amount * (1.0 - d / 90.0))

func _build_music() -> void:
	var bpm = 96.0
	var beat = 60.0 / bpm
	var bars = 8
	var n = int(beat * 4.0 * bars * MRATE)
	var drone = PackedFloat32Array()
	var drums = PackedFloat32Array()
	var strings = PackedFloat32Array()
	drone.resize(n)
	drums.resize(n)
	strings.resize(n)
	var roots = [73.42, 73.42, 87.31, 65.41, 73.42, 73.42, 58.27, 65.41]   # D D F C D D Bb C
	var lp = 0.0
	for i in range(n):
		var t = float(i) / MRATE
		var bar = int(t / (beat * 4.0)) % bars
		var f = roots[bar]
		var sw = 0.6 + 0.4 * sin(TAU * t / (beat * 8.0))
		drone[i] = (sin(TAU * f * t) * 0.5 + sin(TAU * f * 1.5 * t) * 0.25 + sin(TAU * f * 0.5 * t) * 0.35) * 0.32 * sw
	# drums: low toms on the beat, a snare-ish crack on 2 and 4, rolls into each fourth bar
	var hit_len = int(0.35 * MRATE)
	for b in range(bars * 4):
		var start = int(b * beat * MRATE)
		var low = b % 4 == 0 or b % 4 == 2
		for k in range(hit_len):
			if start + k >= n:
				break
			var t = float(k) / MRATE
			var v = 0.0
			if low:
				v = sin(TAU * (70.0 - t * 60.0) * t) * exp(-t / 0.12) * 0.9
			else:
				lp += (randf() * 2.0 - 1.0 - lp) * 0.5
				v = lp * exp(-t / 0.06) * 0.6 + sin(TAU * 180.0 * t) * exp(-t / 0.05) * 0.3
			drums[start + k] += v
		if b % 16 == 15:
			for r in range(4):
				var st2 = start + int(r * beat * 0.25 * MRATE)
				for k in range(int(0.12 * MRATE)):
					if st2 + k < n:
						var t2 = float(k) / MRATE
						drums[st2 + k] += sin(TAU * (110.0 - r * 10.0) * t2) * exp(-t2 / 0.05) * 0.5
	# strings: a driving eighth-note ostinato on the chord tones
	var pat = [0, 0, 7, 0, 3, 0, 7, 10]
	for e in range(bars * 8):
		var st3 = int(e * beat * 0.5 * MRATE)
		var bar2 = int(e / 8) % bars
		var f2 = roots[bar2] * 2.0 * pow(2.0, pat[e % 8] / 12.0)
		var L = int(beat * 0.5 * MRATE)
		var ph = 0.0
		for k in range(L):
			if st3 + k >= n:
				break
			var t3 = float(k) / MRATE
			ph += f2 / MRATE
			var saw = (fmod(ph, 1.0) * 2.0 - 1.0)
			strings[st3 + k] = saw * 0.22 * minf(1.0, t3 * 60.0) * exp(-t3 / 0.25)
	for arr in [drone, drums, strings]:
		var w = _wav_rate(arr, MRATE)
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = n
		var pl = AudioStreamPlayer.new()
		pl.stream = w
		pl.volume_db = -80.0
		add_child(pl)
		pl.play()
		music.append(pl)
	music_ready = true

func _wav_rate(samples: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var w = _wav(samples)
	w.mix_rate = rate
	return w

func _process(dt: float) -> void:
	if not music_ready:
		return
	var on = G.started and not G.over
	heat = maxf(0.0, heat - dt * 0.25)
	var want = clampf(heat / 2.0, 0.0, 1.0) if on else 0.0
	intensity = move_toward(intensity, want, dt * (0.35 if want > intensity else 0.08))
	var mv = G.settings["music"]
	var lv = [0.25 + intensity * 0.5, maxf(0.0, intensity - 0.25) * 1.3, maxf(0.0, intensity - 0.55) * 2.0]
	for i in range(music.size()):
		var a = clampf(lv[i], 0.0, 1.0) * mv * (1.0 if on else 0.0)
		music[i].volume_db = linear_to_db(maxf(a, 0.0001)) - 6.0
	# the wider battle: far-off booms and crackling gunfire while a fight is on
	if on:
		rumble_t -= dt
		if rumble_t <= 0.0:
			rumble_t = randf_range(2.5, 8.0) / (0.5 + G.soldiers.size() / 40.0)
			ui_player2.stream = s_far
			ui_player2.pitch_scale = randf_range(0.45, 0.8)
			ui_player2.volume_db = randf_range(-26.0, -16.0)
			ui_player2.play()
	# echo inside buildings
	var cam = get_viewport().get_camera_3d()
	if cam != null and G.started and G.world != null:
		var p = cam.global_position
		var inside = G.world.inside_at(p.x, p.y + 2.2, p.z) or not G.ray(p, p + Vector3(0, 6.0, 0), G.L_WORLD).is_empty()
		indoor = move_toward(indoor, 1.0 if inside else 0.0, dt * 2.0)
		if reverb != null:
			reverb.room_size = 0.55 + indoor * 0.35
			reverb.wet = 0.18 + indoor * 0.35
			reverb.damping = 0.6 - indoor * 0.3

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
	notice(pos, 0.08)
	play(s_shot, pos, w["snd_vol"], w["snd_pitch"], minf(d / 343.0, 0.4))

func boom(pos: Vector3) -> void:
	notice(pos, 0.6)
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

func hammer(pos: Vector3) -> void:
	if cam_dist(pos) < 45.0:
		play(s_hammer, pos, -6.0, randf_range(0.8, 1.25))

func kick(pos: Vector3) -> void:
	if cam_dist(pos) < 70.0:
		play(s_kick, pos, 0.0, randf_range(0.85, 1.1))

func glass(pos: Vector3) -> void:
	if cam_dist(pos) < 80.0:
		play(s_glass, pos, -3.0, randf_range(0.9, 1.15))

# breaking glass: a bright crash and a scatter of tinkles
func _glass_sound() -> AudioStreamWAV:
	var n = int(0.7 * RATE)
	var out = PackedFloat32Array()
	out.resize(n)
	var hp_prev = 0.0
	var pings = []
	for k in range(14):
		pings.append([randf_range(0.0, 0.5), randf_range(2500.0, 6500.0), randf_range(0.15, 0.35)])
	for i in range(n):
		var t = float(i) / RATE
		var w = randf() * 2.0 - 1.0
		var hpv = w - hp_prev
		hp_prev = w
		var v = hpv * exp(-t / 0.06) * 0.7
		for pg in pings:
			var dt = t - pg[0]
			if dt > 0.0 and dt < 0.12:
				v += sin(TAU * pg[1] * dt) * exp(-dt / 0.03) * pg[2]
		out[i] = v * minf(1.0, t * 2000.0)
	return _wav(out)

func step(pos: Vector3) -> void:
	if cam_dist(pos) < 12.0:
		play(s_step, pos, -14.0, randf_range(0.8, 1.2))

# engines: short rumbles re-triggered while driving, pitched up with speed
func engine(pos: Vector3, load_: float, heavy: bool) -> void:
	if cam_dist(pos) < 90.0:
		play(s_engine, pos, -6.0 if heavy else -9.0, (0.55 if heavy else 0.8) + load_ * 0.5)

func _engine_loop() -> AudioStreamWAV:
	var n = int(0.42 * RATE)
	var out = PackedFloat32Array()
	out.resize(n)
	var lp = 0.0
	for i in range(n):
		var t = float(i) / RATE
		var env = minf(1.0, t * 30.0) * minf(1.0, (0.42 - t) * 30.0)
		lp += (randf() * 2.0 - 1.0 - lp) * 0.08
		var v = sin(TAU * 42.0 * t) * 0.35 + sin(TAU * 84.0 * t) * 0.2 + sin(TAU * 126.0 * t) * 0.1 + lp * 0.5
		v *= 0.75 + 0.25 * sin(TAU * 14.0 * t)
		out[i] = v * env * 0.6
	return _wav(out)

func hit_tick(kill: bool) -> void:
	ui_player.stream = s_hit
	ui_player.pitch_scale = 0.6 if kill else 1.0
	ui_player.volume_db = -4.0 if kill else -8.0
	ui_player.play()
