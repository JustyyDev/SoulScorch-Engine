package soulscorch.scripting;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.math.FlxAngle;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxVelocity;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxSort;
import flixel.util.FlxTimer;
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
import soulscorch.backend.system.SaveData;
import soulscorch.backend.system.XMSoul;
import soulscorch.backend.system.apis.NativeAPI;
import soulscorch.backend.system.engine.DevConsole;
import soulscorch.backend.system.engine.Engine;
import soulscorch.backend.system.engine.EngineOptimizer;
import soulscorch.backend.system.engine.HotReloader;
import soulscorch.backend.system.engine.Runtime;
import soulscorch.backend.system.engine.Version;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.PlayState;
import soulscorch.scripting.ScriptInstance;
import soulscorch.scripting.ScriptTools;
import soulscorch.scripting.mod.ModLoader;
import soulscorch.scripting.mod.ModManager;

#if sys
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;
#end

using StringTools;

class SoulScorchInterp extends Interp {
    override function get(o:Dynamic, f:String):Dynamic {
        if (o == null) {
            if (variables.exists(f)) {
                return variables.get(f);
            }
            
            // Fast-path resolution avoiding reflection overhead
            var ps = PlayState.instance;
            if (ps != null) {
                switch (f) {
                    case "boyfriend" | "bf": return ps.boyfriend;
                    case "dad": return ps.dad;
                    case "gf": return ps.gf;
                    case "currentStage" | "stage": return ps.currentStage;
                    case "camGame": return ps.camGame;
                    case "camHUD": return ps.camHUD;
                    case "camOther": return ps.camOther;
                    case "camControls": return ps.camControls;
                    case "playerStrumline": return ps.playerStrumline;
                    case "opponentStrumline": return ps.opponentStrumline;
                    case "playerStrums": return (ps.playerStrumline != null) ? ps.playerStrumline.receptors : null;
                    case "opponentStrums": return (ps.opponentStrumline != null) ? ps.opponentStrumline.receptors : null;
                    case "notes": return ps.notes;
                    case "sustainsGroup": return ps.sustainsGroup;
                    case "curBeat": return ps.curBeat;
                    case "curStep": return ps.curStep;
                    case "health": return ps.health;
                    case "songScore": return ps.songScore;
                    case "songMisses": return ps.songMisses;
                    case "accuracy": return ps.accuracy;
                    case "defaultCamZoom": return ps.defaultCamZoom;
                    case "defaultHUDZoom": return ps.defaultHUDZoom;
                    case "middlescroll": return ps.middlescroll;
                    case "downscroll": return ps.downscroll;
                    case "botplay": return ps.botplay;
                    case "paused": return ps.paused;
                    case "isEnding": return ps.isEnding;
                }
            }

            if (f == "game" || f == "state") return (ps != null) ? ps : FlxG.state;
            if (f == "camera") return FlxG.camera;
            if (f == "cameras") return FlxG.cameras;
        }
        return super.get(o, f);
    }

    override function set(o:Dynamic, f:String, v:Dynamic):Dynamic {
        if (o == null) {
            var ps = PlayState.instance;
            if (ps != null) {
                switch (f) {
                    case "health": ps.health = v; return v;
                    case "defaultCamZoom": ps.defaultCamZoom = v; return v;
                    case "defaultHUDZoom": ps.defaultHUDZoom = v; return v;
                    case "middlescroll": ps.middlescroll = v; return v;
                    case "downscroll": ps.downscroll = v; return v;
                    case "botplay": ps.botplay = v; return v;
                }
            }
            variables.set(f, v);
            return v;
        }
        return super.set(o, f, v);
    }
}

class Script implements ScriptInstance {
    public var active:Bool = false;
    public var path(default, null):String;

    public var interp:SoulScorchInterp;
    public var parser:Parser;
    public var ast:Expr;

    public function new(path:String, autoLoad:Bool = true) {
        this.path = path;
        interp = new SoulScorchInterp();
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
        // Haxe Standard Library
        set("Std", Std);
        set("Math", Math);
        set("StringTools", StringTools);
        set("Reflect", Reflect);
        set("Type", Type);
        set("Date", Date);
        set("DateTools", DateTools);
        set("Xml", Xml);
        set("Json", haxe.Json);

        #if sys
        set("Sys", Sys);
        set("File", sys.io.File);
        set("FileSystem", sys.FileSystem);
        set("Process", sys.io.Process);
        #end

        set("NativeAPI", NativeAPI);
        set("openfl", {Lib: openfl.Lib});
        set("Lib", openfl.Lib);
        set("Application", openfl.Lib.application);
        set("window", openfl.Lib.application.window);
        set("stage", openfl.Lib.current.stage);

        // Flixel Core & Hierarchy
        set("FlxG", flixel.FlxG);
        set("FlxSprite", flixel.FlxSprite);
        set("FlxCamera", flixel.FlxCamera);
        set("FlxText", flixel.text.FlxText);
        set("FlxObject", flixel.FlxObject);
        set("FlxState", flixel.FlxState);
        set("FlxSubState", flixel.FlxSubState);
        set("FlxBasic", flixel.FlxBasic);
        set("FlxGroup", flixel.group.FlxGroup);
        set("FlxTypedGroup", flixel.group.FlxGroup.FlxTypedGroup);
        set("FlxSpriteGroup", flixel.group.FlxSpriteGroup);
        set("FlxTween", flixel.tweens.FlxTween);
        set("FlxEase", flixel.tweens.FlxEase);
        set("FlxTimer", flixel.util.FlxTimer);
        set("FlxSort", flixel.util.FlxSort);
        set("FlxMath", flixel.math.FlxMath);
        set("FlxVelocity", flixel.math.FlxVelocity);
        set("FlxAngle", flixel.math.FlxAngle);
        set("FlxSound", flixel.sound.FlxSound);

        // Safe FlxPoint bridge
        set("FlxPoint", {
            get: function(?x:Float = 0, ?y:Float = 0) return FlxPoint.get(x, y),
            weak: function(?x:Float = 0, ?y:Float = 0) return FlxPoint.weak(x, y),
            set: function(point:FlxPoint, ?x:Float = 0, ?y:Float = 0) return point.set(x, y)
        });

        // Color Presets
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

        // SoulScorch Backend
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
        set("SaveData", SaveData);
        set("EngineOptimizer", EngineOptimizer);
        set("HotReloader", HotReloader);
        set("DevConsole", DevConsole);
        set("AssetResolver", AssetResolver);
        set("AssetHelper", AssetHelper);
        set("AudioManager", AudioManager);
        set("JuiceManager", soulscorch.graphics.JuiceManager);
        set("ScriptTools", ScriptTools);

        // Gameplay Types
        set("Character", soulscorch.gameplay.actors.Character);
        set("HealthIcon", soulscorch.gameplay.actors.HealthIcon);
        set("Note", soulscorch.gameplay.notes.Note);
        set("Strumline", soulscorch.gameplay.notes.Strumline);
        set("StrumArrow", soulscorch.gameplay.notes.StrumArrow);
        set("NoteSplash", soulscorch.gameplay.notes.NoteSplash);
        set("NoteSkinManager", soulscorch.gameplay.notes.NoteSkinManager);
        set("Stage", soulscorch.gameplay.stage.Stage);
        set("PlayState", PlayState);

        // State Helpers
        set("add", function(obj:FlxBasic) {
            if (FlxG.state != null) FlxG.state.add(obj);
        });
        set("remove", function(obj:FlxBasic) {
            if (FlxG.state != null) FlxG.state.remove(obj);
        });
        set("insert", function(index:Int, obj:FlxBasic) {
            if (FlxG.state != null) FlxG.state.insert(index, obj);
        });
        set("addBehindGF", function(obj:FlxBasic) {
            var ps = PlayState.instance;
            if (ps != null && ps.gf != null) {
                var idx = ps.members.indexOf(ps.gf);
                if (idx != -1) ps.insert(idx, obj); else ps.add(obj);
            } else if (FlxG.state != null) {
                FlxG.state.add(obj);
            }
        });
        set("addBehindBF", function(obj:FlxBasic) {
            var ps = PlayState.instance;
            if (ps != null && ps.boyfriend != null) {
                var idx = ps.members.indexOf(ps.boyfriend);
                if (idx != -1) ps.insert(idx, obj); else ps.add(obj);
            } else if (FlxG.state != null) {
                FlxG.state.add(obj);
            }
        });
        set("addBehindDad", function(obj:FlxBasic) {
            var ps = PlayState.instance;
            if (ps != null && ps.dad != null) {
                var idx = ps.members.indexOf(ps.dad);
                if (idx != -1) ps.insert(idx, obj); else ps.add(obj);
            } else if (FlxG.state != null) {
                FlxG.state.add(obj);
            }
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
            active = false;
            return false;
        }
    }

    public function set(key:String, value:Dynamic):Void {
        if (interp != null) interp.variables.set(key, value);
    }

    public function get(key:String):Dynamic {
        return (interp != null) ? interp.variables.get(key) : null;
    }

    public function importClass(className:String):Bool {
        if (className == null) return false;
        var resolvedClass:Dynamic = Type.resolveClass(className);
        if (resolvedClass == null) resolvedClass = Type.resolveEnum(className);

        if (resolvedClass != null) {
            var shortName:String = className.substr(className.lastIndexOf(".") + 1);
            set(shortName, resolvedClass);
            return true;
        }
        return false;
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