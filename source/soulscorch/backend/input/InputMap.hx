package soulscorch.backend.input;

import flixel.FlxG;
import flixel.input.gamepad.FlxGamepad;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.input.keyboard.FlxKey;
import openfl.Lib;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import soulscorch.backend.input.MobilePad;
import soulscorch.backend.utils.Logger;

using StringTools;

class InputMap {
    public static var keyBinds:Map<String, Array<FlxKey>> = new Map<String, Array<FlxKey>>();
    public static var padBinds:Map<String, Array<FlxGamepadInputID>> = new Map<String, Array<FlxGamepadInputID>>();
    public static var mobilePad:MobilePad = null;
    private static var nativeBound:Bool = false;
    private static var nativeKeysHeld:Map<Int, Bool> = new Map<Int, Bool>();
    private static var nativeKeysPressed:Map<Int, Bool> = new Map<Int, Bool>();
    private static var nativeKeysReleased:Map<Int, Bool> = new Map<Int, Bool>();

    public static var defaultKeyBinds:Map<String, Array<FlxKey>> = [
        "note_left"   => [D, LEFT],
        "note_down"   => [F, DOWN],
        "note_up"     => [J, UP],
        "note_right"  => [K, RIGHT],
        "ui_left"     => [A, LEFT],
        "ui_down"     => [S, DOWN],
        "ui_up"       => [W, UP],
        "ui_right"    => [D, RIGHT],
        "accept"      => [ENTER, SPACE, Z],
        "back"        => [ESCAPE, BACKSPACE, X],
        "pause"       => [ENTER, ESCAPE],
        "reset"       => [R],
        "debug"       => [SEVEN, EIGHT],
        "volume_mute" => [ZERO, NUMPADZERO],
        "volume_down" => [MINUS, NUMPADMINUS],
        "volume_up"   => [PLUS, NUMPADPLUS],
        "fullscreen"  => [F11]
    ];

    public static var defaultPadBinds:Map<String, Array<FlxGamepadInputID>> = [
        "note_left"  => [DPAD_LEFT, X, LEFT_TRIGGER],
        "note_down"  => [DPAD_DOWN, A, LEFT_SHOULDER],
        "note_up"    => [DPAD_UP, Y, RIGHT_SHOULDER],
        "note_right" => [DPAD_RIGHT, B, RIGHT_TRIGGER],
        "ui_left"    => [DPAD_LEFT, LEFT_STICK_DIGITAL_LEFT],
        "ui_down"    => [DPAD_DOWN, LEFT_STICK_DIGITAL_DOWN],
        "ui_up"      => [DPAD_UP, LEFT_STICK_DIGITAL_UP],
        "ui_right"   => [DPAD_RIGHT, LEFT_STICK_DIGITAL_RIGHT],
        "accept"     => [A, START],
        "back"       => [B],
        "pause"      => [START],
        "reset"      => [BACK]
    ];

    public static function init():Void {
        loadBindings();
        bindNativeKeyboard();
    }

    private static function bindNativeKeyboard():Void {
        if (nativeBound || Lib.current == null || Lib.current.stage == null) return;
        nativeBound = true;
        Lib.current.stage.addEventListener(KeyboardEvent.KEY_DOWN, onNativeKeyDown, true, 1000);
        Lib.current.stage.addEventListener(KeyboardEvent.KEY_UP, onNativeKeyUp, true, 1000);
        Lib.current.stage.addEventListener(Event.DEACTIVATE, onNativeFocusLost);
    }

    public static function claimKeyboardFocus():Void {
        bindNativeKeyboard();
        nativeKeysHeld.clear();
        clearNativeEdges();
        if (Lib.current != null && Lib.current.stage != null) Lib.current.stage.focus = null;
        if (FlxG.keys != null) FlxG.keys.reset();
    }

    private static function onNativeKeyDown(event:KeyboardEvent):Void {
        if (!nativeKeysHeld.exists(event.keyCode)) nativeKeysPressed.set(event.keyCode, true);
        nativeKeysReleased.remove(event.keyCode);
        nativeKeysHeld.set(event.keyCode, true);
    }

    private static function onNativeKeyUp(event:KeyboardEvent):Void {
        nativeKeysHeld.remove(event.keyCode);
        nativeKeysPressed.remove(event.keyCode);
        nativeKeysReleased.set(event.keyCode, true);
    }

    private static function onNativeFocusLost(_):Void {
        nativeKeysHeld.clear();
        clearNativeEdges();
    }

    private static function clearNativeEdges():Void {
        nativeKeysPressed.clear();
        nativeKeysReleased.clear();
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
            try {
                var rawKeys:Dynamic = FlxG.save.data.customKeyBinds;
                for (action in Reflect.fields(rawKeys)) {
                    var arr:Array<Dynamic> = Reflect.field(rawKeys, action);
                    if (arr != null && keyBinds.exists(action)) {
                        var parsedKeys:Array<FlxKey> = [];
                        for (item in arr) {
                            if (Std.isOfType(item, Int)) {
                                parsedKeys.push(cast item);
                            } else if (Std.isOfType(item, String)) {
                                var k = FlxKey.fromString(item);
                                if (k != NONE) parsedKeys.push(k);
                            }
                        }
                        if (parsedKeys.length > 0) keyBinds.set(action, parsedKeys);
                    }
                }
            } catch (e:Dynamic) {
                Logger.warn('Failed restoring custom keybinds: $e', "input");
            }
        }

        if (FlxG.save.data != null && FlxG.save.data.customPadBinds != null) {
            try {
                var rawPads:Dynamic = FlxG.save.data.customPadBinds;
                for (action in Reflect.fields(rawPads)) {
                    var arr:Array<Dynamic> = Reflect.field(rawPads, action);
                    if (arr != null && padBinds.exists(action)) {
                        var parsedPads:Array<FlxGamepadInputID> = [];
                        for (item in arr) {
                            if (Std.isOfType(item, Int)) {
                                parsedPads.push(cast item);
                            } else if (Std.isOfType(item, String)) {
                                var b = FlxGamepadInputID.fromString(item);
                                if (b != NONE) parsedPads.push(b);
                            }
                        }
                        if (parsedPads.length > 0) padBinds.set(action, parsedPads);
                    }
                }
            } catch (e:Dynamic) {
                Logger.warn('Failed restoring custom pad binds: $e', "input");
            }
        }
    }

    public static function saveBindings():Void {
        if (FlxG.save.data != null) {
            var serializedKeys:Dynamic = {};
            for (action => keys in keyBinds) {
                var intArr:Array<Int> = [];
                for (k in keys) intArr.push(cast k);
                Reflect.setField(serializedKeys, action, intArr);
            }

            var serializedPads:Dynamic = {};
            for (action => pads in padBinds) {
                var intArr:Array<Int> = [];
                for (p in pads) intArr.push(cast p);
                Reflect.setField(serializedPads, action, intArr);
            }

            FlxG.save.data.customKeyBinds = serializedKeys;
            FlxG.save.data.customPadBinds = serializedPads;
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
        return checkKeys(norm, 0) || checkGamepad(norm, 0) || checkMobile(norm, 0);
    }

    public static function justPressed(action:String):Bool {
        var norm = normalizeAction(action);
        return checkKeys(norm, 1) || checkGamepad(norm, 1) || checkMobile(norm, 1);
    }

    public static function justReleased(action:String):Bool {
        var norm = normalizeAction(action);
        return checkKeys(norm, 2) || checkGamepad(norm, 2) || checkMobile(norm, 2);
    }

    private static function checkKeys(action:String, state:Int):Bool {
        var keys = keyBinds.get(action);
        if (keys == null || keys.length == 0) return false;

        for (key in keys) {
            var keyCode:Int = cast key;
            if (state == 0 && nativeKeysHeld.exists(keyCode)) return true;
            if (state == 1 && nativeKeysPressed.exists(keyCode)) {
                nativeKeysPressed.remove(keyCode);
                return true;
            }
            if (state == 2 && nativeKeysReleased.exists(keyCode)) {
                nativeKeysReleased.remove(keyCode);
                return true;
            }
        }

        return switch (state) {
            case 0: FlxG.keys.anyPressed(keys);
            case 1: FlxG.keys.anyJustPressed(keys);
            case 2: FlxG.keys.anyJustReleased(keys);
            default: false;
        };
    }

    private static function checkGamepad(action:String, state:Int):Bool {
        var buttons = padBinds.get(action);
        if (buttons == null || buttons.length == 0) return false;

        var gamepad:FlxGamepad = FlxG.gamepads.lastActive;
        if (gamepad != null) {
            return switch (state) {
                case 0: gamepad.anyPressed(buttons);
                case 1: gamepad.anyJustPressed(buttons);
                case 2: gamepad.anyJustReleased(buttons);
                default: false;
            };
        }

        for (pad in FlxG.gamepads.getActiveGamepads()) {
            if (pad != null) {
                var triggered = switch (state) {
                    case 0: pad.anyPressed(buttons);
                    case 1: pad.anyJustPressed(buttons);
                    case 2: pad.anyJustReleased(buttons);
                    default: false;
                };
                if (triggered) return true;
            }
        }

        return false;
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
            case "pause": mobilePad.buttonPause;
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
            return formatKeyName(keys[slot].toString());
        }
        return "---";
    }

    public static function getPadLabel(action:String, slot:Int = 0):String {
        var norm = normalizeAction(action);
        var pads = padBinds.get(norm);
        if (pads != null && slot < pads.length && pads[slot] != NONE) {
            return pads[slot].toString().replace("DPAD_", "").replace("LEFT_STICK_DIGITAL_", "L_STICK_");
        }
        return "---";
    }

    public static function formatKeyName(name:String):String {
        if (name == null) return "---";
        var clean = name.toUpperCase().trim();
        return switch (clean) {
            case "CONTROL": "CTRL";
            case "ESCAPE": "ESC";
            case "BACKSPACE": "BKSP";
            case "DELETE": "DEL";
            case "PAGEUP": "PGUP";
            case "PAGEDOWN": "PGDN";
            case "CAPSLOCK": "CAPS";
            case "NUMPADZERO": "NUM_0";
            case "NUMPADONE": "NUM_1";
            case "NUMPADTWO": "NUM_2";
            case "NUMPADTHREE": "NUM_3";
            case "NUMPADFOUR": "NUM_4";
            case "NUMPADFIVE": "NUM_5";
            case "NUMPADSIX": "NUM_6";
            case "NUMPADSEVEN": "NUM_7";
            case "NUMPADEIGHT": "NUM_8";
            case "NUMPADNINE": "NUM_9";
            case "NUMPADMINUS": "NUM_-";
            case "NUMPADPLUS": "NUM_+";
            case "NUMPADPERIOD": "NUM_.";
            case "NUMPADMULTIPLY": "NUM_*";
            case "ZERO": "0";
            case "ONE": "1";
            case "TWO": "2";
            case "THREE": "3";
            case "FOUR": "4";
            case "FIVE": "5";
            case "SIX": "6";
            case "SEVEN": "7";
            case "EIGHT": "8";
            case "NINE": "9";
            default: clean;
        };
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