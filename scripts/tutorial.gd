class_name Tutorial
# The first battle: a small guided fight that teaches the handful of things you need before a real one.
# Selecting, sending men somewhere, moving the view, attacking, calling fire support, buying more men.
# The enemy here stands still and has no commander; each step waits until you've done the thing (or you
# press Skip), then sets up the next.

static var on = false
static var step_i = -1
static var t_step = 0.0
static var panel: PanelContainer = null
static var head: Label = null
static var body: Label = null
static var mark: Node3D = null
static var foes: Array = []
static var d = {}

const STEPS = [
	["Select your squad", "Drag a box round your men with the left mouse button (or double-click one of them). Their names light up when they're selected."],
	["Send them somewhere", "With the squad selected, right-click on the ground inside the yellow ring. They'll find their own way and their own cover."],
	["Look around", "Pan the view with W A S D, zoom with the mouse wheel (it zooms toward the pointer), and turn it with Q and E. Do each once."],
	["Attack", "An enemy section is holding the red ring. Right-click near them to send your squad in: your men open fire by themselves once they can see the enemy. The cards on the left tell you what each squad is doing."],
	["Call fire support", "More of them, dug in behind sandbags. Don't walk into that. At the bottom of the screen open Fire support, pick Artillery barrage, and click on the red ring. Then send your men in to finish it."],
	["Buy more men", "Supply points pay for everything. Open Recruit, pick Rifle squad, then click near your men: they come up by lorry from the edge of the map."],
	["That's all you need", "Their headquarters is at the far end of the field: destroy it and you've won. In a real battle the enemy has a commander of his own and won't wait for you. Press M for the menu whenever you like."]]

static var starting = false

static func start() -> void:
	stop()
	starting = true
	G.tutorial = true
	step_i = -1
	foes = []
	d = {}
	G.main.start_game({"map": "field", "mode": "commander", "size": 0, "limit": 999, "reinforce": false, "armor": "none", "teams": 2, "armies": false})
	starting = false
	G.tutorial = true
	on = true
	Support.points[0] = 10
	var home: Vector3 = G.world.rally_point(0)
	var to = G.flat(G.world.capture - home).normalized()
	for i in range(6):
		var p: Vector3 = G.main._free_spot(home + to * 6.0 + Vector3(-to.z, 0, to.x) * (i - 2.5) * 1.6)
		G.main.spawn_soldier(0, p.x, p.z, "rifle" if i != 3 else "")
	_stand_fast()
	d["home"] = home
	d["to"] = to
	d["p1"] = G.main._free_spot(home + to * 38.0)
	d["p2"] = G.main._free_spot(home + to * 90.0)
	d["p3"] = G.main._free_spot(home + to * 148.0)
	G.pc.selection.clear()
	# (the view starts on the squad itself, clear of the buttons along the bottom)
	G.pc.rts_focus = home + to * 12.0
	G.pc.rts_dist = 42.0
	G.pc.rcam_ok = false
	_build_panel()
	_next()

# fresh men at the start line when the squad's been shot to pieces, so nobody's left with nothing to do
static func _top_up() -> void:
	var home: Vector3 = d["home"]
	var to: Vector3 = d["to"]
	for i in range(6):
		var p: Vector3 = G.main._free_spot(home + to * 8.0 + Vector3(-to.z, 0, to.x) * (i - 2.5) * 1.6)
		G.main.spawn_soldier(0, p.x, p.z, "rifle")
	_stand_fast()
	G.ui.message("Your squad's taken a beating: six fresh men have come up at your headquarters")

# Men with no orders go and find the battle by themselves, which is no good while somebody is still reading
# how to select them: in the lesson they wait where they are until they're sent somewhere.
static func _stand_fast() -> void:
	for s in G.soldiers:
		if s.team == 0 and s.state == "alive" and s.order == null:
			s.order = {"mode": "hold", "point": s.pos}

static func stop() -> void:
	on = false
	G.tutorial = false
	if panel != null and is_instance_valid(panel):
		panel.queue_free()
		if G.ui != null and G.ui.msg != null and is_instance_valid(G.ui.msg):
			G.ui._place(G.ui.msg, Control.PRESET_CENTER_TOP, -260, 200, 520, 40)
	panel = null
	if mark != null and is_instance_valid(mark):
		mark.queue_free()
	mark = null

static func _build_panel() -> void:
	if panel != null and is_instance_valid(panel):
		panel.queue_free()
	panel = G.ui._panel(Color(0.05, 0.06, 0.07, 0.9))
	# (under the supply line, and the game's own messages are moved down out from behind it)
	G.ui._place(panel, Control.PRESET_CENTER_TOP, -290, 102, 580, 110)
	G.ui._place(G.ui.msg, Control.PRESET_CENTER_TOP, -260, 272, 520, 40)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	head = G.ui._label("", 13, Color(1.0, 0.78, 0.3))
	body = G.ui._label("", 15)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(548, 0)
	var row = HBoxContainer.new()
	var sp = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var skip = G.ui._button("Skip this step", func(): Tutorial._next())
	skip.custom_minimum_size = Vector2(120, 26)
	var quit = G.ui._button("End the lesson", func(): Tutorial.stop())
	quit.custom_minimum_size = Vector2(120, 26)
	row.add_child(sp)
	row.add_child(quit)
	row.add_child(skip)
	v.add_child(head)
	v.add_child(body)
	v.add_child(row)
	panel.add_child(v)
	G.ui.root.add_child(panel)

static func _marker(p, col: Color) -> void:
	if mark != null and is_instance_valid(mark):
		mark.queue_free()
	mark = null
	if p == null:
		return
	mark = Node3D.new()
	var mat = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var ring = MeshInstance3D.new()
	var tm = TorusMesh.new()
	tm.inner_radius = 5.4
	tm.outer_radius = 6.0
	ring.mesh = tm
	ring.material_override = mat
	ring.scale = Vector3(1, 0.15, 1)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mark.add_child(ring)
	var beam = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.12
	cm.bottom_radius = 0.12
	cm.height = 16.0
	beam.mesh = cm
	var bm = mat.duplicate()
	bm.albedo_color = Color(col.r, col.g, col.b, 0.45)
	beam.material_override = bm
	beam.position = Vector3(0, 8.0, 0)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mark.add_child(beam)
	G.main.add_child(mark)
	mark.global_position = Vector3(p.x, G.world.ground_y(p.x, p.z) + 0.2, p.z)

static func _spawn_foes(p: Vector3, n: int, dug: bool) -> void:
	foes = []
	var to: Vector3 = d["to"]
	var side = Vector3(-to.z, 0, to.x)
	if dug:
		G.world.sandbags(p.x - to.x * 2.2, p.z - to.z * 2.2, 9.0, absf(to.z) > absf(to.x), 1.0)
		G.world.update_nav_area(p.x - 8.0, p.z - 8.0, p.x + 8.0, p.z + 8.0)
	for i in range(n):
		var q: Vector3 = G.main._free_spot(p + side * (i - (n - 1) * 0.5) * 1.8 + to * (0.6 if dug else 0.0))
		var s = G.main.spawn_soldier(1, q.x, q.z, "rifle")
		if s != null:
			s.order = {"mode": "hold", "point": s.pos}
			# (rifles only: one rifle grenade into a squad standing close together ended the lesson's
			# first fight in a second)
			s.rgren = 0
			s.grenades = 0
			s.fausts = 0
			s.set_meta("tut_post", s.pos)
			s.body_yaw = atan2(-to.x, -to.z)
			s.aim_yaw = s.body_yaw
			foes.append(s)

# Bring the squad and the ring it's being sent to into the view together, below the lesson's panel.
static func _frame(p: Vector3) -> void:
	var men = _mine()
	var c: Vector3 = d["home"]
	if not men.is_empty():
		c = Vector3.ZERO
		for s in men:
			c += s.pos
		c /= float(men.size())
	var gap = G.dist2d(c, p)
	G.pc.rts_focus = c.lerp(p, 0.46)
	G.pc.rts_yaw = atan2(p.x - c.x, p.z - c.z) if gap > 2.0 else G.pc.rts_yaw
	G.pc.rts_dist = clampf(gap * 1.9 + 6.0, 50.0, 135.0)

static func _mine() -> Array:
	# (a man knocked off his feet is still one of yours: only the dead and the wounded are out of it)
	return G.soldiers.filter(func(s): return s.team == 0 and s.state in ["alive", "down", "getup", "riding"])

static func _next() -> void:
	if not on:
		return
	step_i += 1
	t_step = 0.0
	if step_i >= STEPS.size():
		step_i = STEPS.size() - 1
	head.text = "FIRST BATTLE  ·  %d of %d  ·  %s" % [step_i + 1, STEPS.size(), STEPS[step_i][0].to_upper()]
	body.text = STEPS[step_i][1]
	G.audio.order_tick(true)
	match step_i:
		0:
			_marker(null, Color.WHITE)
		1:
			_marker(d["p1"], Color(1.0, 0.85, 0.2, 0.9))
			_frame(d["p1"])
		2:
			_marker(null, Color.WHITE)
			d["cam0"] = [G.pc.rts_focus, G.pc.rts_dist, G.pc.rts_yaw]
			d["cam_done"] = [false, false, false]
		3:
			_spawn_foes(d["p2"], 5, true)
			_marker(d["p2"], Color(1.0, 0.25, 0.2, 0.9))
			_frame(d["p2"])
		4:
			_spawn_foes(d["p3"], 7, true)
			_marker(d["p3"], Color(1.0, 0.25, 0.2, 0.9))
			_frame(d["p3"])
			Support.points[0] = maxi(Support.points[0], 45)
			d["strikes0"] = Support.missions.size()
			d["struck_t"] = -1.0
		5:
			_marker(null, Color.WHITE)
			Support.points[0] = maxi(Support.points[0], 40)
			d["pts0"] = Support.points[0]
			d["men0"] = G.soldiers.filter(func(s): return s.team == 0).size()
		6:
			_marker(null, Color.WHITE)
			Support.points[0] = maxi(Support.points[0], 60)

static func step(dt: float) -> void:
	if not on:
		return
	if not G.started or G.over or panel == null or not is_instance_valid(panel):
		if G.over or not G.started:
			stop()
		return
	t_step += dt
	if mark != null and is_instance_valid(mark):
		var k = 1.0 + 0.06 * sin(G.sim_time * 4.0)
		mark.scale = Vector3(k, 1.0, k)
	# (a man knocked flat by a shell isn't out of it: he's still the enemy until he's dead or lying wounded)
	var live = foes.filter(func(s): return is_instance_valid(s) and s.state in ["alive", "down", "getup"])
	# the enemy here holds his ground: anyone who's wandered off his post is sent back to it
	d["leash_t"] = float(d.get("leash_t", 0.0)) - dt
	if d["leash_t"] <= 0.0:
		d["leash_t"] = 1.0
		for f in live:
			var post: Vector3 = f.get_meta("tut_post", f.pos)
			if f.state == "alive" and G.dist2d(f.pos, post) > 7.0 and f.vis_t == null:
				f.order = {"mode": "hold", "point": post}
				f.task = null
				AI.go_to(f, post, 4.0)
		if step_i in [3, 4] and _mine().size() < 3 and t_step > 3.0 and G.sim_time > float(d.get("top_t", 0.0)):
			d["top_t"] = G.sim_time + 20.0
			_top_up()
	match step_i:
		0:
			if G.pc.selection.size() >= 4 and t_step > 0.8:
				_next()
		1:
			var near = _mine().filter(func(s): return G.dist2d(s.pos, d["p1"]) < 9.0).size()
			if near >= 3:
				_next()
		2:
			var c0: Array = d["cam0"]
			var done: Array = d["cam_done"]
			done[0] = done[0] or G.dist2d(G.pc.rts_focus, c0[0]) > 12.0
			done[1] = done[1] or absf(G.pc.rts_dist - c0[1]) > 4.0
			done[2] = done[2] or absf(G.wrap_a(G.pc.rts_yaw - c0[2])) > 0.3
			body.text = STEPS[2][1] + "\n%s pan    %s zoom    %s turn" % ["[done]" if done[0] else "[  ]", "[done]" if done[1] else "[  ]", "[done]" if done[2] else "[  ]"]
			if done[0] and done[1] and done[2]:
				_next()
		3:
			if live.is_empty() and t_step > 6.0:
				_next()
		4:
			if d["struck_t"] < 0.0 and Support.missions.size() > d["strikes0"] or (d["struck_t"] < 0.0 and Combat.strikes.size() > 0):
				d["struck_t"] = G.sim_time
				body.text = "Rounds on the way. When they've landed, send your squad in to clear what's left."
			if live.size() <= 0 and t_step > 2.0:
				_next()
		5:
			if Support.points[0] <= d["pts0"] - 10 or G.soldiers.filter(func(s): return s.team == 0).size() >= d["men0"] + 4:
				_next()
		_:
			pass
