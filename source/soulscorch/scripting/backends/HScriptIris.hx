package soulscorch.scripting.backends;

#if SOULSCORCH_IRIS
import crowplexus.iris.Iris;
#else
import hscript.Interp;
import hscript.Parser;
#end

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.FlxSubState;
import flixel.addons.display.FlxBackdrop;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.effects.FlxTrail;
import flixel.group.FlxGroup;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxAngle;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.math.FlxVelocity;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.ui.FlxBar;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import flixel.util.FlxSort;
import flixel.util.FlxTimer;
import lime.app.Application;
import openfl.Lib;
import openfl.display.BlendMode;
import openfl.filters.ShaderFilter;
import openfl.geom.Matrix;
import openfl.net.URLRequest;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.AudioManager;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.input.Controls;
import soulscorch.backend.system.EventBus;
import soulscorch.backend.system.SaveData;
import soulscorch.backend.system.XMSoul;
import soulscorch.backend.system.apis.FileSystemAPI;
import soulscorch.backend.system.apis.ModelAPI;
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
import soulscorch.gameplay.GameplayFlags;
import soulscorch.gameplay.JudgementManager;
import soulscorch.gameplay.PlayState;
import soulscorch.gameplay.actors.Character;
import soulscorch.gameplay.actors.HealthIcon;
import soulscorch.gameplay.modchart.ModchartManager;
import soulscorch.gameplay.notes.Note;
import soulscorch.gameplay.notes.NoteSkinManager;
import soulscorch.gameplay.notes.NoteSplash;
import soulscorch.gameplay.notes.StrumArrow;
import soulscorch.gameplay.notes.Strumline;
import soulscorch.gameplay.stage.Stage;
import soulscorch.graphics.JuiceManager;
import soulscorch.graphics.shaders.ShaderManager;
import soulscorch.graphics.shaders.SoulShader;
import soulscorch.graphics.threed.Away3DManager;
import soulscorch.scripting.ScriptInstance;
import soulscorch.scripting.ScriptManager;
import soulscorch.scripting.ScriptedState;
import soulscorch.scripting.ScriptedSubState;
import soulscorch.scripting.mod.ModCustomState;
import soulscorch.scripting.mod.ModLoader;
import soulscorch.scripting.mod.ModManager;
import soulscorch.scripting.mod.SoulGlobalScript;
import soulscorch.ui.menus.credits.CreditsState;
import soulscorch.ui.menus.option.OptionsMenuState;
import soulscorch.ui.menus.states.FreeplayState;
import soulscorch.ui.menus.states.MainMenuState;
import soulscorch.ui.menus.states.ResultsState;
import soulscorch.ui.menus.states.StoryMenuState;
import soulscorch.ui.menus.states.TitleState;
import soulscorch.ui.menus.substate.GameOverSubState;
import soulscorch.ui.menus.substate.PauseSubState;

#if sys
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;
#end

using StringTools;

class HScriptIris implements ScriptInstance {
    public var active:Bool = false;
    public var path(default, null):String;

    public var customSprites:Map<String, FlxSprite> = new Map<String, FlxSprite>();
    public var customTexts:Map<String, FlxText> = new Map<String, FlxText>();
    public var activeTweens:Map<String, FlxTween> = new Map<String, FlxTween>();
    public var activeTimers:Map<String, FlxTimer> = new Map<String, FlxTimer>();

    #if SOULSCORCH_IRIS
    private var iris:Iris;
    #else
    private var interp:Interp;
    #end

    public function new(scriptPath:String, ?customCode:String) {
        this.path = (scriptPath == null) ? "" : scriptPath;
        
        var code:String = customCode;
        #if sys
        if (code == null && path != "" && FileSystem.exists(path)) {
            code = File.getContent(path);
        }
        #end

        if (code != null) {
            #if SOULSCORCH_IRIS
            this.iris = new Iris(code, {name: path, autoRun: false});
            presetEnvironment();
            load();
            #else
            var parser = new Parser();
            parser.allowTypes = false;
            parser.allowJSON = true;
            
            try {
                var program = parser.parseString(code);
                this.interp = new Interp();
                
                for (i in 0...2000) {
                    interp.variables.set(Std.string(i), i);
                }

                presetEnvironment();
                interp.execute(program);
                active = true;
            } catch (e:Dynamic) {
                Logger.error('HScript initialization error in $path: $e', "hscript");
                active = false;
            }
            #end
        }
    }

    public function load():Bool {
        #if SOULSCORCH_IRIS
        if (iris == null) return false;
        try {
            iris.execute();
            active = true;
        } catch (e:Dynamic) {
            Logger.error('Failed to execute Iris script ($path): $e', "iris");
            active = false;
        }
        return active;
        #else
        return active;
        #end
    }

    private function presetEnvironment():Void {
        set("curBeat", Conductor.curBeat);
        set("curStep", Conductor.curStep);
        set("curDecBeat", Conductor.curDecBeat);
        set("curDecStep", Conductor.curDecStep);
        set("bpm", Conductor.bpm);
        set("crochet", Conductor.crochet);
        set("stepCrochet", Conductor.stepCrochet);
        set("songPosition", Conductor.songPosition);

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
        set("FileSystemAPI", FileSystemAPI);
        set("openfl", {Lib: openfl.Lib});
        set("Lib", openfl.Lib);
        set("Application", lime.app.Application);
        set("window", (openfl.Lib.application != null) ? openfl.Lib.application.window : null);
        set("stage", openfl.Lib.current.stage);
        set("Controls", Controls.instance);
        set("controls", Controls.instance);

        set("FlxG", FlxG);
        set("FlxSprite", FlxSprite);
        set("FlxCamera", FlxCamera);
        set("FlxText", FlxText);
        set("FlxObject", FlxObject);
        set("FlxState", FlxState);
        set("FlxSubState", FlxSubState);
        set("FlxBasic", FlxBasic);
        set("FlxBar", FlxBar);
        set("FlxButton", FlxButton);
        set("FlxBackdrop", FlxBackdrop);
        set("FlxGridOverlay", FlxGridOverlay);

        set("FlxPoint", {
            get: function(?x:Float = 0, ?y:Float = 0) return FlxPoint.get(x, y),
            weak: function(?x:Float = 0, ?y:Float = 0) return FlxPoint.weak(x, y),
            set: function(point:FlxPoint, ?x:Float = 0, ?y:Float = 0) return point.set(x, y)
        });
        set("FlxRect", {get: FlxRect.get});

        set("FlxGroup", FlxGroup);
        set("FlxTypedGroup", FlxTypedGroup);
        set("FlxSpriteGroup", FlxSpriteGroup);

        set("FlxTween", FlxTween);
        set("FlxEase", FlxEase);
        set("FlxTimer", FlxTimer);
        set("FlxSort", FlxSort);

        set("FlxMath", FlxMath);
        set("FlxVelocity", FlxVelocity);
        set("FlxAngle", FlxAngle);

        set("FlxSound", FlxSound);
        set("FlxTrail", FlxTrail);

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
            fromRGB: FlxColor.fromRGB,
            fromHSL: FlxColor.fromHSL,
            fromString: FlxColor.fromString
        });

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
        set("SaveData", SaveData.instance);
        set("EngineOptimizer", EngineOptimizer);
        set("HotReloader", HotReloader);
        set("DevConsole", DevConsole);
        set("AssetResolver", AssetResolver);
        set("AssetHelper", AssetHelper);
        set("AudioManager", AudioManager);
        set("Framerate", Framerate);
        set("GameConfig", GameConfig);
        set("CrashHandler", CrashHandler);

        set("JuiceManager", JuiceManager);
        set("SoulShader", SoulShader);
        set("ShaderManager", ShaderManager.instance);

        set("Character", Character);
        set("HealthIcon", HealthIcon);
        set("Note", Note);
        set("Strumline", Strumline);
        set("StrumArrow", StrumArrow);
        set("NoteSplash", NoteSplash);
        set("NoteSkinManager", NoteSkinManager);
        set("Stage", Stage);
        set("GameplayFlags", GameplayFlags);
        set("JudgementManager", JudgementManager);
        set("ModchartManager", ModchartManager);

        set("MusicBeatState", MusicBeatState);
        set("ResultsState", ResultsState);
        set("GameOverSubState", GameOverSubState);
        set("PauseSubState", PauseSubState);
        set("PlayState", PlayState);

        syncStateVariables();

        set("add", function(obj:FlxBasic) {
            if (FlxG.state != null) FlxG.state.add(obj);
        });

        set("remove", function(obj:FlxBasic) {
            if (FlxG.state != null) FlxG.state.remove(obj);
        });

        set("insert", function(idx:Int, obj:FlxBasic) {
            if (FlxG.state != null) FlxG.state.insert(idx, obj);
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

    public function syncStateVariables():Void {
        var ps = PlayState.instance;
        set("game", ps != null ? ps : FlxG.state);
        set("state", FlxG.state);
        set("camera", FlxG.camera);
        set("cameras", FlxG.cameras);
        set("sound", FlxG.sound);
        set("keys", FlxG.keys);
        set("mouse", FlxG.mouse);

        if (ps != null) {
            set("boyfriend", ps.boyfriend);
            set("dad", ps.dad);
            set("gf", ps.gf);
            set("stage", ps.currentStage);
            set("currentStage", ps.currentStage);
            set("camGame", ps.camGame);
            set("camHUD", ps.camHUD);
            set("camOther", ps.camOther);
            set("camControls", ps.camControls);
            set("playerStrumline", ps.playerStrumline);
            set("opponentStrumline", ps.opponentStrumline);
            set("playerStrums", (ps.playerStrumline != null) ? ps.playerStrumline.receptors : null);
            set("opponentStrums", (ps.opponentStrumline != null) ? ps.opponentStrumline.receptors : null);
            set("notes", ps.notes);
            set("sustainsGroup", ps.sustainsGroup);
            set("defaultCamZoom", ps.defaultCamZoom);
            set("defaultHUDZoom", ps.defaultHUDZoom);
            set("middlescroll", ps.middlescroll);
            set("downscroll", ps.downscroll);
            set("botplay", ps.botplay);
            set("health", ps.health);
        }
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
        if (!active) return null;

        set("curBeat", Conductor.curBeat);
        set("curStep", Conductor.curStep);
        set("songPosition", Conductor.songPosition);

        #if SOULSCORCH_IRIS
        if (iris != null) {
            try {
                if (!iris.exists(func)) return null;
                var fn = iris.get(func);
                if (fn == null || !Reflect.isFunction(fn)) return null;

                var result:Dynamic = (args != null && args.length > 0) ? iris.call(func, args) : iris.call(func);
                if (result != null) {
                    if (Reflect.hasField(result, "value")) return Reflect.field(result, "value");
                    if (Reflect.hasField(result, "val")) return Reflect.field(result, "val");
                    return result;
                }
                return null;
            } catch (e:Dynamic) {
                Logger.warn('Iris call warning in $func ($path): $e', "iris");
                return null;
            }
        }
        #else
        if (interp != null && interp.variables.exists(func)) {
            var fn = interp.variables.get(func);
            if (fn != null && Reflect.isFunction(fn)) {
                try {
                    return Reflect.callMethod(null, fn, (args != null) ? args : []);
                } catch (e:Dynamic) {
                    Logger.warn('HScript call warning in $func ($path): $e', "hscript");
                    return null;
                }
            }
        }
        #end
        return null;
    }

    public function set(key:String, value:Dynamic):Void {
        #if SOULSCORCH_IRIS
        if (iris != null) iris.set(key, value);
        #else
        if (interp != null) interp.variables.set(key, value);
        #end
    }

    public function get(key:String):Dynamic {
        #if SOULSCORCH_IRIS
        if (iris != null) return iris.get(key);
        #else
        if (interp != null && interp.variables.exists(key)) return interp.variables.get(key);
        #end
        if (customSprites.exists(key)) return customSprites.get(key);
        if (customTexts.exists(key)) return customTexts.get(key);
        return null;
    }

    public function destroy():Void {
        active = false;
        for (t in activeTweens) t.cancel();
        for (tm in activeTimers) tm.cancel();
        activeTweens.clear();
        activeTimers.clear();

        for (s in customSprites) s.destroy();
        for (txt in customTexts) txt.destroy();
        customSprites.clear();
        customTexts.clear();

        #if SOULSCORCH_IRIS
        if (iris != null) {
            iris.destroy();
            iris = null;
        }
        #else
        if (interp != null) {
            interp.variables.clear();
            interp = null;
        }
        #end
    }
}