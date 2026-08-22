package soulscorch.scripting;

import flixel.FlxG;
import flixel.math.FlxMath;
import flixel.util.FlxColor;
import hscript.Expr;
import hscript.Interp;
import hscript.Parser;

import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.AudioManager;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.system.EventBus;
import soulscorch.backend.system.XMSoul;
import soulscorch.backend.system.apis.NativeAPI;
import soulscorch.backend.system.engine.CrashHandler;
import soulscorch.backend.system.engine.DevConsole;
import soulscorch.backend.system.engine.Engine;
import soulscorch.backend.system.engine.EngineOptimizer;
import soulscorch.backend.system.engine.GameConfig;
import soulscorch.backend.system.engine.HotReloader;
import soulscorch.backend.system.engine.Runtime;
import soulscorch.backend.system.engine.Version;
import soulscorch.backend.system.framerate.Framerate;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.ScriptInstance;
import soulscorch.scripting.mod.ModLoader;
import soulscorch.scripting.mod.ModManager;

#if sys
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;
#end

using StringTools;

class Script implements ScriptInstance {
    public var active:Bool = false;
    public var path(default, null):String;

    public var interp:Interp;
    public var parser:Parser;
    public var ast:Expr;

    public function new(path:String, autoLoad:Bool = true) {
        this.path = path;
        interp = new Interp();
        parser = new Parser();

        parser.allowTypes = true;
        parser.allowJSON = true;
        parser.allowMetadata = true;

        setupGlobals();

        if (autoLoad) {
            load();
        }
    }

    public function setupGlobals():Void {
        // Core Haxe & Reflection
        set("Std", Std);
        set("Math", Math);
        set("StringTools", StringTools);
        set("Reflect", Reflect);
        set("Type", Type);
        set("Date", Date);
        set("DateTools", DateTools);
        set("Xml", Xml);
        set("Json", haxe.Json);

        // Native System & I/O
        #if sys
        set("Sys", Sys);
        set("File", sys.io.File);
        set("FileSystem", sys.FileSystem);
        set("Process", sys.io.Process);
        #end

        // Native OS API & Windowing
        set("NativeAPI", NativeAPI);
        set("openfl", {Lib: openfl.Lib});
        set("Lib", openfl.Lib);
        set("Application", openfl.Lib.application);
        set("window", openfl.Lib.application.window);
        set("stage", openfl.Lib.current.stage);

        // Flixel Core & States
        set("FlxG", flixel.FlxG);
        set("FlxSprite", flixel.FlxSprite);
        set("FlxCamera", flixel.FlxCamera);
        set("FlxText", flixel.text.FlxText);
        set("FlxObject", flixel.FlxObject);
        set("FlxState", flixel.FlxState);
        set("FlxSubState", flixel.FlxSubState);
        set("FlxBasic", flixel.FlxBasic);
        set("FlxBackdrop", flixel.addons.display.FlxBackdrop);
        set("FlxGridOverlay", flixel.addons.display.FlxGridOverlay);

        // Flx Groups & Containers
        set("FlxGroup", flixel.group.FlxGroup);
        set("FlxTypedGroup", flixel.group.FlxGroup.FlxTypedGroup);
        set("FlxSpriteGroup", flixel.group.FlxSpriteGroup);

        // Flx Tweens, Eases & Timing
        set("FlxTween", flixel.tweens.FlxTween);
        set("FlxEase", flixel.tweens.FlxEase);
        set("FlxTimer", flixel.util.FlxTimer);
        set("FlxSort", flixel.util.FlxSort);

        // Flx Math, Physics & Velocity
        set("FlxMath", flixel.math.FlxMath);
        set("FlxVelocity", flixel.math.FlxVelocity);
        set("FlxAngle", flixel.math.FlxAngle);

        // Flx Sounds & Effects
        set("FlxSound", flixel.sound.FlxSound);
        set("FlxTrail", flixel.addons.effects.FlxTrail);

        // Color Palettes & Utilities
        set("FlxColor", {
            BLACK: 0xFF000000,
            WHITE: 0xFFFFFFFF,
            RED: 0xFFFF0000,
            GREEN: 0xFF00FF00,
            BLUE: 0xFF0000FF,
            CYAN: 0xFF00FFFF,
            MAGENTA: 0xFFFF00FF,
            YELLOW: 0xFFFFFF00,
            TRANSPARENT: 0x00000000,
            fromRGB: flixel.util.FlxColor.fromRGB,
            fromHSL: flixel.util.FlxColor.fromHSL,
            fromString: flixel.util.FlxColor.fromString
        });

        // Engine Architecture, Performance & Modding
        set("Runtime", Runtime);
        set("Engine", Engine);
        set("Version", Version);
        set("Conductor", Conductor);
        set("Paths", Paths);
        set("EventBus", EventBus);
        set("Logger", Logger);
        set("ModLoader", ModLoader);
        set("ModManager", ModManager);
        set("XMSoul", XMSoul);
        set("EngineOptimizer", EngineOptimizer);
        set("HotReloader", HotReloader);
        set("DevConsole", DevConsole);
        set("AssetResolver", AssetResolver);
        set("AssetHelper", AssetHelper);
        set("AudioManager", AudioManager);

        // Visuals & Shaders
        set("JuiceManager", soulscorch.graphics.JuiceManager);
        set("SoulShader", soulscorch.graphics.shaders.SoulShader);
        set("ShaderManager", soulscorch.graphics.shaders.ShaderManager);

        // Gameplay Actors, Notes, Mechanics & Charting
        set("Character", soulscorch.gameplay.actors.Character);
        set("HealthIcon", soulscorch.gameplay.actors.HealthIcon);
        set("Note", soulscorch.gameplay.notes.Note);
        set("Strumline", soulscorch.gameplay.notes.Strumline);
        set("StrumArrow", soulscorch.gameplay.notes.StrumArrow);
        set("NoteSplash", soulscorch.gameplay.notes.NoteSplash);
        set("NoteSkinManager", soulscorch.gameplay.notes.NoteSkinManager);
        set("Stage", soulscorch.gameplay.stage.Stage);
        set("GameplayFlags", soulscorch.gameplay.GameplayFlags);
        set("JudgementManager", soulscorch.gameplay.JudgementManager);
        set("ModchartManager", soulscorch.gameplay.modchart.ModchartManager);

        // UI & Menus
        set("MusicBeatState", MusicBeatState);
        set("ResultsState", soulscorch.ui.menus.states.ResultsState);
        set("GameOverSubState", soulscorch.ui.menus.substate.GameOverSubState);
        set("PauseSubState", soulscorch.ui.menus.substate.PauseSubState);

        // Live Context & Shorthand Hooks
        set("game", flixel.FlxG.state);
        set("state", flixel.FlxG.state);
        set("camera", flixel.FlxG.camera);
        set("cameras", flixel.FlxG.cameras);
        set("sound", flixel.FlxG.sound);
        set("keys", flixel.FlxG.keys);
        set("mouse", flixel.FlxG.mouse);
        set("defaultCamZoom", 1.0);
        set("PlayState", soulscorch.gameplay.PlayState);

        // Script Global Helper Utilities
        set("add", function(obj:flixel.FlxBasic) {
            if (flixel.FlxG.state != null) flixel.FlxG.state.add(obj);
        });
        set("remove", function(obj:flixel.FlxBasic) {
            if (flixel.FlxG.state != null) flixel.FlxG.state.remove(obj);
        });
        set("insert", function(index:Int, obj:flixel.FlxBasic) {
            if (flixel.FlxG.state != null) flixel.FlxG.state.insert(index, obj);
        });
        set("switchState", function(nextState:flixel.FlxState) {
            MusicBeatState.switchState(nextState);
        });
        set("log", function(msg:Dynamic) {
            Logger.info(Std.string(msg), "script");
        });
        set("trace", function(msg:Dynamic) {
            Logger.info(Std.string(msg), "script");
        });
    }

    public function load():Bool {
        if (path == null || path.trim().length == 0) {
            active = false;
            return false;
        }

        var fullPath = ModLoader.getPath(path.trim());
        if (!AssetResolver.exists(fullPath)) {
            active = false;
            return false;
        }

        try {
            var rawCode = AssetResolver.getText(fullPath);
            ast = parser.parseString(rawCode);
            interp.execute(ast);
            active = true;
            return true;
        } catch (e:Dynamic) {
            Logger.error('Script parse/runtime error in $path: $e', "script");
            if (DevConsole.instance != null) {
                DevConsole.instance.log('[SCRIPT ERROR] $path: ' + Std.string(e));
            }
            active = false;
            return false;
        }
    }

    public function set(key:String, value:Dynamic):Void {
        if (interp != null) {
            interp.variables.set(key, value);
        }
    }

    public function get(key:String):Dynamic {
        return (interp != null) ? interp.variables.get(key) : null;
    }

    public function call(func:String, ?args:Array<Dynamic>):Dynamic {
        if (!active || interp == null || !interp.variables.exists(func)) return null;

        var fn = interp.variables.get(func);
        if (fn != null && Reflect.isFunction(fn)) {
            try {
                return Reflect.callMethod(null, fn, (args != null) ? args : []);
            } catch (e:Dynamic) {
                Logger.error('Runtime error in script $func ($path): $e', "script");
            }
        }
        return null;
    }

    public function destroy():Void {
        active = false;
        if (interp != null) {
            interp.variables.clear();
            interp = null;
        }
        parser = null;
        ast = null;
    }
}