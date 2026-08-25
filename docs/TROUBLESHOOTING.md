# Troubleshooting Guide

[Documentation home](../README.md) | [Beginner guide](BEGINNER_MODDING.md) | [Desktop guide](DESKTOP_GUIDE.md)

## The mod does not appear

- Confirm the folder is directly inside `mods/`.
- Confirm it contains `soulmod.xmsoul`, `soulmod.json`, or another supported mod config.
- Check that the folder name is not hidden or prefixed with `_`.
- Validate the JSON or XML syntax.
- Restart the engine after changing the mod config.

## The mod cannot be enabled

Check dependencies. Every required mod must be installed. Look at validation warnings in the mod menu or logs.

## A song is missing from Freeplay

- Check the song ID and metadata path.
- Check that at least one chart exists.
- Check difficulty spelling.
- Check filename capitalization on Linux and mobile.
- Look for a malformed JSON or XMSoul file.

## A character is invisible

- Confirm the PNG and XML atlas both exist.
- Confirm the image path in character data.
- Confirm animation prefixes match atlas names.
- Check scale and position offsets.
- Test with antialiasing on and off.

## An icon is stretched or uses the wrong face

- Check frame count and image width.
- Use icon XMSoul metadata for unusual sheets.
- For three frames, use normal `0`, losing `1`, winning `2`.
- Clear caches or restart after replacing icon files.

## A script does not run

- Check the extension.
- Check the script path in the mod config.
- Check whether the backend is enabled.
- Check callback spelling.
- Read the script error in the log.
- Remember that Python and JavaScript are desktop process backends.

## The game lags

- Disable expensive shaders.
- Reduce particles and splashes.
- Remove file reads from `update`.
- Check slow-script warnings.
- Test without song previews.
- Test low-end mode.
- Shrink very large textures and icons.

## Windows build problems

Use `build.bat` option `S` to install libraries. For MSVC, install Visual Studio C++ Build Tools. For MinGW, use the download option in the build menu.

## Linux build problems

Install the compiler and native audio, input, OpenGL, X11, udev, and DBus development packages. Linux paths are case-sensitive.

## macOS build problems

Make sure Haxe, Neko, Lime, and the runner architecture match. The CI workflow patches an old hxcpp zlib conflict for modern Apple SDKs.

## Android build problems

Check Java 17, Android SDK 34, NDK 21.4, CMake, and accepted SDK licenses. Confirm environment variables point to the same NDK folder.

## iOS signing problems

CI generates an unsigned Xcode project. Device and store builds require an Apple development team, bundle ID, certificates, and provisioning.

## Before reporting a bug

Include:

- Operating system
- Build target
- Engine commit or version
- Enabled mods
- Exact steps to reproduce
- Full error text
- Relevant log files
- Whether the problem happens with all mods disabled
