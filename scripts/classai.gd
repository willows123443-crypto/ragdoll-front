class_name ClassAI
extends RefCounted
# What each class does besides shooting: engineers build, mine, repair and blow things up;
# radio operators call in artillery; medics patch people up; anti-tank soldiers hunt vehicles.
# jobs() runs inside AI.decide and returns true if the soldier took on a job this time.

static func jobs(s, known: bool, threat: Vector3) -> bool:
	s.job_cd -= 2.0
	match s.cls:
		"engineer":
			return _engineer(s, known, threat)
		"radio":
			_radio(s)
		"medic":
			return _medic(s, known)
		"at":
			return _anti_tank(s)
	return false

static func busy(s) -> bool:
	return s.task in ["repair", "build", "mine", "patch"]

# ---------------------------------------------------------------- engineers
static func _engineer(s, known: bool, threat: Vector3) -> bool:
	# blow up enemy vehicles and gun nests that come close
	if s.satchels > 0:
		for v in G.vehicles:
			if v.team != s.team and not v.dead and G.dist2d(v.pos, s.pos) < 22.0 and not G.blocked(s.head_pos(), v.center()):
				if G.dist2d(v.pos, s.pos) < 13.0:
					Combat.throw_grenade(s, v.pos, "satchel")
					return false
				AI.release_cover(s)
				AI.go_to(s, v.pos, 5.4)
				s.task = "sapper"
				return true
	if s.vis_t != null or s.job_cd > 0.0:
		return false
	# repair damaged friendly vehicles
	for v in G.vehicles:
		if v.team == s.team and not v.dead and v.hp < v.spec["hp"] * 0.75 and G.dist2d(v.pos, s.pos) < 40.0:
			AI.release_cover(s)
			s.task = "repair"
			s.board_target = v
			AI.go_to(s, v.pos + G.flat(s.pos - v.pos).normalized() * (v.spec["len"] * 0.5 + 0.8), 4.8)
			G.fx.callout(s, G.pick(["I'll fix her up!", "Repairing!"]))
			return true
	# dig in: sandbags where we're holding and there's no cover, and mines on the way in
	var holding = s.task in ["hold", "defend", "objective"] or (Obj.uses_points() and not Obj.points.is_empty() and G.dist2d(s.pos, AI.objective_for(s)) < 14.0)
	if not holding:
		return false
	if s.kits > 0 and s.cover == null and randf() < 0.6:
		s.task = "build"
		s.build_t = 2.5
		s.board_target = threat
		AI.stop_move(s)
		G.fx.callout(s, G.pick(["Digging in!", "Putting up sandbags!"]))
		return true
	if s.mines > 0 and known and randf() < 0.5:
		var dir = G.flat(threat - s.pos).normalized()
		var spot = s.pos + dir * randf_range(8.0, 14.0) + Vector3(-dir.z, 0, dir.x) * randf_range(-6.0, 6.0)
		if not G.world.inside_any(spot.x, spot.z, 0.5):
			s.task = "mine"
			s.board_target = spot
			AI.release_cover(s)
			AI.go_to(s, spot, 4.0)
			return true
	return false

# called every tick while an engineer is on a job
static func work(s) -> void:
	match s.task:
		"build":
			s.crouch_t = 1.0
			s.want = Vector3.ZERO
			s.hand_t = s.pos + G.flat(s.board_target - s.pos).normalized() * 0.6 + Vector3(0, 0.3, 0)
			s.build_t -= G.DT
			if s.build_t <= 0.0:
				var dir = G.flat(s.board_target - s.pos).normalized()
				var at = s.pos + dir * 1.4
				var along_x = absf(dir.z) > absf(dir.x)
				if not G.world.inside_any(at.x, at.z, 0.6):
					G.world.build_now(func(): G.world.sandbags(at.x, at.z, 3.0, along_x))
					s.kits -= 1
				s.task = null
				s.job_cd = 10.0
				s.decide_t = 0.0
		"mine":
			if s.move_target == null:
				Combat.place_mine(s, s.pos + G.flat(s.board_target - s.pos) * 0.2, "ap")
				s.mines -= 1
				s.task = null
				s.job_cd = 8.0
				s.decide_t = 0.0
		"repair":
			var v = s.board_target
			if v == null or not is_instance_valid(v) or v.dead or v.hp >= v.spec["hp"]:
				s.task = null
				s.decide_t = 0.0
				return
			if G.dist2d(v.pos, s.pos) < v.spec["len"] * 0.5 + 1.8:
				AI.stop_move(s)
				s.crouch_t = 0.6
				s.hand_t = v.center()
				s.aim_yaw = G.turn_to(s.aim_yaw, atan2(v.pos.x - s.pos.x, v.pos.z - s.pos.z), 4.0 * G.DT)
				v.hp = minf(v.spec["hp"], v.hp + 40.0 * G.DT)
				if randf() < 0.05:
					G.fx.impact(v.center() + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)), Vector3.UP)
			elif s.move_target == null:
				AI.go_to(s, v.pos, 4.8)
		"patch":
			var w = s.patient
			if w == null or not is_instance_valid(w) or w.state != "alive" or w.hp >= 95.0:
				s.task = null
				s.patient = null
				s.decide_t = 0.0
				return
			if G.dist2d(w.pos, s.pos) < 1.3:
				AI.stop_move(s)
				s.crouch_t = 0.8
				s.hand_t = w.chest()
				w.hp = minf(100.0, w.hp + 25.0 * G.DT)
				if w.hp >= 95.0:
					Stats.healed(s)
					G.fx.callout(w, G.pick(["Thanks, doc.", "Good as new."]))
			elif s.move_target == null or s.move_target.distance_to(w.pos) > 1.5:
				AI.go_to(s, w.pos, 5.0)

# ---------------------------------------------------------------- medics: patch up the walking wounded too
static func _medic(s, known: bool) -> bool:
	if s.vis_t != null or s.job_cd > 0.0:
		return false
	var best = null
	var bd = 25.0
	for o in G.soldiers:
		if o != s and o.team == s.team and o.state == "alive" and o.hp < 65.0 and o.vehicle == null:
			var d = G.dist2d(o.pos, s.pos)
			if d < bd:
				bd = d
				best = o
	if best == null:
		return false
	AI.release_cover(s)
	s.task = "patch"
	s.patient = best
	s.job_cd = 6.0
	AI.go_to(s, best.pos, 5.0)
	G.fx.callout(s, G.pick(["Let me see that.", "Hold still, I'll patch you."]))
	return true

# ---------------------------------------------------------------- radio operators: artillery on enemy clusters
static func _radio(s) -> void:
	s.radio_cd -= 2.0
	if s.radio_cd > 0.0:
		return
	var target = artillery_target(s.team, s.pos, 40.0)
	if target == null:
		return
	s.radio_cd = randf_range(55.0, 75.0)
	call_artillery(s, target)

# where enemies bunch up, as far as the team knows, and nowhere near friends
static func artillery_target(team: int, from: Vector3, min_d: float):
	var best = null
	var bn = 2
	for o in G.soldiers:
		if o.team == team or o.state == "dead" or o.hidden_in_vehicle or G.dist2d(o.pos, from) < min_d:
			continue
		var seen = false
		for f in G.soldiers:
			if f.team == team and f.state != "dead" and f.intel.has(o) and f.intel[o]["seen"] and G.sim_time - f.intel[o]["t"] < 10.0:
				seen = true
				break
		if not seen:
			continue
		var n = 0
		for o2 in G.soldiers:
			if o2.team == o.team and o2.state != "dead" and G.dist2d(o2.pos, o.pos) < 12.0:
				n += 1
		var friends = false
		for f in G.soldiers:
			if f.team == team and f.state != "dead" and G.dist2d(f.pos, o.pos) < 22.0:
				friends = true
				break
		if n > bn and not friends:
			bn = n
			best = o.pos
	return best

static func call_artillery(s, target: Vector3) -> void:
	for i in range(6):
		Combat.shell_at(target, 10.0, 6.0 + i * randf_range(0.5, 1.0), s, 1.45)
	G.fx.callout(s, G.pick(["Fire mission, danger close!", "Artillery inbound!", "Requesting fire support!"]))
	G.ui.radio(s.team, "%s: fire mission on grid %s" % [s.sname, AI.grid_ref(target)])

# ---------------------------------------------------------------- anti-tank: go after enemy armour
static func _anti_tank(s) -> bool:
	if s.wid != "rpg" and s.wid != "atrifle":
		return false
	if s.wid == "rpg" and s.rockets <= 0:
		return false
	var best = null
	var bd = 70.0
	for v in G.vehicles:
		if v.team != s.team and not v.dead and v.kind != "mortar":
			var d = G.dist2d(v.pos, s.pos)
			if d < bd:
				bd = d
				best = v
	if best == null or bd < 25.0:
		return false
	# close in to firing range, using cover on the way
	var c = AI.find_cover(s, best.pos, "advance")
	if c != null and G.dist2d(c.p, best.pos) < bd:
		AI.take_cover(s, c)
	else:
		AI.go_to(s, best.pos + G.flat(s.pos - best.pos).normalized() * 30.0, 4.6)
	s.task = "hunt"
	if randf() < 0.3:
		G.fx.callout(s, G.pick(["Tank! I'm on it!", "Moving on the armour!"]))
	return true
