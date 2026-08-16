package soulscorch.ui;

import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.events.KeyboardEvent;
import openfl.ui.Keyboard;
import soulscorch.modding.Script;
import soulscorch.core.Logger;

class DevConsole extends Sprite {
    public static var instance:DevConsole;

    var bg:Sprite;
    var logText:TextField;
    var inputField:TextField;
    var logs:Array<String> = [];
    var maxLogs:Int = 18;
    var consoleScript:Script;

    public function new() {
        super();
        instance = this;

        bg = new Sprite();
        bg.graphics.beginFill(0x000000, 0.8);
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
        inputField.defaultTextFormat = inputFormat;
        inputField.text = "> [Open Console]";
        addChild(inputField);

        visible = false;
        consoleScript = new Script("");

        openfl.Lib.current.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
    }

    public function log(msg:String):Void {
        logs.push(msg);
        if (logs.length > maxLogs) logs.shift();
        logText.text = logs.join("\n");
        Logger.info("devconsole", msg);
    }

    private function onKeyDown(e:KeyboardEvent):Void {
        if (e.keyCode == 192 || e.keyCode == Keyboard.F2) { // Tilde (~) or F2
            visible = !visible;
        }
    }

    public function executeCommand(code:String):Void {
        try {
            consoleScript.interp.variables.set("FlxG", flixel.FlxG);
            consoleScript.interp.variables.set("state", flixel.FlxG.state);
            var result = consoleScript.interp.execute(consoleScript.parser.parseString(code));
            log('[EXEC] ' + code + ' => ' + Std.string(result));
        } catch (e:Dynamic) {
            log('[ERROR] ' + Std.string(e));
        }
    }
}