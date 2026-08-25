# Desktop Installation and Modding

[Documentation home](../README.md) | [Mobile guide](MOBILE_GUIDE.md) | [Troubleshooting](TROUBLESHOOTING.md)

## Playing mods

1. Download a mod zip.
2. Extract it once.
3. Put the mod folder inside `mods/`.
4. Start SoulScorch.
5. Open the mod menu.
6. Enable the mod.
7. Restart when the mod changes global systems or assets.

The folder should look like `mods/mod-id/soulmod.xmsoul`, not `mods/mod-id/mod-id/soulmod.xmsoul`.

## Windows development

Run `setup_portable_env.bat` for a local non-admin toolchain, or install Haxe and the required libraries yourself.

Run `build.bat` and choose:

- `1` for MinGW Windows release
- `2` for MSVC Windows release
- `3` for MSVC debug
- `8` for HashLink
- `9` for CPPIA testing
- `S` to install libraries

MSVC requires Visual Studio Build Tools with the C++ workload. MinGW can be downloaded by the build menu.

## Linux development

Install Haxe, Neko, a C++ compiler, and the native libraries listed in the release workflow. Then run:

```bash
haxelib run lime build linux -release
```

Use `xdg-open` support for links and file locations. Linux paths are case-sensitive, so match every filename exactly.

## macOS development

Install Xcode command-line tools, Haxe, and the haxelibs from the release workflow. Build with:

```bash
haxelib run lime build mac -release
```

The current CI uses an Intel runner because Lime 8.1.3 provides an Intel `Mac64` host NDLL. If you build on Apple Silicon, the Haxe, Neko, Lime host binary, and terminal architecture must agree.

## Faster builds

- Keep the haxelib and hxcpp caches.
- Do not run a deep clean for normal edits.
- Keep precompiled headers enabled.
- Build one target at a time.
- Use the fast compile check before a release build.
- Keep generated build folders out of virus scanning when your system policy allows it.

## Standalone mod packages

Run `mod-packager.bat`, choose a mod, then choose Windows or HashLink. The packager builds the engine, copies required runtime files, copies shared assets, copies the selected mod, and writes `engine.cfg`.

Test the package on a clean folder before uploading it.

## Optional FMOD

Set `FMOD_SDK` before building. The build scripts enable FMOD when the SDK is present. Without it, SoulScorch uses the standard Flixel audio backend.

Do not include FMOD SDK files in a public repository unless its license allows that exact redistribution.
