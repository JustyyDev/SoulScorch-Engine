package soulscorch.backend;

import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.FlxG;

class MusicBeatTransition extends FlxSubState {
    public static var finishCallback:Void->Void;
    private var isTransIn:Bool = false;
    private var transBlack:FlxSprite;

    public function new(transIn:Bool) {
        super();
        this.isTransIn = transIn;

        var zoom:Float = FlxG.camera.zoom;
        var width:Int = Std.int(FlxG.width / zoom);
        var height:Int = Std.int(FlxG.height / zoom);

        transBlack = new FlxSprite().makeGraphic(width * 2, height * 2, FlxColor.BLACK);
        transBlack.scrollFactor.set();
        transBlack.screenCenter();
        add(transBlack);

        if (isTransIn) {
            transBlack.alpha = 1;
            FlxTween.tween(transBlack, {alpha: 0}, 0.5, {
                ease: FlxEase.cubeOut,
                onComplete: function(twn:FlxTween) {
                    close();
                    if (finishCallback != null) {
                        finishCallback();
                        finishCallback = null;
                    }
                }
            });
        } else {
            transBlack.alpha = 0;
            FlxTween.tween(transBlack, {alpha: 1}, 0.5, {
                ease: FlxEase.cubeIn,
                onComplete: function(twn:FlxTween) {
                    if (finishCallback != null) {
                        finishCallback();
                        finishCallback = null;
                    }
                }
            });
        }
    }
}