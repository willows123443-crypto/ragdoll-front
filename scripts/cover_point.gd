class_name CoverPoint
extends RefCounted

var p = Vector3.ZERO
var n = Vector3.ZERO     # points from the cover object toward the soldier
var t = Vector3.ZERO     # for corners: direction to lean out
var type = "low"         # low, corner, wall
var col = null
var owner_s = null
var ban = 0.0
var upper = false
var tower = null
