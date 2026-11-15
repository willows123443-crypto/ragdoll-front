class_name Modes
extends RefCounted
# The newer game modes:
#   escort     Alpha drives a convoy of trucks across the map; Bravo tries to stop it
#   rescue     a pilot is down behind the lines; Alpha must reach him and bring him home, Bravo hunts him
#   koth       one hill to hold, and it moves somewhere else every 90 seconds
#   commander  a capture battle you fight from above: select squads and send them where you want
#   horde      Alpha holds out against waves of the walking dead
#   general    each side's general hides somewhere on its half with bodyguards; kill theirs first
# and the daily challenge: a battle picked from today's date, the same for everyone.

static var convoy: Array = []
static var convoy_goal = Vector3.ZERO
static var convoy_need = 2
static var arrived = 0
static var pilot = null
static var rescued = false
static var rescue_t = 0.0
static var rescue_squad = null
static var crash_p = Vector3.ZERO
static var pilot_known_t = -1.0      # Bravo knows exactly where he is until then
static var koth_t = 0.0
static var koth_moves = 0
static var horde_wave = 0
static var horde_left = 0
static var horde_t = 0.0
static var horde_spawn_t = 0.0
static var check_t = 0.0
static var daily: Dictionary = {}       # today's challenge while one is being played
static var generals: Array = []
static var gen_known: Array = []         # what each side knows of the enemy general: {"p", "t"} or null
static var gen_move_t: Array = []
static var gen_search: Array = []        # places each side means to search, in the enemy half

const RESCUE_TIME = 720.0
const KOTH_EVERY = 90.0
const HORDE_WIN = 10
static var horde_endless = false     # the ten waves are beaten and the player chose to keep going
static var horde_in = false          # (the Ministry: the survivors have been sent inside)
static var stall_t = 0.0             # how long the last few of a wave have been unable to get at anyone
static var stragglers = 0            # ...and how many have dropped for it

static func reset() -> void:
	clear_spits()
	convoy = []
	arrived = 0
	pilot = null
	rescued = false
	rescue_squad = null
	pilot_known_t = -1.0
	rescue_t = RESCUE_TIME
	koth_t = KOTH_EVERY
	koth_moves = 0
	horde_wave = 0
	horde_endless = false
	horde_in = false
	horde_left = 0
	horde_t = 10.0
	horde_spawn_t = 0.0
	horde_side = -1
	smashed = 0
	smash_said = -1
	forts = []
	forts_made = false
	jobs = []
	job_ends = {}
	fort_t = 0.0
	boarded_n = 0
	doors_n = 0
	torn_n = 0
	up_t = 0.0
	ups = 0
	boss = null
	boss_due = 0
	board_spent = 0
	side_known = false
	quiet_t = 0.0
	last_kills = 0
	buy_t = 0.0
	bought = {}
	downs = 0
	for r in rocks:
		if is_instance_valid(r["node"]):
			r["node"].queue_free()
	rocks = []
	clear_drops()
	keep_b = -1
	check_t = 0.0
	generals = []
	gen_known = [null, null]
	gen_move_t = [0.0, 0.0]
	gen_search = [[], []]

# ---------------------------------------------------------------- setup
static func setup() -> void:
	match G.mode:
		"escort":
			_setup_escort()
		"rescue":
			_setup_rescue()
		"general":
			_setup_general()
		"commander":
			G.pc.set_rts(true)
			Support.points[0] = 30
			if not G.tutorial:
				G.ui.message("You command Alpha. Destroy the enemy HQ to win. Buy squads, vehicles and fire support with supply points, and mark out buildings for your engineers. Click or drag to select, right-click to send. WASD pans, wheel zooms, Q/E turn")
		"horde":
			G.ui.message("Hold out! Wave after wave of the dead are coming. Survive %d waves" % HORDE_WIN)

static func _setup_escort() -> void:
	var W = G.world
	convoy_goal = _clear_spot(W.capture.lerp(W.spawn[1], 0.38), 5.0)
	# line up just in front of the base, clear of its tents and sandbags
	var start: Vector3 = _clear_spot(W.spawn[0].lerp(convoy_goal, 0.22), 6.0)
	var dir = G.flat(convoy_goal - start).normalized()
	var yaw = atan2(dir.x, dir.z)
	var side = Vector3(dir.z, 0, -dir.x)
	var kinds = ["armoredcar", "truck", "truck", "truck"]
	for i in range(kinds.size()):
		var p = _clear_spot(start - dir * (i * 11.0) + side * (2.0 if i % 2 == 0 else -2.0), 4.0)
		var v = G.main.spawn_vehicle(kinds[i], 0, p, yaw)
		if kinds[i] == "truck":
			# a co-driver rides along to take over if the driver is hit
			var cd = G.main.spawn_soldier(0, p.x, p.z, "")
			if cd != null:
				cd.mount(v, v.free_seat("pass"))
			v.mission = {"type": "escort", "drop": convoy_goal, "exit": convoy_goal, "stage": 0, "wait": 0.0, "delay": 4.0 + i * 3.0}
			v.hp *= 2.0
			convoy.append(v)
		else:
			v.mission = {"type": "escort", "drop": convoy_goal, "exit": convoy_goal, "stage": 0, "wait": 0.0, "delay": 2.0, "lead": true}
	convoy_need = 2
	G.ui.radio(0, "Convoy rolling. Get at least %d trucks to the marker" % convoy_need)
	G.ui.radio(1, "Enemy convoy on the road. Stop it!")

static func _clear_spot(p: Vector3, r: float) -> Vector3:
	var W = G.world
	var b: Rect2 = W.bounds
	for k in range(40):
		var q = p + (Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * (2.0 + k * 1.5) if k > 0 else Vector3.ZERO)
		q.x = clampf(q.x, b.position.x + 10.0, b.end.x - 10.0)
		q.z = clampf(q.z, b.position.y + 10.0, b.end.y - 10.0)
		if not W.inside_any(q.x, q.z, r) and not W.in_water(q.x, q.z):
			var clear = true
			for st in Build.sites:
				if G.dist2d(st["p"], q) < r + 6.0:
					clear = false
					break
			if clear:
				return q
	return G.main._free_spot(p)

# a mission vehicle in the convoy: wait its turn, then drive to the goal and stay there
static func escort_target(v, m: Dictionary):
	if m["go_t"] < m.get("delay", 0.0):
		return null
	if m["stage"] >= 5:
		return null
	var dg = G.dist2d(v.pos, convoy_goal)
	var lead = _lead_truck()
	# the armoured car scouts ahead of the leading truck, then waits past the goal
	if m.get("lead", false):
		var beyond = convoy_goal + G.flat(convoy_goal - G.world.spawn[0]).normalized() * 18.0
		if G.dist2d(v.pos, beyond) < 8.0:
			m["stage"] = 5
			return null
		if lead != null:
			var ld = G.flat(convoy_goal - lead.pos)
			if ld.length() > 45.0:
				var scout = lead.pos + ld.normalized() * 40.0
				if G.dist2d(v.pos, scout) < 8.0:
					return null
				return scout
		return beyond
	# a detour round whatever blocked the road
	if m.get("detour_t", 0.0) > m["go_t"]:
		if G.dist2d(v.pos, m["detour"]) > 6.0:
			m["why"] = "detour"
			return m["detour"]
		m["detour_t"] = 0.0
	# progress check every few seconds: jammed near the goal counts as through; jammed elsewhere, go round
	if m.get("chk_t", 0.0) <= m["go_t"]:
		var stuck = m.has("chk_p") and G.dist2d(v.pos, m["chk_p"]) < 2.0 and not m.get("held", false)
		if stuck and dg < 50.0:
			dg = 0.0
		elif stuck:
			var f = G.flat(convoy_goal - v.pos).normalized()
			var side = Vector3(f.z, 0, -f.x) * (1.0 if m.get("dside", 1.0) > 0.0 else -1.0)
			m["dside"] = -m.get("dside", 1.0)
			m["detour"] = _clear_spot(v.pos + side * 12.0 + f * 10.0, 3.5)
			m["detour_t"] = m["go_t"] + 8.0
			if v.driver() != null:
				G.fx.callout(v.driver(), G.pick(["Road's blocked, going round!", "Find another way!", "Back up, back up!"]))
		m["chk_t"] = m["go_t"] + 6.0
		m["chk_p"] = v.pos
	m["held"] = false
	if dg < 14.0:
		m["stage"] = 5
		if v in convoy:
			arrived += 1
			G.ui.radio(0, "Truck made it through! (%d of %d)" % [arrived, convoy_need])
		return null
	# trucks keep a little behind the vehicle ahead of them
	var i = convoy.find(v)
	if i > 0:
		var ahead = convoy[i - 1]
		if is_instance_valid(ahead) and not ahead.dead and ahead.mission != null and ahead.mission["stage"] < 5 and G.dist2d(ahead.pos, v.pos) < 12.0 and G.dist2d(ahead.pos, convoy_goal) < G.dist2d(v.pos, convoy_goal):
			m["held"] = true
			m["why"] = "behind"
			return null
	# the leading truck doesn't race off without its escort (but won't wait forever)
	if v == lead and m.get("wait_esc", 0.0) < 20.0:
		var near = 0
		var walkers = 0
		var f2 = G.flat(convoy_goal - v.pos).normalized()
		for s in G.soldiers:
			if s.team == 0 and s.state == "alive" and s.vehicle == null:
				walkers += 1
				var rel = G.flat(s.pos - v.pos)
				if rel.length() < 45.0 and rel.dot(f2) > -12.0:
					near += 1
		if walkers >= 3 and near < 2:
			m["wait_esc"] = m.get("wait_esc", 0.0) + G.DT
			m["held"] = true
			m["why"] = "escort"
			return null
	m["why"] = "go"
	return convoy_goal

static func _setup_rescue() -> void:
	var W = G.world
	var axis = G.flat(W.spawn[1] - W.spawn[0]).normalized()
	var perp = Vector3(-axis.z, 0, axis.x)
	var b: Rect2 = W.bounds
	# off to one side of the battlefield, a little on Bravo's side of the middle
	var depth = absf(perp.dot(Vector3(b.size.x, 0, b.size.y)))
	var p = W.capture.lerp(W.spawn[1], 0.05) + perp * (1.0 if randf() < 0.5 else -1.0) * clampf(depth * 0.36, 25.0, 90.0)
	p = G.main._free_spot(p)
	# the wreck he climbed out of
	var yaw = randf() * TAU
	W.build_now(func():
		W.add_box(p.x + 4.0, 0.0, p.z + 1.0, 2.2, 1.6, 7.0, Color(0.2, 0.22, 0.2), {"ry": yaw, "collide": false})
		W.add_box(p.x + 5.5, 0.4, p.z + 5.0, 0.6, 1.4, 3.6, Color(0.18, 0.2, 0.18), {"ry": yaw + 0.6, "collide": false})
		W.add_box(p.x + 2.0, 0.0, p.z - 3.0, 5.0, 0.15, 0.4, Color(0.15, 0.15, 0.15), {"ry": yaw + 1.2, "collide": false}))
	G.fx.wreck_smoke(Vector3(p.x + 4.0, W.ground_y(p.x, p.z) + 1.5, p.z + 1.0), W.geo_root)
	crash_p = p
	pilot = G.main.spawn_soldier(0, p.x, p.z, "pistol")
	if pilot != null:
		pilot.sname = "Lt. " + pilot.sname
		pilot.set_meta("pilot", true)
		pilot.hp = 40.0
		pilot.make_wounded()
		pilot.order = {"mode": "hold", "point": pilot.pos}
	G.ui.radio(0, "Pilot down behind enemy lines! Find him and bring him home")
	G.ui.radio(1, "An enemy pilot went down near the marker. Find him before they do")

# ---------------------------------------------------------------- kill the general
# how far a point is from team t's spawn toward the enemy's, 0 at home and 1 at theirs
static func _frac(t: int, p: Vector3) -> float:
	var a: Vector3 = G.world.spawn[t]
	var b: Vector3 = G.world.spawn[1 - t]
	var ab = G.flat(b - a)
	return G.flat(p - a).dot(ab) / maxf(1.0, ab.length_squared())

# a house in team t's half to hide in; further back each time he has to move
static func _hideout(t: int, lo: float, hi: float, avoid = null) -> Vector3:
	var cands = []
	for b in G.world.buildings:
		var p = Vector3(b["x"], 0, b["z"])
		var f = _frac(t, p)
		if f > lo and f < hi and b["w"] >= 4.5 and b["d"] >= 4.5 and b.get("fallen", 0) < 3:
			if avoid != null and G.dist2d(p, avoid) < 15.0:
				continue
			# away from the base and its vehicles, which draw fire
			var busy = G.dist2d(p, G.world.spawn[t]) < 24.0
			for v in G.vehicles:
				if G.dist2d(v.pos, p) < 18.0:
					busy = true
			if not busy:
				cands.append(p)
	if not cands.is_empty():
		var p2: Vector3 = G.pick(cands)
		return p2
	# open country: dig him in behind some sandbags off to one side
	var a: Vector3 = G.world.spawn[t]
	var b2: Vector3 = G.world.spawn[1 - t]
	var axis = G.flat(b2 - a).normalized()
	var perp = Vector3(-axis.z, 0, axis.x)
	var bnd: Rect2 = G.world.bounds
	var q0 = a.lerp(b2, randf_range(maxf(lo, 0.04), maxf(hi, 0.1))) + perp * randf_range(-30.0, 30.0)
	q0.x = clampf(q0.x, bnd.position.x + 10.0, bnd.end.x - 10.0)
	q0.z = clampf(q0.z, bnd.position.y + 10.0, bnd.end.y - 10.0)
	var q = G.main._free_spot(q0)
	G.world.build_now(func():
		G.world.sandbags(q.x, q.z + 2.2, 4.0, false)
		G.world.sandbags(q.x, q.z - 2.2, 4.0, false))
	return q

static func _setup_general() -> void:
	generals = [null, null]
	for t in range(2):
		var spot = _hideout(t, -0.15, 0.3)
		var g = G.main.spawn_soldier(t, spot.x, spot.z, "smg")
		if g == null:
			continue
		g.set_class("officer")
		g.general_look()
		g.sname = "Gen. " + g.sname
		g.set_meta("general", true)
		g.hp = 140.0
		g.order = {"mode": "hold", "point": g.pos}
		generals[t] = g
		# the general and his bodyguard are a squad of their own that never goes off on attacks
		var gq = {"team": t, "members": [], "id": G.squads.size(), "form": "wedge", "bound": 0, "guard": true, "follow": true, "leader": g}
		G.squads.append(gq)
		_join(g, gq)
		g.set_leader(true)
		for k in range(4):
			var b = G.main.spawn_soldier(t, spot.x + randf_range(-3, 3), spot.z + randf_range(-3, 3), "")
			if b != null:
				b.set_meta("guard", true)
				b.order = {"mode": "follow", "who": g, "point": null}
				_join(b, gq)
		# where to look for theirs: houses in the enemy half
		var cands = []
		for bd in G.world.buildings:
			var p = Vector3(bd["x"], 0, bd["z"])
			var f = _frac(1 - t, p)
			if f > 0.05 and f < 0.65 and bd["w"] >= 4.5:
				cands.append(p)
		if cands.is_empty():
			var a: Vector3 = G.world.spawn[1 - t]
			for k in range(6):
				cands.append(a.lerp(G.world.capture, 0.2 + k * 0.1) + Vector3(randf_range(-35, 35), 0, randf_range(-35, 35)))
		cands.shuffle()
		gen_search[t] = cands
	G.ui.radio(0, "Find and kill the enemy general. Keep ours alive: he's hiding in our half with his bodyguard")
	G.ui.radio(1, "Find and kill the enemy general. Keep ours alive: he's hiding in our half with his bodyguard")

static func _join(s, q: Dictionary) -> void:
	if s.squad != null:
		s.squad["members"].erase(s)
		if s.squad.get("leader") == s:
			s.squad["leader"] = null
			s.set_leader(false)
	q["members"].append(s)
	s.squad = q

static func _general_check() -> void:
	for t in range(2):
		var g = generals[t] if t < generals.size() else null
		if g == null or not is_instance_valid(g) or g.state == "dead":
			G.ui.radio(1 - t, "The enemy general is dead!")
			G.ui.radio(t, "We've lost the general!")
			G.main.end_game(1 - t)
			return
	for t in range(2):
		var g = generals[t]
		# has anyone on the other side laid eyes on him?
		var seen = false
		for o in G.soldiers:
			if o.team == 1 - t and o.state == "alive" and o.intel.has(g):
				var k = o.intel[g]
				if k["seen"] and G.sim_time - k["t"] < 1.0:
					seen = true
					break
		if seen:
			var first = gen_known[1 - t] == null or G.sim_time - gen_known[1 - t]["t"] > 30.0
			gen_known[1 - t] = {"p": g.pos, "t": G.sim_time}
			if first:
				G.ui.radio(1 - t, "Enemy general spotted at %s! All squads, converge!" % AI.grid_ref(g.pos))
				G.ui.radio(t, "They've seen the general! Get him out of there!")
		# enemies close by, or his hideout's known: move him further back
		var danger = seen
		for e in g.intel.keys():
			if is_instance_valid(e) and e.state == "alive" and g.intel[e]["seen"] and G.sim_time - g.intel[e]["t"] < 3.0 and G.dist2d(e.pos, g.pos) < 28.0:
				danger = true
		if danger and G.sim_time > gen_move_t[t] and g.state == "alive":
			gen_move_t[t] = G.sim_time + 70.0
			var lo = maxf(0.0, _frac(t, g.pos) - 0.25)
			var to = _hideout(t, lo, maxf(lo + 0.12, _frac(t, g.pos) - 0.02), g.pos)
			g.order = {"mode": "move", "point": to}
			g.set_meta("hide_at", to)
			G.fx.callout(g, G.pick(["Fall back! Move!", "We're leaving, now!", "Get me out of here!"]))
		elif g.has_meta("hide_at") and G.dist2d(g.pos, g.get_meta("hide_at")) < 3.0:
			g.order = {"mode": "hold", "point": g.pos}
			g.remove_meta("hide_at")

static func _general_target(s):
	if generals.size() < 2:
		return null
	var mine = generals[s.team]
	var theirs = generals[1 - s.team]
	if s == mine or s.has_meta("guard"):
		return null
	var q = s.squad["id"] if s.squad != null else s.id
	var a = float(s.id) * 2.39
	var off = Vector3(cos(a), 0, sin(a)) * (3.0 + float(s.id % 4) * 2.5)
	# every third squad screens our own general
	if q % 3 == 2 and mine != null and is_instance_valid(mine) and mine.state != "dead":
		return mine.pos + G.flat(G.world.capture - mine.pos).normalized() * 16.0 + off
	var k = gen_known[s.team]
	if k != null and G.sim_time - k["t"] < 90.0:
		if theirs != null and is_instance_valid(theirs) and G.sim_time - k["t"] < 6.0:
			return theirs.pos + off
		return k["p"] + off
	# nobody knows where he is: squads search the houses in the enemy half, a different one each in turn
	var cands: Array = gen_search[s.team]
	if cands.is_empty():
		return null
	var i = (q + int(G.sim_time / 50.0)) % cands.size()
	return cands[i] + off

# ---------------------------------------------------------------- where the AI should go in these modes
static func target_for(s):
	match G.mode:
		"general":
			return _general_target(s)
		"escort":
			var lead = _lead_truck()
			if lead == null:
				return null
			var dir = G.flat(convoy_goal - lead.pos)
			var L = dir.length()
			dir = dir / L if L > 0.1 else Vector3.ZERO
			var a = float(s.id) * 2.39
			var off = Vector3(cos(a), 0, sin(a)) * (4.0 + float(s.id % 5) * 2.0)
			if s.team == 0:
				var side = Vector3(dir.z, 0, -dir.x) * (1.0 if s.id % 2 == 0 else -1.0)
				var qid = s.squad["id"] if s.squad != null else s.id
				if qid % 2 == 0:
					# screening squads push ahead and clear the road of ambushes
					return lead.pos + dir * minf(L, 30.0 + float(qid % 3) * 8.0) + side * (6.0 + float(s.id % 4) * 3.0)
				# the rest walk alongside the trucks, out to the sides of the road (never in front of them)
				return lead.pos + dir * minf(L, 6.0 + float(s.id % 3) * 4.0) + side * (8.0 + float(s.id % 4) * 3.0)
			return lead.pos + dir * minf(L, 45.0) + off
		"rescue":
			if pilot == null or not is_instance_valid(pilot) or pilot.state == "dead":
				return null
			if s == pilot:
				return null
			var a2 = float(s.id) * 2.39
			var off2 = Vector3(cos(a2), 0, sin(a2)) * (3.0 + float(s.id % 4) * 2.5)
			if s.team == 0 and rescued:
				return _home(0) + off2
			if s.team == 1 and s.squad != null and s.squad["id"] % 2 == 1:
				return null      # half of Bravo holds the middle
			if s.team == 1 and G.sim_time > pilot_known_t:
				# Bravo only knows roughly where he came down: squads sweep the area round the wreck
				var q = s.squad["id"] if s.squad != null else s.id
				var sweep = float(q) * 1.7 + floor(G.sim_time / 20.0) * 2.1
				return crash_p + Vector3(cos(sweep), 0, sin(sweep)) * (18.0 + float(q % 3) * 9.0) + off2
			return pilot.pos + off2
	return null

static func _lead_truck():
	var best = null
	var bd = 1e9
	for v in convoy:
		if is_instance_valid(v) and not v.dead and v.mission != null and v.mission["stage"] < 5:
			var d = G.dist2d(v.pos, convoy_goal)
			if d < bd:
				bd = d
				best = v
	return best

static func _home(t: int) -> Vector3:
	var h = Build.hq(t)
	if h != null:
		return h["p"]
	return G.world.spawn[t]

# ---------------------------------------------------------------- per tick
static func step(dt: float) -> void:
	if not spits.is_empty() or not puddles.is_empty():
		step_spits(dt)
	if G.over:
		return
	check_t -= dt
	match G.mode:
		"escort":
			if check_t <= 0.0:
				check_t = 0.5
				var alive = 0
				for v in convoy:
					if is_instance_valid(v) and not v.dead and v.mission != null and v.mission["stage"] < 5:
						alive += 1
				if arrived >= convoy_need:
					G.main.end_game(0)
				elif arrived + alive < convoy_need:
					G.main.end_game(1)
		"rescue":
			rescue_t -= dt
			if check_t <= 0.0:
				check_t = 0.4
				_rescue_check()
		"koth":
			koth_t -= dt
			if koth_t <= 10.0 and koth_t + dt > 10.0:
				G.ui.message("The hill moves in 10 seconds!")
			if koth_t <= 0.0:
				_move_hill()
		"horde":
			_horde(dt)
		"general":
			if check_t <= 0.0:
				check_t = 0.5
				_general_check()

static func _rescue_check() -> void:
	if pilot == null or not is_instance_valid(pilot) or pilot.state == "dead":
		G.ui.radio(0, "We lost the pilot...")
		G.main.end_game(1)
		return
	if rescue_t <= 0.0:
		G.ui.radio(0, "Out of time. The pilot is lost")
		G.main.end_game(1)
		return
	_send_rescue_squad()
	# does Bravo see him?
	if G.sim_time > pilot_known_t - 5.0:
		var head = pilot.chest()
		for s in G.soldiers:
			if s.team == 1 and s.state == "alive" and G.dist2d(s.pos, pilot.pos) < (28.0 if not rescued else 60.0):
				if not G.blocked(s.head_pos(), head, true):
					if G.sim_time > pilot_known_t:
						G.fx.callout(s, G.pick(["There's the pilot!", "Found him!", "Pilot spotted!"]))
						G.ui.radio(1, "Pilot spotted, converge on him!")
					pilot_known_t = G.sim_time + 20.0
					break
	if not rescued:
		if randf() < 0.08:
			G.fx.callout(pilot, G.pick(["Over here!", "I'm hurt, over here!", "Anyone out there?"]))
		for s in G.soldiers_near(pilot.pos):
			if s.team == 1 and s.state == "alive" and G.dist2d(s.pos, pilot.pos) < 2.0:
				G.fx.callout(s, "Got the pilot! He's ours!")
				G.ui.radio(0, "They've taken the pilot prisoner...")
				G.main.end_game(1)
				return
		# a medic who patched him up counts as finding him
		if pilot.state == "alive" or pilot.state == "getup":
			var by = null
			for s in G.soldiers_near(pilot.pos):
				if s.team == 0 and s != pilot and s.state == "alive":
					by = s
			_rescue_done(by)
			return
		for s in G.soldiers_near(pilot.pos):
			if s.team == 0 and s != pilot and s.state == "alive" and G.dist2d(s.pos, pilot.pos) < (2.6 if s.is_player else 5.5):
				_rescue_done(s)
				break
	else:
		# keep him with somebody friendly
		var o = pilot.order
		var who = o.get("who") if o != null else null
		if pilot.state == "alive" and (who == null or not is_instance_valid(who) or who.state == "dead"):
			var best = null
			var bd = 60.0
			for s in G.soldiers:
				if s.team == 0 and s != pilot and s.state == "alive":
					var d = G.dist2d(s.pos, pilot.pos)
					if d < bd:
						bd = d
						best = s
			pilot.order = {"mode": "follow", "who": best, "point": null} if best != null else {"mode": "move", "point": _home(0)}
	if G.dist2d(pilot.pos, _home(0)) < 26.0 and (rescued or pilot.carried_by != null):
		G.ui.radio(0, "The pilot is safe!")
		G.main.end_game(0)

static func _rescue_done(s) -> void:
	rescued = true
	pilot.hp = 150.0
	if pilot.carried_by != null and is_instance_valid(pilot.carried_by):
		pilot.carried_by.carrying = null
	pilot.carried_by = null
	if pilot.state == "wounded":
		pilot.start_getup()
	pilot.order = {"mode": "follow", "who": s, "point": null} if s != null else {"mode": "move", "point": _home(0)}
	if s != null:
		G.fx.callout(s, "Got him! Head for home!")
	G.ui.radio(0, "We have the pilot! Get him back to base")
	G.ui.radio(1, "They've got the pilot. Cut them off!")

# one squad is sent to fetch the pilot, then to see him home
static func _send_rescue_squad() -> void:
	var q = rescue_squad
	var alive = 0
	if q != null:
		for m in q["members"]:
			if is_instance_valid(m) and m.state == "alive":
				alive += 1
	if q == null or alive == 0:
		var best = null
		var bs = -1e9
		for sq in G.squads:
			if sq["team"] != 0:
				continue
			var n = 0
			var cp = Vector3.ZERO
			for m in sq["members"]:
				if is_instance_valid(m) and m.state == "alive" and m != pilot:
					n += 1
					cp += m.pos
			if n == 0:
				continue
			var score = n * 20.0 - G.dist2d(cp / n, pilot.pos)
			if score > bs:
				bs = score
				best = sq
		rescue_squad = best
		q = best
		if q == null:
			return
		G.ui.radio(0, "Sending a squad to get that pilot!")
	var goal = _home(0) if rescued else pilot.pos
	for m in q["members"]:
		if is_instance_valid(m) and m.state == "alive" and not m.is_player and m != pilot:
			var a = float(m.id) * 2.39
			m.order = {"mode": "move", "point": goal + Vector3(cos(a), 0, sin(a)) * (1.5 if not rescued else 5.0)}

static func hill_spot() -> Vector3:
	var W = G.world
	var cands = []
	for o in W.objectives:
		cands.append(o["p"])
	cands.append(W.capture)
	var b: Rect2 = W.bounds
	for k in range(4):
		cands.append(W.capture + Vector3(randf_range(-0.3, 0.3) * b.size.x, 0, randf_range(-0.3, 0.3) * b.size.y))
	var cur = Obj.points[0]["p"] if not Obj.points.is_empty() else Vector3(1e6, 0, 0)
	cands.shuffle()
	for c in cands:
		if G.dist2d(c, cur) > 30.0:
			return Obj._free_near(c)
	return Obj._free_near(cands[0])

static func _move_hill() -> void:
	koth_t = KOTH_EVERY
	koth_moves += 1
	var pt = Obj.points[0]
	var p = hill_spot()
	pt["p"] = Vector3(p.x, G.world.ground_y(p.x, p.z), p.z)
	pt["owner"] = -1
	pt["prog"] = 0.0
	G.main.refresh_markers()
	for q in G.squads:
		q["obj_t"] = -1.0
	G.ui.message("The hill has moved!")
	for t in range(2):
		G.ui.radio(t, "New hill marked, everybody move!")

# ---------------------------------------------------------------- the horde
# ---- reasons to move in a zombie battle
# Each wave comes mostly from one side (announced), so the line has to be turned to face it. A supply drop
# lands out beyond the defences at the start of each wave from the second: whoever reaches it in time
# brings back points, ammunition and sometimes a weapon. And there's a keep: the building nearest the
# middle, where men rest and restock between waves, and where everyone can be called back to.
const SIDE_NAMES = ["west", "east", "north", "south"]
const DROP_TIME = 85.0
static var horde_side = -1
static var drops: Array = []         # {"p", "t", "node"}
static var keep_b = -1               # index of the keep in the world's buildings (-1: not looked for, -2: none)

static func clear_drops() -> void:
	for d in drops:
		if d.get("node") != null and is_instance_valid(d["node"]):
			d["node"].queue_free()
	drops = []

static func keep() -> int:
	if keep_b == -1:
		keep_b = -2
		var bd = 60.0
		for i in range(G.world.buildings.size()):
			var b = G.world.buildings[i]
			var d = G.dist2d(Vector3(b["x"], 0, b["z"]), G.world.capture)
			if d < bd and b["w"] > 5.0 and b["d"] > 5.0:
				bd = d
				keep_b = i
	return keep_b

static func keep_pos() -> Vector3:
	var k = keep()
	if k < 0:
		return G.world.capture
	var b = G.world.buildings[k]
	return Vector3(b["x"], G.world.ground_y(b["x"], b["z"]), b["z"])

# everyone back to the keep (or to the middle, on a map with no building near it)
static func fall_back() -> String:
	if Levels.on:
		return _fall_back_floor()
	var k = keep()
	var c = keep_pos()
	var n = 0
	for s in G.soldiers:
		if s.team != 0 or s.state != "alive" or s.is_player or s.vehicle != null:
			continue
		var p = c
		if k >= 0:
			var b = G.world.buildings[k]
			# (a clear bit of floor inside it)
			for tries in range(12):
				p = Vector3(b["x"] + randf_range(-0.5, 0.5) * (b["w"] - 2.0), c.y, b["z"] + randf_range(-0.5, 0.5) * (b["d"] - 2.0))
				if not G.world.solid_at(p.x, p.z, 0.3, p.y) and not G.world.astar.is_point_solid(G.world.nav_cell(p.x, p.z)):
					break
		else:
			p = G.main._free_spot(c + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)))
		s.order = {"mode": "move", "point": p, "tag": "fallback"}
		if k >= 0:
			s.order["in"] = k
		s.decide_t = 0.0
		_drop_job(s)
		n += 1
	G.audio.radio_click()
	return "%d men falling back to %s" % [n, "the keep" if k >= 0 else "the middle"]

# The Ministry: everyone who is below the next floor up goes to it and holds the heads of the stairs.
# With nobody inside yet, everyone goes in to the ground floor.
# (to_k: the storey to fall back to; left out, it's the one above the lowest any of them is on)
static func _fall_back_floor(to_k: int = -1) -> String:
	var low = 99
	for s in G.soldiers:
		if s.team == 0 and s.state == "alive" and not s.zombie and Levels.inside(s.pos, 0.0):
			low = mini(low, Levels.storey_of(s.pos))
	var top = Levels.n - 1
	if to_k < 0 and low != 99 and low >= top:
		return "Everyone is on the %s already: there is nowhere left to go" % Levels.names[top].to_lower()
	var k = to_k if to_k >= 0 else (0 if low == 99 else low + 1)
	var mid = Vector3(Levels.rect.position.x + Levels.rect.size.x * 0.5, Levels.floor_y(k), Levels.rect.position.y + Levels.rect.size.y * 0.5)
	var n = 0
	for s in G.soldiers:
		if s.team != 0 or s.state != "alive" or s.is_player or s.vehicle != null or s.zombie:
			continue
		if Levels.inside(s.pos, 0.0) and Levels.storey_of(s.pos) >= k:
			continue
		var near = mid + Vector3(randf_range(-0.3, 0.3) * Levels.rect.size.x, 0, randf_range(-0.25, 0.25) * Levels.rect.size.y)
		if k > 0:
			# the head of the nearest staircase that comes up to that floor
			var bd = 1e9
			for st in Levels.stairs:
				if int(st["k"]) == k - 1 and G.dist2d(st["b"], s.pos) < bd:
					bd = G.dist2d(st["b"], s.pos)
					near = st["b"]
		var p = Levels.spot_on(k, near, 5.0 if k > 0 else 4.0)
		var ord = {"mode": "move", "point": p, "tag": "fallback"}
		if k > 0:
			# Somewhere he can see the head of the stairs from, a few metres back, and facing it: that is
			# where they will come up, one or two at a time. (They used to stand anywhere within five
			# metres of it, round a corner as often as not, looking wherever they had been looking.)
			for tries in range(8):
				var q = Levels.spot_on(k, near, 5.0)
				var dq = G.dist2d(q, near)
				if dq > 2.0 and dq < 5.5 and not G.blocked(q + Vector3(0, 1.4, 0), near + Vector3(0, 1.0, 0)):
					p = q
					break
			ord["point"] = p
			var tn = G.flat(near - p)
			if tn.length() > 0.5:
				ord["face"] = atan2(tn.x, tn.z)
		s.order = ord
		s.decide_t = 0.0
		_drop_job(s)
		n += 1
	G.audio.radio_click()
	if n == 0:
		return "Everyone is on the %s or above already" % Levels.names[k].to_lower()
	return "%d men falling back to the %s" % [n, Levels.names[k].to_lower()]

# ---------------------------------------------------------------- records, regrouping, rebuilding
# the furthest wave beaten on each map, kept between sessions
static func horde_best(map_id: String, d: int = -1) -> int:
	return int(G.settings.get("horde_best", {}).get(rec_key(map_id, d), 0))

# Easy, Normal, Hard: how many of them come, how much it takes to put one down, how fast they are and
# what a kill pays. Each has its own record (Normal's is the one that was kept before there were three).
const DIFF_NAMES = ["Easy", "Normal", "Hard"]
const DIFF_TIPS = ["A quarter fewer of them, weaker and a little slower, and a kill pays more",
	"As it was",
	"Many more of them (nearly half as many again in the open), tougher and a little faster, and a kill pays less"]

static func diff() -> int:
	return clampi(int(G.settings.get("horde_diff", 1)), 0, 2)

static func rec_key(map_id: String, d: int = -1) -> String:
	return map_id + ["/easy", "", "/hard"][diff() if d < 0 else d]

# what a kill is worth
static func kill_pay(z) -> int:
	if z.has_meta("boss"):
		return 40 if str(z.get_meta("boss")) == "mother" else 30
	var f: float = float({"brute": 4, "armored": 3, "bloater": 2, "spitter": 2}.get(z.ztype, 1)) * [1.4, 1.0, 0.7 if Levels.on else 0.6][diff()]
	if Levels.on:
		f *= 1.25
	return int(f) + (1 if randf() < f - floorf(f) else 0)

static func _record_wave() -> void:
	if G.attract or not OS.get_cmdline_user_args().is_empty() and not ("--keeprecord" in OS.get_cmdline_user_args()):
		return            # (not from the automatic tests)
	var hb: Dictionary = G.settings.get("horde_best", {})
	if horde_wave > int(hb.get(rec_key(G.map_id), 0)):
		hb[rec_key(G.map_id)] = horde_wave
		G.settings["horde_best"] = hb
		G.save_prefs()

# Between waves the remnants close up: a squad down to one or two men joins the nearest one with room.
# (Nine squads of one and two men each were a long list to command and no use as squads.)
static func _regroup() -> int:
	var mine = []
	for q in G.squads:
		if q["team"] != 0 or q.get("crew", false) or q.get("guard", false):
			continue
		q["members"] = q["members"].filter(func(m): return is_instance_valid(m) and m.state != "dead")
		if not q["members"].is_empty():
			mine.append(q)
	mine.sort_custom(func(a, b): return a["members"].size() < b["members"].size())
	var moved = 0
	for q in mine:
		if q["members"].size() > 2:
			continue
		for m in q["members"].duplicate():
			if m.is_player:
				continue
			var best = null
			var bd = 1e9
			for o in mine:
				if o == q or o["members"].is_empty() or o["members"].size() >= 6:
					continue
				var d = G.dist2d(m.pos, o["members"][0].pos)
				if d < bd:
					bd = d
					best = o
			if best != null:
				AI._into(m, best)
				moved += 1
	return moved

# Walls and roof a building has lost, put back: the pieces of it within 14 m of p (sixty at most), except
# where somebody is standing. A piece put back can be knocked down again, and counts as standing in a
# saved battle.
static func rebuild(p: Vector3) -> int:
	var W = G.world
	var b = null
	for bb in W.buildings:
		if absf(p.x - bb["x"]) < bb["w"] / 2.0 + 0.8 and absf(p.z - bb["z"]) < bb["d"] / 2.0 + 0.8:
			b = bb
			break
	if b == null:
		return 0
	var list = []
	for c in W.static_cols:
		if c.alive or not c.dest or not c.has_meta("bld") or c.has_meta("furn") or c.has_meta("tree") or c.has_meta("fence") or c.has_meta("quiet") or c.has_meta("boom"):
			continue
		if c.has_meta("rebuilt") and c.get_meta("rebuilt").alive:
			continue
		if c.has_meta("roof"):
			continue          # (roofs go back last: see below)
		var m: Vector3 = (c.lo + c.hi) * 0.5
		if absf(m.x - b["x"]) > b["w"] / 2.0 + 0.8 or absf(m.z - b["z"]) > b["d"] / 2.0 + 0.8 or G.dist2d(m, p) > 14.0:
			continue
		var clear = true
		for s in G.soldiers:
			if s.state != "dead" and s.pos.x > c.lo.x - 0.45 and s.pos.x < c.hi.x + 0.45 and s.pos.z > c.lo.z - 0.45 and s.pos.z < c.hi.z + 0.45 and s.pos.y < c.hi.y and s.pos.y + 1.8 > c.lo.y:
				clear = false
				break
		if clear:
			list.append(c)
	list.sort_custom(func(x, y): return G.dist2d((x.lo + x.hi) * 0.5, p) < G.dist2d((y.lo + y.hi) * 0.5, p))
	list = list.slice(0, 60)
	# (walls first, lowest first, so that what goes on top of them has something under it)
	list.sort_custom(func(x, y): return x.lo.y < y.lo.y)
	for c in list:
		var before = W.cols.size()
		W.build_now(func():
			W.add_box((c.lo.x + c.hi.x) * 0.5, c.lo.y, (c.lo.z + c.hi.z) * 0.5, c.hi.x - c.lo.x, c.hi.y - c.lo.y, c.hi.z - c.lo.z, c.color, {"abs": true, "dest": true, "hp": 260.0}))
		if W.cols.size() > before:
			var nc = W.cols[W.cols.size() - 1]
			c.set_meta("rebuilt", nc)
			var bld = c.get_meta("bld")
			nc.set_meta("bld", bld)
			bld["cols"].append(nc)
			if c.lo.y - c.gy < 0.5:
				bld["fallen"] = maxi(0, int(bld["fallen"]) - 1)
	# The pitched roof: back on once two walls stand under it (the same rule that brings one down). It
	# used to be left off, and a house put back together stood open to the sky.
	var roofs = 0
	for c in W.roof_cols.duplicate():
		if c.alive or not c.has_meta("bld") or not is_same(c.get_meta("bld"), b):
			continue
		if c.has_meta("rebuilt") and c.get_meta("rebuilt").alive:
			continue
		var under = 0
		for o in b["cols"]:
			if o.alive and o.lo.y - o.gy < 1.0 and o.hi.y - o.gy > 1.7 and not o.has_meta("furn") \
					and o.hi.x > c.lo.x - 0.4 and o.lo.x < c.hi.x + 0.4 and o.hi.z > c.lo.z - 0.4 and o.lo.z < c.hi.z + 0.4:
				under += 1
		if under < 3:
			continue
		var rw: float = c.hi.x - c.lo.x
		var rd: float = c.hi.z - c.lo.z
		var rh: float = float(c.get_meta("rh", minf(rw, rd) * 0.32 + 0.4))
		var mx: float = (c.lo.x + c.hi.x) * 0.5
		var mz: float = (c.lo.z + c.hi.z) * 0.5
		var made = []
		W.build_now(func():
			var ref
			if rw >= rd:
				ref = W.add_box(mx, c.lo.y, mz, rw + 0.6, rh, rd + 0.7, c.color, {"shape": "prism", "ry": PI / 2.0, "abs": true, "collide": false})
			else:
				ref = W.add_box(mx, c.lo.y, mz, rw + 0.7, rh, rd + 0.6, c.color, {"shape": "prism", "abs": true, "collide": false})
			var nc = W.add_col(mx, c.lo.y, mz, rw, minf(rh, 0.6), rd)
			nc.vis = [ref]
			made.append(nc))
		if made.is_empty():
			continue
		var nr = made[0]
		nr.set_meta("roof", true)
		nr.set_meta("rh", rh)
		nr.set_meta("bld", b)
		nr.dest = true
		nr.hp = 160.0
		nr.color = c.color
		W.roof_cols.append(nr)
		b["cols"].append(nr)
		c.set_meta("rebuilt", nr)
		roofs += 1
	if list.is_empty() and roofs == 0:
		return 0
	G.audio.hammer(p)
	return list.size() + roofs

# ---------------------------------------------------------------- what men say against the dead
# The drill for fighting men who shoot back (pin them, flank them, bound forward under covering fire)
# is the wrong thing to be shouting at a horde. Those lines are swapped for ones that fit.
const HORDE_FIGHT = ["Aim for the head!", "Don't let them get close!", "Keep shooting, keep shooting!", "Thin them out!", "Stay together!", "Watch your backs!",
	"They just keep coming!", "Make every round count!"]
const HORDE_MOVE = ["Back up, back up!", "Move, they're on us!", "Fall back, keep your spacing!", "Don't get cut off!"]

static func horde_say(text: String) -> String:
	var low = text.to_lower()
	for w in ["suppress", "base of fire", "keep them down", "everything on that position", "flank", "pinned", "enemy fire", "taking fire", "sniper", "return fire"]:
		if w in low:
			return G.pick(HORDE_FIGHT)
	for w in ["bounding", "leapfrog", "cover and move", "first team", "moving up", "advance", "push forward", "on me", "smoke"]:
		if w in low:
			return G.pick(HORDE_MOVE)
	for w in ["target down", "enemy down", "tango down", "he's down", "scratch one", "got him", "neutralised"]:
		if w in low:
			return G.pick(["One down!", "Dropped it!", "That one's finished!", "Got one!"])
	# (a sighting keeps its bearing and range: "Contact south, 15m!" becomes "Dead ones south, 15m!")
	for w in ["Contact", "Enemy", "Tango", "Hostiles"]:
		if text.begins_with(w + " ") or text.begins_with(w + ","):
			return "Dead ones" + text.substr(w.length())
	return text

static func _new_drop() -> void:
	var c = G.world.capture
	var b: Rect2 = G.world.bounds.grow(-14.0)
	var p = c
	for k in range(14):
		var ang = randf() * TAU
		# (not on the side they're coming from)
		var dv = Vector3(cos(ang), 0, sin(ang))
		var side_v = [Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 0, 1)][maxi(horde_side, 0)]
		if horde_side >= 0 and dv.dot(side_v) > 0.3:
			continue
		p = c + dv * randf_range(48.0, 68.0)
		p.x = clampf(p.x, b.position.x, b.end.x)
		p.z = clampf(p.z, b.position.y, b.end.y)
		p = G.main._free_spot(p)
		if G.dist2d(p, c) > 38.0 and Doors.building_at(p) < 0:
			break
	make_drop(p, DROP_TIME, true)

# (also how a drop that was waiting on the ground when the battle was saved is put back)
static func make_drop(p: Vector3, t: float, tell: bool) -> void:
	var c = G.world.capture
	p.y = G.world.ground_y(p.x, p.z)
	var node = Node3D.new()
	var crate = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(1.1, 0.7, 0.8)
	crate.mesh = bm
	crate.material_override = VModel.mat(Color(0.3, 0.34, 0.2))
	crate.position = Vector3(0, 0.35, 0)
	node.add_child(crate)
	for sx in [-0.3, 0.3]:
		var band = MeshInstance3D.new()
		var sb = BoxMesh.new()
		sb.size = Vector3(0.08, 0.72, 0.82)
		band.mesh = sb
		band.material_override = VModel.mat(Color(0.75, 0.72, 0.62))
		band.position = Vector3(sx, 0.35, 0)
		node.add_child(band)
	# a column of green light over it, to find it by from anywhere on the map
	var beam = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.25
	cm.bottom_radius = 0.25
	cm.height = 34.0
	cm.radial_segments = 6
	cm.rings = 1
	beam.mesh = cm
	var mt = StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.albedo_color = Color(0.4, 1.0, 0.45, 0.42)
	mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mt.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = mt
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position = Vector3(0, 17.5, 0)
	node.add_child(beam)
	G.world.add_child(node)
	node.global_position = p
	drops.append({"p": p, "t": t, "node": node})
	if not tell:
		return
	G.ui.message("Supply drop at %s: get a man to it within %d s (green light)" % [AI.grid_ref(p), int(DROP_TIME)])
	G.ui.radio(0, "Supplies dropped at %s, %d m out. Fetch them before the dead get there" % [AI.grid_ref(p), int(G.dist2d(p, c))])

static func _step_drops(dt: float) -> void:
	for i in range(drops.size() - 1, -1, -1):
		var d = drops[i]
		d["t"] -= dt
		var who = null
		for s in G.soldiers:
			if s.team == 0 and s.state == "alive" and G.dist2d(s.pos, d["p"]) < 3.0 and absf(s.pos.y - d["p"].y) < 2.5:
				who = s
				break
		if who == null and d["t"] > 0.0:
			if is_instance_valid(d["node"]):
				d["node"].rotation.y += dt * 0.6
			continue
		if is_instance_valid(d["node"]):
			d["node"].queue_free()
		drops.remove_at(i)
		if who == null:
			G.ui.message("The supply drop was lost")
			continue
		# what's in it: points always, ammunition for everyone near, and one thing more
		Support.points[0] += 8
		var near = 0
		for s in G.soldiers:
			if s.team == 0 and s.state != "dead" and G.dist2d(s.pos, d["p"]) < 30.0:
				s.reserve = s.W["mag"] * s.W["mags"]
				s.grenades = maxi(s.grenades, 2)
				near += 1
		var extra = ""
		var r = randf()
		if r < 0.4 and not who.is_player and who.wid != "lmg":
			who.set_weapon("lmg")
			extra = ", and a machine gun for %s" % who.sname
		elif r < 0.7:
			for s in G.soldiers:
				if s.team == 0 and (s.state == "alive" or s.state == "wounded"):
					s.hp = 100.0
					s.bleed = 0.0
			extra = ", and dressings for everyone"
		else:
			Support.points[0] += 6
			extra = ", and 6 points more"
		G.fx.callout(who, G.pick(["Got it!", "Supplies! Over here!", "Crate's ours!"]))
		G.ui.message("Supply drop recovered: +8 points, %d men restocked%s" % [near, extra])

# between waves the keep is where men rest: anyone inside it mends slowly and fills his pouches
static func _keep_rest(dt: float) -> void:
	var k = keep()
	if k < 0:
		return
	for s in G.soldiers:
		if s.team == 0 and s.state == "alive" and Doors.building_at(s.pos) == k:
			s.hp = minf(100.0, s.hp + 3.0 * dt)
			if s.reserve < s.W["mag"] * s.W["mags"] and randf() < dt * 0.5:
				s.reserve = mini(s.W["mag"] * s.W["mags"], s.reserve + s.W["mag"])

static func _horde(dt: float) -> void:
	_step_drops(dt)
	_step_rocks(dt)
	_fortify(dt)
	_auto_up(dt)
	_quartermaster(dt)
	if Levels.on and not horde_in and G.sim_time > 1.0:
		# (the Ministry: nobody waits for them in the yard)
		horde_in = true
		fall_back()
		# (the view starts well back from the building, looking down on it: it used to start with the
		# camera against the south wall)
		if G.player == null and not G.pc.rts:
			var c0 = Vector3(Levels.rect.position.x + Levels.rect.size.x * 0.5, Levels.gy, Levels.rect.position.y + Levels.rect.size.y * 0.5)
			var from = c0 + Vector3(0, 46.0, 52.0)
			var dv = c0 - from
			G.pc.free_pos = from
			G.pc.free_yaw = atan2(dv.x, dv.z)
			G.pc.free_pitch = atan2(dv.y, Vector2(dv.x, dv.z).length())
		G.ui.message("The Ministry. Your men board up the ground floor and hold it; when a floor is overrun they fall back up the stairs by themselves (\"Up a floor\" in the Armoury tab sends them up sooner)")
	var dead_walking = 0
	for s in G.soldiers:
		if s.team == 1 and s.state != "dead":
			dead_walking += 1
	if G.alive_count(0) == 0:
		G.ui.message("Overrun after %d waves" % maxi(0, horde_wave - 1))
		G.main.end_game(1)
		return
	if horde_left > 0:
		horde_spawn_t -= dt
		if horde_spawn_t <= 0.0 and dead_walking < 90:
			horde_spawn_t = 1.2
			var n = mini(horde_left, 7)
			horde_left -= n
			_spawn_pack(n)
		return
	if dead_walking > 0:
		# The last few of a wave that can't get at anyone (shut in a room, the wrong side of a wall, at the
		# foot of something they can't climb) don't hold the next wave up for ever: after forty seconds
		# with none of them within reach of a man, they drop.
		# ...and a dozen or fewer with nobody killed for a minute and a half go the same way: five of them
		# shut in somewhere held a self-played Ministry battle in its sixth wave for a quarter of an hour.
		var kills_now = int(Stats.teams[0]["kills"])
		if kills_now != last_kills or horde_left > 0:
			last_kills = kills_now
			quiet_t = 0.0
		else:
			quiet_t += dt
		if dead_walking <= 12 and quiet_t > 90.0:
			quiet_t = 0.0
			for z in G.soldiers.duplicate():
				if z.team == 1 and z.state != "dead":
					z.hp = 0.0
					Combat.kill(z, null, false)
					stragglers += 1
			G.ui.radio(0, "Nothing's moved for a while: the last of them have dropped. Wave %d is done" % horde_wave)
			return
		if dead_walking <= 4:
			var near_any = false
			for z in G.soldiers:
				if z.team != 1 or z.state == "dead":
					continue
				for m in G.soldiers:
					if m.team == 0 and m.state != "dead" and G.dist2d(m.pos, z.pos) < 14.0 and absf(m.pos.y - z.pos.y) < 1.7 and not G.blocked(z.pos + Vector3(0, 1.0, 0), m.pos + Vector3(0, 1.0, 0)):
						near_any = true
						break
				if near_any:
					break
			stall_t = 0.0 if near_any else stall_t + dt
			if stall_t > 40.0:
				stall_t = 0.0
				for z in G.soldiers.duplicate():
					if z.team == 1 and z.state != "dead":
						z.hp = 0.0
						Combat.kill(z, null, false)
						stragglers += 1
				G.ui.radio(0, "The last of them have dropped. Wave %d is done" % horde_wave)
		else:
			stall_t = 0.0
		return
	stall_t = 0.0
	if horde_wave >= HORDE_WIN and not horde_endless:
		_record_wave()
		G.main.end_game(0)
		return
	if horde_t >= BREAK - 0.01 and horde_wave > 0:
		var was_best = horde_best(G.map_id)
		_record_wave()
		var rec = ("  A new best for this map (it was %d)." % was_best) if (horde_wave > was_best and was_best > 0) else ""
		G.ui.message("Wave %d beaten: %d s to dig in. Build barricades and buy weapons (Armoury tab); the men board up the windows and doors of the house they hold. Men in the keep rest and restock.%s" % [horde_wave, int(BREAK), rec])
		G.ui.radio(0, "Wave %d done. Points for kills: %d to spend" % [horde_wave, Support.points[0]])
		_regroup()
		# where the next lot will come from is known now, so the right side gets boarded in the break
		horde_side = randi() % 4
		side_known = true
		G.ui.radio(0, "Scouts say the next lot is coming from the %s" % SIDE_NAMES[horde_side])
		_back_down()
	horde_t -= dt
	_keep_rest(dt)
	if horde_t > 0.0:
		return
	horde_wave += 1
	if not side_known:
		horde_side = randi() % 4
	side_known = false
	board_spent = 0
	horde_left = wave_size(horde_wave)
	press = {}
	_no_launchers()
	# after dark they come in greater numbers (and faster: see make_zombie)
	if G.main.is_night():
		horde_left = int(horde_left * 1.4)
		G.ui.radio(0, "It's dark: there'll be more of them, and they're faster")
	horde_t = BREAK
	new_men(maxi(0, G.team_size - G.alive_count(0)))
	# Every tenth wave something much bigger comes with them: the Goliath at ten, the Hurler at twenty,
	# the Brood mother at thirty, then round again with one more of them each time.
	boss_due = 0
	if horde_wave % 10 == 0:
		var tens = horde_wave / 10 - 1
		boss_kind_due = BOSS_ORDER[tens % 3]
		boss_due = 1 + tens / 3
		horde_left += boss_due
	G.ui.message("Wave %d: %d of them, most from the %s%s" % [horde_wave, horde_left, SIDE_NAMES[horde_side], "" if boss_due == 0 else (". %s is with them" % BOSS_SAY[boss_kind_due][0] if boss_due == 1 else ". %d of the big ones are with them" % boss_due)])
	if boss_due > 0:
		G.ui.radio(0, BOSS_SAY[boss_kind_due][1])
	G.ui.radio(0, "They're coming from the %s. Turn the line to face them" % SIDE_NAMES[horde_side])
	if horde_wave >= 2:
		_new_drop()

# Indoors a lobbed grenade hits the ceiling and comes down among the men who fired it (two of three
# friendly-fire deaths in one Ministry battle). Holding the Ministry, grenadiers carry rifles.
static func _no_launchers() -> void:
	if not Levels.on:
		return
	for m in G.soldiers:
		if m.team == 0 and not m.zombie and not m.is_player and m.state != "dead" and m.wid == "gl":
			m.set_weapon("rifle")
			m.mag = int(m.W["mag"])
			m.reserve = int(m.W["mag"]) * 6

# How many come in a wave. In the open they can be shot down a long way off, so there are more of them
# there, the later waves grow faster, and Hard brings nearly half as many again. Inside the Ministry
# every one of them arrives at arm's length: the first waves are a little over half the size there and
# it builds to five in six of the open's by the fifth, and a kill pays a quarter more. (Nobody giving orders, the town was won on Hard and the Ministry lost in wave 4.)
static func wave_size(w: int) -> int:
	var n = 10.0 + w * 8.0 + G.team_size
	if Levels.on:
		n *= lerpf(0.55, 0.85, clampf((w - 1) / 4.0, 0.0, 1.0))
		return int(round(n * [0.75, 1.0, 1.25][diff()]))
	n += 0.5 * w * w
	return int(round(n * [0.75, 1.0, 1.45][diff()]))

static func _spawn_pack(n: int) -> void:
	var W = G.world
	var b: Rect2 = W.bounds
	var c = G.world.capture
	var p = Vector3.ZERO
	# somewhere on the edge of the map, not right on top of anyone
	for k in range(10):
		# (three packs in four come from the side this wave is coming from)
		var side = horde_side if (horde_side >= 0 and randf() < 0.75) else randi() % 4
		match side:
			0: p = Vector3(b.position.x + 12.0, 0, randf_range(b.position.y + 10.0, b.end.y - 10.0))
			1: p = Vector3(b.end.x - 12.0, 0, randf_range(b.position.y + 10.0, b.end.y - 10.0))
			2: p = Vector3(randf_range(b.position.x + 10.0, b.end.x - 10.0), 0, b.position.y + 12.0)
			_: p = Vector3(randf_range(b.position.x + 10.0, b.end.x - 10.0), 0, b.end.y - 12.0)
		p = c + (p - c).limit_length(110.0)
		var ok = true
		for s in G.soldiers:
			if s.team == 0 and s.state != "dead" and G.dist2d(s.pos, p) < 45.0:
				ok = false
				break
		if ok:
			break
	for i in range(n):
		var q = G.main._free_spot(p + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5)))
		var kind = _pick_type()
		if boss_due > 0:
			boss_due -= 1
			kind = boss_kind_due
		spawn_zombie(kind, q.x, q.z)

# later waves bring more of the fast and the big ones
static func _pick_type() -> String:
	var r = randf()
	# (on Hard in the open the mix is that of three waves later: more that run, more of the big ones)
	var w = float(horde_wave) + (3.0 if diff() == 2 and not Levels.on else 0.0)
	# later waves: riot-armoured ones, bloaters that burst, and spitters that throw acid from a distance
	if horde_wave >= 2 and randf() < 0.05 + 0.01 * w:
		return "bloater"
	if horde_wave >= 3 and randf() < 0.04 + 0.01 * w:
		return "armored"
	if horde_wave >= 4 and randf() < 0.03 + 0.005 * w:
		return "spitter"
	if horde_wave >= 2 and r < 0.04 + 0.012 * w:
		return "brute"
	r = randf()
	if r < 0.12 + 0.025 * w:
		return "runner"
	if randf() < 0.12:
		return "crawler"
	return "walker"

const ZOMBIES = {
	"walker": {"hp": 110.0, "hpw": 6.0, "speed": [2.4, 3.2], "dmg": [16.0, 24.0], "name": "Walker"},
	"runner": {"hp": 70.0, "hpw": 4.0, "speed": [5.0, 5.8], "dmg": [12.0, 18.0], "name": "Runner"},
	"brute": {"hp": 430.0, "hpw": 25.0, "speed": [2.2, 2.6], "dmg": [34.0, 44.0], "name": "Brute"},
	"crawler": {"hp": 55.0, "hpw": 3.0, "speed": [2.6, 3.0], "dmg": [9.0, 14.0], "name": "Crawler"},
	"armored": {"hp": 220.0, "hpw": 8.0, "speed": [2.3, 2.9], "dmg": [18.0, 26.0], "name": "Armoured"},
	"bloater": {"hp": 90.0, "hpw": 4.0, "speed": [2.0, 2.5], "dmg": [14.0, 20.0], "name": "Bloater"},
	"spitter": {"hp": 80.0, "hpw": 4.0, "speed": [2.6, 3.2], "dmg": [10.0, 15.0], "name": "Spitter"},
	# the giant of every tenth wave: a brute three times over. Rifles wear it down slowly; machine guns,
	# grenades and fire do it quicker, and it goes through a barricade or a boarded door without stopping
	"boss": {"hp": 2200.0, "hpw": 45.0, "speed": [2.5, 2.7], "dmg": [55.0, 75.0], "name": "Goliath"},
	"hurler": {"hp": 1700.0, "hpw": 40.0, "speed": [2.1, 2.3], "dmg": [35.0, 50.0], "name": "Hurler"},
	"mother": {"hp": 2500.0, "hpw": 45.0, "speed": [1.7, 1.9], "dmg": [30.0, 45.0], "name": "Brood mother"},
}
static var boss = null
static var boss_due = 0
static var boss_kind_due = "boss"
const BOSS_ORDER = ["boss", "hurler", "mother"]
const BOSS_SIZE = {"boss": 1.5, "hurler": 1.4, "mother": 1.38}     # how much bigger than a man, all through
const BOSS_SAY = {
	"boss": ["A giant", "There's a giant in that lot. It'll stamp flat anything near it: keep back from it, and everything you've got on it"],
	"hurler": ["Something that throws", "One of them is throwing masonry. Don't bunch up, and get it before it gets the range"],
	"mother": ["Something that breeds", "The big pale one is dropping more of them as it comes. Kill it first or we'll never see the end of them"],
}

# one of the dead of a given kind, put down at a spot (the giants are built bigger from the start)
static func spawn_zombie(kind: String, x: float, z: float):
	var big: bool = BOSS_SIZE.has(kind)
	Soldier.zombie_next = "brute" if big else kind
	Soldier.size_next = float(BOSS_SIZE[kind]) if big else 1.0
	var s = G.main.spawn_soldier(1, x, z, "pistol")
	Soldier.zombie_next = ""
	Soldier.size_next = 1.0
	if s != null:
		make_zombie(s, kind)
	return s

static func boss_down(z) -> void:
	var nm: String = z.sname
	if boss == z:
		boss = null
		for o in G.soldiers:
			if o != z and o.zombie and o.state != "dead" and o.has_meta("boss"):
				boss = o
	G.ui.message("The %s is down" % nm)
	G.ui.radio(0, "It's down! The big one is down!")

# ---- what each of the big ones does besides walk and hit
# The Goliath stamps: everyone within five metres is thrown off his feet and hurt, and barricades and
# boards that near are flattened. The Hurler throws lumps of masonry from a distance. The Brood mother
# drops runners behind her as she comes.
static var rocks: Array = []        # {"node", "a", "b", "t", "dur", "h"}

static func _boss_tick(s, t, d: float) -> void:
	var kind = str(s.get_meta("boss"))
	var now = G.sim_time
	var level = absf(t.pos.y - s.pos.y) < 1.7
	match kind:
		"boss":
			if d < 5.0 and level and now > float(s.get_meta("slam_t", 0.0)):
				s.set_meta("slam_t", now + 7.0)
				_slam(s)
		"hurler":
			if not s.has_meta("throw_t"):
				s.set_meta("throw_t", now + 2.0)
			elif d > 7.0 and d < 36.0 and now > float(s.get_meta("throw_t")):
				if not G.blocked(s.pos + Vector3(0, 2.4, 0), t.chest()):
					s.set_meta("throw_t", now + 5.5)
					_hurl(s, t)
				else:
					s.set_meta("throw_t", now + 1.0)
		"mother":
			if not s.has_meta("brood_t"):
				s.set_meta("brood_t", now + 6.0)
			elif now > float(s.get_meta("brood_t")):
				s.set_meta("brood_t", now + 9.0)
				var mine = 0
				for o in G.soldiers:
					if o.zombie and o.state != "dead" and o.has_meta("brood"):
						mine += 1
				if mine < 14:
					for i in range(3):
						var q = G.main._free_spot(s.pos + Vector3(randf_range(-2.0, 2.0), 0, randf_range(-2.0, 2.0)))
						var kid = spawn_zombie("runner" if i < 2 else "crawler", q.x, q.z)
						if kid != null:
							kid.set_meta("brood", true)
							if absf(s.pos.y - kid.pos.y) > 1.0:
								kid.move_to(Vector3(q.x, s.pos.y, q.z))
					brood_n += 3
					G.audio.roar(s.pos)
					G.fx.dust_cloud(s.pos, 1.6)

static var upstairs_n = 0     # times one of the dead has started up a house's stairs (for the tests)
static var brood_n = 0
static var slams = 0
static var throws = 0

static func _slam(s) -> void:
	slams += 1
	G.fx.dust_cloud(s.pos, 4.0)
	G.audio.slam(s.pos)
	var cam = G.main.get_viewport().get_camera_3d()
	if cam != null and G.dist2d(cam.global_position, s.pos) < 40.0:
		Combat.shake = maxf(Combat.shake, 0.6)
	s.lunge_t = 0.4
	for m in G.soldiers.duplicate():
		if m.team == s.team or m.state == "dead":
			continue
		var dd = G.dist2d(m.pos, s.pos)
		if dd > 5.5 or absf(m.pos.y - s.pos.y) > 1.7:
			continue
		m.hp -= 10.0 + 28.0 * (1.0 - dd / 5.5)
		m.last_attacker = s
		if m.hp <= 0.0:
			Combat.kill(m, s, false)
		elif m.state == "alive":
			m.fall(1.6)
			m.push(1, G.flat(m.pos - s.pos).normalized() * 5.0 + Vector3(0, 3.0, 0), 0.5)
	_smash(s, 5.0, 900.0)
	for c in G.world.cols_in_rect(s.pos.x - 4.0, s.pos.z - 4.0, s.pos.x + 4.0, s.pos.z + 4.0):
		if c.alive and c.has_meta("board") and c.lo.y < s.pos.y + 2.4 and c.hi.y > s.pos.y:
			torn_n += c.vis.size()
			G.world.destroy_col(c)

static func _hurl(s, t) -> void:
	throws += 1
	var a: Vector3 = s.pos + Vector3(0, 2.5, 0)
	# (at where he'll be if he keeps going, roughly)
	var b: Vector3 = t.pos + G.flat(t.vel) * 0.8 + Vector3(randf_range(-1.2, 1.2), 0, randf_range(-1.2, 1.2))
	var node = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(0.55, 0.45, 0.5)
	node.mesh = bm
	node.material_override = Soldier._mat("rock", Color(0.42, 0.4, 0.37), false)
	G.world.add_child(node)
	node.global_position = a
	var dist = a.distance_to(b)
	rocks.append({"node": node, "a": a, "b": b, "t": 0.0, "dur": clampf(dist / 15.0, 0.9, 2.2), "h": 1.5 + dist * 0.13, "by": s})
	s.lunge_t = 0.35
	s.lunge_dir = G.flat(b - a).normalized()
	G.audio.roar(s.pos)

static func _step_rocks(dt: float) -> void:
	for r in rocks.duplicate():
		r["t"] += dt
		var u = clampf(float(r["t"]) / float(r["dur"]), 0.0, 1.0)
		var p: Vector3 = r["a"].lerp(r["b"], u) + Vector3(0, sin(PI * u) * float(r["h"]), 0)
		if is_instance_valid(r["node"]):
			r["node"].global_position = p
			r["node"].rotate_x(dt * 5.0)
		if u < 1.0:
			continue
		rocks.erase(r)
		if is_instance_valid(r["node"]):
			r["node"].queue_free()
		var b: Vector3 = r["b"]
		G.fx.dust_cloud(b, 2.0)
		G.audio.slam(b, 0.0)
		for i in range(5):
			G.fx.debris(b + Vector3(0, 0.3, 0), Vector3(randf_range(-3, 3), randf_range(2, 5), randf_range(-3, 3)), 0.5, Color(0.42, 0.4, 0.37), Vector3(0.2, 0.16, 0.18))
		for m in G.soldiers.duplicate():
			if m.zombie or m.state == "dead":
				continue
			var dd = m.pos.distance_to(b)
			if dd > 2.6:
				continue
			m.hp -= 12.0 + 30.0 * (1.0 - dd / 2.6)
			if is_instance_valid(r["by"]):
				m.last_attacker = r["by"]
			if m.hp <= 0.0:
				Combat.kill(m, r["by"] if is_instance_valid(r["by"]) else null, false)
			elif m.state == "alive":
				m.fall(1.3)
		G.world.damage_area(b, 1.8, 220.0)

# a spitter keeps its distance and lobs acid: a hit burns, and where it lands it leaves a puddle that
# burns anyone who stands in it for a while
static var spits: Array = []
static var puddles: Array = []
static var _acid_mat: StandardMaterial3D = null

static func _acid() -> StandardMaterial3D:
	if _acid_mat == null:
		_acid_mat = StandardMaterial3D.new()
		_acid_mat.albedo_color = Color(0.55, 0.85, 0.15, 0.85)
		_acid_mat.emission_enabled = true
		_acid_mat.emission = Color(0.35, 0.6, 0.05)
		_acid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_acid_mat.roughness = 0.2
	return _acid_mat

static func _spit(s, t) -> void:
	if G.sim_time < s.get_meta("spit_t", 0.0):
		return
	s.set_meta("spit_t", G.sim_time + randf_range(3.5, 5.0))
	var from: Vector3 = s.head_pos() + Vector3(0, -0.05, 0)
	var aim: Vector3 = t.chest() + G.flat(t.vel) * 0.5
	var flat_d = G.dist2d(aim, from)
	var tflight = clampf(flat_d / 14.0, 0.4, 1.4)
	var v = (aim - from) / tflight
	v.y -= 0.5 * G.GRAV * tflight      # arc up and over
	var m = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	sm.radial_segments = 8
	sm.rings = 4
	m.mesh = sm
	m.material_override = _acid()
	G.fx.add_child(m)
	m.global_position = from
	spits.append({"p": from, "v": v, "m": m, "life": 3.0, "owner": s})
	s.lunge_t = 0.0
	s.melee_t = 0.8
	G.audio.groan(s.pos, "snarl")

static func step_spits(dt: float) -> void:
	for i in range(spits.size() - 1, -1, -1):
		var sp = spits[i]
		sp["life"] -= dt
		sp["v"].y += G.GRAV * dt
		var np: Vector3 = sp["p"] + sp["v"] * dt
		var ex: Array = sp["owner"].rids if is_instance_valid(sp["owner"]) else []
		var hit = G.ray(sp["p"], np, G.L_WORLD | G.L_BODY, ex)
		var landed = sp["life"] <= 0.0
		var at: Vector3 = np
		if not hit.is_empty():
			at = hit.position
			landed = true
			if hit.collider.has_meta("soldier"):
				var v = hit.collider.get_meta("soldier")
				if not v.zombie and v.state != "dead":
					v.hp -= randf_range(14.0, 22.0)
					v.last_attacker = sp["owner"] if is_instance_valid(sp["owner"]) else null
					if v.is_player:
						Combat.shake = maxf(Combat.shake, 0.3)
					if v.hp <= 0.0:
						Combat.kill(v, v.last_attacker, false)
					elif v.state == "alive" and not v.is_player:
						G.fx.callout(v, G.pick(["Argh, it burns!", "Acid!", "Get it off me!"]))
		sp["p"] = np
		if is_instance_valid(sp["m"]):
			sp["m"].global_position = np
		if landed:
			if is_instance_valid(sp["m"]):
				sp["m"].queue_free()
			spits.remove_at(i)
			var gy = G.world.surface_y(at.x, at.z, at.y + 0.5)
			var pm = MeshInstance3D.new()
			var cm = CylinderMesh.new()
			cm.top_radius = 1.1
			cm.bottom_radius = 1.1
			cm.height = 0.02
			cm.radial_segments = 14
			pm.mesh = cm
			pm.material_override = _acid()
			G.fx.add_child(pm)
			pm.global_position = Vector3(at.x, gy + 0.03, at.z)
			G.fx.smoke_screen(Vector3(at.x, gy + 0.3, at.z), 2.0, Color(0.6, 0.8, 0.3), 0.3)
			puddles.append({"p": Vector3(at.x, gy, at.z), "m": pm, "life": 5.0})
	for i in range(puddles.size() - 1, -1, -1):
		var pd = puddles[i]
		pd["life"] -= dt
		if is_instance_valid(pd["m"]):
			pd["m"].scale = Vector3.ONE * clampf(pd["life"] / 2.0, 0.2, 1.0)
		if pd["life"] <= 0.0:
			if is_instance_valid(pd["m"]):
				pd["m"].queue_free()
			puddles.remove_at(i)
			continue
		for o in G.soldiers_near(pd["p"]):
			if not o.zombie and o.state == "alive" and G.dist2d(o.pos, pd["p"]) < 1.1 and absf(o.pos.y - pd["p"].y) < 1.0:
				o.hp -= 6.0 * dt
				if o.hp <= 0.0:
					Combat.kill(o, null, false)

static func clear_spits() -> void:
	for sp in spits:
		if is_instance_valid(sp["m"]):
			sp["m"].queue_free()
	for pd in puddles:
		if is_instance_valid(pd["m"]):
			pd["m"].queue_free()
	spits = []
	puddles = []

const BREAK = 30.0

# the zombie-mode shop: points come from kills and pay for weapons, supplies and boarding up windows
const SHOP = {
	"board": {"name": "Boarding: on", "cost": 0, "tip": "Your men board up the house they hold by themselves: a point a window, two a door (doors once everyone is inside), whenever there are points and none of the dead are close. Click to stop them and keep the points"},
	"buy": {"name": "Buying: on", "cost": 0, "tip": "Your men spend the points themselves: a patch-up or ammunition when enough of them need it, men back up to most of the strength they started at, then machine guns and shotguns, then a bigger team (two more a wave, thirty at most). What boarding up needs this wave is kept back. Click to stop them and do the buying yourself"},
	"lmg": {"name": "Machine guns", "cost": 12, "tip": "Click near your men: the three closest get machine guns"},
	"shotgun": {"name": "Shotguns ×4", "cost": 8, "tip": "Click near your men: the four closest get shotguns"},
	"flamer": {"name": "Flamethrower", "cost": 10, "tip": "Click near your men: the closest gets a flamethrower"},
	"ammo": {"name": "Ammo for all", "cost": 5, "tip": ""},
	"heal": {"name": "Patch all up", "cost": 6, "tip": ""},
	"man": {"name": "Extra man", "cost": 7, "tip": ""},
	"men5": {"name": "5 extra men", "cost": 32, "tip": ""},
	"rebuild": {"name": "Rebuild walls", "cost": 12, "tip": "Click a damaged building: the walls and floors it has lost within 14 m of the click are put back (not where someone is standing), and its roof once there are walls to carry it"},
	"keep": {"name": "To the keep", "cost": 0, "tip": "Everyone runs to the building in the middle and holds it"},
}

static func shop_instant(k: String) -> bool:
	return k in ["ammo", "heal", "man", "men5", "keep", "board", "buy"]

# (on the Ministry map the free order is a different one)
static func shop_name(k: String) -> String:
	if k == "keep" and Levels.on:
		return "Up a floor"
	if k == "board":
		return "Boarding: on" if auto_board else "Boarding: off"
	if k == "buy":
		return "Buying: on" if auto_buy else "Buying: off"
	return SHOP[k]["name"]

static func shop_tip(k: String) -> String:
	if k == "keep" and Levels.on:
		return "Everyone below moves up to the next floor and holds the head of the stairs (from outside, everyone runs in)"
	return SHOP[k]["tip"]

# buy something; p is where the player clicked (for the ones that need a place)
static func shop(k: String, p: Vector3) -> String:
	var c: int = SHOP[k]["cost"]
	if Support.points[0] < c:
		return "Not enough points: %s costs %d, you have %d (kills earn points)" % [SHOP[k]["name"], c, Support.points[0]]
	match k:
		"board":
			auto_board = not auto_board
			if not auto_board:
				for j in jobs.duplicate():
					_job_end(j)
			return "The men will board up the house they hold by themselves" if auto_board else "No more boarding up: the points are yours to spend"
		"buy":
			auto_buy = not auto_buy
			return "The men will spend the points themselves: men first, then weapons" if auto_buy else "No more buying: the points are yours to spend"
		"lmg", "shotgun", "flamer":
			var want = {"lmg": 3, "shotgun": 4, "flamer": 1}[k]
			var men = G.soldiers.filter(func(s): return s.team == 0 and s.state == "alive" and not s.is_player and s.wid != k)
			men.sort_custom(func(a, b): return G.dist2d(a.pos, p) < G.dist2d(b.pos, p))
			if men.is_empty():
				return "Nobody to hand them to"
			Support.points[0] -= c
			for i in range(mini(want, men.size())):
				men[i].set_weapon(k)
				G.fx.callout(men[i], G.pick(["Now we're talking!", "Got it!", "Let them come!"]))
			return "%s handed out" % SHOP[k]["name"]
		"ammo":
			Support.points[0] -= c
			for s in G.soldiers:
				if s.team == 0 and s.state != "dead":
					s.reserve = s.W["mag"] * s.W["mags"]
					s.grenades = maxi(s.grenades, 1)
			return "Everyone restocked"
		"heal":
			Support.points[0] -= c
			for s in G.soldiers:
				if s.team == 0 and (s.state == "alive" or s.state == "wounded"):
					s.hp = 100.0
					s.bleed = 0.0
					if s.state == "wounded":
						s.start_getup()
			return "Everyone patched up"
		"man":
			Support.points[0] -= c
			new_men(1)
			return "A survivor joins you"
		"men5":
			Support.points[0] -= c
			new_men(5)
			return "Five survivors join you"
		"rebuild":
			var nr = rebuild(p)
			if nr == 0:
				return "Nothing to rebuild there: click a building that has lost walls"
			Support.points[0] -= c
			return "%d pieces of the building put back" % nr
		"keep":
			return fall_back()
	return ""

# ---------------------------------------------------------------- the men board the place up themselves
# The house the survivors are holding gets its windows boarded by the men in it, one man to a window,
# whenever there are points to pay for the planks (one a window, two a door) and none of the dead are
# close. Doors are left till everyone is inside. (It used to be a card: the player bought "Board up"
# and clicked a building.) The card that is left turns it off, for anyone who'd rather keep the points.
static var auto_board = true
static var forts: Array = []          # every door and ground-floor window: {"kind", "c", "n", "horiz", "w", "y0", "y1", "b", "cols"}
static var forts_made = false
static var jobs: Array = []           # {"s": the man, "f": the opening, "p": where he stands, "w": time worked, "t0", "cost"}
static var fort_t = 0.0
static var boarded_n = 0              # windows boarded this battle
static var doors_n = 0                # ...and doors
static var torn_n = 0                 # planks the dead have torn down
static var up_t = 0.0
static var ups = 0                    # times the men have gone up a floor without being told
static var job_ends = {}              # how the boarding jobs ended (for the tests)

static func _fort_list() -> Array:
	if forts_made:
		return forts
	forts_made = true
	forts = []
	var W = G.world
	for pn in Doors.panes:
		var c: Vector3 = pn["c"]
		if c.y - W.ground_y(c.x, c.z) > 2.6:
			continue          # (upstairs windows are out of their reach)
		forts.append({"kind": "win", "c": c, "n": pn["n"], "horiz": pn["horiz"], "w": pn["w"] + 0.2, "y0": c.y - pn["h"] * 0.42, "y1": c.y + pn["h"] * 0.42, "b": pn["b"], "pane": pn, "cols": []})
	for d in Doors.doors:
		var c2: Vector3 = d["c"]
		forts.append({"kind": "door", "c": c2, "n": d["n"], "horiz": absf(d["along"].x) > 0.5, "w": d["pw"] + 0.5, "y0": c2.y - 0.8, "y1": c2.y + 0.9, "b": d["b"], "door": d, "cols": []})
	if Levels.on:
		for o in Office.outs:
			var f: Dictionary = o.duplicate()
			f["b"] = Levels.bi
			f["cols"] = []
			forts.append(f)
	return forts

static func fort_boarded(f: Dictionary) -> bool:
	for c in f["cols"]:
		if c.alive:
			return true
	return false

# is the wall the opening is in still standing?
static func _fort_ok(f: Dictionary) -> bool:
	var src = f.get("pane", f.get("door"))
	return src == null or src["col"] == null or src["col"].alive

static func _zombie_within(p: Vector3, r: float) -> bool:
	for z in G.soldiers:
		if z.zombie and z.state != "dead" and G.dist2d(z.pos, p) < r and absf(z.pos.y - p.y) < 3.0:
			return true
	return false

# the building most of the survivors are in (-1: they aren't in one)
static func held_building() -> int:
	var cnt = {}
	var total = 0
	for s in G.soldiers:
		if s.team == 0 and s.state == "alive" and not s.zombie:
			total += 1
			var b = Doors.building_at(s.pos)
			if b >= 0:
				cnt[b] = int(cnt.get(b, 0)) + 1
	var best = -1
	var bn = 0
	for b in cnt:
		if cnt[b] > bn:
			bn = cnt[b]
			best = b
	return best if bn >= mini(3, total) and bn > 0 else -1

static func _everyone_in(b: int) -> bool:
	for s in G.soldiers:
		if s.team == 0 and not s.zombie and s.state != "dead" and Doors.building_at(s.pos) != b:
			return false
	return true

# every door of it is boarded: nobody walks in
static func sealed(b: int) -> bool:
	var n = 0
	for f in forts:
		if f["b"] == b and f["kind"] == "door" and _fort_ok(f):
			if not fort_boarded(f):
				return false
			n += 1
	return n > 0

static func _stand(f: Dictionary):
	var y = Levels.gy if (Levels.on and f["b"] == Levels.bi) else G.world.ground_y(f["c"].x, f["c"].z)
	# (somewhere the route-finder counts as open floor. A spot hard against the wall isn't, and a man sent
	# to one was taken to the nearest open ground instead, which for a window was the ground outside it:
	# he climbed out and stood there.)
	var along = Vector3(1, 0, 0) if f["horiz"] else Vector3(0, 0, 1)
	for side in [0.0, 0.5, -0.5]:
		for back in [1.2, 1.5, 1.0]:
			var p: Vector3 = f["c"] - f["n"] * back + along * side
			p.y = y
			if not G.world.solid_at(p.x, p.z, 0.25, y) and not G.world.astar.is_point_solid(G.world.nav_cell(p.x, p.z)):
				return p
	return null

static func _job_end(j: Dictionary) -> void:
	jobs.erase(j)
	var s = j["s"]
	if is_instance_valid(s) and s.task == "fortify":
		s.task = null
		s.decide_t = 0.0
		AI.stop_move(s)

static func _drop_job(s) -> void:
	for j in jobs.duplicate():
		if j["s"] == s:
			_job_end(j)

static func _fortify(dt: float) -> void:
	for j in jobs.duplicate():
		var m = j["s"]
		var why = ""
		if not is_instance_valid(m) or m.state != "alive":
			why = "man down"
		elif m.task != "fortify":
			why = "called away (%s)" % str(m.task)
		elif fort_boarded(j["f"]):
			why = "done"
		elif G.sim_time - float(j["t0"]) > 30.0:
			why = "took too long"
		elif _zombie_within(m.pos, 6.5):
			why = "the dead too close"
		if why != "":
			job_ends[why] = int(job_ends.get(why, 0)) + 1
			_job_end(j)
	fort_t -= dt
	if fort_t > 0.0 or not auto_board or G.over:
		return
	fort_t = 1.0
	var b = held_building()
	if b < 0 or jobs.size() >= 4:
		return
	var free_pts: int = Support.points[0]
	var left: int = board_cap() - board_spent
	for j in jobs:
		free_pts -= int(j["cost"])
		left -= int(j["cost"])
	var mine = 0
	for f in _fort_list():
		if f["b"] == b:
			mine += 1
	# (a house with a handful of windows is boarded all round whatever it costs: the budget is for the
	# Ministry, whose sixty-six ground-floor windows at a point each took everything there was)
	if mine <= 10:
		left = 99
	if free_pts < 1:
		return
	var doors_ok = _everyone_in(b)
	var cands = []
	var any_win = false
	for f in _fort_list():
		if f["b"] != b or fort_boarded(f) or G.sim_time < float(f.get("skip_t", 0.0)) or not _fort_ok(f):
			continue
		if f["kind"] == "door" and (not doors_ok or free_pts < 2):
			continue
		# (the budget is for windows: the doors, which are few and wide, are always worth it)
		if f["kind"] == "win" and left < 1:
			continue
		var taken = false
		for j in jobs:
			if j["f"] == f:
				taken = true
		if taken or _zombie_within(f["c"], 7.0):
			continue
		any_win = any_win or f["kind"] == "win"
		cands.append(f)
	if cands.is_empty():
		return
	var men = []
	for s in G.soldiers:
		if s.team != 0 or s.state != "alive" or s.is_player or s.zombie or s.vehicle != null or Doors.building_at(s.pos) != b:
			continue
		if s.task in ["fortify", "medic", "stretcher", "drag", "fetch", "flee", "rout", "board", "post"] or s.dragging != null or ClassAI.busy(s):
			continue
		if s.order != null and str(s.order.get("tag", "")) == "fallback" and s.order.get("point") != null and G.dist2d(s.pos, s.order["point"]) > 6.0:
			continue
		if Levels.on and Levels.level_of(s.pos) != 0:
			continue
		if _zombie_within(s.pos, 9.0):
			continue
		men.append(s)
	if men.is_empty():
		return
	# Which first: the doors (the widest ways in, once everyone is inside), then the windows on the
	# side they're coming from, and the other windows only in a small house or when points are piling
	# up. Within that, whichever is nearest a free man.
	var side_v = [Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 0, 1)][maxi(horde_side, 0)]
	var tier_of = func(f) -> int:
		if f["kind"] == "door":
			return 0
		return 1 if (horde_side >= 0 and f["n"].dot(side_v) > 0.5) else 2
	var best_tier = 9
	for f in cands:
		best_tier = mini(best_tier, tier_of.call(f))
	if best_tier == 2 and mine > 10 and Support.points[0] < 40:
		return
	var bf = null
	var bm = null
	var bs = 1e9
	for f in cands:
		if tier_of.call(f) != best_tier:
			continue
		for s in men:
			var sc = G.dist2d(s.pos, f["c"])
			if sc < bs:
				bs = sc
				bf = f
				bm = s
	if bf == null:
		return
	var p = _stand(bf)
	if p == null:
		bf["skip_t"] = G.sim_time + 25.0
		return
	jobs.append({"s": bm, "f": bf, "p": p, "w": 0.0, "t0": G.sim_time, "cost": 1 if bf["kind"] == "win" else 2})
	AI.release_cover(bm)
	bm.task = "fortify"
	AI.go_to(bm, p, 4.6)
	fort_t = 0.3

# the man's side of it: to the window, then hammer till the planks are up
static func fort_tick(s) -> void:
	var j = null
	for q in jobs:
		if q["s"] == s:
			j = q
			break
	if j == null:
		s.task = null
		s.decide_t = 0.0
		return
	var f: Dictionary = j["f"]
	var p: Vector3 = j["p"]
	# (there: on the inside of it and within arm's reach of the planks)
	var there = (s.pos - f["c"]).dot(f["n"]) < -0.2 and G.dist2d(s.pos, f["c"]) < 1.75 and absf(s.pos.y - p.y) < 1.2
	if not there:
		if s.move_target == null or G.dist2d(s.move_target, p) > 0.5:
			# (the walk ended somewhere else: there's no way to it. Leave that one for a while.)
			j["stall"] = int(j.get("stall", 0)) + 1
			if int(j["stall"]) > 4:
				f["skip_t"] = G.sim_time + 40.0
				job_ends["no way to it"] = int(job_ends.get("no way to it", 0)) + 1
				_job_end(j)
				return
			AI.go_to(s, p, 4.6)
		return
	AI.stop_move(s)
	s.want = Vector3.ZERO
	var to = G.flat(f["c"] - s.pos)
	s.aim_yaw = G.turn_to(s.aim_yaw, atan2(to.x, to.z), 5.0 * G.DT)
	s.hand_t = f["c"] - f["n"] * 0.12 + Vector3(0, sin(G.sim_time * 3.0 + s.seed_) * (f["y1"] - f["y0"]) * 0.3, 0)
	s.tool_mode = "hammer"
	s.crouch_t = 0.0
	s.prone_t = false
	var w0: float = j["w"]
	j["w"] = w0 + G.DT
	if int(w0 / 0.6) != int(float(j["w"]) / 0.6):
		G.audio.hammer(s.pos)
	if float(j["w"]) < (2.4 if f["kind"] == "win" else 3.6):
		return
	var cost: int = j["cost"]
	if Support.points[0] >= cost and not fort_boarded(f):
		Support.points[0] -= cost
		board_spent += cost
		_board(f)
		job_ends["done"] = int(job_ends.get("done", 0)) + 1
		if f["kind"] == "door":
			G.fx.callout(s, G.pick(["Door's shut!", "That'll hold them a while!", "Door's boarded!"]))
	_job_end(j)

# The planks themselves: three across a window, more across a door. What stops anyone is one sheet the
# size of the opening behind them (a plank at chest height on its own is something to duck under, and
# the dead walked in at boarded doors); the planks are what you see, and they come off from the top as
# it's torn at. Nothing fired from inside hits it: the men shoot out between the planks. (As boxes that
# stopped bullets, the boards were shot away by the defenders themselves in a few seconds.)
static func _board(f: Dictionary) -> void:
	var W = G.world
	var win: bool = f["kind"] == "win"
	var made = []
	W.build_now(func():
		if f.has("pane"):
			Doors.shatter(f["pane"], false)
			f["pane"]["boarded"] = true
		var c: Vector3 = f["c"] + f["n"] * (0.07 if win else -0.1)
		var w: float = f["w"]
		var y0: float = float(f["y0"])
		var h: float = float(f["y1"]) - y0
		var n = 3 if win else clampi(int(round(h / 0.42)), 4, 6)
		var planks = []
		for k in range(n):
			var y = y0 + h * (k + 0.5) / n
			var sz = Vector3(w, 0.16, 0.05) if f["horiz"] else Vector3(0.05, 0.16, w)
			planks.append(W.add_box(c.x, y - 0.08, c.z, sz.x, sz.y, sz.z, Color(0.5, 0.38, 0.24).darkened(randf_range(0.0, 0.2)), {"abs": true, "collide": false}))
		var base = y0 if win else y0 - 0.3
		var sheet = W.add_col(c.x, base, c.z, w if f["horiz"] else 0.08, float(f["y1"]) - base, 0.08 if f["horiz"] else w)
		sheet.vis = planks
		sheet.dest = true
		sheet.color = Color(0.5, 0.38, 0.24)
		sheet.set_meta("per", 140.0 if win else 200.0)
		sheet.hp = float(sheet.get_meta("per")) * n
		sheet.set_meta("board", true)
		made.append(sheet))
	f["cols"] = made
	for pc in made:
		# (marked as something a bullet or a line of sight goes through: see G.ray. It still stops anyone
		# walking into it, and a body knocked flying against it.)
		if is_instance_valid(pc.body):
			pc.body.set_meta("thru", true)
	if win:
		boarded_n += 1
	else:
		doors_n += 1

# every ground-floor window of the building at p, at once (what the old card did: the tests still use it)
static func board_up(p: Vector3) -> int:
	var b = Doors.building_at(p)
	if b < 0:
		return 0
	var n = 0
	for f in _fort_list():
		if f["b"] == b and f["kind"] == "win" and not fort_boarded(f) and _fort_ok(f):
			_board(f)
			n += 1
	if n > 0:
		G.audio.hammer(p)
	return n

# what's boarded, for a saved battle, and putting it back
static func boards_state() -> Array:
	var out = []
	for f in forts:
		if fort_boarded(f):
			out.append([f["c"].x, f["c"].y, f["c"].z])
	return out

static func boards_restore(list: Array) -> int:
	var n = 0
	for q in list:
		var p = Vector3(float(q[0]), float(q[1]), float(q[2]))
		for f in _fort_list():
			if f["c"].distance_to(p) < 0.4 and not fort_boarded(f):
				_board(f)
				n += 1
				break
	return n

# Men who join during the battle. They come on at the edge of the map and walk in, unless the house is
# shut (every door boarded) or the survivors have gone upstairs in the Ministry: then they are found
# inside, with the others, rather than left to hammer on the door with the dead behind them.
# New men join the others where the others are: inside the building being held, if anyone is in it, and
# otherwise beside the rest when the dead are about the place they would have walked in from. (They
# used to be put down at the edge of the map and left to walk in through the wave: at the end of one
# Ministry wave eighteen of twenty-three living men were outside.)
static func new_men(n: int) -> void:
	var n0 = G.soldiers.size()
	var mine = G.soldiers.filter(func(m): return m.team == 0 and not m.zombie and m.state == "alive" and m.vehicle == null)
	for i in range(n):
		G.main.base_spawn(0)
	if G.soldiers.size() == n0:
		return
	# (the building with most of them in it, however few that is: with two men left inside the Ministry
	# and eight just arrived it counted as not held, and the eight were left in the yard)
	var cnt = {}
	var mid = Vector3.ZERO
	for m in mine:
		mid += m.pos / float(mine.size())
		var mb = Doors.building_at(m.pos)
		if mb >= 0:
			cnt[mb] = int(cnt.get(mb, 0)) + 1
	var b = -1
	var inside_n = 0
	for kb in cnt:
		if cnt[kb] > inside_n:
			inside_n = cnt[kb]
			b = kb
	if Levels.on:
		b = Levels.bi
		inside_n = maxi(inside_n, 1)
	var into = b >= 0 and inside_n > 0
	if not into:
		if mine.is_empty():
			return
		var danger = false
		var sp: Vector3 = G.soldiers[n0].pos
		for z in G.soldiers:
			if z.zombie and z.state != "dead" and G.dist2d(z.pos, sp) < 45.0:
				danger = true
				break
		if not danger:
			return
	for i in range(n0, G.soldiers.size()):
		var s2 = G.soldiers[i]
		if s2.team != 0 or s2.zombie:
			continue
		if Levels.on and s2.wid == "gl" and not s2.is_player:
			s2.set_weapon("rifle")
			s2.mag = int(s2.W["mag"])
			s2.reserve = int(s2.W["mag"]) * 6
		if into:
			s2.move_to(_inside_spot(b))
		else:
			var q: Vector3 = G.main._free_spot(mid + Vector3(randf_range(-4.0, 4.0), 0, randf_range(-4.0, 4.0)))
			s2.move_to(Vector3(q.x, G.world.ground_y(q.x, q.z), q.z))

static func _inside_spot(b: int) -> Vector3:
	var inside = G.soldiers.filter(func(s): return s.team == 0 and s.state == "alive" and not s.zombie and Doors.building_at(s.pos) == b)
	var bd = G.world.buildings[b]
	var fallback = Vector3(bd["x"], G.world.ground_y(bd["x"], bd["z"]), bd["z"])
	if inside.is_empty():
		return fallback
	if Levels.on and b == Levels.bi:
		# (with the ones highest up)
		inside.sort_custom(func(x, y): return x.pos.y > y.pos.y)
		var m = inside[0]
		return Levels.spot_on(Levels.level_of(m.pos), m.pos, 4.0)
	for k in range(14):
		var m2 = inside[randi() % inside.size()]
		var q: Vector3 = m2.pos + Vector3(randf_range(-2.0, 2.0), 0, randf_range(-2.0, 2.0))
		q.y = G.world.ground_y(q.x, q.z)
		if Doors.building_at(q) == b and not G.world.solid_at(q.x, q.z, 0.3, q.y):
			return q
	return Vector3(inside[0].pos.x, G.world.ground_y(inside[0].pos.x, inside[0].pos.z), inside[0].pos.z)

static var quiet_t = 0.0             # how long since anything was killed, with the wave all on the field
static var last_kills = 0

# what boarding up may spend in one wave
static var board_spent = 0
static var side_known = false

static func board_cap() -> int:
	return 12 + 2 * horde_wave

# ---------------------------------------------------------------- the men spend the points themselves
# Every few seconds, with what's left after this wave's boarding is kept back: a patch-up or ammunition
# when a third of the men need it; more men, up to the size of the team and two more for every wave
# (thirty at most); then machine guns for one man in four and, indoors, shotguns for one in five; and
# when points still pile up, five more men. One card turns it off.
const MEN_CAP = 30                    # the most men they'll buy up to (more than that and the battle crawls in a browser)
static var auto_buy = true
static var buy_t = 0.0
static var bought = {}                # what they have bought this battle

static func _buy(k: String, at: Vector3, why: String) -> void:
	var c: int = SHOP[k]["cost"]
	var msg = shop(k, at)
	bought[k] = int(bought.get(k, 0)) + 1
	G.ui.radio(0, "Quartermaster: %s (%d points). %s" % [why, c, msg])

static func _quartermaster(dt: float) -> void:
	buy_t -= dt
	if buy_t > 0.0 or not auto_buy or G.over or horde_wave < 1:
		return
	buy_t = 3.0
	var men = G.soldiers.filter(func(m): return m.team == 0 and not m.zombie and (m.state == "alive" or m.state == "wounded" or m.state == "down" or m.state == "getup"))
	if men.is_empty():
		return
	var keep_back = clampi(board_cap() - board_spent, 0, 6) if auto_board else 0
	var free: int = Support.points[0] - keep_back
	var n = men.size()
	var mid = Vector3.ZERO
	var hurt = 0
	var dry = 0
	var lmgs = 0
	var shotguns = 0
	for m in men:
		mid += m.pos / float(n)
		if m.hp < 55.0 or m.state == "wounded":
			hurt += 1
		if m.reserve <= m.W["mag"]:
			dry += 1
		if m.wid == "lmg":
			lmgs += 1
		elif m.wid == "shotgun":
			shotguns += 1
	if free >= 6 and hurt >= (maxi(2, n / 4) if Levels.on else maxi(3, n / 3)):
		_buy("heal", mid, "%d of us hurt" % hurt)
		return
	if free >= 5 and dry >= maxi(3, n / 3):
		_buy("ammo", mid, "%d of us on the last magazine" % dry)
		return
	# Back up to three in five of the strength they started at first; then guns for the men there are (a machine gun for
	# one in four, and indoors a shotgun for one in five); only then a bigger team. (More men used to come
	# before anything else, and where men were being lost every wave nothing else was ever bought: the
	# Ministry was won with 112 replacements and not one machine gun.)
	var want = mini(G.team_size + horde_wave * 2, MEN_CAP)
	var guns_due = lmgs < n / 4 or (Levels.on and shotguns < n / 5)
	if n < (G.team_size * 3 + 4) / 5 or (n < want and not guns_due):
		if free >= 32 and want - n >= 4:
			_buy("men5", mid, "we're %d and want to be %d" % [n, want])
		elif free >= 7:
			_buy("man", mid, "we're %d and want to be %d" % [n, want])
		return
	if lmgs < n / 4:
		if free >= 12:
			_buy("lmg", mid, "machine guns for three")
	elif Levels.on and shotguns < n / 5:
		if free >= 8:
			_buy("shotgun", mid, "shotguns for the corridors")
	elif free >= 60 and n < MEN_CAP - 4:
		_buy("men5", mid, "points to spare")
	elif free >= 40 and lmgs < n / 2:
		_buy("lmg", mid, "points to spare: more machine guns")
	elif free >= 40 and hurt >= 1:
		_buy("heal", mid, "points to spare: %d of us hurt" % hurt)

# ---------------------------------------------------------------- back down when the wave is beaten
# The Ministry: the floors given up during a wave are taken back when it's over. Everyone upstairs
# comes down to the ground floor, by the foot of the nearest stairs, and the boarding starts again.
# (They used to stay where they had fallen back to, so a floor once lost was lost for good.)
static var downs = 0

static func _back_down() -> int:
	if not Levels.on:
		return 0
	var n = 0
	for s in G.soldiers:
		if s.team != 0 or s.state != "alive" or s.is_player or s.zombie or s.vehicle != null:
			continue
		if not Levels.inside(s.pos, 0.0) or Levels.level_of(s.pos) == 0:
			continue
		var near: Vector3 = s.pos
		var bd = 1e9
		for st in Levels.stairs:
			if int(st["k"]) == 0 and G.dist2d(st["a"], s.pos) < bd:
				bd = G.dist2d(st["a"], s.pos)
				near = st["a"]
		# (given as a fall-back order, which is the one a man carries out at a run whatever else he was doing)
		# (and a hand's breadth above the floor: a spot given at exactly ground height near a man upstairs
		# is taken to mean "here, on my floor", and they walked to the place above it and stood there)
		s.order = {"mode": "move", "point": Levels.spot_on(0, near, 7.0) + Vector3(0, 0.1, 0), "tag": "fallback"}
		_drop_job(s)
		s.decide_t = 0.0
		n += 1
	if n > 0:
		downs += 1
		G.ui.radio(0, "Wave's done: %d of us back down to the ground floor, and get the boards up" % n)
	return n

# ---------------------------------------------------------------- up a floor without being told
# The Ministry: when the lowest floor the survivors hold has more of the dead on it than men, the men
# on it go up to the next and hold the heads of the stairs (what the "Up a floor" card does). A house
# with an upstairs: when the dead are in downstairs, the men downstairs go up to the windows above.
static func _auto_up(dt: float) -> void:
	up_t -= dt
	if up_t > 0.0 or G.over:
		return
	up_t = 2.0
	if Levels.on:
		var men = []
		var dead = []
		for k in range(Levels.n):
			men.append(0)
			dead.append(0)
		for s in G.soldiers:
			if s.state == "dead" or not Levels.inside(s.pos, 0.0):
				continue
			var k2 = Levels.level_of(s.pos)
			if s.zombie:
				dead[k2] += 1
			elif s.team == 0 and s.state == "alive":
				men[k2] += 1
		# The highest floor that is overrun decides it: the men on it, and anyone still below it, go up
		# to the next. (It used to go by the lowest floor with a man on it, so one man left behind on the
		# ground floor kept sending the rest to the first floor while the first floor was being overrun.)
		# Overrun: half as many again of the dead on the floor as men, and six at least; or the last two
		# or three men with as many of the dead. Seven of them among five riflemen is a fight, not a rout.
		for k in range(Levels.n - 2, -1, -1):
			if men[k] > 0 and (dead[k] >= maxi(6, int(ceil(men[k] * 1.5))) or (men[k] <= 3 and dead[k] >= 3)):
				var msg = _fall_back_floor(k + 1)
				ups += 1
				up_t = 12.0
				G.ui.message("The %s is overrun (%d of the dead on it, %d men): %s" % [Levels.names[k].to_lower(), dead[k], men[k], msg.to_lower() if msg.begins_with("Everyone") else msg])
				G.ui.radio(0, "They're in on the %s! Up the stairs, everybody up!" % Levels.names[k].to_lower())
				break
		return
	for T in G.world.towers:
		if T.get("ladder", false) or not G.world.tower_ok(T):
			continue
		var down = []
		var zn = 0
		for s in G.soldiers:
			if s.state == "dead" or absf(s.pos.x - T["x"]) > T["w"] / 2.0 or absf(s.pos.z - T["z"]) > T["d"] / 2.0:
				continue
			if s.pos.y - G.world.ground_y(s.pos.x, s.pos.z) > 1.5:
				continue
			if s.zombie:
				zn += 1
			elif s.team == 0 and s.state == "alive" and not s.is_player and s.vehicle == null and s.task != "post":
				down.append(s)
		if down.is_empty() or zn < maxi(2, (down.size() + 1) / 2):
			continue
		var went = 0
		for s in down:
			var best = null
			var bd = 1e9
			for cp in T["cps"]:
				if AI.cover_free(cp, s) and cp.ban < G.sim_time and G.world.cp_ok(cp) and cp.p.distance_to(s.pos) < bd:
					bd = cp.p.distance_to(s.pos)
					best = cp
			if best == null:
				continue
			_drop_job(s)
			AI.release_cover(s)
			s.order = {"mode": "hold", "point": best.p, "tag": "garrison"}
			AI.take_post(s, best)
			went += 1
		if went > 0:
			ups += 1
			up_t = 8.0
			G.ui.radio(0, "They're in downstairs at %s: %d of us going up" % [AI.grid_ref(Vector3(T["x"], 0, T["z"])), went])


static func make_zombie(z, kind: String = "walker") -> void:
	var zs = ZOMBIES[kind]
	z.zombie = true
	z.ztype = "brute" if BOSS_SIZE.has(kind) else kind
	if BOSS_SIZE.has(kind):
		z.set_meta("boss", kind)
		boss = z
		G.audio.roar(z.pos)
		var eyes = z._mat_glow("zeyes", Color(1.0, 0.3, 0.1))
		match kind:
			"boss":
				# half as big again as a man all through, and built like a wall: a slab of a chest, a hump of
				# shoulder, arms like a man's thighs, eyes that glow
				var hide = z._mat("zboss", Color(0.3, 0.13, 0.11), false)
				z.bulk(1, Vector3(0.72, 0.6, 0.46), Vector3(0, 0.04, 0.02), hide)
				z.bulk(1, Vector3(0.6, 0.22, 0.34), Vector3(0, 0.34, 0.08), hide)
				z.bulk(0, Vector3(0.5, 0.28, 0.38), Vector3.ZERO, hide)
				for i in [3, 5]:
					z.bulk(i, Vector3(0.26, 0.36, 0.26), Vector3.ZERO, hide)
				for i in [4, 6]:
					z.bulk(i, Vector3(0.24, 0.36, 0.24), Vector3(0, -0.02, 0), hide)
				z.eye_glow(eyes)
			"hurler":
				# rangy and stooped, grey as the masonry it throws, with forearms like clubs
				var grey = z._mat("zhurl", Color(0.36, 0.38, 0.36), false)
				z.bulk(1, Vector3(0.5, 0.5, 0.34), Vector3(0, 0.06, 0.04), grey)
				for i in [4, 6]:
					z.bulk(i, Vector3(0.26, 0.42, 0.26), Vector3(0, -0.06, 0), grey)
				for i in [3, 5]:
					z.bulk(i, Vector3(0.18, 0.34, 0.18), Vector3.ZERO, grey)
				z.eye_glow(z._mat_glow("zeyes2", Color(0.9, 0.85, 0.3)))
			"mother":
				# pale and swollen: a great belly, and sacs on its back
				var pale = z._mat("zmother", Color(0.72, 0.66, 0.6), false)
				var sac = z._mat("zsac", Color(0.62, 0.34, 0.34), false)
				z.bulk(0, Vector3(0.66, 0.5, 0.62), Vector3(0, 0.08, -0.1), pale)
				z.bulk(1, Vector3(0.58, 0.5, 0.5), Vector3(0, -0.04, -0.06), pale)
				for q in [Vector3(-0.16, 0.14, 0.2), Vector3(0.14, 0.02, 0.22), Vector3(0.0, 0.26, 0.2)]:
					z.bulk(1, Vector3(0.2, 0.2, 0.18), q, sac)
				z.eye_glow(z._mat_glow("zeyes3", Color(0.9, 0.4, 0.6)))
	z.grenades = 0
	z.smokes = 0
	z.satchels = 0
	z.rgren = 0
	z.gun_node.visible = false
	z.hp = (zs["hp"] + horde_wave * zs["hpw"]) * [0.85, 1.0, 1.15 if Levels.on else 1.45][diff()]
	z.zspeed = randf_range(zs["speed"][0], zs["speed"][1]) * (1.2 if G.main.is_night() else 1.0) * [0.95, 1.0, 1.06 if Levels.on else 1.12][diff()]
	z.think = randf_range(0.0, 0.6)
	z.groan_t = randf_range(0.5, 6.0)
	z.sname = zs["name"]
	z.set_meta("hp0", z.hp)
	if kind == "crawler":
		z.prone_t = true
		z.prone = true

# what a zombie does instead of thinking: lurch towards the nearest living soldier, then lunge and bite
static func zombie_tick(s) -> void:
	s.think -= G.DT
	if s.think <= 0.0:
		s.think = 0.7
		var best = null
		var bd = 1e9
		for o in G.soldiers:
			if o.team != s.team and (o.state == "alive" or o.state == "wounded" or o.state == "down" or o.state == "getup"):
				var d = G.dist2d(o.pos, s.pos)
				if d < bd:
					bd = d
					best = o
		s.target = best
	var t = s.target
	s.ready_ = false
	s.ads = false
	if s.zhold != null:
		var h = s.zhold
		if not is_instance_valid(h) or h.grab_by != s or h.grab_t <= 0.0 or h.state != "alive":
			s.zhold = null
		else:
			var th2 = G.flat(h.pos - s.pos)
			AI.stop_move(s)
			s.want = th2.normalized() * 0.15 if th2.length() > 0.8 else Vector3.ZERO
			s.aim_yaw = G.turn_to(s.aim_yaw, atan2(th2.x, th2.z), 6.0 * G.DT)
			s.zhold_t = 0.25
			s.lunge_t = 0.0
			return
	s.crouch_t = 0.12 if s.ztype != "brute" else 0.0
	s.prone_t = s.ztype == "crawler" and not s.has_meta("risen")
	s.tool_mode = ""
	s.hand_t = null
	s.groan_t -= G.DT
	if s.groan_t <= 0.0:
		s.groan_t = randf_range(3.0, 8.0)
		G.audio.groan(s.pos, "brute" if s.ztype == "brute" else ("screech" if s.ztype == "runner" and randf() < 0.5 else "groan"))
	if t == null or not is_instance_valid(t) or t.state == "dead":
		AI.stop_move(s)
		s.want = Vector3.ZERO
		s.lunge_t = 0.0
		return
	var to = G.flat(t.pos - s.pos)
	if s.has_meta("boss"):
		_boss_tick(s, t, to.length())
	var d = to.length()
	# (a man on the floor above or below is not "close", however near he is on the plan: the dead stood
	# in a knot under a man upstairs and the wave never ended)
	if absf(t.pos.y - s.pos.y) > 1.7:
		d = maxf(d, 8.0) + absf(t.pos.y - s.pos.y) * 3.0
	var level = d == to.length()
	var yaw = atan2(to.x, to.z)
	s.aim_yaw = G.turn_to(s.aim_yaw, yaw, 3.0 * G.DT)
	s.aim_pitch = 0.0
	var spd: float = s.zspeed
	if s.zhit_t > 0.0:
		spd *= 0.4          # a hit costs it its stride
	# a spitter hangs back at throwing range instead of closing in
	if s.ztype == "spitter" and s.lunge_t <= 0.0 and d > 5.0 and d < 20.0 and not G.blocked(s.head_pos(), t.chest()):
		AI.stop_move(s)
		s.want = Vector3.ZERO if d > 9.0 else -to / d * 0.5
		_spit(s, t)
		return
	# the Hurler stands off where it can see him and throws (see _boss_tick), and closes only when it can't
	if s.has_meta("boss") and str(s.get_meta("boss")) == "hurler" and s.lunge_t <= 0.0 and d > 9.0 and d < 34.0 and not G.blocked(s.pos + Vector3(0, 2.4, 0), t.chest()):
		AI.stop_move(s)
		s.want = Vector3.ZERO
		s.aim_yaw = G.turn_to(s.aim_yaw, atan2(to.x, to.z), 3.0 * G.DT)
		return
	var reach = 1.0 if s.ztype == "crawler" else (2.0 if s.has_meta("boss") else 1.25)
	# the attack: a short wind-up, a lunge and a bite
	if s.lunge_t > 0.0:
		s.lunge_t -= G.DT
		AI.stop_move(s)
		if s.lunge_t > 0.3:
			# drawing back for it, and still coming on, slower, turning with him as he moves (it used to stop
			# dead, and then the lunge fell a good metre short of a man who hadn't stirred)
			if d > 0.9:
				s.lunge_dir = to / maxf(d, 0.01)
				s.want = s.lunge_dir * (spd * 0.6 / s.W["speed"])
			else:
				s.want = Vector3.ZERO
			s.aim_yaw = G.turn_to(s.aim_yaw, atan2(s.lunge_dir.x, s.lunge_dir.z), 5.0 * G.DT)
		else:
			s.want = s.lunge_dir * (minf(spd * 1.9, 6.5) / s.W["speed"]) if s.ztype != "crawler" else s.lunge_dir * 0.6
			if s.melee_t <= 0.0 and d < reach:
				s.melee_t = 1.1 if s.ztype != "brute" else 1.5
				_claw(s, t)
		if s.lunge_t <= 0.0:
			s.melee_t = maxf(s.melee_t, 0.5)
		return
	s.melee_t -= G.DT
	if d < (1.4 if s.ztype == "crawler" else (3.2 if s.has_meta("boss") else 2.4)) and s.melee_t <= 0.0:
		# (a longer drawing-back than before, so that it can be seen coming: longest for the big ones)
		s.lunge_t = {"runner": 0.45, "brute": 0.8}.get(s.ztype, 0.62)
		s.lunge_dir = to / maxf(d, 0.01)
		s.melee_t = 0.0
		G.audio.groan(s.pos, "snarl")
		return
	if d < 1.1:
		AI.stop_move(s)
		s.want = Vector3.ZERO
		return
	if s.ztype == "brute" and d < 40.0 and G.sim_time > float(s.get_meta("smash_t", 0.0)):
		# (he looks for something to hit three times a second, and rests a second after a blow)
		s.set_meta("smash_t", G.sim_time + 0.3)
		if _smash(s, 1.5, 230.0 if not s.has_meta("boss") else 700.0) or (s.has_meta("boss") and _tear(s, 1.8)):
			s.set_meta("smash_t", G.sim_time + 1.2)
			s.want = Vector3.ZERO
			return
	if level and s.bad_t < G.sim_time and (d < 7.0 or (d < 30.0 and not G.blocked(s.pos + Vector3(0, 1.0, 0), t.pos + Vector3(0, 1.0, 0)))):
		AI.stop_move(s)
		var dir = to / d
		# slide round posts and corners rather than pushing into them
		if G.world.solid_at(s.pos.x + dir.x * 0.6, s.pos.z + dir.z * 0.6, 0.22, s.pos.y) and not _vaultable_ahead(s, dir):
			# (a brute with a barricade in front of him goes through it there and then. Staged in a
			# browser, one brute against one sandbag wall, he walked round the end of it two times in four:
			# the sidestep below came before the blow, which was only tried every second or so.)
			if s.ztype == "brute" and _smash(s, 1.7, 230.0 if not s.has_meta("boss") else 700.0):
				s.set_meta("smash_t", G.sim_time + 1.2)
				s.want = Vector3.ZERO
				return
			for ang in [0.6, -0.6, 1.1, -1.1]:
				var nd = dir.rotated(Vector3.UP, ang)
				if not G.world.solid_at(s.pos.x + nd.x * 0.6, s.pos.z + nd.z * 0.6, 0.22, s.pos.y):
					dir = nd
					break
		# a lurching walk: speed surges and sags
		var surge = 1.0 if s.ztype == "runner" else 0.75 + 0.35 * absf(sin(G.sim_time * 1.6 + s.seed_))
		match s.zstyle:
			1:
				surge = 0.6 + 0.6 * maxf(0.0, sin(G.sim_time * 2.4 + s.seed_))      # lunging bursts
			2:
				surge = 0.8 + 0.25 * sin(G.sim_time * 0.9 + s.seed_)
			4:
				surge = 0.85                                                       # slow and steady
		s.want = dir * (spd * surge / s.W["speed"])
		# not getting anywhere (a wall, a fence, a crowd)? find a way round for a while
		s.prog_t += G.DT
		if s.prog_t > 1.5:
			if G.dist2d(s.pos, s.prog_p) < 0.6 and s.vault == null:
				# boarded-up windows and doors in the way get torn at
				var tore = _tear(s, 1.3)
				if not tore:
					tore = _smash(s, 1.3, 30.0)
				if not tore:
					s.bad_t = G.sim_time + 6.0
					AI.go_to(s, t.pos, spd)
			s.prog_t = 0.0
			s.prog_p = s.pos
	else:
		# A crawler following a route (round a building, in at a door, up a staircase) that isn't getting
		# anywhere hauls itself upright: the routes are for men on their feet, who step over a low wall
		# and climb stairs, and a crawler left at the foot of either kept the wave from ever ending.
		if s.ztype == "crawler" and not s.has_meta("risen"):
			if G.sim_time - float(s.get_meta("cr_t", -99.0)) > 5.0:
				if s.has_meta("cr_p") and G.sim_time - float(s.get_meta("cr_t", -99.0)) < 7.0 and G.dist2d(s.pos, s.get_meta("cr_p")) < 1.2:
					s.set_meta("risen", true)
					risen_n += 1
				s.set_meta("cr_t", G.sim_time)
				s.set_meta("cr_p", s.pos)
		# The way in is boarded up and there's no other: he goes to the nearest boarded door or window and
		# tears at it. (Before doors could be boarded there was always a way in. With every way shut, the
		# route-finder took the dead as near as it could get and left them standing at the wall.)
		var goal: Vector3 = t.pos
		var br = s.get_meta("breach") if s.has_meta("breach") else null
		if br != null:
			if not fort_boarded(br) or G.sim_time > float(s.get_meta("breach_t", 0.0)):
				s.remove_meta("breach")
				br = null
			else:
				goal = br["c"] + br["n"] * 0.75
				goal.y = s.pos.y
				var gd = G.dist2d(s.pos, goal)
				var pn = _press(br, s) if gd < 4.0 else 0
				# Over the top: with half a dozen of them heaped against it, one that can't get to the
				# planks climbs up the backs of the ones in front and in over what's left of the boards.
				if pn >= 6 and gd > 0.9 and gd < 3.8 and s.vault == null and s.ztype != "brute" and s.ztype != "crawler" and s.state == "alive" and G.sim_time > float(press[br["c"]].get("over_t", 0.0)):
					var inn: Vector3 = br["c"] - br["n"] * 1.0
					inn.y = G.world.surface_y(inn.x, inn.z, s.pos.y + 0.5)
					if absf(inn.y - s.pos.y) < 0.9 and not G.world.solid_at(inn.x, inn.z, 0.3, inn.y):
						press[br["c"]]["over_t"] = G.sim_time + 6.0
						s.vault = {"a": s.pos, "b": inn, "h": 1.5, "t": 0.0, "dive": true, "top": s.pos.y + 1.2}
						s.remove_meta("breach")
						piled += 1
						if pile_said != horde_wave:
							pile_said = horde_wave
							G.ui.radio(0, "They're coming in over the top of each other at %s!" % AI.grid_ref(br["c"]))
						return
				if gd < 1.5:
					AI.stop_move(s)
					s.want = Vector3.ZERO
					var tb = G.flat(br["c"] - s.pos)
					s.aim_yaw = G.turn_to(s.aim_yaw, atan2(tb.x, tb.z), 4.0 * G.DT)
					if G.sim_time > float(s.get_meta("tear_t", 0.0)):
						s.set_meta("tear_t", G.sim_time + 0.9)
						# a man standing close behind the boards: an arm through the gap for him
						var vic = null
						for o in G.soldiers:
							if not o.zombie and o.team != s.team and o.state == "alive" and G.dist2d(o.pos, br["c"]) < 1.7 and absf(o.pos.y - s.pos.y) < 1.5:
								vic = o
								break
						if vic != null and randf() < 0.5:
							s.lunge_t = 0.5
							s.lunge_dir = G.flat(vic.pos - s.pos).normalized()
							s.melee_t = 1.0
							_claw(s, vic, 0.5, false)
							reached += 1
							if reach_said != horde_wave:
								reach_said = horde_wave
								G.ui.radio(0, "They're reaching through the boards at %s: stand back from it" % AI.grid_ref(br["c"]))
						else:
							_tear(s, 2.0)
					return
		# (Up the stairs of a house after a man at an upstairs window, too: the way there is by the foot
		# of the stairs and the head of them. They used to walk to the spot underneath him and stand there,
		# so the upstairs of any house was somewhere the dead could never come.)
		var routed = s.route != null and G.dist2d(s.route["pts"][s.route["pts"].size() - 1], goal) < 4.0
		if not routed and (s.move_target == null or G.dist2d(s.move_target, goal) > 4.0):
			if br == null:
				AI.route_to(s, goal, spd)
			else:
				AI.go_to(s, goal, spd)
		if s.route != null and not (s.route["i"] == 0 and s.route["nav"]):
			AI.follow_route(s)
		else:
			var res = AI.follow_path(s)
			if res == "arrived" and s.route != null and G.dist2d(s.pos, s.route["pts"][0]) < 1.0:
				s.route["i"] = 1
				upstairs_n += 1
			elif res == "stuck" or res == "arrived":
				AI.stop_move(s)
				if br == null and d > 2.5 and G.sim_time > float(s.get_meta("tear_t", 0.0)):
					s.set_meta("tear_t", G.sim_time + 1.0)
					if not _tear(s, 1.6):
						var nb = _nearest_boarded(s.pos, 45.0)
						if nb != null:
							s.set_meta("breach", nb)
							s.set_meta("breach_t", G.sim_time + 40.0)

# The dead against what you've built. A brute doesn't go round or over a barricade: he puts his weight
# through it (sandbags go in one blow, a concrete wall in two). The others only claw at one when it's
# what's stopping them, and it takes a pack of them a while.
static var smashed = 0
static var smash_said = -1
static var risen_n = 0

static func _smash(s, reach: float, dmg: float) -> bool:
	for st in Build.sites:
		if st["dead"] or G.dist2d(st["p"], s.pos) > 12.0:
			continue
		for c in st["cols"]:
			if not c.alive or not c.dest or c.lo.y > s.pos.y + 1.6 or c.hi.y < s.pos.y:
				continue
			var cx = clampf(s.pos.x, c.lo.x, c.hi.x)
			var cz = clampf(s.pos.z, c.lo.z, c.hi.z)
			if Vector2(cx - s.pos.x, cz - s.pos.z).length() > reach:
				continue
			c.hp -= dmg
			s.lunge_t = 0.5
			s.lunge_dir = G.flat(((c.lo + c.hi) * 0.5) - s.pos).normalized()
			G.audio.hammer(s.pos)
			if c.hp <= 0.0:
				G.world.destroy_col(c)
				smashed += 1
				if smash_said != horde_wave:
					smash_said = horde_wave
					G.ui.message("The dead are breaking through the barricades at %s" % AI.grid_ref(s.pos))
			return true
	return false

# claw at whatever is nailed over a door or window within reach
# claw at whatever is nailed over a door or window within reach: the planks come off one at a time, from the top
static func _tear(s, reach: float) -> bool:
	var bc = null
	for c in G.world.cols_in_rect(s.pos.x - reach, s.pos.z - reach, s.pos.x + reach, s.pos.z + reach):
		if c.alive and c.has_meta("board") and c.lo.y < s.pos.y + 2.4 and c.hi.y > s.pos.y:
			bc = c
			break
	if bc == null:
		return false
	bc.hp -= 400.0 if s.has_meta("boss") else (140.0 if s.ztype == "brute" else 55.0)
	s.lunge_t = 0.5
	s.lunge_dir = G.flat(((bc.lo + bc.hi) * 0.5) - s.pos).normalized()
	G.audio.hammer(s.pos)
	var left = int(ceil(maxf(bc.hp, 0.0) / float(bc.get_meta("per", 140.0))))
	while bc.vis.size() > left:
		var r = bc.vis.pop_back()
		if r[1] == -2 and is_instance_valid(r[0]):
			var pp: Vector3 = r[0].global_position
			r[0].queue_free()
			G.audio.tear(pp)
			G.fx.debris(pp, Vector3(randf_range(-1.5, 1.5), randf_range(0.5, 2.0), randf_range(-1.5, 1.5)), 0.3, bc.color, Vector3(0.7, 0.14, 0.05))
		torn_n += 1
	if bc.hp <= 0.0:
		G.world.destroy_col(bc)
	return true

# how many of them are pressed up against one boarded opening just now
static var press = {}                # by the opening's middle: {"seen": {id: when}, "t", "over_t"}
static var pile_said = -1
static var reach_said = -1

static func _press(f, s) -> int:
	var key: Vector3 = f["c"]
	if not press.has(key):
		press[key] = {"seen": {}, "t": 0.0, "over_t": 0.0}
	var pr: Dictionary = press[key]
	pr["seen"][s.id] = G.sim_time
	if G.sim_time - float(pr["t"]) > 1.0:
		pr["t"] = G.sim_time
		for k in pr["seen"].keys():
			if G.sim_time - float(pr["seen"][k]) > 1.0:
				pr["seen"].erase(k)
	return pr["seen"].size()

static func _nearest_boarded(p: Vector3, r: float):
	var best = null
	var bd = r
	for f in forts:
		if fort_boarded(f) and G.dist2d(f["c"], p) < bd and absf(f["c"].y - p.y) < 3.0:
			bd = G.dist2d(f["c"], p)
			best = f
	return best

static func _vaultable_ahead(s, dir: Vector3) -> bool:
	for c in G.world.cell_at(s.pos.x + dir.x * 0.7, s.pos.z + dir.z * 0.7):
		if G.world.vaultable(c):
			return true
	return false

# ---- for the tests: how the dead have taken their hits, and how the men have got on in their grip
static var flinches = 0
static var legs_off = 0
static var zdeaths = [0, 0, 0]       # put down through the head, through the body, by a limb
static var grabs = 0
static var shoved = 0
static var dragged = 0
static var pulled = 0                # freed by the man next to him
static var reached = 0               # clawed through the boards
static var piled = 0                 # came in over the top of the others

# A leg shot through: it comes off at the knee, the thing goes down on its face and comes on along the
# ground, slower. Not the big ones, and not the ones already crawling.
static func lose_leg(z, sd: int) -> void:
	if z.has_meta("legless") or z.ztype == "crawler" or z.ztype == "brute" or z.has_meta("boss") or z.state == "dead":
		return
	z.set_meta("legless", sd)
	legs_off += 1
	var shin = 8 if sd == 0 else 10
	var kp: Vector3 = z.parts[shin].global_position
	for ch in z.parts[shin].get_children():
		if ch is MeshInstance3D:
			ch.queue_free()
	z._mesh(z.parts[shin - 1], Vector3(0.16, 0.05, 0.16), Vector3(0, -0.215, 0), z._mat("zblood", Color(0.32, 0.05, 0.04), false))
	z._mesh(z.parts[shin - 1], Vector3(0.05, 0.08, 0.05), Vector3(0, -0.26, 0), z._mat("zbone", Color(0.8, 0.77, 0.66), false))
	G.fx.debris(kp, Vector3(randf_range(-1.2, 1.2), 1.6, randf_range(-1.2, 1.2)), 0.5, Color(0.2, 0.2, 0.2), Vector3(0.14, 0.42, 0.14))
	G.fx.bleed(kp, Vector3.UP, false)
	G.fx.bleed(kp, Vector3.DOWN, false)
	z.ztype = "crawler"
	z.zspeed = randf_range(1.5, 2.0)
	if z.zhold != null:
		z.zhold = null
	z.fall(1.3)

# ---- a man in the grip of one of the dead
# A grab that lands takes hold. For a second or so he can do nothing but wrench at it; then he either
# throws it off (likelier if he's unhurt, surer if a friend is beside him to haul it away, harder with
# more of them on him) and it goes down, or it bears him to the ground and goes on biting.
static func _grab(z, t) -> bool:
	if t.is_player or t.grab_t > 0.0 or t.state != "alive" or t.vehicle != null:
		return false
	if z.ztype == "brute" or z.ztype == "crawler" or z.ztype == "spitter" or z.has_meta("boss") or z.atk_kind != 0 or z.has_meta("breach"):
		return false
	if randf() > 0.45:
		return false
	t.grab_by = z
	t.grab_t = randf_range(0.9, 1.4)
	z.zhold = t
	z.zhold_t = 0.3
	grabs += 1
	if randf() < 0.5:
		G.fx.callout(t, G.pick(["It's got me!", "Get it off me!", "Get off! Get off!", "Help me here!"]))
	return true

static func _grab_end(s) -> void:
	var z = s.grab_by
	if z != null and is_instance_valid(z) and z.zhold == s:
		z.zhold = null
	s.grab_by = null
	s.grab_t = 0.0

static func grab_tick(s) -> void:
	var z = s.grab_by
	if z == null or not is_instance_valid(z) or z.state != "alive" or s.state != "alive" or G.dist2d(z.pos, s.pos) > 2.4:
		_grab_end(s)
		return
	s.grab_t -= G.DT
	AI.stop_move(s)
	s.want = Vector3(sin(G.sim_time * 11.0 + s.seed_), 0, cos(G.sim_time * 8.0 + s.seed_)) * 0.22
	s.ready_ = false
	var to = G.flat(z.pos - s.pos)
	s.aim_yaw = G.turn_to(s.aim_yaw, atan2(to.x, to.z), 6.0 * G.DT)
	if s.grab_t > 0.0:
		return
	var others = 0
	var friend = null
	for o in G.soldiers:
		if o == s or o == z or o.state != "alive":
			continue
		var dd = G.dist2d(o.pos, s.pos)
		if o.zombie and dd < 1.6 and absf(o.pos.y - s.pos.y) < 1.5:
			others += 1
		elif not o.zombie and o.team == s.team and o.grab_t <= 0.0 and dd < 4.5 and absf(o.pos.y - s.pos.y) < 1.5:
			friend = o
	var p = 0.6 + (0.15 if s.hp > 60.0 else 0.0) - minf(0.3, 0.08 * others) + (0.35 if friend != null else 0.0)
	var away = -to.normalized() if to.length() > 0.05 else Vector3(sin(s.body_yaw), 0, cos(s.body_yaw))
	if randf() < clampf(p, 0.1, 0.95):
		z.fall(1.3)
		z.push(1, away * 4.0 + Vector3(0, 1.4, 0), 0.5)
		z.melee_t = 1.5
		if friend != null and randf() < 0.6:
			pulled += 1
			G.fx.callout(friend, G.pick(["Got it! You're clear!", "I've got it, go!", "Off him!"]))
		else:
			shoved += 1
			if randf() < 0.5:
				G.fx.callout(s, G.pick(["Get OFF!", "Off me!", "Not today!"]))
	else:
		dragged += 1
		s.hp -= randf_range(8.0, 14.0)
		G.fx.bleed(s.chest(), away, false)
		if s.hp <= 0.0:
			_grab_end(s)
			Combat.kill(s, z, false)
			return
		G.audio.voice(s, "scream")
		s.fall(2.0)
		s.push(1, away * -1.5 + Vector3(0, -1.0, 0), 0.4)
		z.melee_t = 0.5
	_grab_end(s)

static func _claw(z, t, k: float = 1.0, may_grab: bool = true) -> void:
	var zk = str(z.get_meta("boss")) if z.has_meta("boss") else z.ztype
	var zr = ZOMBIES[zk]["dmg"] if ZOMBIES.has(zk) else ZOMBIES["walker"]["dmg"]
	var dmg = randf_range(zr[0], zr[1]) * k
	t.hp -= dmg
	t.last_attacker = z
	G.fx.bleed(t.chest(), G.flat(t.pos - z.pos).normalized(), false)
	G.audio.play(G.audio.s_hit, t.chest(), -4.0, 0.6)
	if t.is_player:
		Combat.shake = maxf(Combat.shake, 0.35)
	if t.hp <= 0.0:
		Combat.kill(t, z, false)
	elif may_grab and _grab(z, t):
		pass
	elif t.state == "alive" and may_grab and (z.ztype == "brute" or randf() < 0.2):
		t.fall(1.6 if z.ztype == "brute" else 1.2)
		if z.ztype == "brute":
			t.push(1, G.flat(t.pos - z.pos).normalized() * 6.0 + Vector3(0, 2.5, 0), 0.5)
	if t.state == "alive" and not t.is_player:
		Morale.shock(t, 8.0)

# ---------------------------------------------------------------- HUD line
static func status_text() -> String:
	match G.mode:
		"general":
			if generals.size() < 2 or generals[0] == null or generals[1] == null:
				return ""
			var k = gen_known[0]
			var their = "location unknown" if k == null else ("spotted %d s ago" % int(G.sim_time - k["t"]))
			var guards = 0
			for s in G.soldiers:
				if s.team == 0 and s.state == "alive" and s.has_meta("guard"):
					guards += 1
			return "their general: %s · ours: %d guards" % [their, guards]
		"escort":
			var alive = 0
			for v in convoy:
				if is_instance_valid(v) and not v.dead and v.mission != null and v.mission["stage"] < 5:
					alive += 1
			return "convoy: %d through, %d on the road (need %d)" % [arrived, alive, convoy_need]
		"rescue":
			var st = "pilot down" if not rescued else "bring the pilot home"
			return "%s · %d:%02d" % [st, int(rescue_t) / 60, int(rescue_t) % 60]
		"koth":
			return "hill moves in %d s" % int(koth_t)
		"horde":
			var n = 0
			for s in G.soldiers:
				if s.team == 1 and s.state != "dead":
					n += 1
			var extra = ""
			if horde_side >= 0 and n + horde_left > 0:
				extra += " from the %s" % SIDE_NAMES[horde_side]
			if not drops.is_empty():
				extra += " · supply drop %s, %d s" % [AI.grid_ref(drops[0]["p"]), int(drops[0]["t"])]
			if boss != null and is_instance_valid(boss) and boss.state != "dead":
				extra += " · %s: %d%%" % [boss.sname, int(clampf(boss.hp / maxf(1.0, float(boss.get_meta("hp0", boss.hp))), 0.0, 1.0) * 100.0)]
			if not jobs.is_empty():
				extra += " · %d boarding up" % jobs.size()
			var dn = "" if diff() == 1 else " (%s)" % DIFF_NAMES[diff()].to_lower()
			if horde_endless:
				return "wave %d%s, endless (best %d) · %d coming%s" % [horde_wave, dn, horde_best(G.map_id), n + horde_left, extra]
			return "wave %d of %d%s · %d coming%s" % [horde_wave, HORDE_WIN, dn, n + horde_left, extra]
	return ""

# ---------------------------------------------------------------- the daily challenge
const DAILY_MAPS = ["town", "field", "trenches", "forest", "city", "factory", "office", "valley", "river", "pass", "front", "random"]
const DAILY_MODES = ["capture", "frontline", "escort", "rescue", "horde", "breakthrough", "siege", "general"]
const DAILY_PATH = "user://daily.dat"

static func today() -> String:
	var d = Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d["year"], d["month"], d["day"]]

static func daily_config() -> Dictionary:
	var key = today()
	var r = RandomNumberGenerator.new()
	r.seed = hash(key + "ragdoll-front")
	var mode = DAILY_MODES[r.randi() % DAILY_MODES.size()]
	var map = DAILY_MAPS[r.randi() % DAILY_MAPS.size()]
	if mode == "escort" and map in ["factory", "trenches", "office"]:
		map = "valley"
	var tod = ["day", "day", "dusk", "night", "dawn"][r.randi() % 5]
	var mods = []
	var armor = ["none", "light", "heavy"][r.randi() % 3]
	var size = [10, 15, 20, 30][r.randi() % 4]
	if r.randf() < 0.3:
		mods.append("veterans")
	if r.randf() < 0.25:
		mods.append("no reinforcements")
	return {"date": key, "map": map, "mode": mode, "time": tod, "armor": armor, "size": size, "mods": mods, "seed": r.randi()}

static func daily_text(c: Dictionary) -> String:
	var mn = G.world.MAPS.get(c["map"], {}).get("name", c["map"])
	var t = "%s · %s on %s, %s, %d a side, %s armour" % [c["date"], c["mode"].capitalize(), mn, c["time"], c["size"], c["armor"]]
	if not c["mods"].is_empty():
		t += " · " + ", ".join(c["mods"])
	var best = daily_best()
	if not best.is_empty():
		t += "\nYour best today: %s in %d:%02d with %d kills" % ["won" if best["won"] else "lost", int(best["time"]) / 60, int(best["time"]) % 60, best["kills"]]
	return t

static func start_daily() -> void:
	var c = daily_config()
	daily = c
	G.random_seed = c["seed"]
	var keep_t = G.settings["time"]
	G.settings["time"] = c["time"]
	G.main.apply_time()
	G.settings["time"] = keep_t
	Campaign.active = false
	G.main.start_game({"map": c["map"], "mode": c["mode"], "size": c["size"], "limit": G.default_limit(c["mode"]), "reinforce": not ("no reinforcements" in c["mods"]),
		"reinf_mode": "truck", "armor": c["armor"], "teams": 2})
	if "veterans" in c["mods"]:
		for s in G.soldiers:
			s.set_vet(2)
	G.ui.message("Daily challenge: " + daily_text(c).split("\n")[0])

static func daily_best() -> Dictionary:
	if not FileAccess.file_exists(DAILY_PATH):
		return {}
	var f = FileAccess.open(DAILY_PATH, FileAccess.READ)
	if f == null:
		return {}
	var d = f.get_var()
	if d is Dictionary and d.get("date", "") == today():
		return d
	return {}

static func daily_over(winner: int) -> String:
	if daily.is_empty():
		return ""
	var kills = 0
	for s in G.soldiers:
		if s.team == 0:
			kills += s.kills
	var res = {"date": daily["date"], "won": winner == 0, "time": G.game_time, "kills": kills}
	var best = daily_best()
	var better = best.is_empty() or (res["won"] and not best["won"]) or (res["won"] == best["won"] and (res["kills"] > best["kills"] if not res["won"] else res["time"] < best["time"]))
	if better:
		var f = FileAccess.open(DAILY_PATH, FileAccess.WRITE)
		if f != null:
			f.store_var(res)
	daily = {}
	return "Daily challenge %s · %d kills%s" % ["won" if res["won"] else "lost", kills, " · new best!" if better else ""]
