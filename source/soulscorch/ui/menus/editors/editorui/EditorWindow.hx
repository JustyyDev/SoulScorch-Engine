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
    private var headerAccent:FlxSprite;
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

        // Outer Border Frame
        border = new FlxSprite(0, 0).makeGraphic(Std.int(width), Std.int(height), 0xFF2F364D);
        add(border);

        // Body Background Panel
        bodyBg = new FlxSprite(1, 32).makeGraphic(Std.int(width - 2), Std.int(height - 33), 0xEE0B0E14);
        add(bodyBg);

        // Header Title Bar
        headerBar = new FlxSprite(1, 1).makeGraphic(Std.int(width - 2), 31, 0xFF161A26);
        add(headerBar);

        // Header Neon Accent Line
        headerAccent = new FlxSprite(1, 31).makeGraphic(Std.int(width - 2), 2, 0xFF00FFCC);
        add(headerAccent);

        titleText = new FlxText(12, 8, width - 45, title, 13);
        titleText.setFormat(Paths.font("vcr"), 13, 0xFF00FFCC, LEFT, OUTLINE, FlxColor.BLACK);
        titleText.borderSize = 1.0;
        add(titleText);

        btnMinimize = new FlxSprite(width - 26, 8).makeGraphic(16, 16, 0xFF22283A);
        add(btnMinimize);

        container = new FlxSpriteGroup(1, 34);
        add(container);

        scrollFactor.set(0, 0);
    }

    public function addElement(element:FlxSprite):Void {
        if (container != null) {
            container.add(element);
        }
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        var cam:FlxCamera = (cameras != null && cameras.length > 0) ? cameras[0] : FlxG.camera;
        var mousePos:FlxPoint = FlxG.mouse.getPositionInCameraView(cam);

        var onHeader = (mousePos.x >= x && mousePos.x <= x + windowWidth - 30 && mousePos.y >= y && mousePos.y <= y + 32);
        var onMinBtn = (mousePos.x >= x + windowWidth - 30 && mousePos.x <= x + windowWidth - 6 && mousePos.y >= y + 6 && mousePos.y <= y + 26);

        if (onMinBtn && FlxG.mouse.justPressed) {
            isMinimized = !isMinimized;
            if (bodyBg != null) bodyBg.visible = !isMinimized;
            if (headerAccent != null) headerAccent.visible = !isMinimized;
            if (container != null) container.visible = !isMinimized;
            if (border != null) {
                border.setGraphicSize(Std.int(windowWidth), isMinimized ? 32 : Std.int(windowHeight));
                border.updateHitbox();
            }
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
            y = Math.max(0, Math.min(FlxG.height - 32, mousePos.y - dragOffsetY));
        }
    }
}