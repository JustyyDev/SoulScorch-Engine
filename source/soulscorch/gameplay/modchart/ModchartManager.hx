package soulscorch.gameplay.modchart;

import flixel.FlxBasic;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import soulscorch.backend.audio.Conductor;
import soulscorch.gameplay.modchart.ModchartTypes;
import soulscorch.gameplay.notes.Note;
import soulscorch.gameplay.notes.StrumArrow;

using StringTools;

class ModchartManager {
    public var playerStrumline:Dynamic;
    public var opponentStrumline:Dynamic;

    public var modifiers:Map<String, Float> = new Map();
    public var opponentModifiers:Map<String, Float> = new Map();
    public var events:Array<ModchartEvent> = [];
    public var totalTime:Float = 0.0;

    public function new(playerStrums:Dynamic, opponentStrums:Dynamic) {
        this.playerStrumline = playerStrums;
        this.opponentStrumline = opponentStrums;

        initDefaultModifiers();
    }

    private function initDefaultModifiers():Void {
        var defaults:Array<String> = [
            "drunk", "drunkSpeed",
            "tipsy", "tipsySpeed",
            "tornado",
            "bumpy", "bumpySpeed",
            "beat",
            "stealth",
            "invert",
            "flip"
        ];

        for (m in defaults) {
            modifiers.set(m, 0.0);
            opponentModifiers.set(m, 0.0);
        }

        modifiers.set("drunkSpeed", 1.0);
        modifiers.set("tipsySpeed", 1.0);
        modifiers.set("bumpySpeed", 1.0);

        opponentModifiers.set("drunkSpeed", 1.0);
        opponentModifiers.set("tipsySpeed", 1.0);
        opponentModifiers.set("bumpySpeed", 1.0);
    }

    public function set(name:String, value:Float, target:ModTarget = BOTH):Void {
        if (target == PLAYER || target == BOTH) {
            modifiers.set(name, value);
        }
        if (target == OPPONENT || target == BOTH) {
            opponentModifiers.set(name, value);
        }
    }

    public function get(name:String, target:ModTarget = PLAYER):Float {
        var map = (target == OPPONENT) ? opponentModifiers : modifiers;
        return map.exists(name) ? map.get(name) : 0.0;
    }

    public function queueEvent(step:Float, name:String, value:Float, duration:Float = 0, ease:String = "linear", target:ModTarget = BOTH):Void {
        events.push({
            step: step,
            name: name,
            value: value,
            duration: duration,
            ease: ease,
            target: target
        });

        events.sort(function(a:ModchartEvent, b:ModchartEvent):Int {
            if (a.step < b.step) return -1;
            if (a.step > b.step) return 1;
            return 0;
        });
    }

    public function update(elapsed:Float):Void {
        totalTime += elapsed;

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
        var easeFn = resolveEase(easeName);

        FlxTween.num(startVal, targetVal, duration, {ease: easeFn}, function(v:Float) {
            set(name, v, target);
        });
    }

    private function updateReceptors(target:ModTarget):Void {
        var receptors = getReceptorList(target);
        if (receptors == null) return;

        var map = (target == OPPONENT) ? opponentModifiers : modifiers;

        for (i in 0...receptors.length) {
            var receptor = receptors[i];
            if (receptor == null) continue;

            var baseX:Float = (receptor.baseX != null) ? receptor.baseX : receptor.x;
            var baseY:Float = (receptor.baseY != null) ? receptor.baseY : receptor.y;

            var offsetX:Float = 0.0;
            var offsetY:Float = 0.0;
            var alphaVal:Float = 1.0;

            var invert = map.get("invert");
            if (invert > 0) {
                offsetX += ((i % 2 == 0) ? 1 : -1) * (112 * invert);
            }

            var flip = map.get("flip");
            if (flip > 0) {
                var targetCol = 3 - i;
                offsetX += (targetCol - i) * 112 * flip;
            }

            var drunk = map.get("drunk");
            if (drunk != 0) {
                var speed = map.get("drunkSpeed");
                offsetX += Math.sin((totalTime * speed * 2.5) + (i * 0.35)) * (drunk * 40.0);
            }

            var tipsy = map.get("tipsy");
            if (tipsy != 0) {
                var speed = map.get("tipsySpeed");
                offsetY += Math.cos((totalTime * speed * 2.5) + (i * 0.45)) * (tipsy * 30.0);
            }

            var beat = map.get("beat");
            if (beat != 0) {
                var crochet = Conductor.crochet > 0 ? Conductor.crochet : 600.0;
                var curBeatFloat = Conductor.songPosition / crochet;
                var beatProg = (curBeatFloat - Math.floor(curBeatFloat));
                offsetX += Math.sin(beatProg * Math.PI) * ((i % 2 == 0 ? 1 : -1) * beat * 20.0);
            }

            receptor.x = baseX + offsetX;
            receptor.y = baseY + offsetY;

            var stealth = map.get("stealth");
            if (stealth > 0) {
                alphaVal = Math.max(0.0, 1.0 - stealth);
            }
            receptor.alpha = alphaVal;
        }
    }

    public function modifyNote(note:Note, dir:Int, target:ModTarget, strumTime:Float):Void {
        if (note == null) return;

        var map = (target == OPPONENT) ? opponentModifiers : modifiers;
        var diff = (strumTime - Conductor.songPosition);

        var drunk = map.get("drunk");
        if (drunk != 0) {
            var speed = map.get("drunkSpeed");
            note.x += Math.sin(((totalTime * speed * 2.5) + (diff * 0.004)) + (dir * 0.35)) * (drunk * 40.0);
        }

        var tipsy = map.get("tipsy");
        if (tipsy != 0) {
            var speed = map.get("tipsySpeed");
            note.y += Math.cos(((totalTime * speed * 2.5) + (diff * 0.004)) + (dir * 0.45)) * (tipsy * 30.0);
        }

        var tornado = map.get("tornado");
        if (tornado != 0) {
            var theta = (diff * 0.003) + (dir * 0.8);
            note.x += Math.sin(theta) * (tornado * 45.0);
        }

        var bumpy = map.get("bumpy");
        if (bumpy != 0) {
            var speed = map.get("bumpySpeed");
            note.y += Math.sin((diff * 0.006 * speed)) * (bumpy * 35.0);
        }

        var stealth = map.get("stealth");
        if (stealth > 0) {
            note.alpha = Math.max(0.0, 1.0 - (stealth * (1.0 - Math.min(1.0, Math.abs(diff) / 600.0))));
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

    private function resolveEase(ease:String):flixel.tweens.FlxEase.EaseFunction {
        if (ease == null) return FlxEase.linear;
        var clean = ease.toLowerCase().trim();
        return switch (clean) {
            case "sinein": FlxEase.sineIn;
            case "sineout": FlxEase.sineOut;
            case "sineinout": FlxEase.sineInOut;
            case "quadin": FlxEase.quadIn;
            case "quadout": FlxEase.quadOut;
            case "quadinout": FlxEase.quadInOut;
            case "cubein": FlxEase.cubeIn;
            case "cubeout": FlxEase.cubeOut;
            case "cubeinout": FlxEase.cubeInOut;
            case "backin": FlxEase.backIn;
            case "backout": FlxEase.backOut;
            case "backinout": FlxEase.backInOut;
            case "circin": FlxEase.circIn;
            case "circout": FlxEase.circOut;
            case "circinout": FlxEase.circInOut;
            case "elasticin": FlxEase.elasticIn;
            case "elasticout": FlxEase.elasticOut;
            case "elasticinout": FlxEase.elasticInOut;
            default: FlxEase.linear;
        };
    }
}