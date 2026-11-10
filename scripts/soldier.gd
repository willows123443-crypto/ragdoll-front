class_name Soldier
extends Node3D
# A soldier is 11 rigid bodies joined together. "Muscles" push each body toward an animated pose every
# physics tick; when strength drops (hit, knocked down, dead) the body goes limp and Jolt takes over.

# pose points: 0 head,1 neck,2 pelvis,3 lSh,4 lEl,5 lHand,6 rSh,7 rEl,8 rHand,9 lHip,10 lKnee,11 lFoot,12 rHip,13 rKnee,14 rFoot
# parts: 0 pelvis,1 chest,2 head,3 upper arm L,4 forearm L,5 upper arm R,6 forearm R,7 thigh L,8 shin L,9 thigh R,10 shin R
const PART_SEG = [[-1, -1], [-1, -1], [-1, -1], [3, 4], [4, 5], [6, 7], [7, 8], [9, 10], [10, 11], [12, 13], [13, 14]]
const PART_W = [0.36, 0.44, 0.26, 0.13, 0.12, 0.13, 0.12, 0.17, 0.15, 0.17, 0.15]
const PART_H = [0.22, 0.52, 0.27, 0.3, 0.3, 0.3, 0.3, 0.45, 0.45, 0.45, 0.45]
const PART_D = [0.25, 0.26, 0.26, 0.13, 0.12, 0.13, 0.12, 0.17, 0.15, 0.17, 0.15]
const PART_MASS = [10.0, 14.0, 4.0, 2.5, 2.0, 2.5, 2.0, 7.0, 4.0, 7.0, 4.0]
const PART_MUS = [1.0, 1.0, 0.7, 1.05, 0.95, 1.05, 0.95, 1.0, 1.1, 1.0, 1.1]
const PART_REG = [0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4]       # 0 core, 1 l-arm, 2 r-arm, 3 l-leg, 4 r-leg
const PART_KIND = ["torso", "torso", "head", "arm", "arm", "arm", "arm", "leg", "leg", "leg", "leg"]

const KF = {
	"PRONE": [[0, 0.24, 0.8], [0, 0.2, 0.57], [0, 0.16, 0.01], [-0.21, 0.18, 0.53], [-0.33, 0.07, 0.3], [-0.22, 0.07, 0.55], [0.21, 0.18, 0.53], [0.33, 0.07, 0.3], [0.22, 0.07, 0.55],
		[-0.11, 0.15, -0.04], [-0.14, 0.1, -0.49], [-0.16, 0.08, -0.94], [0.11, 0.15, -0.04], [0.14, 0.1, -0.49], [0.16, 0.08, -0.94]],
	"ALLFOURS": [[0, 0.74, 0.66], [0, 0.64, 0.48], [0, 0.6, -0.07], [-0.21, 0.6, 0.44], [-0.25, 0.33, 0.47], [-0.22, 0.05, 0.5], [0.21, 0.6, 0.44], [0.25, 0.33, 0.47], [0.22, 0.05, 0.5],
		[-0.11, 0.56, -0.08], [-0.13, 0.08, -0.02], [-0.14, 0.07, -0.47], [0.11, 0.56, -0.08], [0.13, 0.08, -0.02], [0.14, 0.07, -0.47]],
	"KNEEL": [[0, 1.37, 0.12], [0, 1.16, 0.08], [0, 0.6, 0], [-0.21, 1.11, 0.08], [-0.27, 0.86, 0.2], [-0.12, 0.8, 0.42], [0.21, 1.11, 0.08], [0.27, 0.85, 0.02], [0.1, 0.74, 0.22],
		[-0.11, 0.56, 0], [-0.13, 0.55, 0.45], [-0.14, 0.07, 0.47], [0.11, 0.56, 0], [0.13, 0.08, 0.06], [0.14, 0.08, -0.39]],
	"SIT": [[0, 0.86, -0.08], [0, 0.66, -0.13], [0, 0.14, 0], [-0.21, 0.6, -0.13], [-0.3, 0.34, -0.2], [-0.32, 0.06, -0.2], [0.21, 0.6, -0.13], [0.3, 0.34, -0.2], [0.32, 0.06, -0.2],
		[-0.11, 0.12, 0.03], [-0.13, 0.42, 0.35], [-0.14, 0.07, 0.6], [0.11, 0.12, 0.03], [0.13, 0.42, 0.35], [0.14, 0.07, 0.6]],
}
const SEQ_DOWN = [["ALLFOURS", 0.6, 0.16], ["KNEEL", 0.55, 0.22], ["STAND", 0.45, 0.3]]
const SEQ_UP = [["SIT", 0.65, 0.15], ["KNEEL", 0.65, 0.2], ["STAND", 0.45, 0.3]]
const UPREF = {1: [0, 0.56, 0], 0: [0, 0.77, 0.03], 3: [-0.21, 0.51, 0], 6: [0.21, 0.51, 0]}

static var mats = {}
static var camo_tex: ImageTexture = null
static var next_id = 0
static var zombie_next = false    # the horde: the next soldier made is one of the walking dead
var zombie = false
var melee_t = 0.0

var id = 0
var team = 0
var sname = ""
var wid = "rifle"
var W: Dictionary
var pos = Vector3.ZERO
var vel = Vector3.ZERO
var want = Vector3.ZERO
var vy = 0.0
var body_yaw = 0.0
var aim_yaw = 0.0
var aim_pitch = 0.0
var phase = 0.0
var crouch = 0.0
var crouch_t = 0.0
var lean = 0.0
var lean_t = 0.0
var ready_ = false
var turning = false
var prone = false
var prone_t = false
var vault = null
var stumble = 0.0
var stumble_dir = Vector3.ZERO
var seed_ = 0.0
var hp = 100.0
var state = "alive"
var strength = 0.42
var stun = 0.0
var limb = [1.0, 1.0, 1.0, 1.0, 1.0]
var P: Array = []
var parts: Array = []
var targets: Array = []
var rids: Array = []
var gun_node: Node3D
var gun_body: RigidBody3D = null
var gun_dir_p = Vector3.FORWARD
var gun_dir = Vector3.FORWARD
var grip = Vector3.ZERO
var muzzle = Vector3.ZERO
var gun_blocked = false
var anchor_l = false
var mag = 30
var reserve = 120       # rounds carried besides the loaded magazine
var resupply_t = 0.0
var supply_target = null
var morale = 70.0
var nerve = 1.0         # how hard bad news hits this soldier
var nerve_cap = 80.0    # morale they settle at when things are calm
var broken = false
var rally_cd = 0.0
var morale_t = 0.0
var rec = null          # stats record (see Stats)
var leader_mark: Node3D = null
var vehicle = null
var seat = -1
var board_target = null
var hidden_in_vehicle = false
var chute: Node3D = null
var partial = false
var cls = "rifleman"
var mines = 0
var satchels = 0
var kits = 0            # sandbag kits (engineers)
var radio_cd = 20.0
var build_t = 0.0
var burn_t = 0.0
var burn_fx_t = 0.0
var primary = null      # [weapon, mag, reserve] while using the sidearm
var partner = null      # sniper <-> spotter
var job_cd = 0.0
var build_site = null       # the construction site this soldier is working on
var vis_veh = null
var fired_t = -99.0
var flares = 0
var flare_cd = 0.0
var reload_t = 0.0
var fire_cd = 0.0
var burst = 0
var burst_cd = 0.5
var grenades = 2
var smokes = 1
var rockets = 3
var stickies = 0
var rgren = 0             # rifle grenades
var heat = 0.0            # machine gun barrel heat (0..1)
var barrel_t = 0.0        # changing an overheated barrel
var shots_here = 0        # snipers move after a few shots from one spot
var light_on = false
var flashlight: Node3D = null
var nade_cd = 6.0
var throw_t = 0.0
var hand_t = null
var tool_mode = ""           # "hammer" while building
var hammer: Node3D = null
var hammer_hit = false
var mag_drop = false
var skin = Color.WHITE
var callout_cd = 0.0
var is_player = false
var p_crouch = false
var p_prone = false
var ads = false
var down_t = 0.0
var dead_t = 0.0
var last_attacker = null
var hurt_t = 0.0
var supp = 0.0
var heal_t = 0.0
var medic = null
var dragger = null
var dragging = null
var carrying = null         # a wounded friend over the shoulder
var carried_by = null
var crate = false           # lugging an ammo box
var wound_part = -1         # where they were last hit (they clutch it)
var vet = 0                 # veteran level (campaign): steadier aim and nerves
var kills = 0
var crate_mesh: MeshInstance3D = null
var gu = null
var crawl_target = null
var pooled = false
# AI
var think = 0.0
var decide_t = 0.0
var vis_t = null
var target = null
var threat = Vector3.ZERO
var has_threat = false
var last_seen = Vector3.ZERO
var has_seen = false
var seen_t = -99.0
var intel = {}
var report_t = 0.0
var task = null
var move_target = null
var path: Array = []
var path_i = 0
var need_path = false
var speed_t = 4.6
var cover = null
var in_cover = false
var cover_time = 0.0
var cover_bad = 0
var peek_vis = false
var want_peek = false
var force_peek = false
var kneel = false
var prog_t = 0.0
var prog_p = Vector3.ZERO
var stuck_n = 0
var unstick_t = 0.0          # sidestepping around whatever we ran into
var unstick_dir = Vector3.ZERO
var bad_spot = null          # a place we got stuck trying to reach
var bad_t = 0.0
var idle_p = Vector3.ZERO
var idle_t = 0.0
var ff_t = 0.0
var block_t = 0.0
var squad = null
var role = "rifleman"
var patient = null
var flee = null
var flee_t = 0.0
var route = null
var tower = null
var order = null
var drag_to = null

func setup(team_: int, x: float, z: float, weapon_id: String) -> void:
	next_id += 1
	id = next_id
	team = team_
	sname = G.pick(G.NAMES)
	wid = weapon_id
	W = G.WEAPONS[wid]
	mag = W["mag"]
	reserve = W["mag"] * W["mags"]
	nerve = randf_range(0.75, 1.3)
	nerve_cap = randf_range(68.0, 88.0)
	morale = nerve_cap - randf_range(0.0, 10.0)
	morale_t = randf() * 0.5
	pos = Vector3(x, G.world.ground_y(x, z), z)
	body_yaw = PI / 2.0 if team == 0 else -PI / 2.0
	aim_yaw = body_yaw
	phase = randf() * 6.0
	seed_ = randf() * 100.0
	skin = G.pick(G.SKINS)
	zombie = zombie_next
	if zombie:
		skin = Color(0.5, 0.57, 0.42).lerp(Color(0.6, 0.6, 0.5), randf() * 0.5)
	callout_cd = randf_range(0.0, 3.0)
	burst_cd = randf_range(0.3, 1.2)
	nade_cd = randf_range(4.0, 10.0)
	think = randf_range(0.0, 0.3)
	decide_t = randf_range(0.0, 0.5)
	for i in range(15):
		P.append(Vector3.ZERO)
	for i in range(11):
		targets.append(Transform3D())
	stand_pose()
	_build_body()
	_build_gun()
	compute_muzzle()

func face(yaw: float) -> void:
	body_yaw = yaw
	aim_yaw = yaw
	stand_pose()
	_compute_targets()
	for i in range(parts.size()):
		parts[i].global_transform = targets[i]
		parts[i].linear_velocity = Vector3.ZERO
		parts[i].angular_velocity = Vector3.ZERO

# ---------------------------------------------------------------- building the body
static func _mat(key: String, col: Color, camo: bool) -> StandardMaterial3D:
	if mats.has(key):
		return mats[key]
	var m = StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.9
	if camo:
		if camo_tex == null:
			var img = Image.create_empty(64, 64, false, Image.FORMAT_RGB8)
			img.fill(Color(1, 1, 1))
			var r = RandomNumberGenerator.new()
			r.seed = 9
			for i in range(34):
				var v: float = [0.59, 0.75, 0.88][i % 3]
				var cx = r.randf_range(0, 64)
				var cy = r.randf_range(0, 64)
				var rx = r.randf_range(3, 12)
				var ry = r.randf_range(2, 8)
				for y in range(64):
					for x in range(64):
						if pow((x - cx) / rx, 2) + pow((y - cy) / ry, 2) < 1.0:
							img.set_pixel(x, y, Color(v, v, v))
			camo_tex = ImageTexture.create_from_image(img)
		m.albedo_texture = camo_tex
	mats[key] = m
	return m

func _mesh(parent: Node3D, size: Vector3, offset: Vector3, mat: Material) -> void:
	var mi = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = offset
	mi.layers = 2
	parent.add_child(mi)

static var helm_meshes = {}

static func _hm(key: String) -> Mesh:
	if helm_meshes.has(key):
		return helm_meshes[key]
	var m: Mesh
	match key:
		"dome":
			var sm = SphereMesh.new()
			sm.radius = 0.5
			sm.height = 0.5
			sm.is_hemisphere = true
			sm.radial_segments = 12
			sm.rings = 4
			m = sm
		"flare":
			var cm = CylinderMesh.new()
			cm.top_radius = 0.48
			cm.bottom_radius = 0.56
			cm.height = 1.0
			cm.radial_segments = 12
			cm.rings = 1
			m = cm
		_:
			var cy = CylinderMesh.new()
			cy.top_radius = 0.5
			cy.bottom_radius = 0.5
			cy.height = 1.0
			cy.radial_segments = 12
			cy.rings = 1
			m = cy
	helm_meshes[key] = m
	return m

func _hpart(parent: Node3D, key: String, sc: Vector3, at: Vector3, mat: Material) -> void:
	var mi = MeshInstance3D.new()
	mi.mesh = _hm(key)
	mi.scale = sc
	mi.position = at
	mi.material_override = mat
	mi.layers = 2
	parent.add_child(mi)

# each team wears a differently shaped helmet, with a band in the team colour
func _helmet(head: Node3D, helm: Material, band: Material, cloth: Material) -> void:
	match team % 4:
		0:  # round dome with a narrow rim
			_hpart(head, "dome", Vector3(0.33, 0.5, 0.35), Vector3(0, 0.07, 0), helm)
			_hpart(head, "cyl", Vector3(0.37, 0.025, 0.39), Vector3(0, 0.07, 0), helm)
		1:  # deep helmet flaring out over the neck and ears
			_hpart(head, "dome", Vector3(0.32, 0.5, 0.34), Vector3(0, 0.08, 0), helm)
			_hpart(head, "flare", Vector3(0.33, 0.1, 0.35), Vector3(0, 0.035, -0.015), helm)
		2:  # shallow bowl with a wide flat brim
			_hpart(head, "dome", Vector3(0.28, 0.38, 0.3), Vector3(0, 0.08, 0), helm)
			_hpart(head, "cyl", Vector3(0.44, 0.022, 0.46), Vector3(0, 0.075, 0), helm)
		_:  # soft field cap with a brim
			_hpart(head, "cyl", Vector3(0.29, 0.13, 0.3), Vector3(0, 0.13, 0), cloth)
			_hpart(head, "cyl", Vector3(0.4, 0.02, 0.42), Vector3(0, 0.075, 0), cloth)
	_hpart(head, "cyl", Vector3(0.335, 0.035, 0.355), Vector3(0, 0.09, 0), band)

func _build_body() -> void:
	_compute_targets()
	var uni = _mat("uni" + G.TEAM_UNI[team].to_html(), G.TEAM_UNI[team], true)
	var uni2 = _mat("uni2" + G.TEAM_UNI2[team].to_html(), G.TEAM_UNI2[team], true)
	var vest = _mat("vest" + G.TEAM_VEST[team].to_html(), G.TEAM_VEST[team], true)
	var helm = _mat("helm" + G.TEAM_HELM[team].to_html(), G.TEAM_HELM[team], false)
	var band = _mat("band" + G.TEAM_BAND[team].to_html(), G.TEAM_BAND[team], false)
	var sk = _mat("skin" + skin.to_html(false), skin, false)
	if zombie:
		# torn, filthy clothes and no helmet
		var rag = [Color(0.55, 0.5, 0.42), Color(0.62, 0.58, 0.5), Color(0.45, 0.48, 0.52), Color(0.58, 0.47, 0.4)][id % 4]
		uni = _mat("zuni" + str(id % 4), rag, false)
		uni2 = _mat("zuni2" + str(id % 3), rag.darkened(0.25 + 0.1 * (id % 3)), false)
		vest = _mat("zvest" + str(id % 4), rag.darkened(0.15).lerp(Color(0.35, 0.1, 0.08), 0.25), false)
	var boot = _mat("boot", Color(0.16, 0.14, 0.12), false)
	for i in range(11):
		var b = RigidBody3D.new()
		b.collision_layer = G.L_BODY
		b.collision_mask = G.L_WORLD | G.L_BODY | G.L_DEBRIS | G.L_VEH
		b.mass = PART_MASS[i]
		b.can_sleep = false
		b.linear_damp = 0.1
		b.angular_damp = 1.0
		var cs = CollisionShape3D.new()
		var bs = BoxShape3D.new()
		bs.size = Vector3(PART_W[i], PART_H[i], PART_D[i])
		cs.shape = bs
		b.add_child(cs)
		b.set_meta("soldier", self)
		b.set_meta("part", i)
		add_child(b)
		b.global_transform = targets[i]
		parts.append(b)
		rids.append(b.get_rid())
	# visuals
	_mesh(parts[0], Vector3(0.36, 0.22, 0.25), Vector3.ZERO, uni2)
	_mesh(parts[1], Vector3(0.42, 0.52, 0.24), Vector3.ZERO, uni)
	_mesh(parts[1], Vector3(0.46, 0.32, 0.3), Vector3(0, 0.06, 0), vest)
	_mesh(parts[1], Vector3(0.32, 0.3, 0.14), Vector3(0, 0.05, 0.19), vest)
	_mesh(parts[2], Vector3(0.25, 0.26, 0.25), Vector3.ZERO, sk)
	if not zombie:
		_helmet(parts[2], helm, band, uni)
	for i in [3, 5]:
		_mesh(parts[i], Vector3(0.13, 0.32, 0.13), Vector3.ZERO, uni)
	_mesh(parts[3], Vector3(0.15, 0.08, 0.15), Vector3(0, -0.03, 0), band)
	for i in [4, 6]:
		_mesh(parts[i], Vector3(0.12, 0.3, 0.12), Vector3(0, -0.02, 0), uni)
		_mesh(parts[i], Vector3(0.1, 0.11, 0.1), Vector3(0, 0.15, 0), sk)
	for i in [7, 9]:
		_mesh(parts[i], Vector3(0.17, 0.47, 0.17), Vector3.ZERO, uni2)
	for i in [8, 10]:
		_mesh(parts[i], Vector3(0.15, 0.45, 0.15), Vector3.ZERO, uni2)
		_mesh(parts[i], Vector3(0.16, 0.14, 0.28), Vector3(0, 0.21, 0.07), boot)
	# no collisions within the same body (joints and muscles handle that)
	for i in range(11):
		for j in range(i + 1, 11):
			parts[i].add_collision_exception_with(parts[j])
	# joints
	var right = (P[6] - P[3]).normalized()
	var up = (P[1] - P[2]).normalized()
	_cone(0, 1, P[2] + up * 0.1, up, 0.5, 0.4)
	_cone(1, 2, P[1], up, 0.6, 0.8)
	_cone(1, 3, P[3], (P[4] - P[3]).normalized(), 1.7, 1.0)
	_cone(1, 5, P[6], (P[7] - P[6]).normalized(), 1.7, 1.0)
	_cone(0, 7, P[9], (P[10] - P[9]).normalized(), 1.2, 0.35)
	_cone(0, 9, P[12], (P[13] - P[12]).normalized(), 1.2, 0.35)
	_hinge(3, 4, P[4], right, -1.4 * G.ELBOW_SIGN, 1.4 * G.ELBOW_SIGN)
	_hinge(5, 6, P[7], right, -1.4 * G.ELBOW_SIGN, 1.4 * G.ELBOW_SIGN)
	_hinge(7, 8, P[10], right, -2.3 * G.KNEE_SIGN, 0.05 * G.KNEE_SIGN)
	_hinge(9, 10, P[13], right, -2.3 * G.KNEE_SIGN, 0.05 * G.KNEE_SIGN)

func _basis_x(axis: Vector3) -> Basis:
	var x = axis.normalized()
	var y = Vector3.UP if absf(x.dot(Vector3.UP)) < 0.9 else Vector3.FORWARD
	y = (y - x * y.dot(x)).normalized()
	return Basis(x, y, x.cross(y))

func _cone(a: int, b: int, at: Vector3, axis: Vector3, swing: float, twist: float) -> void:
	var j = ConeTwistJoint3D.new()
	add_child(j)
	j.global_transform = Transform3D(_basis_x(axis), at)
	j.node_a = j.get_path_to(parts[a])
	j.node_b = j.get_path_to(parts[b])
	j.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, swing)
	j.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, twist)

func _hinge(a: int, b: int, at: Vector3, axis: Vector3, lo: float, hi: float) -> void:
	var j = HingeJoint3D.new()
	add_child(j)
	var z = axis.normalized()
	var y = Vector3.UP if absf(z.dot(Vector3.UP)) < 0.9 else Vector3.FORWARD
	y = (y - z * y.dot(z)).normalized()
	j.global_transform = Transform3D(Basis(y.cross(z), y, z), at)
	j.node_a = j.get_path_to(parts[a])
	j.node_b = j.get_path_to(parts[b])
	j.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
	j.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, minf(lo, hi))
	j.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, maxf(lo, hi))

func _build_gun() -> void:
	gun_node = Node3D.new()
	add_child(gun_node)
	_fill_gun()

func _fill_gun() -> void:
	for c in gun_node.get_children():
		gun_node.remove_child(c)
		c.queue_free()
	var i = 0
	for p in G.GUN_MODELS[wid]:
		var mi = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(p[3], p[4], p[5])
		mi.mesh = bm
		mi.material_override = _mat("gun" + p[6].to_html(false), p[6], false)
		mi.position = Vector3(p[0], p[1], p[2])
		mi.layers = 2
		mi.name = "p%d" % i
		gun_node.add_child(mi)
		i += 1

func set_weapon(new_id: String) -> void:
	wid = new_id
	W = G.WEAPONS[new_id]
	mag = W["mag"]
	reserve = W["mag"] * W["mags"]
	reload_t = 0.0
	fire_cd = 0.3
	burst = 0
	_fill_gun()

# ---------------------------------------------------------------- pose generation
func _ik(a: Vector3, c: Vector3, L1: float, L2: float, hint: Vector3) -> Vector3:
	var d = c - a
	var ln = d.length()
	if ln < 1e-5:
		return a + hint * L1
	d /= ln
	ln = minf(ln, L1 + L2 - 0.002)
	var x = (L1 * L1 - L2 * L2 + ln * ln) / (2.0 * ln)
	var h = sqrt(maxf(0.0, L1 * L1 - x * x))
	var perp = hint - d * hint.dot(d)
	if perp.length() > 1e-5:
		perp = perp.normalized()
	else:
		perp = Vector3.ZERO
	return a + d * x + perp * h

func _reach(from: Vector3, to: Vector3, max_l: float) -> Vector3:
	var d = to - from
	var l = d.length()
	if l > max_l:
		return from + d * (max_l / l)
	return to

func _aim_vector(t: float, spd: float) -> Vector3:
	var amp = 0.006 + spd * 0.003 + supp * 0.012
	var sy = aim_yaw + (sin(t * 1.1) * 0.6 + sin(t * 2.3) * 0.4) * amp
	var sp = aim_pitch + (sin(t * 1.4 + 1.0) * 0.6 + sin(t * 2.9) * 0.4) * amp
	var cp = cos(sp)
	return Vector3(sin(sy) * cp, sin(sp), cos(sy) * cp)

# show the hammer and put the gun away while building, and the other way round after
func _tool_visuals() -> void:
	var want = tool_mode == "hammer" and state == "alive"
	if want and hammer == null:
		hammer = Node3D.new()
		var handle = MeshInstance3D.new()
		var hm = CylinderMesh.new()
		hm.top_radius = 0.018
		hm.bottom_radius = 0.022
		hm.height = 0.34
		hm.radial_segments = 6
		handle.mesh = hm
		handle.material_override = _mat("hhandle", Color(0.45, 0.32, 0.18), false)
		handle.rotation.x = PI / 2.0
		handle.position = Vector3(0, 0, 0.12)
		hammer.add_child(handle)
		var head = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(0.05, 0.16, 0.06)
		head.mesh = bm
		head.material_override = _mat("hhead", Color(0.25, 0.25, 0.26), false)
		head.position = Vector3(0, 0.03, 0.28)
		hammer.add_child(head)
		parts[6].add_child(hammer)
		hammer.position = Vector3(0, 0.17, 0)
	if hammer != null:
		hammer.visible = want
	if gun_node != null and vehicle == null and gun_body == null:
		gun_node.visible = not want

# veterans wear stripes on the left sleeve
func set_vet(n: int) -> void:
	vet = clampi(n, 0, 3)
	if parts.size() < 4:
		return
	var m = _mat("band" + G.TEAM_BAND[team].to_html(), G.TEAM_BAND[team], false)
	for k in range(vet):
		var mi = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(0.145, 0.025, 0.145)
		mi.mesh = bm
		mi.material_override = m
		mi.position = Vector3(0, 0.1 - k * 0.045, 0)
		mi.layers = 2
		parts[3].add_child(mi)

func set_crate(on: bool) -> void:
	crate = on
	if on and crate_mesh == null and parts.size() > 1:
		crate_mesh = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(0.55, 0.32, 0.36)
		crate_mesh.mesh = bm
		crate_mesh.material_override = _mat("crate", Color(0.3, 0.33, 0.2), false)
		parts[1].add_child(crate_mesh)
		crate_mesh.position = Vector3(0, -0.1, 0.32)
	if crate_mesh != null:
		crate_mesh.visible = on

func _show_mag(on: bool) -> void:
	if on and mag_mesh == null and parts.size() > 4:
		mag_mesh = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(0.05, 0.16, 0.08)
		mag_mesh.mesh = bm
		mag_mesh.material_override = _mat("magz", Color(0.13, 0.13, 0.12), false)
		parts[4].add_child(mag_mesh)
		mag_mesh.position = Vector3(0, 0.22, 0.02)
		mag_mesh.rotation.x = 0.4
	if mag_mesh != null:
		mag_mesh.visible = on

func _arms_and_gun(spd: float, sprint: bool, uf: Vector3, ur: Vector3, aim: Vector3) -> void:
	if tool_mode != "" or (hammer != null and hammer.visible):
		_tool_visuals()
	if mag_mesh != null and mag_mesh.visible and reload_t <= 0.0:
		mag_mesh.visible = false
	var reloading = reload_t > 0.0
	var rk = 1.0 - reload_t / W["reload"] if reloading else 0.0
	var shoulder = ready_ and not reloading and not sprint and not gun_blocked and (ads or burst > 0 or fire_cd > -0.8 or prone)
	var g: Vector3
	if hand_t != null:
		g = Vector3(uf.x * 0.3, -0.85, uf.z * 0.3).normalized()
	elif gun_blocked and ready_:
		g = (aim * 0.3 + Vector3(0, 0.95, 0)).normalized()
	elif sprint:
		g = (uf * 0.3 - ur * 0.7 + Vector3(0, 0.6, 0)).normalized()
	elif reloading:
		g = (aim * 0.7 + Vector3(0, -0.45, 0) - ur * 0.25).normalized()
	elif ready_:
		g = aim
	else:
		g = uf * 0.55 - ur * 0.62
		g.y = 0.45
		g = g.normalized()
	var gd = Vector3(0, -1, 0) + g * g.y
	if gd.length_squared() < 1e-4:
		gd = uf
	gd = gd.normalized()
	var rsh: Vector3 = P[6]
	var lsh: Vector3 = P[3]
	var rh: Vector3
	var lh: Vector3
	if shoulder:
		rh = rsh + uf * 0.03 - ur * 0.06 + g * 0.24 + Vector3(0, 0.03, 0)
	elif ready_ or reloading or gun_blocked:
		rh = rsh + g * 0.27 - ur * 0.07 + Vector3(0, -0.09, 0)
	else:
		rh = rsh + uf * 0.2 - ur * 0.05 + Vector3(0, -0.3 + sin(phase * 2.0) * 0.02 * minf(spd, 3.0), 0)
	anchor_l = false
	if throw_t > 0.0:
		var k = 1.0 - throw_t / 0.55
		if k < 0.45:
			rh = rsh - uf * 0.32 + ur * 0.1 + Vector3(0, 0.2, 0)
		else:
			rh = rsh + uf * 0.45 + Vector3(0, 0.25 * (1.0 - k), 0)
		lh = lsh + uf * 0.22 + Vector3(0, -0.32, 0)
		g = (uf * 0.6 + ur * 0.5 + Vector3(0, -0.4, 0)).normalized()
		anchor_l = true
	elif hand_t != null and tool_mode == "hammer":
		# hammering: the right hand swings up and down, the left steadies the work
		var sw = sin(G.sim_time * 8.5 + seed_ * 3.0)
		rh = hand_t + ur * 0.1 + Vector3(0, 0.1 + 0.34 * maxf(sw, -0.25), 0) - uf * 0.12 * sw
		lh = hand_t - ur * 0.2 + uf * 0.05 + Vector3(0, -0.06, 0)
		if sw < -0.2 and not hammer_hit:
			hammer_hit = true
			if randf() < 0.6:
				G.audio.hammer(hand_t)
			if randf() < 0.15:
				G.fx.impact(hand_t, Vector3.UP)
		elif sw > 0.3:
			hammer_hit = false
	elif hand_t != null:
		rh = hand_t + ur * 0.13
		lh = hand_t - ur * 0.13
	elif reloading:
		var pm = rh + g * 0.13 + gd * 0.13
		var pp: Vector3 = P[1] + uf * 0.2 + Vector3(0, -0.28, 0)
		var home: Vector3 = rh + g * W["hold"]
		if rk < 0.25:
			lh = home.lerp(pm, rk / 0.25)
		elif rk < 0.55:
			lh = pm.lerp(pp, (rk - 0.25) / 0.3)
		elif rk < 0.85:
			lh = pp.lerp(pm, (rk - 0.55) / 0.3)
		else:
			lh = pm.lerp(home, (rk - 0.85) / 0.15)
		_show_mag(rk > 0.12 and rk < 0.88 and W["mag"] > 1 and not W["rocket"])
		if rk > 0.3 and not mag_drop:
			mag_drop = true
			if wid != "rpg":
				G.fx.debris(pm, Vector3(randf_range(-0.3, 0.3), -0.5, randf_range(-0.3, 0.3)), 0.1, G.C_DARK)
	else:
		lh = rh + g * W["hold"]
		# hurt and not shooting: one hand presses on the wound, the gun hangs from the other
		if wound_part >= 0 and hp < 60.0 and not shoulder and state == "alive" and wound_part != 4 and wound_part != 3:
			var wp: Vector3 = parts[wound_part].global_position
			lh = wp + uf * 0.08
			g = (uf * 0.4 - ur * 0.3 + Vector3(0, -0.6, 0)).normalized()
			anchor_l = false
	if not reloading:
		mag_drop = false
	gun_dir_p = g
	rh = _reach(rsh, rh, 0.59)
	lh = _reach(lsh, lh, 0.59)
	P[8] = rh
	P[5] = lh
	P[7] = _ik(rsh, rh, 0.3, 0.3, Vector3(0, -1, 0) + ur * 0.7)
	P[4] = _ik(lsh, lh, 0.3, 0.3, Vector3(0, -1, 0) - ur * 0.7)
	if shoulder:
		P[0] = P[0] + ur * 0.035 + uf * 0.02

func stand_pose() -> void:
	var c = crouch
	var spd = Vector2(vel.x, vel.z).length()
	var t = G.sim_time + seed_
	var fx = sin(body_yaw)
	var fz = cos(body_yaw)
	var f = Vector3(fx, 0, fz)
	var r = Vector3(-fz, 0, fx)
	var mlx = vel.dot(r)
	var mlz = vel.dot(f)
	var mn = 1.0 / spd if spd > 0.05 else 0.0
	var bob = absf(sin(phase)) * 0.035 * minf(spd / 3.0, 1.0)
	var breath = sin(t * 1.7) * 0.006
	var pY = 0.98 - 0.42 * c + bob * 0.5
	var gy = pos.y
	var base = Vector3(pos.x, gy, pos.z)
	P[2] = base + r * (lean * 0.05) + Vector3(0, pY, 0) + f * (-0.04 * c)
	P[9] = base + r * (-0.11 + lean * 0.05) + Vector3(0, pY - 0.05, 0) + f * (-0.04 * c)
	P[12] = base + r * (0.11 + lean * 0.05) + Vector3(0, pY - 0.05, 0) + f * (-0.04 * c)
	var sprint = not ready_ and spd > 4.6
	var al = 0.06 + 0.3 * c + minf(spd, 6.0) * 0.028 + (0.12 if sprint else 0.0) + breath
	var th = lean * 0.42
	var tw = clampf(G.wrap_a(aim_yaw - body_yaw), -1.1, 1.1)
	var uy = body_yaw + tw
	var uf = Vector3(sin(uy), 0, cos(uy))
	var ur = Vector3(-cos(uy), 0, sin(uy))
	var ca = cos(al)
	var sa = sin(al)
	var ct = cos(th)
	var st = sin(th)
	for i in [1, 0, 3, 6]:
		var R: Array = UPREF[i]
		var y1: float = R[1] * ca - R[2] * sa
		var z1: float = R[1] * sa + R[2] * ca
		var x2: float = R[0] * ct + y1 * st
		var y2: float = -R[0] * st + y1 * ct
		P[i] = P[2] + ur * x2 + uf * z1 + Vector3(0, y2 + breath, 0)
	if not ready_ and spd < 0.3:
		P[0] = P[0] + ur * (sin(t * 0.35) * 0.05)
	var A = minf(spd * 0.12, 0.45)
	var lmx = mlx * mn
	var lmz = mlz * mn
	if turning and spd < 0.3:
		A = 0.1; lmx = 1.0; lmz = 0.3
	if stumble > 0.0:
		A = maxf(A, 0.32); lmx = stumble_dir.dot(r); lmz = stumble_dir.dot(f)
	for side in range(2):
		var sd = 1.0 if side == 1 else -1.0
		var ph = phase + (PI if side == 1 else 0.0)
		var sw = sin(ph)
		var lift = maxf(0.0, cos(ph)) * A * 0.6
		var hi = 12 if side == 1 else 9
		var cz = -0.24 * c if side == 1 else 0.3 * c
		var foot = base + r * (sd * 0.13 + lmx * sw * A) + f * (lmz * sw * A + cz)
		if vault != null or vy < -0.5:
			foot.y = gy + 0.07 + lift
		else:
			foot.y = G.world.surface_y(foot.x, foot.z, gy + 0.3) + 0.07 + lift
		if side == 1 and kick_t > 0.0:
			var kk = sin(PI * (1.0 - kick_t / 0.38))
			foot = foot.lerp(base + kick_dir * 0.72 + r * 0.1 + Vector3(0, 0.5, 0), kk)
		foot = _reach(P[hi], foot, 0.88)
		P[hi + 2] = foot
		P[hi + 1] = _ik(P[hi], foot, 0.45, 0.45, f + r * (sd * 0.15))
	_arms_and_gun(spd, sprint, uf, ur, _aim_vector(t, spd))

func key_world(arr: Array, root: Vector3, yaw: float) -> Array:
	var f = Vector3(sin(yaw), 0, cos(yaw))
	var r = Vector3(-cos(yaw), 0, sin(yaw))
	var out: Array = []
	for k in arr:
		out.append(root + r * k[0] + Vector3(0, k[1], 0) + f * k[2])
	return out

func _follow_ground(pts: Array) -> void:
	var upstairs = pos.y - G.world.ground_y(pos.x, pos.z) > 0.5
	for i in range(pts.size()):
		if not upstairs:
			pts[i] = pts[i] + Vector3(0, G.world.ground_y(pts[i].x, pts[i].z) - pos.y, 0)

func prone_pose() -> void:
	var spd = Vector2(vel.x, vel.z).length()
	var pts = key_world(KF["PRONE"], pos, body_yaw)
	_follow_ground(pts)
	var f = Vector3(sin(body_yaw), 0, cos(body_yaw))
	var r = Vector3(-cos(body_yaw), 0, sin(body_yaw))
	if spd > 0.1:
		var k = sin(phase)
		pts[10] = pts[10] + r * (-0.12 * maxf(0.0, -k)) + f * (0.22 * maxf(0.0, -k))
		pts[13] = pts[13] + r * (0.12 * maxf(0.0, k)) + f * (0.22 * maxf(0.0, k))
	for i in range(15):
		P[i] = pts[i]
	_arms_and_gun(spd, false, f, r, _aim_vector(G.sim_time + seed_, spd))

func crawl_pose() -> void:
	var pts = key_world(KF["PRONE"], pos, body_yaw)
	_follow_ground(pts)
	var f = Vector3(sin(body_yaw), 0, cos(body_yaw))
	var r = Vector3(-cos(body_yaw), 0, sin(body_yaw))
	var k = sin(phase)
	pts[5] = pts[5] + f * (0.2 * k) + Vector3(0, 0.04 * maxf(0.0, k), 0)
	pts[4] = pts[4] + f * (0.1 * k) + Vector3(0, 0.03, 0)
	pts[8] = pts[8] - f * (0.2 * k) + Vector3(0, 0.04 * maxf(0.0, -k), 0)
	pts[7] = pts[7] - f * (0.1 * k) + Vector3(0, 0.03, 0)
	pts[10] = pts[10] + r * (-0.12 * maxf(0.0, -k)) + f * (0.22 * maxf(0.0, -k))
	pts[13] = pts[13] + r * (0.12 * maxf(0.0, k)) + f * (0.22 * maxf(0.0, k))
	pts[0] = pts[0] + Vector3(0, 0.06, 0)
	for i in range(15):
		P[i] = pts[i]

# ---------------------------------------------------------------- muscles
func _bone_xform(a: Vector3, b: Vector3, side: Vector3) -> Transform3D:
	var y = b - a
	if y.length_squared() < 1e-8:
		y = Vector3.UP
	y = y.normalized()
	var x = side - y * side.dot(y)
	if x.length_squared() < 1e-6:
		x = Vector3.RIGHT - y * y.x
	x = x.normalized()
	return Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5)

func _compute_targets() -> void:
	var right: Vector3 = (P[6] - P[3]).normalized()
	var up: Vector3 = P[1] - P[2]
	var tl = up.length()
	targets[1] = _bone_xform(P[2], P[1], right)
	targets[1].origin = P[2] + up * 0.55
	var hipmid: Vector3 = (P[9] + P[12]) * 0.5
	targets[0] = _bone_xform(P[2], P[1], (P[12] - P[9]).normalized())
	targets[0].origin = hipmid + up / maxf(tl, 0.001) * 0.03
	targets[2] = _bone_xform(P[1], P[0], right)
	targets[2].origin = P[0]
	for i in range(3, 11):
		targets[i] = _bone_xform(P[PART_SEG[i][0]], P[PART_SEG[i][1]], right)

var lod_frozen = false
var lod_n = 0
var kick_t = 0.0
var kick_dir = Vector3.FORWARD

# a boot to a door (or a window)
func kick(dir: Vector3) -> void:
	kick_t = 0.38
	kick_dir = dir
	stumble = 0.0

# far from the camera in a big battle, a healthy soldier's body just follows its pose
# instead of being simulated: the physics only runs for the people you can actually see
func _lod_far() -> bool:
	if G.soldiers.size() < 50 or is_player or state != "alive" or vault != null or dragging != null:
		return false
	var cam = get_viewport().get_camera_3d()
	var ld: float = G.settings["lod_dist"]
	return cam != null and cam.global_position.distance_squared_to(pos) > ld * ld

# back to a real simulated body (falling, dying, climbing aboard)
func lod_wake() -> void:
	if not lod_frozen:
		return
	lod_frozen = false
	for b in parts:
		b.freeze = false
		b.linear_velocity = vel

func drive() -> void:
	_compute_targets()
	if _lod_far():
		if not lod_frozen or not parts[0].freeze:
			lod_frozen = true
			for b in parts:
				b.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
				b.freeze = true
		for i in range(parts.size()):
			parts[i].global_transform = targets[i]
		return
	elif lod_frozen:
		lod_frozen = false
		if not hidden_in_vehicle:
			for b in parts:
				b.freeze = false
				b.linear_velocity = vel
	for i in range(parts.size()):
		var b: RigidBody3D = parts[i]
		var k: float = strength * PART_MUS[i] * limb[PART_REG[i]]
		if k < 0.002:
			continue
		var tg: Transform3D = targets[i]
		var dv: Vector3 = (tg.origin - b.global_position) / G.DT
		b.linear_velocity = b.linear_velocity.lerp(dv, minf(k * 1.2, 0.95))
		var q: Quaternion = tg.basis.get_rotation_quaternion() * b.global_basis.get_rotation_quaternion().inverse()
		if q.w < 0.0:
			q = -q
		var ang = q.get_angle()
		if ang > 0.001:
			var w = q.get_axis().normalized() * (ang / G.DT)
			b.angular_velocity = b.angular_velocity.lerp(w, minf(k, 0.9))

func set_sleepy(v: bool) -> void:
	for b in parts:
		b.can_sleep = v

func wake() -> void:
	for b in parts:
		b.sleeping = false

func push(part: int, impulse_v: Vector3, spread: float) -> void:
	for i in range(parts.size()):
		var b: RigidBody3D = parts[i]
		var w = 1.0 if i == part else spread
		b.apply_central_impulse(impulse_v * b.mass * w)

func part_pos(i: int) -> Vector3:
	return parts[i].global_position

func chest() -> Vector3:
	return parts[1].global_position

func head_pos() -> Vector3:
	return parts[2].global_position

# ---------------------------------------------------------------- classes
func set_class(c: String) -> void:
	cls = c
	if c == "officer" and parts.size() > 2:
		# officers wear a peaked cap instead of a helmet
		for m in parts[2].get_children():
			if m is MeshInstance3D and m.position.y > 0.05:
				m.visible = false
		var capm = _mat("cap", Color(0.42, 0.12, 0.1), false)
		_hpart(parts[2], "cyl", Vector3(0.3, 0.09, 0.31), Vector3(0, 0.12, 0), capm)
		_hpart(parts[2], "cyl", Vector3(0.36, 0.03, 0.37), Vector3(0, 0.17, 0.01), capm)
		_hpart(parts[2], "cyl", Vector3(0.2, 0.015, 0.14), Vector3(0, 0.075, 0.13), _mat("boot", Color(0.16, 0.14, 0.12), false))
		_hpart(parts[2], "cyl", Vector3(0.31, 0.03, 0.32), Vector3(0, 0.09, 0), _mat("band" + G.TEAM_BAND[team].to_html(), G.TEAM_BAND[team], false))
	mines = 3 if c == "engineer" else 0
	satchels = 2 if c == "engineer" else 0
	kits = 3 if c == "engineer" else 0
	stickies = 2 if c == "at" else (1 if c == "engineer" else 0)
	rgren = 3 if c == "rifleman" and wid == "rifle" else 0
	if c == "radio":
		smokes = 3
	if c == "at" and wid == "rpg":
		rockets = 4
	if c == "spotter" or c == "sniper":
		for o in G.soldiers:
			if o != self and o.team == team and o.state != "dead" and o.partner == null and ((c == "spotter" and o.cls == "sniper") or (c == "sniper" and o.cls == "spotter")):
				partner = o
				o.partner = self
				var sp = o if c == "sniper" else self
				var sn = self if c == "sniper" else o
				sp.order = {"mode": "follow", "who": sn, "point": null}
				break

# out of ammunition for the main gun: fall back on the pistol
func to_sidearm() -> bool:
	if wid == "pistol" or primary != null:
		return false
	primary = [wid, mag, reserve]
	set_weapon("pistol")
	return true

func from_sidearm() -> void:
	if primary == null:
		return
	set_weapon(primary[0])
	primary = null

# ---------------------------------------------------------------- ammunition
func start_reload() -> bool:
	if reload_t > 0.0 or mag >= W["mag"] or reserve <= 0:
		return false
	reload_t = W["reload"]
	return true

func finish_reload() -> void:
	var take = mini(W["mag"] - mag, reserve)
	mag += take
	reserve -= take

func ammo_frac() -> float:
	return float(mag + reserve) / float(W["mag"] * (W["mags"] + 1))

func resupply() -> void:
	from_sidearm()
	reserve = W["mag"] * W["mags"]
	if cls == "engineer":
		mines = maxi(mines, 3)
		satchels = maxi(satchels, 2)
		kits = maxi(kits, 3)
	grenades = maxi(grenades, 2)
	smokes = maxi(smokes, 1)
	if wid == "rpg":
		rockets = 3

# squad leaders carry a radio with a tall antenna so you can pick them out
func set_leader(v: bool) -> void:
	if zombie:
		return
	if rec != null:
		rec["leader"] = rec["leader"] or v
	if v and leader_mark == null and parts.size() > 1:
		leader_mark = Node3D.new()
		var box = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(0.2, 0.24, 0.1)
		box.mesh = bm
		box.material_override = _mat("radio", Color(0.2, 0.22, 0.17), false)
		box.layers = 2
		leader_mark.add_child(box)
		var ant = MeshInstance3D.new()
		var am = BoxMesh.new()
		am.size = Vector3(0.018, 0.75, 0.018)
		ant.mesh = am
		ant.material_override = _mat("antenna", Color(0.1, 0.1, 0.1), false)
		ant.position = Vector3(0.06, 0.45, 0)
		ant.layers = 2
		leader_mark.add_child(ant)
		leader_mark.position = Vector3(0, 0.08, -0.2)
		parts[1].add_child(leader_mark)
	elif not v and leader_mark != null:
		leader_mark.queue_free()
		leader_mark = null

func set_head_hidden(v: bool) -> void:
	if parts.size() < 3:
		return
	for c in parts[2].get_children():
		if c is MeshInstance3D:
			c.layers = 8 if v else 2

func is_up() -> bool:
	return state == "alive" or state == "riding"

# ---------------------------------------------------------------- weapon position
func hand_r() -> Vector3:
	return parts[6].global_transform * Vector3(0, 0.15, 0)

func hand_l() -> Vector3:
	return parts[4].global_transform * Vector3(0, 0.15, 0)

func compute_muzzle() -> void:
	if state == "dead":
		return
	if state == "alive":
		gun_dir = gun_dir_p
		# hold the gun where the pose wants the hands, carried by the real chest so it moves with the body
		# but doesn't flap around with the loosely driven arm bodies
		var pose_hand: Vector3 = P[5] - gun_dir * 0.3 if anchor_l else P[8]
		var steady: Vector3 = parts[1].global_position + (pose_hand - targets[1].origin)
		var phys: Vector3 = hand_l() - gun_dir * 0.3 if anchor_l else hand_r()
		grip = steady.lerp(phys, 0.15)
	else:
		var d = hand_l() - hand_r()
		if d.length() > 0.05:
			gun_dir = d.normalized()
		grip = hand_r()
	muzzle = grip + gun_dir * (W["len"] - 0.24)
	var u: Vector3 = (parts[1].global_basis.y)
	u = u - gun_dir * u.dot(gun_dir)
	if u.length_squared() < 1e-4:
		u = Vector3.UP - gun_dir * gun_dir.y
	u = u.normalized()
	var want_xf = Transform3D(Basis(u.cross(gun_dir), u, gun_dir), grip)
	if state == "alive" and not is_player:
		# AI hands wobble with the ragdoll; ease the gun toward where it should be so it doesn't shake
		var cur: Transform3D = gun_node.global_transform
		if cur.origin.distance_to(grip) < 0.6:
			var q0 = cur.basis.get_rotation_quaternion()
			var q1 = want_xf.basis.get_rotation_quaternion()
			want_xf = Transform3D(Basis(q0.slerp(q1, 0.3)), cur.origin.lerp(grip, 0.35))
	gun_node.global_transform = want_xf
	var head = gun_node.get_node_or_null("p1")
	if wid == "rpg" and head:
		head.visible = mag > 0

func check_gun_clip() -> void:
	if state != "alive" or prone:
		gun_blocked = false
		return
	if (Engine.get_physics_frames() + id) % 3 != 0:
		return
	var a = _aim_vector(G.sim_time + seed_, 0.0)
	var L: float = W["len"] + 0.12
	var from: Vector3 = parts[5].global_position + Vector3(0, 0.05, 0)
	gun_blocked = not G.ray(from, from + a * L, G.L_WORLD).is_empty()

func drop_gun() -> void:
	if gun_body != null:
		return
	gun_body = RigidBody3D.new()
	gun_body.collision_layer = G.L_DEBRIS
	gun_body.collision_mask = G.L_WORLD | G.L_DEBRIS
	gun_body.mass = 4.0
	var cs = CollisionShape3D.new()
	var bs = BoxShape3D.new()
	bs.size = Vector3(0.08, 0.12, W["len"])
	cs.shape = bs
	cs.position = Vector3(0, 0, W["len"] / 2.0 - 0.24)
	gun_body.add_child(cs)
	add_child(gun_body)
	gun_body.global_transform = gun_node.global_transform
	gun_body.linear_velocity = parts[6].linear_velocity
	gun_node.reparent(gun_body, true)

# ---------------------------------------------------------------- state changes
func fall(t: float = -1.0) -> void:
	if state == "dead":
		return
	if vehicle != null:
		dismount(true)
	if state == "chute":
		_drop_chute()
	if state == "alive" or state == "getup":
		AI.release_cover(self)
		path = []
		move_target = null
	if dragging:
		dragging.dragger = null
		dragging = null
	lod_wake()
	state = "down"
	strength = 0.0
	down_t = t if t > 0.0 else randf_range(1.2, 2.2)
	gu = null; ads = false; task = null; flee = null; prone = false; prone_t = false; vault = null; hand_t = null; throw_t = 0.0; route = null; vy = 0.0

func go_dead() -> void:
	if vehicle != null:
		dismount(true)
	if state == "chute":
		_drop_chute()
	if state != "dead":
		compute_muzzle()
		drop_gun()
	AI.release_cover(self)
	path = []
	move_target = null
	route = null
	if dragging:
		dragging.dragger = null
		dragging = null
	if dragger and is_instance_valid(dragger):
		dragger.dragging = null
		dragger = null
	if carrying != null and is_instance_valid(carrying):
		carrying.carried_by = null
	carrying = null
	set_crate(false)
	lod_wake()
	state = "dead"
	strength = 0.0
	dead_t = 0.0
	gu = null; task = null; flee = null; hand_t = null; vault = null; prone = false; prone_t = false
	if medic and is_instance_valid(medic):
		medic.task = null
		medic.patient = null
		medic.hand_t = null
	medic = null
	if patient and is_instance_valid(patient):
		patient.medic = null
	patient = null
	set_sleepy(true)

func torso_facing_up() -> bool:
	return parts[1].global_basis.z.y < -0.05

func start_getup() -> void:
	var pel: Vector3 = parts[0].global_position
	pos = Vector3(pel.x, 0, pel.z)
	pos.y = G.world.surface_y(pos.x, pos.z, pel.y)
	pos = G.world.push_out_circle(pos, 0.35)[0]
	var up = torso_facing_up()
	var yaw: float
	if up:
		var feet: Vector3 = (parts[8].global_position + parts[10].global_position) * 0.5 - pel
		yaw = atan2(feet.x, feet.z)
	else:
		var hd: Vector3 = parts[2].global_position - pel
		yaw = atan2(hd.x, hd.z)
	body_yaw = yaw
	aim_yaw = yaw
	aim_pitch = 0.0
	vel = Vector3.ZERO
	vy = 0.0
	var snap: Array = []
	var f = Vector3(sin(yaw), 0, cos(yaw))
	var r = Vector3(-cos(yaw), 0, sin(yaw))
	# where each pose point currently is, relative to the new root
	var cur = [parts[2].global_position, parts[1].global_position + parts[1].global_basis.y * 0.26, pel,
		parts[3].global_transform * Vector3(0, -0.15, 0), parts[3].global_transform * Vector3(0, 0.15, 0), hand_l(),
		parts[5].global_transform * Vector3(0, -0.15, 0), parts[5].global_transform * Vector3(0, 0.15, 0), hand_r(),
		parts[7].global_transform * Vector3(0, -0.22, 0), parts[7].global_transform * Vector3(0, 0.22, 0), parts[8].global_transform * Vector3(0, 0.22, 0),
		parts[9].global_transform * Vector3(0, -0.22, 0), parts[9].global_transform * Vector3(0, 0.22, 0), parts[10].global_transform * Vector3(0, 0.22, 0)]
	for p in cur:
		var d: Vector3 = p - pos
		snap.append([d.dot(r), d.y, d.dot(f)])
	gu = {"seq": SEQ_UP if up else SEQ_DOWN, "i": 0, "t": 0.0, "root": pos, "yaw": yaw, "snap": snap}
	state = "getup"
	stumble = 0.0
	lean = 0.0
	lean_t = 0.0
	set_sleepy(false)

func make_wounded() -> void:
	state = "wounded"
	strength = 0.18
	crawl_target = null
	heal_t = 0.0
	phase = 0.0
	var pel: Vector3 = parts[0].global_position
	var hd: Vector3 = parts[2].global_position - pel
	body_yaw = atan2(hd.x, hd.z)
	pos = Vector3(pel.x, 0, pel.z)
	pos.y = G.world.surface_y(pos.x, pos.z, pel.y)
	G.fx.callout(self, "Medic!")

func start_vault(c) -> bool:
	var thin_x: bool = (c.hi.x - c.lo.x) < (c.hi.z - c.lo.z)
	var wl = Vector2(want.x, want.z).length()
	if wl < 1.3:
		return false
	var tx = pos.x
	var tz = pos.z
	if thin_x:
		if absf(want.x) < wl * 0.55:
			return false
		tx = c.hi.x + 0.45 if want.x > 0.0 else c.lo.x - 0.45
	else:
		if absf(want.z) < wl * 0.55:
			return false
		tz = c.hi.z + 0.45 if want.z > 0.0 else c.lo.z - 0.45
	var ty: float = G.world.surface_y(tx, tz, pos.y + 0.5)
	if G.world.inside_any(tx, tz, 0.3, ty) or absf(ty - pos.y) > 0.9:
		return false
	vault = {"a": pos, "b": Vector3(tx, ty, tz), "h": maxf(0.2, c.hi.y - maxf(pos.y, ty) + 0.15), "t": 0.0}
	return true

# ---------------------------------------------------------------- per-tick update
static var beam_mat: StandardMaterial3D = null

# a torch clipped under the barrel: a faint beam you can see, and a real light for the nearest few
func _flashlight_tick() -> void:
	var want = light_on and (state == "alive" or state == "riding") and gun_node != null and gun_node.visible and vehicle == null
	if want and flashlight == null:
		flashlight = Node3D.new()
		gun_node.add_child(flashlight)
		flashlight.position = Vector3(0.05, -0.04, 0.45)
		var body = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		cm.top_radius = 0.035
		cm.bottom_radius = 0.03
		cm.height = 0.14
		cm.radial_segments = 8
		body.mesh = cm
		body.rotation.x = PI / 2.0
		body.material_override = _mat("torch", Color(0.12, 0.12, 0.12), false)
		flashlight.add_child(body)
		if beam_mat == null:
			beam_mat = StandardMaterial3D.new()
			beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			beam_mat.albedo_color = Color(1.0, 0.95, 0.75, 0.07)
		var beam = MeshInstance3D.new()
		var bm = CylinderMesh.new()
		bm.top_radius = 1.4
		bm.bottom_radius = 0.04
		bm.height = 9.0
		bm.radial_segments = 10
		bm.cap_top = false
		bm.cap_bottom = false
		beam.mesh = bm
		beam.rotation.x = PI / 2.0
		beam.position = Vector3(0, 0, 4.6)
		beam.material_override = beam_mat
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flashlight.add_child(beam)
	if flashlight != null:
		flashlight.visible = want

var glint: MeshInstance3D = null
var mag_mesh: MeshInstance3D = null

# snipers' scopes flash in the sun when they're pointed your way
func _glint_tick() -> void:
	var cam = get_viewport().get_camera_3d()
	if cam == null or gun_node == null:
		return
	if glint == null:
		glint = MeshInstance3D.new()
		var q = QuadMesh.new()
		q.size = Vector2(0.5, 0.5)
		glint.mesh = q
		var m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.albedo_texture = G.fx.soft_tex
		m.albedo_color = Color(1.0, 0.97, 0.85, 1.0)
		m.no_depth_test = false
		glint.material_override = m
		glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gun_node.add_child(glint)
		glint.position = Vector3(0, 0.09, 0.25)
	var to_cam = (cam.global_position - muzzle).normalized()
	var facing = gun_dir.dot(to_cam)
	var show = state == "alive" and ready_ and not G.main.is_night() and facing > 0.93 and not is_player
	glint.visible = show
	if show:
		var k = (facing - 0.93) / 0.07
		var d = cam.global_position.distance_to(muzzle)
		glint.scale = Vector3.ONE * clampf(d / 25.0, 0.6, 5.0) * (0.4 + k) * (0.85 + 0.3 * sin(G.sim_time * 9.0))

func tick() -> void:
	if heat > 0.0:
		heat = maxf(0.0, heat - 0.16 * G.DT)
	if cls == "sniper" and wid == "sniper":
		_glint_tick()
	elif glint != null:
		glint.visible = false
	if light_on or flashlight != null:
		_flashlight_tick()
	callout_cd -= G.DT
	hurt_t -= G.DT
	if burn_t > 0.0 and state != "dead":
		_burn()
	match state:
		"dead":
			dead_t += G.DT
			if not pooled and dead_t > 1.2:
				pooled = true
				G.fx.decal(parts[0].global_position, randf_range(1.0, 1.6), false)
		"down":
			_tick_down()
		"getup":
			_tick_getup()
		"wounded":
			_tick_wounded()
		"alive":
			_tick_alive()
		"riding":
			_tick_riding()
		"chute":
			_tick_chute()
	if state != "dead" and not hidden_in_vehicle and (not lod_frozen or lod_n % 2 == 0):
		compute_muzzle()

func _tick_down() -> void:
	supp = maxf(0.0, supp - 0.3 * G.DT)
	down_t -= G.DT
	if down_t <= 0.0 and parts[0].linear_velocity.length() < 1.2:
		if hp < 35.0 and randf() < 0.65:
			make_wounded()
		else:
			start_getup()

func _tick_getup() -> void:
	var step: Array = gu["seq"][gu["i"]]
	gu["t"] += G.DT / step[1]
	var k = G.smooth01(gu["t"])
	var from: Array
	if gu["i"] == 0:
		from = key_world(gu["snap"], gu["root"], gu["yaw"])
	else:
		from = key_world(KF[gu["seq"][gu["i"] - 1][0]], gu["root"], gu["yaw"])
	if step[0] == "STAND":
		pos = gu["root"]
		body_yaw = gu["yaw"]
		aim_yaw = body_yaw
		crouch = 0.75
		vel = Vector3.ZERO
		ready_ = false
		lean = 0.0
		reload_t = 0.0
		stand_pose()
		for i in range(15):
			P[i] = from[i].lerp(P[i], k)
	else:
		var to = key_world(KF[step[0]], gu["root"], gu["yaw"])
		for i in range(15):
			P[i] = from[i].lerp(to[i], k)
	var prev_str: float = gu["seq"][gu["i"] - 1][2] if gu["i"] > 0 else 0.08
	strength = lerpf(prev_str, step[2], k)
	drive()
	if gu["t"] >= 1.0:
		gu["i"] += 1
		gu["t"] = 0.0
		if gu["i"] >= gu["seq"].size():
			state = "alive"
			gu = null
			crouch = 0.75
			crouch_t = 0.75
			strength = 0.42
			think = 0.0
			decide_t = 0.0

func _tick_wounded() -> void:
	if not has_meta("pilot"):
		hp -= 0.45 * G.DT
	supp = maxf(0.0, supp - 0.3 * G.DT)
	if hp <= 0.0:
		Combat.kill(self, last_attacker, false)
		return
	if randf() < 0.004:
		G.fx.callout(self, G.pick(["Medic!", "I'm hit!", "Help!"]))
	if carried_by != null and is_instance_valid(carried_by) and carried_by.state == "alive" and carried_by.carrying == self:
		# slung over a shoulder in a fireman's carry
		crawl_pose()
		strength = 0.02
		drive()
		var cy = carried_by.body_yaw
		var back = -Vector3(sin(cy), 0, cos(cy))
		var side = Vector3(cos(cy), 0, -sin(cy))
		var sh: Vector3 = carried_by.chest() + Vector3(0, 0.3, 0) + side * 0.12
		for i in range(parts.size()):
			var t = sh
			if i in [1, 2, 3, 4, 5, 6]:
				t = sh + back * 0.35 + Vector3(0, -0.35 - (0.25 if i in [2, 4, 6] else 0.0), 0)
			elif i != 0:
				t = sh - back * 0.3 + Vector3(0, -0.3 - (0.3 if i in [8, 10] else 0.0), 0)
			var b: RigidBody3D = parts[i]
			b.linear_velocity = b.linear_velocity.lerp((t - b.global_position) / G.DT * 0.25, 0.7)
		pos = carried_by.pos
		return
	elif carried_by != null:
		carried_by = null
	if dragger != null and is_instance_valid(dragger) and dragger.state == "alive":
		crawl_pose()
		strength = 0.02
		drive()
		var hand: Vector3 = (dragger.hand_l() + dragger.hand_r()) * 0.5
		for i in [1, 3, 5]:
			var b: RigidBody3D = parts[i]
			b.linear_velocity = b.linear_velocity.lerp((hand - b.global_position) / G.DT * 0.3, 0.6)
		var pel: Vector3 = parts[0].global_position
		pos = Vector3(pel.x, G.world.surface_y(pel.x, pel.z, pel.y), pel.z)
		var hd: Vector3 = parts[2].global_position - pel
		body_yaw = atan2(hd.x, hd.z)
		return
	dragger = null
	if crawl_target == null or pos.distance_to(crawl_target) < 0.5:
		var best = null
		var bd = 1e9
		for cp in G.world.cover_near(pos, 10.0):
			if cp.upper:
				continue
			var d: float = cp.p.distance_to(pos)
			if d < 10.0 and d > 0.8 and d < bd and (not has_threat or cp.p.distance_to(threat) > pos.distance_to(threat) - 2.0):
				bd = d
				best = cp
		crawl_target = best.p if best and randf() < 0.85 else null
	want = Vector3.ZERO
	if crawl_target != null and heal_t <= 0.0 and medic == null:
		var d3: Vector3 = G.flat(crawl_target - pos)
		var d = d3.length()
		if d > 0.4:
			d3 /= d
			pos += d3 * 0.45 * G.DT
			body_yaw = G.turn_to(body_yaw, atan2(d3.x, d3.z), 2.0 * G.DT)
			phase += 4.0 * G.DT
			pos = G.world.push_out_circle(pos, 0.3)[0]
			pos.y = G.world.surface_y(pos.x, pos.z, pos.y)
	crawl_pose()
	strength = 0.18
	drive()
	if heal_t >= 3.0:
		hp = 50.0
		heal_t = 0.0
		if medic and is_instance_valid(medic):
			medic.task = null
			medic.patient = null
			medic.hand_t = null
		medic = null
		start_getup()
		G.fx.callout(self, "Thanks!")

func _tick_alive() -> void:
	supp = maxf(0.0, supp - 0.3 * G.DT)
	radio_cd = maxf(0.0, radio_cd - G.DT) if is_player else radio_cd
	stun = maxf(0.0, stun - G.DT)
	throw_t = maxf(0.0, throw_t - G.DT)
	for r in range(5):
		limb[r] = minf(1.0, limb[r] + 1.1 * G.DT)
	if is_player:
		G.pc.player_update(self)
	else:
		AI.update(self)
	if state != "alive":
		return
	var sm: float = W["speed"] * (0.3 if prone else 1.0)
	var wading = not G.world.water.is_empty() and G.world.in_water(pos.x, pos.z)
	if wading:
		sm *= 0.4
		prone_t = false
	if vault != null:
		vault["t"] += G.DT / 0.6
		var k = G.smooth01(vault["t"])
		var a: Vector3 = vault["a"]
		var b: Vector3 = vault["b"]
		pos = a.lerp(b, k)
		pos.y += sin(PI * minf(1.0, vault["t"])) * vault["h"]
		vel = G.flat(b - a) / 0.6
		crouch = 0.55
		if vault["t"] >= 1.0:
			pos = b
			vault = null
	else:
		vel.x += clampf(want.x * sm - vel.x, -12.0 * G.DT, 12.0 * G.DT)
		vel.z += clampf(want.z * sm - vel.z, -12.0 * G.DT, 12.0 * G.DT)
		pos.x += vel.x * G.DT
		pos.z += vel.z * G.DT
		for o in G.soldiers_near(pos):
			if o == self or o.state != "alive" or absf(o.pos.y - pos.y) > 1.0:
				continue
			var dx: float = pos.x - o.pos.x
			var dz: float = pos.z - o.pos.z
			var d2 = dx * dx + dz * dz
			if d2 < 0.5 and d2 > 1e-6:
				var d = sqrt(d2)
				var pushv = (0.71 - d) * 0.5
				pos.x += dx / d * pushv
				pos.z += dz / d * pushv
		var res: Array = G.world.push_out_circle(pos, 0.33)
		pos = res[0]
		var hit = res[1]
		if hit != null and not prone and vy == 0.0 and dragging == null and G.world.vaultable(hit):
			start_vault(hit)
		# keep clear of vehicles
		for v in G.vehicles:
			if absf(pos.x - v.pos.x) > 9.0 or absf(pos.z - v.pos.z) > 9.0:
				continue
			var rel = G.flat(pos - v.pos)
			var vf = v.forward()
			var vl = Vector3(vf.z, 0, -vf.x)
			var a = rel.dot(vf)
			var bb = rel.dot(vl)
			var hl = v.spec["len"] * 0.5 + 0.3
			var hw = v.spec["wid"] * 0.5 + 0.3
			if absf(a) < hl and absf(bb) < hw and absf(pos.y - v.pos.y) < 2.5:
				if hl - absf(a) < hw - absf(bb):
					pos += vf * (hl - absf(a)) * signf(a if a != 0.0 else 1.0)
				else:
					pos += vl * (hw - absf(bb)) * signf(bb if bb != 0.0 else 1.0)
		var bnd: Rect2 = G.world.bounds
		pos.x = clampf(pos.x, bnd.position.x, bnd.end.x)
		pos.z = clampf(pos.z, bnd.position.y, bnd.end.y)
		var sy: float = G.world.surface_y(pos.x, pos.z, pos.y)
		if sy >= pos.y - 0.06 and vy >= 0.0:
			pos.y = minf(sy, pos.y + 8.0 * G.DT) if sy > pos.y else sy
			vy = 0.0
		else:
			vy += G.GRAV * G.DT
			pos.y += vy * G.DT
			if pos.y <= sy:
				var v = -vy
				pos.y = sy
				vy = 0.0
				if v > 7.5:
					fall(2.2)
					hp -= (v - 7.0) * 12.0
					if hp <= 0.0:
						Combat.kill(self, null, false)
					return
	crouch += clampf(crouch_t - crouch, -3.5 * G.DT, 3.5 * G.DT)
	lean += clampf((0.0 if prone else lean_t) - lean, -4.0 * G.DT, 4.0 * G.DT)
	prone = prone_t and vault == null and dragging == null
	var spd = Vector2(vel.x, vel.z).length()
	if prone:
		body_yaw = G.turn_to(body_yaw, aim_yaw, 1.6 * G.DT)
		aim_yaw = body_yaw + clampf(G.wrap_a(aim_yaw - body_yaw), -0.45, 0.45)
		aim_pitch = clampf(aim_pitch, -0.3, 0.35)
	elif spd > 0.6 and dragging == null:
		var my = atan2(vel.x, vel.z)
		var rel = G.wrap_a(my - aim_yaw)
		var goal = aim_yaw + rel * 0.5 if absf(rel) < 1.3 else aim_yaw
		body_yaw = G.turn_to(body_yaw, goal, 6.0 * G.DT)
		turning = false
	else:
		var dd = G.wrap_a(aim_yaw - body_yaw)
		if absf(dd) > 0.8:
			turning = true
		if turning or dragging != null:
			body_yaw = G.turn_to(body_yaw, aim_yaw, 3.2 * G.DT)
			if absf(dd) < 0.12:
				turning = false
	var ph0 = sin(phase)
	phase += (spd * (5.0 if prone else 2.3) + (6.0 if turning else 0.0) + (9.0 if stumble > 0.0 else 0.0)) * G.DT
	if ph0 * sin(phase) < 0.0 and (spd > 0.8 or stumble > 0.0) and not prone:
		G.audio.step(pos)
	stumble = maxf(0.0, stumble - G.DT)
	kick_t = maxf(0.0, kick_t - G.DT)
	# far away in a big battle: pose and body only every third tick, and no balance checks
	var far = _lod_far()
	if far:
		lod_n += 1
		if lod_n % 2 != 0:
			return
	if not far:
		check_gun_clip()
	if prone:
		prone_pose()
	else:
		stand_pose()
	strength = 0.42 * (1.0 - 0.8 * minf(1.0, stun / 0.25))
	drive()
	# balance: if the body gets pushed away from the legs, step after it or fall
	if not far and not prone and vault == null and vy == 0.0:
		var pel: Vector3 = parts[0].global_position
		var tp: Vector3 = targets[0].origin
		var ex = pel.x - tp.x
		var ez = pel.z - tp.z
		var e = Vector2(ex, ez).length()
		var ey = tp.y - pel.y
		if e > 0.65 or ey > 0.45 or parts[2].global_position.y - pos.y < 0.45:
			fall()
			return
		if e > 0.17:
			pos.x += ex * 0.14
			pos.z += ez * 0.14
			stumble = 0.3
			stumble_dir = Vector3(ex / e, 0, ez / e)
			pos = G.world.push_out_circle(pos, 0.33)[0]

# ---------------------------------------------------------------- vehicles
func mount(v, i: int) -> bool:
	if v == null or v.dead or i < 0 or i >= v.seats.size() or v.seats[i] != null:
		return false
	AI.release_cover(self)
	AI.stop_move(self)
	if dragging != null:
		dragging.dragger = null
		dragging = null
	vehicle = v
	seat = i
	v.seats[i] = self
	lod_wake()
	v.open_door(i)
	state = "riding"
	task = null
	route = null
	board_target = null
	ads = false
	prone = false
	prone_t = false
	vault = null
	lean = 0.0
	lean_t = 0.0
	vel = Vector3.ZERO
	for b in parts:
		b.add_collision_exception_with(v.body)
	hidden_in_vehicle = false
	visible = true
	gun_node.visible = v.spec["seats"][i]["role"] != "gunner"
	mount_from = pos
	mount_t = MOUNT_TIME
	_place_in_seat()
	return true

const MOUNT_TIME = 0.6
var mount_from = Vector3.ZERO
var mount_t = 0.0

func _hide_inside() -> void:
	hidden_in_vehicle = true
	visible = false
	for b in parts:
		b.freeze = true
		b.collision_layer = 0
	gun_node.visible = false

func dismount(eject: bool) -> void:
	var v = vehicle
	if v == null:
		return
	var start: Vector3 = pos
	if is_instance_valid(v) and seat >= 0 and seat < v.seats.size() and v.seats[seat] == self:
		v.seats[seat] = null
		if not v.dead:
			v.open_door(seat)
	var out: Vector3 = pos
	if is_instance_valid(v):
		var side = Vector3(cos(v.yaw), 0, -sin(v.yaw))
		var o: Vector3 = v.spec["seats"][seat]["o"]
		side *= 1.0 if o.x >= 0.0 else -1.0
		out = v.pos + side * (v.spec["wid"] * 0.5 + 0.9) + v.forward() * o.z
		out = G.world.push_out_circle(out, 0.35)[0]
		if hidden_in_vehicle and v.turret != null:
			start = v.turret.global_position + Vector3(0, 0.9, 0) - Vector3(0, 0.95, 0)
		for b in parts:
			b.remove_collision_exception_with(v.body)
	vehicle = null
	seat = -1
	visible = true
	gun_node.visible = true
	var was_hidden = hidden_in_vehicle
	hidden_in_vehicle = false
	mount_t = 0.0
	for b in parts:
		b.freeze = false
		b.collision_layer = G.L_BODY
	out.y = G.world.surface_y(out.x, out.z, out.y + 1.0)
	pos = start
	if was_hidden:
		# climbing out of the hatch: put the body back together standing on the hull
		stand_pose()
		_compute_targets()
		for k in range(parts.size()):
			parts[k].global_transform = targets[k]
			parts[k].linear_velocity = Vector3.ZERO
			parts[k].angular_velocity = Vector3.ZERO
	if state == "riding":
		state = "alive"
		strength = 0.42
		think = 0.0
		decide_t = 0.0
	if eject and state == "alive":
		pos = out
		fall(randf_range(1.5, 2.5))
	elif state == "alive":
		# hop down: the vault movement carries them from the seat to the ground beside the vehicle
		vault = {"a": start, "b": out, "t": 0.0, "h": 0.3}
		vy = 0.0

func _place_in_seat() -> void:
	var xf: Transform3D = vehicle.seat_xform(seat)
	var f: Vector3 = xf.basis.z
	body_yaw = atan2(f.x, f.z)
	var seat_p: Vector3 = xf.origin - Vector3(0, 0.95, 0)
	if mount_t > 0.0:
		# climbing in: an arc from where they stood up to the seat (or the hatch for crew inside)
		var goal = seat_p
		if vehicle.spec["seats"][seat]["pose"] == "hidden" and vehicle.turret != null:
			goal = vehicle.turret.global_position + Vector3(0, 0.9, 0) - Vector3(0, 0.95, 0)
		var k = G.smooth01(1.0 - mount_t / MOUNT_TIME)
		pos = mount_from.lerp(goal, k) + Vector3(0, sin(k * PI) * 0.35, 0)
		mount_t -= G.DT
		if mount_t <= 0.0 and vehicle.spec["seats"][seat]["pose"] == "hidden":
			_hide_inside()
		return
	pos = seat_p

func _tick_riding() -> void:
	var v = vehicle
	if v == null or not is_instance_valid(v):
		vehicle = null
		state = "alive"
		return
	supp = maxf(0.0, supp - 0.3 * G.DT)
	stun = 0.0
	for r in range(5):
		limb[r] = minf(1.0, limb[r] + 1.1 * G.DT)
	_place_in_seat()
	var role: String = v.spec["seats"][seat]["role"]
	if is_player:
		G.pc.rider_update(self)
	else:
		think -= G.DT
		if think <= 0.0:
			AI.perceive(self)
		morale_t -= G.DT
		if morale_t <= 0.0:
			morale_t = 0.5
			Morale.tick(self, 0.5)
		if vis_t != null and is_instance_valid(vis_t) and role != "driver":
			var tp: Vector3 = vis_t.pos
			aim_yaw = G.turn_to(aim_yaw, atan2(tp.x - pos.x, tp.z - pos.z), 3.0 * G.DT)
		else:
			aim_yaw = G.turn_to(aim_yaw, body_yaw, 2.0 * G.DT)
	if hidden_in_vehicle:
		# inside the hull: keep the frozen body with the vehicle so it's there when they climb out
		var off: Vector3 = pos - parts[0].global_position + Vector3(0, 0.95, 0)
		for b in parts:
			b.global_position += off
		return
	vel = Vector3.ZERO
	crouch = 0.0
	var spose: String = v.spec["seats"][seat]["pose"]
	if mount_t > 0.0:
		ready_ = false
		crouch = 0.6
		stand_pose()
		strength = 0.5
		drive()
		return
	if spose == "hatch":
		ready_ = vis_t != null
		stand_pose()
		if not is_player and role == "pass":
			AI.aim_and_fire(self)
		strength = 0.5
		drive()
		return
	if role == "gunner":
		ready_ = false
		stand_pose()
		hand_t = v.turret.global_position + v._gun_dir() * 0.25 + Vector3(0, 0.15, 0) if v.turret != null else null
		_arms_and_gun(0.0, false, Vector3(sin(aim_yaw), 0, cos(aim_yaw)), Vector3(-cos(aim_yaw), 0, sin(aim_yaw)), Vector3(sin(aim_yaw), 0, cos(aim_yaw)))
		hand_t = null
	else:
		ready_ = role != "driver" and vis_t != null
		ride_pose(role == "driver")
		if not is_player and role == "pass" and ready_:
			AI.aim_and_fire(self)
	strength = 0.5
	drive()

# seated: upper body as when standing, thighs forward along the seat, shins hanging down
func ride_pose(driving: bool) -> void:
	stand_pose()
	var f = Vector3(sin(body_yaw), 0, cos(body_yaw))
	for hi in [9, 12]:
		var hip: Vector3 = P[hi]
		var knee = hip + f * 0.42 + Vector3(0, 0.02, 0)
		P[hi + 1] = knee
		P[hi + 2] = knee + Vector3(0, -0.42, 0) + f * 0.06
	if driving:
		var r = Vector3(-f.z, 0, f.x)
		var wheel = P[2] + f * 0.45 + Vector3(0, 0.35, 0)
		P[8] = wheel - r * 0.18
		P[5] = wheel + r * 0.18
		P[7] = _ik(P[6], P[8], 0.3, 0.3, Vector3(0, -1, 0) + r * 0.7)
		P[4] = _ik(P[3], P[5], 0.3, 0.3, Vector3(0, -1, 0) - r * 0.7)

# ---------------------------------------------------------------- parachutes
func start_chute(at: Vector3) -> void:
	state = "chute"
	pos = at
	vel = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	chute = Node3D.new()
	var canopy = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = 2.4
	sm.height = 2.0
	sm.is_hemisphere = true
	canopy.mesh = sm
	canopy.material_override = _mat("canopy" + G.TEAM_UNI[team].to_html(), G.TEAM_UNI[team].lerp(Color(0.8, 0.8, 0.75), 0.4), false)
	canopy.position = Vector3(0, 4.2, 0)
	chute.add_child(canopy)
	for k in range(4):
		var line = MeshInstance3D.new()
		var lm = BoxMesh.new()
		lm.size = Vector3(0.02, 3.2, 0.02)
		line.mesh = lm
		line.material_override = _mat("line", Color(0.2, 0.2, 0.2), false)
		var a = k * PI / 2.0 + PI / 4.0
		line.position = Vector3(cos(a) * 0.9, 2.9, sin(a) * 0.9)
		line.rotation = Vector3(sin(a) * 0.45, 0, -cos(a) * 0.45)
		chute.add_child(line)
	G.main.add_child(chute)
	stand_pose()
	_compute_targets()
	for k in range(parts.size()):
		parts[k].global_transform = targets[k]
		parts[k].linear_velocity = Vector3(0, -4.5, 0)

func _tick_chute() -> void:
	var gy: float = G.world.surface_y(pos.x, pos.z, pos.y)
	var wind = Vector3(sin(G.sim_time * 0.1) * 1.5, 0, 0.6)
	pos += (vel + wind) * G.DT + Vector3(0, -4.5 * G.DT, 0)
	vel *= 0.995
	if chute != null:
		chute.global_position = pos + Vector3(0, 0.9, 0)
		chute.rotation.z = sin(G.sim_time * 1.3 + seed_) * 0.08
	ready_ = false
	stand_pose()
	strength = 0.35
	drive()
	if pos.y <= gy + 0.05:
		pos.y = gy
		_drop_chute()
		state = "alive"
		strength = 0.42
		think = 0.0
		decide_t = 0.0
		if randf() < 0.25:
			fall(1.0)

func _drop_chute() -> void:
	if chute != null:
		chute.queue_free()
		chute = null

# ---------------------------------------------------------------- on fire
func ignite(by) -> void:
	if state == "dead" or hidden_in_vehicle:
		return
	if burn_t <= 0.0 and state == "alive" and not is_player:
		G.fx.callout(self, G.pick(["I'm on fire!", "AAAH! Get it off!", "Burning!"]))
	burn_t = maxf(burn_t, 4.5)
	if by != null and is_instance_valid(by):
		last_attacker = by

func _burn() -> void:
	burn_t -= G.DT
	hp -= 16.0 * G.DT
	supp = 1.5
	Morale.shock(self, 3.0 * G.DT)
	burn_fx_t -= G.DT
	if burn_fx_t <= 0.0:
		burn_fx_t = 0.12
		G.fx.flame_puff(parts[1].global_position, Vector3(0, 2.0, 0), 0.6)
	if state == "alive" and not is_player and vehicle == null and move_target == null:
		# panic: run anywhere
		AI.release_cover(self)
		AI.go_to(self, pos + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8)), 6.0)
	if hp <= 0.0:
		Combat.kill(self, last_attacker, false)
