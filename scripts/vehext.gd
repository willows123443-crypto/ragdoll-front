class_name VehExt
extends RefCounted
# Vehicle extras: fixed-wing planes, fuel, towing, bridge laying, supply and recovery runs,
# anti-aircraft fire and visible battle damage.

# ---------------------------------------------------------------- planes
static func plane_step(v, dt: float) -> void:
	var gy = G.world.ground_y(v.pos.x, v.pos.z)
	if v.rotor != null:
		v.rotor.rotation.z += dt * (45.0 if not v.dead else 6.0)
	var cur: Vector3 = v.get_meta("dir", v.forward())
	if v.dead:
		# going down in a spiral, trailing smoke
		v.air_vel.y -= 14.0 * dt
		v.pos += v.air_vel * dt
		v.roll += dt * 2.5
		if v.air_vel.length() > 0.5:
			cur = v.air_vel.normalized()
		_orient(v, cur, v.roll)
		if v.pos.y <= gy + 0.6 and not v.has_meta("crashed"):
			v.set_meta("crashed", true)
			v.pos.y = gy + 0.3
			v.air_vel = Vector3.ZERO
			G.fx.explosion(v.pos + Vector3(0, 1, 0), 2.0)
			G.audio.boom(v.pos)
			G.world.damage_area(v.pos, 6.0, 1.2)
		if v.has_meta("crashed"):
			v.pos.y = gy + 0.3
			v.air_vel = Vector3.ZERO
		v.alt = maxf(0.0, v.pos.y - gy)
		return
	var want: Vector3 = cur
	var thr = 0.75
	var fire = false
	var bomb = false
	var d = v.driver()
	if d != null and is_instance_valid(d) and d.state == "riding":
		if d.is_player:
			var aim: Vector3 = v.player_inputs["aim"]
			if aim.distance_to(v.pos) > 5.0:
				want = (aim - v.pos).normalized()
			thr = 0.55 + v.player_inputs["thr"] * 0.45
			var shift = Input.is_key_pressed(KEY_SHIFT)
			fire = v.player_inputs["fire"] and not shift
			bomb = v.player_inputs["fire"] and shift
		else:
			var r = _plane_ai(v, dt, cur)
			want = r[0]
			thr = r[1]
			fire = r[2]
			bomb = r[3]
	else:
		want = (cur + Vector3(0, -0.25, 0)).normalized()
		thr = 0.2
	# never fly into the ground: look a couple of seconds ahead along the current heading
	var spd0: float = v.get_meta("spd", v.spec["speed"])
	var ahead = v.pos + cur * spd0 * 1.8
	var gy_ahead = maxf(G.world.ground_y(ahead.x, ahead.z), gy)
	var clearance = minf(v.pos.y - gy, ahead.y - gy_ahead)
	if clearance < 30.0 and want.y < 0.35:
		want = (G.flat(want).normalized() + Vector3(0, 0.5 + 1.2 * (1.0 - clamp(clearance, 0.0, 30.0) / 30.0), 0)).normalized()
	# turn at a limited rate, banking into turns
	var ang = cur.angle_to(want)
	var maxa = v.spec["turn"] * 1.25 * dt
	var nd = cur
	if ang > 0.0001:
		nd = cur.slerp(want, minf(1.0, maxa / ang)).normalized()
	var turn_rate = G.flat(cur).signed_angle_to(G.flat(nd), Vector3.UP) / maxf(dt, 0.001)
	v.roll = lerpf(v.roll, clampf(-turn_rate * 0.9, -1.15, 1.15), dt * 3.0)
	var spd: float = v.get_meta("spd", v.spec["speed"] * 0.8)
	var target_spd = lerpf(v.spec["rev"], v.spec["speed"], thr) - nd.y * 18.0
	spd = move_toward(spd, target_spd, v.spec["accel"] * dt)
	v.set_meta("spd", spd)
	v.set_meta("dir", nd)
	v.pos += nd * spd * dt
	v.air_vel = nd * spd
	v.yaw = atan2(nd.x, nd.z)
	_orient(v, nd, v.roll)
	gy = G.world.ground_y(v.pos.x, v.pos.z)
	v.alt = v.pos.y - gy
	# hitting the ground or a building
	var crash = v.pos.y < gy + 0.8
	if not crash and v.alt < 25.0:
		for c in G.world.cols_in_rect(v.pos.x - 2.0, v.pos.z - 2.0, v.pos.x + 2.0, v.pos.z + 2.0):
			if c.alive and v.pos.y < c.hi.y and v.pos.y > c.lo.y - 0.5:
				crash = true
				break
	if crash:
		v.set_meta("why", "crashed")
		v.destroy(null)
		return
	# guns in the wings, bombs under the belly
	v.fire_cd -= dt
	v.bomb_cd -= dt
	if fire and v.fire_cd <= 0.0 and d != null and is_instance_valid(d):
		v.fire_cd = 0.07
		var W = G.WEAPONS["hmg"]
		var right = nd.cross(Vector3.UP).normalized()
		for side in [-1.0, 1.0]:
			var o = v.pos + right * side * 2.2 + nd * 2.0
			Combat.fire_ray(d, o, Combat.spread_dir(nd, 0.012), W, true, [v.body.get_rid()])
		G.fx.muzzle(v.pos + nd * 3.0, false)
		G.audio.shot(v.pos, W)
	if bomb and v.bomb_cd <= 0.0 and d != null and is_instance_valid(d):
		v.bomb_cd = 2.5 if v.kind == "bomber" else 6.0
		_drop_bomb(v, d)
	if v.kind == "bomber":
		v._weapons(dt)
	v.engine_t -= dt
	if v.engine_t <= 0.0:
		v.engine_t = 0.25
		G.audio.engine(v.pos, 1.0, true)
	if v.life_t > 0.0:
		v.life_t -= dt
		if v.life_t <= 0.0:
			v.set_meta("leaving", true)
	# gone off the edge of the map on the way home
	var b: Rect2 = G.world.bounds
	if v.has_meta("leaving") and (v.pos.x < b.position.x - 150.0 or v.pos.x > b.end.x + 150.0 or v.pos.z < b.position.y - 150.0 or v.pos.z > b.end.y + 150.0):
		var dr = v.driver()
		v.remove()
		if dr != null and is_instance_valid(dr) and not dr.is_player:
			G.soldiers.erase(dr)
			dr.queue_free()

static func _orient(v, dir: Vector3, roll: float) -> void:
	var z = dir.normalized()
	var x = Vector3.UP.cross(z)
	if x.length_squared() < 1e-4:
		x = Vector3.RIGHT
	x = x.normalized()
	var y = z.cross(x).normalized()
	var bs = Basis(x, y, z).rotated(z, roll)
	v.global_transform = Transform3D(bs, v.pos)
	v.body.global_transform = v.global_transform

static func _drop_bomb(v, d) -> void:
	var m = MeshInstance3D.new()
	var bm = CapsuleMesh.new()
	bm.radius = 0.18
	bm.height = 1.0
	m.mesh = bm
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.22, 0.18)
	m.material_override = mat
	G.fx.add_child(m)
	var p = v.pos + Vector3(0, -0.6, 0)
	m.global_position = p
	Combat.rockets.append({"p": p, "v": v.air_vel * 0.95, "owner": d, "veh": v, "mesh": m, "life": 12.0, "trail": 1.0, "power": 2.3, "vdmg": 1200.0, "g": 1.0})
	G.audio.whistle(p)

static func _plane_ai(v, dt: float, cur: Vector3) -> Array:
	var b: Rect2 = G.world.bounds
	var center = Vector3(b.get_center().x, 0, b.get_center().y)
	if v.has_meta("leaving"):
		var away = G.flat(v.pos - center)
		if away.length_squared() < 1.0:
			away = Vector3(1, 0, 0)
		return [(away.normalized() + Vector3(0, 0.15, 0)).normalized(), 1.0, false, false]
	# keep over the battlefield
	if v.pos.x < b.position.x - 60.0 or v.pos.x > b.end.x + 60.0 or v.pos.z < b.position.y - 60.0 or v.pos.z > b.end.y + 60.0:
		var back = center + Vector3(0, 80.0, 0) - v.pos
		return [back.normalized(), 0.8, false, false]
	var pull: float = v.get_meta("pull_t", 0.0)
	if pull > 0.0:
		v.set_meta("pull_t", pull - dt)
		return [(G.flat(cur).normalized() + Vector3(0, 0.75, 0)).normalized(), 1.0, false, false]
	# fighters go after enemy aircraft first
	if v.kind == "fighter":
		var best = null
		var bd = 600.0
		for o in G.vehicles:
			if o.team != v.team and not o.dead and o.spec.get("air", false) and o.alt > 4.0:
				var dd = o.pos.distance_to(v.pos)
				if dd < bd:
					bd = dd
					best = o
		if best != null:
			var lead: Vector3 = best.pos + best.air_vel * (bd / (v.get_meta("spd", 40.0) + 80.0))
			var w = (lead - v.pos).normalized()
			return [w, 1.0, cur.angle_to(w) < 0.07 and bd < 220.0, false]
	# ground attack: armour first, then dug-in positions, then groups of soldiers
	var g = _ground_target(v)
	if g == null:
		var orbit = center + Vector3(cos(G.sim_time * 0.12), 0, sin(G.sim_time * 0.12)) * 120.0 + Vector3(0, 85.0, 0)
		return [(orbit - v.pos).normalized(), 0.7, false, false]
	var flat_d = G.dist2d(g, v.pos)
	if flat_d > (170.0 if v.kind == "bomber" else 140.0):
		var app = g + Vector3(0, 85.0 if v.kind == "bomber" else 65.0, 0)
		return [(app - v.pos).normalized(), 1.0, false, false]
	var w2 = (g - v.pos).normalized()
	var aligned = cur.angle_to(w2) < 0.1
	if v.alt < 50.0 or (v.kind == "bomber" and aligned and flat_d < 85.0):
		v.set_meta("pull_t", 3.0)
		return [w2, 1.0, false, aligned and v.kind == "bomber"]
	return [w2, 0.85, aligned and flat_d < 150.0 and v.kind == "fighter", aligned and v.kind == "fighter" and flat_d < 60.0]

static func _ground_target(v):
	var best = null
	var bd = 1e9
	for o in G.vehicles:
		if o.team != v.team and not o.dead and not o.spec.get("air", false):
			var d = G.dist2d(o.pos, v.pos)
			if d < bd:
				bd = d
				best = o.center()
	if best != null:
		return best
	var es = Build.enemy_site_near(v.team, v.pos, 400.0)
	if es != null and es[0]["kind"] in ["hq", "fob", "depot", "bunker", "mgnest", "aa"]:
		return es[1]
	return ClassAI.artillery_target(v.team, v.pos, 0.0)

# ---------------------------------------------------------------- anti-aircraft fire
static func aa_target(v):
	var best = null
	var bd = 280.0
	for o in G.vehicles:
		if o.team != v.team and not o.dead and o.spec.get("air", false) and o.alt > 3.0:
			var d = o.pos.distance_to(v.pos)
			if d < bd:
				bd = d
				best = o
	if best == null:
		return null
	var t = bd / 330.0
	return [best.center() + best.air_vel * t, false]

# AA guns knock down the strike planes and transports flying over them too
static func aa_vs_plane(at: Vector3, team: int, dt: float) -> bool:
	for v in G.vehicles:
		if v.kind == "aagun" and not v.dead and v.team != team and v.gunner() != null and v.pos.distance_to(at) < 200.0:
			if randf() < 0.3 * dt:
				return true
	return false

# ---------------------------------------------------------------- fuel
static func fuel_tick(v, dt: float, thr: float) -> float:
	if v.spec.get("static", false):
		return thr
	v.fuel = maxf(0.0, v.fuel - absf(v.speed) / maxf(v.spec["speed"], 1.0) * dt / 420.0)
	# topping up at crates, FOBs, depots and supply dumps
	v.supply_t += dt
	if v.supply_t > 2.0:
		v.supply_t = 0.0
		if v.fuel < 1.0 or v.hp < v.spec["hp"]:
			for a in G.world.ammo_points:
				if (a["team"] == v.team or a["team"] < 0) and G.dist2d(a["p"], v.pos) < 18.0:
					v.fuel = minf(1.0, v.fuel + 0.15)
					break
			for st in Build.sites:
				if st["kind"] == "depot" and st["team"] == v.team and Build.alive(st) and G.dist2d(st["p"], v.pos) < 16.0:
					v.fuel = minf(1.0, v.fuel + 0.2)
					v.repair(60.0)
					if v.tracks_broken and v.hp > v.spec["hp"] * 0.5:
						v.tracks_broken = false
	if v.fuel <= 0.0:
		var d = v.driver()
		if d != null and is_instance_valid(d) and not v.fuel_said:
			v.fuel_said = true
			if d.is_player:
				G.ui.message("Out of fuel! Refuel at a depot, FOB, supply dump or ammo crate")
			else:
				G.fx.callout(d, "We're out of fuel!")
		return 0.0
	v.fuel_said = false
	return thr

# where an AI driver low on fuel should head
static func fuel_stop(v):
	var best = null
	var bd = 1e9
	for a in G.world.ammo_points:
		if a["team"] == v.team or a["team"] < 0:
			var d = G.dist2d(a["p"], v.pos)
			if d < bd:
				bd = d
				best = a["p"]
	return best

# ---------------------------------------------------------------- towing
static func try_tow(v) -> String:
	if v.towing != null and is_instance_valid(v.towing):
		v.towing.towed_by = null
		v.towing = null
		return "Unhitched"
	var f = v.forward()
	var best = null
	var bd = 9.0
	for o in G.vehicles:
		if o == v or o.dead or o.spec.get("air", false) or o.towed_by != null or o.kind == "tank":
			continue
		var movable = o.kind in ["artillery", "mortar", "aagun"] or o.tracks_broken or o.driver() == null or o.fuel <= 0.0
		if not movable:
			continue
		var rel = G.flat(o.pos - v.pos)
		if rel.dot(f) > 0.0:
			continue
		var d = rel.length()
		if d < bd + v.spec["len"] * 0.5:
			bd = d
			best = o
	if best == null:
		return "Nothing to tow behind you (back up to a field gun or broken-down vehicle)"
	v.towing = best
	best.towed_by = v
	return "Towing the %s (press Q again to unhitch)" % best.spec["name"].to_lower()

static func tow_tick(v, dt: float) -> void:
	var o = v.towing
	if o == null:
		return
	if not is_instance_valid(o) or o.dead or v.dead:
		if is_instance_valid(o):
			o.towed_by = null
		v.towing = null
		return
	var f = v.forward()
	var hitch = v.pos - f * (v.spec["len"] * 0.5 + o.spec["len"] * 0.5 + 0.8)
	var to = G.flat(v.pos - o.pos)
	if to.length_squared() > 0.01:
		o.yaw = lerp_angle(o.yaw, atan2(to.x, to.z), minf(1.0, dt * 2.5))
	o.pos = o.pos.lerp(Vector3(hitch.x, o.pos.y, hitch.z), minf(1.0, dt * 6.0))
	o._place(dt)

# ---------------------------------------------------------------- bridges
# lays the bridge across the water ahead; returns a message
static func lay_bridge(v) -> String:
	if v.bridge_laid:
		return "The bridge has already been laid"
	var f = v.forward()
	var along_x = absf(f.x) >= absf(f.z)
	var dir = Vector3(signf(f.x), 0, 0) if along_x else Vector3(0, 0, signf(f.z))
	var start = -1.0
	var stop = -1.0
	for i in range(1, 130):
		var p = v.pos + dir * (v.spec["len"] * 0.5 + i * 0.5)
		var wet = G.world.in_water(p.x, p.z)
		if wet and start < 0.0:
			start = i * 0.5
		elif not wet and start >= 0.0:
			stop = i * 0.5
			break
	if start < 0.0 or start > (24.0 if not v.driver() or not v.driver().is_player else 12.0):
		return "Drive up to the water's edge, facing across, to lay the bridge"
	if stop < 0.0:
		return "Too wide to bridge here (up to about 25 m)"
	var a = v.pos + dir * (v.spec["len"] * 0.5 + maxf(0.0, start - 3.0))
	var b = v.pos + dir * (v.spec["len"] * 0.5 + stop + 2.0)
	G.world.build_now(func():
		if along_x:
			G.world.bridge(minf(a.x, b.x), maxf(a.x, b.x), v.pos.z, 5.0)
		else:
			G.world.bridge_z(minf(a.z, b.z), maxf(a.z, b.z), v.pos.x, 5.0))
	v.bridge_laid = true
	if v.has_meta("bridge_node"):
		v.get_meta("bridge_node").visible = false
	G.fx.dust_cloud((a + b) * 0.5, 6.0)
	G.audio.boom((a + b) * 0.5)
	G.ui.radio(v.team, "Bridge laid at %s" % AI.grid_ref((a + b) * 0.5))
	return "Bridge laid!"

# for an AI bridge layer: the riverbank on the way from home to the objective
static func bridge_site(v):
	if G.world.water.is_empty():
		return null
	var home: Vector3 = G.world.spawn[v.team]
	var obj: Vector3 = G.world.spawn[(v.team + 1) % G.team_count()]
	var to = G.flat(obj - home)
	var L = to.length()
	if L < 1.0:
		return null
	to /= L
	var along_x = absf(to.x) >= absf(to.z)
	var dir = Vector3(signf(to.x), 0, 0) if along_x else Vector3(0, 0, signf(to.z))
	var side = Vector3(-dir.z, 0, dir.x)
	# try a few lines across, away from the existing bridges
	for off in [0.0, 22.0, -22.0, 40.0, -40.0]:
		var o2 = home + side * off
		for k in range(int(L / 2.0)):
			var p = o2 + dir * (k * 2.0)
			if G.world.in_water(p.x, p.z):
				return [p - dir * 9.0, dir]
			var near_bridge = false
			for b in G.world.bridges:
				if b[5].alive and p.x > b[0] - 3.0 and p.x < b[1] + 3.0 and p.z > b[2] - 3.0 and p.z < b[3] + 3.0:
					near_bridge = true
			if near_bridge:
				break
	return null

# ---------------------------------------------------------------- battle damage you can see
static func dent(v, at: Vector3) -> void:
	var best = null
	var bd = 1.6
	for m in v.get_children():
		if m is MeshInstance3D:
			var d = m.global_position.distance_to(at)
			if d < bd:
				bd = d
				best = m
	if best == null or best.has_meta("dented"):
		return
	best.set_meta("dented", true)
	var mat = best.material_override
	if mat is StandardMaterial3D:
		var dm = mat.duplicate()
		dm.albedo_color = dm.albedo_color.darkened(0.3)
		best.material_override = dm
	best.rotation += Vector3(randf_range(-0.07, 0.07), randf_range(-0.05, 0.05), randf_range(-0.07, 0.07))
	best.scale *= Vector3(randf_range(0.94, 1.0), randf_range(0.92, 1.0), 1.0)

static func lose_door(v) -> void:
	for d in v.doors:
		var n: Node3D = d["n"]
		if is_instance_valid(n) and n.visible and not d.has("slide"):
			var p = n.global_position
			n.visible = false
			for m in n.get_children():
				if m is MeshInstance3D and m.material_override is StandardMaterial3D:
					G.fx.debris(p + Vector3(0, 0.4, 0), (p - v.center()).normalized() * 5.0 + Vector3(0, 3, 0), 0.5, m.material_override.albedo_color)
					break
			return

# an ammunition explosion flips the turret off
static func blow_turret(v) -> void:
	if v.turret == null or not is_instance_valid(v.turret):
		return
	var rb = RigidBody3D.new()
	rb.collision_layer = G.L_DEBRIS
	rb.collision_mask = G.L_WORLD
	rb.mass = 40.0
	var cs = CollisionShape3D.new()
	var bs = BoxShape3D.new()
	bs.size = Vector3(2.0, 0.8, 2.4)
	cs.shape = bs
	rb.add_child(cs)
	G.fx.add_child(rb)
	rb.global_transform = v.turret.global_transform
	v.turret.reparent(rb, true)
	rb.linear_velocity = Vector3(randf_range(-3, 3), randf_range(9, 13), randf_range(-3, 3))
	rb.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-2, 2), randf_range(-4, 4))
	v.turret = null
	v.gun_pivot = null
	var wr = weakref(rb)
	G.main.get_tree().create_timer(60.0, false).timeout.connect(func():
		var r = wr.get_ref()
		if r != null:
			r.queue_free())

# ---------------------------------------------------------------- supply and recovery runs
# a truck from HQ restocks a FOB or supply dump that's running low
static func supply_run(team: int, st: Dictionary) -> void:
	var h = Build.hq(team)
	if h == null or not Build.alive(h):
		return
	var start = G.main._free_spot(h["p"] + Build._front(h) * 10.0)
	var drop = G.main._free_spot(st["p"] + Build._front(st) * -8.0)
	var v = Vehicle.make("truck", team, start, atan2(drop.x - start.x, drop.z - start.z))
	v.mission = {"type": "supply", "drop": drop, "exit": start, "stage": 0, "wait": 0.0, "site": st}
	var drv = G.main.spawn_soldier(team, start.x, start.z, "rifle")
	if drv == null:
		v.remove()
		return
	drv.mount(v, 0)
	st["truck"] = v
	G.ui.radio(team, "Supply truck on its way to the %s at %s" % [st["name"], AI.grid_ref(st["p"])])
