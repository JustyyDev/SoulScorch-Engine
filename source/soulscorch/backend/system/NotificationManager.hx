package soulscorch.backend.system;

import flixel.FlxCamera;
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

enum NotificationType {
    INFO;
    SUCCESS;
    WARNING;
    ERROR;
    ACHIEVEMENT;
}

class ToastNotification extends FlxSpriteGroup {
    public var targetY:Float = 0.0;
    public var onExpire:ToastNotification->Void;

    private var bg:FlxSprite;
    private var accent:FlxSprite;
    private var icon:FlxSprite;
    private var label:FlxText;
    private var dismissTween:FlxTween;

    public function new(title:String, ?message:String, type:NotificationType = INFO, onExpire:ToastNotification->Void) {
        super(20, -120);
        this.onExpire = onExpire;

        var accentColor:FlxColor = switch (type) {
            case SUCCESS: 0xFF2ED573;
            case WARNING: 0xFFFFA502;
            case ERROR: 0xFFFF4757;
            case ACHIEVEMENT: 0xFFECCC68;
            case INFO: 0xFF70A1FF;
        };

        var content = (message != null && message.length > 0) ? '$title\n$message' : title;
        var toastWidth:Float = Math.min(440, FlxG.width - 40);
        var toastHeight:Float = (message != null && message.length > 30) ? 68 : 54;

        bg = new FlxSprite().makeGraphic(Std.int(toastWidth), Std.int(toastHeight), 0xF013111C);
        add(bg);

        accent = new FlxSprite().makeGraphic(5, Std.int(toastHeight), accentColor);
        add(accent);

        label = new FlxText(18, 8, toastWidth - 30, content, 14);
        label.setFormat(Paths.font("vcr"), 14, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
        label.borderSize = 1.2;
        add(label);

        scrollFactor.set(0, 0);

        dismissTween = FlxTween.tween(this, {alpha: 0}, 0.3, {
            ease: FlxEase.sineIn,
            startDelay: 3.5,
            onComplete: function(_) {
                if (this.onExpire != null) this.onExpire(this);
            }
        });
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        y = FlxMath.lerp(y, targetY, FlxMath.bound(elapsed * 14.0, 0, 1));
    }

    public function dismiss():Void {
        if (dismissTween != null) dismissTween.cancel();
        FlxTween.tween(this, {alpha: 0, x: -width}, 0.2, {
            ease: FlxEase.cubeIn,
            onComplete: function(_) {
                if (this.onExpire != null) this.onExpire(this);
            }
        });
    }
}

class NotificationManager extends FlxGroup {
    public static var instance(get, null):NotificationManager;
    private static var _instance:NotificationManager;

    private var stack:Array<ToastNotification> = [];
    private static inline var MARGIN_Y:Float = 24;

    public function new() {
        super();
        _instance = this;
    }

    public static inline function get_instance():NotificationManager {
        if (_instance == null) _instance = new NotificationManager();
        return _instance;
    }

    public function notify(title:String, ?message:String, type:NotificationType = INFO):Void {
        var toast = new ToastNotification(title, message, type, function(t:ToastNotification) {
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

        var soundName = (type == ACHIEVEMENT) ? "confirmMenu" : "scrollMenu";
        AssetHelper.playSoundSafely(soundName, 0.6);
    }

    public function notifyInfo(title:String, ?message:String):Void notify(title, message, INFO);
    public function notifySuccess(title:String, ?message:String):Void notify(title, message, SUCCESS);
    public function notifyWarning(title:String, ?message:String):Void notify(title, message, WARNING);
    public function notifyError(title:String, ?message:String):Void notify(title, message, ERROR);
    public function notifyAchievement(name:String, desc:String):Void notify(name, desc, ACHIEVEMENT);

    private function reposition():Void {
        var currentY:Float = MARGIN_Y;
        for (item in stack) {
            item.targetY = currentY;
            currentY += item.height + 8;
        }
    }

    public function clearAll():Void {
        for (toast in stack) {
            remove(toast, true);
            toast.destroy();
        }
        stack = [];
    }
}