# OpenCircuitBreakers

A fan-made port of *Circuit Breakers* (Supersonic Software / Mindscape, PlayStation, 1998), built in Godot.

The port contains none of the original game's data. You need your own copy of the game.

Most of the code was written by AI coding agents.

## Features

- Singleplayer races, time trials, and the World Series against AI drivers
- Local and online multiplayer, including battle mode
- A level editor for custom tracks, with AI support and pickup placement
- Custom tilesets made from OBJ models

## Getting started

1. Download a build from the [releases page](https://github.com/Pigmassacre/opencircuitbreakers/releases).
2. Launch the game. The first time it opens a setup page.
3. Point it at your *Circuit Breakers* disc image (the `.cue` file, so the music can be extracted too). The game extracts the tracks, cars, and audio into a `data` folder next to the executable.

An optional add-on demo disc adds the Castle and Rooftop tracks.

## Custom tilesets

A custom tileset is a folder of OBJ models plus a `tileset.json` that lists them. Drop the folder into `tilesets/` next to the game, and the level editor picks it up the next time it opens.

## Running from source

Download [Godot 4.7.2](https://godotengine.org/download) into the `Godot/` folder, then open `Project/` in the editor. Launching without extracted content opens the setup page, which writes `data/` next to the repo.

To extract headlessly instead:

```
Godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path Project -s res://scripts/export_cli.gd -- "/path/to/Circuit Breakers.cue"
```

`--addon` takes the demo disc, and `--out` writes somewhere other than `data`.

To bake the shipped tilesets in `CustomTilesets/` into the project:

```
Godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path Project -s res://scripts/tileset_bake.gd
```

## Building

`Tools/release.sh` packages Linux and Windows builds into `Builds/`. Pass a tag (`Tools/release.sh v0.1.0`) to publish them as a GitHub release.

## License

The code is MIT licensed, see [LICENSE](LICENSE). The Kenney assets are CC0.

## Credits

- Port by Olof Karlsson
- *Circuit Breakers* by Supersonic Software, published by Mindscape
- City Kit, Racing Kit, and Game Icons by [Kenney](https://kenney.nl) (CC0)
- Built with [Godot Engine](https://godotengine.org) (MIT)
