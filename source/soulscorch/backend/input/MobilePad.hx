package soulscorch.backend.input;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;

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

class MobileButton extends FlxSprite {
    public var isPressed:Bool = false;
    public var isJustPressed:Bool = false;
    public var isJustReleased:Bool = false;

    private var _lastPressed:Bool = false;

    public function new(x:Float, y:Float, width:Int = 115, height:Int = 115, color:Int = 0xFFFFFFFF) {
        super(x, y);
        makeGraphic(width, height, color);
        alpha = 0.45;
        scrollFactor.set(0, 0);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        isPressed = false;

        #if mobile
        for (touch in FlxG.touches.list) {
            if (touch.overlaps(this, camera)) {
                isPressed = true;
                break;
            }
        }
        #end

        if (FlxG.mouse.overlaps(this, camera) && FlxG.mouse.pressed) {
            isPressed = true;
        }

        isJustPressed = isPressed && !_lastPressed;
        isJustReleased = !isPressed && _lastPressed;
        _lastPressed = isPressed;

        alpha = isPressed ? 0.8 : 0.45;
    }
}

class MobilePad extends FlxSpriteGroup {
    public var buttonLeft:MobileButton;
    public var buttonDown:MobileButton;
    public var buttonUp:MobileButton;
    public var buttonRight:MobileButton;

    public var buttonA:MobileButton;
    public var buttonB:MobileButton;

    public function new(mode:MobilePadMode = FULL, action:MobilePadAction = A_B) {
        super();

        var btnSize:Int = 115;
        var padding:Float = 20.0;
        var screenH:Float = FlxG.height;
        var screenW:Float = FlxG.width;

        if (mode == FULL || mode == ARROWS_ONLY) {
            buttonLeft = new MobileButton(padding, screenH - (btnSize * 2) - padding, btnSize, btnSize, 0xFFC24B99);
            buttonDown = new MobileButton(buttonLeft.x + btnSize + 8, screenH - btnSize - padding, btnSize, btnSize, 0xFF00FFFF);
            buttonUp = new MobileButton(buttonLeft.x + btnSize + 8, screenH - (btnSize * 2) - 16 - padding, btnSize, btnSize, 0xFF12FA05);
            buttonRight = new MobileButton(buttonDown.x + btnSize + 8, screenH - (btnSize * 2) - padding, btnSize, btnSize, 0xFFF9393F);

            add(buttonLeft);
            add(buttonDown);
            add(buttonUp);
            add(buttonRight);
        }

        if (action == A_B || action == A_B_X_Y) {
            buttonB = new MobileButton(screenW - (btnSize * 2) - 28, screenH - btnSize - padding, btnSize, btnSize, 0xFFFF4444);
            buttonA = new MobileButton(screenW - btnSize - padding, screenH - (btnSize * 1.5) - padding, btnSize, btnSize, 0xFF00FF44);

            add(buttonB);
            add(buttonA);
        }

        scrollFactor.set(0, 0);
    }
}