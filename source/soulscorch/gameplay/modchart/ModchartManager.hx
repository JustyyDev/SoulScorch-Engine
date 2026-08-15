package soulscorch.gameplay.modchart;

import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import soulscorch.gameplay.Conductor;

typedef Modifier = {
    var name:String;
    var value:Float;
    var targetValue:Float;
    var duration:Float;
    var elapsed:Float;
}

class ModchartManager {
    public var modifiers:Map<String, Modifier> = new Map();
    public var playerStrums:FlxTypedGroup<FlxSprite>;
    public var opponentStrums:FlxTypedGroup<FlxSprite>;

    public function new(playerStrums:FlxTypedGroup<FlxSprite>, opponentStrums:FlxTypedGroup<FlxSprite>) {
        this.playerStrums = playerStrums;
        this.opponentStrums = opponentStrums;
    }

    public function set(name:String, value:Float):Void {
        modifiers.set(name, {
            name: name,
            value: value,
            targetValue: value,
            duration: 0,
            elapsed: 0
        });
    }

    public function ease(name:String, targetValue:Float, stepDuration:Float):Void {
        var current = get(name);
        modifiers.set(name, {
            name: name,
            value: current,
            targetValue: targetValue,
            duration: stepDuration,
            elapsed: 0
        });
    }

    public function get(name:String):Float {
        if (!modifiers.exists(name)) return 0.0;
        return modifiers.get(name).value;
    }

    public function update(elapsed:Float):Void {
        for (mod in modifiers) {
            if (mod.duration > 0 && mod.elapsed < mod.duration) {
                mod.elapsed += elapsed;
                var progress = Math.min(1.0, mod.elapsed / mod.duration);
                mod.value = mod.value + (mod.targetValue - mod.value) * progress;
            } else {
                mod.value = mod.targetValue;
            }
        }

        applyModifiers();
    }

    private function applyModifiers():Void {
        var sway = get("sway");
        var bounce = get("bounce");
        var songPos = Conductor.songPosition * 0.005;

        for (i in 0...4) {
            var pStrum = playerStrums.members[i];
            var oStrum = opponentStrums.members[i];

            if (pStrum != null) {
                if (sway != 0) pStrum.x += Math.sin(songPos + i) * sway;
                if (bounce != 0) pStrum.y += Math.cos(songPos + i) * bounce;
            }

            if (oStrum != null) {
                if (sway != 0) oStrum.x += Math.sin(songPos + i + Math.PI) * sway;
                if (bounce != 0) oStrum.y += Math.cos(songPos + i + Math.PI) * bounce;
            }
        }
    }
}