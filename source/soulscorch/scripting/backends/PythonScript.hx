package soulscorch.scripting.backends;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.PlayState;
import soulscorch.scripting.ScriptInstance;
import soulscorch.scripting.mod.ModManager;

#if sys
import sys.io.Process;
#end

using StringTools;

class PythonScript implements ScriptInstance {
    public var active:Bool = false;
    public var path(default, null):String;

    private var variables:Map<String, Dynamic> = new Map<String, Dynamic>();
    private var pySprites:Map<String, FlxSprite> = new Map<String, FlxSprite>();
    private var pyTexts:Map<String, FlxText> = new Map<String, FlxText>();

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

        variables.set("FlxG", FlxG);
        variables.set("game", FlxG.state);
        variables.set("state", FlxG.state);
        variables.set("Conductor", Conductor);

        active = true;
        call("create", []);
        call("onCreate", []);
        return true;
    }

    public function call(func:String, ?args:Array<Dynamic>):Dynamic {
        // Guard per-frame hooks to prevent frame freezes from process spawning
        if (func == "update" || func == "onUpdate" || func == "onUpdatePost") {
            return null;
        }

        #if sys
        if (!active || path == null) return null;
        var fullPath = ModManager.getPath(path);
        try {
            var procArgs = ["python", fullPath, func];
            if (args != null) {
                for (a in args) procArgs.push(Std.string(a));
            }
            var proc = new Process(procArgs[0], procArgs.slice(1));
            var output = proc.stdout.readAll().toString();
            proc.close();
            return output.trim();
        } catch (e:Dynamic) {
            Logger.warn('Python execution notice in $func ($path): $e', "python");
        }
        #end
        return null;
    }

    public function set(key:String, value:Dynamic):Void {
        variables.set(key, value);
    }

    public function get(key:String):Dynamic {
        if (variables.exists(key)) return variables.get(key);
        if (pySprites.exists(key)) return pySprites.get(key);
        if (pyTexts.exists(key)) return pyTexts.get(key);
        return null;
    }

    public function importClass(className:String):Bool {
        if (className == null) return false;
        var resolvedClass:Dynamic = Type.resolveClass(className);
        if (resolvedClass != null) {
            set(className.substr(className.lastIndexOf(".") + 1), resolvedClass);
            return true;
        }
        return false;
    }

    public function destroy():Void {
        active = false;
        for (s in pySprites) s.destroy();
        for (txt in pyTexts) txt.destroy();
        pySprites.clear();
        pyTexts.clear();
        variables.clear();
    }
}