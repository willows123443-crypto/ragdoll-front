class_name Props
extends RefCounted
# Materials and meshes that make the small things in the world read properly up close:
# leafy, gently moving foliage clumps, and proper filled sandbags of coarse sacking.

static var _fol_sh: Shader = null
static var _bag_sh: Shader = null
static var _mats = {}
static var _bag_mesh: ArrayMesh = null

const NOISE = """
float hash3(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 45.164))) * 43758.5453); }
float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}
"""

static func is_leafy(c: Color) -> bool:
	return c.g > c.r + 0.03 and c.g > c.b + 0.05

# a material for a static shape of this colour, or null to use the plain one
static func mat_for(c: Color, shape: String) -> Material:
	if shape == "blob" and is_leafy(c):
		return foliage(c)
	if shape == "leaves":
		return foliage(c, true)
	if shape == "pillow":
		return sacking(c)
	return null

static var _leaf_sh: Shader = null
static var _leaf_mesh: ArrayMesh = null

static func _fol_code(cards: bool) -> String:
	var cull = ", cull_disabled;" if cards else ";"
	var bend = "1.0" if cards else "0.65"
	var leafy = CARD_FRAG if cards else CLUMP_FRAG
	var code = FOL_A.replace("%CULL%", cull) + NOISE + FOL_B.replace("%BEND%", bend) + leafy + FOL_END
	return code

const FOL_A = """shader_type spatial;
render_mode diffuse_lambert_wrap%CULL%
uniform vec3 col = vec3(0.3, 0.37, 0.2);
varying vec3 wpos;
varying float lh;
varying vec3 inst;
"""
const FOL_B = """
void vertex() {
	lh = clamp(VERTEX.y + 0.5, 0.0, 1.0);
	inst = MODEL_MATRIX[3].xyz;
	// soft, rounded shading instead of facets: lean the normals out from the middle of the clump
	NORMAL = normalize(mix(NORMAL, normalize(VERTEX + vec3(0.0, 0.15, 0.0)), %BEND%));
	// a slow stir in the breeze, more at the top than the bottom
	float sw = sin(TIME * 1.1 + inst.x * 0.37 + inst.z * 0.29) + 0.4 * sin(TIME * 2.7 + inst.z * 0.8);
	VERTEX.x += sw * 0.018 * lh * lh;
	VERTEX.z += sw * 0.012 * lh * lh;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float n = vnoise(wpos * 6.5) * 0.55 + vnoise(wpos * 17.0) * 0.45;
	float iv = hash3(floor(inst * 2.0 + 0.5));
	vec3 c = col * (0.82 + 0.3 * iv);
	c = mix(c, c * vec3(1.15, 1.08, 0.75), 0.35 * vnoise(inst * 0.3 + wpos * 0.6));
	// dark and dense down inside, lighter leaves on top
	c *= mix(0.6, 1.12, smoothstep(0.05, 0.95, lh));
"""
const CARD_FRAG = """
	// each card is a little spray of pointed leaves
	vec2 q = UV * 2.0 - 1.0;
	float lf = 0.0;
	for (int k = 0; k < 3; k++) {
		float an = float(k) * 2.1 + 0.4;
		vec2 r = vec2(cos(an) * q.x + sin(an) * q.y, -sin(an) * q.x + cos(an) * q.y) - vec2(0.0, 0.32);
		float w = 0.36 * (1.0 - pow(clamp(abs(r.y) / 0.62, 0.0, 1.0), 1.6));
		lf = max(lf, step(abs(r.x), w) * step(abs(r.y), 0.62));
	}
	if (lf < 0.5) { discard; }
	c *= 0.85 + 0.35 * hash3(floor(wpos * 9.0));
"""
const CLUMP_FRAG = """
	// leaves: lit tips and dark gaps between them
	c *= 0.66 + 0.56 * n;
	c += step(0.8, n) * vec3(0.04, 0.06, 0.01);
"""
const FOL_END = """
	ALBEDO = c;
	ROUGHNESS = 0.82;
	SPECULAR = 0.25;
}"""

static func foliage(c: Color, cards: bool = false) -> ShaderMaterial:
	var key = ("l" if cards else "f") + c.to_html(false)
	if _mats.has(key):
		return _mats[key]
	if cards and _leaf_sh == null:
		_leaf_sh = Shader.new()
		_leaf_sh.code = _fol_code(true)
	if not cards and _fol_sh == null:
		_fol_sh = Shader.new()
		_fol_sh.code = _fol_code(false)
	var m = ShaderMaterial.new()
	m.shader = _leaf_sh if cards else _fol_sh
	m.set_shader_parameter("col", Vector3(c.r, c.g, c.b) * (1.28 if cards else 1.08))
	_mats[key] = m
	return m

static func sacking(c: Color) -> ShaderMaterial:
	var key = "s" + c.to_html(false)
	if _mats.has(key):
		return _mats[key]
	if _bag_sh == null:
		_bag_sh = Shader.new()
		_bag_sh.code = """shader_type spatial;
render_mode diffuse_lambert_wrap;
uniform vec3 col = vec3(0.64, 0.58, 0.44);
varying vec3 lp;
varying vec3 inst;
varying vec3 wpos;
""" + NOISE + """
void vertex() {
	lp = VERTEX;
	inst = MODEL_MATRIX[3].xyz;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float iv = hash3(floor(inst * 3.0 + 0.5));
	vec3 c = col * (0.84 + 0.26 * iv);
	// the coarse weave of the sacking
	float wv = sin(UV.x * 300.0) * 0.5 + sin(UV.y * 190.0) * 0.5;
	c *= 0.93 + 0.07 * wv;
	// creased and bunched up at the tied ends, shadowed underneath where it presses on the bag below
	float ends = smoothstep(0.3, 0.5, abs(lp.x));
	c *= 1.0 - 0.32 * ends * (0.6 + 0.4 * sin(UV.y * 44.0));
	c *= mix(0.62, 1.0, smoothstep(-0.42, 0.05, lp.y));
	// mud, damp and wear
	float d = vnoise(wpos * 3.0) * 0.6 + vnoise(wpos * 11.0) * 0.4;
	c = mix(c, c * vec3(0.66, 0.6, 0.52), smoothstep(0.55, 0.85, d) * 0.7);
	// the seam along the top
	c *= 1.0 - 0.18 * (1.0 - smoothstep(0.0, 0.02, abs(UV.y - 0.5))) * step(0.0, lp.y);
	ALBEDO = c;
	ROUGHNESS = 0.97;
	SPECULAR = 0.15;
}"""
	var m = ShaderMaterial.new()
	m.shader = _bag_sh
	m.set_shader_parameter("col", Vector3(c.r, c.g, c.b))
	_mats[key] = m
	return m

# a filled sandbag, its long side along x, inside a unit box: flat underneath, bulging at the middle,
# gathered in where it's tied at the ends
static func bag_mesh() -> ArrayMesh:
	if _bag_mesh != null:
		return _bag_mesh
	var NU = 16
	var NV = 18
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(NU + 1):
		var u = float(i) / NU
		var x = -0.5 + u
		var t = absf(x) / 0.5
		var taper = sqrt(maxf(0.0, 1.0 - pow(t, 5.0)))
		taper = maxf(taper, 0.06)
		var bulge = 1.0 + 0.07 * (1.0 - t * t)
		for j in range(NV + 1):
			var a = float(j) / NV * TAU
			var cy = -cos(a)
			var cz = sin(a)
			var sy = signf(cy) * pow(absf(cy), 0.62)
			var sz = signf(cz) * pow(absf(cz), 0.62)
			var y = sy * 0.5 * taper
			var z = sz * 0.5 * taper * bulge
			if y < -0.36:
				y = -0.36 + (y + 0.36) * 0.25
			# the ends are tied off a little higher than the middle sits
			y += 0.05 * t * t
			st.set_uv(Vector2(u, float(j) / NV))
			st.add_vertex(Vector3(x * (0.96 + 0.04 * taper), y, z))
	for i in range(NU):
		for j in range(NV):
			var a0 = i * (NV + 1) + j
			var b0 = a0 + NV + 1
			st.add_index(a0)
			st.add_index(b0)
			st.add_index(a0 + 1)
			st.add_index(a0 + 1)
			st.add_index(b0)
			st.add_index(b0 + 1)
	st.generate_normals()
	var m = st.commit()
	# make sure the faces point outwards
	var arr = m.surface_get_arrays(0)
	var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var vts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var top = 0
	for k in range(vts.size()):
		if vts[k].y > vts[top].y:
			top = k
	if nrm[top].y < 0.0:
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		for k in range(0, idx.size(), 3):
			var tmp = idx[k + 1]
			idx[k + 1] = idx[k + 2]
			idx[k + 2] = tmp
		for k in range(nrm.size()):
			nrm[k] = -nrm[k]
		arr[Mesh.ARRAY_INDEX] = idx
		arr[Mesh.ARRAY_NORMAL] = nrm
		m = ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_bag_mesh = m
	return m

# leaves sticking out all over a foliage clump, so it has a ragged leafy edge instead of a smooth ball
static func leaf_mesh() -> ArrayMesh:
	if _leaf_mesh != null:
		return _leaf_mesh
	var rg = RandomNumberGenerator.new()
	rg.seed = 4411
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var N = 34
	for i in range(N):
		# spread evenly over the sphere (a spiral), mostly the upper and outer parts
		var yy = 1.0 - 1.6 * (float(i) + 0.5) / N
		var rr = sqrt(maxf(0.0, 1.0 - yy * yy))
		var ph = float(i) * 2.39996
		var dir = Vector3(cos(ph) * rr, yy, sin(ph) * rr).normalized()
		var c = dir * rg.randf_range(0.42, 0.52)
		var sz = rg.randf_range(0.2, 0.3)
		# the card faces mostly outwards, tipped at random
		var t1 = dir.cross(Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT).normalized()
		var t2 = dir.cross(t1).normalized()
		var a = rg.randf_range(0.0, TAU)
		var ax = (t1 * cos(a) + t2 * sin(a)) * sz
		var ay = (-t1 * sin(a) + t2 * cos(a)) * sz + dir * sz * rg.randf_range(0.2, 0.6)
		var pts = [c - ax - ay, c + ax - ay, c + ax + ay, c - ax + ay]
		var uvs = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_normal(dir)
			st.set_uv(uvs[k])
			st.add_vertex(pts[k])
	_leaf_mesh = st.commit()
	return _leaf_mesh
