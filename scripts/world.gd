extends Node3D
# Terrain, static geometry, colliders, navigation, cover points, destruction and the three maps.

var TX0 = -130.0
var TZ0 = -95.0
var TW = 260
var TH_ = 190
var th = PackedFloat32Array()          # (TW+1)*(TH_+1) heights, 1 m grid
var ter_max = 0.0
var terrain_mesh: MeshInstance3D = null
var terrain_body: StaticBody3D = null

var cols: Array = []                    # WCol
var grid = {}                          # cell -> Array of WCol
const GRID = 6.0
var groups = {}                        # colour key -> {"color", "xforms": Array, "mm": MultiMesh}
var piece = null
var cover: Array = []                   # CoverPoint
var terrain_cover: Array = []
var towers: Array = []
var smoke_sources: Array = []
var buildings: Array = []
var roads: Array = []
var spawn = [Vector3(-96, 0, 0), Vector3(96, 0, 0)]
var capture = Vector3.ZERO
var bounds = Rect2(-128, -93, 256, 186)   # playable area (x, z)
var ammo_points: Array = []   # {"p": Vector3, "team": int (-1 = anyone)}
var objectives: Array = []    # control points, in order from Alpha's side to Bravo's: {"p", "name"}
var geo_root: Node3D
var rng = RandomNumberGenerator.new()

# navigation (0.5 m grid)
const NCS = 0.5
var NX0 = -130.0
var NZ0 = -95.0
var NW = 520
var NH = 380
var astar = AStarGrid2D.new()
var nav_vault = PackedByteArray()      # 1 where a low wall can be vaulted

const WALLC = [Color(0.78, 0.71, 0.56), Color(0.73, 0.64, 0.49), Color(0.61, 0.59, 0.55), Color(0.56, 0.33, 0.27), Color(0.82, 0.76, 0.62)]
var MAPS = {
	"town": {"name": "Town ruins", "ground": Color(0.48, 0.45, 0.37), "seed": 1337},
	"field": {"name": "Farmland", "ground": Color(0.44, 0.46, 0.31), "seed": 4242},
	"trenches": {"name": "Trenches", "ground": Color(0.42, 0.38, 0.30), "seed": 777},
	"valley": {"name": "Valley offensive (large)", "ground": Color(0.43, 0.45, 0.32), "seed": 9001, "size": Vector2(660, 260)},
	"front": {"name": "Western front (large)", "ground": Color(0.41, 0.37, 0.3), "seed": 1916, "size": Vector2(560, 240)},
}

# the map's terrain, navigation grid and playable bounds all come from its size
func _set_size(w: float, d: float) -> void:
	TW = int(w)
	TH_ = int(d)
	TX0 = -w / 2.0
	TZ0 = -d / 2.0
	NX0 = TX0
	NZ0 = TZ0
	NW = int(w / NCS)
	NH = int(d / NCS)
	bounds = Rect2(TX0 + 2.0, TZ0 + 2.0, w - 4.0, d - 4.0)

func is_large() -> bool:
	return TW > 300

func rnd(a: float, b: float) -> float:
	return rng.randf_range(a, b)

# ---------------------------------------------------------------- terrain
func ground_y(x: float, z: float) -> float:
	var fx = x - TX0
	var fz = z - TZ0
	if fx < 0.0 or fz < 0.0 or fx >= TW or fz >= TH_:
		return 0.0
	var ix = int(fx)
	var iz = int(fz)
	var tx = fx - ix
	var tz = fz - iz
	var i = iz * (TW + 1) + ix
	var W = TW + 1
	return (th[i] * (1.0 - tx) + th[i + 1] * tx) * (1.0 - tz) + (th[i + W] * (1.0 - tx) + th[i + W + 1] * tx) * tz

func _each_vert(x0: float, z0: float, x1: float, z1: float, fn: Callable) -> void:
	var ix0 = maxi(0, int(floor(x0 - TX0)))
	var ix1 = mini(TW, int(ceil(x1 - TX0)))
	var iz0 = maxi(0, int(floor(z0 - TZ0)))
	var iz1 = mini(TH_, int(ceil(z1 - TZ0)))
	for iz in range(iz0, iz1 + 1):
		for ix in range(ix0, ix1 + 1):
			fn.call(iz * (TW + 1) + ix, TX0 + ix, TZ0 + iz)

func hill(x: float, z: float, r: float, h: float) -> void:
	_each_vert(x - r, z - r, x + r, z + r, func(i, vx, vz):
		var d = Vector2(vx - x, vz - z).length()
		if d < r:
			th[i] += h * 0.5 * (1.0 + cos(PI * d / r)))

func crater_ter(x: float, z: float, r: float, d: float) -> void:
	_each_vert(x - r * 1.6, z - r * 1.6, x + r * 1.6, z + r * 1.6, func(i, vx, vz):
		var k = Vector2(vx - x, vz - z).length() / r
		if k < 1.0:
			th[i] -= d * (1.0 - k * k)
		if k > 0.8 and k < 1.55:
			th[i] += 0.32 * d * sin((k - 0.8) / 0.75 * PI))

func _seg_dist(px: float, pz: float, ax: float, az: float, bx: float, bz: float) -> float:
	var dx = bx - ax
	var dz = bz - az
	var l2 = dx * dx + dz * dz
	var t = 0.0
	if l2 > 0.0:
		t = clampf(((px - ax) * dx + (pz - az) * dz) / l2, 0.0, 1.0)
	return Vector2(px - ax - dx * t, pz - az - dz * t).length()

func trench_ter(pts: Array, w: float, depth: float) -> void:
	var x0 = 1e9
	var x1 = -1e9
	var z0 = 1e9
	var z1 = -1e9
	for p in pts:
		x0 = minf(x0, p.x); x1 = maxf(x1, p.x); z0 = minf(z0, p.y); z1 = maxf(z1, p.y)
	var m = w / 2.0 + 2.5
	_each_vert(x0 - m, z0 - m, x1 + m, z1 + m, func(i, vx, vz):
		var d = 1e9
		for k in range(pts.size() - 1):
			d = minf(d, _seg_dist(vx, vz, pts[k].x, pts[k].y, pts[k + 1].x, pts[k + 1].y))
		if d < w / 2.0:
			th[i] = minf(th[i], -depth)
		elif d < w / 2.0 + 0.8:
			th[i] = minf(th[i], -depth * (1.0 - (d - w / 2.0) / 0.8))
		elif d < w / 2.0 + 2.4:
			th[i] += 0.28 * sin((d - w / 2.0 - 0.8) / 1.6 * PI))

func flatten_rect(x0: float, z0: float, x1: float, z1: float, feather: float) -> void:
	_each_vert(x0 - feather, z0 - feather, x1 + feather, z1 + feather, func(i, vx, vz):
		var dx = maxf(maxf(x0 - vx, 0.0), vx - x1)
		var dz = maxf(maxf(z0 - vz, 0.0), vz - z1)
		th[i] *= G.smooth01(Vector2(dx, dz).length() / feather))

func build_terrain(base: Color) -> void:
	var W = TW + 1
	for iz in range(TH_ + 1):
		for ix in range(W):
			var e = mini(mini(ix, iz), mini(TW - ix, TH_ - iz))
			if e < 6:
				th[iz * W + ix] *= e / 6.0
	ter_max = 0.0
	for h in th:
		ter_max = maxf(ter_max, h)
	# visible mesh (built from arrays: much faster than adding vertices one by one)
	var mud = Color(0.31, 0.26, 0.2)
	var hi = base.lightened(0.12)
	var r = RandomNumberGenerator.new()
	r.seed = 77
	var verts = PackedVector3Array()
	var norms = PackedVector3Array()
	var colors = PackedColorArray()
	verts.resize(W * (TH_ + 1)); norms.resize(W * (TH_ + 1)); colors.resize(W * (TH_ + 1))
	for iz in range(TH_ + 1):
		for ix in range(W):
			var i = iz * W + ix
			var h = th[i]
			verts[i] = Vector3(TX0 + ix, h, TZ0 + iz)
			var hl = th[i - 1] if ix > 0 else h
			var hr = th[i + 1] if ix < TW else h
			var hd = th[i - W] if iz > 0 else h
			var hu = th[i + W] if iz < TH_ else h
			norms[i] = Vector3(hl - hr, 2.0, hd - hu).normalized()
			var c = base
			if h < -0.2:
				c = c.lerp(mud, minf(1.0, -h / 0.9))
			elif h > 0.3:
				c = c.lerp(hi, minf(1.0, h / 4.0))
			var v = r.randf_range(0.92, 1.06)
			colors[i] = Color(c.r * v, c.g * v, c.b * v)
	var idx = PackedInt32Array()
	idx.resize(TW * TH_ * 6)
	var k = 0
	for iz in range(TH_):
		for ix in range(TW):
			var a = iz * W + ix
			idx[k] = a; idx[k + 1] = a + 1; idx[k + 2] = a + W
			idx[k + 3] = a + 1; idx[k + 4] = a + W + 1; idx[k + 5] = a + W
			k += 6
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx
	var am = ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	am.surface_set_material(0, mat)
	if terrain_mesh:
		terrain_mesh.queue_free()
	terrain_mesh = MeshInstance3D.new()
	terrain_mesh.mesh = am
	add_child(terrain_mesh)
	# collision
	if terrain_body:
		terrain_body.queue_free()
	terrain_body = StaticBody3D.new()
	terrain_body.collision_layer = G.L_WORLD
	terrain_body.collision_mask = 0
	var cs = CollisionShape3D.new()
	var hm = HeightMapShape3D.new()
	hm.map_width = W
	hm.map_depth = TH_ + 1
	hm.map_data = th
	cs.shape = hm
	terrain_body.add_child(cs)
	terrain_body.position = Vector3(TX0 + TW / 2.0, 0, TZ0 + TH_ / 2.0)
	add_child(terrain_body)

# ---------------------------------------------------------------- walkable height (terrain, floors, stairs)
func surface_y(x: float, z: float, cur: float) -> float:
	var hit = G.ray(Vector3(x, cur + 0.75, z), Vector3(x, cur - 8.0, z), G.L_WORLD)
	if hit.is_empty():
		return ground_y(x, z)
	return hit.position.y

# ---------------------------------------------------------------- static boxes and colliders
func add_box(cx: float, y0: float, cz: float, w: float, h: float, d: float, color: Color, opt: Dictionary = {}):
	var base = 0.0 if opt.get("abs", false) else ground_y(cx, cz)
	var bb = Basis.from_euler(Vector3(opt.get("rx", 0.0), opt.get("ry", 0.0), opt.get("rz", 0.0)))
	var xf = Transform3D(bb.scaled(Vector3(w, h, d)), Vector3(cx, base + y0 + h / 2.0, cz))
	var key = color.to_html(false) + ("n" if opt.get("no_shadow", false) else "s")
	if not groups.has(key):
		groups[key] = {"color": color, "xforms": [], "mm": null, "no_shadow": opt.get("no_shadow", false)}
	var g = groups[key]
	g["xforms"].append(xf)
	var ref = [g, g["xforms"].size() - 1]
	if piece != null:
		piece.append(ref)
	var rotated: bool = opt.get("rx", 0.0) != 0.0 or opt.get("ry", 0.0) != 0.0 or opt.get("rz", 0.0) != 0.0
	if opt.get("collide", true) and not rotated:
		var c = add_col(cx, base + y0, cz, w, h, d)
		c.vis = [ref]
		c.color = color
		c.dest = opt.get("dest", false)
		c.hp = opt.get("hp", 160.0)
		c.no_move = opt.get("no_move", false)
		c.prop = opt.get("mat", 0)
	return ref

func piece_start() -> void:
	piece = []

func piece_end(c, color: Color, hp: float) -> void:
	if c:
		c.vis.append_array(piece)
		c.dest = true
		c.hp = hp
		c.color = color
	piece = null

func add_col(cx: float, y0: float, cz: float, w: float, h: float, d: float, prop: int = 0) -> WCol:
	var c = WCol.new()
	c.lo = Vector3(cx - w / 2.0, y0, cz - d / 2.0)
	c.hi = Vector3(cx + w / 2.0, y0 + h, cz + d / 2.0)
	c.gy = ground_y(cx, cz)
	c.prop = prop
	var b = StaticBody3D.new()
	b.collision_layer = G.L_WORLD
	b.collision_mask = 0
	var cs = CollisionShape3D.new()
	var bs = BoxShape3D.new()
	bs.size = Vector3(w, h, d)
	cs.shape = bs
	b.add_child(cs)
	b.position = Vector3(cx, y0 + h / 2.0, cz)
	b.set_meta("col", c)
	geo_root.add_child(b)
	c.body = b
	cols.append(c)
	_insert_grid(c)
	return c

func finalize_static() -> void:
	for key in groups:
		var g = groups[key]
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = BoxMesh.new()
		mm.instance_count = g["xforms"].size()
		for i in range(g["xforms"].size()):
			mm.set_instance_transform(i, g["xforms"][i])
		var mi = MultiMeshInstance3D.new()
		mi.multimesh = mm
		var mat = StandardMaterial3D.new()
		mat.albedo_color = g["color"]
		mat.roughness = 0.95
		mi.material_override = mat
		if g["no_shadow"]:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		geo_root.add_child(mi)
		g["mm"] = mm

func flat_plane(x: float, z: float, w: float, d: float, color: Color, y: float = 0.012) -> void:
	var m = MeshInstance3D.new()
	var pm = PlaneMesh.new()
	pm.size = Vector2(w, d)
	m.mesh = pm
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	m.material_override = mat
	m.position = Vector3(x, ground_y(x, z) + y, z)
	geo_root.add_child(m)

# ---------------------------------------------------------------- collision queries (our own boxes, for movement and planning)
func _gkey(ix: int, iz: int) -> int:
	return ix * 4096 + iz

func _insert_grid(c) -> void:
	for ix in range(int(floor((c.lo.x - 1.0) / GRID)), int(floor((c.hi.x + 1.0) / GRID)) + 1):
		for iz in range(int(floor((c.lo.z - 1.0) / GRID)), int(floor((c.hi.z + 1.0) / GRID)) + 1):
			var k = _gkey(ix, iz)
			if not grid.has(k):
				grid[k] = []
			grid[k].append(c)

func _remove_grid(c) -> void:
	for ix in range(int(floor((c.lo.x - 1.0) / GRID)), int(floor((c.hi.x + 1.0) / GRID)) + 1):
		for iz in range(int(floor((c.lo.z - 1.0) / GRID)), int(floor((c.hi.z + 1.0) / GRID)) + 1):
			var k = _gkey(ix, iz)
			if grid.has(k):
				grid[k].erase(c)

func cell_at(x: float, z: float) -> Array:
	return grid.get(_gkey(int(floor(x / GRID)), int(floor(z / GRID))), [])

func blocks_at(c, y: float) -> bool:
	return (not c.no_move) and c.hi.y > y + 0.4 and c.lo.y < y + 1.3

func blocks_move(c) -> bool:
	return blocks_at(c, c.gy)

func push_out_circle(pos: Vector3, r: float) -> Array:
	# returns [new_pos, collider_hit_or_null]
	var hit = null
	for c in cell_at(pos.x, pos.z):
		if not blocks_at(c, pos.y):
			continue
		var cx = clampf(pos.x, c.lo.x, c.hi.x)
		var cz = clampf(pos.z, c.lo.z, c.hi.z)
		var dx = pos.x - cx
		var dz = pos.z - cz
		var d2 = dx * dx + dz * dz
		if d2 < r * r:
			hit = c
			if d2 > 1e-8:
				var d = sqrt(d2)
				pos.x = cx + dx / d * r
				pos.z = cz + dz / d * r
			else:
				var l = pos.x - c.lo.x
				var rr = c.hi.x - pos.x
				var f = pos.z - c.lo.z
				var bk = c.hi.z - pos.z
				var m = minf(minf(l, rr), minf(f, bk))
				if m == l: pos.x = c.lo.x - r
				elif m == rr: pos.x = c.hi.x + r
				elif m == f: pos.z = c.lo.z - r
				else: pos.z = c.hi.z + r
	return [pos, hit]

func inside_any(x: float, z: float, r: float, y: float = -999.0) -> bool:
	if y == -999.0:
		y = ground_y(x, z)
	for c in cell_at(x, z):
		if not blocks_at(c, y):
			continue
		if x > c.lo.x - r and x < c.hi.x + r and z > c.lo.z - r and z < c.hi.z + r:
			return true
	return false

func inside_at(x: float, y: float, z: float) -> bool:
	for c in cell_at(x, z):
		if x > c.lo.x and x < c.hi.x and y > c.lo.y and y < c.hi.y and z > c.lo.z and z < c.hi.z:
			return true
	return false

func vaultable(c) -> bool:
	var h: float = c.hi.y - c.gy
	var sx: float = c.hi.x - c.lo.x
	var sz: float = c.hi.z - c.lo.z
	if c.no_move or c.lo.y - c.gy > 0.3 or h < 0.5 or h > 1.2 or minf(sx, sz) > 1.0:
		return false
	var cx: float = (c.lo.x + c.hi.x) / 2.0
	var cz: float = (c.lo.z + c.hi.z) / 2.0
	return not inside_at(cx, c.hi.y + 0.9, cz) and not inside_at(cx, c.hi.y + 1.4, cz)

# ---------------------------------------------------------------- navigation
func nav_cell(x: float, z: float) -> Vector2i:
	return Vector2i(clampi(int(floor((x - NX0) / NCS)), 0, NW - 1), clampi(int(floor((z - NZ0) / NCS)), 0, NH - 1))

func nav_pos(c: Vector2i) -> Vector3:
	var x = NX0 + (c.x + 0.5) * NCS
	var z = NZ0 + (c.y + 0.5) * NCS
	return Vector3(x, ground_y(x, z), z)

func _nav_mark(c) -> void:
	if not blocks_move(c):
		return
	var v = vaultable(c)
	var r = 0.3
	var ix0 = maxi(0, int(floor((c.lo.x - r - NX0) / NCS)))
	var ix1 = mini(NW - 1, int(floor((c.hi.x + r - NX0) / NCS)))
	var iz0 = maxi(0, int(floor((c.lo.z - r - NZ0) / NCS)))
	var iz1 = mini(NH - 1, int(floor((c.hi.z + r - NZ0) / NCS)))
	for iz in range(iz0, iz1 + 1):
		for ix in range(ix0, ix1 + 1):
			var p = Vector2i(ix, iz)
			if v:
				if not astar.is_point_solid(p):
					astar.set_point_weight_scale(p, 4.0)
					nav_vault[iz * NW + ix] = 1
			else:
				astar.set_point_solid(p, true)
				nav_vault[iz * NW + ix] = 0

func build_nav() -> void:
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, NW, NH)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	nav_vault = PackedByteArray()
	nav_vault.resize(NW * NH)
	for c in cols:
		_nav_mark(c)

func update_nav_area(x0: float, z0: float, x1: float, z1: float) -> void:
	var a = nav_cell(x0 - 1.0, z0 - 1.0)
	var b = nav_cell(x1 + 1.0, z1 + 1.0)
	for iz in range(a.y, b.y + 1):
		for ix in range(a.x, b.x + 1):
			astar.set_point_solid(Vector2i(ix, iz), false)
			astar.set_point_weight_scale(Vector2i(ix, iz), 1.0)
			nav_vault[iz * NW + ix] = 0
	for c in cols:
		if c.hi.x > x0 - 2.0 and c.lo.x < x1 + 2.0 and c.hi.z > z0 - 2.0 and c.lo.z < z1 + 2.0:
			_nav_mark(c)

func _nearest_free(c: Vector2i) -> Vector2i:
	if not astar.is_point_solid(c):
		return c
	for r in range(1, 9):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dz) != r:
					continue
				var p = Vector2i(c.x + dx, c.y + dz)
				if astar.is_in_boundsv(p) and not astar.is_point_solid(p):
					return p
	return Vector2i(-1, -1)

func _walk_line(a: Vector2i, b: Vector2i) -> bool:
	var d = Vector2(b - a)
	var n = int(ceil(d.length() * 2.0))
	var vaults = 0
	for i in range(1, n + 1):
		var t = float(i) / n
		var p = Vector2i(roundi(a.x + d.x * t), roundi(a.y + d.y * t))
		if astar.is_point_solid(p):
			return false
		if nav_vault[p.y * NW + p.x] == 1:
			vaults += 1
	return vaults < 4

func find_path(from: Vector3, to: Vector3) -> Array:
	var s = _nearest_free(nav_cell(from.x, from.z))
	var t = _nearest_free(nav_cell(to.x, to.z))
	if s.x < 0 or t.x < 0:
		return []
	var ids: Array = astar.get_id_path(s, t, true)
	if ids.is_empty():
		return []
	var out: Array = []
	var i = 0
	while i < ids.size() - 1:
		var j = mini(ids.size() - 1, i + 30)
		while j > i + 1 and not _walk_line(ids[i], ids[j]):
			j -= 2 if j - 2 > i else 1
		out.append(nav_pos(ids[j]))
		i = j
	if out.is_empty():
		out.append(nav_pos(ids[ids.size() - 1]))
	if ids[ids.size() - 1] == t and not astar.is_point_solid(nav_cell(to.x, to.z)):
		out[out.size() - 1] = Vector3(to.x, ground_y(to.x, to.z), to.z)
	return out

# ---------------------------------------------------------------- cover points
func add_cp(x: float, z: float, n: Vector3, t: Vector3, type: String, c, y: float = -999.0):
	if absf(x) > 125.0 or absf(z) > 90.0:
		return null
	var upper = y != -999.0
	if not upper:
		y = ground_y(x, z)
		if inside_any(x, z, 0.28, y):
			return null
	for o in cover:
		if Vector2(o.p.x - x, o.p.z - z).length_squared() < 0.36 and absf(o.p.y - y) < 1.0 and o.type == type:
			return null
	var cp = CoverPoint.new()
	cp.p = Vector3(x, y, z)
	cp.n = n
	cp.t = t
	cp.type = type
	cp.col = c
	cp.upper = upper
	cover.append(cp)
	return cp

func gen_cover_for(c) -> void:
	var rel: float = c.hi.y - c.gy
	if c.lo.y - c.gy > 0.3 or rel < 0.85 or c.no_move:
		return
	var sx: float = c.hi.x - c.lo.x
	var sz: float = c.hi.z - c.lo.z
	if sx < 0.45 and sz < 0.45:
		return
	var tall = rel >= 1.45
	var off = 0.55
	var faces = [
		{"fixed": c.lo.z - off, "n": Vector3(0, 0, -1), "a": c.lo.x, "b": c.hi.x, "ax": "x"},
		{"fixed": c.hi.z + off, "n": Vector3(0, 0, 1), "a": c.lo.x, "b": c.hi.x, "ax": "x"},
		{"fixed": c.lo.x - off, "n": Vector3(-1, 0, 0), "a": c.lo.z, "b": c.hi.z, "ax": "z"},
		{"fixed": c.hi.x + off, "n": Vector3(1, 0, 0), "a": c.lo.z, "b": c.hi.z, "ax": "z"}]
	for f in faces:
		var L: float = f["b"] - f["a"]
		if not tall:
			var n = maxi(1, roundi(L / 1.5))
			for i in range(n):
				var s: float = f["a"] + (i + 0.5) * L / n
				var p = _face_pt(f, s)
				add_cp(p.x, p.y, f["n"], Vector3.ZERO, "low", c)
		else:
			if L >= 0.7:
				for e in [[f["a"] + 0.3, -1.0], [f["b"] - 0.3, 1.0]]:
					var p = _face_pt(f, e[0])
					var tv = Vector3(e[1], 0, 0) if f["ax"] == "x" else Vector3(0, 0, e[1])
					var px = p.x + tv.x * 0.85
					var pz = p.y + tv.z * 0.85
					var gy = ground_y(px, pz)
					if not inside_at(px, gy + 1.5, pz) and not inside_at(px, gy + 1.0, pz):
						add_cp(p.x, p.y, f["n"], tv, "corner", c)
			if L > 2.4:
				var n2 = roundi((L - 1.2) / 2.2)
				for i in range(n2):
					var p = _face_pt(f, f["a"] + 0.6 + (i + 0.5) * (L - 1.2) / n2)
					add_cp(p.x, p.y, f["n"], Vector3.ZERO, "wall", c)

func _face_pt(f: Dictionary, s: float) -> Vector2:
	if f["ax"] == "x":
		return Vector2(s, f["fixed"])
	return Vector2(f["fixed"], s)

func build_cover() -> void:
	cover = []
	for c in cols:
		gen_cover_for(c)
	for t in terrain_cover:
		add_cp(t[0], t[1], Vector3(t[2], 0, t[3]), Vector3.ZERO, "low", null)
	for T in towers:
		for p in T["posts"]:
			var cp = add_cp(p[0], p[1], Vector3(p[2], 0, p[3]), Vector3.ZERO, "low", null, T["floor_y"])
			if cp:
				cp.tower = T
				T["cps"].append(cp)

# ---------------------------------------------------------------- destruction
func destroy_col(c, depth: int = 0) -> void:
	if not c.alive:
		return
	c.alive = false
	cols.erase(c)
	_remove_grid(c)
	if is_instance_valid(c.body):
		c.body.queue_free()
	var zero = Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0, -500, 0))
	for r in c.vis:
		var g = r[0]
		if g["mm"]:
			g["mm"].set_instance_transform(r[1], zero)
	var size: Vector3 = c.hi - c.lo
	var n = clampi(roundi(size.x * size.y * size.z * 3.0), 4, 14)
	for i in range(n):
		var p = Vector3(randf_range(c.lo.x, c.hi.x), randf_range(c.lo.y, c.hi.y), randf_range(c.lo.z, c.hi.z))
		G.fx.debris(p, Vector3(randf_range(-3, 3), randf_range(1, 5), randf_range(-3, 3)), randf_range(0.15, 0.5), c.color)
	G.fx.dust_cloud((c.lo + c.hi) / 2.0, maxf(size.x, size.z))
	for cp in cover:
		if cp.col == c and cp.owner_s != null and is_instance_valid(cp.owner_s):
			cp.owner_s.cover = null
			cp.owner_s.in_cover = false
	cover = cover.filter(func(cp): return cp.col != c)
	for s in G.soldiers:
		if G.dist2d(s.parts[0].global_position, (c.lo + c.hi) / 2.0) < 7.0:
			s.wake()
	# anything resting on top falls with it
	if depth < 3:
		for o in cols.duplicate():
			if o.dest and o.lo.y >= c.hi.y - 0.15 and o.lo.y <= c.hi.y + 0.4 and o.hi.x > c.lo.x and o.lo.x < c.hi.x and o.hi.z > c.lo.z and o.lo.z < c.hi.z:
				var support = 0
				for s2 in cols:
					if s2 != o and s2.hi.y >= o.lo.y - 0.15 and s2.hi.y <= o.lo.y + 0.2 and s2.hi.x > o.lo.x and s2.lo.x < o.hi.x and s2.hi.z > o.lo.z and s2.lo.z < o.hi.z:
						support += 1
				if support < 2:
					destroy_col(o, depth + 1)
	update_nav_area(c.lo.x, c.lo.z, c.hi.x, c.hi.z)

func damage_area(pos: Vector3, R: float, power: float) -> void:
	for c in cols.duplicate():
		if not c.dest or not c.alive:
			continue
		var cp = Vector3(clampf(pos.x, c.lo.x, c.hi.x), clampf(pos.y, c.lo.y, c.hi.y), clampf(pos.z, c.lo.z, c.hi.z))
		var d = pos.distance_to(cp)
		if d < R:
			c.hp -= 260.0 * power * (1.0 - d / R)
			if c.hp <= 0.0:
				destroy_col(c)

# ---------------------------------------------------------------- map pieces
func wall_run(horiz: bool, fixed: float, a0: float, a1: float, h: float, color: Color, th_: float) -> void:
	var L = a1 - a0
	var s = 0.0
	while s < L - 0.05:
		var seg = minf(L - s, rnd(1.5, 3.0))
		var ruined = rng.randf() < 0.35
		var ph = h * rnd(0.25, 0.75) if ruined else h * rnd(0.85, 1.0)
		var can_open = seg > 1.4 and s > 0.6 and (L - s - seg) > 0.6
		var r = rng.randf()
		var c = a0 + s + seg / 2.0
		if can_open and r < 0.24:
			if ph > 2.6:
				_wall_piece(horiz, fixed, c, seg, 2.4, ph - 2.4, color, th_)
		elif can_open and r < 0.55:
			_wall_piece(horiz, fixed, c, seg, 0.0, 1.0, color, th_)
			if ph > 2.7:
				_wall_piece(horiz, fixed, c, seg, 2.2, ph - 2.2, color, th_)
		else:
			_wall_piece(horiz, fixed, c, seg, 0.0, maxf(ph, 1.1), color, th_)
		s += seg

func _wall_piece(horiz: bool, fixed: float, c: float, ln: float, y0: float, h: float, color: Color, th_: float) -> void:
	if horiz:
		add_box(c, y0, fixed, ln, h, th_, color, {"dest": true, "hp": 200.0})
	else:
		add_box(fixed, y0, c, th_, h, ln, color, {"dest": true, "hp": 200.0})

func building(x: float, z: float, w: float, d: float, h: float) -> void:
	var color: Color = WALLC[rng.randi() % WALLC.size()]
	var t = 0.35
	buildings.append({"x": x, "z": z, "w": w, "d": d, "h": h})
	wall_run(true, z - d / 2.0, x - w / 2.0, x + w / 2.0, h, color, t)
	wall_run(true, z + d / 2.0, x - w / 2.0, x + w / 2.0, h, color, t)
	wall_run(false, x - w / 2.0, z - d / 2.0 + t / 2.0, z + d / 2.0 - t / 2.0, h, color, t)
	wall_run(false, x + w / 2.0, z - d / 2.0 + t / 2.0, z + d / 2.0 - t / 2.0, h, color, t)
	flat_plane(x, z, w - 0.4, d - 0.4, Color(0.44, 0.42, 0.38), 0.02)
	var r = rng.randf()
	if r < 0.45:
		var fw = w * rnd(0.4, 0.7)
		add_box(x - w / 2.0 + fw / 2.0, 3.0, z, fw, 0.25, d - 0.4, Color(0.55, 0.53, 0.47), {"dest": true, "hp": 140.0})
	elif r < 0.8 and h > 4.0:
		var rd = d * rnd(0.35, 0.6)
		add_box(x, h - 0.1, z - d / 2.0 + rd / 2.0, w + 0.2, 0.3, rd, Color(0.36, 0.29, 0.25), {"dest": true, "hp": 140.0})
	for i in range(5):
		add_box(x + rnd(-w / 2.0, w / 2.0), 0.0, z + rnd(-d / 2.0, d / 2.0), rnd(0.5, 1.4), rnd(0.2, 0.5), rnd(0.5, 1.4), Color(0.54, 0.52, 0.47), {"ry": rnd(0.0, 3.0), "collide": false})

# two-storey building with stairs and an upper floor; upper windows become firing posts
func tower(x: float, z: float, w: float, d: float) -> void:
	var color: Color = WALLC[rng.randi() % WALLC.size()]
	var t = 0.35
	var FY = 3.45
	var H = 6.6
	buildings.append({"x": x, "z": z, "w": w, "d": d, "h": H})
	var T = {"x": x, "z": z, "w": w, "d": d, "floor_y": FY, "posts": [], "cps": []}
	var sides = [[true, z - d / 2.0, x - w / 2.0, x + w / 2.0, 0.0, -1.0, -1], [true, z + d / 2.0, x - w / 2.0, x + w / 2.0, 0.0, 1.0, 1],
		[false, x - w / 2.0, z - d / 2.0 + t / 2.0, z + d / 2.0 - t / 2.0, -1.0, 0.0, 2], [false, x + w / 2.0, z - d / 2.0 + t / 2.0, z + d / 2.0 - t / 2.0, 1.0, 0.0, 1]]
	for sd in sides:
		var horiz: bool = sd[0]
		var fixed: float = sd[1]
		var a0: float = sd[2]
		var a1: float = sd[3]
		var nx: float = sd[4]
		var nz: float = sd[5]
		var door: int = sd[6]
		var L = a1 - a0
		var n = maxi(2, roundi(L / 2.0))
		var seg = L / n
		for i in range(n):
			var c = a0 + (i + 0.5) * seg
			var open = "solid"
			if door == i:
				open = "door"
			elif i % 2 == 1 and i < n - 1:
				open = "win"
			if open == "door":
				_tower_piece(horiz, fixed, c, seg, 2.4, FY - 2.4, color, t)
			elif open == "win":
				_tower_piece(horiz, fixed, c, seg, 0.0, 1.0, color, t)
				_tower_piece(horiz, fixed, c, seg, 2.2, FY - 2.2, color, t)
			else:
				_tower_piece(horiz, fixed, c, seg, 0.0, FY, color, t)
			var upper_win = i > 0 and i < n - 1 and (i % 2 == 0 or n <= 3)
			if upper_win:
				_tower_piece(horiz, fixed, c, seg, FY, 1.0, color, t)
				_tower_piece(horiz, fixed, c, seg, FY + 2.2, H - FY - 2.2, color, t)
				var px = c if horiz else fixed - nx * 0.6
				var pz = fixed - nz * 0.6 if horiz else c
				T["posts"].append([px, pz, -nx, -nz])
			else:
				_tower_piece(horiz, fixed, c, seg, FY, H - FY, color, t)
	flat_plane(x, z, w - 0.4, d - 0.4, Color(0.44, 0.42, 0.38), 0.02)
	# stairs along the north inner wall, rising toward +x
	var sx0 = x - w / 2.0 + 0.5
	var sx1 = sx0 + 5.0
	var sz0 = z - d / 2.0 + 0.35
	var sz1 = sz0 + 1.3
	var steps = 12
	for i in range(steps):
		var sh = (i + 1) * FY / steps
		add_box(sx0 + (i + 0.5) * (sx1 - sx0) / steps, 0.0, (sz0 + sz1) / 2.0, (sx1 - sx0) / steps, sh, sz1 - sz0, Color(0.43, 0.4, 0.36), {"collide": false})
	var ramp = StaticBody3D.new()
	ramp.collision_layer = G.L_WORLD
	ramp.collision_mask = 0
	var rcs = CollisionShape3D.new()
	var rb = BoxShape3D.new()
	var rl = Vector2(sx1 - sx0, FY).length()
	rb.size = Vector3(rl, 0.2, sz1 - sz0)
	rcs.shape = rb
	ramp.add_child(rcs)
	var ang = atan2(FY, sx1 - sx0)
	ramp.transform = Transform3D(Basis(Vector3(0, 0, 1), ang), Vector3((sx0 + sx1) / 2.0 + sin(ang) * 0.1, FY / 2.0 - cos(ang) * 0.1, (sz0 + sz1) / 2.0))
	geo_root.add_child(ramp)
	# upper floor around the stairwell
	add_box(x, FY - 0.25, (sz1 + z + d / 2.0 - 0.2) / 2.0, w - 0.5, 0.25, (z + d / 2.0 - 0.2) - sz1, Color(0.52, 0.49, 0.45), {"dest": true, "hp": 260.0})
	add_box((sx1 + x + w / 2.0 - 0.2) / 2.0, FY - 0.25, (sz0 + sz1) / 2.0, (x + w / 2.0 - 0.2) - sx1, 0.25, sz1 - sz0, Color(0.52, 0.49, 0.45), {"dest": true, "hp": 260.0})
	T["floor_rects"] = [[x - w / 2.0 + 0.2, x + w / 2.0 - 0.2, sz1, z + d / 2.0 - 0.2], [sx1, x + w / 2.0 - 0.2, sz0, sz1]]
	T["stair_bottom"] = Vector3(sx0 + 0.2, 0.0, (sz0 + sz1) / 2.0)
	T["stair_top"] = Vector3(sx1 + 0.6, FY, (sz0 + sz1) / 2.0)
	T["inside"] = Vector3(x, 0.0, z + 0.5)
	# keep only posts that stand on the floor
	var ok: Array = []
	for p in T["posts"]:
		for fr in T["floor_rects"]:
			if p[0] > fr[0] + 0.2 and p[0] < fr[1] - 0.2 and p[1] > fr[2] + 0.2 and p[1] < fr[3] - 0.2:
				ok.append(p)
				break
	T["posts"] = ok
	towers.append(T)

func _tower_piece(horiz: bool, fixed: float, c: float, seg: float, y0: float, h: float, color: Color, t: float) -> void:
	if horiz:
		add_box(c, y0, fixed, seg, h, t, color, {"dest": true, "hp": 240.0})
	else:
		add_box(fixed, y0, c, t, h, seg, color, {"dest": true, "hp": 240.0})

func sandbags(x: float, z: float, ln: float, along_x: bool, h: float = 1.0) -> void:
	var rows = roundi(h / 0.5)
	var n = maxi(1, roundi(ln / 0.9))
	piece_start()
	for i in range(n):
		var o = -ln / 2.0 + (i + 0.5) * ln / n
		for k in range(rows):
			var bx = x + o if along_x else x
			var bz = z if along_x else z + o
			add_box(bx, k * 0.5, bz, 0.92 if along_x else 0.62, 0.5, 0.62 if along_x else 0.92, Color(0.69, 0.64, 0.48) if k % 2 == 1 else Color(0.64, 0.58, 0.44), {"collide": false})
	var gy = ground_y(x, z)
	var c
	if along_x:
		c = add_col(x, gy, z, ln, rows * 0.5, 0.65)
	else:
		c = add_col(x, gy, z, 0.65, rows * 0.5, ln)
	piece_end(c, Color(0.66, 0.6, 0.45), 150.0)

func hedgehog(x: float, z: float) -> void:
	var c = Color(0.23, 0.21, 0.2)
	add_box(x, 0.1, z, 1.7, 0.14, 0.14, c, {"rz": 0.6, "ry": 0.3, "collide": false})
	add_box(x, 0.1, z, 1.7, 0.14, 0.14, c, {"rz": -0.6, "ry": 0.3, "collide": false})
	add_box(x, 0.05, z, 0.14, 0.14, 1.7, c, {"rx": 0.6, "collide": false})
	add_col(x, ground_y(x, z), z, 1.1, 0.9, 1.1)

func crate(x: float, z: float, s: float) -> void:
	add_box(x, 0.0, z, s, s, s, Color(0.43, 0.35, 0.23), {"dest": true, "hp": 70.0, "mat": 1})

func truck(x: float, z: float, along_z: bool) -> void:
	var c = Color(0.23, 0.22, 0.2)
	var gy = ground_y(x, z)
	if along_z:
		add_box(x, 0.5, z, 2.4, 1.6, 6.0, c, {"collide": false}); add_box(x, 0.5, z + 3.6, 2.3, 2.1, 1.6, Color(0.2, 0.19, 0.18), {"collide": false})
		add_col(x, gy, z + 0.8, 2.4, 2.2, 7.6)
	else:
		add_box(x, 0.5, z, 6.0, 1.6, 2.4, c, {"collide": false}); add_box(x + 3.6, 0.5, z, 1.6, 2.1, 2.3, Color(0.2, 0.19, 0.18), {"collide": false})
		add_col(x + 0.8, gy, z, 7.6, 2.2, 2.4)
	for o in [-2.0, 2.0]:
		for s in [-1.25, 1.25]:
			if along_z:
				add_box(x + s, 0.0, z + o, 0.4, 0.9, 0.9, Color(0.11, 0.11, 0.11), {"collide": false})
			else:
				add_box(x + o, 0.0, z + s, 0.9, 0.9, 0.4, Color(0.11, 0.11, 0.11), {"collide": false})
	smoke_sources.append(Vector3(x, gy + 2.4, z))

func tank(x: float, z: float) -> void:
	var gy = ground_y(x, z)
	add_box(x, 0.0, z, 7.0, 1.3, 3.6, Color(0.29, 0.3, 0.24), {"collide": false})
	add_box(x, 1.3, z, 3.4, 0.9, 2.8, Color(0.27, 0.28, 0.23), {"collide": false})
	add_box(x + 3.0, 1.65, z, 3.6, 0.22, 0.22, Color(0.23, 0.24, 0.2), {"collide": false})
	add_col(x, gy, z, 7.0, 2.2, 3.6)
	smoke_sources.append(Vector3(x, gy + 2.5, z))

func dead_tree(x: float, z: float) -> void:
	var h = rnd(4.0, 7.0)
	var c = Color(0.24, 0.2, 0.16)
	add_box(x, 0.0, z, 0.32, h, 0.32, c, {"rz": rnd(-0.08, 0.08), "collide": false})
	for i in range(4):
		add_box(x + rnd(-0.6, 0.6), h * rnd(0.5, 0.9), z + rnd(-0.6, 0.6), 0.12, rnd(1.0, 2.2), 0.12, c, {"rz": rnd(-1, 1), "rx": rnd(-1, 1), "collide": false})
	add_col(x, ground_y(x, z), z, 0.4, h, 0.4)

func live_tree(x: float, z: float) -> void:
	var h = rnd(3.0, 5.0)
	add_box(x, 0.0, z, 0.4, h, 0.4, Color(0.29, 0.23, 0.16), {"collide": false})
	add_col(x, ground_y(x, z), z, 0.45, h, 0.45)
	var leaf = [Color(0.27, 0.35, 0.18), Color(0.25, 0.32, 0.16), Color(0.32, 0.39, 0.23)]
	for i in range(3):
		var s = rnd(2.0, 3.4)
		add_box(x + rnd(-0.7, 0.7), h - 0.6 + i * 0.7, z + rnd(-0.7, 0.7), s, s * 0.8, s, leaf[i], {"ry": rnd(0, 1), "collide": false})

func skyline(colors: Array, hmin: float, hmax: float) -> void:
	for i in range(46 if not is_large() else 70):
		var a = rnd(0.0, TAU)
		var r = rnd(1.45, 1.9) * TW / 2.0
		add_box(cos(a) * r, 0.0, sin(a) * r * float(TH_) / float(TW) * 1.1, rnd(8, 20), rnd(hmin, hmax), rnd(8, 18), colors[i % colors.size()], {"collide": false, "no_shadow": true})

func base(sx: float, dist: float = 96.0) -> void:
	var bx = sx * dist
	for i in range(3):
		add_box(bx + sx * 7.0, 0.0, -22.0 + i * 22.0, 6.0, 2.4, 4.0, Color(0.33, 0.38, 0.24) if sx < 0 else Color(0.42, 0.39, 0.28), {"dest": true, "hp": 120.0})
	add_box(bx + sx * 3.0, 0.0, 0.0, 0.15, 7.0, 0.15, Color(0.27, 0.27, 0.27), {"collide": false})
	add_box(bx + sx * 3.9, 5.6, 0.0, 1.6, 1.0, 0.05, G.TEAM_BAND[0] if sx < 0 else G.TEAM_BAND[1], {"collide": false, "no_shadow": true})
	ammo_crate(bx + sx * 1.5, -5.0, 0 if sx < 0 else 1)
	ammo_crate(bx + sx * 1.5, 5.0, 0 if sx < 0 else 1)

# an ammo crate: stand next to it for a second to restock
func ammo_crate(x: float, z: float, team: int) -> void:
	add_box(x, 0.0, z, 1.3, 0.7, 0.8, Color(0.24, 0.29, 0.18), {"mat": 1})
	add_box(x, 0.7, z, 1.32, 0.06, 0.2, Color(0.82, 0.7, 0.2), {"collide": false})
	ammo_points.append({"p": Vector3(x, ground_y(x, z), z), "team": team})

# where a beaten soldier runs back to
# (reinforcements gather behind the most forward control point the team holds, otherwise at base)
func rally_point(team: int) -> Vector3:
	if Obj.chain() or G.mode == "laststand":
		var i = Obj.forward_held(team)
		if i >= 0:
			var p: Vector3 = Obj.points[i]["p"]
			var back = G.flat(spawn[team] - p).normalized()
			return p + back * 14.0
	return spawn[team]

func crater_at(x: float, z: float, r: float, d: float) -> void:
	for rd in roads:
		if x > rd[0] - r * 1.7 and x < rd[1] + r * 1.7 and z > rd[2] - r * 1.7 and z < rd[3] + r * 1.7:
			return
	crater_ter(x, z, r, d)
	for k in range(6):
		var a = k / 6.0 * TAU + 0.3
		terrain_cover.append([x + cos(a) * r * 0.55, z + sin(a) * r * 0.55, -cos(a), -sin(a)])

func hedge_row(x: float, z: float, ln: float, along_x: bool) -> void:
	if along_x:
		add_box(x, 0.0, z, ln, 1.35, 1.1, Color(0.31, 0.35, 0.2), {"dest": true, "hp": 180.0, "mat": 2})
	else:
		add_box(x, 0.0, z, 1.1, 1.35, ln, Color(0.31, 0.35, 0.2), {"dest": true, "hp": 180.0})
	var c = cols[cols.size() - 1]
	piece_start()
	for i in range(int(ln / 2.0)):
		var o = -ln / 2.0 + i * 2.0 + 1.0
		add_box(x + o if along_x else x + rnd(-0.2, 0.2), 1.2, z + rnd(-0.2, 0.2) if along_x else z + o, 1.4, rnd(0.4, 0.8), 1.4, Color(0.34, 0.39, 0.23), {"collide": false, "ry": rnd(0, 1)})
	piece_end(c, Color(0.31, 0.35, 0.2), 180.0)

# ---------------------------------------------------------------- maps
func build_town() -> void:
	for i in range(16):
		var sz = -1.0 if rng.randf() < 0.5 else 1.0
		hill(rnd(-120, 120), sz * rnd(60, 92), rnd(14, 26), rnd(1.5, 4.5))
	for i in range(6):
		var sx = -1.0 if rng.randf() < 0.5 else 1.0
		hill(sx * rnd(110, 128), rnd(-80, 80), rnd(10, 18), rnd(1, 3))
	flatten_rect(-40, -48, 40, 48, 8); flatten_rect(-130, -5, 130, 5, 3); flatten_rect(-130, -28, -84, 28, 6); flatten_rect(84, -28, 130, 28, 6)
	roads = [[-130, 130, -4.5, 4.5], [-17.5, -10.5, -45, 45]]
	for sx in [-1.0, 1.0]:
		for i in range(9):
			crater_at(sx * rnd(52, 72), rnd(-45, 45), rnd(2.2, 3.4), rnd(0.9, 1.3))
	_flatten_roads()
	build_terrain(MAPS["town"]["ground"])
	flat_plane(0, 0, 260, 9, Color(0.29, 0.29, 0.3), 0.015); flat_plane(-14, 0, 7, 90, Color(0.32, 0.31, 0.32), 0.013)
	for b in [[-25, -12, 9, 9, 5], [-24, 30, 9, 9, 4.5], [-4, -30, 9, 8, 5], [-5, -14, 7, 7, 4], [-4, 15, 8, 7, 6], [-5, 31, 10, 9, 5],
			[11, -12, 7, 8, 4.5], [12, 14, 9, 8, 5], [12, 30, 8, 8, 6], [28, -20, 8, 12, 5], [27, 32, 7, 7, 4]]:
		building(b[0], b[1], b[2], b[3], b[4])
	tower(-24, -29, 10, 8); tower(-24, 13, 11, 8); tower(12, -28, 9, 10); tower(28, 14, 10, 9)
	skyline([Color(0.54, 0.56, 0.57), Color(0.49, 0.51, 0.53), Color(0.6, 0.62, 0.62)], 10, 45)
	for sx in [-1.0, 1.0]:
		for z in [-36, -20, -7, 8, 22, 38]:
			sandbags(sx * rnd(44, 50), z + rnd(-2, 2), rnd(3, 5.5), false)
		for z in [-28, -12, 14, 30]:
			sandbags(sx * rnd(60, 66), z + rnd(-2, 2), rnd(3, 5), false)
		for z in [-45, -25, 25, 45]:
			sandbags(sx * rnd(74, 80), z, 5.0, false)
		for i in range(14):
			hedgehog(sx * rnd(36, 70), rnd(-55, 55))
		for i in range(7):
			var x = sx * rnd(33, 38)
			var z = rnd(-40, 40)
			if absf(z) < 5.0:
				continue
			crate(x, z, 1.0)
			if rng.randf() < 0.5:
				crate(x + 1.05, z, 1.0)
		for z in [-38, -16, 22]:
			add_box(sx * 36.0, 0.0, z, 0.4, 1.15, rnd(5, 9), Color(0.6, 0.57, 0.52), {"dest": true, "hp": 120.0})
		base(sx)
	for i in range(16):
		var x = rnd(-30, 30)
		var z = rnd(-44, 44)
		if absf(z) > 5.0:
			crate(x, z, rnd(0.9, 1.2))
	sandbags(-8, -6.2, 4, true); sandbags(-8, 6.2, 4, true); sandbags(-3.5, 0, 3, false)
	truck(-40, 2, true); truck(39, -1.5, false); truck(6, 2.4, false); tank(18, -48); tank(-30, 50)
	for i in range(40):
		var sx = -1.0 if rng.randf() < 0.5 else 1.0
		dead_tree(rnd(-120, 120), sx * rnd(58, 95))
	capture = Vector3(-8, 0, 0)

func build_field() -> void:
	for i in range(22):
		hill(rnd(-120, 120), rnd(-90, 90), rnd(14, 34), rnd(1.2, 4))
	flatten_rect(-4, 24, 8, 36, 6); flatten_rect(-12, -39, 4, -25, 6); flatten_rect(-130, -5, 130, 1, 3)
	flatten_rect(-130, -28, -84, 28, 6); flatten_rect(84, -28, 130, 28, 6); flatten_rect(-14, -14, 14, 10, 5)
	roads = [[-130, 130, -4.5, 0.5]]
	for i in range(10):
		crater_at(rnd(-60, 60), rnd(-60, 60), rnd(2, 3), rnd(0.8, 1.2))
	_flatten_roads()
	build_terrain(MAPS["field"]["ground"])
	flat_plane(0, -2, 260, 5, Color(0.48, 0.42, 0.31), 0.014)
	for sx in [-1.0, 1.0]:
		var z = -70.0
		while z < 70.0:
			if absf(z) >= 6.0:
				var L = rnd(6, 11)
				hedge_row(sx * rnd(18, 22), z + L / 2.0, L, false)
			z += rnd(10, 16)
		z = -70.0
		while z < 70.0:
			if absf(z + 2.0) >= 5.0:
				var L2 = rnd(5, 9)
				hedge_row(sx * rnd(48, 54), z + L2 / 2.0, L2, false)
			z += rnd(12, 18)
		for i in range(6):
			add_box(sx * rnd(28, 70), 0.0, rnd(-60, 60), rnd(5, 9), 1.0, 0.6, Color(0.55, 0.54, 0.5), {"dest": true, "hp": 130.0})
		for i in range(8):
			var hz = rnd(-60, 60)
			if absf(hz + 2.0) < 4.0:
				continue
			add_box(sx * rnd(25, 75), 0.0, hz, 2.2, 1.7, 2.2, Color(0.78, 0.68, 0.36), {"dest": true, "hp": 90.0})
		for i in range(5):
			sandbags(sx * rnd(64, 80), rnd(-50, 50), rnd(3, 5), false)
		for i in range(18):
			var tz = rnd(-90, 90)
			if absf(tz) < 8.0:
				continue
			live_tree(sx * rnd(10, 120), tz)
		base(sx)
	tower(2, 30, 10, 8); building(-4, -32, 12, 10, 6)
	for i in range(10):
		var cz = rnd(-20, 20)
		if absf(cz + 2.0) < 4.0:
			continue
		crate(rnd(-12, 12), cz, 1.0)
	sandbags(0, 6, 4, true); sandbags(0, -10, 4, true); sandbags(-5, -2, 3, false); sandbags(5, -2, 3, false)
	tank(10, -14); truck(-12, 10, false)
	skyline([Color(0.32, 0.38, 0.24), Color(0.36, 0.42, 0.27), Color(0.29, 0.34, 0.21)], 8, 20)
	capture = Vector3(0, 0, -2)

func build_trenches() -> void:
	var lines: Array = []
	for sx in [-1.0, 1.0]:
		for x in [sx * 38.0, sx * 70.0]:
			var pts: Array = []
			var k = 0
			var z = -78.0
			while z <= 78.0:
				pts.append(Vector2(x + (1.4 if k % 2 == 1 else -1.4), z))
				z += 8.0
				k += 1
			trench_ter(pts, 2.4, 1.15)
			lines.append({"pts": pts, "sx": sx})
		for z in [-36.0, 0.0, 36.0]:
			trench_ter([Vector2(sx * 38.0, z), Vector2(sx * 70.0, z)], 2.0, 1.15)
	for i in range(34):
		crater_at(rnd(-30, 30), rnd(-70, 70), rnd(2, 3.6), rnd(0.9, 1.4))
	for sx in [-1.0, 1.0]:
		for i in range(8):
			crater_at(sx * rnd(44, 64), rnd(-70, 70), rnd(2, 3), rnd(0.8, 1.2))
	flatten_rect(-130, -28, -84, 28, 6); flatten_rect(84, -28, 130, 28, 6); flatten_rect(-6, -7, 6, 7, 3)
	build_terrain(MAPS["trenches"]["ground"])
	for L in lines:
		var pts: Array = L["pts"]
		for k in range(pts.size() - 1):
			var a: Vector2 = pts[k]
			var b: Vector2 = pts[k + 1]
			var t = 0.1
			while t < 1.0:
				var p = a.lerp(b, t)
				terrain_cover.append([p.x + 0.45, p.y, -1.0, 0.0])
				terrain_cover.append([p.x - 0.45, p.y, 1.0, 0.0])
				t += 0.2
			var mid = (a + b) / 2.0
			add_box(mid.x, 0.02, mid.y, 0.9, 0.06, a.distance_to(b), Color(0.35, 0.27, 0.2), {"collide": false, "ry": atan2(b.x - a.x, b.y - a.y)})
			if rng.randf() < 0.6:
				sandbags(mid.x - L["sx"] * 2.0, mid.y, rnd(2.5, 4), false, 0.5)
	for sx in [-1.0, 1.0]:
		for i in range(6):
			var x = sx * rnd(46, 62)
			var z = rnd(-60, 60)
			for k in range(5):
				add_box(x, 0.0, z + k * 1.4 - 2.8, 0.08, 0.9, 0.08, Color(0.23, 0.2, 0.17), {"collide": false})
			add_box(x, 0.4, z, 0.04, 0.04, 6.0, Color(0.33, 0.31, 0.29), {"collide": false})
			add_box(x, 0.75, z, 0.04, 0.04, 6.0, Color(0.33, 0.31, 0.29), {"collide": false})
		for i in range(12):
			add_box(sx * rnd(40, 110), 0.0, rnd(-90, 90), 0.35, rnd(1, 3), 0.35, Color(0.23, 0.19, 0.16), {"rz": rnd(-0.3, 0.3)})
		base(sx)
	var cc = Color(0.54, 0.53, 0.5)
	add_box(0, 0, -4, 6, 1.4, 0.6, cc, {"dest": true, "hp": 300.0}); add_box(0, 0, 4, 6, 1.4, 0.6, cc, {"dest": true, "hp": 300.0}); add_box(-3, 0, 0, 0.6, 1.4, 3, cc, {"dest": true, "hp": 300.0})
	for p in [[-3, -4], [3, -4], [-3, 4], [3, 4]]:
		add_box(p[0], 0, p[1], 0.5, 2.1, 0.5, Color(0.49, 0.48, 0.45), {"dest": true, "hp": 300.0})
	add_box(0, 2.1, 0, 6.6, 0.3, 8.6, Color(0.49, 0.48, 0.45), {"dest": true, "hp": 300.0})
	tank(-6, -30); truck(8, 30, true)
	skyline([Color(0.43, 0.42, 0.36), Color(0.37, 0.36, 0.31), Color(0.48, 0.46, 0.41)], 6, 18)
	capture = Vector3.ZERO

# ---------------------------------------------------------------- large maps
# a cluster of houses (some with an upper floor) around a point, keeping clear of roads
func village(cx: float, cz: float, rx: float, rz: float, n: int, towers_: int) -> void:
	var placed: Array = []
	var tries = 0
	while placed.size() < n + towers_ and tries < 200:
		tries += 1
		var tw = placed.size() < towers_
		var w = rnd(8, 11) if tw else rnd(6, 10)
		var d = rnd(7, 9) if tw else rnd(6, 9)
		var x = cx + rnd(-rx, rx)
		var z = cz + rnd(-rz, rz)
		var ok = true
		for q in placed:
			if absf(q[0] - x) < (q[2] + w) / 2.0 + 4.0 and absf(q[1] - z) < (q[3] + d) / 2.0 + 4.0:
				ok = false
				break
		for rd in roads:
			if x + w / 2.0 + 2.0 > rd[0] and x - w / 2.0 - 2.0 < rd[1] and z + d / 2.0 + 2.0 > rd[2] and z - d / 2.0 - 2.0 < rd[3]:
				ok = false
		if not ok:
			continue
		placed.append([x, z, w, d])
		flatten_rect(x - w / 2.0 - 1.0, z - d / 2.0 - 1.0, x + w / 2.0 + 1.0, z + d / 2.0 + 1.0, 3.0)
	return_village = placed

var return_village: Array = []

func _village_build(placed: Array, towers_: int) -> void:
	var i = 0
	for q in placed:
		if i < towers_:
			tower(q[0], q[1], q[2], q[3])
		else:
			building(q[0], q[1], q[2], q[3], rnd(3.5, 6.0))
		i += 1

# a line of sandbagged positions facing along x
func strongpoint(x: float, z: float, facing: float) -> void:
	sandbags(x, z - 4.0, 3.5, true); sandbags(x, z + 4.0, 3.5, true); sandbags(x + facing * 2.0, z, 4.0, false)
	crate(x - facing * 3.0, z + rnd(-3, 3), 1.0)

func build_valley() -> void:
	var W2 = TW / 2.0
	var D2 = TH_ / 2.0
	var X = [-200.0, -100.0, 0.0, 100.0, 200.0]
	var Z = [26.0, -34.0, 0.0, 30.0, -22.0]
	# rolling hills, steeper along the valley sides, and a ridge at D
	for i in range(46):
		var x = rnd(-W2, W2)
		var z = rnd(-D2, D2)
		var side = absf(z) / D2
		hill(x, z, rnd(16, 40), rnd(1.0, 3.0) + side * rnd(2.0, 6.0))
	for k in range(6):
		hill(100.0 + rnd(-30, 30), 30.0 + rnd(-20, 20), rnd(18, 26), rnd(3.0, 5.0))
	roads = [[-W2, W2, -3.5, 3.5]]
	for i in range(5):
		roads.append([X[i] - 3.0, X[i] + 3.0, minf(0.0, Z[i]) - 12.0, maxf(0.0, Z[i]) + 12.0])
	for sx in [-1.0, 1.0]:
		flatten_rect(sx * (W2 - 70.0) - 26.0, -30.0, sx * (W2 - 70.0) + 26.0, 30.0, 8.0)
	var vil: Array = []
	for i in range(5):
		var n = [6, 3, 9, 2, 6][i]
		var tw = [1, 1, 3, 0, 1][i]
		village(X[i], Z[i], 22.0 if i != 2 else 30.0, 20.0, n, tw)
		vil.append([return_village, tw])
		flatten_rect(X[i] - 7.0, Z[i] - 7.0, X[i] + 7.0, Z[i] + 7.0, 4.0)
	# shell holes in no-man's land between the objectives
	for i in range(60):
		crater_at(rnd(-W2 + 90.0, W2 - 90.0), rnd(-D2 + 15.0, D2 - 15.0), rnd(2, 3.4), rnd(0.8, 1.3))
	_flatten_roads()
	build_terrain(MAPS["valley"]["ground"])
	for rd in roads:
		flat_plane((rd[0] + rd[1]) * 0.5, (rd[2] + rd[3]) * 0.5, rd[1] - rd[0], rd[3] - rd[2], Color(0.31, 0.3, 0.3) if rd[1] - rd[0] > 100.0 else Color(0.45, 0.4, 0.31), 0.015)
	for i in range(5):
		_village_build(vil[i][0], vil[i][1])
		var facing_a = 1.0
		strongpoint(X[i] - 10.0, Z[i], -1.0)
		strongpoint(X[i] + 10.0, Z[i], 1.0)
		for k in range(4):
			crate(X[i] + rnd(-6, 6), Z[i] + rnd(-6, 6), rnd(0.9, 1.2))
		ammo_crate(X[i] + 3.0, Z[i] + 5.5, -1)
	# the ridge at D gets a trench line
	trench_ter([Vector2(92.0, 8.0), Vector2(90.0, 30.0), Vector2(93.0, 52.0)], 2.4, 1.1)
	# farmland: hedge rows and tree lines across the valley
	var x = -W2 + 110.0
	while x < W2 - 110.0:
		var z = -D2 + 15.0
		while z < D2 - 15.0:
			var L = rnd(8, 16)
			if absf(z) > 9.0 and rng.randf() < 0.55:
				var near_obj = false
				for i in range(5):
					if absf(x - X[i]) < 28.0 and absf(z - Z[i]) < 26.0:
						near_obj = true
				if not near_obj:
					hedge_row(x + rnd(-3, 3), z + L / 2.0, L, false)
			z += rnd(14, 22)
		x += rnd(24, 34)
	for i in range(140):
		var tx = rnd(-W2 + 20.0, W2 - 20.0)
		var tz = rnd(-D2 + 8.0, D2 - 8.0)
		if absf(tz) < 7.0 or on_road(tx, tz) or inside_any(tx, tz, 2.0):
			continue
		if absf(tz) > D2 * 0.55 or rng.randf() < 0.3:
			live_tree(tx, tz)
	for i in range(14):
		var wx = rnd(-W2 + 100.0, W2 - 100.0)
		var wz = rnd(-60, 60)
		if not inside_any(wx, wz, 4.0) and not on_road(wx, wz):
			if rng.randf() < 0.5:
				tank(wx, wz)
			else:
				truck(wx, wz, rng.randf() < 0.5)
	for sx in [-1.0, 1.0]:
		base(sx, W2 - 70.0)
	skyline([Color(0.32, 0.38, 0.26), Color(0.37, 0.42, 0.3), Color(0.45, 0.47, 0.4)], 10, 28)
	objectives = []
	for i in range(5):
		objectives.append({"p": Vector3(X[i], 0, Z[i]), "name": "ABCDE"[i]})
	capture = objectives[2]["p"]
	spawn = [Vector3(-(W2 - 70.0), 0, 0), Vector3(W2 - 70.0, 0, 0)]

func build_front() -> void:
	var W2 = TW / 2.0
	var D2 = TH_ / 2.0
	var X = [-150.0, -50.0, 50.0, 150.0]
	var lines: Array = []
	for i in range(4):
		var pts: Array = []
		var k = 0
		var z = -D2 + 12.0
		while z <= D2 - 12.0:
			pts.append(Vector2(X[i] + (1.6 if k % 2 == 1 else -1.6) + sin(z * 0.03 + i) * 4.0, z))
			z += 8.0
			k += 1
		trench_ter(pts, 2.4, 1.2)
		lines.append({"pts": pts, "sx": -1.0 if X[i] < 0.0 else 1.0})
		for zc in [-60.0, 0.0, 60.0]:
			trench_ter([Vector2(X[i] - 12.0, zc), Vector2(X[i] + 12.0, zc)], 2.0, 1.1)
	for i in range(120):
		crater_at(rnd(-W2 + 70.0, W2 - 70.0), rnd(-D2 + 10.0, D2 - 10.0), rnd(2, 4), rnd(0.9, 1.5))
	for sx in [-1.0, 1.0]:
		flatten_rect(sx * (W2 - 55.0) - 24.0, -28.0, sx * (W2 - 55.0) + 24.0, 28.0, 6.0)
	for i in range(4):
		flatten_rect(X[i] + 6.0, -7.0, X[i] + 16.0, 7.0, 3.0)
	build_terrain(MAPS["front"]["ground"])
	for L in lines:
		var pts: Array = L["pts"]
		for k in range(pts.size() - 1):
			var a: Vector2 = pts[k]
			var b: Vector2 = pts[k + 1]
			var t = 0.1
			while t < 1.0:
				var p = a.lerp(b, t)
				terrain_cover.append([p.x + 0.45, p.y, -1.0, 0.0])
				terrain_cover.append([p.x - 0.45, p.y, 1.0, 0.0])
				t += 0.2
			var mid = (a + b) / 2.0
			add_box(mid.x, 0.02, mid.y, 0.9, 0.06, a.distance_to(b), Color(0.35, 0.27, 0.2), {"collide": false, "ry": atan2(b.x - a.x, b.y - a.y)})
			if rng.randf() < 0.5:
				sandbags(mid.x + 2.0, mid.y, rnd(2.5, 4), false, 0.5)
			if rng.randf() < 0.5:
				sandbags(mid.x - 2.0, mid.y, rnd(2.5, 4), false, 0.5)
	# barbed wire and stakes in no-man's land
	for i in range(40):
		var x = rnd(-W2 + 80.0, W2 - 80.0)
		var z = rnd(-D2 + 15.0, D2 - 15.0)
		for k in range(5):
			add_box(x, 0.0, z + k * 1.4 - 2.8, 0.08, 0.9, 0.08, Color(0.23, 0.2, 0.17), {"collide": false})
		add_box(x, 0.4, z, 0.04, 0.04, 6.0, Color(0.33, 0.31, 0.29), {"collide": false})
		add_box(x, 0.75, z, 0.04, 0.04, 6.0, Color(0.33, 0.31, 0.29), {"collide": false})
	for i in range(50):
		add_box(rnd(-W2 + 40.0, W2 - 40.0), 0.0, rnd(-D2 + 5.0, D2 - 5.0), 0.35, rnd(1, 3.5), 0.35, Color(0.23, 0.19, 0.16), {"rz": rnd(-0.3, 0.3)})
	# a concrete bunker behind each line: the control point
	var cc = Color(0.54, 0.53, 0.5)
	for i in range(4):
		var bx = X[i] + 11.0
		add_box(bx, 0, -4, 6, 1.4, 0.6, cc, {"dest": true, "hp": 300.0}); add_box(bx, 0, 4, 6, 1.4, 0.6, cc, {"dest": true, "hp": 300.0})
		for p in [[-3, -4], [3, -4], [-3, 4], [3, 4]]:
			add_box(bx + p[0], 0, p[1], 0.5, 2.1, 0.5, Color(0.49, 0.48, 0.45), {"dest": true, "hp": 300.0})
		add_box(bx, 2.1, 0, 6.6, 0.3, 8.6, Color(0.49, 0.48, 0.45), {"dest": true, "hp": 300.0})
		ammo_crate(bx - 1.0, 0.0, -1)
	for i in range(10):
		var wx = rnd(-W2 + 90.0, W2 - 90.0)
		var wz = rnd(-D2 + 20.0, D2 - 20.0)
		if not inside_any(wx, wz, 4.0):
			tank(wx, wz)
	for i in range(30):
		dead_tree(rnd(-W2 + 20.0, W2 - 20.0), rnd(-D2 + 5.0, D2 - 5.0))
	for sx in [-1.0, 1.0]:
		base(sx, W2 - 55.0)
	skyline([Color(0.43, 0.42, 0.36), Color(0.37, 0.36, 0.31), Color(0.48, 0.46, 0.41)], 6, 18)
	objectives = []
	for i in range(4):
		objectives.append({"p": Vector3(X[i] + 11.0, 0, 0), "name": "ABCD"[i]})
	capture = objectives[1]["p"]
	spawn = [Vector3(-(W2 - 55.0), 0, 0), Vector3(W2 - 55.0, 0, 0)]

# roads are flat painted strips, so the ground under them must be flat too (no hills or holes hidden under the paint)
func _flatten_roads() -> void:
	for rd in roads:
		flatten_rect(rd[0], rd[2], rd[1], rd[3], 2.5)

func on_road(x: float, z: float) -> bool:
	for r in roads:
		if x > r[0] and x < r[1] and z > r[2] and z < r[3]:
			return true
	return false

func build_decor() -> void:
	# grass
	var n = int(4000.0 * TW * TH_ / (260.0 * 190.0))
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var cm = CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.09
	cm.height = 0.45
	cm.radial_segments = 4
	cm.rings = 1
	mm.mesh = cm
	mm.instance_count = n
	var k = 0
	var tries = 0
	while k < n and tries < n * 3:
		tries += 1
		var x = rnd(bounds.position.x, bounds.end.x)
		var z = rnd(bounds.position.y, bounds.end.y)
		var gy = ground_y(x, z)
		if on_road(x, z) or inside_any(x, z, 0.3) or gy < -0.4:
			continue
		var inb = false
		for b in buildings:
			if absf(x - b["x"]) < b["w"] / 2.0 and absf(z - b["z"]) < b["d"] / 2.0:
				inb = true
				break
		if inb:
			continue
		var s = rnd(0.6, 1.5)
		var bs = Basis.from_euler(Vector3(rnd(-0.3, 0.3), rnd(0, 6), rnd(-0.3, 0.3))).scaled(Vector3(s, s * rnd(0.7, 1.4), s))
		mm.set_instance_transform(k, Transform3D(bs, Vector3(x, gy + 0.2 * s, z)))
		mm.set_instance_color(k, Color.from_hsv(rnd(0.14, 0.2), rnd(0.3, 0.45), rnd(0.32, 0.45)))
		k += 1
	mm.visible_instance_count = k
	var mi = MultiMeshInstance3D.new()
	mi.multimesh = mm
	var gm = StandardMaterial3D.new()
	gm.vertex_color_use_as_albedo = true
	gm.vertex_color_is_srgb = true
	gm.roughness = 1.0
	mi.material_override = gm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	geo_root.add_child(mi)
	# rubble around buildings
	if buildings.size() > 0:
		var nr = mini(900, buildings.size() * 60)
		var rm = MultiMesh.new()
		rm.transform_format = MultiMesh.TRANSFORM_3D
		rm.use_colors = true
		rm.mesh = BoxMesh.new()
		rm.instance_count = nr
		for i in range(nr):
			var b = buildings[i % buildings.size()]
			var side = rng.randf() < 0.5
			var sgn = -1.0 if rng.randf() < 0.5 else 1.0
			var x: float = b["x"] + (rnd(-b["w"] / 2.0 - 1.5, b["w"] / 2.0 + 1.5) if side else sgn * (b["w"] / 2.0 + rnd(-0.6, 1.6)))
			var z: float = b["z"] + (sgn * (b["d"] / 2.0 + rnd(-0.6, 1.6)) if side else rnd(-b["d"] / 2.0 - 1.5, b["d"] / 2.0 + 1.5))
			var s = rnd(0.08, 0.32)
			var bs = Basis.from_euler(Vector3(rnd(0, 3), rnd(0, 3), rnd(0, 3))).scaled(Vector3(s * rnd(1, 2), s, s * rnd(1, 1.6)))
			rm.set_instance_transform(i, Transform3D(bs, Vector3(x, ground_y(x, z) + s * 0.3, z)))
			var wc: Color = WALLC[rng.randi() % WALLC.size()]
			rm.set_instance_color(i, wc.darkened(rnd(0.0, 0.3)))
		var ri = MultiMeshInstance3D.new()
		ri.multimesh = rm
		var rmat = StandardMaterial3D.new()
		rmat.vertex_color_use_as_albedo = true
		rmat.vertex_color_is_srgb = true
		ri.material_override = rmat
		geo_root.add_child(ri)

func load_map(id: String) -> void:
	if not MAPS.has(id):
		id = "town"
	if geo_root:
		geo_root.queue_free()
	geo_root = Node3D.new()
	add_child(geo_root)
	cols = []; grid = {}; groups = {}; cover = []; terrain_cover = []; towers = []; smoke_sources = []; buildings = []; roads = []; ammo_points = []
	var sz: Vector2 = MAPS[id].get("size", Vector2(260, 190))
	_set_size(sz.x, sz.y)
	objectives = []
	th = PackedFloat32Array()
	th.resize((TW + 1) * (TH_ + 1))
	th.fill(0.0)
	rng.seed = MAPS[id]["seed"]
	G.map_id = id
	spawn = [Vector3(-96, 0, 0), Vector3(96, 0, 0)]
	if id == "town":
		build_town()
	elif id == "field":
		build_field()
	elif id == "valley":
		build_valley()
	elif id == "front":
		build_front()
	else:
		build_trenches()
	if objectives.is_empty():
		objectives = [{"p": capture, "name": "A"}]
	finalize_static()
	build_nav()
	build_cover()
	build_decor()
	for s in smoke_sources:
		G.fx.wreck_smoke(s, geo_root)
