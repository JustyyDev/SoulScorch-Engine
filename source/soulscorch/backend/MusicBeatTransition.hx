package soulscorch.backend;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxGradient;
import soulscorch.backend.TransitionData;

class MusicBeatTransition extends FlxSpriteGroup {
    public static var transitionCamera:FlxCamera;
    public static var isTransitioning:Bool = false;

    private var gradient:FlxSprite;
    private var solid:FlxSprite;
    private var data:TransitionData;
    private var onFinish:Void->Void;

    public function new(data:TransitionData, ?onFinish:Void->Void) {
        super();
        this.data = data;
        this.onFinish = onFinish;

        if (transitionCamera == null) {
            transitionCamera = new FlxCamera();
            transitionCamera.bgColor.alpha = 0;
            FlxG.cameras.add(transitionCamera, false);
        }

        cameras = [transitionCamera];
        createVisuals();
    }

    private function createVisuals():Void {
        var width = FlxG.width;
        var height = FlxG.height;

        if (data.type == FADE) {
            solid = new FlxSprite().makeGraphic(width, height, data.color);
            solid.alpha = (data.direction == IN) ? 0.0 : 1.0;
            add(solid);

            var targetAlpha = (data.direction == IN) ? 1.0 : 0.0;
            FlxTween.tween(solid, {alpha: targetAlpha}, data.duration, {
                ease: data.ease,
                onComplete: function(_) complete()
            });
        } else {
            gradient = FlxGradient.createGradientFlxSprite(width, Std.int(height * 0.5), [data.color, FlxColor.TRANSPARENT]);
            solid = new FlxSprite().makeGraphic(width, height, data.color);

            if (data.direction == IN) {
                gradient.y = -gradient.height;
                solid.y = -solid.height - gradient.height;
                add(solid);
                add(gradient);

                FlxTween.tween(this, {y: height + gradient.height}, data.duration, {
                    ease: data.ease,
                    onComplete: function(_) complete()
                });
            } else {
                gradient.flipY = true;
                gradient.y = height;
                solid.y = 0;
                add(solid);
                add(gradient);

                FlxTween.tween(this, {y: height + gradient.height}, data.duration, {
                    ease: data.ease,
                    onComplete: function(_) complete()
                });
            }
        }
    }

    private function complete():Void {
        isTransitioning = false;
        if (onFinish != null) {
            onFinish();
        }
        destroy();
    }
}