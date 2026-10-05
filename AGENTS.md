There is a local copy of Godot located inside this repo: in the Godot/ folder.

The player is expected to provide their own copy of Circuit Breakers. Tracks, cars, audio, and editor tilesets are extracted by `Project/scripts/content_export.gd`. That is the only setup flow. Do not add a parallel Python setup or export path.

Launching the game without that content opens the in-game setup page, which writes a `data` folder next to the executable (next to the repo when running in the editor). Music is written as WAV. An optional add-on disc supplies Castle and Rooftop.

Development uses the same exporter, headless. The default output folder is `data` next to the repo, outside the Godot project, so a packaged build cannot include it:

```
Godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path Project -s res://scripts/export_cli.gd -- "/path/to/Circuit Breakers.cue"
```

`--addon` takes the demo disc. `--out` writes somewhere other than `data`.

Custom tilesets are a folder of OBJ models plus a `tileset.json` that lists those models. Shipped sources live in `CustomTilesets/<id>/`. Bake them into the project with:

```
Godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path Project -s res://scripts/tileset_bake.gd
```

A folder of the same shape placed in `tilesets/` next to the game (next to the repo when running in the editor) is baked when the editor opens and appears with the custom tilesets.
