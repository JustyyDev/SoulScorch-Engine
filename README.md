SoulScorch Engine is a high-performance and modular game engine designed specifically for Friday Night Funkin and rhythm game development. It serves as a comprehensive ecosystem that replaces traditional modding limitations with built-in development suites and advanced rhythm mechanics.

### Core Architectural Features

* **Mania Chart Studio:** A high-precision mapping environment providing multi-division beat quantization ranging from 1/4 down to 1/64 beats, real-time audio hitsound feedback during scrubbing, continuous multi-section viewports, and integrated event automation for triggers and script events.
* **Modchart Matrix Studio:** A visual workspace designed for configuring receptor transformation math. It allows creators to preview and manipulate modifiers like Drunk, Tipsy, Beat Pulse, Confusion, Reverse, Cross, Invert, Bumpy, and Stealth in real time, with instant SoulScript event generation.
* **Actor Studio and Stage Architect:** Complete in-engine visual editors that eliminate the need for external tools. Actor Studio handles Sparrow XML animation injection, frame-by-frame scrubbing, and camera focus anchoring, while Stage Architect enables drag-and-drop prop placement, multi-layer parallax scrolling configuration, and JSON stage serialization.
* **HomeSoulDB Workshop Ecosystem:** A native package manager and community repository built directly into the engine, allowing users to browse, bump, download, and install community packages, custom weeks, and shaders without manual file management.
* **Advanced Performance Optimizer:** A background memory management subsystem that monitors frame rates, purges unused VRAM graphic assets, performs generational garbage collection sweeps, and clamps delta time to prevent stutter spikes during heavy modchart execution.

### What Makes It Different From Other FNF Modding Engines

* **Unified Creative Suite:** Traditional engines require external applications or basic debug menus for charting and staging. SoulScorch embeds an entire developer studio directly into the game binaries, allowing creators to map, script, animate, and build stages within a single environment.
* **Etterna-Grade Precision:** Borrowing performance and customization standards from rhythm games like Etterna and Osu, the engine offers robust playback rate scaling from 0.25x to 2.0x, strict quantization color coding, multi-key mapping slots, and millisecond-accurate input calibration.
* **Smart Garbage Collection and Memory Management:** Standard modding engines frequently suffer from memory leaks and stutter spikes due to unmanaged asset accumulation. SoulScorch utilizes targeted VRAM asset caching and focus-lost throttling profiles to maintain stable frame rates over extended play sessions.

# SoulScorch Engine: Comprehensive Modding & Architecture Guide

This guide details how every subsystem, directory structure, and modding pipeline operates within **SoulScorch Engine**.

---

## 1. Directory Structure

SoulScorch Engine organizes assets, source code, and user modifications into a strict directory tree. Understanding this structure is essential for building custom content and packages.

```text
SoulScorch-Engine/
├── assets/
│   ├── data/                 # Global song charts, weeks, scripts, and configs
│   │   ├── characters/       # Character offset and property JSONs
│   │   ├── stages/           # Stage architectural layout JSONs
│   │   ├── weeks/            # Campaign week structure JSONs
│   │   └── config/           # Engine configuration and menu item lists
│   ├── images/               # Global textures, UI atlases, and graphic assets
│   │   ├── ui/               # Main menus, title screens, HUDs, and alphabet sprites
│   │   └── characters/       # Global character sprite sheets and Sparrow XMLs
│   ├── music/                # Instrumental files, menu loops, and jingles
│   ├── sounds/               # Sound effects (hitsounds, menu clicks, UI clicks)
│   └── songs/                # Individual song folders (Inst.ogg, Voices.ogg, charts)
├── mods/                     # User modification packages (Hot-swappable)
│   └── [ModFolderName]/
│       ├── data/             # Mod-specific charts, stages, and characters
│       ├── images/           # Custom textures overriding base assets
│       ├── scripts/          # Global HScript/Lua mod scripts and custom states
│       └── mod.json          # Mod metadata descriptor (Name, author, version)
└── source/                   # Core Haxe engine source files
    ├── soulscorch/
    │   ├── backend/          # Audio, asset loaders, saving, input, and memory
    │   ├── gameplay/         # Notes, strumlines, scoring, and play state logic
    │   ├── scripting/        # HScript and mod execution managers
    │   └── ui/               # Menus, HUDs, substates, and in-engine editors
    └── Main.hx               # Engine entry point and optimization pipeline

```

---

## 2. How Mods Work & Mod Structure (`mods/`)

SoulScorch features a dynamic mod loader managed by `ModManager.hx` and `ModRegistry.hx`. Every folder placed inside the `mods/` directory is treated as an independent modification package.

### The `mod.json` Metadata File

Every mod should include a `mod.json` descriptor in its root directory to define its identity and metadata:

```json
{
    "name": "My Custom Mod",
    "description": "An incredible total-conversion mod featuring custom songs and stages.",
    "author": "YourName",
    "version": "1.0.0",
    "api_version": "1.0"
}

```

### Asset Overriding Hierarchy

When the engine loads assets via `Paths.hx` or `AssetResolver.hx`, it checks directories in the following priority order:

1. **Active Mods (`mods/[ActiveMod]/`)**: If a file exists here, it overrides all base assets.
2. **Preload Assets (`assets/preload/`)**: Core game files.
3. **Core Library Assets (`assets/`)**: Fallback assets.

---

## 3. Modding Examples & Subsystem Breakdown

### A. Custom Characters (`assets/data/characters/` or `mods/[Mod]/data/characters/`)

Characters define animations, offsets, health bar colors, and camera focus points.

**Example Character JSON (`dad.json`):**

```json
{
    "image": "characters/DAD_assets",
    "scale": 1.0,
    "sing_duration": 4.0,
    "healthicon": "dad",
    "position": [0, 0],
    "camera_position": [150, -100],
    "flip_x": false,
    "no_antialiasing": false,
    "healthbar_colors": [175, 102, 206],
    "animations": [
        {
            "anim": "idle",
            "name": "Dad idle dance",
            "fps": 24,
            "loop": true,
            "offsets": [0, 0]
        },
        {
            "anim": "singUP",
            "name": "Dad Sing Note UP",
            "fps": 24,
            "loop": false,
            "offsets": [-6, 50]
        }
    ]
}

```

### B. Custom Stages (`assets/data/stages/` or `mods/[Mod]/data/stages/`)

Stages define camera zoom levels, character spawn coordinates, and multi-layer background art pieces.

**Example Stage JSON (`stage.json`):**

```json
{
    "name": "stage",
    "defaultZoom": 0.9,
    "cameraSpeed": 1.0,
    "hideGirlfriend": false,
    "boyfriend": [770, 450],
    "dad": [100, 100],
    "girlfriend": [400, 130],
    "pieces": [
        {
            "name": "stageback",
            "image": "stages/default/stageback",
            "position": [-600, -200],
            "scroll": [0.9, 0.9],
            "scale": [1.0, 1.0],
            "layer": "background"
        },
        {
            "name": "stagefront",
            "image": "stages/default/stagefront",
            "position": [-650, 600],
            "scroll": [1.0, 1.0],
            "scale": [1.1, 1.1],
            "layer": "behindDad"
        }
    ]
}

```

### C. Campaign Weeks (`assets/data/weeks/` or `mods/[Mod]/data/weeks/`)

Weeks group songs together for Story Mode campaigns.

**Example Week JSON (`week1.json`):**

```json
{
    "id": "week1",
    "name": "SCORCHED CAMPAIGN",
    "songs": ["Bopeebo", "Fresh", "Dad Battle"],
    "characters": ["dad", "bf", "gf"],
    "color": "#F9CF51",
    "difficulties": ["easy", "normal", "hard"]
}

```

### D. HScript Mod Scripting (`mods/[Mod]/scripts/`)

Global scripts or song-specific scripts run via HScript-Iris, letting you manipulate gameplay events, camera movement, and note behavior dynamically.

**Example Mod Script (`my_script.hx`):**

```haxe
function onCreate() {
    trace("Custom script loaded successfully!");
}

function onUpdate(elapsed:Float) {
    // Custom logic executed every frame
}

function onBeatHit(beat:Int) {
    if (beat % 4 == 0) {
        // Triggered every 4th beat
    }
}

```

---

## 4. Engine Architecture & Core Subsystems

* **`Main.hx` & `EngineOptimizer.hx**`: Bootstraps the engine, configures high-performance Flixel timing (`FlxG.fixedTimestep = false`), manages VRAM asset purging every 15 seconds, and executes emergency garbage collection sweeps when frame rates dip below 50 FPS.
* **`ChartingState.hx`**: An Etterna-grade chart editor featuring multi-division quantization snaps (`1/4` to `1/64`), real-time hitsound audio feedback, section lane inversion, and event automator integration.
* **`ModchartWorkspaceState.hx`**: A visual modchart matrix suite that calculates receptor transformations (`Drunk`, `Tipsy`, `Beat Pulse`, `Confusion`, `Reverse`, `Cross`, `Invert`, `Bumpy`, `Stealth`) in real time and exports clean **SoulScript** event triggers.
* **`CharacterEditorState.hx` & `StageEditorState.hx**`: In-engine visual IDE studios allowing creators to live-inject XML animations, calibrate offsets, test character trajectories, and drag-and-drop stage props without touching external code editors.
* **`HomeSoulDBModule.hx`**: A native package manager connecting directly to online community repositories, allowing users to browse, bump, download, and install community mods securely inside the game.