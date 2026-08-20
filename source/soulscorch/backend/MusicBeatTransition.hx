package soulscorch.backend;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxGradient;
import soulscorch.backend.TransitionData;
import soulscorch.backend.TransitionData.TransitionDirection;
import soulscorch.backend.TransitionData.TransitionType;

class MusicBeatTransition extends FlxSpriteGroup {
    public static var isTransitioning:Bool = false;
    private static var instance:MusicBeatTransition;

    private var solidBg:FlxSprite;
    private var gradient:FlxSprite;
    private var overlayCam:FlxCamera;

    private var activeData:TransitionData;
    private var onFinishCallback:Void->Void;

    public function new() {
        super();
        scrollFactor.set(0, 0);

        overlayCam = new FlxCamera();
        overlayCam.bgColor = FlxColor.TRANSPARENT;
        FlxG.cameras.add(overlayCam, false);
        cameras = [overlayCam];

        solidBg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        solidBg.scrollFactor.set(0, 0);
        add(solidBg);

        gradient = new FlxSprite().makeGraphic(FlxG.width, Std.int(FlxG.height * 0.5), FlxColor.TRANSPARENT);
        for (y in 0...Std.int(FlxG.height * 0.5)) {
            var alphaVal = Math.floor((1.0 - (y / (FlxG.height * 0.5))) * 255);
            gradient.pixels.fillRect(new openfl.geom.Rectangle(0, y, FlxG.width, 1), FlxColor.fromRGB(0, 0, 0, alphaVal));
        }
        gradient.dirty = true;
        gradient.scrollFactor.set(0, 0);
        add(gradient);

        visible = false;
    }

    public static function play(data:TransitionData, ?onFinish:Void->Void):Void {
        if (instance == null || instance.overlayCam == null || !FlxG.cameras.list.contains(instance.overlayCam)) {
            if (instance != null) instance.destroy();
            instance = new MusicBeatTransition();
            if (FlxG.state != null) FlxG.state.add(instance);
        } else if (FlxG.state != null && !FlxG.state.members.contains(instance)) {
            FlxG.state.add(instance);
        }

        instance.startTransition(data, onFinish);
    }

    private function startTransition(data:TransitionData, ?onFinish:Void->Void):Void {
        this.activeData = data;
        this.onFinishCallback = onFinish;
        isTransitioning = true;
        visible = true;

        FlxTween.cancelTweensOf(solidBg);
        FlxTween.cancelTweensOf(gradient);

        solidBg.color = data.color;
        gradient.color = data.color;

        var w = FlxG.width;
        var h = FlxG.height;

        switch (data.type) {
            case FADE:
                gradient.visible = false;
                solidBg.visible = true;
                solidBg.setPosition(0, 0);
                solidBg.alpha = (data.direction == OUT) ? 0.0 : 1.0;

                var targetAlpha = (data.direction == OUT) ? 1.0 : 0.0;
                FlxTween.tween(solidBg, {alpha: targetAlpha}, data.duration, {
                    ease: data.ease,
                    onComplete: function(_) finish()
                });

            case WIPE:
                gradient.visible = true;
                solidBg.visible = true;
                solidBg.alpha = 1.0;
                gradient.alpha = 1.0;

                if (data.direction == OUT) {
                    gradient.flipY = false;
                    gradient.y = h;
                    solidBg.y = gradient.y + gradient.height;

                    FlxTween.tween(gradient, {y: -gradient.height}, data.duration, {ease: data.ease});
                    FlxTween.tween(solidBg, {y: 0}, data.duration, {
                        ease: data.ease,
                        onComplete: function(_) finish()
                    });
                } else {
                    gradient.flipY = true;
                    solidBg.y = 0;
                    gradient.y = solidBg.height;

                    FlxTween.tween(gradient, {y: h + gradient.height}, data.duration, {ease: data.ease});
                    FlxTween.tween(solidBg, {y: h + gradient.height}, data.duration, {
                        ease: data.ease,
                        onComplete: function(_) finish()
                    });
                }

            case DIAMOND:
                gradient.visible = false;
                solidBg.visible = true;
                solidBg.setPosition(0, 0);
                solidBg.scale.set(data.direction == OUT ? 0.0 : 1.5, data.direction == OUT ? 0.0 : 1.5);
                solidBg.alpha = 1.0;

                var targetScale = data.direction == OUT ? 1.5 : 0.0;
                FlxTween.tween(solidBg.scale, {x: targetScale, y: targetScale}, data.duration, {
                    ease: data.ease,
                    onComplete: function(_) finish()
                });

            default:
                finish();
        }
    }

    private function finish():Void {
        isTransitioning = false;
        visible = false;

        if (onFinishCallback != null) {
            var cb = onFinishCallback;
            onFinishCallback = null;
            cb();
        }
    }

    override public function destroy():Void {
        if (overlayCam != null && FlxG.cameras.list.contains(overlayCam)) {
            FlxG.cameras.remove(overlayCam, true);
        }
        overlayCam = null;
        instance = null;
        super.destroy();
    }
}