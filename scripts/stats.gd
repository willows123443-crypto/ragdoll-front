class_name Stats
extends RefCounted
# Battle statistics for the after-action report. Records outlive the soldiers (bodies get cleaned up).

static var roster: Array = []
static var teams: Array = []
static var timeline: Array = []     # [game_time, [alive per team], [score per team]]
static var sample_t = 0.0

static func reset() -> void:
	roster = []
	teams = []
	for t in range(G.team_count()):
		teams.append({"spawned": 0, "deaths": 0, "kills": 0, "shots": 0, "hits": 0, "dmg": 0.0, "heads": 0, "routs": 0, "teamkills": 0, "heals": 0, "vehicles_lost": 0})
	timeline = []
	sample_t = 0.0

static func register(s) -> void:
	s.rec = {"name": s.sname, "team": s.team, "weapon": s.W["name"], "kills": 0, "deaths": 0, "shots": 0, "hits": 0,
		"dmg": 0.0, "heads": 0, "routs": 0, "heals": 0, "spawn_t": G.game_time, "death_t": -1.0, "player": false, "leader": false}
	roster.append(s.rec)
	if s.team < teams.size():
		teams[s.team]["spawned"] += 1

static func _ok(s) -> bool:
	return s != null and is_instance_valid(s) and s.rec != null

static func shot(s) -> void:
	if _ok(s):
		s.rec["shots"] += 1
		teams[s.team]["shots"] += 1

static func hit(attacker, victim, dmg: float) -> void:
	if _ok(attacker) and attacker.team != victim.team:
		attacker.rec["hits"] += 1
		attacker.rec["dmg"] += dmg
		teams[attacker.team]["hits"] += 1
		teams[attacker.team]["dmg"] += dmg

static func killed(victim, attacker, head: bool) -> void:
	if _ok(victim):
		victim.rec["deaths"] += 1
		victim.rec["death_t"] = G.game_time
		teams[victim.team]["deaths"] += 1
	if _ok(attacker):
		if attacker.team != victim.team:
			attacker.rec["kills"] += 1
			teams[attacker.team]["kills"] += 1
			if head:
				attacker.rec["heads"] += 1
				teams[attacker.team]["heads"] += 1
		else:
			teams[attacker.team]["teamkills"] += 1

static func rout(s) -> void:
	if _ok(s):
		s.rec["routs"] += 1
		teams[s.team]["routs"] += 1

static func healed(medic) -> void:
	if _ok(medic):
		medic.rec["heals"] += 1
		teams[medic.team]["heals"] += 1

static func step(dt: float) -> void:
	sample_t -= dt
	if sample_t > 0.0:
		return
	sample_t = 5.0
	var alive = []
	for t in range(G.team_count()):
		alive.append(G.alive_count(t))
	var pts = []
	var inc = []
	for t in range(G.team_count()):
		pts.append(Support.points[t] if t < Support.points.size() else 0)
		inc.append(Support.earned[t] if t < Support.earned.size() else 0)
	timeline.append([G.game_time, alive, G.score.duplicate(), pts, inc])

static func mvp(team: int = -1):
	var best = null
	for r in roster:
		if team >= 0 and r["team"] != team:
			continue
		var sc = r["kills"] * 100.0 + r["dmg"] + r["heals"] * 60.0
		if best == null or sc > best[0]:
			best = [sc, r]
	return best[1] if best != null and best[0] > 0.0 else null

static func vehicle_lost(team: int) -> void:
	if team < teams.size():
		teams[team]["vehicles_lost"] += 1
