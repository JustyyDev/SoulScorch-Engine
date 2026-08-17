package soulscorch.gameplay;

import flixel.FlxG;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.system.EventBus;
import soulscorch.gameplay.notes.Note;
import soulscorch.gameplay.scoring.Judgment;

class JudgementManager extends FlxGroup {
    public static inline var MARVELOUS_WINDOW:Float = 22.5;
    public static inline var SICK_WINDOW:Float = 45.0;
    public static inline var GOOD_WINDOW:Float = 90.0;
    public static inline var BAD_WINDOW:Float = 135.0;
    public static inline var SHIT_WINDOW:Float = 160.0;

    public var combo:Int = 0;
    public var misses:Int = 0;
    public var totalNotesHit:Int = 0;
    public var totalNotesJudged:Int = 0;
    public var accuracy:Float = 0.0;
    public var health:Float = 1.0;

    public var onJudgement:Judgment->Float->Void;
    public var onHealthChange:Float->Void;
    public var onMiss:Note->Void;

    private var popupAges:Map<FlxText, Float> = new Map();
    private var judgementHistory:Array<Float> = [];

    public function new() {
        super();
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
        judgementHistory.push(weight);
        accuracy = calculateAccuracy();

        health = Math.min(2.0, health + Judgment.healthModifier(result));
        if (onHealthChange != null) onHealthChange(health);

        showPopup(result, combo);
        EventBus.emit("judgement/hit", {judgement: result, difference: difference, combo: combo, accuracy: accuracy});

        if (onJudgement != null) onJudgement(result, weight);
    }

    public function miss(note:Note):Void {
        if (note == null || (note.tooLate && note.wasGoodHit)) return;

        note.tooLate = true;
        note.wasGoodHit = false;

        combo = 0;
        misses++;
        totalNotesJudged++;
        judgementHistory.push(0.0);
        accuracy = calculateAccuracy();

        health = Math.max(0.0, health - 0.085);
        if (onHealthChange != null) onHealthChange(health);

        showPopup(MISS, 0);
        EventBus.emit("judgement/miss", {misses: misses, accuracy: accuracy});

        if (onMiss != null) onMiss(note);
    }

    public function calculateAccuracy():Float {
        if (judgementHistory.length == 0) return 0.0;
        var total:Float = 0.0;
        for (w in judgementHistory) total += w;
        return (total / judgementHistory.length) * 100.0;
    }

    private function showPopup(result:Judgment, currentCombo:Int):Void {
        var text:FlxText = new FlxText(0, FlxG.height * 0.42, 0, (result == MISS ? "MISS" : Std.string(result)).toUpperCase(), 24);
        text.setFormat(Paths.font("vcr"), 24, colorFor(result), CENTER, OUTLINE, FlxColor.BLACK);
        text.borderSize = 1.5;
        text.screenCenter(X);
        text.scrollFactor.set(0, 0);
        text.scale.set(0.85, 0.85);
        add(text);
        popupAges.set(text, 0.0);

        if (currentCombo > 1 && result != MISS) {
            var comboText:FlxText = new FlxText(0, text.y + 28, 0, 'x$currentCombo', 18);
            comboText.setFormat(Paths.font("vcr"), 18, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
            comboText.borderSize = 1.25;
            comboText.screenCenter(X);
            comboText.scrollFactor.set(0, 0);
            add(comboText);
            popupAges.set(comboText, 0.0);
        }
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        var expired:Array<FlxText> = [];

        for (text in popupAges.keys()) {
            var age:Float = popupAges.get(text) + elapsed;
            popupAges.set(text, age);
            text.y -= elapsed * 24.0;
            text.alpha = Math.max(0.0, 1.0 - (age / 0.55));
            text.scale.set(0.85 + Math.min(0.2, age * 1.2), 0.85 + Math.min(0.2, age * 1.2));

            if (age >= 0.55) {
                expired.push(text);
            }
        }

        for (text in expired) {
            popupAges.remove(text);
            remove(text, true);
            text.destroy();
        }
    }

    public function reset():Void {
        combo = 0;
        misses = 0;
        totalNotesHit = 0;
        totalNotesJudged = 0;
        accuracy = 0.0;
        health = 1.0;
        judgementHistory = [];
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
}