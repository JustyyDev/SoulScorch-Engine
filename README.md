# SoulScorch Engine

SoulScorch Engine is a free and open rhythm game engine built with Haxe, HaxeFlixel, OpenFL, and Lime.

It gives creators a place to build songs, characters, stages, menus, events, shaders, and full game mods. You can start with a small asset mod, then learn scripting when you want deeper control.

## Main features

- Custom songs, charts, difficulties, and weeks
- Custom characters, health icons, stages, notes, and splashes
- SoulScript, HScript, Iris, Lua, Python, and JavaScript support
- XMSoul data files for readable engine and mod configuration
- Mod loading, validation, priorities, dependencies, and global scripts
- Freeplay shuffle, song previews, and custom metadata
- Editors for charts, characters, stages, and modcharts
- Shader, camera, event, dialogue, cutscene, replay, and video systems
- Desktop, Android, and iOS build targets
- HomeSoulDB support for finding and installing mods

## Start here

Choose the guide that matches what you want to do.

| Guide | What it teaches |
| --- | --- |
| [Beginner Modding Guide](docs/BEGINNER_MODDING.md) | Make your first mod from an empty folder |
| [Advanced Modding Guide](docs/ADVANCED_MODDING.md) | Dependencies, priorities, global scripts, events, shaders, and custom states |
| [Desktop Guide](docs/DESKTOP_GUIDE.md) | Install, test, build, and package mods on Windows, Linux, and macOS |
| [Mobile Guide](docs/MOBILE_GUIDE.md) | Android and iOS support, limits, assets, and testing |
| [Scripting Guide](docs/SCRIPTING_GUIDE.md) | SoulScript, HScript, Iris, Lua, Python, and JavaScript |
| [Assets and Data Guide](docs/ASSETS_AND_DATA.md) | Songs, characters, stages, icons, noteskins, dialogue, and XMSoul |
| [Troubleshooting Guide](docs/TROUBLESHOOTING.md) | Fix common mod, script, asset, and build problems |

## Quick first mod

Create this folder:

```text
mods/my-first-mod/
```

Add `mods/my-first-mod/soulmod.xmsoul`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<mod name="My First Mod" version="1.0.0" author="Your Name" apiVersion="1.0.0" description="My first SoulScorch mod" color="#5BA2FF" icon="icon.png">
    <scripts>
        <script path="scripts/global.soul" global="true" />
    </scripts>
</mod>
```

Add `mods/my-first-mod/scripts/global.soul`:

```text
on create:
    play sound "confirmMenu" at 0.7

every 4 beats:
    camera bump(0.02)
```

Start SoulScorch, open the mod menu, enable the mod, and test it.

Read the [Beginner Modding Guide](docs/BEGINNER_MODDING.md) for the full walkthrough.

## Supported scripting

| Language | Extension | Best use |
| --- | --- | --- |
| SoulScript | `.soul` | Simple readable gameplay and menu scripts |
| HScript | `.hx`, `.hscript` | Deep live engine control |
| Iris | `.iris` | HScript-style mod scripting |
| LuaJIT | `.lua` | Familiar Friday Night Funkin mod scripts on C++ targets |
| Python | `.py` | Infrequent external tools and callbacks on desktop |
| JavaScript | `.js` | Infrequent Node.js callbacks on desktop |

SoulScript, HScript, Iris, and Lua can work with live engine objects. Python and JavaScript run as separate processes, so they are better for tools and occasional callbacks.

## Project folders

```text
SoulScorch-Engine/
|- assets/preload/       Built-in assets and data
|- assets/shared/        Shared engine assets
|- mods/                 Installed and local mods
|- source/               Engine source code
|- commandline/          Command-line tools
|- tools/                Conversion and build helpers
|- docs/                 Modding documentation
|- project.xml           Lime project configuration
|- build.bat             Windows build menu
|- mod-packager.bat      Standalone mod packager
```

## Build targets

- Windows C++ with MSVC or MinGW
- Linux C++
- macOS C++
- Android APK
- iOS Xcode project
- HTML5
- HashLink
- CPPIA test host

See the [Desktop Guide](docs/DESKTOP_GUIDE.md) and [Mobile Guide](docs/MOBILE_GUIDE.md) before building.

## Mod safety and compatibility

- Keep mod files inside your own mod folder.
- Use lowercase IDs for songs, characters, stages, and difficulties.
- List required mods as dependencies.
- Test with only your mod enabled before sharing it.
- Do not include private keys, passwords, paid SDK files, or files you cannot redistribute.
- Use the mod validator before packaging a release.

## Useful tools

- `build.bat` opens the Windows build menu.
- `mod-packager.bat` builds a standalone package for one mod.
- The command-line project includes mod validation commands.

## Project links

- SoulScorch Engine: https://github.com/JustyyDev/SoulScorch-Engine
- linc_luajit: https://github.com/JustyyDev/linc_luajit
- HomeSoulDB: https://github.com/JustyyDev/HomeSoulDB

## License

Read [LICENSE](LICENSE) before redistributing the engine or engine source.

Mods can have their own license, but they must still follow the licenses of any libraries and assets they include.

## Credits

SoulScorch Engine is made by the SoulScorch Team and community contributors.

Thank you to everyone who creates mods, tests builds, reports bugs, writes ideas, and helps other creators.
