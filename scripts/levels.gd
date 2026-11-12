class_name Levels
extends RefCounted

# A building with real floors: every storey gets its own walking grid, joined by flights of stairs, so men
# can be sent anywhere on any floor and find their way there, up and down stairwells as they need to.
# The ground floor uses the map's own grid; the floors above are covered here.

static var on = false
static var rect = Rect2()           # the building's footprint (x, z)
static var gy = 0.0                 # its ground floor
static var FH = 3.6                 # storey height
static var n = 3                    # storeys
static var grids: Array = []        # [k] = AStarGrid2D for storey k (k >= 1)
static var X0 = 0.0
static var Z0 = 0.0
static var GW = 0
static var GH = 0
const CS = 0.5
static var stairs: Array = []       # {"k": lower storey, "a": foot (on k), "b": head (on k+1)}
static var bi = -1                  # the building's index, for the cutaway
static var view = -1                # storey shown with everything above it lifted off (-1: the whole building)
static var names = ["Ground floor", "First floor", "Second floor", "Third floor", "Fourth floor"]

static func reset() -> void:
	on = false
	grids = []
	stairs = []
	bi = -1
	view = -1

static func inside(p: Vector3, pad: float = 0.0) -> bool:
	return on and p.x > rect.position.x - pad and p.x < rect.end.x + pad and p.z > rect.position.y - pad and p.z < rect.end.y + pad

static func floor_y(k: int) -> float:
	return gy + k * FH

static func level_of(p: Vector3) -> int:
	if not inside(p, 0.6):
		return 0
	return clampi(int(floor((p.y - gy + 1.2) / FH)), 0, n - 1)

# which storey a point is meant to be on. Points worked out from the ground height (a step to the side,
# a spot near a flag) by a man upstairs usually mean "here, on my floor": keep them on his floor if it's
# a place he can stand there
static func target_level(from: Vector3, to: Vector3) -> int:
	if not inside(to, 0.3):
		return 0
	var lt = level_of(to)
	var lf = level_of(from)
	if lt == 0 and lf > 0 and absf(to.y - G.world.ground_y(to.x, to.z)) < 0.05 and G.dist2d(from, to) < 15.0 and walkable(lf, to):
		return lf
	return lt

static func cell(x: float, z: float) -> Vector2i:
	return Vector2i(clampi(int(floor((x - X0) / CS)), 0, GW - 1), clampi(int(floor((z - Z0) / CS)), 0, GH - 1))

static func cpos(c: Vector2i, k: int) -> Vector3:
	return Vector3(X0 + (c.x + 0.5) * CS, floor_y(k), Z0 + (c.y + 0.5) * CS)

static func walkable(k: int, p: Vector3) -> bool:
	if k <= 0:
		return not G.world.astar.is_point_solid(G.world.nav_cell(p.x, p.z))
	if k >= grids.size():
		return false
	return not grids[k].is_point_solid(cell(p.x, p.z))

# ---------------------------------------------------------------- building the grids
static func build() -> void:
	X0 = rect.position.x
	Z0 = rect.position.y
	GW = int(ceil(rect.size.x / CS))
	GH = int(ceil(rect.size.y / CS))
	grids = [null]
	for k in range(1, n):
		var g = AStarGrid2D.new()
		g.region = Rect2i(0, 0, GW, GH)
		g.cell_size = Vector2(1, 1)
		g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		g.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		g.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		g.update()
		grids.append(g)
		mark(k, rect.position.x, rect.position.y, rect.end.x, rect.end.y)

# re-mark one patch of a storey (after a wall comes down)
static func update_area(x0: float, z0: float, x1: float, z1: float) -> void:
	if not on:
		return
	for k in range(1, n):
		mark(k, x0 - 1.0, z0 - 1.0, x1 + 1.0, z1 + 1.0)

static func mark(k: int, x0: float, z0: float, x1: float, z1: float) -> void:
	var g: AStarGrid2D = grids[k]
	var W = G.world
	var ly = floor_y(k)
	var a = cell(x0, z0)
	var b = cell(x1, z1)
	for iz in range(a.y, b.y + 1):
		for ix in range(a.x, b.x + 1):
			var p = cpos(Vector2i(ix, iz), k)
			g.set_point_solid(Vector2i(ix, iz), not _floor_under(p.x, p.z, ly))
			g.set_point_weight_scale(Vector2i(ix, iz), 1.0)
	var r = 0.3
	for c in W.cols_in_rect(x0 - 1.0, z0 - 1.0, x1 + 1.0, z1 + 1.0):
		if not c.alive or not W.blocks_at(c, ly):
			continue
		var c0 = cell(c.lo.x - r, c.lo.z - r)
		var c1 = cell(c.hi.x + r, c.hi.z + r)
		var low = c.hi.y - ly < 1.15 and c.lo.y < ly + 0.3 and minf(c.hi.x - c.lo.x, c.hi.z - c.lo.z) < 1.0
		for iz in range(maxi(c0.y, a.y), mini(c1.y, b.y) + 1):
			for ix in range(maxi(c0.x, a.x), mini(c1.x, b.x) + 1):
				var q = Vector2i(ix, iz)
				if low:
					if not g.is_point_solid(q):
						g.set_point_weight_scale(q, 4.0)
				else:
					g.set_point_solid(q, true)

# a slab, landing or floor whose top is at this height under this spot (well in from its edges, so
# nobody is sent to stand on the lip of a stairwell)
static func _floor_under(x: float, z: float, ly: float) -> bool:
	for c in G.world.cell_at(x, z):
		if not c.alive or c.hi.y - c.lo.y > 0.7 or absf(c.hi.y - ly) > 0.15:
			continue
		if x > c.lo.x + 0.2 and x < c.hi.x - 0.2 and z > c.lo.z + 0.2 and z < c.hi.z - 0.2:
			return true
	return false

# ---------------------------------------------------------------- finding the way
static func _nearest(g: AStarGrid2D, c: Vector2i) -> Vector2i:
	if not g.is_point_solid(c):
		return c
	for r in range(1, 10):
		var best = Vector2i(-1, -1)
		var bd = 1e9
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dz) != r:
					continue
				var q = Vector2i(c.x + dx, c.y + dz)
				if q.x < 0 or q.y < 0 or q.x >= GW or q.y >= GH or g.is_point_solid(q):
					continue
				var d = dx * dx + dz * dz
				if d < bd:
					bd = d
					best = q
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)

static func _line(g: AStarGrid2D, a: Vector2i, b: Vector2i) -> bool:
	var d = Vector2(b - a)
	var m = int(ceil(d.length() * 2.0))
	for i in range(1, m + 1):
		var t = float(i) / m
		var p = Vector2i(roundi(a.x + d.x * t), roundi(a.y + d.y * t))
		if g.is_point_solid(p) or g.get_point_weight_scale(p) > 1.5:
			return false
	return true

# a path on one storey
static func flat_path(k: int, from: Vector3, to: Vector3) -> Array:
	if k <= 0:
		var gp = G.world.find_path(from, to)
		return gp
	var g: AStarGrid2D = grids[k]
	var s = _nearest(g, cell(from.x, from.z))
	var t = _nearest(g, cell(to.x, to.z))
	if s.x < 0 or t.x < 0:
		return []
	var ids: Array = g.get_id_path(s, t, true)
	if ids.is_empty():
		return []
	var out: Array = []
	var i = 0
	while i < ids.size() - 1:
		var j = mini(ids.size() - 1, i + 30)
		while j > i + 1 and not _line(g, ids[i], ids[j]):
			j -= 2 if j - 2 > i else 1
		out.append(cpos(ids[j], k))
		i = j
	if out.is_empty():
		out.append(cpos(ids[ids.size() - 1], k))
	for i2 in range(out.size() - 1):
		out[i2] = _off_walls(g, out[i2])
	if ids[ids.size() - 1] == t and not g.is_point_solid(cell(to.x, to.z)):
		out[out.size() - 1] = Vector3(to.x, floor_y(k), to.z)
	return out

static func _off_walls(g: AStarGrid2D, p: Vector3) -> Vector3:
	var c = cell(p.x, p.z)
	var push = Vector2.ZERO
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			if dx == 0 and dz == 0:
				continue
			var q = Vector2i(c.x + dx, c.y + dz)
			if q.x < 0 or q.y < 0 or q.x >= GW or q.y >= GH:
				continue
			if g.is_point_solid(q):
				push -= Vector2(dx, dz) / float(dx * dx + dz * dz)
	if push.length_squared() < 0.01:
		return p
	push = push.normalized() * 0.4
	var np = Vector3(p.x + push.x, p.y, p.z + push.y)
	if g.is_point_solid(cell(np.x, np.z)):
		return p
	return np

# how many men are on each flight of stairs (a busy flight costs more, so a squad spreads over the stairwells)
static var busy_t = 0.0
static func step(dt: float) -> void:
	if not on:
		return
	busy_t -= dt
	if busy_t > 0.0:
		return
	busy_t = 1.0
	for st in stairs:
		st["busy"] = 0
		var a: Vector3 = st["a"]
		var b: Vector3 = st["b"]
		for s in G.soldiers:
			if s.state == "alive" and s.pos.y > a.y + 0.3 and s.pos.y < b.y - 0.1 and absf(s.pos.x - a.x) < 1.6 and s.pos.z > minf(a.z, b.z) - 1.0 and s.pos.z < maxf(a.z, b.z) + 1.0:
				st["busy"] += 1

# the whole way, floor to floor, by whichever stairs make the trip shortest
static func path(from: Vector3, to: Vector3) -> Array:
	var lf = level_of(from)
	var lt = target_level(from, to)
	if lf == lt:
		return flat_path(lf, from, to)
	var out: Array = []
	var cur = from
	var k = lf
	var guard = 0
	while k != lt and guard < 8:
		guard += 1
		var up = lt > k
		var best = null
		var bs = 1e9
		for st in stairs:
			if (up and st["k"] == k) or (not up and st["k"] == k - 1):
				var a: Vector3 = st["a"] if up else st["b"]
				var b: Vector3 = st["b"] if up else st["a"]
				var sc = G.dist2d(cur, a) + G.dist2d(b, to) * 0.8 + float(st.get("busy", 0)) * 4.0
				if sc < bs:
					bs = sc
					best = st
		if best == null:
			break
		var a2: Vector3 = best["a"] if up else best["b"]
		var b2: Vector3 = best["b"] if up else best["a"]
		var leg = flat_path(k, cur, a2)
		out.append_array(leg)
		if leg.is_empty() or G.dist2d(leg[leg.size() - 1], a2) > 0.3:
			out.append(a2)
		out.append(b2)
		cur = b2
		k += 1 if up else -1
	var last_leg = flat_path(k, cur, to)
	out.append_array(last_leg)
	if out.is_empty():
		out.append(to)
	return out

# the nearest open floor on his own storey (for a man wedged in a corner upstairs)
static func free_near(p: Vector3) -> Vector3:
	var k = level_of(p)
	if k <= 0:
		return G.world.nav_pos(G.world._nearest_free(G.world.nav_cell(p.x, p.z)))
	var c = _nearest(grids[k], cell(p.x, p.z))
	if c.x < 0:
		return p
	return cpos(c, k)

# a random open spot on a storey, near a point
static func spot_on(k: int, near: Vector3, r: float) -> Vector3:
	for i in range(16):
		var a = randf() * TAU
		var q = near + Vector3(cos(a), 0, sin(a)) * randf_range(0.0, r)
		q.y = floor_y(k)
		if inside(q, -1.0) and walkable(k, q):
			return q
	var c = _nearest(grids[k], cell(near.x, near.z)) if k > 0 else G.world._nearest_free(G.world.nav_cell(near.x, near.z))
	if c.x < 0:
		return Vector3(near.x, floor_y(k), near.z)
	return cpos(c, k) if k > 0 else G.world.nav_pos(c)
