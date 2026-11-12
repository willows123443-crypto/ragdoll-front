class_name Fog
extends RefCounted
# Commander mode's fog of war: enemy soldiers and vehicles only show while one of your men can see them
# (or they're right on top of him), and enemy structures only once someone has found them.
# Gunfire still flashes in the dark, so you can tell where a fight is going on.

static var on = false
static var tick = 0.0

static func reset() -> void:
	on = G.mode == "commander"
	tick = 0.0
	for s in G.soldiers:
		if s.has_meta("fogged"):
			s.remove_meta("fogged")

static func hidden(s) -> bool:
	return on and s.has_meta("fogged")

static func step(dt: float) -> void:
	if not on:
		return
	tick -= dt
	if tick > 0.0:
		return
	tick = 0.25
	var sight = 32.0 if G.main.is_night() else 70.0
	var mine: Array = []
	var eyes: Array = []
	for s in G.soldiers:
		if s.team == 0 and (s.state == "alive" or s.state == "riding" or s.state == "wounded"):
			mine.append(s.pos)
			eyes.append(s)
	for v in G.vehicles:
		if v.team == 0 and not v.dead:
			mine.append(v.pos)
	# your HQ and forward bases keep a lookout of their own: anything that comes near them shows,
	# even with none of your men left standing there
	var posts: Array = []
	for st in Build.sites:
		if st["team"] == 0 and Build.alive(st) and st["kind"] in ["hq", "fob", "fob2", "bunker", "tower", "pillbox"]:
			posts.append([st["p"], 55.0 if st["kind"] == "hq" else 35.0])
	# vehicles first: seen up close (or by their lights), or because someone's spotted a man aboard
	for v in G.vehicles:
		if v.team == 0:
			continue
		var vv = v.dead
		var vs = 140.0 if v.lights_on else sight      # headlights give it away from far off
		if not vv:
			for p in mine:
				if G.dist2d(p, v.pos) < vs:
					vv = true
					break
		if not vv:
			for ps in posts:
				if G.dist2d(ps[0], v.pos) < ps[1]:
					vv = true
					break
		if not vv:
			for seat in v.seats:
				if seat != null and is_instance_valid(seat):
					for o in eyes:
						var k2 = o.intel.get(seat)
						if k2 != null and k2["seen"] and G.sim_time - k2["t"] < 1.2:
							vv = true
							break
				if vv:
					break
		v.visible = vv
	for s in G.soldiers:
		if s.team == 0:
			continue
		# a man in a vehicle shows exactly when his vehicle does: never floating on his own in the fog
		if s.state == "riding" and s.vehicle != null and is_instance_valid(s.vehicle):
			_show(s, s.vehicle.visible)
			continue
		var vis = s.state == "dead"
		if not vis:
			for p in mine:
				if G.dist2d(p, s.pos) < 12.0:
					vis = true
					break
		if not vis:
			for ps in posts:
				if G.dist2d(ps[0], s.pos) < ps[1] * 0.8:
					vis = true
					break
		if not vis:
			for o in eyes:
				var k = o.intel.get(s)
				if k != null and k["seen"] and G.sim_time - k["t"] < 1.2:
					vis = true
					break
		if not vis:
			# anyone of ours with a clear line to him: the nearest few within eyesight look (the AI's
			# own sighting reports only cover the men each soldier is paying attention to, so a man in
			# plain view could stay hidden)
			var near: Array = []
			for o in eyes:
				if o.state == "riding" and o.hidden_in_vehicle:
					continue
				var d = G.dist2d(o.pos, s.pos)
				if d < sight:
					near.append([d, o])
			near.sort_custom(func(a, b): return a[0] < b[0])
			var tgt = s.chest() if s.has_method("chest") else s.pos + Vector3(0, 1.2, 0)
			for i in range(mini(3, near.size())):
				if not G.blocked(near[i][1].head_pos(), tgt, true):
					vis = true
					break
		if not vis and G.sim_time - s.get_meta("fog_seen_t", -99.0) < 1.5:
			vis = true          # a moment's grace so a man ducking in and out of view doesn't flicker
		if vis:
			s.set_meta("fog_seen_t", G.sim_time)
		if not vis:
			# an observer post's view
			for st in Build.sites:
				if st["team"] == 0 and st["kind"] == "observer" and Build.alive(st) and s in st.get("sees", []):
					vis = true
					break
		_show(s, vis)
	for st in Build.sites:
		if st["team"] == 0 or st.get("seen0", false):
			continue
		var found = st["kind"] == "hq"         # where their HQ is, is known from the start
		if not found:
			for p in mine:
				if G.dist2d(p, st["p"]) < sight * 0.9:
					found = true
					break
		if found:
			st["seen0"] = true
			if is_instance_valid(st["root"]):
				st["root"].visible = true
		elif is_instance_valid(st["root"]):
			st["root"].visible = false

static func _show(s, vis: bool) -> void:
	if s.has_meta("fogged") == (not vis):
		return
	if vis:
		s.remove_meta("fogged")
		s.visible = not s.hidden_in_vehicle and not s.has_meta("fv_hid")
	else:
		s.set_meta("fogged", true)
		s.visible = false
