package soulscorch.ui.menus.editors.editorui;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import soulscorch.backend.assets.Paths;

class EditorToast extends FlxSpriteGroup {
    public static var instance:EditorToast;

    private var bg:FlxSprite;
    private var text:FlxText;
    private var dismissTimer:FlxTimer;

    public function new() {
        super(0, 0);
        instance = this;
        scrollFactor.set(0, 0);

        bg = new FlxSprite(0, 0).makeGraphic(420, 44, 0xEE1A1A24);
        add(bg);

        var border = new FlxSprite(0, 0).makeGraphic(420, 2, 0xFF00FFCC);
        add(border);

        text = new FlxText(16, 12, 388, "", 14);
        text.setFormat(Paths.font("vcr"), 14, FlxColor.WHITE, CENTER);
        add(text);

        screenCenter(X);
        y = FlxG.height + 60;
        alpha = 0.0;
    }

    public static function show(message:String, isError:Bool = false):Void {
        if (instance == null || instance.text == null) return;
        instance.display(message, isError);
    }

    public function display(message:String, isError:Bool = false):Void {
        if (text == null) return;

        text.text = (message != null) ? message : "";
        text.color = isError ? 0xFFFF3366 : 0xFF00FFCC;

        screenCenter(X);
        FlxTween.cancelTweensOf(this);

        if (dismissTimer != null) {
            dismissTimer.cancel();
        }

        alpha = 1.0;
        FlxTween.tween(this, {y: FlxG.height - 68}, 0.35, {
            ease: FlxEase.quartOut,
            onComplete: function(_) {
                dismissTimer = new FlxTimer().start(2.2, function(_) {
                    FlxTween.tween(this, {y: FlxG.height + 60, alpha: 0.0}, 0.35, {ease: FlxEase.quartIn});
                });
            }
        });
    }

    override public function destroy():Void {
        if (dismissTimer != null) dismissTimer.cancel();
        if (instance == this) instance = null;
        super.destroy();
    }
}