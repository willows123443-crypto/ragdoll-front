class_name Tex
extends RefCounted
# Procedural surface textures, made once at start-up: weathered plaster, brick, roof tiles and
# worn vehicle paint, each with a matching normal map. They're greyscale and get tinted by each
# material's colour, and laid on with triplanar mapping so plain boxes need no UVs.

static var cache = {}
const SZ = 128

static func _noise(freq: float, oct: int, seed_v: int) -> Image:
	var n = FastNoiseLite.new()
	n.seed = seed_v
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = oct
	var img: Image = n.get_seamless_image(SZ, SZ, false, false, 0.15, true)
	img.convert(Image.FORMAT_RGBA8)
	return img

static func _finish(key: String, img: Image, bump: Image, bump_scale: float) -> void:
	img.generate_mipmaps()
	var t = ImageTexture.create_from_image(img)
	var nb = bump.duplicate()
	nb.convert(Image.FORMAT_RGBA8)
	nb.bump_map_to_normal_map(bump_scale)
	nb.generate_mipmaps()
	cache[key] = [t, ImageTexture.create_from_image(nb)]

# grey value 0..1 of a noise image pixel
static func _v(img: Image, x: int, y: int) -> float:
	return img.get_pixel(posmod(x, SZ), posmod(y, SZ)).r

static func get_pair(kind: String) -> Array:
	if cache.has(kind):
		return cache[kind]
	match kind:
		"plaster":
			_plaster()
		"brick":
			_brick()
		"tiles":
			_tiles()
		"paint":
			_paint()
		_:
			_plain()
	return cache[kind]

# weathered render: soft blotches, fine grain, rain streaks running down, the odd crack
static func _plaster() -> void:
	var a = _noise(0.035, 4, 11)
	var g = _noise(0.4, 2, 12)
	var img = Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var bump = Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var streak = []
	for x in range(SZ):
		streak.append(0.0 if randf() > 0.12 else randf_range(0.03, 0.09))
	for y in range(SZ):
		for x in range(SZ):
			var v = 0.86 + 0.12 * _v(a, x, y) + 0.05 * (_v(g, x, y) - 0.5)
			v -= streak[x] * (1.0 - float(y) / SZ) * 0.8
			img.set_pixel(x, y, Color(v, v, v))
			var b = _v(g, x, y) * 0.6 + _v(a, x, y) * 0.4
			bump.set_pixel(x, y, Color(b, b, b))
	# a few hairline cracks
	for k in range(2):
		var x0 = randi() % SZ
		var y0 = randi() % SZ
		var dx = randf_range(-0.6, 0.6)
		for i in range(randi_range(8, 18)):
			var px = posmod(int(x0 + dx * i + randf_range(-0.6, 0.6)), SZ)
			var py = posmod(y0 + i, SZ)
			img.set_pixel(px, py, img.get_pixel(px, py).darkened(0.1))
			bump.set_pixel(px, py, Color(0.3, 0.3, 0.3))
	_finish("plaster", img, bump, 1.2)

# brick courses with mortar, each brick a slightly different shade
static func _brick() -> void:
	var g = _noise(0.3, 2, 21)
	var img = Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var bump = Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var bh = 8
	var bw = 16
	var shades = {}
	for y in range(SZ):
		var row = y / bh
		var off = (bw / 2) if row % 2 == 1 else 0
		for x in range(SZ):
			var col = posmod(x + off, SZ) / bw
			var key = row * 100 + col
			if not shades.has(key):
				shades[key] = randf_range(0.78, 1.0)
			var mortar = (y % bh) == 0 or (posmod(x + off, SZ) % bw) == 0
			var v = 0.62 if mortar else shades[key] + 0.08 * (_v(g, x, y) - 0.5)
			img.set_pixel(x, y, Color(v, v, v))
			var b = 0.2 if mortar else 0.75 + 0.2 * _v(g, x, y)
			bump.set_pixel(x, y, Color(b, b, b))
	_finish("brick", img, bump, 5.0)

# clay roof tiles: overlapping rows, a shadow under each row's lower edge
static func _tiles() -> void:
	var g = _noise(0.25, 2, 31)
	var img = Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var bump = Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var th = 10
	var tw = 12
	var shades = {}
	for y in range(SZ):
		var row = y / th
		var off = (tw / 2) if row % 2 == 1 else 0
		var k = float(y % th) / th
		for x in range(SZ):
			var col = posmod(x + off, SZ) / tw
			var key = row * 100 + col
			if not shades.has(key):
				shades[key] = randf_range(0.82, 1.0)
			var edge = (posmod(x + off, SZ) % tw) == 0
			var v = shades[key] * (0.7 + 0.3 * k) + 0.06 * (_v(g, x, y) - 0.5)
			if edge:
				v *= 0.8
			img.set_pixel(x, y, Color(v, v, v))
			var b = k * 0.8 + (0.0 if edge else 0.15)
			bump.set_pixel(x, y, Color(b, b, b))
	_finish("tiles", img, bump, 4.0)

# vehicle paint: brushed-on blotches, chipped and scratched edges, a little dust
static func _paint() -> void:
	var a = _noise(0.05, 3, 41)
	var g = _noise(0.5, 1, 42)
	var img = Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var bump = Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	for y in range(SZ):
		for x in range(SZ):
			var v = 0.88 + 0.1 * _v(a, x, y) + 0.04 * (_v(g, x, y) - 0.5)
			img.set_pixel(x, y, Color(v, v, v))
			var b = 0.5 + 0.1 * _v(g, x, y)
			bump.set_pixel(x, y, Color(b, b, b))
	for k in range(26):
		var x0 = randi() % SZ
		var y0 = randi() % SZ
		var ang = randf() * TAU
		var light = randf() < 0.5
		for i in range(randi_range(3, 12)):
			var px = posmod(int(x0 + cos(ang) * i), SZ)
			var py = posmod(int(y0 + sin(ang) * i), SZ)
			var c = img.get_pixel(px, py)
			img.set_pixel(px, py, c.lightened(0.18) if light else c.darkened(0.3))
			bump.set_pixel(px, py, Color(0.3, 0.3, 0.3))
	_finish("paint", img, bump, 2.0)

# a camouflage net: knotted cord with leafy scrim garnish tied on in patches (transparent between)
static func net() -> ImageTexture:
	if cache.has("net"):
		return cache["net"][0]
	var a = _noise(0.06, 3, 61)
	var b = _noise(0.09, 2, 62)
	var img = Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var cols = [Color(0.25, 0.3, 0.17), Color(0.35, 0.33, 0.21), Color(0.18, 0.21, 0.13), Color(0.42, 0.38, 0.26)]
	for y in range(SZ):
		for x in range(SZ):
			var g = _v(a, x, y)
			var c: Color
			if g > 0.42:
				c = cols[int(_v(b, x, y) * 3.99)]
				c = c.darkened(randf_range(0.0, 0.12))
				c.a = 1.0
			elif x % 8 == 0 or y % 8 == 0:
				c = Color(0.2, 0.2, 0.14, 1.0)
			else:
				c = Color(0, 0, 0, 0)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var t = ImageTexture.create_from_image(img)
	cache["net"] = [t, t]
	return t

static func _plain() -> void:
	var a = _noise(0.06, 3, 51)
	var img = Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	for y in range(SZ):
		for x in range(SZ):
			var v = 0.9 + 0.1 * _v(a, x, y)
			img.set_pixel(x, y, Color(v, v, v))
	_finish("plain", img, a, 1.5)

# put a texture on a material, mapped by world (or object) position
static func apply(m: StandardMaterial3D, kind: String, scale: float, world: bool = true, normal: float = 0.6) -> void:
	var p = get_pair(kind)
	m.albedo_texture = p[0]
	m.uv1_triplanar = true
	m.uv1_world_triplanar = world
	m.uv1_scale = Vector3(scale, scale, scale)
	m.uv1_triplanar_sharpness = 4.0
	if normal > 0.0:
		m.normal_enabled = true
		m.normal_texture = p[1]
		m.normal_scale = normal
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
