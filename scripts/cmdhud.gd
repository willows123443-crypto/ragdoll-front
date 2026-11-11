extends Control
# Commander-view overlay: a whole-map minimap you can click to move the camera (squads with arrows,
# vehicle icons, flags, fading last-seen enemy marks and red pings where your men are under fire),
# alerts down the side that fly the camera to trouble when clicked (Space: the latest one), a slim
# health bar over whatever the mouse is on, and supply income under the score.

var font: Font
var click: Control
var alerts_box: VBoxContainer
var alerts: Array = []          # {"t": time, "p": Vector3, "text": String, "btn": Button}
var last_seen = {}              # enemy -> [pos, time]
var pings: Array = []           # [pos, time]
var ping_cd = {}                # soldier/squad -> next time
var alert_cd = {}               # key -> next time
var earn_hist: Array = []       # [time, earned]
var mm_rect = Rect2()
var hp_seen = {}                # site/vehicle -> hp last tick (for "under fire")
var tick_t = 0.0
const MMS = 250.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	click = Control.new()
	click.mouse_filter = Control.MOUSE_FILTER_STOP
	click.gui_input.connect(_mm_input)
	add_child(click)
	alerts_box = VBoxContainer.new()
	alerts_box.add_theme_constant_override("separation", 4)
	alerts_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(alerts_box)

func active() -> bool:
	return G.started and G.mode == "commander" and G.player == null and G.pc.rts and G.ui.visible and not G.ui.menu_open() \
		and (G.ui.tacmap == null or not G.ui.tacmap.visible)

func _process(dt: float) -> void:
	var on = active()
	visible = on
	click.visible = on
	# the kill feed moves over to make room for the map
	var fb = G.ui.get("feed_box")
	if fb != null:
		fb.offset_left = -MMS - 24.0 - 320.0 if on else -330.0
		fb.offset_right = -MMS - 24.0 if on else -10.0
	if not on:
		return
	var vs = get_viewport_rect().size
	# top right, under the frame counter: the bottom right is the order dock and the unit card
	var mh = MMS * clampf(G.world.bounds.size.y / maxf(1.0, G.world.bounds.size.x), 0.45, 1.0)
	mm_rect = Rect2(vs.x - MMS - 12.0, 30.0, MMS, mh)
	click.position = mm_rect.position
	click.size = mm_rect.size
	alerts_box.position = Vector2(vs.x - 252.0, mm_rect.end.y + 10.0)
	alerts_box.size.x = 240.0
	tick_t -= dt
	if tick_t <= 0.0:
		tick_t = 0.5
		_watch()
	# alerts fade out after a while
	for a in alerts.duplicate():
		var age = G.sim_time - a["t"]
		if age > 14.0 or not is_instance_valid(a["btn"]):
			if is_instance_valid(a["btn"]):
				a["btn"].queue_free()
			alerts.erase(a)
		elif age > 11.0:
			a["btn"].modulate.a = (14.0 - age) / 3.0
	queue_redraw()

func _input(ev: InputEvent) -> void:
	if not active():
		return
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_SPACE and not Prep.active() and not alerts.is_empty():
		_jump(alerts[alerts.size() - 1]["p"])
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------- what to warn about
func alert(key: String, text: String, p: Vector3, cd: float = 25.0, col: Color = Color(1.0, 0.55, 0.4)) -> void:
	if G.sim_time < alert_cd.get(key, 0.0):
		return
	alert_cd[key] = G.sim_time + cd
	var b = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.text = "  " + text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 13)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.1, 0.85)
	sb.border_color = col
	sb.border_width_left = 4
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 6
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	b.add_theme_stylebox_override("normal", sb)
	var sh = sb.duplicate()
	sh.bg_color = Color(0.2, 0.2, 0.2, 0.95)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_color_override("font_color", Color(1, 1, 1))
	b.tooltip_text = "Click to go there (Space: the latest alert)"
	b.pressed.connect(func(): _jump(p))
	alerts_box.add_child(b)
	# slide in from the right
	b.modulate.a = 0.0
	var tw = b.create_tween()
	tw.tween_property(b, "modulate:a", 1.0, 0.25)
	alerts.append({"t": G.sim_time, "p": p, "text": text, "btn": b})
	while alerts.size() > 5:
		var o = alerts.pop_front()
		if is_instance_valid(o["btn"]):
			o["btn"].queue_free()
	if G.audio != null:
		G.audio.order_tick(false)

func _jump(p: Vector3) -> void:
	G.pc.rts_focus = Vector3(p.x, G.world.ground_y(p.x, p.z), p.z)

func _watch() -> void:
	# squads pinned
	for q in G.squads:
		if q["team"] != 0:
			continue
		var men = q["members"].filter(func(m): return is_instance_valid(m) and m.state == "alive")
		if men.size() < 2:
			continue
		var pinned = men.filter(func(m): return m.supp > 1.2).size()
		if pinned * 2 >= men.size():
			alert("pin%d" % q["id"], "Squad %d pinned down" % (q["id"] + 1), men[0].pos, 40.0)
	# men under fire: pings on the map
	for s in G.soldiers:
		if s.team == 0 and s.state == "alive" and s.supp > 1.1 and G.sim_time > ping_cd.get(s, 0.0):
			ping_cd[s] = G.sim_time + 5.0
			var close = false
			for pg in pings:
				if pg[0].distance_to(s.pos) < 15.0 and G.sim_time - pg[1] < 3.0:
					close = true
					break
			if not close:
				pings.append([s.pos, G.sim_time])
	while pings.size() > 30:
		pings.pop_front()
	# structures and vehicles being hit, and vehicles lost
	for st in Build.sites:
		if st["team"] != 0 or st["dead"]:
			continue
		var hp = Build.damage(st)
		var was = hp_seen.get(st, hp)
		hp_seen[st] = hp
		if hp > was + 0.02:
			alert("st" + str(st["p"]), "%s under fire" % st["name"], st["p"], 30.0, Color(1.0, 0.3, 0.3) if st["kind"] == "hq" else Color(1.0, 0.6, 0.35))
	for v in G.vehicles:
		if v.team != 0:
			continue
		var was2 = hp_seen.get(v, v.hp)
		hp_seen[v] = v.hp
		if v.dead and not v.has_meta("lost_said"):
			v.set_meta("lost_said", true)
			alert("vl" + str(v.get_instance_id()), "%s lost" % v.spec["name"], v.pos, 1.0, Color(1.0, 0.25, 0.25))
		elif not v.dead and v.hp < was2 - 40.0:
			alert("vh" + str(v.get_instance_id()), "%s taking hits" % v.spec["name"], v.pos, 25.0)
	# enemies we've seen, remembered where they were last seen
	for s in G.soldiers:
		if s.team == 0 or s.state == "dead":
			continue
		if not Fog.hidden(s):
			last_seen[s] = [s.pos, G.sim_time]
	for k in last_seen.keys():
		if not is_instance_valid(k) or G.sim_time - last_seen[k][1] > 30.0:
			last_seen.erase(k)
	# income: a sample every few seconds
	if Support.earned.size() > 0:
		earn_hist.append([G.sim_time, Support.earned[0]])
		while earn_hist.size() > 2 and G.sim_time - earn_hist[0][0] > 120.0:
			earn_hist.pop_front()

# ---------------------------------------------------------------- drawing
func _draw() -> void:
	if not active():
		return
	_minimap(mm_rect)
	_hover_bar()
	_income()

func _w2m(p: Vector3, r: Rect2, b: Rect2) -> Vector2:
	return r.position + Vector2((p.x - b.position.x) / b.size.x, (p.z - b.position.y) / b.size.y) * r.size

func _minimap(r: Rect2) -> void:
	var b: Rect2 = G.world.bounds
	if b.size.x < 1.0:
		return
	draw_rect(r.grow(3.0), Color(0, 0, 0, 0.6))
	draw_rect(r, Color(0.2, 0.24, 0.16, 0.92))
	for w in G.world.water:
		var a = _w2m(Vector3(w[0], 0, w[2]), r, b)
		var c = _w2m(Vector3(w[1], 0, w[3]), r, b)
		draw_rect(Rect2(a, c - a).abs().intersection(r), Color(0.25, 0.4, 0.55, 0.9))
	for rd in G.world.roads:
		var a2 = _w2m(Vector3(rd[0], 0, rd[2]), r, b)
		var c2 = _w2m(Vector3(rd[1], 0, rd[3]), r, b)
		draw_rect(Rect2(a2, c2 - a2).abs().intersection(r), Color(0.5, 0.46, 0.38, 0.9))
	for bd in G.world.buildings:
		var a3 = _w2m(Vector3(bd["x"] - bd["w"] / 2.0, 0, bd["z"] - bd["d"] / 2.0), r, b)
		var c3 = _w2m(Vector3(bd["x"] + bd["w"] / 2.0, 0, bd["z"] + bd["d"] / 2.0), r, b)
		draw_rect(Rect2(a3, (c3 - a3).max(Vector2(2, 2))), Color(0.12, 0.12, 0.1, 0.95))
	for pt in Obj.points:
		var p = _w2m(pt["p"], r, b)
		var col = G.team_color(pt["owner"]) if pt["owner"] >= 0 else Color(0.92, 0.92, 0.92)
		draw_circle(p, 7.0, Color(0, 0, 0, 0.5))
		draw_arc(p, 7.0, 0, TAU, 20, col, 2.0)
		draw_string(font, p + Vector2(-4, 5), pt["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)
	for st in Build.sites:
		if st["dead"] or (st["team"] != 0 and not st.get("seen0", false)):
			continue
		var p2 = _w2m(st["p"], r, b)
		var sz = 9.0 if st["kind"] == "hq" else 5.0
		draw_rect(Rect2(p2 - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), G.team_color(st["team"]).darkened(0.1))
		draw_rect(Rect2(p2 - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), Color(0, 0, 0, 0.8), false, 1.0)
	# where enemies were last seen: fading crosses
	for k in last_seen:
		var e = last_seen[k]
		var age = G.sim_time - e[1]
		if age < 0.6:
			continue
		var a4 = clampf(1.0 - age / 30.0, 0.0, 1.0) * 0.8
		var p3 = _w2m(e[0], r, b)
		draw_line(p3 - Vector2(3, 3), p3 + Vector2(3, 3), Color(1, 0.3, 0.25, a4), 1.5)
		draw_line(p3 + Vector2(-3, 3), p3 + Vector2(3, -3), Color(1, 0.3, 0.25, a4), 1.5)
	# soldiers: yours as dots, enemies you can see in red
	for s in G.soldiers:
		if s.state == "dead" or s.state == "riding":
			continue
		var p4 = _w2m(s.pos, r, b)
		if s.team == 0:
			draw_circle(p4, 1.6, G.team_color(0).lightened(0.45))
		elif not Fog.hidden(s):
			draw_circle(p4, 2.2, Color(1.0, 0.3, 0.25))
	# squads: an arrow from where they are the way they're heading
	for q in G.squads:
		if q["team"] != 0:
			continue
		var men = q["members"].filter(func(m): return is_instance_valid(m) and m.state == "alive")
		if men.is_empty():
			continue
		var c4 = Vector3.ZERO
		var vel = Vector3.ZERO
		for m in men:
			c4 += m.pos
			vel += m.vel
		c4 /= men.size()
		vel /= men.size()
		var pc = _w2m(c4, r, b)
		draw_circle(pc, 5.0, Color(0.15, 0.3, 0.6, 0.9))
		draw_string(font, pc + Vector2(-3, 4), str(q["id"] + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1))
		if G.flat(vel).length() > 0.5:
			var d = Vector2(vel.x / b.size.x, vel.z / b.size.y).normalized()
			var tipp = pc + d * 14.0
			draw_line(pc + d * 5.0, tipp, Color(0.75, 0.9, 1.0), 2.0)
			draw_colored_polygon(PackedVector2Array([tipp + d * 4.0, tipp + Vector2(-d.y, d.x) * 3.5, tipp - Vector2(-d.y, d.x) * 3.5]), Color(0.75, 0.9, 1.0))
	# vehicles: a tank with its gun, lorries as long boxes, the rest small squares
	for v in G.vehicles:
		if v.dead or (v.team != 0 and not v.visible) or v.spec.get("air", false):
			continue
		var p5 = _w2m(v.pos, r, b)
		var f = Vector2(sin(v.yaw), cos(v.yaw))
		var sd = Vector2(f.y, -f.x)
		var col2 = G.team_color(v.team).lightened(0.2) if v.team == 0 else Color(1.0, 0.35, 0.3)
		var L = 4.5 if v.spec["tracked"] or v.kind.ends_with("truck") or v.kind == "truck" else 3.0
		var W = 2.6
		var pts = PackedVector2Array([p5 + f * L + sd * W, p5 + f * L - sd * W, p5 - f * L - sd * W, p5 - f * L + sd * W])
		draw_colored_polygon(pts, col2)
		pts.append(pts[0])
		draw_polyline(pts, Color(0, 0, 0, 0.9), 1.0)
		if v.turret != null and v.spec["tracked"]:
			var gy = v.yaw + v.turret_yaw
			draw_line(p5, p5 + Vector2(sin(gy), cos(gy)) * 7.0, Color(0, 0, 0, 0.9), 1.5)
	# under fire: expanding red rings
	for pg in pings:
		var age2 = G.sim_time - pg[1]
		if age2 > 2.5:
			continue
		var p6 = _w2m(pg[0], r, b)
		draw_arc(p6, 4.0 + age2 * 7.0, 0, TAU, 20, Color(1, 0.2, 0.15, 1.0 - age2 / 2.5), 2.0)
	# what the camera is looking at
	var fc = _w2m(G.pc.rts_focus, r, b)
	var half = G.pc.rts_dist * 0.75
	var vsz = Vector2(half * 1.6 / b.size.x, half / b.size.y) * r.size
	draw_rect(Rect2(fc - vsz * 0.5, vsz), Color(1, 1, 1, 0.75), false, 1.5)
	draw_rect(r, Color(0, 0, 0, 0.9), false, 2.0)
	draw_string(font, r.position + Vector2(5, 14), "MAP · click to look", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.55))

func _mm_input(ev: InputEvent) -> void:
	if (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0):
		var b: Rect2 = G.world.bounds
		var k = ev.position / mm_rect.size
		_jump(Vector3(b.position.x + k.x * b.size.x, 0, b.position.y + k.y * b.size.y))
		click.accept_event()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
		# right-click on the map: send the selected men there
		var b2: Rect2 = G.world.bounds
		var k2 = ev.position / mm_rect.size
		var p = Vector3(b2.position.x + k2.x * b2.size.x, 0, b2.position.y + k2.y * b2.size.y)
		p.y = G.world.ground_y(p.x, p.z)
		var k3 = 0
		for m in G.pc.selection:
			if is_instance_valid(m) and m.state == "alive" and m.team == 0:
				var q = G.main._free_spot(p + Vector3((k3 % 4) - 1.5, 0, int(k3 / 4)) * 2.0)
				m.order = {"mode": "move", "point": q}
				G.pc._obey(m, q)
				k3 += 1
		if k3 > 0:
			G.ui.message("Moving to the point on the map")
		click.accept_event()

# a slim health bar over whatever's under the mouse
func _hover_bar() -> void:
	var cam: Camera3D = G.pc.cam
	var mp = get_viewport().get_mouse_position()
	if mm_rect.has_point(mp):
		return
	var o = cam.project_ray_origin(mp)
	var d = cam.project_ray_normal(mp)
	var s = G.pc.pick_soldier(o, d)
	var hp = -1.0
	var top = Vector3.ZERO
	var name_ = ""
	if s != null and (s.team == 0 or not Fog.hidden(s)) and s.state != "dead":
		hp = clampf(s.hp / 100.0, 0.0, 1.0)
		top = s.pos + Vector3(0, 2.1, 0)
		name_ = s.sname
	else:
		var v = G.pc.pick_vehicle(o, d)
		if v != null and not v.dead and (v.team == 0 or v.visible):
			hp = clampf(v.hp / v.spec["hp"], 0.0, 1.0)
			top = v.pos + Vector3(0, 3.2, 0)
			name_ = v.spec["name"]
		else:
			var hit = G.ray(o, o + d * 600.0, G.L_WORLD)
			if not hit.is_empty():
				var st = Build.site_at(hit["position"], 1.5)
				if st != null and not st["dead"] and (st["team"] == 0 or st.get("seen0", false)):
					hp = 1.0 - Build.damage(st)
					top = st["p"] + Vector3(0, 3.5, 0)
					name_ = st["name"]
	if hp < 0.0 or cam.is_position_behind(top):
		return
	var sp = cam.unproject_position(top)
	var w = 54.0
	draw_rect(Rect2(sp + Vector2(-w / 2.0 - 1, -1), Vector2(w + 2, 7)), Color(0, 0, 0, 0.75))
	var col = Color(0.4, 0.95, 0.4) if hp > 0.6 else (Color(1.0, 0.8, 0.3) if hp > 0.3 else Color(1.0, 0.3, 0.25))
	draw_rect(Rect2(sp + Vector2(-w / 2.0, 0), Vector2(w * hp, 5)), col)
	var tw = font.get_string_size(name_, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_string(font, sp + Vector2(-tw / 2.0, -4), name_, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.9))

# supply in hand and coming in, under the score
func _income() -> void:
	if Support.points.is_empty() or earn_hist.size() < 2:
		return
	var vs = get_viewport_rect().size
	var a = earn_hist[0]
	var z = earn_hist[earn_hist.size() - 1]
	var span = maxf(10.0, z[0] - a[0])
	var per_min = (z[1] - a[1]) * 60.0 / span
	# falling? compare the last minute with the minute before
	var mid_i = 0
	for i in range(earn_hist.size()):
		if z[0] - earn_hist[i][0] <= 60.0:
			mid_i = i
			break
	var recent = (z[1] - earn_hist[mid_i][1]) * 60.0 / maxf(10.0, z[0] - earn_hist[mid_i][0])
	var older = (earn_hist[mid_i][1] - a[1]) * 60.0 / maxf(10.0, earn_hist[mid_i][0] - a[0]) if mid_i > 0 else recent
	var trend = "▲" if recent > older + 1.0 else ("▼" if recent < older - 1.0 else "")
	var t = "Supply %d   ·   +%.0f / min %s" % [Support.points[0], maxf(0.0, per_min), trend]
	var tw = font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var at = Vector2(vs.x * 0.5 - tw * 0.5, 90.0)
	draw_rect(Rect2(at + Vector2(-10, -16), Vector2(tw + 20, 22)), Color(0, 0, 0, 0.5))
	draw_string(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.88, 0.5))
	if trend == "▼":
		draw_string(font, at + Vector2(tw - 10, 0), "▼", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.35, 0.3))
