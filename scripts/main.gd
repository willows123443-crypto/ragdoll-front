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
	sm.sky_top_color = Color(0.45, 0.55, 0.66)
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
	env.fog_density = 0.003
	env.fog_aerial_perspective = 0.4
	sky_mat = sm
	var we = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = float(_arg("sun", "0.95"))
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	sun.rotation = Vector3(deg_to_rad(-52), deg_to_rad(-35), 0)
	add_child(sun)
	apply_time()

# day, dusk or night: sky, light and how far soldiers can see
var clock = 0.25          # 0.25 = midday ... 0.6 = dusk ... 0.8 = night ... 1.25 = midday again
var clock_t = 0.0

func _cycle_step(dt: float) -> void:
	if G.settings["time"] != "cycle":
		return
	clock += dt / 900.0          # a full day in fifteen minutes
	clock_t -= dt
	if clock_t <= 0.0:
		clock_t = 1.0
		apply_time()

func apply_time() -> void:
	var t = G.settings["time"]
	if t == "cycle":
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
			sun.light_energy = 0.22
			sun.rotation = Vector3(deg_to_rad(-40), deg_to_rad(30), 0)
			env.ambient_light_color = Color(0.3, 0.38, 0.6)
			env.ambient_light_energy = 0.2
			env.fog_light_color = Color(0.04, 0.05, 0.09)
			env.tonemap_exposure = ex * 1.4
			G.view_range = 45.0
		_:
			sky_mat.sky_top_color = Color(0.45, 0.55, 0.66)
			sky_mat.sky_horizon_color = Color(0.68, 0.7, 0.71)
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

func is_night() -> bool:
	return G.settings["time"] == "night" or (G.settings["time"] == "cycle" and G.view_range < 80.0)

# the cycle mixes the three looks: day (0.25), dusk (0.55), night (0.75), dawn back to day
func _blend_time(c: float) -> void:
	var keys = [[0.0, "night"], [0.15, "dusk"], [0.25, "day"], [0.5, "day"], [0.62, "dusk"], [0.75, "night"], [1.0, "night"]]
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
	sky_mat.ground_horizon_color = A[2].lerp(B[2], k)
	sky_mat.ground_bottom_color = sky_mat.ground_horizon_color.darkened(0.5)
	sun.light_color = A[3].lerp(B[3], k)
	sun.light_energy = lerpf(A[4], B[4], k)
	env.ambient_light_color = A[5].lerp(B[5], k)
	env.ambient_light_energy = lerpf(A[6], B[6], k)
	env.fog_light_color = A[7].lerp(B[7], k)
	G.view_range = lerpf(A[8], B[8], k)
	sun.rotation = Vector3(deg_to_rad(lerpf(-60.0, -8.0, absf(c - 0.375) / 0.375)), deg_to_rad(-35.0 + c * 120.0), 0)
	sun.shadow_enabled = G.settings["shadows"]

func _tod(n: String) -> Array:
	match n:
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
	Combat.clear_all()
	G.fx.clear_all()
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

func preview_map(id: String) -> void:
	_clear()
	G.started = false
	G.world.load_map(id)
	refresh_markers()

func start_game(o: Dictionary) -> void:
	_clear()
	G.mode = o.get("mode", "sandbox")
	G.teams = clampi(o.get("teams", G.teams), 2, 4)
	if G.mode in ["frontline", "assault", "laststand", "breakthrough", "sabotage", "siege", "escort", "rescue", "koth", "commander", "horde"]:
		G.teams = 2
	G.pc.set_rts(false)
	G.apply_teams()
	G.score = []
	G.cap_score = []
	for t in range(G.team_count()):
		G.score.append(0)
		G.cap_score.append(0.0)
	G.team_size = o.get("size", 10)
	if G.mode == "sabotage":
		var keep_t = G.settings["time"]
		G.settings["time"] = "night"
		apply_time()
		G.settings["time"] = keep_t
	G.limit = o.get("limit", 50)
	G.reinforce = o.get("reinforce", true)
	G.reinf_mode = o.get("reinf_mode", G.reinf_mode)
	G.armor = o.get("armor", G.armor)
	G.world.load_map(o.get("map", "town"))
	Stats.reset()
	Reinforce.reset()
	Obj.reset()
	Commander.reset()
	Support.reset()
	Build.reset()
	Modes.reset()
	Build.setup_bases()
	Obj.setup_mode()
	for t in range(G.team_count()):
		if (G.mode == "laststand" or G.mode == "horde") and t == 1:
			continue
		var n_here = G.team_size if o.get("armies", true) else 0
		if G.mode == "sabotage" and t == 0:
			n_here = maxi(4, G.team_size / 2)
		for i in range(n_here):
			if G.mode == "laststand":
				var c: Vector3 = Obj.points[0]["p"]
				spawn_soldier(0, c.x + randf_range(-8, 8), c.z + randf_range(-8, 8), "")
			else:
				base_spawn(t)
		if G.mode == "sabotage" and t == 0:
			for sd in G.soldiers:
				if sd.team == 0:
					sd.satchels = 2
		elif not (G.mode == "escort" and t == 0) and o.get("armies", true):
			_starting_vehicles(t)
	Modes.setup()
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
	var cap = maxi(160, G.team_size * G.teams + 60)
	if G.soldiers.size() >= cap:
		cleanup_bodies(true)
	if G.soldiers.size() >= cap:
		return null
	var p = Vector3(x, G.world.ground_y(x, z), z)
	p = G.world.push_out_circle(p, 0.35)[0]
	var s = Soldier.new()
	add_child(s)
	var cl = "rifleman" if wid != "" else G.pick_class(team)
	if wid == "":
		wid = G.pick(G.CLASSES[cl]["w"])
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
	return v

func _starting_vehicles(t: int) -> void:
	if G.armor == "none":
		return
	var home: Vector3 = G.world.rally_point(t)
	var enemy: Vector3 = G.world.capture
	var yaw = atan2(enemy.x - home.x, enemy.z - home.z)
	var side = Vector3(cos(yaw), 0, -sin(yaw))
	spawn_vehicle("jeep", t, _free_spot(home + side * 16.0), yaw)
	if G.armor == "heavy":
		spawn_vehicle("tank", t, _free_spot(home - side * 18.0), yaw)
	# a mortar pit at the base and machine-gun nests out in front of it (two-sided battles only, to keep it fast)
	if G.team_count() > 2:
		return
	var fwd = G.flat(enemy - home).normalized()
	spawn_vehicle("mortar", t, _free_spot(home - fwd * 6.0 + side * 6.0), yaw)
	if G.mode != "laststand" and G.mode != "sabotage":
		spawn_vehicle("radar", t, _free_spot(home - fwd * 16.0 - side * 8.0), yaw)
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
	tick_us += Time.get_ticks_usec() - t0
	tick_n += 1

func _sim_step() -> void:
	G.sim_time += G.DT
	if not G.over:
		G.game_time += G.DT
	G.path_budget = 4
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
	Commander.step(G.DT)
	Obj.step(G.DT)
	Modes.step(G.DT)
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
		vs.append("%s%d hp%d crew%d spd%.1f%s%s" % [v.kind, v.team, int(v.hp), crew, v.speed, " WRECK" if v.dead else "", (" st%d d%.0f" % [v.mission["stage"], G.dist2d(v.pos, v.mission["drop"])]) if v.mission != null else ""])
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
		["field", "horde", 30.0, "truck"], ["town", "koth", 25.0, "truck"], ["field", "escort", 30.0, "truck"], ["field", "rescue", 25.0, "truck"]]
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
		"armor": _arg("armor", "light"), "reinf_mode": _arg("reinf", "truck"), "teams": int(_arg("teams", "2"))})
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
	start_game({"map": "field", "mode": "capture", "size": 8, "limit": 9999, "reinforce": true, "armor": "none", "reinf_mode": "instant", "teams": 2})
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
	Campaign.active = true
	end_game(1)
	print("RUINTEST first battle: %d pieces, %d wrecked, recorded %d" % [n0, dead, Campaign.ruins(1).size()])
	await _wait(1.0)
	Campaign.data["owner"][1] = 1
	Campaign.attack(1)
	await _wait(1.0)
	print("RUINTEST second battle: %d pieces, ruined at start %d, doors %d" % [G.world.static_cols.size(), G.world.ruined_at_start, Doors.doors.size()])
	get_tree().quit()

# the newer modes: run one for a while and print how it is going
func _mode_test(mode: String) -> void:
	await _wait(0.5)
	if mode == "daily":
		Modes.start_daily()
		print("MODETEST daily ", Modes.daily_text(Modes.daily))
	else:
		start_game({"map": _arg("map", "field"), "mode": mode, "size": int(_arg("size", "10")), "limit": 100, "reinforce": true, "armor": "light", "reinf_mode": "truck", "teams": 2})
	if _arg("dbg", "") != "":
		for j in range(int(_arg("dbgn", "10"))):
			await _wait(0.8)
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
					print("DBG truck drv %s spd %.1f stage %d go %.0f pos %s path %d/%d rev %.1f yaw %.2f fuel %.2f" % [v.driver() != null, v.speed, v.mission["stage"], v.mission["go_t"], v.pos, v.path_i, v.path.size(), v.reverse_t, v.yaw, v.fuel])
					break
	for k in range(int(_arg("secs", "48")) / 8):
		await _wait(8.0)
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
		print("MODETEST %s %ds | %s | alive %d v %d zombies %d | over %s | score %s%s" % [G.mode, (k + 1) * 8, Obj.status_text(), G.alive_count(0), G.alive_count(1), z, G.over, G.cap_score, pz])
		if G.over:
			break
	get_tree().quit()

# doors get kicked open by people walking through them, grenades go in through windows
func _door_test() -> void:
	await _wait(0.5)
	start_game({"map": _arg("map", "town"), "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2})
	print("DOORTEST doors %d panes %d" % [Doors.doors.size(), Doors.panes.size()])
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
