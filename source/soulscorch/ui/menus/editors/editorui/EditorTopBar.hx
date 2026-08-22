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
    private var buttons:Array<{name:String, callback:Void->Void, x:Float, w:Float, spr:FlxSprite}> = [];

    public function new(editorTitle:String) {
        super(0, 0);

        var bg = new FlxSprite(0, 0).makeGraphic(FlxG.width, 32, EditorTheme.PANEL_HEADER);
        add(bg);

        var bottomBorder = new FlxSprite(0, 31).makeGraphic(FlxG.width, 1, EditorTheme.PANEL_BORDER);
        add(bottomBorder);

        var brandTag = new FlxSprite(10, 8).makeGraphic(4, 16, EditorTheme.ACCENT_CYAN);
        add(brandTag);

        titleText = new FlxText(20, 7, 300, 'SOULSCORCH // $editorTitle', 14);
        titleText.setFormat(Paths.font("vcr"), 14, EditorTheme.TEXT_PRIMARY, LEFT);
        add(titleText);

        scrollFactor.set(0, 0);
    }

    public function addAction(name:String, callback:Void->Void):Void {
        var startX:Float = FlxG.width - 10;
        for (btn in buttons) startX -= (btn.w + 6);

        var btnWidth:Float = Math.max(70, (name.length * 9.0) + 16.0);
        var btnX:Float = startX - btnWidth;

        var buttonSprite = new FlxSprite(btnX, 4).makeGraphic(Std.int(btnWidth), 24, EditorTheme.BTN_IDLE);
        add(buttonSprite);

        var txt = new FlxText(btnX, 7, btnWidth, name, 12);
        txt.setFormat(Paths.font("vcr"), 12, EditorTheme.TEXT_PRIMARY, CENTER);
        add(txt);

        buttons.push({name: name, callback: callback, x: btnX, w: btnWidth, spr: buttonSprite});
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        var cam:FlxCamera = (cameras != null && cameras.length > 0) ? cameras[0] : FlxG.camera;
        var mousePos:FlxPoint = FlxG.mouse.getPositionInCameraView(cam);

        for (btn in buttons) {
            var hovered = (mousePos.x >= btn.x && mousePos.x <= btn.x + btn.w && mousePos.y >= 4 && mousePos.y <= 28);
            btn.spr.color = hovered ? EditorTheme.BTN_HOVER : EditorTheme.BTN_IDLE;

            if (hovered && FlxG.mouse.justPressed) {
                AssetHelper.playSoundSafely("scrollMenu", 0.5);
                btn.callback();
                break;
            }
        }
    }
}