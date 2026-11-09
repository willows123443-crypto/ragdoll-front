extends Control
# Minimap (bottom right), a compass strip (when you control a soldier) and your squad's status.

var font: Font
const MS = 190.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font

func _process(_dt: float) -> void:
	visible = G.started and G.ui.visible and not G.ui.menu_open() and (G.ui.tacmap == null or not G.ui.tacmap.visible)
	if visible:
		queue_redraw()

func _draw() -> void:
	var vs = get_viewport_rect().size
	_minimap(Rect2(vs.x - MS - 12.0, vs.y - MS - 12.0, MS, MS))
	if G.player != null and is_instance_valid(G.player):
		_compass(Vector2(vs.x * 0.5, 128.0), G.pc.cam_yaw)
		_squad(Vector2(16.0, 280.0), G.player)

# ---------------------------------------------------------------- minimap: 160 m around you (or the camera)
func _minimap(r: Rect2) -> void:
	var cam = G.pc.cam
	var c: Vector3 = G.player.pos if G.player != null and is_instance_valid(G.player) else cam.global_position
	var yaw: float = G.pc.cam_yaw if G.player != null else G.pc.free_yaw
	var span = 160.0
	var k = r.size.x / span
	var mid = r.get_center()
	draw_rect(r, Color(0.16, 0.19, 0.13, 0.82))
	var sy = sin(yaw)
	var cy = cos(yaw)
	# map "up" is the way you're facing
	var rot = func(p: Vector3) -> Vector2:
		var dx = p.x - c.x
		var dz = p.z - c.z
		return mid + Vector2(-dx * cy + dz * sy, -(dx * sy + dz * cy)) * k
	for w in G.world.water:
		var pts = PackedVector2Array([rot.call(Vector3(w[0], 0, w[2])), rot.call(Vector3(w[1], 0, w[2])), rot.call(Vector3(w[1], 0, w[3])), rot.call(Vector3(w[0], 0, w[3]))])
		_poly_clip(pts, r, Color(0.25, 0.4, 0.55, 0.9))
	for rd in G.world.roads:
		var pts2 = PackedVector2Array([rot.call(Vector3(rd[0], 0, rd[2])), rot.call(Vector3(rd[1], 0, rd[2])), rot.call(Vector3(rd[1], 0, rd[3])), rot.call(Vector3(rd[0], 0, rd[3]))])
		_poly_clip(pts2, r, Color(0.45, 0.42, 0.36, 0.9))
	for b in G.world.buildings:
		if absf(b["x"] - c.x) > span or absf(b["z"] - c.z) > span:
			continue
		var hw = b["w"] / 2.0
		var hd = b["d"] / 2.0
		var pts3 = PackedVector2Array([rot.call(Vector3(b["x"] - hw, 0, b["z"] - hd)), rot.call(Vector3(b["x"] + hw, 0, b["z"] - hd)), rot.call(Vector3(b["x"] + hw, 0, b["z"] + hd)), rot.call(Vector3(b["x"] - hw, 0, b["z"] + hd))])
		_poly_clip(pts3, r, Color(0.1, 0.1, 0.09, 0.9))
	for pt in Obj.points:
		var p = rot.call(pt["p"])
		if r.has_point(p):
			var col = G.team_color(pt["owner"]) if pt["owner"] >= 0 else Color(0.9, 0.9, 0.9)
			draw_arc(p, 10.0 * k + 3.0, 0, TAU, 16, col, 2.0)
			draw_string(font, p + Vector2(-4, 5), pt["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
	var my_team = G.player.team if G.player != null and is_instance_valid(G.player) else 0
	for st in Build.sites:
		if st["dead"] or (st["team"] != my_team and st["kind"] != "hq"):
			continue
		var p2 = rot.call(st["p"])
		if r.has_point(p2):
			draw_rect(Rect2(p2 - Vector2(3, 3), Vector2(6, 6)), G.team_color(st["team"]))
	for v in G.vehicles:
		if v.dead:
			continue
		var p3 = rot.call(v.pos)
		if r.has_point(p3) and (v.team == my_team or _seen(v.pos, my_team)):
			draw_rect(Rect2(p3 - Vector2(4, 4), Vector2(8, 8)), G.team_color(v.team), false, 2.0)
	for s in G.soldiers:
		if s.state == "dead" or s.state == "riding":
			continue
		var p4 = rot.call(s.pos)
		if not r.has_point(p4):
			continue
		if s.team == my_team:
			var same_squad = G.player != null and is_instance_valid(G.player) and s.squad == G.player.squad
			draw_circle(p4, 2.6 if same_squad else 1.8, Color(0.6, 1.0, 0.6) if same_squad else G.team_color(s.team).lightened(0.35))
		elif _seen(s.pos, my_team):
			draw_circle(p4, 2.4, Color(1.0, 0.3, 0.25))
	# you, at the centre, pointing up
	draw_colored_polygon(PackedVector2Array([mid + Vector2(0, -6), mid + Vector2(4, 4), mid + Vector2(-4, 4)]), Color(1, 1, 1))
	draw_rect(r, Color(0, 0, 0, 0.9), false, 2.0)
	draw_string(font, r.position + Vector2(4, 13), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.0))

func _poly_clip(pts: PackedVector2Array, r: Rect2, col: Color) -> void:
	var clip = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	for poly in Geometry2D.intersect_polygons(pts, clip):
		if poly.size() >= 3:
			draw_colored_polygon(poly, col)

func _seen(p: Vector3, team: int) -> bool:
	for s in G.soldiers:
		if s.team == team and s.state != "dead":
			for e in s.intel.values():
				if e["seen"] and G.sim_time - e["t"] < 6.0 and e["p"].distance_to(p) < 4.0:
					return true
	return false

# ---------------------------------------------------------------- compass strip
func _compass(c: Vector2, yaw: float) -> void:
	var w = 380.0
	var r = Rect2(c.x - w / 2.0, c.y, w, 24.0)
	draw_rect(r, Color(0, 0, 0, 0.45))
	var heading = fposmod(rad_to_deg(atan2(sin(yaw), cos(yaw))), 360.0)
	# yaw 0 faces +z; call +z north... the map's "up" is -z, so north = 180 here
	var labels = {0: "S", 45: "SW", 90: "W", 135: "NW", 180: "N", 225: "NE", 270: "E", 315: "SE"}
	for d in range(0, 360, 15):
		var off = wrapf(float(d) - heading, -180.0, 180.0)
		if absf(off) > 60.0:
			continue
		var x = c.x - off / 60.0 * (w / 2.0)
		var major = labels.has(d)
		draw_line(Vector2(x, r.position.y + (2 if major else 10)), Vector2(x, r.end.y - 2), Color(1, 1, 1, 0.8 if major else 0.4), 1.5 if major else 1.0)
		if major:
			draw_string(font, Vector2(x - 6, r.end.y + 13), labels[d], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1))
	# flag markers along the strip
	if G.player != null:
		for pt in Obj.points:
			var to = pt["p"] - G.player.pos
			var b = fposmod(rad_to_deg(atan2(to.x, to.z)), 360.0)
			var off2 = wrapf(b - heading, -180.0, 180.0)
			if absf(off2) <= 60.0:
				var x2 = c.x - off2 / 60.0 * (w / 2.0)
				var col = G.team_color(pt["owner"]) if pt["owner"] >= 0 else Color(0.9, 0.9, 0.9)
				draw_string(font, Vector2(x2 - 4, r.position.y - 3), pt["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
	draw_colored_polygon(PackedVector2Array([Vector2(c.x, r.end.y - 2), Vector2(c.x - 5, r.end.y + 5), Vector2(c.x + 5, r.end.y + 5)]), Color(1, 0.85, 0.3))

# ---------------------------------------------------------------- squad status
func _squad(at: Vector2, me) -> void:
	var q = me.squad
	if q == null:
		return
	var n = 0
	for m in q["members"]:
		if is_instance_valid(m):
			n += 1
	draw_rect(Rect2(at.x - 6, at.y - 16, 300, 26 + n * 17), Color(0, 0, 0, 0.45))
	draw_string(font, at, "SQUAD %d" % (q["id"] + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.9))
	var y = at.y + 8.0
	for m in q["members"]:
		if not is_instance_valid(m):
			continue
		var col = Color(0.75, 0.95, 0.7)
		var st = ""
		match m.state:
			"dead":
				col = Color(0.5, 0.5, 0.5)
				st = "KIA"
			"wounded":
				col = Color(1.0, 0.45, 0.35)
				st = "WOUNDED"
			"down", "getup":
				col = Color(1.0, 0.8, 0.4)
				st = "down"
			"riding":
				st = "in vehicle"
		if m.state == "alive":
			if m.broken:
				st = "shaken"
				col = Color(1.0, 0.75, 0.4)
			elif m.ammo_frac() < 0.25:
				st = "low ammo"
			elif m.reload_t > 0.0:
				st = "reloading"
			elif m.task == "construct":
				st = "building"
		var name_ = m.sname + (" (you)" if m == me else "") + (" ★" + "★".repeat(m.vet - 1) if m.vet > 0 else "")
		draw_rect(Rect2(at.x, y, 6, 14), G.team_color(m.team))
		draw_string(font, Vector2(at.x + 10, y + 12), name_, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
		# health bar
		var hpw = 60.0
		draw_rect(Rect2(at.x + 150, y + 4, hpw, 6), Color(0, 0, 0, 0.6))
		if m.state != "dead":
			draw_rect(Rect2(at.x + 150, y + 4, hpw * clampf(m.hp / 100.0, 0.0, 1.0), 6), col)
		if st != "":
			draw_string(font, Vector2(at.x + 216, y + 12), st, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)
		y += 17.0
