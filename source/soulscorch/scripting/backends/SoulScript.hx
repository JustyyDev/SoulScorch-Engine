package soulscorch.scripting.backends;

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
import hscript.Interp;
import hscript.Parser;
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
import soulscorch.scripting.ScriptedState;
import soulscorch.scripting.ScriptedSubState;
import soulscorch.scripting.mod.ModCustomState;
import soulscorch.scripting.mod.ModLoader;
import soulscorch.scripting.mod.ModManager;
import soulscorch.scripting.mod.SoulGlobalScript;
import soulscorch.scripting.soul.SoulScriptParser;
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

class SoulScript implements ScriptInstance {
    public var active:Bool = false;
    public var path(default, null):String;

    public var uiElements:Map<String, FlxSprite> = new Map<String, FlxSprite>();
    private var interp:Interp;

    public function new(scriptPath:String) {
        this.path = (scriptPath == null) ? "" : scriptPath;
        load();
    }

    public function load():Bool {
        var fullPath = ModManager.getPath(path);
        if (!AssetResolver.exists(fullPath)) {
            active = false;
            return false;
        }

        try {
            var rawText = AssetResolver.getText(fullPath);
            initScript(rawText);
            
            var xmlPath = fullPath.substr(0, fullPath.lastIndexOf(".")) + ".xml";
            if (AssetResolver.exists(xmlPath)) {
                parseXML(AssetResolver.getText(xmlPath));
            }

            active = true;
            return true;
        } catch (e:Dynamic) {
            Logger.error('Failed to initialize SoulScript ($path): $e', "soulscript");
            active = false;
            return false;
        }
    }

    private function initScript(code:String):Void {
        var transpiled = SoulScriptParser.transpile(code);
        var sanitized = preprocessScript(transpiled);
        
        var parser = new Parser();
        parser.allowTypes = false;
        parser.allowJSON = true;
        var program = parser.parseString(sanitized);

        interp = new Interp();

        // 1. Timing & Conductor Variables (Default setup to prevent EUnknownVariable on init)
        set("curBeat", 0);
        set("curStep", 0);
        set("curDecBeat", 0.0);
        set("curDecStep", 0.0);
        set("bpm", Conductor.bpm);
        set("crochet", Conductor.crochet);
        set("stepCrochet", Conductor.stepCrochet);

        // 2. Core Haxe & Reflection
        set("Std", Std);
        set("Math", Math);
        set("StringTools", StringTools);
        set("Reflect", Reflect);
        set("Type", Type);
        set("Date", Date);
        set("DateTools", DateTools);
        set("Xml", Xml);
        set("Json", haxe.Json);

        // 3. Native System & I/O
        #if sys
        set("Sys", Sys);
        set("File", sys.io.File);
        set("FileSystem", sys.FileSystem);
        set("Process", sys.io.Process);
        #end

        // 4. Native OS API & Windowing
        set("NativeAPI", NativeAPI);
        set("FileSystemAPI", FileSystemAPI);
        set("openfl", {Lib: openfl.Lib});
        set("Lib", openfl.Lib);
        set("Application", lime.app.Application);
        set("window", (openfl.Lib.application != null) ? openfl.Lib.application.window : null);
        set("stage", openfl.Lib.current.stage);
        set("Controls", Controls.instance);
        set("controls", Controls.instance);

        // 5. Flixel Core & Geometry
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
        set("FlxPoint", {get: FlxPoint.get, weak: FlxPoint.weak});
        set("FlxRect", {get: FlxRect.get});

        // 6. Flx Groups, Containers & Objects
        set("FlxGroup", FlxGroup);
        set("FlxTypedGroup", FlxTypedGroup);
        set("FlxSpriteGroup", FlxSpriteGroup);

        // 7. Flx Tweens, Eases & Timers
        set("FlxTween", FlxTween);
        set("FlxEase", FlxEase);
        set("FlxTimer", FlxTimer);
        set("FlxSort", FlxSort);

        // 8. Flx Math & Physics
        set("FlxMath", FlxMath);
        set("FlxVelocity", FlxVelocity);
        set("FlxAngle", FlxAngle);

        // 9. Audio & Visuals
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

        set("BlendMode", {
            NORMAL: BlendMode.NORMAL,
            ADD: BlendMode.ADD,
            MULTIPLY: BlendMode.MULTIPLY,
            SCREEN: BlendMode.SCREEN,
            DARKEN: BlendMode.DARKEN,
            LIGHTEN: BlendMode.LIGHTEN,
            OVERLAY: BlendMode.OVERLAY,
            HARDLIGHT: BlendMode.HARDLIGHT,
            SUBTRACT: BlendMode.SUBTRACT,
            DIFFERENCE: BlendMode.DIFFERENCE,
            INVERT: BlendMode.INVERT,
            ALPHA: BlendMode.ALPHA,
            ERASE: BlendMode.ERASE,
            LAYER: BlendMode.LAYER
        });

        set("Matrix", Matrix);
        set("URLRequest", URLRequest);

        // 10. Engine Subsystems
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
        set("Framerate", Framerate);
        set("GameConfig", GameConfig);
        set("CrashHandler", CrashHandler);

        #if desktop
        set("Discord", soulscorch.backend.system.modules.discord.DiscordRPC);
        #end

        // 11. 3D Rendering & Shaders
        set("Away3DManager", Away3DManager);
        set("ModelAPI", ModelAPI);
        set("JuiceManager", JuiceManager);
        set("SoulShader", SoulShader);
        set("ShaderManager", ShaderManager.instance);

        set("ShaderFilter", function(shaderOrFilter:Dynamic) {
            if (Std.isOfType(shaderOrFilter, ShaderFilter)) {
                return shaderOrFilter;
            } else if (Std.isOfType(shaderOrFilter, SoulShader)) {
                var s:SoulShader = cast shaderOrFilter;
                return s.filter;
            } else if (Std.isOfType(shaderOrFilter, flixel.system.FlxAssets.FlxShader)) {
                return new ShaderFilter(cast shaderOrFilter);
            }
            return null;
        });

        // 12. Gameplay Actors, Notes & Charting
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

        // 13. UI & Menus
        set("MusicBeatState", MusicBeatState);
        set("ResultsState", ResultsState);
        set("GameOverSubState", GameOverSubState);
        set("PauseSubState", PauseSubState);
        set("MainMenuState", MainMenuState);
        set("TitleState", TitleState);
        set("FreeplayState", FreeplayState);
        set("StoryMenuState", StoryMenuState);
        set("OptionsMenuState", OptionsMenuState);
        set("CreditsState", CreditsState);
        set("ModCustomState", ModCustomState);
        set("ScriptedState", ScriptedState);
        set("ScriptedSubState", ScriptedSubState);

        // 14. Live Context Hooks
        set("game", FlxG.state);
        set("state", FlxG.state);
        set("camera", FlxG.camera);
        set("cameras", FlxG.cameras);
        set("sound", FlxG.sound);
        set("keys", FlxG.keys);
        set("mouse", FlxG.mouse);
        set("defaultCamZoom", 1.0);
        set("PlayState", PlayState);

        // 15. Utility Functions
        set("lerp", function(a:Float, b:Float, ratio:Float):Float return FlxMath.lerp(a, b, ratio));
        set("getElement", function(id:String):Null<FlxSprite> return uiElements.get(id));
        set("trace", function(v:Dynamic):Void Logger.info(Std.string(v), "soulscript"));
        set("log", function(v:Dynamic):Void Logger.info(Std.string(v), "soulscript"));

        set("add", function(obj:Dynamic):Void {
            if (FlxG.state != null) FlxG.state.add(obj);
        });

        set("remove", function(obj:Dynamic):Void {
            if (FlxG.state != null) FlxG.state.remove(obj);
        });

        set("insert", function(idx:Int, obj:Dynamic):Void {
            if (FlxG.state != null) FlxG.state.insert(idx, obj);
        });

        set("openURL", function(url:String):Void {
            #if linux Sys.command("xdg-open", [url]);
            #else Lib.getURL(new URLRequest(url)); #end
        });

        set("switchState", function(target:Dynamic):Void {
            if (Std.isOfType(target, String)) {
                var targetName:String = cast target;
                var redirect = SoulGlobalScript.getRedirect(targetName);
                if (redirect != null) {
                    MusicBeatState.switchState(new ModCustomState(redirect));
                } else {
                    switch (targetName.toLowerCase()) {
                        case "mainmenustate" | "mainmenu": MusicBeatState.switchState(new MainMenuState());
                        case "titlestate" | "title": MusicBeatState.switchState(new TitleState());
                        case "freeplaystate" | "freeplay": MusicBeatState.switchState(new FreeplayState());
                        case "storymenustate" | "storymenu": MusicBeatState.switchState(new StoryMenuState());
                        case "optionsstate" | "optionsmenustate": MusicBeatState.switchState(new OptionsMenuState());
                        case "creditsstate" | "credits": MusicBeatState.switchState(new CreditsState());
                        default: MusicBeatState.switchState(new ScriptedState(targetName));
                    }
                }
            } else {
                MusicBeatState.switchState(target);
            }
        });

        set("importClass", function(className:String):Bool {
            return importClass(className);
        });

        set("createInstance", function(className:String, args:Array<Dynamic>):Dynamic {
            var cl = Type.resolveClass(className);
            if (cl != null) return Type.createInstance(cl, args != null ? args : []);
            return null;
        });

        interp.execute(program);
    }

    public function importClass(className:String):Bool {
        if (interp == null || className == null) return false;
        var resolvedClass:Dynamic = Type.resolveClass(className);
        if (resolvedClass == null) resolvedClass = Type.resolveEnum(className);

        if (resolvedClass != null) {
            var shortName:String = className.substr(className.lastIndexOf(".") + 1);
            set(shortName, resolvedClass);
            return true;
        }
        return false;
    }

    private function preprocessScript(code:String):String {
        var rPackage = ~/package\s+[\w\.]*;/g;
        code = rPackage.replace(code, "");

        var rImport = ~/import\s+[\w\.\*]+;/g;
        code = rImport.replace(code, "");

        var rModifiers = ~/\b(public|private|static|override)\s+(var|function)\b/g;
        code = rModifiers.replace(code, "$2");

        return code;
    }

    private function parseXML(rawXml:String):Void {
        if (rawXml.length == 0) return;
        try {
            var xml = Xml.parse(rawXml).firstElement();
            if (xml.get("bgColor") != null) {
                var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.fromString(xml.get("bgColor")));
                bg.scrollFactor.set();
                if (FlxG.state != null) FlxG.state.add(bg);
            }

            for (node in xml.elements()) {
                var nodeName = node.nodeName.toLowerCase();
                var id = node.get("id");
                var xPos = (node.get("x") != null) ? Std.parseFloat(node.get("x")) : 0.0;
                var yPos = (node.get("y") != null) ? Std.parseFloat(node.get("y")) : 0.0;
                var scaleVal = (node.get("scale") != null) ? Std.parseFloat(node.get("scale")) : 1.0;
                var alphaVal = (node.get("alpha") != null) ? Std.parseFloat(node.get("alpha")) : 1.0;

                switch (nodeName) {
                    case "sprite":
                        var spr = new FlxSprite(xPos, yPos);
                        var img = node.get("image");
                        if (img != null) AssetHelper.loadImageSafely(spr, img);
                        spr.scale.set(scaleVal, scaleVal);
                        spr.updateHitbox();
                        spr.alpha = alphaVal;
                        if (id != null) uiElements.set(id, spr);
                        if (FlxG.state != null) FlxG.state.add(spr);

                    case "text":
                        var content = (node.get("content") != null) ? node.get("content") : "";
                        var size = (node.get("size") != null) ? Std.parseInt(node.get("size")) : 16;
                        var width = (node.get("width") != null) ? Std.parseFloat(node.get("width")) : 0;
                        var txt = new FlxText(xPos, yPos, width, content, size);
                        var col = (node.get("color") != null) ? FlxColor.fromString(node.get("color")) : FlxColor.WHITE;
                        txt.setFormat(Paths.font("vcr"), size, col, LEFT);
                        txt.alpha = alphaVal;
                        if (id != null) uiElements.set(id, txt);
                        if (FlxG.state != null) FlxG.state.add(txt);

                    case "button":
                        var w = (node.get("width") != null) ? Std.parseInt(node.get("width")) : 100;
                        var h = (node.get("height") != null) ? Std.parseInt(node.get("height")) : 40;
                        var onClickName = node.get("onClick");

                        var btn = new FlxButton(xPos, yPos, "", function() {
                            if (onClickName != null) call(onClickName, []);
                        });
                        btn.makeGraphic(w, h, FlxColor.TRANSPARENT);
                        btn.alpha = alphaVal;
                        if (id != null) uiElements.set(id, btn);
                        if (FlxG.state != null) FlxG.state.add(btn);
                }
            }
        } catch (e:Dynamic) {
            Logger.error('SoulScript XML layout parsing error: $e', "soulscript");
        }
    }

    public function call(func:String, ?args:Array<Dynamic>):Dynamic {
        if (interp != null) {
            // Keep step and beat variables in sync with Conductor statically
            set("curBeat", Conductor.curBeat);
            set("curStep", Conductor.curStep);
            set("curDecBeat", Conductor.curDecBeat);
            set("curDecStep", Conductor.curDecStep);
            set("bpm", Conductor.bpm);
            set("crochet", Conductor.crochet);
            set("stepCrochet", Conductor.stepCrochet);

            if (interp.variables.exists(func)) {
                var fn = interp.variables.get(func);
                if (Reflect.isFunction(fn)) {
                    return Reflect.callMethod(null, fn, (args != null) ? args : []);
                }
            }
        }
        return null;
    }

    public function set(key:String, value:Dynamic):Void {
        if (interp != null) interp.variables.set(key, value);
    }

    public function get(key:String):Dynamic {
        if (interp != null && interp.variables.exists(key)) return interp.variables.get(key);
        if (uiElements.exists(key)) return uiElements.get(key);
        return null;
    }

    public function destroy():Void {
        active = false;
        call("onDestroy", []);
        uiElements.clear();
        if (interp != null) {
            interp.variables.clear();
            interp = null;
        }
    }
}