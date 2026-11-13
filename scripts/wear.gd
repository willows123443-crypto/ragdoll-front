class_name Wear
# What a man's uniform shows of what he's been through: mud on the knees, elbows and front of men who've
# crawled (more of it the further they've gone, and quicker in the rain), a white dressing wound round
# wherever he was hit once it's been seen to, and soot on the crews who got out of a burning vehicle.

static var mats = {}
static var boxes = {}

static func _mat(key: String, col: Color) -> StandardMaterial3D:
	if mats.has(key):
		return mats[key]
	var m = StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 1.0
	if col.a < 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mats[key] = m
	return m

static func _box(sz: Vector3) -> BoxMesh:
	var k = "%.3f,%.3f,%.3f" % [sz.x, sz.y, sz.z]
	if boxes.has(k):
		return boxes[k]
	var bm = BoxMesh.new()
	bm.size = sz
	boxes[k] = bm
	return bm

static func _add(s, part: int, sz: Vector3, off: Vector3, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = _box(sz)
	mi.material_override = mat
	mi.position = off
	mi.layers = 2
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.parts[part].add_child(mi)
	return mi

# ---------------------------------------------------------------- mud
static func mud_tick(s, dt: float) -> void:
	if s.mud_stage >= 3 or s.parts.size() < 11:
		return
	s.mud = minf(1.0, s.mud + dt * (0.2 if Weather.kind == "rain" else 0.1))
	var st = 3 if s.mud >= 1.0 else (2 if s.mud >= 0.55 else (1 if s.mud >= 0.2 else 0))
	while s.mud_stage < st:
		s.mud_stage += 1
		_mud_stage(s, s.mud_stage)

static func _mud_stage(s, stage: int) -> void:
	var m = _mat("mud" + str(s.id % 3), [Color(0.43, 0.34, 0.23), Color(0.38, 0.31, 0.22), Color(0.47, 0.38, 0.26)][s.id % 3])
	match stage:
		1:
			# knees and elbows
			for i in [8, 10]:
				_add(s, i, Vector3(0.166, 0.15, 0.166), Vector3(0, -0.16, 0), m)
			for i in [4, 6]:
				_add(s, i, Vector3(0.132, 0.15, 0.132), Vector3(0, -0.09, 0), m)
		2:
			# belly and thighs
			_add(s, 0, Vector3(0.375, 0.15, 0.262), Vector3(0, -0.02, 0), m)
			for i in [7, 9]:
				_add(s, i, Vector3(0.182, 0.2, 0.182), Vector3(0, 0.1, 0), m)
		3:
			# plastered: up the chest, down the shins and along the arms
			_add(s, 1, Vector3(0.452, 0.12, 0.272), Vector3(0, -0.2, 0), m)
			for i in [8, 10]:
				_add(s, i, Vector3(0.162, 0.14, 0.162), Vector3(0, 0.02, 0), m)
			for i in [3, 5]:
				_add(s, i, Vector3(0.14, 0.12, 0.14), Vector3(0, 0.08, 0), m)

# ---------------------------------------------------------------- dressings
# a bandage wound round the part that was hit, with the blood coming through it (up to three of them on
# a man who keeps getting hit)
static func dress(w) -> void:
	if w.parts.size() < 11:
		return
	var used: Array = w.get_meta("dressed", [])
	if used.size() >= 3:
		return
	var part: int = w.wound_part if w.wound_part >= 0 and w.wound_part < 11 else -1
	if part < 0 or part in used:
		var free = [1, 3, 5, 7, 9, 4, 6, 8, 10, 2].filter(func(p): return not (p in used))
		if w.has_meta("leg_wound") and not (7 in used):
			part = 7
		else:
			part = free[randi() % free.size()]
	used.append(part)
	w.set_meta("dressed", used)
	var white = _mat("lint", Color(0.93, 0.91, 0.85))
	var red = _mat("lintred", Color(0.5, 0.07, 0.06))
	var pw: float = Soldier.PART_W[part]
	var pd: float = Soldier.PART_D[part]
	var sz = Vector3(pw + 0.03, 0.11, pd + 0.03)
	var off = Vector3.ZERO
	if part == 2:
		sz = Vector3(pw + 0.02, 0.055, pd + 0.02)     # round the brow, just under the rim of the helmet
		off = Vector3(0, 0.055, 0)
	elif part == 1:
		sz = Vector3(pw + 0.03, 0.13, pd + 0.03)
		off = Vector3(0, -0.17, 0)                    # round the ribs, below the webbing
	elif part == 0:
		sz = Vector3(pw + 0.03, 0.11, pd + 0.03)
	var b = _add(w, part, sz, off, white)
	var spot = MeshInstance3D.new()
	spot.mesh = _box(Vector3(minf(0.08, sz.x * 0.5), sz.y * 0.55, 0.012))
	spot.material_override = red
	spot.position = Vector3(sz.x * randf_range(-0.2, 0.2), 0, (sz.z * 0.5 + 0.004) * (1.0 if randf() < 0.5 else -1.0))
	spot.layers = 2
	spot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.add_child(spot)

# ---------------------------------------------------------------- soot
# out of a burning vehicle: blackened face and hands, the uniform scorched and smoke-stained
static func soot(s) -> void:
	if s.parts.size() < 11 or s.has_meta("sooty"):
		return
	s.set_meta("sooty", true)
	var k = _mat("soot", Color(0.03, 0.03, 0.03, 0.8))
	var k2 = _mat("soot2", Color(0.04, 0.035, 0.03, 0.58))
	_add(s, 2, Vector3(0.262, 0.2, 0.272), Vector3(0, -0.035, 0), k2)       # face and neck
	_add(s, 1, Vector3(0.465, 0.36, 0.285), Vector3(0, 0.08, 0), k)         # chest and shoulders
	_add(s, 0, Vector3(0.375, 0.12, 0.262), Vector3(0, 0.05, 0), k2)
	for i in [3, 5]:
		_add(s, i, Vector3(0.142, 0.2, 0.142), Vector3(0, -0.06, 0), k)
	for i in [4, 6]:
		_add(s, i, Vector3(0.132, 0.34, 0.132), Vector3(0, 0.0, 0), k2)
	for i in [7, 9]:
		_add(s, i, Vector3(0.182, 0.22, 0.182), Vector3(0, -0.1, 0), k2)
