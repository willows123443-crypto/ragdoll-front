class_name Ferry
extends RefCounted
# Assault boats on rivers: each side keeps a couple of small boats at its own bank. Soldiers
# whose objective lies across the water pile in, the boat runs them over, drops them in the
# shallows on the far side, and comes back for more.

static var boats: Array = []      # {"v", "home", "far", "load_t"}

static func reset() -> void:
	boats = []

# the river map has a north-south river through x = 0
static func setup() -> void:
	reset()
	if G.map_id != "river" or G.team_count() != 2 or G.mode == "horde":
		return
	for t in range(2):
		var side = signf(G.world.spawn[t].x)
		if side == 0.0:
			continue
		for z in ([-36.0, 104.0] if t == 0 else [36.0, -104.0]):
			spawn_boat(t, z, side)

static func _river_x(z: float) -> float:
	return sin(z * 0.02) * 6.0

static func spawn_boat(t: int, z: float, side: float) -> void:
	var cx = _river_x(z)
	var home = Vector3(cx + side * 8.3, 0, z)
	var far = Vector3(cx - side * 8.3, 0, z + randf_range(-6.0, 6.0))
	var v = G.main.spawn_vehicle("dinghy", t, home, -side * PI / 2.0, true)
	v.mission = {"type": "ferry", "stage": 0}
	boats.append({"v": v, "home": home, "far": far, "load_t": 0.0, "side": side})

static func step(dt: float) -> void:
	for b in boats:
		var v = b["v"]
		if not is_instance_valid(v) or v.dead:
			continue
		if v.mission == null or v.mission.get("type", "") != "ferry":
			continue
		if v.mission["stage"] == 0:
			b["load_t"] += dt
			_recruit(b)

# who's going across? anyone near this bank whose objective is on the other side
static func _recruit(b: Dictionary) -> void:
	var v = b["v"]
	if Engine.get_physics_frames() % 30 != 0:
		return
	var side: float = b["side"]
	var free = 0
	for i in range(1, v.seats.size()):
		if v.seats[i] == null:
			free += 1
	if free == 0:
		return
	var heading = 0
	for s in G.soldiers:
		if s.task == "board" and s.board_target == v:
			heading += 1
	for s in G.soldiers:
		if heading >= free:
			break
		if s.team != v.team or s.state != "alive" or s.is_player or s.vehicle != null or s.task in ["board", "medic", "build", "carry"]:
			continue
		if s.vis_t != null or s.dragging != null or s.carrying != null or s.cls in ["engineer"] and s.build_site != null:
			continue
		if G.dist2d(s.pos, b["home"]) > 60.0:
			continue
		var obj: Vector3 = AI.objective_for(s)
		var odx = obj.x - _river_x(obj.z)
		if signf(odx) == side and absf(odx) > 12.0:
			continue
		if signf(s.pos.x - _river_x(s.pos.z)) != side:
			continue
		# a standing bridge on the way beats waiting for the boat
		var near_bridge = false
		for br in G.world.bridges:
			var bz = (br[2] + br[3]) * 0.5
			if br[5].alive and absf(bz - s.pos.z) < 14.0:
				near_bridge = true
		if near_bridge:
			continue
		s.task = "board"
		s.board_target = v
		AI.go_to(s, v.pos, 4.0)
		heading += 1

# called from the vehicle's mission logic: where should the boat go now?
static func target(v, dt: float):
	var b = null
	for x in boats:
		if x["v"] == v:
			b = x
	if b == null:
		return null
	var m = v.mission
	var aboard = 0
	for i in range(1, v.seats.size()):
		if v.seats[i] != null:
			aboard += 1
	match m["stage"]:
		0:
			# loading: go once it's full, or after a while with someone aboard
			if G.dist2d(v.pos, b["home"]) > 3.0:
				return b["home"]
			if aboard >= v.seats.size() - 1 or (aboard >= 2 and b["load_t"] > 14.0) or (aboard >= 1 and b["load_t"] > 30.0):
				m["stage"] = 1
				m["go_t"] = 0.0
				if v.driver() != null:
					G.fx.callout(v.driver(), G.pick(["Hold on!", "Shoving off!", "Keep your heads down!"]))
			return null
		1:
			m["go_t"] = m.get("go_t", 0.0) + dt
			var stuck = absf(v.speed) < 0.3 and m["go_t"] > 4.0 and G.dist2d(v.pos, b["far"]) < 9.0
			if G.dist2d(v.pos, b["far"]) < 2.5 or stuck:
				for i in range(1, v.seats.size()):
					var s = v.seats[i]
					if s != null and is_instance_valid(s):
						s.dismount(false)
						# into the shallows and up the bank
						if not s.is_player:
							var bank = b["far"] + Vector3(-b["side"] * 6.0, 0, randf_range(-3.0, 3.0))
							AI.go_to(s, bank, 4.0)
				if v.driver() != null:
					G.fx.callout(v.driver(), G.pick(["Out! Go, go!", "Everybody out!", "Move up the bank!"]))
				m["stage"] = 2
				m["wait"] = 2.0
				return null
			return b["far"]
		2:
			m["wait"] -= dt
			if m["wait"] <= 0.0:
				m["stage"] = 3
			return null
		_:
			if G.dist2d(v.pos, b["home"]) < 2.5:
				m["stage"] = 0
				b["load_t"] = 0.0
				return null
			return b["home"]
	return null
