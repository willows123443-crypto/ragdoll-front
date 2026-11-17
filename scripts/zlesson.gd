class_name ZLesson
# The zombie lesson: five things, on the town, before the first wave. Getting the men indoors, the
# boarding they do by themselves, spending the points, a handful of the dead to shoot, and throwing one
# off when it has hold of you. No wave comes while it is on; when it ends the real battle starts.
# Each step waits until the thing is done (or you press Skip).

static var on = false
static var starting = false
static var step_i = -1
static var t_step = 0.0
static var panel: PanelContainer = null
static var head: Label = null
static var body: Label = null
static var d = {}
static var kind = "town"

# The Ministry's own lesson: the three things that are different there.
const STEPS_OFFICE = [
	["The foot of the stairs", "In the Ministry the men don't string themselves out along the windows. Each takes a place round the foot of one staircase, facing out down the corridors, and comes back to it when he has finished boarding. Watch them take their places."],
	["Up a floor", "Twelve of the dead are coming in. In Supplies press Up a floor: every man goes up the nearest stairs and takes a place a few metres back from the head of them, facing it. (Left alone, the men go up by themselves when a floor is overrun.)"],
	["The head of the stairs", "They can only come up the stairs, one or two at a time, into the guns. When the floor below is clear again the men go back down by themselves."],
	["That's the Ministry", "Three floors: there are two more retreats like that one before there is nowhere left to go. Press Start the waves when you are ready."],
]

const STEPS = [
	["Get indoors", "The dead come in waves, from one side at a time, and in the open they come from everywhere. At the bottom of the screen open Supplies and press To the keep: the men run to the house in the middle and the houses beside it, as many to each as it has room for, and hold them."],
	["Boarding up", "The men board the windows and doors of the house they hold by themselves: a point a window, two a door, whenever there are points and none of the dead are close. Watch them do the first three. (Boarding: on, in Supplies, turns it off if you would rather keep the points.)"],
	["Spend the points", "Every one of the dead put down pays points. In Supplies, buy an Extra man: he turns up inside with the others. Machine guns and shotguns are bought there too. Left alone, the men spend the points themselves (Buying: on)."],
	["Hold them off", "Here come eight. Your men shoot by themselves. A man who is bitten to death gets up again as one of them half a minute or so later, unless he is shot through the head first (your men do it themselves when nothing is close)."],
	["Throw one off", "In Orders press Take control, then click one of your men: now you are him. One of the dead is coming for you. Let it take hold, then hammer F or Space three times to throw it off. Do nothing and it bears you down. (In a battle a man standing beside you will haul it off you.)"],
	["That's all you need", "Ten waves, each bigger than the last, and a giant with the tenth. In the Ministry the men hold the foot of the stairs and go up a floor when it is lost. Press Start the waves when you are ready."],
]

static func steps() -> Array:
	return STEPS_OFFICE if kind == "office" else STEPS

static func start(which: String = "town") -> void:
	stop(false)
	kind = which
	starting = true
	G.main.start_game({"map": kind, "mode": "horde", "size": 10 if kind == "office" else 8, "limit": 999, "reinforce": true, "armor": "none", "teams": 2})
	starting = false
	on = true
	step_i = -1
	d = {}
	Modes.horde_t = 60.0
	Support.points[0] = maxi(Support.points[0], 4)
	# (the view starts on the men)
	var mid = Vector3.ZERO
	var n = 0
	for s in G.soldiers:
		if s.team == 0 and not s.zombie and s.state == "alive":
			mid += s.pos
			n += 1
	if n > 0:
		mid /= n
		G.pc.rts_focus = mid
		G.pc.rts_dist = 40.0
		G.pc.rcam_ok = false
		if G.player == null and not G.pc.rts:
			var from = mid + Vector3(0, 20.0, 26.0)
			var dv = mid - from
			G.pc.free_pos = from
			G.pc.free_yaw = atan2(dv.x, dv.z)
			G.pc.free_pitch = atan2(dv.y, Vector2(dv.x, dv.z).length())
	_build_panel()
	_next()

# (and the waves begin: nobody is left in a battle where nothing ever comes)
static func stop(go: bool = true) -> void:
	var was = on
	on = false
	if panel != null and is_instance_valid(panel):
		panel.queue_free()
		if G.ui != null and G.ui.msg != null and is_instance_valid(G.ui.msg):
			G.ui._place(G.ui.msg, Control.PRESET_CENTER_TOP, -260, 200, 520, 40)
	panel = null
	if was and go and G.started and not G.over and G.mode == "horde":
		Modes.horde_t = 15.0
		# (nothing of the lesson's is left walking about to hold the first wave up)
		for z in G.soldiers.duplicate():
			if z.zombie and z.state != "dead":
				z.spare = false
				z.hp = 0.0
				Combat.kill(z, null, false)
		G.ui.message("The lesson is over. The first wave is fifteen seconds off")

static func _build_panel() -> void:
	panel = G.ui._panel(Color(0.05, 0.06, 0.07, 0.9))
	G.ui._place(panel, Control.PRESET_CENTER_TOP, -290, 102, 580, 118)
	G.ui._place(G.ui.msg, Control.PRESET_CENTER_TOP, -260, 286, 520, 40)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	head = G.ui._label("", 13, Color(1.0, 0.78, 0.3))
	body = G.ui._label("", 15)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(548, 0)
	var row = HBoxContainer.new()
	var sp = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var skip = G.ui._button("Skip this step", func(): ZLesson._next())
	skip.custom_minimum_size = Vector2(120, 26)
	var quit = G.ui._button("Start the waves", func(): ZLesson.stop())
	quit.custom_minimum_size = Vector2(120, 26)
	row.add_child(sp)
	row.add_child(quit)
	row.add_child(skip)
	v.add_child(head)
	v.add_child(body)
	v.add_child(row)
	panel.add_child(v)
	G.ui.root.add_child(panel)

static func _next() -> void:
	if not on:
		return
	if step_i >= steps().size() - 1:
		stop()
		return
	step_i += 1
	t_step = 0.0
	head.text = "%s  ·  %d of %d  ·  %s" % ["THE MINISTRY" if kind == "office" else "ZOMBIE LESSON", step_i + 1, steps().size(), steps()[step_i][0].to_upper()]
	body.text = steps()[step_i][1]
	G.audio.order_tick(true)
	if kind == "office":
		match step_i:
			1:
				d["fb0"] = Modes.fall_backs
				d["up_t"] = -1.0
				Modes.horde_side = randi() % 4
				Modes.horde_left = 12
				Modes.horde_spawn_t = 0.0
		return
	match step_i:
		0:
			d["fb0"] = Modes.fall_backs
		1:
			Support.points[0] = maxi(Support.points[0], 8)
			d["b0"] = Modes.boarded_n + Modes.doors_n
		2:
			Support.points[0] = maxi(Support.points[0], 10)
			d["men0"] = G.alive_count(0)
		3:
			Modes.horde_side = randi() % 4
			Modes.horde_left = 8
			Modes.horde_spawn_t = 0.0
		4:
			d["free0"] = Modes.p_free
			d["zeds"] = []
			d["z_t"] = 1.5

# the lesson's zombie has done its job: it is an ordinary one now, nearly done for, and the men may shoot it
static func _done_with_it() -> void:
	for z in d.get("zeds", []):
		if is_instance_valid(z) and z.state != "dead":
			z.hp = minf(z.hp, 30.0)
			z.spare = false
			if z.has_meta("lesson"):
				z.remove_meta("lesson")

static func _step_office(_dt: float) -> void:
	var men = G.soldiers.filter(func(m): return m.team == 0 and not m.zombie and m.state == "alive")
	match step_i:
		0:
			var at = 0
			for m in men:
				var li = int(m.get_meta("lobby_i", -1))
				if li >= 0 and li < Modes.lobby_spots.size() and G.dist2d(m.pos, Modes.lobby_spots[li]["p"]) < 2.0:
					at += 1
			if (at >= mini(6, men.size()) and t_step > 6.0) or t_step > 40.0:
				_next()
		1:
			if float(d["up_t"]) < 0.0 and (Modes.fall_backs > int(d["fb0"]) or Modes.ups > 0):
				d["up_t"] = t_step
			if float(d["up_t"]) >= 0.0:
				var up = men.filter(func(m): return Levels.inside(m.pos, 0.0) and Levels.storey_of(m.pos) >= 1).size()
				if (up >= men.size() and t_step - float(d["up_t"]) > 3.0) or t_step - float(d["up_t"]) > 40.0:
					_next()
		2:
			if t_step > 4.0 and Modes.horde_left <= 0 and _dead_up() == 0:
				_next()

static func _dead_up() -> int:
	return G.soldiers.filter(func(z): return z.zombie and z.state != "dead").size()

static func step(dt: float) -> void:
	if not on:
		return
	if not G.started or G.over or G.mode != "horde" or panel == null or not is_instance_valid(panel):
		stop(false)
		return
	t_step += dt
	# no wave of its own while the lesson is on
	Modes.horde_t = maxf(Modes.horde_t, 30.0)
	if kind == "office":
		_step_office(dt)
		return
	match step_i:
		0:
			if Modes.fall_backs > int(d["fb0"]) and t_step > 1.0:
				_next()
		1:
			# (three boarded, or everyone has had a fair while to get there and start)
			if Modes.boarded_n + Modes.doors_n >= int(d["b0"]) + 3 or t_step > 75.0:
				_next()
			elif Support.points[0] < 2:
				Support.points[0] = 3
		2:
			if G.alive_count(0) > int(d["men0"]):
				_next()
			elif Support.points[0] < 7:
				Support.points[0] = 10
		3:
			if t_step > 4.0 and Modes.horde_left <= 0 and _dead_up() == 0:
				_next()
		4:
			if Modes.p_free > int(d["free0"]):
				_done_with_it()
				_next()
				return
			var pl = G.player
			if pl == null or not is_instance_valid(pl) or not pl.is_player or pl.state == "dead":
				d["held"] = false
				return
			# (a man standing beside you hauls it off before you have pressed anything: that counts)
			if pl.grab_t > 0.0:
				d["held"] = true
			elif d.get("held", false):
				d["held"] = false
				if pl.state == "alive":
					G.ui.message("The man beside you hauled it off: that is the other way out of it")
					_done_with_it()
					_next()
					return
				# (borne down: it comes again, and the others still leave it to you)
			d["zeds"] = d["zeds"].filter(func(z): return is_instance_valid(z) and z.state != "dead")
			if not d["zeds"].is_empty():
				return
			d["z_t"] = float(d["z_t"]) - dt
			if float(d["z_t"]) > 0.0:
				return
			d["z_t"] = 5.0
			# One of them, close, on the same floor of the same house with nothing between it and you (a
			# window to look through is not a way in), and left alone by the others until it has hold.
			var best = pl.pos
			var bd = -1.0
			var hb = Doors.building_at(pl.pos)
			for r in [6.0, 4.5, 3.2]:
				for i in range(12):
					var a = i * TAU / 12.0
					var q: Vector3 = pl.pos + Vector3(cos(a), 0, sin(a)) * r
					if Doors.building_at(q) != hb or G.world.solid_at(q.x, q.z, 0.4, pl.pos.y):
						continue
					if G.blocked(q + Vector3(0, 1.2, 0), pl.pos + Vector3(0, 1.2, 0)) or G.blocked(q + Vector3(0, 0.35, 0), pl.pos + Vector3(0, 0.35, 0)):
						continue
					var near = 1e9
					for m in G.soldiers:
						if m.team == 0 and m != pl and m.state == "alive":
							near = minf(near, G.dist2d(m.pos, q))
					if near > bd:
						bd = near
						best = q
				if bd >= 0.0:
					break
			if bd < 0.0:
				return
			var z = Modes.spawn_zombie("walker", best.x, best.z)
			if z != null:
				z.move_to(Vector3(best.x, pl.pos.y, best.z))
				z.hp = 300.0
				z.set_meta("lesson", true)
				z.spare = true
				z.target = pl
				d["zeds"].append(z)
