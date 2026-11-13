class_name Office
extends RefCounted

# "Ministry": a three-storey office block in a walled yard. A long corridor runs the length of every floor,
# three cross corridors cut through it, and the wings either side are rooms behind rooms: front offices
# off the corridor, back offices along the outside wall, doors between them. Four stairwells (two near
# each end, two near the middle, set so both sides have the same) join the floors. The fight is inside.

const HX = 50.0          # half length (x)
const HZ = 22.0          # half depth (z)
const CORR = 2.0         # main corridor half width
const MIDZ = 12.0        # wall between front and back offices
const CROSS = [-26.0, 0.0, 26.0]
const CW = 1.5           # cross corridor half width
const FH = 3.6
const NL = 3
const T_OUT = 0.4
const T_IN = 0.3

static var w = null
static var doors_at = {}     # wall key -> [[c, half width], ...] so furniture keeps out of doorways

static func build(world) -> void:
	w = world
	doors_at = {}
	var W2 = w.TW / 2.0
	var D2 = w.TH_ / 2.0
	w.flatten_rect(-W2 + 8.0, -D2 + 8.0, W2 - 8.0, D2 - 8.0, 6.0)
	for i in range(10):
		var hz = D2 - w.rnd(2, 14) if w.rng.randf() < 0.5 else -D2 + w.rnd(2, 14)
		w.hill(w.rnd(-W2, W2), hz, w.rnd(10, 20), w.rnd(0.8, 2.2))
	w.roads = [[-W2, -HX - 4.0, -2.5, 2.5], [HX + 4.0, W2, -2.5, 2.5]]
	w.build_terrain(w.MAPS["office"]["ground"])
	for rd in w.roads:
		w.flat_plane((rd[0] + rd[1]) / 2.0, (rd[2] + rd[3]) / 2.0, rd[1] - rd[0], rd[3] - rd[2], Color(0.3, 0.3, 0.31), 0.015)
	var gy0 = w.ground_y(0, 0)
	Levels.reset()
	Levels.on = true
	Levels.rect = Rect2(-HX, -HZ, HX * 2.0, HZ * 2.0)
	Levels.gy = gy0
	Levels.FH = FH
	Levels.n = NL
	var bld = {"x": 0.0, "z": 0.0, "w": HX * 2.0, "d": HZ * 2.0, "h": FH * NL + 1.2, "cols": [], "walls0": 0, "fallen": 0, "hall": true, "office": true}
	w.buildings.append(bld)
	Levels.bi = w.buildings.size() - 1
	# the ground floor's finish: polished stone, with a runner down the corridor
	w.flat_plane(0, 0, HX * 2.0 - 0.6, HZ * 2.0 - 0.6, Color(0.55, 0.53, 0.5), 0.02)
	w.flat_plane(0, 0, HX * 2.0 - 1.0, CORR * 2.0 - 0.4, Color(0.42, 0.24, 0.2), 0.03)
	# stairwells: front-office slots in the outer column of a wing, and one each side of the middle,
	# laid out so the building is the same from either end (turned half round)
	var wells = [
		{"col": _col(0, 2), "sz": 1.0, "sx": 1.0},     # west wing, north side
		{"col": _col(3, 0), "sz": -1.0, "sx": -1.0},   # east wing, south side (the same, turned round)
		{"col": _col(1, 2), "sz": -1.0, "sx": 1.0},    # west of the middle, south side
		{"col": _col(2, 0), "sz": 1.0, "sx": -1.0},    # east of the middle, north side
	]
	var holes = []      # [k] -> rects of open floor
	for k in range(NL + 1):
		holes.append([])
	for wl in wells:
		_stairwell(wl, holes)
	Rooms.reset()
	for k in range(NL):
		_storey(k, wells)
	Rooms.link()
	# floors and the roof
	var fcol = [Color(0.55, 0.53, 0.5), Color(0.47, 0.36, 0.26), Color(0.4, 0.43, 0.47), Color(0.35, 0.35, 0.36)]
	for k in range(1, NL + 1):
		for r in _cut_holes([-HX, HX, -HZ, HZ], holes[k]):
			w.add_box((r[0] + r[1]) / 2.0, k * FH - 0.3, (r[2] + r[3]) / 2.0, r[1] - r[0], 0.3, r[3] - r[2], fcol[k] if k < NL else Color(0.38, 0.38, 0.39), {"dest": false, "lit": 0.34} if k < NL else {"dest": false})
		if k < NL:
			w.add_box(0, k * FH + 0.01, 0, HX * 2.0 - 1.0, 0.02, CORR * 2.0 - 0.4, [Color(0.42, 0.24, 0.2), Color(0.25, 0.32, 0.25), Color(0.24, 0.27, 0.36)][k], {"collide": false, "lit": 0.7})
	# the outside: a band at each floor, a parapet and plant on the roof
	var oc = Color(0.62, 0.55, 0.47)
	for k in range(1, NL + 1):
		for e in [-1.0, 1.0]:
			w.add_box(0, k * FH - 0.35, e * (HZ + 0.12), HX * 2.0 + 0.6, 0.35, 0.3, oc.lightened(0.15), {"collide": false})
			w.add_box(e * (HX + 0.12), k * FH - 0.35, 0, 0.3, 0.35, HZ * 2.0 + 0.6, oc.lightened(0.15), {"collide": false})
	for e in [-1.0, 1.0]:
		w.add_box(0, NL * FH, e * (HZ - 0.2), HX * 2.0, 1.0, 0.4, oc, {"dest": false})
		w.add_box(e * (HX - 0.2), NL * FH, 0, 0.4, 1.0, HZ * 2.0 - 0.8, oc, {"dest": false})
	for i in range(6):
		w.add_box(w.rnd(-HX + 6.0, HX - 6.0), NL * FH, w.rnd(-HZ + 5.0, HZ - 5.0), w.rnd(2.0, 4.0), w.rnd(1.0, 1.8), w.rnd(1.5, 3.0), Color(0.5, 0.5, 0.48), {"collide": false})
	# the yard: a wall round it with gates, parked cars, sandbags at the doors
	_yard(W2, D2)
	# flags: one in each wing and one in the middle, each on a different floor
	var objs = [Vector3(-38.0, 0, -6.0), Vector3(0.0, 0, 7.0), Vector3(38.0, 0, 6.0)]
	w.objectives = []
	var lvs = [1, 2, 1]
	var nm = "ABC"
	for i in range(3):
		w.objectives.append({"p": objs[i], "name": nm[i], "lv": lvs[i]})
	w.capture = objs[1]
	var sp = W2 - 16.0
	w.spawn = [Vector3(-sp, 0, 0), Vector3(sp, 0, 0)]
	for sx in [-1.0, 1.0]:
		w.base(sx, sp)
	for o in [Vector3(-HX - 8.0, 0, 6.0), Vector3(HX + 8.0, 0, -6.0)]:
		w.ammo_crate(o.x, o.z, -1)

# x range of column c (0..2) of wing b (0..3)
static func _col(b: int, c: int) -> Array:
	var edges = [-HX, CROSS[0] - CW, CROSS[0] + CW, CROSS[1] - CW, CROSS[1] + CW, CROSS[2] - CW, CROSS[2] + CW, HX]
	var x0 = edges[b * 2]
	var x1 = edges[b * 2 + 1]
	var cw = (x1 - x0) / 3.0
	return [x0 + c * cw, x0 + (c + 1) * cw]

static func _is_well(wells: Array, x0: float, x1: float, sz: float) -> Dictionary:
	for wl in wells:
		if absf(wl["col"][0] - x0) < 0.01 and absf(wl["col"][1] - x1) < 0.01 and wl["sz"] == sz:
			return wl
	return {}

# ---------------------------------------------------------------- walls
# a wall along x (horiz) or z on storey k with gaps: [centre, width, "door"|"win"|"open"]
static func _wall(horiz: bool, fixed: float, a0: float, a1: float, k: int, color: Color, t: float, gaps: Array, hp: float, key: String = "") -> void:
	var y0 = k * FH
	var h = FH - 0.3
	gaps.sort_custom(func(p, q): return p[0] < q[0])
	if key != "":
		var lst = []
		for gp in gaps:
			if gp[2] == "door" or gp[2] == "open":
				lst.append([gp[0], gp[1] / 2.0 + 0.9])
		doors_at[key] = lst
	var cur = a0
	for gp in gaps:
		var g0 = clampf(gp[0] - gp[1] / 2.0, a0, a1)
		var g1 = clampf(gp[0] + gp[1] / 2.0, a0, a1)
		_solid(horiz, fixed, cur, g0, y0, 0.0, h, color, t, hp)
		match gp[2]:
			"door":
				_solid(horiz, fixed, g0, g1, y0, 2.3, h - 2.3, color, t, hp)
				_frame(horiz, fixed, g0, g1, y0, t)
				if horiz:
					Rooms.add_door(k, true, (g0 + g1) / 2.0, fixed)
				else:
					Rooms.add_door(k, false, fixed, (g0 + g1) / 2.0)
			"win":
				_solid(horiz, fixed, g0, g1, y0, 0.0, 1.0, color, t, hp)
				_solid(horiz, fixed, g0, g1, y0, 2.2, h - 2.2, color, t, hp)
				_sill(horiz, fixed, g0, g1, y0 + 1.0, t, color.lightened(0.25))
			"open":
				_solid(horiz, fixed, g0, g1, y0, 2.6, h - 2.6, color, t, hp)
		cur = g1
	_solid(horiz, fixed, cur, a1, y0, 0.0, h, color, t, hp)

# a solid stretch, in pieces of up to 3 m (so a blast takes out a piece, not the whole wall)
static func _solid(horiz: bool, fixed: float, a: float, b: float, y0: float, dy: float, h: float, color: Color, t: float, hp: float) -> void:
	var L = b - a
	if L < 0.05 or h < 0.05:
		return
	var n = maxi(1, int(ceil(L / 3.0)))
	for i in range(n):
		var c = a + (i + 0.5) * L / n
		# (the building itself can't be knocked down: its walls, floors and roof stand whatever lands on
		# them, so the fight for it happens inside it; the furniture and barricades still break)
		# (inside walls are lit: the corridor ones more than the partitions between offices)
		var o2 = {"dest": false, "hp": hp}
		if t < T_OUT:
			o2["lit"] = 0.42
		if horiz:
			w.add_box(c, y0 + dy, fixed, L / n, h, t, color, o2)
		else:
			w.add_box(fixed, y0 + dy, c, t, h, L / n, color, o2)

static func _frame(horiz: bool, fixed: float, g0: float, g1: float, y0: float, t: float) -> void:
	var fc = Color(0.36, 0.27, 0.18)
	for e in [g0 + 0.05, g1 - 0.05]:
		if horiz:
			w.add_box(e, y0, fixed, 0.1, 2.3, t + 0.1, fc, {"collide": false, "lit": 0.7})
		else:
			w.add_box(fixed, y0, e, t + 0.1, 2.3, 0.1, fc, {"collide": false, "lit": 0.7})

static func _sill(horiz: bool, fixed: float, g0: float, g1: float, y: float, t: float, c: Color) -> void:
	if horiz:
		w.add_box((g0 + g1) / 2.0, y - 0.06, fixed, g1 - g0 + 0.1, 0.08, t + 0.2, c, {"collide": false})
	else:
		w.add_box(fixed, y - 0.06, (g0 + g1) / 2.0, t + 0.2, 0.08, g1 - g0 + 0.1, c, {"collide": false})

static func _rnd_door(a0: float, a1: float) -> float:
	return w.rnd(a0 + 1.4, a1 - 1.4) if a1 - a0 > 3.2 else (a0 + a1) / 2.0

# ---------------------------------------------------------------- one storey
static func _storey(k: int, wells: Array) -> void:
	var out_c = Color(0.62, 0.55, 0.47)
	# the corridors are lit and the offices aren't: paler walls out here, dimmer ones in the rooms
	var corr_c: Color = [Color(0.78, 0.74, 0.64), Color(0.72, 0.76, 0.7), Color(0.7, 0.72, 0.78)][k].lightened(0.1)
	var room_c = [Color(0.74, 0.7, 0.6), Color(0.7, 0.68, 0.6), Color(0.68, 0.68, 0.66), Color(0.76, 0.72, 0.66)].map(func(c): return c.darkened(0.24))
	# outside walls: windows all along; on the ground floor, doors at the ends of the corridors
	for e in [-1.0, 1.0]:
		var gaps = []
		var x = -HX + 1.5
		while x < HX - 1.0:
			var near_cross = false
			for cx in CROSS:
				if absf(x - cx) < 2.2:
					near_cross = true
			if not near_cross:
				gaps.append([x, 1.4, "win"])
			x += 3.0
		for cx in CROSS:
			gaps.append([cx, 2.6, "open" if k == 0 else "win"])
		for gp in gaps:
			_window_light(k, true, e * HZ, gp[0], gp[1], -e)
		_wall(true, e * HZ, -HX, HX, k, out_c, T_OUT, gaps, 420.0)
		var eg = [[-9.0, 1.4, "win"], [-15.0, 1.4, "win"], [9.0, 1.4, "win"], [15.0, 1.4, "win"], [0.0, 2.8, "open" if k == 0 else "win"]]
		for gp in eg:
			_window_light(k, false, e * HX, gp[0], gp[1], -e)
		_wall(false, e * HX, -HZ + T_OUT / 2.0, HZ - T_OUT / 2.0, k, out_c, T_OUT, eg, 420.0)
	# the main corridor's walls, wing by wing, a door into every front office
	for b in range(4):
		var bx = [_col(b, 0)[0], _col(b, 2)[1]]
		for sz in [-1.0, 1.0]:
			var gaps = []
			for c in range(3):
				var cr = _col(b, c)
				var wl = _is_well(wells, cr[0], cr[1], sz)
				if not wl.is_empty():
					gaps.append([(cr[0] + cr[1]) / 2.0, 1.6, "door"])
				else:
					gaps.append([_rnd_door(cr[0], cr[1]), 1.4, "door"])
			_wall(true, sz * CORR, bx[0], bx[1], k, corr_c, T_IN, gaps, 240.0, "c%d_%d_%d" % [k, b, int(sz)])
	# the cross corridors' walls: doors into the offices either side
	for cx in CROSS:
		for e in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var z0 = minf(sz * CORR, sz * HZ) + (0.15 if sz > 0 else 0.2)
				var z1 = maxf(sz * CORR, sz * HZ) - (0.2 if sz > 0 else 0.15)
				var gaps = []
				var wx = cx + e * CW
				var b = CROSS.find(cx) + (1 if e > 0 else 0)
				var c = 0 if e > 0 else 2
				var cr = _col(b, c)
				var front_well = not _is_well(wells, cr[0], cr[1], sz).is_empty()
				if not front_well and w.rng.randf() < 0.75:
					gaps.append([sz * (CORR + MIDZ) / 2.0 + w.rnd(-2.0, 2.0), 1.4, "door"])
				if w.rng.randf() < 0.8:
					gaps.append([sz * (MIDZ + HZ) / 2.0 + w.rnd(-2.0, 2.0), 1.4, "door"])
				_wall(false, wx, z0, z1, k, corr_c, T_IN, gaps, 240.0)
	# inside the wings: front offices off the corridor, back offices along the outside, doors between
	for b in range(4):
		for sz in [-1.0, 1.0]:
			var col_c: Color = room_c[(b + (1 if sz > 0 else 0) + k) % room_c.size()]
			for c in range(3):
				var cr = _col(b, c)
				var wl = _is_well(wells, cr[0], cr[1], sz)
				# the wall between front and back office
				var gaps = []
				if not wl.is_empty():
					var u_aisle = cr[1] - 0.9 if wl["sx"] > 0 else cr[0] + 0.9
					gaps.append([u_aisle, 1.2, "door"])
				elif w.rng.randf() < 0.8:
					gaps.append([_rnd_door(cr[0], cr[1]), 1.4, "door"])
				_wall(true, sz * MIDZ, cr[0] + 0.15, cr[1] - 0.15, k, col_c, T_IN, gaps, 220.0, "m%d_%d_%d_%d" % [k, b, c, int(sz)])
				# partitions between columns (not at the wing's ends: those are cross corridor or outside walls)
				if c < 2:
					var xw = cr[1]
					var nxt = _col(b, c + 1)
					var gp2 = []
					var lw = _is_well(wells, cr[0], cr[1], sz)
					var rw = _is_well(wells, nxt[0], nxt[1], sz)
					if lw.is_empty() and rw.is_empty() and w.rng.randf() < 0.55:
						gp2.append([sz * (CORR + MIDZ) / 2.0 + w.rnd(-2.5, 2.5), 1.3, "door"])
					if w.rng.randf() < 0.6:
						gp2.append([sz * (MIDZ + HZ) / 2.0 + w.rnd(-3.0, 3.0), 1.3, "door"])
					var za = minf(sz * CORR, sz * HZ) + 0.15
					var zb = maxf(sz * CORR, sz * HZ) - 0.15
					_wall(false, xw, za, zb, k, col_c, T_IN, gp2, 220.0)
				if wl.is_empty():
					_furnish(k, cr[0], cr[1], sz * CORR, sz * MIDZ, sz, true)
					Rooms.add_room(k, cr[0], cr[1], sz * CORR, sz * MIDZ)
					_room_shade(k, cr[0], cr[1], sz * CORR, sz * MIDZ, 0.5)
				_furnish(k, cr[0], cr[1], sz * MIDZ, sz * HZ, sz, false)
				Rooms.add_room(k, cr[0], cr[1], sz * MIDZ, sz * HZ)
				_room_shade(k, cr[0], cr[1], sz * MIDZ, sz * HZ, 0.36)
	_corridor_lamps(k)
	# corridor barricades at the crossings (staggered, so there's always a way past)
	for cx in CROSS:
		if w.rng.randf() < 0.65:
			var e = 1.0 if w.rng.randf() < 0.5 else -1.0
			var side = 1.0 if w.rng.randf() < 0.5 else -1.0
			w.add_box(cx + e * 4.5, k * FH, side * 0.85, 0.7, 0.9, 2.1, Color(0.6, 0.55, 0.4), {"dest": true, "hp": 260.0, "shape": "pillow"})
	for i in range(3):
		if true:
			var x = w.rnd(-HX + 4.0, HX - 4.0)
			var near = false
			for cx in CROSS:
				if absf(x - cx) < 4.0:
					near = true
			if not near:
				var e2 = 1.0 if w.rng.randf() < 0.5 else -1.0
				w.add_box(x, k * FH, e2 * 1.1, 1.6, 0.8, 0.75, Color(0.4, 0.3, 0.22), {"dest": true, "hp": 90.0, "mat": 1, "lit": 0.7})
	# a sign at each stairwell door: which floor this is
	for wl in wells:
		var cr: Array = wl["col"]
		var x = (cr[0] + cr[1]) / 2.0 + 1.3
		var sc = [Color(0.85, 0.75, 0.3), Color(0.35, 0.7, 0.4), Color(0.35, 0.55, 0.85)][k]
		w.add_box(x, k * FH + 2.0, wl["sz"] * (CORR - 0.18), 0.6, 0.45, 0.04, sc, {"collide": false, "no_shadow": true})

# ---------------------------------------------------------------- light and shade indoors
# (painted on rather than lit: it costs nothing to draw, and it goes away with its floor in the cutaway view)
const FLOOR_C = [Color(0.55, 0.53, 0.5), Color(0.47, 0.36, 0.26), Color(0.4, 0.43, 0.47)]

# an office is dimmer than the corridor outside it (the inner ones, with no window of their own, dimmest)
static func _room_shade(k: int, x0: float, x1: float, za: float, zb: float, dark: float) -> void:
	var z0 = minf(za, zb)
	var z1 = maxf(za, zb)
	w.add_box((x0 + x1) / 2.0, k * FH + 0.01, (z0 + z1) / 2.0, x1 - x0 - 0.32, 0.02, z1 - z0 - 0.32, FLOOR_C[k].darkened(dark), {"collide": false, "no_shadow": true, "lit": 0.85})

# daylight through a window in an outside wall: a pale wash on the floor under it, and on the sunny side
# of the building a bright patch where the sun itself comes in, thrown across the floor at the sun's angle
static func _window_light(k: int, horiz: bool, fixed: float, c: float, wd: float, inward: float) -> void:
	var n = Vector3(0, 0, inward) if horiz else Vector3(inward, 0, 0)
	var t = Vector3(1, 0, 0) if horiz else Vector3(0, 0, 1)
	var at = (Vector3(c, 0, fixed) if horiz else Vector3(fixed, 0, c)) + n * (T_OUT / 2.0)
	var y = k * FH + 0.031
	var soft = FLOOR_C[k].darkened(0.12)
	var p = at + n * 1.0
	w.add_box(p.x, y, p.z, (wd + 0.3) if horiz else 2.0, 0.014, 2.0 if horiz else (wd + 0.3), soft, {"collide": false, "no_shadow": true, "glow": true})
	var sd: Vector3 = Basis.from_euler(Vector3(deg_to_rad(-52.0), deg_to_rad(-35.0), 0.0)) * Vector3(0, 0, -1)
	var inn = sd.dot(n)
	if inn < 0.12 or sd.y > -0.2:
		return
	# the sill is a metre up and the top of the window 2.2: where those heights land on the floor
	var d0 = inn * 1.0 / -sd.y
	var d1 = inn * 2.2 / -sd.y
	var sh = sd.dot(t) * 1.6 / -sd.y
	var q = at + n * ((d0 + d1) / 2.0) + t * sh
	var dep = maxf(0.4, d1 - d0)
	var sun_c = Color(1.0, 0.95, 0.8).lerp(FLOOR_C[k], 0.45)
	w.add_box(q.x, y + 0.015, q.z, wd if horiz else dep, 0.014, dep if horiz else wd, sun_c, {"collide": false, "no_shadow": true, "glow": true})

# lamps down the middle of every corridor ceiling, and the pool of light under each on the floor
static func _corridor_lamps(k: int) -> void:
	var lamp = Color(1.0, 0.97, 0.82)
	var run_c: Color = [Color(0.42, 0.24, 0.2), Color(0.25, 0.32, 0.25), Color(0.24, 0.27, 0.36)][k]
	var pool = run_c.lerp(Color(0.9, 0.82, 0.6), 0.25)
	var x = -HX + 4.5
	while x < HX - 3.0:
		w.add_box(x, k * FH + FH - 0.38, 0, 1.3, 0.07, 0.28, lamp, {"collide": false, "no_shadow": true, "glow": true})
		w.add_box(x, k * FH + 0.031, 0, 3.0, 0.014, CORR * 2.0 - 0.5, pool.darkened(0.25), {"collide": false, "no_shadow": true, "glow": true})
		w.add_box(x, k * FH + 0.046, 0, 1.5, 0.012, CORR * 2.0 - 1.4, pool, {"collide": false, "no_shadow": true, "glow": true})
		x += 7.0
	for cx in CROSS:
		for z in [-17.0, -9.5, 9.5, 17.0]:
			w.add_box(cx, k * FH + FH - 0.38, z, 0.28, 0.07, 1.3, lamp, {"collide": false, "no_shadow": true, "glow": true})
			w.add_box(cx, k * FH + 0.031, z, CW * 2.0 - 0.5, 0.014, 2.6, FLOOR_C[k].lerp(Color(0.9, 0.82, 0.6), 0.2).darkened(0.3), {"collide": false, "no_shadow": true, "glow": true})

# desks, chairs, cabinets and shelves in one office, kept out of the doorways
static func _furnish(k: int, x0: float, x1: float, za: float, zb: float, sz: float, front: bool) -> void:
	var z0 = minf(za, zb) + 0.15
	var z1 = maxf(za, zb) - 0.15
	var y = k * FH
	var desk = Color(0.42, 0.3, 0.2)
	var metal = Color(0.38, 0.4, 0.42)
	var nd = w.rng.randi_range(1, 3)
	for i in range(nd):
		var x = w.rnd(x0 + 2.0, x1 - 2.0)
		var z = w.rnd(z0 + 2.2, z1 - 2.2)
		var rot = w.rng.randf() < 0.5
		w.add_box(x, y, z, 1.7 if not rot else 0.85, 0.78, 0.85 if not rot else 1.7, desk, {"dest": true, "hp": 80.0, "mat": 1, "lit": 0.7})
		w.add_box(x + w.rnd(-0.3, 0.3), y + 0.78, z + w.rnd(-0.2, 0.2), 0.45, 0.04, 0.32, Color(0.85, 0.83, 0.78), {"collide": false, "ry": w.rnd(-0.5, 0.5), "lit": 0.7})
		var ch = Vector3(x + (0.0 if not rot else 0.85), 0, z + (0.85 if not rot else 0.0))
		w.add_box(ch.x, y, ch.z, 0.45, 0.45, 0.45, Color(0.2, 0.2, 0.22), {"collide": false, "lit": 0.7})
		w.add_box(ch.x, y + 0.45, ch.z + (0.2 if not rot else 0.0), 0.45, 0.5, 0.06, Color(0.2, 0.2, 0.22), {"collide": false, "lit": 0.7})
	# cabinets along the outside wall (back offices) or the end of a front office, clear of the doors
	var along_z = sz * (HZ - 0.55) if not front else sz * (MIDZ - 0.5)
	var key = "m%d" % k
	var nc = w.rng.randi_range(0, 3)
	for i in range(nc):
		var x = w.rnd(x0 + 0.8, x1 - 0.8)
		var blocked = false
		for wk in doors_at:
			if not String(wk).begins_with(key) or front == false:
				continue
			for dd in doors_at[wk]:
				if absf(dd[0] - x) < dd[1]:
					blocked = true
		if front:
			# the front office's back wall has the door to the back office: stay well clear of every gap in it
			blocked = blocked or w.rng.randf() < 0.4
		if blocked:
			continue
		var tall = w.rng.randf() < 0.5
		w.add_box(x, y, along_z, 0.9, 1.9 if tall else 1.25, 0.5, metal if tall else desk.darkened(0.2), {"dest": true, "hp": 120.0, "mat": 0 if tall else 1, "lit": 0.7})

# ---------------------------------------------------------------- stairwells
# Two flights in a U: the first rises away from the corridor to a far landing on the floor above, the
# second comes back up to a near landing on the floor above that. A narrow aisle at the side joins the
# landings on every floor; walls between the flights; a rail where a landing meets an open stairwell.
static func _stairwell(wl: Dictionary, holes: Array) -> void:
	var cr: Array = wl["col"]
	var sz: float = wl["sz"]
	var sx: float = wl["sx"]
	var ux0: float = cr[0] if sx > 0 else cr[1]
	var cw: float = cr[1] - cr[0]
	var stone = Color(0.5, 0.48, 0.45)
	var wall_c = Color(0.66, 0.64, 0.6)
	var LN1 = [0.15, 2.55]
	var SP1 = [2.55, 3.15]
	var LN2 = [3.15, 5.55]
	var SP2 = [5.55, 5.85]
	var V0 = CORR + 2.15
	var V1 = CORR + 7.55
	# local (u across, v away from the corridor) to world rect [x0, x1, z0, z1]
	var R = func(u0: float, u1: float, v0: float, v1: float) -> Array:
		var xa = ux0 + sx * u0
		var xb = ux0 + sx * u1
		var za = sz * v0
		var zb = sz * v1
		return [minf(xa, xb), maxf(xa, xb), minf(za, zb), maxf(za, zb)]
	var box = func(r: Array, y0: float, h: float, c: Color, opt: Dictionary) -> void:
		w.add_box((r[0] + r[1]) / 2.0, y0, (r[2] + r[3]) / 2.0, r[1] - r[0], h, r[3] - r[2], c, opt)
	# open floor over each flight
	holes[1].append(R.call(LN1[0], LN1[1], V0, V1))
	holes[2].append(R.call(LN2[0], LN2[1], V0, V1))
	# walls between the flights and beside the aisle, a storey at a time
	for k in range(NL):
		box.call(R.call(SP1[0], SP1[1], V0, V1), k * FH, FH - 0.3, wall_c, {"dest": false})
		box.call(R.call(SP2[0], SP2[1], V0, V1), k * FH, FH - 0.3, wall_c, {"dest": false})
	# rails where a landing meets an open flight
	box.call(R.call(LN1[0], LN1[1], V0 - 0.12, V0), FH, 1.0, Color(0.3, 0.3, 0.32), {"dest": false})
	box.call(R.call(LN2[0], LN2[1], V1, V1 + 0.12), 2.0 * FH, 1.0, Color(0.3, 0.3, 0.32), {"dest": false})
	# the two flights
	_flight(R.call(LN1[0], LN1[1], V0, V1), 0, sz, stone)
	_flight(R.call(LN2[0], LN2[1], V0, V1), 1, -sz, stone)
	var mid1 = (LN1[0] + LN1[1]) / 2.0
	var mid2 = (LN2[0] + LN2[1]) / 2.0
	var P = func(u: float, v: float, k: int) -> Vector3:
		return Vector3(ux0 + sx * u, Levels.gy + k * FH, sz * v)
	Levels.stairs.append({"k": 0, "a": P.call(mid1, V0 - 0.9, 0), "b": P.call(mid1, V1 + 1.0, 1)})
	Levels.stairs.append({"k": 1, "a": P.call(mid2, V1 + 1.0, 1), "b": P.call(mid2, V0 - 0.9, 2)})

# one flight from storey k up to k+1 over rect r (along z); rise_dir: +1 rises toward +z
static func _flight(r: Array, k: int, rise_dir: float, c: Color) -> void:
	var x0: float = r[0]
	var x1: float = r[1]
	var z0: float = r[2]
	var z1: float = r[3]
	var L = z1 - z0
	var base = k * FH
	var steps = 14
	for i in range(steps):
		var sh = (i + 1) * FH / steps
		var zc = z0 + (i + 0.5) * L / steps if rise_dir > 0 else z1 - (i + 0.5) * L / steps
		w.add_box((x0 + x1) / 2.0, base, zc, x1 - x0, sh, L / steps, c.darkened(0.03 * (i % 2)), {"collide": false, "lit": 0.42})
	# what's walked on: a smooth ramp
	var ramp = StaticBody3D.new()
	ramp.collision_layer = G.L_WORLD
	ramp.collision_mask = 0
	var rcs = CollisionShape3D.new()
	var rb = BoxShape3D.new()
	rb.size = Vector3(x1 - x0, 0.2, Vector2(L, FH).length())
	rcs.shape = rb
	ramp.add_child(rcs)
	var ang = atan2(FH, L)
	ramp.transform = Transform3D(Basis(Vector3(1, 0, 0), -ang * rise_dir), Vector3((x0 + x1) / 2.0, Levels.gy + base + FH / 2.0 - 0.1, (z0 + z1) / 2.0))
	w._geo().add_child(ramp)
	# nobody walks underneath it
	var n = 6
	for i in range(n):
		var k0 = float(i) / n
		var k1 = float(i + 1) / n
		var zc2 = lerpf(z0, z1, (k0 + k1) / 2.0)
		var h = FH * (k0 if rise_dir > 0 else (1.0 - k1)) - 0.45
		if h < 0.5:
			continue
		var cc = w.add_col((x0 + x1) / 2.0, Levels.gy + base, zc2, x1 - x0, h, (z1 - z0) / n)
		cc.dest = false
		cc.vis = []
		cc.set_meta("under_stairs", true)

# ---------------------------------------------------------------- floor slabs with holes in them
# cut rect [x0, x1, z0, z1] around each hole: whatever's left as a handful of rects
static func _cut_holes(r: Array, hs: Array) -> Array:
	var out = [r]
	for h in hs:
		var nxt = []
		for q in out:
			if h[1] <= q[0] or h[0] >= q[1] or h[3] <= q[2] or h[2] >= q[3]:
				nxt.append(q)
				continue
			if h[0] > q[0]:
				nxt.append([q[0], h[0], q[2], q[3]])
			if h[1] < q[1]:
				nxt.append([h[1], q[1], q[2], q[3]])
			var xa = maxf(q[0], h[0])
			var xb = minf(q[1], h[1])
			if h[2] > q[2]:
				nxt.append([xa, xb, q[2], h[2]])
			if h[3] < q[3]:
				nxt.append([xa, xb, h[3], q[3]])
		out = nxt
	# keep each slab under ~25 m so the cutaway and the lighting have sensible pieces to work with
	var fin = []
	for q in out:
		var nx = maxi(1, int(ceil((q[1] - q[0]) / 25.0)))
		var nz = maxi(1, int(ceil((q[3] - q[2]) / 25.0)))
		for i in range(nx):
			for j in range(nz):
				fin.append([lerpf(q[0], q[1], float(i) / nx), lerpf(q[0], q[1], float(i + 1) / nx), lerpf(q[2], q[3], float(j) / nz), lerpf(q[2], q[3], float(j + 1) / nz)])
	return fin

# ---------------------------------------------------------------- the yard
static func _yard(W2: float, D2: float) -> void:
	var wc = Color(0.55, 0.52, 0.48)
	# a low wall round the yard with gateways on the road and at the sides
	var YX = HX + 26.0
	var YZ = HZ + 16.0
	for e in [-1.0, 1.0]:
		var gaps = [[-26.0, 5.0, "open"], [26.0, 5.0, "open"], [0.0, 6.0, "open"]]
		var cur = -YX
		for gp in gaps:
			_lowwall(true, e * YZ, cur, gp[0] - gp[1] / 2.0, wc)
			cur = gp[0] + gp[1] / 2.0
		_lowwall(true, e * YZ, cur, YX, wc)
		_lowwall(false, e * YX, -YZ, -4.0, wc)
		_lowwall(false, e * YX, 4.0, YZ, wc)
	# sandbags at the doors, cars in the yard, a few trees
	for e in [-1.0, 1.0]:
		w.sandbags(e * (HX + 6.0), 3.5, 3.0, false)
		w.sandbags(e * (HX + 6.0), -3.5, 3.0, false)
		for cx in CROSS:
			w.sandbags(cx + 3.5, e * (HZ + 5.0), 2.5, true)
	for i in range(8):
		var x = w.rnd(-HX + 4.0, HX - 4.0)
		var z = (HZ + w.rnd(6.0, 12.0)) * (1.0 if i % 2 == 0 else -1.0)
		if not w.inside_any(x, z, 3.0):
			w.truck(x, z, w.rng.randf() < 0.5)
	for i in range(24):
		var x = w.rnd(-W2 + 8.0, W2 - 8.0)
		var z = w.rnd(-D2 + 6.0, D2 - 6.0)
		if (absf(x) > YX + 4.0 or absf(z) > YZ + 4.0) and not w.on_road(x, z) and not w.inside_any(x, z, 2.0):
			w.live_tree(x, z)

static func _lowwall(horiz: bool, fixed: float, a: float, b: float, c: Color) -> void:
	var L = b - a
	if L < 0.3:
		return
	var n = maxi(1, int(ceil(L / 3.0)))
	for i in range(n):
		var m = a + (i + 0.5) * L / n
		if horiz:
			w.add_box(m, 0.0, fixed, L / n, 1.1, 0.4, c, {"dest": true, "hp": 260.0})
		else:
			w.add_box(fixed, 0.0, m, 0.4, 1.1, L / n, c, {"dest": true, "hp": 260.0})

# ---------------------------------------------------------------- cover on the floors above
static func cover(world) -> void:
	if not Levels.on:
		return
	for c in world.cols_in_rect(-HX - 1.0, -HZ - 1.0, HX + 1.0, HZ + 1.0):
		for k in range(1, NL):
			var ly = Levels.floor_y(k)
			if absf(c.lo.y - ly) < 0.3:
				world.gen_cover_for(c, ly, k)
