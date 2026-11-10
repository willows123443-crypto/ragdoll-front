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
- **Campaign:** nine regions to take one battle at a time; survivors become veterans with stripes, and whatever gets wrecked in a region stays wrecked, structures left standing are still there next time, and your surviving vehicles carry on as a motor pool
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
- **Time passes:** "Dawn till nightfall" starts a battle at first light and runs into the night over about eighteen minutes, with the sun moving across the sky and night tactics kicking in when it gets dark (or pick the endless day and night cycle)
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
- **Commander mode, a real war economy:** fog of war (enemy troops and vehicles only show while your men can see them, their structures once found); control groups (Ctrl+number saves a selection, the number recalls it, twice to look at it); vehicles you buy are built one after another at the depot (two depots work faster); upgrades researched at HQ (heavier armour, field engineering, heavy artillery, logistics); and supply dumps only pay when a supply convoy drives in from your edge of the map and gets through, so the enemy can ambush it
- **Zombie mode:** a 30-second break after each wave to dig in; kills earn points to spend in the Armoury (board up a building's windows, machine guns, shotguns, a flamethrower, ammo, first aid, an extra man) and on barricades from the Build tab; the dead tear at boarded windows; after dark there are more of them and they're faster
- **Mode settings:** settings a mode doesn't use are greyed out in the setup screen, and the in-battle reinforcements switch is sandbox only; outside sandbox and commander mode reinforcements are free (no paratroopers or helicopter troops to buy)
- **Fixes:** jeep and technical machine guns sit well above the car on a post with the gunner on a step behind (the jeep's windscreen folds flat), and mounted guns can't point down into their own vehicle; every gun model's parts are joined up (no floating barrels or sights)

## Controls
**Free camera:** WASD fly, Space/E up, Q/C down, Shift faster, right-drag look, wheel zoom. 1–9 pick a tool, left-click uses it, F takes control of the soldier at the centre of the screen.
**Command tab:** click or drag a box to select soldiers, right-click the ground to send them there.
**Controlling a soldier:** mouse aim, left-click fire, right mouse aim down sights, Q/E lean, Shift sprint, C crouch, Z prone, R reload, G grenade, V smoke, L flare, 1–5 weapons, Y first person, O squad follows you, F pick up a fallen soldier's gun or get into a vehicle, hold U to help build a friendly site, I to dismantle what you aim at, X leave the soldier.
**In a vehicle:** WASD drive, mouse aims the turret, left-click fire, 1–4 change seat, F get out.
**Controlling a soldier (more):** walk into a ladder to climb it, 0 for a panzerfaust.
**Anywhere:** M or Esc menu, H help (dresses your wound while controlling a bleeding soldier), J battle report, P pause, T slow motion.

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
