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
	if not Rules.free_tools() and s.team != 0:
		G.ui.message("That's one of theirs: pick one of your own soldiers")
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
	if pull and not sprint and not s.swim and s.fire_cd <= 0.0 and s.mag > 0 and s.reload_t <= 0.0 and not s.gun_blocked:
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
	if not Rules.free_tools():
		return 0 if G.player == null else G.player.team
	var team: int = G.ui.build_team
	return team if team < G.team_count() else 0

# where a ray from the camera meets the terrain
func ground_hit(o: Vector3, d: Vector3):
	var t0 = 0.0
	var t1 = -1.0
	var t = 0.0
	while t < 600.0:
		var q = o + d * t
		if q.y <= G.world.ground_y(q.x, q.z):
			t1 = t
			break
		t0 = t
		t += 2.0
	if t1 < 0.0:
		return null
	for k in range(14):
		var tm = (t0 + t1) * 0.5
		var q2 = o + d * tm
		if q2.y <= G.world.ground_y(q2.x, q2.z):
			t1 = tm
		else:
			t0 = tm
	var r = o + d * t1
	return Vector3(r.x, G.world.ground_y(r.x, r.z), r.z)

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
	# the ground under the mouse (not the preview itself, or it chases its own tail and shakes)
	var gh = ground_hit(o, d)
	if gh == null:
		if ghost != null:
			ghost.visible = false
		return
	var p: Vector3 = gh
	p = Vector3(snappedf(p.x, 0.5), p.y, snappedf(p.z, 0.5))
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
	var ok = Build.clear_at(p, kind) and not Build.too_near_hq(kind, team, p) and Support.points.size() > team and (Build.cost(kind) == 0 or Support.points[team] >= Build.cost(kind))
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
	if not on:
		for mk in dest_marks:
			mk.visible = false
		return
	# one line per squad on foot (from where its men actually are) and one per vehicle (from the vehicle)
	var team = 0
	var glines = {}
	for s in G.soldiers:
		if s.team != team or not (s.state == "alive" or s.state == "riding") or s.is_player:
			continue
		var key = ""
		var at: Vector3
		var dest = null
		if s.state == "riding":
			var v = s.vehicle
			if v == null or not is_instance_valid(v) or v.dead:
				continue
			key = "v%d" % v.get_instance_id()
			at = v.pos
			dest = v.cmd
		else:
			if s.order == null or s.order.get("mode", "") != "move" or s.order.get("point") == null:
				continue
			key = "q%d" % (G.squads.find(s.squad) if s.squad != null else -1000 - s.id)
			at = s.pos
			dest = s.order["point"]
		if dest == null:
			continue
		if not glines.has(key):
			glines[key] = {"c": Vector3.ZERO, "d": Vector3.ZERO, "n": 0, "sel": false}
		var g = glines[key]
		g["c"] += at
		g["d"] += dest
		g["n"] += 1
		if s in selection:
			g["sel"] = true
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var any_line = false
	var used = 0
	var tnow = Time.get_ticks_msec() * 0.001
	for key in glines:
		var g = glines[key]
		# only the units you have selected show where they're headed
		if not g["sel"]:
			continue
		var c: Vector3 = g["c"] / g["n"]
		var dest: Vector3 = g["d"] / g["n"]
		if G.dist2d(c, dest) < 4.0:
			continue
		var col = Color(1.0, 0.86, 0.3, 0.9)
		var a2 = c + Vector3(0, 0.6, 0)
		var b2 = Vector3(dest.x, G.world.ground_y(dest.x, dest.z) + 0.25, dest.z)
		# a dashed line whose dashes run toward the destination
		var L = a2.distance_to(b2)
		var dir = (b2 - a2) / maxf(L, 0.01)
		var ph = fmod(tnow * 4.0, 3.0)
		var x = ph - 3.0
		while x < L - 2.4:
			var x0 = maxf(x, 0.0)
			var x1 = minf(x + 1.6, L - 2.4)
			if x1 > x0:
				var fade = clampf(x0 / 3.0, 0.25, 1.0)
				var cc = Color(col.r, col.g, col.b, col.a * fade)
				im.surface_set_color(cc); im.surface_add_vertex(a2 + dir * x0)
				im.surface_set_color(cc); im.surface_add_vertex(a2 + dir * x1)
			x += 3.0
		any_line = true
		_dest_marker(used, b2, tnow)
		used += 1
	for i in range(used, dest_marks.size()):
		dest_marks[i].visible = false
	if not any_line:
		im.surface_set_color(Color(0, 0, 0, 0)); im.surface_add_vertex(Vector3.ZERO)
		im.surface_set_color(Color(0, 0, 0, 0)); im.surface_add_vertex(Vector3.ZERO)
	im.surface_end()

# where a selected group is going: a glowing ring on the ground with four arrowheads pointing in, gently pulsing
var dest_marks: Array = []

func _dest_marker(i: int, p: Vector3, t: float) -> void:
	while dest_marks.size() <= i:
		var n = Node3D.new()
		var m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(1.0, 0.86, 0.3, 0.85)
		m.no_depth_test = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		var ring = MeshInstance3D.new()
		var tm = TorusMesh.new()
		tm.inner_radius = 1.25
		tm.outer_radius = 1.45
		tm.rings = 32
		tm.ring_segments = 6
		ring.mesh = tm
		ring.scale = Vector3(1, 0.15, 1)
		ring.material_override = m
		n.add_child(ring)
		var dot = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		cm.top_radius = 0.22
		cm.bottom_radius = 0.22
		cm.height = 0.04
		dot.mesh = cm
		dot.material_override = m
		n.add_child(dot)
		for k in range(4):
			var arw = MeshInstance3D.new()
			var pm = PrismMesh.new()
			pm.size = Vector3(0.55, 0.5, 0.04)
			arw.mesh = pm
			arw.material_override = m
			var a = k * PI / 2.0
			arw.position = Vector3(sin(a), 0, cos(a)) * 2.0
			# lying flat, pointing at the centre
			arw.rotation = Vector3(-PI / 2.0, a + PI, 0)
			arw.set_meta("a", a)
			n.add_child(arw)
		add_child(n)
		dest_marks.append(n)
	var mk: Node3D = dest_marks[i]
	mk.visible = true
	mk.global_position = p
	var pulse = 0.5 + 0.5 * sin(t * 4.0)
	for ch in mk.get_children():
		if ch.has_meta("a"):
			var a: float = ch.get_meta("a")
			ch.position = Vector3(sin(a), 0, cos(a)) * (1.9 + 0.35 * pulse)
	mk.rotation.y = t * 0.6

# control groups: Ctrl+number saves the selection, the number brings it back (twice to look at it)
var groups = {}

func select_group(i: int) -> void:
	var g: Array = groups[i].filter(func(x): return is_instance_valid(x) and x.state != "dead")
	groups[i] = g
	if g.is_empty():
		groups.erase(i)
		G.ui.message("Group %d is gone" % (i + 1))
		return
	selection = g.duplicate()
	sel_vehicle = null
	var c = Vector3.ZERO
	for m in g:
		c += m.pos
	c /= g.size()
	if last_squad_key == 100 + i:
		rts_focus = c
	last_squad_key = 100 + i
	G.ui.message("Group %d (%d) · press %d again to look at them" % [i + 1, g.size(), i + 1])

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
	_cut_tick(dt)
	_update_rings()
	_rts_overlay()
	_ghost_tick()
	_order_preview_tick()
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
				var turning_bp = G.ui.tool.begins_with("b:")
				if Input.is_key_pressed(KEY_Q) and not turning_bp: rts_yaw += 1.4 * dt
				if Input.is_key_pressed(KEY_E) and not turning_bp: rts_yaw -= 1.4 * dt
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
			var bp = G.ui.tool.begins_with("b:")
			if (Input.is_key_pressed(KEY_E) and not bp) or Input.is_key_pressed(KEY_SPACE): free_pos.y += sp
			if (Input.is_key_pressed(KEY_Q) and not bp) or Input.is_key_pressed(KEY_C) or Input.is_key_pressed(KEY_CTRL): free_pos.y -= sp
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

# ---------------------------------------------------------------- seeing into buildings
# looking down on the town, the roof and upper floors lift off the house under the cursor and any house
# your selected men are in, cut just above the floor they're standing on
var cut_t = 0.0

func _cut_tick(dt: float) -> void:
	cut_t -= dt
	if cut_t > 0.0:
		return
	cut_t = 0.12
	var w = G.world
	if w == null or not w.has_method("set_cut"):
		return
	var want = {}
	if G.started and (G.player == null or force_free) and not G.editor.active:
		var cp = cam.global_position
		var mp = get_viewport().get_mouse_position()
		var o = cam.project_ray_origin(mp)
		var hit = G.ray(o, o + cam.project_ray_normal(mp) * 400.0, G.L_WORLD)
		if not hit.is_empty():
			var bi = w.building_index(hit.position, 0.4)
			if bi >= 0 and _looks_down_on(bi, cp):
				want[bi] = 2.3
		for c in selection:
			if is_instance_valid(c) and c is Soldier and c.state == "alive" and c.vehicle == null:
				var sb = w.building_index(c.pos, -0.1)
				if sb >= 0 and _looks_down_on(sb, cp):
					want[sb] = maxf(want.get(sb, 0.0), maxf(2.3, c.pos.y - w.buildings[sb]["gy"] + 2.3))
	w.set_cut(want)

func _looks_down_on(bi: int, cp: Vector3) -> bool:
	var b = G.world.buildings[bi]
	return cp.y > b["gy"] + b["h"] + 1.5

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
		elif G.player == null and r_drag and rts and fdrag_a != null:
			if ev.position.distance_to(r_press) > 6.0:
				r_moved = true
				var gb = _ground_at(ev.position)
				if gb != null and G.dist2d(gb, fdrag_a) > 2.5:
					fdrag = true
					fdrag_b = gb
		elif G.player == null and (r_drag or m_drag) and rts:
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
			# placing a structure: hold the right button and move the mouse to turn it; a plain right-click puts it away
			if ev.pressed:
				rot_drag = true
				rot_acc = 0.0
				rot_moved = false
			else:
				if rot_drag and not rot_moved:
					G.ui.tool = "sel"
					G.ui._render_tools()
					G.ui.message("Blueprint put away")
				rot_drag = false
		elif ev.button_index == MOUSE_BUTTON_RIGHT:
			if G.player != null:
				rmb_down = ev.pressed
			else:
				r_drag = ev.pressed
				if ev.pressed:
					r_press = ev.position
					r_moved = false
					fdrag = false
					fdrag_b = null
					# with men selected, a right-drag in the commander view draws the line they form up on
					fdrag_a = _ground_at(ev.position) if rts and not _foot_men().is_empty() and not ev.alt_pressed else null
				elif fdrag and fdrag_a != null and fdrag_b != null:
					_order_line(fdrag_a, fdrag_b, ev.shift_pressed)
					fdrag = false
					fdrag_a = null
				elif not r_moved and not selection.is_empty():
					fdrag = false
					fdrag_a = null
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
		elif ev.button_index == MOUSE_BUTTON_MIDDLE and G.player == null:
			# middle-drag turns the commander camera (right-drag draws lines when men are selected)
			m_drag = ev.pressed
			if ev.pressed:
				r_press = ev.position
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
	# a blueprint in hand: R, E or Q turn it (instead of turning the camera)
	if (k == KEY_R or k == KEY_E or k == KEY_Q) and G.player == null and G.ui.tool.begins_with("b:"):
		rotate_place(-1 if k == KEY_Q else 1)
		return
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
		elif k == KEY_F and s.state == "alive" and _knife_target(s) != null:
			Combat.knife(s, _knife_target(s))
		elif k == KEY_F and s.state == "alive" and Faction.player_tunnel(s):
			pass
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
		elif k == KEY_0 and s.state == "alive":
			s.primary = null
			s.set_weapon("pfaust")
			G.ui.message("Panzerfaust: one shot, short range, then it's thrown away")
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
			var gi = k - KEY_1
			if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META):
				# Ctrl+number: remember this selection as a group
				groups[gi] = selection.duplicate()
				G.ui.message("Group %d: %d soldier%s" % [gi + 1, groups[gi].size(), "" if groups[gi].size() == 1 else "s"])
			elif groups.has(gi):
				select_group(gi)
			else:
				select_squad(gi)
		elif k >= KEY_1 and k <= KEY_9:
			G.ui.pick_tool(k - KEY_1)
		elif k == KEY_F:
			var cp = cos(free_pitch)
			var d = Vector3(sin(free_yaw) * cp, sin(free_pitch), cos(free_yaw) * cp)
			possess(pick_soldier(cam.global_position, d))

# take apart whatever is at a point: a whole construction, an emplacement, or one piece of a building
# an enemy right in front of you: F is a knife
func _knife_target(s):
	var f = Vector3(sin(s.aim_yaw), 0, cos(s.aim_yaw))
	for o in G.soldiers:
		if o.team != s.team and o.state == "alive" and G.dist2d(o.pos, s.pos) < 1.8 and f.dot(G.flat(o.pos - s.pos).normalized()) > 0.5:
			return o
	return null

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
		var mine = G.player == null or st["team"] == G.player.team
		if not mine and st["kind"] != "wire":
			G.ui.message("You can't take apart the enemy's %s by hand (but you can cut their wire)" % nm.to_lower())
			return true
		Build.dismantle(st)
		G.ui.message("Cut through the wire" if not mine else "Dismantled the %s" % nm)
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
	if not Rules.free_tools() and G.mode != "commander" and not (tool in ["sel", "ctl", "mv"] or tool.begins_with("b:") or tool.begins_with("sup:") or tool.begins_with("h:") or tool in ["up", "camo", "rep", "dis"]):
		return
	if G.mode == "commander" and not (tool == "sel" or tool.begins_with("b:") or tool.begins_with("sup:") or tool.begins_with("r:") or tool in ["up", "camo", "rep", "dis"]):
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
		AI.batch_begin()
		for off in [[0, 0], [-1.6, -1.6], [1.6, -1.6], [-3.2, -3.2], [3.2, -3.2]]:
			G.main.spawn_soldier(team, p.x + off[1] * fw, p.z + off[0], "")
		AI.batch_end()
	elif tool == "boom":
		Combat.explode(p + Vector3(0, 0.1, 0), null, 1.1)
	elif tool == "mortar":
		Combat.mortar_strike(p, 7)
		G.ui.message("Mortar barrage incoming")
	elif tool == "smoke":
		Combat.smoke_at(p, 26.0)
	elif tool == "flare":
		Combat.flare(p + Vector3(0, 0, 0), p)
	elif tool.begins_with("r:"):
		# the recruits' truck drives them to the spot you clicked
		G.ui._recruit(tool.substr(2), p)
		G.ui.tool = "sel"
		G.ui._render_tools()
	elif tool.begins_with("h:"):
		G.ui.message(Modes.shop(tool.substr(2), p))
		G.ui._dock_points()
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
		var gh = ground_hit(o, d)
		if gh != null:
			p = Vector3(snappedf(gh.x, 0.5), gh.y, snappedf(gh.z, 0.5))
		if G.mode == "commander":
			team = 0
		if not (kind in Rules.build(team)):
			G.ui.message("Nobody builds a %s in this mode" % Build.KINDS[kind]["name"].to_lower())
			return
		var to = place_front(p, team)
		if not Build.clear_at(p, kind):
			G.ui.message("No room for a %s there" % Build.KINDS[kind]["name"])
			return
		if Build.too_near_hq(kind, team, p):
			G.ui.message("Supply dumps go at least %d m out from HQ: the trucks have to earn it" % int(Build.SUPPLY_MIN))
			return
		var c = Build.cost(kind)
		if c > 0:
			if Support.points[team] < c:
				G.ui.message("Not enough supply points: a %s costs %d, you have %d" % [Build.KINDS[kind]["name"], c, Support.points[team]])
				return
			Support.points[team] -= c
		Build.place(kind, team, p, to, false, true)
		G.audio.radio_click()
		# Shift held: keep the blueprint in hand to put down another of the same; otherwise put it away
		if Input.is_key_pressed(KEY_SHIFT):
			G.ui.message("%s site marked out%s · keep Shift held to place more" % [Build.KINDS[kind]["name"], (" (-%d points)" % c) if c > 0 else ""])
		else:
			G.ui.message("%s site marked out for %s%s · engineers will build it (hold Shift to place several)" % [Build.KINDS[kind]["name"], G.TEAM_NAMES[team], (" (-%d points)" % c) if c > 0 else ""])
			G.ui.tool = "sel" if G.mode == "commander" else "ctl"
			G.ui._render_tools()
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
	var tb = G.world.table_near(s.pos, 1.7)
	if tb != null:
		var face = Vector3(sin(cam_yaw), 0, cos(cam_yaw))
		G.world.flip_table(tb, face)
		s.kick(G.flat(tb["p"] - s.pos).normalized())
		G.ui.message("Table flipped: cover facing the way you're looking")
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
	# a fallen radioman of ours: take the set off his back
	if best.radio_pack != null and best.team == s.team and s.radio_pack == null:
		best.give_radio(false)
		s.give_radio(true)
		G.ui.message("Took the radio set: you can call fire missions (class action)")
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
func _sel_team_ok(c) -> bool:
	if G.mode == "commander" or (G.mode != "sandbox" and G.player == null):
		return c.team == 0
	return true

# the vehicle under the cursor (its hull, or near where the click lands)
func pick_vehicle(o: Vector3, d: Vector3):
	var hit = G.ray(o, o + d * 600.0, G.L_WORLD | G.L_VEH)
	if not hit.is_empty() and hit.collider.has_meta("vehicle"):
		var hv = hit.collider.get_meta("vehicle")
		if is_instance_valid(hv) and not hv.dead:
			return hv
	if not hit.is_empty():
		var best = null
		var bd = 1e9
		for v in G.vehicles:
			if v.dead:
				continue
			var dd = G.dist2d(v.pos, hit.position)
			if dd < (2.2 if v.spec.get("static", false) else v.spec["len"] * 0.5 + 0.6) and dd < bd:
				bd = dd
				best = v
		return best
	return null

func _select_vehicle(v, add: bool) -> void:
	if not add:
		selection = []
	for x in v.seats:
		if x != null and is_instance_valid(x) and x.state == "riding" and not x.is_player and not (x in selection):
			selection.append(x)
	sel_vehicle = v
	G.ui.show_vehicle(v)

var sel_vehicle = null

func _finish_select(add: bool) -> void:
	if not add:
		selection = []
		sel_vehicle = null
	var a: Vector2 = drag_from
	var b: Vector2 = drag_to
	if a.distance_to(b) < 6.0:
		var o = cam.project_ray_origin(b)
		var d = cam.project_ray_normal(b)
		var hit = G.ray(o, o + d * 600.0, G.L_WORLD)
		var s = null
		var direct = G.ray(o, o + d * 400.0, G.L_WORLD | G.L_BODY | G.L_VEH)
		if not direct.is_empty() and direct.collider.has_meta("soldier"):
			s = direct.collider.get_meta("soldier")
		# a vehicle: click its hull (or a man sitting in it) to take the whole crew and its troops
		var v = null
		if s != null and s.state == "riding" and s.vehicle != null:
			v = s.vehicle
		elif s == null:
			v = pick_vehicle(o, d)
		if v != null and v.team == (0 if G.mode == "commander" or G.mode != "sandbox" else v.team) and not v.spec.get("static", false):
			_select_vehicle(v, add)
			if selection.is_empty():
				G.ui.message("The %s is empty" % v.spec["name"].to_lower())
			else:
				G.ui.message("%s selected (%d aboard) · right-click to drive there" % [v.spec["name"], selection.size()])
			return
		if s == null:
			s = pick_soldier(o, d)
			if s != null and s.state == "riding":
				s = null
		if s == null and rts:
			# from up high, a click near a soldier counts
			if not hit.is_empty():
				var bd = 4.0
				for c in G.soldiers:
					if c.state != "dead" and c.state != "riding" and _sel_team_ok(c):
						var dd = G.dist2d(c.pos, hit.position)
						if dd < bd:
							bd = dd
							s = c
		if s != null and s.state != "dead" and _sel_team_ok(s):
			G.ui.hide_info()
			var dbl = s == click_s and Time.get_ticks_msec() - click_ms < 400
			click_s = s
			click_ms = Time.get_ticks_msec()
			if dbl and s.squad != null:
				# double-click: the men of his squad who are on foot nearby
				for m in s.squad["members"]:
					if is_instance_valid(m) and m.state != "dead" and m.state != "riding" and G.dist2d(m.pos, s.pos) < 40.0 and not (m in selection):
						selection.append(m)
			elif s in selection:
				selection.erase(s)
			else:
				selection.append(s)
		elif s == null and not hit.is_empty():
			# a structure: say what it is and what can be done with it
			var st = Build.site_at(hit.position, 0.3)
			if st != null:
				G.ui.show_site(st)
				return
			G.ui.hide_info()
	else:
		G.ui.hide_info()
		var r = Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (a - b).abs())
		for s in G.soldiers:
			if s.state == "dead" or s.is_player or cam.is_position_behind(s.chest()) or not _sel_team_ok(s):
				continue
			if r.has_point(cam.unproject_position(s.chest())) and not (s in selection):
				selection.append(s)
	if selection.size() == 1 and is_instance_valid(selection[0]) and selection[0].state != "riding":
		G.ui.show_unit(selection[0])      # one man: his card (class, health, ammo, what he's doing)
	elif not selection.is_empty():
		G.ui.hide_info()
	if not selection.is_empty():
		G.ui.message("%d selected. Right-click the ground to send them there%s" % [selection.size(), " · double-click a man for his whole squad" if selection.size() == 1 else ""])

var click_s = null
var click_ms = 0

func _order_move(screen: Vector2) -> void:
	var o = cam.project_ray_origin(screen)
	var d = cam.project_ray_normal(screen)
	var hit = G.ray(o, o + d * 500.0, G.L_WORLD)
	if hit.is_empty():
		return
	var p: Vector3 = hit.position
	# right-click on one of our vehicles or guns: climb in / man it
	var tv = null
	var vh = G.ray(o, o + d * 600.0, G.L_WORLD | G.L_VEH)
	if not vh.is_empty() and vh.collider.has_meta("vehicle"):
		tv = vh.collider.get_meta("vehicle")
	else:
		for gv in G.vehicles:
			if gv.spec.get("static", false) and not gv.dead and G.dist2d(gv.pos, p) < 1.8:
				tv = gv
	if tv != null and is_instance_valid(tv) and tv.team == 0 and not tv.dead and not tv.spec.get("air", false) and _order_board(tv):
		return
	# right-click on one of our unfinished or damaged structures: go and build / fix it
	var st = Build.site_at(p, 1.5)
	if st != null and st["team"] == 0 and not st["dead"] and (not st["done"] or Build.needs_repair(st)) and _order_build(st, Input.is_key_pressed(KEY_SHIFT)):
		return
	var n = 0
	var vs = []
	for s in selection:
		if not is_instance_valid(s) or s.state == "dead":
			continue
		if s.state == "riding" and s.vehicle != null and is_instance_valid(s.vehicle):
			# riders: their vehicle drives there and they stay aboard until told to get out
			var v = s.vehicle
			if not (v in vs):
				vs.append(v)
			s.order = {"mode": "move", "point": p}
			continue
		# spread them out a little around the point, and get going at once
		var off = Vector3((n % 4) - 1.5, 0, int(n / 4) - 1.0) * 2.0
		n += 1
		if Input.is_key_pressed(KEY_SHIFT) and s.order != null and s.order.get("mode", "") == "move" and s.order.get("point") != null and not s.order.has("arrived"):
			# Shift: one more stop on the way, after the ones already given
			if not s.order.has("queue"):
				s.order["queue"] = []
			if s.order["queue"].size() < 8:
				s.order["queue"].append(p + off)
			G.ui.message("Waypoint added")
			G.audio.order_tick(true)
			continue
		s.order = {"mode": "move", "point": p + off}
		_obey(s, p + off)
	var k = 0
	# several vehicles going a fair way: they drive in a column behind the biggest one
	vs.sort_custom(func(a, b): return a.rank() > b.rank())
	for v in vs:
		# several vehicles: park side by side rather than on the same spot
		var off2 = Vector3((k % 3) - 1.0, 0, int(k / 3)) * 9.0 if vs.size() > 1 else Vector3.ZERO
		v.command(p + off2)
		if k > 0 and G.dist2d(vs[0].pos, p) > 40.0 and G.dist2d(v.pos, vs[0].pos) < 45.0:
			v.convoy = {"lead": vs[0], "k": k}
		k += 1
	G.fx.order_marker(p)
	G.audio.radio_click()
	var parts = []
	if n > 0:
		parts.append("%d soldier%s" % [n, "" if n == 1 else "s"])
	if not vs.is_empty():
		parts.append("%d vehicle%s" % [vs.size(), "" if vs.size() == 1 else "s"])
	G.ui.message("Moving " + " and ".join(parts))

# drop whatever they were doing and start moving now, instead of at the next decision
func _obey(s, to: Vector3) -> void:
	if s.state != "alive" or s.is_player:
		return
	if s.cover != null:
		AI.release_cover(s)
	if s.task in ["medic", "stretcher", "construct", "repair", "board", "fetch", "flee", "rout", "flank_move", "clear", "support"]:
		if s.task == "stretcher":
			return
		if s.dragging != null:
			s.dragging.dragger = null
			s.dragging = null
		s.task = null
	s.route = null
	s.flee = null
	s.build_site = null if s.task != "construct" else s.build_site
	s.prone_t = false
	if to.y - G.world.ground_y(to.x, to.z) > 1.5:
		AI.route_to(s, to, 5.0)          # upstairs: by the stairs or ladder
	else:
		AI.route_to(s, G.main._free_spot(to) if G.world.inside_any(to.x, to.z, 0.4) else to, 5.0)
	s.path_prio = true
	s.decide_t = 1.2
	s.think = 0.0
	s.set_meta("obey_t", G.sim_time)

# selected men climb into a vehicle or man a gun, as many as there are free seats
func _order_board(v) -> bool:
	var free = 0
	for i in range(v.seats.size()):
		if v.seats[i] == null:
			free += 1
	if free == 0:
		G.ui.message("%s is full" % v.spec["name"])
		return true
	var n = 0
	for s in selection:
		if n >= free:
			break
		if not is_instance_valid(s) or s.state != "alive" or s.vehicle != null or s.is_player:
			continue
		_obey(s, v.pos)
		s.task = "board"
		s.board_target = v
		s.no_board_t = 0.0
		s.order = {"mode": "hold", "point": v.pos}
		n += 1
	if n == 0:
		return false
	G.fx.order_marker(v.pos)
	G.audio.radio_click()
	G.ui.message("%d soldier%s heading for the %s" % [n, "" if n == 1 else "s", v.spec["name"].to_lower()])
	return true

# selected men go and work on a structure (anyone can build; engineers are quicker).
# With Shift held the structure goes on the end of their list, and they move on to it when the one before is finished.
func _order_build(st, queue: bool = false) -> bool:
	var n = 0
	for s in selection:
		if not is_instance_valid(s) or s.state != "alive" or s.vehicle != null or s.is_player:
			continue
		var q: Array = s.get_meta("build_queue", [])
		if queue and (s.task == "construct" or not q.is_empty()):
			if not (st in q) and s.build_site != st:
				q.append(st)
			s.set_meta("build_queue", q)
			n += 1
			continue
		s.set_meta("build_queue", [])
		_obey(s, st["p"])
		s.order = {"mode": "hold", "point": Build.work_spot(st, s)}
		ClassAI._start_construct(s, st)
		s.set_meta("ordered_build", st)
		n += 1
	if n == 0:
		return false
	G.fx.order_marker(st["p"])
	G.audio.radio_click()
	if queue:
		G.ui.message("Queued: the %s, next on the list for %d soldier%s" % [st["name"].to_lower(), n, "" if n == 1 else "s"])
	else:
		G.ui.message("%d soldier%s sent to %s the %s (Shift+right-click to queue more)" % [n, "" if n == 1 else "s", "build" if not st["done"] else "repair", st["name"].to_lower()])
	return true

# the vehicles the selected men are riding in
func sel_vehicles() -> Array:
	var vs = []
	for s in selection:
		if is_instance_valid(s) and s.state == "riding" and s.vehicle != null and is_instance_valid(s.vehicle) and not s.vehicle.dead and not (s.vehicle in vs):
			vs.append(s.vehicle)
	return vs

func order_selected(mode: String) -> void:
	if mode == "dismount":
		dismount_selected(true)
		return
	if mode in ["vstop", "vback", "vsmoke", "vfree"]:
		for v in sel_vehicles():
			if v.spec.get("static", false):
				continue
			match mode:
				"vstop":
					v.command(v.pos)
				"vback":
					v.command(G.main._free_spot(G.world.rally_point(v.team)))
				"vfree":
					v.cmd = null
				"vsmoke":
					if G.sim_time > v.smoke_cd:
						VehExt.pop_smoke(v, _sel_threat(v.pos))
		G.audio.radio_click()
		G.ui.message({"vstop": "Vehicles stop where they are", "vback": "Vehicles heading back to the rally point", "vfree": "Vehicles act on their own", "vsmoke": "Smoke!"}[mode])
		return
	if mode in ["fallback", "smoke", "cover"]:
		_special_order(mode)
		return
	for s in selection:
		if is_instance_valid(s) and s.state != "dead":
			s.order = null if mode == "free" else {"mode": mode, "point": s.pos}
			s.decide_t = 0.0
			if s.state == "riding" and s.vehicle != null and is_instance_valid(s.vehicle) and s.vehicle.driver() == s:
				s.vehicle.cmd = null if mode == "free" else s.vehicle.pos
	G.audio.radio_click()
	G.ui.message({"free": "Selected soldiers act on their own", "hold": "Selected soldiers hold their ground", "charge": "Selected soldiers charge!"}[mode])

# where the trouble is for the selected men: the nearest enemy anyone of them has seen, or straight ahead
func _sel_threat(c: Vector3) -> Vector3:
	var best = null
	var bd = 1e9
	for s in selection:
		if is_instance_valid(s) and s.has_seen and G.sim_time - s.seen_t < 20.0:
			var d = G.dist2d(s.threat, c)
			if d < bd:
				bd = d
				best = s.threat
	if best != null:
		return best
	return G.world.capture if G.dist2d(G.world.capture, c) > 10.0 else c + Vector3(0, 0, 30)

func _special_order(mode: String) -> void:
	var men = selection.filter(func(x): return is_instance_valid(x) and x.state == "alive" and x.vehicle == null and not x.is_player)
	if men.is_empty():
		return
	var c = Vector3.ZERO
	for m in men:
		c += m.pos
	c /= men.size()
	var threat = _sel_threat(c)
	var away = G.flat(c - threat).normalized()
	match mode:
		"smoke":
			# a wall of smoke between them and the enemy, from whoever has a smoke grenade
			var n = 0
			for m in men:
				if m.smokes > 0 and n < 3:
					var tp = m.pos - away * 12.0 + Vector3(-away.z, 0, away.x) * (n - 1) * 6.0
					Combat.throw_grenade(m, tp, "smoke")
					n += 1
			G.ui.message("Smoke out!" if n > 0 else "Nobody selected has smoke left")
		"fallback":
			# back the way they came, under smoke if they have it
			var home: Vector3 = G.world.rally_point(0)
			var dir = G.flat(home - c)
			dir = dir.normalized() if dir.length() > 5.0 else away
			var dest = c + dir * 30.0
			var k = 0
			var smoked = false
			for m in men:
				if not smoked and m.smokes > 0:
					Combat.throw_grenade(m, m.pos - away * 10.0, "smoke")
					smoked = true
				var off = Vector3((k % 4) - 1.5, 0, int(k / 4) - 1.0) * 2.2
				m.order = {"mode": "move", "point": dest + off}
				_obey(m, dest + off)
				k += 1
			G.fx.order_marker(dest)
			G.ui.message("Falling back%s" % (" under smoke" if smoked else ""))
		"cover":
			# everyone into the nearest cover facing the enemy, and stay there
			var got = 0
			for m in men:
				var cp = AI.find_cover(m, threat, "defend")
				if cp != null:
					AI.release_cover(m)
					m.order = {"mode": "hold", "point": cp.pos}
					_obey(m, cp.pos)
					got += 1
				else:
					m.order = {"mode": "hold", "point": m.pos}
					m.prone_t = true
			G.ui.message("Taking cover (%d found some, the rest go flat)" % got if got < men.size() else "Taking cover")
	G.audio.radio_click()

# get out of whatever they're riding in: troops only, or (troops=false) the crew as well
func dismount_selected(troops: bool) -> void:
	var vs = []
	for s in selection:
		if is_instance_valid(s) and s.state == "riding" and s.vehicle != null and is_instance_valid(s.vehicle) and not (s.vehicle in vs):
			vs.append(s.vehicle)
	if sel_vehicle != null and is_instance_valid(sel_vehicle) and not (sel_vehicle in vs):
		vs.append(sel_vehicle)
	var n = 0
	var got = []
	for v in vs:
		var any_pass = false
		for i in range(v.seats.size()):
			if v.seats[i] != null and v.spec["seats"][i]["role"] == "pass":
				any_pass = true
		for i in range(v.seats.size()):
			var r = v.seats[i]
			if r == null or not is_instance_valid(r) or r.is_player:
				continue
			var pas = v.spec["seats"][i]["role"] == "pass"
			if (troops and any_pass and not pas) or (troops and not any_pass and not (r in selection)):
				continue
			r.dismount(false)
			r.no_board_t = G.sim_time + 45.0
			# off the truck and into a ring around it, then they wait for orders
			r.order = {"mode": "hold", "point": r.vault["b"] if r.vault != null else r.pos}
			r.decide_t = 0.0
			got.append(r)
			n += 1
		if n > 0 and v.driver() != null:
			G.fx.callout(v.driver(), G.pick(["Everybody out!", "Go, go, go!", "Out you get!"]))
		if v.mission != null and v.mission.get("type", "") in ["deliver", "supply"] and v.mission.get("stage", 0) == 0:
			v.mission["drop"] = v.pos
	if n == 0:
		G.ui.message("Nobody to get out (select a vehicle with troops aboard)")
		return
	selection = got
	G.ui.message("%d soldier%s dismounting" % [n, "" if n == 1 else "s"])

func dismantle_site(st: Dictionary) -> void:
	Build.dismantle(st)

func clear_selection() -> void:
	selection = []
	sel_vehicle = null
	G.ui.hide_info()

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
	# men on foot get a ring each; a vehicle gets one ring round the whole hull
	var marks = []
	var seen = []
	for s in selection:
		if s.state == "riding" and s.vehicle != null and is_instance_valid(s.vehicle):
			if not (s.vehicle in seen):
				seen.append(s.vehicle)
				marks.append([s.vehicle.pos, s.vehicle.spec["len"] * 0.55 + 0.4, s.vehicle.spec["name"].to_upper(), Color(0.85, 0.9, 1.0)])
		else:
			var p: Vector3 = s.pos if s.state == "alive" else s.parts[0].global_position
			var ct = CLASS_TAG.get(s.cls, ["", Color.WHITE])
			marks.append([p, 1.0, ct[0], ct[1]])
	_class_tags(marks)
	# say what's in the selection when it changes
	var sig = str(selection.size()) + str(seen.size())
	if sig != sel_sig:
		sel_sig = sig
		if not selection.is_empty():
			G.ui.message("Selected: " + _sel_summary())
	for i in range(sel_rings.size()):
		var r = sel_rings[i]
		if i < marks.size():
			r.visible = true
			var p: Vector3 = marks[i][0]
			r.global_position = Vector3(p.x, G.world.ground_y(p.x, p.z) + 0.08 if marks[i][1] > 1.0 else p.y + 0.06, p.z)
			var sc = marks[i][1] * (1.0 + (rts_dist / 30.0 if rts and marks[i][1] <= 1.0 else 0.0))
			r.scale = Vector3(sc, 0.3, sc)
		else:
			r.visible = false

# what each kind of soldier is, shown over him while he's selected
const CLASS_TAG = {"rifleman": ["RIFLE", Color(0.9, 0.92, 0.88)], "mg": ["MG", Color(1.0, 0.75, 0.35)], "medic": ["MEDIC", Color(1.0, 0.45, 0.45)],
	"at": ["AT", Color(1.0, 0.55, 0.2)], "engineer": ["ENGINEER", Color(0.55, 0.85, 1.0)], "assault": ["ASSAULT", Color(0.95, 0.85, 0.4)],
	"radio": ["RADIO", Color(0.6, 1.0, 0.6)], "sniper": ["SNIPER", Color(0.8, 0.7, 1.0)], "spotter": ["SPOTTER", Color(0.8, 0.7, 1.0)],
	"officer": ["OFFICER", Color(1.0, 0.95, 0.6)]}
const PLURAL = {"rifleman": ["rifleman", "riflemen"], "mg": ["machine gunner", "machine gunners"], "medic": ["medic", "medics"],
	"at": ["anti-tank soldier", "anti-tank soldiers"], "engineer": ["engineer", "engineers"], "assault": ["assault trooper", "assault troopers"],
	"radio": ["radio operator", "radio operators"], "sniper": ["sniper", "snipers"], "spotter": ["spotter", "spotters"], "officer": ["officer", "officers"]}
var sel_tags: Array = []
var sel_sig = ""

func _class_tags(marks: Array) -> void:
	var show = rts and G.player == null
	while sel_tags.size() < marks.size():
		var l = Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = true
		l.pixel_size = 0.0011
		l.font_size = 22
		l.outline_size = 7
		l.outline_modulate = Color(0, 0, 0, 0.85)
		add_child(l)
		sel_tags.append(l)
	for i in range(sel_tags.size()):
		var l: Label3D = sel_tags[i]
		if show and i < marks.size() and marks[i][2] != "":
			l.visible = true
			l.text = marks[i][2]
			l.modulate = marks[i][3]
			var p: Vector3 = marks[i][0]
			l.global_position = p + Vector3(0, 2.4 if marks[i][1] <= 1.0 else 3.6, 0)
		else:
			l.visible = false

# a short version for the orders strip: "5 men", "3 men + jeep"
func _sel_short() -> String:
	var men = 0
	var veh = []
	for s in selection:
		if not is_instance_valid(s) or s.state == "dead":
			continue
		if s.state == "riding" and s.vehicle != null and is_instance_valid(s.vehicle):
			if not (s.vehicle in veh):
				veh.append(s.vehicle)
			continue
		men += 1
	var parts = []
	if men > 0:
		parts.append("%d %s" % [men, "man" if men == 1 else "men"])
	if veh.size() == 1:
		parts.append(veh[0].spec["name"].to_lower())
	elif veh.size() > 1:
		parts.append("%d vehicles" % veh.size())
	return " + ".join(parts)

func _sel_summary() -> String:
	var n = {}
	var veh = []
	for s in selection:
		if s.state == "riding" and s.vehicle != null and is_instance_valid(s.vehicle):
			if not (s.vehicle in veh):
				veh.append(s.vehicle)
			continue
		n[s.cls] = n.get(s.cls, 0) + 1
	var parts = []
	for k in n:
		var nm = PLURAL.get(k, [k, k + "s"])
		parts.append("%d %s" % [n[k], nm[0] if n[k] == 1 else nm[1]])
	for v in veh:
		parts.append(v.spec["name"].to_lower())
	return ", ".join(parts)

# B: whatever your class is good at
func _class_action(s) -> void:
	match ("radio" if s.radio_pack != null else s.cls):
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
			if s.radio_pack == null:
				G.ui.message("You've no radio set: pick one up off a fallen radioman")
				return
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

# ---------------------------------------------------------------- order previews, dragged lines, waypoints
# Hovering with men selected shows faint figures where each would end up (green and crouched where
# there's cover to take). Right-drag draws the line they form up on, facing away from where they are now.
# Shift + right-click adds a waypoint to the end of the route instead of replacing it.
var fdrag = false
var fdrag_a = null
var fdrag_b = null
var m_drag = false
var pghosts: Array = []
var pg_mats: Array = []
var wp_flags: Array = []

func _ground_at(screen: Vector2):
	var o = cam.project_ray_origin(screen)
	var d = cam.project_ray_normal(screen)
	var hit = G.ray(o, o + d * 500.0, G.L_WORLD)
	if hit.is_empty():
		return null
	return hit.position

func _foot_men() -> Array:
	return selection.filter(func(x): return is_instance_valid(x) and x.state == "alive" and x.vehicle == null and not x.is_player)

# where each man goes for a plain right-click on p (same spread as _order_move)
func _click_spots(p: Vector3, men: Array) -> Array:
	var out = []
	var n = 0
	for s in men:
		var off = Vector3((n % 4) - 1.5, 0, int(n / 4) - 1.0) * 2.0
		out.append([s, p + off])
		n += 1
	return out

# men along a dragged line, in the order they stand now so nobody crosses over; a second rank
# behind if the line's too short for them all
func _line_spots(a: Vector3, b: Vector3, men: Array) -> Dictionary:
	var L = G.flat(b - a)
	var ln = maxf(L.length(), 0.01)
	var along = L / ln
	var c = (a + b) * 0.5
	var now = Vector3.ZERO
	for m in men:
		now += m.pos
	now /= maxf(1.0, men.size())
	var nrm = Vector3(-along.z, 0, along.x)
	if nrm.dot(G.flat(c - now)) < 0.0:
		nrm = -nrm
	var sorted = men.duplicate()
	sorted.sort_custom(func(x, y): return G.flat(x.pos - a).dot(along) < G.flat(y.pos - a).dot(along))
	var n = sorted.size()
	var per_row = n if n <= 1 or ln / (n - 1) >= 1.2 else maxi(1, int(ln / 1.2) + 1)
	var out = []
	for i in range(n):
		var row = i / per_row
		var col = i % per_row
		var cnt = mini(per_row, n - row * per_row)
		var t = 0.5 if cnt == 1 else float(col) / (cnt - 1)
		var q = a + along * ln * t - nrm * row * 1.8
		out.append([sorted[i], Vector3(q.x, G.world.ground_y(q.x, q.z), q.z)])
	return {"spots": out, "face": atan2(nrm.x, nrm.z), "c": c}

func _order_line(a: Vector3, b: Vector3, queue: bool) -> void:
	var men = _foot_men()
	if men.is_empty():
		return
	var r = _line_spots(a, b, men)
	for e in r["spots"]:
		var s = e[0]
		var q: Vector3 = e[1]
		if G.world.inside_any(q.x, q.z, 0.4):
			q = G.main._free_spot(q)
		if queue and s.order != null and s.order.get("mode", "") == "move" and s.order.get("point") != null and not s.order.has("arrived"):
			if not s.order.has("queue"):
				s.order["queue"] = []
			s.order["queue"].append(q)
			s.order["face"] = r["face"]
			continue
		s.order = {"mode": "move", "point": q, "face": r["face"]}
		_obey(s, q)
	# vehicles in the selection go to the middle of the line
	var vs = []
	for s in selection:
		if is_instance_valid(s) and s.state == "riding" and s.vehicle != null and is_instance_valid(s.vehicle) and not (s.vehicle in vs):
			vs.append(s.vehicle)
	for v in vs:
		v.command(r["c"])
	G.fx.order_marker(r["c"])
	G.audio.radio_click()
	G.audio.order_tick()
	G.ui.message("%d soldier%s forming a line%s" % [men.size(), "" if men.size() == 1 else "s", " (queued)" if queue else ""])

func _pghost(i: int) -> Node3D:
	if pg_mats.is_empty():
		for c in [Color(0.95, 0.95, 0.9, 0.5), Color(0.4, 1.0, 0.45, 0.6)]:
			var m = StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = c
			m.no_depth_test = true
			pg_mats.append(m)
	while pghosts.size() <= i:
		var n = Node3D.new()
		var body = MeshInstance3D.new()
		var cm = CapsuleMesh.new()
		cm.radius = 0.24
		cm.height = 1.7
		cm.radial_segments = 8
		cm.rings = 2
		body.mesh = cm
		body.position = Vector3(0, 0.85, 0)
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(body)
		var nose = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(0.1, 0.1, 0.55)
		nose.mesh = bm
		nose.position = Vector3(0, 1.25, 0.4)
		nose.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(nose)
		var disc = MeshInstance3D.new()
		var dm = CylinderMesh.new()
		dm.top_radius = 0.5
		dm.bottom_radius = 0.5
		dm.height = 0.03
		dm.radial_segments = 16
		disc.mesh = dm
		disc.position = Vector3(0, 0.05, 0)
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(disc)
		add_child(n)
		pghosts.append(n)
	return pghosts[i]

func _covered(q: Vector3) -> bool:
	for cp in G.world.cover_near(q, 1.6):
		if not cp.upper and G.dist2d(cp.p, q) < 1.3:
			return true
	return false

func _order_preview_tick() -> void:
	var used = 0
	var show = G.started and G.player == null and not G.ui.menu_open() and not G.editor.active and not G.ui.tool.begins_with("b:")
	var men = _foot_men() if show else []
	if show and not men.is_empty():
		var spots = []
		var face = null
		if fdrag and fdrag_a != null and fdrag_b != null:
			var r = _line_spots(fdrag_a, fdrag_b, men)
			spots = r["spots"]
			face = r["face"]
		elif drag_from == null:
			var mp = get_viewport().get_mouse_position() if test_mouse == null else test_mouse
			var over_ui = get_viewport().has_method("gui_get_hovered_control") and get_viewport().gui_get_hovered_control() != null
			var p = null if over_ui and test_mouse == null else _ground_at(mp)
			if p != null and Build.site_at(p, 1.5) == null:
				spots = _click_spots(p, men)
		for e in spots:
			var q: Vector3 = e[1]
			var g = _pghost(used)
			used += 1
			g.visible = true
			g.global_position = q
			var cov = _covered(q)
			var mat = pg_mats[1] if cov else pg_mats[0]
			for ch in g.get_children():
				ch.material_override = mat
			# bigger when the camera's high up, so they still read from the commander view
			var zoom = clampf(cam.global_position.distance_to(q) / 40.0, 1.0, 2.2)
			g.scale = Vector3(zoom, zoom * (0.62 if cov else 1.0), zoom)
			var fy = face if face != null else atan2(q.x - e[0].pos.x, q.z - e[0].pos.z)
			g.rotation = Vector3(0, fy, 0)
	for i in range(used, pghosts.size()):
		pghosts[i].visible = false
	_drag_line_tick()
	_waypoint_flags()

var dline: Node3D = null

# the dragged line itself, with an arrow off its middle the way they'll face
func _drag_line_tick() -> void:
	var on = fdrag and fdrag_a != null and fdrag_b != null and G.player == null and not _foot_men().is_empty()
	if not on:
		if dline != null:
			dline.visible = false
		return
	if dline == null:
		dline = Node3D.new()
		var m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(1.0, 0.86, 0.3, 0.85)
		m.no_depth_test = true
		var bar = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(1, 0.06, 0.25)
		bar.mesh = bm
		bar.material_override = m
		dline.add_child(bar)
		var arw = MeshInstance3D.new()
		var pm = PrismMesh.new()
		pm.size = Vector3(1.6, 1.4, 0.06)
		arw.mesh = pm
		arw.material_override = m
		dline.add_child(arw)
		add_child(dline)
	dline.visible = true
	var a: Vector3 = fdrag_a
	var b: Vector3 = fdrag_b
	var mid = (a + b) * 0.5
	var L = G.dist2d(a, b)
	var r = _line_spots(a, b, _foot_men())
	var fy: float = r["face"]
	var zoom = clampf(cam.global_position.distance_to(mid) / 40.0, 1.0, 2.2)
	dline.global_position = Vector3(mid.x, G.world.ground_y(mid.x, mid.z) + 0.15, mid.z)
	var bar: MeshInstance3D = dline.get_child(0)
	bar.rotation = Vector3(0, atan2(b.x - a.x, b.z - a.z) + PI / 2.0, 0)
	bar.scale = Vector3(L, 1, zoom)
	var arw: MeshInstance3D = dline.get_child(1)
	# flat on the ground, tip pointing the way they'll face
	arw.basis = Basis(Vector3.UP, fy) * Basis(Vector3.RIGHT, -PI / 2.0)
	arw.position = Vector3(sin(fy), 0, cos(fy)) * (1.6 * zoom)
	arw.scale = Vector3(zoom, zoom, zoom)

# numbered flags on the queued waypoints of the selected men (one set per squad)
func _waypoint_flags() -> void:
	var used = 0
	if G.started and G.player == null:
		var seen = {}
		for s in selection:
			if not is_instance_valid(s) or s.state != "alive" or s.order == null or s.order.get("queue", []).is_empty():
				continue
			var key = s.squad if s.squad != null else s
			if seen.has(key):
				continue
			seen[key] = true
			var pts = [s.order["point"]] + s.order["queue"]
			for k in range(pts.size()):
				if used >= 24:
					break
				while wp_flags.size() <= used:
					wp_flags.append(_make_flag())
				var fl: Node3D = wp_flags[used]
				var q: Vector3 = pts[k]
				fl.visible = true
				fl.get_child(2).text = str(k + 1)
				fl.global_position = Vector3(q.x, G.world.ground_y(q.x, q.z), q.z)
				var fz = clampf(cam.global_position.distance_to(q) / 40.0, 1.0, 2.2)
				fl.scale = Vector3(fz, fz, fz)
				used += 1
	for i in range(used, wp_flags.size()):
		wp_flags[i].visible = false

# a little yellow pennant on a pole with the stop's number over it
func _make_flag() -> Node3D:
	var n = Node3D.new()
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.86, 0.3)
	m.no_depth_test = true
	var pole = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 0.05
	cm.height = 2.2
	pole.mesh = cm
	pole.position = Vector3(0, 1.1, 0)
	pole.material_override = m
	pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(pole)
	var fl = MeshInstance3D.new()
	var pm = PrismMesh.new()
	pm.size = Vector3(0.9, 0.6, 0.04)
	fl.mesh = pm
	fl.rotation = Vector3(0, 0, -PI / 2.0)
	fl.position = Vector3(0.45, 1.9, 0)
	fl.material_override = m
	fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(fl)
	var l = Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0016
	l.font_size = 26
	l.outline_size = 9
	l.modulate = Color(1.0, 0.92, 0.55)
	l.position = Vector3(0, 2.8, 0)
	n.add_child(l)
	add_child(n)
	return n
