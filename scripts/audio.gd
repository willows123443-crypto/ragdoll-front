extends Node
# Sounds are generated at startup (no audio files needed) and played through a pool of 3D players.

const RATE = 22050
var s_shot: AudioStreamWAV
var s_boom: AudioStreamWAV
var s_whizz: AudioStreamWAV
var s_rico: AudioStreamWAV
var s_whistle: AudioStreamWAV
var s_step: AudioStreamWAV
var s_splash: AudioStreamWAV
var s_hit: AudioStreamWAV
var s_rocket: AudioStreamWAV
var s_engine: AudioStreamWAV
var s_rumble: AudioStreamWAV
var s_squeal: AudioStreamWAV
var s_hammer: AudioStreamWAV
var s_kick: AudioStreamWAV
var s_guns = {}             # a report for each kind of gun
var s_distant: AudioStreamWAV
var s_crack: AudioStreamWAV
var s_slap: AudioStreamWAV
var s_groans: Array = []
var s_snarl: AudioStreamWAV
var s_screech: AudioStreamWAV
var s_glass: AudioStreamWAV
var players: Array = []
var pi = 0
var ui_player: AudioStreamPlayer
var ui_player2: AudioStreamPlayer

func _ready() -> void:
	# In a browser every sound goes straight to the master bus. Adding a bus while the game runs
	# (AudioServer.add_bus) trips a fault in the engine's web audio: the new bus is slotted in ahead of
	# the master, the master is then routed into it, and nothing is connected to the speakers any more.
	# That is why the browser build was completely silent. (The engine's effects aren't used in a
	# browser anyway, so nothing is lost: the page has its own limiter.)
	web = OS.has_feature("web") or "--webaudio" in OS.get_cmdline_user_args()     # (the flag: to test the browser routing on a desktop)
	if not web:
		var bus = AudioServer.bus_count
		AudioServer.add_bus(bus)
		AudioServer.set_bus_name(bus, "World")
		AudioServer.set_bus_send(bus, "Master")
		AudioServer.set_bus_volume_db(bus, -4.0)
		world_bus = "World"
		# the loudest moments (a shell close by with a firefight going) are held under full scale and
		# not clipped
		var lim = AudioEffectHardLimiter.new()
		lim.ceiling_db = -0.5
		AudioServer.add_bus_effect(0, lim)
		var rev = AudioEffectReverb.new()
		reverb = rev
		rev.room_size = 0.55
		rev.damping = 0.6
		rev.wet = 0.18
		rev.dry = 1.0
		AudioServer.add_bus_effect(bus, rev)
		# a blast close by leaves you half deaf for a moment: everything dull and muffled, then it comes back
		deaf_fx = AudioEffectLowPassFilter.new()
		deaf_fx.cutoff_hz = 20000.0
		AudioServer.add_bus_effect(bus, deaf_fx)
		AudioServer.set_bus_effect_enabled(bus, AudioServer.get_bus_effect_count(bus) - 1, false)
		deaf_bus = bus
	s_shot = _noise(0.32, 0.055, 0.45, 2.2)
	s_boom = _noise(1.8, 0.35, 0.08, 1.0, 55.0)
	s_whizz = _noise(0.12, 0.03, 0.9, 1.0)
	s_rico = _sweep(2400.0, 800.0, 0.28, 0.25)
	s_whistle = _sweep(1400.0, 380.0, 1.15, 0.22)
	s_step = _noise(0.06, 0.02, 0.15, 1.0)
	s_splash = _noise(0.32, 0.09, 0.62, 1.4)
	s_hit = _sweep(1400.0, 1200.0, 0.05, 0.25)
	s_rocket = _noise(0.7, 0.25, 0.3, 1.0)
	s_engine = _engine_loop()
	s_rumble = _rumble()
	s_squeal = _squeal()
	s_hammer = _noise(0.09, 0.025, 0.55, 3.0, 30.0)
	s_kick = _noise(0.35, 0.07, 0.12, 2.4, 70.0)
	s_glass = _glass_sound()
	# guns: length, decay, brightness, punch, low thump
	s_guns["rifle"] = _gun(0.42, 0.05, 0.5, 2.3, 70.0, 0.02)
	s_guns["lmg"] = _gun(0.4, 0.045, 0.42, 2.5, 60.0, 0.015)
	s_guns["sniper"] = _gun(0.9, 0.09, 0.55, 2.6, 48.0, 0.05)
	s_guns["shotgun"] = _gun(0.55, 0.08, 0.25, 2.8, 52.0, 0.0)
	s_guns["hmg"] = _gun(0.5, 0.06, 0.3, 2.8, 42.0, 0.02)
	s_guns["smg"] = _gun(0.22, 0.03, 0.55, 2.0, 95.0, 0.0)
	s_guns["pistol"] = _gun(0.2, 0.028, 0.6, 1.8, 110.0, 0.0)
	s_guns["atrifle"] = _gun(1.0, 0.11, 0.4, 3.0, 38.0, 0.06)
	s_distant = _noise(1.4, 0.32, 0.05, 1.1, 34.0)
	s_crack = _crack()
	s_slap = _noise(0.25, 0.05, 0.22, 1.2, 0.0)
	for k in range(3):
		s_groans.append(_groan(1.1 + k * 0.35, 85.0 + k * 22.0, 0.55))
	s_snarl = _groan(0.55, 140.0, 1.0)
	s_screech = _groan(0.7, 260.0, 1.2)
	ear = AudioListener3D.new()
	add_child(ear)
	for i in range(28):
		var p = AudioStreamPlayer3D.new()
		p.bus = world_bus
		p.unit_size = UNIT
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
	_build_menu_music.call_deferred()
	_build_voices()
	set_volume(G.settings["volume"])

# ---------------------------------------------------------------- battle music and the sound of the wider battle
# Three looping layers built at startup: a low drone, war drums and a tense string ostinato.
# They fade in as the fighting near the camera heats up.
const MRATE = 11025
var music: Array = []           # AudioStreamPlayer per layer
var intensity = 0.0
var heat = 0.0                  # recent fighting near the camera
var battle = 0.0                # how much of the whole battle is in contact (0..1)
var battle_t = 0.0
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
	if web:
		_build_mixes(drone, drums, strings, n)
	for arr in [drone, drums, strings]:
		var w = _wav_rate(arr, MRATE)
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = n
		var pl = AudioStreamPlayer.new()
		pl.stream = w
		pl.volume_db = -80.0
		add_child(pl)
		if not web:
			pl.play()        # (in a browser each layer is started when it's wanted, at the level it's wanted)
		music.append(pl)
	music_ready = true

func _wav_rate(samples: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var w = _wav(samples)
	w.mix_rate = rate
	return w

var deaf_fx: AudioEffectLowPassFilter = null
var deaf_bus = -1
var web = false
var world_bus = "Master"
# The title tune and the horn calls are made at full scale and turned down to taste here. (A little
# further in a browser, where the page's limiter lifts everything that passes through it.)
var music_cut = -6.0 if OS.has_feature("web") else -4.0

# scale a waveform so its loudest point is at `peak`
func _norm(out: PackedFloat32Array, peak: float) -> void:
	var m = 0.0001
	for x in out:
		m = maxf(m, absf(x))
	var k = peak / m
	for i in range(out.size()):
		out[i] *= k
var world_trim = 0.0        # (browser only: what the World bus's volume does on desktop)
var deaf = 0.0
var s_ring: AudioStreamWAV = null

func deafen(k: float) -> void:
	k = clampf(k, 0.0, 1.0)
	if k < 0.15 or deaf_fx == null:
		return
	var was = deaf
	deaf = maxf(deaf, 1.2 + 2.0 * k)
	AudioServer.set_bus_effect_enabled(deaf_bus, AudioServer.get_bus_effect_count(deaf_bus) - 1, true)
	if was < 0.5 and k > 0.4:
		if s_ring == null:
			var rate = 22050
			var n = int(rate * 2.4)
			var smp = PackedFloat32Array()
			smp.resize(n)
			for i in range(n):
				var t = float(i) / rate
				smp[i] = sin(TAU * 3700.0 * t) * 0.35 * exp(-t * 1.3) * minf(1.0, t * 30.0)
			s_ring = _wav(smp)
			s_ring.mix_rate = rate
		ui_player2.stream = s_ring
		ui_player2.pitch_scale = randf_range(0.95, 1.05)
		ui_player2.volume_db = -20.0 + 6.0 * k + fx_db()
		ui_player2.play()

func _process(dt: float) -> void:
	_ear_tick()
	_engine_loops()
	echo_budget = minf(echo_budget + dt * 9.0, 4.0)
	if deaf > 0.0 and deaf_fx != null:
		deaf = maxf(0.0, deaf - dt)
		# the world comes back gradually: from a dull thump up to full brightness
		deaf_fx.cutoff_hz = lerpf(20000.0, 450.0, clampf(deaf / 1.6, 0.0, 1.0))
		if deaf <= 0.0:
			AudioServer.set_bus_effect_enabled(deaf_bus, AudioServer.get_bus_effect_count(deaf_bus) - 1, false)
	if not music_ready:
		return
	var on = G.started and not G.over and not G.attract
	# (the battle behind the title screen is kept well down under the tune)
	var wv = -18.0 if G.attract else -4.0
	if deaf_bus < 0:
		world_trim = move_toward(world_trim, wv, dt * 30.0)
	elif absf(AudioServer.get_bus_volume_db(deaf_bus) - wv) > 0.05:
		AudioServer.set_bus_volume_db(deaf_bus, move_toward(AudioServer.get_bus_volume_db(deaf_bus), wv, dt * 30.0))
	# the title screen and the menus before a battle have their own tune; it fades out as the battle
	# comes up and back in when you return
	var menu_on = (not G.started or G.attract) and G.settings["music"] > 0.0
	menu_k = move_toward(menu_k, 1.0 if menu_on else 0.0, dt * (0.5 if menu_on else 0.9))
	if menu_player != null:
		_loop_vol(menu_player, linear_to_db(maxf((1.0 if web and menu_on else menu_k) * G.settings["music"] * 2.0, 0.0001)) + music_cut, menu_k > 0.0 and (menu_on or not web))
	_horde_bed(dt)
	heat = maxf(0.0, heat - dt * 0.25)
	# how hot the whole battle is, not just what's in front of the camera (the commander's view is high up):
	# the share of men who can see an enemy right now
	battle_t -= dt
	if battle_t <= 0.0 and on:
		battle_t = 1.0
		var n = 0
		var c = 0
		for sl in G.soldiers:
			if sl.state == "alive" and not sl.zombie:
				n += 1
				if sl.vis_t != null:
					c += 1
		battle = clampf(float(c) / maxf(8.0, n * 0.5), 0.0, 1.0)
	var want = clampf(maxf(heat / 2.0, battle * 0.9), 0.0, 1.0) if on else 0.0
	intensity = move_toward(intensity, want, dt * (0.35 if want > intensity else 0.08))
	var mv = G.settings["music"]
	var lv = [0.25 + intensity * 0.5, maxf(0.0, intensity - 0.25) * 1.3, maxf(0.0, intensity - 0.55) * 2.0]
	for i in range(music.size()):
		var a = clampf(lv[i], 0.0, 1.0) * mv * (1.0 if on else 0.0)
		if not web:
			music[i].volume_db = linear_to_db(maxf(a, 0.0001)) - 3.0
	if web:
		_mix_tick(intensity, mv, on)
	# the wider battle: far-off booms and crackling gunfire while a fight is on
	if on:
		rumble_t -= dt
		if rumble_t <= 0.0:
			rumble_t = randf_range(2.5, 8.0) / (0.5 + G.soldiers.size() / 40.0)
			var r = randf()
			if r < 0.45:
				ui_player2.stream = s_far
				ui_player2.pitch_scale = randf_range(0.45, 0.8)
				ui_player2.volume_db = randf_range(-26.0, -16.0) + fx_db()
				ui_player2.play()
			elif r < 0.75:
				# a machine gun somewhere off past the edge of the map: a short burst, dulled by distance
				var n = randi_range(4, 10)
				var vol = randf_range(-30.0, -21.0)
				var pit = randf_range(0.5, 0.65)
				for k in range(n):
					_far_shot(k * randf_range(0.075, 0.095), vol, pit)
			else:
				# scattered rifle fire
				for k in range(randi_range(2, 5)):
					_far_shot(randf_range(0.0, 1.6), randf_range(-32.0, -24.0), randf_range(0.6, 0.8))
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

var far_players: Array = []
var far_i = 0

func _far_shot(delay: float, vol: float, pit: float) -> void:
	if far_players.is_empty():
		for k in range(6):
			var pl = AudioStreamPlayer.new()
			add_child(pl)
			far_players.append(pl)
	get_tree().create_timer(delay, false).timeout.connect(func():
		var pl: AudioStreamPlayer = far_players[far_i]
		far_i = (far_i + 1) % far_players.size()
		pl.stream = s_distant
		pl.pitch_scale = pit * randf_range(0.95, 1.05)
		pl.volume_db = vol + fx_db()
		pl.play())

# a crackle and a squelch, for orders going out over the radio
var s_radio: AudioStreamWAV = null

func radio_click() -> void:
	if s_radio == null:
		var n = int(0.3 * RATE)
		var out = PackedFloat32Array()
		out.resize(n)
		var lp = 0.0
		var hp = 0.0
		for i in range(n):
			var t = float(i) / RATE
			var v = 0.0
			# a short squelch tone, then band-limited hiss that crackles in and out
			if t < 0.06:
				v += sin(TAU * 1250.0 * t) * 0.35 * minf(1.0, t * 300.0)
			var nz = randf() * 2.0 - 1.0
			lp += (nz - lp) * 0.45
			hp = lp - hp * 0.6
			var gate = 1.0 if fmod(t * 37.0 + sin(t * 90.0), 1.0) > 0.25 else 0.35
			v += hp * 0.32 * gate * (1.0 if t > 0.04 else 0.0) * exp(-maxf(0.0, t - 0.2) / 0.03)
			out[i] = v
		s_radio = _wav(out)
	if G.settings["volume"] <= 0.0:
		return
	ui_player.stream = s_radio
	ui_player.pitch_scale = randf_range(0.95, 1.05)
	ui_player.volume_db = -10.0 + fx_db()
	ui_player.play()

# a small two-note blip when a waypoint goes down or a line is drawn (not the radio squelch)
var s_tick: AudioStreamWAV = null
var tick_player: AudioStreamPlayer = null

func order_tick(high: bool = false) -> void:
	if s_tick == null:
		var n = int(0.11 * RATE)
		var out = PackedFloat32Array()
		out.resize(n)
		for i in range(n):
			var t = float(i) / RATE
			var f = 880.0 if t < 0.045 else 1320.0
			out[i] = sin(TAU * f * t) * 0.3 * minf(1.0, t * 400.0) * exp(-t / 0.05)
		s_tick = _wav(out)
		tick_player = AudioStreamPlayer.new()
		add_child(tick_player)
	tick_player.stream = s_tick
	tick_player.pitch_scale = 1.2 if high else 1.0
	tick_player.volume_db = -12.0 + fx_db()
	tick_player.play()

# The tune for the title screen: a slow march in D minor. A soft pad holds the chords, a horn carries
# the melody, a kettledrum marks each bar and a side drum ticks quietly underneath. Built once at
# startup like the battle music (there are no sound files in the game).
var menu_player: AudioStreamPlayer = null
var menu_k = 0.0

func _build_menu_music() -> void:
	var bpm = 76.0
	var beat = 60.0 / bpm
	var bars = 8
	var n = int(beat * 4.0 * bars * MRATE)
	var out = PackedFloat32Array()
	out.resize(n)
	# chords, one a bar: Dm Dm Bb F Gm Dm A Dm (three notes each, an octave below the tune)
	var chords = [[146.83, 174.61, 220.0], [146.83, 174.61, 220.0], [116.54, 146.83, 174.61], [130.81, 174.61, 220.0],
		[98.0, 146.83, 196.0], [146.83, 174.61, 220.0], [110.0, 138.59, 164.81], [146.83, 174.61, 220.0]]
	var bar_n = int(beat * 4.0 * MRATE)
	for b in range(bars):
		var ch = chords[b]
		for k in range(bar_n):
			var t = float(k) / MRATE
			var env = minf(1.0, t / 0.5) * minf(1.0, (beat * 4.0 - t) / 0.6)
			var v = 0.0
			for f in ch:
				v += sin(TAU * f * t) + 0.5 * sin(TAU * f * 1.003 * t + 1.0) + 0.22 * sin(TAU * f * 2.0 * t)
			out[b * bar_n + k] = v * 0.045 * env
	# the tune: [note in semitones above D4, beats]
	var tune = [[0, 2], [3, 1], [7, 1],  [7, 3], [5, 1],  [3, 2], [0, 1], [3, 1],  [10, 2], [7, 2],
		[8, 2], [5, 1], [8, 1],  [7, 3], [3, 1],  [2, 2], [-1, 1], [2, 1],  [0, 4]]
	var at = 0.0
	for nt in tune:
		var f2 = 293.66 * pow(2.0, nt[0] / 12.0)
		var len_s = nt[1] * beat
		var st = int(at * MRATE)
		for k in range(int(len_s * MRATE)):
			if st + k >= n:
				break
			var t2 = float(k) / MRATE
			var vib = 1.0 + 0.004 * sin(TAU * 5.2 * t2) * minf(1.0, t2 / 0.4)
			var ph = TAU * f2 * vib * t2
			var env2 = minf(1.0, t2 / 0.07) * minf(1.0, (len_s - t2) / 0.12) * (0.75 + 0.25 * exp(-t2 / 0.6))
			out[st + k] += (sin(ph) + 0.45 * sin(ph * 2.0) + 0.22 * sin(ph * 3.0) + 0.08 * sin(ph * 4.0)) * 0.13 * env2
		at += len_s
	# kettledrum on the first beat of every bar (and the third of the last), side drum ticking the march
	var lp = 0.0
	for b in range(bars * 4):
		var st3 = int(b * beat * MRATE)
		if b % 4 == 0 or b == bars * 4 - 2:
			for k in range(int(0.9 * MRATE)):
				if st3 + k >= n:
					break
				var t3 = float(k) / MRATE
				out[st3 + k] += sin(TAU * (73.4 - t3 * 6.0) * t3) * exp(-t3 / 0.28) * 0.3
		for sub in ([0.0, 0.5, 0.75] if b % 2 == 1 else [0.0]):
			var st4 = st3 + int(sub * beat * MRATE)
			for k in range(int(0.09 * MRATE)):
				if st4 + k >= n:
					break
				var t4 = float(k) / MRATE
				lp += (randf() * 2.0 - 1.0 - lp) * 0.6
				out[st4 + k] += lp * exp(-t4 / 0.025) * (0.07 if sub == 0.0 else 0.045)
	_norm(out, 0.92)
	var w = _wav_rate(out, MRATE)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	menu_player = AudioStreamPlayer.new()
	menu_player.stream = w
	menu_player.volume_db = -80.0
	add_child(menu_player)

# The battle music in a browser. On a desktop three layers play together and each is turned up and down
# as the fight heats and cools; a browser can't turn a playing sound up or down. So there the same
# material is made into three finished mixes (calm: the drone; tense: drone and drums; hot: drone, drums
# and strings) and only one plays at a time. A change is made on a bar line, from the same place in the
# loop, and not more often than every six seconds, so it comes in on the beat and doesn't chatter.
const BAR_S = 2.5                 # one bar at 96 to the minute
var mixes: Array = []             # AudioStreamPlayer for calm, tense, hot
var mix_cur = -1
var mix_want = 0
var mix_ms = 0
var mix_switches = 0

func _build_mixes(drone: PackedFloat32Array, drums: PackedFloat32Array, strings: PackedFloat32Array, n: int) -> void:
	for wts in [[0.32, 0.0, 0.0], [0.5, 0.34, 0.0], [0.6, 0.68, 0.55]]:
		var out = PackedFloat32Array()
		out.resize(n)
		for i in range(n):
			out[i] = drone[i] * wts[0] + drums[i] * wts[1] + strings[i] * wts[2]
		var w = _wav_rate(out, MRATE)
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = n
		var pl = AudioStreamPlayer.new()
		pl.stream = w
		add_child(pl)
		mixes.append(pl)

func _mix_tick(k: float, mv: float, on: bool) -> void:
	if mixes.is_empty():
		return
	if not on or mv <= 0.0:
		if mix_cur >= 0:
			mixes[mix_cur].stop()
			mix_cur = -1
		return
	# which mix the fight calls for (with a margin, so it doesn't flap on the line between two)
	if mix_want == 0 and k > 0.34:
		mix_want = 1
	elif mix_want == 1 and k > 0.64:
		mix_want = 2
	elif mix_want == 2 and k < 0.5:
		mix_want = 1
	elif mix_want == 1 and k < 0.22:
		mix_want = 0
	var db = linear_to_db(maxf(mv * 2.0, 0.001)) - 3.0
	var now = Time.get_ticks_msec()
	if mix_cur < 0:
		mix_cur = mix_want
		mix_ms = now
		_loop_vol(mixes[mix_cur], db, true)
		return
	if mix_want != mix_cur and now - mix_ms > 6000:
		var pos: float = mixes[mix_cur].get_playback_position()
		if fmod(pos, BAR_S) < 0.2:
			mixes[mix_cur].stop()
			mix_cur = mix_want
			mix_ms = now
			mix_switches += 1
			_loop_vol(mixes[mix_cur], db, true, pos)
			return
	_loop_vol(mixes[mix_cur], db, true)

# Set a looping player's volume, and start or stop it. On a desktop that's all there is to it. In a
# browser a sound that isn't placed in the world keeps the volume it was started at (turning it up or
# down afterwards does nothing: the title tune was started at the first step of its fade-in and stayed
# there, all but silent), so there the volume goes in steps of 4 dB, and at each step the sound is
# stopped and started again at the new level from where it had got to.
func _loop_vol(pl: AudioStreamPlayer, db: float, on: bool, sync_pos: float = -1.0) -> void:
	if not on:
		if pl.playing:
			pl.stop()
		return
	if not web:
		pl.volume_db = db
		if not pl.playing:
			pl.play(maxf(sync_pos, 0.0))
		return
	var cur: float = pl.get_meta("vol", -999.0)
	if pl.playing and absf(cur - db) < 4.0:
		return
	var at = pl.get_playback_position() if pl.playing else maxf(sync_pos, 0.0)
	var L = pl.stream.get_length() if pl.stream != null else 0.0
	if L > 0.0:
		at = fmod(at, L)
	loop_restarts += 1
	pl.stop()
	pl.volume_db = db
	pl.set_meta("vol", db)
	pl.play(at)

var loop_restarts = 0

# the effects slider (everything but the music), as decibels
func fx_db() -> float:
	return linear_to_db(clampf(float(G.settings.get("sfx", 1.0)), 0.001, 1.0))

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

func play(stream: AudioStream, pos: Vector3, vol_db: float = 0.0, pitch: float = 1.0, delay: float = 0.0, muffle: bool = false, cutoff: float = 5000.0) -> void:
	if delay > 0.01:
		get_tree().create_timer(delay, false).timeout.connect(func(): play(stream, pos, vol_db, pitch, 0.0, muffle, cutoff))
		return
	var p: AudioStreamPlayer3D = players[pi]
	pi = (pi + 1) % players.size()
	p.stream = stream
	p.global_position = pos
	p.volume_db = vol_db - (5.0 if muffle else 0.0) + world_trim + fx_db()
	# through a wall: dull and low, the top end cut away (and the top end goes with distance too)
	p.attenuation_filter_cutoff_hz = 800.0 if muffle else cutoff
	p.pitch_scale = pitch * randf_range(0.93, 1.07)
	p.play()

# a blast near where you're watching from: everything goes dull for a moment and comes back (no ringing:
# that's for a man caught close to one)
func dull(k: float) -> void:
	k = clampf(k, 0.0, 1.0)
	if k < 0.2 or deaf_fx == null:
		return
	deaf = maxf(deaf, 0.3 + 0.9 * k)
	AudioServer.set_bus_effect_enabled(deaf_bus, AudioServer.get_bus_effect_count(deaf_bus) - 1, true)

# Where the battle is heard from. In a man's boots that's the camera. Looking down from above it's a
# point close over the ground you're looking at: heard from the camera itself, forty or eighty metres up,
# a whole battle was a faint patter (most players took it for no sound at all).
const UNIT = 20.0          # how far a sound carries at full strength (was 12)
const EAR_UP = 15.0        # the ear is never further than this from the ground being looked at
var ear: AudioListener3D = null
var ear_pos = Vector3.ZERO
var ear_ok = false

func _ear_tick() -> void:
	var cam = get_viewport().get_camera_3d()
	if cam == null or ear == null:
		ear_ok = false
		return
	var cp: Vector3 = cam.global_position
	var p = cp
	if G.started and G.world != null and (G.player == null or not is_instance_valid(G.player)):
		var fwd: Vector3 = -cam.global_transform.basis.z
		var h = cp.y - G.world.ground_y(cp.x, cp.z)
		if h > EAR_UP and fwd.y < -0.08:
			var focus: Vector3 = cp + fwd * minf(h / -fwd.y, 320.0)
			var back: Vector3 = cp - focus
			var L = back.length()
			if L > EAR_UP:
				p = focus + back / L * EAR_UP
	ear_pos = p
	ear_ok = true
	ear.global_transform = Transform3D(cam.global_transform.basis, p)
	if not ear.is_current():
		ear.make_current()

func cam_dist(pos: Vector3) -> float:
	if ear_ok:
		return ear_pos.distance_to(pos)
	var cam = get_viewport().get_camera_3d()
	return cam.global_position.distance_to(pos) if cam else 0.0

# is there a wall (or a hill) between the listener and a sound? checked for nearby sounds only
func occluded(pos: Vector3) -> bool:
	var cam = get_viewport().get_camera_3d()
	if cam == null or G.world == null:
		return false
	var a = ear_pos if ear_ok else cam.global_position
	if a.distance_to(pos) > 80.0:
		return false
	return G.blocked(a, pos + Vector3(0, 0.8, 0))

# echoes cost voices: only so many shots a second get them, so a big firefight doesn't cut its own sounds off
var echo_budget = 4.0

func shot(pos: Vector3, w: Dictionary) -> void:
	var d = cam_dist(pos)
	notice(pos, 0.08)
	var delay = minf(d / 343.0, 0.7)
	var stream = s_guns.get(w["id"], s_shot)
	var vol: float = w["snd_vol"]
	if d > 110.0:
		# far off, a gun is a dull thump rolling across the field: lower and duller the further away it is
		var fk = clampf((d - 110.0) / 150.0, 0.0, 1.0)
		play(s_distant, pos, vol - 4.0, w["snd_pitch"] * lerpf(1.3, 1.0, fk), delay, false, lerpf(1600.0, 650.0, fk))
		return
	var muf = occluded(pos)
	# sharp and cracking up close; from 40 m out it loses its edge and a low thud comes in under it
	var far_k = clampf((d - 40.0) / 70.0, 0.0, 1.0)
	play(stream, pos, vol - far_k * 6.0, randf_range(0.96, 1.04) * (1.0 - far_k * 0.12), delay, muf, lerpf(11000.0, 1500.0, clampf((d - 15.0) / 80.0, 0.0, 1.0)))
	if d < 24.0 and not muf:
		# right beside it: the hard crack on the front of the bang
		play(s_crack, pos, vol - 7.0 - d * 0.3, randf_range(0.75, 0.95), delay, false, 16000.0)
	if far_k > 0.15:
		play(s_distant, pos, vol - 10.0 + far_k * 6.0, w["snd_pitch"] * 1.3, delay, muf, 1400.0)
	if d < 90.0 and G.world != null and echo_budget >= 1.0:
		if indoor > 0.5:
			# in a room the bang comes straight back off the walls, loud and close behind the shot
			echo_budget -= 1.0
			play(s_slap, pos, vol - 5.0, 0.7, delay + randf_range(0.03, 0.06))
			play(s_slap, pos, vol - 11.0, 0.58, delay + randf_range(0.1, 0.17), false, 2500.0)
		elif _walls_near(pos):
			# in town it slaps back off the nearest wall, and again, fainter and duller, off the far end of the street
			echo_budget -= 1.0
			play(s_slap, pos, vol - 9.0, 0.85, delay + randf_range(0.09, 0.2))
			if d < 60.0:
				play(s_slap, pos, vol - 15.0, 0.62, delay + randf_range(0.3, 0.5), false, 1800.0)

func _walls_near(p: Vector3) -> bool:
	return G.world.cols_in_rect(p.x - 14.0, p.z - 14.0, p.x + 14.0, p.z + 14.0).size() > 6

# a round going past close: the sharp crack of a supersonic bullet, louder the closer it passes
func crack(pos: Vector3, miss: float) -> void:
	play(s_crack, pos, lerpf(2.0, -14.0, clampf(miss / 7.0, 0.0, 1.0)), randf_range(0.9, 1.15))

# a gunshot: a sharp transient, a body of filtered noise, and a low thump
func _gun(len_s: float, decay: float, bright: float, punch: float, thump: float, tail: float) -> AudioStreamWAV:
	var n = int(len_s * RATE)
	var out = PackedFloat32Array()
	out.resize(n)
	var lp = 0.0
	var lp2 = 0.0
	for i in range(n):
		var t = float(i) / RATE
		var env = exp(-t / decay) * minf(1.0, t * 3000.0)
		var w = randf() * 2.0 - 1.0
		lp += (w - lp) * bright
		lp2 += (lp - lp2) * 0.08
		var v = lp * env * punch
		v += (randf() * 2.0 - 1.0) * exp(-t / 0.004) * 0.8
		if thump > 0.0:
			v += sin(TAU * thump * t * (1.0 - t * 0.6)) * exp(-t / (decay * 1.4)) * 0.9
		if tail > 0.0:
			v += lp2 * exp(-t / (tail * 6.0)) * 1.4
		out[i] = v
	return _wav(out)

func _crack() -> AudioStreamWAV:
	var n = int(0.06 * RATE)
	var out = PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		var t = float(i) / RATE
		var v = (randf() * 2.0 - 1.0) * exp(-t / 0.006) * 1.4
		v += sin(TAU * 2600.0 * t) * exp(-t / 0.01) * 0.5
		out[i] = v
	return _wav(out)

func boom(pos: Vector3) -> void:
	notice(pos, 0.6)
	var d = cam_dist(pos)
	var delay = minf(d / 343.0, 0.8)
	if d > 130.0:
		# a long way off: a low rumble that arrives late
		play(s_far, pos, 9.0, randf_range(0.6, 0.8), delay, false, 800.0)
		return
	# a blast is felt even through a wall, just deeper
	var muf = occluded(pos)
	var fk = clampf((d - 30.0) / 100.0, 0.0, 1.0)
	play(s_boom, pos, 6.0 + (3.0 if muf else 0.0), (0.85 if muf else 1.0) * (1.0 - 0.15 * fk), delay, muf, lerpf(7000.0, 1400.0, fk))
	if d < 20.0 and not muf:
		play(s_crack, pos, 3.0, 0.55, delay, false, 16000.0)
	if d < 110.0 and G.world != null and (indoor > 0.5 or _walls_near(pos)):
		# and it rolls back off the buildings
		play(s_boom, pos, -5.0, 0.62, delay + randf_range(0.28, 0.5), false, 1100.0)

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

# the dead: a voiced moan through a throaty filter, wobbling in pitch, with breath noise
func _groan(len_s: float, f0: float, rough: float) -> AudioStreamWAV:
	var n = int(len_s * RATE)
	var out = PackedFloat32Array()
	out.resize(n)
	var ph = 0.0
	var lp = 0.0
	var bp1 = 0.0
	var bp2 = 0.0
	var wob = randf() * 6.0
	for i in range(n):
		var t = float(i) / RATE
		var k = t / len_s
		var env = minf(1.0, t * 12.0) * (1.0 - k) * (0.7 + 0.3 * sin(t * 9.0 + wob))
		var f = f0 * (1.0 + 0.12 * sin(t * 5.3 + wob) - 0.25 * k) * (1.0 + (randf() - 0.5) * 0.04 * rough)
		ph += f / RATE
		var saw = 2.0 * fmod(ph, 1.0) - 1.0
		var v = saw * 0.6 + (randf() * 2.0 - 1.0) * 0.35 * rough
		# a crude vocal-tract resonance
		bp1 += (v - bp1) * 0.12
		bp2 += (bp1 - bp2) * 0.12
		lp += ((bp1 - bp2 * 0.6) - lp) * 0.5
		out[i] = lp * env * 1.6
	return _wav(out)

func groan(pos: Vector3, kind: String) -> void:
	if cam_dist(pos) > 45.0:
		return
	match kind:
		"snarl":
			play(s_snarl, pos, -2.0, randf_range(0.8, 1.1))
		"screech":
			play(s_screech, pos, -1.0, randf_range(0.9, 1.15))
		"brute":
			play(s_groans[randi() % s_groans.size()], pos, 2.0, 0.6)
		_:
			play(s_groans[randi() % s_groans.size()], pos, -5.0, randf_range(0.8, 1.15))

# a footfall, by what's underfoot: a dull pad on earth and grass, a harder scuff on a road, a hollow
# knock on the boards and concrete of a floor indoors
func step(pos: Vector3) -> void:
	if cam_dist(pos) > 14.0:
		return
	var W = G.world
	if W != null and s_step_floor != null and W.inside_at(pos.x, pos.y + 1.0, pos.z):
		play(s_step_floor, pos, -11.0, randf_range(0.85, 1.2))
	elif W != null and s_step_road != null and W.on_road(pos.x, pos.z):
		play(s_step_road, pos, -12.0, randf_range(0.85, 1.2))
	else:
		play(s_step, pos, -13.0, randf_range(0.8, 1.2))

func splash(pos: Vector3, deep: bool) -> void:
	if cam_dist(pos) < 18.0:
		play(s_splash, pos, -10.0 if deep else -15.0, randf_range(0.7, 1.1) if deep else randf_range(1.0, 1.4))

# engines: short rumbles re-triggered while driving, pitched up with speed
# the few vehicles nearest the camera get a continuous engine note instead of the short rumbles: the
# revs climb through each gear and drop at the change, tracks clatter with speed, and a gearbox whine
# when it's backing up
var eng_loops: Array = []
var eng_assigned: Array = []
var s_eng_loop: AudioStreamWAV = null
var s_whine: AudioStreamWAV = null

func _make_engine_loops() -> void:
	var n = RATE
	var out = PackedFloat32Array()
	out.resize(n)
	var lp = 0.0
	for i in range(n):
		var t = float(i) / RATE
		lp += (randf() * 2.0 - 1.0 - lp) * 0.08
		# whole numbers of cycles in one second, so the loop joins without a click
		var v = sin(TAU * 42.0 * t) * 0.35 + sin(TAU * 84.0 * t) * 0.2 + sin(TAU * 126.0 * t) * 0.1 + lp * 0.45
		v *= 0.75 + 0.25 * sin(TAU * 14.0 * t)
		var edge = minf(1.0, minf(t, 1.0 - t) * 200.0)
		out[i] = v * 0.6 * lerpf(1.0, 1.0, edge)
	s_eng_loop = _wav(out)
	s_eng_loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s_eng_loop.loop_begin = 0
	s_eng_loop.loop_end = n
	var w = PackedFloat32Array()
	w.resize(n)
	for i in range(n):
		var t = float(i) / RATE
		w[i] = (sin(TAU * 620.0 * t) * 0.6 + sin(TAU * 1240.0 * t) * 0.25) * 0.3
	s_whine = _wav(w)
	s_whine.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s_whine.loop_begin = 0
	s_whine.loop_end = n
	for i in range(4):
		var pair = []
		for k in range(2):
			var p = AudioStreamPlayer3D.new()
			p.bus = world_bus
			p.unit_size = 10.0
			p.max_distance = 110.0
			p.stream = s_eng_loop if k == 0 else s_whine
			p.volume_db = -80.0
			add_child(p)
			pair.append(p)
		eng_loops.append(pair)

func _engine_loops() -> void:
	if not G.started or G.over:
		for pr in eng_loops:
			for p in pr:
				if p.playing:
					p.stop()
		eng_assigned.clear()
		return
	var cam = get_viewport().get_camera_3d()
	if cam == null:
		return
	if eng_loops.is_empty():
		_make_engine_loops()
	var near = []
	for v in G.vehicles:
		if v.dead or v.driver() == null or v.spec.get("static", false) or v.spec.get("air", false) or not v.visible:
			continue
		var d = cam.global_position.distance_squared_to(v.pos)
		if d < 75.0 * 75.0:
			near.append([d, v])
	near.sort_custom(func(a, b): return a[0] < b[0])
	eng_assigned.clear()
	for i in range(eng_loops.size()):
		var eng: AudioStreamPlayer3D = eng_loops[i][0]
		var wh: AudioStreamPlayer3D = eng_loops[i][1]
		if i >= near.size():
			if eng.playing:
				eng.stop()
				wh.stop()
			continue
		var v = near[i][1]
		eng_assigned.append(v.pos)
		var heavy: bool = v.spec["tracked"]
		var r = clampf(absf(v.speed) / maxf(1.0, v.spec["speed"]), 0.0, 1.0)
		var gears = 3.0 if heavy else 4.0
		var gi = minf(gears - 1.0, floorf(r * gears))
		var within = r * gears - gi
		var rpm = 0.15 + 0.85 * within if r > 0.04 else 0.0
		eng.global_position = v.pos
		wh.global_position = v.pos
		eng.pitch_scale = (0.55 if heavy else 0.8) * (1.0 + rpm * 0.7 + gi * 0.06)
		eng.volume_db = (-7.0 if heavy else -10.0) + r * 5.0 + fx_db()
		var back = v.speed < -0.4
		wh.pitch_scale = 0.8 + r * 0.8
		wh.volume_db = (-17.0 + fx_db()) if back else -80.0
		if not eng.playing:
			eng.play(randf() * 0.9)
			wh.play(randf() * 0.9)

func engine(pos: Vector3, load_: float, heavy: bool) -> void:
	for a in eng_assigned:
		if a.distance_squared_to(pos) < 4.0:
			return
	var d = cam_dist(pos)
	if d < 90.0:
		play(s_engine, pos, -6.0 if heavy else -9.0, (0.55 if heavy else 0.8) + load_ * 0.5)
	elif heavy and d < 340.0:
		# armour you can't see yet: a deep rumble and the clatter of tracks carrying from far off,
		# heard from its direction (placed nearer so it isn't lost, and quieter the further it is)
		var cam = get_viewport().get_camera_3d()
		if cam != null:
			var dir = (pos - cam.global_position).normalized()
			play(s_rumble, cam.global_position + dir * 30.0, -10.0 - (d - 90.0) / 16.0, 0.8 + load_ * 0.3)

# tracks squealing as a tank turns
func squeal(pos: Vector3) -> void:
	var d = cam_dist(pos)
	if d < 180.0:
		play(s_squeal, pos, -8.0 - d / 30.0, randf_range(0.85, 1.15))

func _rumble() -> AudioStreamWAV:
	var n = int(0.45 * RATE)
	var out = PackedFloat32Array()
	out.resize(n)
	var lp = 0.0
	var lp2 = 0.0
	for i in range(n):
		var t = float(i) / RATE
		var env = minf(1.0, t * 12.0) * minf(1.0, (0.45 - t) * 12.0)
		lp += (randf() * 2.0 - 1.0 - lp) * 0.02
		lp2 += (randf() * 2.0 - 1.0 - lp2) * 0.15
		# a low growl, with the tracks' links clacking faintly over it
		var clack = (1.0 if fmod(t * 11.0, 1.0) < 0.06 else 0.0) * lp2 * 0.5
		var v = sin(TAU * 28.0 * t) * 0.4 + sin(TAU * 37.0 * t) * 0.25 + lp * 1.6 + clack
		out[i] = v * env * 0.7
	return _wav(out)

func _squeal() -> AudioStreamWAV:
	var n = int(0.7 * RATE)
	var out = PackedFloat32Array()
	out.resize(n)
	var ph = 0.0
	for i in range(n):
		var t = float(i) / RATE
		var env = minf(1.0, t * 20.0) * pow(maxf(0.0, 1.0 - t / 0.7), 1.4)
		var f = 1500.0 + 380.0 * sin(TAU * 7.0 * t) + 160.0 * sin(TAU * 23.0 * t)
		ph += TAU * f / RATE
		var v = sin(ph) * 0.45 + sin(ph * 1.51) * 0.2 + (randf() * 2.0 - 1.0) * 0.12
		out[i] = v * env * 0.35
	return _wav(out)

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
	ui_player.volume_db = (-4.0 if kill else -8.0) + fx_db()
	ui_player.play()

# ---------------------------------------------------------------- radio chatter (commander)
# short spoken reports over the radio when something happens: a click, then the line in one steady
# "radio operator" voice. Only one at a time, and never on top of a soldier's shout.
var radio_t = 0.0

func radio_say(_text: String) -> void:
	# (a click on the net when a message comes in: the words are on the screen, not read out)
	if G.attract or not G.started or G.sim_time < radio_t:
		return
	radio_t = G.sim_time + 3.5
	radio_click()


# ---------------------------------------------------------------- voices without words
# Men shout, grunt, cry out and scream, but nothing is said: each sound is a buzz from the throat pushed
# through two mouth resonances that slide from one vowel to another, with a rasp of breath on the front.
# Every man has his own pitch, so a section doesn't sound like one man.
const VOWEL = {"a": [800.0, 1250.0], "o": [520.0, 920.0], "e": [520.0, 1850.0], "i": [320.0, 2250.0], "u": [360.0, 820.0]}
var s_shouts: Array = []
var s_grunts: Array = []
var s_pains: Array = []
var s_screams: Array = []
var s_step_road: AudioStreamWAV = null
var s_step_floor: AudioStreamWAV = null
var s_reload: AudioStreamWAV = null
var s_pin: AudioStreamWAV = null
var s_door: AudioStreamWAV = null
var s_win: AudioStreamWAV = null
var s_lose: AudioStreamWAV = null
var s_horde: AudioStreamWAV = null
var horde_player: AudioStreamPlayer = null
var horde_k = 0.0
var horde_t = 0.0
var horde_want = 0.0
var sting_player: AudioStreamPlayer = null
var voice_t = 0.0

func _voice(len_s: float, f0: float, f1: float, va: String, vb: String, rough: float, burst: float) -> AudioStreamWAV:
	var n = int(len_s * RATE)
	var out = PackedFloat32Array()
	out.resize(n)
	var A: Array = VOWEL[va]
	var B: Array = VOWEL[vb]
	var ph = 0.0
	var l1 = 0.0
	var b1 = 0.0
	var l2 = 0.0
	var b2 = 0.0
	var wob = randf() * 6.0
	for i in range(n):
		var t = float(i) / RATE
		var k = t / len_s
		var f = lerpf(f0, f1, k) * (1.0 + 0.025 * sin(t * 34.0 + wob)) * (1.0 + (randf() - 0.5) * 0.05 * rough)
		ph += f / RATE
		var src = (2.0 * fmod(ph, 1.0) - 1.0) * 0.7 + (randf() * 2.0 - 1.0) * 0.45 * rough
		if t < burst:
			src += (randf() * 2.0 - 1.0) * 1.3 * (1.0 - t / burst)
		var c1 = 2.0 * sin(PI * lerpf(A[0], B[0], k) / RATE)
		var c2 = 2.0 * sin(PI * lerpf(A[1], B[1], k) / RATE)
		var h1 = src - l1 - 0.28 * b1
		b1 += c1 * h1
		l1 += c1 * b1
		var h2 = src - l2 - 0.22 * b2
		b2 += c2 * h2
		l2 += c2 * b2
		var env = minf(1.0, t / 0.012) * minf(1.0, (len_s - t) / 0.07)
		out[i] = clampf((b1 * 0.5 + b2 * 0.32) * env, -1.0, 1.0)
	return _wav(out)

# a short tap or knock: a click of noise and a decaying tone
func _knock(len_s: float, tone: float, decay: float, bright: float, vol: float) -> AudioStreamWAV:
	var n = int(len_s * RATE)
	var out = PackedFloat32Array()
	out.resize(n)
	var lp = 0.0
	for i in range(n):
		var t = float(i) / RATE
		lp += (randf() * 2.0 - 1.0 - lp) * bright
		out[i] = (lp * exp(-t / (decay * 0.5)) * 0.7 + sin(TAU * tone * t) * exp(-t / decay) * 0.6) * vol * minf(1.0, t * 900.0)
	return _wav(out)

func _mix_at(out: PackedFloat32Array, src: AudioStreamWAV, at_s: float, vol: float) -> void:
	var d: PackedByteArray = src.data
	var st = int(at_s * RATE)
	for i in range(d.size() / 2):
		if st + i >= out.size():
			break
		out[st + i] += d.decode_s16(i * 2) / 32000.0 * vol

# a few notes on a horn: [semitones above D4, seconds]
func _fanfare(notes: Array) -> AudioStreamWAV:
	var total = 0.0
	for nt in notes:
		total += nt[1]
	var n = int((total + 0.5) * MRATE)
	var out = PackedFloat32Array()
	out.resize(n)
	var at = 0.0
	for nt in notes:
		var f = 293.66 * pow(2.0, nt[0] / 12.0)
		var L: float = nt[1] + (0.45 if nt == notes[notes.size() - 1] else 0.03)
		var st = int(at * MRATE)
		for k in range(int(L * MRATE)):
			if st + k >= n:
				break
			var t = float(k) / MRATE
			var ph = TAU * f * t * (1.0 + 0.003 * sin(TAU * 5.0 * t))
			var env = minf(1.0, t / 0.03) * minf(1.0, (L - t) / 0.25)
			out[st + k] += (sin(ph) + 0.5 * sin(ph * 2.0) + 0.3 * sin(ph * 3.0) + 0.12 * sin(ph * 4.0)) * 0.2 * env
			out[st + k] += sin(ph * 0.5) * 0.12 * env
		at += nt[1]
	_norm(out, 0.92)
	return _wav_rate(out, MRATE)

# (Built a sound at a time over the first few seconds, a frame between each: made all at once they held
# the title screen back, most of all in a browser.)
var voices_ready = false

func _build_voices() -> void:
	var tree = get_tree()
	for k in range(20):
		await tree.process_frame
	# shouts: hey, go, ah, oi, ya, ho
	for v in [[0.3, 215.0, 255.0, "e", "i"], [0.28, 205.0, 170.0, "o", "u"], [0.36, 235.0, 200.0, "a", "a"], [0.32, 190.0, 245.0, "o", "i"], [0.28, 245.0, 205.0, "i", "a"], [0.26, 175.0, 205.0, "o", "o"]]:
		s_shouts.append(_voice(v[0], v[1], v[2], v[3], v[4], 0.25, 0.03))
		await tree.process_frame
	for v in [[0.14, 135.0, 108.0, "u", "o"], [0.18, 150.0, 118.0, "a", "o"], [0.12, 160.0, 125.0, "o", "u"]]:
		s_grunts.append(_voice(v[0], v[1], v[2], v[3], v[4], 0.55, 0.02))
		await tree.process_frame
	for v in [[0.42, 265.0, 170.0, "a", "a"], [0.3, 300.0, 205.0, "a", "e"], [0.36, 240.0, 160.0, "e", "o"]]:
		s_pains.append(_voice(v[0], v[1], v[2], v[3], v[4], 0.7, 0.03))
		await tree.process_frame
	for v in [[0.8, 335.0, 235.0, "a", "e"], [1.0, 380.0, 195.0, "a", "a"], [0.6, 305.0, 180.0, "e", "a"]]:
		s_screams.append(_voice(v[0], v[1], v[2], v[3], v[4], 0.5, 0.02))
		await tree.process_frame
	voices_ready = true
	s_step_road = _knock(0.07, 420.0, 0.012, 0.55, 0.5)
	s_step_floor = _knock(0.11, 150.0, 0.03, 0.3, 0.6)
	# a magazine change: out, in, and the bolt run forward
	var click = _knock(0.05, 2100.0, 0.008, 0.8, 0.6)
	var clack = _knock(0.08, 900.0, 0.015, 0.7, 0.8)
	var rl = PackedFloat32Array()
	rl.resize(int(0.75 * RATE))
	_mix_at(rl, click, 0.0, 0.8)
	_mix_at(rl, clack, 0.3, 0.8)
	_mix_at(rl, click, 0.52, 0.7)
	_mix_at(rl, clack, 0.58, 1.0)
	s_reload = _wav(rl)
	await tree.process_frame
	# the pin and the spoon: a thin ring and a tick after it
	var pn = PackedFloat32Array()
	pn.resize(int(0.3 * RATE))
	for i in range(pn.size()):
		var t = float(i) / RATE
		pn[i] = sin(TAU * 3400.0 * t) * 0.3 * exp(-t / 0.05) + sin(TAU * 5200.0 * t) * 0.15 * exp(-t / 0.03)
	_mix_at(pn, click, 0.16, 0.6)
	s_pin = _wav(pn)
	s_door = _knock(0.2, 95.0, 0.05, 0.25, 0.9)
	await tree.process_frame
	s_win = _fanfare([[0, 0.16], [4, 0.16], [7, 0.16], [12, 0.5], [7, 0.16], [12, 0.9]])
	await tree.process_frame
	s_lose = _fanfare([[7, 0.45], [5, 0.45], [3, 0.45], [0, 1.1]])
	sting_player = AudioStreamPlayer.new()
	add_child(sting_player)
	await tree.process_frame
	# the horde, heard before it's seen: a dozen of the dead moaning over one another, on a loop
	var hl = 3.2
	var hn = int(hl * RATE)
	var hb = PackedFloat32Array()
	hb.resize(hn)
	for vz in range(9):
		var g = _groan(randf_range(0.9, 1.6), randf_range(70.0, 150.0), randf_range(0.4, 0.9))
		var d: PackedByteArray = g.data
		var st = randi() % hn
		for i in range(d.size() / 2):
			hb[(st + i) % hn] += d.decode_s16(i * 2) / 32000.0 * 0.4
		await tree.process_frame
	_norm(hb, 0.9)
	s_horde = _wav(hb)
	s_horde.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s_horde.loop_begin = 0
	s_horde.loop_end = hn
	horde_player = AudioStreamPlayer.new()
	horde_player.stream = s_horde
	horde_player.volume_db = -80.0
	add_child(horde_player)

# a shout to go with a callout: no words, each man in his own voice
func bark(s, text: String) -> void:
	if not voices_ready or not G.started or G.attract or voice_t > G.sim_time or s.zombie:
		return
	var p: Vector3 = s.pos if s.state != "dead" else s.parts[0].global_position
	if cam_dist(p) > 60.0:
		return
	voice_t = G.sim_time + 0.12
	var pick = (s.id + text.length()) % s_shouts.size()
	play(s_shouts[pick], p, 1.0 if text.ends_with("!") else -2.0, _man_pitch(s), 0.0, occluded(p), 6000.0)

func _man_pitch(s) -> float:
	return 0.84 + fmod(absf(s.seed_) * 7.31, 1.0) * 0.34

# "grunt" (an effort: a throw, a shove, a climb), "pain" (hit and still up), "scream" (going down)
func voice(s, kind: String) -> void:
	if not voices_ready or s.zombie or not G.started:
		return
	var p: Vector3 = s.parts[0].global_position
	if cam_dist(p) > (70.0 if kind == "scream" else 40.0):
		return
	var bank: Array = s_grunts if kind == "grunt" else (s_pains if kind == "pain" else s_screams)
	play(bank[randi() % bank.size()], p, {"grunt": -6.0, "pain": 0.0, "scream": 3.0}[kind], _man_pitch(s) * randf_range(0.95, 1.05), 0.0, occluded(p), 7000.0)

func reload_snd(pos: Vector3) -> void:
	if s_reload != null and cam_dist(pos) < 22.0:
		play(s_reload, pos, -9.0, randf_range(0.92, 1.08))

func pin(pos: Vector3) -> void:
	if s_pin != null and cam_dist(pos) < 20.0:
		play(s_pin, pos, -8.0, randf_range(0.95, 1.1))

func door(pos: Vector3) -> void:
	if s_door != null and cam_dist(pos) < 45.0:
		play(s_door, pos, -5.0, randf_range(0.85, 1.1))

# the end of a battle: a rising call if you won it, a falling one if you didn't
func sting(won: bool) -> void:
	if sting_player == null or G.settings["music"] <= 0.0:
		return
	sting_player.stream = s_win if won else s_lose
	sting_player.volume_db = linear_to_db(maxf(G.settings["music"] * 2.0, 0.001)) + music_cut + 2.0
	sting_player.play()

# the moan of the horde: louder the more of them are up and the nearer the nearest is to where you're
# listening from, so a wave is heard coming before it's seen
func _horde_bed(dt: float) -> void:
	if horde_player == null:
		return
	var on = G.started and not G.over and not G.attract and G.mode == "horde"
	horde_t -= dt
	if on and horde_t <= 0.0:
		horde_t = 0.4
		var n = 0
		var near = 1e9
		for z in G.soldiers:
			if z.zombie and z.state != "dead":
				n += 1
				near = minf(near, ear_pos.distance_to(z.pos))
		horde_want = 0.0 if n == 0 else clampf(0.12 + minf(n, 40) / 40.0 * 0.4 + clampf(1.0 - near / 90.0, 0.0, 1.0) * 0.6, 0.0, 1.0)
	if not on:
		horde_want = 0.0
	horde_k = move_toward(horde_k, horde_want, dt * (0.35 if horde_want > horde_k else 0.6))
	horde_player.pitch_scale = 0.85 + horde_k * 0.25
	_loop_vol(horde_player, linear_to_db(maxf(horde_k, 0.001)) - 12.0 + fx_db(), horde_k > 0.02)
