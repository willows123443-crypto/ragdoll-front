class_name Campaign
extends RefCounted
# A campaign across nine regions. Alpha (you) attacks regions next to ones it holds; each battle is
# fought on that region's kind of map. Soldiers who survive carry on to the next battle and become
# veterans: steadier, better shots, with stripes on their sleeves. Lose a battle and Bravo pushes back.

const PATH = "user://campaign.dat"
const REGIONS = [
	{"name": "Westfield", "map": "field", "x": 0, "y": 0, "mode": "capture"},
	{"name": "Old Town", "map": "town", "x": 0, "y": 1, "mode": "capture"},
	{"name": "Pine Wood", "map": "forest", "x": 0, "y": 2, "mode": "capture"},
	{"name": "The River", "map": "river", "x": 1, "y": 0, "mode": "frontline"},
	{"name": "Valley Road", "map": "valley", "x": 1, "y": 1, "mode": "assault"},
	{"name": "Ridge Pass", "map": "pass", "x": 1, "y": 2, "mode": "breakthrough"},
	{"name": "Iron Coast", "map": "beach", "x": 2, "y": 0, "mode": "assault"},
	{"name": "The Capital", "map": "city", "x": 2, "y": 1, "mode": "destroy"},
	{"name": "Mud Flats", "map": "trenches", "x": 2, "y": 2, "mode": "breakthrough"},
]
const FIRST = ["Abe", "Bill", "Carl", "Dan", "Ed", "Frank", "Gus", "Hank", "Ike", "Jack", "Ken", "Lou", "Mack", "Ned", "Ollie", "Pete", "Ray", "Sam", "Ted", "Vic", "Walt", "Zeke"]
const LAST = ["Adams", "Baker", "Cole", "Dixon", "Evans", "Fisher", "Grant", "Hayes", "Irwin", "Jones", "Kelly", "Lane", "Moore", "Nash", "Olsen", "Price", "Reed", "Stone", "Tate", "Webb", "Young"]
const SQUAD = 10

static var active = false
static var data = {}
static var current = -1          # region being fought over

static func new_campaign() -> void:
	data = {"owner": [], "roster": [], "turn": 1, "log": ["The campaign begins. Take the regions next to yours, one battle at a time."],
		"pool": ["jeep", "jeep", "truck", "halftrack"], "sites": {}, "ruins": {}}
	for r in REGIONS:
		data["owner"].append(0 if r["x"] == 0 else 1)
	_fill_roster()
	save()

static func _fill_roster() -> void:
	var used = {}
	for r in data["roster"]:
		used[r["name"]] = true
	while data["roster"].size() < SQUAD:
		var n = "%s %s" % [FIRST[randi() % FIRST.size()], LAST[randi() % LAST.size()]]
		if used.has(n):
			continue
		used[n] = true
		data["roster"].append({"name": n, "vet": 0, "kills": 0, "battles": 0})

static func save() -> void:
	var f = FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_var(data)

static func load_saved() -> bool:
	if not FileAccess.file_exists(PATH):
		return false
	var f = FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return false
	var d = f.get_var()
	if d is Dictionary and d.has("owner"):
		data = d
		return true
	return false

static func adjacent(i: int) -> bool:
	var r = REGIONS[i]
	for j in range(REGIONS.size()):
		if data["owner"][j] == 0:
			var o = REGIONS[j]
			if absi(o["x"] - r["x"]) + absi(o["y"] - r["y"]) == 1:
				return true
	return false

static func can_attack(i: int) -> bool:
	return data["owner"][i] == 1 and adjacent(i)

static func attack(i: int) -> void:
	active = true
	current = i
	var r = REGIONS[i]
	G.main.start_game({"map": r["map"], "mode": r["mode"], "size": SQUAD, "limit": 100, "reinforce": true,
		"reinf_mode": "truck", "armor": "heavy" if data["turn"] > 2 else "light", "teams": 2})
	# our motor pool: whatever survived the last battles
	if not data.has("pool"):
		data["pool"] = ["jeep", "jeep", "truck", "halftrack"]
	var home: Vector3 = G.world.rally_point(0)
	var face = atan2(G.world.capture.x - home.x, G.world.capture.z - home.z)
	var side = Vector3(cos(face), 0, -sin(face))
	var k0 = 0
	for kind in data["pool"]:
		var vp = G.main._free_spot(home + side * ((k0 % 4) - 1.5) * 7.0 - Vector3(sin(face), 0, cos(face)) * (8.0 + int(k0 / 4) * 9.0))
		G.main.spawn_vehicle(kind, 0, vp, face)
		k0 += 1
	# defences and bases either side built here in earlier battles are still standing
	var kept = 0
	for sd in data.get("sites", {}).get(i, []):
		var front = Vector3(0, 0, sd["fs"]) if sd["ax"] else Vector3(sd["fs"], 0, 0)
		if Build.place(sd["kind"], sd["team"], sd["p"], front, true) != null:
			kept += 1
	# our soldiers are the campaign roster, veterans and all
	var k = 0
	for s in G.soldiers:
		if s.team == 0 and k < data["roster"].size():
			var e = data["roster"][k]
			s.sname = e["name"]
			s.set_vet(e["vet"])
			s.set_meta("roster", k)
			k += 1
	var note = ""
	if G.world.ruined_at_start > 0:
		note += " · %d pieces still in ruins" % G.world.ruined_at_start
	if kept > 0:
		note += " · %d structures still standing" % kept
	G.ui.message("Battle for %s · %d vehicles in our motor pool%s" % [r["name"], data["pool"].size(), note])

# which of a region's map pieces were destroyed in earlier battles there
static func ruins(i: int) -> Array:
	var all = data.get("ruins", {})
	return all.get(i, [])

static func _record_ruins(i: int) -> int:
	var W = G.world
	if not data.has("ruins"):
		data["ruins"] = {}
	var had: Array = data["ruins"].get(i, [])
	var set_ = {}
	for k in had:
		set_[k] = true
	var added = 0
	for k in range(W.static_cols.size()):
		var c = W.static_cols[k]
		if not c.alive and c.dest and not set_.has(k):
			set_[k] = true
			added += 1
	var out = set_.keys()
	out.sort()
	data["ruins"][i] = out
	return added

static func battle_over(winner: int) -> String:
	if not active or current < 0:
		return ""
	active = false
	var r = REGIONS[current]
	var lines = []
	var wrecked = _record_ruins(current)
	if wrecked > 0:
		lines.append("%d more pieces of %s lie in ruins (they stay that way)." % [wrecked, r["name"]])
	# vehicles that made it come along to the next battle; HQ sends one more
	var pool = []
	for v in G.vehicles:
		if is_instance_valid(v) and not v.dead and v.team == 0 and not v.spec.get("air", false) and not v.spec.get("static", false) and v.kind in ["jeep", "truck", "halftrack", "armoredcar", "tank", "motorbike", "ambulance", "radar", "bridger"]:
			pool.append(v.kind)
	var lost_v = maxi(0, data.get("pool", []).size() - pool.size())
	var fresh = "tank" if winner == 0 and data["turn"] % 2 == 0 else ("armoredcar" if winner == 0 else "jeep")
	pool.append(fresh)
	if pool.size() > 8:
		pool = pool.slice(0, 8)
	data["pool"] = pool
	lines.append("Motor pool: %d vehicles (%s joins)%s." % [pool.size(), fresh, (", %d lost" % lost_v) if lost_v > 0 else ""])
	# what's built here stays built
	var keep_sites = []
	for st in Build.sites:
		if st["done"] and not st["dead"] and st["kind"] != "hq":
			keep_sites.append({"kind": st["kind"], "team": st["team"], "p": st["p"], "ax": st["ax"], "fs": st["fs"]})
	if not data.has("sites"):
		data["sites"] = {}
	data["sites"][current] = keep_sites.slice(0, 40)
	if not keep_sites.is_empty():
		lines.append("%d structures left standing at %s." % [mini(keep_sites.size(), 40), r["name"]])
	# survivors carry on; the fallen are struck from the roster
	var alive_names = {}
	var kills = {}
	for s in G.soldiers:
		if s.team == 0:
			if s.state != "dead":
				alive_names[s.sname] = true
			kills[s.sname] = s.kills
	var keep = []
	var promoted = []
	for e in data["roster"]:
		if alive_names.has(e["name"]):
			e["battles"] += 1
			var k = kills.get(e["name"], 0)
			e["kills"] += k
			if e["vet"] < 3 and (k >= 2 or e["battles"] % 2 == 0):
				e["vet"] += 1
				promoted.append(e["name"])
			keep.append(e)
	var lost = data["roster"].size() - keep.size()
	data["roster"] = keep
	_fill_roster()
	if winner == 0:
		data["owner"][current] = 0
		lines.append("Victory at %s! The region is ours." % r["name"])
	else:
		lines.append("Defeat at %s." % r["name"])
		# Bravo pushes back into one of our regions on the line
		for j in range(REGIONS.size()):
			if data["owner"][j] == 0 and _touches_enemy(j) and REGIONS[j]["x"] > 0:
				data["owner"][j] = 1
				lines.append("Bravo counter-attacks and takes %s." % REGIONS[j]["name"])
				break
	if lost > 0:
		lines.append("%d of our soldiers fell; %d recruits join the squad." % [lost, lost])
	if not promoted.is_empty():
		lines.append("Promoted: " + ", ".join(promoted))
	data["turn"] += 1
	var ours = data["owner"].count(0)
	if ours == REGIONS.size():
		lines.append("Every region is ours. The campaign is won!")
	elif ours == 0:
		lines.append("We've been driven from the map. The campaign is lost.")
	data["log"] = lines + data["log"]
	if data["log"].size() > 30:
		data["log"] = data["log"].slice(0, 30)
	save()
	return "\n".join(lines)

static func _touches_enemy(i: int) -> bool:
	var r = REGIONS[i]
	for j in range(REGIONS.size()):
		if data["owner"][j] == 1:
			var o = REGIONS[j]
			if absi(o["x"] - r["x"]) + absi(o["y"] - r["y"]) == 1:
				return true
	return false
