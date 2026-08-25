package soulscorch.ui.menus.editors.editorui;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.Paths;

class EditorTopBar extends FlxSpriteGroup {
    public var titleText:FlxText;
    private var buttons:Array<{name:String, callback:Void->Void, x:Float, w:Float, spr:FlxSprite, txt:FlxText}> = [];

    public function new(editorTitle:String) {
        super(0, 0);

        var bg = new FlxSprite(0, 0).makeGraphic(FlxG.width, EditorTheme.TOP_BAR_HEIGHT, EditorTheme.PANEL_HEADER);
        add(bg);

        var bottomBorder = new FlxSprite(0, EditorTheme.TOP_BAR_HEIGHT - 1).makeGraphic(FlxG.width, 1, EditorTheme.ACCENT_CYAN);
        bottomBorder.alpha = 0.7;
        add(bottomBorder);

        var brandTag = new FlxSprite(12, 10).makeGraphic(4, 28, EditorTheme.ACCENT_CYAN);
        add(brandTag);

        titleText = new FlxText(26, 9, FlxG.width * 0.42, EditorTheme.clampLabel('SOULSCORCH  /  $editorTitle', 56), 14);
        titleText.setFormat(Paths.font("vcr"), 14, EditorTheme.TEXT_PRIMARY, LEFT);
        add(titleText);

        scrollFactor.set(0, 0);
    }

    public function addAction(name:String, callback:Void->Void):Void {
        var startX:Float = FlxG.width - 10;
        for (btn in buttons) startX -= (btn.w + 6);

        var btnWidth:Float = Math.min(150, Math.max(72, (name.length * 8.0) + 18.0));
        var btnX:Float = startX - btnWidth;
        if (btnX < FlxG.width * 0.48) return;

        var buttonSprite = EditorTheme.makeRoundedRect(Std.int(btnWidth), 26, EditorTheme.BTN_IDLE, EditorTheme.CORNER_SM);
        buttonSprite.setPosition(btnX, 11);
        add(buttonSprite);

        var txt = new FlxText(btnX, 15, btnWidth, EditorTheme.clampLabel(name, Std.int(btnWidth / 7)), 12);
        txt.setFormat(Paths.font("vcr"), 12, EditorTheme.TEXT_PRIMARY, CENTER);
        add(txt);

        buttons.push({name: name, callback: callback, x: btnX, w: btnWidth, spr: buttonSprite, txt: txt});
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        var cam:FlxCamera = (cameras != null && cameras.length > 0) ? cameras[0] : FlxG.camera;
        var mousePos:FlxPoint = FlxG.mouse.getPositionInCameraView(cam);

        for (btn in buttons) {
            var hovered = (mousePos.x >= btn.x && mousePos.x <= btn.x + btn.w && mousePos.y >= 11 && mousePos.y <= 37);
            btn.spr.color = hovered ? EditorTheme.BTN_HOVER : EditorTheme.BTN_IDLE;
            btn.txt.color = hovered ? EditorTheme.ACCENT_CYAN : EditorTheme.TEXT_PRIMARY;

            if (hovered && FlxG.mouse.justPressed) {
                AssetHelper.playSoundSafely("scrollMenu", 0.5);
                btn.callback();
                break;
            }
        }
    }
}