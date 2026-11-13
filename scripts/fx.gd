extends Node3D
# Visual effects: tracers, muzzle flashes, impacts, blood, explosions, smoke, decals, debris, callouts.

var soft_tex: ImageTexture
var tracer_pool: Array = []
var tracers: Array = []
var flash_lights: Array = []
var flash_i = 0
var flash_boost = 1.0
var tracer_mat: StandardMaterial3D = null
var cam_now: Camera3D = null
var night_now = false
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
	tracer_mat = tm
	# at night each tracer gets a soft glowing streak round its core
	var gm = StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	gm.albedo_color = Color(1.0, 0.45, 0.15, 0.35)
	var gbm = BoxMesh.new()
	gbm.size = Vector3(0.11, 0.11, 1.0)
	var bm = BoxMesh.new()
	bm.size = Vector3(0.025, 0.025, 1.0)
	for i in range(140):
		var m = MeshInstance3D.new()
		m.mesh = bm
		m.material_override = tm
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visible = false
		add_child(m)
		var gl = MeshInstance3D.new()
		gl.mesh = gbm
		gl.material_override = gm
		gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gl.name = "glow"
		gl.visible = false
		m.add_child(gl)
		tracer_pool.append(m)
	for i in range(10):
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
	# at night a flash lights up the walls and the men round it
	# every flash a little different, so a burst flickers on the walls rather than strobing evenly
	# indoors, out of the daylight, every shot throws its flash up the walls of the room
	var inside = G.world != null and G.world.building_index(pos) >= 0
	f["l"].light_energy = (3.0 if big else 1.6) * flash_boost * (2.6 if night_now else (2.3 if inside else 1.0)) * randf_range(0.65, 1.25)
	f["l"].omni_range = (13.0 if night_now else (11.0 if inside else 9.0)) * randf_range(0.85, 1.1)
	f["l"].light_color = Color(1.0, randf_range(0.62, 0.78), randf_range(0.28, 0.42))
	f["t"] = randf_range(0.035, 0.06) + (0.025 if inside else 0.0)
	var p = _one_shot_smoke(pos, Color(1.0, 0.8, 0.4, 1.0), 3, 0.06, 0.25, 0.5, true)
	p.initial_velocity_max = 0.5

func _one_shot_smoke(pos: Vector3, col: Color, amount: int, life: float, s0: float, s1: float, additive: bool) -> CPUParticles3D:
	var p = CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 1.0
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
	# the web build draws particles that haven't been emitted yet as black discs (the black circle
	# behind a rocket): keep the puff hidden for its first couple of frames, until they all exist
	p.visible = false
	var wp = weakref(p)
	get_tree().create_timer(0.05, false).timeout.connect(func():
		var pp = wp.get_ref()
		if pp != null:
			pp.visible = true)
	get_tree().create_timer(life + 0.5, false).timeout.connect(p.queue_free)
	return p

func explosion(pos: Vector3, power: float) -> void:
	var fire = _one_shot_smoke(pos + Vector3(0, 0.6, 0), Color(1.0, 0.6, 0.2, 1.0), 14, 0.45, 1.2 * power, 4.5 * power, true)
	fire.initial_velocity_max = 4.0 * power
	var smoke = _one_shot_smoke(pos + Vector3(0, 1.0, 0), Color(0.28, 0.27, 0.25, 0.8), 16, 4.5, 2.0 * power, 8.0 * power, false)
	smoke.initial_velocity_max = 3.0
	smoke.gravity = Vector3(0, 0.8, 0)
	# earth thrown up in a cone: fine dirt, then heavier clods that tumble back down
	var dirt = _make_burst(Color(0.38, 0.33, 0.26), 60, 1.6, 13.0 * power, 0.09, false)
	dirt.spread = 26.0
	dirt.direction = Vector3.UP
	dirt.global_position = pos
	dirt.emitting = true
	get_tree().create_timer(2.5, false).timeout.connect(dirt.queue_free)
	var clods = _make_burst(Color(0.3, 0.26, 0.2), int(10 + 8 * power), 2.4, 11.0 * power, 0.2, false)
	clods.spread = 34.0
	clods.direction = Vector3.UP
	clods.angular_velocity_min = -400.0
	clods.angular_velocity_max = 400.0
	clods.scale_amount_min = 0.6
	clods.scale_amount_max = 1.6
	clods.global_position = pos
	clods.emitting = true
	get_tree().create_timer(3.0, false).timeout.connect(clods.queue_free)
	var plume = _one_shot_smoke(pos + Vector3(0, 0.3, 0), Color(0.3, 0.26, 0.2, 0.85), int(10 + 6 * power), 1.5, 0.7 * power, 2.6 * power, false)
	plume.direction = Vector3.UP
	plume.spread = 18.0
	plume.initial_velocity_min = 7.0 * power
	plume.initial_velocity_max = 14.0 * power
	plume.gravity = Vector3(0, -7.0, 0)
	plume.damping_min = 1.0
	plume.damping_max = 2.0
	# a ring of dust rolling out low along the ground
	var roll = _one_shot_smoke(pos + Vector3(0, 0.3, 0), Color(0.6, 0.55, 0.46, 0.7), int(18 + 10 * power), 2.6, 0.9 * power, 3.4 * power, false)
	roll.direction = Vector3(1, 0, 0)
	roll.spread = 180.0
	roll.flatness = 1.0
	roll.initial_velocity_min = 6.0 * power
	roll.initial_velocity_max = 9.0 * power
	roll.damping_min = 4.0 * power
	roll.damping_max = 6.0 * power
	roll.gravity = Vector3(0, 0.15, 0)
	# the white-hot flash at the heart of it, lighting up the walls round about
	var core = _one_shot_smoke(pos + Vector3(0, 0.8, 0), Color(1.0, 0.93, 0.75, 1.0), 3, 0.14, 2.6 * power, 3.6 * power, true)
	core.initial_velocity_max = 0.3
	var f = flash_lights[(flash_i + 2) % flash_lights.size()]
	f["l"].global_position = pos + Vector3(0, 1.5, 0)
	f["l"].light_energy = 13.0 * flash_boost
	f["l"].omni_range = 18.0 + 10.0 * power
	f["t"] = 0.2
	decal(pos, randf_range(2.5, 3.5) * power, true)
	# the dust hangs about long after the bang
	var haze = _one_shot_smoke(pos + Vector3(0, 0.8, 0), Color(0.55, 0.5, 0.42, 0.55), 7, 14.0, 3.0 * power, 11.0 * power, false)
	haze.gravity = Vector3(0, 0.04, 0)
	haze.initial_velocity_max = 0.8
	haze.spread = 90.0
	_blast_extras(pos, power)

# ---------------------------------------------------------------- blasts: flash, ground ring, embers, clods
var ring_tex: ImageTexture
var ring_pool: Array = []
var ring_i = 0
var flashq_pool: Array = []
var flashq_i = 0
var ember_pool: Array = []
var ember_i = 0
var clod_mm: MultiMesh = null
var clod_i = 0
var clod_fly: Array = []       # the ones still in the air: [slot, pos, vel, basis, spin axis, spin, size, bounced]
const CLODS = 640

func _blast_setup() -> void:
	var sz = 128
	var img = Image.create_empty(sz, sz, false, Image.FORMAT_RGBA8)
	for y in range(sz):
		for x in range(sz):
			var d = Vector2(x - sz / 2.0 + 0.5, y - sz / 2.0 + 0.5).length() / (sz / 2.0)
			var a = clampf(1.0 - absf(d - 0.84) / 0.13, 0.0, 1.0)
			a = a * a
			if d < 0.84:
				a = maxf(a, clampf((d - 0.35) / 0.49, 0.0, 1.0) * 0.22)   # the dust it drags along behind it
			img.set_pixel(x, y, Color(1, 1, 1, a))
	ring_tex = ImageTexture.create_from_image(img)
	for i in range(6):
		var m = MeshInstance3D.new()
		var pm = PlaneMesh.new()
		pm.size = Vector2(2, 2)
		m.mesh = pm
		var mat = StandardMaterial3D.new()
		mat.albedo_texture = ring_tex
		mat.albedo_color = Color(0.93, 0.89, 0.8, 0.0)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visible = false
		add_child(m)
		ring_pool.append({"m": m, "mat": mat, "t": 9.0, "dur": 0.4, "r": 6.0})
	for i in range(4):
		var m = MeshInstance3D.new()
		var q = QuadMesh.new()
		q.size = Vector2(1, 1)
		m.mesh = q
		var mat = StandardMaterial3D.new()
		mat.albedo_texture = soft_tex
		mat.albedo_color = Color(1.0, 0.95, 0.8, 0.0)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.billboard_keep_scale = true
		mat.no_depth_test = true
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visible = false
		add_child(m)
		flashq_pool.append({"m": m, "mat": mat, "t": 9.0, "s": 6.0})
	for i in range(4):
		var e = _make_burst(Color(1.0, 0.72, 0.3), 26, 0.9, 18.0, 0.07, true)
		e.spread = 70.0
		e.direction = Vector3.UP
		e.gravity = Vector3(0, -16.0, 0)
		e.color_ramp = _fade_ramp(Color(1, 1, 1, 1))
		ember_pool.append(e)
	clod_mm = MultiMesh.new()
	clod_mm.transform_format = MultiMesh.TRANSFORM_3D
	clod_mm.use_colors = true
	clod_mm.instance_count = CLODS
	var bm = BoxMesh.new()
	bm.size = Vector3(1, 1, 1)
	clod_mm.mesh = bm
	var cm = StandardMaterial3D.new()
	cm.vertex_color_use_as_albedo = true
	cm.roughness = 1.0
	var cmi = MultiMeshInstance3D.new()
	cmi.multimesh = clod_mm
	cmi.material_override = cm
	cmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cmi.custom_aabb = AABB(Vector3(-600, -50, -600), Vector3(1200, 200, 1200))
	add_child(cmi)
	_clods_clear()

var clod_xf: Array = []        # where each clod came to rest (null while it's in the air or unused)
var clod_sz: Array = []
var clod_chk = 0
var cut_sig = 0
var cut_t = 0.0

# is this spot on a part of a building that's been lifted off for the view (a roof, an upper storey)?
func _cut_away(p: Vector3) -> bool:
	var cuts: Dictionary = G.world.cut_now
	if cuts.is_empty():
		return false
	var bi: int = G.world.building_index(p, 0.7)
	return bi >= 0 and cuts.has(bi) and p.y - float(G.world.buildings[bi].get("gy", 0.0)) > float(cuts[bi])

# when the upper storeys or the roof of a building are lifted off to see inside, what's lying on them goes
# with them (rubble and clods on a floor you couldn't see used to hang in the air over the one you could)
func _cut_tick(dt: float) -> void:
	cut_t -= dt
	if cut_t > 0.0 or G.world == null:
		return
	cut_t = 0.25
	var cuts: Dictionary = G.world.cut_now
	var sig = cuts.hash()
	if cuts.is_empty() and sig == cut_sig:
		return
	for d in debris_list:
		var b = d["b"]
		if is_instance_valid(b):
			var hide = _cut_away(b.global_position)
			if b.visible == hide:
				b.visible = not hide
	if sig != cut_sig and clod_mm != null:
		for i in range(clod_xf.size()):
			if clod_xf[i] != null:
				_clod_show(i)
	cut_sig = sig

func _clod_show(i: int) -> void:
	var xf: Transform3D = clod_xf[i]
	if _cut_away(xf.origin):
		clod_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0, -500, 0)))
	else:
		clod_mm.set_instance_transform(i, xf)

# what they were lying on has gone (a desk smashed, a wall blown down): they fall the rest of the way
func drop_clods(lo: Vector3, hi: Vector3) -> void:
	if clod_mm == null:
		return
	for i in range(clod_xf.size()):
		if clod_xf[i] == null:
			continue
		var o: Vector3 = clod_xf[i].origin
		if o.x > lo.x and o.x < hi.x and o.z > lo.z and o.z < hi.z and o.y > lo.y and o.y < hi.y:
			clod_fly.append([i, o, Vector3(randf_range(-0.6, 0.6), 0.5, randf_range(-0.6, 0.6)), clod_xf[i].basis.orthonormalized(), Vector3.UP, randf_range(1.0, 4.0), clod_sz[i], true])
			clod_xf[i] = null

func _clods_clear() -> void:
	clod_fly.clear()
	clod_i = 0
	clod_xf.resize(CLODS)
	clod_sz.resize(CLODS)
	for i in range(CLODS):
		clod_xf[i] = null
		clod_sz[i] = Vector3.ONE * 0.1
	if clod_mm != null:
		for i in range(CLODS):
			clod_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0, -500, 0)))

# the flash, the ring racing out across the ground, the sparks, and the earth and rubble it throws out
# (which comes down round the crater and stays there)
func _blast_extras(pos: Vector3, power: float) -> void:
	if clod_mm == null:
		_blast_setup()
	var gy: float = G.world.surface_y(pos.x, pos.z, pos.y + 0.5) if G.world != null else pos.y
	var low = pos.y - gy < 2.5
	if power >= 0.45 and low:
		var r = ring_pool[ring_i]
		ring_i = (ring_i + 1) % ring_pool.size()
		r["t"] = 0.0
		r["dur"] = 0.34 + 0.1 * power
		r["r"] = 5.5 + 5.5 * power
		r["m"].global_position = Vector3(pos.x, gy + 0.12, pos.z)
		r["m"].scale = Vector3(0.4, 1.0, 0.4)
		r["m"].visible = true
	var fq = flashq_pool[flashq_i]
	flashq_i = (flashq_i + 1) % flashq_pool.size()
	fq["t"] = 0.0
	fq["s"] = 5.0 + 6.0 * power
	fq["m"].global_position = pos + Vector3(0, 0.9, 0)
	fq["m"].visible = true
	var e: CPUParticles3D = ember_pool[ember_i]
	ember_i = (ember_i + 1) % ember_pool.size()
	e.global_position = pos + Vector3(0, 0.3, 0)
	e.initial_velocity_min = 6.0 * power
	e.initial_velocity_max = 20.0 * power
	e.restart()
	e.emitting = true
	if not low:
		return
	var n = int(clampf(9.0 + 12.0 * power, 10.0, 34.0))
	var paved = G.world != null and G.world.has_method("on_road") and G.world.on_road(pos.x, pos.z)
	for i in range(n):
		var ang = randf() * TAU
		var out = randf_range(1.2, 7.5) * (0.6 + 0.5 * power)
		var sz = randf_range(0.1, 0.27) * (0.8 + 0.25 * power)
		var col = Color(0.27, 0.23, 0.18).lerp(Color(0.12, 0.11, 0.1), randf() * 0.7)
		if paved and i % 2 == 0:
			col = Color(0.3, 0.3, 0.31).lerp(Color(0.16, 0.16, 0.16), randf() * 0.6)
		var slot = clod_i
		clod_i = (clod_i + 1) % CLODS
		for k in range(clod_fly.size()):
			if clod_fly[k][0] == slot:
				clod_fly.remove_at(k)
				break
		clod_mm.set_instance_color(slot, col)
		clod_xf[slot] = null
		clod_fly.append([slot, Vector3(pos.x, gy + 0.2, pos.z), Vector3(cos(ang) * out, randf_range(5.0, 11.0) * (0.7 + 0.3 * power), sin(ang) * out),
			Basis.from_euler(Vector3(randf() * 6.0, randf() * 6.0, randf() * 6.0)), Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5).normalized(), randf_range(4.0, 12.0),
			Vector3(sz * randf_range(0.8, 1.6), sz * randf_range(0.5, 0.9), sz * randf_range(0.8, 1.4)), false])

func _blast_step(dt: float) -> void:
	for r in ring_pool:
		if r["t"] < r["dur"]:
			r["t"] += dt
			var k = clampf(r["t"] / r["dur"], 0.0, 1.0)
			var e = 1.0 - (1.0 - k) * (1.0 - k)
			var sc = lerpf(0.4, r["r"], e)
			r["m"].scale = Vector3(sc, 1.0, sc)
			r["mat"].albedo_color.a = 0.95 * pow(1.0 - k, 1.3)
			if k >= 1.0:
				r["m"].visible = false
	for f in flashq_pool:
		if f["t"] < 0.13:
			f["t"] += dt
			var k = clampf(f["t"] / 0.13, 0.0, 1.0)
			var sc = f["s"] * (0.7 + 0.6 * k)
			f["m"].scale = Vector3(sc, sc, sc)
			f["mat"].albedo_color.a = (1.0 - k) * (1.0 - k)
			if k >= 1.0:
				f["m"].visible = false
	# a couple of the ones lying about are looked at each frame: still on something? (a door they landed on
	# has swung open, a wreck has been cleared away...)
	for k in range(2):
		clod_chk = (clod_chk + 1) % CLODS
		if clod_xf[clod_chk] != null:
			var o: Vector3 = clod_xf[clod_chk].origin
			if o.y - G.world.surface_y(o.x, o.z, o.y + 0.3) > 0.45:
				clod_fly.append([clod_chk, o, Vector3.ZERO, clod_xf[clod_chk].basis.orthonormalized(), Vector3.UP, 2.0, clod_sz[clod_chk], true])
				clod_xf[clod_chk] = null
	var i = clod_fly.size() - 1
	while i >= 0:
		var c = clod_fly[i]
		var v: Vector3 = c[2]
		v.y -= 16.0 * dt
		var p: Vector3 = c[1] + v * dt
		var b: Basis = c[3].rotated(c[4], c[5] * dt)
		var done = false
		if v.y < 0.0:
			var gy: float = G.world.surface_y(p.x, p.z, p.y + 0.6)
			if p.y <= gy + c[6].y * 0.5:
				p.y = gy + c[6].y * 0.45
				if not c[7] and v.length() > 5.0:
					# one skip, then it lies where it lands
					c[7] = true
					v = Vector3(v.x * 0.35, -v.y * 0.22, v.z * 0.35)
					c[5] *= 0.4
				else:
					done = true
		c[1] = p
		c[2] = v
		c[3] = b
		clod_mm.set_instance_transform(c[0], Transform3D(b.scaled_local(c[6]), p))
		if done:
			clod_xf[c[0]] = Transform3D(b.scaled_local(c[6]), p)
			clod_sz[c[0]] = c[6]
			_clod_show(c[0])
			clod_fly.remove_at(i)
		i -= 1

func dust_cloud(pos: Vector3, size: float) -> void:
	var d = _one_shot_smoke(pos, Color(0.62, 0.58, 0.5, 0.7), 8, 3.0, 1.2 * clampf(size, 1.0, 3.0), 4.5, false)
	d.initial_velocity_max = 1.5

# water thrown up: spray that falls back, and a pale ring on the surface
func splash(pos: Vector3, size: float) -> void:
	var d = _one_shot_smoke(pos, Color(0.85, 0.9, 0.92, 0.75), int(6 + 6 * size), 0.9, 0.35 * size, 1.4 * size, false)
	d.direction = Vector3(0, 1, 0)
	d.spread = 35.0
	d.initial_velocity_min = 1.5 * size
	d.initial_velocity_max = 3.5 * size
	d.gravity = Vector3(0, -9.0, 0)
	ripple(pos, size)

# a column of white water thrown straight up by a shell, falling back as spray
func water_column(pos: Vector3, power: float) -> void:
	var d = _one_shot_smoke(pos, Color(0.9, 0.94, 0.96, 0.85), int(18 * power) + 6, 1.6, 0.9 * power, 2.6 * power, false)
	d.direction = Vector3(0, 1, 0)
	d.spread = 10.0
	d.initial_velocity_min = 8.0 * power
	d.initial_velocity_max = 14.0 * power
	d.gravity = Vector3(0, -9.8, 0)

# the white wake churned up behind a moving boat, left on the water where it was made
func wake(pos: Vector3, back: Vector3, size: float) -> void:
	var m = MeshInstance3D.new()
	var qm = QuadMesh.new()
	qm.size = Vector2(1.0, 1.0)
	m.mesh = qm
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.97, 1.0, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	m.global_position = pos + Vector3(0, 0.04, 0)
	m.rotation = Vector3(-PI / 2.0, atan2(back.x, back.z), 0)
	m.scale = Vector3(size, size * 1.4, 1)
	var tw = m.create_tween()
	tw.set_parallel(true)
	tw.tween_property(m, "scale", Vector3(size * 3.2, size * 2.4, 1), 2.4)
	tw.tween_property(mat, "albedo_color:a", 0.0, 2.4)
	tw.chain().tween_callback(m.queue_free)

func ripple(pos: Vector3, size: float) -> void:
	var m = MeshInstance3D.new()
	var tm = TorusMesh.new()
	tm.inner_radius = 0.42
	tm.outer_radius = 0.5
	tm.rings = 16
	tm.ring_segments = 4
	m.mesh = tm
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.95, 1.0, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	m.global_position = pos + Vector3(0, 0.03, 0)
	m.scale = Vector3(0.6, 0.15, 0.6) * size
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(m, "scale", Vector3(3.0, 0.15, 3.0) * size, 1.4)
	tw.tween_property(mat, "albedo_color:a", 0.0, 1.4)
	tw.chain().tween_callback(m.queue_free)

func wreck_smoke(pos: Vector3, parent: Node, c: Color = Color(0.17, 0.16, 0.15, 0.6), amount: int = 40) -> CPUParticles3D:
	var p = CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 10.0
	p.direction = Vector3(0.12, 1, 0.03)
	p.spread = 8.0
	p.initial_velocity_min = 1.8
	p.initial_velocity_max = 2.8
	p.gravity = Vector3(0.25, 0.1, 0.05)
	var q = QuadMesh.new()
	p.mesh = q
	p.material_override = billboard_mat(Color(1, 1, 1, 1), false)
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
	return p

# a lingering smoke screen; returns the emitter so it can be stopped
# (the amount has to be set here, before it starts: changing it afterwards re-creates the particles,
# and on the web unborn particles show as black discs)
func smoke_screen(pos: Vector3, life: float, tint: Color = Color(0.85, 0.85, 0.83), big: float = 1.0, dens: float = 1.0) -> CPUParticles3D:
	var p = CPUParticles3D.new()
	p.amount = int(110 * big * dens)
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
	# (on the floor it happened on: a shell on a roof used to scorch the ground floor three storeys below)
	d.global_position = Vector3(pos.x, G.world.surface_y(pos.x, pos.z, pos.y + 0.6) + 0.5, pos.z)
	d.rotation = Vector3(0, randf() * TAU, 0)
	d.visible = true

# ---------------------------------------------------------------- tracers
func tracer(o: Vector3, dir: Vector3, ln: float, speed: float, on_hit: Callable, visible_: bool, bright: bool = false) -> void:
	var t = {"o": o, "dir": dir, "len": ln, "d": 0.0, "speed": speed, "on_hit": on_hit, "done": false, "mesh": null, "tail": 3.5}
	# (a tracer round fired from right beside the view, your own machine gun's, is seen end-on, and its
	# wide glow was a big orange square leaving the muzzle: those are drawn as plain tracers)
	if bright and G.player != null:
		var cam0 = get_viewport().get_camera_3d()
		if cam0 != null and cam0.global_position.distance_to(o) < 5.0:
			bright = false
	if visible_ and bright:
		if bright_pool.is_empty():
			_make_bright_pool()
		for m in bright_pool:
			if not m.visible:
				t["mesh"] = m
				t["tail"] = 7.0
				t["bright"] = true
				m.visible = true
				break
	if visible_ and t["mesh"] == null:
		for m in tracer_pool:
			if not m.visible:
				t["mesh"] = m
				m.visible = true
				break
	tracers.append(t)

# the tracer rounds: a hot core and a wide glow round it, drawn on top of the haze so a line of them
# reads from commander height, day or night
var bright_pool: Array = []
var bright_glow_mat: StandardMaterial3D = null

func _make_bright_pool() -> void:
	var cm = StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.albedo_color = Color(1.0, 0.88, 0.55)
	cm.disable_fog = true
	var gm = StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_color = Color(1.0, 0.5, 0.12, 0.55)
	gm.disable_fog = true
	bright_glow_mat = gm
	var bm = BoxMesh.new()
	bm.size = Vector3(0.045, 0.045, 1.0)
	var gbm = BoxMesh.new()
	gbm.size = Vector3(0.12, 0.12, 1.0)
	for i in range(48):
		var m = MeshInstance3D.new()
		m.mesh = bm
		m.material_override = cm
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visible = false
		add_child(m)
		var gl = MeshInstance3D.new()
		gl.mesh = gbm
		gl.material_override = gm
		gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gl.name = "glow"
		m.add_child(gl)
		bright_pool.append(m)

var torch_lights: Array = []

# a handful of real spotlights go to the switched-on torches nearest the camera
func _torches() -> void:
	if torch_lights.is_empty():
		for i in range(5):
			var l = SpotLight3D.new()
			l.light_color = Color(0.88, 0.93, 1.0)
			l.light_energy = 0.0
			l.spot_range = 30.0
			l.spot_angle = 28.0
			# a bright centre that falls off softly to the edge, dimming with distance
			l.spot_angle_attenuation = 2.4
			l.spot_attenuation = 1.3
			l.shadow_enabled = false
			add_child(l)
			torch_lights.append(l)
	var cam = get_viewport().get_camera_3d()
	if cam == null:
		return
	var lit = []
	for s in G.soldiers:
		if s.light_on and s.flashlight != null and s.flashlight.visible:
			lit.append([s.pos.distance_squared_to(cam.global_position), s.flashlight, false])
	for v in G.vehicles:
		if v.lights_on and v.lamps != null and v.lamps.visible and v.visible:
			# headlights count as nearer: they light far more of the scene
			lit.append([v.pos.distance_squared_to(cam.global_position) * 0.5, v.lamps.get_node("aim"), true])
			for lp in v.lamps.get_meta("lamps", []):
				Lamp.update(lp, cam)
	lit.sort_custom(func(a, b): return a[0] < b[0])
	for i in range(torch_lights.size()):
		var l: SpotLight3D = torch_lights[i]
		if i < lit.size() and lit[i][0] < 110.0 * 110.0:
			var f: Node3D = lit[i][1]
			l.global_transform = f.global_transform * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
			l.light_energy = 9.0 if lit[i][2] else 5.0
			l.spot_range = 45.0 if lit[i][2] else 30.0
			l.spot_angle = 34.0 if lit[i][2] else 28.0
		else:
			l.light_energy = 0.0

# now and then a plane goes over, high up, belonging to someone else's war
var amb_plane_t = 60.0
var amb_planes: Array = []

func _ambient_planes(dt: float) -> void:
	if not G.started or G.over or G.world == null:
		return
	amb_plane_t -= dt
	if amb_plane_t <= 0.0:
		amb_plane_t = randf_range(70.0, 160.0)
		var b: Rect2 = G.world.bounds
		var c = Vector3(b.get_center().x, 0, b.get_center().y)
		var a = randf() * TAU
		var dir = Vector3(cos(a), 0, sin(a))
		var R = maxf(b.size.x, b.size.y) * 0.5 + 350.0
		var start = c - dir * R + Vector3(-dir.z, 0, dir.x) * randf_range(-80.0, 80.0) + Vector3(0, randf_range(150.0, 230.0), 0)
		var n = randi_range(1, 3)
		for k in range(n):
			var pm = Reinforce._plane_mesh(randi() % 2)
			var off = Vector3(-dir.z, 0, dir.x) * (k - (n - 1) * 0.5) * 22.0 - dir * k * 14.0
			pm.global_position = start + off
			pm.look_at(pm.global_position + dir, Vector3.UP)
			amb_planes.append({"n": pm, "v": dir * randf_range(62.0, 75.0), "t": 0.0, "end": 2.0 * R / 62.0})
	for i in range(amb_planes.size() - 1, -1, -1):
		var p = amb_planes[i]
		p["t"] += dt
		if not is_instance_valid(p["n"]) or p["t"] > p["end"]:
			if is_instance_valid(p["n"]):
				p["n"].queue_free()
			amb_planes.remove_at(i)
			continue
		p["n"].global_position += p["v"] * dt
		p["e"] = p.get("e", 0.0) - dt
		if p["e"] <= 0.0:
			p["e"] = 0.3
			G.audio.engine(p["n"].global_position, 0.8, true)

# ---------------------------------------------------------------- rain (campaign storms)
var rain: CPUParticles3D = null

func set_storm(on: bool) -> void:
	if not on:
		if rain != null:
			rain.queue_free()
			rain = null
		return
	if rain != null:
		return
	rain = CPUParticles3D.new()
	var qm = QuadMesh.new()
	qm.size = Vector2(0.018, 0.55)
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.78, 0.82, 0.9, 0.22)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	qm.material = m
	rain.mesh = qm
	rain.amount = 2200
	rain.lifetime = 1.1
	rain.preprocess = 1.0
	rain.local_coords = false
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(32, 1, 32)
	rain.direction = Vector3(0.12, -1, 0.05)
	rain.spread = 2.0
	rain.gravity = Vector3(0, -9.8, 0)
	rain.initial_velocity_min = 16.0
	rain.initial_velocity_max = 20.0
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rain)

func _rain_follow() -> void:
	if rain == null:
		return
	var cam = get_viewport().get_camera_3d()
	if cam != null:
		# a box of rain in front of the camera, falling through the view whether it's low or high up
		var p = cam.global_position
		var f = -cam.global_transform.basis.z
		var q = p + f * 22.0
		rain.global_position = Vector3(q.x, q.y + 12.0, q.z)

func step(dt: float) -> void:
	_rain_follow()
	if clod_mm != null:
		_blast_step(dt)
	_cut_tick(dt)
	_idle_hide()

	_ambient_planes(dt)
	if marks_mat != null:
		marks_mat.set_shader_parameter("now", G.sim_time)
	if foot_mat != null:
		foot_mat.set_shader_parameter("now", G.sim_time)
	grass_t -= dt
	if grass_t <= 0.0 and G.world != null:
		grass_t = 0.5
		G.world.grass_recover()
	cam_now = get_viewport().get_camera_3d()
	var nn = G.main.is_night()
	if nn != night_now:
		night_now = nn
		if tracer_mat != null:
			tracer_mat.albedo_color = Color(1.0, 0.62, 0.3) if nn else Color(1.0, 0.9, 0.6)
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
		var tail: float = t["tail"]
		var thick = 1.0
		if t.has("bright") and cam_now != null:
			# thicker and longer the further away the camera is, so it stays a visible streak from above
			thick = clampf(cam_now.global_position.distance_to(t["o"] + t["dir"] * minf(t["d"], t["len"])) / 20.0, 1.0, 4.5)
			tail = 7.0 * clampf(thick * 0.6, 1.0, 2.6)
		if t["d"] - tail >= t["len"]:
			if t["mesh"]:
				t["mesh"].visible = false
			tracers.remove_at(i)
			continue
		if t["mesh"]:
			var a = maxf(0.0, t["d"] - tail)
			var b = minf(t["len"], t["d"])
			var m: MeshInstance3D = t["mesh"]
			var mid: Vector3 = t["o"] + t["dir"] * ((a + b) / 2.0)
			var up = Vector3.UP if absf(t["dir"].y) < 0.95 else Vector3.RIGHT
			m.global_transform = Transform3D(Basis.looking_at(t["dir"], up).scaled(Vector3(thick, thick, maxf(0.01, b - a))), mid)
			(m.get_child(0) as Node3D).visible = night_now or t.has("bright")
	for f in flash_lights:
		if f["t"] > 0.0:
			f["t"] -= dt
			if f["l"].light_energy > 9.0:
				f["l"].light_energy *= pow(0.02, dt)      # the big flashes die away rather than blink off
			if f["t"] <= 0.0:
				f["l"].light_energy = 0.0
				f["l"].omni_range = 9.0
	# debris settles then disappears
	for i in range(debris_list.size() - 1, -1, -1):
		var d = debris_list[i]
		d["t"] -= dt
		d["age"] = d.get("age", 0.0) + dt
		if d["age"] > 7.0 and not d.get("still", false) and is_instance_valid(d["b"]):
			var b: RigidBody3D = d["b"]
			# only once it's at rest on something: a piece still tumbling (or on nothing) is left to fall
			var p = b.global_position
			var rest = b.linear_velocity.length_squared() < 0.05 and not G.ray(p + Vector3(0, 0.1, 0), p - Vector3(0, 0.6, 0), G.L_WORLD).is_empty()
			if rest or p.y - G.world.ground_y(p.x, p.z) < 0.4:
				d["still"] = true
				b.freeze = true
				b.collision_mask = 0
			elif d["age"] > 20.0:
				d["t"] = 0.0      # stuck somewhere odd for this long: tidy it away rather than leave it hanging
		if d["t"] <= 0.0 or not is_instance_valid(d["b"]):
			if is_instance_valid(d["b"]):
				d["b"].queue_free()
			debris_list.remove_at(i)

# a ladder whose wall came down: it topples away from where the wall was and lies there a while
func falling_ladder(base: Vector3, n: Vector3, length: float) -> void:
	var b = RigidBody3D.new()
	b.collision_layer = G.L_DEBRIS
	b.collision_mask = G.L_WORLD | G.L_DEBRIS
	b.mass = 25.0
	var root = Node3D.new()
	var col = Color(0.4, 0.3, 0.2)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = col
	for e in [-0.25, 0.25]:
		var rail = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(0.07, length, 0.07)
		rail.mesh = bm
		rail.material_override = mat
		rail.position = Vector3(e, 0, 0)
		root.add_child(rail)
	var nr = int(length / 0.3)
	for k in range(1, nr):
		var rung = MeshInstance3D.new()
		var rm = BoxMesh.new()
		rm.size = Vector3(0.5, 0.04, 0.05)
		rung.mesh = rm
		rung.material_override = mat
		rung.position = Vector3(0, k * 0.3 - length / 2.0, 0)
		root.add_child(rung)
	b.add_child(root)
	var cs = CollisionShape3D.new()
	var bs = BoxShape3D.new()
	bs.size = Vector3(0.55, length, 0.08)
	cs.shape = bs
	b.add_child(cs)
	add_child(b)
	# rails along the ladder's own x, facing out from the wall
	var x_axis = Vector3(n.z, 0, -n.x)
	b.global_transform = Transform3D(Basis(x_axis, Vector3.UP, x_axis.cross(Vector3.UP)), base + Vector3(0, length / 2.0 + 0.05, 0))
	b.apply_impulse(n * 30.0, Vector3(0, length * 0.45, 0))
	var tw = b.create_tween()
	tw.tween_interval(25.0)
	tw.tween_callback(b.queue_free)

func debris(pos: Vector3, vel: Vector3, size: float, col: Color, shape: Vector3 = Vector3.ZERO) -> void:
	if debris_list.size() > 260:
		var old = debris_list.pop_front()
		if is_instance_valid(old["b"]):
			old["b"].queue_free()
	var b = RigidBody3D.new()
	b.collision_layer = G.L_DEBRIS
	b.collision_mask = G.L_WORLD | G.L_DEBRIS | G.L_BODY
	b.mass = size * 20.0
	var sz = Vector3(size * randf_range(0.6, 1.4), size * randf_range(0.5, 1.0), size * randf_range(0.6, 1.4)) if shape == Vector3.ZERO else shape
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
	debris_list.append({"b": b, "t": randf_range(150.0, 240.0)})

func clear_all() -> void:
	if marks_mm != null:
		for i in range(marks_mm.instance_count):
			marks_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0, -500, 0)))
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
	_clods_clear()
	for r in ring_pool:
		r["m"].visible = false
		r["t"] = 9.0
	for c in callouts:
		if is_instance_valid(c["l"]):
			c["l"].queue_free()
	callouts.clear()
	for p in amb_planes:
		if is_instance_valid(p["n"]):
			p["n"].queue_free()
	amb_planes.clear()
	amb_plane_t = randf_range(40.0, 90.0)

# ---------------------------------------------------------------- speech bubbles
func callout(s, text: String) -> void:
	if s.callout_cd > 0.0 or s.zombie or Fog.hidden(s):
		return
	# text over heads switched off: they still shout (you hear it), you just don't see the words
	if not G.settings["callouts"]:
		s.callout_cd = randf_range(4.0, 7.0)
		G.audio.bark(s, Voice.flavour(s, text))
		return
	# supply and logistics crews just get on with it: no chatter over trucks and ambulances
	var sv = s.vehicle
	if sv != null and is_instance_valid(sv) and (sv.kind in ["truck", "ambulance", "radar", "bridger", "supplytruck", "ammotruck"] or (sv.mission != null and sv.mission.get("type", "") in ["supply", "escort"])):
		return
	# in a big fight only the nearest few get a speech bubble at once (your own squad always does)
	var cam = get_viewport().get_camera_3d()
	var mine = G.player != null and is_instance_valid(G.player) and s.squad != null and s.squad == G.player.squad
	if cam != null and not mine and not s.is_player:
		var d = cam.global_position.distance_to(s.pos)
		var live = 0
		var farther = null
		for c in callouts:
			if c["t"] > 0.4 and is_instance_valid(c["s"]):
				live += 1
				var dc = cam.global_position.distance_to(c["s"].pos)
				if dc > d and (farther == null or dc > farther[1]):
					farther = [c, dc]
		if d > 75.0:
			return
		if live >= 4:
			if farther == null:
				return
			farther[0]["t"] = 0.0      # make room: the farthest one goes
	s.callout_cd = randf_range(4.0, 7.0)
	text = Voice.flavour(s, text)
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
	# (the words are drawn as a speech bubble on the HUD: see Hudx._bubbles; the label only keeps time)
	l.visible = false
	add_child(l)
	callouts.append({"l": l, "s": s, "t": 1.8, "text": text, "icon": bubble_icon(text)})
	G.audio.bark(s, text)

# a few words that float up from a spot and fade (+1 over a man who got a kill)
func float_text(p: Vector3, text: String, col: Color) -> void:
	var l = Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0014
	l.font_size = 30
	l.outline_size = 10
	l.modulate = col
	add_child(l)
	l.global_position = p
	var tw = l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "global_position", p + Vector3(0, 1.4, 0), 1.2).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 1.2).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)

# a little picture for the bubble, from what's being shouted
func bubble_icon(text: String) -> String:
	var t = text.to_lower()
	for k in [["grenade", "blast"], ["frag", "blast"], ["fire in the hole", "blast"], ["charge", "blast"], ["satchel", "blast"], ["hole", "blast"],
			["medic", "medic"], ["doc", "medic"], ["hit", "bleed"], ["bleeding", "bleed"], ["wounded", "bleed"],
			["reload", "rifle"], ["belt", "mg"], ["mag", "rifle"], ["ammo", "rifle"], ["out!", "rifle"],
			["tank", "vehicle"], ["armour", "vehicle"], ["vehicle", "vehicle"], ["truck", "vehicle"],
			["sniper", "sniper"], ["smoke", "blast"], ["rocket", "at"], ["rpg", "at"], ["contact", "head"], ["enemy", "head"], ["movement", "head"]]:
		if t.find(k[0]) >= 0:
			return k[1]
	return ""

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
	# the click itself: a ring that snaps in to the spot and a ripple that spreads out and fades
	var gy = G.world.ground_y(p.x, p.z)
	var at = Vector3(p.x, maxf(p.y, gy) + 0.12, p.z)
	for k in range(2):
		var r = MeshInstance3D.new()
		var tm = TorusMesh.new()
		tm.inner_radius = 1.0
		tm.outer_radius = 1.18
		tm.rings = 32
		tm.ring_segments = 6
		r.mesh = tm
		var m = StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.86, 0.3, 0.9)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.no_depth_test = true
		r.material_override = m
		add_child(r)
		r.global_position = at
		var tw = r.create_tween()
		tw.set_parallel(true)
		if k == 0:
			r.scale = Vector3(2.4, 0.15, 2.4)
			tw.tween_property(r, "scale", Vector3(0.9, 0.15, 0.9), 0.25).set_ease(Tween.EASE_OUT)
			tw.chain().tween_property(m, "albedo_color:a", 0.0, 0.5).set_delay(0.3)
		else:
			r.scale = Vector3(0.6, 0.15, 0.6)
			tw.tween_property(r, "scale", Vector3(3.2, 0.15, 3.2), 0.6).set_ease(Tween.EASE_OUT)
			tw.tween_property(m, "albedo_color:a", 0.0, 0.6)
		tw.chain().tween_callback(r.queue_free)

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
			p.amount = 5
			p.lifetime = 0.6
			p.explosiveness = 0.6
			p.spread = 20.0
			p.gravity = Vector3(0, 3.0, 0)
			p.mesh = QuadMesh.new()
			p.material_override = flame_mat
			var g = Gradient.new()
			# (deep orange and thin, so a fire is tongues of flame: bright yellow at full strength, a dozen
			# of them on top of each other, added up to one white ball of light)
			g.set_color(0, Color(1.0, 0.56, 0.16, 0.5))
			g.set_color(1, Color(0.55, 0.08, 0.02, 0.0))
			p.color_ramp = g
			p.scale_amount_curve = _grow_curve(0.55, 1.5)
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

# ---------------------------------------------------------------- rockets: a proper projectile with fins and a flame,
# leaving a thin pale smoke trail that drifts and fades
var _glow_mat: StandardMaterial3D = null

func rocket_model(faust: bool) -> Node3D:
	var n = Node3D.new()
	var body = Color(0.3, 0.33, 0.24) if not faust else Color(0.25, 0.27, 0.2)
	var L = 0.55 if not faust else 0.3
	var r = 0.045 if not faust else 0.075
	# the nose points along -z (look_at faces -z at the target)
	VModel.cyl(n, r, L, Vector3(0, 0, 0), body, "z", {"seg": 8})
	VModel.cyl(n, r, 0.16 if not faust else 0.2, Vector3(0, 0, -L * 0.5 - (0.08 if not faust else 0.1)), body.darkened(0.25), "z", {"r2": 0.005, "seg": 8, "rot": Vector3(PI, 0, 0)})
	for k in range(4):
		var f = Node3D.new()
		f.rotation.z = k * PI / 2.0
		n.add_child(f)
		VModel.box(null, f, Vector3(0.006, 0.09, 0.12), Vector3(0, r + 0.04, L * 0.42), body.darkened(0.15), {"b": 0.0})
	if _glow_mat == null:
		_glow_mat = StandardMaterial3D.new()
		_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow_mat.albedo_color = Color(1.0, 0.7, 0.3)
		_glow_mat.emission_enabled = true
		_glow_mat.emission = Color(1.0, 0.55, 0.15)
		_glow_mat.emission_energy_multiplier = 3.0
	var flame = MeshInstance3D.new()
	flame.mesh = VModel.cyl_mesh(r * 0.9, 0.22, 0.01, 8)
	flame.material_override = _glow_mat
	flame.rotation.x = PI / 2.0
	flame.position = Vector3(0, 0, L * 0.5 + 0.11)
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(flame)
	n.set_meta("flame", flame)
	return n

func rocket_trail(pos: Vector3) -> void:
	var d = _one_shot_smoke(pos, Color(0.8, 0.79, 0.76, 0.6), 2, 2.2, 0.4, 2.2, false)
	d.initial_velocity_min = 0.05
	d.initial_velocity_max = 0.3
	d.gravity = Vector3(0, 0.25, 0)

# ---------------------------------------------------------------- tread marks and exhaust
var marks_mm: MultiMesh = null
var marks_mat: ShaderMaterial = null
var marks_i = 0
var grass_t = 0.0
const MARKS = 1600
const MARK_FADE = 200.0

func _marks_setup() -> void:
	marks_mm = MultiMesh.new()
	marks_mm.transform_format = MultiMesh.TRANSFORM_3D
	marks_mm.use_custom_data = true
	var pm = PlaneMesh.new()
	pm.size = Vector2(1, 1)
	marks_mm.mesh = pm
	marks_mm.instance_count = MARKS
	for i in range(MARKS):
		marks_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0, -500, 0)))
	var sh = Shader.new()
	sh.code = """shader_type spatial;
render_mode depth_draw_never, cull_disabled, shadows_disabled;
uniform float now = 0.0;
uniform float fade = 200.0;
varying float age;
varying float kind;
void vertex() {
	age = now - INSTANCE_CUSTOM.x;
	kind = INSTANCE_CUSTOM.y;
}
void fragment() {
	float a = clamp(1.0 - age / fade, 0.0, 1.0);
	a = a * a * 0.62;
	float tread;
	if (kind > 0.5) {
		// track links: bars across, with the guide horn gap down the middle
		tread = step(0.45, fract(UV.y * 7.0)) * (1.0 - 0.6 * step(abs(UV.x - 0.5), 0.06));
	} else {
		// tyre: chevron blocks
		tread = step(0.5, fract(UV.y * 9.0 + abs(UV.x - 0.5) * 2.5));
	}
	float edge = smoothstep(0.0, 0.15, UV.x) * smoothstep(1.0, 0.85, UV.x);
	float k = a * edge * (0.55 + 0.45 * tread);
	ALBEDO = vec3(0.24, 0.2, 0.15);
	ROUGHNESS = 1.0;
	ALPHA = k;
}"""
	marks_mat = ShaderMaterial.new()
	marks_mat.shader = sh
	marks_mat.set_shader_parameter("fade", MARK_FADE)
	var mi = MultiMeshInstance3D.new()
	mi.multimesh = marks_mm
	mi.material_override = marks_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 10000.0
	add_child(mi)

# one stretch of track or tyre print, lying on the ground and fading out over a few minutes
func track_mark(p: Vector3, fwd: Vector3, w: float, l: float, tracked: bool) -> void:
	if marks_mm == null:
		_marks_setup()
	var W = G.world
	var gy = W.ground_y(p.x, p.z)
	# lie along the slope
	var f = G.flat(fwd).normalized()
	var r = Vector3(f.z, 0, -f.x)
	var y_f = W.ground_y(p.x + f.x * 0.6, p.z + f.z * 0.6) - W.ground_y(p.x - f.x * 0.6, p.z - f.z * 0.6)
	var y_r = W.ground_y(p.x + r.x * 0.4, p.z + r.z * 0.4) - W.ground_y(p.x - r.x * 0.4, p.z - r.z * 0.4)
	var along = (f * 1.2 + Vector3(0, y_f, 0)).normalized()
	var side = (r * 0.8 + Vector3(0, y_r, 0)).normalized()
	var up = side.cross(along).normalized()
	if up.y < 0.0:
		up = -up
	marks_mm.set_instance_transform(marks_i, Transform3D(Basis(side * w, up, along * l), Vector3(p.x, gy + 0.035, p.z)))
	marks_mm.set_instance_custom_data(marks_i, Color(G.sim_time, 1.0 if tracked else 0.0, 0, 0))
	marks_i = (marks_i + 1) % MARKS

# boot prints: their own small ring of marks, deepest on wet ground (rain, the beach, by the water),
# faint on dry grass, none on roads or floors
const FEET = 700
const FOOT_FADE = 110.0
var foot_mm: MultiMesh = null
var foot_mat: ShaderMaterial = null
var foot_i = 0

func _feet_setup() -> void:
	foot_mm = MultiMesh.new()
	foot_mm.transform_format = MultiMesh.TRANSFORM_3D
	foot_mm.use_custom_data = true
	var pm = PlaneMesh.new()
	pm.size = Vector2(1, 1)
	foot_mm.mesh = pm
	foot_mm.instance_count = FEET
	for i in range(FEET):
		foot_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0, -500, 0)))
	var sh = Shader.new()
	sh.code = """shader_type spatial;
render_mode depth_draw_never, cull_disabled, shadows_disabled;
uniform float now = 0.0;
uniform float fade = 110.0;
varying float age;
varying float depth;
void vertex() {
	age = now - INSTANCE_CUSTOM.x;
	depth = INSTANCE_CUSTOM.y;
}
void fragment() {
	// a sole and a heel, with a few tread bars across the sole
	vec2 q = UV - vec2(0.5);
	float sole = 1.0 - smoothstep(0.85, 1.0, length(vec2(q.x / 0.42, (q.y + 0.12) / 0.36)));
	float heel = 1.0 - smoothstep(0.85, 1.0, length(vec2(q.x / 0.36, (q.y - 0.3) / 0.17)));
	float shape = max(sole, heel);
	float bars = 0.7 + 0.3 * step(0.5, fract(UV.y * 8.0));
	float a = clamp(1.0 - age / fade, 0.0, 1.0);
	ALBEDO = vec3(0.2, 0.17, 0.13);
	ROUGHNESS = 1.0;
	ALPHA = shape * bars * a * a * depth;
}"""
	foot_mat = ShaderMaterial.new()
	foot_mat.shader = sh
	foot_mat.set_shader_parameter("fade", FOOT_FADE)
	var mi = MultiMeshInstance3D.new()
	mi.multimesh = foot_mm
	mi.material_override = foot_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 10000.0
	add_child(mi)

func footprint(p: Vector3, yaw: float, left: bool) -> void:
	if cam_now == null or cam_now.global_position.distance_squared_to(p) > 55.0 * 55.0:
		return
	var W = G.world
	var gy = W.ground_y(p.x, p.z)
	if absf(p.y - gy) > 0.4 or W.on_road(p.x, p.z):
		return
	var wet = rain != null or G.map_id == "beach" or (not W.water.is_empty() and W.near_water(p.x, p.z, 8.0))
	if foot_mm == null:
		_feet_setup()
	var f = Vector3(sin(yaw), 0, cos(yaw))
	var r = Vector3(f.z, 0, -f.x)
	var at = p + r * (0.11 if left else -0.11)
	foot_mm.set_instance_transform(foot_i, Transform3D(Basis(r * 0.13, Vector3.UP, -f * 0.3), Vector3(at.x, W.ground_y(at.x, at.z) + 0.03, at.z)))
	foot_mm.set_instance_custom_data(foot_i, Color(G.sim_time, 0.75 if wet else 0.32, 0, 0))
	foot_i = (foot_i + 1) % FEET

# a puff from the exhaust pipe: heavy and dark under load, faint at idle
func exhaust(p: Vector3, back: Vector3, k: float, diesel: bool) -> void:
	var c = Color(0.16, 0.15, 0.14, 0.55 * k + 0.12) if diesel else Color(0.42, 0.42, 0.42, 0.35 * k + 0.1)
	var e = _one_shot_smoke(p, c, 1 if k < 0.5 else 2, 1.2 + 1.2 * k, 0.18 + 0.15 * k, 0.8 + 1.4 * k, false)
	e.direction = (back + Vector3(0, 0.6, 0)).normalized()
	e.spread = 20.0
	e.initial_velocity_min = 0.6 + 1.6 * k
	e.initial_velocity_max = 1.0 + 2.4 * k
	e.gravity = Vector3(0, 0.6, 0)
	e.damping_min = 0.8
	e.damping_max = 1.4

# a magazine lobbed from one man to another
func toss_mag(from: Vector3, to: Vector3) -> void:
	var m = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(0.05, 0.16, 0.08)
	m.mesh = bm
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.18, 0.17)
	m.material_override = mat
	add_child(m)
	m.global_position = from
	var tw = m.create_tween()
	tw.tween_method(func(k: float):
		if is_instance_valid(m):
			m.global_position = from.lerp(to, k) + Vector3(0, sin(k * PI) * 1.2, 0)
			m.rotation = Vector3(k * 9.0, k * 4.0, 0), 0.0, 1.0, 0.55)
	tw.tween_callback(m.queue_free)

# The smoke, spark and dust emitters are kept ready in pools, a few hundred of them, and one that's doing
# nothing was still a draw every frame. They're only shown while they have something in the air.
var emitters: Array = []
func _idle_hide() -> void:
	if not emitters.is_empty() and not is_instance_valid(emitters[0]):
		emitters = []
	if emitters.is_empty():
		for pool in [dust_pool, blood_pool, spark_pool, dirt_pool, ember_pool]:
			for e in pool:
				if e is CPUParticles3D:
					emitters.append(e)
		if emitters.is_empty():
			return
	var now = G.sim_time
	for e in emitters:
		if e.emitting:
			e.set_meta("live_t", now + e.lifetime + 0.4)
			if not e.visible:
				e.visible = true
		elif e.visible and now > float(e.get_meta("live_t", 0.0)):
			e.visible = false
