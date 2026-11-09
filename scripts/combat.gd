class_name Combat
extends RefCounted
# Shooting, damage, kills, rockets, grenades, smoke, mortar strikes and explosions.

static var rockets: Array = []
static var strikes: Array = []
static var shake = 0.0

static func spread_dir(base: Vector3, spread: float) -> Vector3:
	var d = base.normalized()
	var a = Vector3(-d.z, 0, d.x)
	if a.length_squared() < 1e-6:
		a = Vector3.RIGHT
	a = a.normalized()
	var b = d.cross(a)
	var g1 = (randf() + randf() + randf() - 1.5) * 1.15
	var g2 = (randf() + randf() + randf() - 1.5) * 1.15
	return (d + a * g1 * spread + b * g2 * spread).normalized()

# one trigger pull
static func fire_weapon(s, origin: Vector3, dir: Vector3, spread: float) -> void:
	var W = s.W
	if W["rocket"]:
		launch_rocket(s, origin, spread_dir(dir, spread))
	else:
		for k in range(W["pellets"]):
			fire_ray(s, origin, spread_dir(dir, spread + (W["spread"] if W["pellets"] > 1 else 0.0)), W, k == 0 or k % 3 == 0)
	G.fx.muzzle(origin, W["id"] == "shotgun" or W["id"] == "sniper")
	G.audio.shot(origin, W)
	s.parts[6].apply_central_impulse(-s.gun_dir * W["force"] * 0.08)
	# gunfire gives away your rough position to enemies within earshot
	for o in G.soldiers:
		if o == s or o.state == "dead" or o.team == s.team:
			continue
		var d = o.pos.distance_to(origin)
		if d < 45.0:
			AI.add_intel(o, s, origin, 1.5 if d < 15.0 else d * 0.12, false)

static func fire_ray(shooter, o: Vector3, d: Vector3, W: Dictionary, vis: bool) -> void:
	var hit = G.ray(o, o + d * 240.0, G.L_WORLD | G.L_BODY, shooter.rids)
	var t = 240.0
	var hit_s = null
	var part = -1
	var col = null
	var normal = -d
	if not hit.is_empty():
		t = o.distance_to(hit.position)
		normal = hit.normal
		if hit.collider.has_meta("soldier"):
			hit_s = hit.collider.get_meta("soldier")
			part = hit.collider.get_meta("part")
		elif hit.collider.has_meta("col"):
			col = hit.collider.get_meta("col")
	# suppression: bullets passing close make people keep their heads down
	for s in G.soldiers:
		if s == shooter or s.state == "dead":
			continue
		var c = s.chest()
		var tt = clampf((c - o).dot(d), 0.0, t)
		var dd = (o + d * tt).distance_to(c)
		if dd < 3.0:
			s.supp = minf(1.5, s.supp + 0.22 * (1.0 - dd / 3.0) * (1.4 if W["id"] == "lmg" else 1.0))
			if shooter.team != s.team:
				AI.add_intel(s, shooter, shooter.pos, 5.0, false)
	var cam = G.main.get_viewport().get_camera_3d()
	if shooter != G.player and cam:
		var tc = (cam.global_position - o).dot(d)
		if tc > 2.0 and tc < t and (o + d * tc).distance_to(cam.global_position) < 2.5 and randf() < 0.6:
			G.audio.whizz(o + d * tc)
	var hp = o + d * t
	var dmg = W["dmg"]
	if W["id"] == "shotgun" and t > 15.0:
		dmg *= maxf(0.25, 1.0 - (t - 15.0) / 20.0)
	var force = W["force"]
	var on_hit = func():
		if hit_s != null:
			if is_instance_valid(hit_s):
				hit_soldier(hit_s, part, hp, d, dmg, shooter, force)
		elif t < 239.0:
			G.fx.impact(hp, normal)
			if randf() < 0.25 and hp.y > G.world.ground_y(hp.x, hp.z) + 0.1:
				G.audio.ricochet(hp)
			if col != null and col.alive and col.dest and col.hp < 100.0:
				col.hp -= W["dmg"] * 0.08
				if col.hp <= 0.0:
					G.world.destroy_col(col)
	G.fx.tracer(o, d, t, W["tracer"], on_hit, vis)

static func hit_soldier(s, part: int, point: Vector3, dir: Vector3, dmg: float, attacker, force: float) -> void:
	if attacker != null and not is_instance_valid(attacker):
		attacker = null
	var b: RigidBody3D = s.parts[part]
	var imp = dir * force * 1.6
	if s.state == "dead":
		b.apply_impulse(imp * b.mass * 0.6, point - b.global_position)
		G.fx.bleed(point, dir, false)
		return
	var kind = Soldier.PART_KIND[part]
	var mult = 1.0
	if kind == "head":
		mult = 2.5 if (attacker != null and attacker.W["id"] == "sniper") else 4.0
	elif kind == "arm":
		mult = 0.55
	elif kind == "leg":
		mult = 0.6
	s.hp -= dmg * mult
	s.last_attacker = attacker
	s.hurt_t = 3.0
	s.supp = minf(1.5, s.supp + 0.6)
	if attacker != null and attacker.team != s.team:
		AI.add_intel(s, attacker, attacker.pos, 3.0, false)
	G.fx.bleed(point, dir, kind == "head")
	if attacker == G.player and attacker != null:
		G.ui.hit_marker(s.hp <= 0.0)
	if s == G.player:
		G.ui.damage_indicator(attacker.pos if attacker != null else point - dir * 10.0)
	if s.hp <= 0.0:
		kill(s, attacker, kind == "head")
		b.apply_impulse(imp * b.mass * (1.3 if kind == "head" else 1.0), point - b.global_position)
		return
	b.apply_impulse(imp * b.mass * 0.8, point - b.global_position)
	if s.state == "alive" or s.state == "riding":
		s.limb[Soldier.PART_REG[part]] = 0.05
		if kind == "torso" or kind == "head":
			s.stun = maxf(s.stun, 0.18 + force * 0.03)
		if kind == "leg" and randf() < 0.3:
			s.fall()
		elif force > 6.0 and randf() < 0.5:
			s.fall()
		if s.state == "alive" and randf() < 0.4:
			G.fx.callout(s, G.pick(["I'm hit!", "Argh!", "Taking fire!"]))
	else:
		if s.state == "getup":
			s.fall(1.0)
		if s.state == "down":
			s.down_t = maxf(s.down_t, 1.0)

static func kill(s, attacker, head: bool) -> void:
	if s.state == "dead":
		return
	if attacker != null and not is_instance_valid(attacker):
		attacker = null
	s.go_dead()
	if attacker != null and attacker.team != s.team:
		G.score[attacker.team] += 1
	G.main.on_kill(s, attacker)
	G.ui.feed(attacker, s, head)
	G.fx.decal(s.parts[0].global_position, randf_range(0.6, 1.0), false)
	if attacker != null and attacker.team != s.team and attacker.state == "alive" and randf() < 0.3:
		G.fx.callout(attacker, G.pick(["Target down!", "Got him!", "Enemy down!"]))
	for o in G.soldiers:
		o.intel.erase(s)
	for o in G.soldiers:
		if o != s and o.team == s.team and o.is_up() and o.pos.distance_squared_to(s.pos) < 225.0 and randf() < 0.4:
			G.fx.callout(o, G.pick(["Man down!", s.sname + "'s down!", "We lost " + s.sname + "!"]))
			break
	if s == G.player:
		G.ui.message("You were killed in action")
		var wr = weakref(s)
		G.main.get_tree().create_timer(2.6, false).timeout.connect(func():
			var o = wr.get_ref()
			if o != null and G.player == o:
				G.pc.leave_soldier())

# ---------------------------------------------------------------- rockets
static func launch_rocket(s, origin: Vector3, dir: Vector3) -> void:
	var m = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(0.1, 0.1, 0.5)
	m.mesh = bm
	var mat = StandardMaterial3D.new()
	mat.albedo_color = G.C_GREEN
	m.material_override = mat
	G.fx.add_child(m)
	m.global_position = origin
	rockets.append({"p": origin, "v": dir * 48.0, "owner": s, "mesh": m, "life": 5.0, "trail": 0.0})
	G.fx.dust_cloud(origin - dir * 1.4, 1.5)
	G.audio.rocket(origin)
	if not s.is_player:
		s.rockets -= 1

static func step_rockets() -> void:
	for i in range(rockets.size() - 1, -1, -1):
		var r = rockets[i]
		r["life"] -= G.DT
		r["v"].y += G.GRAV * 0.15 * G.DT
		var stepv: Vector3 = r["v"] * G.DT
		var ex: Array = []
		if is_instance_valid(r["owner"]):
			ex = r["owner"].rids
		var hit = G.ray(r["p"], r["p"] + stepv, G.L_WORLD | G.L_BODY, ex)
		if not hit.is_empty() or r["life"] <= 0.0:
			var at: Vector3 = r["p"] if hit.is_empty() else hit.position
			if not hit.is_empty() and hit.collider.has_meta("soldier"):
				var hs = hit.collider.get_meta("soldier")
				if hs.state != "dead":
					hs.hp -= 60.0
					if hs.hp <= 0.0:
						kill(hs, r["owner"], false)
			explode(at - stepv.normalized() * 0.1, r["owner"], 1.25)
			r["mesh"].queue_free()
			rockets.remove_at(i)
			continue
		r["p"] += stepv
		r["mesh"].global_position = r["p"]
		r["mesh"].look_at(r["p"] + stepv, Vector3.UP if absf(stepv.normalized().y) < 0.95 else Vector3.RIGHT)
		r["trail"] -= G.DT
		if r["trail"] <= 0.0:
			r["trail"] = 0.05
			G.fx.dust_cloud(r["p"], 0.5)

# ---------------------------------------------------------------- mortar strikes
static func mortar_strike(center: Vector3, n: int) -> void:
	for i in range(n):
		var a = randf() * TAU
		var r = sqrt(randf()) * 9.0
		var p = Vector3(center.x + cos(a) * r, 0, center.z + sin(a) * r)
		p.y = G.world.ground_y(p.x, p.z) + 0.1
		strikes.append({"p": p, "t": 1.4 + i * randf_range(0.4, 0.8), "whistled": false})

static func step_strikes() -> void:
	for i in range(strikes.size() - 1, -1, -1):
		var s = strikes[i]
		s["t"] -= G.DT
		if not s["whistled"] and s["t"] < 1.15:
			s["whistled"] = true
			G.audio.whistle(s["p"])
		if s["t"] <= 0.0:
			explode(s["p"], null, 1.35)
			strikes.remove_at(i)

# ---------------------------------------------------------------- grenades and smoke
static func throw_grenade(s, target: Vector3, type: String) -> void:
	var start = s.head_pos() + Vector3(0, 0.1, 0)
	var dist = G.dist2d(target, start)
	var T = clampf(0.6 + dist * 0.035, 0.7, 1.6)
	var v = Vector3((target.x - start.x) / T, (target.y + 0.2 - start.y) / T - 0.5 * G.GRAV * T, (target.z - start.z) / T)
	var g = RigidBody3D.new()
	g.collision_layer = G.L_DEBRIS
	g.collision_mask = G.L_WORLD | G.L_DEBRIS
	g.mass = 0.5
	g.continuous_cd = true
	var cs = CollisionShape3D.new()
	var bs = BoxShape3D.new()
	bs.size = Vector3(0.12, 0.16, 0.12)
	cs.shape = bs
	g.add_child(cs)
	var m = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = bs.size
	m.mesh = bm
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.57, 0.53) if type == "smoke" else Color(0.18, 0.21, 0.14)
	m.material_override = mat
	g.add_child(m)
	g.set_meta("type", type)
	g.set_meta("fuse", 1.6 if type == "smoke" else 2.6)
	g.set_meta("owner", s)
	G.fx.add_child(g)
	g.global_position = start
	g.linear_velocity = v
	g.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
	G.grenades.append(g)
	if type == "smoke":
		s.smokes -= 1
	else:
		s.grenades -= 1
	s.throw_t = 0.55
	G.fx.callout(s, "Popping smoke!" if type == "smoke" else "Grenade out!")

static func smoke_at(p: Vector3, life: float) -> void:
	var sc = SmokeCloud.new()
	sc.p = p + Vector3(0, 1.0, 0)
	sc.r = 0.5
	sc.t = life
	sc.node = G.fx.smoke_screen(p + Vector3(0, 0.5, 0), life - 4.0)
	G.smoke_clouds.append(sc)

static func step_grenades() -> void:
	for i in range(G.grenades.size() - 1, -1, -1):
		var g = G.grenades[i]
		if not is_instance_valid(g):
			G.grenades.remove_at(i)
			continue
		var fuse = g.get_meta("fuse") - G.DT
		g.set_meta("fuse", fuse)
		if fuse <= 0.0:
			var owner_s = g.get_meta("owner")
			if owner_s != null and not is_instance_valid(owner_s):
				owner_s = null
			if g.get_meta("type") == "smoke":
				smoke_at(g.global_position, 24.0)
			else:
				explode(g.global_position, owner_s, 1.0)
			g.queue_free()
			G.grenades.remove_at(i)
	for i in range(G.smoke_clouds.size() - 1, -1, -1):
		var c = G.smoke_clouds[i]
		c.t -= G.DT
		c.r = minf(5.5, c.r + G.DT * 2.2)
		if c.t < 4.0:
			c.r = maxf(0.0, c.r - G.DT * 1.3)
		if c.t <= 0.0:
			G.smoke_clouds.remove_at(i)

# ---------------------------------------------------------------- explosions
static func explode(pos: Vector3, owner_s, power: float) -> void:
	var R = 7.0 * power
	G.fx.explosion(pos, power)
	G.audio.boom(pos)
	var cam = G.main.get_viewport().get_camera_3d()
	if cam:
		shake = maxf(shake, clampf(1.2 - cam.global_position.distance_to(pos) / 40.0, 0.0, 1.0))
	G.world.damage_area(pos, R * 0.75, power)
	for s in G.soldiers:
		var d = s.parts[0].global_position.distance_to(pos)
		if owner_s != null and s.state != "dead" and s.team != owner_s.team and d < 60.0:
			AI.add_intel(s, owner_s, owner_s.pos, 10.0, false)
		if d > R * 1.7:
			continue
		var exposed = not G.blocked(pos + Vector3(0, 0.4, 0), s.chest())
		var f = (1.0 - d / (R * 1.7)) * (1.0 if exposed else 0.35)
		if s.state != "dead":
			s.supp = 1.5
			if d < R:
				s.hp -= 170.0 * (1.0 - d / R) * (1.0 if exposed else 0.3)
				if s == G.player:
					G.ui.damage_indicator(pos)
			if s.hp <= 0.0:
				kill(s, owner_s if owner_s != s else null, false)
			elif f > 0.3:
				s.fall(randf_range(1.8, 3.0))
			elif s.state == "alive":
				s.stun = maxf(s.stun, 0.3)
		s.wake()
		for b in s.parts:
			var away: Vector3 = b.global_position - pos
			away.y = maxf(away.y, 0.0) + 0.8
			b.apply_central_impulse(away.normalized() * 14.0 * f * randf_range(0.8, 1.2) * b.mass * (0.6 if s.state == "alive" else 1.0))
	for d in G.fx.debris_list:
		if is_instance_valid(d["b"]) and d["b"].global_position.distance_to(pos) < R:
			var aw: Vector3 = d["b"].global_position - pos
			d["b"].apply_central_impulse(aw.normalized() * 6.0 * d["b"].mass * (1.0 - aw.length() / R) + Vector3(0, 3, 0))

static func clear_all() -> void:
	for r in rockets:
		if is_instance_valid(r["mesh"]):
			r["mesh"].queue_free()
	rockets.clear()
	strikes.clear()
	for g in G.grenades:
		if is_instance_valid(g):
			g.queue_free()
	G.grenades.clear()
	G.smoke_clouds.clear()
