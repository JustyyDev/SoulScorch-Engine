package soulscorch.ui;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.group.FlxGroup;
import openfl.events.KeyboardEvent;
import openfl.ui.Keyboard;
import soulscorch.core.Version;

class DebugConsole extends FlxGroup {
    public static var instance:DebugConsole;

    var bg:FlxSprite;
    var logText:FlxText;
    var titleText:FlxText;
    var isOpen:Bool = false;
    var logLines:Array<String> = [];
    var maxLines:Int = 22;

    public function new() {
        super();
        instance = this;

        bg = new FlxSprite().makeGraphic(FlxG.width, 320, 0xE0000000);
        bg.visible = false;
        add(bg);

        titleText = new FlxText(16, 12, 0, "SoulScorch Debug Console (" + Version.fullVersion() + ")", 16);
        titleText.setFormat(null, 16, 0xFFFFFF, LEFT);
        titleText.visible = false;
        add(titleText);

        logText = new FlxText(16, 42, FlxG.width - 32, "", 12);
        logText.setFormat(null, 12, 0xDDEEFF, LEFT);
        logText.visible = false;
        add(logText);

        FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
        log("[BOOT] SoulScorch debug console initialized");
        log("[INFO] Press F2 to toggle the console");
    }

    function onKeyDown(event:KeyboardEvent):Void {
        if (event.keyCode == Keyboard.F2) {
            toggle();
        }
    }

    public function toggle():Void {
        isOpen = !isOpen;
        bg.visible = isOpen;
        titleText.visible = isOpen;
        logText.visible = isOpen;
    }

    public function log(msg:String):Void {
        logLines.push(msg);
        while (logLines.length > maxLines) {
            logLines.shift();
        }
        if (logText != null) {
            logText.text = logLines.join("\n");
        }
    }
}
