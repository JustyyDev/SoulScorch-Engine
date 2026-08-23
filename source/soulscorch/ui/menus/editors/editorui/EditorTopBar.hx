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
import soulscorch.ui.hud.Alphabet;

class EditorTopBar extends FlxSpriteGroup {
    public var titleText:Alphabet;
    private var buttons:Array<{name:String, callback:Void->Void, x:Float, w:Float, spr:FlxSprite}> = [];

    public function new(editorTitle:String) {
        super(0, 0);

        var bg = new FlxSprite(0, 0).makeGraphic(FlxG.width, 36, EditorTheme.PANEL_HEADER);
        add(bg);

        var bottomBorder = new FlxSprite(0, 35).makeGraphic(FlxG.width, 1, EditorTheme.PANEL_BORDER);
        add(bottomBorder);

        var brandTag = new FlxSprite(10, 10).makeGraphic(4, 16, EditorTheme.ACCENT_CYAN);
        add(brandTag);

        titleText = new Alphabet(20, 9, 'SOULSCORCH // $editorTitle', false);
        titleText.scale.set(0.7, 0.7);
        add(titleText);

        scrollFactor.set(0, 0);
    }

    public function addAction(name:String, callback:Void->Void):Void {
        var startX:Float = FlxG.width - 10;
        for (btn in buttons) startX -= (btn.w + 6);

        var btnWidth:Float = Math.max(70, (name.length * 9.0) + 16.0);
        var btnX:Float = startX - btnWidth;

        var buttonSprite = EditorTheme.makeRoundedRect(Std.int(btnWidth), 24, EditorTheme.BTN_IDLE, EditorTheme.CORNER_SM);
        buttonSprite.setPosition(btnX, 6);
        add(buttonSprite);

        var txt = new FlxText(btnX, 9, btnWidth, name, 12);
        txt.setFormat(Paths.font("vcr"), 12, EditorTheme.TEXT_PRIMARY, CENTER);
        add(txt);

        buttons.push({name: name, callback: callback, x: btnX, w: btnWidth, spr: buttonSprite});
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        var cam:FlxCamera = (cameras != null && cameras.length > 0) ? cameras[0] : FlxG.camera;
        var mousePos:FlxPoint = FlxG.mouse.getPositionInCameraView(cam);

        for (btn in buttons) {
            var hovered = (mousePos.x >= btn.x && mousePos.x <= btn.x + btn.w && mousePos.y >= 4 && mousePos.y <= 30);
            btn.spr.color = hovered ? EditorTheme.BTN_HOVER : EditorTheme.BTN_IDLE;

            if (hovered && FlxG.mouse.justPressed) {
                AssetHelper.playSoundSafely("scrollMenu", 0.5);
                btn.callback();
                break;
            }
        }
    }
}