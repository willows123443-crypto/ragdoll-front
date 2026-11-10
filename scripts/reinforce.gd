class_name Reinforce
extends RefCounted
# Reinforcements arrive instead of popping into existence: troop trucks drive in from your edge of
# the map and unload at the rally point, or a transport plane flies over and drops paratroopers.

static var timers: Array = []
static var planes: Array = []

static func reset() -> void:
	timers = []
	for t in range(G.team_count()):
		timers.append(0.0)
	for p in planes:
		if is_instance_valid(p["node"]):
			p["node"].queue_free()
	planes = []

static func foot_count(t: int) -> int:
	var n = 0
	for s in G.soldiers:
		if s.team == t and s.state != "dead":
			var v = s.vehicle
			# on foot, or still on the way up in a truck, boat or helicopter
			if v == null or not is_instance_valid(v) or (v.mission != null and v.mission.get("type", "deliver") == "deliver" and v.driver() != s):
				n += 1
	return n

static func step(dt: float) -> void:
	_step_planes(dt)
	if not G.reinforce or G.over:
		return
	for t in range(G.team_count()):
		if G.mode == "laststand" or (G.mode == "horde" and t == 1) or (G.mode == "commander" and t == 0):
			continue          # waves are handled by the game mode
		# men crewing guns and vehicles don't count toward the infantry strength
		var missing = G.size_of(t) - foot_count(t)
		if not Campaign.reinforce_ok(t):
			continue
		if missing <= 0:
			timers[t] = minf(timers[t], 0.0)
			continue
		if G.mode == "sabotage" and t == 0:
			continue
		if G.mode == "siege" and t == 0 and Obj.supply < 1.0:
			continue
		# no HQ and no FOB: nobody can come in until one is built
		if not Build.can_respawn(t):
			timers[t] = minf(timers[t], 0.0)
			continue
		timers[t] += dt
		if G.mode == "siege" and t == 0:
			missing = mini(missing, int(Obj.supply))
		var before = timers[t]
		# fresh troops are gathered and sent forward in groups, which takes a while
		var thr = {"instant": 7.0, "para": 35.0 if missing >= 4 else 55.0, "heli": 38.0 if missing >= 4 else 58.0}.get(G.reinf_mode, 30.0 if missing >= 4 else 50.0)
		if timers[t] > thr and G.reinf_mode != "instant" and not Comms.reinforce_allowed(t):
			timers[t] = thr       # waiting on a runner to ask for them
			continue
		if timers[t] > thr and G.reinf_mode != "instant":
			Comms.used_reinf(t)
		match G.reinf_mode:
			"instant":
				if timers[t] > thr:
					timers[t] = 0.0
					G.main.base_spawn(t)
			"para":
				if timers[t] > thr:
					timers[t] = -20.0
					paradrop(t, mini(missing, 6))
			"heli":
				if timers[t] > thr:
					timers[t] = -20.0
					heli(t, mini(missing, 6))
			_:
				if timers[t] > thr:
					timers[t] = -20.0
					truck(t, mini(missing, 8))
		if G.mode == "siege" and t == 0 and timers[t] < before - 1.0:
			Obj.supply = maxf(0.0, Obj.supply - mini(missing, 8))

# behind our own front line: where the team's men are, pulled back toward home and away from known enemies
static func forward_drop(t: int) -> Vector3:
	var home: Vector3 = G.world.rally_point(t)
	var sum = Vector3.ZERO
	var n = 0
	for s in G.soldiers:
		if s.team == t and s.state == "alive" and s.vehicle == null and G.dist2d(s.pos, G.world.spawn[t]) > 40.0:
			sum += s.pos
			n += 1
	if n < 3:
		return home
	var front = sum / n
	var back = G.flat(home - front)
	if back.length() < 30.0:
		return home
	var p = front + back.normalized() * 35.0
	# not into a known enemy position
	var c = AI.team_intel_center(t)
	if c != null and G.dist2d(c, p) < 40.0:
		p = p + back.normalized() * 25.0
	if G.world.in_water(p.x, p.z):
		return home
	return p

# where a team's trucks come in from: the team's own edge of the map, on a road if there is one
static func entry_point(t: int) -> Vector3:
	var b: Rect2 = G.world.bounds
	var home: Vector3 = G.world.rally_point(t)
	# come in from the team's own edge: the one behind its base as seen from the middle of the map
	var dir = G.flat(G.world.spawn[t] - Vector3.ZERO).normalized()
	if dir.length_squared() < 0.01:
		dir = Vector3(-1, 0, 0)
	var x = b.position.x + 5.0 if dir.x < 0.0 else b.end.x - 5.0
	var z = home.z
	for rd in G.world.roads:
		if rd[1] - rd[0] > 100.0:
			z = (rd[2] + rd[3]) * 0.5
			break
	if absf(dir.z) > absf(dir.x):
		x = home.x
		z = b.position.y + 5.0 if dir.z < 0.0 else b.end.y - 5.0
	return Vector3(x, G.world.ground_y(x, z), z)

# somewhere just in from the edge with nothing parked on it (wrecks and other arrivals block the road)
static func clear_entry(t: int) -> Vector3:
	var e = entry_point(t)
	var inward = G.flat(G.world.rally_point(t) - e).normalized()
	var perp = Vector3(-inward.z, 0, inward.x)
	var b: Rect2 = G.world.bounds
	for k in range(16):
		var q = e + inward * (6.0 + (k / 4) * 6.0) + perp * [0.0, 9.0, -9.0, 18.0][k % 4]
		q.x = clampf(q.x, b.position.x + 5.0, b.end.x - 5.0)
		q.z = clampf(q.z, b.position.y + 5.0, b.end.y - 5.0)
		var ok = not G.world.inside_any(q.x, q.z, 2.0) and not G.world.in_water(q.x, q.z)
		for v in G.vehicles:
			if G.dist2d(v.pos, q) < 10.0:
				ok = false
		if ok:
			return Vector3(q.x, G.world.ground_y(q.x, q.z), q.z)
	return e

static func truck(t: int, n: int, dest = null) -> void:
	if G.map_id == "beach" and t == 0:
		boat(t, n)
		return
	var entry = clear_entry(t)
	# drop them where they're needed: a little behind the front line (or wherever they were sent)
	var drop = G.main._free_spot(dest if dest != null else forward_drop(t))
	var yaw = atan2(drop.x - entry.x, drop.z - entry.z)
	var v = Vehicle.make("truck", t, entry, yaw)
	v.mission = {"type": "deliver", "drop": drop, "exit": entry, "stage": 0, "wait": 0.0}
	var drv = G.main.spawn_soldier(t, entry.x, entry.z, "rifle")
	if drv == null:
		v.remove()
		return
	drv.mount(v, 0)
	for i in range(n):
		var s = G.main.spawn_soldier(t, entry.x, entry.z, "")
		if s == null:
			break
		s.mount(v, i + 1)
	G.ui.radio(t, "%d reinforcements inbound by truck, ETA two minutes" % n)

# a transport helicopter flies troops in and lands them at the rally point
static func heli(t: int, n: int) -> void:
	var entry = clear_entry(t)
	var drop = G.main._free_spot(G.world.rally_point(t) + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)))
	var v = Vehicle.make("heli", t, entry, atan2(drop.x - entry.x, drop.z - entry.z))
	v.mission = {"type": "deliver", "drop": drop, "exit": entry, "stage": 0, "wait": 0.0}
	var drv = G.main.spawn_soldier(t, entry.x, entry.z, "rifle")
	if drv == null:
		v.remove()
		return
	drv.mount(v, 0)
	for i in range(mini(n, v.seats.size() - 1)):
		var s = G.main.spawn_soldier(t, entry.x, entry.z, "")
		if s == null:
			break
		s.mount(v, i + 1)
	G.ui.radio(t, "Helicopter inbound with %d troops" % n)

# landing craft come in from the sea and drop their ramp on the beach
static func boat(t: int, n: int) -> void:
	var b: Rect2 = G.world.bounds
	var z = randf_range(b.position.y + 30.0, b.end.y - 30.0)
	var entry = Vector3(b.position.x - 60.0, 0, z)
	var drop = Vector3(b.position.x + 68.0, 0, z)
	var v = Vehicle.make("boat", t, entry, PI / 2.0)
	v.mission = {"type": "deliver", "drop": drop, "exit": entry, "stage": 0, "wait": 0.0}
	var drv = G.main.spawn_soldier(t, b.position.x + 5.0, z, "rifle")
	if drv == null:
		v.remove()
		return
	drv.mount(v, 0)
	for i in range(mini(n, 8)):
		var s = G.main.spawn_soldier(t, b.position.x + 5.0, z, "")
		if s == null:
			break
		s.mount(v, i + 1)
	G.ui.radio(t, "Landing craft inbound, %d troops" % n)

static func paradrop(t: int, n: int) -> void:
	var home: Vector3 = G.world.rally_point(t)
	var zone = home + G.flat(G.world.capture - home).normalized() * 18.0
	var b: Rect2 = G.world.bounds
	# the plane crosses the map along z, passing over the drop zone
	var start = Vector3(zone.x, 75.0, b.position.y - 40.0)
	var end_ = Vector3(zone.x, 75.0, b.end.y + 40.0)
	var node = _plane_mesh(t)
	node.global_position = start
	node.look_at(end_, Vector3.UP)
	planes.append({"node": node, "from": start, "to": end_, "t": 0.0, "team": t, "zone": zone, "left": n, "drop_t": 0.0})
	G.audio.engine(start, 1.0, true)
	G.ui.radio(t, "Paratroopers inbound, watch the skies")

static func _step_planes(dt: float) -> void:
	for i in range(planes.size() - 1, -1, -1):
		var p = planes[i]
		var L = p["from"].distance_to(p["to"])
		p["t"] += dt * 38.0 / L
		var at: Vector3 = p["from"].lerp(p["to"], p["t"])
		p["node"].global_position = at
		p["drop_t"] -= dt
		# once over the zone, the whole stick goes out the door one after another
		if p["left"] > 0 and (p.get("dropping", false) or absf(at.z - p["zone"].z) < 22.0) and p["drop_t"] <= 0.0:
			p["dropping"] = true
			p["drop_t"] = 0.2
			p["left"] -= 1
			var x = at.x + randf_range(-3, 3)
			var s = G.main.spawn_soldier(p["team"], x, at.z, "")
			if s != null:
				s.start_chute(Vector3(x, at.y - 3.0, at.z))
		if int(p["t"] * 40.0) % 3 == 0 and randf() < 0.1:
			G.audio.engine(at, 1.0, true)
		if p["t"] >= 1.0:
			p["node"].queue_free()
			planes.remove_at(i)

static func _plane_mesh(t: int) -> Node3D:
	var n = Node3D.new()
	var c = G.TEAM_UNI[t].lerp(Color(0.45, 0.47, 0.45), 0.6)
	for part in [[Vector3(2.6, 2.6, 18.0), Vector3(0, 0, 0)], [Vector3(26.0, 0.4, 3.2), Vector3(0, 0.4, 0.8)],
			[Vector3(8.0, 0.3, 1.8), Vector3(0, 0.6, -7.5)], [Vector3(0.3, 3.0, 2.2), Vector3(0, 2.0, -7.6)]]:
		var mi = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = part[0]
		mi.mesh = bm
		var m = StandardMaterial3D.new()
		m.albedo_color = c
		mi.material_override = m
		mi.position = part[1]
		n.add_child(mi)
	# box +z is the nose; look_at points -z forward, so flip the model
	n.rotation_degrees.y = 180.0
	var holder = Node3D.new()
	holder.add_child(n)
	G.main.add_child(holder)
	return holder
