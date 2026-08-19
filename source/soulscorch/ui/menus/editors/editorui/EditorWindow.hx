package soulscorch.ui.menus.editors.editorui;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import soulscorch.backend.assets.Paths;

class EditorWindow extends FlxSpriteGroup {
    public var windowTitle:String;
    public var windowWidth:Float;
    public var windowHeight:Float;
    public var isMinimized:Bool = false;

    public var container:FlxSpriteGroup;
    private var headerBar:FlxSprite;
    private var bodyBg:FlxSprite;
    private var border:FlxSprite;
    private var titleText:FlxText;
    private var btnMinimize:FlxSprite;

    private var isDragging:Bool = false;
    private var dragOffsetX:Float = 0.0;
    private var dragOffsetY:Float = 0.0;

    public function new(x:Float, y:Float, width:Float, height:Float, title:String = "Editor Tool") {
        super(x, y);
        this.windowWidth = width;
        this.windowHeight = height;
        this.windowTitle = title;

        border = new FlxSprite(0, 0).makeGraphic(Std.int(width), Std.int(height), 0xFF3F557A);
        add(border);

        bodyBg = new FlxSprite(1, 30).makeGraphic(Std.int(width - 2), Std.int(height - 31), 0xEE121824);
        add(bodyBg);

        headerBar = new FlxSprite(1, 1).makeGraphic(Std.int(width - 2), 29, 0xFF1B2434);
        add(headerBar);

        titleText = new FlxText(10, 6, width - 40, title, 14);
        titleText.setFormat(Paths.font("vcr"), 14, 0xFF00FFCC, LEFT);
        add(titleText);

        btnMinimize = new FlxSprite(width - 24, 6).makeGraphic(16, 16, 0xFF2E3D54);
        add(btnMinimize);

        container = new FlxSpriteGroup(1, 30);
        add(container);

        scrollFactor.set(0, 0);
    }

    public function addElement(element:FlxSprite):Void {
        container.add(element);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        var cam:FlxCamera = (cameras != null && cameras.length > 0) ? cameras[0] : FlxG.camera;
        var mousePos:FlxPoint = FlxG.mouse.getPositionInCameraView(cam);

        var onHeader = (mousePos.x >= x && mousePos.x <= x + windowWidth - 30 && mousePos.y >= y && mousePos.y <= y + 30);
        var onMinBtn = (mousePos.x >= x + windowWidth - 28 && mousePos.x <= x + windowWidth - 6 && mousePos.y >= y + 4 && mousePos.y <= y + 26);

        if (onMinBtn && FlxG.mouse.justPressed) {
            isMinimized = !isMinimized;
            bodyBg.visible = !isMinimized;
            container.visible = !isMinimized;
            border.setGraphicSize(Std.int(windowWidth), isMinimized ? 30 : Std.int(windowHeight));
            border.updateHitbox();
            return;
        }

        if (FlxG.mouse.justPressed && onHeader) {
            isDragging = true;
            dragOffsetX = mousePos.x - x;
            dragOffsetY = mousePos.y - y;
        }

        if (FlxG.mouse.justReleased) {
            isDragging = false;
        }

        if (isDragging) {
            x = Math.max(0, Math.min(FlxG.width - windowWidth, mousePos.x - dragOffsetX));
            y = Math.max(0, Math.min(FlxG.height - 30, mousePos.y - dragOffsetY));
        }
    }
}