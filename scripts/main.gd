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
	markers = Node3D.new()
	add_child(markers)
	preview_map("town")
	if "--autotest" in OS.get_cmdline_user_args():
		_autotest()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot_mode(a.substr(7))

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
func apply_time() -> void:
	var t = G.settings["time"]
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
	return G.settings["time"] == "night"

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
	if G.mode in ["frontline", "assault", "laststand"]:
		G.teams = 2
	G.apply_teams()
	G.score = []
	G.cap_score = []
	for t in range(G.team_count()):
		G.score.append(0)
		G.cap_score.append(0.0)
	G.team_size = o.get("size", 10)
	G.limit = o.get("limit", 50)
	G.reinforce = o.get("reinforce", true)
	G.reinf_mode = o.get("reinf_mode", G.reinf_mode)
	G.armor = o.get("armor", G.armor)
	G.world.load_map(o.get("map", "town"))
	Stats.reset()
	Reinforce.reset()
	Obj.reset()
	for t in range(G.team_count()):
		if G.mode == "laststand" and t == 1:
			continue
		for i in range(G.team_size):
			if G.mode == "laststand":
				var c: Vector3 = Obj.points[0]["p"]
				spawn_soldier(0, c.x + randf_range(-8, 8), c.z + randf_range(-8, 8), "")
			else:
				base_spawn(t)
		_starting_vehicles(t)
	refresh_markers()
	G.pc.free_pos = Vector3(-62, G.world.ground_y(-62, -6) + 7.0, -6)
	G.pc.free_yaw = PI / 2.0 + 0.12
	G.pc.free_pitch = -0.12
	G.started = true

func spawn_soldier(team: int, x: float, z: float, wid: String):
	if G.soldiers.size() >= 160:
		cleanup_bodies(true)
	if G.soldiers.size() >= 160:
		return null
	var p = Vector3(x, G.world.ground_y(x, z), z)
	p = G.world.push_out_circle(p, 0.35)[0]
	var s = Soldier.new()
	add_child(s)
	s.setup(team, p.x, p.z, wid if wid != "" else G.random_weapon())
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
	for v in G.vehicles.duplicate():
		if is_instance_valid(v):
			v.step(G.DT)
	for s in G.soldiers.duplicate():
		if is_instance_valid(s):
			s.tick()
	Combat.step_grenades()
	Combat.step_rockets()
	Combat.step_strikes()
	Combat.step_flares()
	G.fx.step(G.DT)
	Stats.step(G.DT)
	Obj.step(G.DT)
	if randf() < 0.05:
		cleanup_bodies(false)

func _process(dt: float) -> void:
	G.fx.update_callouts(dt)
	G.ui.update_hud(dt)
	for f in point_flags:
		if is_instance_valid(f):
			f.get_child(1).rotation.y = sin(Time.get_ticks_msec() * 0.003 + f.position.x) * 0.3

func on_kill(_s, _attacker) -> void:
	Obj.on_death(_s)
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

func on_point_changed(i: int, prev: int, owner: int) -> void:
	var pt = Obj.points[i]
	_set_flag_color(point_flags[i] if i < point_flags.size() else null, G.TEAM_BAND[owner] if owner >= 0 else Color(0.85, 0.85, 0.85))
	if owner >= 0:
		G.ui.message("%s captured point %s" % [G.TEAM_NAMES[owner], pt["name"]])
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
	var kn = _knee_stats()
	print("AUTOTEST %s | knees ok/backward: body %d/%d, target %d/%d" % [tag, kn[0], kn[1], kn[2], kn[3]])
	print("AUTOTEST %s | teams %d alive %s" % [tag, G.team_count(), str(range(G.team_count()).map(func(t): return G.alive_count(t)))])
	print("AUTOTEST %s | alive %d v %d | dead %d | score %d-%d | sim %.2f ms/tick" % [tag, alive[0], alive[1], dead, G.score[0], G.score[1], ms])
	tick_us = 0
	tick_n = 0

func _autotest() -> void:
	print("AUTOTEST start")
	var scen = [["town", "capture", 30.0, "truck"], ["field", "capture", 30.0, "para"], ["trenches", "capture", 30.0, "truck"],
		["valley", "frontline", 75.0, "truck"], ["front", "assault", 50.0, "para"], ["town", "laststand", 45.0, "truck"],
		["field", "capture", 40.0, "truck", 4, "night"], ["town", "deathmatch", 30.0, "para", 3, "dusk"]]
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
	start_game({"map": _arg("map", "town"), "mode": "capture", "size": int(_arg("size", "6")), "limit": 9999, "reinforce": true,
		"armor": _arg("armor", "light"), "reinf_mode": _arg("reinf", "truck"), "teams": int(_arg("teams", "2"))})
	if _arg("flare", "") != "":
		Combat.flare(G.world.capture + Vector3(-20, 0, 0), G.world.capture)
	await _wait(float(_arg("wait", "6")))
	var c: Vector3 = G.world.capture
	await _look(c + Vector3(-40, 25, -10), c)
	await _snap(dir, "overview")
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
