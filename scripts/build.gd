class_name Build
extends RefCounted
# Things soldiers build during a battle. A structure starts as a marked-out site with a scaffold
# and goes up piece by piece while engineers (and anyone else nearby with a spare moment) work on
# it. Finished structures do something for their team, and everything can be shot, blown up or
# dismantled. Each team's HQ and FOBs are where its reinforcements come in: lose them all and,
# in the modes that use bases, nobody new arrives until the team builds another FOB.

const KINDS = {
	"hq": {"name": "HQ", "work": 144.0, "size": Vector2(16, 12)},
	"fob": {"name": "FOB", "work": 72.0, "size": Vector2(11, 10)},
	"sandbags": {"name": "Sandbag wall", "work": 9.6, "size": Vector2(3.4, 1.2)},
	"wire": {"name": "Barbed wire", "work": 8.0, "size": Vector2(6, 1.2)},
	"traps": {"name": "Tank traps", "work": 14.4, "size": Vector2(8, 2)},
	"mgnest": {"name": "MG nest", "work": 22.4, "size": Vector2(4, 4)},
	"mortarpit": {"name": "Mortar pit", "work": 22.4, "size": Vector2(3.6, 3.6)},
	"tower": {"name": "Watchtower", "work": 38.4, "size": Vector2(3.6, 3.6)},
	"bunker": {"name": "Bunker", "work": 64.0, "size": Vector2(7.5, 6.5)},
	"hospital": {"name": "Field hospital", "work": 41.6, "size": Vector2(9, 6.5)},
	"radio": {"name": "Radio mast", "work": 28.8, "size": Vector2(4.5, 4.5)},
	"depot": {"name": "Vehicle depot", "work": 57.6, "size": Vector2(11, 9)},
	"aa": {"name": "AA gun", "work": 24.0, "size": Vector2(4.6, 4.6)},
	"concrete": {"name": "Concrete wall", "work": 22.0, "size": Vector2(3.6, 1.2)},
	"pillbox": {"name": "Pillbox", "work": 40.0, "size": Vector2(4.6, 4.6)},
	"fob2": {"name": "FOB (hut)", "work": 60.0, "size": Vector2(11, 10)},
	"supply": {"name": "Supply dump", "work": 25.6, "size": Vector2(6.5, 5.5)},
}
const ORDER = ["fob", "sandbags", "wire", "traps", "mgnest", "mortarpit", "aa", "tower", "bunker", "hospital", "radio", "depot", "supply"]
# what an AI team adds around a finished FOB, in order: [kind, sideways, forward]
const FOB_PLAN = [["mgnest", 0.0, 13.0], ["sandbags", -6.0, 10.0], ["sandbags", 6.0, 10.0], ["hospital", -11.0, -6.0],
	["supply", 11.0, -5.0], ["radio", -12.0, 5.0], ["mortarpit", 6.0, -12.0], ["tower", 12.0, 7.0], ["wire", 0.0, 20.0],
	["traps", -12.0, 19.0], ["bunker", 0.0, 0.0], ["aa", -8.0, -16.0], ["depot", 0.0, -22.0]]

# what each structure can be upgraded into
const UPGRADES = {"sandbags": "concrete", "mgnest": "pillbox", "fob": "fob2"}
const DEPOT_COST = {"jeep": 6, "truck": 6, "halftrack": 12, "armoredcar": 16}
const DEPOT_TIME = {"jeep": 35.0, "truck": 40.0, "halftrack": 60.0, "armoredcar": 75.0}
const CANVAS = Color(0.52, 0.5, 0.38)
const WOODC = Color(0.45, 0.35, 0.23)
const CONCRETE = Color(0.56, 0.56, 0.53)
const METALC = Color(0.24, 0.25, 0.24)
const CRATE = Color(0.3, 0.33, 0.2)

static var sites: Array = []
static var tick = 0.0
static var ai_t: Array = []
static var no_spawn_said: Array = []
static var out: Array = []        # teams knocked out (no base, nobody left)
static var depot_t = {}

static func reset() -> void:
	for st in sites:
		if is_instance_valid(st["root"]):
			st["root"].queue_free()
	sites = []
	tick = 0.0
	ai_t = []
	no_spawn_said = []
	out = []
	depot_t = {}
	for t in range(G.team_count()):
		ai_t.append(randf_range(8.0, 14.0))
		no_spawn_said.append(false)
		out.append(false)

# what a structure costs in commander mode (supply points)
const COSTS = {"fob": 24, "sandbags": 2, "wire": 2, "traps": 3, "mgnest": 8, "mortarpit": 10, "aa": 10, "tower": 6, "bunker": 14,
	"hospital": 12, "radio": 10, "depot": 16, "supply": 8}

static func cost(kind: String) -> int:
	return COSTS.get(kind, 0) if G.mode == "commander" else 0

# a see-through blueprint of a structure for placing it: same pieces as the real thing, no colliders
static var ghost_mats = {}
static func ghost(kind: String, p: Vector3, front: Vector3) -> Node3D:
	var f = G.flat(front).normalized()
	if f.length_squared() < 0.01:
		f = Vector3(1, 0, 0)
	var ax = absf(f.z) >= absf(f.x)
	var fs = signf(f.z) if ax else signf(f.x)
	var root = Node3D.new()
	G.world.geo_root.add_child(root)
	var st = {"kind": kind, "team": 0, "p": Vector3(p.x, G.world.ground_y(p.x, p.z), p.z), "ax": ax, "fs": fs,
		"work": 0.0, "need": 1.0, "done": false, "born": 0.0, "dead": false, "root": root, "parts": [], "cols": [],
		"hidden": [], "shown": 0, "scaf": null, "label": null, "veh": null, "player": true, "t": 0.0, "ammo": null, "name": "", "pct": -1}
	var keep_piece = G.world.piece
	G.world.edit_node = root
	G.world.dyn_mode = false
	G.world.piece = null
	match kind:
		"fob": _geo_fob(st)
		"sandbags": _geo_sandbags(st)
		"wire": _geo_wire(st)
		"traps": _geo_traps(st)
		"mgnest": _geo_mgnest(st)
		"mortarpit": _geo_mortarpit(st)
		"tower": _geo_tower(st)
		"bunker": _geo_bunker(st)
		"hospital": _geo_hospital(st)
		"radio": _geo_radio(st)
		"depot": _geo_depot(st)
		"supply": _geo_supply(st)
		"aa": _geo_aa(st)
	G.world.edit_node = null
	G.world.piece = keep_piece
	# the outline of its footprint and an arrow out of the front
	var sz: Vector2 = KINDS[kind]["size"]
	var fw = Vector3(0, 0, fs) if ax else Vector3(fs, 0, 0)
	var half_len = (sz.y if true else sz.x) * 0.5
	var foot = MeshInstance3D.new()
	var fm = BoxMesh.new()
	fm.size = Vector3(sz.x, 0.06, sz.y) if ax else Vector3(sz.y, 0.06, sz.x)
	foot.mesh = fm
	foot.position = st["p"] + Vector3(0, 0.08, 0)
	foot.set_meta("ghost_foot", true)
	root.add_child(foot)
	var arrow = Node3D.new()
	var shaft = MeshInstance3D.new()
	var sm = BoxMesh.new()
	sm.size = Vector3(0.5, 0.12, 2.6)
	shaft.mesh = sm
	shaft.position = Vector3(0, 0, 1.3)
	arrow.add_child(shaft)
	var head = MeshInstance3D.new()
	var hm = PrismMesh.new()
	hm.size = Vector3(1.6, 1.6, 0.12)
	head.mesh = hm
	head.rotation = Vector3(PI / 2.0, 0, 0)
	head.position = Vector3(0, 0, 3.2)
	arrow.add_child(head)
	arrow.set_meta("ghost_arrow", true)
	root.add_child(arrow)
	arrow.position = st["p"] + fw * (half_len + 0.6) + Vector3(0, 0.3, 0)
	arrow.rotation.y = atan2(fw.x, fw.z)
	return root

# tint a blueprint: blue-green when it fits, red when it doesn't
static func ghost_tint(root: Node3D, ok: bool) -> void:
	var key = "ok" if ok else "bad"
	if not ghost_mats.has(key):
		var m = StandardMaterial3D.new()
		m.albedo_color = Color(0.35, 0.85, 1.0, 0.38) if ok else Color(1.0, 0.3, 0.25, 0.42)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		ghost_mats[key] = m
		var a = StandardMaterial3D.new()
		a.albedo_color = Color(1.0, 0.85, 0.2) if ok else Color(1.0, 0.45, 0.3)
		a.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		a.no_depth_test = true
		ghost_mats[key + "_arrow"] = a
	_tint_all(root, ghost_mats[key], ghost_mats[key + "_arrow"])

static func _tint_all(n: Node, m: Material, am: Material) -> void:
	for ch in n.get_children():
		if ch is MeshInstance3D:
			ch.material_override = am if (n.has_meta("ghost_arrow") or ch.has_meta("ghost_foot")) else m
			ch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_tint_all(ch, m, am)

# modes where reinforcements need a base to arrive at
static func bases_matter() -> bool:
	return G.reinforce and G.mode in ["deathmatch", "capture", "frontline", "assault", "destroy", "breakthrough", "siege"]

# ---------------------------------------------------------------- placing and building
static func place(kind: String, team: int, p: Vector3, front: Vector3, instant: bool = false, player: bool = false):
	var f = G.flat(front)
	if f.length_squared() < 0.01:
		f = Vector3(0, 0, 1)
	f = f.normalized()
	# structures are axis-aligned: pick the axis the front faces along
	var ax = absf(f.z) >= absf(f.x)          # true: front is +-z, length runs along x
	var fs = signf(f.z) if ax else signf(f.x)
	var root = Node3D.new()
	G.world.geo_root.add_child(root)
	var st = {"kind": kind, "team": team, "p": Vector3(p.x, G.world.ground_y(p.x, p.z), p.z), "ax": ax, "fs": fs,
		"work": 0.0, "need": KINDS[kind]["work"], "done": false, "born": G.sim_time, "dead": false, "root": root, "parts": [], "cols": [],
		"hidden": [], "shown": 0, "scaf": null, "label": null, "veh": null, "player": player, "t": randf(), "ammo": null,
		"name": KINDS[kind]["name"], "pct": -1}
	var before = G.world.cols.size()
	G.world.edit_node = root
	G.world.dyn_mode = true
	G.world.piece = null
	match kind:
		"hq": _geo_hq(st)
		"fob": _geo_fob(st)
		"sandbags": _geo_sandbags(st)
		"wire": _geo_wire(st)
		"traps": _geo_traps(st)
		"mgnest": _geo_mgnest(st)
		"mortarpit": _geo_mortarpit(st)
		"tower": _geo_tower(st)
		"bunker": _geo_bunker(st)
		"hospital": _geo_hospital(st)
		"radio": _geo_radio(st)
		"depot": _geo_depot(st)
		"supply": _geo_supply(st)
		"aa": _geo_aa(st)
		"concrete": _geo_concrete(st)
		"pillbox": _geo_pillbox(st)
		"fob2": _geo_fob2(st)
	G.world.edit_node = null
	G.world.dyn_mode = false
	for i in range(before, G.world.cols.size()):
		var c = G.world.cols[i]
		c.dest = true
		# headquarters and bunkers are built to take a pounding (but can be blown up when that's the point)
		if kind == "hq":
			c.hp = maxf(c.hp, 650.0 if G.mode == "destroy" else 1500.0)
		elif kind == "bunker":
			c.hp = maxf(c.hp, 900.0)
		elif kind == "fob":
			c.hp = maxf(c.hp, 600.0)
		elif kind == "fob2" or kind == "concrete" or kind == "pillbox":
			c.hp = maxf(c.hp, 900.0)
		st["cols"].append(c)
	var parts = []
	for ch in root.get_children():
		if ch is MeshInstance3D:
			parts.append(ch)
	parts.sort_custom(func(a, b): return a.position.y - absf(a.scale.y) * 0.5 < b.position.y - absf(b.scale.y) * 0.5)
	st["parts"] = parts
	sites.append(st)
	if instant:
		for c in st["cols"]:
			G.world.gen_cover_for(c)
			G.world.update_nav_area(c.lo.x, c.lo.z, c.hi.x, c.hi.z)
		st["work"] = st["need"]
		st["shown"] = parts.size()
		_complete(st, true)
		return st
	# take everything out of the world until it's built
	for c in st["cols"]:
		G.world.cols.erase(c)
		G.world._remove_grid(c)
		if is_instance_valid(c.body):
			c.body.collision_layer = 0
		st["hidden"].append(c)
	for m in parts:
		m.visible = false
	_scaffold(st)
	return st

static func _scaffold(st: Dictionary) -> void:
	var sz: Vector2 = KINDS[st["kind"]]["size"]
	var n = Node3D.new()
	st["root"].add_child(n)
	st["scaf"] = n
	var hw = sz.x * 0.5
	var hd = sz.y * 0.5
	var pole = WOODC.lightened(0.15)
	var corners = [Vector2(-hw, -hd), Vector2(hw, -hd), Vector2(hw, hd), Vector2(-hw, hd)]
	var ph = 1.2 if sz.x < 5.0 else 2.2
	for c in corners:
		var w = _w(st, c.x, c.y)
		var mi = MeshInstance3D.new()
		mi.mesh = VModel.cyl_mesh(0.05, ph, -1.0, 6)
		mi.material_override = VModel.mat(pole)
		mi.position = Vector3(w.x, G.world.ground_y(w.x, w.y) + ph * 0.5, w.y)
		n.add_child(mi)
	# a taped-off outline
	for i in range(4):
		var a = _w(st, corners[i].x, corners[i].y)
		var b = _w(st, corners[(i + 1) % 4].x, corners[(i + 1) % 4].y)
		var mid = (a + b) * 0.5
		var tape = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(0.02, 0.03, a.distance_to(b))
		tape.mesh = bm
		tape.material_override = VModel.mat(Color(0.9, 0.75, 0.15))
		tape.position = Vector3(mid.x, G.world.ground_y(mid.x, mid.y) + 0.8, mid.y)
		tape.rotation.y = atan2(b.x - a.x, b.y - a.y)
		n.add_child(tape)
	var stake = _w(st, -hw, -hd)
	var flag = MeshInstance3D.new()
	var fm = BoxMesh.new()
	fm.size = Vector3(0.5, 0.32, 0.03)
	flag.mesh = fm
	flag.material_override = VModel.mat(G.team_color(st["team"]))
	flag.position = Vector3(stake.x + 0.28, G.world.ground_y(stake.x, stake.y) + ph - 0.2, stake.y)
	n.add_child(flag)
	var lb = Label3D.new()
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.font_size = 40
	lb.pixel_size = 0.012
	lb.outline_size = 8
	lb.modulate = G.team_color(st["team"]).lightened(0.3)
	lb.no_depth_test = false
	lb.visibility_range_end = 90.0
	lb.position = st["p"] + Vector3(0, ph + 1.4, 0)
	lb.text = "%s  0%%" % st["name"]
	st["root"].add_child(lb)
	st["label"] = lb

# adds building effort; returns true while there's still work to do
static func add_work(st: Dictionary, amt: float) -> bool:
	if st["done"] or st["dead"]:
		return false
	st["work"] += amt
	var frac = clampf(st["work"] / st["need"], 0.0, 1.0)
	var want = ceili(frac * st["parts"].size())
	while st["shown"] < want:
		var m: MeshInstance3D = st["parts"][st["shown"]]
		st["shown"] += 1
		if is_instance_valid(m):
			m.visible = true
			if randf() < 0.25:
				G.fx.dust_cloud(m.global_position, 0.8)
		_reveal_cols(st, m)
	var pct = int(frac * 100.0)
	if pct != st["pct"] and is_instance_valid(st["label"]):
		st["pct"] = pct
		st["label"].text = "%s  %d%%" % [st["name"], pct]
	if frac >= 1.0:
		_complete(st, false)
		return false
	return true

static func _reveal_cols(st: Dictionary, m: MeshInstance3D) -> void:
	for c in st["hidden"].duplicate():
		var ready_ = true
		for r in c.vis:
			if r[1] == -2 and is_instance_valid(r[0]) and not r[0].visible:
				ready_ = false
				break
		if not ready_:
			continue
		st["hidden"].erase(c)
		if not c.alive:
			continue
		G.world.cols.append(c)
		G.world._insert_grid(c)
		if is_instance_valid(c.body):
			c.body.collision_layer = G.L_WORLD
		G.world.gen_cover_for(c)
		G.world.update_nav_area(c.lo.x, c.lo.z, c.hi.x, c.hi.z)
		# anyone standing in it steps out of the way
		var mid = (c.lo + c.hi) * 0.5
		for s in G.soldiers:
			if s.state == "alive" and s.pos.x > c.lo.x - 0.3 and s.pos.x < c.hi.x + 0.3 and s.pos.z > c.lo.z - 0.3 and s.pos.z < c.hi.z + 0.3 and s.pos.y < c.hi.y:
				var away = G.flat(s.pos - mid)
				if away.length_squared() < 0.01:
					away = Vector3(1, 0, 0)
				s.push(0, away.normalized() * 2.0 + Vector3(0, 1, 0), 0.2)

static func _complete(st: Dictionary, quiet: bool) -> void:
	st["done"] = true
	if G.mode == "commander" and st["team"] == 0 and G.ui != null and G.ui.has_method("_render_tools"):
		G.ui.call_deferred("_render_tools")
	for c in st["hidden"].duplicate():
		st["hidden"].erase(c)
		if c.alive:
			G.world.cols.append(c)
			G.world._insert_grid(c)
			if is_instance_valid(c.body):
				c.body.collision_layer = G.L_WORLD
			G.world.gen_cover_for(c)
			G.world.update_nav_area(c.lo.x, c.lo.z, c.hi.x, c.hi.z)
	for m in st["parts"]:
		if is_instance_valid(m):
			m.visible = true
	if st["scaf"] != null and is_instance_valid(st["scaf"]):
		st["scaf"].queue_free()
	if st["label"] != null and is_instance_valid(st["label"]):
		st["label"].queue_free()
	var t: int = st["team"]
	match st["kind"]:
		"fob", "fob2", "supply", "hq":
			var a = _wv(st, 2.6 if st["kind"] in ["fob", "fob2"] else 0.0, 1.5 if st["kind"] in ["fob", "fob2"] else 0.0)
			# only HQ never runs dry; FOBs and dumps start with what the builders brought and rely on supply trucks
			st["ammo"] = {"p": a, "team": t, "stock": 60.0 if st["kind"] != "hq" else 1e9, "site": st}
			G.world.ammo_points.append(st["ammo"])
		"mgnest", "mortarpit", "aa", "pillbox":
			VModel.bare = true
			var yaw = atan2(_front(st).x, _front(st).z)
			st["veh"] = G.main.spawn_vehicle({"mgnest": "nest", "mortarpit": "mortar", "aa": "aagun", "pillbox": "nest"}[st["kind"]], t, st["p"], yaw, false)
			VModel.bare = false
	if st.get("camo_wanted", false):
		add_camo(st)
	if t < no_spawn_said.size():
		no_spawn_said[t] = false
	if not quiet:
		G.ui.radio(t, "%s built at %s" % [st["name"], AI.grid_ref(st["p"])])

static func alive(st: Dictionary) -> bool:
	return st["done"] and not st["dead"]

# a finished structure counts as lost once most of it is gone
static func _check_alive(st: Dictionary) -> void:
	if not st["done"] or st["dead"]:
		return
	var n = st["cols"].size()
	if n == 0:
		return
	var left = 0
	for c in st["cols"]:
		if c.alive:
			left += 1
	var keep = {"hq": 0.5 if G.mode == "destroy" else 0.3, "fob": 0.4, "fob2": 0.4}.get(st["kind"], 0.35)
	if float(left) / n < keep:
		_lose(st, true)

static func _lose(st: Dictionary, loud: bool) -> void:
	st["dead"] = true
	if st["ammo"] != null:
		G.world.ammo_points.erase(st["ammo"])
		st["ammo"] = null
	if loud and st["kind"] in ["hq", "fob", "fob2", "hospital", "radio", "depot", "bunker", "tower"]:
		G.ui.radio(st["team"], "%s at %s has been destroyed!" % [st["name"], AI.grid_ref(st["p"])])
		for t in range(G.team_count()):
			if t != st["team"] and st["kind"] in ["hq", "fob", "fob2"]:
				G.ui.radio(t, "Enemy %s destroyed" % st["name"])

# replace a finished structure with its stronger version, built up on the same spot
static func upgrade(st: Dictionary):
	if not UPGRADES.has(st["kind"]) or not st["done"] or st["dead"]:
		return null
	var nk: String = UPGRADES[st["kind"]]
	var p: Vector3 = st["p"]
	var fw = _front(st)
	var team: int = st["team"]
	var camo = st.get("camo", false)
	_remove_quietly(st)
	var plans = {}
	for k in st.keys():
		if str(k).begins_with("plan_"):
			plans[k] = true
	var ns = place(nk, team, p, fw)
	ns.merge(plans)
	if camo:
		ns["camo_wanted"] = true
	G.ui.radio(team, "Upgrading the %s to a %s" % [KINDS[UPGRADES.keys()[UPGRADES.values().find(nk)]]["name"], KINDS[nk]["name"]])
	return ns

static func _remove_quietly(st: Dictionary) -> void:
	if st["ammo"] != null:
		G.world.ammo_points.erase(st["ammo"])
	for c in st["cols"]:
		if c.alive:
			c.alive = false
			G.world.cols.erase(c)
			G.world._remove_grid(c)
			if is_instance_valid(c.body):
				c.body.queue_free()
			G.world.update_nav_area(c.lo.x, c.lo.z, c.hi.x, c.hi.z)
	if st["veh"] != null and is_instance_valid(st["veh"]):
		st["veh"].remove()
	if is_instance_valid(st["root"]):
		st["root"].queue_free()
	sites.erase(st)

# a damaged or wrecked structure is rebuilt in place (engineers do the work)
static func needs_repair(st: Dictionary) -> bool:
	if not st["done"]:
		return false
	var lost = 0
	for c in st["cols"]:
		if not c.alive:
			lost += 1
	return st["dead"] or (st["cols"].size() > 0 and float(lost) / st["cols"].size() > 0.25)

static func rebuild(st: Dictionary):
	var kind: String = st["kind"]
	var p: Vector3 = st["p"]
	var fw = _front(st)
	var team: int = st["team"]
	var camo = st.get("camo", false)
	_remove_quietly(st)
	var plans = {}
	for k in st.keys():
		if str(k).begins_with("plan_"):
			plans[k] = true
	var ns = place(kind, team, p, fw)
	ns.merge(plans)
	ns["work"] = ns["need"] * 0.4        # the foundations are still there
	if camo:
		ns["camo_wanted"] = true
	return ns

# throw a camouflage net over a structure
static func add_camo(st: Dictionary) -> void:
	if st.get("camo", false) or not is_instance_valid(st["root"]):
		return
	st["camo"] = true
	var sz: Vector2 = KINDS[st["kind"]]["size"]
	var net = Node3D.new()
	st["root"].add_child(net)
	var h = 3.2 if st["kind"] in ["fob", "fob2", "depot", "hospital", "supply"] else 2.2
	var w = (sz.x if st["ax"] else sz.y) + 1.0
	var d = (sz.y if st["ax"] else sz.x) + 1.0
	# one net draped over poles at the corners, sagging between them
	var stt = SurfaceTool.new()
	stt.begin(Mesh.PRIMITIVE_TRIANGLES)
	var N = 10
	var gy0 = G.world.ground_y(st["p"].x, st["p"].z)
	for i in range(N):
		for j in range(N):
			var quad = [[i, j], [i + 1, j], [i + 1, j + 1], [i, j], [i + 1, j + 1], [i, j + 1]]
			for q in quad:
				var u = float(q[0]) / N
				var v2 = float(q[1]) / N
				var x = -w / 2.0 + u * w
				var z = -d / 2.0 + v2 * d
				var sag = 0.55 * sin(u * PI) * sin(v2 * PI) + 0.25 * (sin(u * PI) + sin(v2 * PI)) * 0.5
				var gx = G.world.ground_y(st["p"].x + x, st["p"].z + z)
				var y = maxf(gx + 0.6, gy0 + h - sag + 0.08 * sin(u * 23.0 + v2 * 17.0))
				stt.set_uv(Vector2(u * w * 0.5, v2 * d * 0.5))
				stt.add_vertex(Vector3(st["p"].x + x, y, st["p"].z + z))
	stt.generate_normals()
	var nm = MeshInstance3D.new()
	nm.mesh = stt.commit()
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = Tex.net()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1.0
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	nm.material_override = mat
	nm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	net.add_child(nm)
	net.top_level = true
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			var pole = MeshInstance3D.new()
			pole.mesh = VModel.cyl_mesh(0.05, h, -1.0, 6)
			pole.material_override = VModel.mat(WOODC)
			var px = st["p"].x + cx * w / 2.0
			var pz = st["p"].z + cz * d / 2.0
			pole.position = Vector3(px, G.world.ground_y(px, pz) + h / 2.0, pz)
			net.add_child(pole)

# take a structure apart (the player's dismantle tool)
static func dismantle(st: Dictionary) -> void:
	if not st["dead"]:
		_lose(st, false)
	for c in st["cols"]:
		if c.alive:
			if st["hidden"].has(c):
				c.alive = false
				if is_instance_valid(c.body):
					c.body.queue_free()
			else:
				G.world.destroy_col(c)
	if st["veh"] != null and is_instance_valid(st["veh"]):
		st["veh"].remove()
	G.fx.dust_cloud(st["p"] + Vector3(0, 1, 0), KINDS[st["kind"]]["size"].x * 0.6)
	if is_instance_valid(st["root"]):
		st["root"].queue_free()
	sites.erase(st)

static func site_at(p: Vector3, pad: float = 0.5):
	var best = null
	var bd = 1e9
	for st in sites:
		var sz: Vector2 = KINDS[st["kind"]]["size"]
		var r = maxf(sz.x, sz.y) * 0.5 + pad
		var d = G.dist2d(st["p"], p)
		if d < r and d < bd:
			bd = d
			best = st
	return best

# nearest unfinished friendly site
static func work_site(team: int, from: Vector3, max_d: float):
	var best = null
	var bd = max_d
	for st in sites:
		if st["team"] == team and not st["done"] and not st["dead"]:
			var d = G.dist2d(st["p"], from) * (0.6 if is_fob(st) else 1.0)
			if d < bd:
				bd = d
				best = st
	return best

static func build_radius(st: Dictionary) -> float:
	var sz: Vector2 = KINDS[st["kind"]]["size"]
	return maxf(sz.x, sz.y) * 0.5 + 1.2

# a spot just outside a site to work from
static func work_spot(st: Dictionary, s) -> Vector3:
	var d = G.flat(s.pos - st["p"])
	if d.length_squared() < 0.01:
		d = Vector3(1, 0, 0)
	var sz: Vector2 = KINDS[st["kind"]]["size"]
	return st["p"] + d.normalized() * (minf(sz.x, sz.y) * 0.5 + 0.8)

# an enemy structure close by, for sappers and artillery: [site, aim point] or null
# a camouflaged structure only shows up once enemy soldiers get close to it on the ground
static func spotted(st: Dictionary, by_team: int) -> bool:
	if not st.get("camo", false):
		return true
	for s in G.soldiers:
		if s.team == by_team and s.state == "alive" and s.vehicle == null and G.dist2d(s.pos, st["p"]) < 35.0:
			return true
	return false

static func enemy_site_near(team: int, from: Vector3, max_d: float, need_spot: bool = false):
	var best = null
	var bd = max_d
	for st in sites:
		if st["team"] == team or st["dead"] or (not st["done"] and st["shown"] == 0):
			continue
		if need_spot and not spotted(st, team):
			continue
		var d = G.dist2d(st["p"], from)
		if d < bd:
			bd = d
			best = st
	if best == null:
		return null
	return [best, best["p"] + Vector3(0, 0.5, 0)]

# can someone at `from` see this structure (hitting the structure itself counts)?
static func sees(from: Vector3, st: Dictionary) -> bool:
	var to: Vector3 = st["p"] + Vector3(0, 1.0, 0)
	var hit = G.ray(from, to, G.L_WORLD)
	return hit.is_empty() or G.dist2d(hit.position, st["p"]) < build_radius(st) + 0.5

static func helpers(st: Dictionary) -> int:
	var n = 0
	for s in G.soldiers:
		if s.build_site == st and s.task == "construct" and s.state == "alive":
			n += 1
	return n

# ---------------------------------------------------------------- bases and respawning
static func is_fob(st: Dictionary) -> bool:
	return st["kind"] == "fob" or st["kind"] == "fob2"

static func fobs(team: int) -> Array:
	return sites.filter(func(st): return st["team"] == team and is_fob(st) and alive(st))

static func hq(team: int):
	for st in sites:
		if st["team"] == team and st["kind"] == "hq":
			return st
	return null

static func hq_alive(team: int) -> bool:
	var h = hq(team)
	return h == null or alive(h)      # maps without an HQ never lose it

# where a team's new soldiers come in: its HQ, or failing that its most forward FOB
static func spawn_pos(team: int):
	if hq_alive(team):
		return G.world.spawn[team]
	var fl = fobs(team)
	if fl.is_empty():
		return null
	var obj = _objective(team)
	fl.sort_custom(func(a, b): return G.dist2d(a["p"], obj) < G.dist2d(b["p"], obj))
	return fl[0]["p"] - _front(fl[0]) * 7.0

static func can_respawn(team: int) -> bool:
	if not bases_matter():
		return true
	return spawn_pos(team) != null

# the forward FOB trucks should drive to, if it's ahead of the usual rally point
static func forward_fob(team: int, rally: Vector3):
	var obj = _objective(team)
	var best = null
	var bd = G.dist2d(rally, obj) - 5.0
	for st in fobs(team):
		var d = G.dist2d(st["p"], obj)
		if d < bd:
			bd = d
			best = st
	if best == null and not hq_alive(team):
		var fl = fobs(team)
		if not fl.is_empty():
			best = fl[0]
	return best["p"] - _front(best) * 7.0 if best != null else null

static func _objective(team: int) -> Vector3:
	if not Obj.points.is_empty():
		var f = Obj.front(team) if Obj.chain() else 0
		if f >= 0 and f < Obj.points.size():
			return Obj.points[f]["p"]
	var ec = Commander._enemy_center(team)
	if ec != null:
		return ec
	var o = (team + 1) % G.team_count()
	return G.world.spawn[o] if o < G.world.spawn.size() else Vector3.ZERO

static func _front(st: Dictionary) -> Vector3:
	return Vector3(0, 0, st["fs"]) if st["ax"] else Vector3(st["fs"], 0, 0)

# ---------------------------------------------------------------- every tick
static func step(dt: float) -> void:
	if sites.is_empty() and ai_t.is_empty():
		return
	tick += dt
	if tick < 0.5:
		return
	var tdt = tick
	tick = 0.0
	for st in sites.duplicate():
		_check_alive(st)
		if not st["done"] and not st["dead"]:
			_passive_work(st, tdt)
		elif alive(st):
			_effect(st, tdt)
	if G.over:
		return
	for t in range(ai_t.size()):
		ai_t[t] -= tdt
		if ai_t[t] <= 0.0:
			ai_t[t] = randf_range(9.0, 14.0)
			_ai_plan(t)
	_check_out()

# soldiers standing around a site lend a hand when nothing's going on
static func _passive_work(st: Dictionary, dt: float) -> void:
	var r = build_radius(st) + 1.0
	for s in G.soldiers:
		if s.team != st["team"] or s.state != "alive" or s == G.player or s.vis_t != null:
			continue
		if G.dist2d(s.pos, st["p"]) < r and s.want.length_squared() < 0.5 and s.task != "construct":
			add_work(st, dt * 0.3)

static func _effect(st: Dictionary, dt: float) -> void:
	var t: int = st["team"]
	st["t"] += dt
	match st["kind"]:
		"hospital":
			# each aid station keeps an ambulance running
			if G.sim_time - st.get("amb_t", -999.0) > 45.0:
				var have = false
				for v in G.vehicles:
					if v.kind == "ambulance" and v.team == t and not v.dead:
						have = true
				if not have:
					st["amb_t"] = G.sim_time
					var ap = G.main._free_spot(st["p"] + _front(st) * 8.0)
					G.main.spawn_vehicle("ambulance", t, ap, atan2(_front(st).x, _front(st).z), true)
			for s in G.soldiers:
				if s.team == t and s.state == "alive" and s.hp < 100.0 and G.dist2d(s.pos, st["p"]) < 10.0:
					s.hp = minf(100.0, s.hp + 4.0 * dt)
		"radio":
			if st["t"] > 8.0:
				st["t"] = 0.0
				Support.earn(t, 1)
		"tower":
			if st["t"] > 2.0:
				st["t"] = 0.0
				var eye = st["p"] + Vector3(0, 5.6, 0)
				var friend = null
				for s in G.soldiers:
					if s.team == t and s.state == "alive" and G.dist2d(s.pos, st["p"]) < 60.0:
						friend = s
						break
				if friend != null:
					for o in G.soldiers:
						if o.team != t and o.state != "dead" and G.dist2d(o.pos, st["p"]) < 80.0 and not G.blocked(eye, o.chest()):
							AI.share_intel(friend, o, o.pos)
		"depot":
			# vehicles cost supply points and take time to put together
			if st.get("making", "") == "":
				if st["t"] > 20.0:
					st["t"] = 0.0
					var n = 0
					for v in G.vehicles:
						if v.team == t and not v.dead and not v.spec.get("static", false) and not v.spec.get("air", false):
							n += 1
					var kinds = ["jeep", "halftrack", "jeep", "armoredcar", "truck"] if G.armor != "none" else ["jeep", "truck"]
					var k: String = kinds[randi() % kinds.size()]
					var cost = DEPOT_COST.get(k, 10)
					if n < 3 and t < Support.points.size() and Support.points[t] >= cost:
						Support.points[t] -= cost
						st["making"] = k
						st["make_t"] = 0.0
						var lb = Label3D.new()
						lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
						lb.font_size = 36
						lb.pixel_size = 0.012
						lb.outline_size = 8
						lb.modulate = G.team_color(t).lightened(0.3)
						lb.visibility_range_end = 90.0
						lb.position = st["p"] + Vector3(0, 5.2, 0)
						st["root"].add_child(lb)
						st["make_lbl"] = lb
						G.ui.radio(t, "Depot: building a %s (%d supply)" % [Vehicle.SPECS[k]["name"].to_lower(), cost])
			else:
				st["make_t"] += dt
				var need = DEPOT_TIME.get(st["making"], 45.0)
				if is_instance_valid(st.get("make_lbl")):
					st["make_lbl"].text = "%s  %d%%" % [Vehicle.SPECS[st["making"]]["name"], int(100.0 * st["make_t"] / need)]
				if randf() < dt * 0.8:
					G.audio.hammer(st["p"])
				if st["make_t"] >= need:
					var k2: String = st["making"]
					st["making"] = ""
					st["t"] = 0.0
					if is_instance_valid(st.get("make_lbl")):
						st["make_lbl"].queue_free()
					var p = G.main._free_spot(st["p"] + _front(st) * 7.0)
					G.main.spawn_vehicle(k2, t, p, atan2(_front(st).x, _front(st).z), false)
					G.ui.radio(t, "Depot: a %s is ready for crew" % Vehicle.SPECS[k2]["name"].to_lower())
		"fob", "fob2", "hq", "supply":
			# FOBs and dumps running low call up a supply truck from HQ
			if st["kind"] != "hq" and st.get("ammo") != null and st["ammo"]["stock"] < 55.0:
				var tr = st.get("truck")
				if (tr == null or not is_instance_valid(tr) or tr.dead) and G.sim_time - st.get("truck_t", -999.0) > 60.0:
					st["truck_t"] = G.sim_time
					VehExt.supply_run(t, st)
			# top up grenades and engineer kits at the crates
			if st["t"] > 3.0:
				st["t"] = 0.0
				for s in G.soldiers:
					if s.team == t and s.state == "alive" and G.dist2d(s.pos, st["p"]) < 9.0:
						if s.cls == "engineer":
							s.kits = maxi(s.kits, 3)
							s.satchels = maxi(s.satchels, 1)

# in modes with bases, a team with no base and nobody left is out
static func _check_out() -> void:
	if not bases_matter() or G.over or G.mode == "destroy":
		return
	var left = []
	for t in range(G.team_count()):
		if out[t]:
			continue
		var has_base = can_respawn(t)
		if not has_base and not no_spawn_said[t]:
			no_spawn_said[t] = true
			G.ui.radio(t, "No HQ or FOB left: reinforcements can't reach us until we build a new FOB!")
		if not has_base and G.alive_count(t) == 0:
			out[t] = true
			G.ui.radio(t, "%s has been wiped out" % G.TEAM_NAMES[t])
			continue
		left.append(t)
	if left.size() == 1 and G.team_count() > 1 and out.count(true) > 0:
		G.main.end_game(left[0])

# ---------------------------------------------------------------- AI: what to build where
# what an AI side may build in each mode (the player can still mark out anything)
static func allowed(t: int) -> Array:
	match G.mode:
		"sandbox":
			return []
		"deathmatch":
			return ["sandbags"]
		"laststand":
			return ["sandbags", "wire", "traps", "mgnest"] if t == 0 else []
		"assault":
			if t == 0:
				return ["fob", "sandbags", "hospital", "supply", "radio", "mortarpit", "tower", "aa"]
			return ["sandbags", "wire", "traps", "mgnest", "bunker", "tower", "mortarpit", "aa"]
		"siege":
			if t == 0:
				return ["sandbags", "wire", "traps", "mgnest", "bunker", "hospital", "tower"]
			return ["fob", "sandbags", "mortarpit", "supply", "radio"]
		"breakthrough":
			if t == 1:
				return ["sandbags", "wire", "traps", "mgnest", "bunker", "tower"]
			return ["fob", "sandbags", "hospital", "supply", "mortarpit"]
		"sabotage":
			return []
		"horde":
			return ["sandbags", "wire", "traps", "mgnest", "tower", "hospital", "bunker"] if t == 0 else []
		"rescue", "escort":
			return ["fob", "sandbags", "hospital", "supply", "mgnest", "mortarpit"]
	return ORDER.duplicate()

# defenders dig in around the points they hold instead of setting up FOBs
const DEFENCE_PLAN = [["mgnest", 0.0, 9.0], ["sandbags", -5.0, 7.0], ["sandbags", 5.0, 7.0], ["wire", 0.0, 15.0], ["bunker", 0.0, -4.0],
	["traps", 9.0, 14.0], ["tower", -9.0, -6.0], ["mortarpit", 6.0, -10.0], ["aa", -6.0, -12.0]]

static func _ai_plan(t: int) -> void:
	if G.alive_count(t) == 0:
		return
	var ok = allowed(t)
	if ok.is_empty() or (ok.size() == 1 and ok[0] == "sandbags"):
		return
	if not ("fob" in ok):
		_ai_defend_plan(t, ok)
		return
	var mine = sites.filter(func(st): return st["team"] == t and not st["dead"])
	var unfinished = mine.filter(func(st): return not st["done"])
	if unfinished.size() >= 2:
		return
	var fl = mine.filter(func(st): return is_fob(st))
	var obj = _objective(t)
	var home: Vector3 = G.world.spawn[t]
	if fl.is_empty() or (fl.size() < 2 and fobs(t).size() == fl.size() and _all_done(fl) and G.sim_time > 200.0 and randf() < 0.3):
		# a FOB part way to the objective, out of the thick of it
		var to = G.flat(obj - home)
		var L = to.length()
		var at = home + to * (0.5 if L > 160.0 else 0.33) if L > 70.0 else home + to.normalized() * minf(L * 0.4, 25.0)
		if not hq_alive(t):
			at = home + to * 0.3
		if G.dist2d(at, obj) < 45.0 and L > 60.0:
			at = obj - to.normalized() * 45.0
		var spot = find_spot(at, "fob", 22.0, 14, false, t)
		if spot != null:
			place("fob", t, spot, to)
			G.ui.radio(t, "Engineers: setting up a FOB at %s" % AI.grid_ref(spot))
		return
	# rebuild what's been knocked about, net the important stuff, then upgrade
	for st in mine:
		if st["done"] and needs_repair(st) and st["kind"] != "hq" and randf() < 0.5:
			rebuild(st)
			G.ui.radio(t, "Engineers: rebuilding the %s at %s" % [st["name"], AI.grid_ref(st["p"])])
			return
	for st in mine:
		if st["done"] and not st["dead"] and not st.get("camo", false) and st["kind"] in ["fob", "fob2", "depot", "supply", "mortarpit", "aa"] and randf() < 0.4:
			add_camo(st)
			return
	# extras around a finished FOB
	for f in fl:
		if not f["done"]:
			continue
		var fw = _front(f)
		var side = Vector3(fw.z, 0, -fw.x)
		for item in FOB_PLAN:
			if not (item[0] in ok):
				continue
			var key = "%s_%d_%d" % [item[0], int(item[1]), int(item[2])]
			if f.has("plan_" + key):
				continue
			f["plan_" + key] = true
			var want = f["p"] + side * item[1] + fw * item[2]
			if item[0] == "bunker":
				if Obj.points.is_empty():
					continue
				want = _held_point(t)
				if want == null:
					continue
			if item[0] == "depot":
				if not hq_alive(t):
					continue
				want = home + G.flat(obj - home).normalized() * 12.0 + side * 14.0
			var spot = find_spot(want, item[0], 8.0, 14, false, t)
			if spot != null:
				place(item[0], t, spot, fw)
				return
	_ai_upgrade(t)

static func _ai_defend_plan(t: int, ok: Array) -> void:
	var held = []
	for pt in Obj.points:
		if pt["owner"] == t:
			held.append(pt)
	if held.is_empty():
		return
	var pt = held[randi() % held.size()]
	var ed = G.flat(Commander._enemy_center(t) - pt["p"]) if Commander._enemy_center(t) != null else G.flat(G.world.spawn[(t + 1) % G.team_count()] - pt["p"])
	if ed.length_squared() < 1.0:
		ed = Vector3(1, 0, 0)
	var fw = ed.normalized()
	var side = Vector3(fw.z, 0, -fw.x)
	if not pt.has("plan"):
		pt["plan"] = {}
	for item in DEFENCE_PLAN:
		if not (item[0] in ok):
			continue
		var key = "%s_%d_%d" % [item[0], int(item[1]), int(item[2])]
		if pt["plan"].has(key):
			continue
		pt["plan"][key] = true
		var spot = find_spot(pt["p"] + side * item[1] + fw * item[2], item[0], 5.0, 14, false, t)
		if spot != null:
			place(item[0], t, spot, fw)
			return

static func _ai_upgrade(t: int) -> bool:
	for st in sites:
		if st["team"] == t and st["done"] and not st["dead"] and UPGRADES.has(st["kind"]) and G.sim_time - st.get("born", 0.0) > 120.0 and randf() < 0.25:
			upgrade(st)
			return true
	return false

static func _all_done(a: Array) -> bool:
	for st in a:
		if not st["done"]:
			return false
	return true

static func _held_point(t: int):
	for pt in Obj.points:
		if pt["owner"] == t:
			var near = false
			for st in sites:
				if st["kind"] == "bunker" and st["team"] == t and G.dist2d(st["p"], pt["p"]) < 25.0:
					near = true
			if not near:
				var back = G.flat(G.world.spawn[t] - pt["p"]).normalized()
				return pt["p"] + back * 9.0
	return null

# somewhere flat and empty for a structure, near a wanted spot
static func find_spot(want: Vector3, kind: String, spread: float, tries: int = 14, relaxed: bool = false, team: int = -1):
	var sz: Vector2 = KINDS[kind]["size"]
	var r = maxf(sz.x, sz.y) * 0.5
	var b: Rect2 = G.world.bounds
	# where the enemy will be looking from
	var eye = null
	if team >= 0:
		eye = Commander._enemy_center(team)
		if eye == null:
			eye = G.world.spawn[(team + 1) % G.team_count()]
	var best = null
	var bs = 1e9
	var found = 0
	for k in range(tries + (6 if team >= 0 else 0)):
		var p = want if k == 0 else want + Vector3(randf_range(-spread, spread), 0, randf_range(-spread, spread))
		if p.x < b.position.x + r + 3.0 or p.x > b.end.x - r - 3.0 or p.z < b.position.y + r + 3.0 or p.z > b.end.y - r - 3.0:
			continue
		if not clear_at(p, kind, relaxed):
			continue
		var gp = Vector3(p.x, G.world.ground_y(p.x, p.z), p.z)
		if team < 0:
			return gp
		found += 1
		# out of the enemy's sight, tucked in among cover, not too far from where it's wanted
		var sc = G.dist2d(gp, want) * 0.2
		if not G.blocked(eye + Vector3(0, 1.6, 0), gp + Vector3(0, 1.5, 0)):
			sc += 6.0 if kind in ["fob", "fob2", "hospital", "depot", "supply", "radio", "aa", "mortarpit"] else 2.0
		var near = 0
		for c in G.world.cols_in_rect(gp.x - 12.0, gp.z - 12.0, gp.x + 12.0, gp.z + 12.0):
			if c.hi.y - c.gy > 1.2:
				near += 1
		sc -= minf(near, 8) * 0.5
		if kind in ["fob", "fob2", "hospital", "depot", "supply", "radio"]:
			sc -= minf(G.dist2d(gp, eye), 200.0) * 0.015
		if sc < bs:
			bs = sc
			best = gp
		if found >= 8:
			break
	return best

static func clear_at(p: Vector3, kind: String, relaxed: bool = false) -> bool:
	var sz: Vector2 = KINDS[kind]["size"]
	var hw = sz.x * 0.5 + 0.5
	var hd = sz.y * 0.5 + 0.5
	var r = maxf(hw, hd)
	var g0 = G.world.ground_y(p.x, p.z)
	for ix in range(-2, 3):
		for iz in range(-2, 3):
			var x = p.x + ix * r * 0.5
			var z = p.z + iz * r * 0.5
			if G.world.inside_any(x, z, 0.4) or G.world.in_water(x, z) or (G.world.on_road(x, z) and not relaxed):
				return false
			if absf(G.world.ground_y(x, z) - g0) > (1.6 if not relaxed else 2.6):
				return false
	for st in sites:
		var s2: Vector2 = KINDS[st["kind"]]["size"]
		if G.dist2d(st["p"], p) < r + maxf(s2.x, s2.y) * 0.5 + 1.0:
			return false
	for pt in Obj.points:
		if G.dist2d(pt["p"], p) < 6.0 + r:
			return false
	for v in G.vehicles:
		if not v.dead and G.dist2d(v.pos, p) < r + 3.0:
			return false
	return true

# every team gets an HQ at its base when the battle starts
static func setup_bases() -> void:
	for t in range(G.team_count()):
		if t >= G.world.spawn.size():
			continue
		var home: Vector3 = G.world.spawn[t]
		var to = G.flat(Vector3.ZERO - home)
		if to.length_squared() < 1.0:
			to = Vector3(1, 0, 0)
		to = to.normalized()
		var spot = find_spot(home - to * 17.0, "hq", 10.0, 24)
		if spot == null:
			spot = find_spot(home - to * 12.0, "hq", 22.0, 40, true)
		if spot == null:
			spot = find_spot(home + Vector3(to.z, 0, -to.x) * 20.0, "hq", 26.0, 40, true)
		if spot != null:
			place("hq", t, spot, to, true)

# ---------------------------------------------------------------- geometry
# local coordinates: lx runs along the structure, lz toward its front, y up from the ground
static func _w(st: Dictionary, lx: float, lz: float) -> Vector2:
	var p: Vector3 = st["p"]
	if st["ax"]:
		return Vector2(p.x + lx * st["fs"], p.z + lz * st["fs"])
	return Vector2(p.x + lz * st["fs"], p.z - lx * st["fs"])

static func _wv(st: Dictionary, lx: float, lz: float) -> Vector3:
	var w = _w(st, lx, lz)
	return Vector3(w.x, G.world.ground_y(w.x, w.y), w.y)

static func _b(st: Dictionary, lx: float, y: float, lz: float, w: float, h: float, d: float, c: Color, opt: Dictionary = {}):
	var wp = _w(st, lx, lz)
	var o = opt.duplicate()
	if st.has("base_y") and not o.has("abs"):
		o["abs"] = true
		y += st["base_y"]
	if st["ax"]:
		return G.world.add_box(wp.x, y, wp.y, w, h, d, c, o)
	if o.has("ry"):
		o["ry"] = o["ry"] + PI / 2.0
	return G.world.add_box(wp.x, y, wp.y, d, h, w, c, o)

# a pitched roof with its ridge along lx; it has a collider so it can be shot away
static func _roof(st: Dictionary, lx: float, y: float, lz: float, w: float, h: float, d: float, c: Color, hp: float = 160.0) -> void:
	var wp = _w(st, lx, lz)
	var gy = st.get("base_y", G.world.ground_y(wp.x, wp.y))
	var ref
	if st["ax"]:
		ref = G.world.add_box(wp.x, gy + y, wp.y, w, h, d, c, {"shape": "prism", "ry": PI / 2.0, "abs": true, "collide": false})
	else:
		ref = G.world.add_box(wp.x, gy + y, wp.y, d, h, w, c, {"shape": "prism", "abs": true, "collide": false})
	var col = G.world.add_col(wp.x, gy + y, wp.y, (w if st["ax"] else d) * 0.9, h * 0.5, (d if st["ax"] else w) * 0.9)
	col.vis = [ref]
	col.dest = true
	col.hp = hp
	col.color = c

static func _cyl(st: Dictionary, lx: float, y: float, lz: float, r: float, h: float, c: Color, collide: bool = false, opt: Dictionary = {}):
	var o = opt.duplicate()
	o["shape"] = "cyl"
	o["collide"] = collide
	return _b(st, lx, y, lz, r * 2.0, h, r * 2.0, c, o)

static func _sandbags(st: Dictionary, lx: float, lz: float, ln: float, along_lx: bool, h: float = 1.0) -> void:
	var wp = _w(st, lx, lz)
	G.world.sandbags(wp.x, wp.y, ln, along_lx == st["ax"], h)

static func _crates(st: Dictionary, lx: float, lz: float, n: int) -> void:
	for i in range(n):
		var ox = (i % 3) * 1.05 - 1.05
		var oy = 0.0 if i < 3 else 0.62
		var c = CRATE.darkened(randf_range(0.0, 0.15))
		_b(st, lx + ox + (0.5 if i >= 3 else 0.0), oy, lz, 0.98, 0.6, 0.62, c, {"hp": 90.0})
		_b(st, lx + ox + (0.5 if i >= 3 else 0.0), oy + 0.6, lz, 1.0, 0.04, 0.15, Color(0.82, 0.7, 0.2), {"collide": false})

static func _drums(st: Dictionary, lx: float, lz: float, n: int) -> void:
	for i in range(n):
		var a = i * 2.4
		var r = 0.0 if i == 0 else 0.64
		_cyl(st, lx + cos(a) * r, 0.0, lz + sin(a) * r, 0.3, 0.9, Color(0.3, 0.32, 0.22) if i % 2 == 0 else Color(0.5, 0.2, 0.14), i == 0)

static func _flagpole(st: Dictionary, lx: float, lz: float, h: float, c: Color) -> void:
	_cyl(st, lx, 0.0, lz, 0.07, h, Color(0.3, 0.3, 0.3), true, {"hp": 120.0})
	_b(st, lx + 0.85, h - 1.2, lz, 1.6, 1.0, 0.05, c, {"collide": false, "no_shadow": true})

static func _tent(st: Dictionary, lx: float, lz: float, w: float, d: float, h: float, c: Color) -> void:
	_b(st, lx, 0.0, lz, w, h, d, c, {"hp": 160.0})
	_roof(st, lx, h, lz, w + 0.3, h * 0.55, d + 0.4, c.darkened(0.08))
	_b(st, lx + w * 0.25, 0.0, lz + d * 0.5 + 0.02, 1.0, h * 0.85, 0.05, c.darkened(0.45), {"collide": false})
	for e in [-1.0, 1.0]:
		_cyl(st, lx + e * (w * 0.5 + 0.35), 0.0, lz + d * 0.5 + 0.4, 0.03, 0.4, WOODC)

static func _geo_hq(st: Dictionary) -> void:
	var tc: Color = G.TEAM_UNI[st["team"]].lerp(CANVAS, 0.5)
	# concrete command post with a doorway at the front and slits on the sides
	var cx = -3.5
	var cz = -1.5
	_b(st, cx, 0.0, cz - 2.0, 6.0, 2.6, 0.45, CONCRETE)
	_b(st, cx - 2.8, 0.0, cz, 0.45, 2.6, 3.6, CONCRETE)
	_b(st, cx + 2.8, 0.0, cz, 0.45, 1.3, 3.6, CONCRETE)
	_b(st, cx + 2.8, 1.75, cz, 0.45, 0.85, 3.6, CONCRETE)
	_b(st, cx - 1.9, 0.0, cz + 2.0, 2.2, 2.6, 0.45, CONCRETE)
	_b(st, cx + 1.9, 0.0, cz + 2.0, 2.2, 2.6, 0.45, CONCRETE)
	_b(st, cx, 2.1, cz + 2.0, 1.6, 0.5, 0.45, CONCRETE)
	_b(st, cx, 2.6, cz, 6.4, 0.4, 4.8, CONCRETE.darkened(0.1))
	for k in range(3):
		_b(st, cx - 2.0 + k * 2.0, 3.0, cz, 1.5, 0.3, 3.6, Color(0.42, 0.42, 0.3), {"collide": false, "shape": "blob"})
	_b(st, cx, 2.3, cz + 2.25, 2.0, 0.25, 0.08, G.team_color(st["team"]), {"collide": false})
	# big tent, flags, stores, a sandbag front
	_tent(st, 4.5, -2.5, 5.5, 4.0, 2.0, tc)
	_flagpole(st, 0.5, 3.6, 8.0, G.team_color(st["team"]))
	_flagpole(st, -7.0, 3.6, 6.0, G.team_color(st["team"]))
	_crates(st, 4.5, 2.4, 6)
	_drums(st, 7.2, 1.6, 3)
	_sandbags(st, -4.0, 5.6, 6.0, true)
	_sandbags(st, 4.5, 5.6, 6.0, true)
	_cyl(st, -6.6, 2.9, -3.0, 0.03, 4.5, METALC)

static func _geo_fob(st: Dictionary) -> void:
	var tc: Color = G.TEAM_UNI[st["team"]].lerp(CANVAS, 0.5)
	_tent(st, -2.2, -2.0, 5.0, 3.6, 1.9, tc)
	_flagpole(st, 2.8, -3.2, 7.0, G.team_color(st["team"]))
	_crates(st, 2.6, 1.5, 5)
	_drums(st, 4.6, -1.2, 3)
	_sandbags(st, -2.5, 4.4, 4.5, true)
	_sandbags(st, 2.5, 4.4, 4.5, true)
	_sandbags(st, -5.2, 2.0, 3.5, false)
	# camouflage net on poles over the stores
	for p in [Vector2(0.6, -0.4), Vector2(5.0, -0.4), Vector2(0.6, 3.2), Vector2(5.0, 3.2)]:
		_cyl(st, p.x, 0.0, p.y, 0.05, 2.5, WOODC)
	_b(st, 2.8, 2.45, 1.4, 5.0, 0.06, 4.2, Color(0.3, 0.33, 0.22), {"collide": false})
	_b(st, -4.0, 0.0, 1.3, 1.2, 0.75, 0.7, WOODC, {"hp": 80.0})
	_b(st, -4.0, 0.75, 1.3, 0.5, 0.3, 0.35, Color(0.2, 0.22, 0.18), {"collide": false})
	_cyl(st, -4.3, 0.75, 1.3, 0.02, 2.5, METALC)

static func _geo_sandbags(st: Dictionary) -> void:
	_sandbags(st, 0.0, 0.0, 3.2, true)

static func _geo_wire(st: Dictionary) -> void:
	var L = 6.0
	var c = Color(0.3, 0.28, 0.26)
	var col = G.world.add_col(st["p"].x, st["p"].y, st["p"].z, L if st["ax"] else 0.9, 0.95, 0.9 if st["ax"] else L)
	col.vis = []
	col.dest = true
	col.hp = 70.0
	col.color = c
	G.world.piece = []
	for i in range(5):
		var x = -L / 2.0 + i * L / 4.0
		_b(st, x, 0.0, 0.0, 0.08, 1.15, 0.08, WOODC, {"collide": false, "rz": 0.35 if st["ax"] else 0.0, "rx": 0.0 if st["ax"] else 0.35})
		_b(st, x, 0.0, 0.0, 0.08, 1.15, 0.08, WOODC, {"collide": false, "rz": -0.35 if st["ax"] else 0.0, "rx": 0.0 if st["ax"] else -0.35})
	# coils: rings along the line
	for i in range(14):
		var x = -L / 2.0 + (i + 0.5) * L / 14.0
		_b(st, x, 0.05, 0.0, 0.03, 0.8, 0.8, c, {"collide": false, "shape": "cyl", "rz": PI / 2.0 if st["ax"] else 0.0, "rx": 0.0 if st["ax"] else PI / 2.0, "no_shadow": true})
	for y in [0.35, 0.8]:
		_b(st, 0.0, y, 0.0, L, 0.025, 0.025, c, {"collide": false, "no_shadow": true})
	col.vis.append_array(G.world.piece)
	G.world.piece = null

static func _geo_traps(st: Dictionary) -> void:
	for i in range(4):
		var w = _w(st, -3.0 + i * 2.0, (0.5 if i % 2 == 0 else -0.5))
		G.world.hedgehog(w.x, w.y)

static func _geo_mgnest(st: Dictionary) -> void:
	_sandbags(st, 0.0, 1.6, 3.4, true, 1.0)
	_sandbags(st, -1.7, 0.2, 2.4, false, 1.0)
	_sandbags(st, 1.7, 0.2, 2.4, false, 1.0)
	_b(st, 0.9, 0.0, -1.2, 0.5, 0.3, 0.35, CRATE, {"collide": false})

static func _geo_mortarpit(st: Dictionary) -> void:
	_sandbags(st, 0.0, 1.5, 3.0, true, 0.5)
	_sandbags(st, 0.0, -1.5, 3.0, true, 0.5)
	_sandbags(st, -1.5, 0.0, 2.2, false, 0.5)
	_sandbags(st, 1.5, 0.0, 2.2, false, 0.5)
	for i in range(3):
		_b(st, -0.8 + i * 0.35, 0.0, -0.9, 0.28, 0.2, 0.45, Color(0.28, 0.3, 0.2), {"collide": false})

static func _geo_concrete(st: Dictionary) -> void:
	_b(st, 0.0, 0.0, 0.0, 3.4, 1.35, 0.55, CONCRETE, {"hp": 700.0})
	_b(st, 0.0, 1.35, 0.0, 3.5, 0.12, 0.65, CONCRETE.darkened(0.1), {"collide": false})
	for x in [-1.2, 0.0, 1.2]:
		_b(st, x, 0.15, 0.3, 0.12, 1.0, 0.06, CONCRETE.darkened(0.15), {"collide": false})

static func _geo_pillbox(st: Dictionary) -> void:
	var c = CONCRETE
	_b(st, 0.0, 0.0, -1.9, 4.2, 2.1, 0.5, c)
	for x in [-1.9, 1.9]:
		_b(st, x, 0.0, 0.0, 0.5, 2.1, 3.4, c)
	# front: low wall, wide firing slit, heavy lintel
	_b(st, 0.0, 0.0, 1.9, 4.2, 1.05, 0.5, c)
	_b(st, 0.0, 1.55, 1.9, 4.2, 0.55, 0.5, c)
	_b(st, 0.0, 2.1, 0.0, 4.6, 0.45, 4.4, c.darkened(0.1))
	# doorway at the back
	_b(st, -1.3, 0.0, -2.35, 1.4, 2.1, 0.4, c)
	_b(st, 1.3, 0.0, -2.35, 1.4, 2.1, 0.4, c)
	for k in range(3):
		_b(st, -1.4 + k * 1.4, 2.45, 0.0, 1.6, 0.4, 3.8, Color(0.42, 0.4, 0.28), {"collide": false, "shape": "blob"})

static func _geo_fob2(st: Dictionary) -> void:
	# a proper hut in place of the tent, bigger stores, sandbagged all round
	var hut = WOODC.lightened(0.1)
	_b(st, -2.2, 0.0, -2.0, 5.2, 2.3, 3.8, hut, {"hp": 260.0})
	_roof(st, -2.2, 2.3, -2.0, 5.8, 1.2, 4.4, Color(0.34, 0.3, 0.26), 220.0)
	_b(st, -1.0, 0.0, -0.08, 1.0, 1.9, 0.06, hut.darkened(0.4), {"collide": false})
	for x in [-3.6, -2.6]:
		_b(st, x, 1.1, -0.08, 0.6, 0.5, 0.05, Color(0.2, 0.24, 0.28), {"collide": false})
	_cyl(st, -0.6, 2.9, -2.6, 0.12, 0.8, Color(0.3, 0.3, 0.3))
	_flagpole(st, 2.8, -3.2, 7.5, G.team_color(st["team"]))
	_crates(st, 2.6, 1.5, 6)
	_crates(st, 2.6, 2.8, 3)
	_drums(st, 4.6, -1.2, 4)
	_sandbags(st, -2.5, 4.4, 4.5, true)
	_sandbags(st, 2.5, 4.4, 4.5, true)
	_sandbags(st, -5.2, 2.0, 3.5, false)
	_sandbags(st, 5.4, 1.0, 3.5, false)
	_b(st, -4.0, 0.0, 1.3, 1.2, 0.75, 0.7, WOODC, {"hp": 80.0})
	_cyl(st, -4.3, 0.75, 1.3, 0.02, 3.0, METALC)

static func _geo_aa(st: Dictionary) -> void:
	_sandbags(st, 0.0, 2.1, 3.6, true, 1.0)
	_sandbags(st, 0.0, -2.1, 3.6, true, 1.0)
	_sandbags(st, -2.1, 0.0, 2.4, false, 1.0)
	_sandbags(st, 2.1, 0.0, 2.4, false, 1.0)
	_crates(st, 1.2, -1.3, 2)

static func _geo_tower(st: Dictionary) -> void:
	var h = 4.8
	for p in [Vector2(-1.4, -1.4), Vector2(1.4, -1.4), Vector2(1.4, 1.4), Vector2(-1.4, 1.4)]:
		_cyl(st, p.x, 0.0, p.y, 0.14, h + 2.4, WOODC, true, {"hp": 150.0})
	for k in range(2):
		var y = 1.0 + k * 1.8
		_b(st, 0.0, y, -1.4, 2.9, 0.12, 0.1, WOODC, {"collide": false})
		_b(st, 0.0, y, 1.4, 2.9, 0.12, 0.1, WOODC, {"collide": false})
		_b(st, -1.4, y, 0.0, 0.1, 0.12, 2.9, WOODC, {"collide": false})
		_b(st, 1.4, y, 0.0, 0.1, 0.12, 2.9, WOODC, {"collide": false})
	_b(st, 0.0, h, 0.0, 3.4, 0.2, 3.4, WOODC.darkened(0.1), {"hp": 160.0})
	_b(st, 0.0, h + 0.2, 1.65, 3.4, 0.9, 0.1, WOODC, {"hp": 90.0})
	_b(st, 1.65, h + 0.2, 0.0, 0.1, 0.9, 3.4, WOODC, {"hp": 90.0})
	_b(st, -1.65, h + 0.2, 0.0, 0.1, 0.9, 3.4, WOODC, {"hp": 90.0})
	_sandbags(st, 0.0, 1.3, 2.4, true, 0.5)
	_roof(st, 0.0, h + 2.4, 0.0, 3.8, 0.9, 3.8, Color(0.35, 0.3, 0.22))
	# ladder at the back
	for x in [-0.25, 0.25]:
		_b(st, x, 0.0, -1.75, 0.07, h + 0.4, 0.07, WOODC, {"collide": false})
	for k in range(9):
		_b(st, 0.0, 0.4 + k * 0.5, -1.75, 0.5, 0.05, 0.05, WOODC, {"collide": false})
	_b(st, 0.9, h + 0.9, 1.4, 0.2, 0.2, 0.25, Color(0.7, 0.7, 0.6), {"collide": false})

static func _geo_bunker(st: Dictionary) -> void:
	var c = CONCRETE
	_b(st, 0.0, 0.0, -2.9, 7.0, 2.3, 0.6, c)
	_b(st, -3.25, 0.0, 0.0, 0.6, 2.3, 5.2, c)
	_b(st, 3.25, 0.0, 0.0, 0.6, 2.3, 5.2, c)
	# front: low wall, firing slit, lintel
	_b(st, 0.0, 0.0, 2.9, 7.0, 1.2, 0.6, c)
	_b(st, 0.0, 1.75, 2.9, 7.0, 0.55, 0.6, c)
	for x in [-1.2, 1.2]:
		_b(st, x, 1.2, 2.9, 0.4, 0.55, 0.6, c)
	_b(st, 0.0, 2.3, 0.0, 7.6, 0.4, 6.6, c.darkened(0.1))
	# earth banked against the sides and over the roof
	for k in range(4):
		_b(st, -2.6 + k * 1.75, 2.55, 0.0, 2.2, 0.55, 5.6, Color(0.42, 0.4, 0.28), {"collide": false, "shape": "blob"})
	for e in [-1.0, 1.0]:
		for k in range(3):
			_b(st, e * 4.0, -0.3, -2.0 + k * 2.0, 1.4, 2.0, 2.2, Color(0.4, 0.38, 0.27), {"collide": false, "shape": "blob"})

static func _geo_hospital(st: Dictionary) -> void:
	var white = Color(0.86, 0.85, 0.8)
	var red = Color(0.8, 0.12, 0.12)
	_b(st, 0.0, 0.0, 0.0, 8.0, 2.1, 5.0, white, {"hp": 160.0})
	_roof(st, 0.0, 2.1, 0.0, 8.4, 1.3, 5.6, white.darkened(0.06))
	# red crosses on the front and on a panel by the door
	_b(st, -2.5, 0.9, 2.52, 1.0, 0.3, 0.04, red, {"collide": false})
	_b(st, -2.5, 0.65, 2.52, 0.3, 0.8, 0.04, red, {"collide": false})
	_b(st, 1.5, 0.0, 2.52, 1.4, 1.9, 0.05, white.darkened(0.4), {"collide": false})
	# stretchers and stores outside
	for i in range(3):
		_b(st, -3.4 + i * 1.0, 0.0, 3.6, 0.6, 0.22, 1.9, Color(0.4, 0.42, 0.32), {"collide": false})
	_crates(st, 3.4, -3.4, 3)
	_cyl(st, 4.6, 0.0, 3.0, 0.06, 5.5, Color(0.3, 0.3, 0.3), true)
	_b(st, 5.3, 4.4, 3.0, 1.3, 0.9, 0.04, white, {"collide": false})
	_b(st, 5.3, 4.75, 3.0, 0.8, 0.22, 0.05, red, {"collide": false})
	_b(st, 5.3, 4.6, 3.0, 0.22, 0.6, 0.05, red, {"collide": false})

static func _geo_radio(st: Dictionary) -> void:
	var m = METALC.lightened(0.15)
	# lattice mast: three legs and rungs
	for k in range(3):
		var a = k * TAU / 3.0
		var x = cos(a) * 0.55
		var z = sin(a) * 0.55
		_cyl(st, x, 0.0, z, 0.05, 10.0, m, k == 0, {"hp": 120.0})
	for k in range(9):
		_b(st, 0.0, 0.8 + k * 1.05, 0.0, 1.1, 0.04, 1.0, m, {"collide": false, "ry": k * 0.5})
	_cyl(st, 0.0, 10.0, 0.0, 0.02, 2.2, m)
	_b(st, 0.0, 12.1, 0.0, 0.18, 0.18, 0.18, Color(0.95, 0.2, 0.15), {"collide": false})
	_b(st, 0.3, 8.0, 0.4, 0.06, 0.8, 0.8, m, {"collide": false, "shape": "cyl", "rz": 1.2})
	# radio hut and generator
	_b(st, -1.2, 0.0, -1.6, 2.0, 1.9, 1.6, G.TEAM_UNI[st["team"]].lerp(CANVAS, 0.4))
	_roof(st, -1.2, 1.9, -1.6, 2.3, 0.5, 1.9, Color(0.3, 0.3, 0.27))
	_b(st, 1.5, 0.0, -1.5, 1.0, 0.7, 0.7, Color(0.33, 0.36, 0.25), {"hp": 80.0})
	_cyl(st, 1.5, 0.7, -1.5, 0.05, 0.6, METALC)

static func _geo_depot(st: Dictionary) -> void:
	var post = WOODC
	for x in [-5.0, 0.0, 5.0]:
		for z in [-3.6, 1.0]:
			_cyl(st, x, 0.0, z, 0.15, 3.6, post, true, {"hp": 140.0})
	_b(st, 0.0, 0.0, -3.9, 10.4, 2.6, 0.2, WOODC.darkened(0.1), {"hp": 150.0})
	_roof(st, 0.0, 3.6, -1.3, 11.0, 1.1, 5.6, Color(0.34, 0.35, 0.33))
	for i in range(8):
		_b(st, -4.4 + i * 1.25, 3.62, -1.3, 0.04, 0.04, 5.0, Color(0.28, 0.29, 0.27), {"collide": false})
	_drums(st, 4.3, 3.2, 4)
	for k in range(4):
		_b(st, -4.6, k * 0.3, 3.0, 0.9, 0.3, 0.9, Color(0.07, 0.07, 0.07), {"collide": k == 0, "shape": "cyl"})
	_b(st, -2.0, 0.0, -3.1, 2.4, 0.9, 0.8, WOODC, {"hp": 80.0})
	_b(st, -2.0, 0.9, -3.1, 0.4, 0.25, 0.4, Color(0.6, 0.15, 0.1), {"collide": false})
	_b(st, 2.0, 0.0, -1.0, 2.2, 0.03, 3.5, Color(0.15, 0.14, 0.12), {"collide": false})

static func _geo_supply(st: Dictionary) -> void:
	_crates(st, -1.5, -1.0, 6)
	_crates(st, 1.8, -1.2, 4)
	_drums(st, 2.3, 1.4, 3)
	_b(st, -1.6, 0.0, 1.4, 1.8, 0.12, 1.1, WOODC, {"collide": false})
	_b(st, -1.6, 0.12, 1.4, 1.6, 0.75, 1.0, Color(0.36, 0.38, 0.27), {"hp": 90.0})
	for p in [Vector2(-3.0, -2.4), Vector2(3.0, -2.4), Vector2(-3.0, 2.4), Vector2(3.0, 2.4)]:
		_cyl(st, p.x, 0.0, p.y, 0.05, 2.4, WOODC)
	_b(st, 0.0, 2.35, 0.0, 6.2, 0.06, 5.0, Color(0.3, 0.33, 0.22), {"collide": false})
	_sandbags(st, 0.0, 2.9, 4.0, true, 0.5)
