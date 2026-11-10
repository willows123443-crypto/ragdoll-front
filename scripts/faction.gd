class_name Faction
extends RefCounted
# Factions: who each side is. "army" is a regular army (everything the game had before);
# "militia" is the Black Banner Militia:
#   - mixed civilian clothes, scarves and balaclavas, chest rigs, no helmets
#   - old rifles, machine guns, plenty of RPGs, hunting rifles, molotovs; poorer shots
#   - technicals (pickups with a gun in the back) and motorbikes; no tanks, no air support, no radio operators
#   - hidden weapons caches on its side of the map: re-arm there, and fresh fighters turn up at them in ones and twos
#   - roadside bombs on the roads, set off by vehicles
#   - tunnels: fighters drop in at one end and come out at the other
#   - snipers who move after every shot

const LIST = ["army", "militia"]
const NAMES = {"army": "Regular army", "militia": "Black Banner Militia"}

static var caches: Array = []         # {"p", "team", "alive", "node", "ammo"}
static var tunnels: Array = []        # {"a", "b", "team"}
static var trickle_t: Array = [0.0, 0.0, 0.0, 0.0]

static func of(t: int) -> String:
	return G.factions[t] if t >= 0 and t < G.factions.size() else "army"

static func militia(t: int) -> bool:
	return of(t) == "militia"

static func reset() -> void:
	for c in caches:
		if c.get("node") != null and is_instance_valid(c["node"]):
			c["node"].queue_free()
	caches = []
	tunnels = []
	trickle_t = [0.0, 0.0, 0.0, 0.0]

# ---------------------------------------------------------------- soldiers
const MIL_CLASSES = {
	"rifleman": ["rifle"], "mg": ["lmg"], "medic": ["rifle"], "at": ["rpg", "rpg"], "engineer": ["shotgun", "rifle"],
	"assault": ["smg", "shotgun"], "sniper": ["sniper"], "spotter": ["rifle"], "officer": ["pistol"], "radio": ["rifle"],
}

static func weapon_for(t: int, cls: String) -> String:
	if militia(t):
		return G.pick(MIL_CLASSES.get(cls, ["rifle"]))
	return G.pick(G.CLASSES[cls]["w"])

# the militia has more RPGs, no radio operators, no spotters and no officers
static func pick_class(t: int) -> String:
	if not militia(t):
		return G.pick_class(t)
	var r = randf()
	if r < 0.4: return "rifleman"
	if r < 0.55: return "mg"
	if r < 0.72: return "at"
	if r < 0.82: return "assault"
	if r < 0.9: return "engineer"
	if r < 0.95: return "medic"
	return "sniper"

const CLOTHES = [Color(0.22, 0.22, 0.24), Color(0.36, 0.3, 0.24), Color(0.15, 0.18, 0.28), Color(0.44, 0.42, 0.38), Color(0.3, 0.33, 0.24),
	Color(0.5, 0.45, 0.36), Color(0.12, 0.12, 0.13), Color(0.32, 0.2, 0.16), Color(0.55, 0.53, 0.5)]
const TROUSERS = [Color(0.2, 0.25, 0.36), Color(0.14, 0.14, 0.15), Color(0.3, 0.3, 0.32), Color(0.38, 0.34, 0.26), Color(0.24, 0.22, 0.2)]

# per fighter: a jacket, trousers and a scarf or balaclava, no two quite the same
static func clothes(id: int) -> Array:
	return [CLOTHES[id % CLOTHES.size()], TROUSERS[(id * 7) % TROUSERS.size()], Color(0.16, 0.15, 0.13).lerp(Color(0.3, 0.27, 0.2), float(id % 3) / 2.0)]

static func headgear(s, head: Node3D) -> void:
	var k = s.id % 4
	var dark = s._mat("milwrap" + str(k), [Color(0.1, 0.1, 0.1), Color(0.5, 0.45, 0.36), Color(0.2, 0.2, 0.22), Color(0.62, 0.6, 0.55)][k], false)
	var band = s._mat("band" + G.TEAM_BAND[s.team].to_html(), G.TEAM_BAND[s.team], false)
	match k:
		0:  # balaclava: the whole head, a slit for the eyes
			s._hpart(head, "dome", Vector3(0.28, 0.52, 0.29), Vector3(0, 0.0, 0), dark)
		1:  # shemagh wrapped round head and face
			s._hpart(head, "dome", Vector3(0.3, 0.42, 0.31), Vector3(0, 0.06, 0), dark)
			s._hpart(head, "cyl", Vector3(0.27, 0.1, 0.27), Vector3(0, -0.06, -0.02), dark)
		2:  # beanie and a face scarf
			s._hpart(head, "dome", Vector3(0.28, 0.36, 0.29), Vector3(0, 0.09, 0), dark)
			s._hpart(head, "cyl", Vector3(0.26, 0.09, 0.26), Vector3(0, -0.07, -0.025), band)
		_:  # bare head, headband in the side's colour
			s._hpart(head, "cyl", Vector3(0.27, 0.04, 0.27), Vector3(0, 0.07, 0), band)

# chest rig, a tracksuit or a jacket, trainers or boots: no two fighters kitted out the same
static func rig(s, vest: Material, uni: Material, uni2: Material) -> void:
	var k = s.id
	var box = s.unit_box
	var pouch = s._mat("milpouch" + str(k % 3), [Color(0.27, 0.25, 0.18), Color(0.18, 0.18, 0.17), Color(0.36, 0.32, 0.22)][k % 3], false)
	var strap = s._mat("milstrap", Color(0.12, 0.11, 0.1), false)
	# magazine pouches across the chest rig, and a grenade pouch on the side
	for i in range(4):
		s._detail(s.parts[1], box, Vector3((i - 1.5) * 0.085, -0.03, -0.27), pouch, Vector3(0.07, 0.11, 0.04))
	s._detail(s.parts[1], box, Vector3(0.19, -0.1, -0.12), pouch, Vector3(0.07, 0.08, 0.08))
	for e in [-1.0, 1.0]:
		s._detail(s.parts[1], box, Vector3(e * 0.11, 0.1, 0.0), strap, Vector3(0.045, 0.28, 0.31))
	# a third wear tracksuits: stripes down the arms and legs
	if k % 3 == 0:
		var st = s._mat("milstripe" + str(k % 2), [Color(0.85, 0.85, 0.82), Color(0.75, 0.62, 0.2)][k % 2], false)
		for i in [3, 5]:
			for e2 in [-1.0, 1.0]:
				s._detail(s.parts[i], box, Vector3(e2 * 0.066, 0.0, 0.0), st, Vector3(0.012, 0.32, 0.03))
		for i in [7, 9, 8, 10]:
			var hw = 0.086 if i in [7, 9] else 0.076
			for e3 in [-1.0, 1.0]:
				s._detail(s.parts[i], box, Vector3(e3 * hw, 0.0, 0.0), st, Vector3(0.012, 0.42, 0.03))
	elif k % 3 == 1:
		# an open jacket over a T-shirt: a lighter front panel
		var tee = s._mat("miltee" + str(k % 4), [Color(0.7, 0.68, 0.62), Color(0.3, 0.35, 0.45), Color(0.48, 0.2, 0.18), Color(0.2, 0.2, 0.2)][k % 4], false)
		s._detail(s.parts[1], box, Vector3(0, -0.17, -0.123), tee, Vector3(0.16, 0.16, 0.01))
	# trainers with white soles for some, worn boots for the rest
	if k % 2 == 0:
		var shoe = s._mat("milshoe" + str(k % 3), [Color(0.85, 0.85, 0.83), Color(0.15, 0.15, 0.17), Color(0.3, 0.32, 0.4)][k % 3], false)
		var sole = s._mat("milsole", Color(0.92, 0.92, 0.9), false)
		for i in [8, 10]:
			s._detail(s.parts[i], box, Vector3(0, 0.21, 0.07), shoe, Vector3(0.165, 0.13, 0.29))
			s._detail(s.parts[i], box, Vector3(0, 0.275, 0.07), sole, Vector3(0.17, 0.03, 0.3))
	# an armband in the group's colour
	var band = s._mat("band" + G.TEAM_BAND[s.team].to_html(), G.TEAM_BAND[s.team], false)
	s._detail(s.parts[5], box, Vector3(0, 0.06, 0), band, Vector3(0.14, 0.06, 0.14))

# ---------------------------------------------------------------- vehicles and support
const MIL_VEH = {"jeep": "technical", "halftrack": "technical", "armoredcar": "technical", "tank": "technical", "heavytank": "technical",
	"radar": "", "atgun": "", "bridger": "", "ambulance": "", "gunship": "", "fighter": "", "bomber": ""}

static func vehicle_kind(t: int, kind: String) -> String:
	if not militia(t):
		return kind
	return MIL_VEH.get(kind, kind)

static func support_ok(t: int, what: String) -> bool:
	if not militia(t):
		return what != "technical"
	return not (what in ["airstrike", "paradrop", "heli", "gunship", "fighter", "bomber", "recon", "tank", "heavytank", "armoredcar", "halftrack", "radar", "atgun", "bridger", "ambulance", "jeep"])

# ---------------------------------------------------------------- the militia's ground
static func setup() -> void:
	reset()
	for t in range(mini(2, G.team_count())):
		if not militia(t):
			continue
		_place_caches(t)
		_place_ieds(t)
		_place_tunnels(t)

static func _frac(t: int, p: Vector3) -> float:
	var a: Vector3 = G.world.spawn[t]
	var b: Vector3 = G.world.spawn[(t + 1) % G.team_count()]
	var ab = G.flat(b - a)
	return G.flat(p - a).dot(ab) / maxf(1.0, ab.length_squared())

static func _place_caches(t: int) -> void:
	var spots = []
	for b in G.world.buildings:
		var p = Vector3(b["x"], 0, b["z"])
		var f = _frac(t, p)
		if f > 0.1 and f < 0.55 and b["w"] >= 4.0:
			spots.append(p)
	spots.shuffle()
	var n = 0
	for p in spots:
		if n >= 4:
			break
		var q = G.main._free_spot(p)
		_cache_at(t, q)
		n += 1
	# open country: dig them in among the scrub
	var a: Vector3 = G.world.spawn[t]
	var b2: Vector3 = G.world.spawn[(t + 1) % G.team_count()]
	var axis = G.flat(b2 - a).normalized()
	var perp = Vector3(-axis.z, 0, axis.x)
	while n < 3:
		var q2 = G.main._free_spot(a.lerp(b2, randf_range(0.15, 0.45)) + perp * randf_range(-40.0, 40.0))
		_cache_at(t, q2)
		n += 1

static func _cache_at(t: int, p: Vector3) -> void:
	p.y = G.world.ground_y(p.x, p.z)
	var node = Node3D.new()
	G.world.geo_root.add_child(node)
	node.position = p
	var wood = VModel.mat(Color(0.36, 0.28, 0.18))
	var tarp = VModel.mat(Color(0.25, 0.27, 0.2))
	for k in range(3):
		var mi = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(1.0, 0.32, 0.45)
		mi.mesh = bm
		mi.material_override = wood
		mi.position = Vector3(0, 0.16 + k * 0.32, 0) if k < 2 else Vector3(0.6, 0.16, 0.3)
		mi.rotation.y = randf_range(-0.3, 0.3)
		node.add_child(mi)
	var tm = MeshInstance3D.new()
	var tb = BoxMesh.new()
	tb.size = Vector3(1.6, 0.05, 1.2)
	tm.mesh = tb
	tm.material_override = tarp
	tm.position = Vector3(0.2, 0.7, 0.1)
	tm.rotation = Vector3(0.1, 0.3, -0.08)
	node.add_child(tm)
	var ammo = {"p": p, "team": t, "stock": 400.0}
	G.world.ammo_points.append(ammo)
	caches.append({"p": p, "team": t, "alive": true, "node": node, "ammo": ammo})

# a cache goes up if it's caught in a blast (or an enemy engineer blows it)
static func blast(p: Vector3, power: float) -> void:
	for c in caches:
		if c["alive"] and G.dist2d(c["p"], p) < 2.5 + power:
			c["alive"] = false
			G.world.ammo_points.erase(c["ammo"])
			if is_instance_valid(c["node"]):
				c["node"].queue_free()
			G.fx.explosion(c["p"] + Vector3(0, 0.5, 0), 1.2)
			G.ui.radio(c["team"], "A weapons cache has been destroyed!")
			for o in range(G.team_count()):
				if o != c["team"]:
					G.ui.radio(o, "Enemy weapons cache destroyed")

static func live_caches(t: int) -> Array:
	return caches.filter(func(c): return c["team"] == t and c["alive"])

static func _place_ieds(t: int) -> void:
	var n = 0
	for k in range(60):
		if n >= 5:
			break
		var rd = G.pick(G.world.roads) if not G.world.roads.is_empty() else null
		if rd == null:
			break
		var p = Vector3(randf_range(rd[0], rd[1]), 0, randf_range(rd[2], rd[3]))
		var f = _frac(t, p)
		if f < 0.15 or f > 0.65 or G.near_spawn(p, 35.0):
			continue
		Combat.place_mine_at(t, p, "ied")
		n += 1

static func _place_tunnels(t: int) -> void:
	var a: Vector3 = G.world.spawn[t]
	var b: Vector3 = G.world.spawn[(t + 1) % G.team_count()]
	var axis = G.flat(b - a).normalized()
	var perp = Vector3(-axis.z, 0, axis.x)
	for k in range(2):
		var side = 1.0 if k == 0 else -1.0
		var p0 = G.main._free_spot(a.lerp(b, 0.12) + perp * side * randf_range(10.0, 30.0))
		var p1 = G.main._free_spot(a.lerp(b, randf_range(0.4, 0.5)) + perp * side * randf_range(15.0, 45.0))
		for p in [p0, p1]:
			_hatch(p)
		tunnels.append({"a": p0, "b": p1, "team": t})

static func _hatch(p: Vector3) -> void:
	var mi = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.6
	cm.bottom_radius = 0.75
	cm.height = 0.12
	mi.mesh = cm
	mi.material_override = VModel.mat(Color(0.1, 0.09, 0.08))
	G.world.geo_root.add_child(mi)
	mi.position = Vector3(p.x, G.world.ground_y(p.x, p.z) + 0.04, p.z)
	var lid = MeshInstance3D.new()
	var lb = BoxMesh.new()
	lb.size = Vector3(1.0, 0.06, 1.0)
	lid.mesh = lb
	lid.material_override = VModel.mat(Color(0.35, 0.27, 0.17))
	G.world.geo_root.add_child(lid)
	lid.position = mi.position + Vector3(0.9, 0.1, 0.2)
	lid.rotation = Vector3(0.2, 0.6, 0.3)

# ---------------------------------------------------------------- every tick
static func step(dt: float) -> void:
	if G.over:
		return
	for t in range(mini(2, G.team_count())):
		if not militia(t):
			continue
		_trickle(t, dt)
	if Engine.get_physics_frames() % 20 == 0:
		_tunnel_use()

# fighters keep turning up at the caches in ones and twos (fewer caches, fewer men)
static func _trickle(t: int, dt: float) -> void:
	if not G.reinforce or G.mode in ["laststand", "horde", "sabotage"] or (G.mode == "commander" and t == 0):
		return
	var cs = live_caches(t)
	var missing = G.size_of(t) - Reinforce.foot_count(t)
	if missing <= 0:
		return
	trickle_t[t] += dt
	var every = 14.0 if cs.is_empty() else 7.0 + 8.0 / cs.size()
	if trickle_t[t] < every:
		return
	trickle_t[t] = 0.0
	for k in range(mini(missing, randi_range(1, 2))):
		var p: Vector3 = G.pick(cs)["p"] if not cs.is_empty() else G.world.spawn[t]
		G.main.spawn_soldier(t, p.x + randf_range(-3, 3), p.z + randf_range(-3, 3), "")

# fighters far from where they're going take a tunnel if one gets them most of the way
static func _tunnel_use() -> void:
	for tn in tunnels:
		for s in G.soldiers:
			if s.team != tn["team"] or s.state != "alive" or s.is_player or s.vehicle != null or s.move_target == null:
				continue
			for ends in [[tn["a"], tn["b"]], [tn["b"], tn["a"]]]:
				var e0: Vector3 = ends[0]
				var e1: Vector3 = ends[1]
				if G.dist2d(s.pos, e0) < 1.6:
					var gain = G.dist2d(s.pos, s.move_target) - G.dist2d(e1, s.move_target)
					if gain > 35.0:
						s.pos = Vector3(e1.x + randf_range(-1, 1), G.world.ground_y(e1.x, e1.z), e1.z + randf_range(-1, 1))
						s.need_path = true
						if randf() < 0.3:
							G.fx.callout(s, G.pick(["Through the tunnel!", "Out the other side."]))

# the player at a tunnel mouth (F): out the other end
static func player_tunnel(s) -> bool:
	for tn in tunnels:
		if tn["team"] != s.team:
			continue
		for ends in [[tn["a"], tn["b"]], [tn["b"], tn["a"]]]:
			if G.dist2d(s.pos, ends[0]) < 1.8:
				var e1: Vector3 = ends[1]
				s.pos = Vector3(e1.x, G.world.ground_y(e1.x, e1.z), e1.z)
				G.ui.message("Through the tunnel")
				return true
	return false
