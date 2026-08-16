package soulscorch.scripting.soul;

import StringTools;

class SoulScriptParser {
    public static function transpile(source:String):String {
        if (source == null) return ""; var output:Array<String> = []; var indent:Int = 0;
        for (raw in source.split("\n")) {
            var line:String = StringTools.trim(StringTools.replace(raw, "\r", "")); if (line.length == 0 || line.indexOf("#") == 0) continue;
            if (line == "end" || line == "}") { indent = Std.int(Math.max(0, indent - 1)); continue; }
            var header:String = translateHeader(line); if (header != null) { output.push(spaces(indent) + header); indent++; continue; }
            var tween:String = translateTween(line); output.push(spaces(indent) + (tween == null ? line : tween));
        }
        while (indent-- > 0) output.push("}"); return output.join("\n");
    }
    private static function translateHeader(line:String):String {
        var at:EReg = ~/^at beat (-?\d+(?:\.\d+)?)\s*:/i; var every:EReg = ~/^every (\d+(?:\.\d+)?) beats\s*:/i; var note:EReg = ~/^on noteHit\((.*)\)\s*:/i;
        if (at.match(line)) return "if (curBeat == " + at.matched(1) + ") {";
        if (every.match(line)) return "if (curBeat % " + every.matched(1) + " == 0) {";
        if (note.match(line)) return 'if (event == "noteHit" && (' + note.matched(1) + ')) {';
        return null;
    }
    private static function translateTween(line:String):String {
        var regex:EReg = ~/^([A-Za-z_][A-Za-z0-9_.]*)\.([A-Za-z_][A-Za-z0-9_]*)\s*->\s*(.*?)\s+in\s+([0-9.]+)s(?:\s*\(([^)]+)\))?$/;
        if (!regex.match(line)) return null; var ease:String = regex.matched(5); if (ease == null || ease.length == 0) ease = "linear";
        return 'FlxTween.tween(' + regex.matched(1) + ', {' + regex.matched(2) + ': ' + regex.matched(3) + '}, ' + regex.matched(4) + ', {ease: FlxEase.' + ease + '});';
    }
    private static function spaces(count:Int):String { var result:String = ""; for (i in 0...count) result += "    "; return result; }
}
