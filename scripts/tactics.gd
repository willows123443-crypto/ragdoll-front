class_name Tactics
extends RefCounted
# Squad tactics that need a memory or a bit of coordination:
# - pinned down: men under heavy fire go flat; the squad answers with a base of fire on whoever's
#   shooting and sends the other fireteam round the side
# - calling for help: a squad in trouble radios for it; the nearest squad that isn't busy comes,
#   and any mortar on the side is told where the attackers are
# - clearing buildings: stack up outside the door, grenade in, then go in together
# - defenders inside a building watch its doors and stairs instead of the wall
# - danger memory: each side remembers where its men were killed, keeps out of those places when
#   it can and smokes them when it has to cross

const DANGER_LIFE = 150.0

static var danger: Array = [[], [], [], []]       # per team: {"p", "w", "t"}
static var events = {"pinned": 0, "help": 0, "stack": 0, "danger_smoke": 0, "doorwatch": 0, "screen": 0, "cover_smoke": 0, "duck": 0, "bail": 0}

static func reset() -> void:
	danger = [[], [], [], []]
	for k in events:
		events[k] = 0

# ---------------------------------------------------------------- danger memory
static func note_death(s) -> void:
	if s.zombie or s.team < 0 or s.team >= danger.size():
		return
	var list: Array = danger[s.team]
	for d in list:
		if G.dist2d(d["p"], s.pos) < 10.0:
			d["w"] += 1.0
			d["t"] = G.sim_time
			return
	list.append({"p": s.pos, "w": 1.0, "t": G.sim_time})
	if list.size() > 40:
		list.pop_front()

# pinned under fire: not as bad as a death, but enough that men route round it next time
static func note_fire(s) -> void:
	if s.zombie or s.team < 0 or s.team >= danger.size():
		return
	var list: Array = danger[s.team]
	for d in list:
		if G.dist2d(d["p"], s.pos) < 8.0:
			d["w"] = minf(d["w"] + 0.25, 6.0)
			d["t"] = G.sim_time
			return
	list.append({"p": s.pos, "w": 0.35, "t": G.sim_time})
	if list.size() > 40:
		list.pop_front()

# how dangerous a place is for a team (0 = nothing known)
static func danger_at(p: Vector3, team: int) -> float:
	if team < 0 or team >= danger.size():
		return 0.0
	var w = 0.0
	for d in danger[team]:
		var age = G.sim_time - d["t"]
		if age > DANGER_LIFE:
			continue
		var dd = G.dist2d(d["p"], p)
		if dd < 12.0:
			w += d["w"] * (1.0 - dd / 12.0) * (1.0 - age / DANGER_LIFE)
	return w

static func _seg_dist(a: Vector3, b: Vector3, p: Vector3) -> float:
	var ab = G.flat(b - a)
	var L2 = ab.length_squared()
	if L2 < 0.01:
		return G.dist2d(a, p)
	var k = clampf(G.flat(p - a).dot(ab) / L2, 0.0, 1.0)
	return G.dist2d(a + ab * k, p)

# ---------------------------------------------------------------- per squad, about once a second
static func squad(q) -> void:
	var L = Squad.leader_of(q)
	if L == null or not is_instance_valid(L) or L.is_player or L.zombie:
		return
	_pinned(q, L)
	_call_help(q, L)
	_danger_cross(q, L)
	_stack_up(q, L)

static func _pinned(q, L) -> void:
	var pinned = []
	var shooter = null
	for m in q["members"]:
		if m.state == "alive" and not m.is_player and m.supp > 0.9:
			pinned.append(m)
			for c in [m.last_attacker, m.vis_t, m.target]:
				if shooter == null and c != null and is_instance_valid(c) and c.state != "dead" and c.team != m.team:
					shooter = c
	if pinned.size() < 2 or shooter == null or G.sim_time < q.get("pin_cd", 0.0):
		return
	q["pin_cd"] = G.sim_time + 25.0
	events["pinned"] += 1
	# everyone who can see where it's coming from puts fire on it, the rest go round
	q["supp_until"] = G.sim_time + 15.0
	q["supp_tgt"] = shooter
	for m in q["members"]:
		AI.add_intel(m, shooter, shooter.pos, 2.0, true)
	if q["members"].size() >= 4 and G.sim_time > q.get("flank_cd", 0.0):
		var to = G.flat(shooter.pos - L.pos).normalized()
		var side = 1.0 if (q["id"] + int(G.sim_time)) % 2 == 0 else -1.0
		var perp = Vector3(to.z, 0, -to.x) * side
		var spot = shooter.pos + perp * 16.0 - to * 5.0
		var n = 0
		for m in q["members"]:
			if m != L and not m.is_player and m.state == "alive" and m.supp < 1.0 and n < 2:
				AI.release_cover(m)
				m.task = "flank_move"
				m.prone_t = false
				AI.go_to(m, spot + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)), 5.0)
				n += 1
		if n > 0:
			q["flank_cd"] = G.sim_time + 30.0
	Voice.say(pinned[0], "suppressed")
	if randf() < 0.5:
		Voice.say(L, "suppress")

# a squad that's losing men fast, pinned, or outnumbered asks for help
static func _call_help(q, L) -> void:
	if G.sim_time < q.get("help_cd", 0.0):
		return
	var n = q["members"].filter(func(m): return is_instance_valid(m) and m.state == "alive").size()
	var foes = 0
	var near_foe = null
	for e in L.intel:
		var k = L.intel[e]
		if G.sim_time - k["t"] < 8.0 and G.dist2d(k["p"], L.pos) < 50.0:
			foes += 1
			near_foe = e
	var pinned = q["members"].filter(func(m): return is_instance_valid(m) and m.state == "alive" and m.supp > 1.0).size()
	var hurt = q.get("peak", n) - n >= 2 and G.sim_time - q.get("loss_t", -99.0) < 20.0
	if not ((foes >= n + 2) or pinned >= 2 or hurt) or near_foe == null:
		return
	q["help_cd"] = G.sim_time + 45.0
	events["help"] += 1
	# the nearest squad that isn't in a fight of its own comes over
	var best = null
	var bd = 130.0
	for o in G.squads:
		if o == q or o["team"] != q["team"] or o.get("guard", false) or o.get("helping_t", 0.0) > G.sim_time:
			continue
		var OL = Squad.leader_of(o)
		if OL == null or not is_instance_valid(OL) or OL.is_player:
			continue
		if OL.has_seen and G.sim_time - OL.seen_t < 10.0:
			continue
		var d = G.dist2d(OL.pos, L.pos)
		if d < bd:
			bd = d
			best = o
	if best != null:
		best["helping_t"] = G.sim_time + 40.0
		best["cmd"] = {"job": "support", "p": L.pos + G.flat(L.pos - near_foe.pos).normalized() * 6.0, "t": G.sim_time + 30.0}
		for m in best["members"]:
			if is_instance_valid(m) and m.state == "alive" and not m.is_player:
				m.decide_t = 0.0
		G.ui.radio(q["team"], "%s: we need help at %s! %s's squad is on the way" % [L.sname, AI.grid_ref(L.pos), Squad.leader_of(best).sname])
	else:
		G.ui.radio(q["team"], "%s: we need help at %s!" % [L.sname, AI.grid_ref(L.pos)])
	G.fx.callout(L, G.pick(["We need help here!", "Requesting support!", "We're getting hammered, send help!"]))
	# mortars on our side get told where the attackers are
	for v in G.vehicles:
		if v.team == q["team"] and not v.dead and v.kind == "mortar" and v.gunner() != null:
			AI.add_intel(v.gunner(), near_foe, near_foe.pos, 3.0, true)

# about to cross a place where men were killed: smoke it first, and keep low
static func _danger_cross(q, L) -> void:
	if L.move_target == null or G.sim_time < q.get("dsmoke_cd", 0.0):
		return
	var worst = null
	var ww = 1.5
	for d in danger[L.team]:
		if G.sim_time - d["t"] > DANGER_LIFE:
			continue
		if _seg_dist(L.pos, L.move_target, d["p"]) < 10.0 and d["w"] > ww:
			ww = d["w"]
			worst = d
	if worst == null:
		return
	var thrower = null
	for m in q["members"]:
		if m.state == "alive" and not m.is_player and m.smokes > 0 and G.dist2d(m.pos, worst["p"]) < 35.0:
			thrower = m
			break
	q["dsmoke_cd"] = G.sim_time + 35.0
	if thrower == null:
		return
	Combat.throw_grenade(thrower, worst["p"], "smoke")
	G.fx.callout(thrower, G.pick(["Smoke that corner, we lost men there!", "Watch it, that spot's covered! Smoke!", "Don't cross there in the open!"]))
	events["danger_smoke"] += 1

# an enemy holed up in a building: get to the door, stack up, grenade in, then all go in together
static func _stack_up(q, L) -> void:
	if q.get("stack") != null:
		var sk = q["stack"]
		var go = G.sim_time > sk["t"]
		if not go:
			var ready = 0
			for m in sk["men"]:
				if is_instance_valid(m) and m.state == "alive" and G.dist2d(m.pos, sk["at"]) < 3.5:
					ready += 1
			go = ready >= mini(2, sk["men"].size())
		if go:
			var thrower = null
			for m in sk["men"]:
				if is_instance_valid(m) and m.state == "alive" and m.grenades > 0:
					thrower = m
					break
			if thrower != null:
				Combat.throw_grenade(thrower, sk["in"], "frag")
				Voice.say(thrower, "frag_in")
			q["breach_p"] = sk["in"]
			q["breach_go"] = G.sim_time + (2.6 if thrower != null else 0.3)
			q["breach_rushed"] = false
			q["breach_cd"] = G.sim_time + 30.0
			q["stack"] = null
		return
	if G.sim_time < q.get("breach_cd", 0.0) or G.sim_time < q.get("stack_cd", 0.0):
		return
	var tp = null
	for m in q["members"]:
		var t = m.vis_t if m.vis_t != null else m.target
		if t != null and is_instance_valid(t) and t.state != "dead" and Doors.building_at(t.pos) >= 0 and G.dist2d(t.pos, m.pos) < 45.0 and G.dist2d(t.pos, m.pos) > 8.0:
			tp = t.pos
			break
	if tp == null:
		return
	var bi = Doors.building_at(tp)
	var door = null
	var bd = 1e9
	for d in Doors.doors:
		if d["b"] == bi:
			var dd = G.dist2d(d["c"], L.pos)
			if dd < bd:
				bd = dd
				door = d
	if door == null or bd > 60.0:
		return
	q["stack_cd"] = G.sim_time + 40.0
	var at: Vector3 = door["c"] + door["n"] * 1.6
	at.y = G.world.ground_y(at.x, at.z)
	var men = []
	var side: Vector3 = door["along"]
	for m in q["members"]:
		if m.state == "alive" and not m.is_player and m.vehicle == null and men.size() < 4:
			AI.release_cover(m)
			m.task = "clear"
			var k = men.size()
			AI.go_to(m, at + side * ((0.9 + 0.6 * (k / 2)) * (1.0 if k % 2 == 0 else -1.0)), 4.6)
			men.append(m)
	if men.is_empty():
		return
	q["stack"] = {"men": men, "at": at, "in": door["c"] - door["n"] * 2.5, "t": G.sim_time + 12.0}
	q["breach_door"] = door
	q["breach_b"] = bi
	events["stack"] += 1
	G.fx.callout(L, G.pick(["Stack up on the door!", "On the door, get ready!", "Stack up, we're going in!"]))

# ---------------------------------------------------------------- defenders inside: watch the way in
static func door_watch(s) -> bool:
	if s.vis_t != null or s.is_player or s.zombie:
		return false
	var bi = Doors.building_at(s.pos)
	if bi < 0:
		return false
	var near = false
	for e in s.intel:
		var k = s.intel[e]
		if G.sim_time - k["t"] < 12.0 and G.dist2d(k["p"], s.pos) < 30.0:
			near = true
			break
	if not near:
		return false
	# face the nearest door of this building (or the top of the stairs, upstairs) and wait
	var look = null
	var bd = 1e9
	var T = s.tower
	if T != null and AI.upstairs(s) and T.has("stair_top"):
		look = T["stair_top"]
	else:
		for d in Doors.doors:
			if d["b"] == bi:
				var dd = G.dist2d(d["c"], s.pos)
				if dd < bd and dd > 1.5:
					bd = dd
					look = d["c"]
	if look == null:
		return false
	s.aim_yaw = G.turn_to(s.aim_yaw, atan2(look.x - s.pos.x, look.z - s.pos.z), 3.0 * G.DT)
	s.ready_ = true
	s.crouch_t = 0.6
	events["doorwatch"] += 1
	return true

# ---------------------------------------------------------------- smoke
# a tank that enemy rocket men have spotted gets a smoke screen thrown between it and them by the
# infantry walking with it
static func screen_armour() -> void:
	for v in G.vehicles:
		if v.dead or not (v.spec["tracked"] or v.kind in ["armoredcar", "halftrack"]) or v.spec.get("air", false) or v.spec.get("static", false):
			continue
		if G.sim_time - v.get_meta("screen_t", -99.0) < 22.0:
			continue
		var hunter = null
		var hd = 85.0
		for e in G.soldiers:
			if e.team == v.team or e.state != "alive" or e.vis_veh != v:
				continue
			if not (e.W["rocket"] or e.W["ap"] or e.fausts > 0 or e.rockets > 0):
				continue
			var d = G.dist2d(e.pos, v.pos)
			if d < hd:
				hd = d
				hunter = e
		if hunter == null or hd < 10.0:
			continue
		var by = null
		var bd = 28.0
		for f in G.soldiers:
			if f.team != v.team or f.state != "alive" or f.vehicle != null or f.is_player or f.smokes <= 0 or f.throw_t > 0.0:
				continue
			var d2 = G.dist2d(f.pos, v.pos)
			if d2 < bd:
				bd = d2
				by = f
		if by == null:
			continue
		# between the tank and the man with the rocket, as far as he can throw it
		var dir = G.flat(hunter.pos - v.pos).normalized()
		var at = v.pos + dir * minf(hd * 0.4, 16.0)
		if G.dist2d(at, by.pos) > 24.0:
			at = by.pos + G.flat(at - by.pos).normalized() * 24.0
		Combat.throw_grenade(by, at, "smoke")
		v.set_meta("screen_t", G.sim_time)
		events["screen"] += 1
		G.fx.callout(by, G.pick(["Rocket team on the tank! Smoke!", "They've seen the tank, screen it!", "Smoke out front of the armour!"]))

# men pulling back under fire throw smoke between themselves and the enemy first
static func cover_smoke(s, threat: Vector3) -> void:
	if s.smokes <= 0 or s.is_player or s.throw_t > 0.0 or s.vehicle != null:
		return
	var dT = G.dist2d(threat, s.pos)
	if dT > 80.0 or dT < 8.0:
		return
	var q = s.squad
	if q != null and G.sim_time - q.get("cover_smoke_t", -99.0) < 18.0:
		return
	if q != null:
		q["cover_smoke_t"] = G.sim_time
	Combat.throw_grenade(s, s.pos + G.flat(threat - s.pos).normalized() * minf(dT * 0.35, 14.0), "smoke")
	events["cover_smoke"] += 1
	G.fx.callout(s, G.pick(["Smoke out! Fall back!", "Popping smoke, move!", "Smoke! Pull back behind it!"]))
