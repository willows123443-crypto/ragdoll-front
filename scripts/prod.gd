class_name Prod
extends RefCounted
# Commander mode's war economy.
# Vehicles you buy are built one after another at your vehicle depot (a queue you can watch fill).
# Upgrades are researched at your HQ, one at a time.
# Supplies come by road: every so often a truck sets off from your edge of the map for each supply dump,
# and the points only count when it gets there. Lose the truck on the way and they're lost with it.

const TIME = {"jeep": 18.0, "technical": 16.0, "motorbike": 12.0, "halftrack": 30.0, "armoredcar": 38.0, "tank": 55.0,
	"heavytank": 75.0, "plough": 60.0, "atgun": 22.0, "ambulance": 18.0, "radar": 32.0, "bridger": 32.0}
const UPGRADES = {
	"armour": {"name": "Heavier armour", "cost": 30, "time": 60.0, "desc": "vehicles take a third less damage",
		"long": "every vehicle you have and buy afterwards takes a third less damage from bullets, rockets and shells"},
	"engineers": {"name": "Field engineering", "cost": 20, "time": 45.0, "desc": "engineers build twice as fast",
		"long": "engineers put up structures and repair them twice as fast (other soldiers who help build are unchanged)"},
	"artillery": {"name": "Heavy artillery", "cost": 30, "time": 60.0, "desc": "barrages fire more and bigger shells",
		"long": "artillery barrages fire twelve heavier shells instead of eight, so they hit harder and cover more ground"},
	"logistics": {"name": "Logistics", "cost": 20, "time": 45.0, "desc": "supply convoys carry half as much again",
		"long": "each supply truck run to a dump brings in half as many points again (12 instead of 8)"},
}
const CONVOY_EVERY = 45.0
const CONVOY_LOAD = 8

static var queues: Array = [[], []]
static var research: Array = [[], []]
static var done: Array = [{}, {}]
static var convoy_t: Array = [20.0, 20.0]

static func reset() -> void:
	queues = [[], []]
	research = [[], []]
	done = [{}, {}]
	convoy_t = [20.0, 25.0]
	Logistics.reset()

static func active() -> bool:
	return G.mode == "commander"

static func is_vehicle(what: String) -> bool:
	return TIME.has(what)

static func has(team: int, up: String) -> bool:
	return active() and team < done.size() and done[team].has(up)

# a vehicle that's been paid for joins the depot's queue
static func order(team: int, what: String) -> void:
	queues[team].append({"what": what, "t": 0.0, "need": TIME.get(what, 30.0)})
	if queues[team].size() > 1:
		G.ui.radio(team, "%s added to the depot's queue (%d waiting)" % [Support.NAMES[what].split(" (")[0], queues[team].size() - 1])
	else:
		G.ui.radio(team, "Depot: building a %s" % Support.NAMES[what].split(" (")[0].to_lower())

static func can_research(team: int, up: String) -> bool:
	if done[team].has(up):
		return false
	for r in research[team]:
		if r["what"] == up:
			return false
	return true

static func start_research(team: int, up: String) -> bool:
	if not can_research(team, up) or Support.points[team] < UPGRADES[up]["cost"]:
		return false
	Support.points[team] -= UPGRADES[up]["cost"]
	research[team].append({"what": up, "t": 0.0, "need": UPGRADES[up]["time"]})
	G.ui.radio(team, "HQ: work starts on %s" % UPGRADES[up]["name"].to_lower())
	return true

static func step(dt: float) -> void:
	if not active() or G.over:
		return
	for t in range(2):
		# the depot works through its queue (twice as fast with two depots)
		if not queues[t].is_empty():
			var depots = 0
			for st in Build.sites:
				if st["team"] == t and st["kind"] == "depot" and Build.alive(st):
					depots += 1
			if depots > 0:
				var q = queues[t][0]
				q["t"] += dt * (1.0 if depots == 1 else 1.6)
				if q["t"] >= q["need"]:
					queues[t].pop_front()
					_roll_out(t, q["what"])
		if not research[t].is_empty():
			var h = Build.hq(t)
			if h != null and Build.alive(h):
				var r = research[t][0]
				r["t"] += dt
				if r["t"] >= r["need"]:
					research[t].pop_front()
					done[t][r["what"]] = true
					G.ui.radio(t, "HQ: %s ready (%s)" % [UPGRADES[r["what"]]["name"], UPGRADES[r["what"]]["desc"]])
		pass
	Logistics.step(dt)

# a finished vehicle drives out of the depot (or in from the rear if the depot's gone)
static func _roll_out(team: int, what: String) -> void:
	var dep = null
	for st in Build.sites:
		if st["team"] == team and st["kind"] == "depot" and Build.alive(st):
			dep = st
			break
	if dep != null:
		var p = dep["p"] + Build._front(dep) * 8.0
		Reinforce.drive_in(team, what, p, true, false)
		G.ui.radio(team, "Depot: %s on its way in" % Support.NAMES[what].split(" (")[0].to_lower())
	else:
		Support.deliver(team, what)

# one truck per supply dump, from our edge of the map
static func _send_convoys(team: int) -> void:
	var n = 0
	for st in Build.sites:
		if st["team"] != team or st["kind"] != "supply" or not Build.alive(st) or n >= 3:
			continue
		var tr = st.get("convoy")
		if tr != null and is_instance_valid(tr) and not tr.dead:
			continue        # the last one hasn't got there yet
		n += 1
		var start = Reinforce.offmap(Reinforce.clear_entry(team))
		var drop = G.world.park_spot(st["p"], null, start)
		var v = Vehicle.make("truck", team, start, atan2(drop.x - start.x, drop.z - start.z))
		var load = int(CONVOY_LOAD * (1.5 if has(team, "logistics") else 1.0))
		v.mission = {"type": "supply", "drop": drop, "exit": start, "stage": 0, "wait": 0.0, "site": st, "pts": load}
		AI.batch_begin(AI.CREW)
		var drv = G.main.spawn_soldier(team, start.x, start.z, "rifle")
		AI.batch_end()
		if drv == null:
			v.remove()
			continue
		drv.mount(v, 0)
		st["convoy"] = v
		var cargo = Node3D.new()
		v.add_child(cargo)
		for k in range(6):
			VModel.box(v, cargo, Vector3(0.95, 0.55, 0.65), Vector3(-0.55 + (k % 2) * 1.1, 1.75, -0.2 - (k / 2) * 1.2), Color(0.3, 0.33, 0.2).darkened(randf_range(0.0, 0.15)), {"b": 0.03})
		v.set_meta("cargo", cargo)
	if n > 0:
		G.ui.radio(team, "Supply convoy on the road (%d truck%s): keep the route clear" % [n, "" if n == 1 else "s"])

# what's going on, for the dock
static func status(team: int) -> String:
	var parts = []
	if not queues[team].is_empty():
		var q = queues[team][0]
		var s = "Depot: %s %d%%" % [Support.NAMES[q["what"]].split(" (")[0], int(100.0 * q["t"] / q["need"])]
		if queues[team].size() > 1:
			s += " (+%d)" % (queues[team].size() - 1)
		parts.append(s)
	if not research[team].is_empty():
		var r = research[team][0]
		parts.append("HQ: %s %d%%" % [UPGRADES[r["what"]]["name"], int(100.0 * r["t"] / r["need"])])
	parts.append("Convoy in %d s" % int(convoy_t[team]))
	return "  ·  ".join(parts)
