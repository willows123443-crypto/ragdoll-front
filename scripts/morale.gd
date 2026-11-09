class_name Morale
extends RefCounted
# Morale and squad leaders.
# Every soldier has morale from 0 to 100. Being shot at, hit, losing friends or the squad leader,
# and being outnumbered wear it down; friends, a leader close by, kills and quiet moments build it back up.
# Below SHAKEN a soldier fights worse and hugs cover; below BROKEN they run for the rear until they recover.

const SHAKEN = 32.0
const BROKEN = 12.0
const RECOVER = 42.0

static func shock(s, amount: float) -> void:
	if s.state == "dead" or s.is_player:
		return
	s.morale = maxf(0.0, s.morale - amount * s.nerve)

static func boost(s, amount: float) -> void:
	if s.state == "dead":
		return
	s.morale = minf(100.0, s.morale + amount)

static func is_leader(s) -> bool:
	return s.squad != null and s.squad.get("leader") == s

static func on_death(dead, attacker) -> void:
	var lost_leader = is_leader(dead)
	var said = false
	for o in G.soldiers:
		if o == dead or o.state == "dead":
			continue
		var d = o.pos.distance_to(dead.pos)
		if o.team == dead.team:
			if d < 25.0:
				shock(o, 14.0 * (1.0 - d / 32.0))
			if lost_leader and o.squad == dead.squad:
				shock(o, 16.0)
				if not said and o.is_up():
					said = true
					G.fx.callout(o, G.pick(["The sarge is down!", "We lost the lieutenant!", "Who's in charge now?!"]))
		elif attacker != null and o == attacker:
			boost(o, 9.0)
		elif d < 30.0:
			boost(o, 3.0)
	if lost_leader:
		dead.set_leader(false)
		dead.squad["leader"] = null
		dead.squad["promote_t"] = G.sim_time + 5.0

# called twice a second for every living soldier
static func tick(s, dt: float) -> void:
	if s.state == "dead":
		return
	var q = s.squad
	# a new leader steps up a few seconds after the old one falls
	if q != null and q.get("leader") == null and G.sim_time > q.get("promote_t", 0.0):
		var best = null
		for m in q["members"]:
			if is_instance_valid(m) and m.state == "alive" and (best == null or m.morale > best.morale):
				best = m
		if best != null:
			q["leader"] = best
			best.set_leader(true)
			boost(best, 15.0)
			G.fx.callout(best, G.pick(["I'm taking command! On me!", "I've got the squad, follow me!", "Listen up, I'm in charge now!"]))
	if s.is_player:
		s.morale = maxf(s.morale, 60.0)
		_leader_aura(s)
		return
	if s.state != "alive" and s.state != "riding":
		return
	var friends = 0
	var leader_near = false
	for o in G.soldiers:
		if o == s or o.team != s.team or o.state != "alive":
			continue
		var d2 = o.pos.distance_squared_to(s.pos)
		if d2 < 144.0:
			friends += 1
		if d2 < 400.0 and is_leader(o) and o.squad == s.squad and o.morale > SHAKEN:
			leader_near = true
	var enemies = 0
	for e in s.intel.values():
		if e["seen"] and G.sim_time - e["t"] < 4.0 and e["p"].distance_to(s.pos) < 45.0:
			enemies += 1
	var rate = 1.0
	rate += minf(friends, 4) * 0.35
	if leader_near:
		rate += 1.4
	if is_leader(s):
		rate += 0.8
	if s.supp > 0.4:
		rate -= 1.0
	if enemies > friends + 1:
		rate -= (enemies - friends - 1) * 0.7
	if s.hp < 50.0:
		rate -= 0.6
	if G.sim_time - s.seen_t > 15.0:
		rate += 2.5
	if s.broken and G.sim_time - s.seen_t > 6.0:
		rate += 2.0
	var cap = s.nerve_cap
	if s.morale > cap and rate > 0.0:
		rate = -0.5
	s.morale = clampf(s.morale + rate * dt, 0.0, 100.0)
	# breaking and recovering
	if not s.broken and s.morale < BROKEN and s.task != "flee":
		s.broken = true
		Stats.rout(s)
		AI.release_cover(s)
		s.route = null
		s.task = "rout"
		s.prone_t = false
		var home: Vector3 = G.world.rally_point(s.team)
		AI.go_to(s, home + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)), 5.8)
		G.fx.callout(s, G.pick(["Fall back! Fall back!", "I'm getting out of here!", "We can't hold!", "Retreat!"]))
	elif s.broken and s.morale > RECOVER:
		s.broken = false
		s.task = null
		s.decide_t = 0.0
		G.fx.callout(s, G.pick(["Okay... okay, I'm good.", "Getting back in it!", "Alright, let's go again."]))
	if is_leader(s):
		_leader_aura(s)

# leaders steady the men around them and rally anyone who has run
static func _leader_aura(s) -> void:
	s.rally_cd -= 0.5
	if s.rally_cd > 0.0 or s.morale < 45.0 or s.state != "alive":
		return
	var rallied = false
	for o in G.soldiers:
		if o.team == s.team and o != s and o.state == "alive" and o.broken and o.pos.distance_to(s.pos) < 28.0:
			boost(o, 26.0)
			rallied = true
	if rallied:
		s.rally_cd = 12.0
		G.fx.callout(s, G.pick(["Rally on me!", "Hold together, men!", "On me! Form up!"]))
