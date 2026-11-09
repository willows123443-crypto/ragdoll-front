class_name Vehicle
extends Node3D
# Jeeps (with a mounted machine gun), troop trucks and tanks. Arcade driving over the terrain,
# seats for the crew, AI drivers and gunners, damage, wrecks, and running people over.
# Local axes: +z is forward, +x is the vehicle's left, +y up.

const SPECS = {
	"jeep": {"name": "Jeep", "len": 4.2, "wid": 2.0, "speed": 15.0, "rev": 5.0, "accel": 7.0, "turn": 1.5, "hp": 520.0,
		"bullet": 0.35, "tracked": false, "standoff": 38.0,
		"seats": [
			{"o": Vector3(0.45, 1.12, 0.15), "role": "driver", "pose": "sit", "face": 0.0},
			{"o": Vector3(0.0, 1.72, -1.35), "role": "gunner", "pose": "stand", "face": 0.0},
			{"o": Vector3(-0.45, 1.12, 0.15), "role": "pass", "pose": "sit", "face": 0.0},
			{"o": Vector3(-0.5, 1.12, -0.85), "role": "pass", "pose": "sit", "face": 0.0}]},
	"truck": {"name": "Truck", "len": 7.2, "wid": 2.5, "speed": 11.0, "rev": 4.0, "accel": 4.5, "turn": 1.0, "hp": 650.0,
		"bullet": 0.3, "tracked": false, "standoff": 0.0,
		"seats": [
			{"o": Vector3(0.5, 1.75, 2.3), "role": "driver", "pose": "sit", "face": 0.0},
			{"o": Vector3(0.8, 1.62, -0.1), "role": "pass", "pose": "sit", "face": -PI / 2.0},
			{"o": Vector3(-0.8, 1.62, -0.1), "role": "pass", "pose": "sit", "face": PI / 2.0},
			{"o": Vector3(0.8, 1.62, -1.0), "role": "pass", "pose": "sit", "face": -PI / 2.0},
			{"o": Vector3(-0.8, 1.62, -1.0), "role": "pass", "pose": "sit", "face": PI / 2.0},
			{"o": Vector3(0.8, 1.62, -1.9), "role": "pass", "pose": "sit", "face": -PI / 2.0},
			{"o": Vector3(-0.8, 1.62, -1.9), "role": "pass", "pose": "sit", "face": PI / 2.0},
			{"o": Vector3(0.8, 1.62, -2.8), "role": "pass", "pose": "sit", "face": -PI / 2.0},
			{"o": Vector3(-0.8, 1.62, -2.8), "role": "pass", "pose": "sit", "face": PI / 2.0}]},
	"tank": {"name": "Tank", "len": 6.6, "wid": 3.3, "speed": 7.5, "rev": 3.5, "accel": 3.5, "turn": 0.85, "hp": 1800.0,
		"bullet": 0.0, "tracked": true, "standoff": 50.0,
		"seats": [
			{"o": Vector3(0.6, 1.0, 1.6), "role": "driver", "pose": "hidden", "face": 0.0},
			{"o": Vector3(0.0, 2.25, -0.2), "role": "gunner", "pose": "hidden", "face": 0.0},
			{"o": Vector3(0.5, 2.35, -0.4), "role": "pass", "pose": "hatch", "face": 0.0, "turret": true}]},
}

const L_VEH = 8

var kind = "jeep"
var spec: Dictionary
var team = 0
var pos = Vector3.ZERO
var yaw = 0.0
var pitch = 0.0
var roll = 0.0
var speed = 0.0
var hp = 400.0
var dead = false
var dead_t = 0.0
var seats: Array = []          # soldier or null per seat
var body: AnimatableBody3D
var turret: Node3D = null
var gun_pivot: Node3D = null
var wheels: Array = []
var turret_yaw = 0.0           # relative to the hull
var gun_pitch = 0.0
var fire_cd = 0.0
var cannon_cd = 0.0
var burst = 0
var burst_cd = 0.5
var aim_point = Vector3.ZERO
var player_inputs = {"thr": 0.0, "steer": 0.0, "fire": false, "aim": Vector3.ZERO}
# AI driving
var mission = null             # {"type": "deliver", "drop": Vector3, "exit": Vector3, "stage": 0, "wait": 0.0}
var path: Array = []
var path_i = 0
var path_t = 0.0
var goal = Vector3.ZERO
var stuck_t = 0.0
var reverse_t = 0.0
var crew_t = 0.0
var smoke_node = null
var engine_t = 0.0

static var mats = {}

static func make(kind_: String, team_: int, p: Vector3, yaw_: float) -> Vehicle:
	var v = Vehicle.new()
	v.kind = kind_
	v.spec = SPECS[kind_]
	v.team = team_
	v.pos = p
	v.yaw = yaw_
	v.hp = v.spec["hp"]
	G.main.add_child(v)
	v._build()
	G.vehicles.append(v)
	v._place(0.0)
	return v

static func _m(key: String, c: Color) -> StandardMaterial3D:
	if not mats.has(key):
		var m = StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.85
		mats[key] = m
	return mats[key]

func _box(parent: Node3D, size: Vector3, at: Vector3, c: Color, collide: bool = false) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _m(c.to_html(), c)
	mi.position = at
	parent.add_child(mi)
	if collide:
		var cs = CollisionShape3D.new()
		var bs = BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.position = at
		body.add_child(cs)
	return mi

func _wheel(at: Vector3, r: float, w: float) -> void:
	var mi = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = w
	cm.radial_segments = 10
	mi.mesh = cm
	mi.material_override = _m("tyre", Color(0.08, 0.08, 0.08))
	mi.rotation.z = PI / 2.0
	var hub = Node3D.new()
	hub.position = at
	hub.add_child(mi)
	add_child(hub)
	wheels.append(hub)

func _build() -> void:
	body = AnimatableBody3D.new()
	body.collision_layer = L_VEH
	body.collision_mask = 0
	body.sync_to_physics = false
	body.set_meta("vehicle", self)
	G.main.add_child(body)
	var base_col = G.TEAM_UNI[team].lerp(Color(0.35, 0.36, 0.3), 0.55)
	var dark = base_col.darkened(0.35)
	var band = G.TEAM_BAND[team]
	match kind:
		"jeep":
			# open-topped: floor, low sides, bonnet, windscreen frame and seats, so the crew is visible
			var col = CollisionShape3D.new()
			var cb = BoxShape3D.new()
			cb.size = Vector3(1.9, 0.9, 4.0)
			col.shape = cb
			col.position = Vector3(0, 0.85, 0)
			body.add_child(col)
			_box(self, Vector3(1.9, 0.22, 4.0), Vector3(0, 0.62, 0), base_col)
			_box(self, Vector3(1.85, 0.5, 1.25), Vector3(0, 0.98, 1.38), base_col)
			for x in [0.92, -0.92]:
				_box(self, Vector3(0.08, 0.42, 2.7), Vector3(x, 0.94, -0.62), base_col)
			_box(self, Vector3(1.9, 0.42, 0.08), Vector3(0, 0.94, -1.96), base_col)
			_box(self, Vector3(1.7, 0.08, 0.12), Vector3(0, 1.18, -1.98), band)
			_box(self, Vector3(1.6, 0.06, 0.06), Vector3(0, 1.72, 0.7), dark)
			for x in [0.8, -0.8]:
				_box(self, Vector3(0.06, 0.55, 0.06), Vector3(x, 1.45, 0.7), dark)
			_box(self, Vector3(1.5, 0.46, 0.02), Vector3(0, 1.46, 0.7), Color(0.55, 0.65, 0.7))
			for x in [0.45, -0.45]:
				_box(self, Vector3(0.55, 0.18, 0.55), Vector3(x, 0.82, 0.1), dark)
				_box(self, Vector3(0.55, 0.5, 0.12), Vector3(x, 1.05, -0.2), dark)
			_box(self, Vector3(1.3, 0.18, 0.55), Vector3(-0.2, 0.82, -0.9), dark)
			_box(self, Vector3(0.36, 0.06, 0.04), Vector3(0.45, 1.25, 0.55), Color(0.1, 0.1, 0.1))
			for z in [1.35, -1.3]:
				for x in [0.95, -0.95]:
					_wheel(Vector3(x, 0.42, z), 0.42, 0.32)
			turret = Node3D.new()
			turret.position = Vector3(0, 1.6, -0.62)
			add_child(turret)
			_box(turret, Vector3(0.12, 0.85, 0.12), Vector3(0, -0.42, 0), dark)
			gun_pivot = Node3D.new()
			gun_pivot.position = Vector3(0, 0.15, 0)
			turret.add_child(gun_pivot)
			_box(gun_pivot, Vector3(0.18, 0.2, 0.9), Vector3(0, 0, 0.25), Color(0.12, 0.12, 0.12))
			_box(gun_pivot, Vector3(0.07, 0.07, 0.8), Vector3(0, 0.02, 1.0), Color(0.1, 0.1, 0.1))
			_box(gun_pivot, Vector3(0.6, 0.4, 0.04), Vector3(0, 0.1, 0.45), dark)
		"truck":
			_box(self, Vector3(2.4, 0.5, 7.0), Vector3(0, 0.95, 0), dark, true)
			# cab with windows so the driver shows
			_box(self, Vector3(2.3, 0.75, 1.8), Vector3(0, 1.55, 2.5), base_col, true)
			_box(self, Vector3(2.3, 0.12, 1.8), Vector3(0, 2.62, 2.5), base_col)
			for x in [1.12, -1.12]:
				for z in [1.65, 3.35]:
					_box(self, Vector3(0.08, 0.95, 0.1), Vector3(x, 2.1, z), base_col)
			_box(self, Vector3(2.2, 0.85, 0.08), Vector3(0, 2.12, 1.62), base_col)
			_box(self, Vector3(2.1, 0.6, 0.02), Vector3(0, 2.2, 3.38), Color(0.55, 0.65, 0.7))
			_box(self, Vector3(2.3, 0.8, 0.9), Vector3(0, 1.4, 3.75), base_col.darkened(0.1))
			_box(self, Vector3(0.55, 0.2, 0.5), Vector3(0.5, 1.95, 2.3), Color(0.15, 0.15, 0.14))
			_box(self, Vector3(2.4, 0.6, 4.6), Vector3(0, 1.5, -1.2), base_col)
			_box(self, Vector3(2.45, 0.1, 4.7), Vector3(0, 2.75, -1.2), base_col.darkened(0.15))
			for x in [1.18, -1.18]:
				_box(self, Vector3(0.06, 1.2, 4.6), Vector3(x, 2.15, -1.2), base_col.darkened(0.15))
			_box(self, Vector3(2.4, 0.1, 0.4), Vector3(0, 2.7, 3.3), band)
			for z in [2.4, -0.4, -2.6]:
				for x in [1.1, -1.1]:
					_wheel(Vector3(x, 0.55, z), 0.55, 0.42)
		"tank":
			_box(self, Vector3(3.3, 1.0, 6.4), Vector3(0, 0.95, 0), base_col, true)
			_box(self, Vector3(3.0, 0.4, 5.2), Vector3(0, 1.6, -0.2), base_col.darkened(0.1), true)
			for x in [1.45, -1.45]:
				_box(self, Vector3(0.7, 0.95, 6.6), Vector3(x, 0.5, 0), Color(0.13, 0.13, 0.12))
			for z in range(5):
				for x in [1.45, -1.45]:
					_wheel(Vector3(x, 0.42, -2.4 + z * 1.2), 0.4, 0.74)
			turret = Node3D.new()
			turret.position = Vector3(0, 1.8, -0.3)
			add_child(turret)
			_box(turret, Vector3(2.3, 0.85, 2.7), Vector3(0, 0.42, 0), base_col)
			_box(turret, Vector3(0.6, 0.18, 0.6), Vector3(0.5, 0.92, -0.4), dark)
			_box(turret, Vector3(1.4, 0.1, 0.3), Vector3(0, 0.88, -1.2), band)
			gun_pivot = Node3D.new()
			gun_pivot.position = Vector3(0, 0.45, 1.3)
			turret.add_child(gun_pivot)
			_box(gun_pivot, Vector3(0.5, 0.5, 0.5), Vector3(0, 0, 0.2), dark)
			_box(gun_pivot, Vector3(0.2, 0.2, 3.2), Vector3(0, 0, 1.9), dark)
			_box(gun_pivot, Vector3(0.3, 0.3, 0.5), Vector3(0, 0, 3.4), dark)
	for s in spec["seats"]:
		seats.append(null)

func seat_xform(i: int) -> Transform3D:
	var sd = spec["seats"][i]
	var xf = global_transform
	if sd.get("turret", false) and turret != null:
		xf = global_transform * Transform3D(Basis(Vector3.UP, turret_yaw), Vector3.ZERO)
	return Transform3D(xf.basis * Basis(Vector3.UP, sd["face"]), xf * sd["o"])

func forward() -> Vector3:
	return Vector3(sin(yaw), 0, cos(yaw))

func driver():
	return seats[0]

func gunner():
	for i in range(seats.size()):
		if spec["seats"][i]["role"] == "gunner":
			return seats[i]
	return null

func gunner_seat() -> int:
	for i in range(seats.size()):
		if spec["seats"][i]["role"] == "gunner":
			return i
	return -1

func free_seat(prefer: String = "") -> int:
	if prefer != "":
		for i in range(seats.size()):
			if seats[i] == null and spec["seats"][i]["role"] == prefer:
				return i
	for i in range(seats.size()):
		if seats[i] == null:
			return i
	return -1

func capacity() -> int:
	return seats.size()

func has_gun() -> bool:
	return gun_pivot != null

func center() -> Vector3:
	return pos + Vector3(0, 1.0, 0)

# ---------------------------------------------------------------- placement on the ground
func _ground(x: float, z: float) -> float:
	return G.world.ground_y(x, z)

func _place(dt: float) -> void:
	var f = forward()
	var l = Vector3(cos(yaw), 0, -sin(yaw))
	var hl = spec["len"] * 0.42
	var hw = spec["wid"] * 0.42
	var hf = _ground(pos.x + f.x * hl, pos.z + f.z * hl)
	var hb = _ground(pos.x - f.x * hl, pos.z - f.z * hl)
	var hL = _ground(pos.x + l.x * hw, pos.z + l.z * hw)
	var hR = _ground(pos.x - l.x * hw, pos.z - l.z * hw)
	var tp = -atan2(hf - hb, hl * 2.0)
	var tr = atan2(hL - hR, hw * 2.0)
	var k = 1.0 if dt <= 0.0 else minf(1.0, dt * 8.0)
	pitch = lerpf(pitch, tp, k)
	roll = lerpf(roll, tr, k)
	pos.y = maxf((hf + hb + hL + hR) * 0.25, _ground(pos.x, pos.z) - 0.1)
	global_transform = Transform3D(Basis.from_euler(Vector3(pitch, yaw, roll)), pos)
	body.global_transform = global_transform

# ---------------------------------------------------------------- per physics tick
func step(dt: float) -> void:
	if dead:
		dead_t += dt
		speed = move_toward(speed, 0.0, 10.0 * dt)
		return
	var thr = 0.0
	var steer = 0.0
	var d = driver()
	if d != null and is_instance_valid(d) and d.state == "riding":
		if d.is_player:
			thr = player_inputs["thr"]
			steer = player_inputs["steer"]
		else:
			var r = _ai_drive(dt)
			thr = r[0]
			steer = r[1]
	var top = spec["speed"] if thr >= 0.0 else spec["rev"]
	var target = thr * top
	if thr == 0.0:
		speed = move_toward(speed, 0.0, 6.0 * dt)
	elif signf(target) != signf(speed) and absf(speed) > 0.3:
		speed = move_toward(speed, 0.0, 12.0 * dt)
	else:
		speed = move_toward(speed, target, spec["accel"] * dt)
	var turn_k = 1.0 if spec["tracked"] else clampf(absf(speed) / 4.0, 0.0, 1.0)
	var dir_k = -1.0 if speed < -0.1 else 1.0
	yaw += steer * spec["turn"] * turn_k * dir_k * dt
	var f = forward()
	var np = pos + f * speed * dt
	# walls, crates and other vehicles
	var bumped = false
	var r_ = spec["wid"] * 0.5
	var n = int(ceil(spec["len"] / spec["wid"]))
	for k in range(n + 1):
		var off = (float(k) / float(n) - 0.5) * (spec["len"] - spec["wid"])
		var c = np + f * off
		var res = G.world.push_out_circle(c, r_)
		if res[1] != null:
			var col = res[1]
			# tanks flatten crates and flimsy walls; anything fast smashes crates
			if col.dest and (spec["tracked"] or (col.prop == 1 and absf(speed) > 6.0)):
				G.world.destroy_col(col)
				speed *= 0.85
				continue
			np += res[0] - c
			bumped = true
	for o in G.vehicles:
		if o == self:
			continue
		var dv = G.flat(np - o.pos)
		var md = (spec["len"] + o.spec["len"]) * 0.3
		if dv.length() < md and dv.length() > 0.01:
			np += dv.normalized() * (md - dv.length())
			bumped = true
	if bumped and absf(speed) > 3.0:
		speed *= 0.4
		G.audio.hit_tick(false)
	elif bumped:
		speed *= 0.8
	var b = G.world.bounds
	np.x = clampf(np.x, b.position.x + 3.0, b.end.x - 3.0)
	np.z = clampf(np.z, b.position.y + 3.0, b.end.y - 3.0)
	pos = np
	_place(dt)
	_hit_people(f)
	for w in wheels:
		w.rotation.x += speed * dt / 0.45
	_weapons(dt)
	_crew_tick(dt)
	engine_t -= dt
	if engine_t <= 0.0 and driver() != null:
		engine_t = 0.35
		G.audio.engine(pos, absf(speed) / spec["speed"], kind == "tank")

func _hit_people(f: Vector3) -> void:
	var l = Vector3(cos(yaw), 0, -sin(yaw))
	var hl = spec["len"] * 0.5 + 0.25
	var hw = spec["wid"] * 0.5 + 0.25
	for s in G.soldiers:
		if s.vehicle == self or s.state == "riding":
			continue
		var p: Vector3 = s.pos if s.state == "alive" or s.state == "getup" else s.parts[0].global_position
		var rel = G.flat(p - pos)
		var a = rel.dot(f)
		var bb = rel.dot(l)
		if absf(a) > hl or absf(bb) > hw or absf(p.y - pos.y) > 2.0:
			continue
		if (s.state == "alive" or s.state == "getup") and absf(speed) > 2.5:
			# run over
			var dmg = speed * speed * 0.7
			var drv = driver()
			s.fall(2.0)
			s.push(1, f * speed * 0.9 * signf(speed) + Vector3(0, 2.5, 0), 0.6)
			Combat.hit_soldier(s, 1, s.chest(), f * signf(speed), dmg, drv if (drv != null and is_instance_valid(drv)) else null, 2.0)
		elif s.state == "alive":
			# shove aside
			var side = l * (1.0 if bb >= 0.0 else -1.0)
			s.pos += side * (hw - absf(bb)) * 0.5
			s.pos = G.world.push_out_circle(s.pos, 0.33)[0]

# ---------------------------------------------------------------- weapons
func _gun_dir() -> Vector3:
	if gun_pivot == null:
		return forward()
	return gun_pivot.global_transform.basis.z.normalized()

func muzzle() -> Vector3:
	if gun_pivot == null:
		return center()
	return gun_pivot.global_transform * Vector3(0, 0.02, 1.45 if kind == "jeep" else 3.7)

func _weapons(dt: float) -> void:
	fire_cd -= dt
	cannon_cd -= dt
	if turret == null:
		return
	var g = gunner()
	var controller = g
	var drv = driver()
	if g == null and drv != null and is_instance_valid(drv) and drv.is_player and kind == "tank":
		controller = drv          # a lone player in a tank works the gun too
	if controller == null or not is_instance_valid(controller) or controller.state != "riding":
		return
	var want = null
	var shoot = false
	var use_cannon = false
	if controller.is_player:
		want = player_inputs["aim"]
		shoot = player_inputs["fire"]
		use_cannon = kind == "tank" and not Input.is_key_pressed(KEY_SHIFT)
	else:
		var t = _ai_gun_target(controller)
		if t != null:
			want = t[0]
			use_cannon = t[1]
			shoot = true
	if want == null:
		turret_yaw = lerp_angle(turret_yaw, 0.0, dt * 0.8)
		gun_pitch = lerpf(gun_pitch, 0.0, dt)
		_apply_turret()
		return
	aim_point = want
	# rotate the turret toward the target at a limited speed
	var local = global_transform.affine_inverse() * want
	var ty = atan2(local.x, local.z) - turret.position.x * 0.0
	var rate = 1.1 if kind == "tank" else 3.5
	turret_yaw = turret_yaw + clampf(wrapf(ty - turret_yaw, -PI, PI), -rate * dt, rate * dt)
	var piv = gun_pivot.global_position
	var flat_d = G.dist2d(want, piv)
	var tp = atan2(want.y - piv.y, flat_d) - pitch * cos(turret_yaw)
	gun_pitch = clampf(gun_pitch + clampf(tp - gun_pitch, -1.5 * dt, 1.5 * dt), -0.15 if kind == "tank" else -0.35, 0.4)
	_apply_turret()
	var err = absf(wrapf(ty - turret_yaw, -PI, PI))
	if not shoot or err > 0.08:
		return
	var dir = (want - muzzle()).normalized()
	if not controller.is_player:
		if AI.friendly_in_line(controller, muzzle(), dir, muzzle().distance_to(want)) != null:
			return
	if use_cannon:
		if cannon_cd <= 0.0:
			cannon_cd = 4.5
			Combat.launch_shell(self, controller, muzzle(), _gun_dir())
			G.fx.muzzle(muzzle(), true)
			G.audio.boom(muzzle())
			Combat.shake = maxf(Combat.shake, 0.3 if controller.is_player else 0.0)
	else:
		if not controller.is_player:
			if burst <= 0:
				burst_cd -= dt
				if burst_cd <= 0.0:
					burst = randi_range(6, 16)
					burst_cd = randf_range(0.6, 1.4)
				return
		if fire_cd <= 0.0:
			fire_cd = 0.085
			burst -= 1
			var W = G.WEAPONS["hmg"]
			var spread = W["spread"] + (0.008 if absf(speed) > 1.0 else 0.0)
			Combat.fire_ray(controller, muzzle(), Combat.spread_dir(_gun_dir(), spread), W, true, [body.get_rid()])
			G.fx.muzzle(muzzle(), false)
			G.audio.shot(muzzle(), W)

func _apply_turret() -> void:
	turret.rotation.y = turret_yaw
	gun_pivot.rotation.x = -gun_pitch

# what should an AI gunner shoot at? returns [point, use_cannon] or null
func _ai_gun_target(g):
	var best = null
	var bd = 1e9
	# enemy vehicles first for the cannon
	if kind == "tank":
		for o in G.vehicles:
			if o.team != team and not o.dead and o.pos.distance_to(pos) < 160.0 and not G.blocked(muzzle(), o.center()):
				var d = o.pos.distance_to(pos)
				if d < bd:
					bd = d
					best = [o.center(), true]
		if best != null:
			return best
	var tgt = g.vis_t
	if tgt == null or not is_instance_valid(tgt) or tgt.state == "dead":
		return null
	var p = tgt.chest()
	var d2 = p.distance_to(pos)
	if kind == "tank":
		# shell groups and soldiers in cover; machine gun the rest
		var near = 0
		for o in G.soldiers:
			if o.team != team and o.state != "dead" and o.pos.distance_to(tgt.pos) < 6.0:
				near += 1
		return [p, d2 > 18.0 and (near >= 2 or tgt.in_cover or cannon_cd <= 0.0)]
	return [p, false]

# ---------------------------------------------------------------- crew
func _crew_tick(dt: float) -> void:
	for i in range(seats.size()):
		var s = seats[i]
		if s != null and (not is_instance_valid(s) or s.vehicle != self):
			seats[i] = null
	# empty driver or gunner seats: a nearby friendly soldier with nothing better to do climbs in
	crew_t -= dt
	if crew_t > 0.0 or mission != null:
		return
	crew_t = 3.0
	for role in ["driver", "gunner"]:
		var si = -1
		for i in range(seats.size()):
			if seats[i] == null and spec["seats"][i]["role"] == role:
				si = i
		if si < 0:
			continue
		var best = null
		var bd = 30.0
		for s in G.soldiers:
			if s.team == team and s.state == "alive" and not s.is_player and s.vehicle == null and s.task != "board" and not s.broken and s.vis_t == null:
				var dd = G.dist2d(s.pos, pos)
				if dd < bd:
					bd = dd
					best = s
		if best != null:
			best.board_target = self
			best.task = "board"
			AI.release_cover(best)
			AI.go_to(best, pos, 5.0)
			G.fx.callout(best, G.pick(["I'll take the wheel!", "Manning the gun!", "Getting in!"]) if role == "gunner" else "I'll drive!")

func take_damage(amount: float, attacker, at: Vector3) -> void:
	if dead:
		return
	hp -= amount
	if hp < spec["hp"] * 0.35 and smoke_node == null:
		G.fx.wreck_smoke(center(), self)
		smoke_node = true
	if hp <= 0.0:
		destroy(attacker)

func destroy(attacker) -> void:
	if dead:
		return
	dead = true
	hp = 0.0
	G.fx.explosion(center(), 1.4)
	G.audio.boom(center())
	if smoke_node == null:
		G.fx.wreck_smoke(center(), self)
		smoke_node = true
	for m in get_children():
		if m is MeshInstance3D:
			m.material_override = _m("wreck", Color(0.12, 0.11, 0.1))
	if turret:
		for m in turret.get_children():
			if m is MeshInstance3D:
				m.material_override = _m("wreck", Color(0.12, 0.11, 0.1))
	for i in range(seats.size()):
		var s = seats[i]
		if s != null and is_instance_valid(s):
			s.dismount(true)
			if randf() < (0.8 if kind == "tank" else 0.5):
				Combat.kill(s, attacker, false)
			else:
				s.hp = minf(s.hp, 30.0)
	if attacker != null and is_instance_valid(attacker) and attacker.team != team:
		G.ui.feed(attacker, null, false, spec["name"])
	Stats.vehicle_lost(team)

func remove() -> void:
	for i in range(seats.size()):
		if seats[i] != null and is_instance_valid(seats[i]):
			seats[i].dismount(false)
	G.vehicles.erase(self)
	body.queue_free()
	queue_free()

# ---------------------------------------------------------------- AI driving
func _set_goal(p: Vector3) -> void:
	if p.distance_to(goal) < 4.0 and path_t > 0.0 and not path.is_empty():
		return
	goal = p
	path = G.world.find_path(pos, _leg(p))
	path_i = 0
	path_t = 4.0

func _leg(p: Vector3) -> Vector3:
	if G.dist2d(p, pos) > 90.0:
		return pos + G.flat(p - pos).normalized() * 75.0
	return p

func _steer_to(target: Vector3, dt: float) -> Array:
	var to = G.flat(target - pos)
	var ang = wrapf(atan2(to.x, to.z) - yaw, -PI, PI)
	var steer = clampf(ang * 2.0, -1.0, 1.0)
	var thr = 1.0 if absf(ang) < 0.9 else 0.35
	if absf(ang) > 2.4 and to.length() < 14.0:
		thr = -1.0
		steer = -steer
	if not spec["tracked"] and absf(ang) > 1.2:
		thr = 0.5
	return [thr, steer]

func _ai_drive(dt: float) -> Array:
	path_t -= dt
	var d = driver()
	var target = null
	if mission != null:
		target = _mission_target(dt)
		if target == null:
			return [0.0, 0.0]
	else:
		var obj: Vector3 = AI.objective_for(d)
		var enemy = null
		var best = AI.best_intel(d)
		if best != null and G.sim_time - best["t"] < 15.0:
			enemy = best["p"]
		var stand = spec["standoff"]
		if enemy != null and stand > 0.0:
			var de = G.dist2d(enemy, pos)
			if de < stand * 0.55:
				# too close: back away from the enemy
				target = pos + G.flat(pos - enemy).normalized() * 15.0
			elif de < stand:
				return [0.0, 0.0]        # in a good firing position: hold
			else:
				target = enemy
		else:
			target = obj
		if hp < spec["hp"] * 0.3 and enemy != null:
			target = G.world.rally_point(team)
		if G.dist2d(target, pos) < 8.0:
			return [0.0, 0.0]
	_set_goal(target)
	# follow the path with some look-ahead
	var aim: Vector3 = target
	while path_i < path.size() and G.dist2d(path[path_i], pos) < 5.0:
		path_i += 1
	if path_i < path.size():
		aim = path[path_i]
	if path_t <= 0.0:
		path_t = 4.0
		path = G.world.find_path(pos, _leg(goal))
		path_i = 0
	var r = _steer_to(aim, dt)
	# whiskers: veer away from walls just ahead
	if r[0] > 0.0:
		var f0 = forward()
		var front = pos + f0 * spec["len"] * 0.5 + Vector3(0, 0.8, 0)
		for side in [-1.0, 1.0]:
			var a = yaw + side * 0.45
			var wd = Vector3(sin(a), 0, cos(a))
			var off = Vector3(f0.z, 0, -f0.x) * side * -spec["wid"] * 0.45
			if not G.ray(front + off, front + off + wd * (4.0 + absf(speed) * 0.6), G.L_WORLD).is_empty():
				r[1] -= side * 0.8
		r[1] = clampf(r[1], -1.0, 1.0)
	# don't drive over friends
	var f = forward()
	for s in G.soldiers:
		if s.team == team and s.state == "alive" and s.vehicle == null:
			var rel = G.flat(s.pos - pos)
			var a = rel.dot(f) * signf(r[0] if r[0] != 0.0 else 1.0)
			if a > 0.0 and a < spec["len"] * 0.5 + 5.0 and absf(rel.dot(Vector3(f.z, 0, -f.x))) < spec["wid"] * 0.5 + 0.8:
				return [0.0, r[1]]
	# unstick: if we want to move but aren't, back up for a moment
	if reverse_t > 0.0:
		reverse_t -= dt
		return [-1.0, -r[1]]
	if absf(r[0]) > 0.3 and absf(speed) < 0.6:
		stuck_t += dt
		if stuck_t > 1.6:
			stuck_t = 0.0
			reverse_t = 1.4
	else:
		stuck_t = 0.0
	return r

func _mission_target(dt: float):
	var m = mission
	if m["stage"] == 0:
		if G.dist2d(pos, m["drop"]) < 6.0:
			m["stage"] = 1
			m["wait"] = 2.5
			for i in range(1, seats.size()):
				var s = seats[i]
				if s != null and is_instance_valid(s):
					s.dismount(false)
			if driver() != null:
				G.fx.callout(driver(), G.pick(["Everybody out!", "Go, go, go!", "Unload!"]))
			return null
		return m["drop"]
	if m["stage"] == 1:
		m["wait"] -= dt
		if m["wait"] <= 0.0:
			m["stage"] = 2
		return null
	if G.dist2d(pos, m["exit"]) < 6.0:
		var d = driver()
		remove()
		if d != null and is_instance_valid(d):
			G.soldiers.erase(d)
			d.queue_free()
		return null
	return m["exit"]
