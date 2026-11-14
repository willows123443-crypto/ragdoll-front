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
const VERSION = 4
const REGIONS = [
	{"name": "Westfield", "map": "field", "p": Vector2(0.07, 0.5), "mode": "capture", "hq": 0},
	{"name": "Old Town", "map": "town", "p": Vector2(0.24, 0.24), "mode": "capture", "bonus": "recruits"},
	{"name": "Pine Wood", "map": "forest", "p": Vector2(0.24, 0.76), "mode": "capture", "bonus": "sawmill"},
	{"name": "Valley Road", "map": "valley", "p": Vector2(0.41, 0.5), "mode": "assault", "bonus": "roads"},
	{"name": "The River", "map": "river", "p": Vector2(0.43, 0.15), "mode": "frontline", "bonus": "hospital"},
	{"name": "Mud Flats", "map": "trenches", "p": Vector2(0.43, 0.85), "mode": "breakthrough", "bonus": "training"},
	{"name": "Ridge Pass", "map": "pass", "p": Vector2(0.6, 0.33), "mode": "breakthrough", "bonus": "guns"},
	{"name": "Western Front", "map": "front", "p": Vector2(0.6, 0.68), "mode": "frontline", "bonus": "depot"},
	{"name": "Iron Coast", "map": "beach", "p": Vector2(0.77, 0.14), "mode": "assault", "bonus": "harbour"},
	{"name": "Factory Row", "map": "factory", "p": Vector2(0.77, 0.52), "mode": "capture", "bonus": "factory"},
	{"name": "Great Forest", "map": "forest", "p": Vector2(0.77, 0.86), "mode": "general", "bonus": "hunters"},
	{"name": "The Capital", "map": "city", "p": Vector2(0.93, 0.5), "mode": "destroy", "hq": 1},
]
const LINKS = [[0, 1], [0, 2], [1, 3], [2, 3], [1, 4], [2, 5], [3, 6], [3, 7], [4, 6], [5, 7], [4, 8], [6, 8],
	[6, 9], [7, 9], [7, 10], [5, 10], [8, 11], [9, 11], [10, 11]]
# The six-region campaign: the same country with the middle taken out.
const SHORT_REGIONS = [0, 1, 2, 3, 9, 11]
const SHORT_LINKS = [[0, 1], [0, 2], [1, 3], [2, 3], [1, 9], [3, 9], [3, 11], [9, 11]]
# What holding a region (in supply) is worth. Either side gets it.
const BONUS = {
	"recruits": ["Recruiting office", "infantry costs 2 less"],
	"sawmill": ["Sawmills", "+2 to the war chest each turn"],
	"roads": ["Crossroads", "+3 to the war chest each turn"],
	"hospital": ["Field hospital", "armies in supply get two men back a turn, up to 16"],
	"training": ["Training ground", "recruits arrive with a stripe already"],
	"guns": ["Artillery park", "+20 support points at the start of every battle"],
	"depot": ["Supply depot", "+3 to the war chest each turn"],
	"harbour": ["Harbour", "+4 to the war chest each turn"],
	"factory": ["Factories", "vehicles cost a third less"],
	"hunters": ["Hunters' lodges", "sniper teams and radio operators at half price"],
}
const BONUS_INCOME = {"sawmill": 2, "roads": 3, "depot": 3, "harbour": 4}
const RANKS = ["Private", "Corporal", "Sergeant", "Staff Sergeant"]
const RANK_S = ["Pte", "Cpl", "Sgt", "S/Sgt"]
# a sergeant picks up one of these (it shows in the roster, and he fights that way)
const PERKS = {"marksman": "Marksman: shoots straighter", "tough": "Tough: takes more to put down", "steady": "Steady: keeps his nerve under fire", "scrounger": "Scrounger: carries a spare grenade and smoke"}
# something extra to try for in a battle you fight yourself
const OBJ = {
	"swift": ["Swift victory", "win inside eight minutes", "+10 to the war chest"],
	"light": ["Light losses", "lose no more than a third of the men you bring", "two more promotions"],
	"armour": ["Tank hunters", "knock out every enemy vehicle", "a captured vehicle joins the army"],
	"spare": ["Spare the place", "fewer than 20 more pieces of it wrecked", "+8 to the war chest"],
	"keep": ["Bring them home", "lose none of your vehicles", "+6 to the war chest"],
}
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

const CLS_ONE = {"rifleman": "rifleman", "mg": "machine gunner", "at": "anti-tank", "medic": "medic", "engineer": "engineer",
	"assault": "assault", "radio": "radio operator", "sniper": "sniper", "spotter": "spotter", "officer": "officer"}

static var active = false
static var data = {}
static var current = -1          # region being fought over
static var selected = -1         # army id picked on the map

static func new_campaign(short: bool = false) -> void:
	data = {"version": VERSION, "owner": [], "armies": [], "next_id": 0, "roster": [], "turn": 1, "funds": [24, 24],
		"log": ["The campaign begins. Move your armies one region a turn, recruit with the war chest, cut the enemy's supply lines and take the Capital. Up to three companies can share a region: each has to be beaten before the ground changes hands."],
		"pool": [], "sites": {}, "ruins": {}, "battle": null, "raised": [0, 0], "short": short, "links": SHORT_LINKS if short else LINKS,
		"fallen": [], "plan": [], "choice": null, "pending_ev": null,
		"headline": {"head": "WAR!", "sub": "The army marches east. The Capital is %s regions away." % ("three" if short else "five"), "turn": 1}}
	for i in range(REGIONS.size()):
		var in_play = not short or i in SHORT_REGIONS
		data["owner"].append(-1 if not in_play else (0 if REGIONS[i]["p"].x < 0.3 else 1))
	var a0 = _add_army(0, 0, 12)
	a0["veh"] = ["jeep", "halftrack"]
	var a1 = _add_army(0, 1, 10)
	a1["veh"] = ["jeep"]
	_add_army(0, 2, 8)
	if short:
		var s1 = _add_army(1, 3, 11)
		s1["veh"] = ["jeep"]
		_add_army(1, 9, 10)
	else:
		_add_army(1, 4, 10)
		var b1 = _add_army(1, 3, 11)
		b1["veh"] = ["jeep"]
		_add_army(1, 7, 10)
	var b3 = _add_army(1, 11, 12)
	b3["veh"] = ["armoredcar"]
	selected = -1
	data["plan"] = _bravo_plan()
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
static func add_men(a: Dictionary, cls: Array, vet0: int = 0) -> void:
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
		a["men"].append({"name": n, "cls": c, "vet": vet0, "kills": 0, "battles": 0})
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
	if data["funds"][a["team"]] < cost(a["team"], pack):
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
	data["funds"][a["team"]] -= cost(a["team"], pack)
	if P.has("veh"):
		a["veh"].append(P["veh"])
	else:
		add_men(a, P["cls"], 1 if has_bonus(a["team"], "training") else 0)
	save()
	return ""

static func can_raise(team: int) -> String:
	if data["funds"][team] < RAISE_COST:
		return "needs %d in the war chest" % RAISE_COST
	if data["owner"][HQ[team]] != team:
		return "we've lost our HQ"
	if not room_at(HQ[team], team):
		return "HQ is full (%d companies): move one out first" % STACK
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
	var n = 4 + net.size()
	for i in net:
		n += int(BONUS_INCOME.get(REGIONS[i].get("bonus", ""), 0))
	return n

# does this side hold (and supply) a region with this bonus?
static func has_bonus(team: int, key: String) -> bool:
	for i in supply_net(team):
		if REGIONS[i].get("bonus", "") == key:
			return true
	return false

static func bonus_text(i: int) -> String:
	var k: String = REGIONS[i].get("bonus", "")
	return ("%s: %s" % [BONUS[k][0], BONUS[k][1]]) if BONUS.has(k) else ""

# what a pack costs this side just now
static func cost(team: int, pack: String) -> int:
	var P = PACKS[pack]
	var c: int = P["cost"]
	if P.has("veh"):
		if has_bonus(team, "factory"):
			c = int(ceil(c * 2.0 / 3.0))
	elif pack in ["snp", "rad"] and has_bonus(team, "hunters"):
		c = int(ceil(c * 0.5))
	elif has_bonus(team, "recruits"):
		c = maxi(2, c - 2)
	return c

static func links() -> Array:
	return data.get("links", LINKS)

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
	# a campaign begun before the rework carries on, with what's new switched on
	for k in [["short", false], ["links", LINKS], ["fallen", []], ["plan", []], ["choice", null], ["pending_ev", null],
			["headline", {"head": "THE WAR GOES ON", "sub": "", "turn": data.get("turn", 1)}]]:
		if not data.has(k[0]):
			data[k[0]] = k[1]
	data["version"] = VERSION

static func load_saved() -> bool:
	if not FileAccess.file_exists(PATH):
		return false
	var f = FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return false
	var d = f.get_var()
	if d is Dictionary and d.get("version", 1) in [3, VERSION] and d.has("armies"):
		data = d
		_upgrade()
		return true
	return false

# ---------------------------------------------------------------- the map
static func neighbours(i: int) -> Array:
	var out = []
	for l in links():
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

# Up to STACK companies of one side can stand in the same region. The strongest is the one that fights
# when the region is attacked (or attacks out of it first); the region only changes hands when the last
# of them has been beaten.
const STACK = 3

static func armies_at(region: int, team: int = -1) -> Array:
	var out = data["armies"].filter(func(a): return a["region"] == region and (team < 0 or a["team"] == team))
	out.sort_custom(func(x, y): return x["str"] > y["str"])
	return out

static func army_at(region: int, team: int = -1) -> Variant:
	var l = armies_at(region, team)
	return l[0] if not l.is_empty() else null

static func room_at(region: int, team: int) -> bool:
	return armies_at(region, team).size() < STACK

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
	# (into the enemy's ground or our own, as long as there's room for another company there)
	return data["owner"][to] != 0 or room_at(to, 0)

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
	if foe == null and to == HQ[1]:
		# nobody left in the city, but the Ministry is never given up without a fight
		foe = _add_army(1, to, 10)
		foe["name"] = "Palace Guard"
		data["battle"] = {"region": to, "attacker": 0, "army": a["id"], "foe": foe["id"], "from": from, "stage": 2, "obj": ""}
		_pick_objective()
		save()
		return "battle"
	if foe == null:
		a["region"] = to
		data["owner"][to] = 0
		var l = "%s takes %s unopposed." % [a["name"], r["name"]]
		l += _cut_note(1)
		_log([l])
		save()
		return l
	data["battle"] = {"region": to, "attacker": 0, "army": a["id"], "foe": foe["id"], "from": from, "stage": 1, "obj": ""}
	_pick_objective()
	save()
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
	# a question left unanswered is answered the cautious way
	if data.get("choice") != null:
		choose(int(data["choice"].get("default", 1)))
	var net1 = supply_net(1)
	# after attacking, Bravo spends a turn regrouping before it attacks one of your armies again
	var attacked_army = data.get("bravo_rest", false)
	data["bravo_rest"] = false
	var grabs = 0          # Bravo takes at most one undefended region a turn
	var plan: Array = data.get("plan", [])
	var bravo = data["armies"].filter(func(x): return x["team"] == 1)
	# the strongest first
	bravo.sort_custom(func(x, y): return x["str"] > y["str"])
	for b in bravo:
		var best = -1
		var bs = -1e9
		var here: int = b["region"]
		var meant = -1
		for pl in plan:
			if pl["army"] == b["id"]:
				meant = pl["to"]
		for j in neighbours(here):
			var sc = _bravo_score(b, j, grabs, attacked_army, net1)
			# what it had planned, it would rather carry through
			if j == meant and sc > -1e8:
				sc += 3.0
			if sc > bs:
				bs = sc
				best = j
		if meant >= 0 and best != meant and data["owner"][meant] == 0:
			lines.append("Bravo's %s calls off its move on %s." % [b["name"], REGIONS[meant]["name"]])
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
			data["battle"] = {"region": best, "attacker": 1, "army": foe2["id"], "foe": b["id"], "from": here, "stage": 1, "obj": ""}
			_pick_objective()
			lines.append("Bravo's %s attacks your %s at %s! Defend it." % [b["name"], foe2["name"], r["name"]])
	data["plan"] = []
	if data["battle"] == null:
		lines += _new_turn()
	_headline(lines)
	_log(lines)
	save()
	return lines

# how much Bravo's army b wants to go to region j (very negative: it can't or won't)
static func _bravo_score(b: Dictionary, j: int, grabs: int, attacked_army: bool, net1: Dictionary) -> float:
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
			# (more companies behind the first: each one is another battle to win before the place falls)
			sc -= 2.5 * (armies_at(j, 0).size() - 1)
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
	elif own == 1 and room_at(j, 1):
		# move up toward the front, or fall back to recover if badly hurt
		var front = 0
		var danger = 0.0
		for k in neighbours(j):
			if data["owner"][k] == 0:
				front += 1
				for pa in armies_at(k, 0):
					danger += pa["str"]
		sc = front * 1.5 - 2.0 if b["str"] >= 5 else (4.0 if net1.has(j) and front == 0 else -1.0)
		if mine != null:
			# joining a company that's already there: worth it where the enemy next door outnumbers what's
			# holding the place (and always to stand by the capital), otherwise spread out
			var held = 0.0
			for ma in armies_at(j, 1):
				held += ma["str"]
			sc = (2.5 + front * 0.5 + (2.0 if j == HQ[1] else 0.0)) if (b["str"] >= 5 and danger > held * 1.1) else -1.0
	return sc

# What Bravo means to do next turn, as things stand now: your scouts report it, and it's drawn on the map.
# (It can still change its mind if you move men in the way.)
static func _bravo_plan() -> Array:
	var out = []
	var net1 = supply_net(1)
	var attacked = data.get("bravo_rest", false)
	var grabs = 0
	var bravo = data["armies"].filter(func(x): return x["team"] == 1)
	bravo.sort_custom(func(x, y): return x["str"] > y["str"])
	for b in bravo:
		var best = -1
		var bs = -1e9
		for j in neighbours(b["region"]):
			var sc = _bravo_score(b, j, grabs, attacked, net1)
			if sc > bs:
				bs = sc
				best = j
		if best < 0 or bs < 0.5 or data["owner"][best] != 0:
			continue
		var hit = army_at(best, 0) != null
		out.append({"army": b["id"], "from": b["region"], "to": best, "attack": hit})
		if hit:
			attacked = true
		else:
			grabs += 1
	return out

static func plan_text() -> String:
	var parts = []
	for pl in data.get("plan", []):
		var b = army(pl["army"])
		if b != null:
			parts.append("%s (%d men) is %s %s" % [b["name"], b["str"], "massing against" if pl["attack"] else "about to walk into", REGIONS[pl["to"]]["name"]])
	return ("Scouts report: Bravo's " + "; Bravo's ".join(parts) + ".") if not parts.is_empty() else "Scouts report: Bravo shows no sign of moving this turn."

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
				# stragglers and the walking wounded come back (faster, and to a bigger army, with a hospital)
				var hosp = has_bonus(t, "hospital")
				for k in range(2 if hosp else 1):
					if a["men"].size() < (16 if hosp else 10):
						add_men(a, ["rifleman"])
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
	data["plan"] = _bravo_plan()
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
	data["choice"] = null
	# what was set going last turn
	var pe = data.get("pending_ev")
	data["pending_ev"] = null
	if pe != null and pe.get("kind", "") == "partisans":
		_partisans(int(pe["region"]), lines)
	var r = randf()
	var funds: int = data["funds"][0]
	var net0 = supply_net(0)
	var mine = data["armies"].filter(func(x): return x["team"] == 0 and net0.has(x["region"]))
	mine.sort_custom(func(x, y): return x["str"] < y["str"])
	if r < 0.18:
		data["weather"] = "storm"
		data["event"] = "storm"
		lines.append("Storm front: rain and low cloud. No aircraft can fly in this turn's battles.")
	elif r < 0.36:
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
		data["choice"] = {"kind": "partisans", "region": j, "cost": 10, "default": 1,
			"text": "Partisans behind Bravo's lines at %s are asking for rifles." % REGIONS[j]["name"],
			"opts": ["Arm them (10): they rise next turn", "Keep the money"]}
	elif r < 0.52:
		var n2 = randi_range(10, 18)
		if mine.is_empty() or mine[0]["men"].size() + 4 > MAX_STR:
			data["funds"][0] += n2
			lines.append("A patrol captures an enemy supply dump: +%d to the war chest." % n2)
		else:
			data["choice"] = {"kind": "dump", "n": n2, "army": mine[0]["id"], "default": 0, "text": "A patrol has found an enemy supply dump.",
				"opts": ["Haul it home (+%d to the war chest)" % n2, "Hand it out to the %s (+4 men)" % mine[0]["name"]]}
	elif r < 0.64 and funds > 6:
		var n3 = mini(funds, randi_range(6, 12))
		var with_v = data["armies"].filter(func(x): return x["team"] == 0 and not x["veh"].is_empty())
		if with_v.is_empty():
			data["funds"][0] -= n3
			lines.append("One of our supply convoys was ambushed on the road: -%d from the war chest." % n3)
		else:
			data["choice"] = {"kind": "convoy", "n": n3, "army": with_v[0]["id"], "default": 1, "text": "One of our supply convoys is pinned down on the road.",
				"opts": ["Send the %s's vehicles to break it out (they may not all come back)" % with_v[0]["name"], "Write it off (-%d)" % n3]}
	elif r < 0.76 and not mine.is_empty() and mine[0]["men"].size() + 5 <= MAX_STR:
		data["choice"] = {"kind": "volunteers", "army": mine[0]["id"], "default": 1, "text": "Lads from %s want to join up." % REGIONS[mine[0]["region"]]["name"],
			"opts": ["Take them into the %s (+5 riflemen)" % mine[0]["name"], "Send them to the workshops (+6 to the war chest)"]}
	elif r < 0.85 and funds >= 12:
		var room = mine.filter(func(x): return x["veh"].size() < MAX_VEH)
		if not room.is_empty():
			data["choice"] = {"kind": "tank", "army": room[0]["id"], "default": 1, "text": "A quartermaster has a tank going spare, no questions asked.",
				"opts": ["Buy it for the %s (12)" % room[0]["name"], "Leave it"]}

# the partisans you armed rise: they bleed the army there, or hand the place over if it's empty
static func _partisans(j: int, lines: Array) -> void:
	if j < 0 or j >= REGIONS.size() or data["owner"][j] != 1 or j == HQ[1]:
		lines.append("The partisans we armed found nothing left to do.")
		return
	var foe = army_at(j, 1)
	if foe != null and foe["men"].size() > 3:
		var n = mini(randi_range(3, 5), foe["men"].size() - 2)
		for k in range(n):
			foe["men"].pop_back()
		_sync(foe)
		lines.append("Partisans ambush Bravo's %s at %s: %d of their men lost." % [foe["name"], REGIONS[j]["name"], n])
	elif foe == null:
		data["owner"][j] = 0
		lines.append("Partisans rise at %s and hand it over to us." % REGIONS[j]["name"] + _cut_note(1))
	else:
		lines.append("The partisans at %s harry Bravo's %s but can't shift it." % [REGIONS[j]["name"], foe["name"]])

# your answer to this turn's question (k: which of the two)
static func choose(k: int) -> String:
	var c = data.get("choice")
	if c == null:
		return ""
	data["choice"] = null
	var a = army(int(c.get("army", -1)))
	var line = ""
	match c["kind"]:
		"partisans":
			var rn: String = REGIONS[int(c["region"])]["name"]
			if k == 0 and data["funds"][0] >= int(c["cost"]):
				data["funds"][0] -= int(c["cost"])
				data["pending_ev"] = {"kind": "partisans", "region": int(c["region"])}
				line = "Rifles go out to the partisans at %s. They rise next turn." % rn
			else:
				line = "The partisans at %s are left to fend for themselves." % rn
		"dump":
			if k == 0 or a == null:
				data["funds"][0] += int(c["n"])
				line = "The captured dump is hauled home: +%d to the war chest." % int(c["n"])
			else:
				add_men(a, ["rifleman", "rifleman", "rifleman", "mg"])
				line = "The captured stores go to the %s: four more men under arms." % a["name"]
		"convoy":
			if k == 0 and a != null and not a["veh"].is_empty():
				if randf() < 0.7:
					data["funds"][0] += 3
					line = "The %s breaks the convoy out. The supplies get through (+3)." % a["name"]
				else:
					a["veh"].pop_back()
					line = "The %s breaks the convoy out, but loses a vehicle doing it." % a["name"]
			else:
				var n = mini(int(c["n"]), data["funds"][0])
				data["funds"][0] -= n
				line = "The convoy is written off: -%d from the war chest." % n
		"volunteers":
			if k == 0 and a != null:
				add_men(a, ["rifleman", "rifleman", "rifleman", "rifleman", "rifleman"])
				line = "Five volunteers join the %s." % a["name"]
			else:
				data["funds"][0] += 6
				line = "The volunteers go to the workshops: +6 to the war chest."
		"tank":
			if k == 0 and a != null and data["funds"][0] >= 12 and a["veh"].size() < MAX_VEH:
				data["funds"][0] -= 12
				a["veh"].append("tank")
				line = "A tank turns up at the %s's lines overnight (-12)." % a["name"]
			else:
				line = "The quartermaster's tank goes to somebody else."
	if line != "":
		_log([line])
	save()
	return line

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
	var what = "Attack" if b["attacker"] == 0 else "Defence"
	if int(b.get("stage", 1)) == 2:
		what = "Storming the Ministry"
	return "%s at %s: %s (%d, %s) against %s (%d, %s)" % [what, r["name"],
		ours["name"] if ours != null else "?", ours["str"] if ours != null else 0, "in supply" if ours != null and supplied(0, ours["region"]) else "cut off",
		theirs["name"] if theirs != null else "?", theirs["str"] if theirs != null else 0, "in supply" if theirs != null and supplied(1, theirs["region"]) else "cut off"]

# something extra to try for, picked to suit the two armies
static func _pick_objective() -> void:
	var b = data.get("battle")
	if b == null:
		return
	var ours = army(b["army"])
	var theirs = army(b["foe"])
	var opts = ["light"]
	if int(b.get("stage", 1)) == 1:
		opts.append("spare")
	if b["attacker"] == 0:
		opts.append("swift")
		if theirs != null and not theirs["veh"].is_empty() and int(b.get("stage", 1)) == 1:
			opts.append("armour")
	if ours != null and not ours["veh"].is_empty():
		opts.append("keep")
	b["obj"] = opts[randi() % opts.size()]

static func objective_text() -> String:
	var b = data.get("battle")
	if b == null or not OBJ.has(b.get("obj", "")):
		return ""
	var o: Array = OBJ[b["obj"]]
	return "%s: %s. Reward: %s." % [o[0], o[1], o[2]]

# how the two armies compare, for the screen before the battle
static func _power(a, defending: bool, sup: bool) -> float:
	if a == null:
		return 1.0
	var pw = 0.0
	for m in a["men"]:
		pw += 1.0 + 0.15 * int(m.get("vet", 0))
	for v in a["veh"]:
		pw += float({"jeep": 2.0, "technical": 2.5, "motorbike": 1.0, "halftrack": 4.0, "armoredcar": 6.0, "tank": 10.0, "heavytank": 14.0}.get(v, 2.0))
	return maxf(0.5, pw * (1.3 if defending else 1.0) * (1.0 if sup else 0.8))

static func odds() -> Array:
	var b = data.get("battle")
	if b == null:
		return [1.0, "even"]
	var ours = army(b["army"])
	var theirs = army(b["foe"])
	var p0 = _power(ours, b["attacker"] == 1, ours != null and supplied(0, ours["region"] if b["attacker"] == 1 else b["from"]))
	var p1 = _power(theirs, b["attacker"] == 0, theirs != null and supplied(1, theirs["region"] if b["attacker"] == 0 else b["from"]))
	var k = p0 / p1
	return [k, "very good" if k > 1.6 else ("good" if k > 1.2 else ("even" if k > 0.85 else ("poor" if k > 0.6 else "bad")))]

# How you fight it: "command" (from above, you give the orders), "soldier" (the AI commands your side and
# you're one of the men), or auto_resolve() below.
static var how = "command"
static var stage2 = false
static var free_def = {}
static var t_start = 0.0

static func start_battle(h: String) -> void:
	how = h
	G.settings["ai_side"] = h == "soldier"
	_start_battle()
	if h == "soldier":
		var best = null
		for s in G.soldiers:
			if s.team == 0 and s.state == "alive" and s.vehicle == null and (best == null or (s.cls == "rifleman" and best.cls != "rifleman") or (s.vet > best.vet and s.cls == best.cls)):
				best = s
		if best != null:
			G.pc.possess(best)

static func _start_battle() -> void:
	var b = data["battle"]
	var ours = army(b["army"])
	var theirs = army(b["foe"])
	var i: int = b["region"]
	stage2 = int(b.get("stage", 1)) == 2
	var mode = REGIONS[i]["mode"] if b["attacker"] == 0 else "siege"
	if stage2:
		mode = "capture"
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
	attack(i, mode, maxi(n0, n1), [sup0, sup1], [n0, n1], [cls0, cls1], [ours["veh"] if ours != null else [], theirs["veh"] if theirs != null else []], "office" if stage2 else "")

# start the battle for region i (also used directly by the tests)
static func attack(i: int, mode: String = "", size: int = SQUAD, supply: Array = [true, true], sizes: Array = [], cls: Array = [], vehs: Array = [], map_id: String = "") -> void:
	active = true
	current = i
	var r = REGIONS[i]
	if mode == "":
		mode = r["mode"]
	# each side fields its army's real strength; a side out of supply gets no reinforcements
	data["no_reinf"] = [not supply[0], not supply[1]]
	G.main.start_game({"map": map_id if map_id != "" else r["map"], "mode": mode, "size": size, "limit": G.default_limit(mode), "reinforce": true,
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
				s.sname = "%s %s" % [RANK_S[clampi(int(men[k]["vet"]), 0, 3)], men[k]["name"]]
				s.set_vet(men[k]["vet"])
				s.set_meta("roster", k)
				_apply_perk(s, str(men[k].get("perk", "")))
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
	free_def = {}
	t_start = G.sim_time
	for t2 in range(2):
		if has_bonus(t2, "guns") and t2 < Support.points.size():
			Support.points[t2] += 20
	if b != null and b.get("attacker", 0) == 1 and how == "command" and not G.settings.get("ai_side", false):
		# you're in command and they're coming: a stock of defences to put where you want them, up at once
		free_def = {"sandbags": 6, "wire": 3, "mgnest": 2, "traps": 3, "mortarpit": 1}
		note += " · place your defences (Defences tab): 6 sandbag walls, 3 wire, 2 MG nests, 3 traps and a mortar pit go up at once"
	elif b != null and b.get("attacker", 0) == 1:
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
	G.ui.message("Battle for %s · %d of our vehicles%s" % [r["name"] if not stage2 else "the Ministry", nveh, note])
	var ot = objective_text()
	if ot != "":
		G.ui.radio(0, "Objective. " + ot)
	Prep.start((120.0 if not free_def.is_empty() else 90.0) if b != null and b.get("attacker", 0) == 1 else Prep.SECS)

# one of the free defences put down before a defensive battle: true if this one's on the house
static func take_free(kind: String) -> bool:
	if not active or not Prep.active() or int(free_def.get(kind, 0)) <= 0:
		return false
	free_def[kind] -= 1
	return true

static func free_left() -> String:
	var parts = []
	for k in free_def:
		if int(free_def[k]) > 0:
			parts.append("%d %s" % [free_def[k], Build.KINDS[k]["name"].to_lower()])
	return ", ".join(parts)

static func _apply_perk(s, perk: String) -> void:
	if perk == "":
		return
	s.set_meta("perk", perk)
	match perk:
		"tough":
			s.hp = 125.0
		"steady":
			s.nerve *= 0.7
		"scrounger":
			s.grenades += 1
			s.smokes += 1

# reinforcements are off for a side that's cut off
static func reinforce_ok(t: int) -> bool:
	if not active:
		return true
	var nr = data.get("no_reinf", [false, false])
	return t >= nr.size() or not nr[t]

# which of a region's map pieces were destroyed in earlier battles there
static func ruins(i: int) -> Array:
	if stage2:
		return []          # (the Ministry is its own map: the city's ruins aren't its ruins)
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
		if data["owner"][j] == t and room_at(j, t):
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
	last_before = before if t == 0 else last_before
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
				_fell(m, a, int(r[1]))
				continue
			m["battles"] += 1
			m["kills"] += r[1]
			if m["vet"] < 3 and (r[1] >= 2 or m["battles"] % 2 == 0):
				_promote(m)
				promoted.append("%s %s" % [RANK_S[m["vet"]], m["name"]])
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
		last_fell = fell
		last_lost_v = lost_v
		lines.append("%s: %d men left%s%s." % [a["name"], a["men"].size(), (" (%d fell)" % fell) if fell > 0 else "", (", %d vehicles lost" % lost_v) if lost_v > 0 else ""])
		if not promoted.is_empty():
			lines.append("Promoted: " + ", ".join(promoted.slice(0, 6)) + ("…" if promoted.size() > 6 else ""))
	return lines

static var last_before = 0
static var last_fell = 0
static var last_lost_v = 0

static func _promote(m: Dictionary) -> void:
	m["vet"] = mini(3, int(m["vet"]) + 1)
	if m["vet"] >= 2 and str(m.get("perk", "")) == "":
		var ks = PERKS.keys()
		m["perk"] = ks[randi() % ks.size()]

# a man who didn't come back goes on the roll
static func _fell(m: Dictionary, a: Dictionary, kills_now: int) -> void:
	if not data.has("fallen"):
		data["fallen"] = []
	var b = data.get("battle")
	data["fallen"].push_front({"name": m["name"], "cls": m["cls"], "vet": int(m["vet"]), "kills": int(m["kills"]) + kills_now, "battles": int(m["battles"]) + 1,
		"army": a["name"], "at": REGIONS[int(b["region"])]["name"] if b != null else "", "turn": data["turn"]})
	if data["fallen"].size() > 120:
		data["fallen"].resize(120)

static func battle_over(winner: int) -> String:
	if not active or current < 0:
		return ""
	active = false
	var r = REGIONS[current]
	var lines = []
	var wrecked = 0
	if not stage2:
		wrecked = _record_ruins(current)
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
		last_before = 0
		last_fell = 0
		last_lost_v = 0
		var foe_veh_left = G.vehicles.filter(func(v): return is_instance_valid(v) and not v.dead and v.team == 1 and not v.spec.get("air", false) and not v.spec.get("static", false) and v.kind in ["jeep", "technical", "halftrack", "armoredcar", "tank", "heavytank"]).size()
		var foe_veh_kind = str(theirs["veh"][0]) if theirs != null and not theirs["veh"].is_empty() else ""
		if ours != null:
			lines += _survivors(ours, winner != 0)
		if theirs != null:
			_survivors(theirs, winner != 1)
		if winner == 0 and ours != null:
			lines += _objective_result(b, ours, wrecked, foe_veh_left, foe_veh_kind)
		lines += _outcome(b, winner, ours, theirs)
	_headline(lines)
	_log(lines)
	save()
	return "\n".join(lines)

# did you bring off the extra you were asked for?
static func _objective_result(b: Dictionary, ours: Dictionary, wrecked: int, foe_veh_left: int, foe_veh_kind: String) -> Array:
	var key: String = b.get("obj", "")
	if not OBJ.has(key):
		return []
	var done = false
	var mins = (G.sim_time - t_start) / 60.0
	match key:
		"swift":
			done = mins <= 8.0 + Prep.SECS / 60.0
		"light":
			done = last_before > 0 and last_fell * 3 <= last_before
		"armour":
			done = foe_veh_left == 0
		"spare":
			done = wrecked < 20
		"keep":
			done = last_lost_v == 0
	if not done:
		return ["Objective missed: %s (%s)." % [OBJ[key][0], OBJ[key][1]]]
	var got = ""
	match key:
		"swift":
			data["funds"][0] += 10
			got = "+10 to the war chest"
		"spare":
			data["funds"][0] += 8
			got = "the townsfolk pay their thanks: +8 to the war chest"
		"keep":
			data["funds"][0] += 6
			got = "+6 to the war chest"
		"light":
			var n = 0
			for m in ours["men"]:
				if int(m["vet"]) < 3 and n < 2:
					_promote(m)
					n += 1
			got = "%d more men promoted" % n
		"armour":
			if foe_veh_kind != "" and ours["veh"].size() < MAX_VEH:
				ours["veh"].append(foe_veh_kind)
				got = "a captured %s joins the %s" % [foe_veh_kind, ours["name"]]
			else:
				data["funds"][0] += 8
				got = "the wrecks are stripped for parts: +8 to the war chest"
	return ["Objective won: %s. %s." % [OBJ[key][0], got.capitalize()]]

# who holds the ground now, and where the beaten army goes (shared by a fought battle and an auto-resolved one)
static func _outcome(b: Dictionary, winner: int, ours, theirs) -> Array:
	var lines = []
	var i: int = b["region"]
	var r = REGIONS[i]
	var st2 = int(b.get("stage", 1)) == 2
	if b["attacker"] == 0:
		var rest1 = armies_at(i, 1).filter(func(x): return x != theirs)
		if winner == 0 and i == HQ[1] and not st2 and rest1.is_empty():
			# the city is taken; the last of them are in the Ministry, and it has to be stormed
			if theirs == null or not (theirs in data["armies"]):
				theirs = _add_army(1, i, 0)
				theirs["name"] = "Palace Guard"
				b["foe"] = theirs["id"]
			var need = []
			for k in range(maxi(0, 10 - theirs["men"].size())):
				need.append(MIX[k % MIX.size()])
			add_men(theirs, need)
			theirs["veh"] = []
			b["stage"] = 2
			_pick_objective()
			lines.append("The city is ours, but Bravo's staff are holding out in the Ministry. One more fight: storm it.")
			return lines
		if winner == 0 and not rest1.is_empty() and not st2:
			# beaten, but not the last of them: the place is still held, and our company goes back to where
			# it set out from
			lines.append("Victory at %s, but Bravo still holds it with %s. It must be beaten too." % [r["name"], rest1[0]["name"] if rest1.size() == 1 else "%d more companies" % rest1.size()])
			if theirs != null:
				_retreat(theirs, lines)
			if ours != null:
				ours["region"] = b["from"]
		elif winner == 0:
			data["owner"][i] = 0
			lines.append(("The Ministry has fallen. %s is ours!" if st2 else "Victory at %s! The region is ours.") % r["name"])
			if theirs != null:
				_retreat(theirs, lines)
			if ours != null:
				ours["region"] = i
			lines[lines.size() - 1] += _cut_note(1)
		else:
			lines.append(("The assault on the Ministry failed. %s still holds out." if st2 else "Our attack on %s failed.") % r["name"])
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
		elif not armies_at(i, 0).filter(func(x): return x != ours).is_empty():
			# our company was beaten, but another of ours is still standing there: the ground is held
			var rest0 = armies_at(i, 0).filter(func(x): return x != ours)
			lines.append("Our %s was beaten at %s, but %s still holds the ground." % [ours["name"] if ours != null else "company", r["name"], rest0[0]["name"] if rest0.size() == 1 else "%d of our companies" % rest0.size()])
			if ours != null:
				_retreat(ours, lines)
			if theirs != null:
				theirs["region"] = b["from"]
		else:
			data["owner"][i] = 1
			lines.append("%s has fallen to Bravo." % r["name"])
			if ours != null:
				_retreat(ours, lines)
			if theirs != null:
				theirs["region"] = i
			lines[lines.size() - 1] += _cut_note(0)
	data["battle"] = null
	# the rest of Bravo's turn: supply, recovery, new armies
	if b["attacker"] == 1:
		lines += _new_turn()
	return lines

# ---------------------------------------------------------------- settle it without fighting
# The staff work it out on paper: quicker, but it costs more men than a battle well fought, nobody earns
# an objective, and fewer are promoted.
static func auto_resolve() -> String:
	var b = data.get("battle")
	if b == null:
		return ""
	var ours = army(b["army"])
	var theirs = army(b["foe"])
	var sup0 = ours != null and supplied(0, ours["region"] if b["attacker"] == 1 else b["from"])
	var sup1 = theirs != null and supplied(1, theirs["region"] if b["attacker"] == 0 else b["from"])
	var p0 = _power(ours, b["attacker"] == 1, sup0) * randf_range(0.85, 1.15)
	var p1 = _power(theirs, b["attacker"] == 0, sup1) * randf_range(0.85, 1.15)
	var winner = 0 if p0 >= p1 else 1
	var ratio = maxf(p0, p1) / maxf(minf(p0, p1), 0.5)
	var lose_frac = clampf(0.3 + 0.12 * ratio, 0.42, 0.8)
	var win_frac = clampf(0.42 / ratio, 0.1, 0.4)
	var lines = ["The staff settle %s on paper." % ("the storming of the Ministry" if int(b.get("stage", 1)) == 2 else "the fight for " + REGIONS[int(b["region"])]["name"])]
	if ours != null:
		lines += _auto_losses(ours, win_frac if winner == 0 else lose_frac, winner == 0)
	if theirs != null:
		_auto_losses(theirs, win_frac if winner == 1 else lose_frac, winner == 1)
	lines += _outcome(b, winner, ours, theirs)
	_headline(lines)
	_log(lines)
	save()
	return "\n".join(lines)

static func _auto_losses(a: Dictionary, frac: float, won: bool) -> Array:
	var before: int = a["men"].size()
	var n = clampi(int(round(before * frac)), 0 if won else mini(1, before), maxi(0, before - 1))
	for k in range(n):
		if a["men"].is_empty():
			break
		var j = randi() % a["men"].size()
		if a["team"] == 0:
			_fell(a["men"][j], a, 0)
		a["men"].remove_at(j)
	var promoted = []
	if a["team"] == 0:
		for m in a["men"]:
			m["battles"] += 1
			if int(m["vet"]) < 3 and randf() < 0.2:
				_promote(m)
				promoted.append("%s %s" % [RANK_S[m["vet"]], m["name"]])
	var lost_v = 0
	for k in range(a["veh"].size() - 1, -1, -1):
		if randf() < (0.15 if won else 0.55):
			a["veh"].remove_at(k)
			lost_v += 1
	_sync(a)
	if a["team"] != 0:
		return []
	var out = ["%s: %d men left%s%s." % [a["name"], a["men"].size(), (" (%d fell)" % n) if n > 0 else "", (", %d vehicles lost" % lost_v) if lost_v > 0 else ""]]
	if not promoted.is_empty():
		out.append("Promoted: " + ", ".join(promoted.slice(0, 6)))
	return out

# ---------------------------------------------------------------- the paper
# One headline a turn, from the biggest thing that happened.
static func _headline(lines: Array) -> void:
	var keys = ["campaign is won", "campaign is lost", "Ministry has fallen", "holding out in the Ministry", "Victory at", "has fallen to Bravo", "We held", "failed",
		"is destroyed", "is broken", "cut off", "Partisans", "attacks your", "pushes into", "takes", "Storm front", "calls off"]
	var pick = ""
	for k in keys:
		for l in lines:
			if str(l).find(k) >= 0:
				pick = str(l)
				break
		if pick != "":
			break
	var head = "ALL QUIET ON THE FRONT"
	if pick != "":
		var cutp = pick.length()
		for ch in ["!", ".", ":"]:
			var at = pick.find(ch)
			if at > 8 and at < cutp:
				cutp = at
		head = pick.substr(0, mini(cutp, 58)).to_upper()
	var held = data["owner"].count(0)
	var total = data["owner"].count(0) + data["owner"].count(1)
	data["headline"] = {"head": head, "sub": "We hold %d of %d regions. War chest %d. %d names on the roll of the fallen." % [held, total, data["funds"][0], data.get("fallen", []).size()], "turn": data["turn"]}
