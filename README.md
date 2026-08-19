# SoulScorch Engine: Comprehensive Architecture & Modding Guide

This guide details how every subsystem, directory structure, modding pipeline, and custom scripting language operates within **SoulScorch Engine**.

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

## 2. SoulScript Specification & Syntax

**SoulScript** is SoulScorch Engine's custom, human-readable domain-specific scripting language (DSL) designed specifically for declarative modcharts, receptor transformation timelines, and event automation. Instead of writing complex raw HScript or Lua boilerplate for basic wave movements, creators use SoulScript to define smooth property transitions, easing curves, and timed event triggers.

### Structure and Syntax Rules

* **Comments:** Lines starting with `#` or `//` are treated as comments.
* **Event Blocks:** Modchart triggers are wrapped inside `on event("Name")` and `end` blocks.
* **Property Interpolation:** Modifiers are modified using the arrow operator (`->`), targeting properties, specifying target intensities, durations, and easing curves.

### Supported Properties and Modifiers

* `drunk`: Horizontal sine wave oscillation across receptor lanes.
* `tipsy`: Vertical wave motion.
* `beat`: Quarter-note snappy scaling and position pulse.
* `confusion`: Receptor rotation angle in degrees.
* `stealth`: Receptor transparency and opacity control.
* `reverse`: Flips receptor layout to downscroll positioning.
* `cross`: Swaps inner lane positioning.
* `bumpy`: Simulates 3D perspective distortion.
* `invert`: Mirrors strumline layouts.

### Example SoulScript File (`wave_event.soul`)

```soul
# SoulScript Modchart Event Trigger Script
on event("Modchart Wave Matrix"):
    modchart.drunk -> 1.5 in 0.5s (cubeOut)
    modchart.tipsy -> 0.8 in 0.5s (cubeOut)
    modchart.confusion -> 180.0 in 0.8s (elasticOut)
    modchart.bumpy -> 1.2 in 0.4s (bounceOut)
end

on event("Stealth Fade"):
    modchart.stealth -> 1.0 in 0.3s (quadOut)
end

```

---

## 3. How Mods Work & Mod Structure (`mods/`)

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

## 4. Modding Examples & Subsystem Breakdown

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

## 5. Engine Architecture & Core Subsystems

* **`Main.hx` & `EngineOptimizer.hx`**: Bootstraps the engine, configures high-performance Flixel timing (`FlxG.fixedTimestep = false`), manages VRAM asset purging **every 15 seconds**, and executes emergency garbage collection sweeps *when frame rates dip below 50 FPS*.
* **`ChartingState.hx`**: An Etterna-grade chart editor featuring multi-division quantization snaps (`1/4` to `1/64`), real-time hitsound audio feedback, section lane inversion, and event automator integration.
* **`ModchartWorkspaceState.hx`**: A visual modchart matrix suite that calculates receptor transformations (`Drunk`, `Tipsy`, `Beat Pulse`, `Confusion`, `Reverse`, `Cross`, `Invert`, `Bumpy`, `Stealth`) in real time and exports clean **SoulScript** event triggers.
* **`CharacterEditorState.hx` & `StageEditorState.hx`**: In-engine visual IDE studios allowing creators to live-inject XML animations, calibrate offsets, test character trajectories, and drag-and-drop stage props without touching external code editors.
* **`HomeSoulDBModule.hx`**: A native package manager connecting directly to **online community repositories**, allowing users to **browse, bump, download,** and **install community mods** securely inside the game.