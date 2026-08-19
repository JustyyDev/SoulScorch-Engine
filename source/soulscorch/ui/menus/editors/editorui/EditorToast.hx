package soulscorch.ui.menus.editors.editorui;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import soulscorch.backend.assets.Paths;

class EditorToast extends FlxSpriteGroup {
    public static var instance:EditorToast;

    private var toastBg:FlxSprite;
    private var toastText:FlxText;
    private var currentTween:FlxTween;

    public function new() {
        super(0, FlxG.height - 50);
        instance = this;

        toastBg = new FlxSprite(0, 0).makeGraphic(400, 34, EditorTheme.PANEL_HEADER);
        toastBg.alpha = 0.95;
        add(toastBg);

        var accentLine = new FlxSprite(0, 0).makeGraphic(4, 34, EditorTheme.ACCENT_CYAN);
        add(accentLine);

        toastText = new FlxText(12, 8, 380, "", 13);
        toastText.setFormat(Paths.font("vcr"), 13, EditorTheme.TEXT_PRIMARY, LEFT);
        add(toastText);

        x = (FlxG.width - 400) * 0.5;
        alpha = 0;
        scrollFactor.set(0, 0);
    }

    public static function show(message:String, isError:Bool = false):Void {
        if (instance == null) return;
        instance.toastText.text = message;
        instance.toastText.color = isError ? EditorTheme.ACCENT_MAGENTA : EditorTheme.ACCENT_CYAN;

        if (instance.currentTween != null) instance.currentTween.cancel();

        instance.alpha = 1.0;
        instance.y = FlxG.height - 50;

        instance.currentTween = FlxTween.tween(instance, {alpha: 0.0, y: FlxG.height - 35}, 0.5, {
            startDelay: 2.0,
            ease: FlxEase.cubeOut
        });
    }
}