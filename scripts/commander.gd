class_name Commander
extends RefCounted
# A commander for each AI side. Every so often it looks at what the team knows and hands squads jobs:
# attack the front objective, defend a threatened point, swing round a flank, or wait in reserve.
# Each side has an officer; while he's alive orders come quickly and soldiers nearby fight harder.
# Every commander has a personality:
#   reckless  attacks straight away and keeps attacking, the nearest objective first
#   cautious  waits until it has the numbers, digs in and sets ambushes, avoids strong points
#   cunning   sends its weight where the scouts say the enemy is thin, with a feint and flanks
# and a couple of scouts who creep ahead and radio back what they see.

static var timers: Array = []
static var style: Array = []
static var sightings: Array = []     # per side: [{"p", "n", "t"}] reported by scouts
static var scout_t: Array = []
static var held: Array = []          # how long a cautious side has been sitting tight
const STYLES = ["reckless", "cautious", "cunning"]
const STYLE_TEXT = {"reckless": "reckless: attacks at once and keeps coming", "cautious": "cautious: digs in and waits for the numbers", "cunning": "cunning: probes with scouts and hits weak spots"}

static func reset() -> void:
	timers = []
	style = []
	sightings = []
	scout_t = []
	for t in range(G.team_count()):
		timers.append(randf_range(6.0, 10.0))
		style.append(STYLES[randi() % STYLES.size()])
		sightings.append([])
		scout_t.append(3.0)
		held.append(0.0)

static func style_of(t: int) -> String:
	return style[t] if t >= 0 and t < style.size() else "cunning"

# how many enemies this side believes are near a spot: what its soldiers know, plus scout reports
static func strength(team: int, p: Vector3, r: float) -> float:
	var seen = {}
	for s in G.soldiers:
		if s.team != team or s.state == "dead":
			continue
		for e in s.intel.keys():
			var k = s.intel[e]
			if G.sim_time - k["t"] < 30.0 and G.dist2d(k["p"], p) < r:
				seen[e] = true
	var n = float(seen.size())
	if team < sightings.size():
		for sg in sightings[team]:
			if G.sim_time - sg["t"] < 90.0 and G.dist2d(sg["p"], p) < r:
				n += sg["n"] * 0.6
	return n

# a scout's report goes into the picture (it needs a working radio to get back)
static func report(team: int, p: Vector3, n: int) -> void:
	if team >= sightings.size():
		return
	var list: Array = sightings[team]
	for sg in list:
		if G.dist2d(sg["p"], p) < 14.0:
			sg["p"] = sg["p"].lerp(p, 0.5)
			sg["n"] = maxi(sg["n"], n)
			sg["t"] = G.sim_time
			return
	list.append({"p": p, "n": n, "t": G.sim_time})
	if list.size() > 24:
		list.pop_front()

# keep one or two scouts out on each side
static func _keep_scouts(t: int) -> void:
	if G.mode in ["horde", "laststand", "sandbox", "escort"] or (G.mode == "commander" and t == 0) or (G.mode == "sabotage" and t == 0):
		return
	var want = 2 if G.team_size >= 14 else 1
	var have = 0
	for s in G.soldiers:
		if s.team == t and s.state == "alive" and s.has_meta("scout"):
			have += 1
	if have >= want:
		return
	var best = null
	for s in G.soldiers:
		if s.team == t and s.state == "alive" and not s.is_player and s.vehicle == null and s.cls in ["rifleman", "sniper"] \
				and not Morale.is_leader(s) and not s.has_meta("guard") and not s.has_meta("runner") and not s.has_meta("general"):
			best = s
			break
	if best == null:
		return
	best.set_meta("scout", true)
	best.order = null
	# scouts work alone: out of the squad, so squad tactics leave them be
	var sq = {"team": t, "members": [], "id": G.squads.size(), "form": "wedge", "bound": 0, "guard": true, "follow": true}
	G.squads.append(sq)
	if best.squad != null:
		best.squad["members"].erase(best)
	sq["members"].append(best)
	best.squad = sq
	G.fx.callout(best, G.pick(["Going forward to have a look.", "Scouting ahead.", "I'll see what's out there."]))

static func officer(team: int):
	for s in G.soldiers:
		if s.team == team and s.cls == "officer" and s.state != "dead":
			return s
	return null

static func step(dt: float) -> void:
	if G.over:
		return
	for t in range(timers.size()):
		timers[t] -= dt
		if timers[t] > 0.0:
			continue
		if (G.mode == "horde" and t == 1) or (G.mode == "commander" and t == 0):
			timers[t] = 999.0
			continue
		var off = officer(t)
		timers[t] = 14.0 if off != null else 30.0
		if style_of(t) == "reckless":
			timers[t] *= 0.75
		_keep_scouts(t)
		if VehExt.has_radar(t):
			timers[t] *= 0.6       # the command truck keeps the picture fresh
		_plan(t, off)

static func _squads(team: int) -> Array:
	return G.squads.filter(func(q): return q["team"] == team and not q["members"].is_empty() and not q.get("follow"))

# where the enemy seems to be, from everything the team knows
static func _enemy_center(team: int):
	var c = Vector3.ZERO
	var n = 0
	for s in G.soldiers:
		if s.team != team or s.state == "dead":
			continue
		for e in s.intel.values():
			if G.sim_time - e["t"] < 25.0:
				c += e["p"]
				n += 1
	return c / n if n > 0 else null

static func _plan(team: int, off) -> void:
	var qs = _squads(team)
	if qs.is_empty():
		return
	# player-given orders take precedence
	if G.orders[team]["mode"] != "free":
		return
	var said = false
	var home: Vector3 = G.world.spawn[team]
	if G.mode == "destroy" or G.mode == "commander":
		_base_plan(team, qs, home)
		return
	if G.mode == "sabotage":
		_raid_plan(team, qs, home)
		return
	# a cautious commander won't attack into a stronger enemy: dig in and let them come
	if style_of(team) == "cautious" and G.mode not in ["assault", "breakthrough", "siege", "general"] and not (G.mode == "assault" and team == 0):
		var mine = G.alive_count(team)
		var theirs = strength(team, G.world.capture, 9999.0)
		if theirs > mine * 1.05 and G.sim_time > 20.0 and held[team] < 75.0:
			held[team] += timers[team]
			_hold_ground(team, qs, home)
			return
		if held[team] >= 75.0:
			held[team] = 0.0
			G.ui.radio(team, "Command: we've waited long enough. All squads, advance")
	if Obj.uses_points() and not Obj.points.is_empty() and G.mode != "laststand":
		_spread_over_points(team, qs, home)
		return
	# deathmatch / sandbox: hit the enemy where they are, with one squad going round the side
	var ec = _enemy_center(team)
	if ec == null:
		return
	var st = style_of(team)
	for k in range(qs.size()):
		var q = qs[k]
		var job = "attack"
		if st == "cunning" and qs.size() >= 2 and k % 2 == 1:
			job = "flank"
		elif st != "reckless" and qs.size() >= 3 and k == qs.size() - 1:
			job = "flank"
		elif st != "reckless" and qs.size() >= 4 and k == 0:
			job = "defend"
		_assign(q, job, ec if job != "defend" else home + G.flat(ec - home).normalized() * 25.0, home)
	G.ui.radio(team, "Command: enemy concentrating near %s, all squads engage" % AI.grid_ref(ec))

# hand squads out across the points: attack what we can take, defend what's under threat,
# keep a light hold on the rest, and never send everyone to the same place
static func _spread_over_points(team: int, qs: Array, home: Vector3) -> void:
	var pts = Obj.points
	var vals = []
	for i in range(pts.size()):
		var pt = pts[i]
		var v = 0.0
		var enemies = 0
		for t in range(G.team_count()):
			if t != team:
				enemies += pt["n"][t]
		if pt["owner"] == team:
			v = 3.0 if enemies > 0 else 0.7
		elif Obj.capturable(i, team):
			v = 2.4 if pt["owner"] < 0 else 2.0
		else:
			v = 0.0
		if G.mode == "assault" and team == 1 and pt["owner"] == 1:
			v = 2.6 if i == Obj.front(0) else 1.0
		# what the commander believes is there (scout reports included) bends the choice
		if v > 0.0 and pt["owner"] != team:
			var est = strength(team, pt["p"], 30.0)
			match style_of(team):
				"cunning":
					v = maxf(0.3, v + 0.8 - est * 0.35)
				"cautious":
					v = maxf(0.2, v - est * 0.5)
				"reckless":
					v += 0.4
		elif pt["owner"] == team and style_of(team) == "cautious":
			v += 0.5
		vals.append(v)
	var count = []
	for i in range(pts.size()):
		count.append(0)
	var lines = []
	for q in qs:
		var L = Squad.leader_of(q)
		var from: Vector3 = L.pos if L != null else home
		var best = -1
		var bs = -1e9
		for i in range(pts.size()):
			if vals[i] <= 0.0:
				continue
			var d = G.dist2d(from, pts[i]["p"])
			var sc = vals[i] / (1.0 + count[i] * 0.9) - d / 250.0
			if sc > bs:
				bs = sc
				best = i
		if best < 0:
			continue
		var job = "defend" if pts[best]["owner"] == team else "attack"
		# a second squad on the same point swings round the side
		if job == "attack" and count[best] == 1:
			job = "flank"
		count[best] += 1
		_assign(q, job, pts[best]["p"], home)
		q["obj"] = best
		q["obj_t"] = G.sim_time + 20.0
		lines.append("%s %s" % [job, pts[best]["name"]])
	if not lines.is_empty() and randf() < 0.6:
		G.ui.radio(team, "Command: " + ", ".join(lines.slice(0, 4)))

# destroy base: most squads go for the nearest enemy HQ or FOB, one stays home to guard the HQ
static func _base_plan(team: int, qs: Array, home: Vector3) -> void:
	var targets = Build.sites.filter(func(st): return st["team"] != team and not st["dead"] and st["done"] and st["kind"] in ["hq", "fob", "fob2"])
	if targets.is_empty():
		return
	targets.sort_custom(func(a, b): return G.dist2d(a["p"], home) < G.dist2d(b["p"], home))
	var mine = Build.hq(team)
	var k = 0
	for q in qs:
		if k % 4 == 3 and mine != null and Build.alive(mine):
			_assign(q, "defend", mine["p"] + G.flat(targets[0]["p"] - mine["p"]).normalized() * 12.0, home)
		else:
			var tg = targets[mini(k / 3, targets.size() - 1)]
			_assign(q, "flank" if k % 3 == 1 else "attack", tg["p"], home)
		k += 1
	G.ui.radio(team, "Command: all squads, hit the enemy %s at %s" % [targets[0]["name"], AI.grid_ref(targets[0]["p"])])

# sabotage: raiders split between the targets; defenders guard them and hunt the raiders
static func _raid_plan(team: int, qs: Array, home: Vector3) -> void:
	var tg = Obj.sab_targets.filter(func(st): return not st["dead"])
	if tg.is_empty():
		return
	var k = 0
	for q in qs:
		var st = tg[k % tg.size()]
		if team == 0:
			_assign(q, "flank" if k % 2 == 1 else "attack", st["p"], home)
		else:
			var ec = _enemy_center(team)
			if k % 2 == 0 or ec == null:
				_assign(q, "defend", st["p"], home)
			else:
				_assign(q, "attack", ec, home)
		k += 1

# dig in around what we hold (or in front of the base) and wait: the troops hold fire for an ambush
static func _hold_ground(team: int, qs: Array, home: Vector3) -> void:
	var spots = []
	for pt in Obj.points:
		if pt["owner"] == team:
			spots.append(pt["p"])
	if spots.is_empty():
		spots.append(home + G.flat(G.world.capture - home).normalized() * minf(45.0, G.dist2d(home, G.world.capture) * 0.35))
	var k = 0
	for q in qs:
		_assign(q, "defend", spots[k % spots.size()], home)
		q["dig"] = true
		k += 1
	if randf() < 0.5:
		G.ui.radio(team, "Command: they outnumber us. Dig in, hold fire until they're close")

static func _assign(q, job: String, target: Vector3, home: Vector3) -> void:
	q["dig"] = false
	var p = target
	if job == "flank":
		var to = G.flat(target - home).normalized()
		var side = 1.0 if (q.get("id", 0) % 2 == 0) else -1.0
		p = target + Vector3(to.z, 0, -to.x) * side * 35.0 - to * 10.0
		p.x = clampf(p.x, G.world.bounds.position.x + 5.0, G.world.bounds.end.x - 5.0)
		p.z = clampf(p.z, G.world.bounds.position.y + 5.0, G.world.bounds.end.y - 5.0)
	q["cmd"] = {"job": job, "p": p, "t": G.sim_time + 20.0}
	q["obj_t"] = -1.0
	var L = Squad.leader_of(q)
	if L != null and randf() < 0.5:
		Voice.say(L, "order_defend" if job == "defend" else "order_attack")

# the commander's point for this squad, if it has a fresh one
static func target_for(s):
	var q = s.squad
	if q == null:
		return null
	var c = q.get("cmd")
	if c == null or G.sim_time > c["t"] + 10.0:
		return null
	if c["job"] == "flank" and G.dist2d(s.pos, c["p"]) < 12.0:
		return null     # made it round the side: now fight normally
	return c["p"]
