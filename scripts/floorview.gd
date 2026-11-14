class_name FloorView
extends Control
# In a building with floors: pick a floor and everything above it is lifted off, so you look straight
# down into its rooms and corridors. Men on the floors above are hidden too, and shown instead as small
# markers with their floor number, so you can still tell what's going on up there. Page Up / Page Down,
# or the buttons on the right. While you're in control of a man inside, it follows his floor.

var panel: VBoxContainer
var btns: Array = []       # index 0: whole building; i: floor i - 1
var t = 0.0
var shown = -1             # the floor actually being shown right now (the auto one included)
var hid: Array = []        # soldiers this hid

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel = VBoxContainer.new()
	panel.add_theme_constant_override("separation", 3)
	panel.custom_minimum_size = Vector2(200, 0)
	add_child(panel)
	var head = Label.new()
	head.text = "FLOORS  ·  PgUp / PgDn"
	head.add_theme_font_size_override("font_size", Hud.SIZE_SMALL)
	head.add_theme_color_override("font_color", Hud.MUTED)
	panel.add_child(head)
	visible = false

func _rebuild() -> void:
	# (each entry is [button, floor]: freeing the entry itself did nothing, so every new battle in the
	# building added another set of buttons under the old ones)
	for b in btns:
		if is_instance_valid(b[0]):
			panel.remove_child(b[0])
			b[0].queue_free()
	btns = []
	var labels = ["Whole building"]
	for k in range(Levels.n - 1, -1, -1):
		labels.append(Levels.names[k])
	for i in range(labels.size()):
		var b = Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", Hud.SIZE_BODY)
		b.custom_minimum_size = Vector2(200, 26)
		var floor_k = -1 if i == 0 else Levels.n - i
		b.pressed.connect(func(): pick(floor_k))
		panel.add_child(b)
		btns.append([b, floor_k])

# show floor k (-1: the whole building, roof on)
func pick(k: int) -> void:
	Levels.view = k
	t = 0.0
	if k >= 0:
		G.ui.message("Looking at the %s" % Levels.names[k].to_lower())

func step_floor(d: int) -> void:
	if not Levels.on:
		return
	var k = Levels.view
	if k < 0:
		k = Levels.n if d < 0 else -1
	k += d
	if k >= Levels.n:
		k = -1
	elif k < -1:
		k = Levels.n - 1
	pick(clampi(k, -1, Levels.n - 1))

func _process(dt: float) -> void:
	var want = Levels.on and G.started and not G.over
	if want != visible:
		visible = want
		if want:
			_rebuild()
		else:
			_unhide_all()
	if not visible:
		return
	# right-hand side, a little above the middle (placed by hand: the HUD root has no size to anchor to)
	var vs = get_viewport_rect().size
	var py = vs.y * 0.5 - 170.0
	# (in command of a battle the map and the alerts are up there too: the floors go underneath them)
	var ch = G.ui.cmdhud
	if ch != null and is_instance_valid(ch) and ch.active():
		py = maxf(py, ch.alerts_box.position.y + (ch.alerts_box.get_combined_minimum_size().y if ch.alerts_box.get_child_count() > 0 else 0.0) + 8.0)
	panel.position = Vector2(vs.x - 214.0, py)
	t -= dt
	if t > 0.0:
		queue_redraw()
		return
	t = 0.1
	shown = Levels.view
	var p = G.player
	if p != null and is_instance_valid(p) and p.state == "alive" and Levels.inside(p.pos, 0.3) and not G.pc.force_free:
		shown = Levels.level_of(p.pos)
	# men on hidden floors
	var top = Levels.floor_y(shown) + Levels.FH - 0.8 if shown >= 0 else 1e9
	var now_hid: Array = []
	for s in G.soldiers:
		if not is_instance_valid(s):
			continue
		var above = shown >= 0 and Levels.inside(s.pos, 0.4) and s.pos.y > top
		if above:
			if s.visible:
				s.visible = false
			s.set_meta("fv_hid", true)
			now_hid.append(s)
		elif s.has_meta("fv_hid"):
			s.remove_meta("fv_hid")
			s.visible = not s.hidden_in_vehicle and not Fog.hidden(s)
	hid = now_hid
	# the buttons: which is on, and how many of yours and how many seen enemies are on each floor
	var mine = []
	var theirs = []
	for k in range(Levels.n):
		mine.append(0)
		theirs.append(0)
	for s in G.soldiers:
		if not is_instance_valid(s) or s.state != "alive" or not Levels.inside(s.pos, 0.3):
			continue
		var k2 = Levels.level_of(s.pos)
		if s.team == 0:
			mine[k2] += 1
		elif not Fog.hidden(s):
			theirs[k2] += 1
	for e in btns:
		var b: Button = e[0]
		var k3: int = e[1]
		var on = k3 == shown
		var txt = Levels.names[k3] if k3 >= 0 else "Whole building"
		if k3 >= 0:
			txt += "   %d" % mine[k3] + (" · %d enemy" % theirs[k3] if theirs[k3] > 0 else "")
		b.text = ("> " if on else "   ") + txt
		var sb = Hud.pill(Hud.ACCENT.darkened(0.45) if on else Hud.BG_SOFT, Hud.ACCENT if on else Hud.EDGE)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", Hud.pill(Hud.BG, Hud.ACCENT))
		b.add_theme_stylebox_override("pressed", sb)
		b.add_theme_color_override("font_color", Hud.TEXT if on else Hud.MUTED)
		if k3 >= 0 and theirs[k3] > 0 and not on:
			b.add_theme_color_override("font_color", Hud.WARN)
	queue_redraw()

func _unhide_all() -> void:
	for s in G.soldiers:
		if is_instance_valid(s) and s.has_meta("fv_hid"):
			s.remove_meta("fv_hid")
			s.visible = not s.hidden_in_vehicle and not Fog.hidden(s)
	hid = []

# markers for men on the floors above the one shown: a dot in their colour with the floor number
func _draw() -> void:
	if not visible or hid.is_empty():
		return
	var cam = get_viewport().get_camera_3d()
	if cam == null:
		return
	var font = get_theme_default_font()
	var cut = Levels.floor_y(shown) + Levels.FH
	for s in hid:
		if not is_instance_valid(s) or s.state == "dead":
			continue
		if s.team != 0 and Fog.hidden(s):
			continue
		var at = Vector3(s.pos.x, cut, s.pos.z)
		if cam.is_position_behind(at):
			continue
		var sp = cam.unproject_position(at)
		var col: Color = G.team_color(s.team) if G.has_method("team_color") else (Hud.INFO if s.team == 0 else Hud.BAD)
		draw_circle(sp, 5.0, Color(0, 0, 0, 0.55))
		draw_circle(sp, 3.6, Color(col, 0.8))
		draw_string(font, sp + Vector2(6, 4), str(Levels.level_of(s.pos)), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.85))
