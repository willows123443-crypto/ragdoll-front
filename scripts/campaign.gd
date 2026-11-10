class_name Campaign
extends RefCounted
# A turn-based campaign over twelve regions. Each side has armies on the map. On your turn you
# move each of your armies once into a neighbouring region: into an empty enemy region and it's
# yours, into one with an enemy army and there's a battle, fought on that region's map with the
# armies' real strengths. Then Bravo moves: it attacks where you're thin, pushes into gaps and
# tries to win back what it lost.
#
# Supply: a region is in supply if you can trace a line of your own regions back to your HQ.
# Armies in supply recover strength each turn and get reinforcements in battle; cut off, they
# wither and fight without reinforcements. Take the enemy's capital to win the campaign.
#
# Soldiers of the 1st Company who survive carry on and become veterans; vehicles that survive
# join the motor pool; ruins and anything built stay as they were left.

const PATH = "user://campaign.dat"
const VERSION = 2
const REGIONS = [
	{"name": "Westfield", "map": "field", "p": Vector2(0.07, 0.5), "mode": "capture", "hq": 0},
	{"name": "Old Town", "map": "town", "p": Vector2(0.24, 0.24), "mode": "capture"},
	{"name": "Pine Wood", "map": "forest", "p": Vector2(0.24, 0.76), "mode": "capture"},
	{"name": "Valley Road", "map": "valley", "p": Vector2(0.41, 0.5), "mode": "assault"},
	{"name": "The River", "map": "river", "p": Vector2(0.43, 0.15), "mode": "frontline"},
	{"name": "Mud Flats", "map": "trenches", "p": Vector2(0.43, 0.85), "mode": "breakthrough"},
	{"name": "Ridge Pass", "map": "pass", "p": Vector2(0.6, 0.33), "mode": "breakthrough"},
	{"name": "Western Front", "map": "front", "p": Vector2(0.6, 0.68), "mode": "frontline"},
	{"name": "Iron Coast", "map": "beach", "p": Vector2(0.77, 0.14), "mode": "assault"},
	{"name": "Factory Row", "map": "factory", "p": Vector2(0.77, 0.52), "mode": "capture"},
	{"name": "Great Forest", "map": "forest", "p": Vector2(0.77, 0.86), "mode": "general"},
	{"name": "The Capital", "map": "city", "p": Vector2(0.93, 0.5), "mode": "destroy", "hq": 1},
]
const LINKS = [[0, 1], [0, 2], [1, 3], [2, 3], [1, 4], [2, 5], [3, 6], [3, 7], [4, 6], [5, 7], [4, 8], [6, 8],
	[6, 9], [7, 9], [7, 10], [5, 10], [8, 11], [9, 11], [10, 11]]
const ARMY_NAMES = [["1st Company", "2nd Company", "3rd Company", "4th Company", "5th Company", "6th Company"],
	["Grenadier Btn", "Rifle Btn", "Panzer Btn", "Mountain Btn", "Guards Btn", "Reserve Btn"]]
const FIRST = ["Abe", "Bill", "Carl", "Dan", "Ed", "Frank", "Gus", "Hank", "Ike", "Jack", "Ken", "Lou", "Mack", "Ned", "Ollie", "Pete", "Ray", "Sam", "Ted", "Vic", "Walt", "Zeke"]
const LAST = ["Adams", "Baker", "Cole", "Dixon", "Evans", "Fisher", "Grant", "Hayes", "Irwin", "Jones", "Kelly", "Lane", "Moore", "Nash", "Olsen", "Price", "Reed", "Stone", "Tate", "Webb", "Young"]
const SQUAD = 10
const MAX_STR = 14
const HQ = [0, 11]

static var active = false
static var data = {}
static var current = -1          # region being fought over
static var selected = -1         # army id picked on the map

static func new_campaign() -> void:
	data = {"version": VERSION, "owner": [], "armies": [], "next_id": 0, "roster": [], "turn": 1,
		"log": ["The campaign begins. Move your armies one region a turn; cut the enemy's supply lines and take the Capital."],
		"pool": ["jeep", "jeep", "truck", "halftrack"], "sites": {}, "ruins": {}, "battle": null, "raised": [0, 0]}
	for i in range(REGIONS.size()):
		data["owner"].append(0 if REGIONS[i]["p"].x < 0.3 else 1)
	_add_army(0, 0, 10)
	_add_army(0, 1, 8)
	_add_army(0, 2, 7)
	_add_army(1, 4, 8)
	_add_army(1, 3, 9)
	_add_army(1, 7, 8)
	_add_army(1, 11, 10)
	selected = -1
	_fill_roster()
	save()

static func _add_army(team: int, region: int, strength: int) -> Dictionary:
	var n = 0
	for a in data["armies"]:
		if a["team"] == team:
			n += 1
	var names: Array = ARMY_NAMES[team]
	var a2 = {"id": data["next_id"], "team": team, "region": region, "str": strength, "moved": false, "name": names[n % names.size()] if n < names.size() else "%s %d" % [names[0], n + 1]}
	data["next_id"] += 1
	data["armies"].append(a2)
	return a2

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
	if d is Dictionary and d.get("version", 1) == VERSION and d.has("armies"):
		data = d
		return true
	return false

# ---------------------------------------------------------------- the map
static func neighbours(i: int) -> Array:
	var out = []
	for l in LINKS:
		if l[0] == i:
			out.append(l[1])
		elif l[1] == i:
			out.append(l[0])
	return out

static func linked(a: int, b: int) -> bool:
	return neighbours(a).has(b)

static func army(id: int) -> Variant:
	for a in data["armies"]:
		if a["id"] == id:
			return a
	return null

static func army_at(region: int, team: int = -1) -> Variant:
	for a in data["armies"]:
		if a["region"] == region and (team < 0 or a["team"] == team):
			return a
	return null

# regions this side can trace back to its HQ through its own ground
static func supply_net(team: int) -> Dictionary:
	var net = {}
	var hq = HQ[team]
	if data["owner"][hq] != team:
		return net
	var todo = [hq]
	net[hq] = true
	while not todo.is_empty():
		var i = todo.pop_back()
		for j in neighbours(i):
			if not net.has(j) and data["owner"][j] == team:
				net[j] = true
				todo.append(j)
	return net

static func supplied(team: int, region: int) -> bool:
	return supply_net(team).has(region)

# kept for the old one-battle-at-a-time callers (tests): a region next to ours that Bravo holds
static func adjacent(i: int) -> bool:
	for j in neighbours(i):
		if data["owner"][j] == 0:
			return true
	return false

static func can_attack(i: int) -> bool:
	return data["owner"][i] == 1 and adjacent(i)

# where the selected army may go
static func can_move(a: Dictionary, to: int) -> bool:
	if a == null or a["team"] != 0 or a["moved"] or not linked(a["region"], to):
		return false
	var mine = army_at(to, 0)
	return mine == null

# ---------------------------------------------------------------- your moves
# returns a line for the log, or "battle" if a battle has been started
static func move(a: Dictionary, to: int) -> String:
	if not can_move(a, to):
		return ""
	var from: int = a["region"]
	var r = REGIONS[to]
	a["moved"] = true
	if data["owner"][to] == 0:
		a["region"] = to
		save()
		return "%s moves to %s." % [a["name"], r["name"]]
	var foe = army_at(to, 1)
	if foe == null:
		a["region"] = to
		data["owner"][to] = 0
		var l = "%s takes %s unopposed." % [a["name"], r["name"]]
		l += _cut_note(1)
		_log([l])
		save()
		return l
	data["battle"] = {"region": to, "attacker": 0, "army": a["id"], "foe": foe["id"], "from": from}
	save()
	_start_battle()
	return "battle"

# armies of `team` that just lost supply get a note
static func _cut_note(team: int) -> String:
	var net = supply_net(team)
	var cut = []
	for a in data["armies"]:
		if a["team"] == team and not net.has(a["region"]):
			cut.append(a["name"])
	if cut.is_empty():
		return ""
	return " %s %s cut off from supply!" % [", ".join(cut), "is" if cut.size() == 1 else "are"]

# ---------------------------------------------------------------- Bravo's turn
# returns what happened; may leave a battle waiting (Bravo attacking one of your armies)
static func end_turn() -> Array:
	var lines = []
	var net1 = supply_net(1)
	var attacked_army = false
	var bravo = data["armies"].filter(func(x): return x["team"] == 1)
	# the strongest first
	bravo.sort_custom(func(x, y): return x["str"] > y["str"])
	for b in bravo:
		var best = -1
		var bs = -1e9
		var here: int = b["region"]
		for j in neighbours(here):
			var own = data["owner"][j]
			var mine = army_at(j, 1)
			var sc = -1e9
			if own == 0:
				var foe = army_at(j, 0)
				if foe == null:
					sc = 6.0 + (12.0 if j == HQ[0] else 0.0)
				elif not attacked_army:
					sc = (b["str"] - foe["str"]) * 1.2 + (2.0 if not supplied(0, j) else 0.0) + (10.0 if j == HQ[0] else 0.0)
					if b["str"] < 5:
						sc -= 8.0
				# cutting our line counts for a lot
				if sc > -1e8:
					var save_o = data["owner"][j]
					data["owner"][j] = 1
					var before = 0
					for a in data["armies"]:
						if a["team"] == 0 and not supplied(0, a["region"]):
							before += 1
					data["owner"][j] = save_o
					sc += before * 3.0
			elif mine == null:
				# move up toward the front, or fall back to recover if badly hurt
				var front = 0
				for k in neighbours(j):
					if data["owner"][k] == 0:
						front += 1
				sc = front * 1.5 - 2.0 if b["str"] >= 5 else (4.0 if net1.has(j) and front == 0 else -1.0)
			if sc > bs:
				bs = sc
				best = j
		if best < 0 or bs < 0.5:
			continue
		var r = REGIONS[best]
		if data["owner"][best] == 1:
			b["region"] = best
			continue
		var foe2 = army_at(best, 0)
		if foe2 == null:
			b["region"] = best
			data["owner"][best] = 1
			lines.append("Bravo's %s pushes into %s." % [b["name"], r["name"]] + _cut_note(0))
		else:
			attacked_army = true
			data["battle"] = {"region": best, "attacker": 1, "army": foe2["id"], "foe": b["id"], "from": here}
			lines.append("Bravo's %s attacks your %s at %s! Defend it." % [b["name"], foe2["name"], r["name"]])
	if data["battle"] == null:
		lines += _new_turn()
	_log(lines)
	save()
	return lines

# supply, recovery and fresh troops; the turn counter moves on
static func _new_turn() -> Array:
	var lines = []
	for t in range(2):
		var net = supply_net(t)
		for a in data["armies"]:
			if a["team"] != t:
				continue
			a["moved"] = false
			if net.has(a["region"]):
				a["str"] = mini(MAX_STR, a["str"] + 2)
			else:
				a["str"] -= 1
				if t == 0:
					lines.append("%s is out of supply and losing men (%d left)." % [a["name"], maxi(0, a["str"])])
		for a in data["armies"].duplicate():
			if a["str"] <= 0:
				data["armies"].erase(a)
				lines.append("%s %s has melted away." % ["Our" if t == 0 else "Bravo's", a["name"]])
		# every few turns a new army forms at a side's HQ, if it still holds it
		var n = data["armies"].filter(func(x): return x["team"] == t).size()
		data["raised"][t] += 1
		if data["owner"][HQ[t]] == t and n < 4 and data["raised"][t] >= (3 if t == 0 else 2) and army_at(HQ[t], t) == null:
			data["raised"][t] = 0
			var na = _add_army(t, HQ[t], 7)
			lines.append("%s raises a new army at %s." % ["HQ" if t == 0 else "Bravo", REGIONS[HQ[t]]["name"]] if t == 1 else "HQ raises the %s at %s." % [na["name"], REGIONS[HQ[t]]["name"]])
	data["turn"] += 1
	var ours = data["owner"].count(0)
	if data["owner"][HQ[1]] == 0:
		lines.append("The Capital has fallen to us. The campaign is won!")
	elif data["owner"][HQ[0]] == 1 or ours == 0:
		lines.append("Westfield is lost. The campaign is lost.")
	return lines

static func over() -> int:
	if data.is_empty():
		return -1
	if data["owner"][HQ[1]] == 0:
		return 0
	if data["owner"][HQ[0]] == 1:
		return 1
	return -1

static func _log(lines: Array) -> void:
	if lines.is_empty():
		return
	data["log"] = lines + data["log"]
	if data["log"].size() > 30:
		data["log"] = data["log"].slice(0, 30)

# ---------------------------------------------------------------- battles
static func pending_battle() -> Variant:
	return data.get("battle")

static func battle_text() -> String:
	var b = data.get("battle")
	if b == null:
		return ""
	var ours = army(b["army"])
	var theirs = army(b["foe"])
	var r = REGIONS[b["region"]]
	return "%s at %s: %s (%d, %s) against %s (%d, %s)" % ["Attack" if b["attacker"] == 0 else "Defence", r["name"],
		ours["name"] if ours != null else "?", ours["str"] if ours != null else 0, "in supply" if ours != null and supplied(0, ours["region"]) else "cut off",
		theirs["name"] if theirs != null else "?", theirs["str"] if theirs != null else 0, "in supply" if theirs != null and supplied(1, theirs["region"]) else "cut off"]

static func _start_battle() -> void:
	var b = data["battle"]
	var ours = army(b["army"])
	var theirs = army(b["foe"])
	var i: int = b["region"]
	var mode = REGIONS[i]["mode"] if b["attacker"] == 0 else "siege"
	var n0 = clampi(ours["str"] if ours != null else 6, 4, MAX_STR)
	var n1 = clampi(theirs["str"] if theirs != null else 6, 4, MAX_STR)
	var sup0 = ours != null and supplied(0, ours["region"] if b["attacker"] == 1 else b["from"])
	var sup1 = theirs != null and supplied(1, theirs["region"] if b["attacker"] == 0 else b["from"])
	attack(i, mode, maxi(n0, n1), [sup0, sup1], [n0, n1])

# start the battle for region i (also used directly by the tests)
static func attack(i: int, mode: String = "", size: int = SQUAD, supply: Array = [true, true], sizes: Array = []) -> void:
	active = true
	current = i
	var r = REGIONS[i]
	if mode == "":
		mode = r["mode"]
	# each side fields its army's real strength; a side out of supply gets no reinforcements
	data["no_reinf"] = [not supply[0], not supply[1]]
	G.main.start_game({"map": r["map"], "mode": mode, "size": size, "limit": G.default_limit(mode), "reinforce": true,
		"reinf_mode": "truck", "armor": "heavy" if data["turn"] > 2 else "light", "teams": 2, "caps": sizes})
	if not supply[0]:
		G.ui.radio(0, "We're cut off: no reinforcements this time")
	if not supply[1]:
		G.ui.radio(1, "We're cut off from supply")
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
		if s.team == 0 and s.state != "dead" and k < data["roster"].size():
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

# reinforcements are off for a side that's cut off
static func reinforce_ok(t: int) -> bool:
	if not active:
		return true
	var nr = data.get("no_reinf", [false, false])
	return t >= nr.size() or not nr[t]

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

# after a beaten army: back to a free friendly region next door, or it's destroyed
static func _retreat(a: Dictionary, lines: Array) -> void:
	var t: int = a["team"]
	var opts = []
	for j in neighbours(a["region"]):
		if data["owner"][j] == t and army_at(j, t) == null:
			opts.append(j)
	if opts.is_empty() or a["str"] <= 1:
		data["armies"].erase(a)
		lines.append("%s %s is destroyed." % ["Our" if t == 0 else "Bravo's", a["name"]])
		return
	# fall back toward home
	opts.sort_custom(func(x, y): return absf(REGIONS[x]["p"].x - REGIONS[HQ[t]]["p"].x) < absf(REGIONS[y]["p"].x - REGIONS[HQ[t]]["p"].x))
	a["region"] = opts[0]
	lines.append("%s %s falls back to %s." % ["Our" if t == 0 else "Bravo's", a["name"], REGIONS[opts[0]]["name"]])

static func _foot(t: int) -> int:
	var n = 0
	for s in G.soldiers:
		if s.team == t and s.state != "dead" and s.vehicle == null:
			n += 1
	return n

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
	# the armies: strength is whoever's left standing
	var b = data.get("battle")
	if b == null:
		# a one-off battle (old style): just the region changes hands
		if winner == 0:
			data["owner"][current] = 0
			lines.append("Victory at %s! The region is ours." % r["name"])
		else:
			lines.append("Defeat at %s." % r["name"])
	else:
		var ours = army(b["army"])
		var theirs = army(b["foe"])
		# what's left of each army: the men still on their feet (vehicle crews don't count), never more
		# than it brought, and the loser leaves some behind as it pulls out
		var caps = G.team_caps if G.team_caps.size() == 2 else [MAX_STR, MAX_STR]
		if ours != null:
			ours["str"] = clampi(_foot(0) - (2 if winner == 1 else 0), 1, caps[0])
		if theirs != null:
			theirs["str"] = clampi(_foot(1) - (2 if winner == 0 else 0), 0, caps[1])
		if b["attacker"] == 0:
			if winner == 0:
				data["owner"][current] = 0
				lines.append("Victory at %s! The region is ours." % r["name"])
				if theirs != null:
					_retreat(theirs, lines)
				if ours != null:
					ours["region"] = current
				lines[lines.size() - 1] += _cut_note(1)
			else:
				lines.append("Our attack on %s failed." % r["name"])
				if ours != null:
					ours["region"] = b["from"]
		else:
			if winner == 0:
				lines.append("We held %s!" % r["name"])
				if theirs != null:
					theirs["region"] = b["from"]
					if theirs["str"] <= 1:
						data["armies"].erase(theirs)
						lines.append("Bravo's %s is broken." % theirs["name"])
			else:
				data["owner"][current] = 1
				lines.append("%s has fallen to Bravo." % r["name"])
				if ours != null:
					_retreat(ours, lines)
				if theirs != null:
					theirs["region"] = current
				lines[lines.size() - 1] += _cut_note(0)
		data["battle"] = null
		# the rest of Bravo's turn: supply, recovery, new armies
		if b["attacker"] == 1:
			lines += _new_turn()
	if lost > 0:
		lines.append("%d of our soldiers fell; %d recruits join the 1st Company." % [lost, lost])
	if not promoted.is_empty():
		lines.append("Promoted: " + ", ".join(promoted))
	_log(lines)
	save()
	return "\n".join(lines)
