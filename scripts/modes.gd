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

static func reset() -> void:
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
	horde_left = 0
	horde_t = 10.0
	horde_spawn_t = 0.0
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
static func _horde(dt: float) -> void:
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
		return
	if horde_wave >= HORDE_WIN:
		G.main.end_game(0)
		return
	horde_t -= dt
	if horde_t > 0.0:
		return
	horde_wave += 1
	horde_left = 10 + horde_wave * 8 + G.team_size
	horde_t = 14.0
	var fresh = G.team_size - G.alive_count(0)
	for i in range(maxi(0, fresh)):
		G.main.base_spawn(0)
	G.ui.message("Wave %d: %d of them" % [horde_wave, horde_left])

static func _spawn_pack(n: int) -> void:
	var W = G.world
	var b: Rect2 = W.bounds
	var c = G.world.capture
	var p = Vector3.ZERO
	# somewhere on the edge of the map, not right on top of anyone
	for k in range(10):
		var side = randi() % 4
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
		Soldier.zombie_next = kind
		var z = G.main.spawn_soldier(1, q.x, q.z, "pistol")
		Soldier.zombie_next = ""
		if z != null:
			make_zombie(z, kind)

# later waves bring more of the fast and the big ones
static func _pick_type() -> String:
	var r = randf()
	var w = float(horde_wave)
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
}

static func make_zombie(z, kind: String = "walker") -> void:
	var zs = ZOMBIES[kind]
	z.zombie = true
	z.ztype = kind
	z.grenades = 0
	z.smokes = 0
	z.satchels = 0
	z.rgren = 0
	z.gun_node.visible = false
	z.hp = zs["hp"] + horde_wave * zs["hpw"]
	z.zspeed = randf_range(zs["speed"][0], zs["speed"][1])
	z.think = randf_range(0.0, 0.6)
	z.groan_t = randf_range(0.5, 6.0)
	z.sname = zs["name"]
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
	s.crouch_t = 0.12 if s.ztype != "brute" else 0.0
	s.prone_t = s.ztype == "crawler"
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
	var d = to.length()
	var yaw = atan2(to.x, to.z)
	s.aim_yaw = G.turn_to(s.aim_yaw, yaw, 3.0 * G.DT)
	s.aim_pitch = 0.0
	var spd: float = s.zspeed
	var reach = 1.0 if s.ztype == "crawler" else 1.25
	# the attack: a short wind-up, a lunge and a bite
	if s.lunge_t > 0.0:
		s.lunge_t -= G.DT
		AI.stop_move(s)
		if s.lunge_t > 0.3:
			s.want = Vector3.ZERO
		else:
			s.want = s.lunge_dir * (minf(spd * 1.9, 6.5) / s.W["speed"]) if s.ztype != "crawler" else s.lunge_dir * 0.6
			if s.melee_t <= 0.0 and d < reach:
				s.melee_t = 1.1 if s.ztype != "brute" else 1.5
				_claw(s, t)
		if s.lunge_t <= 0.0:
			s.melee_t = maxf(s.melee_t, 0.5)
		return
	s.melee_t -= G.DT
	if d < (2.4 if s.ztype != "crawler" else 1.4) and s.melee_t <= 0.0:
		s.lunge_t = 0.55 if s.ztype != "runner" else 0.42
		s.lunge_dir = to / maxf(d, 0.01)
		s.melee_t = 0.0
		G.audio.groan(s.pos, "snarl")
		return
	if d < 1.1:
		AI.stop_move(s)
		s.want = Vector3.ZERO
		return
	if s.bad_t < G.sim_time and (d < 7.0 or (d < 30.0 and not G.blocked(s.pos + Vector3(0, 1.0, 0), t.pos + Vector3(0, 1.0, 0)))):
		AI.stop_move(s)
		var dir = to / d
		# slide round posts and corners rather than pushing into them
		if G.world.solid_at(s.pos.x + dir.x * 0.6, s.pos.z + dir.z * 0.6, 0.22, s.pos.y) and not _vaultable_ahead(s, dir):
			for ang in [0.6, -0.6, 1.1, -1.1]:
				var nd = dir.rotated(Vector3.UP, ang)
				if not G.world.solid_at(s.pos.x + nd.x * 0.6, s.pos.z + nd.z * 0.6, 0.22, s.pos.y):
					dir = nd
					break
		# a lurching walk: speed surges and sags
		var surge = 1.0 if s.ztype == "runner" else 0.75 + 0.35 * absf(sin(G.sim_time * 1.6 + s.seed_))
		s.want = dir * (spd * surge / s.W["speed"])
		# not getting anywhere (a wall, a fence, a crowd)? find a way round for a while
		s.prog_t += G.DT
		if s.prog_t > 1.5:
			if G.dist2d(s.pos, s.prog_p) < 0.6 and s.vault == null:
				s.bad_t = G.sim_time + 6.0
				AI.go_to(s, t.pos, spd)
			s.prog_t = 0.0
			s.prog_p = s.pos
	else:
		if s.move_target == null or G.dist2d(s.move_target, t.pos) > 4.0:
			AI.go_to(s, t.pos, spd)
		if s.route != null and not (s.route["i"] == 0 and s.route["nav"]):
			AI.follow_route(s)
		else:
			var res = AI.follow_path(s)
			if res == "stuck" or res == "arrived":
				AI.stop_move(s)

static func _vaultable_ahead(s, dir: Vector3) -> bool:
	for c in G.world.cell_at(s.pos.x + dir.x * 0.7, s.pos.z + dir.z * 0.7):
		if G.world.vaultable(c):
			return true
	return false

static func _claw(z, t) -> void:
	var zr = ZOMBIES.get(z.ztype, ZOMBIES["walker"])["dmg"]
	var dmg = randf_range(zr[0], zr[1])
	t.hp -= dmg
	t.last_attacker = z
	G.fx.bleed(t.chest(), G.flat(t.pos - z.pos).normalized(), false)
	G.audio.play(G.audio.s_hit, t.chest(), -4.0, 0.6)
	if t.is_player:
		Combat.shake = maxf(Combat.shake, 0.35)
	if t.hp <= 0.0:
		Combat.kill(t, z, false)
	elif t.state == "alive" and (z.ztype == "brute" or randf() < 0.2):
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
			return "wave %d of %d · %d coming" % [horde_wave, HORDE_WIN, n + horde_left]
	return ""

# ---------------------------------------------------------------- the daily challenge
const DAILY_MAPS = ["town", "field", "trenches", "forest", "city", "factory", "valley", "river", "pass", "front", "random"]
const DAILY_MODES = ["capture", "frontline", "laststand", "destroy", "escort", "rescue", "koth", "horde", "breakthrough", "siege", "general"]
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
	if mode == "escort" and map in ["factory", "trenches"]:
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
