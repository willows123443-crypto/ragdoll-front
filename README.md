# Tin Hat Tactics

A ragdoll soldier battle sandbox with a commander RTS mode, built in Godot 4.6. (Formerly called Ragdoll Front; the repository and web address keep the old name.)

## Play in the browser
**https://willows123443-crypto.github.io/ragdoll-front/**

Every push to `main` rebuilds the game automatically, so just refresh the page (Ctrl+Shift+R) to get the latest version.
The build also runs an automatic headless test. Its results are posted as comments on issue #1.

The browser build uses Godot's Compatibility renderer, so it has no SSAO and no bullet-hole decals. It also runs physics on a single thread, so expect lower frame rates with very large battles.

## Opening it in Godot (optional)
1. Unzip the folder anywhere.
2. Open Godot 4.6. In the Project Manager, choose **Import**, select `project.godot`, then **Import & Edit**.
3. Press **F5** (Run Project). The first import takes a few seconds.

You don't need to install anything else. Every mesh, texture and sound is generated in code. Physics uses Jolt, which is built into Godot 4.6, and the project is already set to use it.

## What's in the game
- **Active ragdoll soldiers** with AI that only knows what it has seen, heard or been told by radio; cover, peeking, medics dragging the wounded
- **Morale and squad leaders:** losses and heavy fire shake soldiers; broken soldiers run until a leader rallies them
- **Ammo and resupply**, bullet penetration through thin cover, grenades, smoke, mortars, flares
- **Vehicles:** jeeps with mounted machine guns, troop trucks and tanks, with AI crews; you can drive them
- **Reinforcements** arrive by truck, helicopter or paratroopers, at your HQ or a forward FOB; lose them all and nobody new comes until you build another FOB
- **Building:** engineers put up FOBs, sandbag walls, barbed wire, tank traps, MG nests, mortar pits, watchtowers, bunkers, field hospitals, radio masts, vehicle depots and supply dumps piece by piece; mark out sites yourself from the Build tab, and dismantle anything
- **Destructible everything:** houses, churches, warehouses and apartment blocks come down wall by wall and floor by floor
- **Team looks:** each side has its own vehicle style, insignia and helmet shape
- **Modes:** sandbox, deathmatch, capture the points, frontline, assault, last stand, destroy base, breakthrough, sabotage (night raid), siege, convoy escort, pilot rescue, a king-of-the-hill flag that moves, a top-down commander (RTS) mode where you buy squads, vehicles and fire support with supply points and your engineers build what you mark out, and a zombie horde with walkers, runners, crawlers and brutes — the menu explains each
- **Daily challenge:** one battle a day picked from the date (map, mode, time of day, twists), with your best result kept
- **Doors and windows:** soldiers kick doors open, glass shatters when shot, and grenades get lobbed in through windows
- **Huge battles:** 100 a side or more; far-off soldiers are simplified so the battle keeps running (Settings: how close full detail starts, the most soldiers at once, and an on-screen frame rate and soldier count)
- **Spoken callouts:** soldiers near you shout "Contact!", "Reloading!", "Man down!" using your browser's speech voices (can be turned off in Settings)
- **Night fighting:** only the point man shows a light, soldiers creep forward crouched, leaders fire flares and everyone shoots at muzzle flashes
- **Air war:** fighters and dive bombers you can fly, AA guns, helicopter transports and gunships
- **Logistics:** fuel, towing, bridge layers, supply trucks that restock FOBs, ammo boxes you can carry, upgrades (concrete walls, pillboxes, huts), camo nets and rebuilding
- **Campaign:** regions to take one battle at a time; survivors become veterans with stripes, and whatever gets wrecked in a region stays wrecked, and structures left standing are still there next time
- **Scenario codes:** save a battle as a code and share it
- **Commander's map** (Tab): see the whole battle and send squads around
- **Building with a blueprint:** a see-through preview follows the mouse with an arrow for its front; hold right-click to turn it
- **Squad tactics:** fire-and-movement, a base of fire that suppresses while others flank, smoke before crossing open ground, falling back to regroup when overrun
- **Maps:** Town ruins, Farmland, Trenches, Forest, City blocks, a tank factory fought indoors, Beach landing, large maps (Valley offensive, Western front, River crossing, Mountain pass), the huge battlefield, random maps, and your own from the **map editor** (sculpt and paint the ground, place buildings, squads and vehicles with orders and waypoints, and triggers that set off reinforcements, barrages, messages or a win)
- **Up to four sides** with your own names, armband colours and uniforms; day, dusk or night
- **Command:** select soldiers and send them somewhere, team orders, "follow me"
- **Title screen:** quick battle, campaign, daily challenge, commander, zombie horde, map editor and scenario codes; Esc or M during a battle pauses it with Resume, Restart, New battle, Battle report and Quit
- **Win limits only where a mode uses them:** kills, points, tickets or supplies can be set per mode in the setup screen; modes that end another way (convoy escort, pilot rescue, last stand, sabotage, destroy base, horde) have no score limit to end them early
- **Bleeding and field dressings:** wounds bleed until bandaged; press H to dress your own wound (slow), soldiers patch a nearby buddy faster, and medics do it twice as fast and carry more dressings
- **Building interiors:** furnished rooms (tables, chairs, beds, wardrobes, stoves), some two-storey houses with stairs, and soldiers flip tables over for cover (F flips one when you control a soldier)
- **Artillery spotting:** a radio operator calls in a fire mission; the ranging round lands off target, the observer sends a correction, and the rounds walk onto the target before firing for effect
- **Destructible trees and fences:** tanks flatten fences and push trees over, and shellfire leaves splintered stumps and fallen trunks
- **Sound:** each weapon sounds different, shots echo between buildings, far-off fire becomes a dull thud, and rounds crack or whizz overhead depending on how close they pass
- **Bigger explosions:** a shockwave ring, dust that hangs in the air, debris that stays on the ground, and craters that dig into the terrain and can be used as cover
- **Ragdolls:** soldiers clutch wounds, slump, drop to their knees, stagger or spin as they die, and reach out to a wall to catch themselves when knocked down
- **Water:** wade through shallows (slower the deeper it gets) or swim deep water with your rifle slung; on the river map each side has assault boats that ferry squads across and drop them in the shallows
- **Time passes:** "Dawn till nightfall" starts a battle at first light and runs into the night over about twenty-five minutes, with the sun moving across the sky and night tactics kicking in when it gets dark (or pick the endless day and night cycle)
- **Anti-tank weapons:** bazookas, one-shot panzerfausts that riflemen pull out when a tank gets close (0 picks one), and anti-tank guns that their crews push into position, fire only from a standstill, and shoot armour-piercing at tanks and high explosive at infantry
- **Kill the general:** each side's general hides in a house on its own half with a bodyguard; scouts and patrols search for theirs, and once he's spotted everyone converges while he tries to slip away further back
- **Climbing:** vault through windows (smashing the glass) as well as over low walls, and climb ladders onto flat roofs, where snipers and machine gunners set up
- **Campaign map:** twelve regions and armies on both sides; move each army once a turn, take empty ground at once or fight for occupied regions with the armies' real strength; supply lines run back to your HQ, and cut-off armies wither; Bravo counter-attacks where you're thin
- **Radio and runners:** artillery, air support and reinforcements need a radio operator, command truck or radio mast; without one a runner has to carry the request back to HQ on foot
- **Scouts and commanders:** each side sends scouts ahead who radio back what they see; commanders are reckless, cautious or cunning and fight that way; defenders who haven't been spotted hold their fire for an ambush
- **Better looks:** brick, weathered plaster and tiled roofs; worn paint, track links, tow cables, jerrycans and tools on the vehicles; camouflage nets that drape over their poles
- **Commander mode economy:** the HQ only brings in a trickle of supply; build supply dumps for real income. Vehicles need a vehicle depot and air support a radio mast before you can buy them, and the maps are bigger, with farms and woods round the edges. A heavy tank joins the vehicles
- **Factions:** pick what each side plays in the setup screen: the regular army or the **Black Banner Militia**, in civilian clothes with scarves and balaclavas, technicals instead of tanks, plenty of RPGs and molotovs, hidden weapons caches where fresh fighters keep turning up (blow the caches to stop them), roadside bombs on the roads, tunnels across their side of the map, and snipers who move after every shot; but no air support, no tanks and no radio operators
- **Fight to the end:** nobody breaks and runs any more
- **Field hospitals:** each keeps a blood supply; wounded brought in are patched up, and men who fall close by are worked on and come back as reinforcements
- **Night raid tools:** silenced pistols, knives (F on an enemy right in front of you) and cutting enemy wire (I)
- **Recon plane:** a call-in that circles the enemy's side for thirty seconds and puts everything it sees on your map, unless their anti-aircraft guns bring it down
- **Commander mode** is now won by destroying the enemy HQ; recruits are driven to wherever you click
- **After-action report** (J) and first-person view (Y)
- **Commanding vehicles:** click a vehicle to select everyone aboard (one ring round the hull); right-click to drive it there and it waits; **Dismount** (Orders tab, or the button on the vehicle panel) gets the troops out of any vehicle, and they hold where they hop down. Order lines start from where each unit or vehicle actually is
- **Click a structure** to see what it is, how built or damaged it is, and Repair, Dismantle (half the cost back in commander mode), Upgrade or Camo it from the panel
- **Tidier squads:** soldiers you drop in together, a truck of recruits or a paradrop stick form their own squad; vehicle crews have their own and no longer get mixed into infantry squads. Nothing spawns for you in commander mode unless you buy it (no free depot vehicles or ambulances)
- **Each mode has its own rules:** who builds what, which call-ins you get, and whether sides start with an HQ (straight fights like capture, king of the hill, deathmatch and kill the general have no building at all; defenders dig in, attackers bring forward bases). The setup screen lists them. Free spawning and effects are for sandbox only; in a battle you command your own side
- **Faces and kit:** every soldier has eyes, brows, a nose, ears and a mouth (some with stubble, militia mostly bearded); regulars wear belts, webbing, chin straps and chest pouches; militia wear chest rigs, tracksuits or open jackets, trainers or boots, and armbands, and their technicals fly a black banner
- **Vehicles you can see into:** the technical has an open cab with doors that swing open, a bench seat, dashboard and steering wheel; trucks have a dash, wheel and seat; no more helmets through roofs in trucks, ambulances, command trucks and helicopters
- **Rockets** are now a proper finned rocket with a flame, leaving a thin pale smoke trail
- **More ammunition:** more spare magazines for every gun and more rockets
- **Smoother animation:** pose changes ease in over a few frames; soldiers turn to face a wall before vaulting it and look where they're going while they're over
- **Map fixes:** the beach map's sea now runs to the horizon, and the colour of high ground no longer washes out to near white on hilly maps
- **Animation:** soldiers with nothing to shoot at stand easy with the rifle held low and their weight shifting, walk facing where they're going, ease into turns, and only take a knee when something has happened; far-off soldiers move smoothly instead of stuttering; everyone has a neck
- **Hits and deaths:** soldiers flinch, stagger or drop to a knee when hit and stay up; deaths depend on where the hit landed (a head shot drops them at once, leg hits fold the knees) with more ways to fall: forwards, twisting, reaching out, sitting back; bodies settle and lie still
- **Militia looks:** full balaclavas with an eye slit; AK-pattern rifles with wooden furniture and curved magazines, old bolt-action rifles, a belt-fed MG and RPG-7s
- **Zombie fights:** soldiers back away from anything close while they keep shooting and never walk into the horde; new zombies from later waves: riot-armoured ones you have to shoot in the head, bloaters that burst and knock people down, and spitters that hang back and lob acid that burns and leaves a burning puddle; every zombie has its own walk (shambling, lurching, staggering, hunched or stiff), arm poses and pace, and there are two kinds of runner
- **Smarter soldiers:** left to themselves they pull back to their mates when cut off, fall back to better cover when badly outnumbered, get out of sight of enemy armour if they have nothing to fight it with, and head for a field hospital when badly hurt; vehicles stuck in a narrow street try another way round and their troops get out and carry on on foot
- **Look fixes:** Bravo's helmet sits clear of the eyes; helicopter troops sit on benches along the walls; the river has gently sloping banks; distant farms and towns have pitched roofs, chimneys and windows
- **Commander mode, a real war economy:** fog of war (enemy troops and vehicles only show while your men can see them, their structures once found); control groups (Ctrl+number saves a selection, the number recalls it, twice to look at it); vehicles you buy are built one after another at the depot (two depots work faster); upgrades researched at HQ (heavier armour, field engineering, heavy artillery, logistics); and supply dumps only pay when one of your supply trucks gets there from HQ, so the enemy can ambush it
- **Zombie mode:** a 30-second break after each wave to dig in; kills earn points to spend in the Armoury (board up a building's windows, machine guns, shotguns, a flamethrower, ammo, first aid, an extra man) and on barricades from the Build tab; the dead tear at boarded windows; after dark there are more of them and they're faster
- **Mode settings:** settings a mode doesn't use are greyed out in the setup screen, and the in-battle reinforcements switch is sandbox only; outside sandbox and commander mode reinforcements are free (no paratroopers or helicopter troops to buy)
- **Fixes:** jeep and technical machine guns sit well above the car on a post with the gunner on a step behind (the jeep's windscreen folds flat), and mounted guns can't point down into their own vehicle; every gun model's parts are joined up (no floating barrels or sights)
- **Squads that think:** a pinned squad keeps a base of fire on the shooter while two men work round the flank; a squad in trouble radios for help and the nearest free squad comes over while mortars get the target; soldiers remember where their mates were killed, keep out of those spots when looking for cover and smoke them before crossing; to clear a building they stack up at the door, post a grenade and rush in, and men inside watch the doors and stairs
- **Commanders that plan:** each side probes for the thinnest part of your line and attacks there, softens a position with artillery or mortars, lays smoke and then goes in together; tanks wait outside close streets until infantry come up, an infantry squad follows each tank and goes after rocket men; and the AI learns from you, guarding the side you keep attacking from and bringing more anti-tank men if you lean on armour
- **Dragging and stretchers:** medics drag the wounded with both hands under the arms, to cover or into a nearby field hospital; when the hospital is too far to drag, the medic calls a second man over and they carry him back on a stretcher (if either bearer is hit, the stretcher goes down)
- **Each side sounds different:** the regular army calls out by the book, Bravo uses clipped radio-speak, and the militia shout rough and informal, each with its own spoken voices, pitch and pace
- **Dogfights:** fighters pick out enemy planes first and stay on the one they're chasing, break hard and jink when someone sits on their tail, and turn away rather than collide head-on; damaged planes trail grey smoke, then black smoke and flames, and go down in a spiral; shot down with height to spare, the crew bail out by parachute and fight on when they land
- **Planes come down properly:** badly hit planes burn with flickering flames streaming back; a downed plane digs in nose first, tears a wing off, scatters pieces, leaves a scorch mark and burns for a while
- **Parachutes:** panelled canopies with a vent at the top that sway and breathe, lines to each shoulder, and they collapse on the ground after landing; the man rolls as he lands, gets out of the harness and has a look round before moving off
- **Wounded on stretchers** hold their wound, roll their head and hang an arm over the side; **medics under fire** throw smoke and crawl the last stretch
- **Kit:** helmets come off when soldiers fall; men out of ammunition pick up a dead man's gun, and riflemen grab a dropped rocket launcher when armour is about
- **Steadier shooting:** machine gunners go prone and put the bipod down (much more accurate), and anyone firing over a wall or a sill rests the gun on it
- **Vehicles:** tyres can be shot flat and tracks knocked off, and a crewman climbs out and fixes them under fire; tank crews bail out of a burning tank and fight on foot; infantry ride on the back of tanks and jump off at the first shot; headlights at night that give a vehicle away from far off; vehicles push straight through hedges, prefer roads, and the ones you buy drive in from the edge of the map behind your HQ
- **Mines:** engineers sweep roads with a detector and clear what they find, and the **mine plough tank** sets off mines ahead of its blade
- **Commander mode:** the AI buys troops just as you do (engineers, riflemen, anti-tank teams), digs in anti-aircraft guns when you use planes, and sends squads to ambush your supply convoys; the HQ can't be shelled; bought vehicles roll in from the map edge; a depot under construction shows how far along it is; the vehicles setting is only what each side starts with
- **Orders (RTS):** only selected units show their order line, with a pulsing ring where they're going; selected units show what they are (RIFLE, MG, MEDIC…); right-click a vehicle or a mortar to climb in or man it, or a structure going up to build it; units start moving the moment you order them, and orders crackle over the radio
- **Building by hand:** workers take turns hammering, digging with a shovel and carrying sandbags or planks from a pile beside the site
- **Night:** F2 for night vision; moonlight is a little brighter; weapon lights are a cool white beam that fades along its length with a soft spot of light
- **Sound and sky:** machine guns and rifle fire off past the edge of the map, and now and then planes going over high up
- **Water:** rippling water that reflects the sky and catches the sun; bullets kick up spouts, shells throw up columns of spray, and boats leave a wake
- **Fewer speech bubbles:** in big fights only the nearest few soldiers talk at once; trucks and supply crews don't chatter
- **Maps:** no more hedges or bushes lying along roads
- **Menus:** a new title screen and battle setup, with what each mode is about shown beside the Deploy button, and "starting soldiers" where more come in later
- **Seeing into buildings:** looking down on a house, its roof and upper floors lift off when the cursor is over it or your selected men are inside, so you can watch the fight in the rooms
- **Fighting from houses:** soldiers prefer cover inside buildings, and men holding a point near a house go in and take the windows facing the enemy
- **Better lights:** weapon lights and headlights have a glowing lens with a flare when they point your way, a beam that stops at the first wall instead of shining through it, and a pool of light where they land
- **Bushes and sandbags:** bushes are leafy mounds with a ragged edge that stir in the breeze; sandbags are proper filled sacks of coarse sacking, tied at the ends
- **Smoke used smartly:** men pulling back under fire throw smoke first, a squad falling back screens itself, and infantry throw a smoke screen between a tank and the rocket men who've spotted it
- **No surrender:** a man with an empty rifle, no grenades and his last pistol magazine charges with the pistol and his knife
- **The radioman:** radio operators carry a real set with a whip aerial on their back; only a man carrying a radio can call artillery or answer a smoke marker, so kill him and his squad can't call the guns until someone runs over and takes the set off him (F to take it yourself)
- **Abandoned vehicles:** wrecked and empty vehicles lie out in the middle of the map; whichever side gets a man to one first patches it up with his tools and drives it away
- **Grenades thrown back:** a man near a live grenade sometimes lunges, snatches it up and throws it back
- **Bigger explosions:** a white flash that lights up the walls round about, earth and clods thrown up in a cone, and a ring of dust rolling out along the ground
- **Tracks and trampling:** tanks leave tread marks and wheels leave tyre tracks that fade over a few minutes; grass is pressed flat under vehicles and where men lie prone, and slowly stands up again; exhaust puffs thick and dark when a vehicle pulls away and light when it idles
- **Interiors:** shelves of books, tables, beds and wardrobes; a blast nearby knocks wardrobes, shelves and tables over, and smashed furniture splinters and leaves broken boards on the floor
- **More buildings:** big two-room farmhouses with a porch, more of them round towns and farms, and busier villages
- **Commander mode build queue:** Shift + right-click more structures to queue them; the engineer builds the next one when he finishes the first, and really hammers at the wall while he works. Right-click puts a blueprint away
- **Orders card:** with soldiers selected a card of orders pops up (hold, take cover, charge, fall back, smoke, dismount, act freely, build, formations)
- **Supply trucks (commander mode):** each side runs at most three sand-painted supply trucks piled with crates; they load at HQ, drive out to the supply dumps and FOBs and only earn when they get there. Lose one and you buy another at HQ. Supply dumps must be at least 70 m from HQ, so the road is a risk
- **Ammo truck:** buy one, park it behind the line and nearby soldiers run to its tailgate to restock; when it's empty, drive it back to HQ or a supply dump to load up
- **HQs and vehicles:** each faction's HQ has its own look; vehicles come in from the map edge and leave by it, no longer get stuck at the rally point, and soldiers step aside for them and walk round them
- **Squad drills:** a man about to dash across open ground shouts "Cover me!" and his mates fire on the enemy while he runs; a man out of ammo shouts for a mag and the nearest mate with the same gun tosses him two; clearing a house, the first two through the door go one left, one right, call "Clear!", and move on to the next room of a big house
- **Sounds that carry:** you hear tanks rumbling and clanking before you see them, and their tracks squeal as they turn
- **Fewer, more different modes:** assault, last stand, destroy base and king of the hill are gone from the menu (they were too close to frontline, breakthrough, siege, commander and capture); the campaign still uses them
- **Selecting:** a click picks one soldier, a double-click his whole squad
- **Orders that fit:** the orders card only shows what makes sense for what's selected: vehicles get Stop, Back to rally, Drive freely and Pop smoke; guns get Leave the gun; formations need three men; snipers and medics don't charge
- **Blueprints:** Q and E turn a structure you're placing (as well as R and right-drag)
- **Commander mode pushes on:** men with no orders work their way toward the enemy HQ cover to cover, don't settle into long-range firefights when they could move up, and once they reach the HQ they blow it up and shoot it to pieces instead of standing about
- **Snipers and spotters:** the sniper heads up high on his own, his spotter climbs up beside him, and the spotter finds targets with binoculars and calls them out to him
- **Upstairs:** men at windows and parapets on upper floors kneel steadily instead of bobbing up and down; builders always stand (or kneel) to work, never lie down
- **The dead:** bodies no longer block the living or vehicles, and a body left hanging in the air (its floor blown away, or the truck drove off) falls to the ground
- **Vehicles:** wheeled vehicles do three-point turns instead of circling round a spot they can't reach, and stop once they're close; trucks leaving the map head for the edge and off it rather than getting stuck; supply trucks stuck near a dump unload there; vehicles bought in commander mode get on with the fight instead of parking at the depot
- **Commander economy:** the first supply trucks only arrive once you have a supply dump or FOB, and they also keep FOBs stocked; buy more (and the ammo truck) from the new Supply tab, no depot needed; bigger recruit squads (rifle squad of eight, a sixteen-man platoon in two trucks, an MG team, a radio team); hover any card to see what it does, including what each upgrade does in full
- **Forward observer post:** a sandbagged lookout with a periscope: it sees a long way round it (through the fog of war, passing what it sees to your men nearby), and artillery called near it lands far more accurately
- **Long days, short nights:** in the day and night cycle about sixteen minutes of daylight to two and a half of darkness
- **Campaign, reworked:** a bigger campaign screen with the map on the left and your army on the right. Each army has its own named men (by class, with stars, kills and battles) and its own vehicles; spend the war chest (it grows with every region you hold in supply) on rifle squads, MG, anti-tank and sniper teams, engineers, medics, radio operators, jeeps, half-tracks, armoured cars and tanks for any army in supply, or raise a new army at HQ. Battles are fought with exactly the men and vehicles each army has; survivors carry on, reinforcements who live fill the gaps, and Bravo recruits too
- **Who runs your side:** in every mode except sandbox your side no longer builds, buys or plans on its own; pick "AI commander" in the setup screen (or on the campaign screen) to have an AI run it while you watch or help
- **Looks:** barbed wire at HQs is proper coiled wire (no more grey lumps), bunkers and FOBs have sandbags laid over their roofs, camouflage nets are tied to the tops of their poles, and tents are canvas ridge tents with guy ropes and door flaps
- **Map backgrounds:** a patchwork of fields, hedgerows along them, round-crowned trees among the firs, and smoke rising from fighting somewhere beyond the hills
- **Smarter routes on foot:** long walks are planned whole on a coarse map first, so men go round a block or a river instead of walking into dead ends; places where their side keeps getting pinned or killed cost more, open ground most of all, so they route behind buildings, hedges and walls; men step round each other and take turns at doorways; a man wedged in plain view clambers out instead of popping across; men you order plan their route ahead of everyone else's
- **Smarter driving:** vehicles aim a little way ahead along their route so corners become curves, and slow for sharp bends; they keep their route unless a new one is clearly better (no more dithering between two); parked and jammed vehicles count as obstacles when planning; when two meet, the smaller gives way (backing off if nose to nose); trucks keep to roads, tanks go cross-country; supply and ammo trucks park in free bays instead of on top of each other; several vehicles sent a long way drive in a column behind the biggest
- **Path debug view (F9):** every man's and vehicle's planned route, where each vehicle is aiming, who's giving way, parking bays, and each side's danger spots
- **Orders you can see:** with men selected, faint figures show where each will stand (green and crouched where there's cover); right-drag in the commander view draws a line for them to form up on, facing away from where they are now (middle-drag turns the camera); Shift + right-click queues more stops, shown as numbered flags
- **Kill feed with icons:** a weapon silhouette between the names (rifle, SMG, machine gun, scoped rifle, shotgun, pistol, flamethrower, rocket, knife, blast, tank, bleeding out) and a mark for headshots
- **Squad cards:** a slim, foldable column of one-line cards for your squads in the commander view: kind (or the vehicle a crew runs), men left, a thin health bar and what it's doing (moving, fighting, pinned, building, in cover, mounted, driving, parked); click one to select the squad and look at it
- **Battle prep (campaign):** a minute before each campaign battle to place your men, build and dig in; nobody advances, nothing is called in and the clock doesn't run; Space or the button starts it early
- **Campaign events:** most turns something happens: a storm (rain, grey light, shorter sight and no aircraft in that turn's battles), partisans ambushing an enemy army or handing a region over, a captured enemy dump for the war chest, or one of your convoys ambushed
- **Wall dust:** a wall or a building coming down throws up a cloud of brick dust that drifts off and blocks sight for several seconds
- **Heads turn:** men snap their heads round toward a near miss or an explosion before their bodies follow
- **Vehicles unstuck:** steep banks and mounds are now part of the driving map (wheels go round them, tracks slow down), so lorries no longer grind against a slope; vehicles skip waypoints they've already passed instead of turning back to touch them; they never crawl too slowly to move; they stop fidgeting between driving and waiting near their target; men standing in the road step out of it
- **Transports:** troops riding along are dropped part way to their objective, short of the enemy, and the lorry goes back; nobody sits in the back of a command truck, ammo truck or ambulance; empty transport lorries leave the map; recruited squads' men are made a couple a frame so big orders don't stall the game
- **Ambulances:** each carries two medics who get out with a stretcher, carry the wounded man to the back, climb in after him and drive him to a bay beside the field hospital
- **Field hospitals:** the wounded go inside the tent and come back out patched up a quarter of a minute later, then head back to the fight
- **Upstairs:** stairs and ladders are part of route planning (send men to a window and they go by the stairs, and stay up there); nobody walks through the underside of a staircase; men won't climb to a floor that's been blown away, and those up there when it goes find somewhere else
- **Ladders fall:** a ladder whose wall or roof comes down topples over, and nobody tries to climb it
- **Getting out of vehicles:** men climbing out no longer get flung into the air by the hull (it looked like they'd been blown up)
- **Prone:** men lying still aren't shoved along the ground by their mates, and men moving while down crawl instead of sliding
- **Fog of war:** men in an enemy vehicle show only when the vehicle does
- **Counter-battery gun:** a new structure that shoots most incoming shells out of the sky within about 60 m (and fires at aircraft); the AI builds one by its HQ when shelled, and its own shelling round your HQ is rationed to one barrage every few minutes
- **AI commander:** builds a supply dump early (so its trucks run) and a vehicle depot, and buys a few fighting vehicles as the battle goes on; an AI-run player side now builds too
- **Vehicle damage:** grey smoke from the engine once a vehicle's hurt, black smoke when it's badly hit (both stop when it's repaired); a crewman gets out to patch up a badly damaged vehicle as well as to fix tracks and tyres
- **Wrecks:** towed away after 20 seconds instead of 40
- **New weapons:** carbine (engineers, radio operators, spotters), automatic rifle (riflemen and assault troops), marksman rifle (some snipers) and grenade launcher (some riflemen), each with its own model; shotguns and bolt-action rifles are loaded a round at a time, the grenade launcher breaks open, rockets go in the back of the tube, and bolt actions are worked after every shot
- **RPG fix:** no more black disc behind a rocket (the web build drew smoke puffs before they'd started)
- **Campaign balance:** Bravo takes at most one undefended region a turn, only attacks armies it clearly outnumbers, and regroups for a turn after an attack; when you're defending, your men start dug in (sandbags and an MG nest) with a 90 second prep
- **HUD:** the orders card is now a slim strip above the dock, messages are smaller, the info panel sits above the minimap, and clicking a single soldier shows his card (health, ammo, kit, squad, what he's doing, and buttons to hold, take cover or take control)
- **Building:** hold Shift while placing a structure to keep the blueprint and place more of the same
- **Settings:** "Show soldiers' shouts as text" off hides the words above their heads; you still hear them
- **Crews bail out:** a vehicle that's taken a heavy hit and can't move (or is nearly done for) is abandoned; the crew climbs out and runs for the nearest cover
- **Ducking from turrets:** infantry who see an enemy tank or armoured car's turret swing onto them get behind cover or go flat
- **Supply chart:** the battle report plots each side's supply over time (points earned, and points in hand)
- **Craters stay:** shell holes have a raised rim you can see and use as cover; men lie in them below the rim
- **Thicker dust and smoke:** a falling wall throws up a dense low cloud with a taller one drifting off it; smoke grenades now make a solid white wall in two layers
- **Loading drills:** mortar crews take a bomb from the box, hold it over the tube, let it drop and duck with their hands over their ears; machine gunners (nests, jeeps, other mounted MGs) change the belt every hundred rounds (open the cover, lay the belt, slap it shut); the anti-tank gunner fetches a shell from beside the trail and rams it into the breech after every shot
- **Anti-tank guns:** none at the start of a battle any more; when enemy armour shows up one is bought, and it sets up behind your line covering the approach instead of rolling up to the front
- **Medics and pick-ups you can see:** a man dressing a wound winds the bandage round with both hands while the wounded man keeps still, and he wears a white dressing afterwards; men kneel at an ammo crate or over a body and go through it before they've restocked
- **Wounded fight on less:** a man who's bleeding badly gets into cover (or flat) and dresses it rather than carrying on shooting
- **Behind low walls:** men only rise as high as it takes to fire over the top, and go flat behind a low wall while they reload or the rounds are coming in
- **No shooting while working:** engineers building, mending or sweeping don't fire; an enemy close by makes them drop the job and fight. Nobody sweeps for mines under fire
- **Fewer grenades:** one frag each (and one rifle grenade), thrown much less often
- **Take control in commander:** "Control him" on a soldier's card (or the Take control tool) puts you in his boots; X takes you back up to the commander view
- **Order buttons:** only the order the selected men are actually on is lit
- **Selection and order marks:** thin glowing rings on the ground under selected men with a chevron for the way they face; the hover preview shows a ring and chevron where each man will end up (green where there's cover) and a faint trail from him to it
- **Vehicles:** tougher against small arms and near misses, fewer hits set them on fire and most fires burn out; two vehicles nose to nose sort themselves out (the smaller backs off at an angle while the bigger waits, a parked one with a driver shuffles out of the road, a wreck gets driven round); a lorry creeping back and forth counts as stuck and finds another way; men can't stand inside a lorry's bonnet any more
- **Headlights:** set into the front of each vehicle in a dark housing, with a softer pool of light on the road
- **Bodies and rubble:** whatever was lying on a wall or roof falls when it's blown away; rubble that's still moving or resting on nothing isn't frozen in mid-air; bodies aren't thrown as high or as far by blasts
- **Roofs:** a man blown up onto a roof walks to the edge and drops off it
- **Truck reinforcements:** the radio gives the real time until they arrive instead of "two minutes"
- **AI-run Alpha (commander):** gets reinforcement waves and plans attacks like the enemy commander does; AI mortars fire again (they'd been stuck re-checking for targets)
- **Frontline:** each side starts holding the flags on its own side of the line; a side has to hold every flag for a full minute to win that way (and not in the opening minutes), so battles no longer end in under a minute
- **Helmets:** shaped to fit the square heads, a rounded-off crown sitting down over the head with each side's own rim, skirt, brim or cap
- **Lorries:** once parked they stay parked instead of creeping at a spot they can't quite reach; three-point turns are carried through instead of rocking on the spot; a lorry backing into something pulls forward on full lock instead
- **AT gun crew:** the man at the trail takes a shell from the box and passes it up, the gunner rams it home, and the spent case flies out of the breech after every shot
- **Tools in hand:** a shovel for men digging in, a spanner worked round for repairs, the mine detector swept side to side, and men kneel to scrape a hole and bury a mine
- **Wounded helped back:** a man shot in the leg hobbles; a mate puts an arm round him and walks him back to a medic, the hospital or the rear, with the wounded man's arm over his shoulders
- **Grenade throws:** AI men pull the pin, wind back, throw over the top and follow through, then keep their heads down until it's gone off
- **Ammo hand-offs:** a man who's run dry next to a mate with plenty is handed a couple of magazines
- **Tank fights:** armour is thickest at the front (side hits do more, rear hits much more); tanks holding a position swing their hull to face enemy armour, and back off a few metres after a shot at armour before coming forward again
- **Smoke:** nobody sprays into a smoke screen at where they last saw someone, unless they saw them go in a moment ago
- **Attack-move:** the Attack-move button (or Ctrl + right-click) sends men somewhere but has them stop, take cover and fight anything they run into, then carry on
- **Night:** tracers glow orange with a soft halo, muzzle flashes light the walls and men round them, and flares hang longer under a parachute, drifting and smoking
- **Damaged walls:** a blast leaves a scorch on a wall that's still standing, and a badly hurt wall gets a hole punched through it with chunks knocked off at its foot
- **Performance:** far-off soldiers are simplified from 36 men up (not 50), think every third tick when they're not in a fight, and only check for crowding and vehicles now and then
- **Commander map:** a whole-map minimap in the top right: click it (or drag) to move the camera, right-click to send the selected men there. It shows flags, bases, your squads with an arrow the way they're moving, vehicle icons (tanks with their gun), enemies you can see, fading crosses where enemies were last seen, red rings where your men are under fire, and the box the camera is looking at
- **Alerts:** "Squad 2 pinned down", "Tank lost", "HQ under fire", "Jeep taking hits" pop up under the map; click one to fly there, or press Space for the latest
- **Hover:** in the commander view, the mouse over a soldier, vehicle or structure shows its name and a slim health bar
- **Supply line:** supply in hand and income per minute (with an arrow when it's rising or falling) under the score
- **Build tabs:** Defences (sandbags, wire, nests, pits, traps...) and Bases (FOBs, hospital, depot, supply dump, radio, observer, watchtower) are separate tabs
- **Buttons and panels:** buttons glow under the mouse and click when pressed; the unit card and menus fade in
- **In a soldier's boots:** your magazine and spare rounds sit by the crosshair with a bar of rounds; squadmates show as green ticks on the compass; hold ` (the key under Esc) for the squad wheel (Follow me, Attack there, Smoke there, Take cover, Hold here, As you were): move the mouse toward one and let go. A quick tap of Q still leans
- **Fog of war:** enemies in plain sight of any of your men now always show (each man's nearest few look for themselves), with a moment's grace so men ducking in and out of view don't flicker
- **No more flinging:** standing men's limbs don't collide with vehicles, wrecks or flying debris (only once they go down); troops never get out of a lorry past the edge of the map, and a lorry won't unload out there
- **Craters:** the rim is small lumps out on the lip, so men lying in the bowl can't get trapped inside it
- **Built positions:** men standing where a wall goes up are stepped out of the way instead of bounced about; crews man a mortar pit or MG nest from the lip instead of trying to walk through its walls
- **Smoke:** no more black discs in smoke screens
- **Zoomed out:** far soldiers move smoothly again instead of stuttering
- **Walking round vehicles:** men steer round a vehicle's real shape, the short way round toward where they're going
- **Supply trucks:** a fleet truck whose driver got out gets someone back in (or HQ sends a driver), a truck stuck on its run for a minute starts again, and one you sent somewhere goes back to its runs after a while. The "Convoy in" timer is gone
- **AI commander building:** fighting positions face where the enemy is now and go where they can see the approach; tank traps go across the road in once enemy armour shows up; AA only once there's something in the air; nothing gets built where the enemy is
- **Militia technical:** sloped bonnet, grille and bull bar, wing mirrors, roof rack, spare wheel, jerrycans and a winged gun shield
- **Friendly fire on vehicles:** men and AT guns hold fire when one of their own vehicles is in the line, and stray rifle rounds barely scratch your own armour
- **Fighting through buildings:** men inside knock a mousehole through a shared wall to reach the next building instead of running out into the street, and defenders favour upstairs windows
- **Commander icons:** each squad has an order badge over it (shield = hold, crosshair = attack-move, chevrons = follow, arrow = move); squad cards show a weapon icon and health pips per man
- **Speech bubbles** with an icon (reloading, grenade, medic, contact…) instead of floating text
- **Sound:** distant gunfire turns into a muffled thud, and shots behind walls sound muffled
- **Radio chatter** in commander mode: pinned squads, lost vehicles, sites under fire and armour or aircraft spotted, read out over the radio
- **Vehicles drive through bushes** and hedges; trucks and tanks flatten small trees
- **Command truck:** parked for a few seconds it sets up as a command post. Men within 45 m stay steadier and shoot straighter, it spots enemies at long range, and reinforcements can arrive there
- **No stray flags:** flagpoles and crates no longer appear on roads or in commander mode
- **Camo nets are built:** ordering a net drops a rolled net, and men have to put it up
- **Far units in commander:** distant men move their gun with them and skip shadows, so zoomed-out armies look smooth and cost less
- **Headlights:** a soft patch of light on the road ahead instead of a cone
- **Night falls gradually:** dusk and dawn take longer and the light changes smoothly
- **Cover behind vehicles:** men kneel behind a vehicle instead of lying with their legs sticking out
- **Quieter selection:** the ring under selected men is smaller and fainter, and the line from each man to his spot only shows while you're giving the order
- **Camo nets drape:** the net rides over the roof, sags, and slopes down to pegs on the ground with a ragged edge, blotchy colours and scraps of foliage; masts poke through
- **Muzzle flashes at night** flicker on walls and the ground, each one a little different
- **Tracers you can follow:** every fourth round from a machine gun is a bright tracer that stays visible from commander height
- **Battle damage on vehicles:** bullet holes and soot stay on the hull, small parts like mirrors and lamps get shot off, and wrecks burn and then smoulder for a few minutes (ones blocking a road or a spawn are still towed away sooner)
- **Footprints:** boot prints in the ground near the camera, deepest in the rain, on the beach and by the water
- **Close blasts in first person** throw dirt over the view and leave your hearing muffled and ringing for a moment
- **Hit reactions:** a round in the arm twists a man round, one in the chest rocks him back, a head graze snaps his head back
- **Deaths against cover:** men killed with a wall at their back slide down it and end up sitting against it
- **Quiet moments:** men check their rifle over, look around, or drink from their canteen
- **Bayonets:** a charge order fixes bayonets, and men run through anyone they reach
- **Sidearms:** out of rifle ammo, a man slings his rifle across his back and fights on with his pistol
- **Kit by class:** medics wear a white armband and red crosses with a medical bag, engineers carry a shovel, machine gunners a belt of rounds and an ammo tin, AT men spare rockets on their back, assault troops grenades, snipers scrim on the helmet, officers binoculars. The radio is worn on the back
- **Badly wounded men** stop fighting and drag themselves toward the nearest medic, who comes to meet them
- **Crews who survive** a knocked-out vehicle get to cover and fight on as infantry
- **The AI's command truck** drives up behind its own line and sets up as a command post, so it's worth hunting
- **Flares** open a small parachute and throw long moving shadows at night
- **Suspension:** vehicles squat when pulling away, dip when braking, lean in turns, bounce over rough ground, and rock back when the main gun fires
- **Towing:** select a truck, jeep, halftrack or technical and press Tow to hitch up the nearest field gun, mortar or broken-down vehicle, then send the truck where you want it (a tow bar shows the hitch)
- **Tank riders** hold on through scattered fire and only jump off when the tank stops, is hit hard, or the enemy is close
- **Engine sound:** the nearest vehicles have a continuous engine note that climbs through the gears, plus a gearbox whine when backing up
- **Battle music** now follows the whole battle (not just what's near the camera), so commander mode gets the drums too
- **Callouts** say where the enemy is relative to the speaker and what's next to them ("Contact left, by the truck!"), and say where a man was hit
- **Title screen battle:** a small battle plays out behind the main menu while the camera circles it
- **Rebindable keys:** Settings → Controls. Click an action, then press the new key (Default keys puts them back)
- **Fixed:** a stream of errors from wounded men being helped along, and from smoke being thrown for a crossing
- **Ammo sharing at range:** a man out of magazines shouts for ammo and a squadmate up to 13 m away lobs one across (the hand-to-hand pass is still there up close)
- **Falling trees:** a tree hit by a shell or rammed by a tank tips over and crashes down, knocking flat anyone underneath; the trunk then lies there as a log that wheeled vehicles have to go round (tanks roll over it)
- **Rolling over:** a big blast right beside a light vehicle throws it onto its side or roof, and jeeps and lorries taken too fast across a steep slope or round a tight turn go over; the crew crawl out hurt and dazed
- **Roofs cave in** under shellfire: slabs and beams crash into the rooms, dust boils out, and anyone upstairs is hurt. Fences splinter
- **Chain reactions:** fuel drums (by camps, crates and some houses) go up a moment after they're shot or blasted and set off whatever's next to them; supply dumps, depots and FOBs cook off for a few seconds when destroyed, and tanks and lorries can cook off after they're knocked out
- **Fuel matters:** tanks burn fuel fast (about four minutes of hard driving) and engines use a little idling. Refuel at your own base crates, FOBs, depots and dumps (not at stray crates), or park a supply or ammo truck alongside. Vehicle cards show a fuel gauge, and commander mode warns you when one runs low or dry; the AI sends its supply trucks out to vehicles that have run dry
- **AI feints:** a cunning (sometimes a cautious) AI commander sends one squad, with a barrage and smoke, noisily at one objective while the rest wait out of sight behind another, then sends them in once your squads have shifted
- **AI learns:** the AI watches what keeps killing its men and answers it: more anti-tank teams against armour, counter-snipers against snipers, assault teams against machine guns, more MGs against rushes, digging in against shelling. You get an intel message when it adapts
- **AI regroups:** a badly beaten AI pulls back to a second line and gathers its reinforcements there, then counter-attacks together once it's back up to strength
- **Where's the fighting?** in commander mode press Home (or the button under the map) to jump the camera to the heaviest fighting; press again for the next spot
- **Battle builder** (title screen): an empty battlefield where you set out squads, vehicles and defences for both sides (defences go up at once, free). Everyone holds still until you press Start the battle, then you watch
- **Fixed:** "We've lost the radio" messages at the start of a sandbox
- **Balance pass:** a harness (`--balance`) plays one AI-vs-AI battle and sums it up on one line (winner, kills, vehicles lost, flips, fuel, feints, regroups, adaptations). From a dozen battles across capture, frontline and commander: rollovers were far too common (12 in one battle, mostly lorries flung round turns), so the turn limit is much stricter and blasts flip vehicles less often; no side came out consistently ahead
- **Simpler HUD:** the column of buttons on the left is now one Menu button that drops down (main menu, pause, slow motion, battle report, controls, reinforcements)
- **One look for the HUD:** radio messages, alerts, speech bubbles, squad cards, menus and tags all use the same dark rounded panels, colours and text sizes; speech bubbles are dark with the speaker's team colour on the edge
- **Soldiers re-proportioned:** helmets are deeper and rounder and come down over the head instead of sitting on top like a cap; the chest plate, pouches and pack are slimmer so the men look less boxy
- **Minimap:** the box showing what the camera sees is now the real patch of ground (turned with the camera) and stays inside the map
- **Building clears the ground:** putting a structure down clears trees, hedges, bushes and grass where it goes (houses, walls and the rest of the map are left alone), so they no longer block a site
- **Supply trucks show what they're doing** in commander mode: "Loading at HQ" or "Unloading" with a progress bar, "Taking supplies to the dump · 80m" or "Heading back to HQ", with a dotted line to where they're going
- **Ragdolls stay put:** a man going down against a vehicle or wreck isn't thrown across the map any more, and no limb can fly faster than a real fall
- **Distant men walk properly:** far-off men in commander view keep stepping between their updates, so they walk instead of sliding and twitching
- **Vehicles get unstuck:** a vehicle that means to move but hasn't for ten seconds counts as stuck; when it's jammed in with its own side's vehicles it slips past them for a few seconds; when it's wedged it's moved clear toward where it was going (not back where it came from); a vehicle waiting on a man who can't move goes round him; the command truck no longer tries to drive into the hills behind HQ
- **No back-and-forth sawing:** a tank holding a firing position sticks with its decision for a few seconds instead of flicking between closing in and backing off, and a vehicle going over the same spot again doesn't lay more track on it
- **Camo nets always need building:** the Camo button on a structure now orders a net that engineers put up, instead of it appearing at once
- **Black Banner Militia vehicles:** the militia now field an old tank (sandbags and logs for armour, a black banner on the turret), a gun truck (a lorry with boiler plate welded over it and a cannon) and a twin-gun technical, as well as the technical. In commander mode, vehicles you order now always go into the depot's queue and show their progress, even for the militia (who have no radio: the depot is at home)

- **New map: Ministry offices (3 floors, indoor):** a three-storey office block in a walled yard. Every floor has a long corridor, three cross corridors and wings of front and back offices with doors between them, furnished with desks, cabinets and corridor barricades. Four U-shaped stairwells join the floors, laid out so both sides get the same. The flags are on different floors (A and C on the first floor at either end, B on the top floor in the middle)
- **Fighting on every floor:** each storey has its own path grid, joined by the stairwells, so the AI can be sent anywhere on any floor and finds its own way up and down. Cover is generated on the upper floors too, men only pick cover on the floor they're on, and a flag on a floor is held by whoever is on that floor
- **Floor view:** in the office block, Page Up / Page Down (or the floor buttons on the right) lift off everything above the chosen floor so you look straight down into its rooms. Each button shows how many of your men and how many seen enemies are on that floor, and men on hidden floors show as small markers with their floor number. While you play a man inside, the view follows his floor
- **See inside your HQ:** hover over an HQ from above and its roof lifts off
- **AI goes for the HQ:** sappers and rocket men close to an enemy HQ now attack it even under fire, instead of circling it; the AI knows artillery can't hurt an HQ in commander battles and shells the defenders instead, and you're told if you try (the artillery card says so too)
- **Your bases keep watch:** enemy soldiers and vehicles near your HQ (and forward bases, bunkers and towers) always show through the fog of war
- **Safe drop-offs:** reinforcements ordered while the drop point is overrun get dropped back toward the map edge, out of the fighting, and you're told where
- **Economy:** the HQ earns a little more supply on its own (2 points every 18 s), and militia squads cost 20% less than army ones
- **Troops find a clear shot:** a man whose rifle is jammed against the wall he's leaning on steps back or picks other cover, and one who has no line of fire from his cover for five seconds goes and finds some; no more firing blind sideways while walking
- **Fixed:** far-off men in the commander view are posed fresh on every frame between their updates (they were sliding, then snapping forward, with their rifles floating in front of them)
- **Fixed:** vehicles stopping for any friendly vehicle close by: they now only stop for one that's coming at them, ease off behind one driving away, and slip past after six seconds of giving way. A vehicle sawing back and forth with three-point turns swings round forward instead, and a parking or drop-off spot a few metres to the side or behind counts as reached
- **Fixed:** damaged supply trucks (and other lorries and jeeps) stopping for ages while the driver got out to patch the body; they now drive on, and only stop to change a wheel with two or more flats
- **Fixed:** two supply trucks jammed nose to side at HQ: a waiting truck now moves over, and the second time a vehicle jams against one of its own it slips past
- **Fixed:** a supply truck that restarted its run out on the road showing "Loading at HQ"; it drives back first
- **Fixed:** building didn't clear the small bushes scattered through the grass, and left flattened grass showing through the floor

- **Fewer modes:** the menu now offers Sandbox, Commander (RTS) and Zombie horde, with the Campaign on the title screen. The other battle types are no longer offered on their own (they still turn up as campaign missions), and the daily challenge is gone
- **Minimap shows every enemy** in sandbox and horde battles; in commander and campaign battles it still only shows the ones your men can see
- **Stuck recorder:** every time a vehicle that means to move hasn't for ten seconds, or a man is blocked three times on the same walk, the game notes where, what it was doing and the likeliest cause (own vehicle, wreck, wall, crowd, map edge...) in `user://stuck_log.txt`. `--stuckrun --battles=N` plays AI battles back to back and prints the causes by count
- **Men pass each other:** a man with one of his own just ahead and in his way steps round him on the right, early, instead of walking into his back; two meeting where there's no room (a doorway, a stair) take turns
- **Paths keep off corners:** the turning points of a path are eased 40 cm out from the wall they bend round, on the ground and on the upper floors of the office block, which is where men used to snag
- **Stairwells share the load:** a flight with men already on it costs more to a man planning his way, so a squad spreads over the stairwells instead of queuing at one
- **Fixed:** the AI calling a recon plane before a battle had begun (in the battle builder, during prep or in the first seconds); it now waits two minutes and until the fighting has started

- **New vehicle driver:** instead of a pile of separate rules pulling the wheel different ways (reverse, three-point turn, give way, detour), the driver now imagines a handful of ways to drive the next two and a half seconds, each the curve the vehicle would really follow with its own turning circle, throws out any that would hit a wall, a wreck, another vehicle or one of his own men, and takes the one that gets furthest along the path pointing the right way. He backs up only when there's no way on, carries a tight turn through in a few goes, backs out of a street there's no room to turn in, waits behind his own instead of backing away from them, remembers what he has bumped into, and never takes steep ground or water. In test battles vehicles see-saw far less than before (1 to 2 episodes against 6 to 10 on the same battles) and get stuck about as rarely
- **Room clearing:** in the office block, a squad that knows of an enemy in an office on its floor stacks up either side of the nearest door, one man posts a grenade through the doorway, and they go in together: first man to one corner, second to the other, third down the middle, the last holding the door. They call the room clear and move on. Men inside a room with the enemy about cover its door
- **Stuck recorder** no longer counts a vehicle that's broken down or out of fuel, or one that made a wide turn and came back on itself

- **Fixed:** indoors, men no longer throw a grenade at an enemy they have no clear line to (under a ceiling it came back off the wall among their own squad)

- **Feet that stay planted:** each foot now stays on the spot it came down on while the body moves over it, then lifts, swings through and lands ahead where the body will be, on whatever is there (slopes, steps, stairs). The legs turn over at a rate that matches the ground covered (short quick steps at a walk, long ones at a run) instead of a runner's rate at every speed, and the hips ride lower as the stride lengthens. In the walk test a walking man's feet used to slide 62% of the distance he covered; now 2 to 5%
- **Stepping round on the spot:** a man who turns, or is left with a foot out of place when he stops, takes small steps to bring his feet back under him instead of swivelling on them
- **Leaning with the movement:** the body leans into a start, back against a stop, and into a swerve
- **Tanks and infantry together:** among buildings, or with enemy infantry near, an AI tank (or armoured car or half-track) no longer drives in alone: it waits up to 14 seconds for the nearest free squad, then goes forward at walking pace, and that squad walks in behind and beside it instead of in its own formation. Vehicles you have given an order to are left alone
- **Cover with a shot:** when picking cover the AI now checks more candidates for a line of fire before setting off, and a place it can't shoot from counts heavily against it unless the man is hiding

- **Keep right:** wheeled vehicles on a road now hold the right-hand side of it, so two meeting pass each other instead of both taking the middle, and their paths stay on the road instead of cutting corners across rough ground. In the road test (lorries sent both ways down one city street) all six kept right and passed 3 m apart; before, two of six did and they passed 0.9 m apart
- **A battle plan for the AI commander (commander battles):** instead of sending squads at your base as they turn up, the AI forms up first: scouts go forward while the squads gather at a forming-up point short of your base, on the side you're thinnest. Then everyone goes in together behind a barrage, with one squad round the flank and one held back in reserve. The reserve goes home if the AI's own HQ is threatened, or goes in once the attack has lost about half its men or had 75 seconds. An attack that has spent itself is called off and formed up again. A reckless commander skips the forming up
- **One way round for a squad:** the leader leaves a trail; a man who can't walk straight to his place in the formation follows the trail round the building the way the leader went (in test battles this made no measurable difference to how spread out squads get)
- **Going to ground and getting up:** the body goes down through a crouch over half a second, and comes up a little slower, instead of flicking between poses (the head used to jump up to 0.75 m in one frame; now 0.12 m at most)
- **Cover that can be reached unseen:** cover a man would have to cross open ground in the enemy's sights to reach now counts against it when he chooses where to go
- **Fixed:** small vehicles (the anti-tank gun, pushed by its crew) shut in by their own memory of what they'd bumped into, and vehicles that start pressed against something (a gun among its sandbags) unable to pull clear
- **Better explosions:** a flash, a ring of dust racing out across the ground, sparks, and clods of earth (rubble on a road) thrown out that land round the crater and stay there. A blast near where you're watching from dulls the sound for a moment
- **Guns by distance:** a hard crack on the front of a shot close by, losing its edge with distance until it's a dull thump that arrives late; in town a shot slaps back off the nearest wall and again off the far end of the street, and indoors it comes straight back off the walls of the room. Explosions do the same, and a far one is a low rumble
- **Smoother commander camera:** the view eases in and out when you pan, turn or zoom, jumps glide instead of cutting, and the wheel zooms toward what the pointer is on
- **Squad cards:** one click selects a squad, a double-click takes the view to it; **End** selects and shows the next of your squads that is fighting or pinned
- **Uniform wear:** mud builds up on the knees, elbows, belly and chest of men who crawl (quicker in rain); a dressing goes round the part that was hit once a wound is seen to; crews who get out of a burning vehicle come out blackened
- **Weather (in the battle setup, under World):** rain brings streaks through the view, wet shining roads and puddles pocked by the drops; cold brings a pale sky and breath in the air. Looks only: it changes nothing about the fight (a campaign storm still grounds aircraft, and now rains properly)
- **Light indoors (the Ministry offices):** the offices are dim and the corridors lit, with lamps down the ceilings and pools of light under them; daylight lies on the floor under every window, with bright patches where the sun comes in on the sunny side; a shot fired indoors throws a brighter flash up the walls
- **Vaulting and ladders:** going over a wall a man puts a hand down on the top, brings his knees up and over, and gives at the knees as he lands; on a ladder he turns to it and his hands and feet go onto the rungs (and come off at the top) over a few frames, instead of snapping between poses
- **Turning on the spot:** the feet step round as the body turns, and far-off men keep turning and stepping between their full updates instead of in jerks
- **Faster big battles:** far-off men and settled bodies are drawn with about 23 pieces each instead of 37 (pouches, canteen and the small parts of helmet and rifle are left off beyond the detail distance); far-off men get a fresh pose every other frame and are carried along in between; crews inside vehicles think every third tick; a body at rest costs almost nothing. In a test battle of about 110 men and 15 vehicles the simulation step went from about 14.5 ms to about 11.8 ms
- **Fixed:** a man getting up off the ground was knocked flat again by his own balance check (so getting up took a couple of seconds on the floor first); the anti-tank gun never noticed it had bumped into something because it is slower than the speed the check was written for
- **Renamed:** the game is now Tin Hat Tactics
- **Vehicles running into each other:** a driver now counts a way as shut if he couldn't pull up short of what's on it (before, anything more than three-quarters of a second away didn't count, far too late for a lorry at speed), takes it no faster than he can stop, and brakes properly when easing off. The back end is checked on a turn as well as the nose. A parked vehicle in the road is asked to pull over; squeezing past our own after a long jam is done at a crawl and no longer straight through them. Vehicles arriving at the edge of the map queue up instead of appearing on top of each other. In test battles collisions went from 6 and 8 in four minutes to 0 and 3
- **Less artillery from the AI:** each side has one battery, and after any fire mission it isn't to be had again for about a minute and a half, whoever asks (radio operators and the AI commander used to call it independently). Nobody shells men who are under a roof
- **The Ministry stands:** its walls, floors and roof can't be knocked down (furniture and barricades still break), and a blast stays on its own storey: a shell on the roof no longer wrecks the rooms and scorches the ground floor three storeys below. The fight for it happens inside
- **No AI building inside the Ministry:** AI commanders and their engineers put nothing up inside it
- **Rubble in the air:** what was lying on something that gets destroyed (rubble, clods, bodies) now falls with it; and when a building's upper storeys or roof are lifted off for the view, the rubble lying on them is hidden with them instead of hanging over the floor you're looking at
- **Rifle through the head:** a man hard up against a wall holds his rifle upright in front of his shoulder, tipped outward, instead of through his own helmet
- **Men walking past the enemy:** a man looked at only his six nearest enemies, and indoors those are often through a wall or on the floor above, so he could miss the one in front of him; now he keeps looking until he finds one he can see. Scouts fight when the enemy is close or has seen them, men holding fire for an ambush open up on anyone crossing or going away, and a man on his way round a flank stops for an enemy in plain view
- **Builders under fire:** anyone building, repairing or digging in downs tools and fights when an enemy is in view within rifle range, rounds are coming his way, he's hit, or the enemy is known to be close; nobody sets off to a building site while that's so
- **First battle:** a guided fight on the title screen that teaches selecting, sending men somewhere, moving the view, attacking, calling fire support and buying more men, one step at a time. The enemy in it stands still, shoots badly and has no commander; your squad waits where it is until you send it somewhere, the radio always works, and a squad that gets shot to pieces is replaced
- **Difficulty and enemy commander (battle setup):** Easy, Normal or Hard changes what the enemy's supply is worth, how often it buys and shells, how well its men shoot and how long it gives you before its first move; you can also pick the enemy commander's temperament (reckless, cautious, cunning) instead of leaving it to chance
- **Squad tags and contact alerts:** in the commander view each of your squads has a tag over it when it's doing something you'd want to know at a glance (Fighting, Pinned!, Out of ammo, Clearing rooms, Building, With the tank); from high up it shrinks to a coloured dot. A squad coming into contact is called out once in the alerts with a ring on the map. Tags aren't drawn over the buttons, the squad cards or the map. The cards no longer say "Fighting" when the enemy is merely known to be somewhere
- **Supply lorries keep to their line:** a supply or ammunition lorry on a run follows its route like a tram, slows for bends, and stops and waits for anything on its line instead of swerving round it; only when something has sat on the line for a while does it drive round the ordinary way. In five-minute town battles collisions went from 4 to between 0 and 2, and lorries no longer sit locked together (99 s spent overlapping down to 0 or 1 s). How many runs get through still swings widely from battle to battle (it depends on whether the supply dump survives), so there's no figure for that
- **Fewer explosions:** an AI mortar or field-gun crew fires three or four rounds and then stops for the best part of a minute (a mortar used to drop a bomb every five and a half seconds for as long as anyone was in view, half of all the explosions in a battle), and doesn't fire at men under a roof
- **Lit inside (the Ministry):** the inside walls, floors, stairs, door frames and furniture give back some light of their own, so the rooms and corridors can be seen at eye level and at night
- **Commander view:** opens over your own men and headquarters instead of the empty middle of the map; nothing is armed when a battle starts, so the first click on the map selects men instead of trying to buy a rifle squad there; on-screen messages sit on a dark plate so they can be read over a bright wall; the frame-rate line is no longer cut off and now counts draws
- **Drawing the map:** every box of the same kind of surface now goes into one batch with its own colour (it was one batch per colour, and every house is a slightly different shade)
- **Fewer things to draw:** a vehicle is about 120 separate pieces and a man about 30, and every piece was drawn a second time for its shadow. Small pieces (handles, lamps, pouches, straps) no longer cast one, a vehicle a long way from the view drops its small pieces altogether, and smoke and spark emitters waiting for work aren't drawn. In a town fight with 50 men and 10 vehicles a frame went from about 3,950 draws to between 2,900 and 3,500 (it varies with what has been built and blown up); shadows are still the largest share (about 1,400 to 1,600)

- **Campaign rework:**
  - **How to fight each battle:** a battle now waits on the campaign screen with the odds, and you choose: command it from above, go in as one of the men while the AI commands your side, or auto-resolve it on paper (quick, but it costs more men, earns no objective, and fewer are promoted)
  - **Regions worth holding:** ten of the twelve give whoever holds them (in supply) something: cheaper infantry, cheaper vehicles, extra income, a field hospital, trained recruits, artillery support in every battle. It's written on the map
  - **Scouts' reports:** Bravo's next move is drawn on the map as a red arrow a turn ahead. Move men in the way and it may call the attack off
  - **Defending:** when you command a defence you get a stock of sandbags, wire, MG nests, tank traps and a mortar pit that go up at once, wherever you place them, before the enemy arrives
  - **The company:** every man has a rank (private to staff sergeant), sergeants pick up a perk (marksman, tough, steady, scrounger), and everyone who doesn't come back goes on the roll of the fallen with his kills and where he fell
  - **Questions:** most turns' events now ask you something (arm the partisans or keep the money, take volunteers or send them to the workshops, buy a tank no questions asked)
  - **Optional objectives:** each battle you fight yourself has one (win inside eight minutes, lose no more than a third, knock out every enemy vehicle, spare the town, bring your vehicles home) with a reward
  - **The Ministry:** taking the Capital is two battles: the city, then storming the Ministry building
  - **The Front Gazette:** a headline each turn; and a **short campaign** of six regions alongside the full twelve
- **Orders:** Hold fire (shoot only if shot at, or at 15 m), Ambush (lie low and hold fire until the enemy is within 30 m; the first shot releases the squad), Patrol (walk a beat between two points), and right-click a building to send the selected men in to man its windows and doors. A squad answers an order out loud. Men on a plain move order now defend themselves: an AI side's men stop and fight what they meet, yours stop for an enemy within 40 m or anyone shooting at them (Fall back still keeps them moving). In tests a squad sent across an enemy section's front walked straight past it four times out of four before, and stopped to fight four out of four now
- **Reactions:** a man turns on whoever has just hit him, or is firing at him, even with another enemy nearer in front. A man whose shot is blocked looks for a spot with a clear line instead of stepping left and right at random (that was the pacing up and down inside houses), and gives up on that target for a while if there isn't one. A wounded man dresses the wound before anything else
- **Roof posts:** snipers, spotters and anyone at a lookout post are left out of flanking runs, room clearing and salvage, a posted man crosses to a parapet facing the enemy instead of climbing down, and a sniper keeps a post nobody is shooting at. The middle stay at a post went from 8 s to 28 s in the test, and stays under 8 s from six in twelve to one in ten. Men walk the last step to a ladder instead of being put on it
- **Squad tags** hang on one of the squad's men (not the middle of a scattered squad, which could be empty ground), carry the squad's number, and have a stem down to him. **Squad cards** show a lorry, a jeep or a gun for those, not a tank
- **Looks:** helmets sit down on the head and come round the sides and back; the officer's cap no longer has a helmet rim under it; the rifle rides on top of the hands instead of through them; men give back a little of their own colour so they aren't black in shade or indoors; a burning vehicle has orange flames and black smoke instead of a white ball of light; from high up every man gets a dot in his side's colour
- **Nothing left hanging:** a roof, upper floor or upstairs wall with no standing wall under it comes down; a downed man with a limb under the ground is lifted clear before he's left to lie, and a standing man who ends up under it is put back on top
- **Settings:** Shadows can be Automatic (turned down a step if the frame rate stays under 38 for five seconds), All, Near the view only, or Off
- **Small things:** the hint line gives way to the row of orders; the on-screen message is drawn in to clear the squad cards in a narrow window; a drop-down can't open in the instant after another closes; recruit cards say what the unit is good at and weak against
- **Taking control in the browser:** if the browser doesn't hand the mouse over when you take control of a man (the pointer stays on screen and he can't be aimed or fired), the next click asks for it again, and a line on screen says so
- **Your own tracer rounds** are drawn as plain tracers: the wide glow on a machine gun's tracer, seen end-on from behind the gun, was a big orange square leaving the muzzle
- **Rocket men** carry a carbine as well. The launcher comes up when there's armour within 90 m or an enemy strongpoint within 60 m; otherwise they fight with the carbine, and no rocket is fired at a man on foot. Reloading the launcher takes five seconds: the tube comes down, a rocket comes over the shoulder from the pack and is pushed home, and the tube goes back up. In a town battle with no armour the rockets fired went to none
- **Squad command wheel** is on ` (the key under Esc), not on Q: holding Q to lean no longer brings the wheel up
- **No rings following the pointer:** with men selected, the rings that showed where each would stand are gone (a line dragged with the right button still shows them)
- **Sandbox is yours:** in a sandbox the AI commanders no longer call in artillery, air strikes, paratroopers or helicopters, buy vehicles, or have radio operators call barrages of their own. "AI support in sandbox" in the battle setup turns it back on
- **Supply lorries that stop:** three safety nets. One that makes no headway for 14 s is taken off its line and left to the ordinary driver for 45 s, and after another 20 s is let through friendly vehicles; a man of yours standing on its line is asked to step off instead of waited for; and one that fails two runs from the same spot (boxed in by something built or parked round it) is manhandled by its crew to the nearest clear ground. Supply and ammo lorries also no longer run out of fuel. (The report of lorries stuck for good could not be reproduced in tests on the town and Western front maps, with either side commanding, so which of these fixes it is not known)
- **Militia vehicles:** the gun truck, the armoured bus and the old tank can be bought (they were missing from the list of things a side may call in, so only the technical showed); the AI's militia buys them too
- **Squad tags hold still:** a tag stays up at least two and a half seconds and a new word waits for the old one, instead of flashing as the squad's state flickers; it stays on the same man while he's near the middle of the squad
- **Sound in the browser.** The browser build was completely silent. The game added a second audio bus as it started, and the engine's web audio puts a bus added that way in front of the master, then routes the master into it, leaving nothing connected to the speakers. In a browser everything now plays on the master bus. Checked by reading the signal at the page's output: nothing before, sound after.
- **A louder battle.** The battle used to be heard from the camera itself, so from a commander's height it was a faint patter. Now it is heard from a point close over the ground you are looking at, sounds carry further, and a limiter (the engine's own on desktop, one in the page for the browser build) keeps the loudest moments from clipping.
- **No spoken voice.** Shouts and radio messages are text on the screen; nothing is read out by the computer's speech voice any more (it drowned everything else). The setting for it is gone.
- **Title music.** A slow march plays on the title screen and in the menus, fades out as a battle comes up and comes back afterwards. The music slider controls it.
- **Zombie battles:** nobody throws smoke at the dead or goes through their pockets for ammunition. A man with a zombie on top of him shoves it off with his rifle (it staggers back or goes over), and men backing away pick the way with the most room instead of the first free step, so they stop wedging themselves into corners. Fewer bodies are kept lying about and the dead cast no shadows, which is where the slowdown was.
- **Grenades** are not thrown with a wall right in front of the thrower (the hand went through it and the grenade started on the far side). The throw itself is slower and bolder: pin out at the chest, arm cocked beside the head with the grenade (or smoke can, or bottle) in the hand, over the top; the rifle stays down in the other hand.
- **Campaign: up to three companies of a side can share a region.** The strongest fights; the ground changes hands only when the last one there has been beaten. Bravo doubles up where your neighbours outnumber it.
- **Supply lorries** have a closed cab: the driver cannot be seen, shot out of it or made to climb down, so a lorry is only stopped by wrecking the lorry. They do not set out for a stop with the enemy within 60 m, and turn round if the stop comes under attack on the way.
- **Black Banner vehicles** (old tank, gun truck) wear their own sand, rust and black paint with a large banner, so they are not mistaken for the army's green ones.
- Fixes: the row of tools at the bottom now belongs to the new battle as soon as it starts (it showed the previous mode's tabs until clicked), and a second battle in the Ministry no longer stacks another set of floor buttons under the first.
- **Voices without words.** Men shout with their callouts, grunt when they throw or shove, cry out when hit and sometimes scream going down: generated sounds, a different pitch for every man, no speech.
- **Everyday sounds:** magazine changes, the pin and spoon of a grenade, vehicle doors, footsteps that differ on earth, road and indoor floors, and a horn call when a battle is won or lost. A separate **Effects** slider sits beside the music one.
- **The horde is heard before it's seen:** a bed of moaning that grows with their numbers and as the nearest closes on where you're listening from.
- **Zombie battles give you reasons to move.** Each wave comes mostly from one side, announced. From the second wave a supply drop lands 45 to 70 m out under a green light: reach it in 85 s for points, ammunition and sometimes a machine gun or dressings. The building nearest the middle is the keep: men inside it mend and restock between waves, and "Fall back to the keep" (Armoury tab, free) calls everyone in. Men you send somewhere now go, instead of stopping because one of the dead is in sight.
- **Cheaper zombies:** beyond 26 m from the camera a zombie is posed, not simulated, and moves thirty times a second instead of sixty; bodies are put to rest sooner. Measured with 60 of them walking: 11.5 ms a tick against 20.1 with a low camera, 9.1 against 11.2 from above.
- **The entrenching tool.** A man with nothing left to fire fights with his spade, swung two-handed where you can see it (the last stand used to be an invisible knife). The Charge order already fixes bayonets.
- **Campaign: reserves.** Another of your companies in the region (or in the one you attacked from) sends up to eight men into the battle about two minutes in; what they lose is taken off that company. Bravo's do the same. On paper each reserve company is worth 20%.
- **Campaign: company commanders.** Each of your companies has a named officer with one strength (Fire-eater, Steady, Quartermaster, Scrounger, Old hand). He is on the field with his men: if he falls he is wounded (away two turns) or killed (the next man takes over, with a way of his own). Wins bring promotion.
- **Campaign: turn report.** When a new turn starts one sheet shows Bravo's moves, what the turn cost you, what changed and any other dispatches.
- **Your men stay where you send them** until you give another order (a side the computer commands still drifts back into the fight).
- **The Ministry's inside walls can be blown through** (three grenades or a satchel); the outside walls, floors and stairwells stay.
- **Casualties from the commander view:** a red cross over every man of yours who is down, ringed by the life he has left; a green line from whoever is coming for him, an amber blinking ring and an alert when nobody is.
- **Slow-motion finish:** when a battle ends the last few seconds run at quarter speed while the camera circles the last man to fall or the last big explosion, then the result comes up. Any key skips it; it can be switched off.
- **Symbols that were empty boxes in the browser** (menu, back, play, flags, stars, ticks, arrows) are now drawn as images or written as words.
- **Graphics presets:** Low, Medium and High set picture sharpness, shadows, detail distance, soldier limit and grass together; "3D picture drawn at" can be set on its own.
- **Save a battle in progress** (one slot, from the pause menu; "Continue saved battle" on the title screen). Kept: the map and its ruins, every man on foot with his name, rank, weapon, wounds and ammunition, vehicles and their damage, structures, orders, score, points, supply and the zombie wave. Not kept: shells in flight, fires, bodies, squads (they form again), passengers, and what each man was doing. Campaign battles are not saved part way.
- **Zombies break what you build.** A brute goes through a barricade instead of round it: sandbags in one blow, a concrete wall in two. The others claw at a defence when it is what is stopping them. Engineers repair between waves.
- **Saved battles keep squads and passengers.** Every man comes back in the squad he was in, and a man who was aboard a vehicle is put back in his seat with his own name, weapon and ammunition.
- **Battle music in the browser** is three finished mixes (calm, tense, hot) with one playing at a time; a change is made on a bar line, from the same place in the loop, at most every six seconds. (A browser cannot turn a playing sound up or down, which is how the desktop build layers it.)
- **A second campaign: The Islands.** Ten regions. You hold one harbour town; the two beaches next to it have to be taken first, and the Citadel can only be reached through Foundry Isle or Pinewatch. "New campaign…" now opens a chooser: Mainland, Short War or Islands.
- **Campaign difficulty:** Easy, Normal, Hard. It sets both war chests, what Bravo earns, how strong its companies start, how readily it attacks, and how good its soldiers are in the battles.
- **Battle difficulty widened.** Measured over three AI-against-AI battles a setting, the enemy took 42% of the kills on Easy, 50% on Normal and 60% on Hard (before the change it was 43, 47 and 47: Hard was no harder than Normal). `--difftest` repeats the measurement.
- **Ironman:** with it on, losing headquarters ends the campaign. With it off, headquarters falls back to the nearest region you still hold and leaves half the war chest behind; the campaign ends when there is nowhere left to go.
- **Balance pass.** Weapons that lost to the rifle at their own job were brought up: SMG damage 21 to 24, shotgun 14 to 18 a pellet with a tighter pattern and quicker pump, carbine 26 to 32 and faster, BAR 32 to 36 with a 24-round magazine, DMR 62 to 70 and faster, sniper 96 to 125 (a body hit now kills), machine gun a little tighter, and the rifle a little less accurate at long range. Engineers cost 10 (was 12) and the anti-tank team 12 (was 14). `--baltest` prints every weapon's output and fights six of each against six riflemen.

## Controls
**Free camera:** WASD fly, Space/E up, Q/C down, Shift faster, right-drag look, wheel zoom. 1–9 pick a tool, left-click uses it, F takes control of the soldier at the centre of the screen.
**Command tab:** click a soldier (double-click for his squad) or drag a box to select, right-click the ground to send them there, a vehicle or mortar to get them in it, or a structure going up to have them build it. In the commander view right-drag draws a line for them to form up on (middle-drag turns the camera), and Shift + right-click adds stops to their route. Home jumps to the heaviest fighting and End to the next of your squads in contact; the wheel zooms toward the pointer.
**Controlling a soldier:** mouse aim, left-click fire, right mouse aim down sights, Q/E lean, Shift sprint, C crouch, Z prone, R reload, G grenade, V smoke, L flare, 1–5 weapons, Y first person, O squad follows you, F pick up a fallen soldier's gun or get into a vehicle, hold U to help build a friendly site, I to dismantle what you aim at, X leave the soldier.
**In a vehicle:** WASD drive, mouse aims the turret, left-click fire, 1–4 change seat, F get out.
**Controlling a soldier (more):** walk into a ladder to climb it, 0 for a panzerfaust.
**Anywhere:** Page Up / Page Down floor view (office block), M or Esc menu, H help (dresses your wound while controlling a bleeding soldier), J battle report, P pause, T slow motion, F2 night vision, F9 path debug view, Space ends campaign battle prep.

## I couldn't run this, so please report problems
I couldn't run Godot where I wrote this. I checked the scripts with a static checker, but the first run will probably surface a few errors. When something breaks, send me:
- **Red errors** from the Debugger → Errors tab or the Output panel. Copy the text, which includes the file and line, e.g. `soldier.gd:412`.
- **What it looks like.** A screenshot or a one-line description is enough, e.g. "soldiers fold up like a deck chair".

### Things most likely to need a tweak
- **Knees or elbows bending the wrong way:** in `scripts/g.gd`, change `KNEE_SIGN` (or `ELBOW_SIGN`) from `1.0` to `-1.0`.
- **Soldiers too floppy or too stiff:** in `scripts/soldier.gd`, standing muscle strength is `var strength = 0.42` near the top. Wounded soldiers use 0.18.
- **Low frame rate with lots of soldiers:** lower the team size in the menu first, then tell me your soldier count and FPS.

## Files
| File | What it does |
|---|---|
| `scripts/g.gd` | Autoload `G`: constants, weapons, team colours, shared state and helpers |
| `scripts/main.gd` | Scene setup, sky and lighting, game start, spawning, simulation tick, modes |
| `scripts/world.gd` | Terrain, map building, colliders, navigation grid, cover points, destruction |
| `scripts/soldier.gd` | Ragdoll body, muscles, poses, gun model, soldier states |
| `scripts/ai.gd` | Perception, intel sharing, cover, decisions, movement, aiming |
| `scripts/combat.gd` | Shooting, damage, rockets, grenades, mortars, explosions |
| `scripts/fx.gd` | Particles, tracers, decals, lights, debris, callouts |
| `scripts/audio.gd` | Generated sounds and the 3D audio pool |
| `scripts/player_cam.gd` | Camera, input, controlling a soldier, tools |
| `scripts/ui.gd` | HUD, scoreboard, kill feed, tool bar, menus |
| `scripts/squadcards.gd` | Commander view squad cards |
| `scripts/icons.gd` | Weapon and status icons drawn at start-up |
| `scripts/navviz.gd` | Path debug view (F9) |
| `scripts/rooms.gd` | Room clearing in the office block: stack on the door, grenade, entry, clear |
| `scripts/stucklog.gd` | Stuck recorder: what got stuck, where and why |
| `scripts/levels.gd` | Buildings with real floors: a path grid per storey, joined by stairs |
| `scripts/office.gd` | The Ministry offices map (three storeys of corridors, rooms and stairwells) |
| `scripts/floorview.gd` | Floor view: lifts off the floors above the one you pick |
| `scripts/prep.gd` | Campaign battle prep phase |
