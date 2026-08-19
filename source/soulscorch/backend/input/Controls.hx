package soulscorch.backend.input;

import soulscorch.backend.input.InputMap;
import soulscorch.backend.input.MobilePad;

class Controls {
    public static var instance(get, null):Controls;
    private static var _instance:Controls;

    public var enabled:Bool = true;

    public static inline function get_instance():Controls {
        if (_instance == null) {
            _instance = new Controls();
            InputMap.init();
        }
        return _instance;
    }

    public function new() {}

    public function bindMobilePad(pad:MobilePad):Void {
        InputMap.bindMobilePad(pad);
    }

    public function unbindMobilePad():Void {
        InputMap.unbindMobilePad();
    }

    // --- Note Gameplay Inputs ---
    public var NOTE_LEFT(get, never):Bool;
    inline function get_NOTE_LEFT():Bool return enabled && InputMap.pressed("note_left");

    public var NOTE_LEFT_P(get, never):Bool;
    inline function get_NOTE_LEFT_P():Bool return enabled && InputMap.justPressed("note_left");

    public var NOTE_LEFT_R(get, never):Bool;
    inline function get_NOTE_LEFT_R():Bool return enabled && InputMap.justReleased("note_left");

    public var NOTE_DOWN(get, never):Bool;
    inline function get_NOTE_DOWN():Bool return enabled && InputMap.pressed("note_down");

    public var NOTE_DOWN_P(get, never):Bool;
    inline function get_NOTE_DOWN_P():Bool return enabled && InputMap.justPressed("note_down");

    public var NOTE_DOWN_R(get, never):Bool;
    inline function get_NOTE_DOWN_R():Bool return enabled && InputMap.justReleased("note_down");

    public var NOTE_UP(get, never):Bool;
    inline function get_NOTE_UP():Bool return enabled && InputMap.pressed("note_up");

    public var NOTE_UP_P(get, never):Bool;
    inline function get_NOTE_UP_P():Bool return enabled && InputMap.justPressed("note_up");

    public var NOTE_UP_R(get, never):Bool;
    inline function get_NOTE_UP_R():Bool return enabled && InputMap.justReleased("note_up");

    public var NOTE_RIGHT(get, never):Bool;
    inline function get_NOTE_RIGHT():Bool return enabled && InputMap.pressed("note_right");

    public var NOTE_RIGHT_P(get, never):Bool;
    inline function get_NOTE_RIGHT_P():Bool return enabled && InputMap.justPressed("note_right");

    public var NOTE_RIGHT_R(get, never):Bool;
    inline function get_NOTE_RIGHT_R():Bool return enabled && InputMap.justReleased("note_right");

    // --- UI Navigation Inputs ---
    public var UI_LEFT(get, never):Bool;
    inline function get_UI_LEFT():Bool return enabled && InputMap.pressed("ui_left");

    public var UI_LEFT_P(get, never):Bool;
    inline function get_UI_LEFT_P():Bool return enabled && InputMap.justPressed("ui_left");

    public var UI_LEFT_R(get, never):Bool;
    inline function get_UI_LEFT_R():Bool return enabled && InputMap.justReleased("ui_left");

    public var UI_DOWN(get, never):Bool;
    inline function get_UI_DOWN():Bool return enabled && InputMap.pressed("ui_down");

    public var UI_DOWN_P(get, never):Bool;
    inline function get_UI_DOWN_P():Bool return enabled && InputMap.justPressed("ui_down");

    public var UI_DOWN_R(get, never):Bool;
    inline function get_UI_DOWN_R():Bool return enabled && InputMap.justReleased("ui_down");

    public var UI_UP(get, never):Bool;
    inline function get_UI_UP():Bool return enabled && InputMap.pressed("ui_up");

    public var UI_UP_P(get, never):Bool;
    inline function get_UI_UP_P():Bool return enabled && InputMap.justPressed("ui_up");

    public var UI_UP_R(get, never):Bool;
    inline function get_UI_UP_R():Bool return enabled && InputMap.justReleased("ui_up");

    public var UI_RIGHT(get, never):Bool;
    inline function get_UI_RIGHT():Bool return enabled && InputMap.pressed("ui_right");

    public var UI_RIGHT_P(get, never):Bool;
    inline function get_UI_RIGHT_P():Bool return enabled && InputMap.justPressed("ui_right");

    public var UI_RIGHT_R(get, never):Bool;
    inline function get_UI_RIGHT_R():Bool return enabled && InputMap.justReleased("ui_right");

    // --- System & Menu Triggers ---
    public var ACCEPT(get, never):Bool;
    inline function get_ACCEPT():Bool return enabled && InputMap.justPressed("accept");

    public var BACK(get, never):Bool;
    inline function get_BACK():Bool return enabled && InputMap.justPressed("back");

    public var PAUSE(get, never):Bool;
    inline function get_PAUSE():Bool return enabled && InputMap.justPressed("pause");

    public var RESET(get, never):Bool;
    inline function get_RESET():Bool return enabled && InputMap.justPressed("reset");

    public var DEBUG(get, never):Bool;
    inline function get_DEBUG():Bool return enabled && InputMap.justPressed("debug");

    public var VOLUME_MUTE(get, never):Bool;
    inline function get_VOLUME_MUTE():Bool return InputMap.justPressed("volume_mute");

    public var VOLUME_DOWN(get, never):Bool;
    inline function get_VOLUME_DOWN():Bool return InputMap.justPressed("volume_down");

    public var VOLUME_UP(get, never):Bool;
    inline function get_VOLUME_UP():Bool return InputMap.justPressed("volume_up");

    public var FULLSCREEN(get, never):Bool;
    inline function get_FULLSCREEN():Bool return InputMap.justPressed("fullscreen");

    // --- Lane Array Helpers ---
    public function notePressed(lane:Int):Bool {
        if (!enabled) return false;
        return switch (lane % 4) {
            case 0: NOTE_LEFT;
            case 1: NOTE_DOWN;
            case 2: NOTE_UP;
            case 3: NOTE_RIGHT;
            default: false;
        };
    }

    public function noteJustPressed(lane:Int):Bool {
        if (!enabled) return false;
        return switch (lane % 4) {
            case 0: NOTE_LEFT_P;
            case 1: NOTE_DOWN_P;
            case 2: NOTE_UP_P;
            case 3: NOTE_RIGHT_P;
            default: false;
        };
    }

    public function noteJustReleased(lane:Int):Bool {
        if (!enabled) return false;
        return switch (lane % 4) {
            case 0: NOTE_LEFT_R;
            case 1: NOTE_DOWN_R;
            case 2: NOTE_UP_R;
            case 3: NOTE_RIGHT_R;
            default: false;
        };
    }

    public function anyNotePressed():Bool {
        return enabled && (NOTE_LEFT || NOTE_DOWN || NOTE_UP || NOTE_RIGHT);
    }

    public function anyNoteJustPressed():Bool {
        return enabled && (NOTE_LEFT_P || NOTE_DOWN_P || NOTE_UP_P || NOTE_RIGHT_P);
    }

    public function getPressedLanes():Array<Int> {
        if (!enabled) return [];
        var result:Array<Int> = [];
        if (NOTE_LEFT) result.push(0);
        if (NOTE_DOWN) result.push(1);
        if (NOTE_UP) result.push(2);
        if (NOTE_RIGHT) result.push(3);
        return result;
    }
}