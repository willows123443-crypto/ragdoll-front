class_name Scenario
extends RefCounted
# Battle setups as shareable codes: the map, mode and options, every soldier, vehicle and structure
# where it stands, and the orders in force. Copy the code, send it to a friend, paste it to load.

const PREFIX = "RF1:"

static func capture() -> Dictionary:
	var d = {"v": 1, "map": G.map_id, "seed": G.random_seed, "mode": G.mode, "teams": G.team_count(), "size": G.team_size,
		"limit": G.limit, "reinforce": G.reinforce, "reinf_mode": G.reinf_mode, "armor": G.armor, "time": G.settings["time"],
		"team_cfg": G.team_cfg.duplicate(true), "soldiers": [], "vehicles": [], "sites": [], "orders": []}
	if G.map_id == "custom":
		d["custom"] = G.custom_map
	for s in G.soldiers:
		if s.state == "dead" or s.state == "riding":
			continue
		var o = s.order
		var od = null
		if o != null and o.get("point") != null and o["mode"] in ["move", "hold"]:
			od = [o["mode"], o["point"].x, o["point"].z]
		d["soldiers"].append([s.team, snappedf(s.pos.x, 0.1), snappedf(s.pos.z, 0.1), s.cls, s.wid, od])
	for v in G.vehicles:
		if v.dead or v.mission != null or v.spec.get("plane", false):
			continue
		var crew = 0
		for x in v.seats:
			if x != null:
				crew += 1
		d["vehicles"].append([v.kind, v.team, snappedf(v.pos.x, 0.1), snappedf(v.pos.z, 0.1), snappedf(v.yaw, 0.01), crew > 0])
	for st in Build.sites:
		if st["dead"]:
			continue
		var f = Build._front(st)
		d["sites"].append([st["kind"], st["team"], snappedf(st["p"].x, 0.1), snappedf(st["p"].z, 0.1), f.x, f.z, st["done"], st.get("camo", false)])
	for o in G.orders:
		if o.get("point") != null:
			d["orders"].append([o["mode"], o["point"].x, o["point"].z])
		else:
			d["orders"].append([o["mode"]])
	return d

static func encode(d: Dictionary) -> String:
	var raw = var_to_bytes(d)
	var z = raw.compress(FileAccess.COMPRESSION_GZIP)
	return PREFIX + str(raw.size()) + ":" + Marshalls.raw_to_base64(z)

static func decode(code: String):
	code = code.strip_edges().replace("\n", "").replace(" ", "")
	if not code.begins_with(PREFIX):
		return null
	var rest = code.substr(PREFIX.length())
	var i = rest.find(":")
	if i < 0:
		return null
	var n = int(rest.substr(0, i))
	var z = Marshalls.base64_to_raw(rest.substr(i + 1))
	if z.is_empty():
		return null
	var raw = z.decompress(n, FileAccess.COMPRESSION_GZIP)
	if raw.size() != n:
		return null
	var d = bytes_to_var(raw)
	return d if d is Dictionary and d.get("v", 0) == 1 else null

# rebuild a battle from a saved setup
static func apply(d: Dictionary) -> void:
	G.random_seed = d.get("seed", G.random_seed)
	if d.has("team_cfg"):
		G.team_cfg = d["team_cfg"]
	if d.has("custom"):
		G.custom_map = d["custom"]
	var keep_t = G.settings["time"]
	G.settings["time"] = d.get("time", keep_t)
	G.main.apply_time()
	G.settings["time"] = keep_t
	G.main.start_game({"map": d["map"], "mode": d["mode"], "size": d.get("size", 10), "limit": d.get("limit", 100),
		"reinforce": d.get("reinforce", true), "reinf_mode": d.get("reinf_mode", "truck"), "armor": d.get("armor", "light"), "teams": d.get("teams", 2)})
	# swap the default armies and bases for the saved ones
	for v in G.vehicles.duplicate():
		v.remove()
	for s in G.soldiers.duplicate():
		G.soldiers.erase(s)
		s.queue_free()
	G.squads.clear()
	for st in Build.sites.duplicate():
		Build._remove_quietly(st)
	for e in d.get("sites", []):
		var st = Build.place(e[0], e[1], Vector3(e[2], 0, e[3]), Vector3(e[4], 0, e[5]), e[6])
		if e.size() > 7 and e[7] and e[6]:
			Build.add_camo(st)
	for e in d.get("soldiers", []):
		var s = G.main.spawn_soldier(e[0], e[1], e[2], e[4])
		if s != null:
			s.set_class(e[3])
			if e.size() > 5 and e[5] != null:
				s.order = {"mode": e[5][0], "point": Vector3(e[5][1], G.world.ground_y(e[5][1], e[5][2]), e[5][2])}
	for e in d.get("vehicles", []):
		G.main.spawn_vehicle(e[0], e[1], Vector3(e[2], 0, e[3]), e[4], e[5])
	var ords = d.get("orders", [])
	for t in range(mini(ords.size(), G.orders.size())):
		var o = ords[t]
		G.orders[t] = {"mode": o[0], "point": Vector3(o[1], G.world.ground_y(o[1], o[2]), o[2]) if o.size() > 2 else null}
	G.main.refresh_markers()
