package soulscorch.ui.menus.editors.editorui;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import soulscorch.backend.assets.Paths;

class EditorWindow extends FlxSpriteGroup {
    public var windowWidth:Float;
    public var windowHeight:Float;
    public var title(default, set):String;

    private var bg:FlxSprite;
    private var header:FlxSprite;
    private var border:FlxSprite;
    private var shadow:FlxSprite;
    private var titleTxt:FlxText;
    private var contentGroup:FlxSpriteGroup;

    private var isDragging:Bool = false;
    private var dragOffset:FlxPoint;

    public function new(x:Float, y:Float, width:Float, height:Float, title:String = "Properties") {
        super(x, y);
        this.windowWidth = width;
        this.windowHeight = height;

        var w = Std.int(width);
        var h = Std.int(height);

        shadow = EditorTheme.makeShadow(w, h, EditorTheme.CORNER_MD, 8);
        shadow.setPosition(2, 3);
        shadow.alpha = 0.35;
        add(shadow);

        border = EditorTheme.makeRoundedRect(w + 2, h + 2, EditorTheme.PANEL_BORDER, EditorTheme.CORNER_MD);
        border.setPosition(-1, -1);
        add(border);

        bg = EditorTheme.makeRoundedRect(w, h, EditorTheme.PANEL_BG, EditorTheme.CORNER_MD);
        add(bg);

        header = new FlxSprite(0, 0).makeGraphic(w, 32, EditorTheme.PANEL_HEADER);
        add(header);

        var accentLine = new FlxSprite(0, 31).makeGraphic(Std.int(width), 1, EditorTheme.PANEL_BORDER);
        add(accentLine);

        titleTxt = new FlxText(12, 8, width - 24, title.toUpperCase(), 12);
        titleTxt.setFormat(Paths.font("vcr"), 12, EditorTheme.TEXT_PRIMARY, LEFT);
        add(titleTxt);

        contentGroup = new FlxSpriteGroup(0, 34);
        add(contentGroup);

        dragOffset = FlxPoint.get(0, 0);
        scrollFactor.set(0, 0);
    }

    public function addElement(sprite:FlxSprite):Void {
        contentGroup.add(sprite);
    }

    public function removeElement(sprite:FlxSprite):Void {
        contentGroup.remove(sprite, true);
    }

    override public function update(elapsed:Float):Void {
        var cam:FlxCamera = (cameras != null && cameras.length > 0) ? cameras[0] : FlxG.camera;
        var mousePos:FlxPoint = FlxG.mouse.getPositionInCameraView(cam);

        if (FlxG.mouse.justPressed && mousePos.x >= x && mousePos.x <= x + windowWidth && mousePos.y >= y && mousePos.y <= y + 28) {
            isDragging = true;
            dragOffset.set(mousePos.x - x, mousePos.y - y);
        }

        if (isDragging) {
            if (FlxG.mouse.pressed) {
                x = Math.max(0, Math.min(FlxG.width - windowWidth, mousePos.x - dragOffset.x));
                y = Math.max(0, Math.min(FlxG.height - windowHeight, mousePos.y - dragOffset.y));
            } else {
                isDragging = false;
            }
        }

        super.update(elapsed);
    }

    private function set_title(val:String):String {
        title = val;
        if (titleTxt != null) titleTxt.text = val.toUpperCase();
        return val;
    }

    override public function destroy():Void {
        if (dragOffset != null) dragOffset.put();
        super.destroy();
    }
}