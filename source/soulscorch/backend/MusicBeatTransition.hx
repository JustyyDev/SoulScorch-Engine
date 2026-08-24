package soulscorch.backend;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import haxe.xml.Access;
import soulscorch.backend.TransitionData;
import soulscorch.backend.TransitionData.TransitionDirection;
import soulscorch.backend.TransitionData.TransitionType;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.system.XMSoul;

class MusicBeatTransition extends FlxSpriteGroup {
    public static var isTransitioning:Bool = false;
    private static var instance:MusicBeatTransition;

    private var solidBg:FlxSprite;
    private var gradient:FlxSprite;
    private var leftCurtain:FlxSprite;
    private var rightCurtain:FlxSprite;
    private var overlayCam:FlxCamera;

    private var activeData:TransitionData;
    private var onFinishCallback:Void->Void;
    private var cachedWidth:Int = 0;
    private var cachedHeight:Int = 0;

    public function new() {
        super();
        scrollFactor.set(0, 0);

        overlayCam = new FlxCamera();
        overlayCam.bgColor = FlxColor.TRANSPARENT;
        FlxG.cameras.add(overlayCam, false);
        cameras = [overlayCam];

        cachedWidth = FlxG.width;
        cachedHeight = FlxG.height;

        solidBg = new FlxSprite().makeGraphic(cachedWidth, cachedHeight, FlxColor.BLACK);
        solidBg.scrollFactor.set(0, 0);
        add(solidBg);

        gradient = new FlxSprite();
        rebuildGradient();
        gradient.scrollFactor.set(0, 0);
        add(gradient);

        // Curtains
        leftCurtain = new FlxSprite().makeGraphic(Std.int(cachedWidth * 0.5), cachedHeight, FlxColor.BLACK);
        leftCurtain.scrollFactor.set(0, 0);
        leftCurtain.visible = false;
        add(leftCurtain);

        rightCurtain = new FlxSprite().makeGraphic(Std.int(cachedWidth * 0.5), cachedHeight, FlxColor.BLACK);
        rightCurtain.scrollFactor.set(0, 0);
        rightCurtain.visible = false;
        add(rightCurtain);

        visible = false;
    }

    private function rebuildGradient():Void {
        var gradHeight = Std.int(cachedHeight * 0.5);
        gradient.makeGraphic(cachedWidth, gradHeight, FlxColor.TRANSPARENT, true);

        for (y in 0...gradHeight) {
            var alphaVal = Math.floor((1.0 - (y / gradHeight)) * 255);
            gradient.pixels.fillRect(new openfl.geom.Rectangle(0, y, cachedWidth, 1), FlxColor.fromRGB(0, 0, 0, alphaVal));
        }
        gradient.dirty = true;
    }

    private function ensureViewportGraphics():Void {
        if (cachedWidth == FlxG.width && cachedHeight == FlxG.height) return;

        cachedWidth = FlxG.width;
        cachedHeight = FlxG.height;

        solidBg.makeGraphic(cachedWidth, cachedHeight, FlxColor.BLACK, true);
        rebuildGradient();
        leftCurtain.makeGraphic(Std.int(cachedWidth * 0.5), cachedHeight, FlxColor.BLACK, true);
        rightCurtain.makeGraphic(Std.int(cachedWidth * 0.5), cachedHeight, FlxColor.BLACK, true);
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
        ensureViewportGraphics();

        if (data == null) {
            data = new TransitionData(TransitionType.WIPE, TransitionDirection.OUT, 0.35);
        }

        this.activeData = data;
        this.onFinishCallback = onFinish;
        isTransitioning = true;
        visible = true;

        FlxTween.cancelTweensOf(solidBg);
        FlxTween.cancelTweensOf(gradient);
        FlxTween.cancelTweensOf(leftCurtain);
        FlxTween.cancelTweensOf(rightCurtain);

        solidBg.color = data.color;
        gradient.color = data.color;
        leftCurtain.color = data.color;
        rightCurtain.color = data.color;

        leftCurtain.visible = false;
        rightCurtain.visible = false;
        gradient.visible = false;
        solidBg.visible = false;

        if (data.sound != null && data.sound.length > 0) {
            AssetHelper.playSoundSafely(data.sound, 0.7);
        }

        var w = cachedWidth;
        var h = cachedHeight;

        switch (data.type) {
            case FADE:
                solidBg.visible = true;
                solidBg.setPosition(0, 0);
                solidBg.scale.set(1, 1);
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
                solidBg.scale.set(1, 1);

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

            case CURTAIN:
                leftCurtain.visible = true;
                rightCurtain.visible = true;
                leftCurtain.y = 0;
                rightCurtain.y = 0;

                if (data.direction == OUT) {
                    leftCurtain.x = -leftCurtain.width;
                    rightCurtain.x = w;

                    FlxTween.tween(leftCurtain, {x: 0}, data.duration, {ease: data.ease});
                    FlxTween.tween(rightCurtain, {x: w * 0.5}, data.duration, {
                        ease: data.ease,
                        onComplete: function(_) finish()
                    });
                } else {
                    leftCurtain.x = 0;
                    rightCurtain.x = w * 0.5;

                    FlxTween.tween(leftCurtain, {x: -leftCurtain.width}, data.duration, {ease: data.ease});
                    FlxTween.tween(rightCurtain, {x: w}, data.duration, {
                        ease: data.ease,
                        onComplete: function(_) finish()
                    });
                }

            case DIAMOND, CIRCLE:
                solidBg.visible = true;
                solidBg.setPosition(0, 0);
                solidBg.alpha = 1.0;

                var startScale = (data.direction == OUT) ? 0.0 : 2.0;
                var endScale = (data.direction == OUT) ? 2.0 : 0.0;
                solidBg.scale.set(startScale, startScale);

                FlxTween.tween(solidBg.scale, {x: endScale, y: endScale}, data.duration, {
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