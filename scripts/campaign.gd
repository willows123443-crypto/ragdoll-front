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
const VERSION = 3
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
const MAX_STR = 40         # men in one army
const MAX_VEH = 4
const HQ = [0, 11]
# what an army is made up of when it's raised: a mix of the classes
const MIX = ["rifleman", "rifleman", "mg", "rifleman", "at", "medic", "rifleman", "engineer", "rifleman", "mg", "rifleman", "radio", "at", "rifleman", "sniper", "spotter"]
# what you can buy for an army in supply, from the war chest
const PACKS = {
	"rifle": {"name": "Rifle squad", "cost": 10, "cls": ["rifleman", "rifleman", "rifleman", "rifleman", "mg", "at", "medic", "rifleman"]},
	"mg": {"name": "MG team", "cost": 7, "cls": ["mg", "mg", "rifleman"]},
	"at": {"name": "Anti-tank team", "cost": 8, "cls": ["at", "at", "rifleman"]},
	"eng": {"name": "Engineers", "cost": 7, "cls": ["engineer", "engineer", "engineer"]},
	"med": {"name": "Medics", "cost": 4, "cls": ["medic", "medic"]},
	"snp": {"name": "Sniper team", "cost": 6, "cls": ["sniper", "spotter"]},
	"rad": {"name": "Radio operator", "cost": 4, "cls": ["radio"]},
	"jeep": {"name": "Jeep", "cost": 6, "veh": "jeep"},
	"halftrack": {"name": "Half-track", "cost": 11, "veh": "halftrack"},
	"armoredcar": {"name": "Armoured car", "cost": 15, "veh": "armoredcar"},
	"tank": {"name": "Tank", "cost": 22, "veh": "tank"},
}
const RAISE_COST = 25
const CLS_NAMES = {"rifleman": "Riflemen", "mg": "Machine gunners", "at": "Anti-tank", "medic": "Medics", "engineer": "Engineers",
	"assault": "Assault", "radio": "Radio operators", "sniper": "Snipers", "spotter": "Spotters", "officer": "Officers"}

static var active = false
static var data = {}
static var current = -1          # region being fought over
static var selected = -1         # army id picked on the map

static func new_campaign() -> void:
	data = {"version": VERSION, "owner": [], "armies": [], "next_id": 0, "roster": [], "turn": 1, "funds": [24, 24],
		"log": ["The campaign begins. Move your armies one region a turn, recruit with the war chest, cut the enemy's supply lines and take the Capital."],
		"pool": [], "sites": {}, "ruins": {}, "battle": null, "raised": [0, 0]}
	for i in range(REGIONS.size()):
		data["owner"].append(0 if REGIONS[i]["p"].x < 0.3 else 1)
	var a0 = _add_army(0, 0, 12)
	a0["veh"] = ["jeep", "halftrack"]
	var a1 = _add_army(0, 1, 10)
	a1["veh"] = ["jeep"]
	_add_army(0, 2, 8)
	_add_army(1, 4, 10)
	var b1 = _add_army(1, 3, 11)
	b1["veh"] = ["jeep"]
	_add_army(1, 7, 10)
	var b3 = _add_army(1, 11, 12)
	b3["veh"] = ["armoredcar"]
	selected = -1
	save()

static func _add_army(team: int, region: int, strength: int) -> Dictionary:
	var n = 0
	for a in data["armies"]:
		if a["team"] == team:
			n += 1
	var names: Array = ARMY_NAMES[team]
	var a2 = {"id": data["next_id"], "team": team, "region": region, "str": 0, "moved": false, "men": [], "veh": [],
		"name": names[n % names.size()] if n < names.size() else "%s %d" % [names[0], n + 1]}
	data["next_id"] += 1
	data["armies"].append(a2)
	var cls = []
	for k in range(strength):
		cls.append(MIX[k % MIX.size()])
	add_men(a2, cls)
	return a2

# new men join an army: each gets a name of his own
static func add_men(a: Dictionary, cls: Array) -> void:
	var used = {}
	for m in a["men"]:
		used[m["name"]] = true
	for c in cls:
		if a["men"].size() >= MAX_STR:
			break
		var n = ""
		for k in range(20):
			n = "%s %s" % [FIRST[randi() % FIRST.size()], LAST[randi() % LAST.size()]]
			if not used.has(n):
				break
		used[n] = true
		a["men"].append({"name": n, "cls": c, "vet": 0, "kills": 0, "battles": 0})
	_sync(a)

static func _sync(a: Dictionary) -> void:
	if not a.has("men"):
		a["men"] = []
	if not a.has("veh"):
		a["veh"] = []
	a["str"] = a["men"].size()

# how many of each class an army has, for the screen
static func make_up(a: Dictionary) -> Dictionary:
	var out = {}
	for m in a["men"]:
		out[m["cls"]] = out.get(m["cls"], 0) + 1
	return out

# ---------------------------------------------------------------- recruiting
static func can_buy(a: Dictionary, pack: String) -> String:
	if a == null:
		return "pick an army first"
	var P = PACKS[pack]
	if data["funds"][a["team"]] < P["cost"]:
		return "not enough in the war chest"
	if not supplied(a["team"], a["region"]):
		return "cut off: no recruits can reach it"
	if P.has("veh"):
		if a["veh"].size() >= MAX_VEH:
			return "no room for more vehicles"
	elif a["men"].size() + P["cls"].size() > MAX_STR:
		return "the army is at full strength"
	return ""

static func buy(a: Dictionary, pack: String) -> String:
	var why = can_buy(a, pack)
	if why != "":
		return why
	var P = PACKS[pack]
	data["funds"][a["team"]] -= P["cost"]
	if P.has("veh"):
		a["veh"].append(P["veh"])
	else:
		add_men(a, P["cls"])
	save()
	return ""

static func can_raise(team: int) -> String:
	if data["funds"][team] < RAISE_COST:
		return "needs %d in the war chest" % RAISE_COST
	if data["owner"][HQ[team]] != team:
		return "we've lost our HQ"
	if army_at(HQ[team], team) != null:
		return "an army is already at HQ: move it out first"
	if data["armies"].filter(func(x): return x["team"] == team).size() >= 6:
		return "six armies is the most we can keep"
	return ""

static func raise_army(team: int) -> String:
	var why = can_raise(team)
	if why != "":
		return why
	data["funds"][team] -= RAISE_COST
	var a = _add_army(team, HQ[team], 8)
	a["moved"] = true
	_log(["HQ raises the %s at %s." % [a["name"], REGIONS[HQ[team]]["name"]]] if team == 0 else [])
	save()
	return ""

# income each turn: a little from HQ and more for every region held in supply
static func income(team: int) -> int:
	var net = supply_net(team)
	return 4 + net.size()

static func save() -> void:
	var f = FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_var(data)

# armies from an older save get men and vehicles
static func _upgrade() -> void:
	for a in data["armies"]:
		if not a.has("men"):
			a["men"] = []
			a["veh"] = []
			var cls = []
			for k in range(a.get("str", 8)):
				cls.append(MIX[k % MIX.size()])
			add_men(a, cls)
	if not data.has("funds"):
		data["funds"] = [20, 20]

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
	# after attacking, Bravo spends a turn regrouping before it attacks one of your armies again
	var attacked_army = data.get("bravo_rest", false)
	data["bravo_rest"] = false
	var grabs = 0          # Bravo takes at most one undefended region a turn
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
					sc = (6.0 + (12.0 if j == HQ[0] else 0.0)) if grabs == 0 else -1e9
				elif not attacked_army:
					# only attacks it clearly outnumbers: defenders are dug in
					sc = (b["str"] - foe["str"] * 1.3) * 1.2 + (2.0 if not supplied(0, j) else 0.0) + (10.0 if j == HQ[0] else 0.0)
					if b["str"] < 5 or b["str"] < foe["str"] * 1.15:
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
			grabs += 1
			b["region"] = best
			data["owner"][best] = 1
			lines.append("Bravo's %s pushes into %s." % [b["name"], r["name"]] + _cut_note(0))
		else:
			attacked_army = true
			data["bravo_rest"] = true
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
			_sync(a)
			if net.has(a["region"]):
				if a["men"].size() < 10:
					add_men(a, ["rifleman"])        # stragglers and the walking wounded come back
			else:
				if not a["men"].is_empty():
					a["men"].pop_back()
				_sync(a)
				if t == 0:
					lines.append("%s is out of supply and losing men (%d left)." % [a["name"], maxi(0, a["str"])])
		for a in data["armies"].duplicate():
			if a["str"] <= 0:
				data["armies"].erase(a)
				lines.append("%s %s has melted away." % ["Our" if t == 0 else "Bravo's", a["name"]])
		# the war chest fills; Bravo spends its on the armies that need it most
		var inc = income(t)
		data["funds"][t] += inc
		if t == 0:
			lines.append("The war chest grows by %d (now %d)." % [inc, data["funds"][0]])
		else:
			_bravo_spends(lines)
	_event(lines)
	data["turn"] += 1
	var ours = data["owner"].count(0)
	if data["owner"][HQ[1]] == 0:
		lines.append("The Capital has fallen to us. The campaign is won!")
	elif data["owner"][HQ[0]] == 1 or ours == 0:
		lines.append("Westfield is lost. The campaign is lost.")
	return lines

# most turns something happens: the weather turns, partisans rise behind Bravo's lines, a patrol
# finds an enemy dump, or one of our convoys is ambushed
static func _event(lines: Array) -> void:
	data["weather"] = "clear"
	data["event"] = ""
	var r = randf()
	if r < 0.2:
		data["weather"] = "storm"
		data["event"] = "storm"
		lines.append("Storm front: rain and low cloud. No aircraft can fly in this turn's battles.")
	elif r < 0.38:
		var cands = []
		for j in range(REGIONS.size()):
			if data["owner"][j] != 1 or j == HQ[1]:
				continue
			for k in neighbours(j):
				if data["owner"][k] == 0:
					cands.append(j)
					break
		if cands.is_empty():
			return
		var j: int = cands[randi() % cands.size()]
		var foe = army_at(j, 1)
		data["event"] = "partisans"
		if foe != null and foe["men"].size() > 3:
			var n = mini(randi_range(2, 4), foe["men"].size() - 2)
			for k in range(n):
				foe["men"].pop_back()
			_sync(foe)
			lines.append("Partisans ambush Bravo's %s at %s: %d of their men lost." % [foe["name"], REGIONS[j]["name"], n])
		elif foe == null:
			data["owner"][j] = 0
			lines.append("Partisans rise at %s and hand it over to us." % REGIONS[j]["name"] + _cut_note(1))
	elif r < 0.53:
		var n2 = randi_range(10, 22)
		data["funds"][0] += n2
		data["event"] = "supplies"
		lines.append("A patrol captures an enemy supply dump: +%d to the war chest." % n2)
	elif r < 0.63 and data["funds"][0] > 6:
		var n3 = mini(data["funds"][0], randi_range(6, 12))
		data["funds"][0] -= n3
		data["event"] = "ambush"
		lines.append("One of our supply convoys was ambushed on the road: -%d from the war chest." % n3)

static func _bravo_spends(lines: Array) -> void:
	var mine = data["armies"].filter(func(x): return x["team"] == 1)
	if mine.size() < 4 and can_raise(1) == "" and randf() < 0.6:
		raise_army(1)
		lines.append("Bravo raises a new army at %s." % REGIONS[HQ[1]]["name"])
		return
	mine.sort_custom(func(x, y): return x["str"] < y["str"])
	# one purchase a turn, for the weakest army that can take it
	for a in mine:
		for pk in (["rifle", "at", "mg"] if a["str"] < 18 else ["tank", "halftrack", "rifle", "snp"]):
			if can_buy(a, pk) == "":
				buy(a, pk)
				return

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
	if ours != null:
		_sync(ours)
	if theirs != null:
		_sync(theirs)
	var n0 = clampi(ours["str"] if ours != null else 6, 4, MAX_STR)
	var n1 = clampi(theirs["str"] if theirs != null else 6, 4, MAX_STR)
	var sup0 = ours != null and supplied(0, ours["region"] if b["attacker"] == 1 else b["from"])
	var sup1 = theirs != null and supplied(1, theirs["region"] if b["attacker"] == 0 else b["from"])
	var cls0 = ours["men"].map(func(m): return m["cls"]) if ours != null else []
	var cls1 = theirs["men"].map(func(m): return m["cls"]) if theirs != null else []
	attack(i, mode, maxi(n0, n1), [sup0, sup1], [n0, n1], [cls0, cls1], [ours["veh"] if ours != null else [], theirs["veh"] if theirs != null else []])

# start the battle for region i (also used directly by the tests)
static func attack(i: int, mode: String = "", size: int = SQUAD, supply: Array = [true, true], sizes: Array = [], cls: Array = [], vehs: Array = []) -> void:
	active = true
	current = i
	var r = REGIONS[i]
	if mode == "":
		mode = r["mode"]
	# each side fields its army's real strength; a side out of supply gets no reinforcements
	data["no_reinf"] = [not supply[0], not supply[1]]
	G.main.start_game({"map": r["map"], "mode": mode, "size": size, "limit": G.default_limit(mode), "reinforce": true,
		"reinf_mode": "truck", "armor": "heavy" if data["turn"] > 2 else "light", "teams": 2, "caps": sizes, "cls": cls, "armies_veh": true})
	if not supply[0]:
		G.ui.radio(0, "We're cut off: no reinforcements this time")
	if not supply[1]:
		G.ui.radio(1, "We're cut off from supply")
	# each army brings its own vehicles
	var nveh = 0
	for t in range(2):
		var list: Array = vehs[t] if vehs.size() > t else []
		var home: Vector3 = G.world.rally_point(t)
		var face = atan2(G.world.capture.x - home.x, G.world.capture.z - home.z)
		var side = Vector3(cos(face), 0, -sin(face))
		var k0 = 0
		for kind in list:
			var vp = G.main._free_spot(home + side * ((k0 % 4) - 1.5) * 7.0 - Vector3(sin(face), 0, cos(face)) * (8.0 + int(k0 / 4) * 9.0))
			G.main.spawn_vehicle(Faction.vehicle_kind(t, kind), t, vp, face)
			k0 += 1
		if t == 0:
			nveh = k0
	# defences and bases either side built here in earlier battles are still standing
	var kept = 0
	for sd in data.get("sites", {}).get(i, []):
		var front = Vector3(0, 0, sd["fs"]) if sd["ax"] else Vector3(sd["fs"], 0, 0)
		if Build.place(sd["kind"], sd["team"], sd["p"], front, true) != null:
			kept += 1
	# our soldiers are the army's own men, by name, veterans and all
	var b = data.get("battle")
	var ours = army(b["army"]) if b != null else null
	var men: Array = ours["men"] if ours != null else []
	var taken = {}
	for s in G.soldiers:
		if s.team != 0 or s.state == "dead" or s.vehicle != null:
			continue
		for k in range(men.size()):
			if not taken.has(k) and men[k]["cls"] == s.cls:
				taken[k] = true
				s.sname = men[k]["name"]
				s.set_vet(men[k]["vet"])
				s.set_meta("roster", k)
				break
	var note = ""
	if G.world.ruined_at_start > 0:
		note += " · %d pieces still in ruins" % G.world.ruined_at_start
	if kept > 0:
		note += " · %d structures still standing" % kept
	if data.get("weather", "") == "storm":
		G.storm = true
		Weather.apply()
		G.main.apply_time()
		note += " · storm: no aircraft"
	# defending: our men have had time to dig in (sandbags and an MG nest already up), and a longer prep
	if b != null and b.get("attacker", 0) == 1:
		var home: Vector3 = G.world.rally_point(0)
		var fw = G.flat(G.world.capture - home).normalized()
		var sd = Vector3(fw.z, 0, -fw.x)
		var made = 0
		for item in [["mgnest", 0.0, 14.0], ["sandbags", -7.0, 11.0], ["sandbags", 7.0, 11.0], ["sandbags", 0.0, 18.0]]:
			var spot = Build.find_spot(home + sd * item[1] + fw * item[2], item[0], 5.0, 10, true)
			if spot != null and Build.place(item[0], 0, spot, fw, true) != null:
				made += 1
		if made > 0:
			note += " · dug in"
	G.ui.message("Battle for %s · %d of our vehicles%s" % [r["name"], nveh, note])
	Prep.start(90.0 if b != null and b.get("attacker", 0) == 1 else Prep.SECS)

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

# after a battle: who's left of an army
static func _survivors(a: Dictionary, lost_it: bool) -> Array:
	var lines = []
	var t: int = a["team"]
	var before: int = a["men"].size()
	var keep = []
	var promoted = []
	var named = {}
	var extra = []
	for s in G.soldiers:
		if s.team != t or s.zombie:
			continue
		var alive = s.state != "dead"
		if t == 0 and s.has_meta("roster"):
			var k: int = s.get_meta("roster")
			if k < a["men"].size():
				named[k] = [alive, s.kills]
		elif alive and s.vehicle == null:
			extra.append(s.cls)
	if t == 0:
		for k in range(a["men"].size()):
			var m = a["men"][k]
			var r = named.get(k, [true, 0])     # men who never made it onto the field are safe
			if not r[0]:
				continue
			m["battles"] += 1
			m["kills"] += r[1]
			if m["vet"] < 3 and (r[1] >= 2 or m["battles"] % 2 == 0):
				m["vet"] += 1
				promoted.append(m["name"])
			keep.append(m)
		a["men"] = keep
	else:
		# Bravo's army: what classes are still standing (named or not)
		a["men"] = []
		for c in extra:
			a["men"].append({"name": "", "cls": c, "vet": 0, "kills": 0, "battles": 1})
	# reinforcements who made it fill the ranks back up, never past what the army brought
	if t == 0:
		var fill = []
		for c in extra:
			if a["men"].size() + fill.size() < before:
				fill.append(c)
		add_men(a, fill)
	# the side that lost leaves a couple of men behind as it pulls out
	if lost_it:
		for k in range(mini(2, a["men"].size() - 1)):
			a["men"].pop_back()
	var veh = []
	for v in G.vehicles:
		if is_instance_valid(v) and not v.dead and v.team == t and not v.spec.get("air", false) and not v.spec.get("static", false) \
				and v.kind in ["jeep", "technical", "halftrack", "armoredcar", "tank", "heavytank", "motorbike"] and veh.size() < MAX_VEH:
			veh.append(v.kind)
	var lost_v = maxi(0, a["veh"].size() - veh.size())
	a["veh"] = veh
	_sync(a)
	if t == 0:
		var fell = before - a["men"].size()
		lines.append("%s: %d men left%s%s." % [a["name"], a["men"].size(), (" (%d fell)" % fell) if fell > 0 else "", (", %d vehicles lost" % lost_v) if lost_v > 0 else ""])
		if not promoted.is_empty():
			lines.append("Promoted: " + ", ".join(promoted.slice(0, 6)) + ("…" if promoted.size() > 6 else ""))
	return lines

static func battle_over(winner: int) -> String:
	if not active or current < 0:
		return ""
	active = false
	var r = REGIONS[current]
	var lines = []
	var wrecked = _record_ruins(current)
	if wrecked > 0:
		lines.append("%d more pieces of %s lie in ruins (they stay that way)." % [wrecked, r["name"]])
	# what's built here stays built
	var keep_sites = []
	for st in Build.sites:
		if st["done"] and not st["dead"] and st["kind"] != "hq":
			keep_sites.append({"kind": st["kind"], "team": st["team"], "p": st["p"], "ax": st["ax"], "fs": st["fs"]})
	if not data.has("sites"):
		data["sites"] = {}
	data["sites"][current] = keep_sites.slice(0, 40)
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
		# what's left of each army: its men still on their feet (named, with their kills and promotions),
		# reinforcements who survived filling the gaps up to what it brought, and the vehicles that came through
		if ours != null:
			lines += _survivors(ours, winner != 0)
		if theirs != null:
			_survivors(theirs, winner != 1)
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
	_log(lines)
	save()
	return "\n".join(lines)
