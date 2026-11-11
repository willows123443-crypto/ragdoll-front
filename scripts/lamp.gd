class_name Lamp
extends RefCounted
# A light you can see: a glowing lens with a soft flare when it points your way, a beam of light in the
# air that stops where it hits something (so it never shines through a wall), and a soft pool of light
# on whatever it lands on. Weapon lights and vehicle headlights both use it; the nearest few also get a
# real spotlight (see Fx._torches).

static var _glow_tex: GradientTexture2D = null
static var _glow_mat: StandardMaterial3D = null
static var _pool_mat: StandardMaterial3D = null

static func glow_tex() -> GradientTexture2D:
	if _glow_tex == null:
		var g = Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.25, Color(1, 1, 1, 0.65))
		g.add_point(0.6, Color(1, 1, 1, 0.12))
		_glow_tex = GradientTexture2D.new()
		_glow_tex.gradient = g
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(0.5, 0.0)
		_glow_tex.width = 64
		_glow_tex.height = 64
	return _glow_tex

static func _mats() -> void:
	if _glow_mat != null:
		return
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glow_mat.albedo_texture = glow_tex()
	_glow_mat.albedo_color = Color(1.0, 0.97, 0.9, 1.0)
	_glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_glow_mat.no_depth_test = false
	_glow_mat.disable_receive_shadows = true
	_pool_mat = StandardMaterial3D.new()
	_pool_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_pool_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pool_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_pool_mat.albedo_texture = glow_tex()
	_pool_mat.albedo_color = Color(0.75, 0.8, 0.85, 0.55)
	_pool_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

# reach: how far the beam goes; spread: how fast it widens (radius per metre); lens: size of the lens
static func make(parent: Node3D, reach: float, spread: float, lens: float, warm: bool) -> Node3D:
	_mats()
	var n = Node3D.new()
	parent.add_child(n)
	n.set_meta("reach", reach)
	n.set_meta("spread", spread)
	n.set_meta("cd", 0)
	var lm = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = lens
	cm.bottom_radius = lens
	cm.height = 0.02
	cm.radial_segments = 10
	lm.mesh = cm
	var em = StandardMaterial3D.new()
	em.albedo_color = Color(1.0, 0.96, 0.85) if warm else Color(0.92, 0.96, 1.0)
	em.emission_enabled = true
	em.emission = em.albedo_color
	em.emission_energy_multiplier = 4.0
	lm.material_override = em
	lm.rotation.x = PI / 2.0
	n.add_child(lm)
	# the flare round the lens
	var fl = MeshInstance3D.new()
	var q = QuadMesh.new()
	q.size = Vector2(lens * 9.0, lens * 9.0)
	fl.mesh = q
	fl.material_override = _glow_mat
	fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fl.position = Vector3(0, 0, 0.03)
	fl.name = "flare"
	n.add_child(fl)
	# the beam: a cone of light in the air
	var beam = MeshInstance3D.new()
	var bm = CylinderMesh.new()
	bm.top_radius = spread * 10.0 + lens
	bm.bottom_radius = lens
	bm.height = 10.0
	bm.radial_segments = 16
	bm.rings = 6
	bm.cap_top = false
	bm.cap_bottom = false
	beam.mesh = bm
	beam.material_override = Soldier.get_beam_mat()
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.name = "beam"
	n.add_child(beam)
	# the pool of light where it lands (kept in world space)
	var pool = MeshInstance3D.new()
	var pq = QuadMesh.new()
	pq.size = Vector2(1, 1)
	pool.mesh = pq
	pool.material_override = _pool_mat.duplicate()
	if warm:
		pool.material_override.albedo_color = Color(0.95, 0.86, 0.66, 0.38)
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pool.top_level = true
	pool.name = "pool"
	n.add_child(pool)
	_set_len(n, reach)
	return n

static func _set_len(n: Node3D, d: float) -> void:
	var beam: MeshInstance3D = n.get_node("beam")
	var k = maxf(d, 0.3) / 10.0
	beam.transform = Transform3D(Basis(Vector3.RIGHT, PI / 2.0).scaled(Vector3(k, k, k)), Vector3(0, 0, 5.0 * k))

# where the beam ends and the pool of light lands; done a few times a second, and only near the camera
static func update(n: Node3D, cam: Camera3D) -> void:
	if n == null or not n.is_visible_in_tree():
		return
	var o = n.global_position
	var fl: MeshInstance3D = n.get_node("flare")
	var fwd = n.global_transform.basis.z.normalized()
	if cam != null:
		var to_cam = (cam.global_position - o).normalized()
		var face = clampf(fwd.dot(to_cam), 0.0, 1.0)
		fl.visible = face > 0.15
		fl.scale = Vector3.ONE * (0.4 + 1.4 * face * face)
		if cam.global_position.distance_to(o) > 120.0:
			return
	var cd: int = n.get_meta("cd")
	n.set_meta("cd", cd - 1)
	if cd > 0:
		return
	n.set_meta("cd", 3)
	var reach: float = n.get_meta("reach")
	var hit = G.ray(o + fwd * 0.1, o + fwd * reach, n.get_meta("mask", G.L_WORLD | G.L_VEH))
	var pool: MeshInstance3D = n.get_node("pool")
	if hit.is_empty():
		_set_len(n, reach)
		pool.visible = false
		return
	var d = o.distance_to(hit.position)
	_set_len(n, d)
	var nrm: Vector3 = hit.normal
	var r = n.get_meta("spread") * d + 0.25
	# a stretched ellipse when it glances along the ground, a round spot on a wall it hits square on
	var glance = clampf(absf(fwd.dot(nrm)), 0.25, 1.0)
	var up = nrm
	var side = fwd.cross(up)
	if side.length_squared() < 0.001:
		side = Vector3.RIGHT.cross(up)
	side = side.normalized()
	var along = up.cross(side).normalized()
	pool.visible = true
	pool.global_transform = Transform3D(Basis(side * r * 2.0, along * r * 2.0 / glance, up), hit.position + nrm * 0.04)
	var m: StandardMaterial3D = pool.material_override
	m.albedo_color.a = clampf(0.75 * (1.0 - d / reach) + 0.15, 0.1, 0.8) * (0.75 + 0.25 * glance)
