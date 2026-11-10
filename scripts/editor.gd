extends CanvasLayer
# Map editor: sculpt the ground, place buildings, cover and props, set spawns and control points,
# save maps (kept in the browser's storage) and play them.

var active = false
var data: Dictionary = {}
var tool = "house"
var rot = 0
var brush = 7.0
var nodes: Array = []            # one Node3D per item, same order as data["items"]
var markers: Node3D = null
var cursor: MeshInstance3D = null
var painting = false
var paint_t = 0.0
var drag_a = null                # start of a road or trench drag
var dirty_terrain = false
var root: Control
var name_edit: LineEdit
var mode_opt: OptionButton
var load_box: VBoxContainer
var status: Label
var tool_buttons = {}
var armies_opt: OptionButton
var sel = null                    # selected unit or trigger (a dictionary in data)
var sel_kind = ""                 # "unit" or "trigger"
var wp_mode = false               # clicks add waypoints to the selected unit
var spot_mode = false             # the next click sets the selected trigger's action spot
var insp: PanelContainer = null   # inspector for the selection
var insp_box: VBoxContainer
var veh_pick = "jeep"
var paint_t2 = 0.0

const TOOLS = [
	["Ground", [["raise", "Raise"], ["lower", "Lower"], ["flatten", "Flatten"], ["smooth", "Smooth"], ["crater", "Crater"]]],
	["Buildings", [["house", "House"], ["tower", "Two-storey"], ["wall", "Wall"]]],
	["Cover", [["sandbags", "Sandbags"], ["crate", "Crate"], ["hedge", "Hedge"], ["hedgehog", "Tank trap"], ["trench", "Trench (drag)"]]],
	["Props", [["tree", "Tree"], ["deadtree", "Dead tree"], ["tankwreck", "Tank wreck"], ["truckwreck", "Truck wreck"], ["ammo", "Ammo crate"], ["road", "Road (drag)"]]],
	["Markers", [["spawnA", "Alpha spawn"], ["spawnB", "Bravo spawn"], ["point", "Control point"]]],
	["Paint the ground", [["paint:1", "Grass"], ["paint:2", "Dry grass"], ["paint:3", "Dirt"], ["paint:4", "Mud"], ["paint:5", "Sand"],
		["paint:6", "Rock"], ["paint:7", "Snow"], ["paint:8", "Scorched"], ["paint:9", "Tarmac"], ["paint:0", "Unpaint"]]],
	["Units and scripting", [["squadA", "Alpha squad"], ["squadB", "Bravo squad"], ["vehA", "Alpha vehicle"], ["vehB", "Bravo vehicle"],
		["trigger", "Trigger"], ["sel", "Select / orders"]]],
	["", [["erase", "Erase"]]],
]
const TIPS = {
	"raise": "Hold the left button to raise the ground ([ ] change brush size)", "lower": "Hold to dig the ground down",
	"flatten": "Hold to level the ground to where you first clicked", "smooth": "Hold to smooth bumps",
	"crater": "Click to blow a shell crater", "trench": "Drag to dig a trench with duckboards",
	"road": "Drag a rectangle to lay a flat road", "erase": "Click an object or marker to remove it",
	"point": "Click to add a control point (frontline mode takes them in order from west to east)",
	"squadA": "Click to place an Alpha squad, then give it orders on the right", "squadB": "Click to place a Bravo squad, then give it orders on the right",
	"vehA": "Click to place an Alpha vehicle (pick the type on the right)", "vehB": "Click to place a Bravo vehicle (pick the type on the right)",
	"trigger": "Click to place a trigger area, then set what sets it off and what happens",
	"sel": "Click a unit or trigger to edit it",
}

func _ready() -> void:
	layer = 5
	G.editor = self
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = G.ui._theme()
	add_child(root)
	visible = false
	G.ui.refresh_maps()

func typing() -> bool:
	if not active or root == null:
		return false
	var f = root.get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is SpinBox

# ---------------------------------------------------------------- opening / closing
func new_map(size: Vector2) -> void:
	var h = PackedFloat32Array()
	h.resize((int(size.x) + 1) * (int(size.y) + 1))
	h.fill(0.0)
	data = {"name": "My map", "size": size, "ground": Color(0.46, 0.45, 0.35), "heights": h, "items": [],
		"spawns": [Vector3(-size.x / 2.0 + 30.0, 0, 0), Vector3(size.x / 2.0 - 30.0, 0, 0)], "points": [Vector3.ZERO],
		"units": [], "triggers": [], "paint": PackedByteArray()}
	_open()

func _open() -> void:
	for k in ["units", "triggers"]:
		if not data.has(k):
			data[k] = []
	if not data.has("paint"):
		data["paint"] = PackedByteArray()
	sel = null
	wp_mode = false
	spot_mode = false
	active = true
	G.started = false
	G.main._clear()
	G.ui.menu.visible = false
	G.ui.root.visible = false
	visible = true
	G.world.begin_edit(data)
	_rebuild_items()
	_build_ui()
	G.pc.free_pos = Vector3(data["spawns"][0].x + 20.0, 40.0, 30.0)
	G.pc.free_yaw = PI / 2.0 + 0.6
	G.pc.free_pitch = -0.6
	if cursor == null:
		cursor = MeshInstance3D.new()
		var tm = TorusMesh.new()
		tm.inner_radius = 0.95
		tm.outer_radius = 1.0
		cursor.mesh = tm
		var m = StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.85, 0.25)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.no_depth_test = true
		cursor.material_override = m
		G.main.add_child(cursor)
	cursor.visible = true

func close() -> void:
	active = false
	visible = false
	G.ui.root.visible = true
	if cursor:
		cursor.visible = false
	if markers:
		markers.queue_free()
		markers = null
	G.main.preview_map("town")
	G.ui.show_menu()

# ---------------------------------------------------------------- building what's in the data
func _rebuild_items() -> void:
	for n in nodes:
		if is_instance_valid(n):
			n.queue_free()
	nodes = []
	for it in data["items"]:
		nodes.append(_make_item_node(it))
	_rebuild_markers()

func _make_item_node(it: Dictionary) -> Node3D:
	var n = Node3D.new()
	G.world.geo_root.add_child(n)
	G.world.edit_node = n
	G.world.build_item(it)
	G.world.edit_node = null
	return n

func _rebuild_markers() -> void:
	if markers:
		markers.queue_free()
	markers = Node3D.new()
	G.main.add_child(markers)
	for t in range(2):
		_marker(data["spawns"][t], G.team_color(t), 1.2)
	for p in data["points"]:
		_marker(p, Color(0.9, 0.9, 0.9), 9.0)
	for u in data["units"]:
		var col = G.team_color(u["team"])
		var g = _post(Vector3(u["x"], 0, u["z"]), col, 2.2 if u["kind"] == "squad" else 1.4, Scripted.describe_unit(u), u == sel)
		if u["kind"] == "vehicle":
			var b = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = Vector3(2.2, 1.2, 4.2) if u.get("rot", 0) == 1 else Vector3(4.2, 1.2, 2.2)
			b.mesh = bm
			b.material_override = _flat_mat(col.darkened(0.3))
			b.position.y = 0.6
			g.add_child(b)
		var prev = Vector3(u["x"], 0, u["z"])
		var k = 1
		for w in u.get("wp", []):
			_post(w, col.lightened(0.3), 0.6, str(k), false)
			_line(prev, w, col)
			prev = w
			k += 1
	for tr in data["triggers"]:
		var c = Vector3(tr["x"], 0, tr["z"])
		var tc = Color(1.0, 0.6, 0.15) if tr != sel else Color(1.0, 0.95, 0.3)
		if tr.get("when", "") in ["enter", "clear"]:
			_marker(c, tc, tr.get("r", 12.0))
		_post(c, tc, 1.2, Scripted.describe_trigger(tr), tr == sel)
		if tr.has("ax"):
			var a = Vector3(tr["ax"], 0, tr["az"])
			_post(a, Color(1.0, 0.3, 0.2), 0.8, "action spot", false)
			_line(c, a, tc)

func _marker(p: Vector3, col: Color, r: float) -> void:
	var g = Node3D.new()
	var pole = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(0.12, 4.0, 0.12)
	pole.mesh = bm
	pole.position.y = 2.0
	g.add_child(pole)
	var flag = MeshInstance3D.new()
	var fm = BoxMesh.new()
	fm.size = Vector3(1.2, 0.7, 0.04)
	flag.mesh = fm
	var m = StandardMaterial3D.new()
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flag.material_override = m
	flag.position = Vector3(0.62, 3.6, 0)
	g.add_child(flag)
	var ring = MeshInstance3D.new()
	var tm = TorusMesh.new()
	tm.inner_radius = r - 0.25
	tm.outer_radius = r
	ring.mesh = tm
	ring.material_override = m
	ring.scale = Vector3(1, 0.05, 1)
	g.add_child(ring)
	markers.add_child(g)
	g.global_position = Vector3(p.x, G.world.ground_y(p.x, p.z) + 0.05, p.z)

static var flat_mats = {}
func _flat_mat(col: Color) -> StandardMaterial3D:
	var k = col.to_html()
	if not flat_mats.has(k):
		var m = StandardMaterial3D.new()
		m.albedo_color = col
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flat_mats[k] = m
	return flat_mats[k]

# a marker post with a label floating over it
func _post(p: Vector3, col: Color, h: float, text: String, hilite: bool) -> Node3D:
	var g = Node3D.new()
	var pole = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(0.35, h, 0.35)
	pole.mesh = bm
	pole.position.y = h / 2.0
	pole.material_override = _flat_mat(col if not hilite else Color(1, 1, 0.4))
	g.add_child(pole)
	if text != "":
		var l = Label3D.new()
		l.text = text
		l.font_size = 26
		l.fixed_size = true
		l.pixel_size = 0.00085
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.outline_size = 10
		l.modulate = Color(1, 1, 0.6) if hilite else Color.WHITE
		l.position.y = h + 0.8
		g.add_child(l)
	markers.add_child(g)
	g.global_position = Vector3(p.x, G.world.ground_y(p.x, p.z) + 0.05, p.z)
	return g

func _line(a: Vector3, b: Vector3, col: Color) -> void:
	var n = maxi(1, int(G.dist2d(a, b) / 3.0))
	for k in range(1, n):
		var p = a.lerp(b, float(k) / n)
		var d = MeshInstance3D.new()
		var sm = BoxMesh.new()
		sm.size = Vector3(0.3, 0.12, 0.3)
		d.mesh = sm
		d.material_override = _flat_mat(col)
		markers.add_child(d)
		d.global_position = Vector3(p.x, G.world.ground_y(p.x, p.z) + 0.15, p.z)

# ---------------------------------------------------------------- input
func _ground_at(screen: Vector2):
	var cam: Camera3D = G.pc.cam
	var o = cam.project_ray_origin(screen)
	var d = cam.project_ray_normal(screen)
	var hit = G.ray(o, o + d * 900.0, G.L_WORLD)
	if hit.is_empty():
		return null
	return hit.position

func handle(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var p = _ground_at(ev.position)
		if p != null and cursor:
			cursor.global_position = p + Vector3(0, 0.15, 0)
			var r = brush if (tool in ["raise", "lower", "flatten", "smooth", "crater"] or tool.begins_with("paint:")) else 2.0
			cursor.scale = Vector3(r, 1.0, r)
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		var p = _ground_at(ev.position)
		if ev.pressed:
			if p == null:
				return
			if tool in ["raise", "lower", "flatten", "smooth"] or tool.begins_with("paint:"):
				painting = true
				flatten_h = G.world.ground_y(p.x, p.z)
				if tool.begins_with("paint:"):
					_paint(p)
			elif tool in ["road", "trench"]:
				drag_a = p
			else:
				_click(p)
		else:
			if painting:
				painting = false
				if tool.begins_with("paint:"):
					G.world.build_terrain(data["ground"])
				else:
					_terrain_changed()
			if drag_a != null and p != null:
				_drag_done(drag_a, p)
			drag_a = null
	elif ev is InputEventKey and ev.pressed and not ev.echo and not typing():
		match ev.keycode:
			KEY_R:
				rot = 1 - rot
				_status("Rotation: " + ("east–west" if rot == 0 else "north–south"))
			KEY_BRACKETLEFT:
				brush = maxf(2.0, brush - 1.0)
				_status("Brush %d m" % int(brush))
			KEY_BRACKETRIGHT:
				brush = minf(25.0, brush + 1.0)
				_status("Brush %d m" % int(brush))
			KEY_ESCAPE:
				close()

var flatten_h = 0.0

func _process(dt: float) -> void:
	if not active or not painting:
		return
	paint_t -= dt
	var p = _ground_at(get_viewport().get_mouse_position())
	if p == null:
		return
	if tool.begins_with("paint:"):
		_paint(p)
	else:
		_brush(p, dt)
	if paint_t <= 0.0:
		paint_t = 0.25
		G.world.build_terrain(data["ground"])

func _brush(p: Vector3, dt: float) -> void:
	var w = G.world
	var r = brush
	var th: PackedFloat32Array = w.th
	var W = w.TW + 1
	var x0 = maxi(0, int(floor(p.x - r - w.TX0)))
	var x1 = mini(w.TW, int(ceil(p.x + r - w.TX0)))
	var z0 = maxi(0, int(floor(p.z - r - w.TZ0)))
	var z1 = mini(w.TH_, int(ceil(p.z + r - w.TZ0)))
	for iz in range(z0, z1 + 1):
		for ix in range(x0, x1 + 1):
			var vx = w.TX0 + ix
			var vz = w.TZ0 + iz
			var d = Vector2(vx - p.x, vz - p.z).length()
			if d > r:
				continue
			var k = 0.5 * (1.0 + cos(PI * d / r))
			var i = iz * W + ix
			match tool:
				"raise":
					th[i] = minf(25.0, th[i] + 3.0 * k * dt)
				"lower":
					th[i] = maxf(-6.0, th[i] - 3.0 * k * dt)
				"flatten":
					th[i] = lerpf(th[i], flatten_h, minf(1.0, 4.0 * k * dt))
				"smooth":
					var avg = 0.0
					var n = 0
					for o in [-1, 1, -W, W]:
						if i + o >= 0 and i + o < th.size():
							avg += th[i + o]
							n += 1
					th[i] = lerpf(th[i], avg / maxf(1.0, n), minf(1.0, 3.0 * k * dt))
	w.th = th

# colour the ground under the brush
func _paint(p: Vector3) -> void:
	var w = G.world
	if w.paint.size() != w.th.size():
		var pa = PackedByteArray()
		pa.resize(w.th.size())
		pa.fill(0)
		w.paint = pa
	var idx = int(tool.split(":")[1])
	var r = brush
	var W = w.TW + 1
	var x0 = maxi(0, int(floor(p.x - r - w.TX0)))
	var x1 = mini(w.TW, int(ceil(p.x + r - w.TX0)))
	var z0 = maxi(0, int(floor(p.z - r - w.TZ0)))
	var z1 = mini(w.TH_, int(ceil(p.z + r - w.TZ0)))
	var pa2: PackedByteArray = w.paint
	for iz in range(z0, z1 + 1):
		for ix in range(x0, x1 + 1):
			var d = Vector2(w.TX0 + ix - p.x, w.TZ0 + iz - p.z).length()
			# a ragged edge so painted patches don't look like stamped circles
			if d < r * (0.75 + 0.25 * sin(ix * 1.7 + iz * 2.3)):
				pa2[iz * W + ix] = idx
	w.paint = pa2
	data["paint"] = pa2

func _terrain_changed() -> void:
	G.world.build_terrain(data["ground"])
	data["heights"] = G.world.th
	_rebuild_items()

func _click(p: Vector3) -> void:
	if wp_mode and sel_kind == "unit" and sel != null:
		if not sel.has("wp"):
			sel["wp"] = []
		sel["wp"].append(Vector3(snappedf(p.x, 0.5), 0, snappedf(p.z, 0.5)))
		if sel.get("order", "hold") in ["hold", "free", "attack"]:
			sel["order"] = "move"
		_rebuild_markers()
		_inspect()
		_status("Waypoint %d added · keep clicking to add more, or press Done" % sel["wp"].size())
		return
	if spot_mode and sel_kind == "trigger" and sel != null:
		sel["ax"] = snappedf(p.x, 0.5)
		sel["az"] = snappedf(p.z, 0.5)
		spot_mode = false
		_rebuild_markers()
		_inspect()
		_status("Action spot set")
		return
	match tool:
		"squadA", "squadB":
			var u = {"kind": "squad", "team": 0 if tool == "squadA" else 1, "x": snappedf(p.x, 0.5), "z": snappedf(p.z, 0.5), "rot": rot, "size": 6, "order": "hold", "wp": []}
			data["units"].append(u)
			_select(u, "unit")
		"vehA", "vehB":
			var u2 = {"kind": "vehicle", "team": 0 if tool == "vehA" else 1, "x": snappedf(p.x, 0.5), "z": snappedf(p.z, 0.5), "rot": rot, "vtype": veh_pick, "order": "free", "wp": []}
			data["units"].append(u2)
			_select(u2, "unit")
		"trigger":
			var tr = {"when": "enter", "team": 0, "x": snappedf(p.x, 0.5), "z": snappedf(p.z, 0.5), "r": 14.0, "t": 60.0, "n": 6, "pt": 0,
				"then": "reinforce", "ateam": 1, "text": "", "vtype": "tank"}
			data["triggers"].append(tr)
			_select(tr, "trigger")
		"sel":
			_select_at(p)
		"erase":
			_erase(p)
		"crater":
			G.world.crater_ter(p.x, p.z, brush * 0.45, brush * 0.18)
			_terrain_changed()
		"spawnA", "spawnB":
			data["spawns"][0 if tool == "spawnA" else 1] = Vector3(p.x, 0, p.z)
			_rebuild_markers()
		"point":
			if data["points"].size() >= 8:
				_status("At most 8 control points")
				return
			data["points"].append(Vector3(p.x, 0, p.z))
			_rebuild_markers()
		_:
			var it = {"t": tool, "x": snappedf(p.x, 0.5), "z": snappedf(p.z, 0.5), "rot": rot, "seed": randi() % 100000}
			data["items"].append(it)
			nodes.append(_make_item_node(it))

func _drag_done(a: Vector3, b: Vector3) -> void:
	if tool == "road":
		var w = absf(b.x - a.x)
		var d = absf(b.z - a.z)
		# a thin drag becomes a 7 m wide road along its long side
		if w >= d:
			d = maxf(d, 7.0)
		else:
			w = maxf(w, 7.0)
		var it = {"t": "road", "x": (a.x + b.x) / 2.0, "z": (a.z + b.z) / 2.0, "w": maxf(w, 4.0), "d": maxf(d, 4.0), "rot": 0, "seed": 1}
		G.world.flatten_rect(it["x"] - it["w"] / 2.0, it["z"] - it["d"] / 2.0, it["x"] + it["w"] / 2.0, it["z"] + it["d"] / 2.0, 2.5)
		data["items"].append(it)
		_terrain_changed()
	elif tool == "trench":
		if a.distance_to(b) < 2.0:
			return
		G.world.trench_ter([Vector2(a.x, a.z), Vector2(b.x, b.z)], 2.4, 1.15)
		data["items"].append({"t": "trench", "x": a.x, "z": a.z, "x2": b.x, "z2": b.z, "rot": 0, "seed": 1})
		_terrain_changed()

func _erase(p: Vector3) -> void:
	for arr in [data["units"], data["triggers"]]:
		for i in range(arr.size()):
			if G.dist2d(Vector3(arr[i]["x"], 0, arr[i]["z"]), p) < 3.0:
				if arr[i] == sel:
					_select(null, "")
				arr.remove_at(i)
				_rebuild_markers()
				return
	# markers first
	for i in range(data["points"].size()):
		if G.dist2d(data["points"][i], p) < 4.0 and data["points"].size() > 1:
			data["points"].remove_at(i)
			_rebuild_markers()
			return
	var best = -1
	var bd = 5.0
	for i in range(data["items"].size()):
		var it = data["items"][i]
		var d = Vector2(it["x"] - p.x, it["z"] - p.z).length()
		if it["t"] == "trench":
			d = minf(d, Vector2(it["x2"] - p.x, it["z2"] - p.z).length())
		if d < bd:
			bd = d
			best = i
	if best >= 0:
		data["items"].remove_at(best)
		if best < nodes.size():
			nodes[best].queue_free()
			nodes.remove_at(best)

# ---------------------------------------------------------------- saving, loading, playing
static func list_maps() -> Array:
	var out = []
	var d = DirAccess.open("user://maps")
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".map"):
			out.append(f.trim_suffix(".map"))
	out.sort()
	return out

static func load_file(n: String) -> Dictionary:
	var f = FileAccess.open("user://maps/%s.map" % n, FileAccess.READ)
	if f == null:
		return {}
	var m = f.get_var()
	return m if m is Dictionary else {}

func save() -> void:
	var n = name_edit.text.strip_edges().replace("/", "-").replace(".", "-")
	if n == "":
		n = "My map"
	data["name"] = n
	data["heights"] = G.world.th
	data["paint"] = G.world.paint
	DirAccess.make_dir_recursive_absolute("user://maps")
	var f = FileAccess.open("user://maps/%s.map" % n, FileAccess.WRITE)
	f.store_var(data)
	f.close()
	_status("Saved \"%s\"" % n)
	G.ui.refresh_maps()

func open_saved(n: String) -> void:
	var m = load_file(n)
	if m.is_empty():
		_status("Couldn't open \"%s\"" % n)
		return
	data = m
	_open()
	_status("Opened \"%s\"" % n)

func play() -> void:
	var modes = ["sandbox", "deathmatch", "capture", "frontline", "assault", "laststand", "koth", "commander", "horde"]
	data["heights"] = G.world.th
	data["paint"] = G.world.paint
	_select(null, "")
	G.custom_map = data.duplicate(true)
	active = false
	visible = false
	if cursor:
		cursor.visible = false
	if markers:
		markers.queue_free()
		markers = null
	G.ui.root.visible = true
	var placed_only = armies_opt != null and armies_opt.selected == 1 and not data["units"].is_empty()
	G.main.start_game({"map": "custom", "mode": modes[mode_opt.selected], "size": 10, "limit": 100, "reinforce": not placed_only, "teams": 2,
		"armies": not placed_only})

# ---------------------------------------------------------------- UI
func _status(t: String) -> void:
	if status:
		status.text = t

func _build_ui() -> void:
	for c in root.get_children():
		c.queue_free()
	insp = null
	tool_buttons = {}
	var ui = G.ui
	var side = ui._panel(Color(0.09, 0.1, 0.12, 0.92))
	ui._place(side, Control.PRESET_TOP_LEFT, 10, 10, 250, 0)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.add_child(ui._label("Map editor", 20))
	for grp in TOOLS:
		if grp[0] != "":
			v.add_child(ui._label(grp[0], 13, Color(0.7, 0.72, 0.74)))
		var flow = HFlowContainer.new()
		for t in grp[1]:
			var id = t[0]
			var b = ui._button(t[1], func(): _pick(id))
			tool_buttons[id] = b
			flow.add_child(b)
		v.add_child(flow)
	v.add_child(ui._label("R rotate · [ ] brush size · right-drag look · WASD fly · Esc exit", 11, Color(0.65, 0.65, 0.65)))
	var sc = ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(240, minf(660.0, root.get_viewport().get_visible_rect().size.y - 40.0))
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	side.add_child(sc)
	root.add_child(side)
	var top = ui._panel(Color(0.09, 0.1, 0.12, 0.92))
	ui._place(top, Control.PRESET_CENTER_TOP, -450, 10, 900, 0)
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	name_edit = LineEdit.new()
	name_edit.text = data.get("name", "My map")
	name_edit.custom_minimum_size = Vector2(150, 0)
	h.add_child(name_edit)
	h.add_child(ui._button("Save", func(): save()))
	var lb = ui._button("Open…", func(): load_box.visible = not load_box.visible)
	h.add_child(lb)
	h.add_child(ui._button("New small", func(): new_map(Vector2(260, 190))))
	h.add_child(ui._button("New large", func(): new_map(Vector2(560, 240))))
	mode_opt = ui._option(["Sandbox", "Deathmatch", "Capture", "Frontline", "Assault", "Last stand", "King of the hill", "Commander", "Horde"], 2)
	h.add_child(mode_opt)
	armies_opt = ui._option(["Armies + my units", "Only my units"], 0)
	h.add_child(armies_opt)
	var pb = ui._button("▶ Play", func(): play())
	pb.modulate = Color(0.6, 1.0, 0.6)
	h.add_child(pb)
	h.add_child(ui._button("Exit", func(): close()))
	top.add_child(h)
	root.add_child(top)
	load_box = VBoxContainer.new()
	ui._place(load_box, Control.PRESET_CENTER_TOP, 0, 60, 220, 0)
	for n in list_maps():
		var nn = n
		load_box.add_child(ui._button(n, func():
			load_box.visible = false
			open_saved(nn)))
	if list_maps().is_empty():
		load_box.add_child(ui._label("No saved maps yet", 13))
	load_box.visible = false
	root.add_child(load_box)
	status = ui._label("", 14)
	ui._place(status, Control.PRESET_CENTER_BOTTOM, -300, -40, 600, 24)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(status)
	_pick(tool)

func _pick(id: String) -> void:
	tool = id
	wp_mode = false
	spot_mode = false
	for k in tool_buttons:
		tool_buttons[k].modulate = Color(1.0, 0.85, 0.3) if k == id else Color.WHITE
	_status(TIPS.get(id, "Click to place · R rotates"))
	if root != null and (insp != null or id in ["vehA", "vehB"]):
		_inspect()

# ---------------------------------------------------------------- selecting units and triggers, and their settings
func _select_at(p: Vector3) -> void:
	var best = null
	var bk = ""
	var bd = 4.0
	for u in data["units"]:
		var d = G.dist2d(Vector3(u["x"], 0, u["z"]), p)
		if d < bd:
			bd = d
			best = u
			bk = "unit"
	for tr in data["triggers"]:
		var d2 = G.dist2d(Vector3(tr["x"], 0, tr["z"]), p)
		if d2 < bd:
			bd = d2
			best = tr
			bk = "trigger"
	_select(best, bk)

func _select(x, kind: String) -> void:
	sel = x
	sel_kind = kind if x != null else ""
	wp_mode = false
	spot_mode = false
	_rebuild_markers()
	_inspect()

func _inspect() -> void:
	if insp == null:
		insp = G.ui._panel(Color(0.09, 0.1, 0.12, 0.94))
		G.ui._place(insp, Control.PRESET_TOP_RIGHT, -300, 70, 290, 0)
		insp_box = VBoxContainer.new()
		insp_box.add_theme_constant_override("separation", 4)
		insp.add_child(insp_box)
		root.add_child(insp)
	if insp.get_parent() != root:
		root.add_child(insp)
	for c in insp_box.get_children():
		c.queue_free()
	var ui = G.ui
	if sel == null:
		insp.visible = tool in ["vehA", "vehB"]
		if insp.visible:
			insp_box.add_child(ui._label("Vehicle to place", 15))
			insp_box.add_child(_opt(Scripted.VEHICLES, Scripted.VEHICLES.find(veh_pick), func(i): veh_pick = Scripted.VEHICLES[i]))
		return
	insp.visible = true
	if sel_kind == "unit":
		var u = sel
		insp_box.add_child(ui._label(Scripted.describe_unit(u), 14, Color(1, 0.95, 0.6)))
		insp_box.add_child(_opt(["Alpha", "Bravo"], u["team"], func(i): u["team"] = i; _changed()))
		if u["kind"] == "squad":
			insp_box.add_child(_spin("Men", 1, 20, u.get("size", 6), func(v): u["size"] = int(v); _changed()))
		else:
			insp_box.add_child(_opt(Scripted.VEHICLES, maxi(0, Scripted.VEHICLES.find(u.get("vtype", "jeep"))), func(i): u["vtype"] = Scripted.VEHICLES[i]; _changed()))
		insp_box.add_child(ui._label("Orders", 13, Color(0.7, 0.72, 0.74)))
		insp_box.add_child(_opt(Scripted.ORDER_NAMES, maxi(0, Scripted.ORDERS.find(u.get("order", "hold"))), func(i): u["order"] = Scripted.ORDERS[i]; _changed()))
		var h = HBoxContainer.new()
		h.add_child(ui._button("Done adding" if wp_mode else "Add waypoints", func():
			wp_mode = not wp_mode
			_status("Click the ground to add waypoints" if wp_mode else "")
			_inspect()))
		h.add_child(ui._button("Clear waypoints", func(): u["wp"] = []; _changed()))
		insp_box.add_child(h)
	else:
		var tr = sel
		insp_box.add_child(ui._label(Scripted.describe_trigger(tr), 14, Color(1, 0.85, 0.5)))
		insp_box.add_child(ui._label("When", 13, Color(0.7, 0.72, 0.74)))
		insp_box.add_child(_opt(Scripted.WHEN_NAMES, maxi(0, Scripted.WHEN.find(tr.get("when", "enter"))), func(i): tr["when"] = Scripted.WHEN[i]; _changed(); _inspect()))
		match tr.get("when", "enter"):
			"time":
				insp_box.add_child(_spin("Seconds", 5, 3600, tr.get("t", 60.0), func(v): tr["t"] = float(v); _changed()))
			"enter", "clear":
				insp_box.add_child(_opt(["Alpha", "Bravo"], tr.get("team", 0), func(i): tr["team"] = i; _changed()))
				insp_box.add_child(_spin("Radius (m)", 3, 80, tr.get("r", 14.0), func(v): tr["r"] = float(v); _changed()))
			"point":
				insp_box.add_child(_opt(["Alpha", "Bravo"], tr.get("team", 0), func(i): tr["team"] = i; _changed()))
				var names = []
				for k in range(maxi(1, data["points"].size())):
					names.append("Point " + "ABCDEFGH"[k])
				insp_box.add_child(_opt(names, clampi(int(tr.get("pt", 0)), 0, names.size() - 1), func(i): tr["pt"] = i; _changed()))
			"losses":
				insp_box.add_child(_opt(["Alpha", "Bravo"], tr.get("team", 0), func(i): tr["team"] = i; _changed()))
				insp_box.add_child(_spin("Men lost", 1, 200, tr.get("n", 10), func(v): tr["n"] = int(v); _changed()))
		insp_box.add_child(ui._label("Then", 13, Color(0.7, 0.72, 0.74)))
		insp_box.add_child(_opt(Scripted.THEN_NAMES, maxi(0, Scripted.THEN.find(tr.get("then", "message"))), func(i): tr["then"] = Scripted.THEN[i]; _changed(); _inspect()))
		var th = tr.get("then", "message")
		if th in ["reinforce", "vehicle", "airstrike", "attack", "win"]:
			insp_box.add_child(_opt(["for Alpha", "for Bravo"], tr.get("ateam", 1), func(i): tr["ateam"] = i; _changed()))
		if th == "reinforce":
			insp_box.add_child(_spin("Men", 1, 20, tr.get("n", 6), func(v): tr["n"] = int(v); _changed()))
		if th == "vehicle":
			insp_box.add_child(_opt(Scripted.VEHICLES, maxi(0, Scripted.VEHICLES.find(tr.get("vtype", "tank"))), func(i): tr["vtype"] = Scripted.VEHICLES[i]; _changed()))
		var te = LineEdit.new()
		te.placeholder_text = "Message to show (optional)"
		te.text = tr.get("text", "")
		te.text_changed.connect(func(t): tr["text"] = t; _rebuild_markers())
		insp_box.add_child(te)
		if th in ["reinforce", "vehicle", "artillery", "airstrike", "smoke", "attack"]:
			insp_box.add_child(ui._button("Click to set where it happens" if not spot_mode else "Click the map…", func():
				spot_mode = true
				_status("Click where it should happen")
				_inspect()))
	insp_box.add_child(ui._button("Delete", func():
		if sel_kind == "unit":
			data["units"].erase(sel)
		else:
			data["triggers"].erase(sel)
		_select(null, "")))

func _changed() -> void:
	_rebuild_markers()
	if insp_box.get_child_count() > 0 and insp_box.get_child(0) is Label:
		insp_box.get_child(0).text = Scripted.describe_unit(sel) if sel_kind == "unit" else Scripted.describe_trigger(sel)

func _opt(items: Array, selected: int, cb: Callable) -> OptionButton:
	var o = G.ui._option(items, clampi(selected, 0, items.size() - 1))
	o.item_selected.connect(cb)
	return o

func _spin(label: String, lo: float, hi: float, val: float, cb: Callable) -> HBoxContainer:
	var h = HBoxContainer.new()
	h.add_child(G.ui._label(label, 13))
	var sp = SpinBox.new()
	sp.min_value = lo
	sp.max_value = hi
	sp.value = val
	sp.value_changed.connect(cb)
	h.add_child(sp)
	return h
