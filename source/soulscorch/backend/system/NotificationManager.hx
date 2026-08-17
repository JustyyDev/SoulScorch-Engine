package soulscorch.backend.system;

import flixel.FlxG;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import soulscorch.backend.assets.Paths;

class NotificationManager extends FlxGroup {
    public static var instance(get, null):NotificationManager;
    private static var _instance:NotificationManager;

    private var stack:Array<FlxText> = [];
    private static inline var SLOT_HEIGHT:Float = 54;
    private static inline var MARGIN_X:Float = 20;
    private static inline var MARGIN_Y:Float = 20;

    public function new() {
        super();
        _instance = this;
    }

    public static inline function get_instance():NotificationManager {
        if (_instance == null) {
            _instance = new NotificationManager();
        }
        return _instance;
    }

    /**
     * Spawns an animated on-screen toast notification.
     */
    public function notify(title:String, ?message:String, ?color:FlxColor = FlxColor.WHITE):Void {
        var content = (message != null && message.length > 0) ? '$title\n$message' : title;
        var label = new FlxText(MARGIN_X, -80, FlxG.width - (MARGIN_X * 2), content, 15);
        label.setFormat(Paths.font("vcr"), 15, color, LEFT, OUTLINE, FlxColor.BLACK);
        label.borderSize = 1.5;
        label.scrollFactor.set(0, 0);

        if (cameras != null && cameras.length > 0) {
            label.cameras = cameras;
        }

        add(label);
        stack.push(label);

        var targetY = MARGIN_Y + ((stack.length - 1) * SLOT_HEIGHT);
        FlxTween.tween(label, {y: targetY}, 0.35, {ease: FlxEase.backOut});

        FlxTween.tween(label, {alpha: 0}, 0.4, {
            ease: FlxEase.quadIn,
            startDelay: 3.2,
            onComplete: function(_) {
                remove(label, true);
                stack.remove(label);
                label.destroy();
                reposition();
            }
        });
    }

    private function reposition():Void {
        for (i in 0...stack.length) {
            var item = stack[i];
            var targetY = MARGIN_Y + (i * SLOT_HEIGHT);
            if (item.y != targetY) {
                FlxTween.tween(item, {y: targetY}, 0.25, {ease: FlxEase.quadOut});
            }
        }
    }
}