# Mobile Modding and Builds

[Documentation home](../README.md) | [Desktop guide](DESKTOP_GUIDE.md) | [Assets guide](ASSETS_AND_DATA.md)

SoulScorch targets Android and iOS, but mobile systems have stricter storage, memory, signing, and process rules.

## Mobile scripting support

| Backend | Android | iOS | Notes |
| --- | --- | --- | --- |
| SoulScript | Yes | Yes | Runs inside the engine |
| HScript and Iris | Yes | Yes | Runs inside the engine |
| LuaJIT | Yes on C++ builds | Yes on C++ builds | Uses bundled platform libraries |
| Python | No | No | Needs an external Python process |
| JavaScript with Node | No | No | Needs an external Node process |

Use SoulScript, HScript, Iris, or Lua for mobile mods.

## Mobile asset rules

- Keep images reasonably small.
- Use power-of-two textures only when a platform or shader needs them.
- Compress audio before packaging.
- Avoid long uncompressed WAV files.
- Limit simultaneous particles and shaders.
- Test touch controls and wide screens.
- Do not assume a hardware keyboard exists.
- Do not use desktop-only file paths.

## Android builds

The GitHub workflow installs JDK 17, Android SDK 34, NDK 21.4, CMake, Haxe, hxcpp, and LuaJIT.

A local build uses:

```bash
haxelib run lime build android -release
```

The APK output is usually under `bin/android` or `export/android`.

Android users cannot always edit app-owned folders easily. For a public mobile mod system, provide an import screen or a documented accessible mods folder.

## iOS builds

The CI workflow creates an unsigned Xcode project. This does not produce a store-ready app.

To install on a device, open the project in Xcode and choose:

- An Apple development team
- A unique bundle identifier
- A connected device or simulator
- Valid signing settings

App Store releases need Apple certificates, provisioning, privacy information, and store review.

## Mobile testing checklist

- Test a fresh install.
- Test a device with limited memory.
- Test touch input in menus and gameplay.
- Test app pause and resume.
- Test headphones and speaker changes.
- Test different aspect ratios.
- Test missing optional files.
- Test low-end mode.
- Test a mod with Lua scripts.
- Test without network access.

## Mobile mod packages

Do not package desktop DLL, NDLL, EXE, Python, or Node files into a mobile mod. Keep mobile mods focused on portable assets, XMSoul, SoulScript, HScript, Iris, and Lua.
