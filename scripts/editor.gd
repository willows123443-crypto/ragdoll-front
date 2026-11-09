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

const TOOLS = [
	["Ground", [["raise", "Raise"], ["lower", "Lower"], ["flatten", "Flatten"], ["smooth", "Smooth"], ["crater", "Crater"]]],
	["Buildings", [["house", "House"], ["tower", "Two-storey"], ["wall", "Wall"]]],
	["Cover", [["sandbags", "Sandbags"], ["crate", "Crate"], ["hedge", "Hedge"], ["hedgehog", "Tank trap"], ["trench", "Trench (drag)"]]],
	["Props", [["tree", "Tree"], ["deadtree", "Dead tree"], ["tankwreck", "Tank wreck"], ["truckwreck", "Truck wreck"], ["ammo", "Ammo crate"], ["road", "Road (drag)"]]],
	["Markers", [["spawnA", "Alpha spawn"], ["spawnB", "Bravo spawn"], ["point", "Control point"]]],
	["", [["erase", "Erase"]]],
]
const TIPS = {
	"raise": "Hold the left button to raise the ground ([ ] change brush size)", "lower": "Hold to dig the ground down",
	"flatten": "Hold to level the ground to where you first clicked", "smooth": "Hold to smooth bumps",
	"crater": "Click to blow a shell crater", "trench": "Drag to dig a trench with duckboards",
	"road": "Drag a rectangle to lay a flat road", "erase": "Click an object or marker to remove it",
	"point": "Click to add a control point (frontline mode takes them in order from west to east)",
}

func _ready() -> void:
	layer = 5
	G.editor = self
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	visible = false
	G.ui.refresh_maps()

func typing() -> bool:
	return active and name_edit != null and name_edit.has_focus()

# ---------------------------------------------------------------- opening / closing
func new_map(size: Vector2) -> void:
	var h = PackedFloat32Array()
	h.resize((int(size.x) + 1) * (int(size.y) + 1))
	h.fill(0.0)
	data = {"name": "My map", "size": size, "ground": Color(0.46, 0.45, 0.35), "heights": h, "items": [],
		"spawns": [Vector3(-size.x / 2.0 + 30.0, 0, 0), Vector3(size.x / 2.0 - 30.0, 0, 0)], "points": [Vector3.ZERO]}
	_open()

func _open() -> void:
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
			var r = brush if tool in ["raise", "lower", "flatten", "smooth", "crater"] else 2.0
			cursor.scale = Vector3(r, 1.0, r)
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		var p = _ground_at(ev.position)
		if ev.pressed:
			if p == null:
				return
			if tool in ["raise", "lower", "flatten", "smooth"]:
				painting = true
				flatten_h = G.world.ground_y(p.x, p.z)
			elif tool in ["road", "trench"]:
				drag_a = p
			else:
				_click(p)
		else:
			if painting:
				painting = false
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

func _terrain_changed() -> void:
	G.world.build_terrain(data["ground"])
	data["heights"] = G.world.th
	_rebuild_items()

func _click(p: Vector3) -> void:
	match tool:
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
	var modes = ["sandbox", "deathmatch", "capture", "frontline", "assault", "laststand"]
	data["heights"] = G.world.th
	G.custom_map = data.duplicate(true)
	active = false
	visible = false
	if cursor:
		cursor.visible = false
	if markers:
		markers.queue_free()
		markers = null
	G.ui.root.visible = true
	G.main.start_game({"map": "custom", "mode": modes[mode_opt.selected], "size": 10, "limit": 100, "reinforce": true, "teams": 2})

# ---------------------------------------------------------------- UI
func _status(t: String) -> void:
	if status:
		status.text = t

func _build_ui() -> void:
	for c in root.get_children():
		c.queue_free()
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
	side.add_child(v)
	root.add_child(side)
	var top = ui._panel(Color(0.09, 0.1, 0.12, 0.92))
	ui._place(top, Control.PRESET_CENTER_TOP, -380, 10, 760, 0)
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
	mode_opt = ui._option(["Sandbox", "Deathmatch", "Capture", "Frontline", "Assault", "Last stand"], 2)
	h.add_child(mode_opt)
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
	for k in tool_buttons:
		tool_buttons[k].modulate = Color(1.0, 0.85, 0.3) if k == id else Color.WHITE
	_status(TIPS.get(id, "Click to place · R rotates"))
