package soulscorch.scripting.backends;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import lime.app.Application;
import openfl.Lib;
import openfl.filters.ShaderFilter;
import openfl.net.URLRequest;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.input.Controls;
import soulscorch.backend.input.InputMap;
import soulscorch.backend.system.EventBus;
import soulscorch.backend.system.apis.FileSystemAPI;
import soulscorch.backend.system.apis.ModelAPI;
import soulscorch.backend.system.apis.NativeAPI;
import soulscorch.backend.system.engine.DevConsole;
import soulscorch.backend.system.engine.Engine;
import soulscorch.backend.system.engine.Runtime;
import soulscorch.backend.utils.Logger;
import soulscorch.graphics.shaders.SoulShader;
import soulscorch.graphics.threed.Away3DManager;
import soulscorch.scripting.Script;
import soulscorch.scripting.ScriptInstance;
import soulscorch.scripting.ScriptManager;
import soulscorch.scripting.ScriptedState;
import soulscorch.scripting.ScriptedSubState;
import soulscorch.scripting.mod.ModLoader;

class HScriptIris implements ScriptInstance {
    public var active:Bool = false;
    public var path(default, null):String;
    private var script:Script;

    public function new(scriptPath:String, ?customCode:String) {
        this.path = (scriptPath == null) ? "" : scriptPath;
        this.script = new Script(path, false);
        presetEnvironment();
        load();
    }

    public function load():Bool {
        if (script == null) return false;
        active = script.load();
        return active;
    }

    private function presetEnvironment():Void {
        if (script == null) return;

        // --- Flixel Core & Rendering ---
        set("FlxG", FlxG);
        set("FlxSprite", FlxSprite);
        set("FlxCamera", FlxCamera);
        set("FlxText", FlxText);
        set("FlxBasic", FlxBasic);
        set("FlxObject", FlxObject);
        set("FlxGroup", FlxGroup);
        set("FlxTypedGroup", flixel.group.FlxGroup.FlxTypedGroup);
        set("FlxSpriteGroup", FlxSpriteGroup);

        // --- Flixel Math, Timers & Tweens ---
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
            CYAN: 0xFF00FFFF,
            MAGENTA: 0xFFFF00FF,
            YELLOW: 0xFFFFFF00,
            TRANSPARENT: 0x00000000,
            fromRGB: FlxColor.fromRGB,
            fromHSL: FlxColor.fromHSL,
            fromString: FlxColor.fromString,
            colorLookup: FlxColor.colorLookup
        });

        // --- Standard Library & System ---
        set("Type", Type);
        set("Reflect", Reflect);
        set("Std", Std);
        set("Math", Math);
        set("StringTools", StringTools);
        #if sys set("Sys", Sys); #end
        set("Lib", Lib);
        set("Application", Application);
        set("URLRequest", URLRequest);

        // --- Shaders & 3D Stage API ---
        set("ShaderFilter", ShaderFilter);
        set("SoulShader", SoulShader);
        set("CustomShader", SoulShader);
        set("Away3DManager", Away3DManager);
        set("ModelAPI", ModelAPI);

        // --- SoulScorch Engine Systems ---
        set("Runtime", Runtime.engine);
        set("Engine", Engine.instance);
        set("Conductor", Conductor);
        set("Paths", Paths);
        set("EventBus", EventBus.instance);
        set("Logger", Logger);
        set("NativeAPI", NativeAPI);
        set("FileSystem", FileSystemAPI);
        set("AssetResolver", AssetResolver);
        set("AssetHelper", AssetHelper);
        set("ModLoader", ModLoader);
        set("ScriptManager", ScriptManager);
        set("ScriptedState", ScriptedState);
        set("ScriptedSubState", ScriptedSubState);

        set("game", FlxG.state);
        set("state", FlxG.state);
        set("controls", Controls.instance);

        #if desktop
        set("Discord", soulscorch.backend.system.modules.discord.DiscordRPC);
        #end

        // --- Helper Closures ---
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

        set("importClass", function(className:String):Bool {
            return importClass(className);
        });
    }

    public function importClass(className:String):Bool {
        if (script == null || className == null) return false;
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
        return (script != null && active) ? script.call(func, args) : null;
    }

    public function set(key:String, value:Dynamic):Void {
        if (script != null) script.set(key, value);
    }

    public function get(key:String):Dynamic {
        return (script != null) ? script.get(key) : null;
    }

    public function destroy():Void {
        active = false;
        if (script != null) {
            script.destroy();
            script = null;
        }
    }
}