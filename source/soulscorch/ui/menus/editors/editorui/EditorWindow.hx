package soulscorch.ui.menus.editors.editorui;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import soulscorch.backend.assets.Paths;
import flixel.math.FlxPoint;

class EditorWindow extends FlxSpriteGroup {
    public var windowWidth:Float;
    public var windowHeight:Float;
    public var title(default, set):String;

    private var bg:FlxSprite;
    private var header:FlxSprite;
    private var border:FlxSprite;
    private var titleTxt:FlxText;
    private var contentGroup:FlxSpriteGroup;

    private var isDragging:Bool = false;
    private var dragOffset:FlxPoint;

    public function new(x:Float, y:Float, width:Float, height:Float, title:String = "Properties") {
        super(x, y);
        this.windowWidth = width;
        this.windowHeight = height;

        border = new FlxSprite(-1, -1).makeGraphic(Std.int(width + 2), Std.int(height + 2), EditorTheme.PANEL_BORDER);
        add(border);

        bg = new FlxSprite(0, 0).makeGraphic(Std.int(width), Std.int(height), EditorTheme.PANEL_BG);
        add(bg);

        header = new FlxSprite(0, 0).makeGraphic(Std.int(width), 26, EditorTheme.PANEL_HEADER);
        add(header);

        var accentLine = new FlxSprite(0, 25).makeGraphic(Std.int(width), 1, EditorTheme.ACCENT_CYAN);
        accentLine.alpha = 0.6;
        add(accentLine);

        titleTxt = new FlxText(8, 5, width - 16, title, 13);
        titleTxt.setFormat(Paths.font("vcr"), 13, EditorTheme.TEXT_PRIMARY, LEFT, OUTLINE, FlxColor.BLACK);
        add(titleTxt);

        contentGroup = new FlxSpriteGroup(0, 28);
        add(contentGroup);

        dragOffset = flixel.math.FlxPoint.get(0, 0);
        scrollFactor.set(0, 0);
    }

    public function addElement(sprite:FlxSprite):Void {
        contentGroup.add(sprite);
    }

    public function removeElement(sprite:FlxSprite):Void {
        contentGroup.remove(sprite, true);
    }

    override public function update(elapsed:Float):Void {
        var mx = FlxG.mouse.screenX;
        var my = FlxG.mouse.screenY;

        if (FlxG.mouse.justPressed && mx >= x && mx <= x + windowWidth && my >= y && my <= y + 26) {
            isDragging = true;
            dragOffset.set(mx - x, my - y);
        }

        if (isDragging) {
            if (FlxG.mouse.pressed) {
                x = Math.max(0, Math.min(FlxG.width - windowWidth, mx - dragOffset.x));
                y = Math.max(0, Math.min(FlxG.height - windowHeight, my - dragOffset.y));
            } else {
                isDragging = false;
            }
        }

        super.update(elapsed);
    }

    private function set_title(val:String):String {
        title = val;
        if (titleTxt != null) titleTxt.text = val;
        return val;
    }

    override public function destroy():Void {
        if (dragOffset != null) dragOffset.put();
        super.destroy();
    }
}