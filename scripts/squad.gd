class_name Squad
extends RefCounted
# Squad-level tactics, run about once a second for every squad:
#   formations (wedge, line, column) while moving, fire-and-movement in two fireteams (one bounds while the
#   other covers), flanking an enemy that's pinned down, and clearing buildings (grenade in, then rush in).

const FORMS = {
	"wedge": [Vector2(0, 0), Vector2(-3, -3), Vector2(3, -3), Vector2(-6, -6), Vector2(6, -6), Vector2(-9, -9), Vector2(9, -9)],
	"line": [Vector2(0, 0), Vector2(-3.5, 0), Vector2(3.5, 0), Vector2(-7, 0), Vector2(7, 0), Vector2(-10.5, 0), Vector2(10.5, 0)],
	"column": [Vector2(0, 0), Vector2(0, -3), Vector2(0, -6), Vector2(0, -9), Vector2(0, -12), Vector2(0, -15), Vector2(0, -18)],
}

static var tick_t = 0.0
static var events = {"flank": 0, "breach": 0, "bound": 0, "suppress": 0, "smoke": 0, "fallback": 0}

static func step(dt: float) -> void:
	tick_t -= dt
	if tick_t > 0.0:
		return
	tick_t = 1.0
	RadioPack.step()
	Salvage.step()
	Tactics.screen_armour()
	for q in G.squads:
		q["members"] = q["members"].filter(func(m): return is_instance_valid(m) and m.state != "dead")
		if q["members"].is_empty() or q.get("guard", false):
			continue
		_bounding(q)
		_flank(q)
		_breach(q)
		_suppress(q)
		_smoke_cross(q)
		_fall_back(q)
		Tactics.squad(q)
		release_fallback(q)

static func leader_of(q):
	var l = q.get("leader")
	if l != null and is_instance_valid(l) and l.state != "dead":
		return l
	return null

static func index_of(s) -> int:
	if s.squad == null:
		return 0
	return maxi(0, s.squad["members"].find(s))

# where this soldier should be in the squad's formation (null if no formation applies)
static func slot(s):
	var q = s.squad
	if q == null:
		return null
	var L = leader_of(q)
	if L == null or L == s or L.vehicle != null:
		return null
	var form: String = q.get("form", "wedge")
	var offs: Array = FORMS[form]
	var i = mini(index_of(s), offs.size() - 1)
	if i <= 0:
		i = 1
	var heading = L.body_yaw
	if L.move_target != null:
		var to = G.flat(L.move_target - L.pos)
		if to.length() > 1.0:
			heading = atan2(to.x, to.z)
	var f = Vector3(sin(heading), 0, cos(heading))
	var r = Vector3(f.z, 0, -f.x)
	var o: Vector2 = offs[i]
	return L.pos + r * o.x + f * o.y

# pick a formation from the situation unless an order fixed one
static func auto_form(q) -> void:
	if q.get("form_fixed", false):
		return
	var L = leader_of(q)
	if L == null:
		return
	var on_road = G.world.on_road(L.pos.x, L.pos.z)
	var contact = L.has_seen and G.sim_time - L.seen_t < 20.0
	q["form"] = "line" if contact else ("column" if on_road else "wedge")

# ---------------------------------------------------------------- fire and movement
static func fireteam(s) -> int:
	return index_of(s) % 2

static func may_bound(s) -> bool:
	var q = s.squad
	if q == null or q["members"].size() < 3:
		return true
	return fireteam(s) == q.get("bound", 0)

static func _bounding(q) -> void:
	auto_form(q)
	if q["members"].size() < 3:
		return
	q["bound_t"] = q.get("bound_t", 0.0) + 1.0
	var b = q.get("bound", 0)
	var moving = 0
	for m in q["members"]:
		if fireteam(m) == b and m.move_target != null and not m.in_cover:
			moving += 1
	# swap roles once the bounding team has gone to ground, or after a while
	if (moving == 0 and q["bound_t"] > 3.0) or q["bound_t"] > 9.0:
		q["bound"] = 1 - b
		q["bound_t"] = 0.0
		events["bound"] += 1
		var L = leader_of(q)
		if L != null and L.has_seen and G.sim_time - L.seen_t < 10.0 and randf() < 0.5:
			Voice.say(L, "bound")

# ---------------------------------------------------------------- flanking a pinned enemy
static func _flank(q) -> void:
	if G.sim_time < q.get("flank_cd", 0.0) or q["members"].size() < 3:
		return
	var L = leader_of(q)
	if L == null or L.is_player:
		return
	var tgt = L.target
	if tgt == null or not is_instance_valid(tgt) or tgt.state == "dead":
		return
	# the target is pinned: in cover and under fire
	if not (tgt.in_cover or tgt.supp > 0.7) or G.dist2d(tgt.pos, L.pos) > 70.0:
		return
	var side = 1.0 if randf() < 0.5 else -1.0
	var to = G.flat(tgt.pos - L.pos).normalized()
	var perp = Vector3(to.z, 0, -to.x) * side
	var spot = tgt.pos + perp * 18.0 - to * 6.0
	if G.world.inside_any(spot.x, spot.z, 0.6):
		spot = tgt.pos + perp * 14.0
	var n = 0
	for m in q["members"]:
		if m != L and not m.is_player and m.state == "alive" and fireteam(m) == 1 - q.get("bound", 0) and n < 2:
			AI.release_cover(m)
			m.task = "flank_move"
			AI.go_to(m, spot + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)), 5.2)
			n += 1
	if n > 0:
		events["flank"] += 1
		q["flank_cd"] = G.sim_time + 30.0
		# the rest of the squad keeps the target's head down while the flankers move
		q["supp_until"] = G.sim_time + 14.0
		q["supp_tgt"] = tgt
		Voice.say(L, "flank")
		G.ui.radio(L.team, "%s: pinned an enemy at %s, flanking %s" % [L.sname, AI.grid_ref(tgt.pos), "right" if side > 0.0 else "left"])

# ---------------------------------------------------------------- base of fire
# while part of the squad flanks, the rest keep shooting at where the enemy is, seen or not
static func _suppress(q) -> void:
	if G.sim_time > q.get("supp_until", 0.0):
		return
	var tgt = q.get("supp_tgt")
	if tgt == null or not is_instance_valid(tgt) or tgt.state == "dead":
		q["supp_until"] = 0.0
		return
	var said = false
	for m in q["members"]:
		if m.is_player or m.state != "alive" or m.task == "flank_move" or m.ammo_frac() < 0.3:
			continue
		AI.add_intel(m, tgt, tgt.pos, 1.0, true)
		m.target = tgt
		if not said and randf() < 0.3:
			Voice.say(m, "suppress")
			said = true
	events["suppress"] += 1

# ---------------------------------------------------------------- smoke before open ground
static func _smoke_cross(q) -> void:
	if G.sim_time < q.get("smoke_cd", 0.0):
		return
	var L = leader_of(q)
	if L == null or L.is_player or L.move_target == null or not L.has_seen or G.sim_time - L.seen_t > 15.0:
		return
	var to = G.flat(L.move_target - L.pos)
	if to.length() < 18.0:
		return
	# open ground: hardly any cover along the way
	var mid = L.pos + to * 0.5
	if G.world.cover_near(mid, 8.0).size() >= 3:
		return
	var thrower = null
	for m in q["members"]:
		if m.state == "alive" and not m.is_player and m.smokes > 0 and G.dist2d(m.pos, L.pos) < 12.0:
			thrower = m
			break
	if thrower == null:
		return
	# the screen goes between the enemy and the crossing
	var th = G.flat(L.threat - mid)
	var spot = mid + (th.normalized() * minf(10.0, th.length() * 0.4) if th.length() > 1.0 else Vector3.ZERO)
	Combat.throw_grenade(thrower, spot, "smoke")
	Voice.say(thrower, "smoke")
	q["smoke_cd"] = G.sim_time + 40.0
	events["smoke"] += 1

# ---------------------------------------------------------------- pulling back when it's hopeless
static func _fall_back(q) -> void:
	if G.sim_time < q.get("fb_cd", 0.0) or G.mode in ["laststand", "horde", "siege"]:
		return
	var L = leader_of(q)
	if L == null or L.is_player:
		return
	var n = q["members"].size()
	q["peak"] = maxi(q.get("peak", 0), n)
	if n * 3 > q["peak"] or q["peak"] < 4:
		return
	# count the enemies they know are close
	var close = 0
	for e in L.intel:
		if is_instance_valid(e) and e.state == "alive" and G.sim_time - L.intel[e]["t"] < 10.0 and G.dist2d(L.intel[e]["p"], L.pos) < 45.0:
			close += 1
	if close < n * 2 + 1:
		return
	var back = G.world.fallback_point(L.team, L.pos)
	# the smoke goes out first, then everyone runs for it behind the screen
	for m in q["members"]:
		if not m.is_player and m.state == "alive" and m.smokes > 0:
			Tactics.cover_smoke(m, L.threat if L.has_threat else back * 2.0 - L.pos)
			break
	for m in q["members"]:
		if not m.is_player and m.state == "alive":
			AI.release_cover(m)
			m.order = {"mode": "move", "point": back + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))}
			m.decide_t = 0.0
	Voice.say(L, "fallback")
	G.ui.radio(L.team, "%s's squad is falling back to regroup" % L.sname)
	q["fb_cd"] = G.sim_time + 60.0
	q["fb_until"] = G.sim_time + 20.0
	q["peak"] = n
	events["fallback"] += 1

static func release_fallback(q) -> void:
	if q.get("fb_until", 0.0) > 0.0 and G.sim_time > q["fb_until"]:
		q["fb_until"] = 0.0
		for m in q["members"]:
			if not m.is_player and m.order != null and m.order.get("mode", "") == "move":
				m.order = null

# ---------------------------------------------------------------- clearing buildings
static func _building_at(p: Vector3):
	for b in G.world.buildings:
		if absf(p.x - b["x"]) < b["w"] / 2.0 and absf(p.z - b["z"]) < b["d"] / 2.0:
			return b
	for T in G.world.towers:
		if absf(p.x - T["x"]) < T["w"] / 2.0 and absf(p.z - T["z"]) < T["d"] / 2.0:
			return T
	return null

# inside: once nobody's left in sight in the room, "Clear!", and on to the next room of a big house
static func _clear_rooms(q) -> void:
	var bi = q.get("breach_b", -1)
	if bi < 0 or G.sim_time < q.get("clear_check", 1e9) or bi >= G.world.buildings.size():
		return
	var b = G.world.buildings[bi]
	var inside = []
	for m in q["members"]:
		if is_instance_valid(m) and m.state == "alive" and m.task == "clear" and Doors.building_at(m.pos) == bi:
			inside.append(m)
	var contact = false
	for m in q["members"]:
		if is_instance_valid(m) and m.vis_t != null and is_instance_valid(m.vis_t) and m.vis_t.state == "alive" and Doors.building_at(m.vis_t.pos) == bi:
			contact = true
	if contact:
		q["clear_check"] = G.sim_time + 3.0
		return
	if inside.is_empty():
		q["breach_b"] = -1
		return
	G.fx.callout(inside[0], G.pick(["Clear!", "Room clear!", "Clear left!"]))
	if inside.size() > 1:
		G.fx.callout(inside[1], G.pick(["Clear right!", "Clear!", "All clear here."]))
	var big = maxf(b["w"], b["d"]) > 11.0 and q.get("clear_room", 0) == 0
	if big:
		# the far room: across the house from the door they came in by
		var door = q.get("breach_door")
		var far = Vector3(b["x"], 0, b["z"])
		if door != null:
			var off = Vector3(b["x"], 0, b["z"]) - G.flat(door["c"])
			off.y = 0.0
			far = Vector3(b["x"], 0, b["z"]) + (Vector3(off.x, 0, 0) if b["w"] >= b["d"] else Vector3(0, 0, off.z)) * 0.0
			var ax = Vector3(1, 0, 0) if b["w"] >= b["d"] else Vector3(0, 0, 1)
			var sgn = -signf(G.flat(door["c"] - Vector3(b["x"], 0, b["z"])).dot(ax))
			if sgn == 0.0:
				sgn = 1.0
			far = Vector3(b["x"], 0, b["z"]) + ax * sgn * maxf(b["w"], b["d"]) * 0.28
		var k = 0
		for m in inside:
			var to = far + Vector3(randf_range(-1.2, 1.2), 0, randf_range(-1.2, 1.2))
			to.y = G.world.ground_y(to.x, to.z)
			AI.go_to(m, to, 4.6)
			k += 1
		G.fx.callout(inside[0], G.pick(["Next room!", "Moving through!", "On me, next room!"]))
		q["clear_room"] = 1
		q["clear_check"] = G.sim_time + 5.0
		return
	# done: carry on as normal
	for m in inside:
		m.task = null
		m.decide_t = 0.0
	q["breach_b"] = -1

static func _breach(q) -> void:
	var now = G.sim_time
	if now < q.get("breach_go", -1.0):
		return
	if q.get("breach_go", -1.0) > 0.0 and now >= q["breach_go"] and not q.get("breach_rushed", true):
		# grenade's gone off: everyone close rushes in
		q["breach_rushed"] = true
		var p: Vector3 = q["breach_p"]
		var said = false
		var door = q.get("breach_door")
		var k = 0
		for m in q["members"]:
			if not m.is_player and m.state == "alive" and m.vehicle == null and G.dist2d(m.pos, p) < 30.0:
				AI.release_cover(m)
				m.task = "clear"
				var to = p + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
				if door != null:
					# through the door in pairs: the first man buttonhooks left, the second goes right, the rest follow
					var nin: Vector3 = -door["n"]
					var al: Vector3 = door["along"]
					if k == 0:
						to = door["c"] + nin * 2.0 + al * 2.0
					elif k == 1:
						to = door["c"] + nin * 2.0 - al * 2.0
					else:
						to = door["c"] + nin * (1.2 + 0.6 * (k / 2)) + al * (0.7 if k % 2 == 0 else -0.7)
					to.y = G.world.ground_y(to.x, to.z)
				AI.go_to(m, to, 5.6)
				k += 1
				if not said:
					Voice.say(m, "breach")
					said = true
		q["breach_cd"] = now + 25.0
		if q.get("breach_b", -1) >= 0:
			q["clear_check"] = now + 4.5
			q["clear_room"] = 0
		return
	_clear_rooms(q)
	if now < q.get("breach_cd", 0.0):
		return
	var L = leader_of(q)
	if L == null or L.is_player:
		return
	# anyone in the squad looking at an enemy who is inside a building?
	var p = null
	for m in q["members"]:
		var t = m.vis_t
		if t != null and is_instance_valid(t) and t.state != "dead" and _building_at(t.pos) != null and G.dist2d(t.pos, m.pos) < 40.0:
			p = t.pos
			break
	if p == null:
		return
	# someone with a grenade, close enough to throw it in
	for m in q["members"]:
		if m.state == "alive" and not m.is_player and m.grenades > 0 and G.dist2d(m.pos, p) < 22.0 and G.dist2d(m.pos, p) > 6.0:
			Combat.throw_grenade(m, Doors.throw_point(m, p), "frag")
			Voice.say(m, "frag_in")
			events["breach"] += 1
			q["breach_p"] = p
			q["breach_go"] = now + 3.0
			q["breach_rushed"] = false
			q["breach_cd"] = now + 30.0
			return
