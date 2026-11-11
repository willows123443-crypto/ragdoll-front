class_name Ops
extends RefCounted
# The AI commander's operational sense, on top of Commander's plans:
# - weak spots: attacks go in where the enemy is thinnest (left, centre or right), from what scouts report
# - coordinated attacks: a barrage on the target, then smoke in front of it, then the squads move in
# - armour support: an infantry squad walks with each tank and hunts the enemy's anti-tank men,
#   and tanks wait outside tight streets until infantry are with them
# - learning from the other side: lots of enemy armour means more anti-tank weapons; a favourite
#   line of attack gets a squad guarding it; heavy shelling makes them dig bunkers

static var lane_off: Array = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
static var ops: Array = [{}, {}, {}, {}]
static var seen_armour: Array = [0, 0, 0, 0]
static var shelled: Array = [0, 0, 0, 0]
static var their_lane: Array = [[0, 0, 0], [0, 0, 0], [0, 0, 0], [0, 0, 0]]
static var tick = 0.0
static var raids: Array = [null, null, null, null]
static var raid_cd: Array = [0.0, 0.0, 0.0, 0.0]
static var events = {"weak": 0, "barrage": 0, "smoke": 0, "escort": 0, "tank_wait": 0, "raid": 0}

static func reset() -> void:
	lane_off = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	ops = [{}, {}, {}, {}]
	seen_armour = [0, 0, 0, 0]
	shelled = [0, 0, 0, 0]
	their_lane = [[0, 0, 0], [0, 0, 0], [0, 0, 0], [0, 0, 0]]
	tick = 0.0
	raids = [null, null, null, null]
	raid_cd = [90.0, 90.0, 90.0, 90.0]
	for k in events:
		events[k] = 0

static func ai_side(team: int) -> bool:
	if G.mode == "commander" and team == 0 and not G.ai_runs(0):
		return false
	return not (G.mode == "horde" and team == 1)

# what this side knows about where the enemy is (every soldier's sightings and reports)
static func _known(team: int) -> Array:
	var out = {}
	for s in G.soldiers:
		if s.team != team or s.state == "dead":
			continue
		for e in s.intel:
			if G.sim_time - s.intel[e]["t"] < 25.0 and not out.has(e):
				out[e] = s.intel[e]["p"]
	return out.values()

# the lane (left, centre, right of the line from home to the target) with the fewest known enemies
static func plan_lane(team: int, home: Vector3, target: Vector3) -> void:
	var to = G.flat(target - home)
	if to.length() < 30.0:
		lane_off[team] = Vector3.ZERO
		return
	to = to.normalized()
	var perp = Vector3(to.z, 0, -to.x)
	var bins = [0, 0, 0]
	for p in _known(team):
		var lat = G.flat(p - target).dot(perp)
		if absf(G.flat(p - target).dot(to)) > 60.0:
			continue
		bins[0 if lat < -14.0 else (2 if lat > 14.0 else 1)] += 1
	var best = 1
	if bins[0] + 1 < bins[1] and bins[0] <= bins[2]:
		best = 0
	elif bins[2] + 1 < bins[1] and bins[2] < bins[0]:
		best = 2
	var off = perp * float(best - 1) * 26.0
	var b = G.world.bounds
	var t2 = target + off
	if t2.x < b.position.x + 10.0 or t2.x > b.end.x - 10.0 or t2.z < b.position.y + 10.0 or t2.z > b.end.y - 10.0:
		off = Vector3.ZERO
	if off != Vector3.ZERO and lane_off[team] == Vector3.ZERO:
		events["weak"] += 1
		G.ui.radio(team, "Command: they're thin on the %s, main effort goes in there" % ("left" if best == 0 else "right"))
	lane_off[team] = off

# an attack is about to go in: shells first, then smoke, then the squads
static func coordinated(team: int, target: Vector3, home: Vector3) -> void:
	if not ai_side(team):
		return
	var op: Dictionary = ops[team]
	if G.sim_time < op.get("next", 0.0):
		return
	op["next"] = G.sim_time + randf_range(110.0, 150.0)
	op["target"] = target
	op["home"] = home
	var fired = false
	if Rules.callin_ok(team, "artillery") and Support.points.size() > team and Support.points[team] >= Support.COSTS["artillery"]:
		fired = Support.call_in(team, "artillery", target)
	if not fired:
		# no guns of our own to spare: the mortars get the target instead
		for v in G.vehicles:
			if v.team == team and not v.dead and v.kind == "mortar" and v.gunner() != null:
				for s in G.soldiers:
					if s.team != team and s.state == "alive" and G.dist2d(s.pos, target) < 20.0:
						AI.add_intel(v.gunner(), s, s.pos, 3.0, true)
						fired = true
						break
	if fired:
		events["barrage"] += 1
	op["smoke_t"] = G.sim_time + (9.0 if fired else 1.0)
	op["go_t"] = G.sim_time + (14.0 if fired else 5.0)
	G.ui.radio(team, "Command: barrage on %s, then smoke, then everyone goes in" % AI.grid_ref(target) if fired else "Command: smoke, then everyone goes in")

static func step(dt: float) -> void:
	if not G.started or G.over:
		return
	tick -= dt
	if tick > 0.0:
		return
	tick = 0.5
	for t in range(mini(2, G.team_count())):
		var op: Dictionary = ops[t]
		if op.has("smoke_t") and G.sim_time >= op["smoke_t"]:
			op.erase("smoke_t")
			var tg: Vector3 = op["target"]
			var to = G.flat(tg - op["home"]).normalized()
			var perp = Vector3(to.z, 0, -to.x)
			for k in range(3):
				Combat.smoke_at(tg - to * 22.0 + perp * (k - 1) * 12.0, 24.0)
			events["smoke"] += 1
		if op.has("go_t") and G.sim_time >= op["go_t"]:
			op.erase("go_t")
			for q in G.squads:
				if q["team"] == t and q.get("cmd") != null and q["cmd"]["job"] in ["attack", "flank"]:
					q["cmd"]["t"] = G.sim_time + 20.0
					var L = Squad.leader_of(q)
					if L != null and is_instance_valid(L):
						L.decide_t = 0.0
						if randf() < 0.5:
							G.fx.callout(L, G.pick(["That's the smoke, go!", "Now! Move, move!", "Go while they're down!"]))
						for m in q["members"]:
							if is_instance_valid(m):
								m.decide_t = 0.0
		if ai_side(t):
			_escorts(t)
			_raids(t)
		_learn(t)

# one infantry squad walks with each tank or armoured car
static func _escorts(team: int) -> void:
	for o in G.squads:
		var ev = o.get("escorting")
		if ev != null and (not is_instance_valid(ev) or ev.dead):
			o["escorting"] = null
	for v in G.vehicles:
		if v.team != team or v.dead or not (v.spec["tracked"] or v.kind == "armoredcar") or v.spec.get("static", false):
			continue
		var q = v.get_meta("escort") if v.has_meta("escort") else null
		if q == null or not (q in G.squads) or Squad.leader_of(q) == null:
			q = null
			var bd = 90.0
			for o in G.squads:
				if o["team"] != team or o.get("guard", false) or o.get("escorting") != null or o.get("raiding", false):
					continue
				var L = Squad.leader_of(o)
				if L == null or not is_instance_valid(L) or L.is_player:
					continue
				var d = G.dist2d(L.pos, v.pos)
				if d < bd:
					bd = d
					q = o
			if q == null:
				continue
			q["escorting"] = v
			v.set_meta("escort", q)
			events["escort"] += 1
		# walk a little behind and to the side of it, and go after anyone with a rocket near it
		q["cmd"] = {"job": "escort", "p": v.pos - v.forward() * 7.0 + Vector3(cos(v.yaw), 0, -sin(v.yaw)) * 4.0, "t": G.sim_time + 2.0}
		# quiet and the tank is rolling slowly: climb up on the engine deck and ride (they jump off at the first shot)
		if absf(v.speed) > 0.3 and absf(v.speed) < 3.0 and G.sim_time - v.hit_t > 20.0 and v.kind == "tank" and randf() < 0.1:
			var free = []
			for i in range(v.seats.size()):
				if v.seats[i] == null and v.spec["seats"][i].get("rider", false):
					free.append(i)
			for m in q["members"]:
				if free.is_empty():
					break
				if is_instance_valid(m) and m.state == "alive" and m.vehicle == null and m.vis_t == null and m.task == null \
						and G.sim_time > m.no_board_t and G.dist2d(m.pos, v.pos) < 10.0 and not m.is_player:
					m.task = "board"
					m.board_target = v
					free.pop_front()
		for e in G.soldiers:
			if e.team != team and e.state == "alive" and (e.W["rocket"] or e.fausts > 0) and G.dist2d(e.pos, v.pos) < 50.0:
				var crew = v.driver()
				if crew != null and is_instance_valid(crew) and crew.intel.has(e):
					for m in q["members"]:
						if is_instance_valid(m) and m.state == "alive":
							AI.add_intel(m, e, e.pos, 1.0, true)
							m.target = e

# do our tanks have infantry close by? (they wait outside tight streets until they do)
static func tank_may_enter(v) -> bool:
	if not ai_side(v.team):
		return true
	var ahead = v.pos + v.forward() * 16.0
	var tight = G.world.cols_in_rect(ahead.x - 7.0, ahead.z - 7.0, ahead.x + 7.0, ahead.z + 7.0).filter(func(c): return c.alive and c.hi.y - c.lo.y > 2.5).size()
	if tight < 4:
		return true
	for s in G.soldiers:
		if s.team == v.team and s.state == "alive" and s.vehicle == null and G.dist2d(s.pos, ahead) < 18.0:
			return true
	if randf() < 0.05:
		events["tank_wait"] += 1
	return false

# notice what the other side leans on and answer it
static func _learn(team: int) -> void:
	var armour = 0
	for v in G.vehicles:
		if v.team != team and v.team >= 0 and not v.dead and (v.spec["tracked"] or v.kind == "armoredcar"):
			var d = v.driver()
			if d == null:
				continue
			for s in G.soldiers:
				if s.team == team and s.state == "alive" and s.intel.has(d):
					armour += 1
					break
	if armour > seen_armour[team]:
		seen_armour[team] = armour
		if armour >= 2 and ai_side(team):
			G.ui.radio(team, "Command: they're leaning on armour. More anti-tank weapons forward")

# called when this side gets shelled
static func note_shelled(team: int) -> void:
	if team < 0 or team >= shelled.size():
		return
	shelled[team] += 1

# the share of anti-tank men to add when the enemy has shown a lot of armour
static func at_bias(team: int) -> float:
	if team < 0 or team >= seen_armour.size():
		return 0.0
	return clampf((seen_armour[team] - 1) * 0.12, 0.0, 0.3)

# remember which side the enemy keeps coming from
static func note_attack(team: int, from: Vector3) -> void:
	var home: Vector3 = G.world.spawn[team]
	var to = G.flat(G.world.capture - home)
	if to.length() < 1.0:
		return
	to = to.normalized()
	var lat = G.flat(from - G.world.capture).dot(Vector3(to.z, 0, -to.x))
	their_lane[team][0 if lat < -14.0 else (2 if lat > 14.0 else 1)] += 1

# the side the enemy favours, if it clearly has one (for a guard squad)
static func favourite_lane(team: int):
	var b: Array = their_lane[team]
	var tot = b[0] + b[1] + b[2]
	if tot < 8:
		return null
	for i in [0, 2]:
		if b[i] > tot * 0.5:
			var home: Vector3 = G.world.spawn[team]
			var to = G.flat(G.world.capture - home).normalized()
			return home + to * 40.0 + Vector3(to.z, 0, -to.x) * (-1.0 if i == 0 else 1.0) * 26.0
	return null

# commander mode: a squad slips out to lie in wait along the road the enemy's supply convoys use
static func _raids(team: int) -> void:
	if G.mode != "commander":
		return
	var r = raids[team]
	if r != null:
		var q = r["q"]
		if not (q in G.squads) or Squad.leader_of(q) == null or G.sim_time > r["until"]:
			if q in G.squads:
				q.erase("raiding")
			raids[team] = null
			return
		q["cmd"] = {"job": "defend", "p": r["p"], "t": G.sim_time + 2.0}
		return
	if G.sim_time < raid_cd[team]:
		return
	var foe = 1 - team if team < 2 else 0
	var dumps = Build.sites.filter(func(st): return st["team"] == foe and st["kind"] == "supply" and Build.alive(st))
	if dumps.is_empty():
		return
	raid_cd[team] = G.sim_time + randf_range(150.0, 220.0)
	var dump = G.pick(dumps)
	var start = Reinforce.entry_point(foe)
	var to = G.flat(dump["p"] - start)
	var perp = Vector3(to.z, 0, -to.x).normalized() * (1.0 if randf() < 0.5 else -1.0)
	var ambush = G.main._free_spot(start + to * randf_range(0.3, 0.55) + perp * randf_range(9.0, 15.0))
	var best = null
	var bd = 1e9
	for q in G.squads:
		if q["team"] != team or q.get("guard", false) or q.get("crew", false) or q.get("escorting") != null or q.get("follow", false):
			continue
		var L = Squad.leader_of(q)
		if L == null or not is_instance_valid(L) or q["members"].size() < 3:
			continue
		var d = G.dist2d(L.pos, ambush)
		if d < bd:
			bd = d
			best = q
	if best == null:
		return
	best["raiding"] = true
	raids[team] = {"q": best, "p": ambush, "until": G.sim_time + 160.0}
	events["raid"] += 1
	var L2 = Squad.leader_of(best)
	if L2 != null:
		G.fx.callout(L2, G.pick(["We hit their supply trucks. Move out.", "Ambush on the supply road, let's go.", "Their convoys come this way. We wait for them."]))
