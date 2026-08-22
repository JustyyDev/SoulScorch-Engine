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
    public var customSprites:Map<String, FlxSprite> = new Map<String, FlxSprite>();
    public var customTexts:Map<String, FlxText> = new Map<String, FlxText>();
    public var activeTweens:Map<String, FlxTween> = new Map<String, FlxTween>();
    public var activeTimers:Map<String, FlxTimer> = new Map<String, FlxTimer>();

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
            initScript(rawText, fullPath);

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

    private function initScript(code:String, fullPath:String):Void {
        var parsedCode = code;

        // Route transpilation strictly to .soul files
        if (fullPath.endsWith(".soul")) {
            var transpiled = SoulScriptParser.transpile(code);
            parsedCode = preprocessScript(transpiled);
        } else {
            parsedCode = preprocessScript(code);
        }

        var parser = new Parser();
        parser.allowTypes = false;
        parser.allowJSON = true;
        var program = parser.parseString(parsedCode);

        interp = new Interp();

        // Inject default integer literals to avoid parser identifier lookups
        for (i in 0...2000) {
            interp.variables.set(Std.string(i), i);
        }

        // ==========================================
        // Conductor, Timing & State Properties
        // ==========================================
        set("curBeat", Conductor.curBeat);
        set("curStep", Conductor.curStep);
        set("curDecBeat", Conductor.curDecBeat);
        set("curDecStep", Conductor.curDecStep);
        set("bpm", Conductor.bpm);
        set("crochet", Conductor.crochet);
        set("stepCrochet", Conductor.stepCrochet);
        set("songPosition", Conductor.songPosition);

        // ==========================================
        // Core Standard Libraries & Reflection
        // ==========================================
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

        // ==========================================
        // Flixel Core Framework & UI
        // ==========================================
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

        // ==========================================
        // Subsystems, Modding & Storage
        // ==========================================
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

        #if desktop
        set("Discord", soulscorch.backend.system.modules.discord.DiscordRPC);
        #end

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
        set("MainMenuState", MainMenuState);
        set("TitleState", TitleState);
        set("FreeplayState", FreeplayState);
        set("StoryMenuState", StoryMenuState);
        set("OptionsMenuState", OptionsMenuState);
        set("CreditsState", CreditsState);
        set("ModCustomState", ModCustomState);
        set("ScriptedState", ScriptedState);
        set("ScriptedSubState", ScriptedSubState);

        set("game", FlxG.state);
        set("state", FlxG.state);
        set("camera", FlxG.camera);
        set("cameras", FlxG.cameras);
        set("sound", FlxG.sound);
        set("keys", FlxG.keys);
        set("mouse", FlxG.mouse);
        set("defaultCamZoom", 1.0);
        set("PlayState", PlayState);

        // ==========================================
        // High-Level SoulScript Bridges & Shorthands
        // ==========================================

        // --- Custom Sprite & Text Instantiation ---
        set("makeSprite", function(tag:String, image:String, x:Float = 0, y:Float = 0, ?inFront:Bool = false) {
            var spr = new FlxSprite(x, y);
            if (image != null && image.trim().length > 0) {
                AssetHelper.loadGraphicSafely(spr, image);
            } else {
                spr.makeGraphic(64, 64, FlxColor.WHITE);
            }
            customSprites.set(tag, spr);
            if (FlxG.state != null) {
                if (inFront) FlxG.state.add(spr); else FlxG.state.insert(0, spr);
            }
            return spr;
        });

        set("makeAnimatedSprite", function(tag:String, image:String, x:Float = 0, y:Float = 0, ?inFront:Bool = false) {
            var spr = new FlxSprite(x, y);
            AssetHelper.loadSparrowSafely(spr, image);
            customSprites.set(tag, spr);
            if (FlxG.state != null) {
                if (inFront) FlxG.state.add(spr); else FlxG.state.insert(0, spr);
            }
            return spr;
        });

        set("makeText", function(tag:String, text:String, width:Float = 0, x:Float = 0, y:Float = 0, size:Int = 16, ?inFront:Bool = true) {
            var txt = new FlxText(x, y, width, text, size);
            txt.setFormat(Paths.font("vcr"), size, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
            txt.borderSize = 1.2;
            customTexts.set(tag, txt);
            if (FlxG.state != null) {
                if (inFront) FlxG.state.add(txt); else FlxG.state.insert(0, txt);
            }
            return txt;
        });

        set("getSprite", function(tag:String):Null<FlxSprite> {
            if (customSprites.exists(tag)) return customSprites.get(tag);
            if (uiElements.exists(tag)) return uiElements.get(tag);
            return null;
        });

        set("getText", function(tag:String):Null<FlxText> return customTexts.get(tag));

        set("removeObject", function(tag:String, destroy:Bool = true) {
            var spr = customSprites.get(tag);
            if (spr != null) {
                if (FlxG.state != null) FlxG.state.remove(spr, true);
                if (destroy) {
                    spr.destroy();
                    customSprites.remove(tag);
                }
                return;
            }
            var txt = customTexts.get(tag);
            if (txt != null) {
                if (FlxG.state != null) FlxG.state.remove(txt, true);
                if (destroy) {
                    txt.destroy();
                    customTexts.remove(tag);
                }
            }
        });

        // --- Note & Receptor Tweens ---
        set("noteTweenX", function(tag:String, lane:Int, targetX:Float, duration:Float, ?ease:String = "linear") {
            var receptor = getReceptorByLane(lane);
            if (receptor != null) {
                cancelScriptTween(tag);
                activeTweens.set(tag, FlxTween.tween(receptor, {x: targetX}, duration, {
                    ease: resolveEaseFunction(ease),
                    onComplete: function(_) activeTweens.remove(tag)
                }));
            }
        });

        set("noteTweenY", function(tag:String, lane:Int, targetY:Float, duration:Float, ?ease:String = "linear") {
            var receptor = getReceptorByLane(lane);
            if (receptor != null) {
                cancelScriptTween(tag);
                activeTweens.set(tag, FlxTween.tween(receptor, {y: targetY}, duration, {
                    ease: resolveEaseFunction(ease),
                    onComplete: function(_) activeTweens.remove(tag)
                }));
            }
        });

        set("noteTweenAngle", function(tag:String, lane:Int, targetAngle:Float, duration:Float, ?ease:String = "linear") {
            var receptor = getReceptorByLane(lane);
            if (receptor != null) {
                cancelScriptTween(tag);
                activeTweens.set(tag, FlxTween.tween(receptor, {angle: targetAngle}, duration, {
                    ease: resolveEaseFunction(ease),
                    onComplete: function(_) activeTweens.remove(tag)
                }));
            }
        });

        set("noteTweenAlpha", function(tag:String, lane:Int, targetAlpha:Float, duration:Float, ?ease:String = "linear") {
            var receptor = getReceptorByLane(lane);
            if (receptor != null) {
                cancelScriptTween(tag);
                activeTweens.set(tag, FlxTween.tween(receptor, {alpha: targetAlpha}, duration, {
                    ease: resolveEaseFunction(ease),
                    onComplete: function(_) activeTweens.remove(tag)
                }));
            }
        });

        // --- Character Animation & Camera Actions ---
        set("characterPlayAnim", function(character:String, animName:String, force:Bool = true) {
            if (PlayState.instance == null) return;
            switch (character.toLowerCase().trim()) {
                case "dad" | "opponent": if (PlayState.instance.dad != null) PlayState.instance.dad.playAnim(animName, force);
                case "bf" | "boyfriend" | "player": if (PlayState.instance.boyfriend != null) PlayState.instance.boyfriend.playAnim(animName, force);
                case "gf" | "girlfriend": if (PlayState.instance.gf != null) PlayState.instance.gf.playAnim(animName, force);
            }
        });

        set("characterDance", function(character:String) {
            if (PlayState.instance == null) return;
            switch (character.toLowerCase().trim()) {
                case "dad" | "opponent": if (PlayState.instance.dad != null) PlayState.instance.dad.dance();
                case "bf" | "boyfriend" | "player": if (PlayState.instance.boyfriend != null) PlayState.instance.boyfriend.dance();
                case "gf" | "girlfriend": if (PlayState.instance.gf != null) PlayState.instance.gf.dance();
            }
        });

        set("cameraFocus", function(character:String) {
            if (PlayState.instance == null) return;
            switch (character.toLowerCase().trim()) {
                case "dad" | "opponent":
                    if (PlayState.instance.dad != null && PlayState.instance.camFollow != null) {
                        PlayState.instance.camFollow.setPosition(
                            PlayState.instance.dad.getMidpoint().x + 150 + PlayState.instance.dad.cameraOffset[0],
                            PlayState.instance.dad.getMidpoint().y - 100 + PlayState.instance.dad.cameraOffset[1]
                        );
                    }
                case "bf" | "boyfriend" | "player":
                    if (PlayState.instance.boyfriend != null && PlayState.instance.camFollow != null) {
                        PlayState.instance.camFollow.setPosition(
                            PlayState.instance.boyfriend.getMidpoint().x - 100 + PlayState.instance.boyfriend.cameraOffset[0],
                            PlayState.instance.boyfriend.getMidpoint().y - 100 + PlayState.instance.boyfriend.cameraOffset[1]
                        );
                    }
                case "gf" | "girlfriend":
                    if (PlayState.instance.gf != null && PlayState.instance.camFollow != null) {
                        PlayState.instance.camFollow.setPosition(
                            PlayState.instance.gf.getMidpoint().x + PlayState.instance.gf.cameraOffset[0],
                            PlayState.instance.gf.getMidpoint().y + PlayState.instance.gf.cameraOffset[1]
                        );
                    }
            }
        });

        // --- Song Events & Modifiers ---
        set("triggerEvent", function(eventName:String, val1:Dynamic, val2:Dynamic) {
            if (PlayState.instance != null) {
                PlayState.instance.triggerEvent(eventName, val1, val2);
            }
        });

        set("setHealth", function(value:Float) {
            if (PlayState.instance != null) PlayState.instance.health = value;
        });

        set("getHealth", function():Float {
            return (PlayState.instance != null) ? PlayState.instance.health : 1.0;
        });

        set("addScore", function(score:Int) {
            if (PlayState.instance != null) PlayState.instance.songScore += score;
        });

        set("addMisses", function(misses:Int) {
            if (PlayState.instance != null) PlayState.instance.songMisses += misses;
        });

        // --- Shaders & FX ---
        set("setShaderFloat", function(shaderName:String, uniform:String, value:Float) {
            var s = ShaderManager.instance.getShader(shaderName);
            if (s != null) s.setFloat(uniform, value);
        });

        set("setShaderBool", function(shaderName:String, uniform:String, value:Bool) {
            var s = ShaderManager.instance.getShader(shaderName);
            if (s != null) s.setBool(uniform, value);
        });

        set("cameraShake", function(camName:String, intensity:Float, duration:Float) {
            var cam = resolveCamera(camName);
            if (cam != null) cam.shake(intensity, duration);
        });

        set("cameraFlash", function(camName:String, colorStr:String, duration:Float) {
            var cam = resolveCamera(camName);
            if (cam != null) cam.flash(FlxColor.fromString(colorStr), duration);
        });

        // --- Tween Management & Interpolation ---
        set("tweenProperty", function(tag:String, target:Dynamic, property:String, toValue:Float, duration:Float, ?ease:String = "linear") {
            if (target == null) return;
            cancelScriptTween(tag);
            var tweenProps:Dynamic = {};
            Reflect.setField(tweenProps, property, toValue);
            activeTweens.set(tag, FlxTween.tween(target, tweenProps, duration, {
                ease: resolveEaseFunction(ease),
                onComplete: function(_) activeTweens.remove(tag)
            }));
        });

        set("cancelTween", cancelScriptTween);

        // --- Timers ---
        set("startTimer", function(tag:String, duration:Float, callback:Void->Void, ?loops:Int = 1) {
            if (activeTimers.exists(tag)) {
                activeTimers.get(tag).cancel();
                activeTimers.remove(tag);
            }
            activeTimers.set(tag, new FlxTimer().start(duration, function(_) {
                if (callback != null) callback();
            }, loops));
        });

        set("cancelTimer", function(tag:String) {
            if (activeTimers.exists(tag)) {
                activeTimers.get(tag).cancel();
                activeTimers.remove(tag);
            }
        });

        // --- Audio Controls ---
        set("playSound", function(soundPath:String, volume:Float = 1.0) {
            AssetHelper.playSoundSafely(soundPath, volume);
        });

        set("playMusic", function(musicPath:String, volume:Float = 1.0, loop:Bool = true) {
            FlxG.sound.playMusic(Paths.music(musicPath), volume, loop);
        });

        // --- General Utilities ---
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
                if (redirect != null && redirect != targetName) {
                    MusicBeatState.switchState(new ModCustomState(redirect));
                } else {
                    switch (targetName.toLowerCase().trim()) {
                        case "mainmenustate" | "mainmenu": MusicBeatState.switchState(new MainMenuState());
                        case "titlestate" | "title": MusicBeatState.switchState(new TitleState());
                        case "freeplaystate" | "freeplay": MusicBeatState.switchState(new FreeplayState());
                        case "storymenustate" | "storymenu": MusicBeatState.switchState(new StoryMenuState());
                        case "optionsstate" | "optionsmenustate" | "options": MusicBeatState.switchState(new OptionsMenuState());
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

    private function getReceptorByLane(lane:Int):Null<StrumArrow> {
        if (PlayState.instance == null) return null;
        if (lane < 4 && PlayState.instance.opponentStrumline != null && PlayState.instance.opponentStrumline.receptors.length > lane) {
            return PlayState.instance.opponentStrumline.receptors[lane];
        } else if (lane >= 4 && PlayState.instance.playerStrumline != null && PlayState.instance.playerStrumline.receptors.length > (lane - 4)) {
            return PlayState.instance.playerStrumline.receptors[lane - 4];
        }
        return null;
    }

    private function resolveCamera(cameraName:String):FlxCamera {
        if (cameraName == null) return FlxG.camera;
        return switch (cameraName.toLowerCase().trim()) {
            case "hud" | "camhud": (PlayState.instance != null) ? PlayState.instance.camHUD : FlxG.camera;
            case "other" | "camother": (PlayState.instance != null) ? PlayState.instance.camOther : FlxG.camera;
            case "controls" | "camcontrols": (PlayState.instance != null) ? PlayState.instance.camControls : FlxG.camera;
            default: FlxG.camera;
        };
    }

    private function cancelScriptTween(tag:String):Void {
        if (activeTweens.exists(tag)) {
            activeTweens.get(tag).cancel();
            activeTweens.remove(tag);
        }
    }

    private function resolveEaseFunction(ease:String):flixel.tweens.FlxEase.EaseFunction {
        return switch (ease.toLowerCase().trim()) {
            case "sinein": FlxEase.sineIn;
            case "sineout": FlxEase.sineOut;
            case "sineinout": FlxEase.sineInOut;
            case "quadin": FlxEase.quadIn;
            case "quadout": FlxEase.quadOut;
            case "quadinout": FlxEase.quadInOut;
            case "cubein": FlxEase.cubeIn;
            case "cubeout": FlxEase.cubeOut;
            case "cubeinout": FlxEase.cubeInOut;
            case "quartin": FlxEase.quartIn;
            case "quartout": FlxEase.quartOut;
            case "quartinout": FlxEase.quartInOut;
            case "quintin": FlxEase.quintIn;
            case "quintout": FlxEase.quintOut;
            case "quintinout": FlxEase.quintInOut;
            case "expoin": FlxEase.expoIn;
            case "expoout": FlxEase.expoOut;
            case "expoinout": FlxEase.expoInOut;
            case "circin": FlxEase.circIn;
            case "circout": FlxEase.circOut;
            case "circinout": FlxEase.circInOut;
            case "backin": FlxEase.backIn;
            case "backout": FlxEase.backOut;
            case "backinout": FlxEase.backInOut;
            case "elasticin": FlxEase.elasticIn;
            case "elasticout": FlxEase.elasticOut;
            case "elasticinout": FlxEase.elasticInOut;
            case "bouncein": FlxEase.bounceIn;
            case "bounceout": FlxEase.bounceOut;
            case "bounceinout": FlxEase.bounceInOut;
            default: FlxEase.linear;
        };
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
            set("curBeat", Conductor.curBeat);
            set("curStep", Conductor.curStep);
            set("curDecBeat", Conductor.curDecBeat);
            set("curDecStep", Conductor.curDecStep);
            set("bpm", Conductor.bpm);
            set("crochet", Conductor.crochet);
            set("stepCrochet", Conductor.stepCrochet);
            set("songPosition", Conductor.songPosition);

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
        if (customSprites.exists(key)) return customSprites.get(key);
        if (customTexts.exists(key)) return customTexts.get(key);
        if (uiElements.exists(key)) return uiElements.get(key);
        return null;
    }

    public function destroy():Void {
        active = false;
        call("onDestroy", []);

        for (t in activeTweens) t.cancel();
        for (tm in activeTimers) tm.cancel();
        activeTweens.clear();
        activeTimers.clear();

        for (s in customSprites) s.destroy();
        for (txt in customTexts) txt.destroy();
        customSprites.clear();
        customTexts.clear();
        uiElements.clear();

        if (interp != null) {
            interp.variables.clear();
            interp = null;
        }
    }
}