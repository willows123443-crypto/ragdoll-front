class_name Keys
extends RefCounted
# Rebindable keys. The game's code is written against the default keys (W, S, A, D, Q, E...); this
# layer turns whatever key the player pressed into the default key for that action, and answers
# "is the key for this action held?" with the player's own binding. Bindings live in G.settings["keys"]
# as action -> keycode, and only the ones that differ from the default are stored.

const ACTIONS = [
	["forward", "Move forward / pan the map up", KEY_W],
	["back", "Move back / pan down", KEY_S],
	["left", "Move left / pan left", KEY_A],
	["right", "Move right / pan right", KEY_D],
	["lean_l", "Lean left / turn the map", KEY_Q],
	["lean_r", "Lean right / turn the map", KEY_E],
	["up", "Jump / camera up", KEY_SPACE],
	["reload", "Reload / turn a blueprint", KEY_R],
	["use", "Use, get in, take control", KEY_F],
	["grenade", "Throw a grenade", KEY_G],
	["smoke", "Throw smoke", KEY_V],
	["crouch", "Crouch", KEY_C],
	["prone", "Go prone", KEY_Z],
	["slowmo", "Slow motion", KEY_T],
	["pause", "Pause", KEY_P],
	["scores", "Tactical map", KEY_TAB],
	["menu", "Menu", KEY_M],
	["help", "Help / controls", KEY_H],
	["report", "Battle report", KEY_J],
	["nv", "Night vision", KEY_F2],
]

static func _custom() -> Dictionary:
	var c = G.settings.get("keys", {})
	return c if c is Dictionary else {}

static func bound(action: String) -> int:
	for a in ACTIONS:
		if a[0] == action:
			return int(_custom().get(action, a[2]))
	return 0

# the key the player actually presses for what the code calls `default_k`
static func phys(default_k: int) -> int:
	var c = _custom()
	if c.is_empty():
		return default_k
	for a in ACTIONS:
		if a[2] == default_k:
			return int(c.get(a[0], default_k))
	return default_k

static func held(default_k: int) -> bool:
	return Input.is_key_pressed(phys(default_k))

# what the code should treat a pressed key as
static func logical(k: int) -> int:
	var c = _custom()
	if c.is_empty():
		return k
	for a in ACTIONS:
		if int(c.get(a[0], a[2])) == k:
			return a[2]
	# the default key of an action that's been moved elsewhere now does nothing
	for a in ACTIONS:
		if a[2] == k:
			return KEY_NONE
	return k

static func set_key(action: String, k: int) -> void:
	var c = _custom().duplicate()
	var def = 0
	var old = bound(action)
	for a in ACTIONS:
		if a[0] == action:
			def = a[2]
	# a key can only do one thing: whatever had it takes this action's old key
	for a in ACTIONS:
		if a[0] != action and bound(a[0]) == k:
			if old == a[2]:
				c.erase(a[0])
			else:
				c[a[0]] = old
	if k == def:
		c.erase(action)
	else:
		c[action] = k
	G.settings["keys"] = c

static func reset() -> void:
	G.settings["keys"] = {}

static func name_of(k: int) -> String:
	return OS.get_keycode_string(k) if k != 0 else "—"
