class_name Combat
extends RefCounted
# Shooting, damage, kills, rockets, grenades, smoke, mortar strikes and explosions.

static var rockets: Array = []
static var strikes: Array = []
static var shake = 0.0
static var flares: Array = []
static var mines: Array = []
static var arty = false            # the blast going off is an artillery or mortar shell
static var fires: Array = []       # burning hedges, crates and huts

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
	if not s.zombie:
		spread *= s.steady()
		if s.team > 0 and not s.is_player:
			spread *= float(Commander.handicap(s.team)["aim"])
	s.fired_t = G.sim_time
	if s.cls == "sniper":
		s.shots_here += 1
	if W["id"] == "lmg":
		s.heat += 0.012
		if s.heat >= 1.0:
			# too hot to fire: swap the barrel (shown as a reload)
			s.heat = 0.3
			s.fire_cd = 4.5
			s.reload_t = W["reload"]
			if s == G.player:
				G.ui.message("Barrel overheated! Changing it…")
			else:
				G.fx.callout(s, G.pick(["Changing barrel!", "Barrel's cooked!"]))
	if W["flame"]:
		flame(s, origin, dir)
		return
	if W["rocket"]:
		launch_rocket(s, origin, spread_dir(dir, spread))
	elif W["gl"]:
		# lobbed: aimed at where the target stands (or a long way out along the aim), not straight at it
		var tp: Vector3 = origin + dir * 45.0
		if s.target != null and is_instance_valid(s.target) and not s.is_player:
			tp = s.target.pos + Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5))
		if G.dist2d(tp, origin) < 14.0:
			tp = origin + G.flat(dir).normalized() * 14.0      # never lob one at his own feet
		elif s.is_player and G.pc != null:
			tp = G.pc.aim_point
		launch_rifle_grenade(s, origin, tp)
		s.parts[6].apply_central_impulse(-s.gun_dir * W["force"] * 0.08)
		return
	else:
		# machine guns load every fourth round as a tracer that glows hot enough to see from the air
		bright = W["id"] in ["lmg", "hmg", "bar"] and s.mag % 4 == 0
		for k in range(W["pellets"]):
			fire_ray(s, origin, spread_dir(dir, spread + (W["spread"] if W["pellets"] > 1 else 0.0)), W, k == 0 or k % 3 == 0)
		bright = false
	if not W.get("silent", false):
		G.fx.muzzle(origin, W["id"] == "shotgun" or W["id"] == "sniper")
		G.audio.shot(origin, W)
	else:
		G.audio.play(G.audio.s_step, origin, -6.0, 2.6)
	if not W["rocket"] and not W["flame"]:
		var rt = s.gun_dir.cross(Vector3.UP).normalized()
		G.fx.casing(origin - s.gun_dir * (W["len"] * 0.55), -rt)
	s.parts[6].apply_central_impulse(-s.gun_dir * W["force"] * 0.08)
	# gunfire gives away your rough position to enemies within earshot
	for o in G.soldiers:
		if o == s or o.state == "dead" or o.team == s.team:
			continue
		var d = o.pos.distance_to(origin)
		if d < (6.0 if W.get("silent", false) else 45.0):
			AI.add_intel(o, s, origin, 1.5 if d < 15.0 else d * 0.12, false)

# how much material a bullet can punch through (metres of plain wall); wood and foliage count for much less
const PEN = {"rifle": 0.34, "lmg": 0.42, "sniper": 0.75, "shotgun": 0.08, "rpg": 0.0, "hmg": 0.55, "smg": 0.2, "pistol": 0.12, "atrifle": 1.3, "flamer": 0.0, "pfaust": 0.0,
	"carbine": 0.24, "bar": 0.4, "dmr": 0.6, "gl": 0.0}
const MAT_FACTOR = [1.0, 0.3, 0.1]   # solid, wood, foliage

# metres of the ray o + d*t inside an axis-aligned box, starting from entry distance t0
static func _box_exit(o: Vector3, d: Vector3, lo: Vector3, hi: Vector3) -> float:
	var t_exit = 1e9
	for k in range(3):
		var dk = d[k]
		if absf(dk) < 1e-6:
			continue
		var t1 = (lo[k] - o[k]) / dk
		var t2 = (hi[k] - o[k]) / dk
		t_exit = minf(t_exit, maxf(t1, t2))
	return t_exit

static var bright = false     # the next round fired is a glowing tracer

static func fire_ray(shooter, o: Vector3, d: Vector3, W: Dictionary, vis: bool, extra_ex: Array = []) -> void:
	var exclude: Array = shooter.rids.duplicate()
	exclude.append_array(extra_ex)
	if shooter.vehicle != null and is_instance_valid(shooter.vehicle):
		exclude.append(shooter.vehicle.body.get_rid())
	var dmg = W["dmg"]
	var pen = PEN.get(W["id"], 0.3)
	var events: Array = []
	var t_end = 240.0
	var from = o
	for step in range(4):
		var hit = G.ray(from, o + d * 240.0, G.L_WORLD | G.L_BODY | G.L_VEH | Doors.L_GLASS, exclude)
		if hit.is_empty():
			break
		var t = o.distance_to(hit.position)
		# window glass breaks and the round carries on; a wooden door slows it a little
		if hit.collider.has_meta("pane"):
			Doors.shatter(hit.collider.get_meta("pane"))
			exclude.append(hit.rid)
			from = hit.position + d * 0.05
			continue
		if hit.collider.has_meta("door"):
			Doors.shot(hit.collider.get_meta("door"), dmg, hit.position, d)
			exclude.append(hit.rid)
			from = hit.position + d * 0.12
			dmg *= 0.75
			continue
		if hit.collider.has_meta("vehicle"):
			events.append({"t": t, "veh": hit.collider.get_meta("vehicle"), "p": hit.position, "n": hit.normal, "dmg": dmg})
			t_end = t
			break
		if W["id"] == "shotgun" and t > 15.0:
			dmg = W["dmg"] * maxf(0.25, 1.0 - (t - 15.0) / 20.0)
		if hit.collider.has_meta("soldier"):
			events.append({"t": t, "s": hit.collider.get_meta("soldier"), "part": hit.collider.get_meta("part"), "p": hit.position, "dmg": dmg})
			t_end = t
			break
		var col = hit.collider.get_meta("col") if hit.collider.has_meta("col") else null
		events.append({"t": t, "p": hit.position, "n": hit.normal, "col": col, "dmg": dmg})
		t_end = t
		if col == null or not col.alive or pen <= 0.0:
			break
		# thin enough to punch through?
		var t_out = _box_exit(o, d, col.lo, col.hi)
		var thick = maxf(0.0, t_out - t)
		var eff = thick * MAT_FACTOR[clampi(col.prop, 0, 2)]
		if thick <= 0.0 or eff >= pen:
			break
		dmg *= 1.0 - 0.7 * eff / pen
		pen -= eff
		exclude.append(hit.rid)
		from = o + d * (t_out + 0.02)
		events.append({"t": t_out, "p": o + d * t_out, "n": d, "col": null, "dmg": 0.0, "exit": true})
		t_end = 240.0
	# suppression: bullets passing close make people keep their heads down
	for s in G.soldiers:
		if s == shooter or s.state == "dead":
			continue
		var c = s.chest()
		var tt = clampf((c - o).dot(d), 0.0, t_end)
		var dd = (o + d * tt).distance_to(c)
		if dd < 3.0:
			var add = 0.22 * (1.0 - dd / 3.0) * (1.4 if W["id"] == "lmg" else 1.0)
			s.supp = minf(1.5, s.supp + add)
			if shooter.team != s.team:
				AI.add_intel(s, shooter, shooter.pos, 5.0, false)
				Morale.shock(s, add * 9.0)
				# a crack overhead: heads snap round toward where it came from
				s.look_p = shooter.pos
				s.look_t = 1.4
				# ground under heavy fire is remembered as a bad place to cross
				if s.supp > 0.9 and G.sim_time > s.danger_note_t:
					s.danger_note_t = G.sim_time + 4.0
					Tactics.note_fire(s)
	var cam = G.main.get_viewport().get_camera_3d()
	if shooter != G.player and cam:
		var tc = (cam.global_position - o).dot(d)
		if tc > 2.0 and tc < t_end:
			var miss = (o + d * tc).distance_to(cam.global_position)
			# rifle-calibre rounds crack as they go past; pistol and SMG rounds just whizz
			if miss < 7.0 and W["id"] in ["rifle", "lmg", "sniper", "hmg", "atrifle"] and tc > 15.0:
				G.audio.crack(o + d * tc, miss)
			elif miss < 2.5 and randf() < 0.6:
				G.audio.whizz(o + d * tc)
	var force = W["force"]
	Stats.shot(shooter)
	var on_hit = func():
		for ev in events:
			if ev.has("veh"):
				var v = ev["veh"]
				if is_instance_valid(v):
					# a stray round from our own side mostly just dents the paint
					var own_side = shooter != null and is_instance_valid(shooter) and "team" in shooter and shooter.team == v.team
					v.take_damage(ev["dmg"] * (0.9 if W["ap"] else v.spec["bullet"]) * (0.15 if own_side else 1.0), shooter, ev["p"])
					if not v.dead or randf() < 0.3:
						VehExt.bullet_hole(v, ev["p"], ev["n"], W["ap"] or W["id"] == "hmg")
					# rounds that can't get through whine off the armour
					if not W["ap"] and v.spec["bullet"] < 0.2 and randf() < 0.5:
						var rd = d.bounce(ev["n"]).normalized()
						rd = (rd + Vector3(randf_range(-0.3, 0.3), randf_range(0.0, 0.4), randf_range(-0.3, 0.3))).normalized()
						G.fx.tracer(ev["p"], rd, randf_range(6.0, 25.0), 260.0, Callable(), true)
						G.audio.ricochet(ev["p"])
				G.fx.impact(ev["p"], ev["n"])
				if randf() < 0.4:
					G.audio.ricochet(ev["p"])
			elif ev.has("s"):
				var hs = ev["s"]
				if is_instance_valid(hs):
					hit_soldier(hs, ev["part"], ev["p"], d, ev["dmg"], shooter, force)
			else:
				var ip: Vector3 = ev["p"]
				# into the water: a little spout where it went in, not a puff of dirt off the bottom
				if not G.world.water.is_empty() and G.world.in_water(ip.x, ip.z) and ip.y < G.world.water_level(ip.x, ip.z) + 0.05:
					if randf() < 0.6:
						G.fx.splash(Vector3(ip.x, G.world.water_level(ip.x, ip.z), ip.z), 0.35)
					continue
				G.fx.impact(ev["p"], ev["n"])
				if ev.has("exit"):
					continue
				if randf() < 0.25 and ev["p"].y > G.world.ground_y(ev["p"].x, ev["p"].z) + 0.1:
					G.audio.ricochet(ev["p"])
				var col = ev["col"]
				if col != null and col.alive and col.has_meta("boom"):
					# a fuel drum holed: a few rounds and it goes up
					col.hp -= W["dmg"] * (0.5 if W.get("ap", false) else 0.3)
					G.fx.flame_puff(ev["p"], ev["n"] * 1.5, 0.3)
					if col.hp <= 0.0:
						G.world.destroy_col(col)
				elif col != null and col.alive and col.dest and col.hp < 100.0 and not col.has_meta("built"):
					col.hp -= W["dmg"] * 0.08
					if col.hp <= 0.0:
						G.world.destroy_col(col)
				elif col != null and col.alive and col.dest and col.has_meta("built") and W.get("ap", false):
					col.hp -= W["dmg"] * 0.05
					if col.hp <= 0.0:
						G.world.destroy_col(col)
	G.fx.tracer(o, d, t_end, W["tracer"], on_hit, vis, bright)

# keep ragdolls from flying off like rockets
static func _cap(s, maxv: float) -> void:
	for b in s.parts:
		var v: Vector3 = b.linear_velocity
		if v.length() > maxv:
			b.linear_velocity = v.normalized() * maxv
		if b.linear_velocity.y > maxv * 0.6:
			b.linear_velocity.y = maxv * 0.6

static func hit_soldier(s, part: int, point: Vector3, dir: Vector3, dmg: float, attacker, force: float) -> void:
	if attacker != null and not is_instance_valid(attacker):
		attacker = null
	var b: RigidBody3D = s.parts[part]
	var imp = dir * force * 1.6
	if s.state == "dead":
		s.unsettle()
		b.apply_impulse(imp * b.mass * 0.25, point - b.global_position)
		_cap(s, 5.0)
		G.fx.bleed(point, dir, false)
		return
	var kind = Soldier.PART_KIND[part]
	var mult = 1.0
	if kind == "head":
		mult = 2.8 if (attacker != null and attacker.W["id"] == "sniper") else 3.2
	elif kind == "arm":
		mult = 0.55
	elif kind == "leg":
		mult = 0.6
	if s.zombie and s.ztype == "armored" and kind == "torso":
		mult *= 0.3          # riot armour: aim for the head
	# battles last longer: everyone takes a bit more punishment than before
	dmg *= 0.62
	s.hp -= dmg * mult * (0.35 if s == Modes.pilot else 1.0)     # the pilot has a flak vest (and the game is no fun if he drops at once)
	if kind == "torso" or kind == "leg" or kind == "arm":
		s.wound_part = part
	# a round through the leg: he can still move, but only at a hobble until a medic sees to it
	if kind == "leg" and s.state == "alive" and dmg * mult > 8.0 and not s.zombie:
		s.set_meta("leg_wound", true)
	Stats.hit(attacker, s, dmg * mult)
	Morale.shock(s, 10.0)
	s.last_attacker = attacker
	s.hurt_t = 3.0
	s.supp = minf(1.5, s.supp + 0.6)
	if attacker != null and attacker.team != s.team:
		AI.add_intel(s, attacker, attacker.pos, 3.0, false)
	G.fx.bleed(point, dir, kind == "head")
	if attacker != null and attacker.team != s.team and randf() < 0.3:
		Ops.note_attack(s.team, attacker.pos)
	if attacker == G.player and attacker != null:
		G.ui.hit_marker(s.hp <= 0.0)
	if s == G.player:
		G.ui.damage_indicator(attacker.pos if attacker != null else point - dir * 10.0)
	if s.hp <= 0.0:
		if kind != "head" and randf() < 0.45:
			G.audio.voice(s, "scream")
		kill(s, attacker, kind == "head")
		b.apply_impulse(imp * b.mass * (0.5 if kind == "head" else 0.4), point - b.global_position)
		_cap(s, 5.5)
		return
	Medical.wound(s, dmg * mult)
	if randf() < 0.4:
		G.audio.voice(s, "pain")
	b.apply_impulse(imp * b.mass * 0.8, point - b.global_position)
	if s.state == "alive" or s.state == "riding":
		s.limb[Soldier.PART_REG[part]] = 0.05
		if kind == "torso" or kind == "head":
			s.stun = maxf(s.stun, 0.18 + force * 0.03)
		var running = s.state == "alive" and s.want.length() > 3.5
		if kind == "leg" and randf() < (0.55 if running else 0.3):
			s.fall()
		elif force > 6.0 and randf() < 0.5:
			s.fall()
		elif running and randf() < 0.35:
			# stumble: hit mid-stride, they go down hard and scramble up
			s.fall(randf_range(0.6, 1.1))
			s.push(1, dir * 2.5 + Vector3(0, 0.5, 0), 0.4)
		elif s.state == "alive":
			# stays up: a flinch away from the hit, a step or two off balance, or a drop to one knee
			var rr = randf()
			if kind == "leg" or rr < 0.3:
				s.crouch = maxf(s.crouch, 0.8)
				s.stumble = 0.25
				s.stumble_dir = G.flat(dir).normalized()
			elif rr < 0.7:
				s.stumble = 0.35
				s.stumble_dir = G.flat(dir).normalized()
			else:
				s.aim_yaw += randf_range(-0.5, 0.5)       # spun half round by the impact
			# where it hit decides the jolt: a shoulder or arm twists him round toward that side, a round
			# in the chest from the front rocks him back a step, the head snaps back
			var local_hit: Vector3 = point - s.chest()
			var rgt = Vector3(cos(s.body_yaw), 0, -sin(s.body_yaw))
			if kind == "arm":
				var side = signf(local_hit.dot(rgt))
				s.body_yaw += side * randf_range(0.35, 0.7)
				s.aim_yaw = s.body_yaw
				s.parts[1].angular_velocity += Vector3.UP * side * randf_range(2.0, 3.5)
			elif kind == "torso":
				s.stumble = maxf(s.stumble, 0.3)
				s.stumble_dir = G.flat(dir).normalized()
			elif kind == "head":
				s.parts[2].apply_central_impulse(G.flat(dir).normalized() * 1.2 * s.parts[2].mass)
		if s.state == "alive" and randf() < 0.45:
			match kind:
				"leg":
					G.fx.callout(s, G.pick(["My leg! I'm hit!", "Argh, my leg!", "Took one in the leg!"]))
				"arm":
					G.fx.callout(s, G.pick(["Took one in the arm!", "My arm! I can still shoot!", "Argh! Arm's hit!"]))
				"head":
					G.fx.callout(s, G.pick(["Grazed me! I'm okay!", "Christ, that was close!"]))
				_:
					G.fx.callout(s, G.pick(["I'm hit!", "Argh!", "I'm hit, I'm hit!", "Hit! Still in it!"]))
	else:
		if s.state == "getup":
			s.fall(1.0)
		if s.state == "down":
			s.down_t = maxf(s.down_t, 1.0)

static var cause = ""          # what the next kill was done with, for the kill feed ("" = the attacker's gun)

# the last man to fall and the last big blast: where the camera goes for the slow-motion finish
static var last_kill = {"t": -99.0, "p": Vector3.ZERO, "name": "", "team": -1}
static var last_boom = {"t": -99.0, "p": Vector3.ZERO, "pow": 0.0}

static func kill(s, attacker, head: bool) -> void:
	if s.state == "dead":
		return
	if not s.zombie or G.mode == "horde":
		last_kill = {"t": G.sim_time, "p": s.pos, "name": s.sname, "team": s.team}
	if attacker != null and not is_instance_valid(attacker):
		attacker = null
	# zombie mode: kills earn points to spend between waves
	if G.mode == "horde" and s.zombie and attacker != null and attacker.team == 0:
		Support.earn(0, {"brute": 4, "armored": 3, "bloater": 2, "spitter": 2}.get(s.ztype, 1))
	Tactics.note_death(s)
	if s.squad != null:
		s.squad["loss_t"] = G.sim_time
	if s.zombie and s.ztype == "bloater" and not s.has_meta("burst"):
		# a bloater bursts: a gas blast that knocks down (and hurts) anyone close, zombies included
		s.set_meta("burst", true)
		var bp: Vector3 = s.chest()
		G.fx.smoke_screen(bp, 6.0, Color(0.55, 0.62, 0.3), 0.6)
		(func(): Combat.explode(bp, null, 0.55)).call_deferred()
	s.go_dead()
	if attacker == null or attacker.team != s.team:
		Ops.note_loss(s, attacker, cause if cause != "" else ("arty" if arty else ""))
	if attacker != null and attacker.team != s.team:
		attacker.kills += 1
	Stats.killed(s, attacker, head)
	Morale.on_death(s, attacker)
	if attacker != null and attacker.team != s.team:
		G.score[attacker.team] += 1
		# (not against the horde: a zombie has its own price above. With this on top and the trickle, a
		# game played in the browser had 1,100 points unspent by wave 7, with men at 6 points each.)
		if G.mode != "horde":
			Support.earn(attacker.team, 2)
	G.main.on_kill(s, attacker)
	G.ui.feed(attacker, s, head, "", cause)
	cause = ""
	Medical.try_save(s)
	G.fx.decal(s.parts[0].global_position, randf_range(0.6, 1.0), false)
	if attacker != null and attacker.team != s.team and attacker.state == "alive" and randf() < 0.3:
		Voice.say(attacker, "kill")
	for o in G.soldiers:
		o.intel.erase(s)
	for o in G.soldiers:
		if o != s and o.team == s.team and o.is_up() and o.pos.distance_squared_to(s.pos) < 225.0 and randf() < 0.4:
			Voice.say(o, "man_down", [s.sname])
			break
	if s == G.player:
		G.ui.message("You were killed in action")
		var wr = weakref(s)
		G.main.get_tree().create_timer(2.6, false).timeout.connect(func():
			var o = wr.get_ref()
			if o != null and G.player == o:
				G.pc.leave_soldier())

# ---------------------------------------------------------------- knives
# a quiet kill up close; from behind (or on someone busy elsewhere) it's over at once
static func knife(s, t) -> void:
	if t == null or t.state == "dead" or s.state != "alive":
		return
	s.throw_t = 0.4
	s.set_meta("throw_T", 0.55)
	var f = Vector3(sin(t.body_yaw), 0, cos(t.body_yaw))
	var from_behind = f.dot(G.flat(s.pos - t.pos).normalized()) < 0.2 or t.vis_t != s
	G.audio.play(G.audio.s_hit, t.chest(), -10.0, 0.6)
	if from_behind:
		t.hp = 0.0
		cause = "knife"
		kill(t, s, false)
	else:
		hit_soldier(t, 1, t.chest(), G.flat(t.pos - s.pos).normalized(), 110.0, s, 1.5)
	s.fire_cd = 0.9

# stored ammunition or fuel going up after the first blast: a string of bangs over a few seconds,
# each one able to set off the next drum, dump or vehicle along
static func cook_off(p: Vector3, n: int, power: float, spread: float, delay: float = 0.6) -> void:
	G.bal_add("cook")
	for k in range(n):
		var t = G.main.get_tree().create_timer(delay + k * randf_range(0.35, 0.9) + randf() * 0.4, false)
		t.timeout.connect(func():
			if not G.started:
				return
			var q = p + Vector3(randf_range(-spread, spread), randf_range(0.2, 1.0), randf_range(-spread, spread))
			explode(q, null, power * randf_range(0.6, 1.1))
			for j in range(4):
				G.fx.flame_puff(q, Vector3(randf_range(-3, 3), randf_range(3, 8), randf_range(-3, 3)), 1.1))

# a bayonet thrust: a lunge forward, and it goes in hard from any side
static func bayonet(s, t) -> void:
	if t == null or t.state == "dead" or s.state != "alive":
		return
	s.throw_t = 0.35
	s.set_meta("throw_T", 0.55)
	s.stumble = 0.25
	s.stumble_dir = G.flat(t.pos - s.pos).normalized()
	G.audio.play(G.audio.s_hit, t.chest(), -8.0, 0.55)
	cause = "bayonet"
	hit_soldier(t, 1, t.chest(), G.flat(t.pos - s.pos).normalized(), randf_range(95.0, 150.0), s, 2.0)
	cause = ""
	s.fire_cd = 1.0

# A shove with the rifle butt: for something right on top of him (a zombie, or anyone when his gun's
# empty). It hurts, and it knocks the other man back a couple of steps so there's room to shoot.
static var shove_n = 0
static func shove(s, t) -> void:
	if t == null or t.state == "dead" or s.state != "alive":
		return
	shove_n += 1
	var dir = G.flat(t.pos - s.pos).normalized()
	s.throw_t = 0.42
	s.set_meta("throw_T", 0.42)
	s.set_meta("thrust", true)
	s.stumble = 0.12
	s.stumble_dir = dir
	G.audio.play(G.audio.s_hit, t.chest(), -9.0, 0.8)
	G.audio.voice(s, "grunt")
	cause = "rifle butt"
	hit_soldier(t, 1, t.chest(), dir, randf_range(14.0, 24.0), s, 3.0)
	cause = ""
	if t.state == "alive":
		if t.zombie and randf() < 0.5:
			# (knocked clean off its feet: it's a second or so getting up again)
			t.fall(randf_range(0.7, 1.2))
			t.push(1, dir * 3.0 + Vector3(0, 0.5, 0), 0.4)
		else:
			# (sent staggering back a good step and a half)
			t.stumble = 0.75
			t.stumble_dir = dir
			t.vel = dir * 6.5
			t.stun = maxf(t.stun, 0.5)
	s.fire_cd = maxf(s.fire_cd, 0.45)
	s.set_meta("shove_t", G.sim_time + 1.3)
	if randf() < 0.3:
		G.fx.callout(s, G.pick(["Get off!", "Back!", "Get back!", "Off me!"]))

# The entrenching tool: what a man fights with when there's nothing left to fire. Swung two-handed, edge
# on, it puts a man or one of the dead on the ground more often than not.
static var spade_n = 0
static func spade(s, t) -> void:
	if t == null or t.state == "dead" or s.state != "alive":
		return
	spade_n += 1
	var dir = G.flat(t.pos - s.pos).normalized()
	s.throw_t = 0.5
	s.set_meta("throw_T", 0.5)
	s.set_meta("thrust", true)
	s.set_meta("spade", true)
	s.stumble = 0.15
	s.stumble_dir = dir
	G.audio.play(G.audio.s_hit, t.chest(), -5.0, 0.55)
	G.audio.voice(s, "grunt")
	cause = "entrenching tool"
	hit_soldier(t, 1 if randf() < 0.6 else 2, t.chest(), dir, randf_range(55.0, 95.0), s, 4.0)
	cause = ""
	if t.state == "alive" and randf() < 0.6:
		t.fall(randf_range(0.8, 1.4))
		t.push(1, dir * 3.0 + Vector3(0, 0.5, 0), 0.4)
	s.fire_cd = maxf(s.fire_cd, 0.6)
	s.set_meta("shove_t", G.sim_time + 1.0)

# has he anything left to shoot with at all
static func dry(s) -> bool:
	return s.mag <= 0 and s.reserve <= 0 and s.reload_t <= 0.0

# ---------------------------------------------------------------- rockets
static func launch_rocket(s, origin: Vector3, dir: Vector3, veh = null) -> void:
	var faust = veh == null and s.wid == "pfaust"
	var m = G.fx.rocket_model(faust)
	G.fx.add_child(m)
	m.global_position = origin
	m.look_at(origin + dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT)
	if faust:
		# a short, loopy flight and a big shaped charge
		rockets.append({"p": origin, "v": dir * 34.0, "owner": s, "veh": veh, "mesh": m, "life": 3.0, "trail": 0.0, "g": 0.35, "vdmg": 760.0, "power": 1.1})
	else:
		rockets.append({"p": origin, "v": dir * 48.0, "owner": s, "veh": veh, "mesh": m, "life": 5.0, "trail": 0.0})
	G.fx.dust_cloud(origin - dir * 1.4, 1.2)
	G.audio.rocket(origin)
	if faust:
		s.call_deferred("spent_faust")
	elif not s.is_player and veh == null:
		s.rockets -= 1

static func step_rockets() -> void:
	for i in range(rockets.size() - 1, -1, -1):
		var r = rockets[i]
		r["life"] -= G.DT
		r["v"].y += G.GRAV * r.get("g", 0.15) * G.DT
		var stepv: Vector3 = r["v"] * G.DT
		var ex: Array = []
		if is_instance_valid(r["owner"]):
			ex = r["owner"].rids.duplicate()
		if r.get("veh") != null and is_instance_valid(r["veh"]):
			ex.append(r["veh"].body.get_rid())
		var hit = G.ray(r["p"], r["p"] + stepv, G.L_WORLD | G.L_BODY | G.L_VEH, ex)
		if not hit.is_empty() or r["life"] <= 0.0:
			var at: Vector3 = r["p"] if hit.is_empty() else hit.position
			if not hit.is_empty() and hit.collider.has_meta("vehicle"):
				var hv = hit.collider.get_meta("vehicle")
				# shells glance off sloped armour at a shallow angle
				var cosang = absf(stepv.normalized().dot(hit.normal))
				if r.get("veh") != null and hv.spec["tracked"] and cosang < 0.38 and not r.get("bounced", false) and randf() < 0.65:
					r["bounced"] = true
					r["v"] = r["v"].bounce(hit.normal) * 0.55
					r["p"] = hit.position + hit.normal * 0.15
					r["life"] = minf(r["life"], 0.8)
					hv.take_damage(r.get("vdmg", 560.0) * 0.12, r["owner"] if is_instance_valid(r["owner"]) else null, hit.position)
					G.fx.impact(hit.position, hit.normal)
					G.fx.impact(hit.position, hit.normal)
					G.audio.ricochet(hit.position)
					G.audio.play(G.audio.s_boom, hit.position, -6.0, 2.2)
					if hv.driver() != null:
						G.fx.callout(hv.driver(), G.pick(["Bounced off!", "Ricochet! Armour held!"]))
					continue
				hv.take_damage(r.get("vdmg", 560.0), r["owner"] if is_instance_valid(r["owner"]) else null, hit.position)
			if not hit.is_empty() and hit.collider.has_meta("soldier"):
				var hs = hit.collider.get_meta("soldier")
				if hs.state != "dead":
					hs.hp -= 60.0
					if hs.hp <= 0.0:
						kill(hs, r["owner"], false)
			G.bal_add("boom: " + (("shell from a " + r["veh"].kind) if r.get("veh") != null and is_instance_valid(r["veh"]) else ("rocket" if r.get("power", 1.25) > 0.8 else "rifle grenade")))
			explode(at - stepv.normalized() * 0.1, r["owner"] if is_instance_valid(r["owner"]) else null, r.get("power", 1.25))
			r["mesh"].queue_free()
			rockets.remove_at(i)
			continue
		r["p"] += stepv
		r["mesh"].global_position = r["p"]
		r["mesh"].look_at(r["p"] + stepv, Vector3.UP if absf(stepv.normalized().y) < 0.95 else Vector3.RIGHT)
		r["trail"] -= G.DT
		if r["trail"] <= 0.0:
			r["trail"] = 0.035
			G.fx.rocket_trail(r["p"] - stepv.normalized() * 0.4)
		var fl = r["mesh"].get_meta("flame") if r["mesh"].has_meta("flame") else null
		if fl != null:
			fl.scale = Vector3(1.0, 0.7 + randf() * 0.6, 1.0)

# tank cannon: a fast, flat shell
static func launch_shell(veh, s, origin: Vector3, dir: Vector3, power: float = 1.5, vdmg: float = 650.0, speed: float = 140.0) -> void:
	var m = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(0.12, 0.12, 0.6)
	m.mesh = bm
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.8, 0.4)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	G.fx.add_child(m)
	m.global_position = origin
	rockets.append({"p": origin, "v": dir * speed, "owner": s, "veh": veh, "mesh": m, "life": 3.0, "trail": 0.0, "power": power, "vdmg": vdmg})
	G.fx.dust_cloud(origin + dir * 0.5, 2.0)

# ---------------------------------------------------------------- flares
# a parachute flare: rises over the target, pops, and drifts down lighting up everything around it
static func flare(from: Vector3, target: Vector3) -> void:
	var node = Node3D.new()
	var ball = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = 0.25
	sm.height = 0.5
	ball.mesh = sm
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.95, 0.8)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.9, 0.7)
	m.emission_energy_multiplier = 6.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ball.material_override = m
	node.add_child(ball)
	var light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.9, 0.75)
	light.light_energy = 0.0
	light.omni_range = 75.0
	light.omni_attenuation = 0.8
	light.shadow_enabled = false
	node.add_child(light)
	G.fx.add_child(node)
	node.global_position = from + Vector3(0, 1.5, 0)
	flares.append({"node": node, "light": light, "a": from + Vector3(0, 1.5, 0), "b": target + Vector3(0, 42.0, 0), "t": 0.0, "lit": false})
	G.audio.rocket(from)

static func step_flares() -> void:
	for i in range(flares.size() - 1, -1, -1):
		var f = flares[i]
		f["t"] += G.DT
		var n: Node3D = f["node"]
		if not f["lit"]:
			var k = minf(1.0, f["t"] / 2.2)
			var p: Vector3 = f["a"].lerp(f["b"], k)
			p.y += sin(k * PI) * 8.0
			n.global_position = p
			if k >= 1.0:
				f["lit"] = true
				f["t"] = 0.0
				G.audio.whistle(p)
				# the parachute pops open above it, and the light throws long moving shadows (only for
				# a couple of flares at once, they're costly)
				var chute = Node3D.new()
				var dome = MeshInstance3D.new()
				var dm = SphereMesh.new()
				dm.radius = 0.7
				dm.height = 0.7
				dm.is_hemisphere = true
				dome.mesh = dm
				var cm = StandardMaterial3D.new()
				cm.albedo_color = Color(0.85, 0.85, 0.8)
				cm.cull_mode = BaseMaterial3D.CULL_DISABLED
				dome.material_override = cm
				dome.position = Vector3(0, 1.3, 0)
				chute.add_child(dome)
				for a in [0.0, PI * 0.5, PI, PI * 1.5]:
					var line = MeshInstance3D.new()
					var lm = BoxMesh.new()
					lm.size = Vector3(0.01, 1.4, 0.01)
					line.mesh = lm
					line.material_override = cm
					line.position = Vector3(cos(a) * 0.32, 0.65, sin(a) * 0.32)
					line.rotation = Vector3(-sin(a) * 0.45, 0, cos(a) * 0.45)
					chute.add_child(line)
				n.add_child(chute)
				var shadowed = 0
				for o in flares:
					if o["light"].shadow_enabled:
						shadowed += 1
				f["light"].shadow_enabled = shadowed < 2 and G.main.is_night()
		else:
			# under its little parachute it sways and sinks slowly, lighting the ground for the best part of a minute
			var life = f["t"]
			n.global_position += Vector3(0.4 + 0.5 * sin(life * 0.9), -0.75, 0.2 + 0.4 * cos(life * 0.7)) * G.DT
			f["light"].light_energy = clampf(life * 4.0, 0.0, 1.0) * clampf((40.0 - life) / 5.0, 0.0, 1.0) * (11.0 if G.main.is_night() else 2.0) * (0.85 + randf() * 0.3)
			f["light"].omni_range = 95.0
			if int(life * 6.0) != int((life - G.DT) * 6.0):
				G.fx.exhaust(n.global_position + Vector3(0, -0.3, 0), Vector3(0, -1, 0), 0.25, false)
			if life > 40.0 or n.global_position.y < G.world.ground_y(n.global_position.x, n.global_position.z) + 1.0:
				n.queue_free()
				flares.remove_at(i)

# is this spot lit up (by a flare, a fire or a muzzle flash)?
static func lit(p: Vector3) -> bool:
	for f in flares:
		if f["lit"] and G.dist2d(f["node"].global_position, p) < 60.0:
			return true
	return false

# ---------------------------------------------------------------- mortar strikes
static func mortar_strike(center: Vector3, n: int) -> void:
	for i in range(n):
		var a = randf() * TAU
		var r = sqrt(randf()) * 9.0
		var p = Vector3(center.x + cos(a) * r, 0, center.z + sin(a) * r)
		p.y = G.world.ground_y(p.x, p.z) + 0.1
		strikes.append({"p": p, "t": 1.4 + i * randf_range(0.4, 0.8), "whistled": false})

# one shell from a mortar team or an artillery call: lands after the flight time near the target
static func shell_at(target: Vector3, spread: float, flight: float, owner_s, power: float = 1.35, team: int = -1) -> void:
	var a = randf() * TAU
	var r = sqrt(randf()) * spread
	var p = Vector3(target.x + cos(a) * r, 0, target.z + sin(a) * r)
	p.y = G.world.ground_y(p.x, p.z) + 0.1
	if team < 0 and owner_s != null and is_instance_valid(owner_s):
		team = owner_s.team
	strikes.append({"p": p, "t": flight, "whistled": false, "owner": owner_s, "power": power, "team": team})

static var intercepts = 0

# a counter-battery gun near where a shell is coming down gets a burst off at it
static func _intercept(s) -> bool:
	if s.get("checked", false):
		return false
	s["checked"] = true
	for st in Build.sites:
		if st["kind"] != "cbgun" or not Build.alive(st) or not st["done"] or st["team"] == s.get("team", -1):
			continue
		if G.dist2d(st["p"], s["p"]) > 60.0 or randf() > 0.75:
			continue
		var gun: Vector3 = st["p"] + Vector3(0, 2.2, 0)
		var burst: Vector3 = s["p"] + Vector3(randf_range(-3, 3), randf_range(26.0, 34.0), randf_range(-3, 3))
		var dir = (burst - gun).normalized()
		for k in range(3):
			G.fx.tracer(gun, (dir + Vector3(randf_range(-0.03, 0.03), randf_range(-0.03, 0.03), randf_range(-0.03, 0.03))).normalized(), 2.0, 260.0, func(): pass, true)
		G.fx.explosion(burst, 0.35)
		G.audio.play(G.audio.s_boom, burst, -10.0, 1.6)
		intercepts += 1
		return true
	return false

static func step_strikes() -> void:
	for i in range(strikes.size() - 1, -1, -1):
		var s = strikes[i]
		s["t"] -= G.DT
		if s["t"] < 0.9 and _intercept(s):
			strikes.remove_at(i)
			continue
		if not s["whistled"] and s["t"] < 1.15:
			s["whistled"] = true
			G.audio.whistle(s["p"])
		if s["t"] <= 0.0:
			var ow = s.get("owner")
			# remembered by the side whose HQ it fell near (an AI builds a counter-battery gun)
			for st in Build.sites:
				if st["kind"] == "hq" and not st["dead"] and st["team"] != s.get("team", -1) and G.dist2d(st["p"], s["p"]) < 50.0:
					st["shelled_t"] = G.sim_time
			arty = true
			G.bal_add("boom: " + str(s.get("src", "artillery")))
			explode(s["p"], ow if (ow != null and is_instance_valid(ow)) else null, s.get("power", 1.35))
			arty = false
			strikes.remove_at(i)

# ---------------------------------------------------------------- grenades and smoke
const THROW_T = 1.35      # an AI throw from start to finish: pull the pin, wind back, let go, follow through
const THROW_AT = 0.5     # throw_t left when the grenade leaves his hand

# AI men go through the motions first (see Soldier, throw_t): the grenade only leaves the hand part way through
static func throw_grenade(s, target: Vector3, type: String, cook: float = 0.0) -> void:
	if not s.is_player and s.state == "alive":
		# (smoke hides nothing from the dead: nobody throws it in a horde battle)
		if type == "smoke" and G.mode == "horde":
			s.smokes = 0
			return
		# (not with a wall right in front of him: his arm went through it and the grenade started its
		# flight on the far side)
		var chest: Vector3 = s.pos + Vector3(0, 1.3, 0)
		var d0 = G.flat(target - s.pos).normalized()
		if not G.ray(chest, chest + d0 * 1.8 + Vector3(0, 0.45, 0), G.L_WORLD).is_empty():
			s.nade_cd = maxf(s.nade_cd, 3.0)
			return
		if s.has_meta("throw_pending") and s.throw_t > 0.0:
			return          # one in the hand already
		# (a throw cut short when he was knocked down leaves nothing behind)
		s.set_meta("throw_pending", [target, type, cook])
		G.audio.pin(s.pos + Vector3(0, 1.2, 0))
		s.throw_t = THROW_T
		s.set_meta("throw_T", THROW_T)
		s.burst = 0
		return
	_throw_now(s, target, type, cook)

# the moment of release, from the throw animation (or at once for the player)
static func release_throw(s) -> void:
	if not s.has_meta("throw_pending"):
		return
	var pend: Array = s.get_meta("throw_pending")
	s.remove_meta("throw_pending")
	if s.state != "alive":
		return
	_throw_now(s, pend[0], pend[1], pend[2])
	if randf() < 0.6:
		G.audio.voice(s, "grunt")
	s.throw_t = THROW_AT          # keep the follow-through going

static var thrown = {}
static func _throw_now(s, target: Vector3, type: String, cook: float = 0.0) -> void:
	thrown[type] = thrown.get(type, 0) + 1
	if type == "frag" and Faction.militia(s.team) and randf() < 0.6:
		type = "molotov"
	var start = (s.parts[6].global_position + Vector3(0, 0.15, 0)) if s.parts.size() > 6 and not s.is_player else s.head_pos() + Vector3(0, 0.1, 0)
	# (the hand can be the other side of something thin he's standing against: it leaves from the near
	# side of whatever is between his chest and his hand)
	var chest0: Vector3 = s.pos + Vector3(0, 1.3, 0)
	if not s.is_player and not G.ray(chest0, start, G.L_WORLD).is_empty():
		start = chest0 + Vector3(0, 0.3, 0)
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
	mat.albedo_color = Color(0.55, 0.57, 0.53) if type == "smoke" else (Color(0.7, 0.2, 0.15) if type == "marker" else (Color(0.3, 0.42, 0.25) if type == "molotov" else Color(0.18, 0.21, 0.14)))
	m.material_override = mat
	g.add_child(m)
	g.set_meta("type", type)
	var fuse = {"smoke": 1.6, "marker": 1.4, "satchel": 4.0, "sticky": 3.2, "molotov": 1.0}.get(type, 2.6)
	if type == "frag":
		fuse = maxf(0.7, fuse - cook)
	g.set_meta("fuse", fuse)
	g.set_meta("seen", {})
	g.set_meta("owner", s)
	G.fx.add_child(g)
	g.global_position = start
	g.linear_velocity = v
	g.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
	G.grenades.append(g)
	if type == "satchel":
		bs.size = Vector3(0.3, 0.18, 0.22)
		bm.size = bs.size
		mat.albedo_color = Color(0.4, 0.33, 0.2)
	elif type == "sticky":
		bs.size = Vector3(0.2, 0.2, 0.2)
		bm.size = bs.size
		mat.albedo_color = Color(0.25, 0.22, 0.18)
	if type == "smoke" or type == "marker":
		s.smokes -= 1
	elif type == "satchel":
		s.satchels -= 1
	elif type == "sticky":
		s.stickies -= 1
	else:
		s.grenades -= 1
	if s.is_player:
		s.throw_t = 0.55
		s.set_meta("throw_T", 0.55)
	G.fx.callout(s, {"smoke": "Popping smoke!", "satchel": "Satchel charge! Get back!", "sticky": "Sticky bomb!", "marker": "Marking the target!", "molotov": "Burn them out!"}.get(type, "Grenade out!"))

# a wall coming down: a thick cloud of brick dust that rolls out, drifts and blocks sight for a while
static func dust_at(p: Vector3, size: float) -> void:
	var big = clampf(size / 5.0, 0.5, 1.0)
	var sc = SmokeCloud.new()
	sc.p = p + Vector3(0, 0.6, 0)
	sc.r = 2.5
	sc.t = 15.0 + 6.0 * big
	# two layers: a dense low cloud rolling out along the ground and a taller one drifting up off it
	sc.node = G.fx.smoke_screen(Vector3(p.x, G.world.ground_y(p.x, p.z) + 1.0, p.z), sc.t - 3.0, Color(0.52, 0.46, 0.38), big * 1.6)
	sc.node.scale = Vector3(0.85, 0.85, 0.85)      # it bursts out, rather than growing from nothing like a smoke grenade
	var upper = G.fx.smoke_screen(Vector3(p.x, G.world.ground_y(p.x, p.z) + 3.2, p.z), sc.t - 6.0, Color(0.6, 0.55, 0.47), big * 1.1)
	upper.scale = Vector3(0.6, 0.6, 0.6)
	sc.set_meta("upper", upper)
	# and a thick burst rolling out along the ground first
	for k in range(4):
		var a2 = k * TAU / 4.0 + randf() * 0.6
		G.fx.dust_cloud(p + Vector3(cos(a2), 0, sin(a2)) * 2.2 * big + Vector3(0, -0.5, 0), 3.0)
	sc.set_meta("max_r", 6.5 * big)
	var a = randf() * TAU
	sc.set_meta("drift", Vector3(0.7 + cos(a) * 0.3, 0, 0.25 + sin(a) * 0.3))
	G.smoke_clouds.append(sc)

static func smoke_at(p: Vector3, life: float, tint: Color = Color(0.85, 0.85, 0.83), big: float = 1.0) -> void:
	var sc = SmokeCloud.new()
	sc.p = p + Vector3(0, 1.0, 0)
	sc.r = 0.5
	sc.t = life
	sc.node = G.fx.smoke_screen(p + Vector3(0, 0.5, 0), life - 4.0, tint, big)
	# a smoke screen proper (not a coloured marker) is thick: a second dense bank hugging the ground
	# under the main cloud, so it's a solid white wall you can't see a man through
	if big >= 0.7:
		G.fx.smoke_screen(p + Vector3(0, 0.3, 0), life - 5.0, tint.lightened(0.05), big * 0.8, 1.4)
		G.fx.smoke_screen(p + Vector3(0, 1.4, 0), life - 6.0, tint, big * 0.65, 1.2)
	sc.set_meta("max_r", 9.0 * big)
	G.smoke_clouds.append(sc)

static func step_grenades() -> void:
	for i in range(G.grenades.size() - 1, -1, -1):
		var g = G.grenades[i]
		if not is_instance_valid(g):
			G.grenades.remove_at(i)
			continue
		var fuse = g.get_meta("fuse") - G.DT
		g.set_meta("fuse", fuse)
		var gtype: String = g.get_meta("type")
		Doors.grenade_tick(g)
		# sticky bombs cling to the first vehicle they touch
		if gtype == "sticky":
			_sticky_tick(g)
		if gtype in ["frag", "sticky", "satchel"] and fuse > 0.3:
			_grenade_reactions(g, fuse)
		if fuse <= 0.0:
			var owner_s = g.get_meta("owner")
			if owner_s != null and not is_instance_valid(owner_s):
				owner_s = null
			if gtype == "smoke":
				smoke_at(g.global_position, 32.0)
			elif gtype == "marker":
				smoke_at(g.global_position, 18.0, Color(0.85, 0.22, 0.18), 0.45)
				_marker_popped(g.global_position, owner_s)
			elif gtype == "satchel":
				G.bal_add("boom: satchel")
				explode(g.global_position, owner_s, 2.1)
			elif gtype == "molotov":
				molotov(g.global_position, owner_s)
			elif gtype == "sticky":
				var sv = g.get_meta("stuck_v") if g.has_meta("stuck_v") else null
				if sv != null and is_instance_valid(sv) and not sv.dead:
					sv.take_damage(1100.0, owner_s, g.global_position)
				explode(g.global_position, owner_s, 0.9)
			else:
				G.bal_add("boom: grenade")
				explode(g.global_position, owner_s, 1.0)
			g.queue_free()
			G.grenades.remove_at(i)
	for i in range(G.smoke_clouds.size() - 1, -1, -1):
		var c = G.smoke_clouds[i]
		c.t -= G.DT
		c.r = minf(c.get_meta("max_r", 9.0), c.r + G.DT * 2.6)
		# dust from a fallen wall drifts off on the breeze, thinning as it goes
		if c.has_meta("drift"):
			var dv: Vector3 = c.get_meta("drift")
			c.p += dv * G.DT
			if is_instance_valid(c.node):
				c.node.global_position += dv * G.DT
			var up_n = (c.get_meta("upper") if c.has_meta("upper") else null)
			if up_n != null and is_instance_valid(up_n):
				up_n.global_position += (dv * 1.4 + Vector3(0, 0.15, 0)) * G.DT
		if c.t < 4.0:
			c.r = maxf(0.0, c.r - G.DT * 1.3)
		if c.t <= 0.0:
			G.smoke_clouds.remove_at(i)

static func _sticky_tick(g: RigidBody3D) -> void:
	if g.has_meta("stuck_v"):
		var v = g.get_meta("stuck_v")
		if is_instance_valid(v):
			g.global_position = v.global_transform * g.get_meta("stuck_o")
		return
	for v in G.vehicles:
		if v.dead:
			continue
		var lp: Vector3 = v.global_transform.affine_inverse() * g.global_position
		if absf(lp.x) < v.spec["wid"] * 0.55 + 0.2 and absf(lp.z) < v.spec["len"] * 0.5 + 0.2 and lp.y > -0.2 and lp.y < 3.2:
			g.set_meta("stuck_v", v)
			g.set_meta("stuck_o", lp)
			g.freeze = true
			G.audio.hammer(g.global_position)
			return

# soldiers who see a grenade land near them dive away, or grab it and throw it back
static func _grenade_reactions(g: RigidBody3D, fuse: float) -> void:
	var gp = g.global_position
	if g.linear_velocity.length() > 4.0 and not g.has_meta("stuck_v"):
		return       # still in the air
	var seen: Dictionary = g.get_meta("seen")
	var owner_s = g.get_meta("owner")
	for s in G.soldiers:
		if s.state != "alive" or s.is_player or seen.has(s):
			continue
		var d = G.dist2d(s.pos, gp)
		if d > 7.0 or absf(s.pos.y - gp.y) > 2.5:
			continue
		seen[s] = true
		if G.blocked(s.head_pos(), gp + Vector3(0, 0.15, 0)):
			continue
		if randf() < 0.25:
			continue      # didn't notice it
		var throw_back = g.get_meta("type") == "frag" and d < 3.4 and fuse > 1.4 + d * 0.15 and s.stun <= 0.0 and randf() < (0.5 if d < 2.0 else 0.3) and not g.has_meta("stuck_v")
		if throw_back:
			# a lunge to it, snatched up off the ground
			if d > 1.0:
				var to_g = G.flat(gp - s.pos).normalized()
				if not G.world.solid_at(s.pos.x + to_g.x * (d - 0.8), s.pos.z + to_g.z * (d - 0.8), 0.25, s.pos.y):
					s.pos += to_g * (d - 0.8)
			s.crouch = 1.0
			AI.release_cover(s)
			var back_to: Vector3 = owner_s.pos if owner_s != null and is_instance_valid(owner_s) else s.pos + G.flat(gp - s.pos).normalized() * -12.0
			back_to = s.pos + G.flat(back_to - s.pos).normalized() * minf(G.dist2d(back_to, s.pos), 22.0)
			var start = s.head_pos() + Vector3(0, 0.2, 0)
			var T = clampf(0.6 + G.dist2d(back_to, start) * 0.035, 0.7, 1.4)
			g.global_position = start
			g.linear_velocity = Vector3((back_to.x - start.x) / T, (back_to.y + 0.2 - start.y) / T - 0.5 * G.GRAV * T, (back_to.z - start.z) / T)
			g.set_meta("owner", s)
			g.set_meta("seen", {})
			s.throw_t = 0.55
			G.fx.callout(s, G.pick(["Throwing it back!", "Return to sender!", "Get it out of here!"]))
			return
		# dive flat away from it
		var away = G.flat(s.pos - gp)
		if away.length_squared() < 0.01:
			away = Vector3(randf() - 0.5, 0, randf() - 0.5)
		away = away.normalized()
		s.fall(randf_range(1.4, 2.2))
		s.push(0, away * 4.5 + Vector3(0, 1.6, 0), 0.8)
		G.fx.callout(s, G.pick(["Grenade!", "Grenade, get down!", "Down!"]))

# a red smoke marker: the nearest free radio operator calls the guns onto it
static func _marker_popped(at: Vector3, owner_s) -> void:
	if owner_s == null:
		return
	# it needs a radio: the thrower's own squad's set, or another one close by
	var best = null
	if owner_s.radio_pack != null:
		best = owner_s
	for o in G.soldiers:
		if best != null:
			break
		if o.team == owner_s.team and o.state == "alive" and o.radio_pack != null and o.radio_cd <= 0.0 \
				and ((owner_s.squad != null and o.squad == owner_s.squad) or G.dist2d(o.pos, at) < 90.0):
			best = o
	if best != null and (owner_s.is_player or Rules.ai_callin_ok()):
		best.radio_cd = 45.0
		ClassAI.call_artillery(best, at)
	elif owner_s == G.player:
		G.ui.message("No radio to call in the marker: get the set off the radioman")

# rifle grenades: a lobbed round on a ballistic arc, solved for the distance to the target
static func launch_rifle_grenade(s, origin: Vector3, target: Vector3) -> void:
	var speed = 46.0
	var d = G.dist2d(target, origin)
	var dy = target.y - origin.y
	var g = -G.GRAV
	var v2 = speed * speed
	var disc = v2 * v2 - g * (g * d * d + 2.0 * dy * v2)
	var ang = 0.6
	if disc > 0.0:
		ang = atan2(v2 - sqrt(disc), g * d)
	var flat = G.flat(target - origin).normalized()
	var dir = (flat * cos(ang) + Vector3(0, sin(ang), 0)).normalized()
	var m = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(0.07, 0.07, 0.24)
	m.mesh = bm
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.33, 0.25)
	m.material_override = mat
	G.fx.add_child(m)
	m.global_position = origin
	rockets.append({"p": origin, "v": dir * speed, "owner": s, "veh": null, "mesh": m, "life": 8.0, "trail": 1.0, "power": 0.75, "vdmg": 260.0, "g": 1.0})
	G.audio.shot(origin, G.WEAPONS["shotgun"])
	G.fx.muzzle(origin, false)

# ---------------------------------------------------------------- explosions
static func explode(pos: Vector3, owner_s, power: float) -> void:
	if power >= float(last_boom["pow"]) or G.sim_time - float(last_boom["t"]) > 4.0:
		last_boom = {"t": G.sim_time, "p": pos, "pow": power}
	# a shell into the river throws up a tall column of spray
	if not G.world.water.is_empty() and G.world.in_water(pos.x, pos.z) and pos.y < G.world.water_level(pos.x, pos.z) + 0.6:
		var wl = G.world.water_level(pos.x, pos.z)
		G.fx.splash(Vector3(pos.x, wl, pos.z), 2.2 * power)
		G.fx.water_column(Vector3(pos.x, wl, pos.z), power)
	Doors.blast(pos, power)
	Faction.blast(pos, power)
	var R = 7.0 * power
	G.fx.explosion(pos, power)
	G.audio.boom(pos)
	var cam = G.main.get_viewport().get_camera_3d()
	if cam:
		shake = maxf(shake, clampf(1.2 - cam.global_position.distance_to(pos) / 40.0, 0.0, 1.0))
		# in first person a blast close by: dust thrown over the view and the hearing goes for a moment
		if G.player != null and G.player.state != "dead":
			var dd = G.player.pos.distance_to(pos)
			var k = clampf(1.0 - dd / (16.0 * clampf(power, 0.6, 2.0)), 0.0, 1.0)
			if k > 0.05:
				shake = maxf(shake, 0.6 + k)
				G.audio.deafen(k * 1.2)
				G.ui.dust_hit(k)
		else:
			# watching from close by (not through a soldier's eyes): the sound goes dull for a moment
			G.audio.dull(1.0 - cam.global_position.distance_to(pos) / (24.0 * clampf(power, 0.6, 2.0)))
	G.world.damage_area(pos, R * 0.75, power)
	if power >= 1.0:
		G.world.blast_crater(pos, clampf(1.2 * power, 1.0, 3.2))
	elif power >= 0.7:
		G.world.blast_crater(pos, 0.9)        # grenades and rifle grenades leave a scrape too
	# everyone in earshot looks round at the bang
	for sl in G.soldiers:
		if sl.state == "alive" and not sl.is_player and sl.look_t < 0.6:
			var dl = G.dist2d(sl.pos, pos)
			if dl > R and dl < 55.0:
				sl.look_p = pos
				sl.look_t = 1.3
	for v in G.vehicles.duplicate():
		var dv = v.center().distance_to(pos)
		if dv < R * 1.2:
			v.take_damage(300.0 * power * (1.0 - dv / (R * 1.2)) * (0.3 if v.spec["tracked"] else 1.0), owner_s, pos)
			# a big blast right beside a light vehicle throws it over (if it's still in one piece)
			if not v.dead and not v.spec["tracked"] and power >= 1.0 and dv < R * 0.45 and v.can_flip() and randf() < 0.3 * power:
				var side = G.flat(v.pos - pos)
				var rgt = Vector3(v.forward().z, 0, -v.forward().x)
				v.hit_from = pos
				G.bal_add("flip_blast")
				v.flip_over(signf(side.dot(rgt)) * -1.0, randf() < 0.3, "blast")
	var blast_lv = Levels.storey_of(pos)
	for s in G.soldiers:
		if s.state == "riding" and s.hidden_in_vehicle:
			continue
		var d = s.parts[0].global_position.distance_to(pos)
		if owner_s != null and s.state != "dead" and s.team != owner_s.team and d < 60.0:
			AI.add_intel(s, owner_s, owner_s.pos, 10.0, false)
		if d > R * 1.7:
			continue
		# a solid floor between him and it (a shell on the roof, a grenade on the storey below): he hears it, no more
		if blast_lv > -99 and Levels.storey_of(s.parts[0].global_position) != blast_lv and Levels.storey_of(s.parts[0].global_position) > -99:
			if s.state == "alive":
				s.supp = maxf(s.supp, 0.6)
			continue
		var exposed = not G.blocked(pos + Vector3(0, 0.4, 0), s.chest())
		var f = (1.0 - d / (R * 1.7)) * (1.0 if exposed else 0.35)
		if s.state != "dead":
			s.supp = 1.5
			if d < R:
				var edmg = 130.0 * (1.0 - d / R) * (1.0 if exposed else 0.3) * ((0.0 if not Modes.rescued else 0.3) if s == Modes.pilot else 1.0)
				s.hp -= edmg
				Medical.wound(s, edmg * 0.6)
				if s == G.player:
					G.ui.damage_indicator(pos)
			if s.hp <= 0.0:
				cause = "blast"
				kill(s, owner_s if owner_s != s else null, false)
			elif f > 0.3:
				s.fall(randf_range(1.8, 3.0))
			elif s.state == "alive":
				s.stun = maxf(s.stun, 0.3)
		s.wake()
		s.unsettle()
		# thrown flat and rolled, not launched skyward
		for b in s.parts:
			var away: Vector3 = b.global_position - pos
			away.y = maxf(away.y, 0.0) * 0.4 + 0.12
			b.apply_central_impulse(away.normalized() * 5.5 * f * randf_range(0.85, 1.1) * b.mass * (0.7 if s.state == "alive" else 0.8))
		_cap(s, 6.0)
	for d in G.fx.debris_list:
		if is_instance_valid(d["b"]) and d["b"].global_position.distance_to(pos) < R:
			var aw: Vector3 = d["b"].global_position - pos
			d["b"].apply_central_impulse(aw.normalized() * 6.0 * d["b"].mass * (1.0 - aw.length() / R) + Vector3(0, 3, 0))

# ---------------------------------------------------------------- flamethrower
static func flame(s, origin: Vector3, dir: Vector3) -> void:
	var d = spread_dir(dir, 0.05)
	G.fx.flame_puff(origin + d * 0.3, d * 15.0 + Vector3(0, 1.0, 0), 0.9)
	if randf() < 0.3:
		G.audio.play(G.audio.s_rocket, origin, -10.0, 0.5)
	var reach = 17.0
	var hit = G.ray(origin, origin + d * reach, G.L_WORLD)
	if not hit.is_empty():
		reach = origin.distance_to(hit.position)
		if hit.collider.has_meta("col"):
			ignite_col(hit.collider.get_meta("col"))
	for o in G.soldiers:
		if o == s or o.state == "dead" or o.hidden_in_vehicle:
			continue
		var v = o.chest() - origin
		var t = v.dot(d)
		if t < 0.0 or t > reach:
			continue
		if (v - d * t).length() < 0.6 + t * 0.12:
			o.ignite(s)
			o.hp -= 2.0
	for v in G.vehicles:
		if v.center().distance_to(origin + d * minf(reach, v.center().distance_to(origin))) < 2.5 and v.center().distance_to(origin) < reach:
			v.take_damage(6.0 * (0.2 if v.spec["tracked"] else 1.0), s, v.center())

# ---------------------------------------------------------------- fire spreading through hedges, crates and huts
static func ignite_col(c) -> void:
	if c == null or not c.alive or not c.dest or c.prop == 0 and c.hp > 130.0:
		return
	for f in fires:
		if f["c"] == c:
			return
	fires.append({"c": c, "t": 0.0, "fx": 0.0, "spread": randf_range(3.0, 6.0)})

static func step_fires() -> void:
	for i in range(fires.size() - 1, -1, -1):
		var f = fires[i]
		var c = f["c"]
		if not c.alive:
			fires.remove_at(i)
			continue
		f["t"] += G.DT
		f["fx"] -= G.DT
		var mid: Vector3 = (c.lo + c.hi) * 0.5
		if f["fx"] <= 0.0:
			f["fx"] = 0.15
			var p = Vector3(randf_range(c.lo.x, c.hi.x), c.hi.y - 0.2, randf_range(c.lo.z, c.hi.z))
			G.fx.flame_puff(p, Vector3(randf_range(-0.3, 0.3), 2.5, randf_range(-0.3, 0.3)), 1.0)
		for o in G.soldiers:
			if o.state != "dead" and o.pos.x > c.lo.x - 1.0 and o.pos.x < c.hi.x + 1.0 and o.pos.z > c.lo.z - 1.0 and o.pos.z < c.hi.z + 1.0:
				o.ignite(null)
		f["spread"] -= G.DT
		if f["spread"] <= 0.0:
			f["spread"] = randf_range(3.0, 6.0)
			for o in G.world.cols:
				if o != c and o.dest and o.prop > 0 and o.alive and absf(((o.lo + o.hi) * 0.5).x - mid.x) < 4.0 and absf(((o.lo + o.hi) * 0.5).z - mid.z) < 4.0:
					ignite_col(o)
		if f["t"] > (12.0 if c.prop == 2 else 9.0):
			G.world.destroy_col(c)
			G.fx.decal(mid, 2.5, true)
			fires.remove_at(i)

# ---------------------------------------------------------------- mines and satchel charges
# a bottle of petrol: the glass breaks and a pool of fire spreads, setting alight anyone standing in it
static func molotov(p: Vector3, owner_s) -> void:
	G.audio.glass(p)
	for k in range(10):
		var q = p + Vector3(randf_range(-2.2, 2.2), 0.1, randf_range(-2.2, 2.2))
		G.fx.flame_puff(q, Vector3(0, randf_range(1.5, 3.0), 0), randf_range(0.8, 1.4))
	for o in G.soldiers:
		if o.state != "dead" and G.dist2d(o.pos, p) < 3.2 and absf(o.pos.y - p.y) < 2.0:
			o.ignite(owner_s)
	for c in G.world.cols_in_rect(p.x - 3.0, p.z - 3.0, p.x + 3.0, p.z + 3.0):
		if c.alive and c.prop == 1:
			ignite_col(c)

# the militia's roadside bombs: dug into the road, invisible, set off by a vehicle driving over them
static func place_mine_at(team: int, at: Vector3, kind: String) -> void:
	var m = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.45
	cm.bottom_radius = 0.5
	cm.height = 0.04
	m.mesh = cm
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.29, 0.28)
	m.material_override = mat
	G.fx.add_child(m)
	var p = Vector3(at.x, G.world.ground_y(at.x, at.z) + 0.02, at.z)
	m.global_position = p
	mines.append({"p": p, "team": team, "kind": kind, "node": m, "owner": null, "arm": 2.0})

static func place_mine(s, at: Vector3, kind: String) -> void:
	var m = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.18 if kind == "ap" else 0.32
	cm.bottom_radius = cm.top_radius
	cm.height = 0.07
	m.mesh = cm
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.27, 0.2)
	m.material_override = mat
	G.fx.add_child(m)
	var p = Vector3(at.x, G.world.ground_y(at.x, at.z) + 0.03, at.z)
	m.global_position = p
	mines.append({"p": p, "team": s.team, "kind": kind, "node": m, "owner": s, "arm": 2.0})

static func step_mines() -> void:
	for i in range(mines.size() - 1, -1, -1):
		var m = mines[i]
		if m["arm"] > 0.0:
			m["arm"] -= G.DT
			continue
		var boom = false
		# a mine plough digs it up ahead of the tracks and sets it off harmlessly against the blade
		for pv in G.vehicles:
			if pv.has_meta("plough") and not pv.dead and G.dist2d(pv.pos + pv.forward() * (pv.spec["len"] * 0.5 + 1.0), m["p"]) < pv.spec["wid"] * 0.5 + 0.5:
				pv.set_meta("plough_t", G.sim_time)
				explode(m["p"] + Vector3(0, 0.2, 0), null, 0.6)
				if randf() < 0.5 and pv.driver() != null:
					G.fx.callout(pv.driver(), G.pick(["Mine cleared!", "Another one gone.", "Plough got one!"]))
				m["node"].queue_free()
				mines.remove_at(i)
				boom = true
				break
		if boom:
			continue
		if m["kind"] == "ap":
			for o in G.soldiers:
				if o.team != m["team"] and (o.state == "alive" or o.state == "getup") and G.dist2d(o.pos, m["p"]) < 0.9:
					boom = true
					break
		else:
			for v in G.vehicles:
				if v.team != m["team"] and not v.dead and not v.spec.get("air", false) and G.dist2d(v.pos, m["p"]) < v.spec["wid"] * 0.5 + 0.8:
					boom = true
					v.take_damage(1100.0 if m["kind"] == "ied" else 650.0, m["owner"] if m["owner"] != null and is_instance_valid(m["owner"]) else null, m["p"])
					# the blast takes off a track or a wheel
					if not v.dead and not v.tracks_broken:
						v.tracks_broken = true
						G.ui.radio(v.team, "%s hit a mine, %s gone!" % [v.spec["name"], "track" if v.spec["tracked"] else "wheel"])
					break
		if boom:
			explode(m["p"] + Vector3(0, 0.2, 0), m["owner"] if m["owner"] != null and is_instance_valid(m["owner"]) else null, 0.9 if m["kind"] == "ap" else (2.2 if m["kind"] == "ied" else 1.5))
			m["node"].queue_free()
			mines.remove_at(i)

static func clear_all() -> void:
	for m in mines:
		if is_instance_valid(m["node"]):
			m["node"].queue_free()
	mines = []
	fires = []
	for f in flares:
		if is_instance_valid(f["node"]):
			f["node"].queue_free()
	flares = []
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
