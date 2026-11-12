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
var roof_cols: Array = []     # pitched roofs: somewhere a man only ends up by being blown there
var smoke_sources: Array = []
var buildings: Array = []
var roads: Array = []
var spawn = [Vector3(-96, 0, 0), Vector3(96, 0, 0)]
var capture = Vector3.ZERO
var bounds = Rect2(-128, -93, 256, 186)   # playable area (x, z)
var water: Array = []          # [x0, x1, z0, z1, level] areas of deep water (rivers, sea)
var bridges: Array = []        # [x0, x1, z0, z1, deck_y, col]
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
# vehicles path on a coarser grid where everything solid is grown by a vehicle's half-width
const VCS = 2.0
const VCLEAR = 1.6
var vastar = AStarGrid2D.new()
var VW = 130
var VH = 95

const WALLC = [Color(0.78, 0.71, 0.56), Color(0.73, 0.64, 0.49), Color(0.61, 0.59, 0.55), Color(0.56, 0.33, 0.27), Color(0.82, 0.76, 0.62)]
var MAPS = {
	"town": {"name": "Town ruins", "ground": Color(0.48, 0.45, 0.37), "seed": 1337},
	"field": {"name": "Farmland", "ground": Color(0.44, 0.46, 0.31), "seed": 4242},
	"trenches": {"name": "Trenches", "ground": Color(0.42, 0.38, 0.30), "seed": 777},
	"valley": {"name": "Valley offensive (large)", "ground": Color(0.43, 0.45, 0.32), "seed": 9001, "size": Vector2(660, 260)},
	"river": {"name": "River crossing (large)", "ground": Color(0.42, 0.46, 0.3), "seed": 4410, "size": Vector2(560, 240)},
	"forest": {"name": "Forest", "ground": Color(0.33, 0.38, 0.24), "seed": 2601, "size": Vector2(300, 220)},
	"city": {"name": "City blocks", "ground": Color(0.45, 0.44, 0.41), "seed": 8080, "size": Vector2(300, 220)},
	"pass": {"name": "Mountain pass (large)", "ground": Color(0.4, 0.42, 0.3), "seed": 3300, "size": Vector2(560, 220)},
	"beach": {"name": "Beach landing", "ground": Color(0.72, 0.66, 0.48), "seed": 1944, "size": Vector2(300, 240)},
	"random": {"name": "Random", "ground": Color(0.44, 0.45, 0.33), "seed": 1, "size": Vector2(360, 220)},
	"front": {"name": "Western front (large)", "ground": Color(0.41, 0.37, 0.3), "seed": 1916, "size": Vector2(560, 240)},
	"huge": {"name": "Huge battlefield (huge)", "ground": Color(0.43, 0.46, 0.31), "seed": 5150, "size": Vector2(840, 340)},
	"factory": {"name": "Tank factory (indoor)", "ground": Color(0.44, 0.43, 0.4), "seed": 6060, "size": Vector2(300, 200)},
}

# the extra ground round a map enlarged for commander mode: woods, hedges, farms and ruins,
# and the two bases pushed out toward the new edges
func _outskirts(core: Vector2) -> void:
	var W2 = TW / 2.0
	var D2 = TH_ / 2.0
	var cx = core.x / 2.0 - 6.0
	var cz = core.y / 2.0 - 6.0
	var outside = func(x: float, z: float) -> bool:
		return absf(x) > cx or absf(z) > cz
	var tries = 0
	var placed = 0
	while placed < 26 and tries < 400:
		tries += 1
		var x = rnd(-W2 + 15.0, W2 - 15.0)
		var z = rnd(-D2 + 15.0, D2 - 15.0)
		if not outside.call(x, z) or inside_any(x, z, 9.0):
			continue
		var r = rng.randf()
		if r >= 0.7 and near_road(x, z, 9.0):
			continue
		if r < 0.45:
			for k in range(rng.randi_range(4, 9)):
				var tx = x + rnd(-9.0, 9.0)
				var tz = z + rnd(-9.0, 9.0)
				if outside.call(tx, tz) and not inside_any(tx, tz, 1.5) and not near_road(tx, tz, 2.5):
					live_tree(tx, tz)
		elif r < 0.7:
			hedge_row(x, z, rnd(10.0, 22.0), rng.randf() < 0.5)
		elif r < 0.85:
			if rng.randf() < 0.3:
				house(x, z, rnd(11.5, 14.0), rnd(8.5, 10.0))
			else:
				house(x, z, rnd(7.0, 9.0), rnd(6.5, 8.0))
		else:
			building(x, z, rnd(6.0, 9.0), rnd(6.0, 8.0), rnd(3.5, 5.0))
		placed += 1
	for k in range(30):
		var bx = rnd(-W2 + 8.0, W2 - 8.0)
		var bz = rnd(-D2 + 8.0, D2 - 8.0)
		if outside.call(bx, bz) and not inside_any(bx, bz, 2.0):
			bush(bx, bz)
	# bases out near the new edges, so there's ground to fight over
	for t in range(mini(2, spawn.size())):
		var sx = signf(spawn[t].x) if spawn[t].x != 0.0 else (1.0 if t == 1 else -1.0)
		spawn[t] = Vector3(sx * (W2 - 45.0), 0, spawn[t].z)

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

func water_level(x: float, z: float) -> float:
	for w in water:
		if x > w[0] and x < w[1] and z > w[2] and z < w[3]:
			return w[4]
	return -99.0

func in_water(x: float, z: float) -> bool:
	for w in water:
		if x > w[0] and x < w[1] and z > w[2] and z < w[3] and ground_y(x, z) < w[4] - 0.3:
			for b in bridges:
				if b[5].alive and x > b[0] and x < b[1] and z > b[2] and z < b[3]:
					return false
			return true
	return false

# close to the edge of a river or the sea (wet, muddy ground)
func near_water(x: float, z: float, r: float) -> bool:
	for w in water:
		if x > w[0] - r and x < w[1] + r and z > w[2] - r and z < w[3] + r and ground_y(x, z) < w[4] + 1.2:
			return true
	return false

# vehicles drive on bridge decks; everything else on the ground
func drive_y(x: float, z: float) -> float:
	for b in bridges:
		if b[5].alive and x > b[0] - 0.5 and x < b[1] + 0.5 and z > b[2] and z < b[3]:
			return b[4]
	return ground_y(x, z)

# water: rippling, reflecting the sky more the flatter you look across it, with the sun glinting off it
static var water_shader: Shader = null
var water_mats: Array = []

func add_water(x0: float, x1: float, z0: float, z1: float, level: float, col: Color) -> void:
	water.append([x0, x1, z0, z1, level])
	var m = MeshInstance3D.new()
	var pm = PlaneMesh.new()
	pm.size = Vector2(x1 - x0, z1 - z0)
	m.mesh = pm
	if water_shader == null:
		water_shader = Shader.new()
		water_shader.code = """shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
uniform vec4 deep : source_color = vec4(0.2, 0.3, 0.32, 0.8);
uniform vec4 sky : source_color = vec4(0.62, 0.7, 0.78, 1.0);
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz;
	float t = TIME;
	vec3 n = normalize(vec3(
		0.10 * cos(p.x * 0.9 + t * 1.3) + 0.06 * cos(p.x * 2.3 + p.y * 1.7 + t * 2.1) + 0.035 * cos((p.x - p.y) * 4.3 + t * 3.1),
		1.0,
		0.10 * cos(p.y * 0.8 - t * 1.1) + 0.06 * cos(p.y * 2.1 - p.x * 1.3 + t * 1.9) + 0.035 * cos((p.x + p.y) * 3.9 - t * 2.7)));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(deep.rgb, sky.rgb, clamp(fres * 0.85 + 0.08, 0.0, 1.0));
	ROUGHNESS = 0.06;
	SPECULAR = 0.95;
	METALLIC = 0.0;
	ALPHA = mix(deep.a, 1.0, fres);
}"""
	var mat = ShaderMaterial.new()
	mat.shader = water_shader
	mat.set_shader_parameter("deep", col)
	water_mats.append(mat)
	m.material_override = mat
	m.position = Vector3((x0 + x1) / 2.0, level, (z0 + z1) / 2.0)
	_geo().add_child(m)

# a destructible deck across a river; when it's blown the crossing is gone
func bridge(x0: float, x1: float, zc: float, wide: float) -> void:
	var deck_y = 0.15
	var c = add_col((x0 + x1) / 2.0, deck_y - 0.5, zc, x1 - x0, 0.5, wide)
	var ref = add_box((x0 + x1) / 2.0, deck_y - 0.5, zc, x1 - x0, 0.5, wide, Color(0.42, 0.38, 0.32), {"abs": true, "collide": false})
	c.vis = [ref]
	c.dest = true
	c.hp = 400.0
	c.color = Color(0.42, 0.38, 0.32)
	c.no_move = true
	for k in [-1.0, 1.0]:
		add_box((x0 + x1) / 2.0, deck_y, zc + k * (wide / 2.0 - 0.15), x1 - x0, 1.0, 0.25, Color(0.36, 0.33, 0.29), {"abs": true, "collide": false})
	for i in range(int((x1 - x0) / 8.0) + 1):
		add_box(x0 + i * 8.0, -3.0, zc, 1.0, deck_y + 2.5, wide - 1.0, Color(0.4, 0.38, 0.34), {"abs": true, "collide": false})
	bridges.append([x0, x1, zc - wide / 2.0, zc + wide / 2.0, deck_y, c])

# a bridge running north-south (along z)
func bridge_z(z0: float, z1: float, xc: float, wide: float) -> void:
	var deck_y = 0.15
	var c = add_col(xc, deck_y - 0.5, (z0 + z1) / 2.0, wide, 0.5, z1 - z0)
	var ref = add_box(xc, deck_y - 0.5, (z0 + z1) / 2.0, wide, 0.5, z1 - z0, Color(0.42, 0.38, 0.32), {"abs": true, "collide": false})
	c.vis = [ref]
	c.dest = true
	c.hp = 400.0
	c.color = Color(0.42, 0.38, 0.32)
	c.no_move = true
	for k in [-1.0, 1.0]:
		c.vis.append(add_box(xc + k * (wide / 2.0 - 0.15), deck_y, (z0 + z1) / 2.0, 0.25, 1.0, z1 - z0, Color(0.36, 0.33, 0.29), {"abs": true, "collide": false}))
	bridges.append([xc - wide / 2.0, xc + wide / 2.0, z0, z1, deck_y, c])

func set_water_sky(c: Color) -> void:
	for m in water_mats:
		m.set_shader_parameter("sky", c)

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

# ground colours painted in the editor (index 0 = the map's own colour)
const PAINT = [Color(0, 0, 0), Color(0.38, 0.47, 0.26), Color(0.56, 0.53, 0.34), Color(0.43, 0.35, 0.24), Color(0.3, 0.25, 0.19),
	Color(0.74, 0.67, 0.48), Color(0.5, 0.5, 0.48), Color(0.9, 0.91, 0.93), Color(0.19, 0.17, 0.15), Color(0.32, 0.32, 0.33)]
const PAINT_NAMES = ["Default", "Grass", "Dry grass", "Dirt", "Mud", "Sand", "Rock", "Snow", "Scorched", "Tarmac"]
const PAINT_GRASS = [true, true, true, false, false, false, false, false, false, false]
var paint: PackedByteArray = PackedByteArray()

func paint_at(x: float, z: float) -> int:
	if paint.is_empty():
		return 0
	var ix = clampi(int(round(x - TX0)), 0, TW)
	var iz = clampi(int(round(z - TZ0)), 0, TH_)
	var i = iz * (TW + 1) + ix
	return paint[i] if i < paint.size() else 0

func build_terrain(base: Color) -> void:
	var W = TW + 1
	var painted = paint.size() == th.size()
	for iz in range(TH_ + 1):
		for ix in range(W):
			var e = mini(mini(ix, iz), mini(TW - ix, TH_ - iz))
			# the ground eases down to the edge (but the seabed stays under the sea, or it shows as a rim)
			if e < 6 and th[iz * W + ix] > -0.4:
				th[iz * W + ix] *= e / 6.0
	ter_max = 0.0
	for h in th:
		ter_max = maxf(ter_max, h)
	# visible mesh (built from arrays: much faster than adding vertices one by one)
	var mud = Color(0.31, 0.26, 0.2)
	# high ground: a touch drier and lighter, never bleached (big hill maps were washing out to near white)
	var hi = base.lerp(Color(0.5, 0.5, 0.36), 0.35)
	var r = RandomNumberGenerator.new()
	r.seed = 77
	# big soft patches of drier and lusher ground so fields aren't one flat colour
	var noise = FastNoiseLite.new()
	noise.seed = 1234
	noise.frequency = 0.018
	var dry = base.lerp(Color(0.56, 0.5, 0.35), 0.35)
	var lush = base.lerp(Color(0.3, 0.42, 0.22), 0.35)
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
			var nz = noise.get_noise_2d(TX0 + ix, TZ0 + iz)
			var c = base.lerp(dry, clampf(nz * 1.6, 0.0, 1.0)).lerp(lush, clampf(-nz * 1.6, 0.0, 1.0))
			if painted and paint[i] > 0 and paint[i] < PAINT.size():
				c = PAINT[paint[i]]
			if h < -0.2:
				c = c.lerp(mud, minf(1.0, -h / 0.9))
			elif h > 0.3:
				c = c.lerp(hi, minf(0.6, h / 8.0))
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
# raycasting for the walking surface is only needed upstairs, on stairs, or on top of things;
# out in the open the heightmap is exact and much cheaper
func surface_y(x: float, z: float, cur: float) -> float:
	var g = ground_y(x, z)
	if not water.is_empty():
		var wl = water_level(x, z)
		if wl > -50.0 and g < wl - 0.3:
			# wading: chest deep at most (bridge decks are found by the ray below)
			var hit = _surface_ray(x, z, cur)
			return maxf(hit, wl - 1.25)
	if cur < g + 0.2:
		var in_tower = false
		for T in towers:
			var r = T.get("rect")
			if r != null and x > r[0] and x < r[1] and z > r[2] and z < r[3]:
				in_tower = true
				break
		if not in_tower:
			return g
	return _surface_ray(x, z, cur)

func _surface_ray(x: float, z: float, cur: float) -> float:
	var hit = G.ray(Vector3(x, cur + 0.75, z), Vector3(x, cur - 8.0, z), G.L_WORLD)
	if hit.is_empty():
		return ground_y(x, z)
	return hit.position.y

# ---------------------------------------------------------------- static boxes and colliders
var openings: Array = []          # doorways and windows of intact buildings (doors and glass go in them)
var edit_node: Node3D = null      # map editor: geometry goes into this node as separate meshes
var dyn_mode = false             # building during a battle (engineers): separate meshes but real colliders
var dyn_root: Node3D = null

# put something up in the middle of a battle: it gets collision, cover points and updated navigation
func build_now(fn: Callable) -> void:
	if dyn_root == null or not is_instance_valid(dyn_root):
		dyn_root = Node3D.new()
		geo_root.add_child(dyn_root)
	var before = cols.size()
	edit_node = dyn_root
	dyn_mode = true
	fn.call()
	edit_node = null
	dyn_mode = false
	for i in range(before, cols.size()):
		var c = cols[i]
		gen_cover_for(c)
		update_nav_area(c.lo.x, c.lo.z, c.hi.x, c.hi.z)
static var edit_mats = {}
static var unit_box: BoxMesh = null
static var shape_meshes = {}

# unit-sized meshes for non-box shapes (blob = lumpy foliage clump)
static func shape_mesh(shape: String) -> Mesh:
	if shape_meshes.has(shape):
		return shape_meshes[shape]
	var m: Mesh
	match shape:
		"blob":
			var sm = SphereMesh.new()
			sm.radius = 0.5
			sm.height = 1.0
			sm.radial_segments = 9
			sm.rings = 5
			var arr = sm.get_mesh_arrays()
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			var st = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for i in idx:
				var v: Vector3 = verts[i]
				var hsh = sin(v.x * 37.1 + v.y * 17.3 + v.z * 29.7) * 0.5 + 0.5
				st.add_vertex(v * (0.86 + hsh * 0.26))
			st.generate_normals()
			m = st.commit()
		"cyl":
			var cm = CylinderMesh.new()
			cm.top_radius = 0.5
			cm.bottom_radius = 0.5
			cm.height = 1.0
			cm.radial_segments = 10
			cm.rings = 1
			m = cm
		"cone":
			var cn = CylinderMesh.new()
			cn.top_radius = 0.0
			cn.bottom_radius = 0.5
			cn.height = 1.0
			cn.radial_segments = 8
			cn.rings = 1
			m = cn
		"prism":
			var pm = PrismMesh.new()
			pm.size = Vector3.ONE
			m = pm
		"pillow":
			m = Props.bag_mesh()
		"leaves":
			m = Props.leaf_mesh()
		"bag":
			var cp = CapsuleMesh.new()
			cp.radius = 0.25
			cp.height = 1.0
			cp.radial_segments = 8
			cp.rings = 2
			m = cp
		"wheel":
			var wm = CylinderMesh.new()
			wm.top_radius = 0.5
			wm.bottom_radius = 0.5
			wm.height = 1.0
			wm.radial_segments = 14
			wm.rings = 1
			m = wm
		_:
			m = BoxMesh.new()
	shape_meshes[shape] = m
	return m

func _geo() -> Node3D:
	return edit_node if edit_node != null else geo_root

func add_box(cx: float, y0: float, cz: float, w: float, h: float, d: float, color: Color, opt: Dictionary = {}):
	# leafy clumps get a ragged edge of leaves round them
	if opt.get("shape", "") == "blob" and Props.is_leafy(color) and not opt.get("bare", false):
		var lo = opt.duplicate()
		lo["shape"] = "leaves"
		lo["collide"] = false
		lo["no_shadow"] = true
		add_box(cx, y0 - h * 0.04, cz, w * 1.08, h * 1.08, d * 1.08, color, lo)
	var base = 0.0 if opt.get("abs", false) else ground_y(cx, cz)
	var bb = Basis.from_euler(Vector3(opt.get("rx", 0.0), opt.get("ry", 0.0), opt.get("rz", 0.0)))
	var xf = Transform3D(bb.scaled(Vector3(w, h, d)), Vector3(cx, base + y0 + h / 2.0, cz))
	if edit_node != null:
		if unit_box == null:
			unit_box = BoxMesh.new()
		var key0 = color.to_html()
		if not edit_mats.has(key0):
			var em = StandardMaterial3D.new()
			em.albedo_color = color
			em.roughness = 0.95
			edit_mats[key0] = em
		var mi = MeshInstance3D.new()
		mi.mesh = unit_box if opt.get("shape", "") == "" else shape_mesh(opt["shape"])
		var pm0 = Props.mat_for(color, opt.get("shape", ""))
		mi.material_override = pm0 if pm0 != null else edit_mats[key0]
		mi.transform = xf
		edit_node.add_child(mi)
		var nref = [mi, -2]
		if piece != null:
			piece.append(nref)
		if opt.get("collide", true) and not (opt.get("rx", 0.0) != 0.0 or opt.get("ry", 0.0) != 0.0 or opt.get("rz", 0.0) != 0.0) and dyn_mode:
			var dc = add_col(cx, base + y0, cz, w, h, d)
			dc.vis = [nref]
			dc.color = color
			dc.dest = opt.get("dest", true)
			dc.hp = opt.get("hp", 160.0 if opt.has("dest") else 300.0)
			dc.prop = opt.get("mat", 0)
		return nref
	var shp: String = opt.get("shape", "")
	var key = color.to_html(false) + ("n" if opt.get("no_shadow", false) else "s") + shp
	if not groups.has(key):
		groups[key] = {"color": color, "xforms": [], "mm": null, "no_shadow": opt.get("no_shadow", false), "shape": shp}
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
		c.dest = opt.get("dest", true)
		c.hp = opt.get("hp", 160.0 if opt.has("dest") else 300.0)
		c.no_move = opt.get("no_move", false)
		c.prop = opt.get("mat", 0)
	return ref

# ---------------------------------------------------------------- seeing into buildings
# every drawn piece of a building above its ground floor, so the roof and upper storeys can be lifted off
var cut_now: Dictionary = {}

func _cut_index() -> void:
	var grid = {}
	for i in range(buildings.size()):
		var b = buildings[i]
		b["idx"] = i
		b["upper"] = []
		b["gy"] = ground_y(b["x"], b["z"])
		for cx in range(floori((b["x"] - b["w"] / 2.0 - 1.0) / 6.0), floori((b["x"] + b["w"] / 2.0 + 1.0) / 6.0) + 1):
			for cz in range(floori((b["z"] - b["d"] / 2.0 - 1.0) / 6.0), floori((b["z"] + b["d"] / 2.0 + 1.0) / 6.0) + 1):
				var k = Vector2i(cx, cz)
				if not grid.has(k):
					grid[k] = []
				grid[k].append(b)
	if grid.is_empty():
		return
	for key in groups:
		var g = groups[key]
		if g["mm"] == null:
			continue
		var xs: Array = g["xforms"]
		for i in range(xs.size()):
			var o: Vector3 = xs[i].origin
			if o.y < -100.0:
				continue
			var k = Vector2i(floori(o.x / 6.0), floori(o.z / 6.0))
			if not grid.has(k):
				continue
			for b in grid[k]:
				if absf(o.x - b["x"]) < b["w"] / 2.0 + 0.7 and absf(o.z - b["z"]) < b["d"] / 2.0 + 0.7:
					var rel = o.y - b["gy"]
					if rel > 2.3:
						b["upper"].append([g, i, rel])
					break

# want: building index -> height above its ground where the cut is made
func set_cut(want: Dictionary) -> void:
	var zero = Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0, -500, 0))
	for bi in cut_now.keys():
		if not want.has(bi) or absf(want[bi] - cut_now[bi]) > 0.1:
			for e in buildings[bi].get("upper", []):
				e[0]["mm"].set_instance_transform(e[1], e[0]["xforms"][e[1]])
			cut_now.erase(bi)
	for bi in want:
		if cut_now.has(bi):
			continue
		var cut: float = want[bi]
		for e in buildings[bi].get("upper", []):
			if e[2] > cut:
				e[0]["mm"].set_instance_transform(e[1], zero)
		cut_now[bi] = cut

func building_index(p: Vector3, pad: float = 0.0) -> int:
	for i in range(buildings.size()):
		var b = buildings[i]
		if absf(p.x - b["x"]) < b["w"] / 2.0 + pad and absf(p.z - b["z"]) < b["d"] / 2.0 + pad:
			return i
	return -1

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
	_geo().add_child(b)
	c.body = b
	cols.append(c)
	_insert_grid(c)
	return c

func finalize_static() -> void:
	for key in groups:
		var g = groups[key]
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = BoxMesh.new() if g.get("shape", "") == "" else shape_mesh(g["shape"])
		mm.instance_count = g["xforms"].size()
		for i in range(g["xforms"].size()):
			mm.set_instance_transform(i, g["xforms"][i])
		var mi = MultiMeshInstance3D.new()
		mi.multimesh = mm
		var mat = StandardMaterial3D.new()
		mat.albedo_color = g["color"]
		mat.roughness = 0.95
		_surface(mat, g["color"], g.get("shape", ""))
		var pm = Props.mat_for(g["color"], g.get("shape", ""))
		mi.material_override = pm if pm != null else mat
		if g["no_shadow"]:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_geo().add_child(mi)
		g["mm"] = mm
	_cut_index()

# what a static surface is made of, from its colour: tiled roofs, brick, or weathered plaster and stone
func _surface(mat: StandardMaterial3D, c: Color, shape: String) -> void:
	for rc in ROOFC:
		if _near_col(c, rc, 0.03) or (shape == "prism"):
			Tex.apply(mat, "tiles", 0.28, true, 0.8)
			return
	if c.r > 0.5 and c.g < 0.4 and c.b < 0.35 and c.r - c.g > 0.18:
		Tex.apply(mat, "brick", 0.6, true, 0.8)
		return
	if c.g > c.r + 0.05 and c.g > c.b + 0.05:
		Tex.apply(mat, "plain", 0.3, true, 0.0)      # greenery
		return
	Tex.apply(mat, "plaster", 0.35, true, 0.3)

func _near_col(a: Color, b: Color, tol: float) -> bool:
	return absf(a.r - b.r) < tol and absf(a.g - b.g) < tol and absf(a.b - b.b) < tol

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
	_geo().add_child(m)

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

# like inside_any, but low walls you can vault don't count
func solid_at(x: float, z: float, r: float, y: float) -> bool:
	for c in cell_at(x, z):
		if not blocks_at(c, y) or vaultable(c):
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
	# room above for a body to go over: low walls, and window sills with the lintel well above
	return not inside_at(cx, c.hi.y + 0.6, cz) and not inside_at(cx, c.hi.y + 0.95, cz)

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
	_build_vnav()
	_build_cnav()
	for w in water:
		var ix0 = maxi(0, int((w[0] - NX0) / NCS))
		var ix1 = mini(NW - 1, int((w[1] - NX0) / NCS))
		var iz0 = maxi(0, int((w[2] - NZ0) / NCS))
		var iz1 = mini(NH - 1, int((w[3] - NZ0) / NCS))
		for iz in range(iz0, iz1 + 1, 1):
			for ix in range(ix0, ix1 + 1, 1):
				var px = NX0 + (ix + 0.5) * NCS
				var pz = NZ0 + (iz + 0.5) * NCS
				if in_water(px, pz) and not astar.is_point_solid(Vector2i(ix, iz)):
					astar.set_point_weight_scale(Vector2i(ix, iz), 12.0)

func update_nav_area(x0: float, z0: float, x1: float, z1: float) -> void:
	var a = nav_cell(x0 - 1.0, z0 - 1.0)
	var b = nav_cell(x1 + 1.0, z1 + 1.0)
	for iz in range(a.y, b.y + 1):
		for ix in range(a.x, b.x + 1):
			astar.set_point_solid(Vector2i(ix, iz), false)
			astar.set_point_weight_scale(Vector2i(ix, iz), 1.0)
			nav_vault[iz * NW + ix] = 0
	for c in cols_in_rect(x0 - 2.0, z0 - 2.0, x1 + 2.0, z1 + 2.0):
		_nav_mark(c)
	_vnav_area(x0, z0, x1, z1)
	# water stays slow going
	for iz in range(a.y, b.y + 1):
		for ix in range(a.x, b.x + 1):
			var px = NX0 + (ix + 0.5) * NCS
			var pz = NZ0 + (iz + 0.5) * NCS
			if not water.is_empty() and in_water(px, pz) and not astar.is_point_solid(Vector2i(ix, iz)):
				astar.set_point_weight_scale(Vector2i(ix, iz), 12.0)
	if CW > 0:
		var ca = Vector2i(a.x / CCS, a.y / CCS)
		var cb = Vector2i(mini(b.x / CCS, CW - 1), mini(b.y / CCS, CH - 1))
		for cz in range(maxi(0, ca.y), cb.y + 1):
			for cx in range(maxi(0, ca.x), cb.x + 1):
				_cnav_cell(cx, cz)

# ---------------------------------------------------------------- whole-trip route planning
# Long walks are planned on a coarse 4 m grid first, so a man knows the way round a block or a river
# before he sets off instead of walking a straight line into a dead end. Places where his side keeps
# getting shot or killed cost more on that grid, the open ones most of all, so men go round behind
# buildings, hedges and walls when there's a better way.
const CCS = 8                     # fine cells per coarse cell
var cnav = AStarGrid2D.new()
var CW = 0
var CH = 0
var cbase = PackedFloat32Array()
var cexposed = PackedByteArray()  # 1: no cover anywhere in the cell
var cexp_done = false
var route_stats = {"routes": 0, "detours": 0}

func _build_cnav() -> void:
	CW = maxi(1, int(ceil(float(NW) / CCS)))
	CH = maxi(1, int(ceil(float(NH) / CCS)))
	cnav = AStarGrid2D.new()
	cnav.region = Rect2i(0, 0, CW, CH)
	cnav.cell_size = Vector2(1, 1)
	cnav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	cnav.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	cnav.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	cnav.update()
	cbase = PackedFloat32Array()
	cbase.resize(CW * CH)
	cexposed = PackedByteArray()
	cexposed.resize(CW * CH)
	cexp_done = false
	for cz in range(CH):
		for cx in range(CW):
			_cnav_cell(cx, cz)

func _cnav_cell(cx: int, cz: int) -> void:
	var free = 0
	var tot = 0
	var wet = 0
	for fz in range(cz * CCS, mini(NH, (cz + 1) * CCS), 2):
		for fx in range(cx * CCS, mini(NW, (cx + 1) * CCS), 2):
			tot += 1
			var p = Vector2i(fx, fz)
			if not astar.is_point_solid(p):
				free += 1
				if astar.get_point_weight_scale(p) > 10.0:
					wet += 1
	var c = Vector2i(cx, cz)
	var solid = tot == 0 or free * 8 < tot
	cnav.set_point_solid(c, solid)
	# cluttered cells cost a bit more (the fine path has to weave), water a lot more
	var w = 1.0 + (1.0 - float(free) / maxf(1.0, tot)) * 1.2
	if wet * 2 > free:
		w = 8.0
	cbase[cz * CW + cx] = w
	if not solid:
		cnav.set_point_weight_scale(c, w)

func _cnav_exposure() -> void:
	cexp_done = true
	for cz in range(CH):
		for cx in range(CW):
			var x = NX0 + (cx + 0.5) * CCS * NCS
			var z = NZ0 + (cz + 0.5) * CCS * NCS
			var any = false
			for cp in cover_near(Vector3(x, 0, z), 3.0):
				if absf(cp.p.x - x) < 2.6 and absf(cp.p.z - z) < 2.6:
					any = true
					break
			cexposed[cz * CW + cx] = 0 if any else 1

func ccell(x: float, z: float) -> Vector2i:
	return Vector2i(clampi(int(floor((x - NX0) / (NCS * CCS))), 0, CW - 1), clampi(int(floor((z - NZ0) / (NCS * CCS))), 0, CH - 1))

func cpos(c: Vector2i) -> Vector3:
	var x = NX0 + (c.x + 0.5) * CCS * NCS
	var z = NZ0 + (c.y + 0.5) * CCS * NCS
	return Vector3(x, ground_y(x, z), z)

func _cnear_free(c: Vector2i) -> Vector2i:
	if not cnav.is_point_solid(c):
		return c
	for r in range(1, 4):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var p = Vector2i(c.x + dx, c.y + dz)
				if cnav.is_in_boundsv(p) and not cnav.is_point_solid(p):
					return p
	return Vector2i(-1, -1)

# the way a man of this team should go, as a few waypoints, or [] when there's no better plan
# than walking straight there
func find_route(from: Vector3, to: Vector3, team: int) -> Array:
	if CW <= 0:
		return []
	if not cexp_done:
		_cnav_exposure()
	var s = _cnear_free(ccell(from.x, from.z))
	var t = _cnear_free(ccell(to.x, to.z))
	if s.x < 0 or t.x < 0:
		return []
	# this side's bad places: costlier for the length of this search only
	var touched = {}
	if team >= 0 and team < Tactics.danger.size():
		for d in Tactics.danger[team]:
			var age = G.sim_time - d["t"]
			if age > Tactics.DANGER_LIFE:
				continue
			var fade = 1.0 - age / Tactics.DANGER_LIFE
			var dc = ccell(d["p"].x, d["p"].z)
			for dz in range(-3, 4):
				for dx in range(-3, 4):
					var c = Vector2i(dc.x + dx, dc.y + dz)
					if not cnav.is_in_boundsv(c) or cnav.is_point_solid(c):
						continue
					var fall = 1.0 - Vector2(dx, dz).length() / 3.6
					if fall <= 0.0:
						continue
					var i = c.y * CW + c.x
					var add = minf(3.0, d["w"]) * fall * fade * (2.2 if cexposed[i] == 1 else 0.8)
					touched[c] = touched.get(c, 0.0) + add
		for c in touched:
			cnav.set_point_weight_scale(c, cbase[c.y * CW + c.x] + minf(9.0, touched[c]))
	var ids: Array = cnav.get_id_path(s, t, true)
	for c in touched:
		cnav.set_point_weight_scale(c, cbase[c.y * CW + c.x])
	if ids.size() < 2:
		return []
	route_stats["routes"] += 1
	# pull the string tight, but never across a cell costlier than the way we were going
	var out: Array = []
	var i = 0
	var bent = false
	while i < ids.size() - 1:
		var j = mini(ids.size() - 1, i + 14)
		while j > i + 1 and not _cline_ok(ids, i, j, touched):
			j -= 1
		if j < ids.size() - 1:
			bent = true
		out.append(cpos(ids[j]))
		i = j
	if bent and not touched.is_empty():
		route_stats["detours"] += 1
	out[out.size() - 1] = Vector3(to.x, ground_y(to.x, to.z), to.z)
	return out

func _ccost(c: Vector2i, touched: Dictionary) -> float:
	return cbase[c.y * CW + c.x] + touched.get(c, 0.0)

func _cline_ok(ids: Array, i: int, j: int, touched: Dictionary) -> bool:
	var top = 0.0
	for k in range(i, j + 1):
		top = maxf(top, _ccost(ids[k], touched))
	var a: Vector2i = ids[i]
	var d = Vector2(ids[j] - a)
	var n = int(ceil(d.length() * 2.0))
	for k in range(1, n):
		var t = float(k) / n
		var c = Vector2i(roundi(a.x + d.x * t), roundi(a.y + d.y * t))
		if cnav.is_point_solid(c) or _ccost(c, touched) > top + 0.05:
			return false
	return true

# ---------------------------------------------------------------- vehicle navigation
# Two grids: wheels keep to the roads (open ground costs a lot more), tracks hardly care.
var tastar = AStarGrid2D.new()

func _new_vgrid() -> AStarGrid2D:
	var g = AStarGrid2D.new()
	g.region = Rect2i(0, 0, VW, VH)
	g.cell_size = Vector2(1, 1)
	g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	g.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	g.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	g.update()
	return g

func _build_vnav() -> void:
	VW = maxi(1, int(ceil(TW / VCS)))
	VH = maxi(1, int(ceil(TH_ / VCS)))
	vastar = _new_vgrid()
	tastar = _new_vgrid()
	for iz in range(VH):
		for ix in range(VW):
			var r = _vroad(ix, iz)
			vastar.set_point_weight_scale(Vector2i(ix, iz), 1.0 if r else 2.4)
			tastar.set_point_weight_scale(Vector2i(ix, iz), 1.0 if r else 1.15)
	_vnav_slopes()
	for c in cols:
		_vnav_mark(c)
	_vnav_water(0, 0, VW - 1, VH - 1)

# ground too steep to drive up (banks, mounds, ditches): closed to wheels, slow going for tracks
var vsteep = PackedByteArray()

func _vnav_slopes() -> void:
	vsteep = PackedByteArray()
	vsteep.resize(VW * VH)
	for iz in range(VH):
		for ix in range(VW):
			var x = TX0 + (ix + 0.5) * VCS
			var z = TZ0 + (iz + 0.5) * VCS
			var h0 = ground_y(x, z)
			var top = 0.0
			for o in [Vector2(1.6, 0), Vector2(-1.6, 0), Vector2(0, 1.6), Vector2(0, -1.6)]:
				top = maxf(top, absf(ground_y(x + o.x, z + o.y) - h0))
			if top > 0.9:
				vsteep[iz * VW + ix] = 1
				vastar.set_point_solid(Vector2i(ix, iz), true)
				tastar.set_point_weight_scale(Vector2i(ix, iz), 5.0 if top < 1.6 else 50.0)

func _vroad(ix: int, iz: int) -> bool:
	return on_road(TX0 + (ix + 0.5) * VCS, TZ0 + (iz + 0.5) * VCS)

func _vbase_w(ix: int, iz: int, tracked: bool = false) -> float:
	if _vroad(ix, iz):
		return 1.0
	return 1.15 if tracked else 2.4

func vnav_cell(x: float, z: float) -> Vector2i:
	return Vector2i(clampi(int(floor((x - TX0) / VCS)), 0, VW - 1), clampi(int(floor((z - TZ0) / VCS)), 0, VH - 1))

func _vnav_mark(c) -> void:
	if not blocks_move(c) or c.hi.y - c.gy < 0.35:
		return
	# hedges and loose crates don't stop a vehicle, it just goes through them: costlier, not closed
	var soft = c.dest and not c.has_meta("tree") and (c.prop == 2 or c.prop == 1)
	var ix0 = maxi(0, int(floor((c.lo.x - VCLEAR - TX0) / VCS)))
	var ix1 = mini(VW - 1, int(floor((c.hi.x + VCLEAR - TX0) / VCS)))
	var iz0 = maxi(0, int(floor((c.lo.z - VCLEAR - TZ0) / VCS)))
	var iz1 = mini(VH - 1, int(floor((c.hi.z + VCLEAR - TZ0) / VCS)))
	if soft:
		ix0 = maxi(0, int(floor((c.lo.x - TX0) / VCS)))
		ix1 = mini(VW - 1, int(floor((c.hi.x - TX0) / VCS)))
		iz0 = maxi(0, int(floor((c.lo.z - TZ0) / VCS)))
		iz1 = mini(VH - 1, int(floor((c.hi.z - TZ0) / VCS)))
	for iz in range(iz0, iz1 + 1):
		for ix in range(ix0, ix1 + 1):
			var p = Vector2i(ix, iz)
			if soft:
				vastar.set_point_weight_scale(p, 4.0)
				tastar.set_point_weight_scale(p, 3.0)
			else:
				vastar.set_point_solid(p, true)
				tastar.set_point_solid(p, true)

func _vnav_water(ix0: int, iz0: int, ix1: int, iz1: int) -> void:
	if water.is_empty():
		return
	for iz in range(iz0, iz1 + 1):
		for ix in range(ix0, ix1 + 1):
			var x = TX0 + (ix + 0.5) * VCS
			var z = TZ0 + (iz + 0.5) * VCS
			if in_water(x, z):
				vastar.set_point_solid(Vector2i(ix, iz), true)
				tastar.set_point_solid(Vector2i(ix, iz), true)

func _vnav_area(x0: float, z0: float, x1: float, z1: float) -> void:
	if vastar.region.size.x != VW:
		return
	var a = vnav_cell(x0 - VCLEAR - 2.0, z0 - VCLEAR - 2.0)
	var b = vnav_cell(x1 + VCLEAR + 2.0, z1 + VCLEAR + 2.0)
	for iz in range(a.y, b.y + 1):
		for ix in range(a.x, b.x + 1):
			var p = Vector2i(ix, iz)
			vastar.set_point_solid(p, false)
			tastar.set_point_solid(p, false)
			vastar.set_point_weight_scale(p, _vbase_w(ix, iz, false))
			tastar.set_point_weight_scale(p, _vbase_w(ix, iz, true))
			if vsteep.size() == VW * VH and vsteep[iz * VW + ix] == 1:
				vastar.set_point_solid(p, true)
				tastar.set_point_weight_scale(p, 5.0)
	var m = VCLEAR + VCS * 2.0
	for c in cols_in_rect(TX0 + a.x * VCS - m, TZ0 + a.y * VCS - m, TX0 + (b.x + 1) * VCS + m, TZ0 + (b.y + 1) * VCS + m):
		_vnav_mark(c)
	_vnav_water(a.x, a.y, b.x, b.y)

func _vnearest_free(c: Vector2i, g: AStarGrid2D) -> Vector2i:
	if not g.is_point_solid(c):
		return c
	for r in range(1, 7):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dz) != r:
					continue
				var p = Vector2i(c.x + dx, c.y + dz)
				if g.is_in_boundsv(p) and not g.is_point_solid(p):
					return p
	return Vector2i(-1, -1)

func _vwalk_line(a: Vector2i, b: Vector2i, g: AStarGrid2D = null) -> bool:
	if g == null:
		g = vastar
	var d = Vector2(b - a)
	var n = int(ceil(d.length() * 2.0))
	for i in range(1, n + 1):
		var t = float(i) / n
		if g.is_point_solid(Vector2i(roundi(a.x + d.x * t), roundi(a.y + d.y * t))):
			return false
	return true

# can a vehicle drive straight from a to b (nothing built or wrecked in the way)?
func vseg_clear(a: Vector3, b: Vector3) -> bool:
	if vastar.region.size.x != VW:
		return true
	return _vwalk_line(vnav_cell(a.x, a.z), vnav_cell(b.x, b.z), tastar)

# a path a vehicle fits along (clear of walls, wrecks and everything built), or [] if there is none.
# Other vehicles standing still are in the way too, for this search only, so traffic plans round a
# parked truck or a jam instead of driving into it.
func find_vpath(from: Vector3, to: Vector3, tracked: bool = false, me = null) -> Array:
	if vastar.region.size.x != VW:
		return find_path(from, to)
	var g: AStarGrid2D = tastar if tracked else vastar
	var s = _vnearest_free(vnav_cell(from.x, from.z), g)
	var t = _vnearest_free(vnav_cell(to.x, to.z), g)
	if s.x < 0 or t.x < 0:
		return find_path(from, to)
	var shut: Array = []
	if me != null:
		for o in G.vehicles:
			if o == me or (o.dead and o.spec.get("static", false)) or o.spec.get("air", false) or o.spec.get("boat", false) or absf(o.speed) > 0.6:
				continue
			if G.dist2d(o.pos, from) > 140.0 or G.dist2d(o.pos, to) < 8.0 or G.dist2d(o.pos, from) < 4.0:
				continue
			var R = o.spec["len"] * 0.5 + 0.8
			var c0 = vnav_cell(o.pos.x - R, o.pos.z - R)
			var c1 = vnav_cell(o.pos.x + R, o.pos.z + R)
			for iz in range(c0.y, c1.y + 1):
				for ix in range(c0.x, c1.x + 1):
					var p = Vector2i(ix, iz)
					if p != s and p != t and not g.is_point_solid(p):
						g.set_point_solid(p, true)
						shut.append(p)
	var ids: Array = g.get_id_path(s, t, true)
	for p in shut:
		g.set_point_solid(p, false)
	if ids.is_empty():
		return find_path(from, to)
	var out: Array = []
	var i = 0
	while i < ids.size() - 1:
		var j = mini(ids.size() - 1, i + 20)
		while j > i + 1 and not _vwalk_line(ids[i], ids[j], g):
			j -= 1
		var x = TX0 + (ids[j].x + 0.5) * VCS
		var z = TZ0 + (ids[j].y + 0.5) * VCS
		out.append(Vector3(x, ground_y(x, z), z))
		i = j
	if out.is_empty():
		out.append(Vector3(to.x, ground_y(to.x, to.z), to.z))
	elif ids[ids.size() - 1] == vnav_cell(to.x, to.z):
		out[out.size() - 1] = Vector3(to.x, ground_y(to.x, to.z), to.z)
	return out

# a free bay for a vehicle near a place: open ground it fits on, nobody else parked or heading
# there, on the side it comes in from so it can pull out the same way
func park_spot(c: Vector3, v, from: Vector3) -> Vector3:
	var best = null
	var bs = 1e9
	for ring in [7.0, 10.0, 13.0, 17.0]:
		for k in range(12):
			var a = k * TAU / 12.0
			var q = c + Vector3(cos(a), 0, sin(a)) * ring
			if not _bay_free(q, v):
				continue
			var sc = G.dist2d(q, from) + ring * 0.6
			if sc < bs:
				bs = sc
				best = q
		if best != null:
			break
	if best == null:
		return G.main._free_spot(c)
	best = Vector3(best.x, ground_y(best.x, best.z), best.z)
	if v != null:
		v.set_meta("park", best)
	return best

func _bay_free(q: Vector3, v) -> bool:
	var b = bounds
	if q.x < b.position.x + 6.0 or q.x > b.end.x - 6.0 or q.z < b.position.y + 6.0 or q.z > b.end.y - 6.0:
		return false
	if in_water(q.x, q.z) or inside_any(q.x, q.z, 2.4):
		return false
	if vastar.region.size.x == VW:
		var c = vnav_cell(q.x, q.z)
		for dz in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var p = Vector2i(c.x + dx, c.y + dz)
				if not tastar.is_in_boundsv(p) or tastar.is_point_solid(p):
					return false
	for o in G.vehicles:
		if o == v or o.dead or o.spec.get("air", false):
			continue
		if G.dist2d(o.pos, q) < 6.5:
			return false
		if o.has_meta("park") and G.dist2d(o.get_meta("park"), q) < 6.5:
			return false
	return true

# colliders overlapping a rectangle, found through the spatial grid
func cols_in_rect(x0: float, z0: float, x1: float, z1: float) -> Array:
	var out = []
	var seen = {}
	for ix in range(int(floor(x0 / GRID)), int(floor(x1 / GRID)) + 1):
		for iz in range(int(floor(z0 / GRID)), int(floor(z1 / GRID)) + 1):
			for c in grid.get(_gkey(ix, iz), []):
				if seen.has(c):
					continue
				seen[c] = true
				if c.hi.x > x0 and c.lo.x < x1 and c.hi.z > z0 and c.lo.z < z1:
					out.append(c)
	return out

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
const CGRID = 8.0
var cover_grid = {}

func _ckey(x: float, z: float) -> int:
	return int(floor(x / CGRID)) * 4096 + int(floor(z / CGRID))

# cover points within r of a spot, through a spatial grid
func cover_near(p: Vector3, r: float) -> Array:
	var out = []
	for ix in range(int(floor((p.x - r) / CGRID)), int(floor((p.x + r) / CGRID)) + 1):
		for iz in range(int(floor((p.z - r) / CGRID)), int(floor((p.z + r) / CGRID)) + 1):
			out.append_array(cover_grid.get(ix * 4096 + iz, []))
	return out

func add_cp(x: float, z: float, n: Vector3, t: Vector3, type: String, c, y: float = -999.0):
	if x < bounds.position.x or x > bounds.end.x or z < bounds.position.y or z > bounds.end.y:
		return null
	var upper = y != -999.0
	if not upper:
		y = ground_y(x, z)
		if inside_any(x, z, 0.28, y):
			return null
	for o in cover_near(Vector3(x, y, z), 0.7):
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
	var k = _ckey(x, z)
	if not cover_grid.has(k):
		cover_grid[k] = []
	cover_grid[k].append(cp)
	if c != null:
		if not c.has_meta("cps"):
			c.set_meta("cps", [])
		c.get_meta("cps").append(cp)
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
					add_cp(p.x, p.y, f["n"], Vector3(1, 0, 0) if f["ax"] == "x" else Vector3(0, 0, 1), "wall", c)

func _face_pt(f: Dictionary, s: float) -> Vector2:
	if f["ax"] == "x":
		return Vector2(s, f["fixed"])
	return Vector2(f["fixed"], s)

func build_cover() -> void:
	cover = []
	cover_grid = {}
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
var static_cols: Array = []      # the map's own pieces, in build order (campaign damage refers to them by index)
var ruined_at_start = 0

# gone before the battle starts (destroyed in an earlier campaign battle): no debris, dust or collapse
func ruin_col(c) -> void:
	if not c.alive:
		return
	c.alive = false
	cols.erase(c)
	_remove_grid(c)
	if is_instance_valid(c.body):
		c.body.queue_free()
	for mk in c.get_meta("marks", []):
		if is_instance_valid(mk):
			mk.queue_free()
	_drop_resting_on(c)
	var zero = Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0, -500, 0))
	for r in c.vis:
		if r[1] == -2:
			if is_instance_valid(r[0]):
				r[0].queue_free()
			continue
		var g = r[0]
		g["xforms"][r[1]] = zero
		if g["mm"]:
			g["mm"].set_instance_transform(r[1], zero)
	if c.has_meta("bld") and c.lo.y - c.gy < 0.5 and not c.has_meta("furn"):
		c.get_meta("bld")["fallen"] += 1
	# leave some rubble where it stood
	if (c.hi.x - c.lo.x) * (c.hi.z - c.lo.z) > 0.6 and c.lo.y - c.gy < 0.5 and not c.has_meta("furn"):
		var cx = (c.lo.x + c.hi.x) * 0.5
		var cz = (c.lo.z + c.hi.z) * 0.5
		for k in range(2):
			add_box(cx + rnd(-0.6, 0.6), 0.0, cz + rnd(-0.6, 0.6), rnd(0.4, 0.9), rnd(0.2, 0.4), rnd(0.4, 0.9), c.color.darkened(0.2), {"collide": false, "ry": rnd(0, 3)})

var last_dust_ms = 0

# whatever was lying on top of a box that's just gone (a body, rubble, a dropped crate) falls with it,
# instead of hanging in the air where the box used to be
func roof_under(p: Vector3):
	for c in roof_cols:
		if c.alive and p.x > c.lo.x - 0.1 and p.x < c.hi.x + 0.1 and p.z > c.lo.z - 0.1 and p.z < c.hi.z + 0.1 and p.y > c.hi.y - 0.4 and p.y < c.hi.y + 1.0:
			return c
	return null

func _drop_resting_on(c) -> void:
	var lo: Vector3 = c.lo - Vector3(0.5, 0.3, 0.5)
	var hi: Vector3 = c.hi + Vector3(0.5, 2.5, 0.5)
	var inside = func(p: Vector3) -> bool:
		return p.x > lo.x and p.x < hi.x and p.z > lo.z and p.z < hi.z and p.y > lo.y and p.y < hi.y
	for s in G.soldiers:
		if s.state == "dead" and not s.parts.is_empty() and inside.call(s.parts[0].global_position):
			s.unsettle()
			for b in s.parts:
				b.sleeping = false
	for d in G.fx.debris_list:
		var b = d["b"]
		if is_instance_valid(b) and inside.call(b.global_position):
			d["still"] = false
			d["age"] = 0.0
			b.freeze = false
			b.sleeping = false
			b.collision_mask = G.L_WORLD | G.L_DEBRIS

func destroy_col(c, depth: int = 0) -> void:
	if not c.alive:
		return
	c.alive = false
	cols.erase(c)
	_remove_grid(c)
	if depth < 3:
		_collapse_check(c)
	if is_instance_valid(c.body):
		c.body.queue_free()
	var zero = Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0, -500, 0))
	for r in c.vis:
		if r[1] == -2:
			if is_instance_valid(r[0]):
				r[0].queue_free()
			continue
		var g = r[0]
		g["xforms"][r[1]] = zero
		if g["mm"]:
			g["mm"].set_instance_transform(r[1], zero)
	if c.has_meta("tree"):
		_tree_down(c)
	_ladder_check(c)
	var size: Vector3 = c.hi - c.lo
	if (c.has_meta("furn") and c.prop == 1) or c.has_meta("fence"):
		_splinter(c)
	if c.has_meta("roof"):
		_roof_cave(c)
	if c.has_meta("boom"):
		_drum_blow(c)
	var n = clampi(roundi(size.x * size.y * size.z * 3.0), 4, 14)
	for i in range(n):
		var p = Vector3(randf_range(c.lo.x, c.hi.x), randf_range(c.lo.y, c.hi.y), randf_range(c.lo.z, c.hi.z))
		G.fx.debris(p, Vector3(randf_range(-3, 3), randf_range(1, 5), randf_range(-3, 3)), randf_range(0.15, 0.5), c.color)
	G.fx.dust_cloud((c.lo + c.hi) / 2.0, maxf(size.x, size.z))
	# a real wall (not a crate, hedge or sandbag) throws up a cloud you can't see through
	if not c.has_meta("tree") and c.prop == 0 and size.y > 0.8 and maxf(size.x, size.z) * size.y > 2.4 and c.hi.y - c.gy > 1.4 and Time.get_ticks_msec() - last_dust_ms > 700 and G.started:
		last_dust_ms = Time.get_ticks_msec()
		Combat.dust_at((c.lo + c.hi) / 2.0, maxf(size.x, size.z) * size.y / 2.0)
	if c.has_meta("cps"):
		for cp in c.get_meta("cps"):
			if cp.owner_s != null and is_instance_valid(cp.owner_s):
				cp.owner_s.cover = null
				cp.owner_s.in_cover = false
			cover.erase(cp)
			var k = _ckey(cp.p.x, cp.p.z)
			if cover_grid.has(k):
				cover_grid[k].erase(cp)
		c.set_meta("cps", [])
	for s in G.soldiers:
		if G.dist2d(s.parts[0].global_position, (c.lo + c.hi) / 2.0) < 7.0:
			s.wake()
	# anything resting on top falls with it
	if depth < 3:
		for o in cols_in_rect(c.lo.x - 0.1, c.lo.z - 0.1, c.hi.x + 0.1, c.hi.z + 0.1):
			if o.dest and o.alive and o.lo.y >= c.hi.y - 0.4 and o.lo.y <= c.hi.y + 0.4 and o.hi.x > c.lo.x and o.lo.x < c.hi.x and o.hi.z > c.lo.z and o.lo.z < c.hi.z:
				var support = 0
				var big = (o.hi.x - o.lo.x) * (o.hi.z - o.lo.z) > 12.0
				for s2 in cols_in_rect(o.lo.x, o.lo.z, o.hi.x, o.hi.z):
					if s2 != o and s2.hi.y >= o.lo.y - 0.15 and s2.hi.y <= o.lo.y + 0.45 and s2.hi.x > o.lo.x and s2.lo.x < o.hi.x and s2.hi.z > o.lo.z and s2.lo.z < o.hi.z:
						support += 1
				# a floor or roof needs walls on several sides to stay up
				if big and support < 4:
					support = mini(support, 1)
				if support < 2:
					destroy_col(o, depth + 1)
	update_nav_area(c.lo.x, c.lo.z, c.hi.x, c.hi.z)

# wooden furniture smashed: long splinters flying, and broken boards left lying on the floor
func _splinter(c) -> void:
	var mid = (c.lo + c.hi) * 0.5
	var wc: Color = c.color
	for i in range(10):
		var p = Vector3(randf_range(c.lo.x, c.hi.x), randf_range(c.lo.y, c.hi.y), randf_range(c.lo.z, c.hi.z))
		G.fx.debris(p, G.flat(p - mid).normalized() * randf_range(2.0, 5.0) + Vector3(0, randf_range(1.5, 4.5), 0), 0.1, wc,
			Vector3(randf_range(0.03, 0.06), randf_range(0.02, 0.04), randf_range(0.25, 0.7)))
	var y0 = c.lo.y - ground_y(mid.x, mid.z)
	var ext = c.hi - c.lo
	(func():
		build_now(func():
			for k in range(3):
				var px = mid.x + randf_range(-ext.x, ext.x) * 0.45
				var pz = mid.z + randf_range(-ext.z, ext.z) * 0.45
				add_box(px, y0 + 0.01 * k, pz, randf_range(0.12, 0.2), 0.04, randf_range(0.5, 1.1), wc.darkened(randf_range(0.05, 0.2)), {"collide": false, "ry": randf_range(0, 3)}))).call_deferred()

# a roof hit hard enough falls in: slabs of tiles and beams crash down into the rooms, the dust boils
# out of the windows, and anyone upstairs under it is hurt
func _roof_cave(c) -> void:
	var mid = (c.lo + c.hi) * 0.5
	var col: Color = c.color
	for i in range(8):
		var p = Vector3(randf_range(c.lo.x, c.hi.x), c.hi.y + 0.2, randf_range(c.lo.z, c.hi.z))
		G.fx.debris(p, Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.5), randf_range(-1.0, 1.0)), 0.5, col,
			Vector3(randf_range(0.6, 1.3), 0.08, randf_range(0.5, 1.1)))
	for i in range(4):
		var p2 = Vector3(randf_range(c.lo.x, c.hi.x), c.lo.y, randf_range(c.lo.z, c.hi.z))
		G.fx.debris(p2, Vector3(0, -1.0, 0), 0.5, Color(0.35, 0.27, 0.19), Vector3(0.12, 0.12, randf_range(1.2, 2.2)))
	G.fx.dust_cloud(Vector3(mid.x, c.gy + 1.5, mid.z), maxf(c.hi.x - c.lo.x, c.hi.z - c.lo.z))
	if G.started:
		Combat.dust_at(Vector3(mid.x, c.gy + 1.0, mid.z), maxf(c.hi.x - c.lo.x, c.hi.z - c.lo.z) * 0.9)
	for sd in G.soldiers:
		if sd.state != "dead" and sd.vehicle == null and sd.pos.x > c.lo.x and sd.pos.x < c.hi.x and sd.pos.z > c.lo.z and sd.pos.z < c.hi.z \
				and sd.pos.y > c.gy + 1.5 and sd.pos.y < c.hi.y:
			sd.hp -= 40.0
			if sd.hp <= 0.0:
				Combat.kill(sd, null, false)
			else:
				sd.fall(1.5)

# fuel drums: shoot them or blow them up and they go off a moment later, setting off whatever's next to them
func fuel_drums(x: float, z: float, n: int) -> void:
	# their own dice, so adding them doesn't reshuffle the rest of the map
	var dr = RandomNumberGenerator.new()
	dr.seed = hash(Vector2i(int(x * 10.0), int(z * 10.0)))
	for i in range(n):
		var a = dr.randf() * TAU
		var r = 0.0 if i == 0 else dr.randf_range(0.6, 1.1)
		var dx = x + cos(a) * r
		var dz = z + sin(a) * r
		if inside_any(dx, dz, 0.4) or on_road(dx, dz):
			continue
		var tone = Color(0.55, 0.15, 0.1) if dr.randf() < 0.5 else Color(0.28, 0.32, 0.2)
		var dc = add_col(dx, ground_y(dx, dz), dz, 0.58, 0.9, 0.58, 1)
		piece_start()
		add_box(dx, 0.0, dz, 0.58, 0.9, 0.58, tone, {"collide": false, "shape": "cyl"})
		for yy in [0.28, 0.6]:
			add_box(dx, yy, dz, 0.61, 0.04, 0.61, tone.darkened(0.3), {"collide": false, "shape": "cyl"})
		add_box(dx + 0.15, 0.9, dz, 0.08, 0.03, 0.08, Color(0.2, 0.2, 0.2), {"collide": false, "shape": "cyl"})
		piece_end(dc, tone, 35.0)
		dc.set_meta("boom", 0.75)

func _drum_blow(c) -> void:
	var p = (c.lo + c.hi) * 0.5
	var pw: float = c.get_meta("boom")
	var t = G.main.get_tree().create_timer(randf_range(0.15, 0.6), false)
	t.timeout.connect(func():
		if not G.started:
			return
		Combat.explode(p, null, pw)
		for k in range(6):
			G.fx.flame_puff(p + Vector3(randf_range(-0.6, 0.6), randf_range(0.0, 1.2), randf_range(-0.6, 0.6)), Vector3(randf_range(-2, 2), randf_range(3, 7), randf_range(-2, 2)), 1.3))

# a blast nearby shoves furniture over: a wardrobe or dresser goes down on its side, a table goes up on its edge
func knock_over(c, dir: Vector3) -> void:
	if not c.alive or not c.has_meta("tip") or c.has_meta("tipped"):
		return
	for t in tables:
		if t["c"] == c:
			flip_table(t, -dir)
			return
	var size: Vector3 = c.hi - c.lo
	var mid = (c.lo + c.hi) * 0.5
	var col: Color = c.color
	var hp = c.hp
	var y0 = c.lo.y - ground_y(mid.x, mid.z)
	ruin_col(c)
	var along_x = absf(dir.x) >= absf(dir.z)
	var sg = signf(dir.x if along_x else dir.z)
	var nx = size.y if along_x else size.x
	var nz = size.z if along_x else size.y
	var ny = size.x if along_x else size.z
	var cx = mid.x + (sg * (size.y * 0.5) if along_x else 0.0)
	var cz = mid.z + (0.0 if along_x else sg * (size.y * 0.5))
	build_now(func():
		add_box(cx, y0, cz, nx, ny, nz, col, {"dest": true, "hp": hp, "mat": 1})
		if not cols.is_empty():
			cols[cols.size() - 1].set_meta("furn", true)
			cols[cols.size() - 1].set_meta("tipped", true))
	update_nav_area(mid.x - 2.0, mid.z - 2.0, mid.x + 2.0, mid.z + 2.0)
	G.audio.kick(mid)

var wall_marks: Array = []

func wall_mark(c, cp: Vector3, from: Vector3, hole: bool) -> void:
	if G.fx == null or G.fx.scorch_tex == null:
		return
	# which face of the box the blast came at
	var ctr = (c.lo + c.hi) * 0.5
	var ext = (c.hi - c.lo) * 0.5
	var rel = from - ctr
	var n: Vector3
	if absf(rel.x) / maxf(ext.x, 0.05) > absf(rel.z) / maxf(ext.z, 0.05):
		n = Vector3(signf(rel.x), 0, 0)
	else:
		n = Vector3(0, 0, signf(rel.z))
	var on_face = cp
	on_face.y = clampf(from.y, c.lo.y + 0.5, c.hi.y - 0.4)
	var faces = [n]
	if hole:
		faces.append(-n)      # right through: it shows on the far side too
	for fn in faces:
		var p = on_face
		if fn.x != 0.0:
			p.x = (c.hi.x if fn.x > 0 else c.lo.x) + fn.x * 0.02
		else:
			p.z = (c.hi.z if fn.z > 0 else c.lo.z) + fn.z * 0.02
		var q = MeshInstance3D.new()
		var qm = QuadMesh.new()
		var sz = randf_range(0.9, 1.3) if hole else randf_range(1.1, 1.8)
		qm.size = Vector2(sz, sz * randf_range(0.7, 1.0))
		q.mesh = qm
		var mt = StandardMaterial3D.new()
		mt.albedo_texture = G.fx.scorch_tex
		mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mt.albedo_color = Color(0.05, 0.04, 0.04, 1.0) if hole else Color(0.25, 0.22, 0.2, 0.85)
		mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if hole else BaseMaterial3D.SHADING_MODE_PER_PIXEL
		q.material_override = mt
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(q)
		q.global_position = p
		q.look_at(p + fn, Vector3.UP if absf(fn.y) < 0.9 else Vector3.RIGHT)
		q.rotate_object_local(Vector3(0, 1, 0), PI)
		q.rotate_object_local(Vector3(0, 0, 1), randf() * TAU)
		var marks: Array = c.get_meta("marks", [])
		marks.append(q)
		c.set_meta("marks", marks)
		wall_marks.append(q)
	if hole:
		for k in range(5):
			G.fx.debris(on_face + n * 0.4 + Vector3(0, randf_range(-0.3, 0.3), 0), n * randf_range(1.5, 3.5) + Vector3(randf_range(-1, 1), randf_range(0.5, 2.0), randf_range(-1, 1)), 0.18, c.color)
	while wall_marks.size() > 160:
		var old = wall_marks.pop_front()
		if is_instance_valid(old):
			old.queue_free()

func damage_area(pos: Vector3, R: float, power: float) -> void:
	# in commander mode the HQ is dug in too deep for shells: it has to be taken on the ground
	var hq_safe = Combat.arty and G.mode == "commander"
	for c in cols_in_rect(pos.x - R, pos.z - R, pos.x + R, pos.z + R):
		if not c.dest or not c.alive:
			continue
		if hq_safe and c.has_meta("hq"):
			continue
		var cp = Vector3(clampf(pos.x, c.lo.x, c.hi.x), clampf(pos.y, c.lo.y, c.hi.y), clampf(pos.z, c.lo.z, c.hi.z))
		var d = pos.distance_to(cp)
		if d < R:
			var hp0 = c.hp
			c.hp -= 260.0 * power * (1.0 - d / R)
			if c.hp <= 0.0:
				destroy_col(c)
			elif c.lo.y - c.gy < 0.5 and c.hi.y - c.lo.y > 1.2 and not c.has_meta("furn") and not c.has_meta("tip"):
				# a wall that's still standing shows it: a scorch where it was hit, and once it's badly hurt
				# a hole punched through, with chunks knocked off at its foot
				wall_mark(c, cp, pos, c.hp < 55.0 and hp0 >= 55.0)
			elif c.has_meta("tip") and d < R * 0.85:
				var push = G.flat(cp - pos)
				knock_over(c, push.normalized() if push.length_squared() > 0.01 else Vector3(randf() - 0.5, 0, randf() - 0.5).normalized())

# ---------------------------------------------------------------- map pieces
func wall_run(horiz: bool, fixed: float, a0: float, a1: float, h: float, color: Color, th_: float, intact: bool = false, door_at: float = -1.0) -> void:
	var L = a1 - a0
	var s = 0.0
	var i = 0
	var made_door = false
	while s < L - 0.05:
		var seg = minf(L - s, rnd(1.5, 3.0) if not intact else 2.0)
		if intact and L - s - seg < 1.0:
			seg = L - s
		var ruined = rng.randf() < 0.35 and not intact
		var ph = h * rnd(0.25, 0.75) if ruined else (h * rnd(0.85, 1.0) if not intact else h)
		var can_open = seg > 1.4 and s > 0.6 and (L - s - seg) > 0.6
		var r = rng.randf()
		var c = a0 + s + seg / 2.0
		if intact and can_open:
			r = 0.1 if (door_at >= 0.0 and not made_door and absf(c - (a0 + door_at)) < seg * 0.6) else (0.4 if i % 2 == 1 else 0.9)
			if r < 0.2:
				made_door = true
		elif can_open and door_at >= 0.0 and not made_door and absf(c - (a0 + door_at)) < seg * 0.75:
			# a ruin still always has a way in on its door side
			r = 0.1
			made_door = true
		if can_open and r < 0.24:
			if ph > 2.6:
				_wall_piece(horiz, fixed, c, seg, 2.4, ph - 2.4, color, th_, "lintel")
			if cols.size() > 0:
				var dcol = cols[cols.size() - 1]
				piece_start()
				_door_frame(horiz, fixed, c, minf(seg, 1.6), color, th_)
				dcol.vis.append_array(piece)
				piece = null
				if intact and edit_node == null and not dyn_mode:
					openings.append({"kind": "door", "horiz": horiz, "fixed": fixed, "c": c, "w": minf(seg, 1.6), "col": dcol, "b": buildings.size() - 1})
		elif can_open and r < 0.55:
			_wall_piece(horiz, fixed, c, seg, 0.0, 1.0, color, th_, "sill")
			if intact and edit_node == null and not dyn_mode:
				openings.append({"kind": "window", "horiz": horiz, "fixed": fixed, "c": c, "w": seg, "y0": 1.0, "y1": minf(2.2, ph), "col": cols[cols.size() - 1], "b": buildings.size() - 1})
			if ph > 2.7:
				_wall_piece(horiz, fixed, c, seg, 2.2, ph - 2.2, color, th_, "lintel")
		else:
			_wall_piece(horiz, fixed, c, seg, 0.0, maxf(ph, 1.1), color, th_, "full" if not ruined else "ruin")
		s += seg
		i += 1

# a wall section, with a plinth, window sill or lintel and a string course that come down with it
func _wall_piece(horiz: bool, fixed: float, c: float, ln: float, y0: float, h: float, color: Color, th_: float, kind: String = "full") -> void:
	if horiz:
		add_box(c, y0, fixed, ln, h, th_, color, {"dest": true, "hp": 200.0})
	else:
		add_box(fixed, y0, c, th_, h, ln, color, {"dest": true, "hp": 200.0})
	var col = cols[cols.size() - 1] if edit_node == null and not cols.is_empty() else null
	piece_start()
	var trim = color.lightened(0.2)
	var dark = color.darkened(0.28)
	if y0 < 0.05:
		_trim(horiz, fixed, c, ln, 0.0, 0.42, th_ + 0.1, dark)
	if kind == "sill":
		_trim(horiz, fixed, c, ln + 0.1, y0 + h - 0.02, 0.1, th_ + 0.22, trim)
	elif kind == "lintel":
		_trim(horiz, fixed, c, ln, y0, 0.2, th_ + 0.08, trim)
	if y0 < 3.2 and y0 + h > 3.5 and kind != "ruin":
		_trim(horiz, fixed, c, ln, 3.2, 0.16, th_ + 0.1, trim)
	if kind == "full" and h > 2.0:
		_trim(horiz, fixed, c, ln, y0 + h - 0.18, 0.18, th_ + 0.14, trim)
	piece_end(col, color, 200.0)

func _trim(horiz: bool, fixed: float, c: float, ln: float, y0: float, h: float, th_: float, color: Color) -> void:
	if horiz:
		add_box(c, y0, fixed, ln, h, th_, color, {"collide": false})
	else:
		add_box(fixed, y0, c, th_, h, ln, color, {"collide": false})

func _door_frame(horiz: bool, fixed: float, c: float, w: float, color: Color, th_: float) -> void:
	var fc = Color(0.36, 0.27, 0.18)
	for e in [-1.0, 1.0]:
		if horiz:
			add_box(c + e * (w / 2.0 - 0.06), 0.0, fixed, 0.12, 2.4, th_ + 0.12, fc, {"collide": false})
		else:
			add_box(fixed, 0.0, c + e * (w / 2.0 - 0.06), th_ + 0.12, 2.4, 0.12, fc, {"collide": false})
	# a step
	if horiz:
		add_box(c, 0.0, fixed, w, 0.15, th_ + 0.6, color.darkened(0.3), {"collide": false})
	else:
		add_box(fixed, 0.0, c, th_ + 0.6, 0.15, w, color.darkened(0.3), {"collide": false})

func building(x: float, z: float, w: float, d: float, h: float) -> void:
	var color: Color = WALLC[rng.randi() % WALLC.size()]
	var t = 0.35
	var bld = {"x": x, "z": z, "w": w, "d": d, "h": h, "cols": [], "walls0": 0, "fallen": 0}
	buildings.append(bld)
	var c0 = cols.size()
	var ds = rng.randi() % 4
	wall_run(true, z - d / 2.0, x - w / 2.0, x + w / 2.0, h, color, t, false, w / 2.0 if ds == 0 else -1.0)
	wall_run(true, z + d / 2.0, x - w / 2.0, x + w / 2.0, h, color, t, false, w / 2.0 if ds == 1 else -1.0)
	wall_run(false, x - w / 2.0, z - d / 2.0 + t / 2.0, z + d / 2.0 - t / 2.0, h, color, t, false, d / 2.0 if ds == 2 else -1.0)
	wall_run(false, x + w / 2.0, z - d / 2.0 + t / 2.0, z + d / 2.0 - t / 2.0, h, color, t, false, d / 2.0 if ds == 3 else -1.0)
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
	_claim(bld, c0)

const ROOFC = [Color(0.5, 0.25, 0.2), Color(0.36, 0.3, 0.27), Color(0.42, 0.22, 0.17), Color(0.33, 0.34, 0.36)]

# an intact house: regular windows and a door, a pitched tiled roof and a chimney
func house(x: float, z: float, w: float, d: float, h: float = 3.4) -> void:
	# the big ones are farmhouses with two rooms and a porch
	if w >= 11.5 and d >= 8.5 and rng.randf() < 0.7 and edit_node == null:
		big_house(x, z, w, d)
		return
	# bigger houses get an upstairs
	if w >= 8.5 and d >= 7.0 and rng.randf() < 0.45 and edit_node == null:
		var c0u = cols.size()
		_tower(x, z, w, d)
		_pitched_roof(x, z, w, d, 6.6, ROOFC[rng.randi() % ROOFC.size()], true)
		var T = towers[towers.size() - 1]
		_furnish(x, z, w, d, 0.0, z - d / 2.0 + 2.2)
		for fr in T["floor_rects"]:
			if fr[1] - fr[0] > 3.0 and fr[3] - fr[2] > 2.5:
				_furnish((fr[0] + fr[1]) / 2.0, (fr[2] + fr[3]) / 2.0, fr[1] - fr[0], fr[3] - fr[2], T["floor_y"], -1e9, true)
				break
		var bldu = {"x": x, "z": z, "w": w, "d": d, "h": 8.6, "cols": [], "walls0": 0, "fallen": 0}
		_claim(bldu, c0u)
		return
	# some have a flat roof you can get up onto by a ladder on the outside
	if w <= 10.0 and d <= 9.0 and rng.randf() < 0.35 and edit_node == null:
		flat_house(x, z, w, d, h)
		return
	var color: Color = WALLC[rng.randi() % WALLC.size()]
	var t = 0.35
	var bld = {"x": x, "z": z, "w": w, "d": d, "h": h + 1.8, "cols": [], "walls0": 0, "fallen": 0}
	buildings.append(bld)
	var c0 = cols.size()
	var door_side = rng.randi() % 4
	wall_run(true, z - d / 2.0, x - w / 2.0, x + w / 2.0, h, color, t, true, w / 2.0 if door_side == 0 else -1.0)
	wall_run(true, z + d / 2.0, x - w / 2.0, x + w / 2.0, h, color, t, true, w / 2.0 if door_side == 1 else -1.0)
	wall_run(false, x - w / 2.0, z - d / 2.0 + t / 2.0, z + d / 2.0 - t / 2.0, h, color, t, true, d / 2.0 if door_side == 2 else -1.0)
	wall_run(false, x + w / 2.0, z - d / 2.0 + t / 2.0, z + d / 2.0 - t / 2.0, h, color, t, true, d / 2.0 if door_side == 3 else -1.0)
	flat_plane(x, z, w - 0.4, d - 0.4, Color(0.44, 0.42, 0.38), 0.02)
	_pitched_roof(x, z, w, d, h, ROOFC[rng.randi() % ROOFC.size()], true)
	_furnish(x, z, w, d, 0.0)
	_claim(bld, c0)

# a single storey with a flat roof and a parapet; a ladder against one wall goes up to the roof
func flat_house(x: float, z: float, w: float, d: float, h: float = 3.3) -> void:
	var color: Color = WALLC[rng.randi() % WALLC.size()].lerp(Color(0.8, 0.76, 0.66), 0.25)
	var t = 0.35
	var bld = {"x": x, "z": z, "w": w, "d": d, "h": h + 1.0, "cols": [], "walls0": 0, "fallen": 0}
	buildings.append(bld)
	var c0 = cols.size()
	var door_side = rng.randi() % 4
	var ladder_side = (door_side + 1 + rng.randi() % 3) % 4
	wall_run(true, z - d / 2.0, x - w / 2.0, x + w / 2.0, h, color, t, true, w / 2.0 if door_side == 0 else -1.0)
	wall_run(true, z + d / 2.0, x - w / 2.0, x + w / 2.0, h, color, t, true, w / 2.0 if door_side == 1 else -1.0)
	wall_run(false, x - w / 2.0, z - d / 2.0 + t / 2.0, z + d / 2.0 - t / 2.0, h, color, t, true, d / 2.0 if door_side == 2 else -1.0)
	wall_run(false, x + w / 2.0, z - d / 2.0 + t / 2.0, z + d / 2.0 - t / 2.0, h, color, t, true, d / 2.0 if door_side == 3 else -1.0)
	flat_plane(x, z, w - 0.4, d - 0.4, Color(0.44, 0.42, 0.38), 0.02)
	# the roof slab, with a parapet round it (a gap where the ladder comes up)
	var rh = h + 0.25
	var roofc = Color(0.5, 0.48, 0.45)
	add_box(x, h, z, w + 0.2, 0.25, d + 0.2, roofc, {"dest": true, "hp": 260.0})
	var pc = color.darkened(0.08)
	var lad_n = [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0)][ladder_side]
	# the ladder sits a third of the way along its wall
	var along = Vector3(1, 0, 0) if ladder_side < 2 else Vector3(0, 0, 1)
	var half = (w if ladder_side < 2 else d) / 2.0
	var off = half * 0.4 * (1.0 if rng.randf() < 0.5 else -1.0)
	var wall_c = Vector3(x, 0, z) + lad_n * ((d if ladder_side < 2 else w) / 2.0) + along * off
	for side in range(4):
		var n = [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0)][side]
		var horiz = side < 2
		var L = w + 0.2 if horiz else d + 0.2
		var cx = x + n.x * (w / 2.0)
		var cz = z + n.z * (d / 2.0)
		if side == ladder_side:
			# two stretches either side of a 1 m gap
			var g0 = off - 0.55
			var g1 = off + 0.55
			for seg in [[-L / 2.0, g0], [g1, L / 2.0]]:
				var sl = seg[1] - seg[0]
				if sl < 0.2:
					continue
				var mid = (seg[0] + seg[1]) / 2.0
				if horiz:
					add_box(x + mid, rh, cz, sl, 0.6, 0.22, pc, {"dest": true, "hp": 120.0})
				else:
					add_box(cx, rh, z + mid, 0.22, 0.6, sl, pc, {"dest": true, "hp": 120.0})
		elif horiz:
			add_box(x, rh, cz, L, 0.6, 0.22, pc, {"dest": true, "hp": 120.0})
		else:
			add_box(cx, rh, z, 0.22, 0.6, L, pc, {"dest": true, "hp": 120.0})
	# the ladder: two rails and rungs, leaning against the wall
	var base = wall_c + lad_n * 0.75
	var gy = ground_y(base.x, base.z)
	var top_y = ground_y(x, z) + rh
	var ladc = Color(0.4, 0.3, 0.2)
	var rl = top_y + 0.9 - gy
	var lrefs = []
	for e in [-0.25, 0.25]:
		var rp = wall_c + lad_n * 0.42 + along * e
		lrefs.append(add_box(rp.x, 0.0, rp.z, 0.07, rl, 0.07, ladc, {"collide": false}))
	var nr = int(rl / 0.3)
	for k in range(1, nr):
		var ry = k * 0.3
		var rp2 = wall_c + lad_n * 0.42
		if ladder_side < 2:
			lrefs.append(add_box(rp2.x, ry, rp2.z, 0.5, 0.04, 0.05, ladc.darkened(0.1), {"collide": false}))
		else:
			lrefs.append(add_box(rp2.x, ry, rp2.z, 0.05, 0.04, 0.5, ladc.darkened(0.1), {"collide": false}))
	var T = {"x": x, "z": z, "w": w, "d": d, "floor_y": top_y, "posts": [], "cps": [], "rect": [x - w / 2.0 - 1.2, x + w / 2.0 + 1.2, z - d / 2.0 - 1.2, z + d / 2.0 + 1.2], "ladder": true, "n": lad_n,
		"stair_bottom": Vector3(base.x, gy, base.z), "stair_top": Vector3(wall_c.x, top_y, wall_c.z) - lad_n * 0.9, "lad_x": Vector3(wall_c.x, 0, wall_c.z) + lad_n * 0.42}
	T["inside"] = T["stair_bottom"] + lad_n * 1.5
	T["lad_refs"] = lrefs
	T["lad_base"] = Vector3(wall_c.x, gy, wall_c.z) + lad_n * 0.42
	T["lad_len"] = rl
	T["lad_pts"] = [Vector3(wall_c.x, gy + rl * 0.35, wall_c.z), Vector3(wall_c.x, top_y - 0.6, wall_c.z), Vector3(wall_c.x, top_y - 0.1, wall_c.z)]
	# firing spots along the parapet, facing out
	for side in range(4):
		var n2 = [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0)][side]
		var L2 = w if side < 2 else d
		var al2 = Vector3(1, 0, 0) if side < 2 else Vector3(0, 0, 1)
		for k in [-0.3, 0.3]:
			var pp = Vector3(x, 0, z) + n2 * ((d if side < 2 else w) / 2.0 - 0.55) + al2 * L2 * k
			if side == ladder_side and absf(L2 * k - off) < 1.2:
				continue
			T["posts"].append([pp.x, pp.z, n2.x, n2.z])
	towers.append(T)
	_furnish(x, z, w, d, 0.0)
	_claim(bld, c0)

# ---------------------------------------------------------------- furniture
# tables (which soldiers flip over for cover), chairs, a bed, a wardrobe, a stove and a rug.
# y0 is the floor height; keep_south is a z below which nothing goes (the stairs)
var tables: Array = []          # {"c": WCol, "p": Vector3, "y": floor height, "flipped": bool}
const WOOD = Color(0.45, 0.32, 0.2)

func _furnish(x: float, z: float, w: float, d: float, y0: float, keep_south: float = -1e9, upper: bool = false) -> void:
	var hw = w / 2.0 - 0.9
	var hd = d / 2.0 - 0.9
	if hw < 0.8 or hd < 0.8:
		return
	var placed = []
	var free = func(px: float, pz: float, r: float) -> bool:
		if pz - r < keep_south:
			return false
		for q in placed:
			if absf(q.x - px) < r + q.y and absf(q.z - pz) < r + q.y:
				return false
		return upper or not inside_any(px, pz, r * 0.6, ground_y(px, pz) + y0)
	# a rug in the middle
	if not upper:
		flat_plane(x + rnd(-0.5, 0.5), z + rnd(-0.5, 0.5), minf(2.6, w - 2.0), minf(1.8, d - 2.0), [Color(0.45, 0.2, 0.16), Color(0.25, 0.3, 0.4), Color(0.42, 0.36, 0.22)][rng.randi() % 3], 0.035)
	# the table and its chairs
	for k in range(8):
		var tx = x + rnd(-hw + 0.6, hw - 0.6)
		var tz = z + rnd(-hd + 0.6, hd - 0.6)
		if free.call(tx, tz, 1.1):
			var along_x = rng.randf() < 0.5
			var tw = 1.5 if along_x else 0.85
			var td = 0.85 if along_x else 1.5
			var refs = [add_box(tx, y0 + 0.68, tz, tw, 0.08, td, WOOD, {"collide": false})]
			for ex in [-1.0, 1.0]:
				for ez in [-1.0, 1.0]:
					refs.append(add_box(tx + ex * (tw / 2.0 - 0.08), y0, tz + ez * (td / 2.0 - 0.08), 0.08, 0.68, 0.08, WOOD.darkened(0.2), {"collide": false}))
			if edit_node == null:
				var col = add_col(tx, ground_y(tx, tz) + y0, tz, tw, 0.76, td, 1)
				col.dest = true
				col.hp = 60.0
				col.color = WOOD
				col.vis = refs
				col.set_meta("furn", true)
				col.set_meta("tip", true)
				tables.append({"c": col, "p": Vector3(tx, ground_y(tx, tz) + y0, tz), "y": y0, "flipped": false})
			placed.append(Vector3(tx, 0, tz) + Vector3(0, 1.1, 0))
			for e in [-1.0, 1.0]:
				var cx = tx + (e * (tw / 2.0 + 0.35) if along_x else 0.0)
				var cz = tz + (0.0 if along_x else e * (td / 2.0 + 0.35))
				add_box(cx, y0, cz, 0.42, 0.45, 0.42, WOOD.lightened(0.08), {"collide": false})
				add_box(cx + (e * 0.19 if along_x else 0.0), y0 + 0.45, cz + (0.0 if along_x else e * 0.19), 0.06 if along_x else 0.42, 0.45, 0.42 if along_x else 0.06, WOOD.lightened(0.08), {"collide": false})
			break
	# against the walls: a bed, a wardrobe, a stove or a dresser
	var kinds = ["bed", "wardrobe", "stove", "dresser", "shelf"]
	for i in range(kinds.size() - 1, 0, -1):
		var j = rng.randi() % (i + 1)
		var tmp = kinds[i]
		kinds[i] = kinds[j]
		kinds[j] = tmp
	var n = 2 if not upper else 1
	for kind in kinds.slice(0, n + 1):
		for k in range(10):
			var side = rng.randi() % 4
			var px = x + (rnd(-hw, hw) if side < 2 else (-hw if side == 2 else hw))
			var pz = z + ((-hd if side == 0 else hd) if side < 2 else rnd(-hd, hd))
			var r = 1.0 if kind == "bed" else 0.6
			if not free.call(px, pz, r):
				continue
			match kind:
				"bed":
					var bx = 1.9 if side < 2 else 0.95
					var bz = 0.95 if side < 2 else 1.9
					add_box(px, y0, pz, bx, 0.45, bz, Color(0.35, 0.26, 0.18), {"dest": true, "hp": 80.0, "mat": 1})
					add_box(px, y0 + 0.45, pz, bx - 0.1, 0.12, bz - 0.1, Color(0.78, 0.76, 0.7), {"collide": false})
				"wardrobe":
					add_box(px, y0, pz, 0.9 if side < 2 else 0.5, 1.9, 0.5 if side < 2 else 0.9, WOOD.darkened(0.12), {"dest": true, "hp": 90.0, "mat": 1})
				"stove":
					add_box(px, y0, pz, 0.7, 0.85, 0.6, Color(0.2, 0.2, 0.21), {"dest": true, "hp": 200.0})
					add_box(px, y0 + 0.85, pz, 0.14, 1.4, 0.14, Color(0.15, 0.15, 0.15), {"collide": false})
				"dresser":
					add_box(px, y0, pz, 1.1 if side < 2 else 0.5, 0.85, 0.5 if side < 2 else 1.1, WOOD.lightened(0.05), {"dest": true, "hp": 70.0, "mat": 1})
				"shelf":
					# a tall shelf unit against the wall, its boards lined with books, jars and boxes
					var sw = 1.3 if side < 2 else 0.38
					var sd = 0.38 if side < 2 else 1.3
					add_box(px, y0, pz, sw, 1.9, sd, WOOD.darkened(0.25), {"dest": true, "hp": 60.0, "mat": 1})
					var sc = cols[cols.size() - 1] if edit_node == null and not cols.is_empty() else null
					var inn = [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)][side]
					piece_start()
					var bookc = [Color(0.5, 0.16, 0.12), Color(0.18, 0.25, 0.4), Color(0.25, 0.35, 0.2), Color(0.6, 0.52, 0.32), Color(0.75, 0.72, 0.62)]
					for sy in [0.12, 0.6, 1.08, 1.5]:
						var fp = Vector3(px, 0, pz) + inn * 0.2
						add_box(fp.x, y0 + sy, fp.z, sw + 0.04 if side < 2 else 0.04, 0.04, 0.04 if side < 2 else sd + 0.04, WOOD.darkened(0.1), {"collide": false})
						var nb = rng.randi_range(3, 6)
						for b in range(nb):
							var o = -0.5 + (b + 0.5) / nb
							var bp = Vector3(px, 0, pz) + inn * 0.21 + (Vector3(o * 1.1, 0, 0) if side < 2 else Vector3(0, 0, o * 1.1))
							add_box(bp.x, y0 + sy + 0.04, bp.z, 0.14 if side < 2 else 0.04, rnd(0.2, 0.34), 0.04 if side < 2 else 0.14, bookc[rng.randi() % bookc.size()], {"collide": false})
					if sc != null:
						sc.vis.append_array(piece)
					piece = null
			if edit_node == null and not cols.is_empty():
				cols[cols.size() - 1].set_meta("furn", true)
				if kind in ["wardrobe", "dresser", "shelf"]:
					cols[cols.size() - 1].set_meta("tip", true)
			placed.append(Vector3(px, r, pz))
			break

# a soldier tips a table onto its side between himself and the threat: instant low cover
func flip_table(t: Dictionary, threat_dir: Vector3) -> void:
	if t["flipped"] or not t["c"].alive:
		return
	t["flipped"] = true
	var p: Vector3 = t["p"]
	ruin_col(t["c"])
	update_nav_area(p.x - 1.0, p.z - 1.0, p.x + 1.0, p.z + 1.0)
	var along_x = absf(threat_dir.z) >= absf(threat_dir.x)
	var off = Vector3(0, 0, signf(threat_dir.z)) * 0.4 if along_x else Vector3(signf(threat_dir.x), 0, 0) * 0.4
	var q = p + off
	var yy = t["y"]
	build_now(func():
		add_box(q.x, yy, q.z, 1.5 if along_x else 0.1, 0.85, 0.1 if along_x else 1.5, WOOD, {"dest": true, "hp": 70.0, "mat": 1})
		for e in [-1.0, 1.0]:
			var lp = q - off * 1.6 + (Vector3(e * 0.6, 0, 0) if along_x else Vector3(0, 0, e * 0.6))
			add_box(lp.x, yy + 0.35, lp.z, 0.08 if along_x else 0.6, 0.08, 0.6 if along_x else 0.08, WOOD.darkened(0.2), {"collide": false}))
	G.audio.kick(q)

func table_near(p: Vector3, r: float):
	var best = null
	var bd = r
	for t in tables:
		if not t["flipped"] and t["c"].alive and absf(t["p"].y - p.y) < 1.5:
			var d = G.dist2d(t["p"], p)
			if d < bd:
				bd = d
				best = t
	return best

# a pitched roof over a box of walls; it rests on the walls and falls in when they go
func _pitched_roof(x: float, z: float, w: float, d: float, h: float, rc: Color, chimney: bool, rh: float = -1.0) -> void:
	var gy = ground_y(x, z)
	var along_x = w >= d
	if rh < 0.0:
		rh = minf(w, d) * 0.32 + 0.4
	var ref
	if along_x:
		ref = add_box(x, gy + h, z, w + 0.6, rh, d + 0.7, rc, {"shape": "prism", "ry": PI / 2.0, "abs": true, "collide": false})
	else:
		ref = add_box(x, gy + h, z, w + 0.7, rh, d + 0.6, rc, {"shape": "prism", "abs": true, "collide": false})
	var c = add_col(x, gy + h, z, w, minf(rh, 0.6), d)
	c.set_meta("roof", true)
	roof_cols.append(c)
	c.vis = [ref]
	c.dest = true
	c.hp = 160.0
	c.color = rc
	piece_start()
	# eaves boards and gable ends
	if along_x:
		for e in [-1.0, 1.0]:
			add_box(x, gy + h - 0.1, z + e * (d / 2.0 + 0.3), w + 0.6, 0.12, 0.1, rc.darkened(0.3), {"abs": true, "collide": false})
	else:
		for e in [-1.0, 1.0]:
			add_box(x + e * (w / 2.0 + 0.3), gy + h - 0.1, z, 0.1, 0.12, d + 0.6, rc.darkened(0.3), {"abs": true, "collide": false})
	if chimney:
		var cx = x + (w * 0.25 if along_x else rnd(-0.4, 0.4))
		var cz = z + (rnd(-0.4, 0.4) if along_x else d * 0.25)
		add_box(cx, gy + h, cz, 0.6, rh + 0.7, 0.6, Color(0.5, 0.36, 0.3), {"abs": true, "collide": false})
		add_box(cx, gy + h + rh + 0.7, cz, 0.75, 0.12, 0.75, Color(0.42, 0.32, 0.27), {"abs": true, "collide": false})
	c.vis.append_array(piece)
	piece = null

# bigger buildings: a warehouse, a church with a steeple, or an apartment block
# a big farmhouse: two rooms either side of an inside wall with a doorway through it, a front door under
# a porch roof on posts, a back door, a tall pitched roof, and furniture in both rooms
func big_house(x: float, z: float, w: float, d: float, h: float = 3.7) -> void:
	var color: Color = WALLC[rng.randi() % WALLC.size()]
	var t = 0.35
	var bld = {"x": x, "z": z, "w": w, "d": d, "h": h + 2.6, "cols": [], "walls0": 0, "fallen": 0, "kind": "bighouse"}
	buildings.append(bld)
	var c0 = cols.size()
	var front = -1.0 if rng.randf() < 0.5 else 1.0
	var door_x = w * (0.28 if rng.randf() < 0.5 else 0.72)
	wall_run(true, z + front * d / 2.0, x - w / 2.0, x + w / 2.0, h, color, t, true, door_x)
	wall_run(true, z - front * d / 2.0, x - w / 2.0, x + w / 2.0, h, color, t, true, w - door_x)
	wall_run(false, x - w / 2.0, z - d / 2.0 + t / 2.0, z + d / 2.0 - t / 2.0, h, color, t, true)
	wall_run(false, x + w / 2.0, z - d / 2.0 + t / 2.0, z + d / 2.0 - t / 2.0, h, color, t, true)
	# the inside wall, with a doorway in the middle
	var px = x + (w * 0.08 if door_x < w * 0.5 else -w * 0.08)
	var inner = color.lightened(0.08)
	var ia = z - d / 2.0 + t
	var ib = z + d / 2.0 - t
	var gap = 1.1
	var mid = (ia + ib) * 0.5
	for seg in [[ia, mid - gap * 0.5], [mid + gap * 0.5, ib]]:
		var L = seg[1] - seg[0]
		if L > 0.3:
			add_box(px, 0.0, (seg[0] + seg[1]) * 0.5, 0.22, h, L, inner, {"dest": true, "hp": 140.0})
	add_box(px, 2.1, mid, 0.22, h - 2.1, gap, inner, {"dest": true, "hp": 140.0})
	flat_plane(x, z, w - 0.4, d - 0.4, Color(0.47, 0.4, 0.32), 0.02)
	var rc = ROOFC[rng.randi() % ROOFC.size()]
	_pitched_roof(x, z, w, d, h, rc, true, minf(w, d) * 0.38 + 0.5)
	# the porch: a lean-to roof on posts over the front door, a board floor and a step
	var fx = x - w / 2.0 + door_x
	var fz = z + front * (d / 2.0 + 1.3)
	var wood = Color(0.38, 0.28, 0.19)
	for e in [-1.0, 1.0]:
		add_box(fx + e * 1.5, 0.0, fz + front * 1.0, 0.16, h - 0.5, 0.16, wood, {"dest": true, "hp": 60.0, "mat": 1})
	add_box(fx, h - 0.55, fz, 3.6, 0.1, 2.8, rc.darkened(0.1), {"collide": false, "rx": front * 0.16})
	add_box(fx, 0.0, fz, 3.3, 0.14, 2.5, wood.lightened(0.05), {"collide": false})
	for k in range(5):
		add_box(fx - 1.4 + k * 0.7, 0.14, fz, 0.04, 0.01, 2.5, wood.darkened(0.25), {"collide": false})
	_claim(bld, c0)
	# a room each side of the inside wall
	var lw = px - (x - w / 2.0)
	var rw = (x + w / 2.0) - px
	_furnish(x - w / 2.0 + lw / 2.0, z, lw, d, 0.0)
	_furnish(px + rw / 2.0, z, rw, d, 0.0)

func big_building(x: float, z: float, w: float, d: float) -> void:
	var r = rng.randf()
	if r < 0.34:
		warehouse(x, z, w, d)
	elif r < 0.67:
		church(x, z, w, d)
	else:
		apartment(x, z, w, d)

func warehouse(x: float, z: float, w: float, d: float) -> void:
	var color = Color(0.55, 0.5, 0.44) if rng.randf() < 0.5 else Color(0.5, 0.3, 0.24)
	var t = 0.4
	var h = 5.2
	var bld = {"x": x, "z": z, "w": w, "d": d, "h": h + 2.0, "cols": [], "walls0": 0, "fallen": 0}
	buildings.append(bld)
	var c0 = cols.size()
	var along_x = w >= d
	# big loading doors at both ends
	for e in [-1.0, 1.0]:
		if along_x:
			_wall_piece(false, x + e * w / 2.0, z - d / 2.0 + 1.1, 2.2, 0.0, h, color, t)
			_wall_piece(false, x + e * w / 2.0, z + d / 2.0 - 1.1, 2.2, 0.0, h, color, t)
			_wall_piece(false, x + e * w / 2.0, z, d - 4.4, 3.6, h - 3.6, color, t, "lintel")
		else:
			_wall_piece(true, z + e * d / 2.0, x - w / 2.0 + 1.1, 2.2, 0.0, h, color, t)
			_wall_piece(true, z + e * d / 2.0, x + w / 2.0 - 1.1, 2.2, 0.0, h, color, t)
			_wall_piece(true, z + e * d / 2.0, x, w - 4.4, 3.6, h - 3.6, color, t, "lintel")
	# long sides: high windows in a row
	if along_x:
		wall_run(true, z - d / 2.0, x - w / 2.0, x + w / 2.0, h, color, t, true)
		wall_run(true, z + d / 2.0, x - w / 2.0, x + w / 2.0, h, color, t, true)
	else:
		wall_run(false, x - w / 2.0, z - d / 2.0 + t / 2.0, z + d / 2.0 - t / 2.0, h, color, t, true)
		wall_run(false, x + w / 2.0, z - d / 2.0 + t / 2.0, z + d / 2.0 - t / 2.0, h, color, t, true)
	flat_plane(x, z, w - 0.4, d - 0.4, Color(0.4, 0.39, 0.37), 0.02)
	_pitched_roof(x, z, w, d, h, Color(0.38, 0.4, 0.4), false, 1.6)
	for i in range(6):
		crate(x + rnd(-w / 2.0 + 2.0, w / 2.0 - 2.0), z + rnd(-d / 2.0 + 1.5, d / 2.0 - 1.5), rnd(0.9, 1.3))
	_claim(bld, c0)

func church(x: float, z: float, w: float, d: float) -> void:
	var color = Color(0.74, 0.72, 0.66)
	var t = 0.5
	var h = 6.0
	var bld = {"x": x, "z": z, "w": w, "d": d, "h": h + 3.0, "cols": [], "walls0": 0, "fallen": 0}
	buildings.append(bld)
	var c0 = cols.size()
	var along_x = w >= d
	if along_x:
		wall_run(true, z - d / 2.0, x - w / 2.0, x + w / 2.0, h, color, t, true)
		wall_run(true, z + d / 2.0, x - w / 2.0, x + w / 2.0, h, color, t, true)
		wall_run(false, x + w / 2.0, z - d / 2.0 + t / 2.0, z + d / 2.0 - t / 2.0, h, color, t, true)
		wall_run(false, x - w / 2.0, z - d / 2.0 + t / 2.0, z + d / 2.0 - t / 2.0, h, color, t, true, (d - t) / 2.0)
	else:
		wall_run(false, x - w / 2.0, z - d / 2.0 + t / 2.0, z + d / 2.0 - t / 2.0, h, color, t, true)
		wall_run(false, x + w / 2.0, z - d / 2.0 + t / 2.0, z + d / 2.0 - t / 2.0, h, color, t, true)
		wall_run(true, z + d / 2.0, x - w / 2.0, x + w / 2.0, h, color, t, true)
		wall_run(true, z - d / 2.0, x - w / 2.0, x + w / 2.0, h, color, t, true, w / 2.0)
	flat_plane(x, z, w - 0.5, d - 0.5, Color(0.5, 0.48, 0.44), 0.02)
	_pitched_roof(x, z, w, d, h, Color(0.3, 0.31, 0.34), false, minf(w, d) * 0.55)
	# pews
	for i in range(5):
		var o = -0.3 + i * 0.13
		if along_x:
			add_box(x + w * o, 0.0, z, 0.5, 0.8, d * 0.6, Color(0.36, 0.25, 0.16), {"hp": 60.0})
		else:
			add_box(x, 0.0, z + d * o, w * 0.6, 0.8, 0.5, Color(0.36, 0.25, 0.16), {"hp": 60.0})
	_claim(bld, c0)
	# the steeple at the entrance end, a separate tower that can come down on its own
	var sx = x - w / 2.0 - 1.6 if along_x else x
	var sz = z if along_x else z - d / 2.0 - 1.6
	var c1 = cols.size()
	var sb = {"x": sx, "z": sz, "w": 3.4, "d": 3.4, "h": 15.0, "cols": [], "walls0": 0, "fallen": 0}
	buildings.append(sb)
	for k in range(3):
		var y0 = k * 4.0
		for e in [-1.0, 1.0]:
			# an archway through the bottom of the tower, in line with the church door
			if not (k == 0 and along_x):
				add_box(sx + e * 1.45, y0, sz, 0.5, 4.0, 3.4, color.darkened(0.04), {"dest": true, "hp": 320.0})
			if not (k == 0 and not along_x):
				add_box(sx, y0, sz + e * 1.45, 2.4, 4.0, 0.5, color.darkened(0.04), {"dest": true, "hp": 320.0})
		if k == 0:
			for e in [-1.0, 1.0]:
				if along_x:
					add_box(sx + e * 1.45, 0.0, sz + 1.2, 0.5, 4.0, 1.0, color.darkened(0.04), {"dest": true, "hp": 320.0})
					add_box(sx + e * 1.45, 0.0, sz - 1.2, 0.5, 4.0, 1.0, color.darkened(0.04), {"dest": true, "hp": 320.0})
					add_box(sx + e * 1.45, 2.6, sz, 0.5, 1.4, 1.4, color.darkened(0.04), {"dest": true, "hp": 320.0})
				else:
					add_box(sx + 1.2, 0.0, sz + e * 1.45, 1.0, 4.0, 0.5, color.darkened(0.04), {"dest": true, "hp": 320.0})
					add_box(sx - 1.2, 0.0, sz + e * 1.45, 1.0, 4.0, 0.5, color.darkened(0.04), {"dest": true, "hp": 320.0})
					add_box(sx, 2.6, sz + e * 1.45, 1.4, 1.4, 0.5, color.darkened(0.04), {"dest": true, "hp": 320.0})
	add_box(sx, 12.0, sz, 3.8, 0.4, 3.8, color.lightened(0.1), {"dest": true, "hp": 200.0})
	var spire = add_box(sx, ground_y(sx, sz) + 12.4, sz, 3.2, 5.5, 3.2, Color(0.3, 0.31, 0.34), {"shape": "cone", "abs": true, "collide": false})
	cols[cols.size() - 1].vis.append(spire)
	cols[cols.size() - 1].vis.append(add_box(sx, ground_y(sx, sz) + 17.6, sz, 0.12, 1.4, 0.12, Color(0.6, 0.55, 0.35), {"abs": true, "collide": false}))
	_claim(sb, c1)

func apartment(x: float, z: float, w: float, d: float) -> void:
	var color: Color = [Color(0.68, 0.64, 0.58), Color(0.6, 0.48, 0.4), Color(0.62, 0.62, 0.6)][rng.randi() % 3]
	var t = 0.4
	var h = 3.3
	var floors = 3
	var bld = {"x": x, "z": z, "w": w, "d": d, "h": h * floors + 0.5, "cols": [], "walls0": 0, "fallen": 0}
	buildings.append(bld)
	var c0 = cols.size()
	# ground floor you can walk into; upper floors are solid walls with dark window panes
	wall_run(true, z - d / 2.0, x - w / 2.0, x + w / 2.0, h, color, t, true, w / 2.0)
	wall_run(true, z + d / 2.0, x - w / 2.0, x + w / 2.0, h, color, t, true, w / 2.0)
	wall_run(false, x - w / 2.0, z - d / 2.0 + t / 2.0, z + d / 2.0 - t / 2.0, h, color, t, true)
	wall_run(false, x + w / 2.0, z - d / 2.0 + t / 2.0, z + d / 2.0 - t / 2.0, h, color, t, true)
	flat_plane(x, z, w - 0.4, d - 0.4, Color(0.44, 0.42, 0.38), 0.02)
	var glass = Color(0.16, 0.19, 0.22)
	for f in range(1, floors):
		var y0 = f * h
		add_box(x, y0 - 0.25, z, w - 0.3, 0.3, d - 0.3, Color(0.5, 0.48, 0.45), {"dest": true, "hp": 260.0})
		for sd in [[true, -1.0], [true, 1.0], [false, -1.0], [false, 1.0]]:
			var horiz: bool = sd[0]
			var L = w if horiz else d - t
			var n = maxi(2, roundi(L / 2.6))
			for i in range(n):
				var c = (x if horiz else z) - L / 2.0 + (i + 0.5) * L / n
				var fixed = (z + sd[1] * d / 2.0) if horiz else (x + sd[1] * w / 2.0)
				_wall_piece(horiz, fixed, c, L / n, y0, h, color, t, "full")
				var wcol = cols[cols.size() - 1]
				piece_start()
				# a window: dark pane, sill and shutters, on the outside face
				var out = fixed + sd[1] * (t / 2.0 + 0.02)
				if horiz:
					add_box(c, y0 + 0.9, out, 1.1, 1.4, 0.04, glass, {"collide": false})
					add_box(c, y0 + 0.82, out + sd[1] * 0.06, 1.3, 0.1, 0.16, color.lightened(0.2), {"collide": false})
					for e in [-1.0, 1.0]:
						add_box(c + e * 0.75, y0 + 0.9, out + sd[1] * 0.03, 0.38, 1.4, 0.05, Color(0.3, 0.38, 0.3), {"collide": false})
				else:
					add_box(out, y0 + 0.9, c, 0.04, 1.4, 1.1, glass, {"collide": false})
					add_box(out + sd[1] * 0.06, y0 + 0.82, c, 0.16, 0.1, 1.3, color.lightened(0.2), {"collide": false})
					for e in [-1.0, 1.0]:
						add_box(out + sd[1] * 0.03, y0 + 0.9, c + e * 0.75, 0.05, 1.4, 0.38, Color(0.3, 0.38, 0.3), {"collide": false})
				wcol.vis.append_array(piece)
				piece = null
	var top = floors * h
	add_box(x, top - 0.25, z, w + 0.3, 0.35, d + 0.3, color.darkened(0.15), {"dest": true, "hp": 260.0})
	var rcol = cols[cols.size() - 1]
	piece_start()
	for e in [-1.0, 1.0]:
		add_box(x, top + 0.1, z + e * (d / 2.0), w + 0.3, 0.6, 0.25, color.darkened(0.1), {"collide": false})
		add_box(x + e * (w / 2.0), top + 0.1, z, 0.25, 0.6, d + 0.3, color.darkened(0.1), {"collide": false})
	add_box(x + w * 0.25, top + 0.1, z, 1.6, 1.4, 1.6, Color(0.45, 0.45, 0.43), {"collide": false})
	rcol.vis.append_array(piece)
	piece = null
	_claim(bld, c0)

# remember which colliders belong to a building so it can come down floor by floor
func _claim(bld: Dictionary, c0: int) -> void:
	for i in range(c0, cols.size()):
		var c = cols[i]
		if c.dest:
			bld["cols"].append(c)
			c.set_meta("bld", bld)
			if c.lo.y - c.gy < 0.5 and not c.has_meta("furn"):
				bld["walls0"] += 1

func _collapse_check(c) -> void:
	if not c.has_meta("bld"):
		return
	var bld = c.get_meta("bld")
	if c.lo.y - c.gy < 0.5 and not c.has_meta("furn"):
		bld["fallen"] += 1
	if bld.get("down", 0) >= 2 or bld["walls0"] == 0:
		return
	var frac = float(bld["fallen"]) / float(bld["walls0"])
	var stage = 2 if frac > 0.7 else (1 if frac > 0.4 else 0)
	if stage <= bld.get("down", 0):
		return
	bld["down"] = stage
	# the floors above give way first; then the rest of the shell
	var mid = Vector3(bld["x"], ground_y(bld["x"], bld["z"]), bld["z"])
	for o in bld["cols"].duplicate():
		if not o.alive:
			continue
		var upper = o.lo.y - o.gy > 1.5
		if upper or stage == 2:
			destroy_col(o, 3)
	G.fx.dust_cloud(mid + Vector3(0, 2, 0), maxf(bld["w"], bld["d"]))
	Combat.dust_at(mid, maxf(bld["w"], bld["d"]) * 1.4)
	G.audio.boom(mid)
	Combat.shake = maxf(Combat.shake, 0.4)
	for sd in G.soldiers:
		if sd.state != "dead" and absf(sd.pos.x - bld["x"]) < bld["w"] / 2.0 + 0.5 and absf(sd.pos.z - bld["z"]) < bld["d"] / 2.0 + 0.5:
			sd.hp -= 45.0 if sd.pos.y - mid.y < 1.0 else 120.0
			if sd.hp <= 0.0:
				Combat.kill(sd, null, false)
			else:
				sd.fall(2.0)

# two-storey building with stairs and an upper floor; upper windows become firing posts
func tower(x: float, z: float, w: float, d: float) -> void:
	var c0t = cols.size()
	_tower(x, z, w, d)
	var bld = {"x": x, "z": z, "w": w, "d": d, "h": 7.0, "cols": [], "walls0": 0, "fallen": 0}
	_claim(bld, c0t)

func _tower(x: float, z: float, w: float, d: float) -> void:
	var color: Color = WALLC[rng.randi() % WALLC.size()]
	var t = 0.35
	var FY = 3.45
	var H = 6.6
	buildings.append({"x": x, "z": z, "w": w, "d": d, "h": H})
	var T = {"x": x, "z": z, "w": w, "d": d, "floor_y": FY, "posts": [], "cps": [], "rect": [x - w / 2.0 - 0.5, x + w / 2.0 + 0.5, z - d / 2.0 - 0.5, z + d / 2.0 + 0.5]}
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
	_under_stairs(sx0, sx1, sz0, sz1, ground_y(x, z), FY, 1.0)
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
	_geo().add_child(ramp)
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

# the space under a flight of stairs: solid on the ground floor (nobody walks through the steps), open on
# top (the ramp is walked on above it). dir: which way along x the stairs rise.
func _under_stairs(x0: float, x1: float, z0: float, z1: float, gy: float, rise: float, dir: float) -> void:
	var n = 6
	for i in range(n):
		var k0 = float(i) / n
		var k1 = float(i + 1) / n
		var hk = k0 if dir > 0.0 else 1.0 - k1     # the low end of this slice
		var h = rise * hk - 0.45
		if h < 0.5:
			continue
		var c = add_col(lerpf(x0, x1, (k0 + k1) / 2.0), gy, (z0 + z1) / 2.0, (x1 - x0) / n, h, z1 - z0)
		c.dest = false
		c.vis = []
		c.set_meta("under_stairs", true)

# is there a floor (a slab, roof or platform) under this spot at this height?
func floor_at(x: float, z: float, y: float) -> bool:
	for c in cell_at(x, z):
		if not c.alive or c.hi.y - c.lo.y > 0.7 or absf(c.hi.y - y) > 0.45:
			continue
		if x > c.lo.x - 0.35 and x < c.hi.x + 0.35 and z > c.lo.z - 0.35 and z < c.hi.z + 0.35:
			return true
	return false

# can men still get up into this building/tower and stand up there?
func tower_ok(T: Dictionary) -> bool:
	if T.get("ladder_down", false):
		return false
	var top: Vector3 = T["stair_top"]
	return floor_at(top.x, top.z, top.y) or floor_at(top.x, top.z, top.y + ground_y(top.x, top.z))

# is this upstairs post still somewhere a man can stand?
func cp_ok(cp) -> bool:
	if cp == null:
		return false
	if not cp.upper:
		return true
	if cp.tower != null and not tower_ok(cp.tower):
		return false
	return floor_at(cp.p.x, cp.p.z, cp.p.y)

# a ladder whose wall (or roof) has come down falls over and is gone
func _ladder_check(c) -> void:
	for T in towers:
		if not T.get("ladder", false) or T.get("ladder_down", false) or not T.has("lad_pts"):
			continue
		var hit = false
		for q in T["lad_pts"]:
			if q.x > c.lo.x - 0.6 and q.x < c.hi.x + 0.6 and q.z > c.lo.z - 0.6 and q.z < c.hi.z + 0.6 and q.y > c.lo.y - 0.3 and q.y < c.hi.y + 0.3:
				hit = true
		if not hit:
			continue
		T["ladder_down"] = true
		var zero = Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0, -500, 0))
		for r in T.get("lad_refs", []):
			var g = r[0]
			if r[1] >= 0 and r[1] < g["xforms"].size():
				g["xforms"][r[1]] = zero
				if g["mm"]:
					g["mm"].set_instance_transform(r[1], zero)
		G.fx.falling_ladder(T["lad_base"], T["n"], T["lad_len"])
		# anyone on it comes off
		for s in G.soldiers:
			if s.climb != null and s.climb["T"] == T:
				s.climb = null
				s.vy = 0.0
			if s.tower == T and s.route != null:
				s.route = null
				s.tower = null
				s.task = null
				s.decide_t = 0.0

func _tower_piece(horiz: bool, fixed: float, c: float, seg: float, y0: float, h: float, color: Color, t: float) -> void:
	if horiz:
		add_box(c, y0, fixed, seg, h, t, color, {"dest": true, "hp": 240.0})
	else:
		add_box(fixed, y0, c, t, h, seg, color, {"dest": true, "hp": 240.0})
	var col = cols[cols.size() - 1] if edit_node == null and not cols.is_empty() else null
	piece_start()
	if y0 < 0.05:
		_trim(horiz, fixed, c, seg, 0.0, 0.42, t + 0.1, color.darkened(0.28))
	if absf(h - 1.0) < 0.01 or (y0 > 3.0 and absf(h - 1.0) < 0.01):
		_trim(horiz, fixed, c, seg + 0.1, y0 + h - 0.02, 0.1, t + 0.22, color.lightened(0.2))
	if y0 + h > 6.5:
		_trim(horiz, fixed, c, seg, y0 + h - 0.2, 0.2, t + 0.16, color.lightened(0.2))
	if y0 < 3.2 and y0 + h > 3.5:
		_trim(horiz, fixed, c, seg, 3.25, 0.16, t + 0.1, color.lightened(0.2))
	piece_end(col, color, 240.0)

func sandbags(x: float, z: float, ln: float, along_x: bool, h: float = 1.0) -> void:
	var rows = roundi(h / 0.5)
	var layers = maxi(1, roundi(rows * 0.5 / 0.25))
	var gy = ground_y(x, z)
	var c
	if along_x:
		c = add_col(x, gy, z, ln, rows * 0.5, 0.65)
	else:
		c = add_col(x, gy, z, 0.65, rows * 0.5, ln)
	piece_start()
	var n = maxi(1, roundi(ln / 0.86))
	for k in range(layers):
		var stag = 0.5 if k % 2 == 1 else 0.0
		for i in range(n + (1 if k % 2 == 1 else 0)):
			var o = -ln / 2.0 + (i + 0.5 - stag) * ln / n
			if absf(o) > ln / 2.0 - 0.15:
				o = clampf(o, -ln / 2.0 + 0.3, ln / 2.0 - 0.3)
			var bx = x + o if along_x else x + rnd(-0.03, 0.03)
			var bz = z + rnd(-0.03, 0.03) if along_x else z + o
			var bc = Color(0.69, 0.64, 0.48) if (i + k) % 3 == 0 else (Color(0.64, 0.58, 0.44) if (i + k) % 3 == 1 else Color(0.6, 0.55, 0.41))
			add_box(bx, k * 0.25 - 0.06, bz, rnd(0.9, 0.98), rnd(0.33, 0.37), rnd(0.58, 0.64), bc, {"collide": false, "shape": "pillow", "ry": rnd(-0.1, 0.1) + (0.0 if along_x else PI / 2.0)})
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
	var gy = ground_y(x, z)
	if along_z:
		add_col(x, gy, z + 0.3, 2.4, 2.2, 7.2)
		wreck_prop("truck", x, z + 0.3, 0.0)
	else:
		add_col(x + 0.3, gy, z, 7.2, 2.2, 2.4)
		wreck_prop("truck", x + 0.3, z, PI / 2.0)
	smoke_sources.append(Vector3(x, gy + 2.4, z))

func tank(x: float, z: float) -> void:
	var gy = ground_y(x, z)
	add_col(x, gy, z, 7.0, 2.2, 3.6)
	wreck_prop("tank", x, z, PI / 2.0 + rnd(-0.15, 0.15))
	smoke_sources.append(Vector3(x, gy + 2.5, z))

# a burnt-out vehicle left on the map: the real model, scorched, sitting a little askew
func wreck_prop(kind: String, x: float, z: float, yaw: float) -> void:
	var v = Vehicle.new()
	v.kind = kind
	v.spec = Vehicle.SPECS[kind]
	v.team = rng.randi() % 2
	v.dead = true
	_geo().add_child(v)
	var gy = ground_y(x, z)
	var xf = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3(0, 0, 1), rnd(-0.05, 0.05)) * Basis(Vector3(1, 0, 0), rnd(-0.03, 0.03)), Vector3(x, gy - 0.12, z))
	v.global_transform = xf
	v.body = AnimatableBody3D.new()
	v.body.collision_layer = 0
	v.body.collision_mask = 0
	_geo().add_child(v.body)
	VModel.build(v)
	v._wreck_paint(v)
	if v.turret != null:
		v.turret.rotation.y = rnd(-0.8, 0.8)
	if v.gun_pivot != null:
		v.gun_pivot.rotation.x = rnd(-0.15, 0.05)
	v.set_process(false)
	v.set_physics_process(false)

func dead_tree(x: float, z: float) -> void:
	var h = rnd(4.0, 7.0)
	var c = Color(0.24, 0.2, 0.16)
	var tc = add_col(x, ground_y(x, z), z, 0.4, h, 0.4, 1)
	piece_start()
	add_box(x, 0.0, z, 0.32, h, 0.32, c, {"rz": rnd(-0.08, 0.08), "collide": false})
	for i in range(4):
		add_box(x + rnd(-0.6, 0.6), h * rnd(0.5, 0.9), z + rnd(-0.6, 0.6), 0.12, rnd(1.0, 2.2), 0.12, c, {"rz": rnd(-1, 1), "rx": rnd(-1, 1), "collide": false})
	piece_end(tc, c, 180.0)
	tc.set_meta("tree", h)
	tc.set_meta("dead_tree", true)

# a wooden fence: posts and two rails; low enough to vault, flimsy enough to drive through
func fence_row(x: float, z: float, ln: float, along_x: bool) -> void:
	var fc = Color(0.5, 0.42, 0.3)
	var c = add_col(x, ground_y(x, z), z, ln if along_x else 0.14, 0.95, 0.14 if along_x else ln, 1)
	piece_start()
	var n = maxi(2, int(ln / 1.3))
	for i in range(n + 1):
		var o = -ln / 2.0 + i * ln / n
		add_box(x + o if along_x else x, 0.0, z if along_x else z + o, 0.1, 1.0, 0.1, fc.darkened(0.15), {"collide": false})
	for yy in [0.35, 0.75]:
		add_box(x, yy, z, ln if along_x else 0.05, 0.08, 0.05 if along_x else ln, fc, {"collide": false})
	piece_end(c, fc, 50.0)
	c.set_meta("fence", true)

# a shell crater: a dark scooped bowl with a ring of thrown-up earth, and the rim is cover for anyone lying in it
var craters: Array = []
func blast_crater(p: Vector3, r: float) -> void:
	if in_water(p.x, p.z) or inside_any(p.x, p.z, 0.5):
		return
	var gy = ground_y(p.x, p.z)
	if absf(p.y - gy) > 1.2:
		return
	var node = Node3D.new()
	geo_root.add_child(node)
	node.position = Vector3(p.x, gy, p.z)
	var bowl = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r * 0.45
	cm.height = 0.12
	bowl.mesh = cm
	bowl.material_override = _crater_mat(Color(0.2, 0.17, 0.13))
	bowl.position = Vector3(0, 0.02, 0)
	node.add_child(bowl)
	var n = 9
	for k in range(n):
		var a = k * TAU / n + randf_range(-0.2, 0.2)
		var lump = MeshInstance3D.new()
		lump.mesh = shape_mesh("blob")
		lump.material_override = _crater_mat(Color(0.36, 0.3, 0.22).lerp(Color(0.3, 0.26, 0.2), randf()))
		var s = randf_range(0.7, 1.1) * r * 0.55
		lump.scale = Vector3(s * 1.4, s * 0.45, s)
		lump.rotation.y = -a
		lump.position = Vector3(cos(a) * r, 0.0, sin(a) * r)
		node.add_child(lump)
	# the thrown-up earth of the rim stops bullets and hides a man lying in the hole (you can still walk over it)
	var rims = []
	# (small lumps out on the lip, clear of the bowl: big boxes reached in over the spots where men lie
	# and trapped them inside)
	for k in range(8):
		var a3 = k * TAU / 8.0
		var rp = Vector3(p.x + cos(a3) * r * 1.08, 0, p.z + sin(a3) * r * 1.08)
		var rc = add_col(rp.x, gy, rp.z, r * 0.42, 0.38 + r * 0.04, r * 0.42)
		rc.no_move = true
		rc.dest = false
		rc.vis = []
		rc.set_meta("crater_rim", true)
		rims.append(rc)
	# lying in the bowl, the rim keeps you out of sight
	var cps = []
	for k in range(4):
		var a2 = k * TAU / 4.0 + randf() * 0.5
		var d = Vector3(cos(a2), 0, sin(a2))
		var cp = add_cp(p.x + d.x * r * 0.45, p.z + d.z * r * 0.45, -d, Vector3(-d.z, 0, d.x), "low", null)
		if cp != null:
			cp.set_meta("crater", true)
			cps.append(cp)
	craters.append({"n": node, "cps": cps, "rims": rims})
	if craters.size() > 120:
		var old = craters.pop_front()
		if is_instance_valid(old["n"]):
			old["n"].queue_free()
		for rc2 in old.get("rims", []):
			if rc2.alive:
				rc2.alive = false
				cols.erase(rc2)
				_remove_grid(rc2)
				if is_instance_valid(rc2.body):
					rc2.body.queue_free()
		for cp in old["cps"]:
			cover.erase(cp)
			var kk = _ckey(cp.p.x, cp.p.z)
			if cover_grid.has(kk):
				cover_grid[kk].erase(cp)

static var crater_mats = {}
func _crater_mat(c: Color) -> StandardMaterial3D:
	var k = c.to_html()
	if not crater_mats.has(k):
		var m = StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 1.0
		crater_mats[k] = m
	return crater_mats[k]

# what's left when a tree comes down: a splintered stump, and the trunk lying where it fell
func _tree_down(c) -> void:
	var x = (c.lo.x + c.hi.x) * 0.5
	var z = (c.lo.z + c.hi.z) * 0.5
	var h: float = c.get_meta("tree")
	var dir: Vector3 = c.get_meta("fall") if c.has_meta("fall") else Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	var dead = c.has_meta("dead_tree")
	var trunk = Color(0.24, 0.2, 0.16) if dead else Color(0.29, 0.23, 0.16)
	var sh = randf_range(0.35, 0.9)
	# the tree doesn't vanish: it tips over and crashes down (in the direction it was pushed), and the
	# trunk then lies there as a log that blocks wheeled vehicles until something blows it apart
	if G.started and not G.attract:
		var falling = Node3D.new()
		var gy0 = ground_y(x, z)
		falling.position = Vector3(x, gy0 + sh, z)
		geo_root.add_child(falling)
		var tm = MeshInstance3D.new()
		tm.mesh = VModel.cyl_mesh(0.2, h - sh, -1.0, 8)
		tm.material_override = VModel.mat(trunk)
		tm.position = Vector3(0, (h - sh) * 0.5, 0)
		falling.add_child(tm)
		if not dead:
			var lm = VModel.mat(Color(0.27, 0.35, 0.18))
			for k in range(4):
				var b = MeshInstance3D.new()
				var sm = SphereMesh.new()
				sm.radius = randf_range(0.9, 1.4)
				sm.height = sm.radius * 1.7
				sm.radial_segments = 8
				sm.rings = 4
				b.mesh = sm
				b.material_override = lm
				b.position = Vector3(randf_range(-0.6, 0.6), h - sh - 0.8 + randf_range(-0.4, 0.5), randf_range(-0.6, 0.6))
				falling.add_child(b)
		var axis = Vector3.UP.cross(dir).normalized()
		var tw = falling.create_tween()
		tw.tween_method(func(k: float): falling.basis = Basis(axis, k * k * PI * 0.5), 0.0, 1.0, randf_range(1.0, 1.5))
		tw.tween_callback(func():
			falling.queue_free()
			_tree_landed(x, z, h, sh, dir, dead, trunk))
		_tree_stump(x, z, sh, trunk)
		return
	build_now(func():
		add_box(x, 0.0, z, 0.46, sh, 0.46, trunk.darkened(0.15), {"collide": false, "shape": "cyl"})
		for k in range(4):
			var a = k * PI / 2.0 + randf_range(-0.4, 0.4)
			add_box(x + cos(a) * 0.13, sh - 0.05, z + sin(a) * 0.13, 0.08, randf_range(0.2, 0.45), 0.08, Color(0.62, 0.52, 0.36), {"collide": false, "rz": cos(a) * 0.35, "rx": -sin(a) * 0.35})
		if randf() < 0.85:
			var L = maxf(1.5, h - sh)
			var mid = Vector3(x, 0, z) + dir * (L * 0.5 + 0.3)
			add_box(mid.x, 0.05, mid.z, 0.38, 0.38, L, trunk, {"collide": false, "ry": atan2(dir.x, dir.z)})
			if not dead:
				var tip = Vector3(x, 0, z) + dir * (L + 0.8)
				for k in range(3):
					add_box(tip.x + randf_range(-0.9, 0.9), 0.0, tip.z + randf_range(-0.9, 0.9), randf_range(1.4, 2.2), randf_range(1.0, 1.5), randf_range(1.4, 2.2), Color(0.27, 0.34, 0.18), {"collide": false, "shape": "blob", "ry": randf() * 3.0}))

func _tree_stump(x: float, z: float, sh: float, trunk: Color) -> void:
	build_now(func():
		add_box(x, 0.0, z, 0.46, sh, 0.46, trunk.darkened(0.15), {"collide": false, "shape": "cyl"})
		for k in range(4):
			var a = k * PI / 2.0 + randf_range(-0.4, 0.4)
			add_box(x + cos(a) * 0.13, sh - 0.05, z + sin(a) * 0.13, 0.08, randf_range(0.2, 0.45), 0.08, Color(0.62, 0.52, 0.36), {"collide": false, "rz": cos(a) * 0.35, "rx": -sin(a) * 0.35}))

# the crash: dust, a thump, anyone underneath knocked flat (or worse), and the log left lying
func _tree_landed(x: float, z: float, h: float, sh: float, dir: Vector3, dead: bool, trunk: Color) -> void:
	var L = maxf(1.5, h - sh)
	var base = Vector3(x, ground_y(x, z), z)
	var tip = base + dir * (L + 0.5)
	G.fx.dust_cloud(base.lerp(tip, 0.6), 2.5)
	G.audio.boom(base.lerp(tip, 0.5))
	for sd in G.soldiers:
		if sd.state == "dead" or sd.vehicle != null:
			continue
		var t = clampf(G.flat(sd.pos - base).dot(dir) / maxf(L, 0.1), 0.0, 1.0)
		if G.dist2d(sd.pos, base + dir * (L * t)) < 0.8 and absf(sd.pos.y - base.y) < 1.5:
			sd.hp -= 45.0
			if sd.hp <= 0.0:
				Combat.kill(sd, null, false)
			else:
				sd.fall(2.0)
	build_now(func():
		var mid = Vector3(x, 0, z) + dir * (L * 0.5 + 0.3)
		add_box(mid.x, 0.05, mid.z, 0.38, 0.38, L, trunk, {"collide": false, "ry": atan2(dir.x, dir.z)})
		if not dead:
			var tp = Vector3(x, 0, z) + dir * (L + 0.8)
			for k in range(3):
				add_box(tp.x + randf_range(-0.9, 0.9), 0.0, tp.z + randf_range(-0.9, 0.9), randf_range(1.4, 2.2), randf_range(1.0, 1.5), randf_range(1.4, 2.2), Color(0.27, 0.34, 0.18), {"collide": false, "shape": "blob", "ry": randf() * 3.0})
		# the log itself: a run of low blocks along the trunk (boxes can't lie at an angle)
		var n = maxi(2, int(L / 0.9))
		for k in range(n):
			var q = Vector3(x, 0, z) + dir * (0.6 + (L - 0.3) * (float(k) + 0.5) / n)
			var lc = add_col(q.x, ground_y(q.x, q.z), q.z, 0.55, 0.42, 0.55, 0)
			lc.dest = true
			lc.hp = 140.0
			lc.color = trunk
			lc.set_meta("log", true))

func live_tree(x: float, z: float) -> void:
	var h = rnd(3.0, 5.0)
	var trunk = Color(0.29, 0.23, 0.16)
	var tc = add_col(x, ground_y(x, z), z, 0.45, h, 0.45, 1)
	piece_start()
	add_box(x, 0.0, z, 0.42, h, 0.42, trunk, {"collide": false, "shape": "cyl"})
	# a couple of branches
	for i in range(2):
		var a = rnd(0, TAU)
		add_box(x + cos(a) * 0.5, h * rnd(0.55, 0.75), z + sin(a) * 0.5, 0.14, 1.3, 0.14, trunk, {"collide": false, "shape": "cyl", "rz": cos(a) * 0.9, "rx": -sin(a) * 0.9})
	var leaf = [Color(0.27, 0.35, 0.18), Color(0.25, 0.32, 0.16), Color(0.32, 0.39, 0.23), Color(0.29, 0.37, 0.19)]
	var nb = rng.randi_range(5, 7)
	for i in range(nb):
		var s = rnd(1.6, 2.6) if i > 0 else rnd(2.6, 3.2)
		var a = float(i) / nb * TAU + rnd(-0.4, 0.4)
		var r = 0.0 if i == 0 else rnd(0.8, 1.4)
		add_box(x + cos(a) * r, h - 1.1 + rnd(0.0, 1.2) - (0.0 if i == 0 else 0.4), z + sin(a) * r, s, s * 0.85, s, leaf[i % leaf.size()], {"ry": rnd(0, 3), "collide": false, "shape": "blob"})
	piece_end(tc, trunk, 240.0)
	tc.set_meta("tree", h)

# a rounded bush clump (visual only)
func bush(x: float, z: float, sc: float = 1.0) -> void:
	if on_road(x, z) or on_road(x + 1.2, z) or on_road(x - 1.2, z) or on_road(x, z + 1.2) or on_road(x, z - 1.2):
		return
	var cl = [Color(0.26, 0.33, 0.17), Color(0.3, 0.37, 0.2), Color(0.23, 0.3, 0.15), Color(0.33, 0.38, 0.19)]
	# a mound of leafy clumps: big ones low down, smaller ones piled on top and out at the sides
	var n = rng.randi_range(4, 6)
	var hgt = 0.0
	for i in range(n):
		var s = (rnd(0.85, 1.25) if i < 3 else rnd(0.55, 0.85)) * sc
		var r = (rnd(0.2, 0.65) if i < 3 else rnd(0.0, 0.45)) * sc
		var a = rnd(0.0, TAU)
		var y = -0.2 if i < 3 else rnd(0.25, 0.5) * sc
		hgt = maxf(hgt, y + s * 0.8)
		add_box(x + cos(a) * r, y, z + sin(a) * r, s * rnd(1.0, 1.3), s * rnd(0.72, 0.88), s, cl[(i + rng.randi()) % 4], {"ry": rnd(0, 3), "collide": false, "shape": "blob"})
	# a few woody stems showing at the bottom
	for i in range(3):
		var a2 = rnd(0.0, TAU)
		add_box(x + cos(a2) * 0.35 * sc, 0.0, z + sin(a2) * 0.35 * sc, 0.05, 0.45 * sc, 0.05, Color(0.24, 0.19, 0.13), {"collide": false, "rx": rnd(-0.4, 0.4), "rz": rnd(-0.4, 0.4)})

func skyline(colors: Array, hmin: float, hmax: float) -> void:
	return
	for i in range(46 if not is_large() else 70):
		var a = rnd(0.0, TAU)
		var r = rnd(1.45, 1.9) * TW / 2.0
		add_box(cos(a) * r, 0.0, sin(a) * r * float(TH_) / float(TW) * 1.1, rnd(8, 20), rnd(hmin, hmax), rnd(8, 18), colors[i % colors.size()], {"collide": false, "no_shadow": true})

func base(sx: float, dist: float = 96.0) -> void:
	var bx = sx * dist
	for i in range(3):
		var tz = -22.0 + i * 22.0
		if not near_road(bx + sx * 7.0, tz, 4.5):
			ridge_tent(bx + sx * 7.0, tz, Color(0.33, 0.38, 0.24) if sx < 0 else Color(0.42, 0.39, 0.28))
	# (in commander mode the HQ is the base: no stray flagpole and crates left standing about)
	if G.mode != "commander":
		add_box(bx + sx * 3.0, 0.0, 0.0, 0.15, 7.0, 0.15, Color(0.27, 0.27, 0.27), {"collide": false})
		add_box(bx + sx * 3.9, 5.6, 0.0, 1.6, 1.0, 0.05, G.team_color(0 if sx < 0 else 1), {"collide": false, "no_shadow": true})
		ammo_crate(bx + sx * 1.5, -5.0, 0 if sx < 0 else 1, true)
		ammo_crate(bx + sx * 1.5, 5.0, 0 if sx < 0 else 1, true)

# a small camp: flagpole and two ammo crates
func camp(t: int, p: Vector3) -> void:
	if G.mode != "commander" and not on_road(p.x, p.z):
		add_box(p.x, 0.0, p.z, 0.15, 7.0, 0.15, Color(0.27, 0.27, 0.27), {"collide": false})
		add_box(p.x + 0.9, 5.6, p.z, 1.6, 1.0, 0.05, G.team_color(t), {"collide": false, "no_shadow": true})
		ammo_crate(p.x - 4.0, p.z, t, true)
		ammo_crate(p.x + 4.0, p.z, t, true)
	# tents and a sandbag ring facing the middle of the map
	var hut = G.TEAM_UNI[t].lerp(Color(0.4, 0.4, 0.33), 0.5) if t < G.TEAM_UNI.size() else Color(0.4, 0.4, 0.33)
	var inward = -signf(p.z) if absf(p.z) > absf(p.x) else 0.0
	for i in range(3):
		var hx = p.x - 18.0 + i * 18.0
		var hz = p.z - inward * 9.0
		# never on (or right by) the road: that's where vehicles come in
		if near_road(hx, hz, 4.5):
			hx += 9.0 if hx >= p.x else -9.0
		if not inside_any(hx, hz, 3.0) and not near_road(hx, hz, 4.5):
			ridge_tent(hx, hz, hut)
	for k in [-1.0, 1.0]:
		sandbags(p.x + k * 9.0, p.z + inward * 8.0, 5.0, true)
	fuel_drums(p.x + 13.0, p.z - inward * 3.0, 3)

# a canvas ridge tent: sloping sides down to the ground, a pole at each end, a darker door flap and pegged guy lines
func ridge_tent(x: float, z: float, col: Color) -> void:
	var L = 6.0
	var W = 4.0
	var H = 2.4
	var r0 = add_box(x, 0.0, z, W * 0.8, H * 0.55, L * 0.95, col, {"dest": true, "hp": 120.0, "no_shadow": true})
	var c0 = cols[cols.size() - 1]
	piece_start()
	# the canvas (the box collider above stays hidden under it)
	add_box(x, 0.0, z, W, H, L, col, {"shape": "prism", "collide": false})
	add_box(x, H - 0.06, z, 0.1, 0.12, L + 0.1, col.darkened(0.25), {"collide": false})
	for e in [-1.0, 1.0]:
		add_box(x, 0.0, z + e * (L * 0.5 + 0.02), 0.07, H + 0.25, 0.07, Color(0.38, 0.28, 0.18), {"collide": false})
		add_box(x, 0.0, z + e * (L * 0.5 + 0.03), W * 0.42, H * 0.7, 0.04, col.darkened(0.35), {"collide": false, "shape": "prism"})
		for sd in [-1.0, 1.0]:
			add_box(x + sd * (W * 0.5 + 0.9), 0.0, z + e * (L * 0.5 + 0.4), 0.06, 0.25, 0.06, Color(0.38, 0.28, 0.18), {"collide": false})
	c0.vis.append_array(piece)
	piece = null
	# the collider box itself is never drawn
	if r0[0] is Dictionary:
		r0[0]["xforms"][r0[1]] = Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0, -500, 0))
	elif r0[0] is Node3D:
		r0[0].visible = false

# an ammo crate: stand next to it for a second to restock
func ammo_crate(x: float, z: float, team: int, base_crate: bool = false) -> void:
	add_box(x, 0.0, z, 1.3, 0.7, 0.8, Color(0.24, 0.29, 0.18), {"mat": 1})
	add_box(x, 0.7, z, 1.32, 0.06, 0.2, Color(0.82, 0.7, 0.2), {"collide": false})
	# crates at a side's own base never run out; ones lying around the map do
	var at_base = base_crate
	ammo_points.append({"p": Vector3(x, ground_y(x, z), z), "team": team, "stock": 1e9 if at_base else 60.0})
	# crates lying out on the map often have a few fuel drums stacked by them
	if not at_base and team < 0 and absi(hash(Vector2i(int(x), int(z)))) % 10 < 6:
		fuel_drums(x + 1.9, z + 0.3, 2 + absi(hash(Vector2i(int(z), int(x)))) % 2)

# where a beaten soldier runs back to
# where a beaten soldier falls back to: the nearest held point behind him, or a line 40 m back toward base
func fallback_point(team: int, from: Vector3) -> Vector3:
	var home: Vector3 = spawn[team]
	var back = G.flat(home - from)
	if back.length() < 45.0:
		return home
	var best = from + back.normalized() * 40.0
	if Obj.chain():
		var bd = 1e9
		for pt in Obj.points:
			if pt["owner"] == team and G.dist2d(pt["p"], from) < bd and G.dist2d(pt["p"], home) < G.dist2d(from, home):
				bd = G.dist2d(pt["p"], from)
				best = pt["p"] + G.flat(home - pt["p"]).normalized() * 8.0
	return best

# (reinforcements gather behind the most forward control point the team holds, otherwise at base)
func rally_point(team: int) -> Vector3:
	var r: Vector3 = spawn[team]
	if Obj.chain() or G.mode == "laststand":
		var i = Obj.forward_held(team)
		if i >= 0:
			var p: Vector3 = Obj.points[i]["p"]
			var back = G.flat(spawn[team] - p).normalized()
			r = p + back * 14.0
	# a FOB further forward (or the only base left) is where reinforcements gather
	var f = Build.forward_fob(team, r)
	if f != null:
		return f
	return r

func crater_at(x: float, z: float, r: float, d: float) -> void:
	for rd in roads:
		if x > rd[0] - r * 1.7 and x < rd[1] + r * 1.7 and z > rd[2] - r * 1.7 and z < rd[3] + r * 1.7:
			return
	crater_ter(x, z, r, d)
	for k in range(6):
		var a = k / 6.0 * TAU + 0.3
		terrain_cover.append([x + cos(a) * r * 0.55, z + sin(a) * r * 0.55, -cos(a), -sin(a)])

func hedge_row(x: float, z: float, ln: float, along_x: bool) -> void:
	# never across or along a road: keep only the stretches that are off it, cut into separate hedges
	var n0 = maxi(2, int(ln / 0.6))
	var runs = []
	var cur = null
	for i in range(n0 + 1):
		var o = -ln / 2.0 + ln * i / n0
		var px = x + o if along_x else x
		var pz = z if along_x else z + o
		var bad = false
		for q in [Vector2(0, 0), Vector2(0.9, 0), Vector2(-0.9, 0), Vector2(0, 0.9), Vector2(0, -0.9)]:
			if on_road(px + q.x, pz + q.y):
				bad = true
		if not bad:
			if cur == null:
				cur = [o, o]
			else:
				cur[1] = o
		elif cur != null:
			runs.append(cur)
			cur = null
	if cur != null:
		runs.append(cur)
	if runs.size() == 1 and runs[0][0] <= -ln / 2.0 + 0.01 and runs[0][1] >= ln / 2.0 - 0.01:
		_hedge_piece(x, z, ln, along_x)
		return
	for r in runs:
		var L = r[1] - r[0]
		if L >= 2.0:
			var m = (r[0] + r[1]) * 0.5
			_hedge_piece(x + m if along_x else x, z if along_x else z + m, L, along_x)

func _hedge_piece(x: float, z: float, ln: float, along_x: bool) -> void:
	var hc = Color(0.31, 0.35, 0.2)
	# collider only; the visible hedge is a row of leafy clumps
	var c = add_col(x, ground_y(x, z), z, ln if along_x else 0.9, 1.3, 0.9 if along_x else ln)
	c.vis = []
	c.dest = true
	c.hp = 180.0
	c.prop = 2
	c.color = hc
	piece_start()
	var cl = [Color(0.34, 0.39, 0.23), Color(0.29, 0.35, 0.19), Color(0.32, 0.37, 0.21)]
	var n = maxi(2, int(ln / 0.9))
	for i in range(n):
		var o = -ln / 2.0 + (i + 0.5) * ln / n
		var s = rnd(1.15, 1.45)
		var j = rnd(-0.12, 0.12)
		add_box(x + o if along_x else x + j, -0.1, z + j if along_x else z + o, s * 0.95, s * 0.85, s * 0.95, cl[(i + 1) % 3], {"collide": false, "ry": rnd(0, 3), "shape": "blob"})
		add_box(x + o if along_x else x - j, rnd(0.45, 0.7), z - j if along_x else z + o, s, s * rnd(0.75, 0.9), s, cl[i % 3], {"collide": false, "ry": rnd(0, 3), "shape": "blob"})
	piece_end(c, hc, 180.0)
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
		if rng.randf() < 0.4:
			house(b[0], b[1], b[2], b[3])
		else:
			building(b[0], b[1], b[2], b[3], b[4])
	tower(-24, -29, 10, 8); tower(-24, 13, 11, 8); tower(12, -28, 9, 10); tower(28, 14, 10, 9)
	# bigger farmhouses round the edge of the town
	big_house(26, -40, 12, 8); big_house(-27, 41, 12, 8); big_house(8, 44, 12, 7.5)
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
	tower(2, 30, 10, 8); big_house(-4, -32, 13, 10)
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

# ---------------------------------------------------------------- scenery beyond the edge of the map
var backdrop: Node3D = null

# rolling country (or ruined suburbs, or shell-torn mud) stretching to the horizon, with forests and buildings
# round-crowned trees among the firs, hedgerows along the field edges, and smoke rising from fighting
# somewhere far off
func _backdrop_extras(x0: float, hw: float, hd: float, hfun: Callable, tn: FastNoiseLite) -> void:
	var trees: Array = []
	var hedges: Array = []
	var tries = 0
	while trees.size() < 1300 and tries < 9000:
		tries += 1
		var x = rng.randf_range(x0, -x0)
		var z = rng.randf_range(x0, -x0)
		var ex = maxf(absf(x) - hw, absf(z) - hd)
		if ex < 10.0 or ex > 480.0:
			continue
		var y = hfun.call(x, z)
		if y < -1.0:
			continue
		if tn.get_noise_2d(x * 1.3 + 50.0, z * 1.3) > 0.0 or rng.randf() < 0.12:
			trees.append(Vector3(x, y, z))
	# hedgerows: lines of bushes along the field boundaries near the map
	for k in range(140):
		var horiz = rng.randf() < 0.5
		var x = rng.randf_range(x0 * 0.55, -x0 * 0.55)
		var z = rng.randf_range(x0 * 0.55, -x0 * 0.55)
		x = roundf(x / 70.0) * 70.0 if not horiz else x
		z = roundf(z / 52.0) * 52.0 if horiz else z
		var L = rng.randf_range(30.0, 70.0)
		for i in range(int(L / 3.0)):
			var p = Vector3(x + (i * 3.0 if horiz else 0.0), 0, z + (0.0 if horiz else i * 3.0))
			if maxf(absf(p.x) - hw, absf(p.z) - hd) < 6.0:
				continue
			p.y = hfun.call(p.x, p.z)
			if p.y < -1.0 or p.y > 24.0:
				continue
			hedges.append(p)
	var blob = shape_mesh("blob")
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = blob
	mm.instance_count = trees.size() * 2 + hedges.size()
	var trunk = MultiMesh.new()
	trunk.transform_format = MultiMesh.TRANSFORM_3D
	var tm = CylinderMesh.new()
	tm.top_radius = 0.25
	tm.bottom_radius = 0.35
	tm.height = 1.0
	tm.radial_segments = 5
	tm.rings = 1
	trunk.mesh = tm
	trunk.instance_count = trees.size()
	var i2 = 0
	for i in range(trees.size()):
		var p: Vector3 = trees[i]
		var s = rng.randf_range(4.5, 8.5)
		var th = s * 0.55
		trunk.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(1, th, 1)), p + Vector3(0, th * 0.5, 0)))
		mm.set_instance_transform(i2, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * 0.8, s)), p + Vector3(0, th + s * 0.3, 0)))
		mm.set_instance_transform(i2 + 1, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s * 0.7, s * 0.6, s * 0.7)), p + Vector3(rng.randf_range(-1, 1) * s * 0.3, th + s * 0.62, rng.randf_range(-1, 1) * s * 0.3)))
		i2 += 2
	for p in hedges:
		var s2 = rng.randf_range(2.4, 3.6)
		mm.set_instance_transform(i2, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s2 * 1.2, s2 * 0.8, s2)), p + Vector3(0, s2 * 0.3, 0)))
		i2 += 1
	var cm = MultiMeshInstance3D.new()
	cm.multimesh = mm
	cm.material_override = Props.foliage(Color(0.27, 0.35, 0.18))
	cm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	backdrop.add_child(cm)
	var tmi = MultiMeshInstance3D.new()
	tmi.multimesh = trunk
	var bm = StandardMaterial3D.new()
	bm.albedo_color = Color(0.25, 0.2, 0.15)
	bm.roughness = 1.0
	tmi.material_override = bm
	tmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	backdrop.add_child(tmi)
	# smoke from a battle somewhere beyond the hills
	for k in range(rng.randi_range(2, 3)):
		var a = rng.randf() * TAU
		var r = rng.randf_range(420.0, 650.0)
		var sp = Vector3(cos(a) * r, 0, sin(a) * r)
		sp.y = maxf(0.0, hfun.call(sp.x, sp.z))
		var p = CPUParticles3D.new()
		p.amount = 14
		p.lifetime = 40.0
		p.preprocess = 40.0
		p.direction = Vector3(0.15, 1, 0)
		p.spread = 8.0
		p.gravity = Vector3(0.25, 0.6, 0)
		p.initial_velocity_min = 2.0
		p.initial_velocity_max = 3.0
		var q = QuadMesh.new()
		q.size = Vector2(1, 1)
		p.mesh = q
		p.material_override = G.fx.billboard_mat(Color(1, 1, 1, 1), false)
		p.color = Color(0.32, 0.3, 0.29, 0.55)
		p.color_ramp = G.fx._fade_ramp(Color(0.32, 0.3, 0.29, 0.55))
		p.scale_amount_min = 18.0
		p.scale_amount_max = 26.0
		p.scale_amount_curve = G.fx._grow_curve(1.0, 3.0)
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		backdrop.add_child(p)
		p.position = sp

func build_backdrop(style: String) -> void:
	if backdrop:
		backdrop.queue_free()
	backdrop = Node3D.new()
	add_child(backdrop)
	var noise = FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.004
	noise.fractal_octaves = 4
	var tree_noise = FastNoiseLite.new()
	tree_noise.seed = noise.seed + 7
	tree_noise.frequency = 0.012
	var hw = TW / 2.0
	var hd = TH_ / 2.0
	var R = 760.0
	var cell = 14.0
	var n = int(2.0 * (maxf(hw, hd) + R) / cell)
	var x0 = -(maxf(hw, hd) + R)
	var base_c: Color = MAPS.get(G.map_id, {}).get("ground", Color(0.45, 0.45, 0.35))
	var hill_c = base_c.lerp(Color(0.3, 0.38, 0.2), 0.45) if style != "war" else base_c.darkened(0.15)
	var far_c = Color(0.42, 0.47, 0.5)
	var verts = PackedVector3Array()
	var cols = PackedColorArray()
	# roads that run off the edge of the map carry on across the countryside
	var road_z: Array = []
	var road_x: Array = []
	for rd in roads:
		if rd[1] - rd[0] > TW * 0.9:
			road_z.append([(rd[2] + rd[3]) * 0.5, (rd[3] - rd[2]) * 0.5])
		elif rd[3] - rd[2] > TH_ * 0.9:
			road_x.append([(rd[0] + rd[1]) * 0.5, (rd[1] - rd[0]) * 0.5])
	var sea = G.map_id == "beach"
	var hfun = func(x: float, z: float) -> float:
		var ex = maxf(0.0, maxf(absf(x) - hw, absf(z) - hd))
		if ex <= 0.0:
			return -2.0
		# the beach map: open sea all the way to the horizon in the west, the coast bending back west beyond the map
		if sea and x < -hw + 68.0 - maxf(0.0, absf(z) - hd) * 0.4:
			return -6.0
		var k = clampf(ex / 90.0, 0.0, 1.0)
		for rz in road_z:
			if absf(x) > hw:
				k = minf(k, clampf((absf(z - rz[0]) - rz[1] - 3.0) / 25.0, 0.0, 1.0))
		for rx in road_x:
			if absf(z) > hd:
				k = minf(k, clampf((absf(x - rx[0]) - rx[1] - 3.0) / 25.0, 0.0, 1.0))
		var h = (noise.get_noise_2d(x, z) * 0.5 + 0.5) * 38.0 * k * k
		h += clampf((ex - 350.0) / 300.0, 0.0, 1.0) * (60.0 + noise.get_noise_2d(x * 0.5, z * 0.5) * 50.0)
		return h - 0.4 * (1.0 - k)
	var hs = PackedFloat32Array()
	hs.resize((n + 1) * (n + 1))
	for iz in range(n + 1):
		for ix in range(n + 1):
			hs[iz * (n + 1) + ix] = hfun.call(x0 + ix * cell, x0 + iz * cell)
	var st = SurfaceTool.new()
	var arr_v = PackedVector3Array()
	var arr_c = PackedColorArray()
	var arr_n = PackedVector3Array()
	for iz in range(n):
		for ix in range(n):
			var xa = x0 + ix * cell
			var za = x0 + iz * cell
			# skip cells entirely inside the playable map
			if xa > -hw + 2.0 and xa + cell < hw - 2.0 and za > -hd + 2.0 and za + cell < hd - 2.0:
				continue
			var q = [[ix, iz], [ix + 1, iz], [ix, iz + 1], [ix + 1, iz + 1]]
			var pv = []
			for c in q:
				pv.append(Vector3(x0 + c[0] * cell, hs[c[1] * (n + 1) + c[0]], x0 + c[1] * cell))
			var nrm = (pv[2] - pv[0]).cross(pv[1] - pv[0]).normalized()
			if nrm.y < 0.0:
				nrm = -nrm
			var hh = (pv[0].y + pv[3].y) * 0.5
			var col = base_c.lerp(hill_c, clampf(hh / 20.0, 0.0, 1.0)).lerp(far_c, clampf((hh - 40.0) / 80.0, 0.0, 0.7))
			# farm country: a patchwork of fields (wheat, pasture, ploughed earth, green crops) on the low ground
			if style == "farm" and hh < 26.0 and hh > -1.0:
				var fx = floori((xa + 0.35 * cell + noise.get_noise_2d(za, 0.0) * 30.0) / 70.0)
				var fz = floori((za + noise.get_noise_2d(0.0, xa) * 30.0) / 52.0)
				var fh = absi((fx * 73856093) ^ (fz * 19349663)) % 6
				var fc = [Color(0.74, 0.66, 0.38), Color(0.44, 0.52, 0.26), Color(0.5, 0.41, 0.3), Color(0.56, 0.6, 0.3), Color(0.66, 0.6, 0.36), base_c][fh]
				col = col.lerp(fc, 0.55 * (1.0 - clampf(hh / 26.0, 0.0, 1.0)))
			col = col * (0.93 + 0.07 * noise.get_noise_2d(xa * 3.0, za * 3.0))
			col.a = 1.0
			for idx in [0, 1, 2, 1, 3, 2]:
				arr_v.append(pv[idx])
				arr_c.append(col)
				arr_n.append(nrm)
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = arr_v
	arrays[Mesh.ARRAY_COLOR] = arr_c
	arrays[Mesh.ARRAY_NORMAL] = arr_n
	var am = ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	am.surface_set_material(0, mat)
	var mi = MeshInstance3D.new()
	mi.mesh = am
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	backdrop.add_child(mi)
	for rz in road_z:
		for sx in [-1.0, 1.0]:
			_road_strip(Vector3(sx * (hw + 300.0), 0.0, rz[0]), Vector2(600.0, rz[1] * 2.0))
	for rx in road_x:
		for sz in [-1.0, 1.0]:
			_road_strip(Vector3(rx[0], 0.0, sz * (hd + 300.0)), Vector2(rx[1] * 2.0, 600.0))
	# woods: clumps of trees where the noise says so
	var crowns: Array = []
	var tries = 0
	var want = 2600 if style != "war" else 700
	while crowns.size() < want and tries < want * 6:
		tries += 1
		var x = rng.randf_range(x0, -x0)
		var z = rng.randf_range(x0, -x0)
		var ex = maxf(absf(x) - hw, absf(z) - hd)
		if ex < 8.0 or ex > 520.0:
			continue
		var dens = tree_noise.get_noise_2d(x, z)
		if dens < (0.05 if style != "war" else 0.35):
			continue
		var cy = hfun.call(x, z)
		if cy < -1.0:
			continue
		crowns.append(Vector3(x, cy, z))
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var cone = CylinderMesh.new()
	cone.top_radius = 0.0 if style != "war" else 0.12
	cone.bottom_radius = 2.2 if style != "war" else 0.2
	cone.height = 8.0
	cone.radial_segments = 6
	cone.rings = 1
	mm.mesh = cone
	mm.instance_count = crowns.size()
	for i in range(crowns.size()):
		var p: Vector3 = crowns[i]
		var sc = rng.randf_range(0.7, 1.5)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(sc, sc * rng.randf_range(0.8, 1.3), sc)), p + Vector3(0, 3.6 * sc, 0)))
		var g = Color(0.2, 0.3, 0.15) if style != "war" else Color(0.22, 0.18, 0.14)
		mm.set_instance_color(i, g * rng.randf_range(0.8, 1.2))
	var tmi = MultiMeshInstance3D.new()
	tmi.multimesh = mm
	var tmat = StandardMaterial3D.new()
	tmat.vertex_color_use_as_albedo = true
	tmat.vertex_color_is_srgb = true
	tmat.roughness = 1.0
	tmi.material_override = tmat
	tmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	backdrop.add_child(tmi)
	if style != "war":
		_backdrop_extras(x0, hw, hd, hfun, tree_noise)
	# buildings: ruined suburbs around the town, farmsteads in the country
	var houses = 140 if style == "urban" else (36 if style == "farm" else 12)
	var walls = [Color(0.78, 0.71, 0.56), Color(0.73, 0.64, 0.49), Color(0.61, 0.59, 0.55), Color(0.56, 0.33, 0.27), Color(0.82, 0.76, 0.62)]
	var roofs = [Color(0.45, 0.25, 0.2), Color(0.36, 0.29, 0.25), Color(0.3, 0.3, 0.32)]
	var hmm = MultiMesh.new()
	hmm.transform_format = MultiMesh.TRANSFORM_3D
	hmm.use_colors = true
	hmm.mesh = BoxMesh.new()
	hmm.instance_count = houses * 2
	var prm = MultiMesh.new()
	prm.transform_format = MultiMesh.TRANSFORM_3D
	prm.use_colors = true
	var prism = PrismMesh.new()
	prism.size = Vector3(1, 1, 1)
	prm.mesh = prism
	prm.instance_count = houses
	var chm = MultiMesh.new()
	chm.transform_format = MultiMesh.TRANSFORM_3D
	chm.use_colors = true
	chm.mesh = BoxMesh.new()
	chm.instance_count = houses
	var wnm = MultiMesh.new()
	wnm.transform_format = MultiMesh.TRANSFORM_3D
	wnm.use_colors = true
	wnm.mesh = BoxMesh.new()
	wnm.instance_count = houses * 2
	var np = 0
	var nc = 0
	var nw = 0
	var k = 0
	tries = 0
	while k < houses and tries < houses * 20:
		tries += 1
		var x = rng.randf_range(x0, -x0)
		var z = rng.randf_range(x0, -x0)
		var ex = maxf(absf(x) - hw, absf(z) - hd)
		var maxd = 180.0 if style == "urban" else 420.0
		if ex < 12.0 or ex > maxd:
			continue
		var y = hfun.call(x, z)
		if y > 20.0 or y < -1.0:
			continue
		var w = rng.randf_range(7, 13)
		var d = rng.randf_range(6, 11)
		var h = rng.randf_range(4, 9) if style == "urban" else rng.randf_range(3.5, 6)
		if style == "urban" and rng.randf() < 0.4:
			h *= rng.randf_range(0.3, 0.6)     # ruined
		var yaw = rng.randf_range(0, PI)
		var bb = Basis(Vector3.UP, yaw)
		hmm.set_instance_transform(k * 2, Transform3D(bb.scaled(Vector3(w, h, d)), Vector3(x, y + h / 2.0 - 0.3, z)))
		hmm.set_instance_color(k * 2, walls[rng.randi() % walls.size()])
		var ruined = style == "urban" and h < 4.0
		var rc: Color = roofs[rng.randi() % roofs.size()]
		if ruined or (style == "urban" and rng.randf() < 0.5):
			# flat roof with a parapet (or the bare top of a ruin)
			hmm.set_instance_transform(k * 2 + 1, Transform3D(bb.scaled(Vector3(w + 0.3, 0.45, d + 0.3)), Vector3(x, y + h + 0.2 - 0.3, z)))
			hmm.set_instance_color(k * 2 + 1, walls[rng.randi() % walls.size()].darkened(0.12))
		else:
			# a pitched roof with overhanging eaves, and a chimney
			hmm.set_instance_transform(k * 2 + 1, Transform3D(bb.scaled(Vector3(0.01, 0.01, 0.01)), Vector3(x, y - 50.0, z)))
			var rh = minf(w, d) * 0.32
			prm.set_instance_transform(np, Transform3D(bb.scaled(Vector3(w + 0.8, rh, d + 0.8)), Vector3(x, y + h + rh / 2.0 - 0.3, z)))
			prm.set_instance_color(np, rc)
			np += 1
			chm.set_instance_transform(nc, Transform3D(bb.scaled(Vector3(0.7, rh + 0.8, 0.7)), Vector3(x, y + h + rh * 0.5, z) + bb * Vector3(w * 0.28, 0, d * 0.1)))
			chm.set_instance_color(nc, Color(0.45, 0.32, 0.27))
			nc += 1
		# a dark band of windows along the long sides
		for sgn in [-1.0, 1.0]:
			wnm.set_instance_transform(nw, Transform3D(bb.scaled(Vector3(w * 0.75, minf(1.2, h * 0.25), 0.1)), Vector3(x, y + h * 0.55, z) + bb * Vector3(0, 0, sgn * (d * 0.5 + 0.03))))
			wnm.set_instance_color(nw, Color(0.14, 0.15, 0.17))
			nw += 1
		k += 1
	hmm.visible_instance_count = k * 2
	prm.visible_instance_count = np
	chm.visible_instance_count = nc
	wnm.visible_instance_count = nw
	for mmx in [hmm, prm, chm, wnm]:
		var hmi = MultiMeshInstance3D.new()
		hmi.multimesh = mmx
		hmi.material_override = tmat
		hmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		backdrop.add_child(hmi)

func _road_strip(c: Vector3, size: Vector2) -> void:
	var m = MeshInstance3D.new()
	var pm = PlaneMesh.new()
	pm.size = size
	m.mesh = pm
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.31, 0.3, 0.3)
	mat.roughness = 1.0
	m.material_override = mat
	m.position = c + Vector3(0, 0.02, 0)
	backdrop.add_child(m)

# ---------------------------------------------------------------- large maps
# a cluster of houses (some with an upper floor) around a point, keeping clear of roads
func village(cx: float, cz: float, rx: float, rz: float, n: int, towers_: int) -> void:
	n = int(round(n * 1.3))       # busier villages
	var placed: Array = []
	var tries = 0
	while placed.size() < n + towers_ and tries < 200:
		tries += 1
		var tw = placed.size() < towers_
		var big = (placed.size() - towers_) % 4 == 0 and n >= 4
		var w = rnd(8, 11) if tw else (rnd(13, 16) if big else rnd(6, 10))
		var d = rnd(7, 9) if tw else (rnd(9, 11) if big else rnd(6, 9))
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
		elif q[2] >= 12.5:
			if rng.randf() < 0.55 and edit_node == null:
				big_house(q[0], q[1], q[2], q[3])
			else:
				big_building(q[0], q[1], q[2], q[3])
		elif rng.randf() < 0.45:
			house(q[0], q[1], q[2], q[3])
			# a garden fence along one side
			if rng.randf() < 0.6:
				var side = 1.0 if rng.randf() < 0.5 else -1.0
				if rng.randf() < 0.5:
					fence_row(q[0], q[1] + side * (q[3] / 2.0 + 2.2), q[2] + 2.0, true)
				else:
					fence_row(q[0] + side * (q[2] / 2.0 + 2.2), q[1], q[3] + 2.0, false)
			if absi(hash(Vector2i(int(q[0] * 3.0), int(q[1] * 3.0)))) % 10 < 2:
				fuel_drums(q[0] + q[2] / 2.0 + 1.0, q[1] - q[3] / 2.0 - 1.0, 2)
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

# ---------------------------------------------------------------- custom maps (from the map editor)
const ITEM_KINDS = ["house", "tower", "wall", "sandbags", "crate", "hedge", "tree", "deadtree", "hedgehog", "tankwreck", "truckwreck", "ammo", "road", "trench"]

func build_item(it: Dictionary) -> void:
	rng.seed = it.get("seed", 1)
	var x: float = it["x"]
	var z: float = it["z"]
	var ax: bool = it.get("rot", 0) == 0
	match it["t"]:
		"house":
			building(x, z, 9.0 if ax else 7.0, 7.0 if ax else 9.0, 4.5)
		"tower":
			tower(x, z, 10.0 if ax else 8.0, 8.0 if ax else 10.0)
		"wall":
			add_box(x, 0.0, z, 8.0 if ax else 0.45, 2.2, 0.45 if ax else 8.0, Color(0.6, 0.57, 0.52), {"dest": true, "hp": 160.0})
		"sandbags":
			sandbags(x, z, 4.0, ax)
		"crate":
			crate(x, z, 1.0)
		"hedge":
			hedge_row(x, z, 8.0, ax)
		"tree":
			live_tree(x, z)
		"deadtree":
			dead_tree(x, z)
		"hedgehog":
			hedgehog(x, z)
		"tankwreck":
			tank(x, z)
		"truckwreck":
			truck(x, z, not ax)
		"ammo":
			ammo_crate(x, z, -1)
		"road":
			flat_plane(x, z, it["w"], it["d"], Color(0.31, 0.3, 0.3), 0.015)
		"trench":
			var a = Vector2(it["x"], it["z"])
			var b = Vector2(it["x2"], it["z2"])
			var mid = (a + b) / 2.0
			add_box(mid.x, 0.02, mid.y, 0.9, 0.06, a.distance_to(b), Color(0.35, 0.27, 0.2), {"collide": false, "ry": atan2(b.x - a.x, b.y - a.y)})

func build_custom(m: Dictionary) -> void:
	th = m["heights"].duplicate()
	paint = m.get("paint", PackedByteArray()).duplicate()
	roads = []
	for it in m["items"]:
		if it["t"] == "road":
			roads.append([it["x"] - it["w"] / 2.0, it["x"] + it["w"] / 2.0, it["z"] - it["d"] / 2.0, it["z"] + it["d"] / 2.0])
	build_terrain(m["ground"])
	for it in m["items"]:
		build_item(it)
		if it["t"] == "trench":
			var a = Vector2(it["x"], it["z"])
			var b = Vector2(it["x2"], it["z2"])
			var n = maxi(1, int(a.distance_to(b) / 1.6))
			var dir = (b - a).normalized()
			var nrm = Vector2(-dir.y, dir.x)
			for k in range(n + 1):
				var p = a.lerp(b, float(k) / n)
				terrain_cover.append([p.x + nrm.x * 0.45, p.y + nrm.y * 0.45, -nrm.x, -nrm.y])
				terrain_cover.append([p.x - nrm.x * 0.45, p.y - nrm.y * 0.45, nrm.x, nrm.y])
	spawn = [m["spawns"][0], m["spawns"][1]]
	for t in range(2):
		camp(t, spawn[t])
	objectives = []
	var pts: Array = m["points"].duplicate()
	pts.sort_custom(func(a, b): return a.x < b.x)
	var names = "ABCDEFGH"
	for i in range(pts.size()):
		objectives.append({"p": pts[i], "name": names[i % names.length()]})
	capture = pts[pts.size() / 2] if not pts.is_empty() else Vector3.ZERO
	skyline([Color(0.45, 0.47, 0.42), Color(0.4, 0.42, 0.37), Color(0.5, 0.52, 0.47)], 8, 24)

# the editor shows the map without nav, cover or decoration (those are built when you play it)
func begin_edit(m: Dictionary) -> void:
	if geo_root:
		geo_root.queue_free()
	geo_root = Node3D.new()
	add_child(geo_root)
	openings = []; tables = []; craters = []; cols = []; grid = {}; groups = {}; cover = []; cover_grid = {}; terrain_cover = []; towers = []; roof_cols = []; wall_marks = []; smoke_sources = []; buildings = []; cut_now = {}; grass_mm = null; grass_bent = []; roads = []; ammo_points = []; water = []; water_mats = []; bridges = []
	_set_size(m["size"].x, m["size"].y)
	th = m["heights"]
	paint = m.get("paint", PackedByteArray())
	build_terrain(m["ground"])

# ---------------------------------------------------------------- more maps
func bunker(x: float, z: float) -> void:
	var cc = Color(0.54, 0.53, 0.5)
	add_box(x, 0, z - 4, 6, 1.4, 0.6, cc, {"dest": true, "hp": 300.0}); add_box(x, 0, z + 4, 6, 1.4, 0.6, cc, {"dest": true, "hp": 300.0})
	for p in [[-3, -4], [3, -4], [-3, 4], [3, 4]]:
		add_box(x + p[0], 0, z + p[1], 0.5, 2.1, 0.5, Color(0.49, 0.48, 0.45), {"dest": true, "hp": 300.0})
	add_box(x, 2.1, z, 6.6, 0.3, 8.6, Color(0.49, 0.48, 0.45), {"dest": true, "hp": 300.0})

func _std_end(style_ground: String, objs: Array, sp: float) -> void:
	objectives = []
	var names = "ABCDEFGH"
	for i in range(objs.size()):
		objectives.append({"p": objs[i], "name": names[i]})
	capture = objs[objs.size() / 2]
	spawn = [Vector3(-sp, 0, 0), Vector3(sp, 0, 0)]
	for sx in [-1.0, 1.0]:
		base(sx, sp)

# a river runs north-south through the middle; three bridges cross it (blow them and you have to wade)
func build_river() -> void:
	var W2 = TW / 2.0
	var D2 = TH_ / 2.0
	for i in range(30):
		hill(rnd(-W2, W2), rnd(-D2, D2), rnd(16, 34), rnd(1.0, 3.5))
	roads = [[-W2, W2, -3.5, 3.5]]
	for sx in [-1.0, 1.0]:
		flatten_rect(sx * (W2 - 60.0) - 24.0, -28.0, sx * (W2 - 60.0) + 24.0, 28.0, 6.0)
	# the riverbed
	# the riverbed, with banks that slope gently down to the water instead of dropping off a step
	_each_vert(-34.0, -D2 - 2.0, 34.0, D2 + 2.0, func(i, vx, vz):
		var dx = absf(vx - sin(vz * 0.02) * 6.0)
		if dx < 7.0:
			th[i] = -2.6
		elif dx < 26.0:
			var k = G.smooth01((dx - 7.0) / 19.0)
			# the hills ease down toward the river; the bank meets the water about 10 m out
			var land = minf(th[i], 0.4 + (dx - 10.0) * 0.22)
			th[i] = lerpf(-2.6, land, k))
	var X = [-170.0, -80.0, 80.0, 170.0]
	var Z = [20.0, -25.0, 25.0, -20.0]
	var vil = []
	for i in range(4):
		village(X[i], Z[i], 22.0, 18.0, 5, 1)
		vil.append(return_village)
	_flatten_roads()
	build_terrain(MAPS["river"]["ground"])
	# the water follows the river's bends in short strips
	var seg = 8.0
	var zz = -D2
	while zz < D2:
		var cx = sin((zz + seg * 0.5) * 0.02) * 6.0
		add_water(cx - 21.0, cx + 21.0, zz, minf(D2, zz + seg), -0.7, Color(0.22, 0.34, 0.38, 0.85))
		zz += seg
	for rd in roads:
		if rd[1] - rd[0] > 100.0:
			flat_plane(-W2 / 2.0 - 7.0, (rd[2] + rd[3]) * 0.5, W2 - 14.0, rd[3] - rd[2], Color(0.31, 0.3, 0.3), 0.015)
			flat_plane(W2 / 2.0 + 7.0, (rd[2] + rd[3]) * 0.5, W2 - 14.0, rd[3] - rd[2], Color(0.31, 0.3, 0.3), 0.015)
	bridge(-19.0, 19.0, 0.0, 7.0)
	bridge(-19.0, 19.0, -70.0, 5.0)
	bridge(-19.0, 19.0, 70.0, 5.0)
	for i in range(4):
		_village_build(vil[i], 1)
		strongpoint(X[i] + (8.0 if X[i] < 0.0 else -8.0), Z[i], 1.0 if X[i] < 0.0 else -1.0)
		ammo_crate(X[i], Z[i] + 6.0, -1)
	for zc in [0.0, -70.0, 70.0]:
		for sx in [-1.0, 1.0]:
			sandbags(sx * 22.0, zc + 6.0, 4.0, false); sandbags(sx * 22.0, zc - 6.0, 4.0, false)
	for i in range(80):
		var tx = rnd(-W2 + 10.0, W2 - 10.0)
		var tz = rnd(-D2 + 5.0, D2 - 5.0)
		if absf(tx) > 20.0 and not on_road(tx, tz) and not inside_any(tx, tz, 2.0):
			live_tree(tx, tz)
	var objs = [Vector3(-170, 0, 20), Vector3(-80, 0, -25), Vector3(0, 0, 0), Vector3(80, 0, 25), Vector3(170, 0, -20)]
	_std_end("farm", objs, W2 - 60.0)

# dense woods, a few clearings with log cabins and foxholes
func build_forest() -> void:
	var W2 = TW / 2.0
	var D2 = TH_ / 2.0
	for i in range(20):
		hill(rnd(-W2, W2), rnd(-D2, D2), rnd(14, 30), rnd(1.0, 3.0))
	var clear = [Vector3(-60, 0, 30), Vector3(0, 0, -20), Vector3(60, 0, 30)]
	for c in clear:
		flatten_rect(c.x - 14.0, c.z - 12.0, c.x + 14.0, c.z + 12.0, 6.0)
	for sx in [-1.0, 1.0]:
		flatten_rect(sx * (W2 - 40.0) - 20.0, -24.0, sx * (W2 - 40.0) + 20.0, 24.0, 6.0)
	roads = [[-W2, W2, -2.0, 2.0]]
	_flatten_roads()
	build_terrain(MAPS["forest"]["ground"])
	flat_plane(0, 0, TW, 4.0, Color(0.42, 0.36, 0.27), 0.015)
	var n = 0
	var tries = 0
	while n < 520 and tries < 4000:
		tries += 1
		var x = rnd(-W2 + 4.0, W2 - 4.0)
		var z = rnd(-D2 + 4.0, D2 - 4.0)
		var ok = not on_road(x, z) and absf(x) < W2 - 62.0
		for c in clear:
			if absf(x - c.x) < 15.0 and absf(z - c.z) < 13.0:
				ok = false
		if ok and not inside_any(x, z, 1.2):
			live_tree(x, z)
			n += 1
	for i in range(40):
		var x = rnd(-W2 + 70.0, W2 - 70.0)
		var z = rnd(-D2 + 8.0, D2 - 8.0)
		if not inside_any(x, z, 2.0) and not on_road(x, z):
			add_box(x, 0.0, z, rnd(3, 6), 0.55, 0.55, Color(0.33, 0.25, 0.17), {"ry": 0.0, "dest": true, "hp": 120.0, "mat": 1})
	for c in clear:
		building(c.x + 6.0, c.z + 3.0, 7.0, 6.0, 3.6)
		for k in range(3):
			crater_ter(c.x - 6.0 + k * 5.0, c.z - 6.0, 1.4, 0.8)
		sandbags(c.x - 4.0, c.z - 8.0, 4.0, true)
		ammo_crate(c.x, c.z + 8.0, -1)
	_std_end("farm", clear, W2 - 40.0)

# a grid of streets lined with houses, alleys between them
func build_city() -> void:
	var W2 = TW / 2.0
	var D2 = TH_ / 2.0
	roads = []
	for zc in [-60.0, 0.0, 60.0]:
		roads.append([-W2, W2, zc - 4.0, zc + 4.0])
	for xc in [-90.0, -30.0, 30.0, 90.0]:
		roads.append([xc - 4.0, xc + 4.0, -D2, D2])
	for sx in [-1.0, 1.0]:
		flatten_rect(sx * (W2 - 25.0) - 15.0, -20.0, sx * (W2 - 25.0) + 15.0, 20.0, 5.0)
	_flatten_roads()
	flatten_rect(-W2 + 40.0, -D2, W2 - 40.0, D2, 4.0)
	build_terrain(MAPS["city"]["ground"])
	for rd in roads:
		flat_plane((rd[0] + rd[1]) / 2.0, (rd[2] + rd[3]) / 2.0, rd[1] - rd[0], rd[3] - rd[2], Color(0.3, 0.3, 0.31), 0.015)
	var xs = [-120.0, -60.0, 0.0, 60.0, 120.0]
	var zs = [-90.0, -30.0, 30.0, 90.0]
	for bx in xs:
		for bz in zs:
			if absf(bx) > W2 - 45.0:
				continue
			# a block: a row of houses with an alley through the middle
			for k in range(-1, 2):
				var hx = bx + k * 15.0
				var hz = bz + rnd(-2, 2)
				var rr = rng.randf()
				if rr < 0.22:
					tower(hx, hz - 7.0, 11.0, 9.0)
				elif rr < 0.42:
					big_building(hx, hz - 7.0, 13.0, 10.0)
				elif rr < 0.6:
					house(hx, hz - 7.0, 12.0, 10.0, 3.6)
				else:
					building(hx, hz - 7.0, 12.0, 10.0, rnd(4.0, 7.5))
				if rng.randf() < 0.7:
					building(hx, hz + 8.0, 12.0, 9.0, rnd(3.8, 6.5))
			for i in range(3):
				crate(bx + rnd(-20, 20), bz + rnd(-2, 2), 1.0)
	for i in range(14):
		var p = Vector3(rnd(-W2 + 50.0, W2 - 50.0), 0, [-60.0, 0.0, 60.0][rng.randi() % 3] + rnd(-2.5, 2.5))
		if not inside_any(p.x, p.z, 2.0):
			if rng.randf() < 0.5:
				truck(p.x, p.z, false)
			else:
				sandbags(p.x, p.z, 4.0, false)
	var objs = [Vector3(-60, 0, 0), Vector3(0, 0, 0), Vector3(60, 0, 0)]
	for o in objs:
		ammo_crate(o.x + 2.0, o.z + 5.5, -1)
	_std_end("urban", objs, W2 - 25.0)

# a road winds up a valley between steep slopes; bunkers hold the heights
func build_pass() -> void:
	var W2 = TW / 2.0
	var D2 = TH_ / 2.0
	_each_vert(-W2, -D2, W2, D2, func(i, vx, vz):
		var dz = absf(vz - sin(vx * 0.012) * 25.0)
		th[i] += G.smooth01(clampf((dz - 18.0) / 70.0, 0.0, 1.0)) * (14.0 + 6.0 * sin(vx * 0.03)))
	for i in range(30):
		hill(rnd(-W2, W2), rnd(-D2, D2), rnd(10, 22), rnd(1.0, 3.0))
	roads = [[-W2, W2, -3.0, 3.0]]
	var X = [-160.0, -60.0, 60.0, 160.0]
	var objs = []
	for x in X:
		var zc = sin(x * 0.012) * 25.0
		flatten_rect(x - 10.0, zc - 10.0, x + 10.0, zc + 10.0, 6.0)
		objs.append(Vector3(x, 0, zc))
	for sx in [-1.0, 1.0]:
		var zc2 = sin(sx * (W2 - 50.0) * 0.012) * 25.0
		flatten_rect(sx * (W2 - 50.0) - 22.0, zc2 - 22.0, sx * (W2 - 50.0) + 22.0, zc2 + 22.0, 6.0)
	build_terrain(MAPS["pass"]["ground"])
	for o in objs:
		bunker(o.x, o.z)
		ammo_crate(o.x - 5.0, o.z, -1)
		for k in [-1.0, 1.0]:
			strongpoint(o.x + k * 12.0, o.z + k * 16.0, k)
	for i in range(30):
		var x = rnd(-W2 + 30.0, W2 - 30.0)
		var z = sin(x * 0.012) * 25.0 + rnd(-14, 14)
		if not inside_any(x, z, 3.0):
			add_box(x, 0.0, z, rnd(1.5, 3.5), rnd(1.0, 2.2), rnd(1.5, 3.0), Color(0.5, 0.48, 0.44), {"ry": 0.0})
	for i in range(70):
		if rng.randf() < 0.3:
			dead_tree(rnd(-W2, W2), rnd(-D2, D2))
		else:
			live_tree(rnd(-W2, W2), rnd(-D2, D2))
	objectives = []
	for i in range(objs.size()):
		objectives.append({"p": objs[i], "name": "ABCD"[i]})
	capture = objs[1]
	spawn = [Vector3(-(W2 - 50.0), 0, sin(-(W2 - 50.0) * 0.012) * 25.0), Vector3(W2 - 50.0, 0, sin((W2 - 50.0) * 0.012) * 25.0)]
	for t in range(2):
		camp(t, spawn[t])

# Alpha comes ashore from the sea in the west; Bravo holds the dunes and bunkers
func build_beach() -> void:
	var W2 = TW / 2.0
	var D2 = TH_ / 2.0
	_each_vert(-W2, -D2, W2, D2, func(i, vx, vz):
		var k = (vx + W2) / TW
		th[i] = -3.0 + clampf(k * 3.2, 0.0, 1.0) * 3.0 + clampf((vx + 40.0) / 40.0, 0.0, 1.0) * 2.5 + sin(vz * 0.05) * 0.4)
	for i in range(18):
		hill(rnd(0, W2), rnd(-D2, D2), rnd(10, 20), rnd(1.0, 2.5))
	flatten_rect(W2 - 60.0, -24.0, W2 - 20.0, 24.0, 6.0)
	build_terrain(MAPS["beach"]["ground"])
	add_water(-W2 - 1300.0, -W2 + 70.0, -D2 - 1300.0, D2 + 1300.0, -0.4, Color(0.2, 0.36, 0.45, 0.88))
	for i in range(40):
		hedgehog(rnd(-W2 + 70.0, -W2 + 120.0), rnd(-D2 + 10.0, D2 - 10.0))
	for i in range(4):
		var bz = -75.0 + i * 50.0
		bunker(-W2 + 175.0, bz)
	for i in range(8):
		sandbags(-W2 + 150.0 + rnd(0, 20), rnd(-D2 + 10.0, D2 - 10.0), 5.0, false)
	for i in range(12):
		var x = -W2 + 128.0
		var z = -D2 + 10.0 + i * (TH_ - 20.0) / 11.0
		for k in range(5):
			add_box(x, 0.0, z + k * 1.4 - 2.8, 0.08, 0.9, 0.08, Color(0.23, 0.2, 0.17), {"collide": false})
		add_box(x, 0.4, z, 0.04, 0.04, 6.0, Color(0.33, 0.31, 0.29), {"collide": false})
	village(W2 - 90.0, 0.0, 26.0, 40.0, 7, 2)
	_village_build(return_village, 2)
	var objs = [Vector3(-W2 + 110.0, 0, 0), Vector3(-W2 + 175.0, 0, -25), Vector3(W2 - 90.0, 0, 0)]
	objectives = []
	for i in range(3):
		objectives.append({"p": objs[i], "name": "ABC"[i]})
	capture = objs[1]
	spawn = [Vector3(-W2 + 85.0, 0, 0), Vector3(W2 - 40.0, 0, 0)]
	camp(0, spawn[0])
	base(1.0, W2 - 40.0)

# a different battlefield every time, from a seed
func build_random(seed_v: int) -> void:
	rng.seed = seed_v
	var W2 = TW / 2.0
	var D2 = TH_ / 2.0
	for i in range(rng.randi_range(15, 40)):
		hill(rnd(-W2, W2), rnd(-D2, D2), rnd(12, 36), rnd(1.0, 4.5))
	var n = rng.randi_range(3, 5)
	var objs = []
	for i in range(n):
		objs.append(Vector3(-W2 + 70.0 + i * (TW - 140.0) / (n - 1), 0, rnd(-D2 * 0.5, D2 * 0.5)))
	roads = [[-W2, W2, -3.5, 3.5]] if rng.randf() < 0.7 else []
	var vils = []
	for o in objs:
		var kind = rng.randi() % 3
		if kind == 0:
			village(o.x, o.z, 20.0, 18.0, rng.randi_range(3, 7), rng.randi_range(0, 2))
			vils.append([return_village, 1])
		else:
			flatten_rect(o.x - 8.0, o.z - 8.0, o.x + 8.0, o.z + 8.0, 4.0)
			vils.append(null)
	for i in range(rng.randi_range(0, 30)):
		crater_at(rnd(-W2 + 60.0, W2 - 60.0), rnd(-D2, D2), rnd(2, 3.5), rnd(0.8, 1.3))
	for sx in [-1.0, 1.0]:
		flatten_rect(sx * (W2 - 40.0) - 20.0, -24.0, sx * (W2 - 40.0) + 20.0, 24.0, 6.0)
	_flatten_roads()
	build_terrain(Color(rng.randf_range(0.38, 0.55), rng.randf_range(0.4, 0.5), rng.randf_range(0.28, 0.38)))
	for rd in roads:
		flat_plane(0, 0, TW, rd[3] - rd[2], Color(0.31, 0.3, 0.3), 0.015)
	for i in range(objs.size()):
		var o = objs[i]
		if vils[i] != null:
			_village_build(vils[i][0], vils[i][1])
		elif rng.randf() < 0.5:
			bunker(o.x, o.z)
		else:
			strongpoint(o.x - 6.0, o.z, -1.0); strongpoint(o.x + 6.0, o.z, 1.0)
		ammo_crate(o.x + 3.0, o.z + 6.0, -1)
	for i in range(rng.randi_range(4, 14)):
		hedge_row(rnd(-W2 + 60.0, W2 - 60.0), rnd(-D2 + 10.0, D2 - 10.0), rnd(6, 16), rng.randf() < 0.5)
	for i in range(rng.randi_range(30, 160)):
		var x = rnd(-W2 + 10.0, W2 - 10.0)
		var z = rnd(-D2 + 5.0, D2 - 5.0)
		if not on_road(x, z) and not inside_any(x, z, 2.0):
			live_tree(x, z)
	for i in range(rng.randi_range(2, 8)):
		var x = rnd(-W2 + 70.0, W2 - 70.0)
		var z = rnd(-D2 + 15.0, D2 - 15.0)
		if not inside_any(x, z, 4.0):
			if rng.randf() < 0.5:
				tank(x, z)
			else:
				truck(x, z, rng.randf() < 0.5)
	_std_end("farm", objs, W2 - 40.0)

# the biggest map: five villages strung along a road across rolling farmland, woods, hedgerows and an old trench line
func build_huge() -> void:
	var W2 = TW / 2.0
	var D2 = TH_ / 2.0
	for i in range(70):
		hill(rnd(-W2, W2), rnd(-D2, D2), rnd(14, 44), rnd(1.0, 5.5))
	var objs = []
	for i in range(5):
		objs.append(Vector3(-W2 + 120.0 + i * (TW - 240.0) / 4.0, 0, rnd(-D2 * 0.35, D2 * 0.35)))
	roads = [[-W2, W2, -3.5, 3.5]]
	var vils = []
	for i in range(objs.size()):
		var o = objs[i]
		village(o.x, o.z, 30.0 if i == 2 else 24.0, 24.0, 8 if i == 2 else rng.randi_range(5, 7), rng.randi_range(1, 2))
		vils.append(return_village)
	# a trench line either side of the middle village
	for sx in [-1.0, 1.0]:
		var tx = objs[2].x + sx * 95.0
		var pts = []
		for k in range(9):
			pts.append(Vector2(tx + rnd(-4, 4), -D2 + 30.0 + k * (TH_ - 60.0) / 8.0))
		trench_ter(pts, 2.4, 1.5)
	for i in range(40):
		crater_at(rnd(-W2 + 80.0, W2 - 80.0), rnd(-D2, D2), rnd(2, 4), rnd(0.8, 1.4))
	for sx in [-1.0, 1.0]:
		flatten_rect(sx * (W2 - 40.0) - 20.0, -24.0, sx * (W2 - 40.0) + 20.0, 24.0, 6.0)
	_flatten_roads()
	build_terrain(MAPS["huge"]["ground"])
	for rd in roads:
		flat_plane(0, 0, TW, rd[3] - rd[2], Color(0.31, 0.3, 0.3), 0.015)
	for i in range(objs.size()):
		_village_build(vils[i], 1 if i != 2 else 2)
		ammo_crate(objs[i].x + 3.0, objs[i].z + 6.0, -1)
	# woods
	for w in range(8):
		var wx = rnd(-W2 + 90.0, W2 - 90.0)
		var wz = rnd(-D2 + 30.0, D2 - 30.0) if absf(wx) > 10.0 else D2 * 0.6
		for i in range(rng.randi_range(18, 40)):
			var x = wx + rnd(-28, 28)
			var z = wz + rnd(-20, 20)
			if absf(z) < D2 - 5.0 and not on_road(x, z) and not inside_any(x, z, 2.0):
				live_tree(x, z)
				if rng.randf() < 0.3:
					bush(x + rnd(-3, 3), z + rnd(-3, 3))
	for i in range(30):
		hedge_row(rnd(-W2 + 80.0, W2 - 80.0), rnd(-D2 + 10.0, D2 - 10.0), rnd(8, 22), rng.randf() < 0.5)
	for sx in [-1.0, 1.0]:
		for k in range(6):
			sandbags(objs[2].x + sx * 92.0, -D2 + 40.0 + k * 45.0, 4.0, false)
	for i in range(12):
		var x = rnd(-W2 + 90.0, W2 - 90.0)
		var z = rnd(-D2 + 15.0, D2 - 15.0)
		if not inside_any(x, z, 4.0):
			if rng.randf() < 0.5:
				tank(x, z)
			else:
				truck(x, z, rng.randf() < 0.5)
	_std_end("farm", objs, W2 - 40.0)

# a big indoor fight: a tank factory hall under a roof held up by pillars, offices, machines and storage racks
var lamps: Array = []
func build_factory() -> void:
	var W2 = TW / 2.0
	var D2 = TH_ / 2.0
	var HX = 80.0
	var HZ = 50.0
	var H = 8.0
	roads = [[-W2, -HX, -24.0, -16.0], [-W2, -HX, 16.0, 24.0], [HX, W2, -24.0, -16.0], [HX, W2, 16.0, 24.0]]
	flatten_rect(-W2 + 10.0, -D2 + 10.0, W2 - 10.0, D2 - 10.0, 6.0)
	for i in range(14):
		var hx = rnd(-W2, W2)
		var hz = D2 - rnd(2, 18) if rng.randf() < 0.5 else -D2 + rnd(2, 18)
		hill(hx, hz, rnd(10, 22), rnd(1.0, 3.0))
	build_terrain(MAPS["factory"]["ground"])
	for rd in roads:
		flat_plane((rd[0] + rd[1]) / 2.0, (rd[2] + rd[3]) / 2.0, rd[1] - rd[0], rd[3] - rd[2], Color(0.3, 0.3, 0.31), 0.015)
	var wc = Color(0.52, 0.47, 0.42)
	var t = 0.5
	var bld = {"x": 0.0, "z": 0.0, "w": HX * 2.0, "d": HZ * 2.0, "h": H + 1.0, "cols": [], "walls0": 0, "fallen": 0, "hall": true}
	buildings.append(bld)
	var c0 = cols.size()
	# long walls: four runs each with a door and high windows
	for e in [-1.0, 1.0]:
		for k in range(4):
			var a0 = -HX + k * 40.0
			wall_run(true, e * HZ, a0, a0 + 40.0, H, wc, t, true, 20.0)
	# end walls: two loading bays each
	for e in [-1.0, 1.0]:
		var x = e * HX
		wall_run(false, x, -HZ + t / 2.0, -24.0, H, wc, t, true)
		wall_run(false, x, -16.0, 16.0, H, wc, t, true, 16.0)
		wall_run(false, x, 24.0, HZ - t / 2.0, H, wc, t, true)
		for bz in [-20.0, 20.0]:
			_wall_piece(false, x, bz, 8.0, 4.6, H - 4.6, wc, t, "lintel")
			add_box(x + e * 0.4, 4.4, bz, 0.25, 0.25, 8.4, Color(0.75, 0.6, 0.15), {"collide": false})
	# concrete floor and painted walkways
	flat_plane(0, 0, HX * 2.0 - 0.6, HZ * 2.0 - 0.6, Color(0.5, 0.5, 0.48), 0.02)
	for zz in [-20.0, 20.0]:
		flat_plane(0, zz, HX * 2.0 - 1.0, 0.25, Color(0.78, 0.66, 0.2), 0.03)
		flat_plane(0, zz - 4.0, HX * 2.0 - 1.0, 0.25, Color(0.78, 0.66, 0.2), 0.03)
	# pillars every 20 m and the roof panels resting on them (a few already holed, letting the light in)
	for px in range(-3, 4):
		for pz in [-30.0, -10.0, 10.0, 30.0]:
			add_box(px * 20.0, 0.0, pz, 0.8, H, 0.8, Color(0.4, 0.4, 0.42), {"dest": true, "hp": 700.0})
	var holes = {}
	for i in range(8):
		holes[Vector2i(rng.randi_range(0, 7), rng.randi_range(1, 3))] = true
	for ix in range(8):
		for iz in range(5):
			if holes.has(Vector2i(ix, iz)):
				continue
			var cx = -HX + 10.0 + ix * 20.0
			var cz = -HZ + 10.0 + iz * 20.0
			add_box(cx, H, cz, 20.0, 0.45, 20.0, Color(0.33, 0.33, 0.34), {"dest": true, "hp": 520.0})
			add_box(cx, H + 0.45, cz, 19.6, 0.12, 19.6, Color(0.42, 0.3, 0.26), {"collide": false})
	for ix in range(9):
		add_box(-HX + ix * 20.0, H - 0.7, 0.0, 0.35, 0.7, HZ * 2.0 - 1.0, Color(0.36, 0.33, 0.3), {"collide": false})
	# offices in two corners: rooms with doors and glass
	var oc = Color(0.62, 0.6, 0.55)
	for e in [-1.0, 1.0]:
		var ox0 = -HX + 0.3 if e < 0 else HX - 36.3
		var oz = e * (HZ - 16.0)
		wall_run(true, oz, ox0, ox0 + 36.0, 3.4, oc, 0.3, true, 18.0)
		for k in range(1, 3):
			wall_run(false, ox0 + k * 12.0, minf(oz, e * HZ) + 0.2, maxf(oz, e * HZ) - 0.2, 3.4, oc, 0.3, true, 8.0)
		add_box(ox0 + 18.0, 3.4, (oz + e * HZ) / 2.0, 36.0, 0.3, 16.0, Color(0.5, 0.48, 0.45), {"dest": true, "hp": 220.0})
		for k in range(3):
			var dx = ox0 + 6.0 + k * 12.0
			add_box(dx, 0.0, oz + e * 6.0, 2.2, 0.8, 1.0, Color(0.38, 0.28, 0.2), {"dest": true, "hp": 60.0, "mat": 1})
	# machines: presses, furnaces, half-built hulls and conveyor lines
	var mc = [Color(0.3, 0.36, 0.3), Color(0.35, 0.35, 0.38), Color(0.42, 0.32, 0.22)]
	for i in range(10):
		var x = rnd(-HX + 12.0, HX - 12.0)
		var z = rnd(-HZ + 20.0, HZ - 20.0)
		if absf(z - 20.0) < 3.0 or absf(z + 20.0) < 3.0 or inside_any(x, z, 4.0):
			continue
		var c = mc[rng.randi() % mc.size()]
		var w = rnd(3.0, 5.0)
		var d = rnd(2.5, 4.0)
		var h = rnd(2.2, 4.2)
		add_box(x, 0.0, z, w, h, d, c, {"dest": true, "hp": 900.0})
		add_box(x, h, z, w * 0.6, 0.6, d * 0.6, c.darkened(0.2), {"collide": false})
		add_box(x + w * 0.3, h, z, 0.5, 2.5, 0.5, Color(0.25, 0.25, 0.25), {"shape": "cyl", "collide": false})
	for i in range(4):
		var x = rnd(-HX + 20.0, HX - 20.0)
		var z = [-8.0, 8.0, -36.0, 36.0][i]
		add_box(x, 0.0, z, 18.0, 0.9, 1.4, Color(0.25, 0.27, 0.28), {"dest": true, "hp": 500.0})
		for k in range(4):
			add_box(x - 7.5 + k * 5.0, 0.9, z, 1.6, 0.8, 1.2, Color(0.33, 0.35, 0.27), {"collide": false})
	for i in range(3):
		var x = -40.0 + i * 40.0 + rnd(-6, 6)
		tank(x, rnd(-4, 4) + (12.0 if i == 1 else -12.0))
	smoke_sources = []
	# storage racks
	for r in range(4):
		var x = 30.0 + r * 4.5
		add_box(x, 0.0, -28.0, 1.2, 3.8, 14.0, Color(0.27, 0.36, 0.5), {"dest": true, "hp": 260.0, "mat": 1})
		for k in range(5):
			crate(x, -34.0 + k * 3.0, 0.9)
	for r in range(4):
		var x = -45.0 - r * 4.5
		add_box(x, 0.0, 28.0, 1.2, 3.8, 14.0, Color(0.27, 0.36, 0.5), {"dest": true, "hp": 260.0, "mat": 1})
	for i in range(30):
		var x = rnd(-HX + 4.0, HX - 4.0)
		var z = rnd(-HZ + 4.0, HZ - 4.0)
		if not inside_any(x, z, 1.4):
			crate(x, z, rnd(0.8, 1.3))
	# catwalks along the long walls: a second level to shoot from, with stairs at one end
	_catwalk(1.0, -60.0, 40.0, HZ, true)
	_catwalk(-1.0, -40.0, 60.0, HZ, false)
	_claim(bld, c0)
	# hanging lamps (the sun barely gets in)
	lamps = []
	for lx in [-60.0, -20.0, 20.0, 60.0]:
		for lz in [-22.0, 22.0]:
			var l = OmniLight3D.new()
			l.omni_range = 34.0
			l.omni_attenuation = 0.45
			l.light_energy = 4.6
			l.light_color = Color(1.0, 0.86, 0.62)
			l.shadow_enabled = false
			_geo().add_child(l)
			l.position = Vector3(lx, ground_y(lx, lz) + H - 1.6, lz)
			lamps.append(l)
			add_box(lx, H - 1.6, lz, 1.0, 0.25, 1.0, Color(0.95, 0.85, 0.6), {"collide": false, "no_shadow": true})
	# outside: yards with trucks, fences and sandbags at the loading bays
	for e in [-1.0, 1.0]:
		for bz in [-20.0, 20.0]:
			sandbags(e * (HX + 10.0), bz + 6.0, 4.0, false)
			sandbags(e * (HX + 10.0), bz - 6.0, 4.0, false)
		for k in range(3):
			truck(e * (HX + 24.0 + k * 9.0), rnd(-40, -30) if k % 2 == 0 else rnd(30, 40), true)
	for i in range(30):
		var x = rnd(-W2 + 10.0, W2 - 10.0)
		var z = rnd(-D2 + 5.0, D2 - 5.0)
		if (absf(x) > HX + 6.0 or absf(z) > HZ + 6.0) and not on_road(x, z) and not inside_any(x, z, 2.0) and absf(x) < W2 - 50.0:
			live_tree(x, z)
	var objs = [Vector3(-50, 0, 0), Vector3(0, 0, 0), Vector3(50, 0, 0)]
	for o in objs:
		ammo_crate(o.x + 2.0, o.z + 4.0, -1)
	_std_end("urban", objs, W2 - 25.0)

# a raised steel walkway inside the factory's long wall (side e = +1 north, -1 south), x0..x1,
# reached by stairs beyond one end; it works like a tower's upper floor for the AI
func _catwalk(e: float, x0: float, x1: float, HZ: float, stairs_west: bool) -> void:
	var FY = 4.2
	var zin = e * (HZ - 0.3)
	var zout = e * (HZ - 3.0)
	var zc = (zin + zout) / 2.0
	var wd = absf(zin - zout)
	var steel = Color(0.33, 0.35, 0.37)
	var L = x1 - x0
	add_box((x0 + x1) / 2.0, FY - 0.25, zc, L, 0.25, wd, steel, {"dest": true, "hp": 320.0})
	# railing on the open side, posts underneath
	add_box((x0 + x1) / 2.0, FY, zout + e * 0.06, L, 1.0, 0.12, Color(0.75, 0.6, 0.15), {"dest": true, "hp": 160.0})
	var k = 0.0
	while k <= L + 0.01:
		add_box(x0 + k, 0.0, zout + e * 0.35, 0.3, FY - 0.25, 0.3, steel.darkened(0.2), {"dest": true, "hp": 260.0})
		k += 8.0
	# stairs
	var sb: float
	var st: float
	if stairs_west:
		sb = x0 - 8.0
		st = x0
	else:
		sb = x1 + 8.0
		st = x1
	var steps = 14
	for i in range(steps):
		var sh = (i + 1) * FY / steps
		var sx = sb + (st - sb) * (i + 0.5) / steps
		add_box(sx, sh - 0.2, zc, absf(st - sb) / steps, 0.2, wd, steel, {"collide": false})
	var ramp = StaticBody3D.new()
	ramp.collision_layer = G.L_WORLD
	ramp.collision_mask = 0
	var rcs = CollisionShape3D.new()
	var rb = BoxShape3D.new()
	rb.size = Vector3(Vector2(absf(st - sb), FY).length(), 0.2, wd)
	rcs.shape = rb
	ramp.add_child(rcs)
	var ang = atan2(FY, absf(st - sb)) * signf(st - sb)
	var gy = ground_y((sb + st) / 2.0, zc)
	_under_stairs(minf(sb, st), maxf(sb, st), zc - wd / 2.0, zc + wd / 2.0, gy, FY, signf(st - sb))
	ramp.transform = Transform3D(Basis(Vector3(0, 0, 1), ang), Vector3((sb + st) / 2.0, gy + FY / 2.0 - 0.1, zc))
	_geo().add_child(ramp)
	var xa = minf(sb, x0) - 0.5
	var xb = maxf(sb, x1) + 0.5
	var T = {"x": (xa + xb) / 2.0, "z": zc, "w": xb - xa, "d": wd + 1.0, "floor_y": FY, "posts": [], "cps": [],
		"rect": [xa, xb, minf(zin, zout) - 0.5, maxf(zin, zout) + 0.5],
		"floor_rects": [[x0, x1, minf(zin, zout), maxf(zin, zout)]],
		"stair_bottom": Vector3(sb - signf(st - sb) * 0.5, 0.0, zc), "stair_top": Vector3(st + signf(st - sb) * 0.8, FY, zc),
		"inside": Vector3(sb - signf(st - sb) * 0.5, 0.0, zc - e * 4.0)}
	var px = x0 + 3.0
	while px < x1 - 2.0:
		T["posts"].append([px, zout + e * 0.45, 0.0, e])
		px += 6.0
	towers.append(T)

# roads are flat painted strips, so the ground under them must be flat too (no hills or holes hidden under the paint)
func _flatten_roads() -> void:
	for rd in roads:
		flatten_rect(rd[0], rd[2], rd[1], rd[3], 2.5)

func near_road(x: float, z: float, r: float) -> bool:
	for rd in roads:
		if x > rd[0] - r and x < rd[1] + r and z > rd[2] - r and z < rd[3] + r:
			return true
	return false

func on_road(x: float, z: float) -> bool:
	for r in roads:
		if x > r[0] and x < r[1] and z > r[2] and z < r[3]:
			return true
	return false

static var grass_tex: ImageTexture = null

# a texture of tapered grass blades (white, tinted per instance)
static func _grass_texture() -> ImageTexture:
	if grass_tex != null:
		return grass_tex
	var W = 64
	var H = 64
	var img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var r = RandomNumberGenerator.new()
	r.seed = 77
	for k in range(14):
		var bx = r.randf_range(4, W - 4)
		var hgt = r.randf_range(0.45, 1.0) * H
		var lean = r.randf_range(-14, 14)
		var wid = r.randf_range(2.2, 3.6)
		for yy in range(int(hgt)):
			var t = float(yy) / hgt
			var cx = bx + lean * t * t
			var hw = wid * (1.0 - t) + 0.4
			var shade = 0.55 + 0.45 * t
			for xx in range(int(cx - hw), int(cx + hw) + 1):
				if xx >= 0 and xx < W:
					img.set_pixel(xx, H - 1 - yy, Color(shade, shade, shade * 0.9, 1.0))
	img.generate_mipmaps()
	grass_tex = ImageTexture.create_from_image(img)
	return grass_tex

# three crossed quads, normals pointing up so tufts light like the ground
static func _tuft_mesh(w: float, h: float) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(3):
		var a = i * PI / 3.0
		var dx = Vector3(cos(a), 0, sin(a)) * w * 0.5
		var p0 = -dx
		var p1 = dx
		var p2 = dx + Vector3(0, h, 0)
		var p3 = -dx + Vector3(0, h, 0)
		var uv = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		var ps = [p0, p1, p2, p3]
		for k in [0, 1, 2, 0, 2, 3, 0, 2, 1, 0, 3, 2]:
			st.set_normal(Vector3.UP)
			st.set_uv(uv[k])
			st.add_vertex(ps[k])
	return st.commit()

# ---------------------------------------------------------------- trampled grass
var grass_mm: MultiMesh = null
var grass_cells = {}
var grass_flat = PackedFloat32Array()     # when each tuft was pressed flat (0 = standing)
var grass_orig = []
var grass_bent: Array = []                 # tufts lying flat, to spring back up after a while

# tufts within r of p are pressed flat (by wheels, tracks, or a man lying in them); dir lays them over
func flatten_grass(p: Vector3, r: float, dir: Vector3 = Vector3.ZERO, keep: float = 240.0) -> void:
	if grass_mm == null:
		return
	var now = G.sim_time
	for cx in range(floori((p.x - r) / 4.0), floori((p.x + r) / 4.0) + 1):
		for cz in range(floori((p.z - r) / 4.0), floori((p.z + r) / 4.0) + 1):
			var ck = Vector2i(cx, cz)
			if not grass_cells.has(ck):
				continue
			for i in grass_cells[ck]:
				if grass_flat[i] > 0.0:
					continue
				var t: Transform3D = grass_orig[i]
				if Vector2(t.origin.x - p.x, t.origin.z - p.z).length_squared() > r * r:
					continue
				# pressed down and spread out, leaning the way it was pushed
				var lay = G.flat(dir).normalized() * 0.25 if dir.length_squared() > 0.01 else Vector3.ZERO
				var b = t.basis.scaled(Vector3(1.3, 0.18, 1.3))
				b.y += lay * t.basis.y.length() * 0.18
				grass_mm.set_instance_transform(i, Transform3D(b, t.origin + Vector3(0, 0.02, 0)))
				grass_flat[i] = now + keep
				grass_bent.append(i)

# trampled grass slowly stands up again (a few each call)
func grass_recover() -> void:
	if grass_bent.is_empty():
		return
	var now = G.sim_time
	var n = mini(30, grass_bent.size())
	for k in range(n):
		var i = grass_bent[0]
		if grass_flat[i] > now:
			break
		grass_bent.pop_front()
		grass_flat[i] = 0.0
		grass_mm.set_instance_transform(i, grass_orig[i])

func build_decor() -> void:
	# grass tufts
	var n = int(7000.0 * TW * TH_ / (260.0 * 190.0)) if G.settings["grass"] else 0
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _tuft_mesh(0.75, 0.55)
	mm.instance_count = n
	var k = 0
	var tries = 0
	var bush_spots = []
	while k < n and tries < n * 3:
		tries += 1
		var x = rnd(bounds.position.x, bounds.end.x)
		var z = rnd(bounds.position.y, bounds.end.y)
		var gy = ground_y(x, z)
		if on_road(x, z) or inside_any(x, z, 0.3) or gy < -0.4 or in_water(x, z) or not PAINT_GRASS[paint_at(x, z)]:
			continue
		var inb = false
		for b in buildings:
			if absf(x - b["x"]) < b["w"] / 2.0 + 0.5 and absf(z - b["z"]) < b["d"] / 2.0 + 0.5:
				inb = true
				break
		if inb:
			continue
		var sc = rnd(0.7, 1.5)
		var bs = Basis.from_euler(Vector3(rnd(-0.12, 0.12), rnd(0, 6), rnd(-0.12, 0.12))).scaled(Vector3(sc, sc * rnd(0.7, 1.3), sc))
		mm.set_instance_transform(k, Transform3D(bs, Vector3(x, gy - 0.04, z)))
		var col = Color.from_hsv(rnd(0.15, 0.22), rnd(0.35, 0.5), rnd(0.42, 0.58))
		if rng.randf() < 0.04:
			col = Color.from_hsv(rnd(0.13, 0.15), 0.38, 0.6)
		mm.set_instance_color(k, col)
		if k % 70 == 0:
			bush_spots.append(Vector3(x, gy, z))
		k += 1
	mm.visible_instance_count = k
	grass_mm = mm
	grass_cells = {}
	grass_flat = PackedFloat32Array()
	grass_flat.resize(k)
	grass_orig = []
	grass_orig.resize(k)
	for i in range(k):
		var gt: Transform3D = mm.get_instance_transform(i)
		grass_orig[i] = gt
		var ck = Vector2i(floori(gt.origin.x / 4.0), floori(gt.origin.z / 4.0))
		if not grass_cells.has(ck):
			grass_cells[ck] = PackedInt32Array()
		grass_cells[ck].append(i)
	var mi = MultiMeshInstance3D.new()
	mi.multimesh = mm
	var gm = StandardMaterial3D.new()
	gm.vertex_color_use_as_albedo = true
	gm.vertex_color_is_srgb = true
	gm.albedo_texture = _grass_texture()
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	gm.alpha_scissor_threshold = 0.5
	gm.roughness = 1.0
	mi.material_override = gm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_geo().add_child(mi)
	# rounded bushes and flowers among the grass
	var nb = 0
	var bm = MultiMesh.new()
	bm.transform_format = MultiMesh.TRANSFORM_3D
	bm.use_colors = true
	bm.mesh = shape_mesh("blob")
	bm.instance_count = bush_spots.size() * 3
	for sp in bush_spots:
		var bsz = rnd(0.6, 1.3)
		for j in range(3):
			var ss = bsz * rnd(0.6, 1.0)
			var off = Vector3(rnd(-0.5, 0.5), 0, rnd(-0.5, 0.5)) * bsz
			bm.set_instance_transform(nb, Transform3D(Basis.from_euler(Vector3(0, rnd(0, 3), 0)).scaled(Vector3(ss * 1.2, ss * 0.8, ss)), sp + off + Vector3(0, ss * 0.25, 0)))
			bm.set_instance_color(nb, Color.from_hsv(rnd(0.19, 0.26), rnd(0.4, 0.55), rnd(0.28, 0.4)))
			nb += 1
	var bmi = MultiMeshInstance3D.new()
	bmi.multimesh = bm
	var bmat = StandardMaterial3D.new()
	bmat.vertex_color_use_as_albedo = true
	bmat.vertex_color_is_srgb = true
	bmat.roughness = 1.0
	bmi.material_override = bmat
	_geo().add_child(bmi)
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
		_geo().add_child(ri)

func load_map(id: String) -> void:
	if not MAPS.has(id) and not (id == "custom" and not G.custom_map.is_empty()):
		id = "town"
	if geo_root:
		geo_root.queue_free()
	geo_root = Node3D.new()
	add_child(geo_root)
	openings = []; cols = []; grid = {}; groups = {}; cover = []; cover_grid = {}; terrain_cover = []; towers = []; roof_cols = []; wall_marks = []; smoke_sources = []; buildings = []; cut_now = {}; grass_mm = null; grass_bent = []; roads = []; ammo_points = []; water = []; water_mats = []; bridges = []
	paint = PackedByteArray()
	if id == "random":
		var rs = RandomNumberGenerator.new()
		rs.seed = G.random_seed
		MAPS["random"]["size"] = Vector2([300.0, 360.0, 480.0][rs.randi() % 3], [200.0, 240.0][rs.randi() % 2])
	var sz: Vector2 = MAPS.get(id, {}).get("size", Vector2(260, 190))
	if id == "custom":
		sz = G.custom_map["size"]
	# commander battles get more room: smaller maps grow outward, with farmland and woods round the edges
	var core = sz
	if G.mode == "commander" and id != "custom" and sz.x < 500.0:
		sz = Vector2(roundf(sz.x * 1.6), roundf(sz.y * 1.4))
	_set_size(sz.x, sz.y)
	objectives = []
	th = PackedFloat32Array()
	th.resize((TW + 1) * (TH_ + 1))
	th.fill(0.0)
	rng.seed = MAPS[id]["seed"] if MAPS.has(id) else 31337
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
	elif id == "river":
		build_river()
	elif id == "forest":
		build_forest()
	elif id == "city":
		build_city()
	elif id == "pass":
		build_pass()
	elif id == "beach":
		build_beach()
	elif id == "random":
		build_random(G.random_seed)
	elif id == "huge":
		build_huge()
	elif id == "factory":
		build_factory()
	elif id == "custom":
		build_custom(G.custom_map)
	else:
		build_trenches()
	if sz != core:
		_outskirts(core)
	if objectives.is_empty():
		objectives = [{"p": capture, "name": "A"}]
	# third and fourth teams get a small camp at the north and south edges
	for t in range(2, G.team_count()):
		var z = (bounds.position.y + 22.0) if t == 2 else (bounds.end.y - 22.0)
		var x = capture.x
		spawn.append(Vector3(x, 0, z))
		camp(t, spawn[t])
	static_cols = cols.duplicate()
	ruined_at_start = 0
	if Campaign.active and Campaign.current >= 0:
		for i in Campaign.ruins(Campaign.current):
			if i >= 0 and i < static_cols.size():
				ruin_col(static_cols[i])
				ruined_at_start += 1
	finalize_static()
	Doors.setup(self)
	build_nav()
	build_cover()
	build_decor()
	build_backdrop({"factory": "urban", "huge": "farm", "town": "urban", "field": "farm", "trenches": "war", "valley": "farm", "front": "war", "city": "urban", "river": "farm", "pass": "farm", "forest": "farm", "beach": "farm"}.get(id, "farm"))
	for s in smoke_sources:
		G.fx.wreck_smoke(s, geo_root)
