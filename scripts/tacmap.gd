extends Control
# The commander's map (Tab): a top-down view of the whole battlefield with flags, buildings,
# structures, vehicles, your squads and the enemies your side knows about. Click a squad to
# select it, right-click to send it somewhere (Shift + right-click: hold where they are).

var sel = null          # selected squad
var view: Rect2         # where the map is drawn on screen
var font: Font

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	font = ThemeDB.fallback_font

func toggle() -> void:
	visible = not visible
	if visible:
		sel = null
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	queue_redraw()

func _process(_dt: float) -> void:
	if visible:
		queue_redraw()

func _to_screen(p: Vector3) -> Vector2:
	var b: Rect2 = G.world.bounds
	return view.position + Vector2((p.x - b.position.x) / b.size.x * view.size.x, (p.z - b.position.y) / b.size.y * view.size.y)

func _to_world(v: Vector2) -> Vector3:
	var b: Rect2 = G.world.bounds
	var x = b.position.x + (v.x - view.position.x) / view.size.x * b.size.x
	var z = b.position.y + (v.y - view.position.y) / view.size.y * b.size.y
	return Vector3(x, G.world.ground_y(x, z), z)

func _wr(x0: float, z0: float, x1: float, z1: float) -> Rect2:
	var a = _to_screen(Vector3(x0, 0, z0))
	var c = _to_screen(Vector3(x1, 0, z1))
	return Rect2(a, c - a).abs()

func _draw() -> void:
	if not G.started:
		return
	var vs = get_viewport_rect().size
	var b: Rect2 = G.world.bounds
	var k = minf((vs.x - 80.0) / b.size.x, (vs.y - 140.0) / b.size.y)
	var sz = b.size * k
	view = Rect2((vs - sz) * 0.5 + Vector2(0, 20), sz)
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.55))
	draw_rect(view, Color(0.36, 0.4, 0.27))
	draw_rect(view, Color(0.1, 0.1, 0.1), false, 2.0)
	# grid squares like the radio uses
	for i in range(1, 8):
		var x = view.position.x + view.size.x * i / 8.0
		draw_line(Vector2(x, view.position.y), Vector2(x, view.end.y), Color(0, 0, 0, 0.12))
		var y = view.position.y + view.size.y * i / 8.0
		draw_line(Vector2(view.position.x, y), Vector2(view.end.x, y), Color(0, 0, 0, 0.12))
	for w in G.world.water:
		draw_rect(_wr(w[0], w[2], w[1], w[3]).intersection(view), Color(0.25, 0.4, 0.55))
	for rd in G.world.roads:
		draw_rect(_wr(rd[0], rd[2], rd[1], rd[3]).intersection(view), Color(0.5, 0.47, 0.4))
	for br in G.world.bridges:
		if br[5].alive:
			draw_rect(_wr(br[0], br[2], br[1], br[3]), Color(0.55, 0.45, 0.32))
	for bl in G.world.buildings:
		draw_rect(_wr(bl["x"] - bl["w"] / 2.0, bl["z"] - bl["d"] / 2.0, bl["x"] + bl["w"] / 2.0, bl["z"] + bl["d"] / 2.0), Color(0.22, 0.2, 0.18))
	# flags
	for pt in Obj.points:
		var c = G.team_color(pt["owner"]) if pt["owner"] >= 0 else Color(0.9, 0.9, 0.9)
		var sp = _to_screen(pt["p"])
		draw_arc(sp, 10.0 * k * 1.0 + 6.0, 0, TAU, 24, c, 2.0)
		draw_string(font, sp + Vector2(-5, 5), pt["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, c)
	# structures: ours always, the enemy's only if someone's seen them
	for st in Build.sites:
		if st["dead"]:
			continue
		if st["team"] != 0 and not _known_site(st):
			continue
		var r = Rect2(_to_screen(st["p"]) - Vector2(5, 5), Vector2(10, 10))
		var c2 = G.team_color(st["team"])
		draw_rect(r, c2 if st["done"] else Color(c2, 0.4))
		draw_rect(r, Color(0, 0, 0), false, 1.0)
		if st["kind"] in ["hq", "fob", "fob2", "depot"]:
			draw_string(font, r.position + Vector2(12, 10), st["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.85))
	# vehicles
	for v in G.vehicles:
		if v.dead or (v.team != 0 and not _known_pos(v.pos)):
			continue
		var p = _to_screen(v.pos)
		var f = Vector2(sin(v.yaw), cos(v.yaw))
		var pts = PackedVector2Array([p + f * 8.0, p + Vector2(-f.y, f.x) * 5.0 - f * 5.0, p - Vector2(-f.y, f.x) * 5.0 - f * 5.0])
		_poly(pts, G.team_color(v.team))
	# soldiers: ours as dots, squad leaders labelled
	for s in G.soldiers:
		if s.state == "dead" or s.state == "riding":
			continue
		if s.team == 0:
			draw_circle(_to_screen(s.pos), 2.5, G.team_color(0).lightened(0.3))
		elif s.team != 0 and _known_pos(s.pos):
			var e = _to_screen(s.pos)
			draw_line(e - Vector2(3, 3), e + Vector2(3, 3), G.team_color(s.team), 2.0)
			draw_line(e - Vector2(3, -3), e + Vector2(3, -3), G.team_color(s.team), 2.0)
	for q in G.squads:
		if q["team"] != 0:
			continue
		var L = Squad.leader_of(q)
		if L == null or not is_instance_valid(L):
			continue
		var p2 = _to_screen(L.pos)
		var on = q == sel
		draw_circle(p2, 7.0 if on else 5.5, Color(1, 0.85, 0.3) if on else G.team_color(0))
		draw_string(font, p2 + Vector2(8, -6), "Sq %d" % (q["id"] + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1))
		var o = L.order
		if o != null and o.get("point") != null:
			draw_dashed_line(p2, _to_screen(o["point"]), Color(1, 0.85, 0.3, 0.7), 1.5, 6.0)
	if G.player != null and is_instance_valid(G.player):
		draw_arc(_to_screen(G.player.pos), 6.0, 0, TAU, 16, Color(1, 1, 1), 2.0)
	draw_string(font, Vector2(view.position.x, view.position.y - 10), "COMMANDER'S MAP  ·  click a squad to select it  ·  right-click: move there  ·  Shift+right-click: hold where they are  ·  Tab to close", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1))

func _known_pos(p: Vector3) -> bool:
	for s in G.soldiers:
		if s.team == 0 and s.state != "dead":
			for e in s.intel.values():
				if G.sim_time - e["t"] < 20.0 and e["p"].distance_to(p) < 6.0:
					return true
	return false

func _known_site(st: Dictionary) -> bool:
	if st["kind"] == "hq":
		return true
	for s in G.soldiers:
		if s.team == 0 and s.state == "alive" and G.dist2d(s.pos, st["p"]) < 80.0:
			return true
	return false

func _gui_input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton) or not ev.pressed:
		return
	if ev.button_index == MOUSE_BUTTON_LEFT:
		sel = null
		var bd = 14.0
		for q in G.squads:
			if q["team"] != 0:
				continue
			var L = Squad.leader_of(q)
			if L != null and is_instance_valid(L):
				var d = _to_screen(L.pos).distance_to(ev.position)
				if d < bd:
					bd = d
					sel = q
		accept_event()
	elif ev.button_index == MOUSE_BUTTON_RIGHT and sel != null and view.has_point(ev.position):
		var p = _to_world(ev.position)
		var hold = Input.is_key_pressed(KEY_SHIFT)
		for m in sel["members"]:
			if is_instance_valid(m) and m.state != "dead" and not m.is_player:
				m.order = {"mode": "hold", "point": m.pos} if hold else {"mode": "move", "point": p}
				m.decide_t = 0.0
		G.fx.order_marker(p)
		G.ui.message("Squad %d: %s" % [sel["id"] + 1, "hold your position" if hold else "move to " + AI.grid_ref(p)])
		accept_event()

# A polygon that can't be cut into triangles (its corners in a line, or not numbers at all: the map is asked
# to draw before it has a size) is an error in the browser's console every time. Those are skipped.
func _poly(pts: PackedVector2Array, col: Color) -> void:
	if pts.size() >= 3 and not Geometry2D.triangulate_polygon(pts).is_empty():
		draw_colored_polygon(pts, col)
