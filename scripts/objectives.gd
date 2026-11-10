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
	return G.mode in ["capture", "frontline", "assault", "laststand", "breakthrough", "siege", "koth"]

const MODE_INFO = {
	"sandbox": "Free play with no way to win or lose. Drop in soldiers, vehicles and buildings and watch what happens.",
	"deathmatch": "First side to reach the kill limit wins. Reinforcements arrive at your HQ or FOBs.",
	"capture": "Three or more flags across the middle of the map. Every flag you hold earns points each second; first side to the points limit wins.",
	"frontline": "A chain of flags across a big map. Take them one after another; whoever holds more drains the other side's tickets. Run out of tickets or lose every flag and you lose.",
	"assault": "Alpha attacks a chain of flags held by Bravo, with limited tickets. Bravo digs in with bunkers, wire and MG nests.",
	"laststand": "Alpha holds one flag against bigger and bigger enemy waves. Survive as long as you can.",
	"destroy": "Each side has an HQ and builds FOBs. Blow up an enemy's HQ and all its FOBs to knock it out; the last side with a base wins.",
	"breakthrough": "Bravo holds a fortified line of bunkers, wire and MG nests. Alpha must take every flag on the line before its tickets run out, then hold at least one against the counter-attack.",
	"sabotage": "At night, a small Alpha raiding party must blow up Bravo's radio mast and vehicle depot with satchel charges. The raiders get no reinforcements.",
	"escort": "Alpha drives a convoy of trucks across the map, with an armoured car up front. Get at least two trucks to the marker; Bravo sets ambushes along the way.",
	"rescue": "A pilot is down behind enemy lines. Alpha has to reach him, get him on his feet (or carry him) and bring him back to base before time runs out. Bravo hunts him: if they reach him first, they take him prisoner.",
	"koth": "King of the hill: one flag, and every 90 seconds it moves somewhere else. Holding it earns points; first to the points limit wins.",
	"commander": "A battle you fight from above: destroy the enemy HQ to win, and keep yours standing. Earn supply from supply dumps, build a vehicle depot for armour and a radio mast for air support. You can't take over soldiers: select squads, box-select or click, and right-click to send them (Ctrl+number saves a group). You only see the enemy where your men can see them. Vehicles are built at the depot, upgrades at HQ, and supply dumps pay when a convoy gets through. WASD pans, the wheel zooms.",
	"horde": "Alpha holds out against ten waves of the walking dead. Between waves there's a short break: spend points from kills on barricades, boarded windows and weapons. After dark there are more of them, and later waves bring armoured ones, bloaters and spitters.",
	"general": "Each side's general hides in a house on its own half, with a bodyguard. Find theirs and kill him before they find yours. Once he's spotted the whole side converges, and a general who's found moves somewhere further back.",
	"siege": "Alpha holds a fortified town while its supplies run down; holding the supply-road flags slows the drain. Bravo wins by taking the town, Alpha by holding out until the timer ends.",
}

static var phase = 0
static var hold_t = 0.0
static var supply = 0.0
static var siege_t = 0.0
static var sab_targets: Array = []
static var mode_t = 0.0

static func chain() -> bool:
	return G.mode in ["frontline", "assault"]

static func reset() -> void:
	points = []
	var src: Array = G.world.objectives
	if G.mode == "laststand":
		src = [{"p": G.world.capture, "name": "A"}]
	elif G.mode == "capture":
		src = _capture_points()
	elif G.mode == "koth":
		src = [{"p": _free_near(G.world.capture), "name": "K"}]
	elif G.mode in ["escort", "rescue", "horde", "general"]:
		src = []
	elif G.mode == "breakthrough":
		src = _line_points(2)
	elif G.mode == "siege":
		src = _siege_points()
	elif G.mode in ["destroy", "sabotage"]:
		src = []
	# no flags at all in modes that aren't about holding ground
	if not uses_points():
		src = []
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
	if G.mode == "breakthrough":
		for pt in points:
			pt["owner"] = 1
			pt["prog"] = -1.0
	if G.mode == "siege":
		for pt in points:
			pt["owner"] = 0
			pt["prog"] = 1.0
	phase = 0
	hold_t = 150.0
	supply = float(G.limit) * 1.2 if G.limit < 100000 else 160.0
	siege_t = 480.0
	sab_targets = []
	mode_t = 0.0
	tickets = [G.limit, G.limit] if G.limit < 100000 else [200, 200]
	bleed_t = 0.0
	wave = 0
	wave_t = 8.0
	wave_left = 0

# capture mode: several points spread across the middle of the map, so squads split up
static func _capture_points() -> Array:
	var n = 3 if G.team_count() == 2 else G.team_count() + 1
	var W = G.world
	var out = []
	if G.team_count() == 2 and W.objectives.size() >= 3:
		var ci = 0
		for i in range(W.objectives.size()):
			if W.objectives[i]["p"].distance_to(W.capture) < 1.0:
				ci = i
		var a = clampi(ci - 1, 0, W.objectives.size() - 3)
		for i in range(3):
			out.append({"p": W.objectives[a + i]["p"], "name": "ABC"[i]})
		return out
	var c: Vector3 = W.capture
	var axis = G.flat(W.spawn[1] - W.spawn[0])
	axis = axis.normalized() if axis.length_squared() > 1.0 else Vector3(1, 0, 0)
	var perp = Vector3(-axis.z, 0, axis.x)
	var b: Rect2 = W.bounds
	var R = clampf(minf(b.size.x, b.size.y) * 0.3, 26.0, 70.0)
	var raw = []
	if n == 3:
		raw = [c + perp * R, c, c - perp * R]
	else:
		raw.append(c)
		for k in range(n - 1):
			var ang = k * TAU / (n - 1) + 0.4
			raw.append(c + (perp * cos(ang) + axis * sin(ang)) * R)
	var names = "ABCDE"
	for i in range(raw.size()):
		var p: Vector3 = raw[i]
		p.x = clampf(p.x, b.position.x + 18.0, b.end.x - 18.0)
		p.z = clampf(p.z, b.position.y + 18.0, b.end.y - 18.0)
		for k in range(12):
			if not W.inside_any(p.x, p.z, 2.5) and not W.in_water(p.x, p.z):
				break
			p = raw[i] + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10))
		out.append({"p": p, "name": names[i]})
	return out

# a line of n points across the middle, square to the line between the bases
static func _line_points(n: int) -> Array:
	var W = G.world
	var c: Vector3 = W.capture
	var axis = G.flat(W.spawn[1] - W.spawn[0])
	axis = axis.normalized() if axis.length_squared() > 1.0 else Vector3(1, 0, 0)
	var perp = Vector3(-axis.z, 0, axis.x)
	var R = clampf(minf(W.bounds.size.x, W.bounds.size.y) * 0.22, 20.0, 50.0)
	var out = []
	for i in range(n):
		var k = (float(i) - (n - 1) * 0.5)
		out.append({"p": _free_near(c + perp * k * R * 1.6), "name": "ABCDE"[i]})
	return out

# siege: the town (A) and two supply roads (B, C) back toward Alpha's edge
static func _siege_points() -> Array:
	var W = G.world
	var c: Vector3 = W.capture
	var home: Vector3 = W.spawn[0]
	var back = G.flat(home - c)
	var L = back.length()
	back = back.normalized() if L > 1.0 else Vector3(-1, 0, 0)
	var perp = Vector3(-back.z, 0, back.x)
	var d = clampf(L * 0.55, 30.0, 90.0)
	return [{"p": c, "name": "A"}, {"p": _free_near(c + back * d + perp * d * 0.6), "name": "B"}, {"p": _free_near(c + back * d - perp * d * 0.6), "name": "C"}]

static func _free_near(p: Vector3) -> Vector3:
	var W = G.world
	var b: Rect2 = W.bounds
	var q = p
	for k in range(14):
		q.x = clampf(q.x, b.position.x + 18.0, b.end.x - 18.0)
		q.z = clampf(q.z, b.position.y + 18.0, b.end.y - 18.0)
		if not W.inside_any(q.x, q.z, 2.5) and not W.in_water(q.x, q.z):
			return q
		q = p + Vector3(randf_range(-12, 12), 0, randf_range(-12, 12))
	return q

# things each mode sets up once the bases exist
static func setup_mode() -> void:
	var W = G.world
	match G.mode:
		"breakthrough":
			# Bravo's fortified line in front of the points
			var axis = G.flat(W.spawn[1] - W.spawn[0]).normalized()
			var perp = Vector3(-axis.z, 0, axis.x)
			for pt in points:
				var front = -axis
				var base: Vector3 = pt["p"]
				for item in [["bunker", 0.0, -6.0], ["mgnest", -9.0, 7.0], ["mgnest", 9.0, 7.0], ["wire", -6.0, 15.0], ["wire", 6.0, 15.0],
						["traps", 0.0, 21.0], ["sandbags", -4.0, 8.0], ["sandbags", 4.0, 8.0], ["tower", 12.0, -5.0]]:
					var sp = Build.find_spot(base + perp * item[1] + front * item[2], item[0], 4.0, 10, true)
					if sp != null:
						Build.place(item[0], 1, sp, front, true)
		"siege":
			var a: Vector3 = points[0]["p"]
			var toward = G.flat(W.spawn[1] - a).normalized()
			var perp2 = Vector3(-toward.z, 0, toward.x)
			for item in [["bunker", 0.0, 9.0], ["mgnest", -11.0, 12.0], ["mgnest", 11.0, 12.0], ["wire", 0.0, 22.0], ["wire", -12.0, 20.0],
					["wire", 12.0, 20.0], ["sandbags", -6.0, 11.0], ["sandbags", 6.0, 11.0], ["hospital", 0.0, -12.0], ["traps", 0.0, 27.0]]:
				var sp = Build.find_spot(a + perp2 * item[1] + toward * item[2], item[0], 5.0, 10, true)
				if sp != null:
					Build.place(item[0], 0, sp, toward, true)
		"sabotage":
			# the raid targets, between Bravo's HQ and the middle of the map
			var h: Vector3 = W.spawn[1]
			var to_mid = G.flat(W.capture - h).normalized()
			var side = Vector3(-to_mid.z, 0, to_mid.x)
			for item in [["radio", 22.0, 14.0], ["depot", 22.0, -14.0]]:
				var sp = Build.find_spot(h + to_mid * item[1] + side * item[2], item[0], 10.0, 30, true)
				if sp != null:
					sab_targets.append(Build.place(item[0], 1, sp, to_mid, true))
			for item in [["mgnest", 34.0, 0.0], ["tower", 30.0, 22.0], ["wire", 38.0, -8.0]]:
				var sp2 = Build.find_spot(h + to_mid * item[1] + side * item[2], item[0], 6.0, 20, true)
				if sp2 != null:
					Build.place(item[0], 1, sp2, to_mid, true)

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
	if G.over:
		return
	_mode_step(dt)
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
		"koth":
			var ko = points[0]["owner"]
			if ko >= 0 and not points[0]["contested"]:
				G.cap_score[ko] += dt * 0.5
				if G.cap_score[ko] >= G.limit:
					G.main.end_game(ko)
					return
		"capture", "commander":
			for pt in points:
				var o = pt["owner"]
				if o >= 0:
					G.cap_score[o] += dt * 0.75 / points.size()
					if G.cap_score[o] >= G.limit:
						G.main.end_game(o)
						return
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
		"breakthrough":
			var taken = 0
			for pt in points:
				if pt["owner"] == 0:
					taken += 1
			if phase == 0 and taken == points.size():
				phase = 1
				hold_t = 150.0
				G.ui.radio(0, "The line is ours! Dig in, the counter-attack is coming")
				G.ui.radio(1, "We've lost the line. All units, counter-attack!")
				for t in range(Reinforce.timers.size()):
					Reinforce.timers[t] = 999.0 if t == 1 else Reinforce.timers[t]
			elif phase == 1:
				hold_t -= dt
				if taken == 0:
					G.main.end_game(1)
				elif hold_t <= 0.0:
					G.main.end_game(0)
		"siege":
			siege_t -= dt
			var roads = 0
			for i in range(1, points.size()):
				if points[i]["owner"] != 0:
					roads += 1
			supply = maxf(0.0, supply - dt * (0.12 + 0.18 * roads))
			if points[0]["owner"] == 1:
				G.main.end_game(1)
			elif siege_t <= 0.0:
				G.main.end_game(0)
			elif supply <= 0.0 and G.alive_count(0) == 0:
				G.main.end_game(1)

# win conditions for the modes that aren't just about flags
static func _mode_step(dt: float) -> void:
	mode_t += dt
	match G.mode:
		"destroy", "commander":
			if mode_t < 3.0:
				return
			var alive_bases = []
			for t in range(G.team_count()):
				if Build.out[t] if t < Build.out.size() else false:
					continue
				if Build.hq_alive(t) or not Build.fobs(t).is_empty():
					alive_bases.append(t)
				elif t < Build.out.size():
					Build.out[t] = true
					G.ui.radio(t, "Our HQ and every FOB are gone. %s is out!" % G.TEAM_NAMES[t])
					for o in range(G.team_count()):
						if o != t:
							G.ui.radio(o, "%s's base is destroyed!" % G.TEAM_NAMES[t])
			if alive_bases.size() == 1:
				G.main.end_game(alive_bases[0])
		"sabotage":
			if mode_t < 3.0:
				return
			var left = 0
			for st in sab_targets:
				if not st["dead"]:
					left += 1
			if not sab_targets.is_empty() and left == 0:
				G.main.end_game(0)
			elif G.alive_count(0) == 0:
				G.main.end_game(1)

static func _spend(team: int, n: int) -> void:
	if G.mode != "frontline" and not (G.mode in ["assault", "breakthrough"] and team == 0):
		return
	tickets[team] = maxi(0, tickets[team] - n)
	if tickets[team] <= 0:
		G.main.end_game(1 - team)

static func on_death(s) -> void:
	if s.team < 2 and (G.mode == "frontline" or G.mode == "assault" or (G.mode == "breakthrough" and phase == 0)):
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
		"breakthrough":
			if phase == 0:
				return "break the line · tickets %d" % tickets[0]
			return "hold! %d:%02d" % [int(hold_t) / 60, int(hold_t) % 60]
		"siege":
			return "supply %d · %d:%02d left" % [int(supply), int(siege_t) / 60, int(siege_t) % 60]
		"destroy":
			return "destroy the enemy base"
		"sabotage":
			var left = 0
			for st in sab_targets:
				if not st["dead"]:
					left += 1
			return "targets left: %d" % left
	return Modes.status_text()
