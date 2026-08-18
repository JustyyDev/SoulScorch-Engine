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
    public static var isTransitioning:Bool = false;

    private var gradient:FlxSprite;
    private var solidBg:FlxSprite;
    private var data:TransitionData;
    private var onFinish:Void->Void;
    private var subCamera:FlxCamera;

    public function new(data:TransitionData, ?onFinish:Void->Void) {
        super();
        this.data = data;
        this.onFinish = onFinish;

        // Create overlay camera with explicit top layer z-index
        subCamera = new FlxCamera();
        subCamera.bgColor.alpha = 0;
        FlxG.cameras.add(subCamera, false);
        cameras = [subCamera];

        scrollFactor.set();
        createVisuals();
    }

    private function createVisuals():Void {
        var width = FlxG.width;
        var height = FlxG.height;

        if (data.type == FADE) {
            solidBg = new FlxSprite().makeGraphic(width, height, data.color);
            solidBg.scrollFactor.set();
            solidBg.alpha = (data.direction == OUT) ? 0.0 : 1.0;
            add(solidBg);

            var targetAlpha = (data.direction == OUT) ? 1.0 : 0.0;
            FlxTween.tween(solidBg, {alpha: targetAlpha}, data.duration, {
                ease: data.ease,
                onComplete: function(_) complete()
            });
        } else {
            gradient = FlxGradient.createGradientFlxSprite(width, Std.int(height * 0.4), [data.color, FlxColor.TRANSPARENT]);
            gradient.scrollFactor.set();
            solidBg = new FlxSprite().makeGraphic(width, height, data.color);
            solidBg.scrollFactor.set();

            if (data.direction == OUT) {
                // Wipe up from bottom
                gradient.y = height;
                solidBg.y = gradient.y + gradient.height;
                add(solidBg);
                add(gradient);

                FlxTween.tween(gradient, {y: -gradient.height}, data.duration, {ease: data.ease});
                FlxTween.tween(solidBg, {y: 0}, data.duration, {
                    ease: data.ease,
                    onComplete: function(_) complete()
                });
            } else {
                // Wipe down reveal
                gradient.flipY = true;
                gradient.y = 0;
                solidBg.y = -solidBg.height;
                add(solidBg);
                add(gradient);

                FlxTween.tween(gradient, {y: height}, data.duration, {ease: data.ease});
                FlxTween.tween(solidBg, {y: gradient.height}, data.duration, {
                    ease: data.ease,
                    onComplete: function(_) complete()
                });
            }
        }
    }

    private function complete():Void {
        isTransitioning = false;

        if (subCamera != null && FlxG.cameras.list.contains(subCamera)) {
            FlxG.cameras.remove(subCamera, true);
        }

        if (onFinish != null) {
            onFinish();
        }
        destroy();
    }
}