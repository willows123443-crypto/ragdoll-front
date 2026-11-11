# Ragdoll Front: Godot 4.6 port (Stage 1)

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
- **In a soldier's boots:** your magazine and spare rounds sit by the crosshair with a bar of rounds; squadmates show as green ticks on the compass; hold Q for the squad wheel (Follow me, Attack there, Smoke there, Take cover, Hold here, As you were): move the mouse toward one and let go. A quick tap of Q still leans
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

## Controls
**Free camera:** WASD fly, Space/E up, Q/C down, Shift faster, right-drag look, wheel zoom. 1–9 pick a tool, left-click uses it, F takes control of the soldier at the centre of the screen.
**Command tab:** click a soldier (double-click for his squad) or drag a box to select, right-click the ground to send them there, a vehicle or mortar to get them in it, or a structure going up to have them build it. In the commander view right-drag draws a line for them to form up on (middle-drag turns the camera), and Shift + right-click adds stops to their route.
**Controlling a soldier:** mouse aim, left-click fire, right mouse aim down sights, Q/E lean, Shift sprint, C crouch, Z prone, R reload, G grenade, V smoke, L flare, 1–5 weapons, Y first person, O squad follows you, F pick up a fallen soldier's gun or get into a vehicle, hold U to help build a friendly site, I to dismantle what you aim at, X leave the soldier.
**In a vehicle:** WASD drive, mouse aims the turret, left-click fire, 1–4 change seat, F get out.
**Controlling a soldier (more):** walk into a ladder to climb it, 0 for a panzerfaust.
**Anywhere:** M or Esc menu, H help (dresses your wound while controlling a bleeding soldier), J battle report, P pause, T slow motion, F2 night vision, F9 path debug view, Space ends campaign battle prep.

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
| `scripts/prep.gd` | Campaign battle prep phase |
