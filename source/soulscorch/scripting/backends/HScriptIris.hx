package soulscorch.scripting.backends;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.addons.display.FlxBackdrop;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.effects.FlxTrail;
import flixel.group.FlxGroup;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import lime.app.Application;
import openfl.Lib;
import openfl.display.BlendMode;
import openfl.filters.ShaderFilter;
import openfl.geom.Matrix;
import openfl.net.URLRequest;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.input.Controls;
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

#if sys
import sys.FileSystem;
import sys.io.File;
#end

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

        script.set("FlxG", FlxG);
        script.set("FlxSprite", FlxSprite);
        script.set("FlxCamera", FlxCamera);
        script.set("FlxText", FlxText);
        script.set("FlxBasic", FlxBasic);
        script.set("FlxObject", FlxObject);
        script.set("FlxGroup", FlxGroup);
        script.set("FlxTypedGroup", flixel.group.FlxGroup.FlxTypedGroup);
        script.set("FlxSpriteGroup", FlxSpriteGroup);
        
        script.set("FlxBackdrop", FlxBackdrop);
        script.set("FlxTrail", FlxTrail);
        script.set("FlxGridOverlay", FlxGridOverlay);

        script.set("FlxTween", FlxTween);
        script.set("FlxEase", FlxEase);
        script.set("FlxTimer", FlxTimer);
        script.set("FlxMath", FlxMath);
        
        script.set("FlxPoint", {
            get: FlxPoint.get,
            weak: FlxPoint.weak
        });
        
        script.set("FlxRect", {
            get: FlxRect.get
        });
        
        script.set("FlxColor", {
            BLACK: 0xFF000000, WHITE: 0xFFFFFFFF, RED: 0xFFFF0000,
            GREEN: 0xFF00FF00, BLUE: 0xFF0000FF, CYAN: 0xFF00FFFF,
            MAGENTA: 0xFFFF00FF, YELLOW: 0xFFFFFF00, TRANSPARENT: 0x00000000,
            fromRGB: FlxColor.fromRGB, fromHSL: FlxColor.fromHSL, fromString: FlxColor.fromString
        });

        // Fixed BlendMode abstract mapping for hscript
        script.set("BlendMode", {
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

        script.set("Matrix", Matrix);
        
        script.set("Type", Type);
        script.set("Reflect", Reflect);
        script.set("Std", Std);
        script.set("Math", Math);
        script.set("StringTools", StringTools);
        
        #if sys 
        script.set("Sys", Sys);
        script.set("FileSystem", FileSystem);
        script.set("File", File);
        #end
        
        script.set("Lib", Lib);
        script.set("Application", Application);
        script.set("URLRequest", URLRequest);

        script.set("ShaderFilter", ShaderFilter);
        script.set("SoulShader", SoulShader);
        script.set("Away3DManager", Away3DManager);
        script.set("ModelAPI", ModelAPI);

        script.set("Runtime", Runtime);
        script.set("Engine", Engine);
        script.set("Conductor", Conductor);
        script.set("Paths", Paths);
        script.set("EventBus", EventBus.instance);
        script.set("Logger", Logger);
        script.set("NativeAPI", NativeAPI);
        script.set("FileSystemAPI", FileSystemAPI);
        script.set("AssetResolver", AssetResolver);
        script.set("AssetHelper", AssetHelper);
        script.set("ModLoader", ModLoader);
        script.set("ScriptManager", ScriptManager);
        script.set("ScriptedState", ScriptedState);
        script.set("ScriptedSubState", ScriptedSubState);

        script.set("game", FlxG.state);
        script.set("state", FlxG.state);
        script.set("controls", Controls.instance);

        #if desktop
        script.set("Discord", soulscorch.backend.system.modules.discord.DiscordRPC);
        #end

        script.set("lerp", function(a:Float, b:Float, ratio:Float):Float {
            return FlxMath.lerp(a, b, ratio);
        });

        script.set("openURL", function(url:String):Void {
            #if linux Sys.command("xdg-open", [url]);
            #else Lib.getURL(new URLRequest(url)); #end
        });

        script.set("switchState", function(stateName:String):Void {
            FlxG.switchState(new ScriptedState(stateName));
        });

        script.set("importClass", function(className:String):Bool {
            return importClass(className);
        });

        script.set("createInstance", function(className:String, args:Array<Dynamic>):Dynamic {
            var cl = Type.resolveClass(className);
            if (cl != null) return Type.createInstance(cl, args != null ? args : []);
            return null;
        });
    }

    public function importClass(className:String):Bool {
        if (script == null || className == null) return false;
        var resolvedClass:Dynamic = Type.resolveClass(className);
        if (resolvedClass == null) resolvedClass = Type.resolveEnum(className);

        if (resolvedClass != null) {
            var shortName:String = className.substr(className.lastIndexOf(".") + 1);
            script.set(shortName, resolvedClass);
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