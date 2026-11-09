extends Node
# Global state and helpers shared by every script (autoload "G").

const DT = 1.0 / 60.0
const GRAV = -9.8

# collision layers
const L_WORLD = 1
const L_BODY = 2
const L_DEBRIS = 4

# if dead soldiers' knees or elbows bend the wrong way, flip these to -1.0
var KNEE_SIGN = 1.0
var ELBOW_SIGN = 1.0

var main = null
var world = null
var fx = null
var audio = null
var ui = null
var pc = null          # player / camera controller

var soldiers: Array = []
var player = null
var sim_time = 0.0
var score = [0, 0]
var cap_score = [0.0, 0.0]
var cap_owner = -1
var cap_prog = 0.0
var cap_contested = false

var mode = "sandbox"      # sandbox, deathmatch, capture
var map_id = "town"
var team_size = 10
var reinforce = true
var limit = 50
var started = false
var over = false
var game_time = 0.0
var view_range = 150.0
var path_budget = 0
var orders = [{"mode": "free", "point": null}, {"mode": "free", "point": null}]
var squads: Array = []
var grenades: Array = []
var smoke_clouds: Array = []
var settings = {"sens": 1.0, "invert_y": false, "volume": 0.8, "blood": true, "callouts": true}

const TEAM_NAMES = ["Alpha", "Bravo"]
var TEAM_BAND = [Color(0.18, 0.44, 0.88), Color(0.84, 0.17, 0.17)]
var TEAM_UNI = [Color(0.36, 0.43, 0.25), Color(0.48, 0.46, 0.31)]
var TEAM_UNI2 = [Color(0.31, 0.36, 0.22), Color(0.40, 0.39, 0.25)]
var TEAM_VEST = [Color(0.28, 0.31, 0.18), Color(0.35, 0.33, 0.23)]
var TEAM_HELM = [Color(0.30, 0.35, 0.20), Color(0.38, 0.36, 0.24)]
var SKINS = [Color(0.91, 0.73, 0.55), Color(0.82, 0.61, 0.42), Color(0.56, 0.38, 0.24), Color(0.94, 0.79, 0.63), Color(0.71, 0.49, 0.33)]
const NAMES = ["Miller","Kowalski","Reyes","Novak","Park","Hughes","Silva","Ivanov","Okafor","Brandt","Dubois","Tanaka","Walsh","Costa","Larsen","Haddad","Petrov","Moreau","Kim","Ortiz","Jensen","Bauer","Russo","Nakamura","Fischer","Byrne","Duarte","Lindqvist","Abara","Sato","Grant","Weber","Rossi"]

var WEAPONS = {
	"rifle":   {"id": "rifle", "name": "Rifle", "mag": 30, "rof": 0.1, "auto": true, "dmg": 30.0, "pellets": 1, "spread": 0.011, "move_spread": 0.022, "force": 3.2, "reload": 2.3, "recoil": 0.011, "len": 0.92, "hold": 0.34, "snd_pitch": 1.0, "snd_vol": 0.0, "zoom": 42.0, "tracer": 330.0, "range": [12.0, 75.0], "burst": [2, 6], "speed": 1.0, "rocket": false},
	"lmg":     {"id": "lmg", "name": "Machine gun", "mag": 100, "rof": 0.08, "auto": true, "dmg": 26.0, "pellets": 1, "spread": 0.02, "move_spread": 0.05, "force": 3.2, "reload": 4.5, "recoil": 0.014, "len": 1.08, "hold": 0.4, "snd_pitch": 0.85, "snd_vol": 1.5, "zoom": 44.0, "tracer": 330.0, "range": [18.0, 95.0], "burst": [6, 14], "speed": 0.85, "rocket": false},
	"sniper":  {"id": "sniper", "name": "Sniper rifle", "mag": 5, "rof": 1.25, "auto": false, "dmg": 96.0, "pellets": 1, "spread": 0.0015, "move_spread": 0.045, "force": 7.5, "reload": 3.2, "recoil": 0.06, "len": 1.22, "hold": 0.4, "snd_pitch": 0.7, "snd_vol": 4.0, "zoom": 14.0, "tracer": 650.0, "range": [35.0, 170.0], "burst": [1, 1], "speed": 0.95, "rocket": false},
	"shotgun": {"id": "shotgun", "name": "Shotgun", "mag": 8, "rof": 0.85, "auto": false, "dmg": 14.0, "pellets": 8, "spread": 0.055, "move_spread": 0.02, "force": 2.4, "reload": 3.4, "recoil": 0.045, "len": 0.86, "hold": 0.36, "snd_pitch": 0.6, "snd_vol": 3.0, "zoom": 52.0, "tracer": 300.0, "range": [2.0, 20.0], "burst": [1, 1], "speed": 1.05, "rocket": false},
	"rpg":     {"id": "rpg", "name": "Rocket launcher", "mag": 1, "rof": 1.0, "auto": false, "dmg": 0.0, "pellets": 1, "spread": 0.007, "move_spread": 0.03, "force": 5.0, "reload": 3.6, "recoil": 0.035, "len": 1.12, "hold": 0.42, "snd_pitch": 0.5, "snd_vol": 4.0, "zoom": 38.0, "tracer": 0.0, "range": [16.0, 85.0], "burst": [1, 1], "speed": 0.9, "rocket": true},
}
const WEAPON_LIST = ["rifle", "lmg", "sniper", "shotgun", "rpg"]

# gun models: [x, y, z, w, h, l, colour] along the gun (z forward from the grip)
const C_DARK = Color(0.14, 0.15, 0.15)
const C_MID = Color(0.23, 0.24, 0.2)
const C_WOOD = Color(0.42, 0.29, 0.17)
const C_OLIVE = Color(0.29, 0.33, 0.21)
const C_GREEN = Color(0.25, 0.29, 0.18)
var GUN_MODELS = {
	"rifle": [[0, -0.01, -0.16, 0.05, 0.1, 0.17, C_DARK], [0, 0.03, 0.08, 0.06, 0.09, 0.34, C_DARK], [0, 0.045, 0.47, 0.025, 0.025, 0.42, C_DARK], [0, 0.035, 0.35, 0.055, 0.065, 0.22, C_MID],
		[0, -0.08, 0.13, 0.045, 0.16, 0.07, C_DARK], [0, -0.06, 0.0, 0.04, 0.1, 0.05, C_DARK], [0, 0.1, 0.06, 0.02, 0.04, 0.07, C_DARK]],
	"lmg": [[0, -0.01, -0.16, 0.06, 0.11, 0.17, C_DARK], [0, 0.03, 0.1, 0.08, 0.11, 0.4, C_DARK], [0, 0.045, 0.6, 0.035, 0.035, 0.5, C_DARK], [0, -0.09, 0.12, 0.13, 0.13, 0.15, C_GREEN],
		[0.035, -0.06, 0.7, 0.015, 0.16, 0.015, C_DARK], [-0.035, -0.06, 0.7, 0.015, 0.16, 0.015, C_DARK], [0, 0.115, 0.16, 0.03, 0.03, 0.13, C_DARK], [0, -0.06, 0.0, 0.04, 0.1, 0.05, C_DARK]],
	"sniper": [[0, -0.01, -0.14, 0.055, 0.12, 0.2, C_WOOD], [0, 0.02, 0.16, 0.06, 0.08, 0.5, C_WOOD], [0, 0.045, 0.68, 0.025, 0.025, 0.6, C_DARK], [0, 0.11, 0.15, 0.05, 0.05, 0.32, C_DARK],
		[0, 0.075, 0.06, 0.02, 0.04, 0.02, C_DARK], [0, 0.075, 0.24, 0.02, 0.04, 0.02, C_DARK], [0.05, 0.04, 0.02, 0.05, 0.02, 0.02, C_DARK]],
	"shotgun": [[0, -0.01, -0.15, 0.05, 0.1, 0.18, C_WOOD], [0, 0.03, 0.07, 0.06, 0.08, 0.24, C_DARK], [0, 0.05, 0.38, 0.03, 0.03, 0.5, C_DARK], [0, 0.015, 0.38, 0.028, 0.028, 0.44, C_DARK],
		[0, 0.015, 0.32, 0.06, 0.06, 0.15, C_WOOD], [0, -0.06, 0.0, 0.04, 0.1, 0.05, C_DARK]],
	"rpg": [[0, 0.02, 0.3, 0.11, 0.11, 1.12, C_OLIVE], [0, 0.02, 0.93, 0.15, 0.15, 0.22, C_GREEN], [0, -0.08, 0.12, 0.04, 0.11, 0.05, C_DARK], [0.07, 0.08, 0.28, 0.03, 0.07, 0.05, C_DARK], [0, -0.07, 0.36, 0.04, 0.1, 0.05, C_DARK]],
}

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--knee="):
			KNEE_SIGN = float(a.substr(7))

func random_weapon() -> String:
	var r = randf()
	if r < 0.54: return "rifle"
	if r < 0.70: return "lmg"
	if r < 0.82: return "shotgun"
	if r < 0.93: return "sniper"
	return "rpg"

# ---------------------------------------------------------------- helpers
func rnd(a: float, b: float) -> float:
	return randf_range(a, b)

func wrap_a(a: float) -> float:
	return wrapf(a, -PI, PI)

func turn_to(a: float, b: float, m: float) -> float:
	return a + clampf(wrap_a(b - a), -m, m)

func smooth01(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)

func pick(arr: Array):
	return arr[randi() % arr.size()]

func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

func dist2d(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func alive_count(team: int) -> int:
	var n = 0
	for s in soldiers:
		if s.team == team and s.state != "dead":
			n += 1
	return n

# physics ray against the world (and optionally bodies). Returns {} or the hit dictionary.
func ray(from: Vector3, to: Vector3, mask: int, exclude: Array = []) -> Dictionary:
	var space = main.get_world_3d().direct_space_state
	var q = PhysicsRayQueryParameters3D.create(from, to, mask)
	if not exclude.is_empty():
		var ex: Array[RID] = []
		ex.assign(exclude)
		q.exclude = ex
	return space.intersect_ray(q)

# is the straight line a->b blocked by the world (and optionally smoke)?
func blocked(a: Vector3, b: Vector3, smoke: bool = false) -> bool:
	var d = b - a
	var L = d.length()
	if L < 0.05:
		return false
	var hit = ray(a, a + d * ((L - 0.08) / L), L_WORLD)
	if not hit.is_empty():
		return true
	if smoke:
		var dir = d / L
		for sc in smoke_clouds:
			if sc.r < 1.0:
				continue
			var t = clampf((sc.p - a).dot(dir), 0.0, L)
			if (a + dir * t).distance_squared_to(sc.p) < sc.r * sc.r * 0.7:
				return true
	return false
