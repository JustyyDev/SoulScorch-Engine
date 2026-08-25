# Beginner Modding Guide

[Documentation home](../README.md) | [Advanced guide](ADVANCED_MODDING.md) | [Troubleshooting](TROUBLESHOOTING.md)

This guide walks through a complete first mod. You do not need to edit engine source code.

## What you need

- A copy of SoulScorch Engine
- A text editor such as Visual Studio Code
- An image editor for PNG files
- An audio editor for OGG files
- A folder name with simple lowercase letters and hyphens

## Make the mod folder

Create this structure:

```text
mods/my-first-mod/
|- soulmod.xmsoul
|- icon.png
|- scripts/
|  |- global.soul
|- songs/
|- data/
|- images/
|- sounds/
```

Only add folders you need. Empty folders are optional.

## Add the mod information

Create `soulmod.xmsoul`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<mod name="My First Mod" version="1.0.0" author="Your Name" apiVersion="1.0.0" description="A small practice mod" color="#5BA2FF" icon="icon.png">
    <scripts>
        <script path="scripts/global.soul" global="true" />
    </scripts>
</mod>
```

The important fields are:

- `name`: the title shown in the mod menu
- `version`: your release number
- `author`: the creator name
- `description`: a short explanation
- `color`: a menu color in hex format
- `icon`: a PNG inside the mod folder

## Add a simple SoulScript

Create `scripts/global.soul`:

```text
on create:
    play sound "confirmMenu" at 0.6

on beat 8:
    camera flash CYAN for 0.2s

every 4 beats:
    camera shake 0.005 for 0.1s
```

Save the file, start the engine, and enable the mod from the mod menu.

## Add a song

Use a lowercase song ID such as `my-song`.

```text
mods/my-first-mod/songs/my-song/
|- song/
|  |- Inst.ogg
|  |- Voices.ogg
|- charts/
|  |- normal.json
|- meta.xmsoul
```

Example `meta.xmsoul`:

```xml
<song name="My Song" bpm="120" player1="bf" player2="dad" gfVersion="gf" stage="default" difficulties="normal" />
```

The chart must use the same song ID and difficulty name. You can use the chart editor to create or change it.

## Add a character

A basic character needs an image atlas and a data file:

```text
mods/my-first-mod/images/characters/my-character.png
mods/my-first-mod/images/characters/my-character.xml
mods/my-first-mod/data/characters/my-character.xmsoul
```

Start by copying a built-in character data file into your mod, rename it, then change the image, animation prefixes, offsets, icon, and health color.

## Add a health icon

Use either:

```text
images/ui/game/icons/icon-my-character.png
```

or:

```text
images/ui/game/icons/my-character/icon.png
```

A two-frame icon uses normal frame `0` and losing frame `1`. A three-frame icon uses normal frame `0`, losing frame `1`, and winning frame `2`.

## Add a stage

Create:

```text
data/stages/my-stage/stage.xmsoul
images/stages/my-stage/background.png
```

A stage file controls images, positions, scroll factors, camera zoom, and character positions. Start with a copy of the built-in default stage and replace one part at a time.

## Test your mod

1. Enable only your mod.
2. Open Freeplay and find the song.
3. Test each difficulty.
4. Check character animations and icons.
5. Pause and restart the song.
6. Return to menus and watch for missing assets.
7. Read the console or log when something does not load.

## Share your mod

Use `mod-packager.bat` on Windows or zip only your mod folder. A player should be able to place the folder inside `mods/`, enable it, and play.

Before sharing, remove temporary files, editor backups, private notes, and files you do not have permission to redistribute.
