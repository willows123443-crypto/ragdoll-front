class_name Salvage
extends RefCounted
# Wrecked and abandoned vehicles left lying about the map from earlier fighting. They belong to nobody:
# whichever side gets a man to one first can patch it up enough to run, climb in and take it.

static var wrecks: Array = []
static var claimed = 0

static func reset() -> void:
	wrecks = []
	claimed = 0

# a couple of derelicts out in the middle ground at the start of a battle
static func place(n: int) -> void:
	var W = G.world
	if W == null or G.mode in ["horde", "laststand", "commander", "sandbox", "escort"]:
		return
	var a: Vector3 = W.rally_point(0)
	var b: Vector3 = W.rally_point(1) if G.team_count() > 1 else W.capture
	var kinds = ["jeep", "truck", "technical", "halftrack", "jeep", "armoredcar"]
	if G.armor == "heavy":
		kinds.append("tank")
	var tries = 0
	while wrecks.size() < n and tries < 40:
		tries += 1
		var t = randf_range(0.3, 0.7)
		var side = G.flat(b - a).normalized().cross(Vector3.UP)
		var p = a.lerp(b, t) + side * randf_range(-45.0, 45.0)
		p = G.main._free_spot(p)
		if W.inside_any(p.x, p.z, 3.5) or W.in_water(p.x, p.z) or G.dist2d(p, W.capture) < 14.0:
			continue
		var far = true
		for w in wrecks:
			if is_instance_valid(w) and G.dist2d(w.pos, p) < 30.0:
				far = false
		if not far:
			continue
		var kind: String = kinds[randi() % kinds.size()]
		var v = G.main.spawn_vehicle(Faction.vehicle_kind(randi() % 2, kind), 0, p, randf() * TAU, false)
		if v == null:
			continue
		make_derelict(v)

static func make_derelict(v) -> void:
	v.team = -1
	v.set_meta("derelict", true)
	v.hp = v.spec["hp"] * randf_range(0.22, 0.4)
	if v.spec["tracked"] and randf() < 0.6:
		v.tracks_broken = true
	wrecks.append(v)

static func claim(v, team: int) -> void:
	claimed += 1
	v.team = team
	v.remove_meta("derelict")
	wrecks.erase(v)
	G.ui.radio(team, "We've got the abandoned %s running" % v.spec["name"].to_lower())

# patched up enough to drive: it takes a man a little while with his tools
const WORK = 9.0

# about once a second: men near a derelict who aren't fighting go over and get it going
static func step() -> void:
	for i in range(wrecks.size() - 1, -1, -1):
		var v = wrecks[i]
		if not is_instance_valid(v) or v.dead or v.team >= 0:
			wrecks.remove_at(i)
			continue
		var by = v.get_meta("salvor") if v.has_meta("salvor") else null
		if by != null and (not is_instance_valid(by) or by.state != "alive" or by.task != "salvage"):
			v.remove_meta("salvor")
			by = null
		if by != null:
			continue
		# whoever's nearest and not busy fighting goes for it
		var best = null
		var bd = 55.0
		for o in G.soldiers:
			if o.state != "alive" or o.is_player or o.vehicle != null or o.vis_t != null or o.broken or o.zombie:
				continue
			if o.order != null or ClassAI.busy(o) or o.task in ["stretcher", "get_radio", "charge", "medic", "board", "salvage", "post", "scout", "clear", "flank_move"]:
				continue
			# (a scout has his own errand, and it kept calling him back from the wreck: he went to and fro
			# between the two; snipers and spotters aren't sent either)
			if o.has_meta("scout") or o.cls == "sniper" or o.cls == "spotter":
				continue
			var d = G.dist2d(o.pos, v.pos) - (12.0 if o.cls == "engineer" else 0.0)
			if d < bd:
				bd = d
				best = o
		if best != null:
			v.set_meta("salvor", best)
			AI.release_cover(best)
			best.task = "salvage"
			best.board_target = v
			AI.go_to(best, v.pos, 4.6)
			G.fx.callout(best, G.pick(["There's an abandoned %s, I'll get it going!" % v.spec["name"].to_lower(), "Cover me, that wreck might still run!"]))

# the man working on it (every tick, from ClassAI): hammering at the engine and the running gear
static func work(s) -> void:
	var v = s.board_target
	if v == null or not (v is Vehicle) or not is_instance_valid(v) or v.dead or v.team >= 0:
		s.task = null
		s.board_target = null
		s.decide_t = 0.0
		return
	if G.dist2d(v.pos, s.pos) < maxf(v.spec["len"], v.spec["wid"]) * 0.5 + 1.6:
		AI.stop_move(s)
		s.crouch_t = 0.6
		s.hand_t = v.center() + Vector3(0, -0.3, 0)
		s.aim_yaw = G.turn_to(s.aim_yaw, atan2(v.pos.x - s.pos.x, v.pos.z - s.pos.z), 4.0 * G.DT)
		var w = v.get_meta("work", 0.0) + G.DT * (1.6 if s.cls == "engineer" else 1.0)
		v.set_meta("work", w)
		if randf() < 0.05:
			G.fx.impact(v.center() + Vector3(randf_range(-1, 1), -0.3, randf_range(-1, 1)), Vector3.UP)
		if w >= WORK:
			v.hp = maxf(v.hp, v.spec["hp"] * 0.55)
			v.tracks_broken = false
			v.burning = false
			if v.has_meta("salvor"):
				v.remove_meta("salvor")
			s.task = null
			s.board_target = null
			var si = v.free_seat("driver")
			if si < 0 or not s.mount(v, si):
				claim(v, s.team)
			G.fx.callout(s, G.pick(["She runs! Get in!", "Got it going!", "That'll do, she'll drive!"]))
	elif s.move_target == null:
		AI.go_to(s, v.pos, 4.6)
