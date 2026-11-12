class_name Comms
extends RefCounted
# Radio and runners. A side can call artillery, air support and reinforcements only while it
# has a working radio: a radio operator on his feet, a command truck, or a radio mast. Lose them
# and requests pile up until a runner carries them back to HQ on foot.

static var queue: Array = []        # per side: [{"what", "target"}]
static var runner: Array = []       # per side: the soldier carrying the message, or null
static var reinf_ok: Array = []     # reinforcement waves a runner has asked for
static var need_reinf: Array = []
static var wait_t: Array = []      # how long HQ has gone without word
static var had: Array = []
static var tick_t = 0.0
static var delivered = 0            # for the tests

static func reset() -> void:
	queue = []
	runner = []
	reinf_ok = []
	need_reinf = []
	had = []
	for t in range(G.team_count()):
		queue.append([])
		runner.append(null)
		reinf_ok.append(0)
		need_reinf.append(false)
		had.append(true)
		wait_t.append(0.0)
	tick_t = 0.0
	delivered = 0

static func ok(t: int) -> bool:
	for s in G.soldiers:
		if s.team == t and s.cls == "radio" and s.state == "alive":
			return true
	for v in G.vehicles:
		if v.team == t and v.kind == "radar" and not v.dead:
			return true
	for st in Build.sites:
		if st["team"] == t and st["kind"] == "radio" and Build.alive(st):
			return true
	return false

static func hq_pos(t: int) -> Vector3:
	var h = Build.hq(t)
	if h != null and Build.alive(h):
		return h["p"]
	return G.world.rally_point(t)

# a call-in when there may be no radio: false means go ahead now, true means it's been queued
static func hold(t: int, what: String, target: Vector3) -> bool:
	if queue.size() <= t or ok(t):
		return false
	if queue[t].size() < 3:
		queue[t].append({"what": what, "target": target})
	if t == 0 and G.player != null or G.mode == "commander" and t == 0:
		G.ui.message("No radio! A runner is taking the request for %s back to HQ" % Support.NAMES.get(what, what).split(" (")[0].to_lower())
	_send_runner(t)
	return true

# reinforcements: with no radio, a wave only comes once a runner has asked for it
static func reinforce_allowed(t: int) -> bool:
	if reinf_ok.size() <= t or ok(t):
		return true
	if reinf_ok[t] > 0:
		return true
	# nobody left out there to send, or no word for two minutes: HQ sends men up anyway
	if _pick_runner(t) == null or wait_t[t] > 120.0:
		wait_t[t] = 0.0
		need_reinf[t] = false
		return true
	if not need_reinf[t]:
		need_reinf[t] = true
		_send_runner(t)
	return false

static func used_reinf(t: int) -> void:
	if reinf_ok.size() > t and reinf_ok[t] > 0 and not ok(t):
		reinf_ok[t] -= 1

static func step(dt: float) -> void:
	if queue.is_empty() or G.over:
		return
	tick_t -= dt
	if tick_t > 0.0:
		return
	tick_t = 1.0
	for t in range(queue.size()):
		if G.mode == "horde" and t == 1:
			continue
		var has = ok(t)
		if not has and need_reinf[t]:
			wait_t[t] += 1.0
		if has != had[t]:
			had[t] = has
			if G.mode == "sandbox" or G.alive_count(t) == 0:
				continue        # nothing to report: nobody was relying on it
			if not has:
				G.ui.radio(t, "We've lost the radio! Messages to HQ go by runner now")
			else:
				G.ui.radio(t, "Radio's back on the net")
				# the radio's back: anything still waiting goes out at once
				_deliver(t, false)
		var r = runner[t]
		if r != null and (not is_instance_valid(r) or r.state == "dead"):
			if is_instance_valid(r) and r.state == "dead":
				G.ui.radio(t, "Our runner's been killed. Sending another")
			runner[t] = null
			r = null
		if r != null:
			if r.state == "alive" and G.dist2d(r.pos, hq_pos(t)) < 9.0:
				_deliver(t, true)
			elif r.state == "alive" and (r.order == null or r.order.get("point") == null or G.dist2d(r.order["point"], hq_pos(t)) > 3.0):
				r.order = {"mode": "move", "point": hq_pos(t)}
		elif not has and (not queue[t].is_empty() or need_reinf[t]):
			_send_runner(t)

static func _send_runner(t: int) -> void:
	if runner.size() <= t:
		return
	var r = runner[t]
	if r != null and is_instance_valid(r) and r.state != "dead":
		return
	var best = _pick_runner(t)
	if best == null:
		return
	var home = hq_pos(t)
	runner[t] = best
	best.set_meta("runner", true)
	best.order = {"mode": "move", "point": home}
	AI.release_cover(best)
	G.fx.callout(best, G.pick(["I'll run it back to HQ!", "Runner going! Cover me!", "Taking the message back!"]))
	G.ui.radio(t, "A runner is on his way back to HQ")

# someone who isn't in the middle of a fight, and the further forward the better (that's where the news is)
static func _pick_runner(t: int):
	var home = hq_pos(t)
	var best = null
	var bs = -1e9
	for s in G.soldiers:
		if s.team != t or s.state != "alive" or s.is_player or s.vehicle != null or s.zombie:
			continue
		if s.has_meta("general") or s.has_meta("guard") or s.cls in ["officer", "medic", "engineer"] or s.task == "medic":
			continue
		var d = G.dist2d(s.pos, home)
		if d < 15.0:
			continue
		var sc = -absf(d - 60.0) - (40.0 if s.vis_t != null else 0.0) - s.supp * 20.0 + randf() * 10.0
		if sc > bs:
			bs = sc
			best = s
	return best

static func _deliver(t: int, by_runner: bool) -> void:
	var items: Array = queue[t].duplicate()
	queue[t].clear()
	for it in items:
		if Support.call_in(t, it["what"], it["target"], true):
			delivered += 1
	if need_reinf[t] and by_runner:
		reinf_ok[t] += 1
		need_reinf[t] = false
		Reinforce.timers[t] = maxf(Reinforce.timers[t], 25.0)
	if by_runner:
		var r = runner[t]
		if r != null and is_instance_valid(r):
			r.remove_meta("runner")
			r.order = null
			G.fx.callout(r, "Message for HQ!")
		runner[t] = null
		G.ui.radio(t, "The runner made it to HQ" + (": support is on the way" if not items.is_empty() else ": reinforcements are being sent up"))
