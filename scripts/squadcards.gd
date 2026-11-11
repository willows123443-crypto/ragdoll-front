class_name SquadCards
extends VBoxContainer
# Commander view: a column of cards down the left, one per squad on your side. Each shows the squad's
# number and kind, how many men are left, a health bar for the whole squad and what it's doing.
# Click a card to select that squad and look at it.

var cards: Array = []
var t = 0.0
const CW = 176

func _ready() -> void:
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(192, 12)
	visible = false

static func kind_of(q: Dictionary) -> String:
	var roles = {}
	var n = 0
	for m in q["members"]:
		if is_instance_valid(m) and m.state != "dead":
			roles[m.role] = roles.get(m.role, 0) + 1
			n += 1
	if n == 0:
		return "Squad"
	if roles.get("sniper", 0) + roles.get("spotter", 0) >= n:
		return "Sniper team"
	if roles.get("mg", 0) * 2 >= n:
		return "MG team"
	if roles.get("at", 0) * 2 >= n:
		return "Anti-tank"
	if roles.get("engineer", 0) * 2 >= n:
		return "Engineers"
	if roles.get("medic", 0) * 2 >= n:
		return "Medics"
	return "Rifle squad"

static func icon_of(q: Dictionary) -> String:
	match kind_of(q):
		"Sniper team":
			return "sniper"
		"MG team":
			return "mg"
		"Anti-tank":
			return "at"
		"Engineers":
			return "shotgun"
		"Medics":
			return "medic"
	return "rifle"

# what the squad is up to, from its men
static func doing(q: Dictionary) -> Array:
	var n = 0
	var moving = 0
	var fighting = 0
	var pinned = 0
	var building = 0
	var riding = 0
	var cover = 0
	for m in q["members"]:
		if not is_instance_valid(m) or m.state == "dead":
			continue
		n += 1
		if m.state == "riding" or (m.vehicle != null and is_instance_valid(m.vehicle)):
			riding += 1
			continue
		if m.state != "alive":
			continue
		if m.supp > 0.9:
			pinned += 1
		if m.vis_t != null or G.sim_time - m.seen_t < 3.0:
			fighting += 1
		if m.task in ["construct", "repair"]:
			building += 1
		if m.move_target != null and m.want.length_squared() > 0.5:
			moving += 1
		if m.in_cover:
			cover += 1
	if n == 0:
		return ["Wiped out", Color(0.6, 0.6, 0.6)]
	if riding * 2 >= n:
		return ["Mounted", Color(0.7, 0.8, 1.0)]
	if pinned * 2 >= n:
		return ["Pinned down!", Color(1.0, 0.45, 0.35)]
	if fighting > 0:
		return ["In combat", Color(1.0, 0.7, 0.35)]
	if building > 0:
		return ["Building", Color(0.95, 0.85, 0.45)]
	if moving * 2 >= n:
		return ["Moving", Color(0.75, 0.9, 1.0)]
	if cover * 2 >= n:
		return ["In cover", Color(0.6, 0.95, 0.6)]
	return ["Holding", Color(0.8, 0.82, 0.78)]

func _card(i: int) -> Dictionary:
	while cards.size() <= i:
		var k = cards.size()
		var b = Button.new()
		b.custom_minimum_size = Vector2(CW, 40)
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.07, 0.08, 0.09, 0.82)
		sb.set_corner_radius_all(4)
		sb.border_color = Color(1.0, 0.86, 0.3, 0.0)
		sb.set_border_width_all(2)
		var sh = sb.duplicate()
		sh.bg_color = Color(0.14, 0.16, 0.17, 0.9)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sh)
		b.add_theme_stylebox_override("pressed", sh)
		var h = HBoxContainer.new()
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 6
		h.offset_right = -6
		h.add_theme_constant_override("separation", 6)
		var num = G.ui._label(str(k + 1), 20, Color(1.0, 0.86, 0.4))
		num.custom_minimum_size = Vector2(16, 0)
		h.add_child(num)
		var ic = TextureRect.new()
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(34, 16)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(ic)
		var v = VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 1)
		var top = G.ui._label("", 12, Color(0.92, 0.92, 0.88))
		v.add_child(top)
		var bar = ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 5)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bg = StyleBoxFlat.new()
		bg.bg_color = Color(0.2, 0.08, 0.06, 0.9)
		var fg = StyleBoxFlat.new()
		fg.bg_color = Color(0.45, 0.85, 0.4)
		bar.add_theme_stylebox_override("background", bg)
		bar.add_theme_stylebox_override("fill", fg)
		v.add_child(bar)
		var act = G.ui._label("", 11, Color(0.8, 0.8, 0.8))
		v.add_child(act)
		h.add_child(v)
		b.add_child(h)
		b.pressed.connect(func():
			G.pc.select_squad(k)
			G.pc.select_squad(k))     # twice: select it and look at it
		add_child(b)
		cards.append({"b": b, "sb": sb, "ic": ic, "top": top, "bar": bar, "fg": fg, "act": act})
	return cards[i]

func _process(dt: float) -> void:
	var show = G.started and G.player == null and not G.ui.menu_open() and not G.editor.active and not G.over
	var qs = G.pc.my_squads() if show else []
	visible = show and not qs.is_empty()
	if not visible:
		return
	t -= dt
	if t > 0.0:
		return
	t = 0.25
	var n = mini(qs.size(), 8)
	for i in range(n):
		var q = qs[i]
		var c = _card(i)
		c["b"].visible = true
		var alive = 0
		var hp = 0.0
		var sel = false
		for m in q["members"]:
			if is_instance_valid(m) and m.state != "dead":
				alive += 1
				hp += clampf(m.hp, 0.0, 100.0)
				if m in G.pc.selection:
					sel = true
		var total = maxi(alive, q.get("size0", q["members"].size()))
		q["size0"] = total
		c["ic"].texture = Icons.get_icon(icon_of(q))
		c["top"].text = "%s  %d/%d" % [kind_of(q), alive, total]
		c["bar"].max_value = total * 100.0
		c["bar"].value = hp
		var frac = hp / maxf(1.0, total * 100.0)
		c["fg"].bg_color = Color(0.45, 0.85, 0.4) if frac > 0.6 else (Color(0.95, 0.75, 0.3) if frac > 0.3 else Color(0.95, 0.35, 0.3))
		var d = doing(q)
		c["act"].text = d[0]
		c["act"].add_theme_color_override("font_color", d[1])
		c["sb"].border_color = Color(1.0, 0.86, 0.3, 0.95 if sel else 0.0)
		c["b"].tooltip_text = "Squad %d: click to select it and look at it (or press %d)" % [i + 1, i + 1]
	for i in range(n, cards.size()):
		cards[i]["b"].visible = false
