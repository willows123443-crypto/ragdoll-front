class_name Hive
# You are the horde. Two battles:
#
#   "attack": soldiers hold a building (the keep in a town, or the Ministry) and do what they do against
#   the dead in zombie mode: board up, buy guns with what your dead cost them, fall back upstairs. Kill
#   every one of them before the relief column arrives.
#
#   "defend": the hive stands in the open and an army comes for it, a bigger party each time, with
#   machine guns, shotguns, flamethrowers and grenade launchers as it goes on. Its heart is one of the
#   dead that cannot move: if they kill it you have lost; outlast every party and you have won.
#
# What you have: biomass (a little all the time, more for every man your dead bring down), which buys
# more of the dead by the pack; three orders for the whole horde (hunt, gather at a point and wait,
# go for a point); pits to come up out of nearer the enemy; and any one of the dead to be yourself.
#
# It is zombie mode underneath (G.mode stays "horde": the dead, the men's defence and everything they
# buy and build are that mode's own), with the waves switched off and this in their place.

static var on = ""                 # "", "attack" or "defend"
static var bio = 0.0
static var order = null            # for every one of the free dead: {"p": Vector3, "hold": bool}, or null = hunt
static var pits: Array = []        # [{"p": Vector3, "node": Node3D}]
static var hive_p = Vector3.ZERO
static var hive_k = 0              # the floor it is on, where the building has floors
static var alarm_t = 0.0
static var mound: Node3D = null
static var heart = null            # defend: the one that must not die
static var queue: Array = []       # kinds waiting to come up
static var q_t = 0.0
static var relief_t = 0.0          # attack: seconds until the relief column
static var wave = 0                # defend
static var wave_t = 0.0
static var waves = 8
static var men0 = 0
static var men_killed = 0
static var spawned = 0
static var lost = 0
static var free_t = 0.0
static var said = {}
static var t0 = 0.0
static var starting = false

const CAP = 90                     # the most of the dead up at once
# a pack: how many, what it costs
const PACKS = {
	"walker": {"n": 5, "cost": 8, "name": "Walkers"},
	"crawler": {"n": 4, "cost": 6, "name": "Crawlers"},
	"runner": {"n": 3, "cost": 10, "name": "Runners"},
	"spitter": {"n": 2, "cost": 10, "name": "Spitters"},
	"armored": {"n": 2, "cost": 12, "name": "Armoured"},
	"bloater": {"n": 1, "cost": 9, "name": "Bloater"},
	"brute": {"n": 1, "cost": 16, "name": "Brute"},
	"boss": {"n": 1, "cost": 60, "name": "Goliath"},
	"hurler": {"n": 1, "cost": 55, "name": "Hurler"},
	"mother": {"n": 1, "cost": 55, "name": "Brood mother"},
}
const PACK_TIPS = {
	"walker": "five of the ordinary dead", "crawler": "four, low and hard to hit", "runner": "three, fast: in among them before they can turn",
	"spitter": "two that hang back and spit", "armored": "two in plate: rifle rounds mostly glance off", "bloater": "one: bursts among them when it is put down",
	"brute": "one: goes through boards and barricades", "boss": "a giant: stamps flat what is near it", "hurler": "a giant: throws masonry from a distance",
	"mother": "a giant: drops runners as she comes",
}
const PIT_COST = 25

static func diff() -> int:
	return clampi(int(G.settings.get("horde_diff", 1)), 0, 2)

static func stop() -> void:
	on = ""
	order = null
	queue = []
	for p in pits:
		if is_instance_valid(p["node"]):
			p["node"].queue_free()
	pits = []
	if mound != null and is_instance_valid(mound):
		mound.queue_free()
	mound = null
	heart = null

static func start(kind: String, map: String) -> void:
	stop()
	starting = true
	G.main.start_game({"map": map, "mode": "horde", "size": ([12, 16, 22][diff()] if kind == "attack" else 4), "limit": 999, "reinforce": false, "armor": "none", "teams": 2})
	starting = false
	on = kind
	bio = 30.0 if kind == "attack" else 50.0
	hive_k = 0
	alarm_t = 0.0
	men_killed = 0
	spawned = 0
	lost = 0
	said = {}
	t0 = G.sim_time
	free_t = 4.0
	q_t = 0.0
	Modes.horde_t = 1e9
	Modes.horde_wave = 4
	Modes.horde_left = 0
	Modes.horde_side = -1
	G.pc.selection = []
	var W = G.world
	var c: Vector3 = W.capture
	var b: Rect2 = W.bounds
	if kind == "attack":
		Modes.auto_board = true
		Modes.auto_buy = true
		Support.points[0] = 30
		relief_t = [15.0, 13.0, 11.0][diff()] * 60.0
		# the hive: out at the edge, on the side with the most room
		var best = c
		var bd = -1.0
		for a in range(8):
			var dir = Vector3(cos(a * TAU / 8.0), 0, sin(a * TAU / 8.0))
			var q = c + dir * 95.0
			q.x = clampf(q.x, b.position.x + 14.0, b.end.x - 14.0)
			q.z = clampf(q.z, b.position.y + 14.0, b.end.y - 14.0)
			if G.dist2d(q, c) > bd and not W.solid_at(q.x, q.z, 3.0, W.ground_y(q.x, q.z)):
				bd = G.dist2d(q, c)
				best = q
		hive_p = G.main._free_spot(best)
		if not Levels.on:
			Modes.fall_back()
		# They have had time to get ready: the windows of the house they hold are boarded already (the
		# doors they do themselves, as you watch), and one man in five has a machine gun, one in six a
		# shotgun. (Without that, forty of the dead let go at once took the town's house in under two
		# minutes for thirty-two of their own.)
		var held: Vector3 = c
		if Levels.on:
			held = Vector3(Levels.rect.position.x + Levels.rect.size.x * 0.5, Levels.gy, Levels.rect.position.y + Levels.rect.size.y * 0.5)
		elif Modes.keep() >= 0:
			held = Modes.keep_pos()
		Modes.board_up(held)
		var mm = G.soldiers.filter(func(m): return m.team == 0 and not m.zombie and m.state == "alive")
		for i in range(mm.size()):
			if i % 5 == 1:
				mm[i].set_weapon("lmg")
			elif i % 6 == 3:
				mm[i].set_weapon("shotgun")
		free_t = 40.0
		for i in range(10):
			queue.append("walker")
		G.ui.message("You are the horde. %d soldiers hold the %s: kill every one of them before the relief column gets here, in %d minutes" % [G.alive_count(0), "Ministry" if Levels.on else "house in the middle of the town", int(relief_t / 60.0)])
	else:
		Modes.auto_board = false
		Modes.auto_buy = false
		Support.points[0] = 0
		waves = [6, 8, 10][diff()]
		wave = 0
		wave_t = 12.0
		# The hive is indoors where there is a big building to be in (the Ministry's ground floor): out
		# in the open the dead never reached a rifleman, seventy of them for none, and the heart was
		# dead in two minutes. Indoors they have to come in after it, round corners, at arm's length.
		# And on the top floor of it: on the ground floor they shot the dead round the heart through the
		# windows from outside, 144 of them for two soldiers. Up there the only way to it is the stairs.
		if Levels.on:
			hive_k = Levels.n - 1
			hive_p = Levels.spot_on(hive_k, Vector3(Levels.rect.position.x + Levels.rect.size.x * 0.5, Levels.floor_y(hive_k), Levels.rect.position.y + Levels.rect.size.y * 0.5), 6.0)
		else:
			hive_p = G.main._free_spot(c)
		# the first men on the field are the first party: they start at the edge like the rest
		var first = G.soldiers.filter(func(m): return m.team == 0 and not m.zombie)
		_send_party(first, randi() % 4)
		wave = 1
		wave_t = 70.0
		heart = Modes.spawn_zombie("boss", hive_p.x, hive_p.z)
		if heart != null:
			heart.move_to(hive_p)
			heart.set_meta("hive", true)
			heart.sname = "The heart of the hive"
			heart.hp = 6000.0 * [1.3, 1.0, 0.8][diff()]
			heart.set_meta("hp0", heart.hp)
			heart.zspeed = 0.0
			Modes.boss = heart
		for i in range(14):
			queue.append("walker")
		# (they start gathered round the heart: let go to hunt, they walk out into the rifles)
		order = {"p": hive_p, "hold": true, "t": G.sim_time}
		G.ui.message("You are the horde, and this is the hive. An army is coming for it, %d parties, each bigger than the last. Keep its heart alive" % waves)
	if not (kind == "defend" and Levels.on):
		hive_p.y = W.ground_y(hive_p.x, hive_p.z)
	_build_mound()
	men0 = G.alive_count(0)
	# the view: over the hive, looking at what it is after
	if G.player == null:
		var look = c if kind == "attack" else hive_p + Vector3(0, 0, -20.0)
		var from = hive_p + Vector3(0, 34.0, 30.0) if kind == "defend" else hive_p + (hive_p - c).normalized() * 18.0 + Vector3(0, 34.0, 0)
		var dv = look - from
		G.pc.free_pos = from
		G.pc.free_yaw = atan2(dv.x, dv.z)
		G.pc.free_pitch = atan2(dv.y, Vector2(dv.x, dv.z).length())
		G.pc.rts_focus = hive_p if kind == "defend" else hive_p.lerp(c, 0.3)
		G.pc.rts_dist = 55.0
		G.pc.rcam_ok = false
	G.ui._render_tools()

# ---- the hive to look at: a mound of flesh the dead come up out of (and a pit is a smaller one)
static func _flesh(parent: Node3D, r: float, at: Vector3, col: Color) -> void:
	var m = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = r
	sm.height = r * 1.5
	sm.radial_segments = 10
	sm.rings = 5
	m.mesh = sm
	m.material_override = VModel.mat(col)
	m.position = at
	parent.add_child(m)

static func _make_mound(p: Vector3, big: bool) -> Node3D:
	var n = Node3D.new()
	G.main.add_child(n)
	n.global_position = p
	var k = 1.0 if big else 0.45
	var rr = RandomNumberGenerator.new()
	rr.seed = int(p.x * 13.0 + p.z * 7.0)
	_flesh(n, 3.2 * k, Vector3(0, 0.3 * k, 0), Color(0.33, 0.13, 0.12))
	for i in range(11 if big else 6):
		var a = i * TAU / (11.0 if big else 6.0) + rr.randf() * 0.5
		var d = rr.randf_range(2.2, 4.4) * k
		_flesh(n, rr.randf_range(0.9, 1.8) * k, Vector3(cos(a) * d, rr.randf_range(0.0, 0.5) * k, sin(a) * d), Color(0.3 + rr.randf() * 0.12, 0.11 + rr.randf() * 0.05, 0.1 + rr.randf() * 0.05))
	# the mouths it opens by: dark hollows
	for i in range(3 if big else 1):
		var a2 = i * TAU / 3.0 + 0.6
		_flesh(n, 1.0 * k, Vector3(cos(a2) * 2.6 * k, 0.9 * k, sin(a2) * 2.6 * k), Color(0.07, 0.03, 0.03))
	return n

static func _build_mound() -> void:
	mound = _make_mound(hive_p, not (on == "defend" and Levels.on))

# ---- the economy
static func can(kind: String) -> bool:
	return PACKS.has(kind) and bio >= float(PACKS[kind]["cost"])

static func buy(kind: String) -> String:
	if not PACKS.has(kind):
		return ""
	var pk = PACKS[kind]
	if bio < float(pk["cost"]):
		return "Not enough biomass: %s costs %d and the hive has %d" % [str(pk["name"]).to_lower(), pk["cost"], int(bio)]
	if up() + queue.size() + int(pk["n"]) > CAP:
		return "The hive can keep no more than %d on their feet at once" % CAP
	if kind in ["boss", "hurler", "mother"]:
		for z in G.soldiers:
			if z.zombie and z.state != "dead" and z.has_meta("boss") and not z.has_meta("hive"):
				return "One giant at a time"
		if kind in queue or "boss" in queue or "hurler" in queue or "mother" in queue:
			return "One giant at a time"
	bio -= float(pk["cost"])
	for i in range(int(pk["n"])):
		queue.append(kind)
	return "%s coming up%s" % [pk["name"], "" if pits.is_empty() else " from the nearest pit"]

static func up() -> int:
	var n = 0
	for z in G.soldiers:
		if z.zombie and z.state != "dead" and not z.has_meta("hive"):
			n += 1
	return n

static func dig(p: Vector3) -> String:
	if bio < PIT_COST:
		return "Not enough biomass: a pit costs %d" % PIT_COST
	if pits.size() >= 4:
		return "Four pits is all the hive can feed"
	if Doors.building_at(p) >= 0 or (Levels.on and Levels.inside(p, 2.0)) or G.world.solid_at(p.x, p.z, 1.5, p.y):
		return "Not there: a pit needs open ground"
	for m in G.soldiers:
		if m.team == 0 and not m.zombie and m.state == "alive" and G.dist2d(m.pos, p) < 28.0:
			return "Too close to them: no nearer than 28 m to a living man"
	bio -= PIT_COST
	p.y = G.world.ground_y(p.x, p.z)
	pits.append({"p": p, "node": _make_mound(p, false)})
	G.audio.slam(p, 0.0)
	return "A pit opens. The dead come up from whichever pit is nearest where you send them"

# where the next of them comes up: the hive, or the pit nearest where the horde is being sent
static func _mouth() -> Vector3:
	if pits.is_empty():
		return hive_p
	var aim = hive_p
	if order != null:
		aim = order["p"]
	else:
		var n = 0
		var sum = Vector3.ZERO
		for m in G.soldiers:
			if m.team == 0 and not m.zombie and m.state == "alive":
				sum += m.pos
				n += 1
		if n > 0:
			aim = sum / n
	var best = hive_p
	var bd = G.dist2d(hive_p, aim)
	for p in pits:
		if G.dist2d(p["p"], aim) < bd:
			bd = G.dist2d(p["p"], aim)
			best = p["p"]
	return best

static func man_lost(_s) -> void:
	if on == "":
		return
	men_killed += 1
	bio += 8.0 if on == "attack" else 10.0

static func dead_lost(_z) -> void:
	if on != "":
		lost += 1

# ---- orders for the whole horde
static func hunt() -> String:
	order = null
	G.audio.radio_click()
	return "The horde hunts: each of them goes for the nearest of the living"

static func rally(p: Vector3, hold: bool) -> String:
	order = {"p": p, "hold": hold, "t": G.sim_time}
	G.fx.order_marker(p)
	return "The horde gathers there and waits" if hold else "The horde goes for that place, and hunts from there"

# Called from the zombie brain each tick, after it has chosen who it would go for. True: this has moved
# it and the brain is done for the tick. One of the living within reach of it and it fights as it
# always does.
static func obey(s, t) -> bool:
	if order == null or s.has_meta("boss") and s.has_meta("hive"):
		return false
	if s.lunge_t > 0.0 or s.zhold != null or s.zfeed_t > 0.0 or s.is_player:
		return false
	if not order["hold"] and s.has_meta("hv_done") and int(s.get_meta("hv_done")) == int(float(order["t"]) * 10.0):
		return false
	if t != null and is_instance_valid(t) and t.state != "dead":
		# (Waiting, it goes for any man it can see within forty metres, or any at all within five, or
		# whoever has just hit it: gather them out of sight. It used to wait for five metres whatever it
		# could see, and then for fourteen: soldiers at the far end of a corridor shot 149 of them round
		# the heart without losing a man.)
		var dt2 = G.dist2d(t.pos, s.pos)
		if absf(t.pos.y - s.pos.y) < 1.7:
			if dt2 < 5.0 or (not order["hold"] and dt2 < 10.0) or s.zhit_t > 0.0:
				return false
			if dt2 < 40.0 and not G.blocked(s.head_pos(), t.chest()):
				alarm_t = G.sim_time + 6.0
				return false
	# (one of them has seen one of the living: for the next six seconds they all go, not just the ones
	# with a line to him. Let go one doorway's worth at a time, 65 of them lost 36 to six riflemen and
	# killed none.)
	if order["hold"] and G.sim_time < alarm_t and t != null and is_instance_valid(t) and t.state != "dead" and G.dist2d(s.pos, order["p"]) < 35.0:
		return false
	var gp: Vector3 = order["p"]
	var dd = G.dist2d(s.pos, gp)
	# (they stand round the place, not on it: the bigger the crowd the wider)
	var slack = 3.0 + float(s.id % 7) * 0.9
	if dd < slack and absf(gp.y - s.pos.y) < 2.0:
		AI.stop_move(s)
		s.want = Vector3.ZERO
		if not order["hold"]:
			s.set_meta("hv_done", int(float(order["t"]) * 10.0))
		return true
	var spd: float = s.zspeed * (0.4 if s.zhit_t > 0.0 else 1.0)
	if s.route == null and (s.move_target == null or G.dist2d(s.move_target, gp) > 4.0):
		AI.route_to(s, gp, spd)
	if s.route != null and not (s.route["i"] == 0 and s.route["nav"]):
		AI.follow_route(s)
	else:
		var res = AI.follow_path(s)
		if res == "arrived" and s.route != null and G.dist2d(s.pos, s.route["pts"][0]) < 1.0:
			s.route["i"] = 1
		elif res == "stuck":
			# something in the way of where it was sent: boards come off, a low wall is climbed
			if G.sim_time > float(s.get_meta("tear_t", 0.0)):
				s.set_meta("tear_t", G.sim_time + 1.0)
				if not Modes._tear(s, 1.6) and not Modes._over_wall(s):
					s.move_target = null
	var v = G.flat(s.vel)
	if v.length() > 0.3:
		s.aim_yaw = G.turn_to(s.aim_yaw, atan2(v.x, v.z), 4.0 * G.DT)
	s.aim_pitch = 0.0
	return true

# ---- being one of them: W A S D, Shift to break into a run, the mouse button to claw, F to tear at boards
static func player_zombie(s, cam_yaw: float, mouse_down: bool) -> void:
	var f = Vector3(sin(cam_yaw), 0, cos(cam_yaw))
	var r = Vector3(-cos(cam_yaw), 0, sin(cam_yaw))
	var m = Vector3.ZERO
	if Keys.held(KEY_W): m += f
	if Keys.held(KEY_S): m -= f
	if Keys.held(KEY_D): m += r
	if Keys.held(KEY_A): m -= r
	var sp: float = maxf(s.zspeed, 2.4) * (1.5 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	if s.zhit_t > 0.0:
		sp *= 0.5
	s.ready_ = false
	s.ads = false
	s.crouch_t = 0.12 if s.ztype != "brute" else 0.0
	s.prone_t = s.ztype == "crawler" and not s.has_meta("risen")
	s.aim_yaw = G.turn_to(s.aim_yaw, cam_yaw, 8.0 * G.DT)
	s.aim_pitch = 0.0
	s.melee_t -= G.DT
	if s.lunge_t > 0.0:
		s.lunge_t -= G.DT
		s.want = f * minf(sp * 1.6, 6.5)
		if s.lunge_t <= 0.25 and not s.has_meta("pz_hit"):
			s.set_meta("pz_hit", true)
			var t = _in_reach(s, f, 2.4 if not s.has_meta("boss") else 3.4)
			if t != null:
				Modes._claw(s, t)
			elif s.ztype == "brute":
				Modes._smash(s, 1.8, 230.0 if not s.has_meta("boss") else 700.0)
		return
	s.want = m.normalized() * sp if m.length_squared() > 0.0 else Vector3.ZERO
	if mouse_down and s.melee_t <= 0.0:
		s.lunge_t = 0.5 if s.ztype != "brute" else 0.7
		s.lunge_dir = f
		s.melee_t = 1.0 if s.ztype != "brute" else 1.4
		if s.has_meta("pz_hit"):
			s.remove_meta("pz_hit")
		G.audio.groan(s.pos, "snarl")
	if Keys.held(KEY_F) and G.sim_time > float(s.get_meta("tear_t", 0.0)):
		s.set_meta("tear_t", G.sim_time + 0.8)
		if not Modes._tear(s, 2.2) and s.ztype == "brute":
			Modes._smash(s, 1.8, 230.0)

static func _in_reach(s, f: Vector3, reach: float):
	var best = null
	var bd = reach
	for o in G.soldiers:
		if o.team == s.team or o.state == "dead" or o.vehicle != null:
			continue
		var v = G.flat(o.pos - s.pos)
		var d = v.length()
		if d < bd and absf(o.pos.y - s.pos.y) < 1.6 and (d < 0.6 or v.normalized().dot(f) > 0.35):
			bd = d
			best = o
	return best

# ---- the parties that come for the hive
const SIDE_NAMES = ["west", "east", "north", "south"]

static func _edge(side: int, k: float) -> Vector3:
	var b: Rect2 = G.world.bounds
	var p: Vector3
	match side:
		0: p = Vector3(b.position.x + 14.0, 0, lerpf(b.position.y + 20.0, b.end.y - 20.0, k))
		1: p = Vector3(b.end.x - 14.0, 0, lerpf(b.position.y + 20.0, b.end.y - 20.0, k))
		2: p = Vector3(lerpf(b.position.x + 20.0, b.end.x - 20.0, k), 0, b.position.y + 14.0)
		_: p = Vector3(lerpf(b.position.x + 20.0, b.end.x - 20.0, k), 0, b.end.y - 14.0)
	# (no further out than 130 m: a party should arrive, not hike)
	p = hive_p + (p - hive_p).limit_length(130.0)
	return p

# how near the hive each stops to shoot, by what he carries
static func _stand(wid: String) -> float:
	return float({"flamer": 8.0, "shotgun": 12.0, "smg": 14.0, "lmg": 20.0, "gl": 30.0, "rpg": 30.0}.get(wid, 17.0))

static func _send_party(men: Array, side: int) -> void:
	var mid = _edge(side, randf_range(0.3, 0.7))
	var along = Vector3(0, 0, 1) if side < 2 else Vector3(1, 0, 0)
	for i in range(men.size()):
		var m = men[i]
		if not is_instance_valid(m):
			continue
		var q: Vector3 = G.main._free_spot(mid + along * (i - men.size() * 0.5) * 2.2)
		m.move_to(Vector3(q.x, G.world.ground_y(q.x, q.z), q.z))
		_assault_order(m)

static func _assault_order(m) -> void:
	var back = G.flat(m.pos - hive_p)
	if back.length() < 1.0:
		back = Vector3(1, 0, 0)
	var p = hive_p + back.normalized().rotated(Vector3.UP, randf_range(-0.35, 0.35)) * _stand(m.wid)
	var ord = {"mode": "move", "point": p, "tag": "assault"}
	if Levels.on:
		# indoors: a place on the hive's own floor that he can see the heart from, as near his side of
		# it as there is one
		var best = Levels.spot_on(hive_k, hive_p, 8.0)
		var bd = 1e9
		for i in range(10):
			var q: Vector3 = Levels.spot_on(hive_k, hive_p + back.normalized().rotated(Vector3.UP, randf_range(-1.2, 1.2)) * randf_range(5.0, 15.0), 1.5)
			if G.dist2d(q, hive_p) < 3.5 or G.blocked(q + Vector3(0, 1.4, 0), hive_p + Vector3(0, 1.6, 0)):
				continue
			var d = G.dist2d(q, m.pos)
			if d < bd:
				bd = d
				best = q
		ord["point"] = best
		ord["in"] = Levels.bi
	else:
		ord["point"] = G.main._free_spot(p)
	m.order = ord
	m.decide_t = 0.0

static func _next_party() -> void:
	wave += 1
	# (Small parties, one more man each time. At 8, 11, 14 and so on with the next due whether or not
	# the last was dealt with, there were 83 soldiers in the building by the ninth minute, and the dead
	# were losing twenty-seven for every one of them.)
	var n = int(round((3.0 + wave) * [0.8, 1.0, 1.25][diff()]))
	var side = randi() % 4
	var men = []
	var mid = _edge(side, 0.5)
	for i in range(n):
		var wid = "rifle"
		if wave >= 2 and i % 5 == 1:
			wid = "lmg"
		elif wave >= 3 and i % 6 == 3:
			wid = "shotgun"
		elif wave >= 4 and i % 9 == 4:
			wid = "flamer"
		elif wave >= 5 and i % 10 == 7:
			wid = "gl"
		elif wave >= 3 and i % 11 == 9:
			wid = "smg"
		var s = G.main.spawn_soldier(0, mid.x + randf_range(-3, 3), mid.z + randf_range(-3, 3), wid)
		if s != null:
			men.append(s)
	_send_party(men, side)
	men0 += men.size()
	G.ui.message("Party %d of %d: %d of them, from the %s" % [wave, waves, men.size(), SIDE_NAMES[side]])
	G.audio.radio_click()

# ---- every tick (called from the zombie mode's own step, in place of its waves)
static func step(dt: float) -> void:
	if on == "" or G.over:
		return
	Modes.horde_t = 1e9
	if not G.pc.selection.is_empty():
		G.pc.selection = []            # (the living are not yours to give orders to)
	# (the hive is under a roof: start with its own floor showing, not the top of the building)
	if on == "defend" and Levels.on and not said.has("floor") and G.ui.floor_view != null:
		said["floor"] = true
		G.ui.floor_view.pick(hive_k)
	# biomass: a little all the time
	# (Attacking: enough for a dozen walkers a minute. At twice that, fifty of the dead were at the
	# Ministry's doors in the first minute and all sixteen men in it were dead in the second.)
	bio += dt * (0.3 if on == "attack" else 0.5)
	# the dead come up one at a time
	q_t -= dt
	if q_t <= 0.0 and not queue.is_empty() and up() < CAP:
		q_t = 0.45
		var kind: String = queue.pop_front()
		var mp = _mouth()
		var a = randf() * TAU
		var q: Vector3 = mp + Vector3(cos(a), 0, sin(a)) * randf_range(2.5, 5.0) * (1.0 if mp == hive_p else 0.5)
		if Levels.on and mp == hive_p and hive_k > 0:
			q = Levels.spot_on(hive_k, q, 1.5)
		var z = Modes.spawn_zombie(kind, q.x, q.z)
		if z != null:
			if Levels.on and mp == hive_p and hive_k > 0:
				z.move_to(q)
			spawned += 1
			z.fall(0.7)                # (it comes up out of the ground and gets to its feet)
			if Modes.BOSS_SIZE.has(kind):
				Modes.boss = z if heart == null else Modes.boss
				G.ui.message("%s is up" % str(PACKS[kind]["name"]))
	# and the hive puts out one of its own every few seconds while it is short of them
	free_t -= dt
	if free_t <= 0.0:
		free_t = 12.0 if on == "attack" else 6.0
		if up() + queue.size() < (8 if on == "attack" else 12):
			queue.append("walker")
	var men = G.alive_count(0)
	if on == "attack":
		relief_t -= dt
		if men == 0:
			G.ui.message("Nobody left alive in there. The building is yours")
			G.main.end_game(1)
			return
		if relief_t <= 0.0:
			G.ui.message("The relief column is here. %d of them were still alive" % men)
			G.main.end_game(0)
			return
		for mark in [300.0, 120.0, 60.0]:
			if relief_t < mark and not said.has(mark):
				said[mark] = true
				G.ui.message("The relief column is %d minute%s off, and %d of them are still alive" % [int(mark / 60.0), "" if mark == 60.0 else "s", men])
	else:
		if heart == null or not is_instance_valid(heart) or heart.state == "dead":
			G.ui.message("The heart of the hive is dead")
			G.main.end_game(0)
			return
		# the men of a party go on to the hive when they have dealt with what was in front of them
		wave_t -= dt
		if wave >= waves and men == 0:
			G.ui.message("That was the last of them. The hive feeds")
			G.main.end_game(1)
			return
		if wave < waves and (wave_t <= 0.0 or (men <= 1 and wave_t < 100.0)):
			wave_t = 120.0
			_next_party()
		# A man not yet on the hive's floor makes for the stairs and nothing else (the order the men use
		# to fall back up them: it is the one that knows the way between floors); once he is on it he
		# fights his way to his place like anyone. And a man who has lost his order gets it again.
		if Engine.get_physics_frames() % 30 == 0:
			for m in G.soldiers:
				if m.team != 0 or m.zombie or m.state != "alive" or m.is_player:
					continue
				var tg = str(m.order.get("tag", "")) if m.order != null else ""
				if tg != "assault" and tg != "fallback":
					_assault_order(m)
					tg = "assault"
				if Levels.on and hive_k > 0:
					var here = Levels.inside(m.pos, 0.0) and Levels.storey_of(m.pos) == hive_k
					if here and tg == "fallback":
						m.order["tag"] = "assault"
						m.decide_t = 0.0
					elif not here and tg == "assault":
						m.order["tag"] = "fallback"
						m.decide_t = 0.0

static func status() -> String:
	if on == "attack":
		return "biomass %d · the dead %d · %d of %d soldiers left · relief in %d:%02d" % [int(bio), up(), G.alive_count(0), men0, int(relief_t) / 60, int(relief_t) % 60]
	if on == "defend":
		var hp = 0.0
		if heart != null and is_instance_valid(heart):
			hp = clampf(heart.hp / maxf(1.0, float(heart.get_meta("hp0", heart.hp))), 0.0, 1.0)
		return "biomass %d · the dead %d · party %d of %d, %d soldiers on the field · the heart %d%%" % [int(bio), up(), wave, waves, G.alive_count(0), int(hp * 100.0)]
	return ""

static func win_text(team: int) -> String:
	if on == "attack":
		return "The building is yours" if team == 1 else "The relief column got through"
	return "The hive feeds" if team == 1 else "The hive is dead"
