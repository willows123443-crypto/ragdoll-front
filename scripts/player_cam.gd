extends Node3D
# Free camera, taking control of soldiers, aiming, recoil, and the sandbox tools.

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

func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 65.0
	cam.near = 0.05
	cam.far = 700.0
	add_child(cam)
	cam.current = true

# ---------------------------------------------------------------- controlling a soldier
func possess(s) -> void:
	if s == null or s.state == "dead":
		G.ui.message("Pick a living soldier")
		return
	if G.player != null and G.player != s and is_instance_valid(G.player):
		G.player.is_player = false
	G.player = s
	s.is_player = true
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
	s.want = m.normalized() * sp if m.length_squared() > 0.0 else Vector3.ZERO
	s.crouch_t = 0.9 if s.p_crouch else 0.0
	s.prone_t = s.p_prone
	var lean = 0.0
	if not sprint and not s.p_prone:
		lean = (1.0 if Input.is_key_pressed(KEY_E) else 0.0) - (1.0 if Input.is_key_pressed(KEY_Q) else 0.0)
	s.lean_t = lean
	var oy = s.pos.y + (0.3 if s.prone else 1.45 - 0.45 * s.crouch)
	s.aim_yaw = atan2(aim_point.x - s.pos.x, aim_point.z - s.pos.z)
	s.aim_pitch = clampf(atan2(aim_point.y - oy, G.dist2d(aim_point, s.pos)), -1.1, 1.1)
	s.ready_ = not sprint
	if s.reload_t > 0.0:
		s.reload_t -= G.DT
		if s.reload_t <= 0.0:
			s.mag = W["mag"]
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
		if s.mag <= 0:
			s.reload_t = W["reload"]
	if not mouse_down:
		trig_latch = false

# ---------------------------------------------------------------- camera
func _process(dt: float) -> void:
	bloom = maxf(0.0, bloom - dt * 0.08)
	kick = maxf(0.0, kick - dt * 1.6)
	var fov_t = 65.0
	if G.player != null and not is_instance_valid(G.player):
		G.player = null
	if G.player != null:
		var s = G.player
		var cp = cos(cam_pitch)
		var d = Vector3(sin(cam_yaw) * cp, sin(cam_pitch), cos(cam_yaw) * cp)
		var r = Vector3(-cos(cam_yaw), 0, sin(cam_yaw))
		var back = 2.4
		var side = 0.6
		var piv: Vector3
		if s.state == "alive":
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
		var hit = G.ray(piv, want_p, G.L_WORLD)
		if not hit.is_empty():
			want_p = piv + (want_p - piv).normalized() * maxf(0.2, piv.distance_to(hit.position) - 0.2)
		cam.global_position = want_p
		cam.look_at(want_p + d, Vector3.UP)
		var ah = G.ray(want_p, want_p + d * 300.0, G.L_WORLD | G.L_BODY, s.rids)
		aim_point = want_p + d * 300.0 if ah.is_empty() else ah.position
		if aim_point.distance_to(piv) < 2.0:
			aim_point = want_p + d * 20.0
	else:
		if not G.started:
			orbit += dt * 0.05
			var c = G.world.capture
			free_pos = Vector3(c.x + cos(orbit) * 55.0, G.world.ground_y(c.x, c.z) + 22.0, c.z + sin(orbit) * 55.0)
			free_yaw = atan2(c.x - free_pos.x, c.z - free_pos.z)
			free_pitch = -0.32
		var cp = cos(free_pitch)
		var d = Vector3(sin(free_yaw) * cp, sin(free_pitch), cos(free_yaw) * cp)
		var r = Vector3(-cos(free_yaw), 0, sin(free_yaw))
		if G.started and not G.ui.typing():
			var sp = (40.0 if Input.is_key_pressed(KEY_SHIFT) else 14.0) * dt
			if Input.is_key_pressed(KEY_W): free_pos += d * sp
			if Input.is_key_pressed(KEY_S): free_pos -= d * sp
			if Input.is_key_pressed(KEY_D): free_pos += r * sp
			if Input.is_key_pressed(KEY_A): free_pos -= r * sp
			if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_SPACE): free_pos.y += sp
			if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_C) or Input.is_key_pressed(KEY_CTRL): free_pos.y -= sp
		free_pos.y = clampf(free_pos.y, G.world.ground_y(free_pos.x, free_pos.z) + 0.6, 140.0)
		cam.global_position = free_pos
		cam.look_at(free_pos + d, Vector3.UP)
	if absf(cam.fov - fov_t) > 0.05:
		cam.fov += (fov_t - cam.fov) * minf(1.0, dt * 14.0)
	if Combat.shake > 0.0:
		cam.global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * Combat.shake * 0.25
		Combat.shake = maxf(0.0, Combat.shake - dt * 2.5)
	G.main.follow_sun(cam.global_position, -cam.global_basis.z)

# ---------------------------------------------------------------- input
func _unhandled_input(ev: InputEvent) -> void:
	if not G.started or G.ui.menu_open():
		return
	if ev is InputEventMouseMotion:
		var k = 0.0024 * G.settings["sens"] * (cam.fov / 65.0)
		var inv = -1.0 if G.settings["invert_y"] else 1.0
		if G.player != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			cam_yaw -= ev.relative.x * k
			cam_pitch = clampf(cam_pitch - ev.relative.y * k * inv, -1.2, 1.2)
		elif G.player == null and r_drag:
			free_yaw -= ev.relative.x * 0.004 * G.settings["sens"]
			free_pitch = clampf(free_pitch - ev.relative.y * 0.004 * G.settings["sens"] * inv, -1.45, 1.45)
	elif ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_RIGHT:
			if G.player != null:
				rmb_down = ev.pressed
			else:
				r_drag = ev.pressed
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				if G.player != null:
					if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
						Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
					else:
						mouse_down = true
				else:
					use_tool(ev.position)
			else:
				mouse_down = false
		elif ev.button_index == MOUSE_BUTTON_WHEEL_UP and G.player == null and ev.pressed:
			free_pos += Vector3(sin(free_yaw) * cos(free_pitch), sin(free_pitch), cos(free_yaw) * cos(free_pitch)) * 2.0
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and G.player == null and ev.pressed:
			free_pos -= Vector3(sin(free_yaw) * cos(free_pitch), sin(free_pitch), cos(free_yaw) * cos(free_pitch)) * 2.0
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		_key(ev.keycode)

func _key(k: int) -> void:
	if k == KEY_T:
		Engine.time_scale = 0.25 if Engine.time_scale > 0.5 else 1.0
	elif k == KEY_P:
		get_tree().paused = not get_tree().paused
	if G.player != null:
		var s = G.player
		if k == KEY_X:
			leave_soldier()
		elif k == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif k == KEY_R and s.mag < s.W["mag"] and s.reload_t <= 0.0 and s.state == "alive":
			s.reload_t = s.W["reload"]
		elif k == KEY_C:
			s.p_crouch = not s.p_crouch
			s.p_prone = false
		elif k == KEY_Z:
			s.p_prone = not s.p_prone
			s.p_crouch = false
		elif k == KEY_G and s.grenades > 0 and s.state == "alive":
			Combat.throw_grenade(s, _throw_target(s), "frag")
		elif k == KEY_V and s.smokes > 0 and s.state == "alive":
			Combat.throw_grenade(s, _throw_target(s), "smoke")
		elif k >= KEY_1 and k <= KEY_5 and s.state == "alive":
			s.set_weapon(G.WEAPON_LIST[k - KEY_1])
			G.ui.message(s.W["name"])
	else:
		if k >= KEY_1 and k <= KEY_9:
			G.ui.pick_tool(k - KEY_1)
		elif k == KEY_F:
			var cp = cos(free_pitch)
			var d = Vector3(sin(free_yaw) * cp, sin(free_pitch), cos(free_yaw) * cp)
			possess(pick_soldier(cam.global_position, d))

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
	if tool == "ctl":
		possess(pick_soldier(o, d))
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
	if tool == "a1" or tool == "b1":
		G.main.spawn_soldier(0 if tool == "a1" else 1, p.x, p.z, "")
	elif tool == "a5" or tool == "b5":
		var team = 0 if tool == "a5" else 1
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
	elif tool == "spA" or tool == "spB":
		G.world.spawn[0 if tool == "spA" else 1] = Vector3(p.x, 0, p.z)
		G.main.refresh_markers()
