package soulscorch.scripting.backends;

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
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.ModLoader;
import soulscorch.scripting.ScriptInstance;

#if (cpp && LUA_ALLOWED)
import llua.Lua;
import llua.LuaL;
import llua.State;
#end

class LuaScript implements ScriptInstance {
    public var active:Bool = false;
    public var path(default, null):String;

    #if (cpp && LUA_ALLOWED)
    public var luaState:State;
    #end

    private var variables:Map<String, Dynamic> = new Map();
    private var luaSprites:Map<String, FlxSprite> = new Map();
    private var luaTweens:Map<String, FlxTween> = new Map();
    private var luaTimers:Map<String, FlxTimer> = new Map();

    public function new(scriptPath:String) {
        this.path = (scriptPath == null) ? "" : scriptPath;
        load();
    }

    public function load():Bool {
        var fullPath = ModLoader.getPath(path);
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
                var err = Lua.tostring(luaState, -1);
                Logger.error('Lua compile error ($path): $err', "lua");
                active = false;
                return false;
            }
            active = true;
            call("onCreate");
            return true;
        } catch (e:Dynamic) {
            Logger.error('Failed to initialize Lua state for $path: $e', "lua");
            active = false;
            return false;
        }
        #else
        // Fallback simulated environment when compiled without native LuaJIT
        variables.set("FlxG", FlxG);
        variables.set("game", FlxG.state);
        variables.set("Conductor", Conductor);
        active = true;
        return true;
        #end
    }

    #if (cpp && LUA_ALLOWED)
    private function registerLuaCallbacks():Void {
        // --- Core Properties ---
        Lua_helper.add_callback(luaState, "getProperty", function(variable:String) {
            return getProperty(FlxG.state, variable);
        });

        Lua_helper.add_callback(luaState, "setProperty", function(variable:String, value:Dynamic) {
            setProperty(FlxG.state, variable, value);
        });

        // --- Sprites ---
        Lua_helper.add_callback(luaState, "makeLuaSprite", makeLuaSprite);
        Lua_helper.add_callback(luaState, "makeAnimatedLuaSprite", makeAnimatedLuaSprite);
        Lua_helper.add_callback(luaState, "addLuaSprite", addLuaSprite);
        Lua_helper.add_callback(luaState, "removeLuaSprite", removeLuaSprite);
        Lua_helper.add_callback(luaState, "setScrollFactor", setScrollFactor);
        Lua_helper.add_callback(luaState, "scaleObject", scaleObject);

        // --- Tweens & Camera ---
        Lua_helper.add_callback(luaState, "doTweenX", doTweenX);
        Lua_helper.add_callback(luaState, "doTweenY", doTweenY);
        Lua_helper.add_callback(luaState, "doTweenAngle", doTweenAngle);
        Lua_helper.add_callback(luaState, "doTweenAlpha", doTweenAlpha);
        Lua_helper.add_callback(luaState, "doTweenZoom", doTweenZoom);
        Lua_helper.add_callback(luaState, "cameraShake", cameraShake);
        Lua_helper.add_callback(luaState, "cameraFlash", cameraFlash);

        // --- Audio ---
        Lua_helper.add_callback(luaState, "playSound", playSound);
    }
    #end

    public function makeLuaSprite(tag:String, image:String, x:Float = 0, y:Float = 0):Void {
        var sprite = new FlxSprite(x, y);
        if (image != null && image.length > 0) {
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
        var cam:FlxCamera = (cameraName.toLowerCase() == "hud" || cameraName.toLowerCase() == "camhud") ? getProperty(FlxG.state, "camHUD") : FlxG.camera;
        if (cam != null) {
            cancelTween(tag);
            luaTweens.set(tag, FlxTween.tween(cam, {zoom: value}, duration, {
                ease: resolveEase(ease),
                onComplete: function(_) luaTweens.remove(tag)
            }));
        }
    }

    public function cameraShake(cameraName:String, intensity:Float, duration:Float):Void {
        var cam:FlxCamera = (cameraName.toLowerCase() == "hud" || cameraName.toLowerCase() == "camhud") ? getProperty(FlxG.state, "camHUD") : FlxG.camera;
        if (cam != null) cam.shake(intensity, duration);
    }

    public function cameraFlash(cameraName:String, colorStr:String, duration:Float):Void {
        var cam:FlxCamera = (cameraName.toLowerCase() == "hud" || cameraName.toLowerCase() == "camhud") ? getProperty(FlxG.state, "camHUD") : FlxG.camera;
        if (cam != null) cam.flash(FlxColor.fromString(colorStr), duration);
    }

    public function playSound(soundPath:String, volume:Float = 1.0):Void {
        AssetHelper.playSoundSafely(soundPath, volume);
    }

    private function cancelTween(tag:String):Void {
        if (luaTweens.exists(tag)) {
            luaTweens.get(tag).cancel();
            luaTweens.remove(tag);
        }
    }

    private function resolveObject(name:String):Dynamic {
        if (luaSprites.exists(name)) return luaSprites.get(name);
        return getProperty(FlxG.state, name);
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
            case "circin": FlxEase.circIn;
            case "circout": FlxEase.circOut;
            case "circinout": FlxEase.circInOut;
            case "backin": FlxEase.backIn;
            case "backout": FlxEase.backOut;
            case "backinout": FlxEase.backInOut;
            case "elasticin": FlxEase.elasticIn;
            case "elasticout": FlxEase.elasticOut;
            case "elasticinout": FlxEase.elasticInOut;
            default: FlxEase.linear;
        };
    }

    public static function setProperty(root:Dynamic, dottedPath:String, value:Dynamic):Void {
        if (root == null || dottedPath == null) return;
        var parts = dottedPath.split(".");
        var current:Dynamic = root;

        for (i in 0...(parts.length - 1)) {
            if (current == null) return;
            var key = parts[i];
            current = Std.isOfType(current, haxe.ds.StringMap) ? cast(current, haxe.ds.StringMap<Dynamic>).get(key) : Reflect.getProperty(current, key);
        }

        if (current != null && parts.length > 0) {
            var lastKey = parts[parts.length - 1];
            if (Std.isOfType(current, haxe.ds.StringMap)) {
                cast(current, haxe.ds.StringMap<Dynamic>).set(lastKey, value);
            } else {
                Reflect.setProperty(current, lastKey, value);
            }
        }
    }

    public static function getProperty(root:Dynamic, dottedPath:String):Dynamic {
        if (root == null || dottedPath == null) return null;
        var current:Dynamic = root;

        for (part in dottedPath.split(".")) {
            if (current == null) return null;
            current = Std.isOfType(current, haxe.ds.StringMap) ? cast(current, haxe.ds.StringMap<Dynamic>).get(part) : Reflect.getProperty(current, part);
        }
        return current;
    }

    public function call(func:String, ?args:Array<Dynamic>):Dynamic {
        #if (cpp && LUA_ALLOWED)
        if (!active || luaState == null) return null;
        Lua.getglobal(luaState, func);
        if (Lua.isfunction(luaState, -1)) {
            var argCount = (args != null) ? args.length : 0;
            if (args != null) {
                for (arg in args) {
                    if (Std.isOfType(arg, String)) Lua.pushstring(luaState, cast arg);
                    else if (Std.isOfType(arg, Int)) Lua.pushinteger(luaState, cast arg);
                    else if (Std.isOfType(arg, Float)) Lua.pushnumber(luaState, cast arg);
                    else if (Std.isOfType(arg, Bool)) Lua.pushboolean(luaState, cast arg);
                    else Lua.pushnil(luaState);
                }
            }
            if (Lua.pcall(luaState, argCount, 1, 0) != 0) {
                var err = Lua.tostring(luaState, -1);
                Logger.error('Lua runtime error in $func ($path): $err', "lua");
                return null;
            }
            return Lua.tostring(luaState, -1);
        }
        #end
        return null;
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
        luaSprites.clear();
        variables.clear();

        #if (cpp && LUA_ALLOWED)
        if (luaState != null) {
            Lua.close(luaState);
            luaState = null;
        }
        #end
    }
}