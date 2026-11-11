class_name Logistics
extends RefCounted
# Commander mode's supply trucks and ammo trucks.
# Each side runs a small fleet of supply trucks (three at most). They load up at HQ, drive out to the
# supply dumps (which must be well away from HQ) and to FOBs running short, and only earn their points
# when they get there. A truck that's knocked out is gone: buy another at HQ.
# An ammo truck is bought, driven up behind the line and parked: soldiers nearby run to it to restock.

const FLEET_MAX = 3
const FLEET_START = 2
const LOAD = 8
const LOAD_TIME = 14.0
const AMMO_STOCK = 260.0

static var fleet: Array = [[], []]
static var started: Array = [false, false]
static var tick_t = 0.0
static var delivered: Array = [0, 0]

static func reset() -> void:
	fleet = [[], []]
	started = [false, false]
	tick_t = 0.0
	delivered = [0, 0]

static func count(team: int) -> int:
	return fleet[team].filter(func(v): return is_instance_valid(v) and not v.dead).size() if team < fleet.size() else 0

# somewhere for the trucks to go: a supply dump or a FOB that's finished
static func has_stop(team: int) -> bool:
	for st in Build.sites:
		if st["team"] == team and Build.alive(st) and st["kind"] in ["supply", "fob", "fob2"]:
			return true
	return false

static func can_buy_truck(team: int) -> bool:
	return Prod.active() and count(team) < FLEET_MAX and Build.hq_alive(team) and has_stop(team)

# a new supply truck drives in from the edge of the map behind HQ and joins the fleet
static func buy_truck(team: int) -> bool:
	if not can_buy_truck(team):
		return false
	var h = Build.hq(team)
	var park = G.main._free_spot(h["p"] + Build._front(h) * 12.0 + _park_off(team))
	var v = Reinforce.drive_in(team, "supplytruck", park, true, false)
	if v == null:
		return false
	v.command(park)
	_join(team, v)
	G.ui.radio(team, "HQ: a new supply truck is on its way (%d of %d)" % [count(team), FLEET_MAX])
	return true

static func _park_off(team: int) -> Vector3:
	var h = Build.hq(team)
	var f = Build._front(h)
	var side = Vector3(f.z, 0, -f.x)
	return side * (-7.0 + 7.0 * (fleet[team].size() % 3))

static func _join(team: int, v) -> void:
	fleet[team].append(v)
	v.set_meta("fleet", true)
	v.set_meta("load_t", G.sim_time + 4.0)
	var cargo = Node3D.new()
	v.add_child(cargo)
	v.set_meta("cargo", cargo)

static func step(dt: float) -> void:
	if not Prod.active() or G.over:
		return
	tick_t -= dt
	if tick_t > 0.0:
		return
	tick_t = 1.0
	for t in range(2):
		var h = Build.hq(t)
		if h == null or not Build.alive(h):
			continue
		# the first trucks turn up once there's a supply dump or a FOB for them to run to
		if not started[t] and has_stop(t):
			started[t] = true
			for k in range(FLEET_START):
				var p = G.main._free_spot(h["p"] + Build._front(h) * 12.0 + _park_off(t))
				var v = Reinforce.drive_in(t, "supplytruck", p, true, false)
				if v == null:
					continue
				v.command(p)
				_join(t, v)
			G.ui.radio(t, "HQ: %d supply trucks are on their way to run supplies" % FLEET_START)
		# trucks lost on the road
		for i in range(fleet[t].size() - 1, -1, -1):
			var v = fleet[t][i]
			if not is_instance_valid(v) or v.dead:
				fleet[t].remove_at(i)
				G.ui.radio(t, "A supply truck has been destroyed! %d left. Buy another at HQ (%d supply)" % [count(t), Support.COSTS["supplytruck"]])
		for v in fleet[t]:
			_dispatch(t, v, h)
		# the AI side keeps its fleet up
		if G.ai_runs(t) and count(t) < 2 and Support.points[t] >= Support.COSTS["supplytruck"] + 6:
			Support.points[t] -= Support.COSTS["supplytruck"]
			buy_truck(t)
	_ammo_trucks()

# an idle truck back at HQ, loaded: off to whichever dump or FOB needs it most
static func _dispatch(t: int, v, h) -> void:
	if v.mission != null or v.driver() == null or G.sim_time < v.get_meta("load_t", 0.0):
		return
	if v.cmd != null and G.dist2d(v.pos, v.cmd) > 8.0 and G.dist2d(v.pos, h["p"]) > 30.0:
		return      # the player's sent it somewhere
	var best = null
	var bs = 1e9
	for st in Build.sites:
		if st["team"] != t or not Build.alive(st) or not st["done"] or not (st["kind"] in ["supply", "fob", "fob2"]):
			continue
		var tr = st.get("convoy")
		if tr != null and is_instance_valid(tr) and not tr.dead and tr != v and tr.mission != null:
			continue        # somebody's already on the way there
		var sc = G.sim_time - st.get("served_t", -999.0)
		if st["kind"] != "supply":
			if st.get("ammo") == null or st["ammo"]["stock"] > 70.0:
				continue
			sc += 40.0
		sc = -sc
		if sc < bs:
			bs = sc
			best = st
	if best == null:
		return
	var home = G.main._free_spot(h["p"] + Build._front(h) * 12.0)
	var drop = G.world.park_spot(best["p"], v, h["p"])
	var load = int(LOAD * (1.5 if Prod.has(t, "logistics") else 1.0)) if best["kind"] == "supply" else 0
	v.cmd = null
	v.mission = {"type": "supply", "fleet": true, "drop": drop, "exit": home, "stage": 0, "wait": 0.0, "site": best, "pts": load}
	best["convoy"] = v
	best["served_t"] = G.sim_time
	_show_cargo(v, true)
	if t == 0:
		G.ui.radio(t, "Supply truck heading for the %s at %s" % [best["name"], AI.grid_ref(best["p"])])

static func _show_cargo(v, on: bool) -> void:
	var c = v.get_meta("cargo") if v.has_meta("cargo") else null
	if c == null or not is_instance_valid(c):
		return
	if on and c.get_child_count() == 0:
		for k in range(4):
			VModel.box(v, c, Vector3(0.95, 0.45, 0.7), Vector3(-0.55 + (k % 2) * 1.1, 2.3, -1.8 - (k / 2) * 0.9), Color(0.3, 0.33, 0.2).darkened(randf_range(0.0, 0.15)), {"b": 0.03})
	c.visible = on

# back home after a run (called by the truck): unload the empties and load up again
static func arrived_home(v) -> void:
	v.mission = null
	v.set_meta("load_t", G.sim_time + LOAD_TIME)
	v.command(v.pos)
	_show_cargo(v, false)

# ---------------------------------------------------------------- ammo trucks
# parked, an ammo truck is an ammunition point that moves with it: men come and restock from its tailgate
static func _ammo_trucks() -> void:
	for v in G.vehicles:
		if v.kind != "ammotruck":
			continue
		var ap = v.get_meta("ap") if v.has_meta("ap") else null
		if v.dead or not is_instance_valid(v):
			if ap != null:
				G.world.ammo_points.erase(ap)
				v.remove_meta("ap")
			continue
		if ap == null:
			ap = {"p": v.pos, "team": v.team, "stock": AMMO_STOCK, "truck": true}
			v.set_meta("ap", ap)
		var parked = absf(v.speed) < 0.3
		var back = v.pos - v.forward() * (v.spec["len"] * 0.5 + 1.2)
		ap["p"] = Vector3(back.x, G.world.ground_y(back.x, back.z), back.z)
		ap["team"] = v.team
		var listed = G.world.ammo_points.has(ap)
		if parked and ap["stock"] > 0.0 and not listed:
			G.world.ammo_points.append(ap)
		elif (not parked or ap["stock"] <= 0.0) and listed:
			G.world.ammo_points.erase(ap)
			if ap["stock"] <= 0.0 and not v.has_meta("empty_said"):
				v.set_meta("empty_said", true)
				G.ui.radio(v.team, "Ammo truck is empty: bring it back to HQ to load up")
		# back at HQ or a supply dump: refilled
		if ap["stock"] < AMMO_STOCK:
			for st in Build.sites:
				if st["team"] == v.team and Build.alive(st) and st["kind"] in ["hq", "supply"] and G.dist2d(st["p"], v.pos) < 25.0:
					ap["stock"] = minf(AMMO_STOCK, ap["stock"] + 20.0)
					if ap["stock"] >= AMMO_STOCK and v.has_meta("empty_said"):
						v.remove_meta("empty_said")
						G.ui.radio(v.team, "Ammo truck loaded up")
					break
