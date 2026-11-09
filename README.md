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

## What's in Stage 1
- Active ragdoll soldiers: 11 rigid parts joined by joints, with muscles that pull the body toward a procedural pose. Soldiers stumble, fall, get back up, get wounded and die as ragdolls.
- Three maps (Town, Field, Trenches), each with terrain, trenches, towers with stairs and destructible walls and buildings.
- Three modes: Sandbox, Deathmatch and Capture. You can set the team size, the score limit and whether reinforcements are on.
- AI:
  - Line of sight, with knowledge shared by radio within a squad, by shouting nearby and by hearing gunfire.
  - Cover-taking, leaning and peeking, snipers in towers and medics who drag the wounded.
  - Grenades and smoke, plus friendly-fire and muzzle-clearance checks.
- Weapons: rifle, LMG, sniper, shotgun and RPG. Also grenades, smoke, mortar strikes and explosions that destroy walls.
- Effects and sound: blood, dust, sparks, decals, tracers, muzzle flashes, debris and procedural sound with reverb.
- Tools menu: spawn soldiers or squads, take control, push, explosion, mortar, smoke and move spawn points.

## Controls
**Free camera:** WASD to move, Space/E up, C/Q/Ctrl down, Shift for speed, right-drag to look, mouse wheel for speed.
- 1–9 pick a tool; left click uses it.
- F takes control of the soldier under the cursor.

**Controlling a soldier:**
- WASD to move, Shift to sprint, Q/E to lean.
- Left click fires; right click aims (scope on the sniper).
- R reload, C crouch, Z prone, G grenade, V smoke, 1–5 change weapon.
- X or Esc leaves the soldier.

**Anywhere:** M menu, H help, P pause, T slow motion.

## Not ported yet (Stage 2)
Vehicles, scenarios, unit selection and orders, night and flares, the build tool and the settings panel.

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
