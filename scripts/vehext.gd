class_name VehExt
extends RefCounted
# Vehicle extras: fixed-wing planes, fuel, towing, bridge laying, supply and recovery runs,
# anti-aircraft fire and visible battle damage.

# ---------------------------------------------------------------- planes
static func plane_step(v, dt: float) -> void:
	var gy = G.world.ground_y(v.pos.x, v.pos.z)
	if v.rotor != null and not v.has_meta("crashed"):
		v.rotor.rotation.z += dt * (45.0 if not v.dead else 6.0)
	var cur: Vector3 = v.get_meta("dir", v.forward())
	if v.dead and v.has_meta("crashed"):
		burn_fx(v, dt)
		v.alt = 0.0
		return
	if v.dead:
		# going down in a spiral, trailing smoke
		v.air_vel.y -= 14.0 * dt
		v.pos += v.air_vel * dt
		v.roll += dt * 2.5
		if v.air_vel.length() > 0.5:
			cur = v.air_vel.normalized()
		_orient(v, cur, v.roll)
		damage_trail(v)
		burn_fx(v, dt)
		if v.pos.y <= gy + 0.6:
			v.set_meta("crashed", true)
			v.air_vel = Vector3.ZERO
			Combat.explode(v.pos + Vector3(0, 1, 0), null, 1.4)
			crash_wreck(v)
			v.alt = 0.0
			return
		v.alt = maxf(0.0, v.pos.y - gy)
		return
	damage_trail(v)
	burn_fx(v, dt)
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
	# keep the fight low enough to see from the battlefield: over the ceiling, nose down into a turn
	if v.alt > 190.0 and want.y > -0.2:
		var fw = G.flat(want)
		if fw.length_squared() < 0.01:
			fw = G.flat(cur)
		if fw.length_squared() < 0.01:
			fw = Vector3(1, 0, 0)
		want = (fw.normalized() + Vector3(0, -0.25 - clampf((v.alt - 190.0) / 60.0, 0.0, 1.0), 0)).normalized()
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
		# fighters break into a climbing turn to one side; bombers just pull out of the dive
		var fc = G.flat(cur).normalized()
		if v.kind == "fighter":
			fc = fc.rotated(Vector3.UP, v.get_meta("pull_side", 1.0) * 1.1)
		return [(fc + Vector3(0, 0.75 if v.kind != "fighter" else 0.35, 0)).normalized(), 1.0, false, false]
	# someone on my tail: break hard to one side, then reverse, until he overshoots
	var ev = _evade(v, dt, cur)
	if ev != null:
		return ev
	# fighters go after enemy aircraft first: other planes before helicopters, and the one I'm already chasing
	if v.kind == "fighter":
		var best = null
		var bs = 1e9
		var cur_t = v.get_meta("dog_t") if v.has_meta("dog_t") else null
		for o in G.vehicles:
			if o.team != v.team and not o.dead and o.spec.get("air", false) and o.alt > 4.0:
				var dd = o.pos.distance_to(v.pos)
				if dd > 650.0:
					continue
				var sc = dd * (1.0 if o.spec.get("plane", false) else 1.6)
				if o == cur_t:
					sc *= 0.6
				# easier shot if he's in front of me
				sc *= 1.3 - 0.5 * cur.dot((o.pos - v.pos).normalized())
				if sc < bs:
					bs = sc
					best = o
		if best != null:
			v.set_meta("dog_t", best)
			var bd = best.pos.distance_to(v.pos)
			var lead: Vector3 = best.pos + best.air_vel * (bd / (v.get_meta("spd", 40.0) + 80.0))
			var w = (lead - v.pos).normalized()
			# overshooting a slower target head-on: pull up and come round again instead of ramming
			if bd < 25.0 and cur.dot(best.air_vel.normalized()) < 0.0:
				v.set_meta("pull_t", randf_range(1.2, 2.2))
				v.set_meta("pull_side", 1.0 if randf() < 0.5 else -1.0)
			if bd < 60.0 and randf() < 0.01:
				G.fx.callout(v.driver(), G.pick(["On his six!", "I've got him!", "Guns, guns, guns!", "Stay on him!"]))
			return [w, 1.0 if bd > 70.0 else 0.6, cur.angle_to(w) < 0.08 and bd < 230.0, false]
		elif v.has_meta("dog_t"):
			v.remove_meta("dog_t")
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

# an enemy fighter sitting behind me and pointing at me: jink. The break lasts a couple of seconds,
# alternates sides and mixes in climbs and dives, so a chasing fighter has to work to stay on it.
static func _evade(v, dt: float, cur: Vector3):
	var et: float = v.get_meta("ev_t", 0.0)
	if et > 0.0:
		v.set_meta("ev_t", et - dt)
		var right = cur.cross(Vector3.UP).normalized()
		var side: float = v.get_meta("ev_side", 1.0)
		var vert: float = v.get_meta("ev_v", 0.0)
		if v.alt < 45.0:
			vert = absf(vert) + 0.2
		return [(cur + right * side * 1.6 + Vector3(0, vert, 0)).normalized(), 1.0, false, false]
	v.set_meta("ev_chk", v.get_meta("ev_chk", 0.0) - dt)
	if v.get_meta("ev_chk", 0.0) > 0.0:
		return null
	v.set_meta("ev_chk", 0.4)
	for o in G.vehicles:
		if o.team == v.team or o.dead or o.kind != "fighter" or o.alt < 4.0:
			continue
		var to_me = v.pos - o.pos
		var d = to_me.length()
		if d > 260.0 or d < 1.0:
			continue
		var od: Vector3 = o.get_meta("dir", o.forward())
		# he's behind me and his nose is on me
		if od.dot(to_me / d) > 0.93 and cur.dot(to_me / d) > 0.3:
			v.set_meta("ev_t", randf_range(1.6, 2.8))
			v.set_meta("ev_side", -v.get_meta("ev_side", 1.0) if randf() < 0.7 else v.get_meta("ev_side", 1.0))
			v.set_meta("ev_v", randf_range(-0.5, 0.6))
			if randf() < 0.3:
				G.fx.callout(v.driver(), G.pick(["He's on my tail!", "Breaking left!", "Breaking right!", "Get him off me!"]))
			return null
	return null

# a damaged plane trails smoke: grey from the engine first, then thick black with flames before it goes
static func damage_trail(v) -> void:
	var f = v.hp / v.spec["hp"]
	var stage: int = v.get_meta("trail", 0)
	if f < 0.7 and stage < 1:
		v.set_meta("trail", 1)
		_trail(v, Color(0.62, 0.62, 0.6, 0.55), 0.7, 3.0)
	if f < 0.35 and stage < 2:
		v.set_meta("trail", 2)
		_trail(v, Color(0.1, 0.09, 0.08, 0.8), 1.2, 5.0)
		var fl = OmniLight3D.new()
		fl.light_color = Color(1.0, 0.55, 0.2)
		fl.light_energy = 3.0
		fl.omni_range = 10.0
		v.add_child(fl)
		fl.position = Vector3(0, 1.6, 2.5)
		v.set_meta("fire_l", fl)

# flames streaming back from the engine of a burning plane, flickering; and on the wreck once it's down
static func burn_fx(v, dt: float) -> void:
	if v.get_meta("trail", 0) < 2:
		return
	var fl = v.get_meta("fire_l") if v.has_meta("fire_l") else null
	var down = v.has_meta("crashed")
	if down:
		var wt: float = v.get_meta("wreck_t", 0.0) - dt
		v.set_meta("wreck_t", wt)
		if wt <= 0.0:
			if fl != null and is_instance_valid(fl):
				fl.queue_free()
				v.remove_meta("fire_l")
			return
	if fl != null and is_instance_valid(fl):
		fl.light_energy = randf_range(1.8, 5.0) * (0.6 if down else 1.0)
	var cd: float = v.get_meta("flame_cd", 0.0) - dt
	if cd > 0.0:
		v.set_meta("flame_cd", cd)
		return
	v.set_meta("flame_cd", 0.16 if down else 0.05)
	var f: Vector3 = v.global_transform.basis.z
	if down:
		var p = v.global_transform * Vector3(randf_range(-3.0, 3.0), 1.2, randf_range(-3.0, 3.5))
		G.fx.flame_puff(p, Vector3(randf_range(-0.4, 0.4), randf_range(2.5, 4.0), randf_range(-0.4, 0.4)), randf_range(1.2, 2.2))
	else:
		var p = v.global_transform * Vector3(randf_range(-0.3, 0.3), 1.5, 3.2)
		G.fx.flame_puff(p, -f * randf_range(3.0, 6.0) + Vector3(0, 1.0, 0), randf_range(1.6, 2.8))

# a plane hitting the ground: it digs in nose down, a wing tears off, pieces scatter and the wreck burns
static func crash_wreck(v) -> void:
	var gy = G.world.ground_y(v.pos.x, v.pos.z)
	var f = G.flat(v.get_meta("dir", v.forward()))
	if f.length_squared() < 0.01:
		f = Vector3(1, 0, 0)
	f = f.normalized()
	v.pos.y = gy - 0.25
	var bs = Basis.looking_at(-f, Vector3.UP)
	bs = bs.rotated(bs.x, 0.18).rotated(f, randf_range(-0.35, 0.35))
	v.global_transform = Transform3D(bs, v.pos)
	v.body.global_transform = v.global_transform
	v.roll = 0.0
	G.fx.decal(v.pos, 11.0, true)
	G.fx.decal(v.pos - f * 6.0, 7.0, true)
	var pc = Color(0.3, 0.3, 0.28)
	for k in range(9):
		G.fx.debris(v.pos + Vector3(randf_range(-2, 2), 1.5, randf_range(-2, 2)), f * randf_range(4.0, 14.0) + Vector3(randf_range(-6, 6), randf_range(4, 10), randf_range(-6, 6)), randf_range(0.3, 0.9), pc)
	_wing_off(v, 1.0 if randf() < 0.5 else -1.0, f)
	if v.get_meta("trail", 0) < 2:
		v.set_meta("trail", 1)
		damage_trail(v)
	v.set_meta("trail", 2)
	if not v.has_meta("fire_l"):
		var fl = OmniLight3D.new()
		fl.light_color = Color(1.0, 0.55, 0.2)
		fl.omni_range = 12.0
		v.add_child(fl)
		fl.position = Vector3(0, 2.0, 0)
		v.set_meta("fire_l", fl)
	v.set_meta("wreck_t", 45.0)

# the outer half of one wing comes away as its own piece of wreckage
static func _wing_off(v, side: float, f: Vector3) -> void:
	var parts = []
	for m in v.get_children():
		if m is MeshInstance3D and m.position.x * side > 1.7 and m.position.y < 2.0:
			parts.append(m)
	if parts.is_empty():
		return
	var rb = RigidBody3D.new()
	rb.collision_layer = G.L_DEBRIS
	rb.collision_mask = G.L_WORLD | G.L_DEBRIS
	rb.mass = 60.0
	G.fx.add_child(rb)
	rb.global_transform = v.global_transform
	var cs = CollisionShape3D.new()
	var bx = BoxShape3D.new()
	bx.size = Vector3(4.0, 0.3, 1.9)
	cs.shape = bx
	cs.position = Vector3(side * 3.0, 1.1, 0.5)
	rb.add_child(cs)
	for m in parts:
		m.reparent(rb, true)
	var right = v.global_transform.basis.x
	rb.linear_velocity = right * side * randf_range(4.0, 8.0) + f * randf_range(3.0, 8.0) + Vector3(0, randf_range(4.0, 7.0), 0)
	rb.angular_velocity = Vector3(randf_range(-3, 3), randf_range(-3, 3), randf_range(-3, 3))
	G.fx.debris_list.append({"b": rb, "t": 200.0})

static func _trail(v, c: Color, size: float, life: float) -> void:
	var p = CPUParticles3D.new()
	p.amount = 60
	p.lifetime = life
	p.direction = Vector3(0, 1, 0)
	p.spread = 30.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.8
	p.gravity = Vector3(0, 0.3, 0)
	p.mesh = QuadMesh.new()
	p.material_override = G.fx.billboard_mat(Color(1, 1, 1, 1), false)
	p.color = c
	p.color_ramp = G.fx._fade_ramp(c)
	p.scale_amount_min = size
	p.scale_amount_max = size * 1.5
	p.scale_amount_curve = G.fx._grow_curve(1.0, 4.0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.local_coords = false
	p.preprocess = life
	v.add_child(p)
	p.position = Vector3(0.0, 0.4, -1.0 if v.kind == "bomber" else 0.6)
	p.emitting = true

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
	var es = Build.enemy_site_near(v.team, v.pos, 400.0, true)
	if es != null and es[0]["kind"] in ["hq", "fob", "fob2", "depot", "bunker", "mgnest", "aa"]:
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
	var drop = G.world.park_spot(st["p"], null, start)
	var v = Vehicle.make("truck", team, start, atan2(drop.x - start.x, drop.z - start.z))
	v.mission = {"type": "supply", "drop": drop, "exit": start, "stage": 0, "wait": 0.0, "site": st}
	AI.batch_begin(AI.CREW)
	var drv = G.main.spawn_soldier(team, start.x, start.z, "rifle")
	AI.batch_end()
	if drv == null:
		v.remove()
		return
	drv.mount(v, 0)
	st["truck"] = v
	# crates stacked in the back, so you can see what it's carrying
	var cargo = Node3D.new()
	v.add_child(cargo)
	for k in range(6):
		VModel.box(v, cargo, Vector3(0.95, 0.55, 0.65), Vector3(-0.55 + (k % 2) * 1.1, 1.75, -0.2 - (k / 2) * 1.2), Color(0.3, 0.33, 0.2).darkened(randf_range(0.0, 0.15)), {"b": 0.03})
	v.set_meta("cargo", cargo)
	G.ui.radio(team, "Supply truck on its way to the %s at %s" % [st["name"], AI.grid_ref(st["p"])])

# ---------------------------------------------------------------- smoke, ambulances, command trucks
# armour hit hard throws a smoke screen out ahead and backs off behind it
static func pop_smoke(v, at: Vector3) -> void:
	v.smoke_cd = G.sim_time + 50.0
	var away = G.flat(at - v.pos)
	if away.length_squared() < 0.01:
		away = v.forward()
	away = away.normalized()
	for k in range(3):
		var side = Vector3(-away.z, 0, away.x) * (k - 1) * 5.0
		Combat.smoke_at(v.pos + away * 9.0 + side, 26.0, Color(0.85, 0.85, 0.83), 0.8)
	G.audio.play(G.audio.s_rocket, v.pos, -4.0, 1.6)
	var d = v.driver()
	if d != null and is_instance_valid(d):
		G.fx.callout(d, G.pick(["Popping smoke!", "Smoke, smoke! Reversing!"]))
		if not d.is_player:
			v.reverse_t = 2.5

# ambulances fetch the wounded and run them back to the field hospital (or HQ)
static func medevac(v, dt: float):
	var load = 0
	for i in range(1, v.seats.size()):
		if v.seats[i] != null:
			load += 1
	var hosp = null
	for st in Build.sites:
		if st["team"] == v.team and st["kind"] == "hospital" and Build.alive(st):
			if hosp == null or G.dist2d(st["p"], v.pos) < G.dist2d(hosp["p"], v.pos):
				hosp = st
	var home: Vector3 = hosp["p"] if hosp != null else G.world.spawn[v.team]
	# the nearest wounded soldier nobody is already helping
	var best = null
	var bd = 160.0
	if load < v.seats.size() - 1:
		for s in G.soldiers:
			if s.team == v.team and s.state == "wounded" and s.dragger == null and s.carried_by == null:
				var d = G.dist2d(s.pos, v.pos)
				var near_enemy = false
				for o in G.soldiers:
					if o.team != v.team and o.state == "alive" and G.dist2d(o.pos, s.pos) < 25.0:
						near_enemy = true
						break
				if d < bd and not near_enemy:
					bd = d
					best = s
	if best != null and (load == 0 or bd < 50.0):
		if bd < 5.0 and absf(v.speed) < 1.0:
			var seat = v.free_seat("pass")
			if seat > 0 and best.mount(v, seat):
				G.fx.callout(best, "Thank God…")
			return null
		return best.pos
	if load == 0:
		# wait by the hospital for the next call
		return home if G.dist2d(home, v.pos) > 14.0 else null
	if G.dist2d(home, v.pos) < 12.0 and absf(v.speed) < 1.0:
		for i in range(1, v.seats.size()):
			var p = v.seats[i]
			if p != null and is_instance_valid(p):
				p.dismount(false)
				p.hp = 100.0
				p.heal_t = 0.0
				G.fx.callout(p, G.pick(["Patched up and ready.", "Back in the fight."]))
		G.ui.radio(v.team, "Ambulance: wounded delivered to the aid station")
		return null
	return home

# the command truck parks well behind the line
static func radar_spot(v) -> Vector3:
	var home: Vector3 = G.world.spawn[v.team]
	var r: Vector3 = G.world.rally_point(v.team)
	return home.lerp(r, 0.5) + G.flat(home - Build._objective(v.team)).normalized() * 10.0

# while it's running, the command truck tracks every enemy within a wide radius for the whole team
static func radar_tick(v, dt: float) -> void:
	v.radar_t += dt
	if v.rotor != null:
		v.rotor.rotation.y += dt * 1.6
	if v.radar_t < 2.0:
		return
	v.radar_t = 0.0
	if v.driver() == null and v.seats.size() > 1 and v.seats[1] == null:
		return
	var friend = null
	for s in G.soldiers:
		if s.team == v.team and s.state == "alive":
			friend = s
			break
	if friend == null:
		return
	for o in G.soldiers:
		if o.team != v.team and o.state != "dead" and G.dist2d(o.pos, v.pos) < 170.0:
			for f in G.soldiers:
				if f.team == v.team and f.state == "alive" and f.squad != null and Squad.leader_of(f.squad) == f:
					AI.add_intel(f, o, o.pos, 4.0, false)

static func has_radar(team: int) -> bool:
	for v in G.vehicles:
		if v.kind == "radar" and v.team == team and not v.dead:
			return true
	return false

# ---------------------------------------------------------------- headlights and the mine plough
# two lamps on the front, glowing, with a pale beam each; the nearest few get a real light (see Fx._torches)
static func headlamps(v) -> Node3D:
	var n = Node3D.new()
	v.add_child(n)
	var tracked: bool = v.spec["tracked"]
	var y = 1.25 if tracked else (1.0 if v.kind in ["jeep", "technical", "motorbike"] else 1.1)
	var z = v.spec["len"] * 0.5 + 0.02
	var lamp_m = StandardMaterial3D.new()
	lamp_m.albedo_color = Color(1.0, 0.95, 0.8)
	lamp_m.emission_enabled = true
	lamp_m.emission = Color(1.0, 0.93, 0.75)
	lamp_m.emission_energy_multiplier = 3.0
	var xs = [0.0] if v.kind == "motorbike" else [-v.spec["wid"] * 0.32, v.spec["wid"] * 0.32]
	var lamps = []
	for x in xs:
		var l = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		cm.top_radius = 0.11
		cm.bottom_radius = 0.11
		cm.height = 0.06
		l.mesh = cm
		l.rotation.x = PI / 2.0
		l.position = Vector3(x, y, z)
		l.material_override = lamp_m
		n.add_child(l)
		# the beam, its flare and the pool of light it throws on the road, dipped a little
		var lp = Lamp.make(n, 40.0, 0.2, 0.1, true)
		lp.position = Vector3(x, y, z + 0.04)
		lp.rotation.x = 0.09
		lp.set_meta("mask", G.L_WORLD)
		lamps.append(lp)
	var aim = Node3D.new()
	aim.name = "aim"
	aim.position = Vector3(0, y, z)
	aim.rotation.x = 0.07
	n.add_child(aim)
	n.set_meta("lamps", lamps)
	n.visible = false
	return n

# a rake of steel tines on arms out in front of the hull: it digs up mines and sets them off ahead of the tracks
static func plough_blade(v) -> void:
	var n = Node3D.new()
	v.add_child(n)
	var steel = VModel.mat(Color(0.22, 0.22, 0.2))
	var z = v.spec["len"] * 0.5 + 0.9
	var w = v.spec["wid"] + 0.2
	VModel.box(null, n, Vector3(w, 0.22, 0.25), Vector3(0, 0.45, z), Color(0.22, 0.22, 0.2), {"b": 0.03, "m": steel})
	for x in [-1.0, 1.0]:
		VModel.box(null, n, Vector3(0.18, 0.18, 1.3), Vector3(x * v.spec["wid"] * 0.34, 0.75, z - 0.6), Color(0.22, 0.22, 0.2), {"b": 0.03, "m": steel, "rot": Vector3(-0.35, 0, 0)})
	var k = 0
	var tx = -w * 0.5 + 0.12
	while tx < w * 0.5:
		VModel.box(null, n, Vector3(0.08, 0.4, 0.1), Vector3(tx, 0.22, z + 0.1), Color(0.18, 0.18, 0.17), {"b": 0.01, "m": steel, "rot": Vector3(0.35, 0, 0)})
		tx += 0.26
		k += 1
	v.set_meta("blade", n)

# ---------------------------------------------------------------- what a vehicle leaves behind it
# tread marks and tyre tracks pressed into the ground, the grass flattened under it, and smoke from
# the exhaust: a thick black puff when the driver puts his foot down, a light haze when idling
static func ground_tick(v, dt: float, thr: float) -> void:
	var cam = v.get_viewport().get_camera_3d()
	var near = cam != null and cam.global_position.distance_to(v.pos) < 110.0
	var f = v.forward()
	var right = Vector3(f.z, 0, -f.x)
	if v.driver() != null and near:
		v.exh_t -= dt
		var pushing = absf(thr) > 0.2 and absf(v.speed) < v.spec["speed"] * 0.85
		if v.exh_t <= 0.0:
			v.exh_t = (0.15 if pushing else 0.6) * randf_range(0.8, 1.2)
			var tracked: bool = v.spec["tracked"]
			var pipe = v.pos - f * (v.spec["len"] * 0.5 - (0.2 if tracked else 0.1)) - right * v.spec["wid"] * 0.3 + Vector3(0, 1.35 if tracked else 0.45, 0)
			if v.kind == "motorbike":
				pipe = v.pos - f * 0.75 + right * 0.15 + Vector3(0, 0.35, 0)
			G.fx.exhaust(pipe, -f, 1.0 if pushing else 0.25, tracked or v.kind in ["truck", "halftrack", "supplytruck", "ammotruck"])
	if absf(v.speed) < 0.4 or v.spec.get("static", false):
		return
	v.mark_d += absf(v.speed) * dt
	if v.mark_d < 0.55:
		return
	var step = v.mark_d
	v.mark_d = 0.0
	var tracked2: bool = v.spec["tracked"]
	var half = v.spec["wid"] * 0.5 - (0.32 if tracked2 else 0.24)
	var w = 0.52 if tracked2 else (0.12 if v.kind == "motorbike" else 0.24)
	var rear = v.pos - f * v.spec["len"] * 0.32 * signf(v.speed)
	var xs = [0.0] if v.kind == "motorbike" else [-half, half]
	if near and not G.world.in_water(rear.x, rear.z):
		for x in xs:
			G.fx.track_mark(rear + right * x, f, w, step + 0.12, tracked2)
	G.world.flatten_grass(v.pos, v.spec["wid"] * 0.5 + 0.2, f, 300.0)

# where an ammo truck parks on its own: a little way behind where our infantry are, on the side of home
static func ammo_spot(v) -> Vector3:
	if G.sim_time < v.get_meta("spot_t", -99.0) and v.has_meta("spot"):
		return v.get_meta("spot")
	var c = Vector3.ZERO
	var n = 0
	for s in G.soldiers:
		if s.team == v.team and s.state == "alive" and s.vehicle == null:
			c += s.pos
			n += 1
	var home: Vector3 = G.world.rally_point(v.team)
	var spot = home
	if n > 0:
		c /= n
		var back = G.flat(home - c)
		spot = c + back.normalized() * minf(25.0, back.length()) if back.length() > 1.0 else c
	spot = G.main._free_spot(spot)
	v.set_meta("spot", spot)
	v.set_meta("spot_t", G.sim_time + 12.0)
	return spot
