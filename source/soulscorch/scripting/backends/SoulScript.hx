package soulscorch.scripting.backends;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.FlxSubState;
import flixel.group.FlxGroup;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxAngle;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import hscript.Interp;
import hscript.Parser;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.PlayState;
import soulscorch.gameplay.actors.Character;
import soulscorch.gameplay.notes.StrumArrow;
import soulscorch.gameplay.notes.Strumline;
import soulscorch.graphics.JuiceManager;
import soulscorch.scripting.ScriptInstance;
import soulscorch.scripting.mod.ModManager;
import soulscorch.scripting.soul.SoulScriptParser;

using StringTools;

class SoulScript implements ScriptInstance {
    public var active:Bool = false;
    public var path(default, null):String;

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
            active = true;
            call("create");
            call("onCreate");
            return true;
        } catch (e:Dynamic) {
            Logger.error('Failed to initialize SoulScript ($path): $e', "soulscript");
            active = false;
            return false;
        }
    }

    private function initScript(code:String, fullPath:String):Void {
        var parsedCode = fullPath.endsWith(".soul") ? SoulScriptParser.transpile(code) : code;

        var parser = new Parser();
        parser.allowTypes = false; // Prevents numbers like 64 and 1 from failing as types
        parser.allowJSON = true;
        var program = parser.parseString(parsedCode);

        interp = new Interp();

        for (i in 0...2000) {
            interp.variables.set(Std.string(i), i);
        }

        set("Std", Std);
        set("Math", Math);
        set("StringTools", StringTools);
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
            fromString: FlxColor.fromString
        });

        set("Conductor", Conductor);
        set("Paths", Paths);
        set("AssetHelper", AssetHelper);

        syncStateVariables();
        interp.execute(program);
    }

    public function syncStateVariables():Void {
        var ps = PlayState.instance;
        set("game", (ps != null) ? ps : FlxG.state);
        set("state", FlxG.state);

        if (ps != null) {
            set("boyfriend", ps.boyfriend);
            set("dad", ps.dad);
            set("gf", ps.gf);
            set("camGame", ps.camGame);
            set("camHUD", ps.camHUD);
            set("playerStrumline", ps.playerStrumline);
            set("opponentStrumline", ps.opponentStrumline);
            set("playerStrums", (ps.playerStrumline != null) ? ps.playerStrumline.receptors : null);
            set("opponentStrums", (ps.opponentStrumline != null) ? ps.opponentStrumline.receptors : null);
            set("notes", ps.notes);
            set("sustainsGroup", ps.sustainsGroup);
            set("health", ps.health);
        }
    }

    public function call(func:String, ?args:Array<Dynamic>):Dynamic {
        if (!active || interp == null) return null;

        set("curBeat", Conductor.curBeat);
        set("curStep", Conductor.curStep);
        set("songPosition", Conductor.songPosition);

        if (interp.variables.exists(func)) {
            var fn = interp.variables.get(func);
            if (fn != null && Reflect.isFunction(fn)) {
                try {
                    return Reflect.callMethod(null, fn, (args != null) ? args : []);
                } catch (e:Dynamic) {
                    Logger.warn('SoulScript call warning in $func ($path): $e', "soulscript");
                }
            }
        }
        return null;
    }

    public function set(key:String, value:Dynamic):Void {
        if (interp != null) interp.variables.set(key, value);
    }

    public function get(key:String):Dynamic {
        return (interp != null && interp.variables.exists(key)) ? interp.variables.get(key) : null;
    }

    public function importClass(className:String):Bool {
        if (interp == null || className == null) return false;
        var resolvedClass:Dynamic = Type.resolveClass(className);
        if (resolvedClass != null) {
            set(className.substr(className.lastIndexOf(".") + 1), resolvedClass);
            return true;
        }
        return false;
    }

    public function destroy():Void {
        active = false;
        if (interp != null) {
            interp.variables.clear();
            interp = null;
        }
    }
}