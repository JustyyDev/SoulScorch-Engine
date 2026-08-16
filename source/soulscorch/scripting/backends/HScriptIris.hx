package soulscorch.scripting.backends;

import Type;
import Reflect;
import Std;
import Math;
import StringTools;
import Sys;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxTimer;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import openfl.filters.ShaderFilter;
import openfl.net.URLRequest;
import openfl.Lib;
import lime.app.Application;

import soulscorch.gameplay.Conductor;
import soulscorch.system.SoulShader;
import soulscorch.assets.AssetResolver;
import soulscorch.modding.ModLoader;
import soulscorch.modding.Script;
import soulscorch.scripting.ScriptInstance;
import soulscorch.scripting.ScriptManager;
import soulscorch.scripting.ScriptedState;
import soulscorch.scripting.ScriptedSubState;

class HScriptIris implements ScriptInstance {
    public var active:Bool = false;
    public var path(default, null):String;
    private var script:Script;

    public function new(scriptPath:String, ?customCode:String) {
        path = scriptPath == null ? "" : scriptPath;
        
        // Matches Script.hx constructor (single path argument)
        script = new Script(path);
        
        active = (script != null && script.active);
        presetEnvironment();
    }

    private function presetEnvironment():Void {
        if (script == null) return;

        // Flixel Core & Math
        set("FlxG", FlxG);
        set("FlxSprite", FlxSprite);
        set("FlxCamera", FlxCamera);
        set("FlxText", FlxText);
        set("FlxTween", FlxTween);
        set("FlxEase", FlxEase);
        set("FlxTimer", FlxTimer);
        set("FlxMath", FlxMath);
        set("FlxColor", {
            BLACK: 0xFF000000,
            WHITE: 0xFFFFFFFF,
            RED: 0xFFFF0000,
            GREEN: 0xFF00FF00,
            BLUE: 0xFF0000FF,
            TRANSPARENT: 0x00000000,
            fromRGB: FlxColor.fromRGB,
            fromHSL: FlxColor.fromHSL,
            colorLookup: FlxColor.colorLookup
        });

        // Haxe & System Libs
        set("Type", Type);
        set("Reflect", Reflect);
        set("Std", Std);
        set("Math", Math);
        set("StringTools", StringTools);
        set("Sys", Sys);
        set("Lib", Lib);
        set("URLRequest", URLRequest);

        // Graphics & Shaders
        set("ShaderFilter", ShaderFilter);
        set("SoulShader", SoulShader);
        set("CustomShader", SoulShader);

        // SoulScorch Engine Systems
        set("Conductor", Conductor);
        set("game", FlxG.state);
        set("state", FlxG.state);
        set("ScriptManager", ScriptManager);
        set("ScriptedState", ScriptedState);
        set("ScriptedSubState", ScriptedSubState);
        set("AssetResolver", AssetResolver);
        set("ModLoader", ModLoader);
        set("Application", Application);

        // Helper closures
        set("lerp", function(a:Float, b:Float, ratio:Float):Float {
            return FlxMath.lerp(a, b, ratio);
        });

        set("openURL", function(url:String):Void {
            #if linux
            Sys.command("xdg-open", [url]);
            #else
            Lib.getURL(new URLRequest(url));
            #end
        });

        set("switchState", function(stateName:String):Void {
            FlxG.switchState(new ScriptedState(stateName));
        });

        // Controls Mock Bridge (UP_P, DOWN_P, ACCEPT, BACK)
        set("controls", {
            UP_P: FlxG.keys.anyJustPressed([UP, W]),
            DOWN_P: FlxG.keys.anyJustPressed([DOWN, S]),
            LEFT_P: FlxG.keys.anyJustPressed([LEFT, A]),
            RIGHT_P: FlxG.keys.anyJustPressed([RIGHT, D]),
            ACCEPT: FlxG.keys.anyJustPressed([ENTER, SPACE]),
            BACK: FlxG.keys.anyJustPressed([ESCAPE, BACKSPACE])
        });

        set("importClass", function(className:String):Bool {
            return importClass(className);
        });
    }

    public function importClass(className:String):Bool {
        if (script == null || !script.active || className == null) return false;
        var resolvedClass:Dynamic = Type.resolveClass(className);
        if (resolvedClass == null) resolvedClass = Type.resolveEnum(className);
        if (resolvedClass != null) {
            var shortName:String = className.substr(className.lastIndexOf(".") + 1);
            set(shortName, resolvedClass);
            return true;
        }
        return false;
    }

    public function call(func:String, ?args:Array<Dynamic>):Dynamic return script == null ? null : script.call(func, args);
    public function set(key:String, value:Dynamic):Void if (script != null) script.set(key, value);
    public function get(key:String):Dynamic return script == null ? null : script.get(key);
    public function destroy():Void {
        active = false;
        if (script != null) {
            script.destroy();
            script = null;
        }
    }
}