package soulscorch.gameplay.modchart;

import flixel.FlxBasic;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import soulscorch.backend.audio.Conductor;
import soulscorch.gameplay.modchart.ModchartEase;
import soulscorch.gameplay.modchart.ModchartTypes;
import soulscorch.gameplay.modchart.Modifiers;
import soulscorch.gameplay.notes.Note;
import soulscorch.gameplay.notes.StrumArrow;

using StringTools;

class ModchartManager {
    public static var instance:ModchartManager;

    public var playerStrumline:Dynamic;
    public var opponentStrumline:Dynamic;

    public var modifierObjects:Map<String, Modifier> = new Map<String, Modifier>();
    public var events:Array<ModchartEvent> = [];
    public var totalTime:Float = 0.0;

    public function new(playerStrums:Dynamic, opponentStrums:Dynamic) {
        instance = this;
        this.playerStrumline = playerStrums;
        this.opponentStrumline = opponentStrums;

        registerBuiltinModifiers();
    }

    private function registerBuiltinModifiers():Void {
        registerModifier(new DrunkModifier());
        registerModifier(new TipsyModifier());
        registerModifier(new BumpyModifier());
        registerModifier(new TornadoModifier());
        registerModifier(new ConfusionModifier());
        registerModifier(new StealthModifier());
        registerModifier(new InvertModifier());
        registerModifier(new FlipModifier());
    }

    public function registerModifier(mod:Modifier):Void {
        if (mod != null && mod.name != null) {
            modifierObjects.set(mod.name.toLowerCase().trim(), mod);
        }
    }

    public function set(name:String, value:Float, target:ModTarget = BOTH, lane:Int = -1):Void {
        var clean = (name != null) ? name.toLowerCase().trim() : "";
        if (modifierObjects.exists(clean)) {
            modifierObjects.get(clean).setValue(value, target, lane);
        }
    }

    public function get(name:String, target:ModTarget = PLAYER, lane:Int = 0):Float {
        var clean = (name != null) ? name.toLowerCase().trim() : "";
        return modifierObjects.exists(clean) ? modifierObjects.get(clean).getValue(target, lane) : 0.0;
    }

    public function queueEvent(step:Float, name:String, value:Float, duration:Float = 0, ease:String = "linear", target:ModTarget = BOTH, lane:Int = -1):Void {
        events.push({
            step: step,
            name: name,
            value: value,
            duration: duration,
            ease: ease,
            target: target
        });

        events.sort(function(a:ModchartEvent, b:ModchartEvent):Int {
            return (a.step < b.step) ? -1 : ((a.step > b.step) ? 1 : 0);
        });
    }

    public function update(elapsed:Float):Void {
        totalTime += elapsed;

        for (mod in modifierObjects) {
            if (mod.active) mod.update(elapsed);
        }

        var stepCrochet = Conductor.stepCrochet > 0 ? Conductor.stepCrochet : 150.0;
        var curStepFloat = Conductor.songPosition / stepCrochet;

        while (events.length > 0 && events[0].step <= curStepFloat) {
            var ev = events.shift();
            if (ev.duration <= 0) {
                set(ev.name, ev.value, ev.target);
            } else {
                tweenModifier(ev.name, ev.value, ev.duration * stepCrochet * 0.001, ev.ease, ev.target);
            }
        }

        updateReceptors(PLAYER);
        updateReceptors(OPPONENT);
    }

    private function tweenModifier(name:String, targetVal:Float, duration:Float, easeName:String, target:ModTarget):Void {
        var startVal = get(name, target);
        var easeFn = ModchartEase.getEase(easeName);

        FlxTween.num(startVal, targetVal, Math.max(0.001, duration), {ease: easeFn}, function(v:Float) {
            set(name, v, target);
        });
    }

    private function updateReceptors(target:ModTarget):Void {
        var receptors = getReceptorList(target);
        if (receptors == null) return;

        for (i in 0...receptors.length) {
            var receptor:FlxSprite = receptors[i];
            if (receptor == null) continue;

            var baseX:Float = Reflect.hasField(receptor, "baseX") ? Reflect.field(receptor, "baseX") : receptor.x;
            var baseY:Float = Reflect.hasField(receptor, "baseY") ? Reflect.field(receptor, "baseY") : receptor.y;

            receptor.x = baseX;
            receptor.y = baseY;
            receptor.angle = 0;
            receptor.alpha = 1.0;

            for (mod in modifierObjects) {
                if (mod.active) {
                    mod.modifyReceptor(receptor, i, target);
                }
            }
        }
    }

    public function modifyNote(note:Note, dir:Int, target:ModTarget, strumTime:Float):Void {
        if (note == null) return;

        for (mod in modifierObjects) {
            if (mod.active) {
                mod.modifyNote(note, dir, target, strumTime);
            }
        }
    }

    private function getReceptorList(target:ModTarget):Array<Dynamic> {
        var targetLine = (target == OPPONENT) ? opponentStrumline : playerStrumline;
        if (targetLine == null) return [];

        if (Reflect.hasField(targetLine, "receptors")) {
            var list:Array<Dynamic> = Reflect.field(targetLine, "receptors");
            if (list != null) return list;
        }

        if (Std.isOfType(targetLine, FlxTypedGroup)) {
            var group:FlxTypedGroup<Dynamic> = cast targetLine;
            return group.members;
        }

        return [];
    }

    public function clear():Void {
        events = [];
        for (mod in modifierObjects) {
            mod.setValue(0.0, BOTH);
        }
    }
}