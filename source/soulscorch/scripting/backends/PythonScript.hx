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
import soulscorch.gameplay.notes.StrumArrow;
import soulscorch.graphics.shaders.ShaderManager;
import soulscorch.scripting.ScriptInstance;
import soulscorch.scripting.ScriptedState;
import soulscorch.scripting.mod.ModCustomState;
import soulscorch.scripting.mod.ModManager;
import soulscorch.scripting.mod.SoulGlobalScript;

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
    private var pyTweens:Map<String, FlxTween> = new Map<String, FlxTween>();
    private var pyTimers:Map<String, FlxTimer> = new Map<String, FlxTimer>();

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

        registerPythonBridge();
        active = true;
        call("onCreate", []);
        return true;
    }

    private function registerPythonBridge():Void {
        variables.set("FlxG", FlxG);
        variables.set("game", FlxG.state);
        variables.set("state", FlxG.state);
        variables.set("Conductor", Conductor);
    }

    public function makePythonSprite(tag:String, image:String, x:Float = 0, y:Float = 0, ?inFront:Bool = false):Void {
        var sprite = new FlxSprite(x, y);
        if (image != null && image.trim().length > 0) {
            AssetHelper.loadGraphicSafely(sprite, image);
        } else {
            sprite.makeGraphic(64, 64, FlxColor.WHITE);
        }
        pySprites.set(tag, sprite);
        if (FlxG.state != null) {
            if (inFront) FlxG.state.add(sprite); else FlxG.state.insert(0, sprite);
        }
    }

    public function makeAnimatedPythonSprite(tag:String, image:String, x:Float = 0, y:Float = 0, ?inFront:Bool = false):Void {
        var sprite = new FlxSprite(x, y);
        AssetHelper.loadSparrowSafely(sprite, image);
        pySprites.set(tag, sprite);
        if (FlxG.state != null) {
            if (inFront) FlxG.state.add(sprite); else FlxG.state.insert(0, sprite);
        }
    }

    public function makePythonText(tag:String, text:String, width:Float = 0, x:Float = 0, y:Float = 0, size:Int = 16, ?inFront:Bool = true):Void {
        var txt = new FlxText(x, y, width, text, size);
        txt.setFormat(Paths.font("vcr"), size, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
        pyTexts.set(tag, txt);
        if (FlxG.state != null) {
            if (inFront) FlxG.state.add(txt); else FlxG.state.insert(0, txt);
        }
    }

    public function characterPlayAnim(character:String, anim:String, forced:Bool = true):Void {
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

    public function noteTweenX(tag:String, lane:Int, value:Float, duration:Float, ?ease:String = "linear"):Void {
        var target = getReceptorByLane(lane);
        if (target != null) {
            cancelTween(tag);
            pyTweens.set(tag, FlxTween.tween(target, {x: value}, duration, {
                ease: resolveEase(ease),
                onComplete: function(_) pyTweens.remove(tag)
            }));
        }
    }

    public function noteTweenY(tag:String, lane:Int, value:Float, duration:Float, ?ease:String = "linear"):Void {
        var target = getReceptorByLane(lane);
        if (target != null) {
            cancelTween(tag);
            pyTweens.set(tag, FlxTween.tween(target, {y: value}, duration, {
                ease: resolveEase(ease),
                onComplete: function(_) pyTweens.remove(tag)
            }));
        }
    }

    public function noteTweenAngle(tag:String, lane:Int, value:Float, duration:Float, ?ease:String = "linear"):Void {
        var target = getReceptorByLane(lane);
        if (target != null) {
            cancelTween(tag);
            pyTweens.set(tag, FlxTween.tween(target, {angle: value}, duration, {
                ease: resolveEase(ease),
                onComplete: function(_) pyTweens.remove(tag)
            }));
        }
    }

    public function noteTweenAlpha(tag:String, lane:Int, value:Float, duration:Float, ?ease:String = "linear"):Void {
        var target = getReceptorByLane(lane);
        if (target != null) {
            cancelTween(tag);
            pyTweens.set(tag, FlxTween.tween(target, {alpha: value}, duration, {
                ease: resolveEase(ease),
                onComplete: function(_) pyTweens.remove(tag)
            }));
        }
    }

    public function cameraShake(cameraName:String, intensity:Float, duration:Float):Void {
        var cam:FlxCamera = (cameraName.toLowerCase() == "hud") ? PlayState.instance.camHUD : FlxG.camera;
        if (cam != null) cam.shake(intensity, duration);
    }

    public function cameraFlash(cameraName:String, colorStr:String, duration:Float):Void {
        var cam:FlxCamera = (cameraName.toLowerCase() == "hud") ? PlayState.instance.camHUD : FlxG.camera;
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

    public function switchState(target:String):Void {
        if (target == null) return;
        var clean = target.trim();
        var redirect = SoulGlobalScript.getRedirect(clean);
        if (redirect != null && redirect != clean) {
            MusicBeatState.switchState(new ModCustomState(redirect));
        } else {
            MusicBeatState.switchState(new ScriptedState(clean));
        }
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

    private function cancelTween(tag:String):Void {
        if (pyTweens.exists(tag)) {
            pyTweens.get(tag).cancel();
            pyTweens.remove(tag);
        }
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

    public function call(func:String, ?args:Array<Dynamic>):Dynamic {
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
            Logger.warn('Python execution warning in $func ($path): $e', "python");
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

    public function destroy():Void {
        active = false;
        call("onDestroy", []);
        for (t in pyTweens) t.cancel();
        for (tm in pyTimers) tm.cancel();
        pyTweens.clear();
        pyTimers.clear();
        for (s in pySprites) s.destroy();
        for (txt in pyTexts) txt.destroy();
        pySprites.clear();
        pyTexts.clear();
        variables.clear();
    }
}