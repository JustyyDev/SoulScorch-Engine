# Example Mod

A minimal reference mod showing the main things SoulScorch Engine mods can do.

## What this demonstrates

- **`soulmod.json`** - the metadata file every mod needs (`name`, `version`,
  `api_version`, `description`, `color`, `global_scripts`, `flags`,
  `load_priority`). Read by `SoulModParser` and listed in the Mod Switch Menu
  (press **Tab** in-game).
- **Asset overrides** - `assets/data/config/introText.txt` overrides the
  base game's title-screen wacky text. `ModManager.getPath()` checks the
  currently selected mod's `assets/` folder before falling back to the base
  `assets/preload/` folder, so any file placed here with the same relative
  path replaces the original.
- **Global scripts** - `mods/global_scripts/example_features.hx` is an
  HScript file auto-loaded by `GlobalScriptManager` on boot. It implements
  the `onGlobalInit`, `onGlobalUpdate(elapsed)` and `onStateSwitch` hooks.

## Trying it out

1. Launch the game and press **Tab** to open the Mod Switch Menu.
2. Select "Example Mod" and press **Enter** to make it the active mod
   (selection is saved and persists between sessions; pick "Mods Disabled"
   to go back to the base game).
3. Start a new run of the title screen intro to see the overridden wacky text.
4. Check the dev console (`~` or **F2**) for the `[Example Mod]` trace lines
   logged by the global script.

## Notes

- Only one mod can be active at a time (folder selected via the Mod Switch
  Menu); `global_scripts/` files always run regardless of the active mod
  selection since they're loaded once at boot.
- Press **7** in-game to open the Editor Picker (debug menu) for the
  Character Editor / Charting Editor.
