package soulscorch.scripting.soul;

using StringTools;

class SoulScriptParser {
    public static function transpile(source:String):String {
        if (source == null || source.trim().length == 0) return "";

        var lines = source.split("\n");
        var output:Array<String> = [];
        var indentStack:Array<Int> = [0];

        for (raw in lines) {
            var rawClean = raw.replace("\r", "");
            var trimmed = rawClean.trim();

            if (trimmed.length == 0 || trimmed.startsWith("#") || trimmed.startsWith("//")) {
                continue;
            }

            var currentIndent = getIndentLevel(rawClean);

            while (indentStack.length > 1 && currentIndent < indentStack[indentStack.length - 1]) {
                indentStack.pop();
                output.push(getIndentation(indentStack.length - 1) + "}");
            }

            var header = translateHeader(trimmed);
            if (header != null) {
                output.push(getIndentation(indentStack.length - 1) + header);
                indentStack.push(currentIndent + 4);
                continue;
            }

            var tween = translateAnyTween(trimmed);
            if (tween != null) {
                output.push(getIndentation(indentStack.length - 1) + tween);
                continue;
            }

            var macroCode = translateMacros(trimmed);
            if (macroCode != null) {
                output.push(getIndentation(indentStack.length - 1) + macroCode);
                continue;
            }

            var statement = trimmed;
            if (!statement.endsWith(";") && !statement.endsWith("{") && !statement.endsWith("}")) {
                statement += ";";
            }

            output.push(getIndentation(indentStack.length - 1) + statement);
        }

        while (indentStack.length > 1) {
            indentStack.pop();
            output.push(getIndentation(indentStack.length - 1) + "}");
        }

        return output.join("\n");
    }

    private static function getIndentLevel(line:String):Int {
        var count = 0;
        for (i in 0...line.length) {
            var c = line.charAt(i);
            if (c == " ") count += 1;
            else if (c == "\t") count += 4;
            else break;
        }
        return count;
    }

    private static inline function getIndentation(depth:Int):String {
        var str = "";
        for (_ in 0...depth) str += "    ";
        return str;
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

    private static function translateAnyTween(line:String):String {
        var clean = line.trim();

        // Strumline: strumline.player[0].y -> 100 in 1s (cubeOut)
        var strumReg = ~/^strumline\.(player|opponent)\[([0-3])\]\.([A-Za-z0-9_]+)\s*->\s*(.*?)\s+in\s+([0-9.]+)s?(?:\s*\(([^)]+)\))?;?$/i;
        if (strumReg.match(clean)) {
            var group = strumReg.matched(1) == "player" ? "game.playerStrumline.receptors" : "game.opponentStrumline.receptors";
            var idx = strumReg.matched(2);
            var prop = strumReg.matched(3);
            var val = strumReg.matched(4);
            var dur = strumReg.matched(5);
            var ease = strumReg.matched(6) != null ? strumReg.matched(6) : "linear";
            return 'FlxTween.tween($group[$idx], {$prop: $val}, $dur, {ease: FlxEase.$ease});';
        }

        // Camera Pan: camera -> [x, y] in 2s (quadInOut)
        var camReg = ~/^camera\s*->\s*\[\s*(-?[0-9.]+)\s*,\s*(-?[0-9.]+)\s*\]\s+in\s+([0-9.]+)s?(?:\s*\(([^)]+)\))?;?$/i;
        if (camReg.match(clean)) {
            var targetX = camReg.matched(1);
            var targetY = camReg.matched(2);
            var dur = camReg.matched(3);
            var ease = camReg.matched(4) != null ? camReg.matched(4) : "linear";
            return 'FlxTween.tween(FlxG.camera.scroll, {x: $targetX - (FlxG.width / 2), y: $targetY - (FlxG.height / 2)}, $dur, {ease: FlxEase.$ease});';
        }

        // Vector3: obj.position -> [x, y, z] in 1.5s
        var v3Reg = ~/^([A-Za-z_][A-Za-z0-9_.]*)\.(position|target|rotation|scale)\s*->\s*\[\s*(-?[0-9.]+)\s*,\s*(-?[0-9.]+)\s*,\s*(-?[0-9.]+)\s*\]\s+in\s+([0-9.]+)s?(?:\s*\(([^)]+)\))?;?$/i;
        if (v3Reg.match(clean)) {
            var target = v3Reg.matched(1);
            var prop = v3Reg.matched(2);
            var x = v3Reg.matched(3);
            var y = v3Reg.matched(4);
            var z = v3Reg.matched(5);
            var dur = v3Reg.matched(6);
            var ease = v3Reg.matched(7) != null ? v3Reg.matched(7) : "linear";
            return 'FlxTween.tween($target.$prop, {x: $x, y: $y, z: $z}, $dur, {ease: FlxEase.$ease});';
        }

        // Shader Uniform: shader.glitch.intensity -> 0.8 in 0.5s
        var shaderReg = ~/^shader\.([A-Za-z0-9_]+)\.([A-Za-z0-9_]+)\s*->\s*([0-9.]+)\s+in\s+([0-9.]+)s?(?:\s*\(([^)]+)\))?;?$/i;
        if (shaderReg.match(clean)) {
            var shaderVar = shaderReg.matched(1);
            var uniform = shaderReg.matched(2);
            var targetVal = shaderReg.matched(3);
            var dur = shaderReg.matched(4);
            var ease = shaderReg.matched(5) != null ? shaderReg.matched(5) : "linear";
            return 'FlxTween.num($shaderVar.getFloat("$uniform"), $targetVal, $dur, {ease: FlxEase.$ease}, function(v) { $shaderVar.setFloat("$uniform", v); });';
        }

        // Generic Property: sprite.alpha -> 0.0 in 1.25s (quadOut)
        var propReg = ~/^([A-Za-z_][A-Za-z0-9_.]*)\.([A-Za-z_][A-Za-z0-9_]*)\s*->\s*(.*?)\s+in\s+([0-9.]+)s?(?:\s*\(([^)]+)\))?;?$/;
        if (propReg.match(clean)) {
            var target = propReg.matched(1);
            var prop = propReg.matched(2);
            var value = propReg.matched(3);
            var dur = propReg.matched(4);
            var ease = propReg.matched(5) != null ? propReg.matched(5) : "linear";
            return 'FlxTween.tween($target, {$prop: $value}, $dur, {ease: FlxEase.$ease});';
        }

        return null;
    }

    private static function translateMacros(line:String):String {
        var clean = line.trim();

        var shake = ~/^screen\.shake\(([0-9.]+),\s*([0-9.]+)s?\);?$/i;
        if (shake.match(clean)) return 'FlxG.camera.shake(' + shake.matched(1) + ', ' + shake.matched(2) + ');';

        var bump = ~/^camera\.bump\(([0-9.]+)\);?$/i;
        if (bump.match(clean)) return 'FlxG.camera.zoom += ' + bump.matched(1) + ';';

        var fade = ~/^([A-Za-z_][A-Za-z0-9_.]*)\.fade\(([0-9.]+),\s*([0-9.]+)s?(?:,\s*([A-Za-z0-9_]+))?\);?$/i;
        if (fade.match(clean)) {
            var spr = fade.matched(1);
            var targetAlpha = fade.matched(2);
            var dur = fade.matched(3);
            var ease = fade.matched(4) != null ? fade.matched(4) : "linear";
            return 'FlxTween.tween($spr, {alpha: $targetAlpha}, $dur, {ease: FlxEase.$ease});';
        }

        var snd = ~/^playSound\("([^"]+)"(?:,\s*([0-9.]+))?\);?$/i;
        if (snd.match(clean)) {
            var vol = snd.matched(2) != null ? snd.matched(2) : "1.0";
            return 'soulscorch.backend.assets.AssetHelper.playSoundSafely("' + snd.matched(1) + '", ' + vol + ');';
        }

        var music = ~/^playMusic\("([^"]+)"(?:,\s*([0-9.]+))?(?:,\s*(true|false))?\);?$/i;
        if (music.match(clean)) {
            var vol = music.matched(2) != null ? music.matched(2) : "1.0";
            var loop = music.matched(3) != null ? music.matched(3) : "true";
            return 'FlxG.sound.playMusic(Paths.music("' + music.matched(1) + '"), ' + vol + ', ' + loop + ');';
        }

        return null;
    }
}