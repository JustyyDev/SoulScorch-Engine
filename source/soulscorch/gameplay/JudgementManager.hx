package soulscorch.gameplay;

import flixel.FlxG;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.system.EventBus;
import soulscorch.gameplay.notes.Note;
import soulscorch.gameplay.scoring.Judgment;

class JudgementManager extends FlxTypedGroup<FlxText> {
    public static var MARVELOUS_WINDOW:Float = 22.5;
    public static var SICK_WINDOW:Float = 45.0;
    public static var GOOD_WINDOW:Float = 90.0;
    public static var BAD_WINDOW:Float = 135.0;
    public static var SHIT_WINDOW:Float = 160.0;

    public var combo:Int = 0;
    public var misses:Int = 0;
    public var totalNotesHit:Int = 0;
    public var totalNotesJudged:Int = 0;
    public var totalWeight:Float = 0.0;
    public var accuracy:Float = 0.0;
    public var health:Float = 1.0;
    public var maxHealth:Float = 2.0;

    public var onJudgement:Judgment->Float->Void;
    public var onHealthChange:Float->Void;
    public var onMiss:Note->Void;

    private var activeTweens:Map<FlxText, FlxTween> = new Map<FlxText, FlxTween>();

    public function new() {
        super();
        maxHealth = GameplayFlags.getFloat("maxHealth", 2.0);
        updateWindows();
    }

    public function updateWindows():Void {
        var scale:Float = GameplayFlags.getFloat("judgeWindow", 166.0) / 166.0;
        MARVELOUS_WINDOW = 22.5 * scale;
        SICK_WINDOW = 45.0 * scale;
        GOOD_WINDOW = 90.0 * scale;
        BAD_WINDOW = 135.0 * scale;
        SHIT_WINDOW = 160.0 * scale;
    }

    public function judge(note:Note, songPosition:Float):Judgment {
        if (note == null || note.wasGoodHit) return MISS;

        var difference:Float = Math.abs(songPosition - note.strumTime);
        var result:Judgment = if (difference <= SICK_WINDOW) SICK
            else if (difference <= GOOD_WINDOW) GOOD
            else if (difference <= BAD_WINDOW) BAD
            else if (difference <= SHIT_WINDOW) SHIT
            else MISS;

        if (result == MISS) {
            miss(note);
        } else {
            registerHit(note, result, difference);
        }
        return result;
    }

    public function registerHit(note:Note, result:Judgment, difference:Float = 0.0):Void {
        if (note == null || note.wasGoodHit || result == MISS) return;

        note.wasGoodHit = true;
        note.canBeHit = false;

        combo++;
        totalNotesHit++;
        totalNotesJudged++;

        var weight:Float = Judgment.accuracyWeight(result);
        totalWeight += weight;
        accuracy = (totalWeight / totalNotesJudged) * 100.0;

        health = Math.min(maxHealth, health + Judgment.healthModifier(result));
        if (onHealthChange != null) onHealthChange(health);

        showPopup(result, combo);
        dispatchHit(result, difference);

        if (onJudgement != null) onJudgement(result, weight);
    }

    public function miss(note:Note):Void {
        if (note == null || (note.tooLate && note.wasGoodHit)) return;

        note.tooLate = true;
        note.wasGoodHit = false;

        combo = 0;
        misses++;
        totalNotesJudged++;
        accuracy = totalNotesJudged > 0 ? (totalWeight / totalNotesJudged) * 100.0 : 0.0;

        var penalty:Float = GameplayFlags.getFloat("missPenalty", 0.085);
        health = Math.max(0.0, health - penalty);
        if (onHealthChange != null) onHealthChange(health);

        showPopup(MISS, 0);
        dispatchMiss();

        if (onMiss != null) onMiss(note);
    }

    private function showPopup(result:Judgment, currentCombo:Int):Void {
        var text:FlxText = recycle(FlxText);
        var judgeName:String = (result == MISS ? "MISS" : Std.string(result)).toUpperCase();
        
        text.text = judgeName;
        text.setFormat(Paths.font("vcr"), 24, colorFor(result), CENTER, OUTLINE, FlxColor.BLACK);
        text.borderSize = 1.5;
        text.screenCenter(X);
        text.y = FlxG.height * 0.42;
        text.scrollFactor.set(0, 0);
        text.scale.set(0.85, 0.85);
        text.alpha = 1.0;
        text.visible = true;

        if (activeTweens.exists(text)) {
            activeTweens.get(text).cancel();
            activeTweens.remove(text);
        }

        var twn = FlxTween.tween(text, {y: text.y - 20, alpha: 0, "scale.x": 1.05, "scale.y": 1.05}, 0.5, {
            ease: FlxEase.cubeOut,
            onComplete: function(_) {
                text.kill();
                activeTweens.remove(text);
            }
        });
        activeTweens.set(text, twn);

        if (currentCombo > 1 && result != MISS) {
            var comboText:FlxText = recycle(FlxText);
            comboText.text = 'x$currentCombo';
            comboText.setFormat(Paths.font("vcr"), 18, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
            comboText.borderSize = 1.25;
            comboText.screenCenter(X);
            comboText.y = (FlxG.height * 0.42) + 28;
            comboText.scrollFactor.set(0, 0);
            comboText.scale.set(0.85, 0.85);
            comboText.alpha = 1.0;
            comboText.visible = true;

            if (activeTweens.exists(comboText)) {
                activeTweens.get(comboText).cancel();
                activeTweens.remove(comboText);
            }

            var comboTwn = FlxTween.tween(comboText, {y: comboText.y - 20, alpha: 0, "scale.x": 1.05, "scale.y": 1.05}, 0.5, {
                ease: FlxEase.cubeOut,
                onComplete: function(_) {
                    comboText.kill();
                    activeTweens.remove(comboText);
                }
            });
            activeTweens.set(comboText, comboTwn);
        }
    }

    private function dispatchHit(result:Judgment, difference:Float):Void {
        try {
            var bus:Dynamic = EventBus;
            if (Reflect.hasField(bus, "publish")) {
                bus.publish("judgement/hit", {judgement: result, difference: difference, combo: combo, accuracy: accuracy});
            } else if (Reflect.hasField(bus, "emit")) {
                bus.emit("judgement/hit", {judgement: result, difference: difference, combo: combo, accuracy: accuracy});
            }
        } catch (e:Dynamic) {}
    }

    private function dispatchMiss():Void {
        try {
            var bus:Dynamic = EventBus;
            if (Reflect.hasField(bus, "publish")) {
                bus.publish("judgement/miss", {misses: misses, accuracy: accuracy});
            } else if (Reflect.hasField(bus, "emit")) {
                bus.emit("judgement/miss", {misses: misses, accuracy: accuracy});
            }
        } catch (e:Dynamic) {}
    }

    public function reset():Void {
        for (twn in activeTweens) twn.cancel();
        activeTweens.clear();
        forEach(function(txt:FlxText) txt.kill());

        combo = 0;
        misses = 0;
        totalNotesHit = 0;
        totalNotesJudged = 0;
        totalWeight = 0.0;
        accuracy = 0.0;
        health = 1.0;
    }

    private static function colorFor(result:Judgment):FlxColor {
        return switch (result) {
            case SICK: 0xFF00FFFF;
            case GOOD: 0xFF55E055;
            case BAD: 0xFFE08833;
            case SHIT, MISS: 0xFFE03333;
            default: FlxColor.WHITE;
        };
    }

    override public function destroy():Void {
        for (twn in activeTweens) twn.cancel();
        activeTweens.clear();
        super.destroy();
    }
}