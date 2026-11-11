extends Node3D
# Sets up the scene, runs the simulation tick, and handles game setup, spawning and game modes.

var env: Environment
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D
var reinf_t = [0.0, 0.0]
var markers: Node3D
var point_flags: Array = []
var spawn_flags: Array = []
var tick_us = 0
var prof = [0, 0]
var force_cls: Array = []   # classes for the next soldiers made (bought squads)
var spawn_q: Array = []      # soldiers still to be made, a couple a frame

func queue_spawn(f: Callable) -> void:
	spawn_q.append(f)
var sim_ms = 0.0        # smoothed cost of one simulation tick, for the performance readout
var tick_n = 0

func _ready() -> void:
	G.main = self
	randomize()
	_build_environment()
	G.fx = preload("res://scripts/fx.gd").new()
	add_child(G.fx)
	G.audio = preload("res://scripts/audio.gd").new()
	add_child(G.audio)
	G.world = preload("res://scripts/world.gd").new()
	add_child(G.world)
	G.pc = preload("res://scripts/player_cam.gd").new()
	G.pc.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(G.pc)
	G.ui = preload("res://scripts/ui.gd").new()
	add_child(G.ui)
	add_child(preload("res://scripts/editor.gd").new())
	G.navviz = NavViz.new()
	add_child(G.navviz)
	markers = Node3D.new()
	add_child(markers)
	preview_map("town")
	if "--autotest" in OS.get_cmdline_user_args():
		_autotest()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot_mode(a.substr(7))
		if a == "--maptest":
			_map_test()
		if a == "--breachtest":
			_breach_test()
		if a == "--basetest":
			_base_test()
		if a == "--vehtest":
			_veh_test()
		if a == "--camptest":
			_camp_test()
		if a == "--bigtest":
			_big_test()
		if a == "--doortest":
			_door_test()
		if a == "--laddertest":
			_ladder_test()
		if a == "--ordertest":
			_order_test()
		if a == "--spittest":
			_spit_test()
		if a == "--prodtest":
			_prod_test()
		if a == "--hordetest":
			_horde_test()
		if a == "--dogtest":
			_dog_test()
		if a == "--depottest":
			_depot_test()
		if a == "--econtest":
			_econ_test()
		if a == "--vtrace":
			_vtrace()
		if a == "--distest":
			_dis_test()
		if a == "--rtstest":
			_rts_test()
		if a == "--crouchtest":
			_crouch_test()
		if a == "--vfeattest":
			_vfeat_test()
		if a.begins_with("--uishot="):
			_ui_shot(a.substr(9))
		if a == "--stretchtest":
			_stretch_test()
		if a.begins_with("--mapshots="):
			_map_shots(a.substr(11))
		if a == "--camptest2":
			_camp_test2()
		if a == "--stairtest":
			_stair_test()
		if a == "--ambtest":
			_amb_test()
		if a == "--cbtest":
			_cb_test()
		if a.begins_with("--attest="):
			_at_test(a.substr(9))
		if a.begins_with("--lightshot="):
			_light_shot(a.substr(12))
		if a == "--ctltest":
			_ctl_test()
		if a.begins_with("--loadtest="):
			_load_test(a.substr(11))
		if a == "--recruittest":
			_recruit_test()
		if a.begins_with("--batchshot="):
			_batch_shot(a.substr(12))
		if a == "--ruintest":
			_ruin_test()
		if a.begins_with("--modetest="):
			_mode_test(a.substr(11))
		if a.begins_with("--edtest="):
			_editor_test(a.substr(9))

func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	var sm = ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.36, 0.52, 0.72)
	sm.sky_horizon_color = Color(0.68, 0.7, 0.71)
	sm.ground_horizon_color = Color(0.6, 0.6, 0.58)
	sm.ground_bottom_color = Color(0.3, 0.29, 0.26)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.72)
	env.ambient_light_energy = float(_arg("amb", "0.38"))
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = float(_arg("exp", "0.68"))
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.fog_enabled = true
	env.fog_light_color = Color(0.66, 0.69, 0.7)
	env.fog_density = 0.0016
	env.fog_aerial_perspective = 0.25
	env.fog_sky_affect = 0.6
	# a little more punch: contrast and colour
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.1
	env.adjustment_saturation = 1.18
	env.adjustment_brightness = 1.0
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.1
	sky_mat = sm
	var we = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = float(_arg("sun", "0.95"))
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.shadow_blur = 1.4
	sun.rotation = Vector3(deg_to_rad(-52), deg_to_rad(-35), 0)
	add_child(sun)
	apply_time()

# day, dusk or night: sky, light and how far soldiers can see
var clock = 0.25          # 0.25 = midday ... 0.6 = dusk ... 0.8 = night ... 1.25 = midday again
var clock_t = 0.0

var was_night = false

func _cycle_step(dt: float) -> void:
	var tm = G.settings["time"]
	if tm != "cycle" and tm != "dawn":
		return
	if tm == "dawn":
		# one long day: first light to full dark over about eighteen minutes, then it stays night
		if clock < 0.8:
			clock = minf(0.8, clock + dt * 0.72 / 1500.0)     # first light to dark in about twenty-five minutes
	else:
		# long days and short nights: about sixteen minutes of daylight, two and a half of darkness
		var c = fposmod(clock, 1.0)
		var night = c < 0.08 or c > 0.72
		clock += dt / 900.0 * (2.2 if night else 0.6)
	clock_t -= dt
	if clock_t <= 0.0:
		clock_t = 1.0
		apply_time()
		var n = is_night()
		if n != was_night and G.started and not G.over:
			for t in range(G.team_count()):
				G.ui.radio(t, "Night is falling. Lights out, keep your heads down." if n else "First light. Eyes open.")
		was_night = n

# the hour shown on the HUD for the passing day
func hour_text() -> String:
	var h = fposmod(6.0 + (fposmod(clock, 1.0) - 0.1) * 25.0, 24.0)
	return "%02d:%02d" % [int(h), int(fposmod(h, 1.0) * 60.0)]

func apply_time() -> void:
	var t = G.settings["time"]
	if t == "cycle" or t == "dawn":
		_blend_time(fposmod(clock, 1.0))
		return
	var amb = float(_arg("amb", "0.38"))
	var ex = float(_arg("exp", "0.68"))
	var sn = float(_arg("sun", "0.95"))
	sun.shadow_enabled = G.settings["shadows"]
	match t:
		"dusk":
			sky_mat.sky_top_color = Color(0.32, 0.36, 0.55)
			sky_mat.sky_horizon_color = Color(0.86, 0.55, 0.35)
			sky_mat.ground_horizon_color = Color(0.5, 0.36, 0.28)
			sun.light_color = Color(1.0, 0.68, 0.42)
			sun.light_energy = sn * 0.8
			sun.rotation = Vector3(deg_to_rad(-12), deg_to_rad(-70), 0)
			env.ambient_light_color = Color(0.62, 0.52, 0.5)
			env.ambient_light_energy = amb * 0.8
			env.fog_light_color = Color(0.72, 0.55, 0.45)
			env.tonemap_exposure = ex
			G.view_range = 110.0
		"night":
			sky_mat.sky_top_color = Color(0.02, 0.03, 0.07)
			sky_mat.sky_horizon_color = Color(0.06, 0.08, 0.14)
			sky_mat.ground_horizon_color = Color(0.04, 0.05, 0.08)
			sun.light_color = Color(0.55, 0.65, 0.9)
			sun.light_energy = 0.3
			sun.rotation = Vector3(deg_to_rad(-40), deg_to_rad(30), 0)
			env.ambient_light_color = Color(0.3, 0.38, 0.6)
			env.ambient_light_energy = 0.3
			env.fog_light_color = Color(0.04, 0.05, 0.09)
			env.tonemap_exposure = ex * 1.4
			G.view_range = 45.0
		_:
			sky_mat.sky_top_color = Color(0.36, 0.52, 0.72)
			sky_mat.sky_horizon_color = Color(0.7, 0.74, 0.76)
			sky_mat.ground_horizon_color = Color(0.6, 0.6, 0.58)
			sun.light_color = Color(1.0, 0.95, 0.86)
			sun.light_energy = sn
			sun.rotation = Vector3(deg_to_rad(-52), deg_to_rad(-35), 0)
			env.ambient_light_color = Color(0.62, 0.66, 0.72)
			env.ambient_light_energy = amb
			env.fog_light_color = Color(0.66, 0.69, 0.7)
			env.tonemap_exposure = ex
			G.view_range = 150.0
	sky_mat.ground_bottom_color = sky_mat.ground_horizon_color.darkened(0.5)
	if G.world != null:
		G.world.set_water_sky(sky_mat.sky_horizon_color.lerp(sky_mat.sky_top_color, 0.35))
	_storm_tint()

# campaign storm: grey sky, weak light, rain haze and shorter sight
func _storm_tint() -> void:
	env.fog_density = 0.0016
	if not G.storm:
		return
	var grey = Color(0.42, 0.45, 0.48)
	sky_mat.sky_top_color = sky_mat.sky_top_color.lerp(grey * 0.8, 0.75)
	sky_mat.sky_horizon_color = sky_mat.sky_horizon_color.lerp(grey, 0.7)
	sky_mat.ground_horizon_color = sky_mat.ground_horizon_color.lerp(grey * 0.85, 0.6)
	sun.light_energy *= 0.4
	env.ambient_light_energy *= 0.85
	env.fog_light_color = env.fog_light_color.lerp(grey, 0.7)
	env.fog_density = 0.0075
	G.view_range *= 0.72

func is_night() -> bool:
	return G.settings["time"] == "night" or ((G.settings["time"] == "cycle" or G.settings["time"] == "dawn") and G.view_range < 80.0)

# the cycle mixes the three looks: day (0.25), dusk (0.55), night (0.75), dawn back to day
func _blend_time(c: float) -> void:
	var keys = [[0.0, "night"], [0.06, "night"], [0.12, "dawn"], [0.22, "day"], [0.5, "day"], [0.62, "dusk"], [0.75, "night"], [1.0, "night"]]
	var a = keys[0]
	var b = keys[1]
	for i in range(keys.size() - 1):
		if c >= keys[i][0] and c <= keys[i + 1][0]:
			a = keys[i]
			b = keys[i + 1]
	var k = (c - a[0]) / maxf(0.0001, b[0] - a[0])
	var A = _tod(a[1])
	var B = _tod(b[1])
	sky_mat.sky_top_color = A[0].lerp(B[0], k)
	sky_mat.sky_horizon_color = A[1].lerp(B[1], k)
	if G.world != null:
		G.world.set_water_sky(sky_mat.sky_horizon_color)
	sky_mat.ground_horizon_color = A[2].lerp(B[2], k)
	sky_mat.ground_bottom_color = sky_mat.ground_horizon_color.darkened(0.5)
	sun.light_color = A[3].lerp(B[3], k)
	sun.light_energy = lerpf(A[4], B[4], k)
	env.ambient_light_color = A[5].lerp(B[5], k)
	env.ambient_light_energy = lerpf(A[6], B[6], k)
	env.fog_light_color = A[7].lerp(B[7], k)
	G.view_range = lerpf(A[8], B[8], k)
	# the sun climbs from the east at dawn, peaks around noon and goes down in the west at dusk
	var day_k = clampf((c - 0.1) / 0.56, 0.0, 1.0)
	var elev = lerpf(-5.0, -62.0, sin(day_k * PI))
	if c < 0.08 or c > 0.7:
		elev = -40.0       # moonlight
	sun.rotation = Vector3(deg_to_rad(elev), deg_to_rad(-100.0 + day_k * 160.0), 0)
	sun.shadow_enabled = G.settings["shadows"]
	_storm_tint()

func _tod(n: String) -> Array:
	match n:
		"dawn":
			return [Color(0.38, 0.45, 0.62), Color(0.95, 0.7, 0.6), Color(0.56, 0.45, 0.42), Color(1.0, 0.78, 0.6), 0.62, Color(0.6, 0.58, 0.66), 0.3, Color(0.78, 0.66, 0.62), 115.0]
		"dusk":
			return [Color(0.32, 0.36, 0.55), Color(0.86, 0.55, 0.35), Color(0.5, 0.36, 0.28), Color(1.0, 0.68, 0.42), 0.76, Color(0.62, 0.52, 0.5), 0.3, Color(0.72, 0.55, 0.45), 110.0]
		"night":
			return [Color(0.02, 0.03, 0.07), Color(0.06, 0.08, 0.14), Color(0.04, 0.05, 0.08), Color(0.55, 0.65, 0.9), 0.22, Color(0.3, 0.38, 0.6), 0.2, Color(0.04, 0.05, 0.09), 45.0]
	return [Color(0.45, 0.55, 0.66), Color(0.68, 0.7, 0.71), Color(0.6, 0.6, 0.58), Color(1.0, 0.95, 0.86), 0.95, Color(0.62, 0.66, 0.72), 0.38, Color(0.66, 0.69, 0.7), 150.0]

func follow_sun(_cam_pos: Vector3, _fwd: Vector3) -> void:
	pass   # directional shadows already follow the camera in Godot

# ---------------------------------------------------------------- setting up battles
func _clear() -> void:
	if G.player != null:
		G.pc.leave_soldier()
	for v in G.vehicles.duplicate():
		v.remove()
	G.vehicles.clear()
	for s in G.soldiers:
		if is_instance_valid(s):
			s._drop_chute()
			s.queue_free()
	G.soldiers.clear()
	G.squads.clear()
	AI.batch_stack.clear()
	Combat.clear_all()
	G.fx.clear_all()
	if G.ui.nv != null:
		G.ui.nv_on = false
		G.ui.nv.visible = false
	G.score = []
	G.cap_score = []
	for t in range(G.team_count()):
		G.score.append(0)
		G.cap_score.append(0.0)
	G.cap_owner = -1
	G.cap_prog = 0.0
	G.over = false
	G.game_time = 0.0
	G.orders = []
	for t in range(4):
		G.orders.append({"mode": "free", "point": null})
	get_tree().paused = false
	Engine.time_scale = 1.0

func quit_to_title() -> void:
	var m = G.map_id if G.map_id != "custom" else "town"
	Modes.daily = {}
	Campaign.active = false
	preview_map(m)

func preview_map(id: String) -> void:
	_clear()
	G.started = false
	G.world.load_map(id)
	refresh_markers()

func start_game(o: Dictionary) -> void:
	_clear()
	spawn_q.clear()
	Prep.reset()
	G.storm = false
	G.fx.set_storm(false)
	if G.ui.title != null:
		G.ui.title.visible = false
		G.ui.menu.visible = false
	G.mode = o.get("mode", "sandbox")
	G.factions = o.get("factions", G.factions).duplicate()
	if Campaign.active:
		G.factions = ["army", "army", "army", "army"]
	G.teams = clampi(o.get("teams", G.teams), 2, 4)
	if G.mode in ["frontline", "assault", "laststand", "breakthrough", "sabotage", "siege", "escort", "rescue", "koth", "commander", "horde", "general"]:
		G.teams = 2
	G.pc.set_rts(false)
	G.apply_teams()
	G.score = []
	G.cap_score = []
	for t in range(G.team_count()):
		G.score.append(0)
		G.cap_score.append(0.0)
	G.team_size = o.get("size", 10)
	G.team_caps = o.get("caps", [])
	if G.mode == "sabotage":
		var keep_t = G.settings["time"]
		G.settings["time"] = "night"
		apply_time()
		G.settings["time"] = keep_t
	if G.settings["time"] == "dawn":
		clock = 0.08
		apply_time()
	was_night = is_night()
	G.limit = o.get("limit", G.default_limit(G.mode))
	G.reinforce = o.get("reinforce", true)
	G.reinf_mode = o.get("reinf_mode", G.reinf_mode)
	G.armor = o.get("armor", G.armor)
	G.world.load_map(o.get("map", "town"))
	Stats.reset()
	Reinforce.reset()
	Obj.reset()
	Commander.reset()
	Support.reset()
	Comms.reset()
	Build.reset()
	Modes.reset()
	Build.setup_bases()
	Obj.setup_mode()
	for t in range(G.team_count()):
		if (G.mode == "laststand" or G.mode == "horde") and t == 1:
			continue
		var n_here = G.size_of(t) if o.get("armies", true) else 0
		if G.mode == "sabotage" and t == 0:
			n_here = maxi(4, G.team_size / 2)
		# a campaign army fights with the men it actually has, class by class
		var cl_list: Array = o.get("cls", [])
		if t < cl_list.size() and not cl_list[t].is_empty():
			force_cls = cl_list[t].duplicate()
		for i in range(n_here):
			if G.mode == "laststand":
				var c: Vector3 = Obj.points[0]["p"]
				spawn_soldier(0, c.x + randf_range(-8, 8), c.z + randf_range(-8, 8), "")
			else:
				base_spawn(t)
		force_cls = []
		if G.mode == "sabotage" and t == 0:
			# the raiders: satchels, knives, wire cutters, and silenced pistols for half of them
			var k = 0
			for sd in G.soldiers:
				if sd.team == 0:
					sd.satchels = 2
					sd.set_meta("knife", true)
					if k % 2 == 0 and not sd.W["rocket"]:
						sd.set_weapon("silenced")
					k += 1
		elif not (G.mode == "escort" and t == 0) and o.get("armies", true) and not (Campaign.active and t == 0) and not o.get("armies_veh", false):
			_starting_vehicles(t)
	Modes.setup()
	Ferry.setup()
	Medical.reset_hospitals()
	Faction.setup()
	Fog.reset()
	Tactics.reset()
	RadioPack.reset()
	Salvage.reset()
	if o.get("armies", true) and G.armor != "none":
		Salvage.place(3 if G.world.is_large() else 2)
	Ops.reset()
	Stretcher.reset()
	Prod.reset()
	if G.mode not in ["sandbox", "horde"] and G.team_count() == 2:
		G.ui.radio(0, "Your commander is %s" % Commander.STYLE_TEXT[Commander.style_of(0)])
	Scripted.reset()
	if G.map_id == "custom":
		Scripted.setup(G.custom_map)
		if not o.get("armies", true):
			G.team_size = maxi(Scripted.placed_count(G.custom_map, 0), Scripted.placed_count(G.custom_map, 1))
	G.started = true
	refresh_markers()
	G.pc.free_pos = Vector3(-62, G.world.ground_y(-62, -6) + 7.0, -6)
	G.pc.free_yaw = PI / 2.0 + 0.12
	G.pc.free_pitch = -0.12
	G.started = true

func spawn_soldier(team: int, x: float, z: float, wid: String):
	var cap = mini(int(G.settings["max_soldiers"]), maxi(160, G.team_size * G.teams + 60))
	if G.soldiers.size() >= cap:
		cleanup_bodies(true)
	if G.soldiers.size() >= cap:
		return null
	var p = Vector3(x, G.world.ground_y(x, z), z)
	p = G.world.push_out_circle(p, 0.35)[0]
	var s = Soldier.new()
	add_child(s)
	var cl = "rifleman" if wid != "" else (force_cls.pop_front() if not force_cls.is_empty() else Faction.pick_class(team))
	# a side that keeps meeting enemy armour sends more anti-tank men
	if wid == "" and cl == "rifleman" and randf() < Ops.at_bias(team):
		cl = "at"
	if wid == "":
		wid = Faction.weapon_for(team, cl)
	s.setup(team, p.x, p.z, wid)
	s.set_class(cl)
	var tgt: Vector3 = G.world.capture
	s.face(atan2(tgt.x - p.x, (tgt.z - p.z) * 0.3))
	G.soldiers.append(s)
	Stats.register(s)
	AI.assign_squad(s)
	return s

# a vehicle with its crew (driver, and a gunner if it has a gun)
func spawn_vehicle(kind: String, team: int, p: Vector3, yaw: float, crew: bool = true):
	p = Vector3(p.x, G.world.ground_y(p.x, p.z), p.z)
	var v = Vehicle.make(kind, team, p, yaw)
	if crew:
		AI.batch_begin(AI.CREW)
		var d = spawn_soldier(team, p.x, p.z, "rifle")
		if d != null:
			d.mount(v, 0)
		var gs = v.gunner_seat()
		if gs >= 0:
			var g = spawn_soldier(team, p.x, p.z, "rifle")
			if g != null:
				g.mount(v, gs)
		for i in range(v.seats.size()):
			if v.spec["seats"][i]["pose"] == "hatch" and v.seats[i] == null:
				var c = spawn_soldier(team, p.x, p.z, "rifle")
				if c != null:
					c.mount(v, i)
		AI.batch_end()
	return v

func _starting_vehicles(t: int) -> void:
	if G.armor == "none":
		return
	var home: Vector3 = G.world.rally_point(t)
	var enemy: Vector3 = G.world.capture
	var yaw = atan2(enemy.x - home.x, enemy.z - home.z)
	var side = Vector3(cos(yaw), 0, -sin(yaw))
	spawn_vehicle(Faction.vehicle_kind(t, "jeep"), t, _free_spot(home + side * 16.0), yaw)
	if G.armor == "heavy":
		spawn_vehicle(Faction.vehicle_kind(t, "tank"), t, _free_spot(home - side * 18.0), yaw)
	# a mortar pit at the base and machine-gun nests out in front of it (two-sided battles only, to keep it fast)
	if G.team_count() > 2:
		return
	var fwd = G.flat(enemy - home).normalized()
	spawn_vehicle("mortar", t, _free_spot(home - fwd * 6.0 + side * 6.0), yaw)
	if G.mode != "laststand" and G.mode != "sabotage" and not Faction.militia(t):
		spawn_vehicle("radar", t, _free_spot(home - fwd * 16.0 - side * 8.0), yaw)
	# (no anti-tank gun at the start: it's bought once enemy armour shows up, and then sets up behind the line)
	if G.mode != "laststand" or t == 0:
		for k in [-1.0, 1.0]:
			var np = _free_spot(home + fwd * minf(40.0, G.dist2d(home, enemy) * 0.3) + side * k * 14.0)
			spawn_vehicle("nest", t, np, yaw)

func _free_spot(p: Vector3) -> Vector3:
	for k in range(20):
		var q = p + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * k * 1.5
		var clear = true
		for dx in [-2.5, 0.0, 2.5]:
			for dz in [-3.5, 0.0, 3.5]:
				if G.world.inside_any(q.x + dx, q.z + dz, 0.5):
					clear = false
		if clear:
			return q
	return p

func base_spawn(team: int) -> void:
	var b: Vector3 = G.world.spawn[team]
	if Build.bases_matter():
		var sp = Build.spawn_pos(team)
		if sp == null:
			return
		b = sp
	for k in range(6):
		var x = b.x + randf_range(-8, 8)
		var z = b.z + randf_range(-14, 14)
		if not G.world.inside_any(x, z, 0.4):
			spawn_soldier(team, x, z, "")
			return
	spawn_soldier(team, b.x, b.z, "")

func cleanup_bodies(force: bool) -> void:
	var dead = G.soldiers.filter(func(s): return s.state == "dead" and s != G.player)
	var lim = maxi(0, dead.size() - 10) if force else 60
	if dead.size() > lim:
		dead.sort_custom(func(a, b): return a.dead_t > b.dead_t)
		for i in range(dead.size() - lim):
			G.soldiers.erase(dead[i])
			dead[i].queue_free()

func clear_bodies() -> void:
	for s in G.soldiers.duplicate():
		if s.state == "dead" and s != G.player:
			G.soldiers.erase(s)
			s.queue_free()

# ---------------------------------------------------------------- simulation
func _physics_process(_delta: float) -> void:
	if not G.started:
		return
	var t0 = Time.get_ticks_usec()
	_sim_step()
	var used = Time.get_ticks_usec() - t0
	tick_us += used
	tick_n += 1
	sim_ms = lerpf(sim_ms, used / 1000.0, 0.05)

func _sim_step() -> void:
	G.sim_time += G.DT
	Prep.step(G.DT)
	if not G.over and not Prep.active():
		G.game_time += G.DT
	G.path_budget = 4
	for k in range(mini(2, spawn_q.size())):
		var f: Callable = spawn_q.pop_front()
		f.call()
	Reinforce.step(G.DT)
	Build.step(G.DT)
	var ta = Time.get_ticks_usec()
	for v in G.vehicles.duplicate():
		if is_instance_valid(v):
			v.step(G.DT)
	var tb = Time.get_ticks_usec()
	G.rebuild_sgrid()
	# performance: frozen far-away soldiers think and move every other tick, with a double time step
	var big = G.soldiers.size() >= 50
	var fr = Engine.get_physics_frames()
	for s in G.soldiers.duplicate():
		if not is_instance_valid(s):
			continue
		if big and s.lod_frozen and s.state == "alive":
			if (fr + s.id) % 2 != 0:
				s.lod_glide()
				continue
			G.DT = 2.0 / 60.0
			s.tick()
			G.DT = 1.0 / 60.0
		else:
			s.tick()
	var tc = Time.get_ticks_usec()
	prof[0] += tb - ta
	prof[1] += tc - tb
	Doors.step()
	Combat.step_grenades()
	Combat.step_rockets()
	Combat.step_strikes()
	Combat.step_flares()
	Combat.step_mines()
	Combat.step_fires()
	G.fx.step(G.DT)
	Stats.step(G.DT)
	Squad.step(G.DT)
	Support.step(G.DT)
	Fog.step(G.DT)
	Prod.step(G.DT)
	if not Prep.active():
		Commander.step(G.DT)
		Ops.step(G.DT)
	Stretcher.step(G.DT)
	if not Prep.active():
		Obj.step(G.DT)
	Modes.step(G.DT)
	Ferry.step(G.DT)
	Medical.hospitals_tick(G.DT)
	Faction.step(G.DT)
	Comms.step(G.DT)
	Scripted.step(G.DT)
	if randf() < 0.05:
		cleanup_bodies(false)

func _process(dt: float) -> void:
	if G.started:
		_cycle_step(dt * Engine.time_scale)
	G.fx.update_callouts(dt)
	G.ui.update_hud(dt)
	for f in point_flags:
		if is_instance_valid(f):
			f.get_child(1).rotation.y = sin(Time.get_ticks_msec() * 0.003 + f.position.x) * 0.3

func on_kill(_s, _attacker) -> void:
	Obj.on_death(_s)
	Scripted.on_death(_s)
	if G.mode == "deathmatch" and not G.over:
		for t in range(2):
			if G.score[t] >= G.limit:
				end_game(t)

func end_game(t: int) -> void:
	if G.over:
		return
	G.over = true
	if G.player != null:
		G.pc.leave_soldier()
	G.ui.show_win(t)
	var dres = Modes.daily_over(t)
	if dres != "":
		G.ui.message(dres)
	if Campaign.active:
		var res = Campaign.battle_over(t)
		G.ui.campaign_result(res)

func on_point_changed(i: int, prev: int, owner: int) -> void:
	var pt = Obj.points[i]
	_set_flag_color(point_flags[i] if i < point_flags.size() else null, G.TEAM_BAND[owner] if owner >= 0 else Color(0.85, 0.85, 0.85))
	if owner >= 0:
		Support.earn(owner, 10)
		G.ui.message("%s captured point %s" % [G.TEAM_NAMES[owner], pt["name"]])
		G.ui.radio(owner, "Point %s is ours!" % pt["name"])
		for s in G.soldiers:
			if s.state != "dead" and s.team < 2:
				if s.team == owner:
					Morale.boost(s, 10.0)
				else:
					Morale.shock(s, 6.0)
	elif prev >= 0:
		G.ui.message("%s lost point %s" % [G.TEAM_NAMES[prev], pt["name"]])
	for q in G.squads:
		q["obj_t"] = -1.0

# ---------------------------------------------------------------- flags
func _make_flag(col: Color, big: bool) -> Node3D:
	var g = Node3D.new()
	var pole = MeshInstance3D.new()
	var pm = BoxMesh.new()
	pm.size = Vector3(0.08, 3.2, 0.08)
	pole.mesh = pm
	pole.position.y = 1.6
	g.add_child(pole)
	var fl = MeshInstance3D.new()
	var fm = BoxMesh.new()
	fm.size = Vector3(0.9, 0.55, 0.03)
	fl.mesh = fm
	var mat = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fl.material_override = mat
	fl.position = Vector3(0.47, 2.85, 0)
	g.add_child(fl)
	var ring = MeshInstance3D.new()
	var tm = TorusMesh.new()
	tm.inner_radius = 7.6 if big else 1.2
	tm.outer_radius = 8.0 if big else 1.45
	ring.mesh = tm
	var rm = StandardMaterial3D.new()
	rm.albedo_color = Color(col.r, col.g, col.b, 0.6)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = rm
	ring.scale = Vector3(1, 0.05, 1)
	ring.position.y = 0.1
	g.add_child(ring)
	markers.add_child(g)
	return g

func _set_flag_color(f: Node3D, col: Color) -> void:
	if f == null:
		return
	f.get_child(1).material_override.albedo_color = col
	f.get_child(2).material_override.albedo_color = Color(col.r, col.g, col.b, 0.6)

func refresh_markers() -> void:
	for c in markers.get_children():
		c.queue_free()
	spawn_flags = []
	for t in range(G.team_count()):
		spawn_flags.append(_make_flag(G.TEAM_BAND[t], false))
	for t in range(G.team_count()):
		var p: Vector3 = G.world.spawn[t]
		spawn_flags[t].position = Vector3(p.x, G.world.ground_y(p.x, p.z), p.z)
	point_flags = []
	var pts = Obj.points
	if not G.started:
		pts = []
		for o in G.world.objectives:
			pts.append({"p": o["p"], "name": o["name"], "owner": -1})
	for pt in pts:
		var f = _make_flag(G.TEAM_BAND[pt["owner"]] if pt["owner"] >= 0 else Color(0.85, 0.85, 0.85), true)
		var c: Vector3 = pt["p"]
		f.position = Vector3(c.x, G.world.ground_y(c.x, c.z), c.z)
		var lbl = Label3D.new()
		lbl.text = pt["name"]
		lbl.font_size = 96
		lbl.pixel_size = 0.02
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.modulate = Color(1, 1, 1, 0.85)
		lbl.position = Vector3(0, 5.0, 0)
		f.add_child(lbl)
		point_flags.append(f)

# ---------------------------------------------------------------- automatic test (run by the GitHub build)
func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, true).timeout

func _report(tag: String) -> void:
	var bl = []
	for st in Build.sites:
		bl.append("%s%d:%s" % [st["kind"], st["team"], "dead" if st["dead"] else ("ok" if st["done"] else "%d%%" % int(100.0 * st["work"] / st["need"]))])
	var lean_n = 0
	var ctypes = {}
	for o in G.soldiers:
		if o.state == "alive" and o.in_cover and o.cover != null:
			ctypes[o.cover.type] = ctypes.get(o.cover.type, 0) + 1
			if o.cover.type == "wall" and o.cover.side != 0.0:
				lean_n += 1
	print("AUTOTEST %s | cover types %s" % [tag, str(ctypes)])
	var qo = []
	for q in G.squads:
		qo.append("%d:%s" % [q["team"], str(q.get("obj", -1))])
	print("AUTOTEST %s | squad objectives %s" % [tag, " ".join(qo)])
	print("AUTOTEST %s | builds %s | spawnable %s | wall-leaners %d" % [tag, ", ".join(bl), str([Build.can_respawn(0), Build.can_respawn(1)]), lean_n])
	var alive = [G.alive_count(0), G.alive_count(1)]
	var dead = G.soldiers.filter(func(s): return s.state == "dead").size()
	var ms = (tick_us / 1000.0) / maxi(tick_n, 1)
	var mor = [0.0, 0.0]
	var brk = [0, 0]
	var low = [0, 0]
	var cnt = [0, 0]
	for o in G.soldiers:
		if o.state == "alive" and o.team < 2:
			mor[o.team] += o.morale
			cnt[o.team] += 1
			if o.broken:
				brk[o.team] += 1
			if o.ammo_frac() < 0.3:
				low[o.team] += 1
	var leaders = 0
	for q in G.squads:
		if q.get("leader") != null and is_instance_valid(q["leader"]) and q["leader"].state != "dead":
			leaders += 1
	print("AUTOTEST %s | morale %d/%d broken %d/%d lowammo %d/%d leaders %d/%d squads | routs %d/%d shots %d/%d hits %d/%d" % [tag, int(mor[0] / maxi(cnt[0], 1)), int(mor[1] / maxi(cnt[1], 1)), brk[0], brk[1], low[0], low[1], leaders, G.squads.size(), Stats.teams[0]["routs"], Stats.teams[1]["routs"], Stats.teams[0]["shots"], Stats.teams[1]["shots"], Stats.teams[0]["hits"], Stats.teams[1]["hits"]])
	var vs = []
	for v in G.vehicles:
		var crew = 0
		for q in v.seats:
			if q != null:
				crew += 1
		vs.append("%s%d hp%d crew%d spd%.1f%s%s" % [v.kind, v.team, int(v.hp), crew, v.speed, " WRECK" if v.dead else "", (" st%d d%.0f" % [v.mission.get("stage", -1), G.dist2d(v.pos, v.mission.get("drop", v.pos))]) if v.mission != null else ""])
	var rid = 0
	var chu = 0
	for o in G.soldiers:
		if o.state == "riding":
			rid += 1
		elif o.state == "chute":
			chu += 1
	print("AUTOTEST %s | vehicles: %s | riding %d chute %d" % [tag, ", ".join(vs), rid, chu])
	var cen = []
	for t in range(G.team_count()):
		var c = Vector3.ZERO
		var n = 0
		for o in G.soldiers:
			if o.team == t and o.state != "dead":
				c += o.pos
				n += 1
		cen.append("t%d spawn(%d,%d) avg(%d,%d)" % [t, int(G.world.spawn[t].x), int(G.world.spawn[t].z), int(c.x / maxi(n, 1)), int(c.z / maxi(n, 1))])
	print("AUTOTEST %s | %s" % [tag, " ".join(cen)])
	var kn = _knee_stats()
	print("AUTOTEST %s | knees ok/backward: body %d/%d, target %d/%d" % [tag, kn[0], kn[1], kn[2], kn[3]])
	print("AUTOTEST %s | teams %d alive %s" % [tag, G.team_count(), str(range(G.team_count()).map(func(t): return G.alive_count(t)))])
	print("AUTOTEST %s | prof vehicles %.2f soldiers %.2f ms/tick" % [tag, prof[0] / 1000.0 / maxi(tick_n, 1), prof[1] / 1000.0 / maxi(tick_n, 1)])
	prof = [0, 0]
	var inb = 0
	for o in G.soldiers:
		if o.state == "alive" and Squad._building_at(o.pos) != null:
			inb += 1
	print("AUTOTEST %s | soldiers inside buildings %d" % [tag, inb])
	print("AUTOTEST %s | squad events %s | officers %s" % [tag, str(Squad.events), str(range(G.team_count()).map(func(t): return Commander.officer(t) != null))])
	print("AUTOTEST %s | alive %d v %d | dead %d | score %d-%d | sim %.2f ms/tick" % [tag, alive[0], alive[1], dead, G.score[0], G.score[1], ms])
	tick_us = 0
	tick_n = 0

func _autotest() -> void:
	print("AUTOTEST start")
	var scen = [["town", "capture", 30.0, "truck"], ["field", "capture", 30.0, "para"], ["trenches", "capture", 30.0, "truck"], ["valley", "capture", 60.0, "truck"],
		["valley", "frontline", 75.0, "heli"], ["front", "assault", 50.0, "para"], ["town", "laststand", 45.0, "truck"],
		["field", "capture", 40.0, "truck", 4, "night"], ["town", "deathmatch", 30.0, "para", 3, "dusk"],
		["field", "destroy", 45.0, "truck"], ["town", "breakthrough", 35.0, "truck"], ["field", "sabotage", 35.0, "truck"], ["town", "siege", 35.0, "truck"], ["factory", "capture", 35.0, "truck"],
		["field", "horde", 30.0, "truck"], ["town", "koth", 25.0, "truck"], ["field", "escort", 30.0, "truck"], ["field", "rescue", 25.0, "truck"], ["town", "general", 30.0, "truck"], ["river", "frontline", 30.0, "truck"]]
	var only = _arg("scen", "")
	for sc in scen:
		var m = sc[0]
		if only != "" and only != m + ":" + sc[1]:
			continue
		var tag = m + "/" + sc[1]
		var nteams = sc[4] if sc.size() > 4 else 2
		G.settings["time"] = sc[5] if sc.size() > 5 else "day"
		apply_time()
		tag += " %dt %s" % [nteams, G.settings["time"]]
		start_game({"map": m, "mode": sc[1], "size": 10, "limit": 100, "reinforce": true, "armor": "heavy", "reinf_mode": sc[3], "teams": nteams})
		await _wait(12.0)
		_report(tag + " 12s")
		var s = null
		for o in G.soldiers:
			if o.state == "alive":
				s = o
				break
		if s != null:
			G.pc.possess(s)
			await _wait(3.0)
			if G.player != null:
				G.pc.leave_soldier()
		# orders: send three soldiers somewhere and a squad following someone
		var picked = G.soldiers.filter(func(o): return o.team == 0 and o.state == "alive" and o.vehicle == null).slice(0, 3)
		var goal = G.world.spawn[0] + Vector3(6, 0, 6)
		for o in picked:
			o.order = {"mode": "move", "point": goal}
			o.decide_t = 0.0
		var lead = null
		for o in G.soldiers:
			if o.team == 1 and o.state == "alive" and o.vehicle == null and o.squad != null and o.squad["members"].size() > 2:
				lead = o
				break
		if lead != null:
			G.pc._toggle_follow(lead)
		Combat.explode(G.world.capture + Vector3(0, 0.5, 0), null, 1.0)
		Combat.mortar_strike(G.world.capture, 4)
		if sc.size() <= 4:
			for t in range(2):
				Support.points[t] = 200
			Support.call_in(0, "gunship", G.world.capture)
			Support.call_in(0, "airstrike", G.world.capture)
			Support.call_in(1, "armoredcar", G.world.capture)
			Support.call_in(1, "halftrack", G.world.capture)
			Support.call_in(0, "motorbike", G.world.capture)
			Support.call_in(1, "artillery", G.world.capture)
		await _wait(10.0)
		var dd = []
		for o in picked:
			if is_instance_valid(o) and o.state == "alive":
				dd.append(int(G.dist2d(o.pos, goal)))
		var fd = []
		if lead != null and is_instance_valid(lead):
			for mb in lead.squad["members"]:
				if is_instance_valid(mb) and mb != lead and mb.state == "alive":
					fd.append(int(G.dist2d(mb.pos, lead.pos)))
		print("AUTOTEST %s | ordered soldiers dist to goal %s | followers dist to leader %s" % [tag, str(dd), str(fd)])
		await _wait(maxf(1.0, sc[2] - 25.0))
		_report(tag + " %ds" % int(sc[2]))
		var pts = []
		for pt in Obj.points:
			pts.append("%s:%d%s" % [pt["name"], pt["owner"], "*" if pt["contested"] else ""])
		print("AUTOTEST %s | points %s | %s | over=%s" % [tag, " ".join(pts), Obj.status_text(), G.over])
	print("AUTOTEST done")
	get_tree().quit()

# ---------------------------------------------------------------- screenshot mode (development aid)
# --shot=OUTDIR [--map=town] [--wait=6] [--size=6]
func _arg(name: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="):
			return a.substr(name.length() + 3)
	return def

func _snap(dir: String, name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "/" + name + ".png")

func _look(from: Vector3, at: Vector3) -> void:
	G.pc.free_pos = from
	var d = at - from
	G.pc.free_yaw = atan2(d.x, d.z)
	G.pc.free_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	await get_tree().process_frame
	await get_tree().process_frame

func _shot_mode(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	G.settings["time"] = _arg("time", "day")
	apply_time()
	G.ui.visible = false
	G.pc.force_free = true
	await _wait(0.5)
	start_game({"map": _arg("map", "town"), "mode": _arg("mode", "capture"), "size": int(_arg("size", "6")), "limit": 9999, "reinforce": true,
		"armor": _arg("armor", "light"), "reinf_mode": _arg("reinf", "truck"), "teams": int(_arg("teams", "2")),
		"factions": (_arg("fac", "army,army") + ",army,army").split(","), "armies": _arg("armies", "1") != "0"})
	if _arg("milshot", "") != "":
		# a few militia fighters and a technical up close
		await _wait(1.0)
		var ms = G.soldiers.filter(func(x): return x.team == 0 and x.state == "alive" and x.vehicle == null)
		if not ms.is_empty():
			var m0 = ms[0]
			var f0 = Vector3(sin(m0.body_yaw), 0, cos(m0.body_yaw))
			await _look(m0.pos + f0 * 4.0 + Vector3(1.5, 1.7, 0), m0.pos + Vector3(0, 1.0, 0))
			await _snap(dir, "militia")
	if _arg("faceshot", "") != "":
		# a line of soldiers seen close up: faces, then the whole kit
		for s0 in G.soldiers.duplicate():
			if s0.state != "dead":
				s0.queue_free()
				G.soldiers.erase(s0)
		var bnd2: Rect2 = G.world.bounds
		var cp: Vector3 = G.world.capture
		for tries in range(300):
			var q2 = Vector3(randf_range(bnd2.position.x + 30, bnd2.end.x - 30), 0, randf_range(bnd2.position.y + 30, bnd2.end.y - 30))
			if G.world.cols_in_rect(q2.x - 10, q2.z - 10, q2.x + 10, q2.z + 10).is_empty() and not G.world.in_water(q2.x, q2.z):
				cp = q2
				break
		var row = []
		for i in range(5):
			var sx = spawn_soldier(int(_arg("fteam", "0")), cp.x + (i - 2) * 0.9, cp.z, "")
			if sx != null:
				sx.order = {"mode": "hold", "point": sx.pos}
				sx.face(0.0)
				if _arg("fwid", "") != "":
					sx.set_weapon(_arg("fwid", "").split(",")[i % _arg("fwid", "").split(",").size()])
				row.append(sx)
		await _wait(1.2)
		for sx in row:
			sx.face(0.0)
			sx.aim_yaw = 0.0
		await _wait(0.4)
		await _look(cp + Vector3(0.0, 1.62, 2.3), cp + Vector3(0, 1.5, 0))
		await _snap(dir, "faces")
		await _look(cp + Vector3(1.2, 1.4, 4.6), cp + Vector3(0, 0.9, 0))
		await _snap(dir, "kit")
		await _look(cp + Vector3(2.4, 1.7, 1.2), cp + Vector3(0.4, 1.3, 0))
		await _snap(dir, "kit_side")
	if _arg("zombieshot", "") != "":
		# a mixed pack of the dead walking past, each with its own gait
		for s0 in G.soldiers.duplicate():
			if s0.state != "dead":
				s0.queue_free()
				G.soldiers.erase(s0)
		var zc: Vector3 = _free_spot(G.world.capture)
		var bait = spawn_soldier(0, zc.x - 26.0, zc.z, "pistol")
		bait.order = {"mode": "hold", "point": bait.pos}
		bait.mag = 0
		bait.reserve = 0
		var kinds = ["walker", "walker", "walker", "runner", "brute", "armored", "bloater", "spitter", "walker", "runner"]
		for i in range(kinds.size()):
			Soldier.zombie_next = kinds[i]
			var zz = spawn_soldier(1, zc.x + (i % 5) * 1.6, zc.z - 4.0 + (i / 5) * 3.0 + (i % 5) * 0.8, "pistol")
			Soldier.zombie_next = ""
			if zz != null:
				Modes.make_zombie(zz, kinds[i])
		await _wait(float(_arg("zombieshot", "2.0")))
		print("ZOMBIESHOT spits ", Modes.spits.size(), " puddles ", Modes.puddles.size(), " bait hp ", bait.hp)
		await _look(zc + Vector3(-6.0, 1.8, 9.0), zc + Vector3(-6.0, 1.0, 0))
		await _snap(dir, "zombies")
		await _wait(0.6)
		await _snap(dir, "zombies2")
	if _arg("rocketshot", "") != "":
		# a bazooka round in flight, seen from the side
		var rp0: Vector3 = _free_spot(G.world.capture + Vector3(10, 0, 10))
		var shooter = spawn_soldier(0, rp0.x, rp0.z, "rpg")
		shooter.order = {"mode": "hold", "point": shooter.pos}
		await _wait(0.5)
		var o0 = shooter.pos + Vector3(0, 1.5, 0)
		Combat.launch_rocket(shooter, o0 + Vector3(0, 1.0, 0), Vector3(1, 0.1, 0).normalized())
		await _wait(float(_arg("rocketshot", "0.6")))
		var rk = Combat.rockets[0]["p"] if not Combat.rockets.is_empty() else o0 + Vector3(25, 0, 0)
		if not Combat.rockets.is_empty():
			var rm = Combat.rockets[0]["mesh"]
			print("ROCKETSHOT mesh ", rm.global_position, " vis ", rm.is_visible_in_tree(), " kids ", rm.get_child_count(), " cam ", get_viewport().get_camera_3d().global_position)
		print("ROCKETSHOT rockets ", Combat.rockets.size(), " at ", rk)
		# the camera position takes two frames to apply: aim where the rocket will be by then
		var still = G.fx.rocket_model(false)
		G.fx.add_child(still)
		still.global_position = rk + Vector3(1.6, 0.6, 0.5)
		still.look_at(still.global_position + Vector3(1, 0.1, 0), Vector3.UP)
		for k in range(6):
			G.fx.rocket_trail(still.global_position - Vector3(0.6 + k * 0.5, 0.05 * k, 0))
		await _look(rk + Vector3(1.0, 0.8, 3.2), rk + Vector3(1.6, 0.1, 0))
		await _wait(0.3)
		await _snap(dir, "rocket")
		print("ROCKETSHOT cam after ", get_viewport().get_camera_3d().global_position, " rockets ", Combat.rockets.size())
	if _arg("stretchshot", "") != "":
		# a stretcher run back to the field hospital, and a medic dragging a man in with both hands
		var home: Vector3 = _free_spot(G.world.capture + Vector3(-40, 0, 0))
		var fw = Vector3(1, 0, 0)
		var hsp = _free_spot(home)
		Build.place("hospital", 0, hsp, fw, true)
		var groups = [[hsp + Vector3(70, 0, 0), 2], [hsp + Vector3(26, 0, -16), 1]]
		var ws = []
		for g in groups:
			var wp = _free_spot(g[0])
			var w = spawn_soldier(0, wp.x, wp.z, "rifle")
			force_cls = ["medic"]
			spawn_soldier(0, wp.x + 5.0, wp.z + 1.0, "")
			force_cls = []
			if g[1] == 2:
				spawn_soldier(0, wp.x - 5.0, wp.z - 1.0, "rifle")
			ws.append(w)
		await _wait(0.4)
		for w in ws:
			w.hp = 30.0
			w.make_wounded()
			w.bleed = 0.0
		await _wait(float(_arg("stretchshot", "7")))
		for w in ws:
			var c: Vector3 = w.parts[1].global_position
			await _look(c + (Vector3(1.5, 1.5, 4.2) if w.has_meta("stretcher") else Vector3(2.8, 2.6, -2.8)), c + Vector3(0, -0.1, 0))
			await _wait(0.2)
			await _snap(dir, "stretcher" if w.has_meta("stretcher") else ("drag" if w.dragger != null else "medic_%s" % w.state))
	if _arg("chuteshot", "") != "":
		var cq: Vector3 = _free_spot(G.world.capture)
		var para = spawn_soldier(0, cq.x, cq.z, "rifle")
		para.start_chute(cq + Vector3(0, 60, 0))
		await _wait(float(_arg("chuteshot", "2")))
		var pp: Vector3 = para.pos
		await _look(pp + Vector3(0, 2.0, 6.5), pp + Vector3(0, 2.4, 0))
		await _snap(dir, "chute_front")
		pp = para.pos
		await _look(pp + Vector3(6.5, 1.0, 0.5), pp + Vector3(0, 2.4, 0))
		await _snap(dir, "chute_side")
	if _arg("nightshot", "") != "":
		# two men with weapon lights sweeping a street, then the same with night vision on
		var c1: Vector3 = _free_spot(G.world.capture)
		var lights = []
		for k in range(2):
			var m = spawn_soldier(0, c1.x + k * 2.5, c1.z, "rifle")
			m.order = {"mode": "hold", "point": m.pos}
			m.light_on = true
			m.set_meta("force_light", true)
			m.aim_yaw = 0.4 - k * 0.6
			lights.append(m)
		await _wait(1.5)
		await _look(c1 + Vector3(-4.5, 2.4, -5.0), c1 + Vector3(1.0, 0.6, 6.0))
		await _wait(0.3)
		await _snap(dir, "torches")
		var jp = spawn_vehicle("jeep", 0, _free_spot(c1 + Vector3(9, 0, -6)), 0.5)
		jp.set_meta("force_light", true)
		await _wait(1.0)
		await _look(jp.pos + Vector3(-6.0, 2.6, -6.5), jp.pos + Vector3(2.0, 0.4, 9.0))
		await _snap(dir, "headlights")
		G.ui.toggle_nv()
		await _wait(0.3)
		await _look(G.world.capture + Vector3(-30, 25, -30), G.world.capture)
		await _snap(dir, "nightvision")
		G.ui.toggle_nv()
		await _snap(dir, "night_plain")
	if _arg("postshot", "") != "":
		# men climbing up to their posts on upper floors and crouching there
		var men = []
		for T in G.world.towers:
			if T.get("ladder", false) or T["cps"].is_empty() or men.size() >= 2:
				continue
			var sb: Vector3 = T["stair_bottom"]
			var m = spawn_soldier(0, sb.x, sb.z, "rifle")
			AI.take_post(m, T["cps"][0])
			men.append(m)
		await _wait(float(_arg("postshot", "25")))
		var i3 = 0
		for m in men:
			for k in range(3):
				await _look(m.pos + Vector3(-2.2, 1.4, -2.2), m.pos + Vector3(0, 0.5, 0))
				await _snap(dir, "post%d_%d" % [i3, k])
				print("POSTSHOT %d y %.2f fl %.2f crouch %.2f peek %s state %s task %s" % [i3, m.pos.y, m.pos.y - G.world.ground_y(m.pos.x, m.pos.z), m.crouch, m.want_peek, m.state, m.task])
				await _wait(0.4)
			i3 += 1
	if _arg("bldshot", "") != "":
		# a big farmhouse from outside, then looking down into it with the roof lifted off, then after a blast inside
		var bi = -1
		var bd = 1e9
		for i in range(G.world.buildings.size()):
			var b = G.world.buildings[i]
			if b.get("kind", "") == "bighouse":
				var dd = G.dist2d(Vector3(b["x"], 0, b["z"]), G.world.capture)
				if dd < bd:
					bd = dd
					bi = i
		if bi < 0:
			print("BLDSHOT no big house")
		else:
			var b = G.world.buildings[bi]
			var bc = Vector3(b["x"], G.world.ground_y(b["x"], b["z"]), b["z"])
			await _look(bc + Vector3(-b["w"] * 1.1, 6.0, -b["d"] * 1.6), bc + Vector3(0, 2.0, 0))
			await _snap(dir, "bighouse_out")
			await _look(bc + Vector3(0.5, 4.0, -b["d"] * 1.1), bc + Vector3(0, 0.6, 0))
			await _snap(dir, "bighouse_side")
			G.world.set_cut({bi: 2.3})
			await _look(bc + Vector3(-3.0, 16.0, -9.0), bc)
			await _wait(0.2)
			await _snap(dir, "bighouse_cut")
			Combat.explode(bc + Vector3(b["w"] * 0.2, 0.3, 0.0), null, 0.8)
			await _wait(2.0)
			await _snap(dir, "bighouse_blast")
			G.world.set_cut({})
	if _arg("markshot", "") != "":
		# a tank and a jeep driving off across the grass, leaving their tracks behind them
		var mp: Vector3 = _free_spot(G.world.spawn[0].lerp(G.world.capture, 0.2))
		var tk = spawn_vehicle("tank", 0, mp, atan2(G.world.capture.x - mp.x, G.world.capture.z - mp.z))
		var jp = spawn_vehicle("jeep", 0, _free_spot(mp + Vector3(8, 0, 6)), atan2(G.world.capture.x - mp.x, G.world.capture.z - mp.z))
		await _wait(float(_arg("markshot", "10")))
		var back = -tk.forward()
		await _look(tk.pos + back * 9.0 + Vector3(3.0, 4.0, 0), tk.pos + back * 2.0)
		await _snap(dir, "marks_tank")
		var mid = mp.lerp(tk.pos, 0.5)
		await _look(mid + Vector3(-9.0, 12.0, -9.0), mid)
		await _snap(dir, "marks_trail")
		var gp = G.world.capture + Vector3(6, 0, 6)
		G.fx.explosion(_free_spot(gp), 1.2)
		await _look(gp + Vector3(-12.0, 4.5, -12.0), gp + Vector3(0, 1.5, 0))
		await _wait(0.12)
		await _snap(dir, "boom1")
		await _wait(0.45)
		await _snap(dir, "boom2")
	if _arg("propshot", "") != "":
		# sandbags and bushes up close
		var pc: Vector3 = _free_spot(G.world.spawn[0].lerp(G.world.capture, 0.25) + Vector3(0, 0, 12))
		G.world.build_now(func():
			G.world.sandbags(pc.x, pc.z, 4.5, true, 1.0)
			G.world.sandbags(pc.x + 2.6, pc.z + 1.9, 3.2, false, 1.0)
			G.world.bush(pc.x - 3.5, pc.z + 3.0, 1.0)
			G.world.bush(pc.x + 4.5, pc.z + 5.0, 1.3)
			G.world.bush(pc.x - 1.0, pc.z + 6.5, 0.8))
		await _wait(0.5)
		await _look(pc + Vector3(-3.0, 2.2, -4.5), pc + Vector3(0.5, 0.4, 2.0))
		await _snap(dir, "props_close")
		await _look(pc + Vector3(-7.0, 5.0, -8.0), pc + Vector3(0.5, 0.4, 3.0))
		await _snap(dir, "props_wide")
		var tp = _free_spot(pc + Vector3(14, 0, 4))
		var st1 = spawn_vehicle("supplytruck", 0, tp, 0.6, false)
		var at1 = spawn_vehicle("ammotruck", 0, _free_spot(tp + Vector3(7, 0, -2)), -0.5, false)
		await _wait(0.4)
		await _look(tp + Vector3(-6.0, 4.0, -9.0), tp + Vector3(3.0, 1.2, 0.0))
		await _snap(dir, "trucks_rear")
		await _look(tp + Vector3(9.0, 3.5, 10.0), tp + Vector3(3.0, 1.2, 0.0))
		await _snap(dir, "trucks_front")
		var opp = _free_spot(pc + Vector3(-12, 0, 10))
		Build.place("observer", 0, opp, Vector3(0, 0, 1), true)
		var ow = spawn_soldier(0, opp.x + 0.6, opp.z, "rifle")
		await _wait(0.8)
		await _look(opp + Vector3(-5.5, 3.2, -6.0), opp + Vector3(0, 1.0, 0))
		await _snap(dir, "observer")
	if _arg("polishshot", "") != "":
		# a tank with riders, a mine plough, a jeep, builders at work, and a machine gunner with the bipod down
		var c2: Vector3 = _free_spot(G.world.capture + Vector3(-95, 0, 25))
		var tk = spawn_vehicle("tank", 0, c2, 0.0)
		for k in range(3):
			var rr = spawn_soldier(0, c2.x + 3.0, c2.z, "rifle")
			rr.mount(tk, tk.free_seat("pass"))
		var pl = spawn_vehicle("plough", 0, _free_spot(c2 + Vector3(11, 0, 0)), 0.0)
		var jp = spawn_vehicle("jeep", 0, _free_spot(c2 + Vector3(-10, 0, 2)), 0.0)
		jp.tyres = 0
		var bs = _free_spot(c2 + Vector3(0, 0, -22))
		var st = Build.place("mgnest", 0, bs, Vector3(0, 0, 1), false, true)
		var workers = []
		force_cls = ["engineer", "engineer", "rifleman"]
		for k in range(3):
			workers.append(spawn_soldier(0, bs.x - 3.0 + k * 3.0, bs.z - 4.0, ""))
		force_cls = []
		for w in workers:
			ClassAI._start_construct(w, st)
			w.order = {"mode": "hold", "point": w.pos}
		var mgp = _free_spot(c2 + Vector3(-12, 0, -14))
		var mg = spawn_soldier(0, mgp.x, mgp.z, "lmg")
		mg.order = {"mode": "hold", "point": mg.pos}
		await _wait(float(_arg("polishshot", "6")))
		mg.prone_t = true
		mg.ready_ = true
		mg.bipod_k = 1.0
		mg._pose_bipod()
		await _look(tk.pos + Vector3(-6.5, 3.8, -7.5), tk.pos + Vector3(0, 1.4, -1.5))
		await _snap(dir, "riders")
		await _look(pl.pos + Vector3(5.0, 3.0, 8.5), pl.pos + Vector3(0, 0.8, 3.0))
		await _snap(dir, "plough")
		await _look(bs + Vector3(5.5, 3.5, -7.5), bs + Vector3(0, 0.6, -2))
		await _snap(dir, "builders")
		await _wait(1.5)
		await _snap(dir, "builders2")
		var mgf = Vector3(sin(mg.body_yaw), 0, cos(mg.body_yaw))
		var mgr = Vector3(-mgf.z, 0, mgf.x)
		await _look(mg.pos + mgf * 1.6 + mgr * 1.8 + Vector3(0, 0.9, 0), mg.pos + mgf * 0.6 + Vector3(0, 0.3, 0))
		await _snap(dir, "bipod")
	if _arg("homeshot", "") != "":
		# what's around each side's starting area: HQ, rally point, structures
		await _wait(float(_arg("homeshot", "3")))
		G.pc.rts = false
		for t in [0, 1]:
			var rp: Vector3 = G.world.rally_point(t)
			await _look(rp + Vector3(0, 45, 28), rp)
			await _snap(dir, "home%d" % t)
			await _look(rp + Vector3(-14, 6, 16), rp + Vector3(-6, 1, 6))
			await _snap(dir, "camp%d" % t)
			for st in Build.sites:
				if st["team"] == t and st["kind"] == "hq":
					await _look(st["p"] + Vector3(14, 13, 16), st["p"])
					await _snap(dir, "hq%d" % t)
			for st in Build.sites:
				if st["team"] == t:
					print("HOMESHOT team %d site %s at %s done %s" % [t, st["kind"], str(st["p"]), str(st["done"])])
	if _arg("dogshot", "") != "":
		# fighters over the field: one smoking and on fire, and a pilot coming down under his canopy
		var c0: Vector3 = G.world.capture + Vector3(0, 70, 0)
		var a = spawn_vehicle("fighter", 0, c0, 0.0)
		var b = spawn_vehicle("fighter", 1, c0 + Vector3(0, 0, 60), 0.0)
		var e = spawn_vehicle("fighter", 1, c0 + Vector3(60, 10, -60), 0.0)
		for v in [a, b, e]:
			v.pos.y = c0.y + (10.0 if v == e else 0.0)
			v.life_t = 999.0
		await _wait(0.2)
		b.take_damage(b.spec["hp"] * 0.7, null, b.pos)
		e.destroy(null)
		await _wait(float(_arg("dogshot", "2.5")))
		var bd: Vector3 = b.get_meta("dir", b.forward())
		var bp: Vector3 = b.pos + bd * b.get_meta("spd", 40.0) / 30.0
		await _look(bp - bd * 24.0 + Vector3(0, 5, 0) + bd.cross(Vector3.UP) * 9.0, bp - bd * 7.0)
		await _snap(dir, "dogfight")
		var ewatch = e
		await _wait(2.5)
		var ch = G.soldiers.filter(func(x): return x.state == "chute")
		print("DOGSHOT chutes ", ch.size())
		if not ch.is_empty():
			var cp: Vector3 = ch[0].pos
			await _look(cp + Vector3(7, 1.5, 7), cp + Vector3(0, 2.5, 0))
			await _snap(dir, "bailout")
		for q in range(30):
			if ewatch.has_meta("crashed"):
				break
			await _wait(0.5)
		await _wait(1.5)
		print("DOGSHOT wreck crashed ", ewatch.has_meta("crashed"), " at ", ewatch.pos)
		var wc = ewatch.pos + Vector3(14, 0, 12)
		wc.y = G.world.ground_y(wc.x, wc.z) + 7.0
		await _look(wc, ewatch.pos + Vector3(0, 1, 0))
		await _snap(dir, "wreck")
	if _arg("fxshot", "") != "":
		# a crater, a felled tree and a furnished room
		var tree = null
		for c in G.world.cols:
			if c.has_meta("tree") and not c.has_meta("dead_tree") and G.dist2d((c.lo + c.hi) * 0.5, G.world.capture) < 90.0:
				tree = c
				break
		if tree != null:
			var tp = (tree.lo + tree.hi) * 0.5
			tp.y = tree.lo.y
			tree.set_meta("fall", Vector3(1, 0, 0))
			G.world.destroy_col(tree)
			Combat.explode(tp + Vector3(-4.0, 0.1, 3.0), null, 1.6)
			await _wait(2.5)
			await _look(tp + Vector3(-9, 5, 10), tp + Vector3(-1, 0, 1))
			await _snap(dir, "fx")
		if not G.world.tables.is_empty():
			var tb = G.world.tables[0]
			var p0: Vector3 = tb["p"]
			await _look(p0 + Vector3(2.2, 1.7, 2.2), p0)
			await _snap(dir, "room")
	if _arg("titleshot", "") != "":
		G.ui.visible = true
		G.pc.force_free = false
		G.main.quit_to_title()
		G.ui.show_menu()
		await _wait(1.0)
		await _snap(dir, "title")
	if _arg("vehshot", "") != "":
		# each vehicle on its own, empty, lit from the camera's side
		var c0v: Vector3 = G.world.capture
		var bnd: Rect2 = G.world.bounds
		for tries in range(300):
			var q = Vector3(randf_range(bnd.position.x + 30, bnd.end.x - 30), 0, randf_range(bnd.position.y + 30, bnd.end.y - 30))
			if G.world.cols_in_rect(q.x - 16, q.z - 16, q.x + 16, q.z + 16).is_empty() and not G.world.in_water(q.x, q.z):
				c0v = q
				break
		var ld: Vector3 = sun.global_transform.basis.z
		var cam_dir = G.flat(ld).normalized()
		for kind in _arg("vehshot", "").split(","):
			for v0 in G.vehicles.duplicate():
				v0.remove()
			var vv = spawn_vehicle(kind, int(_arg("vteam", "0")), c0v, 0.6, _arg("vcrew", "") != "")
			if _arg("vcrew", "") != "":
				for si in range(vv.seats.size()):
					if vv.seats[si] == null:
						var rr = spawn_soldier(int(_arg("vteam", "0")), c0v.x, c0v.z, "")
						if rr != null:
							rr.mount(vv, si)
				for x0 in G.soldiers:
					if x0.vehicle == null:
						x0.order = {"mode": "hold", "point": x0.pos}
				await _wait(float(_arg("vcrew", "1")))
			await _wait(0.3)
			var L = vv.spec["len"]
			var side = Vector3(-cam_dir.z, 0, cam_dir.x)
			if _arg("vside", "") != "":
				# close on the cab from the driver's side, a little in front
				var vs = Vector3(cos(vv.yaw), 0, -sin(vv.yaw))
				await _look(vv.pos + vs * 4.2 + vv.forward() * 3.2 + Vector3(0, 2.0, 0), vv.pos + vv.forward() * 0.6 + Vector3(0, 1.2, 0))
			else:
				await _look(vv.pos + cam_dir * L * 1.1 + side * L * 0.55 + Vector3(0, L * 0.45, 0), vv.pos + Vector3(0, 1.0, 0))
			await _snap(dir, "veh_" + kind)
	if _arg("unloadshot", "") != "":
		Reinforce.truck(0, 8)
		var tv = G.vehicles[G.vehicles.size() - 1]
		for k in range(120):
			await _wait(0.5)
			if not is_instance_valid(tv) or (tv.mission != null and tv.mission["stage"] >= 1):
				break
		await _wait(float(_arg("unloadshot", "1.0")))
		if is_instance_valid(tv):
			var bk = -tv.forward()
			await _look(tv.pos + bk * 11.0 + Vector3(-bk.z, 0, bk.x) * 5.0 + Vector3(0, 4.0, 0), tv.pos - tv.forward() * 3.0)
			await _snap(dir, "unload")
			print("UNLOAD truck stage %d speed %.2f" % [tv.mission["stage"] if tv.mission != null else -1, tv.speed])
	if _arg("campshot", "") != "":
		G.ui.visible = true
		Campaign.new_campaign()
		Campaign.move(Campaign.army_at(2, 0), 5)
		Campaign.selected = Campaign.army_at(1, 0)["id"]
		G.ui._show_campaign("3rd Company takes Mud Flats unopposed.")
		await _wait(0.6)
		await _snap(dir, "campaign")
		Campaign.selected = -1
		G.ui._show_campaign()
		await _wait(0.4)
		await _snap(dir, "campaign_list")
		G.ui.camp_panel.visible = false
	if _arg("climbshot", "") != "":
		var lads = G.world.towers.filter(func(T): return T.get("ladder", false))
		if not lads.is_empty():
			var T = lads[0]
			var lo: Vector3 = T["stair_bottom"]
			var sl = spawn_soldier(0, lo.x + T["n"].x * 3.0, lo.z + T["n"].z * 3.0, "rifle")
			AI.take_post(sl, T["cps"][0])
			await _wait(float(_arg("climbshot", "5")))
			var n: Vector3 = T["n"]
			var side = Vector3(-n.z, 0, n.x)
			await _look(sl.pos + n * 5.0 + side * 3.0 + Vector3(0, 2.0, 0), sl.pos + Vector3(0, 1.0, 0))
			await _snap(dir, "climb")
	if _arg("menushot", "") != "":
		G.ui.visible = true
		G.ui.show_menu()
		await _wait(0.5)
		await _snap(dir, "menu")
	if _arg("uishot", "") != "":
		# the HUD and tool dock as a player sees them, with a structure being placed
		G.ui.visible = true
		G.ui.menu.visible = false
		G.ui.help.visible = false
		G.pc.force_free = false
		G.pc.free_pos = G.world.capture + Vector3(-30, 18, 10)
		G.pc.free_yaw = PI / 2.0
		G.pc.free_pitch = -0.45
		G.ui.tab = _arg("uitab", "build")
		G.ui.tool = _arg("uitool", "b:bunker")
		G.ui._render_tools()
		var mv = _arg("mouse", "640,360").split(",")
		G.pc.test_mouse = Vector2(float(mv[0]), float(mv[1]))
		if _arg("rot", "") != "":
			for k in range(int(_arg("rot", "0"))):
				G.pc.rotate_place(1)
		await _wait(float(_arg("uishot", "2")))
		await _snap(dir, "ui")
	if _arg("rtsshot", "") != "":
		await _wait(float(_arg("rtsshot", "5")))
		G.pc.force_free = false
		G.pc.set_rts(true)
		G.pc.select_squad(0)
		G.pc._order_move(get_viewport().get_visible_rect().size * Vector2(0.62, 0.4))
		G.pc.select_squad(1)
		G.pc.select_squad(0)
		await _wait(1.0)
		await _snap(dir, "rts_orders")
	if _arg("zshot", "") != "":
		await _wait(float(_arg("zshot", "20")))
		var zs = G.soldiers.filter(func(x): return x.zombie and x.state == "alive")
		if not zs.is_empty():
			var z = zs[0]
			var f = Vector3(sin(z.body_yaw), 0, cos(z.body_yaw))
			await _look(z.pos + f * 4.5 + Vector3(1.5, 1.6, 0), z.pos + Vector3(0, 1.0, 0))
			await _snap(dir, "zombie")
			if G.pc.rts or true:
				G.pc.force_free = false
				G.pc.set_rts(true)
				G.pc.rts_focus = z.pos
				await _wait(0.5)
				await _snap(dir, "rts")
	if _arg("vtypes", "") != "":
		for v in G.vehicles.duplicate():
			v.remove()
		var c0: Vector3 = G.world.capture
		var k = 0
		var vl = ["halftrack", "armoredcar", "motorbike", "artillery", "gunship", "heli"]
		if _arg("vtypes", "") != "1":
			vl = _arg("vtypes", "").split(",")
		for kind in vl:
			spawn_vehicle(kind, k % 2, _free_spot(c0 + Vector3(-30 + k * 12, 0, 22)), 0.4)
			k += 1
	if _arg("builds", "") != "":
		var k = 0
		for kind in Build.ORDER:
			var bp = G.world.capture + Vector3(-36 + (k % 4) * 16, 0, -40 + (k / 4) * 16)
			Build.place(kind, k % 2, bp, Vector3(0, 0, 1), _arg("builds", "") == "1")
			k += 1
	if _arg("smoke", "") != "":
		Combat.smoke_at(G.world.capture + Vector3(0, 0, 10), 30.0)
		Combat.throw_grenade(G.soldiers[0], G.world.capture + Vector3(4, 0, 12), "smoke")
	if _arg("flare", "") != "":
		Combat.flare(G.world.capture + Vector3(-20, 0, 0), G.world.capture)
	await _wait(float(_arg("wait", "6")))
	var c: Vector3 = G.world.capture
	await _look(c + Vector3(-40, 25, -10), c)
	await _snap(dir, "overview")
	if _arg("cam", "") != "":
		var cv = _arg("cam", "").split(",")
		var av = _arg("at", "0,0,0").split(",")
		await _look(c + Vector3(float(cv[0]), float(cv[1]), float(cv[2])), c + Vector3(float(av[0]), float(av[1]), float(av[2])))
		await _snap(dir, "cam")
	if _arg("hud", "") != "":
		for s in G.soldiers:
			if s.state == "alive" and s.team == 0:
				G.pc.possess(s)
				G.pc.force_free = false
				break
		G.ui.visible = true
		G.ui.menu.visible = false
		await _wait(1.5)
		await _snap(dir, "hud")
		G.ui.visible = false
		G.pc.force_free = true
	if _arg("tacmap", "") != "":
		G.ui.visible = true
		G.ui.tacmap = preload("res://scripts/tacmap.gd").new()
		G.ui.root.add_child(G.ui.tacmap)
		G.ui.tacmap.toggle()
		await _wait(0.3)
		await _snap(dir, "tacmap")
		G.ui.tacmap.toggle()
		G.ui.visible = false
	if _arg("builders", "") != "":
		var bn = 0
		for s in G.soldiers:
			if s.state == "alive" and s.tool_mode == "hammer" and bn < 3:
				var f = Vector3(sin(s.aim_yaw), 0, cos(s.aim_yaw))
				await _look(s.pos + Vector3(-f.z, 0, f.x) * 2.6 + f * 1.2 + Vector3(0, 1.4, 0), s.pos + Vector3(0, 0.9, 0))
				await _snap(dir, "builder%d" % bn)
				bn += 1
		print("SHOT builders found ", bn)
	if _arg("cams", "") != "":
		var ci = 0
		for spec in _arg("cams", "").split(";"):
			var v = spec.split(",")
			await _look(c + Vector3(float(v[0]), float(v[1]), float(v[2])), c + Vector3(float(v[3]), float(v[4]), float(v[5])))
			await _snap(dir, "cam%d" % ci)
			ci += 1
	if _arg("smoke", "") != "":
		await _look(c + Vector3(-14, 4, 4), c + Vector3(0, 1, 11))
		await _snap(dir, "smoke")
	if _arg("fp", "") != "":
		for s in G.soldiers:
			if s.state == "alive":
				G.pc.first_person = _arg("fp", "") == "1"
				G.pc.possess(s)
				G.pc.force_free = false
				await _wait(1.5)
				await _snap(dir, "player_view")
				G.ui.visible = true
				await _wait(0.2)
				await _snap(dir, "player_view_hud")
				G.ui.visible = false
				G.pc.force_free = true
				break
	var pose = _arg("pose", "")
	if pose != "":
		for s in G.soldiers:
			if s.state == "alive":
				G.pc.possess(s)
				s.p_crouch = pose == "crouch"
				s.p_prone = pose == "prone"
				break
		await _wait(2.5)
	var vi = 0
	for v in G.vehicles:
		if vi >= int(_arg("vshots", "0")):
			break
		var f = v.forward()
		var r = Vector3(f.z, 0, -f.x)
		get_tree().paused = true
		await _look(v.pos + r * 9.0 + f * 5.0 + Vector3(0, 4.0, 0), v.pos + Vector3(0, 1.0, 0))
		await _snap(dir, "vehicle%d" % vi)
		get_tree().paused = false
		vi += 1
	var n = 0
	var order = G.soldiers.duplicate()
	if G.player != null:
		order.erase(G.player)
		order.push_front(G.player)
	for s in order:
		if s.state != "alive" or n >= int(_arg("close", "3")):
			continue
		var p = s.pos
		var f = Vector3(sin(s.aim_yaw), 0, cos(s.aim_yaw))
		var r = Vector3(f.z, 0, -f.x)
		get_tree().paused = true
		await _look(p + r * float(_arg("dist", "3.0")) + Vector3(0, 0.8, 0), p + Vector3(0, 0.6, 0))
		await _snap(dir, "side%d" % n)
		await _look(p + f * 3.0 + Vector3(0, 1.4, 0), p + Vector3(0, 0.9, 0))
		await _snap(dir, "front%d" % n)
		get_tree().paused = false
		await _wait(0.3)
		n += 1
	get_tree().quit()

func _knee_stats() -> Array:
	# counts legs bending the right way (shin swings back) vs backwards, for real bodies and for the pose targets
	var out = [0, 0, 0, 0]
	for s in G.soldiers:
		if s.state != "alive":
			continue
		var f = Vector3(sin(s.aim_yaw), 0, cos(s.aim_yaw))
		for pr in [[7, 8], [9, 10]]:
			var yt = s.parts[pr[0]].global_basis.y
			var ys = s.parts[pr[1]].global_basis.y
			var d = (ys - yt).dot(f)
			if absf(d) > 0.25:
				out[0 if d < 0.0 else 1] += 1
			var tt = s.targets[pr[0]].basis.y
			var ts = s.targets[pr[1]].basis.y
			var e = (ts - tt).dot(f)
			if absf(e) > 0.25:
				out[2 if e < 0.0 else 3] += 1
	return out

# exercises the map editor end to end: sculpt, place, save, reopen, play
func _editor_test(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	await _wait(0.5)
	var ed = G.editor
	ed.new_map(Vector2(260, 190))
	ed.tool = "raise"
	for k in range(20):
		ed._brush(Vector3(-20, 0, 30), 0.1)
	ed._terrain_changed()
	ed.tool = "road"
	ed._drag_done(Vector3(-120, 0, -2), Vector3(120, 0, 2))
	ed.tool = "trench"
	ed._drag_done(Vector3(30, 0, -40), Vector3(34, 0, 40))
	ed.tool = "crater"
	ed._click(Vector3(-50, 0, -30))
	for t in [["house", -10, -15], ["tower", 10, 15], ["wall", 0, -30], ["sandbags", 20, 0], ["crate", 22, 4], ["hedge", -40, 20],
			["tree", -60, -50], ["deadtree", 60, 50], ["hedgehog", 45, -10], ["tankwreck", -30, 45], ["truckwreck", 40, -45], ["ammo", 0, 8]]:
		ed.tool = t[0]
		ed._click(Vector3(t[1], 0, t[2]))
	ed.tool = "point"
	ed._click(Vector3(-40, 0, 0))
	ed._click(Vector3(40, 0, 0))
	ed.tool = "erase"
	ed._click(Vector3(22, 0, 4))
	# ground paint, placed units with orders, and triggers
	ed.brush = 12.0
	for pt in [["paint:5", -60, 30], ["paint:3", 0, 0], ["paint:7", 60, -40], ["paint:8", 20, 40]]:
		ed.tool = pt[0]
		for k in range(6):
			ed._paint(Vector3(pt[1] + k * 4.0, 0, pt[2]))
	G.world.build_terrain(ed.data["ground"])
	ed.tool = "squadA"
	ed._click(Vector3(-90, 0, -10))
	ed.sel["order"] = "patrol"
	ed.wp_mode = true
	ed._click(Vector3(-40, 0, -20))
	ed._click(Vector3(-40, 0, 20))
	ed.wp_mode = false
	ed.tool = "squadB"
	ed._click(Vector3(40, 0, 5))
	ed.sel["size"] = 8
	ed.tool = "vehB"
	ed.veh_pick = "tank"
	ed._click(Vector3(70, 0, 20))
	ed.sel["order"] = "move"
	ed.sel["wp"] = [Vector3(30, 0, 20)]
	ed.tool = "trigger"
	ed._click(Vector3(-40, 0, 0))
	ed.sel["when"] = "time"
	ed.sel["t"] = 4.0
	ed.sel["then"] = "message"
	ed.sel["text"] = "Trigger test fired"
	ed._click(Vector3(-40, 0, 25))
	ed.sel["when"] = "enter"
	ed.sel["team"] = 0
	ed.sel["then"] = "reinforce"
	ed.sel["ateam"] = 1
	ed.sel["n"] = 5
	ed.spot_mode = true
	ed._click(Vector3(10, 0, 30))
	ed._rebuild_markers()
	print("EDTEST items %d points %d units %d triggers %d painted %d" % [ed.data["items"].size(), ed.data["points"].size(), ed.data["units"].size(), ed.data["triggers"].size(), Array(G.world.paint).filter(func(x): return x > 0).size()])
	ed.name_edit.text = "Test map"
	ed.save()
	ed.new_map(Vector2(260, 190))
	ed.open_saved("Test map")
	print("EDTEST reopened items %d units %d triggers %d paint %d" % [ed.data["items"].size(), ed.data["units"].size(), ed.data["triggers"].size(), ed.data["paint"].size()])
	ed.tool = "sel"
	ed._click(Vector3(-40, 0, 25))
	G.pc.free_pos = Vector3(-70, 45, -60)
	G.pc.free_yaw = 0.7
	G.pc.free_pitch = -0.55
	await _wait(0.5)
	await _snap(dir, "editor")
	ed.mode_opt.select(3)
	ed.armies_opt.select(1)
	ed.play()
	await _wait(1.0)
	print("EDTEST playing map=%s mode=%s soldiers=%d points=%d groups=%d vehicles=%d" % [G.map_id, G.mode, G.soldiers.size(), Obj.points.size(), Scripted.groups.size(), G.vehicles.size()])
	await _wait(5.0)
	print("EDTEST triggers fired %s" % [Scripted.fired.keys()])
	G.pc.free_pos = Vector3(-70, 45, -60)
	G.pc.free_yaw = 0.7
	G.pc.free_pitch = -0.55
	await _wait(20.0)
	await _snap(dir, "played")
	print("EDTEST after 20s alive %d v %d" % [G.alive_count(0), G.alive_count(1)])
	get_tree().quit()

# bases: knock out a team's HQ, check it stops getting reinforcements, then that a new FOB brings them back
func _base_test() -> void:
	await _wait(0.5)
	Engine.time_scale = 4.0
	start_game({"map": "field", "mode": "destroy", "size": 8, "limit": 9999, "reinforce": true, "armor": "none", "reinf_mode": "instant", "teams": 2})
	await _wait(2.0)
	var h = Build.hq(1)
	print("BASETEST hq1 ", h != null, " can_respawn ", Build.can_respawn(1))
	for c in h["cols"]:
		if c.alive:
			G.world.destroy_col(c)
	for st in Build.sites.duplicate():
		if st["team"] == 1 and st["kind"] == "fob":
			Build.dismantle(st)
	await _wait(1.5)
	print("BASETEST after hq loss: hq_alive ", Build.hq_alive(1), " can_respawn ", Build.can_respawn(1), " fob sites ", Build.sites.filter(func(st): return st["team"] == 1 and st["kind"] == "fob").size())
	var n0 = G.alive_count(1)
	for s in G.soldiers:
		if s.team == 1 and s.state != "dead" and randf() < 0.5:
			Combat.kill(s, null, false)
	await _wait(15.0)
	print("BASETEST alive before/after %d -> %d (should not grow)" % [n0, G.alive_count(1)])
	# a finished FOB brings reinforcements back
	var spot = Build.find_spot(G.world.spawn[1] * 0.6, "fob", 30.0, 40, true)
	var f = Build.place("fob", 1, spot, Vector3(-1, 0, 0))
	var k = 0
	while not f["done"] and k < 200:
		Build.add_work(f, 1.0)
		k += 1
	print("BASETEST fob done ", f["done"], " can_respawn ", Build.can_respawn(1), " spawn_pos ", Build.spawn_pos(1))
	var n1 = G.alive_count(1)
	await _wait(20.0)
	print("BASETEST alive after fob %d -> %d (should grow)" % [n1, G.alive_count(1)])
	# lose everything and everyone: the team is out
	Build.dismantle(f)
	for s in G.soldiers:
		if s.team == 1 and s.state != "dead":
			Combat.kill(s, null, false)
	await _wait(3.0)
	print("BASETEST over ", G.over, " out ", Build.out)
	get_tree().quit()

# planes dogfight, the AA gun fires, the bridge layer bridges, the truck tows and runs on fuel
func _veh_test() -> void:
	await _wait(0.5)
	Engine.time_scale = 3.0
	start_game({"map": "river", "mode": "sandbox", "size": 4, "limit": 9999, "reinforce": false, "armor": "none", "teams": 2})
	var c: Vector3 = G.world.capture
	var f0 = spawn_vehicle("fighter", 0, c + Vector3(-150, 0, 0), PI / 2.0)
	var f1 = spawn_vehicle("fighter", 1, c + Vector3(150, 0, 30), -PI / 2.0)
	var b0 = spawn_vehicle("bomber", 0, c + Vector3(-160, 0, -40), PI / 2.0)
	var aa = spawn_vehicle("aagun", 1, c + Vector3(60, 0, -30), -PI / 2.0)
	var br = spawn_vehicle("bridger", 0, G.world.spawn[0], PI / 2.0)
	var tr = spawn_vehicle("truck", 0, G.world.spawn[0] + Vector3(0, 0, 14), PI / 2.0)
	var gun = spawn_vehicle("artillery", 0, G.world.spawn[0] + Vector3(-9, 0, 14), PI / 2.0, false)
	var msg = VehExt.try_tow(tr)
	print("VEHTEST tow: ", msg)
	print("VEHTEST bridge site ", VehExt.bridge_site(br), " driver ", br.driver(), " obj ", Build._objective(0), " water ", G.world.water)
	for k in range(14):
		await _wait(4.0)
		var line = []
		for v in [f0, f1, b0, aa, br, tr, gun]:
			if is_instance_valid(v):
				line.append("%s%d hp%d alt%d %s%s fuel%.2f p(%d,%d)" % [v.kind, v.team, int(v.hp), int(v.alt), "DEAD" if v.dead else "", v.get_meta("why", ""), v.fuel, int(v.pos.x), int(v.pos.z)])
			else:
				line.append("gone")
		if k >= 9 and is_instance_valid(br):
			print("VEHTEST bridger speed %.2f yaw %.2f bstuck %.1f site %s msg %s" % [br.speed, br.yaw, br.get_meta("bstuck", 0.0), str(VehExt.bridge_site(br)), VehExt.lay_bridge(br) if k == 13 else ""])
		print("VEHTEST t%d | %s | bridges %d | gun-tr dist %.1f" % [k, " · ".join(line), G.world.bridges.size(), G.dist2d(gun.pos, tr.pos) if is_instance_valid(gun) and is_instance_valid(tr) else -1.0])
	get_tree().quit()

# campaign battle, scenario code round trip, upgrades, carrying
func _camp_test() -> void:
	await _wait(0.5)
	Campaign.new_campaign()
	Campaign.attack(3)
	await _wait(3.0)
	var vets = 0
	for s in G.soldiers:
		if s.team == 0 and s.has_meta("roster"):
			vets += 1
	print("CAMPTEST battle map ", G.map_id, " mode ", G.mode, " roster soldiers ", vets)
	var code = Scenario.encode(Scenario.capture())
	print("CAMPTEST code length ", code.length())
	var d = Scenario.decode(code)
	print("CAMPTEST decoded soldiers ", d["soldiers"].size(), " vehicles ", d["vehicles"].size(), " sites ", d["sites"].size())
	Campaign.active = true
	end_game(0)
	print("CAMPTEST owner after win ", Campaign.data["owner"])
	await _wait(1.0)
	Scenario.apply(d)
	await _wait(2.0)
	print("CAMPTEST after load: soldiers ", G.soldiers.size(), " vehicles ", G.vehicles.size(), " sites ", Build.sites.size())
	# upgrades and camo
	var fob = null
	for st in Build.sites:
		if st["kind"] == "hq":
			Build.add_camo(st)
	var sp = Build.find_spot(G.world.spawn[0] * 0.7, "fob", 30.0, 40, true)
	fob = Build.place("fob", 0, sp, Vector3(1, 0, 0), true)
	var up = Build.upgrade(fob)
	print("CAMPTEST upgraded to ", up["kind"] if up != null else "none")
	for k in range(200):
		Build.add_work(up, 1.0)
	print("CAMPTEST fob2 done ", up["done"], " fobs ", Build.fobs(0).size())
	get_tree().quit()

# 100 v 100 (or --size=N): how long a simulation tick takes with far soldiers simplified
func _big_test() -> void:
	await _wait(0.5)
	start_game({"map": _arg("map", "valley"), "mode": "capture", "size": int(_arg("size", "100")), "limit": 9999, "reinforce": true,
		"armor": "light", "reinf_mode": "instant", "teams": 2})
	G.pc.free_pos = Vector3(0, 30, 0)
	for k in range(3):
		tick_us = 0
		tick_n = 0
		prof = [0, 0]
		await _wait(8.0)
		var frozen = 0
		for s in G.soldiers:
			if s.lod_frozen:
				frozen += 1
		print("BIGTEST %ds soldiers %d frozen %d sim %.2f ms/tick  veh %.2f soldiers %.2f" % [(k + 1) * 8, G.soldiers.size(), frozen,
			(tick_us / 1000.0) / maxi(tick_n, 1), prof[0] / 1000.0 / maxi(tick_n, 1), prof[1] / 1000.0 / maxi(tick_n, 1)])
	get_tree().quit()

# campaign: what gets wrecked in a region stays wrecked next time
func _ruin_test() -> void:
	await _wait(0.5)
	Campaign.new_campaign()
	Campaign.attack(1)
	await _wait(1.0)
	var n0 = G.world.static_cols.size()
	var c = G.world.capture
	G.world.damage_area(c + Vector3(0, 1, 0), 14.0, 6.0)
	await _wait(1.0)
	var dead = 0
	for col in G.world.static_cols:
		if not col.alive:
			dead += 1
	var sp = Build.find_spot(G.world.spawn[0] * 0.6, "sandbags", 20.0, 30, true)
	if sp != null:
		Build.place("sandbags", 0, sp, Vector3(1, 0, 0), true)
	Campaign.active = true
	end_game(1)
	print("RUINTEST first battle: %d pieces, %d wrecked, recorded %d" % [n0, dead, Campaign.ruins(1).size()])
	await _wait(1.0)
	Campaign.data["owner"][1] = 1
	Campaign.attack(1)
	await _wait(1.0)
	var t0v = G.vehicles.filter(func(v): return v.team == 0).size()
	print("RUINTEST second battle: %d pieces, ruined at start %d, doors %d, pool %s, alpha vehicles %d, saved sites %d, sites now %d" % [G.world.static_cols.size(), G.world.ruined_at_start, Doors.doors.size(), Campaign.data["pool"], t0v, Campaign.data["sites"].get(1, []).size(), Build.sites.size()])
	get_tree().quit()

# the newer modes: run one for a while and print how it is going
func _stuck_count() -> int:
	var n = 0
	for x in G.soldiers:
		if x.state == "alive" and x.stuck_n > 0:
			n += 1
	return n

func _inside_count() -> int:
	var n = 0
	for x in G.soldiers:
		if x.state != "alive":
			continue
		for b in G.world.buildings:
			if absf(x.pos.x - b["x"]) < b["w"] * 0.5 - 0.3 and absf(x.pos.z - b["z"]) < b["d"] * 0.5 - 0.3:
				n += 1
				break
	return n

func _mode_test(mode: String) -> void:
	await _wait(0.5)
	if _arg("time", "") != "":
		G.settings["time"] = _arg("time", "day")
		apply_time()
	if _arg("aiside", "") != "":
		G.settings["ai_side"] = true
	if mode == "daily":
		Modes.start_daily()
		print("MODETEST daily ", Modes.daily_text(Modes.daily))
	else:
		start_game({"map": _arg("map", "field"), "mode": mode, "size": int(_arg("size", "10")), "limit": 100, "reinforce": true, "armor": _arg("armor", "light"), "reinf_mode": "truck", "teams": 2,
			"factions": (_arg("fac", "army,army") + ",army,army").split(",")})
	if _arg("noradio", "") != "":
		for v in G.vehicles.duplicate():
			if v.kind == "radar":
				v.destroy(null)
		for s in G.soldiers:
			if s.cls == "radio":
				s.set_class("rifleman")
		Support.points = [40, 40]
	if _arg("dbg", "") != "":
		for j in range(int(_arg("dbgn", "10"))):
			await _wait(float(_arg("dbgdt", "0.8")))
			if Modes.pilot != null and is_instance_valid(Modes.pilot):
				var la = Modes.pilot.last_attacker
				print("DBG pilot hp %.1f state %s attacker %s" % [Modes.pilot.hp, Modes.pilot.state, (la.sname + " t" + str(la.team)) if la != null and is_instance_valid(la) else "none"])
			for v2 in G.vehicles:
				if v2.mission != null and v2.mission.get("lead", false):
					print("DBG lead car spd %.1f pos %s path %d/%d drv %s stuck %.1f rev %.1f" % [v2.speed, v2.pos, v2.path_i, v2.path.size(), v2.driver() != null, v2.stuck_t, v2.reverse_t])
			for v in Modes.convoy:
				if is_instance_valid(v):
					var f = v.forward()
					for so in G.soldiers:
						if so.team == v.team and so.state == "alive" and so.vehicle == null:
							var rel = G.flat(so.pos - v.pos)
							var aa = rel.dot(f)
							if aa > 0.0 and aa < v.spec["len"] * 0.5 + 5.0 and absf(rel.dot(Vector3(f.z, 0, -f.x))) < v.spec["wid"] * 0.5 + 0.8:
								print("   blocker %s task %s order %s mt %s" % [so.sname, so.task, so.order, so.move_target])
					print("DBG truck drv %s spd %.1f stage %d go %.0f pos %s path %d/%d rev %.1f why %s wait %.1f hp %.0f" % [v.driver() != null, v.speed, v.mission["stage"], v.mission["go_t"], v.pos, v.path_i, v.path.size(), v.reverse_t, v.mission.get("why", "?"), v.mission.get("wait_esc", 0.0), v.hp])
					break
	var hist = {}
	for k in range(int(_arg("secs", "48")) / 8):
		for q4 in range(4):
			await _wait(2.0)
			for s in G.soldiers:
				if s.state != "alive" or s.vehicle != null or s.zombie:
					continue
				var hh: Array = hist.get(s.get_instance_id(), [])
				hh.append([s.pos, s.vis_t != null or G.sim_time - s.seen_t < 4.0, s.task])
				if hh.size() > 20:
					hh.pop_front()
				hist[s.get_instance_id()] = hh
		# going round in circles: plenty of walking over the last 40 s, nothing to show for it, no fighting
		var loops = []
		for s in G.soldiers:
			var hh2: Array = hist.get(s.get_instance_id(), [])
			if s.state != "alive" or hh2.size() < 20:
				continue
			var walked = 0.0
			var fought = false
			for j in range(1, hh2.size()):
				walked += G.dist2d(hh2[j][0], hh2[j - 1][0])
				fought = fought or hh2[j][1]
			if walked > 22.0 and G.dist2d(hh2[0][0], hh2[-1][0]) < 10.0 and (not fought or _arg("loops", "") == "2"):
				loops.append(s)
		if _arg("hqdbg", "") != "" and Build.hq(0) != null:
			var hp0: Vector3 = Build.hq(0)["p"]
			var near = []
			for s in G.soldiers:
				if s.team == 1 and s.state == "alive":
					var ob = AI.objective_for(s)
					near.append("%d:%s/%s/%s%s o%d/%d mt%s cmd%s" % [int(G.dist2d(s.pos, hp0)), s.task, AI.order_of(s)["mode"], "v" if s.vis_t != null else "", "s%d" % int(G.sim_time - s.seen_t), int(G.dist2d(ob, hp0)), int(G.dist2d(ob, s.pos)), s.move_target != null, Commander.target_for(s) != null])
			print("HQDBG ", " ".join(near))
		if _arg("loops", "") != "":
			var lt = []
			for s in loops.slice(0, 4):
				var tasks = {}
				for e in hist[s.get_instance_id()]:
					tasks[str(e[2])] = true
				lt.append("%s[%s ord %s bld %d cov %s up %.1f]" % [s.cls, ",".join(tasks.keys()), AI.order_of(s)["mode"], G.world.building_index(s.pos, 3.0), s.cover != null, s.pos.y - G.world.ground_y(s.pos.x, s.pos.z)])
			print("LOOPS %d %s" % [loops.size(), " ".join(lt)])
		var z = 0
		for s in G.soldiers:
			if s.zombie and s.state != "dead":
				z += 1
		var pz = ""
		if Modes.pilot != null and is_instance_valid(Modes.pilot):
			pz = " pilot %s %s d_home %.0f" % [Modes.pilot.state, Modes.rescued, G.dist2d(Modes.pilot.pos, Modes._home(0))]
		var lead = Modes._lead_truck()
		if lead != null:
			pz += " lead %.0f m to go" % G.dist2d(lead.pos, Modes.convoy_goal)
		var up = 0
		for s in G.soldiers:
			if s.state == "alive" and s.pos.y - G.world.ground_y(s.pos.x, s.pos.z) > 2.5:
				up += 1
		if up > 0:
			pz += " upstairs %d" % up
		var lads = G.world.towers.filter(func(T): return T.get("ladder", false)).size()
		var climbing = 0
		for s in G.soldiers:
			if s.climb != null:
				climbing += 1
		if lads > 0:
			pz += " ladders %d climbing %d" % [lads, climbing]
		var bl = 0
		var dressing = 0
		for s in G.soldiers:
			if s.state != "dead" and s.bleed > 0.0:
				bl += 1
			if s.bandage_t > 0.0:
				dressing += 1
		pz += " bleeding %d dressing %d tables %d flipped %d" % [bl, dressing, G.world.tables.size(), G.world.tables.filter(func(t): return t["flipped"]).size()]
		var sw = 0
		var wade = 0
		var faust = 0
		for s in G.soldiers:
			if s.state == "alive" and s.swim:
				sw += 1
			elif s.state == "alive" and not G.world.water.is_empty() and G.world.in_water(s.pos.x, s.pos.z):
				wade += 1
			if s.wid == "pfaust":
				faust += 1
		if sw + wade > 0:
			pz += " swim %d wade %d" % [sw, wade]
		if faust > 0:
			pz += " faust_up %d" % faust
		for b in Ferry.boats:
			if is_instance_valid(b["v"]):
				var ab = 0
				for i in range(1, b["v"].seats.size()):
					if b["v"].seats[i] != null:
						ab += 1
				pz += " boat[%s st%d ab%d x%.0f]" % ["dead" if b["v"].dead else "ok", b["v"].mission["stage"] if b["v"].mission != null else -1, ab, b["v"].pos.x]
		if G.mode == "general" and Modes.generals.size() == 2:
			for g in Modes.generals:
				if g != null and is_instance_valid(g):
					pz += " gen%d[%s %.0f,%.0f f%.2f hp%.0f %s %s %s %s]" % [g.team, g.state, g.pos.x, g.pos.z, Modes._frac(g.team, g.pos), g.hp, g.task, AI.order_of(g)["mode"], "BROKEN" if g.broken else "", "carried" if g.carried_by != null else ""]
		if Faction.militia(0) or Faction.militia(1):
			var mines_n = Combat.mines.filter(func(m): return m["kind"] == "ied").size()
			var tech = G.vehicles.filter(func(v): return v.kind == "technical" and not v.dead).size()
			pz += " caches %d ieds %d technicals %d tunnels %d" % [Faction.caches.filter(func(c): return c["alive"]).size(), mines_n, tech, Faction.tunnels.size()]
		var hosp_n = Medical.recovering.size()
		if hosp_n > 0:
			pz += " recovering %d" % hosp_n
		var scouts = 0
		var sprung = 0
		for s in G.soldiers:
			if s.state == "alive" and s.has_meta("scout"):
				scouts += 1
		for q in G.squads:
			if G.sim_time - q.get("sprung_t", -99.0) < 8.0:
				sprung += 1
		pz += " styles %s/%s scouts %d sight %d,%d sprung %d ambush %d/%d" % [Commander.style_of(0), Commander.style_of(1), scouts, Commander.sightings[0].size(), Commander.sightings[1].size(), sprung, AI.ambushes, AI.ambush_waits]
		if not Comms.queue.is_empty():
			pz += " comms[%s %s q%d,%d run%s,%s ok%d,%d dl%d]" % [Comms.ok(0), Comms.ok(1), Comms.queue[0].size(), Comms.queue[1].size(), Comms.runner[0] != null, Comms.runner[1] != null, Comms.reinf_ok[0], Comms.reinf_ok[1], Comms.delivered]
		for v in G.vehicles:
			if v.kind == "atgun":
				pz += " at[%s %.1f]" % ["dead" if v.dead else ("crew" if v.gunner() != null else "nocrew"), G.sim_time - v.get_meta("fire_t", -99.0)]
		print("MODETEST %s %ds | %s | alive %d v %d zombies %d | over %s | score %s%s" % [G.mode, (k + 1) * 8, Obj.status_text(), G.alive_count(0), G.alive_count(1), z, G.over, G.cap_score, pz + " tac" + str(Tactics.events) + " ops" + str(Ops.events) + " raze %d hq %s" % [G.soldiers.filter(func(x): return x.state == "alive" and x.task == "raze").size(), str(Build.sites.filter(func(x): return x["kind"] == "hq").map(func(x): return "%d/%d%s" % [x["cols"].filter(func(c): return c.alive).size(), x["cols"].size(), "X" if x["dead"] else ""]))] + " fleet %d/%d runs %s dumps %d" % [Logistics.count(0), Logistics.count(1), str(Logistics.delivered), Build.sites.filter(func(x): return x["kind"] == "supply" and not x["dead"]).size()] + " salvage %d/%d radio %d/%d" % [Salvage.claimed, Salvage.wrecks.size(), RadioPack.taken, RadioPack.dropped.size()] + " inside %d/%d" % [_inside_count(), G.soldiers.filter(func(x): return x.state == "alive").size()] + " route %s stuck %d" % [str(G.world.route_stats), _stuck_count()] + " pts %s earned %s" % [str(Support.points), str(Support.earned)] + " cveh %d/%d depots %d" % [G.vehicles.filter(func(v): return v.team == 0 and not v.dead and v.kind in Support.AI_VEH).size(), G.vehicles.filter(func(v): return v.team == 1 and not v.dead and v.kind in Support.AI_VEH).size(), Build.sites.filter(func(x): return x["kind"] == "depot" and not x["dead"]).size()]])
		if G.over:
			break
	get_tree().quit()

# doors get kicked open by people walking through them, grenades go in through windows
# the turn-based campaign: move, fight, Bravo's turn, supply
# this batch's features in pictures: order ghosts, a dragged line, waypoints, the kill feed with icons,
# squad cards, the path debug view, wall dust, and a campaign battle in prep during a storm
func _batch_shot(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	G.settings["time"] = "day"
	apply_time()
	await _wait(0.5)
	start_game({"map": _arg("map", "field"), "mode": "commander", "size": 10, "limit": 999, "reinforce": true, "armor": "light", "reinf_mode": "truck", "teams": 2})
	await _wait(5.0)
	var pc = G.pc
	pc.force_free = false
	pc.set_rts(true)
	pc.select_squad(0)
	pc.dismount_selected(true)
	await _wait(3.0)
	pc.select_squad(0)
	var men = pc._foot_men()
	print("BATCHSHOT foot men ", men.size())
	var c = Vector3.ZERO
	for m in men:
		c += m.pos
	c /= maxf(1.0, men.size())
	var fwd = G.flat(G.world.capture - c).normalized()
	pc.rts_focus = c + fwd * 14.0
	pc.rts_dist = 46.0
	await _wait(0.6)
	var vs = get_viewport().get_visible_rect().size
	pc.test_mouse = pc.cam.unproject_position(c + fwd * 22.0 + Vector3(fwd.z, 0, -fwd.x) * 6.0)
	await _wait(0.4)
	await _snap(dir, "ghosts")
	# one man clicked: his card
	var keep_sel = pc.selection.duplicate()
	pc.selection = [men[0]]
	G.ui.show_unit(men[0])
	await _wait(0.5)
	await _snap(dir, "unit_card")
	pc.selection = keep_sel
	G.ui.hide_info()
	print("BATCHSHOT ghosts ", pc.pghosts.filter(func(x): return x.visible).size(), " tool ", G.ui.tool, " menu ", G.ui.menu_open(), " mouse ", pc.test_mouse, " ground ", pc._ground_at(pc.test_mouse))
	# a dragged line across their front
	pc.test_mouse = Vector2(-5000, -5000)
	var side = Vector3(fwd.z, 0, -fwd.x)
	pc.fdrag_a = c + fwd * 18.0 - side * 9.0
	pc.fdrag_b = c + fwd * 18.0 + side * 9.0
	pc.fdrag = true
	await _wait(0.4)
	await _snap(dir, "line_drag")
	pc._order_line(pc.fdrag_a, pc.fdrag_b, false)
	pc.fdrag = false
	# and two more stops queued after it
	for m in men:
		if m.order != null:
			m.order["queue"] = [m.order["point"] + fwd * 14.0 + side * 8.0, m.order["point"] + fwd * 28.0]
	# kill feed rows with icons, and a +1 over one of ours
	var foes = G.soldiers.filter(func(x): return x.team == 1 and x.state == "alive")
	if men.size() >= 3 and foes.size() >= 3:
		men[0].set_weapon("lmg")
		G.ui.feed(men[0], foes[0], false)
		G.ui.feed(men[1], foes[1], true)
		G.ui.feed(foes[2], men[2], false, "", "blast")
		G.ui.feed(men[2], null, false, "Jeep")
	await _wait(1.0)
	await _snap(dir, "waypoints_feed")
	print("BATCHSHOT flags ", pc.wp_flags.filter(func(x): return x.visible).size(), " queue ", men[0].order)
	# path debug, after they've been moving for a while
	await _wait(5.0)
	G.navviz.toggle()
	pc.rts_dist = 90.0
	await _wait(1.0)
	await _snap(dir, "pathdebug")
	G.navviz.toggle()
	print("BATCHSHOT route ", G.world.route_stats, " cards ", G.ui.squad_cards.visible, " ", G.ui.squad_cards.cards.size())
	# a wall comes down: dust you can't see through
	var wall = null
	for col in G.world.cols:
		if col.alive and col.dest and col.prop == 0 and not col.has_meta("tree") and col.hi.y - col.lo.y > 2.0 and maxf(col.hi.x - col.lo.x, col.hi.z - col.lo.z) > 3.0:
			wall = col
			break
	if wall != null:
		var wc: Vector3 = (wall.lo + wall.hi) / 2.0
		pc.set_rts(false)
		pc.force_free = true
		await _look(wc + Vector3(12, 6, 12), wc)
		print("BATCHSHOT wall size ", wall.hi - wall.lo, " prop ", wall.prop, " gy ", wall.gy, " started ", G.started)
		G.world.destroy_col(wall)
		print("BATCHSHOT wall alive ", wall.alive, " clouds ", G.smoke_clouds.size())
		await _wait(2.2)
		await _snap(dir, "dust")
		print("BATCHSHOT dust clouds ", G.smoke_clouds.size())
		pc.force_free = false
	# a campaign battle: prep countdown, in a storm
	Campaign.new_campaign()
	Campaign.data["weather"] = "storm"
	var a1 = Campaign.army_at(1, 0)
	print("BATCHSHOT attack: ", Campaign.move(a1, 4))
	await _wait(3.0)
	pc.force_free = false
	pc.set_rts(true)
	pc.rts_focus = G.world.rally_point(0)
	pc.rts_dist = 60.0
	await _wait(1.0)
	await _snap(dir, "prep_storm")
	print("BATCHSHOT prep ", Prep.active(), " %.0f" % Prep.t, " storm ", G.storm, " air ok ", Rules.callin_ok(0, "airstrike"), " held ", Prep.held)
	Prep.finish()
	await _wait(2.0)
	print("BATCHSHOT after prep ", Prep.active(), " orders ", G.soldiers.filter(func(x): return x.order != null and x.order.get("prep", false)).size())
	# a few turns of events
	for k in range(6):
		Campaign._event([])
		print("BATCHSHOT event ", Campaign.data.get("event", ""), " weather ", Campaign.data.get("weather", ""), " funds ", Campaign.data["funds"])
	get_tree().quit()

# men sent upstairs by the stairs; then the floor is blown away and they're sent again (they mustn't
# keep climbing into thin air); then a ladder's wall comes down (the ladder must fall)
func _stair_test() -> void:
	await _wait(0.5)
	start_game({"map": _arg("map", "town"), "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2, "armies": false})
	await _wait(1.0)
	var T = null
	var L = null
	for t in G.world.towers:
		if t.get("ladder", false):
			if L == null:
				L = t
		elif T == null and not t.get("posts", []).is_empty():
			T = t
	print("STAIR towers ", G.world.towers.size(), " house ", T != null, " ladder ", L != null)
	if T == null:
		get_tree().quit()
		return
	var inside: Vector3 = T["inside"]
	var men = []
	for i in range(3):
		var sx = spawn_soldier(0, inside.x + i * 0.8, inside.z + 3.0, "rifle")
		men.append(sx)
	await _wait(0.5)
	var post = T["posts"][0]
	var goal = Vector3(post[0], T["stair_top"].y + G.world.ground_y(post[0], post[1]), post[1])
	print("STAIR under-stairs blockers ", G.world.cols.filter(func(c): return c.has_meta("under_stairs")).size(), " floor at goal ", G.world.floor_at(goal.x, goal.z, goal.y), " tower ok ", G.world.tower_ok(T))
	for m in men:
		m.order = {"mode": "move", "point": goal}
		AI.route_to(m, goal, 4.4)
	for k in range(10):
		await _wait(1.5)
		print("STAIR up t%d " % k + " | ".join(men.map(func(m): return "y%.1f route %s task %s" % [m.pos.y - G.world.ground_y(m.pos.x, m.pos.z), m.route != null, m.task])))
	# blow the upper floor away
	var gone = 0
	for c in G.world.cols.duplicate():
		if c.alive and c.dest and c.hi.y - c.lo.y < 0.7 and absf(c.hi.y - c.gy - T["floor_y"]) < 0.5 and absf((c.lo.x + c.hi.x) / 2.0 - T["x"]) < T["w"] / 2.0 and absf((c.lo.z + c.hi.z) / 2.0 - T["z"]) < T["d"] / 2.0:
			G.world.destroy_col(c)
			gone += 1
	print("STAIR floor pieces destroyed ", gone, " tower ok now ", G.world.tower_ok(T))
	await _wait(3.0)
	for m in men:
		m.order = {"mode": "move", "point": goal}
		m.decide_t = 0.0
	var climbs = 0
	for k in range(8):
		await _wait(1.5)
		for m in men:
			if m.route != null:
				climbs += 1
		print("STAIR after t%d " % k + " | ".join(men.map(func(m): return "y%.1f route %s state %s" % [m.pos.y - G.world.ground_y(m.pos.x, m.pos.z), m.route != null, m.state])))
	print("STAIR route ticks after floor gone ", climbs)
	if L != null:
		var lp: Vector3 = L["lad_pts"][1]
		var wall = null
		for c in G.world.cols:
			if c.alive and lp.x > c.lo.x - 0.6 and lp.x < c.hi.x + 0.6 and lp.z > c.lo.z - 0.6 and lp.z < c.hi.z + 0.6 and lp.y > c.lo.y - 0.3 and lp.y < c.hi.y + 0.3:
				wall = c
				break
		print("STAIR ladder wall found ", wall != null)
		if wall != null:
			G.world.destroy_col(wall)
		print("STAIR ladder down ", L.get("ladder_down", false), " tower ok ", G.world.tower_ok(L))
	get_tree().quit()

# recruit squads in commander mode and follow their trucks: where they go, how fast, why they stop
func _recruit_test() -> void:
	await _wait(0.5)
	start_game({"map": _arg("map", "field"), "mode": "commander", "size": 10, "limit": 999, "reinforce": true, "armor": "light", "reinf_mode": "truck", "teams": 2})
	await _wait(2.0)
	var before = G.vehicles.duplicate()
	var t0 = Time.get_ticks_usec()
	for k in range(4):
		spawn_soldier(0, -150.0 + k, 0.0, "")
	print("RECRUIT perf: 4 soldiers %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	for k in range(int(_arg("n", "3"))):
		var t1 = Time.get_ticks_usec()
		Reinforce.truck_cls(0, ["rifleman", "rifleman", "mg", "rifleman", "at", "medic", "rifleman", "rifleman"])
		print("RECRUIT perf: truck of 8 %.1f ms" % ((Time.get_ticks_usec() - t1) / 1000.0))
		await _wait(float(_arg("gap", "4")))
	var trucks = G.vehicles.filter(func(v): return not (v in before))
	for k in range(int(_arg("secs", "70")) / 2):
		await _wait(2.0)
		var parts = []
		for v in trucks:
			if not is_instance_valid(v):
				parts.append("gone")
				continue
			var m = v.mission
			parts.append("%s(%.0f,%.0f) spd%.1f %s st%s drop%.0f riders%d" % [v.kind, v.pos.x, v.pos.z, v.speed, v.why, str(m.get("stage", "-")) if m != null else "-", G.dist2d(v.pos, m["drop"]) if m != null and m.has("drop") else -1.0, v.seats.filter(func(x): return x != null).size()])
		print("RECRUIT t%02d " % (k * 2) + " | ".join(parts))
	get_tree().quit()

func _camp_test2() -> void:
	await _wait(0.5)
	Campaign.new_campaign()
	var D = Campaign.data
	print("CAMP2 owner ", D["owner"])
	for a in D["armies"]:
		print("CAMP2 army ", a["name"], " team ", a["team"], " at ", Campaign.REGIONS[a["region"]]["name"], " str ", a["str"])
	var a2 = Campaign.army_at(2, 0)
	print("CAMP2 move to Mud Flats: ", Campaign.move(a2, 5))
	var a1 = Campaign.army_at(1, 0)
	print("CAMP2 attack The River: ", Campaign.move(a1, 4))
	await _wait(3.0)
	print("CAMP2 battle map ", G.map_id, " mode ", G.mode, " alive ", G.alive_count(0), " v ", G.alive_count(1), " caps ", G.team_caps)
	end_game(0)
	print("CAMP2 after win owner ", D["owner"])
	for a in D["armies"]:
		print("CAMP2 army ", a["name"], " at ", Campaign.REGIONS[a["region"]]["name"], " str ", a["str"], " supplied ", Campaign.supplied(a["team"], a["region"]))
	for k in range(4):
		var lines = Campaign.end_turn()
		print("CAMP2 end turn %d: %s | battle %s" % [k, " / ".join(lines), Campaign.battle_text()])
		if Campaign.pending_battle() != null:
			Campaign._start_battle()
			await _wait(2.0)
			print("CAMP2 defence battle map ", G.map_id, " mode ", G.mode, " alive ", G.alive_count(0), " v ", G.alive_count(1))
			end_game(1 if k % 2 == 0 else 0)
			print("CAMP2 after defence ", D["log"][0])
	print("CAMP2 owner ", D["owner"], " turn ", D["turn"], " over ", Campaign.over())
	get_tree().quit()

# a soldier is sent up onto a flat roof by its ladder, then back down; and one goes through a window
# a quick look at each map from a few angles (to catch colour and texture problems)
func _map_shots(list: String) -> void:
	var dir = _arg("dir", "/tmp/mapshots")
	DirAccess.make_dir_recursive_absolute(dir)
	G.ui.visible = false
	G.pc.force_free = true
	await _wait(0.3)
	for m in list.split(","):
		start_game({"map": m, "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2, "armies": false})
		await _wait(1.5)
		var c: Vector3 = G.world.capture
		await _look(c + Vector3(-40, 25, -10), c)
		await _snap(dir, m + "_a")
		await _look(c + Vector3(30, 70, 60), c)
		await _snap(dir, m + "_b")
		await _look(c + Vector3(22, 3.5, 18), c + Vector3(0, 2, 0))
		await _snap(dir, m + "_c")
		print("MAPSHOT ", m)
	get_tree().quit()

# zombie mode: the shop and boarded windows
func _horde_test() -> void:
	await _wait(0.5)
	Engine.time_scale = 2.0
	start_game({"map": "town", "mode": "horde", "size": 10, "limit": 999, "reinforce": true, "armor": "none", "teams": 2})
	await _wait(1.0)
	Support.points[0] = 100
	var bi = -1
	var bd = 1e9
	for i in range(G.world.buildings.size()):
		var b = G.world.buildings[i]
		var d = G.dist2d(Vector3(b["x"], 0, b["z"]), G.world.capture)
		var nwin = Doors.panes.filter(func(pn): return pn["b"] == i).size()
		if d < bd and nwin > 0:
			bd = d
			bi = i
	var bp = Vector3(G.world.buildings[bi]["x"], 0, G.world.buildings[bi]["z"])
	print("HORDETEST board: ", Modes.shop("board", bp))
	print("HORDETEST lmg: ", Modes.shop("lmg", G.world.capture), " | ammo: ", Modes.shop("ammo", G.world.capture), " | points left ", Support.points[0])
	print("HORDETEST lmgs now ", G.soldiers.filter(func(x): return x.team == 0 and x.wid == "lmg").size(), " boards ", G.world.cols.filter(func(c): return c.alive and c.has_meta("board")).size())
	for k in range(6):
		await _wait(10.0)
		print("HORDETEST t%d wave %d left %d alive %d points %d boards %d" % [k * 10, Modes.horde_wave, Modes.horde_left, G.alive_count(0), Support.points[0], G.world.cols.filter(func(c): return c.alive and c.has_meta("board")).size()])
	get_tree().quit()

# commander mode with no starting vehicles: mark a depot, let engineers build it, then buy a jeep through the dock
func _depot_test() -> void:
	await _wait(0.5)
	Engine.time_scale = 3.0
	start_game({"map": "field", "mode": "commander", "size": 6, "limit": 999, "reinforce": true, "armor": "none", "teams": 2})
	await _wait(1.0)
	Support.points[0] = 200
	var home: Vector3 = G.world.rally_point(0)
	var fw = G.flat(G.world.capture - home).normalized()
	var spot = _free_spot(home - fw * 15.0 + Vector3(fw.z, 0, -fw.x) * 18.0)
	var dep = Build.place("depot", 0, spot, fw, false)
	G.ui._recruit("eng") if false else null
	force_cls = ["engineer", "engineer", "engineer"]
	for k in range(3):
		spawn_soldier(0, spot.x + k * 2.0, spot.z + 6.0, "")
	force_cls = []
	print("DEPOTTEST callins has jeep: ", Rules.callin_ok(0, "jeep"), " site ", dep != null, " card text: ", Support.need_text("jeep"))
	for k in range(30):
		await _wait(4.0)
		if dep != null and dep["done"]:
			break
		if k % 5 == 0:
			print("DEPOTTEST t%d depot %.0f/%.0f" % [k * 4, dep["work"], dep["need"]])
	print("DEPOTTEST depot done ", dep["done"], " unlocked ", Support.unlocked(0, "jeep"))
	var v0 = G.vehicles.filter(func(x): return x.team == 0).size()
	G.ui._card_clicked("sup:jeep")
	print("DEPOTTEST after click points ", Support.points[0], " | ", Prod.status(0))
	for k in range(12):
		await _wait(5.0)
	var mine = G.vehicles.filter(func(x): return x.team == 0)
	print("DEPOTTEST vehicles %d -> %d" % [v0, mine.size()])
	for v in mine:
		print("   ", v.kind, " at ", v.pos, " d_depot %.0f" % G.dist2d(v.pos, dep["p"]))
	get_tree().quit()

# the AI commander's economy: it recruits, answers our planes with AA guns and sends a squad to ambush our convoys
func _econ_test() -> void:
	await _wait(0.5)
	Engine.time_scale = 3.0
	start_game({"map": "field", "mode": "commander", "size": 8, "limit": 999, "reinforce": true, "armor": "light", "teams": 2})
	await _wait(1.0)
	var home: Vector3 = G.world.rally_point(0)
	var fw = G.flat(G.world.capture - home).normalized()
	Build.place("supply", 0, _free_spot(home + Vector3(fw.z, 0, -fw.x) * -18.0), fw, true)
	Support.points[1] = 150
	var fp = spawn_vehicle("fighter", 0, Reinforce.entry_point(0), 0.0)
	fp.life_t = 999.0
	var n0 = G.soldiers.filter(func(x): return x.team == 1 and x.state != "dead").size()
	Ops.raid_cd[1] = G.sim_time + 5.0
	for k in range(18):
		await _wait(10.0)
		var aa = Build.sites.filter(func(st): return st["team"] == 1 and st["kind"] == "aa").map(func(st): return "%d%%" % int(100.0 * st["work"] / st["need"]))
		var r = Ops.raids[1]
		print("ECONTEST t%d | eng %d | AI men %d (start %d) pts %d | AA %s | raid %s %s" % [k * 10, G.soldiers.filter(func(x): return x.team == 1 and x.state == "alive" and x.cls == "engineer").size(), G.soldiers.filter(func(x): return x.team == 1 and x.state != "dead").size(), n0, Support.points[1], str(aa), str(Ops.events["raid"]), ("leader d %.0f" % G.dist2d(Squad.leader_of(r["q"]).pos, r["p"])) if r != null and Squad.leader_of(r["q"]) != null else "-"])
	get_tree().quit()

# RTS orders: select riflemen, send them to build a marked-out site, two to man a mortar, then a move that should start at once
func _rts_test() -> void:
	await _wait(0.5)
	start_game({"map": "field", "mode": "commander", "size": 6, "limit": 999, "reinforce": false, "armor": "light", "teams": 2})
	await _wait(1.0)
	var home: Vector3 = G.world.rally_point(0)
	var fw = G.flat(G.world.capture - home).normalized()
	var c = _free_spot(home + fw * 10.0)
	var men = []
	force_cls = ["rifleman", "rifleman", "rifleman", "mg", "medic", "rifleman"]
	for k in range(6):
		men.append(spawn_soldier(0, c.x + k * 1.5, c.z, ""))
	force_cls = []
	var st = Build.place("sandbags", 0, _free_spot(c + fw * 12.0), fw, false, true)
	var mortar = spawn_vehicle("mortar", 0, _free_spot(c - fw * 10.0), atan2(fw.x, fw.z), false)
	await _wait(0.5)
	G.pc.selection = men.slice(0, 3)
	G.pc._update_rings()
	print("RTSTEST summary: ", G.pc._sel_summary())
	print("RTSTEST build order ", G.pc._order_build(st))
	var st2 = Build.place("sandbags", 0, _free_spot(c + fw * 12.0 + Vector3(fw.z, 0, -fw.x) * 9.0), fw, false, true)
	print("RTSTEST queue order ", G.pc._order_build(st2, true), " queues ", men.slice(0, 3).map(func(x): return x.get_meta("build_queue", []).size()))
	G.pc.selection = men.slice(3, 5)
	print("RTSTEST board order ", G.pc._order_board(mortar))
	G.pc.selection = [men[5]]
	var p0: Vector3 = men[5].pos
	men[5].order = {"mode": "move", "point": c + fw * 30.0}
	G.pc._obey(men[5], c + fw * 30.0)
	for q in range(5):
		await _wait(0.2)
		var mm = men[5]
		print("RTSTEST mover %.1fs went %.1f m | state %s task %s mt %s path %d want %s vel %s order %s" % [0.2 * (q + 1), G.dist2d(mm.pos, p0), mm.state, str(mm.task), str(mm.move_target), mm.path.size(), str(mm.want), str(mm.vel), str(mm.order)])
	for k in range(14):
		await _wait(3.0)
		print("RTSTEST t%d site2 %.0f/%.0f | site %.0f/%.0f done %s | mortar crew %s | builders %s" % [k * 3, st2["work"], st2["need"], st["work"], st["need"], str(st["done"]), str(mortar.seats.map(func(x): return x != null)), str(men.slice(0, 3).map(func(x): return x.task))])
	get_tree().quit()

# vehicle features: a flat tyre and a thrown track fixed by the crew, riders jumping off, a burning tank's crew
# bailing out, a mine plough clearing a mine, headlights at night and an engineer sweeping for mines
func _vfeat_test() -> void:
	await _wait(0.5)
	G.settings["time"] = "night"
	apply_time()
	start_game({"map": "field", "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2, "armies": false})
	await _wait(0.5)
	var c: Vector3 = _free_spot(G.world.capture)
	var jeep = spawn_vehicle("jeep", 0, c, 0.0)
	var tank = spawn_vehicle("tank", 0, _free_spot(c + Vector3(20, 0, 0)), 0.0)
	var tank2 = spawn_vehicle("tank", 1, _free_spot(c + Vector3(-160, 0, 60)), PI)
	var pl = spawn_vehicle("plough", 0, _free_spot(c + Vector3(0, 0, 40)), 0.0)
	await _wait(0.5)
	for k in range(6):
		jeep.take_damage(10.0, null, jeep.global_transform * Vector3(1.0, 0.4, 1.0))
	tank.tracks_broken = true
	print("VFEAT jeep tyres %d, tank tracks %s, lights jeep %s tank %s" % [jeep.tyres, str(tank.tracks_broken), str(jeep.lights_on), str(tank.lights_on)])
	# riders
	var riders = []
	for k in range(2):
		var r = spawn_soldier(0, tank.pos.x + 3.0, tank.pos.z, "rifle")
		r.mount(tank, tank.free_seat("pass"))
		riders.append(r)
	# a mine in front of the plough, and one in the road for the engineer
	Combat.mines.append({"p": pl.pos + pl.forward() * 9.0, "team": 1, "kind": "at", "arm": 0.0, "owner": null, "node": Node3D.new()})
	G.main.add_child(Combat.mines[-1]["node"])
	pl.command(pl.pos + pl.forward() * 30.0)
	force_cls = ["engineer"]
	var eng = spawn_soldier(0, c.x - 30.0, c.z - 10.0, "")
	force_cls = []
	Combat.mines.append({"p": eng.pos + Vector3(4.0, 0, 0), "team": 1, "kind": "ap", "arm": 0.0, "owner": null, "node": Node3D.new()})
	G.main.add_child(Combat.mines[-1]["node"])
	await _wait(1.0)
	tank.take_damage(30.0, null, tank.center())
	await _wait(0.5)
	print("VFEAT riders aboard after a hit: %s" % str(riders.map(func(x): return x.vehicle != null)))
	tank2.burning = true
	for k in range(10):
		await _wait(2.0)
		print("VFEAT t%d | jeep tyres %d fix %s | tank tracks %s fix %s | burning tank crew out %d | plough mines left %d plough hp %.0f | eng task %s mines %d | lights jeep %s" % [k * 2,
			jeep.tyres, str(jeep.fix_by.task) if jeep.fix_by != null and is_instance_valid(jeep.fix_by) else "-", str(tank.tracks_broken), str(tank.fix_by.task) if tank.fix_by != null and is_instance_valid(tank.fix_by) else "-",
			G.soldiers.filter(func(x): return x.team == 1 and x.state == "alive" and x.vehicle == null).size(), Combat.mines.size(), pl.hp, str(eng.task), Combat.mines.size(), str(jeep.lights_on)])
	get_tree().quit()

# the menus, for checking how they look
func _ui_shot(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	await _wait(3.0)
	await _snap(dir, "title")
	G.ui._open_setup()
	await _wait(0.6)
	await _snap(dir, "setup")
	var mi = G.ui.MODE_IDS.find("commander")
	G.ui.opt_mode.select(mi)
	G.ui._show_mode_info()
	await _wait(0.4)
	await _snap(dir, "setup_commander")
	get_tree().quit()

# every vehicle's position, speed and where it's trying to go, every couple of seconds
func _vtrace() -> void:
	await _wait(0.5)
	start_game({"map": _arg("map", "field"), "mode": _arg("mode", "commander"), "size": 10, "limit": 999, "reinforce": true, "armor": _arg("armor", "light"), "reinf_mode": "truck", "teams": 2})
	await _wait(0.5)
	for k in range(int(_arg("n", "30"))):
		await _wait(2.0)
		for v in G.vehicles:
			if v.dead or v.spec.get("air", false) or v.spec.get("static", false):
				continue
			print("VTRACE t%02d %s#%d T%d pos (%.0f,%.0f) spd %.1f tgt %s cmd %s mis %s det %s drv %s" % [k * 2, v.kind, v.get_instance_id() % 1000, v.team, v.pos.x, v.pos.z, v.speed,
				v.why, str(v.cmd != null), str(v.mission.get("type", "") if v.mission != null else "-"), str(v.detour != null), str(v.driver() != null)])
	get_tree().quit()

# troops getting off a truck: where each man is, what he's doing and how fast, for a few seconds afterwards
func _dis_test() -> void:
	await _wait(0.5)
	start_game({"map": "field", "mode": "capture", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2, "armies": false})
	await _wait(0.5)
	var c: Vector3 = _free_spot(G.world.rally_point(0) + Vector3(30, 0, 0))
	var tr = spawn_vehicle(_arg("veh", "truck"), 0, c, PI / 2.0, _arg("crew", "1") == "1")
	var men = []
	for k in range(4):
		var m = spawn_soldier(0, c.x, c.z + 6.0, "rifle")
		m.mount(tr, tr.free_seat("pass"))
		men.append(m)
	await _wait(1.0)
	for m in men:
		m.dismount(false)
	for k in range(40):
		await _wait(0.1)
		var line = "DIS %.2f |" % (k * 0.1)
		for m in men:
			line += " (%.2f,%.2f) v%.1f %s %s |" % [m.pos.x - c.x, m.pos.z - c.z, G.flat(m.vel).length(), str(m.task), "V" if m.vault != null else ""]
		print(line)
	if _arg("cshot", "") != "":
		var i2 = 0
		for s in G.soldiers:
			await _look(s.pos + Vector3(-2.5, 1.6, -2.5), s.pos + Vector3(0, 0.6, 0))
			await _snap(_arg("cshot", "/tmp"), "crouch%d" % i2)
			await _look(s.pos + Vector3(3.5, -1.0, 3.5) + Vector3(0, 0, 0), s.pos + Vector3(0, 0.6, 0))
			await _snap(_arg("cshot", "/tmp"), "crouch%d_out" % i2)
			i2 += 1
	get_tree().quit()

# dogfight: two fighters a side meet over the field; count hits, smoke trails, kills and parachutes
func _dog_test() -> void:
	await _wait(0.5)
	Engine.time_scale = 2.0
	start_game({"map": "field", "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2, "armies": false})
	await _wait(0.5)
	for t in [0, 1]:
		for k in range(2):
			var ep = Reinforce.entry_point(t) + Vector3(k * 30.0, 0, 0)
			var pv = spawn_vehicle("fighter", t, ep, atan2(G.world.capture.x - ep.x, G.world.capture.z - ep.z))
			pv.life_t = 999.0
	for k in range(int(_arg("n", "12"))):
		await _wait(float(_arg("dt", "5")))
		var line = "DOGTEST t%d" % (k * 5)
		for v in G.vehicles:
			if v.kind == "fighter":
				line += " | T%d hp %.0f alt %.0f trail %d %s%s dir %s pull %.1f tgt %s" % [v.team, v.hp, v.alt, v.get_meta("trail", 0), "dead " if v.dead else "", "evading" if v.get_meta("ev_t", 0.0) > 0.0 else "", str(v.get_meta("dir", Vector3.ZERO)), v.get_meta("pull_t", 0.0), str(v.get_meta("dog_t").pos.distance_to(v.pos)) if v.has_meta("dog_t") and is_instance_valid(v.get_meta("dog_t")) else "-"]
		var chutes = G.soldiers.filter(func(x): return x.state == "chute").size()
		var landed = G.soldiers.filter(func(x): return x.state == "alive" and x.vehicle == null).size()
		print(line, " | chutes %d on ground %d" % [chutes, landed])
	get_tree().quit()

# a wounded man far from the field hospital gets carried back on a stretcher by two men
# an ambulance fetches a wounded man: medics out with a stretcher, back in, to the hospital, inside, out again
func _amb_test() -> void:
	await _wait(0.5)
	start_game({"map": "field", "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2, "armies": false})
	await _wait(0.5)
	var home: Vector3 = G.world.rally_point(0)
	var fw = G.flat(G.world.capture - home).normalized()
	var hp = _free_spot(home)
	Build.place("hospital", 0, hp, fw, true)
	var amb = spawn_vehicle("ambulance", 0, _free_spot(hp + fw * 12.0), atan2(fw.x, fw.z))
	var wp = _free_spot(hp + fw * 60.0)
	var w = spawn_soldier(0, wp.x, wp.z, "rifle")
	var wname = w.sname
	await _wait(0.5)
	w.hp = 30.0
	w.make_wounded()
	w.bleed = 0.0
	for k in range(45):
		await _wait(2.0)
		var meds = amb.get_meta("medics", [])
		var ws = (w.state + (" in-veh" if w.vehicle != null else "") + (" stretcher" if w.has_meta("stretcher") else "")) if is_instance_valid(w) else "gone(in hospital)"
		var back = G.soldiers.filter(func(x): return x.sname == wname and not is_instance_valid(w) and x.state == "alive")
		print("AMBTEST pos %s yaw %.2f path %s | " % [str(amb.pos), amb.yaw, str(amb.path)] + "why %s path %d/%d y%.1f r%.1f st%.1f inp %s | " % [amb.why, amb.path_i, amb.path.size(), amb.yield_t, amb.reverse_t, amb.stuck_t, str(amb.player_inputs)] + "t%d amb d_w %.1f d_h %.1f spd %.1f | medics %s | w %s | rec %d | back out %s" % [k * 2, G.dist2d(amb.pos, wp), G.dist2d(amb.pos, hp), amb.speed, ",".join(meds.map(func(m): return (m.task if m.task != null else "-") + ("@veh" if m.vehicle != null else "") if is_instance_valid(m) else "x")), ws, Medical.recovering.size(), str(back.size() > 0) + (" dist_h %.0f" % G.dist2d(back[0].pos, hp) if back.size() > 0 else "")])
		if back.size() > 0 and G.dist2d(back[0].pos, hp) > 15.0:
			break
	get_tree().quit()

# the anti-tank gun's loader drill against a tank down the field
func _at_test(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	G.settings["time"] = "day"
	apply_time()
	await _wait(0.5)
	start_game({"map": "field", "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2, "armies": false})
	await _wait(0.5)
	G.pc.force_free = true
	var c: Vector3 = _free_spot(G.world.rally_point(0))
	var fw = G.flat(G.world.capture - c).normalized()
	var ag = spawn_vehicle("atgun", 0, c, atan2(fw.x, fw.z))
	var tk = spawn_vehicle("tank", 1, _free_spot(c + fw * 110.0), atan2(-fw.x, -fw.z), false)
	await _wait(1.0)
	var side = Vector3(fw.z, 0, -fw.x)
	var shots = 0
	var fired = 0
	var was = 0.0
	for k in range(400):
		await _wait(0.1)
		if not is_instance_valid(ag) or ag.dead:
			break
		if ag.atload_t > was + 0.5:
			fired += 1
		was = ag.atload_t
		if ag.atload_t > 0.0 and shots < 4:
			var ph = 1.0 - ag.atload_t / 2.3
			if (shots == 0 and ph > 0.2) or (shots == 1 and ph > 0.45) or (shots == 2 and ph > 0.7) or (shots == 3 and ph > 0.9):
				var gp: Vector3 = ag.gunner().pos if ag.gunner() != null else ag.pos
				await _look(gp + side * 2.4 - fw * 1.8 + Vector3(0, 1.8, 0), gp + fw * 0.6 + Vector3(0, 0.9, 0))
				await _snap(dir, "atgun_%d" % shots)
				shots += 1
		if shots >= 4 and fired >= 2:
			break
	print("ATTEST shots fired %d, pictures %d, tank hp %.0f" % [fired, shots, tk.hp if is_instance_valid(tk) else -1.0])
	get_tree().quit()

# vehicles with their headlights on at night, from the side, from in front and from above
func _light_shot(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	G.settings["time"] = "night"
	apply_time()
	await _wait(0.5)
	start_game({"map": _arg("map", "field"), "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2, "armies": false})
	await _wait(0.5)
	G.pc.force_free = true
	var c: Vector3 = _free_spot(G.world.rally_point(0))
	var fw = G.flat(G.world.capture - c).normalized()
	var side = Vector3(fw.z, 0, -fw.x)
	var vs = []
	var k = 0
	for kind in ["jeep", "truck", "tank"]:
		var v = spawn_vehicle(kind, 0, _free_spot(c + side * (k - 1) * 7.0), atan2(fw.x, fw.z), false)
		v.set_meta("force_light", true)
		vs.append(v)
		k += 1
	await _wait(2.0)
	await _look(c - fw * 9.0 + side * 9.0 + Vector3(0, 4.0, 0), c + fw * 8.0)
	await _wait(0.5)
	await _snap(dir, "lights_behind")
	await _look(c + fw * 22.0 + side * 6.0 + Vector3(0, 2.5, 0), c)
	await _wait(0.5)
	await _snap(dir, "lights_front")
	await _look(c + side * 16.0 + fw * 6.0 + Vector3(0, 3.0, 0), c + fw * 6.0)
	await _wait(0.5)
	await _snap(dir, "lights_side")
	get_tree().quit()

# taking over one man from the commander's view, and handing him back
func _ctl_test() -> void:
	await _wait(0.5)
	start_game({"map": "field", "mode": "commander", "size": 6, "limit": 999, "reinforce": true, "armor": "light", "teams": 2})
	await _wait(3.0)
	var u = G.soldiers.filter(func(o): return o.team == 0 and o.state == "alive" and o.vehicle == null)[0]
	G.pc.selection = [u]
	G.ui.show_unit(u)
	await _wait(0.3)
	G.pc.possess(u)
	await _wait(2.0)
	print("CTLTEST possessed %s rts %s player %s" % [str(G.player == u), str(G.pc.rts), u.sname])
	G.pc.leave_soldier()
	await _wait(0.5)
	print("CTLTEST back rts %s player %s tool %s" % [str(G.pc.rts), str(G.player), G.ui.tool])
	get_tree().quit()

# a mortar crew dropping rounds and a jeep gunner changing his belt, with pictures through each drill
func _load_test(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	G.settings["time"] = "day"
	apply_time()
	await _wait(0.5)
	start_game({"map": "field", "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2, "armies": false})
	await _wait(0.5)
	G.pc.force_free = true
	var c: Vector3 = _free_spot(G.world.rally_point(0))
	var fw = G.flat(G.world.capture - c).normalized()
	var mt = spawn_vehicle("mortar", 0, c, atan2(fw.x, fw.z))
	var jp = spawn_vehicle("jeep", 0, _free_spot(c + Vector3(fw.z, 0, -fw.x) * 14.0), atan2(fw.x, fw.z))
	for k in range(4):
		var e = _free_spot(c + fw * (140.0 + k * 4.0) + Vector3(fw.z, 0, -fw.x) * (k * 3.0))
		spawn_soldier(1, e.x, e.z, "rifle")
	await _wait(1.0)
	jp.belt = 4
	var side = Vector3(fw.z, 0, -fw.x)
	var mshots = 0
	var bshots = 0
	var fired = 0
	var belts = 0
	for k in range(300):
		await _wait(0.1)
		if mt.load_t > 0.0 and mshots < 4:
			var ph = 1.0 - mt.load_t / 1.9
			if (mshots == 0 and ph > 0.1) or (mshots == 1 and ph > 0.35) or (mshots == 2 and ph > 0.55) or (mshots == 3 and ph > 0.75):
				await _look(mt.pos + side * 3.2 + fw * 1.6 + Vector3(0, 1.9, 0), mt.pos + Vector3(0, 0.8, 0))
				await _snap(dir, "mortar_%d" % mshots)
				mshots += 1
		if jp.belt_t > 0.0 and bshots < 3:
			var pb = 1.0 - jp.belt_t / 3.4
			if (bshots == 0 and pb > 0.1) or (bshots == 1 and pb > 0.4) or (bshots == 2 and pb > 0.85):
				var gp: Vector3 = jp.gunner().pos if jp.gunner() != null else jp.pos
				var jf: Vector3 = jp.forward()
				var js = Vector3(jf.z, 0, -jf.x)
				await _look(gp - jf * 2.2 + js * 1.6 + Vector3(0, 2.6, 0), gp + jf * 0.4 + Vector3(0, 1.2, 0))
				await _snap(dir, "belt_%d" % bshots)
				bshots += 1
		if jp.belt_t > 0.0 and jp.belt_t < 0.12:
			belts += 1
		fired = 20 - mt.shells
		if mshots >= 4 and bshots >= 3:
			break
		if not is_instance_valid(mt):
			print("LOADTEST mortar gone at t%.1f" % (k * 0.1))
			break
		if k % 5 == 0 and k < 40:
			print("LOADTEST t%.1f mortar hp %.0f dead %s gunner %s load %.2f cd %.1f" % [k * 0.1, mt.hp, str(mt.get("dead")), str(mt.gunner() != null), mt.load_t, mt.cannon_cd])
		if k % 20 == 0:
			print("LOADTEST t%.0f mortar load %.1f cd %.1f shells %d | jeep belt %d belt_t %.1f heat %.2f" % [k * 0.1, mt.load_t, mt.cannon_cd, mt.shells, jp.belt, jp.belt_t, jp.gun_heat])
	print("LOADTEST mortar shots %d, shells used %d, belt drill seen %d, belt now %d, mortar crew %d jeep crew %d" % [mshots, fired, bshots, jp.belt, mt.crew_count() if mt.has_method("crew_count") else -1, jp.crew_count() if jp.has_method("crew_count") else -1])
	get_tree().quit()

func _cb_test() -> void:
	await _wait(0.5)
	start_game({"map": "field", "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2, "armies": false})
	await _wait(0.5)
	var p = _free_spot(G.world.rally_point(0))
	var st = Build.place("cbgun", 0, p, Vector3(1, 0, 0), true)
	await _wait(0.5)
	print("CBTEST site ", st != null and st["done"], " alive ", Build.alive(st))
	Support.fire_mission(1, p + Vector3(15, 0, 0), null, 12, 12.0, 1.6)
	await _wait(25.0)
	print("CBTEST intercepted ", Combat.intercepts, " of 13 shells")
	get_tree().quit()

func _stretch_test() -> void:
	await _wait(0.5)
	start_game({"map": "field", "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2, "armies": false})
	await _wait(0.5)
	var home: Vector3 = G.world.rally_point(0)
	var fw = G.flat(G.world.capture - home).normalized()
	var hp = _free_spot(home)
	Build.place("hospital", 0, hp, fw, true)
	var wp = _free_spot(hp + fw * 80.0)
	var w = spawn_soldier(0, wp.x, wp.z, "rifle")
	force_cls = ["medic"]
	var m = spawn_soldier(0, wp.x + 8.0, wp.z, "")
	force_cls = []
	var b = spawn_soldier(0, wp.x - 8.0, wp.z, "rifle")
	await _wait(0.5)
	w.hp = 30.0
	w.make_wounded()
	w.bleed = 0.0
	for k in range(30):
		await _wait(2.0)
		var st = w.get_meta("stretcher") if w.has_meta("stretcher") else null
		print("STRETCHTEST t%d w %s d_hosp %.1f | medic task %s | b task %s | stage %s heal %.1f" % [k * 2, w.state, G.dist2d(w.pos, hp), str(m.task), str(b.task), str(st["stage"]) if st != null else "-", w.heal_t])
		if w.state != "wounded":
			break
	get_tree().quit()

# commander economy: a depot queue, an upgrade and a supply convoy
func _prod_test() -> void:
	await _wait(0.5)
	Engine.time_scale = 3.0
	start_game({"map": "field", "mode": "commander", "size": 6, "limit": 999, "reinforce": true, "armor": "light", "teams": 2})
	await _wait(1.0)
	var home: Vector3 = G.world.rally_point(0)
	var fw = G.flat(G.world.capture - home).normalized()
	var dep = Build.place("depot", 0, _free_spot(home - fw * 20.0 + Vector3(fw.z, 0, -fw.x) * 20.0), fw, true)
	var dump = Build.place("supply", 0, _free_spot(home + Vector3(fw.z, 0, -fw.x) * -18.0), fw, true)
	Support.points[0] = 200
	var v0 = G.vehicles.filter(func(x): return x.team == 0 and not x.dead).size()
	print("PRODTEST call jeep ", Support.call_in(0, "jeep", G.world.capture), " tank ", Support.call_in(0, "tank", G.world.capture), " research ", Prod.start_research(0, "armour"))
	print("PRODTEST points after orders ", Support.points[0], " | ", Prod.status(0))
	Prod.convoy_t[0] = 1.0
	for k in range(12):
		await _wait(8.0)
		print("PRODTEST t%d | %s | points %d | vehicles %d (from %d) | armour %s | fog hidden enemies %d" % [k * 8, Prod.status(0), Support.points[0], G.vehicles.filter(func(x): return x.team == 0 and not x.dead).size(), v0, str(Prod.has(0, "armour")), G.soldiers.filter(func(x): return x.team == 1 and Fog.hidden(x)).size()])
	get_tree().quit()

# a spitter against a soldier who can't shoot back
func _spit_test() -> void:
	await _wait(0.5)
	start_game({"map": "field", "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2, "armies": false})
	await _wait(0.5)
	var c: Vector3 = _free_spot(G.world.capture)
	var bait = spawn_soldier(0, c.x, c.z, "pistol")
	bait.order = {"mode": "hold", "point": bait.pos}
	for k in ["spitter", "bloater", "armored"]:
		Soldier.zombie_next = k
		var z = spawn_soldier(1, c.x + 14.0, c.z + (0.0 if k == "spitter" else (25.0 if k == "bloater" else -25.0)), "pistol")
		Soldier.zombie_next = ""
		Modes.make_zombie(z, k)
		z.hp = 99999.0
	var shot = 0
	for i in range(8):
		await _wait(1.0)
		shot = maxi(shot, Modes.spits.size())
		var sz = null
		for z in G.soldiers:
			if z.zombie and z.ztype == "spitter":
				sz = z
		print("SPITTEST t%d spits %d puddles %d bait hp %.0f state %s | spitter d %.1f blocked %s spit_t %.1f now %.1f" % [i, Modes.spits.size(), Modes.puddles.size(), bait.hp, bait.state, G.dist2d(sz.pos, bait.pos), str(G.blocked(sz.head_pos(), bait.chest())), sz.get_meta("spit_t", 0.0), G.sim_time])
		if not Modes.puddles.is_empty():
			print("   puddle at ", Modes.puddles[0]["p"], " bait at ", bait.pos)
	# the bloater bursts when it dies
	for z in G.soldiers:
		if z.zombie and z.ztype == "bloater" and z.state != "dead":
			Combat.kill(z, null, false)
	await _wait(0.5)
	print("SPITTEST bloater burst done, bait state %s hp %.0f" % [bait.state, bait.hp])
	get_tree().quit()

# commander orders: a half-track with troops is sent somewhere, then told to dismount
func _order_test() -> void:
	await _wait(0.5)
	start_game({"map": _arg("map", "field"), "mode": "commander", "size": 8, "limit": 999, "reinforce": false, "armor": "normal", "teams": 2})
	await _wait(1.0)
	var home: Vector3 = G.world.rally_point(0)
	var p0 = _free_spot(home + Vector3(6, 0, 6))
	var v = spawn_vehicle("halftrack", 0, p0, 0.0)
	AI.batch_begin()
	var riders = []
	for i in range(1, v.seats.size()):
		if v.seats[i] == null:
			var r = spawn_soldier(0, p0.x, p0.z, "")
			r.mount(v, i)
			riders.append(r)
	var sq = AI.batch_end()
	print("ORDERTEST riders %d squad %d crew squad %s (crew flag %s)" % [riders.size(), sq["members"].size() if sq != null else -1, str(v.driver().squad != sq), str(v.driver().squad.get("crew", false))])
	var s1 = spawn_soldier(0, home.x, home.z, "")
	print("ORDERTEST lone soldier joined crew squad: %s, joined riders: %s" % [str(s1.squad.get("crew", false)), str(s1.squad == sq)])
	G.pc._select_vehicle(v, false)
	var dest = _free_spot(p0 + G.flat(G.world.capture - p0).normalized() * 45.0)
	var cam = G.pc.cam
	# order straight through the API (the click is the same call)
	v.command(dest)
	for r in riders:
		r.order = {"mode": "move", "point": dest}
	for k in range(8):
		await _wait(4.0)
		print("ORDERTEST t%d dist %.1f speed %.1f aboard %d" % [k * 4, G.dist2d(v.pos, dest), v.speed, riders.filter(func(r): return r.vehicle == v).size()])
	G.pc.selection = riders.duplicate()
	G.pc.sel_vehicle = v
	G.pc.dismount_selected(true)
	await _wait(12.0)
	var on_foot = riders.filter(func(r): return is_instance_valid(r) and r.state == "alive" and r.vehicle == null).size()
	for r in riders:
		print("  rider ", r.state if is_instance_valid(r) else "gone", " veh ", r.vehicle != null if is_instance_valid(r) else "-", " seat ", r.seat if is_instance_valid(r) else -9, " task ", r.task if is_instance_valid(r) else "")
	print("  seats ", v.seats.map(func(x): return "-" if x == null else x.sname), " dead ", v.dead)
	print("ORDERTEST after dismount: on foot %d of %d, crew still aboard %s" % [on_foot, riders.size(), str(v.driver() != null)])
	print("ORDERTEST free spawns: vehicles %d" % G.vehicles.filter(func(x): return x.team == 0 and not x.dead).size())
	get_tree().quit()

func _ladder_test() -> void:
	await _wait(0.5)
	start_game({"map": _arg("map", "town"), "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2, "armies": false})
	var lads = G.world.towers.filter(func(T): return T.get("ladder", false))
	print("LADDERTEST ladders %d" % lads.size())
	if lads.is_empty():
		get_tree().quit()
		return
	var T = lads[0]
	var lo: Vector3 = T["stair_bottom"]
	var s = spawn_soldier(0, lo.x + T["n"].x * 6.0, lo.z + T["n"].z * 6.0, "rifle")
	print("LADDERTEST roof cps %d" % T["cps"].size())
	AI.take_post(s, T["cps"][0])
	for k in range(14):
		await _wait(1.0)
		print("LADDERTEST t%d pos %.1f,%.1f,%.1f ground %.1f climb %s route %s task %s" % [k, s.pos.x, s.pos.y, s.pos.z, G.world.ground_y(s.pos.x, s.pos.z), s.climb != null, s.route != null, s.task])
	AI.go_downstairs(s)
	for k in range(8):
		await _wait(1.0)
		print("LADDERTEST down t%d pos %.1f,%.1f,%.1f climb %s route %s" % [k, s.pos.x, s.pos.y, s.pos.z, s.climb != null, s.route != null])
	get_tree().quit()

func _door_test() -> void:
	await _wait(0.5)
	start_game({"map": _arg("map", "town"), "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2})
	print("DOORTEST doors %d panes %d tables %d" % [Doors.doors.size(), Doors.panes.size(), G.world.tables.size()])
	if not G.world.tables.is_empty():
		var tb = G.world.tables[0]
		var nc = G.world.cols.size()
		G.world.flip_table(tb, Vector3(1, 0, 0))
		print("DOORTEST flipped a table: alive %s cols %d -> %d" % [tb["c"].alive, nc, G.world.cols.size()])
	for dq in Doors.doors:
		print("  door ", dq["c"], " n ", dq["n"])
	if Doors.doors.is_empty():
		get_tree().quit()
		return
	var d = Doors.doors[0]
	var b = G.world.buildings[d["b"]]
	var inside = Vector3(b["x"], 0, b["z"])
	var outside = d["c"] + d["n"] * 5.0
	var s = spawn_soldier(0, outside.x, outside.z, "rifle")
	s.order = {"mode": "hold", "point": s.pos}
	await _wait(0.5)
	for k in range(5):
		AI.go_to(s, inside, 1.0)
		await _wait(1.0)
		print("  walker ", s.pos, " task ", s.task, " mt ", s.move_target, " route ", s.route.size() if s.route != null else -1)
	print("DOORTEST walker at %.1f from door, door goal %.2f ang %.2f, inside %s" % [G.dist2d(s.pos, d["c"]), d["goal"], d["ang"], Doors.building_at(s.pos) == d["b"]])
	# grenade through a window
	var p = null
	var tp = Vector3.ZERO
	for q in Doors.panes:
		if q["alive"] and q["b"] != d["b"]:
			for dd in [9.0, 7.0, 11.0, 5.0, 13.0]:
				var cand = q["c"] + q["n"] * dd
				var hh = Vector3(cand.x, G.world.ground_y(cand.x, cand.z) + 1.6, cand.z)
				if G.ray(hh, q["c"] + q["n"] * 0.3, G.L_WORLD).is_empty() and not G.world.solid_at(cand.x, cand.z, 0.4, hh.y - 1.6):
					p = q
					tp = cand
					break
		if p != null:
			break
	if p != null:
		var bb = G.world.buildings[p["b"]]
		var tgt = Vector3(bb["x"], G.world.ground_y(bb["x"], bb["z"]), bb["z"])
		var th = spawn_soldier(1, tp.x, tp.z, "rifle")
		th.order = {"mode": "hold", "point": th.pos}
		await _wait(0.5)
		var aim = Doors.throw_point(th, tgt)
		var rh = G.ray(th.head_pos(), p["c"] + p["n"] * 0.3, G.L_WORLD, th.rids)
		if not rh.is_empty() and rh.collider.has_meta("col"):
			var cc = rh.collider.get_meta("col")
			print("  hit col lo ", cc.lo, " hi ", cc.hi, " pane c ", p["c"], " w ", p["w"])
		print("DOORTEST window aim changed %s  bld %d/%d  ray %s  n %s  dist %.1f" % [aim != tgt, Doors.building_at(tgt), p["b"], rh.get("position", "clear"), p["n"], G.dist2d(th.pos, p["c"])])
		Combat.throw_grenade(th, aim, "smoke")
		var g = G.grenades[G.grenades.size() - 1]
		await _wait(1.2)
		var gp = g.global_position if is_instance_valid(g) else Vector3.ZERO
		print("DOORTEST grenade inside %s pane broken %s" % [Doors.building_at(gp) == p["b"], not p["alive"]])
	get_tree().quit()

func _breach_test() -> void:
	await _wait(0.5)
	start_game({"map": "town", "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2})
	var b = G.world.buildings[3]
	var e = spawn_soldier(1, b["x"], b["z"], "rifle")
	e.order = {"mode": "hold", "point": e.pos}
	var dir = Vector3(1, 0, 0)
	for k in range(5):
		var p = Vector3(b["x"], 0, b["z"]) - dir * 24.0 + Vector3(0, 0, (k - 2) * 2.0)
		spawn_soldier(0, p.x, p.z, "rifle")
	for t in range(30):
		await _wait(1.0)
		if Squad.events["breach"] > 0 and t > 8:
			break
	var inside = 0
	for o in G.soldiers:
		if o.team == 0 and o.state == "alive" and Squad._building_at(o.pos) != null:
			inside += 1
	print("BREACHTEST events %s enemy %s attackers inside %d" % [str(Squad.events), e.state, inside])
	get_tree().quit()

func _map_test() -> void:
	await _wait(0.5)
	for m in ["river", "forest", "city", "pass", "beach", "random"]:
		var t0 = Time.get_ticks_msec()
		start_game({"map": m, "mode": "assault" if m == "beach" else "frontline", "size": 8, "limit": 100, "reinforce": true, "armor": "light", "reinf_mode": "truck", "teams": 2})
		var load_ms = Time.get_ticks_msec() - t0
		await _wait(15.0)
		var wet = 0
		for o in G.soldiers:
			if o.state == "alive" and G.world.in_water(o.pos.x, o.pos.z):
				wet += 1
		print("MAPTEST %s size %dx%d load %d ms | alive %d v %d | points %d | wading %d | vehicles %d | sim %.2f ms" % [m, G.world.TW, G.world.TH_, load_ms, G.alive_count(0), G.alive_count(1), Obj.points.size(), wet, G.vehicles.size(), (tick_us / 1000.0) / maxi(tick_n, 1)])
		tick_us = 0
		tick_n = 0
	get_tree().quit()

# a man crouching at a post on an upper floor: does he stay put or bob about?
func _crouch_test() -> void:
	if _arg("cshot", "") != "":
		G.ui.visible = false
		G.pc.force_free = true
	await _wait(0.5)
	start_game({"map": _arg("map", "town"), "mode": "sandbox", "size": 1, "limit": 100, "reinforce": false, "armor": "none", "reinf_mode": "instant", "teams": 2})
	await _wait(1.0)
	for s in G.soldiers.duplicate():
		s.queue_free()
	G.soldiers.clear()
	var n = 0
	for T in G.world.towers:
		if T.get("ladder", false) or T["cps"].is_empty() or n >= 3:
			continue
		var cp = T["cps"][0]
		var sb: Vector3 = T["stair_bottom"]
		var s = spawn_soldier(0, sb.x, sb.z, "rifle")
		AI.take_post(s, cp)
		n += 1
	await _wait(float(_arg("crouchwait", "25")))
	for k in range(24):
		await _wait(0.25)
		var line = "CROUCH t%.2f" % (k * 0.25)
		for s in G.soldiers:
			var chest_rel = s.parts[1].global_position.y - s.pos.y
			line += " | y%.2f fl%.2f cr%.2f ct%.2f kn%s pr%s chest%.2f st%s in%s" % [s.pos.y, s.pos.y - G.world.ground_y(s.pos.x, s.pos.z), s.crouch, s.crouch_t, s.kneel, s.prone, chest_rel, s.state, s.in_cover]
		print(line)
	get_tree().quit()
