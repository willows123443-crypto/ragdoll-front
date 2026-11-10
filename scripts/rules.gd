class_name Rules
extends RefCounted
# What each game mode allows, in one place: what each side may build, which call-ins it gets,
# and which tools the player has. Sandbox is the only mode with free spawning and effects.

const FIRE = ["artillery", "airstrike", "recon"]
const TROOPS = ["paradrop", "heli"]
const AIR = ["gunship", "fighter", "bomber"]
const LIGHT = ["jeep", "motorbike", "technical", "ambulance"]
const ARMOUR = ["halftrack", "armoredcar", "tank", "heavytank", "plough", "atgun", "bridger", "radar"]
const BASE = ["fob", "sandbags", "wire", "traps", "mgnest", "mortarpit", "aa", "tower", "bunker", "hospital", "radio", "depot", "supply"]
const DIG_IN = ["sandbags", "wire", "traps", "mgnest", "bunker", "tower"]

# what side t may build (the AI side builds from this list, and so does the player)
static func build(t: int, mode: String = "") -> Array:
	match mode if mode != "" else G.mode:
		"sandbox":
			return BASE.duplicate()
		"deathmatch", "capture", "koth", "sabotage", "rescue", "general":
			return []        # straight fights: nobody builds
		"frontline":
			return ["fob", "sandbags", "mgnest", "hospital"]
		"laststand":
			return ["sandbags", "wire", "traps", "mgnest"] if t == 0 else []
		"horde":
			return ["sandbags", "wire", "traps", "mgnest", "tower"] if t == 0 else []
		"assault", "breakthrough":
			# attackers bring forward bases and aid stations; defenders dig in
			var defender = 1
			return DIG_IN.duplicate() if t == defender else ["fob", "hospital", "sandbags"]
		"siege":
			return ["sandbags", "wire", "traps", "mgnest", "bunker", "hospital"] if t == 0 else ["fob", "mortarpit", "sandbags"]
		"escort":
			# the ambushers block the road; the convoy just drives
			return ["wire", "traps", "mgnest"] if t == 1 else []
		"destroy", "commander":
			return BASE.duplicate()
	return []

# whether side t starts with an HQ (a base to defend or a rear base to respawn at)
static func has_hq(t: int) -> bool:
	match G.mode:
		"destroy", "commander", "frontline":
			return true
		"assault", "breakthrough":
			return t == 0
		"siege":
			return t == 1
	return false

# what the AI builds for side t (the player's own side in commander mode builds only what the player orders)
static func ai_build(t: int) -> Array:
	if G.mode == "sandbox" or (G.mode == "commander" and t == 0):
		return []
	return build(t)

# the call-ins side t can use in this mode
static func callins(t: int, mode: String = "") -> Array:
	var m = mode if mode != "" else G.mode
	var veh = [] if G.armor == "none" else LIGHT + (ARMOUR if G.armor == "heavy" or m in ["commander", "destroy", "sandbox"] else ["halftrack", "armoredcar", "atgun"])
	# in commander mode the vehicles setting is only what each side starts with: the depot can always build
	if m == "commander":
		veh = LIGHT + ARMOUR
	# extra troops are only bought in sandbox and commander mode: everywhere else reinforcements come free
	match m:
		"sandbox", "commander":
			return FIRE + TROOPS + AIR + veh
		"destroy", "frontline":
			return FIRE + AIR + veh
		"deathmatch", "capture", "koth":
			return FIRE + veh
		"assault", "breakthrough":
			return FIRE + AIR + veh if t == 0 else ["artillery", "recon", "atgun"]
		"laststand":
			return ["artillery", "airstrike"] if t == 0 else []
		"horde":
			return ["artillery", "airstrike"] if t == 0 else []
		"siege":
			return ["artillery", "recon"] if t == 0 else FIRE + veh
		"sabotage":
			return [] if t == 0 else ["recon"]
		"escort":
			return ["artillery", "recon", "airstrike"] if t == 0 else ["artillery"]
		"rescue":
			return ["artillery", "recon"] if t == 0 else ["recon"]
		"general":
			return ["recon", "artillery"] + LIGHT
	return FIRE

static func callin_ok(t: int, what: String) -> bool:
	return what in callins(t)

# the player's tool tabs outside commander mode
static func free_tools() -> bool:
	return G.mode == "sandbox"

static func mode_text(mode: String) -> String:
	var b = build(0, mode)
	var parts = []
	parts.append("Building: " + ("anything" if b.size() >= BASE.size() else ("none" if b.is_empty() else ", ".join(b.map(func(k): return Build.KINDS[k]["name"].to_lower())))))
	var c = callins(0, mode)
	parts.append("Call-ins: " + ("none" if c.is_empty() else ("all" if c.size() >= 14 else ", ".join(c.map(func(k): return Support.NAMES[k].split(" (")[0].to_lower())))))
	return " · ".join(parts)
