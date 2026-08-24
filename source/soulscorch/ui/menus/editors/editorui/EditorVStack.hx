package soulscorch.ui.menus.editors.editorui;

import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import soulscorch.backend.assets.Paths;

class EditorVStack extends FlxSpriteGroup {
    public var contentWidth(default, null):Float;
    public var cursorY(default, null):Float = 0.0;
    public var defaultGap:Float;

    public function new(x:Float, y:Float, width:Float, defaultGap:Float = 8.0) {
        super(x, y);
        this.contentWidth = width;
        this.defaultGap = defaultGap;
        scrollFactor.set(0, 0);
    }

    public function addItem(item:FlxSprite, height:Float, ?gap:Float):FlxSprite {
        item.setPosition(0, cursorY);
        add(item);
        cursorY += height + (gap != null ? gap : defaultGap);
        return item;
    }

    public function addRow(items:Array<FlxSprite>, height:Float, ?gap:Float):Void {
        for (item in items) {
            item.y = cursorY;
            add(item);
        }
        cursorY += height + (gap != null ? gap : defaultGap);
    }

    public function addSection(title:String):Void {
        var accent = new FlxSprite(0, cursorY + 5).makeGraphic(3, 10, EditorTheme.ACCENT_CYAN);
        add(accent);

        var label = new FlxText(10, cursorY + 2, contentWidth - 10, title.toUpperCase(), 10);
        label.setFormat(Paths.font("vcr"), 10, EditorTheme.TEXT_MUTED, LEFT);
        add(label);

        cursorY += 18 + defaultGap;
    }
}