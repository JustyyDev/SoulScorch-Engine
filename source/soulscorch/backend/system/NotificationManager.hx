package soulscorch.backend.system;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.Paths;

class ToastNotification extends FlxSpriteGroup {
    public var targetY:Float = 0.0;
    public var onExpire:ToastNotification->Void;

    private var bg:FlxSprite;
    private var accent:FlxSprite;
    private var label:FlxText;

    public function new(title:String, ?message:String, ?color:FlxColor = FlxColor.WHITE, onExpire:ToastNotification->Void) {
        super(20, -100);
        this.onExpire = onExpire;

        var content = (message != null && message.length > 0) ? '$title\n$message' : title;
        var width:Float = Math.min(420, FlxG.width - 40);

        bg = new FlxSprite().makeGraphic(Std.int(width), 56, 0xEE120F1D);
        add(bg);

        accent = new FlxSprite().makeGraphic(5, 56, color);
        add(accent);

        label = new FlxText(16, 10, width - 24, content, 14);
        label.setFormat(Paths.font("vcr"), 14, color, LEFT, OUTLINE, FlxColor.BLACK);
        label.borderSize = 1.2;
        add(label);

        scrollFactor.set(0, 0);

        FlxTween.tween(this, {alpha: 0}, 0.35, {
            ease: FlxEase.quadIn,
            startDelay: 3.2,
            onComplete: function(_) {
                if (this.onExpire != null) this.onExpire(this);
            }
        });
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        var lerpFactor = FlxMath.bound(elapsed * 12.0, 0, 1);
        y = FlxMath.lerp(y, targetY, lerpFactor);
    }
}

class NotificationManager extends FlxGroup {
    public static var instance(get, null):NotificationManager;
    private static var _instance:NotificationManager;

    private var stack:Array<ToastNotification> = [];
    private static inline var SLOT_HEIGHT:Float = 64;
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

    public function notify(title:String, ?message:String, ?color:FlxColor = FlxColor.WHITE):Void {
        var toast = new ToastNotification(title, message, color, function(t:ToastNotification) {
            remove(t, true);
            stack.remove(t);
            t.destroy();
            reposition();
        });

        if (cameras != null && cameras.length > 0) {
            toast.cameras = cameras;
        }

        add(toast);
        stack.push(toast);
        reposition();

        AssetHelper.playSoundSafely("scrollMenu", 0.5);
    }

    private function reposition():Void {
        for (i in 0...stack.length) {
            var item = stack[i];
            item.targetY = MARGIN_Y + (i * SLOT_HEIGHT);
        }
    }
}