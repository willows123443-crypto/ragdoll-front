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
static var zombie_next = ""       # the horde: the next soldier made is one of the walking dead (walker, runner, brute, crawler)
var zombie = false
var zstyle = 0          # 0 reaching shamble, 1 lurch, 2 stagger, 3 hunched, 4 stiff
var zgait = 1.0
var ztype = ""
var zspeed = 2.8
var lunge_t = 0.0
var lunge_dir = Vector3.FORWARD
var groan_t = 0.0
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
var no_board_t = -1.0          # told to get out: don't climb back into a vehicle before this
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
var grenades = 1               # one frag each: grenades are for clearing a position, not for every exchange
var smokes = 1
var rockets = 5
var clip_n = 0
var peek_hold = 0.0        # peeking (or ducking) is kept up for a moment, no flickering in and out
var peek_on = false
var wedge_n = 0
var wedge_p = Vector3.ZERO
var slide_dir = Vector3.ZERO
var slide_t = 0.0
var fausts = 0            # one-shot panzerfausts carried as well as the main gun
var swim = false
var climb = null          # going up or down a ladder
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
var hands_t = null   # two-handed grip: [left, right] (dragging a man by his shoulders)
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
var bleed = 0.0          # hp lost per second until a dressing goes on
var dressings = 2
var bandage_t = 0.0      # putting a dressing on (own wound, or bandage_who's)
var bandage_who = null
var drip_t = 0.0
var dragger = null
var dragging = null
var carrying = null         # a wounded friend over the shoulder
var carried_by = null
var crate = false           # lugging an ammo box
var wound_part = -1         # where they were last hit (they clutch it)
var mud = 0.0                # how much crawling he's done (it shows on his uniform)
var mud_stage = 0
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
var path_prio = false        # the player just ordered him: plan his route ahead of the queue
var scramble = null          # clambering out of a spot he got wedged in
var door_wait = 0.0          # waiting for a mate to get through a doorway
var danger_note_t = 0.0
var look_p = null            # something loud he's turning his head to look at
var look_t = 0.0
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
	zombie = zombie_next != ""
	ztype = zombie_next
	# each of the dead moves its own way: a gait style and its own pace
	zstyle = randi() % 5
	zgait = randf_range(0.8, 1.25)
	if zombie:
		skin = [Color(0.55, 0.6, 0.48), Color(0.62, 0.62, 0.55), Color(0.5, 0.55, 0.5), Color(0.58, 0.55, 0.45)][randi() % 4]
		if ztype == "brute":
			skin = Color(0.47, 0.5, 0.42)
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
	# A man in shadow (the far side of him from the sun, or anywhere indoors) was all but black: there's
	# little light in the shade here. His clothes and skin give back a little of their own colour, so
	# he can be made out in a doorway, under a roof or with the sun behind him.
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 0.2
	if camo:
		m.emission_texture = camo_tex
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

# ---------------------------------------------------------------- faces
# a painted face (eyes, brows, mouth, stubble or a beard) on the front of the head, a nose and ears;
# only drawn up close, where you can see it
static var face_texs = {}
static var face_mats = {}
const BROWS = [Color(0.2, 0.13, 0.08), Color(0.07, 0.06, 0.05), Color(0.52, 0.4, 0.24), Color(0.3, 0.2, 0.12)]

static func _face_mat(brow: int, beard: int, eyes_only: bool, slit: Color = Color(0, 0, 0, 0)) -> Material:
	var key = "%d_%d_%s_%s" % [brow, beard, str(eyes_only), slit.to_html()]
	if face_mats.has(key):
		return face_mats[key]
	var N = 32
	var img = Image.create(N, N, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var bc: Color = BROWS[brow]
	var r = RandomNumberGenerator.new()
	r.seed = hash(key)
	if beard > 0 and not eyes_only:
		for y in range(15, N):
			for x in range(3, N - 3):
				var cx = absf(x - 15.5)
				# the beard follows the jaw: wide at the cheeks, round at the chin
				var inside = (y >= 20 and cx < 12.5 - maxf(0.0, y - 26) * 1.4) or (y < 20 and cx > 9.5 and cx < 12.5)
				if not inside:
					continue
				if beard == 2 or r.randf() < 0.32:
					img.set_pixel(x, y, bc.darkened(0.15 + r.randf() * 0.15))
	# a balaclava's eye slit: a band of skin with the eyes in it
	if slit.a > 0.0:
		for y in range(11, 18):
			for x in range(4, N - 4):
				img.set_pixel(x, y, slit)
	# brows, slightly angled (hidden under a balaclava)
	for x in range(6, 14):
		if slit.a > 0.0:
			break
		var y = 9 if x > 8 else 10
		img.set_pixel(x, y, bc)
		img.set_pixel(N - 1 - x, y, bc)
		if x > 7 and x < 12:
			img.set_pixel(x, y + 1, bc.lerp(Color(0, 0, 0, 0), 0.0))
			img.set_pixel(N - 1 - x, y + 1, bc)
	# eyes: whites, iris, a dark upper lid
	for side in [0, 1]:
		for x in range(7, 13):
			var xx = x if side == 0 else N - 1 - x
			img.set_pixel(xx, 13, Color(0.13, 0.1, 0.08))
			img.set_pixel(xx, 14, Color(0.9, 0.88, 0.84))
			img.set_pixel(xx, 15, Color(0.82, 0.8, 0.76))
		for x in range(9, 11):
			var xx2 = x if side == 0 else N - 1 - x
			img.set_pixel(xx2, 14, Color(0.18, 0.13, 0.09))
			img.set_pixel(xx2, 15, Color(0.12, 0.09, 0.07))
	if not eyes_only:
		# mouth
		for x in range(12, 20):
			img.set_pixel(x, 23, Color(0.36, 0.17, 0.15))
		for x in range(13, 19):
			img.set_pixel(x, 24, Color(0.55, 0.32, 0.28, 0.85))
	var tex = ImageTexture.create_from_image(img)
	var m = StandardMaterial3D.new()
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.4
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.roughness = 0.85
	face_mats[key] = m
	return m

func _detail(parent: Node3D, mesh: Mesh, at: Vector3, mat: Material, sc: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	mi.scale = sc
	mi.material_override = mat
	mi.layers = 2
	mi.visibility_range_end = 38.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

static var face_quad: QuadMesh = null
static var unit_box: BoxMesh = null

func _face(head: Node3D, sk: Material, militia: bool) -> void:
	if face_quad == null:
		face_quad = QuadMesh.new()
		face_quad.size = Vector2(0.25, 0.236)
		unit_box = BoxMesh.new()
		unit_box.size = Vector3.ONE
	var dark_skin = skin.get_luminance() < 0.42
	var brow = 1 if dark_skin else [0, 0, 3, 2, 1][id % 5]
	var beard = 0
	if militia:
		beard = 2 if id % 5 < 3 else 1
	elif id % 3 == 0:
		beard = 1
	var balaclava = militia and id % 4 == 0
	# the head and torso pieces have +z pointing out of the back, so the face goes on -z
	var z = 0.1375 if balaclava else 0.1265
	# set a little low on the head so brows and eyes sit clear of any helmet rim
	var fq = _detail(head, face_quad, Vector3(0, -0.012, -z), _face_mat(brow, beard, balaclava, skin if balaclava else Color(0, 0, 0, 0)))
	fq.rotation.y = PI
	if not balaclava:
		_detail(head, unit_box, Vector3(0, -0.04, -0.138), sk, Vector3(0.045, 0.07, 0.04))
	for e in [-1.0, 1.0]:
		_detail(head, unit_box, Vector3(e * 0.132, 0.0, 0.005), sk, Vector3(0.025, 0.07, 0.05))

# webbing, belt and pouches for the regulars
func _kit(vest: Material, helm: Material) -> void:
	if unit_box == null:
		unit_box = BoxMesh.new()
		unit_box.size = Vector3.ONE
	var belt = _mat("belt", Color(0.2, 0.17, 0.12), false)
	var pouch = _mat("pouch" + G.TEAM_VEST[team].to_html(), G.TEAM_VEST[team].darkened(0.08), false)
	_mesh(parts[0], Vector3(0.38, 0.05, 0.27), Vector3(0, 0.085, 0), belt)
	for e in [-1.0, 1.0]:
		_detail(parts[0], unit_box, Vector3(e * 0.11, 0.05, -0.14), pouch, Vector3(0.085, 0.075, 0.05))
		# shoulder straps over the vest
		_detail(parts[1], unit_box, Vector3(e * 0.12, 0.08, 0.0), belt, Vector3(0.05, 0.3, 0.31))
		# chin strap
		_detail(parts[2], unit_box, Vector3(e * 0.127, -0.02, -0.03), helm, Vector3(0.012, 0.16, 0.014))
	# magazine pouches on the chest
	for k in range(3):
		_detail(parts[1], unit_box, Vector3((k - 1) * 0.09, -0.02, -0.19), pouch, Vector3(0.07, 0.09, 0.035))
	# collar
	_detail(parts[1], unit_box, Vector3(0, 0.25, -0.02), _mat("collar" + G.TEAM_UNI[team].to_html(), G.TEAM_UNI[team].darkened(0.12), false), Vector3(0.26, 0.05, 0.2))

# each team wears a differently shaped helmet, with a band in the team colour
func _helmet(head: Node3D, helm: Material, band: Material, cloth: Material) -> void:
	var n0 = head.get_child_count()
	_helmet_parts(head, helm, band, cloth)
	for i in range(n0, head.get_child_count()):
		head.get_child(i).set_meta("helmet", true)

# knocked off when he goes down: the helmet comes away and rolls on the ground beside him
func drop_helmet() -> void:
	if parts.size() < 3:
		return
	var head: Node3D = parts[2]
	var bits = []
	for ch in head.get_children():
		if ch.has_meta("helmet"):
			bits.append(ch)
	if bits.is_empty():
		return
	var rb = RigidBody3D.new()
	rb.collision_layer = G.L_DEBRIS
	rb.collision_mask = G.L_WORLD | G.L_DEBRIS
	rb.mass = 1.2
	var cs = CollisionShape3D.new()
	var sp = SphereShape3D.new()
	sp.radius = 0.15
	cs.shape = sp
	cs.position = Vector3(0, 0.1, 0)
	rb.add_child(cs)
	G.fx.add_child(rb)
	rb.global_transform = head.global_transform
	for b in bits:
		b.reparent(rb, true)
	rb.linear_velocity = head.linear_velocity + Vector3(randf_range(-1.5, 1.5), randf_range(1.0, 2.5), randf_range(-1.5, 1.5))
	rb.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
	G.fx.debris_list.append({"b": rb, "t": 150.0})

func _helmet_parts(head: Node3D, helm: Material, band: Material, cloth: Material) -> void:
	# The heads are boxes, so the helmets are shells shaped to fit them: a rounded-off square crown sitting
	# down over the top of the head, just clear of the brows, with each side's own brim or skirt.
	var by = 0.072
	var bs = 0.308
	match team % 4:
		0:  # a steel pot pulled well down: low over the top of the head, round the sides over the ears and
			# down the back of the neck, with a short rolled rim over the brow
			_hbox(head, Vector3(0.298, 0.135, 0.304), Vector3(0, 0.106, 0.004), helm, 0.058)
			_hbox(head, Vector3(0.292, 0.016, 0.03), Vector3(0, 0.044, -0.146), helm, 0.007)
			_hbox(head, Vector3(0.298, 0.1, 0.02), Vector3(0, 0.012, 0.15), helm, 0.008)
			for e in [-1.0, 1.0]:
				_hbox(head, Vector3(0.02, 0.085, 0.235), Vector3(e * 0.147, 0.02, 0.035), helm, 0.008)
		1:  # a crown, a short peak over the eyes, and a skirt flaring out over the ears and the back of the neck
			_hbox(head, Vector3(0.294, 0.14, 0.302), Vector3(0, 0.108, 0.01), helm, 0.058)
			_hbox(head, Vector3(0.25, 0.016, 0.05), Vector3(0, 0.05, -0.15), helm, 0.006, Vector3(0.28, 0, 0))
			_hbox(head, Vector3(0.26, 0.075, 0.018), Vector3(0, 0.035, 0.16), helm, 0.006, Vector3(-0.38, 0, 0))
			for e in [-1.0, 1.0]:
				_hbox(head, Vector3(0.018, 0.07, 0.21), Vector3(e * 0.148, 0.036, 0.035), helm, 0.006, Vector3(0, 0, e * 0.36))
		2:  # a bowl pulled down on the head with a wide flat brim
			_hbox(head, Vector3(0.288, 0.11, 0.288), Vector3(0, 0.118, 0.0), helm, 0.048)
			_hbox(head, Vector3(0.37, 0.014, 0.37), Vector3(0, 0.07, 0.0), helm, 0.007)
			by = 0.084
			bs = 0.292
		_:  # a soft field cap with a peak
			_hbox(head, Vector3(0.268, 0.09, 0.268), Vector3(0, 0.15, 0.0), cloth, 0.03)
			_hbox(head, Vector3(0.2, 0.014, 0.085), Vector3(0, 0.112, -0.165), cloth, 0.006, Vector3(0.12, 0, 0))
			by = 0.125
			bs = 0.274
	_hbox(head, Vector3(bs, 0.022, bs), Vector3(0, by, 0.004 if team % 4 < 2 else 0.0), band, 0.01)

# a bevelled box (rounded edges), for helmets and the like
func _hbox(parent: Node3D, size: Vector3, at: Vector3, mat: Material, bevel: float, rot: Vector3 = Vector3.ZERO) -> void:
	var mi = MeshInstance3D.new()
	mi.mesh = VModel.bevel_mesh(size, bevel)
	mi.position = at
	mi.rotation = rot
	mi.material_override = mat
	mi.layers = 2
	parent.add_child(mi)

func _build_body() -> void:
	_compute_targets()
	var uni = _mat("uni" + G.TEAM_UNI[team].to_html(), G.TEAM_UNI[team], true)
	var uni2 = _mat("uni2" + G.TEAM_UNI2[team].to_html(), G.TEAM_UNI2[team], true)
	var vest = _mat("vest" + G.TEAM_VEST[team].to_html(), G.TEAM_VEST[team], true)
	var helm = _mat("helm" + G.TEAM_HELM[team].to_html(), G.TEAM_HELM[team], false)
	var band = _mat("band" + G.TEAM_BAND[team].to_html(), G.TEAM_BAND[team], false)
	var militia = Faction.militia(team) and not zombie
	if militia:
		# no uniform: whatever they had on, a chest rig over it
		var cl: Array = Faction.clothes(id)
		uni = _mat("mil" + cl[0].to_html(), cl[0], true)
		uni2 = _mat("mil" + cl[1].to_html(), cl[1], true)
		vest = _mat("mil" + cl[2].to_html(), cl[2], true)
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
	_mesh(parts[1], Vector3(0.45, 0.3, 0.27), Vector3(0, 0.06, 0), vest)
	_mesh(parts[1], Vector3(0.3, 0.26, 0.06), Vector3(0, 0.05, -0.15), vest)
	_mesh(parts[2], Vector3(0.25, 0.26, 0.25), Vector3.ZERO, sk)
	# a neck down into the collar, so the head doesn't float above the shoulders
	_mesh(parts[2], Vector3(0.12, 0.13, 0.12), Vector3(0, -0.185, 0.015), sk)
	if not zombie:
		_face(parts[2], sk, militia)
	if militia:
		Faction.headgear(self, parts[2])
		Faction.rig(self, vest, uni, uni2)
	elif not zombie:
		_helmet(parts[2], helm, band, uni)
		var pack = _mat("pack" + G.TEAM_VEST[team].to_html(), G.TEAM_VEST[team].darkened(0.18), true)
		_mesh(parts[1], Vector3(0.27, 0.28, 0.12), Vector3(0, 0.04, 0.19), pack)
		_mesh(parts[0], Vector3(0.09, 0.13, 0.08), Vector3(0.17, 0.0, 0.08), _mat("canteen", Color(0.24, 0.26, 0.2), false))
		_kit(vest, helm)
	else:
		_zombie_look(sk, uni, uni2)
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
	for p in G.gun_model(wid, team, id):
		var mi = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(p[3], p[4], p[5])
		mi.mesh = bm
		mi.material_override = _mat("gun" + p[6].to_html(false), p[6], false)
		mi.position = Vector3(p[0], p[1], p[2])
		if p.size() > 7:
			mi.rotation.x = p[7]
		mi.layers = 2
		mi.name = "p%d" % i
		# machine gun bipod legs: hinged at the top so they can fold up under the barrel
		if new_bipod(p):
			mi.set_meta("leg", Vector3(p[0], p[1] + p[4] * 0.5, p[2]))
			mi.set_meta("len", p[4])
		gun_node.add_child(mi)
		i += 1
	bipod_k = 0.0
	_pose_bipod()
	_bayonet_mesh()

func new_bipod(p: Array) -> bool:
	return wid in ["lmg", "atrifle"] and absf(p[3] - 0.015) < 0.001 and p[4] > 0.15 and absf(p[5] - 0.015) < 0.001

var detector: Node3D = null

# a sandbag or plank carried in both arms while building
var carried: MeshInstance3D = null

# tools and loads live under the effects node: take them with us when this soldier is removed
func _exit_tree() -> void:
	for n in [tool_node, detector, carried]:
		if n != null and is_instance_valid(n):
			n.queue_free()

# the beam material shared by weapon lights and headlights
static func get_beam_mat() -> ShaderMaterial:
	if beam_mat == null:
		var sh = Shader.new()
		sh.code = """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec3 col = vec3(0.86, 0.92, 1.0);
uniform float strength = 0.16;
varying float along;
void vertex() { along = clamp((VERTEX.y + 5.0) / 10.0, 0.0, 1.0); }
void fragment() {
	float edge = pow(abs(dot(NORMAL, VIEW)), 1.6);
	float fade = pow(1.0 - along, 1.8) * smoothstep(0.0, 0.04, along);
	ALBEDO = col * strength * fade * edge;
}"""
		beam_mat = ShaderMaterial.new()
		beam_mat.shader = sh
	return beam_mat

func carry_item(on: bool, kind: String, at: Vector3) -> void:
	if not on:
		if carried != null:
			carried.queue_free()
			carried = null
		return
	if carried == null or carried.get_meta("k", "") != kind:
		if carried != null:
			carried.queue_free()
		carried = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(0.5, 0.2, 0.32) if kind == "bag" else Vector3(0.16, 0.07, 2.0)
		carried.mesh = bm
		carried.material_override = _mat("carry" + kind, Color(0.55, 0.5, 0.36) if kind == "bag" else Color(0.55, 0.42, 0.27), false)
		carried.set_meta("k", kind)
		G.fx.add_child(carried)
	carried.global_position = at
	carried.rotation = Vector3(0, body_yaw + (PI / 2.0 if kind == "plank" else 0.0), 0)
	carried.set_meta("seen", G.sim_time)

# hand tools: a shovel, a hammer, or a mine detector, from the grip to the working end
var tool_node: Node3D = null

func tool_at(kind: String, grip: Vector3, head: Vector3) -> void:
	if kind == "detector":
		detector_at(grip, head)
		return
	if tool_node == null or tool_node.get_meta("k", "") != kind:
		if tool_node != null:
			tool_node.queue_free()
		tool_node = Node3D.new()
		tool_node.set_meta("k", kind)
		var pole = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(0.035, 1.0, 0.035) if kind != "wrench" else Vector3(0.03, 1.0, 0.015)
		pole.mesh = bm
		pole.material_override = _mat("toolwood", Color(0.45, 0.33, 0.2), false) if kind != "wrench" else _mat("toolsteel", Color(0.3, 0.3, 0.3), false)
		pole.name = "pole"
		tool_node.add_child(pole)
		var hd = MeshInstance3D.new()
		var hm = BoxMesh.new()
		hm.size = Vector3(0.22, 0.03, 0.26) if kind == "shovel" else (Vector3(0.07, 0.025, 0.07) if kind == "wrench" else Vector3(0.06, 0.06, 0.16))
		hd.mesh = hm
		hd.material_override = _mat("toolsteel", Color(0.3, 0.3, 0.3), false)
		hd.name = "head"
		tool_node.add_child(hd)
		G.fx.add_child(tool_node)
	tool_node.visible = true
	tool_node.set_meta("seen", G.sim_time)
	var d = head - grip
	var L = maxf(d.length(), 0.05)
	var y = d / L
	var x = y.cross(Vector3.UP).normalized() if absf(y.y) < 0.99 else Vector3.RIGHT
	var z = x.cross(y)
	(tool_node.get_node("pole") as MeshInstance3D).global_transform = Transform3D(Basis(x, y * L, z), (grip + head) * 0.5)
	(tool_node.get_node("head") as MeshInstance3D).global_transform = Transform3D(Basis(x, y, z), head)

# a mine detector: a pole from the hands down to a flat search head just above the ground
func detector_at(grip: Vector3, head: Vector3) -> void:
	if detector == null:
		detector = Node3D.new()
		var pole = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(0.03, 1.0, 0.03)
		pole.mesh = bm
		pole.material_override = _mat("det", Color(0.15, 0.15, 0.14), false)
		pole.name = "pole"
		detector.add_child(pole)
		var disc = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		cm.top_radius = 0.17
		cm.bottom_radius = 0.17
		cm.height = 0.035
		disc.mesh = cm
		disc.material_override = _mat("detd", Color(0.3, 0.32, 0.26), false)
		disc.name = "disc"
		detector.add_child(disc)
		G.fx.add_child(detector)
	detector.visible = true
	detector.set_meta("seen", G.sim_time)
	var pole: MeshInstance3D = detector.get_node("pole")
	var d = head - grip
	var L = d.length()
	var y = d / maxf(L, 0.01)
	var x = y.cross(Vector3.UP).normalized() if absf(y.y) < 0.99 else Vector3.RIGHT
	var z = x.cross(y)
	pole.global_transform = Transform3D(Basis(x, y * L, z), (grip + head) * 0.5)
	var disc: MeshInstance3D = detector.get_node("disc")
	disc.global_position = head

var bipod_k = 0.0          # 0 folded, 1 legs down on the ground or a wall
var still_t = 0.0

# set up to fire: machine gunners drop the bipod once they've stopped (or gone prone, or are behind low cover),
# and anyone firing over a wall or sill rests the gun on it; both steady the aim a lot
func _bipod_tick() -> void:
	if state != "alive":
		return
	still_t = still_t + G.DT if vel.length() < 0.5 else 0.0
	var rest = in_cover and cover != null and cover.type == "low"
	var want = (wid == "lmg" or wid == "atrifle") and ready_ and (prone or (rest and still_t > 0.4))
	var nk = move_toward(bipod_k, 1.0 if want else 0.0, G.DT * 2.5)
	if nk != bipod_k:
		bipod_k = nk
		_pose_bipod()

func _pose_bipod() -> void:
	if gun_node == null:
		return
	for c in gun_node.get_children():
		if not c.has_meta("leg"):
			continue
		var hinge: Vector3 = c.get_meta("leg")
		var L: float = c.get_meta("len")
		var sx = signf(hinge.x) if hinge.x != 0.0 else 1.0
		var b = Basis(Vector3.RIGHT, lerpf(-PI / 2.0, 0.0, bipod_k)) * Basis(Vector3.BACK, sx * 0.3 * bipod_k)
		c.basis = b
		c.position = hinge + b * Vector3(0, -L * 0.5, 0)

func steady() -> float:
	var k = 1.0
	if bipod_k > 0.9:
		k = 0.45
	elif in_cover and cover != null and cover.type == "low" and vel.length() < 0.5:
		k = 0.6            # rested on the wall or the sill
	if prone:
		k = minf(k, 0.7)
	return k

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

# ---------------------------------------------------------------- feet that stay where they're put
# The ground a man covers with each step, and so how fast his legs go: short quick steps at a walk,
# long ones at a run (the legs used to turn over at a runner's rate whatever the speed, which is why
# a walking man's feet slid).
static func step_len(spd: float) -> float:
	return clampf(0.5 + 0.17 * spd, 0.62, 1.5)

static var PLANT = true

static func gait_k(spd: float) -> float:
	return PI / step_len(spd) if PLANT else 2.3

var foot_w: Array = [Vector3.ZERO, Vector3.ZERO]      # where each foot is planted, in the world
var foot_yaw: Array = [0.0, 0.0]                      # which way he faced when it was last put down
var foot_sw: Array = [false, false]                   # in the air, swinging to its next place
var foot_from: Array = [Vector3.ZERO, Vector3.ZERO]
var foot_t0: Array = [0.0, 0.0]
var foot_dur: Array = [0.2, 0.2]
var foot_ok = false
var foot_seen = -1.0
var acc_lp = Vector3.ZERO
var pvel = Vector3.ZERO

# one leg: the foot stays planted on the spot it came down on while the body moves over it; when the
# walk cycle says it's this leg's turn (or the leg's at full stretch) it lifts, swings through, and
# comes down ahead where the body will be. Standing, a foot left out of place (he's turned, or shuffled)
# takes a small step back under him.
func _plant_foot(side: int, hip: Vector3, base: Vector3, f: Vector3, r: Vector3, cz: float, spd: float, gy: float) -> Vector3:
	var sd = 1.0 if side == 1 else -1.0
	var neutral = base + r * (sd * 0.13) + f * cz
	var now = G.sim_time
	if not foot_ok or now - foot_seen > 0.4 or G.dist2d(foot_w[side], neutral) > 1.25 or absf(foot_w[side].y - gy) > 1.1:
		foot_w[side] = Vector3(neutral.x, G.world.surface_y(neutral.x, neutral.z, gy + 0.3) + 0.07, neutral.z)
		foot_sw[side] = false
		foot_yaw[side] = body_yaw
	var other = 1 - side
	var moving = spd > 0.3
	var ph = wrapf(phase + (PI if side == 1 else 0.0), -PI, PI)
	var swing_ph = absf(ph) < PI * 0.5
	var w = maxf(spd * gait_k(spd), 0.5)
	if not foot_sw[side]:
		var stretched = (foot_w[side] - hip).length() > 0.875
		var lift_off = false
		if moving:
			lift_off = swing_ph or stretched
		else:
			# standing: step it back under him if it's been left behind (one foot at a time)
			var off = G.dist2d(foot_w[side], neutral)
			# (and when he's turned on the spot: the feet step round with him, they don't swivel)
			lift_off = (off > 0.17 or stretched or (off > 0.07 and absf(G.wrap_a(body_yaw - foot_yaw[side])) > 0.55)) and not foot_sw[other] and now - maxf(foot_t0[0] + foot_dur[0], foot_t0[1] + foot_dur[1]) > 0.06
		if lift_off:
			foot_sw[side] = true
			foot_from[side] = foot_w[side]
			foot_t0[side] = now
			if moving:
				var rem = (PI * 0.5 - ph) if swing_ph else (PI * 0.5 - ph + (TAU if ph > 0.0 else 0.0))
				foot_dur[side] = clampf(rem / w, 0.12, 0.6)
			else:
				foot_dur[side] = 0.2
	if not foot_sw[side]:
		return foot_w[side]
	var u = clampf((now - foot_t0[side]) / foot_dur[side], 0.0, 1.0)
	var t_rem = (1.0 - u) * foot_dur[side]
	var tgt = neutral
	if moving:
		var dirv = Vector3(vel.x, 0, vel.z) / spd
		# as far ahead as the leg will reach from where the hips ride (no further: a foot put down out of
		# reach has to be dragged straight back in)
		var hv = hip.y - gy - 0.07
		var rh = sqrt(maxf(0.86 * 0.86 - hv * hv, 0.01))
		tgt = neutral + Vector3(vel.x, 0, vel.z) * t_rem + dirv * minf(step_len(spd) * 0.5, rh * 0.9)
	tgt.y = G.world.surface_y(tgt.x, tgt.z, gy + 0.3) + 0.07
	var e = u * u * (3.0 - 2.0 * u)
	var p = foot_from[side].lerp(tgt, e)
	p.y = lerpf(foot_from[side].y, tgt.y, e) + sin(PI * u) * (0.06 + minf(spd, 6.0) * 0.022)
	foot_w[side] = p
	if u >= 1.0:
		foot_sw[side] = false
		foot_w[side] = tgt
		foot_yaw[side] = body_yaw
	return p

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

# the grenade in his throwing hand from the moment it comes off his belt until it leaves: green for a
# fragmentation grenade, a pale can for smoke, a bottle for petrol
var nade_mesh: MeshInstance3D = null
func _show_nade(on: bool, type: String = "frag") -> void:
	if on and nade_mesh == null and parts.size() > 6:
		nade_mesh = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		cm.top_radius = 0.035
		cm.bottom_radius = 0.045
		cm.height = 0.13
		cm.radial_segments = 8
		cm.rings = 1
		nade_mesh.mesh = cm
		nade_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parts[6].add_child(nade_mesh)
		nade_mesh.position = Vector3(0, 0.2, 0.0)
	if nade_mesh != null:
		if on and not nade_mesh.visible:
			var col = Color(0.2, 0.27, 0.14)
			if type == "smoke":
				col = Color(0.72, 0.74, 0.7)
			elif type == "molotov":
				col = Color(0.5, 0.33, 0.12)
			nade_mesh.material_override = _mat("nade_" + type, col, false)
		nade_mesh.visible = on

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
		# hard up against a wall: muzzle up, the rifle upright in front of the right shoulder and tipped a
		# little outward (it used to stand up through his own head)
		g = (aim * 0.2 + ur * 0.24 + Vector3(0, 0.95, 0)).normalized()
	elif sprint:
		g = (uf * 0.3 - ur * 0.7 + Vector3(0, 0.6, 0)).normalized()
	elif reloading:
		g = (aim * 0.7 + Vector3(0, -0.45, 0) - ur * 0.25).normalized()
	elif ready_:
		g = aim
	elif spd < 0.6:
		# at ease: rifle held low across the body, muzzle down
		g = (uf * 0.62 - ur * 0.38 + Vector3(0, -0.55, 0)).normalized()
	else:
		g = uf * 0.55 - ur * 0.62
		g.y = 0.3
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
	elif gun_blocked and ready_ and not reloading:
		rh = rsh + uf * 0.24 + ur * 0.08 + Vector3(0, -0.26, 0)
	elif ready_ or reloading or gun_blocked:
		rh = rsh + g * 0.27 - ur * 0.07 + Vector3(0, -0.09, 0)
	elif spd < 0.6:
		rh = rsh + uf * 0.14 - ur * 0.03 + Vector3(0, -0.36, 0)
	else:
		rh = rsh + uf * 0.2 - ur * 0.05 + Vector3(0, -0.3 + sin(phase * 2.0) * 0.02 * minf(spd, 3.0), 0)
	anchor_l = false
	if swim and state == "alive":
		# breaststroke
		var k = G.sim_time * 3.2 + seed_
		var sw = sin(k)
		var reach = Vector3(0, -0.12 + 0.06 * cos(k), 0) + uf * (0.32 + 0.22 * sw)
		rh = rsh + reach - ur * (0.08 + 0.22 * maxf(0.0, -sw))
		lh = lsh + reach + ur * (0.08 + 0.22 * maxf(0.0, -sw))
	elif throw_t > 0.0 and has_meta("spade"):
		# the entrenching tool, swung two-handed from over the right shoulder down across the body
		var TP: float = get_meta("throw_T", 0.5)
		var kp = clampf(1.0 - throw_t / TP, 0.0, 1.0)
		var sw = clampf((kp - 0.2) / 0.45, 0.0, 1.0)
		var up_p: Vector3 = rsh + ur * 0.12 - uf * 0.05 + Vector3(0, 0.42, 0)
		var dn_p: Vector3 = (rsh + lsh) * 0.5 + uf * 0.45 - ur * 0.12 + Vector3(0, -0.28, 0)
		rh = up_p.lerp(dn_p, sw * sw * (3.0 - 2.0 * sw))
		var hd: Vector3 = (Vector3(0, 1.0, 0) - uf * 0.2).lerp(uf * 0.9 + Vector3(0, -0.25, 0), sw).normalized()
		lh = rh - hd * 0.18
		anchor_l = true
		g = (uf * 0.3 + Vector3(0, -0.9, 0)).normalized()
		tool_at("shovel", rh - hd * 0.2, rh + hd * 0.62)
		if gun_node != null:
			gun_node.visible = false
	elif throw_t > 0.0 and has_meta("thrust"):
		# a shove with the rifle held across the body: drawn in to the chest, driven out with both hands
		# and brought back
		var TS: float = get_meta("throw_T", 0.42)
		var ks = clampf(1.0 - throw_t / TS, 0.0, 1.0)
		var out = 0.0
		if ks < 0.25:
			out = -0.1 * (ks / 0.25)
		elif ks < 0.55:
			out = lerpf(-0.1, 0.5, (ks - 0.25) / 0.3)
		else:
			out = lerpf(0.5, 0.12, (ks - 0.55) / 0.45)
		rh = rsh + uf * (0.2 + out) - ur * 0.02 + Vector3(0, -0.12, 0)
		g = (-ur * 0.82 + Vector3(0, 0.42, 0) + uf * 0.25).normalized()
	elif throw_t > 0.0:
		var TT: float = get_meta("throw_T", 0.55)
		var k = 1.0 - throw_t / TT
		if TT > 0.9:
			# pin out at the chest, arm right back and up, over the top, and the follow-through
			var rel = 1.0 - Combat.THROW_AT / TT
			if k < 0.28:
				rh = (rsh + lsh) * 0.5 + uf * 0.3 + Vector3(0, -0.22, 0)
				lh = rh + ur * 0.09 + Vector3(0, 0.03 * sin(k * 40.0), 0)
			elif k < rel:
				var w = (k - 0.28) / (rel - 0.28)
				# (cocked: the hand up beside his head and a little behind it. Further back than this the arm
				# can't follow, and it hung at his side instead)
				rh = rsh + (-uf * 0.14 + ur * 0.24 + Vector3(0, 0.5, 0)) * minf(1.0, w * 1.6)
				# (the left hand takes the rifle down out of the way: held up in front of him it read as aiming)
				var lh_pin: Vector3 = (rsh + lsh) * 0.5 + uf * 0.3 + Vector3(0, -0.22, 0) + ur * 0.09
				lh = lh_pin.lerp(lsh + uf * 0.2 + Vector3(0, -0.34, 0), minf(1.0, w * 2.5))
			else:
				var w2 = (k - rel) / (1.0 - rel)
				rh = rsh + uf * lerpf(0.62, 0.4, w2) + Vector3(0, lerpf(0.42, -0.4, w2), 0) - ur * 0.18 * w2
				lh = lsh + uf * 0.2 + Vector3(0, -0.3, 0)
		else:
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
		rh = hand_t + ur * 0.08 + Vector3(0, 0.06 + 0.42 * maxf(sw, -0.15), 0) - uf * (0.16 * sw + 0.06)
		lh = hand_t - ur * 0.2 + uf * 0.05 + Vector3(0, -0.06, 0)
		if sw < -0.2 and not hammer_hit:
			# the blow lands on the work: a knock, a little dust and now and then a splinter
			hammer_hit = true
			if randf() < 0.7:
				G.audio.hammer(hand_t)
			if randf() < 0.35:
				G.fx.impact(hand_t, -uf)
			if randf() < 0.12:
				G.fx.debris(hand_t, Vector3(randf_range(-1, 1), randf_range(1.5, 3.0), randf_range(-1, 1)), 0.06, Color(0.55, 0.42, 0.27))
		elif sw > 0.3:
			hammer_hit = false
	elif zombie:
		var zt = G.sim_time + seed_
		if lunge_t > 0.3:
			# wind-up: arms come up
			rh = rsh + uf * 0.15 + Vector3(0, 0.28, 0) - ur * 0.05
			lh = lsh + uf * 0.15 + Vector3(0, 0.28, 0) + ur * 0.05
		elif lunge_t > 0.0:
			# the grab
			rh = rsh + uf * 0.58 + Vector3(0, -0.02, 0) + ur * 0.04
			lh = lsh + uf * 0.58 + Vector3(0, -0.02, 0) - ur * 0.04
		elif ztype == "runner":
			var k = sin(phase)
			rh = rsh + uf * (0.12 + 0.22 * k) + Vector3(0, -0.22 + 0.1 * absf(k), 0)
			lh = lsh + uf * (0.12 - 0.22 * k) + Vector3(0, -0.22 + 0.1 * absf(k), 0)
		elif ztype == "brute":
			rh = rsh + uf * 0.22 - ur * 0.18 + Vector3(0, -0.32 + sin(zt * 1.3) * 0.04, 0)
			lh = lsh + uf * 0.22 + ur * 0.18 + Vector3(0, -0.32 + sin(zt * 1.1) * 0.04, 0)
		elif ztype == "runner" and zstyle % 2 == 1:
			# arms trailing back as it bolts
			var k2 = sin(phase)
			rh = rsh - uf * (0.18 + 0.08 * k2) + Vector3(0, -0.28, 0) - ur * 0.06
			lh = lsh - uf * (0.18 - 0.08 * k2) + Vector3(0, -0.28, 0) + ur * 0.06
		else:
			match zstyle:
				1:  # arms hanging and swinging with the lurch
					var k3 = sin(phase)
					rh = rsh + uf * (0.08 + 0.12 * k3) + Vector3(0, -0.5, 0) - ur * 0.04
					lh = lsh + uf * (0.08 - 0.12 * k3) + Vector3(0, -0.5, 0) + ur * 0.04
				2:  # one arm reaching, the other dangling
					rh = rsh + uf * 0.45 + Vector3(0, -0.04 + sin(zt * 2.0) * 0.07, 0)
					lh = lsh + uf * 0.06 + Vector3(0, -0.52, 0) + ur * 0.05
				3:  # hands hanging low in front of the knees
					rh = rsh + uf * 0.28 - ur * 0.06 + Vector3(0, -0.46 + sin(zt * 1.4) * 0.03, 0)
					lh = lsh + uf * 0.3 + ur * 0.06 + Vector3(0, -0.46 + sin(zt * 1.2) * 0.03, 0)
				4:  # clawing at the air
					rh = rsh + uf * 0.3 + Vector3(0, 0.05 + 0.16 * sin(zt * 3.1), 0) - ur * 0.05
					lh = lsh + uf * 0.3 + Vector3(0, 0.05 + 0.16 * sin(zt * 2.6 + 1.0), 0) + ur * 0.05
				_:
					rh = rsh + uf * 0.42 - ur * 0.02 + Vector3(0, -0.06 + sin(zt * 2.1) * 0.06, 0)
					lh = lsh + uf * (0.34 + 0.06 * sin(zt * 1.3)) + ur * 0.02 + Vector3(0, -0.12 + sin(zt * 1.7) * 0.07, 0)
	elif hand_t != null and hands_t != null:
		lh = hands_t[0]
		rh = hands_t[1]
	elif hand_t != null:
		rh = hand_t + ur * 0.13
		lh = hand_t - ur * 0.13
	elif reloading:
		var pm = rh + g * 0.13 + gd * 0.13
		var pp: Vector3 = P[1] + uf * 0.2 + Vector3(0, -0.28, 0)
		var home: Vector3 = rh + g * W["hold"]
		match W.get("reload_style", "mag"):
			"shells":
				# one round at a time from the belt pouch into the gun: hand to the pouch and back, four times
				var port = rh + g * 0.1 + Vector3(0, 0.03, 0) - ur * 0.04
				var cyc = fmod(rk * 4.0, 1.0)
				if rk < 0.08:
					lh = home.lerp(port, rk / 0.08)
				elif rk > 0.92:
					lh = port.lerp(home, (rk - 0.92) / 0.08)
				else:
					lh = port.lerp(pp, sin(cyc * PI))
				_show_mag(false)
			"single":
				# break it open, a round from the pouch into the breech, snap it shut
				var breech = rh + g * 0.16 + Vector3(0, 0.02, 0)
				if rk < 0.2:
					lh = home.lerp(breech, rk / 0.2)
				elif rk < 0.45:
					lh = breech.lerp(pp, (rk - 0.2) / 0.25)
				elif rk < 0.75:
					lh = pp.lerp(breech, (rk - 0.45) / 0.3)
				else:
					lh = breech.lerp(home, (rk - 0.75) / 0.25)
				g = (g + Vector3(0, -0.35, 0)).normalized()        # muzzle tipped down while it's open
				_show_mag(false)
			"rocket":
				# a fresh rocket from over the shoulder slid into the back of the tube
				# The tube comes down off the shoulder, muzzle to the ground; a hand goes back over the
				# shoulder for a rocket from the pack, brings it round and seats it in the tube with a
				# push; then the tube goes back up. Five seconds, and he's no use to anyone while it lasts.
				var tip = sin(clampf((rk - 0.04) / 0.9, 0.0, 1.0) * PI)
				g = (g + Vector3(0, -0.55 * tip, 0)).normalized()
				var back = rh - g * 0.34 + Vector3(0, 0.05, 0)
				var over = P[1] - uf * 0.2 + Vector3(0, 0.16, 0) + ur * 0.14
				if rk < 0.22:
					lh = home.lerp(over, rk / 0.22)
				elif rk < 0.36:
					lh = over + Vector3(0, 0.03 * sin((rk - 0.22) / 0.14 * PI), 0)
				elif rk < 0.62:
					lh = over.lerp(back, (rk - 0.36) / 0.26)
				elif rk < 0.76:
					lh = back + g * 0.1 * sin((rk - 0.62) / 0.14 * PI)
				else:
					lh = back.lerp(home, (rk - 0.76) / 0.24)
				_show_mag(false)
			_:
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
					G.fx.debris(pm, Vector3(randf_range(-0.3, 0.3), -0.5, randf_range(-0.3, 0.3)), 0.1, G.C_DARK)
	else:
		# (in a throw the rifle stays down in the left hand: it used to follow the throwing hand up, so a
		# man winding up to throw looked like a man taking aim)
		if not (throw_t > 0.0 and anchor_l):
			lh = rh + g * W["hold"]
		# a bolt action: up, back, forward, down after every shot
		if W.get("bolt", false) and shoulder:
			var since = W["rof"] - fire_cd
			if since > 0.15 and since < 0.75:
				var bk = sin((since - 0.15) / 0.6 * PI)
				rh = rh + Vector3(0, 0.05, 0) * bk + ur * 0.05 * bk - g * 0.07 * sin((since - 0.15) / 0.6 * TAU * 0.5) * bk
		# hurt and not shooting: one hand presses on the wound, the gun hangs from the other
		if wound_part >= 0 and hp < 60.0 and not shoulder and state == "alive" and wound_part != 4 and wound_part != 3:
			var wp: Vector3 = parts[wound_part].global_position
			lh = wp + uf * 0.08
			g = (uf * 0.4 - ur * 0.3 + Vector3(0, -0.6, 0)).normalized()
			anchor_l = false
		elif habit_t > 0.0 and not shoulder and state == "alive" and habit != "look":
			var hk = sin(clampf(1.0 - habit_t / HABIT_LEN, 0.0, 1.0) * PI)
			if habit == "check":
				# rifle brought up and tilted to look it over, then lowered again
				var gup = (uf * 0.75 + ur * 0.15 + Vector3(0, 0.4, 0)).normalized()
				g = g.lerp(gup, hk).normalized()
				rh = rh.lerp(rsh + uf * 0.24 - ur * 0.05 + Vector3(0, -0.12, 0), hk)
				lh = rh + g * W["hold"]
			else:
				# the left hand goes to the hip for the canteen, up to the mouth, and back
				var mouth: Vector3 = parts[2].global_position + uf * 0.14 + Vector3(0, -0.08, 0)
				var hip: Vector3 = parts[0].global_position + ur * -0.17 + uf * 0.05
				lh = hip.lerp(mouth, clampf(hk * 1.5, 0.0, 1.0)) if hk > 0.15 else lh.lerp(hip, hk / 0.15)
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
	# striding out, the hips ride lower: a straight leg can't reach a foot planted ahead or behind
	var plant = PLANT and not zombie and not swim and vault == null and climb == null and vy >= -0.5 and stumble <= 0.0
	if plant:
		pY -= 0.075 * clampf(spd / 1.6, 0.0, 1.0) * (1.0 - 0.6 * c)
	var gy = pos.y
	var base = Vector3(pos.x, gy, pos.z)
	# standing easy: the weight drifts from one leg to the other and the hips follow
	var ease_k = clampf(1.0 - spd / 0.6, 0.0, 1.0) * (0.0 if ready_ or zombie or c > 0.3 else 1.0)
	var sway = sin(t * 0.33 + float(id)) * 0.035 * ease_k
	pY -= absf(sway) * 0.35
	P[2] = base + r * (lean * 0.05 + sway) + Vector3(0, pY, 0) + f * (-0.04 * c)
	P[9] = base + r * (-0.11 + lean * 0.05 + sway) + Vector3(0, pY - 0.05 - maxf(0.0, sway) * 0.4, 0) + f * (-0.04 * c)
	P[12] = base + r * (0.11 + lean * 0.05 + sway) + Vector3(0, pY - 0.05 - maxf(0.0, -sway) * 0.4, 0) + f * (-0.04 * c)
	var sprint = not ready_ and spd > 4.6
	var al = 0.06 + 0.3 * c + minf(spd, 6.0) * 0.028 + (0.12 if sprint else 0.0) + breath
	if swim:
		al = 1.05 + sin(t * 3.2) * 0.05
	var th = lean * 0.42
	if plant and not prone:
		# leaning into a start, back against a stop, and into a swerve
		al += clampf(acc_lp.dot(f) * 0.013, -0.1, 0.15)
		th += clampf(acc_lp.dot(r) * 0.01, -0.1, 0.1)
	if zombie:
		al += {"walker": 0.42, "runner": 0.3, "brute": 0.5, "bloater": 0.2, "spitter": 0.36}.get(ztype, 0.4) + (0.3 if lunge_t > 0.0 and lunge_t < 0.3 else 0.0)
		th += sin(t * 0.9) * 0.14 + (0.1 if id % 2 == 0 else -0.1)
		match zstyle:
			1:  # lurching, pitched forward and bobbing with every step
				al += 0.22 + absf(sin(phase)) * 0.12
			2:  # staggering from side to side as it walks
				th += sin(phase * 0.5) * 0.22
				for hi2 in [2, 9, 12]:
					P[hi2] = P[hi2] + r * sin(phase * 0.5) * 0.07
			3:  # hunched right over
				al += 0.38
				for hi3 in [2, 9, 12]:
					P[hi3] = P[hi3] - Vector3(0, 0.07, 0)
			4:  # stiff and upright, head rolling
				al -= 0.28
				th += sin(t * 0.5) * 0.08
		if ztype == "runner" and zstyle % 2 == 1:
			al += 0.25          # the other kind of runner: bent low and fast
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
	if zombie:
		# head lolls to one side and juts forward
		P[1] = P[1] + uf * (0.06 + (0.1 if lunge_t > 0.0 and lunge_t < 0.3 else 0.0)) + ur * (0.05 * sin(t * 0.6) + (0.04 if id % 2 == 0 else -0.04)) - Vector3(0, 0.04, 0)
		if zstyle == 4:
			P[0] = P[0] + ur * sin(t * 0.7) * 0.07 - Vector3(0, 0.03, 0)     # head lolling round
		elif zstyle == 3:
			P[0] = P[0] + uf * 0.06
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
		if zombie and ztype != "runner" and side == id % 2 and (zstyle == 0 or zstyle == 3):
			sw *= 0.45          # the bad leg drags
			lift = 0.0
		elif zombie and zstyle == 4 and side == id % 2:
			lift *= 0.3         # a stiff leg swung round rather than lifted
		elif zombie and zstyle == 1:
			sw *= 1.3
			lift *= 1.4
		var hi = 12 if side == 1 else 9
		var cz = -0.24 * c if side == 1 else 0.3 * c
		var wide = 0.1 if zombie and zstyle == 2 else 0.0
		var foot = base + r * (sd * (0.13 + wide) + lmx * sw * A) + f * (lmz * sw * A + cz)
		if plant:
			foot = _plant_foot(side, P[hi], base, f, r, cz, spd, gy)
			if side == 1 and kick_t > 0.0:
				var kk2 = sin(PI * (1.0 - kick_t / 0.38))
				foot = foot.lerp(base + kick_dir * 0.72 + r * 0.1 + Vector3(0, 0.5, 0), kk2)
			foot = _reach(P[hi], foot, 0.88)
			P[hi + 2] = foot
			P[hi + 1] = _ik(P[hi], foot, 0.45, 0.45, f + r * (sd * 0.15))
			continue
		if swim:
			# frog kick, legs trailing behind
			var kk = sin(t * 3.2 + (PI if side == 1 else 0.0))
			foot = P[hi] - f * 0.72 + r * sd * (0.18 + 0.12 * kk) + Vector3(0, -0.28 + 0.12 * kk, 0)
			P[hi + 2] = foot
			P[hi + 1] = _ik(P[hi], foot, 0.45, 0.45, Vector3(0, -1, 0))
			continue
		if vault != null or vy < -0.5 or climb != null:
			foot.y = gy + 0.07 + lift
		else:
			foot.y = G.world.surface_y(foot.x, foot.z, gy + 0.3) + 0.07 + lift
		if side == 1 and kick_t > 0.0:
			var kk = sin(PI * (1.0 - kick_t / 0.38))
			foot = foot.lerp(base + kick_dir * 0.72 + r * 0.1 + Vector3(0, 0.5, 0), kk)
		foot = _reach(P[hi], foot, 0.88)
		P[hi + 2] = foot
		P[hi + 1] = _ik(P[hi], foot, 0.45, 0.45, f + r * (sd * 0.15))
	if plant:
		foot_ok = true
		foot_seen = G.sim_time
	else:
		foot_ok = false
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

var head_turn = 0.0          # head turned off the line of the shoulders (radians)

# a crack overhead or a bang nearby: the head snaps round to it first, the body follows if it must
# when it's quiet, men fidget: check the rifle over, look round, take a drink from the canteen
var habit = ""
var habit_t = 0.0
var habit_cd = 0.0
const HABIT_LEN = 2.6

func _habit_tick() -> void:
	if habit_t > 0.0:
		habit_t -= G.DT
		if habit_t <= 0.0 or ready_ or target != null or supp > 0.15 or state != "alive":
			habit = ""
			habit_t = 0.0
		return
	habit_cd -= G.DT
	if habit_cd > 0.0:
		return
	habit_cd = randf_range(9.0, 22.0)
	if is_player or zombie or state != "alive" or vehicle != null or ready_ or target != null or supp > 0.1 or want.length() > 0.5 \
			or reload_t > 0.0 or hand_t != null or tool_mode != "" or prone or G.sim_time - seen_t < 15.0:
		return
	habit = G.pick(["check", "check", "look", "drink"])
	habit_t = HABIT_LEN
	if habit == "look":
		var a = body_yaw + randf_range(-1.4, 1.4)
		look_p = pos + Vector3(sin(a), 0, cos(a)) * 20.0
		look_t = HABIT_LEN

func _head_tick() -> void:
	_habit_tick()
	var want = 0.0
	if look_t > 0.0:
		look_t -= G.DT
		if look_p != null and state == "alive" and not is_player and not zombie:
			var to = G.flat(look_p - pos)
			if to.length_squared() > 1.0:
				var shoulders = body_yaw + clampf(G.wrap_a(aim_yaw - body_yaw), -1.1, 1.1)
				want = clampf(G.wrap_a(atan2(to.x, to.z) - shoulders), -1.25, 1.25)
	head_turn = move_toward(head_turn, want, G.DT * (8.0 if want != 0.0 else 2.5))

func _compute_targets() -> void:
	_head_tick()
	var right: Vector3 = (P[6] - P[3]).normalized()
	var up: Vector3 = P[1] - P[2]
	var tl = up.length()
	targets[1] = _bone_xform(P[2], P[1], right)
	targets[1].origin = P[2] + up * 0.55
	var hipmid: Vector3 = (P[9] + P[12]) * 0.5
	targets[0] = _bone_xform(P[2], P[1], (P[12] - P[9]).normalized())
	targets[0].origin = hipmid + up / maxf(tl, 0.001) * 0.03
	var hright = right
	if absf(head_turn) > 0.01:
		var neck = (P[0] - P[1]).normalized()
		if neck.length_squared() > 0.5:
			hright = right.rotated(neck, head_turn)
	targets[2] = _bone_xform(P[1], P[0], hright)
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
const ZOMBIE_LOD = 26.0
func _lod_far() -> bool:
	# the dead are many and all alike: beyond a stone's throw from the camera a zombie is always posed and
	# never simulated, however few of them there are (each one was costing as much as a soldier)
	if zombie and horde_lean and state == "alive" and vault == null:
		var zc = get_viewport().get_camera_3d()
		return zc != null and zc.global_position.distance_squared_to(pos) > ZOMBIE_LOD * ZOMBIE_LOD
	# (men riding on a lorry or serving a gun count too: a far-off crew is posed, not simulated)
	if G.soldiers.size() < 36 or is_player or (state != "alive" and state != "riding") or vault != null or dragging != null:
		return false
	var cam = get_viewport().get_camera_3d()
	var ld: float = G.settings["lod_dist"]
	return cam != null and cam.global_position.distance_squared_to(pos) > ld * ld

# a far-off soldier only thinks every other frame: in between, carry the body along so it doesn't stutter
var glide_off = Vector3.ZERO
var glide_ph = 0.0

# going to ground and getting up again: the body goes down through a crouch over half a second (and
# comes up a little slower) instead of flicking from one pose to the other
var pose_mode = ""
var tr_from: Array = []
var tr_t0 = -9.0
var tr_dur = 0.5
var tr_kind = 0              # 0 going to ground / getting up, 1 into a vault, 2 landing from one
var pose_pos = Vector3.ZERO  # where he stood when the joints were last worked out

func _pose_now() -> void:
	var mode = "vault" if vault != null else ("prone" if prone else "stand")
	if mode != pose_mode:
		if pose_mode != "":
			if mode == "vault":
				_tr_begin(0.2, 1)
			elif pose_mode == "vault":
				_tr_begin(0.3, 2)
			else:
				_tr_begin(0.5 if prone else 0.62, 0)
		pose_mode = mode
	if prone and vault == null and (zombie or Vector2(vel.x, vel.z).length() > 0.25):
		crawl_pose()          # moving while down: elbows and knees, not sliding on his belly
	elif prone and vault == null:
		prone_pose()
	else:
		stand_pose()
		if vault != null and not zombie and PLANT:
			_vault_pose()
	_tr_apply()

# start easing from the pose he's in now to whatever he does next
func _tr_begin(dur: float, kind: int) -> void:
	if state != "alive" or zombie or not PLANT or P.size() < 15:
		return
	tr_from = []
	for i in range(15):
		tr_from.append(P[i] - pose_pos)
	tr_t0 = G.sim_time
	tr_dur = dur
	tr_kind = kind

func _tr_apply() -> void:
	var u = (G.sim_time - tr_t0) / tr_dur
	if u < 1.0 and tr_from.size() == 15:
		var e = u * u * (3.0 - 2.0 * u)
		if tr_kind == 0:
			# through a crouch on the way: the hips lead going down, the head and chest lead coming up
			var dip = sin(PI * u) * 0.12
			for i in range(15):
				var k = e
				if i == 2 or i == 9 or i == 12:
					k = clampf(e * (1.25 if prone else 0.85), 0.0, 1.0)
				elif i <= 1:
					k = clampf(e * (0.85 if prone else 1.2), 0.0, 1.0)
				P[i] = (pos + tr_from[i]).lerp(P[i], k)
				if i <= 8 and i != 2:
					P[i].y -= dip * (1.0 if not prone else 0.4)
		else:
			# into the jump, or coming down off it: the knees give as he lands and he straightens up again
			var dip = sin(PI * u) * (0.11 if tr_kind == 2 else (0.05 if tr_kind == 1 else 0.0))
			for i in range(15):
				P[i] = (pos + tr_from[i]).lerp(P[i], e)
				if i <= 9 or i == 12:
					P[i].y -= dip
			if tr_kind == 2:
				var f = Vector3(sin(body_yaw), 0, cos(body_yaw))
				for hip in [9, 12]:
					P[hip + 1] = P[hip + 1].lerp(_ik(P[hip], P[hip + 2], 0.45, 0.45, f + Vector3(0, 0.2, 0)), e)
	pose_pos = pos

# going over a wall: a hand down on the top of it, the knees brought up and swung over to one side, and
# the feet out in front again to land (instead of running through the air in a crouch)
func _vault_pose() -> void:
	var vt = clampf(vault["t"], 0.0, 1.0)
	var a: Vector3 = vault["a"]
	var b: Vector3 = vault["b"]
	var fl = G.flat(b - a)
	if fl.length() < 0.05 or vault.get("dive", false):
		return
	var f = fl.normalized()
	var r = Vector3(-f.z, 0, f.x)
	var w = pow(maxf(sin(PI * vt), 0.0), 0.7)
	if w <= 0.0:
		return
	# the body leans over the hand he's put down
	var lean_v = (f * 0.1 - r * 0.07 - Vector3(0, 0.05, 0)) * w
	for i in [0, 1, 3, 6]:
		P[i] = P[i] + lean_v
	if vault.has("top"):
		var mid = a.lerp(b, 0.5)
		var hp = Vector3(mid.x, vault["top"] + 0.04, mid.z) - r * 0.24
		var hand = _reach(P[3], hp, 0.59)
		P[5] = P[5].lerp(hand, w)
		P[4] = P[4].lerp(_ik(P[3], P[5], 0.3, 0.3, Vector3(0, -1, 0) - r * 0.5 - f * 0.3), w)
	for side in range(2):
		var sd = 1.0 if side == 1 else -1.0
		var hip = 12 if side == 1 else 9
		var foot = P[hip] + Vector3(0, -0.4, 0) + r * (0.24 + 0.07 * sd) + f * lerpf(-0.28, 0.4, vt)
		P[hip + 2] = P[hip + 2].lerp(_reach(P[hip], foot, 0.88), w)
		P[hip + 1] = _ik(P[hip], P[hip + 2], 0.45, 0.45, f + Vector3(0, 0.7, 0) + r * 0.5)

# a far-off man turning on the spot between his full updates: how fast his body and his aim are coming round
var yaw_rate = 0.0
var aim_rate = 0.0
var glide_yaw = 0.0
var glide_aim = 0.0

static var PERF = false
static var pf = [0, 0, 0, 0]      # microseconds: thinking, posing, driving the body, gliding

func lod_glide(cheap: bool = false) -> void:
	if not lod_frozen or hidden_in_vehicle or state != "alive":
		return
	var d = Vector3(vel.x, 0, vel.z) * G.DT
	var turns = absf(yaw_rate) > 0.2 or absf(aim_rate) > 0.2
	if d.length_squared() < 1e-8 and not turns and not foot_sw[0] and not foot_sw[1]:
		return
	if cheap:
		# every other in-between frame he's just carried along as he is (body, rifle and all): from where
		# far-off men are seen, a pose that's a sixtieth of a second old can't be told from a fresh one
		if d.length_squared() >= 1e-8:
			pos += d
			glide_off += d
			var gs0 = Vector2(vel.x, vel.z).length()
			var dph0 = gs0 * (5.0 if prone else (2.3 if zombie else gait_k(gs0))) * G.DT
			phase += dph0
			glide_ph += dph0
			for b in parts:
				b.global_position += d
			if gun_node != null and gun_body == null and vehicle == null:
				gun_node.global_position += d
		return
	# (always, however far off: skipping it made men stutter along when the commander view was zoomed out)
	# the legs keep stepping too, not just the body sliding: move him on, step the walk cycle on, and
	# pose him, so a walking man looks like he's walking from any height (undone before his next real tick)
	var gs = Vector2(vel.x, vel.z).length()
	var dph = gs * (5.0 if prone else (2.3 if zombie else gait_k(gs))) * G.DT
	pos += d
	glide_off += d
	phase += dph
	glide_ph += dph
	# and he keeps coming round (with his feet stepping round under him) instead of turning in jerks
	if turns:
		body_yaw += yaw_rate * G.DT
		glide_yaw += yaw_rate * G.DT
		aim_yaw += aim_rate * G.DT
		glide_aim += aim_rate * G.DT
	# a fresh pose from where he is now (the joints were last worked out where he was on the full update)
	_pose_now()
	_compute_targets()
	for i in range(parts.size()):
		parts[i].global_transform = targets[i]
	# and his rifle in his hands, from the same pose
	if gun_node != null and gun_body == null and vehicle == null:
		compute_muzzle()

# a far-off man riding: between his full updates he's just carried along with his seat
func rider_glide() -> void:
	if vehicle == null or not is_instance_valid(vehicle) or parts.is_empty() or mount_t > 0.0:
		return
	var p0 = pos
	_place_in_seat()
	var d = pos - p0
	if d.length_squared() < 1e-8:
		return
	for b in parts:
		b.global_position += d
	if gun_node != null and gun_body == null:
		gun_node.global_position += d

func lod_unglide() -> void:
	pos -= glide_off
	phase -= glide_ph
	body_yaw -= glide_yaw
	aim_yaw -= glide_aim
	glide_off = Vector3.ZERO
	glide_ph = 0.0
	glide_yaw = 0.0
	glide_aim = 0.0

# far-off men don't cast shadows (dozens of little shadow casters were a big part of the frame cost)
static var horde_lean = true      # (off only for the before/after measurement in --zedtest)
func _far_shadows(on: bool) -> void:
	if zombie and horde_lean:
		on = false        # (a horde is a lot of bodies: none of them is drawn a second time for a shadow)
	var mode = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var off = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for b in parts:
		for c in b.get_children():
			if c is GeometryInstance3D:
				# (a pouch or a helmet strap never casts one: it can't be seen, and it's a draw each)
				var sz: Vector3 = c.get_aabb().size * c.scale.abs()
				c.cast_shadow = mode if maxf(sz.x, maxf(sz.y, sz.z)) >= 0.2 else off
	if gun_node != null:
		for c in gun_node.get_children():
			if c is GeometryInstance3D:
				var sz2: Vector3 = c.get_aabb().size * c.scale.abs()
				c.cast_shadow = mode if maxf(sz2.x, maxf(sz2.y, sz2.z)) >= 0.3 else off

# A man is some fifty separate pieces (pouches, canteen, belt, the bits of his helmet and rifle...), and
# every piece is a draw: far off, where they can't be told apart, only the big ones are drawn (the limbs
# and body, the helmet's crown and band, the vest, boots, hands and the body of the rifle).
var detail_list = null
var detail_hidden = false

func _detail_scan() -> void:
	detail_list = []
	for pi2 in range(parts.size()):
		var kids: Array = parts[pi2].find_children("*", "GeometryInstance3D", true, false)
		var best = null
		var best_v = 0.0
		var extra: Array = []
		for k in range(kids.size()):
			var g: GeometryInstance3D = kids[k]
			if k == 0:
				continue                  # the limb itself
			if g.visibility_range_end > 0.0:
				continue                  # (already only drawn close up)
			var ab: AABB = g.get_aabb()
			var sz: Vector3 = ab.size * g.scale
			var vol = sz.x * sz.y * sz.z
			var mat = g.material_override
			var keep = false
			if mat is StandardMaterial3D:
				var c: Color = mat.albedo_color
				# hands and faces, and anything in the side's own colour (the band round the helmet and arm)
				keep = c.is_equal_approx(skin) or c.is_equal_approx(G.TEAM_BAND[team])
			if keep:
				continue
			if vol > best_v:
				if best != null:
					extra.append(best)
				best = g
				best_v = vol
			else:
				extra.append(g)
		# (the biggest thing on each part stays: the helmet, the vest, the boot)
		if best != null and best_v < 0.0025:
			extra.append(best)
		detail_list.append_array(extra)
	if gun_node != null:
		var gk: Array = gun_node.find_children("*", "GeometryInstance3D", true, false)
		gk.sort_custom(func(a, b): return a.get_aabb().get_volume() * a.scale.x * a.scale.y * a.scale.z > b.get_aabb().get_volume() * b.scale.x * b.scale.y * b.scale.z)
		for k in range(2, gk.size()):
			if gk[k].visibility_range_end <= 0.0:
				detail_list.append(gk[k])

func _far_detail(hide: bool) -> void:
	if hide == detail_hidden or parts.is_empty():
		return
	if detail_list == null:
		_detail_scan()
	detail_hidden = hide
	for g in detail_list:
		if is_instance_valid(g):
			g.visible = not hide

# back to a real simulated body (falling, dying, climbing aboard)
func lod_wake() -> void:
	if not lod_frozen:
		return
	lod_frozen = false
	_far_shadows(true)
	_far_detail(false)
	for b in parts:
		b.freeze = false
		b.linear_velocity = vel

# the pose targets are eased a little, relative to where the soldier stands: the body still goes where he goes
# at once, but sudden pose changes (snapping aim, a foot hitting a step) blend over a few frames instead of jerking
var sm_off: Array = []
var sm_rot: Array = []

func _smooth_targets() -> void:
	if sm_off.size() != targets.size():
		sm_off = []
		sm_rot = []
		for t in targets:
			sm_off.append(t.origin - pos)
			sm_rot.append(t.basis.get_rotation_quaternion())
		return
	var a = 1.0 - exp(-G.DT * (22.0 if state == "alive" and vault == null else 60.0))
	for i in range(targets.size()):
		var tg: Transform3D = targets[i]
		var off: Vector3 = tg.origin - pos
		if off.distance_squared_to(sm_off[i]) > 0.36:
			sm_off[i] = off
			sm_rot[i] = tg.basis.get_rotation_quaternion()
			continue
		sm_off[i] = sm_off[i].lerp(off, a)
		var q: Quaternion = tg.basis.get_rotation_quaternion()
		var q0: Quaternion = sm_rot[i]
		if q0.dot(q) < 0.0:
			q = -q
		sm_rot[i] = q0.slerp(q, a).normalized()
		targets[i] = Transform3D(Basis(sm_rot[i]), pos + sm_off[i])

var shadow_init = false

func drive() -> void:
	if not shadow_init:
		shadow_init = true
		if not lod_frozen:
			_far_shadows(true)
	_compute_targets()
	var far = _lod_far()
	if (state == "alive" or state == "riding" or state == "getup") and not far:
		_smooth_targets()
	elif far:
		sm_off = []
	if far:
		if not lod_frozen or not parts[0].freeze:
			lod_frozen = true
			for b in parts:
				b.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
				b.freeze = true
			_far_shadows(false)
			_far_detail(true)
		for i in range(parts.size()):
			parts[i].global_transform = targets[i]
		return
	elif lod_frozen:
		lod_frozen = false
		_far_shadows(true)
		_far_detail(false)
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
	unsettle()
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
	dressings = 6 if c == "medic" else 2
	if c == "officer" and parts.size() > 2:
		# officers wear a peaked cap instead of a helmet
		# (every piece of the helmet goes, its rim and skirt too: the rim used to be left round his head
		# under the cap)
		for m in parts[2].get_children():
			if m is MeshInstance3D and (m.has_meta("helmet") or m.position.y > 0.05):
				m.visible = false
				m.remove_meta("helmet")
		var capm = _mat("cap", Color(0.42, 0.12, 0.1), false)
		_hpart(parts[2], "cyl", Vector3(0.3, 0.085, 0.31), Vector3(0, 0.1, 0), capm)
		_hpart(parts[2], "cyl", Vector3(0.35, 0.028, 0.36), Vector3(0, 0.15, -0.01), capm)
		_hpart(parts[2], "cyl", Vector3(0.2, 0.015, 0.14), Vector3(0, 0.062, -0.135), _mat("boot", Color(0.16, 0.14, 0.12), false))
		_hpart(parts[2], "cyl", Vector3(0.31, 0.03, 0.32), Vector3(0, 0.074, 0), _mat("band" + G.TEAM_BAND[team].to_html(), G.TEAM_BAND[team], false))
	if not zombie and parts.size() > 6 and not has_meta("kit_" + c):
		set_meta("kit_" + c, true)
		_class_kit(c)
	mines = 3 if c == "engineer" else 0
	satchels = 2 if c == "engineer" else 0
	kits = 3 if c == "engineer" else 0
	stickies = 2 if c == "at" else (1 if c == "engineer" else 0)
	rgren = 1 if c == "rifleman" and wid == "rifle" else 0
	if c == "radio":
		smokes = 3
		give_radio.call_deferred(true)
	if c == "at" and wid == "rpg":
		set_meta("launcher", "rpg")
		rockets = 6
	fausts = 0
	if c == "rifleman" and randf() < 0.35:
		fausts = 1
	elif c == "at":
		fausts = 2 if wid == "atrifle" else 1
	if c == "spotter" or c == "sniper":
		for o in G.soldiers:
			if o != self and o.team == team and o.state != "dead" and o.partner == null and ((c == "spotter" and o.cls == "sniper") or (c == "sniper" and o.cls == "spotter")):
				partner = o
				o.partner = self
				var sp = o if c == "sniper" else self
				var sn = self if c == "sniper" else o
				sp.order = {"mode": "follow", "who": sn, "point": null}
				break

# what each kind of soldier carries, so you can tell them apart at a glance (front is -z, back +z)
func _class_kit(c: String) -> void:
	var wood = _mat("kwood", Color(0.42, 0.3, 0.18), false)
	var steel = _mat("ksteel", Color(0.3, 0.31, 0.32), false)
	var khaki = _mat("kkhaki", Color(0.5, 0.46, 0.34), false)
	var bz = 0.17 if Faction.militia(team) else 0.3        # militia carry no pack
	match c:
		"medic":
			# white armband and red crosses on the helmet sides, a medical bag on the hip
			var white = _mat("kwhite", Color(0.92, 0.92, 0.88), false)
			var red = _mat("kred", Color(0.75, 0.1, 0.08), false)
			_mesh(parts[5], Vector3(0.145, 0.09, 0.145), Vector3(0, -0.02, 0), white)
			_mesh(parts[5], Vector3(0.15, 0.025, 0.15), Vector3(0, -0.02, 0), red)
			for x in [-1.0, 1.0]:
				_mesh(parts[2], Vector3(0.012, 0.09, 0.09), Vector3(x * 0.16, 0.12, 0.0), white)
				_mesh(parts[2], Vector3(0.016, 0.065, 0.02), Vector3(x * 0.163, 0.12, 0.0), red)
				_mesh(parts[2], Vector3(0.016, 0.02, 0.065), Vector3(x * 0.163, 0.12, 0.0), red)
			_mesh(parts[0], Vector3(0.1, 0.15, 0.2), Vector3(-0.22, -0.02, 0.02), white)
			_mesh(parts[0], Vector3(0.104, 0.05, 0.02), Vector3(-0.22, -0.02, 0.02), red)
			_mesh(parts[0], Vector3(0.104, 0.02, 0.06), Vector3(-0.22, -0.02, 0.02), red)
		"engineer":
			# an entrenching shovel strapped to the pack, a tool roll on the belt
			_mesh(parts[1], Vector3(0.035, 0.5, 0.035), Vector3(0.1, 0.0, bz), wood)
			_mesh(parts[1], Vector3(0.16, 0.19, 0.02), Vector3(0.1, -0.3, bz + 0.01), steel)
			_mesh(parts[0], Vector3(0.22, 0.08, 0.08), Vector3(0.0, -0.04, 0.17), khaki)
		"mg":
			# a belt of rounds slung across the chest and a spare ammo tin on the hip
			var brass = _mat("kbrass", Color(0.72, 0.56, 0.2), false)
			var belt = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = Vector3(0.07, 0.62, 0.035)
			belt.mesh = bm
			belt.material_override = brass
			belt.position = Vector3(0, 0.02, -0.19)
			belt.rotation.z = 0.75
			belt.layers = 2
			parts[1].add_child(belt)
			_mesh(parts[0], Vector3(0.1, 0.15, 0.2), Vector3(-0.22, -0.03, 0.0), _mat("ktin", Color(0.28, 0.3, 0.22), false))
		"at":
			# two spare rockets in a carrier on the back
			for x in [-0.07, 0.07]:
				_mesh(parts[1], Vector3(0.08, 0.62, 0.08), Vector3(x, 0.08, bz + 0.02), _mat("ktube", Color(0.3, 0.33, 0.24), false))
				_mesh(parts[1], Vector3(0.09, 0.05, 0.09), Vector3(x, 0.4, bz + 0.02), steel)
		"assault":
			# grenades hung on the chest straps
			for k in range(3):
				_mesh(parts[1], Vector3(0.06, 0.08, 0.06), Vector3((k - 1) * 0.1, 0.12, -0.2), _mat("kgren", Color(0.25, 0.29, 0.2), false))
		"sniper", "spotter":
			# scrim and strips of hessian on the helmet and shoulders break up the outline
			var hess = [_mat("kh1", Color(0.4, 0.36, 0.24), false), _mat("kh2", Color(0.28, 0.33, 0.18), false)]
			for k in range(9):
				var m = MeshInstance3D.new()
				var bm2 = BoxMesh.new()
				bm2.size = Vector3(0.05, randf_range(0.12, 0.22), 0.012)
				m.mesh = bm2
				m.material_override = hess[k % 2]
				m.layers = 2
				var on_head = k < 5
				var a = randf() * TAU
				m.position = (Vector3(cos(a) * 0.15, 0.1, sin(a) * 0.15) if on_head else Vector3(randf_range(-0.2, 0.2), 0.2, randf_range(-0.1, 0.12)))
				m.rotation = Vector3(randf_range(-0.6, 0.6), a, randf_range(-0.4, 0.4))
				(parts[2] if on_head else parts[1]).add_child(m)
		"officer":
			# binoculars round the neck and a map case on the hip
			_mesh(parts[1], Vector3(0.16, 0.07, 0.06), Vector3(0, 0.1, -0.2), _mat("kbino", Color(0.12, 0.12, 0.11), false))
			_mesh(parts[0], Vector3(0.05, 0.18, 0.22), Vector3(0.21, -0.04, 0.0), _mat("kcase", Color(0.36, 0.22, 0.12), false))

# a general: gold braid on the cap, shoulder boards and a Sam Browne belt
func general_look() -> void:
	var gold = _mat("gold", Color(0.86, 0.68, 0.22), false)
	_hpart(parts[2], "cyl", Vector3(0.315, 0.04, 0.325), Vector3(0, 0.135, 0), gold)
	for x in [0.17, -0.17]:
		_mesh(parts[1], Vector3(0.12, 0.03, 0.15), Vector3(x, 0.255, 0), gold)
	var brown = _mat("belt", Color(0.3, 0.17, 0.08), false)
	_mesh(parts[1], Vector3(0.44, 0.05, 0.27), Vector3(0, -0.2, 0), brown)
	_mesh(parts[1], Vector3(0.05, 0.5, 0.26), Vector3(0.06, 0.0, 0), brown)
	_mesh(parts[1], Vector3(0.1, 0.06, 0.02), Vector3(-0.1, 0.12, -0.125), _mat("ribbons", Color(0.7, 0.15, 0.12), false))

# out of ammunition for the main gun: fall back on the pistol
func to_sidearm() -> bool:
	if wid == "pistol" or primary != null:
		return false
	primary = [wid, mag, reserve]
	var long_gun = wid
	set_weapon("pistol")
	_sling(long_gun)
	return true

func from_sidearm() -> void:
	if primary == null:
		return
	set_weapon(primary[0])
	mag = primary[1]
	reserve = primary[2]
	primary = null
	_sling("")

# the empty rifle goes over the shoulder while he fights on with the pistol
var slung: Node3D = null

func _sling(w: String) -> void:
	if slung != null and is_instance_valid(slung):
		slung.queue_free()
	slung = null
	if w == "" or parts.size() < 2 or not G.WEAPONS.has(w) or G.WEAPONS[w]["rocket"] or w == "pfaust":
		return
	slung = Node3D.new()
	for p in G.gun_model(w, team, id):
		var mi = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(p[3], p[4], p[5])
		mi.mesh = bm
		mi.material_override = _mat("gun" + p[6].to_html(false), p[6], false)
		mi.position = Vector3(p[0], p[1], p[2])
		if p.size() > 7:
			mi.rotation.x = p[7]
		mi.layers = 2
		slung.add_child(mi)
	parts[1].add_child(slung)
	# diagonally across the back, muzzle up over the left shoulder
	slung.position = Vector3(0.05, -0.12, 0.32 if not Faction.militia(team) else 0.18)
	slung.transform.basis = Basis(Vector3(0, 0, 1), 1.1) * Basis(Vector3(1, 0, 0), -PI / 2.0)

# bayonets go on for a charge, and stay on
const BAYONET_GUNS = ["rifle", "carbine", "bar"]

func fix_bayonet() -> bool:
	if has_meta("bayonet") or not (wid in BAYONET_GUNS) or zombie:
		return false
	set_meta("bayonet", true)
	_bayonet_mesh()
	return true

func _bayonet_mesh() -> void:
	if not has_meta("bayonet") or not (wid in BAYONET_GUNS) or gun_node == null:
		return
	# the muzzle end of the gun model: the furthest-forward part
	var front = -1e9
	var by = 0.0
	for p in G.gun_model(wid, team, id):
		if p[2] + p[5] * 0.5 > front:
			front = p[2] + p[5] * 0.5
			by = p[1]
	var steel = _mat("bayo", Color(0.62, 0.63, 0.65), false)
	var blade = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(0.012, 0.028, 0.3)
	blade.mesh = bm
	blade.material_override = steel
	blade.position = Vector3(0, by - 0.035, front + 0.12)
	blade.layers = 2
	blade.name = "bayonet"
	gun_node.add_child(blade)
	var lug = MeshInstance3D.new()
	var lm = BoxMesh.new()
	lm.size = Vector3(0.03, 0.04, 0.05)
	lug.mesh = lm
	lug.material_override = _mat("bayolug", Color(0.2, 0.2, 0.2), false)
	lug.position = Vector3(0, by - 0.03, front - 0.02)
	lug.layers = 2
	gun_node.add_child(lug)

# ---------------------------------------------------------------- ladders
# the player walks into the foot of a ladder (or toward its top from the roof) to use it
func _ladder_check() -> void:
	if want.length_squared() < 1.0:
		return
	for T in G.world.towers:
		if not T.get("ladder", false):
			continue
		var n: Vector3 = T["n"]
		var lo: Vector3 = T["stair_bottom"]
		var hi: Vector3 = T["stair_top"]
		var wd = G.flat(want).normalized()
		if G.dist2d(pos, lo) < 0.9 and absf(pos.y - lo.y) < 0.8 and wd.dot(-n) > 0.6:
			start_climb(T, true)
			return
		if G.dist2d(pos, hi) < 0.9 and absf(pos.y - hi.y) < 0.8 and wd.dot(n) > 0.6:
			start_climb(T, false)
			return

func start_climb(T: Dictionary, up: bool) -> void:
	if climb != null or state != "alive":
		return
	climb = {"T": T, "up": up, "t": 0.0, "dur": 2.6, "p0": pos}
	_tr_begin(0.3, 3)
	release_ladder_gun(true)

func release_ladder_gun(hide: bool) -> void:
	if gun_node != null and vehicle == null:
		gun_node.visible = not hide

func _tick_climb() -> void:
	var c = climb
	var T: Dictionary = c["T"]
	c["t"] += G.DT / c["dur"]
	var k = clampf(c["t"], 0.0, 1.0)
	var kk = k if c["up"] else 1.0 - k
	var n: Vector3 = T["n"]
	var lad: Vector3 = T["lad_x"]
	var lo: Vector3 = T["stair_bottom"]
	var hi: Vector3 = T["stair_top"]
	var foot = Vector3(lad.x + n.x * 0.32, lo.y, lad.z + n.z * 0.32)
	# up the rungs, then over the parapet onto the roof
	if kk < 0.12:
		pos = lo.lerp(foot, kk / 0.12)
	elif kk < 0.82:
		pos = Vector3(foot.x, lerpf(lo.y, hi.y, (kk - 0.12) / 0.7), foot.z)
	else:
		pos = Vector3(foot.x, hi.y, foot.z).lerp(hi, (kk - 0.82) / 0.18)
	# (he walks the last step to the ladder: he used to be put at its foot, or at its head, the instant
	# the climb began, from up to a metre off)
	if c["t"] < 0.14 and c.has("p0"):
		var k0: float = c["t"] / 0.14
		pos = (c["p0"] as Vector3).lerp(pos, k0 * k0 * (3.0 - 2.0 * k0))
	vel = Vector3.ZERO
	want = Vector3.ZERO
	vy = 0.0
	# he turns to the ladder as he steps up to it, and his hands and feet go onto the rungs (and come off
	# them at the top) over a few frames rather than all at once
	var lyaw = atan2(-n.x, -n.z)
	body_yaw = G.turn_to(body_yaw, lyaw, 8.0 * G.DT)
	aim_yaw = G.turn_to(aim_yaw, lyaw, 8.0 * G.DT)
	aim_pitch = lerpf(aim_pitch, 0.0, 0.2)
	crouch = move_toward(crouch, 0.0, 3.5 * G.DT)
	ready_ = false
	stand_pose()
	var cw = smoothstep(0.05, 0.17, kk) * (1.0 - smoothstep(0.7, 0.83, kk))
	if cw > 0.0:
		var P0 = P.duplicate()
		var f = -n
		var r = Vector3(-f.z, 0, f.x)
		var ph = pos.y * 5.2
		var rail = Vector3(lad.x, 0, lad.z)
		var rh = rail + r * 0.2 + Vector3(0, pos.y + 1.55 + 0.14 * sin(ph), 0)
		var lh = rail - r * 0.2 + Vector3(0, pos.y + 1.55 - 0.14 * sin(ph), 0)
		P[8] = _reach(P[6], rh, 0.59)
		P[5] = _reach(P[3], lh, 0.59)
		P[7] = _ik(P[6], P[8], 0.3, 0.3, Vector3(0, -1, 0) + n * 0.6 + r * 0.4)
		P[4] = _ik(P[3], P[5], 0.3, 0.3, Vector3(0, -1, 0) + n * 0.6 - r * 0.4)
		for side in range(2):
			var sd = 1.0 if side == 1 else -1.0
			var hip = 12 if side == 1 else 9
			var fy = pos.y + 0.12 + 0.15 * sin(ph + (PI if side == 1 else 0.0))
			var ft = rail + r * sd * 0.12 + n * 0.05 + Vector3(0, fy, 0)
			P[hip + 2] = _reach(P[hip], ft, 0.88)
			P[hip + 1] = _ik(P[hip], P[hip + 2], 0.45, 0.45, n + Vector3(0, 0.3, 0))
		if cw < 1.0:
			for i in [4, 5, 7, 8, 10, 11, 13, 14]:
				P[i] = P0[i].lerp(P[i], cw)
		if cw > 0.5 and sin(ph) * sin(ph - 5.2 * 0.9 * G.DT) < 0.0:
			G.audio.step(pos)
	_tr_apply()
	strength = 0.5
	drive()
	if c["t"] >= 1.0:
		pos = hi if c["up"] else lo
		climb = null
		_tr_begin(0.3, 3)
		release_ladder_gun(false)

# into or out of deep water: the rifle goes over the shoulder, and comes back out on the far bank
func _swim_change() -> void:
	if swim:
		G.fx.splash(Vector3(pos.x, G.world.water_level(pos.x, pos.z), pos.z), 1.0)
		if gun_node != null:
			gun_node.visible = false
		ready_ = false
		burst = 0
		if not is_player and randf() < 0.3:
			G.fx.callout(self, G.pick(["It's deep!", "Swim for it!", "Keep your rifle dry!"]))
	elif gun_node != null and vehicle == null:
		gun_node.visible = true

# pull a panzerfaust off the back for a tank that's come close
func to_faust() -> bool:
	if fausts <= 0 or wid == "pfaust" or primary != null:
		return false
	primary = [wid, mag, reserve]
	set_weapon("pfaust")
	fire_cd = 0.6
	return true

# fired: throw the empty tube away and go back to the rifle
func spent_faust() -> void:
	if wid != "pfaust" or state == "dead":
		return
	var f = Vector3(sin(body_yaw), 0, cos(body_yaw))
	G.fx.debris(hand_r() + Vector3(0, 0.1, 0), Vector3(-f.z, 1.2, f.x) * 2.0 - f, 0.12, G.C_OLIVE)
	if fausts > 0:
		fausts -= 1
	if primary != null:
		from_sidearm()
	elif not is_player:
		set_weapon("rifle")

# ---------------------------------------------------------------- ammunition
func start_reload() -> bool:
	if reload_t > 0.0 or mag >= W["mag"] or reserve <= 0:
		return false
	reload_t = W["reload"]
	if not W["rocket"]:
		G.audio.reload_snd(pos)
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
	grenades = maxi(grenades, 1)
	smokes = maxi(smokes, 1)
	dressings = maxi(dressings, 6 if cls == "medic" else 2)
	if wid == "rpg":
		rockets = 5

# the walking dead: glowing eyes, a slack jaw, blood down the front, torn sleeves; brutes are bulked out
func _zombie_look(sk: Material, uni: Material, uni2: Material) -> void:
	var eye = _mat_glow("zeye", Color(0.95, 0.85, 0.35))
	var blood = _mat("zblood", Color(0.32, 0.05, 0.04), false)
	var dark = _mat("zrot", Color(0.22, 0.2, 0.17), false)
	for e in [-1.0, 1.0]:
		_mesh(parts[2], Vector3(0.05, 0.03, 0.02), Vector3(e * 0.06, 0.03, -0.126), eye)
	_mesh(parts[2], Vector3(0.12, 0.05, 0.05), Vector3(0, -0.11, -0.1), dark)
	_mesh(parts[2], Vector3(0.14, 0.04, 0.03), Vector3(0.03, 0.09, -0.12), blood)
	_mesh(parts[1], Vector3(0.22, 0.26, 0.02), Vector3(0.05, 0.02, -0.165), blood)
	_mesh(parts[1], Vector3(0.12, 0.14, 0.02), Vector3(-0.12, -0.14, -0.13), blood)
	_mesh(parts[1], Vector3(0.1, 0.1, 0.02), Vector3(0.1, -0.05, 0.155), dark)
	# one arm torn bare
	var bare = 3 if id % 2 == 0 else 5
	_mesh(parts[bare], Vector3(0.135, 0.33, 0.135), Vector3.ZERO, sk)
	_mesh(parts[bare + 1], Vector3(0.05, 0.08, 0.13), Vector3(0, 0.06, 0.02), blood)
	if ztype == "brute":
		_mesh(parts[1], Vector3(0.62, 0.5, 0.4), Vector3(0, 0.05, 0.02), sk)
		_mesh(parts[1], Vector3(0.56, 0.2, 0.36), Vector3(0, -0.2, 0.0), uni)
		for i in [3, 5]:
			_mesh(parts[i], Vector3(0.22, 0.36, 0.22), Vector3.ZERO, sk)
		for i in [4, 6]:
			_mesh(parts[i], Vector3(0.2, 0.32, 0.2), Vector3(0, -0.02, 0), sk)
			_mesh(parts[i], Vector3(0.16, 0.14, 0.16), Vector3(0, 0.17, 0), dark)
		_mesh(parts[2], Vector3(0.3, 0.2, 0.26), Vector3(0, -0.04, 0), sk)
	elif ztype == "runner":
		_mesh(parts[1], Vector3(0.38, 0.5, 0.2), Vector3.ZERO, sk)
		_mesh(parts[1], Vector3(0.3, 0.07, 0.21), Vector3(0, 0.08, 0.0), blood)
	elif ztype == "armored":
		# riot gear: helmet with a visor, a body armour vest and pads
		var riot = _mat("zriot", Color(0.13, 0.14, 0.15), false)
		_hpart(parts[2], "dome", Vector3(0.33, 0.52, 0.35), Vector3(0, 0.06, 0), riot)
		_mesh(parts[2], Vector3(0.24, 0.1, 0.02), Vector3(0, 0.02, -0.15), _mat("zvisor", Color(0.25, 0.3, 0.32), false))
		_mesh(parts[1], Vector3(0.5, 0.4, 0.34), Vector3(0, 0.04, 0), riot)
		for i in [3, 5, 7, 9]:
			_mesh(parts[i], Vector3(0.16, 0.14, 0.16), Vector3(0, 0.0, 0), riot)
	elif ztype == "bloater":
		# swollen and sickly green, the gut ready to burst
		var bloat = _mat("zbloat", Color(0.5, 0.56, 0.32), false)
		_mesh(parts[1], Vector3(0.62, 0.52, 0.5), Vector3(0, -0.04, -0.06), bloat)
		_mesh(parts[0], Vector3(0.5, 0.26, 0.42), Vector3(0, 0.02, -0.04), bloat)
		_mesh(parts[1], Vector3(0.18, 0.14, 0.03), Vector3(0.08, -0.08, -0.31), blood)
	elif ztype == "spitter":
		# thin, the jaw hanging open over a swollen, glowing throat
		var acid = _mat_glow("zacid", Color(0.55, 0.85, 0.15))
		_mesh(parts[2], Vector3(0.12, 0.1, 0.03), Vector3(0, -0.07, -0.13), _mat("zmouth", Color(0.08, 0.02, 0.02), false))
		_mesh(parts[2], Vector3(0.16, 0.12, 0.14), Vector3(0, -0.17, -0.03), acid)
		_mesh(parts[1], Vector3(0.36, 0.5, 0.2), Vector3.ZERO, sk)
		_mesh(parts[1], Vector3(0.1, 0.18, 0.02), Vector3(-0.05, 0.08, -0.11), acid)
	elif ztype == "crawler":
		for i in [8, 10]:
			for ch in parts[i].get_children():
				if ch is MeshInstance3D:
					ch.visible = false
			_mesh(parts[i], Vector3(0.15, 0.12, 0.15), Vector3(0, 0.18, 0), blood)

static func _mat_glow(key: String, col: Color) -> StandardMaterial3D:
	if mats.has(key):
		return mats[key]
	var m = StandardMaterial3D.new()
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mats[key] = m
	return m

# a field radio on the back: a big set in its canvas harness, a handset on a curly lead and a long whip aerial
var radio_pack: Node3D = null

func give_radio(on: bool) -> void:
	if on and radio_pack == null and parts.size() > 1 and not zombie:
		radio_pack = Node3D.new()
		var olive = _mat("radioset", Color(0.24, 0.27, 0.19), false)
		var dark = _mat("radioknob", Color(0.1, 0.1, 0.09), false)
		for b in [[Vector3(0.3, 0.38, 0.16), Vector3(0, 0, 0), olive], [Vector3(0.31, 0.06, 0.17), Vector3(0, 0.16, 0), dark],
				[Vector3(0.05, 0.05, 0.03), Vector3(-0.08, 0.1, -0.09), dark], [Vector3(0.05, 0.05, 0.03), Vector3(0.0, 0.1, -0.09), dark],
				[Vector3(0.07, 0.14, 0.05), Vector3(0.19, -0.02, 0.03), dark], [Vector3(0.32, 0.04, 0.04), Vector3(0, -0.12, 0.08), olive]]:
			var m = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = b[0]
			m.mesh = bm
			m.position = b[1]
			m.material_override = b[2]
			radio_pack.add_child(m)
		var ant = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		cm.top_radius = 0.004
		cm.bottom_radius = 0.009
		cm.height = 0.8
		cm.radial_segments = 4
		ant.mesh = cm
		ant.material_override = dark
		ant.position = Vector3(0.1, 0.57, -0.03)
		ant.rotation = Vector3(-0.12, 0, -0.08)
		radio_pack.add_child(ant)
		# worn on the back, over the pack
		radio_pack.position = Vector3(0, 0.04, 0.3)
		radio_pack.rotation.y = PI
		parts[1].add_child(radio_pack)
		if leader_mark != null:
			leader_mark.visible = false
	elif not on and radio_pack != null:
		radio_pack.queue_free()
		radio_pack = null
		if leader_mark != null:
			leader_mark.visible = true

# squad leaders carry a radio with a tall antenna so you can pick them out
func set_leader(v: bool) -> void:
	if zombie or zombie_next != "":
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
	var u: Vector3 = (parts[1].global_basis.y)
	u = u - gun_dir * u.dot(gun_dir)
	if u.length_squared() < 1e-4:
		u = Vector3.UP - gun_dir * gun_dir.y
	u = u.normalized()
	# The weapon rides on top of the hands, not through the middle of them: the hand on the fore-end
	# cups it from underneath and the other is down on the pistol grip. (It used to be threaded through
	# both fists like a spit.)
	grip += u * 0.052
	muzzle = grip + gun_dir * (W["len"] - 0.24)
	var want_xf = Transform3D(Basis(u.cross(gun_dir), u, gun_dir), grip)
	if state == "alive" and not is_player and not lod_frozen:
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
	# a little hysteresis so the gun doesn't flick up and down against a wall edge
	var hit = not G.ray(from, from + a * L, G.L_WORLD).is_empty()
	if hit != gun_blocked:
		clip_n += 1
		if clip_n >= 3:
			gun_blocked = hit
			clip_n = 0
	else:
		clip_n = 0

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
	if climb != null:
		climb = null
		release_ladder_gun(false)
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
	fall_t = 0.0
	down_t = t if t > 0.0 else randf_range(1.2, 2.2)
	gu = null; ads = false; task = null; flee = null; prone = false; prone_t = false; vault = null; hand_t = null; hands_t = null; throw_t = 0.0; route = null; vy = 0.0

var death_style = ""
var fall_t = 0.0

func go_dead() -> void:
	if climb != null:
		climb = null
		release_ladder_gun(false)
	# how this one goes down
	# where they were hit shapes how they go down
	var r = randf()
	if wound_part == 2 and r < 0.65:
		death_style = "limp"            # a head shot: everything just stops
	elif wound_part >= 7 and r < 0.6:
		death_style = "knees"           # legs go first
	elif (wound_part == 3 or wound_part == 4 or wound_part == 5 or wound_part == 6) and r < 0.5:
		death_style = "clutch"
	else:
		var styles = ["slump", "knees", "clutch", "stagger", "spin", "forward", "twist", "reach", "sitback"]
		death_style = styles[randi() % styles.size()]
	# a wall or sandbags right at his back or side: he slides down it and ends up sitting against it
	if death_style != "limp" and state == "alive" and randf() < 0.75:
		var c: Vector3 = parts[1].global_position
		for col in G.world.cols_in_rect(c.x - 0.9, c.z - 0.9, c.x + 0.9, c.z + 0.9):
			if col.alive and col.hi.y > pos.y + 0.8 and col.lo.y < pos.y + 0.6 and col.prop != 1 and not col.has_meta("tree"):
				var nearest = Vector3(clampf(c.x, col.lo.x, col.hi.x), c.y, clampf(c.z, col.lo.z, col.hi.z))
				var to = G.flat(nearest - c)
				if to.length() < 0.8 and to.length() > 0.05:
					death_style = "wall"
					set_meta("wall_dir", to.normalized())
					break
	settled = false
	if vehicle != null:
		dismount(true)
	if state == "chute":
		_drop_chute()
	if state != "dead":
		compute_muzzle()
		drop_gun()
		if not zombie and not Faction.militia(team) and randf() < 0.45:
			drop_helmet()
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
	RadioPack.on_death(self)
	state = "dead"
	strength = 0.0
	dead_t = 0.0
	gu = null; task = null; flee = null; hand_t = null; hands_t = null; vault = null; prone = false; prone_t = false
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
	if not has_meta("pilot"):
		bleed = maxf(bleed, 0.45)
	bandage_t = 0.0
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
	# nobody goes over a wall while looking the other way: a beat to turn and face it first
	var vyaw = atan2(tx - pos.x, tz - pos.z)
	var turn_first = absf(G.wrap_a(body_yaw - vyaw)) > 0.9
	var cx = (c.lo.x + c.hi.x) * 0.5
	var cz = (c.lo.z + c.hi.z) * 0.5
	# a window: dive through low, and the glass goes if it's still in
	var win = G.world.inside_at(cx, c.hi.y + 1.4, cz)
	vault = {"a": pos, "b": Vector3(tx, ty, tz), "h": maxf(0.2, c.hi.y - maxf(pos.y, ty) + (0.02 if win else 0.15)), "t": -0.45 if turn_first else 0.0, "dive": win, "top": c.hi.y}
	if win:
		var pane = Doors.pane_near(Vector3(cx, c.hi.y + 0.6, cz), 1.4)
		if pane != null:
			Doors.shatter(pane)
		if not is_player and randf() < 0.25:
			G.fx.callout(self, G.pick(["Through the window!", "Going in the window!"]))
	return true

# ---------------------------------------------------------------- per-tick update
static var beam_mat: ShaderMaterial = null

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
		# the lens, its flare, a beam that stops at the first wall and a pool of light where it lands
		var lp = Lamp.make(flashlight, 22.0, 0.16, 0.03, false)
		lp.position = Vector3(0, 0, 0.075)
		lp.name = "lamp"
	if flashlight != null:
		flashlight.visible = want
		if want:
			Lamp.update(flashlight.get_node("lamp"), get_viewport().get_camera_3d())

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

var flat_t = 0.0

var exc_veh = null
var exc_t = 0.0

func _exc_tick() -> void:
	if exc_veh == null:
		return
	var v = exc_veh
	var clear = not is_instance_valid(v) or G.sim_time > exc_t or (vault == null and G.dist2d(pos, v.pos) > v.spec["len"] * 0.5 + v.spec["wid"] * 0.5 + 0.6)
	if not clear:
		return
	exc_veh = null
	if is_instance_valid(v) and is_instance_valid(v.body) and vehicle != v:
		for b in parts:
			b.remove_collision_exception_with(v.body)

var _full_mask = true

# a man down (dead, wounded, knocked flat) is a ragdoll and collides with everything again. If he goes
# down overlapping a vehicle or wreck, the physics shoves him out of it hard enough to throw him across
# the map: ignore the vehicle he's in for a moment, and never let a limb fly faster than a real fall
# A man who's gone down with part of him under the ground (a leg or his whole lower half through the
# surface, which a fast fall or a shove from a vehicle can do: the earth is a thin skin with nothing
# underneath) is lifted until the deepest part of him is back on top of it.
var bury_t = 0
var bury_n = 0
func _unbury() -> bool:
	# (a handful of tries, then he's left be: where the ground he's lying in isn't where the map says
	# it is, lifting him again and again would only keep him twitching)
	if G.world == null or parts.is_empty() or state == "riding" or state == "chute" or bury_n >= 6:
		return false
	var deep = 0.0
	for b in parts:
		var bp: Vector3 = b.global_position
		deep = maxf(deep, G.world.ground_y(bp.x, bp.z) - 0.1 - bp.y)
	if deep < 0.08:
		return false
	bury_n += 1
	var up = Vector3(0, deep + 0.12, 0)
	for b in parts:
		b.global_position += up
		if not b.freeze:
			var lv: Vector3 = b.linear_velocity
			b.linear_velocity = Vector3(lv.x * 0.3, maxf(lv.y, 0.0), lv.z * 0.3)
	return true

func _ragdoll_guard() -> void:
	if state == "alive" or parts.is_empty():
		return
	bury_t += 1
	if bury_t % 20 == 0:
		_unbury()
	if parts[0].freeze:
		return
	# pushed down through the ground (a lorry driving over a man who's been knocked flat does it: the
	# earth is a surface with nothing under it, and once a body was through it fell for ever and the man
	# never got up): lift him back onto it
	var p0: Vector3 = parts[0].global_position
	if G.world != null and state != "riding" and state != "chute":
		var g0: float = G.world.ground_y(p0.x, p0.z)
		if p0.y < g0 - 0.45:
			var up = Vector3(0, g0 + 0.25 - p0.y, 0)
			for b in parts:
				b.global_position += up
				var lv: Vector3 = b.linear_velocity
				b.linear_velocity = Vector3(lv.x * 0.3, maxf(lv.y, 0.0), lv.z * 0.3)
	var lim = 7.0
	for b in parts:
		var v: Vector3 = b.linear_velocity
		if v.y > 3.5:
			v.y = 3.5
		var h = Vector2(v.x, v.z)
		if h.length() > lim:
			h = h.normalized() * lim
		if v.y < -14.0:
			v.y = -14.0
		b.linear_velocity = Vector3(h.x, v.y, h.y)

# Standing men are moved by their own legs, not shoved about by the physics: their limbs don't collide
# with vehicles, wrecks or flying debris (that's what flung men into the air beside a burnt-out car or
# when a lorry nudged them). Once they go down they're ragdolls again and land on all of it properly.
func _sync_mask() -> void:
	var full = state != "alive"
	if full == _full_mask or parts.is_empty():
		return
	_full_mask = full
	if full and exc_veh == null and vehicle == null:
		# going down right against a vehicle: don't collide with it for a few seconds
		for v in G.vehicles:
			if is_instance_valid(v) and is_instance_valid(v.body) and G.dist2d(v.pos, pos) < v.spec["len"] * 0.5 + 1.2:
				for b in parts:
					b.add_collision_exception_with(v.body)
				exc_veh = v
				exc_t = G.sim_time + 4.0
				break
	for b in parts:
		if b.collision_layer == G.L_BODY:
			b.collision_mask = (G.L_WORLD | G.L_BODY | G.L_DEBRIS | G.L_VEH) if full else (G.L_WORLD | G.L_BODY)

func tick() -> void:
	# a body that's come to rest has nothing left to work out but whether what it lies on is still there
	if state == "dead" and settled and pooled and dragger == null and carried_by == null and glint == null and flashlight == null and tool_node == null and carried == null and detector == null:
		dead_t += G.DT
		if (int(dead_t * 60.0) + id) % 120 == 0:
			_check_support()
			# and the dead, far from the view, are drawn as plainly as the far-off living (and cast no shadow)
			var cam = get_viewport().get_camera_3d()
			if cam != null and parts.size() > 0:
				var ld: float = G.settings["lod_dist"]
				var far_b = cam.global_position.distance_squared_to(parts[0].global_position) > ld * ld
				if far_b != detail_hidden:
					_far_detail(far_b)
					_far_shadows(not far_b)
		return
	_sync_mask()
	_exc_tick()
	_ragdoll_guard()
	if prone and state == "alive" and vehicle == null:
		flat_t -= G.DT
		if flat_t <= 0.0:
			flat_t = 1.0
			G.world.flatten_grass(pos + Vector3(sin(aim_yaw), 0, cos(aim_yaw)) * 0.45, 0.75, Vector3(sin(aim_yaw), 0, cos(aim_yaw)), 90.0)
	if heat > 0.0:
		heat = maxf(0.0, heat - 0.16 * G.DT)
	if cls == "sniper" and wid == "sniper":
		_glint_tick()
	elif glint != null:
		glint.visible = false
	if light_on or flashlight != null:
		_flashlight_tick()
	if wid == "lmg" or wid == "atrifle":
		_bipod_tick()
	if detector != null and (task != "sweep" or state != "alive"):
		detector.queue_free()
		detector = null
	# tools and loads put down as soon as they're not being used this moment
	if tool_node != null and (state != "alive" or G.sim_time - tool_node.get_meta("seen", 0.0) > 0.1):
		tool_node.queue_free()
		tool_node = null
	if carried != null and (state != "alive" or G.sim_time - carried.get_meta("seen", 0.0) > 0.25):
		carried.queue_free()
		carried = null
	callout_cd -= G.DT
	hurt_t -= G.DT
	if bleed > 0.0 and state != "dead":
		Medical.tick(self)
		if state == "dead":
			return
	if burn_t > 0.0 and state != "dead":
		_burn()
	# hands that were busy with a job (a dressing, a crate) go back to the rifle once the job stops
	if hands_t != null and has_meta("work_hands_t") and G.sim_time - get_meta("work_hands_t") > 0.12:
		hands_t = null
		hand_t = null
		remove_meta("work_hands_t")
	match state:
		"dead":
			if dead_t < 0.9 and not lod_frozen:
				_death_motion()
			# whatever knocked him about (a blast, a vehicle, the physics catching a limb), a body doesn't
			# go sailing up into the air
			if not settled and not lod_frozen and (int(dead_t * 60.0) % 3 == 0):
				Combat._cap(self, 9.0)
			dead_t += G.DT
			_settle()
			if settled and (int(dead_t * 60.0) + id) % 120 == 0:
				_check_support()
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
	if state != "dead" and not hidden_in_vehicle:
		compute_muzzle()

# the last moments: buckling at the knees, hands going to the wound, staggering back, spinning round
func _death_motion() -> void:
	var t = dead_t
	var up = Vector3.UP
	match death_style:
		"knees":
			if t < 0.35:
				parts[0].linear_velocity.y = minf(parts[0].linear_velocity.y, -1.6)
				for i in [8, 10]:
					parts[i].linear_velocity += Vector3(sin(body_yaw), 0, cos(body_yaw)) * 0.35
				parts[1].linear_velocity = parts[1].linear_velocity.lerp(Vector3(0, -0.6, 0), 0.15)
		"clutch":
			var wp = wound_part if wound_part >= 0 and wound_part < parts.size() else 1
			var tgt: Vector3 = parts[wp].global_position
			for i in [4, 6]:
				var to = tgt - parts[i].global_position
				if to.length() > 0.12:
					parts[i].linear_velocity = parts[i].linear_velocity.lerp(to / G.DT * 0.12, 0.4)
		"stagger":
			if t < 0.45:
				var back = -Vector3(sin(body_yaw), 0, cos(body_yaw))
				for i in [0, 1, 2]:
					var lv: Vector3 = parts[i].linear_velocity
					if G.flat(lv).length() < 2.6:
						parts[i].linear_velocity = lv + back * (0.22 if i == 0 else 0.3)
		"spin":
			if t < 0.05:
				var sp = (1.0 if id % 2 == 0 else -1.0) * randf_range(4.0, 7.0)
				parts[1].angular_velocity += up * sp
				parts[0].angular_velocity += up * sp * 0.6
		"forward":
			# topples forward onto the face, the knees giving way under him
			if t < 0.4:
				var fw = Vector3(sin(body_yaw), 0, cos(body_yaw))
				parts[1].linear_velocity += fw * 0.28
				parts[2].linear_velocity += fw * 0.32
				parts[0].linear_velocity.y = minf(parts[0].linear_velocity.y, -0.8)
		"twist":
			# turns half away as one leg folds
			if t < 0.3:
				var sd = 1.0 if id % 2 == 0 else -1.0
				parts[1].angular_velocity += up * sd * 0.5
				parts[8 if id % 2 == 0 else 10].linear_velocity.y = minf(parts[8 if id % 2 == 0 else 10].linear_velocity.y, -1.4)
		"reach":
			# one arm comes up and out, then everything sags
			if t < 0.45:
				var hand = 6 if id % 2 == 0 else 4
				var fw2 = Vector3(sin(body_yaw), 0, cos(body_yaw))
				parts[hand].linear_velocity = parts[hand].linear_velocity.lerp(fw2 * 1.4 + Vector3(0, 1.6 - t * 4.0, 0), 0.3)
				parts[0].linear_velocity.y = minf(parts[0].linear_velocity.y, -0.9)
		"wall":
			# back to the wall: the chest leans into it while the hips slide down and out, so he ends up
			# sitting slumped against it with his legs out in front
			var wd: Vector3 = get_meta("wall_dir", Vector3.FORWARD)
			if t < 0.9:
				parts[1].linear_velocity = parts[1].linear_velocity.lerp(wd * 0.9 + Vector3(0, -0.5, 0), 0.25)
				parts[2].linear_velocity = parts[2].linear_velocity.lerp(wd * 0.7 + Vector3(0, -0.3, 0), 0.2)
				parts[0].linear_velocity = parts[0].linear_velocity.lerp(-wd * 0.6 + Vector3(0, -1.4, 0), 0.25)
				for i in [8, 10]:
					parts[i].linear_velocity = parts[i].linear_velocity.lerp(-wd * 1.2, 0.2)
		"sitback":
			# drops to the seat, then rolls back
			if t < 0.3:
				parts[0].linear_velocity.y = minf(parts[0].linear_velocity.y, -2.0)
			elif t < 0.7:
				var bk = -Vector3(sin(body_yaw), 0, cos(body_yaw))
				parts[1].linear_velocity += bk * 0.22
				parts[2].linear_velocity += bk * 0.26

# once a body has come to rest it stops twitching: more damping, and it's frozen in place until
# something (a blast, a vehicle, being dragged) moves it again
var settled = false

func _settle() -> void:
	if settled or lod_frozen or parts.is_empty() or dragger != null or carried_by != null:
		return
	if dead_t > 1.4 and dead_t < 1.45:
		for b in parts:
			b.linear_damp = 1.6
			b.angular_damp = 3.5
	if dead_t > (2.0 if zombie and horde_lean else 3.0) and int(dead_t * 60.0) % 15 == 0:
		# (a body that never quite stops twitching is put to rest anyway after a while: left alone it was
		# simulated for as long as it lay there. The dead of a horde sooner than anyone.)
		var give_up = dead_t > (4.0 if zombie and horde_lean else 9.0)
		for b in parts:
			if not give_up and (b.linear_velocity.length_squared() > 0.02 or b.angular_velocity.length_squared() > 0.1):
				return
		# (not left half in the ground: lifted clear first, and given another moment to come to rest)
		if _unbury():
			return
		settled = true
		for b in parts:
			b.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
			b.freeze = true
			# the dead are out of everyone's way: nobody trips over or drives into a body that's lying still
			b.collision_layer = CORPSE_LAYER
			b.collision_mask = G.L_WORLD

const CORPSE_LAYER = 64

# a body left hanging in the air (what it lay on was blown away or drove off) drops to the ground
func _check_support() -> void:
	if not settled or parts.is_empty() or dragger != null or carried_by != null:
		return
	var p: Vector3 = parts[0].global_position
	var sy = G.world.surface_y(p.x, p.z, p.y)
	if p.y - sy > 0.55 and G.ray(p, p - Vector3(0, 0.75, 0), G.L_WORLD | G.L_VEH).is_empty():
		unsettle()
		for b in parts:
			b.collision_layer = CORPSE_LAYER
			b.collision_mask = G.L_WORLD

func unsettle() -> void:
	if not settled:
		return
	settled = false
	dead_t = 1.5
	for b in parts:
		b.freeze = false
		b.linear_damp = 0.1
		b.angular_damp = 1.0

# knocked down next to a wall: put a hand out to catch yourself
func _brace() -> void:
	var ch: Vector3 = parts[1].global_position
	var v: Vector3 = G.flat(parts[1].linear_velocity)
	if v.length() < 0.6:
		return
	var hit = G.ray(ch, ch + v.normalized() * 1.2, G.L_WORLD)
	if hit.is_empty():
		return
	var hp: Vector3 = hit.position + Vector3(0, 0.1, 0)
	var hand = 6 if v.normalized().dot(Vector3(-cos(body_yaw), 0, sin(body_yaw))) >= 0.0 else 4
	var to = hp - parts[hand].global_position
	parts[hand].linear_velocity = parts[hand].linear_velocity.lerp(to / G.DT * 0.25, 0.5)
	parts[1].linear_velocity *= 0.9

func _tick_down() -> void:
	fall_t += G.DT
	if fall_t < 0.9:
		_brace()
	supp = maxf(0.0, supp - 0.3 * G.DT)
	down_t -= G.DT
	if down_t <= 0.0 and (parts[0].linear_velocity.length() < 1.2 or fall_t > 9.0):
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
	supp = maxf(0.0, supp - 0.3 * G.DT)
	if hp <= 0.0:
		Combat.cause = "bleed"
		Combat.kill(self, last_attacker, false)
		return
	if has_meta("stretcher") and get_meta("stretcher")["stage"] == 1:
		# lying on a stretcher: the bearers carry the body, nothing to do here
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
		# held under both arms: each of the dragger's hands has one of his shoulders
		var hl: Vector3 = dragger.hand_l()
		var hr: Vector3 = dragger.hand_r()
		var a3 = 3
		var a5 = 5
		if parts[3].global_position.distance_squared_to(hl) > parts[5].global_position.distance_squared_to(hl):
			a3 = 5
			a5 = 3
		var tg = {1: (hl + hr) * 0.5 + Vector3(0, -0.08, 0), a3: hl, a5: hr}
		for i in tg:
			var b: RigidBody3D = parts[i]
			b.linear_velocity = b.linear_velocity.lerp((tg[i] - b.global_position) / G.DT * 0.3, 0.6)
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
		bleed = 0.0
		heal_t = 0.0
		if medic and is_instance_valid(medic):
			medic.task = null
			medic.patient = null
			medic.hand_t = null
		medic = null
		start_getup()
		G.fx.callout(self, "Thanks!")

# turning eases in and out instead of starting and stopping dead
var yaw_v = 0.0

func _turn_body(goal: float, max_rate: float) -> void:
	var d = G.wrap_a(goal - body_yaw)
	var want_v = clampf(d * 7.0, -max_rate, max_rate)
	yaw_v = lerpf(yaw_v, want_v, minf(1.0, G.DT * 11.0))
	if absf(d) < absf(yaw_v * G.DT):
		body_yaw = goal
		yaw_v = 0.0
	else:
		body_yaw += yaw_v * G.DT

func _tick_alive() -> void:
	# a man on his feet who has ended up under the ground (got up from where a vehicle pushed him through
	# it, say) is put back on top of it
	bury_t += 1
	if bury_t % 30 == 0 and vehicle == null and vault == null and climb == null and not swim and G.world != null:
		var sy0: float = G.world.surface_y(pos.x, pos.z, pos.y + 0.6)
		if sy0 - pos.y > 0.9:
			pos.y = sy0
			vy = 0.0
	supp = maxf(0.0, supp - 0.3 * G.DT)
	radio_cd = maxf(0.0, radio_cd - G.DT) if is_player else radio_cd
	stun = maxf(0.0, stun - G.DT)
	var thr_before = throw_t
	throw_t = maxf(0.0, throw_t - G.DT)
	if has_meta("throw_pending") and throw_t > 0.0:
		_show_nade(true, str((get_meta("throw_pending") as Array)[1]))
	elif nade_mesh != null and nade_mesh.visible:
		_show_nade(false)
	if throw_t <= 0.0 and has_meta("thrust"):
		remove_meta("thrust")
		if has_meta("spade"):
			# (the spade goes back on his pack and the rifle comes off his shoulder again)
			remove_meta("spade")
			if tool_node != null and is_instance_valid(tool_node):
				tool_node.visible = false
			if gun_node != null and vehicle == null and gun_body == null and state == "alive":
				gun_node.visible = true
	if has_meta("throw_pending") and thr_before > Combat.THROW_AT and throw_t <= Combat.THROW_AT:
		Combat.release_throw(self)
		# and down for a moment while it goes off
		if not is_player:
			set_meta("duck_after_t", G.sim_time + 1.2)
	for r in range(5):
		limb[r] = minf(1.0, limb[r] + 1.1 * G.DT)
	if is_player:
		G.pc.player_update(self)
		if bandage_t > 0.0:
			Medical.bandage_tick(self)
	elif PERF:
		var pt0 = Time.get_ticks_usec()
		AI.update(self)
		pf[0] += Time.get_ticks_usec() - pt0
	else:
		AI.update(self)
	if state != "alive":
		climb = null
		return
	if climb != null:
		_tick_climb()
		return
	if is_player:
		_ladder_check()
	var sm: float = W["speed"] * (0.3 if prone else 1.0)
	if has_meta("leg_wound"):
		# hobbling on the good leg; leaning on a mate he goes a little better
		sm *= 0.6 if has_meta("helper") else 0.38
	# water: wading slows you down the deeper it gets; past chest height you swim, rifle slung
	var was_swim = swim
	swim = false
	var swim_y = 0.0
	if not G.world.water.is_empty() and G.world.in_water(pos.x, pos.z):
		var wl = G.world.water_level(pos.x, pos.z)
		var dep = wl - G.world.ground_y(pos.x, pos.z)
		prone_t = false
		if dep > 1.25:
			swim = true
			swim_y = wl - 1.3
			sm *= 0.3
		else:
			sm *= lerpf(0.7, 0.42, clampf(dep / 1.25, 0.0, 1.0))
	if swim != was_swim:
		_swim_change()
	if vault != null:
		vault["t"] += G.DT / 0.6
		var vt = clampf(vault["t"], 0.0, 1.0)
		var k = G.smooth01(vt)
		var a: Vector3 = vault["a"]
		var b: Vector3 = vault["b"]
		pos = a.lerp(b, k)
		pos.y += sin(PI * vt) * vault["h"]
		vel = G.flat(b - a) / 0.6
		# eyes and body on where they're going while they're over the top
		var over_yaw = atan2(b.x - a.x, b.z - a.z)
		body_yaw = G.turn_to(body_yaw, over_yaw, 9.0 * G.DT)
		if not is_player:
			aim_yaw = G.turn_to(aim_yaw, over_yaw, 9.0 * G.DT)
			aim_pitch = lerpf(aim_pitch, 0.0, 0.2)
		crouch = 1.0 if vault.get("dive", false) else 0.55
		if vault["t"] >= 1.0:
			pos = b
			vault = null
	else:
		vel.x += clampf(want.x * sm - vel.x, -12.0 * G.DT, 12.0 * G.DT)
		vel.z += clampf(want.z * sm - vel.z, -12.0 * G.DT, 12.0 * G.DT)
		pos.x += vel.x * G.DT
		pos.z += vel.z * G.DT
		# a man lying still isn't shoved along the ground by his mates (that slid prone men about)
		var still_flat = prone and want.length_squared() < 0.04
		var skip_crowd = still_flat or (lod_frozen and (Engine.get_physics_frames() + id) % 4 != 0)
		for o in ([] if skip_crowd else G.soldiers_near(pos)):
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
		for v in ([] if skip_crowd and not still_flat else G.vehicles):
			if absf(pos.x - v.pos.x) > 9.0 or absf(pos.z - v.pos.z) > 9.0:
				continue
			# the body as it's really built (a bonnet sticking out past the spec length, say), plus a margin
			var ex: Array = VehExt.extents(v)
			var lp: Vector3 = v.global_transform.affine_inverse() * Vector3(pos.x, v.pos.y + 0.5, pos.z)
			var m = 0.32
			if lp.x > ex[0].x - m and lp.x < ex[1].x + m and lp.z > ex[0].z - m and lp.z < ex[1].z + m and absf(pos.y - v.pos.y) < 2.5:
				# out by the nearest side
				var dl = [lp.x - (ex[0].x - m), (ex[1].x + m) - lp.x, lp.z - (ex[0].z - m), (ex[1].z + m) - lp.z]
				var mi = 0
				for q in range(1, 4):
					if dl[q] < dl[mi]:
						mi = q
				var push_l = [Vector3(-dl[0], 0, 0), Vector3(dl[1], 0, 0), Vector3(0, 0, -dl[2]), Vector3(0, 0, dl[3])][mi]
				pos += v.global_transform.basis * push_l
		var bnd: Rect2 = G.world.bounds
		pos.x = clampf(pos.x, bnd.position.x, bnd.end.x)
		pos.z = clampf(pos.z, bnd.position.y, bnd.end.y)
		var sy: float = G.world.surface_y(pos.x, pos.z, pos.y)
		if swim:
			pos.y = move_toward(pos.y, maxf(sy, swim_y), 2.5 * G.DT)
			vy = 0.0
		elif sy >= pos.y - 0.06 and vy >= 0.0:
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
		if not ready_:
			goal = my            # just walking: face the way you're going
		_turn_body(goal, 6.0)
		turning = false
	else:
		var dd = G.wrap_a(aim_yaw - body_yaw)
		if absf(dd) > 0.8:
			turning = true
		if turning or dragging != null:
			_turn_body(aim_yaw, 3.6)
		else:
			yaw_v = lerpf(yaw_v, 0.0, minf(1.0, G.DT * 10.0))
			if absf(dd) < 0.12:
				turning = false
	if prone and spd > 0.25 and not zombie and mud_stage < 3 and not swim:
		Wear.mud_tick(self, G.DT)
	var ph0 = sin(phase)
	phase += (spd * (5.0 if prone else (2.3 if zombie else gait_k(spd))) * (zgait if zombie else 1.0) + (6.0 if turning and zombie else 0.0) + (9.0 if stumble > 0.0 else 0.0)) * G.DT
	# how hard he's speeding up, slowing or swerving: the body leans with it
	acc_lp = acc_lp.lerp((Vector3(vel.x, 0, vel.z) - pvel) / G.DT, 0.18)
	pvel = Vector3(vel.x, 0, vel.z)
	if ph0 * sin(phase) < 0.0 and (spd > 0.8 or stumble > 0.0) and not prone:
		if not G.world.water.is_empty() and G.world.in_water(pos.x, pos.z):
			if not _lod_far():
				G.fx.ripple(Vector3(pos.x, G.world.water_level(pos.x, pos.z), pos.z), 0.7 if swim else 0.5)
			G.audio.splash(pos, swim)
		else:
			G.audio.step(pos)
			if not zombie and vehicle == null:
				G.fx.footprint(pos, body_yaw, sin(phase) > 0.0)
	stumble = maxf(0.0, stumble - G.DT)
	kick_t = maxf(0.0, kick_t - G.DT)
	# far away in a big battle: pose and body only every third tick, and no balance checks
	var far = _lod_far()
	if not far:
		check_gun_clip()
	if PERF:
		var pt1 = Time.get_ticks_usec()
		_pose_now()
		var pt2 = Time.get_ticks_usec()
		strength = 0.42 * (1.0 - 0.8 * minf(1.0, stun / 0.25))
		drive()
		pf[1] += pt2 - pt1
		pf[2] += Time.get_ticks_usec() - pt2
	else:
		_pose_now()
		strength = 0.42 * (1.0 - 0.8 * minf(1.0, stun / 0.25))
		drive()
	# balance: if the body gets pushed away from the legs, step after it or fall
	# (not while he's still getting up off the ground or landing from a vault: his body is low then because
	# it's meant to be, and checking it knocked every man flat again the moment he started to rise)
	if not far and not prone and vault == null and vy == 0.0 and G.sim_time - tr_t0 > tr_dur + 0.3:
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
	if v.team < 0 and v.has_meta("derelict"):
		Salvage.claim(v, team)
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
	gun_node.visible = v.spec["seats"][i]["role"] != "gunner" and v.spec["seats"][i]["pose"] != "push"
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
	var delay = 0.0
	var rear = false
	if is_instance_valid(v):
		var side = Vector3(cos(v.yaw), 0, -sin(v.yaw))
		var o: Vector3 = v.spec["seats"][seat]["o"]
		var role: String = v.spec["seats"][seat]["role"]
		rear = role == "pass" and v.kind in ["truck", "halftrack", "ambulance", "radar"] and not eject
		if rear:
			# troops hop down over the tailgate one after another and fan out behind
			var k = seat - 1
			delay = k * 0.35
			var fan = (1.0 if k % 2 == 0 else -1.0) * (0.5 + 0.35 * (k / 2))
			out = v.pos - v.forward() * (v.spec["len"] * 0.5 + 1.1 + 0.45 * (k / 2)) + side * fan
		else:
			side *= 1.0 if o.x >= 0.0 else -1.0
			out = v.pos + side * (v.spec["wid"] * 0.5 + 0.9) + v.forward() * o.z
		# never out past the edge of the map (the hills there would throw him back in)
		var bd: Rect2 = G.world.bounds.grow(-3.0)
		out.x = clampf(out.x, bd.position.x, bd.end.x)
		out.z = clampf(out.z, bd.position.y, bd.end.y)
		out = G.world.push_out_circle(out, 0.35)[0]
		if rear and G.world.inside_any(out.x, out.z, 0.3):
			out = G.world.push_out_circle(v.pos + side * (v.spec["wid"] * 0.5 + 1.0), 0.35)[0]
		if hidden_in_vehicle and v.turret != null:
			start = v.turret.global_position + Vector3(0, 0.9, 0) - Vector3(0, 0.95, 0)
		# keep ignoring the hull until he's clear of it: his body starts inside it, and letting the physics
		# push the two apart flings him into the air (it looked like the men blew up on getting out)
		exc_veh = v
		exc_t = G.sim_time + 2.5
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
		vault = {"a": start, "b": out, "t": -delay / 0.6, "h": 0.6 if rear else 0.3}
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
		if mount_t <= 0.0 and (vehicle.spec["seats"][seat]["pose"] == "hidden" or (vehicle.sealed(seat) and not is_player)):
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
		# (now and then is enough: nobody can see it in there)
		if (Engine.get_physics_frames() + id) % 12 < 3:
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
	if spose == "push" and v.kind == "atgun" and v.atload_t > 0.0 and absf(v.speed) < 0.3:
		_atgun_feed(v)
		strength = 0.5
		drive()
		return
	if spose == "push":
		# leaning into the gun's trail handles, walking it forward
		ready_ = false
		crouch = 0.35
		var vf: Vector3 = v.forward()
		vel = vf * v.speed
		phase += absf(v.speed) * 2.6 * G.DT
		aim_yaw = body_yaw
		hand_t = pos + vf * 0.55 + Vector3(0, 0.62, 0)
		stand_pose()
		hand_t = null
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
	if role == "gunner" and v.kind == "mortar" and v.load_t > 0.0:
		_mortar_drill(v)
	elif role == "gunner" and v.kind == "atgun" and v.atload_t > 0.0 and v.turret != null:
		_atgun_drill(v)
	elif role == "gunner" and v.belt_t > 0.0 and v.turret != null:
		_belt_drill(v)
	elif role == "gunner":
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

# loading a mortar: crouch to the ammo box at his side, lift a round, hold it over the tube, let it go,
# then turn away with his hands over his ears as it fires
func _mortar_drill(v) -> void:
	ready_ = false
	var k = 1.0 - v.load_t / 1.9
	var uf = Vector3(sin(aim_yaw), 0, cos(aim_yaw))
	var ur = Vector3(-cos(aim_yaw), 0, sin(aim_yaw))
	var tube: Vector3 = v.muzzle()
	var box: Vector3 = pos + ur * 0.38 + uf * 0.12 + Vector3(0, 0.25, 0)
	var over = tube + Vector3(0, 0.3, 0)
	var ears = P[0] if P.size() > 0 else pos + Vector3(0, 1.5, 0)
	var held: Vector3
	if k < 0.18:
		crouch = lerpf(0.3, 0.9, k / 0.18)
		held = (pos + uf * 0.3 + Vector3(0, 0.9, 0)).lerp(box, k / 0.18)
	elif k < 0.45:
		crouch = lerpf(0.9, 0.45, (k - 0.18) / 0.27)
		held = box.lerp(over, (k - 0.18) / 0.27)
	elif k < 0.66:
		crouch = 0.45
		held = over.lerp(tube + Vector3(0, 0.05, 0), (k - 0.45) / 0.21)
	else:
		crouch = 0.85
		held = Vector3.ZERO
	stand_pose()
	if held != Vector3.ZERO:
		hand_t = held
		hands_t = [held - ur * 0.06 + Vector3(0, -0.06, 0), held + ur * 0.06 + Vector3(0, 0.06, 0)]
		if v.round_mesh != null:
			v.round_mesh.global_position = held
			v.round_mesh.global_rotation = Vector3.ZERO
	else:
		# ducking: both hands up over his ears
		var hp: Vector3 = parts[2].global_position if parts.size() > 2 else ears
		hand_t = hp
		hands_t = [hp - ur * 0.13, hp + ur * 0.13]
	_arms_and_gun(0.0, false, uf, ur, uf)
	hand_t = null
	hands_t = null

# reloading the anti-tank gun: down to the ammo box beside the trail for a shell, swing it up behind the
# breech, ram it home with both hands, and back on the sights
func _atgun_drill(v) -> void:
	ready_ = false
	var k = 1.0 - v.atload_t / 2.3
	var uf = Vector3(sin(aim_yaw), 0, cos(aim_yaw))
	var ur = Vector3(-cos(aim_yaw), 0, sin(aim_yaw))
	var gd: Vector3 = v._gun_dir()
	var breech: Vector3 = v.gun_pivot.global_position - gd * 0.25
	var behind = breech - gd * 0.45 + Vector3(0, 0.05, 0)
	var grip: Vector3 = v.turret.global_position + gd * 0.25 + Vector3(0, 0.15, 0)
	var box: Vector3 = pos + ur * 0.42 - uf * 0.1 + Vector3(0, 0.28, 0)
	# with a man at the trail he passes the round up; on his own the gunner fetches it from the box
	var feeder = v.driver() != null and v.driver() != self
	var take: Vector3 = v.gun_pivot.global_position - gd * 0.95 + Vector3(0, -0.05, 0)
	var held = Vector3.ZERO
	var reach = Vector3.ZERO        # one hand out for something, the other on the gun
	var t0 = 0.45 if feeder else 0.3      # when the round is in his hands
	if feeder:
		if k < 0.3:
			crouch = 0.2
		elif k < 0.45:
			crouch = 0.25
			reach = grip.lerp(take, (k - 0.3) / 0.15)
		elif k < 0.6:
			crouch = 0.25
			held = take.lerp(behind, (k - 0.45) / 0.15)
	else:
		if k < 0.12:
			crouch = lerpf(0.2, 0.85, k / 0.12)
			reach = box
		elif k < 0.3:
			crouch = 0.85
			held = box
		elif k < 0.6:
			crouch = lerpf(0.85, 0.3, (k - 0.3) / 0.3)
			held = box.lerp(behind, (k - 0.3) / 0.3)
	if k >= 0.6 and k < 0.8:
		crouch = 0.3
		held = behind.lerp(breech + gd * 0.1, (k - 0.6) / 0.2)
	elif k >= 0.8:
		crouch = 0.25
	stand_pose()
	if held != Vector3.ZERO:
		hand_t = held
		var along = k >= t0
		hands_t = [held - gd * 0.2 + Vector3(0, -0.04, 0), held + gd * 0.12 + Vector3(0, 0.02, 0)] if along else [held - ur * 0.08, held + ur * 0.08]
		if v.round_mesh != null:
			v.round_mesh.visible = true
			v.round_mesh.global_position = held
			# lying along the barrel once it's lifted, upright while it comes out of the box
			v.round_mesh.global_basis = Basis.looking_at(gd, Vector3.UP) * Basis(Vector3(1, 0, 0), PI / 2.0) if along else Basis()
	else:
		if v.round_mesh != null and (not feeder or k >= 0.6):
			v.round_mesh.visible = false
		hand_t = grip
		hands_t = [reach, grip] if reach != Vector3.ZERO else null
	_arms_and_gun(0.0, false, uf, ur, uf)
	hand_t = null
	hands_t = null

# the man at the trail feeds the gun: bends to the shell box at his feet, lifts a round and holds it
# out to the gunner, who takes it at the breech (see _atgun_drill)
func _atgun_feed(v) -> void:
	ready_ = false
	var k = 1.0 - v.atload_t / 2.3
	var vf: Vector3 = v.forward()
	var vr = Vector3(vf.z, 0, -vf.x)
	aim_yaw = atan2(vf.x, vf.z)
	body_yaw = G.turn_to(body_yaw, aim_yaw, 6.0 * G.DT)
	var uf = Vector3(sin(aim_yaw), 0, cos(aim_yaw))
	var ur = Vector3(-cos(aim_yaw), 0, sin(aim_yaw))
	var box: Vector3 = pos - vr * 0.5 + Vector3(0, 0.25, 0)
	var hand_over: Vector3 = v.gun_pivot.global_position - v._gun_dir() * 0.95 + Vector3(0, -0.05, 0)
	var held = Vector3.ZERO
	if k < 0.15:
		crouch = lerpf(0.3, 0.9, k / 0.15)
	elif k < 0.3:
		crouch = 0.9
		held = box
	elif k < 0.45:
		crouch = lerpf(0.9, 0.2, (k - 0.3) / 0.15)
		held = box.lerp(hand_over, (k - 0.3) / 0.15)
	else:
		crouch = 0.3
	stand_pose()
	if held != Vector3.ZERO:
		hand_t = held
		hands_t = [held - ur * 0.09, held + ur * 0.09]
		if v.round_mesh != null:
			v.round_mesh.visible = true
			v.round_mesh.global_position = held
			v.round_mesh.global_basis = Basis(Vector3.UP, aim_yaw) * Basis(Vector3(1, 0, 0), PI / 2.0)
	else:
		hand_t = pos + uf * 0.45 + Vector3(0, 0.62, 0) if k >= 0.45 else box
	_arms_and_gun(0.0, false, uf, ur, uf)
	hand_t = null
	hands_t = null

# changing the belt on a mounted MG: one hand flips the feed cover up, the other brings the new belt from
# the box and lays it in, then the cover is slapped shut and the hands go back to the grips
func _belt_drill(v) -> void:
	ready_ = false
	var k = 1.0 - v.belt_t / 3.4
	var uf = Vector3(sin(aim_yaw), 0, cos(aim_yaw))
	var ur = Vector3(-cos(aim_yaw), 0, sin(aim_yaw))
	var grip: Vector3 = v.turret.global_position + v._gun_dir() * 0.25 + Vector3(0, 0.15, 0)
	var tray: Vector3 = v.turret.global_position + v._gun_dir() * 0.45 + Vector3(0, 0.3, 0)
	var cover_up = tray + Vector3(0, 0.22, 0) - v._gun_dir() * 0.05
	var box: Vector3 = pos + ur * 0.32 + uf * 0.1 + Vector3(0, 0.55, 0)
	var lh: Vector3
	var rh: Vector3
	if k < 0.2:
		rh = grip.lerp(cover_up, k / 0.2)
		lh = grip.lerp(box, k / 0.2)
	elif k < 0.5:
		rh = cover_up
		lh = box.lerp(tray, (k - 0.2) / 0.3)
	elif k < 0.8:
		rh = cover_up
		lh = tray + ur * (0.08 * sin((k - 0.5) * 30.0))
	elif k < 0.9:
		rh = cover_up.lerp(tray + Vector3(0, 0.04, 0), (k - 0.8) / 0.1)
		lh = tray.lerp(grip, (k - 0.8) / 0.1)
	else:
		rh = (tray + Vector3(0, 0.04, 0)).lerp(grip, (k - 0.9) / 0.1)
		lh = grip
	crouch = 0.2
	stand_pose()
	hand_t = grip
	hands_t = [lh, rh]
	_arms_and_gun(0.0, false, uf, ur, uf)
	hand_t = null
	hands_t = null

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
var chute_lines: Array = []

func start_chute(at: Vector3) -> void:
	state = "chute"
	chute_lines = []
	pos = at
	vel = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	chute = Node3D.new()
	var canopy = MeshInstance3D.new()
	canopy.mesh = canopy_mesh()
	var cm = StandardMaterial3D.new()
	cm.vertex_color_use_as_albedo = true
	cm.albedo_color = G.TEAM_UNI[team].lerp(Color(0.8, 0.8, 0.75), 0.4)
	cm.cull_mode = BaseMaterial3D.CULL_DISABLED
	cm.roughness = 0.9
	canopy.material_override = cm
	canopy.position = Vector3(0, 4.2, 0)
	chute.add_child(canopy)
	chute.set_meta("canopy", canopy)
	for k in range(4):
		var line = MeshInstance3D.new()
		var lm = BoxMesh.new()
		lm.size = Vector3(0.025, 1.0, 0.025)
		line.mesh = lm
		line.material_override = _mat("line", Color(0.2, 0.2, 0.2), false)
		line.top_level = true
		chute.add_child(line)
		chute_lines.append(line)
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
		# the canopy swings over him like a pendulum and breathes as the air spills out of it
		chute.global_position = pos + Vector3(0, 0.9, 0)
		chute.rotation.z = sin(G.sim_time * 1.3 + seed_) * 0.11
		chute.rotation.x = sin(G.sim_time * 0.9 + seed_ * 1.7) * 0.08
		var cn = chute.get_meta("canopy")
		var br = 1.0 + sin(G.sim_time * 2.6 + seed_) * 0.035
		cn.scale = Vector3(br, 2.0 - br, br)
	ready_ = false
	stand_pose()
	strength = 0.35
	# hands up on the risers above each shoulder
	var lsh: Vector3 = parts[3].global_transform * Vector3(0, -0.15, 0)
	var rsh: Vector3 = parts[5].global_transform * Vector3(0, -0.15, 0)
	hand_t = (lsh + rsh) * 0.5 + Vector3(0, 0.45, 0)
	hands_t = [lsh + Vector3(0, 0.42, 0), rsh + Vector3(0, 0.42, 0)]
	drive()
	_chute_lines(lsh, rsh)
	if pos.y <= gy + 0.05:
		hand_t = null
		hands_t = null
		pos.y = gy
		_drop_chute(true)
		state = "alive"
		strength = 0.42
		think = 0.0
		decide_t = 0.0
		# a parachute landing fall: feet, then roll; then out of the harness and a look round before moving off
		set_meta("landed", 2.6)
		if randf() < 0.6 and not is_player:
			fall(0.75)

# the rigging: the two lines on each side of the canopy run down to the harness at that shoulder
func _chute_lines(lsh: Vector3, rsh: Vector3) -> void:
	if chute == null or chute_lines.size() < 4:
		return
	var xf: Transform3D = chute.global_transform
	var fwd = Vector3(sin(body_yaw), 0, cos(body_yaw))
	var right = Vector3(-cos(body_yaw), 0, sin(body_yaw))
	var lside = 1.0 if (lsh - rsh).dot(right) > 0.0 else -1.0
	var rim = [right * lside + fwd, right * lside - fwd, -right * lside + fwd, -right * lside - fwd]
	for k in range(4):
		var top: Vector3 = xf * Vector3(0, 4.2, 0) + (xf.basis * rim[k]).normalized() * 2.35
		var bot: Vector3 = (lsh if k < 2 else rsh) + Vector3(0, 0.06, 0)
		var d = top - bot
		var L = d.length()
		if L < 0.01:
			continue
		var y = d / L
		var x = y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		var z = x.cross(y)
		chute_lines[k].global_transform = Transform3D(Basis(x, y * L, z), (top + bot) * 0.5)

func _drop_chute(landed: bool = false) -> void:
	chute_lines = []
	if chute == null:
		return
	if not landed or not is_instance_valid(chute):
		chute.queue_free()
		chute = null
		return
	# on the ground the canopy keeps going a little way downwind and collapses flat, and stays there a while
	var c = chute
	chute = null
	for k in c.get_children():
		if k != c.get_meta("canopy"):
			k.queue_free()
	var wind = Vector3(sin(G.sim_time * 0.1) * 1.5, 0, 0.6).normalized()
	var gy: float = G.world.ground_y(pos.x, pos.z)
	var end_p = pos + wind * 4.0
	end_p.y = G.world.ground_y(end_p.x, end_p.z) - 4.05
	var tw = c.create_tween()
	tw.set_parallel(true)
	tw.tween_property(c, "global_position", end_p, 1.6).set_ease(Tween.EASE_IN)
	tw.tween_property(c, "rotation", Vector3(wind.z * 1.2, 0, -wind.x * 1.2), 1.6)
	tw.tween_property(c.get_meta("canopy"), "scale", Vector3(1.15, 0.06, 1.15), 1.6).set_ease(Tween.EASE_IN)
	tw.chain().tween_property(c, "rotation", Vector3.ZERO, 0.4)
	tw.chain().tween_interval(30.0)
	tw.chain().tween_callback(c.queue_free)

# a dome of eight gores in two shades, with a vent hole at the top and a scalloped skirt
static var _canopy_mesh: ArrayMesh = null

static func canopy_mesh() -> ArrayMesh:
	if _canopy_mesh != null:
		return _canopy_mesh
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg = 32
	var rings = 7
	var R = 2.4
	var H = 1.6
	var pts = []
	for r in range(rings + 1):
		var row = []
		var ph = lerpf(0.16, PI * 0.5, float(r) / rings)      # 0.16 rad leaves the vent open at the crown
		for k in range(seg + 1):
			var a = TAU * k / seg
			# between the lines the cloth bellies out, so the skirt is scalloped
			var bulge = 1.0 + 0.05 * absf(sin(a * 4.0)) * (float(r) / rings)
			var rr = sin(ph) * R * bulge
			var y = cos(ph) * H - (0.12 * (1.0 - absf(sin(a * 4.0))) if r == rings else 0.0)
			row.append(Vector3(cos(a) * rr, y, sin(a) * rr))
		pts.append(row)
	for r in range(rings):
		for k in range(seg):
			var gore = int(k / 4) % 2
			var c = Color(1, 1, 1) if gore == 0 else Color(0.78, 0.78, 0.74)
			var a = pts[r][k]
			var b = pts[r][k + 1]
			var cc = pts[r + 1][k + 1]
			var d = pts[r + 1][k]
			for q in [a, cc, b, a, d, cc]:
				st.set_color(c)
				st.add_vertex(q)
	# the vent's rim, a little darker
	st.generate_normals()
	_canopy_mesh = st.commit()
	return _canopy_mesh

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
