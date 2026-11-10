class_name Stretcher
extends RefCounted
# Two men carry a badly wounded soldier back on a stretcher to a field hospital too far to drag him to.
# The first one to reach him calls a second over; they lift him together and walk him back,
# and if either is hit on the way, the stretcher goes down where it is.

static var teams: Array = []

static func reset() -> void:
	for t in teams:
		_drop(t)
	teams = []

static func busy(s) -> bool:
	return s.has_meta("stretcher")

# a medic (or a mate) has reached the wounded man: is a stretcher run worth it, and is there a second bearer?
static func try_start(w, a) -> bool:
	if busy(a) or busy(w) or w.dragger != null or w.carried_by != null:
		return false
	var hosp = Medical.hospital_near(a.team, w.pos, 170.0)
	if hosp == null or G.dist2d(hosp["p"], w.pos) < 40.0:
		return false
	var b = null
	var bd = 25.0
	for o in G.soldiers:
		if o == a or o.team != a.team or o.state != "alive" or o.is_player or o.vehicle != null or busy(o) or o.task in ["medic", "flank_move", "clear"]:
			continue
		if o.vis_t != null:
			continue
		var d = G.dist2d(o.pos, w.pos)
		if d < bd:
			bd = d
			b = o
	if b == null:
		return false
	var t = {"w": w, "a": a, "b": b, "dest": hosp["p"] + G.flat(w.pos - hosp["p"]).normalized() * 4.0, "stage": 0, "mesh": null, "t": 0.0}
	teams.append(t)
	for s in [w, a, b]:
		s.set_meta("stretcher", t)
	for s in [a, b]:
		AI.release_cover(s)
		s.task = "stretcher"
		AI.go_to(s, w.pos, 4.5)
	G.fx.callout(a, G.pick(["Stretcher! Give me a hand!", "Help me carry him!", "Get the stretcher, we're taking him back!"]))
	return true

static func step(dt: float) -> void:
	for i in range(teams.size() - 1, -1, -1):
		var t = teams[i]
		if not _ok(t):
			_drop(t)
			teams.remove_at(i)
			continue
		_tick(t, dt)
		if t.get("done", false):
			_drop(t)
			teams.remove_at(i)

# each bearer's own tick (from AI.update): walk, hold the handles, no shooting
static func drive(s) -> void:
	var t = s.get_meta("stretcher")
	if t["stage"] == 0 or s == t["a"]:
		var res = AI.follow_path(s)
		if res == "arrived" or res == "stuck":
			AI.stop_move(s)
	else:
		s.want = t.get("bw", Vector3.ZERO)
	var h = t.get("ha" if s == t["a"] else "hb")
	if h != null and t["stage"] == 1:
		s.hand_t = h
		var side: Vector3 = t.get("side", Vector3.RIGHT)
		s.hands_t = [h - side * 0.3, h + side * 0.3]
		s.aim_yaw = G.turn_to(s.aim_yaw, t.get("yaw", s.aim_yaw), 6.0 * G.DT)
	s.ready_ = false
	s.vis_t = null

static func _ok(t) -> bool:
	for k in ["w", "a", "b"]:
		var s = t[k]
		if s == null or not is_instance_valid(s):
			return false
	if t["w"].state != "wounded":
		return false
	for k in ["a", "b"]:
		if t[k].state != "alive" or t[k].vehicle != null:
			return false
	t["t"] += G.DT
	return t["t"] < 150.0 and (t["stage"] == 1 or t["t"] < 30.0)

static func _tick(t, dt: float) -> void:
	var w = t["w"]
	var a = t["a"]
	var b = t["b"]
	if t["stage"] == 0:
		# both bearers get to him
		for s in [a, b]:
			if G.dist2d(s.pos, w.pos) > 1.6 and (s.move_target == null or G.dist2d(s.move_target, w.pos) > 1.5):
				AI.go_to(s, w.pos, 4.5)
		if G.dist2d(a.pos, w.pos) < 1.8 and G.dist2d(b.pos, w.pos) < 1.8:
			t["stage"] = 1
			_make_mesh(t)
			for p in w.parts:
				p.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
				p.freeze = true
			AI.go_to(a, t["dest"], 2.6)
			G.fx.callout(b, G.pick(["Lift!", "On three, lift!", "Got him, go!"]))
		return
	# carrying: the front man walks to the hospital, the back man follows two metres behind
	if a.move_target == null or G.dist2d(a.move_target, t["dest"]) > 2.0:
		AI.go_to(a, t["dest"], 2.6)
	var dir = G.flat(t["dest"] - a.pos)
	if dir.length() < 0.5:
		dir = G.flat(a.pos - b.pos)
	dir = dir.normalized()
	var spot = a.pos - dir * 2.2
	AI.stop_move(b)
	var to = G.flat(spot - b.pos)
	t["bw"] = to.normalized() * minf(to.length() * 3.0, 3.0) if to.length() > 0.15 else Vector3.ZERO
	for s in [a, b]:
		s.ready_ = false
		s.crouch_t = 0.15
		s.prone_t = false
	var axis = G.flat(a.pos - b.pos)
	if axis.length() < 0.5:
		axis = dir
	axis = axis.normalized()
	var mid = (a.pos + b.pos) * 0.5
	var y = G.world.surface_y(mid.x, mid.z, mid.y + 0.5) + 0.85
	var c = Vector3(mid.x, y, mid.z)
	# hands on the handles
	t["ha"] = c + axis * 1.05
	t["hb"] = c - axis * 1.05
	t["yaw"] = atan2(axis.x, axis.z)
	t["side"] = axis.cross(Vector3.UP).normalized()
	if is_instance_valid(t["mesh"]):
		t["mesh"].global_position = c
		t["mesh"].rotation.y = atan2(axis.x, axis.z)
	_lay(w, c + Vector3(0, 0.14, 0), axis)
	w.pos = Vector3(c.x, G.world.ground_y(c.x, c.z), c.z)
	if G.dist2d(a.pos, t["dest"]) < 2.5:
		t["done"] = true
		G.fx.callout(a, G.pick(["Doc! Got one for you!", "Put him down here, gently.", "Made it!"]))

# the wounded man lying on his back along the stretcher, head toward the front
static func _lay(w, c: Vector3, axis: Vector3) -> void:
	var side = axis.cross(Vector3.UP).normalized()
	# trunk and head: +y toward the head, +z (their back) down; limbs: +y toward the hand or foot, +z (front) up
	var BT = Basis(-side, axis, Vector3.DOWN)
	var BL = Basis(-side, -axis, Vector3.UP)
	var offs = {0: [0.0, -0.1], 1: [0.0, 0.25], 2: [0.0, 0.62], 3: [-0.22, 0.36], 4: [-0.24, 0.06], 5: [0.22, 0.36], 6: [0.24, 0.06],
		7: [-0.1, -0.35], 8: [-0.1, -0.8], 9: [0.1, -0.35], 10: [0.1, -0.8]}
	for i in range(w.parts.size()):
		var o = offs.get(i, [0.0, 0.0])
		w.parts[i].global_transform = Transform3D(BT if i < 3 else BL, c - side * o[0] + axis * o[1])

static func _make_mesh(t) -> void:
	var n = Node3D.new()
	G.fx.add_child(n)
	var canvas = Color(0.45, 0.43, 0.32)
	var pole = Color(0.35, 0.27, 0.18)
	VModel.box(null, n, Vector3(0.6, 0.04, 1.8), Vector3.ZERO, canvas, {"b": 0.0})
	for x in [-0.32, 0.32]:
		VModel.box(null, n, Vector3(0.05, 0.05, 2.3), Vector3(x, 0.02, 0), pole, {"b": 0.0})
	t["mesh"] = n

static func _drop(t) -> void:
	for k in ["w", "a", "b"]:
		var s = t[k]
		if s != null and is_instance_valid(s):
			if s.has_meta("stretcher"):
				s.remove_meta("stretcher")
			if k != "w":
				if s.task == "stretcher":
					s.task = null
				s.hand_t = null
				s.hands_t = null
				s.decide_t = 0.0
	var w = t["w"]
	if w != null and is_instance_valid(w):
		for p in w.parts:
			p.freeze = false
		if w.medic == t["a"]:
			w.medic = null
	if is_instance_valid(t.get("mesh")):
		t["mesh"].queue_free()
