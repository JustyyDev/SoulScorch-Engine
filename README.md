# SoulScorch Engine

Welcome to SoulScorch Engine. This is a free rhythm game engine that you can change and play with. Think of it like a big toy box. You can add your own songs, characters, and even small programs that make the game do cool things.

## What is SoulScorch Engine

SoulScorch is a game engine. A game engine is like the frame of a car. It gives you the wheels, the motor, and the steering. You add the paint and the music.

With SoulScorch you can:
- Play rhythm games with notes that fall down the screen.
- Add your own songs and charts.
- Change how the game looks.
- Write small programs called scripts that change how the game acts.

## Meet the four script friends

A script is a small set of instructions for the game. SoulScorch understands four kinds of scripts. We call them the four script friends.

1. SoulScript (.soul and .hx files)
   This is the engine's own language. It is easy to read. You can also use plain Haxe code in .hx files.

2. HScript and Iris (.hscript and .iris files)
   These are simple script languages that run fast inside the game.

3. Lua (.lua files)
   Lua is a tiny and famous script language. SoulScorch uses a special helper called linc_luajit to talk to Lua. We made linc_luajit better and moved it to a new home. You can find it here: https://github.com/JustyyDev/linc_luajit

4. Python (.py files)
   Yes, you can even use Python. That is the language many schools teach.

You can mix and match. One mod can use a SoulScript file and a Lua file at the same time.

## How the engine runs your script

When the game loads your script, it calls a few special functions in order. We call these the lifecycle. It is like the morning routine of the game.

- create: This runs first. Set up your things here.
- onCreate: This runs right after create. Build your objects here.
- update: This runs every single frame. Use it to move things or check keys.
- onBeatHit: This runs when the music hits a beat. Use it to make things bounce to the song.

You do not need to write all of them. Write only the ones you need. The engine now calls create and onCreate for you in one clean step, so your script never runs them twice.

## Global scripts run everywhere

Some scripts are special. They are called global scripts. They keep running even when you move from one screen to another.

SoulScorch now finds global scripts by itself. It looks for .soul, .hx, .hscript, .iris, .lua, and .py files in your mod folder and in the base game folder. You do not need to list them by hand anymore.

A global script can do things like change the window title or watch for a key press.

## The folder map

Here is a simple map of the engine. You do not need to understand all of it. Just know where your mods go.

```
SoulScorch-Engine/
â”œâ”€â”€ assets/        # Pictures, music, and game data
â”œâ”€â”€ mods/          # Your mods go here (this is the fun folder)
â”œâ”€â”€ source/        # The engine code (you rarely touch this)
â””â”€â”€ build.bat      # A button that builds the game
```

Your mod lives inside the mods folder. Make a new folder there with your mod name.

## Modding guide (very easy)

Let us make a mod together. Follow these steps.

### Step 1: Make a mod folder

Go to the mods folder. Make a new folder called myfirstmod.

### Step 2: Tell the game about your mod

Inside myfirstmod, make a file called soulmod.json. Write this inside:

```json
{
  "name": "myfirstmod",
  "title": "My First Mod",
  "version": "1.0.0",
  "api_version": "1.0.0",
  "author": "Your Name",
  "description": "A fun little mod",
  "color": "#9d5ebd",
  "icon": "windowicon.png",
  "global_scripts": [],
  "dependencies": [],
  "load_priority": 0
}
```

### Step 3: Write a script

Make a folder called scripts inside myfirstmod. Now write a script. Pick any of the four friends.

SoulScript example (file: scripts/hello.soul):

```
on create:
    print("Hello from my mod")

on update(elapsed):
    if FlxG.keys.justPressed.SPACE:
        print("Space was pressed")
```

Lua example (file: scripts/hello.lua):

```lua
function create()
    print("Hello from Lua")
end

function update(elapsed)
    -- your code here
end
```

To talk to the game from Lua, use add_callback. This lets Lua call a Haxe function by name. The new linc_luajit keeps each Lua world's callbacks separate, so mods never mix up.

```lua
-- register a callback the engine can call
add_callback("myCoolThing", function(arg)
    print("The engine called me with " .. tostring(arg))
end)
```

Python example (file: scripts/hello.py):

```python
def create():
    print("Hello from Python")

def update(elapsed):
    pass
```

HScript example (file: scripts/hello.hscript):

```
function create() {
    trace("Hello from HScript");
}

function update(elapsed) {
    // your code here
}
```

### Step 4: Run the game

Start the engine. Your mod shows up in the mod list. Turn it on and play. That is it. You made a mod.

## The linc_luajit library

Lua support in SoulScorch uses a helper library called linc_luajit. We fixed it and made it better. It now has state scoped callbacks. That means each Lua world keeps its own list of callbacks. This stops bugs where one mod's callbacks leak into another.

The new home for the library is here: https://github.com/JustyyDev/linc_luajit

If you build the engine, it will grab the library from that new home by itself.

## Building the game

You can build the game on Windows with the build button.

```cmd
build.bat
```

This opens a menu. Pick option 1 for a quick build with no admin rights. Pick option 2 for a faster test build.

## Where to get help and more

Here are the three homes for this project:

- SoulScorch Engine (the game): https://github.com/JustyyDev/SoulScorch-Engine
- linc_luajit (the Lua helper): https://github.com/JustyyDev/linc_luajit
- HomeSoulDB (mods and extras): https://github.com/JustyyDev/HomeSoulDB

## Credits

SoulScorch Engine is made by the SoulScorch Team and its modders.

Special thanks to everyone who builds mods and shares them on HomeSoulDB.

The Lua power comes from linc_luajit, now kept at JustyyDev/linc_luajit.

Have fun and make something cool.
