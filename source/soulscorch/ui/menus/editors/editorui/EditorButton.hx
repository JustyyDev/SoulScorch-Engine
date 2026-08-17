package soulscorch.ui.menus.editors.editorui;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import soulscorch.backend.assets.Paths;

class EditorButton extends FlxSpriteGroup {
    public var label:FlxText;
    public var bg:FlxSprite;
    public var onClick:Void->Void;
    public var isHovered:Bool = false;

    public function new(x:Float, y:Float, width:Float, height:Float, labelText:String, ?onClick:Void->Void) {
        super(x, y);
        this.onClick = onClick;

        bg = new FlxSprite(0, 0).makeGraphic(Std.int(width), Std.int(height), 0xFF243044);
        add(bg);

        label = new FlxText(0, (height - 16) * 0.5, width, labelText, 14);
        label.setFormat(Paths.font("vcr"), 14, FlxColor.WHITE, CENTER);
        add(label);

        scrollFactor.set(0, 0);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        var mousePos = FlxG.mouse.getScreenPosition();
        isHovered = (mousePos.x >= x && mousePos.x <= x + bg.width && mousePos.y >= y && mousePos.y <= y + bg.height);

        bg.color = isHovered ? 0xFF364866 : 0xFF243044;

        if (isHovered && FlxG.mouse.justPressed) {
            if (onClick != null) {
                onClick();
            }
        }
    }
}