package soulscorch.scripting.backends;

import flixel.FlxG;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.system.EventBus;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.ModLoader;
import soulscorch.scripting.ScriptInstance;

typedef SoulInstruction = {
    var command:String;
    var args:Array<String>;
    var lineNumber:Int;
}

class SoulScript implements ScriptInstance {
    public var active:Bool = false;
    public var path(default, null):String;

    public var instructions:Array<SoulInstruction> = [];
    public var labels:Map<String, Int> = new Map();
    public var variables:Map<String, Dynamic> = new Map();
    public var programCounter:Int = 0;

    public function new(scriptPath:String) {
        this.path = (scriptPath == null) ? "" : scriptPath;
        load();
    }

    public function load():Bool {
        var fullPath = ModLoader.getPath(path);
        if (!AssetResolver.exists(fullPath)) {
            active = false;
            return false;
        }

        try {
            var rawText = AssetResolver.getText(fullPath);
            parse(rawText);
            active = true;
            return true;
        } catch (e:Dynamic) {
            Logger.error('Failed to parse SoulScript ($path): $e', "soulscript");
            active = false;
            return false;
        }
    }

    public function parse(raw:String):Void {
        instructions = [];
        labels.clear();
        programCounter = 0;

        var lines = raw.split("\n");
        for (i in 0...lines.length) {
            var line = StringTools.trim(lines[i]);
            // Skip empty lines and comments
            if (line.length == 0 || StringTools.startsWith(line, "//") || StringTools.startsWith(line, "#")) continue;

            // Handle labels (e.g. "@cutscene_start")
            if (StringTools.startsWith(line, "@") || StringTools.endsWith(line, ":")) {
                var labelName = StringTools.replace(StringTools.replace(line, "@", ""), ":", "").trim().toLowerCase();
                labels.set(labelName, instructions.length);
                continue;
            }

            var parts = line.split(" ");
            var cmd = parts[0].toUpperCase().trim();
            var args = parts.slice(1);

            instructions.push({
                command: cmd,
                args: args,
                lineNumber: i + 1
            });
        }
    }

    public function executeNext():Bool {
        if (!active || programCounter < 0 || programCounter >= instructions.length) {
            return false;
        }

        var inst = instructions[programCounter];
        programCounter++;

        switch (inst.command) {
            case "SAY", "DIALOGUE":
                var speaker = inst.args[0];
                var text = inst.args.slice(1).join(" ");
                EventBus.emit("soulscript/dialogue", {speaker: speaker, text: text});

            case "EMIT", "EVENT":
                var eventName = inst.args[0];
                var param = inst.args.slice(1).join(" ");
                EventBus.emit(eventName, param);

            case "PLAY_SOUND", "SOUND":
                var sound = inst.args[0];
                var vol = (inst.args.length > 1) ? Std.parseFloat(inst.args[1]) : 1.0;
                AssetHelper.playSoundSafely(sound, vol);

            case "JUMP", "GOTO":
                var targetLabel = inst.args[0].toLowerCase().trim();
                if (labels.exists(targetLabel)) {
                    programCounter = labels.get(targetLabel);
                }

            case "SET":
                var key = inst.args[0];
                var value = inst.args.slice(1).join(" ");
                set(key, value);

            default:
                EventBus.emit('soulscript/${inst.command.toLowerCase()}', inst.args);
        }

        return true;
    }

    public function jumpTo(label:String):Void {
        var clean = label.toLowerCase().trim();
        if (labels.exists(clean)) {
            programCounter = labels.get(clean);
        }
    }

    public function call(func:String, ?args:Array<Dynamic>):Dynamic {
        if (labels.exists(func.toLowerCase())) {
            jumpTo(func);
            return executeNext();
        }
        return null;
    }

    public function set(key:String, value:Dynamic):Void {
        variables.set(key, value);
    }

    public function get(key:String):Dynamic {
        return variables.get(key);
    }

    public function destroy():Void {
        active = false;
        instructions = [];
        labels.clear();
        variables.clear();
    }
}