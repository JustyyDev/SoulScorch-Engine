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