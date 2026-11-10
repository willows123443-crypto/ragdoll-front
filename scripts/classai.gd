class_name ClassAI
extends RefCounted
# What each class does besides shooting: engineers build, mine, repair and blow things up;
# radio operators call in artillery; medics patch people up; anti-tank soldiers hunt vehicles.
# jobs() runs inside AI.decide and returns true if the soldier took on a job this time.

static func jobs(s, known: bool, threat: Vector3) -> bool:
	s.job_cd -= 2.0
	grenade_structure(s)
	_rifle_grenade(s, known, threat)
	_sticky(s)
	_sniper_move(s)
	if G.mode == "sabotage" and s.team == 0 and s.satchels > 0 and s.cls != "engineer":
		var r = _satchel_site(s, 40.0)
		if r >= 0:
			return r == 1
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
	return s.task in ["repair", "build", "mine", "patch", "construct", "defuse", "fixwheel", "sweep"]

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
		var r = _satchel_site(s, 26.0)
		if r >= 0:
			return r == 1
	var far_contact = s.vis_t != null and is_instance_valid(s.vis_t) and G.dist2d(s.vis_t.pos, s.pos) > 60.0
	if far_contact and s.job_cd <= 0.0 and s.task != "construct":
		var ws0 = Build.work_site(s.team, s.pos, 120.0)
		if ws0 != null and ws0["kind"] in ["fob", "hq"] and Build.helpers(ws0) < 3:
			_start_construct(s, ws0)
			return true
	if s.vis_t != null or s.job_cd > 0.0:
		return false
	# sweep for enemy mines nearby and clear them
	for m in Combat.mines:
		if m["team"] != s.team and m["arm"] <= 0.0 and G.dist2d(m["p"], s.pos) < 14.0:
			AI.release_cover(s)
			s.task = "defuse"
			s.board_target = m
			s.build_t = 0.0
			AI.go_to(s, m["p"], 3.2)
			G.fx.callout(s, G.pick(["Mine! I'll clear it.", "Found a mine, stand back."]))
			return true
	# repair damaged friendly vehicles
	for v in G.vehicles:
		if v.team == s.team and not v.dead and not v.spec.get("air", false) and (v.hp < v.spec["hp"] * 0.75 or v.tracks_broken or v.burning) and G.dist2d(v.pos, s.pos) < 40.0:
			AI.release_cover(s)
			s.task = "repair"
			s.board_target = v
			AI.go_to(s, v.pos + G.flat(s.pos - v.pos).normalized() * (v.spec["len"] * 0.5 + 0.8), 4.8)
			G.fx.callout(s, G.pick(["I'll fix her up!", "Repairing!"]))
			return true
	# the other side lays mines or bombs: sweep the road ahead with a detector
	if s.task != "sweep" and randf() < 0.25 and _mine_threat(s.team) and s.get_meta("swept_t", -999.0) < G.sim_time - 40.0:
		s.set_meta("swept_t", G.sim_time)
		var goal = AI.objective_for(s)
		var dir = G.flat(goal - s.pos)
		if dir.length() > 12.0:
			var to = s.pos + dir.normalized() * minf(35.0, dir.length() - 6.0)
			# keep to the road if there's one close
			for rd in G.world.roads:
				if s.pos.z > rd[2] - 12.0 and s.pos.z < rd[3] + 12.0 and rd[1] - rd[0] > rd[3] - rd[2]:
					to.z = (rd[2] + rd[3]) * 0.5
					break
			AI.release_cover(s)
			s.task = "sweep"
			s.build_t = 0.0
			s.set_meta("sweep_to", to)
			AI.go_to(s, to, 1.5)
			G.fx.callout(s, G.pick(["Sweeping for mines, stay behind me.", "Detector out. Nobody passes me.", "Checking the road for mines."]))
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
	if s.kits > 0 and s.cover == null and randf() < 0.6 and "sandbags" in Build.allowed(s.team):
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
			_build_work(s, st)
		"defuse":
			var mn = s.board_target
			if mn == null or not (mn is Dictionary) or not Combat.mines.has(mn) or (s.vis_t != null and G.dist2d(s.vis_t.pos, s.pos) < 40.0):
				s.task = null
				s.board_target = null
				s.decide_t = 0.0
				return
			if G.dist2d(mn["p"], s.pos) < 1.3:
				AI.stop_move(s)
				s.crouch_t = 1.0
				s.hand_t = mn["p"] + Vector3(0, 0.15, 0)
				s.build_t += G.DT
				if s.build_t > 3.5:
					if is_instance_valid(mn["node"]):
						mn["node"].queue_free()
					Combat.mines.erase(mn)
					s.task = null
					s.board_target = null
					s.decide_t = 0.0
					G.fx.callout(s, G.pick(["Mine cleared!", "Safe now."]))
			elif s.move_target == null:
				AI.go_to(s, mn["p"], 3.2)
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
				if v.burning:
					# drag the crew out and smother the fire
					for k in range(v.seats.size()):
						var cs = v.seats[k]
						if cs != null and is_instance_valid(cs) and not cs.is_player:
							cs.dismount(false)
					v.burning = false
					G.fx.callout(s, G.pick(["Get out, she's burning!", "Pulling you out!"]))
				s.aim_yaw = G.turn_to(s.aim_yaw, atan2(v.pos.x - s.pos.x, v.pos.z - s.pos.z), 4.0 * G.DT)
				v.repair(40.0 * G.DT)
				if v.hp >= v.spec["hp"]:
					v.tracks_broken = false
					v.burning = false
				if randf() < 0.05:
					G.fx.impact(v.center() + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)), Vector3.UP)
			elif s.move_target == null:
				AI.go_to(s, v.pos, 4.8)
		"fixwheel":
			# a crewman out at the side of his vehicle with a hammer and a wrench
			var fv = s.board_target
			if fv == null or not (fv is Vehicle) or not is_instance_valid(fv) or fv.dead or not (fv.tracks_broken or fv.tyres > 0):
				s.task = "board" if fv != null and fv is Vehicle and is_instance_valid(fv) and not fv.dead else null
				s.decide_t = 0.0
				return
			var right = Vector3(cos(fv.yaw), 0, -sin(fv.yaw))
			var sd = 1.0 if right.dot(s.pos - fv.pos) >= 0.0 else -1.0
			var spot = fv.pos + right * sd * (fv.spec["wid"] * 0.5 + 0.7) - fv.forward() * fv.spec["len"] * 0.2
			if G.dist2d(spot, s.pos) < 1.0:
				AI.stop_move(s)
				s.want = Vector3.ZERO
				s.crouch_t = 0.9
				s.ready_ = false
				var wheel = fv.pos + right * sd * fv.spec["wid"] * 0.45 - fv.forward() * fv.spec["len"] * 0.2 + Vector3(0, 0.5, 0)
				s.aim_yaw = G.turn_to(s.aim_yaw, atan2(wheel.x - s.pos.x, wheel.z - s.pos.z), 5.0 * G.DT)
				s.hand_t = wheel
				s.tool_mode = "hammer"
				s.build_t += G.DT
				if s.build_t > (10.0 if fv.tracks_broken else 6.0):
					fv.tracks_broken = false
					fv._fix_tyres()
					fv.fix_by = null
					s.task = "board"
					s.board_target = fv
					G.fx.callout(s, G.pick(["Fixed! Mount up!", "She's good, let's go!", "Track's back on!"]))
			elif s.move_target == null or G.dist2d(s.move_target, spot) > 1.0:
				AI.go_to(s, spot, 4.0)
		"sweep":
			_sweep(s)
		"patch":
			var w = s.patient
			if w == null or not is_instance_valid(w) or w.state != "alive" or (w.hp >= 95.0 and w.bleed <= 0.0):
				s.task = null
				s.patient = null
				s.decide_t = 0.0
				return
			if G.dist2d(w.pos, s.pos) < 1.3:
				AI.stop_move(s)
				s.crouch_t = 0.8
				s.hand_t = w.chest()
				w.bleed = 0.0
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
		if o != s and o.team == s.team and o.state == "alive" and (o.hp < 65.0 or o.bleed > 0.1) and o.vehicle == null:
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
		if o.team == team or o.state == "dead" or o.hidden_in_vehicle or G.dist2d(o.pos, from) < min_d or G.near_spawn(o.pos):
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
			if st["team"] == team or st["dead"] or not st["done"] or not (st["kind"] in ["fob", "fob2", "hq", "bunker", "mgnest", "pillbox", "mortarpit", "depot", "radio", "aa"]):
				continue
			if G.dist2d(st["p"], from) < min_d or not Build.spotted(st, team) or (st["kind"] != "hq" and G.near_spawn(st["p"])):
				continue
			if st["kind"] == "hq" and G.mode == "commander":
				continue        # shells can't touch it there
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
	# a red smoke marker goes down where the shells will fall
	Combat.smoke_at(target, 14.0, Color(0.85, 0.22, 0.18), 0.4)
	Support.fire_mission(s.team, target, s, 6, 10.0, 1.45)
	G.fx.callout(s, G.pick(["Fire mission, over!", "Requesting fire, grid %s!" % AI.grid_ref(target), "Battery, fire mission!"]))

# ---------------------------------------------------------------- anti-tank: go after enemy armour
# returns -1 nothing to do, 0 threw a charge, 1 moving in to place one
static func _satchel_site(s, reach: float) -> int:
	var es = Build.enemy_site_near(s.team, s.pos, reach)
	if es == null or not Build.sees(s.head_pos(), es[0]):
		return -1
	if G.dist2d(es[1], s.pos) < 13.0:
		Combat.throw_grenade(s, es[1], "satchel")
		G.fx.callout(s, G.pick(["Charge set!", "Blowing their position!"]))
		return 0
	AI.release_cover(s)
	AI.go_to(s, es[1], 5.0)
	s.task = "sapper"
	return 1

# riflemen lob rifle grenades at enemies dug in behind cover
static func _rifle_grenade(s, known: bool, threat: Vector3) -> void:
	if s.rgren <= 0 or s.wid != "rifle" or s.job_cd > 0.0 or not known:
		return
	var tgt = s.vis_t
	var p: Vector3 = threat
	if tgt != null and is_instance_valid(tgt):
		p = tgt.pos
		if not tgt.in_cover and randf() < 0.7:
			return
	var d = G.dist2d(p, s.pos)
	if d < 28.0 or d > 115.0 or randf() < 0.5:
		return
	for f in G.soldiers:
		if f.team == s.team and f.state != "dead" and G.dist2d(f.pos, p) < 9.0:
			return
	s.aim_yaw = atan2(p.x - s.pos.x, p.z - s.pos.z)
	Combat.launch_rifle_grenade(s, s.head_pos() + Vector3(0, 0.1, 0), p + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)))
	s.rgren -= 1
	s.job_cd = 10.0
	G.fx.callout(s, G.pick(["Rifle grenade out!", "Lobbing one over!"]))

# anti-tank soldiers and engineers run up and slap sticky bombs on armour
static func _sticky(s) -> void:
	if s.stickies <= 0:
		return
	for v in G.vehicles:
		if v.team == s.team or v.dead or v.spec.get("air", false):
			continue
		var d = G.dist2d(v.pos, s.pos)
		if d < 11.0 and not G.blocked(s.head_pos(), v.center()):
			Combat.throw_grenade(s, v.center(), "sticky")
			return

# snipers move to a new spot after a few shots, before they get spotted
static func _sniper_move(s) -> void:
	if s.cls != "sniper" or s.shots_here < (1 if Faction.militia(s.team) else 3):
		return
	s.shots_here = 0
	var from: Vector3 = s.pos
	var best = null
	var bs = 1e9
	for cp in G.world.cover_near(from, 32.0):
		var d = G.dist2d(cp.p, from)
		if d < 12.0 or not AI.cover_free(cp, s) or cp.ban > G.sim_time:
			continue
		var sc = absf(d - 20.0) + randf() * 6.0
		if s.has_threat and AI.cover_safe(cp, s.threat):
			sc -= 5.0
		if sc < bs:
			bs = sc
			best = cp
	if best != null:
		AI.release_cover(s)
		AI.take_cover(s, best)
		G.fx.callout(s, G.pick(["Relocating.", "Moving to a new nest.", "Time to move."]))

static func _rocket_structure(s) -> bool:
	if s.wid != "rpg" or s.rockets <= 0 or s.vis_t != null or s.job_cd > 0.0:
		return false
	var es = Build.enemy_site_near(s.team, s.pos, 60.0)
	if es == null or G.dist2d(es[1], s.pos) < 12.0 or not Build.sees(s.head_pos(), es[0]):
		return false
	var aim = es[1] + Vector3(randf_range(-1.5, 1.5), randf_range(0.4, 1.4), randf_range(-1.5, 1.5))
	s.aim_yaw = atan2(aim.x - s.pos.x, aim.z - s.pos.z)
	Combat.launch_rocket(s, s.head_pos() + Vector3(0, 0.1, 0), (aim - s.head_pos()).normalized())
	s.rockets -= 1
	s.job_cd = 8.0
	G.fx.callout(s, G.pick(["Rocket on their position!", "Hitting the bunker!"]))
	return false

# riflemen lob grenades into enemy positions they've crept up on
static func grenade_structure(s) -> void:
	if s.grenades <= 0 or s.vis_t != null or s.job_cd > 0.0 or s.cls in ["medic", "sniper", "radio"]:
		return
	var es = Build.enemy_site_near(s.team, s.pos, 24.0)
	if es == null or G.dist2d(es[1], s.pos) < 7.0 or not Build.sees(s.head_pos(), es[0]):
		return
	Combat.throw_grenade(s, es[1], "frag")
	s.job_cd = 10.0

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
	if best == null:
		# nothing armoured about: knock holes in enemy positions instead
		return _rocket_structure(s)
	if bd < 25.0:
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

static func _mine_threat(team: int) -> bool:
	for m in Combat.mines:
		if m["team"] != team:
			return true
	return false

# walking slowly with a mine detector swept from side to side in front; anything it finds gets cleared
static func _sweep(s) -> void:
	var to = s.get_meta("sweep_to", s.pos)
	s.build_t += G.DT
	if s.vis_t != null or G.dist2d(to, s.pos) < 2.0 or s.build_t > 45.0:
		s.task = null
		s.decide_t = 0.0
		s.job_cd = 6.0
		return
	if s.move_target == null:
		AI.go_to(s, to, 1.5)
	s.ready_ = false
	s.crouch_t = 0.3
	var f = Vector3(sin(s.body_yaw), 0, cos(s.body_yaw))
	var r = Vector3(-f.z, 0, f.x)
	var sw = sin(G.sim_time * 2.4 + s.seed_) * 0.55
	var head = s.pos + f * 1.5 + r * sw
	head.y = G.world.surface_y(head.x, head.z, s.pos.y + 0.5) + 0.08
	s.hand_t = s.pos + f * 0.45 + Vector3(0, 0.85, 0)
	s.detector_at(s.hand_t, head)
	for m in Combat.mines:
		if m["team"] == s.team:
			continue
		var dm = m["p"] - s.pos
		if G.flat(dm).length() < 6.0 and G.flat(dm).normalized().dot(f) > 0.3:
			AI.stop_move(s)
			s.task = "defuse"
			s.board_target = m
			s.build_t = 0.0
			AI.go_to(s, m["p"], 1.5)
			G.fx.callout(s, G.pick(["Mine! Everybody stop!", "Got one. Hold here while I clear it.", "Contact mine, ahead. Clearing it."]))
			return

# ---------------------------------------------------------------- building, by hand
# Workers take turns at three jobs: hammering at the frame, digging with a shovel, and carrying
# sandbags or planks over from the pile of materials beside the site. Earthworks (sandbags, nests, pits,
# bunkers) are mostly digging and sandbags; huts and bases are mostly carpentry and planks.
const EARTH = ["sandbags", "mgnest", "mortarpit", "bunker", "traps", "wire", "aa"]

static func _build_work(s, st) -> void:
	var rate = 1.0 if s.cls == "engineer" else 0.55
	var job: Dictionary = s.get_meta("bjob", {})
	if job.get("st") != st:
		job = {"st": st, "m": "", "t": 0.0, "stage": 0}
	if job["m"] == "":
		var r = randf()
		var earth = st["kind"] in EARTH
		job["m"] = ("dig" if r < 0.45 else ("carry" if r < 0.8 else "hammer")) if earth else ("hammer" if r < 0.5 else ("carry" if r < 0.85 else "dig"))
		job["t"] = randf_range(5.0, 8.0)
		job["stage"] = 0
	s.set_meta("bjob", job)
	var near_site = G.dist2d(s.pos, st["p"]) < Build.build_radius(st) + 0.7
	var to = G.flat(st["p"] - s.pos)
	match job["m"]:
		"carry":
			var pile = _pile(st)
			if job["stage"] == 0:
				# over to the pile
				if G.dist2d(pile, s.pos) < 1.2:
					AI.stop_move(s)
					s.crouch_t = 0.9
					s.hand_t = pile + Vector3(0, 0.3, 0)
					job["t2"] = job.get("t2", 0.0) + G.DT
					if job["t2"] > 0.7:
						job["stage"] = 1
						job["t2"] = 0.0
						AI.go_to(s, Build.work_spot(st, s), 2.6)
				elif s.move_target == null or G.dist2d(s.move_target, pile) > 1.0:
					AI.go_to(s, pile, 3.6)
			elif job["stage"] == 1:
				# walking back with it held in both arms
				var f = Vector3(sin(s.body_yaw), 0, cos(s.body_yaw))
				var r = Vector3(-f.z, 0, f.x)
				var mid = s.pos + f * 0.38 + Vector3(0, 0.95, 0)
				s.hand_t = mid
				s.hands_t = [mid + r * 0.2, mid - r * 0.2]
				s.ready_ = false
				s.carry_item(true, "bag" if st["kind"] in EARTH else "plank", mid)
				if near_site:
					AI.stop_move(s)
					s.crouch_t = 0.8
					job["t2"] = job.get("t2", 0.0) + G.DT
					if job["t2"] > 0.5:
						s.carry_item(false, "", mid)
						Build.add_work(st, rate * 2.2)
						job["m"] = ""
						job["t2"] = 0.0
				elif s.move_target == null:
					AI.go_to(s, Build.work_spot(st, s), 2.6)
			return
		"dig":
			if not near_site:
				if s.move_target == null:
					AI.go_to(s, Build.work_spot(st, s), 4.6)
				return
			AI.stop_move(s)
			s.want = Vector3.ZERO
			s.crouch_t = 0.35
			s.ready_ = false
			s.aim_yaw = G.turn_to(s.aim_yaw, atan2(to.x, to.z), 4.0 * G.DT)
			var f2 = to.normalized()
			var ph = sin(G.sim_time * 2.6 + s.seed_)
			var dig = maxf(0.0, ph)
			# push the blade in low and forward, then lever the spoil up and over
			var grip = s.pos + f2 * (0.35 + 0.15 * dig) + Vector3(0, 0.95 - 0.3 * dig, 0)
			var blade = s.pos + f2 * (1.15 + 0.1 * dig) + Vector3(0, 0.05 + 0.45 * maxf(0.0, -ph), 0)
			var sh = (blade - grip).normalized()
			s.hand_t = grip
			s.hands_t = [grip + sh * 0.42, grip]
			s.tool_at("shovel", grip - sh * 0.15, blade)
			if ph > 0.97 and randf() < 0.3:
				G.fx.dust_cloud(blade, 0.4)
			Build.add_work(st, rate * G.DT)
		_:
			if not near_site:
				if s.move_target == null:
					AI.go_to(s, Build.work_spot(st, s), 4.6)
				return
			AI.stop_move(s)
			s.want = Vector3.ZERO
			s.crouch_t = 0.75
			s.aim_yaw = G.turn_to(s.aim_yaw, atan2(to.x, to.z), 4.0 * G.DT)
			s.hand_t = s.pos + to.normalized() * 0.55 + Vector3(0, 0.45, 0)
			s.tool_mode = "hammer"
			Build.add_work(st, rate * G.DT)
	job["t"] -= G.DT
	if job["t"] <= 0.0:
		job["m"] = ""

# the stack of materials dumped beside a site: sandbags for earthworks, timber for anything with walls
static func _pile(st) -> Vector3:
	if st.has("pile"):
		return st["pile"]
	var f = Build._front(st)
	var p = G.main._free_spot(st["p"] - f * (Build.build_radius(st) + 1.6) + Vector3(f.z, 0, -f.x) * 2.0)
	p.y = G.world.ground_y(p.x, p.z)
	st["pile"] = p
	var n = Node3D.new()
	st["root"].add_child(n)
	if st["kind"] in EARTH:
		for k in range(6):
			VModel.box(null, n, Vector3(0.55, 0.22, 0.32), Vector3((k % 3) * 0.5 - 0.5, 0.11 + int(k / 3) * 0.22, randf_range(-0.05, 0.05)), Color(0.55, 0.5, 0.36), {"b": 0.08, "rot": Vector3(0, randf_range(-0.2, 0.2), 0)})
	else:
		for k in range(5):
			VModel.box(null, n, Vector3(2.2, 0.08, 0.22), Vector3(0, 0.04 + k * 0.08, (k % 2) * 0.05), Color(0.55, 0.42, 0.27), {"b": 0.01})
	n.global_position = p
	n.rotation.y = atan2(f.x, f.z)
	st["pile_node"] = n
	return p
