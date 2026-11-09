class_name Doors
extends RefCounted
# House doors that soldiers kick open and window glass that shatters when shot, kicked or hit by a grenade.
# A closed door blocks sight, bullets lose a little going through it, and grenades bounce off it.
# Glass you can see through; grenades lobbed at a window smash it and land inside.

const L_GLASS = 16
const KICK_R = 1.25

static var doors: Array = []
static var panes: Array = []
static var glass_mm: MultiMesh = null
static var tick_i = 0
static var door_mat: StandardMaterial3D = null

static func reset() -> void:
	doors = []
	panes = []
	glass_mm = null

# called by the world once a map is built: every recorded opening of an intact building gets a door or a pane
static func setup(w) -> void:
	reset()
	if door_mat == null:
		door_mat = StandardMaterial3D.new()
		door_mat.albedo_color = Color(0.42, 0.3, 0.2)
		door_mat.roughness = 0.85
	for o in w.openings:
		if o["col"] != null and not o["col"].alive:
			continue
		if o["kind"] == "door":
			_make_door(w, o)
		else:
			panes.append(_pane_info(w, o))
	_build_glass(w)

static func _along(o) -> Vector3:
	return Vector3(1, 0, 0) if o["horiz"] else Vector3(0, 0, 1)

static func _center(w, o, y: float) -> Vector3:
	var p = Vector3(o["c"], 0, o["fixed"]) if o["horiz"] else Vector3(o["fixed"], 0, o["c"])
	p.y = w.ground_y(p.x, p.z) + y
	return p

static func _normal(w, o) -> Vector3:
	var b = w.buildings[o["b"]] if o["b"] >= 0 and o["b"] < w.buildings.size() else null
	if b == null:
		return Vector3(0, 0, 1) if o["horiz"] else Vector3(1, 0, 0)
	if o["horiz"]:
		return Vector3(0, 0, signf(o["fixed"] - b["z"]) if o["fixed"] != b["z"] else 1.0)
	return Vector3(signf(o["fixed"] - b["x"]) if o["fixed"] != b["x"] else 1.0, 0, 0)

static func _make_door(w, o) -> void:
	var pw = o["w"] - 0.26
	var along = _along(o)
	var c = _center(w, o, 0.0)
	var hinge = Node3D.new()
	w.geo_root.add_child(hinge)
	hinge.position = c - along * pw / 2.0 + Vector3(0, 0.15, 0)
	var base_yaw = 0.0 if o["horiz"] else -PI / 2.0
	hinge.rotation.y = base_yaw
	var panel = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(pw, 2.2, 0.07)
	panel.mesh = bm
	panel.material_override = door_mat
	panel.position = Vector3(pw / 2.0, 1.1, 0)
	hinge.add_child(panel)
	# a handle and two planks' worth of trim
	var knob = MeshInstance3D.new()
	var km = BoxMesh.new()
	km.size = Vector3(0.06, 0.06, 0.14)
	knob.mesh = km
	var kmat = StandardMaterial3D.new()
	kmat.albedo_color = Color(0.7, 0.62, 0.35)
	kmat.metallic = 0.6
	knob.material_override = kmat
	knob.position = Vector3(pw - 0.12, 1.0, 0)
	hinge.add_child(knob)
	for yy in [0.5, 1.75]:
		var tr = MeshInstance3D.new()
		var tm = BoxMesh.new()
		tm.size = Vector3(pw - 0.1, 0.1, 0.09)
		tr.mesh = tm
		tr.material_override = door_mat
		tr.position = Vector3(pw / 2.0, yy, 0)
		hinge.add_child(tr)
	var body = StaticBody3D.new()
	body.collision_layer = G.L_WORLD
	body.collision_mask = 0
	var cs = CollisionShape3D.new()
	var bs = BoxShape3D.new()
	bs.size = Vector3(pw, 2.2, 0.08)
	cs.shape = bs
	body.add_child(cs)
	body.position = panel.position
	hinge.add_child(body)
	var d = {"node": hinge, "body": body, "c": c + Vector3(0, 1.1, 0), "n": _normal(w, o), "along": along, "pw": pw,
		"base": base_yaw, "ang": 0.0, "goal": 0.0, "sgn": 1.0, "hp": 70.0, "col": o["col"], "b": o["b"], "alive": true}
	body.set_meta("door", d)
	doors.append(d)

static func _pane_info(w, o) -> Dictionary:
	var y0: float = o["y0"]
	var y1: float = o["y1"]
	var c = _center(w, o, (y0 + y1) / 2.0)
	return {"c": c, "n": _normal(w, o), "horiz": o["horiz"], "w": o["w"] - 0.1, "h": y1 - y0 - 0.06, "col": o["col"], "b": o["b"], "alive": true, "body": null, "i": -1}

static func _build_glass(w) -> void:
	if panes.is_empty():
		return
	glass_mm = MultiMesh.new()
	glass_mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm = BoxMesh.new()
	bm.size = Vector3(1, 1, 1)
	glass_mm.mesh = bm
	glass_mm.instance_count = panes.size()
	var mi = MultiMeshInstance3D.new()
	mi.multimesh = glass_mm
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.68, 0.74, 0.32)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.metallic = 0.4
	mat.roughness = 0.08
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.geo_root.add_child(mi)
	for i in range(panes.size()):
		var p = panes[i]
		var sz = Vector3(p["w"], p["h"], 0.03) if p["horiz"] else Vector3(0.03, p["h"], p["w"])
		glass_mm.set_instance_transform(i, Transform3D(Basis.from_scale(sz), p["c"]))
		var body = StaticBody3D.new()
		body.collision_layer = L_GLASS
		body.collision_mask = 0
		var cs = CollisionShape3D.new()
		var bs = BoxShape3D.new()
		bs.size = sz + Vector3(0.02, 0.0, 0.02)
		cs.shape = bs
		body.add_child(cs)
		w.geo_root.add_child(body)
		body.position = p["c"]
		body.set_meta("pane", p)
		p["body"] = body
		p["i"] = i

# ---------------------------------------------------------------- breaking things
static func shatter(p: Dictionary, loud: bool = true) -> void:
	if not p["alive"]:
		return
	p["alive"] = false
	if glass_mm != null and p["i"] >= 0:
		glass_mm.set_instance_transform(p["i"], Transform3D(Basis.from_scale(Vector3(0.001, 0.001, 0.001)), p["c"]))
	if is_instance_valid(p["body"]):
		p["body"].queue_free()
	p["body"] = null
	if loud:
		G.fx.glass(p["c"], p["n"])
		G.audio.glass(p["c"])

static func open(d: Dictionary, from: Vector3, fast: bool = true) -> void:
	if not d["alive"] or d["goal"] > 0.0:
		return
	# swing away from whoever pushed it
	var side = signf((from - d["c"]).dot(d["n"]))
	if side == 0.0:
		side = 1.0
	var far = Basis(Vector3.UP, d["base"] + 1.4) * Vector3(1, 0, 0)
	d["sgn"] = 1.0 if signf(far.dot(d["n"])) == -side else -1.0
	d["goal"] = 1.45 if fast else 1.2
	d["speed"] = 9.0 if fast else 3.0
	G.audio.kick(d["c"])

static func break_door(d: Dictionary, vel: Vector3 = Vector3.ZERO) -> void:
	if not d["alive"]:
		return
	d["alive"] = false
	var c: Vector3 = d["c"]
	for k in range(4):
		G.fx.debris(c + Vector3(randf_range(-0.4, 0.4), randf_range(-0.8, 0.8), randf_range(-0.4, 0.4)), vel + Vector3(randf_range(-2, 2), randf_range(1, 4), randf_range(-2, 2)), 0.28, Color(0.42, 0.3, 0.2))
	if is_instance_valid(d["node"]):
		d["node"].queue_free()

static func shot(d: Dictionary, dmg: float, p: Vector3, dir: Vector3) -> void:
	d["hp"] -= dmg
	G.fx.impact(p, -dir)
	if d["hp"] <= 0.0:
		break_door(d, dir * 3.0)

# explosions blow doors open or off their hinges and blow out windows
static func blast(pos: Vector3, power: float) -> void:
	for d in doors:
		if not d["alive"]:
			continue
		var dd = pos.distance_to(d["c"])
		if dd < 3.0 * power:
			break_door(d, (d["c"] - pos).normalized() * 6.0)
		elif dd < 7.0 * power:
			open(d, pos)
	for p in panes:
		if p["alive"] and pos.distance_to(p["c"]) < 9.0 * power:
			shatter(p)

# ---------------------------------------------------------------- per tick
static func step() -> void:
	if doors.is_empty() and panes.is_empty():
		return
	tick_i += 1
	for d in doors:
		if not d["alive"]:
			continue
		if d["ang"] != d["goal"]:
			d["ang"] = move_toward(d["ang"], d["goal"], d.get("speed", 6.0) * G.DT)
			d["node"].rotation.y = d["base"] + d["sgn"] * d["ang"]
	if tick_i % 3 != 0:
		return
	# soldiers walking up to a closed door kick it open
	for d in doors:
		if not d["alive"] or d["goal"] > 0.0:
			continue
		for s in G.soldiers_near(d["c"]):
			if s.state != "alive" or absf(s.pos.y + 1.1 - d["c"].y) > 1.6:
				continue
			var to = G.flat(d["c"] - s.pos)
			var dist = to.length()
			if dist > KICK_R:
				continue
			if s.is_player or Vector2(s.vel.x, s.vel.z).length() > 0.4 or s.want.length() > 0.3:
				open(d, s.pos)
				s.kick(to / maxf(dist, 0.01))
				break
	if tick_i % 30 != 0:
		return
	# walls that came down take their doors and windows with them
	for d in doors:
		if d["alive"] and d["col"] != null and not d["col"].alive:
			break_door(d)
	for p in panes:
		if p["alive"] and p["col"] != null and not p["col"].alive:
			shatter(p, false)

# grenades go through glass (it is not solid to them) and break it on the way
static func grenade_tick(g: RigidBody3D) -> void:
	var gp = g.global_position
	for p in panes:
		if not p["alive"]:
			continue
		var c: Vector3 = p["c"]
		if absf(gp.y - c.y) > p["h"] / 2.0 + 0.2:
			continue
		var along = absf(gp.x - c.x) if p["horiz"] else absf(gp.z - c.z)
		var across = absf(gp.z - c.z) if p["horiz"] else absf(gp.x - c.x)
		if along < p["w"] / 2.0 + 0.1 and across < 0.35:
			shatter(p)

static func pane_near(p: Vector3, r: float):
	var best = null
	var bd = r
	for q in panes:
		if q["alive"]:
			var d = p.distance_to(q["c"])
			if d < bd:
				bd = d
				best = q
	return best

static func door_near(p: Vector3, r: float):
	for d in doors:
		if d["alive"] and G.dist2d(p, d["c"]) < r:
			return d
	return null

# ---------------------------------------------------------------- grenades through windows
static func building_at(p: Vector3) -> int:
	var bs = G.world.buildings
	for i in range(bs.size()):
		var b = bs[i]
		if absf(p.x - b["x"]) < b["w"] / 2.0 - 0.2 and absf(p.z - b["z"]) < b["d"] / 2.0 - 0.2:
			return i
	return -1

# an enemy inside a house: lob the grenade in through a window (or an open door) the thrower can see
static func throw_point(s, target: Vector3) -> Vector3:
	var bi = building_at(target)
	if bi < 0 or building_at(s.pos) == bi:
		return target
	var head = s.head_pos()
	var best = null
	var bd = 26.0
	for p in panes:
		if p["b"] == bi:
			var r = _try_opening(s, head, p["c"], p["n"])
			if r >= 0.0 and r < bd:
				bd = r
				best = p["c"] - p["n"] * 1.3 + Vector3(0, -0.7, 0)
	for d in doors:
		if d["b"] == bi and (not d["alive"] or d["goal"] > 0.0):
			var r = _try_opening(s, head, d["c"], d["n"])
			if r >= 0.0 and r < bd:
				bd = r
				best = d["c"] - d["n"] * 1.6 + Vector3(0, -0.9, 0)
	return best if best != null else target

static func _try_opening(s, head: Vector3, c: Vector3, n: Vector3) -> float:
	var to = G.flat(s.pos - c)
	if to.dot(n) < 1.5:
		return -1.0
	var dist = to.length()
	if dist < 3.0 or dist > 26.0:
		return -1.0
	if not G.ray(head, c + n * 0.3, G.L_WORLD, s.rids).is_empty():
		return -1.0
	return dist
