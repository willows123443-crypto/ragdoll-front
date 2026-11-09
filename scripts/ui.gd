extends CanvasLayer
# HUD, tool bar, menus. Built in code so the project has no scene files to keep in sync.

var tool = "ctl"
var tab = "units"
const MAP_IDS = ["town", "field", "trenches", "forest", "city", "beach", "valley", "front", "river", "pass", "random"]
const TOOLS = {
	"units": [["a1", "Alpha soldier"], ["b1", "Bravo soldier"], ["a5", "Alpha squad"], ["b5", "Bravo squad"], ["ctl", "Take control"], ["spA", "Alpha spawn"], ["spB", "Bravo spawn"]],
	"command": [["sel", "Select"], ["mvA", "Alpha: move to"], ["mvB", "Bravo: move to"]],
	"vehicles": [["v:jeep:0", "Jeep A"], ["v:jeep:1", "Jeep B"], ["v:tank:0", "Tank A"], ["v:tank:1", "Tank B"], ["v:halftrack:0", "Half-track A"],
		["v:armoredcar:1", "Armoured car B"], ["v:motorbike:0", "Motorbike A"], ["v:gunship:0", "Gunship A"], ["v:gunship:1", "Gunship B"],
		["v:truck:0", "Truck A"], ["v:nest:0", "MG nest A"], ["v:nest:1", "MG nest B"], ["v:mortar:0", "Mortar A"], ["v:artillery:0", "Field gun A"]],
	"support": [["sup:artillery", "Artillery 10"], ["sup:airstrike", "Air strike 16"], ["sup:paradrop", "Paras 12"], ["sup:heli", "Heli 16"],
		["sup:jeep", "Jeep 8"], ["sup:halftrack", "Half-track 14"], ["sup:armoredcar", "Arm. car 20"], ["sup:tank", "Tank 30"], ["sup:gunship", "Gunship 34"]],
	"build": [["bteam", "Team"], ["b:fob", "FOB"], ["b:sandbags", "Sandbags"], ["b:wire", "Wire"], ["b:traps", "Tank traps"], ["b:mgnest", "MG nest"],
		["b:mortarpit", "Mortar pit"], ["b:tower", "Watchtower"], ["b:bunker", "Bunker"], ["b:hospital", "Hospital"], ["b:radio", "Radio mast"],
		["b:depot", "Depot"], ["b:supply", "Supply dump"], ["dis", "Dismantle"]],
	"fun": [["boom", "Explosion"], ["mortar", "Mortar strike"], ["smoke", "Smoke"], ["flare", "Flare"], ["push", "Shove"]],
}
const TIPS = {"dis": "Click a structure, wall, building piece or emplacement to take it apart",
	"bteam": "Click to change which team the next construction site is for","sel": "Click or drag a box to select soldiers (Shift adds), then right-click the ground to send them there",
	"mvA": "Click to send the whole Alpha team to a point", "mvB": "Click to send the whole Bravo team to a point",
	"a1": "Click the ground to drop in an Alpha soldier", "b1": "Click the ground to drop in a Bravo soldier",
	"a5": "Click to drop in five Alpha soldiers", "b5": "Click to drop in five Bravo soldiers",
	"ctl": "Click a soldier to take control of them (or press F)", "spA": "Click to move where Alpha reinforcements arrive",
	"spB": "Click to move where Bravo reinforcements arrive", "boom": "Click anywhere to set off an explosion",
	"mortar": "Click to call in a mortar barrage",
	"nA": "Click to build an Alpha machine-gun nest (crewed)", "nB": "Click to build a Bravo machine-gun nest (crewed)",
	"mA": "Click to set up an Alpha mortar pit (it shells enemies your team has spotted)",
	"jA": "Click to drop an Alpha jeep with a driver and gunner", "jB": "Click to drop a Bravo jeep with a driver and gunner",
	"tA": "Click to drop an Alpha tank with its crew", "tB": "Click to drop a Bravo tank with its crew",
	"trA": "Click to drop an empty Alpha truck (take control of a soldier and press F next to it)", "trB": "Click to drop an empty Bravo truck", "smoke": "Click to drop a smoke screen", "flare": "Click to put up a parachute flare (lights up the area at night)", "push": "Click a soldier to shove them over"}

var root: Control
var lbl_a: Label
var lbl_na: Label
var lbl_nb: Label
var lbl_more: Label
var pa_panel: PanelContainer
var pb_panel: PanelContainer
var lbl_b: Label
var lbl_sa: Label
var lbl_sb: Label
var lbl_clock: Label
var lbl_mode: Label
var top_bar: Control
var feed_box: VBoxContainer
var side: VBoxContainer
var btn_reinf: Button
var tabs_box: HBoxContainer
var build_team = 0
var tool_box: HBoxContainer
var tip: Label
var msg: Label
var msg_t = 0.0
var cross: Control
var hitmark: Label
var hit_t = 0.0
var dmg: Control
var dmg_list: Array = []
var phud: PanelContainer
var p_name: Label
var p_hp: ProgressBar
var p_ammo: Label
var scope: TextureRect
var cap_box: VBoxContainer
var cap_lbl: Label
var cap_bar: ProgressBar
var points_box: HBoxContainer
var menu: PanelContainer
var help: PanelContainer
var win: PanelContainer
var win_title: Label
var report: PanelContainer
var report_body: VBoxContainer
var report_chart: Control
var opt_map: OptionButton
var opt_mode: OptionButton
var mode_info: Label
const MODE_IDS = ["sandbox", "deathmatch", "capture", "frontline", "assault", "laststand", "destroy", "breakthrough", "sabotage", "siege"]
var opt_size: OptionButton
var opt_limit: OptionButton
var opt_reinf: OptionButton
var opt_armor: OptionButton
var opt_teams: OptionButton
var opt_time: OptionButton
var seed_edit: LineEdit
var teams_panel: PanelContainer
var settings_panel: PanelContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_top()
	_build_side()
	_build_tools()
	_build_center()
	_build_player_hud()
	_build_menu()
	_build_help()
	_build_win()
	_build_command()

# ---------------------------------------------------------------- helpers
func _place(c: Control, preset: int, x: float, y: float, w: float, h: float) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = x
	c.offset_top = y
	c.offset_right = x + w
	c.offset_bottom = y + h

func _label(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _panel(col: Color) -> PanelContainer:
	var p = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", sb)
	return p

func _button(text: String, cb: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b

# ---------------------------------------------------------------- top scoreboard and feed
func _build_top() -> void:
	top_bar = HBoxContainer.new()
	_place(top_bar, Control.PRESET_CENTER_TOP, -260, 10, 520, 50)
	top_bar.add_theme_constant_override("separation", 0)
	root.add_child(top_bar)
	pa_panel = _panel(Color(0.11, 0.31, 0.72))
	var pa = pa_panel
	var va = VBoxContainer.new()
	lbl_na = _label("ALPHA SQUAD", 14)
	va.add_child(lbl_na)
	lbl_a = _label("0 alive", 11)
	va.add_child(lbl_a)
	pa.add_child(va)
	top_bar.add_child(pa)
	var ps = _panel(Color(0.05, 0.05, 0.05))
	lbl_sa = _label("0", 24)
	ps.add_child(lbl_sa)
	top_bar.add_child(ps)
	var pc = _panel(Color(0.17, 0.18, 0.21))
	var vc = VBoxContainer.new()
	lbl_clock = _label("00:00", 16)
	lbl_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_mode = _label("sandbox", 11)
	lbl_mode.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vc.add_child(lbl_clock)
	vc.add_child(lbl_mode)
	pc.add_child(vc)
	top_bar.add_child(pc)
	var ps2 = _panel(Color(0.05, 0.05, 0.05))
	lbl_sb = _label("0", 24)
	ps2.add_child(lbl_sb)
	top_bar.add_child(ps2)
	pb_panel = _panel(Color(0.71, 0.14, 0.14))
	var pb = pb_panel
	var vb = VBoxContainer.new()
	lbl_nb = _label("BRAVO SQUAD", 14)
	vb.add_child(lbl_nb)
	lbl_b = _label("0 alive", 11)
	vb.add_child(lbl_b)
	pb.add_child(vb)
	top_bar.add_child(pb)
	lbl_more = _label("", 13)
	lbl_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(lbl_more, Control.PRESET_CENTER_TOP, -300, 62, 600, 20)
	root.add_child(lbl_more)
	feed_box = VBoxContainer.new()
	_place(feed_box, Control.PRESET_TOP_RIGHT, -330, 70, 320, 200)
	feed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(feed_box)
	cap_box = VBoxContainer.new()
	_place(cap_box, Control.PRESET_CENTER_TOP, -130, 70, 260, 30)
	cap_lbl = _label("Objective", 12)
	cap_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap_bar = ProgressBar.new()
	cap_bar.min_value = -1.0
	cap_bar.max_value = 1.0
	cap_bar.show_percentage = false
	cap_bar.custom_minimum_size = Vector2(260, 8)
	points_box = HBoxContainer.new()
	points_box.alignment = BoxContainer.ALIGNMENT_CENTER
	points_box.add_theme_constant_override("separation", 6)
	cap_box.add_child(points_box)
	cap_box.add_child(cap_lbl)
	cap_box.add_child(cap_bar)
	cap_box.visible = false
	root.add_child(cap_box)

func feed(a, v, head: bool, what: String = "") -> void:
	var t = ""
	if v == null:
		t = "%s  [%s]  %s destroyed" % [a.sname, a.W["name"], what]
	elif a != null:
		t = "%s  [%s]  %s%s" % [a.sname, a.W["name"], v.sname, "  ✦" if head else ""]
		if a.team == v.team and a != v:
			t += " (friendly)"
	else:
		t = "%s ✖" % v.sname
	var ct = a.team if a != null else (v.team if v != null else 0)
	var l = _label(t, 13, G.team_color(ct).lightened(0.45))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	feed_box.add_child(l)
	feed_box.move_child(l, 0)
	while feed_box.get_child_count() > 7:
		var last = feed_box.get_child(feed_box.get_child_count() - 1)
		feed_box.remove_child(last)
		last.queue_free()
	var wr = weakref(l)
	get_tree().create_timer(6.0).timeout.connect(func():
		var n = wr.get_ref()
		if n != null:
			n.queue_free())

func _tint(p: PanelContainer, c: Color) -> void:
	var sb = p.get_theme_stylebox("panel")
	if sb is StyleBoxFlat and sb.bg_color != c:
		sb = sb.duplicate()
		sb.bg_color = Color(c.r, c.g, c.b, sb.bg_color.a)
		p.add_theme_stylebox_override("panel", sb)

# ---------------------------------------------------------------- side buttons
func _build_side() -> void:
	side = VBoxContainer.new()
	side.position = Vector2(12, 12)
	side.custom_minimum_size = Vector2(170, 0)
	root.add_child(side)
	side.add_child(_button("☰ Menu (M)", func(): show_menu()))
	btn_reinf = _button("Reinforcements: on", func():
		G.reinforce = not G.reinforce
		btn_reinf.text = "Reinforcements: " + ("on" if G.reinforce else "off"))
	side.add_child(btn_reinf)
	side.add_child(_button("Slow-mo (T)", func(): Engine.time_scale = 0.25 if Engine.time_scale > 0.5 else 1.0))
	side.add_child(_button("Pause (P)", func(): get_tree().paused = not get_tree().paused))
	side.add_child(_button("Clear bodies", func(): G.main.clear_bodies()))
	side.add_child(_button("Battle report (J)", func(): show_report()))
	side.add_child(_button("Controls (H)", func(): help.visible = true))

# ---------------------------------------------------------------- tool bar
func _build_tools() -> void:
	tabs_box = HBoxContainer.new()
	_place(tabs_box, Control.PRESET_CENTER_BOTTOM, -230, -96, 460, 32)
	root.add_child(tabs_box)
	tool_box = HBoxContainer.new()
	_place(tool_box, Control.PRESET_CENTER_BOTTOM, -420, -56, 840, 40)
	root.add_child(tool_box)
	tip = _label("", 13)
	_place(tip, Control.PRESET_CENTER_BOTTOM, -300, -124, 600, 20)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(tip)
	_render_tools()

func _render_tools() -> void:
	for c in tabs_box.get_children():
		c.queue_free()
	for c in tool_box.get_children():
		c.queue_free()
	for t in [["units", "Units"], ["command", "Command"], ["vehicles", "Vehicles"], ["support", "Support"], ["build", "Build"], ["fun", "Effects"]]:
		var key = t[0]
		var b = _button(t[1], func():
			tab = key
			tool = TOOLS[key][0][0] if key != "build" else "b:fob"
			_render_tools())
		if tab == key:
			b.modulate = Color(1.0, 0.85, 0.3)
		tabs_box.add_child(b)
	var i = 1
	for t in TOOLS[tab]:
		var id = t[0]
		var label: String = t[1]
		if id == "bteam":
			label = "Team: %s" % G.TEAM_NAMES[build_team] if build_team < G.TEAM_NAMES.size() else "Team"
		var b2 = _button("%d  %s" % [i, label], func():
			if id == "bteam":
				build_team = (build_team + 1) % maxi(1, G.team_count())
			else:
				tool = id
			_render_tools())
		if id == "bteam" and build_team < G.TEAM_BAND.size():
			b2.modulate = G.team_color(build_team).lightened(0.4)
		if tool == id:
			b2.modulate = Color(1.0, 0.85, 0.3)
		tool_box.add_child(b2)
		i += 1
	tool_box.offset_left = -minf(TOOLS[tab].size() * 62.0, 780.0)
	tool_box.offset_right = minf(TOOLS[tab].size() * 62.0, 780.0)
	tip.text = TIPS.get(tool, "")

func pick_tool(i: int) -> void:
	if i < TOOLS[tab].size():
		if TOOLS[tab][i][0] == "bteam":
			build_team = (build_team + 1) % maxi(1, G.team_count())
		else:
			tool = TOOLS[tab][i][0]
		_render_tools()

# ---------------------------------------------------------------- crosshair, hit marker, damage arrows, scope, messages
var vignette: ColorRect

# darkened, shaking edges when bullets are cracking past you
func _build_vignette() -> void:
	vignette = ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh = Shader.new()
	sh.code = """shader_type canvas_item;
uniform float amount = 0.0;
void fragment() {
	vec2 d = UV - vec2(0.5);
	float r = length(d * vec2(1.25, 1.0));
	float v = smoothstep(0.32, 0.78, r) * amount;
	COLOR = vec4(0.03, 0.02, 0.02, v);
}"""
	var mat = ShaderMaterial.new()
	mat.shader = sh
	vignette.material = mat
	root.add_child(vignette)
	root.move_child(vignette, 0)

func _build_center() -> void:
	_build_vignette()
	cross = Control.new()
	cross.set_anchors_preset(Control.PRESET_FULL_RECT)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross.draw.connect(_draw_cross)
	root.add_child(cross)
	hitmark = _label("✕", 30, Color(1, 1, 1))
	_place(hitmark, Control.PRESET_CENTER, -10, -22, 20, 40)
	hitmark.visible = false
	root.add_child(hitmark)
	dmg = Control.new()
	dmg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dmg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dmg.draw.connect(_draw_dmg)
	root.add_child(dmg)
	msg = _label("", 22)
	_place(msg, Control.PRESET_CENTER_TOP, -400, 230, 800, 40)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(msg)
	scope = TextureRect.new()
	scope.set_anchors_preset(Control.PRESET_FULL_RECT)
	scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scope.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scope.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var img = Image.create_empty(256, 256, false, Image.FORMAT_RGBA8)
	for y in range(256):
		for x in range(256):
			var d = Vector2(x - 128, y - 128).length()
			var a = 0.0 if d < 120 else 0.95
			if (absi(x - 128) < 1 or absi(y - 128) < 1) and d < 120:
				a = 1.0
			img.set_pixel(x, y, Color(0, 0, 0, a))
	scope.texture = ImageTexture.create_from_image(img)
	scope.visible = false
	root.add_child(scope)
	var bg = ColorRect.new()
	bg.name = "scope_bg"
	root.add_child(bg)
	bg.visible = false

func _draw_cross() -> void:
	if G.player == null or G.player.state == "riding":
		return
	var s = G.player
	if s.ads and s.wid == "sniper" and G.pc.cam.fov < 24.0:
		return
	var c = cross.size / 2.0
	var gap = minf(40.0, 6.0 + (G.pc.bloom + s.W["spread"] * (0.35 if s.ads else 1.0)) * 450.0 * (65.0 / G.pc.cam.fov))
	var col = Color(1, 1, 1, 0.9)
	cross.draw_line(c + Vector2(0, -gap - 8), c + Vector2(0, -gap), col, 2.0)
	cross.draw_line(c + Vector2(0, gap), c + Vector2(0, gap + 8), col, 2.0)
	cross.draw_line(c + Vector2(-gap - 8, 0), c + Vector2(-gap, 0), col, 2.0)
	cross.draw_line(c + Vector2(gap, 0), c + Vector2(gap + 8, 0), col, 2.0)
	cross.draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), col)

func _draw_dmg() -> void:
	var c = dmg.size / 2.0
	for d in dmg_list:
		var a = d["a"]
		var alpha = clampf(d["t"], 0.0, 1.0)
		var dir = Vector2(sin(a), -cos(a))
		var p = c + dir * 140.0
		dmg.draw_arc(c, 140.0, a - PI / 2.0 - 0.35, a - PI / 2.0 + 0.35, 16, Color(1, 0.15, 0.15, alpha * 0.85), 8.0)
		dmg.draw_circle(p, 3.0, Color(1, 0.2, 0.2, alpha))

func hit_marker(kill: bool) -> void:
	hitmark.visible = true
	hitmark.modulate = Color(1, 0.25, 0.25) if kill else Color(1, 1, 1)
	hit_t = 0.35 if kill else 0.15
	G.audio.hit_tick(kill)

func damage_indicator(from: Vector3) -> void:
	var cam = G.pc.cam
	var to = from - cam.global_position
	var a = atan2(to.x, to.z)
	var rel = G.wrap_a(a - G.pc.cam_yaw)
	dmg_list.append({"a": -rel, "t": 1.2})
	G.pc.kick = minf(0.3, G.pc.kick + 0.1)

func message(t: String) -> void:
	msg.text = t
	msg_t = 2.5

# ---------------------------------------------------------------- player panel
func _build_player_hud() -> void:
	phud = _panel(Color(0, 0, 0, 0.55))
	_place(phud, Control.PRESET_BOTTOM_LEFT, 16, -150, 260, 134)
	var v = VBoxContainer.new()
	p_name = _label("Soldier", 15)
	p_hp = ProgressBar.new()
	p_hp.show_percentage = false
	p_hp.custom_minimum_size = Vector2(240, 10)
	p_ammo = _label("30 / 30", 22)
	var keys = _label("RMB aim · Q/E lean · C crouch · Z prone · R reload\nG grenade · V smoke · 1–5 weapon · X leave soldier", 11, Color(0.8, 0.8, 0.8))
	v.add_child(p_name)
	v.add_child(p_hp)
	v.add_child(p_ammo)
	v.add_child(keys)
	phud.add_child(v)
	phud.visible = false
	root.add_child(phud)

# ---------------------------------------------------------------- menus
func _option(items: Array, sel: int) -> OptionButton:
	var o = OptionButton.new()
	for it in items:
		o.add_item(it)
	o.select(sel)
	o.focus_mode = Control.FOCUS_NONE
	return o

func _row(parent: Control, label: String, ctrl: Control) -> void:
	var h = HBoxContainer.new()
	var l = _label(label, 15)
	l.custom_minimum_size = Vector2(200, 0)
	h.add_child(l)
	h.add_child(ctrl)
	ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(h)

func _build_menu() -> void:
	menu = _panel(Color(0.11, 0.13, 0.15, 0.97))
	_place(menu, Control.PRESET_CENTER, -280, -310, 560, 620)
	menu.custom_minimum_size = Vector2(520, 0)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.add_child(_label("Ragdoll Front", 30))
	var d = _label("Two squads fight it out on their own. Drop in soldiers, call in strikes, or take control of anyone on the field.", 14, Color(0.8, 0.8, 0.8))
	d.autowrap_mode = TextServer.AUTOWRAP_WORD
	d.custom_minimum_size = Vector2(480, 0)
	v.add_child(d)
	opt_map = _option(["Town ruins", "Farmland", "Trenches", "Forest", "City blocks", "Beach landing", "Valley offensive (large)", "Western front (large)", "River crossing (large)", "Mountain pass (large)", "Random map (seed below)"], 0)
	opt_map.item_selected.connect(func(i):
		if not G.started:
			_select_map(i))
	refresh_maps()
	_row(v, "Map", opt_map)
	seed_edit = LineEdit.new()
	seed_edit.text = str(G.random_seed)
	seed_edit.custom_minimum_size = Vector2(120, 0)
	seed_edit.text_submitted.connect(func(t):
		G.random_seed = int(t) if t.is_valid_int() else t.hash()
		if MAP_IDS[opt_map.selected] == "random":
			G.main.preview_map("random"))
	var seed_row = HBoxContainer.new()
	seed_row.add_child(seed_edit)
	seed_row.add_child(_button("New seed", func():
		G.random_seed = randi() % 1000000
		seed_edit.text = str(G.random_seed)
		if opt_map.selected < MAP_IDS.size() and MAP_IDS[opt_map.selected] == "random":
			G.main.preview_map("random")))
	_row(v, "Random map seed", seed_row)
	opt_mode = _option(["Sandbox — endless", "Team deathmatch", "Capture the points", "Frontline — push across the map", "Assault — Alpha attacks", "Last stand — survive the waves",
		"Destroy base", "Breakthrough — break the line", "Sabotage — night raid", "Siege — hold the town"], 0)
	_row(v, "Mode", opt_mode)
	mode_info = _label("", 13, Color(0.8, 0.82, 0.78))
	mode_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mode_info.custom_minimum_size = Vector2(380, 54)
	v.add_child(mode_info)
	opt_mode.item_selected.connect(func(_i): _show_mode_info())
	_show_mode_info()
	opt_limit = _option(["25", "50", "100", "200"], 1)
	_row(v, "Kills / points / tickets", opt_limit)
	opt_size = _option(["5", "8", "10", "15", "20"], 2)
	_row(v, "Soldiers per team", opt_size)
	opt_reinf = _option(["By truck", "Paratroopers", "By helicopter", "Appear at base", "None"], 0)
	_row(v, "Reinforcements", opt_reinf)
	opt_armor = _option(["None", "Jeeps", "Jeeps and tanks"], 1)
	_row(v, "Vehicles", opt_armor)
	opt_teams = _option(["2 teams", "3 teams", "4 teams"], 0)
	_row(v, "Sides (3–4 only in sandbox, deathmatch, capture)", opt_teams)
	opt_time = _option(["Day", "Dusk", "Night", "Day into night (cycle)"], maxi(0, ["day", "dusk", "night", "cycle"].find(G.settings["time"])))
	opt_time.item_selected.connect(func(i):
		G.settings["time"] = ["day", "dusk", "night", "cycle"][i]
		G.main.clock = 0.25
		G.main.apply_time())
	_row(v, "Time of day", opt_time)
	var go = _button("Deploy", func(): _deploy())
	go.custom_minimum_size = Vector2(0, 44)
	go.add_theme_font_size_override("font_size", 20)
	v.add_child(go)
	var h = HBoxContainer.new()
	h.add_child(_button("Map editor", func(): G.editor.new_map(Vector2(260, 190))))
	h.add_child(_button("Teams…", func(): _show_teams()))
	h.add_child(_button("Settings…", func(): _show_settings()))
	h.add_child(_button("Controls", func(): help.visible = true))
	v.add_child(h)
	menu.add_child(v)
	root.add_child(menu)

func _deploy() -> void:
	if seed_edit != null and seed_edit.text.strip_edges() != "":
		var t = seed_edit.text.strip_edges()
		G.random_seed = int(t) if t.is_valid_int() else t.hash()
	var mid = _map_id(opt_map.selected)
	G.main.start_game({"map": mid, "mode": MODE_IDS[opt_mode.selected],
		"size": int(opt_size.get_item_text(opt_size.selected)), "limit": int(opt_limit.get_item_text(opt_limit.selected)),
		"reinforce": opt_reinf.selected != 4, "reinf_mode": ["truck", "para", "heli", "instant", "truck"][opt_reinf.selected],
		"armor": ["none", "light", "heavy"][opt_armor.selected], "teams": opt_teams.selected + 2})
	G.save_prefs()
	menu.visible = false
	help.visible = false

func _show_mode_info() -> void:
	if mode_info != null:
		var id = MODE_IDS[clampi(opt_mode.selected, 0, MODE_IDS.size() - 1)]
		var extra = ""
		if id in ["frontline", "assault", "laststand", "breakthrough", "sabotage", "siege"]:
			extra = "  (two sides only)"
		mode_info.text = Obj.MODE_INFO.get(id, "") + extra

func show_menu() -> void:
	menu.visible = true
	if G.player != null:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _build_help() -> void:
	help = _panel(Color(0.11, 0.13, 0.15, 0.97))
	_place(help, Control.PRESET_CENTER, -330, -250, 660, 500)
	help.custom_minimum_size = Vector2(660, 0)
	var v = VBoxContainer.new()
	v.add_child(_label("Controls", 26))
	var t = "FREE CAMERA\n" + \
		"  W A S D  fly · Space / E up · Q / C down · Shift faster · mouse wheel zoom\n" + \
		"  Right-drag  look around · Left-click  use the selected tool · 1–9  pick a tool\n" + \
		"  F  take control of the soldier at the centre of the screen\n" + \
		"  T  slow-mo · P  pause · M  menu\n\n" + \
		"CONTROLLING A SOLDIER\n" + \
		"  Mouse  aim · Left-click  fire · Right mouse  aim down sights\n" + \
		"  Q / E  lean · Shift  sprint · C  crouch · Z  prone · run into low walls to vault\n" + \
		"  R  reload · G  grenade · V  smoke · 1–5  rifle, machine gun, sniper, shotgun, rockets\n" + \
		"  F  take the gun (or ammo) of a fallen soldier at your feet · stand at an ammo crate to restock\n" + \
		"  B  class action (engineer: sandbags/repair · medic: heal · radio: artillery on crosshair · sniper/spotter: mark target)\n" + \
		"  N  place a mine (Shift+N anti-tank) · K  satchel charge · 1–9  rifle, MG, sniper, shotgun, rockets, SMG, pistol, flamethrower, AT rifle\n" + \
		"  Y  first-person / third-person view · L  fire a flare · Esc  free the mouse · X  leave the soldier\n" + \
		"  U (hold)  help build a friendly construction site · I  dismantle what you aim at (within 6 m)\n" + \
		"  F  next to a vehicle: get in · in a vehicle: WASD drive, mouse aim, click fire, 1–4 change seat, F get out\n\n" + \
		"BATTLE\n" + \
		"  Squad leaders carry a radio antenna. Soldiers who lose friends, their leader or come under heavy fire\n" + \
		"  get shaken, and may break and run to the rear until a leader rallies them.\n" + \
		"  Bullets go through thin walls, crates and hedges. Every building can be blown apart. J  battle report\n" + \
		"  Engineers build FOBs, nests, bunkers and more piece by piece (Build tab to mark out sites).\n" + \
		"  Reinforcements arrive at your HQ or FOBs: lose them all and nobody new comes until you build a FOB."
	var l = _label(t, 14, Color(0.88, 0.88, 0.88))
	v.add_child(l)
	v.add_child(_button("Close", func(): help.visible = false))
	help.add_child(v)
	help.visible = false
	root.add_child(help)

func _build_win() -> void:
	win = _panel(Color(0.11, 0.13, 0.15, 0.97))
	_place(win, Control.PRESET_CENTER, -220, -90, 440, 180)
	win.custom_minimum_size = Vector2(440, 0)
	var v = VBoxContainer.new()
	win_title = _label("Victory", 28)
	win_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(win_title)
	var h = HBoxContainer.new()
	h.add_child(_button("Play again", func():
		win.visible = false
		_deploy()))
	h.add_child(_button("Keep fighting", func():
		G.mode = "sandbox"
		G.over = false
		win.visible = false))
	h.add_child(_button("Battle report", func(): show_report()))
	h.add_child(_button("Main menu", func():
		win.visible = false
		show_menu()))
	v.add_child(h)
	win.add_child(v)
	win.visible = false
	root.add_child(win)

func show_win(team: int) -> void:
	win_title.text = "%s wins" % G.TEAM_NAMES[team]
	win_title.add_theme_color_override("font_color", G.TEAM_BAND[team].lightened(0.3))
	if team == 1 and G.mode == "laststand":
		win_title.text = "Overrun after %d wave%s" % [Obj.wave, "" if Obj.wave == 1 else "s"]
		win_title.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5))
	win.visible = true

func menu_open() -> bool:
	return menu.visible or help.visible or win.visible or (report != null and report.visible) or (teams_panel != null and teams_panel.visible) or (settings_panel != null and settings_panel.visible)

func typing() -> bool:
	return false

# ---------------------------------------------------------------- per-frame
func _unhandled_key_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode == KEY_M and G.started:
			show_menu()
		elif ev.keycode == KEY_H:
			help.visible = not help.visible
		elif ev.keycode == KEY_J and G.started:
			if report != null and report.visible:
				report.visible = false
			else:
				show_report()
		elif ev.keycode == KEY_ESCAPE and G.started and G.player == null:
			menu.visible = false
			help.visible = false

func update_hud(dt: float) -> void:
	if vignette != null:
		var want = 0.0
		if G.player != null and is_instance_valid(G.player) and G.player.state != "dead":
			want = clampf(G.player.supp / 1.2, 0.0, 1.0) * 0.85 + (0.35 if G.player.hp < 35.0 else 0.0)
		var m: ShaderMaterial = vignette.material
		var cv = m.get_shader_parameter("amount")
		var cur: float = cv if cv != null else 0.0
		m.set_shader_parameter("amount", lerpf(cur, want, minf(1.0, dt * 5.0)))
	var cap = G.mode == "capture"
	var tick = G.mode == "frontline"
	lbl_sa.text = str(int(G.cap_score[0])) if cap else (str(Obj.tickets[0]) if tick and not Obj.tickets.is_empty() else str(G.score[0]))
	lbl_sb.text = str(int(G.cap_score[1])) if cap else (str(Obj.tickets[1]) if tick and not Obj.tickets.is_empty() else str(G.score[1]))
	var t = int(G.game_time)
	lbl_clock.text = "%02d:%02d" % [t / 60, t % 60]
	if get_tree().paused:
		lbl_mode.text = "paused"
	elif Engine.time_scale < 0.5:
		lbl_mode.text = "slow-mo"
	elif G.mode == "sandbox":
		lbl_mode.text = "sandbox"
	elif cap:
		lbl_mode.text = "capture · %d" % G.limit
	elif G.mode == "deathmatch":
		lbl_mode.text = "first to %d" % G.limit
	else:
		lbl_mode.text = Obj.status_text()
	lbl_a.text = "%d alive" % G.alive_count(0)
	lbl_b.text = "%d alive" % G.alive_count(1)
	lbl_na.text = G.TEAM_NAMES[0].to_upper()
	lbl_nb.text = G.TEAM_NAMES[1].to_upper()
	_tint(pa_panel, G.TEAM_BAND[0].darkened(0.2))
	_tint(pb_panel, G.TEAM_BAND[1].darkened(0.2))
	var more = []
	for ti in range(2, G.team_count()):
		more.append("%s  %d  (%d alive)" % [G.TEAM_NAMES[ti], int(G.cap_score[ti]) if cap else G.score[ti], G.alive_count(ti)])
	lbl_more.text = "   ·   ".join(more)
	lbl_more.visible = G.started and not more.is_empty()
	var pts = Obj.points
	cap_box.visible = Obj.uses_points() and G.started and not pts.is_empty()
	if cap_box.visible:
		while points_box.get_child_count() < pts.size():
			var l = _label("", 15)
			l.custom_minimum_size = Vector2(26, 0)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			points_box.add_child(l)
		while points_box.get_child_count() > pts.size():
			var c = points_box.get_child(points_box.get_child_count() - 1)
			points_box.remove_child(c)
			c.queue_free()
		var blink = int(Time.get_ticks_msec() / 300) % 2 == 0
		for i in range(pts.size()):
			var pt = pts[i]
			var l = points_box.get_child(i)
			l.text = "[%s]" % pt["name"]
			var col = Color(0.85, 0.85, 0.85) if pt["owner"] < 0 else G.TEAM_BAND[pt["owner"]].lightened(0.25)
			if pt["contested"] and blink:
				col = Color(1.0, 0.85, 0.3)
			l.add_theme_color_override("font_color", col)
		var focus = pts[0]
		if G.player != null and is_instance_valid(G.player):
			var bd = 1e9
			for pt in pts:
				var d = G.dist2d(pt["p"], G.player.pos)
				if d < bd:
					bd = d
					focus = pt
		elif pts.size() > 1:
			focus = pts[Obj.front(0)]
		cap_bar.value = focus["prog"]
		if focus["contested"]:
			cap_lbl.text = "Point %s contested" % focus["name"]
		elif focus["owner"] >= 0:
			cap_lbl.text = "Point %s held by %s" % [focus["name"], G.TEAM_NAMES[focus["owner"]]]
		else:
			cap_lbl.text = "Point %s neutral" % focus["name"]
	var show_game = G.started
	top_bar.visible = show_game
	side.visible = show_game
	var ctl = G.player != null
	tabs_box.visible = show_game and not ctl
	tool_box.visible = show_game and not ctl
	phud.visible = ctl
	cmd_panel.visible = show_game and not ctl and tab == "command"
	if ctl:
		var s = G.player
		var st = ""
		match s.state:
			"dead": st = " — KIA"
			"down": st = " — knocked down"
			"getup": st = " — getting up"
			"wounded": st = " — wounded"
			_:
				if s.reload_t > 0.0: st = " — reloading"
				elif s.prone: st = " — prone"
				elif s.p_crouch: st = " — crouched"
		p_name.text = "%s  ·  %s  ·  %s%s" % [s.sname, G.CLASSES.get(s.cls, {"name": "?"})["name"], s.W["name"], st]
		p_hp.value = maxf(0.0, s.hp)
		p_ammo.text = "%d | %d     grenades %d · smoke %d" % [s.mag, s.reserve, s.grenades, s.smokes]
		if s.rgren > 0:
			p_ammo.text += " · rifle grenades %d (middle mouse)" % s.rgren
		if s.stickies > 0:
			p_ammo.text += " · sticky bombs %d (Shift+K)" % s.stickies
		if s.W["id"] == "lmg":
			p_ammo.text += " · barrel %d%%" % int(s.heat * 100.0)
		if s.cls == "engineer":
			p_ammo.text += " · sandbags %d · mines %d · satchels %d" % [s.kits, s.mines, s.satchels]
		if s.resupply_t > 0.0:
			p_ammo.text += "     resupplying…"
		tip.text = "" if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else "Click to aim — X to leave this soldier"
	else:
		tip.text = TIPS.get(tool, "") if show_game else ""
		if show_game and tab == "support" and not Support.points.is_empty():
			tip.text = "Supply points: %d  (earned over time, for kills and for capturing points) · click a call-in, then the map for strikes" % Support.points[0]
		elif show_game and tool.begins_with("v:"):
			tip.text = "Click the ground to drop this vehicle with its crew"
		elif show_game and tool.begins_with("b:"):
			tip.text = "Click to mark out a %s site for %s — their engineers will come and build it" % [Build.KINDS[tool.substr(2)]["name"], G.TEAM_NAMES[build_team] if build_team < G.TEAM_NAMES.size() else "?"]
	scope.visible = ctl and G.player.ads and G.player.wid == "sniper" and G.pc.cam.fov < 24.0
	cross.queue_redraw()
	if hit_t > 0.0:
		hit_t -= dt
		if hit_t <= 0.0:
			hitmark.visible = false
	for i in range(dmg_list.size() - 1, -1, -1):
		dmg_list[i]["t"] -= dt
		if dmg_list[i]["t"] <= 0.0:
			dmg_list.remove_at(i)
	dmg.queue_redraw()
	if msg_t > 0.0:
		msg_t -= dt
		if msg_t <= 0.0:
			msg.text = ""

# ---------------------------------------------------------------- after-action report
func _build_report() -> void:
	report = _panel(Color(0.09, 0.11, 0.13, 0.97))
	_place(report, Control.PRESET_CENTER, -430, -300, 860, 600)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(840, 580)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	report_body = VBoxContainer.new()
	report_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(report_body)
	report.add_child(scroll)
	report.visible = false
	root.add_child(report)

func _cell(text: String, w: float, col: Color = Color(0.85, 0.87, 0.88), size: int = 14) -> Label:
	var l = _label(text, size, col)
	l.custom_minimum_size = Vector2(w, 0)
	l.clip_text = true
	return l

func show_report() -> void:
	if report == null:
		_build_report()
	for c in report_body.get_children():
		report_body.remove_child(c)
		c.queue_free()
	var t = int(G.game_time)
	var head = HBoxContainer.new()
	head.add_child(_label("After-action report", 24))
	var sp = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(_button("Close (J)", func(): report.visible = false))
	report_body.add_child(head)
	var map_name = G.world.MAPS.get(G.map_id, {}).get("name", G.map_id)
	report_body.add_child(_label("%s · %s · %02d:%02d of fighting" % [map_name, G.mode, t / 60, t % 60], 14, Color(0.7, 0.72, 0.74)))
	# team summary
	var grid = GridContainer.new()
	grid.columns = 1 + G.team_count()
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_child(_cell("", 170))
	for ti in range(G.team_count()):
		grid.add_child(_cell(G.TEAM_NAMES[ti], 150, G.TEAM_BAND[ti].lightened(0.35), 16))
	var rows = [["Soldiers deployed", "spawned"], ["Killed in action", "deaths"], ["Enemies killed", "kills"], ["Headshots", "heads"],
		["Shots fired", "shots"], ["Accuracy", "acc"], ["Times a soldier broke and ran", "routs"], ["Friendly-fire kills", "teamkills"]]
	for r in rows:
		grid.add_child(_cell(r[0], 170, Color(0.7, 0.72, 0.74)))
		for ti in range(G.team_count()):
			var d = Stats.teams[ti] if ti < Stats.teams.size() else {}
			var v = ""
			if r[1] == "acc":
				v = "%d%%" % int(100.0 * d.get("hits", 0) / maxf(1.0, d.get("shots", 0)))
			else:
				v = str(int(d.get(r[1], 0)))
			grid.add_child(_cell(v, 150))
	report_body.add_child(grid)
	# strength over time
	report_body.add_child(_label("Soldiers alive over time", 16))
	report_chart = Control.new()
	report_chart.custom_minimum_size = Vector2(820, 140)
	report_chart.draw.connect(_draw_report_chart)
	report_body.add_child(report_chart)
	# best performers
	var m = Stats.mvp()
	if m != null:
		report_body.add_child(_label("Most valuable soldier: %s (%s, %s) — %d kills, %d damage dealt%s" % [m["name"], G.TEAM_NAMES[m["team"]], m["weapon"], m["kills"], int(m["dmg"]), (", %d wounded treated" % m["heals"]) if m["heals"] > 0 else ""], 15, Color(1.0, 0.86, 0.45)))
	var you = []
	for r in Stats.roster:
		if r["player"]:
			you.append(r)
	if not you.is_empty():
		var k = 0
		var h = 0
		var sh = 0
		for r in you:
			k += r["kills"]
			h += r["hits"]
			sh += r["shots"]
		report_body.add_child(_label("You controlled %d soldier%s: %d kills, %d%% accuracy" % [you.size(), "" if you.size() == 1 else "s", k, int(100.0 * h / maxf(1.0, sh))], 15, Color(0.6, 0.85, 1.0)))
	for ti in range(G.team_count()):
		report_body.add_child(_label("Top soldiers · " + G.TEAM_NAMES[ti], 16, G.TEAM_BAND[ti].lightened(0.35)))
		var list = Stats.roster.filter(func(r): return r["team"] == ti)
		list.sort_custom(func(a, b): return a["kills"] * 100.0 + a["dmg"] > b["kills"] * 100.0 + b["dmg"])
		var tg = GridContainer.new()
		tg.columns = 7
		for hdr in [["Name", 150], ["Weapon", 120], ["Kills", 60], ["Damage", 70], ["Accuracy", 80], ["Status", 160], ["", 120]]:
			tg.add_child(_cell(hdr[0], hdr[1], Color(0.6, 0.62, 0.64), 13))
		for i in range(mini(6, list.size())):
			var r = list[i]
			var status = "alive"
			if r["death_t"] >= 0.0:
				var dt_ = int(r["death_t"])
				status = "killed at %02d:%02d" % [dt_ / 60, dt_ % 60]
			var notes = []
			if r["leader"]:
				notes.append("leader")
			if r["player"]:
				notes.append("you")
			if r["routs"] > 0:
				notes.append("ran %dx" % r["routs"])
			tg.add_child(_cell(r["name"], 150))
			tg.add_child(_cell(r["weapon"], 120))
			tg.add_child(_cell(str(r["kills"]), 60))
			tg.add_child(_cell(str(int(r["dmg"])), 70))
			tg.add_child(_cell("%d%%" % int(100.0 * r["hits"] / maxf(1.0, r["shots"])), 80))
			tg.add_child(_cell(status, 160))
			tg.add_child(_cell(", ".join(notes), 120, Color(0.75, 0.75, 0.6)))
		report_body.add_child(tg)
	report.visible = true

func _draw_report_chart() -> void:
	var c = report_chart
	var w = c.size.x
	var h = c.size.y
	c.draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, 0.04))
	var tl = Stats.timeline
	if tl.size() < 2:
		c.draw_string(ThemeDB.fallback_font, Vector2(10, h / 2.0), "Not enough time has passed yet", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.6, 0.6, 0.6))
		return
	var t0 = tl[0][0]
	var t1 = maxf(tl[tl.size() - 1][0], t0 + 1.0)
	var top = 1.0
	for e in tl:
		for v in e[1]:
			top = maxf(top, v)
	for ti in range(G.team_count()):
		var pts = PackedVector2Array()
		for e in tl:
			if ti < e[1].size():
				pts.append(Vector2((e[0] - t0) / (t1 - t0) * (w - 10.0) + 5.0, h - 6.0 - e[1][ti] / top * (h - 16.0)))
		if pts.size() > 1:
			c.draw_polyline(pts, G.TEAM_BAND[ti].lightened(0.2), 2.0, true)

# ---------------------------------------------------------------- team customisation
func _show_teams() -> void:
	if teams_panel != null:
		teams_panel.queue_free()
	teams_panel = _panel(Color(0.1, 0.12, 0.14, 0.98))
	_place(teams_panel, Control.PRESET_CENTER, -330, -210, 660, 420)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.add_child(_label("Teams", 26))
	v.add_child(_label("Name each side, pick its armband colour and its uniform. Teams 3 and 4 only fight when you choose 3 or 4 sides.", 13, Color(0.75, 0.75, 0.75)))
	var bands = G.BANDS.keys()
	var unis = G.UNIFORMS.keys()
	for i in range(4):
		var c = G.team_cfg[i]
		var h = HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var sw = ColorRect.new()
		sw.custom_minimum_size = Vector2(22, 22)
		sw.color = G.BANDS.get(c["band"], Color.WHITE)
		h.add_child(sw)
		var name_e = LineEdit.new()
		name_e.text = c["name"]
		name_e.max_length = 14
		name_e.custom_minimum_size = Vector2(170, 0)
		name_e.text_changed.connect(func(t): c["name"] = t)
		h.add_child(name_e)
		var ob = _option(bands, maxi(0, bands.find(c["band"])))
		ob.item_selected.connect(func(k):
			c["band"] = bands[k]
			sw.color = G.BANDS[bands[k]])
		h.add_child(ob)
		var ou = _option(unis, maxi(0, unis.find(c["uniform"])))
		ou.item_selected.connect(func(k): c["uniform"] = unis[k])
		h.add_child(ou)
		v.add_child(h)
	var b = HBoxContainer.new()
	b.add_child(_button("Done", func():
		G.apply_teams()
		G.save_prefs()
		teams_panel.visible = false))
	v.add_child(b)
	teams_panel.add_child(v)
	root.add_child(teams_panel)

# ---------------------------------------------------------------- settings
func _show_settings() -> void:
	if settings_panel != null:
		settings_panel.queue_free()
	settings_panel = _panel(Color(0.1, 0.12, 0.14, 0.98))
	_place(settings_panel, Control.PRESET_CENTER, -240, -200, 480, 400)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.add_child(_label("Settings", 26))
	var vol = HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = G.settings["volume"]
	vol.custom_minimum_size = Vector2(220, 0)
	vol.value_changed.connect(func(x):
		G.settings["volume"] = x
		G.audio.set_volume(x))
	_row(v, "Volume", vol)
	var sens = HSlider.new()
	sens.min_value = 0.2
	sens.max_value = 3.0
	sens.step = 0.1
	sens.value = G.settings["sens"]
	sens.custom_minimum_size = Vector2(220, 0)
	sens.value_changed.connect(func(x): G.settings["sens"] = x)
	_row(v, "Mouse sensitivity", sens)
	for item in [["invert_y", "Invert mouse Y"], ["blood", "Blood and bullet holes"], ["callouts", "Soldier callouts"], ["shadows", "Shadows"], ["grass", "Grass (next battle)"]]:
		var key = item[0]
		var cb = CheckBox.new()
		cb.button_pressed = G.settings[key]
		cb.focus_mode = Control.FOCUS_NONE
		cb.toggled.connect(func(on):
			G.settings[key] = on
			if key == "shadows":
				G.main.apply_time())
		_row(v, item[1], cb)
	v.add_child(_button("Done", func():
		G.save_prefs()
		settings_panel.visible = false))
	settings_panel.add_child(v)
	root.add_child(settings_panel)

# ---------------------------------------------------------------- command panel
var cmd_panel: PanelContainer = null
var sel_rect: ColorRect = null

func _build_command() -> void:
	sel_rect = ColorRect.new()
	sel_rect.color = Color(1.0, 0.85, 0.25, 0.15)
	sel_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sel_rect.visible = false
	root.add_child(sel_rect)
	cmd_panel = _panel(Color(0.1, 0.12, 0.14, 0.9))
	_place(cmd_panel, Control.PRESET_TOP_RIGHT, -300, 290, 290, 260)
	var v = VBoxContainer.new()
	v.add_child(_label("Orders", 16))
	for ti in range(2):
		var h = HBoxContainer.new()
		var nm = _label(G.TEAM_NAMES[ti], 13, G.team_color(ti).lightened(0.4))
		nm.custom_minimum_size = Vector2(56, 0)
		h.add_child(nm)
		for m in [["free", "Free"], ["hold", "Hold"], ["charge", "Charge"]]:
			var mode = m[0]
			var team = ti
			h.add_child(_button(m[1], func():
				G.orders[team] = {"mode": mode, "point": null}
				for s in G.soldiers:
					if s.team == team:
						s.decide_t = 0.0
				message("%s: %s" % [G.TEAM_NAMES[team], {"free": "act on your own", "hold": "hold your ground", "charge": "charge!"}[mode]])))
		v.add_child(h)
	v.add_child(_label("Selected soldiers", 13, Color(0.75, 0.75, 0.75)))
	var h2 = HBoxContainer.new()
	for m in [["free", "Free"], ["hold", "Hold"], ["charge", "Charge"]]:
		var mode = m[0]
		h2.add_child(_button(m[1], func(): G.pc.order_selected(mode)))
	h2.add_child(_button("Clear", func(): G.pc.clear_selection()))
	v.add_child(h2)
	var h3 = HBoxContainer.new()
	h3.add_child(_label("Formation", 12, Color(0.75, 0.75, 0.75)))
	for f in [["wedge", "Wedge"], ["line", "Line"], ["column", "Column"], ["auto", "Auto"]]:
		var form = f[0]
		h3.add_child(_button(f[1], func(): G.pc.set_formation(form)))
	v.add_child(h3)
	cmd_panel.add_child(v)
	root.add_child(cmd_panel)

func sel_box_changed() -> void:
	if sel_rect == null:
		return
	var a = G.pc.drag_from
	if a == null:
		sel_rect.visible = false
		return
	var b: Vector2 = G.pc.drag_to
	sel_rect.visible = a.distance_to(b) > 6.0
	sel_rect.position = Vector2(minf(a.x, b.x), minf(a.y, b.y))
	sel_rect.size = (a - b).abs()

# ---------------------------------------------------------------- custom maps in the menu
var custom_names: Array = []

func refresh_maps() -> void:
	if opt_map == null:
		return
	var sel = opt_map.selected
	while opt_map.item_count > MAP_IDS.size():
		opt_map.remove_item(opt_map.item_count - 1)
	custom_names = G.editor.list_maps() if G.editor != null else []
	for n in custom_names:
		opt_map.add_item("Your map: " + n)
	if sel < opt_map.item_count:
		opt_map.select(sel)

func _map_id(i: int) -> String:
	if i < MAP_IDS.size():
		return MAP_IDS[i]
	var m = G.editor.load_file(custom_names[i - MAP_IDS.size()])
	if m.is_empty():
		return "town"
	G.custom_map = m
	return "custom"

func _select_map(i: int) -> void:
	G.main.preview_map(_map_id(i))

# ---------------------------------------------------------------- radio chatter
var radio_box: VBoxContainer = null

func radio(team: int, text: String) -> void:
	if radio_box == null:
		radio_box = VBoxContainer.new()
		_place(radio_box, Control.PRESET_BOTTOM_LEFT, 12, -330, 420, 180)
		radio_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		radio_box.alignment = BoxContainer.ALIGNMENT_END
		root.add_child(radio_box)
	var l = _label("📻 " + G.TEAM_NAMES[team] + ": " + text if team >= 0 else "📻 " + text, 12, G.team_color(team).lightened(0.5) if team >= 0 else Color(0.9, 0.9, 0.8))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(410, 0)
	radio_box.add_child(l)
	while radio_box.get_child_count() > 6:
		var c = radio_box.get_child(0)
		radio_box.remove_child(c)
		c.queue_free()
	var wr = weakref(l)
	get_tree().create_timer(12.0).timeout.connect(func():
		var n = wr.get_ref()
		if n != null:
			n.queue_free())
