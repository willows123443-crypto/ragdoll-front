class_name Prep
extends RefCounted
# Battle prep (campaign battles): a minute before the fighting starts. Nobody advances, no fire
# missions or air support, the objective can't be taken and the clock doesn't run; you place your
# men, build and dig in. Bravo digs in too. Space (or the button) starts the battle early.

const SECS = 60.0
static var t = 0.0
static var tick_t = 0.0
static var held = 0

static func reset() -> void:
	t = 0.0

static func active() -> bool:
	return t > 0.0

static func start(secs: float = SECS) -> void:
	t = secs
	tick_t = 0.0
	held = 0
	_hold_all()
	G.ui.radio(0, "Battle prep: %d seconds to place your men and dig in. Press Space to start now." % int(secs))

static func _hold_all() -> void:
	for s in G.soldiers:
		if s.state == "dead" or s.is_player or s.zombie:
			continue
		if s.order == null:
			s.order = {"mode": "hold", "point": s.pos, "prep": true}
			held += 1
	for v in G.vehicles:
		if v.dead or v.spec.get("air", false) or v.spec.get("static", false):
			continue
		if v.cmd == null and v.mission == null and v.driver() != null and not v.driver().is_player:
			v.cmd = v.pos
			v.set_meta("prep_hold", true)

static func step(dt: float) -> void:
	if t <= 0.0:
		return
	t -= dt
	tick_t -= dt
	if tick_t <= 0.0:
		tick_t = 1.0
		_hold_all()          # anyone who's just turned up waits too
	if t <= 0.0:
		finish()

static func finish() -> void:
	t = 0.0
	for s in G.soldiers:
		if s.order != null and s.order.get("prep", false):
			s.order = null
			s.decide_t = 0.0
	for v in G.vehicles:
		if v.has_meta("prep_hold"):
			v.remove_meta("prep_hold")
			if v.cmd != null and v.cmd.distance_to(v.pos) < 6.0:
				v.cmd = null
	G.ui.radio(0, "Prep's over. The battle begins!")
	G.ui.message("The battle begins!")
	G.audio.radio_click()

static func banner() -> String:
	if t <= 0.0:
		return ""
	return "BATTLE PREP  %d s  ·  place your men and dig in (Space: start now)" % int(ceil(t))
