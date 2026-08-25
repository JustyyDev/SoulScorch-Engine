# Advanced Modding Guide

[Documentation home](../README.md) | [Beginner guide](BEGINNER_MODDING.md) | [Scripting guide](SCRIPTING_GUIDE.md)

This guide covers larger mods that change several engine systems.

## Mod load order

Use `priority` in `soulmod.xmsoul`. Higher-priority mods load first.

```xml
<mod name="Expansion Pack" version="2.0.0" author="Team" apiVersion="1.0.0" priority="20">
    <dependencies>
        <dependency name="base-library" />
    </dependencies>
</mod>
```

Do not depend on load order when a dependency is clearer. Declare every required mod.

## Global scripts

Global scripts stay active across states. Good uses will include shared helpers, state redirects, overlays, and engine-wide events.

```xml
<scripts>
    <script path="scripts/global.soul" global="true" />
    <script path="scripts/debug.lua" global="true" />
</scripts>
```

Keep global `update` callbacks light. Expensive work should run on a beat, timer, event, or state change.

## State redirects

Global scripts can redirect a built-in state to a scripted state. Use a unique state ID to avoid collisions with other mods. Always provide a way to return to the previous menu.

## Custom events

Song events can control cameras, characters, shaders, noteskins, health, and mod-specific logic.

Plan event values before charting:

```text
Event name: Change Scene Color
Value 1: #FF3366
Value 2: 0.5
```

Handle unknown or empty values safely. Old charts may not contain every value your latest script expects.

## Runtime notes and modcharts

Scripts can queue notes, queue events, change modifiers, and tween modifier values. Keep directions between `0` and `3`. Clamp sustain lengths and avoid creating thousands of objects in one frame.

## Shaders

Place shaders in:

```text
mods/my-mod/shaders/myEffect.frag
```

Create and attach them through the shared script API:

```haxe
var shader = createShader("myEffect");
addShaderToCam("myEffect", "hud");
setShaderFloat("myEffect", "strength", 0.4);
```

Mods can override a base shader by using the same path and name. Clear camera shaders when leaving a custom state.

## XMSoul configuration

XMSoul is useful for data that creators should change without editing code. It is used for characters, stages, icons, noteskins, credits, transitions, dialogue, windows, videos, and engine modules.

Prefer attributes for short values and child nodes for lists.

```xml
<thing enabled="true" speed="1.2">
    <item id="first" value="10" />
    <item id="second" value="20" />
</thing>
```

## Performance rules

- Cache parsed files and resolved assets.
- Pool objects used many times.
- Avoid file reads in `update`.
- Avoid creating tweens every frame.
- Use event cursors instead of scanning full arrays.
- Limit particles, splashes, and shader passes.
- Test low-end mode.
- Destroy timers, sounds, shaders, and sprites when finished.

## Compatibility

Use feature checks when calling optional systems. Lua requires a C++ target. Python and JavaScript need desktop executables. FMOD needs its SDK at build time.

A good advanced mod still works when an optional feature is unavailable. Show a useful fallback instead of crashing.

## Validation and release

Validate the mod folder before packaging. Test these cases:

- The mod is the only enabled mod.
- The mod loads with every declared dependency.
- A dependency is missing.
- Another mod overrides the same song or asset.
- The save file has old values.
- The selected language is not English.
- Low-end mode is enabled.
- The game is restarted after enabling or disabling the mod.
