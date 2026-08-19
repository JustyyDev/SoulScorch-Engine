package soulscorch.backend.input;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import soulscorch.backend.assets.Paths;

enum MobilePadMode {
    NONE;
    FULL;
    LEFT_RIGHT;
    UP_DOWN;
    ARROWS_ONLY;
    ACTION_ONLY;
}

enum MobilePadAction {
    NONE;
    A;
    B;
    A_B;
    A_B_X_Y;
}

class MobileButton extends FlxSpriteGroup {
    public var isPressed:Bool = false;
    public var isJustPressed:Bool = false;
    public var isJustReleased:Bool = false;

    public var baseColor:FlxColor;
    public var labelText:String;

    private var bg:FlxSprite;
    private var border:FlxSprite;
    private var label:FlxText;

    private var _lastPressed:Bool = false;
    private var _activeTouchId:Int = -1;

    public function new(x:Float, y:Float, width:Int = 115, height:Int = 115, color:Int = 0xFFFFFFFF, labelText:String = "") {
        super(x, y);
        this.baseColor = color;
        this.labelText = labelText;

        border = new FlxSprite(0, 0).makeGraphic(width, height, 0xFF3F557A);
        add(border);

        bg = new FlxSprite(3, 3).makeGraphic(width - 6, height - 6, baseColor);
        add(bg);

        if (labelText.length > 0) {
            label = new FlxText(0, (height - 24) * 0.5, width, labelText, 20);
            label.setFormat(Paths.font("vcr"), 20, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
            label.borderSize = 1.2;
            add(label);
        }

        alpha = 0.45;
        scrollFactor.set(0, 0);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        var targetCamera:FlxCamera = (cameras != null && cameras.length > 0) ? cameras[0] : FlxG.camera;
        var currentlyTouched:Bool = false;

        #if mobile
        for (touch in FlxG.touches.list) {
            var point = touch.getPositionInCameraView(targetCamera);
            if (point.x >= x && point.x <= x + bg.width && point.y >= y && point.y <= y + bg.height) {
                currentlyTouched = true;
                _activeTouchId = touch.touchPointID;
                break;
            }
        }
        #end

        var mousePos:FlxPoint = FlxG.mouse.getPositionInCameraView(targetCamera);
        if (FlxG.mouse.pressed && (mousePos.x >= x && mousePos.x <= x + bg.width && mousePos.y >= y && mousePos.y <= y + bg.height)) {
            currentlyTouched = true;
        }

        isPressed = currentlyTouched;
        isJustPressed = isPressed && !_lastPressed;
        isJustReleased = !isPressed && _lastPressed;
        _lastPressed = isPressed;

        alpha = isPressed ? 0.85 : 0.45;
        scale.set(isPressed ? 0.95 : 1.0, isPressed ? 0.95 : 1.0);
    }
}

class MobilePad extends FlxSpriteGroup {
    public var buttonLeft:MobileButton;
    public var buttonDown:MobileButton;
    public var buttonUp:MobileButton;
    public var buttonRight:MobileButton;

    public var buttonA:MobileButton;
    public var buttonB:MobileButton;
    public var buttonX:MobileButton;
    public var buttonY:MobileButton;
    public var buttonPause:MobileButton;

    public function new(mode:MobilePadMode = FULL, action:MobilePadAction = A_B) {
        super();

        var btnSize:Int = 110;
        var padding:Float = 18.0;
        var screenH:Float = FlxG.height;
        var screenW:Float = FlxG.width;

        switch (mode) {
            case FULL | ARROWS_ONLY:
                buttonLeft = new MobileButton(padding, screenH - (btnSize * 2) - padding, btnSize, btnSize, 0xFFC24B99, "<");
                buttonDown = new MobileButton(buttonLeft.x + btnSize + 6, screenH - btnSize - padding, btnSize, btnSize, 0xFF00FFFF, "v");
                buttonUp = new MobileButton(buttonLeft.x + btnSize + 6, screenH - (btnSize * 2) - 12 - padding, btnSize, btnSize, 0xFF12FA05, "^");
                buttonRight = new MobileButton(buttonDown.x + btnSize + 6, screenH - (btnSize * 2) - padding, btnSize, btnSize, 0xFFF9393F, ">");

                add(buttonLeft);
                add(buttonDown);
                add(buttonUp);
                add(buttonRight);

            case LEFT_RIGHT:
                buttonLeft = new MobileButton(padding, screenH - btnSize - padding, btnSize, btnSize, 0xFFC24B99, "<");
                buttonRight = new MobileButton(buttonLeft.x + btnSize + 12, screenH - btnSize - padding, btnSize, btnSize, 0xFFF9393F, ">");

                add(buttonLeft);
                add(buttonRight);

            case UP_DOWN:
                buttonUp = new MobileButton(padding, screenH - (btnSize * 2) - 12 - padding, btnSize, btnSize, 0xFF12FA05, "^");
                buttonDown = new MobileButton(padding, screenH - btnSize - padding, btnSize, btnSize, 0xFF00FFFF, "v");

                add(buttonUp);
                add(buttonDown);

            default:
        }

        switch (action) {
            case A:
                buttonA = new MobileButton(screenW - btnSize - padding, screenH - btnSize - padding, btnSize, btnSize, 0xFF00FF44, "A");
                add(buttonA);

            case B:
                buttonB = new MobileButton(screenW - btnSize - padding, screenH - btnSize - padding, btnSize, btnSize, 0xFFFF4444, "B");
                add(buttonB);

            case A_B:
                buttonB = new MobileButton(screenW - (btnSize * 2) - 24 - padding, screenH - btnSize - padding, btnSize, btnSize, 0xFFFF4444, "B");
                buttonA = new MobileButton(screenW - btnSize - padding, screenH - (btnSize * 1.5) - padding, btnSize, btnSize, 0xFF00FF44, "A");

                add(buttonB);
                add(buttonA);

            case A_B_X_Y:
                buttonX = new MobileButton(screenW - (btnSize * 2) - 24 - padding, screenH - (btnSize * 2) - 12 - padding, btnSize, btnSize, 0xFF3B82F6, "X");
                buttonY = new MobileButton(screenW - btnSize - padding, screenH - (btnSize * 2.5) - padding, btnSize, btnSize, 0xFFFBBF24, "Y");
                buttonB = new MobileButton(screenW - (btnSize * 2) - 24 - padding, screenH - btnSize - padding, btnSize, btnSize, 0xFFFF4444, "B");
                buttonA = new MobileButton(screenW - btnSize - padding, screenH - (btnSize * 1.5) - padding, btnSize, btnSize, 0xFF00FF44, "A");

                add(buttonX);
                add(buttonY);
                add(buttonB);
                add(buttonA);

            default:
        }

        buttonPause = new MobileButton(screenW - 75, 15, 60, 60, 0xFF666677, "||");
        add(buttonPause);

        scrollFactor.set(0, 0);
    }
}