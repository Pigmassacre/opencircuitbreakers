# Circuit Breakers reverse-engineering map

Ported behavior lives in the comment on the port function in `Project/scripts/`. This file is the map. When a pass learns something the port implements, write it in that comment and add or point the index row at the function. A convention, a file format, a global, a caller chain, or a difference that has no one port function is written here.

Addresses are functions in the PS1 executable `SLUS_006.97`. A Ghidra address is the `Inspo/re/main.bin` offset plus `0x10000` (the bin has no `0x800` header). Decompiles are `Inspo/re/funcs/XXXXXXXX.c`. The listing is `Inspo/re/listing.txt`. The disc root is `Inspo/re/fs/LES00753/`.

## Units and frames

The original simulation runs at 30 Hz. The port subdivides each of those game frames into 4 physics ticks.

- `4096` is one world unit, and also one full turn (`4096 = 360°`).
- Velocities are fixed-point world units per game frame.
- A world unit is `2.4 / 158` metres.
- Original `(x, y, height)` is the port's `(x, z, y)`.
- Car positions the script sees are whole units, truncated toward zero, matching the shorts the original keeps beside its fixed-point position.
- Distance tests are axis-aligned: `|delta|` below the given unit extents.
- AI speeds are the physics `|vel| / 64`. AI headings are the original's, which is the negated port heading.
- A camera yaw of `0xc00 - heading` looks along that heading.

The car's attitude is two world-axis tilts applied before the heading: x about the X axis, y about the Z axis. The fall line is stored a quarter turn off the heading convention, so slope push peaks when driving straight up or down a slope and vanishes when driving across it. Steering on a slope also turns the car toward that fall line.

Model space for the car body is x forward, y down, z left, with the origin `ground_offset` above the wheels' contact. The renderer's model frame (`FUN_00033484`) is `(-y, x, -height)` of the world. The PS1 projects with `H = 240` onto a 240-line screen, which is a vertical FOV of about 53.13°.

## Files

Per-world handling sits at offset `0xFE8C` of each `.TRK`: `[drag, grip, engine, brake, turn rate]`. The executable has a fallback of `[32, 40, 6700, 4096, 56]` when a track does not supply one.

The track script is a list of shorts at `.TRK` offset `0xFEDC`.

`CARS.DAT` and the exported track mesh use the same vertex layout. `mesh.bin` holds two triangle lists (single-sided, then double-sided). Each list is prefixed by its vertex count. A vertex is 12 floats: position, normal, color, uv. A car file is the body followed by each wheel model, every model in that same two-list form.

Tournament pickup placement comes from `CBBYSS.CON`. Other tracks place the pickup at random.

Sound samples come from the `SOUND/GAME1` VAB. A tone is `[vag, volume, bend down, bend up, center, shift]`. Vag numbers are 1-based. `Tools/export_sfx.py` writes them. Playback is `sound.gd`. Music is the eight CD-DA tracks after the data track: song 0 is CD track 2 (`FUN_00075e3c` writes the lead-out at TOC index 0). `Tools/export_music.py` writes those tracks from a cue.

Particles are additive textured quads taken from a Circuit Breakers TEX. Fire is tpage `0x2e`, a 4×4 sheet of 64px cells. Smoke is tpage `0x3e`, an 8×2 sheet of 32px cells. `fx.gd` draws them. `Tools/export_particles.py` rebuilds the sheets.

## Vibration

`FUN_00032360(pad, pattern, priority, car)` queues a pad pattern only when the pad's current priority is at most the new one, and restarts its frame counter. It does nothing for a car other than 0 with one human or in a time trial, or while `_DAT_000a7318` or `_DAT_000a6930` is set. `FUN_00032434` plays the pattern once per pad read while option `_DAT_000a6cfc` is on (default on), and `FUN_00032594` clears it at the last frame. Patterns are `[small motor, large motor, frames]`; the table is `car.gd` `RUMBLE`.

Several calls were once read as sounds: bump "tone 4", wreck "tone 5", rocket "tone 6", splash "tone 9", and a looping spray. They are patterns 4, 5, 6 and 9 and the water-surface pattern 2. The loose-surface sound is `FUN_00072394`, keyed off the drift puff.

The front-end lift (`FUN_00066d9c`) also vibrates; the port has no 3D car select.

## Bumper cars

`_DAT_000a7200`. `FUN_0003574c` flips it while the countdown sits at 1 (`DAT_000a647c == 1`, `_DAT_000a6f78 == 0`) on the press of car 0's pad going to exactly `0x480` (Left and Circle), with more than one human, outside a submarine world and a time trial. It draws sprite `0xc5` of table `_DAT_000a7334` at x `0x100`, y `0xa0` plus the 16-entry bob at `0x14e60`. While set, no pickups are placed with several humans, `FUN_00056cf0` runs no items, every car draws record 8 of its world's car file, and the `FUN_00056348` kick doubles to `0x8000` while the front end is down (`_DAT_000a6b24 == 0`). The 3D car select (`_DAT_000a6b24 == 1`) drives bumper cars at the normal kick; in play the toggle only arms in a battle, since that is the only start with several humans.

`FUN_00024bc4` arms the countdown (`DAT_000a647c = 0x14`) for every start, battles included. `FUN_0003a330` holds every car for the whole countdown unless one human races outside a time trial.

## Front end

`_DAT_000a6b24` is the front-end flag: 1 at boot and while the 3D car select runs, cleared by `FUN_00028d18` when a track is picked. It is not a battle flag. Everything gated on it (the doubled bump kick, the wreck vibration, the surface-2 wreck, the engine's `+10` and the engine scale's `-50`) is front-end behavior the port has no use for.

## Sound frame

`FUN_000717f4` runs once per frame after the car updates: scale (`FUN_00072ee0`), music, reverb, the engines (`FUN_00073d58`, `FUN_00074028`, `FUN_00071b1c`), then the one-shot checks (wreck, spray, respawn, bump, loose surface, countdown beep). `FUN_00070bcc` and `FUN_00070cb8` set `_DAT_000a6e90` through `FUN_00070d94` whenever they key a voice, loops included. Only when nothing was keyed that frame do the round robin (`FUN_00071cc0` for car `DAT_000a626c`), the rain (`FUN_00073c60`) and the item tones (`FUN_00072864`) run, so the ones further down the list can lose a frame. `_DAT_000a7418` limits the engines and the round robin to eight cars with one human and to the humans otherwise. `sound.gd` `_physics_process` is this pass.

`FUN_00070940` sets reverb type 4 (Studio C) at depth 0. Every `GAME1` tone has the reverb bit, so the port puts the reverb on the whole SFX bus.

`_DAT_000a7318` is set by `FUN_0006ad00`, the 2D mode menu. `FUN_00072ff8` and `FUN_00073108` are its button beeps and `FUN_0007258c` is front-end only; the port's menus use `Sound.ui`.

## Open differences

`FUN_0002ac8c` and `FUN_0002aec4` also raise the respawn tone (`_DAT_000a6b10`); their callers are not identified. The second `_DAT_000a6e38` setter, near decomp line 39374, is not identified either.

## Function index

| Address | Port | What it is |
| --- | --- | --- |
| `FUN_00018c7c` | `sound.gd` `music_frame` | Display-buffer parity, flipped before the audio update |
| `FUN_0001f60c` | `car.gd` `update_body_lean` | Apply body roll |
| `FUN_00020a80` | `items.gd` `update_pool` | 16-slot dropped and launched item pool |
| `FUN_00021450` | `items.gd` `move_shot` | Shot follows the floor, dies on a wall |
| `FUN_00021e48` | `items.gd` `pickup_quad` | Pickup quad |
| `FUN_00024bc4` | `battle.gd` `start` | Battle setup |
| `FUN_00026628` | `race.gd` `start`, `track.gd` `rough_nodes` | AI start-phase counter, rough-node share; the original audio update runs from here |
| `FUN_00029494` | `autopilot.gd` `restore_handling` | Single-player AI, handling restored each frame |
| `FUN_00029c1c` | `items.gd` `car_frame` | Cycle and fire items |
| `FUN_0002a824` | `car.gd` `wreck` | Wreck, pattern 5 |
| `FUN_0002ae04` | `car.gd` `begin_splash`, `step_splash` | Splash, pattern 9 |
| `FUN_0002ecb0` | `track_script.gd` `carpet` | Carpet |
| `FUN_0002f228` | `track_script.gd` `scroll_objects` | Scrolling objects |
| `FUN_0002f2e8` | `track_script.gd` `run` | Track script interpreter |
| `FUN_0002f844` | `car.gd` `hold` | Script holds a car |
| `FUN_0002f884` | `track_script.gd` `branch` | Script `IF` / `GOTO` |
| `FUN_0002fa78` | `track_script.gd` `evaluate` | Script expression |
| `FUN_00032360` | `car.gd` `rumble` | Queue a vibration pattern |
| `FUN_00032434` | `car.gd` `step_rumble` | Play the vibration pattern |
| `FUN_000325ac` | `session.gd` `apply_fog` | Track renderer: cell flood fill, draw reach, `SetFogNearFar` |
| `FUN_00033484` | `track_script.gd` `MODEL_TO_WORLD` | Renderer model frame |
| `FUN_00033934` | `autopilot.gd` `race_phase` | AI heading after the start |
| `FUN_0003403c` | `autopilot.gd` `use_items` | AI item fire |
| `FUN_000345d8` | `autopilot.gd` `steer` | AI throttle |
| `FUN_0003486c` | `autopilot.gd` `steer_ahead` | AI steer |
| `FUN_0003496c` | `autopilot.gd` `off_track` | AI recovery past an edge |
| `FUN_00034afc` | `autopilot.gd` `on_track` | AI corner heading |
| `FUN_00034cb4` | `track_camera.gd` `update_node` | Camera segment from the car's node |
| `FUN_00035554` | `race.gd` `step_countdown` | Countdown step, beep flag |
| `FUN_0003574c` | `race.gd` `toggle_bumper`, `hud.gd` `paint_bumper` | Bumper-car toggle and sign |
| `FUN_00035c5c` | `track_camera.gd` `_physics_process` | 1-player race camera |
| `FUN_00036f5c` | `battle_camera.gd` `_physics_process` | Battle camera focus |
| `FUN_000370d8` | `race.gd` `start` | AI start-phase counter |
| `FUN_000373d4` | `autopilot.gd` `start_phase` | AI start-phase chase |
| `FUN_00037d64` | `track.gd` `cell_kind`, `race.gd` `complete_lap` | Cell kind and lap logic |
| `FUN_000381d8` | `track.gd` `lookup_node` | Node under a point |
| `FUN_00038418` | `track.gd` `search_gate` | Gate search |
| `FUN_000388c4` | `track.gd` `lane_height`, `battle.gd` `grid_slot` | Lane placement, respawn clear, battle grid |
| `FUN_000398c4` | `battle.gd` `set_back` | Expert battle respawn, two nodes back |
| `FUN_0003a330` | `car.gd` `game_frame`, `listener_distance`, `frame_rumble`, `check_start_boost`, `start_boost`, `race.gd` `refresh_staged` | Car update, bump shove, pickup collection, start hold, start boost |
| `FUN_0003ea8c` | `car.gd` `land` | Landing, pattern 4 |
| `FUN_0003fbb8` | `car.gd` `spin_out` | Spin; pattern 8 on car 1's pad |
| `FUN_00043c1c` | `car.gd` `bounce_off_wall`, `wall_rumble` | Wall hit |
| `FUN_00055084` | `items.gd` `spawn_table`, `car.gd` `bump_pass` | Place the pickup, then bump every car pair |
| `FUN_00056348` | `car.gd` `bump_pair` | Car-car bump |
| `FUN_00056cf0` | `items.gd` `run_item` | Fired item, every frame |
| `FUN_00058b38` | `car.gd` `deformed_body` | Rocket body shear |
| `FUN_00058c68` | `car.gd` `deformed_body` | Ring-launcher rear spread |
| `FUN_0005c7ec` | `main_menu.gd` `advance_ribbon` | Menu ribbon hold |
| `FUN_00060068` | `battle.gd` `rank` | Battle track order |
| `FUN_00060684` | `race.gd` `rank_key` | Race places |
| `FUN_00060b48` | `items.gd` `HUD_COLORS` | HUD icon tint |
| `FUN_00060e48` | `items.gd` `reselect` | Next stocked item slot |
| `FUN_00061ab4` | `main_menu.gd` `ribbon_mesh` | Menu ribbon reveal |
| `FUN_0006c6c8` | `battle.gd` `_physics_process` | Two-player battle |
| `FUN_0006d418` | `battle.gd` `update_threshold` | Expert spread and camera |
| `FUN_0006d8b4` | `battle.gd` `restart_active` | Restart cars still in |
| `FUN_0006d9a0` | `battle.gd` `restart_all` | Restart the battle grid |
| `FUN_0006dae4` | `battle.gd` `wide` | Wide node for three cars |
| `FUN_0006de3c` | `battle.gd` `_physics_process` | Three- and four-player battle |
| `FUN_0006f580` | `battle.gd` `measure_spread` | Box around cars still in |
| `FUN_0006f748` | `battle.gd` `measure_spread` | Box around cars still in |
| `FUN_0006f910` | `battle.gd` `eliminate` | Elimination and round winner |
| `FUN_0007080c` | `battle.gd` `past_jump` | Restart past a jump |
| `FUN_00070940` | `sound.gd` `_ready` | Audio init, music ceiling |
| `FUN_00070bcc` | `sound.gd` `effect` | Key a one-shot |
| `FUN_00070ddc` | `sound.gd` `note_pitch` | One-shot note, default `0x40` |
| `FUN_000711c8` | `sound.gd` `apply_music_volume` | Music level to CD volume |
| `FUN_00071248` | `sound.gd` `apply_music_volume` | Music level to CD volume |
| `FUN_000712b8` | `sound.gd` `fade_music` | Music fade out, then advance |
| `FUN_000713dc` | `sound.gd` `note_music_ended` | CD completion callback |
| `FUN_0007144c` | `sound.gd` `begin_music` | `CdlSetmode` 7 and `CdlPlay` |
| `FUN_00071540` | `sound.gd` `note_music_ended` | Detect the end of a track |
| `FUN_000715c0` | `sound.gd` `music_frame` | Start or poll music, fade in |
| `FUN_00071778` | `sound.gd` `fade_music` | Stop the CD and advance |
| `FUN_000717f4` | `sound.gd` `music_frame` | Per-frame audio |
| `FUN_00071104` | `sound.gd` `step_reverb` | Reverb depth up |
| `FUN_00071168` | `sound.gd` `step_reverb` | Reverb depth down |
| `FUN_00071b1c` | `sound.gd` `begin_race` | Key the four drones |
| `FUN_00071cc0` | `sound.gd` `car_loops` | Round-robin loops for one car |
| `FUN_00071d10` | `sound.gd` `music_frame` | Music playlist |
| `FUN_00071ef0` | `car.gd` `wreck`, `begin_splash` | Wreck tone 7, splash tone 10 |
| `FUN_0007202c` | `sound.gd` `spray` | Water spray one-shot |
| `FUN_00072160` | `sound.gd` `appear_tone` | Respawn tone |
| `FUN_0007220c` | `car.gd` `bump_tones` | Car-bump tone |
| `FUN_00072394` | `sound.gd` `puff_tone` | Loose-surface tone off the drift puff |
| `FUN_00072864` | `items.gd` `item_sounds`, `sound.gd` `item_tones` | Item timer, pickup, slowdown, start boost and line tones |
| `FUN_00072e58` | `sound.gd` `scaled` | One-shot volume request |
| `FUN_00072ee0` | `car.gd` `volume_scale`, `engine_scale` | Per-car sound scale |
| `FUN_000731c4` | `sound.gd` `node_loop` | Node flag 1 loop |
| `FUN_0007335c` | `sound.gd` `node_loop` | Node flag `0x40` loop |
| `FUN_000735bc` | `sound.gd` `node_loop` | Node flag 2 loop, cars 0 and 1 |
| `FUN_00073748` | `sound.gd` `node_loop` | Node flag `0x80` loop |
| `FUN_000738c8` | `sound.gd` `node_loop` | Node flag 4 loop |
| `FUN_00073b08` | `sound.gd` `node_loop` | Node loop level |
| `FUN_00073c60` | `sound.gd` `rain_loop` | Rain loop |
| `FUN_00073d58` | `sound.gd` `engine_level` | Gear voice level |
| `FUN_00074028` | `sound.gd` `car_frame` | Engine dispatch |
| `FUN_00074310` | `sound.gd` `engine_gear` | Key the next gear sweep |
| `FUN_0007441c` | `sound.gd` `engine_idle` | Cut the sweep off the throttle |
| `FUN_000744e0` | `sound.gd` `drone_frame` | Drone level and revs |
| `FUN_00074864` | `sound.gd` `engine_pitch` | Gear sweep bend |
| `FUN_000749bc` | `sound.gd` `whine` | Boat whine |
| `FUN_00074d00` | `sound.gd` `sub_engine` | Submarine engine voice |
| `FUN_00075118` | `sound.gd` `countdown_beep` | Countdown beeps |
| `FUN_00075e3c` | not ported | `CdGetToc2`; song 0 is CD track 2 |
| `FUN_00084834` | `sound.gd` `set_level` | SPU voice volume, `volume * 0x81` |
| `FUN_0008525c` | `sound.gd` `note_pitch` | Note to SPU pitch |
| `FUN_000858f4` | `sound.gd` `spu_amplitude` | One-shot SPU level |
| `FUN_00085dd8` | `sound.gd` `bend_scale` | Pitch bend around note 64 |
