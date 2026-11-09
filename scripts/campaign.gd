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
	data = {"owner": [], "roster": [], "turn": 1, "log": ["The campaign begins. Take the regions next to yours, one battle at a time."]}
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
	# our soldiers are the campaign roster, veterans and all
	var k = 0
	for s in G.soldiers:
		if s.team == 0 and k < data["roster"].size():
			var e = data["roster"][k]
			s.sname = e["name"]
			s.set_vet(e["vet"])
			s.set_meta("roster", k)
			k += 1
	if G.world.ruined_at_start > 0:
		G.ui.message("Battle for %s · the scars of earlier fighting remain (%d pieces in ruins)" % [r["name"], G.world.ruined_at_start])
	else:
		G.ui.message("Battle for %s" % r["name"])

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
