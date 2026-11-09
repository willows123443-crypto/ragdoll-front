class_name VModel
extends RefCounted
# Vehicle models: bevelled panels, round wheels and barrels, doors that swing open,
# and team insignia. Even teams get a rounded "cast" look, odd teams an angular welded one,
# so friend and foe read differently at a glance as well as by colour.
# Local axes: +z forward, +x the vehicle's left, +y up.

static var bevel_cache = {}
static var cyl_cache = {}
static var mats = {}
static var bare = false          # emplacements built in a dug pit: no sandbags of their own

const TYRE = Color(0.07, 0.07, 0.07)
const METAL = Color(0.15, 0.15, 0.14)
const WOOD = Color(0.42, 0.33, 0.22)
const CANVAS_A = Color(0.5, 0.48, 0.36)
const CANVAS_B = Color(0.42, 0.42, 0.38)

static func mat(c: Color) -> StandardMaterial3D:
	var k = c.to_html()
	if not mats.has(k):
		var m = StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.75
		mats[k] = m
	return mats[k]

static func glass() -> StandardMaterial3D:
	if not mats.has("glass"):
		var m = StandardMaterial3D.new()
		m.albedo_color = Color(0.32, 0.42, 0.48)
		m.roughness = 0.1
		m.metallic = 0.4
		mats["glass"] = m
	return mats["glass"]

static func lamp() -> StandardMaterial3D:
	if not mats.has("lamp"):
		var m = StandardMaterial3D.new()
		m.albedo_color = Color(0.95, 0.9, 0.7)
		m.emission_enabled = true
		m.emission = Color(0.5, 0.45, 0.3)
		mats["lamp"] = m
	return mats["lamp"]

# a box with chamfered edges and flat shading
static func bevel_mesh(size: Vector3, b: float) -> ArrayMesh:
	b = minf(b, minf(size.x, minf(size.y, size.z)) * 0.3)
	var key = "%.3f_%.3f_%.3f_%.3f" % [size.x, size.y, size.z, b]
	if bevel_cache.has(key):
		return bevel_cache[key]
	var h = size / 2.0
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var polys = []
	for a in range(3):
		var o1 = (a + 1) % 3
		var o2 = (a + 2) % 3
		for sa in [-1.0, 1.0]:
			var q = []
			for ss in [[-1.0, -1.0], [1.0, -1.0], [1.0, 1.0], [-1.0, 1.0]]:
				var s = Vector3.ZERO
				s[a] = sa
				s[o1] = ss[0]
				s[o2] = ss[1]
				q.append(_bp(h, b, s, a))
			polys.append(q)
	for a in range(3):
		for c in range(a + 1, 3):
			var t = 3 - a - c
			for sa in [-1.0, 1.0]:
				for sc in [-1.0, 1.0]:
					var s0 = Vector3.ZERO
					s0[a] = sa
					s0[c] = sc
					s0[t] = -1.0
					var s1 = s0
					s1[t] = 1.0
					polys.append([_bp(h, b, s0, a), _bp(h, b, s0, c), _bp(h, b, s1, c), _bp(h, b, s1, a)])
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var s = Vector3(sx, sy, sz)
				polys.append([_bp(h, b, s, 0), _bp(h, b, s, 1), _bp(h, b, s, 2)])
	for p in polys:
		var cen = Vector3.ZERO
		for v in p:
			cen += v
		cen /= p.size()
		var n: Vector3 = (p[1] - p[0]).cross(p[2] - p[0])
		if n.length() < 0.000001:
			continue
		if n.dot(cen) > 0.0:
			p.reverse()
			n = -n
		var nn = -n.normalized()
		for i in range(1, p.size() - 1):
			for v in [p[0], p[i], p[i + 1]]:
				st.set_normal(nn)
				st.add_vertex(v)
	var m = st.commit()
	bevel_cache[key] = m
	return m

static func _bp(h: Vector3, b: float, s: Vector3, a: int) -> Vector3:
	var p = Vector3(s.x * (h.x - b), s.y * (h.y - b), s.z * (h.z - b))
	p[a] = s[a] * h[a]
	return p

static func cyl_mesh(r: float, h: float, r2: float = -1.0, seg: int = 12) -> CylinderMesh:
	var key = "%.3f_%.3f_%.3f_%d" % [r, h, r2, seg]
	if not cyl_cache.has(key):
		var cm = CylinderMesh.new()
		cm.bottom_radius = r
		cm.top_radius = r if r2 < 0.0 else r2
		cm.height = h
		cm.radial_segments = seg
		cm.rings = 1
		cyl_cache[key] = cm
	return cyl_cache[key]

static func box(v, parent: Node3D, size: Vector3, at: Vector3, c: Color, opt: Dictionary = {}) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = bevel_mesh(size, opt.get("b", 0.05))
	mi.material_override = opt.get("m", mat(c))
	mi.position = at
	mi.rotation = opt.get("rot", Vector3.ZERO)
	parent.add_child(mi)
	if opt.get("col", false):
		col(v, size, at)
	return mi

static func col(v, size: Vector3, at: Vector3) -> void:
	var cs = CollisionShape3D.new()
	var bs = BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = at
	v.body.add_child(cs)

# axis: "x", "y" or "z"
static func cyl(parent: Node3D, r: float, h: float, at: Vector3, c: Color, axis: String = "y", opt: Dictionary = {}) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = cyl_mesh(r, h, opt.get("r2", -1.0), opt.get("seg", 12))
	mi.material_override = opt.get("m", mat(c))
	mi.position = at
	if axis == "x":
		mi.rotation.z = PI / 2.0
	elif axis == "z":
		mi.rotation.x = PI / 2.0
	if opt.has("rot"):
		mi.rotation += opt["rot"]
	if opt.has("scale"):
		mi.scale = opt["scale"]
	parent.add_child(mi)
	return mi

static func ball(parent: Node3D, size: Vector3, at: Vector3, c: Color, opt: Dictionary = {}) -> MeshInstance3D:
	if not cyl_cache.has("ball"):
		var sm = SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		sm.radial_segments = 14
		sm.rings = 7
		cyl_cache["ball"] = sm
	var mi = MeshInstance3D.new()
	mi.mesh = cyl_cache["ball"]
	mi.material_override = opt.get("m", mat(c))
	mi.position = at
	mi.scale = size
	mi.rotation = opt.get("rot", Vector3.ZERO)
	parent.add_child(mi)
	return mi

# a road wheel: tyre, rim and hub cap, spun by the vehicle
static func wheel(v, at: Vector3, r: float, w: float, rim: Color, spin: bool = true) -> Node3D:
	var hub = Node3D.new()
	hub.position = at
	v.add_child(hub)
	cyl(hub, r, w, Vector3.ZERO, TYRE, "x", {"seg": 16})
	cyl(hub, r * 0.62, w + 0.03, Vector3.ZERO, rim, "x", {"seg": 10})
	cyl(hub, r * 0.2, w + 0.07, Vector3.ZERO, METAL, "x", {"seg": 8})
	# tread blocks so the spin shows
	for k in range(6):
		var a = k * TAU / 6.0
		box(v, hub, Vector3(w + 0.02, 0.07, 0.1), Vector3(0, cos(a) * (r - 0.02), sin(a) * (r - 0.02)), TYRE, {"rot": Vector3(-a, 0, 0), "b": 0.01})
	if spin:
		v.wheels.append(hub)
	return hub

# a side or rear door on a hinge; opens when someone gets in or out
# panel runs along local -z from the hinge
static func door(v, parent: Node3D, hinge: Vector3, w: float, h: float, c: Color, open: float, yaw0: float = 0.0, win: bool = false, center: Vector3 = Vector3.INF) -> Node3D:
	var n = Node3D.new()
	n.position = hinge
	n.rotation.y = yaw0
	parent.add_child(n)
	box(v, n, Vector3(0.06, h, w), Vector3(0, h / 2.0, -w / 2.0), c, {"b": 0.025})
	# seam lines and a handle
	box(v, n, Vector3(0.075, h * 0.9, 0.03), Vector3(0, h / 2.0, -0.03), c.darkened(0.35), {"b": 0.005})
	box(v, n, Vector3(0.075, h * 0.9, 0.03), Vector3(0, h / 2.0, -w + 0.03), c.darkened(0.35), {"b": 0.005})
	box(v, n, Vector3(0.1, 0.05, 0.18), Vector3(0, h * 0.55, -w + 0.2), METAL, {"b": 0.01})
	if win:
		box(v, n, Vector3(0.07, 0.04, w * 0.8), Vector3(0, h + 0.02, -w / 2.0), c.darkened(0.2), {"b": 0.01})
		for z in [-0.06, -w + 0.06]:
			box(v, n, Vector3(0.07, 0.6, 0.05), Vector3(0, h + 0.3, z), c.darkened(0.2), {"b": 0.01})
		box(v, n, Vector3(0.07, 0.05, w), Vector3(0, h + 0.6, -w / 2.0), c.darkened(0.2), {"b": 0.01})
	var cen = center
	if cen == Vector3.INF:
		cen = hinge + Basis(Vector3.UP, yaw0) * Vector3(0, 0, -w / 2.0)
	v.doors.append({"n": n, "open": yaw0 + open, "shut": yaw0, "t": 0.0, "c": cen})
	return n

# team insignia, flat on a face. face: "x+", "x-", "y", "z+", "z-"
static func insignia(v, parent: Node3D, at: Vector3, face: String, s: float) -> Node3D:
	var n = Node3D.new()
	n.position = at
	match face:
		"x+":
			n.rotation.y = PI / 2.0
		"x-":
			n.rotation.y = -PI / 2.0
		"y":
			n.rotation.x = -PI / 2.0
		"z-":
			n.rotation.y = PI
	parent.add_child(n)
	var band: Color = G.team_color(v.team)
	var white = Color(0.92, 0.92, 0.9) if band.get_luminance() < 0.75 else Color(0.12, 0.12, 0.12)
	match v.team % 4:
		0:  # roundel
			cyl(n, s, 0.02, Vector3(0, 0, 0.01), band, "z", {"seg": 20})
			cyl(n, s * 0.66, 0.02, Vector3(0, 0, 0.02), white, "z", {"seg": 20})
			cyl(n, s * 0.33, 0.02, Vector3(0, 0, 0.03), band, "z", {"seg": 16})
		1:  # saltire on a dark square
			box(v, n, Vector3(s * 1.7, s * 1.7, 0.02), Vector3(0, 0, 0.01), Color(0.1, 0.1, 0.1), {"b": 0.0})
			box(v, n, Vector3(s * 2.0, s * 0.36, 0.02), Vector3(0, 0, 0.025), band, {"b": 0.0, "rot": Vector3(0, 0, PI / 4.0)})
			box(v, n, Vector3(s * 2.0, s * 0.36, 0.02), Vector3(0, 0, 0.025), band, {"b": 0.0, "rot": Vector3(0, 0, -PI / 4.0)})
		2:  # diamond
			box(v, n, Vector3(s * 1.4, s * 1.4, 0.02), Vector3(0, 0, 0.01), white, {"b": 0.0, "rot": Vector3(0, 0, PI / 4.0)})
			box(v, n, Vector3(s * 1.0, s * 1.0, 0.02), Vector3(0, 0, 0.025), band, {"b": 0.0, "rot": Vector3(0, 0, PI / 4.0)})
		_:  # triangle
			cyl(n, s * 1.1, 0.02, Vector3(0, 0, 0.01), white, "z", {"seg": 3, "rot": Vector3(0, 0, PI / 2.0)})
			cyl(n, s * 0.75, 0.02, Vector3(0, 0, 0.025), band, "z", {"seg": 3, "rot": Vector3(0, 0, PI / 2.0)})
	return n

static func antenna(v, parent: Node3D, at: Vector3, h: float) -> void:
	cyl(parent, 0.012, h, at + Vector3(0, h / 2.0, 0), METAL, "y", {"seg": 4})
	box(v, parent, Vector3(0.02, 0.22, 0.4), at + Vector3(0, h - 0.13, -0.2), G.team_color(v.team), {"b": 0.0})

static func mg(v, parent: Node3D, at: Vector3, l: float = 0.9) -> void:
	box(v, parent, Vector3(0.16, 0.18, l * 0.55), at + Vector3(0, 0, l * 0.1), Color(0.12, 0.12, 0.12), {"b": 0.03})
	cyl(parent, 0.045, l * 0.75, at + Vector3(0, 0.02, l * 0.62), Color(0.1, 0.1, 0.1), "z", {"seg": 8})
	cyl(parent, 0.06, 0.18, at + Vector3(0, 0.02, l * 0.45), Color(0.1, 0.1, 0.1), "z", {"seg": 8})
	box(v, parent, Vector3(0.06, 0.16, 0.1), at + Vector3(0, -0.12, l * 0.05), Color(0.2, 0.15, 0.1), {"b": 0.01})
	box(v, parent, Vector3(0.12, 0.14, 0.22), at + Vector3(0.12, -0.04, l * 0.1), Color(0.3, 0.3, 0.22), {"b": 0.02})

static func sandbag_ring(v, parent: Node3D, pts: Array, rows: int, c: Color) -> void:
	# pts: [Vector3 start, Vector3 end] segments; bags lie along the wall, staggered like bricks
	for seg in pts:
		var a: Vector3 = seg[0]
		var b: Vector3 = seg[1]
		var L = a.distance_to(b)
		var dir = (b - a).normalized()
		var yaw = atan2(dir.x, dir.z)
		var n = maxi(1, ceili(L / 0.58))
		for r in range(rows):
			var off = 0.5 if r % 2 == 1 else 0.0
			for i in range(n):
				var t = (i + 0.5 + off) / n
				if t > 1.0:
					continue
				var p = a.lerp(b, t) + Vector3(0, 0.12 + r * 0.21, 0)
				var bc = c.darkened(randf_range(0.0, 0.12))
				ball(parent, Vector3(0.46, 0.26, 0.68), p, bc, {"rot": Vector3(0, yaw + randf_range(-0.06, 0.06), 0)})

static func build(v) -> void:
	var team: int = v.team
	var rnd = team % 2 == 0          # rounded cast style vs angular welded style
	var base: Color = G.TEAM_UNI[team].lerp(Color(0.35, 0.36, 0.3), 0.35)
	var dark = base.darkened(0.35)
	var band: Color = G.team_color(team)
	var rim = base.darkened(0.15)
	var hull: Node3D = v
	match v.kind:
		"jeep":
			col(v, Vector3(1.9, 0.9, 4.0), Vector3(0, 0.85, 0))
			box(v, hull, Vector3(1.6, 0.18, 4.0), Vector3(0, 0.5, 0), METAL)
			box(v, hull, Vector3(1.86, 0.2, 2.9), Vector3(0, 0.68, -0.5), base)
			for x in [0.92, -0.92]:
				box(v, hull, Vector3(0.08, 0.45, 1.55), Vector3(x, 0.98, -1.2), base, {"b": 0.03})
			box(v, hull, Vector3(1.9, 0.45, 0.08), Vector3(0, 0.98, -1.96), base, {"b": 0.03})
			box(v, hull, Vector3(1.86, 0.55, 0.3), Vector3(0, 1.02, 0.78), base, {"b": 0.04})
			if rnd:
				box(v, hull, Vector3(1.5, 0.42, 1.3), Vector3(0, 1.0, 1.45), base, {"b": 0.1})
				box(v, hull, Vector3(1.1, 0.42, 0.06), Vector3(0, 0.98, 2.1), dark, {"b": 0.02})
				for k in range(7):
					box(v, hull, Vector3(0.05, 0.36, 0.04), Vector3(-0.45 + k * 0.15, 0.98, 2.13), METAL, {"b": 0.0})
				for x in [0.55, -0.55]:
					cyl(hull, 0.1, 0.08, Vector3(x, 1.12, 2.12), Color.WHITE, "z", {"m": lamp()})
				for z in [1.35, -1.3]:
					for x in [0.92, -0.92]:
						box(v, hull, Vector3(0.36, 0.06, 1.0), Vector3(x, 0.9, z), base, {"b": 0.03})
			else:
				box(v, hull, Vector3(1.6, 0.36, 1.35), Vector3(0, 0.98, 1.42), base, {"b": 0.03, "rot": Vector3(0.12, 0, 0)})
				box(v, hull, Vector3(1.6, 0.4, 0.06), Vector3(0, 0.82, 2.08), base, {"b": 0.02, "rot": Vector3(-0.5, 0, 0)})
				for x in [0.92, -0.92]:
					for k in range(3):
						box(v, hull, Vector3(0.03, 0.035, 2.6), Vector3(x * 1.03, 0.85 + k * 0.11, -0.5), base.darkened(0.15), {"b": 0.0})
					cyl(hull, 0.09, 0.08, Vector3(x * 0.8, 1.02, 1.85), Color.WHITE, "z", {"m": lamp()})
				for z in [1.35, -1.3]:
					for x in [0.92, -0.92]:
						box(v, hull, Vector3(0.36, 0.05, 1.0), Vector3(x, 0.9, z), base, {"b": 0.01})
			for x in [0.93, -0.93]:
				door(v, hull, Vector3(x, 0.76, 0.62), 0.95, 0.46 if rnd else 0.52, base, -signf(x) * 1.2)
			# windscreen
			var tilt = 0.0 if rnd else -0.22
			var ws = Node3D.new()
			ws.position = Vector3(0, 1.22, 0.78)
			ws.rotation.x = tilt
			hull.add_child(ws)
			for x in [0.8, -0.8]:
				box(v, ws, Vector3(0.06, 0.55, 0.06), Vector3(x, 0.25, 0), dark, {"b": 0.01})
			box(v, ws, Vector3(1.66, 0.06, 0.06), Vector3(0, 0.52, 0), dark, {"b": 0.01})
			box(v, ws, Vector3(1.55, 0.46, 0.02), Vector3(0, 0.26, 0), dark, {"m": glass(), "b": 0.0})
			for x in [0.45, -0.45]:
				box(v, hull, Vector3(0.55, 0.16, 0.55), Vector3(x, 0.84, 0.1), dark, {"b": 0.05})
				box(v, hull, Vector3(0.55, 0.5, 0.12), Vector3(x, 1.06, -0.2), dark, {"b": 0.05})
			box(v, hull, Vector3(1.3, 0.16, 0.55), Vector3(-0.2, 0.84, -0.9), dark, {"b": 0.05})
			cyl(hull, 0.18, 0.04, Vector3(0.45, 1.28, 0.52), METAL, "y", {"rot": Vector3(-1.0, 0, 0), "seg": 10})
			if rnd:
				cyl(hull, 0.36, 0.2, Vector3(0, 1.0, -2.1), TYRE, "z", {"seg": 14})
			else:
				for x in [0.35, -0.35]:
					box(v, hull, Vector3(0.3, 0.45, 0.16), Vector3(x, 1.0, -2.08), dark.darkened(0.2), {"b": 0.03})
			box(v, hull, Vector3(1.7, 0.08, 0.04), Vector3(0, 1.18, -1.99), band, {"b": 0.0})
			insignia(v, hull, Vector3(0, 1.22 if rnd else 1.18, 1.45), "y", 0.3)
			for x in [0.97, -0.97]:
				insignia(v, hull, Vector3(x, 0.98, -1.2), "x+" if x > 0 else "x-", 0.17)
			antenna(v, hull, Vector3(-0.85, 1.2, -1.85), 2.0)
			for z in [1.35, -1.3]:
				for x in [0.95, -0.95]:
					wheel(v, Vector3(x, 0.42, z), 0.42, 0.3, rim)
			v.turret = Node3D.new()
			v.turret.position = Vector3(0, 1.6, -0.62)
			hull.add_child(v.turret)
			cyl(v.turret, 0.06, 0.85, Vector3(0, -0.42, 0), dark, "y", {"seg": 8})
			v.gun_pivot = Node3D.new()
			v.gun_pivot.position = Vector3(0, 0.15, 0)
			v.turret.add_child(v.gun_pivot)
			mg(v, v.gun_pivot, Vector3(0, 0, 0.1))
			box(v, v.gun_pivot, Vector3(0.6, 0.4, 0.04), Vector3(0, 0.1, 0.45), dark, {"b": 0.02})
		"truck", "ambulance", "radar":
			col(v, Vector3(2.4, 0.5, 7.0), Vector3(0, 0.95, 0))
			col(v, Vector3(2.3, 0.75, 1.8), Vector3(0, 1.55, 2.5))
			box(v, hull, Vector3(1.6, 0.3, 7.0), Vector3(0, 0.85, 0), METAL)
			box(v, hull, Vector3(2.2, 0.75, 1.75), Vector3(0, 1.55, 2.5), base, {"b": 0.06})
			box(v, hull, Vector3(2.32, 0.12, 1.85), Vector3(0, 2.62, 2.5), base, {"b": 0.05})
			for x in [1.12, -1.12]:
				box(v, hull, Vector3(0.08, 0.7, 0.1), Vector3(x, 2.27, 3.35), base, {"b": 0.02})
				box(v, hull, Vector3(0.08, 1.1, 0.12), Vector3(x, 2.07, 1.65), base, {"b": 0.02})
			box(v, hull, Vector3(2.2, 0.85, 0.08), Vector3(0, 2.12, 1.62), base, {"b": 0.02})
			box(v, hull, Vector3(2.1, 0.6, 0.02), Vector3(0, 2.25, 3.38), base, {"m": glass(), "b": 0.0, "rot": Vector3(-0.08, 0, 0)})
			for x in [1.17, -1.17]:
				var d = door(v, hull, Vector3(x, 1.2, 3.3), 1.45, 0.9, base, -signf(x) * 1.15, 0.0, true)
				insignia(v, d, Vector3(signf(x) * 0.035, 0.45, -0.75), "x+" if x > 0 else "x-", 0.22)
			if rnd:
				box(v, hull, Vector3(1.7, 0.8, 1.25), Vector3(0, 1.5, 3.98), base, {"b": 0.22})
				for x in [1.0, -1.0]:
					box(v, hull, Vector3(0.5, 0.35, 1.35), Vector3(x, 1.1, 3.75), base, {"b": 0.16})
			else:
				box(v, hull, Vector3(2.1, 0.78, 1.15), Vector3(0, 1.48, 3.92), base, {"b": 0.04})
				for x in [1.0, -1.0]:
					box(v, hull, Vector3(0.55, 0.08, 1.25), Vector3(x, 1.2, 3.75), base.darkened(0.1), {"b": 0.02, "rot": Vector3(-0.15, 0, 0)})
			box(v, hull, Vector3(1.3, 0.62, 0.06), Vector3(0, 1.5, 4.6), dark, {"b": 0.02})
			for k in range(8):
				box(v, hull, Vector3(0.05, 0.56, 0.04), Vector3(-0.56 + k * 0.16, 1.5, 4.64), METAL, {"b": 0.0})
			for x in [0.85, -0.85]:
				cyl(hull, 0.13, 0.1, Vector3(x, 1.68, 4.58), Color.WHITE, "z", {"m": lamp()})
			box(v, hull, Vector3(2.4, 0.16, 0.15), Vector3(0, 0.98, 4.66), METAL, {"b": 0.04})
			cyl(hull, 0.07, 1.4, Vector3(1.05, 2.4, 1.52), METAL, "y", {"seg": 8})
			cyl(hull, 0.26, 0.9, Vector3(-1.15, 1.05, 1.0), dark, "z")
			if v.kind == "ambulance":
				# a closed white box body with red crosses
				var wc = Color(0.86, 0.86, 0.82)
				box(v, hull, Vector3(2.45, 2.0, 4.7), Vector3(0, 2.3, -1.2), wc, {"b": 0.06})
				var rc = Color(0.8, 0.12, 0.12)
				for x in [1.24, -1.24]:
					var cn = Node3D.new()
					cn.position = Vector3(x, 2.4, -1.2)
					cn.rotation.y = PI / 2.0 if x > 0 else -PI / 2.0
					hull.add_child(cn)
					box(v, cn, Vector3(1.0, 0.3, 0.02), Vector3.ZERO, rc, {"b": 0.0})
					box(v, cn, Vector3(0.3, 1.0, 0.02), Vector3.ZERO, rc, {"b": 0.0})
				var top = Node3D.new()
				top.position = Vector3(0, 3.31, -1.2)
				top.rotation.x = -PI / 2.0
				hull.add_child(top)
				box(v, top, Vector3(1.2, 0.36, 0.02), Vector3.ZERO, rc, {"b": 0.0})
				box(v, top, Vector3(0.36, 1.2, 0.02), Vector3.ZERO, rc, {"b": 0.0})
				box(v, hull, Vector3(2.0, 1.6, 0.05), Vector3(0, 2.2, -3.56), wc.darkened(0.1), {"b": 0.01})
				for z in [2.4, -0.4, -2.6]:
					for x in [1.1, -1.1]:
						wheel(v, Vector3(x, 0.55, z), 0.55, 0.4, rim)
				return
			if v.kind == "radar":
				# a closed command body with a turning radar dish and aerials
				var bc = base.darkened(0.08)
				box(v, hull, Vector3(2.45, 1.9, 4.7), Vector3(0, 2.25, -1.2), bc, {"b": 0.06})
				for k in range(3):
					box(v, hull, Vector3(0.04, 0.4, 0.6), Vector3(1.24, 2.4, -2.5 + k * 1.2), Color(0.2, 0.24, 0.28), {"b": 0.0})
				cyl(hull, 0.12, 0.6, Vector3(0, 3.5, -1.6), METAL, "y", {"seg": 8})
				v.rotor = Node3D.new()
				v.rotor.position = Vector3(0, 3.85, -1.6)
				hull.add_child(v.rotor)
				box(v, v.rotor, Vector3(2.4, 0.9, 0.08), Vector3(0, 0.3, 0), Color(0.6, 0.62, 0.6), {"b": 0.02, "rot": Vector3(-0.3, 0, 0)})
				for x in [-0.9, 0.9]:
					antenna(v, hull, Vector3(x, 3.2, 0.6), 2.6)
				insignia(v, hull, Vector3(-1.24, 2.4, -1.2), "x-", 0.35)
				for z in [2.4, -0.4, -2.6]:
					for x in [1.1, -1.1]:
						wheel(v, Vector3(x, 0.55, z), 0.55, 0.4, rim)
				return
			# cargo bed with plank sides
			box(v, hull, Vector3(2.4, 0.15, 4.6), Vector3(0, 1.38, -1.2), WOOD.darkened(0.15), {"b": 0.03})
			for x in [1.18, -1.18]:
				for y in [1.6, 1.85, 2.1]:
					box(v, hull, Vector3(0.06, 0.16, 4.6), Vector3(x, y, -1.2), WOOD, {"b": 0.02})
				for z in [0.9, -1.2, -3.3]:
					box(v, hull, Vector3(0.08, 0.95, 0.1), Vector3(x, 1.85, z), dark, {"b": 0.02})
			box(v, hull, Vector3(2.4, 0.6, 0.08), Vector3(0, 1.75, -3.5), WOOD, {"b": 0.02})
			box(v, hull, Vector3(2.0, 0.1, 0.06), Vector3(0, 1.98, -3.55), band, {"b": 0.0})
			# canvas cover
			if rnd:
				var cv = cyl(hull, 1.25, 4.7, Vector3(0, 2.62, -1.2), CANVAS_A, "z", {"seg": 16})
				cv.scale = Vector3(1, 1, 0.3)
				for z in [0.9, -1.2, -3.3]:
					box(v, hull, Vector3(2.46, 0.06, 0.08), Vector3(0, 2.72, z), CANVAS_A.darkened(0.2), {"b": 0.0})
			else:
				box(v, hull, Vector3(2.45, 0.12, 4.7), Vector3(0, 2.75, -1.2), CANVAS_B, {"b": 0.04})
				for x in [1.2, -1.2]:
					cyl(hull, 0.12, 4.6, Vector3(x, 2.6, -1.2), CANVAS_B.darkened(0.1), "z", {"seg": 8})
			insignia(v, hull, Vector3(0, 2.92 if rnd else 2.82, -1.2), "y", 0.55)
			antenna(v, hull, Vector3(-1.05, 2.68, 1.8), 1.6)
			for z in [2.4, -0.4, -2.6]:
				for x in [1.1, -1.1]:
					wheel(v, Vector3(x, 0.55, z), 0.55, 0.4, rim)
			for z in [-0.4, -2.6]:
				for x in [1.1, -1.1]:
					box(v, hull, Vector3(0.48, 0.07, 1.25), Vector3(x, 1.18, z), dark, {"b": 0.02})
		"halftrack":
			col(v, Vector3(2.3, 0.9, 6.0), Vector3(0, 1.05, 0))
			box(v, hull, Vector3(2.2, 0.85, 4.3), Vector3(0, 1.05, -0.75), base, {"b": 0.06})
			if rnd:
				box(v, hull, Vector3(1.9, 0.6, 1.7), Vector3(0, 1.35, 2.2), base.darkened(0.06), {"b": 0.15})
				box(v, hull, Vector3(1.9, 0.08, 1.4), Vector3(0, 1.66, 2.1), base.darkened(0.1), {"b": 0.02, "rot": Vector3(0.15, 0, 0)})
			else:
				box(v, hull, Vector3(2.0, 0.55, 1.5), Vector3(0, 1.3, 2.2), base.darkened(0.06), {"b": 0.02})
				box(v, hull, Vector3(2.0, 0.08, 1.6), Vector3(0, 1.67, 2.15), base.darkened(0.1), {"b": 0.01, "rot": Vector3(0.22, 0, 0)})
				box(v, hull, Vector3(2.0, 0.65, 0.08), Vector3(0, 1.2, 3.0), base.darkened(0.08), {"b": 0.01, "rot": Vector3(-0.5, 0, 0)})
			for k in range(6):
				box(v, hull, Vector3(0.05, 0.4, 0.04), Vector3(-0.5 + k * 0.2, 1.35, 3.05), METAL, {"b": 0.0})
			for x in [0.6, -0.6]:
				cyl(hull, 0.1, 0.08, Vector3(x, 1.6, 2.95), Color.WHITE, "z", {"m": lamp()})
			var lean = 0.12 if not rnd else 0.06
			for x in [1.1, -1.1]:
				box(v, hull, Vector3(0.08, 0.8, 3.9), Vector3(x, 1.85, -0.85), base, {"b": 0.02, "rot": Vector3(0, 0, -signf(x) * lean)})
				door(v, hull, Vector3(x * 1.06, 1.15, 1.95), 0.85, 0.9, base, -signf(x) * 1.1)
				insignia(v, hull, Vector3(x * 1.13, 1.85, -1.2), "x+" if x > 0 else "x-", 0.26)
			box(v, hull, Vector3(2.3, 0.5, 0.08), Vector3(0, 1.75, 1.2), base.darkened(0.1), {"b": 0.02})
			for x in [0.5, -0.5]:
				box(v, hull, Vector3(0.5, 0.12, 0.03), Vector3(x, 1.82, 1.24), Color(0.05, 0.05, 0.05), {"b": 0.0})
			# rear wall with a door
			box(v, hull, Vector3(2.3, 0.85, 0.08), Vector3(0, 1.45, -2.88), base, {"b": 0.02})
			door(v, hull, Vector3(-0.5, 1.1, -2.94), 1.0, 1.1, base, 1.3, -PI / 2.0, false, Vector3(0, 1.5, -2.9))
			box(v, hull, Vector3(2.0, 0.1, 0.04), Vector3(0, 2.18, -2.9), band, {"b": 0.0})
			for x in [1.1, -1.1]:
				box(v, hull, Vector3(0.45, 0.25, 4.3), Vector3(x, 0.78, -0.9), Color(0.13, 0.13, 0.12), {"b": 0.08})
				box(v, hull, Vector3(0.45, 0.12, 4.3), Vector3(x, 0.08, -0.9), Color(0.13, 0.13, 0.12), {"b": 0.04})
				for k in range(4):
					wheel(v, Vector3(x * 1.08, 0.42, 0.65 - k * 1.05), 0.36, 0.3, rim)
				wheel(v, Vector3(x * 1.05, 0.45, 2.3), 0.45, 0.32, rim)
				box(v, hull, Vector3(0.45, 0.06, 1.1), Vector3(x * 1.05, 0.98, 2.3), base, {"b": 0.02})
			antenna(v, hull, Vector3(-1.0, 2.25, -2.6), 1.8)
			v.turret = Node3D.new()
			v.turret.position = Vector3(0, 2.4, 0.9)
			hull.add_child(v.turret)
			box(v, v.turret, Vector3(0.75, 0.48, 0.05), Vector3(0, 0.0, 0.35), dark, {"b": 0.02, "rot": Vector3(-0.1 if rnd else 0.0, 0, 0)})
			v.gun_pivot = Node3D.new()
			v.turret.add_child(v.gun_pivot)
			mg(v, v.gun_pivot, Vector3(0, 0, 0.05))
		"armoredcar":
			col(v, Vector3(2.3, 1.1, 5.0), Vector3(0, 1.15, 0))
			box(v, hull, Vector3(2.2, 0.6, 4.6), Vector3(0, 0.95, 0), base.darkened(0.05), {"b": 0.08})
			if rnd:
				box(v, hull, Vector3(2.1, 0.6, 3.8), Vector3(0, 1.5, -0.2), base, {"b": 0.2})
				box(v, hull, Vector3(2.0, 0.5, 1.1), Vector3(0, 1.32, 2.15), base, {"b": 0.18, "rot": Vector3(0.35, 0, 0)})
			else:
				box(v, hull, Vector3(2.2, 0.55, 3.6), Vector3(0, 1.5, -0.3), base, {"b": 0.03})
				box(v, hull, Vector3(2.2, 0.08, 1.2), Vector3(0, 1.4, 2.0), base, {"b": 0.01, "rot": Vector3(0.45, 0, 0)})
				box(v, hull, Vector3(2.2, 0.08, 0.9), Vector3(0, 1.45, -2.25), base, {"b": 0.01, "rot": Vector3(-0.6, 0, 0)})
				for x in [1.1, -1.1]:
					box(v, hull, Vector3(0.08, 0.55, 3.6), Vector3(x, 1.5, -0.3), base.darkened(0.08), {"b": 0.01, "rot": Vector3(0, 0, -signf(x) * 0.25)})
			box(v, hull, Vector3(0.6, 0.12, 0.03), Vector3(0.5, 1.6, 1.75), Color(0.05, 0.05, 0.05), {"b": 0.0, "rot": Vector3(0.35, 0, 0)})
			for x in [0.7, -0.7]:
				cyl(hull, 0.1, 0.08, Vector3(x, 1.2, 2.55), Color.WHITE, "z", {"m": lamp()})
			for x in [1.13, -1.13]:
				door(v, hull, Vector3(x, 1.0, 0.95), 0.9, 0.85, base.darkened(0.03), -signf(x) * 1.0)
				insignia(v, hull, Vector3(x * 1.02, 1.55, -1.1), "x+" if x > 0 else "x-", 0.25)
			box(v, hull, Vector3(1.9, 0.08, 0.04), Vector3(0, 1.85, -2.35), band, {"b": 0.0})
			for z in [1.7, 0.0, -1.7]:
				for x in [1.2, -1.2]:
					wheel(v, Vector3(x, 0.55, z), 0.55, 0.38, rim)
					box(v, hull, Vector3(0.45, 0.07, 1.25), Vector3(x * 1.0, 1.15, z), base.darkened(0.08), {"b": 0.02})
			antenna(v, hull, Vector3(-0.9, 1.8, -2.0), 2.2)
			v.turret = Node3D.new()
			v.turret.position = Vector3(0, 1.95, -0.2)
			hull.add_child(v.turret)
			if rnd:
				cyl(v.turret, 0.85, 0.6, Vector3(0, 0.3, 0), base.darkened(0.04), "y", {"r2": 0.7, "seg": 16})
				cyl(v.turret, 0.25, 0.15, Vector3(0.3, 0.68, -0.3), dark, "y", {"seg": 10})
			else:
				box(v, v.turret, Vector3(1.5, 0.55, 1.6), Vector3(0, 0.28, -0.1), base.darkened(0.04), {"b": 0.03})
				box(v, v.turret, Vector3(1.5, 0.08, 0.6), Vector3(0, 0.38, 0.8), base.darkened(0.04), {"b": 0.01, "rot": Vector3(0.6, 0, 0)})
				box(v, v.turret, Vector3(0.4, 0.15, 0.4), Vector3(0.35, 0.62, -0.4), dark, {"b": 0.02})
			insignia(v, v.turret, Vector3(0, 0.62 if not rnd else 0.61, -0.1), "y", 0.28)
			v.gun_pivot = Node3D.new()
			v.gun_pivot.position = Vector3(0, 0.3, 0.75)
			v.turret.add_child(v.gun_pivot)
			box(v, v.gun_pivot, Vector3(0.4, 0.3, 0.3), Vector3(0, 0, 0.1), dark, {"b": 0.06})
			cyl(v.gun_pivot, 0.07, 1.6, Vector3(0, 0, 0.9), dark, "z", {"seg": 10})
			cyl(v.gun_pivot, 0.1, 0.25, Vector3(0, 0, 1.65), dark, "z", {"seg": 10})
		"motorbike":
			col(v, Vector3(0.3, 0.45, 1.9), Vector3(-0.45, 0.75, 0))
			col(v, Vector3(0.9, 0.5, 1.5), Vector3(0.55, 0.6, 0.0))
			box(v, hull, Vector3(0.12, 0.12, 1.5), Vector3(-0.45, 0.55, 0), METAL, {"b": 0.03})
			ball(hull, Vector3(0.32, 0.26, 0.6), Vector3(-0.45, 0.98, 0.3), base)
			box(v, hull, Vector3(0.28, 0.1, 0.5), Vector3(-0.45, 1.0, -0.2), Color(0.18, 0.13, 0.09), {"b": 0.04})
			box(v, hull, Vector3(0.24, 0.3, 0.4), Vector3(-0.45, 0.62, 0.0), METAL, {"b": 0.05})
			cyl(hull, 0.03, 0.75, Vector3(-0.45, 1.22, 0.7), METAL, "x", {"seg": 6})
			cyl(hull, 0.04, 0.6, Vector3(-0.45, 0.95, 0.75), METAL, "y", {"rot": Vector3(0.35, 0, 0), "seg": 6})
			cyl(hull, 0.09, 0.08, Vector3(-0.45, 1.08, 0.88), Color.WHITE, "z", {"m": lamp()})
			box(v, hull, Vector3(0.3, 0.05, 0.6), Vector3(-0.45, 0.78, 0.8), base, {"b": 0.02})
			box(v, hull, Vector3(0.3, 0.05, 0.6), Vector3(-0.45, 0.78, -0.8), base, {"b": 0.02})
			cyl(hull, 0.05, 0.7, Vector3(-0.62, 0.45, -0.5), METAL, "z", {"seg": 6})
			# sidecar
			if rnd:
				ball(hull, Vector3(0.85, 0.55, 1.6), Vector3(0.55, 0.62, 0.0), base.darkened(0.1))
			else:
				box(v, hull, Vector3(0.85, 0.45, 1.4), Vector3(0.55, 0.6, 0.0), base.darkened(0.1), {"b": 0.04})
				box(v, hull, Vector3(0.85, 0.06, 0.5), Vector3(0.55, 0.78, 0.75), base.darkened(0.1), {"b": 0.01, "rot": Vector3(0.6, 0, 0)})
			box(v, hull, Vector3(0.7, 0.04, 0.3), Vector3(0.55, 0.88, -0.6), band, {"b": 0.0})
			insignia(v, hull, Vector3(0.98, 0.62, 0.0), "x+", 0.15)
			wheel(v, Vector3(-0.45, 0.35, 0.8), 0.35, 0.14, rim)
			wheel(v, Vector3(-0.45, 0.35, -0.8), 0.35, 0.14, rim)
			wheel(v, Vector3(0.9, 0.3, 0.0), 0.3, 0.14, rim)
			v.turret = Node3D.new()
			v.turret.position = Vector3(0.55, 1.15, 0.6)
			hull.add_child(v.turret)
			v.gun_pivot = Node3D.new()
			v.turret.add_child(v.gun_pivot)
			mg(v, v.gun_pivot, Vector3(0, 0, -0.05), 0.8)
		"artillery":
			col(v, Vector3(2.0, 0.15, 0.4), Vector3(0, 0.6, 0.2))
			box(v, hull, Vector3(1.9, 0.14, 0.3), Vector3(0, 0.6, 0.2), dark)
			for x in [1.05, -1.05]:
				wheel(v, Vector3(x, 0.6, 0.2), 0.6, 0.16, rim, false)
			for x in [0.55, -0.55]:
				box(v, hull, Vector3(0.12, 0.14, 2.6), Vector3(x * 0.6, 0.35, -1.2), dark, {"rot": Vector3(0.12, x * 0.25, 0)})
				box(v, hull, Vector3(0.3, 0.08, 0.3), Vector3(x * 1.3, 0.04, -2.4), METAL)
			v.turret = Node3D.new()
			v.turret.position = Vector3(0, 0.95, 0.3)
			hull.add_child(v.turret)
			if rnd:
				box(v, v.turret, Vector3(1.5, 1.0, 0.06), Vector3(0, 0.15, 0.55), base, {"b": 0.02, "rot": Vector3(-0.15, 0, 0)})
			else:
				box(v, v.turret, Vector3(1.0, 0.9, 0.06), Vector3(0, 0.15, 0.55), base, {"b": 0.02})
				for x in [0.65, -0.65]:
					box(v, v.turret, Vector3(0.4, 0.9, 0.06), Vector3(x, 0.15, 0.48), base, {"b": 0.02, "rot": Vector3(0, -signf(x) * 0.4, 0)})
			insignia(v, v.turret, Vector3(0.45, 0.35, 0.6), "z+", 0.14)
			v.gun_pivot = Node3D.new()
			v.gun_pivot.rotation.x = -0.5
			v.turret.add_child(v.gun_pivot)
			box(v, v.gun_pivot, Vector3(0.36, 0.34, 1.1), Vector3(0, 0, 0.2), dark, {"b": 0.06})
			cyl(v.gun_pivot, 0.09, 2.8, Vector3(0, 0, 1.9), dark, "z", {"r2": 0.08, "seg": 10})
			cyl(v.gun_pivot, 0.13, 0.3, Vector3(0, 0, 3.25), dark, "z", {"seg": 10})
		"heli", "gunship":
			var big = v.kind == "heli"
			var hc = base.darkened(0.05)
			col(v, Vector3(2.4 if big else 1.4, 1.9 if big else 1.4, 5.0 if big else 4.2), Vector3(0, 1.4, 0.6 if big else 1.0))
			if big:
				# rounded cabin, glazed nose, engine hump
				ball(hull, Vector3(2.5, 2.1, 6.2), Vector3(0, 1.45, 0.4), hc)
				box(v, hull, Vector3(2.1, 0.45, 4.6), Vector3(0, 0.62, 0.3), hc.darkened(0.08), {"b": 0.18})
				ball(hull, Vector3(1.95, 1.35, 1.7), Vector3(0, 1.65, 3.05), Color.WHITE, {"m": glass()})
				ball(hull, Vector3(1.5, 0.8, 2.8), Vector3(0, 2.45, 0.3), hc.darkened(0.04))
				for x in [0.45, -0.45]:
					cyl(hull, 0.22, 0.6, Vector3(x, 2.5, -1.25), METAL, "z", {"seg": 10})
				# sliding side doors with windows, round portholes behind them
				for x in [1.18, -1.18]:
					var dn = Node3D.new()
					dn.position = Vector3(x, 0.8, 1.2)
					dn.rotation.y = 0.0
					hull.add_child(dn)
					box(v, dn, Vector3(0.06, 1.25, 1.5), Vector3(0, 0.62, -0.75), hc.darkened(0.08), {"b": 0.04})
					box(v, dn, Vector3(0.07, 0.45, 0.9), Vector3(0, 0.95, -0.75), Color.WHITE, {"m": glass(), "b": 0.03})
					v.doors.append({"n": dn, "slide": 1.6, "t": 0.0, "c": Vector3(x, 1.4, 0.45)})
					for k in range(3):
						cyl(hull, 0.17, 0.06, Vector3(x * 1.0, 1.65, -0.6 - k * 0.65), Color.WHITE, "x", {"m": glass(), "seg": 12})
					insignia(v, hull, Vector3(x * 0.96, 1.2, -1.6), "x+" if x > 0 else "x-", 0.32)
				for x in [1.15, -1.15]:
					cyl(hull, 0.05, 3.6, Vector3(x, 0.1, 0.5), dark, "z", {"seg": 6})
					for z in [1.6, -0.6]:
						cyl(hull, 0.045, 0.75, Vector3(x * 0.82, 0.42, z), dark, "y", {"rot": Vector3(0, 0, signf(x) * 0.5), "seg": 6})
			else:
				# slim attack helicopter: tandem canopy, stub wings with rocket pods, chin gun
				ball(hull, Vector3(1.45, 1.55, 5.4), Vector3(0, 1.4, 0.6), hc)
				ball(hull, Vector3(1.0, 1.0, 2.9), Vector3(0, 2.0, 1.5), Color.WHITE, {"m": glass()})
				box(v, hull, Vector3(0.9, 0.08, 2.6), Vector3(0, 2.48, 1.5), hc.darkened(0.15), {"b": 0.02})
				ball(hull, Vector3(1.1, 0.7, 2.2), Vector3(0, 2.2, -0.6), hc.darkened(0.04))
				for x in [1.0, -1.0]:
					box(v, hull, Vector3(1.1, 0.1, 0.7), Vector3(x * 0.95, 1.3, 0.5), hc.darkened(0.08), {"b": 0.03, "rot": Vector3(0, 0, x * 0.1)})
					cyl(hull, 0.2, 1.4, Vector3(x * 1.4, 1.12, 0.55), Color(0.22, 0.24, 0.2), "z", {"seg": 12})
					cyl(hull, 0.16, 0.05, Vector3(x * 1.4, 1.12, 1.26), Color(0.05, 0.05, 0.05), "z", {"seg": 12})
					insignia(v, hull, Vector3(x * 0.7, 1.35, -0.8), "x+" if x > 0 else "x-", 0.24)
				for x in [0.72, -0.72]:
					cyl(hull, 0.05, 3.0, Vector3(x, 0.12, 0.8), dark, "z", {"seg": 6})
					for z in [1.8, -0.2]:
						cyl(hull, 0.04, 0.8, Vector3(x * 0.8, 0.5, z), dark, "y", {"rot": Vector3(0, 0, signf(x) * 0.35), "seg": 6})
			cyl(hull, 0.18, 4.8, Vector3(0, 1.85, -4.0), hc, "z", {"r2": 0.42, "seg": 12})
			box(v, hull, Vector3(0.12, 1.4, 1.0), Vector3(0, 2.45, -6.1), hc, {"b": 0.05, "rot": Vector3(-0.3, 0, 0)})
			box(v, hull, Vector3(1.5, 0.07, 0.5), Vector3(0, 1.95, -5.5), hc, {"b": 0.03})
			box(v, hull, Vector3(1.1, 0.07, 0.36), Vector3(0, 1.92 if not big else 2.0, -2.2), band, {"b": 0.0})
			var tr = Node3D.new()
			tr.position = Vector3(0.13, 2.6, -6.3)
			hull.add_child(tr)
			box(v, tr, Vector3(0.03, 1.4, 0.13), Vector3.ZERO, Color(0.1, 0.1, 0.1), {"b": 0.0})
			box(v, tr, Vector3(0.03, 0.13, 1.4), Vector3.ZERO, Color(0.1, 0.1, 0.1), {"b": 0.0})
			v.set_meta("tail_rotor", tr)
			v.rotor = Node3D.new()
			v.rotor.position = Vector3(0, 3.0 if big else 2.75, 0.4)
			hull.add_child(v.rotor)
			cyl(v.rotor, 0.25, 0.3, Vector3.ZERO, METAL, "y", {"seg": 12})
			cyl(hull, 0.1, 0.5, Vector3(0, (3.0 if big else 2.75) - 0.3, 0.4), METAL, "y", {"seg": 8})
			var nb = 4 if big else 2
			for k in range(nb):
				var blade = box(v, v.rotor, Vector3(0.3, 0.04, 6.5 if big else 5.5), Vector3.ZERO, Color(0.1, 0.1, 0.1), {"b": 0.01})
				blade.rotation.y = k * TAU / nb
				blade.position = Basis(Vector3.UP, k * TAU / nb) * Vector3(0, 0, 3.25 if big else 2.75)
			if not big:
				v.turret = Node3D.new()
				v.turret.position = Vector3(0, 0.75, 3.1)
				hull.add_child(v.turret)
				ball(v.turret, Vector3(0.55, 0.45, 0.55), Vector3(0, 0.1, 0), dark)
				v.gun_pivot = Node3D.new()
				v.turret.add_child(v.gun_pivot)
				cyl(v.gun_pivot, 0.06, 1.0, Vector3(0, 0, 0.45), Color(0.1, 0.1, 0.1), "z", {"seg": 8})
				for k in range(3):
					var a = k * TAU / 3.0
					cyl(v.gun_pivot, 0.025, 1.0, Vector3(cos(a) * 0.06, sin(a) * 0.06, 0.5), Color(0.1, 0.1, 0.1), "z", {"seg": 5})
		"boat":
			var bc = Color(0.38, 0.42, 0.4).lerp(base, 0.3)
			col(v, Vector3(3.3, 0.3, 8.8), Vector3(0, 0.35, 0))
			box(v, hull, Vector3(3.3, 0.35, 8.8), Vector3(0, 0.35, 0), bc, {"b": 0.1})
			for x in [1.6, -1.6]:
				box(v, hull, Vector3(0.14, 1.6, 8.6), Vector3(x, 1.1, 0), bc, {"b": 0.04})
				box(v, hull, Vector3(0.24, 0.1, 8.6), Vector3(x, 1.92, 0), bc.darkened(0.15), {"b": 0.03})
				for z in [-3.0, -1.0, 1.0, 3.0]:
					box(v, hull, Vector3(0.2, 1.5, 0.1), Vector3(x * 0.97, 1.1, z), bc.darkened(0.1), {"b": 0.02})
				insignia(v, hull, Vector3(x * 1.05, 1.2, -2.0), "x+" if x > 0 else "x-", 0.4)
				cyl(hull, 0.18, 1.2, Vector3(x * 1.08, 1.3, 2.8), Color(0.25, 0.25, 0.22), "z", {"seg": 10})
			box(v, hull, Vector3(3.3, 1.6, 0.15), Vector3(0, 1.1, -4.35), bc, {"b": 0.04})
			box(v, hull, Vector3(1.4, 0.7, 1.2), Vector3(0, 2.05, -3.6), bc.darkened(0.2), {"b": 0.08})
			box(v, hull, Vector3(1.2, 0.25, 0.04), Vector3(0, 2.2, -2.99), Color.WHITE, {"m": glass(), "b": 0.0})
			antenna(v, hull, Vector3(0.5, 2.4, -3.9), 1.8)
			box(v, hull, Vector3(2.8, 0.06, 0.06), Vector3(0, 1.98, -4.38), band, {"b": 0.0})
			v.turret = null
			v.ramp = Node3D.new()
			v.ramp.position = Vector3(0, 0.3, 4.35)
			hull.add_child(v.ramp)
			box(v, v.ramp, Vector3(3.2, 1.7, 0.15), Vector3(0, 0.85, 0), bc.darkened(0.1), {"b": 0.04})
			for k in range(5):
				box(v, v.ramp, Vector3(2.9, 0.06, 0.08), Vector3(0, 0.2 + k * 0.32, -0.1), bc.darkened(0.2), {"b": 0.0})
		"nest":
			col(v, Vector3(3.0, 0.9, 0.7), Vector3(0, 0.45, 0.9))
			for x in [1.35, -1.35]:
				col(v, Vector3(0.7, 0.9, 2.0), Vector3(x, 0.45, 0.0))
			var bag = Color(0.66, 0.6, 0.45)
			if not bare:
				sandbag_ring(v, hull, [[Vector3(-1.45, 0, 0.95), Vector3(1.45, 0, 0.95)], [Vector3(1.4, 0, 0.75), Vector3(1.4, 0, -1.0)], [Vector3(-1.4, 0, 0.75), Vector3(-1.4, 0, -1.0)]], 3, bag)
			box(v, hull, Vector3(0.5, 0.06, 0.4), Vector3(0, 0.85, 0.8), dark, {"b": 0.01})
			box(v, hull, Vector3(0.35, 0.25, 0.25), Vector3(0.8, 0.12, -0.3), Color(0.3, 0.3, 0.22), {"b": 0.03})
			v.turret = Node3D.new()
			v.turret.position = Vector3(0, 1.22, 0.1)
			hull.add_child(v.turret)
			cyl(v.turret, 0.04, 0.7, Vector3(0, -0.4, 0), METAL, "y", {"seg": 6})
			for k in range(3):
				var a = k * TAU / 3.0
				cyl(v.turret, 0.025, 0.9, Vector3(cos(a) * 0.2, -0.85, sin(a) * 0.2), METAL, "y", {"rot": Vector3(sin(a) * 0.35, 0, -cos(a) * 0.35), "seg": 5})
			v.gun_pivot = Node3D.new()
			v.turret.add_child(v.gun_pivot)
			mg(v, v.gun_pivot, Vector3(0, 0, 0.05))
		"mortar":
			col(v, Vector3(0.6, 0.06, 0.6), Vector3(0, 0.03, 0))
			cyl(hull, 0.32, 0.06, Vector3(0, 0.03, 0), METAL, "y", {"seg": 12})
			var pts = []
			for k in range(6):
				var a0 = k * TAU / 6.0 + 0.3
				var a1 = (k + 1) * TAU / 6.0 + 0.3
				if k == 2:
					continue
				pts.append([Vector3(cos(a0), 0, sin(a0)) * 1.05, Vector3(cos(a1), 0, sin(a1)) * 1.05])
			if not bare:
				sandbag_ring(v, hull, pts, 2, Color(0.64, 0.58, 0.44))
			for k in range(3):
				box(v, hull, Vector3(0.14, 0.12, 0.45), Vector3(-0.5 + k * 0.17, 0.06, -0.55), Color(0.28, 0.3, 0.2), {"b": 0.02})
			v.turret = Node3D.new()
			v.turret.position = Vector3(0, 0.15, 0)
			hull.add_child(v.turret)
			v.gun_pivot = Node3D.new()
			v.gun_pivot.rotation.x = -0.95
			v.turret.add_child(v.gun_pivot)
			cyl(v.gun_pivot, 0.07, 1.2, Vector3(0, 0, 0.55), Color(0.2, 0.22, 0.18), "z", {"seg": 10})
			for x in [0.18, -0.18]:
				cyl(v.turret, 0.02, 0.6, Vector3(x, 0.2, 0.55), METAL, "y", {"rot": Vector3(0.3, 0, -signf(x) * 0.2), "seg": 4})
		"aagun":
			col(v, Vector3(2.4, 0.5, 2.4), Vector3(0, 0.25, 0))
			cyl(hull, 1.2, 0.35, Vector3(0, 0.18, 0), dark, "y", {"seg": 16})
			for k in range(4):
				var a = k * PI / 2.0 + PI / 4.0
				box(v, hull, Vector3(0.25, 0.15, 1.6), Vector3(cos(a) * 1.3, 0.08, sin(a) * 1.3), METAL, {"rot": Vector3(0, -a + PI / 2.0, 0), "b": 0.03})
			if not bare:
				var pts = []
				for k in range(7):
					var a0 = k * TAU / 8.0 + 0.4
					var a1 = (k + 1) * TAU / 8.0 + 0.4
					pts.append([Vector3(cos(a0), 0, sin(a0)) * 2.1, Vector3(cos(a1), 0, sin(a1)) * 2.1])
				sandbag_ring(v, hull, pts, 2, Color(0.66, 0.6, 0.45))
			v.turret = Node3D.new()
			v.turret.position = Vector3(0, 0.75, 0)
			hull.add_child(v.turret)
			cyl(v.turret, 0.55, 0.35, Vector3(0, 0, 0), base, "y", {"seg": 14})
			box(v, v.turret, Vector3(1.4, 0.7, 0.06), Vector3(0, 0.45, 0.45), base, {"b": 0.02, "rot": Vector3(-0.2, 0, 0)})
			for x in [0.45, -0.45]:
				box(v, v.turret, Vector3(0.08, 0.6, 0.6), Vector3(x, 0.45, 0.0), dark, {"b": 0.02})
			v.gun_pivot = Node3D.new()
			v.gun_pivot.position = Vector3(0, 0.6, 0.0)
			v.turret.add_child(v.gun_pivot)
			box(v, v.gun_pivot, Vector3(0.5, 0.35, 0.6), Vector3(0, 0, 0.1), dark, {"b": 0.05})
			for x in [0.14, -0.14]:
				cyl(v.gun_pivot, 0.05, 2.0, Vector3(x, 0.02, 1.3), Color(0.1, 0.1, 0.1), "z", {"seg": 8})
				cyl(v.gun_pivot, 0.08, 0.3, Vector3(x, 0.02, 2.25), Color(0.1, 0.1, 0.1), "z", {"seg": 8})
			cyl(v.gun_pivot, 0.12, 0.04, Vector3(0.0, 0.3, 0.6), METAL, "z", {"seg": 12})
		"fighter", "bomber":
			var bomber = v.kind == "bomber"
			var pc = base.lerp(Color(0.5, 0.52, 0.5), 0.25)
			col(v, Vector3(1.6, 1.6, 8.0), Vector3(0, 1.4, 0))
			var fl = 9.0 if not bomber else 10.5
			ball(hull, Vector3(1.4, 1.5, fl), Vector3(0, 1.4, 0.0), pc)
			cyl(hull, 0.72, 0.9, Vector3(0, 1.45, fl * 0.42), pc.darkened(0.2), "z", {"r2": 0.6, "seg": 14})
			ball(hull, Vector3(0.9, 0.8, 1.8 if not bomber else 3.2), Vector3(0, 2.05, 0.4 if not bomber else -0.1), Color.WHITE, {"m": glass()})
			# wings with a slight dihedral, tailplane and fin
			for x in [1.0, -1.0]:
				box(v, hull, Vector3(4.6 if not bomber else 5.8, 0.14, 1.9), Vector3(x * (2.6 if not bomber else 3.2), 1.05, 0.5), pc, {"b": 0.06, "rot": Vector3(0, 0, -x * 0.07)})
				box(v, hull, Vector3(0.6, 0.15, 1.95), Vector3(x * (4.7 if not bomber else 5.9), 1.22, 0.45), band, {"b": 0.04, "rot": Vector3(0, 0, -x * 0.07)})
				insignia(v, hull, Vector3(x * 3.4, 1.14, 0.45), "y", 0.45)
				box(v, hull, Vector3(1.6, 0.1, 0.8), Vector3(x * 1.0, 1.6, -fl * 0.45), pc, {"b": 0.03})
				# landing gear legs and wheels tucked under the wings
				cyl(hull, 0.05, 0.7, Vector3(x * 1.4, 0.65, 0.9), METAL, "y", {"seg": 6})
				cyl(hull, 0.22, 0.12, Vector3(x * 1.4, 0.3, 0.9), TYRE, "x", {"seg": 12})
				if not bomber:
					cyl(hull, 0.04, 0.9, Vector3(x * 2.2, 1.0, 1.6), Color(0.1, 0.1, 0.1), "z", {"seg": 6})
			box(v, hull, Vector3(0.12, 1.3, 1.1), Vector3(0, 2.2, -fl * 0.44), pc, {"b": 0.04, "rot": Vector3(-0.25, 0, 0)})
			insignia(v, hull, Vector3(0.71, 1.5, -fl * 0.2), "x+", 0.35)
			insignia(v, hull, Vector3(-0.71, 1.5, -fl * 0.2), "x-", 0.35)
			if bomber:
				box(v, hull, Vector3(0.5, 0.35, 1.6), Vector3(0, 0.6, 0.4), METAL, {"b": 0.12})
				for x in [1.0, -1.0]:
					box(v, hull, Vector3(0.3, 0.6, 0.8), Vector3(x * 1.6, 0.75, 1.2), pc, {"b": 0.06})
			v.rotor = Node3D.new()
			v.rotor.position = Vector3(0, 1.45, fl * 0.42 + 0.55)
			hull.add_child(v.rotor)
			cyl(v.rotor, 0.22, 0.45, Vector3.ZERO, METAL, "z", {"r2": 0.05, "seg": 10})
			for k in range(3):
				var blade = box(v, v.rotor, Vector3(0.18, 1.2, 0.05), Vector3.ZERO, Color(0.1, 0.1, 0.1), {"b": 0.01})
				blade.rotation.z = k * TAU / 3.0
				blade.position = Basis(Vector3(0, 0, 1), k * TAU / 3.0) * Vector3(0, 0.6, 0)
			v.set_meta("prop", true)
			if bomber:
				v.turret = Node3D.new()
				v.turret.position = Vector3(0, 2.05, -1.1)
				hull.add_child(v.turret)
				v.gun_pivot = Node3D.new()
				v.turret.add_child(v.gun_pivot)
				v.gun_pivot.rotation.y = 0.0
				mg(v, v.gun_pivot, Vector3(0, 0, 0.0), 0.8)
		"bridger":
			col(v, Vector3(3.3, 1.0, 6.4), Vector3(0, 0.95, 0))
			box(v, hull, Vector3(2.4, 0.9, 6.0), Vector3(0, 0.95, 0), base.darkened(0.05), {"b": 0.08})
			box(v, hull, Vector3(3.0, 0.45, 4.8), Vector3(0, 1.6, -0.6), base, {"b": 0.12})
			for x in [1.45, -1.45]:
				box(v, hull, Vector3(0.7, 0.18, 6.6), Vector3(x, 0.88, 0), Color(0.13, 0.13, 0.12), {"b": 0.06})
				box(v, hull, Vector3(0.7, 0.14, 5.8), Vector3(x, 0.05, 0), Color(0.13, 0.13, 0.12), {"b": 0.05})
				cyl(hull, 0.4, 0.7, Vector3(x, 0.5, 3.0), Color(0.13, 0.13, 0.12), "x", {"seg": 12})
				cyl(hull, 0.4, 0.7, Vector3(x, 0.5, -3.0), Color(0.13, 0.13, 0.12), "x", {"seg": 12})
			for z in range(5):
				for x in [1.45, -1.45]:
					wheel(v, Vector3(x, 0.42, -2.4 + z * 1.2), 0.38, 0.6, rim)
			# the folded bridge on its launch arm
			var br = Node3D.new()
			br.position = Vector3(0, 2.0, 0.0)
			hull.add_child(br)
			box(v, br, Vector3(3.6, 0.35, 7.6), Vector3(0, 0.2, 0), Color(0.45, 0.42, 0.36), {"b": 0.04})
			for x in [1.65, -1.65]:
				box(v, br, Vector3(0.2, 0.6, 7.6), Vector3(x, 0.4, 0), Color(0.38, 0.36, 0.3), {"b": 0.03})
			for k in range(6):
				box(v, br, Vector3(3.3, 0.06, 0.12), Vector3(0, 0.42, -3.2 + k * 1.3), Color(0.32, 0.3, 0.26), {"b": 0.0})
			v.set_meta("bridge_node", br)
			insignia(v, hull, Vector3(1.22, 1.0, -1.0), "x+", 0.3)
			insignia(v, hull, Vector3(-1.22, 1.0, -1.0), "x-", 0.3)
			box(v, hull, Vector3(2.4, 0.1, 0.06), Vector3(0, 1.4, -3.02), band, {"b": 0.0})
		"tank":
			col(v, Vector3(3.3, 1.0, 6.4), Vector3(0, 0.95, 0))
			col(v, Vector3(3.0, 0.4, 5.2), Vector3(0, 1.6, -0.2))
			box(v, hull, Vector3(2.4, 0.9, 6.0), Vector3(0, 0.95, 0), base.darkened(0.05), {"b": 0.08})
			if rnd:
				box(v, hull, Vector3(2.9, 0.5, 4.6), Vector3(0, 1.6, -0.5), base, {"b": 0.18})
				box(v, hull, Vector3(2.9, 0.1, 1.6), Vector3(0, 1.32, 2.55), base, {"b": 0.04, "rot": Vector3(0.45, 0, 0)})
			else:
				box(v, hull, Vector3(3.2, 0.42, 4.6), Vector3(0, 1.6, -0.5), base, {"b": 0.03})
				box(v, hull, Vector3(3.2, 0.1, 1.2), Vector3(0, 1.45, 2.4), base, {"b": 0.01, "rot": Vector3(0.25, 0, 0)})
				box(v, hull, Vector3(2.6, 0.7, 0.1), Vector3(0, 1.0, 3.1), base, {"b": 0.01, "rot": Vector3(-0.55, 0, 0)})
				for x in [1.62, -1.62]:
					box(v, hull, Vector3(0.05, 0.55, 4.6), Vector3(x, 1.0, -0.2), base.darkened(0.08), {"b": 0.01})
			for x in [1.45, -1.45]:
				box(v, hull, Vector3(0.7, 0.18, 6.6), Vector3(x, 0.88, 0), Color(0.13, 0.13, 0.12), {"b": 0.06})
				box(v, hull, Vector3(0.7, 0.14, 5.8), Vector3(x, 0.05, 0), Color(0.13, 0.13, 0.12), {"b": 0.05})
				cyl(hull, 0.4, 0.7, Vector3(x, 0.5, 3.0), Color(0.13, 0.13, 0.12), "x", {"seg": 12})
				cyl(hull, 0.4, 0.7, Vector3(x, 0.5, -3.0), Color(0.13, 0.13, 0.12), "x", {"seg": 12})
				box(v, hull, Vector3(0.75, 0.06, 6.7), Vector3(x, 1.05, 0), base.darkened(0.1), {"b": 0.02})
				for k in range(3):
					box(v, hull, Vector3(0.12, 0.3, 0.7), Vector3(x * 0.75, 1.35, -1.8 + k * 0.9), dark, {"b": 0.04})
			for z in range(5):
				for x in [1.45, -1.45]:
					wheel(v, Vector3(x, 0.42, -2.4 + z * 1.2), 0.38, 0.6, rim)
			for x in [0.6, -0.6]:
				cyl(hull, 0.09, 0.4, Vector3(x, 1.75, -2.9), METAL, "z", {"seg": 8})
			box(v, hull, Vector3(0.5, 0.15, 0.05), Vector3(0.7, 1.6, 2.15), Color(0.05, 0.05, 0.05), {"b": 0.0, "rot": Vector3(0.4, 0, 0)})
			box(v, hull, Vector3(2.4, 0.1, 0.06), Vector3(0, 1.4, -3.02), band, {"b": 0.0})
			for x in [1.2, -1.2]:
				cyl(hull, 0.13, 0.08, Vector3(x, 1.45, 3.05), Color.WHITE, "z", {"m": lamp()})
			v.turret = Node3D.new()
			v.turret.position = Vector3(0, 1.8, -0.3)
			hull.add_child(v.turret)
			if rnd:
				ball(v.turret, Vector3(2.4, 1.0, 2.9), Vector3(0, 0.35, -0.1), base)
				ball(v.turret, Vector3(2.0, 0.6, 1.4), Vector3(0, 0.4, -1.3), base.darkened(0.03))
				cyl(v.turret, 0.32, 0.25, Vector3(0.5, 0.9, -0.4), dark, "y", {"seg": 12})
				cyl(v.turret, 0.3, 0.06, Vector3(0.5, 1.05, -0.4), dark, "y", {"seg": 12})
				for x in [1.08, -1.08]:
					insignia(v, v.turret, Vector3(x, 0.4, -0.2), "x+" if x > 0 else "x-", 0.3)
			else:
				box(v, v.turret, Vector3(2.2, 0.75, 2.4), Vector3(0, 0.38, -0.2), base, {"b": 0.04})
				box(v, v.turret, Vector3(2.2, 0.08, 0.8), Vector3(0, 0.5, 1.15), base, {"b": 0.01, "rot": Vector3(0.7, 0, 0)})
				for x in [1.12, -1.12]:
					box(v, v.turret, Vector3(0.04, 0.6, 2.6), Vector3(x * 1.06, 0.35, -0.3), base.darkened(0.06), {"b": 0.01})
					insignia(v, v.turret, Vector3(x * 1.1, 0.38, -0.2), "x+" if x > 0 else "x-", 0.3)
				box(v, v.turret, Vector3(1.8, 0.5, 0.7), Vector3(0, 0.4, -1.65), base.darkened(0.05), {"b": 0.03})
				box(v, v.turret, Vector3(0.55, 0.22, 0.55), Vector3(0.5, 0.86, -0.4), dark, {"b": 0.03})
			box(v, v.turret, Vector3(1.4, 0.08, 0.3), Vector3(0, 0.8, -1.25), band, {"b": 0.0})
			antenna(v, v.turret, Vector3(-0.8, 0.75, -1.3), 2.4)
			v.gun_pivot = Node3D.new()
			v.gun_pivot.position = Vector3(0, 0.45, 1.3)
			v.turret.add_child(v.gun_pivot)
			if rnd:
				ball(v.gun_pivot, Vector3(0.75, 0.6, 0.6), Vector3(0, 0, 0.15), dark)
			else:
				box(v, v.gun_pivot, Vector3(0.9, 0.55, 0.35), Vector3(0, 0, 0.15), dark, {"b": 0.05})
			cyl(v.gun_pivot, 0.11, 3.2, Vector3(0, 0, 1.9), dark, "z", {"r2": 0.1, "seg": 12})
			cyl(v.gun_pivot, 0.15, 0.6, Vector3(0, 0, 1.2), dark, "z", {"seg": 12})
			if rnd:
				cyl(v.gun_pivot, 0.15, 0.35, Vector3(0, 0, 3.45), dark, "z", {"seg": 12})
			else:
				box(v, v.gun_pivot, Vector3(0.36, 0.22, 0.4), Vector3(0, 0, 3.45), dark, {"b": 0.03})
