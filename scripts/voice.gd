class_name Voice
extends RefCounted
# What soldiers shout. Several variants for each situation so battles don't sound repetitive.

const LINES = {
	"contact": ["Contact %s, %dm!", "Enemy %s, %d metres!", "Movement %s, %dm!", "Hostiles %s!", "Eyes %s, enemy at %d!", "Got eyes on them, %s!"],
	"contact_tank": ["Tank! Tank %s!", "Armour, %s!", "Enemy tank %s, get the rockets up!"],
	"contact_mg": ["MG nest %s!", "Machine gun %s, stay down!"],
	"contact_sniper": ["Sniper! Get down!", "Sniper %s, watch the windows!"],
	"reload": ["Reloading!", "Changing mags!", "Cover me, reloading!", "Mag out!", "I'm dry, reloading!"],
	"moving": ["Moving!", "Move up!", "On the move!", "Going!", "Moving, cover me!"],
	"covering": ["Covering!", "I've got you covered!", "Suppressing!", "Keep their heads down!"],
	"bound": ["First team, move! Second team, cover!", "Bounding, go!", "Leapfrog, move up!", "Cover and move!"],
	"flank": ["Flank them!", "Go around the side!", "Hit them from the flank!", "Pin them, we'll go round!"],
	"frag_in": ["Frag out, in the window!", "Grenade in the building!", "Clearing with a frag!"],
	"breach": ["Go, go, go! Clear it!", "Stack up and go!", "In! Clear the room!", "Room clear? Push!"],
	"man_down": ["Man down!", "%s's hit!", "We lost %s!", "Medic! %s is down!"],
	"kill": ["Target down!", "Got him!", "Enemy down!", "Scratch one!", "He's down!"],
	"grenade": ["Grenade!", "Frag, get clear!", "Grenade, move!"],
	"suppressed": ["I'm pinned!", "Can't move!", "They've got us pinned!", "Too much fire!"],
	"smoke": ["Smoke out! Cross under the smoke!", "Popping smoke!", "Smoke, then move!"],
	"suppress": ["Base of fire, keep them down!", "Everything on that position!", "Suppressing fire, now!"],
	"fallback": ["Fall back to the line!", "Back, back, back!", "Pull back!", "Regroup at the rear!"],
	"order_attack": ["Command says push!", "We're going in, on me!", "Orders are to attack!"],
	"order_defend": ["Dig in, we hold here!", "Hold this position!", "Nobody falls back!"],
}

static func say(s, kind: String, args: Array = []) -> void:
	if s == null or not is_instance_valid(s) or not LINES.has(kind):
		return
	var t: String = G.pick(LINES[kind])
	var n = t.count("%")
	if n > 0:
		var a = args.slice(0, n)
		while a.size() < n:
			a.append("")
		t = t % a
	G.fx.callout(s, t)
