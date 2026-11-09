extends Node
# Global state and helpers shared by every script (autoload "G").

const DT = 1.0 / 60.0
const GRAV = -9.8

# collision layers
const L_WORLD = 1
const L_BODY = 2
const L_DEBRIS = 4

# if dead soldiers' knees or elbows bend the wrong way, flip these to -1.0
var teams = 2
var vehicles: Array = []
var reinf_mode = "truck"     # truck, para, instant
var armor = "light"          # none, light, heavy: vehicles each side starts with
const L_VEH = 8
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
var orders = [{"mode": "free", "point": null}, {"mode": "free", "point": null}, {"mode": "free", "point": null}, {"mode": "free", "point": null}]
var squads: Array = []
var grenades: Array = []
var smoke_clouds: Array = []
var settings = {"sens": 1.0, "invert_y": false, "volume": 0.8, "blood": true, "callouts": true, "shadows": true, "grass": true, "time": "day"}

# ---------------------------------------------------------------- teams: names, armband colours and uniforms
const UNIFORMS = {
	"Woodland": [Color(0.36, 0.43, 0.25), Color(0.31, 0.36, 0.22), Color(0.28, 0.31, 0.18), Color(0.30, 0.35, 0.20)],
	"Desert": [Color(0.66, 0.58, 0.42), Color(0.58, 0.5, 0.36), Color(0.52, 0.45, 0.32), Color(0.6, 0.53, 0.38)],
	"Olive drab": [Color(0.48, 0.46, 0.31), Color(0.40, 0.39, 0.25), Color(0.35, 0.33, 0.23), Color(0.38, 0.36, 0.24)],
	"Winter": [Color(0.86, 0.87, 0.88), Color(0.74, 0.76, 0.78), Color(0.55, 0.57, 0.58), Color(0.9, 0.9, 0.9)],
	"Urban grey": [Color(0.45, 0.46, 0.47), Color(0.36, 0.37, 0.38), Color(0.25, 0.26, 0.27), Color(0.3, 0.31, 0.32)],
	"Jungle": [Color(0.22, 0.32, 0.18), Color(0.18, 0.26, 0.14), Color(0.17, 0.2, 0.12), Color(0.2, 0.28, 0.15)],
	"Navy": [Color(0.2, 0.25, 0.36), Color(0.16, 0.2, 0.29), Color(0.13, 0.15, 0.2), Color(0.18, 0.21, 0.28)],
	"Field brown": [Color(0.45, 0.36, 0.26), Color(0.38, 0.3, 0.21), Color(0.3, 0.24, 0.17), Color(0.35, 0.28, 0.2)],
}
const BANDS = {"Blue": Color(0.18, 0.44, 0.88), "Red": Color(0.84, 0.17, 0.17), "Green": Color(0.2, 0.7, 0.25),
	"Yellow": Color(0.92, 0.78, 0.15), "Orange": Color(0.95, 0.5, 0.1), "Purple": Color(0.58, 0.28, 0.82),
	"White": Color(0.92, 0.92, 0.92), "Black": Color(0.1, 0.1, 0.1)}
var team_cfg = [
	{"name": "Alpha", "band": "Blue", "uniform": "Woodland"},
	{"name": "Bravo", "band": "Red", "uniform": "Olive drab"},
	{"name": "Charlie", "band": "Green", "uniform": "Desert"},
	{"name": "Delta", "band": "Yellow", "uniform": "Urban grey"},
]
var TEAM_NAMES = []
var TEAM_BAND = []
var TEAM_UNI = []
var TEAM_UNI2 = []
var TEAM_VEST = []
var TEAM_HELM = []

func apply_teams() -> void:
	TEAM_NAMES = []; TEAM_BAND = []; TEAM_UNI = []; TEAM_UNI2 = []; TEAM_VEST = []; TEAM_HELM = []
	for c in team_cfg:
		var u: Array = UNIFORMS.get(c["uniform"], UNIFORMS["Woodland"])
		TEAM_NAMES.append(c["name"] if c["name"].strip_edges() != "" else "Team")
		TEAM_BAND.append(BANDS.get(c["band"], Color.WHITE))
		TEAM_UNI.append(u[0]); TEAM_UNI2.append(u[1]); TEAM_VEST.append(u[2]); TEAM_HELM.append(u[3])

func team_color(t: int) -> Color:
	return TEAM_BAND[t] if t >= 0 and t < TEAM_BAND.size() else Color(0.85, 0.85, 0.85)

# saved between sessions (in the browser this lives in the page's local storage)
func save_prefs() -> void:
	var cf = ConfigFile.new()
	for k in settings:
		cf.set_value("settings", k, settings[k])
	cf.set_value("teams", "cfg", team_cfg)
	cf.save("user://prefs.cfg")

func load_prefs() -> void:
	var cf = ConfigFile.new()
	if cf.load("user://prefs.cfg") != OK:
		return
	for k in settings:
		settings[k] = cf.get_value("settings", k, settings[k])
	var tc = cf.get_value("teams", "cfg", null)
	if tc is Array and tc.size() == 4:
		team_cfg = tc
var SKINS = [Color(0.91, 0.73, 0.55), Color(0.82, 0.61, 0.42), Color(0.56, 0.38, 0.24), Color(0.94, 0.79, 0.63), Color(0.71, 0.49, 0.33)]
const NAMES = ["Miller","Kowalski","Reyes","Novak","Park","Hughes","Silva","Ivanov","Okafor","Brandt","Dubois","Tanaka","Walsh","Costa","Larsen","Haddad","Petrov","Moreau","Kim","Ortiz","Jensen","Bauer","Russo","Nakamura","Fischer","Byrne","Duarte","Lindqvist","Abara","Sato","Grant","Weber","Rossi"]

var WEAPONS = {
	"rifle":   {"id": "rifle", "mags": 5, "name": "Rifle", "mag": 30, "rof": 0.1, "auto": true, "dmg": 30.0, "pellets": 1, "spread": 0.011, "move_spread": 0.022, "force": 3.2, "reload": 2.3, "recoil": 0.011, "len": 0.92, "hold": 0.34, "snd_pitch": 1.0, "snd_vol": 0.0, "zoom": 42.0, "tracer": 330.0, "range": [12.0, 75.0], "burst": [2, 6], "speed": 1.0, "rocket": false},
	"lmg":     {"id": "lmg", "mags": 2, "name": "Machine gun", "mag": 100, "rof": 0.08, "auto": true, "dmg": 26.0, "pellets": 1, "spread": 0.02, "move_spread": 0.05, "force": 3.2, "reload": 4.5, "recoil": 0.014, "len": 1.08, "hold": 0.4, "snd_pitch": 0.85, "snd_vol": 1.5, "zoom": 44.0, "tracer": 330.0, "range": [18.0, 95.0], "burst": [6, 14], "speed": 0.85, "rocket": false},
	"sniper":  {"id": "sniper", "mags": 5, "name": "Sniper rifle", "mag": 5, "rof": 1.25, "auto": false, "dmg": 96.0, "pellets": 1, "spread": 0.0015, "move_spread": 0.045, "force": 7.5, "reload": 3.2, "recoil": 0.06, "len": 1.22, "hold": 0.4, "snd_pitch": 0.7, "snd_vol": 4.0, "zoom": 14.0, "tracer": 650.0, "range": [35.0, 170.0], "burst": [1, 1], "speed": 0.95, "rocket": false},
	"shotgun": {"id": "shotgun", "mags": 4, "name": "Shotgun", "mag": 8, "rof": 0.85, "auto": false, "dmg": 14.0, "pellets": 8, "spread": 0.055, "move_spread": 0.02, "force": 2.4, "reload": 3.4, "recoil": 0.045, "len": 0.86, "hold": 0.36, "snd_pitch": 0.6, "snd_vol": 3.0, "zoom": 52.0, "tracer": 300.0, "range": [2.0, 20.0], "burst": [1, 1], "speed": 1.05, "rocket": false},
	"hmg":     {"id": "hmg", "mags": 0, "name": "Mounted MG", "mag": 200, "rof": 0.085, "auto": true, "dmg": 34.0, "pellets": 1, "spread": 0.012, "move_spread": 0.0, "force": 4.0, "reload": 4.0, "recoil": 0.0, "len": 1.2, "hold": 0.4, "snd_pitch": 0.75, "snd_vol": 3.0, "zoom": 40.0, "tracer": 340.0, "range": [10.0, 120.0], "burst": [6, 16], "speed": 1.0, "rocket": false},
	"rpg":     {"id": "rpg", "mags": 2, "name": "Rocket launcher", "mag": 1, "rof": 1.0, "auto": false, "dmg": 0.0, "pellets": 1, "spread": 0.007, "move_spread": 0.03, "force": 5.0, "reload": 3.6, "recoil": 0.035, "len": 1.12, "hold": 0.42, "snd_pitch": 0.5, "snd_vol": 4.0, "zoom": 38.0, "tracer": 0.0, "range": [16.0, 85.0], "burst": [1, 1], "speed": 0.9, "rocket": true},
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

func team_count() -> int:
	return teams

func _ready() -> void:
	load_prefs()
	apply_teams()
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
