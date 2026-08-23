package soulscorch.gameplay.modchart;

import flixel.FlxSprite;
import soulscorch.backend.audio.Conductor;
import soulscorch.gameplay.modchart.ModchartTypes.ModTarget;
import soulscorch.gameplay.notes.Note;

using StringTools;

class DrunkModifier extends Modifier {
    public var speed:Float = 1.0;
    public var totalTime:Float = 0.0;

    public function new() {
        super("drunk");
    }

    override public function update(elapsed:Float):Void {
        totalTime += elapsed;
    }

    override public function modifyReceptor(receptor:FlxSprite, lane:Int, target:ModTarget):Void {
        var val = getValue(target, lane);
        if (val != 0) {
            receptor.x += Math.sin((totalTime * speed * 2.5) + (lane * 0.35)) * (val * 40.0);
        }
    }

    override public function modifyNote(note:Note, lane:Int, target:ModTarget, strumTime:Float):Void {
        var val = getValue(target, lane);
        if (val != 0) {
            var diff = strumTime - Conductor.songPosition;
            note.x += Math.sin(((totalTime * speed * 2.5) + (diff * 0.004)) + (lane * 0.35)) * (val * 40.0);
        }
    }
}

class TipsyModifier extends Modifier {
    public var speed:Float = 1.0;
    public var totalTime:Float = 0.0;

    public function new() {
        super("tipsy");
    }

    override public function update(elapsed:Float):Void {
        totalTime += elapsed;
    }

    override public function modifyReceptor(receptor:FlxSprite, lane:Int, target:ModTarget):Void {
        var val = getValue(target, lane);
        if (val != 0) {
            receptor.y += Math.cos((totalTime * speed * 2.5) + (lane * 0.45)) * (val * 30.0);
        }
    }

    override public function modifyNote(note:Note, lane:Int, target:ModTarget, strumTime:Float):Void {
        var val = getValue(target, lane);
        if (val != 0) {
            var diff = strumTime - Conductor.songPosition;
            note.y += Math.cos(((totalTime * speed * 2.5) + (diff * 0.004)) + (lane * 0.45)) * (val * 30.0);
        }
    }
}

class BumpyModifier extends Modifier {
    public var speed:Float = 1.0;

    public function new() {
        super("bumpy");
    }

    override public function modifyNote(note:Note, lane:Int, target:ModTarget, strumTime:Float):Void {
        var val = getValue(target, lane);
        if (val != 0) {
            var diff = strumTime - Conductor.songPosition;
            note.y += Math.sin(diff * 0.006 * speed) * (val * 35.0);
        }
    }
}

class TornadoModifier extends Modifier {
    public function new() {
        super("tornado");
    }

    override public function modifyNote(note:Note, lane:Int, target:ModTarget, strumTime:Float):Void {
        var val = getValue(target, lane);
        if (val != 0) {
            var diff = strumTime - Conductor.songPosition;
            var theta = (diff * 0.003) + (lane * 0.8);
            note.x += Math.sin(theta) * (val * 45.0);
        }
    }
}

class ConfusionModifier extends Modifier {
    public function new() {
        super("confusion");
    }

    override public function modifyReceptor(receptor:FlxSprite, lane:Int, target:ModTarget):Void {
        var val = getValue(target, lane);
        if (val != 0) {
            receptor.angle += val;
        }
    }

    override public function modifyNote(note:Note, lane:Int, target:ModTarget, strumTime:Float):Void {
        var val = getValue(target, lane);
        if (val != 0) {
            note.angle += val;
        }
    }
}

class StealthModifier extends Modifier {
    public function new() {
        super("stealth");
    }

    override public function modifyReceptor(receptor:FlxSprite, lane:Int, target:ModTarget):Void {
        var val = getValue(target, lane);
        if (val > 0) {
            receptor.alpha *= Math.max(0.0, 1.0 - val);
        }
    }

    override public function modifyNote(note:Note, lane:Int, target:ModTarget, strumTime:Float):Void {
        var val = getValue(target, lane);
        if (val > 0) {
            var diff = strumTime - Conductor.songPosition;
            var fadeDist = Math.min(1.0, Math.abs(diff) / 600.0);
            note.alpha *= Math.max(0.0, 1.0 - (val * (1.0 - fadeDist)));
        }
    }
}

class InvertModifier extends Modifier {
    public function new() {
        super("invert");
    }

    override public function modifyReceptor(receptor:FlxSprite, lane:Int, target:ModTarget):Void {
        var val = getValue(target, lane);
        if (val != 0) {
            receptor.x += ((lane % 2 == 0) ? 1 : -1) * (112.0 * val);
        }
    }

    override public function modifyNote(note:Note, lane:Int, target:ModTarget, strumTime:Float):Void {
        var val = getValue(target, lane);
        if (val != 0) {
            note.x += ((lane % 2 == 0) ? 1 : -1) * (112.0 * val);
        }
    }
}

class FlipModifier extends Modifier {
    public function new() {
        super("flip");
    }

    override public function modifyReceptor(receptor:FlxSprite, lane:Int, target:ModTarget):Void {
        var val = getValue(target, lane);
        if (val != 0) {
            var targetCol = 3 - lane;
            receptor.x += (targetCol - lane) * 112.0 * val;
        }
    }

    override public function modifyNote(note:Note, lane:Int, target:ModTarget, strumTime:Float):Void {
        var val = getValue(target, lane);
        if (val != 0) {
            var targetCol = 3 - lane;
            note.x += (targetCol - lane) * 112.0 * val;
        }
    }
}

class MiniModifier extends Modifier {
    public function new() {
        super("mini");
    }

    override public function modifyReceptor(receptor:FlxSprite, lane:Int, target:ModTarget):Void {
        var val = getValue(target, lane);
        if (val != 0) {
            var scale = 1.0 - (0.5 * val);
            receptor.scale.set(scale, scale);
        }
    }

    override public function modifyNote(note:Note, lane:Int, target:ModTarget, strumTime:Float):Void {
        var val = getValue(target, lane);
        if (val != 0) {
            var scale = 1.0 - (0.5 * val);
            note.scale.set(scale, scale);
        }
    }
}

class SpinModifier extends Modifier {
    public var speed:Float = 1.0;
    public var totalTime:Float = 0.0;

    public function new() {
        super("spin");
    }

    override public function update(elapsed:Float):Void {
        totalTime += elapsed;
    }

    override public function modifyReceptor(receptor:FlxSprite, lane:Int, target:ModTarget):Void {
        var val = getValue(target, lane);
        if (val != 0) {
            receptor.angle += (totalTime * speed * 90.0 * val) % 360.0;
        }
    }

    override public function modifyNote(note:Note, lane:Int, target:ModTarget, strumTime:Float):Void {
        var val = getValue(target, lane);
        if (val != 0) {
            note.angle += (totalTime * speed * 90.0 * val) % 360.0;
        }
    }
}

class WaveModifier extends Modifier {
    public var speed:Float = 1.0;
    public var totalTime:Float = 0.0;

    public function new() {
        super("wave");
    }

    override public function update(elapsed:Float):Void {
        totalTime += elapsed;
    }

    override public function modifyReceptor(receptor:FlxSprite, lane:Int, target:ModTarget):Void {
        var val = getValue(target, lane);
        if (val != 0) {
            receptor.y += Math.sin((totalTime * speed * 3.0) + (lane * 0.5)) * (val * 25.0);
        }
    }

    override public function modifyNote(note:Note, lane:Int, target:ModTarget, strumTime:Float):Void {
        var val = getValue(target, lane);
        if (val != 0) {
            var diff = strumTime - Conductor.songPosition;
            note.y += Math.sin(((totalTime * speed * 3.0) + (diff * 0.004)) + (lane * 0.5)) * (val * 25.0);
        }
    }
}

class SquareModifier extends Modifier {
    public var speed:Float = 1.0;
    public var totalTime:Float = 0.0;

    public function new() {
        super("square");
    }

    override public function update(elapsed:Float):Void {
        totalTime += elapsed;
    }

    override public function modifyReceptor(receptor:FlxSprite, lane:Int, target:ModTarget):Void {
        var val = getValue(target, lane);
        if (val != 0) {
            var s = Math.sin((totalTime * speed * 2.0) + (lane * 0.5));
            receptor.x += (s >= 0 ? 1 : -1) * (val * 30.0);
        }
    }

    override public function modifyNote(note:Note, lane:Int, target:ModTarget, strumTime:Float):Void {
        var val = getValue(target, lane);
        if (val != 0) {
            var diff = strumTime - Conductor.songPosition;
            var s = Math.sin(((totalTime * speed * 2.0) + (diff * 0.004)) + (lane * 0.5));
            note.x += (s >= 0 ? 1 : -1) * (val * 30.0);
        }
    }
}

class CrossoverModifier extends Modifier {
    public function new() {
        super("crossover");
    }

    override public function modifyReceptor(receptor:FlxSprite, lane:Int, target:ModTarget):Void {
        var val = getValue(target, lane);
        if (val != 0) {
            var targetCol = (lane < 2) ? (lane + 2) : (lane - 2);
            receptor.x += (targetCol - lane) * 112.0 * val;
        }
    }

    override public function modifyNote(note:Note, lane:Int, target:ModTarget, strumTime:Float):Void {
        var val = getValue(target, lane);
        if (val != 0) {
            var targetCol = (lane < 2) ? (lane + 2) : (lane - 2);
            note.x += (targetCol - lane) * 112.0 * val;
        }
    }
}

class XModifier extends Modifier {
    public function new() {
        super("x");
    }

    override public function modifyReceptor(receptor:FlxSprite, lane:Int, target:ModTarget):Void {
        var val = getValue(target, lane);
        if (val != 0) receptor.x += val * 100.0;
    }

    override public function modifyNote(note:Note, lane:Int, target:ModTarget, strumTime:Float):Void {
        var val = getValue(target, lane);
        if (val != 0) note.x += val * 100.0;
    }
}

class YModifier extends Modifier {
    public function new() {
        super("y");
    }

    override public function modifyReceptor(receptor:FlxSprite, lane:Int, target:ModTarget):Void {
        var val = getValue(target, lane);
        if (val != 0) receptor.y += val * 100.0;
    }

    override public function modifyNote(note:Note, lane:Int, target:ModTarget, strumTime:Float):Void {
        var val = getValue(target, lane);
        if (val != 0) note.y += val * 100.0;
    }
}

class AlphaModifier extends Modifier {
    public function new() {
        super("alpha");
    }

    override public function modifyReceptor(receptor:FlxSprite, lane:Int, target:ModTarget):Void {
        var val = getValue(target, lane);
        if (val != 0) receptor.alpha *= Math.max(0.0, 1.0 - val);
    }

    override public function modifyNote(note:Note, lane:Int, target:ModTarget, strumTime:Float):Void {
        var val = getValue(target, lane);
        if (val != 0) note.alpha *= Math.max(0.0, 1.0 - val);
    }
}

class DrawDistanceModifier extends Modifier {
    public function new() {
        super("drawdistance");
    }

    override public function modifyReceptor(receptor:FlxSprite, lane:Int, target:ModTarget):Void {}

    override public function modifyNote(note:Note, lane:Int, target:ModTarget, strumTime:Float):Void {
        var val = getValue(target, lane);
        if (val != 0) {
            var diff = strumTime - Conductor.songPosition;
            note.alpha *= Math.max(0.0, 1.0 - (Math.abs(diff) / (800.0 + val * 400.0)));
        }
    }
}

class PulseModifier extends Modifier {
    public var speed:Float = 1.0;
    public var totalTime:Float = 0.0;

    public function new() {
        super("pulse");
    }

    override public function update(elapsed:Float):Void {
        totalTime += elapsed;
    }

    override public function modifyReceptor(receptor:FlxSprite, lane:Int, target:ModTarget):Void {
        var val = getValue(target, lane);
        if (val != 0) {
            var s = 1.0 + Math.sin(totalTime * speed * 4.0) * 0.25 * val;
            receptor.scale.set(s, s);
        }
    }

    override public function modifyNote(note:Note, lane:Int, target:ModTarget, strumTime:Float):Void {
        var val = getValue(target, lane);
        if (val != 0) {
            var diff = strumTime - Conductor.songPosition;
            var s = 1.0 + Math.sin((totalTime * speed * 4.0) + (diff * 0.004)) * 0.25 * val;
            note.scale.set(s, s);
        }
    }
}