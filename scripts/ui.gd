extends CanvasLayer
# HUD, tool bar, menus. Built in code so the project has no scene files to keep in sync.

var tool = "ctl"
var tab = "units"
const TOOLS = {
	"units": [["a1", "Alpha soldier"], ["b1", "Bravo soldier"], ["a5", "Alpha squad"], ["b5", "Bravo squad"], ["ctl", "Take control"], ["spA", "Alpha spawn"], ["spB", "Bravo spawn"]],
	"fun": [["boom", "Explosion"], ["mortar", "Mortar strike"], ["smoke", "Smoke"], ["push", "Shove"]],
}
const TIPS = {"a1": "Click the ground to drop in an Alpha soldier", "b1": "Click the ground to drop in a Bravo soldier",
	"a5": "Click to drop in five Alpha soldiers", "b5": "Click to drop in five Bravo soldiers",
	"ctl": "Click a soldier to take control of them (or press F)", "spA": "Click to move where Alpha reinforcements arrive",
	"spB": "Click to move where Bravo reinforcements arrive", "boom": "Click anywhere to set off an explosion",
	"mortar": "Click to call in a mortar barrage", "smoke": "Click to drop a smoke screen", "push": "Click a soldier to shove them over"}

var root: Control
var lbl_a: Label
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
var menu: PanelContainer
var help: PanelContainer
var win: PanelContainer
var win_title: Label
var opt_map: OptionButton
var opt_mode: OptionButton
var opt_size: OptionButton
var opt_limit: OptionButton
var chk_reinf: CheckBox

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
	var pa = _panel(Color(0.11, 0.31, 0.72))
	var va = VBoxContainer.new()
	va.add_child(_label("ALPHA SQUAD", 14))
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
	var pb = _panel(Color(0.71, 0.14, 0.14))
	var vb = VBoxContainer.new()
	vb.add_child(_label("BRAVO SQUAD", 14))
	lbl_b = _label("0 alive", 11)
	vb.add_child(lbl_b)
	pb.add_child(vb)
	top_bar.add_child(pb)
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
	cap_box.add_child(cap_lbl)
	cap_box.add_child(cap_bar)
	cap_box.visible = false
	root.add_child(cap_box)

func feed(a, v, head: bool) -> void:
	var t = ""
	if a != null:
		t = "%s  [%s]  %s%s" % [a.sname, a.W["name"], v.sname, "  ✦" if head else ""]
		if a.team == v.team and a != v:
			t += " (friendly)"
	else:
		t = "%s ✖" % v.sname
	var l = _label(t, 13, Color(0.6, 0.75, 1.0) if (a != null and a.team == 0) or (a == null and v.team == 0) else Color(1.0, 0.65, 0.65))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	feed_box.add_child(l)
	feed_box.move_child(l, 0)
	while feed_box.get_child_count() > 7:
		var last = feed_box.get_child(feed_box.get_child_count() - 1)
		feed_box.remove_child(last)
		last.queue_free()
	get_tree().create_timer(6.0).timeout.connect(func():
		if is_instance_valid(l):
			l.queue_free())

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
	side.add_child(_button("Controls (H)", func(): help.visible = true))

# ---------------------------------------------------------------- tool bar
func _build_tools() -> void:
	tabs_box = HBoxContainer.new()
	_place(tabs_box, Control.PRESET_CENTER_BOTTOM, -90, -96, 180, 32)
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
	for t in [["units", "Units"], ["fun", "Effects"]]:
		var key = t[0]
		var b = _button(t[1], func():
			tab = key
			tool = TOOLS[key][0][0]
			_render_tools())
		if tab == key:
			b.modulate = Color(1.0, 0.85, 0.3)
		tabs_box.add_child(b)
	var i = 1
	for t in TOOLS[tab]:
		var id = t[0]
		var b2 = _button("%d  %s" % [i, t[1]], func():
			tool = id
			_render_tools())
		if tool == id:
			b2.modulate = Color(1.0, 0.85, 0.3)
		tool_box.add_child(b2)
		i += 1
	tool_box.offset_left = -TOOLS[tab].size() * 66.0
	tool_box.offset_right = TOOLS[tab].size() * 66.0
	tip.text = TIPS.get(tool, "")

func pick_tool(i: int) -> void:
	if i < TOOLS[tab].size():
		tool = TOOLS[tab][i][0]
		_render_tools()

# ---------------------------------------------------------------- crosshair, hit marker, damage arrows, scope, messages
func _build_center() -> void:
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
	_place(menu, Control.PRESET_CENTER, -260, -230, 520, 460)
	menu.custom_minimum_size = Vector2(520, 0)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.add_child(_label("Ragdoll Front", 30))
	var d = _label("Two squads fight it out on their own. Drop in soldiers, call in strikes, or take control of anyone on the field.", 14, Color(0.8, 0.8, 0.8))
	d.autowrap_mode = TextServer.AUTOWRAP_WORD
	d.custom_minimum_size = Vector2(480, 0)
	v.add_child(d)
	opt_map = _option(["Town ruins", "Farmland", "Trenches"], 0)
	opt_map.item_selected.connect(func(i):
		if not G.started:
			G.main.preview_map(["town", "field", "trenches"][i]))
	_row(v, "Map", opt_map)
	opt_mode = _option(["Sandbox — endless", "Team deathmatch", "Capture the point"], 0)
	_row(v, "Mode", opt_mode)
	opt_limit = _option(["25", "50", "100"], 1)
	_row(v, "Kills / points to win", opt_limit)
	opt_size = _option(["5", "8", "10", "15", "20"], 2)
	_row(v, "Soldiers per team", opt_size)
	chk_reinf = CheckBox.new()
	chk_reinf.button_pressed = true
	chk_reinf.focus_mode = Control.FOCUS_NONE
	_row(v, "Reinforcements", chk_reinf)
	var go = _button("Deploy", func(): _deploy())
	go.custom_minimum_size = Vector2(0, 44)
	go.add_theme_font_size_override("font_size", 20)
	v.add_child(go)
	var h = HBoxContainer.new()
	h.add_child(_button("Controls", func(): help.visible = true))
	h.add_child(_button("Quit", func(): get_tree().quit()))
	v.add_child(h)
	menu.add_child(v)
	root.add_child(menu)

func _deploy() -> void:
	var maps = ["town", "field", "trenches"]
	var modes = ["sandbox", "deathmatch", "capture"]
	G.main.start_game({"map": maps[opt_map.selected], "mode": modes[opt_mode.selected],
		"size": int(opt_size.get_item_text(opt_size.selected)), "limit": int(opt_limit.get_item_text(opt_limit.selected)),
		"reinforce": chk_reinf.button_pressed})
	menu.visible = false
	help.visible = false

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
		"  Right-drag  look around · Left-click  use the selected tool · 1–7  pick a tool\n" + \
		"  F  take control of the soldier at the centre of the screen\n" + \
		"  T  slow-mo · P  pause · M  menu\n\n" + \
		"CONTROLLING A SOLDIER\n" + \
		"  Mouse  aim · Left-click  fire · Right mouse  aim down sights\n" + \
		"  Q / E  lean · Shift  sprint · C  crouch · Z  prone · run into low walls to vault\n" + \
		"  R  reload · G  grenade · V  smoke · 1–5  rifle, machine gun, sniper, shotgun, rockets\n" + \
		"  Esc  free the mouse · X  leave the soldier"
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
	h.add_child(_button("Main menu", func():
		win.visible = false
		show_menu()))
	v.add_child(h)
	win.add_child(v)
	win.visible = false
	root.add_child(win)

func show_win(team: int) -> void:
	win_title.text = "%s squad wins" % G.TEAM_NAMES[team]
	win_title.add_theme_color_override("font_color", G.TEAM_BAND[team].lightened(0.3))
	win.visible = true

func menu_open() -> bool:
	return menu.visible or help.visible or win.visible

func typing() -> bool:
	return false

# ---------------------------------------------------------------- per-frame
func _unhandled_key_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode == KEY_M and G.started:
			show_menu()
		elif ev.keycode == KEY_H:
			help.visible = not help.visible
		elif ev.keycode == KEY_ESCAPE and G.started and G.player == null:
			menu.visible = false
			help.visible = false

func update_hud(dt: float) -> void:
	var cap = G.mode == "capture"
	lbl_sa.text = str(int(G.cap_score[0])) if cap else str(G.score[0])
	lbl_sb.text = str(int(G.cap_score[1])) if cap else str(G.score[1])
	var t = int(G.game_time)
	lbl_clock.text = "%02d:%02d" % [t / 60, t % 60]
	if get_tree().paused:
		lbl_mode.text = "paused"
	elif Engine.time_scale < 0.5:
		lbl_mode.text = "slow-mo"
	elif G.mode == "sandbox":
		lbl_mode.text = "sandbox"
	else:
		lbl_mode.text = ("capture · %d" if cap else "first to %d") % G.limit
	lbl_a.text = "%d alive" % G.alive_count(0)
	lbl_b.text = "%d alive" % G.alive_count(1)
	cap_box.visible = cap and G.started
	if cap:
		cap_bar.value = G.cap_prog
		if G.cap_contested:
			cap_lbl.text = "Objective contested"
		elif G.cap_owner >= 0:
			cap_lbl.text = "Objective held by " + G.TEAM_NAMES[G.cap_owner]
		else:
			cap_lbl.text = "Objective neutral"
	var show_game = G.started
	top_bar.visible = show_game
	side.visible = show_game
	var ctl = G.player != null
	tabs_box.visible = show_game and not ctl
	tool_box.visible = show_game and not ctl
	phud.visible = ctl
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
		p_name.text = "%s  ·  %s%s" % [s.sname, s.W["name"], st]
		p_hp.value = maxf(0.0, s.hp)
		p_ammo.text = "%d / %d     grenades %d · smoke %d" % [s.mag, s.W["mag"], s.grenades, s.smokes]
		tip.text = "" if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else "Click to aim — X to leave this soldier"
	else:
		tip.text = TIPS.get(tool, "") if show_game else ""
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
