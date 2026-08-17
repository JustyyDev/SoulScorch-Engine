package soulscorch.backend.system.engine;

import hscript.Interp;
import hscript.Parser;
import openfl.Lib;
import openfl.display.Sprite;
import openfl.events.KeyboardEvent;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.ui.Keyboard;
import soulscorch.backend.utils.Logger;

class DevConsole extends Sprite {
    public static var instance(get, null):DevConsole;
    private static var _instance:DevConsole;

    var bg:Sprite;
    var logText:TextField;
    var inputField:TextField;
    var logs:Array<String> = [];
    var maxLogs:Int = 18;

    var parser:Parser;
    var interp:Interp;

    public function new() {
        super();
        _instance = this;

        bg = new Sprite();
        bg.graphics.beginFill(0x000000, 0.85);
        bg.graphics.drawRect(0, 0, 1280, 320);
        bg.graphics.endFill();
        addChild(bg);

        var format = new TextFormat("_sans", 13, 0xFFFFFF);

        logText = new TextField();
        logText.x = 10;
        logText.y = 10;
        logText.width = 1260;
        logText.height = 270;
        logText.defaultTextFormat = format;
        logText.selectable = false;
        logText.mouseEnabled = false;
        addChild(logText);

        var inputFormat = new TextFormat("_sans", 13, 0xFFFF00);
        inputField = new TextField();
        inputField.x = 10;
        inputField.y = 290;
        inputField.width = 1260;
        inputField.height = 25;
        inputField.type = INPUT;
        inputField.defaultTextFormat = inputFormat;
        inputField.text = "";
        addChild(inputField);

        visible = false;

        parser = new Parser();
        parser.allowTypes = true;
        parser.allowJSON = true;
        interp = new Interp();

        Lib.current.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
    }

    public static inline function get_instance():DevConsole {
        if (_instance == null) {
            _instance = new DevConsole();
            Lib.current.stage.addChild(_instance);
        }
        return _instance;
    }

    public function log(msg:String):Void {
        logs.push(msg);
        if (logs.length > maxLogs) logs.shift();
        logText.text = logs.join("\n");
        Logger.info(msg);
    }

    private function onKeyDown(e:KeyboardEvent):Void {
        if (e.keyCode == 192 || e.keyCode == Keyboard.F2) { // Tilde (~) or F2[cite: 43]
            visible = !visible;
            if (visible) {
                Lib.current.stage.focus = inputField;
                inputField.text = "";
            }
        } else if (visible && e.keyCode == Keyboard.ENTER) {
            var cmd = StringTools.trim(inputField.text);
            if (cmd.length > 0) {
                executeCommand(cmd);
                inputField.text = "";
            }
        }
    }

    public function executeCommand(code:String):Void {
        try {
            interp.variables.set("FlxG", flixel.FlxG);
            interp.variables.set("state", flixel.FlxG.state);
            interp.variables.set("Engine", Engine.instance);
            interp.variables.set("Runtime", Runtime.engine);

            var program = parser.parseString(code);
            var result = interp.execute(program);
            log('[EXEC] $code => ' + Std.string(result));
        } catch (e:Dynamic) {
            log('[ERROR] ' + Std.string(e));
        }
    }
}