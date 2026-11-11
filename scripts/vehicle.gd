class_name Vehicle
extends Node3D
# Jeeps (with a mounted machine gun), troop trucks and tanks. Arcade driving over the terrain,
# seats for the crew, AI drivers and gunners, damage, wrecks, and running people over.
# Local axes: +z is forward, +x is the vehicle's left, +y up.

const SPECS = {
	"jeep": {"name": "Jeep", "len": 4.2, "wid": 2.0, "speed": 15.0, "rev": 5.0, "accel": 7.0, "turn": 1.5, "hp": 520.0,
		"bullet": 0.35, "tracked": false, "standoff": 38.0,
		"seats": [
			{"o": Vector3(0.45, 1.12, 0.15), "role": "driver", "pose": "sit", "face": 0.0},
			{"o": Vector3(0.0, 2.0, -1.25), "role": "gunner", "pose": "stand", "face": 0.0, "turret": true},
			{"o": Vector3(-0.45, 1.12, 0.15), "role": "pass", "pose": "sit", "face": 0.0},
			{"o": Vector3(-0.5, 1.12, -0.85), "role": "pass", "pose": "sit", "face": 0.0}]},
	"truck": {"name": "Truck", "len": 7.2, "wid": 2.5, "speed": 11.0, "rev": 4.0, "accel": 4.5, "turn": 1.0, "hp": 650.0,
		"bullet": 0.3, "tracked": false, "standoff": 0.0,
		"seats": [
			{"o": Vector3(0.5, 1.6, 2.3), "role": "driver", "pose": "sit", "face": 0.0},
			{"o": Vector3(0.8, 1.62, -0.1), "role": "pass", "pose": "sit", "face": -PI / 2.0},
			{"o": Vector3(-0.8, 1.62, -0.1), "role": "pass", "pose": "sit", "face": PI / 2.0},
			{"o": Vector3(0.8, 1.62, -1.0), "role": "pass", "pose": "sit", "face": -PI / 2.0},
			{"o": Vector3(-0.8, 1.62, -1.0), "role": "pass", "pose": "sit", "face": PI / 2.0},
			{"o": Vector3(0.8, 1.62, -1.9), "role": "pass", "pose": "sit", "face": -PI / 2.0},
			{"o": Vector3(-0.8, 1.62, -1.9), "role": "pass", "pose": "sit", "face": PI / 2.0},
			{"o": Vector3(0.8, 1.62, -2.8), "role": "pass", "pose": "sit", "face": -PI / 2.0},
			{"o": Vector3(-0.8, 1.62, -2.8), "role": "pass", "pose": "sit", "face": PI / 2.0}]},
	"halftrack": {"name": "Half-track", "len": 6.2, "wid": 2.4, "speed": 10.5, "rev": 4.0, "accel": 4.5, "turn": 1.0, "hp": 900.0,
		"bullet": 0.12, "tracked": false, "standoff": 30.0, "gun": "mg",
		"seats": [
			{"o": Vector3(0.5, 1.55, 1.7), "role": "driver", "pose": "sit", "face": 0.0},
			{"o": Vector3(0.0, 2.05, 0.45), "role": "gunner", "pose": "stand", "face": 0.0, "turret": true},
			{"o": Vector3(0.75, 1.5, -0.4), "role": "pass", "pose": "sit", "face": -PI / 2.0},
			{"o": Vector3(-0.75, 1.5, -0.4), "role": "pass", "pose": "sit", "face": PI / 2.0},
			{"o": Vector3(0.75, 1.5, -1.3), "role": "pass", "pose": "sit", "face": -PI / 2.0},
			{"o": Vector3(-0.75, 1.5, -1.3), "role": "pass", "pose": "sit", "face": PI / 2.0},
			{"o": Vector3(0.75, 1.5, -2.2), "role": "pass", "pose": "sit", "face": -PI / 2.0},
			{"o": Vector3(-0.75, 1.5, -2.2), "role": "pass", "pose": "sit", "face": PI / 2.0}]},
	"armoredcar": {"name": "Armoured car", "len": 5.2, "wid": 2.4, "speed": 16.0, "rev": 6.0, "accel": 6.5, "turn": 1.2, "hp": 1000.0,
		"bullet": 0.06, "tracked": false, "standoff": 40.0, "gun": "autocannon",
		"seats": [
			{"o": Vector3(0.5, 1.2, 1.3), "role": "driver", "pose": "hidden", "face": 0.0},
			{"o": Vector3(0.0, 2.1, -0.3), "role": "gunner", "pose": "hidden", "face": 0.0}]},
	"motorbike": {"name": "Motorbike", "len": 2.6, "wid": 1.9, "speed": 19.0, "rev": 4.0, "accel": 9.0, "turn": 2.0, "hp": 200.0,
		"bullet": 0.6, "tracked": false, "standoff": 30.0, "gun": "mg",
		"seats": [
			{"o": Vector3(-0.45, 1.25, -0.1), "role": "driver", "pose": "sit", "face": 0.0},
			{"o": Vector3(0.55, 1.0, 0.0), "role": "gunner", "pose": "sit", "face": 0.0}]},
	"artillery": {"name": "Field gun", "len": 4.5, "wid": 2.4, "speed": 0.0, "rev": 0.0, "accel": 0.0, "turn": 0.0, "hp": 600.0,
		"bullet": 0.15, "tracked": false, "standoff": 0.0, "static": true,
		"seats": [{"o": Vector3(0.9, 0.95, -1.6), "role": "gunner", "pose": "stand", "face": 0.0}]},
	"technical": {"name": "Technical", "len": 4.9, "wid": 2.0, "speed": 15.0, "rev": 5.0, "accel": 7.0, "turn": 1.4, "hp": 460.0,
		"bullet": 0.4, "tracked": false, "standoff": 34.0,
		"seats": [
			{"o": Vector3(0.45, 0.9, 0.45), "role": "driver", "pose": "sit", "face": 0.0},
			{"o": Vector3(0.0, 2.27, -1.45), "role": "gunner", "pose": "stand", "face": 0.0, "turret": true},
			{"o": Vector3(-0.45, 0.9, 0.45), "role": "pass", "pose": "sit", "face": 0.0},
			{"o": Vector3(0.6, 1.25, -1.9), "role": "pass", "pose": "sit", "face": -PI / 2.0},
			{"o": Vector3(-0.6, 1.25, -1.9), "role": "pass", "pose": "sit", "face": PI / 2.0}]},
	"atgun": {"name": "Anti-tank gun", "len": 3.8, "wid": 2.0, "speed": 1.5, "rev": 1.0, "accel": 1.2, "turn": 0.4, "hp": 520.0,
		"bullet": 0.25, "tracked": false, "standoff": 80.0,
		"seats": [
			{"o": Vector3(0.0, 0.95, -2.35), "role": "driver", "pose": "push", "face": 0.0},
			{"o": Vector3(0.62, 0.95, -0.85), "role": "gunner", "pose": "stand", "face": 0.0}]},
	"dinghy": {"name": "Assault boat", "len": 5.2, "wid": 1.9, "speed": 6.5, "rev": 3.0, "accel": 3.0, "turn": 1.1, "hp": 260.0,
		"bullet": 0.7, "tracked": false, "standoff": 0.0, "boat": true,
		"seats": [
			{"o": Vector3(0.0, 0.95, -2.0), "role": "driver", "pose": "sit", "face": 0.0},
			{"o": Vector3(0.45, 0.8, 1.3), "role": "pass", "pose": "sit", "face": 0.0},
			{"o": Vector3(-0.45, 0.8, 1.3), "role": "pass", "pose": "sit", "face": 0.0},
			{"o": Vector3(0.45, 0.8, 0.4), "role": "pass", "pose": "sit", "face": 0.0},
			{"o": Vector3(-0.45, 0.8, 0.4), "role": "pass", "pose": "sit", "face": 0.0},
			{"o": Vector3(0.45, 0.8, -0.5), "role": "pass", "pose": "sit", "face": 0.0},
			{"o": Vector3(-0.45, 0.8, -0.5), "role": "pass", "pose": "sit", "face": 0.0}]},
	"heli": {"name": "Transport helicopter", "len": 11.0, "wid": 3.0, "speed": 26.0, "rev": 8.0, "accel": 8.0, "turn": 1.0, "hp": 700.0,
		"bullet": 0.3, "tracked": false, "standoff": 0.0, "air": true,
		"seats": [
			{"o": Vector3(0.3, 1.0, 2.75), "role": "driver", "pose": "sit", "face": 0.0},
			{"o": Vector3(0.78, 1.05, 1.2), "role": "pass", "pose": "sit", "face": -PI / 2.0},
			{"o": Vector3(-0.78, 1.05, 1.2), "role": "pass", "pose": "sit", "face": PI / 2.0},
			{"o": Vector3(0.78, 1.05, 0.4), "role": "pass", "pose": "sit", "face": -PI / 2.0},
			{"o": Vector3(-0.78, 1.05, 0.4), "role": "pass", "pose": "sit", "face": PI / 2.0},
			{"o": Vector3(0.78, 1.05, -0.4), "role": "pass", "pose": "sit", "face": -PI / 2.0},
			{"o": Vector3(-0.78, 1.05, -0.4), "role": "pass", "pose": "sit", "face": PI / 2.0}]},
	"gunship": {"name": "Gunship", "len": 10.0, "wid": 2.4, "speed": 30.0, "rev": 8.0, "accel": 9.0, "turn": 1.2, "hp": 900.0,
		"bullet": 0.2, "tracked": false, "standoff": 0.0, "air": true, "gun": "mg",
		"seats": [
			{"o": Vector3(0.0, 1.5, 1.6), "role": "driver", "pose": "hidden", "face": 0.0},
			{"o": Vector3(0.0, 1.5, 2.6), "role": "gunner", "pose": "hidden", "face": 0.0}]},
	"boat": {"name": "Landing craft", "len": 9.0, "wid": 3.4, "speed": 9.0, "rev": 4.0, "accel": 3.5, "turn": 0.6, "hp": 800.0,
		"bullet": 0.1, "tracked": false, "standoff": 0.0, "boat": true,
		"seats": [
			{"o": Vector3(0.0, 1.95, -3.8), "role": "driver", "pose": "sit", "face": 0.0},
			{"o": Vector3(0.9, 1.3, 2.0), "role": "pass", "pose": "sit", "face": 0.0},
			{"o": Vector3(-0.9, 1.3, 2.0), "role": "pass", "pose": "sit", "face": 0.0},
			{"o": Vector3(0.9, 1.3, 0.8), "role": "pass", "pose": "sit", "face": 0.0},
			{"o": Vector3(-0.9, 1.3, 0.8), "role": "pass", "pose": "sit", "face": 0.0},
			{"o": Vector3(0.9, 1.3, -0.4), "role": "pass", "pose": "sit", "face": 0.0},
			{"o": Vector3(-0.9, 1.3, -0.4), "role": "pass", "pose": "sit", "face": 0.0},
			{"o": Vector3(0.9, 1.3, -1.6), "role": "pass", "pose": "sit", "face": 0.0},
			{"o": Vector3(-0.9, 1.3, -1.6), "role": "pass", "pose": "sit", "face": 0.0}]},
	"nest": {"name": "MG nest", "len": 3.2, "wid": 3.2, "speed": 0.0, "rev": 0.0, "accel": 0.0, "turn": 0.0, "hp": 900.0,
		"bullet": 0.04, "tracked": false, "standoff": 0.0, "static": true,
		"seats": [{"o": Vector3(0.0, 0.95, -0.55), "role": "gunner", "pose": "stand", "face": 0.0, "turret": true}]},
	"mortar": {"name": "Mortar", "len": 1.6, "wid": 1.6, "speed": 0.0, "rev": 0.0, "accel": 0.0, "turn": 0.0, "hp": 260.0,
		"bullet": 0.5, "tracked": false, "standoff": 0.0, "static": true,
		"seats": [{"o": Vector3(0.75, 0.95, -0.2), "role": "gunner", "pose": "stand", "face": 0.0}]},
	"aagun": {"name": "Anti-aircraft gun", "len": 3.0, "wid": 3.0, "speed": 0.0, "rev": 0.0, "accel": 0.0, "turn": 0.0, "hp": 700.0,
		"bullet": 0.1, "tracked": false, "standoff": 0.0, "static": true, "gun": "aa",
		"seats": [{"o": Vector3(0.0, 1.35, -0.55), "role": "gunner", "pose": "stand", "face": 0.0, "turret": true}]},
	"fighter": {"name": "Fighter", "len": 9.0, "wid": 10.0, "speed": 52.0, "rev": 24.0, "accel": 10.0, "turn": 1.0, "hp": 480.0,
		"bullet": 0.35, "tracked": false, "standoff": 0.0, "air": true, "plane": true,
		"seats": [{"o": Vector3(0.0, 1.55, 0.2), "role": "driver", "pose": "hidden", "face": 0.0}]},
	"bomber": {"name": "Dive bomber", "len": 11.0, "wid": 13.0, "speed": 42.0, "rev": 22.0, "accel": 8.0, "turn": 0.8, "hp": 650.0,
		"bullet": 0.3, "tracked": false, "standoff": 0.0, "air": true, "plane": true,
		"seats": [{"o": Vector3(0.0, 1.55, 0.8), "role": "driver", "pose": "hidden", "face": 0.0},
			{"o": Vector3(0.0, 1.5, -0.9), "role": "gunner", "pose": "hidden", "face": PI}]},
	"bridger": {"name": "Bridge layer", "len": 7.4, "wid": 3.3, "speed": 7.0, "rev": 3.0, "accel": 3.0, "turn": 0.8, "hp": 1300.0,
		"bullet": 0.0, "tracked": true, "standoff": 0.0,
		"seats": [{"o": Vector3(0.6, 1.0, 1.8), "role": "driver", "pose": "hidden", "face": 0.0}]},
	"supplytruck": {"name": "Supply truck", "len": 7.2, "wid": 2.5, "speed": 10.5, "rev": 4.0, "accel": 4.2, "turn": 1.0, "hp": 600.0,
		"bullet": 0.3, "tracked": false, "standoff": 0.0,
		"seats": [
			{"o": Vector3(0.5, 1.6, 2.3), "role": "driver", "pose": "sit", "face": 0.0},
			{"o": Vector3(-0.5, 1.6, 2.3), "role": "pass", "pose": "sit", "face": 0.0}]},
	"ammotruck": {"name": "Ammo truck", "len": 7.2, "wid": 2.5, "speed": 10.0, "rev": 4.0, "accel": 4.2, "turn": 1.0, "hp": 560.0,
		"bullet": 0.3, "tracked": false, "standoff": 0.0,
		"seats": [
			{"o": Vector3(0.5, 1.6, 2.3), "role": "driver", "pose": "sit", "face": 0.0},
			{"o": Vector3(-0.5, 1.6, 2.3), "role": "pass", "pose": "sit", "face": 0.0}]},
	"ambulance": {"name": "Ambulance", "len": 7.2, "wid": 2.5, "speed": 12.0, "rev": 4.0, "accel": 5.0, "turn": 1.0, "hp": 550.0,
		"bullet": 0.35, "tracked": false, "standoff": 0.0,
		"seats": [
			{"o": Vector3(0.5, 1.6, 2.3), "role": "driver", "pose": "sit", "face": 0.0},
			{"o": Vector3(0.6, 1.6, -0.5), "role": "pass", "pose": "hidden", "face": 0.0},
			{"o": Vector3(-0.6, 1.6, -0.5), "role": "pass", "pose": "hidden", "face": 0.0},
			{"o": Vector3(0.6, 1.6, -2.0), "role": "pass", "pose": "hidden", "face": 0.0},
			{"o": Vector3(-0.6, 1.6, -2.0), "role": "pass", "pose": "hidden", "face": 0.0}]},
	"radar": {"name": "Command truck", "len": 7.2, "wid": 2.5, "speed": 10.0, "rev": 4.0, "accel": 4.5, "turn": 1.0, "hp": 750.0,
		"bullet": 0.3, "tracked": false, "standoff": 0.0,
		"seats": [
			{"o": Vector3(0.5, 1.6, 2.3), "role": "driver", "pose": "sit", "face": 0.0},
			{"o": Vector3(0.0, 1.6, -1.0), "role": "pass", "pose": "hidden", "face": 0.0}]},
	"tank": {"name": "Tank", "len": 6.6, "wid": 3.3, "speed": 7.5, "rev": 3.5, "accel": 3.5, "turn": 0.85, "hp": 1800.0,
		"bullet": 0.0, "tracked": true, "standoff": 50.0,
		"seats": [
			{"o": Vector3(0.6, 1.0, 1.6), "role": "driver", "pose": "hidden", "face": 0.0},
			{"o": Vector3(0.0, 2.25, -0.2), "role": "gunner", "pose": "hidden", "face": 0.0},
			{"o": Vector3(0.5, 2.35, -0.4), "role": "pass", "pose": "hatch", "face": 0.0, "turret": true},
			# infantry riding on the engine deck, legs over the side
			{"o": Vector3(1.05, 1.95, -1.6), "role": "pass", "pose": "sit", "face": -PI / 2.0, "rider": true},
			{"o": Vector3(-1.05, 1.95, -1.6), "role": "pass", "pose": "sit", "face": PI / 2.0, "rider": true},
			{"o": Vector3(1.05, 1.95, -2.5), "role": "pass", "pose": "sit", "face": -PI / 2.0, "rider": true},
			{"o": Vector3(-1.05, 1.95, -2.5), "role": "pass", "pose": "sit", "face": PI / 2.0, "rider": true}]},
}

const L_VEH = 8

var kind = "jeep"
var heavy = false        # a heavy tank: a tank with thicker armour, a bigger gun, and slower
var spec: Dictionary
var team = 0
var pos = Vector3.ZERO
var yaw = 0.0
var pitch = 0.0
var roll = 0.0
var speed = 0.0
var hp = 400.0
var dead = false
var dead_t = 0.0
var seats: Array = []          # soldier or null per seat
var body: AnimatableBody3D
var turret: Node3D = null
var gun_pivot: Node3D = null
var wheels: Array = []
var turret_yaw = 0.0           # relative to the hull
var gun_pitch = 0.0
var fire_cd = 0.0
var cannon_cd = 0.0
var burst = 0
var burst_cd = 0.5
var aim_point = Vector3.ZERO
var player_inputs = {"thr": 0.0, "steer": 0.0, "fire": false, "aim": Vector3.ZERO}
# AI driving
var mission = null             # {"type": "deliver", "drop": Vector3, "exit": Vector3, "stage": 0, "wait": 0.0}
var path: Array = []
var path_i = 0
var path_t = 0.0
var goal = Vector3.ZERO
var stuck_t = 0.0
var reverse_t = 0.0
var crew_t = 0.0
var smoke_node = null
var engine_t = 0.0
# damage zones
var tracks_broken = false
var tyres = 0               # tyres shot out (wheeled vehicles)
var fix_by = null           # the crewman out fixing a track or a wheel
var hit_t = -99.0           # when it was last hit
var lights_on = false
var why = ""
var stop_t = 0.0
var wake_t = 0.0
var burn_t = 0.0
var lamps: Node3D = null
var exh_t = 0.0
var cmd_near_t = 0.0
var squeal_t = 0.0
var mark_d = 0.0
var burning = false
var burn_fx = 0.0
var bailed = false
# aircraft
var alt = 0.0                 # height above the ground
var air_vel = Vector3.ZERO
var rotor: Node3D = null
var orbit_a = 0.0
var life_t = -1.0             # gunships called in for a while
var ramp: Node3D = null
var doors: Array = []          # {"n", "open"/"shut" or "slide", "t", "c"}
var shells = 20                # mortar and field-gun rounds
var fuel = 1.0
var towing = null              # the vehicle we're pulling
var tracer_n = 0
var towed_by = null
var bomb_cd = 0.0
var bridge_laid = false
var fuel_said = false
var smoke_cd = 0.0
var radar_t = 0.0
var gun_heat = 0.0             # mounted machine guns overheat
var belt = 100                 # rounds left on the mounted MG's belt
var belt_t = 0.0               # changing the belt: the gunner's hands are busy
var load_t = 0.0               # a mortar round on its way into the tube
var load_target = null
var atload_t = 0.0             # the anti-tank gun's crew ramming the next round home
var round_mesh: MeshInstance3D = null
var supply_t = 0.0
var cmd = null                 # the commander's move order: drive here and wait

static var mats = {}

static func make(kind_: String, team_: int, p: Vector3, yaw_: float) -> Vehicle:
	var v = Vehicle.new()
	if kind_ == "heavytank":
		v.heavy = true
		v.kind = "tank"
		var hs = SPECS["tank"].duplicate(true)
		hs["name"] = "Heavy tank"
		hs["hp"] = 3400.0
		hs["speed"] = 5.2
		hs["rev"] = 2.4
		hs["accel"] = 2.4
		hs["turn"] = 0.6
		hs["len"] = 7.6
		hs["wid"] = 3.8
		for st in hs["seats"]:
			st["o"] = st["o"] * 1.16
		v.spec = hs
	elif kind_ == "plough":
		v.kind = "tank"
		var ps = SPECS["tank"].duplicate(true)
		ps["name"] = "Mine plough tank"
		ps["hp"] = 2100.0
		ps["speed"] = 6.0
		v.spec = ps
		v.set_meta("plough", true)
	else:
		v.kind = kind_
		v.spec = SPECS[kind_]
	v.team = team_
	v.pos = p
	v.yaw = yaw_
	v.hp = v.spec["hp"]
	G.main.add_child(v)
	v._build()
	G.vehicles.append(v)
	if v.spec.get("plane", false):
		v.alt = 75.0
		v.pos.y = v._ground(p.x, p.z) + v.alt
		v.set_meta("dir", Vector3(sin(yaw_), 0, cos(yaw_)))
		v.set_meta("spd", v.spec["speed"])
		v.global_transform = Transform3D(Basis(Vector3.UP, yaw_), v.pos)
		v.body.global_transform = v.global_transform
	elif v.spec.get("air", false):
		v.alt = 35.0
		v.pos.y = v._ground(p.x, p.z) + v.alt
		v.global_transform = Transform3D(Basis(Vector3.UP, yaw_), v.pos)
		v.body.global_transform = v.global_transform
	else:
		v._place(0.0)
	if v.has_meta("plough"):
		VehExt.plough_blade(v)
	return v

static func _m(key: String, c: Color) -> StandardMaterial3D:
	if not mats.has(key):
		var m = StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.85
		mats[key] = m
	return mats[key]

func _box(parent: Node3D, size: Vector3, at: Vector3, c: Color, collide: bool = false) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _m(c.to_html(), c)
	mi.position = at
	parent.add_child(mi)
	if collide:
		var cs = CollisionShape3D.new()
		var bs = BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.position = at
		body.add_child(cs)
	return mi

func _wheel(at: Vector3, r: float, w: float) -> void:
	var mi = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = w
	cm.radial_segments = 10
	mi.mesh = cm
	mi.material_override = _m("tyre", Color(0.08, 0.08, 0.08))
	mi.rotation.z = PI / 2.0
	var hub = Node3D.new()
	hub.position = at
	hub.add_child(mi)
	add_child(hub)
	wheels.append(hub)

func _build() -> void:
	body = AnimatableBody3D.new()
	body.collision_layer = L_VEH
	body.collision_mask = 0
	body.sync_to_physics = false
	body.set_meta("vehicle", self)
	G.main.add_child(body)
	VModel.build(self)
	for s in spec["seats"]:
		seats.append(null)

func seat_xform(i: int) -> Transform3D:
	var sd = spec["seats"][i]
	var xf = global_transform
	if sd.get("turret", false) and turret != null:
		# turn with the gun, around the turret's pivot
		var tp: Vector3 = turret.position
		xf = global_transform * Transform3D(Basis(), tp) * Transform3D(Basis(Vector3.UP, turret_yaw), Vector3.ZERO) * Transform3D(Basis(), -tp)
	return Transform3D(xf.basis * Basis(Vector3.UP, sd["face"]), xf * sd["o"])

func forward() -> Vector3:
	return Vector3(sin(yaw), 0, cos(yaw))

func driver():
	return seats[0]

func gunner():
	for i in range(seats.size()):
		if spec["seats"][i]["role"] == "gunner":
			return seats[i]
	return null

func gunner_seat() -> int:
	for i in range(seats.size()):
		if spec["seats"][i]["role"] == "gunner":
			return i
	return -1

func free_seat(prefer: String = "") -> int:
	if prefer != "":
		for i in range(seats.size()):
			if seats[i] == null and spec["seats"][i]["role"] == prefer:
				return i
	for i in range(seats.size()):
		if seats[i] == null:
			return i
	return -1

func capacity() -> int:
	return seats.size()

func has_gun() -> bool:
	return gun_pivot != null

func center() -> Vector3:
	return pos + Vector3(0, 1.0, 0)

# ---------------------------------------------------------------- placement on the ground
func _ground(x: float, z: float) -> float:
	if spec.get("boat", false):
		return maxf(G.world.ground_y(x, z), G.world.water_level(x, z) - 0.35)
	return G.world.drive_y(x, z)

func _place(dt: float) -> void:
	var f = forward()
	var l = Vector3(cos(yaw), 0, -sin(yaw))
	var hl = spec["len"] * 0.42
	var hw = spec["wid"] * 0.42
	var hf = _ground(pos.x + f.x * hl, pos.z + f.z * hl)
	var hb = _ground(pos.x - f.x * hl, pos.z - f.z * hl)
	var hL = _ground(pos.x + l.x * hw, pos.z + l.z * hw)
	var hR = _ground(pos.x - l.x * hw, pos.z - l.z * hw)
	var tp = -atan2(hf - hb, hl * 2.0)
	var tr = atan2(hL - hR, hw * 2.0)
	var k = 1.0 if dt <= 0.0 else minf(1.0, dt * 8.0)
	pitch = lerpf(pitch, tp, k)
	roll = lerpf(roll, tr, k)
	pos.y = maxf((hf + hb + hL + hR) * 0.25, _ground(pos.x, pos.z) - 0.1)
	if dt > 0.0:
		_suspension(dt)
	global_transform = Transform3D(Basis.from_euler(Vector3(pitch + sus_p, yaw, roll + sus_r)), pos)
	body.global_transform = global_transform

# the hull rocks on its springs: squats as it pulls away, dips its nose when it brakes, leans out on a
# turn, bounces over rough ground, and rocks back when the main gun fires
var sus_p = 0.0
var sus_pv = 0.0
var sus_r = 0.0
var sus_rv = 0.0
var sus_speed = 0.0
var sus_yaw = 0.0

func kick(p: float, r: float = 0.0) -> void:
	sus_pv += p
	sus_rv += r

func _suspension(dt: float) -> void:
	if spec.get("static", false) or spec.get("air", false) or spec.get("boat", false):
		return
	var tracked: bool = spec["tracked"]
	var soft = 0.55 if tracked else 1.0
	var acc = (speed - sus_speed) / dt
	sus_speed = speed
	var yr = G.wrap_a(yaw - sus_yaw) / dt
	sus_yaw = yaw
	var tgt_p = clampf(-acc * 0.014 * soft, -0.07, 0.07)
	var tgt_r = clampf(-yr * speed * 0.012 * soft, -0.06, 0.06)
	# rough ground off the road: little kicks, more the faster it goes
	if absf(speed) > 1.5 and randf() < dt * absf(speed) * 0.5 and not G.world.on_road(pos.x, pos.z):
		sus_pv += randf_range(-0.25, 0.25) * soft
		sus_rv += randf_range(-0.2, 0.2) * soft
	var stiff = 55.0 if tracked else 38.0
	var damp = 7.5 if tracked else 5.0
	sus_pv += ((tgt_p - sus_p) * stiff - sus_pv * damp) * dt
	sus_rv += ((tgt_r - sus_r) * stiff - sus_rv * damp) * dt
	sus_p = clampf(sus_p + sus_pv * dt, -0.12, 0.12)
	sus_r = clampf(sus_r + sus_rv * dt, -0.1, 0.1)

# ---------------------------------------------------------------- per physics tick
func step(dt: float) -> void:
	if not doors.is_empty():
		_doors_tick(dt)
	gun_heat = maxf(0.0, gun_heat - 0.12 * dt)
	if atload_t > 0.0:
		atload_t = maxf(0.0, atload_t - dt)
		if round_mesh != null and (atload_t <= 0.0 or gunner() == null):
			round_mesh.visible = false
		if gunner() == null:
			atload_t = 0.0
	if belt_t > 0.0:
		belt_t -= dt
		if belt_t <= 0.0:
			belt_t = 0.0
			belt = 100
	# a loading drill with nobody left on the gun stops where it is
	if load_t > 0.0 and gunner() == null:
		load_t = 0.0
		load_target = null
		if round_mesh != null:
			round_mesh.visible = false
	if kind == "radar" and not dead:
		VehExt.radar_tick(self, dt)
	# mortars and field guns restock from nearby ammo crates, FOBs and supply dumps
	if (kind == "mortar" or kind == "artillery") and shells < 20:
		supply_t += dt
		if supply_t > 8.0:
			supply_t = 0.0
			for a in G.world.ammo_points:
				if (a["team"] == team or a["team"] < 0) and G.dist2d(a["p"], pos) < 40.0:
					shells = mini(20, shells + 4)
					break
	if dead:
		dead_t += dt
		speed = move_toward(speed, 0.0, 10.0 * dt)
		# wrecks stay where they died, smouldering, for a few minutes; ones blocking a road or a spawn
		# (or one too many on the map) get towed away sooner
		if not spec.get("plane", false):
			if not has_meta("wreck_life"):
				var blocking = G.world.near_road(pos.x, pos.z, 3.5)
				for t in range(G.team_count()):
					if G.dist2d(G.world.rally_point(t), pos) < 30.0:
						blocking = true
				set_meta("wreck_life", 25.0 if blocking else randf_range(150.0, 200.0))
			var life: float = get_meta("wreck_life")
			if life > 25.0 and dead_t > 25.0 and int(dead_t * 2.0) % 10 == 0:
				var wrecks = G.vehicles.filter(func(o): return o.dead and not o.spec.get("plane", false))
				if wrecks.size() > 8:
					wrecks.sort_custom(func(a, b): return a.dead_t > b.dead_t)
					if wrecks[0] == self:
						set_meta("wreck_life", dead_t)
						life = dead_t
			# the fire dies down after the first minute or so, the smoke goes on
			if dead_t < minf(life, 70.0) and int(dead_t * 60.0) % 9 == 0 and visible:
				G.fx.flame_puff(center() + Vector3(randf_range(-0.7, 0.7), 0.6, randf_range(-0.7, 0.7)), Vector3(0, 2.5, 0), 0.9)
			if dead_t > life - 5.0:
				position.y -= dt * 0.6
			if dead_t > life:
				remove()
				return
		if spec.get("plane", false):
			VehExt.plane_step(self, dt)
		return
	if burning:
		_burn_tick(dt)
		if dead:
			return
	if spec.get("air", false):
		_air_step(dt)
		return
	if towed_by != null and is_instance_valid(towed_by):
		_crew_tick(dt)
		return
	if spec.get("static", false):
		_weapons(dt)
		_crew_tick(dt)
		return
	var thr = 0.0
	var steer = 0.0
	var d = driver()
	if d != null and is_instance_valid(d) and d.state == "riding":
		if d.is_player:
			thr = player_inputs["thr"]
			steer = player_inputs["steer"]
		else:
			# the AI driver thinks every other tick (twice the time step when it does): a big saving with
			# a lot of vehicles about, and nobody can tell
			if _drive_cache.is_empty() or (Engine.get_physics_frames() + get_instance_id()) % 2 == 0:
				_drive_cache = _ai_drive(dt * (1.0 if _drive_cache.is_empty() else 2.0))
			thr = _drive_cache[0]
			steer = _drive_cache[1]
	_trail_tick()
	thr = VehExt.fuel_tick(self, dt, thr)
	if tracks_broken:
		thr = 0.0
		steer *= 0.3 if spec["tracked"] else 1.0
	elif tyres > 0:
		thr *= maxf(0.25, 1.0 - 0.25 * tyres)
	var top = spec["speed"] if thr >= 0.0 else spec["rev"]
	var target = thr * top
	if thr == 0.0:
		speed = move_toward(speed, 0.0, 6.0 * dt)
	elif signf(target) != signf(speed) and absf(speed) > 0.3:
		speed = move_toward(speed, 0.0, 12.0 * dt)
	else:
		speed = move_toward(speed, target, spec["accel"] * dt)
	var turn_k = 1.0 if spec["tracked"] else clampf(absf(speed) / 4.0, 0.0, 1.0)
	var dir_k = -1.0 if speed < -0.1 else 1.0
	yaw += steer * spec["turn"] * turn_k * dir_k * dt
	var f = forward()
	var np = pos + f * speed * dt
	# walls, crates and other vehicles
	var bumped = false
	var r_ = spec["wid"] * 0.5
	var n = int(ceil(spec["len"] / spec["wid"]))
	for k in range(n + 1):
		var off = (float(k) / float(n) - 0.5) * (spec["len"] - spec["wid"])
		var c = np + f * off
		var res = G.world.push_out_circle(c, r_)
		if res[1] != null:
			var col = res[1]
			# tanks flatten crates and flimsy walls; anything fast smashes crates
			# hedges and bushes: anything with wheels or tracks pushes straight through and flattens them
			var hedge = col.prop == 2 and not col.has_meta("tree") and not spec.get("boat", false)
			if col.dest and (spec["tracked"] or hedge or _drives_through(col) or (col.prop == 1 and absf(speed) > 3.0 and not col.has_meta("tree"))):
				if col.has_meta("tree"):
					col.set_meta("fall", f * signf(speed if speed != 0.0 else 1.0))
				G.world.destroy_col(col)
				if hedge:
					G.fx.dust_cloud(c, 1.0)
				speed *= 0.85
				continue
			np += res[0] - c
			bumped = true
	# other vehicles: each is a capsule along its length; overlapping capsules push apart
	var ra = spec["wid"] * 0.5
	var ha = maxf(0.0, spec["len"] * 0.5 - ra)
	for o in G.vehicles:
		if o == self or (o.spec.get("air", false) and o.alt > 3.0) or spec.get("air", false):
			continue
		if absf(o.pos.x - np.x) > 14.0 or absf(o.pos.z - np.z) > 14.0:
			continue
		var rb = o.spec["wid"] * 0.5
		var hb = maxf(0.0, o.spec["len"] * 0.5 - rb)
		var fo = o.forward()
		var cl = _seg_closest(np - f * ha, np + f * ha, o.pos - fo * hb, o.pos + fo * hb)
		var dv = G.flat(cl[0] - cl[1])
		var dl = dv.length()
		var md = ra + rb + 0.15
		if dl < md:
			var nrm = dv / dl if dl > 0.01 else G.flat(np - o.pos).normalized()
			if nrm.length_squared() < 0.01:
				nrm = Vector3(1, 0, 0)
			# the one that's moving does the giving way; a parked or wrecked one stays put
			np += nrm * (md - dl)
			bumped = true
	if bumped and absf(speed) > 3.0:
		speed *= 0.4
		G.audio.hit_tick(false)
	elif bumped:
		speed *= 0.8
	if not G.world.water.is_empty():
		var wet = G.world.in_water(np.x + f.x * spec["len"] * 0.4 * signf(speed if speed != 0.0 else 1.0), np.z + f.z * spec["len"] * 0.4 * signf(speed if speed != 0.0 else 1.0))
		if spec.get("boat", false):
			if not wet and G.world.ground_y(np.x, np.z) > G.world.water_level(np.x, np.z) - 0.2:
				np = pos       # run aground
				speed = 0.0
		elif wet:
			np = pos
			speed = 0.0
		if not spec.get("boat", false) and G.world.in_water(pos.x, pos.z):
			# went into the river (a bridge came down under it)
			destroy(null)
			return
	var b = G.world.bounds
	if mission == null:
		np.x = clampf(np.x, b.position.x + 3.0, b.end.x - 3.0)
		np.z = clampf(np.z, b.position.y + 3.0, b.end.y - 3.0)
	pos = np
	# boats leave a white wake behind them
	if spec.get("boat", false) and absf(speed) > 1.2:
		wake_t -= dt
		if wake_t <= 0.0:
			wake_t = 0.12
			var stern = pos - forward() * spec["len"] * 0.45 * signf(speed)
			var wl = G.world.water_level(stern.x, stern.z)
			G.fx.wake(Vector3(stern.x, wl, stern.z), -forward() * signf(speed), spec["wid"] * 0.45 * clampf(absf(speed) / 5.0, 0.5, 1.2))
			if randf() < 0.3:
				var bow = pos + forward() * spec["len"] * 0.45
				G.fx.splash(Vector3(bow.x, wl, bow.z), 0.3)
	_place(dt)
	if not spec.get("boat", false):
		VehExt.ground_tick(self, dt, thr)
	if towing != null or has_meta("tow_target") or has_meta("tow_bar"):
		VehExt.tow_tick(self, dt)
	_hit_people(f)
	for w in wheels:
		w.rotation.x += speed * dt / 0.45
	_weapons(dt)
	_crew_tick(dt)
	engine_t -= dt
	if engine_t <= 0.0 and driver() != null:
		engine_t = 0.35
		G.audio.engine(pos, absf(speed) / spec["speed"], spec["tracked"])
	if spec["tracked"] and absf(steer) > 0.55 and absf(speed) > 0.8:
		squeal_t -= dt
		if squeal_t <= 0.0:
			squeal_t = randf_range(1.2, 2.4)
			G.audio.squeal(pos)

func _hit_people(f: Vector3) -> void:
	var l = Vector3(cos(yaw), 0, -sin(yaw))
	var hl = spec["len"] * 0.5 + 0.25
	var hw = spec["wid"] * 0.5 + 0.25
	for s in G.soldiers:
		if s.vehicle == self or s.state == "riding":
			continue
		var p: Vector3 = s.pos if s.state == "alive" or s.state == "getup" else s.parts[0].global_position
		var rel = G.flat(p - pos)
		var a = rel.dot(f)
		var bb = rel.dot(l)
		if absf(a) > hl or absf(bb) > hw or absf(p.y - pos.y) > 2.0:
			continue
		if s.team == team and s.state == "alive":
			# our own people get bundled out of the way, never run down
			var side0 = l * (1.0 if bb >= 0.0 else -1.0)
			s.pos += side0 * (hw - absf(bb)) * 0.8
			s.pos = G.world.push_out_circle(s.pos, 0.33)[0]
			continue
		if (s.state == "alive" or s.state == "getup") and absf(speed) > 2.5 and s.team != team:
			# run over
			var dmg = speed * speed * 0.7
			var drv = driver()
			s.fall(2.0)
			s.push(1, f * speed * 0.9 * signf(speed) + Vector3(0, 2.5, 0), 0.6)
			Combat.hit_soldier(s, 1, s.chest(), f * signf(speed), dmg, drv if (drv != null and is_instance_valid(drv)) else null, 2.0)
		elif s.state == "alive":
			# shove aside
			var side = l * (1.0 if bb >= 0.0 else -1.0)
			s.pos += side * (hw - absf(bb)) * 0.5
			s.pos = G.world.push_out_circle(s.pos, 0.33)[0]

# ---------------------------------------------------------------- weapons
func _gun_dir() -> Vector3:
	if gun_pivot == null:
		return forward()
	return gun_pivot.global_transform.basis.z.normalized()

func muzzle() -> Vector3:
	if gun_pivot == null:
		return center()
	return gun_pivot.global_transform * Vector3(0, 0.02, {"jeep": 1.45, "nest": 1.3, "mortar": 1.15, "halftrack": 1.35, "motorbike": 0.65, "armoredcar": 1.7, "artillery": 3.4, "gunship": 0.95, "atgun": 2.7, "technical": 1.45}.get(kind, 3.7))

func _weapons(dt: float) -> void:
	fire_cd -= dt
	cannon_cd -= dt
	if turret == null:
		return
	var g = gunner()
	var controller = g
	var drv = driver()
	if g == null and drv != null and is_instance_valid(drv) and drv.is_player and kind in ["tank", "gunship", "armoredcar"]:
		controller = drv          # a lone player in a tank works the gun too
	if controller == null or not is_instance_valid(controller) or controller.state != "riding":
		return
	var want = null
	var shoot = false
	var use_cannon = false
	if controller.is_player:
		want = player_inputs["aim"]
		shoot = player_inputs["fire"]
		use_cannon = (kind == "tank" and not Input.is_key_pressed(KEY_SHIFT)) or kind == "armoredcar"
	else:
		var t = _ai_gun_target(controller)
		if t != null:
			want = t[0]
			use_cannon = t[1]
			shoot = true
	if kind == "mortar" and load_t > 0.0:
		_mortar_load(controller, dt)
		return
	if kind == "mortar" or kind == "artillery":
		_mortar(controller, dt, want, shoot)
		return
	if kind == "atgun":
		_atgun(controller, dt, want, shoot)
		return
	if want == null:
		# no target: watch where the enemy was last seen, or sweep the front
		var look = 0.0
		if not controller.is_player and controller.has_threat and G.sim_time - controller.seen_t < 30.0:
			var lt = global_transform.affine_inverse() * controller.threat
			look = atan2(lt.x, lt.z)
		elif not spec.get("air", false):
			look = sin(G.sim_time * 0.35 + float(get_instance_id() % 97)) * (0.9 if kind in ["jeep", "halftrack", "nest", "motorbike"] else 0.5)
		turret_yaw = turret_yaw + clampf(wrapf(look - turret_yaw, -PI, PI), -0.9 * dt, 0.9 * dt)
		gun_pitch = lerpf(gun_pitch, 0.0, dt)
		_apply_turret()
		return
	aim_point = want
	# rotate the turret toward the target at a limited speed
	var local = global_transform.affine_inverse() * want
	var ty = atan2(local.x, local.z) - turret.position.x * 0.0
	var rate = 1.1 if kind == "tank" else 3.5
	turret_yaw = turret_yaw + clampf(wrapf(ty - turret_yaw, -PI, PI), -rate * dt, rate * dt)
	var piv = gun_pivot.global_position
	var flat_d = G.dist2d(want, piv)
	var tp = atan2(want.y - piv.y, flat_d) - pitch * cos(turret_yaw)
	var pmax = 1.45 if kind == "aagun" else (0.9 if kind == "bomber" else 0.4)
	var pmin = -0.15 if kind in ["tank", "jeep", "technical"] else -0.35     # mounted guns can't point down into their own car
	gun_pitch = clampf(gun_pitch + clampf(tp - gun_pitch, -1.5 * dt, 1.5 * dt), pmin, pmax)
	_apply_turret()
	var err = absf(wrapf(ty - turret_yaw, -PI, PI))
	if not shoot or err > 0.08:
		return
	var dir = (want - muzzle()).normalized()
	if not controller.is_player:
		if AI.friendly_in_line(controller, muzzle(), dir, muzzle().distance_to(want)) != null:
			return
	if use_cannon and kind == "armoredcar":
		if cannon_cd <= 0.0:
			cannon_cd = 0.45
			Combat.launch_shell(self, controller, muzzle(), Combat.spread_dir(_gun_dir(), 0.008), 0.5, 140.0, 110.0)
			G.fx.muzzle(muzzle(), false)
			G.audio.shot(muzzle(), G.WEAPONS["atrifle"])
	elif use_cannon:
		if cannon_cd <= 0.0:
			cannon_cd = 5.5 if heavy else 4.5
			if heavy:
				Combat.launch_shell(self, controller, muzzle(), _gun_dir(), 2.0, 1050.0, 160.0)
			else:
				Combat.launch_shell(self, controller, muzzle(), _gun_dir())
			G.fx.muzzle(muzzle(), true)
			# the whole hull rocks back on its springs with the shot
			var lg = global_transform.basis.inverse() * _gun_dir()
			kick(lg.z * 0.9, -lg.x * 0.6)
			G.audio.boom(muzzle())
			Combat.shake = maxf(Combat.shake, 0.3 if controller.is_player else 0.0)
			# shoot and scoot: after a shot at armour an AI tank backs off a few metres out of the
			# spot it gave away, then comes forward again
			if not controller.is_player and spec["tracked"] and _armour_near(110.0) != null and driver() != null and not driver().is_player and cmd == null:
				set_meta("scoot_until", G.sim_time + 2.6)
	else:
		if not controller.is_player:
			if burst <= 0:
				burst_cd -= dt
				if burst_cd <= 0.0:
					burst = randi_range(6, 16)
					burst_cd = randf_range(0.6, 1.4)
				return
		if fire_cd <= 0.0:
			fire_cd = 0.085 if kind != "aagun" else 0.055
			burst -= 1
			# a fresh belt every hundred rounds: the gunner opens the cover, lays the belt in and slaps it shut
			if belt_t > 0.0:
				return
			if belt <= 0 and kind != "aagun":
				belt_t = 3.4
				if controller.is_player:
					G.ui.message("Belt's empty: changing it…")
				elif randf() < 0.6:
					G.fx.callout(controller, G.pick(["Reloading!", "Changing belts!", "New belt!"]))
				return
			belt -= 1
			gun_heat += 0.007 if kind != "aagun" else 0.004
			if gun_heat >= 1.0:
				# overheated: wait for the barrel to be swapped
				fire_cd = 5.0
				gun_heat = 0.35
				if controller.is_player:
					G.ui.message("Gun overheated, changing the barrel…")
				else:
					G.fx.callout(controller, G.pick(["Barrel's glowing! Changing it!", "Overheated!"]))
				return
			var W = G.WEAPONS["hmg"]
			var spread = W["spread"] + (0.008 if absf(speed) > 1.0 else 0.0) + (0.02 if kind == "aagun" else 0.0)
			tracer_n += 1
			Combat.bright = tracer_n % 4 == 0
			Combat.fire_ray(controller, muzzle(), Combat.spread_dir(_gun_dir(), spread), W, true, [body.get_rid()])
			Combat.bright = false
			G.fx.muzzle(muzzle(), false)
			G.audio.shot(muzzle(), W)

# the anti-tank gun: only fires from a standstill, armour-piercing at tanks, high explosive at groups of infantry
func _atgun(g, dt: float, want, shoot: bool) -> void:
	if want == null:
		gun_pitch = lerpf(gun_pitch, 0.0, dt)
		_apply_turret()
		return
	aim_point = want
	var local = global_transform.affine_inverse() * want
	var ty = atan2(local.x, local.z)
	# a small traverse on the carriage; beyond that the crew heaves the trails round
	var lim = 0.55
	turret_yaw = clampf(turret_yaw + clampf(wrapf(ty - turret_yaw, -PI, PI), -0.9 * dt, 0.9 * dt), -lim, lim)
	if absf(wrapf(ty, -PI, PI)) > lim and absf(speed) < 0.2:
		yaw += clampf(wrapf(ty, -PI, PI), -0.35 * dt, 0.35 * dt)
		rotation.y = yaw
	var piv = gun_pivot.global_position
	var tp = atan2(want.y - piv.y, G.dist2d(want, piv))
	gun_pitch = clampf(gun_pitch + clampf(tp - gun_pitch, -1.0 * dt, 1.0 * dt), -0.12, 0.3)
	_apply_turret()
	if not shoot or absf(speed) > 0.3 or cannon_cd > 0.0 or atload_t > 0.0 or absf(wrapf(ty - turret_yaw, -PI, PI)) > 0.05:
		return
	if not g.is_player and AI.friendly_in_line(g, muzzle(), (want - muzzle()).normalized(), muzzle().distance_to(want)) != null:
		return      # one of ours in the way
	set_meta("fire_t", G.sim_time)
	# the breech opens, the case is thrown out, and the next round has to be fetched and rammed home
	atload_t = 2.3
	_make_round()
	var gdir = _gun_dir()
	var side = Vector3(gdir.z, 0, -gdir.x)
	G.fx.debris(gun_pivot.global_position - gdir * 0.6 + Vector3(0, 0.05, 0), -gdir * 3.5 + side * randf_range(-0.6, 0.6) + Vector3(0, 1.6, 0), 0.06, Color(0.78, 0.62, 0.3), Vector3(0.07, 0.07, 0.42))
	var ap = _at_target_is_vehicle
	cannon_cd = (3.6 if ap else 6.5) if not g.is_player else 2.5
	if ap:
		Combat.launch_shell(self, g, muzzle(), Combat.spread_dir(_gun_dir(), 0.004), 0.9, 820.0, 170.0)
	else:
		Combat.launch_shell(self, g, muzzle(), Combat.spread_dir(_gun_dir(), 0.012), 1.05, 120.0, 130.0)
	G.fx.muzzle(muzzle(), true)
	G.fx.dust_cloud(muzzle() - _gun_dir() * 0.4 + Vector3(0, -0.6, 0), 2.2)
	G.audio.boom(muzzle())
	if g.is_player:
		Combat.shake = maxf(Combat.shake, 0.25)
	elif randf() < 0.35:
		G.fx.callout(g, G.pick(["On the way!", "Fire!", "Reload, AP!", "Shot!"]) if ap else G.pick(["HE out!", "Fire!"]))

var _at_target_is_vehicle = false

# the nearest enemy armour (tanks, armoured cars, AT guns) this side knows about, within r
func _armour_near(r: float):
	var best = null
	var bd = r
	for o in G.vehicles:
		if o.team != team and o.team >= 0 and not o.dead and (o.spec["tracked"] or o.kind in ["armoredcar", "atgun"]) and not o.spec.get("air", false):
			var d = G.dist2d(o.pos, pos)
			if d < bd and not G.blocked(center() + Vector3(0, 1.0, 0), o.center() + Vector3(0, 0.6, 0)):
				bd = d
				best = o
	return best

# where an anti-tank gun sets up: behind the team's own line, picked once and moved only after a long quiet spell
func _at_post():
	if G.mode == "sandbox" or team < 0:
		return null
	var quiet = G.sim_time - get_meta("fire_t", -99.0) > 90.0
	if not has_meta("post") or (quiet and G.sim_time - get_meta("post_t", 0.0) > 150.0):
		var p: Vector3 = Reinforce.forward_drop(team)
		var home: Vector3 = G.world.rally_point(team)
		# no closer to the enemy than a third of the way out from home
		var cap = home.lerp(G.world.capture, 0.4)
		if G.dist2d(p, home) > G.dist2d(cap, home):
			p = cap
		set_meta("post", G.main._free_spot(p))
		set_meta("post_t", G.sim_time)
	return get_meta("post")

func _apply_turret() -> void:
	turret.rotation.y = turret_yaw
	if kind != "mortar" and kind != "artillery":
		gun_pivot.rotation.x = -gun_pitch

# mortars lob shells at enemies anyone on the team has spotted (or where the player clicks)
func _mortar(g, dt: float, want, shoot: bool) -> void:
	var target = null
	if g.is_player:
		if shoot and want != null:
			target = want
	elif cannon_cd > 0.0:
		return
	else:
		cannon_cd = 1.0      # look for a target about once a second
		var best = 0
		for o in G.soldiers:
			if o.team == team or o.state == "dead" or o.hidden_in_vehicle or G.near_spawn(o.pos):
				continue
			var d = G.dist2d(o.pos, pos)
			if d < (60.0 if kind == "artillery" else 30.0) or d > (900.0 if kind == "artillery" else 240.0):
				continue
			var spotted = false
			for f in G.soldiers:
				if f.team == team and f.state != "dead" and f.intel.has(o) and f.intel[o]["seen"] and G.sim_time - f.intel[o]["t"] < 8.0:
					spotted = true
					break
			if not spotted:
				continue
			var near_friend = false
			for f in G.soldiers:
				if f.team == team and f.state != "dead" and G.dist2d(f.pos, o.pos) < 14.0:
					near_friend = true
					break
			if near_friend:
				continue
			var n = 0
			for o2 in G.soldiers:
				if o2.team == o.team and o2.state != "dead" and G.dist2d(o2.pos, o.pos) < 10.0:
					n += 1
			if n > best:
				best = n
				target = o.pos
	if target == null:
		return
	if not g.is_player:
		cannon_cd = 0.0     # the search above held it a second; a target found fires now
	var local = global_transform.affine_inverse() * target
	turret_yaw = turret_yaw + clampf(wrapf(atan2(local.x, local.z) - turret_yaw, -PI, PI), -1.5 * dt, 1.5 * dt)
	_apply_turret()
	gun_pivot.rotation.x = -0.95 if kind == "mortar" else -0.5
	if cannon_cd > 0.0:
		return
	var arty = kind == "artillery"
	if shells <= 0:
		cannon_cd = 6.0
		if g.is_player:
			G.ui.message("Out of rounds. Bring the gun near an ammo crate, FOB or supply dump")
		elif randf() < 0.3:
			G.fx.callout(g, G.pick(["Out of rounds!", "Need more shells here!"]))
		return
	shells -= 1
	cannon_cd = (9.0 if arty else 5.5) if not g.is_player else (5.0 if arty else 3.0)
	if kind == "mortar":
		# the round goes in by hand: picked from the box, held over the tube, dropped, and the crew ducks
		load_t = 1.9
		load_target = target
		return
	_shoot_shell(g, target)

func _shoot_shell(g, target: Vector3) -> void:
	var arty = kind == "artillery"
	var dist = G.dist2d(target, pos)
	G.fx.muzzle(muzzle(), true)
	G.audio.boom(muzzle())
	Combat.shell_at(target, (5.0 + dist * 0.03) if arty else (3.0 + dist * 0.05), (4.0 + dist / 160.0) if arty else (2.5 + dist / 90.0), g, 1.9 if arty else 1.2, team)
	if not g.is_player and randf() < 0.3:
		G.fx.callout(g, G.pick(["Round out!", "Shot over!", "Firing for effect!"]))

# the round the loader carries in his hands: a finned mortar bomb or a brass anti-tank shell
func _make_round() -> void:
	if round_mesh != null:
		return
	round_mesh = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	var at = kind == "atgun"
	cm.top_radius = 0.035 if at else 0.045
	cm.bottom_radius = 0.045 if at else 0.055
	cm.height = 0.6 if at else 0.42
	round_mesh.mesh = cm
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(0.78, 0.62, 0.3) if at else Color(0.42, 0.46, 0.3)
	m.metallic = 0.5 if at else 0.0
	round_mesh.material_override = m
	round_mesh.visible = false
	add_child(round_mesh)

# the loading drill: where the round is through it, and the shot when it drops in
func _mortar_load(g, dt: float) -> void:
	var before = load_t
	load_t -= dt
	_make_round()
	var k = 1.0 - load_t / 1.9
	if load_target != null:
		var lt = global_transform.affine_inverse() * load_target
		turret_yaw = turret_yaw + clampf(wrapf(atan2(lt.x, lt.z) - turret_yaw, -PI, PI), -1.5 * dt, 1.5 * dt)
		_apply_turret()
	round_mesh.visible = k > 0.18 and k < 0.66
	# it fires the moment the round reaches the bottom of the tube
	if before > 0.55 and load_t <= 0.55 and load_target != null:
		round_mesh.visible = false
		_shoot_shell(g, load_target)
		if not g.is_player and randf() < 0.3:
			G.fx.callout(g, G.pick(["Round out!", "Shot over!", "Firing for effect!"]))
	if load_t <= 0.0:
		load_t = 0.0
		load_target = null

# what should an AI gunner shoot at? returns [point, use_cannon] or null
func _ai_gun_target(g):
	var best = null
	var bd = 1e9
	# enemy vehicles first for the cannon
	if kind == "tank" or kind == "armoredcar":
		for o in G.vehicles:
			if o.team != team and o.team >= 0 and not o.dead and o.pos.distance_to(pos) < 160.0 and not G.blocked(muzzle(), o.center()):
				var d = o.pos.distance_to(pos)
				if d < bd:
					bd = d
					best = [o.center(), true]
		if best != null:
			return best
	if kind == "aagun" or kind == "bomber":
		return VehExt.aa_target(self)
	if kind == "atgun":
		_at_target_is_vehicle = false
		for o in G.vehicles:
			if o.team != team and o.team >= 0 and not o.dead and not o.spec.get("air", false) and o.pos.distance_to(pos) < (85.0 if o.spec.get("static", false) or o.kind == "atgun" else 160.0) and not G.blocked(muzzle(), o.center()):
				var d = o.pos.distance_to(pos)
				if d < bd:
					bd = d
					best = [o.center(), true]
		if best != null:
			_at_target_is_vehicle = true
			return best
		var tg = g.vis_t
		if tg != null and is_instance_valid(tg) and tg.state != "dead" and tg.pos.distance_to(pos) > 20.0:
			var near = 0
			for o in G.soldiers_near(tg.pos):
				if o.team != team and o.state != "dead":
					near += 1
			if near >= 3 or (tg.in_cover and near >= 2):
				return [tg.chest(), false]
		return null
	var tgt = g.vis_t
	if tgt == null or not is_instance_valid(tgt) or tgt.state == "dead":
		# nobody to shoot: tanks and armoured cars knock down enemy positions in view
		if (kind == "tank" or kind == "armoredcar") and cannon_cd <= 0.0:
			var es = Build.enemy_site_near(team, pos, 110.0)
			if es != null and Build.sees(muzzle(), es[0]):
				return [es[1] + Vector3(0, 0.8, 0), true]
		return null
	var p = tgt.chest()
	var d2 = p.distance_to(pos)
	if kind == "armoredcar":
		return [p, true]
	if kind == "tank":
		# shell groups and soldiers in cover; machine gun the rest
		var near = 0
		for o in G.soldiers:
			if o.team != team and o.state != "dead" and o.pos.distance_to(tgt.pos) < 6.0:
				near += 1
		return [p, d2 > 18.0 and (near >= 2 or tgt.in_cover or cannon_cd <= 0.0)]
	return [p, false]

# ---------------------------------------------------------------- crew
func _crew_tick(dt: float) -> void:
	_bail_check()
	_self_repair()
	_riders_tick()
	_lights_tick()
	for i in range(seats.size()):
		var s = seats[i]
		if s != null and (not is_instance_valid(s) or s.vehicle != self):
			seats[i] = null
	# empty driver or gunner seats: a nearby friendly soldier with nothing better to do climbs in
	crew_t -= dt
	if crew_t > 0.0 or burning or bailed or (mission != null and not mission.get("type", "") in ["escort", "ferry"]):
		return
	crew_t = 3.0 if mission == null else 1.5
	for role in ["driver", "gunner"]:
		var si = -1
		for i in range(seats.size()):
			if seats[i] == null and spec["seats"][i]["role"] == role:
				si = i
		if si < 0:
			continue
		# someone already aboard slides over into the empty seat
		var moved = false
		for i in range(seats.size()):
			var ps = seats[i]
			if ps != null and is_instance_valid(ps) and not ps.is_player and spec["seats"][i]["role"] == "pass":
				ps.dismount(false)
				if ps.mount(self, si):
					G.fx.callout(ps, "I've got the wheel!" if role == "driver" else "On the gun!")
					moved = true
				break
		if moved:
			continue
		var best = null
		var bd = 30.0
		for s in G.soldiers:
			if s.team == team and s.state == "alive" and not s.is_player and s.vehicle == null and s.task != "board" and s.task != "fixwheel" and not s.broken and s.vis_t == null and G.sim_time > s.no_board_t and s.order == null:
				var dd = G.dist2d(s.pos, pos)
				if dd < bd:
					bd = dd
					best = s
		if best != null:
			best.board_target = self
			best.task = "board"
			AI.release_cover(best)
			AI.go_to(best, pos, 5.0)
			G.fx.callout(best, G.pick(["I'll take the wheel!", "Manning the gun!", "Getting in!"]) if role == "gunner" else "I'll drive!")

func take_damage(amount: float, attacker, at: Vector3) -> void:
	if dead:
		return
	if Prod.has(team, "armour"):
		amount *= 0.67
	# armour is thickest at the front: a heavy round into the side goes through more easily, into the
	# back easier still
	if amount >= 60.0 and (spec["tracked"] or kind in ["armoredcar", "halftrack"]):
		var lpa = global_transform.affine_inverse() * at
		var fz = lpa.z / maxf(0.5, spec["len"] * 0.5)
		var sx = absf(lpa.x) / maxf(0.5, spec["wid"] * 0.5)
		if fz > 0.55 and sx < 0.85:
			amount *= 0.6
		elif fz < -0.55:
			amount *= 1.5
		else:
			amount *= 1.15
	# vehicles are tougher than a run of hits suggests: rifle fire and near misses chip at them, and it
	# takes a proper anti-tank weapon (or a lot of everything else) to finish one
	if amount < 900.0:
		amount *= 0.65 if amount < 60.0 else 0.8
	if has_meta("plough") and G.sim_time - get_meta("plough_t", -9.0) < 0.15:
		amount *= 0.08          # the plough takes the blast
	hit_t = G.sim_time
	if amount >= 60.0:
		heavy_t = G.sim_time
		if attacker != null and is_instance_valid(attacker):
			hit_from = attacker.pos
		else:
			hit_from = at
	# a round into a tyre: it goes flat and the vehicle limps
	if not spec["tracked"] and not spec.get("air", false) and not spec.get("static", false) and not spec.get("boat", false) and tyres < 4 and amount < 200.0:
		var lp = global_transform.affine_inverse() * at
		if lp.y < 1.0 and absf(lp.x) > spec["wid"] * 0.3 and randf() < 0.22:
			tyres += 1
			_flat_tyre(lp)
			if tyres == 1:
				G.ui.radio(team, "%s has a tyre shot out" % spec["name"])
	hp -= amount
	# where it was hit matters: tracks and running gear along the sides, the engine up front
	if amount >= 120.0 and not spec.get("air", false) and not spec.get("static", false):
		var local = global_transform.affine_inverse() * at
		if (spec["tracked"] or kind == "halftrack") and absf(local.x) > spec["wid"] * 0.36 and local.y < 1.3 and randf() < 0.5 and not tracks_broken:
			tracks_broken = true
			G.ui.radio(team, "%s tracks knocked out!" % spec["name"])
		if not burning and randf() < (0.2 if local.z > spec["len"] * 0.15 else 0.08):
			burning = true
			G.ui.radio(team, "%s on fire!" % spec["name"])
	if amount >= 150.0 and (spec["tracked"] or kind == "armoredcar" or kind == "halftrack") and G.sim_time > smoke_cd and not dead:
		VehExt.pop_smoke(self, at)
	if amount >= 60.0 and not spec.get("plane", false):
		VehExt.dent(self, at)
		VehExt.soot(self, at)
		if hp < spec["hp"] * 0.55 and randf() < 0.3:
			VehExt.lose_door(self)
	# damage you can read from across the field: grey wisps from the engine when it's been hurt,
	# thick black smoke when it's badly hit
	if hp < spec["hp"] * 0.7 and not has_meta("dmg_smoke") and not spec.get("air", false):
		set_meta("dmg_smoke", G.fx.wreck_smoke(center() + forward() * spec["len"] * 0.3 + Vector3(0, 0.6, 0), self, Color(0.62, 0.62, 0.6, 0.35), 14))
	if hp < spec["hp"] * 0.35 and smoke_node == null:
		smoke_node = G.fx.wreck_smoke(center(), self)
	if hp <= 0.0:
		destroy(attacker)

func destroy(attacker) -> void:
	if dead:
		return
	dead = true
	hp = 0.0
	burning = false
	G.fx.explosion(center(), 1.4)
	G.audio.boom(center())
	if smoke_node == null:
		G.fx.wreck_smoke(center(), self)
		smoke_node = true
	_wreck_paint(self)
	if kind in ["tank", "armoredcar"] and randf() < 0.45:
		VehExt.blow_turret(self)
	if towing != null and is_instance_valid(towing):
		towing.towed_by = null
		towing = null
	if kind == "radar":
		G.ui.radio(team, "Our command truck is destroyed! We're blind out here")
		for t in range(G.team_count()):
			if t != team:
				G.ui.radio(t, "Enemy command truck destroyed")
		if team < Commander.timers.size():
			Commander.timers[team] = maxf(Commander.timers[team], 30.0)
	# shot down with height to spare: the crew bail out and come down under parachutes
	var bail = spec.get("plane", false) and alt > 22.0
	for i in range(seats.size()):
		var s = seats[i]
		if s != null and is_instance_valid(s) and bail and randf() < 0.8:
			s.dismount(true)
			s.start_chute(pos + Vector3(randf_range(-2, 2), -2.5, randf_range(-2, 2)))
			s.vel = G.flat(air_vel) * 0.12
			s.hp = minf(s.hp, randf_range(55.0, 100.0))
			G.fx.callout(s, G.pick(["Bailing out!", "I'm hit, I'm getting out!", "Eject! Eject!", "Going over the side!"]))
			continue
		if s != null and is_instance_valid(s):
			var rider = spec["seats"][i].get("rider", false)
			s.dismount(true)
			# tank crews often get out of a brew-up alive, hurt and maybe on fire, and fight on as infantry
			if bail or randf() < (0.3 if rider else (0.55 if kind == "tank" else 0.5)):
				Combat.kill(s, attacker, false)
			else:
				s.hp = minf(s.hp, randf_range(30.0, 55.0))
				s.no_board_t = G.sim_time + 60.0
				# out of the wreck and into the nearest cover, then back in the fight with his rifle
				if not s.is_player:
					var threat: Vector3 = attacker.pos if attacker != null and is_instance_valid(attacker) else hit_from
					_scatter(s, threat)
					if randf() < 0.6:
						G.fx.callout(s, G.pick(["She's gone! Get to cover!", "I'm out! Where's the rest of the crew?", "Get down, get down!"]))
	if attacker != null and is_instance_valid(attacker) and attacker.team != team:
		G.ui.feed(attacker, null, false, spec["name"])
	Stats.vehicle_lost(team)

# a crewman out of a knocked-out vehicle: away from whoever did it, into cover, ready to fight on foot
func _scatter(guy, threat: Vector3) -> void:
	var away = G.flat(guy.pos - threat)
	if away.length_squared() < 0.01:
		away = -forward()
	away = away.normalized()
	(func():
		if not is_instance_valid(guy) or guy.state != "alive":
			return
		guy.threat = threat
		guy.has_threat = true
		var cp = AI.find_cover(guy, threat, "hold")
		if cp != null and G.dist2d(cp.p, guy.pos) < 30.0:
			AI.take_cover(guy, cp)
		else:
			AI.go_to(guy, guy.pos + away * 14.0, 5.8)
		guy.task = "flee"
		guy.flee_t = 5.0
		guy.decide_t = 4.0).call_deferred()

# closest points between segments a0-a1 and b0-b1 (on the ground plane)
static func _seg_closest(a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3) -> Array:
	var d1 = G.flat(a1 - a0)
	var d2 = G.flat(b1 - b0)
	var r = G.flat(a0 - b0)
	var a = d1.dot(d1)
	var e = d2.dot(d2)
	var f = d2.dot(r)
	var s = 0.0
	var t = 0.0
	if a < 1e-5 and e < 1e-5:
		return [a0, b0]
	if a < 1e-5:
		t = clampf(f / e, 0.0, 1.0)
	else:
		var c = d1.dot(r)
		if e < 1e-5:
			s = clampf(-c / a, 0.0, 1.0)
		else:
			var b = d1.dot(d2)
			var den = a * e - b * b
			s = clampf((b * f - c * e) / den, 0.0, 1.0) if den > 1e-5 else 0.0
			t = (b * s + f) / e
			if t < 0.0:
				t = 0.0
				s = clampf(-c / a, 0.0, 1.0)
			elif t > 1.0:
				t = 1.0
				s = clampf((b - c) / a, 0.0, 1.0)
	return [a0 + (a1 - a0) * s, b0 + (b1 - b0) * t]

func _wreck_paint(n: Node) -> void:
	for m in n.get_children():
		if m.has_meta("mark") or m is CPUParticles3D:
			continue        # bullet holes and soot keep their own look
		if m is MeshInstance3D:
			# scorched: every part keeps its own shade, blackened and rusted, so the wreck still reads as the vehicle it was
			var cur = m.material_override
			var c0 = cur.albedo_color if cur is StandardMaterial3D else Color(0.3, 0.3, 0.28)
			var burnt = c0.darkened(0.62).lerp(Color(0.32, 0.17, 0.09), 0.22 if randf() < 0.5 else 0.08)
			burnt.a = 1.0
			m.material_override = VModel.mat(burnt)
		if m.get_child_count() > 0:
			_wreck_paint(m)

# swing open the door nearest a seat for a moment
func open_door(i: int) -> void:
	if doors.is_empty() or i < 0 or i >= spec["seats"].size():
		return
	var o: Vector3 = spec["seats"][i]["o"]
	var best = null
	var bd = 1e9
	for d in doors:
		var c: Vector3 = d["c"]
		var dd = Vector2(c.x - o.x, c.z - o.z).length()
		if dd < bd:
			bd = dd
			best = d
	if best != null and bd < 3.0:
		best["t"] = 1.6

func _doors_tick(dt: float) -> void:
	for d in doors:
		if d["t"] > 0.0:
			d["t"] -= dt
		var n: Node3D = d["n"]
		if not is_instance_valid(n):
			continue
		if d.has("slide"):
			n.position.z = lerpf(n.position.z, d["c"].z + 0.7 - (d["slide"] if d["t"] > 0.0 else 0.0), minf(1.0, dt * 6.0))
		else:
			n.rotation.y = lerp_angle(n.rotation.y, d["open"] if d["t"] > 0.0 else d["shut"], minf(1.0, dt * 7.0))

func remove() -> void:
	for i in range(seats.size()):
		if seats[i] != null and is_instance_valid(seats[i]):
			seats[i].dismount(false)
	G.vehicles.erase(self)
	body.queue_free()
	queue_free()

# ---------------------------------------------------------------- AI driving
# the commander sends this vehicle somewhere: it drops whatever it was doing, drives there and waits
func command(p: Vector3) -> void:
	if spec.get("static", false) or spec.get("air", false) or dead:
		return
	if mission != null and mission.get("type", "") in ["escort", "supply"]:
		return          # convoys keep to their route
	if mission != null:
		mission = null
	cmd = Vector3(p.x, G.world.ground_y(p.x, p.z), p.z)
	if has_meta("parked_at"):
		remove_meta("parked_at")
	convoy = null
	path_t = 0.0
	stuck_t = 0.0
	if driver() != null and not driver().is_player:
		G.fx.callout(driver(), G.pick(["Moving!", "On our way.", "Roger, driving."]))

func _set_goal(p: Vector3) -> void:
	if p.distance_to(goal) < 4.0 and path_t > 0.0 and not path.is_empty():
		return
	var same = p.distance_to(goal) < 4.0 and not path.is_empty()
	goal = p
	path_t = 4.0
	var np = _plan(p)
	if same and not _better(np):
		return          # nearly the same way as before: keep to it rather than dither between the two
	path = np
	path_i = 0

func _plan(p: Vector3) -> Array:
	if spec.get("boat", false):
		return G.world.find_path(pos, _leg(p))
	return G.world.find_vpath(pos, _leg(p), spec["tracked"], self)

func _path_left() -> float:
	var L = 0.0
	var prev = pos
	for i in range(path_i, path.size()):
		L += G.dist2d(prev, path[i])
		prev = path[i]
	return L

# switch to a new route only if the old one is blocked now or the new one is clearly shorter
func _better(np: Array) -> bool:
	if np.is_empty():
		return false
	if path_i >= path.size():
		return true
	var prev = pos
	for i in range(path_i, mini(path.size(), path_i + 4)):
		if not G.world.vseg_clear(prev, path[i]):
			return true
		prev = path[i]
	var L = 0.0
	prev = pos
	for q in np:
		L += G.dist2d(prev, q)
		prev = q
	return L < _path_left() * 0.85 - 4.0

# where to aim along the path: a point a little way ahead on it, so corners get rounded off
# into a curve instead of driven to and turned on the spot
func _pursuit() -> Vector3:
	var look = 5.0 + absf(speed) * (0.55 if spec["tracked"] else 0.8)
	var prev = pos
	var acc = 0.0
	for i in range(path_i, path.size()):
		var q: Vector3 = path[i]
		var seg = G.dist2d(prev, q)
		if acc + seg >= look:
			var k = (look - acc) / maxf(seg, 0.01)
			return prev.lerp(q, k)
		acc += seg
		prev = q
	return path[path.size() - 1]

# how sharp the next bend is and how far off: slow for it so the turn can be made
func _bend_speed() -> float:
	if path_i >= path.size() - 1:
		return 1.0
	var a: Vector3 = path[path_i]
	var b: Vector3 = path[path_i + 1]
	var d_in = G.flat(a - pos)
	var d_out = G.flat(b - a)
	if d_in.length_squared() < 0.5 or d_out.length_squared() < 0.5:
		return 1.0
	var turn = d_in.normalized().angle_to(d_out.normalized())
	var dist = d_in.length()
	if turn < 0.5 or dist > 22.0:
		return 1.0
	var k = clampf(1.0 - (turn - 0.5) * 0.5, 0.35, 1.0)
	return lerpf(k, 1.0, clampf((dist - 6.0) / 16.0, 0.0, 1.0))

# who gives way when two meet: the bigger one goes first
func rank() -> int:
	if kind == "tank":
		return 5
	if spec["tracked"]:
		return 4
	if kind in ["armoredcar", "apc"]:
		return 3
	if kind in ["truck", "supplytruck", "ammotruck", "ambulance", "radar", "bridger"]:
		return 2
	return 1

# breadcrumbs: where this vehicle has been, for a convoy following it
var trail: Array = []
var convoy = null          # {"lead": vehicle, "k": place in the column}
var yield_t = 0.0

func _trail_tick() -> void:
	if trail.is_empty() or G.dist2d(trail[trail.size() - 1], pos) > 3.0:
		trail.append(pos)
		if trail.size() > 50:
			trail.pop_front()

# the spot in the column for a follower: k gaps back along the leader's track
func _convoy_spot():
	var L = convoy["lead"]
	if L == null or not is_instance_valid(L) or L.dead or L.driver() == null or L.cmd == null:
		convoy = null
		return null
	if G.dist2d(L.pos, L.cmd) < 22.0:
		convoy = null          # leader's there: everyone to their own spot
		return null
	var want = 13.0 * convoy["k"]
	var acc = 0.0
	var prev: Vector3 = L.pos
	for i in range(L.trail.size() - 1, -1, -1):
		var q: Vector3 = L.trail[i]
		acc += G.dist2d(prev, q)
		prev = q
		if acc >= want:
			return q
	return prev

func _leg(p: Vector3) -> Vector3:
	if G.dist2d(p, pos) > 90.0:
		return pos + G.flat(p - pos).normalized() * 75.0
	return p

func _steer_to(target: Vector3, dt: float) -> Array:
	var to = G.flat(target - pos)
	var ang = wrapf(atan2(to.x, to.z) - yaw, -PI, PI)
	var steer = clampf(ang * 2.0, -1.0, 1.0)
	var thr = 1.0 if absf(ang) < 0.9 else 0.35
	var L = to.length()
	if spec["tracked"]:
		# tracks turn on the spot: pivot first, then drive
		if absf(ang) > 0.9 and L < 30.0:
			thr = 0.12
		if absf(ang) > 2.4 and L < 14.0:
			thr = -1.0
			steer = -steer
	else:
		# wheels can't turn tighter than about 5 m: a mark off to the side or behind that's closer than that
		# gets a three-point turn (back up on opposite lock), never a circle round it
		var tight = 5.5 + spec["len"] * 0.3
		# each leg of the turn is carried through for a moment: flicking between forward and reverse
		# every frame left lorries rocking on the spot for half a minute
		var leg_t: float = get_meta("leg_t", 0.0)
		var leg: int = get_meta("leg", 0)
		if G.sim_time < leg_t and leg != 0 and not (leg < 0 and absf(ang) < 0.5):
			thr = 0.75 * leg
			steer = -steer if leg < 0 else steer
		elif absf(ang) > 1.1 and L < tight * 2.2:
			thr = -0.75
			steer = -steer
			set_meta("leg", -1)
			set_meta("leg_t", G.sim_time + 1.8)
		elif absf(ang) > 1.2:
			thr = 0.55
			if leg < 0:
				set_meta("leg", 1)
				set_meta("leg_t", G.sim_time + 1.5)
		else:
			set_meta("leg", 0)
		# ease off for a sharp bend close by so the turn is tight
		if absf(ang) > 0.5 and L < 14.0 and thr > 0.0:
			thr = minf(thr, 0.45)
	return [thr, steer]

# where to let troops off: part way up toward their objective, short of known enemies
func rider_drop(obj: Vector3) -> Vector3:
	if G.sim_time < get_meta("drop_t", -99.0) and has_meta("drop_p"):
		return get_meta("drop_p")
	var home: Vector3 = G.world.rally_point(team)
	var p = Reinforce.forward_drop(team)
	if G.dist2d(p, home) < 20.0:
		# nobody up front yet: well forward of home toward the objective
		var to = G.flat(obj - home)
		p = home + to * 0.55 if to.length() > 60.0 else obj
	var ec = AI.team_intel_center(team)
	if ec != null and G.dist2d(ec, p) < 60.0:
		p = ec + G.flat(p - ec).normalized() * 60.0
	if G.dist2d(p, obj) > G.dist2d(pos, obj):
		p = pos            # already past it: let them off here
	p = G.main._free_spot(p)
	set_meta("drop_p", p)
	set_meta("drop_t", G.sim_time + 10.0)
	return p

func unload_riders() -> void:
	for i in range(1, seats.size()):
		var ps2 = seats[i]
		if ps2 != null and spec["seats"][i]["role"] == "pass" and not ps2.is_player and not spec["seats"][i].get("turret", false) and not spec["seats"][i].get("rider", false):
			ps2.dismount(false)
			ps2.no_board_t = G.sim_time + 40.0
	pass_stall = 0.0

var pass_stall = 0.0

var idle_empty = 0.0
var _drive_cache: Array = []

# what this vehicle simply pushes over rather than steering round: hedges and bushes, fences and loose
# props, and (for anything bigger than a jeep) young trees
func _drives_through(c) -> bool:
	if not c.dest or spec.get("boat", false) or spec.get("air", false):
		return false
	if c.prop == 2:
		return true
	if c.has_meta("tree"):
		return spec["tracked"] or (spec["len"] >= 4.5 and float(c.get_meta("tree")) < 5.5)
	return c.prop == 1 and spec["len"] >= 3.5

# parked near enough: once a lorry has stopped at its spot it stays put until the spot itself moves well
# away, instead of creeping at a spot it can't quite reach and sawing back and forth for minutes
func _parked(target: Vector3, r: float) -> bool:
	if has_meta("parked_at"):
		var pa: Vector3 = get_meta("parked_at")
		if G.dist2d(target, pa) < 14.0 and G.dist2d(pos, pa) < 3.0:
			return true
		remove_meta("parked_at")
	# close enough, or close-ish and it's been trying for a while without getting any closer
	var d = G.dist2d(target, pos)
	if d < r or (d < r + 10.0 and stuck_n >= 1):
		set_meta("parked_at", pos)
		stuck_n = 0
		return true
	return false

func _ai_drive(dt: float) -> Array:
	why = "drive"
	path_t -= dt
	# a transport lorry with nobody left in the back and nothing to do clears off the map
	if mission == null and has_meta("transport"):
		var empty = true
		for i in range(1, seats.size()):
			if seats[i] != null:
				empty = false
		if empty and (absf(speed) < 0.6 or cmd == null):
			idle_empty += dt
		else:
			idle_empty = 0.0
		if idle_empty > 12.0:
			cmd = null
			mission = {"type": "deliver", "drop": pos, "exit": Reinforce.offmap(Reinforce.edge_near_hq(team)), "stage": 2, "wait": 0.0}
			if team == 0:
				G.ui.radio(0, "Empty truck heading back")
	# men sitting in the back of something that isn't going anywhere get out and walk
	if mission == null and seats.size() > 1 and kind != "ambulance":
		var aboard = false
		for i in range(1, seats.size()):
			if seats[i] != null and not seats[i].is_player and spec["seats"][i]["role"] == "pass" and not spec["seats"][i].get("turret", false) and not spec["seats"][i].get("rider", false):
				aboard = true
				break
		if aboard:
			pass_stall = pass_stall + dt if absf(speed) < 0.5 else maxf(0.0, pass_stall - dt * 2.0)
			# (not while it's still out past the edge of the map coming in: they'd be dropped in the hills)
			if (pass_stall > 12.0 or kind in ["radar", "ammotruck", "supplytruck", "ambulance", "bridger"]) and G.world.bounds.grow(-6.0).has_point(Vector2(pos.x, pos.z)):
				unload_riders()
	var d = driver()
	var target = null
	if mission != null:
		target = _mission_target(dt)
		if target == null:
			why = "w1"
			return [0.0, 0.0]
		if spec.get("boat", false):
			return _steer_to(target, dt)
	elif detour != null and G.sim_time < detour_t and G.dist2d(detour, pos) > 6.0:
		target = detour
	elif cmd != null and convoy != null and _convoy_spot() != null:
		# in a column: keep station behind the vehicle in front, at its pace
		target = _convoy_spot()
		var gap = G.dist2d(target, pos)
		var CL = convoy["lead"]
		if gap < 4.0 or (G.dist2d(CL.pos, pos) < 9.0 + 4.0 * convoy["k"] and absf(CL.speed) < 1.0):
			why = "convoy"
			return [0.0, 0.0]
		if gap < 30.0 and G.world.vseg_clear(pos, target):
			var rr = _steer_to(target, dt)
			if gap < 9.0:
				rr[0] = minf(rr[0], 0.35)
			return rr
	elif cmd != null:
		target = cmd
		var dc = G.dist2d(cmd, pos)
		if dc < 16.0:
			cmd_near_t += dt
		else:
			cmd_near_t = 0.0
		if _parked(cmd, 4.5 + spec["len"] * 0.35) or cmd_near_t > 7.0:
			if cmd_near_t > 7.0 and not has_meta("parked_at"):
				set_meta("parked_at", pos)
			why = "w2"
			return [0.0, 0.0]
	elif kind == "ambulance":
		target = VehExt.medevac(self, dt)
		if target == null:
			why = "w3"
			return [0.0, 0.0]
	elif kind == "ammotruck" or kind == "supplytruck":
		var want_c = VehExt.ammo_spot(self) if kind == "ammotruck" else G.world.rally_point(team)
		# park in a free bay near the spot rather than on top of it
		if not has_meta("park_c") or G.dist2d(get_meta("park_c"), want_c) > 6.0 or not has_meta("park"):
			set_meta("park_c", want_c)
			G.world.park_spot(want_c, self, G.world.rally_point(team))
		target = get_meta("park")
		if _parked(target, 4.5):
			why = "w4"
			return [0.0, 0.0]
	elif kind == "radar":
		target = VehExt.radar_spot(self)
		if _parked(target, 6.0):
			why = "w4"
			return [0.0, 0.0]
	elif fuel < 0.15 and VehExt.fuel_stop(self) != null and G.dist2d(VehExt.fuel_stop(self), pos) > 12.0:
		target = VehExt.fuel_stop(self)
	elif kind == "bridger":
		if bridge_laid:
			why = "w5"
			return [0.0, 0.0]
		var bsite = VehExt.bridge_site(self)
		if bsite == null:
			why = "w6"
			return [0.0, 0.0]
		var bank: Vector3 = bsite[0]
		var bst: float = get_meta("bstuck", 0.0)
		if absf(speed) < 2.0 and G.dist2d(bank, pos) < 22.0:
			bst += dt
		else:
			bst = maxf(0.0, bst - dt * 0.3)
		set_meta("bstuck", bst)
		if G.dist2d(bank, pos) < 5.0 or (G.dist2d(bank, pos) < 22.0 and bst > 3.0):
			var want_yaw = atan2(bsite[1].x, bsite[1].z)
			var dy = wrapf(want_yaw - yaw, -PI, PI)
			if absf(dy) > 0.12:
				return [0.25, clampf(dy * 2.0, -1.0, 1.0)]
			var res = VehExt.lay_bridge(self)
			if not bridge_laid and res.begins_with("Drive"):
				return [0.5, 0.0]       # creep up to the edge
			why = "w7"
			return [0.0, 0.0]
		target = bank
	elif kind == "atgun" and G.sim_time - get_meta("fire_t", -99.0) < 25.0:
		why = "w8"
		return [0.0, 0.0]
	elif kind == "atgun" and _at_post() != null and G.dist2d(_at_post(), pos) < 5.0:
		# dug in at its post covering the approach: it waits there for armour rather than driving into the fight
		why = "w8"
		return [0.0, 0.0]
	elif kind == "atgun" and _at_post() != null:
		target = _at_post()
	else:
		var obj: Vector3 = AI.objective_for(d)
		var enemy = null
		var best = AI.best_intel(d)
		if best != null and G.sim_time - best["t"] < 15.0:
			enemy = best["p"]
		var stand = spec["standoff"]
		if enemy != null and stand > 0.0:
			var de = G.dist2d(enemy, pos)
			# a band either side of each line, so it doesn't flick between backing off, holding and closing in
			if de < stand * (0.62 if hold_mode == "back" else 0.5):
				# too close: back away from the enemy
				hold_mode = "back"
				target = pos + G.flat(pos - enemy).normalized() * 15.0
			elif de < stand * (1.15 if hold_mode == "hold" else 1.0):
				hold_mode = "hold"
				why = "w9"
				var armour = _armour_near(stand * 1.6) if spec["tracked"] else null
				if armour != null:
					if G.sim_time < get_meta("scoot_until", 0.0):
						return [-0.6, 0.0]
					# thick front plate toward the enemy tank: swing the hull to face it
					var to_a = G.flat(armour.pos - pos)
					var da = wrapf(atan2(to_a.x, to_a.z) - yaw, -PI, PI)
					if absf(da) > 0.22:
						return [0.0, clampf(da * 1.8, -1.0, 1.0)]
				return [0.0, 0.0]        # in a good firing position: hold
			else:
				hold_mode = ""
				target = enemy
		else:
			target = obj
		if hp < spec["hp"] * 0.3 and enemy != null:
			target = G.world.rally_point(team)
		# carrying troops (not the commander in his hatch, not men riding on the deck): take them where they're going
		var riders = 0
		for i in range(1, seats.size()):
			if seats[i] != null and spec["seats"][i]["role"] == "pass" and not spec["seats"][i].get("turret", false) and not spec["seats"][i].get("rider", false):
				riders += 1
		if riders > 0:
			for i in range(1, seats.size()):
				var ps = seats[i]
				if ps != null and spec["seats"][i]["role"] == "pass" and not ps.is_player and not spec["seats"][i].get("turret", false) and not spec["seats"][i].get("rider", false):
					target = rider_drop(AI.objective_for(ps))
					break
			# drop them a sensible way up, short of the fighting, then (a lorry) go back for more
			if G.dist2d(target, pos) < 12.0 or (enemy != null and G.dist2d(enemy, pos) < 55.0) or pass_stall > 8.0:
				unload_riders()
				if kind == "truck":
					cmd = G.main._free_spot(G.world.rally_point(team))
				why = "w10"
				return [0.0, 0.0]
		# there (or near enough): stay put until the target has moved well away, not the moment it shifts a metre
		var dt_ = G.dist2d(target, pos)
		if dt_ < 8.0 or (hold_mode == "there" and dt_ < 15.0):
			hold_mode = "there"
			why = "w11"
			return [0.0, 0.0]
		if hold_mode == "there":
			hold_mode = ""
		# armour doesn't drive into a built-up street on its own: wait for the infantry (and decide
		# that for a few seconds at a time, not every tick)
		if spec["tracked"] and enemy == null:
			if G.sim_time > enter_t:
				may_enter = Ops.tank_may_enter(self)
				enter_t = G.sim_time + (6.0 if may_enter else 4.0)
			if not may_enter:
				why = "w12"
				return [0.0, 0.0]
	_set_goal(target)
	# follow the path, aiming a little way ahead on it
	var aim: Vector3 = target
	while path_i < path.size() and G.dist2d(path[path_i], pos) < 4.0:
		path_i += 1
	# already nearer the next waypoint than this one is to it: this one's behind or beside us, skip it
	# (turning round to touch a corner we've cut is what makes a lorry shuffle back and forth)
	while path_i < path.size() - 1 and G.dist2d(path[path_i + 1], pos) < G.dist2d(path[path_i + 1], path[path_i]) and G.dist2d(path[path_i], pos) < 12.0:
		path_i += 1
	if path_i < path.size():
		aim = _pursuit()
	if path_t <= 0.0:
		path_t = 4.0
		var np = _plan(goal)
		if _better(np):
			path = np
			path_i = 0
	var r = _steer_to(aim, dt)
	# ease off for a bend ahead (only when we're more or less lined up; a hard turn already goes slow),
	# but never so far that the engine can't move the thing
	if r[0] > 0.0:
		var to_aim = G.flat(aim - pos)
		var off = absf(wrapf(atan2(to_aim.x, to_aim.z) - yaw, -PI, PI))
		if off < 0.6:
			r[0] *= _bend_speed()
		r[0] = maxf(r[0], 0.3)
	# whiskers: veer away from walls just ahead
	if r[0] > 0.0:
		var f0 = forward()
		var front = pos + f0 * spec["len"] * 0.5 + Vector3(0, 0.8, 0)
		for side in [-1.0, 1.0]:
			var a = yaw + side * 0.45
			var wd = Vector3(sin(a), 0, cos(a))
			var off = Vector3(f0.z, 0, -f0.x) * side * -spec["wid"] * 0.45
			var wh = G.ray(front + off, front + off + wd * (4.0 + absf(speed) * 0.6), G.L_WORLD)
			if not wh.is_empty():
				# hedges, bushes, fences and saplings it'll just drive through: no swerving for those
				var wc = wh.collider.get_meta("col") if wh.collider.has_meta("col") else null
				if wc != null and _drives_through(wc):
					continue
				r[1] -= side * 0.8
		r[1] = clampf(r[1], -1.0, 1.0)
	# don't drive over friends
	var f = forward()
	var reach_f = spec["len"] + 6.0
	for s in G.soldiers:
		if absf(s.pos.x - pos.x) > reach_f or absf(s.pos.z - pos.z) > reach_f:
			continue
		if s.team == team and s.state == "alive" and s.vehicle == null:
			var rel = G.flat(s.pos - pos)
			var a = rel.dot(f) * signf(r[0] if r[0] != 0.0 else 1.0)
			if a > 0.0 and a < spec["len"] * 0.5 + 5.0 and absf(rel.dot(Vector3(f.z, 0, -f.x))) < spec["wid"] * 0.5 + 0.8:
				# our own men in the way step aside (the driver waits only for you, or a man who can't move)
				if not s.is_player and s.vault == null and not s.prone and s.dragging == null:
					# a man just standing there in the road is told to step out of it
					if s.move_target == null and G.sim_time > s.get_meta("clear_t", -9.0):
						s.set_meta("clear_t", G.sim_time + 4.0)
						var sdir = Vector3(f.z, 0, -f.x) * (1.0 if rel.dot(Vector3(f.z, 0, -f.x)) >= 0.0 else -1.0)
						AI.go_to(s, s.pos + sdir * (spec["wid"] * 0.5 + 3.0), 4.0)
					if true:
						var sd = rel.dot(Vector3(f.z, 0, -f.x))
						s.pos += Vector3(f.z, 0, -f.x) * (1.0 if sd >= 0.0 else -1.0) * 0.07
						s.pos = G.world.push_out_circle(s.pos, 0.33)[0]
					if a < spec["len"] * 0.5 + 1.5:
						return [minf(r[0], 0.15), r[1]]
					continue
				return [0.0, r[1]]
	# other vehicles (and wrecks) in the way: steer round them; nose to nose, one of them gives way
	var lv = Vector3(cos(yaw), 0, -sin(yaw))
	var dsg = signf(r[0]) if r[0] != 0.0 else 1.0
	for o in G.vehicles:
		if o == self or (o.spec.get("air", false) and o.alt > 3.0):
			continue
		var rel = G.flat(o.pos - pos)
		var a2 = rel.dot(f) * dsg
		var lat = rel.dot(lv)
		var reach = (spec["len"] + o.spec["len"]) * 0.5 + 5.0
		var half = (spec["wid"] + o.spec["wid"]) * 0.5 + 1.0
		if a2 > 0.0 and a2 < reach and absf(lat) < half:
			r[1] = clampf(r[1] - signf(lat if lat != 0.0 else 1.0) * 0.9 * dsg, -1.0, 1.0)
			var close = a2 < (spec["len"] + o.spec["len"]) * 0.5 + 1.0
			if close and not o.dead and o.team == team and absf(o.speed) > 0.2:
				var mine = rank()
				var theirs = o.rank()
				if theirs > mine or (theirs == mine and get_instance_id() > o.get_instance_id()):
					# the smaller one gives way: nose to nose it backs off a little, either way it waits
					if f.dot(o.forward()) < -0.4 and reverse_t <= 0.0 and yield_t <= 0.0:
						reverse_t = 1.1
					yield_t = 2.5
					r[0] = minf(absf(r[0]), 0.1) * dsg
	if yield_t > 0.0:
		yield_t -= dt
	# unstick: if we want to move but aren't, back up for a moment
	if reverse_t > 0.0:
		reverse_t -= dt
		# never back over our own men
		for s2 in G.soldiers:
			if s2.team == team and s2.state != "dead" and s2.vehicle == null:
				var rel2 = G.flat(s2.pos - pos)
				if rel2.dot(f) < 0.0 and rel2.dot(f) > -(spec["len"] * 0.5 + 4.0) and absf(rel2.dot(lv)) < spec["wid"] * 0.5 + 1.0:
					reverse_t = 0.0
					return [0.0, r[1]]
		if has_meta("rev_steer") and reverse_t > 0.0:
			return [-1.0, get_meta("rev_steer")]
		remove_meta("rev_steer")
		return [-1.0, -r[1]]
	if absf(r[0]) > 0.12 and absf(speed) < 0.6 and yield_t <= 0.0:
		stuck_t += dt
		if stuck_t > 1.6:
			stuck_t = 0.0
			stuck_n += 1
			if r[0] < 0.0:
				# backing into something: pull forward on full lock instead and try the turn the other way
				set_meta("leg", 1)
				set_meta("leg_t", G.sim_time + 2.5)
				reverse_t = 0.0
			else:
				_jam_sort(f, lv, dsg)
	else:
		stuck_t = 0.0
	# really wedged (or off the map): slide to the nearest open ground and carry on
	prog_t += dt
	if prog_t > 10.0:
		prog_t = 0.0
		var moved = G.dist2d(pos, prog_p)
		prog_p = pos
		var b = G.world.bounds
		var outside = pos.x < b.position.x or pos.x > b.end.x or pos.z < b.position.y or pos.z > b.end.y
		# creeping back and forth a metre at a time counts as stuck too
		if (moved < 5.0 and stuck_n >= 3) or (outside and moved < 3.0):
			stuck_n = 0
			_unwedge()
			_plan_detour()
		elif moved < 5.0 and stuck_n >= 1:
			_plan_detour()
		elif moved >= 5.0:
			stuck_n = 0
	return r

var stuck_n = 0

# stuck against another vehicle: sort it out between the two instead of both backing up and nosing in
# again together. A parked one with a driver shuffles out of the road; of two that both want to move,
# the smaller backs off at an angle while the bigger waits; a wreck or an empty truck gets driven round.
func _jam_sort(f: Vector3, lv: Vector3, dsg: float) -> void:
	var blk = null
	var bd = 1e9
	for o in G.vehicles:
		if o == self or (o.spec.get("air", false) and o.alt > 3.0):
			continue
		var rel = G.flat(o.pos - pos)
		var a2 = rel.dot(f) * dsg
		var lat = rel.dot(lv)
		if a2 > -1.0 and a2 < (spec["len"] + o.spec["len"]) * 0.5 + 3.0 and absf(lat) < (spec["wid"] + o.spec["wid"]) * 0.5 + 1.2 and rel.length() < bd:
			bd = rel.length()
			blk = o
	if blk == null:
		reverse_t = 1.4
		return
	var rel_b = G.flat(blk.pos - pos)
	var away_side = -signf(rel_b.dot(lv)) if absf(rel_b.dot(lv)) > 0.2 else (1.0 if get_instance_id() % 2 == 0 else -1.0)
	var drv = blk.driver()
	var idle = drv != null and not blk.dead and blk.team == team and absf(blk.speed) < 0.3 and blk.mission == null and blk.cmd == null and not blk.spec.get("static", false)
	if idle:
		# the parked one moves over to let us by
		var bl = Vector3(cos(blk.yaw), 0, -sin(blk.yaw))
		var push = bl * (signf(G.flat(blk.pos - pos).dot(bl)) if absf(G.flat(blk.pos - pos).dot(bl)) > 0.3 else 1.0)
		var spot = G.main._free_spot(blk.pos + push * (blk.spec["wid"] + 5.0) + blk.forward() * 4.0)
		blk.detour = spot
		blk.detour_t = G.sim_time + 8.0
		blk.path_t = 0.0
		yield_t = 2.5
		return
	if blk.dead or drv == null or blk.team != team or blk.spec.get("static", false):
		# nothing that will move: back off a touch and go round it
		reverse_t = 1.2
		set_meta("rev_steer", -away_side * dsg)
		_plan_detour()
		return
	var mine = rank()
	var theirs = blk.rank()
	if theirs > mine or (theirs == mine and get_instance_id() > blk.get_instance_id()):
		reverse_t = 2.2
		set_meta("rev_steer", -away_side * dsg)     # backing up with the wheel over opens a gap beside him
		blk.yield_t = 0.0
		blk.stuck_t = 0.0
	else:
		yield_t = 1.8          # the other one is clearing out of our way

var hold_mode = ""         # "", "back", "hold", "there": which side of each line we were on last
var may_enter = true
var enter_t = 0.0
var prog_t = 0.0
var prog_p = Vector3.ZERO

# boxed in (a narrow street, a jam, a wreck): try another way for a while, through open ground to one side;
# and troops in the back get out and carry on on foot rather than sit in a jam
var detour = null
var detour_t = 0.0

func _plan_detour() -> void:
	var to = G.flat(goal - pos)
	if to.length_squared() < 1.0:
		to = forward()
	to = to.normalized()
	var best = null
	for k in range(16):
		var a = (0.9 + 0.25 * k) * (1.0 if k % 2 == 0 else -1.0)
		var q = pos + to.rotated(Vector3.UP, a) * (18.0 + 2.0 * k)
		if G.world.inside_any(q.x, q.z, spec["wid"] * 0.8) or G.world.in_water(q.x, q.z):
			continue
		var b = G.world.bounds
		if q.x < b.position.x + 8.0 or q.x > b.end.x - 8.0 or q.z < b.position.y + 8.0 or q.z > b.end.y - 8.0:
			continue
		best = q
		break
	if best != null:
		detour = best
		detour_t = G.sim_time + 14.0
		path_t = 0.0
	if mission == null and kind != "ambulance":
		for i in range(1, seats.size()):
			var ps = seats[i]
			if ps != null and is_instance_valid(ps) and spec["seats"][i]["role"] == "pass" and not ps.is_player:
				ps.dismount(false)
				ps.no_board_t = G.sim_time + 30.0

func _unwedge() -> void:
	var b = G.world.bounds
	var best = null
	var c = Vector3(clampf(pos.x, b.position.x + 6.0, b.end.x - 6.0), 0, clampf(pos.z, b.position.y + 6.0, b.end.y - 6.0))
	for k in range(30):
		var a = randf() * TAU
		var q = c + Vector3(cos(a), 0, sin(a)) * (3.0 + k * 0.6)
		var clear = not G.world.inside_any(q.x, q.z, spec["wid"] * 0.6) and not G.world.in_water(q.x, q.z)
		for o in G.vehicles:
			if o != self and G.dist2d(o.pos, q) < (spec["len"] + o.spec["len"]) * 0.5 + 1.0:
				clear = false
		if clear and q.x > b.position.x + 4.0 and q.x < b.end.x - 4.0 and q.z > b.position.y + 4.0 and q.z < b.end.y - 4.0:
			best = q
			break
	if best == null:
		return
	pos = Vector3(best.x, _ground(best.x, best.z), best.z)
	speed = 0.0
	path = []
	path_t = 0.0
	_place(0.0)

func _mission_target(dt: float):
	var m = mission
	if m.get("type", "") == "escort":
		m["go_t"] = m.get("go_t", 0.0) + dt
		return Modes.escort_target(self, m)
	if m.get("type", "") == "route":
		return Scripted.route_target(self, m)
	if m.get("type", "") == "ferry":
		return Ferry.target(self, dt)
	if spec.get("boat", false) and m["stage"] == 0 and (absf(speed) < 0.3 and G.dist2d(pos, m["drop"]) < 40.0 and m.get("go_t", 0.0) > 6.0):
		m["drop"] = pos     # beached short of the mark: unload here
	m["go_t"] = m.get("go_t", 0.0) + dt
	if spec.get("boat", false) and ramp != null:
		ramp.rotation.x = lerpf(ramp.rotation.x, 1.3 if m["stage"] == 1 else 0.0, dt * 3.0)
	# held up on the way (traffic, wrecks, a blocked road) or taking far too long: everyone out here
	if m["stage"] == 0 and not spec.get("air", false) and not spec.get("boat", false) and m.get("type", "") != "supply":
		if absf(speed) < 0.5:
			m["slow_t"] = m.get("slow_t", 0.0) + dt
		else:
			m["slow_t"] = maxf(0.0, m.get("slow_t", 0.0) - dt * 0.5)
		if (m["slow_t"] > 6.0 and m["go_t"] > 8.0) or m["go_t"] > 110.0:
			m["drop"] = pos
	if m["stage"] == 0 and m.get("type", "") == "supply":
		if absf(speed) < 0.5:
			m["slow_t"] = m.get("slow_t", 0.0) + dt
		else:
			m["slow_t"] = maxf(0.0, m.get("slow_t", 0.0) - dt * 0.5)
		if m["slow_t"] > 7.0 and G.dist2d(pos, m["drop"]) < 30.0:
			m["drop"] = pos
	if m["stage"] == 0:
		var inb: Rect2 = G.world.bounds.grow(-10.0)
		if not inb.has_point(Vector2(m["drop"].x, m["drop"].z)):
			# a drop point out past the edge (stuck coming in): bring it inside the map
			m["drop"] = G.main._free_spot(Vector3(clampf(m["drop"].x, inb.position.x, inb.end.x), 0, clampf(m["drop"].z, inb.position.y, inb.end.y)))
		if G.dist2d(pos, m["drop"]) < 6.0 and G.world.bounds.grow(-6.0).has_point(Vector2(pos.x, pos.z)):
			if absf(speed) > 0.4 and not spec.get("air", false):
				return null          # roll to a stop before anyone gets out
			m["stage"] = 1
			m["wait"] = 5.0
			if m.get("type", "") == "supply":
				var st = m["site"]
				if st != null and not st["dead"] and st.get("ammo") != null:
					st["ammo"]["stock"] = minf(160.0, st["ammo"]["stock"] + 100.0)
					if has_meta("cargo"):
						get_meta("cargo").visible = false
					m["wait"] = 6.0
					G.ui.radio(team, "Supplies delivered to the %s" % st["name"])
				if m.get("fleet", false) and team < Logistics.delivered.size():
					Logistics.delivered[team] += 1
				if m.get("pts", 0) > 0 and st != null and not st["dead"]:
					Support.points[team] += m["pts"]
					G.ui.radio(team, "Convoy got through: +%d supply" % m["pts"])
					m["pts"] = 0
					if has_meta("cargo"):
						get_meta("cargo").visible = false
			for i in range(1, seats.size()):
				var s = seats[i]
				if s != null and is_instance_valid(s):
					s.dismount(false)
			if driver() != null:
				G.fx.callout(driver(), G.pick(["Everybody out!", "Go, go, go!", "Unload!"]))
			return null
		return m["drop"]
	if m["stage"] == 1:
		m["wait"] -= dt
		if m["wait"] <= 0.0:
			m["stage"] = 2
		return null
	# a supply truck of the fleet goes back to HQ to load up again
	if m.get("fleet", false):
		if G.dist2d(pos, m["exit"]) < 8.0:
			Logistics.arrived_home(self)
			return null
		return m["exit"]
	# heading home: once it's well clear (or stuck, or taking too long) it simply drives off the map
	m["exit_t"] = m.get("exit_t", 0.0) + dt
	if absf(speed) < 0.5:
		m["xslow"] = m.get("xslow", 0.0) + dt
	else:
		m["xslow"] = 0.0
	# gone once it's off the edge of the map; if it's stuck on the way, only once nobody's watching
	var cam = get_viewport().get_camera_3d()
	var unseen = cam == null or cam.global_position.distance_to(pos) > 150.0 or (-cam.global_transform.basis.z).dot((pos - cam.global_position).normalized()) < 0.2
	var bb: Rect2 = G.world.bounds
	var ex: Vector3 = m["exit"]
	var edge_in = Vector3(clampf(ex.x, bb.position.x + 4.0, bb.end.x - 4.0), ex.y, clampf(ex.z, bb.position.y + 4.0, bb.end.y - 4.0))
	var edge_d = minf(minf(pos.x - bb.position.x, bb.end.x - pos.x), minf(pos.z - bb.position.y, bb.end.y - pos.z))
	var at_edge = edge_d < 14.0
	if Reinforce.outside_map(pos, 6.0) or G.dist2d(pos, m["exit"]) < 6.0 or ((m["exit_t"] > 60.0 or m["xslow"] > 8.0) and unseen) or (at_edge and m["xslow"] > 4.0) or m["exit_t"] > 150.0:
		var d = driver()
		remove()
		if d != null and is_instance_valid(d):
			G.soldiers.erase(d)
			d.queue_free()
		return null
	# out to the edge by the way the map allows, then straight off it
	if G.dist2d(pos, edge_in) > 10.0 and not at_edge:
		return edge_in
	return m["exit"]

# ---------------------------------------------------------------- engine fires and bailing out
var heavy_t = -99.0          # last time something big hit her
var hit_from = Vector3.ZERO

# stuck (track off, wheels shot) or badly holed, and still being hit by something heavy: the crew don't
# sit there waiting for the next one, they get out and run for cover away from whoever's firing
func _bail_check() -> void:
	if bailed or dead or burning or spec.get("static", false) or spec.get("air", false) or spec.get("boat", false):
		return
	if G.sim_time - heavy_t > 4.0:
		return
	var stuck = tracks_broken or tyres >= 3 or (absf(speed) < 0.4 and fix_by != null)
	var wrecked = hp < spec["hp"] * 0.25
	if not (stuck or wrecked):
		return
	if not (spec["tracked"] or kind in ["armoredcar", "halftrack", "jeep", "truck", "technical", "supplytruck", "ammotruck", "ambulance", "radar"]):
		return
	bailed = true
	Tactics.events["bail"] += 1
	var threat: Vector3 = hit_from
	for i in range(seats.size()):
		var s = seats[i]
		if s == null or not is_instance_valid(s) or s.is_player:
			continue
		s.dismount(false)
		s.no_board_t = G.sim_time + 60.0
		var away = G.flat(s.pos - threat)
		if away.length_squared() < 0.01:
			away = -forward()
		var guy = s
		(func():
			if not is_instance_valid(guy) or guy.state != "alive":
				return
			guy.threat = threat
			guy.has_threat = true
			var cp = AI.find_cover(guy, threat, "hold")
			if cp != null and G.dist2d(cp.p, guy.pos) < 30.0:
				AI.take_cover(guy, cp)
			else:
				AI.go_to(guy, guy.pos + away.normalized() * 16.0, 5.8)
			guy.task = "flee"
			guy.flee_t = 6.0).call_deferred()
		s.decide_t = 5.0
		G.fx.callout(s, G.pick(["We're hit, bail out!", "Out, out, she's done!", "Get clear of her!"]))
	if team == 0:
		G.ui.radio(0, "%s crew bailing out!" % spec["name"])

func _burn_tick(dt: float) -> void:
	hp -= 8.0 * dt
	# most fires burn themselves out (or the crew beats them out) unless she's already badly hurt
	if burn_t > get_meta("burn_len", 0.0) and hp > spec["hp"] * 0.2:
		if not has_meta("burn_len"):
			set_meta("burn_len", randf_range(14.0, 28.0))
		else:
			burning = false
			burn_t = 0.0
			remove_meta("burn_len")
			G.ui.radio(team, "%s: the fire's out" % spec["name"])
			return
	burn_fx -= dt
	if burn_fx <= 0.0:
		burn_fx = 0.15
		G.fx.flame_puff(center() + Vector3(randf_range(-0.6, 0.6), 0.9, spec["len"] * 0.25), Vector3(0, 3.0, 0), 1.2)
	burn_t += dt
	if not bailed and (hp < spec["hp"] * 0.4 or (spec["tracked"] and burn_t > 3.0)):
		bailed = true
		for i in range(seats.size()):
			var s = seats[i]
			if s != null and is_instance_valid(s):
				s.dismount(false)
				s.hp = minf(s.hp, 70.0)
				s.no_board_t = G.sim_time + 90.0
				if not s.is_player:
					if randf() < 0.3:
						s.ignite(null)
					# get clear of her before she goes up, then carry on as infantry
					var away = G.flat(s.pos - pos)
					if away.length_squared() < 0.01:
						away = Vector3(1, 0, 0)
					var dest = s.pos + away.normalized() * 14.0 - forward() * 4.0
					(func(): if is_instance_valid(s) and s.state == "alive": AI.go_to(s, dest, 5.6)).call_deferred()
					s.decide_t = 4.0
					G.fx.callout(s, G.pick(["Bail out! Bail out!", "She's gonna blow!", "Get out, get out!"]))
	if hp <= 0.0:
		destroy(null)

func _flat_tyre(lp: Vector3) -> void:
	var best = null
	var bd = 1e9
	for w in wheels:
		if not is_instance_valid(w) or w.has_meta("flat"):
			continue
		var d = (w.position - lp).length()
		if d < bd:
			bd = d
			best = w
	if best != null:
		best.set_meta("flat", true)
		best.position.y -= 0.13       # sitting on the rim

func _fix_tyres() -> void:
	tyres = 0
	for w in wheels:
		if is_instance_valid(w) and w.has_meta("flat"):
			w.remove_meta("flat")
			w.position.y += 0.13

# a thrown track or a flat: a crewman climbs out (under fire if need be) and fixes it, then gets back in
func _self_repair() -> void:
	if dead or not (tracks_broken or tyres > 0 or (hp < spec["hp"] * 0.4 and not burning)) or spec.get("air", false) or spec.get("static", false):
		return
	if fix_by != null and is_instance_valid(fix_by) and fix_by.state == "alive" and fix_by.task == "fixwheel":
		return
	fix_by = null
	if G.sim_time - get_meta("broke_t", G.sim_time) < 0.0:
		return
	if not has_meta("broke_t"):
		set_meta("broke_t", G.sim_time + 3.0)
		return
	var pick = null
	for i in range(seats.size() - 1, -1, -1):
		var c = seats[i]
		if c != null and is_instance_valid(c) and not c.is_player and c.state == "riding" and not spec["seats"][i].get("rider", false):
			pick = c
			break
	if pick == null:
		return
	remove_meta("broke_t")
	pick.dismount(false)
	pick.task = "fixwheel"
	pick.board_target = self
	pick.build_t = 0.0
	fix_by = pick
	G.fx.callout(pick, G.pick(["I'll fix the track, cover me!", "Getting out to fix it!", "Cover me, I'm on the wheel!"]) if spec["tracked"] else G.pick(["Changing the tyre, cover me!", "Flat! I'll fix it!"]))

# infantry riding on the deck jump off as soon as there's shooting
func _riders_tick() -> void:
	var any = false
	for i in range(seats.size()):
		if seats[i] != null and spec["seats"][i].get("rider", false):
			any = true
	if not any:
		return
	# riders hang on through scattered fire and only jump down when it gets close: the tank stops for
	# a while, takes a heavy hit, is badly hurt, or someone on the deck sees the enemy close by
	stop_t = stop_t + G.DT if absf(speed) < 0.4 else 0.0
	var contact = G.sim_time - heavy_t < 3.0 or stop_t > 5.0 or hp < spec["hp"] * 0.5
	if not contact:
		for c in seats:
			if c != null and is_instance_valid(c) and c.vis_t != null and is_instance_valid(c.vis_t) and G.dist2d(c.vis_t.pos, pos) < 30.0:
				contact = true
				break
	if not contact:
		return
	for i in range(seats.size()):
		var r = seats[i]
		if r != null and is_instance_valid(r) and spec["seats"][i].get("rider", false) and not r.is_player:
			r.dismount(false)
			r.no_board_t = G.sim_time + 30.0
			r.decide_t = 0.0
	if randf() < 0.7 and driver() != null:
		G.fx.callout(driver(), G.pick(["Riders off! Contact!", "Everybody off the deck!", "Dismount, dismount!"]))

# headlights at night while driving out of contact; dark again as soon as there's shooting about
func _lights_tick() -> void:
	var want = G.main.is_night() and not dead and driver() != null and not spec.get("air", false) and not spec.get("static", false) \
		and not spec.get("boat", false) and G.sim_time - hit_t > 25.0
	if has_meta("force_light"):
		want = true
	if want:
		for c in seats:
			if c != null and is_instance_valid(c) and c.vis_t != null:
				want = false
				break
	if want == lights_on:
		return
	lights_on = want
	if want and lamps == null:
		lamps = VehExt.headlamps(self)
	if lamps != null:
		lamps.visible = want

func repair(amount: float) -> void:
	hp = minf(spec["hp"], hp + amount)
	_clear_damage_smoke()
	if hp > spec["hp"] * 0.5:
		burning = false
		tracks_broken = false
		bailed = false

# repaired well enough: the smoke stops
func _clear_damage_smoke() -> void:
	if hp >= spec["hp"] * 0.7 and has_meta("dmg_smoke"):
		var d = get_meta("dmg_smoke")
		if is_instance_valid(d):
			d.queue_free()
		remove_meta("dmg_smoke")
	if hp >= spec["hp"] * 0.45 and smoke_node is Node and is_instance_valid(smoke_node) and not dead:
		smoke_node.queue_free()
		smoke_node = null

# ---------------------------------------------------------------- aircraft
func _air_step(dt: float) -> void:
	if spec.get("plane", false):
		VehExt.plane_step(self, dt)
		return
	if rotor != null:
		rotor.rotation.y += dt * (18.0 if not dead else 4.0)
		if has_meta("tail_rotor"):
			get_meta("tail_rotor").rotation.x += dt * (40.0 if not dead else 6.0)
	var gy = _ground(pos.x, pos.z)
	if dead:
		# going down
		alt = maxf(0.0, alt - 11.0 * dt)
		yaw += 2.5 * dt
		pos += air_vel * dt
		air_vel *= 0.98
		pos.y = gy + alt
		global_transform = Transform3D(Basis.from_euler(Vector3(0.3, yaw, 0.4)), pos)
		body.global_transform = global_transform
		if alt <= 0.0 and air_vel.length() > 0.1:
			G.fx.explosion(pos + Vector3(0, 1, 0), 1.6)
			G.audio.boom(pos)
			air_vel = Vector3.ZERO
		return
	var fwd = 0.0
	var turn = 0.0
	var climb = 0.0
	var d = driver()
	if d != null and is_instance_valid(d) and d.state == "riding":
		if d.is_player:
			fwd = player_inputs["thr"]
			turn = player_inputs["steer"]
			climb = player_inputs.get("climb", 0.0)
		else:
			var r = _ai_fly(dt)
			fwd = r[0]
			turn = r[1]
			climb = r[2]
	else:
		climb = -0.6     # nobody flying it: settle to the ground
	yaw += turn * spec["turn"] * dt
	var f = forward()
	var want_v = f * fwd * (spec["speed"] if fwd >= 0.0 else spec["rev"])
	air_vel = air_vel.move_toward(want_v, spec["accel"] * dt)
	var np = pos + air_vel * dt
	var b = G.world.bounds
	if mission == null and life_t < 0.0:
		np.x = clampf(np.x, b.position.x - 60.0, b.end.x + 60.0)
		np.z = clampf(np.z, b.position.y - 60.0, b.end.y + 60.0)
	alt = clampf(alt + climb * 8.0 * dt, 0.0, 90.0)
	# don't fly through the scenery: keep the whole airframe (rotor included) above anything nearby
	var floor_y = gy
	for c in G.world.cols_in_rect(np.x - 6.5, np.z - 6.5, np.x + 6.5, np.z + 6.5):
		if c.alive:
			floor_y = maxf(floor_y, c.hi.y + 0.4)
	if floor_y > gy + 0.5:
		if gy + alt < floor_y:
			# something tall ahead: stop and climb over it rather than sliding through
			np = Vector3(pos.x, np.y, pos.z)
			air_vel *= 0.5
			alt = minf(alt + 12.0 * dt, 90.0)
	pos = Vector3(np.x, gy + alt, np.z)
	var lv = global_transform.basis.inverse() * air_vel
	pitch = lerpf(pitch, clampf(lv.z * 0.012, -0.3, 0.3), dt * 3.0)
	roll = lerpf(roll, clampf(-turn * 0.25, -0.35, 0.35), dt * 3.0)
	global_transform = Transform3D(Basis.from_euler(Vector3(pitch, yaw, roll)), pos)
	body.global_transform = global_transform
	if turret != null:
		_weapons(dt)
	if kind == "gunship":
		_gunship_rockets(dt)
	_crew_tick(dt)
	engine_t -= dt
	if engine_t <= 0.0:
		engine_t = 0.3
		G.audio.engine(pos, 1.0, true)
	if life_t > 0.0:
		life_t -= dt
		if life_t <= 0.0 and mission == null:
			mission = {"type": "leave", "exit": Reinforce.entry_point(team) + Vector3(0, 0, 0) * 1.0, "stage": 3, "wait": 0.0, "drop": pos}

# an open, flat patch for a helicopter to set down on, near the wanted spot
static func find_lz(want: Vector3) -> Vector3:
	var W = G.world
	for k in range(30):
		var r = 0.0 if k == 0 else 4.0 + k * 1.6
		var a = k * 2.4
		var p = want + Vector3(cos(a), 0, sin(a)) * r
		if p.x < W.bounds.position.x + 12.0 or p.x > W.bounds.end.x - 12.0 or p.z < W.bounds.position.y + 12.0 or p.z > W.bounds.end.y - 12.0:
			continue
		var g0 = W.ground_y(p.x, p.z)
		var clear = not W.in_water(p.x, p.z)
		if clear:
			for c in W.cols_in_rect(p.x - 8.0, p.z - 8.0, p.x + 8.0, p.z + 8.0):
				if c.alive and c.hi.y > g0 + 0.4:
					clear = false
					break
		if clear:
			for v in G.vehicles:
				if not v.dead and G.dist2d(v.pos, p) < 9.0 and not v.spec.get("air", false):
					clear = false
					break
		if clear and absf(W.ground_y(p.x + 5.0, p.z) - g0) < 1.2 and absf(W.ground_y(p.x, p.z + 5.0) - g0) < 1.2:
			return Vector3(p.x, g0, p.z)
	return want

func landed() -> bool:
	return spec.get("air", false) and alt < 1.0 and air_vel.length() < 1.0

# AI pilots: transports deliver troops; gunships circle over the enemy
func _ai_fly(dt: float) -> Array:
	var target: Vector3
	var want_alt = 38.0
	if mission != null:
		var m = mission
		if m["stage"] == 0:
			if not m.get("lz_ok", false):
				m["drop"] = find_lz(m["drop"])
				m["lz_ok"] = true
			target = m["drop"]
			var dd = G.dist2d(pos, target)
			# come in high, slow to a hover over the landing zone, then straight down
			if dd < 7.0:
				want_alt = 0.0
			elif dd < 40.0:
				want_alt = 14.0
			if dd < 7.0 and alt < 1.2:
				m["stage"] = 1
				m["wait"] = 3.0
				for i in range(1, seats.size()):
					var s = seats[i]
					if s != null and is_instance_valid(s):
						s.dismount(false)
				if driver() != null:
					G.fx.callout(driver(), G.pick(["Go, go! Out!", "LZ is hot, move!", "Everybody off!"]))
				return [0.0, 0.0, -1.0]
		elif m["stage"] == 1:
			m["wait"] -= dt
			if m["wait"] <= 0.0:
				m["stage"] = 2
			return [0.0, 0.0, -1.0]
		else:
			target = m["exit"]
			if alt < 16.0:
				return [0.0, 0.0, 1.0]       # lift off before moving away
			if G.dist2d(pos, target) < 30.0:
				var dr = driver()
				remove()
				if dr != null and is_instance_valid(dr):
					G.soldiers.erase(dr)
					dr.queue_free()
				return [0.0, 0.0, 0.0]
	else:
		# gunship: orbit what the team knows about the enemy, otherwise the objective
		var c = Commander._enemy_center(team)
		if c == null:
			c = G.world.capture
		orbit_a += dt * 0.25
		target = c + Vector3(cos(orbit_a), 0, sin(orbit_a)) * 55.0
		want_alt = 42.0
		if hp < spec["hp"] * 0.35:
			target = G.world.spawn[team]
			want_alt = 20.0
	var to = G.flat(target - pos)
	var ang = wrapf(atan2(to.x, to.z) - yaw, -PI, PI)
	var fwd = clampf(to.length() / 30.0, 0.0, 1.0) * (1.0 if absf(ang) < 1.2 else 0.3)
	if mission != null and mission["stage"] == 0 and to.length() < 40.0:
		fwd = clampf(to.length() / 22.0, 0.0, 0.6)
		if to.length() < 7.0:
			fwd = 0.0
			air_vel = air_vel.move_toward(Vector3.ZERO, 6.0 * dt)
	var climb = clampf((want_alt - alt) / 6.0, -1.0, 1.0)
	return [fwd, clampf(ang * 1.5, -1.0, 1.0), climb]

var rocket_cd = 4.0

func _gunship_rockets(dt: float) -> void:
	rocket_cd -= dt
	if rocket_cd > 0.0:
		return
	var p = null
	var d = driver()
	if d != null and is_instance_valid(d) and d.is_player:
		if Input.is_key_pressed(KEY_SHIFT) and player_inputs["fire"]:
			p = player_inputs["aim"]
	else:
		p = ClassAI.artillery_target(team, pos, 25.0)
	if p == null:
		return
	rocket_cd = 6.0 if (d == null or not d.is_player) else 1.2
	var shooter = d if d != null and is_instance_valid(d) else gunner()
	if shooter == null:
		return
	for side in [-1.0, 1.0]:
		var o = global_transform * Vector3(side * 1.3, 1.15, 1.5)
		Combat.launch_rocket(shooter, o, Combat.spread_dir((p - o).normalized(), 0.03), self)
