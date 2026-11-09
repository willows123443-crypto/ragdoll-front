class_name Scripted
extends RefCounted
# Editor-made scenarios: squads and vehicles placed on the map with standing orders, and triggers
# ("when Alpha reaches the bridge, Bravo's reserve counter-attacks") that fire once during the battle.
#
# unit:    {"kind": "squad"|"vehicle", "team", "x", "z", "rot", "size", "vtype", "order", "wp": [Vector3...]}
#          orders: hold, move, patrol, attack, free
# trigger: {"when", "team", "x", "z", "r", "t", "n", "then", "ateam", "ax", "az", "text", "vtype", "pt"}
#          when: time, enter, clear, point, losses
#          then: reinforce, vehicle, artillery, airstrike, smoke, message, attack, win

const ORDERS = ["hold", "move", "patrol", "attack", "free"]
const ORDER_NAMES = ["Hold here", "Move to waypoint", "Patrol waypoints", "Attack the points", "Act on their own"]
const WHEN = ["time", "enter", "clear", "point", "losses"]
const WHEN_NAMES = ["After a time", "Team enters area", "Area cleared of team", "Team takes a point", "Team has lost N men"]
const THEN = ["reinforce", "vehicle", "artillery", "airstrike", "smoke", "message", "attack", "win"]
const THEN_NAMES = ["Reinforcements arrive", "Vehicle arrives", "Artillery barrage", "Air strike", "Smoke screen", "Show a message", "Team attacks the spot", "Team wins"]
const VEHICLES = ["jeep", "truck", "halftrack", "armoredcar", "tank", "artillery", "mortar", "nest", "aagun"]

static var groups: Array = []          # placed units at play time: {"u": unit, "members": [], "veh": v, "wi": waypoint index}
static var triggers: Array = []
static var fired = {}
static var losses = [0, 0]
static var check_t = 0.0

static func active() -> bool:
	return G.map_id == "custom" and not (triggers.is_empty() and groups.is_empty())

static func reset() -> void:
	groups = []
	triggers = []
	fired = {}
	losses = [0, 0]
	check_t = 0.0

# called after the standard armies (if any) are in place
static func setup(m: Dictionary) -> void:
	reset()
	for u in m.get("units", []):
		_spawn_unit(u)
	triggers = m.get("triggers", []).duplicate(true)

static func placed_count(m: Dictionary, team: int) -> int:
	var n = 0
	for u in m.get("units", []):
		if u["team"] == team and u["kind"] == "squad":
			n += int(u.get("size", 6))
	return n

static func _spawn_unit(u: Dictionary) -> void:
	var p = Vector3(u["x"], 0, u["z"])
	var yaw = PI / 2.0 if u.get("rot", 0) == 0 else 0.0
	if u["team"] == 1:
		yaw += PI
	var gr = {"u": u, "members": [], "veh": null, "wi": 0}
	if u["kind"] == "vehicle":
		var v = G.main.spawn_vehicle(u.get("vtype", "jeep"), u["team"], p, yaw)
		gr["veh"] = v
		var wp: Array = u.get("wp", [])
		match u.get("order", "free"):
			"hold":
				v.mission = {"type": "route", "pts": [p], "loop": false, "stage": 0, "wait": 0.0, "drop": p, "exit": p}
			"move", "patrol":
				if not wp.is_empty():
					v.mission = {"type": "route", "pts": wp.duplicate(), "loop": u["order"] == "patrol", "stage": 0, "wait": 0.0, "drop": wp[0], "exit": wp[0], "i": 0}
	else:
		var n = int(u.get("size", 6))
		for i in range(n):
			var q = G.main._free_spot(p + Vector3((i % 3) - 1.0, 0, int(i / 3) - 0.5) * 1.6)
			var s = G.main.spawn_soldier(u["team"], q.x, q.z, "")
			if s != null:
				s.face(yaw)
				gr["members"].append(s)
		_give_order(gr)
	groups.append(gr)

static func _give_order(gr: Dictionary) -> void:
	var u = gr["u"]
	var wp: Array = u.get("wp", [])
	for s in gr["members"]:
		if not is_instance_valid(s) or s.state == "dead" or s.is_player:
			continue
		var a = float(s.id) * 2.39
		var off = Vector3(cos(a), 0, sin(a)) * 2.0
		match u.get("order", "free"):
			"hold":
				s.order = {"mode": "hold", "point": s.pos}
			"move", "patrol":
				if not wp.is_empty():
					s.order = {"mode": "move", "point": wp[clampi(gr["wi"], 0, wp.size() - 1)] + off}
			"attack":
				s.order = {"mode": "charge", "point": s.pos}
			_:
				s.order = null
		s.decide_t = 0.0

# placed vehicles driving their waypoints
static func route_target(v, m: Dictionary):
	var pts: Array = m["pts"]
	if pts.is_empty():
		return null
	var i = clampi(m.get("i", 0), 0, pts.size() - 1)
	var tgt: Vector3 = pts[i]
	if G.dist2d(v.pos, tgt) < 7.0:
		if i < pts.size() - 1:
			m["i"] = i + 1
		elif m.get("loop", false):
			m["i"] = 0
		else:
			return null
		tgt = pts[m["i"]]
	return tgt

static func on_death(s) -> void:
	if s.team < 2:
		losses[s.team] += 1

static func step(dt: float) -> void:
	if G.over or (groups.is_empty() and triggers.is_empty()):
		return
	check_t -= dt
	if check_t > 0.0:
		return
	check_t = 0.5
	# patrols: when most of the squad is at the waypoint, move on to the next one
	for gr in groups:
		var u = gr["u"]
		if u["kind"] != "squad" or not (u.get("order", "") in ["move", "patrol"]):
			continue
		var wp: Array = u.get("wp", [])
		if wp.is_empty():
			continue
		var there = 0
		var alive = 0
		for s in gr["members"]:
			if is_instance_valid(s) and s.state == "alive":
				alive += 1
				if G.dist2d(s.pos, wp[gr["wi"]]) < 7.0:
					there += 1
		if alive > 0 and there * 2 >= alive:
			if gr["wi"] < wp.size() - 1:
				gr["wi"] += 1
				_give_order(gr)
			elif u["order"] == "patrol":
				gr["wi"] = 0
				_give_order(gr)
	for i in range(triggers.size()):
		if fired.has(i):
			continue
		var tr = triggers[i]
		if _met(tr):
			fired[i] = true
			_fire(tr)

static func _met(tr: Dictionary) -> bool:
	var c = Vector3(tr.get("x", 0.0), 0, tr.get("z", 0.0))
	var r: float = tr.get("r", 12.0)
	var team: int = tr.get("team", 0)
	match tr.get("when", "time"):
		"time":
			return G.game_time >= tr.get("t", 60.0)
		"enter":
			for s in G.soldiers:
				if s.team == team and (s.state == "alive" or s.state == "riding") and G.dist2d(s.pos, c) < r:
					return true
			return false
		"clear":
			if G.game_time < 5.0:
				return false
			for s in G.soldiers:
				if s.team == team and s.state != "dead" and G.dist2d(s.pos, c) < r:
					return false
			return true
		"point":
			var pi = int(tr.get("pt", 0))
			return pi < Obj.points.size() and Obj.points[pi]["owner"] == team
		"losses":
			return losses[clampi(team, 0, 1)] >= int(tr.get("n", 10))
	return false

static func _fire(tr: Dictionary) -> void:
	var at = Vector3(tr.get("ax", tr.get("x", 0.0)), 0, tr.get("az", tr.get("z", 0.0)))
	at.y = G.world.ground_y(at.x, at.z)
	var team: int = tr.get("ateam", 0)
	var text: String = tr.get("text", "")
	match tr.get("then", "message"):
		"reinforce":
			var n = clampi(int(tr.get("n", 6)), 1, 20)
			var gr = {"u": {"kind": "squad", "team": team, "order": "free"}, "members": [], "veh": null, "wi": 0}
			for k in range(n):
				var q = G.main._free_spot(at + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)))
				var s = G.main.spawn_soldier(team, q.x, q.z, "")
				if s != null:
					gr["members"].append(s)
			groups.append(gr)
			G.ui.radio(team, text if text != "" else "Reinforcements have arrived")
		"vehicle":
			G.main.spawn_vehicle(tr.get("vtype", "tank"), team, at, atan2(G.world.capture.x - at.x, G.world.capture.z - at.z))
			G.ui.radio(team, text if text != "" else "Armour has arrived")
		"artillery":
			for k in range(10):
				Combat.shell_at(at, 14.0, 3.0 + k * randf_range(0.4, 0.9), null, 1.6)
			G.ui.message(text if text != "" else "Incoming artillery!")
		"airstrike":
			Support._air_strike(team, at)
			G.ui.message(text if text != "" else "Air strike inbound!")
		"smoke":
			for k in range(5):
				Combat.smoke_at(at + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8)), 40.0)
			if text != "":
				G.ui.message(text)
		"message":
			G.ui.message(text if text != "" else "...")
		"attack":
			for s in G.soldiers:
				if s.team == team and s.state == "alive" and not s.is_player:
					var a = float(s.id) * 2.39
					s.order = {"mode": "move", "point": at + Vector3(cos(a), 0, sin(a)) * 4.0}
					s.decide_t = 0.0
			G.ui.radio(team, text if text != "" else "All units, attack!")
		"win":
			if text != "":
				G.ui.message(text)
			G.main.end_game(team)

# a one-line description for the editor's labels
static func describe_trigger(tr: Dictionary) -> String:
	var tn = G.TEAM_NAMES[clampi(tr.get("team", 0), 0, 3)]
	var an = G.TEAM_NAMES[clampi(tr.get("ateam", 0), 0, 3)]
	var w = ""
	match tr.get("when", "time"):
		"time": w = "After %d s" % int(tr.get("t", 60.0))
		"enter": w = "If %s enters" % tn
		"clear": w = "When no %s left here" % tn
		"point": w = "When %s takes point %s" % [tn, "ABCDEFGH"[clampi(int(tr.get("pt", 0)), 0, 7)]]
		"losses": w = "When %s has lost %d" % [tn, int(tr.get("n", 10))]
	var t = ""
	match tr.get("then", "message"):
		"reinforce": t = "%d %s reinforcements" % [int(tr.get("n", 6)), an]
		"vehicle": t = "%s %s arrives" % [an, tr.get("vtype", "tank")]
		"artillery": t = "artillery"
		"airstrike": t = "%s air strike" % an
		"smoke": t = "smoke screen"
		"message": t = "\"%s\"" % tr.get("text", "")
		"attack": t = "%s attacks" % an
		"win": t = "%s wins" % an
	return "%s → %s" % [w, t]

static func describe_unit(u: Dictionary) -> String:
	var name = ("%d men" % int(u.get("size", 6))) if u["kind"] == "squad" else u.get("vtype", "jeep")
	var oi = ORDERS.find(u.get("order", "free"))
	return "%s %s · %s%s" % [G.TEAM_NAMES[u["team"]], name, ORDER_NAMES[maxi(0, oi)].to_lower(), (" (%d wp)" % u.get("wp", []).size()) if not u.get("wp", []).is_empty() else ""]
