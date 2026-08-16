package soulscorch.ui.menus;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.input.keyboard.FlxKey;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import soulscorch.backend.MusicBeatState;
import soulscorch.core.Runtime;
import soulscorch.core.EventBus;
import soulscorch.modding.ModManager;

class OptionsMenuState extends MusicBeatState {
    private var entries:Array<String> = [];
    private var tabEntries:Array<Array<String>> = [
        ["Downscroll", "Ghost Tapping", "Flashing Lights", "Antialiasing", "Framerate Limit", "Note Splashes"],
        ["Left", "Down", "Up", "Right"],
        ["Note Offset"]
    ];
    private var tabNames:Array<String> = ["PREFERENCES", "KEYBINDS", "AUDIO & TIMING"];
    private var tabIndex:Int = 0;
    private var tabText:FlxText;
    private var labels:Array<FlxText> = [];
    private var values:Array<FlxText> = [];
    private var selected:Int = 0;
    private var rebinding:Bool = false;
    private var noteSplashes:Bool = true;
    private var ghostTapping:Bool = true;
    private var noteOffset:Float = 0.0;
    private var framerateLimit:Int = 120;
    private var keyActions:Array<String> = ["left", "down", "up", "right"];

    override public function create():Void {
        super.create();
        loadValues();
        entries = tabEntries[tabIndex];
        var background:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF101820);
        add(background);
        var title:FlxText = new FlxText(0, 34, 0, "OPTIONS", 30);
        title.setFormat(null, 30, FlxColor.CYAN, CENTER);
        title.screenCenter(X);
        add(title);
        tabText = new FlxText(0, 72, 0, "", 16);
        tabText.setFormat(null, 16, 0xFF78C7E7, CENTER);
        tabText.screenCenter(X);
        add(tabText);
        for (i in 0...6) {
            var label:FlxText = new FlxText(130, 92 + i * 42, 500, entries[i], 20);
            var value:FlxText = new FlxText(650, 92 + i * 42, 420, "", 20);
            value.alignment = RIGHT;
            labels.push(label);
            values.push(value);
            add(label);
            add(value);
        }
        refreshView();
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        if (rebinding) {
            captureBinding();
            return;
        }
        if (FlxG.keys.justPressed.Q) switchTab(-1);
        if (FlxG.keys.justPressed.E) switchTab(1);
        if (FlxG.keys.justPressed.UP) moveSelection(-1);
        if (FlxG.keys.justPressed.DOWN) moveSelection(1);
        if (FlxG.keys.justPressed.LEFT) changeValue(-1);
        if (FlxG.keys.justPressed.RIGHT) changeValue(1);
        if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE) activate();
        if (FlxG.keys.justPressed.ESCAPE) {
            saveValues();
            FlxG.switchState(new MainMenuState());
        }
    }

    override public function beatHit(beat:Int):Void {
        if (selected >= 0 && selected < labels.length) labels[selected].scale.set(1.04, 1.04);
    }

    private function loadValues():Void {
        if (Runtime.engine != null && Runtime.engine.config != null) {
            framerateLimit = clamp(Runtime.engine.config.framerate, 30, 240);
            noteOffset = Runtime.engine.config.noteOffset;
            ghostTapping = Runtime.engine.config.ghostTapping;
        }
        if (FlxG.save != null) {
            if (FlxG.save.data.noteSplashes != null) noteSplashes = cast FlxG.save.data.noteSplashes;
            if (FlxG.save.data.noteOffset != null) noteOffset = cast FlxG.save.data.noteOffset;
            if (FlxG.save.data.ghostTapping != null) ghostTapping = cast FlxG.save.data.ghostTapping;
        }
    }

    private function saveValues():Void {
        if (Runtime.engine != null && Runtime.engine.config != null) {
            Runtime.engine.config.framerate = framerateLimit;
            Runtime.engine.config.noteOffset = noteOffset;
            Runtime.engine.config.ghostTapping = ghostTapping;
            Runtime.engine.config.save();
        }
        if (FlxG.save != null) {
            FlxG.save.data.noteSplashes = noteSplashes;
            FlxG.save.data.noteOffset = noteOffset;
            FlxG.save.data.ghostTapping = ghostTapping;
            FlxG.save.flush();
        }
        EventBus.publish("options/saved", {framerate: framerateLimit, noteOffset: noteOffset});
    }

    private function moveSelection(change:Int):Void {
        selected = (selected + change) % entries.length;
        if (selected < 0) selected += entries.length;
        refreshView();
    }

    private function activate():Void {
        if (tabIndex == 1) {
            rebinding = true;
            values[selected].text = "PRESS A KEY";
            return;
        }
        changeValue(1);
    }

    private function changeValue(direction:Int):Void {
        if (Runtime.engine == null || Runtime.engine.config == null) return;
        switch (selected) {
            case 0: Runtime.engine.config.downscroll = !Runtime.engine.config.downscroll;
            case 1: ghostTapping = !ghostTapping;
            case 2: Runtime.engine.config.flashingLights = !Runtime.engine.config.flashingLights;
            case 3: Runtime.engine.config.antialiasing = !Runtime.engine.config.antialiasing;
            case 4: framerateLimit = clamp(framerateLimit + direction * 10, 30, 240);
            case 5: noteSplashes = !noteSplashes;
            default: if (tabIndex == 2) noteOffset = Math.max(-250.0, Math.min(250.0, noteOffset + direction * 5.0));
        }
        if (tabIndex == 0 && selected == 4) {
            FlxG.updateFramerate = framerateLimit;
            FlxG.drawFramerate = framerateLimit;
        }
        refreshView();
        EventBus.publish("options/changed", {index: selected});
    }

    private function captureBinding():Void {
        var key:FlxKey = FlxG.keys.firstJustPressed();
        if (key == NONE) return;
        var action:String = keyActions[selected];
        if (Runtime.engine != null && Runtime.engine.config != null) Runtime.engine.config.binds.set(action, [key]);
        rebinding = false;
        refreshView();
    }

    private function refreshView():Void {
        if (tabText != null) tabText.text = "Q/E  CHANGE TAB    " + tabNames[tabIndex];
        for (i in 0...entries.length) {
            labels[i].color = i == selected ? FlxColor.CYAN : FlxColor.WHITE;
            labels[i].alpha = i == selected ? 1.0 : 0.7;
            values[i].text = valueFor(i);
            values[i].color = i == selected ? 0xFFFFFF00 : 0xFF808080;
        }
    }

    private function valueFor(index:Int):String {
        if (Runtime.engine == null || Runtime.engine.config == null) return "Unavailable";
        if (tabIndex == 1) return keyName(Runtime.engine.config.binds.get(keyActions[index]));
        if (tabIndex == 2) return '${Std.int(noteOffset)} ms';
        return switch (index) {
            case 0: Runtime.engine.config.downscroll ? "ON" : "OFF";
            case 1: ghostTapping ? "ON" : "OFF";
            case 2: Runtime.engine.config.flashingLights ? "ON" : "OFF";
            case 3: Runtime.engine.config.antialiasing ? "ON" : "OFF";
            case 4: '$framerateLimit FPS';
            case 5: noteSplashes ? "ON" : "OFF";
            default: "";
        };
    }

    private function switchTab(change:Int):Void {
        tabIndex = (tabIndex + change) % tabEntries.length;
        if (tabIndex < 0) tabIndex += tabEntries.length;
        entries = tabEntries[tabIndex];
        selected = 0;
        refreshView();
    }

    private static function keyName(keys:Array<FlxKey>):String {
        return keys == null || keys.length == 0 ? "UNBOUND" : Std.string(keys[0]);
    }

    private static function clamp(value:Int, minimum:Int, maximum:Int):Int return value < minimum ? minimum : value > maximum ? maximum : value;
}
