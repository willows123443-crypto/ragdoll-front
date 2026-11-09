class_name Commander
extends RefCounted
# A commander for each AI side. Every so often it looks at what the team knows and hands squads jobs:
# attack the front objective, defend a threatened point, swing round a flank, or wait in reserve.
# Each side has an officer; while he's alive orders come quickly and soldiers nearby fight harder.

static var timers: Array = []

static func reset() -> void:
	timers = []
	for t in range(G.team_count()):
		timers.append(randf_range(6.0, 10.0))

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
		var off = officer(t)
		timers[t] = 14.0 if off != null else 30.0
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
	if Obj.chain() or G.mode == "capture":
		var f = Obj.front(team) if Obj.chain() else 0
		var threatened = -1
		for i in range(Obj.points.size()):
			var pt = Obj.points[i]
			if pt["owner"] == team and pt["n"][(team + 1) % 2] > 0:
				threatened = i
		for k in range(qs.size()):
			var q = qs[k]
			var job = "attack"
			if threatened >= 0 and k % 3 == 2:
				job = "defend"
			elif qs.size() >= 4 and k == qs.size() - 1:
				job = "flank"
			_assign(q, job, Obj.points[threatened]["p"] if job == "defend" else Obj.points[f]["p"], home)
			if not said:
				said = true
				G.ui.radio(team, "Command: %d squad%s pushing point %s%s" % [qs.size() - (1 if threatened >= 0 else 0), "s" if qs.size() > 1 else "", Obj.points[f]["name"], ", one holding %s" % Obj.points[threatened]["name"] if threatened >= 0 else ""])
		return
	# deathmatch / sandbox: hit the enemy where they are, with one squad going round the side
	var ec = _enemy_center(team)
	if ec == null:
		return
	for k in range(qs.size()):
		var q = qs[k]
		var job = "attack"
		if qs.size() >= 3 and k == qs.size() - 1:
			job = "flank"
		elif qs.size() >= 4 and k == 0:
			job = "defend"
		_assign(q, job, ec if job != "defend" else home + G.flat(ec - home).normalized() * 25.0, home)
	G.ui.radio(team, "Command: enemy concentrating near %s, all squads engage" % AI.grid_ref(ec))

static func _assign(q, job: String, target: Vector3, home: Vector3) -> void:
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
