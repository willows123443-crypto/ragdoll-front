class_name Medical
extends RefCounted
# Bleeding and field dressings. Wounds keep bleeding until somebody puts a dressing on them:
# you can do your own (slow, and you have to stop), a buddy does it faster, and a medic fastest
# (and patches you up as well). Everyone carries a couple of dressings; medics carry more.

const SELF_T = 4.0
const BUDDY_T = 2.2
const MAX_BLEED = 3.0

# a hit that didn't kill: how much it bleeds
static func wound(s, dmg: float) -> void:
	if s.zombie or s == Modes.pilot:
		return
	s.bleed = minf(MAX_BLEED, s.bleed + dmg * 0.013)

# every tick for anyone not dead
static func tick(s) -> void:
	if s.bleed <= 0.0:
		return
	s.hp -= s.bleed * G.DT
	s.drip_t -= G.DT
	if s.drip_t <= 0.0:
		s.drip_t = randf_range(0.8, 1.6) / maxf(0.4, s.bleed)
		var p: Vector3 = s.parts[1].global_position
		G.fx.bleed(p, Vector3(0, -1, 0), false)
		if randf() < 0.3:
			G.fx.decal(Vector3(p.x, G.world.ground_y(p.x, p.z), p.z), randf_range(0.2, 0.4), false)
	if s.hp <= 0.0 and s.state != "dead":
		Combat.kill(s, s.last_attacker, false)

# a dressing is going on (whoever is putting it on)
static func bandage_tick(s) -> void:
	s.bandage_t -= G.DT
	s.want = Vector3.ZERO
	s.crouch_t = 0.8
	var w = s.bandage_who if s.bandage_who != null and is_instance_valid(s.bandage_who) else s
	if w != s and (w.state == "dead" or G.dist2d(w.pos, s.pos) > 2.2):
		s.bandage_t = 0.0
		s.bandage_who = null
		return
	s.hand_t = w.chest() if w != s else s.chest() + Vector3(0, -0.15, 0)
	work_hands(s, w.chest() + Vector3(0, -0.05, 0) if w != s else s.chest() + Vector3(0, -0.18, 0), "wrap")
	if w != s:
		w.want = Vector3.ZERO
		s.body_yaw = G.turn_to(s.body_yaw, atan2(w.pos.x - s.pos.x, w.pos.z - s.pos.z), 6.0 * G.DT)
		s.aim_yaw = s.body_yaw
	if s.bandage_t <= 0.0:
		s.bandage_t = 0.0
		s.bandage_who = null
		s.hand_t = null
		s.dressings = maxi(0, s.dressings - 1)
		w.bleed = 0.0
		w.hp = minf(100.0, w.hp + (20.0 if s.cls == "medic" else 6.0))
		show_dressing(w)
		if s.cls == "medic" and w.has_meta("leg_wound"):
			w.remove_meta("leg_wound")
		if w != s:
			G.fx.callout(w, G.pick(["Thanks.", "Cheers, mate.", "That'll hold."]))
		elif s.is_player:
			G.ui.message("Wound dressed (%d dressing%s left)" % [s.dressings, "" if s.dressings == 1 else "s"])

# hands busy at a spot, seen from across the field: "wrap" winds a dressing round and round a wound,
# "rummage" reaches down into a crate or a dead man's pouches and back up to the belt
static func work_hands(s, p: Vector3, how: String) -> void:
	var ur = Vector3(-cos(s.body_yaw), 0, sin(s.body_yaw))
	var uf = Vector3(sin(s.body_yaw), 0, cos(s.body_yaw))
	var t = G.sim_time * (7.0 if how == "wrap" else 4.0) + float(s.id)
	if how == "wrap":
		var a = ur * 0.1 * cos(t) + Vector3(0, 0.08 * sin(t), 0)
		s.hands_t = [p + a - uf * 0.04, p - a + uf * 0.02]
	else:
		var belt = s.chest() + Vector3(0, -0.3, 0) + uf * 0.15
		var k = 0.5 + 0.5 * sin(t)
		s.hands_t = [p.lerp(belt, k) - ur * 0.08, p.lerp(belt, 1.0 - k) + ur * 0.08]
	s.hand_t = p
	s.set_meta("work_hands_t", G.sim_time)

# a white field dressing on a man who's been patched up, so you can see who's been seen to
static func show_dressing(w) -> void:
	if w.parts.size() < 4 or w.has_meta("dressing_mesh"):
		return
	var m = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(0.15, 0.07, 0.15)
	m.mesh = bm
	var mt = StandardMaterial3D.new()
	mt.albedo_color = Color(0.93, 0.91, 0.86)
	m.material_override = mt
	var part = w.parts[3 + randi() % 2 * 2] if randf() < 0.6 else w.parts[1]
	part.add_child(m)
	m.position = Vector3(0, 0.02, 0)
	w.set_meta("dressing_mesh", m)

static func start(s, who, t: float) -> void:
	s.bandage_t = t * (0.5 if s.cls == "medic" else 1.0)
	s.bandage_who = who
	AI.stop_move(s)

# AI: stop to dress a wound when it's safe enough, or patch up a bleeding buddy close by
static func ai_tick(s) -> bool:
	if s.bandage_t > 0.0:
		bandage_tick(s)
		if s.supp > (1.7 if s.in_cover or s.prone_t else 1.1) and s.bandage_who == null:
			s.bandage_t = 0.0      # too hot to stay put: carry on bleeding
		return s.bandage_t > 0.0
	if s.dressings <= 0 or s.task == "patch" or s.task == "medic":
		return false
	var safe = s.vis_t == null and s.supp < 0.5
	# a real wound gets seen to: behind cover he dresses it even with rounds coming over, out in the open
	# he first gets into cover (or flat on the ground) to do it
	var hurt = s.bleed > 0.35
	if not safe and not (s.in_cover and s.supp < (1.5 if hurt else 0.9)):
		if hurt and s.state == "alive" and s.vehicle == null and G.sim_time > s.get_meta("dress_cover_t", 0.0):
			s.set_meta("dress_cover_t", G.sim_time + 6.0)
			var cp = AI.find_cover(s, s.threat if s.has_seen else s.pos + Vector3(0, 0, 10), "hold")
			if cp != null and G.dist2d(cp.p, s.pos) < 18.0:
				AI.release_cover(s)
				AI.take_cover(s, cp)
				G.fx.callout(s, G.pick(["I'm hit! Getting into cover!", "Hit! Need to patch this!", "I'm bleeding, moving to cover!"]))
			elif s.vis_t == null or s.supp < 1.2:
				# nothing near: go flat and dress it where he lies
				AI.stop_move(s)
				s.prone_t = true
				start(s, null, SELF_T * 1.3)
				G.fx.callout(s, G.pick(["Hit! Dressing it!", "I'm bleeding!"]))
				return true
		return false
	# somebody close by bleeding worse than me?
	if s.state == "alive" and (s.think <= 0.05 or s.bleed > 0.0):
		for o in G.soldiers_near(s.pos):
			if o != s and o.team == s.team and o.state == "alive" and o.bleed > 0.25 and o.bandage_t <= 0.0 and o.bleed > s.bleed and G.dist2d(o.pos, s.pos) < 2.0:
				start(s, o, BUDDY_T)
				G.fx.callout(s, G.pick(["Hold still, I've got you.", "Let me get that.", "Pressure on it!"]))
				return true
	if s.bleed > 0.12:
		start(s, null, SELF_T)
		if randf() < 0.5:
			G.fx.callout(s, G.pick(["I'm bleeding, patching up!", "Hit! Dressing it!", "Need a second, I'm hit!"]))
		return true
	return false

# the player: H dresses a bleeding friend at your side, or your own wound
static func player_dress(s) -> void:
	if s.bandage_t > 0.0:
		return
	if s.dressings <= 0:
		G.ui.message("No field dressings left (a medic or an ammo crate has more)")
		return
	for o in G.soldiers_near(s.pos):
		if o != s and o.team == s.team and o.state != "dead" and o.bleed > 0.0 and G.dist2d(o.pos, s.pos) < 1.9:
			start(s, o, BUDDY_T)
			G.ui.message("Dressing %s's wound…" % o.sname)
			return
	if s.bleed <= 0.0:
		G.ui.message("You're not bleeding")
		return
	start(s, null, SELF_T)
	G.ui.message("Dressing your wound… (stay put)")


# ---------------------------------------------------------------- field hospitals and blood supply
# Each field hospital keeps a stock of blood. Wounded brought in are patched up and go back to the line;
# men who die close to one are worked on and, if there's blood to spare, return as reinforcements.
static var recovering: Array = []      # {"team", "cls", "name", "t", "site"}
static var regen_t = 0.0

static func reset_hospitals() -> void:
	recovering = []
	regen_t = 0.0

# a wounded man goes in through the tent flap; he comes back out patched up a while later
static func admit(s, st: Dictionary) -> void:
	st["blood"] = blood(st) - 1
	var r = {"team": s.team, "cls": s.cls, "name": s.sname, "t": G.sim_time + randf_range(14.0, 20.0), "site": st, "hp": 100.0,
		"kills": s.kills, "vet": s.vet, "squad": s.squad}
	if s.has_meta("roster"):
		r["roster"] = s.get_meta("roster")
	recovering.append(r)
	if G.pc != null and s in G.pc.selection:
		G.pc.selection.erase(s)
	if s.vehicle != null and is_instance_valid(s.vehicle):
		s.dismount(false)
	G.soldiers.erase(s)
	s.queue_free()

static func hospital_near(team: int, p: Vector3, r: float):
	var best = null
	var bd = r
	for st in Build.sites:
		if st["team"] == team and st["kind"] == "hospital" and Build.alive(st):
			var d = G.dist2d(st["p"], p)
			if d < bd:
				bd = d
				best = st
	return best

static func blood(st: Dictionary) -> int:
	if not st.has("blood"):
		st["blood"] = 6
	return st["blood"]

static func hospitals_tick(dt: float) -> void:
	regen_t += dt
	var regen = regen_t > 25.0
	if regen:
		regen_t = 0.0
	for st in Build.sites:
		if st["kind"] != "hospital" or not Build.alive(st):
			continue
		if regen:
			st["blood"] = mini(8, blood(st) + 1)
		# the wounded brought to the door are taken inside to be treated
		for s in G.soldiers.duplicate():
			if s.team == st["team"] and s.state == "wounded" and s.dragger == null and not s.has_meta("stretcher") and G.dist2d(s.pos, st["p"]) < 7.0 and blood(st) > 0:
				admit(s, st)
	for i in range(recovering.size() - 1, -1, -1):
		var r = recovering[i]
		if G.sim_time < r["t"]:
			continue
		recovering.remove_at(i)
		var st2 = r["site"]
		var p: Vector3 = st2["p"] if Build.alive(st2) else G.world.rally_point(r["team"])
		G.main.force_cls = [r["cls"]]
		var q = r.get("squad")
		if q != null and q in G.squads:
			AI.batch_begin({}, q)
		var n = G.main.spawn_soldier(r["team"], p.x + randf_range(-3, 3), p.z + randf_range(-3, 3), "")
		if q != null and q in G.squads:
			AI.batch_end()
		G.main.force_cls = []
		if n != null:
			n.sname = r["name"]
			n.hp = r.get("hp", 80.0)
			n.kills = r.get("kills", 0)
			if r.get("vet", 0) > 0:
				n.set_vet(r["vet"])
			if r.has("roster"):
				n.set_meta("roster", r["roster"])
			# straight back to the fight, not standing about at the tent
			n.order = null
			n.task = null
			n.decide_t = 0.0
			var front = Reinforce.forward_drop(r["team"])
			if G.dist2d(front, p) < 20.0:
				front = AI.objective_for(n)
			AI.go_to(n, front + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)), 4.6)
			G.fx.callout(n, G.pick(["Patched up. Back to it.", "Thanks, doc.", "I'm good to go."]))
			G.ui.radio(r["team"], "%s is back on his feet and returning to the line" % r["name"])

# called when a soldier dies: close to a field hospital with blood, he's saved and comes back later
static func try_save(s) -> void:
	if s.zombie or s.has_meta("general") or s.has_meta("pilot") or s.is_player:
		return
	var st = hospital_near(s.team, s.pos, 30.0)
	if st == null or blood(st) <= 0:
		return
	st["blood"] -= 1
	recovering.append({"team": s.team, "cls": s.cls, "name": s.sname, "t": G.sim_time + 30.0, "site": st})
	G.ui.radio(s.team, "Medics are working on %s at the field hospital" % s.sname)
	# the body is carried inside
	var wr = weakref(s)
	G.main.get_tree().create_timer(1.5, false).timeout.connect(func():
		var o = wr.get_ref()
		if o != null and o.state == "dead" and o != G.player:
			G.soldiers.erase(o)
			o.queue_free())
