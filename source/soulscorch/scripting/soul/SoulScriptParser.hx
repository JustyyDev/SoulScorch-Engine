package soulscorch.scripting.soul;

using StringTools;

class SoulScriptParser {
    public static function transpile(source:String):String {
        if (source == null || source.trim().length == 0) return "";

        var lines = source.split("\n");
        var output:Array<String> = [];
        var openFunctions:Int = 0;

        for (raw in lines) {
            var rawClean = raw.replace("\r", "");
            var trimmed = rawClean.trim();

            if (trimmed.length == 0 || trimmed.startsWith("#") || trimmed.startsWith("//")) {
                continue;
            }

            var header = translateHeader(trimmed);
            if (header != null) {
                // If a previous function block was already open, close it before opening the next
                if (openFunctions > 0) {
                    output.push("}");
                    openFunctions--;
                }
                output.push(header);
                openFunctions++;
                continue;
            }

            var strumTween = translateStrumTween(trimmed);
            if (strumTween != null) {
                output.push("    " + strumTween);
                continue;
            }

            var vec3Tween = translateVector3Tween(trimmed);
            if (vec3Tween != null) {
                output.push("    " + vec3Tween);
                continue;
            }

            var shaderTween = translateShaderTween(trimmed);
            if (shaderTween != null) {
                output.push("    " + shaderTween);
                continue;
            }

            var tween = translateTween(trimmed);
            if (tween != null) {
                output.push("    " + tween);
                continue;
            }

            var statement = translateMacros(trimmed);
            if (statement == null) statement = trimmed;

            // Avoid injecting duplicate semicolons around braces or existing terminals
            if (!statement.endsWith(";") && !statement.endsWith("{") && !statement.endsWith("}")) {
                statement += ";";
            }

            output.push("    " + statement);
        }

        while (openFunctions > 0) {
            output.push("}");
            openFunctions--;
        }

        return output.join("\n");
    }

    private static function translateHeader(line:String):String {
        var clean = line.trim();

        var atBeat = ~/^at beat (-?\d+(?:\.\d+)?)\s*:/i;
        if (atBeat.match(clean)) return "if (curBeat == " + atBeat.matched(1) + ") {";

        var everyBeat = ~/^every (\d+(?:\.\d+)?) beats\s*:/i;
        if (everyBeat.match(clean)) return "if (curBeat % " + everyBeat.matched(1) + " == 0) {";

        var atStep = ~/^at step (-?\d+(?:\.\d+)?)\s*:/i;
        if (atStep.match(clean)) return "if (curStep == " + atStep.matched(1) + ") {";

        var everyStep = ~/^every (\d+(?:\.\d+)?) steps\s*:/i;
        if (everyStep.match(clean)) return "if (curStep % " + everyStep.matched(1) + " == 0) {";

        var sEvent = ~/^on songEvent\("([^"]+)"(?:,\s*([A-Za-z0-9_]+))?(?:,\s*([A-Za-z0-9_]+))?\)\s*:/i;
        if (sEvent.match(clean)) {
            var name = sEvent.matched(1);
            var v1 = sEvent.matched(2) != null ? sEvent.matched(2) : "value1";
            var v2 = sEvent.matched(3) != null ? sEvent.matched(3) : "value2";
            return 'if (eventName == "$name") { var $v1 = eventVal1; var $v2 = eventVal2;';
        }

        if (~/^on (create|onCreate|globalInit|onGlobalInit)\s*:/i.match(clean)) return "function create() {";
        if (~/^on (postCreate|onPostCreate)\s*:/i.match(clean)) return "function onPostCreate() {";
        if (~/^on (update|onUpdate|globalUpdate|onGlobalUpdate)\s*:/i.match(clean)) return "function onUpdate(elapsed) {";
        if (~/^on (updatePost|onUpdatePost)\s*:/i.match(clean)) return "function onUpdatePost(elapsed) {";
        if (~/^on (beatHit|onBeatHit)\s*:/i.match(clean)) return "function onBeatHit(curBeat) {";
        if (~/^on (stepHit|onStepHit)\s*:/i.match(clean)) return "function onStepHit(curStep) {";
        if (~/^on (preStateSwitch|onPreStateSwitch)\s*:/i.match(clean)) return "function onPreStateSwitch() {";
        if (~/^on (postStateSwitch|onPostStateSwitch|stateSwitch|onStateSwitch)\s*:/i.match(clean)) return "function onStateSwitch() {";
        if (~/^on (destroy|onDestroy)\s*:/i.match(clean)) return "function onDestroy() {";

        var evt = ~/^on event\("([^"]+)"\)\s*:/i;
        if (evt.match(clean)) return 'if (eventName == "' + evt.matched(1) + '") {';

        return null;
    }

    private static function translateStrumTween(line:String):String {
        var clean = line.trim();
        var reg = ~/^strumline\.(player|opponent)\[([0-3])\]\.([A-Za-z0-9_]+)\s*->\s*(.*?)\s+in\s+([0-9.]+)s?(?:\s*\(([^)]+)\))?;?$/i;
        if (!reg.match(clean)) return null;

        var group = reg.matched(1) == "player" ? "game.playerStrumline.receptors" : "game.opponentStrumline.receptors";
        var idx = reg.matched(2);
        var prop = reg.matched(3);
        var val = reg.matched(4);
        var dur = reg.matched(5);
        var ease = reg.matched(6) != null ? reg.matched(6) : "linear";

        return 'FlxTween.tween($group[$idx], {$prop: $val}, $dur, {ease: FlxEase.$ease});';
    }

    private static function translateTween(line:String):String {
        var clean = line.trim();
        var regex = ~/^([A-Za-z_][A-Za-z0-9_.]*)\.([A-Za-z_][A-Za-z0-9_]*)\s*->\s*(.*?)\s+in\s+([0-9.]+)s?(?:\s*\(([^)]+)\))?;?$/;
        if (!regex.match(clean)) return null;

        var target = regex.matched(1);
        var prop = regex.matched(2);
        var value = regex.matched(3);
        var dur = regex.matched(4);
        var ease = regex.matched(5) != null ? regex.matched(5) : "linear";

        return 'FlxTween.tween(' + target + ', {' + prop + ': ' + value + '}, ' + dur + ', {ease: FlxEase.' + ease + '});';
    }

    private static function translateVector3Tween(line:String):String {
        var clean = line.trim();
        var regex = ~/^([A-Za-z_][A-Za-z0-9_.]*)\.(position|target|rotation|scale)\s*->\s*\[\s*(-?[0-9.]+)\s*,\s*(-?[0-9.]+)\s*,\s*(-?[0-9.]+)\s*\]\s+in\s+([0-9.]+)s?(?:\s*\(([^)]+)\))?;?$/;
        if (!regex.match(clean)) return null;

        var target = regex.matched(1);
        var prop = regex.matched(2);
        var x = regex.matched(3);
        var y = regex.matched(4);
        var z = regex.matched(5);
        var dur = regex.matched(6);
        var ease = regex.matched(7) != null ? regex.matched(7) : "linear";

        return 'FlxTween.tween(' + target + '.' + prop + ', {x: ' + x + ', y: ' + y + ', z: ' + z + '}, ' + dur + ', {ease: FlxEase.' + ease + '});';
    }

    private static function translateShaderTween(line:String):String {
        var clean = line.trim();
        var regex = ~/^shader\.([A-Za-z0-9_]+)\.([A-Za-z0-9_]+)\s*->\s*([0-9.]+)\s+in\s+([0-9.]+)s?(?:\s*\(([^)]+)\))?;?$/;
        if (!regex.match(clean)) return null;

        var shaderVar = regex.matched(1);
        var uniform = regex.matched(2);
        var targetVal = regex.matched(3);
        var dur = regex.matched(4);
        var ease = regex.matched(5) != null ? regex.matched(5) : "linear";

        return 'FlxTween.num(' + shaderVar + '.getFloat("' + uniform + '"), ' + targetVal + ', ' + dur + ', {ease: FlxEase.' + ease + '}, function(v) { ' + shaderVar + '.setFloat("' + uniform + '", v); });';
    }

    private static function translateMacros(line:String):String {
        var clean = line.trim();

        var shake = ~/^screen\.shake\(([0-9.]+),\s*([0-9.]+)s?\);?$/i;
        if (shake.match(clean)) return 'FlxG.camera.shake(' + shake.matched(1) + ', ' + shake.matched(2) + ');';

        var bump = ~/^camera\.bump\(([0-9.]+)\);?$/i;
        if (bump.match(clean)) return 'FlxG.camera.zoom += ' + bump.matched(1) + ';';

        var snd = ~/^playSound\("([^"]+)"(?:,\s*([0-9.]+))?\);?$/i;
        if (snd.match(clean)) {
            var vol = snd.matched(2) != null ? snd.matched(2) : "1.0";
            return 'soulscorch.backend.assets.AssetHelper.playSoundSafely("' + snd.matched(1) + '", ' + vol + ');';
        }

        return null;
    }
}