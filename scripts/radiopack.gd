class_name RadioPack
extends RefCounted
# The squad radio is a real set on a real man's back. Only a man carrying one can call the guns in,
# so when its operator goes down his squad has no artillery until somebody runs over, takes the set
# off him and carries on.

static var dropped: Array = []
static var taken = 0      # {"body", "team", "squad", "t", "by"}

static func reset() -> void:
	dropped = []

# the operator is down: the set stays on his back until someone comes for it
static func on_death(s) -> void:
	if s.radio_pack == null:
		return
	dropped.append({"body": s, "team": s.team, "squad": s.squad, "t": G.sim_time, "by": null, "by_t": 0.0})
	var near = null
	var nd = 30.0
	for o in G.soldiers:
		if o != s and o.team == s.team and o.state == "alive" and not o.is_player:
			var d = G.dist2d(o.pos, s.pos)
			if d < nd:
				nd = d
				near = o
	if near != null:
		G.fx.callout(near, G.pick(["Radioman's down!", "We've lost the radio!", "Sparks is hit! Get the set!"]))

static func squad_has_radio(q) -> bool:
	if q == null:
		return false
	for m in q["members"]:
		if is_instance_valid(m) and m.state == "alive" and m.radio_pack != null:
			return true
	return false

# about once a second: send the nearest free man for each set lying on a body
static func step() -> void:
	for i in range(dropped.size() - 1, -1, -1):
		var d = dropped[i]
		var body = d["body"]
		if not is_instance_valid(body) or body.radio_pack == null or G.sim_time - d["t"] > 300.0:
			dropped.remove_at(i)
			continue
		var at: Vector3 = body.parts[0].global_position if body.parts.size() > 0 else body.pos
		var by = d["by"]
		if by != null and (not is_instance_valid(by) or by.state != "alive" or by.task != "get_radio" or G.sim_time - d["by_t"] > 40.0):
			if by != null and is_instance_valid(by) and by.task == "get_radio":
				by.task = null
			d["by"] = null
			by = null
		if by != null:
			if G.dist2d(by.pos, at) < 1.7:
				_take(by, body)
				dropped.remove_at(i)
			elif by.move_target == null:
				AI.go_to(by, at, 5.0)
			continue
		# whoever's closest goes for it: his own squad first, any of the side if there's nobody else near
		var best = null
		var bs = 1e9
		for o in G.soldiers:
			if o.team != d["team"] or o.state != "alive" or o.is_player or o.vehicle != null or o.radio_pack != null or o.broken:
				continue
			if o.cls == "medic" or ClassAI.busy(o) or o.task in ["stretcher", "get_radio", "charge"]:
				continue
			var dd = G.dist2d(o.pos, at)
			if dd > 45.0:
				continue
			var sc = dd + (0.0 if o.squad == d["squad"] else 15.0) + (8.0 if o.vis_t != null else 0.0)
			if sc < bs:
				bs = sc
				best = o
		if best != null:
			d["by"] = best
			d["by_t"] = G.sim_time
			AI.release_cover(best)
			best.task = "get_radio"
			best.prone_t = false
			AI.go_to(best, at, 5.0)
			G.fx.callout(best, G.pick(["I'll get the radio!", "Cover me, going for the set!", "Getting the radio!"]))

static func _take(s, body) -> void:
	taken += 1
	body.give_radio(false)
	s.give_radio(true)
	s.task = null
	s.radio_cd = maxf(s.radio_cd, 10.0)
	s.decide_t = 0.0
	G.fx.callout(s, G.pick(["Got the radio!", "Radio's working, I'm on it!", "I've got the set!"]))
