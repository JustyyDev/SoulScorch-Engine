package soulscorch.core;

import flixel.FlxG;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;

/**
 * On-screen toast notification stack. Added to every Scene so toasts render
 * above gameplay/menus. Auto-dismiss after a few seconds.
 */
class NotificationManager extends FlxGroup {
    public static var instance(default, null):NotificationManager;

    var stack:Array<FlxText> = [];
    static inline var SLOT_HEIGHT:Float = 52;
    static inline var MARGIN:Float = 20;

    public function new() {
        super();
        instance = this;
    }

    public function notify(title:String, ?message:String, ?color:FlxColor):Void {
        var body = message != null ? title + "\n" + message : title;
        var label = new FlxText(MARGIN, -60, FlxG.width - MARGIN * 2, body, 16);
        label.setFormat(null, 16, color != null ? color : FlxColor.WHITE, LEFT, flixel.text.FlxText.FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        label.borderSize = 2;
        label.cameras = cameras;
        add(label);
        stack.push(label);

        var targetY = MARGIN + (stack.length - 1) * SLOT_HEIGHT;
        FlxTween.tween(label, {y: targetY}, 0.3, {ease: FlxEase.circOut});
        FlxTween.tween(label, {alpha: 0}, 0.4, {
            ease: FlxEase.quadIn,
            startDelay: 3.0,
            onComplete: function(_) {
                label.destroy();
                stack.remove(label);
                reposition();
            }
        });
    }

    function reposition():Void {
        for (i in 0...stack.length) {
            var targetY = MARGIN + i * SLOT_HEIGHT;
            if (stack[i].y != targetY) {
                FlxTween.tween(stack[i], {y: targetY}, 0.2, {ease: FlxEase.quadOut});
            }
        }
    }
}
