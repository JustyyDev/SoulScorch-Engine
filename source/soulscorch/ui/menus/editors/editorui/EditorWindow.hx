package soulscorch.ui.menus.editors.editorui;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import soulscorch.backend.assets.Paths;

class EditorWindow extends FlxSpriteGroup {
    public var windowTitle:String;
    public var windowWidth:Float;
    public var windowHeight:Float;

    private var headerBar:FlxSprite;
    private var bodyBg:FlxSprite;
    private var titleText:FlxText;

    private var isDragging:Bool = false;
    private var dragOffsetX:Float = 0.0;
    private var dragOffsetY:Float = 0.0;

    public function new(x:Float, y:Float, width:Float, height:Float, title:String = "Editor Tool") {
        super(x, y);
        this.windowWidth = width;
        this.windowHeight = height;
        this.windowTitle = title;

        bodyBg = new FlxSprite(0, 30).makeGraphic(Std.int(width), Std.int(height - 30), 0xEE121824);
        add(bodyBg);

        headerBar = new FlxSprite(0, 0).makeGraphic(Std.int(width), 30, 0xFF1B2434);
        add(headerBar);

        titleText = new FlxText(10, 6, width - 20, title, 16);
        titleText.setFormat(Paths.font("vcr"), 16, FlxColor.WHITE, LEFT);
        add(titleText);

        scrollFactor.set(0, 0);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        var mousePos = FlxG.mouse.getScreenPosition();

        if (FlxG.mouse.justPressed && mousePos.x >= x && mousePos.x <= x + windowWidth && mousePos.y >= y && mousePos.y <= y + 30) {
            isDragging = true;
            dragOffsetX = mousePos.x - x;
            dragOffsetY = mousePos.y - y;
        }

        if (FlxG.mouse.justReleased) {
            isDragging = false;
        }

        if (isDragging) {
            x = mousePos.x - dragOffsetX;
            y = mousePos.y - dragOffsetY;
        }
    }
}