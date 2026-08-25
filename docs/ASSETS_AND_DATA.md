# Assets and Data Guide

[Documentation home](../README.md) | [Beginner guide](BEGINNER_MODDING.md) | [Troubleshooting](TROUBLESHOOTING.md)

## Asset lookup

The engine checks active mods before built-in assets. A mod can replace an asset by using the same logical path. Keep paths lowercase when possible and use forward slashes in data files.

## Images

Use PNG for sprites. Animated sprites normally use a PNG plus Sparrow XML atlas. Keep transparent space under control because it increases texture memory.

## Audio

- `Inst.ogg` contains the instrumental.
- `Voices.ogg` contains combined vocals.
- `Voices-Player.ogg` and `Voices-Opponent.ogg` can hold split stems.
- Menu sounds belong in a sounds folder.
- Music belongs in a music folder.

## Songs

A song can contain metadata, charts, events, scripts, audio, and optional video or dialogue files. Use one stable lowercase ID everywhere.

## Characters

Character XMSoul controls the image, icon, player side, scale, flip, health color, camera offset, position offset, and animations. Animation prefixes must match the atlas XML exactly.

## Health icons

Supported layouts:

- One frame: normal only
- Two frames: normal `0`, losing `1`
- Three frames: normal `0`, losing `1`, winning `2`

An icon XMSoul file can set frame count, frame roles, display size, scale bounds, antialiasing, offsets, and bop behavior.

## Stages

Stage data controls layers, sprites, animations, scroll factors, scale, positions, camera zoom, and character placement. Name important sprites so scripts can find them.

## Noteskins

A noteskin defines receptor animations, tap-note animations, sustain pieces, scale, and antialiasing. Splash skins define lane animations, offsets, frame rates, scale, and alpha.

## Dialogue

Dialogue can define the speaker, expression, side, text, typing speed, voice sound, one-time sound, bubble type, portrait, and box. Keep lines short enough for the target screen.

## XMSoul tips

```xml
<root enabled="true" speed="1.0">
    <item id="one" path="images/example" />
</root>
```

- Quote every attribute value.
- Escape `&` as `&amp;`.
- Use `true` and `false` for booleans.
- Use commas for arrays when the parser expects them.
- Keep IDs unique inside one file.
- Copy a working built-in file before creating a complex one from nothing.

## Localization

Text keys belong in language files. Use fallback text when adding a new key. Localized assets can be placed under the matching language asset folders.
