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

static var feints: Array = []       # per side: a feint in progress, or null
static var feint_cd: Array = []
static var regroup: Array = []      # per side: the second line it has pulled back to, or null
static var events = {"feint": 0, "feint_go": 0, "regroup": 0, "counter": 0}

static func reset() -> void:
	timers = []
	style = []
	sightings = []
	scout_t = []
	held = []
	feints = []
	feint_cd = []
	regroup = []
	for k in events:
		events[k] = 0
	for t in range(G.team_count()):
		timers.append(randf_range(6.0, 10.0))
		style.append(STYLES[randi() % STYLES.size()])
		sightings.append([])
		scout_t.append(3.0)
		held.append(0.0)
		feints.append(null)
		feint_cd.append(randf_range(45.0, 90.0))
		regroup.append(null)

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
	if G.mode in ["horde", "laststand", "sandbox", "escort"] or not G.ai_runs(t) or (G.mode == "sabotage" and t == 0):
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
		if t < feints.size() and feints[t] != null:
			_feint_tick(t)
		if timers[t] > 0.0:
			continue
		if (G.mode == "horde" and t == 1) or not G.ai_runs(t):
			timers[t] = 999.0
			continue
		var off = officer(t)
		timers[t] = 14.0 if off != null else 30.0
		if style_of(t) == "reckless":
			timers[t] *= 0.75
		_keep_scouts(t)
		_move_command_post(t)
		VehExt.send_fuel(t)
		if VehExt.has_radar(t):
			timers[t] *= 0.6       # the command truck keeps the picture fresh
		_plan(t, off)

# the AI brings its command truck up behind its own line and sets it up there (and moves it back if
# the front comes too close), so it is a target worth hunting
static func _move_command_post(t: int) -> void:
	for v in G.vehicles:
		if v.kind != "radar" or v.team != t or v.dead or v.driver() == null or v.driver().is_player:
			continue
		if v.cmd != null and G.dist2d(v.cmd, v.pos) > 6.0:
			return
		var want: Vector3 = VehExt.radar_spot(v)
		# not too close to where the enemy is now
		var foe = _enemy_center(t)
		if foe != null and G.dist2d(want, foe) < 70.0:
			want = want.lerp(G.world.spawn[t], 0.5)
		want = G.main._free_spot(want)
		if G.dist2d(want, v.pos) > 15.0:
			v.command(want)
		return

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
	# a feint going on: the plan is already made, leave the squads to it until it's played out
	if feints[team] != null:
		return
	# badly beaten: pull back to a second line and gather there rather than feed men in a few at a time
	if _regroup_check(team, qs, home):
		return
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
	Ops.plan_lane(team, home, ec)
	var fav = Ops.favourite_lane(team)
	for k in range(qs.size()):
		var q = qs[k]
		var job = "attack"
		if st == "cunning" and qs.size() >= 2 and k % 2 == 1:
			job = "flank"
		elif st != "reckless" and qs.size() >= 3 and k == qs.size() - 1:
			job = "flank"
		elif st != "reckless" and qs.size() >= 4 and k == 0:
			job = "defend"
		# a defending squad guards the side the enemy keeps coming from, if it has a favourite
		var dp = (fav if fav != null else home + G.flat(ec - home).normalized() * 25.0)
		_assign(q, job, ec if job != "defend" else dp, home)
	G.ui.radio(team, "Command: enemy concentrating near %s, all squads engage" % AI.grid_ref(ec))
	if st != "cautious":
		Ops.coordinated(team, ec, home)

# hand squads out across the points: attack what we can take, defend what's under threat,
# keep a light hold on the rest, and never send everyone to the same place
static func _spread_over_points(team: int, qs: Array, home: Vector3) -> void:
	var pts = Obj.points
	var cand = []
	for i in range(pts.size()):
		if pts[i]["owner"] != team and Obj.capturable(i, team):
			cand.append(pts[i]["p"])
	if _try_feint(team, qs, home, cand):
		return
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
	# the point most squads are going for gets a barrage and smoke ahead of them
	var most = -1
	var mc = 1
	for i in range(pts.size()):
		if pts[i]["owner"] != team and count[i] > mc:
			mc = count[i]
			most = i
	if most >= 0 and style_of(team) != "cautious" and strength(team, pts[most]["p"], 30.0) > 0.5:
		Ops.coordinated(team, pts[most]["p"], home)

# destroy base: most squads go for the nearest enemy HQ or FOB, one stays home to guard the HQ
static func _base_plan(team: int, qs: Array, home: Vector3) -> void:
	var targets = Build.sites.filter(func(st): return st["team"] != team and not st["dead"] and st["done"] and st["kind"] in ["hq", "fob", "fob2"])
	if targets.is_empty():
		return
	targets.sort_custom(func(a, b): return G.dist2d(a["p"], home) < G.dist2d(b["p"], home))
	if _try_feint(team, qs, home, targets.map(func(st): return st["p"])):
		return
	var mine = Build.hq(team)
	Ops.plan_lane(team, home, targets[0]["p"])
	var k = 0
	for q in qs:
		if k % 4 == 3 and mine != null and Build.alive(mine):
			_assign(q, "defend", mine["p"] + G.flat(targets[0]["p"] - mine["p"]).normalized() * 12.0, home)
		else:
			var tg = targets[mini(k / 3, targets.size() - 1)]
			_assign(q, "flank" if k % 3 == 1 else "attack", tg["p"], home)
		k += 1
	G.ui.radio(team, "Command: all squads, hit the enemy %s at %s" % [targets[0]["name"], AI.grid_ref(targets[0]["p"])])
	Ops.coordinated(team, targets[0]["p"], home)

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

# ---------------------------------------------------------------- feints
# One squad (with a barrage and smoke to sell it) goes noisily for one objective; the rest wait out of
# sight behind another. Once the defenders have shifted toward the noise, the main body goes in.
static func _try_feint(team: int, qs: Array, home: Vector3, cand: Array) -> bool:
	if qs.size() < 2 or G.sim_time < feint_cd[team] or G.mode in ["horde", "laststand", "sabotage"]:
		return false
	var st = style_of(team)
	if st == "reckless" or randf() > (0.6 if st == "cunning" else 0.3):
		feint_cd[team] = G.sim_time + 30.0
		return false
	if cand.is_empty():
		return false
	# the real target: where they're thinnest. The decoy: something else well away from it
	var real: Vector3 = cand[0]
	var best = 1e9
	for p in cand:
		var e = strength(team, p, 30.0) + G.dist2d(p, home) / 200.0
		if e < best:
			best = e
			real = p
	var decoy = null
	var far = 45.0
	for p in cand:
		var d = G.dist2d(p, real)
		if d > far:
			far = d
			decoy = p
	if decoy == null:
		var to = G.flat(real - home).normalized()
		decoy = real + Vector3(to.z, 0, -to.x) * (50.0 if randf() < 0.5 else -50.0)
		decoy.x = clampf(decoy.x, G.world.bounds.position.x + 8.0, G.world.bounds.end.x - 8.0)
		decoy.z = clampf(decoy.z, G.world.bounds.position.y + 8.0, G.world.bounds.end.y - 8.0)
	# the squad nearest the decoy makes the noise; everyone else stages behind the real target
	var near_q = qs[0]
	var nd = 1e9
	for q in qs:
		var L = Squad.leader_of(q)
		if L != null and G.dist2d(L.pos, decoy) < nd:
			nd = G.dist2d(L.pos, decoy)
			near_q = q
	var stage: Vector3 = real + G.flat(home - real).normalized() * 55.0
	var main = []
	for q in qs:
		if q == near_q:
			_assign(q, "attack", decoy, home)
		else:
			_assign(q, "defend", stage, home)
			q["dig"] = false
			main.append(q)
	feints[team] = {"real": real, "decoy": decoy, "go": G.sim_time + randf_range(30.0, 45.0), "main": main, "home": home}
	feint_cd[team] = G.sim_time + randf_range(200.0, 320.0)
	Ops.coordinated(team, decoy, home)
	events["feint"] += 1
	G.ui.radio(team, "Command: second squad, make a lot of noise at %s. Everyone else, hold back at %s and wait for my word" % [AI.grid_ref(decoy), AI.grid_ref(stage)])
	return true

static func _feint_tick(t: int) -> void:
	var f = feints[t]
	if G.sim_time < f["go"]:
		return
	if not f.get("went", false):
		f["went"] = true
		for q in f["main"]:
			if Squad.leader_of(q) != null:
				_assign(q, "attack", f["real"], f["home"])
		var op: Dictionary = Ops.ops[t]
		op["next"] = 0.0
		Ops.coordinated(t, f["real"], f["home"])
		events["feint_go"] += 1
		G.ui.radio(t, "Command: they've taken the bait. All squads, go! Go! Hit %s" % AI.grid_ref(f["real"]))
		f["end"] = G.sim_time + 40.0
	elif G.sim_time > f["end"]:
		feints[t] = null

# ---------------------------------------------------------------- falling back to a second line
static func _regroup_check(team: int, qs: Array, home: Vector3) -> bool:
	if G.mode in ["horde", "laststand", "sabotage", "breakthrough"] or G.sim_time < 60.0:
		return false
	var mine = G.alive_count(team)
	var theirs = 0
	for t in range(G.team_count()):
		if t != team:
			theirs = maxi(theirs, G.alive_count(t))
	var r = regroup[team]
	if r == null:
		if mine >= 3 and theirs > 0 and mine < theirs * 0.5 and G.sim_time > float(Ops.ops[team].get("regroup_cd", 0.0)):
			var p = _second_line(team, home)
			regroup[team] = {"p": p, "t": G.sim_time}
			events["regroup"] += 1
			G.ui.radio(team, "Command: we can't hold here. All squads fall back to the second line at %s and regroup!" % AI.grid_ref(p))
			r = regroup[team]
		else:
			return false
	# strong enough again (reinforcements in), or waited long enough: go back in together
	if mine >= theirs * 0.8 or G.sim_time - r["t"] > 150.0:
		regroup[team] = null
		Ops.ops[team]["regroup_cd"] = G.sim_time + 120.0
		events["counter"] += 1
		G.ui.radio(team, "Command: we're back up to strength. All squads together, counter-attack!")
		return false
	for q in qs:
		_assign(q, "defend", r["p"], home)
		q["dig"] = true
	return true

# somewhere back toward home that can be held: the nearest point we still own on that side, else a
# line a quarter of the way out from base
static func _second_line(team: int, home: Vector3) -> Vector3:
	var best = null
	var bd = 1e9
	for pt in Obj.points:
		if pt["owner"] == team:
			var d = G.dist2d(pt["p"], home)
			if d < bd:
				bd = d
				best = pt["p"]
	if best != null and bd > 25.0:
		return best + G.flat(home - best).normalized() * 6.0
	var hq = Build.hq(team)
	if hq != null and Build.alive(hq):
		return hq["p"] + G.flat(G.world.capture - hq["p"]).normalized() * 18.0
	return home + G.flat(G.world.capture - home) * 0.25

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
	# the main effort goes where they're thinnest
	if job == "attack" and q.has("team") and G.dist2d(target, home) > 40.0:
		p += Ops.lane_off[q["team"]]
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
	if q.get("crew", false):
		# vehicle crews go where the nearest infantry squad has been sent, to support it
		var best = null
		var bd = 1e9
		for oq in _squads(s.team):
			var oc = oq.get("cmd")
			if oc == null or G.sim_time > oc["t"] + 10.0:
				continue
			var d = G.dist2d(oc["p"], s.pos)
			if d < bd:
				bd = d
				best = oc["p"]
		return best
	var c = q.get("cmd")
	if c == null or G.sim_time > c["t"] + 10.0:
		return null
	if c["job"] == "flank" and G.dist2d(s.pos, c["p"]) < 12.0:
		return null     # made it round the side: now fight normally
	return c["p"]
