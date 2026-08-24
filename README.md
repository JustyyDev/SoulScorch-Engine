# SoulScorch Engine

SoulScorch Engine is a free rhythm game engine.

Think of it like a giant game toolbox.
You can add songs, characters, stages, and scripts.
You can also change menus, effects, and gameplay rules.

This guide is written to be easy for beginners around age 10 or 11 for example, EVEN KIDS CAN UNDERSTAND THIS OKAY??

## What is a game engine?

A game engine is the base that helps games work.
It handles:
- Graphics
- Audio
- Input
- Saving data
- Loading files

SoulScorch gives you that base so you can focus on making cool content.

## What you can do in SoulScorch

- Play rhythm game charts
- Add custom songs and difficulties
- Make mods with your own assets
- Write scripts to change game behavior
- Build the game for desktop and more targets

## The 4 script friends

SoulScorch supports 4 script types:

1. SoulScript and Haxe (`.soul`, `.hx`)
2. HScript and Iris (`.hscript`, `.iris`)
3. Lua (`.lua`)
4. Python (`.py`)

You can use one type, or mix them.

## Script lifecycle in simple words

When the engine loads a script, it calls functions in this order:

- `create`: set up data
- `onCreate`: create objects
- `update(elapsed)`: runs every frame
- `onBeatHit(beat)`: runs on music beats

You only need to write the functions you want.

## Global scripts

Global scripts are scripts that run across many states.
They are useful for things like:
- Global hotkeys
- Custom overlays
- Shared helpers

SoulScorch can auto-find global scripts in mod folders and base folders.

## Folder map

```text
SoulScorch-Engine/
|- assets/         # Game assets (images, sounds, data)
|- mods/           # Your mods go here
|- source/         # Engine source code
|- tools/          # Build and helper scripts
|- build.bat       # Build menu for Windows
```

## Super quick mod tutorial

### 1) Make your mod folder

Inside `mods`, create:

```text
mods/myfirstmod/
```

### 2) Add mod info file

Create `mods/myfirstmod/soulmod.json`:

```json
{
  "name": "myfirstmod",
  "title": "My First Mod",
  "version": "1.0.0",
  "api_version": "1.0.0",
  "author": "Your Name",
  "description": "A fun little mod",
  "color": "#5BA2FF",
  "icon": "windowicon.png",
  "global_scripts": [],
  "dependencies": [],
  "load_priority": 0
}
```

### 3) Add a script

Create `mods/myfirstmod/scripts/hello.soul`:

```text
on create:
    print("Hello from my mod")

on update(elapsed):
    if FlxG.keys.justPressed.SPACE:
        print("You pressed SPACE")
```

Lua example:

```lua
function create()
    print("Hello from Lua")
end

function update(elapsed)
    -- frame update
end
```

Python example:

```python
def create():
    print("Hello from Python")

def update(elapsed):
    pass
```

HScript example:

```haxe
function create() {
    trace("Hello from HScript");
}

function update(elapsed) {
}
```

### 4) Run the game

- Start the engine
- Open the mod menu
- Enable your mod
- Play

Done. You made a mod.

## Lua helper library

SoulScorch uses `linc_luajit` for Lua support.

Project link:
- https://github.com/JustyyDev/linc_luajit

This helps Lua scripts talk to engine functions.

## Build the game on Windows

Run:

```cmd
build.bat
```

Then choose a menu option.

Common picks:
- `1` MinGW Windows build
- `2` MSVC Windows release build
- `3` MSVC Windows debug build

## Troubleshooting

### Build fails with missing libraries

Use option `S` in `build.bat` to install libraries.

### Build is slow

- Keep your haxelib cache
- Avoid deep clean unless needed
- Use release builds only when ready

### Mod does not show up

Check:
- Folder is inside `mods/`
- `soulmod.json` is valid JSON
- Mod name and files are not empty

### Script does not run

Check:
- File extension is supported
- Function names are correct (`create`, `update`, etc.)
- Script path is in the correct mod folder

## Roadmap idea: Soul3D helper lib

We plan to make an easier 3D helper library called `soul3d`.

Goal:
- Easy model spawn
- Easy camera setup
- Easy light presets
- Easy 3D animation helpers

Planned first version:
- `Soul3D.spawnModel(path, x, y, z)`
- `Soul3D.makeOrbitCamera(radius)`
- `Soul3D.setSunLight(color, intensity)`

This is planned work and can be built step by step.

## Project links

- SoulScorch Engine: https://github.com/JustyyDev/SoulScorch-Engine
- linc_luajit: https://github.com/JustyyDev/linc_luajit
- HomeSoulDB: https://github.com/JustyyDev/HomeSoulDB

## Credits

SoulScorch Engine is made by the SoulScorch Team and community modders.
Thanks to everyone who tests, reports bugs, and makes mods.
