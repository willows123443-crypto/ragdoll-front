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


# ---------------------------------------------------------------- a battle in progress
# One slot. What's kept: the map and what's been destroyed on it, every man still standing (his name,
# rank, weapon, wounds and ammunition), every vehicle and how badly it's hit, what's been built, the
# orders, the score, the points held, supply, and the wave in a zombie battle. What isn't: shells in
# the air, fires, bodies, who was in which squad or riding in the back of what (men are put back on
# foot where they were, and squads form again), and what each man was in the middle of doing.
const SAVE_PATH = "user://battle.save"
static var pending_ruins: Array = []

static func can_save() -> String:
	if not G.started or G.over or G.attract:
		return "there's no battle to save"
	if Campaign.active:
		return "not in a campaign battle: the campaign saves itself"
	if G.tutorial:
		return "the first battle can't be saved"
	return ""

static func capture_battle() -> Dictionary:
	var d = capture()
	d["battle"] = true
	d["soldiers"] = []
	d["men"] = []
	d["vhp"] = []
	d["squads"] = {}
	# the vehicles first, so a man aboard one can be written down by which it was and which seat
	var vidx = {}
	for v in G.vehicles:
		if v.dead or v.mission != null or v.spec.get("plane", false):
			continue
		vidx[v] = d["vhp"].size()
		d["vhp"].append(v.hp / maxf(v.spec["hp"], 1.0))
	for e in d["vehicles"]:
		e[5] = false           # (they're put back empty, and the men who were in them are seated one by one)
	for s in G.soldiers:
		if s.state == "dead":
			continue
		if s.vehicle != null and not vidx.has(s.vehicle):
			continue           # (aboard something that isn't kept: a lorry on a supply run, an aircraft)
		var sq = G.squads.find(s.squad) if s.squad != null else -1
		if sq >= 0 and not d["squads"].has(sq):
			d["squads"][sq] = {"crew": bool(s.squad.get("crew", false)), "form": str(s.squad.get("form", "wedge")), "guard": bool(s.squad.get("guard", false)), "follow": bool(s.squad.get("follow", false))}
		var m = {"t": s.team, "x": snappedf(s.pos.x, 0.1), "z": snappedf(s.pos.z, 0.1), "y": snappedf(s.pos.y, 0.1), "cls": s.cls, "w": s.wid, "hp": s.hp, "mag": s.mag, "res": s.reserve,
			"gr": s.grenades, "sm": s.smokes, "name": s.sname, "vet": s.vet, "zk": s.ztype if s.zombie else "", "sq": sq,
			"ord": [s.order["mode"], s.order["point"].x, s.order["point"].z] if s.order != null and s.order.get("point") != null and s.order["mode"] in ["move", "hold"] else null}
		if s.vehicle != null:
			m["veh"] = [vidx[s.vehicle], s.seat]
		d["men"].append(m)
	var ru = []
	var W = G.world
	for k in range(W.static_cols.size()):
		if not W.static_cols[k].alive and W.static_cols[k].dest:
			ru.append(k)
	d["ruins"] = ru
	d["score"] = G.score.duplicate()
	d["sup"] = Support.points.duplicate()
	d["tickets"] = Obj.tickets.duplicate()
	d["pts"] = Obj.points.map(func(p): return [int(p.get("owner", -1)), float(p.get("prog", 0.0))])
	d["horde"] = [Modes.horde_wave, Modes.horde_left, Modes.horde_side]
	d["elapsed"] = G.game_time
	d["weather"] = G.settings.get("weather", "clear")
	return d

static func save_battle() -> String:
	var why = can_save()
	if why != "":
		return "Not saved: " + why
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return "Not saved: the save file couldn't be written"
	var d = capture_battle()
	f.store_var(d)
	f.close()
	return "Battle saved: %d men, %d vehicles, %d pieces of the map in ruins" % [d["men"].size(), d["vehicles"].size(), d["ruins"].size()]

static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

static func save_text() -> String:
	if not has_save():
		return ""
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return ""
	var d = f.get_var()
	if not (d is Dictionary) or not d.get("battle", false):
		return ""
	var mins = int(float(d.get("elapsed", 0.0)) / 60.0)
	return "%s on %s, %d min in, %d men" % [str(d["mode"]).capitalize(), G.world.MAPS.get(d["map"], {}).get("name", d["map"]) if G.world != null else str(d["map"]), mins, d["men"].size()]

static func load_battle() -> String:
	if not has_save():
		return "No saved battle"
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var d = f.get_var() if f != null else null
	if not (d is Dictionary) or not d.get("battle", false):
		return "The saved battle couldn't be read"
	pending_ruins = d.get("ruins", [])
	var nv0 = d.get("vehicles", []).size()
	apply(d)
	pending_ruins = []
	# the vehicles' damage (they were put back, empty, in the order they were saved in)
	var vh: Array = d.get("vhp", [])
	var live = G.vehicles.filter(func(v): return is_instance_valid(v) and not v.dead)
	for k in range(mini(mini(vh.size(), nv0), live.size())):
		live[k].hp = maxf(1.0, float(vh[k]) * live[k].spec["hp"])
	# the men, a squad at a time so each squad comes back as the squad it was; a man who was aboard a
	# vehicle is put back in his seat
	var groups = {}
	var order = []
	for m in d.get("men", []):
		var key = int(m.get("sq", -1))
		if not groups.has(key):
			groups[key] = []
			order.append(key)
		groups[key].append(m)
	var sqd: Dictionary = d.get("squads", {})
	for key in order:
		var info: Dictionary = sqd.get(key, {})
		if key >= 0:
			var extra = {}
			for flag in ["crew", "guard", "follow"]:
				if info.get(flag, false):
					extra[flag] = true
			AI.batch_begin(extra)
		var made = null
		for m in groups[key]:
			var zk = str(m.get("zk", ""))
			if zk != "":
				Soldier.zombie_next = zk
			var s = G.main.spawn_soldier(int(m["t"]), float(m["x"]), float(m["z"]), "pistol" if zk != "" else str(m["w"]))
			Soldier.zombie_next = ""
			if s == null:
				continue
			if zk != "":
				Modes.make_zombie(s, zk)
			else:
				s.set_class(str(m["cls"]))
				if s.wid != str(m["w"]):
					s.set_weapon(str(m["w"]))
				s.mag = int(m["mag"])
				s.reserve = int(m["res"])
				s.grenades = int(m["gr"])
				s.smokes = int(m["sm"])
				s.sname = str(m["name"])
				s.set_vet(int(m["vet"]))
			s.hp = float(m["hp"])
			if float(m["y"]) > G.world.ground_y(s.pos.x, s.pos.z) + 1.5:
				s.pos.y = float(m["y"])          # (he was upstairs)
			if m.get("ord") != null:
				s.order = {"mode": m["ord"][0], "point": Vector3(m["ord"][1], G.world.ground_y(m["ord"][1], m["ord"][2]), m["ord"][2])}
			if m.has("veh") and int(m["veh"][0]) < live.size():
				var v = live[int(m["veh"][0])]
				var seat = int(m["veh"][1])
				if seat >= 0 and seat < v.seats.size() and v.seats[seat] == null:
					s.mount(v, seat)
			made = s
		if key >= 0:
			AI.batch_end()
			if made != null and made.squad != null and info.has("form"):
				made.squad["form"] = info["form"]
	if d.has("score"):
		for k in range(mini(G.score.size(), d["score"].size())):
			G.score[k] = d["score"][k]
	for k in range(mini(Support.points.size(), d.get("sup", []).size())):
		Support.points[k] = d["sup"][k]
	for k in range(mini(Obj.tickets.size(), d.get("tickets", []).size())):
		Obj.tickets[k] = d["tickets"][k]
	var pts: Array = d.get("pts", [])
	for k in range(mini(Obj.points.size(), pts.size())):
		var was: int = int(Obj.points[k].get("owner", -1))
		Obj.points[k]["owner"] = int(pts[k][0])
		Obj.points[k]["prog"] = float(pts[k][1])
		if was != int(pts[k][0]) and int(pts[k][0]) >= 0 and k < G.main.point_flags.size():
			G.main._set_flag_color(G.main.point_flags[k], G.TEAM_BAND[int(pts[k][0])])
	if G.mode == "horde" and d.has("horde"):
		Modes.horde_wave = int(d["horde"][0])
		Modes.horde_left = int(d["horde"][1])
		Modes.horde_side = int(d["horde"][2])
		Modes.horde_t = Modes.BREAK
	G.game_time = float(d.get("elapsed", 0.0))       # (the battle clock carries on from where it was)
	G.main.refresh_markers()
	return "Saved battle loaded: %d men back on the field" % d.get("men", []).size()
