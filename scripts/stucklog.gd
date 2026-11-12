class_name StuckLog
extends RefCounted
# A record of every time something gets stuck: where, what it was trying to do, and the likeliest reason.
# Kept in memory for the battle and appended to user://stuck_log.txt, so a night of test battles gives a
# list of causes sorted by how often they happen (see --stuckrun).

static var recs: Array = []
static var counts = {}

static func reset() -> void:
	recs = []
	counts = {}

static func _add(kind: String, cause: String, p: Vector3, detail: String) -> void:
	var key = kind + ":" + cause
	counts[key] = counts.get(key, 0) + 1
	var line = "%s t%d %s %s (%.0f,%.0f) %s/%s %s" % [Time.get_datetime_string_from_system(), int(G.sim_time), kind, cause, p.x, p.z, G.map_id, G.mode, detail]
	recs.append(line)
	if recs.size() > 400:
		recs.pop_front()
	if OS.has_feature("web"):
		return
	var f = FileAccess.open("user://stuck_log.txt", FileAccess.READ_WRITE if FileAccess.file_exists("user://stuck_log.txt") else FileAccess.WRITE)
	if f != null:
		f.seek_end()
		f.store_line(line)
		f.close()

# a vehicle that meant to go somewhere and hasn't moved for ten seconds
static func vehicle(v) -> void:
	var f: Vector3 = v.forward()
	var cause = "open"
	var W = G.world
	var b: Rect2 = W.bounds
	var nose = v.pos + f * (v.spec["len"] * 0.5 + 1.5)
	if not b.grow(-2.0).has_point(Vector2(v.pos.x, v.pos.z)):
		cause = "map_edge"
	for o in G.vehicles:
		if o != v and G.dist2d(o.pos, v.pos) < (v.spec["len"] + o.spec["len"]) * 0.5 + 2.5:
			cause = "wreck" if o.dead else ("friend_vehicle" if o.team == v.team else "enemy_vehicle")
			break
	if cause == "open":
		for s in G.soldiers:
			if s.state == "alive" and s.vehicle == null and s.team == v.team and G.dist2d(s.pos, nose) < 3.0:
				cause = "own_men_in_front"
				break
	if cause == "open" and (W.inside_any(nose.x, nose.z, 1.0) or W.inside_any(v.pos.x, v.pos.z, 1.2)):
		cause = "wall_or_object"
	if cause == "open" and W.in_water(nose.x, nose.z):
		cause = "water"
	if cause == "open" and absf(W.ground_y(nose.x, nose.z) - W.ground_y(v.pos.x, v.pos.z)) > 1.2:
		cause = "steep_ground"
	if cause == "open" and v.fuel <= 0.0:
		cause = "no_fuel"
	if cause == "open" and (v.tracks_broken or v.tyres >= 2):
		cause = "broken_down"
	var to = G.flat(v.goal - v.pos)
	_add("VEH", cause, v.pos, "%s T%d why=%s mission=%s goal_d=%.0f goal_ang=%.1f pick=%s block=%.1f spd=%.1f path=%d/%d grid_solid=%s" % [v.kind, v.team, v.why, str(v.mission.get("type", "") if v.mission != null else "-"), G.dist2d(v.goal, v.pos),
		wrapf(atan2(to.x, to.z) - v.yaw, -PI, PI), str(v.arc_pick), v.arc_block, v.speed, v.path_i, v.path.size(), str(W.vastar.is_point_solid(W.vnav_cell(v.pos.x, v.pos.z)))])

# a soldier who's been blocked on the same walk three times running
static func soldier(s) -> void:
	var cause = "open"
	var W = G.world
	var near = 0
	for o in G.soldiers_near(s.pos):
		if o != s and o.state == "alive" and G.dist2d(o.pos, s.pos) < 1.4 and absf(o.pos.y - s.pos.y) < 1.5:
			near += 1
	if near >= 2:
		cause = "crowd"
	elif W.inside_any(s.pos.x, s.pos.z, 0.5, s.pos.y):
		cause = "against_wall"
	elif Levels.on and Levels.inside(s.pos, 0.5):
		cause = "indoors_floor%d" % Levels.level_of(s.pos)
	elif W.building_index(s.pos, 0.5) >= 0:
		cause = "inside_building"
	else:
		for v in G.vehicles:
			if G.dist2d(v.pos, s.pos) < v.spec["len"] * 0.5 + 1.5:
				cause = "against_vehicle"
				break
	_add("MAN", cause, s.pos, "%s T%d task=%s order=%s" % [s.cls, s.team, str(s.task), str(s.order.get("mode", "") if s.order != null else "-")])

static func summary() -> String:
	var keys = counts.keys()
	keys.sort_custom(func(a, b): return counts[a] > counts[b])
	var out = []
	for k in keys:
		out.append("%s=%d" % [k, counts[k]])
	return " ".join(out)
