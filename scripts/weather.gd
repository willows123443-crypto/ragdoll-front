class_name Weather
# What the weather looks like: rain (streaks falling through the view, puddles pocked by the drops, roads
# wet and shining) and cold (breath in the air, a pale haze). Looks only: it changes nothing about the fight
# (a campaign storm still grounds aircraft and shortens sight, as before, and now it rains properly too).

static var kind = "clear"            # "clear", "rain" or "cold"
static var root: Node3D = null
static var puddles: Array = []       # [centre, radius]
static var rip_mm: MultiMesh = null
static var rips: Array = []          # [age, life, pos, size]
static var rip_i = 0
static var puff_mm: MultiMesh = null
static var puffs: Array = []         # [age, life, pos, vel, size]
static var puff_i = 0
static var drop_t = 0.0
static var breath_t = 0.0
const RIPS = 28
const PUFFS = 96

static func wanted() -> String:
	if G.storm:
		return "rain"
	return G.settings.get("weather", "clear")

static func reset() -> void:
	if root != null and is_instance_valid(root):
		root.queue_free()
	root = null
	puddles.clear()
	rips.clear()
	puffs.clear()
	rip_mm = null
	puff_mm = null
	kind = "clear"

# once the map is built (and again if the weather is changed)
static func apply() -> void:
	reset()
	kind = wanted()
	if G.fx != null:
		G.fx.set_storm(kind == "rain")
	if G.world == null or kind == "clear":
		return
	root = Node3D.new()
	root.name = "Weather"
	G.main.add_child(root)
	if kind == "rain":
		_wet_roads()
		_puddles()
		_ripple_pool()
	else:
		_puff_pool()

static func _hidden() -> Transform3D:
	return Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0, -500, 0))

# every road gets a dark wet sheen over it that catches the light
static func _wet_roads() -> void:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.06, 0.08, 0.3)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.1
	mat.metallic = 0.25
	mat.metallic_specular = 1.0
	for rd in G.world.roads:
		var w: float = rd[1] - rd[0]
		var d: float = rd[3] - rd[2]
		if w < 1.0 or d < 1.0:
			continue
		var m = MeshInstance3D.new()
		var pm = PlaneMesh.new()
		pm.size = Vector2(w, d)
		m.mesh = pm
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var cx: float = (rd[0] + rd[1]) * 0.5
		var cz: float = (rd[2] + rd[3]) * 0.5
		m.position = Vector3(cx, G.world.ground_y(cx, cz) + 0.06, cz)
		root.add_child(m)

static func _level(x: float, z: float, r: float) -> bool:
	var y0: float = G.world.ground_y(x, z)
	for o in [Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
		if absf(G.world.ground_y(x + o.x, z + o.y) - y0) > 0.05:
			return false
	return true

# standing water wherever the ground is level: along the road edges mostly, and out in the open
static func _puddles() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 4177
	var b: Rect2 = G.world.bounds
	var roads: Array = G.world.roads
	var tries = 0
	while puddles.size() < 110 and tries < 900:
		tries += 1
		var x = rng.randf_range(b.position.x + 4.0, b.end.x - 4.0)
		var z = rng.randf_range(b.position.y + 4.0, b.end.y - 4.0)
		var r = rng.randf_range(0.6, 1.9)
		if not roads.is_empty() and tries % 2 == 0:
			var rd = roads[rng.randi() % roads.size()]
			var along_x = (rd[1] - rd[0]) > (rd[3] - rd[2])
			if along_x:
				x = rng.randf_range(rd[0], rd[1])
				z = (rd[2] if rng.randf() < 0.5 else rd[3]) + rng.randf_range(-1.6, 1.6)
			else:
				z = rng.randf_range(rd[2], rd[3])
				x = (rd[0] if rng.randf() < 0.5 else rd[1]) + rng.randf_range(-1.6, 1.6)
			r = rng.randf_range(0.5, 1.4)
		if not b.has_point(Vector2(x, z)) or not _level(x, z, r):
			continue
		if G.world.in_water(x, z) or G.world.inside_any(x, z, r):
			continue
		var crowded = false
		for p in puddles:
			if G.dist2d(p[0], Vector3(x, 0, z)) < p[1] + r:
				crowded = true
				break
		if crowded:
			continue
		puddles.append([Vector3(x, G.world.ground_y(x, z) + 0.035, z), r])
	if puddles.is_empty():
		return
	# a soft-edged, slightly lumpy pool shape
	var sz = 64
	var img = Image.create_empty(sz, sz, false, Image.FORMAT_RGBA8)
	for y in range(sz):
		for x in range(sz):
			var v = Vector2(x - sz / 2.0 + 0.5, y - sz / 2.0 + 0.5) / (sz / 2.0)
			var ang = atan2(v.y, v.x)
			var edge = 0.78 + 0.1 * sin(ang * 3.0 + 0.7) + 0.06 * sin(ang * 5.0 + 2.1)
			var a = clampf((edge - v.length()) / 0.14, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.albedo_color = Color(0.05, 0.06, 0.08, 0.82)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.03
	mat.metallic = 0.45
	mat.metallic_specular = 1.0
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var pm = PlaneMesh.new()
	pm.size = Vector2(2, 2)
	mm.mesh = pm
	mm.instance_count = puddles.size()
	for i in range(puddles.size()):
		var p = puddles[i]
		var bs = Basis(Vector3.UP, rng.randf() * TAU).scaled_local(Vector3(p[1], 1.0, p[1] * rng.randf_range(0.6, 1.0)))
		mm.set_instance_transform(i, Transform3D(bs, p[0]))
	var mi = MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)

static func _ring_tex() -> ImageTexture:
	var sz = 48
	var img = Image.create_empty(sz, sz, false, Image.FORMAT_RGBA8)
	for y in range(sz):
		for x in range(sz):
			var d = Vector2(x - sz / 2.0 + 0.5, y - sz / 2.0 + 0.5).length() / (sz / 2.0)
			var a = clampf(1.0 - absf(d - 0.8) / 0.14, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)

static func _ripple_pool() -> void:
	rip_mm = MultiMesh.new()
	rip_mm.transform_format = MultiMesh.TRANSFORM_3D
	rip_mm.use_colors = true
	var pm = PlaneMesh.new()
	pm.size = Vector2(2, 2)
	rip_mm.mesh = pm
	rip_mm.instance_count = RIPS
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = _ring_tex()
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rips.clear()
	for i in range(RIPS):
		rips.append([9.0, 0.5, Vector3.ZERO, 0.3])
		rip_mm.set_instance_transform(i, _hidden())
		rip_mm.set_instance_color(i, Color(1, 1, 1, 0))
	var mi = MultiMeshInstance3D.new()
	mi.multimesh = rip_mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-600, -50, -600), Vector3(1200, 200, 1200))
	root.add_child(mi)

static func _puff_pool() -> void:
	puff_mm = MultiMesh.new()
	puff_mm.transform_format = MultiMesh.TRANSFORM_3D
	puff_mm.use_colors = true
	var q = QuadMesh.new()
	q.size = Vector2(1, 1)
	puff_mm.mesh = q
	puff_mm.instance_count = PUFFS
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = G.fx.soft_tex
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	puffs.clear()
	for i in range(PUFFS):
		puffs.append([9.0, 1.0, Vector3.ZERO, Vector3.ZERO, 0.1])
		puff_mm.set_instance_transform(i, _hidden())
		puff_mm.set_instance_color(i, Color(1, 1, 1, 0))
	var mi = MultiMeshInstance3D.new()
	mi.multimesh = puff_mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-600, -50, -600), Vector3(1200, 200, 1200))
	root.add_child(mi)

static func _breath(s) -> void:
	var hp: Vector3 = s.P[0] if s.P.size() > 0 else s.pos + Vector3(0, 1.6, 0)
	var f = Vector3(sin(s.aim_yaw), 0, cos(s.aim_yaw))
	puffs[puff_i] = [0.0, randf_range(0.9, 1.3), hp + f * 0.16 - Vector3(0, 0.05, 0), f * randf_range(0.35, 0.6) + Vector3(0, 0.12, 0) + Vector3(s.vel.x, 0, s.vel.z) * 0.4, randf_range(0.12, 0.18)]
	puff_i = (puff_i + 1) % PUFFS

static func step(dt: float) -> void:
	if root == null or not is_instance_valid(root):
		return
	var cam = G.main.get_viewport().get_camera_3d()
	if cam == null:
		return
	if kind == "rain" and rip_mm != null:
		# drops landing in the puddles nearest the view
		drop_t -= dt
		if drop_t <= 0.0 and not puddles.is_empty():
			drop_t = 0.045
			var cp: Vector3 = cam.global_position - cam.global_transform.basis.z * 18.0
			for k in range(3):
				var p = puddles[randi() % puddles.size()]
				if G.dist2d(p[0], cp) < 70.0:
					var ang = randf() * TAU
					var rr = randf() * p[1] * 0.6
					rips[rip_i] = [0.0, randf_range(0.45, 0.7), p[0] + Vector3(cos(ang) * rr, 0.012, sin(ang) * rr), randf_range(0.14, 0.3)]
					rip_i = (rip_i + 1) % RIPS
					break
		for i in range(RIPS):
			var r = rips[i]
			if r[0] >= r[1]:
				continue
			r[0] += dt
			var k = clampf(r[0] / r[1], 0.0, 1.0)
			if k >= 1.0:
				rip_mm.set_instance_transform(i, _hidden())
				continue
			var sc: float = r[3] * (0.25 + 0.75 * k)
			rip_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(sc, 1.0, sc)), r[2]))
			rip_mm.set_instance_color(i, Color(0.85, 0.9, 0.95, 0.5 * (1.0 - k)))
	elif kind == "cold" and puff_mm != null:
		# breath: every man near the view, each in his own time (quicker when he's been running)
		breath_t -= dt
		if breath_t <= 0.0:
			breath_t = 0.2
			var cp: Vector3 = cam.global_position
			for s in G.soldiers:
				if s.state != "alive" or s.zombie or s.hidden_in_vehicle or s.lod_frozen:
					continue
				if s.pos.distance_squared_to(cp) > 60.0 * 60.0:
					continue
				var period = 3.2 - minf(Vector2(s.vel.x, s.vel.z).length(), 5.0) * 0.32
				var ph = fmod(G.sim_time + float(s.id) * 0.731, period)
				if ph < 0.6:
					_breath(s)
		for i in range(PUFFS):
			var p = puffs[i]
			if p[0] >= p[1]:
				continue
			p[0] += dt
			var k = clampf(p[0] / p[1], 0.0, 1.0)
			if k >= 1.0:
				puff_mm.set_instance_transform(i, _hidden())
				continue
			p[2] += p[3] * dt
			p[3] = p[3] * (1.0 - 1.6 * dt) + Vector3(0, 0.25, 0) * dt
			var sc: float = p[4] * (1.2 + 3.4 * k)
			puff_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(sc, sc, sc)), p[2]))
			puff_mm.set_instance_color(i, Color(1.0, 1.0, 1.0, 0.85 * (1.0 - k) * minf(1.0, k * 8.0)))
