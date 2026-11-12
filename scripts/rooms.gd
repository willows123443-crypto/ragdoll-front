class_name Rooms
extends RefCounted
# Room clearing in a building with floors (the office block). Every office is a room with its doors
# known. A squad that knows of an enemy in a room on its floor doesn't trickle in after him one at a time:
# it stacks up either side of the nearest door, one man posts a grenade through it, they go in together
# (first man to one corner, second to the other, third down the middle, fourth holds the door), call it
# clear, and move on. Men inside a room with the enemy about cover its door.

static var list: Array = []      # {"k", "x0", "x1", "z0", "z1", "doors": [{"c", "n", "along"}], "clear_t": {team: time}}
static var raw_doors: Array = [] # {"k", "p", "horiz"}: as the walls are built
static var by_k = {}

static func reset() -> void:
	list = []
	raw_doors = []
	by_k = {}

static func add_door(k: int, horiz: bool, x: float, z: float) -> void:
	raw_doors.append({"k": k, "p": Vector3(x, 0, z), "horiz": horiz})

static func add_room(k: int, x0: float, x1: float, z0: float, z1: float) -> void:
	list.append({"k": k, "x0": minf(x0, x1), "x1": maxf(x0, x1), "z0": minf(z0, z1), "z1": maxf(z0, z1), "doors": [], "clear_t": {}})

# once the building's up: which doors open into which rooms
static func link() -> void:
	by_k = {}
	for R in list:
		if not by_k.has(R["k"]):
			by_k[R["k"]] = []
		by_k[R["k"]].append(R)
		var y = Levels.floor_y(R["k"])
		for d in raw_doors:
			if d["k"] != R["k"]:
				continue
			var p: Vector3 = d["p"]
			var n = Vector3.ZERO
			if d["horiz"] and p.x > R["x0"] + 0.3 and p.x < R["x1"] - 0.3:
				if absf(p.z - R["z0"]) < 0.35:
					n = Vector3(0, 0, -1)
				elif absf(p.z - R["z1"]) < 0.35:
					n = Vector3(0, 0, 1)
			elif not d["horiz"] and p.z > R["z0"] + 0.3 and p.z < R["z1"] - 0.3:
				if absf(p.x - R["x0"]) < 0.35:
					n = Vector3(-1, 0, 0)
				elif absf(p.x - R["x1"]) < 0.35:
					n = Vector3(1, 0, 0)
			if n != Vector3.ZERO:
				R["doors"].append({"c": Vector3(p.x, y, p.z), "n": n, "along": Vector3(-n.z, 0, n.x)})

static func room_at(p: Vector3) -> Variant:
	if not Levels.on or not Levels.inside(p, 0.0):
		return null
	for R in by_k.get(Levels.level_of(p), []):
		if p.x > R["x0"] and p.x < R["x1"] and p.z > R["z0"] and p.z < R["z1"]:
			return R
	return null

static func _in(R, p: Vector3, k: int) -> bool:
	return k == R["k"] and p.x > R["x0"] and p.x < R["x1"] and p.z > R["z0"] and p.z < R["z1"]

static func _clamp_in(R, p: Vector3, m: float) -> Vector3:
	return Vector3(clampf(p.x, R["x0"] + m, R["x1"] - m), Levels.floor_y(R["k"]), clampf(p.z, R["z0"] + m, R["z1"] - m))

# ---------------------------------------------------------------- the squad, about once a second
static func squad(q, L) -> void:
	if not Levels.on or list.is_empty():
		return
	var st = q.get("room")
	if st != null:
		_run(q, st)
		return
	if G.sim_time < q.get("room_cd", 0.0) or not Levels.inside(L.pos, 1.0):
		return
	var lk = Levels.level_of(L.pos)
	var best = null
	var bd = 28.0
	for m in q["members"]:
		if m.state != "alive":
			continue
		for e in m.intel:
			if not is_instance_valid(e) or e.state != "alive":
				continue
			var kk = m.intel[e]
			if G.sim_time - kk["t"] > 6.0:
				continue
			var R = room_at(kk["p"])
			if R == null or R["k"] != lk or R["doors"].is_empty():
				continue
			var d = G.dist2d(kk["p"], L.pos)
			if d < bd:
				bd = d
				best = R
	if best == null:
		return
	# some of ours already in there fighting it out: no grenade on top of them, just go and help
	for s in G.soldiers:
		if s.team == L.team and s.state == "alive" and _in(best, s.pos, Levels.level_of(s.pos)):
			return
	var door = null
	var dd = 1e9
	for d in best["doors"]:
		var out: Vector3 = d["c"] + d["n"] * 1.0
		if not Levels.walkable(lk, out):
			continue
		# (by the way they'd actually walk to it: the nearest door through a wall is no use)
		var dist = _walk_len(lk, L.pos, out)
		if dist < dd:
			dd = dist
			door = d
	if door == null or dd > 45.0:
		return
	var men = []
	var pool = q["members"].filter(func(m): return m.state == "alive" and not m.is_player and m.vehicle == null and not m.zombie and not m.broken and Levels.inside(m.pos, 1.0) and Levels.level_of(m.pos) == lk and G.dist2d(m.pos, door["c"]) < 32.0)
	pool.sort_custom(func(a, b): return G.dist2d(a.pos, door["c"]) < G.dist2d(b.pos, door["c"]))
	for m in pool:
		if men.size() >= 4:
			break
		var k = men.size()
		var at: Vector3 = door["c"] + door["n"] * 1.0 + door["along"] * ((1.0 + 0.9 * (k / 2)) * (1.0 if k % 2 == 0 else -1.0))
		if not Levels.walkable(lk, at):
			at = door["c"] + door["n"] * (1.6 + 0.5 * k)
		AI.release_cover(m)
		m.task = "clear"
		AI.go_to(m, at, 4.4)
		men.append(m)
	if men.is_empty():
		return
	q["room"] = {"R": best, "door": door, "men": men, "stage": "stack", "t": G.sim_time + 9.0}
	Tactics.events["room_stack"] = Tactics.events.get("room_stack", 0) + 1
	G.fx.callout(L, G.pick(["Stack up on that door!", "Room on the left, stack up!", "On the door. Ready!", "He's in that office: stack up!"]))

static func _walk_len(k: int, from: Vector3, to: Vector3) -> float:
	var pth = Levels.flat_path(k, from, to)
	if pth.is_empty():
		return 1e9
	var L = 0.0
	var prev = from
	for q in pth:
		L += G.dist2d(prev, q)
		prev = q
	if G.dist2d(prev, to) > 1.5:
		return 1e9
	return L

static func _alive(st) -> Array:
	return st["men"].filter(func(m): return is_instance_valid(m) and m.state == "alive")

static func _done(q, st, cd: float) -> void:
	for m in st["men"]:
		if is_instance_valid(m) and m.task == "clear":
			m.task = null
			m.decide_t = 0.0
	q["room"] = null
	q["room_cd"] = G.sim_time + cd

static func _run(q, st) -> void:
	var men = _alive(st)
	if men.is_empty():
		_done(q, st, 10.0)
		return
	var R = st["R"]
	var door = st["door"]
	var now = G.sim_time
	match st["stage"]:
		"stack":
			var ready = 0
			for m in men:
				if G.dist2d(m.pos, door["c"]) < 3.2 and Levels.level_of(m.pos) == R["k"]:
					ready += 1
			if ready < mini(2, men.size()) and now < st["t"]:
				return
			# the grenade goes in on a line through the middle of the doorway, to land well inside
			# (only by a man who can see clean through the doorway to where it's to land: one thrown at an
			# angle comes back off the frame among his own squad)
			var thrower = null
			var tgt = Vector3.ZERO
			if not Faction.militia(men[0].team):
				for m in men:
					if m.grenades <= 0 or G.dist2d(m.pos, door["c"]) > 3.6 or m.move_target != null:
						continue
					var through = G.flat(door["c"] - m.pos).normalized()
					if through.dot(-door["n"]) < 0.45:
						continue
					var tg = _clamp_in(R, door["c"] + through * 3.4 - door["n"] * 0.8, 0.9)
					if G.blocked(m.head_pos(), tg + Vector3(0, 1.0, 0)) or G.blocked(m.head_pos(), door["c"] + through * 1.2 + Vector3(0, 1.2, 0)):
						continue
					thrower = m
					tgt = tg
					break
			if thrower != null:
				tgt.y += 0.1
				Combat.throw_grenade(thrower, tgt, "frag")
				Voice.say(thrower, "frag_in")
				G.fx.callout(thrower, G.pick(["Frag out!", "Grenade going in!", "Frag in!"]))
			st["stage"] = "wait"
			st["t"] = now + (3.4 if thrower != null else 0.4)
		"wait":
			if now < st["t"]:
				return
			var nin: Vector3 = -door["n"]
			var al: Vector3 = door["along"]
			var k = 0
			for m in men:
				var to: Vector3
				if k == 0:
					to = _clamp_in(R, door["c"] + nin * 1.8 + al * 2.2, 0.7)
				elif k == 1:
					to = _clamp_in(R, door["c"] + nin * 1.8 - al * 2.2, 0.7)
				elif k == 2:
					to = _clamp_in(R, door["c"] + nin * 4.0, 0.9)
				else:
					to = door["c"] - nin * 1.2      # the last man holds the door
				AI.release_cover(m)
				m.task = "clear"
				AI.go_to(m, to, 5.4)
				k += 1
			G.fx.callout(men[0], G.pick(["Go go go!", "In! In!", "Move!", "Going in!"]))
			st["stage"] = "inside"
			st["t"] = now + 2.5
			st["t_max"] = now + 10.0
		"inside":
			if now < st["t"]:
				return
			var contact = false
			for m in q["members"]:
				if is_instance_valid(m) and m.state == "alive" and m.vis_t != null and is_instance_valid(m.vis_t) and m.vis_t.state == "alive" and _in(R, m.vis_t.pos, Levels.level_of(m.vis_t.pos)):
					contact = true
			var inside = men.filter(func(m): return _in(R, m.pos, Levels.level_of(m.pos)))
			if contact and now < st["t_max"]:
				st["t"] = now + 1.5
				return
			if inside.is_empty() and now < st["t_max"]:
				st["t"] = now + 1.0
				return
			if not inside.is_empty() and not contact:
				G.fx.callout(inside[0], G.pick(["Clear!", "Room clear!", "Clear left!"]))
				if inside.size() > 1:
					G.fx.callout(inside[1], G.pick(["Clear right!", "Clear!", "All clear."]))
				R["clear_t"][men[0].team] = now
				Tactics.events["room_clear"] = Tactics.events.get("room_clear", 0) + 1
			_done(q, st, 3.0)

# ---------------------------------------------------------------- a man in a room, enemy about: cover the door
static func watch(s) -> bool:
	if not Levels.on or s.vis_t != null or s.is_player or s.zombie or s.task == "clear":
		return false
	var R = room_at(s.pos)
	if R == null or R["doors"].is_empty():
		return false
	var near = false
	for e in s.intel:
		var k = s.intel[e]
		if G.sim_time - k["t"] < 12.0 and G.dist2d(k["p"], s.pos) < 28.0 and absf(k["p"].y - s.pos.y) < 2.0:
			near = true
			break
	if not near:
		return false
	# the door nearest to where they were last known to be
	var look = null
	var bd = 1e9
	for d in R["doors"]:
		var dd = G.dist2d(d["c"], s.pos)
		if dd > 1.2 and dd < bd:
			bd = dd
			look = d["c"]
	if look == null:
		return false
	s.aim_yaw = G.turn_to(s.aim_yaw, atan2(look.x - s.pos.x, look.z - s.pos.z), 3.0 * G.DT)
	s.ready_ = true
	s.crouch_t = 0.6
	return true
