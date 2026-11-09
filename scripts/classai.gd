class_name ClassAI
extends RefCounted
# What each class does besides shooting: engineers build, mine, repair and blow things up;
# radio operators call in artillery; medics patch people up; anti-tank soldiers hunt vehicles.
# jobs() runs inside AI.decide and returns true if the soldier took on a job this time.

static func jobs(s, known: bool, threat: Vector3) -> bool:
	s.job_cd -= 2.0
	if s.cls != "engineer" and _help_build(s):
		return true
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
	return s.task in ["repair", "build", "mine", "patch", "construct"]

static func _start_construct(s, st) -> void:
	AI.release_cover(s)
	s.task = "construct"
	s.build_site = st
	AI.go_to(s, Build.work_spot(st, s), 4.6)

# riflemen and the like lend a hand on the bigger jobs when it's quiet
static func _help_build(s) -> bool:
	if s.vis_t != null or s.job_cd > 0.0 or Morale.is_leader(s) or s.cls in ["officer", "medic", "sniper", "spotter", "mg"] or randf() > 0.15:
		return false
	var no_eng = true
	for o in G.soldiers:
		if o.team == s.team and o.cls == "engineer" and o.state == "alive":
			no_eng = false
			break
	var st = Build.work_site(s.team, s.pos, 90.0 if no_eng else 45.0)
	if st == null or not (st["kind"] in ["fob", "hq", "bunker", "hospital", "depot", "radio", "tower"] or no_eng):
		return false
	if Build.helpers(st) >= (5 if no_eng else 3):
		return false
	_start_construct(s, st)
	if randf() < 0.4:
		G.fx.callout(s, G.pick(["Giving them a hand.", "I'll help build.", "Grab a shovel!"]))
	return true

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
		# and enemy positions: FOBs, nests, bunkers
		var es = Build.enemy_site_near(s.team, s.pos, 26.0)
		if es != null and Build.sees(s.head_pos(), es[0]):
			if G.dist2d(es[1], s.pos) < 13.0:
				Combat.throw_grenade(s, es[1], "satchel")
				G.fx.callout(s, G.pick(["Charge set!", "Blowing their position!"]))
				return false
			AI.release_cover(s)
			AI.go_to(s, es[1], 5.0)
			s.task = "sapper"
			return true
	var far_contact = s.vis_t != null and is_instance_valid(s.vis_t) and G.dist2d(s.vis_t.pos, s.pos) > 60.0
	if far_contact and s.job_cd <= 0.0 and s.task != "construct":
		var ws0 = Build.work_site(s.team, s.pos, 120.0)
		if ws0 != null and ws0["kind"] in ["fob", "hq"] and Build.helpers(ws0) < 3:
			_start_construct(s, ws0)
			return true
	if s.vis_t != null or s.job_cd > 0.0:
		return false
	# repair damaged friendly vehicles
	for v in G.vehicles:
		if v.team == s.team and not v.dead and not v.spec.get("air", false) and (v.hp < v.spec["hp"] * 0.75 or v.tracks_broken or v.burning) and G.dist2d(v.pos, s.pos) < 40.0:
			AI.release_cover(s)
			s.task = "repair"
			s.board_target = v
			AI.go_to(s, v.pos + G.flat(s.pos - v.pos).normalized() * (v.spec["len"] * 0.5 + 0.8), 4.8)
			G.fx.callout(s, G.pick(["I'll fix her up!", "Repairing!"]))
			return true
	# build: our own sites first
	var ws = Build.work_site(s.team, s.pos, 160.0)
	if ws != null and Build.helpers(ws) < 4:
		_start_construct(s, ws)
		G.fx.callout(s, G.pick(["On my way to build.", "Engineer moving to the site.", "I'll get it built."]))
		return true
	# dig in: sandbags where we're holding and there's no cover, and mines on the way in
	var holding = s.task in ["hold", "defend", "objective"] or (Obj.uses_points() and not Obj.points.is_empty() and G.dist2d(s.pos, AI.objective_for(s)) < 14.0)
	if not holding:
		return false
	if s.kits > 0 and s.cover == null and randf() < 0.6:
		var dir = G.flat(threat - s.pos)
		if dir.length_squared() < 0.01:
			dir = Vector3(0, 0, 1)
		var at = s.pos + dir.normalized() * 1.5
		if not G.world.inside_any(at.x, at.z, 0.8) and Build.site_at(at, 1.0) == null:
			s.kits -= 1
			var st = Build.place("sandbags", s.team, at, dir)
			_start_construct(s, st)
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
		"construct":
			var st = s.build_site
			var close_enemy = s.vis_t != null and is_instance_valid(s.vis_t) and G.dist2d(s.vis_t.pos, s.pos) < 45.0
			if st == null or st["done"] or st["dead"] or not Build.sites.has(st) or close_enemy or s.supp > 1.5:
				s.task = null
				s.build_site = null
				s.decide_t = 0.0
				s.job_cd = 4.0
				return
			if G.dist2d(s.pos, st["p"]) < Build.build_radius(st) + 0.7:
				AI.stop_move(s)
				s.want = Vector3.ZERO
				s.crouch_t = 0.75
				var to = G.flat(st["p"] - s.pos)
				s.aim_yaw = G.turn_to(s.aim_yaw, atan2(to.x, to.z), 4.0 * G.DT)
				s.hand_t = s.pos + to.normalized() * 0.6 + Vector3(0, 0.2 + absf(sin(G.sim_time * 7.0)) * 0.35, 0)
				Build.add_work(st, (1.0 if s.cls == "engineer" else 0.55) * G.DT)
				if randf() < G.DT * 2.2:
					G.audio.hammer(s.pos)
			elif s.move_target == null:
				AI.go_to(s, Build.work_spot(st, s), 4.6)
		"mine":
			if s.move_target == null:
				Combat.place_mine(s, s.pos + G.flat(s.board_target - s.pos) * 0.2, "ap")
				s.mines -= 1
				s.task = null
				s.job_cd = 8.0
				s.decide_t = 0.0
		"repair":
			var v = s.board_target
			if v == null or not is_instance_valid(v) or v.dead or (v.hp >= v.spec["hp"] and not v.tracks_broken and not v.burning):
				s.task = null
				s.decide_t = 0.0
				return
			if G.dist2d(v.pos, s.pos) < v.spec["len"] * 0.5 + 1.8:
				AI.stop_move(s)
				s.crouch_t = 0.6
				s.hand_t = v.center()
				s.aim_yaw = G.turn_to(s.aim_yaw, atan2(v.pos.x - s.pos.x, v.pos.z - s.pos.z), 4.0 * G.DT)
				v.repair(40.0 * G.DT)
				if v.hp >= v.spec["hp"]:
					v.tracks_broken = false
					v.burning = false
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
	if best == null:
		# a known enemy FOB or HQ is worth a few shells too
		for st in Build.sites:
			if st["team"] == team or st["dead"] or not st["done"] or not (st["kind"] in ["fob", "hq", "bunker", "mgnest", "mortarpit", "depot", "radio"]):
				continue
			if G.dist2d(st["p"], from) < min_d:
				continue
			var spotted = false
			var friends2 = false
			for f in G.soldiers:
				if f.team == team and f.state != "dead":
					var d = G.dist2d(f.pos, st["p"])
					if d < 85.0 and Build.sees(f.head_pos(), st):
						spotted = true
					if d < 20.0:
						friends2 = true
			if spotted and not friends2:
				return st["p"]
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
