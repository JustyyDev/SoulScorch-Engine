package soulscorch.backend.input;

import flixel.FlxG;
import flixel.input.gamepad.FlxGamepad;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.input.keyboard.FlxKey;
import soulscorch.backend.input.MobilePad;

using StringTools;

class InputMap {
    public static var keyBinds:Map<String, Array<FlxKey>> = new Map();
    public static var padBinds:Map<String, Array<FlxGamepadInputID>> = new Map();
    public static var mobilePad:MobilePad = null;

    public static var defaultKeyBinds:Map<String, Array<FlxKey>> = [
        "note_left" => [A, LEFT],
        "note_down" => [S, DOWN],
        "note_up" => [W, UP],
        "note_right" => [D, RIGHT],
        "ui_left" => [A, LEFT],
        "ui_down" => [S, DOWN],
        "ui_up" => [W, UP],
        "ui_right" => [D, RIGHT],
        "accept" => [ENTER, SPACE, Z],
        "back" => [ESCAPE, BACKSPACE, X],
        "pause" => [ENTER, ESCAPE],
        "reset" => [R],
        "debug" => [SEVEN, EIGHT]
    ];

    public static var defaultPadBinds:Map<String, Array<FlxGamepadInputID>> = [
        "note_left" => [DPAD_LEFT, X],
        "note_down" => [DPAD_DOWN, A],
        "note_up" => [DPAD_UP, Y],
        "note_right" => [DPAD_RIGHT, B],
        "ui_left" => [DPAD_LEFT, LEFT_STICK_DIGITAL_LEFT],
        "ui_down" => [DPAD_DOWN, LEFT_STICK_DIGITAL_DOWN],
        "ui_up" => [DPAD_UP, LEFT_STICK_DIGITAL_UP],
        "ui_right" => [DPAD_RIGHT, LEFT_STICK_DIGITAL_RIGHT],
        "accept" => [A, START],
        "back" => [B],
        "pause" => [START],
        "reset" => []
    ];

    public static function init():Void {
        loadBindings();
    }

    public static function bindMobilePad(pad:MobilePad):Void {
        mobilePad = pad;
    }

    public static function unbindMobilePad():Void {
        mobilePad = null;
    }

    public static function loadBindings():Void {
        keyBinds.clear();
        padBinds.clear();

        for (action => keys in defaultKeyBinds) {
            keyBinds.set(action, keys.copy());
        }
        for (action => buttons in defaultPadBinds) {
            padBinds.set(action, buttons.copy());
        }

        if (FlxG.save.data != null && FlxG.save.data.customKeyBinds != null) {
            var savedKeys:Map<String, Array<FlxKey>> = FlxG.save.data.customKeyBinds;
            for (action => keys in savedKeys) {
                if (keyBinds.exists(action)) keyBinds.set(action, keys);
            }
        }

        if (FlxG.save.data != null && FlxG.save.data.customPadBinds != null) {
            var savedPads:Map<String, Array<FlxGamepadInputID>> = FlxG.save.data.customPadBinds;
            for (action => buttons in savedPads) {
                if (padBinds.exists(action)) padBinds.set(action, buttons);
            }
        }
    }

    public static function saveBindings():Void {
        if (FlxG.save.data != null) {
            FlxG.save.data.customKeyBinds = keyBinds;
            FlxG.save.data.customPadBinds = padBinds;
            FlxG.save.flush();
        }
    }

    public static function resetToDefaults():Void {
        keyBinds.clear();
        padBinds.clear();
        for (action => keys in defaultKeyBinds) keyBinds.set(action, keys.copy());
        for (action => buttons in defaultPadBinds) padBinds.set(action, buttons.copy());
        saveBindings();
    }

    public static function pressed(action:String):Bool {
        var norm = normalizeAction(action);
        if (checkKeys(norm, 0)) return true;
        if (checkGamepad(norm, 0)) return true;
        if (checkMobile(norm, 0)) return true;
        return false;
    }

    public static function justPressed(action:String):Bool {
        var norm = normalizeAction(action);
        if (checkKeys(norm, 1)) return true;
        if (checkGamepad(norm, 1)) return true;
        if (checkMobile(norm, 1)) return true;
        return false;
    }

    public static function justReleased(action:String):Bool {
        var norm = normalizeAction(action);
        if (checkKeys(norm, 2)) return true;
        if (checkGamepad(norm, 2)) return true;
        if (checkMobile(norm, 2)) return true;
        return false;
    }

    private static function checkKeys(action:String, state:Int):Bool {
        var keys = keyBinds.get(action);
        if (keys == null || keys.length == 0) return false;

        return switch (state) {
            case 0: FlxG.keys.anyPressed(keys);
            case 1: FlxG.keys.anyJustPressed(keys);
            case 2: FlxG.keys.anyJustReleased(keys);
            default: false;
        };
    }

    private static function checkGamepad(action:String, state:Int):Bool {
        var gamepad:FlxGamepad = FlxG.gamepads.lastActive;
        if (gamepad == null) return false;

        var buttons = padBinds.get(action);
        if (buttons == null || buttons.length == 0) return false;

        return switch (state) {
            case 0: gamepad.anyPressed(buttons);
            case 1: gamepad.anyJustPressed(buttons);
            case 2: gamepad.anyJustReleased(buttons);
            default: false;
        };
    }

    private static function checkMobile(action:String, state:Int):Bool {
        if (mobilePad == null) return false;

        var btn:MobileButton = switch (action) {
            case "note_left", "ui_left": mobilePad.buttonLeft;
            case "note_down", "ui_down": mobilePad.buttonDown;
            case "note_up", "ui_up": mobilePad.buttonUp;
            case "note_right", "ui_right": mobilePad.buttonRight;
            case "accept": mobilePad.buttonA;
            case "back": mobilePad.buttonB;
            default: null;
        };

        if (btn == null) return false;

        return switch (state) {
            case 0: btn.isPressed;
            case 1: btn.isJustPressed;
            case 2: btn.isJustReleased;
            default: false;
        };
    }

    public static function bindKey(action:String, key:FlxKey, slot:Int = 0):Void {
        var norm = normalizeAction(action);
        if (!keyBinds.exists(norm)) keyBinds.set(norm, []);

        var current = keyBinds.get(norm);
        if (slot >= current.length) {
            current.push(key);
        } else {
            current[slot] = key;
        }
        saveBindings();
    }

    public static function bindPad(action:String, button:FlxGamepadInputID, slot:Int = 0):Void {
        var norm = normalizeAction(action);
        if (!padBinds.exists(norm)) padBinds.set(norm, []);

        var current = padBinds.get(norm);
        if (slot >= current.length) {
            current.push(button);
        } else {
            current[slot] = button;
        }
        saveBindings();
    }

    public static function getKeyLabel(action:String, slot:Int = 0):String {
        var norm = normalizeAction(action);
        var keys = keyBinds.get(norm);
        if (keys != null && slot < keys.length && keys[slot] != NONE) {
            return keys[slot].toString();
        }
        return "---";
    }

    private static function normalizeAction(action:String):String {
        if (action == null) return "";
        var act = action.toLowerCase().trim();
        return switch (act) {
            case "left": "note_left";
            case "down": "note_down";
            case "up": "note_up";
            case "right": "note_right";
            default: act;
        };
    }
}