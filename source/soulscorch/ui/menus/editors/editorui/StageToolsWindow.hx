package soulscorch.ui.menus.editors.editorui;

import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import soulscorch.backend.assets.Paths;

class StageToolsWindow extends EditorWindow {
    public var stepperScrollX:EditorNumericStepper;
    public var stepperScrollY:EditorNumericStepper;
    public var stepperScaleX:EditorNumericStepper;
    public var stepperScaleY:EditorNumericStepper;
    
    public var btnCenterX:EditorButton;
    public var btnAlignGround:EditorButton;
    public var btnDuplicate:EditorButton;
    public var btnDelete:EditorButton;

    public function new(x:Float, y:Float, ?onAction:String->Void) {
        super(x, y, 320, 260, "Stage Transform Tools");

        // Scroll Factor Steppers
        stepperScrollX = new EditorNumericStepper(10, 8, 300, "Scroll Factor X", 1.0, 0.0, 2.0, 0.1, 2);
        addElement(stepperScrollX);

        stepperScrollY = new EditorNumericStepper(10, 44, 300, "Scroll Factor Y", 1.0, 0.0, 2.0, 0.1, 2);
        addElement(stepperScrollY);

        // Scale Steppers
        stepperScaleX = new EditorNumericStepper(10, 80, 300, "Scale X", 1.0, 0.1, 10.0, 0.05, 2);
        addElement(stepperScaleX);

        stepperScaleY = new EditorNumericStepper(10, 116, 300, "Scale Y", 1.0, 0.1, 10.0, 0.05, 2);
        addElement(stepperScaleY);

        // Quick Alignment Utility Buttons
        btnCenterX = new EditorButton(10, 156, 142, 28, "Center X", function() {
            if (onAction != null) onAction("center_x");
        });
        addElement(btnCenterX);

        btnAlignGround = new EditorButton(158, 156, 142, 28, "Align Ground", function() {
            if (onAction != null) onAction("align_ground");
        });
        addElement(btnAlignGround);

        btnDuplicate = new EditorButton(10, 192, 142, 28, "Duplicate Piece", function() {
            if (onAction != null) onAction("duplicate");
        });
        addElement(btnDuplicate);

        btnDelete = new EditorButton(158, 192, 142, 28, "Delete Piece", function() {
            if (onAction != null) onAction("delete");
        });
        addElement(btnDelete);
    }
}