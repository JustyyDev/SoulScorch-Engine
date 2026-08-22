package soulscorch.scripting.backends;

import crowplexus.iris.Iris;
import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
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

    private var iris:Iris;

    public function new(scriptPath:String, ?customCode:String) {
        this.path = (scriptPath == null) ? "" : scriptPath;
        
        var code:String = customCode;
        #if sys
        if (code == null && path != "" && FileSystem.exists(path)) {
            code = File.getContent(path);
        }
        #end

        if (code != null) {
            this.iris = new Iris(code, {name: path, autoRun: false});
            presetEnvironment();
            load();
        }
    }

    public function load():Bool {
        if (iris == null) return false;
        try {
            iris.execute();
            active = true;
        } catch (e:Dynamic) {
            Logger.error('Failed to execute Iris script ($path): $e', "iris");
            active = false;
        }
        return active;
    }

    private function presetEnvironment():Void {
        if (iris == null) return;

        // Conductor & Song Timing
        iris.set("curBeat", Conductor.curBeat);
        iris.set("curStep", Conductor.curStep);
        iris.set("curDecBeat", Conductor.curDecBeat);
        iris.set("curDecStep", Conductor.curDecStep);
        iris.set("bpm", Conductor.bpm);
        iris.set("crochet", Conductor.crochet);
        iris.set("stepCrochet", Conductor.stepCrochet);
        iris.set("songPosition", Conductor.songPosition);

        // Core Types & Reflection
        iris.set("Std", Std);
        iris.set("Math", Math);
        iris.set("StringTools", StringTools);
        iris.set("Reflect", Reflect);
        iris.set("Type", Type);
        iris.set("Date", Date);
        iris.set("DateTools", DateTools);
        iris.set("Xml", Xml);
        iris.set("Json", haxe.Json);

        #if sys
        iris.set("Sys", Sys);
        iris.set("File", sys.io.File);
        iris.set("FileSystem", sys.FileSystem);
        iris.set("Process", sys.io.Process);
        #end

        iris.set("NativeAPI", NativeAPI);
        iris.set("FileSystemAPI", FileSystemAPI);
        iris.set("openfl", {Lib: openfl.Lib});
        iris.set("Lib", openfl.Lib);
        iris.set("Application", lime.app.Application);
        iris.set("window", (openfl.Lib.application != null) ? openfl.Lib.application.window : null);
        iris.set("stage", openfl.Lib.current.stage);
        iris.set("Controls", Controls.instance);
        iris.set("controls", Controls.instance);

        // Flixel Display & Containers
        iris.set("FlxG", FlxG);
        iris.set("FlxSprite", FlxSprite);
        iris.set("FlxCamera", FlxCamera);
        iris.set("FlxText", FlxText);
        iris.set("FlxObject", FlxObject);
        iris.set("FlxState", FlxState);
        iris.set("FlxSubState", FlxSubState);
        iris.set("FlxBasic", FlxBasic);
        iris.set("FlxBar", FlxBar);
        iris.set("FlxButton", FlxButton);
        iris.set("FlxBackdrop", FlxBackdrop);
        iris.set("FlxGridOverlay", FlxGridOverlay);
        iris.set("FlxPoint", {get: FlxPoint.get, weak: FlxPoint.weak});
        iris.set("FlxRect", {get: FlxRect.get});

        iris.set("FlxGroup", FlxGroup);
        iris.set("FlxTypedGroup", FlxTypedGroup);
        iris.set("FlxSpriteGroup", FlxSpriteGroup);

        iris.set("FlxTween", FlxTween);
        iris.set("FlxEase", FlxEase);
        iris.set("FlxTimer", FlxTimer);
        iris.set("FlxSort", FlxSort);

        iris.set("FlxMath", FlxMath);
        iris.set("FlxVelocity", FlxVelocity);
        iris.set("FlxAngle", FlxAngle);

        iris.set("FlxSound", FlxSound);
        iris.set("FlxTrail", FlxTrail);

        iris.set("FlxColor", {
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

        iris.set("BlendMode", {
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

        iris.set("Matrix", Matrix);
        iris.set("URLRequest", URLRequest);

        // Architecture & Subsystems
        iris.set("Runtime", Runtime);
        iris.set("Engine", Engine);
        iris.set("Version", Version);
        iris.set("Conductor", Conductor);
        iris.set("Paths", Paths);
        iris.set("EventBus", EventBus);
        iris.set("Logger", Logger);
        iris.set("ModLoader", ModLoader);
        iris.set("ModManager", ModManager);
        iris.set("XMSoul", XMSoul);
        iris.set("SaveData", SaveData.instance);
        iris.set("EngineOptimizer", EngineOptimizer);
        iris.set("HotReloader", HotReloader);
        iris.set("DevConsole", DevConsole);
        iris.set("AssetResolver", AssetResolver);
        iris.set("AssetHelper", AssetHelper);
        iris.set("AudioManager", AudioManager);
        iris.set("Framerate", Framerate);
        iris.set("GameConfig", GameConfig);
        iris.set("CrashHandler", CrashHandler);

        #if desktop
        iris.set("Discord", soulscorch.backend.system.modules.discord.DiscordRPC);
        #end

        iris.set("Away3DManager", Away3DManager);
        iris.set("ModelAPI", ModelAPI);
        iris.set("JuiceManager", JuiceManager);
        iris.set("SoulShader", SoulShader);
        iris.set("ShaderManager", ShaderManager.instance);

        iris.set("ShaderFilter", function(shaderOrFilter:Dynamic) {
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

        // Gameplay Elements
        iris.set("Character", Character);
        iris.set("HealthIcon", HealthIcon);
        iris.set("Note", Note);
        iris.set("Strumline", Strumline);
        iris.set("StrumArrow", StrumArrow);
        iris.set("NoteSplash", NoteSplash);
        iris.set("NoteSkinManager", NoteSkinManager);
        iris.set("Stage", Stage);
        iris.set("GameplayFlags", GameplayFlags);
        iris.set("JudgementManager", JudgementManager);
        iris.set("ModchartManager", ModchartManager);

        iris.set("MusicBeatState", MusicBeatState);
        iris.set("ResultsState", ResultsState);
        iris.set("GameOverSubState", GameOverSubState);
        iris.set("PauseSubState", PauseSubState);
        iris.set("MainMenuState", MainMenuState);
        iris.set("TitleState", TitleState);
        iris.set("FreeplayState", FreeplayState);
        iris.set("StoryMenuState", StoryMenuState);
        iris.set("OptionsMenuState", OptionsMenuState);
        iris.set("CreditsState", CreditsState);
        iris.set("ModCustomState", ModCustomState);
        iris.set("ScriptedState", ScriptedState);
        iris.set("ScriptedSubState", ScriptedSubState);

        iris.set("game", FlxG.state);
        iris.set("state", FlxG.state);
        iris.set("camera", FlxG.camera);
        iris.set("cameras", FlxG.cameras);
        iris.set("sound", FlxG.sound);
        iris.set("keys", FlxG.keys);
        iris.set("mouse", FlxG.mouse);
        iris.set("defaultCamZoom", 1.0);
        iris.set("PlayState", PlayState);

        // --- Custom Sprite & Text Helpers ---
        iris.set("makeSprite", function(tag:String, image:String, x:Float = 0, y:Float = 0, ?inFront:Bool = false) {
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

        iris.set("makeAnimatedSprite", function(tag:String, image:String, x:Float = 0, y:Float = 0, ?inFront:Bool = false) {
            var spr = new FlxSprite(x, y);
            AssetHelper.loadSparrowSafely(spr, image);
            customSprites.set(tag, spr);
            if (FlxG.state != null) {
                if (inFront) FlxG.state.add(spr); else FlxG.state.insert(0, spr);
            }
            return spr;
        });

        iris.set("makeText", function(tag:String, text:String, width:Float = 0, x:Float = 0, y:Float = 0, size:Int = 16, ?inFront:Bool = true) {
            var txt = new FlxText(x, y, width, text, size);
            txt.setFormat(Paths.font("vcr"), size, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
            txt.borderSize = 1.2;
            customTexts.set(tag, txt);
            if (FlxG.state != null) {
                if (inFront) FlxG.state.add(txt); else FlxG.state.insert(0, txt);
            }
            return txt;
        });

        iris.set("getSprite", function(tag:String):Null<FlxSprite> return customSprites.get(tag));
        iris.set("getText", function(tag:String):Null<FlxText> return customTexts.get(tag));

        iris.set("removeObject", function(tag:String, destroy:Bool = true) {
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
        iris.set("noteTweenX", function(tag:String, lane:Int, targetX:Float, duration:Float, ?ease:String = "linear") {
            var receptor = getReceptorByLane(lane);
            if (receptor != null) {
                cancelScriptTween(tag);
                activeTweens.set(tag, FlxTween.tween(receptor, {x: targetX}, duration, {
                    ease: resolveEaseFunction(ease),
                    onComplete: function(_) activeTweens.remove(tag)
                }));
            }
        });

        iris.set("noteTweenY", function(tag:String, lane:Int, targetY:Float, duration:Float, ?ease:String = "linear") {
            var receptor = getReceptorByLane(lane);
            if (receptor != null) {
                cancelScriptTween(tag);
                activeTweens.set(tag, FlxTween.tween(receptor, {y: targetY}, duration, {
                    ease: resolveEaseFunction(ease),
                    onComplete: function(_) activeTweens.remove(tag)
                }));
            }
        });

        iris.set("noteTweenAngle", function(tag:String, lane:Int, targetAngle:Float, duration:Float, ?ease:String = "linear") {
            var receptor = getReceptorByLane(lane);
            if (receptor != null) {
                cancelScriptTween(tag);
                activeTweens.set(tag, FlxTween.tween(receptor, {angle: targetAngle}, duration, {
                    ease: resolveEaseFunction(ease),
                    onComplete: function(_) activeTweens.remove(tag)
                }));
            }
        });

        iris.set("noteTweenAlpha", function(tag:String, lane:Int, targetAlpha:Float, duration:Float, ?ease:String = "linear") {
            var receptor = getReceptorByLane(lane);
            if (receptor != null) {
                cancelScriptTween(tag);
                activeTweens.set(tag, FlxTween.tween(receptor, {alpha: targetAlpha}, duration, {
                    ease: resolveEaseFunction(ease),
                    onComplete: function(_) activeTweens.remove(tag)
                }));
            }
        });

        // --- Character Actions & Cameras ---
        iris.set("characterPlayAnim", function(character:String, animName:String, force:Bool = true) {
            if (PlayState.instance == null) return;
            switch (character.toLowerCase().trim()) {
                case "dad" | "opponent": if (PlayState.instance.dad != null) PlayState.instance.dad.playAnim(animName, force);
                case "bf" | "boyfriend" | "player": if (PlayState.instance.boyfriend != null) PlayState.instance.boyfriend.playAnim(animName, force);
                case "gf" | "girlfriend": if (PlayState.instance.gf != null) PlayState.instance.gf.playAnim(animName, force);
            }
        });

        iris.set("characterDance", function(character:String) {
            if (PlayState.instance == null) return;
            switch (character.toLowerCase().trim()) {
                case "dad" | "opponent": if (PlayState.instance.dad != null) PlayState.instance.dad.dance();
                case "bf" | "boyfriend" | "player": if (PlayState.instance.boyfriend != null) PlayState.instance.boyfriend.dance();
                case "gf" | "girlfriend": if (PlayState.instance.gf != null) PlayState.instance.gf.dance();
            }
        });

        iris.set("cameraFocus", function(character:String) {
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

        // --- Song Events & Health ---
        iris.set("triggerEvent", function(eventName:String, val1:Dynamic, val2:Dynamic) {
            if (PlayState.instance != null) PlayState.instance.triggerEvent(eventName, val1, val2);
        });

        iris.set("setHealth", function(value:Float) {
            if (PlayState.instance != null) PlayState.instance.health = value;
        });

        iris.set("getHealth", function():Float {
            return (PlayState.instance != null) ? PlayState.instance.health : 1.0;
        });

        // --- Shaders & FX ---
        iris.set("setShaderFloat", function(shaderName:String, uniform:String, value:Float) {
            var s = ShaderManager.instance.getShader(shaderName);
            if (s != null) s.setFloat(uniform, value);
        });

        iris.set("setShaderBool", function(shaderName:String, uniform:String, value:Bool) {
            var s = ShaderManager.instance.getShader(shaderName);
            if (s != null) s.setBool(uniform, value);
        });

        iris.set("cameraShake", function(camName:String, intensity:Float, duration:Float) {
            var cam = resolveCamera(camName);
            if (cam != null) cam.shake(intensity, duration);
        });

        iris.set("cameraFlash", function(camName:String, colorStr:String, duration:Float) {
            var cam = resolveCamera(camName);
            if (cam != null) cam.flash(FlxColor.fromString(colorStr), duration);
        });

        // --- Tweens & Timers ---
        iris.set("tweenProperty", function(tag:String, target:Dynamic, property:String, toValue:Float, duration:Float, ?ease:String = "linear") {
            if (target == null) return;
            cancelScriptTween(tag);
            var tweenProps:Dynamic = {};
            Reflect.setField(tweenProps, property, toValue);
            activeTweens.set(tag, FlxTween.tween(target, tweenProps, duration, {
                ease: resolveEaseFunction(ease),
                onComplete: function(_) activeTweens.remove(tag)
            }));
        });

        iris.set("cancelTween", cancelScriptTween);

        iris.set("startTimer", function(tag:String, duration:Float, callback:Void->Void, ?loops:Int = 1) {
            if (activeTimers.exists(tag)) {
                activeTimers.get(tag).cancel();
                activeTimers.remove(tag);
            }
            activeTimers.set(tag, new FlxTimer().start(duration, function(_) {
                if (callback != null) callback();
            }, loops));
        });

        iris.set("cancelTimer", function(tag:String) {
            if (activeTimers.exists(tag)) {
                activeTimers.get(tag).cancel();
                activeTimers.remove(tag);
            }
        });

        // --- Sound & Music ---
        iris.set("playSound", function(soundPath:String, volume:Float = 1.0) {
            AssetHelper.playSoundSafely(soundPath, volume);
        });

        iris.set("playMusic", function(musicPath:String, volume:Float = 1.0, loop:Bool = true) {
            FlxG.sound.playMusic(Paths.music(musicPath), volume, loop);
        });

        // --- Helpers ---
        iris.set("lerp", function(a:Float, b:Float, ratio:Float):Float return FlxMath.lerp(a, b, ratio));
        iris.set("trace", function(v:Dynamic):Void Logger.info(Std.string(v), "iris"));
        iris.set("log", function(v:Dynamic):Void Logger.info(Std.string(v), "iris"));

        iris.set("add", function(obj:Dynamic):Void {
            if (FlxG.state != null) FlxG.state.add(obj);
        });

        iris.set("remove", function(obj:Dynamic):Void {
            if (FlxG.state != null) FlxG.state.remove(obj);
        });

        iris.set("openURL", function(url:String):Void {
            #if linux Sys.command("xdg-open", [url]);
            #else Lib.getURL(new URLRequest(url)); #end
        });

        iris.set("switchState", function(target:Dynamic):Void {
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

        iris.set("importClass", function(className:String):Bool {
            return importClass(className);
        });

        iris.set("createInstance", function(className:String, args:Array<Dynamic>):Dynamic {
            var cl = Type.resolveClass(className);
            if (cl != null) return Type.createInstance(cl, args != null ? args : []);
            return null;
        });
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
        if (iris == null || className == null) return false;
        var resolvedClass:Dynamic = Type.resolveClass(className);
        if (resolvedClass == null) resolvedClass = Type.resolveEnum(className);

        if (resolvedClass != null) {
            var shortName:String = className.substr(className.lastIndexOf(".") + 1);
            iris.set(shortName, resolvedClass);
            return true;
        }
        return false;
    }

    public function call(func:String, ?args:Array<Dynamic>):Dynamic {
        if (iris != null && active) {
            iris.set("game", FlxG.state);
            iris.set("state", FlxG.state);
            iris.set("curBeat", Conductor.curBeat);
            iris.set("curStep", Conductor.curStep);
            iris.set("songPosition", Conductor.songPosition);
            var result = iris.call(func, args != null ? args : []);
            return result != null ? result.val : null;
        }
        return null;
    }

    public function set(key:String, value:Dynamic):Void {
        if (iris != null) iris.set(key, value);
    }

    public function get(key:String):Dynamic {
        if (iris != null) return iris.get(key);
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

        if (iris != null) {
            iris.destroy();
            iris = null;
        }
    }
}