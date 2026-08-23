package soulscorch.scripting.backends;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import openfl.display.BlendMode;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.PlayState;
import soulscorch.gameplay.modchart.ModchartTypes.ModTarget;
import soulscorch.gameplay.notes.StrumArrow;
import soulscorch.graphics.shaders.ShaderManager;
import soulscorch.graphics.shaders.SoulShader;
import soulscorch.scripting.ScriptInstance;
import soulscorch.scripting.ScriptedState;
import soulscorch.scripting.mod.ModCustomState;
import soulscorch.scripting.mod.ModManager;
import soulscorch.scripting.mod.ModRegistry;
import soulscorch.scripting.mod.SoulGlobalScript;

#if (cpp && LUA_ALLOWED)
import llua.Lua;
import llua.LuaL;
import llua.Lua_helper;
import llua.State;
import llua.Convert;
#end

using StringTools;

class LuaScript implements ScriptInstance {
    public var active:Bool = false;
    public var path(default, null):String;

    #if (cpp && LUA_ALLOWED)
    public var luaState:State;
    #end

    private var variables:Map<String, Dynamic> = new Map<String, Dynamic>();
    private var luaSprites:Map<String, FlxSprite> = new Map<String, FlxSprite>();
    private var luaTexts:Map<String, FlxText> = new Map<String, FlxText>();
    private var luaTweens:Map<String, FlxTween> = new Map<String, FlxTween>();
    private var luaTimers:Map<String, FlxTimer> = new Map<String, FlxTimer>();

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

        #if (cpp && LUA_ALLOWED)
        try {
            luaState = LuaL.newstate();
            LuaL.openlibs(luaState);
            registerLuaCallbacks();

            var code = AssetResolver.getText(fullPath);
            var result = LuaL.dostring(luaState, code);
            if (result != 0) {
                var rawErr = Lua.tostring(luaState, -1);
                var humanError = formatHumanError(rawErr, path);
                Logger.error(humanError, "lua");
                Lua.pop(luaState, 1);
                active = false;
                return false;
            }
            active = true;
            return true;
        } catch (e:Dynamic) {
            var humanError = '[Lua Exception] Failed to initialize script "$path":\n  -> Reason: $e';
            Logger.error(humanError, "lua");
            active = false;
            return false;
        }
        #else
        variables.set("FlxG", FlxG);
        variables.set("game", FlxG.state);
        variables.set("Conductor", Conductor);
        active = false;
        return false;
        #end
    }

    private function formatHumanError(rawError:String, scriptPath:String):String {
        if (rawError == null) rawError = "Unknown Lua Error";
        
        var cleanErr = rawError.trim();
        var lineNum:String = "Unknown Line";
        
        var lineRegex = ~/:(\d+):\s*(.*)/;
        if (lineRegex.match(cleanErr)) {
            lineNum = lineRegex.matched(1);
            cleanErr = lineRegex.matched(2);
        }

        var readableDescription = cleanErr;
        
        if (cleanErr.indexOf("expected 'end'") != -1 || cleanErr.indexOf("near '<eof>'") != -1) {
            readableDescription = "You forgot to close an 'if', 'function', 'for', or block with an 'end'.";
        } else if (cleanErr.indexOf("expected near") != -1) {
            readableDescription = 'Syntax or punctuation error near this spot (check for missing commas, quotes, or brackets). Original: "$cleanErr"';
        } else if (cleanErr.indexOf("attempt to index") != -1) {
            readableDescription = "Tried to read a property or function on a variable/object that doesn't exist (it might be nil/null).";
        } else if (cleanErr.indexOf("attempt to call") != -1) {
            readableDescription = "Tried to call something as a function that isn't actually a function (check your spelling).";
        }

        return '\n==================================================' +
               '\n [LUA SCRIPT ERROR]' +
               '\n File Path : $scriptPath' +
               '\n Line Number: $lineNum' +
               '\n Issue     : $readableDescription' +
               '\n Raw Error : $rawError' +
               '\n==================================================';
    }

    #if (cpp && LUA_ALLOWED)
    private function registerLuaCallbacks():Void {
        setLuaCallback("getProperty", function(variable:String) {
            var target:Dynamic = (PlayState.instance != null) ? PlayState.instance : FlxG.state;
            return getProperty(target, variable);
        });

        setLuaCallback("setProperty", function(variable:String, value:Dynamic) {
            var target:Dynamic = (PlayState.instance != null) ? PlayState.instance : FlxG.state;
            setProperty(target, variable, value);
        });

        setLuaCallback("getPropertyFromClass", function(className:String, variable:String) {
            var cl = Type.resolveClass(className);
            return (cl != null) ? getProperty(cl, variable) : null;
        });

        setLuaCallback("setPropertyFromClass", function(className:String, variable:String, value:Dynamic) {
            var cl = Type.resolveClass(className);
            if (cl != null) setProperty(cl, variable, value);
        });

        setLuaCallback("switchState", switchCustomState);
        setLuaCallback("makeLuaSprite", makeLuaSprite);
        setLuaCallback("makeAnimatedLuaSprite", makeAnimatedLuaSprite);
        setLuaCallback("makeLuaText", makeLuaText);
        setLuaCallback("setTextString", setTextString);
        setLuaCallback("setTextSize", setTextSize);
        setLuaCallback("setTextColor", setTextColor);
        setLuaCallback("addAnimationByPrefix", addAnimationByPrefix);
        setLuaCallback("addAnimationByIndices", addAnimationByIndices);
        setLuaCallback("playAnim", playAnim);
        setLuaCallback("addLuaSprite", addLuaSprite);
        setLuaCallback("removeLuaSprite", removeLuaSprite);
        setLuaCallback("setScrollFactor", setScrollFactor);
        setLuaCallback("scaleObject", scaleObject);
        setLuaCallback("setObjectCamera", setObjectCamera);

        setLuaCallback("characterPlayAnim", characterPlayAnim);
        setLuaCallback("characterDance", characterDance);
        setLuaCallback("triggerEvent", triggerEvent);
        setLuaCallback("getHealth", function() return (PlayState.instance != null) ? PlayState.instance.health : 1.0);
        setLuaCallback("setHealth", function(val:Float) {
            if (PlayState.instance != null) PlayState.instance.health = val;
        });

        setLuaCallback("doTweenX", doTweenX);
        setLuaCallback("doTweenY", doTweenY);
        setLuaCallback("doTweenAngle", doTweenAngle);
        setLuaCallback("doTweenAlpha", doTweenAlpha);
        setLuaCallback("doTweenZoom", doTweenZoom);
        setLuaCallback("noteTweenX", noteTweenX);
        setLuaCallback("noteTweenY", noteTweenY);
        setLuaCallback("noteTweenAngle", noteTweenAngle);
        setLuaCallback("noteTweenAlpha", noteTweenAlpha);
        setLuaCallback("cameraShake", cameraShake);
        setLuaCallback("cameraFlash", cameraFlash);

        setLuaCallback("setShaderFloat", setShaderFloat);
        setLuaCallback("setShaderBool", setShaderBool);

        setLuaCallback("playSound", playSound);
        setLuaCallback("getSongPosition", function() return Conductor.songPosition);
        setLuaCallback("getCurBeat", function() return Conductor.curBeat);
        setLuaCallback("getCurStep", function() return Conductor.curStep);

        // --- Extended API (no limits) ---
        setLuaCallback("makeGraphic", makeGraphic);
        setLuaCallback("addLuaText", addLuaText);
        setLuaCallback("setTextBorder", setTextBorder);
        setLuaCallback("setTextAlignment", setTextAlignment);
        setLuaCallback("setTextWidth", setTextWidth);
        setLuaCallback("setObjectOrder", setObjectOrder);
        setLuaCallback("getObjectOrder", getObjectOrder);
        setLuaCallback("objectPlayAnim", objectPlayAnim);
        setLuaCallback("setPropertyFromGroup", setPropertyFromGroup);
        setLuaCallback("getPropertyFromGroup", getPropertyFromGroup);
        setLuaCallback("runTimer", runTimer);
        setLuaCallback("cancelTimer", cancelTimer);
        setLuaCallback("cancelTween", cancelTweenByName);
        setLuaCallback("debugPrint", function(msg:Dynamic) Logger.info('[LUA] $msg', "lua"));
        setLuaCallback("screenCenter", screenCenterObject);
        setLuaCallback("setBlendMode", setBlendMode);
        setLuaCallback("setPropertyFromState", function(obj:String, prop:String, val:Dynamic) {
            if (FlxG.state != null) setProperty(FlxG.state, '$obj.$prop', val);
        });
        setLuaCallback("getPropertyFromState", function(obj:String, prop:String) {
            return (FlxG.state != null) ? getProperty(FlxG.state, '$obj.$prop') : null;
        });
        setLuaCallback("isModEnabled", function(mod:String) return ModRegistry.instance.isEnabled(mod));
        setLuaCallback("getActiveMods", function() return ModRegistry.instance.enabledMods);

        // --- Modchart API ---
        setLuaCallback("modchartSet", function(name:String, value:Float, ?target:String = "both", ?lane:Int = -1) {
            if (PlayState.instance != null && PlayState.instance.modcharts != null) {
                var tgt = (target == "opponent") ? OPPONENT : (target == "player") ? PLAYER : BOTH;
                PlayState.instance.modcharts.set(name, value, tgt, lane);
            }
        });
        setLuaCallback("modchartGet", function(name:String, ?target:String = "player", ?lane:Int = 0):Float {
            if (PlayState.instance != null && PlayState.instance.modcharts != null) {
                var tgt = (target == "opponent") ? OPPONENT : (target == "player") ? PLAYER : BOTH;
                return PlayState.instance.modcharts.get(name, tgt, lane);
            }
            return 0.0;
        });
        setLuaCallback("modchartEvent", function(step:Float, name:String, value:Float, ?duration:Float = 0, ?ease:String = "linear", ?target:String = "both", ?lane:Int = -1) {
            if (PlayState.instance != null && PlayState.instance.modcharts != null) {
                var tgt = (target == "opponent") ? OPPONENT : (target == "player") ? PLAYER : BOTH;
                PlayState.instance.modcharts.queueEvent(step, name, value, duration, ease, tgt, lane);
            }
        });

        // --- Shader API ---
        setLuaCallback("createShader", function(name:String):Dynamic {
            return ShaderManager.instance.getShader(name);
        });
        setLuaCallback("setShaderFloatArray", function(shaderName:String, uniform:String, value:Array<Float>):Void {
            var s = ShaderManager.instance.getShader(shaderName);
            if (s != null) s.setFloatArray(uniform, value);
        });
        setLuaCallback("setShaderInt", function(shaderName:String, uniform:String, value:Int):Void {
            var s = ShaderManager.instance.getShader(shaderName);
            if (s != null) s.setInt(uniform, value);
        });
        setLuaCallback("addShaderToCam", function(shaderName:String, cameraName:String):Void {
            var s = ShaderManager.instance.getShader(shaderName);
            if (s == null) return;
            var cam:FlxCamera = switch (cameraName.toLowerCase()) {
                case "hud" | "camhud": (PlayState.instance != null) ? PlayState.instance.camHUD : FlxG.camera;
                case "other" | "camother": (PlayState.instance != null) ? PlayState.instance.camOther : FlxG.camera;
                case "controls" | "camcontrols": (PlayState.instance != null) ? PlayState.instance.camControls : FlxG.camera;
                default: FlxG.camera;
            };
            if (cam != null) ShaderManager.instance.addShader(s, cam);
        });
        setLuaCallback("removeShaderFromCam", function(shaderName:String, cameraName:String):Void {
            var s = ShaderManager.instance.getShader(shaderName);
            if (s == null) return;
            var cam:FlxCamera = switch (cameraName.toLowerCase()) {
                case "hud" | "camhud": (PlayState.instance != null) ? PlayState.instance.camHUD : FlxG.camera;
                case "other" | "camother": (PlayState.instance != null) ? PlayState.instance.camOther : FlxG.camera;
                case "controls" | "camcontrols": (PlayState.instance != null) ? PlayState.instance.camControls : FlxG.camera;
                default: FlxG.camera;
            };
            if (cam != null) ShaderManager.instance.removeShader(s, cam);
        });
    }

    private function setLuaCallback(name:String, func:Dynamic):Void {
        if (luaState != null) {
            Lua_helper.add_callback(luaState, name, func);
        }
    }
    #end

    public function switchCustomState(target:String):Void {
        if (target == null) return;
        var clean = target.trim();
        var redirect = SoulGlobalScript.getRedirect(clean);
        if (redirect != null && redirect != clean) {
            MusicBeatState.switchState(new ModCustomState(redirect));
        } else {
            MusicBeatState.switchState(new ScriptedState(clean));
        }
    }

    public function makeLuaSprite(tag:String, image:String, x:Float = 0, y:Float = 0):Void {
        var sprite = new FlxSprite(x, y);
        if (image != null && image.trim().length > 0) {
            AssetHelper.loadGraphicSafely(sprite, image);
        } else {
            sprite.makeGraphic(64, 64, FlxColor.WHITE);
        }
        luaSprites.set(tag, sprite);
    }

    public function makeAnimatedLuaSprite(tag:String, image:String, x:Float = 0, y:Float = 0):Void {
        var sprite = new FlxSprite(x, y);
        AssetHelper.loadSparrowSafely(sprite, image);
        luaSprites.set(tag, sprite);
    }

    public function makeLuaText(tag:String, text:String, width:Float = 0, x:Float = 0, y:Float = 0):Void {
        var txt = new FlxText(x, y, width, text, 16);
        txt.setFormat(Paths.font("vcr"), 16, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
        luaTexts.set(tag, txt);
    }

    public function setTextString(tag:String, text:String):Void {
        var txt = luaTexts.get(tag);
        if (txt != null) txt.text = text;
    }

    public function setTextSize(tag:String, size:Int):Void {
        var txt = luaTexts.get(tag);
        if (txt != null) txt.size = size;
    }

    public function setTextColor(tag:String, colorStr:String):Void {
        var txt = luaTexts.get(tag);
        if (txt != null) txt.color = FlxColor.fromString(colorStr);
    }

    public function addAnimationByPrefix(tag:String, name:String, prefix:String, framerate:Int = 24, loop:Bool = true):Void {
        var spr = luaSprites.get(tag);
        if (spr != null && spr.animation != null) {
            spr.animation.addByPrefix(name, prefix, framerate, loop);
        }
    }

    public function addAnimationByIndices(tag:String, name:String, prefix:String, indicesStr:String, framerate:Int = 24):Void {
        var spr = luaSprites.get(tag);
        if (spr != null && spr.animation != null) {
            var indices:Array<Int> = [];
            for (p in indicesStr.split(",")) {
                var parsed = Std.parseInt(p.trim());
                if (parsed != null) indices.push(parsed);
            }
            spr.animation.addByIndices(name, prefix, indices, "", framerate, false);
        }
    }

    public function playAnim(tag:String, name:String, forced:Bool = false):Void {
        var spr = luaSprites.get(tag);
        if (spr != null && spr.animation != null) {
            spr.animation.play(name, forced);
        }
    }

    public function addLuaSprite(tag:String, inFront:Bool = false):Void {
        var sprite = luaSprites.get(tag);
        if (sprite != null && FlxG.state != null) {
            if (inFront) {
                FlxG.state.add(sprite);
            } else {
                FlxG.state.insert(0, sprite);
            }
        }
    }

    public function removeLuaSprite(tag:String, destroy:Bool = true):Void {
        var sprite = luaSprites.get(tag);
        if (sprite != null && FlxG.state != null) {
            FlxG.state.remove(sprite, true);
            if (destroy) {
                sprite.destroy();
                luaSprites.remove(tag);
            }
        }
    }

    public function setScrollFactor(tag:String, scrollX:Float, scrollY:Float):Void {
        var sprite = luaSprites.get(tag);
        if (sprite != null) sprite.scrollFactor.set(scrollX, scrollY);
    }

    public function scaleObject(tag:String, scaleX:Float, scaleY:Float):Void {
        var sprite = luaSprites.get(tag);
        if (sprite != null) {
            sprite.scale.set(scaleX, scaleY);
            sprite.updateHitbox();
        }
    }

    public function setObjectCamera(tag:String, cameraName:String):Void {
        var sprite:FlxSprite = luaSprites.exists(tag) ? luaSprites.get(tag) : luaTexts.get(tag);
        if (sprite != null) {
            var cam:FlxCamera = switch (cameraName.toLowerCase().trim()) {
                case "hud" | "camhud": (PlayState.instance != null) ? PlayState.instance.camHUD : FlxG.camera;
                case "other" | "camother": (PlayState.instance != null) ? PlayState.instance.camOther : FlxG.camera;
                case "controls" | "camcontrols": (PlayState.instance != null) ? PlayState.instance.camControls : FlxG.camera;
                default: FlxG.camera;
            };
            if (cam != null) sprite.cameras = [cam];
        }
    }

    public function characterPlayAnim(character:String, anim:String, forced:Bool = false):Void {
        if (PlayState.instance == null) return;
        switch (character.toLowerCase().trim()) {
            case "dad" | "opponent": if (PlayState.instance.dad != null) PlayState.instance.dad.playAnim(anim, forced);
            case "bf" | "boyfriend" | "player": if (PlayState.instance.boyfriend != null) PlayState.instance.boyfriend.playAnim(anim, forced);
            case "gf" | "girlfriend": if (PlayState.instance.gf != null) PlayState.instance.gf.playAnim(anim, forced);
        }
    }

    public function characterDance(character:String):Void {
        if (PlayState.instance == null) return;
        switch (character.toLowerCase().trim()) {
            case "dad" | "opponent": if (PlayState.instance.dad != null) PlayState.instance.dad.dance();
            case "bf" | "boyfriend" | "player": if (PlayState.instance.boyfriend != null) PlayState.instance.boyfriend.dance();
            case "gf" | "girlfriend": if (PlayState.instance.gf != null) PlayState.instance.gf.dance();
        }
    }

    public function triggerEvent(name:String, val1:Dynamic, val2:Dynamic):Void {
        if (PlayState.instance != null) {
            PlayState.instance.triggerEvent(name, val1, val2);
        }
    }

    public function doTweenX(tag:String, target:String, value:Float, duration:Float, ?ease:String = "linear"):Void {
        var obj = resolveObject(target);
        if (obj != null) {
            cancelTween(tag);
            luaTweens.set(tag, FlxTween.tween(obj, {x: value}, duration, {
                ease: resolveEase(ease),
                onComplete: function(_) luaTweens.remove(tag)
            }));
        }
    }

    public function doTweenY(tag:String, target:String, value:Float, duration:Float, ?ease:String = "linear"):Void {
        var obj = resolveObject(target);
        if (obj != null) {
            cancelTween(tag);
            luaTweens.set(tag, FlxTween.tween(obj, {y: value}, duration, {
                ease: resolveEase(ease),
                onComplete: function(_) luaTweens.remove(tag)
            }));
        }
    }

    public function doTweenAngle(tag:String, target:String, value:Float, duration:Float, ?ease:String = "linear"):Void {
        var obj = resolveObject(target);
        if (obj != null) {
            cancelTween(tag);
            luaTweens.set(tag, FlxTween.tween(obj, {angle: value}, duration, {
                ease: resolveEase(ease),
                onComplete: function(_) luaTweens.remove(tag)
            }));
        }
    }

    public function doTweenAlpha(tag:String, target:String, value:Float, duration:Float, ?ease:String = "linear"):Void {
        var obj = resolveObject(target);
        if (obj != null) {
            cancelTween(tag);
            luaTweens.set(tag, FlxTween.tween(obj, {alpha: value}, duration, {
                ease: resolveEase(ease),
                onComplete: function(_) luaTweens.remove(tag)
            }));
        }
    }

    public function doTweenZoom(tag:String, cameraName:String, value:Float, duration:Float, ?ease:String = "linear"):Void {
        var cam:FlxCamera = (cameraName.toLowerCase() == "hud" || cameraName.toLowerCase() == "camhud") 
            ? ((PlayState.instance != null) ? PlayState.instance.camHUD : FlxG.camera) 
            : FlxG.camera;
        if (cam != null) {
            cancelTween(tag);
            luaTweens.set(tag, FlxTween.tween(cam, {zoom: value}, duration, {
                ease: resolveEase(ease),
                onComplete: function(_) luaTweens.remove(tag)
            }));
        }
    }

    public function noteTweenX(tag:String, noteIdx:Int, value:Float, duration:Float, ?ease:String = "linear"):Void {
        var target = getReceptorByIdx(noteIdx);
        if (target != null) {
            cancelTween(tag);
            luaTweens.set(tag, FlxTween.tween(target, {x: value}, duration, {
                ease: resolveEase(ease),
                onComplete: function(_) luaTweens.remove(tag)
            }));
        }
    }

    public function noteTweenY(tag:String, noteIdx:Int, value:Float, duration:Float, ?ease:String = "linear"):Void {
        var target = getReceptorByIdx(noteIdx);
        if (target != null) {
            cancelTween(tag);
            luaTweens.set(tag, FlxTween.tween(target, {y: value}, duration, {
                ease: resolveEase(ease),
                onComplete: function(_) luaTweens.remove(tag)
            }));
        }
    }

    public function noteTweenAngle(tag:String, noteIdx:Int, value:Float, duration:Float, ?ease:String = "linear"):Void {
        var target = getReceptorByIdx(noteIdx);
        if (target != null) {
            cancelTween(tag);
            luaTweens.set(tag, FlxTween.tween(target, {angle: value}, duration, {
                ease: resolveEase(ease),
                onComplete: function(_) luaTweens.remove(tag)
            }));
        }
    }

    public function noteTweenAlpha(tag:String, noteIdx:Int, value:Float, duration:Float, ?ease:String = "linear"):Void {
        var target = getReceptorByIdx(noteIdx);
        if (target != null) {
            cancelTween(tag);
            luaTweens.set(tag, FlxTween.tween(target, {alpha: value}, duration, {
                ease: resolveEase(ease),
                onComplete: function(_) luaTweens.remove(tag)
            }));
        }
    }

    private function getReceptorByIdx(idx:Int):Null<StrumArrow> {
        if (PlayState.instance == null) return null;
        if (idx < 4 && PlayState.instance.opponentStrumline != null && PlayState.instance.opponentStrumline.receptors.length > idx) {
            return PlayState.instance.opponentStrumline.receptors[idx];
        } else if (idx >= 4 && PlayState.instance.playerStrumline != null && PlayState.instance.playerStrumline.receptors.length > (idx - 4)) {
            return PlayState.instance.playerStrumline.receptors[idx - 4];
        }
        return null;
    }

    public function cameraShake(cameraName:String, intensity:Float, duration:Float):Void {
        var cam:FlxCamera = (cameraName.toLowerCase() == "hud" || cameraName.toLowerCase() == "camhud") 
            ? ((PlayState.instance != null) ? PlayState.instance.camHUD : FlxG.camera) 
            : FlxG.camera;
        if (cam != null) cam.shake(intensity, duration);
    }

    public function cameraFlash(cameraName:String, colorStr:String, duration:Float):Void {
        var cam:FlxCamera = (cameraName.toLowerCase() == "hud" || cameraName.toLowerCase() == "camhud") 
            ? ((PlayState.instance != null) ? PlayState.instance.camHUD : FlxG.camera) 
            : FlxG.camera;
        if (cam != null) cam.flash(FlxColor.fromString(colorStr), duration);
    }

    public function setShaderFloat(shaderName:String, uniform:String, value:Float):Void {
        var s = ShaderManager.instance.getShader(shaderName);
        if (s != null) s.setFloat(uniform, value);
    }

    public function setShaderBool(shaderName:String, uniform:String, value:Bool):Void {
        var s = ShaderManager.instance.getShader(shaderName);
        if (s != null) s.setBool(uniform, value);
    }

    public function playSound(soundPath:String, volume:Float = 1.0):Void {
        AssetHelper.playSoundSafely(soundPath, volume);
    }

    public function makeGraphic(tag:String, width:Int, height:Int, colorStr:String = "0xFFFFFFFF"):Void {
        var spr = luaSprites.get(tag);
        if (spr == null) {
            spr = new FlxSprite();
            luaSprites.set(tag, spr);
        }
        spr.makeGraphic(width, height, FlxColor.fromString(colorStr));
    }

    public function addLuaText(tag:String, inFront:Bool = false):Void {
        var txt = luaTexts.get(tag);
        if (txt != null && FlxG.state != null) {
            if (inFront) FlxG.state.add(txt); else FlxG.state.insert(0, txt);
        }
    }

    public function setTextBorder(tag:String, size:Int, colorStr:String):Void {
        var txt = luaTexts.get(tag);
        if (txt != null) {
            txt.borderSize = size;
            txt.borderColor = FlxColor.fromString(colorStr);
            txt.borderStyle = OUTLINE;
        }
    }

    public function setTextAlignment(tag:String, align:String):Void {
        var txt = luaTexts.get(tag);
        if (txt != null) {
            txt.alignment = switch (align.toLowerCase().trim()) {
                case "center" | "centre": CENTER;
                case "right": RIGHT;
                default: LEFT;
            };
        }
    }

    public function setTextWidth(tag:String, width:Float):Void {
        var txt = luaTexts.get(tag);
        if (txt != null) txt.fieldWidth = width;
    }

    public function setObjectOrder(tag:String, order:Int):Void {
        var obj:FlxBasic = luaSprites.exists(tag) ? luaSprites.get(tag) : luaTexts.get(tag);
        if (obj != null && FlxG.state != null) {
            FlxG.state.remove(obj);
            FlxG.state.insert(order, obj);
        }
    }

    public function getObjectOrder(tag:String):Int {
        var obj:FlxBasic = luaSprites.exists(tag) ? luaSprites.get(tag) : luaTexts.get(tag);
        if (obj != null && FlxG.state != null) return FlxG.state.members.indexOf(obj);
        return -1;
    }

    public function objectPlayAnim(tag:String, anim:String, forced:Bool = false):Void {
        var spr = luaSprites.get(tag);
        if (spr != null && spr.animation != null && spr.animation.exists(anim)) spr.animation.play(anim, forced);
    }

    public function setPropertyFromGroup(group:String, index:Int, variable:String, value:Dynamic):Void {
        var grp:Dynamic = getProperty((PlayState.instance != null) ? PlayState.instance : FlxG.state, group);
        if (grp != null && Reflect.field(grp, "members") != null) {
            var members:Array<Dynamic> = Reflect.field(grp, "members");
            if (index >= 0 && index < members.length) setProperty(members[index], variable, value);
        }
    }

    public function getPropertyFromGroup(group:String, index:Int, variable:String):Dynamic {
        var grp:Dynamic = getProperty((PlayState.instance != null) ? PlayState.instance : FlxG.state, group);
        if (grp != null && Reflect.field(grp, "members") != null) {
            var members:Array<Dynamic> = Reflect.field(grp, "members");
            if (index >= 0 && index < members.length) return getProperty(members[index], variable);
        }
        return null;
    }

    public function runTimer(tag:String, time:Float, ?func:String = "onTimerCompleted", loops:Int = 1):Void {
        cancelTimer(tag);
        var remaining = loops;
        var cb = function(_:FlxTimer) {
            call(func, [tag, Std.string(loops - remaining)]);
            remaining--;
            if (remaining <= 0) luaTimers.remove(tag);
        };
        luaTimers.set(tag, new FlxTimer().start(time, cb, loops));
    }

    public function cancelTimer(tag:String):Void {
        if (luaTimers.exists(tag)) {
            luaTimers.get(tag).cancel();
            luaTimers.remove(tag);
        }
    }

    public function cancelTweenByName(tag:String):Void {
        cancelTween(tag);
    }

    public function screenCenterObject(tag:String, axis:String = "xy"):Void {
        var obj:FlxSprite = luaSprites.exists(tag) ? luaSprites.get(tag) : luaTexts.get(tag);
        if (obj != null) {
            var a = axis.toLowerCase().trim();
            if (a == "x") obj.screenCenter(X);
            else if (a == "y") obj.screenCenter(Y);
            else obj.screenCenter();
        }
    }

    public function setBlendMode(tag:String, blend:String):Void {
        var obj:FlxSprite = luaSprites.exists(tag) ? luaSprites.get(tag) : luaTexts.get(tag);
        if (obj != null) {
            obj.blend = switch (blend.toLowerCase().trim()) {
                case "add": BlendMode.ADD;
                case "subtract": BlendMode.SUBTRACT;
                case "multiply": BlendMode.MULTIPLY;
                case "screen": BlendMode.SCREEN;
                case "erase": BlendMode.ERASE;
                default: BlendMode.NORMAL;
            };
        }
    }

    private function cancelTween(tag:String):Void {
        if (luaTweens.exists(tag)) {
            luaTweens.get(tag).cancel();
            luaTweens.remove(tag);
        }
    }

    private function resolveObject(name:String):Dynamic {
        if (luaSprites.exists(name)) return luaSprites.get(name);
        if (luaTexts.exists(name)) return luaTexts.get(name);
        var target:Dynamic = (PlayState.instance != null) ? PlayState.instance : FlxG.state;
        return getProperty(target, name);
    }

    private function resolveEase(ease:String):flixel.tweens.FlxEase.EaseFunction {
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
            default: FlxEase.linear;
        };
    }

    public static function setProperty(root:Dynamic, dottedPath:String, value:Dynamic):Void {
        if (root == null || dottedPath == null) return;
        var parts = dottedPath.split(".");
        var current:Dynamic = root;
        var arrayRegex = ~/^(\w+)\[(\d+)\]$/;

        for (i in 0...(parts.length - 1)) {
            if (current == null) return;
            var part = parts[i];
            if (arrayRegex.match(part)) {
                var fieldName = arrayRegex.matched(1);
                var index = Std.parseInt(arrayRegex.matched(2));
                var arr = Reflect.getProperty(current, fieldName);
                current = (arr != null) ? arr[index] : null;
            } else {
                current = Reflect.getProperty(current, part);
            }
        }

        if (current != null && parts.length > 0) {
            var lastPart = parts[parts.length - 1];
            if (arrayRegex.match(lastPart)) {
                var fieldName = arrayRegex.matched(1);
                var index = Std.parseInt(arrayRegex.matched(2));
                var arr = Reflect.getProperty(current, fieldName);
                if (arr != null) arr[index] = value;
            } else {
                Reflect.setProperty(current, lastPart, value);
            }
        }
    }

    public static function getProperty(root:Dynamic, dottedPath:String):Dynamic {
        if (root == null || dottedPath == null) return null;
        var current:Dynamic = root;
        var arrayRegex = ~/^(\w+)\[(\d+)\]$/;

        for (part in dottedPath.split(".")) {
            if (current == null) return null;
            if (arrayRegex.match(part)) {
                var fieldName = arrayRegex.matched(1);
                var index = Std.parseInt(arrayRegex.matched(2));
                var arr = Reflect.getProperty(current, fieldName);
                current = (arr != null) ? arr[index] : null;
            } else {
                current = Reflect.getProperty(current, part);
            }
        }
        return current;
    }

    public function call(func:String, ?args:Array<Dynamic>):Dynamic {
        #if (cpp && LUA_ALLOWED)
        if (!active || luaState == null) return null;
        Lua.getglobal(luaState, func);

        if (!Lua.isfunction(luaState, -1)) {
            Lua.pop(luaState, 1);
            return null;
        }

        var argCount = (args != null) ? args.length : 0;
        if (args != null) {
            for (arg in args) {
                if (!Convert.toLua(luaState, arg)) Lua.pushnil(luaState);
            }
        }
        if (Lua.pcall(luaState, argCount, 1, 0) != 0) {
            var rawErr = Lua.tostring(luaState, -1);
            var humanError = formatHumanError(rawErr, path);
            Logger.error(humanError, "lua");
            Lua.pop(luaState, 1);
            return null;
        }
        var result = Convert.fromLua(luaState, -1);
        Lua.pop(luaState, 1);
        return result;
        #end
        return null;
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

    public function set(key:String, value:Dynamic):Void {
        variables.set(key, value);
        #if (cpp && LUA_ALLOWED)
        if (luaState != null) {
            if (Std.isOfType(value, String)) {
                Lua.pushstring(luaState, cast value);
                Lua.setglobal(luaState, key);
            } else if (Std.isOfType(value, Float) || Std.isOfType(value, Int)) {
                Lua.pushnumber(luaState, cast value);
                Lua.setglobal(luaState, key);
            } else if (Std.isOfType(value, Bool)) {
                Lua.pushboolean(luaState, cast value);
                Lua.setglobal(luaState, key);
            }
        }
        #end
    }

    public function get(key:String):Dynamic {
        return variables.get(key);
    }

    public function destroy():Void {
        active = false;
        for (tween in luaTweens) tween.cancel();
        for (timer in luaTimers) timer.cancel();
        luaTweens.clear();
        luaTimers.clear();
        for (sprite in luaSprites) sprite.destroy();
        for (text in luaTexts) text.destroy();
        luaSprites.clear();
        luaTexts.clear();
        variables.clear();

        #if (cpp && LUA_ALLOWED)
        if (luaState != null) {
            Lua_helper.clear_callbacks(luaState);
            Lua.close(luaState);
            luaState = null;
        }
        #end
    }
}