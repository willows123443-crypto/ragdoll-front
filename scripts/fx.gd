extends Node3D
# Visual effects: tracers, muzzle flashes, impacts, blood, explosions, smoke, decals, debris, callouts.

var soft_tex: ImageTexture
var tracer_pool: Array = []
var tracers: Array = []
var flash_lights: Array = []
var flash_i = 0
var flash_boost = 1.0
var dust_pool: Array = []
var blood_pool: Array = []
var spark_pool: Array = []
var pool_i = {"dust": 0, "blood": 0, "spark": 0, "dirt": 0}
var dirt_pool: Array = []
var casings: Array = []          # [mesh, velocity, life]
var casing_i = 0
var casing_mm: MultiMesh
var decals: Array = []
var decal_i = 0
var blood_tex: ImageTexture
var scorch_tex: ImageTexture
var debris_list: Array = []
var callouts: Array = []

func _ready() -> void:
	soft_tex = _radial_tex(64, Color(1, 1, 1, 1), 0.0)
	blood_tex = _blob_tex(Color(0.33, 0.04, 0.04, 0.9))
	scorch_tex = _blob_tex(Color(0.16, 0.14, 0.11, 0.5))
	var tm = StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.albedo_color = Color(1.0, 0.9, 0.6)
	tm.emission_enabled = true
	tm.emission = Color(1.0, 0.85, 0.5)
	var bm = BoxMesh.new()
	bm.size = Vector3(0.025, 0.025, 1.0)
	for i in range(140):
		var m = MeshInstance3D.new()
		m.mesh = bm
		m.material_override = tm
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visible = false
		add_child(m)
		tracer_pool.append(m)
	for i in range(5):
		var l = OmniLight3D.new()
		l.light_color = Color(1.0, 0.7, 0.35)
		l.light_energy = 0.0
		l.omni_range = 9.0
		add_child(l)
		flash_lights.append({"l": l, "t": 0.0})
	for i in range(24):
		dust_pool.append(_make_burst(Color(0.55, 0.5, 0.42), 10, 0.7, 3.0, 0.06, false))
		blood_pool.append(_make_burst(Color(0.5, 0.03, 0.03), 12, 0.6, 2.5, 0.05, false))
	for i in range(10):
		spark_pool.append(_make_burst(Color(1.0, 0.8, 0.4), 6, 0.2, 6.0, 0.03, true))
	for i in range(16):
		dirt_pool.append(_make_burst(Color(0.42, 0.36, 0.27), 14, 0.9, 4.5, 0.07, false))
	# spent brass: one multimesh, simulated by hand
	casing_mm = MultiMesh.new()
	casing_mm.transform_format = MultiMesh.TRANSFORM_3D
	var cm = CylinderMesh.new()
	cm.top_radius = 0.008
	cm.bottom_radius = 0.008
	cm.height = 0.045
	cm.radial_segments = 5
	cm.rings = 1
	casing_mm.mesh = cm
	casing_mm.instance_count = 80
	var cmi = MultiMeshInstance3D.new()
	cmi.multimesh = casing_mm
	var brass = StandardMaterial3D.new()
	brass.albedo_color = Color(0.78, 0.6, 0.28)
	brass.metallic = 0.7
	brass.roughness = 0.35
	cmi.material_override = brass
	cmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cmi)
	for i in range(80):
		casings.append({"p": Vector3(0, -999, 0), "v": Vector3.ZERO, "life": 0.0, "spin": 0.0})
		casing_mm.set_instance_transform(i, Transform3D(Basis(), Vector3(0, -999, 0)))
	for i in range(90):
		var d = Decal.new()
		d.size = Vector3(1, 2, 1)
		d.visible = false
		d.cull_mask = 1
		add_child(d)
		decals.append(d)

# ---------------------------------------------------------------- textures and materials
func _radial_tex(sz: int, col: Color, hard: float) -> ImageTexture:
	var img = Image.create_empty(sz, sz, false, Image.FORMAT_RGBA8)
	for y in range(sz):
		for x in range(sz):
			var d = Vector2(x - sz / 2.0, y - sz / 2.0).length() / (sz / 2.0)
			var a = clampf(1.0 - d, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, maxf(a, hard if d < 0.5 else 0.0) * col.a))
	return ImageTexture.create_from_image(img)

func _blob_tex(col: Color) -> ImageTexture:
	var sz = 64
	var img = Image.create_empty(sz, sz, false, Image.FORMAT_RGBA8)
	var r = RandomNumberGenerator.new()
	r.seed = 5
	var blobs: Array = []
	for i in range(7):
		blobs.append([Vector2(r.randf_range(18, 46), r.randf_range(18, 46)), r.randf_range(6, 16)])
	for y in range(sz):
		for x in range(sz):
			var a = 0.0
			for b in blobs:
				var d: float = Vector2(x, y).distance_to(b[0]) / b[1]
				a = maxf(a, clampf(1.2 - d, 0.0, 1.0))
			img.set_pixel(x, y, Color(col.r, col.g, col.b, a * col.a))
	return ImageTexture.create_from_image(img)

func billboard_mat(col: Color, additive: bool) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.albedo_texture = soft_tex
	m.albedo_color = col
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m

func _fade_ramp(c: Color) -> Gradient:
	var g = Gradient.new()
	g.set_color(0, Color(c.r, c.g, c.b, c.a))
	g.set_color(1, Color(c.r, c.g, c.b, 0.0))
	return g

func _grow_curve(a: float, b: float) -> Curve:
	var c = Curve.new()
	c.add_point(Vector2(0, a))
	c.add_point(Vector2(1, b))
	return c

func _make_burst(col: Color, amount: int, life: float, speed: float, size: float, glow: bool) -> CPUParticles3D:
	var p = CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 1.0
	p.spread = 50.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -9.8, 0)
	var bm = BoxMesh.new()
	bm.size = Vector3(size, size, size)
	p.mesh = bm
	var m = StandardMaterial3D.new()
	m.albedo_color = col
	if glow:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p.material_override = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p

func _fire_pool(name_: String, pool: Array, pos: Vector3, dir: Vector3) -> void:
	var p: CPUParticles3D = pool[pool_i[name_]]
	pool_i[name_] = (pool_i[name_] + 1) % pool.size()
	p.global_position = pos
	if dir.length_squared() > 0.001:
		p.direction = dir.normalized()
	p.restart()
	p.emitting = true

# a spent case flicked out to the right of the gun (only near the camera)
func casing(pos: Vector3, right: Vector3) -> void:
	var cam = get_viewport().get_camera_3d()
	if cam == null or cam.global_position.distance_squared_to(pos) > 35.0 * 35.0:
		return
	var c = casings[casing_i]
	casing_i = (casing_i + 1) % casings.size()
	c["p"] = pos
	c["v"] = right * randf_range(1.8, 3.0) + Vector3(0, randf_range(1.5, 2.6), 0) + Vector3(randf_range(-0.4, 0.4), 0, randf_range(-0.4, 0.4))
	c["life"] = 4.0
	c["spin"] = randf() * 6.0

func _step_casings(dt: float) -> void:
	for i in range(casings.size()):
		var c = casings[i]
		if c["life"] <= 0.0:
			continue
		c["life"] -= dt
		var p: Vector3 = c["p"]
		var gy = G.world.ground_y(p.x, p.z)
		if p.y > gy + 0.01 or c["v"].y > 0.0:
			c["v"].y -= 9.8 * dt
			p += c["v"] * dt
			c["spin"] += dt * 25.0
			if p.y < gy + 0.01:
				p.y = gy + 0.01
				c["v"] = Vector3(c["v"].x * 0.3, -c["v"].y * 0.25, c["v"].z * 0.3)
				if c["v"].y < 0.4:
					c["v"] = Vector3.ZERO
		c["p"] = p
		if c["life"] <= 0.0:
			p = Vector3(0, -999, 0)
		casing_mm.set_instance_transform(i, Transform3D(Basis.from_euler(Vector3(c["spin"], c["spin"] * 0.7, PI / 2.0)), p))

# ---------------------------------------------------------------- one-off effects
func impact(pos: Vector3, normal: Vector3) -> void:
	# rounds hitting the ground kick up a spurt of dirt
	if normal.y > 0.6 and pos.y < G.world.ground_y(pos.x, pos.z) + 0.25:
		_fire_pool("dirt", dirt_pool, pos, Vector3(randf_range(-0.2, 0.2), 1.0, randf_range(-0.2, 0.2)))
		return
	_fire_pool("dust", dust_pool, pos, normal + Vector3(0, 0.5, 0))
	if randf() < 0.3:
		_fire_pool("spark", spark_pool, pos, normal)

# shards of a window spraying out
func glass(pos: Vector3, n: Vector3) -> void:
	var p = _make_burst(Color(0.72, 0.82, 0.86), 26, 1.1, 3.2, 0.05, false)
	p.global_position = pos
	p.direction = (n + Vector3(0, 0.3, 0)).normalized()
	p.spread = 70.0
	p.emitting = true
	get_tree().create_timer(1.5, false).timeout.connect(p.queue_free)

func bleed(pos: Vector3, dir: Vector3, heavy: bool) -> void:
	if not G.settings["blood"]:
		_fire_pool("dust", dust_pool, pos, -dir)
		return
	_fire_pool("blood", blood_pool, pos, dir + Vector3(0, 0.4, 0))
	if heavy:
		_fire_pool("blood", blood_pool, pos, -dir + Vector3(0, 0.6, 0))
	if randf() < 0.5:
		decal(pos + dir * randf_range(0.3, 1.2), randf_range(0.3, 0.8), false)

func muzzle(pos: Vector3, big: bool) -> void:
	var f = flash_lights[flash_i]
	flash_i = (flash_i + 1) % flash_lights.size()
	f["l"].global_position = pos
	f["l"].light_energy = (3.0 if big else 1.6) * flash_boost
	f["t"] = 0.05
	var p = _one_shot_smoke(pos, Color(1.0, 0.8, 0.4, 1.0), 3, 0.06, 0.25, 0.5, true)
	p.initial_velocity_max = 0.5

func _one_shot_smoke(pos: Vector3, col: Color, amount: int, life: float, s0: float, s1: float, additive: bool) -> CPUParticles3D:
	var p = CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.9
	p.spread = 180.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 1.5
	p.gravity = Vector3(0, 0.3, 0)
	var q = QuadMesh.new()
	q.size = Vector2(1, 1)
	p.mesh = q
	p.material_override = billboard_mat(Color(1, 1, 1, 1), additive)
	p.color = col
	p.color_ramp = _fade_ramp(col)
	p.scale_amount_min = s0
	p.scale_amount_max = s0 * 1.3
	p.scale_amount_curve = _grow_curve(1.0, s1 / maxf(s0, 0.01))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(life + 0.5, false).timeout.connect(p.queue_free)
	return p

func explosion(pos: Vector3, power: float) -> void:
	var fire = _one_shot_smoke(pos + Vector3(0, 0.6, 0), Color(1.0, 0.6, 0.2, 1.0), 14, 0.45, 1.2 * power, 4.5 * power, true)
	fire.initial_velocity_max = 4.0 * power
	var smoke = _one_shot_smoke(pos + Vector3(0, 1.0, 0), Color(0.28, 0.27, 0.25, 0.8), 16, 4.5, 2.0 * power, 8.0 * power, false)
	smoke.initial_velocity_max = 3.0
	smoke.gravity = Vector3(0, 0.8, 0)
	var dirt = _make_burst(Color(0.38, 0.33, 0.26), 60, 1.6, 12.0 * power, 0.09, false)
	dirt.spread = 70.0
	dirt.direction = Vector3.UP
	dirt.global_position = pos
	dirt.emitting = true
	get_tree().create_timer(2.5, false).timeout.connect(dirt.queue_free)
	var f = flash_lights[(flash_i + 2) % flash_lights.size()]
	f["l"].global_position = pos + Vector3(0, 1.5, 0)
	f["l"].light_energy = 8.0 * flash_boost
	f["l"].omni_range = 22.0
	f["t"] = 0.12
	decal(pos, randf_range(2.5, 3.5) * power, true)

func dust_cloud(pos: Vector3, size: float) -> void:
	var d = _one_shot_smoke(pos, Color(0.62, 0.58, 0.5, 0.7), 8, 3.0, 1.2 * clampf(size, 1.0, 3.0), 4.5, false)
	d.initial_velocity_max = 1.5

func wreck_smoke(pos: Vector3, parent: Node) -> void:
	var p = CPUParticles3D.new()
	p.amount = 40
	p.lifetime = 10.0
	p.direction = Vector3(0.12, 1, 0.03)
	p.spread = 8.0
	p.initial_velocity_min = 1.8
	p.initial_velocity_max = 2.8
	p.gravity = Vector3(0.25, 0.1, 0.05)
	var q = QuadMesh.new()
	p.mesh = q
	p.material_override = billboard_mat(Color(1, 1, 1, 1), false)
	var c = Color(0.17, 0.16, 0.15, 0.6)
	p.color = c
	p.color_ramp = _fade_ramp(c)
	p.scale_amount_min = 1.2
	p.scale_amount_max = 1.8
	p.scale_amount_curve = _grow_curve(1.0, 7.0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.preprocess = p.lifetime
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true

# a lingering smoke screen; returns the emitter so it can be stopped
func smoke_screen(pos: Vector3, life: float, tint: Color = Color(0.85, 0.85, 0.83), big: float = 1.0) -> CPUParticles3D:
	var p = CPUParticles3D.new()
	p.amount = int(110 * big)
	p.lifetime = 8.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 4.0 * big
	p.direction = Vector3(0.2, 1, 0)
	p.spread = 60.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.9
	p.gravity = Vector3(0.15, 0.05, 0)
	p.mesh = QuadMesh.new()
	p.material_override = billboard_mat(Color(1, 1, 1, 1), false)
	var c = Color(tint.r, tint.g, tint.b, 0.9)
	p.color = c
	p.color_ramp = _fade_ramp(c)
	p.scale_amount_min = 3.5 * big
	p.scale_amount_max = 5.0 * big
	p.scale_amount_curve = _grow_curve(1.0, 3.0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# the web renderer draws particles that haven't been emitted yet as black discs, so the cloud
	# starts fully formed (scaled up from small) and fades out as a whole instead of stopping emission
	p.preprocess = p.lifetime
	add_child(p)
	p.global_position = pos
	p.emitting = true
	p.scale = Vector3(0.2, 0.2, 0.2)
	var mat: StandardMaterial3D = p.material_override
	var tw = p.create_tween()
	tw.tween_property(p, "scale", Vector3.ONE, 2.5)
	tw.tween_interval(maxf(0.5, life - 2.5))
	tw.tween_property(mat, "albedo_color", Color(1, 1, 1, 0), 5.0)
	tw.tween_callback(p.queue_free)
	return p

func decal(pos: Vector3, size: float, scorch: bool) -> void:
	if not scorch and not G.settings["blood"]:
		return
	var d: Decal = decals[decal_i]
	decal_i = (decal_i + 1) % decals.size()
	d.texture_albedo = scorch_tex if scorch else blood_tex
	d.size = Vector3(size, 3.0, size * randf_range(0.7, 1.3))
	d.global_position = Vector3(pos.x, G.world.ground_y(pos.x, pos.z) + 0.5, pos.z)
	d.rotation = Vector3(0, randf() * TAU, 0)
	d.visible = true

# ---------------------------------------------------------------- tracers
func tracer(o: Vector3, dir: Vector3, ln: float, speed: float, on_hit: Callable, visible_: bool) -> void:
	var t = {"o": o, "dir": dir, "len": ln, "d": 0.0, "speed": speed, "on_hit": on_hit, "done": false, "mesh": null}
	if visible_:
		for m in tracer_pool:
			if not m.visible:
				t["mesh"] = m
				m.visible = true
				break
	tracers.append(t)

var torch_lights: Array = []

# a handful of real spotlights go to the switched-on torches nearest the camera
func _torches() -> void:
	if torch_lights.is_empty():
		for i in range(5):
			var l = SpotLight3D.new()
			l.light_color = Color(1.0, 0.95, 0.8)
			l.light_energy = 0.0
			l.spot_range = 22.0
			l.spot_angle = 24.0
			l.shadow_enabled = false
			add_child(l)
			torch_lights.append(l)
	var cam = get_viewport().get_camera_3d()
	if cam == null:
		return
	var lit = []
	for s in G.soldiers:
		if s.light_on and s.flashlight != null and s.flashlight.visible:
			lit.append([s.pos.distance_squared_to(cam.global_position), s])
	lit.sort_custom(func(a, b): return a[0] < b[0])
	for i in range(torch_lights.size()):
		var l: SpotLight3D = torch_lights[i]
		if i < lit.size() and lit[i][0] < 90.0 * 90.0:
			var f: Node3D = lit[i][1].flashlight
			l.global_transform = f.global_transform * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
			l.light_energy = 3.0
		else:
			l.light_energy = 0.0

func step(dt: float) -> void:
	if G.main.is_night() or not torch_lights.is_empty():
		_torches()
	_step_casings(dt)
	for i in range(tracers.size() - 1, -1, -1):
		var t = tracers[i]
		t["d"] += t["speed"] * dt
		if not t["done"] and t["d"] >= t["len"]:
			t["done"] = true
			if t["on_hit"].is_valid():
				t["on_hit"].call()
		if t["d"] - 3.5 >= t["len"]:
			if t["mesh"]:
				t["mesh"].visible = false
			tracers.remove_at(i)
			continue
		if t["mesh"]:
			var a = maxf(0.0, t["d"] - 3.5)
			var b = minf(t["len"], t["d"])
			var m: MeshInstance3D = t["mesh"]
			var mid: Vector3 = t["o"] + t["dir"] * ((a + b) / 2.0)
			var up = Vector3.UP if absf(t["dir"].y) < 0.95 else Vector3.RIGHT
			m.global_transform = Transform3D(Basis.looking_at(t["dir"], up).scaled(Vector3(1, 1, maxf(0.01, b - a))), mid)
	for f in flash_lights:
		if f["t"] > 0.0:
			f["t"] -= dt
			if f["t"] <= 0.0:
				f["l"].light_energy = 0.0
				f["l"].omni_range = 9.0
	# debris settles then disappears
	for i in range(debris_list.size() - 1, -1, -1):
		var d = debris_list[i]
		d["t"] -= dt
		if d["t"] <= 0.0 or not is_instance_valid(d["b"]):
			if is_instance_valid(d["b"]):
				d["b"].queue_free()
			debris_list.remove_at(i)

func debris(pos: Vector3, vel: Vector3, size: float, col: Color) -> void:
	if debris_list.size() > 140:
		var old = debris_list.pop_front()
		if is_instance_valid(old["b"]):
			old["b"].queue_free()
	var b = RigidBody3D.new()
	b.collision_layer = G.L_DEBRIS
	b.collision_mask = G.L_WORLD | G.L_DEBRIS | G.L_BODY
	b.mass = size * 20.0
	var sz = Vector3(size * randf_range(0.6, 1.4), size * randf_range(0.5, 1.0), size * randf_range(0.6, 1.4))
	var cs = CollisionShape3D.new()
	var bs = BoxShape3D.new()
	bs.size = sz
	cs.shape = bs
	b.add_child(cs)
	var m = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = sz
	m.mesh = bm
	var mat = StandardMaterial3D.new()
	mat.albedo_color = col.darkened(randf_range(0.0, 0.25))
	m.material_override = mat
	b.add_child(m)
	add_child(b)
	b.global_position = pos
	b.rotation = Vector3(randf() * 6, randf() * 6, randf() * 6)
	b.linear_velocity = vel
	b.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
	debris_list.append({"b": b, "t": randf_range(25.0, 40.0)})

func clear_all() -> void:
	for t in tracers:
		if t["mesh"]:
			t["mesh"].visible = false
	tracers.clear()
	for d in decals:
		d.visible = false
	for d in debris_list:
		if is_instance_valid(d["b"]):
			d["b"].queue_free()
	debris_list.clear()
	for c in callouts:
		if is_instance_valid(c["l"]):
			c["l"].queue_free()
	callouts.clear()

# ---------------------------------------------------------------- speech bubbles
func callout(s, text: String) -> void:
	if not G.settings["callouts"] or s.callout_cd > 0.0 or s.zombie:
		return
	s.callout_cd = randf_range(4.0, 7.0)
	if callouts.size() >= 8:
		var o = callouts.pop_front()
		if is_instance_valid(o["l"]):
			o["l"].queue_free()
	var l = Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0012
	l.font_size = 22
	l.outline_size = 8
	l.modulate = Color(0.75, 0.85, 1.0) if s.team == 0 else Color(1.0, 0.75, 0.75)
	add_child(l)
	callouts.append({"l": l, "s": s, "t": 1.8})
	G.audio.bark(s, text)

func update_callouts(dt: float) -> void:
	for i in range(callouts.size() - 1, -1, -1):
		var c = callouts[i]
		c["t"] -= dt
		if c["t"] <= 0.0 or not is_instance_valid(c["s"]):
			if is_instance_valid(c["l"]):
				c["l"].queue_free()
			callouts.remove_at(i)
			continue
		c["l"].global_position = c["s"].parts[2].global_position + Vector3(0, 0.55, 0)
		c["l"].modulate.a = minf(1.0, c["t"] * 2.0)

# a short-lived marker where an order was given
func order_marker(p: Vector3) -> void:
	var r = MeshInstance3D.new()
	var tm = TorusMesh.new()
	tm.inner_radius = 1.6
	tm.outer_radius = 1.9
	r.mesh = tm
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.85, 0.25, 0.8)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	r.material_override = m
	r.scale = Vector3(1, 0.2, 1)
	add_child(r)
	r.global_position = p + Vector3(0, 0.1, 0)
	var tw = r.create_tween()
	tw.tween_property(r, "scale", Vector3(0.3, 0.2, 0.3), 1.2)
	tw.tween_callback(r.queue_free)

# a tongue of flame (flamethrowers, burning soldiers, burning hedges)
var flame_mat: StandardMaterial3D = null
var flame_pool: Array = []
var flame_i = 0

func flame_puff(pos: Vector3, vel: Vector3, size: float) -> void:
	if flame_pool.is_empty():
		flame_mat = billboard_mat(Color(1, 1, 1, 1), true)
		for k in range(40):
			var p = CPUParticles3D.new()
			p.emitting = false
			p.one_shot = true
			p.amount = 6
			p.lifetime = 0.55
			p.explosiveness = 0.85
			p.spread = 12.0
			p.gravity = Vector3(0, 3.0, 0)
			p.mesh = QuadMesh.new()
			p.material_override = flame_mat
			var g = Gradient.new()
			g.set_color(0, Color(1.0, 0.85, 0.4, 0.95))
			g.set_color(1, Color(0.6, 0.12, 0.02, 0.0))
			p.color_ramp = g
			p.scale_amount_curve = _grow_curve(0.6, 2.2)
			p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(p)
			flame_pool.append(p)
	var p: CPUParticles3D = flame_pool[flame_i]
	flame_i = (flame_i + 1) % flame_pool.size()
	p.global_position = pos
	var sp = vel.length()
	p.direction = vel / maxf(sp, 0.01)
	p.initial_velocity_min = sp * 0.7
	p.initial_velocity_max = sp
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size
	p.restart()
