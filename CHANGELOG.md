# Changelog

## 1.1.1 - 2026-10-11

### Fixed
- Pressing Escape opens the pause menu and leaves it open.
- The loading cover stays closed until the next screen has finished loading.

## 1.1.0 - 2026-10-11

### Added
- Restart in the pause menu during a singleplayer race. It asks before the race starts over.

### Changed
- Cars drive with the original game's physics. Steering will not swing the car into a wall beside it, acceleration and grip follow the slope, and wall bounces, landings, respawns and wrecks match the original.
- This version needs the game data to be exported again. The setup page explains this and asks for your copy of the game.
- Opening the game shows a loading percentage while the menu is prepared, so the first time you open a page it is already ready.

### Fixed
- After crossing the line, your car coasts to a stop. The controls and items no longer respond.
- The finish screen no longer draws a line beside a new best time.

## 1.0.4 - 2026-10-07

### Added
- A Select tool in the level editor. Drag a box to copy the tiles inside it, including pieces on higher layers, then stamp the copy. Q and E rotate it, and the selection shows in solid yellow.
- A loading percentage on the scene wipe while a tileset or track loads.

### Changed
- Track select shows your best time and best finishing place with the same trophy and medal badges as the finish screen.
- Level editor tools use the same icons as the rest of the game.
- The colour band on the singleplayer car select is narrower.

### Fixed
- The place suffix lines up with the number on the track select screen.

## 1.0.3 - 2026-10-06

### Added
- Bumper Cars mode in the main menu, next to Battle and Time Trial, also online. Holding Left and Bumper during a battle countdown also toggles bumper cars, as in the original.
- Controller vibration, with on/off and strength options.
- The start boost from the original game.
- More of the original sounds: the race engine with gear changes, the boat whine, rain, reverb, countdown beeps, respawns, water spray, and item and loose-surface cues. Sounds now fade with distance from the camera.
- The best finishing place on each singleplayer track is remembered.
- 16:10 and 4K resolutions, and the resolution list shows each entry's aspect ratio.

### Changed
- This version needs the game data to be exported again. The setup page explains this and asks for your copy of the game.
- The track finish screen is now animated and shows your place and time as badges.
- Cars bump into each other using the original game's collision test.
- Confirmation dialogs keep focus and start with focus on the Cancel button.

### Fixed
- Submarine flaps no longer turn against the steering, and propellers spin on the right axis.
- The game no longer hitches when loading custom tracks that use big tilesets.
