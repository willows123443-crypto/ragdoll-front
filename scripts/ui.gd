extends CanvasLayer
# HUD, tool bar, menus. Built in code so the project has no scene files to keep in sync.

var tool = "ctl"
var tab = "units"
const MAP_IDS = ["town", "field", "trenches", "forest", "city", "factory", "office", "beach", "valley", "front", "river", "pass", "huge", "random"]
const TIPS = {"s1": "Click the ground to drop in a soldier", "s5": "Click the ground to drop in five soldiers",
	"sp": "Click where this side's reinforcements should arrive", "mv": "Click a point to send the whole side there",
	"up": "Click a structure to upgrade it: sandbags → concrete wall, MG nest → pillbox, FOB tent → hut",
	"camo": "Click a structure to throw a camouflage net over it (aircraft and artillery won't see it until the enemy gets close)",
	"rep": "Click a damaged structure to have engineers repair it (anything destroyed is gone and has to be built again)",
	"dis": "Click a structure, wall, building piece or emplacement to take it apart",
	"bteam": "Click to change which team the next construction site is for","sel": "Click soldiers, a vehicle or a structure (drag a box for several, Shift adds) · right-click the ground to send them",
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
var tacmap: Control
var lbl_a: Label
var lbl_na: Label
var lbl_nb: Label
var lbl_more: Label
var prep_box: HBoxContainer
var prep_lbl: Label
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
var build_team = 0
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
var mode_title: Label
var mode_rules: Label
var size_lbl: Label
# (assault, last stand, destroy base and king of the hill were too close to frontline/breakthrough, siege,
# commander and capture; they live on in the campaign but aren't offered on their own)
# (only the sandbox, the commander RTS and the zombie horde are offered on their own, with the campaign
# on the title screen; the other battle types live on as campaign missions)
const MODE_IDS = ["sandbox", "commander", "horde"]
var opt_size: OptionButton
var opt_limit: OptionButton
var opt_reinf: OptionButton
var opt_armor: OptionButton
var opt_teams: OptionButton
var opt_fac0: OptionButton
var opt_cmd: OptionButton
var opt_fac1: OptionButton
var opt_time: OptionButton
var seed_edit: LineEdit
var teams_panel: PanelContainer
var settings_panel: PanelContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _theme()
	add_child(root)
	_build_top()
	_build_side()
	_build_tools()
	_build_center()
	_build_player_hud()
	_build_menu()
	_build_title()
	_build_help()
	_build_win()
	_build_command()
	_build_info()
	squad_cards = SquadCards.new()
	root.add_child(squad_cards)
	floor_view = FloorView.new()
	root.add_child(floor_view)
	menu.visible = false
	title.visible = true

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
	sb.set_corner_radius_all(Hud.RADIUS)
	sb.set_border_width_all(1)
	sb.border_color = Hud.EDGE
	sb.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", sb)
	return p

func _button(text: String, cb: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	_juice(b)
	return b

# buttons that answer you: a soft glow when the mouse is on them and a click when pressed
func _juice(b: Button) -> void:
	b.mouse_entered.connect(func():
		var tw = b.create_tween()
		tw.tween_property(b, "self_modulate", Color(1.18, 1.14, 1.05), 0.08))
	b.mouse_exited.connect(func():
		var tw = b.create_tween()
		tw.tween_property(b, "self_modulate", Color(1, 1, 1), 0.15))
	b.button_down.connect(func():
		if G.audio != null:
			G.audio.order_tick(true))

func _fade_in(c: Control, t: float = 0.2) -> void:
	if c == null:
		return
	c.modulate.a = 0.0
	var tw = c.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(c, "modulate:a", 1.0, t)

# a panel coming into view slides up a little and fades in, instead of popping
func _pop_in(c: Control, dy: float = 12.0) -> void:
	if c == null:
		return
	c.modulate.a = 0.0
	var tw = c.create_tween()
	tw.set_parallel(true)
	tw.tween_property(c, "modulate:a", 1.0, 0.18)
	var y0 = c.position.y
	c.position.y = y0 + dy
	tw.tween_property(c, "position:y", y0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

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
	# campaign battle prep: the countdown and a button to start early
	prep_box = HBoxContainer.new()
	prep_box.alignment = BoxContainer.ALIGNMENT_CENTER
	prep_box.add_theme_constant_override("separation", 10)
	_place(prep_box, Control.PRESET_CENTER_TOP, -280, 168, 560, 34)
	prep_lbl = _label("", 16, Color(1.0, 0.88, 0.4))
	prep_box.add_child(prep_lbl)
	var prep_btn = _button("Start the battle", func(): Prep.finish())
	prep_btn.focus_mode = Control.FOCUS_NONE
	prep_box.add_child(prep_btn)
	prep_box.visible = false
	root.add_child(prep_box)
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

func feed(a, v, head: bool, what: String = "", cause: String = "") -> void:
	# a row: shooter, what he did it with, the man (or vehicle) he got
	var ct = a.team if a != null else (v.team if v != null else 0)
	var col = G.team_color(ct).lightened(0.45)
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon = cause
	if icon == "" and a != null:
		icon = "vehicle" if a.vehicle != null and is_instance_valid(a.vehicle) and a.state == "riding" else a.wid
	if a != null:
		row.add_child(_label(a.sname, 13, col))
	if icon != "":
		row.add_child(_icon(icon, col))
	if head:
		row.add_child(_icon("head", Color(1.0, 0.85, 0.4)))
	if v == null:
		row.add_child(_label("%s destroyed" % what, 13, Color(1.0, 0.8, 0.5)))
	else:
		var vc = G.team_color(v.team).lightened(0.45)
		row.add_child(_label(v.sname + (" (friendly)" if a != null and a.team == v.team and a != v else ""), 13, vc))
	feed_box.add_child(row)
	feed_box.move_child(row, 0)
	while feed_box.get_child_count() > 7:
		var last = feed_box.get_child(feed_box.get_child_count() - 1)
		feed_box.remove_child(last)
		last.queue_free()
	var wr = weakref(row)
	get_tree().create_timer(6.0).timeout.connect(func():
		var n = wr.get_ref()
		if n != null:
			n.queue_free())

func _icon(kind: String, col: Color) -> TextureRect:
	var tr = TextureRect.new()
	tr.texture = Icons.get_icon(kind)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(Icons.W, Icons.H)
	tr.modulate = col
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

func _tint(p: PanelContainer, c: Color) -> void:
	var sb = p.get_theme_stylebox("panel")
	if sb is StyleBoxFlat and sb.bg_color != c:
		sb = sb.duplicate()
		sb.bg_color = Color(c.r, c.g, c.b, sb.bg_color.a)
		p.add_theme_stylebox_override("panel", sb)

# ---------------------------------------------------------------- side buttons
func _build_side() -> void:
	# one small button in the corner; the rest drops down under it when you click it
	side = VBoxContainer.new()
	side.position = Vector2(12, 12)
	side.z_index = 20          # the drop-down opens over the squad cards
	side.add_theme_constant_override("separation", 4)
	root.add_child(side)
	var top = _button("☰  Menu", func():
		side_list.visible = not side_list.visible)
	top.custom_minimum_size = Vector2(96, 30)
	top.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	top.tooltip_text = "Menu, pause, slow motion, the battle report and the controls"
	side.add_child(top)
	side_list = PanelContainer.new()
	side_list.add_theme_stylebox_override("panel", Hud.pill(Hud.BG, Hud.EDGE))
	side_list.visible = false
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	side_list.add_child(v)
	side.add_child(side_list)
	var item = func(text: String, cb: Callable) -> Button:
		var b = _button(text, func():
			cb.call()
			side_list.visible = false)
		b.custom_minimum_size = Vector2(190, 26)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(b)
		return b
	item.call("Main menu  (M)", func(): show_menu())
	item.call("Pause  (P)", func(): get_tree().paused = not get_tree().paused)
	item.call("Slow motion  (T)", func(): Engine.time_scale = 0.25 if Engine.time_scale > 0.5 else 1.0)
	item.call("Battle report  (J)", func(): show_report())
	item.call("Controls  (H)", func(): help.visible = true)
	btn_reinf = item.call("Reinforcements: on", func():
		G.reinforce = not G.reinforce
		btn_reinf.text = "Reinforcements: " + ("on" if G.reinforce else "off"))

var side_list: PanelContainer = null

# ---------------------------------------------------------------- tool dock
# One panel at the bottom of the screen: tabs along the top, then cards for what you can place,
# call in or buy, each with its cost. The side switch picks which team units, vehicles and
# structures are for. In commander mode it becomes a shop: you pay for everything.
var dock: PanelContainer
var dock_tabs: HBoxContainer
var dock_status: Label
var dock_status_t = 0.0
var up_sig = ""
var dock_cards: HFlowContainer
var dock_side: Button
var dock_pts: Label
var dock_cards_list: Array = []      # [id, button] in order, for the number keys
var dock_pts_shown = -1

const SB_VEH = [["jeep", "Jeep"], ["truck", "Truck"], ["motorbike", "Motorbike"], ["halftrack", "Half-track"], ["armoredcar", "Armoured car"],
	["tank", "Tank"], ["heavytank", "Heavy tank"], ["plough", "Mine plough tank"], ["technical", "Technical"], ["ambulance", "Ambulance"], ["radar", "Command truck"], ["bridger", "Bridge layer"], ["gunship", "Gunship"],
	["fighter", "Fighter"], ["bomber", "Dive bomber"], ["nest", "MG nest"], ["mortar", "Mortar"], ["artillery", "Field gun"], ["aagun", "AA gun"], ["atgun", "AT gun"], ["dinghy", "Assault boat"]]
const BUILD_LIST = [["fob", "FOB"], ["sandbags", "Sandbags"], ["wire", "Barbed wire"], ["traps", "Tank traps"], ["mgnest", "MG nest"],
	["mortarpit", "Mortar pit"], ["aa", "AA gun"], ["cbgun", "Counter-battery gun"], ["tower", "Watchtower"], ["bunker", "Bunker"], ["hospital", "Field hospital"],
	["radio", "Radio mast"], ["depot", "Vehicle depot"], ["supply", "Supply dump"], ["observer", "Observer post"]]
const BASES = ["fob", "hospital", "radio", "depot", "supply", "observer", "tower"]
const RECRUIT = {
	"inf": {"name": "Rifle squad", "cost": 16, "cls": ["rifleman", "rifleman", "rifleman", "rifleman", "mg", "at", "medic", "rifleman"],
		"desc": "Eight men: five riflemen, a machine gunner, an anti-tank man and a medic. The backbone of any attack"},
	"plt": {"name": "Rifle platoon", "cost": 30, "cls": ["rifleman", "rifleman", "rifleman", "rifleman", "mg", "at", "medic", "rifleman",
		"rifleman", "rifleman", "rifleman", "mg", "at", "medic", "radio", "rifleman"],
		"desc": "Sixteen men in two trucks, with a radio operator. Cheaper than two squads"},
	"eng": {"name": "Engineers", "cost": 12, "cls": ["engineer", "engineer", "engineer", "engineer"],
		"desc": "Four engineers: they build and repair, lay mines, sweep for them and blow things up with satchels"},
	"atk": {"name": "Anti-tank team", "cost": 14, "cls": ["at", "at", "at", "rifleman"],
		"desc": "Three rocket men and a rifleman to cover them. They hunt tanks and blast structures"},
	"mgt": {"name": "MG team", "cost": 12, "cls": ["mg", "mg", "rifleman", "rifleman"],
		"desc": "Two machine guns that pin the enemy down while others move"},
	"asl": {"name": "Assault team", "cost": 16, "cls": ["assault", "assault", "assault", "assault", "assault", "assault"],
		"desc": "Six men with SMGs, shotguns and a flamethrower: for clearing buildings and close fighting"},
	"snp": {"name": "Sniper team", "cost": 8, "cls": ["sniper", "spotter"],
		"desc": "A sniper and his spotter: they climb up high, and the spotter finds targets for him"},
	"med": {"name": "Medics", "cost": 6, "cls": ["medic", "medic"],
		"desc": "Two medics who patch up and drag in the wounded, and carry stretchers"},
	"rad": {"name": "Radio team", "cost": 8, "cls": ["radio", "rifleman", "rifleman"],
		"desc": "A radio operator with two riflemen to guard him. Only a man with a radio can call artillery"},
}
# call-ins that happen as soon as you pay (no map click needed)
const INSTANT = ["plough", "technical", "oldtank", "gunbus", "techaa", "recon", "atgun", "heavytank", "paradrop", "heli", "jeep", "motorbike", "halftrack", "armoredcar", "tank", "gunship", "fighter", "bomber", "bridger", "radar", "ambulance", "supplytruck", "ammotruck"]

func _tabs() -> Array:
	if G.mode == "commander":
		return [["recruit", "Recruit"], ["armour", "Vehicles"], ["logistics", "Supply"], ["support", "Fire support"], ["build", "Defences"], ["bases", "Bases"], ["upgrades", "Upgrades"]]
	if Rules.free_tools():
		return [["units", "Units"], ["vehicles", "Vehicles"], ["support", "Call-ins"], ["build", "Build"], ["command", "Command"], ["fun", "Effects"]]
	# a real battle: you command your own side, with what this mode gives it
	var out = [["command", "Command"], ["units", "Soldiers"]]
	if not Rules.callins(0).is_empty():
		out.append(["support", "Call-ins"])
	if not Rules.build(0).is_empty():
		out.append(["build", "Build"])
	if G.mode == "horde":
		out.append(["armoury", "Armoury"])
	return out

# the cards on a tab: [id, title, cost line]
func _cards(t: String) -> Array:
	var out = []
	match t:
		"units":
			out = [["s1", "Soldier", "click the ground"], ["s5", "Squad of five", "click the ground"], ["ctl", "Take control", "click a soldier · F"],
				["sp", "Move spawn point", "where reinforcements arrive"]]
			if not Rules.free_tools():
				out = [["ctl", "Take control", "click one of your soldiers · F"]]
		"vehicles":
			for v in SB_VEH:
				out.append(["v:" + v[0], v[1], "with crew"])
		"support":
			for k in (["recon", "artillery", "airstrike", "gunship", "fighter", "bomber"] if G.mode == "commander" else Support.COSTS.keys().filter(func(x): return x != "supplytruck")):
				if not Faction.support_ok(0, k) or not Rules.callin_ok(0, k):
					continue
				if not Support.unlocked(0, k):
					out.append(["sup:" + k, Support.NAMES[k].split(" (")[0], Support.need_text(k)])
				else:
					out.append(["sup:" + k, Support.NAMES[k].split(" (")[0], "%d pts" % Support.COSTS[k] + ("" if k in INSTANT else " · click the map")])
		"armour":
			for k in ["jeep", "technical", "techaa", "motorbike", "halftrack", "gunbus", "armoredcar", "tank", "oldtank", "heavytank", "plough", "atgun", "ambulance", "radar", "bridger"]:
				if not Faction.support_ok(0, k) or not Rules.callin_ok(0, k):
					continue
				out.append(["sup:" + k, Support.NAMES[k], ("%d pts" % Support.COSTS[k]) if Support.unlocked(0, k) else Support.need_text(k)])
		"logistics":
			# supply trucks earn the points (at most three); the ammo truck restocks the men where you park it
			out.append(["sup:supplytruck", "Supply truck  %d/%d" % [Logistics.count(0), Logistics.FLEET_MAX], ("%d pts · runs supplies from HQ" % Support.COSTS["supplytruck"]) if Logistics.can_buy_truck(0) else ("fleet full" if Logistics.count(0) >= Logistics.FLEET_MAX else ("build a supply dump or FOB first" if not Logistics.has_stop(0) else "needs your HQ"))])
			out.append(["sup:ammotruck", "Ammo truck", "%d pts · park it behind the line" % Support.COSTS["ammotruck"]])
		"recruit":
			for k in RECRUIT:
				out.append(["r:" + k, "%s ×%d" % [RECRUIT[k]["name"], RECRUIT[k]["cls"].size()], "%d pts" % recruit_cost(0, k)])
			if Faction.militia(0):
				return out
			out.append(["sup:paradrop", "Paratroopers ×6", ("%d pts" % Support.COSTS["paradrop"]) if Support.unlocked(0, "paradrop") else Support.need_text("paradrop")])
			out.append(["sup:heli", "Heli assault ×6", ("%d pts" % Support.COSTS["heli"]) if Support.unlocked(0, "heli") else Support.need_text("heli")])
		"build", "bases":
			var can = Rules.build(G.pc._build_team())
			for b in BUILD_LIST:
				if not (b[0] in can):
					continue
				# in commander the build cards come in two tabs: fighting positions, and the bases behind them
				if G.mode == "commander" and ((t == "bases") != (b[0] in BASES)):
					continue
				var c = Build.cost(b[0])
				out.append(["b:" + b[0], b[1], ("%d pts" % c) if c > 0 else "%d s to build" % int(Build.KINDS[b[0]]["work"])])
			if t == "build" or G.mode != "commander":
				out += [["up", "Upgrade", "click a structure"], ["camo", "Camo net", "click a structure"], ["rep", "Repair", "click a damaged structure"], ["dis", "Dismantle", "click anything built"]]
		"command", "orders":
			out = [["sel", "Select", "click or drag a box"], ["o:hold", "Hold", "selected soldiers"], ["o:charge", "Charge", "selected soldiers"],
				["o:dismount", "Dismount", "troops out of vehicles"], ["o:free", "Act freely", "selected soldiers"], ["o:clear", "Deselect", ""]]
			if t == "command":
				out.append(["mv", "Send the side", "click a point"])
			out += [["f:wedge", "Wedge", "formation"], ["f:line", "Line", "formation"], ["f:column", "Column", "formation"]]
		"armoury":
			for k in Modes.SHOP:
				var sh = Modes.SHOP[k]
				out.append(["h:" + k, sh["name"], "%d pts" % sh["cost"]])
		"upgrades":
			for k in Prod.UPGRADES:
				var u = Prod.UPGRADES[k]
				var st = "done" if Prod.done[0].has(k) else ("%d pts · %d s" % [u["cost"], int(u["time"])] if Prod.can_research(0, k) else "in progress")
				out.append(["u:" + k, u["name"], st])
		"fun":
			out = [["boom", "Explosion", ""], ["mortar", "Mortar strike", ""], ["smoke", "Smoke", ""], ["flare", "Flare", "lights up the night"], ["push", "Shove", "knock a soldier over"]]
	return out

func _dock_style(col: Color, border: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(Hud.RADIUS)
	sb.set_content_margin_all(6)
	if border.a > 0.0:
		sb.set_border_width_all(2)
		sb.border_color = border
	return sb

func _build_tools() -> void:
	dock = _panel(Color(0.07, 0.08, 0.09, 0.9))
	dock.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	# if the cards need more room, the dock grows up the screen, never off the bottom
	dock.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(dock)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var head = HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	dock_tabs = HBoxContainer.new()
	dock_tabs.add_theme_constant_override("separation", 3)
	head.add_child(dock_tabs)
	# commander mode: what the depot and HQ are working on, and when the next convoy leaves
	dock_status = _label("", 13, Color(0.8, 0.85, 0.75))
	dock_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(dock_status)
	dock_side = _button("", func():
		build_team = (build_team + 1) % maxi(1, G.team_count())
		_render_tools())
	head.add_child(dock_side)
	dock_pts = _label("", 15, Color(1.0, 0.86, 0.4))
	dock_pts.custom_minimum_size = Vector2(150, 0)
	dock_pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(dock_pts)
	v.add_child(head)
	dock_cards = HFlowContainer.new()
	dock_cards.add_theme_constant_override("h_separation", 5)
	dock_cards.add_theme_constant_override("v_separation", 5)
	dock_cards.custom_minimum_size = Vector2(880, 0)
	v.add_child(dock_cards)
	dock.add_child(v)
	tip = _label("", 13)
	_place(tip, Control.PRESET_CENTER_BOTTOM, -360, -200, 720, 20)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(tip)
	_render_tools()

func _render_tools() -> void:
	if dock == null:
		return
	var tabs = _tabs()
	var ids = tabs.map(func(x): return x[0])
	if not (tab in ids):
		tab = ids[0]
		tool = "sel" if tab in ["orders", "command"] else _cards(tab)[0][0]
	for c in dock_tabs.get_children():
		c.queue_free()
	for t in tabs:
		var key = t[0]
		var b = _button(t[1], func():
			tab = key
			var first = _cards(key)[0][0]
			if not _is_action(first):
				tool = first
			_render_tools())
		b.add_theme_stylebox_override("normal", _dock_style(Color(0.85, 0.65, 0.2, 0.95) if tab == key else Color(0.18, 0.2, 0.22, 0.95)))
		b.add_theme_stylebox_override("hover", _dock_style(Color(0.95, 0.75, 0.3, 1.0) if tab == key else Color(0.26, 0.29, 0.32, 1.0)))
		b.add_theme_color_override("font_color", Color(0.08, 0.08, 0.08) if tab == key else Color(0.88, 0.9, 0.9))
		b.add_theme_color_override("font_hover_color", Color(0.05, 0.05, 0.05) if tab == key else Color(1, 1, 1))
		dock_tabs.add_child(b)
	var sided = tab in ["units", "vehicles", "build", "command"] and Rules.free_tools()
	dock_side.visible = sided
	if sided:
		var bt = mini(build_team, G.team_count() - 1)
		dock_side.text = "For: %s  ⇄" % G.TEAM_NAMES[bt]
		dock_side.add_theme_stylebox_override("normal", _dock_style(G.team_color(bt).darkened(0.35)))
		dock_side.add_theme_stylebox_override("hover", _dock_style(G.team_color(bt).darkened(0.15)))
	for c in dock_cards.get_children():
		c.queue_free()
	dock_cards_list = []
	var i = 1
	var pts = _pts()
	for cd in _cards(tab):
		var id: String = cd[0]
		var b2 = Button.new()
		b2.focus_mode = Control.FOCUS_NONE
		b2.custom_minimum_size = Vector2(118, 50)
		b2.clip_text = true
		b2.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b2.text = ("%d  " % i if i <= 9 and not G.pc.rts else "") + cd[1] + ("\n" + cd[2] if cd[2] != "" else "")
		b2.add_theme_font_size_override("font_size", 13)
		var sel = tool == id
		var cost = _cost(id)
		var afford = (cost <= 0 or pts >= cost) and (not id.begins_with("sup:") or Support.unlocked(0, id.substr(4)))
		b2.add_theme_stylebox_override("normal", _dock_style(Color(0.16, 0.18, 0.2, 0.96), Color(0.95, 0.75, 0.25) if sel else Color(0.3, 0.33, 0.36)))
		b2.add_theme_stylebox_override("hover", _dock_style(Color(0.24, 0.27, 0.3, 1.0), Color(1.0, 0.85, 0.35) if sel else Color(0.55, 0.6, 0.64)))
		b2.add_theme_stylebox_override("pressed", _dock_style(Color(0.3, 0.27, 0.15, 1.0), Color(1.0, 0.85, 0.35)))
		b2.add_theme_color_override("font_color", Color(0.95, 0.95, 0.92) if afford else Color(0.55, 0.5, 0.5))
		b2.pressed.connect(func(): _card_clicked(id))
		_juice(b2)
		# hovering a card says what it is and does, above the dock
		var ds = _card_desc(id)
		if ds != "":
			b2.tooltip_text = ds
			b2.mouse_entered.connect(func():
				if tip != null:
					tip.text = ds)
			b2.mouse_exited.connect(func():
				if tip != null:
					tip.text = TIPS.get(tool, "") if not tool.begins_with("h:") else Modes.SHOP[tool.substr(2)]["tip"])
		dock_cards.add_child(b2)
		dock_cards_list.append([id, b2])
		i += 1
	dock_pts_shown = -1
	_dock_points()
	# size the dock to its cards
	var n = dock_cards_list.size()
	var per_row = mini(n, 7)
	var w = maxf(per_row * 128.0 + 22.0, 640.0)
	dock_cards.custom_minimum_size = Vector2(w - 16.0, 0)
	dock.offset_left = -w / 2.0
	dock.offset_right = w / 2.0
	var rows = int(ceil(float(n) / 7.0))
	var h = 40.0 + rows * 55.0 + 14.0
	dock.offset_top = -h - 8.0
	dock.offset_bottom = -8.0
	tip.offset_top = -h - 34.0
	tip.offset_bottom = -h - 14.0
	tip.text = TIPS.get(tool, "") if not tool.begins_with("h:") else Modes.SHOP[tool.substr(2)]["tip"]

const SUP_DESC = {
	"supplytruck": "Runs supplies from HQ to your supply dumps and FOBs. Points only come in when it gets there. Up to three; lose one and you buy another",
	"ammotruck": "Park it behind the line: men nearby run to its tailgate to restock. Drive it back to HQ or a supply dump to refill it",
	"jeep": "Fast, with a mounted machine gun. Good for scouting and harassing infantry",
	"technical": "A pickup with a heavy machine gun on the back",
	"techaa": "A technical with twin heavy machine guns: twice the fire, just as thin-skinned",
	"gunbus": "A lorry with boiler plate welded over it and a cannon on top: the militia's armoured car, slower and softer",
	"oldtank": "An old tank the militia keep running: sandbags and logs for extra armour, slower and weaker than a modern one",
	"motorbike": "Very fast and fragile: for getting a man somewhere quickly",
	"halftrack": "Armoured troop carrier with a machine gun; carries a squad up to the fight",
	"armoredcar": "Fast armoured car with a cannon; tough against infantry, vulnerable to rockets",
	"tank": "Main battle tank: a big gun and thick armour. Infantry ride on the back",
	"heavytank": "Slower, tougher and harder-hitting than the tank",
	"plough": "A tank with a mine plough that clears the road ahead of it",
	"atgun": "Towed anti-tank gun, set up at the rally point",
	"ambulance": "Picks up the wounded and takes them to a field hospital",
	"radar": "Command truck: park it and it sets up as a command post. Men within 45 m steady faster under fire and shoot straighter, it spots enemies far around, call-ins work through its radio, and reinforcements come up to it",
	"bridger": "Lays a bridge over a river or a blown bridge",
	"artillery": "A barrage of shells on the spot you click (in commander battles it can't hurt an HQ: that has to be taken on the ground)",
	"airstrike": "A plane bombs the spot you click",
	"recon": "A spotter plane circles the enemy's side for thirty seconds and shows everything it sees",
	"gunship": "A helicopter gunship hunts the enemy for seventy seconds",
	"fighter": "A fighter that hunts enemy aircraft for ninety seconds",
	"bomber": "A dive bomber that goes after armour and structures for ninety seconds",
	"paradrop": "Six paratroopers dropped in", "heli": "Six men flown in by helicopter",
}

# what a dock card does, for its hover text
func _card_desc(id: String) -> String:
	if id.begins_with("u:"):
		var k = id.substr(2)
		var u = Prod.UPGRADES[k]
		var st = "Done." if Prod.done[0].has(k) else ("Being researched at HQ." if not Prod.can_research(0, k) else "%d pts, %d s of research at HQ." % [u["cost"], int(u["time"])])
		return "%s: %s. %s" % [u["name"], u.get("long", u["desc"]), st]
	if id.begins_with("r:"):
		var r = RECRUIT[id.substr(2)]
		return "%s (%d pts): %s. Click where you want them dropped off." % [r["name"], recruit_cost(0, id.substr(2)), r.get("desc", "")]
	if id.begins_with("sup:"):
		var k2 = id.substr(4)
		var d = SUP_DESC.get(k2, "")
		if d != "" and not Support.unlocked(0, k2):
			d += ". Needs " + Support.need_text(k2)
		return d
	if id.begins_with("b:"):
		return Build.DESCR.get(id.substr(2), "")
	return ""

func _pts() -> int:
	var t = 0 if G.mode == "commander" else (mini(build_team, G.team_count() - 1) if tab != "support" else 0)
	return Support.points[t] if t < Support.points.size() else 0

func _dock_points() -> void:
	if dock_pts == null:
		return
	var p = _pts()
	if p == dock_pts_shown:
		return
	dock_pts_shown = p
	var show_pts = G.mode == "commander" or G.mode == "horde" or tab in ["support"]
	dock_pts.text = ("Supply  %d pts" % p) if show_pts else ""
	for e in dock_cards_list:
		var c = _cost(e[0])
		e[1].add_theme_color_override("font_color", Color(0.95, 0.95, 0.92) if (c <= 0 or p >= c) else Color(0.55, 0.5, 0.5))

func _cost(id: String) -> int:
	if id.begins_with("sup:"):
		return Support.COSTS.get(id.substr(4), 0)
	if id.begins_with("r:"):
		return recruit_cost(0, id.substr(2))
	if id.begins_with("b:"):
		return Build.cost(id.substr(2))
	if id.begins_with("u:"):
		return Prod.UPGRADES[id.substr(2)]["cost"]
	if id.begins_with("h:"):
		return Modes.SHOP[id.substr(2)]["cost"]
	return 0

func _is_action(id: String) -> bool:
	return id.begins_with("u:") or (id.begins_with("r:") and G.mode != "commander") or id.begins_with("o:") or id.begins_with("f:") or (id.begins_with("sup:") and id.substr(4) in INSTANT)

# a card was clicked: actions happen now, everything else becomes the tool for the next map click
func _card_clicked(id: String) -> void:
	if id.begins_with("o:"):
		var m = id.substr(2)
		if m == "clear":
			G.pc.clear_selection()
		else:
			G.pc.order_selected(m)
		return
	if id.begins_with("f:"):
		G.pc.set_formation(id.substr(2))
		return
	if id.begins_with("h:") and Modes.shop_instant(id.substr(2)):
		message(Modes.shop(id.substr(2), G.world.capture))
		_dock_points()
		return
	if id.begins_with("u:"):
		var up = id.substr(2)
		if not Prod.can_research(0, up):
			message("%s is already done or under way" % Prod.UPGRADES[up]["name"])
		elif not Prod.start_research(0, up):
			message("Not enough supply points: %s costs %d" % [Prod.UPGRADES[up]["name"], Prod.UPGRADES[up]["cost"]])
		else:
			message("Researching %s at HQ: %s" % [Prod.UPGRADES[up]["name"].to_lower(), Prod.UPGRADES[up]["desc"]])
		_render_tools()
		return
	if id.begins_with("r:") and G.mode != "commander":
		_recruit(id.substr(2))
		return
	if id.begins_with("sup:") and not Support.unlocked(0, id.substr(4)):
		var wk = id.substr(4)
		var pend = Support.pending_site(0, wk)
		if pend != null:
			var pct = int(100.0 * pend["work"] / maxf(1.0, pend["need"]))
			var engs = G.soldiers.filter(func(x): return x.team == 0 and x.state == "alive" and x.cls == "engineer").size()
			message("%s: the %s is still being built (%d%%)%s" % [Support.NAMES[wk].split(" (")[0], pend["name"].to_lower(), pct,
				"" if engs > 0 else " and you have no engineers to finish it: recruit an engineer squad"])
		else:
			message("%s: %s first (Build tab)" % [Support.NAMES[wk].split(" (")[0], Support.need_text(wk).capitalize()])
		return
	if id.begins_with("sup:") and id.substr(4) in INSTANT:
		var what = id.substr(4)
		var team = 0
		if Support.call_in(team, what, G.world.capture):
			message("%s on the way (-%d pts)" % [Support.NAMES[what], Support.COSTS[what]])
			if tab == "logistics":
				_render_tools()
		elif Support.points[team] >= Support.COSTS[what]:
			pass        # it said why itself (a full fleet, say)
		else:
			message("Not enough supply points: %s costs %d, you have %d" % [Support.NAMES[what], Support.COSTS[what], Support.points[team]])
		_dock_points()
		return
	tool = id
	_render_tools()

# what a body of men costs a side: the militia's irregulars come cheaper than trained soldiers
func recruit_cost(team: int, k: String) -> int:
	return int(round(RECRUIT[k]["cost"] * (0.8 if Faction.militia(team) else 1.0)))

func _recruit(k: String, dest = null) -> void:
	var r = RECRUIT[k]
	var cost = recruit_cost(0, k)
	if Support.points[0] < cost:
		message("Not enough supply points: %s costs %d, you have %d" % [r["name"], cost, Support.points[0]])
		return
	Support.points[0] -= cost
	var n = Reinforce.truck_cls(0, r["cls"], dest)
	message("%s on the way by %s%s (-%d pts)" % [r["name"], "truck" if n == 1 else "%d trucks" % n, " to the marked spot" if dest != null else "", cost])
	if dest != null:
		G.fx.order_marker(dest)
	_dock_points()

func pick_tool(i: int) -> void:
	if i < dock_cards_list.size():
		_card_clicked(dock_cards_list[i][0])

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

var nv: ColorRect
var nv_on = false
var nv_hinted = false

# night vision (F2): the scene brightened and turned green, grainy, with a dark ring round the edge
func _build_nv() -> void:
	nv = ColorRect.new()
	nv.set_anchors_preset(Control.PRESET_FULL_RECT)
	nv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh = Shader.new()
	sh.code = """shader_type canvas_item;
uniform sampler2D scr : hint_screen_texture, filter_linear;
uniform float t = 0.0;
void fragment() {
	vec3 c = texture(scr, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	l = pow(clamp(l * 4.2, 0.0, 1.0), 0.6);
	float n = fract(sin(dot(floor(SCREEN_UV * 600.0) + vec2(t * 61.0, t * 37.0), vec2(12.9898, 78.233))) * 43758.5453);
	l = l * 0.88 + n * 0.1;
	float scan = 0.96 + 0.04 * sin(SCREEN_UV.y * 900.0);
	vec2 d = UV - vec2(0.5);
	float vg = 1.0 - smoothstep(0.38, 0.72, length(d * vec2(1.25, 1.0)));
	COLOR = vec4(vec3(0.32, 1.0, 0.42) * l * scan * vg, 1.0);
}"""
	var mat = ShaderMaterial.new()
	mat.shader = sh
	nv.material = mat
	nv.visible = false
	# its own layer, under the HUD, so it stays on when the HUD is hidden
	var cl = CanvasLayer.new()
	cl.layer = layer - 1
	cl.add_child(nv)
	add_child(cl)

func toggle_nv() -> void:
	nv_on = not nv_on
	nv.visible = nv_on
	message("Night vision " + ("on" if nv_on else "off") + " (F2)")

var hudx: Control
var cmdhud: Control

func _build_center() -> void:
	_build_vignette()
	_build_nv()
	hudx = preload("res://scripts/hudx.gd").new()
	root.add_child(hudx)
	cmdhud = preload("res://scripts/cmdhud.gd").new()
	root.add_child(cmdhud)
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
	msg = _label("", 18)
	# narrower than the screen so it clears the squad cards on the left and the feed on the right
	_place(msg, Control.PRESET_CENTER_TOP, -260, 200, 520, 40)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# (a dark plate behind it: white words straight over a sunlit wall or a sandy field couldn't be read)
	var msb = StyleBoxFlat.new()
	msb.bg_color = Color(0.04, 0.05, 0.06, 0.62)
	msb.set_corner_radius_all(6)
	msb.content_margin_left = 12
	msb.content_margin_right = 12
	msb.content_margin_top = 6
	msb.content_margin_bottom = 6
	msg.add_theme_stylebox_override("normal", msb)
	msg.visible = false
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

# dirt thrown over the view by a blast close by: a brown haze and clods that fade away
func dust_hit(k: float) -> void:
	var host = Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(host)
	var haze = ColorRect.new()
	haze.set_anchors_preset(Control.PRESET_FULL_RECT)
	haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	haze.color = Color(0.45, 0.38, 0.28, 0.45 * k)
	host.add_child(haze)
	var vs = get_viewport().get_visible_rect().size
	for i in range(int(6 + 10 * k)):
		var b = TextureRect.new()
		b.texture = G.fx.soft_tex
		b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var sz = randf_range(80.0, 260.0) * (0.6 + k)
		b.size = Vector2(sz, sz * randf_range(0.6, 1.0))
		b.position = Vector2(randf() * vs.x, randf() * vs.y) - b.size * 0.5
		b.modulate = Color(0.32, 0.26, 0.18, randf_range(0.35, 0.75) * k)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(b)
	var tw = host.create_tween()
	tw.tween_interval(0.3)
	tw.tween_property(host, "modulate:a", 0.0, 2.2)
	tw.tween_callback(host.queue_free)

func damage_indicator(from: Vector3) -> void:
	var cam = G.pc.cam
	var to = from - cam.global_position
	var a = atan2(to.x, to.z)
	var rel = G.wrap_a(a - G.pc.cam_yaw)
	dmg_list.append({"a": -rel, "t": 1.2})
	G.pc.kick = minf(0.3, G.pc.kick + 0.1)

func message(t: String) -> void:
	msg.text = t
	msg.visible = t != ""
	msg.size.y = 0.0          # (shrinks back to fit a shorter message)
	msg_t = 2.5 + minf(4.0, t.length() * 0.02)

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

const MAP_NAMES = ["Town ruins", "Farmland", "Trenches", "Forest", "City blocks", "Tank factory (indoor)", "Ministry offices (3 floors, indoor)", "Beach landing", "Valley offensive (large)",
	"Western front (large)", "River crossing (large)", "Mountain pass (large)", "Huge battlefield (huge)", "Random map (seed below)"]

func _section(parent: Control, title: String) -> void:
	var l = _label(title.to_upper(), 12, Color(0.95, 0.75, 0.3))
	parent.add_child(l)
	var line = ColorRect.new()
	line.color = Color(0.95, 0.75, 0.3, 0.35)
	line.custom_minimum_size = Vector2(0, 1)
	parent.add_child(line)

func _build_menu() -> void:
	menu = _panel(Color(0.07, 0.08, 0.095, 0.97))
	var msb: StyleBoxFlat = menu.get_theme_stylebox("panel")
	msb.set_corner_radius_all(8)
	msb.set_border_width_all(1)
	msb.border_color = Color(0.96, 0.74, 0.27, 0.35)
	msb.set_content_margin_all(16)
	msb.shadow_color = Color(0, 0, 0, 0.5)
	msb.shadow_size = 18
	_place(menu, Control.PRESET_CENTER, -460, -330, 920, 660)
	var outer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	var top = HBoxContainer.new()
	top.add_child(_button("←  Back", func():
		menu.visible = false
		show_menu()))
	var tl = _label("  New battle", 28, Color(0.96, 0.93, 0.85))
	top.add_child(tl)
	outer.add_child(top)
	var d = _label("Two armies fight it out on their own. Drop in soldiers, call in strikes, command from above or take control of anyone on the field.", 14, Color(0.75, 0.77, 0.75))
	d.autowrap_mode = TextServer.AUTOWRAP_WORD
	d.custom_minimum_size = Vector2(860, 0)
	outer.add_child(d)
	var cols = HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	outer.add_child(cols)
	# left: the battle you're setting up
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	v.custom_minimum_size = Vector2(520, 0)
	cols.add_child(v)
	_section(v, "Battle")
	opt_map = _option(MAP_NAMES, 0)
	opt_map.item_selected.connect(func(i):
		if not G.started:
			_select_map(i))
	refresh_maps()
	_row(v, "Map", opt_map)
	opt_mode = _option(["Sandbox — endless", "Commander — top-down RTS", "Horde — the dead walk"], 0)
	_row(v, "Mode", opt_mode)
	mode_info = _label("", 13, Color(0.8, 0.82, 0.78))
	mode_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mode_info.custom_minimum_size = Vector2(300, 0)
	mode_title = _label("", 18, Color(0.97, 0.95, 0.9))
	mode_rules = _label("", 12, Color(0.96, 0.74, 0.27))
	mode_rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mode_rules.custom_minimum_size = Vector2(300, 0)
	opt_limit = _option(["50"], 0)
	limit_row = HBoxContainer.new()
	limit_lbl = _label("Win at", 15)
	limit_lbl.custom_minimum_size = Vector2(200, 0)
	limit_row.add_child(limit_lbl)
	limit_row.add_child(opt_limit)
	opt_limit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(limit_row)
	_fill_limits()
	_section(v, "Forces")
	opt_size = _option(["5", "8", "10", "15", "20", "30", "50", "100"], 2)
	_row(v, "Soldiers per side", opt_size)
	size_lbl = v.get_child(v.get_child_count() - 1).get_child(0)
	opt_reinf = _option(["By truck", "Paratroopers", "By helicopter", "Appear at base", "None"], 0)
	_row(v, "Reinforcements", opt_reinf)
	opt_armor = _option(["None", "Jeeps", "Jeeps and tanks"], 1)
	_row(v, "Vehicles at the start", opt_armor)
	opt_teams = _option(["2 sides", "3 sides", "4 sides"], 0)
	_row(v, "Sides (3–4 in sandbox, deathmatch, capture)", opt_teams)
	var fnames = Faction.LIST.map(func(f): return Faction.NAMES[f])
	opt_fac0 = _option(fnames, maxi(0, Faction.LIST.find(G.factions[0])))
	_row(v, "Your side (Alpha) plays as", opt_fac0)
	opt_fac1 = _option(fnames, maxi(0, Faction.LIST.find(G.factions[1])))
	_row(v, "Against (Bravo)", opt_fac1)
	opt_cmd = _option(["You command (you build and buy)", "AI commander (watch or help)"], 1 if G.settings.get("ai_side", false) else 0)
	opt_cmd.item_selected.connect(func(i): G.settings["ai_side"] = i == 1)
	_row(v, "Who runs your side", opt_cmd)
	var diffs = ["easy", "normal", "hard"]
	var opt_diff = _option(["Easy: slower, poorer, worse shots", "Normal", "Hard: quicker, richer, better shots"], maxi(0, diffs.find(G.settings.get("difficulty", "normal"))))
	opt_diff.item_selected.connect(func(i): G.settings["difficulty"] = diffs[i])
	opt_diff.tooltip_text = "How good the enemy is. Easy: it earns less supply, buys and shells less often, shoots wider, and gives you about a minute and a half before its first move. Hard: the reverse, and it moves at once."
	_row(v, "Difficulty", opt_diff)
	var styles = ["random", "reckless", "cautious", "cunning"]
	var opt_style = _option(["Any (picked at random)", "Reckless: attacks at once and keeps coming", "Cautious: digs in and waits for the numbers", "Cunning: probes with scouts, hits weak spots"], maxi(0, styles.find(G.settings.get("ai_style", "random"))))
	opt_style.item_selected.connect(func(i): G.settings["ai_style"] = styles[i])
	opt_style.tooltip_text = "The enemy commander's temperament"
	_row(v, "Enemy commander", opt_style)
	_section(v, "World")
	opt_time = _option(["Day", "Dusk", "Night", "Dawn till nightfall (time passes)", "Endless day and night cycle"], maxi(0, ["day", "dusk", "night", "dawn", "cycle"].find(G.settings["time"])))
	opt_time.item_selected.connect(func(i):
		G.settings["time"] = ["day", "dusk", "night", "dawn", "cycle"][i]
		G.main.clock = 0.08 if G.settings["time"] == "dawn" else 0.25
		G.main.apply_time())
	_row(v, "Time of day", opt_time)
	var opt_weather = _option(["Clear", "Rain (puddles, wet roads)", "Cold (breath in the air)"], maxi(0, ["clear", "rain", "cold"].find(G.settings.get("weather", "clear"))))
	opt_weather.item_selected.connect(func(i):
		G.settings["weather"] = ["clear", "rain", "cold"][i]
		if G.started:
			Weather.apply()
			G.main.apply_time())
	opt_weather.tooltip_text = "How the day looks. Rain and cold change nothing about the fighting (a campaign storm still grounds aircraft)."
	_row(v, "Weather", opt_weather)
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
	# right: start, and everything else
	var r = VBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	r.custom_minimum_size = Vector2(316, 0)
	cols.add_child(r)
	_section(r, "Play")
	var go = _button("▶  DEPLOY", func(): _deploy())
	go.custom_minimum_size = Vector2(0, 58)
	go.add_theme_font_size_override("font_size", 22)
	go.add_theme_stylebox_override("normal", _dock_style(Color(0.78, 0.58, 0.16)))
	go.add_theme_stylebox_override("hover", _dock_style(Color(0.9, 0.7, 0.25)))
	go.add_theme_color_override("font_color", Color(0.06, 0.06, 0.05))
	go.add_theme_color_override("font_hover_color", Color(0, 0, 0))
	r.add_child(go)
	# what the chosen mode is about, how it's won and what each side gets
	_section(r, "About this mode")
	var card = PanelContainer.new()
	var csb = StyleBoxFlat.new()
	csb.bg_color = Color(1, 1, 1, 0.045)
	csb.border_width_left = 3
	csb.border_color = Color(0.96, 0.74, 0.27, 0.85)
	csb.set_corner_radius_all(4)
	csb.content_margin_left = 12
	csb.content_margin_right = 10
	csb.content_margin_top = 8
	csb.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", csb)
	var cv = VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	cv.add_child(mode_title)
	cv.add_child(mode_info)
	cv.add_child(mode_rules)
	card.add_child(cv)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	r.add_child(card)
	opt_mode.item_selected.connect(func(_i): _show_mode_info())
	_show_mode_info()
	_section(r, "Options")
	var g = GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 6)
	for e in [["Teams", func(): _show_teams()], ["Settings", func(): _show_settings()], ["Controls", func(): help.visible = true]]:
		var b2 = _button(e[0], e[1])
		b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(b2)
	r.add_child(g)
	menu.add_child(outer)
	root.add_child(menu)

# one look for every button and drop-down
func _theme() -> Theme:
	var t = Theme.new()
	for cls in ["Button", "OptionButton"]:
		t.set_stylebox("normal", cls, _dock_style(Color(0.17, 0.19, 0.21, 0.96), Color(0.28, 0.31, 0.34)))
		t.set_stylebox("hover", cls, _dock_style(Color(0.24, 0.27, 0.3, 1.0), Color(0.6, 0.64, 0.66)))
		t.set_stylebox("pressed", cls, _dock_style(Color(0.32, 0.28, 0.16, 1.0), Color(0.95, 0.75, 0.3)))
		t.set_stylebox("disabled", cls, _dock_style(Color(0.12, 0.13, 0.14, 0.9)))
		t.set_stylebox("focus", cls, StyleBoxEmpty.new())
		t.set_color("font_color", cls, Color(0.92, 0.93, 0.9))
		t.set_color("font_hover_color", cls, Color(1, 1, 1))
	t.set_stylebox("normal", "LineEdit", _dock_style(Color(0.12, 0.13, 0.15), Color(0.3, 0.33, 0.36)))
	t.set_stylebox("focus", "LineEdit", _dock_style(Color(0.12, 0.13, 0.15), Color(0.95, 0.75, 0.3)))
	return t

var camp_panel: PanelContainer
var camp_box: VBoxContainer

func campaign_result(text: String) -> void:
	await get_tree().create_timer(2.5, true).timeout
	win.visible = false
	_show_campaign(text)

var camp_info: Label = null

var camp_view = -1        # an enemy army being looked at
var camp_result = ""

func _show_campaign(result: String = "") -> void:
	if Campaign.data.is_empty() and not Campaign.load_saved():
		Campaign.new_campaign()
	if Campaign.data.get("version", 1) != Campaign.VERSION:
		Campaign.new_campaign()
	if result != "":
		camp_result = result
	if camp_panel == null:
		camp_panel = _panel(Color(0.08, 0.095, 0.1, 0.985))
		var sbp: StyleBoxFlat = camp_panel.get_theme_stylebox("panel")
		sbp.set_corner_radius_all(8)
		sbp.set_border_width_all(1)
		sbp.border_color = Color(0.96, 0.74, 0.27, 0.35)
		sbp.set_content_margin_all(12)
		_place(camp_panel, Control.PRESET_CENTER, -620, -352, 1240, 704)
		camp_panel.z_index = 20
		camp_box = VBoxContainer.new()
		camp_box.add_theme_constant_override("separation", 6)
		camp_panel.add_child(camp_box)
		root.add_child(camp_panel)
	for c in camp_box.get_children():
		camp_box.remove_child(c)
		c.queue_free()
	var D = Campaign.data
	# the top bar: turn, war chest, ground held, who runs our side in battle
	var head = HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	head.add_child(_label("Campaign  ·  Turn %d" % D["turn"], 24, Color(0.97, 0.93, 0.82)))
	head.add_child(_label("War chest  %d  (+%d a turn)" % [D["funds"][0], Campaign.income(0)], 16, Color(1.0, 0.85, 0.4)))
	head.add_child(_label("Regions  %d : %d" % [D["owner"].count(0), D["owner"].count(1)], 16, Color(0.8, 0.85, 0.8)))
	var storm = D.get("weather", "") == "storm"
	var wl = _label("Weather  " + ("STORM, no aircraft" if storm else "clear"), 14, Color(0.6, 0.75, 1.0) if storm else Color(0.75, 0.8, 0.75))
	wl.tooltip_text = "A storm grounds every aircraft in this turn's battles: no air strikes, paratroopers, helicopters, fighters, bombers or recon planes." if storm else "Clear skies: air support can fly."
	wl.mouse_filter = Control.MOUSE_FILTER_STOP
	head.add_child(wl)
	var sp = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(_label("In battle:", 14, Color(0.75, 0.78, 0.75)))
	var oc = _option(["You command", "AI commander"], 1 if G.settings.get("ai_side", false) else 0)
	oc.item_selected.connect(func(i):
		G.settings["ai_side"] = i == 1
		G.save_prefs())
	oc.tooltip_text = "You command: you build and buy for your side in its battles. AI commander: it runs your side and you can watch or help."
	head.add_child(oc)
	camp_box.add_child(head)
	# the map on the left, the selected army on the right
	var body = HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	camp_box.add_child(body)
	body.add_child(_campaign_map())
	body.add_child(_campaign_side())
	camp_info = _label("", 14, Color(0.9, 0.92, 0.88))
	camp_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	camp_info.custom_minimum_size = Vector2(1200, 0)
	camp_box.add_child(camp_info)
	_campaign_info()
	var lg_lines: Array = []
	for l in camp_result.split("\n"):
		if l != "" and not (l in D["log"]):
			lg_lines.append(l)
	lg_lines += D["log"].slice(0, 3)
	var lg_txt = "\n".join(lg_lines.slice(0, 3))
	var lg = _label(lg_txt, 12, Color(0.72, 0.74, 0.7))
	lg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lg.custom_minimum_size = Vector2(1200, 0)
	camp_box.add_child(lg)
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var pend = Campaign.pending_battle()
	var done = Campaign.over()
	if pend != null:
		var fb = _button("  ⚔  Fight the battle  ", func():
			camp_panel.visible = false
			menu.visible = false
			camp_result = ""
			_close_title()
			Campaign._start_battle())
		fb.add_theme_font_size_override("font_size", 18)
		h.add_child(fb)
	elif done < 0:
		var eb = _button("  End turn  ▶  ", func():
			Campaign.selected = -1
			camp_view = -1
			var lines = Campaign.end_turn()
			camp_result = ""
			_show_campaign("\n".join(lines) if not lines.is_empty() else "Bravo holds its ground."))
		eb.add_theme_font_size_override("font_size", 18)
		h.add_child(eb)
	var sp2 = Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp2)
	h.add_child(_button("New campaign", func():
		Campaign.new_campaign()
		camp_result = ""
		_show_campaign()))
	h.add_child(_button("Close", func(): camp_panel.visible = false))
	camp_box.add_child(h)
	camp_panel.visible = true

# the right-hand panel: the army you've picked (its men, vehicles, roster and what you can buy for it),
# an enemy army you've clicked, or a list of your armies
func _campaign_side() -> Control:
	var D = Campaign.data
	var outer = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.14, 0.15, 1.0)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	outer.add_theme_stylebox_override("panel", sb)
	outer.custom_minimum_size = Vector2(CAMP_SIDE, CAMP_H)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	outer.add_child(v)
	var a = Campaign.army(Campaign.selected)
	if a == null and camp_view >= 0:
		a = Campaign.army(camp_view)
	if a == null:
		v.add_child(_label("Your armies", 18, Color(0.97, 0.93, 0.82)))
		for x in D["armies"]:
			if x["team"] != 0:
				continue
			var vehs = x["veh"].size()
			var t = "%s  ·  %s\n%d men%s%s%s" % [x["name"], Campaign.REGIONS[x["region"]]["name"], x["str"], ", %d vehicles" % vehs if vehs > 0 else "",
				"" if Campaign.supplied(0, x["region"]) else "  · CUT OFF", "  · moved" if x["moved"] else ""]
			var xid = x["id"]
			var bt = _button(t, func():
				Campaign.selected = xid
				camp_view = -1
				_show_campaign())
			bt.alignment = HORIZONTAL_ALIGNMENT_LEFT
			bt.add_theme_font_size_override("font_size", 13)
			v.add_child(bt)
		var why = Campaign.can_raise(0)
		var rb = _button("Raise a new army at HQ  (%d)" % Campaign.RAISE_COST, func():
			var r = Campaign.raise_army(0)
			_show_campaign("The new army is ready at Westfield." if r == "" else ""))
		rb.disabled = why != ""
		rb.tooltip_text = "Eight fresh men at HQ" if why == "" else why
		v.add_child(rb)
		if why != "":
			v.add_child(_label("  (" + why + ")", 12, Color(0.65, 0.65, 0.62)))
		return outer
	var mine = a["team"] == 0
	var tc = G.team_color(a["team"])
	v.add_child(_label(("⚑ " if mine else "✠ ") + a["name"], 19, tc.lerp(Color.WHITE, 0.5)))
	var sup = Campaign.supplied(a["team"], a["region"])
	v.add_child(_label("%s  ·  %s%s" % [Campaign.REGIONS[a["region"]]["name"], "in supply" if sup else "CUT OFF from supply", ("  ·  moved this turn" if a["moved"] else "  ·  ready to move") if mine else ""], 13, Color(0.8, 0.83, 0.8) if sup else Color(1.0, 0.5, 0.4)))
	if not mine:
		# what our scouts can tell
		var est = int(round(a["str"] / 5.0)) * 5
		v.add_child(_label("Scouts report about %d men%s." % [maxi(5, est), (" and %d vehicles" % a["veh"].size()) if a["veh"].size() > 0 else ""], 14))
		v.add_child(_button("Back", func():
			camp_view = -1
			_show_campaign()))
		return outer
	# men by class, and the vehicles
	var mk = Campaign.make_up(a)
	var parts = []
	for c in ["rifleman", "mg", "at", "assault", "engineer", "medic", "radio", "sniper", "spotter", "officer"]:
		if mk.has(c):
			parts.append("%s %d" % [Campaign.CLS_NAMES.get(c, c), mk[c]])
	var ml = _label("Men  %d / %d:  %s" % [a["str"], Campaign.MAX_STR, ",  ".join(parts)], 13, Color(0.92, 0.92, 0.88))
	ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ml.custom_minimum_size = Vector2(CAMP_SIDE - 24, 0)
	v.add_child(ml)
	var vn = a["veh"].map(func(k): return Vehicle.SPECS[k]["name"] if Vehicle.SPECS.has(k) else k)
	v.add_child(_label("Vehicles %d / %d:  %s" % [a["veh"].size(), Campaign.MAX_VEH, ", ".join(vn) if not vn.is_empty() else "none"], 13, Color(0.85, 0.88, 0.85)))
	# the roster: veterans first
	var sc = ScrollContainer.new()
	sc.custom_minimum_size = Vector2(CAMP_SIDE - 24, 112)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var rv = VBoxContainer.new()
	rv.add_theme_constant_override("separation", 0)
	sc.add_child(rv)
	var men = a["men"].duplicate()
	men.sort_custom(func(x, y): return x["vet"] * 100 + x["kills"] > y["vet"] * 100 + y["kills"])
	for m in men:
		var line = "%s  %s  —  %s%s" % ["★".repeat(m["vet"]) if m["vet"] > 0 else "·", m["name"], Campaign.CLS_NAMES.get(m["cls"], m["cls"]).trim_suffix("s").trim_suffix("me").replace("Riflemen", "Rifleman"), ("   %d kills, %d battles" % [m["kills"], m["battles"]]) if m["battles"] > 0 else ""]
		rv.add_child(_label(line, 12, Color(1.0, 0.86, 0.45) if m["vet"] >= 2 else Color(0.82, 0.84, 0.8)))
	v.add_child(_label("Roster", 14, Color(0.97, 0.93, 0.82)))
	v.add_child(sc)
	# recruiting
	v.add_child(_label("Recruit  (war chest %d)" % D["funds"][0], 14, Color(0.97, 0.93, 0.82)))
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	var aid = a["id"]
	for pk in Campaign.PACKS:
		var P = Campaign.PACKS[pk]
		var why = Campaign.can_buy(a, pk)
		var label = "%s  %d" % [P["name"], P["cost"]] + (("  +%d" % P["cls"].size()) if P.has("cls") else "")
		var key = pk
		var b = _button(label, func():
			var r = Campaign.buy(Campaign.army(aid), key)
			if r != "":
				message(r)
			_show_campaign())
		b.add_theme_font_size_override("font_size", 12)
		b.custom_minimum_size = Vector2((CAMP_SIDE - 30) / 2.0, 28)
		b.disabled = why != ""
		b.tooltip_text = why if why != "" else ("Adds " + ", ".join(P["cls"]) if P.has("cls") else "Adds a " + P["name"].to_lower())
		grid.add_child(b)
	v.add_child(grid)
	v.add_child(_button("All armies", func():
		Campaign.selected = -1
		camp_view = -1
		_show_campaign()))
	return outer

func _campaign_info() -> void:
	if camp_info == null:
		return
	var pend = Campaign.pending_battle()
	var done = Campaign.over()
	if done == 0:
		camp_info.text = "The Capital is ours. The campaign is won! Start a new one whenever you like."
	elif done == 1:
		camp_info.text = "Westfield has fallen. The campaign is lost."
	elif pend != null:
		camp_info.text = Campaign.battle_text() + ". Fight it out to see who holds the region."
	else:
		var a = Campaign.army(Campaign.selected)
		if a != null and a["moved"]:
			camp_info.text = "%s has moved this turn. You can still recruit for it on the right; End turn when you're done." % a["name"]
		elif a != null:
			camp_info.text = "%s (%d men%s) selected: click a neighbouring region (gold border) to move there. Enemy ground with an army in it means a battle; empty enemy ground is taken at once. Recruit for it on the right." % [a["name"], a["str"], "" if Campaign.supplied(0, a["region"]) else ", cut off"]
		else:
			var left = Campaign.data["armies"].filter(func(x): return x["team"] == 0 and not x["moved"]).size()
			camp_info.text = "Click one of your armies to see its men and recruit for it, and to move it (%d still to move this turn), then End turn. Armies in supply get recruits and fresh men; cut off, they lose men and get no reinforcements in battle." % left

const CAMP_W = 790.0
const CAMP_H = 440.0
const CAMP_SIDE = 398.0

func _campaign_map() -> Control:
	var m = Panel.new()
	m.custom_minimum_size = Vector2(CAMP_W, CAMP_H)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.24, 0.18)
	sb.set_corner_radius_all(6)
	m.add_theme_stylebox_override("panel", sb)
	var R = Campaign.REGIONS
	var own: Array = Campaign.data["owner"]
	var net = [Campaign.supply_net(0), Campaign.supply_net(1)]
	var sel = Campaign.army(Campaign.selected)
	# roads between regions
	for l in Campaign.LINKS:
		var a: Vector2 = R[l[0]]["p"] * Vector2(CAMP_W, CAMP_H)
		var b: Vector2 = R[l[1]]["p"] * Vector2(CAMP_W, CAMP_H)
		var ln = Line2D.new()
		ln.points = PackedVector2Array([a, b])
		ln.width = 5.0
		var o0 = own[l[0]]
		var o1 = own[l[1]]
		ln.default_color = (G.team_color(o0).darkened(0.35) if o0 == o1 else Color(0.85, 0.75, 0.4, 0.9))
		m.add_child(ln)
	for i in range(R.size()):
		var r = R[i]
		var c: Vector2 = r["p"] * Vector2(CAMP_W, CAMP_H)
		var o: int = own[i]
		var cut = not net[o].has(i)
		var txt = "%s%s\n%s · %s" % [r["name"], "  ★" if r.has("hq") else "", r["map"], r["mode"]]
		if cut:
			txt += "\ncut off"
		var nr = Campaign.ruins(i).size()
		if nr > 0:
			txt += "\n%d in ruins" % nr
		var idx = i
		var b = _button(txt, func(): _campaign_click(idx))
		b.add_theme_font_size_override("font_size", 12)
		b.size = Vector2(136, 62)
		b.position = c - Vector2(68, 50)
		var target = sel != null and Campaign.can_move(sel, i)
		var bg = G.team_color(o).darkened(0.45 if not cut else 0.65)
		var border = G.team_color(o).lightened(0.2)
		if target:
			border = Color(1.0, 0.88, 0.35)
			bg = bg.lerp(Color(0.55, 0.45, 0.1), 0.35)
		elif sel != null:
			bg = bg.darkened(0.35)
		for st in ["normal", "hover", "pressed", "disabled"]:
			var sbx = StyleBoxFlat.new()
			sbx.bg_color = bg.lightened(0.12) if st == "hover" else bg
			sbx.set_corner_radius_all(6)
			sbx.set_border_width_all(3 if target else 2)
			sbx.border_color = border
			if cut:
				sbx.border_blend = true
			b.add_theme_stylebox_override(st, sbx)
		b.add_theme_color_override("font_color", Color(0.96, 0.95, 0.9))
		b.add_theme_color_override("font_hover_color", Color(1, 1, 0.85))
		m.add_child(b)
		# armies standing here
		var k = 0
		for a in Campaign.data["armies"]:
			if a["region"] != i:
				continue
			var mine = a["team"] == 0
			var at = "%s %s  %d" % ["⚑" if mine else "✠", a["name"], a["str"]]
			if mine and a["moved"]:
				at += " ✓"
			var aid = a["id"]
			var ab = _button(at, func(): _campaign_army(aid))
			ab.add_theme_font_size_override("font_size", 12)
			ab.size = Vector2(150, 24)
			ab.position = c + Vector2(-75, 14 + k * 26)
			var ac = G.team_color(a["team"])
			var abg = Color(0.1, 0.1, 0.1, 0.92)
			if mine and Campaign.selected == aid:
				abg = Color(0.55, 0.45, 0.08)
			for st in ["normal", "hover", "pressed"]:
				var sba = StyleBoxFlat.new()
				sba.bg_color = abg.lightened(0.15) if st == "hover" else abg
				sba.set_corner_radius_all(10)
				sba.set_border_width_all(2)
				sba.border_color = ac.darkened(0.4) if (mine and a["moved"]) else ac
				ab.add_theme_stylebox_override(st, sba)
			ab.add_theme_color_override("font_color", (ac.lerp(Color.WHITE, 0.55) if not (mine and a["moved"]) else Color(0.6, 0.6, 0.6)))
			m.add_child(ab)
			k += 1
	return m

func _campaign_army(id: int) -> void:
	var a = Campaign.army(id)
	if a == null or Campaign.pending_battle() != null or Campaign.over() >= 0:
		return
	if a["team"] != 0:
		var sel_a = Campaign.army(Campaign.selected)
		if sel_a != null and Campaign.can_move(sel_a, a["region"]):
			_campaign_click(a["region"])
			return
		camp_view = id
		Campaign.selected = -1
		_show_campaign()
		return
	camp_view = -1
	Campaign.selected = id if Campaign.selected != id else -1
	_show_campaign()

func _campaign_click(i: int) -> void:
	if Campaign.pending_battle() != null or Campaign.over() >= 0:
		return
	var a = Campaign.army(Campaign.selected)
	if a == null or a["moved"]:
		var mine = Campaign.army_at(i, 0)
		if mine != null:
			Campaign.selected = mine["id"]
			camp_view = -1
			_show_campaign()
		return
	if not Campaign.can_move(a, i):
		Campaign.selected = -1
		_show_campaign()
		return
	Campaign.selected = -1
	var res = Campaign.move(a, i)
	if res == "battle":
		camp_panel.visible = false
		menu.visible = false
		_close_title()
		return
	_show_campaign(res)

var daily_panel: PanelContainer
var daily_lbl: Label

# today's challenge: the same battle for everyone, picked from the date
func _show_daily() -> void:
	if daily_panel == null:
		daily_panel = _panel(Color(0.11, 0.13, 0.15, 0.97))
		_place(daily_panel, Control.PRESET_CENTER, -280, -130, 560, 260)
		var v = VBoxContainer.new()
		v.add_child(_label("Daily challenge", 24))
		daily_lbl = _label("", 15, Color(0.88, 0.9, 0.85))
		daily_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		daily_lbl.custom_minimum_size = Vector2(520, 110)
		v.add_child(daily_lbl)
		var h = HBoxContainer.new()
		h.add_child(_button("Play today's battle", func():
			daily_panel.visible = false
			menu.visible = false
			help.visible = false
			Modes.start_daily()))
		h.add_child(_button("Close", func(): daily_panel.visible = false))
		v.add_child(h)
		daily_panel.add_child(v)
		root.add_child(daily_panel)
	var c = Modes.daily_config()
	daily_lbl.text = Modes.daily_text(c) + "\n\n" + Obj.MODE_INFO.get(c["mode"], "")
	daily_panel.visible = true

var scen_panel: PanelContainer
var scen_text: TextEdit
var scen_msg: Label

func _show_scenario() -> void:
	if scen_panel == null:
		scen_panel = _panel(Color(0.11, 0.13, 0.15, 0.97))
		_place(scen_panel, Control.PRESET_CENTER, -300, -200, 600, 400)
		var v = VBoxContainer.new()
		v.add_child(_label("Scenario code", 24))
		v.add_child(_label("Save the battle as it stands (armies, vehicles, bases and orders) as a code you can share, or paste a code to load it.", 13, Color(0.8, 0.8, 0.8)))
		scen_text = TextEdit.new()
		scen_text.custom_minimum_size = Vector2(560, 200)
		scen_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		v.add_child(scen_text)
		scen_msg = _label("", 13, Color(1, 0.85, 0.4))
		v.add_child(scen_msg)
		var h = HBoxContainer.new()
		h.add_child(_button("Make code from this battle", func():
			if not G.started:
				scen_msg.text = "Start a battle first"
				return
			var code = Scenario.encode(Scenario.capture())
			scen_text.text = code
			DisplayServer.clipboard_set(code)
			scen_msg.text = "Code made and copied (%d characters). You can also select it and copy it yourself." % code.length()))
		h.add_child(_button("Load this code", func():
			var d = Scenario.decode(scen_text.text)
			if d == null:
				scen_msg.text = "That doesn't look like a scenario code"
				return
			scen_panel.visible = false
			menu.visible = false
			Scenario.apply(d)))
		h.add_child(_button("Close", func(): scen_panel.visible = false))
		v.add_child(h)
		scen_panel.add_child(v)
		root.add_child(scen_panel)
	scen_msg.text = ""
	scen_panel.visible = true

func _deploy() -> void:
	Modes.daily = {}
	Campaign.active = false
	if seed_edit != null and seed_edit.text.strip_edges() != "":
		var t = seed_edit.text.strip_edges()
		G.random_seed = int(t) if t.is_valid_int() else t.hash()
	var mid = _map_id(opt_map.selected)
	G.main.start_game({"map": mid, "mode": MODE_IDS[opt_mode.selected],
		"size": int(opt_size.get_item_text(opt_size.selected)), "limit": _limit_value(),
		"reinforce": opt_reinf.selected != 4 or opt_reinf.disabled, "reinf_mode": ["truck", "para", "heli", "instant", "truck"][opt_reinf.selected],
		"armor": ["none", "light", "heavy"][opt_armor.selected], "teams": opt_teams.selected + 2,
		"factions": [Faction.LIST[opt_fac0.selected], Faction.LIST[opt_fac1.selected], "army", "army"]})
	G.save_prefs()
	menu.visible = false
	title.visible = false
	help.visible = false

# only the modes that end on a number get one to set, and each gets its own kind of number
const LIMITS = {
	"deathmatch": ["Kills to win", [25, 50, 100, 200], 1],
	"capture": ["Points to win", [100, 200, 400, 800], 1],
	"koth": ["Points to win", [60, 120, 240, 480], 1],
	"frontline": ["Tickets per side", [50, 100, 200, 400], 1],
	"assault": ["Attackers' tickets", [50, 100, 200, 400], 1],
	"breakthrough": ["Attackers' tickets", [50, 100, 200, 400], 1],
	"siege": ["Town's supplies", [60, 100, 160, 240], 1],
}
var limit_row: HBoxContainer
var limit_lbl: Label

func _fill_limits() -> void:
	if opt_limit == null or opt_mode == null:
		return
	var id = MODE_IDS[clampi(opt_mode.selected, 0, MODE_IDS.size() - 1)]
	var L = LIMITS.get(id)
	limit_row.visible = L != null
	if L == null:
		return
	limit_lbl.text = L[0]
	opt_limit.clear()
	for n in L[1]:
		opt_limit.add_item(str(n))
	opt_limit.select(L[2])

func _limit_value() -> int:
	var id = MODE_IDS[clampi(opt_mode.selected, 0, MODE_IDS.size() - 1)]
	if not LIMITS.has(id):
		return 999999
	return int(opt_limit.get_item_text(opt_limit.selected))

func _show_mode_info() -> void:
	_fill_limits()
	if mode_info != null:
		var id = MODE_IDS[clampi(opt_mode.selected, 0, MODE_IDS.size() - 1)]
		var extra = ""
		if id in ["frontline", "assault", "laststand", "breakthrough", "sabotage", "siege", "escort", "rescue", "koth", "commander", "horde", "general"]:
			extra = "  (two sides only)"
		mode_info.text = Obj.MODE_INFO.get(id, "")
		if mode_title != null:
			mode_title.text = opt_mode.get_item_text(opt_mode.selected)
			mode_rules.text = ("" if id == "sandbox" else Rules.mode_text(id)) + (" · two sides only" if extra != "" else "")
		_mode_settings(id)

# settings that mean nothing in a mode are greyed out (and the mode's own value shown)
func _mode_settings(id: String) -> void:
	if opt_teams == null:
		return
	var multi = id in ["sandbox", "deathmatch", "capture", "destroy"]
	opt_teams.disabled = not multi
	if not multi:
		opt_teams.select(0)
	# waves, raids and bought troops: the mode decides who turns up
	var own_reinf = id in ["laststand", "horde", "sabotage", "commander"]
	opt_reinf.disabled = own_reinf
	opt_reinf.tooltip_text = "This mode brings in its own troops" if own_reinf else ""
	# no starting vehicles in the raid, the last stand or against the dead
	var no_armor = id in ["sabotage", "horde", "laststand"]
	opt_armor.disabled = no_armor
	if no_armor:
		opt_armor.select(0)
	# the raid is always at night
	opt_time.disabled = id == "sabotage"
	if id == "sabotage":
		opt_time.select(2)
	# the other side is the walking dead
	opt_fac1.disabled = id == "horde"
	# where more men come in later, the number set here is what each side starts with
	if size_lbl != null:
		size_lbl.text = {"laststand": "Defenders", "horde": "Survivors at the start", "sabotage": "Raiders", "commander": "Starting troops per side",
			"general": "Soldiers per side"}.get(id, "Soldiers per side at the start" if id != "sandbox" or opt_reinf.selected != 4 else "Soldiers per side")

# the title screen (and, during a battle, the pause menu)
var title: Control
var title_box: VBoxContainer
var title_sub: Label

var title_tip: Label
var tip_i = 0
var tip_t = 0.0
const TITLE_TIPS = ["Right-click one of your vehicles or a mortar with soldiers selected and they'll climb in or man it.",
	"Select soldiers and right-click a structure that's going up: they'll go and build it.",
	"F2 switches night vision on and off.",
	"F9 shows the path debug view: planned routes, vehicle aim points and danger spots.",
	"Ctrl+number saves a selection as a group; the number brings it back, twice to look at it.",
	"Medics drag the wounded to cover or carry them back to a field hospital on a stretcher.",
	"Machine gunners are far more accurate once the bipod is down.",
	"In commander mode the HQ can't be shelled: it has to be taken on the ground.",
	"Mine plough tanks clear mines and roadside bombs in front of them.",
	"Supply dumps only pay when a convoy gets through, and the enemy knows it.",
	"At night, headlights give a vehicle away from far off."]

func _build_title() -> void:
	title = Control.new()
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	# a dark wash down the left, fading out over the slowly turning battlefield
	var g = Gradient.new()
	g.set_color(0, Color(0.02, 0.025, 0.03, 0.94))
	g.set_color(1, Color(0.02, 0.025, 0.03, 0.0))
	g.add_point(0.62, Color(0.02, 0.025, 0.03, 0.86))
	var gt = GradientTexture2D.new()
	gt.gradient = g
	gt.width = 256
	gt.height = 4
	var shade = TextureRect.new()
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(shade, Control.PRESET_LEFT_WIDE, 0, 0, 640, 0)
	title.add_child(shade)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_place(v, Control.PRESET_LEFT_WIDE, 56, 30, 380, -20)
	title.add_child(v)
	# the name on one line: TIN HAT in white, TACTICS in amber
	var lh = HBoxContainer.new()
	lh.add_theme_constant_override("separation", 12)
	var logo = _label("TIN HAT", 44, Color(0.97, 0.95, 0.9))
	logo.add_theme_constant_override("outline_size", 10)
	lh.add_child(logo)
	var logo2 = _label("TACTICS", 44, Color(0.96, 0.74, 0.27))
	logo2.add_theme_constant_override("outline_size", 10)
	lh.add_child(logo2)
	v.add_child(lh)
	var rule = ColorRect.new()
	rule.color = Color(0.96, 0.74, 0.27, 0.8)
	rule.custom_minimum_size = Vector2(120, 3)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(rule)
	title_sub = _label("Battles that play themselves, until you step in.", 14, Color(0.78, 0.8, 0.77))
	title_sub.autowrap_mode = TextServer.AUTOWRAP_WORD
	title_sub.custom_minimum_size = Vector2(370, 0)
	v.add_child(title_sub)
	var gap = Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	v.add_child(gap)
	title_box = VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 4)
	v.add_child(title_box)
	# a tip along the bottom of the screen
	title_tip = _label("", 13, Color(0.86, 0.86, 0.8))
	title_tip.autowrap_mode = TextServer.AUTOWRAP_WORD
	title_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(title_tip, Control.PRESET_BOTTOM_RIGHT, -560, -46, 530, 36)
	title.add_child(title_tip)
	tip_i = randi() % TITLE_TIPS.size()
	title_tip.text = "TIP  ·  " + TITLE_TIPS[tip_i]
	root.add_child(title)
	_fill_title()

func _tip_tick(dt: float) -> void:
	if title_tip == null or not title.visible:
		return
	tip_t += dt
	if tip_t > 9.0:
		tip_t = 0.0
		tip_i = (tip_i + 1) % TITLE_TIPS.size()
		title_tip.text = "TIP  ·  " + TITLE_TIPS[tip_i]

# a menu entry: a title and a line under it, with a coloured bar down the left edge that lights up on hover
func _title_button(text: String, sub: String, cb: Callable, big: bool = false) -> void:
	var b = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	b.custom_minimum_size = Vector2(370, 56 if big else (42 if sub != "" else 34))
	var accent = Color(0.96, 0.74, 0.27)
	var n = StyleBoxFlat.new()
	n.bg_color = Color(0.8, 0.6, 0.18, 0.95) if big else Color(1, 1, 1, 0.04)
	n.set_corner_radius_all(4)
	n.border_width_left = 4
	n.border_color = accent if big else Color(1, 1, 1, 0.12)
	n.set_content_margin_all(0)
	var h = n.duplicate()
	h.bg_color = Color(0.92, 0.7, 0.25, 1.0) if big else Color(1, 1, 1, 0.1)
	h.border_color = accent
	var pr = h.duplicate()
	pr.bg_color = Color(0.7, 0.5, 0.15, 1.0) if big else Color(0.96, 0.74, 0.27, 0.18)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", pr)
	var lv = VBoxContainer.new()
	lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lv.add_theme_constant_override("separation", -2)
	lv.alignment = BoxContainer.ALIGNMENT_CENTER
	_place(lv, Control.PRESET_FULL_RECT, 16, 0, -16, 0)
	lv.anchor_right = 1.0
	lv.anchor_bottom = 1.0
	lv.offset_right = -10
	lv.offset_bottom = 0
	var tl = _label(text, 22 if big else 16, Color(0.08, 0.07, 0.05) if big else Color(0.95, 0.94, 0.9))
	if big:
		tl.add_theme_constant_override("outline_size", 0)
	lv.add_child(tl)
	if sub != "":
		var sl = _label(sub, 13 if big else 12, Color(0.22, 0.18, 0.1) if big else Color(0.66, 0.68, 0.65))
		if big:
			sl.add_theme_constant_override("outline_size", 0)
		lv.add_child(sl)
	b.add_child(lv)
	title_box.add_child(b)

func _title_header(text: String) -> void:
	var l = _label(text, 11, Color(0.96, 0.74, 0.27, 0.9))
	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_top", 8)
	m.add_child(l)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_box.add_child(m)

func _fill_title() -> void:
	for c in title_box.get_children():
		c.queue_free()
	if G.started and not G.attract:
		title_sub.text = "Paused · %s on %s" % [G.mode.capitalize(), G.world.MAPS.get(G.map_id, {}).get("name", G.map_id) if G.world != null else ""]
		_title_button("▶  Resume", "back to the battle", func(): _close_title(), true)
		_title_button("Restart this battle", "same map, mode and forces", func():
			_close_title()
			_deploy())
		_title_button("New battle…", "pick a map, a mode and your forces", func(): _open_setup())
		_title_button("Battle report", "who killed whom, and how", func(): show_report())
	else:
		title_sub.text = "Battles that play themselves, until you step in: drop in soldiers, take over anyone, or command from above."
		_title_button("▶  Quick battle", "pick a map, a mode and your forces", func(): _open_setup(), true)
		_title_header("PLAY")
		_title_button("First battle", "a guided fight: learn to command in five minutes", func():
			G.main.stop_attract()
			title.visible = false
			menu.visible = false
			Tutorial.start())
		_title_button("Commander", "fight a battle from above, RTS style", func(): _quick("commander"))
		_title_button("Campaign", "twelve regions, one battle at a time", func(): _show_campaign())
		_title_button("Zombie horde", "hold out against the waves", func(): _quick("horde"))
		_title_button("Battle builder", "set out both armies yourself, then press Start and watch", func():
			builder_next = true
			_quick("sandbox"))
		_title_header("CREATE")
		_title_button("Map editor", "build, paint and script your own maps", func():
			G.main.stop_attract()
			title.visible = false
			G.editor.new_map(Vector2(260, 190)))
		_title_button("Scenario code", "save or load a battle as a code", func(): _show_scenario())
	var gap = Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	title_box.add_child(gap)
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	for e in [["Teams", func(): _show_teams()], ["Settings", func(): _show_settings()], ["Controls", func(): help.visible = true]]:
		var b = _button(e[0], e[1])
		b.custom_minimum_size = Vector2(119, 34)
		h.add_child(b)
	title_box.add_child(h)
	if G.started:
		_title_button("Quit to title screen", "", func():
			G.main.quit_to_title()
			show_menu())

func _open_setup() -> void:
	title.visible = false
	menu.visible = true
	_fade_in(menu)

func _close_title() -> void:
	title.visible = false
	get_tree().paused = false
	if G.player != null:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# one click into a mode from the title screen, with sensible settings
func _quick(mode: String) -> void:
	var i = MODE_IDS.find(mode)
	if i >= 0:
		opt_mode.select(i)
		_show_mode_info()
	title.visible = false
	_deploy()

func show_menu() -> void:
	_fill_title()
	title.visible = true
	_fade_in(title)
	menu.visible = false
	if G.started and not G.over:
		get_tree().paused = true
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
		"  Right-drag  look around · Left-click  use the selected tool · 1–9  pick a card on the tool dock\n" + \
		"  Placing a building: a blueprint follows the mouse (red = no room), the arrow is its front · hold right-click and move, or R, to turn it\n" + \
		"  F  take control of the soldier at the centre of the screen\n" + \
		"  T  slow-mo · P  pause · M  menu · Tab  commander's map (select squads, right-click to send them)\n" + \
		"  V  top-down commander view: WASD pans, wheel zooms, Q/E turn, click a soldier to select his squad, 1–9 pick a squad (press again to look at it)\n\n" + \
		"CONTROLLING A SOLDIER\n" + \
		"  Mouse  aim · Left-click  fire · Right mouse  aim down sights\n" + \
		"  Q / E  lean · Shift  sprint · C  crouch · Z  prone · run into low walls or window sills to vault through\n" + \
		"  Walk into the foot of a ladder to climb onto a flat roof (walk to the gap in the parapet to climb down)\n" + \
		"  Deep water: you swim, slowly, with your rifle slung (no shooting); shallow water slows you down\n" + \
		"  R  reload · G  grenade · V  smoke · 1–5  rifle, machine gun, sniper, shotgun, rockets\n" + \
		"  H  put a field dressing on your wound (or on a bleeding friend next to you) — wounds bleed until dressed\n" + \
		"  F  take the gun (or ammo) of a fallen soldier at your feet · stand at an ammo crate to restock\n" + \
		"  B  class action (engineer: sandbags/repair · medic: heal · radio: artillery on crosshair · sniper/spotter: mark target)\n" + \
		"  N  place a mine (Shift+N anti-tank) · K  satchel charge · 1–9  rifle, MG, sniper, shotgun, bazooka, SMG, pistol, flamethrower, AT rifle · 0  panzerfaust\n" + \
		"  Y  first-person / third-person view · L  fire a flare · Esc  free the mouse · X  leave the soldier\n" + \
		"  U (hold)  help build a friendly construction site · I  dismantle what you aim at (within 6 m)\n" + \
		"  Shift+G  cook a grenade · middle mouse  rifle grenade · Shift+K  sticky bomb · Shift+V  red smoke (calls artillery)\n" + \
		"  T  flashlight · F next to a wounded friend: carry them · F at a crate: pick up an ammo box, F again to drop it\n" + \
		"  F on an enemy right in front of you: knife · F at a militia tunnel mouth: out the other end · I at enemy wire: cut it\n" + \
		"  Walk into a closed door to kick it open · F at a window: smash the glass · grenades go in through windows\n" + \
		"  In a vehicle: Q tows a gun or broken vehicle (bridge layer: Q lays the bridge) · planes: mouse steers, Shift+click bombs\n" + \
		"  F  next to a vehicle: get in · in a vehicle: WASD drive, mouse aim, click fire, 1–4 change seat, F get out\n\n" + \
		"BATTLE\n" + \
		"  Squad leaders carry a radio antenna. Soldiers who lose friends, their leader or come under heavy fire\n" + \
		"  get shaken, and may break and run to the rear until a leader rallies them.\n" + \
		"  Bullets go through thin walls, crates and hedges. Every building can be blown apart. J  battle report\n" + \
		"  Artillery, air support and reinforcements need a radio: a radio operator, a command truck or a radio mast.\n" + \
		"  Without one, a runner has to carry the request back to HQ on foot. Scouts creep ahead and radio what they see.\n" + \
		"  Each commander has a personality (reckless, cautious or cunning); defenders who haven't been seen hold fire to spring an ambush.\n" + \
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
	return menu.visible or (title != null and title.visible) or help.visible or win.visible or (report != null and report.visible) or (scen_panel != null and scen_panel.visible) or (camp_panel != null and camp_panel.visible) or (teams_panel != null and teams_panel.visible) or (settings_panel != null and settings_panel.visible)

func typing() -> bool:
	return false

# ---------------------------------------------------------------- per-frame
func _unhandled_key_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and binding != "":
		# waiting for the new key for an action in the settings
		if ev.keycode != KEY_ESCAPE:
			Keys.set_key(binding, ev.keycode)
		binding = ""
		_show_settings()
		get_viewport().set_input_as_handled()
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		var kc = Keys.logical(ev.keycode)
		if kc == KEY_TAB and G.started and not menu_open():
			if tacmap == null:
				tacmap = preload("res://scripts/tacmap.gd").new()
				root.add_child(tacmap)
			tacmap.toggle()
		elif kc == KEY_M and G.started:
			show_menu()
		elif kc == KEY_H and G.player != null and is_instance_valid(G.player) and G.player.state == "alive" and not menu_open():
			Medical.player_dress(G.player)
		elif kc == KEY_H:
			help.visible = not help.visible
		elif kc == KEY_F2 and G.started:
			toggle_nv()
		elif kc == KEY_F9 and G.started:
			G.navviz.toggle()
		elif kc == KEY_SPACE and G.started and Prep.active() and G.player == null:
			Prep.finish()
		elif kc == KEY_J and G.started:
			if report != null and report.visible:
				report.visible = false
			else:
				show_report()
		elif kc == KEY_ESCAPE and help.visible:
			help.visible = false
		elif kc == KEY_ESCAPE and menu.visible:
			menu.visible = false
			show_menu()
		elif kc == KEY_ESCAPE and title.visible and G.started and not G.attract:
			_close_title()
		elif kc == KEY_ESCAPE and G.started and G.player == null:
			show_menu()

var perf_lbl: Label = null
var perf_t = 0.0

# frame rate, soldiers (and how many are simplified far away), cost of a simulation tick
func _perf(dt: float) -> void:
	if perf_lbl == null:
		perf_lbl = _label("", 13, Color(0.85, 0.95, 0.8))
		_place(perf_lbl, Control.PRESET_TOP_RIGHT, -620, 6, 610, 20)
		perf_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		root.add_child(perf_lbl)
	perf_lbl.visible = G.settings["fps"] and G.started
	if not perf_lbl.visible:
		return
	perf_t -= dt
	if perf_t > 0.0:
		return
	perf_t = 0.5
	var n = 0
	var far = 0
	for s in G.soldiers:
		if s.state != "dead":
			n += 1
			if s.lod_frozen:
				far += 1
	var fps = Engine.get_frames_per_second()
	perf_lbl.text = "%d fps · %d soldiers (%d simplified) · %d vehicles · sim %.1f ms · %d draws" % [fps, n, far, G.vehicles.size(), G.main.sim_ms, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))]
	perf_lbl.add_theme_color_override("font_color", Color(0.85, 0.95, 0.8) if fps >= 45 else (Color(1.0, 0.85, 0.4) if fps >= 25 else Color(1.0, 0.45, 0.4)))

var attract_hud = false

func update_hud(dt: float) -> void:
	# while the title-screen battle plays, only the title (and any menu opened from it) is shown: the rest
	# of the HUD is made see-through (not hidden, so nothing that toggles its own visibility fights this)
	if G.attract:
		if not attract_hud and title.get_index() < root.get_child_count() - 1:
			root.move_child(title, -1)        # above the (see-through) HUD, so it gets the clicks
		attract_hud = true
		var keep = [title, menu, help, win, report, scen_panel, camp_panel, teams_panel, settings_panel]
		for c in root.get_children():
			if not (c in keep) and c is CanvasItem and c.modulate.a > 0.0:
				c.modulate.a = 0.0
				c.set_meta("att_hid", true)
		if G.editor.active:
			G.main.stop_attract()
	elif attract_hud:
		attract_hud = false
		for c in root.get_children():
			if c.has_meta("att_hid"):
				c.modulate.a = 1.0
				c.remove_meta("att_hid")
	_perf(dt)
	prep_box.visible = G.started and Prep.active() and not menu_open()
	if prep_box.visible:
		prep_lbl.text = Prep.banner()
	_tip_tick(dt)
	_order_card_tick()
	dock_status_t -= dt
	if dock_status != null and dock_status_t <= 0.0:
		dock_status_t = 0.5
		dock_status.text = Prod.status(0) if Prod.active() and G.started else ""
		var sig2 = ""
		if tab == "upgrades" and Prod.active():
			sig2 = str(Prod.done[0].keys()) + str(Prod.research[0].size())
		elif tab == "logistics":
			sig2 = "L%d%s" % [Logistics.count(0), Logistics.has_stop(0)]
		elif tab in ["armour", "support", "recruit"] and G.mode == "commander":
			# a depot, radio mast or hospital just finished (or was lost): the cards change
			for k in ["jeep", "artillery", "airstrike", "ambulance"]:
				sig2 += "1" if Support.unlocked(0, k) else "0"
			sig2 += Support.need_text("jeep")
		if sig2 != "" and sig2 != up_sig:
			up_sig = sig2
			_render_tools()
	_info_tick(dt)
	if nv != null and nv.visible:
		(nv.material as ShaderMaterial).set_shader_parameter("t", fmod(Time.get_ticks_msec() * 0.001, 100.0))
	# once it gets dark, say how to see
	if G.started and G.main.is_night() and not nv_hinted:
		nv_hinted = true
		message("It's dark: F2 for night vision")
	if vignette != null:
		var want = 0.0
		if G.player != null and is_instance_valid(G.player) and G.player.state != "dead":
			want = clampf(G.player.supp / 1.2, 0.0, 1.0) * 0.85 + (0.35 if G.player.hp < 35.0 else 0.0) + (0.25 + 0.15 * sin(Time.get_ticks_msec() * 0.006) if G.player.bleed > 0.0 else 0.0)
		var m: ShaderMaterial = vignette.material
		var cv = m.get_shader_parameter("amount")
		var cur: float = cv if cv != null else 0.0
		m.set_shader_parameter("amount", lerpf(cur, want, minf(1.0, dt * 5.0)))
	var cap = G.mode in ["capture", "koth"]
	var tick = G.mode == "frontline"
	lbl_sa.text = str(int(G.cap_score[0])) if cap else (str(Obj.tickets[0]) if tick and not Obj.tickets.is_empty() else str(G.score[0]))
	lbl_sb.text = str(int(G.cap_score[1])) if cap else (str(Obj.tickets[1]) if tick and not Obj.tickets.is_empty() else str(G.score[1]))
	# a score only shows when the mode is decided by it (kills, points or tickets)
	var counts = cap or tick or G.mode == "deathmatch"
	lbl_sa.get_parent().visible = counts
	lbl_sb.get_parent().visible = counts
	var t = int(G.game_time)
	lbl_clock.text = "%02d:%02d" % [t / 60, t % 60]
	if G.settings["time"] == "dawn" or G.settings["time"] == "cycle":
		lbl_clock.text += "  ·  " + G.main.hour_text()
	if get_tree().paused:
		lbl_mode.text = "paused"
	elif Engine.time_scale < 0.5:
		lbl_mode.text = "slow-mo"
	elif G.mode == "sandbox":
		lbl_mode.text = "sandbox"
	elif cap:
		lbl_mode.text = "first to %d points" % G.limit
	elif G.mode == "deathmatch":
		lbl_mode.text = "first to %d" % G.limit
	else:
		lbl_mode.text = Obj.status_text()
	if G.started and not G.over and G.mode != "sandbox" and not Comms.queue.is_empty() and not Comms.ok(0) and not get_tree().paused:
		lbl_mode.text += ("  ·  " if lbl_mode.text != "" else "") + ("no radio: runner on the way" if Comms.runner[0] != null else "no radio")
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
	btn_reinf.visible = G.mode == "sandbox"        # in a battle the mode decides
	side.visible = show_game
	var ctl = G.player != null
	dock.visible = show_game and not ctl
	if dock.visible:
		_dock_points()
	phud.visible = ctl
	cmd_panel.visible = false
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
		if s.state == "riding" and s.vehicle != null and is_instance_valid(s.vehicle):
			var rv = s.vehicle
			p_ammo.text = "%s  ·  armour %d%%" % [rv.spec["name"], int(100.0 * rv.hp / rv.spec["hp"])]
			if not rv.spec.get("static", false):
				p_ammo.text += "  ·  fuel %d%%" % int(rv.fuel * 100.0)
			if rv.kind in ["mortar", "artillery"]:
				p_ammo.text += "  ·  rounds %d" % rv.shells
			if rv.gun_heat > 0.05:
				p_ammo.text += "  ·  barrel %d%%" % int(rv.gun_heat * 100.0)
			if rv.towing != null:
				p_ammo.text += "  ·  towing"
			if rv.tracks_broken:
				p_ammo.text += "  ·  immobilised"
			if rv.spec.get("plane", false):
				p_ammo.text += "  ·  alt %d m" % int(rv.alt)
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
		if s.bandage_t > 0.0:
			p_ammo.text += "     dressing a wound…"
		elif s.bleed > 0.0 and s.state != "dead":
			p_ammo.text += "     BLEEDING — H to dress it (%d dressing%s)" % [s.dressings, "" if s.dressings == 1 else "s"]
		tip.text = "" if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else "Click to aim — X to leave this soldier"
	else:
		tip.text = (TIPS.get(tool, "") if not tool.begins_with("h:") else Modes.SHOP[tool.substr(2)]["tip"]) if show_game else ""
		if show_game and tool.begins_with("sup:"):
			tip.text = "Click the map where the %s should hit · supply points come over time, for kills and for holding points" % Support.NAMES[tool.substr(4)].to_lower()
		elif show_game and tool.begins_with("v:"):
			tip.text = "Click the ground to drop this vehicle with its crew"
		elif show_game and tool.begins_with("b:"):
			tip.text = "Click to mark out a %s for %s (engineers build it) · hold right-click and move the mouse, or press R, to turn it · the arrow is its front" % [Build.KINDS[tool.substr(2)]["name"], G.TEAM_NAMES[0 if G.mode == "commander" else mini(build_team, G.team_count() - 1)]]
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
			msg.visible = false

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
	# supply: what each side has taken in so far (bold) and has in hand (faint)
	var tl0 = Stats.timeline
	if tl0.size() >= 2 and tl0[tl0.size() - 1].size() > 4:
		var last = tl0[tl0.size() - 1]
		var mins = maxf(1.0, (last[0] - tl0[0][0]) / 60.0)
		var parts = []
		for ti in range(G.team_count()):
			if ti < last[4].size():
				parts.append("%s %d (%.1f a minute)" % [G.TEAM_NAMES[ti], last[4][ti], last[4][ti] / mins])
		report_body.add_child(_label("Supply taken in over the battle (bold) and in hand (faint) · " + " · ".join(parts), 16))
		supply_chart = Control.new()
		supply_chart.custom_minimum_size = Vector2(820, 120)
		supply_chart.draw.connect(_draw_supply_chart)
		report_body.add_child(supply_chart)
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

var supply_chart: Control = null

func _draw_supply_chart() -> void:
	var c = supply_chart
	var w = c.size.x
	var h = c.size.y
	c.draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, 0.04))
	var tl = Stats.timeline.filter(func(e): return e.size() > 4)
	if tl.size() < 2:
		return
	var t0 = tl[0][0]
	var t1 = maxf(tl[tl.size() - 1][0], t0 + 1.0)
	var top = 1.0
	for e in tl:
		for v in e[4]:
			top = maxf(top, v)
		for v in e[3]:
			top = maxf(top, v)
	for ti in range(G.team_count()):
		for k in [3, 4]:
			var pts = PackedVector2Array()
			for e in tl:
				if ti < e[k].size():
					pts.append(Vector2((e[0] - t0) / (t1 - t0) * (w - 10.0) + 5.0, h - 6.0 - e[k][ti] / top * (h - 16.0)))
			if pts.size() > 1:
				var col = G.TEAM_BAND[ti].lightened(0.2)
				if k == 3:
					col.a = 0.45
				c.draw_polyline(pts, col, 2.5 if k == 4 else 1.5, true)
	c.draw_string(ThemeDB.fallback_font, Vector2(8, 14), str(int(top)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 0.7, 0.7))

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

# ---------------------------------------------------------------- battle builder
var builder_next = false
var builder_bar: PanelContainer = null

func builder_bar_show(on: bool) -> void:
	if builder_bar == null:
		builder_bar = _panel(Color(0.1, 0.12, 0.14, 0.92))
		var v = VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		v.add_child(_label("Battle builder", 16, Color(0.96, 0.85, 0.5)))
		var t = _label("Set out squads, vehicles and defences for both sides (Units, Vehicles, Build tabs; switch side with 'For:'). Everyone holds still until you start.", 12, Color(0.85, 0.86, 0.82))
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size = Vector2(420, 0)
		v.add_child(t)
		var b = _button("▶  Start the battle", func(): G.main.builder_start())
		v.add_child(b)
		builder_bar.add_child(v)
		root.add_child(builder_bar)
		_place(builder_bar, Control.PRESET_CENTER_TOP, -225, 64, 450, 110)
	builder_bar.visible = on

# ---------------------------------------------------------------- settings
var binding = ""          # an action waiting for its new key

func _show_settings() -> void:
	if settings_panel != null:
		settings_panel.queue_free()
	settings_panel = _panel(Color(0.1, 0.12, 0.14, 0.98))
	_place(settings_panel, Control.PRESET_CENTER, -250, -345, 500, 690)
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
	var mus = HSlider.new()
	mus.min_value = 0.0
	mus.max_value = 1.0
	mus.step = 0.05
	mus.value = G.settings["music"]
	mus.custom_minimum_size = Vector2(220, 0)
	mus.value_changed.connect(func(x): G.settings["music"] = x)
	_row(v, "Music", mus)
	var sens = HSlider.new()
	sens.min_value = 0.2
	sens.max_value = 3.0
	sens.step = 0.1
	sens.value = G.settings["sens"]
	sens.custom_minimum_size = Vector2(220, 0)
	sens.value_changed.connect(func(x): G.settings["sens"] = x)
	_row(v, "Mouse sensitivity", sens)
	for item in [["invert_y", "Invert mouse Y"], ["blood", "Blood and bullet holes"], ["callouts", "Show soldiers' shouts as text"], ["shadows", "Shadows"], ["grass", "Grass (next battle)"], ["fps", "Show frame rate and soldier count"], ["voices", "Spoken callouts"]]:
		var key = item[0]
		var cb = CheckBox.new()
		cb.button_pressed = G.settings[key]
		cb.focus_mode = Control.FOCUS_NONE
		cb.toggled.connect(func(on):
			G.settings[key] = on
			if key == "shadows":
				G.main.apply_time())
		_row(v, item[1], cb)
	var ms_vals = [120, 200, 300, 450, 600]
	var ms = _option(["120", "200", "300", "450", "600"], maxi(0, ms_vals.find(int(G.settings["max_soldiers"]))))
	ms.item_selected.connect(func(i): G.settings["max_soldiers"] = ms_vals[i])
	_row(v, "Most soldiers at once", ms)
	var ld_vals = [30.0, 55.0, 80.0, 120.0]
	var ld = _option(["30 m (fastest)", "55 m", "80 m", "120 m (best looking)"], maxi(0, ld_vals.find(float(G.settings["lod_dist"]))))
	ld.item_selected.connect(func(i): G.settings["lod_dist"] = ld_vals[i])
	_row(v, "Full detail within (big battles)", ld)
	# controls: click an action, then press the key you want for it
	v.add_child(_label("Controls  ·  click one, then press a key", 16, Color(0.96, 0.85, 0.5)))
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 3)
	for a in Keys.ACTIONS:
		var act: String = a[0]
		var lbl = _label(a[1], 12, Color(0.85, 0.86, 0.82))
		lbl.custom_minimum_size = Vector2(250, 0)
		grid.add_child(lbl)
		var kb = Button.new()
		kb.focus_mode = Control.FOCUS_NONE
		kb.custom_minimum_size = Vector2(150, 22)
		kb.add_theme_font_size_override("font_size", 12)
		kb.text = "Press a key…" if binding == act else Keys.name_of(Keys.bound(act))
		kb.pressed.connect(func():
			binding = act
			kb.text = "Press a key…  (Esc cancels)")
		grid.add_child(kb)
	var sc = ScrollContainer.new()
	sc.custom_minimum_size = Vector2(460, 200)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.add_child(grid)
	v.add_child(sc)
	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.add_child(_button("Default keys", func():
		Keys.reset()
		_show_settings()))
	hb.add_child(_button("Done", func():
		binding = ""
		G.save_prefs()
		settings_panel.visible = false))
	v.add_child(hb)
	settings_panel.add_child(v)
	root.add_child(settings_panel)

# ---------------------------------------------------------------- order card
# pops up just above the dock whenever you have soldiers selected: what they are, and what you can tell them to do
var order_card: PanelContainer = null
var order_title: Label
var order_grid: HFlowContainer
var order_sig = ""

func _build_order_card() -> void:
	order_card = _panel(Color(0.07, 0.08, 0.09, 0.92))
	var sb: StyleBoxFlat = order_card.get_theme_stylebox("panel")
	sb.set_corner_radius_all(6)
	sb.border_width_top = 2
	sb.border_color = Color(0.96, 0.74, 0.27, 0.8)
	sb.set_content_margin_all(4)
	sb.bg_color = Color(0.07, 0.08, 0.09, 0.78)
	order_card.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	order_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# one slim strip just above the dock: what's selected, then the orders as small buttons
	order_grid = HFlowContainer.new()
	order_grid.add_theme_constant_override("h_separation", 3)
	order_grid.add_theme_constant_override("v_separation", 3)
	order_title = _label("", 12, Color(0.96, 0.9, 0.75))
	order_title.custom_minimum_size = Vector2(0, 24)
	order_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	order_title.mouse_filter = Control.MOUSE_FILTER_STOP
	order_card.add_child(order_grid)
	order_card.visible = false
	root.add_child(order_card)

func _order_card_tick() -> void:
	if order_card == null:
		_build_order_card()
	var sel = G.pc.selection.filter(func(x): return is_instance_valid(x) and x.state != "dead")
	var show = G.started and G.player == null and not sel.is_empty() and not menu_open() and not G.editor.active and dock != null and dock.visible
	order_card.visible = show
	if not show:
		order_sig = ""
		return
	var riding = sel.any(func(x): return x.state == "riding")
	var on_foot = sel.filter(func(x): return x.state != "riding")
	var smokes = on_foot.any(func(x): return x.smokes > 0)
	# the order most of them are on right now: that one button is lit, the rest stay plain
	var tally = {}
	for m in on_foot:
		var o = m.order
		var tg = "free" if o == null else str(o.get("tag", o.get("mode", "")))
		tally[tg] = tally.get(tg, 0) + 1
	var active = ""
	for k in tally:
		if active == "" or tally[k] > tally[active]:
			active = k
	var sig = str(sel.size()) + str(riding) + str(smokes) + str(on_foot.size()) + G.pc._sel_summary() + active
	if sig != order_sig:
		order_sig = sig
		order_title.text = G.pc._sel_short() + "  ▸"
		order_title.tooltip_text = G.pc._sel_summary()
		for c in order_grid.get_children():
			if c != order_title:
				c.queue_free()
		if order_title.get_parent() == null:
			order_grid.add_child(order_title)
		# only the orders that make sense for what's selected
		var items = []
		if not on_foot.is_empty():
			items += [["hold", "Hold"], ["cover", "Cover"]]
			if not on_foot.all(func(x): return x.cls in ["sniper", "spotter", "medic"]):
				items.append(["charge", "Charge!"])
			items.append(["fallback", "Fall back"])
			if smokes:
				items.append(["smoke", "Smoke"])
		if riding:
			var vs = G.pc.sel_vehicles()
			var guns = vs.all(func(x): return x.spec.get("static", false))
			if not guns:
				items += [["vstop", "Stop"], ["vback", "Rally"], ["vfree", "Drive free"]]
				if vs.any(func(x): return (x.spec["tracked"] or x.kind in ["armoredcar", "halftrack"]) and G.sim_time > x.smoke_cd):
					items.append(["vsmoke", "Pop smoke"])
				if vs.any(func(x): return VehExt.can_tow(x)):
					items.append(["vtow", "Unhitch" if vs.any(func(x): return x.towing != null) else "Tow"])
			if vs.any(func(x): return x.seats.size() > 1 or x.spec.get("static", false)):
				items.append(["dismount", "Leave the gun" if guns else "Dismount"])
		if not on_foot.is_empty():
			items.append(["amove", "Attack-move"])
			items.append(["free", "Free"])
			if on_foot.any(func(x): return x.cls == "engineer") or G.mode != "commander":
				items.append(["build", "Build…"])
			if on_foot.size() >= 3:
				items += [["f:wedge", "Wedge"], ["f:line", "Line"], ["f:column", "Column"]]
		items.append(["clear", "Deselect"])
		for it in items:
			var id: String = it[0]
			var b = Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.text = it[1]
			b.custom_minimum_size = Vector2(0, 24)
			b.add_theme_font_size_override("font_size", 12)
			b.tooltip_text = {"hold": "Hold here", "cover": "Take cover nearby", "charge": "Charge!", "fallback": "Fall back", "smoke": "Throw a smoke screen",
				"vstop": "Stop where they are", "vback": "Back to the rally point", "vfree": "Drive freely", "vsmoke": "Pop smoke", "dismount": "Get out", "vtow": "Hitch up the nearest field gun or broken-down vehicle and tow it (press again to unhitch)",
				"free": "Act freely", "build": "Pick something to build", "clear": "Deselect", "amove": "Move, but stop and fight anything on the way (or Ctrl + right-click)"}.get(id, it[1])
			var acc = id == active
			b.add_theme_stylebox_override("normal", _dock_style(Color(0.16, 0.18, 0.2, 0.96), Color(0.95, 0.75, 0.25) if acc else Color(0.3, 0.33, 0.36)))
			b.add_theme_stylebox_override("hover", _dock_style(Color(0.26, 0.29, 0.32, 1.0), Color(1.0, 0.85, 0.35)))
			b.add_theme_stylebox_override("pressed", _dock_style(Color(0.3, 0.27, 0.15, 1.0), Color(1.0, 0.85, 0.35)))
			b.pressed.connect(func():
				if id == "clear":
					G.pc.clear_selection()
				elif id == "build":
					tab = "build"
					tool = _cards("build")[0][0]
					_render_tools()
					message("Pick a structure, place it, then right-click it with soldiers selected (Shift to queue more)")
				elif id.begins_with("f:"):
					G.pc.set_formation(id.substr(2))
				elif id == "amove":
					G.pc.amove_next = true
					message("Attack-move: right-click where to go (or hold Ctrl when you right-click)")
				else:
					G.pc.order_selected(id))
			order_grid.add_child(b)
	var w = 880.0
	order_grid.custom_minimum_size = Vector2(w - 8.0, 0)
	order_card.offset_left = -w / 2.0
	order_card.offset_right = w / 2.0
	order_card.offset_bottom = dock.offset_top - 3.0
	order_card.offset_top = order_card.offset_bottom - (order_grid.get_combined_minimum_size().y + 8.0)

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
	h2.add_child(_button("Dismount", func(): G.pc.dismount_selected(true)))
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
	# you only hear your own side's radio (the enemy's orders would be cheating)
	if team < 0 or (team > 0 and G.mode != "sandbox"):
		return
	if radio_box == null:
		radio_box = VBoxContainer.new()
		_place(radio_box, Control.PRESET_BOTTOM_LEFT, 12, -330, 420, 180)
		radio_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		radio_box.alignment = BoxContainer.ALIGNMENT_END
		root.add_child(radio_box)
	# a radio line: a dark strip with the side's colour down its edge, the same as the alerts
	var line = PanelContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_stylebox_override("panel", Hud.strip(Hud.BG_SOFT, G.team_color(team).lightened(0.25) if team >= 0 else Hud.MUTED))
	line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var l = RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.custom_minimum_size = Vector2(380, 0)
	l.add_theme_font_size_override("normal_font_size", Hud.SIZE_SMALL + 1)
	l.add_theme_font_size_override("bold_font_size", Hud.SIZE_SMALL + 1)
	var who = ("[b][color=#%s]%s[/color][/b]  " % [G.team_color(team).lightened(0.5).to_html(false), G.TEAM_NAMES[team]]) if team >= 0 else ""
	l.text = who + "[color=#%s]%s[/color]" % [Hud.TEXT.to_html(false), text.replace("[", "(").replace("]", ")")]
	line.add_child(l)
	radio_box.add_child(line)
	while radio_box.get_child_count() > 6:
		var c = radio_box.get_child(0)
		radio_box.remove_child(c)
		c.queue_free()
	var wr = weakref(line)
	get_tree().create_timer(12.0).timeout.connect(func():
		var n = wr.get_ref()
		if n != null:
			n.queue_free())

# ---------------------------------------------------------------- what you clicked: a structure or a vehicle
var info: PanelContainer = null
var floor_view: FloorView = null
var squad_cards = null
var info_title: Label
var info_body: Label
var info_btns: HBoxContainer
var info_obj: Dictionary = {}
var info_t = 0.0
var info_key = ""

func _build_info() -> void:
	info = _panel(Color(0.07, 0.08, 0.09, 0.92))
	# bottom right, just above the minimap: clear of the menu buttons, the squad cards and the battle
	info.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	info.offset_left = -312
	info.offset_right = -12
	info.offset_bottom = -212
	info.offset_top = -222
	info.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	var head = HBoxContainer.new()
	info_title = _label("", 18, Color(1.0, 0.88, 0.45))
	info_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(info_title)
	head.add_child(_button("✕", func(): hide_info()))
	v.add_child(head)
	info_body = _label("", 13, Color(0.85, 0.88, 0.9))
	info_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_body.custom_minimum_size = Vector2(276, 0)
	v.add_child(info_body)
	info_btns = HBoxContainer.new()
	info_btns.add_theme_constant_override("separation", 4)
	v.add_child(info_btns)
	info.add_child(v)
	info.visible = false
	root.add_child(info)

func show_site(st: Dictionary) -> void:
	info_obj = {"site": st}
	info_key = ""
	info_t = 0.0
	_info_tick(0.0)

func show_vehicle(v) -> void:
	info_obj = {"veh": v}
	info_key = ""
	info_t = 0.0
	_info_tick(0.0)

func show_unit(s) -> void:
	info_obj = {"unit": s}
	info_key = ""
	info_t = 0.0
	_info_tick(0.0)

func hide_info() -> void:
	info_obj = {}
	if info != null:
		info.visible = false

func _info_button(t: String, cb: Callable) -> void:
	var b = _button(t, cb)
	b.add_theme_font_size_override("font_size", 13)
	info_btns.add_child(b)

func _info_tick(dt: float) -> void:
	if info == null:
		return
	if info_obj.is_empty() or not G.started:
		info.visible = false
		return
	info_t -= dt
	if info_t > 0.0:
		return
	info_t = 0.25
	var title = ""
	var body = ""
	var key = ""
	var btns = []
	if info_obj.has("site"):
		var st: Dictionary = info_obj["site"]
		if not (st in Build.sites):
			hide_info()
			return
		var mine = st["team"] == 0 or (G.mode != "commander" and G.mode == "sandbox")
		title = st["name"]
		var lost = 0
		for c in st["cols"]:
			if not c.alive:
				lost += 1
		var dmg = Build.damage(st)
		if st["dead"]:
			body = "Destroyed"
		elif not st["done"]:
			body = "Being built: %d%%  (%d engineer%s working)" % [int(100.0 * st["work"] / maxf(1.0, st["need"])), Build.helpers(st), "" if Build.helpers(st) == 1 else "s"]
		else:
			body = "Condition: %d%%" % int(100.0 * (1.0 - dmg))
		body += "\n" + G.TEAM_NAMES[st["team"]] + ("" if st["team"] == 0 or G.mode == "sandbox" else " · enemy structure")
		body += "\n" + Build.DESCR.get(st["kind"], "")
		if st.get("camo", false):
			body += "\nUnder a camouflage net"
		key = "s%d%d%d%d" % [int(st["done"]), int(st["dead"]), int(dmg > 0.01), lost]
		if mine:
			if st["done"] and dmg > 0.01:
				btns.append(["Repair", func(): _site_act("rep")])
			if st["kind"] != "hq":
				btns.append(["Dismantle", func(): _site_act("dis")])
			if st["done"] and Build.UPGRADES.has(st["kind"]):
				btns.append(["Upgrade", func(): _site_act("up")])
			if st["done"] and not st.get("camo", false):
				btns.append(["Camo net", func(): _site_act("camo")])
		elif st["kind"] == "wire":
			body += "\n(cut it with a soldier: walk up and press I)"
	elif info_obj.has("veh"):
		var v = info_obj["veh"]
		if not is_instance_valid(v) or v.dead or not (v in G.vehicles):
			hide_info()
			return
		title = v.spec["name"]
		var crew = 0
		var pas = 0
		for i in range(v.seats.size()):
			if v.seats[i] != null:
				if v.spec["seats"][i]["role"] == "pass":
					pas += 1
				else:
					crew += 1
		body = "Condition: %d%%\nCrew %d · troops aboard %d" % [int(100.0 * v.hp / maxf(1.0, v.spec["hp"])), crew, pas]
		if v.cmd != null:
			body += "\nDriving to the marked point"
		body += "\nRight-click the ground to drive there"
		key = "v%d%d" % [pas, crew]
		if pas > 0:
			btns.append(["Dismount troops", func(): G.pc.dismount_selected(true)])
		if crew > 0:
			btns.append(["Crew out", func(): G.pc.dismount_selected(false)])
		if v.cmd != null:
			btns.append(["Stop", func():
				if is_instance_valid(v):
					v.cmd = v.pos
				message("%s stopping" % v.spec["name"])
				info_key = ""])
	if info_obj.has("unit"):
		var u = info_obj["unit"]
		if not is_instance_valid(u) or u.state == "dead" or not (u in G.pc.selection):
			hide_info()
			return
		var tag = G.pc.CLASS_TAG.get(u.cls, ["", Color.WHITE])
		title = "%s · %s" % [u.sname, G.pc.PLURAL.get(u.cls, [u.cls, u.cls])[0].capitalize()]
		var stars = "· veteran %d" % u.vet if u.vet > 0 else ""
		var mags = int(u.reserve / maxf(1.0, u.W["mag"]))
		body = "Health %d%%%s  ·  kills %d %s" % [int(clampf(u.hp, 0.0, 100.0)), " (bleeding)" if u.state == "wounded" else "", u.kills, stars]
		body += "\n%s: %d in the gun, %d spare mag%s" % [u.W["name"], u.mag, mags, "" if mags == 1 else "s"]
		var kit = []
		if u.grenades > 0:
			kit.append("%d grenade%s" % [u.grenades, "" if u.grenades == 1 else "s"])
		if u.smokes > 0:
			kit.append("%d smoke" % u.smokes)
		if u.rockets > 0 and u.W["rocket"]:
			kit.append("%d rocket%s" % [u.rockets, "" if u.rockets == 1 else "s"])
		if not kit.is_empty():
			body += "\n" + ", ".join(kit)
		var sq = G.pc.my_squads().find(u.squad) if u.squad != null else -1
		var doing = SquadCards.doing({"members": [u]})[0]
		body += "\n%s%s" % ["Squad %d · " % (sq + 1) if sq >= 0 else "", doing]
		if u.supp > 0.9:
			body += " (under heavy fire)"
		key = "u%d" % u.id
		btns.append(["Hold", func(): G.pc.order_selected("hold")])
		btns.append(["Take cover", func(): G.pc.order_selected("cover")])
		btns.append(["Control him", func():
			if is_instance_valid(u) and u.state == "alive":
				G.pc.possess(u)])
	if not info.visible:
		info.visible = true
		info.modulate.a = 0.0
		info.create_tween().tween_property(info, "modulate:a", 1.0, 0.16)
	info_title.text = title
	info_body.text = body
	if key != info_key:
		info_key = key
		for c in info_btns.get_children():
			c.queue_free()
		for b in btns:
			_info_button(b[0], b[1])
	# grows upward from just above the minimap
	var hgt = info.get_combined_minimum_size().y
	info.offset_bottom = -212
	info.offset_top = -212 - hgt

func _site_act(what: String) -> void:
	if not info_obj.has("site"):
		return
	var st: Dictionary = info_obj["site"]
	if not (st in Build.sites):
		hide_info()
		return
	match what:
		"rep":
			var r = Build.repair(st)
			message(r)
		"dis":
			var nm = st["name"]
			var back = Build.refund(st)
			G.pc.dismantle_site(st)
			if back > 0:
				Support.points[st["team"]] += back
			message("Dismantled the %s%s" % [nm, (" (+%d pts back)" % back) if back > 0 else ""])
			hide_info()
		"up":
			var ns = Build.upgrade(st)
			if ns == null:
				message("Nothing to upgrade")
			else:
				show_site(ns)
		"camo":
			# the net comes rolled up; men have to put it up (it isn't just there)
			if Build.order_camo(st):
				message("Camouflage net ordered for the %s: engineers will put it up" % st["name"])
			else:
				message("The %s already has a net (or one on the way)" % st["name"])
	info_key = ""
	info_t = 0.0
