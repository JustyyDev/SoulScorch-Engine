package soulscorch.ui.menus.editors.editorui;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.Paths;

class EditorTopBar extends FlxSpriteGroup {
    public var titleText:FlxText;
    private var buttons:Array<{name:String, callback:Void->Void, x:Float, w:Float}> = [];

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

        buttons.push({name: name, callback: callback, x: btnX, w: btnWidth});
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        if (FlxG.mouse.justPressed && FlxG.mouse.screenY <= 32) {
            for (btn in buttons) {
                if (FlxG.mouse.screenX >= btn.x && FlxG.mouse.screenX <= btn.x + btn.w) {
                    AssetHelper.playSoundSafely("scrollMenu", 0.5);
                    btn.callback();
                    break;
                }
            }
        }
    }
}