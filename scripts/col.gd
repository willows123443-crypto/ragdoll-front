class_name WCol
extends RefCounted
# An axis-aligned box in the world: collision, cover, navigation and destruction all use these.

var lo = Vector3.ZERO
var hi = Vector3.ZERO
var gy = 0.0            # ground height under it
var dest = false        # can it be destroyed
var hp = 100.0
var color = Color(0.6, 0.55, 0.45)
var vis: Array = []      # [MultiMesh, index] pairs to hide when destroyed
var body: StaticBody3D = null
var prop = 0
var no_move = false
var alive = true
