# SoulScorch Engine: Comprehensive Architecture & Modding Guide



SoulScorch Engine is a high-performance, modular rhythm game framework designed for deep XML layout customization, dynamic multi-language scripting, 3D hardware-accelerated rendering, and total-conversion modding.

---

## 1. Directory Structure

Assets, core engine systems, and user modifications follow a strict resolution hierarchy:

```text
SoulScorch-Engine/
├── assets/
│   ├── preload/
│   │   ├── data/
│   │   │   ├── characters/       # Character offset & properties (.json / .xmsoul)
│   │   │   ├── stages/           # Multi-layered stage architecture definitions
│   │   │   ├── noteskins/        # Lane receptor & tap note XML specifications
│   │   │   └── config/           # Engine UI, judgments, credits & window settings
│   │   ├── images/               # Textures, sprite atlases, and UI elements
│   │   ├── music/                # Menu music, instrumental stems, and loops
│   │   ├── sounds/               # Sound effects and feedback audio
│   │   └── songs/                # Base song charts and audio tracks
├── mods/                         # Dynamic modification packages (Hot-swappable)
│   └── [ModFolderName]/
│       ├── data/                 # Mod-specific charts, stages, and characters
│       ├── images/               # Custom UI atlases and sprites overriding base assets
│       ├── scripts/              # Mod-scoped SoulScript (.soul), HScript (.hx), and Lua (.lua)
│       └── soulmod.json          # Mod descriptor (or soulmod.xmsoul / mod.json)
├── source/                       # Core Haxe engine source files
│   ├── Main.hx                   # Engine bootstrap, high-performance timing & garbage sweep
│   └── soulscorch/
│       ├── backend/              # Audio Conductor, XMSoul parser, AssetResolver, and RPC
│       ├── gameplay/             # PlayState, note systems, receptors, and stage engines
│       ├── graphics/             # 3D Away3D manager and custom GPU shader pipelines
│       ├── scripting/            # SoulScript transpiler, HScript runtime, and ModManager
│       └── ui/                   # Menus, HUD elements, and in-engine visual editors
└── build.bat                     # Multi-target compilation suite (MSVC, MinGW, HL, CPPIA)

```

---

## 2. SoulScript & Scripting Specification

SoulScorch features **SoulScript**, a transpiled domain-specific language (DSL) combining concise timeline headers and animation tweens with standard HScript execution.

### Core Syntax & Shorthand Features

* **Event Headers:** Clean lifecycle blocks translated directly into functions:
* `on create:` $\rightarrow$ `function create() {`

* `on update(elapsed):` $\rightarrow$ `function update(elapsed) {`

* `on beatHit(curBeat):` $\rightarrow$ `function onBeatHit(curBeat) {`

* `on preStateSwitch:` $\rightarrow$ `function preStateSwitch() {`

* `on postStateSwitch:` $\rightarrow$ `function postStateSwitch() {`

* `at beat <N>:` $\rightarrow$ `if (curBeat == <N>) {`

* `every <N> beats:` $\rightarrow$ `if (curBeat % <N> == 0) {`



* **Property & Tween Shorthand:** `target.property -> value in duration(ease)` converts automatically into Flixel tweens.


* **Strumline & 3D Tweens:** `strumline.player[0].x -> 412 in 0.5s (cubeOut)` and `model.position -> [0, 5, 10] in 1.2s (quartOut)`.



### Available Injections in Script Runtime

Every script (`.soul` or `.hx`) automatically receives global bindings:

* **Flixel Core:** `FlxG`, `FlxSprite`, `FlxCamera`, `FlxText`, `FlxMath`, `FlxTween`, `FlxEase`, `FlxTimer`, `FlxColor`.


* **Engine Internals:** `Runtime`, `Conductor`, `Paths`, `EventBus`, `Logger`, `ModLoader`, `DiscordRPC`, `ScriptManager`, `ScriptedState`, `ScriptedSubState`.


* **Active State Access:** `game` and `state` pointing directly to `FlxG.state`.



---

## 3. Mod Configuration & Metadata

Mods are loaded dynamically from the `mods/` directory. Every mod package declares metadata using `soulmod.json` or `soulmod.xmsoul`:

```json
{
  "name": "examplemod",
  "title": "example mod",
  "version": "1.0.0",
  "api_version": "1.0.0",
  "author": "SoulScorch Team",
  "description": "hi",
  "color": "#9d5ebd",
  "icon": "windowicon.png",
  "global_scripts": [
    "scripts/global.soul"
  ],
  "dependencies": [],
  "load_priority": 0
}

```

### Global Script Redirection (`global.soul` / `global.hx`)

Global scripts run across state switches to hook into transitions, hot-reloading, or state overrides:

```haxe
function preStateSwitch() {
    // Intercept default menus and redirect to scripted mod states
    if (Type.getClassName(Type.getClass(FlxG.game._requestedState)).indexOf("TitleState") != -1) {
        FlxG.game._requestedState = new ScriptedState("TitleState");
    }
}

function postStateSwitch() {
    lime.app.Application.current.window.title = "SoulScorch // Active Mod";
}

function update(elapsed) {
    if (FlxG.keys.justPressed.F5) {
        ScriptManager.instance.updateHotReload();
    }
}

```

---

## 4. XMSoul XML Specification

SoulScorch uses XML-driven architecture (`XMSoul`) for engine settings, layouts, and noteskins.

### Noteskin XML (`assets/preload/data/noteskins/notes/default.xmsoul`)

```xml
<?xml version="1.0" encoding="utf-8"?>
<noteskin name="Default" sprite="ui/game/notes/NOTE_assets" scale="0.7" antialiasing="true">
    <receptors>
        <strum lane="0" static="arrowLEFT" pressed="left press" confirm="left confirm" />
        <strum lane="1" static="arrowDOWN" pressed="down press" confirm="down confirm" />
        <strum lane="2" static="arrowUP" pressed="up press" confirm="up confirm" />
        <strum lane="3" static="arrowRIGHT" pressed="right press" confirm="right confirm" />
    </receptors>
    <tapNotes>
        <note lane="0" anim="purple" />
        <note lane="1" anim="blue" />
        <note lane="2" anim="green" />
        <note lane="3" anim="red" />
    </tapNotes>
    <sustains alpha="0.6" width="50">
        <hold lane="0" body="purple hold piece" end="pruple end hold" />
        <hold lane="1" body="blue hold piece" end="blue hold end" />
        <hold lane="2" body="green hold piece" end="green hold end" />
        <hold lane="3" body="red hold piece" end="red hold end" />
    </sustains>
</noteskin>

```

### Engine Configuration (`assets/preload/data/config/window.xmsoul`)

```xml
<?xml version="1.0" encoding="utf-8"?>
<windowConfig darkMode="true" alpha="1.0" topmost="false" preventSleep="true">
    <titleBar color="20, 20, 30" borderColor="120, 60, 255" textColor="255, 255, 255" />
    <performance maxMemoryMB="2048" alertOnLowMemory="true" />
</windowConfig>

```

---

## 5. In-Engine Studio Suites

* **Chart Studio (`chartStudio.xmsoul` / `.soul`):** High-precision chart editor featuring multi-beat quantization snaps (`1/4` through `1/192`), split instrumental/vocal waveforms, hitsounds, hold duration transformers, and dynamic event tracks.


* **Actor Studio (`actorStudio.xmsoul` / `.soul`):** Character calibration studio for live animation playback, offset calculation, sprite scaling, sing hold duration tuning, and camera anchor offsets.


* **Stage Architect (`stageArchitect.xmsoul` / `.soul`):** Visual scene editor for assembling multi-layered parallax backgrounds, prop scaling, z-indexing, and real-time alpha/antialiasing controls.



---

## 6. Building from Source

The project includes an automated multi-target compiler suite (`build.bat`):

```cmd
# Windows 64-bit (Portable MinGW GCC - No admin rights required)
build.bat (Option 1)

# Windows 64-bit (Visual Studio MSVC Release)
build.bat (Option 2)

# Fast HashLink 64-Bit Bytecode Test
lime test hl

```