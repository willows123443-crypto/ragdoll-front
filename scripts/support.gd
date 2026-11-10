class_name Support
extends RefCounted
# Supply points and call-ins. Sides earn points over time, for kills and for taking objectives,
# and spend them on vehicles, air strikes, artillery, gunships and airborne troops.
# The player spends Alpha's points from the Support tab; AI commanders spend for their own side.

const COSTS = {
	"artillery": 10, "airstrike": 16, "paradrop": 12, "heli": 16,
	"jeep": 8, "motorbike": 6, "halftrack": 14, "armoredcar": 20, "tank": 30, "gunship": 34,
	"fighter": 22, "bomber": 28, "bridger": 14, "radar": 18, "ambulance": 8,
}
const NAMES = {
	"artillery": "Artillery barrage", "airstrike": "Air strike", "paradrop": "Paratroopers", "heli": "Helicopter insertion",
	"jeep": "Jeep", "motorbike": "Motorbike", "halftrack": "Half-track", "armoredcar": "Armoured car", "tank": "Tank", "gunship": "Gunship (70 s)",
	"fighter": "Fighter (90 s)", "bomber": "Dive bomber (90 s)", "bridger": "Bridge layer", "radar": "Command truck", "ambulance": "Ambulance",
}

static var points: Array = []
static var trickle = 0.0
static var ai_t: Array = []
static var planes: Array = []

static func reset() -> void:
	points = []
	ai_t = []
	for t in range(G.team_count()):
		points.append(10)
		ai_t.append(randf_range(20.0, 40.0))
	trickle = 0.0
	for p in planes:
		if is_instance_valid(p["node"]):
			p["node"].queue_free()
	planes = []

static func earn(team: int, n: int) -> void:
	if team >= 0 and team < points.size():
		points[team] += n

static func step(dt: float) -> void:
	_step_planes(dt)
	if G.over or points.is_empty():
		return
	trickle += dt
	if trickle >= 6.0:
		trickle = 0.0
		for t in range(points.size()):
			points[t] += 2 if (G.mode == "commander" and t == 0) else 1
	# AI sides spend what they have
	for t in range(points.size()):
		if t == 0 and (G.player != null or G.mode == "commander"):
			continue
		if t == 1 and G.mode == "horde":
			continue
		ai_t[t] -= dt
		if ai_t[t] > 0.0:
			continue
		ai_t[t] = randf_range(25.0, 45.0)
		_ai_spend(t)

static func _ai_spend(t: int) -> void:
	var opts = []
	var tgt = ClassAI.artillery_target(t, G.world.spawn[t], 30.0)
	if tgt != null:
		opts.append("artillery")
		opts.append("airstrike")
	var veh = 0
	for v in G.vehicles:
		if v.team == t and not v.dead and not v.spec.get("static", false):
			veh += 1
	if veh < 3 and G.armor != "none":
		opts.append_array(["jeep", "halftrack", "armoredcar", "motorbike"])
		if G.armor == "heavy":
			opts.append_array(["tank", "gunship"])
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
	var broken_bridge = false
	for b in G.world.bridges:
		if not b[5].alive:
			broken_bridge = true
	if broken_bridge and G.armor != "none":
		opts.append("bridger")
	opts = opts.filter(func(o): return COSTS[o] <= points[t])
	if opts.is_empty():
		return
	var pick = G.pick(opts)
	call_in(t, pick, tgt if tgt != null else G.world.capture)

static func can_afford(team: int, what: String) -> bool:
	return points[team] >= COSTS[what]

static func call_in(team: int, what: String, target: Vector3) -> bool:
	if points.is_empty() or points[team] < COSTS[what]:
		return false
	if G.mode == "sabotage" and team == 0 and what in ["paradrop", "heli", "jeep", "halftrack", "armoredcar", "tank", "motorbike"]:
		return false      # the raiders are on their own
	points[team] -= COSTS[what]
	match what:
		"artillery":
			for i in range(8):
				Combat.shell_at(target, 12.0, 5.0 + i * randf_range(0.4, 0.9), null, 1.6)
			G.ui.radio(team, "Artillery barrage on %s, splash in five" % AI.grid_ref(target))
		"airstrike":
			_air_strike(team, target)
			G.ui.radio(team, "Air strike inbound on %s" % AI.grid_ref(target))
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
			# ground vehicles drive in from the team's edge of the map
			var e2 = Reinforce.entry_point(team)
			var r: Vector3 = G.world.rally_point(team)
			G.main.spawn_vehicle(what, team, e2, atan2(r.x - e2.x, r.z - e2.z))
			G.ui.radio(team, "%s inbound from the rear" % NAMES[what])
	return true

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
