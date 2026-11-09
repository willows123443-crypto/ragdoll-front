class_name Obj
extends RefCounted
# Control points and the game modes built on them.
#   capture    one point in the middle; holding it scores points
#   frontline  a chain of points across the map; take them in order, push the front forward;
#              each side has tickets (one per soldier lost) and holding more points drains the enemy's
#   assault    Alpha attacks a chain of points Bravo defends, in order, with limited tickets
#   laststand  Alpha holds the centre against waves of Bravo attackers that grow every wave

const RADIUS = 10.0

static var points: Array = []      # {"p", "name", "owner", "prog", "contested", "n": [per team]}
static var tickets: Array = []
static var bleed_t = 0.0
static var wave = 0
static var wave_t = 0.0
static var wave_left = 0

static func uses_points() -> bool:
	return G.mode in ["capture", "frontline", "assault", "laststand"]

static func chain() -> bool:
	return G.mode in ["frontline", "assault"]

static func reset() -> void:
	points = []
	var src: Array = G.world.objectives
	if G.mode == "capture" or G.mode == "laststand":
		src = [{"p": G.world.capture, "name": "A"}]
	for o in src:
		points.append({"p": Vector3(o["p"].x, G.world.ground_y(o["p"].x, o["p"].z), o["p"].z), "name": o["name"],
			"owner": -1, "prog": 0.0, "contested": false, "n": _zeros(), "amt": 0.0, "ct": -1})
	if G.mode == "assault":
		for pt in points:
			pt["owner"] = 1
			pt["prog"] = -1.0
	if G.mode == "laststand":
		points[0]["owner"] = 0
		points[0]["prog"] = 1.0
	tickets = [G.limit, G.limit]
	bleed_t = 0.0
	wave = 0
	wave_t = 8.0
	wave_left = 0

# can this team start capturing point i right now?
static func capturable(i: int, team: int) -> bool:
	if not chain():
		return true
	var n = points.size()
	if G.mode == "assault" and team == 1:
		return true          # defenders may always retake
	if team == 0:
		return i == 0 or points[i - 1]["owner"] == 0
	return i == n - 1 or points[i + 1]["owner"] == 1

# the point a team should be fighting over: the first one it doesn't own in its direction of travel
static func front(team: int) -> int:
	var n = points.size()
	if n == 0:
		return -1
	if team == 0:
		for i in range(n):
			if points[i]["owner"] != 0:
				return i
		return n - 1
	for i in range(n - 1, -1, -1):
		if points[i]["owner"] != 1:
			return i
	return 0

# the most forward point a team holds (where its reinforcements gather), or -1
static func forward_held(team: int) -> int:
	var best = -1
	for i in range(points.size()):
		var pt = points[i]
		if pt["owner"] == team and not pt["contested"] and pt["n"][1 - team] == 0:
			if best < 0 or (team == 0 and i > best) or (team == 1 and i < best):
				best = i
	return best

static func step(dt: float) -> void:
	if points.is_empty() or G.over:
		return
	for pt in points:
		pt["n"] = _zeros()
	for s in G.soldiers:
		if (s.state == "alive" or s.state == "riding") and s.team < G.team_count():
			for pt in points:
				if G.dist2d(s.pos, pt["p"]) < RADIUS and absf(s.pos.y - pt["p"].y) < 6.0:
					pt["n"][s.team] += 1
	if G.team_count() > 2:
		_step_multi(dt)
	else:
		_step_two(dt)
	_score(dt)

static func _zeros() -> Array:
	var z = []
	for t in range(G.team_count()):
		z.append(0)
	return z

# three or four teams: whoever is alone on a point takes it over
static func _step_multi(dt: float) -> void:
	for i in range(points.size()):
		var pt = points[i]
		var present = []
		for t in range(G.team_count()):
			if pt["n"][t] > 0:
				present.append(t)
		pt["contested"] = present.size() > 1
		if present.size() != 1:
			continue
		var k = present[0]
		var rate = 0.09 * mini(pt["n"][k], 4) * dt
		if pt["owner"] >= 0 and pt["owner"] != k:
			pt["amt"] -= rate
			if pt["amt"] <= 0.0:
				var prev = pt["owner"]
				pt["owner"] = -1
				pt["amt"] = 0.0
				pt["ct"] = k
				G.main.on_point_changed(i, prev, -1)
		elif pt["owner"] == k:
			pt["amt"] = minf(1.0, pt["amt"] + rate)
		else:
			if pt["ct"] != k:
				pt["ct"] = k
				pt["amt"] = 0.0
			pt["amt"] += rate
			if pt["amt"] >= 1.0:
				pt["amt"] = 1.0
				pt["owner"] = k
				G.main.on_point_changed(i, -1, k)
		pt["prog"] = pt["amt"] * (1.0 if (pt["owner"] if pt["owner"] >= 0 else pt["ct"]) % 2 == 0 else -1.0)

static func _step_two(dt: float) -> void:
	for i in range(points.size()):
		var pt = points[i]
		var a = pt["n"][0]
		var b = pt["n"][1]
		pt["contested"] = a > 0 and b > 0
		var rate = 0.0
		if a > 0 and b == 0 and capturable(i, 0):
			rate = 0.09 * mini(a, 4)
		elif b > 0 and a == 0 and capturable(i, 1):
			rate = -0.09 * mini(b, 4)
		elif a == 0 and b == 0 and pt["owner"] >= 0:
			rate = 0.03 if pt["owner"] == 0 else -0.03     # an owned, empty point drifts back to its owner
		pt["prog"] = clampf(pt["prog"] + rate * dt, -1.0, 1.0)
		var owner = pt["owner"]
		if pt["prog"] >= 1.0:
			owner = 0
		elif pt["prog"] <= -1.0:
			owner = 1
		elif (owner == 0 and pt["prog"] <= 0.0) or (owner == 1 and pt["prog"] >= 0.0):
			owner = -1
		if owner != pt["owner"]:
			var prev = pt["owner"]
			pt["owner"] = owner
			G.main.on_point_changed(i, prev, owner)

static func _score(dt: float) -> void:
	match G.mode:
		"capture":
			var o = points[0]["owner"]
			if o >= 0:
				G.cap_score[o] += dt * 0.5
				if G.cap_score[o] >= G.limit:
					G.main.end_game(o)
		"frontline":
			var held = [0, 0]
			for pt in points:
				if pt["owner"] >= 0:
					held[pt["owner"]] += 1
			if held[0] == points.size():
				G.main.end_game(0)
				return
			if held[1] == points.size():
				G.main.end_game(1)
				return
			bleed_t += dt
			if bleed_t >= 6.0:
				bleed_t = 0.0
				if held[0] > held[1]:
					_spend(1, held[0] - held[1])
				elif held[1] > held[0]:
					_spend(0, held[1] - held[0])
		"assault":
			var all_taken = true
			for pt in points:
				if pt["owner"] != 0:
					all_taken = false
			if all_taken:
				G.main.end_game(0)
		"laststand":
			_waves(dt)

static func _spend(team: int, n: int) -> void:
	if G.mode != "frontline" and not (G.mode == "assault" and team == 0):
		return
	tickets[team] = maxi(0, tickets[team] - n)
	if tickets[team] <= 0:
		G.main.end_game(1 - team)

static func on_death(s) -> void:
	if s.team < 2 and (G.mode == "frontline" or G.mode == "assault"):
		_spend(s.team, 1)
	if G.mode == "laststand" and s.team == 0 and G.alive_count(0) == 0:
		G.main.end_game(1)

# last stand: waves of attackers, each larger than the last; defenders get a few fresh men between waves
static func _waves(dt: float) -> void:
	var attackers = G.alive_count(1)
	if wave_left > 0:
		wave_t -= dt
		if wave_t <= 0.0:
			var n = mini(wave_left, 8)
			wave_left -= n
			wave_t = 6.0
			if G.reinf_mode == "para":
				Reinforce.paradrop(1, n)
			else:
				Reinforce.truck(1, n)
		return
	if attackers > 0:
		return
	wave_t -= dt
	if wave_t > 0.0:
		return
	wave += 1
	wave_left = 4 + wave * 3
	wave_t = 0.0
	var fresh = mini(3, G.team_size - G.alive_count(0))
	for i in range(fresh):
		G.main.base_spawn(0)
	G.ui.message("Wave %d: %d attackers incoming" % [wave, wave_left])

static func status_text() -> String:
	match G.mode:
		"frontline":
			return "tickets %d : %d" % [tickets[0], tickets[1]]
		"assault":
			return "attackers' tickets %d" % tickets[0]
		"laststand":
			return "wave %d" % wave
	return ""
