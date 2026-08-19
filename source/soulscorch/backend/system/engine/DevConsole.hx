package soulscorch.backend.system.engine;

import flixel.FlxG;
import flixel.math.FlxMath;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import hscript.Interp;
import hscript.Parser;
import openfl.Lib;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.ui.Keyboard;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.input.Controls;
import soulscorch.backend.utils.Logger;
import soulscorch.graphics.shaders.ShaderManager;

using StringTools;

class DevConsole extends Sprite {
    public static var instance(get, null):DevConsole;
    private static var _instance:DevConsole;

    private var bg:Sprite;
    private var logText:TextField;
    private var inputField:TextField;
    private var logs:Array<String> = [];
    private var maxLogs:Int = 18;

    private var commandHistory:Array<String> = [];
    private var historyIndex:Int = -1;

    private var parser:Parser;
    private var interp:Interp;

    public function new() {
        super();
        _instance = this;

        bg = new Sprite();
        addChild(bg);

        var format = new TextFormat("_sans", 13, 0xFFFFFF);

        logText = new TextField();
        logText.x = 10;
        logText.y = 10;
        logText.defaultTextFormat = format;
        logText.selectable = false;
        logText.mouseEnabled = false;
        addChild(logText);

        var inputFormat = new TextFormat("_sans", 13, 0xFFFF00);
        inputField = new TextField();
        inputField.x = 10;
        inputField.type = INPUT;
        inputField.defaultTextFormat = inputFormat;
        inputField.text = "";
        addChild(inputField);

        visible = false;

        parser = new Parser();
        parser.allowTypes = true;
        parser.allowJSON = true;
        interp = new Interp();

        resizeUI();

        Lib.current.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
        Lib.current.stage.addEventListener(Event.RESIZE, function(_) resizeUI());
    }

    public static inline function get_instance():DevConsole {
        if (_instance == null) {
            _instance = new DevConsole();
            Lib.current.stage.addChild(_instance);
        }
        return _instance;
    }

    private function resizeUI():Void {
        var stageW = (Lib.current.stage != null) ? Lib.current.stage.stageWidth : 1280;
        var stageH = (Lib.current.stage != null) ? Lib.current.stage.stageHeight : 720;
        var conH = Math.min(320, stageH * 0.45);

        bg.graphics.clear();
        bg.graphics.beginFill(0x0C0914, 0.90);
        bg.graphics.drawRect(0, 0, stageW, conH);
        bg.graphics.lineStyle(2, 0x00FFCC, 0.8);
        bg.graphics.moveTo(0, conH);
        bg.graphics.lineTo(stageW, conH);
        bg.graphics.endFill();

        logText.width = stageW - 20;
        logText.height = conH - 45;

        inputField.y = conH - 30;
        inputField.width = stageW - 20;
        inputField.height = 25;
    }

    public function log(msg:String):Void {
        logs.push(msg);
        if (logs.length > maxLogs) logs.shift();
        logText.text = logs.join("\n");
    }

    private function onKeyDown(e:KeyboardEvent):Void {
        if (e.keyCode == 192 || e.keyCode == Keyboard.F2) { // Tilde (~) or F2[cite: 83]
            visible = !visible;
            if (visible) {
                Lib.current.stage.focus = inputField;
                inputField.text = "";
                historyIndex = -1;
            } else {
                Lib.current.stage.focus = null;
            }
        } else if (visible) {
            if (e.keyCode == Keyboard.ENTER) {
                var cmd = inputField.text.trim();
                if (cmd.length > 0) {
                    commandHistory.push(cmd);
                    historyIndex = commandHistory.length;
                    executeCommand(cmd);
                    inputField.text = "";
                }
            } else if (e.keyCode == Keyboard.UP) {
                if (commandHistory.length > 0 && historyIndex > 0) {
                    historyIndex--;
                    inputField.text = commandHistory[historyIndex];
                    inputField.setSelection(inputField.text.length, inputField.text.length);
                }
            } else if (e.keyCode == Keyboard.DOWN) {
                if (commandHistory.length > 0 && historyIndex < commandHistory.length - 1) {
                    historyIndex++;
                    inputField.text = commandHistory[historyIndex];
                    inputField.setSelection(inputField.text.length, inputField.text.length);
                } else {
                    historyIndex = commandHistory.length;
                    inputField.text = "";
                }
            }
        }
    }

    public function executeCommand(code:String):Void {
        try {
            interp.variables.set("FlxG", FlxG);
            interp.variables.set("state", FlxG.state);
            interp.variables.set("game", FlxG.state);
            interp.variables.set("Engine", Engine.instance);
            interp.variables.set("Runtime", Runtime.engine);
            interp.variables.set("Paths", Paths);
            interp.variables.set("Conductor", Conductor);
            interp.variables.set("Controls", Controls.instance);
            interp.variables.set("ShaderManager", ShaderManager.instance);
            interp.variables.set("FlxTween", FlxTween);
            interp.variables.set("FlxEase", FlxEase);
            interp.variables.set("FlxMath", FlxMath);
            interp.variables.set("clear", function() {
                logs = [];
                logText.text = "";
            });

            var program = parser.parseString(code);
            var result = interp.execute(program);
            log('[EXEC] $code => ' + Std.string(result));
        } catch (e:Dynamic) {
            log('[ERROR] ' + Std.string(e));
        }
    }
}