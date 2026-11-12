class_name Hud
extends RefCounted
# One look for the whole HUD: the same dark glass panels, the same few colours and the same text
# sizes for alerts, radio messages, speech bubbles, squad cards, menus and tags.

const BG = Color(0.07, 0.08, 0.09, 0.86)          # panels and cards
const BG_SOFT = Color(0.07, 0.08, 0.09, 0.7)      # things over the battlefield (bubbles, tags)
const EDGE = Color(1.0, 1.0, 1.0, 0.1)            # a panel's thin border
const TEXT = Color(0.92, 0.92, 0.88)
const MUTED = Color(0.7, 0.72, 0.68)
const ACCENT = Color(0.96, 0.8, 0.38)             # titles, the selected thing, highlights
const GOOD = Color(0.5, 0.88, 0.45)
const WARN = Color(1.0, 0.72, 0.3)
const BAD = Color(1.0, 0.38, 0.32)
const INFO = Color(0.55, 0.82, 1.0)
const RADIUS = 6

const SIZE_SMALL = 11
const SIZE_BODY = 13
const SIZE_TITLE = 16

static var _cache = {}

# a rounded panel with a thin edge; `edge` tints the edge (pass a colour to mark what it is)
static func pill(bg: Color = BG, edge: Color = EDGE, radius: int = RADIUS) -> StyleBoxFlat:
	var key = "%s|%s|%d" % [bg.to_html(), edge.to_html(), radius]
	if _cache.has(key):
		return _cache[key]
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(1)
	sb.border_color = Color(edge.r, edge.g, edge.b, minf(edge.a, 0.55))
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	sb.anti_aliasing = true
	_cache[key] = sb
	return sb

# a panel with a coloured strip down its left side (alerts, radio lines)
static func strip(bg: Color, side: Color) -> StyleBoxFlat:
	var key = "strip|%s|%s" % [bg.to_html(), side.to_html()]
	if _cache.has(key):
		return _cache[key]
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(RADIUS)
	sb.border_width_left = 3
	sb.border_color = side
	sb.content_margin_left = 9
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	_cache[key] = sb
	return sb
