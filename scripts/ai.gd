class_name AI
extends RefCounted
# Soldier brains: what they know, where they take cover, how they move and when they shoot.

# ---------------------------------------------------------------- knowledge
# Soldiers only know about enemies they have seen or heard, or that a teammate reported:
# squadmates share contacts by radio, anyone else has to be within shouting range.
static func add_intel(s, enemy, at: Vector3, noise: float, seen: bool) -> void:
	if enemy == null or not is_instance_valid(enemy) or enemy.team == s.team or enemy.state == "dead":
		return
	var e = s.intel.get(enemy)
	if e != null and e["seen"] and G.sim_time - e["t"] < 1.5 and not seen:
		return
	var p = Vector3(at.x + randf_range(-noise, noise), at.y, at.z + randf_range(-noise, noise))
	s.intel[enemy] = {"p": p, "t": G.sim_time, "seen": seen}

static func share_intel(s, enemy, at: Vector3) -> void:
	for o in G.soldiers:
		if o == s or o.team != s.team or o.state == "dead" or o.state == "down":
			continue
		var radio = o.squad != null and o.squad == s.squad
		if radio or o.pos.distance_squared_to(s.pos) < 35.0 * 35.0:
			add_intel(o, enemy, at, 1.0 if radio else 2.5, false)

static func best_intel(s):
	var best = null
	var bs = 1e9
	for e in s.intel.keys():
		var k = s.intel[e]
		var age = G.sim_time - k["t"]
		if age > 25.0 or not is_instance_valid(e) or e.state == "dead":
			s.intel.erase(e)
			continue
		var sc = k["p"].distance_to(s.pos) * 0.5 + age * 4.0
		if sc < bs:
			bs = sc
			best = k
	return best

static func team_intel_center(team: int):
	var sum = Vector3.ZERO
	var n = 0
	for s in G.soldiers:
		if s.team != team or s.state == "dead":
			continue
		for k in s.intel.values():
			if G.sim_time - k["t"] < 20.0:
				sum += k["p"]
				n += 1
	if n == 0:
		return null
	return sum / n

static func bearing_text(from: Vector3, to: Vector3) -> String:
	var dirs = ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]
	var a = atan2(to.x - from.x, -(to.z - from.z))
	var i = int(round(fposmod(a, TAU) / (PI / 4.0))) % 8
	return dirs[i]

static func order_of(s) -> Dictionary:
	return s.order if s.order != null else G.orders[s.team]

# men spawned together (a squad you drop in, a truck of recruits, a vehicle's crew) form their own squad
# instead of topping up whatever squad happens to have room
static var batch_stack: Array = []
const CREW = {"guard": true, "follow": true, "crew": true}

static func batch_begin(extra: Dictionary = {}, q = null) -> void:
	batch_stack.push_back({"extra": extra, "q": q})

static func batch_end():
	if batch_stack.is_empty():
		return null
	return batch_stack.pop_back()["q"]

static func new_squad(team: int, extra: Dictionary = {}) -> Dictionary:
	var q = {"team": team, "members": [], "id": G.squads.size(), "form": "wedge", "bound": 0}
	q.merge(extra)
	G.squads.append(q)
	return q

static func assign_squad(s) -> void:
	var q = null
	if not batch_stack.is_empty():
		var b = batch_stack.back()
		var bq = b["q"]
		if bq != null:
			bq["members"] = bq["members"].filter(func(m): return is_instance_valid(m) and m.state != "dead")
		if bq == null or bq["team"] != s.team or bq["members"].size() >= (4 if b["extra"].get("crew", false) else 6) or not (bq in G.squads):
			bq = new_squad(s.team, b["extra"].merged({"sealed": true}))
			b["q"] = bq
		_into(s, bq)
		return
	for sq in G.squads:
		if sq["team"] == s.team and not sq.get("guard", false) and not sq.get("sealed", false):
			sq["members"] = sq["members"].filter(func(m): return is_instance_valid(m) and m.state != "dead")
			if sq["members"].size() < 5:
				q = sq
				break
	if q == null:
		q = new_squad(s.team)
	_into(s, q)

static func _into(s, q: Dictionary) -> void:
	if s.squad != null and s.squad != q:
		s.squad["members"].erase(s)
		if s.squad.get("leader") == s:
			s.squad["leader"] = null
			s.set_leader(false)
	q["members"].append(s)
	s.squad = q
	var ld = q.get("leader")
	if ld == null or not is_instance_valid(ld) or ld.state == "dead":
		q["leader"] = s
		s.set_leader(true)
		s.flares = 3
	s.role = "flanker" if q["members"].size() == 3 else "rifleman"

static func squad_movers(q) -> int:
	var n = 0
	for m in q["members"]:
		if is_instance_valid(m) and m.state == "alive" and m.move_target != null and not m.in_cover and not m.is_player:
			n += 1
	return n

static func objective_for(s) -> Vector3:
	var o = order_of(s)
	if o["mode"] == "move" and o["point"] != null:
		return o["point"]
	var mt = Modes.target_for(s)
	if mt != null:
		return mt
	var ct = Commander.target_for(s)
	if ct != null:
		return ct
	if Obj.uses_points() and not Obj.points.is_empty():
		var i = squad_point(s)
		if i >= 0:
			# everyone takes a different patch of the point rather than its exact centre
			var a = float(s.id) * 2.39
			return Obj.points[i]["p"] + Vector3(cos(a), 0, sin(a)) * (2.5 + float(s.id % 4) * 1.2)
	var c = team_intel_center(s.team)
	# commander mode: the war is won at the enemy HQ, so that's where everyone's heading in the end
	if G.mode == "commander" and G.team_count() == 2:
		var eh = Build.hq((s.team + 1) % 2)
		# (old sightings don't hold them back: with nothing seen for a while they push on for the HQ)
		if eh != null and Build.alive(eh) and (c == null or G.dist2d(c, s.pos) > 70.0 or G.sim_time - s.seen_t > 25.0):
			var a3 = float(s.id) * 2.39
			return eh["p"] + Vector3(cos(a3), 0, sin(a3)) * (16.0 + float(s.id % 5) * 3.0)
	if c != null:
		return c
	return G.world.capture if G.dist2d(s.pos, G.world.capture) > 18.0 else G.world.rally_point((s.team + 1) % G.team_count())

# which control point a soldier's squad is working on (attack the front, or hold a threatened point)
static func squad_point(s) -> int:
	var n = Obj.points.size()
	if n == 1:
		return 0
	var q = s.squad
	if q != null and G.sim_time < q.get("obj_t", -1.0) and q.get("obj", -1) >= 0 and q.get("obj", -1) < n:
		return q["obj"]
	var team = s.team
	var pick = Obj.front(team)
	var qi = 0
	if q != null:
		var k = 0
		for sq in G.squads:
			if sq["team"] == team:
				if sq == q:
					qi = k
				k += 1
	if G.mode == "assault" and team == 1:
		# defenders: most squads hold the point under attack, the rest the next one back
		var f = Obj.front(0)
		pick = f if qi % 3 != 2 or f >= n - 1 else f + 1
	else:
		# hold a point of ours that has enemies on it
		for i in range(n):
			var pt = Obj.points[i]
			if pt["owner"] == team and pt["n"][(team + 1) % 2] > 0 and qi % 3 == 2:
				pick = i
				break
	if q != null:
		q["obj"] = pick
		q["obj_t"] = G.sim_time + 8.0
	return pick

# ---------------------------------------------------------------- cover
static func release_cover(s) -> void:
	if s.cover != null and s.cover.owner_s == s:
		s.cover.owner_s = null
	s.cover = null
	s.in_cover = false
	s.want_peek = false
	s.lean_t = 0.0
	s.force_peek = false

static func take_cover(s, cp) -> void:
	_cover_me(s, cp.p)
	release_cover(s)
	cp.owner_s = s
	s.cover = cp
	s.in_cover = false
	s.cover_time = 0.0
	s.cover_bad = 0
	s.prone_t = false
	go_to(s, cp.p, 4.8)

# about to dash across open ground under fire: "Cover me!", and the mates nearby open up on the enemy
static func _cover_me(s, to: Vector3) -> void:
	if s.is_player or s.squad == null or s.zombie or G.sim_time - s.seen_t > 6.0 or G.dist2d(to, s.pos) < 8.0:
		return
	if G.sim_time < s.get_meta("cover_me_t", -99.0):
		return
	s.set_meta("cover_me_t", G.sim_time + 14.0)
	var n = 0
	for m in s.squad["members"]:
		if m == s or not is_instance_valid(m) or m.state != "alive" or m.vehicle != null or m.is_player:
			continue
		if G.dist2d(m.pos, s.pos) < 24.0 and m.move_target == null and m.ammo_frac() > 0.25:
			m.set_meta("cover_fire_t", G.sim_time + 3.5)
			m.last_seen = s.last_seen
			m.seen_t = maxf(m.seen_t, s.seen_t)
			n += 1
	if n > 0:
		G.fx.callout(s, G.pick(["Cover me!", "Moving! Cover me!", "Cover me, I'm going!"]))
		Squad.events["suppress"] += 1

static func cover_safe(cp, threat: Vector3) -> bool:
	return G.blocked(Vector3(threat.x, threat.y + 1.5, threat.z), Vector3(cp.p.x, cp.p.y + 1.0, cp.p.z))

static func peek_pos(cp) -> Vector3:
	if cp.type == "corner":
		return Vector3(cp.p.x + cp.t.x * 0.7, cp.p.y + 1.45, cp.p.z + cp.t.z * 0.7)
	if cp.type == "wall":
		return Vector3(cp.p.x + cp.t.x * cp.side, cp.p.y + 1.45, cp.p.z + cp.t.z * cp.side)
	return Vector3(cp.p.x, cp.p.y + 1.55, cp.p.z)

# the direction a soldier leans along a wall: toward a window, doorway, gap or broken top
static func wall_lean_dir(cp) -> Vector3:
	return cp.t * signf(cp.side)

static func can_fire_from(cp, threat: Vector3) -> bool:
	var tp = Vector3(threat.x, threat.y + 1.2, threat.z)
	if cp.type == "wall":
		# lean (and shuffle) up to a metre and a bit either way, to a window, doorway or gap
		var first = signf(cp.side) if cp.side != 0.0 else 1.0
		for sd in [first * 0.8, -first * 0.8, first * 1.25, -first * 1.25]:
			var pp = Vector3(cp.p.x + cp.t.x * sd, cp.p.y + 1.45, cp.p.z + cp.t.z * sd)
			if not G.blocked(pp, tp):
				cp.side = sd
				return true
		cp.side = 0.0
		return false
	return not G.blocked(peek_pos(cp), tp)

static func cover_free(cp, s) -> bool:
	return cp.owner_s == null or cp.owner_s == s or not is_instance_valid(cp.owner_s) or cp.owner_s.state == "dead"

static func find_cover(s, threat: Vector3, mode: String):
	var dme = G.dist2d(s.pos, threat)
	var max_d = 10.0 if mode == "hold" else (20.0 if mode == "defend" else 32.0)
	var ideal = (s.W["range"][0] + s.W["range"][1]) / 2.0
	var tdir = G.flat(threat - s.pos) / maxf(dme, 0.01)
	var cands: Array = []
	var i = 0
	for cp in G.world.cover_near(s.pos, max_d):
		i += 1
		if cp.upper or not cover_free(cp, s) or cp.ban > G.sim_time:
			continue
		var dx = cp.p.x - s.pos.x
		var dz = cp.p.z - s.pos.z
		var dm = Vector2(dx, dz).length()
		if dm > max_d:
			continue
		var ex = threat.x - cp.p.x
		var ez = threat.z - cp.p.z
		var de = Vector2(ex, ez).length()
		if de < 6.0:
			continue
		if (ex * cp.n.x + ez * cp.n.z) / de > -0.3:
			continue
		var sc = 0.0
		if mode == "advance":
			if de > dme - 5.0:
				continue
			sc = dm + de * 0.4
		elif mode == "flank":
			if de > dme - 3.0:
				continue
			var lat = absf(dx * tdir.z - dz * tdir.x)
			sc = dm * 0.6 + de * 0.3 - minf(lat, 15.0) * 1.2
		elif mode == "retreat":
			if de < dme + 4.0:
				continue
			sc = dm
		elif mode == "hold":
			sc = dm
		else:
			sc = dm + maxf(0.0, de - dme) * 0.8 + (10.0 if de < 12.0 else 0.0)
		var hide = s.hp < 40.0 or s.supp > 1.1
		# men like to fight from inside buildings: thick walls, windows to shoot from, a roof over them
		if cp.get_meta("inside", -1) != 0:
			var ins = cp.get_meta("inside", -1)
			if ins == -1:
				ins = 1 if Squad._building_at(cp.p) != null else 0
				cp.set_meta("inside", ins)
			if ins == 1:
				if mode == "hold" or mode == "defend":
					sc -= 9.0 if hide else 7.0
				elif mode != "retreat":
					sc -= 3.5
		sc += absf(de - ideal) * 0.12
		sc += Tactics.danger_at(cp.p, s.team) * 4.0      # not where our men keep getting killed
		sc += float((i * 7919 + s.id * 31) % 100) / 50.0
		cands.append([sc, cp])
	cands.sort_custom(func(a, b): return a[0] < b[0])
	var best = null
	var bs = 1e9
	for k in range(mini(6, cands.size())):
		var cp = cands[k][1]
		if not cover_safe(cp, threat):
			continue
		var sc2 = cands[k][0]
		if cp.type == "wall":
			sc2 += -1.0 if can_fire_from(cp, threat) else 2.0
		elif not can_fire_from(cp, threat):
			sc2 += 6.0
		if sc2 < bs:
			bs = sc2
			best = cp
	return best

# how badly we outnumber them round here: our men within 40 m against the enemies we know of near the threat
static func odds(s, threat: Vector3) -> float:
	var f = 0
	for o in G.soldiers:
		if o.team == s.team and o.state == "alive" and o.vehicle == null and G.dist2d(o.pos, s.pos) < 40.0:
			f += 1
	var e = 0
	for k in s.intel:
		var r = s.intel[k]
		if is_instance_valid(k) and k.state != "dead" and G.sim_time - r["t"] < 20.0 and G.dist2d(r["p"], threat) < 50.0:
			e += 1
	return float(f) / float(maxi(1, e))

# the next bit of cover on the way to a point: a real bound forward (8 to 25 m), not a shuffle
static func hop_cover(s, goal: Vector3):
	var dg = G.dist2d(s.pos, goal)
	var best = null
	var bs = 1e9
	for cp in G.world.cover_near(s.pos, 28.0):
		if cp.upper or not cover_free(cp, s) or cp.ban > G.sim_time:
			continue
		var dm = G.dist2d(cp.p, s.pos)
		var de = G.dist2d(cp.p, goal)
		if dm < 6.0 or de > dg - 7.0:
			continue
		var sc = absf(dm - 15.0) + de * 0.15 + Tactics.danger_at(cp.p, s.team) * 4.0 + float((cp.get_instance_id() + s.id) % 7) * 0.4
		if sc < bs:
			bs = sc
			best = cp
	return best

# commander mode: men who've fought their way up to the enemy HQ and see nobody to shoot set about
# destroying it: satchels and grenades if they have them, rockets, and everyone else shoots it to pieces
static func raze_tick(s) -> bool:
	if G.mode != "commander" or s.vehicle != null or s.is_player or s.zombie or s.task in ["medic", "stretcher", "construct", "get_radio", "salvage"]:
		return false
	if s.vis_t != null or G.sim_time - s.seen_t < 4.0 or ClassAI.busy(s):
		if s.task == "raze":
			s.task = null
		return false
	var o = order_of(s)
	if o["mode"] == "move" and not o.get("arrived", false):
		return false
	var hq = Build.hq((s.team + 1) % 2)
	if hq == null or not Build.alive(hq):
		return false
	var hp: Vector3 = hq["p"]
	var d = G.dist2d(s.pos, hp)
	if d > 48.0:
		if s.task == "raze":
			s.task = null
		return false
	# aim at what's left of it
	var aim = hp + Vector3(0, 1.2, 0)
	var bd = 1e9
	for c in hq["cols"]:
		if c.alive and c.lo.y - c.gy < 1.0:
			var cc = (c.lo + c.hi) * 0.5
			var dd = G.dist2d(cc, s.pos)
			if dd < bd:
				bd = dd
				aim = Vector3(cc.x, c.lo.y + minf(1.3, (c.hi.y - c.lo.y) * 0.6), cc.z)
	s.set_meta("raze_p", aim)
	s.set_meta("raze_st", hq)
	s.decide_t = randf_range(1.5, 2.5)
	if s.task != "raze":
		s.task = "raze"
		G.fx.callout(s, G.pick(["That's their HQ! Bring it down!", "Hit the HQ!", "Blow it up!"]))
	if s.satchels > 0:
		if ClassAI._satchel_site(s, 42.0) >= 0:
			s.task = "raze"
			return true
	if s.grenades > 0 and d < 22.0 and s.throw_t <= 0.0 and randf() < 0.4 and not G.blocked(s.head_pos(), aim):
		Combat.throw_grenade(s, aim, "frag")
		return true
	# get within easy range, behind something if there's cover about
	var want = 26.0 if not s.W["rocket"] else 34.0
	if d > want + 6.0 or G.blocked(s.head_pos(), aim):
		var c2 = find_cover(s, aim, "advance")
		if c2 != null and G.dist2d(c2.p, hp) < d - 3.0:
			take_cover(s, c2)
		else:
			release_cover(s)
			go_to(s, hp + G.flat(s.pos - hp).normalized() * want + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)), 4.4)
		s.task = "raze"
		return true
	stop_move(s)
	s.kneel = true
	s.aim_yaw = atan2(aim.x - s.pos.x, aim.z - s.pos.z)
	return true

# the free spots inside buildings near a point that look out towards the threat, a window if there is one
static func garrison_cover(s, center: Vector3, threat: Vector3, rad: float):
	var cands = []
	for cp in G.world.cover_near(center, rad):
		if cp.upper or not cover_free(cp, s) or cp.ban > G.sim_time:
			continue
		var ins = cp.get_meta("inside", -1)
		if ins == -1:
			ins = 1 if Squad._building_at(cp.p) != null else 0
			cp.set_meta("inside", ins)
		if ins != 1:
			continue
		var de = G.dist2d(threat, cp.p)
		if de < 8.0 or ((threat.x - cp.p.x) * cp.n.x + (threat.z - cp.p.z) * cp.n.z) / de > -0.3:
			continue
		cands.append([G.dist2d(cp.p, center) * 0.5 + G.dist2d(cp.p, s.pos) * 0.3 + Tactics.danger_at(cp.p, s.team) * 4.0 + float((cp.get_instance_id() + s.id * 17) % 10) * 0.2, cp])
	if cands.is_empty():
		return null
	cands.sort_custom(func(a, b): return a[0] < b[0])
	for k in range(mini(5, cands.size())):
		if can_fire_from(cands[k][1], threat):
			return cands[k][1]
	return cands[0][1]

static func find_post(s, threat: Vector3):
	var best = null
	var bs = 1e9
	for T in G.world.towers:
		for cp in T["cps"]:
			if not cover_free(cp, s) or cp.ban > G.sim_time:
				continue
			var d = G.dist2d(cp.p, s.pos)
			if d > 70.0:
				continue
			var de = G.dist2d(threat, cp.p)
			if de < 15.0:
				continue
			if ((threat.x - cp.p.x) * cp.n.x + (threat.z - cp.p.z) * cp.n.z) / de > -0.3:
				continue
			var sc = d + absf(de - 60.0) * 0.3
			if sc < bs:
				bs = sc
				best = cp
	return best

static func take_post(s, cp) -> void:
	release_cover(s)
	cp.owner_s = s
	s.cover = cp
	s.tower = cp.tower
	s.task = "post"
	s.prone_t = false
	s.route = {"pts": [cp.tower["stair_bottom"], cp.tower["stair_top"], cp.p], "i": 0, "nav": true}
	go_to(s, s.route["pts"][0], 4.4)

static func upstairs(s) -> bool:
	return s.pos.y - G.world.ground_y(s.pos.x, s.pos.z) > 1.5

static func go_downstairs(s) -> void:
	var T = s.tower
	if T == null:
		for t2 in G.world.towers:
			if absf(s.pos.x - t2["x"]) < t2["w"] / 2.0 + 0.5 and absf(s.pos.z - t2["z"]) < t2["d"] / 2.0 + 0.5:
				T = t2
	release_cover(s)
	stop_move(s)
	if T == null:
		return
	s.route = {"pts": [T["stair_top"], T["stair_bottom"], T["inside"]], "i": 0, "nav": false}
	s.task = "descend"

# ---------------------------------------------------------------- movement
static func go_to(s, point: Vector3, speed: float) -> void:
	if s.move_target != null and s.move_target.distance_squared_to(point) < 0.25 and not s.path.is_empty():
		s.speed_t = speed
		return
	# don't head straight back to a spot we just got stuck on
	if s.bad_spot != null and G.sim_time < s.bad_t and G.dist2d(point, s.bad_spot) < 2.5:
		var a = randf() * TAU
		var alt = point + Vector3(cos(a), 0, sin(a)) * randf_range(3.0, 5.0)
		if not G.world.inside_any(alt.x, alt.z, 0.45):
			point = alt
	# at night, out of contact, men pick their way forward slower
	if speed > 3.0 and s.vis_t == null and G.sim_time - s.seen_t > 8.0 and s.task != "charge" and s.task != "flee" and G.main.is_night():
		speed *= 0.72
	s.move_target = point
	s.path = []
	s.need_path = true
	s.speed_t = speed
	s.prog_t = 0.0
	s.prog_p = s.pos
	s.stuck_n = 0

static func stop_move(s) -> void:
	s.move_target = null
	s.path = []
	s.need_path = false

static func follow_path(s) -> String:
	if s.scramble != null:
		var sc = s.scramble
		sc["k"] += G.DT / sc["dur"]
		var k = clampf(sc["k"], 0.0, 1.0)
		var hop = sin(k * PI) * 0.35
		s.pos = sc["a"].lerp(sc["b"], k) + Vector3(0, hop, 0)
		s.vel = Vector3.ZERO
		s.want = Vector3.ZERO
		s.crouch = maxf(s.crouch, 0.6)
		if k >= 1.0:
			s.scramble = null
			s.need_path = true
		return "moving"
	if s.move_target == null:
		s.want = Vector3.ZERO
		return "idle"
	if s.need_path:
		# men the player just ordered don't queue behind everyone else's planning
		if G.path_budget <= 0 and not s.path_prio:
			s.want = Vector3.ZERO
			return "wait"
		G.path_budget -= 1
		s.path_prio = false
		s.need_path = false
		var tgt: Vector3 = s.move_target
		s.partial = false
		var far = G.dist2d(s.pos, tgt)
		if far > 22.0 and not upstairs(s) and absf(tgt.y - G.world.ground_y(tgt.x, tgt.z)) < 1.5:
			# know the whole way first, then walk it a leg at a time
			var r: Array = G.world.find_route(s.pos, tgt, s.team)
			if r.size() > 1:
				var acc = 0.0
				var prev = s.pos
				var leg = r[0]
				for w in r:
					acc += G.dist2d(prev, w)
					if acc > 45.0 and w != r[0]:
						break
					leg = w
					prev = w
				if leg != r[r.size() - 1]:
					if G.dist2d(s.pos, leg) > 58.0:
						leg = s.pos + G.flat(leg - s.pos).normalized() * 55.0
					tgt = leg
					s.partial = true
		if not s.partial and far > 70.0:
			# long trips are planned in legs so path searches stay cheap on large maps
			tgt = s.pos + G.flat(tgt - s.pos).normalized() * 55.0
			s.partial = true
		s.path = G.world.find_path(s.pos, tgt)
		if s.path.is_empty():
			s.path = [tgt]
		s.path_i = 0
	var wp: Vector3 = s.path[s.path_i]
	var d = G.dist2d(wp, s.pos)
	while d < 0.55 and s.path_i < s.path.size() - 1:
		s.path_i += 1
		wp = s.path[s.path_i]
		d = G.dist2d(wp, s.pos)
	var last = s.path_i == s.path.size() - 1
	if last and s.partial and d < 2.5:
		s.need_path = true
		return "moving"
	if last and d < 0.35:
		s.want = Vector3.ZERO
		return "arrived"
	var sp = s.speed_t
	if last and d < 1.2:
		sp *= maxf(0.3, d / 1.2)
	if s.unstick_t > 0.0:
		s.unstick_t -= G.DT
		s.want = s.unstick_dir * maxf(sp, 2.5)
		return "moving"
	var dir = G.flat(wp - s.pos) / maxf(d, 0.01)
	# slide round corners and posts instead of walking into them
	s.slide_t -= G.DT
	if s.slide_t > 0.0 and s.slide_dir.dot(dir) > 0.0:
		dir = s.slide_dir       # keep going the way we picked round the corner, no dithering
	elif d > 0.8 and G.world.solid_at(s.pos.x + dir.x * 0.6, s.pos.z + dir.z * 0.6, 0.22, s.pos.y):
		for ang in [0.6, -0.6, 1.1, -1.1, 1.6, -1.6]:
			var nd = dir.rotated(Vector3.UP, ang)
			if not G.world.solid_at(s.pos.x + nd.x * 0.6, s.pos.z + nd.z * 0.6, 0.22, s.pos.y):
				dir = nd
				s.slide_dir = nd
				s.slide_t = 0.5
				break
	s.want = dir * sp
	s.prog_t += G.DT
	if s.prog_t > 1.2:
		var moved = G.dist2d(s.pos, s.prog_p)
		s.prog_p = s.pos
		s.prog_t = 0.0
		if moved < 0.35 and s.vault == null:
			s.stuck_n += 1
			s.need_path = true
			# back off and step sideways before trying again
			var side = Vector3(-dir.z, 0, dir.x) * (1.0 if randf() < 0.5 else -1.0)
			s.unstick_dir = (side - dir * 0.6).normalized()
			s.unstick_t = 0.6 + 0.3 * s.stuck_n
			if s.stuck_n >= 3:
				s.stuck_n = 0
				s.bad_spot = s.move_target
				s.bad_t = G.sim_time + 12.0
				# stuck over and over in the same spot: step out to the nearest open ground
				if G.dist2d(s.pos, s.wedge_p) < 2.0:
					s.wedge_n += 1
				else:
					s.wedge_n = 1
					s.wedge_p = s.pos
				if s.wedge_n >= 2 and not AI.upstairs(s):
					s.wedge_n = 0
					unwedge(s)
				return "stuck"
		else:
			s.stuck_n = 0
	return "moving"

static func unwedge(s) -> void:
	var W = G.world
	var best = null
	for k in range(24):
		var a = randf() * TAU
		var q = s.pos + Vector3(cos(a), 0, sin(a)) * (1.5 + (k % 6) * 0.5)
		if not W.inside_any(q.x, q.z, 0.45) and not W.astar.is_point_solid(W.nav_cell(q.x, q.z)) and not W.in_water(q.x, q.z):
			best = q
			break
	if best == null:
		best = W.nav_pos(W._nearest_free(W.nav_cell(s.pos.x, s.pos.z)))
	if G.dist2d(best, s.pos) < 8.0:
		var to = Vector3(best.x, W.surface_y(best.x, best.z, s.pos.y + 0.5), best.z)
		var cam = G.main.get_viewport().get_camera_3d()
		var seen = cam != null and cam.is_position_in_frustum(s.pos) and cam.global_position.distance_to(s.pos) < 90.0
		if not seen:
			s.pos = to
			s.vel = Vector3.ZERO
		else:
			# in view: clamber out over a moment instead of popping across
			s.scramble = {"a": s.pos, "b": to, "k": 0.0, "dur": clampf(G.dist2d(s.pos, to) * 0.28, 0.5, 1.6)}
		s.need_path = true

static func follow_route(s) -> void:
	var R = s.route
	if s.climb != null:
		return
	var wp: Vector3 = R["pts"][R["i"]]
	var d = G.dist2d(wp, s.pos)
	# a ladder instead of stairs: at its foot (or the top) climb it in one go
	var T = s.tower
	if T != null and T.get("ladder", false) and R["i"] <= 1 and R["pts"].size() > 1:
		var end0: Vector3 = R["pts"][0]
		if G.dist2d(end0, s.pos) < 1.3 and absf(end0.y - s.pos.y) < 1.2:
			s.start_climb(T, R["pts"][1].y > end0.y + 1.0)
			R["i"] = 2 if R["pts"].size() > 2 else 1
			return
	if d < 0.4 and absf(wp.y - s.pos.y) < 1.2:
		R["i"] += 1
		if R["i"] >= R["pts"].size():
			s.route = null
			s.want = Vector3.ZERO
			if s.task == "post":
				s.in_cover = true
				s.cover_time = 0.0
			else:
				s.task = null
				s.tower = null
				s.decide_t = 0.0
		return
	s.want = G.flat(wp - s.pos) / maxf(d, 0.01) * 2.6

# ---------------------------------------------------------------- perception
static func perceive(s) -> void:
	s.think = randf_range(0.25, 0.4) if G.soldiers.size() < 90 else randf_range(0.45, 0.75)
	if G.main.is_night():
		# light discipline: only the man on point shows a light, and nobody does once the enemy is near
		var contact = s.vis_t != null or G.sim_time - s.seen_t < 10.0 or s.supp > 0.3
		var point_man = s.squad == null or s.squad["members"].find(s) % 3 == 0
		var near_enemy = s.has_seen and G.dist2d(s.threat, s.pos) < 70.0 and G.sim_time - s.seen_t < 40.0
		s.light_on = (not contact and not near_enemy and point_man and s.state == "alive" and s.cls != "sniper") or s.has_meta("force_light")
	elif s.light_on:
		s.light_on = false
	var eye = s.head_pos()
	var in_c = s.in_cover and s.cover != null
	if in_c and s.cover.type == "wall" and s.has_threat:
		can_fire_from(s.cover, s.threat)
	var pe = peek_pos(s.cover) if in_c else Vector3.ZERO
	var vis = null
	var peek_only = false
	var cand: Array = []
	for o in G.soldiers:
		if o.team != s.team and o.state != "dead" and (o != Modes.pilot or o.state != "wounded"):
			var d2 = o.pos.distance_squared_to(s.pos)
			if d2 < 160.0 * 160.0:
				cand.append([d2 * (0.5 if o == s.target else 1.0) * (6.0 if o == Modes.pilot else 1.0), o])
	cand.sort_custom(func(a, b): return a[0] < b[0])
	for k in range(mini(6, cand.size())):
		var o = cand[k][1]
		var d = sqrt(cand[k][0])
		var rng = G.view_range
		if rng < 100.0:
			# in the dark you see what's lit by flares, or the flash of someone firing
			if Combat.lit(o.pos) or G.sim_time - o.fired_t < 1.2 or o.light_on or (o.vehicle != null and is_instance_valid(o.vehicle) and o.vehicle.lights_on):
				rng = 150.0
		if d > rng:
			continue
		var ch = o.chest()
		var seen = false
		var po = false
		if not G.blocked(eye, ch, true):
			seen = true
		elif in_c and (s.cover.type != "wall" or s.cover.side != 0.0) and not G.blocked(pe, ch, true):
			seen = true
			po = true
		if not seen:
			continue
		var prev = s.intel.get(o)
		var fresh = not (prev != null and prev["seen"] and G.sim_time - prev["t"] < 6.0)
		add_intel(s, o, o.pos, 0.0, true)
		if fresh or G.sim_time - s.report_t > 2.0:
			s.report_t = G.sim_time
			share_intel(s, o, o.pos)
		if fresh and s.is_up() and G.sim_time - s.seen_t > 6.0:
			var dist = int(round(s.pos.distance_to(o.pos) / 5.0)) * 5
			G.fx.callout(s, G.pick(["Contact %s, %dm!" % [bearing_text(s.pos, o.pos), dist], "Enemy %s!" % bearing_text(s.pos, o.pos), "Contact!"]))
		if vis == null:
			vis = o
			peek_only = po
	s.vis_t = vis
	s.peek_vis = peek_only
	# anti-tank weapons look for enemy vehicles too
	s.vis_veh = null
	if s.W["rocket"] or s.W["ap"] or s.fausts > 0:
		var bdv = s.W["range"][1] * 1.2 if (s.W["rocket"] or s.W["ap"]) else 48.0
		for v in G.vehicles:
			if v.team != s.team and v.team >= 0 and not v.dead and v.kind != "mortar":
				var dv = G.dist2d(v.pos, s.pos)
				if dv < bdv and dv > 12.0 and not G.blocked(eye, v.center()):
					bdv = dv
					s.vis_veh = v
	if vis != null:
		s.target = vis
	var best = best_intel(s)
	if best != null:
		s.threat = best["p"]
		s.last_seen = best["p"]
		s.seen_t = best["t"]
		s.has_seen = true
		s.has_threat = true
	else:
		s.has_seen = false
		s.seen_t = -99.0
		s.threat = objective_for(s)
		s.has_threat = true
	var known = s.has_seen and G.sim_time - s.seen_t < 12.0
	if s.cover != null and known and (s.in_cover or s.pos.distance_to(s.cover.p) < 6.0):
		if not cover_safe(s.cover, s.threat):
			s.cover_bad += 1
		else:
			s.cover_bad = 0
	# live grenades nearby
	if s.flee == null and not upstairs(s):
		for g in G.grenades:
			if not is_instance_valid(g) or g.get_meta("type") != "frag":
				continue
			if g.get_meta("fuse") < 2.3 and g.global_position.distance_to(s.pos) < 6.5 and g.get_meta("owner") != s:
				var away = G.flat(s.pos - g.global_position)
				if away.length_squared() < 0.01:
					away = Vector3(1, 0, 0)
				s.flee = s.pos + away.normalized() * 8.0
				s.flee_t = 3.0
				release_cover(s)
				s.route = null
				go_to(s, s.flee, 6.0)
				s.task = "flee"
				G.fx.callout(s, "Grenade!")
				if s.dragging != null:
					s.dragging.dragger = null
					s.dragging = null
					s.hand_t = null
				break

# ---------------------------------------------------------------- scouts
# a scout creeps forward alone, lies up where he can watch, radios back what he sees,
# and slips away rather than getting into a fight
static func scout_tick(s) -> bool:
	if s.order != null and s.order.get("mode", "") == "move":
		return false
	var t = s.team
	var n = 0
	var c = Vector3.ZERO
	for e in s.intel.keys():
		var k = s.intel[e]
		if k["seen"] and G.sim_time - k["t"] < 3.0 and is_instance_valid(e) and e.state != "dead":
			n += 1
			c += k["p"]
	if n > 0:
		c /= n
		if Comms.ok(t):
			Commander.report(t, c, n)
			if G.sim_time - s.get_meta("rep_t", -99.0) > 25.0:
				s.set_meta("rep_t", G.sim_time)
				G.ui.radio(t, "Scout %s: %d enemy near %s" % [s.sname, n, grid_ref(c)])
				G.fx.callout(s, G.pick(["Scout to command: contact, %d men, %s." % [n, bearing_text(s.pos, c)], "I see %d of them. Reporting." % n]))
		if G.dist2d(c, s.pos) < 30.0 or s.supp > 0.25 or s.hp < 70.0:
			# too close: back off the way he came
			release_cover(s)
			s.task = "scout"
			go_to(s, s.pos + G.flat(s.pos - c).normalized() * 25.0, 4.4)
			return true
		if s.cover == null:
			var cv = find_cover(s, c, "hold")
			if cv != null:
				take_cover(s, cv)
			else:
				stop_move(s)
				s.kneel = true
		s.task = "scout"
		return true
	var wp = s.get_meta("scout_wp") if s.has_meta("scout_wp") else null
	if wp == null or G.dist2d(s.pos, wp) < 8.0 or G.sim_time > s.get_meta("scout_wp_t", 0.0):
		wp = _scout_point(s)
		s.set_meta("scout_wp", wp)
		s.set_meta("scout_wp_t", G.sim_time + 50.0)
	if s.cover != null:
		release_cover(s)
	s.task = "scout"
	go_to(s, wp, 3.0)
	return true

# somewhere on the enemy's side worth a look, usually out on a flank
static func _scout_point(s) -> Vector3:
	var t = s.team
	var enemy: Vector3 = G.world.spawn[(t + 1) % G.team_count()]
	var mid: Vector3 = G.world.capture
	var cands = []
	for pt in Obj.points:
		if pt["owner"] != t:
			cands.append(pt["p"])
	var axis = G.flat(enemy - mid)
	var perp = Vector3(-axis.z, 0, axis.x).normalized()
	for k in range(3):
		cands.append(mid + axis * randf_range(0.15, 0.6) + perp * randf_range(-1.0, 1.0) * clampf(axis.length() * 0.8, 20.0, 70.0))
	var p: Vector3 = G.pick(cands)
	var b: Rect2 = G.world.bounds
	p.x = clampf(p.x, b.position.x + 8.0, b.end.x - 8.0)
	p.z = clampf(p.z, b.position.y + 8.0, b.end.y - 8.0)
	return p

# ---------------------------------------------------------------- wire cutters
# engineers, assault troops and raiders cut through enemy wire that's in their way
static func wire_tick(s) -> bool:
	if s.has_meta("cut_st"):
		var st = s.get_meta("cut_st")
		if st == null or st["dead"] or not Build.sites.has(st):
			s.remove_meta("cut_st")
			return false
		stop_move(s)
		s.crouch_t = 0.8
		s.hand_t = st["p"] + Vector3(0, 0.4, 0)
		if G.sim_time > s.get_meta("cut_t", 0.0):
			s.remove_meta("cut_st")
			s.hand_t = null
			Build.dismantle(st)
			G.fx.callout(s, "Wire's cut! Through!")
		return true
	if not (s.cls in ["engineer", "assault"] or s.has_meta("knife")) or s.vis_t != null or s.move_target == null:
		return false
	for st in Build.sites:
		if st["kind"] == "wire" and st["team"] != s.team and not st["dead"] and G.dist2d(st["p"], s.pos) < 4.5:
			s.set_meta("cut_st", st)
			s.set_meta("cut_t", G.sim_time + 2.5)
			G.fx.callout(s, G.pick(["Cutting the wire!", "Cutters out, cover me!"]))
			return true
	return false

# ---------------------------------------------------------------- ambushes
# defenders who haven't been spotted hold their fire until the enemy is close or out in the open,
# then the whole squad opens up at once
static var ambushes = 0
static var ambush_waits = 0

static func ambush_hold(s, tgt) -> bool:
	if tgt == null or s.is_player or s.squad == null or Commander.style_of(s.team) == "reckless":
		return false
	var q = s.squad
	if G.sim_time - q.get("sprung_t", -99.0) < 25.0:
		return false
	var holding = q.get("dig", false) or (q.get("cmd") != null and q["cmd"]["job"] == "defend") or order_of(s)["mode"] == "hold"
	if not holding or not s.in_cover or s.task == "charge":
		return false
	var d = G.dist2d(tgt.pos, s.pos)
	var open = not tgt.in_cover and tgt.vehicle == null
	var spotted = s.supp > 0.15 or s.hurt_t > 0.0
	if d < 22.0 or (open and d < 38.0) or spotted:
		q["sprung_t"] = G.sim_time
		ambushes += 1
		var L = Squad.leader_of(q)
		G.fx.callout(L if L != null else s, G.pick(["Now! Open fire!", "Fire! Fire!", "Let 'em have it!"]))
		return false
	ambush_waits += 1
	if G.sim_time - q.get("wait_said", -99.0) > 20.0:
		q["wait_said"] = G.sim_time
		G.fx.callout(s, G.pick(["Hold your fire... wait for it.", "Steady. Let them come closer.", "Nobody shoots yet."]))
	return true

# ---------------------------------------------------------------- decisions
# soldiers left to themselves size things up and act on it, instead of only doing what the squad does:
# someone cut off pulls back to his mates, a handful facing a crowd falls back to better cover,
# the badly hurt get out of the line, and nobody stands in the open in front of an enemy tank
static func _initiative(s, known: bool, threat: Vector3, dT: float) -> bool:
	if s.zombie or s.task in ["medic", "resupply", "regroup", "withdraw", "sapper", "post"] and s.move_target != null:
		return false
	if not known or dT > 70.0:
		return false
	var friends = 0
	var nearest_f = null
	var nfd = 80.0
	for o in G.soldiers:
		if o == s or o.team != s.team or o.state != "alive" or o.vehicle != null:
			continue
		var d = G.dist2d(o.pos, s.pos)
		if d < 20.0:
			friends += 1
		if d < nfd and d > 4.0:
			nfd = d
			nearest_f = o
	var foes = 0
	for e in s.intel:
		var k = s.intel[e]
		if G.sim_time - k["t"] < 8.0 and G.dist2d(k["p"], s.pos) < 40.0:
			foes += 1
	# enemy armour close and nothing to stop it with: get out of its sight
	if not (s.W["rocket"] or s.W["ap"]) and s.fausts <= 0:
		for v in G.vehicles:
			if v.team != s.team and v.team >= 0 and not v.dead and (v.spec["tracked"] or v.kind == "armoredcar") and G.dist2d(v.pos, s.pos) < 35.0:
				if s.in_cover and s.cover != null and G.blocked(v.center(), s.chest()):
					break        # already out of its sight
				var hc = find_cover(s, v.pos, "retreat")
				if hc != null:
					Tactics.cover_smoke(s, v.pos)
					take_cover(s, hc)
					s.task = "withdraw"
					G.fx.callout(s, G.pick(["Tank! Get behind something!", "Armour, take cover!"]))
					return true
				break
	# cut off from the others: work back to the nearest friend rather than fight it out alone
	if friends == 0 and nearest_f != null and nfd > 22.0 and not (s.in_cover and s.cover_bad == 0 and foes <= 1):
		release_cover(s)
		var side = Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
		go_to(s, nearest_f.pos + side, 4.8)
		s.task = "regroup"
		G.fx.callout(s, G.pick(["Moving to you!", "Coming to you, cover me!", "I'm on my own here, falling in!"]))
		return true
	# badly outnumbered where he is: fall back to cover further off and keep shooting from there
	if foes >= friends + 3 and s.cover_bad < 3:
		var rc = find_cover(s, threat, "retreat")
		if rc != null and G.dist2d(rc.p, s.pos) > 3.0:
			if s.supp > 0.25 or foes >= friends + 5:
				Tactics.cover_smoke(s, threat)
			take_cover(s, rc)
			s.task = "withdraw"
			if randf() < 0.5:
				G.fx.callout(s, G.pick(["Too many of them, fall back!", "Pull back, pull back!", "Back to the next cover!"]))
			return true
	# hurt and out in the open: get out of the line, to a field hospital if there's one close
	if s.hp < 40.0 and not s.in_cover:
		if s.supp > 0.3:
			Tactics.cover_smoke(s, threat)
		var hosp = Medical.hospital_near(s.team, s.pos, 60.0)
		if hosp != null:
			go_to(s, hosp["p"], 4.0)
			s.task = "withdraw"
			return true
		var hcv = find_cover(s, threat, "hold")
		if hcv != null:
			take_cover(s, hcv)
			return true
	return false

static func decide(s) -> void:
	s.decide_t = randf_range(1.6, 2.6)
	if s.task == "stretcher" and Stretcher.busy(s):
		return
	if s.task == "flee" or s.route != null or s.task == "board" or s.task == "get_radio":
		return
	# nothing left to fight with but a pistol and a knife: straight at the nearest enemy
	if s.has_meta("lastditch"):
		if s.primary == null and s.wid != "pistol":
			s.remove_meta("lastditch")        # restocked from a crate or picked up a gun
		elif s.vehicle == null:
			var foe = s.vis_t if (s.vis_t != null and is_instance_valid(s.vis_t) and s.vis_t.state == "alive") else null
			var fp = foe.pos if foe != null else Vector3.ZERO
			if foe == null:
				var bd = 1e9
				for e in s.intel:
					var k = s.intel[e]
					if is_instance_valid(e) and e.state == "alive" and G.sim_time - k["t"] < 30.0 and k["p"].distance_squared_to(s.pos) < bd:
						bd = k["p"].distance_squared_to(s.pos)
						fp = k["p"]
						foe = e
			if foe != null:
				release_cover(s)
				s.task = "charge"
				s.broken = false
				s.prone_t = false
				s.kneel = false
				go_to(s, fp, 5.8)
				s.decide_t = 0.7
				return
	if raze_tick(s):
		return
	# routed: keep running to the rear, then cower in cover until morale comes back
	if s.broken:
		var home: Vector3 = G.world.fallback_point(s.team, s.pos)
		if G.dist2d(s.pos, home) > 12.0:
			if s.move_target == null:
				release_cover(s)
				go_to(s, home + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)), 5.8)
		elif s.cover == null:
			var hc = find_cover(s, s.threat, "hold")
			if hc != null:
				take_cover(s, hc)
		s.task = "rout"
		return
	if s.task == "rout":
		s.task = null
	if s.has_meta("scout") and scout_tick(s):
		return
	if wire_tick(s):
		return
	# at night, leaders put up flares over where the enemy was last seen
	if G.main.is_night() and s.flares > 0 and Morale.is_leader(s):
		s.flare_cd -= 2.0
		if s.flare_cd <= 0.0 and s.has_seen and G.sim_time - s.seen_t < 25.0 and s.vis_t == null and not Combat.lit(s.threat):
			s.flares -= 1
			s.flare_cd = randf_range(18.0, 28.0)
			Combat.flare(s.pos, s.threat)
			G.fx.callout(s, G.pick(["Flare up!", "Light 'em up!"]))
	if ClassAI.busy(s) or (s.task in ["sapper", "flank_move", "clear"] and s.move_target != null):
		return
	if s.task == "fetch" and s.vis_t == null:
		return
	if ammo_run(s):
		return
	# low on ammunition: go and get some
	if s.task == "resupply":
		if s.supply_target == null or (s.supply_target is Object and (not is_instance_valid(s.supply_target) or s.supply_target.reserve + s.supply_target.mag <= 0)):
			s.task = null
		else:
			return
	# completely dry, or there's armour about and a dead man's rocket launcher lying close: go and take his weapon
	var dry = s.reserve <= 0 and s.mag < s.W["mag"] * 0.3
	if (dry or (not s.W["rocket"] and s.cls in ["rifleman", "assault", "engineer"])) and not s.zombie:
		var armour = dry or G.vehicles.any(func(v): return v.team != s.team and not v.dead and (v.spec["tracked"] or v.kind == "armoredcar") and G.dist2d(v.pos, s.pos) < 120.0)
		if armour:
			for o in G.soldiers:
				if o.state != "dead" or o.zombie or o.gun_body == null or not is_instance_valid(o.gun_body) or o.reserve + o.mag <= 0 or o.wid == s.wid:
					continue
				if not dry and not o.W["rocket"]:
					continue
				if G.dist2d(o.pos, s.pos) < (22.0 if dry else 15.0):
					release_cover(s)
					s.supply_target = o
					s.task = "resupply"
					go_to(s, o.pos, 5.0)
					return
	if s.ammo_frac() < 0.7 and s.vis_t == null and s.task != "resupply":
		for o in G.soldiers:
			if o.state == "dead" and o.reserve > 0 and G.dist2d(o.pos, s.pos) < 9.0:
				release_cover(s)
				s.supply_target = o
				s.task = "resupply"
				go_to(s, o.pos, 4.0)
				return
	if s.ammo_frac() < 0.4 and (s.vis_t == null or s.mag == 0):
		var src = find_ammo(s)
		if src != null:
			release_cover(s)
			s.supply_target = src
			s.task = "resupply"
			go_to(s, src.pos if src is Object else src["p"], 4.8)
			G.fx.callout(s, G.pick(["I need ammo!", "Running low, going for ammo!", "Out of mags!"]))
			return
	var order = order_of(s)
	var known = s.has_seen and G.sim_time - s.seen_t < 12.0
	var threat: Vector3 = s.threat
	var W = s.W
	var dT = G.dist2d(threat, s.pos)
	if upstairs(s):
		if s.task == "post" and s.cover != null and s.cover_bad < 2 and order["mode"] != "move" and order["mode"] != "charge":
			return
		if s.cover != null and s.cover_bad >= 2:
			s.cover.ban = G.sim_time + 20.0
		go_downstairs(s)
		return
	if ClassAI.jobs(s, known, threat):
		return
	# medic duty (medics come from far; anyone else only helps a buddy right next to them)
	if s.task == "medic" and s.patient != null and is_instance_valid(s.patient) and s.patient.state == "wounded":
		return
	if s.vis_t == null and G.sim_time - s.seen_t > 2.0 and s.hp > 40.0:
		for w in G.soldiers:
			if w.team == s.team and w.state == "wounded" and w.medic == null and w.pos.distance_to(s.pos) < (45.0 if s.cls == "medic" else 6.0):
				w.medic = s
				s.patient = w
				s.task = "medic"
				release_cover(s)
				go_to(s, w.pos, 5.0)
				G.fx.callout(s, G.pick(["Hang on!", "Coming to you!", "I got you!"]))
				if known and s.smokes > 0:
					Combat.throw_grenade(s, w.pos + G.flat(threat - w.pos).normalized() * 5.0, "smoke")
				return
	if s.task == "medic":
		s.task = null
		s.patient = null
		s.hand_t = null
	# grenades at enemies hiding behind cover
	s.nade_cd -= 2.0
	if s.grenades > 0 and s.nade_cd <= 0.0 and known and s.target != null and is_instance_valid(s.target) and s.target.state != "dead" and s.intel.has(s.target) and dT > 11.0 and dT < 30.0 and (s.target.in_cover or s.vis_t == null):
		if randf() < 0.5:
			var e = s.intel[s.target]
			var gp = Doors.throw_point(s, e["p"])
			if gp == e["p"]:
				gp += Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
			elif randf() < 0.6:
				G.fx.callout(s, G.pick(["Grenade, through the window!", "Frag in the window!", "Fire in the hole!"]))
			Combat.throw_grenade(s, gp, "frag")
			s.burst = 0
			s.burst_cd = 0.8
		s.nade_cd = randf_range(10.0, 18.0)
	if order["mode"] == "free" and _initiative(s, known, threat, dT):
		return
	if order["mode"] == "follow":
		var L = order.get("who")
		if L == null or not is_instance_valid(L) or L.state == "dead":
			s.order = null
		else:
			var lp: Vector3 = L.pos if L.vehicle == null else L.vehicle.pos
			var k1 = (s.id * 37) % 5 - 2
			var k2 = (s.id * 13) % 3 + 1
			var back = G.flat(Vector3(-sin(L.body_yaw), 0, -cos(L.body_yaw)))
			var side = Vector3(back.z, 0, -back.x)
			var spot = lp + back * k2 * 1.8 + side * k1 * 1.8
			if G.dist2d(s.pos, spot) > 5.0:
				release_cover(s)
				s.task = "follow"
				s.prone_t = false
				go_to(s, spot, 5.6 if G.dist2d(s.pos, spot) > 18.0 else 4.2)
			elif known and s.cover == null:
				var fc = find_cover(s, threat, "defend")
				if fc != null and G.dist2d(fc.p, lp) < 9.0:
					take_cover(s, fc)
				else:
					stop_move(s)
					s.kneel = true
			else:
				stop_move(s)
				s.kneel = known
			return
	if order["mode"] == "charge":
		release_cover(s)
		s.task = "charge"
		s.prone_t = false
		var best = null
		var bd = 1e9
		for k in s.intel.values():
			var d = k["p"].distance_squared_to(s.pos)
			if d < bd:
				bd = d
				best = k["p"]
		go_to(s, best if best != null else objective_for(s), 5.4)
		return
	if order["mode"] == "hold":
		s.task = "hold"
		if s.cover != null and s.cover_bad < 2:
			return
		var c = find_cover(s, threat, "hold")
		if c != null:
			take_cover(s, c)
		else:
			stop_move(s)
			s.kneel = true
		return
	if order["mode"] == "move" and order["point"] != null:
		var k1 = (s.id * 37) % 9 - 4
		var k2 = (s.id * 13) % 5 - 2
		var goal: Vector3 = order["point"] if s.order != null else order["point"] + Vector3(k2 * 1.8, 0, k1 * 1.8)
		if G.dist2d(s.pos, goal) > 5.0:
			if s.in_cover and s.supp > 1.1:
				return
			if s.cover != null:
				release_cover(s)
			s.task = "move"
			s.prone_t = false
			go_to(s, goal, 4.4)
			return
		# more waypoints queued with Shift: on to the next one
		if s.order != null and not s.order.get("queue", []).is_empty():
			s.order["point"] = s.order["queue"].pop_front()
			s.order.erase("arrived")
			s.path_prio = true
			go_to(s, s.order["point"], 4.4)
			return
		# told which way to face (a dragged line): look that way while it's quiet, and pick cover facing it
		var quiet_now = not s.has_seen or G.sim_time - s.seen_t > 6.0
		if s.order != null and s.order.has("face") and quiet_now:
			var fy: float = s.order["face"]
			threat = goal + Vector3(sin(fy), 0, cos(fy)) * 30.0
			s.threat = threat
			s.has_threat = true
		if s.cover == null or s.cover_bad >= 2:
			var c2 = find_cover(s, threat, "hold")
			if c2 != null:
				take_cover(s, c2)
			else:
				stop_move(s)
		s.task = "hold"
		# got where you sent them: dig in and fight from here; if it stays quiet, rejoin the battle
		if s.order != null:
			if not s.order.has("arrived"):
				s.order["arrived"] = G.sim_time
			var quiet = not s.has_seen or G.sim_time - s.seen_t > 15.0
			if quiet and G.sim_time - s.order["arrived"] > 25.0:
				s.order = null
				s.decide_t = 0.0
				if randf() < 0.4:
					G.fx.callout(s, G.pick(["Nothing here. Moving up.", "All quiet, rejoining the push.", "Position's clear, let's go."]))
		return
	# capture mode: keep pushing onto the objective when nobody is in sight
	var holding_house = s.task == "garrison" and s.cover != null and G.dist2d(s.cover.p, objective_for(s)) < 26.0
	if Obj.uses_points() and not Obj.points.is_empty() and s.vis_t == null and s.supp < 0.7 and s.task != "post" and not holding_house and G.dist2d(s.pos, objective_for(s)) < 60.0:
		var C: Vector3 = objective_for(s)
		var dc = G.dist2d(s.pos, C)
		var q = s.squad
		var can_move = q == null or squad_movers(q) < ceili(q["members"].size() / 2.0) + 1
		if dc > 9.0 and can_move and (not s.in_cover or s.cover_time > 4.0):
			var bestc = null
			var bdc = 1e9
			var idx = 0
			for cp in G.world.cover_near(C, 9.5):
				idx += 1
				if cp.upper or not cover_free(cp, s) or cp.ban > G.sim_time:
					continue
				var d = G.dist2d(cp.p, C)
				if d > 9.0:
					continue
				var sc = d + float((idx * 31 + s.id * 7) % 10) * 0.3
				if sc < bdc and (not known or cover_safe(cp, threat)):
					bdc = sc
					bestc = cp
			if bestc != null:
				take_cover(s, bestc)
				s.task = "objective"
				return
			if s.cover != null:
				release_cover(s)
			s.task = "objective"
			go_to(s, C + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5)), 4.6)
			return
	# marksmen and some gunners head for upstairs windows
	# marksmen, some gunners and the odd rifleman go up high where they can see a long way
	if s.cover == null and (known or W["id"] == "sniper") and (W["id"] == "sniper" or (W["id"] == "lmg" and s.id % 3 == 0) or (W["id"] == "rifle" and s.id % 7 == 0)):
		var post = find_post(s, threat if known else objective_for(s))
		if post != null:
			take_post(s, post)
			return
	# in cover: stay, or leapfrog forward when the squad allows it
	if s.cover != null:
		if s.cover_bad >= 2:
			s.cover.ban = G.sim_time + 8.0
			release_cover(s)
		elif not s.in_cover:
			return
		else:
			s.cover_time += 2.0
			var too_far = dT > W["range"][1]
			var too_close = W["id"] == "sniper" and dT < W["range"][0]
			var q2 = s.squad
			var can_move2 = q2 == null or squad_movers(q2) < ceili(q2["members"].size() / 2.0)
			if too_close:
				var cr = find_cover(s, threat, "retreat")
				if cr != null:
					take_cover(s, cr)
					s.task = "retreat"
				return
			# men holding a house by the objective stay in it while the enemy is in range
			if s.task == "garrison" and dT < W["range"][1] * 1.5:
				return
			# commander mode: no settling into a long-range firefight, keep pushing cover to cover
			var push = G.mode == "commander" and s.order == null and s.cover_time > 10.0 + float(s.id % 5) and dT > 22.0 and (s.supp < 0.4 or (s.supp < 1.0 and odds(s, threat) >= 3.0))
			if can_move2 and Squad.may_bound(s) and s.morale >= Morale.SHAKEN and (s.supp < 0.5 or (too_far and s.supp < 0.9) or push) and ((s.vis_t == null and s.cover_time > 5.0) or too_far or push):
				# nothing seen lately: the next cover is towards where we're going, not where the last enemy was
				var ca = find_cover(s, threat, "flank" if s.role == "flanker" else "advance") if known else hop_cover(s, objective_for(s))
				if ca != null:
					take_cover(s, ca)
					s.task = "advance"
				elif not known:
					release_cover(s)
				elif too_far and s.supp < 0.9:
					release_cover(s)
					var fwd = G.flat(threat - s.pos).normalized()
					if s.smokes > 0 and randf() < 0.5:
						Combat.throw_grenade(s, s.pos + fwd * 10.0, "smoke")
					go_to(s, s.pos + fwd * 14.0 + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)), 5.0)
					s.task = "advance"
			if s.cover != null:
				return
	if not known:
		var obj = objective_for(s)
		var k3 = (s.id * 37) % 11 - 5
		var k4 = (s.id * 13) % 7 - 3
		var goal2 = obj + Vector3(k4 * 1.5, 0, k3 * 1.6)
		# holding a house by the point: stay at the window while the point is still here
		if s.task == "garrison" and s.cover != null and G.dist2d(s.cover.p, obj) < 26.0:
			return
		# a long walk: hop on a friendly vehicle heading up
		if G.dist2d(s.pos, obj) > 110.0 and s.vehicle == null and G.sim_time > s.no_board_t and s.order == null:
			for v in G.vehicles:
				if v.team == s.team and not v.dead and v.mission == null and v.cmd == null and not v.spec.get("static", false) and not v.spec.get("air", false) and v.driver() != null and not v.driver().is_player and G.dist2d(v.pos, s.pos) < 25.0:
					var fsi = v.free_seat("pass")
					if fsi >= 0 and v.spec["seats"][fsi]["role"] == "pass":
						s.task = "board"
						s.board_target = v
						go_to(s, v.pos, 5.0)
						return
		# commander mode, in the enemy's half with no orders: up from cover to cover, a pause in each
		if G.mode == "commander" and s.order == null and G.dist2d(s.pos, obj) > 14.0 and G.team_count() == 2 and G.sim_time - s.seen_t < 90.0:
			var own: Vector3 = G.world.spawn[s.team]
			var foe: Vector3 = G.world.spawn[(s.team + 1) % 2]
			if G.dist2d(s.pos, foe) < G.dist2d(own, foe) * 0.62:
				var hc = hop_cover(s, obj)
				if hc != null:
					take_cover(s, hc)
					s.set_meta("hop_t", G.sim_time)
					s.task = "advance"
					return
		var fs = Squad.slot(s)
		var in_form = false
		if fs != null and G.dist2d(s.pos, obj) > 12.0:
			# keep formation on the squad leader while moving up
			goal2 = fs
			in_form = true
		# nobody's shooting at us: no ducking into cover on the way up, keep moving
		if s.cover != null and s.supp < 0.3 and G.dist2d(s.pos, obj) > 12.0:
			release_cover(s)
			if G.dist2d(s.pos, goal2) < 2.5:
				stop_move(s)
				s.task = "advance"
				return
		s.prone_t = false
		if in_form:
			# keeping pace with the leader: a short wait at the slot, never a dive for cover
			if G.dist2d(s.pos, goal2) < 2.5:
				stop_move(s)
				s.task = "advance"
				return
			s.task = "advance"
			go_to(s, goal2, 3.6)
			return
		if G.dist2d(s.pos, goal2) < 5.0 or (s.task == "garrison" and s.cover != null):
			var foe_side: Vector3 = G.world.spawn[(s.team + 1) % G.team_count()]
			# a house by the point: go in and take a window facing the way the enemy will come
			if s.task != "garrison" and s.id % 3 != 0 and G.sim_time - s.get_meta("garrison_t", -999.0) > 60.0:
				var gc = garrison_cover(s, obj, foe_side, 24.0)
				if gc != null:
					take_cover(s, gc)
					s.set_meta("garrison_t", G.sim_time)
					s.task = "garrison"
					return
			if s.task == "garrison" and s.cover != null:
				return
			var ch = find_cover(s, foe_side, "hold")
			if ch != null:
				take_cover(s, ch)
			else:
				stop_move(s)
			s.task = "hold"
			return
		s.task = "advance"
		go_to(s, goal2, 3.6)
		return
	var stl = Commander.style_of(s.team)
	var supp_lim = 0.75 if stl == "reckless" else (0.3 if stl == "cautious" else 0.45)
	var hp_lim = 40.0 if stl == "reckless" else (65.0 if stl == "cautious" else 55.0)
	var mode = "defend" if (s.supp > supp_lim or s.hp < hp_lim or (s.vis_t != null and stl != "reckless") or s.morale < Morale.SHAKEN) else ("flank" if s.role == "flanker" else "advance")
	var c3 = find_cover(s, threat, mode)
	if c3 != null:
		take_cover(s, c3)
		s.task = mode
	elif s.vis_t != null or s.supp > 0.8:
		stop_move(s)
		s.task = "fight"
		if s.supp > 1.2 and s.smokes > 0:
			Combat.throw_grenade(s, s.pos + G.flat(threat - s.pos).normalized() * 4.0, "smoke")
		if s.supp > 0.8 or W["id"] == "sniper":
			s.prone_t = true
		else:
			s.kneel = true
	elif dT > 12.0:
		s.prone_t = false
		go_to(s, s.pos + G.flat(threat - s.pos).normalized() * minf(14.0, dT - 8.0), 4.0)
		s.task = "advance"

# ---------------------------------------------------------------- every tick
# soldiers who've stood in the same spot a long while with nothing happening get moving again
static func _watchdog(s) -> void:
	s.idle_t += G.DT
	if G.dist2d(s.pos, s.idle_p) > 2.5:
		s.idle_p = s.pos
		s.idle_t = 0.0
		return
	if s.idle_t < 22.0:
		return
	s.idle_t = 0.0
	s.idle_p = s.pos
	if s.vis_t != null or G.sim_time - s.seen_t < 8.0 or ClassAI.busy(s) or s.task in ["hold", "post", "defend", "medic", "garrison"] or s.broken:
		return
	var o = order_of(s)
	if o["mode"] == "hold" or o["mode"] == "follow":
		return
	if s.cover != null and s.cover.type != "low":
		s.cover.ban = G.sim_time + 20.0
	release_cover(s)
	stop_move(s)
	s.route = null
	s.task = null
	var goal = objective_for(s)
	if G.dist2d(goal, s.pos) < 12.0:
		return
	var a = randf() * TAU
	go_to(s, goal + Vector3(cos(a), 0, sin(a)) * randf_range(2.0, 6.0), 4.6)
	s.decide_t = 3.0

static func update(s) -> void:
	if s.zombie:
		Modes.zombie_tick(s)
		return
	if (s.bleed > 0.0 or s.bandage_t > 0.0 or s.think <= 0.05) and Medical.ai_tick(s):
		stance(s)
		s.crouch_t = 0.8
		return
	if s.think <= 0.05 and not s.in_cover and s.has_seen and G.sim_time - s.seen_t < 8.0 and not G.world.tables.is_empty():
		_try_flip(s)
	s.think -= G.DT
	s.decide_t -= G.DT
	s.morale_t -= G.DT
	if s.morale_t <= 0.0:
		s.morale_t = 0.5
		Morale.tick(s, 0.5)
		supply_tick(s, 0.5)
		pass_ammo(s)
	if s.think <= 0.0:
		perceive(s)
	_watchdog(s)
	if s.decide_t <= 0.0:
		decide(s)
	if s.task == "flee":
		s.flee_t -= G.DT
		if s.flee_t <= 0.0 or s.move_target == null:
			s.task = null
			s.flee = null
			s.decide_t = 0.0
	s.hand_t = null
	s.hands_t = null
	s.tool_mode = ""
	if s.task == "stretcher" and Stretcher.busy(s):
		Stretcher.drive(s)
		return
	# just landed by parachute: out of the harness, then a look round before moving off
	if s.has_meta("landed"):
		var lt: float = s.get_meta("landed") - G.DT
		if lt <= 0.0 or s.vis_t != null or s.is_player:
			s.remove_meta("landed")
		else:
			s.set_meta("landed", lt)
			stop_move(s)
			s.want = Vector3.ZERO
			s.ready_ = false
			s.crouch_t = 0.6
			if lt > 1.5:
				# hands at the chest working the harness release
				var f = Vector3(sin(s.body_yaw), 0, cos(s.body_yaw))
				s.hand_t = s.chest() + f * 0.28 + Vector3(0, -0.05 + sin(lt * 18.0) * 0.04, 0)
			else:
				s.aim_yaw += sin(lt * 2.8) * 2.2 * G.DT
			return
	if s.task == "fetch":
		fetch_tick(s)
	if ClassAI.busy(s):
		ClassAI.work(s)
	# climbing into a vehicle
	if s.task == "board":
		var v = s.board_target
		if v == null or not is_instance_valid(v) or v.dead or v.free_seat() < 0 or s.vis_t != null:
			s.task = null
			s.board_target = null
		elif G.dist2d(v.pos, s.pos) < v.spec["len"] * 0.5 + 1.5:
			var want = "driver" if v.driver() == null else ("gunner" if v.gunner_seat() >= 0 and v.seats[v.gunner_seat()] == null else "pass")
			if s.mount(v, v.free_seat(want)):
				return
		elif s.move_target == null or G.dist2d(s.move_target, v.pos) > 3.0:
			go_to(s, v.pos, 5.0)
	# medic: drag the wounded out of the line of fire, then patch them up
	if s.task == "medic":
		var w = s.patient
		if w == null or not is_instance_valid(w) or w.state != "wounded":
			s.task = null
			s.patient = null
			s.decide_t = 0.0
			if s.dragging != null:
				s.dragging.dragger = null
				s.dragging = null
		elif s.dragging != null:
			var to = G.flat(s.drag_to - s.pos)
			var d = to.length()
			if d < 0.6:
				s.dragging.dragger = null
				s.dragging = null
				s.want = Vector3.ZERO
			else:
				s.want = to / d * 1.5
			var wp = w.parts[1].global_position
			s.aim_yaw = G.turn_to(s.aim_yaw, atan2(wp.x - s.pos.x, wp.z - s.pos.z), 5.0 * G.DT)
			s.ready_ = false
			s.crouch_t = 0.5
			s.hand_t = wp
			# both hands under his arms
			var p3: Vector3 = w.parts[3].global_position
			var p5: Vector3 = w.parts[5].global_position
			if p3.distance_squared_to(s.hand_l()) <= p5.distance_squared_to(s.hand_l()):
				s.hands_t = [p3, p5]
			else:
				s.hands_t = [p5, p3]
		elif G.dist2d(w.pos, s.pos) > 1.1:
			var dw = G.dist2d(w.pos, s.pos)
			var hot = s.has_seen and G.sim_time - s.seen_t < 6.0
			# under fire: screen him with smoke first, then go in low and crawl the last few metres
			if hot and dw < 22.0 and s.smokes > 0 and s.get_meta("smoked_for", null) != w:
				s.set_meta("smoked_for", w)
				Combat.throw_grenade(s, w.pos + G.flat(s.threat - w.pos).normalized() * 5.0, "smoke")
				G.fx.callout(s, G.pick(["Smoke out, I'm going for him!", "Covering smoke! Going in!"]))
			var spd = 5.0 if not hot else (4.2 if dw > 9.0 else 1.4)
			if s.move_target == null or s.move_target.distance_to(w.pos) > 1.0 or absf(s.speed_t - spd) > 0.5:
				go_to(s, w.pos, spd)
		else:
			stop_move(s)
			var exposed = s.has_seen and G.sim_time - s.seen_t < 8.0 and not G.blocked(Vector3(s.threat.x, s.threat.y + 1.5, s.threat.z), w.pos + Vector3(0, 0.4, 0))
			var dest = null
			# a field hospital close by: carry them there, where they can be saved
			# too far to drag him but a hospital's behind us: get a second man and a stretcher
			if w.heal_t <= 0.0 and Medical.hospital_near(s.team, w.pos, 45.0) == null and Stretcher.try_start(w, s):
				return
			var hosp = Medical.hospital_near(s.team, w.pos, 45.0)
			if hosp != null and G.dist2d(hosp["p"], w.pos) > 5.0 and w.heal_t <= 0.0:
				s.dragging = w
				w.dragger = s
				s.drag_to = hosp["p"] + G.flat(w.pos - hosp["p"]).normalized() * 3.0
				G.fx.callout(s, G.pick(["Getting you to the aid station!", "Hang on, the hospital's right here!"]))
				return
			if exposed and w.heal_t <= 0.0:
				var bd = 1e9
				for cp in G.world.cover_near(w.pos, 14.0):
					if cp.upper or not cover_free(cp, s):
						continue
					var dd = cp.p.distance_to(w.pos)
					if dd > 1.5 and dd < 14.0 and dd < bd and cover_safe(cp, s.threat):
						bd = dd
						dest = cp
			if dest != null:
				s.dragging = w
				w.dragger = s
				s.drag_to = dest.p
				G.fx.callout(s, "Moving you!")
			else:
				w.heal_t += G.DT
				s.hand_t = w.parts[1].global_position
				s.aim_yaw = G.turn_to(s.aim_yaw, atan2(w.pos.x - s.pos.x, w.pos.z - s.pos.z), 4.0 * G.DT)
	if s.dragging != null and s.task != "medic":
		s.dragging.dragger = null
		s.dragging = null
	if s.dragging == null:
		if s.route != null and not (s.route["i"] == 0 and s.route["nav"]):
			follow_route(s)
		else:
			var res = follow_path(s)
			if res == "arrived":
				if s.route != null and s.route["i"] == 0:
					s.route["i"] = 1
				else:
					if s.task == "flee":
						s.flee = null
						s.task = null
						s.decide_t = 0.0
					if s.task == "regroup" or s.task == "withdraw":
						s.task = null
					if s.cover != null and s.cover.p.distance_to(s.pos) < 0.8:
						s.in_cover = true
						s.cover_time = 0.0
				stop_move(s)
			elif res == "stuck":
				if s.cover != null:
					s.cover.ban = G.sim_time + 15.0
					release_cover(s)
				stop_move(s)
				s.route = null
				s.decide_t = 0.0
				if s.task == "flee":
					s.flee = null
					s.task = null
	_keep_apart(s)
	_keep_from_zombies(s)
	_round_vehicles(s)
	aim_and_fire(s)
	stance(s)
	if s.vis_t == null and s.move_target == null:
		Tactics.door_watch(s)

# zombies only bite, so you never walk into them: anything close gets backed away from while you keep
# shooting, nobody goes chasing the horde out of the line, and men bunch up back to back when it's thick
static func _keep_from_zombies(s) -> void:
	# standing in acid: get out of it first
	for pd in Modes.puddles:
		var dp = G.flat(s.pos - pd["p"])
		if dp.length() < 1.4:
			stop_move(s)
			s.want = (dp.normalized() if dp.length() > 0.05 else Vector3(1, 0, 0)) * 3.0
			return
	if not (G.mode == "horde" or s.has_meta("zsaw")):
		return
	var t = s.get_meta("zchk", 0.0) - G.DT
	var near = s.get_meta("znear") if s.has_meta("znear") else null
	if t <= 0.0:
		t = 0.25
		near = null
		var bd = 26.0
		var push = Vector3.ZERO
		for o in G.soldiers:
			if not o.zombie or o.state == "dead" or o.team == s.team:
				continue
			var d = G.dist2d(o.pos, s.pos)
			if d < bd:
				bd = d
				near = o
			if d < 14.0:
				push += G.flat(s.pos - o.pos).normalized() * (14.0 - d)
		s.set_meta("znear", near)
		s.set_meta("zpush", push)
		if near != null:
			s.set_meta("zsaw", true)
	s.set_meta("zchk", t)
	if near == null or not is_instance_valid(near) or near.state == "dead":
		return
	var zd = G.dist2d(near.pos, s.pos)
	# don't head toward them: cancel any move that closes the distance
	if s.move_target != null and G.dist2d(s.move_target, near.pos) < zd - 2.0 and s.task != "medic":
		stop_move(s)
		s.decide_t = 1.5
	if s.in_cover and zd > 6.0:
		return
	var danger = 8.0 if near.ztype != "runner" else 12.0
	if zd < danger and s.task != "medic" and s.dragging == null:
		# back off, away from the closest of them and toward the middle of the defence
		var away: Vector3 = s.get_meta("zpush", Vector3.ZERO)
		if away.length_squared() < 0.01:
			away = G.flat(s.pos - near.pos)
		away = away.normalized()
		var home = G.flat(G.world.capture - s.pos)
		if home.length() > 6.0:
			away = (away * 0.75 + home.normalized() * 0.25).normalized()
		for ang in [0.0, 0.5, -0.5, 1.0, -1.0, 1.6, -1.6]:
			var nd = away.rotated(Vector3.UP, ang)
			if not G.world.solid_at(s.pos.x + nd.x * 0.8, s.pos.z + nd.z * 0.8, 0.25, s.pos.y):
				away = nd
				break
		release_cover(s)
		stop_move(s)
		s.want = away * (3.2 if zd < danger * 0.5 else 2.2)
		s.prone_t = false
		s.kneel = false
		s.threat = near.pos
		s.has_threat = true
		if zd < 1.8 and s.throw_t <= 0.0 and s.fire_cd <= 0.0 and s.reload_t > 0.0:
			Combat.knife(s, near)

# indoors with the enemy about and no cover: tip the nearest table over and get behind it
static func _try_flip(s) -> void:
	if randf() > 0.4 or Doors.building_at(s.pos) < 0:
		return
	var t = G.world.table_near(s.pos, 2.6)
	if t == null:
		return
	var to = G.flat(s.threat - t["p"])
	if to.length() < 3.0:
		return
	# only if the table is between us and them (or we can get behind it)
	G.world.flip_table(t, to.normalized())
	s.kick(G.flat(t["p"] - s.pos).normalized())
	G.fx.callout(s, G.pick(["Table!", "Get behind this!", "Cover, here!"]))
	release_cover(s)
	s.decide_t = 0.0

static func aim_at(s, pt: Vector3, rate: float) -> float:
	var oy = s.pos.y + (0.3 if s.prone else 1.45 - 0.45 * s.crouch)
	var dy = atan2(pt.x - s.pos.x, pt.z - s.pos.z)
	var dp = atan2(pt.y - oy, G.dist2d(pt, s.pos))
	s.aim_yaw = G.turn_to(s.aim_yaw, dy, rate * G.DT)
	s.aim_pitch += clampf(dp - s.aim_pitch, -3.0 * G.DT, 3.0 * G.DT)
	return absf(G.wrap_a(dy - s.aim_yaw))

static func exposed_for_shot(s) -> bool:
	if not s.in_cover or s.cover == null:
		return true
	var t = s.cover.type
	if t == "low":
		return not (s.peek_vis or s.force_peek) or s.crouch < 0.35
	if t == "corner" or (t == "wall" and s.cover.side != 0.0):
		return not (s.peek_vis or s.force_peek) or absf(s.lean) > 0.6
	return not s.peek_vis

static func aim_and_fire(s) -> void:
	var W = s.W
	if s.reload_t > 0.0:
		s.reload_t -= G.DT
		if s.reload_t <= 0.0:
			s.finish_reload()
	s.fire_cd -= G.DT
	if s.swim or s.dragging != null or (s.task == "medic" and s.patient != null and is_instance_valid(s.patient) and G.dist2d(s.patient.pos, s.pos) < 1.3):
		s.burst = 0
		return
	var tgt = null
	if s.vis_t != null and is_instance_valid(s.vis_t) and s.vis_t.state != "dead" and s.task != "medic":
		tgt = s.vis_t
		if s.broken and tgt.pos.distance_to(s.pos) > 12.0:
			tgt = null
	# a tank in panzerfaust range: out with it
	if s.fausts > 0 and s.vis_veh != null and is_instance_valid(s.vis_veh) and not s.vis_veh.dead and not W["rocket"] and not W["ap"] and s.task != "medic" \
			and G.dist2d(s.vis_veh.pos, s.pos) < 46.0 and s.reload_t <= 0.0 and s.to_faust():
		G.fx.callout(s, G.pick(["Panzerfaust!", "I've got a faust, cover me!", "Tank! Going for it!"]))
		return
	if W["id"] == "pfaust" and (s.vis_veh == null or not is_instance_valid(s.vis_veh) or s.vis_veh.dead):
		s.from_sidearm()
		return
	# rocket launchers swap to a rifle up close or when out of rockets
	if W["rocket"] and W["id"] != "pfaust" and (s.rockets <= 0 or (tgt != null and tgt.pos.distance_to(s.pos) < 14.0)):
		s.set_weapon("rifle")
		return
	if s.mag <= 0 and s.reserve <= 0 and s.reload_t <= 0.0 and s.to_sidearm():
		G.fx.callout(s, "Switching to pistol!")
		return
	# out of everything: the rifle's empty, no grenades, the last magazine in the pistol. No surrender:
	# up and at them, pistol in one hand and the knife in the other
	if W["id"] == "pistol" and s.primary != null and s.reserve <= 0 and s.grenades <= 0 and tgt != null and not s.zombie \
			and not s.is_player and s.vehicle == null and not s.has_meta("lastditch") and G.dist2d(tgt.pos, s.pos) < 60.0:
		s.set_meta("lastditch", true)
		s.set_meta("knife", true)
		s.decide_t = 0.0
		G.fx.callout(s, G.pick(["I'm out! Come on then!", "Nothing left... for the lads!", "Fix knives! At them!", "Last of it, let's go!"]))
	# raiders and fighters with a knife finish it quietly when they're on top of someone
	if tgt != null and s.has_meta("knife") and s.fire_cd <= 0.0 and tgt.state == "alive" and G.dist2d(tgt.pos, s.pos) < 1.7 and absf(tgt.pos.y - s.pos.y) < 1.0:
		Combat.knife(s, tgt)
		return
	if tgt != null and s.has_meta("knife") and G.main.is_night() and G.dist2d(tgt.pos, s.pos) < 9.0 and tgt.vis_t != s and s.task != "medic":
		go_to(s, tgt.pos, 4.6)        # creep in for the knife rather than give ourselves away
		return
	if tgt != null and s.has_meta("scout") and G.dist2d(tgt.pos, s.pos) > 15.0 and s.supp < 0.3:
		tgt = null        # scouts don't give themselves away
	if tgt != null and ambush_hold(s, tgt):
		tgt = null
		s.want_peek = false
	var veh_t = s.vis_veh
	if veh_t != null and (not is_instance_valid(veh_t) or veh_t.dead or not (W["rocket"] or W["ap"]) or s.task == "medic"):
		veh_t = null
	var point = null
	var extra = 0.0
	if veh_t != null:
		point = veh_t.center()
	elif tgt != null:
		point = tgt.chest()
	elif s.in_cover and not s.broken and W["auto"] and G.sim_time - s.seen_t < 6.0 and s.squad != null and squad_movers(s.squad) > 0 and s.task != "medic":
		point = s.last_seen + Vector3(0, 1.0, 0)
		extra = 0.045
	elif G.sim_time < s.get_meta("cover_fire_t", -99.0) and not s.broken and s.task != "medic" and G.sim_time - s.seen_t < 12.0:
		# covering a mate's dash: fire at where the enemy is
		point = s.last_seen + Vector3(0, 1.0, 0)
		extra = 0.05
	elif s.task == "raze" and s.has_meta("raze_p") and s.move_target == null:
		point = s.get_meta("raze_p")
		extra = 0.01
	if point != null:
		s.ready_ = true
		var err = aim_at(s, point, 5.5)
		s.want_peek = s.in_cover and (s.burst > 0 or s.burst_cd < 0.35) and s.reload_t <= 0.0
		if s.reload_t <= 0.0 and err < 0.12 and exposed_for_shot(s) and not s.gun_blocked:
			if s.burst > 0:
				if s.fire_cd <= 0.0:
					var dist = s.pos.distance_to(point)
					var dvec: Vector3 = point - s.muzzle
					var L = dvec.length()
					var dir = dvec / maxf(L, 0.01)
					# is the barrel clear? (no shooting into the wall you're hiding behind)
					var hit = G.ray(s.muzzle, s.muzzle + dir * L, G.L_WORLD)
					var clear = hit.is_empty() or (tgt == null and s.muzzle.distance_to(hit.position) > L * 0.8)
					var ff = null
					if clear:
						ff = friendly_in_line(s, s.muzzle, dir, L)
					if not clear:
						s.block_t += 0.15
						s.fire_cd = 0.15
						s.force_peek = true
						if s.block_t > 1.0 and not s.in_cover and s.move_target == null:
							s.block_t = 0.0
							go_to(s, s.pos + Vector3(-dir.z, 0, dir.x) * (1.5 if randf() < 0.5 else -1.5), 3.0)
						if s.block_t > 2.5 and s.in_cover:
							s.block_t = 0.0
							s.cover.ban = G.sim_time + 10.0
							release_cover(s)
							s.decide_t = 0.0
					elif ff != null:
						s.ff_t += 0.15
						s.fire_cd = 0.15
						if s.ff_t > 1.2 and s.move_target == null and not s.in_cover:
							s.ff_t = 0.0
							go_to(s, s.pos + Vector3(-dir.z, 0, dir.x) * (1.6 if randf() < 0.5 else -1.6), 3.0)
					else:
						s.block_t = maxf(0.0, s.block_t - 0.1)
						var moving = s.vel.length() > 0.6
						var spread = W["spread"] * (0.3 if W["pellets"] > 1 else 1.0) + dist * 0.00025 + s.supp * 0.03 + (W["move_spread"] if moving else 0.0) - (0.003 if (s.crouch > 0.5 or s.prone) else 0.0) + extra + (0.02 if s.task == "charge" else 0.0) + (0.025 if s.morale < Morale.SHAKEN else 0.0)
						if s.cls == "sniper" and s.partner != null and is_instance_valid(s.partner) and s.partner.state == "alive" and G.dist2d(s.partner.pos, s.pos) < 10.0:
							spread *= 0.55
						spread *= 1.0 - 0.12 * s.vet
						spread += 0.006       # nobody's a perfect shot under fire
						if Faction.militia(s.team):
							spread += 0.008   # irregulars: less training, worn-out rifles
						Combat.fire_weapon(s, s.muzzle, dir, spread)
						if tgt == null and veh_t == null and s.task == "raze" and s.has_meta("raze_st") and not W["rocket"]:
							Build.raze_damage(s.get_meta("raze_st"), W["dmg"] * 0.5 * W["pellets"])
						s.burst -= 1
						s.mag -= 1
						s.fire_cd = W["rof"]
						if s.mag <= 0:
							s.burst = 0
							if s.start_reload():
								if s.vis_t != null or G.sim_time - s.seen_t < 3.0:
									Voice.say(s, "reload")
							else:
								G.fx.callout(s, "I'm out!")
								s.decide_t = 0.0
			elif s.fire_cd <= 0.0:
				s.burst_cd -= G.DT
				if s.burst_cd <= 0.0:
					var far = W["id"] != "sniper" and s.pos.distance_to(point) > W["range"][1] * 1.4
					if W["rocket"] and tgt == null and veh_t == null and s.task != "raze":
						s.burst = 0
					elif far:
						s.burst = randi_range(1, 3) if randf() < 0.35 else 0
					else:
						s.burst = randi_range(W["burst"][0], W["burst"][1])
					# running low: short, aimed bursts and no shooting at shadows
					var af = s.ammo_frac()
					if af < 0.35:
						s.burst = mini(s.burst, maxi(1, W["burst"][0]))
						if tgt == null:
							s.burst = 0
					elif af < 0.6 and tgt == null and randf() < 0.5 and s.task != "raze":
						s.burst = 0
					s.burst_cd = (randf_range(0.35, 1.1) if W["auto"] else randf_range(0.2, 0.6)) * (1.0 + s.supp) * (3.0 if far else 1.0)
	else:
		s.burst = 0
		s.want_peek = false
		s.force_peek = false
		var yaw = s.aim_yaw
		if s.in_cover and s.cover != null:
			var cp = s.cover
			var ty = atan2(s.threat.x - s.pos.x, s.threat.z - s.pos.z)
			if cp.type == "wall" and cp.side != 0.0:
				var ld = wall_lean_dir(cp)
				yaw = atan2(ld.x * 0.5 + sin(ty) * 0.5, ld.z * 0.5 + cos(ty) * 0.5)
				s.ready_ = true
			elif cp.type == "wall":
				yaw = atan2(cp.n.x, cp.n.z)
				s.ready_ = false
			elif cp.type == "corner":
				yaw = atan2(cp.t.x * 0.6 + sin(ty) * 0.4, cp.t.z * 0.6 + cos(ty) * 0.4)
				s.ready_ = true
			else:
				yaw = ty
				s.ready_ = true
		elif s.want.length_squared() > 0.1:
			yaw = atan2(s.want.x, s.want.z)
			s.ready_ = G.sim_time - s.seen_t < 6.0 and s.want.length_squared() < 16.0
		elif s.task == "medic":
			s.ready_ = false
		elif s.has_threat:
			yaw = atan2(s.threat.x - s.pos.x, s.threat.z - s.pos.z)
			s.ready_ = G.sim_time - s.seen_t < 12.0
		else:
			s.ready_ = false        # nothing about: rifle down, at ease
		s.aim_yaw = G.turn_to(s.aim_yaw, yaw, 3.5 * G.DT)
		s.aim_pitch *= 0.95
		if s.mag < W["mag"] * 0.5 and s.vis_t == null:
			s.start_reload()

static func stance(s) -> void:
	s.lean_t = 0.0
	if s.dragging != null:
		s.crouch_t = 0.5
		s.prone_t = false
		return
	if s.task == "medic" and s.patient != null and is_instance_valid(s.patient) and G.dist2d(s.patient.pos, s.pos) < 1.3:
		s.crouch_t = 1.0
		s.prone_t = false
		return
	if s.want.length_squared() > 0.1 and not s.in_cover:
		s.prone_t = false
	# a medic going in under fire crawls the last stretch to the man he's after
	if s.task == "medic" and s.patient != null and is_instance_valid(s.patient) and s.dragging == null and s.has_seen and G.sim_time - s.seen_t < 6.0:
		var dp = G.dist2d(s.patient.pos, s.pos)
		if dp > 1.3 and dp < 9.0:
			s.prone_t = true
	# a machine gunner out in the open with a target goes down behind the gun and gets the bipod on the ground
	if (s.wid == "lmg" or s.wid == "atrifle") and s.vis_t != null and not s.in_cover and s.want.length_squared() < 0.1 and s.vault == null and s.dragging == null and not ClassAI.busy(s):
		s.prone_t = true
	# pinned down in the open: flat on the ground, crawling for cover
	if s.supp > 1.1 and not s.in_cover and s.task != "flank_move" and s.task != "medic" and s.dragging == null and s.vault == null and not s.zombie and not ClassAI.busy(s):
		s.prone_t = true
	if s.in_cover and s.cover != null:
		var cp = s.cover
		var peek_now = s.want_peek and (s.peek_vis or s.force_peek)
		s.peek_hold -= G.DT
		if peek_now != s.peek_on and s.peek_hold <= 0.0:
			s.peek_on = peek_now
			s.peek_hold = (1.1 if peek_now else 0.7) * (2.0 if cp.upper else 1.0)
		var peek = s.peek_on
		if cp.type == "low" and cp.upper:
			# at a window or parapet upstairs: a steady kneel, rising a little to fire, never bobbing up and down
			s.prone_t = false
			s.crouch_t = 0.35 if peek else 0.7
		elif cp.type == "low":
			s.crouch_t = 0.0 if peek else 1.0
		elif cp.type == "corner" or (cp.type == "wall" and cp.side != 0.0):
			var ldir: Vector3 = cp.t if cp.type == "corner" else wall_lean_dir(cp)
			s.crouch_t = 0.45 if cp.type == "corner" else 0.3
			if peek:
				var rv = Vector3(-cos(s.body_yaw), 0, sin(s.body_yaw))
				s.lean_t = 1.0 if ldir.dot(rv) >= 0.0 else -1.0
				s.crouch_t = 0.1
				var stp = 0.5 if s.force_peek else 0.3
				if cp.type == "wall":
					stp = absf(cp.side) - 0.45
				s.want = G.flat(cp.p + ldir * stp - s.pos) * 3.0
			else:
				var back = G.flat(cp.p - s.pos)
				if back.length_squared() > 0.01:
					s.want = back * 3.0
		else:
			s.crouch_t = 1.0
		return
	var dark_creep = (G.main.is_night() or s.has_meta("scout")) and s.vis_t == null and s.task != "charge" and s.task != "flee"
	# only take a knee when there's been something to take a knee for: otherwise stand easy
	var alert = G.sim_time - s.seen_t < 25.0 or s.supp > 0.3
	if s.want.length_squared() > 0.1:
		s.kneel = false
		s.crouch_t = 0.3 if s.supp > 0.8 else (0.35 if dark_creep else 0.0)
	else:
		s.crouch_t = 0.85 if ((s.kneel and alert) or dark_creep) else 0.0

# ---------------------------------------------------------------- ammunition
# nearest place to restock: a friendly ammo crate, or a fallen soldier's pouches close by
static func find_ammo(s):
	var best = null
	var bd = 1e9
	for a in G.world.ammo_points:
		if (a["team"] >= 0 and a["team"] != s.team) or a.get("stock", 1.0) <= 0.0:
			continue
		var d = G.dist2d(a["p"], s.pos)
		if d < bd and d < 140.0:
			bd = d
			best = a
	bd *= 1.3      # a long walk to a crate is worth less than a body close by
	for o in G.soldiers:
		if o.state == "dead" and o.reserve > 0 and o != s:
			var d2 = G.dist2d(o.pos, s.pos)
			if d2 < 45.0 and d2 < bd:
				bd = d2
				best = o
	return best

# an ammo box set down near the squad becomes a small resupply point
static func drop_crate(s) -> void:
	s.set_crate(false)
	var p = s.pos + Vector3(sin(s.body_yaw), 0, cos(s.body_yaw)) * 0.8
	p.y = G.world.ground_y(p.x, p.z)
	var mi = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(0.6, 0.35, 0.4)
	mi.mesh = bm
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 0.33, 0.2)
	mi.material_override = m
	G.world.geo_root.add_child(mi)
	mi.position = p + Vector3(0, 0.17, 0)
	var ap = {"p": p, "team": s.team, "stock": 40.0, "box": true, "node": mi}
	G.world.ammo_points.append(ap)

# a rifleman runs back for an ammo box when his squad is running dry
static func ammo_run(s) -> bool:
	if s.crate or s.cls != "rifleman" or s.vis_t != null or s.squad == null or Morale.is_leader(s):
		return false
	var q = s.squad
	var low = 0
	for m in q["members"]:
		if is_instance_valid(m) and m.state == "alive" and m.ammo_frac() < 0.35:
			low += 1
	if low < 2 or q.get("ammo_run_t", -99.0) > G.sim_time:
		return false
	var best = null
	var bd = 110.0
	for a in G.world.ammo_points:
		if a["team"] == s.team and not a.get("box", false) and a.get("stock", 50.0) > 15.0:
			var d = G.dist2d(a["p"], s.pos)
			if d < bd and d > 15.0:
				bd = d
				best = a
	if best == null:
		return false
	q["ammo_run_t"] = G.sim_time + 60.0
	release_cover(s)
	s.task = "fetch"
	s.supply_target = best
	go_to(s, best["p"], 5.2)
	G.fx.callout(s, G.pick(["I'll get us more ammo!", "Running for ammo!"]))
	return true

static func fetch_tick(s) -> void:
	if s.task != "fetch":
		return
	var a = s.supply_target
	if s.crate:
		var L = Squad.leader_of(s.squad) if s.squad != null else null
		var goal: Vector3 = L.pos if L != null and is_instance_valid(L) and L != s else s.pos
		if G.dist2d(goal, s.pos) < 3.0:
			drop_crate(s)
			s.task = null
			s.decide_t = 0.0
			G.fx.callout(s, G.pick(["Ammo here!", "Grab a mag!"]))
		elif s.move_target == null or s.move_target.distance_to(goal) > 3.0:
			go_to(s, goal, 4.2)
		return
	if a == null or not (a is Dictionary) or not G.world.ammo_points.has(a):
		s.task = null
		return
	if G.dist2d(a["p"], s.pos) < 2.4:
		if a.has("stock"):
			a["stock"] -= 15.0
		s.set_crate(true)
		s.supply_target = null
	elif s.move_target == null:
		go_to(s, a["p"], 5.2)

# a man running dry shouts for a mag, and the nearest mate with plenty and the same gun tosses him one
static func pass_ammo(s) -> void:
	if s.state != "alive" or s.vehicle != null or s.zombie or s.is_player or s.reserve > 0 or s.W["rocket"] or s.W["flame"]:
		return
	if G.sim_time < s.get_meta("mag_ask_t", -99.0):
		return
	s.set_meta("mag_ask_t", G.sim_time + 12.0)
	var best = null
	var bd = 9.0
	for o in G.soldiers:
		if o == s or o.team != s.team or o.state != "alive" or o.vehicle != null or o.zombie or o.wid != s.wid:
			continue
		if o.reserve < o.W["mag"] * 2:
			continue
		var d = G.dist2d(o.pos, s.pos)
		if d < bd:
			bd = d
			best = o
	G.fx.callout(s, G.pick(["Mag! Anyone got a mag?", "I'm dry, throw me one!", "Need ammo here!"]))
	if best == null:
		return
	var n = mini(best.W["mag"] * 2, best.reserve - best.W["mag"])
	best.reserve -= n
	s.reserve += n
	G.fx.callout(best, G.pick(["Catch!", "Here, two mags!", "Heads up!"]))
	G.fx.toss_mag(best.chest(), s.chest())

# standing at a crate (or over a body) restocks you
static func supply_tick(s, dt: float) -> void:
	if s.state != "alive":
		return
	if s.ammo_frac() >= 0.999 and s.grenades >= 2:
		s.resupply_t = 0.0
		return
	var near = null
	for a in G.world.ammo_points:
		if (a["team"] < 0 or a["team"] == s.team) and G.dist2d(a["p"], s.pos) < 2.6 and a.get("stock", 1.0) > 0.0:
			near = a
			break
	if near != null:
		s.resupply_t += dt
		if s.resupply_t >= 1.0:
			s.resupply_t = 0.0
			s.resupply()
			if near.has("stock"):
				near["stock"] -= 6.0
				if near.get("box", false) and near["stock"] <= 0.0:
					if is_instance_valid(near.get("node")):
						near["node"].queue_free()
					G.world.ammo_points.erase(near)
			if s.is_player:
				G.ui.message("Resupplied")
			elif s.task == "resupply":
				s.task = null
				s.supply_target = null
				s.decide_t = 0.0
				G.fx.callout(s, G.pick(["Got ammo!", "Restocked!"]))
		return
	s.resupply_t = 0.0
	if s.task == "resupply" and s.supply_target is Object and is_instance_valid(s.supply_target) and G.dist2d(s.supply_target.pos, s.pos) < 1.8:
		scavenge(s, s.supply_target)
		s.task = null
		s.supply_target = null
		s.decide_t = 0.0

static func scavenge(s, body) -> void:
	# out of rounds for my own gun: pick up his instead (a rocket launcher first, if there's armour about)
	var his_left = body.reserve + body.mag
	var armour_near = G.vehicles.any(func(v): return v.team != s.team and not v.dead and (v.spec["tracked"] or v.kind in ["armoredcar", "halftrack", "technical"]) and G.dist2d(v.pos, s.pos) < 120.0)
	var dry = s.reserve <= 0 and s.mag < s.W["mag"] * 0.3
	var want_rocket = body.W["rocket"] and not s.W["rocket"] and armour_near and s.cls in ["rifleman", "assault", "engineer", "officer"]
	if body.wid != s.wid and his_left > 0 and body.gun_body != null and is_instance_valid(body.gun_body) and (dry or want_rocket) and not s.zombie:
		var keep_r = body.reserve
		var keep_m = body.mag
		s.set_weapon(body.wid)
		s.reserve = mini(keep_r, s.W["mag"] * s.W["mags"])
		s.mag = mini(keep_m, s.W["mag"])
		body.reserve = 0
		body.mag = 0
		body.gun_body.queue_free()
		body.gun_body = null
		if s.is_player:
			G.ui.message("Picked up %s's %s" % [body.sname, s.W["name"].to_lower()])
		else:
			G.fx.callout(s, G.pick(["Taking his rocket!", "Got a launcher!"]) if s.W["rocket"] else G.pick(["I'm out, taking his gun!", "Picked up his weapon!"]))
		return
	# a fallen soldier's rounds only fit if it's the same kind of gun; otherwise take a couple of generic mags
	var got = body.reserve if body.wid == s.wid else mini(body.reserve, s.W["mag"] * 2)
	s.reserve = mini(s.reserve + got, s.W["mag"] * s.W["mags"])
	body.reserve = 0
	if body.grenades > 0:
		s.grenades += 1
		body.grenades -= 1
	if s.is_player:
		G.ui.message("Picked up ammo from %s" % body.sname)
	else:
		G.fx.callout(s, "Took his ammo.")

# would this shot (or its spread, or a rocket's blast) endanger a friend?
static func friendly_in_line(s, from: Vector3, dir: Vector3, L: float):
	var rocket = s.W["rocket"]
	var end = from + dir * L
	for o in G.soldiers:
		if o == s or o.team != s.team or o.state == "dead":
			continue
		var c = o.chest()
		if rocket and c.distance_to(end) < 8.0:
			return o
		var v = c - from
		var t = v.dot(dir)
		if t < 0.0 or t > L + 4.0:
			continue
		var perp = (v - dir * t).length()
		if perp < 0.75 + t * 0.03:
			return o
	return null

static func grid_ref(p: Vector3) -> String:
	var cols = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	var b: Rect2 = G.world.bounds
	var gx = clampi(int((p.x - b.position.x) / 25.0), 0, 25)
	var gz = clampi(int((p.z - b.position.y) / 25.0), 0, 99)
	return "%s%d" % [cols[gx], gz + 1]

# vehicles aren't on the walking map, so a man heading past one walks round it instead of through it:
# if his next steps would take him into a vehicle's footprint, he slides along its side; if he's already
# inside it (just climbed out, or it rolled up to him) he steps out to the nearer side
# men step round each other instead of shoving, and take turns at a doorway
static func _keep_apart(s) -> void:
	if s.vault != null or s.vehicle != null or s.climb != null or s.scramble != null or s.dragging != null:
		return
	var moving = s.want.length_squared() > 0.04
	var push = Vector3.ZERO
	var passer = false
	for o in G.soldiers_near(s.pos):
		if o == s or o.state != "alive" or o.vehicle != null or absf(o.pos.y - s.pos.y) > 1.0:
			continue
		var rel = G.flat(s.pos - o.pos)
		var d2 = rel.length_squared()
		if d2 > 0.5 or d2 < 0.0001:
			continue
		var d = sqrt(d2)
		push += rel / d * (0.71 - d) / 0.71
		if o.want.length_squared() > 0.04:
			passer = true
	if push != Vector3.ZERO:
		if moving:
			var sp = s.want.length()
			s.want = (s.want + push * sp * 1.4).limit_length(sp * 1.1)
		elif passer and not s.prone and s.order == null and not s.in_cover:
			# someone squeezing past: shuffle aside
			s.want = push * 1.2
	# a doorway: one at a time, whoever is in it first goes first
	if s.door_wait > 0.0:
		s.door_wait -= G.DT
		if moving:
			s.want *= 0.1
		return
	if not moving or (Engine.get_physics_frames() + s.id) % 4 != 0:
		return
	var dr = Doors.door_near(s.pos, 1.7)
	if dr == null or absf(s.pos.y + 1.1 - dr["c"].y) > 1.4:
		return
	var dc: Vector3 = dr["c"]
	var my = G.dist2d(s.pos, dc)
	if my < 0.75 or G.flat(dc - s.pos).dot(s.want) <= 0.0:
		return
	for o in G.soldiers_near(dc):
		if o == s or o.state != "alive" or absf(o.pos.y - s.pos.y) > 1.0:
			continue
		if G.dist2d(o.pos, dc) < 0.7 and o.want.length_squared() > 0.04:
			s.door_wait = 0.45
			s.want *= 0.1
			return

static func _round_vehicles(s) -> void:
	if s.vault != null or s.vehicle != null:
		return
	for v in G.vehicles:
		if v.dead and not v.spec.get("static", false) and v.spec.get("air", false):
			continue
		if v.spec.get("air", false) and v.alt > 2.0:
			continue
		var rel = G.flat(s.pos - v.pos)
		var R = v.spec["len"] * 0.5 + 1.0
		if rel.length_squared() > R * R:
			continue
		var f = v.forward()
		var r = Vector3(f.z, 0, -f.x)
		var hl = v.spec["len"] * 0.5 + 0.35
		var hw = v.spec["wid"] * 0.5 + 0.35
		var lx = rel.dot(r)
		var lz = rel.dot(f)
		# standing inside it: out to the nearest edge
		if absf(lx) < hw and absf(lz) < hl:
			var ex = hw - absf(lx)
			var ez = hl - absf(lz)
			if ex < ez:
				s.pos += r * signf(lx if lx != 0.0 else 1.0) * minf(ex, 0.08)
			else:
				s.pos += f * signf(lz if lz != 0.0 else 1.0) * minf(ez, 0.08)
			continue
		# about to walk into it: turn the step along its side
		var w: Vector3 = s.want
		if w.length_squared() < 0.01:
			continue
		var ahead = rel + w.normalized() * 0.9
		var ax = ahead.dot(r)
		var az = ahead.dot(f)
		if absf(ax) < hw and absf(az) < hl:
			var wl = Vector2(w.dot(r), w.dot(f))
			# go round the short way: along the long side if we're beside it, round the end if we're at an end
			if absf(lx) >= hw - 0.05:
				wl = Vector2(0.0, signf(wl.y if absf(wl.y) > 0.05 else (lz if lz != 0.0 else 1.0)) * w.length())
			else:
				wl = Vector2(signf(lx if lx != 0.0 else 1.0) * w.length(), 0.0)
			s.want = r * wl.x + f * wl.y
