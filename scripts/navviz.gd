class_name NavViz
extends Node3D
# Path debug view (F9): every man's planned walk, every vehicle's route and where it's aiming, each
# side's remembered danger spots, and the whole-trip route of the first selected man. For working out
# why a unit went the way it did.

var mi: MeshInstance3D
var on = false
var t = 0.0

func _ready() -> void:
	mi = MeshInstance3D.new()
	mi.mesh = ImmediateMesh.new()
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.no_depth_test = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.visible = false

func toggle() -> void:
	on = not on
	mi.visible = on
	t = 0.0
	G.ui.message("Path debug on: routes, vehicle aim points, danger spots (F9 to hide)" if on else "Path debug off")

func _process(dt: float) -> void:
	if not on or not G.started:
		return
	t -= dt
	if t > 0.0:
		return
	t = 0.2
	_draw()

func _line(im: ImmediateMesh, a: Vector3, b: Vector3, c: Color) -> void:
	im.surface_set_color(c)
	im.surface_add_vertex(a)
	im.surface_set_color(c)
	im.surface_add_vertex(b)

func _ring(im: ImmediateMesh, p: Vector3, r: float, c: Color) -> void:
	var y = G.world.ground_y(p.x, p.z) + 0.2
	for k in range(16):
		var a0 = k * TAU / 16.0
		var a1 = (k + 1) * TAU / 16.0
		_line(im, Vector3(p.x + cos(a0) * r, y, p.z + sin(a0) * r), Vector3(p.x + cos(a1) * r, y, p.z + sin(a1) * r), c)

func _cross(im: ImmediateMesh, p: Vector3, r: float, c: Color) -> void:
	var q = p + Vector3(0, 0.3, 0)
	_line(im, q + Vector3(-r, 0, -r), q + Vector3(r, 0, r), c)
	_line(im, q + Vector3(-r, 0, r), q + Vector3(r, 0, -r), c)

func _draw() -> void:
	var im: ImmediateMesh = mi.mesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var up = Vector3(0, 0.35, 0)
	for s in G.soldiers:
		if s.state != "alive" or s.vehicle != null:
			continue
		var col = Color(0.35, 0.65, 1.0, 0.75) if s.team == 0 else Color(1.0, 0.4, 0.35, 0.75)
		if s.path_i < s.path.size() and s.move_target != null:
			var prev: Vector3 = s.pos + up
			for i in range(s.path_i, s.path.size()):
				var q: Vector3 = s.path[i] + up
				_line(im, prev, q, col)
				prev = q
			if s.partial:
				_cross(im, s.path[s.path.size() - 1], 0.4, Color(1, 1, 1, 0.7))      # end of this leg
		if s.stuck_n > 0 or s.scramble != null:
			_cross(im, s.pos, 0.6, Color(1.0, 0.2, 1.0, 0.95))
		if s.door_wait > 0.0:
			_ring(im, s.pos, 0.5, Color(1.0, 1.0, 0.2, 0.9))
	for v in G.vehicles:
		if v.dead or v.spec.get("air", false) or v.spec.get("static", false):
			continue
		var vc = Color(1.0, 0.65, 0.15, 0.9)
		if v.path_i < v.path.size():
			var prev: Vector3 = v.pos + up * 2.0
			for i in range(v.path_i, v.path.size()):
				var q: Vector3 = v.path[i] + up * 2.0
				_line(im, prev, q, vc)
				prev = q
			_cross(im, v._pursuit(), 0.8, Color(1.0, 1.0, 0.3, 1.0))
		if v.convoy != null and v.convoy["lead"] != null and is_instance_valid(v.convoy["lead"]):
			_line(im, v.pos + up * 3.0, v.convoy["lead"].pos + up * 3.0, Color(0.5, 1.0, 0.5, 0.8))
		if v.yield_t > 0.0:
			_ring(im, v.pos, v.spec["len"] * 0.6, Color(1.0, 1.0, 0.2, 0.9))
		if v.has_meta("park"):
			_ring(im, v.get_meta("park"), 2.0, Color(0.4, 1.0, 0.9, 0.8))
	for team in range(2):
		var dc = Color(1.0, 0.15, 0.1, 0.8) if team == 0 else Color(1.0, 0.55, 0.1, 0.6)
		for d in Tactics.danger[team]:
			var age = G.sim_time - d["t"]
			if age > Tactics.DANGER_LIFE:
				continue
			_ring(im, d["p"], 3.0 + minf(9.0, d["w"] * 2.0) * (1.0 - age / Tactics.DANGER_LIFE), dc)
	# the whole-trip route the first selected man would take from here
	var sel = G.pc.selection if G.pc != null else []
	for s in sel:
		if is_instance_valid(s) and s.state == "alive" and s.move_target != null:
			var r: Array = G.world.find_route(s.pos, s.move_target, s.team)
			var prev: Vector3 = s.pos + up * 1.5
			for q in r:
				var qq: Vector3 = q + up * 1.5
				_line(im, prev, qq, Color(0.3, 1.0, 0.35, 0.95))
				prev = qq
			break
	_line(im, Vector3.ZERO, Vector3.ZERO, Color(0, 0, 0, 0))
	im.surface_end()
