class_name StuckLog
extends RefCounted
# A record of every time something gets stuck: where, what it was trying to do, and the likeliest reason.
# Kept in memory for the battle and appended to user://stuck_log.txt, so a night of test battles gives a
# list of causes sorted by how often they happen (see --stuckrun).

static var recs: Array = []
static var counts = {}
static var dump = false

# a picture of the ground round a stuck vehicle: # solid on the vehicle map, V the vehicle, > its nose,
# o other vehicles, m our men, * the path, x remembered bumps
static func _dump(v) -> void:
	var W = G.world
	var g: AStarGrid2D = W.tastar if v.spec["tracked"] else W.vastar
	var c0: Vector2i = W.vnav_cell(v.pos.x, v.pos.z)
	var marks = {}
	var f: Vector3 = v.forward()
	marks[W.vnav_cell(v.pos.x + f.x * 3.0, v.pos.z + f.z * 3.0)] = ">"
	for o in G.vehicles:
		if o != v:
			marks[W.vnav_cell(o.pos.x, o.pos.z)] = "o"
	for s in G.soldiers:
		if s.team == v.team and s.state == "alive" and s.vehicle == null:
			marks[W.vnav_cell(s.pos.x, s.pos.z)] = "m"
	for i in range(v.path_i, v.path.size()):
		marks[W.vnav_cell(v.path[i].x, v.path[i].z)] = "*"
	for bp in v.arc_bumps:
		marks[W.vnav_cell(bp[0].x, bp[0].z)] = "x"
	marks[c0] = "V"
	print("DUMP %s at (%.0f,%.0f) yaw=%.2f bumps=%d hold=%.1f pick=%s spd=%.1f\n  %s" % [v.kind, v.pos.x, v.pos.z, v.yaw, v.arc_bumps.size(), v.arc_hold, str(v.arc_pick), v.speed, str(v.get_meta("arc_dbg", "")) + "\n  trail " + " ".join(v.get_meta("trail", []))])
	for dz in range(-9, 10):
		var line = ""
		for dx in range(-14, 15):
			var q = Vector2i(c0.x + dx, c0.y + dz)
			if marks.has(q):
				line += marks[q]
			elif q.x < 0 or q.y < 0 or q.x >= g.region.size.x or q.y >= g.region.size.y:
				line += "~"
			else:
				line += "#" if g.is_point_solid(q) else "."
		print("  ", line)

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
	if v.tracks_broken or v.tyres >= 2 or v.fuel <= 0.0:
		return       # broken down or dry: not the driver's doing
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
	if dump:
		_dump(v)
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
	if dump:
		_dump_man(s, cause)
	_add("MAN", cause, s.pos, "%s T%d task=%s order=%s" % [s.cls, s.team, str(s.task), str(s.order.get("mode", "") if s.order != null else "-")])

# the ground round a stuck man on the walking map: # solid, + costly (low cover), S him, T where he's going,
# * his path, m other men, . open
static func _dump_man(s, cause: String) -> void:
	var W = G.world
	var lk = Levels.level_of(s.pos) if Levels.on else 0
	var marks = {}
	var cellf = func(p: Vector3) -> Vector2i:
		return Levels.cell(p.x, p.z) if lk > 0 else W.nav_cell(p.x, p.z)
	for o in G.soldiers_near(s.pos):
		if o != s and o.state == "alive" and absf(o.pos.y - s.pos.y) < 1.5:
			marks[cellf.call(o.pos)] = "m"
	for i in range(s.path_i, s.path.size()):
		marks[cellf.call(s.path[i])] = "*"
	if s.move_target != null:
		marks[cellf.call(s.move_target)] = "T"
	var c0: Vector2i = cellf.call(s.pos)
	marks[c0] = "S"
	var g: AStarGrid2D = Levels.grids[lk] if lk > 0 else W.astar
	var mt = s.move_target
	print("MANDUMP %s %s T%d at (%.1f,%.1f,%.1f) lv%d task=%s tgt=%s d=%.1f path=%d/%d partial=%s cover=%s in_cover=%s wedge=%d vel=%.1f want=%.1f slide=%.1f unstick=%.1f tgt_solid=%s here_solid=%s inside_any=%s" % [cause, s.cls, s.team, s.pos.x, s.pos.y, s.pos.z, lk, str(s.task),
		("(%.1f,%.1f,%.1f)" % [mt.x, mt.y, mt.z]) if mt != null else "-", G.dist2d(mt, s.pos) if mt != null else 0.0, s.path_i, s.path.size(), str(s.partial), str(s.cover != null), str(s.in_cover), s.wedge_n, s.vel.length(), s.want.length(), s.slide_t, s.unstick_t,
		str(g.is_point_solid(cellf.call(mt))) if mt != null else "-", str(g.is_point_solid(c0)), str(W.inside_any(s.pos.x, s.pos.z, 0.33, s.pos.y))])
	var rg = g.region
	for dz in range(-9, 10):
		var line = ""
		for dx in range(-16, 17):
			var q = Vector2i(c0.x + dx, c0.y + dz)
			if marks.has(q):
				line += marks[q]
			elif q.x < rg.position.x or q.y < rg.position.y or q.x >= rg.end.x or q.y >= rg.end.y:
				line += "~"
			elif g.is_point_solid(q):
				line += "#"
			else:
				line += "+" if g.get_point_weight_scale(q) > 1.5 else "."
		print("  ", line)

static func summary() -> String:
	var keys = counts.keys()
	keys.sort_custom(func(a, b): return counts[a] > counts[b])
	var out = []
	for k in keys:
		out.append("%s=%d" % [k, counts[k]])
	return " ".join(out)
