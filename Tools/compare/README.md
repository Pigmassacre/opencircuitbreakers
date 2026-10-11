# Comparing the car physics with the original

These scripts drive the original game in DuckStation, save what its car does every game frame, and check the port against it. They need Linux, Python 3, `wmctrl`, `xwd` and `ffmpeg` (the last three only for screenshots), DuckStation, and your own copy of Circuit Breakers (USA).

## DuckStation

In DuckStation's `settings.ini`, set `EnableGDBServer = true` under `[Debug]`, `Type = DigitalController` under `[Pad1]` with no bindings, and `SaveStateOnExit = false` under `[Main]`. Start the game:

```
DuckStation-x64.AppImage -batch -fastboot -- "Circuit Breakers (USA).cue"
```

DuckStation may update itself when it starts, and it keeps its settings under `~/.local/share/duckstation`. To leave your own setup alone, copy that folder to `somewhere/.local/share/duckstation`, edit the copy, and start DuckStation with `HOME=somewhere`.

## Getting into a race

`menu.py` presses buttons. From a fresh start this reaches a time trial on Jungle 1:

```
python3 menu.py run:14 start:3 run:20 --shot /tmp/now.png
python3 menu.py cross:45 run:1 cross:8 run:3 select:3 run:4 cross:40 run:2
python3 menu.py select:3 run:6 right:28 run:2 select:3 run:8
```

Look at the screenshot between steps; the waits depend on the machine. A time trial has no other cars, so a run repeats exactly.

## Recording and checking

```
python3 record.py lap.json 1500 ../../data/tracks/jungle4/track.json
python3 record.py mix.json 1200 ../../data/tracks/jungle4/track.json mix
```

The menu's Jungle 1 is the folder `jungle4`; `data/tracks/names.json` has the others. Then, from the repository root:

```
Godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path Project -s ../Tools/compare/simtest.gd -- $PWD/data/tracks/jungle4/blocks.bin $PWD/Tools/compare/lap.json
```

runs the port's car update one frame from every recorded state and compares it with the next. Every field should match on every frame.

```
Godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 30 --path Project -s ../Tools/compare/replay.gd -- jungle4 $PWD/Tools/compare/lap.json /tmp/replay.json
python3 Tools/compare/compare.py Tools/compare/lap.json /tmp/replay.json
```

plays the same buttons through a time trial of the whole port and sets the two drives side by side.
