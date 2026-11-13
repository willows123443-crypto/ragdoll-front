class_name Support
extends RefCounted
# Supply points and call-ins. Sides earn points over time, for kills and for taking objectives,
# and spend them on vehicles, air strikes, artillery, gunships and airborne troops.
# The player spends Alpha's points from the Support tab; AI commanders spend for their own side.

const COSTS = {
	"artillery": 14, "airstrike": 20, "paradrop": 16, "heli": 20,
	"jeep": 9, "motorbike": 7, "halftrack": 16, "armoredcar": 24, "tank": 36, "heavytank": 55, "gunship": 40,
	"fighter": 26, "bomber": 34, "bridger": 16, "radar": 20, "ambulance": 9, "atgun": 14, "recon": 10, "technical": 8, "plough": 30, "oldtank": 30, "gunbus": 18, "techaa": 11,
	"supplytruck": 12, "ammotruck": 10,
}
const NAMES = {
	"artillery": "Artillery barrage", "airstrike": "Air strike", "paradrop": "Paratroopers", "heli": "Helicopter insertion",
	"jeep": "Jeep", "motorbike": "Motorbike", "halftrack": "Half-track", "armoredcar": "Armoured car", "tank": "Tank", "gunship": "Gunship (70 s)",
	"fighter": "Fighter (90 s)", "bomber": "Dive bomber (90 s)", "bridger": "Bridge layer", "radar": "Command truck", "ambulance": "Ambulance", "atgun": "Anti-tank gun", "heavytank": "Heavy tank", "recon": "Recon plane (30 s)", "technical": "Technical", "plough": "Mine plough tank", "oldtank": "Old tank", "gunbus": "Gun truck", "techaa": "Twin-gun technical",
	"supplytruck": "Supply truck", "ammotruck": "Ammo truck",
}

# in commander mode, what has to be built before you can call each one in
const NEEDS = {"plough": "depot", "technical": "depot", "oldtank": "depot", "gunbus": "depot", "techaa": "depot", "heavytank": "depot", "jeep": "depot", "motorbike": "depot", "halftrack": "depot", "armoredcar": "depot", "tank": "depot", "ambulance": "hospital",
	"radar": "depot", "bridger": "depot", "atgun": "depot", "gunship": "radio", "fighter": "radio", "bomber": "radio", "airstrike": "radio",
	"paradrop": "radio", "heli": "radio", "recon": "radio"}
const NEED_NAMES = {"depot": "a vehicle depot", "radio": "a radio mast", "hospital": "a field hospital"}

static func unlocked(team: int, what: String) -> bool:
	if G.mode != "commander" or not NEEDS.has(what):
		return true
	for st in Build.sites:
		if st["team"] == team and st["kind"] == NEEDS[what] and Build.alive(st):
			return true
	return false

static func need_text(what: String) -> String:
	var st = pending_site(0, what)
	if st != null:
		return "%s %d%% built" % [st["name"].to_lower(), int(100.0 * st["work"] / maxf(1.0, st["need"]))]
	return "needs " + NEED_NAMES.get(NEEDS.get(what, ""), "a building")

# a building that would unlock this, marked out but not finished yet
static func pending_site(team: int, what: String):
	if not NEEDS.has(what):
		return null
	for st in Build.sites:
		if st["team"] == team and st["kind"] == NEEDS[what] and not st["dead"] and not st["done"]:
			return st
	return null

static var points: Array = []
static var earned: Array = [0, 0, 0, 0]     # supply taken in over the battle (not counting spending)
static var last_pts: Array = [0, 0, 0, 0]
static var hq_t: Array = [0, 0, 0, 0]
static var trickle = 0.0
static var ai_t: Array = []
static var planes: Array = []
static var air_seen: Array = [-999.0, -999.0, -999.0, -999.0]

static func reset() -> void:
	arty_next = [0.0, 0.0, 0.0, 0.0]
	air_seen = [-999.0, -999.0, -999.0, -999.0]
	earned = [0, 0, 0, 0]
	last_pts = [-1, -1, -1, -1]
	for r in recons:
		if is_instance_valid(r["node"]):
			r["node"].queue_free()
	recons = []
	points = []
	hq_t = [0, 0, 0, 0]
	ai_t = []
	for t in range(G.team_count()):
		points.append(10)
		ai_t.append(randf_range(20.0, 40.0))
	trickle = 0.0
	missions = []
	for p in planes:
		if is_instance_valid(p["node"]):
			p["node"].queue_free()
	planes = []

# ---------------------------------------------------------------- fire missions
# The guns don't hit first time: a ranging round lands off target, the observer sends a correction,
# a second round lands closer, and then the battery fires for effect.
static var missions: Array = []

# one battery a side: after a fire mission the guns aren't to be had again for a while, whoever asks
# (the radio operators and the AI commander used to call them down independently, one after another)
static var arty_next = [0.0, 0.0, 0.0, 0.0]
const ARTY_GAP = 95.0

static func arty_ready(team: int) -> bool:
	return team < 0 or team >= arty_next.size() or G.sim_time >= arty_next[team]

static func fire_mission(team: int, target: Vector3, caller, shells: int, spread: float, power: float) -> void:
	if team >= 0 and team < arty_next.size():
		arty_next[team] = G.sim_time + ARTY_GAP * randf_range(0.9, 1.3) * float(Commander.handicap(team)["arty"])
	var a = randf() * TAU
	var err = Vector3(cos(a), 0, sin(a)) * randf_range(28.0, 45.0)
	var op = Build.observer_for(team, target)
	if op != null:
		spread *= 0.5
		err *= 0.35
		G.ui.radio(team, "Observer post has eyes on the target: corrections will be quick")
	missions.append({"team": team, "target": target, "caller": caller, "shells": shells, "spread": spread, "power": power,
		"stage": 0, "t": 1.5, "err": err, "from": caller.pos if caller != null and is_instance_valid(caller) else G.world.spawn[team]})
	G.ui.radio(team, "Fire mission, grid %s. Ranging round on the way" % AI.grid_ref(target))

static func _step_missions(dt: float) -> void:
	for i in range(missions.size() - 1, -1, -1):
		var m = missions[i]
		m["t"] -= dt
		if m["t"] > 0.0:
			continue
		var c = m["caller"]
		var has_eyes = c != null and is_instance_valid(c) and c.state == "alive"
		# the observer keeps the target up to date while he can see what's there
		if has_eyes and c.vis_t != null and is_instance_valid(c.vis_t) and G.dist2d(c.vis_t.pos, m["target"]) < 30.0:
			m["target"] = c.vis_t.pos
		var tgt: Vector3 = m["target"]
		match m["stage"]:
			0:
				# ranging round
				var p = tgt + m["err"]
				Combat.shell_at(p, 1.5, 3.5, c if has_eyes else null, m["power"], m["team"])
				var los = G.flat(tgt - m["from"]).normalized()
				if los.length_squared() < 0.5:
					los = Vector3(1, 0, 0)
				var miss = p - tgt
				var rng = -miss.dot(los)
				var lat = Vector3(los.z, 0, -los.x).dot(miss)
				m["corr"] = "%s %d, %s %d" % ["add" if rng > 0.0 else "drop", absi(roundi(rng / 5.0) * 5), "left" if lat > 0.0 else "right", absi(roundi(lat / 5.0) * 5)]
				m["stage"] = 1
				m["t"] = 6.5
			1:
				# the observer calls the correction
				if has_eyes:
					G.fx.callout(c, G.pick(["Adjust fire, %s!" % m["corr"], "Correction: %s, over!" % m["corr"]]))
				G.ui.radio(m["team"], "Adjust fire: %s. Next round on the way" % m["corr"])
				m["err"] = m["err"] * (0.3 if has_eyes else 0.55) + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
				m["stage"] = 2
				m["t"] = 2.5
			2:
				Combat.shell_at(tgt + m["err"], 1.5, 3.5, c if has_eyes else null, m["power"], m["team"])
				m["err"] = m["err"] * 0.15
				m["stage"] = 3
				m["t"] = 6.5
			3:
				if has_eyes:
					G.fx.callout(c, G.pick(["On target! Fire for effect!", "Good hit, fire for effect!"]))
				G.ui.radio(m["team"], "Fire for effect on %s!" % AI.grid_ref(tgt))
				for k in range(m["shells"]):
					Combat.shell_at(tgt + m["err"], m["spread"], 3.0 + k * randf_range(0.4, 0.9), c if has_eyes else null, m["power"], m["team"])
				missions.remove_at(i)

static func earn(team: int, n: int) -> void:
	if team >= 0 and team < points.size():
		points[team] += n

static func step(dt: float) -> void:
	# income: every rise in a side's points (spending only ever lowers them)
	for t in range(mini(points.size(), 4)):
		if last_pts[t] >= 0 and points[t] > last_pts[t]:
			earned[t] += points[t] - last_pts[t]
		last_pts[t] = points[t]
	_step_planes(dt)
	_step_recons(dt)
	_step_missions(dt)
	if G.over or points.is_empty():
		return
	trickle += dt
	if trickle >= 6.0:
		trickle = 0.0
		for t in range(points.size()):
			if G.mode == "commander":
				# the HQ alone brings in a trickle; supply dumps are where the real income is
				# the HQ brings in a trickle; supply dumps only pay when a convoy gets through (see Prod)
				# (two points every 18 s: a bit more than it was, so a side that's lost its dumps isn't stuck)
				hq_t[t] = hq_t[t] + 1
				if hq_t[t] % 3 != 0 and Build.hq(t) != null and Build.alive(Build.hq(t)):
					_pay(t, 1)
			else:
				_pay(t, 1)
	# AI sides spend what they have (once the battle's actually under way)
	if G.builder or Prep.active() or G.sim_time < 20.0 or G.tutorial:
		return
	for t in range(points.size()):
		if t == 0 and (not G.ai_runs(0) or G.mode == "horde"):
			continue        # the player's own purse
		if t == 1 and G.mode == "horde":
			continue
		ai_t[t] -= dt
		if ai_t[t] > 0.0:
			continue
		ai_t[t] = (randf_range(14.0, 24.0) if G.mode == "commander" else randf_range(25.0, 45.0)) * float(Commander.handicap(t)["spend"])
		if G.mode == "commander" and G.sim_time < float(Commander.handicap(t)["grace"]):
			continue
		_ai_spend(t)

# supply coming in: worth more or less to a hard or an easy enemy (the odd fractions are carried over)
static var pay_frac = [0.0, 0.0, 0.0, 0.0]
static func _pay(t: int, n: int) -> void:
	var k: float = Commander.handicap(t)["income"]
	if t >= pay_frac.size() or is_equal_approx(k, 1.0):
		points[t] += n
		return
	pay_frac[t] += n * k
	var whole = int(floor(pay_frac[t]))
	pay_frac[t] -= whole
	points[t] += whole

static func _ai_spend(t: int) -> void:
	# commander mode: the AI buys its troops just like the player does, so its army grows over the battle
	if G.mode == "commander":
		if G.vehicles.any(func(v): return v.team != t and not v.dead and v.spec.get("air", false)):
			air_seen[t] = G.sim_time
		if G.sim_time - air_seen[t] < 240.0 and _ai_aa(t):
			return
		# a few fighting vehicles as the battle goes on, built at its depot (more the longer it lasts)
		if _ai_vehicle(t):
			return
		if _ai_recruit(t):
			return
	# an AI commander puts spare points into upgrades now and then
	if Prod.active() and points[t] >= 40 and randf() < 0.35:
		for up in Prod.UPGRADES.keys():
			if Prod.can_research(t, up) and Prod.start_research(t, up):
				return
	var opts = []
	var tgt = ClassAI.artillery_target(t, G.world.spawn[t], 30.0) if arty_ready(t) else null
	if tgt != null:
		opts.append("artillery")
		opts.append("airstrike")
	elif AI.team_intel_center(t) == null and G.sim_time > 120.0 and not G.attract and not Prep.active() and not (G.get("builder") == true):
		# (not in the opening minutes, before anyone's had a chance to meet, nor before the battle's begun)
		opts.append("recon")      # no idea where they are: send a plane to look
	var veh = 0
	for v in G.vehicles:
		if v.team == t and not v.dead and not v.spec.get("static", false):
			veh += 1
	if G.mode == "commander" and not G.vehicles.any(func(v): return v.team == t and not v.dead and v.kind == "ammotruck"):
		opts.append("ammotruck")
	if veh < 3 and G.armor != "none":
		opts.append_array(["jeep", "halftrack", "armoredcar", "motorbike"])
		if G.armor == "heavy":
			opts.append_array(["tank", "gunship", "heavytank"])
	if G.alive_count(t) < G.team_size * 0.6:
		opts.append_array(["paradrop", "heli"])
	# answer enemy aircraft with fighters; dive bombers against armour and bases
	var enemy_air = false
	var enemy_armour = false
	for v in G.vehicles:
		if v.team != t and not v.dead:
			if v.spec.get("air", false):
				enemy_air = true
			elif v.spec["tracked"] or v.kind == "armoredcar":
				enemy_armour = true
	if enemy_air and G.armor != "none":
		opts.append_array(["fighter", "fighter"])

	if (enemy_armour or G.mode == "destroy") and G.armor == "heavy":
		opts.append("bomber")
	if enemy_armour:
		var guns = 0
		for v in G.vehicles:
			if v.team == t and not v.dead and v.kind == "atgun":
				guns += 1
		if guns < 2:
			opts.append_array(["atgun", "atgun"])
	# the enemy mines the roads: get a mine plough out in front
	if G.armor != "none" and ClassAI._mine_threat(t) and not G.vehicles.any(func(v): return v.team == t and not v.dead and v.has_meta("plough")):
		opts.append("plough")
	var broken_bridge = false
	for b in G.world.bridges:
		if not b[5].alive:
			broken_bridge = true
	if broken_bridge and G.armor != "none":
		opts.append("bridger")
	if Faction.militia(t):
		opts = opts.map(func(o): return Faction.vehicle_kind(t, o) if o in ["jeep", "halftrack", "armoredcar", "tank", "heavytank"] else o)
	opts = opts.filter(func(o): return COSTS[o] <= points[t] and unlocked(t, o) and Faction.support_ok(t, o) and Rules.callin_ok(t, o))
	if opts.is_empty():
		return
	var pick = G.pick(opts)
	call_in(t, pick, tgt if tgt != null else G.world.capture)

static func can_afford(team: int, what: String) -> bool:
	return points[team] >= COSTS[what]

static func call_in(team: int, what: String, target: Vector3, relay: bool = false) -> bool:
	# commander mode: shells can't hurt an HQ (it's dug in too deep). The AI knows it and puts the
	# barrage on the men defending it instead; you get told
	if G.mode == "commander" and what == "artillery":
		var ehq = Build.hq((team + 1) % 2)
		if ehq != null and Build.alive(ehq) and G.dist2d(target, ehq["p"]) < 24.0:
			if G.ai_runs(team):
				var alt = null
				var bd = 1e9
				for s in G.soldiers:
					if s.team != team and s.state == "alive" and s.vehicle == null:
						var dh = G.dist2d(s.pos, ehq["p"])
						var dt2 = G.dist2d(s.pos, target)
						if dh > 14.0 and dt2 < 70.0 and dt2 < bd:
							bd = dt2
							alt = s.pos
				if alt == null:
					return false
				target = alt
			elif team == 0:
				G.ui.message("Shells can't hurt their HQ: it's dug in too deep. Take it on the ground: satchels, rockets, tank and rifle fire")
	if Prep.active() and (what in Rules.FIRE or what in Rules.TROOPS or what in Rules.AIR):
		if team == 0:
			G.ui.message("Not until the battle starts (Space ends the prep)")
		return false
	if G.storm and what in Rules.FLYING:
		if team == 0:
			G.ui.message("Storm: nothing can fly today")
		return false
	if points.is_empty() or points[team] < COSTS[what] or not unlocked(team, what) or not Faction.support_ok(team, what) or not Rules.callin_ok(team, what):
		return false
	if what == "supplytruck":
		if not Logistics.can_buy_truck(team):
			if team == 0:
				G.ui.message(("Build a supply dump or a FOB first: the trucks need somewhere to go" if not Logistics.has_stop(0) else "You already have %d supply trucks (the most you can run)" % Logistics.FLEET_MAX) if Prod.active() else "Supply trucks are for commander battles")
			return false
		points[team] -= COSTS[what]
		return Logistics.buy_truck(team)
	# no radio: the request goes back to HQ with a runner, and is paid for when it gets there
	if not relay and not (Prod.active() and Prod.is_vehicle(what)) and Comms.hold(team, what, target):
		return true
	points[team] -= COSTS[what]
	if what == "ammotruck":
		var dest: Vector3 = G.world.rally_point(team)
		Reinforce.drive_in(team, "ammotruck", dest, true, false)
		G.ui.radio(team, "Ammo truck on its way%s" % (": park it near the front and the men will come to it" if team == 0 else ""))
		return true
	# commander mode: vehicles are built at the depot, one after another
	if Prod.active() and Prod.is_vehicle(what):
		Prod.order(team, what)
		return true
	match what:
		"artillery":
			if Prod.has(team, "artillery"):
				fire_mission(team, target, null, 12, 13.0, 2.0)
			else:
				fire_mission(team, target, null, 8, 12.0, 1.6)
		"airstrike":
			if team >= 0 and team < arty_next.size():
				arty_next[team] = maxf(arty_next[team], G.sim_time + ARTY_GAP * 0.7)
			_air_strike(team, target)
			G.ui.radio(team, "Air strike inbound on %s" % AI.grid_ref(target))
		"recon":
			_recon(team)
		"paradrop":
			Reinforce.paradrop(team, 6)
		"heli":
			Reinforce.heli(team, 6)
		"fighter", "bomber":
			var ep = Reinforce.entry_point(team)
			var pv = G.main.spawn_vehicle(what, team, ep, atan2(G.world.capture.x - ep.x, G.world.capture.z - ep.z))
			pv.life_t = 90.0
			G.ui.radio(team, "%s on station for ninety seconds" % NAMES[what].split(" (")[0])
		"gunship":
			var e = Reinforce.entry_point(team)
			var v = G.main.spawn_vehicle("gunship", team, e, atan2(G.world.capture.x - e.x, G.world.capture.z - e.z))
			v.life_t = 70.0
			G.ui.radio(team, "Gunship on station for seventy seconds")
		_:
			deliver(team, what)
	return true

# a ground vehicle arrives: anti-tank guns are towed up and unhitched at the rally point, the rest drive in from the rear
static func deliver(team: int, what: String) -> void:
	if what == "atgun":
		var r0: Vector3 = G.world.rally_point(team)
		var fw = G.flat(G.world.capture - r0).normalized()
		G.main.spawn_vehicle("atgun", team, G.main._free_spot(r0 + fw * 12.0), atan2(fw.x, fw.z))
		G.ui.radio(team, "Anti-tank gun set up at the rally point")
		return
	var r: Vector3 = G.world.rally_point(team)
	Reinforce.drive_in(team, what, r, true, false)
	G.ui.radio(team, "%s inbound from the rear" % NAMES[what])

# a spotter plane circles over the enemy's side for thirty seconds: everything it sees goes on our map,
# unless their anti-aircraft guns bring it down first
static var recons: Array = []

static func _recon(team: int) -> void:
	var enemy: Vector3 = G.world.spawn[(team + 1) % G.team_count()]
	var c = G.world.capture.lerp(enemy, 0.45)
	var node = Reinforce._plane_mesh(team)
	node.scale = Vector3(0.6, 0.6, 0.6)
	node.global_position = c + Vector3(0, 90, 0)
	recons.append({"node": node, "team": team, "c": c, "t": 0.0, "tick": 0.0})
	G.ui.radio(team, "Recon plane on station for thirty seconds")

static func _step_recons(dt: float) -> void:
	for i in range(recons.size() - 1, -1, -1):
		var r = recons[i]
		r["t"] += dt
		var a = r["t"] * 0.35
		var at: Vector3 = r["c"] + Vector3(cos(a) * 85.0, 90.0, sin(a) * 85.0)
		var nxt: Vector3 = r["c"] + Vector3(cos(a + 0.1) * 85.0, 90.0, sin(a + 0.1) * 85.0)
		r["node"].global_position = at
		r["node"].look_at(nxt, Vector3.UP)
		if randf() < 0.05:
			G.audio.engine(at, 0.6, false)
		var down = VehExt.aa_vs_plane(at, r["team"], dt * 2.5)
		if down or r["t"] > 30.0:
			if down:
				G.fx.explosion(at, 1.2)
				G.audio.boom(at)
				G.ui.radio(r["team"], "Recon plane shot down!")
			else:
				G.ui.radio(r["team"], "Recon plane heading home")
			r["node"].queue_free()
			recons.remove_at(i)
			continue
		r["tick"] -= dt
		if r["tick"] <= 0.0:
			r["tick"] = 1.0
			# the observer's reports: every enemy in the open goes to the whole side
			for e in G.soldiers:
				if e.team == r["team"] or e.state == "dead" or e.hidden_in_vehicle:
					continue
				for f in G.soldiers:
					if f.team == r["team"] and f.state != "dead":
						AI.add_intel(f, e, e.pos, 2.0, false)

# a ground-attack plane runs in over the target and drops a stick of bombs
static func _air_strike(team: int, target: Vector3) -> void:
	var dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	var start = target - dir * 420.0 + Vector3(0, 60.0, 0)
	var end_ = target + dir * 420.0 + Vector3(0, 60.0, 0)
	var node = Reinforce._plane_mesh(team)
	node.global_position = start
	node.look_at(end_, Vector3.UP)
	planes.append({"node": node, "from": start, "to": end_, "t": 0.0, "target": target, "dir": dir, "dropped": false, "team": team})

static func _step_planes(dt: float) -> void:
	for i in range(planes.size() - 1, -1, -1):
		var p = planes[i]
		p["t"] += dt * 95.0 / p["from"].distance_to(p["to"])
		var at: Vector3 = p["from"].lerp(p["to"], p["t"])
		p["node"].global_position = at
		if randf() < 0.15:
			G.audio.engine(at, 1.0, true)
		# enemy AA can bring the strike plane down before it drops
		if not p["dropped"] and VehExt.aa_vs_plane(at, p.get("team", -1), dt):
			G.fx.explosion(at, 2.0)
			G.audio.boom(at)
			G.ui.radio(p.get("team", 0), "Strike aircraft shot down!")
			p["node"].queue_free()
			planes.remove_at(i)
			continue
		if not p["dropped"] and p["t"] > 0.42:
			p["dropped"] = true
			for k in range(5):
				var hit = p["target"] + p["dir"] * (k - 2) * 9.0
				Combat.shell_at(hit, 2.0, 1.2 + k * 0.15, null, 1.9)
		if p["t"] >= 1.0:
			p["node"].queue_free()
			planes.remove_at(i)

# what the AI commander buys: riflemen first, engineers if it has none, AT men against armour,
# more when it's losing men; capped so it can't flood the map
const AI_VEH = ["jeep", "halftrack", "armoredcar", "tank", "heavytank", "technical", "motorbike"]      # (by kind: the militia's own are these underneath)

static func _ai_vehicle(t: int) -> bool:
	if G.armor == "none" and not Prod.active():
		return false
	var have = 0
	for v in G.vehicles:
		if v.team == t and not v.dead and v.kind in AI_VEH:
			have += 1
	var queued = Prod.queue_size(t) if Prod.active() else 0
	var want = 1 + int(G.game_time / 180.0)
	if have + queued >= mini(want, 5) or randf() < 0.35:
		return false
	var enemy_armour = G.vehicles.any(func(v): return v.team != t and not v.dead and (v.spec["tracked"] or v.kind == "armoredcar"))
	var picks = ["tank", "armoredcar", "halftrack"] if enemy_armour else ["halftrack", "armoredcar", "jeep", "tank"]
	if Faction.militia(t):
		picks = ["oldtank", "gunbus", "techaa"] if enemy_armour else ["techaa", "gunbus", "technical", "oldtank"]
	for k in picks:
		if COSTS.has(k) and COSTS[k] <= points[t] and unlocked(t, k) and Faction.support_ok(t, k) and Rules.callin_ok(t, k):
			if call_in(t, k, G.world.capture):
				return true
	return false

static func _ai_recruit(t: int) -> bool:
	var R = G.ui.RECRUIT
	var mine = G.soldiers.filter(func(x): return x.team == t and x.state != "dead")
	if mine.size() >= int(G.team_size * 2.5) + 6:
		return false
	var engs = mine.filter(func(x): return x.cls == "engineer").size()
	var enemy_armour = G.vehicles.any(func(v): return v.team != t and not v.dead and (v.spec["tracked"] or v.kind == "armoredcar"))
	var k = "inf"
	var pending = Build.sites.any(func(st): return st["team"] == t and not st["done"] and not st["dead"])
	if engs == 0 or (engs < 2 and pending):
		k = "eng"
	elif enemy_armour and randf() < 0.4:
		k = "atk"
	elif randf() < 0.25:
		k = G.pick(["asl", "snp", "med", "mgt", "rad"])
	elif points[t] >= G.ui.recruit_cost(t, "plt") + 10 and randf() < 0.3:
		k = "plt"
	# short-handed: spend on men before anything else; otherwise only now and then
	var short = mine.size() < G.team_size
	if not short and randf() < 0.45:
		return false
	if points[t] < G.ui.recruit_cost(t, k):
		return false
	points[t] -= G.ui.recruit_cost(t, k)
	Reinforce.truck_cls(t, R[k]["cls"])
	return true

static func _ai_aa(t: int) -> bool:
	var hq = Build.hq(t)
	if hq == null:
		return false
	var n = 0
	for st in Build.sites:
		if st["team"] == t and st["kind"] == "aa" and not st["dead"]:
			n += 1
			if not st["done"]:
				return false      # one at a time
	if n >= 2 or points[t] < Build.cost("aa"):
		return false
	var f = Build._front(hq)
	var side = Vector3(f.z, 0, -f.x) * (1.0 if n == 0 else -1.0)
	var spot = G.main._free_spot(hq["p"] + side * 16.0 - f * 6.0)
	if Build.site_at(spot, 3.0) != null:
		return false
	points[t] -= Build.cost("aa")
	Build.place("aa", t, spot, f)
	G.ui.radio(t, "Anti-aircraft gun going up by the HQ")
	return true
