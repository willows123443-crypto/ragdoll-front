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
	if OS.get_cmdline_user_args().is_empty():
		start_attract.call_deferred()
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
		if a == "--warptest":
			_war_test()
		if a.begins_with("--warshot="):
			_war_shot(a.substr(10))
		if a == "--warfight":
			_war_fight()
		if a.begins_with("--kitshot="):
			_kit_shot(a.substr(10))
		if a.begins_with("--meleeshot="):
			_melee_shot(a.substr(12))
		if a == "--audtest":
			_aud_test()
		if a == "--stacktest":
			_stack_test()
		if a == "--restest":
			_res_test()
		if a == "--walltest":
			_wall_test()
		if a == "--savetest":
			_save_test()
		if a.begins_with("--finishshot="):
			_finish_shot(a.substr(13))
		if a.begins_with("--casshot="):
			_cas_shot(a.substr(10))
		if a == "--zedtest":
			_zed_test()
		if a == "--zbench":
			_z_bench()
		if a == "--flanktest":
			_flank_test()
		if a == "--orderstest":
			_orders_test()
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
		if a.begins_with("--hudshot="):
			_hud_shot(a.substr(10))
		if a == "--mapinfo":
			_map_info()
		if a == "--vstuck":
			_vstuck()
		if a == "--vtrace":
			_vtrace()
		if a == "--leveltest":
			_level_test()
		if a == "--levelbattle":
			_level_battle()
		if a == "--wandertest":
			_wander_test()
		if a.begins_with("--arc="):
			Vehicle.ARC_DRIVER = a.substr(6) == "1"
		if a.begins_with("--plant="):
			Soldier.PLANT = a.substr(8) == "1"
		if a.begins_with("--walkshot="):
			_walk_shot(a.substr(11))
		if a.begins_with("--trail="):
			Squad.TRAIL = a.substr(8) == "1"
		if a == "--cohesion":
			_cohesion_test()
		if a.begins_with("--poseshot="):
			_pose_shot(a.substr(11))
		if a.begins_with("--vaultshot="):
			_vault_shot(a.substr(12))
		if a == "--camtest":
			_cam_test()
		if a == "--perfrun":
			_perf_run()
		if a == "--blindtest":
			_blind_test()
		if a == "--pacetest":
			_pace_test()
		if a == "--posttest":
			_post_test()
		if a == "--camptest":
			_camp_test()
		if a.begins_with("--merge="):
			G.merge_boxes = a.substr(8) == "1"
		if a.begins_with("--rails="):
			Vehicle.RAILS = a.substr(8) == "1"
			Vehicle.WATCH = _arg("watch", "1") != "0"
		if a == "--crashtest":
			_crash_test()
		if a == "--invtest":
			_inv_test()
		if a == "--groundtest":
			_ground_test()
		if a == "--rooftest":
			_roof_test()
		if a == "--tutorialtest":
			_tutorial_test()
		if a == "--drawtest":
			_draw_test()
		if a.begins_with("--weather="):
			G.settings["weather"] = a.substr(10)
		if a.begins_with("--polishshot="):
			_polish_shot(a.substr(13))
		if a == "--lanetest":
			_lane_test()
		if a == "--tanktest":
			_tank_test()
		if a.begins_with("--tankshot="):
			_tank_shot(a.substr(11))
		if a.begins_with("--roomshot="):
			_room_shot(a.substr(11))
		if a == "--stuckdump":
			StuckLog.dump = true
		if a == "--stuckrun":
			_stuck_run()
		if a.begins_with("--floorshot="):
			_floor_shot(a.substr(12))
		if a.begins_with("--hqshot="):
			_hq_shot(a.substr(9))
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
		if a.begins_with("--helptest"):
			_help_test(_arg("helpshot", ""))
		if a == "--jamtest":
			_jam_test()
		if a == "--ctltest":
			_ctl_test()
		if a.begins_with("--loadtest="):
			_load_test(a.substr(11))
		if a == "--recruittest":
			_recruit_test()
		if a.begins_with("--varshot="):
			_var_shot(a.substr(10))
		if a == "--balance":
			_balance()
		if a.begins_with("--buildertest="):
			_builder_test(a.substr(14))
		if a.begins_with("--physshot="):
			_phys_shot(a.substr(11))
		if a == "--towtest":
			_tow_test()
		if a.begins_with("--attractshot="):
			_attract_shot(a.substr(14))
		if a.begins_with("--fxshot="):
			_fx_shot(a.substr(9))
		if a.begins_with("--camoshot="):
			_camo_shot(a.substr(11))
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
		# the clock speeds up through the night and slows into the day gradually: a sudden change of pace
		# made the last of dusk collapse into night in a few seconds
		var nf = maxf(smoothstep(0.64, 0.8, c), 1.0 - smoothstep(0.0, 0.1, c))
		clock += dt / 900.0 * lerpf(0.6, 2.2, nf)
	clock_t -= dt
	if clock_t <= 0.0:
		clock_t = 0.2      # the light changes in small steps, five times a second
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
	apply_shadows()
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
		if Weather.kind == "rain":
			# a wet day: low grey cloud, flat light, a little haze (looks only: nobody sees any less far)
			var gr = Color(0.45, 0.48, 0.51)
			sky_mat.sky_top_color = sky_mat.sky_top_color.lerp(gr * 0.82, 0.6)
			sky_mat.sky_horizon_color = sky_mat.sky_horizon_color.lerp(gr, 0.55)
			sky_mat.ground_horizon_color = sky_mat.ground_horizon_color.lerp(gr * 0.85, 0.45)
			sun.light_energy *= 0.62
			env.fog_light_color = env.fog_light_color.lerp(gr, 0.5)
			env.fog_density = 0.0036
		elif Weather.kind == "cold":
			# a hard frost: pale sky, thin cold light, breath hanging in the air
			sky_mat.sky_top_color = sky_mat.sky_top_color.lerp(Color(0.6, 0.7, 0.82), 0.45)
			sky_mat.sky_horizon_color = sky_mat.sky_horizon_color.lerp(Color(0.87, 0.9, 0.93), 0.6)
			sun.light_color = sun.light_color.lerp(Color(0.88, 0.94, 1.0), 0.55)
			sun.light_energy *= 0.9
			env.ambient_light_color = env.ambient_light_color.lerp(Color(0.68, 0.77, 0.92), 0.5)
			env.fog_light_color = env.fog_light_color.lerp(Color(0.86, 0.89, 0.93), 0.6)
			env.fog_density = 0.003
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
	apply_shadows()
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
	Tutorial.stop()
	var m = G.map_id if G.map_id != "custom" else "town"
	Modes.daily = {}
	Campaign.active = false
	preview_map(m)

func preview_map(id: String) -> void:
	_clear()
	G.started = false
	G.attract = false
	G.builder = false
	G.world.load_map(id)
	refresh_markers()

# behind the title screen: a small battle on the menu map, fighting on its own while the camera circles
func start_attract() -> void:
	if G.started or G.editor.active:
		return
	var keep = G.ui.title.visible
	start_game({"map": G.map_id, "mode": "capture", "size": 6, "limit": 999999, "reinforce": true, "armor": "light", "reinf_mode": "truck", "teams": 2, "quiet": true})
	G.attract = true
	G.ui.title.visible = keep
	G.ui.menu.visible = false

func stop_attract() -> void:
	if G.attract:
		preview_map(G.map_id)

func start_game(o: Dictionary) -> void:
	apply_graphics()
	shadow_ups = 0
	shadow_low_t = 0.0
	shadow_high_t = 0.0
	if not Tutorial.starting:
		Tutorial.stop()
	# (what the last battle was saying, the one behind the title screen included, isn't news in this one)
	for box in [G.ui.radio_box, G.ui.feed_box]:
		if box != null and is_instance_valid(box):
			for c in box.get_children():
				c.queue_free()
	G.attract = false
	G.bal = {}
	G.win_team = -2
	# the battle builder: an empty sandbox where both sides are set out by hand
	var bld = G.ui.builder_next
	G.ui.builder_next = false
	G.builder = false
	if G.ui.builder_bar != null:
		G.ui.builder_bar.visible = false
	if bld:
		o = o.duplicate()
		o["mode"] = "sandbox"
		o["size"] = 0
		o["reinforce"] = false
		o["armor"] = "none"
		o["teams"] = 2
		o["armies"] = false
	_clear()
	spawn_q.clear()
	Prep.reset()
	G.storm = false
	G.fx.set_storm(false)
	Weather.reset()
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
	if G.mode not in ["sandbox", "horde"] and G.team_count() == 2 and not Tutorial.starting and not o.get("quiet", false):
		# (your own side's AI commander, when it has one; when you're in command, what's known of theirs)
		if G.settings.get("ai_side", false):
			G.ui.radio(0, "Your commander is %s" % Commander.STYLE_TEXT[Commander.style_of(0)])
		else:
			G.ui.radio(0, "Intelligence: their commander is %s" % Commander.STYLE_TEXT[Commander.style_of(1)])
	Scripted.reset()
	if G.map_id == "custom":
		Scripted.setup(G.custom_map)
		if not o.get("armies", true):
			G.team_size = maxi(Scripted.placed_count(G.custom_map, 0), Scripted.placed_count(G.custom_map, 1))
	G.started = true
	if Weather.wanted() != "clear":
		Weather.apply()
		apply_time()
	refresh_markers()
	G.pc.free_pos = Vector3(-62, G.world.ground_y(-62, -6) + 7.0, -6)
	G.pc.free_yaw = PI / 2.0 + 0.12
	G.pc.free_pitch = -0.12
	G.started = true
	# (the row of tools at the bottom belongs to the mode: it was left showing the last battle's tabs
	# until one of them was clicked)
	G.ui.tab = ""
	G.ui._render_tools()
	if bld:
		G.builder = true
		G.ui.builder_bar_show(true)
		G.pc.set_rts(true)
		G.ui.tab = "units"
		G.ui.tool = G.ui._cards("units")[0][0]
		G.ui._render_tools()

# the battle builder's Start: everybody goes at it
func builder_start() -> void:
	if not G.builder:
		return
	G.builder = false
	G.ui.builder_bar_show(false)
	for t in range(G.team_count()):
		G.orders[t] = {"mode": "free"}
	for s in G.soldiers:
		s.decide_t = 0.0
	Commander.timers = Commander.timers.map(func(x): return 1.0)
	G.audio.radio_click()
	G.ui.message("Battle on!")

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
		cl = Ops.class_swap(team, cl)
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
	# (a horde leaves bodies faster than anything: fewer of them are kept lying about)
	var lim = maxi(0, dead.size() - 10) if force else (24 if G.mode == "horde" and Soldier.horde_lean else 60)
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
var prof2 = [0, 0, 0, 0, 0, 0]      # combat steps, effects, squads, support and fog, commander

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
	Campaign.battle_step()
	var ta = Time.get_ticks_usec()
	for v in G.vehicles.duplicate():
		if is_instance_valid(v):
			v.step(G.DT)
	var tb = Time.get_ticks_usec()
	G.rebuild_sgrid()
	# performance: frozen far-away soldiers think and move every other tick, with a double time step
	var big = G.soldiers.size() >= 36
	var fr = Engine.get_physics_frames()
	for s in G.soldiers.duplicate():
		if not is_instance_valid(s):
			continue
		if (big or s.zombie) and s.lod_frozen and s.state == "alive":
			# the far ones think every third tick (every other while they're in a fight)
			# every third tick when they're not in a fight (every other while they are): with their rifles
			# gliding along with them in between, it doesn't show from the commander view
			var every = 2 if s.vis_t != null or s.supp > 0.3 or s.zombie else 3
			var rem = (fr + s.id) % every
			if rem != 0 and s.zombie and Soldier.horde_lean:
				# (the far-off dead move thirty times a second, not sixty: nothing of theirs is touched on
				# the frames in between, which is most of what each one cost)
				continue
			if rem != 0:
				# (of the in-between frames, one in two gets a fresh pose; on the other he's carried along as he is)
				if Soldier.PERF:
					var g0 = Time.get_ticks_usec()
					s.lod_glide(rem == 1)
					Soldier.pf[3] += Time.get_ticks_usec() - g0
				else:
					s.lod_glide(rem == 1)
				continue
			G.DT = float(every) / 60.0
			s.lod_unglide()
			var y0: float = s.body_yaw
			var a0: float = s.aim_yaw
			s.tick()
			if is_instance_valid(s):
				s.yaw_rate = clampf(G.wrap_a(s.body_yaw - y0) / G.DT, -8.0, 8.0)
				s.aim_rate = clampf(G.wrap_a(s.aim_yaw - a0) / G.DT, -8.0, 8.0)
			G.DT = 1.0 / 60.0
		elif big and s.state == "riding" and not s.is_player and s.mount_t <= 0.0 and (s.hidden_in_vehicle or s.lod_frozen):
			# crews shut inside a vehicle think every third tick; far-off men riding in the open every other
			# one, carried along with their seats in between
			var ev = 3 if s.hidden_in_vehicle else 2
			if (fr + s.id) % ev != 0:
				if not s.hidden_in_vehicle:
					s.rider_glide()
				continue
			G.DT = float(ev) / 60.0
			if Soldier.PERF:
				var r0 = Time.get_ticks_usec()
				s.tick()
				AI.pf["state:riding"] = AI.pf.get("state:riding", 0) + Time.get_ticks_usec() - r0
			else:
				s.tick()
			G.DT = 1.0 / 60.0
		else:
			if s.glide_off != Vector3.ZERO or s.glide_ph != 0.0 or s.glide_yaw != 0.0 or s.glide_aim != 0.0:
				s.lod_unglide()
			if Soldier.PERF and s.state != "alive":
				var d0 = Time.get_ticks_usec()
				var st0: String = s.state
				s.tick()
				AI.pf["state:" + st0] = AI.pf.get("state:" + st0, 0) + Time.get_ticks_usec() - d0
			else:
				s.tick()
	var tc = Time.get_ticks_usec()
	prof[0] += tb - ta
	prof[1] += tc - tb
	Doors.step()
	Levels.step(G.DT)
	Combat.step_grenades()
	Combat.step_rockets()
	Combat.step_strikes()
	Combat.step_flares()
	Combat.step_mines()
	Combat.step_fires()
	var td = Time.get_ticks_usec()
	G.fx.step(G.DT)
	Weather.step(G.DT)
	Tutorial.step(G.DT)
	var te = Time.get_ticks_usec()
	Stats.step(G.DT)
	Squad.step(G.DT)
	var tf = Time.get_ticks_usec()
	Support.step(G.DT)
	Fog.step(G.DT)
	var tg = Time.get_ticks_usec()
	Prod.step(G.DT)
	if not Prep.active():
		if not G.builder:
			Commander.step(G.DT)
		Ops.step(G.DT)
	var th = Time.get_ticks_usec()
	prof2[0] += td - tc
	prof2[1] += te - td
	prof2[2] += tf - te
	prof2[3] += tg - tf
	prof2[4] += th - tg
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

# Shadows: "all", "near" (only what's close to the view casts one), "off", or "auto", which starts with
# all of them and turns them down a step when the frame rate stays low (they are about half of everything
# a frame draws), and back up a step if there's plenty to spare.
var shadow_auto = 2
var shadow_low_t = 0.0
var shadow_high_t = 0.0
var shadow_ups = 0
# ---------------------------------------------------------------- graphics presets
# Low, medium and high set several things at once: how sharp the 3D picture is drawn, shadows, how far
# off men and vehicles are shown in full detail, how many soldiers there can be, and the grass.
const GRAPHICS = {
	"low": {"render_scale": 0.75, "shadow_mode": "off", "lod_dist": 30.0, "max_soldiers": 200, "grass": false},
	"medium": {"render_scale": 1.0, "shadow_mode": "auto", "lod_dist": 55.0, "max_soldiers": 300, "grass": true},
	"high": {"render_scale": 1.0, "shadow_mode": "all", "lod_dist": 80.0, "max_soldiers": 450, "grass": true},
}

# which preset the settings match now ("custom" if none)
func graphics_preset() -> String:
	for k in GRAPHICS:
		var ok = true
		for f in GRAPHICS[k]:
			if str(G.settings.get(f, GRAPHICS["medium"][f])) != str(GRAPHICS[k][f]):
				ok = false
		if ok:
			return k
	return "custom"

func set_graphics(k: String) -> void:
	for f in GRAPHICS[k]:
		G.settings[f] = GRAPHICS[k][f]
	G.settings["shadows"] = true
	shadow_auto = 2
	apply_graphics()
	apply_shadows()
	G.ui.message("Graphics: %s%s" % [k, " (grass changes with the next battle)" if G.started else ""])

func apply_graphics() -> void:
	get_viewport().scaling_3d_scale = clampf(float(G.settings.get("render_scale", 1.0)), 0.5, 1.0)

func apply_shadows() -> void:
	if sun == null:
		return
	var mode: String = G.settings.get("shadow_mode", "auto")
	if not G.settings.get("shadows", true):
		mode = "off"
	var lv: int = {"all": 2, "near": 1, "off": 0}.get(mode, shadow_auto)
	sun.shadow_enabled = lv > 0
	sun.directional_shadow_max_distance = 140.0 if lv >= 2 else 70.0

func _shadow_auto(dt: float) -> void:
	if G.settings.get("shadow_mode", "auto") != "auto" or not G.started or get_tree().paused or DisplayServer.get_name() == "headless":
		return
	var fps = Engine.get_frames_per_second()
	shadow_low_t = shadow_low_t + dt if (fps > 1.0 and fps < 38.0) else 0.0
	shadow_high_t = shadow_high_t + dt if fps >= 57.0 else 0.0
	if shadow_low_t > 5.0 and shadow_auto > 0:
		shadow_auto -= 1
		shadow_low_t = 0.0
		apply_shadows()
		G.ui.message("Shadows turned down to keep the frame rate up (Settings, Shadows, to choose for yourself)")
	elif shadow_high_t > 30.0 and shadow_auto < 2 and shadow_ups < 1:
		shadow_auto += 1
		shadow_ups += 1
		shadow_high_t = 0.0
		apply_shadows()

func _process(dt: float) -> void:
	_shadow_auto(dt)
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
	if G.over or G.attract:
		return
	G.win_team = t
	if OS.get_cmdline_user_args().has("--enddbg"):
		print("ENDGAME team ", t, " at ", G.sim_time, " ", get_stack())
	G.over = true
	if G.player != null:
		G.pc.leave_soldier()
	if _finish_ok():
		_finish_start(t)
		return
	_finish_end(t)

# ---------------------------------------------------------------- the slow-motion finish
# When a battle ends the result doesn't come up at once: for a few seconds everything runs at a quarter
# speed while the camera circles the last thing that happened (the shell that settled it, or the last
# man to fall), then the result is shown. Any key or click skips it. It isn't a recording played back:
# it's the end of the battle itself, slowed down.
var finish_left = 0.0
var finish_team = 0
var finish_p = Vector3.ZERO
var finish_a = 0.0
var finish_ms = 0

func _finish_ok() -> bool:
	# (not in the automatic tests, which end battles by the dozen and wait on what follows)
	var testing = not OS.get_cmdline_user_args().is_empty() and _arg("finishshot", "") == ""
	return G.settings.get("finish_cam", true) and not testing and DisplayServer.get_name() != "headless" and not G.editor.active

func _finish_start(t: int) -> void:
	finish_team = t
	finish_left = 4.5
	finish_ms = Time.get_ticks_msec()
	var cap = "The field is %s" % ("ours" if t == 0 else "theirs")
	finish_p = G.world.capture
	if G.sim_time - float(Combat.last_boom["t"]) < 2.5 and float(Combat.last_boom["pow"]) >= 1.0:
		finish_p = Combat.last_boom["p"]
		cap = "The last shell"
	elif G.sim_time - float(Combat.last_kill["t"]) < 6.0:
		finish_p = Combat.last_kill["p"]
		cap = "The last to fall: %s" % str(Combat.last_kill["name"])
	finish_p.y = G.world.ground_y(finish_p.x, finish_p.z) + 1.0
	var cam = get_viewport().get_camera_3d()
	finish_a = atan2(cam.global_position.z - finish_p.z, cam.global_position.x - finish_p.x) if cam != null else 0.0
	Engine.time_scale = 0.22
	G.ui.finish_bars(true, cap)
	if not RenderingServer.frame_pre_draw.is_connected(_finish_cam):
		RenderingServer.frame_pre_draw.connect(_finish_cam)

# (run just before each frame is drawn, so it has the last word on where the camera is)
func _finish_cam() -> void:
	if finish_left <= 0.0:
		return
	var now = Time.get_ticks_msec()
	var real = (now - finish_ms) / 1000.0
	finish_ms = now
	finish_left -= real
	finish_a += real * 0.28
	var cam = get_viewport().get_camera_3d()
	if cam != null:
		var k = clampf(1.0 - finish_left / 4.5, 0.0, 1.0)
		var rad = lerpf(11.0, 7.5, k)
		var from = finish_p + Vector3(cos(finish_a) * rad, lerpf(4.5, 2.2, k), sin(finish_a) * rad)
		from.y = maxf(from.y, G.world.ground_y(from.x, from.z) + 1.2)
		cam.global_position = from
		cam.look_at(finish_p, Vector3.UP)
		cam.force_update_transform()      # (this late in the frame the move isn't passed on to the renderer otherwise)
	if finish_left <= 0.0:
		_finish_stop()

func _finish_stop() -> void:
	if finish_left > -50.0:
		finish_left = -99.0
		Engine.time_scale = 1.0
		G.ui.finish_bars(false, "")
		_finish_end(finish_team)

func _input(ev: InputEvent) -> void:
	if finish_left > 0.0 and ((ev is InputEventKey and ev.pressed) or (ev is InputEventMouseButton and ev.pressed)):
		finish_left = 0.0
		_finish_stop()
		get_viewport().set_input_as_handled()

func _finish_end(t: int) -> void:
	G.ui.show_win(t)
	G.audio.sting(t == 0)
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
				if _arg("fcls", "") != "":
					sx.set_class(_arg("fcls", "").split(",")[i % _arg("fcls", "").split(",").size()])
				if _arg("fbayo", "") != "" and i % 2 == 1:
					sx.set_weapon("rifle")
					sx.fix_bayonet()
				if _arg("fbayo", "") != "" and i == 4:
					sx.to_sidearm()
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
	if _arg("style", "") != "":
		for t in range(Commander.style.size()):
			Commander.style[t] = _arg("style", "cunning")
			Commander.feint_cd[t] = 20.0
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
		print("MODETEST %s %ds | %s | alive %d v %d zombies %d | over %s | score %s%s" % [G.mode, (k + 1) * 8, Obj.status_text(), G.alive_count(0), G.alive_count(1), z, G.over, G.cap_score, pz + " tac" + str(Tactics.events) + " ops" + str(Ops.events) + " cmd" + str(Commander.events) + " losses" + str(Ops.losses.slice(0, 2)) + " flips %d logs %d drums %d" % [G.vehicles.filter(func(v): return v.has_meta("flipped")).size(), G.world.cols.filter(func(c): return c.alive and c.has_meta("log")).size(), G.world.cols.filter(func(c): return c.alive and c.has_meta("boom")).size()] + " fuel %s" % str(G.vehicles.filter(func(v): return not v.dead and not v.spec.get("static", false) and not v.spec.get("air", false)).map(func(v): return snappedf(v.fuel, 0.01))) + " raze %d hq %s" % [G.soldiers.filter(func(x): return x.state == "alive" and x.task == "raze").size(), str(Build.sites.filter(func(x): return x["kind"] == "hq").map(func(x): return "%d/%d%s" % [x["cols"].filter(func(c): return c.alive).size(), x["cols"].size(), "X" if x["dead"] else ""]))] + " fleet %d/%d runs %s dumps %d" % [Logistics.count(0), Logistics.count(1), str(Logistics.delivered), Build.sites.filter(func(x): return x["kind"] == "supply" and not x["dead"]).size()] + " salvage %d/%d radio %d/%d" % [Salvage.claimed, Salvage.wrecks.size(), RadioPack.taken, RadioPack.dropped.size()] + " inside %d/%d" % [_inside_count(), G.soldiers.filter(func(x): return x.state == "alive").size()] + " route %s stuck %d" % [str(G.world.route_stats), _stuck_count()] + " pts %s earned %s" % [str(Support.points), str(Support.earned)] + " cveh %d/%d depots %d" % [G.vehicles.filter(func(v): return v.team == 0 and not v.dead and v.kind in Support.AI_VEH).size(), G.vehicles.filter(func(v): return v.team == 1 and not v.dead and v.kind in Support.AI_VEH).size(), Build.sites.filter(func(x): return x["kind"] == "depot" and not x["dead"]).size()]])
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

func _hud_shot(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	G.settings["time"] = "day"
	apply_time()
	await _wait(0.3)
	start_game({"map": _arg("map", "field"), "mode": "commander", "size": 10, "limit": 999, "reinforce": true, "armor": "light", "reinf_mode": "truck", "teams": 2})
	await _wait(1.0)
	var h = Build.hq(0)
	var dump = Build.find_spot(h["p"] + G.flat(G.world.capture - h["p"]).normalized() * 50.0, "supply", 15.0, 30, true)
	if dump != null:
		Build.place("supply", 0, dump, G.flat(G.world.capture - dump), true)
	Support.points[0] += 30
	Support.call_in(0, "supplytruck", h["p"])
	await _wait(float(_arg("secs", "30")))
	var trucks = G.vehicles.filter(func(v): return v.kind == "supplytruck" and v.team == 0 and not v.dead)
	var at: Vector3 = trucks[0].pos if not trucks.is_empty() else h["p"]
	G.pc.rts_focus = at
	G.pc.rts_dist = 45.0
	G.ui.radio(0, "Supply truck heading for the supply dump at B4")
	G.ui.cmdhud.alert("test", "Second squad pinned", at, 1.0, Hud.WARN)
	await _wait(1.0)
	print("HUDSHOT trucks ", trucks.size(), " states ", trucks.map(func(v): return G.ui.cmdhud.truck_state(v)[0]))
	await _snap(dir, "commander_hud")
	G.ui.side_list.visible = true
	await _wait(0.3)
	await _snap(dir, "menu_open")
	get_tree().quit()

# how fair a map is: each side's distance to the points, and how much cover lies on each half
func _map_info() -> void:
	await _wait(0.3)
	for m in _arg("maps", "field,valley,town,river").split(","):
		start_game({"map": m, "mode": "capture", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2, "armies": false})
		await _wait(0.3)
		var line = "MAPINFO %s spawn0 (%.0f,%.0f) spawn1 (%.0f,%.0f) rally0 (%.0f,%.0f) rally1 (%.0f,%.0f) |" % [m, G.world.spawn[0].x, G.world.spawn[0].z, G.world.spawn[1].x, G.world.spawn[1].z,
			G.world.rally_point(0).x, G.world.rally_point(0).z, G.world.rally_point(1).x, G.world.rally_point(1).z]
		for pt in Obj.points:
			line += " %s d0=%.0f d1=%.0f |" % [pt["name"], G.dist2d(pt["p"], G.world.spawn[0]), G.dist2d(pt["p"], G.world.spawn[1])]
		var cov = [0, 0]
		var mid: Vector3 = (G.world.spawn[0] + G.world.spawn[1]) * 0.5
		var ax = G.flat(G.world.spawn[1] - G.world.spawn[0]).normalized()
		for cp in G.world.cover:
			cov[0 if G.flat(cp.p - mid).dot(ax) < 0.0 else 1] += 1
		line += " cover %d/%d" % [cov[0], cov[1]]
		print(line)
	get_tree().quit()

# vehicles that want to go somewhere but haven't moved for 20 s: where, why, and what's around them
# --vtrace: catch vehicles see-sawing (going forward, stopping, backing, forward again) and say which rule did it
func _vtrace() -> void:
	await _wait(0.5)
	G.settings["ai_side"] = true
	seed(int(_arg("seed", "5")))
	start_game({"map": _arg("map", "town"), "mode": _arg("mode", "commander"), "size": int(_arg("size", "12")), "limit": 999, "reinforce": true, "armor": _arg("armor", "light"), "reinf_mode": "truck", "teams": 2})
	await _wait(0.5)
	var rec = {}
	var eps = 0
	var cool = {}
	var tot = {}
	for k in range(int(_arg("n", "240")) * 4):
		await _wait(0.25)
		for v in G.vehicles:
			if v.dead or v.spec.get("air", false) or v.spec.get("static", false) or v.driver() == null or v.driver().is_player:
				continue
			var id = v.get_instance_id()
			var r: Array = rec.get(id, [])
			var thr = v._drive_cache[0] if v._drive_cache.size() > 0 else 0.0
			var tags = [v.why, "hm:" + v.hold_mode]
			if v.reverse_t > 0.0: tags.append("rev")
			if v.yield_t > 0.0: tags.append("yield")
			if v.get_meta("leg", 0) != 0 and G.sim_time < v.get_meta("leg_t", 0.0): tags.append("leg%d" % v.get_meta("leg", 0))
			if v.detour != null and G.sim_time < v.detour_t: tags.append("detour")
			if v.stuck_t > 0.5: tags.append("stuck_t")
			if v.get_meta("fw_t", 0.0) > 0.0: tags.append("fw")
			if v.mission != null: tags.append("mis:" + str(v.mission.get("type", "")))
			r.append([v.pos, signf(v.speed) if absf(v.speed) > 0.4 else 0.0, thr, tags])
			if r.size() > 60:
				r.pop_front()
			rec[id] = r
			if r.size() < 60 or G.sim_time < cool.get(id, 0.0):
				continue
			var flips = 0
			var last = 0.0
			for e in r:
				if e[1] != 0.0 and last != 0.0 and e[1] != last:
					flips += 1
				if e[1] != 0.0:
					last = e[1]
			var disp = G.dist2d(r[0][0], r[r.size() - 1][0])
			if flips >= 3 and disp < 12.0:
				eps += 1
				cool[id] = G.sim_time + 20.0
				var h = {}
				for e in r:
					for t in e[3]:
						h[t] = h.get(t, 0) + 1
						tot[t] = tot.get(t, 0) + 1
				print("VTRACE t%d %s T%d (%.0f,%.0f) flips=%d disp=%.1f %s" % [int(G.sim_time), v.kind, v.team, v.pos.x, v.pos.z, flips, disp, str(h)])
	print("VTRACE episodes ", eps, " totals ", tot)
	get_tree().quit()

# --walkshot=DIR: one man walking, then running, then turning on the spot, seen from the side; and how far
# his feet slide over the ground while they're down (metres slid per metre walked)
func _walk_shot(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	G.settings["time"] = "day"
	apply_time()
	await _wait(0.3)
	start_game({"map": "field", "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2})
	await _wait(0.5)
	var p0 = G.main._free_spot(Vector3(0, 0, 40))
	var s = spawn_soldier(0, p0.x, p0.z, "rifle")
	var shots = _arg("shots", "1") == "1"
	for leg in [["walk", 1.6, 6.0], ["run", 5.2, 5.0]]:
		var goal = s.pos + Vector3(leg[1] * leg[2] + 4.0, 0, 0)
		s.order = {"mode": "move", "point": goal}
		AI.go_to(s, goal, leg[1])
		await _wait(1.0)
		var slid = 0.0
		var walked = 0.0
		var hover = 0.0
		var n = 0
		var prev = [s.P[11], s.P[14]]
		var ppos = s.pos
		var frames = int(leg[2] * 60.0) - 60
		for i in range(frames):
			await get_tree().physics_frame
			if s.move_target == null:
				AI.go_to(s, goal, leg[1])
			s.speed_t = leg[1]
			walked += G.dist2d(s.pos, ppos)
			ppos = s.pos
			for k in range(2):
				var fp: Vector3 = s.P[11 + k * 3]
				var gyf = G.world.ground_y(fp.x, fp.z) + 0.07
				if fp.y - gyf < 0.02 and prev[k].y - gyf < 0.02:
					slid += G.dist2d(fp, prev[k])
				prev[k] = fp
			# the lower foot should be on the ground, not hanging above it
			var lowest = minf(s.P[11].y - G.world.ground_y(s.P[11].x, s.P[11].z), s.P[14].y - G.world.ground_y(s.P[14].x, s.P[14].z)) - 0.07
			hover += maxf(0.0, lowest)
			n += 1
			if _arg("dbg", "") != "" and i % 6 == 0 and i < 60:
				print("WS i%d spd=%.1f ok=%s sw=%s L=(%.2f,%.2f,%.2f) R=(%.2f,%.2f,%.2f) hipL=%.2f pos=(%.2f,%.2f) gy=%.2f prone=%s cr=%.1f ph=%.1f stum=%.1f vy=%.1f lod=%s" % [i, s.vel.length(), str(s.foot_ok), str(s.foot_sw), s.P[11].x - s.pos.x, s.P[11].y - s.pos.y, s.P[11].z - s.pos.z, s.P[14].x - s.pos.x, s.P[14].y - s.pos.y, s.P[14].z - s.pos.z, s.P[9].y - s.pos.y, s.pos.x, s.pos.z, G.world.ground_y(s.pos.x, s.pos.z) - s.pos.y, str(s.prone), s.crouch, s.phase, s.stumble, s.vy, str(s.lod_frozen)])
			if shots and i % 9 == 0 and i < 9 * 6:
				await _look(s.pos + Vector3(0.5, 1.0, 4.2), s.pos + Vector3(0.5, 0.8, 0))
				await _snap(dir, "%s_%d" % [leg[0], i / 9])
		print("WALKSHOT %s plant=%s speed=%.1f walked=%.1fm slid=%.2fm (%.0f%%) lowest-foot hover avg=%.3fm" % [leg[0], str(Soldier.PLANT), leg[1], walked, slid, 100.0 * slid / maxf(walked, 0.1), hover / maxf(n, 1)])
	# turning on the spot
	AI.stop_move(s)
	s.order = {"mode": "hold", "point": s.pos}
	await _wait(1.0)
	for i in range(6):
		s.aim_yaw += 0.5
		await _wait(0.25)
		if shots:
			await _look(s.pos + Vector3(0.5, 1.6, 3.6), s.pos + Vector3(0, 0.7, 0))
			await _snap(dir, "turn_%d" % i)
	get_tree().quit()

# --cohesion: an AI battle; for squads on the move and out of contact, how far the men are from their leader
func _cohesion_test() -> void:
	await _wait(0.5)
	G.settings["ai_side"] = true
	seed(int(_arg("seed", "21")))
	start_game({"map": _arg("map", "city"), "mode": _arg("mode", "capture"), "size": 14, "limit": 999, "reinforce": true, "armor": "none", "teams": 2})
	var sum = 0.0
	var n = 0
	var far = 0
	for t in range(int(_arg("secs", "150")) * 2):
		await _wait(0.5)
		for q in G.squads:
			var L = Squad.leader_of(q)
			if L == null or L.vehicle != null or L.state != "alive" or G.sim_time - L.seen_t < 10.0 or L.move_target == null:
				continue
			for m in q["members"]:
				if m == L or not is_instance_valid(m) or m.state != "alive" or m.vehicle != null or m.task != "advance":
					continue
				var d = G.dist2d(m.pos, L.pos)
				sum += d
				n += 1
				if d > 18.0:
					far += 1
	print("COHESION trail=%s map=%s samples=%d avg_dist_to_leader=%.1fm far(>18m)=%.1f%% trail_uses=%d stuck=%s" % [str(Squad.TRAIL), _arg("map", "city"), n, sum / maxf(n, 1), 100.0 * far / maxf(n, 1), Squad.events.get("trail", 0), StuckLog.summary()])
	get_tree().quit()

# --poseshot=DIR: one man going to ground, getting up, and turning on the spot: how far his head jumps
# in a single frame (a snap shows as a big jump), how many steps he takes to turn, and pictures of each
func _pose_shot(dir: String) -> void:
	var shots = dir != "-"
	if shots:
		DirAccess.make_dir_recursive_absolute(dir)
	G.settings["time"] = "day"
	apply_time()
	await _wait(0.3)
	start_game({"map": "field", "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2})
	await _wait(0.5)
	var p0 = G.main._free_spot(Vector3(0, 0, 60))
	var s = spawn_soldier(0, p0.x, p0.z, "rifle")
	s.order = {"mode": "hold", "point": s.pos}
	await _wait(1.5)
	for ph in [["down", true], ["up", false]]:
		var worst = 0.0
		var prev: Vector3 = s.parts[2].global_position - s.pos
		for i in range(54):
			s.prone_t = ph[1]
			AI.stop_move(s)
			await get_tree().physics_frame
			var cur: Vector3 = s.parts[2].global_position - s.pos
			worst = maxf(worst, cur.distance_to(prev))
			prev = cur
			if _arg("dbg", "0") == "1" and i % 6 == 0:
				print("PH %s i%d st=%s prone=%s pel=%s stun=%.2f" % [ph[0], i, s.state, str(s.prone), str(s.parts[0].global_position - s.pos), s.stun])
			if shots and i % 9 == 4:
				await _look(s.pos + Vector3(0.3, 1.0, 4.0), s.pos + Vector3(0, 0.6, 0))
				await _snap(dir, "%s_%d" % [ph[0], i / 9])
		print("POSESHOT going %s: biggest head jump in one frame %.3fm" % [ph[0], worst])
	# turning on the spot: half a turn, in steps
	await _wait(0.5)
	var swings = 0
	var was = [false, false]
	var y0 = s.body_yaw
	for i in range(150):
		s.prone_t = false
		AI.stop_move(s)
		s.aim_yaw = y0 + minf(float(i) / 60.0, 1.0) * PI
		s.body_yaw = s.aim_yaw
		await get_tree().physics_frame
		for k in range(2):
			if s.foot_sw[k] and not was[k]:
				swings += 1
			was[k] = s.foot_sw[k]
		if _arg("dbg", "0") == "1" and i % 6 == 0:
			print("TURN i%d sw=%s by=%.2f cr=%.2f ok=%s seen=%.2f now=%.2f fwL=%s fwR=%s spd=%.2f st=%s veh=%s" % [i, str(s.foot_sw), s.body_yaw, s.crouch, str(s.foot_ok), s.foot_seen, G.sim_time, str(s.foot_w[0] - s.pos), str(s.foot_w[1] - s.pos), s.vel.length(), s.state, str(s.stumble)])
		if shots and i % 15 == 7 and i < 90:
			await _look(s.pos + Vector3(0.3, 2.2, 3.4), s.pos + Vector3(0, 0.5, 0))
			await _snap(dir, "turn_%d" % (i / 15))
	var f = Vector3(sin(s.body_yaw), 0, cos(s.body_yaw))
	var r = Vector3(-f.z, 0, f.x)
	var offL = G.dist2d(s.foot_w[0], s.pos - r * 0.13)
	var offR = G.dist2d(s.foot_w[1], s.pos + r * 0.13)
	print("POSESHOT half turn: body turned %.2f rad, steps taken %d, feet end %.2fm and %.2fm from under him" % [absf(G.wrap_a(s.body_yaw - y0)), swings, offL, offR])
	get_tree().quit()

# --drawtest --map=: what the picture costs to draw in a commander battle: how many separate draws a
# frame takes, and how many of them go when the soldiers, the vehicles, the shadows or the effects are
# taken out (needs a display: run it under xvfb)
func _draw_test() -> void:
	await _wait(0.5)
	G.settings["ai_side"] = true
	seed(7)
	start_game({"map": _arg("map", "town"), "mode": "commander", "size": int(_arg("size", "16")), "limit": 999, "reinforce": true, "armor": "light", "reinf_mode": "truck", "teams": 2})
	await _wait(float(_arg("warm", "25")))
	G.pc.set_rts(true)
	var c = Vector3.ZERO
	var n = 0
	for s in G.soldiers:
		if s.state == "alive":
			c += s.pos
			n += 1
	c /= maxf(n, 1.0)
	G.pc.rts_focus = c
	G.pc.rts_dist = 75.0
	get_tree().paused = true
	var meas = func() -> Array:
		for i in range(4):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		return [int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))]
	var all: Array = await meas.call()
	print("DRAWTEST %s: %d men, %d vehicles in the battle, %d batches of map boxes | whole picture: %d draws, %d objects, %d triangles" % [_arg("map", "town"), G.soldiers.size(), G.vehicles.size(), G.world.groups.size(), all[0], all[1], all[2]])
	if _arg("pic", "") != "":
		get_viewport().get_texture().get_image().save_png(_arg("pic", ""))
	# who the separate pieces belong to: every visible mesh, by what it's part of
	var census = {}
	var stack: Array = [self]
	while not stack.is_empty():
		var nd = stack.pop_back()
		for ch in nd.get_children():
			stack.append(ch)
		if nd is GeometryInstance3D and nd.is_visible_in_tree():
			var key = "other"
			var up = nd
			while up != null and up != self:
				if up is Soldier:
					key = "men"
					break
				if up is Vehicle:
					key = "vehicles"
					break
				if up == G.world.dyn_root:
					key = "things built (bases, HQ, sandbags, works): one mesh a box"
					break
				if up == G.fx:
					key = "effects"
					break
				if up == G.world.geo_root:
					key = "the map (" + ("batched" if nd is MultiMeshInstance3D else "single meshes") + ")"
					break
				if up == G.world:
					key = "the world, other (" + nd.get_class() + ")"
					break
				up = up.get_parent()
			if key == "other":
				var top = nd
				while top.get_parent() != null and top.get_parent() != self:
					top = top.get_parent()
				key = "other: under " + str(top.name).rstrip("0123456789@")
			census[key] = census.get(key, 0) + 1
	var ck = census.keys()
	ck.sort_custom(func(a, b): return census[a] > census[b])
	for k in ck.slice(0, 14):
		print("DRAWTEST   pieces: %5d  %s" % [census[k], k])
	sun.shadow_enabled = false
	var a1: Array = await meas.call()
	print("DRAWTEST   without shadows: %d draws (shadows cost %d)" % [a1[0], all[0] - a1[0]])
	for s in G.soldiers:
		s.visible = false
	var a2: Array = await meas.call()
	print("DRAWTEST   and without the men: %d draws (men cost %d, %.1f each)" % [a2[0], a1[0] - a2[0], (a1[0] - a2[0]) / maxf(G.soldiers.size(), 1.0)])
	for v in G.vehicles:
		v.visible = false
	var a3: Array = await meas.call()
	print("DRAWTEST   and without the vehicles: %d draws (vehicles cost %d, %.1f each)" % [a3[0], a2[0] - a3[0], (a2[0] - a3[0]) / maxf(G.vehicles.size(), 1.0)])
	G.fx.visible = false
	var a4: Array = await meas.call()
	print("DRAWTEST   and without effects (smoke, marks, tracers): %d draws (effects cost %d)" % [a4[0], a3[0] - a4[0]])
	G.ui.root.visible = false
	var a5: Array = await meas.call()
	print("DRAWTEST   and without the interface: %d draws (interface cost %d); what's left is the map itself" % [a5[0], a4[0] - a5[0]])
	get_tree().quit()

# --tutorialtest: the first battle played through by doing what each step asks, the way a player would:
# does every step notice it's been done and move on, and does the enemy stay put?
func _tutorial_test() -> void:
	await _wait(0.5)
	# (the way the title screen does it: with the little battle behind the menu running first)
	if _arg("attract", "") != "":
		start_attract()
		await _wait(float(_arg("attract", "15")))
		stop_attract()
		G.ui.title.visible = false
		G.ui.menu.visible = false
	Tutorial.start()
	await _wait(1.0)
	if _arg("attract", "") != "":
		var lines = []
		if G.ui.radio_box != null:
			for c in G.ui.radio_box.get_children():
				if not c.is_queued_for_deletion() and c.get_child_count() > 0:
					lines.append(c.get_child(0).get_parsed_text())
		print("TUTORIALTEST radio lines at the start: %s | tool %s | attract %s" % [str(lines), G.ui.tool, G.attract])
	var times = []
	var last = -1
	var t = 0.0
	var acted = -1
	while t < 400.0 and Tutorial.on and Tutorial.step_i < 6:
		await _wait(0.5)
		t += 0.5
		if Tutorial.step_i != last:
			times.append("%d at %.0fs" % [Tutorial.step_i + 1, t])
			if StuckLog.dump:
				print("TUTORIALDBG sim %.1f step %d t %.1f pts %s pts0 %s men %d men0 %s" % [G.sim_time, Tutorial.step_i + 1, t, str(Support.points), str(Tutorial.d.get("pts0", "-")), G.soldiers.filter(func(s): return s.team == 0).size(), str(Tutorial.d.get("men0", "-"))])
			last = Tutorial.step_i
		var mine = G.soldiers.filter(func(s): return s.team == 0 and s.state == "alive")
		# (pictures, under xvfb: the first panel, and the squad's tag once it's in the fight)
		var pic = _arg("pic", "")
		if pic != "":
			if Tutorial.step_i == 0 and Tutorial.t_step > 1.0 and not has_meta("tpic0"):
				set_meta("tpic0", true)
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(pic + "/tut_panel.png")
			if Tutorial.step_i == 1 and Tutorial.t_step > 0.6 and not has_meta("tpic1"):
				set_meta("tpic1", true)
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(pic + "/tut_send.png")
			if Tutorial.step_i == 3 and Tutorial.t_step > 3.0 and not has_meta("tpic3"):
				set_meta("tpic3", true)
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(pic + "/tut_attack.png")
			if Tutorial.step_i == 3 and Tutorial.t_step > 3.0 and (mine.any(func(s): return G.sim_time - s.fired_t < 2.0) or Tutorial.t_step > 40.0):
				if mine.size() > 0:
					G.pc.rts_focus = mine[0].pos
					G.pc.rts_dist = 34.0
				await _wait(0.6)
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(pic + "/tut_fight.png")
				print("TUTORIALTEST pictures saved")
				get_tree().quit()
				return
		acted = Tutorial.step_i
		match Tutorial.step_i:
			0:
				G.pc.selection = mine.duplicate()
			1, 3:
				var goal: Vector3 = Tutorial.d["p1"] if Tutorial.step_i == 1 else Tutorial.d["p2"] - Tutorial.d["to"] * 22.0
				for s in mine:
					s.order = {"mode": "move", "point": goal}
					AI.go_to(s, goal + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)), 4.0)
			2:
				G.pc.rts_focus += Vector3(20, 0, 0)
				G.pc.rts_dist += 14.0
				G.pc.rts_yaw += 0.6
			4:
				Support.call_in(0, "artillery", Tutorial.d["p3"])
				await _wait(9.0)
				t += 9.0
				var goal2: Vector3 = Tutorial.d["p3"] - Tutorial.d["to"] * 24.0
				for s in mine:
					s.order = {"mode": "move", "point": goal2}
					AI.go_to(s, goal2 + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)), 4.0)
			5:
				G.ui._recruit(G.ui.RECRUIT.keys()[0], Tutorial.d["p1"])
	print("TUTORIALTEST my side: %s" % str(G.soldiers.filter(func(s): return s.team == 0).map(func(s): return "%s %s hp%d at(%.0f,%.0f) %s" % [s.cls, s.state, int(s.hp), s.pos.x, s.pos.z, str(s.get_meta("death_why", ""))])))
	var foes_moved = 0.0
	for f in Tutorial.foes:
		if is_instance_valid(f) and f.state == "alive":
			foes_moved = maxf(foes_moved, G.dist2d(f.pos, Tutorial.d["p3"]))
	print("TUTORIALTEST reached step %d of 7 (%s) | my men left %d | enemy on the field %d (furthest from its post %.0fm) | enemy vehicles %d, structures %d" % [Tutorial.step_i + 1, ", ".join(times),
		G.soldiers.filter(func(s): return s.team == 0 and s.state == "alive").size(), G.soldiers.filter(func(s): return s.team == 1 and s.state == "alive").size(), foes_moved,
		G.vehicles.filter(func(v): return v.team == 1).size(), Build.sites.filter(func(st): return st["team"] == 1).size()])
	get_tree().quit()

# --rooftest: twelve heavy shells on the Ministry's roof and four grenades in a corridor: what's left of
# the walls, the furniture, and the men on the floor below the roof
func _roof_test() -> void:
	await _wait(0.5)
	start_game({"map": "office", "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2})
	await _wait(1.0)
	var count = func() -> Array:
		var walls = 0
		var furn = 0
		for c in G.world.cols:
			if c.alive and Levels.inside(Vector3((c.lo.x + c.hi.x) * 0.5, 0, (c.lo.z + c.hi.z) * 0.5), 0.5):
				if c.hi.y - c.lo.y > 2.0:
					walls += 1
				elif c.dest:
					furn += 1
		return [walls, furn]
	var c0: Array = count.call()
	var men = []
	for i in range(4):
		var m = spawn_soldier(0, -20.0 + i * 6.0, 0.0, "rifle")
		m.pos.y = Levels.floor_y(2)
		m.order = {"mode": "hold", "point": m.pos}
		men.append(m)
	await _wait(1.0)
	var roof_y: float = Levels.floor_y(3) + 0.1
	for i in range(12):
		Combat.explode(Vector3(-30.0 + i * 5.0, roof_y, randf_range(-8.0, 8.0)), null, 2.0)
		await _wait(0.2)
	await _wait(1.0)
	var c1: Array = count.call()
	var hurt = men.filter(func(m): return m.hp < 99.0 or m.state != "alive").size()
	print("ROOFTEST 12 shells on the roof: walls %d -> %d, furniture %d -> %d, men two storeys below the roof hurt %d of 4 (standing at y %.1f)" % [c0[0], c1[0], c0[1], c1[1], hurt, men[0].pos.y])
	for i in range(4):
		Combat.explode(Vector3(-20.0 + i * 8.0, Levels.floor_y(1) + 0.2, 0.0), null, 1.0)
		await _wait(0.2)
	await _wait(1.0)
	var c2: Array = count.call()
	var hurt2 = men.filter(func(m): return m.hp < 99.0 or m.state != "alive").size()
	print("ROOFTEST 4 grenades in the first-floor corridor: walls %d -> %d, furniture %d -> %d, men standing in that corridor hurt %d of 4" % [c1[0], c2[0], c1[1], c2[1], hurt2])
	var lo = 0
	for d in G.fx.decals:
		if d.visible and Levels.inside(d.global_position, 0.5) and d.global_position.y < Levels.floor_y(1):
			lo += 1
	print("ROOFTEST scorch marks left on the ground floor: %d" % lo)
	get_tree().quit()

# --groundtest --map= --mode=: is the ground the physics knows about the same ground everything else
# stands on? (where it isn't, anything knocked down sinks into the earth, or lies on thin air)
func _ground_test() -> void:
	await _wait(0.5)
	G.settings["ai_side"] = true
	seed(31)
	start_game({"map": _arg("map", "office"), "mode": _arg("mode", "capture"), "size": 16, "limit": 999, "reinforce": true, "armor": "light", "reinf_mode": "truck", "teams": 2})
	await _wait(float(_arg("secs", "3")))
	var b: Rect2 = G.world.bounds
	var worst = 0.0
	var n = 0
	var bad = 0
	var ex = []
	var x = b.position.x + 1.0
	while x < b.end.x:
		var z = b.position.y + 1.0
		while z < b.end.y:
			var g: float = G.world.ground_y(x, z)
			var hit = G.ray(Vector3(x, g + 60.0, z), Vector3(x, g - 60.0, z), G.L_WORLD)
			n += 1
			# the first thing a ray from the sky meets is a roof as often as not: what matters is whether the
			# terrain itself is where it should be, so ask the terrain body alone
			var th = G.world.terrain_height_physics(x, z) if G.world.has_method("terrain_height_physics") else (hit.position.y if not hit.is_empty() else -999.0)
			var d = absf(th - g)
			if d > 0.35:
				bad += 1
				if ex.size() < 8:
					ex.append("(%.0f, %.0f): stands at %.2f, physics %.2f" % [x, z, g, th])
			worst = maxf(worst, d)
			z += 2.0
		x += 2.0
	print("GROUNDTEST %s: %d points, %d where the physics ground is more than 35 cm off (worst %.2f m) %s" % [_arg("map", "office"), n, bad, worst, str(ex)])
	get_tree().quit()

# --invtest --map= --mode= --secs= --armor=: an AI battle watched for things that should never be true:
# men hanging in the air or sunk in the ground, standing inside a wall, off the map, lying "getting up"
# for ever, bodies and rubble at rest on nothing, vehicles in the air or under the ground
func _inv_test() -> void:
	await _wait(0.5)
	G.settings["ai_side"] = true
	seed(int(_arg("seed", "31")))
	start_game({"map": _arg("map", "town"), "mode": _arg("mode", "commander"), "size": int(_arg("size", "16")), "limit": 999, "reinforce": true, "armor": _arg("armor", "heavy"), "reinf_mode": "truck", "teams": 2})
	var secs = float(_arg("secs", "200"))
	var bad = {}
	var ex = {}
	var note = func(k: String, txt: String):
		bad[k] = bad.get(k, 0) + 1
		if not ex.has(k):
			ex[k] = []
		if ex[k].size() < 3:
			ex[k].append(txt)
	var t = 0.0
	var b: Rect2 = G.world.bounds
	while t < secs:
		await _wait(1.0)
		t += 1.0
		for s in G.soldiers:
			if not is_instance_valid(s) or s.parts.is_empty():
				continue
			var p: Vector3 = s.pos
			if is_nan(p.x) or is_nan(p.y) or is_nan(p.z):
				note.call("man: position not a number", "%s %s" % [s.state, str(s.task)])
				continue
			var tag = "%s/%s at (%.0f, %.1f, %.0f) t=%.0f" % [s.state, str(s.task), p.x, p.y, p.z, t]
			if s.state == "alive" and s.vehicle == null and s.vault == null and s.climb == null and not s.swim:
				var sy: float = G.world.surface_y(p.x, p.z, p.y + 0.6)
				var k1 = "air" if p.y - sy > 1.3 and absf(s.vy) < 0.5 else ("sunk" if sy - p.y > 0.7 else "")
				if k1 != "":
					var n1: int = s.get_meta("iv_" + k1, 0) + 1
					s.set_meta("iv_" + k1, n1)
					if n1 == 3:
						note.call("man: standing %s for 3 s" % ("in the air" if k1 == "air" else "sunk in the ground"), tag + " surface %.1f" % sy)
				else:
					s.set_meta("iv_air", 0)
					s.set_meta("iv_sunk", 0)
				if G.world.inside_any(p.x, p.z, -0.12, p.y + 0.9):
					var n2: int = s.get_meta("iv_wall", 0) + 1
					s.set_meta("iv_wall", n2)
					if n2 == 4:
						note.call("man: inside something solid for 4 s", tag)
				else:
					s.set_meta("iv_wall", 0)
				if not b.grow(8.0).has_point(Vector2(p.x, p.z)):
					var n3: int = s.get_meta("iv_out", 0) + 1
					s.set_meta("iv_out", n3)
					if n3 == 20:
						note.call("man: off the map for 20 s", tag)
				if s.hp <= 0.0:
					note.call("man: alive with no health", tag)
			if s.state == "getup" or s.state == "down":
				var n4: int = s.get_meta("iv_down", 0) + 1
				s.set_meta("iv_down", n4)
				if n4 == 15:
					note.call("man: down or getting up for 15 s", tag)
			else:
				s.set_meta("iv_down", 0)
			if s.state == "dead" and s.settled and s.dragger == null and s.carried_by == null:
				var pp: Vector3 = s.parts[0].global_position
				var sy2: float = G.world.surface_y(pp.x, pp.z, pp.y + 0.3)
				if pp.y - sy2 > 1.0 and not s.has_meta("iv_body"):
					s.set_meta("iv_body", true)
					note.call("body: at rest in the air", "(%.0f, %.1f, %.0f) surface %.1f t=%.0f" % [pp.x, pp.y, pp.z, sy2, t])
		for v in G.vehicles:
			if not is_instance_valid(v):
				continue
			var vp: Vector3 = v.pos
			if is_nan(vp.x) or is_nan(vp.z):
				note.call("vehicle: position not a number", v.kind)
				continue
			if v.spec.get("air", false) or v.spec.get("boat", false):
				continue
			var gy: float = G.world.surface_y(vp.x, vp.z, vp.y + 1.0)
			if (vp.y - gy > 2.0 or gy - vp.y > 1.2) and not v.has_meta("iv_y"):
				v.set_meta("iv_y", true)
				note.call("vehicle: %s the ground" % ("above" if vp.y > gy else "under"), "%s%s at (%.0f, %.1f, %.0f) ground %.1f t=%.0f" % [v.kind, " (wreck)" if v.dead else "", vp.x, vp.y, vp.z, gy, t])
			if not b.grow(40.0).has_point(Vector2(vp.x, vp.z)) and not v.has_meta("iv_o"):
				v.set_meta("iv_o", true)
				note.call("vehicle: far off the map", "%s at (%.0f, %.0f) t=%.0f" % [v.kind, vp.x, vp.z, t])
		for d in G.fx.debris_list:
			var db = d["b"]
			if is_instance_valid(db) and d.get("still", false) and not d.has("iv"):
				var dp: Vector3 = db.global_position
				if dp.y - G.world.ground_y(dp.x, dp.z) > 0.6 and G.ray(dp + Vector3(0, 0.1, 0), dp - Vector3(0, 0.8, 0), G.L_WORLD).is_empty():
					d["iv"] = true
					note.call("rubble: at rest in the air", "(%.0f, %.1f, %.0f) t=%.0f" % [dp.x, dp.y, dp.z, t])
		for i in range(G.fx.clod_xf.size()):
			if G.fx.clod_xf[i] != null:
				var cp3: Vector3 = G.fx.clod_xf[i].origin
				if cp3.y - G.world.surface_y(cp3.x, cp3.z, cp3.y + 0.3) > 0.5:
					note.call("clod: at rest in the air (per second)", "(%.0f, %.1f, %.0f) t=%.0f" % [cp3.x, cp3.y, cp3.z, t])
	var keys = bad.keys()
	keys.sort()
	print("INVTEST %s/%s %.0fs: %d kinds of trouble; men %d, vehicles %d" % [_arg("map", "town"), _arg("mode", "commander"), secs, keys.size(), G.soldiers.size(), G.vehicles.size()])
	var booms = {}
	for k in G.bal.keys():
		if str(k).begins_with("boom: "):
			booms[str(k).substr(6)] = G.bal[k]
	print("INVTEST   explosions: %s" % str(booms))
	var built = [0, 0]
	var going = [0, 0]
	var inside_b = 0
	for st in Build.sites:
		if st["team"] >= 0 and st["team"] < 2 and not st["dead"]:
			if st["done"]:
				built[st["team"]] += 1
			else:
				going[st["team"]] += 1
			if Levels.on and Levels.inside(st["p"], 0.0):
				inside_b += 1
	print("INVTEST   structures finished %s, still going up %s, inside the storeyed building %d | fire missions so far: next allowed at %s (now %.0f)" % [str(built), str(going), inside_b, str(Support.arty_next.slice(0, 2).map(func(v): return int(v))), G.sim_time])
	for k in keys:
		print("INVTEST   %s x%d  e.g. %s" % [k, bad[k], " | ".join(ex[k])])
	get_tree().quit()

# do two vehicles' outlines (seen from above, a little inside their real edges) overlap?
func _veh_overlap(a, b, shrink: float) -> bool:
	var ca: Vector3 = a.pos
	var cb: Vector3 = b.pos
	var fa: Vector3 = a.forward()
	var fb: Vector3 = b.forward()
	var axes = [Vector2(fa.x, fa.z), Vector2(fa.z, -fa.x), Vector2(fb.x, fb.z), Vector2(fb.z, -fb.x)]
	var ha = [a.spec["len"] * 0.5 - shrink, a.spec["wid"] * 0.5 - shrink]
	var hb = [b.spec["len"] * 0.5 - shrink, b.spec["wid"] * 0.5 - shrink]
	var d = Vector2(cb.x - ca.x, cb.z - ca.z)
	for ax in axes:
		var ra = absf(axes[0].dot(ax)) * ha[0] + absf(axes[1].dot(ax)) * ha[1]
		var rb = absf(axes[2].dot(ax)) * hb[0] + absf(axes[3].dot(ax)) * hb[1]
		if absf(d.dot(ax)) > ra + rb:
			return false
	return true

# --crashtest --map= --mode= --secs= --armor=: an AI battle with vehicles, counting every time two of them
# run into each other (their outlines overlapping), who was moving, and how long they stayed locked together
var stall = {}
var stall_max = 0.0
var stall_at = ""
func _crash_test() -> void:
	await _wait(0.5)
	G.settings["ai_side"] = _arg("aiside", "1") == "1"
	seed(int(_arg("seed", "21")))
	start_game({"map": _arg("map", "town"), "mode": _arg("mode", "commander"), "size": int(_arg("size", "14")), "limit": 999, "reinforce": true, "armor": _arg("armor", "heavy"), "reinf_mode": "truck", "teams": 2})
	var secs = float(_arg("secs", "240"))
	var touching = {}
	var events = 0
	var stuck_s = 0.0
	var kinds = {}
	var veh_s = 0.0
	var shown = 0
	var t = 0.0
	while t < secs:
		await _wait(0.1)
		t += 0.1
		var vs = G.vehicles.filter(func(v): return is_instance_valid(v) and not v.spec.get("air", false) and not v.spec.get("static", false) and v.kind != "mortar")
		# (--dump=1: you're in command and have had a supply dump built 75 m out from your headquarters)
		if _arg("dump", "") != "" and absf(t - 3.0) < 0.05:
			var hq0 = Build.hq(0)
			if hq0 != null:
				var out: Vector3 = (G.world.capture - hq0["p"])
				out.y = 0.0
				var dp = G.main._free_spot(hq0["p"] + out.normalized() * 75.0)
				Build.place("supply", 0, dp, out.normalized(), true, true)
		# (--dry=1: every supply lorry's tank is all but empty, twenty seconds in)
		if _arg("dry", "") != "" and absf(t - 20.0) < 0.05:
			for v in G.vehicles:
				if v.kind == "supplytruck" or v.kind == "ammotruck":
					v.fuel = 0.01
		if int(t * 10.0 + 0.5) % 600 == 0:
			var sites = [{}, {}]
			for st in Build.sites:
				if st["team"] < 2:
					var kk = str(st["kind"]) + ("" if Build.alive(st) else "(x)")
					sites[st["team"]][kk] = sites[st["team"]].get(kk, 0) + 1
			print("CRASHTEST t=%.0f fleets %d/%d started %s runs %s pts %s alive %d/%d sites %s" % [t, Logistics.count(0), Logistics.count(1), str(Logistics.started), str(Logistics.delivered), str(Support.points), G.alive_count(0), G.alive_count(1), str(sites)])
		for v in vs:
			if not v.dead and (v.kind == "supplytruck" or v.kind == "ammotruck") and v.mission != null and (v.why == "drive" or _arg("dump", "") != ""):
				var st0 = stall.get(v.get_instance_id(), [v.pos, 0.0])
				if G.dist2d(v.pos, st0[0]) > 4.0:
					st0 = [v.pos, 0.0]
				else:
					st0[1] += 0.1
					if st0[1] > stall_max:
						stall_max = st0[1]
						stall_at = "%s t%d at (%.0f, %.0f) rails %s gap %.1f why '%s' driver %s goal %.0f m path %d mission %s" % [v.kind, v.team, v.pos.x, v.pos.z, v._on_rails(), v.rail_gap, v.why, v.driver() != null, G.dist2d(v.goal, v.pos), v.path.size(), str(v.mission).substr(0, 160)]
				stall[v.get_instance_id()] = st0
		for v in vs:
			if not v.dead and absf(v.speed) > 0.5:
				veh_s += 0.1
		var now = {}
		for i in range(vs.size()):
			for j in range(i + 1, vs.size()):
				var a = vs[i]
				var b = vs[j]
				if a.dead and b.dead:
					continue
				if a.towing == b or b.towing == a:
					continue
				if G.dist2d(a.pos, b.pos) > (a.spec["len"] + b.spec["len"]) * 0.5 + 1.0 or absf(a.pos.y - b.pos.y) > 2.5:
					continue
				# (two parked out of sight beyond the edge of the map, waiting to come on, don't count)
				if not G.world.bounds.has_point(Vector2(a.pos.x, a.pos.z)) and not G.world.bounds.has_point(Vector2(b.pos.x, b.pos.z)):
					continue
				if not _veh_overlap(a, b, 0.12):
					continue
				var key = "%d_%d" % [a.get_instance_id(), b.get_instance_id()]
				now[key] = true
				stuck_s += 0.1
				if not touching.has(key):
					events += 1
					var why = "%s%s" % ["wreck" if (a.dead or b.dead) else ("friends" if a.team == b.team else "enemies"), "/both moving" if (absf(a.speed) > 0.8 and absf(b.speed) > 0.8) else ("/one moving" if (absf(a.speed) > 0.8 or absf(b.speed) > 0.8) else "/neither moving")]
					kinds[why] = kinds.get(why, 0) + 1
					if shown < 14:
						shown += 1
						print("CRASH t=%.0f %s(%s spd %.1f %s%s) into %s(%s spd %.1f %s%s) %s at (%.0f, %.0f)" % [t, a.kind, "dead" if a.dead else "t%d" % a.team, a.speed, str(a.get_meta("arc_why", "")), " ghost" if (not a.dead and a.ghosting()) else "",
							b.kind, "dead" if b.dead else "t%d" % b.team, b.speed, str(b.get_meta("arc_why", "")), " ghost" if (not b.dead and b.ghosting()) else "", why, a.pos.x, a.pos.z])
						if StuckLog.dump:
							for m in [a, b]:
								if absf(m.speed) > 0.8:
									print("CRASHDBG %s yaw %.2f pick %s block %.1f hold %.1f mission %s | %s" % [m.kind, m.yaw, str(m.arc_pick), m.arc_block, m.arc_hold, str(m.mission.get("type", "?")) if m.mission != null else "-", str(m.get_meta("arc_dbg", "")).substr(0, 420)])
		touching = now
	print("CRASHTEST %s: %d collisions in %.0f vehicle-seconds of driving (%.1f per 100) | %.0f s spent overlapping | %s" % [_arg("map", "town"), events, veh_s, events * 100.0 / maxf(veh_s, 1.0), stuck_s, str(kinds)])
	print("CRASHTEST supply runs delivered %s, stuck events: %s | longest a lorry sat still on a run: %.0f s (%s)" % [str(Logistics.delivered), StuckLog.summary(), stall_max, stall_at])
	for v in G.vehicles:
		if not v.dead and (v.kind == "supplytruck" or v.kind == "ammotruck"):
			print("CRASHTEST   lorry t%d %s at (%.0f, %.0f) spd %.1f mission %s rails %s wait %.1f gap %.1f path %d driver %s" % [v.team, v.kind, v.pos.x, v.pos.z, v.speed, str(v.mission.get("type", "?")) + "/" + str(v.mission.get("state", v.mission.get("leg", "?"))) if v.mission != null else "-", v._on_rails(), v.rail_wait, v.rail_gap, v.path.size(), v.driver() != null])
	print("CRASHTEST   fleets %d/%d points %s" % [Logistics.count(0), Logistics.count(1), str(Support.points)])
	get_tree().quit()

# --blindtest --map= --mode= --secs= --size=: an AI battle watched for men who have an enemy in plain view
# close by and either haven't noticed him or aren't shooting: man-seconds of each, and what those men were doing
# --pacetest --map= --mode= --secs= --size=: men who walk a long way and get nowhere. Every half-minute,
# anyone who covered more than 22 m but never got 7 m from where he started, with no enemy in sight and
# without firing, is counted as pacing, and the last places he was sent (and by what) are printed.
func _pace_test() -> void:
	await _wait(0.5)
	G.settings["ai_side"] = _arg("aiside", "1") == "1"
	seed(int(_arg("seed", "5")))
	AI.pace_dbg = true
	start_game({"map": _arg("map", "town"), "mode": _arg("mode", "commander"), "size": int(_arg("size", "14")), "limit": 999, "reinforce": true, "armor": _arg("armor", "light"), "reinf_mode": "truck", "teams": 2})
	var secs = float(_arg("secs", "240"))
	var win = {}
	var t = 0.0
	var paced = 0
	var man_windows = 0
	var shown = 0
	var by_who = {}
	while t < secs:
		await _wait(0.5)
		t += 0.5
		for s in G.soldiers:
			if s.state != "alive" or s.vehicle != null or s.is_player:
				win.erase(s.id)
				continue
			if not win.has(s.id):
				win[s.id] = {"p0": s.pos, "last": s.pos, "len": 0.0, "far": 0.0, "busy": false, "t": 0.0, "in": 0}
			var w = win[s.id]
			w["len"] += G.dist2d(s.pos, w["last"])
			w["last"] = s.pos
			w["far"] = maxf(w["far"], G.dist2d(s.pos, w["p0"]))
			w["t"] += 0.5
			if s.vis_t != null or G.sim_time - s.fired_t < 3.0 or s.supp > 0.3:
				w["busy"] = true
			if G.world.inside_any(s.pos.x, s.pos.z, 0.2):
				w["in"] += 1
			if w["t"] >= 30.0:
				man_windows += 1
				if w["len"] > float(_arg("len", "22")) and w["far"] < float(_arg("far", "7")) and (not w["busy"] or _arg("busy", "") != "") and (w["in"] >= 30 or _arg("anywhere", "") != ""):
					paced += 1
					var lg: Array = s.get_meta("pace_log", [])
					var key = ""
					if not lg.is_empty():
						key = str(lg[lg.size() - 1]).split(" ")[1]
					by_who[key] = by_who.get(key, 0) + 1
					if shown < 8:
						shown += 1
						print("PACE t=%.0f team %d %s walked %.0f m inside %.0f m (indoors %d%%) task %s order %s cover %s | %s" % [t, s.team, s.cls, w["len"], w["far"], int(100.0 * w["in"] / 60.0), str(s.task),
							str(s.order.get("tag", s.order.get("mode", "?"))) if s.order != null else "free", s.cover != null, " | ".join(lg.slice(maxi(0, lg.size() - 8)))])
				win.erase(s.id)
	print("PACETEST %s/%s: %d pacing half-minutes out of %d (%.1f%%) | sent by: %s" % [_arg("map", "town"), _arg("mode", "commander"), paced, man_windows, 100.0 * paced / maxf(1.0, man_windows), str(by_who)])
	get_tree().quit()

# --posttest --map= --secs=: how long men stay at a lookout post (a roof, a tower, an upstairs window) once
# they've reached it, and what they were doing when they left
func _post_test() -> void:
	await _wait(0.5)
	G.settings["ai_side"] = true
	seed(int(_arg("seed", "9")))
	AI.pace_dbg = true
	start_game({"map": _arg("map", "town"), "mode": _arg("mode", "capture"), "size": int(_arg("size", "16")), "limit": 999, "reinforce": true, "armor": "none", "reinf_mode": "truck", "teams": 2,
		"cls": [["sniper", "spotter", "sniper", "spotter", "sniper", "rifleman", "rifleman", "mg", "sniper", "rifleman", "rifleman", "mg", "sniper", "spotter", "rifleman", "rifleman"], ["sniper", "spotter", "sniper", "spotter", "sniper", "rifleman", "rifleman", "mg", "sniper", "rifleman", "rifleman", "mg", "sniper", "spotter", "rifleman", "rifleman"]]})
	var secs = float(_arg("secs", "240"))
	var at = {}
	var stays = []
	var shown = 0
	var t = 0.0
	while t < secs:
		await _wait(0.25)
		t += 0.25
		for s in G.soldiers:
			var up = s.state == "alive" and s.task == "post" and s.in_cover and s.pos.y - G.world.ground_y(s.pos.x, s.pos.z) > 1.8
			if up and not at.has(s.id):
				at[s.id] = t
			elif not up and at.has(s.id):
				var d: float = t - at[s.id]
				at.erase(s.id)
				if s.state == "alive":
					stays.append(d)
					if d < 8.0 and shown < 6:
						shown += 1
						var lg: Array = s.get_meta("pace_log", [])
						print("POST t=%.0f %s (team %d) left after %.1f s: task %s order %s supp %.2f hp %d sees %s | %s" % [t, s.cls, s.team, d, str(s.task), str(s.order.get("mode", "?")) if s.order != null else "free", s.supp, int(s.hp), s.vis_t != null, " | ".join(lg.slice(maxi(0, lg.size() - 3)))])
	for id in at:
		stays.append(t - at[id])
	stays.sort()
	print("POSTTEST %s: %d stays at a post | shortest %.1f s, middle %.1f s, longest %.1f s | under 8 s: %d" % [_arg("map", "town"), stays.size(), stays[0] if not stays.is_empty() else 0.0,
		stays[stays.size() / 2] if not stays.is_empty() else 0.0, stays[stays.size() - 1] if not stays.is_empty() else 0.0, stays.filter(func(x): return x < 8.0).size()])
	get_tree().quit()

# --orderstest: the new orders do what they say: hold fire, ambush, patrol, and garrisoning a building
func _orders_test() -> void:
	await _wait(0.3)
	seed(12)
	start_game({"map": "field", "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2})
	await _wait(0.5)
	var c: Vector3 = G.main._free_spot(Vector3(0, 0, 0))
	var men = []
	for k in range(5):
		men.append(spawn_soldier(0, c.x + (k - 2) * 2.0, c.z, "rifle"))
	G.pc.selection = men.duplicate()
	G.pc.order_selected("holdfire")
	var foes = []
	for k in range(2):
		var e = spawn_soldier(1, c.x + k * 4.0, c.z + 50.0, "rifle")
		e.order = {"mode": "hold", "point": e.pos}
		e.set_meta("hold_fire", 1)
		foes.append(e)
	var t0 = G.sim_time
	await _wait(8.0)
	var early = men.filter(func(m): return m.fired_t > t0).size()
	G.pc.order_selected("holdfire")
	await _wait(6.0)
	var late = men.filter(func(m): return m.fired_t > t0 + 8.0).size()
	print("ORDERTEST hold fire: %d of 5 fired in 8 s with the enemy in view at 50 m; after weapons free, %d fired within 6 s" % [early, late])
	# ambush: enemy walks in
	start_game({"map": "field", "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2})
	await _wait(0.5)
	men = []
	for k in range(5):
		men.append(spawn_soldier(0, c.x + (k - 2) * 2.0, c.z, "rifle"))
	G.pc.selection = men.duplicate()
	G.pc.order_selected("ambush")
	foes = []
	for k in range(3):
		var e2 = spawn_soldier(1, c.x + (k - 1) * 3.0, c.z + 75.0, "rifle")
		e2.order = {"mode": "move", "point": Vector3(c.x, 0, c.z - 20.0)}
		e2.set_meta("hold_fire", 1)
		AI.go_to(e2, Vector3(c.x + (k - 1) * 3.0, 0, c.z - 20.0), 3.0)
		foes.append(e2)
	var first = -1.0
	var t = 0.0
	t0 = G.sim_time
	while t < 40.0 and first < 0.0:
		await _wait(0.1)
		t += 0.1
		if men.any(func(m): return m.fired_t > t0):
			var near = 1e9
			for e3 in foes:
				for m in men:
					near = minf(near, G.dist2d(e3.pos, m.pos))
			first = near
	await _wait(4.0)
	print("ORDERTEST ambush: first shot when the nearest enemy was %.0f m off (set at 75 m, sprung at 30); %d of 5 firing after it's sprung" % [first, men.filter(func(m): return G.sim_time - m.fired_t < 4.0).size()])
	# patrol
	start_game({"map": "field", "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2})
	await _wait(0.5)
	men = []
	for k in range(4):
		men.append(spawn_soldier(0, c.x + (k - 2) * 2.0, c.z, "rifle"))
	var far_end = c + Vector3(34.0, 0, 0)
	for m in men:
		m.order = {"mode": "move", "point": far_end, "patrol": [m.pos, far_end], "attack": true, "tag": "patrol"}
		AI.go_to(m, far_end, 3.2)
	var seen_far = {}
	var back = {}
	t = 0.0
	while t < 90.0:
		await _wait(0.5)
		t += 0.5
		for m in men:
			if G.dist2d(m.pos, far_end) < 7.0:
				seen_far[m.id] = true
			elif seen_far.has(m.id) and G.dist2d(m.pos, c) < 9.0:
				back[m.id] = true
	print("ORDERTEST patrol: %d of 4 reached the far end of a 34 m beat, %d of 4 came back again, in 90 s" % [seen_far.size(), back.size()])
	# garrison
	start_game({"map": "town", "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2})
	await _wait(0.5)
	var bld = null
	for col in G.world.cols:
		if col.has_meta("bld"):
			var b = col.get_meta("bld")
			if bld == null or b["w"] * b["d"] > bld["w"] * bld["d"]:
				bld = b
	if bld == null:
		print("ORDERTEST garrison: no building found")
	else:
		var mid = Vector3(bld["x"], G.world.ground_y(bld["x"], bld["z"]), bld["z"])
		men = []
		for k in range(6):
			var sp = G.main._free_spot(mid + Vector3(bld["w"] * 0.5 + 8.0 + k * 1.5, 0, 0))
			men.append(spawn_soldier(0, sp.x, sp.z, "rifle"))
		G.pc.selection = men.duplicate()
		var ok = G.pc._garrison(mid)
		await _wait(30.0)
		var inside = men.filter(func(m): return m.state == "alive" and absf(m.pos.x - bld["x"]) < bld["w"] * 0.5 + 0.8 and absf(m.pos.z - bld["z"]) < bld["d"] * 0.5 + 0.8).size()
		print("ORDERTEST garrison: order taken %s; after 30 s %d of 6 are inside the %.0f x %.0f m building, %d at a window or door, %d upstairs" % [ok, inside, bld["w"], bld["d"],
			men.filter(func(m): return m.cover != null and m.in_cover).size(), men.filter(func(m): return m.pos.y - mid.y > 1.8).size()])
	get_tree().quit()

# --flanktest --old=1 --runs=: (1) a squad in a firefight to its front has two enemies appear behind it: how
# long until one of its men fires at them, and who's left; (2) a squad sent across the front of an enemy
# section on a plain move order: do they stop and fight, or walk on past
func _flank_test() -> void:
	await _wait(0.3)
	AI.react_fix = _arg("old", "") == ""
	var runs = int(_arg("runs", "4"))
	var react = []
	var never = 0
	var left = 0
	var fl_dead = 0
	var walked = 0
	var fought = 0
	var mv_left = 0
	for run in range(runs):
		seed(100 + run)
		start_game({"map": "field", "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2})
		await _wait(0.5)
		var c: Vector3 = G.main._free_spot(Vector3(0, 0, 0))
		var mine = []
		for k in range(5):
			var s = spawn_soldier(0, c.x + (k - 2) * 2.0, c.z, "rifle")
			s.order = {"mode": "hold", "point": s.pos}
			mine.append(s)
		for k in range(4):
			var e = spawn_soldier(1, c.x + (k - 1.5) * 3.0, c.z + 62.0, "rifle")
			e.order = {"mode": "hold", "point": e.pos}
		await _wait(7.0)
		var fl = []
		for k in range(2):
			var e2 = spawn_soldier(1, c.x + (k - 0.5) * 5.0, c.z - 36.0, "rifle")
			e2.order = {"mode": "hold", "point": e2.pos}
			fl.append(e2)
		var t0 = -1.0
		var t = 0.0
		var got = -1.0
		while t < 30.0:
			await _wait(0.1)
			t += 0.1
			if t0 < 0.0 and fl.any(func(x): return G.sim_time - x.fired_t < 0.2):
				t0 = t
			if t0 >= 0.0 and got < 0.0 and mine.any(func(m): return m.state == "alive" and m.target in fl and G.sim_time - m.fired_t < 0.2):
				got = t - t0
		if got >= 0.0:
			react.append(got)
		else:
			never += 1
		left += mine.filter(func(m): return m.state == "alive").size()
		fl_dead += fl.filter(func(x): return x.state != "alive").size()
		# (2) the walk-past
		start_game({"map": "field", "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2})
		await _wait(0.5)
		var movers = []
		for k in range(5):
			var s2 = spawn_soldier(0, c.x - 60.0 + (k - 2) * 1.5, c.z, "rifle")
			movers.append(s2)
		for k in range(3):
			var e3 = spawn_soldier(1, c.x + (k - 1) * 3.0, c.z + 30.0, "rifle")
			e3.order = {"mode": "hold", "point": e3.pos}
		await _wait(1.0)
		var dest = Vector3(c.x + 70.0, 0, c.z)
		for s2 in movers:
			s2.order = {"mode": "move", "point": dest}
			AI.go_to(s2, dest, 4.4)
		var stopped = false
		var t2 = 0.0
		while t2 < 40.0:
			await _wait(0.2)
			t2 += 0.2
			if movers.any(func(m): return m.state == "alive" and m.task == "hold" and m.pos.x < c.x + 40.0):
				stopped = true
		if stopped:
			fought += 1
		else:
			walked += 1
		mv_left += movers.filter(func(m): return m.state == "alive").size()
	react.sort()
	print("FLANKTEST %s: shot from behind, first return fire after %s s (never in %d of %d) | squad left %.1f of 5, flankers down %.1f of 2 | on a move order across the enemy's front: stopped to fight %d, walked on %d, left %.1f of 5" % [
		"old" if not AI.react_fix else "new", str(react.map(func(x): return snappedf(x, 0.1))), never, runs, float(left) / runs, float(fl_dead) / runs, fought, walked, float(mv_left) / runs])
	get_tree().quit()

# --kitshot=DIR: close-ups of how the kit sits on a man: each side's helmet, the officer's cap, and a
# rifle in the hands of a man who's aiming
func _kit_shot(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	G.settings["time"] = "day"
	apply_time()
	G.ui.visible = false
	G.pc.force_free = true
	await _wait(0.3)
	start_game({"map": "field", "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2})
	await _wait(0.5)
	var p0: Vector3 = G.main._free_spot(Vector3(0, 0, 60))
	var men = []
	for k in range(4):
		var s = spawn_soldier(0, p0.x + k * 1.1, p0.z, "rifle")
		s.order = {"mode": "hold", "point": s.pos}
		s.body_yaw = 0.0
		s.aim_yaw = 0.0
		s.set_meta("frozen_ai", true)
		men.append(s)
	men[2].set_class("officer")
	men[3].set_class("sniper")
	await _wait(1.2)
	for s in men:
		s.pos = Vector3(s.pos.x, s.pos.y, p0.z)
		s.body_yaw = 0.0
		s.aim_yaw = 0.0
	await _wait(0.4)
	var mid: Vector3 = Vector3(p0.x + 1.65, men[1].pos.y + 1.72, p0.z)
	await _look(mid + Vector3(0.2, 0.12, 1.75), mid)
	await _snap(dir, "kit_front")
	await _look(mid + Vector3(-0.2, 0.2, -1.75), mid)
	await _snap(dir, "kit_side")
	# a man aiming: an enemy out in front of him
	var foe = spawn_soldier(1, p0.x, p0.z + 45.0, "rifle")
	foe.order = {"mode": "hold", "point": foe.pos}
	await _wait(1.6)
	var a = men[0]
	var hp: Vector3 = a.pos + Vector3(0, 1.35, 0)
	var f = Vector3(sin(a.aim_yaw), 0, cos(a.aim_yaw))
	var r = Vector3(f.z, 0, -f.x)
	await _look(hp + f * 1.3 + r * 1.3 + Vector3(0, 0.25, 0), hp + f * 0.25)
	await _snap(dir, "kit_aim_front")
	await _look(hp - r * 1.7 + f * 0.3 + Vector3(0, 0.15, 0), hp + f * 0.3)
	await _snap(dir, "kit_aim_left")
	get_tree().quit()

# --zbench: what one zombie costs. An empty field, one man a long way off for them to walk at, and the
# dead added thirty at a time; the whole physics frame is timed at each size, with the horde savings on
# and off, from high up and from close by.
func _z_bench() -> void:
	await _wait(0.5)
	for lean in [true, false]:
		for cam_h in [60.0, 4.0]:
			Soldier.horde_lean = lean
			seed(2)
			start_game({"map": "field", "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2})
			await _wait(1.0)
			var bait = spawn_soldier(0, -150.0, 0.0, "rifle")
			bait.mag = 0
			bait.reserve = 0
			bait.grenades = 0
			bait.hp = 100000.0
			bait.order = {"mode": "hold", "point": bait.pos}
			await _look(Vector3(60, cam_h, 0), Vector3(40, 1, 0))
			var line = "ZBENCH savings %s, camera %s:" % ["on" if lean else "off", "high" if cam_h > 10.0 else "low among them"]
			var base = 0.0
			var zn = 0
			for n in [0, 30, 60]:
				while zn < n:
					var z = spawn_soldier(1, 30.0 + (zn % 10) * 2.2, -12.0 + (zn / 10) * 2.2, "rifle")
					Modes.make_zombie(z)
					zn += 1
				await _wait(4.0)
				var samples = []
				for f in range(300):
					await get_tree().physics_frame
					samples.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
				samples.sort()
				var ms: float = samples[samples.size() / 2]
				if n == 0:
					base = ms
				var frozen = 0
				for sl in G.soldiers:
					if sl.zombie and sl.lod_frozen:
						frozen += 1
				line += "  %d: %.1f ms%s" % [n, ms, "" if n == 0 else " (%.2f each, %d posed)" % [(ms - base) / n, frozen]]
			print(line)
			end_game(0)
			await _wait(1.0)
	get_tree().quit()

# --zedtest: a zombie battle left to run. What the men do when the dead get close (shoves, how many
# are wedged with nowhere to go), what they throw, how many bodies are kept lying about, how many of the
# dead cast shadows, and what a tick and a frame cost.
func _zed_test() -> void:
	await _wait(0.5)
	seed(int(_arg("seed", "5")))
	Soldier.horde_lean = _arg("old", "") == ""
	start_game({"map": _arg("map", "town"), "mode": "horde", "size": int(_arg("size", "12")), "limit": 999, "reinforce": true, "armor": "none", "teams": 2})
	G.pc.free_pos = G.world.capture + Vector3(-20, 45, 0)
	await _look(G.world.capture + Vector3(-20, 45, 0), G.world.capture)
	if _arg("low", "") != "":
		# (down among the defenders, as when you're playing one of them)
		await _look(G.world.capture + Vector3(-6, 3.0, 0), G.world.capture + Vector3(10, 1.5, 0))
	var secs = float(_arg("secs", "180"))
	var t = 0.0
	var worst_ms = 0.0
	var corner_s = 0.0
	var close_s = 0.0
	var busy_ms = 0.0
	var busy_z = 0.0
	var busy_n = 0
	while t < secs:
		await _wait(1.0)
		t += 1.0
		worst_ms = maxf(worst_ms, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		var zup = 0
		for s in G.soldiers:
			if s.zombie and s.state != "dead":
				zup += 1
		if zup >= 10 and t > 5.0:
			busy_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			busy_z += zup
			busy_n += 1
		for s in G.soldiers:
			if s.state == "alive" and not s.zombie:
				if G.sim_time - float(s.get_meta("cornered_t", -99.0)) < 1.0:
					corner_s += 1.0
				var zn = s.get_meta("znear") if s.has_meta("znear") else null
				if zn != null and is_instance_valid(zn) and zn.state != "dead" and G.dist2d(zn.pos, s.pos) < 3.0:
					close_s += 1.0
		if int(t) % 30 == 0:
			var men = 0
			var zs = 0
			var bodies = 0
			var zshadow = 0
			for s in G.soldiers:
				if s.state == "dead":
					bodies += 1
				elif s.zombie:
					zs += 1
					for g in s.parts[1].find_children("*", "GeometryInstance3D", true, false):
						if g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
							zshadow += 1
							break
				else:
					men += 1
			print("ZEDTEST %3ds: men %d, the dead up %d (casting shadows %d), bodies lying %d | shoves %d, thrown %s | tick %.1f ms (worst %.1f)%s" % [int(t), men, zs, zshadow, bodies, Combat.shove_n, str(Combat.thrown),
				Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, worst_ms,
				"" if DisplayServer.get_name() == "headless" else " | draws %d, fps %d" % [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), Engine.get_frames_per_second()]])
	print("ZEDTEST with ten or more of the dead up (%d samples): mean tick %.1f ms with %.0f of them on average" % [busy_n, busy_ms / maxf(busy_n, 1), busy_z / maxf(busy_n, 1)])
	# the things that give a reason to move
	var pts0 = Support.points[0]
	var d_before = Modes.drops.size()
	Modes._new_drop()
	var dp: Vector3 = Modes.drops[Modes.drops.size() - 1]["p"]
	var runner = null
	for s in G.soldiers:
		if s.team == 0 and s.state == "alive":
			runner = s
			break
	var line = "wave %d from the %s | drops waiting before %d | new drop %.0f m from the middle" % [Modes.horde_wave, Modes.SIDE_NAMES[maxi(Modes.horde_side, 0)], d_before, G.dist2d(dp, G.world.capture)]
	if runner != null:
		runner.pos = dp + Vector3(1.0, 0, 0)
		runner.reserve = 0
		await _wait(0.5)
		line += " | fetched: points %d -> %d, his reserve %d, drops left %d" % [pts0, Support.points[0], runner.reserve, Modes.drops.size()]
	print("ZEDTEST ", line)
	print("ZEDTEST keep: building %d at %.0f m from the middle | %s | spade blows so far %d" % [Modes.keep(), G.dist2d(Modes.keep_pos(), G.world.capture), Modes.fall_back(), Combat.spade_n])
	await _wait(12.0)
	var inside = 0
	var men_n = 0
	for s in G.soldiers:
		if s.team == 0 and s.state == "alive":
			men_n += 1
			if Doors.building_at(s.pos) == Modes.keep():
				inside += 1
	var dbg = []
	for s in G.soldiers:
		if s.team == 0 and s.state == "alive":
			dbg.append("%.0fm %s %s mv=%s" % [G.dist2d(s.pos, Modes.keep_pos()), str(s.task), "ord" if s.order != null else "-", str(s.move_target != null)])
	print("ZEDTEST 12 s after the order: %d of %d men inside the keep | %s" % [inside, men_n, str(dbg)])
	print("ZEDTEST over %ds: man-seconds with a zombie within 3 m %d, of which wedged with no way out %d" % [int(secs), int(close_s), int(corner_s)])
	get_tree().quit()

# --casshot=DIR: casualties as the commander sees them. Two of your men are put down wounded in a battle
# you're commanding, and a picture is taken from above.
func _cas_shot(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	await _wait(0.5)
	start_game({"map": "field", "mode": "commander", "size": 8, "limit": 999, "reinforce": false, "armor": "none", "teams": 2})
	await _wait(3.0)
	var down = []
	for s in G.soldiers:
		if s.team == 0 and s.state == "alive" and s.cls != "medic" and down.size() < 2:
			s.hp = 30.0
			s.fall(0.5)
			s.make_wounded()
			down.append(s)
	await _wait(4.0)
	var mid: Vector3 = (down[0].pos + down[1].pos) * 0.5 if down.size() == 2 else G.world.rally_point(0)
	await _look(mid + Vector3(-14, 24, 0), mid)
	await _wait(1.0)
	var helped = 0
	for s in down:
		if s.medic != null and is_instance_valid(s.medic):
			helped += 1
	print("CASSHOT %d men down (%s), %d with someone coming, command view %s" % [down.size(), str(down.map(func(x): return x.state)), helped, G.ui.cmdhud.active() if "cmdhud" in G.ui else "?"])
	await _snap(dir, "casualties")
	get_tree().quit()

# --finishshot=DIR: the slow-motion finish. A small battle is ended just after a man falls; a picture is
# taken part way through the finish and another once the result is up, with the state at each point.
func _finish_shot(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	await _wait(0.5)
	start_game({"map": "town", "mode": "deathmatch", "size": 8, "limit": 999, "reinforce": false, "armor": "none", "teams": 2})
	await _wait(6.0)
	var victim = null
	for s in G.soldiers:
		if s.team == 1 and s.state == "alive":
			victim = s
			break
	victim.hp = 0.0
	Combat.kill(victim, null, false)
	await _wait(0.2)
	end_game(0)
	print("FINISHSHOT started: left %.1f s, time scale %.2f, win panel up %s, focus %.0f m from the man who fell" % [finish_left, Engine.time_scale, G.ui.win.visible, G.dist2d(finish_p, victim.pos)])
	for k in range(3):
		await get_tree().process_frame
	await _snap(dir, "finish_slowmo")
	var guard = 0
	while finish_left > 0.0 and guard < 600:
		guard += 1
		await get_tree().process_frame
	await get_tree().process_frame
	print("FINISHSHOT ended after %d frames: time scale %.2f, win panel up %s, bars shown %s" % [guard, Engine.time_scale, G.ui.win.visible, G.ui.fin_bars[0].visible])
	await _snap(dir, "finish_result")
	get_tree().quit()

# --savetest: a battle saved part way and loaded again: what was there before against what comes back.
func _save_test() -> void:
	await _wait(0.5)
	seed(9)
	for cfg in [["town", "capture"], ["town", "horde"]]:
		start_game({"map": cfg[0], "mode": cfg[1], "size": 10, "limit": 100, "reinforce": true, "armor": "light", "teams": 2})
		await _wait(45.0)
		# knock a few pieces of the map down so there's something to remember
		var knocked = 0
		for c in G.world.static_cols:
			if c.alive and c.dest and knocked < 5:
				G.world.ruin_col(c)
				knocked += 1
		var count = func() -> Array:
			var men = [0, 0]
			var hp = 0.0
			var z = 0
			for s in G.soldiers:
				if s.state != "dead" and s.vehicle == null:
					men[mini(s.team, 1)] += 1
					hp += s.hp
					if s.zombie:
						z += 1
			return [men[0], men[1], int(hp), z, G.vehicles.filter(func(v): return is_instance_valid(v) and not v.dead).size(),
				G.world.static_cols.filter(func(c): return not c.alive and c.dest).size(), str(G.score), str(Support.points), Build.sites.filter(func(st): return not st["dead"]).size(), Modes.horde_wave]
		var before: Array = count.call()
		var named = ""
		for s in G.soldiers:
			if s.team == 0 and s.state == "alive":
				named = "%s/%s/%d rounds" % [s.sname, s.wid, s.reserve]
				break
		var msg = Scenario.save_battle()
		var saved_names = {}
		for s in G.soldiers:
			if s.state != "dead" and s.vehicle == null:
				saved_names[s.sname] = true
		end_game(1)
		await _wait(2.0)
		var msg2 = Scenario.load_battle()
		await _wait(1.0)
		var after: Array = count.call()
		var found = ""
		for s in G.soldiers:
			if s.team == 0 and named.begins_with(s.sname + "/"):
				found = "%s/%s/%d rounds" % [s.sname, s.wid, s.reserve]
				break
		print("SAVETEST %s/%s: %s | %s" % [cfg[0], cfg[1], msg, msg2])
		var extra = []
		for s in G.soldiers:
			if s.state != "dead" and s.vehicle == null and not saved_names.has(s.sname):
				var nv = 999.0
				var nk = ""
				for v in G.vehicles:
					if is_instance_valid(v) and G.dist2d(v.pos, s.pos) < nv:
						nv = G.dist2d(v.pos, s.pos)
						nk = v.kind + ("(fleet)" if v.has_meta("fleet") else "")
				extra.append("%s t%d %s %s near %s %.0fm metas %s" % [s.sname, s.team, s.cls, s.state, nk, nv, str(s.get_meta_list())])
		print("SAVETEST   on foot now but not saved: %s" % str(extra))
		print("SAVETEST   before: men on foot %d v %d (hp %d, zombies %d), vehicles %d, ruins %d, score %s, supply %s, structures %d, wave %d" % before)
		print("SAVETEST   after:  men on foot %d v %d (hp %d, zombies %d), vehicles %d, ruins %d, score %s, supply %s, structures %d, wave %d" % after)
		print("SAVETEST   one man: %s -> %s | battle running again: %s (mode %s)" % [named, found, G.started and not G.over, G.mode])
		end_game(1)
		await _wait(1.0)
	get_tree().quit()

# --walltest: the Ministry's walls. Grenades against an inside wall and against the outside one: what
# comes down, and whether the outside still stands.
func _wall_test() -> void:
	await _wait(0.5)
	start_game({"map": "office", "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2})
	await _wait(1.0)
	var W = G.world
	var inner = null
	var outer = null
	var n_in = 0
	var n_out = 0
	for c in W.static_cols:
		if not c.alive or c.hi.y - c.lo.y < 2.0 or c.lo.y > 0.5:
			continue
		var thin = minf(c.hi.x - c.lo.x, c.hi.z - c.lo.z)
		if thin > 0.5:
			continue
		if c.dest:
			n_in += 1
			if inner == null and absf((c.lo.x + c.hi.x) * 0.5) < 30.0:
				inner = c
		else:
			n_out += 1
			if outer == null:
				outer = c
	print("WALLTEST ground-floor wall pieces: %d can be destroyed (inside), %d cannot (outside and stairwells)" % [n_in, n_out])
	for pr in [["inside", inner], ["outside", outer]]:
		var c = pr[1]
		if c == null:
			print("WALLTEST no %s wall found" % pr[0])
			continue
		var p = Vector3((c.lo.x + c.hi.x) * 0.5, 1.0, (c.lo.z + c.hi.z) * 0.5)
		var alive0 = W.static_cols.filter(func(x): return x.alive).size()
		var hits = 0
		while c.alive and hits < 6:
			hits += 1
			Combat.explode(p + Vector3(0.4, 0, 0.4), null, 1.0)
			await _wait(0.4)
		print("WALLTEST %s wall at (%.0f, %.0f), %.0f hp: %s after %d grenade-sized blasts; pieces down in all %d" % [pr[0], p.x, p.z, c.hp if "hp" in c else -1.0, "DOWN" if not c.alive else "still standing", hits, alive0 - W.static_cols.filter(func(x): return x.alive).size()])
	get_tree().quit()

# --restest: a campaign battle with a second company in reserve and the company commander on the field:
# the reserve comes up, what it loses is taken off it, the commander can fall, and the turn report is made.
func _res_test() -> void:
	await _wait(0.5)
	seed(4)
	var out = []
	Campaign.new_campaign()
	var D = Campaign.data
	var a0 = Campaign.army_at(0, 0)
	var a1 = Campaign.army_at(1, 0)
	Campaign.move(a0, 1)
	a1["moved"] = false
	a0["moved"] = false
	out.append("commanders: %s | %s" % [Campaign.co_text(a0).substr(0, 70), Campaign.co_text(a1).substr(0, 70)])
	var res_before = a0["men"].size() if Campaign.army_at(1, 0) == a1 else a1["men"].size()
	var top = Campaign.army_at(1, 0)
	var other = a0 if top == a1 else a1
	res_before = other["men"].size()
	Campaign.move(top, 3)
	out.append("odds with a company in reserve: %.2f (%s)" % [Campaign.odds()[0], Campaign.odds()[1]])
	Campaign.start_battle("command")
	await _wait(4.0)
	out.append("battle on %s: reserves planned %d, commander on the field: %s" % [G.map_id, Campaign.reserves.size(), str(G.soldiers.filter(func(x): return x.has_meta("co")).map(func(x): return x.sname))])
	var n_before = G.soldiers.filter(func(x): return x.team == 0 and x.state != "dead").size()
	for r in Campaign.reserves:
		r["at"] = G.sim_time + 1.0
	await _wait(3.0)
	var rs = G.soldiers.filter(func(x): return x.has_meta("reserve") and x.team == 0)
	out.append("reserve arrived: %d men (ours on the field %d -> %d), first is '%s' a %s" % [rs.size(), n_before, G.soldiers.filter(func(x): return x.team == 0 and x.state != "dead").size(), rs[0].sname if not rs.is_empty() else "-", rs[0].cls if not rs.is_empty() else "-"])
	# two of the reserve and the commander are killed
	for k in range(mini(2, rs.size())):
		rs[k].hp = 0.0
		Combat.kill(rs[k], null, false)
	for cs in G.soldiers:
		if cs.has_meta("co"):
			cs.hp = 0.0
			Combat.kill(cs, null, false)
	await _wait(1.0)
	end_game(0)
	await _wait(3.5)
	out.append("after the battle: reserve company %d -> %d men | top company's commander now: %s" % [res_before, other["men"].size(), Campaign.co_text(top).substr(0, 80)])
	for l in D["log"].slice(0, 8):
		out.append("   log: " + str(l).substr(0, 110))
	var lines = Campaign.end_turn()
	var guard = 0
	while Campaign.pending_battle() != null and guard < 3:
		guard += 1
		Campaign.auto_resolve()
	var rep = D.get("report")
	if rep != null:
		out.append("turn report for turn %d: Bravo's moves %d, fell %d (%s), gained %s, lost %s, war chest %d -> %d, dispatches %d" % [int(rep["turn"]), rep["bravo"].size(), int(rep["fallen"]), ", ".join(rep["names"]).substr(0, 60), str(rep["gained"]), str(rep["lost"]), int(rep["funds"][0]), int(rep["funds"][1]), rep["other"].size()])
	else:
		out.append("turn report: none made")
	for l in out:
		print("RESTEST ", l)
	if _arg("pic", "") != "":
		G.ui.visible = true
		G.ui._show_campaign()
		await _wait(0.5)
		await _snap(_arg("pic", ""), "camp_report")
		if rep != null:
			rep["seen"] = true
		Campaign.selected = Campaign.data["armies"].filter(func(x): return x["team"] == 0)[0]["id"]
		G.ui._show_campaign()
		await _wait(0.5)
		await _snap(_arg("pic", ""), "camp_commander")
	get_tree().quit()

# --stacktest: several companies in one region of the campaign. A region held by two has to be won
# twice; one of ours beaten where another still stands doesn't lose the ground; and there's a limit.
func _stack_test() -> void:
	await _wait(0.3)
	seed(3)
	var out = []
	Campaign.new_campaign()
	var D = Campaign.data
	var a0 = Campaign.army_at(0, 0)
	var a1 = Campaign.army_at(1, 0)
	var a2 = Campaign.army_at(2, 0)
	var b3 = Campaign.army_at(3, 1)
	var b7 = Campaign.army_at(7, 1)
	var b4 = Campaign.army_at(4, 1)
	# two of Bravo's in the Valley Road region
	b7["region"] = 3
	out.append("Bravo has %d companies at %s (%s %d, %s %d); strongest first: %s" % [Campaign.armies_at(3, 1).size(), Campaign.REGIONS[3]["name"], b3["name"], b3["str"], b7["name"], b7["str"], Campaign.army_at(3, 1)["name"]])
	var res = Campaign.move(a1, 3)
	var b = Campaign.pending_battle()
	out.append("our %s attacks: %s, against %s" % [a1["name"], res, Campaign.army(b["foe"])["name"] if b != null else "-"])
	var lines = Campaign._outcome(b, 0, a1, Campaign.army(b["foe"]))
	out.append("  won: owner of the region %d (1 = still Bravo's), our company back at region %d, Bravo companies left there %d | %s" % [D["owner"][3], a1["region"], Campaign.armies_at(3, 1).size(), str(lines[0])])
	Campaign.move(a2, 3)
	b = Campaign.pending_battle()
	lines = Campaign._outcome(b, 0, a2, Campaign.army(b["foe"]))
	out.append("  second attack won: owner %d (0 = ours), our company now at region %d, Bravo companies left there %d | %s" % [D["owner"][3], a2["region"], Campaign.armies_at(3, 1).size(), str(lines[0])])
	# two of ours at region 1, attacked and the first of them beaten
	a1["moved"] = false
	a0["moved"] = false
	out.append("our %s can join %s at region 1: %s" % [a0["name"], a1["name"], Campaign.can_move(a0, 1)])
	Campaign.move(a0, 1)
	var top = Campaign.army_at(1, 0)
	D["battle"] = {"region": 1, "attacker": 1, "army": top["id"], "foe": b4["id"], "from": 4, "stage": 1, "obj": ""}
	lines = Campaign._outcome(D["battle"], 1, top, b4)
	out.append("Bravo attacks region 1 (two of ours) and beats %s: owner %d (0 = still ours), ours left there %d, the beaten one now at region %d, Bravo's company back at region %d | %s" % [top["name"], D["owner"][1], Campaign.armies_at(1, 0).size(), top["region"] if top in D["armies"] else -1, b4["region"], str(lines[0])])
	# the limit
	for k in range(3):
		if Campaign.armies_at(0, 0).size() < Campaign.STACK:
			Campaign._add_army(0, 0, 6)
	var extra = Campaign._add_army(0, 2, 6)
	extra["moved"] = false
	D["funds"][0] = 99
	out.append("HQ with %d companies: a fourth can move in %s; raising another: '%s'" % [Campaign.armies_at(0, 0).size(), Campaign.can_move(extra, 0), Campaign.can_raise(0)])
	# changing mode: the row of tools belongs to the new battle at once, and a second battle in the
	# Ministry doesn't leave a second set of floor buttons
	var seen = []
	for md in [["town", "commander"], ["town", "sandbox"], ["town", "horde"], ["office", "capture"], ["office", "capture"]]:
		start_game({"map": md[0], "mode": md[1], "size": 6, "limit": 999, "reinforce": false, "armor": "none", "teams": 2})
		await _wait(1.0)
		var names = []
		for c in G.ui.dock_tabs.get_children():
			if not c.is_queued_for_deletion() and c is Button:
				names.append(c.text)
		seen.append("%s/%s: tab '%s', tabs %s, floor buttons %d" % [md[0], md[1], G.ui.tab, str(names), G.ui.floor_view.panel.get_child_count() - 1])
		end_game(0)
		await _wait(0.5)
	for l in seen:
		out.append(l)
	for l in out:
		print("STACKTEST ", l)
	get_tree().quit()

# --audtest: how loud the game really is. A small battle watched from where the camera starts, with
# the level on the master bus read every frame: the loudest moment and how much of the time anything
# at all is coming out.
func _aud_test() -> void:
	await _wait(0.5)
	var secs = float(_arg("secs", "30"))
	if _arg("menu", "") == "1":
		# the title screen: is its tune playing, and how loud
		var m0 = Time.get_ticks_msec()
		var mpk = -200.0
		while Time.get_ticks_msec() - m0 < secs * 1000.0:
			await get_tree().process_frame
			mpk = maxf(mpk, maxf(AudioServer.get_bus_peak_volume_left_db(0, 0), AudioServer.get_bus_peak_volume_right_db(0, 0)))
		print("AUDTEST voices built: shouts %d grunts %d pains %d screams %d, reload %s pin %s door %s steps %s/%s stings %s/%s horde loop %s" % [G.audio.s_shouts.size(), G.audio.s_grunts.size(), G.audio.s_pains.size(), G.audio.s_screams.size(),
			G.audio.s_reload != null, G.audio.s_pin != null, G.audio.s_door != null, G.audio.s_step_road != null, G.audio.s_step_floor != null, G.audio.s_win != null, G.audio.s_lose != null, G.audio.s_horde != null])
		for pr in [["shout", G.audio.s_shouts[0]], ["shout2", G.audio.s_shouts[3]], ["grunt", G.audio.s_grunts[0]], ["pain", G.audio.s_pains[0]], ["scream", G.audio.s_screams[1]], ["reload", G.audio.s_reload], ["pin", G.audio.s_pin], ["door", G.audio.s_door], ["step road", G.audio.s_step_road], ["step floor", G.audio.s_step_floor], ["win", G.audio.s_win], ["lose", G.audio.s_lose], ["horde", G.audio.s_horde], ["rifle", G.audio.s_guns["rifle"]]]:
			var d: PackedByteArray = pr[1].data
			var pkv = 0.0
			var acc2 = 0.0
			var clip = 0
			var nn = d.size() / 2
			for i in range(nn):
				var x = d.decode_s16(i * 2) / 32000.0
				pkv = maxf(pkv, absf(x))
				acc2 += x * x
				if absf(x) > 0.98:
					clip += 1
			print("AUDTEST   %-10s %.2f s  peak %.2f  rms %.3f  clipped %.1f%%" % [pr[0], float(nn) / pr[1].mix_rate, pkv, sqrt(acc2 / maxf(nn, 1)), 100.0 * clip / maxf(nn, 1)])
		print("AUDTEST title screen: tune built %s, playing %s, fade %.2f, master peak %.1f dB, started %s attract %s" % [G.audio.menu_player != null, G.audio.menu_player != null and G.audio.menu_player.playing, G.audio.menu_k, mpk, G.started, G.attract])
		get_tree().quit()
		return
	G.pc.force_free = true
	start_game({"map": _arg("map", "town"), "mode": _arg("mode", "sandbox"), "size": int(_arg("size", "1")), "limit": 999, "reinforce": false, "armor": "none", "teams": 2})
	if _arg("high", "") == "1":
		# (looking down on the middle of the town from 70 m up, as when commanding)
		await _look(G.world.capture + Vector3(-25, 70, 0), G.world.capture)
	var t0 = G.sim_time
	var pk = -200.0
	var n = 0
	var loud = 0
	var acc = 0.0
	var wpk = -200.0
	var wb = AudioServer.get_bus_index("World")
	while G.sim_time - t0 < secs:
		await get_tree().process_frame
		var l = maxf(AudioServer.get_bus_peak_volume_left_db(0, 0), AudioServer.get_bus_peak_volume_right_db(0, 0))
		pk = maxf(pk, l)
		if wb >= 0:
			wpk = maxf(wpk, AudioServer.get_bus_peak_volume_left_db(wb, 0))
		n += 1
		acc += db_to_linear(l)
		if l > -30.0:
			loud += 1
	print("AUDTEST driver %s, playback type %s, frames %d: master peak %.1f dB, mean level %.4f (%.1f dB), frames above -30 dB %d%%, world bus peak %.1f dB, music setting %.2f, volume %.2f" % [
		AudioServer.get_driver_name(), str(ProjectSettings.get_setting("audio/general/default_playback_type", "?")), n, pk, acc / maxf(n, 1), linear_to_db(maxf(acc / maxf(n, 1), 0.00001)), int(100.0 * loud / maxf(n, 1)), wpk, G.settings["music"], G.settings["volume"]])
	get_tree().quit()

# --meleeshot=DIR: pictures and numbers for close-quarters work: a man throwing (grenade in his hand),
# a man with a wall in front of him refusing to throw, a shove at a zombie, the militia's vehicles next
# to the army's, and a supply lorry's driver shut in his cab
func _melee_shot(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	G.settings["time"] = "day"
	apply_time()
	G.ui.visible = false
	G.pc.force_free = true
	await _wait(0.3)
	G.factions = ["army", "militia"]
	start_game({"map": "field", "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2})
	await _wait(0.5)
	var out = []
	var p0: Vector3 = G.main._free_spot(Vector3(0, 0, 60))
	# 1. a throw
	var a = spawn_soldier(0, p0.x, p0.z, "rifle")
	a.order = {"mode": "hold", "point": a.pos}
	a.set_meta("frozen_ai", true)
	a.body_yaw = 0.0
	a.aim_yaw = 0.0
	a.grenades = 3
	a.smokes = 2
	await _wait(1.2)
	var g0 = a.grenades
	Combat.throw_grenade(a, a.pos + Vector3(0, 0, 22), "frag")
	out.append("throw started: pending %s, throw_t %.2f" % [a.has_meta("throw_pending"), a.throw_t])
	var hp: Vector3 = a.pos + Vector3(0, 1.4, 0)
	await _wait(0.1)
	var tf = Vector3(sin(a.body_yaw), 0, cos(a.body_yaw))
	var tr = Vector3(tf.z, 0, -tf.x)
	await _look(hp + tf * 1.9 + tr * 1.5 + Vector3(0, 0.3, 0), hp)
	# (the picture machine runs at a frame a second, so each stage of the throw is set by hand)
	for k in range(8):
		a.throw_t = 1.2
		await get_tree().physics_frame
	await _snap(dir, "throw_1_pin")
	for k in range(8):          # (held there a few frames so the arm has time to get to it)
		a.throw_t = 0.78
		await get_tree().physics_frame
	out.append("  grenade in hand shown: %s (throw_t %.2f)" % [a.nade_mesh != null and a.nade_mesh.visible, a.throw_t])
	await _snap(dir, "throw_2_back")
	await _wait(0.25)
	await _snap(dir, "throw_3_over")
	await _wait(0.6)
	out.append("  after: grenades %d -> %d, in hand shown %s" % [g0, a.grenades, a.nade_mesh != null and a.nade_mesh.visible])
	await _wait(3.5)
	# 2. a wall right in front of him: no throw
	G.world.add_box(a.pos.x, 0.0, a.pos.z + 1.0, 3.0, 2.6, 0.3, Color(0.5, 0.5, 0.48), {})
	await _wait(0.3)
	a.nade_cd = 0.0
	var g1 = a.grenades
	Combat.throw_grenade(a, a.pos + Vector3(0, 0, 22), "frag")
	await _wait(1.6)
	out.append("wall 1 m in front: throw started %s, grenades %d -> %d" % [a.throw_t > 0.0 or a.grenades != g1, g1, a.grenades])
	# 3. a shove at a zombie
	var b = spawn_soldier(0, p0.x + 8.0, p0.z, "rifle")
	b.set_meta("frozen_ai", true)
	b.body_yaw = 0.0
	b.aim_yaw = 0.0
	for m in [a, b]:          # (nobody shoots it: the shove alone is being measured)
		m.mag = 0
		m.reserve = 0
		m.grenades = 0
	var z = spawn_soldier(1, p0.x + 8.0, p0.z + 1.2, "rifle")
	Modes.make_zombie(z)
	z.set_meta("frozen_ai", true)
	await _wait(1.0)
	z.pos = b.pos + Vector3(0, 0, 1.15)
	b.body_yaw = 0.0
	b.aim_yaw = 0.0
	z.body_yaw = PI
	await get_tree().physics_frame
	var zh = z.hp
	var zp: Vector3 = z.pos
	Combat.shove(b, z)
	var zh1 = z.hp
	var bh: Vector3 = b.pos + Vector3(0, 1.25, 0.55)
	await _look(bh + Vector3(2.6, 0.3, 0.0), bh)
	b.throw_t = 0.22
	await get_tree().process_frame
	await _snap(dir, "shove")
	var far = 0.0
	for k in range(40):
		await get_tree().physics_frame
		far = maxf(far, G.dist2d(z.pos, zp))
	out.append("shove: zombie hp %.0f -> %.0f from the one blow, sent back up to %.1f m in the next 40 ticks (%s)" % [zh, zh1, far, z.state])
	# 4. the militia's vehicles beside the army's
	var vp: Vector3 = G.main._free_spot(Vector3(-40, 0, 20))
	var kinds = [["tank", 0], ["oldtank", 1], ["armoredcar", 0], ["gunbus", 1]]
	for i in range(kinds.size()):
		spawn_vehicle(kinds[i][0], kinds[i][1], Vector3(vp.x + i * 7.5, 0, vp.z), PI * 0.75, false)
	await _wait(1.5)
	var mid = Vector3(vp.x + 11.0, 1.2, vp.z)
	await _look(mid + Vector3(-3.0, 8.5, -17.0), mid)
	await _snap(dir, "militia_vehicles")
	await _look(Vector3(vp.x + 7.5, 1.5, vp.z) + Vector3(-7.0, 3.2, -8.0), Vector3(vp.x + 5.0, 1.4, vp.z))
	await _snap(dir, "militia_tank")
	# 5. a fleet lorry: its driver
	var lv = spawn_vehicle("supplytruck", 0, G.main._free_spot(Vector3(0, 0, 30)), 0.0, true)
	await _wait(1.5)
	Logistics.fleet[0].append(lv)
	lv.set_meta("fleet", true)
	# the lorry on a run whose stop has the enemy at it: it turns round
	var drop: Vector3 = lv.pos + Vector3(-70, 0, 0)
	lv.mission = {"type": "supply", "fleet": true, "drop": drop, "exit": lv.pos + Vector3(70, 0, 0), "stage": 0, "wait": 0.0, "site": null, "pts": 0}
	Logistics._turn_back(0, lv)
	var st_clear = lv.mission["stage"]
	var raider = spawn_soldier(1, drop.x - 12.0, drop.z + 5.0, "rifle")
	raider.order = {"mode": "hold", "point": raider.pos}
	await _wait(0.3)
	Logistics._turn_back(0, lv)
	out.append("lorry on a run: stage %d with its stop clear, stage %d with an enemy 13 m from the stop (2 = heading home); a stop counts as under attack: %s" % [st_clear, lv.mission["stage"] if lv.mission != null else -1, Logistics._hot(0, drop, 60.0)])
	raider.hp = 0.0
	Combat.kill(raider, null, false)
	lv.mission = null
	var d = lv.driver()
	if d != null:
		d._hide_inside()
		var dh = d.hp
		# rifle and machine-gun fire into the cab from the side, then a shell close by
		var foe = spawn_soldier(1, lv.pos.x + 14.0, lv.pos.z + 1.5, "lmg")
		foe.order = {"mode": "hold", "point": foe.pos}
		for k in range(40):
			var from: Vector3 = foe.pos + Vector3(0, 1.4, 0)
			var to: Vector3 = d.parts[1].global_position + Vector3(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2), randf_range(-0.2, 0.2))
			Combat.fire_weapon(foe, from, (to - from).normalized(), 0.0)
		await _wait(2.0)
		out.append("lorry: driver hidden %s, layer %d, hp %.0f -> %.0f after 40 machine-gun rounds aimed at his seat; lorry hp %.0f/%.0f, wrecked %s" % [d.hidden_in_vehicle, d.parts[0].collision_layer, dh, d.hp, lv.hp, lv.spec["hp"], lv.dead])
	else:
		out.append("lorry: no driver spawned")
	for l in out:
		print("MELEESHOT ", l)
	get_tree().quit()

# --warfight: the three ways into a campaign battle really start one, and each ends back on the map:
# an attack fought as a soldier, a defence commanded from above (with free defences), the Ministry stage
func _war_fight() -> void:
	await _wait(0.5)
	seed(6)
	var out = []
	Campaign.new_campaign()
	var a1 = Campaign.army_at(1, 0)
	Campaign.move(a1, 3)
	Campaign.start_battle("soldier")
	await _wait(8.0)
	out.append("attack as a soldier: map %s mode %s, in a man %s (%s), objective '%s'" % [G.map_id, G.mode, G.player != null, G.player.sname if G.player != null else "-", Campaign.objective_text().substr(0, 30)])
	end_game(0)
	await _wait(3.5)
	out.append("  after: Valley Road owner %d, battle pending %s, headline %s" % [Campaign.data["owner"][3], Campaign.pending_battle() != null, Campaign.data["headline"]["head"]])
	# a defence
	var mine = Campaign.army_at(3, 0)
	var foe = Campaign.army_at(6, 1) if Campaign.army_at(6, 1) != null else Campaign.data["armies"].filter(func(x): return x["team"] == 1)[0]
	if mine != null:
		Campaign.data["battle"] = {"region": 3, "attacker": 1, "army": mine["id"], "foe": foe["id"], "from": foe["region"], "stage": 1, "obj": ""}
		Campaign._pick_objective()
		Campaign.start_battle("command")
		await _wait(3.0)
		var free0 = Campaign.free_left()
		var took = Campaign.take_free("sandbags")
		out.append("defence from above: mode %s, free defences [%s], took one %s, now [%s], player in a man %s" % [G.mode, free0, took, Campaign.free_left(), G.player != null])
		end_game(0)
		await _wait(3.5)
		out.append("  after: held owner %d, turn %d, plan %d" % [Campaign.data["owner"][3], Campaign.data["turn"], Campaign.data["plan"].size()])
	# the Ministry
	var us = Campaign.data["armies"].filter(func(x): return x["team"] == 0)[0]
	var guard = Campaign.army_at(11, 1)
	Campaign.data["battle"] = {"region": 11, "attacker": 0, "army": us["id"], "foe": guard["id"], "from": us["region"], "stage": 1, "obj": "swift"}
	Campaign.auto_resolve()
	var b2 = Campaign.pending_battle()
	if b2 == null or int(b2.get("stage", 1)) != 2:
		# (lost the city on paper: set the second stage up by hand so the Ministry start is still tested)
		Campaign.data["battle"] = {"region": 11, "attacker": 0, "army": us["id"], "foe": guard["id"], "from": us["region"], "stage": 2, "obj": "light"}
	Campaign.start_battle("command")
	await _wait(6.0)
	out.append("the Ministry: map %s mode %s, men %d v %d, storeys %s" % [G.map_id, G.mode, G.alive_count(0), G.alive_count(1), Levels.on])
	end_game(0)
	await _wait(3.5)
	out.append("  after: Capital owner %d, campaign over %d, headline %s" % [Campaign.data["owner"][11], Campaign.over(), Campaign.data["headline"]["head"]])
	for l in out:
		print("WARFIGHT ", l)
	get_tree().quit()

# --warshot=DIR: pictures of the campaign screen (a turn with a question and Bravo's plan, a battle waiting
# to be fought, the roll of the fallen)
func _war_shot(dir: String) -> void:
	await _wait(0.5)
	seed(4)
	G.ui.visible = true
	G.ui.title.visible = false
	Campaign.new_campaign(_arg("short", "") != "")
	var a1 = Campaign.army_at(1, 0)
	Campaign.data["choice"] = {"kind": "volunteers", "army": a1["id"], "default": 1, "text": "Lads from Old Town want to join up.",
		"opts": ["Take them into the %s (+5 riflemen)" % a1["name"], "Send them to the workshops (+6 to the war chest)"]}
	Campaign.selected = a1["id"]
	G.ui._show_campaign()
	await _wait(0.6)
	await _snap(dir, "camp_turn")
	Campaign.choose(0)
	Campaign.selected = -1
	Campaign.move(a1, 3)
	G.ui._show_campaign()
	await _wait(0.6)
	await _snap(dir, "camp_battle")
	Campaign.auto_resolve()
	Campaign.end_turn()
	while Campaign.pending_battle() != null:
		Campaign.auto_resolve()
	G.ui.camp_fallen = true
	G.ui._show_campaign()
	await _wait(0.6)
	await _snap(dir, "camp_fallen")
	get_tree().quit()

# --warptest --turns= --short=1 --seed=: plays the campaign map on paper (every battle auto-resolved, moves
# and answers picked at random) and checks nothing is left in a state it shouldn't be
func _war_test() -> void:
	await _wait(0.3)
	seed(int(_arg("seed", "3")))
	var D
	var bad = []
	var battles = 0
	var choices = 0
	var plans = 0
	var called_off = 0
	var finale = 0
	var turns = int(_arg("turns", "40"))
	var stack_max = [0, 0]
	var stacked = [0, 0]
	var held_on = 0
	Campaign.new_campaign(_arg("short", "") != "")
	for turn in range(turns):
		D = Campaign.data
		if Campaign.over() >= 0:
			break
		plans += D["plan"].size()
		if D.get("choice") != null:
			choices += 1
			Campaign.choose(randi() % 2)
		for a in D["armies"].duplicate():
			if a["team"] != 0 or a["moved"] or not (a in D["armies"]):
				continue
			var opts = Campaign.neighbours(a["region"]).filter(func(j): return Campaign.can_move(a, j))
			# (--strong=1: our armies are kept at full strength and always push east, to reach the Capital)
			if _arg("strong", "") != "":
				var more = []
				for k in range(Campaign.MAX_STR - a["men"].size()):
					more.append("rifleman")
				Campaign.add_men(a, more, 2)
				opts.sort_custom(func(x, y): return Campaign.REGIONS[x]["p"].x > Campaign.REGIONS[y]["p"].x)
				opts = opts.slice(0, 1)
			# (somebody always stays to hold our own HQ: now that companies can share a region, a player who
			# sends every one of them forward together leaves the door open behind him)
			if a["region"] == Campaign.HQ[0] and Campaign.armies_at(Campaign.HQ[0], 0).size() <= 1:
				continue
			if opts.is_empty() or (randf() < 0.25 and _arg("strong", "") == ""):
				continue
			# buy something now and then
			if randf() < 0.5:
				for pk in ["rifle", "mg", "jeep", "tank"]:
					if Campaign.can_buy(a, pk) == "":
						Campaign.buy(a, pk)
						break
			var res = Campaign.move(a, opts[randi() % opts.size()])
			var guard = 0
			while Campaign.pending_battle() != null and guard < 3:
				guard += 1
				battles += 1
				if int(Campaign.pending_battle().get("stage", 1)) == 2:
					finale += 1
				if Campaign.objective_text() == "" or Campaign.battle_text() == "" or Campaign.odds().size() != 2:
					bad.append("battle with no text at turn %d" % turn)
				Campaign.auto_resolve()
			if Campaign.over() >= 0:
				break
		if Campaign.over() >= 0:
			break
		var lines = Campaign.end_turn()
		for l in lines + D["log"].slice(maxi(0, D["log"].size() - 6)):
			if str(l).find("calls off") >= 0:
				called_off += 1
			if str(l).find("still holds") >= 0:
				held_on += 1
		var guard2 = 0
		while Campaign.pending_battle() != null and guard2 < 3:
			guard2 += 1
			battles += 1
			Campaign.auto_resolve()
		# what must always be true
		D = Campaign.data
		for a in D["armies"]:
			if a["str"] != a["men"].size() or a["str"] <= 0 and a["team"] == 0:
				bad.append("army %s strength %d but %d men" % [a["name"], a["str"], a["men"].size()])
			if D["owner"][a["region"]] != a["team"]:
				bad.append("army %s (team %d) stands on ground held by %d at turn %d" % [a["name"], a["team"], D["owner"][a["region"]], turn])
			if a["veh"].size() > Campaign.MAX_VEH + 1 or a["men"].size() > Campaign.MAX_STR:
				bad.append("army %s over strength" % a["name"])
		for i in range(D["owner"].size()):
			var here = D["armies"].filter(func(x): return x["region"] == i)
			var sides = {}
			for ha in here:
				sides[ha["team"]] = sides.get(ha["team"], 0) + 1
			if sides.size() > 1:
				bad.append("both sides' armies in %s at turn %d" % [Campaign.REGIONS[i]["name"], turn])
			for tk in sides:
				stack_max[tk] = maxi(stack_max[tk], sides[tk])
				if sides[tk] > 1:
					stacked[tk] += 1
				if sides[tk] > Campaign.STACK:
					bad.append("%d armies of one side in %s at turn %d" % [sides[tk], Campaign.REGIONS[i]["name"], turn])
			if D["short"] and not (i in Campaign.SHORT_REGIONS) and D["owner"][i] != -1:
				bad.append("region %d out of play but owned" % i)
		if D["funds"][0] < 0 or D["funds"][1] < 0:
			bad.append("war chest below nothing at turn %d" % turn)
		if not D["headline"].has("head") or str(D["headline"]["head"]) == "":
			bad.append("no headline at turn %d" % turn)
	D = Campaign.data
	print("CAMPTEST %s: ended turn %d, result %d | %d battles (%d at the Ministry), %d questions, %d planned moves seen, %d called off | regions %d:%d | armies %d:%d | fallen %d | last headline: %s" % [
		"short" if D["short"] else "full", D["turn"], Campaign.over(), battles, finale, choices, plans, called_off, D["owner"].count(0), D["owner"].count(1),
		D["armies"].filter(func(x): return x["team"] == 0).size(), D["armies"].filter(func(x): return x["team"] == 1).size(), D["fallen"].size(), str(D["headline"]["head"])])
	print("CAMPTEST stacking: most companies in one region ours %d, Bravo's %d | region-turns with a stack ours %d, Bravo's %d | 'still holds' lines seen %d" % [stack_max[0], stack_max[1], stacked[0], stacked[1], held_on])
	print("CAMPTEST trouble: %s" % (str(bad.slice(0, 6)) if not bad.is_empty() else "none"))
	get_tree().quit()

func _blind_test() -> void:
	await _wait(0.5)
	G.settings["ai_side"] = true
	seed(int(_arg("seed", "11")))
	start_game({"map": _arg("map", "office"), "mode": _arg("mode", "capture"), "size": int(_arg("size", "16")), "limit": 999, "reinforce": true, "armor": _arg("armor", "none"), "reinf_mode": "truck", "teams": 2})
	var secs = float(_arg("secs", "150"))
	var blind = 0.0
	var idle = 0.0
	var seen_s = 0.0
	var why_blind = {}
	var why_idle = {}
	var rng_ = float(_arg("range", "15"))
	var t = 0.0
	while t < secs:
		await _wait(0.25)
		t += 0.25
		for s in G.soldiers:
			if s.state != "alive" or s.zombie or s.vehicle != null or s.broken:
				continue
			var eye: Vector3 = s.head_pos()
			var near = null
			for o in G.soldiers:
				if o.team == s.team or o.state != "alive" or o.vehicle != null:
					continue
				if o.pos.distance_squared_to(s.pos) > rng_ * rng_:
					continue
				if not G.blocked(eye, o.chest(), true):
					near = o
					break
			if near == null:
				s.set_meta("bt_blind", 0.0)
				s.set_meta("bt_idle", 0.0)
				continue
			seen_s += 0.25
			var key = "%s/%s%s%s" % [str(s.task), str(s.order.get("mode", "-")) if s.order != null else "-", "/cover" if s.in_cover else "", "/moving" if s.move_target != null else ""]
			if s.vis_t == null:
				var b: float = s.get_meta("bt_blind", 0.0) + 0.25
				s.set_meta("bt_blind", b)
				if b > 1.0:
					blind += 0.25
					why_blind[key] = why_blind.get(key, 0.0) + 0.25
			else:
				s.set_meta("bt_blind", 0.0)
				if G.sim_time - s.fired_t > 3.0 and s.reload_t <= 0.0:
					var i2: float = s.get_meta("bt_idle", 0.0) + 0.25
					s.set_meta("bt_idle", i2)
					if i2 > 1.0:
						idle += 0.25
						var k2 = key + ("/blocked" if s.gun_blocked else "") + ("/noammo" if s.mag <= 0 else "") + ("/cls:" + s.cls if s.cls in ["medic", "sapper", "engineer"] else "")
						why_idle[k2] = why_idle.get(k2, 0.0) + 0.25
				else:
					s.set_meta("bt_idle", 0.0)
	var kb = why_blind.keys()
	kb.sort_custom(func(a, b): return why_blind[a] > why_blind[b])
	var ki = why_idle.keys()
	ki.sort_custom(func(a, b): return why_idle[a] > why_idle[b])
	print("BLINDTEST %s: %.0f man-seconds with an enemy in plain view within %.0fm | not noticed %.1f | noticed but not firing %.1f" % [_arg("map", "office"), seen_s, rng_, blind, idle])
	print("BLINDTEST not noticed while: %s" % str(kb.slice(0, 8).map(func(k): return "%s %.1f" % [k, why_blind[k]])))
	print("BLINDTEST not firing while: %s" % str(ki.slice(0, 10).map(func(k): return "%s %.1f" % [k, why_idle[k]])))
	get_tree().quit()

# --perfrun --map= --size= --secs= --mode= --armor=: a big AI battle, and where each tick's time goes
func _perf_run() -> void:
	await _wait(0.5)
	G.settings["ai_side"] = true
	seed(7)
	Soldier.PERF = true
	start_game({"map": _arg("map", "town"), "mode": _arg("mode", "commander"), "size": int(_arg("size", "40")), "limit": 999, "reinforce": true, "armor": _arg("armor", "light"), "reinf_mode": "truck", "teams": 2})
	G.pc.free_pos = Vector3(0, 60, 0)
	await _wait(float(_arg("warm", "40")))
	var rounds = int(_arg("rounds", "3"))
	var tot = 0
	var small = 0
	var ranged = 0
	var cnt = 0
	for s in G.soldiers:
		if s.state != "alive":
			continue
		cnt += 1
		var nodes = []
		for b in s.parts:
			nodes.append_array(b.find_children("*", "GeometryInstance3D", true, false))
		if s.gun_node != null:
			nodes.append_array(s.gun_node.find_children("*", "GeometryInstance3D", true, false))
		for g in nodes:
			tot += 1
			if g.visibility_range_end > 0.0:
				ranged += 1
			var ab: AABB = g.get_aabb()
			var sc: Vector3 = g.scale
			if maxf(ab.size.x * sc.x, maxf(ab.size.y * sc.y, ab.size.z * sc.z)) < 0.17:
				small += 1
	var drawn_far = 0
	var nfar = 0
	for s in G.soldiers:
		if s.state == "alive" and s.detail_hidden:
			nfar += 1
			for b in s.parts:
				for g in b.find_children("*", "GeometryInstance3D", true, false):
					if g.visible and g.visibility_range_end <= 0.0:
						drawn_far += 1
			if s.gun_node != null:
				for g in s.gun_node.find_children("*", "GeometryInstance3D", true, false):
					if g.visible and g.visibility_range_end <= 0.0:
						drawn_far += 1
	print("PERF meshes per man %.1f, of which small (under 17 cm) %.1f, already hidden at range %.1f | far-off men: %d, pieces drawn each %.1f" % [tot / maxf(cnt, 1.0), small / maxf(cnt, 1.0), ranged / maxf(cnt, 1.0), nfar, drawn_far / maxf(nfar, 1.0)])
	for k in range(rounds):
		tick_us = 0
		tick_n = 0
		prof = [0, 0]
		prof2 = [0, 0, 0, 0, 0, 0]
		Soldier.pf = [0, 0, 0, 0]
		AI.pf = {}
		await _wait(float(_arg("secs", "20")))
		var n = maxi(tick_n, 1)
		var frozen = 0
		var alive = 0
		for s in G.soldiers:
			if s.lod_frozen:
				frozen += 1
			if s.state == "alive":
				alive += 1
		print("PERF %d: men %d (alive %d, far %d) vehicles %d | tick %.2f ms = vehicles %.2f + soldiers %.2f (think %.2f, pose %.2f, body %.2f, glide %.2f, other %.2f) + combat %.2f + effects %.2f + squads %.2f + support/fog %.2f + commander %.2f" % [k, G.soldiers.size(), alive, frozen, G.vehicles.size(),
			tick_us / 1000.0 / n, prof[0] / 1000.0 / n, prof[1] / 1000.0 / n, Soldier.pf[0] / 1000.0 / n, Soldier.pf[1] / 1000.0 / n, Soldier.pf[2] / 1000.0 / n,
			Soldier.pf[3] / 1000.0 / n, (prof[1] - Soldier.pf[0] - Soldier.pf[1] - Soldier.pf[2] - Soldier.pf[3]) / 1000.0 / n,
			prof2[0] / 1000.0 / n, prof2[1] / 1000.0 / n, prof2[2] / 1000.0 / n, prof2[3] / 1000.0 / n, prof2[4] / 1000.0 / n])
		var keys = AI.pf.keys()
		keys.sort_custom(func(a, b): return AI.pf[a] > AI.pf[b])
		var line = ""
		for kk in keys.slice(0, 14):
			line += "%s %.2f  " % [kk, AI.pf[kk] / 1000.0 / n]
		print("PERF %d think: %s" % [k, line])
		var zc = 0
		for zs in G.soldiers:
			if zs.zombie and zs.state != "dead":
				zc += 1
		print("PERF %d engine: whole physics frame %.1f ms | active bodies %d, pairs %d, islands %d | zombies up %d" % [k, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS), Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS), Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT), zc])
	get_tree().quit()

# somewhere out in the open, with nothing built within r of it
func _open_spot(r: float) -> Vector3:
	var b: Rect2 = G.world.bounds
	for i in range(200):
		var x = randf_range(b.position.x + 20.0, b.end.x - 20.0)
		var z = randf_range(b.position.y + 20.0, b.end.y - 20.0)
		if G.world.cols_in_rect(x - r, z - r, x + r, z + r).is_empty() and not G.world.in_water(x, z):
			return Vector3(x, G.world.ground_y(x, z), z)
	return _free_spot(Vector3.ZERO)

# --polishshot=DIR: pictures of the new looks: a shell landing (flash, ring, clods left lying), rain on a
# town street, breath on a cold morning, mud, dressings and soot on three men, and the office block's rooms
func _polish_shot(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	G.settings["time"] = "day"
	var what = _arg("what", "all")
	if what == "all" or what == "blast":
		G.settings["weather"] = "clear"
		apply_time()
		await _wait(0.3)
		start_game({"map": "field", "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2})
		await _wait(0.5)
		var bp = _open_spot(14.0)
		await _look(bp + Vector3(9, 4.5, 9), bp + Vector3(0, 0.8, 0))
		Combat.explode(bp, null, 1.4)
		for i in range(3):
			await get_tree().physics_frame
		await _snap(dir, "blast_0")
		for i in range(7):
			await get_tree().physics_frame
		await _snap(dir, "blast_1")
		await _wait(0.5)
		await _snap(dir, "blast_2")
		await _wait(4.0)
		await _look(bp + Vector3(5, 3.2, 5), bp)
		await _snap(dir, "blast_after")
		print("POLISHSHOT clods flying %d, slots used %d" % [G.fx.clod_fly.size(), G.fx.clod_i])
	if what == "all" or what == "wear":
		if not G.started:
			start_game({"map": "field", "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2})
			await _wait(0.5)
		var wp = _open_spot(8.0)
		var men = []
		for i in range(3):
			var m = spawn_soldier(0, wp.x + i * 1.1, wp.z, "rifle")
			m.order = {"mode": "hold", "point": m.pos}
			m.body_yaw = 0.0
			m.aim_yaw = 0.0
			men.append(m)
		await _wait(1.0)
		men[0].mud = 1.0
		Wear.mud_tick(men[0], 0.01)
		print("POLISHSHOT mud stage %d, shin has %d pieces; man 0 at x %.1f, man 2 at x %.1f" % [men[0].mud_stage, men[0].parts[8].get_child_count(), men[0].pos.x, men[2].pos.x])
		men[1].wound_part = 5
		Wear.dress(men[1])
		men[1].wound_part = 2
		Wear.dress(men[1])
		men[1].wound_part = 9
		Wear.dress(men[1])
		Wear.soot(men[2])
		for m in men:
			m.aim_yaw = 0.0
			m.body_yaw = 0.0
		await _look(men[1].pos + Vector3(0.0, 1.2, 3.0), men[1].pos + Vector3(0, 0.9, 0))
		await _wait(0.3)
		await _snap(dir, "wear")
	if what == "all" or what == "rain":
		G.settings["weather"] = "rain"
		start_game({"map": "town", "mode": "sandbox", "size": 6, "limit": 999, "reinforce": false, "armor": "none", "teams": 2})
		await _wait(2.5)
		var rd = G.world.roads[0]
		var rc = Vector3((rd[0] + rd[1]) * 0.5, 0, (rd[2] + rd[3]) * 0.5)
		rc.y = G.world.ground_y(rc.x, rc.z)
		var along = Vector3(1, 0, 0) if (rd[1] - rd[0]) > (rd[3] - rd[2]) else Vector3(0, 0, 1)
		await _look(rc - along * 14.0 + Vector3(0, 2.4, 0) + Vector3(along.z, 0, along.x) * 2.0, rc + along * 10.0)
		await _wait(0.6)
		await _snap(dir, "rain_street")
		await _look(rc + Vector3(-30, 45, 30), rc)
		await _wait(0.4)
		await _snap(dir, "rain_above")
		print("POLISHSHOT rain: %d puddles, %d roads" % [Weather.puddles.size(), G.world.roads.size()])
	if what == "all" or what == "cold":
		G.settings["weather"] = "cold"
		start_game({"map": "field", "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2})
		await _wait(0.5)
		var cp2 = _open_spot(8.0)
		var cm = []
		for i in range(4):
			var m = spawn_soldier(0, cp2.x + i * 1.2, cp2.z, "rifle")
			m.order = {"mode": "hold", "point": m.pos}
			cm.append(m)
		for m in cm:
			m.aim_yaw = 0.6
			m.body_yaw = 0.6
		await _look(cm[1].pos + Vector3(2.2, 2.6, 2.2), cm[1].pos + Vector3(0.6, 1.2, 0))
		for i in range(40):
			await get_tree().physics_frame
			if Weather.puffs.filter(func(p): return p[0] < p[1] and p[0] > 0.3).size() >= 3:
				break
		await _snap(dir, "cold_breath")
		print("POLISHSHOT cold: puffs live %d" % Weather.puffs.filter(func(p): return p[0] < p[1]).size())
	if what == "wall":
		# a man hard up against a wall with his rifle blocked: where does the rifle go?
		G.settings["weather"] = "clear"
		start_game({"map": "town", "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2})
		await _wait(0.5)
		var wc = null
		for c in G.world.cols:
			if c.alive and c.hi.y - c.lo.y > 2.4 and c.hi.x - c.lo.x > 2.0 and c.hi.z - c.lo.z < 0.8 and absf(c.lo.y - c.gy) < 0.3:
				var mid = Vector3((c.lo.x + c.hi.x) * 0.5, c.gy, c.hi.z + 0.55)
				if not G.world.inside_any(mid.x, mid.z, 0.3) and G.world.cols_in_rect(mid.x - 1.5, mid.z + 0.4, mid.x + 1.5, mid.z + 3.5).is_empty():
					wc = c
					break
		if wc != null:
			var sp0 = Vector3((wc.lo.x + wc.hi.x) * 0.5, wc.gy, wc.hi.z + 0.55)
			var m = spawn_soldier(0, sp0.x, sp0.z, "rifle")
			m.order = {"mode": "hold", "point": sp0}
			var hold = func():
				m.pos = Vector3(sp0.x, m.pos.y, sp0.z)
				m.vel = Vector3.ZERO
				m.want = Vector3.ZERO
				m.move_target = null
				m.aim_yaw = PI
				m.body_yaw = PI
				m.aim_pitch = 0.0
				m.ready_ = true
				m.gun_blocked = true
				m.clip_n = 0
			for shot_i in range(2):
				await _look(sp0 + (Vector3(2.4, 1.5, 1.2) if shot_i == 0 else Vector3(0.0, 1.7, 2.6)), sp0 + Vector3(0, 1.25, 0))
				for i in range(40):
					hold.call()
					await get_tree().physics_frame
				hold.call()
				await _snap(dir, "wall_side" if shot_i == 0 else "wall_back")
			var hd: Vector3 = m.parts[2].global_position
			var gp: Vector3 = m.gun_node.global_position
			var gdir: Vector3 = -m.gun_node.global_transform.basis.z
			print("POLISHSHOT wall: blocked %s, rifle axis passes %.2f m from the middle of his head" % [str(m.gun_blocked), (hd - gp).cross(gdir.normalized()).length()])
		else:
			print("POLISHSHOT wall: no wall found")
	if what == "far":
		G.settings["weather"] = "clear"
		G.settings["ai_side"] = true
		seed(5)
		start_game({"map": "town", "mode": "sandbox", "size": 40, "limit": 999, "reinforce": false, "armor": "none", "teams": 2})
		await _wait(3.0)
		var cen = Vector3.ZERO
		var nn = 0
		for m in G.soldiers:
			if m.team == 0 and m.state == "alive" and not m.hidden_in_vehicle:
				cen += m.pos
				nn += 1
		cen /= maxf(nn, 1.0)
		await _look(cen + Vector3(34, 46, 34), cen)
		await _wait(0.5)
		var hid = 0
		for m in G.soldiers:
			if m.detail_hidden:
				hid += 1
		await _snap(dir, "far_lean")
		for m in G.soldiers:
			m._far_detail(false)
		await get_tree().process_frame
		await _snap(dir, "far_full")
		print("POLISHSHOT far: %d men, %d drawn with the small pieces left off" % [G.soldiers.size(), hid])
	if what == "all" or what == "office":
		G.settings["weather"] = "clear"
		start_game({"map": "office", "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2})
		await _wait(1.0)
		G.ui.floor_view.pick(1)
		await _look(Vector3(-46, 30, 16), Vector3(-30, 3.6, 2))
		await _wait(0.4)
		await _snap(dir, "office_floor1")
		G.ui.floor_view.pick(0)
		await _look(Vector3(20, 17, 30), Vector3(14, 0, 8))
		await _wait(0.4)
		await _snap(dir, "office_floor0")
		# inside a back office looking at the window wall, and down the corridor
		G.ui.floor_view.pick(-1)
		await _look(Vector3(-40.0, 1.7, 13.2), Vector3(-36.0, 1.0, 21.5))
		await _wait(0.4)
		await _snap(dir, "office_room")
		await _look(Vector3(-44.0, 1.7, 0.0), Vector3(-20.0, 1.2, 0.0))
		await _wait(0.4)
		await _snap(dir, "office_corridor")
		# a shot fired in a room: the flash on the walls
		G.fx.muzzle(Vector3(-39.0, 1.4, 17.0), true)
		await _look(Vector3(-41.5, 1.7, 13.2), Vector3(-37.0, 1.2, 20.0))
		await get_tree().process_frame
		await _snap(dir, "office_flash")
	get_tree().quit()

# --camtest: the commander view: does a jump glide instead of cutting, does the spot under the pointer stay
# under it when you zoom, and does a second click on a squad card take the view to the squad
func _cam_test() -> void:
	await _wait(0.5)
	start_game({"map": "field", "mode": "commander", "size": 1, "limit": 60, "reinforce": false, "armor": "none", "teams": 2})
	await _wait(2.0)
	var pc = G.pc
	var f0: Vector3 = pc.rts_focus
	pc.rts_focus = f0 + Vector3(40, 0, 0)
	var steps = 0
	var first = 0.0
	var prev: Vector3 = pc.free_pos
	for i in range(90):
		await get_tree().process_frame
		var mv = pc.free_pos.distance_to(prev)
		if i == 0:
			first = mv
		if mv > 0.02:
			steps += 1
		prev = pc.free_pos
	print("CAMTEST jump of 40m: first frame moved %.1fm, kept moving for %d frames, ended %.2fm from where it was sent" % [first, steps, G.dist2d(pc.rcam_focus, pc.rts_focus)])
	var vp = get_viewport().get_visible_rect().size
	var scr = Vector2(vp.x * 0.78, vp.y * 0.3)
	var g0 = pc._ground_at(scr)
	var d0: float = pc.rts_dist
	for k in range(4):
		var ev = InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_WHEEL_UP
		ev.pressed = true
		ev.position = scr
		pc._unhandled_input(ev)
		for i in range(8):
			await get_tree().process_frame
	for i in range(90):
		await get_tree().process_frame
	var g1 = pc._ground_at(scr)
	if g0 != null and g1 != null:
		print("CAMTEST zoom %.0fm -> %.0fm at a point off to one side: the ground under the pointer moved %.1fm (the middle of the view moved %.1fm)" % [d0, pc.rts_dist, G.dist2d(g0, g1), G.dist2d(f0 + Vector3(40, 0, 0), pc.rts_focus)])
	else:
		print("CAMTEST zoom: no ground under the pointer (%s, %s)" % [str(g0), str(g1)])
	var qs = pc.my_squads()
	if qs.size() >= 2:
		var before: Vector3 = pc.rts_focus
		pc.select_squad(1, 0)
		await get_tree().process_frame
		var moved1 = G.dist2d(before, pc.rts_focus)
		pc.select_squad(1, 1)
		var c = Vector3.ZERO
		for m in pc.selection:
			c += m.pos
		c /= maxf(1.0, pc.selection.size())
		print("CAMTEST squad card: one click moved the view %.1fm (selected %d men), a second click sent it to %.1fm from the squad" % [moved1, pc.selection.size(), G.dist2d(pc.rts_focus, c)])
	pc.cycle_contact()
	get_tree().quit()

# --vaultshot=DIR|-: one man sent over a sandbag wall, then up a ladder (on a map that has one): the biggest
# jump any joint makes in a single frame relative to where he stands (a snap between poses shows as a big
# one), and pictures of each
func _vault_shot(dir: String) -> void:
	var shots = dir != "-"
	if shots:
		DirAccess.make_dir_recursive_absolute(dir)
	G.settings["time"] = "day"
	apply_time()
	await _wait(0.3)
	start_game({"map": _arg("map", "town"), "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2})
	await _wait(0.5)
	var p0 = G.main._free_spot(Vector3(0, 0, 0))
	G.world.sandbags(p0.x, p0.z + 2.5, 24.0, true, 1.0)
	G.world.update_nav_area(p0.x - 13.0, p0.z, p0.x + 13.0, p0.z + 5.0)
	var s = spawn_soldier(0, p0.x, p0.z, "rifle")
	s.order = {"mode": "hold", "point": s.pos}
	await _wait(1.0)
	var worst = 0.0
	var went = false
	var prev: Array = []
	for i in range(15):
		prev.append(s.P[i] - s.pos)
	var n = 0
	for i in range(200):
		if i == 0:
			var goal = p0 + Vector3(0, 0, 6.0)
			s.order = {"mode": "move", "point": goal}
			AI.go_to(s, goal, 3.0)
		await get_tree().physics_frame
		if s.vault != null:
			went = true
			n += 1
			if shots and n % 7 == 3:
				await _look(s.pos + Vector3(2.6, 1.2, 0.0), s.pos + Vector3(0, 0.8, 0))
				await _snap(dir, "vault_%d" % (n / 7))
		if went and n < 76:
			for k in range(15):
				var cur: Vector3 = s.P[k] - s.pos
				worst = maxf(worst, cur.distance_to(prev[k]))
				if cur.distance_to(prev[k]) > 0.1 and _arg("dbg", "0") == "1":
					print("VJ i%d joint %d jump %.2f vault=%s t=%.2f plant_ok=%s" % [i, k, cur.distance_to(prev[k]), str(s.vault != null), s.vault["t"] if s.vault != null else 9.0, str(s.foot_ok)])
		for k in range(15):
			prev[k] = s.P[k] - s.pos
		if went and s.vault == null:
			n += 1
			if shots and n % 7 == 3 and n < 80:
				await _look(s.pos + Vector3(2.6, 1.2, 0.0), s.pos + Vector3(0, 0.8, 0))
				await _snap(dir, "land_%d" % (n / 7))
	print("VAULTSHOT wall: went over %s, biggest joint jump in one frame %.3fm, state %s" % [str(went), worst, s.state])
	var lads = G.world.towers.filter(func(T): return T.get("ladder", false))
	if lads.is_empty():
		print("VAULTSHOT ladder: none on this map")
		get_tree().quit()
		return
	var T = lads[0]
	var lo: Vector3 = T["stair_bottom"]
	var c = spawn_soldier(0, lo.x, lo.z, "rifle")
	c.body_yaw = atan2(T["n"].x, T["n"].z) + 1.2
	await _wait(0.6)
	c.start_climb(T, true)
	worst = 0.0
	for k in range(15):
		prev[k] = c.P[k] - c.pos
	n = 0
	while c.climb != null and n < 400:
		await get_tree().physics_frame
		n += 1
		for k in range(15):
			var cur: Vector3 = c.P[k] - c.pos
			worst = maxf(worst, cur.distance_to(prev[k]))
			if cur.distance_to(prev[k]) > 0.1 and _arg("dbg", "0") == "1":
				print("LJ n%d joint %d jump %.2f t=%.3f" % [n, k, cur.distance_to(prev[k]), c.climb["t"] if c.climb != null else 9.0])
			prev[k] = cur
		if shots and n % 20 == 5:
			var nn: Vector3 = T["n"]
			await _look(c.pos + nn * 3.0 + Vector3(-nn.z, 0, nn.x) * 2.0 + Vector3(0, 1.4, 0), c.pos + Vector3(0, 0.9, 0))
			await _snap(dir, "ladder_%d" % (n / 20))
	print("VAULTSHOT ladder: %d frames, biggest joint jump in one frame %.3fm, state %s" % [n, worst, c.state])
	get_tree().quit()

# --lanetest: lorries sent both ways along the same road: which side do they pass on, how close, how long
func _lane_test() -> void:
	await _wait(0.5)
	start_game({"map": _arg("map", "town"), "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2})
	await _wait(0.5)
	var rd = G.world.roads[0]
	var zc = (rd[2] + rd[3]) * 0.5
	var vs = []
	for i in range(int(_arg("n", "3"))):
		var a = spawn_vehicle("truck", 0, Vector3(-70.0 - i * 14.0, 0, zc), PI / 2.0)
		var b = spawn_vehicle("truck", 0, Vector3(70.0 + i * 14.0, 0, zc), -PI / 2.0)
		a.cmd = Vector3(80.0 - i * 12.0, 0, zc)
		b.cmd = Vector3(-80.0 + i * 12.0, 0, zc)
		vs.append([a, 1.0])
		vs.append([b, -1.0])
	await _wait(1.5)
	var v0 = vs[1][0]
	var W = G.world
	var roadw = []
	for x in range(-60, 61, 12):
		var c = W.vnav_cell(float(x), zc)
		roadw.append("%s%.1f" % ["#" if W.vastar.is_point_solid(c) else "", W.vastar.get_point_weight_scale(c)])
	print("LANE path of first lorry (at %.0f,%.0f, goal %s, why=%s): %s | road weights %s" % [v0.pos.x, v0.pos.z, str(v0.goal), v0.why, str(v0.path.map(func(q): return "%.0f,%.0f" % [q.x, q.z])), str(roadw)])
	var min_d = 1e9
	var right_n = 0
	var cross_n = 0
	var done_t = -1.0
	var crossed = {}
	for t in range(60 * 8):
		await _wait(0.125)
		var arrived = 0
		for e in vs:
			var v = e[0]
			if v.cmd == null or G.dist2d(v.cmd, v.pos) < 14.0:
				arrived += 1
			# which side of the road it's on as it goes through the middle stretch
			if absf(v.pos.x) < 6.0 and not crossed.has(v):
				crossed[v] = true
				cross_n += 1
				print("LANE cross dir=%+d z_off=%.1f t=%.0f spd=%.1f" % [int(e[1]), v.pos.z - zc, G.sim_time, v.speed])
				if _arg("laneshot", "") != "" and cross_n == 3:
					DirAccess.make_dir_recursive_absolute(_arg("laneshot", ""))
					await _look(Vector3(0, 46, zc + 16.0), Vector3(0, 0, zc))
					await _wait(0.1)
					await _snap(_arg("laneshot", ""), "lorries_keep_right")
				if (v.pos.z - zc) * e[1] < -0.3:
					right_n += 1
			for e2 in vs:
				if e2[0] != v and e2[1] != e[1] and absf(v.speed) > 2.0 and absf(e2[0].speed) > 2.0:
					min_d = minf(min_d, G.dist2d(v.pos, e2[0].pos))
		if arrived == vs.size() and done_t < 0.0:
			done_t = G.sim_time
			break
	print("LANETEST road z=%.1f..%.1f lorries=%d crossed=%d on_right=%d closest_pass=%.1fm all_arrived=%s stuck=%s" % [rd[2], rd[3], vs.size(), cross_n, right_n, min_d, ("%.0fs" % done_t) if done_t > 0.0 else "no", StuckLog.summary()])
	get_tree().quit()

# --tankshot=DIR: a tank and a squad sent into the city together: do they go in as one?
func _tank_shot(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	G.settings["time"] = "day"
	apply_time()
	G.settings["ai_side"] = true
	seed(5)
	await _wait(0.3)
	start_game({"map": "city", "mode": "capture", "size": 3, "limit": 999, "reinforce": false, "armor": "none", "teams": 2})
	await _wait(0.5)
	var sp: Vector3 = G.world.spawn[0]
	var toward = G.flat(G.world.capture - sp).normalized()
	var tp = _free_spot(sp + toward * 22.0)
	var tank = spawn_vehicle("tank", 0, tp, atan2(toward.x, toward.z))
	var men = []
	for i in range(5):
		var q = _free_spot(sp + toward * 2.0 + Vector3(toward.z, 0, -toward.x) * (i - 2) * 1.5)
		men.append(spawn_soldier(0, q.x, q.z, "rifle"))
	var shot = 0
	for t in range(int(_arg("secs", "90")) / 2):
		await _wait(2.0)
		if not is_instance_valid(tank) or tank.dead:
			break
		var ds = []
		var behind = 0
		for m in men:
			if is_instance_valid(m) and m.state == "alive":
				ds.append(int(G.dist2d(m.pos, tank.pos)))
				if G.flat(m.pos - tank.pos).dot(tank.forward()) < 0.0:
					behind += 1
		var with_q = 0
		for q in G.squads:
			if q.get("tank") == tank and G.sim_time < q.get("tank_t", 0.0):
				with_q += 1
		print("TANKSHOT t%d spd=%.1f why=%s goal_d=%.0f wait=%s pace=%s squads_with=%d men_d=%s behind=%d" % [int(G.sim_time), tank.speed, tank.why, G.dist2d(tank.goal, tank.pos), str(G.sim_time < float(tank.get_meta("inf_wait", 0.0))), str(G.sim_time < float(tank.get_meta("inf_pace", 0.0))), with_q, str(ds), behind])
		ds.sort()
		if dir != "-" and shot < 2 and with_q > 0 and ds.size() >= 2 and ds[1] < 14 and absf(tank.speed) > 1.0:
			await _look(tank.pos + Vector3(-10, 16, 12), tank.pos)
			await _wait(0.2)
			await _snap(dir, "tank_with_infantry_%d" % shot)
			shot += 1
	get_tree().quit()

# --tanktest: a city battle with armour: when a squad is going in with a tank, how close they keep to it
func _tank_test() -> void:
	await _wait(0.5)
	G.settings["ai_side"] = true
	seed(11)
	start_game({"map": _arg("map", "city"), "mode": _arg("mode", "frontline"), "size": 12, "limit": 999, "reinforce": true, "armor": "heavy", "reinf_mode": "truck", "teams": 2})
	for t in range(int(_arg("secs", "200")) / 5):
		await _wait(5.0)
		for q in G.squads:
			var tk = q.get("tank")
			if tk == null or not is_instance_valid(tk) or tk.dead or G.sim_time > q.get("tank_t", 0.0):
				continue
			var ds = []
			for m in q["members"]:
				if is_instance_valid(m) and m.state == "alive" and m.vehicle == null:
					ds.append(int(G.dist2d(m.pos, tk.pos)))
			print("TANKTEST t%d %s T%d spd=%.1f wait=%s pace=%s waited=%.0f men_d=%s contact=%s" % [int(G.sim_time), tk.kind, tk.team, tk.speed, str(G.sim_time < float(tk.get_meta("inf_wait", 0.0))), str(G.sim_time < float(tk.get_meta("inf_pace", 0.0))), float(tk.get_meta("inf_waited", 0.0)), str(ds), str(G.sim_time - Squad.leader_of(q).seen_t < 8.0 if Squad.leader_of(q) != null else false)])
	print("TANKTEST events ", Tactics.events.get("tank_inf", 0))
	get_tree().quit()

# --roomshot=DIR: a squad in the office block's ground-floor corridor, an enemy in one of the offices:
# the stack on the door, the entry, the room afterwards
func _room_shot(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	G.settings["time"] = "day"
	apply_time()
	await _wait(0.3)
	start_game({"map": "office", "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2})
	await _wait(0.5)
	var men = []
	for i in range(4):
		var s = spawn_soldier(0, -34.0 + i * 1.2, 0.3 * (1 if i % 2 == 0 else -1), "rifle")
		s.grenades = 2
		men.append(s)
	var q = men[0].squad
	for s in men:
		if s.squad != q:
			if s.squad != null:
				s.squad["members"].erase(s)
			s.squad = q
			q["members"].append(s)
	var foe = spawn_soldier(1, -46.0, 8.0, "rifle")
	foe.order = {"mode": "hold", "point": foe.pos}
	# they've heard him in there
	for s in men:
		AI.add_intel(s, foe, foe.pos, 0.2, false)
	G.ui.floor_view.pick(0)
	await _look(Vector3(-40, 15, -9), Vector3(-44, 0, 4))
	var seen = {}
	for t in range(160):
		await _wait(0.25)
		for s in men:
			if is_instance_valid(foe) and foe.state == "alive":
				AI.add_intel(s, foe, foe.pos, 0.2, false)
		var st = q.get("room")
		var stage = st["stage"] if st != null else "-"
		if not seen.has(stage):
			seen[stage] = true
			print("ROOMSHOT t%.1f stage=%s foe=%s stacks=%d clears=%d" % [G.sim_time, stage, foe.state if is_instance_valid(foe) else "gone", Tactics.events.get("room_stack", 0), Tactics.events.get("room_clear", 0)])
		if stage == "stack" and not seen.has("s_shot"):
			var near = 0
			for s in men:
				if G.dist2d(s.pos, st["door"]["c"]) < 3.0:
					near += 1
			if near >= 2:
				seen["s_shot"] = true
				await _snap(dir, "room_stack")
		if stage == "inside" and not seen.has("i_shot") and G.sim_time > st["t"] - 1.0:
			seen["i_shot"] = true
			await _snap(dir, "room_entry")
		if stage == "-" and seen.has("inside") and not seen.has("d_shot"):
			seen["d_shot"] = true
			await _wait(0.6)
			await _snap(dir, "room_clear")
			break
	print("ROOMSHOT end foe=%s stacks=%d clears=%d" % [foe.state if is_instance_valid(foe) else "gone", Tactics.events.get("room_stack", 0), Tactics.events.get("room_clear", 0)])
	get_tree().quit()

# --hqshot=DIR: your HQ from above with its roof on, then lifted off
func _hq_shot(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	G.settings["time"] = "day"
	apply_time()
	await _wait(0.3)
	start_game({"map": "field", "mode": "commander", "size": 8, "limit": 999, "reinforce": true, "armor": "light", "reinf_mode": "truck", "teams": 2, "factions": (_arg("fac", "army,army") + ",army").split(",")})
	await _wait(4.0)
	var hq = Build.hq(0)
	var p: Vector3 = hq["p"]
	G.pc.rts_focus = p
	G.pc.rts_dist = 22.0
	await _wait(0.6)
	await _snap(dir, "hq_roof")
	G.pc._hq_cut(hq)
	await _wait(0.3)
	await _snap(dir, "hq_inside")
	get_tree().quit()

# --floorshot=DIR: the office block from above with each floor shown in turn, and a few views inside
func _floor_shot(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	G.settings["time"] = "day"
	apply_time()
	G.settings["ai_side"] = true
	seed(3)
	await _wait(0.3)
	start_game({"map": "office", "mode": _arg("mode", "capture"), "size": 12, "limit": 999, "reinforce": true, "armor": "none", "teams": 2})
	await _wait(float(_arg("wait", "45")))
	G.ui.floor_view.pick(-1)
	await _look(Vector3(-30, 62, 34), Vector3(-6, 0, 0))
	await _wait(0.4)
	await _snap(dir, "office_whole")
	for k in range(Levels.n):
		G.ui.floor_view.pick(k)
		await _wait(0.4)
		await _snap(dir, "office_floor%d" % k)
	G.ui.floor_view.pick(1)
	await _look(Vector3(-46, 30, 16), Vector3(-30, 3.6, 2))
	await _wait(0.4)
	await _snap(dir, "office_floor1_close")
	G.ui.floor_view.pick(2)
	await _look(Vector3(-4, 26, 18), Vector3(4, 7.2, 4))
	await _wait(0.4)
	await _snap(dir, "office_floor2_close")
	G.ui.floor_view.pick(-1)
	await _look(Vector3(-110, 20, -50), Vector3(0, 4, 0))
	await _wait(0.4)
	await _snap(dir, "office_outside")
	get_tree().quit()

# --stuckrun --battles=N --secs=S --maps=a,b --mode=m: play AI battles back to back and count what got stuck, and why
func _stuck_run() -> void:
	await _wait(0.5)
	G.settings["ai_side"] = true
	var maps = _arg("maps", "field,town,office,valley").split(",")
	StuckLog.reset()
	var total = {}
	for i in range(int(_arg("battles", "4"))):
		seed(100 + i)
		var m = maps[i % maps.size()]
		start_game({"map": m, "mode": _arg("mode", "commander"), "size": int(_arg("size", "12")), "limit": 999, "reinforce": true, "armor": _arg("armor", "light"), "reinf_mode": "truck", "teams": 2})
		StuckLog.reset()
		await _wait(float(_arg("secs", "240")))
		print("PLAN %s styles=%s phases=%s" % [str(Commander.events), str(Commander.style), str(Commander.plans.map(func(p): return (p["phase"] + "/" + p["res"]) if p != null else "-"))])
		print("STUCKRUN battle %d %s: %s | trail=%d tank_inf=%d rooms=%d/%d" % [i, m, StuckLog.summary(), Squad.events.get("trail", 0), Tactics.events.get("tank_inf", 0), Tactics.events.get("room_clear", 0), Tactics.events.get("room_stack", 0)])
		for k in StuckLog.counts:
			total[k] = total.get(k, 0) + StuckLog.counts[k]
	var keys = total.keys()
	keys.sort_custom(func(a, b): return total[a] > total[b])
	print("STUCKRUN total: ", " ".join(keys.map(func(k): return "%s=%d" % [k, total[k]])))
	get_tree().quit()

# --wandertest: men who keep walking and get nowhere (or walk with nowhere to go): what they're up to
func _wander_test() -> void:
	await _wait(0.5)
	G.settings["ai_side"] = true
	seed(int(_arg("seed", "6")))
	start_game({"map": _arg("map", "field"), "mode": _arg("mode", "commander"), "size": int(_arg("size", "12")), "limit": 999, "reinforce": true, "armor": "light", "reinf_mode": "truck", "teams": 2})
	await _wait(0.5)
	var hist = {}
	var told = {}
	var n = 0
	for k in range(int(_arg("secs", "240")) / 2):
		await _wait(2.0)
		for s in G.soldiers:
			if s.state != "alive" or s.vehicle != null or s.is_player:
				continue
			var id = s.get_instance_id()
			var h: Array = hist.get(id, [])
			h.append([s.pos, s.vel.length()])
			if h.size() > 10:
				h.pop_front()
			hist[id] = h
			if h.size() < 10 or told.has(id):
				continue
			var walked = 0.0
			var moving_n = 0
			for e in h:
				walked += e[1] * 2.0
				if e[1] > 0.6:
					moving_n += 1
			var net = G.dist2d(h[0][0], h[h.size() - 1][0])
			if moving_n >= 8 and net < 4.0 and walked > 14.0:
				told[id] = true
				n += 1
				var fwd = Vector3(sin(s.body_yaw), 0, cos(s.body_yaw))
				var side = absf(G.flat(s.vel).normalized().dot(fwd)) if s.vel.length() > 0.3 else -1.0
				print("WANDER t%d T%d %s at (%.0f,%.0f) task=%s order=%s mt=%s path=%d/%d unstick=%.1f slide=%.1f stuck=%d wedge=%d cover=%s in_cover=%s ready=%s fwd_dot=%.2f flee=%s scramble=%s vis=%s" % [int(G.sim_time), s.team, s.cls, s.pos.x, s.pos.z,
					str(s.task), str(s.order.get("mode", "") if s.order != null else "-"), str(s.move_target), s.path_i, s.path.size(), s.unstick_t, s.slide_t, s.stuck_n, s.wedge_n,
					str(s.cover != null), str(s.in_cover), str(s.ready_), side, str(s.flee != null), str(s.scramble != null), str(s.vis_t != null)])
	print("WANDER total ", n)
	get_tree().quit()

# --levelbattle: an AI battle in the office block: who's on which floor, who holds the flags
func _level_battle() -> void:
	await _wait(0.5)
	G.settings["ai_side"] = true
	seed(int(_arg("seed", "4")))
	start_game({"map": "office", "mode": _arg("mode", "capture"), "size": int(_arg("size", "12")), "limit": 999, "reinforce": true, "armor": "none", "teams": 2})
	await _wait(0.5)
	var stuck = {}
	for t in range(int(_arg("secs", "300")) / 10):
		await _wait(10.0)
		var c = [[0, 0, 0, 0], [0, 0, 0, 0]]
		var still = 0
		for s in G.soldiers:
			if s.state != "alive" or s.team > 1:
				continue
			var k = Levels.level_of(s.pos) if Levels.inside(s.pos) else 3
			c[s.team][k] += 1
			var key = s.get_instance_id()
			if stuck.has(key) and stuck[key].distance_to(s.pos) < 0.5 and s.move_target != null:
				still += 1
			stuck[key] = s.pos
		var flags = []
		for pt in Obj.points:
			flags.append("%s:%d" % [pt["name"], pt["owner"]])
		print("LB t%d A[g,1,2,out]=%s B=%s flags=%s stuck_moving=%d rooms=%d doors=%d stacks=%d clears=%d" % [int(G.sim_time), str(c[0]), str(c[1]), " ".join(flags), still, Rooms.list.size(), Rooms.raw_doors.size(), Tactics.events.get("room_stack", 0), Tactics.events.get("room_clear", 0)])
	get_tree().quit()

# --leveltest: the office block's floors, stairs and paths, then men sent to every floor
func _level_test() -> void:
	await _wait(0.5)
	start_game({"map": "office", "mode": _arg("mode", "capture"), "size": int(_arg("size", "8")), "limit": 999, "reinforce": false, "armor": "none", "teams": 2})
	await _wait(0.5)
	print("LEVELS on=", Levels.on, " grids=", Levels.grids.size(), " stairs=", Levels.stairs.size(), " bi=", Levels.bi)
	for k in range(1, Levels.n):
		var g: AStarGrid2D = Levels.grids[k]
		var free = 0
		for iz in range(Levels.GH):
			for ix in range(Levels.GW):
				if not g.is_point_solid(Vector2i(ix, iz)):
					free += 1
		print("LEVEL ", k, " free cells ", free, " of ", Levels.GW * Levels.GH)
	for st in Levels.stairs:
		print("STAIR k=", st["k"], " a=", st["a"], " walk_a=", Levels.walkable(st["k"], st["a"]), " b=", st["b"], " walk_b=", Levels.walkable(st["k"] + 1, st["b"]))
	var cps = [0, 0, 0]
	for cp in G.world.cover:
		if Levels.inside(cp.p):
			cps[cp.lv] += 1
	print("COVER per floor ", cps)
	for pt in Obj.points:
		var pth = Levels.path(G.world.spawn[0], pt["p"])
		var lvls = []
		for q in pth:
			lvls.append(Levels.level_of(q))
		print("PATH to ", pt["name"], " lv", pt.get("lv", 0), " pts=", pth.size(), " levels=", lvls)
	# men sent to each floor: where do they get to?
	var men = []
	var goals = []
	for k in range(Levels.n):
		for j in range(2):
			var s = spawn_soldier(0, -60.0, -4.0 + j * 2.0 + k * 4.0, "rifle")
			var goal = Levels.spot_on(k, Vector3(20.0 - k * 10.0, 0, 8.0 * (1 if j == 0 else -1)), 3.0)
			s.order = {"mode": "move", "point": goal}
			AI.route_to(s, goal, 3.0)
			men.append(s)
			goals.append(goal)
	for t in range(int(_arg("secs", "70"))):
		await _wait(1.0)
		if _arg("trace", "") != "" and t % 3 == 0:
			var ti = int(_arg("trace", "0"))
			var tm = men[ti]
			print("TR t%d (%.1f,%.1f,%.1f) lv%d tgt=%s path_i=%d/%d task=%s stuck=%d wedge=%d" % [t, tm.pos.x, tm.pos.y, tm.pos.z, Levels.level_of(tm.pos), str(tm.move_target), tm.path_i, tm.path.size(), str(tm.task), tm.stuck_n, tm.wedge_n])
		for i in range(men.size()):
			var s = men[i]
			if s.order != null and s.move_target == null and G.dist2d(s.pos, goals[i]) > 2.0:
				AI.route_to(s, goals[i], 3.0)
	for i in range(men.size()):
		var s = men[i]
		print("MAN ", i, " goal lv", Levels.level_of(goals[i]), " at lv", Levels.level_of(s.pos), " y=%.1f d=%.1f state=%s" % [s.pos.y, G.dist2d(s.pos, goals[i]), s.state])
	get_tree().quit()

func _vstuck() -> void:
	await _wait(0.5)
	G.settings["ai_side"] = true
	seed(int(_arg("seed", "5")))
	start_game({"map": _arg("map", "town"), "mode": _arg("mode", "commander"), "size": 12, "limit": 999, "reinforce": true, "armor": _arg("armor", "light"), "reinf_mode": "truck", "teams": 2})
	await _wait(0.5)
	var hist = {}
	var episodes = 0
	var seen = {}
	for k in range(int(_arg("n", "60"))):
		await _wait(5.0)
		for v in G.vehicles:
			if v.dead or v.spec.get("air", false) or v.spec.get("static", false) or v.driver() == null:
				continue
			var id = v.get_instance_id()
			var h: Array = hist.get(id, [])
			h.append(v.pos)
			if h.size() > 4:
				h.pop_front()
			hist[id] = h
			var wants = v.why in ["drive", "convoy"]
			if h.size() == 4 and h[0].distance_to(h[3]) < 3.0 and wants:
				var key = "%d_%d" % [id, int(v.pos.x / 5.0) * 1000 + int(v.pos.z / 5.0)]
				if seen.has(key):
					continue
				seen[key] = true
				episodes += 1
				var near = []
				for o in G.vehicles:
					if o != v and G.dist2d(o.pos, v.pos) < 10.0:
						near.append("%s%s(%.0fm)" % [o.kind, "X" if o.dead else "", G.dist2d(o.pos, v.pos)])
				var b: Rect2 = G.world.bounds
				var edge = minf(minf(v.pos.x - b.position.x, b.end.x - v.pos.x), minf(v.pos.z - b.position.y, b.end.y - v.pos.z))
				print("VSTUCK t%d %s T%d at (%.0f,%.0f) why=%s mis=%s stage=%s cmd=%s goal_d=%.0f edge=%.0f inside=%s road=%s near=%s stuck_n=%d det=%s" % [
					int(G.sim_time), v.kind, v.team, v.pos.x, v.pos.z, v.why, str(v.mission.get("type", "") if v.mission != null else "-"),
					str(v.mission.get("stage", -1) if v.mission != null else -1), str(v.cmd != null), G.dist2d(v.goal, v.pos),
					edge, str(G.world.inside_any(v.pos.x, v.pos.z, 1.0)), str(G.world.on_road(v.pos.x, v.pos.z)), ",".join(near), v.stuck_n, str(v.detour != null)] + " thr=%s yield=%.1f rev=%.1f fw=%.1f spd=%.2f hold=%s friends_front=%d" % [str(v._drive_cache), v.yield_t, v.reverse_t, v.get_meta("fw_t", 0.0), v.speed, v.hold_mode,
					G.soldiers.filter(func(sx): return sx.team == v.team and sx.state == "alive" and sx.vehicle == null and G.dist2d(sx.pos, v.pos + v.forward() * 4.0) < 4.0).size()])
	print("VSTUCK episodes ", episodes, " vehicles ", G.vehicles.size())
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
				await _look(ag.pos + side * 4.2 - fw * 1.2 + Vector3(0, 2.2, 0), ag.pos - fw * 0.8 + Vector3(0, 0.8, 0))
				await _snap(dir, "atgun_%d" % shots)
				shots += 1
		if shots >= 4 and fired >= 2:
			break
	print("ATTEST shots fired %d, pictures %d, tank hp %.0f, driver %s gunner %s" % [fired, shots, tk.hp if is_instance_valid(tk) else -1.0, str(ag.driver() != null), str(ag.gunner() != null)])
	get_tree().quit()

# vehicles with their headlights on at night, from the side, from in front and from above
# the militia's own vehicles side by side
func _var_shot(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	G.settings["time"] = "day"
	apply_time()
	await _wait(0.3)
	start_game({"map": "field", "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2, "armies": false, "factions": ["militia", "army", "army", "army"]})
	await _wait(0.5)
	G.pc.force_free = true
	var c: Vector3 = _free_spot(G.world.capture + Vector3(-20, 0, 0))
	var k = 0
	for kind in ["oldtank", "gunbus", "techaa", "technical"]:
		var v = spawn_vehicle(kind, 0, _free_spot(c + Vector3(k * 9.0, 0, 0)), PI * 0.5, false)
		print("VARSHOT ", kind, " -> ", v.kind, " ", v.spec["name"], " hp ", v.hp)
		k += 1
	await _wait(1.0)
	await _look(c + Vector3(13.0, 5.0, -14.0), c + Vector3(13.0, 1.0, 0))
	await _snap(dir, "militia_vehicles")
	get_tree().quit()

# one AI-vs-AI battle, start to finish (or to a time cap), summed up on one line for balance tuning
func _balance() -> void:
	await _wait(0.3)
	G.settings["ai_side"] = true
	var mode = _arg("mode", "capture")
	var seed_ = int(_arg("seed", str(randi())))
	seed(seed_)
	G.random_seed = seed_
	start_game({"map": _arg("map", "field"), "mode": mode, "size": int(_arg("size", "12")), "limit": int(_arg("limit", "150")), "reinforce": true,
		"armor": _arg("armor", "light"), "reinf_mode": "truck", "teams": 2, "factions": (_arg("fac", "army,army") + ",army,army").split(",")})
	var cap = float(_arg("cap", "420"))
	var t0 = Time.get_ticks_msec()
	var fuel_dry = {}
	while not G.over and G.sim_time < cap:
		await _wait(5.0)
		for v in G.vehicles:
			if not v.dead and v.fuel <= 0.0 and not v.spec.get("static", false) and not v.spec.get("air", false):
				fuel_dry[v.get_instance_id()] = true
	var k = [0, 0]
	for s in G.soldiers:
		if s.state == "dead" and s.team < 2:
			k[1 - s.team] += 1
	var vl = [0, 0]
	for v in G.vehicles:
		if v.dead and v.team >= 0 and v.team < 2:
			vl[v.team] += 1
	var styles = "%s/%s" % [Commander.style_of(0), Commander.style_of(1)]
	print("BALANCE mode=%s map=%s seed=%d win=%d t=%d real=%ds score=%s kills=%d/%d vlost=%d/%d styles=%s flips=%d(s%d/t%d/b%d) dry=%d cook=%d drums=%d trees=%d feint=%d regroup=%d counter=%d adapt=%d toss=%d stuck=%d losses=%s" % [
		mode, G.map_id, seed_, G.win_team, int(G.sim_time), (Time.get_ticks_msec() - t0) / 1000, str(G.cap_score if mode != "deathmatch" else G.score),
		k[0], k[1], vl[0], vl[1], styles, G.bal.get("flip", 0), G.bal.get("flip_slope", 0), G.bal.get("flip_turn", 0), G.bal.get("flip_blast", 0), fuel_dry.size(), G.bal.get("cook", 0), G.bal.get("drum", 0), G.bal.get("tree", 0),
		Commander.events["feint"], Commander.events["regroup"], Commander.events["counter"], Ops.events.get("adapt", 0), G.bal.get("toss", 0), _stuck_count(), str(Ops.losses.slice(0, 2)).replace(" ", "")])
	get_tree().quit()

# the battle builder: squads put down for both sides hold still, then fight once Start is pressed
func _builder_test(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	await _wait(0.3)
	G.ui.builder_next = true
	start_game({"map": _arg("map", "field"), "mode": "capture", "size": 8, "limit": 999, "reinforce": true, "armor": "heavy", "teams": 2})
	await _wait(0.5)
	var c: Vector3 = G.world.capture
	var men = []
	for t in [0, 1]:
		var side = -1.0 if t == 0 else 1.0
		for k in range(6):
			var p = _free_spot(c + Vector3(side * 35.0, 0, -10.0 + k * 4.0))
			var sx = spawn_soldier(t, p.x, p.z, "")
			if sx != null:
				men.append(sx)
		var mg = Build.find_spot(c + Vector3(side * 30.0, 0, 8.0), "mgnest", 10.0, 20, true)
		if mg != null:
			Build.place("mgnest", t, mg, Vector3(-side, 0, 0), true)
	var p0 = men.map(func(m): return m.pos)
	print("BUILDERTEST builder ", G.builder, " soldiers ", G.soldiers.size(), " size_mode ", G.mode, " bar ", G.ui.builder_bar != null and G.ui.builder_bar.visible)
	await _wait(10.0)
	var moved = 0.0
	for i in range(men.size()):
		if is_instance_valid(men[i]):
			moved = maxf(moved, G.dist2d(men[i].pos, p0[i]))
	print("BUILDERTEST held: kills ", G.score, " max moved ", moved)
	await _snap(dir, "builder_set")
	builder_start()
	await _wait(35.0)
	var dead = G.soldiers.filter(func(x): return x.state == "dead").size()
	print("BUILDERTEST after start: builder ", G.builder, " dead ", dead, " score ", G.score)
	await _snap(dir, "builder_fight")
	get_tree().quit()

# a jeep thrown over by a shell, fuel drums going up one after another, a tree crashing down
func _phys_shot(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	G.settings["time"] = "day"
	apply_time()
	await _wait(0.3)
	start_game({"map": _arg("map", "field"), "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2, "armies": false})
	await _wait(0.5)
	G.pc.force_free = true
	var c: Vector3 = _free_spot(G.world.capture + Vector3(10, 0, 10))
	var jeep = spawn_vehicle("jeep", 0, c, 0.0, true)
	var dp = _free_spot(c + Vector3(9, 0, 3))
	G.world.build_now(func(): G.world.fuel_drums(dp.x, dp.z, 3))
	G.world.build_now(func(): G.world.fuel_drums(dp.x + 2.4, dp.z + 0.5, 2))
	var tree = null
	var td = 1e9
	for col in G.world.cols:
		if col.alive and col.has_meta("tree"):
			var d = G.dist2d((col.lo + col.hi) * 0.5, c)
			if d < td:
				td = d
				tree = col
	await _wait(1.0)
	var drums0 = G.world.cols.filter(func(x): return x.alive and x.has_meta("boom")).size()
	await _look(c + Vector3(-14, 6, -10), c + Vector3(3, 1, 2))
	Combat.explode(jeep.pos + Vector3(-2.0, 0.3, 0.5), null, 1.3)
	Combat.explode(dp, null, 0.8)
	await _wait(0.6)
	await _snap(dir, "flip_mid")
	await _wait(2.5)
	await _snap(dir, "flip_after")
	var drums1 = G.world.cols.filter(func(x): return x.alive and x.has_meta("boom")).size()
	print("PHYSSHOT jeep flipped ", jeep.has_meta("flipped"), " dead ", jeep.dead, " drums ", drums0, "->", drums1, " tree at ", td)
	if tree != null:
		var tp: Vector3 = (tree.lo + tree.hi) * 0.5
		tree.set_meta("fall", Vector3(1, 0, 0.3).normalized())
		await _look(tp + Vector3(-3, 4, -12), tp + Vector3(2, 1.5, 0))
		G.world.destroy_col(tree)
		await _wait(0.6)
		await _snap(dir, "tree_falling")
		await _wait(2.0)
		await _snap(dir, "tree_down")
		print("PHYSSHOT logs ", G.world.cols.filter(func(x): return x.alive and x.has_meta("log")).size())
	get_tree().quit()

# a truck sent to hitch up an anti-tank gun, then driven off with it
func _tow_test() -> void:
	G.settings["time"] = "day"
	apply_time()
	await _wait(0.3)
	start_game({"map": "field", "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2, "armies": false})
	await _wait(0.5)
	var c: Vector3 = _free_spot(G.world.rally_point(0))
	var tr = spawn_vehicle("truck", 0, c, 0.0, true)
	var gun = spawn_vehicle("atgun", 0, _free_spot(c + Vector3(25, 0, 10)), 0.0, false)
	await _wait(1.0)
	print("TOWTEST order: ", VehExt.order_tow(tr), " driver ", tr.driver() != null)
	for k in range(30):
		await _wait(1.0)
		if tr.towing != null:
			break
	print("TOWTEST hitched ", tr.towing == gun, " dist ", G.dist2d(tr.pos, gun.pos))
	tr.command(tr.pos + Vector3(-40, 0, -20))
	await _wait(15.0)
	print("TOWTEST after drive: towing ", tr.towing == gun, " gap ", G.dist2d(tr.pos, gun.pos), " bar ", tr.has_meta("tow_bar"), " moved ", G.dist2d(gun.pos, c + Vector3(25, 0, 10)))
	print("TOWTEST unhitch: ", VehExt.order_tow(tr), " bar ", tr.has_meta("tow_bar"))
	get_tree().quit()

# the title screen with its little battle going on behind
func _attract_shot(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	await _wait(0.5)
	start_attract()
	await _wait(float(_arg("secs", "25")))
	print("ATTRACT started ", G.started, " attract ", G.attract, " soldiers ", G.soldiers.size(), " root ", G.ui.root.visible, " title ", G.ui.title.visible)
	await _snap(dir, "title")
	await _wait(6.0)
	await _snap(dir, "title2")
	G.ui._show_settings()
	await _wait(0.5)
	print("ATTRACT settings root ", G.ui.root.visible)
	await _snap(dir, "settings")
	get_tree().quit()

# effects up close: a machine gun's tracers from commander height, a shot-up truck, a flare at night
func _fx_shot(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	G.settings["time"] = _arg("time", "dusk")
	apply_time()
	await _wait(0.5)
	start_game({"map": _arg("map", "field"), "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2, "armies": false})
	await _wait(0.5)
	G.pc.force_free = true
	var c: Vector3 = _free_spot(G.world.capture)
	var gunner = spawn_soldier(0, c.x - 30.0, c.z, "lmg")
	var targ = []
	for k in range(4):
		var t = spawn_soldier(1, c.x + 25.0, c.z - 6.0 + k * 4.0, "rifle")
		t.hp = 9999.0
		targ.append(t)
	var tr = spawn_vehicle("truck", 1, _free_spot(c + Vector3(5, 0, 12)), 0.0, false)
	await _wait(1.0)
	for k in range(30):
		Combat.fire_ray(gunner, tr.center() + Vector3(-12, 0, randf_range(-2, 2)), (tr.center() + Vector3(randf_range(-1.5, 1.5), randf_range(-0.6, 0.4), randf_range(-1.5, 1.5)) - (tr.center() + Vector3(-12, 0, 0))).normalized(), G.WEAPONS["hmg"], true)
	tr.take_damage(90.0, gunner, tr.center() + Vector3(-1, 0.3, 0))
	gunner.order = {"mode": "hold", "point": gunner.pos}
	await _wait(2.5)
	await _look(c + Vector3(-5, 70, 30), c)
	var g0: Vector3 = c + Vector3(-30, 1.2, -4)
	for f in range(36):
		Combat.bright = f % 4 == 0
		var tgt: Vector3 = c + Vector3(25, 1.0, randf_range(-8, 8))
		Combat.fire_ray(targ[0], g0, (tgt - g0).normalized(), G.WEAPONS["lmg"], true)
		Combat.bright = false
		await get_tree().physics_frame
		await get_tree().physics_frame
	print("FXSHOT tracers ", G.fx.tracers.size(), " bright ", G.fx.tracers.filter(func(t): return t.has("bright")).size(), " lens ", G.fx.tracers.map(func(t): return int(t["len"])))
	await _snap(dir, "tracers_high")
	await _look(tr.center() + Vector3(-6, 1.5, 3), tr.center())
	await _wait(0.3)
	await _snap(dir, "truck_holes")
	print("FXSHOT holes ", tr.get_meta("holes", []).size(), " flares ", Combat.flares.size())
	G.settings["time"] = "night"
	apply_time()
	Combat.flare(c, c + Vector3(10, 0, 0))
	await _wait(5.0)
	await _look(c + Vector3(-30, 8, 30), c + Vector3(10, 10, 0))
	await _snap(dir, "flare")
	get_tree().quit()

# camo nets thrown over a few finished structures, from two angles
func _camo_shot(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	G.settings["time"] = "day"
	apply_time()
	await _wait(0.5)
	start_game({"map": _arg("map", "field"), "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2, "armies": false})
	await _wait(0.5)
	G.pc.force_free = true
	var c: Vector3 = G.world.rally_point(0)
	var fw = G.flat(G.world.capture - c).normalized()
	var side = Vector3(fw.z, 0, -fw.x)
	var made = []
	var k = 0
	for kind in ["fob2", "mgnest", "depot", "mortarpit"]:
		var sp = Build.find_spot(c + side * (k - 1.5) * 13.0 + fw * 8.0, kind, 12.0, 40, true)
		if sp != null:
			var st = Build.place(kind, 0, sp, fw, true)
			if st != null:
				made.append(st)
		k += 1
	await _wait(0.5)
	for st in made:
		Build.add_camo(st)
	print("CAMOSHOT nets ", made.size())
	await _wait(0.5)
	await _look(c - fw * 14.0 + Vector3(0, 9.0, 0), c + fw * 8.0)
	await _wait(0.5)
	await _snap(dir, "camo_wide")
	if not made.is_empty():
		var p: Vector3 = made[0]["p"]
		await _look(p - fw * 9.0 + side * 6.0 + Vector3(0, 3.5, 0), p)
		await _wait(0.5)
		await _snap(dir, "camo_hut")
	if made.size() > 1:
		var p2: Vector3 = made[1]["p"]
		await _look(p2 - fw * 7.0 - side * 5.0 + Vector3(0, 3.0, 0), p2)
		await _wait(0.5)
		await _snap(dir, "camo_nest")
	get_tree().quit()

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

# a man shot in the leg gets walked back by a mate; a grenade thrown with the full wind-up; a mag handed over
func _help_test(dir: String) -> void:
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)
	G.settings["time"] = "day"
	apply_time()
	await _wait(0.5)
	start_game({"map": "field", "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2, "armies": false})
	await _wait(0.5)
	G.pc.force_free = true
	var c: Vector3 = _free_spot(G.world.capture + Vector3(-40, 0, 0))
	var men = []
	for k in range(3):
		men.append(spawn_soldier(0, c.x + k * 1.5, c.z, "rifle"))
	force_cls = ["medic"]
	var med = spawn_soldier(0, c.x - 30.0, c.z + 4.0, "")
	force_cls = []
	await _wait(1.0)
	var w = men[0]
	w.hp = 55.0
	w.set_meta("leg_wound", true)
	var p0 = w.pos
	var helped = false
	for k in range(12):
		await _wait(1.0)
		if w.has_meta("helper"):
			helped = true
			if dir != "" and k == 4:
				var h = w.get_meta("helper")
				await _look(w.pos + Vector3(3.5, 1.6, 3.0), (w.pos + h.pos) * 0.5 + Vector3(0, 1.0, 0))
				await _snap(dir, "helpwalk")
	print("HELPTEST tasks ", men.map(func(x): return str(x.task)))
	print("HELPTEST helped %s moved %.1f m toward medic (dist now %.1f) helper task %s" % [str(helped), G.dist2d(w.pos, p0), G.dist2d(w.pos, med.pos), str(w.get_meta("helper").task) if w.has_meta("helper") and is_instance_valid(w.get_meta("helper")) else "-"])
	# a throw
	var t = men[2]
	var g0 = G.grenades.size()
	t.grenades = 1
	Combat.throw_grenade(t, t.pos + Vector3(20, 0, 0), "frag")
	await _wait(0.3)
	var mid = G.grenades.size()
	if dir != "":
		await _look(t.pos + Vector3(0.5, 1.6, 4.0), t.pos + Vector3(0, 1.2, 0))
		await _snap(dir, "throw_windup")
	await _wait(0.7)
	print("HELPTEST grenade: in the air after 0.3 s %d, after 1.0 s %d" % [mid - g0, G.grenades.size() - g0])
	# a hand-off
	var a = men[1]
	var b = spawn_soldier(0, a.pos.x + 1.2, a.pos.z, "rifle")
	await _wait(0.3)
	b.reserve = 0
	b.mag = 2
	a.reserve = a.W["mag"] * 5
	var r0 = b.reserve
	await _wait(4.0)
	print("HELPTEST handoff: receiver reserve %d -> %d" % [r0, b.reserve])
	get_tree().quit()

# vehicles crossing each other's path in both directions: how many get where they were sent
func _jam_test() -> void:
	await _wait(0.5)
	start_game({"map": _arg("map", "field"), "mode": "sandbox", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2, "armies": false})
	await _wait(0.5)
	var a: Vector3 = _free_spot(G.world.rally_point(0))
	var b: Vector3 = _free_spot(a + G.flat(G.world.capture - a).normalized() * 70.0)
	var side = G.flat(b - a).normalized()
	side = Vector3(side.z, 0, -side.x)
	var kinds = ["truck", "supplytruck", "jeep", "tank", "ammotruck", "halftrack"]
	var vs = []
	for k in range(kinds.size()):
		var from = a if k % 2 == 0 else b
		var to = b if k % 2 == 0 else a
		var p0 = _free_spot(from + side * ((k / 2) - 1) * 6.0)
		var v = spawn_vehicle(kinds[k], 0, p0, atan2(to.x - p0.x, to.z - p0.z))
		vs.append([v, _free_spot(to + side * ((k / 2) - 1) * 4.0), 0.0])
	await _wait(1.0)
	for e in vs:
		e[0].command(e[1])
	var t = 0.0
	while t < float(_arg("secs", "90")):
		await _wait(1.0)
		t += 1.0
		for e in vs:
			if e[2] == 0.0 and is_instance_valid(e[0]) and G.dist2d(e[0].pos, e[1]) < 12.0:
				e[2] = t
		if int(t) % 15 == 0:
			var st = []
			for e in vs:
				st.append("%s %.0fm %s" % [e[0].kind, G.dist2d(e[0].pos, e[1]), e[0].why])
			print("JAMTEST t%d " % int(t), ", ".join(st))
	var got = vs.filter(func(e): return e[2] > 0.0)
	print("JAMTEST arrived %d of %d, times %s" % [got.size(), vs.size(), str(vs.map(func(e): return int(e[2])))])
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
