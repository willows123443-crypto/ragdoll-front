extends Node3D
# Free camera, taking control of soldiers, aiming, recoil, and the sandbox tools.

var build_msg_t = 0.0
var cam: Camera3D
var free_pos = Vector3(-62, 7, -6)
var free_yaw = PI / 2.0 + 0.12
var free_pitch = -0.12
var cam_yaw = PI / 2.0
var cam_pitch = 0.0
var aim_point = Vector3.ZERO
var mouse_down = false
var rmb_down = false
var trig_latch = false
var r_drag = false
var bloom = 0.0
var kick = 0.0
var orbit = 0.0
var first_person = false
var selection: Array = []
var sel_rings: Array = []
var drag_from = null          # screen position where a selection box started
var drag_to = Vector2.ZERO
var r_press = Vector2.ZERO
var r_moved = false
var rts = false            # top-down commander camera
var rts_focus = Vector3.ZERO
var rts_dist = 75.0
var rts_yaw = PI / 2.0
var force_free = false   # development screenshots: keep the free camera while controlling a soldier

func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 65.0
	cam.near = 0.05
	cam.far = 700.0
	add_child(cam)
	cam.current = true

# ---------------------------------------------------------------- controlling a soldier
func set_rts(on: bool) -> void:
	rts = on
	if not on:
		return
	if G.player != null:
		leave_soldier()
	var W = G.world
	var home = W.rally_point(0) if W.spawn.size() > 0 else W.capture
	rts_focus = home.lerp(W.capture, 0.45)
	rts_yaw = atan2(W.capture.x - home.x, W.capture.z - home.z)
	rts_dist = 75.0
	G.ui.tab = "command"
	G.ui.tool = "sel"
	G.ui._render_tools()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func possess(s) -> void:
	if G.mode == "commander":
		G.ui.message("You're in command here: select soldiers and right-click to send them")
		return
	if s == null or s.state == "dead":
		G.ui.message("Pick a living soldier")
		return
	if G.player != null and G.player != s and is_instance_valid(G.player):
		G.player.is_player = false
	G.player = s
	s.is_player = true
	s.broken = false
	if s.rec != null:
		s.rec["player"] = true
	_apply_view(s)
	AI.release_cover(s)
	AI.stop_move(s)
	s.task = null
	s.route = null
	s.p_crouch = false
	s.p_prone = false
	if s.dragging != null:
		s.dragging.dragger = null
		s.dragging = null
	s.hand_t = null
	cam_yaw = s.aim_yaw
	cam_pitch = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	G.ui.message("Now controlling %s — %s, %s" % [s.sname, G.TEAM_NAMES[s.team], s.W["name"]])

func leave_soldier() -> void:
	if G.player == null:
		return
	if is_instance_valid(G.player):
		G.player.set_head_hidden(false)
		G.player.is_player = false
		G.player.ads = false
		G.player.decide_t = 0.0
	free_pos = cam.global_position
	free_yaw = cam_yaw
	free_pitch = clampf(cam_pitch, -1.4, 1.4)
	G.player = null
	mouse_down = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func player_update(s) -> void:
	var W = s.W
	s.morale_t -= G.DT
	if s.morale_t <= 0.0:
		s.morale_t = 0.5
		Morale.tick(s, 0.5)
		AI.supply_tick(s, 0.5)
	var f = Vector3(sin(cam_yaw), 0, cos(cam_yaw))
	var r = Vector3(-cos(cam_yaw), 0, sin(cam_yaw))
	var m = Vector3.ZERO
	if Input.is_key_pressed(KEY_W): m += f
	if Input.is_key_pressed(KEY_S): m -= f
	if Input.is_key_pressed(KEY_D): m += r
	if Input.is_key_pressed(KEY_A): m -= r
	var shift = Input.is_key_pressed(KEY_SHIFT)
	var sprint = shift and Input.is_key_pressed(KEY_W) and not s.p_crouch and not s.p_prone and not rmb_down
	var captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	s.ads = rmb_down and not sprint and captured
	var sp = 3.0 if s.p_prone else (1.9 if s.p_crouch else (6.3 if sprint else (2.2 if s.ads else 3.6)))
	if s.carrying != null or s.crate:
		sp *= 0.6
	s.want = m.normalized() * sp if m.length_squared() > 0.0 else Vector3.ZERO
	s.crouch_t = 0.9 if s.p_crouch else 0.0
	s.prone_t = s.p_prone
	var lean = 0.0
	if not sprint and not s.p_prone:
		lean = (1.0 if Input.is_key_pressed(KEY_E) else 0.0) - (1.0 if Input.is_key_pressed(KEY_Q) else 0.0)
	s.lean_t = lean
	# hold U next to a friendly construction site to help build it
	s.tool_mode = ""
	if s.hand_t != null and not Input.is_key_pressed(KEY_U):
		s.hand_t = null
	if Input.is_key_pressed(KEY_U) and m.length_squared() == 0.0:
		var st = Build.work_site(s.team, s.pos, 30.0)
		if st != null and G.dist2d(s.pos, st["p"]) < Build.build_radius(st) + 1.0:
			s.crouch_t = 0.75
			s.tool_mode = "hammer"
			s.hand_t = s.pos + G.flat(st["p"] - s.pos).normalized() * 0.55 + Vector3(0, 0.45, 0)
			Build.add_work(st, (1.6 if s.cls == "engineer" else 1.0) * G.DT)
			build_msg_t -= G.DT
			if build_msg_t <= 0.0:
				build_msg_t = 0.5
				G.ui.message("Building %s: %d%%" % [st["name"], int(100.0 * st["work"] / st["need"])])
		else:
			build_msg_t -= G.DT
			if build_msg_t <= 0.0:
				build_msg_t = 2.0
				G.ui.message("No friendly construction site here")
	var oy = s.pos.y + (0.3 if s.prone else 1.45 - 0.45 * s.crouch)
	s.aim_yaw = atan2(aim_point.x - s.pos.x, aim_point.z - s.pos.z)
	s.aim_pitch = clampf(atan2(aim_point.y - oy, G.dist2d(aim_point, s.pos)), -1.1, 1.1)
	s.ready_ = not sprint
	if s.reload_t > 0.0:
		s.reload_t -= G.DT
		if s.reload_t <= 0.0:
			s.finish_reload()
	s.fire_cd -= G.DT
	var pull = mouse_down and captured and (W["auto"] or not trig_latch)
	if pull and not sprint and s.fire_cd <= 0.0 and s.mag > 0 and s.reload_t <= 0.0 and not s.gun_blocked:
		trig_latch = true
		var dir = (aim_point - s.muzzle).normalized()
		var spread = W["spread"] * (0.35 if s.ads else 1.0) + (W["move_spread"] * (0.5 if s.ads else 1.0) if m.length_squared() > 0.0 else 0.0) + s.supp * 0.01 + bloom
		Combat.fire_weapon(s, s.muzzle, dir, spread)
		s.mag -= 1
		s.fire_cd = W["rof"]
		var rc = W["recoil"] * (0.6 if s.ads else 1.0) * (0.75 if s.p_crouch else 1.0)
		cam_pitch = clampf(cam_pitch + rc * randf_range(0.8, 1.2), -1.2, 1.2)
		cam_yaw += randf_range(-0.5, 0.5) * rc * 0.6
		bloom = minf(0.05, bloom + rc * 0.5)
		kick = minf(0.25, kick + 0.06 + rc)
		if s.mag <= 0 and not s.start_reload():
			G.ui.message("Out of ammo. Find an ammo crate, or press F over a fallen soldier")
	if not mouse_down:
		trig_latch = false

# ---------------------------------------------------------------- camera
# ---------------------------------------------------------------- placing structures: blueprint, facing, rotation
var ghost: Node3D = null
var ghost_key = ""
var ghost_p0 = Vector3.ZERO
var ghost_ok = -1
var test_mouse = null       # screenshots: pretend the mouse is here
var place_dir = -1          # 0..3 = +x, +z, -x, -z; -1 = face the enemy
var rot_drag = false
var rot_acc = 0.0
var rot_moved = false
const PLACE_DIRS = [Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0, -1)]

func place_front(p: Vector3, team: int) -> Vector3:
	if place_dir >= 0:
		return PLACE_DIRS[place_dir]
	var to = G.flat(Build._objective(team) - p)
	if absf(to.x) >= absf(to.z):
		return Vector3(signf(to.x) if to.x != 0.0 else 1.0, 0, 0)
	return Vector3(0, 0, signf(to.z))

func rotate_place(step: int) -> void:
	if place_dir < 0:
		var f = place_front(ghost_p0, _build_team())
		place_dir = PLACE_DIRS.find(f)
	place_dir = (place_dir + step + 4) % 4
	G.ui.message("Facing " + ["east", "south", "west", "north"][place_dir])

func _build_team() -> int:
	var team: int = G.ui.build_team
	return team if team < G.team_count() else 0

func _ghost_tick() -> void:
	var tool: String = G.ui.tool
	var show = G.started and G.player == null and tool.begins_with("b:") and not G.ui.menu_open() and not G.editor.active
	if not show:
		if ghost != null:
			ghost.queue_free()
			ghost = null
			ghost_key = ""
		return
	var mp = get_viewport().get_mouse_position() if test_mouse == null else test_mouse
	var o = cam.project_ray_origin(mp)
	var d = cam.project_ray_normal(mp)
	var hit = G.ray(o, o + d * 500.0, G.L_WORLD)
	if hit.is_empty():
		if ghost != null:
			ghost.visible = false
		return
	var p: Vector3 = hit.position
	var kind = tool.substr(2)
	var team = _build_team()
	var f = place_front(p, team)
	var key = "%s:%d:%d" % [kind, int(f.x), int(f.z)]
	if ghost == null or key != ghost_key or G.dist2d(p, ghost_p0) > 30.0:
		if ghost != null:
			ghost.queue_free()
		ghost = Build.ghost(kind, p, f)
		ghost_key = key
		ghost_p0 = p
		ghost_ok = -1
	ghost.visible = true
	ghost.position = Vector3(p.x - ghost_p0.x, G.world.ground_y(p.x, p.z) - G.world.ground_y(ghost_p0.x, ghost_p0.z), p.z - ghost_p0.z)
	var ok = Build.clear_at(p, kind) and Support.points.size() > team and (Build.cost(kind) == 0 or Support.points[team] >= Build.cost(kind))
	if int(ok) != ghost_ok:
		ghost_ok = int(ok)
		Build.ghost_tint(ghost, ok)

var rts_lines: MeshInstance3D = null
var rts_labels: Array = []
var last_squad_key = -1

# commander view: numbered squads, lines to where each squad was sent (bright for the selected ones)
func my_squads() -> Array:
	var team = 0 if G.player == null else G.player.team
	var out = []
	for q in G.squads:
		if q["team"] != team:
			continue
		for m in q["members"]:
			if is_instance_valid(m) and (m.state == "alive" or m.state == "riding"):
				out.append(q)
				break
	return out

func _rts_overlay() -> void:
	if rts_lines == null:
		rts_lines = MeshInstance3D.new()
		rts_lines.mesh = ImmediateMesh.new()
		var lm = StandardMaterial3D.new()
		lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lm.vertex_color_use_as_albedo = true
		lm.no_depth_test = true
		lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rts_lines.material_override = lm
		add_child(rts_lines)
	var on = rts and G.started and G.player == null
	rts_lines.visible = on
	var im: ImmediateMesh = rts_lines.mesh
	im.clear_surfaces()
	var qs = my_squads() if on else []
	var used = 0
	if on and not qs.is_empty():
		im.surface_begin(Mesh.PRIMITIVE_LINES)
		var any_line = false
		for qi in range(qs.size()):
			var q = qs[qi]
			var c = Vector3.ZERO
			var n = 0
			var dest = null
			var selected = false
			for m in q["members"]:
				if is_instance_valid(m) and (m.state == "alive" or m.state == "riding"):
					c += m.pos
					n += 1
					if m in selection:
						selected = true
					if dest == null and m.order != null and m.order.get("mode", "") == "move" and m.order.get("point") != null:
						dest = m.order["point"]
			c /= n
			if dest != null and G.dist2d(c, dest) > 4.0:
				var col = Color(1.0, 0.85, 0.25, 0.95) if selected else Color(1, 1, 1, 0.35)
				var a = c + Vector3(0, 1.0, 0)
				var b = Vector3(dest.x, G.world.ground_y(dest.x, dest.z) + 1.0, dest.z)
				im.surface_set_color(col); im.surface_add_vertex(a)
				im.surface_set_color(col); im.surface_add_vertex(b)
				# a cross where they're going
				for e in [Vector3(1.5, 0, 1.5), Vector3(1.5, 0, -1.5)]:
					im.surface_set_color(col); im.surface_add_vertex(b - e)
					im.surface_set_color(col); im.surface_add_vertex(b + e)
				any_line = true
			if used >= rts_labels.size():
				var l = Label3D.new()
				l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				l.no_depth_test = true
				l.fixed_size = true
				l.pixel_size = 0.0012
				l.font_size = 30
				l.outline_size = 10
				add_child(l)
				rts_labels.append(l)
			var lb: Label3D = rts_labels[used]
			used += 1
			lb.visible = true
			lb.text = "%d · %d men" % [qi + 1, n] if qi < 9 else "%d men" % n
			lb.modulate = Color(1.0, 0.9, 0.3) if selected else Color(0.85, 0.9, 1.0)
			lb.global_position = c + Vector3(0, 4.0, 0)
		if not any_line:
			im.surface_set_color(Color(0, 0, 0, 0)); im.surface_add_vertex(Vector3.ZERO)
			im.surface_set_color(Color(0, 0, 0, 0)); im.surface_add_vertex(Vector3.ZERO)
		im.surface_end()
	for k in range(used, rts_labels.size()):
		rts_labels[k].visible = false

# number keys in commander view: pick that squad; press it again to look at it
func select_squad(i: int) -> void:
	var qs = my_squads()
	if i >= qs.size():
		G.ui.message("No squad %d" % (i + 1))
		return
	var q = qs[i]
	selection = []
	var c = Vector3.ZERO
	for m in q["members"]:
		if is_instance_valid(m) and (m.state == "alive" or m.state == "riding"):
			selection.append(m)
			c += m.pos
	if selection.is_empty():
		return
	c /= selection.size()
	if last_squad_key == i:
		rts_focus = c
	last_squad_key = i
	G.ui.message("Squad %d selected (%d men) · right-click to send them · press %d again to look at them" % [i + 1, selection.size(), i + 1])

func _process(dt: float) -> void:
	_update_rings()
	_rts_overlay()
	_ghost_tick()
	bloom = maxf(0.0, bloom - dt * 0.08)
	kick = maxf(0.0, kick - dt * 1.6)
	var fov_t = 65.0
	if G.player != null and not is_instance_valid(G.player):
		G.player = null
	if G.player != null and not force_free:
		var s = G.player
		var cp = cos(cam_pitch)
		var d = Vector3(sin(cam_yaw) * cp, sin(cam_pitch), cos(cam_yaw) * cp)
		var r = Vector3(-cos(cam_yaw), 0, sin(cam_yaw))
		var back = 2.4
		var side = 0.6
		var piv: Vector3
		if s.state == "riding" and s.vehicle != null:
			piv = s.vehicle.center() + Vector3(0, 1.6 if s.vehicle.kind != "jeep" else 1.1, 0)
			back = {"jeep": 6.5, "truck": 10.0, "tank": 9.5, "heli": 16.0, "gunship": 14.0, "halftrack": 9.0, "motorbike": 5.0}.get(s.vehicle.kind, 8.0)
			side = 0.0
		elif s.state == "alive":
			piv = Vector3(s.pos.x, s.pos.y + (0.55 if s.prone else 1.55 - 0.45 * s.crouch), s.pos.z) + r * s.lean * 0.4
			if s.ads:
				back = 1.15
				side = 0.42
				fov_t = s.W["zoom"]
		else:
			piv = s.parts[0].global_position + Vector3(0, 0.6, 0)
			back = 4.0
			side = 0.3
		back += kick * 0.6
		var want_p = piv - d * back + r * side + Vector3(0, 0.12, 0)
		if first_person and s.state == "alive" and s.vehicle == null:
			# eyes: where the pose puts the head, carried by the real chest (steady, but moves with the body)
			var eye: Vector3 = s.parts[1].global_position + (s.targets[2].origin - s.targets[1].origin)
			want_p = eye + d * 0.12 + Vector3(0, 0.06, 0) - Vector3(0, kick * 0.05, 0)
			piv = want_p
		var hit = G.ray(piv, want_p, G.L_WORLD)
		if not hit.is_empty():
			want_p = piv + (want_p - piv).normalized() * maxf(0.2, piv.distance_to(hit.position) - 0.2)
		cam.global_position = want_p
		cam.look_at(want_p + d, Vector3.UP)
		if first_person and s.state == "alive" and s.gun_node != null:
			# first person: hold the gun in front of the camera, centred when aiming down the sights
			var up = r.cross(d).normalized()
			var off = Vector3(0.0, -0.13, 0.42) if s.ads else Vector3(0.2, -0.22, 0.48)
			off.y -= kick * 0.1
			s.gun_node.global_transform = Transform3D(Basis(up.cross(d), up, d), want_p + r * off.x + up * off.y + d * off.z - d * kick * 0.15)
		var aex: Array = s.rids.duplicate()
		if s.vehicle != null:
			aex.append(s.vehicle.body.get_rid())
		var ah = G.ray(want_p, want_p + d * 300.0, G.L_WORLD | G.L_BODY | G.L_VEH, aex)
		aim_point = want_p + d * 300.0 if ah.is_empty() else ah.position
		if aim_point.distance_to(piv) < 2.0:
			aim_point = want_p + d * 20.0
	else:
		if not G.started and not G.editor.active:
			orbit += dt * 0.05
			var c = G.world.capture
			var rad = maxf(55.0, G.world.TW * 0.22)
			free_pos = Vector3(c.x + cos(orbit) * rad, G.world.ground_y(c.x, c.z) + rad * 0.4, c.z + sin(orbit) * rad)
			free_yaw = atan2(c.x - free_pos.x, c.z - free_pos.z)
			free_pitch = -0.32
		if rts and G.started:
			# commander view: look down on a point on the ground, pan along it, zoom in and out
			var fw = Vector3(sin(rts_yaw), 0, cos(rts_yaw))
			var rt = Vector3(-cos(rts_yaw), 0, sin(rts_yaw))
			if not G.ui.typing():
				var spd = rts_dist * (1.6 if Input.is_key_pressed(KEY_SHIFT) else 0.75) * dt
				if Input.is_key_pressed(KEY_W): rts_focus += fw * spd
				if Input.is_key_pressed(KEY_S): rts_focus -= fw * spd
				if Input.is_key_pressed(KEY_D): rts_focus += rt * spd
				if Input.is_key_pressed(KEY_A): rts_focus -= rt * spd
				if Input.is_key_pressed(KEY_Q): rts_yaw += 1.4 * dt
				if Input.is_key_pressed(KEY_E): rts_yaw -= 1.4 * dt
			var bb: Rect2 = G.world.bounds
			rts_focus.x = clampf(rts_focus.x, bb.position.x, bb.end.x)
			rts_focus.z = clampf(rts_focus.z, bb.position.y, bb.end.y)
			rts_focus.y = G.world.ground_y(rts_focus.x, rts_focus.z)
			free_yaw = rts_yaw
			free_pitch = -0.98 - 0.25 * clampf((rts_dist - 30.0) / 150.0, 0.0, 1.0)
			var cpr = cos(free_pitch)
			var dr = Vector3(sin(free_yaw) * cpr, sin(free_pitch), cos(free_yaw) * cpr)
			free_pos = rts_focus - dr * rts_dist
		var cp = cos(free_pitch)
		var d = Vector3(sin(free_yaw) * cp, sin(free_pitch), cos(free_yaw) * cp)
		var r = Vector3(-cos(free_yaw), 0, sin(free_yaw))
		if (G.started or G.editor.active) and not G.ui.typing() and not G.editor.typing() and not rts:
			var sp = (40.0 if Input.is_key_pressed(KEY_SHIFT) else 14.0) * dt
			if Input.is_key_pressed(KEY_W): free_pos += d * sp
			if Input.is_key_pressed(KEY_S): free_pos -= d * sp
			if Input.is_key_pressed(KEY_D): free_pos += r * sp
			if Input.is_key_pressed(KEY_A): free_pos -= r * sp
			if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_SPACE): free_pos.y += sp
			if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_C) or Input.is_key_pressed(KEY_CTRL): free_pos.y -= sp
		free_pos.y = clampf(free_pos.y, G.world.ground_y(free_pos.x, free_pos.z) + 0.6, 240.0 if rts else 140.0)
		cam.global_position = free_pos
		cam.look_at(free_pos + d, Vector3.UP)
	if absf(cam.fov - fov_t) > 0.05:
		cam.fov += (fov_t - cam.fov) * minf(1.0, dt * 14.0)
	if G.player != null and is_instance_valid(G.player) and G.player.supp > 0.5:
		Combat.shake = maxf(Combat.shake, (G.player.supp - 0.5) * 0.25)
	if Combat.shake > 0.0:
		cam.global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * Combat.shake * 0.25
		Combat.shake = maxf(0.0, Combat.shake - dt * 2.5)
	G.main.follow_sun(cam.global_position, -cam.global_basis.z)

# ---------------------------------------------------------------- input
func _unhandled_input(ev: InputEvent) -> void:
	if G.editor.active:
		# map editor: right-drag looks around, the wheel moves, everything else goes to the editor
		if ev is InputEventMouseMotion and r_drag:
			var inv = -1.0 if G.settings["invert_y"] else 1.0
			free_yaw -= ev.relative.x * 0.004 * G.settings["sens"]
			free_pitch = clampf(free_pitch - ev.relative.y * 0.004 * G.settings["sens"] * inv, -1.45, 1.45)
		elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_RIGHT:
			r_drag = ev.pressed
		elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed:
			free_pos += Vector3(sin(free_yaw) * cos(free_pitch), sin(free_pitch), cos(free_yaw) * cos(free_pitch)) * 4.0
		elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed:
			free_pos -= Vector3(sin(free_yaw) * cos(free_pitch), sin(free_pitch), cos(free_yaw) * cos(free_pitch)) * 4.0
		G.editor.handle(ev)
		return
	if not G.started or G.ui.menu_open():
		return
	if ev is InputEventMouseMotion:
		var k = 0.0024 * G.settings["sens"] * (cam.fov / 65.0)
		var inv = -1.0 if G.settings["invert_y"] else 1.0
		if G.player != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			cam_yaw -= ev.relative.x * k
			cam_pitch = clampf(cam_pitch - ev.relative.y * k * inv, -1.2, 1.2)
		elif G.player == null and drag_from != null:
			drag_to = ev.position
			G.ui.sel_box_changed()
		if G.player == null and rot_drag:
			rot_acc += ev.relative.x
			if absf(rot_acc) > 70.0:
				rotate_place(1 if rot_acc > 0.0 else -1)
				rot_acc = 0.0
				rot_moved = true
		elif G.player == null and r_drag and rts:
			if ev.position.distance_to(r_press) > 6.0:
				r_moved = true
			rts_yaw -= ev.relative.x * 0.004 * G.settings["sens"]
		elif G.player == null and r_drag:
			if ev.position.distance_to(r_press) > 6.0:
				r_moved = true
			free_yaw -= ev.relative.x * 0.004 * G.settings["sens"]
			free_pitch = clampf(free_pitch - ev.relative.y * 0.004 * G.settings["sens"] * inv, -1.45, 1.45)
	elif ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_RIGHT and G.player == null and G.ui.tool.begins_with("b:"):
			# placing a structure: hold the right button and move the mouse to turn it (a click turns it a quarter)
			if ev.pressed:
				rot_drag = true
				rot_acc = 0.0
				rot_moved = false
			else:
				if rot_drag and not rot_moved:
					rotate_place(1)
				rot_drag = false
		elif ev.button_index == MOUSE_BUTTON_RIGHT:
			if G.player != null:
				rmb_down = ev.pressed
			else:
				r_drag = ev.pressed
				if ev.pressed:
					r_press = ev.position
					r_moved = false
				elif not r_moved and not selection.is_empty():
					_order_move(ev.position)
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				if G.player != null:
					if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
						Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
					else:
						mouse_down = true
				elif G.ui.tool == "sel":
					drag_from = ev.position
					drag_to = ev.position
				else:
					use_tool(ev.position)
			else:
				mouse_down = false
				if drag_from != null and G.player == null:
					_finish_select(ev.shift_pressed)
					drag_from = null
					G.ui.sel_box_changed()
		elif ev.button_index == MOUSE_BUTTON_MIDDLE and ev.pressed and G.player != null and G.player.state == "alive":
			var ps = G.player
			if ps.rgren > 0 and ps.wid == "rifle":
				Combat.launch_rifle_grenade(ps, ps.muzzle, aim_point)
				ps.rgren -= 1
				G.ui.message("Rifle grenade away (%d left)" % ps.rgren)
			else:
				G.ui.message("No rifle grenades (riflemen carry them, on the rifle)")
		elif (ev.button_index == MOUSE_BUTTON_WHEEL_UP or ev.button_index == MOUSE_BUTTON_WHEEL_DOWN) and G.player == null and ev.pressed and rts:
			rts_dist = clampf(rts_dist * (0.88 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 1.14), 14.0, 230.0)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_UP and G.player == null and ev.pressed:
			free_pos += Vector3(sin(free_yaw) * cos(free_pitch), sin(free_pitch), cos(free_yaw) * cos(free_pitch)) * 2.0
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and G.player == null and ev.pressed:
			free_pos -= Vector3(sin(free_yaw) * cos(free_pitch), sin(free_pitch), cos(free_yaw) * cos(free_pitch)) * 2.0
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		_key(ev.keycode)

func _key(k: int) -> void:
	if k == KEY_T and G.player == null:
		Engine.time_scale = 0.25 if Engine.time_scale > 0.5 else 1.0
	elif k == KEY_T and G.player != null:
		G.player.light_on = not G.player.light_on
		G.ui.message("Flashlight on" if G.player.light_on else "Flashlight off")
	elif k == KEY_P:
		get_tree().paused = not get_tree().paused
	if G.player != null:
		var s = G.player
		if k == KEY_X:
			leave_soldier()
		elif k == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif k == KEY_R and s.state == "alive":
			if not s.start_reload() and s.reserve <= 0:
				G.ui.message("No spare magazines")
		elif k == KEY_F and s.state == "riding":
			s.dismount(false)
			G.ui.message("Got out")
		elif k == KEY_Q and s.state == "riding" and s.vehicle != null:
			var rv = s.vehicle
			if rv.kind == "bridger":
				G.ui.message(VehExt.lay_bridge(rv))
			elif not rv.spec.get("air", false) and not rv.spec.get("static", false) and rv.kind != "tank":
				G.ui.message(VehExt.try_tow(rv))
		elif k >= KEY_1 and k <= KEY_4 and s.state == "riding":
			var v = s.vehicle
			var i = k - KEY_1
			if i < v.seats.size() and v.seats[i] == null:
				v.seats[s.seat] = null
				var hid = s.hidden_in_vehicle
				s.vehicle = null
				s.state = "alive"
				for b in s.parts:
					b.freeze = false
					b.remove_collision_exception_with(v.body)
				s.mount(v, i)
				G.ui.message("Seat %d: %s" % [i + 1, v.spec["seats"][i]["role"]])
		elif k == KEY_F and s.state == "alive" and _carry_or_crate(s):
			pass
		elif k == KEY_F and s.state == "alive":
			var v = _near_vehicle(s)
			if v != null:
				var i = v.free_seat("driver")
				if s.mount(v, i):
					var hint = "WASD drive · mouse aim · click fire · 1–4 change seat · F get out"
					if v.spec.get("plane", false):
						hint = "Mouse steers the nose · W/S throttle · click guns · Shift+click bomb · F bail out"
					elif v.kind == "bridger":
						hint = "WASD drive · Q at the water's edge lays the bridge · F get out"
					elif not v.spec.get("air", false) and not v.spec.get("static", false) and v.kind != "tank":
						hint += " · Q tow a gun or broken vehicle behind you"
					G.ui.message("In the %s (%s). %s" % [v.spec["name"].to_lower(), v.spec["seats"][i]["role"], hint])
				else:
					G.ui.message("No free seats")
			else:
				_pick_up(s)
		elif k == KEY_O and s.state == "alive":
			_toggle_follow(s)
		elif k == KEY_L and s.state == "alive":
			Combat.flare(s.pos, aim_point)
			G.ui.message("Flare away")
		elif k == KEY_Y:
			first_person = not first_person
			_apply_view(s)
			G.ui.message("First-person view" if first_person else "Third-person view")
		elif k == KEY_C:
			s.p_crouch = not s.p_crouch
			s.p_prone = false
		elif k == KEY_Z:
			s.p_prone = not s.p_prone
			s.p_crouch = false
		elif k == KEY_G and s.grenades > 0 and s.state == "alive":
			# Shift+G cooks it first so it goes off soon after landing
			Combat.throw_grenade(s, _throw_target(s), "frag", 1.4 if Input.is_key_pressed(KEY_SHIFT) else 0.0)
		elif k == KEY_V and s.smokes > 0 and s.state == "alive":
			Combat.throw_grenade(s, _throw_target(s), "marker" if Input.is_key_pressed(KEY_SHIFT) else "smoke")
		elif k >= KEY_1 and k <= KEY_9 and s.state == "alive":
			s.primary = null
			s.set_weapon(G.WEAPON_LIST[k - KEY_1])
			G.ui.message(s.W["name"])
		elif k == KEY_B and s.state == "alive":
			_class_action(s)
		elif k == KEY_N and s.state == "alive":
			if s.mines > 0:
				Combat.place_mine(s, s.pos + Vector3(sin(cam_yaw), 0, cos(cam_yaw)) * 1.2, "at" if Input.is_key_pressed(KEY_SHIFT) else "ap")
				s.mines -= 1
				G.ui.message("Mine placed (%d left). Shift+N for an anti-tank mine" % s.mines)
			else:
				G.ui.message("No mines (engineers carry them)")
		elif k == KEY_I and s.state == "alive":
			var tgt = aim_point
			if G.dist2d(tgt, s.pos) > 6.0:
				G.ui.message("Get closer to dismantle something (within 6 m)")
			else:
				var o2 = cam.global_position
				var hit2 = G.ray(o2, o2 + (tgt - o2).normalized() * ((tgt - o2).length() + 0.5), G.L_WORLD)
				if not dismantle_at(tgt, hit2):
					G.ui.message("Nothing to dismantle there")
		elif k == KEY_K and s.state == "alive" and Input.is_key_pressed(KEY_SHIFT):
			if s.stickies > 0:
				Combat.throw_grenade(s, _throw_target(s), "sticky")
			else:
				G.ui.message("No sticky bombs (anti-tank soldiers and engineers carry them)")
		elif k == KEY_K and s.state == "alive":
			if s.satchels > 0:
				Combat.throw_grenade(s, _throw_target(s), "satchel")
			else:
				G.ui.message("No satchel charges (engineers carry them)")
	else:
		if k == KEY_R and G.ui.tool.begins_with("b:"):
			rotate_place(1)
			return
		if k == KEY_V and G.started and G.mode != "commander":
			set_rts(not rts)
			if rts:
				rts_focus = G.world.ground_y(free_pos.x, free_pos.z) * Vector3.UP + Vector3(free_pos.x, 0, free_pos.z) + Vector3(sin(free_yaw), 0, cos(free_yaw)) * 30.0
				rts_yaw = free_yaw
			G.ui.message("Commander view: WASD pans, wheel zooms, Q/E turn, click selects a squad, right-click sends it · V to leave" if rts else "Free camera")
			return
		if k >= KEY_1 and k <= KEY_9 and rts:
			select_squad(k - KEY_1)
		elif k >= KEY_1 and k <= KEY_9:
			G.ui.pick_tool(k - KEY_1)
		elif k == KEY_F:
			var cp = cos(free_pitch)
			var d = Vector3(sin(free_yaw) * cp, sin(free_pitch), cos(free_yaw) * cp)
			possess(pick_soldier(cam.global_position, d))

# take apart whatever is at a point: a whole construction, an emplacement, or one piece of a building
func dismantle_at(p: Vector3, hit: Dictionary) -> bool:
	for v in G.vehicles:
		if v.spec.get("static", false) and G.dist2d(v.pos, p) < 2.2:
			for st in Build.sites:
				if st["veh"] == v:
					Build.dismantle(st)
					G.ui.message("Dismantled the %s" % st["name"])
					return true
			v.remove()
			G.fx.dust_cloud(v.pos + Vector3(0, 0.5, 0), 2.0)
			G.ui.message("Dismantled the %s" % v.spec["name"])
			return true
	var st = Build.site_at(p, 0.3)
	if st != null:
		var nm = st["name"]
		Build.dismantle(st)
		G.ui.message("Dismantled the %s" % nm)
		return true
	if not hit.is_empty() and hit.has("collider") and is_instance_valid(hit["collider"]) and hit["collider"].has_meta("col"):
		var c = hit["collider"].get_meta("col")
		if c.alive:
			G.world.destroy_col(c)
			G.ui.message("Piece taken down")
			return true
	return false

func _throw_target(s) -> Vector3:
	var t = aim_point
	if G.dist2d(t, s.pos) > 32.0:
		t = s.pos + G.flat(t - s.pos).normalized() * 32.0
		t.y = G.world.ground_y(t.x, t.z)
	return t

func pick_soldier(o: Vector3, d: Vector3):
	var hit = G.ray(o, o + d * 400.0, G.L_WORLD | G.L_BODY)
	if not hit.is_empty() and hit.collider.has_meta("soldier"):
		return hit.collider.get_meta("soldier")
	var best = null
	var bd = 1e9
	for s in G.soldiers:
		var c = s.chest()
		var t = (c - o).dot(d)
		if t < 0.0:
			continue
		var perp = (o + d * t).distance_to(c)
		if perp < 1.1 and perp + t * 0.01 < bd:
			bd = perp + t * 0.01
			best = s
	return best

func use_tool(screen: Vector2) -> void:
	var o = cam.project_ray_origin(screen)
	var d = cam.project_ray_normal(screen)
	var hit = G.ray(o, o + d * 400.0, G.L_WORLD)
	var tool = G.ui.tool
	if G.mode == "commander" and not (tool == "sel" or tool.begins_with("b:") or tool.begins_with("sup:") or tool in ["up", "camo", "rep", "dis"]):
		return
	if tool == "ctl":
		possess(pick_soldier(o, d))
		return
	if tool == "mvA" or tool == "mvB" or tool == "mv":
		var team = 0 if tool == "mvA" else (1 if tool == "mvB" else _build_team())
		var gp = G.ray(o, o + d * 500.0, G.L_WORLD)
		if not gp.is_empty():
			G.orders[team] = {"mode": "move", "point": gp.position}
			G.fx.order_marker(gp.position)
			G.ui.message("%s: move to the marked point" % G.TEAM_NAMES[team])
			for s in G.soldiers:
				if s.team == team:
					s.decide_t = 0.0
		return
	if tool == "push":
		var s = pick_soldier(o, d)
		if s != null:
			if s.state == "alive" or s.state == "getup":
				s.fall(1.5)
			s.push(1, G.flat(d).normalized() * 7.0 + Vector3(0, 2, 0), 0.5)
		return
	if hit.is_empty():
		return
	var p: Vector3 = hit.position
	if tool == "a1" or tool == "b1" or tool == "s1":
		G.main.spawn_soldier(0 if tool == "a1" else (1 if tool == "b1" else _build_team()), p.x, p.z, "")
	elif tool == "a5" or tool == "b5" or tool == "s5":
		var team = 0 if tool == "a5" else (1 if tool == "b5" else _build_team())
		var fw = 1.0 if team == 0 else -1.0
		for off in [[0, 0], [-1.6, -1.6], [1.6, -1.6], [-3.2, -3.2], [3.2, -3.2]]:
			G.main.spawn_soldier(team, p.x + off[1] * fw, p.z + off[0], "")
	elif tool == "boom":
		Combat.explode(p + Vector3(0, 0.1, 0), null, 1.1)
	elif tool == "mortar":
		Combat.mortar_strike(p, 7)
		G.ui.message("Mortar barrage incoming")
	elif tool == "smoke":
		Combat.smoke_at(p, 26.0)
	elif tool == "flare":
		Combat.flare(p + Vector3(0, 0, 0), p)
	elif tool.begins_with("sup:"):
		var what = tool.substr(4)
		if Support.call_in(0, what, p):
			G.ui.message("%s called in" % Support.NAMES[what])
		else:
			G.ui.message("Not enough supply points (%d needed, %d available)" % [Support.COSTS[what], Support.points[0]])
	elif tool.begins_with("v:"):
		var parts = tool.split(":")
		var kind: String = parts[1]
		var team = int(parts[2]) if parts.size() > 2 else _build_team()
		var en: Vector3 = G.world.rally_point((team + 1) % G.team_count())
		G.main.spawn_vehicle(kind, team, p, atan2(en.x - p.x, en.z - p.z), kind != "truck")
	elif tool.begins_with("b:"):
		var kind = tool.substr(2)
		var team: int = _build_team()
		if G.mode == "commander":
			team = 0
		var to = place_front(p, team)
		if not Build.clear_at(p, kind):
			G.ui.message("No room for a %s there" % Build.KINDS[kind]["name"])
			return
		var c = Build.cost(kind)
		if c > 0:
			if Support.points[team] < c:
				G.ui.message("Not enough supply points: a %s costs %d, you have %d" % [Build.KINDS[kind]["name"], c, Support.points[team]])
				return
			Support.points[team] -= c
		Build.place(kind, team, p, to, false, true)
		G.ui.message("%s site marked out for %s%s · engineers will build it" % [Build.KINDS[kind]["name"], G.TEAM_NAMES[team], (" (-%d points)" % c) if c > 0 else ""])
	elif tool == "dis":
		dismantle_at(p, hit)
	elif tool == "up" or tool == "camo" or tool == "rep":
		var st = Build.site_at(p, 0.5)
		if st == null:
			G.ui.message("Click on a structure")
		elif tool == "up":
			if Build.upgrade(st) == null:
				G.ui.message("Nothing to upgrade (sandbags, MG nests and FOBs can be upgraded once finished)")
		elif tool == "camo":
			if st["done"]:
				Build.add_camo(st)
				G.ui.message("Camouflage net over the %s" % st["name"])
		elif Build.needs_repair(st):
			Build.rebuild(st)
			G.ui.message("Engineers will rebuild the %s" % st["name"])
		else:
			G.ui.message("The %s doesn't need rebuilding" % st["name"])
	elif tool == "spA" or tool == "spB" or tool == "sp":
		G.world.spawn[0 if tool == "spA" else (1 if tool == "spB" else _build_team())] = Vector3(p.x, 0, p.z)
		G.main.refresh_markers()

# F while controlling a soldier: take the gun of a fallen soldier at your feet (with their ammo),
# or just their spare ammo if it's the same kind of gun
# F also picks up a wounded friend (and puts them down), or an ammo box from a crate
func _carry_or_crate(s) -> bool:
	if s.carrying != null:
		var w = s.carrying
		s.carrying = null
		if is_instance_valid(w):
			w.carried_by = null
		G.ui.message("Put %s down" % (w.sname if is_instance_valid(w) else "them"))
		return true
	if s.crate:
		AI.drop_crate(s)
		G.ui.message("Ammo box dropped: your squad can restock here")
		return true
	for o in G.soldiers:
		if o != s and o.team == s.team and o.state == "wounded" and o.dragger == null and o.carried_by == null and G.dist2d(o.pos, s.pos) < 1.8:
			s.carrying = o
			o.carried_by = s
			G.ui.message("Carrying %s. Get them to a medic or the field hospital · F to put down" % o.sname)
			return true
	if _near_vehicle(s) != null:
		return false
	for a in G.world.ammo_points:
		if (a["team"] == s.team or a["team"] < 0) and G.dist2d(a["p"], s.pos) < 2.4 and a.get("stock", 50.0) > 15.0 and not a.get("box", false):
			if a.has("stock"):
				a["stock"] -= 15.0
			s.set_crate(true)
			G.ui.message("Picked up an ammo box · F to drop it where your squad needs it")
			return true
	# kick in a window or a door
	var pn = Doors.pane_near(s.chest(), 1.6)
	if pn != null:
		s.kick(G.flat(pn["c"] - s.pos).normalized())
		Doors.shatter(pn)
		return true
	var dr = Doors.door_near(s.pos, 1.8)
	if dr != null and dr["goal"] <= 0.0:
		s.kick(G.flat(dr["c"] - s.pos).normalized())
		Doors.open(dr, s.pos)
		return true
	return false

func _pick_up(s) -> void:
	var best = null
	var bd = 2.2
	for o in G.soldiers:
		if o.state == "dead" and o != s:
			var d = G.dist2d(o.parts[0].global_position, s.pos)
			if d < bd:
				bd = d
				best = o
	if best == null:
		G.ui.message("Nothing to pick up here")
		return
	if best.wid == s.wid:
		AI.scavenge(s, best)
		return
	var their = [best.wid, best.mag, best.reserve]
	var mine = [s.wid, s.mag, s.reserve]
	s.set_weapon(their[0])
	s.mag = their[1]
	s.reserve = their[2]
	best.set_weapon(mine[0])
	best.mag = mine[1]
	best.reserve = mine[2]
	G.ui.message("Picked up %s's %s" % [best.sname, s.W["name"]])

# first-person view hides your own head so it doesn't block the camera
func _apply_view(s) -> void:
	if s == null or not is_instance_valid(s):
		return
	s.set_head_hidden(first_person)
	cam.set_cull_mask_value(4, not first_person)

func _near_vehicle(s):
	var best = null
	var bd = 1e9
	for v in G.vehicles:
		if v.dead or (v.team != s.team and v.driver() != null) or (v.spec.get("air", false) and not v.landed()):
			continue
		var d = G.dist2d(v.pos, s.pos) - v.spec["len"] * 0.5
		if d < 2.2 and d < bd:
			bd = d
			best = v
	return best

# controlling a soldier who sits in a vehicle
func rider_update(s) -> void:
	var v = s.vehicle
	var role: String = v.spec["seats"][s.seat]["role"]
	var captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var thr = 0.0
	var steer = 0.0
	if role == "driver":
		if Input.is_key_pressed(KEY_W): thr += 1.0
		if Input.is_key_pressed(KEY_S): thr -= 1.0
		if Input.is_key_pressed(KEY_A): steer += 1.0
		if Input.is_key_pressed(KEY_D): steer -= 1.0
	v.player_inputs["thr"] = thr
	v.player_inputs["steer"] = steer
	var climb = 0.0
	if role == "driver" and v.spec.get("air", false):
		if Input.is_key_pressed(KEY_SPACE): climb += 1.0
		if Input.is_key_pressed(KEY_C) or Input.is_key_pressed(KEY_CTRL): climb -= 1.0
	v.player_inputs["climb"] = climb
	v.player_inputs["aim"] = aim_point
	v.player_inputs["fire"] = mouse_down and captured and (role == "gunner" or (role == "driver" and v.kind in ["tank", "gunship", "armoredcar"] and v.gunner() == null))
	s.aim_yaw = atan2(aim_point.x - s.pos.x, aim_point.z - s.pos.z)
	s.morale = maxf(s.morale, 60.0)

# ---------------------------------------------------------------- commanding soldiers
func _finish_select(add: bool) -> void:
	if not add:
		selection = []
	var a: Vector2 = drag_from
	var b: Vector2 = drag_to
	if a.distance_to(b) < 6.0:
		var o = cam.project_ray_origin(b)
		var d = cam.project_ray_normal(b)
		var s = pick_soldier(o, d)
		if s == null and rts:
			# from up high, a click near a soldier counts
			var hit = G.ray(o, o + d * 600.0, G.L_WORLD)
			if not hit.is_empty():
				var bd = 4.0
				for c in G.soldiers:
					if c.state != "dead" and c.team == (0 if G.mode == "commander" else c.team):
						var dd = G.dist2d(c.pos, hit.position)
						if dd < bd:
							bd = dd
							s = c
		if s != null and s.state != "dead":
			if rts and s.squad != null:
				# commander view: a click takes the whole squad
				for m in s.squad["members"]:
					if is_instance_valid(m) and m.state != "dead" and not (m in selection):
						selection.append(m)
			elif s in selection:
				selection.erase(s)
			else:
				selection.append(s)
	else:
		var r = Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (a - b).abs())
		for s in G.soldiers:
			if s.state == "dead" or cam.is_position_behind(s.chest()) or (G.mode == "commander" and s.team != 0):
				continue
			if r.has_point(cam.unproject_position(s.chest())) and not (s in selection):
				selection.append(s)
	if not selection.is_empty():
		G.ui.message("%d selected. Right-click the ground to send them there" % selection.size())

func _order_move(screen: Vector2) -> void:
	var o = cam.project_ray_origin(screen)
	var d = cam.project_ray_normal(screen)
	var hit = G.ray(o, o + d * 500.0, G.L_WORLD)
	if hit.is_empty():
		return
	var p: Vector3 = hit.position
	var n = 0
	for s in selection:
		if not is_instance_valid(s) or s.state == "dead":
			continue
		# spread them out a little around the point
		var off = Vector3((n % 4) - 1.5, 0, int(n / 4) - 1.0) * 2.0
		s.order = {"mode": "move", "point": p + off}
		s.decide_t = 0.0
		if s.cover != null:
			AI.release_cover(s)
		n += 1
	G.fx.order_marker(p)
	G.ui.message("Moving %d soldier%s" % [n, "" if n == 1 else "s"])

func order_selected(mode: String) -> void:
	for s in selection:
		if is_instance_valid(s) and s.state != "dead":
			s.order = null if mode == "free" else {"mode": mode, "point": s.pos}
			s.decide_t = 0.0
	G.ui.message({"free": "Selected soldiers act on their own", "hold": "Selected soldiers hold their ground", "charge": "Selected soldiers charge!"}[mode])

func clear_selection() -> void:
	selection = []

# when you're a squad leader (or anyone, really): your squad follows you around
func _toggle_follow(s) -> void:
	var q = s.squad
	if q == null:
		return
	var on = q.get("follow") != s
	q["follow"] = s if on else null
	for m in q["members"]:
		if is_instance_valid(m) and m != s and m.state != "dead":
			m.order = {"mode": "follow", "who": s, "point": null} if on else null
			m.decide_t = 0.0
	G.ui.message("Squad: follow me!" if on else "Squad: carry on")
	if on:
		G.fx.callout(s, G.pick(["On me!", "Follow me!", "With me, squad!"]))

func _update_rings() -> void:
	selection = selection.filter(func(x): return is_instance_valid(x) and x.state != "dead")
	while sel_rings.size() < selection.size():
		var r = MeshInstance3D.new()
		var tm = TorusMesh.new()
		tm.inner_radius = 0.42
		tm.outer_radius = 0.5
		r.mesh = tm
		var m = StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.85, 0.25)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.no_depth_test = true
		r.material_override = m
		r.scale = Vector3(1, 0.3, 1)
		add_child(r)
		sel_rings.append(r)
	for i in range(sel_rings.size()):
		var r = sel_rings[i]
		if i < selection.size():
			r.visible = true
			var s = selection[i]
			var p: Vector3 = s.pos if s.state == "alive" or s.state == "riding" else s.parts[0].global_position
			r.global_position = Vector3(p.x, p.y + 0.06, p.z)
			var sc = 1.0 + (rts_dist / 30.0 if rts else 0.0)
			r.scale = Vector3(sc, 0.3, sc)
		else:
			r.visible = false

# B: whatever your class is good at
func _class_action(s) -> void:
	match s.cls:
		"engineer":
			if s.kits <= 0:
				G.ui.message("No sandbags left. Restock at an ammo crate")
				return
			var f = Vector3(sin(cam_yaw), 0, cos(cam_yaw))
			var at = s.pos + f * 1.6
			if G.world.inside_any(at.x, at.z, 0.6):
				G.ui.message("No room to build there")
				return
			G.world.build_now(func(): G.world.sandbags(at.x, at.z, 3.0, absf(f.z) > absf(f.x)))
			s.kits -= 1
			G.ui.message("Sandbags built (%d left)" % s.kits)
			# repair anything we're standing next to as well
			for v in G.vehicles:
				if v.team == s.team and not v.dead and G.dist2d(v.pos, s.pos) < v.spec["len"] * 0.5 + 2.0:
					v.repair(250.0)
					G.ui.message("Repaired the %s" % v.spec["name"].to_lower())
		"medic":
			var best = s
			var bd = 2.5
			for o in G.soldiers:
				if o.team == s.team and o != s and (o.state == "alive" or o.state == "wounded") and G.dist2d(o.pos, s.pos) < bd:
					bd = G.dist2d(o.pos, s.pos)
					best = o
			if best.state == "wounded":
				best.heal_t = 99.0
			best.hp = 100.0
			Stats.healed(s)
			G.ui.message("Patched up %s" % ("yourself" if best == s else best.sname))
		"radio":
			if s.radio_cd > 0.0:
				G.ui.message("Artillery is busy, %d s" % int(s.radio_cd))
				return
			s.radio_cd = 30.0
			ClassAI.call_artillery(s, aim_point)
			G.ui.message("Fire mission called on the crosshair")
		"sniper", "spotter":
			var o = pick_soldier(cam.global_position, (aim_point - cam.global_position).normalized())
			if o != null and o.team != s.team:
				for f in G.soldiers:
					if f.team == s.team and f.state != "dead":
						AI.add_intel(f, o, o.pos, 0.0, true)
				G.ui.message("Target marked for the team")
				G.ui.radio(s.team, "%s: enemy marked at %s" % [s.sname, AI.grid_ref(o.pos)])
		_:
			G.ui.message("%s: no special action (engineers build, medics heal, radio calls artillery, snipers mark)" % G.CLASSES[s.cls]["name"])

func set_formation(form: String) -> void:
	var qs = []
	for s in selection:
		if is_instance_valid(s) and s.squad != null and not (s.squad in qs):
			qs.append(s.squad)
	if qs.is_empty():
		qs = G.squads.filter(func(q): return q["team"] == 0)
	for q in qs:
		q["form_fixed"] = form != "auto"
		if form != "auto":
			q["form"] = form
	G.ui.message("Formation: %s (%d squad%s)" % [form, qs.size(), "" if qs.size() == 1 else "s"])
