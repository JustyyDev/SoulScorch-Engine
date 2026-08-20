package soulscorch.gameplay.cutscenes;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.sound.FlxSound;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import soulscorch.backend.MusicBeatSubstate;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.Conductor;
import soulscorch.gameplay.PlayState;
import soulscorch.graphics.FunkinSprite;
import soulscorch.graphics.shaders.SoulShader;
import soulscorch.scripting.ScriptManager;

class CutsceneSubState extends MusicBeatSubstate {
    public var script:ScriptManager;
    public var onFinish:Void->Void;
    private var scriptPath:String;

    public function new(scriptPath:String, onFinish:Void->Void) {
        super();
        this.scriptPath = scriptPath;
        this.onFinish = onFinish;

        this.persistentUpdate = true;
        this.persistentDraw = true;
    }

    override public function create():Void {
        super.create();

        script = new ScriptManager();
        script.loadScript(scriptPath);

        script.setAll("game", PlayState.instance);
        script.setAll("self", this);
        script.setAll("PlayState", PlayState);
        script.setAll("close", function() closeCutscene());
        script.setAll("focusOn", function(char:Dynamic) {
            if (char != null && PlayState.instance != null) {
                if (Reflect.hasField(char, "getCameraPosition")) {
                    var pos:FlxPoint = char.getCameraPosition();
                    PlayState.instance.camFollow.setPosition(pos.x, pos.y);
                    pos.put();
                } else if (Reflect.hasField(char, "getMidpoint")) {
                    var pt:FlxPoint = char.getMidpoint();
                    PlayState.instance.camFollow.setPosition(pt.x, pt.y);
                    pt.put();
                }
            }
        });

        script.setAll("timer", function(duration:Float, cb:Void->Void) {
            new FlxTimer().start(duration, function(_) if (cb != null) cb());
        });

        script.setAll("FunkinSprite", FunkinSprite);
        script.setAll("CustomShader", SoulShader);
        script.setAll("SoulShader", SoulShader);
        script.setAll("Options", {gameplayShaders: true, week6PixelPerfect: false});
        script.setAll("Paths", Paths);
        script.setAll("Conductor", Conductor);
        script.setAll("FlxTween", FlxTween);
        script.setAll("FlxEase", FlxEase);
        script.setAll("FlxTimer", FlxTimer);
        script.setAll("FlxMath", FlxMath);
        
        // Expose FlxColor constants safely as an anonymous script-compatible object
        script.setAll("FlxColor", {
            TRANSPARENT: 0x00000000,
            WHITE: 0xFFFFFF,
            BLACK: 0x000000,
            RED: 0xFF0000,
            GREEN: 0x00FF00,
            BLUE: 0x0000FF,
            YELLOW: 0xFFFF00,
            PURPLE: 0x800080,
            PINK: 0xFFC0CB,
            CYAN: 0x00FFFF,
            MAGENTA: 0xFF00FF,
            ORANGE: 0xFFA500,
            fromString: function(str:String) return FlxColor.fromString(str),
            fromRGB: function(r:Int, g:Int, b:Int, a:Int = 255) return FlxColor.fromRGB(r, g, b, a)
        });

        script.setAll("dad", PlayState.instance.dad);
        script.setAll("boyfriend", PlayState.instance.boyfriend);
        script.setAll("gf", PlayState.instance.gf);
        script.setAll("camGame", PlayState.instance.camGame);
        script.setAll("camHUD", PlayState.instance.camHUD);

        script.callAll("create", []);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        if (script != null) {
            script.callAll("update", [elapsed]);
            script.callAll("postUpdate", [elapsed]);
        }
    }

    public function closeCutscene():Void {
        if (script != null) {
            script.callAll("destroy", []);
            script.clear();
        }
        close();
        if (onFinish != null) onFinish();
    }

    override public function destroy():Void {
        if (script != null) {
            script.callAll("destroy", []);
            script.clear();
        }
        super.destroy();
    }
}