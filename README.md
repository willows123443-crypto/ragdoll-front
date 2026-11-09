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
- **Modes:** sandbox, deathmatch, capture the points, frontline, assault, last stand, destroy base, breakthrough, sabotage (night raid), siege, convoy escort, pilot rescue, a king-of-the-hill flag that moves, a top-down commander (RTS) mode and a zombie horde — the menu explains each
- **Daily challenge:** one battle a day picked from the date (map, mode, time of day, twists), with your best result kept
- **Doors and windows:** soldiers kick doors open, glass shatters when shot, and grenades get lobbed in through windows
- **Huge battles:** 100 a side or more; far-off soldiers are simplified so the battle keeps running
- **Air war:** fighters and dive bombers you can fly, AA guns, helicopter transports and gunships
- **Logistics:** fuel, towing, bridge layers, supply trucks that restock FOBs, ammo boxes you can carry, upgrades (concrete walls, pillboxes, huts), camo nets and rebuilding
- **Campaign:** nine regions to take one battle at a time; survivors become veterans with stripes, and whatever gets wrecked in a region stays wrecked
- **Scenario codes:** save a battle as a code and share it
- **Commander's map** (Tab): see the whole battle and send squads around
- **Maps:** Town ruins, Farmland, Trenches, Forest, City blocks, a tank factory fought indoors, Beach landing, large maps (Valley offensive, Western front, River crossing, Mountain pass), the huge battlefield, random maps, and your own from the **map editor** (sculpt and paint the ground, place buildings, squads and vehicles with orders and waypoints, and triggers that set off reinforcements, barrages, messages or a win)
- **Modes:** sandbox, deathmatch, capture the point, frontline (push across a chain of points with tickets), assault, last stand
- **Up to four sides** with your own names, armband colours and uniforms; day, dusk or night
- **Command:** select soldiers and send them somewhere, team orders, "follow me"
- **After-action report** (J) and first-person view (Y)

## Controls
**Free camera:** WASD fly, Space/E up, Q/C down, Shift faster, right-drag look, wheel zoom. 1–9 pick a tool, left-click uses it, F takes control of the soldier at the centre of the screen.
**Command tab:** click or drag a box to select soldiers, right-click the ground to send them there.
**Controlling a soldier:** mouse aim, left-click fire, right mouse aim down sights, Q/E lean, Shift sprint, C crouch, Z prone, R reload, G grenade, V smoke, L flare, 1–5 weapons, Y first person, O squad follows you, F pick up a fallen soldier's gun or get into a vehicle, hold U to help build a friendly site, I to dismantle what you aim at, X leave the soldier.
**In a vehicle:** WASD drive, mouse aims the turret, left-click fire, 1–4 change seat, F get out.
**Anywhere:** M menu, H help, J battle report, P pause, T slow motion.

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
