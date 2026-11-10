class_name Medical
extends RefCounted
# Bleeding and field dressings. Wounds keep bleeding until somebody puts a dressing on them:
# you can do your own (slow, and you have to stop), a buddy does it faster, and a medic fastest
# (and patches you up as well). Everyone carries a couple of dressings; medics carry more.

const SELF_T = 4.0
const BUDDY_T = 2.2
const MAX_BLEED = 3.0

# a hit that didn't kill: how much it bleeds
static func wound(s, dmg: float) -> void:
	if s.zombie or s == Modes.pilot:
		return
	s.bleed = minf(MAX_BLEED, s.bleed + dmg * 0.013)

# every tick for anyone not dead
static func tick(s) -> void:
	if s.bleed <= 0.0:
		return
	s.hp -= s.bleed * G.DT
	s.drip_t -= G.DT
	if s.drip_t <= 0.0:
		s.drip_t = randf_range(0.8, 1.6) / maxf(0.4, s.bleed)
		var p: Vector3 = s.parts[1].global_position
		G.fx.bleed(p, Vector3(0, -1, 0), false)
		if randf() < 0.3:
			G.fx.decal(Vector3(p.x, G.world.ground_y(p.x, p.z), p.z), randf_range(0.2, 0.4), false)
	if s.hp <= 0.0 and s.state != "dead":
		Combat.kill(s, s.last_attacker, false)

# a dressing is going on (whoever is putting it on)
static func bandage_tick(s) -> void:
	s.bandage_t -= G.DT
	s.want = Vector3.ZERO
	s.crouch_t = 0.8
	var w = s.bandage_who if s.bandage_who != null and is_instance_valid(s.bandage_who) else s
	if w != s and (w.state == "dead" or G.dist2d(w.pos, s.pos) > 2.2):
		s.bandage_t = 0.0
		s.bandage_who = null
		return
	s.hand_t = w.chest() if w != s else s.chest() + Vector3(0, -0.15, 0)
	if w != s:
		w.want = Vector3.ZERO
	if s.bandage_t <= 0.0:
		s.bandage_t = 0.0
		s.bandage_who = null
		s.hand_t = null
		s.dressings = maxi(0, s.dressings - 1)
		w.bleed = 0.0
		w.hp = minf(100.0, w.hp + (20.0 if s.cls == "medic" else 6.0))
		if w != s:
			G.fx.callout(w, G.pick(["Thanks.", "Cheers, mate.", "That'll hold."]))
		elif s.is_player:
			G.ui.message("Wound dressed (%d dressing%s left)" % [s.dressings, "" if s.dressings == 1 else "s"])

static func start(s, who, t: float) -> void:
	s.bandage_t = t * (0.5 if s.cls == "medic" else 1.0)
	s.bandage_who = who
	AI.stop_move(s)

# AI: stop to dress a wound when it's safe enough, or patch up a bleeding buddy close by
static func ai_tick(s) -> bool:
	if s.bandage_t > 0.0:
		bandage_tick(s)
		if s.supp > 1.1 and s.bandage_who == null:
			s.bandage_t = 0.0      # too hot to stay put: carry on bleeding
		return s.bandage_t > 0.0
	if s.dressings <= 0 or s.task == "patch" or s.task == "medic":
		return false
	var safe = s.vis_t == null and s.supp < 0.5
	if not safe and not (s.in_cover and s.supp < 0.9 and s.bleed > 1.0):
		return false
	# somebody close by bleeding worse than me?
	if s.state == "alive" and (s.think <= 0.05 or s.bleed > 0.0):
		for o in G.soldiers_near(s.pos):
			if o != s and o.team == s.team and o.state == "alive" and o.bleed > 0.25 and o.bandage_t <= 0.0 and o.bleed > s.bleed and G.dist2d(o.pos, s.pos) < 2.0:
				start(s, o, BUDDY_T)
				G.fx.callout(s, G.pick(["Hold still, I've got you.", "Let me get that.", "Pressure on it!"]))
				return true
	if s.bleed > 0.12:
		start(s, null, SELF_T)
		if randf() < 0.5:
			G.fx.callout(s, G.pick(["I'm bleeding, patching up!", "Hit! Dressing it!", "Need a second, I'm hit!"]))
		return true
	return false

# the player: H dresses a bleeding friend at your side, or your own wound
static func player_dress(s) -> void:
	if s.bandage_t > 0.0:
		return
	if s.dressings <= 0:
		G.ui.message("No field dressings left (a medic or an ammo crate has more)")
		return
	for o in G.soldiers_near(s.pos):
		if o != s and o.team == s.team and o.state != "dead" and o.bleed > 0.0 and G.dist2d(o.pos, s.pos) < 1.9:
			start(s, o, BUDDY_T)
			G.ui.message("Dressing %s's wound…" % o.sname)
			return
	if s.bleed <= 0.0:
		G.ui.message("You're not bleeding")
		return
	start(s, null, SELF_T)
	G.ui.message("Dressing your wound… (stay put)")
