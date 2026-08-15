package soulscorch.input;

import flixel.FlxG;
import flixel.input.keyboard.FlxKey;
import soulscorch.core.Runtime;

class InputMap {
    public static function pressed(action:String):Bool {
        var binds = getBinds(action);
        if (binds == null) return false;
        
        for (key in binds) {
            if (FlxG.keys.checkStatus(key, PRESSED)) return true;
        }
        return false;
    }

    public static function justPressed(action:String):Bool {
        var binds = getBinds(action);
        if (binds == null) return false;
        
        for (key in binds) {
            if (FlxG.keys.checkStatus(key, JUST_PRESSED)) return true;
        }
        return false;
    }

    public static function justReleased(action:String):Bool {
        var binds = getBinds(action);
        if (binds == null) return false;
        
        for (key in binds) {
            if (FlxG.keys.checkStatus(key, JUST_RELEASED)) return true;
        }
        return false;
    }

    private static function getBinds(action:String):Array<FlxKey> {
        if (Runtime.engine == null || Runtime.engine.config == null) {
            return getDefaultBinds(action);
        }
        
        var binds = Runtime.engine.config.binds.get(action);
        return binds != null ? binds : getDefaultBinds(action);
    }

    private static function getDefaultBinds(action:String):Array<FlxKey> {
        return switch (action) {
            case "left": [A, LEFT];
            case "down": [S, DOWN];
            case "up": [W, UP];
            case "right": [D, RIGHT];
            case "accept": [SPACE, ENTER];
            case "back": [BACKSPACE, ESCAPE];
            case "pause": [ENTER, ESCAPE];
            default: [];
        };
    }
}