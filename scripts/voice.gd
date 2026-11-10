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

# the militia shout rough and informal; the second army (Bravo) talks in clipped radio-speak
const LINES_MIL = {
	"contact": ["There! %s, %d metres!", "They're %s!", "Look, %s! Shoot!", "Enemy %s, get them!", "Over there, %s!"],
	"contact_tank": ["Tank! Tank coming %s!", "Their tank, %s! Bring the rocket!", "Armour %s, get the RPG!"],
	"contact_mg": ["Their gun %s, keep low!", "Machine gun %s!"],
	"contact_sniper": ["Sniper! Stay off the street!", "Their sniper, %s! Get inside!"],
	"reload": ["Empty! Cover me!", "Loading!", "Give me a second!", "Out! Out!"],
	"moving": ["Go! Go!", "Run!", "Follow me!", "Move, brothers!", "With me!"],
	"covering": ["Shoot! Keep shooting!", "I'm covering, go!", "Fire on them!"],
	"bound": ["You go, we shoot!", "Half go, half shoot!", "Run now, I cover!"],
	"flank": ["Go round the back!", "Around the side, go!", "Take the alley, hit them from behind!"],
	"frag_in": ["Grenade in the window!", "Throw it in!"],
	"breach": ["Inside! Get inside!", "Kick the door, go!", "In, in, in!"],
	"man_down": ["They got %s!", "%s is hit!", "Brother down!", "%s! No!"],
	"kill": ["Got one!", "He's finished!", "One less!", "Dropped him!"],
	"grenade": ["Grenade! Run!", "Bomb! Get away!"],
	"suppressed": ["Too many bullets!", "I can't lift my head!", "They're shooting everything!"],
	"smoke": ["Smoke! Run through!", "Throw smoke, then go!"],
	"suppress": ["Everybody shoot that house!", "All guns on them!", "Shoot, don't stop!"],
	"fallback": ["Back to the houses!", "Pull back, regroup!", "Back, to the next street!"],
	"order_attack": ["Now we hit them! Go!", "Attack! Everyone forward!", "We push now!"],
	"order_defend": ["We hold this street!", "Nobody leaves! We fight here!", "This is our ground, hold it!"],
}
const LINES_BRAVO = {
	"contact": ["Tango %s, %d!", "Contact, %s, %d metres, engaging!", "Enemy %s! Range %d!", "Contact %s!"],
	"contact_tank": ["Armour %s! AT up!", "Enemy MBT, %s!"],
	"reload": ["Magazine!", "Reloading, cover!", "Stoppage, reloading!"],
	"moving": ["Moving now!", "Advancing!", "Going firm next cover!"],
	"covering": ["Covering, move!", "Rounds down, move!", "Weight of fire, go!"],
	"bound": ["Fire team one, move! Two, cover!", "Pepper-pot, go!", "Alpha moving, Bravo covering!"],
	"kill": ["Tango down!", "Hit, he's down!", "Target neutralised!"],
	"man_down": ["Casualty! %s is down!", "Man down, %s!", "We've got a casualty!"],
	"suppressed": ["Pinned, I'm pinned!", "Can't get eyes up!", "Heavy fire, heads down!"],
	"fallback": ["Withdraw! Pull back to the line!", "Break contact, back!"],
	"order_defend": ["Go firm, hold here!", "Dig in, nobody moves!"],
}
# lines shouted straight from game code, reworded for the other two voices
const SWAP_MIL = {
	"Medic!": ["Doctor! Somebody!", "Help me! I'm hit!"],
	"I'm hit!": ["They got me!", "I'm shot!"],
	"Help!": ["Brothers! Help!", "Don't leave me!"],
	"Moving you!": ["I've got you, come!", "Hold on, I'm pulling you!"],
	"Frag out!": ["Grenade!", "Take this!"],
	"Smoke out!": ["Smoke! Go now!"],
	"Fall back!": ["Back! Back to the houses!"],
}
const SWAP_BRAVO = {
	"Medic!": ["Medic! Casualty!", "Need a medic here!"],
	"Moving you!": ["Casualty moving, cover!", "Got you, moving!"],
	"Frag out!": ["Grenade out!", "Frag, frag!"],
}

static func style(s) -> String:
	if Faction.militia(s.team):
		return "mil"
	return "bravo" if s.team % 2 == 1 else "alpha"

static func flavour(s, text: String) -> String:
	var st = style(s)
	var sw = SWAP_MIL if st == "mil" else (SWAP_BRAVO if st == "bravo" else {})
	return G.pick(sw[text]) if sw.has(text) else text

static func say(s, kind: String, args: Array = []) -> void:
	if s == null or not is_instance_valid(s) or not LINES.has(kind):
		return
	var st = style(s)
	var set_ = LINES_MIL if st == "mil" else (LINES_BRAVO if st == "bravo" else LINES)
	var t: String = G.pick(set_[kind] if set_.has(kind) else LINES[kind])
	var n = t.count("%")
	if n > 0:
		var a = args.slice(0, n)
		while a.size() < n:
			a.append("")
		t = t % a
	G.fx.callout(s, t)
