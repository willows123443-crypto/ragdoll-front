class_name SquadCards
extends VBoxContainer
# Commander view: a slim column of cards, one per squad on your side, next to the menu buttons.
# Each is one line: number, kind (or the vehicle a crew runs), men left, what it's doing, and a thin
# health bar underneath. Click a card to select that squad and look at it; the header folds them away.

var cards: Array = []
var t = 0.0
var folded = false
var head: Button
const CW = 182

func _ready() -> void:
	add_theme_constant_override("separation", 2)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(192, 12)
	visible = false
	head = Button.new()
	head.focus_mode = Control.FOCUS_NONE
	head.custom_minimum_size = Vector2(CW, 20)
	head.add_theme_font_size_override("font_size", 11)
	head.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var hs = StyleBoxFlat.new()
	hs.bg_color = Color(0.07, 0.08, 0.09, 0.7)
	hs.set_corner_radius_all(3)
	hs.content_margin_left = 6
	head.add_theme_stylebox_override("normal", hs)
	head.add_theme_stylebox_override("hover", hs)
	head.add_theme_stylebox_override("pressed", hs)
	head.pressed.connect(func():
		folded = not folded
		t = 0.0)
	add_child(head)

# the vehicle a squad's men are all riding in (as its crew), or null
static func crew_vehicle(q: Dictionary):
	var v = null
	var any = false
	for m in q["members"]:
		if not is_instance_valid(m) or m.state == "dead":
			continue
		any = true
		if m.state != "riding" or m.vehicle == null or not is_instance_valid(m.vehicle):
			return null
		if v == null:
			v = m.vehicle
		elif v != m.vehicle:
			return null
		var role = m.vehicle.spec["seats"][m.seat]["role"] if m.seat >= 0 and m.seat < m.vehicle.spec["seats"].size() else "pass"
		if role == "pass" and not m.vehicle.spec.get("static", false):
			return null
	return v if any else null

static func kind_of(q: Dictionary) -> String:
	var cv = crew_vehicle(q)
	if cv != null:
		var nm: String = cv.spec["name"]
		return nm.replace("Command truck", "Cmd truck").replace("Supply truck", "Supply")
	var roles = {}
	var n = 0
	for m in q["members"]:
		if is_instance_valid(m) and m.state != "dead":
			roles[m.role] = roles.get(m.role, 0) + 1
			n += 1
	if n == 0:
		return "Squad"
	if roles.get("sniper", 0) + roles.get("spotter", 0) >= n:
		return "Snipers"
	if roles.get("mg", 0) * 2 >= n:
		return "MG team"
	if roles.get("at", 0) * 2 >= n:
		return "Anti-tank"
	if roles.get("engineer", 0) * 2 >= n:
		return "Engineers"
	if roles.get("medic", 0) * 2 >= n:
		return "Medics"
	return "Rifles"

static func icon_of(q: Dictionary) -> String:
	if crew_vehicle(q) != null:
		return "vehicle"
	match kind_of(q):
		"Snipers":
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

# what the squad is up to, from its men (a crew: from its vehicle)
static func doing(q: Dictionary) -> Array:
	var cv = crew_vehicle(q)
	if cv != null:
		if cv.spec.get("static", false):
			return ["Manning", Color(0.75, 0.85, 0.75)]
		if cv.fuel <= 0.0:
			return ["Out of fuel", Color(1.0, 0.45, 0.35)]
		if cv.fuel < 0.2:
			return ["Low fuel", Color(1.0, 0.75, 0.3)]
		if absf(cv.speed) > 1.0:
			return ["Driving", Color(0.75, 0.9, 1.0)]
		return ["Parked", Color(0.8, 0.82, 0.78)]
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
		# only men actually sitting in a vehicle count as mounted
		if m.state == "riding" and m.vehicle != null and is_instance_valid(m.vehicle) and not m.vehicle.dead:
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
	if riding * 2 > n:
		return ["Mounted", Color(0.7, 0.8, 1.0)]
	if pinned * 2 >= n:
		return ["Pinned!", Color(1.0, 0.45, 0.35)]
	if fighting > 0:
		return ["Fighting", Color(1.0, 0.7, 0.35)]
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
		b.custom_minimum_size = Vector2(CW, 38)
		b.focus_mode = Control.FOCUS_NONE
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.07, 0.08, 0.09, 0.72)
		sb.set_corner_radius_all(3)
		sb.border_color = Color(1.0, 0.86, 0.3, 0.0)
		sb.set_border_width_all(1)
		var sh = sb.duplicate()
		sh.bg_color = Color(0.14, 0.16, 0.17, 0.85)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sh)
		b.add_theme_stylebox_override("pressed", sh)
		var h = HBoxContainer.new()
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 5
		h.offset_right = -5
		h.offset_bottom = -17
		h.add_theme_constant_override("separation", 5)
		var num = G.ui._label(str(k + 1), 14, Color(1.0, 0.86, 0.4))
		num.custom_minimum_size = Vector2(10, 0)
		h.add_child(num)
		var ic = TextureRect.new()
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.custom_minimum_size = Vector2(28, 12)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(ic)
		var top = G.ui._label("", 11, Color(0.92, 0.92, 0.88))
		top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.clip_text = true
		h.add_child(top)
		var act = G.ui._label("", 11, Color(0.8, 0.8, 0.8))
		act.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(act)
		b.add_child(h)
		# a row of the men in it: each one's weapon, and a pip for how he's doing
		var men = Control.new()
		men.mouse_filter = Control.MOUSE_FILTER_IGNORE
		men.set_anchors_preset(Control.PRESET_FULL_RECT)
		men.offset_top = 21
		men.offset_left = 18
		men.offset_bottom = -4
		men.draw.connect(func(): _draw_men(men))
		b.add_child(men)
		var bar = ColorRect.new()
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_top = 1.0
		bar.anchor_bottom = 1.0
		bar.offset_top = -3
		bar.offset_left = 3
		b.add_child(bar)
		b.pressed.connect(func():
			G.pc.select_squad(k)
			G.pc.select_squad(k))     # twice: select it and look at it
		add_child(b)
		cards.append({"b": b, "sb": sb, "ic": ic, "top": top, "bar": bar, "act": act, "men": men})
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
	var n = mini(qs.size(), 9)
	head.text = ("▸ " if folded else "▾ ") + "Squads (%d)" % qs.size()
	for i in range(n):
		var q = qs[i]
		var c = _card(i)
		c["b"].visible = not folded
		if folded:
			continue
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
		c["top"].text = "%s %d/%d" % [kind_of(q), alive, total]
		var frac = hp / maxf(1.0, total * 100.0)
		c["bar"].color = Color(0.45, 0.85, 0.4, 0.9) if frac > 0.6 else (Color(0.95, 0.75, 0.3, 0.9) if frac > 0.3 else Color(0.95, 0.35, 0.3, 0.9))
		c["bar"].offset_right = 3.0 + (CW - 6.0) * clampf(frac, 0.0, 1.0)
		var d = doing(q)
		c["act"].text = d[0]
		c["act"].add_theme_color_override("font_color", d[1])
		c["sb"].border_color = Color(1.0, 0.86, 0.3, 0.95 if sel else 0.0)
		c["men"].set_meta("q", q)
		c["men"].queue_redraw()
		c["b"].tooltip_text = "Squad %d: click to select it and look at it (or press %d)" % [i + 1, i + 1]
	for i in range(n, cards.size()):
		cards[i]["b"].visible = false

func _draw_men(c: Control) -> void:
	var q = (c.get_meta("q") if c.has_meta("q") else null)
	if q == null:
		return
	var x = 0.0
	var n = 0
	for m in q["members"]:
		if not is_instance_valid(m):
			continue
		if x + 16.0 > c.size.x:
			break
		var col = Color(0.92, 0.92, 0.88)
		var pip = Color(0.45, 0.9, 0.4)
		if m.state == "dead":
			col = Color(0.45, 0.45, 0.45, 0.6)
			pip = Color(0.3, 0.3, 0.3)
		elif m.state == "wounded":
			col = Color(1.0, 0.45, 0.4)
			pip = Color(1.0, 0.3, 0.25)
		elif m.hp < 35.0:
			pip = Color(1.0, 0.35, 0.3)
		elif m.hp < 70.0:
			pip = Color(1.0, 0.8, 0.3)
		var wid: String = m.wid if "wid" in m else "rifle"
		if m.cls == "medic":
			wid = "medic"
		var tex = Icons.get_icon(wid)
		c.draw_texture_rect(tex, Rect2(x, 0, 15, 6), false, col)
		c.draw_rect(Rect2(x + 1, 8, 13, 3), Color(0, 0, 0, 0.5))
		if m.state != "dead":
			c.draw_rect(Rect2(x + 1, 8, 13.0 * clampf(m.hp / 100.0, 0.05, 1.0), 3), pip)
		x += 16.5
		n += 1
	# a vehicle crew's card has a fuel gauge on the right
	var cv = crew_vehicle(q)
	if cv != null and not cv.spec.get("static", false) and not cv.spec.get("air", false):
		var fx = c.size.x - 30.0
		var fc = Color(0.95, 0.75, 0.3) if cv.fuel > 0.2 else Color(1.0, 0.35, 0.3)
		c.draw_string(ThemeDB.fallback_font, Vector2(fx - 9.0, 9.0), "F", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.85, 0.85, 0.8))
		c.draw_rect(Rect2(fx, 4, 28, 4), Color(0, 0, 0, 0.5))
		c.draw_rect(Rect2(fx, 4, 28.0 * clampf(cv.fuel, 0.0, 1.0), 4), fc)
