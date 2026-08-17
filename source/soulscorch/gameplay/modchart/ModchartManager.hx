package soulscorch.gameplay.modchart;

import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxEase.EaseFunction;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.modchart.BasicModifiers;
import soulscorch.gameplay.modchart.ModchartTypes;

typedef ActiveTween = {
    var modName:String;
    var startValue:Float;
    var targetValue:Float;
    var startStep:Float;
    var durationSteps:Float;
    var ease:EaseFunction;
    var target:ModTarget;
    var lane:Int;
}

class ModchartManager {
    public static var instance:ModchartManager;

    public var modifiers:Map<String, Modifier> = new Map();
    public var queuedEvents:Array<ModchartEvent> = [];
    public var activeTweens:Array<ActiveTween> = [];

    public var playerStrums:FlxTypedGroup<FlxSprite>;
    public var opponentStrums:FlxTypedGroup<FlxSprite>;

    public var defaultPositions:Array<Array<{x:Float, y:Float}>> = [[], []];
    private var tempTransform:RenderTransform = new RenderTransform();

    public function new(playerStrums:FlxTypedGroup<FlxSprite>, opponentStrums:FlxTypedGroup<FlxSprite>) {
        instance = this;
        this.playerStrums = playerStrums;
        this.opponentStrums = opponentStrums;

        registerDefaults();
        cacheDefaultPositions();
    }

    private function registerDefaults():Void {
        addModifier(new DrunkModifier());
        addModifier(new TipsyModifier());
        addModifier(new TornadoModifier());
        addModifier(new BeatModifier());
        addModifier(new BumpyModifier());
        addModifier(new LaneModifier());

        // Basic property modifiers
        for (prop in ["x", "y", "z", "angle", "alpha", "scaleX", "scaleY", "skewX", "skewY"]) {
            addModifier(new TransformModifier(prop));
        }
    }

    public function cacheDefaultPositions():Void {
        defaultPositions = [[], []];
        for (i in 0...4) {
            var p = (playerStrums != null && playerStrums.members.length > i) ? playerStrums.members[i] : null;
            var o = (opponentStrums != null && opponentStrums.members.length > i) ? opponentStrums.members[i] : null;

            defaultPositions[0].push({x: (p != null ? p.x : 0.0), y: (p != null ? p.y : 0.0)});
            defaultPositions[1].push({x: (o != null ? o.x : 0.0), y: (o != null ? o.y : 0.0)});
        }
    }

    public function addModifier(modifier:Modifier):Void {
        modifiers.set(modifier.name.toLowerCase(), modifier);
    }

    public function set(name:String, value:Float, target:ModTarget = BOTH, lane:Int = 4):Void {
        var mod = modifiers.get(name.toLowerCase());
        if (mod != null) {
            mod.setValue(value, target, lane);
        }
    }

    public function get(name:String, target:ModTarget = BOTH, lane:Int = 4):Float {
        var mod = modifiers.get(name.toLowerCase());
        return (mod != null) ? mod.getValue(target, lane) : 0.0;
    }

    /**
     * Queues an eased modifier transition over a step duration.
     */
    public function ease(step:Float, durationSteps:Float, modName:String, targetValue:Float, ?easeName:String = "linear", target:ModTarget = BOTH, lane:Int = 4):Void {
        queuedEvents.push({
            step: step,
            modName: modName.toLowerCase(),
            targetValue: targetValue,
            stepDuration: durationSteps,
            ease: ModchartEase.getEase(easeName),
            target: target,
            lane: lane,
            executed: false
        });

        queuedEvents.sort(function(a, b) return (a.step < b.step) ? -1 : (a.step > b.step ? 1 : 0));
    }

    public function update(elapsed:Float):Void {
        var curStep = Conductor.songPosition / (Conductor.stepCrochet > 0 ? Conductor.stepCrochet : 1.0);

        // 1. Process Timeline Events
        for (event in queuedEvents) {
            if (!event.executed && curStep >= event.step) {
                event.executed = true;

                var startVal = get(event.modName, event.target, event.lane);
                if (event.stepDuration <= 0) {
                    set(event.modName, event.targetValue, event.target, event.lane);
                } else {
                    activeTweens.push({
                        modName: event.modName,
                        startValue: startVal,
                        targetValue: event.targetValue,
                        startStep: event.step,
                        durationSteps: event.stepDuration,
                        ease: event.ease,
                        target: event.target,
                        lane: event.lane
                    });
                }
            }
        }

        // 2. Update Active Eases
        var i = activeTweens.length - 1;
        while (i >= 0) {
            var tween = activeTweens[i];
            var progress = (curStep - tween.startStep) / tween.durationSteps;

            if (progress >= 1.0) {
                set(tween.modName, tween.targetValue, tween.target, tween.lane);
                activeTweens.splice(i, 1);
            } else {
                var easedProgress = tween.ease(Math.max(0.0, progress));
                var currentVal = tween.startValue + ((tween.targetValue - tween.startValue) * easedProgress);
                set(tween.modName, currentVal, tween.target, tween.lane);
            }
            i--;
        }

        // 3. Apply Transforms to Strumlines
        updateStrumlines();
    }

    private function updateStrumlines():Void {
        for (i in 0...4) {
            applyToStrum(playerStrums != null && playerStrums.members.length > i ? playerStrums.members[i] : null, i, PLAYER);
            applyToStrum(opponentStrums != null && opponentStrums.members.length > i ? opponentStrums.members[i] : null, i, OPPONENT);
        }
    }

    private function applyToStrum(strum:FlxSprite, lane:Int, target:ModTarget):Void {
        if (strum == null) return;

        var targetIdx = (target == PLAYER) ? 0 : 1;
        var defaultPos = defaultPositions[targetIdx][lane];

        tempTransform.reset();

        for (mod in modifiers) {
            if (mod.active) {
                mod.applyStrum(tempTransform, lane, target, Conductor.songPosition);
            }
        }

        strum.x = defaultPos.x + tempTransform.x;
        strum.y = defaultPos.y + tempTransform.y;
        strum.angle = tempTransform.angle;
        strum.alpha = tempTransform.alpha;
        strum.scale.set(tempTransform.scaleX, tempTransform.scaleY);
    }

    /**
     * Transforms incoming gameplay notes and calculates curved paths.
     */
    public function modifyNote(note:FlxSprite, lane:Int, target:ModTarget, noteStrumTime:Float):Void {
        if (note == null) return;

        var targetIdx = (target == PLAYER) ? 0 : 1;
        var defaultPos = defaultPositions[targetIdx][lane];
        var distance = (noteStrumTime - Conductor.songPosition) * (Conductor.timeScale != 0 ? Conductor.timeScale : 1.0);

        tempTransform.reset();

        for (mod in modifiers) {
            if (mod.active) {
                mod.applyNote(tempTransform, lane, target, Conductor.songPosition, distance);
            }
        }

        note.x = defaultPos.x + tempTransform.x;
        note.y = defaultPos.y + tempTransform.y + distance;
        note.angle = tempTransform.angle;
        note.alpha = tempTransform.alpha;
        note.scale.set(tempTransform.scaleX, tempTransform.scaleY);
    }

    public function reset():Void {
        for (mod in modifiers) {
            mod.setValue(0.0, BOTH, 4);
            for (i in 0...4) mod.setValue(0.0, BOTH, i);
        }
        queuedEvents = [];
        activeTweens = [];
    }
}