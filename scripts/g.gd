extends Node
# Global state and helpers shared by every script (autoload "G").

var DT = 1.0 / 60.0   # far soldiers in big battles tick at half rate with a doubled step
const GRAV = -9.8

# collision layers
const L_WORLD = 1
const L_BODY = 2
const L_DEBRIS = 4

# if dead soldiers' knees or elbows bend the wrong way, flip these to -1.0
var teams = 2
var vehicles: Array = []
var custom_map: Dictionary = {}
var random_seed = 12345
var editor = null
var reinf_mode = "truck"     # truck, para, instant
var armor = "light"          # none, light, heavy: vehicles each side starts with
const L_VEH = 8
var KNEE_SIGN = 1.0

# does an AI commander run this side (orders, building, buying troops)? Your own side only if you asked
# for one in the setup screen; in sandbox every side runs itself
func ai_runs(t: int) -> bool:
	if tutorial:
		return false          # the first battle: nobody commands the enemy, and you command yours
	if t != 0:
		return true
	return mode == "sandbox" or settings.get("ai_side", false)
var ELBOW_SIGN = 1.0

var main = null
var world = null
var fx = null
var audio = null
var ui = null
var pc = null          # player / camera controller
var navviz = null      # path debug view (F9)

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
var team_caps: Array = []
var factions = ["army", "army", "army", "army"]     # see Faction     # campaign battles: each side's own strength
var reinforce = true
var limit = 50
var started = false
var attract = false       # the little battle playing behind the title screen
var builder = false       # battle builder: both armies being set out, holding still until Start
var bal = {}              # counts of things that happen in a battle, for balance testing
var win_team = -2

func bal_add(k: String, n: int = 1) -> void:
	bal[k] = bal.get(k, 0) + n
var over = false
var game_time = 0.0
var view_range = 150.0
var path_budget = 0
var storm = false          # campaign weather: rain and low cloud, nothing flies
var tutorial = false       # the guided first battle is running
var merge_boxes = true     # map boxes drawn in a few big batches (off only to compare)
var orders = [{"mode": "free", "point": null}, {"mode": "free", "point": null}, {"mode": "free", "point": null}, {"mode": "free", "point": null}]
var squads: Array = []
var grenades: Array = []
var smoke_clouds: Array = []
var prof2 = {}
var sgrid = {}             # soldiers bucketed by 2 m cell, rebuilt every tick

func rebuild_sgrid() -> void:
	sgrid = {}
	for s in soldiers:
		if s.state == "alive":
			var k = int(floor(s.pos.x / 2.0)) * 65536 + int(floor(s.pos.z / 2.0))
			if not sgrid.has(k):
				sgrid[k] = [s]
			else:
				sgrid[k].append(s)

func soldiers_near(p: Vector3) -> Array:
	var out = []
	var cx = int(floor(p.x / 2.0))
	var cz = int(floor(p.z / 2.0))
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			var a = sgrid.get((cx + dx) * 65536 + cz + dz)
			if a != null:
				out.append_array(a)
	return out
var settings = {"sens": 1.0, "invert_y": false, "volume": 0.8, "music": 0.5, "blood": true, "callouts": true, "shadows": true, "grass": true, "time": "day", "weather": "clear", "difficulty": "normal", "ai_style": "random", "fps": true, "max_soldiers": 300, "lod_dist": 55.0, "voices": true, "ai_side": false, "keys": {}}

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
	# a militia side goes by its own name unless the player has named it
	for t in range(TEAM_NAMES.size()):
		if t < factions.size() and factions[t] == "militia" and TEAM_NAMES[t] in ["Alpha", "Bravo", "Charlie", "Delta"]:
			TEAM_NAMES[t] = "Black Banner"

func team_color(t: int) -> Color:
	return TEAM_BAND[t] if t >= 0 and t < TEAM_BAND.size() else Color(0.85, 0.85, 0.85)

# saved between sessions (in the browser this lives in the page's local storage)
# what a mode is played to when nobody picked a number (modes that end some other way get no limit)
func default_limit(mode: String) -> int:
	return {"deathmatch": 50, "capture": 200, "commander": 200, "koth": 120, "frontline": 100, "assault": 100,
		"breakthrough": 100, "siege": 100}.get(mode, 999999)

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
	"rifle":   {"id": "rifle", "mags": 9, "name": "Rifle", "mag": 30, "rof": 0.1, "auto": true, "dmg": 30.0, "pellets": 1, "spread": 0.011, "move_spread": 0.022, "force": 3.2, "reload": 2.3, "recoil": 0.011, "len": 0.92, "hold": 0.34, "snd_pitch": 1.0, "snd_vol": 0.0, "zoom": 42.0, "tracer": 330.0, "range": [12.0, 75.0], "burst": [2, 6], "speed": 1.0, "rocket": false},
	"lmg":     {"id": "lmg", "mags": 4, "name": "Machine gun", "mag": 100, "rof": 0.08, "auto": true, "dmg": 26.0, "pellets": 1, "spread": 0.02, "move_spread": 0.05, "force": 3.2, "reload": 4.5, "recoil": 0.014, "len": 1.08, "hold": 0.4, "snd_pitch": 0.85, "snd_vol": 1.5, "zoom": 44.0, "tracer": 330.0, "range": [18.0, 95.0], "burst": [6, 14], "speed": 0.85, "rocket": false},
	"sniper":  {"id": "sniper", "mags": 8, "name": "Sniper rifle", "mag": 5, "rof": 1.25, "auto": false, "dmg": 96.0, "pellets": 1, "spread": 0.0015, "move_spread": 0.045, "force": 7.5, "reload": 3.2, "recoil": 0.06, "len": 1.22, "hold": 0.4, "snd_pitch": 0.7, "snd_vol": 4.0, "zoom": 14.0, "tracer": 650.0, "range": [35.0, 170.0], "burst": [1, 1], "speed": 0.95, "rocket": false},
	"shotgun": {"id": "shotgun", "mags": 7, "name": "Shotgun", "mag": 8, "rof": 0.85, "auto": false, "dmg": 14.0, "pellets": 8, "spread": 0.055, "move_spread": 0.02, "force": 2.4, "reload": 3.4, "recoil": 0.045, "len": 0.86, "hold": 0.36, "snd_pitch": 0.6, "snd_vol": 3.0, "zoom": 52.0, "tracer": 300.0, "range": [2.0, 20.0], "burst": [1, 1], "speed": 1.05, "rocket": false},
	"hmg":     {"id": "hmg", "mags": 0, "name": "Mounted MG", "mag": 200, "rof": 0.085, "auto": true, "dmg": 34.0, "pellets": 1, "spread": 0.012, "move_spread": 0.0, "force": 4.0, "reload": 4.0, "recoil": 0.0, "len": 1.2, "hold": 0.4, "snd_pitch": 0.75, "snd_vol": 3.0, "zoom": 40.0, "tracer": 340.0, "range": [10.0, 120.0], "burst": [6, 16], "speed": 1.0, "rocket": false},
	"smg":     {"id": "smg", "mags": 7, "name": "Submachine gun", "mag": 32, "rof": 0.075, "auto": true, "dmg": 21.0, "pellets": 1, "spread": 0.022, "move_spread": 0.03, "force": 2.6, "reload": 2.2, "recoil": 0.009, "len": 0.62, "hold": 0.28, "snd_pitch": 1.2, "snd_vol": -1.0, "zoom": 48.0, "tracer": 300.0, "range": [3.0, 40.0], "burst": [4, 9], "speed": 1.05, "rocket": false},
	"pistol":  {"id": "pistol", "mags": 5, "name": "Pistol", "mag": 8, "rof": 0.22, "auto": false, "dmg": 26.0, "pellets": 1, "spread": 0.018, "move_spread": 0.02, "force": 2.4, "reload": 1.6, "recoil": 0.03, "len": 0.3, "hold": 0.12, "snd_pitch": 1.4, "snd_vol": -3.0, "zoom": 50.0, "tracer": 300.0, "range": [2.0, 30.0], "burst": [1, 2], "speed": 1.05, "rocket": false},
	"flamer":  {"id": "flamer", "mags": 2, "name": "Flamethrower", "mag": 120, "rof": 0.05, "auto": true, "dmg": 0.0, "pellets": 1, "spread": 0.06, "move_spread": 0.02, "force": 0.0, "reload": 5.0, "recoil": 0.0, "len": 0.9, "hold": 0.32, "snd_pitch": 0.4, "snd_vol": -4.0, "zoom": 55.0, "tracer": 0.0, "range": [2.0, 17.0], "burst": [12, 24], "speed": 0.9, "rocket": false, "flame": true},
	"atrifle": {"id": "atrifle", "mags": 6, "name": "Anti-tank rifle", "mag": 5, "rof": 1.6, "auto": false, "dmg": 130.0, "pellets": 1, "spread": 0.002, "move_spread": 0.05, "force": 9.0, "reload": 3.5, "recoil": 0.08, "len": 1.5, "hold": 0.5, "snd_pitch": 0.55, "snd_vol": 5.0, "zoom": 30.0, "tracer": 600.0, "range": [20.0, 140.0], "burst": [1, 1], "speed": 0.85, "rocket": false, "ap": true},
	"rpg":     {"id": "rpg", "mags": 4, "name": "Bazooka", "mag": 1, "rof": 1.0, "auto": false, "dmg": 0.0, "pellets": 1, "spread": 0.007, "move_spread": 0.03, "force": 5.0, "reload": 3.6, "recoil": 0.035, "len": 1.12, "hold": 0.42, "snd_pitch": 0.5, "snd_vol": 4.0, "zoom": 38.0, "tracer": 0.0, "range": [16.0, 85.0], "burst": [1, 1], "speed": 0.9, "rocket": true},
	"silenced": {"id": "silenced", "mags": 6, "name": "Silenced pistol", "mag": 8, "rof": 0.3, "auto": false, "dmg": 30.0, "pellets": 1, "spread": 0.014, "move_spread": 0.02, "force": 2.0, "reload": 1.8, "recoil": 0.02, "len": 0.48, "hold": 0.14, "snd_pitch": 2.2, "snd_vol": -20.0, "zoom": 50.0, "tracer": 0.0, "range": [2.0, 25.0], "burst": [1, 2], "speed": 1.05, "rocket": false, "silent": true},
	"carbine": {"id": "carbine", "mags": 8, "name": "Carbine", "mag": 15, "rof": 0.16, "auto": false, "dmg": 26.0, "pellets": 1, "spread": 0.012, "move_spread": 0.016, "force": 2.8, "reload": 2.0, "recoil": 0.012, "len": 0.8, "hold": 0.3, "snd_pitch": 1.1, "snd_vol": -1.0, "zoom": 44.0, "tracer": 320.0, "range": [8.0, 65.0], "burst": [2, 4], "speed": 1.05, "rocket": false},
	"bar":     {"id": "bar", "mags": 7, "name": "Automatic rifle", "mag": 20, "rof": 0.11, "auto": true, "dmg": 32.0, "pellets": 1, "spread": 0.014, "move_spread": 0.035, "force": 3.6, "reload": 2.8, "recoil": 0.016, "len": 1.04, "hold": 0.38, "snd_pitch": 0.9, "snd_vol": 1.0, "zoom": 42.0, "tracer": 330.0, "range": [12.0, 85.0], "burst": [3, 7], "speed": 0.92, "rocket": false},
	"dmr":     {"id": "dmr", "mags": 7, "name": "Marksman rifle", "mag": 10, "rof": 0.45, "auto": false, "dmg": 62.0, "pellets": 1, "spread": 0.003, "move_spread": 0.04, "force": 5.0, "reload": 2.6, "recoil": 0.035, "len": 1.08, "hold": 0.38, "snd_pitch": 0.8, "snd_vol": 2.0, "zoom": 22.0, "tracer": 520.0, "range": [25.0, 130.0], "burst": [1, 2], "speed": 0.97, "rocket": false},
	"gl":      {"id": "gl", "mags": 10, "name": "Grenade launcher", "mag": 1, "rof": 1.2, "auto": false, "dmg": 0.0, "pellets": 1, "spread": 0.02, "move_spread": 0.03, "force": 3.0, "reload": 2.2, "recoil": 0.04, "len": 0.7, "hold": 0.3, "snd_pitch": 1.6, "snd_vol": 0.0, "zoom": 46.0, "tracer": 0.0, "range": [20.0, 110.0], "burst": [1, 1], "speed": 1.0, "rocket": false, "gl": true, "reload_style": "single"},
	"pfaust":  {"id": "pfaust", "mags": 0, "name": "Panzerfaust", "mag": 1, "rof": 1.0, "auto": false, "dmg": 0.0, "pellets": 1, "spread": 0.012, "move_spread": 0.04, "force": 4.0, "reload": 1.0, "recoil": 0.03, "len": 1.0, "hold": 0.4, "snd_pitch": 0.6, "snd_vol": 3.0, "zoom": 44.0, "tracer": 0.0, "range": [8.0, 45.0], "burst": [1, 1], "speed": 0.95, "rocket": true},
}
const WEAPON_LIST = ["rifle", "lmg", "sniper", "shotgun", "rpg", "smg", "pistol", "flamer", "atrifle", "pfaust", "carbine", "bar", "dmr", "gl"]

# gun models: [x, y, z, w, h, l, colour] along the gun (z forward from the grip)
const C_DARK = Color(0.14, 0.15, 0.15)
const C_MID = Color(0.23, 0.24, 0.2)
const C_WOOD = Color(0.42, 0.29, 0.17)
const C_OLIVE = Color(0.29, 0.33, 0.21)
const C_GREEN = Color(0.25, 0.29, 0.18)
var GUN_MODELS = {
	"rifle": [[0, -0.01, -0.16, 0.05, 0.1, 0.17, C_DARK], [0, 0.03, 0.08, 0.06, 0.09, 0.34, C_DARK], [0, 0.045, 0.47, 0.025, 0.025, 0.42, C_DARK], [0, 0.035, 0.35, 0.055, 0.065, 0.22, C_MID],
		[0, -0.08, 0.13, 0.045, 0.16, 0.07, C_DARK], [0, -0.06, 0.0, 0.04, 0.1, 0.05, C_DARK], [0, 0.095, 0.06, 0.02, 0.04, 0.07, C_DARK]],
	"lmg": [[0, -0.01, -0.16, 0.06, 0.11, 0.17, C_DARK], [0, 0.03, 0.1, 0.08, 0.11, 0.4, C_DARK], [0, 0.045, 0.53, 0.035, 0.035, 0.5, C_DARK], [0, 0.045, 0.38, 0.055, 0.055, 0.18, C_MID], [0, -0.09, 0.12, 0.13, 0.13, 0.15, C_GREEN],
		[0.02, -0.05, 0.66, 0.015, 0.16, 0.015, C_DARK], [-0.02, -0.05, 0.66, 0.015, 0.16, 0.015, C_DARK], [0, 0.098, 0.16, 0.03, 0.03, 0.13, C_DARK], [0, -0.06, 0.0, 0.04, 0.1, 0.05, C_DARK]],
	"sniper": [[0, -0.01, -0.14, 0.055, 0.12, 0.2, C_WOOD], [0, 0.02, 0.16, 0.06, 0.08, 0.5, C_WOOD], [0, 0.045, 0.68, 0.025, 0.025, 0.6, C_DARK], [0, 0.11, 0.15, 0.05, 0.05, 0.32, C_DARK],
		[0, 0.075, 0.06, 0.02, 0.04, 0.02, C_DARK], [0, 0.075, 0.24, 0.02, 0.04, 0.02, C_DARK], [0.05, 0.04, 0.02, 0.05, 0.02, 0.02, C_DARK]],
	"shotgun": [[0, -0.01, -0.15, 0.05, 0.1, 0.18, C_WOOD], [0, 0.03, 0.06, 0.06, 0.08, 0.26, C_DARK], [0, 0.05, 0.38, 0.03, 0.03, 0.5, C_DARK], [0, 0.015, 0.38, 0.028, 0.028, 0.44, C_DARK],
		[0, 0.015, 0.32, 0.06, 0.06, 0.15, C_WOOD], [0, -0.06, 0.0, 0.04, 0.1, 0.05, C_DARK]],
	"smg": [[0, -0.01, -0.12, 0.045, 0.09, 0.14, C_DARK], [0, 0.03, 0.08, 0.055, 0.08, 0.28, C_DARK], [0, 0.04, 0.33, 0.03, 0.03, 0.22, C_DARK], [0, -0.09, 0.1, 0.035, 0.18, 0.04, C_DARK], [0, -0.06, -0.02, 0.04, 0.1, 0.05, C_DARK]],
	"pistol": [[0, 0.03, 0.06, 0.035, 0.05, 0.2, C_DARK], [0, -0.04, 0.0, 0.035, 0.1, 0.05, C_DARK]],
	"flamer": [[0, 0.03, 0.15, 0.06, 0.08, 0.5, C_DARK], [0, 0.04, 0.55, 0.05, 0.05, 0.32, C_MID], [0, -0.055, 0.15, 0.04, 0.1, 0.05, C_DARK], [0, 0.04, 0.74, 0.07, 0.07, 0.06, C_DARK]],
	"atrifle": [[0, -0.01, -0.2, 0.06, 0.12, 0.25, C_WOOD], [0, 0.02, 0.2, 0.07, 0.09, 0.6, C_DARK], [0, 0.04, 0.95, 0.04, 0.04, 0.9, C_DARK], [0, 0.04, 1.42, 0.08, 0.06, 0.1, C_DARK],
		[0.025, -0.075, 1.1, 0.015, 0.2, 0.015, C_DARK], [-0.025, -0.075, 1.1, 0.015, 0.2, 0.015, C_DARK], [0, 0.088, 0.18, 0.045, 0.045, 0.22, C_DARK]],
	"silenced": [[0, 0.03, 0.06, 0.035, 0.05, 0.2, C_DARK], [0, 0.03, 0.26, 0.045, 0.045, 0.24, C_MID], [0, -0.04, 0.0, 0.035, 0.1, 0.05, C_DARK]],
	"pfaust": [[0, 0.02, 0.2, 0.055, 0.055, 0.9, C_OLIVE], [0, 0.02, 0.75, 0.16, 0.16, 0.2, C_GREEN], [0, 0.02, 0.89, 0.11, 0.11, 0.12, C_GREEN], [0, 0.02, 0.97, 0.05, 0.05, 0.08, C_DARK], [0, 0.08, 0.38, 0.025, 0.07, 0.03, C_DARK], [0, -0.035, 0.3, 0.035, 0.06, 0.04, C_DARK]],
	"rpg": [[0, 0.02, 0.3, 0.11, 0.11, 1.12, C_OLIVE], [0, 0.02, 0.93, 0.15, 0.15, 0.22, C_GREEN], [0, -0.08, 0.12, 0.04, 0.11, 0.05, C_DARK], [0.07, 0.08, 0.28, 0.03, 0.07, 0.05, C_DARK], [0, -0.07, 0.36, 0.04, 0.1, 0.05, C_DARK]],
	# a short wooden carbine with a small box magazine
	"carbine": [[0, -0.01, -0.14, 0.045, 0.09, 0.16, C_WOOD], [0, 0.025, 0.08, 0.05, 0.07, 0.36, C_WOOD], [0, 0.05, 0.08, 0.035, 0.03, 0.22, C_DARK],
		[0, 0.045, 0.4, 0.022, 0.022, 0.26, C_DARK], [0, -0.055, 0.1, 0.035, 0.08, 0.05, C_DARK], [0, -0.05, -0.01, 0.035, 0.09, 0.045, C_WOOD], [0, 0.08, 0.04, 0.015, 0.03, 0.02, C_DARK]],
	# a heavy automatic rifle: long receiver, bipod folded under the barrel, box magazine underneath
	"bar": [[0, -0.01, -0.17, 0.05, 0.11, 0.18, C_WOOD], [0, 0.03, 0.1, 0.065, 0.1, 0.4, C_DARK], [0, 0.04, 0.5, 0.03, 0.03, 0.42, C_DARK],
		[0, 0.025, 0.36, 0.06, 0.06, 0.2, C_WOOD], [0, -0.07, 0.14, 0.05, 0.12, 0.08, C_DARK], [0.015, 0.0, 0.6, 0.012, 0.012, 0.22, C_DARK], [-0.015, 0.0, 0.6, 0.012, 0.012, 0.22, C_DARK],
		[0, 0.095, 0.0, 0.02, 0.03, 0.05, C_DARK], [0, -0.06, -0.01, 0.04, 0.1, 0.05, C_DARK]],
	# a semi-automatic rifle with a short scope
	"dmr": [[0, -0.01, -0.15, 0.05, 0.11, 0.19, C_WOOD], [0, 0.025, 0.14, 0.055, 0.08, 0.46, C_WOOD], [0, 0.045, 0.6, 0.024, 0.024, 0.42, C_DARK],
		[0, 0.1, 0.12, 0.045, 0.045, 0.24, C_DARK], [0, 0.1, 0.25, 0.055, 0.055, 0.03, C_DARK], [0, -0.065, 0.1, 0.04, 0.1, 0.06, C_DARK], [0, -0.05, -0.01, 0.035, 0.09, 0.045, C_WOOD]],
	# a stubby break-open grenade launcher with a fat barrel and a leaf sight
	"gl": [[0, -0.01, -0.12, 0.05, 0.1, 0.18, C_WOOD], [0, 0.03, 0.08, 0.05, 0.07, 0.14, C_DARK], [0, 0.04, 0.32, 0.085, 0.085, 0.36, C_OLIVE],
		[0, 0.04, 0.5, 0.095, 0.095, 0.03, C_DARK], [0, 0.1, 0.16, 0.04, 0.05, 0.015, C_DARK], [0, -0.05, -0.01, 0.035, 0.09, 0.045, C_WOOD], [0, 0.0, 0.2, 0.06, 0.04, 0.16, C_WOOD]],
}

# the militia's guns look different: AK-pattern rifles with wood furniture and curved magazines,
# old bolt-action rifles, a belt-fed MG with a skeleton stock, and RPG-7s. (x, y, z, w, h, d, colour, tilt)
var GUN_MODELS_MIL = {
	"ak": [[0, -0.02, -0.18, 0.045, 0.09, 0.2, C_WOOD], [0, 0.03, 0.07, 0.055, 0.08, 0.3, C_DARK], [0, 0.075, 0.08, 0.05, 0.02, 0.26, C_MID],
		[0, 0.03, 0.3, 0.06, 0.07, 0.18, C_WOOD], [0, 0.075, 0.3, 0.04, 0.035, 0.16, C_WOOD], [0, 0.035, 0.5, 0.022, 0.022, 0.3, C_DARK],
		[0, 0.07, 0.6, 0.015, 0.04, 0.02, C_DARK], [0, 0.035, 0.66, 0.03, 0.03, 0.04, C_DARK], [0, -0.05, -0.01, 0.035, 0.09, 0.045, C_DARK],
		[0, -0.07, 0.13, 0.035, 0.12, 0.06, C_DARK, -0.3], [0, -0.155, 0.165, 0.035, 0.08, 0.055, C_DARK, -0.65]],
	"bolt": [[0, -0.02, -0.18, 0.05, 0.1, 0.22, C_WOOD], [0, 0.015, 0.2, 0.05, 0.06, 0.55, C_WOOD], [0, 0.045, 0.62, 0.022, 0.022, 0.6, C_DARK],
		[0, 0.05, 0.04, 0.04, 0.04, 0.2, C_DARK], [0.045, 0.05, 0.0, 0.05, 0.015, 0.015, C_DARK], [0, 0.02, 0.42, 0.055, 0.065, 0.02, C_DARK],
		[0, -0.05, -0.01, 0.035, 0.07, 0.05, C_WOOD]],
	"lmg": [[0, -0.02, -0.17, 0.03, 0.1, 0.2, C_WOOD], [0, 0.03, 0.1, 0.07, 0.1, 0.38, C_DARK], [0, 0.045, 0.56, 0.03, 0.03, 0.55, C_DARK],
		[0, -0.1, 0.12, 0.1, 0.11, 0.12, Color(0.3, 0.32, 0.22)], [0.02, -0.05, 0.72, 0.015, 0.16, 0.015, C_DARK], [-0.02, -0.05, 0.72, 0.015, 0.16, 0.015, C_DARK],
		[0, 0.095, 0.12, 0.03, 0.03, 0.12, C_DARK], [0, -0.06, 0.0, 0.04, 0.1, 0.05, C_DARK]],
	"sniper": [[0, -0.02, -0.18, 0.04, 0.12, 0.22, C_WOOD], [0, 0.03, 0.1, 0.05, 0.08, 0.34, C_DARK], [0, 0.03, 0.38, 0.055, 0.065, 0.22, C_WOOD],
		[0, 0.04, 0.72, 0.022, 0.022, 0.5, C_DARK], [0, 0.088, 0.08, 0.04, 0.04, 0.24, C_DARK], [0, -0.052, 0.14, 0.03, 0.09, 0.06, C_DARK]],
	"rpg": [[0, 0.02, 0.15, 0.07, 0.07, 0.95, Color(0.24, 0.26, 0.2)], [0, 0.02, 0.05, 0.085, 0.085, 0.18, C_WOOD], [0, 0.02, 0.72, 0.11, 0.11, 0.16, C_OLIVE],
		[0, 0.02, 0.84, 0.07, 0.07, 0.1, C_OLIVE], [0, 0.02, 0.92, 0.03, 0.03, 0.08, C_DARK], [0, -0.08, 0.0, 0.04, 0.11, 0.05, C_DARK],
		[0, -0.08, 0.15, 0.04, 0.11, 0.05, C_DARK], [0, 0.02, -0.36, 0.1, 0.1, 0.08, C_DARK], [0.06, 0.07, 0.2, 0.03, 0.06, 0.05, C_DARK]],
}

# which model a soldier's gun uses
func gun_model(wid_: String, team_: int, id_: int) -> Array:
	if Faction.militia(team_):
		match wid_:
			"rifle":
				return GUN_MODELS_MIL["bolt"] if id_ % 3 == 0 else GUN_MODELS_MIL["ak"]
			"smg":
				return GUN_MODELS_MIL["ak"]
			"lmg", "sniper", "rpg":
				return GUN_MODELS_MIL[wid_]
	return GUN_MODELS[wid_]

func _fill_weapon_defaults() -> void:
	for k in WEAPONS:
		var w = WEAPONS[k]
		if not w.has("flame"):
			w["flame"] = false
		if not w.has("ap"):
			w["ap"] = false
		if not w.has("gl"):
			w["gl"] = false
		# how it's reloaded: a magazine swapped, shells pushed in one by one, a round dropped into the breech,
		# or a rocket slid into the back of the tube
		if not w.has("reload_style"):
			w["reload_style"] = {"shotgun": "shells", "sniper": "shells", "rpg": "rocket", "atrifle": "mag", "pfaust": "rocket"}.get(k, "mag")
		# bolt actions: the bolt is worked by hand after every shot
		w["bolt"] = k in ["sniper", "atrifle"]

# the area round a side's spawn and rally point, where fresh troops and vehicles arrive: no shelling it
func near_spawn(p: Vector3, r: float = 40.0) -> bool:
	if world == null:
		return false
	for t in range(team_count()):
		if dist2d(p, world.spawn[t]) < r or dist2d(p, world.rally_point(t)) < r * 0.8:
			return true
	return false

func size_of(t: int) -> int:
	return team_caps[t] if t < team_caps.size() else team_size

func team_count() -> int:
	return teams

func _ready() -> void:
	_fill_weapon_defaults()
	load_prefs()
	apply_teams()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--knee="):
			KNEE_SIGN = float(a.substr(7))

# ---------------------------------------------------------------- classes
const CLASSES = {
	"rifleman": {"name": "Rifleman", "w": ["rifle", "rifle", "rifle", "rifle", "bar", "gl", "carbine"], "share": 0.26},
	"mg": {"name": "Machine gunner", "w": ["lmg"], "share": 0.12},
	"medic": {"name": "Medic", "w": ["smg"], "share": 0.12},
	"at": {"name": "Anti-tank", "w": ["rpg", "rpg", "atrifle"], "share": 0.1},
	"engineer": {"name": "Engineer", "w": ["shotgun", "smg", "carbine"], "share": 0.14},
	"assault": {"name": "Assault", "w": ["smg", "smg", "shotgun", "flamer", "bar"], "share": 0.1},
	"radio": {"name": "Radio operator", "w": ["carbine", "rifle"], "share": 0.06},
	"sniper": {"name": "Sniper", "w": ["sniper", "sniper", "dmr"], "share": 0.05},
	"spotter": {"name": "Spotter", "w": ["carbine", "rifle"], "share": 0.05},
	"officer": {"name": "Officer", "w": ["smg", "pistol"], "share": 0.0},
}

# the class this team is shortest of, compared with the mix above
func pick_class(team: int) -> String:
	var have = {}
	var n = 0
	for s in soldiers:
		if s.team == team and s.state != "dead":
			have[s.cls] = have.get(s.cls, 0) + 1
			n += 1
	if n >= 5 and have.get("officer", 0) == 0:
		return "officer"
	var best = "rifleman"
	var bd = -1e9
	for c in CLASSES:
		var d = CLASSES[c]["share"] * (n + 1) - have.get(c, 0) + randf() * 0.3
		if c == "spotter" and have.get("sniper", 0) <= have.get("spotter", 0):
			d -= 10.0
		if d > bd:
			bd = d
			best = c
	return best

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
