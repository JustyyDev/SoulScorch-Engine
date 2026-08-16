package soulscorch.gameplay;

import flixel.FlxBasic;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import soulscorch.gameplay.notes.Note;
import soulscorch.core.EventBus;

enum abstract Judgement(String) from String to String {
    var MARVELOUS = "Marvelous";
    var SICK = "Sick";
    var GOOD = "Good";
    var BAD = "Bad";
    var SHIT = "Shit";
    var MISS = "Miss";
}

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
    public var onJudgement:Judgement->Float->Void;
    public var onHealthChange:Float->Void;
    public var onMiss:Note->Void;
    private var popupAges:Map<FlxText, Float> = new Map();

    public function new() {
        super();
    }

    public function judge(note:Note, songPosition:Float):Judgement {
        if (note == null || note.wasGoodHit) return MISS;
        var difference:Float = Math.abs(songPosition - note.strumTime);
        var result:Judgement = difference <= MARVELOUS_WINDOW ? MARVELOUS : difference <= SICK_WINDOW ? SICK : difference <= GOOD_WINDOW ? GOOD : difference <= BAD_WINDOW ? BAD : difference <= SHIT_WINDOW ? SHIT : MISS;
        if (result == MISS) miss(note);
        else registerHit(note, result, difference);
        return result;
    }

    public function registerHit(note:Note, result:Judgement, difference:Float = 0.0):Void {
        if (note == null || note.wasGoodHit || result == MISS) return;
        note.wasGoodHit = true;
        note.canBeHit = false;
        combo++;
        totalNotesHit++;
        totalNotesJudged++;
        accuracy = calculateAccuracy();
        var weight:Float = weightFor(result);
        health = Math.min(1.0, health + (result == SHIT ? 0.005 : 0.02));
        if (onHealthChange != null) onHealthChange(health);
        showPopup(result, combo);
        EventBus.publish("judgement/hit", {judgement: result, difference: difference, combo: combo, accuracy: accuracy});
        if (onJudgement != null) onJudgement(result, weight);
    }

    public function miss(note:Note):Void {
        if (note == null || note.tooLate && note.wasGoodHit) return;
        note.tooLate = true;
        note.wasGoodHit = false;
        combo = 0;
        misses++;
        totalNotesJudged++;
        health = Math.max(0.0, health - 0.05);
        if (onHealthChange != null) onHealthChange(health);
        showPopup(MISS, 0);
        EventBus.publish("judgement/miss", {misses: misses, accuracy: accuracy});
        if (onMiss != null) onMiss(note);
    }

    public function calculateAccuracy():Float {
        var weighted:Float = 0.0;
        var hitCount:Int = 0;
        for (entry in judgementHistory) {
            weighted += entry;
            hitCount++;
        }
        return hitCount == 0 ? 0.0 : weighted / hitCount * 100.0;
    }

    private var judgementHistory:Array<Float> = [];

    private function weightFor(result:Judgement):Float {
        var weight:Float = switch (result) {
            case MARVELOUS, SICK: 1.0;
            case GOOD: 0.75;
            case BAD: 0.5;
            default: 0.0;
        };
        judgementHistory.push(weight);
        return weight;
    }

    private function showPopup(result:Judgement, currentCombo:Int):Void {
        var text:FlxText = new FlxText(0, FlxG.height * 0.42, 0, result == MISS ? "MISS" : Std.string(result), 24);
        text.setFormat(null, 24, colorFor(result), CENTER);
        text.screenCenter(X);
        text.scale.set(0.8, 0.8);
        add(text);
        popupAges.set(text, 0.0);
        if (currentCombo > 1 && result != MISS) {
            var comboText:FlxText = new FlxText(0, text.y + 28, 0, 'x$currentCombo', 18);
            comboText.setFormat(null, 18, FlxColor.WHITE, CENTER);
            comboText.screenCenter(X);
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
            text.y -= elapsed * 22.0;
            text.alpha = Math.max(0.0, 1.0 - age / 0.55);
            text.scale.set(0.8 + Math.min(0.2, age * 1.5), 0.8 + Math.min(0.2, age * 1.5));
            if (age >= 0.55) expired.push(text);
        }
        for (text in expired) {
            popupAges.remove(text);
            remove(text, true);
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

    private static function colorFor(result:Judgement):FlxColor {
        return switch (result) {
            case MARVELOUS: 0xFFFFFF00;
            case SICK: FlxColor.WHITE;
            case GOOD: FlxColor.GREEN;
            case BAD: FlxColor.ORANGE;
            case SHIT, MISS: FlxColor.RED;
            default: FlxColor.WHITE;
        };
    }
}
