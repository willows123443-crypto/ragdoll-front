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
		"reinforce": d.get("reinforce", true), "reinf_mode": d.get("reinf_mode", "truck"), "armor": d.get("armor", "light"), "teams": d.get("teams", 2),
		"caps": d.get("caps", [])})
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
# Two slots: one for a quick battle and one for the campaign's battle, so saving either leaves the other
# alone. (There was one, and a campaign battle saved over a quick one.) What's kept: the map and what's been destroyed on it, every man still standing (his name,
# rank, weapon, wounds and ammunition), every vehicle and how badly it's hit, what's been built, the
# orders, the score, the points held, supply, the squads, who was aboard which vehicle, the battle
# clock, the wave in a zombie battle with what's boarded up and any supply drop waiting to be fetched, and in a campaign battle each man's place in the campaign, the
# reserves still to come and who has fallen so far. What isn't: shells in the air, fires, bodies, and
# what each man was in the middle of doing.
const SAVE_PATH = "user://battle.save"
const CAMP_PATH = "user://campaign_battle.save"

# Five slots for quick battles, each with a name, and one for the campaign's battle. (The first quick
# slot is the file there has always been.)
const SLOTS = 5

static func slot_path(camp: bool, slot: int = 1) -> String:
	if camp:
		return CAMP_PATH
	return SAVE_PATH if slot <= 1 else "user://battle_%d.save" % slot

# what a save would be called if nobody types a name
static func default_name() -> String:
	var where = G.world.MAPS.get(G.map_id, {}).get("name", G.map_id)
	if G.mode == "horde":
		return "%s, wave %d" % [where, Modes.horde_wave]
	return "%s on %s" % [G.mode.capitalize(), where]

static func _ago(when: float) -> String:
	if when <= 0.0:
		return ""
	var s = Time.get_unix_time_from_system() - when
	if s < 90.0:
		return "saved just now"
	if s < 5400.0:
		return "saved %d min ago" % int(s / 60.0)
	if s < 129600.0:
		return "saved %d h ago" % int(round(s / 3600.0))
	return "saved %d days ago" % int(round(s / 86400.0))

# every quick slot: {"slot", "text" ("" when it's empty), "name"}
static func slot_list() -> Array:
	var out = []
	for i in range(1, SLOTS + 1):
		var d = _read_save(false, i)
		out.append({"slot": i, "text": save_text(false, i), "name": str(d.get("name", "")) if d != null else ""})
	return out

static func used_slots() -> Array:
	var out = []
	for i in range(1, SLOTS + 1):
		if _read_save(false, i) != null:
			out.append(i)
	return out

static func delete_slot(slot: int) -> void:
	var path = slot_path(false, slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
static var pending_ruins: Array = []

static func can_save() -> String:
	if not G.started or G.over or G.attract:
		return "there's no battle to save"
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
		# Aboard something that isn't itself kept (a lorry bringing men up, a landing craft): he is put
		# down on foot where it was. (Men riding up from reserve vanished from a saved campaign battle.)
		# Only a man in an aircraft, or over water, is left out.
		var foot = false
		if s.vehicle != null and not vidx.has(s.vehicle):
			if s.vehicle.spec.get("plane", false) or s.vehicle.spec.get("air", false) or (not G.world.water.is_empty() and G.world.in_water(s.pos.x, s.pos.z)):
				continue
			foot = true
		var sq = G.squads.find(s.squad) if s.squad != null else -1
		if sq >= 0 and not d["squads"].has(sq):
			d["squads"][sq] = {"crew": bool(s.squad.get("crew", false)), "form": str(s.squad.get("form", "wedge")), "guard": bool(s.squad.get("guard", false)), "follow": bool(s.squad.get("follow", false))}
		var m = {"t": s.team, "x": snappedf(s.pos.x, 0.1), "z": snappedf(s.pos.z, 0.1), "y": snappedf(G.world.ground_y(s.pos.x, s.pos.z) if foot else s.pos.y, 0.1), "cls": s.cls, "w": s.wid, "hp": s.hp, "mag": s.mag, "res": s.reserve,
			"gr": s.grenades, "sm": s.smokes, "name": s.sname, "vet": s.vet, "zk": (str(s.get_meta("boss")) if s.has_meta("boss") else s.ztype) if s.zombie else "", "sq": sq,
			"ord": [s.order["mode"], s.order["point"].x, s.order["point"].z] if s.order != null and s.order.get("point") != null and s.order["mode"] in ["move", "hold"] else null}
		if s.vehicle != null and not foot:
			m["veh"] = [vidx[s.vehicle], s.seat]
		# (his place in the campaign: the company commander, a man come up from reserve, or one of the roster)
		if s.has_meta("co"):
			m["co"] = true
		elif s.has_meta("reserve"):
			m["rs"] = [int(s.get_meta("reserve")), int(s.get_meta("res_k"))]
		elif s.has_meta("roster"):
			m["ro"] = int(s.get_meta("roster"))
		d["men"].append(m)
	var ru = []
	var W = G.world
	for k in range(W.static_cols.size()):
		var sc = W.static_cols[k]
		# (a piece knocked down and since rebuilt comes back whole)
		if not sc.alive and sc.dest and not (sc.has_meta("rebuilt") and sc.get_meta("rebuilt").alive):
			ru.append(k)
	d["ruins"] = ru
	d["caps"] = G.team_caps.duplicate()
	# the state of the mode itself: the clock and supplies of a siege, the reinforcement waves, the hill
	# that moves. (A siege saved with 4:39 left came back with 7:45.)
	d["obj"] = {"all_t": Obj.all_t.duplicate(), "bleed_t": Obj.bleed_t, "wave": Obj.wave, "wave_t": Obj.wave_t, "wave_left": Obj.wave_left, "phase": Obj.phase,
		"hold_t": Obj.hold_t, "supply": Obj.supply, "siege_t": Obj.siege_t, "mode_t": Obj.mode_t, "koth_t": Modes.koth_t, "koth_moves": Modes.koth_moves, "rescue_t": Modes.rescue_t}
	if Campaign.active:
		d["camp"] = Campaign.battle_state()
	d["endless"] = Modes.horde_endless
	if G.mode == "horde":
		d["boards"] = Modes.boards_state()
		d["drops"] = Modes.drops.map(func(q): return [q["p"].x, q["p"].z, q["t"]])
		d["hdiff"] = Modes.diff()
	d["score"] = G.score.duplicate()
	d["sup"] = Support.points.duplicate()
	d["tickets"] = Obj.tickets.duplicate()
	d["pts"] = Obj.points.map(func(p): return [int(p.get("owner", -1)), float(p.get("prog", 0.0))])
	d["horde"] = [Modes.horde_wave, Modes.horde_left, Modes.horde_side]
	d["elapsed"] = G.game_time
	d["weather"] = G.settings.get("weather", "clear")
	return d

static func save_battle(slot: int = 1, name: String = "") -> String:
	var why = can_save()
	if why != "":
		return "Not saved: " + why
	var f = FileAccess.open(slot_path(Campaign.active, slot), FileAccess.WRITE)
	if f == null:
		return "Not saved: the save file couldn't be written"
	var d = capture_battle()
	d["name"] = name.strip_edges().substr(0, 40) if name.strip_edges() != "" else default_name()
	d["when"] = Time.get_unix_time_from_system()
	f.store_var(d)
	f.close()
	var more = ""
	if G.mode == "horde" and (d["boards"].size() > 0 or d["drops"].size() > 0):
		more = ", %d boarded-up doors and windows, %d supply drops waiting" % [d["boards"].size(), d["drops"].size()]
	return "%s saved: %d men, %d vehicles, %d pieces of the map in ruins%s" % ["Campaign battle" if d.has("camp") else ("'%s' (slot %d)" % [d["name"], slot]), d["men"].size(), d["vehicles"].size(), d["ruins"].size(), more]

# the saved battle, if there is one and it can be read
static func _read_file(path: String):
	if not FileAccess.file_exists(path):
		return null
	var f = FileAccess.open(path, FileAccess.READ)
	var d = f.get_var() if f != null else null
	return d if (d is Dictionary and d.get("battle", false)) else null

# what's in a slot. (A campaign battle saved when there was only the one slot is still found there.)
static func _read_save(camp: bool = false, slot: int = 1):
	var d = _read_file(slot_path(camp, slot))
	if camp:
		if d == null:
			d = _read_file(SAVE_PATH)
		return d if d != null and d.has("camp") else null
	return d if d != null and not d.has("camp") else null

# is the saved battle the campaign battle that's waiting to be fought?
static func campaign_save_ok() -> bool:
	var d = _read_save(true)
	return d != null and Campaign.resume_check(d["camp"]) == ""

# a campaign battle that has since been fought (or settled some other way) is no longer worth keeping
static func forget_campaign_save() -> void:
	if FileAccess.file_exists(CAMP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CAMP_PATH))
	var d = _read_file(SAVE_PATH)
	if d != null and d.has("camp"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

static func has_save(camp: bool = false, slot: int = 1) -> bool:
	return _read_save(camp, slot) != null

static func save_text(camp: bool = false, slot: int = 1) -> String:
	var d = _read_save(camp, slot)
	if d == null:
		return ""
	var mins = int(float(d.get("elapsed", 0.0)) / 60.0)
	var where = G.world.MAPS.get(d["map"], {}).get("name", d["map"]) if G.world != null else str(d["map"])
	if d.has("camp"):
		if Campaign.resume_check(d["camp"]) != "":
			return ""           # (a campaign battle the campaign has left behind isn't offered)
		return "Campaign: the battle for %s, %d min in, %d men" % [Campaign.REGIONS[int(d["camp"]["region"])]["name"], mins, d["men"].size()]
	var ago = _ago(float(d.get("when", 0.0)))
	return "%s on %s, %d min in, %d men%s" % [str(d["mode"]).capitalize(), where, mins, d["men"].size(), (" · " + ago) if ago != "" else ""]

static func load_battle(from_camp: bool = false, slot: int = 1) -> String:
	var d = _read_save(from_camp, slot)
	if d == null:
		return "No saved battle"
	if d.has("hdiff"):
		G.settings["horde_diff"] = int(d["hdiff"])
	var camp = d.get("camp")
	if camp != null:
		var why = Campaign.resume_check(camp)
		if why != "":
			return "Not loaded: " + why
		Campaign.resume_begin(camp)
	else:
		Campaign.leave_battle()
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
				Soldier.zombie_next = "brute" if Modes.BOSS_SIZE.has(zk) else zk
				Soldier.size_next = float(Modes.BOSS_SIZE.get(zk, 1.0))
			var s = G.main.spawn_soldier(int(m["t"]), float(m["x"]), float(m["z"]), "pistol" if zk != "" else str(m["w"]))
			Soldier.zombie_next = ""
			Soldier.size_next = 1.0
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
			if camp != null:
				Campaign.resume_man(s, m)
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
		Modes.horde_endless = bool(d.get("endless", false))
		# what was boarded up, and any supply drop that was waiting to be fetched
		Modes.boards_restore(d.get("boards", []))
		for q in d.get("drops", []):
			Modes.make_drop(Vector3(float(q[0]), 0, float(q[1])), float(q[2]), false)
	if camp != null:
		Campaign.resume_end(camp)
	if d.has("obj"):
		var ob: Dictionary = d["obj"]
		Obj.all_t = ob["all_t"].duplicate()
		Obj.bleed_t = float(ob["bleed_t"])
		Obj.wave = int(ob["wave"])
		Obj.wave_t = float(ob["wave_t"])
		Obj.wave_left = int(ob["wave_left"])
		Obj.phase = int(ob["phase"])
		Obj.hold_t = float(ob["hold_t"])
		Obj.supply = float(ob["supply"])
		Obj.siege_t = float(ob["siege_t"])
		Obj.mode_t = float(ob["mode_t"])
		Modes.koth_t = float(ob["koth_t"])
		Modes.koth_moves = int(ob["koth_moves"])
		Modes.rescue_t = float(ob["rescue_t"])
	G.game_time = float(d.get("elapsed", 0.0))       # (the battle clock carries on from where it was)
	G.main.refresh_markers()
	return "Saved battle loaded: %d men back on the field" % d.get("men", []).size()
