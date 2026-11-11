class_name Icons
extends RefCounted
# Little white silhouettes for the kill feed and the squad cards, drawn into images at start-up
# (no art files): rifles, sub-machine guns, machine guns, scoped rifles, shotguns, pistols,
# flamethrowers, rocket tubes, a knife, a blast, a tank, a drop of blood, a helmet and a cross.

const W = 44
const H = 16
static var cache = {}

static func _img() -> Image:
	var img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img

static func _r(img: Image, x: int, y: int, w: int, h: int) -> void:
	img.fill_rect(Rect2i(x, y, w, h).intersection(Rect2i(0, 0, img.get_width(), img.get_height())), Color.WHITE)

static func _disc(img: Image, cx: float, cy: float, r: float) -> void:
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			if Vector2(x + 0.5 - cx, y + 0.5 - cy).length() <= r:
				img.set_pixel(x, y, Color.WHITE)

static func _ln(img: Image, a: Vector2, b: Vector2, t: float) -> void:
	var n = int(a.distance_to(b) * 2.0) + 1
	for i in range(n + 1):
		var p = a.lerp(b, float(i) / n)
		if t > 0.9:
			_disc(img, p.x, p.y, t)
		elif p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
			img.set_pixelv(Vector2i(p), Color.WHITE)

static func kind_of(wid: String) -> String:
	match wid:
		"rifle", "ak", "bolt", "spotter", "carbine":
			return "rifle"
		"silenced":
			return "pistol"
		"lmg", "hmg", "bar":
			return "mg"
		"dmr":
			return "sniper"
		"gl":
			return "blast"
		"rpg", "pfaust", "atrifle":
			return "at"
		_:
			return wid

static func get_icon(kind: String) -> ImageTexture:
	kind = kind_of(kind)
	if cache.has(kind):
		return cache[kind]
	var img = _img()
	match kind:
		"rifle":
			_r(img, 1, 6, 12, 4)        # stock
			_r(img, 12, 6, 18, 3)       # body
			_r(img, 30, 7, 13, 1)       # barrel
			_r(img, 18, 9, 3, 4)        # magazine
			_r(img, 14, 9, 2, 3)        # grip
		"smg":
			_r(img, 5, 6, 6, 3)
			_r(img, 10, 5, 16, 4)
			_r(img, 26, 6, 9, 2)
			_r(img, 16, 9, 3, 6)
			_r(img, 12, 9, 2, 3)
		"mg":
			_r(img, 0, 5, 10, 5)
			_r(img, 10, 5, 18, 4)
			_r(img, 28, 6, 16, 2)
			_r(img, 15, 1, 7, 4)        # feed cover
			_ln(img, Vector2(34, 8), Vector2(31, 15), 0.0)
			_ln(img, Vector2(35, 8), Vector2(38, 15), 0.0)
		"sniper":
			_r(img, 0, 7, 12, 4)
			_r(img, 12, 7, 18, 3)
			_r(img, 30, 8, 14, 1)
			_r(img, 13, 3, 12, 3)       # scope
			_r(img, 12, 2, 2, 5)
			_r(img, 24, 2, 2, 5)
			_r(img, 14, 10, 2, 3)
		"shotgun":
			_r(img, 1, 6, 11, 4)
			_r(img, 11, 6, 12, 3)
			_r(img, 23, 6, 20, 2)
			_r(img, 22, 9, 11, 2)       # pump
			_r(img, 13, 9, 2, 3)
		"pistol":
			_r(img, 14, 4, 16, 4)
			_r(img, 14, 8, 5, 7)
			_r(img, 19, 8, 3, 2)
		"flamer":
			_disc(img, 8, 8, 6)          # tank
			_r(img, 13, 7, 20, 3)
			_r(img, 33, 6, 4, 5)
			for k in range(4):
				_disc(img, 39.0 + k * 1.2, 8.0 + (k % 2) * 2 - 1, 1.6)
		"at":
			_r(img, 2, 6, 30, 4)        # tube
			_ln(img, Vector2(32, 8), Vector2(38, 4), 0.0)
			_ln(img, Vector2(32, 8), Vector2(38, 12), 0.0)
			_disc(img, 37, 8, 4)         # warhead
			_r(img, 12, 10, 3, 4)
		"knife", "bayonet":
			_r(img, 8, 6, 9, 4)
			_r(img, 17, 4, 2, 8)
			_ln(img, Vector2(19, 6), Vector2(38, 7), 0.0)
			_ln(img, Vector2(19, 8), Vector2(38, 7), 0.0)
			_r(img, 19, 6, 16, 3)
		"blast":
			for k in range(10):
				var a = k * TAU / 10.0
				_ln(img, Vector2(22, 8), Vector2(22 + cos(a) * 9.0, 8 + sin(a) * 7.0), 1.0)
			_disc(img, 22, 8, 4.5)
		"vehicle":
			_r(img, 6, 9, 30, 5)        # hull
			_r(img, 12, 4, 13, 5)       # turret
			_r(img, 25, 5, 16, 2)       # gun
			for k in range(5):
				_disc(img, 9.0 + k * 6.0, 13.5, 1.8)
		"bleed":
			_disc(img, 22, 10, 4.5)
			_ln(img, Vector2(22, 1), Vector2(18.5, 8), 1.0)
			_ln(img, Vector2(22, 1), Vector2(25.5, 8), 1.0)
		"head":
			_disc(img, 22, 9, 6)
			_r(img, 15, 9, 15, 2)
			img.fill_rect(Rect2i(19, 5, 6, 2), Color(0, 0, 0, 0))
		"medic":
			_r(img, 19, 2, 6, 13)
			_r(img, 15, 6, 14, 5)
		_:
			_r(img, 4, 6, 36, 4)
	var tex = ImageTexture.create_from_image(img)
	cache[kind] = tex
	return tex
