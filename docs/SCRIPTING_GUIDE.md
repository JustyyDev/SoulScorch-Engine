# Scripting Guide

[Documentation home](../README.md) | [Beginner guide](BEGINNER_MODDING.md) | [Advanced guide](ADVANCED_MODDING.md)

## Choosing a language

Use SoulScript for readable actions, HScript or Iris for deep engine work, and Lua when you prefer common Friday Night Funkin mod APIs. Python and JavaScript are desktop process backends for occasional callbacks and tools.

## Lifecycle callbacks

Common callbacks include:

```text
create()
onCreate()
onPostCreate()
onSongStart()
onUpdate(elapsed)
onUpdatePost(elapsed)
onBeatHit(beat)
onStepHit(step)
onDestroy()
```

Gameplay scripts can also receive note, input, event, health, pause, and game-over callbacks.

## SoulScript

```text
on create:
    play sound "confirmMenu" at 0.7

at beat 8:
    camera flash CYAN for 0.2s

every 4 beats:
    camera shake 0.005 for 0.1s

on update:
    if health < 0.5:
        set flag "danger" to true
```

Beat and step blocks trigger once when their boundary is reached.

## HScript and Iris

```haxe
function onCreate() {
    var sprite = new FlxSprite(100, 100);
    sprite.makeGraphic(80, 80, FlxColor.CYAN);
    add(sprite);
}
```

These backends can work directly with live Haxe and Flixel objects.

## Lua

```lua
function onCreate()
    makeLuaSprite('box', '', 100, 100)
    makeGraphic('box', 80, 80, '00FFFF')
    addLuaSprite('box', true)
end

function onBeatHit(beat)
    cameraShake('game', 0.005, 0.1)
end
```

LuaJIT is available on supported C++ desktop and mobile targets.

## Python and JavaScript

These run as external processes. They cannot keep live references to Haxe objects. Use them for file tools, metadata generation, validation, and occasional callbacks.

JavaScript receives the callback name and a JSON payload through Node.js. Python receives command-line callback arguments.

## Shared API

In-process scripts receive shared helpers for:

- Assets and paths
- XMSoul
- Mod state and dependencies
- Gameplay objects
- Cameras and coordinate conversion
- Timers and tweens
- Shaders and uniforms
- Discord presence
- GitHub update checks
- Events and custom states

## Performance

- Never read files every frame.
- Do not spawn a process from `onUpdate`.
- Reuse arrays and sprites.
- Cancel old tweens with the same purpose.
- Use beat, step, event, and timer callbacks.
- Destroy objects created by the script.
- Keep global scripts lighter than song scripts.

## Cancellable hooks

Some callbacks can return `false` to stop the engine default action. Examples include before-note-hit, before-event, before-pause, and before-game-over hooks. Use cancellation carefully so controls and cleanup still work.
