package soulscorch.gameplay;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.system.EventBus;
import soulscorch.gameplay.notes.Note;
import soulscorch.gameplay.scoring.Judgment;

class JudgementManager extends FlxTypedGroup<FlxSprite> {
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

    private var activeTweens:Map<FlxSprite, FlxTween> = new Map<FlxSprite, FlxTween>();

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
        var ratingSpr:FlxSprite = recycle(FlxSprite);
        var ratingName:String = (result == MISS ? "bad" : Std.string(result)).toLowerCase();

        var loaded = AssetHelper.loadGraphicSafely(ratingSpr, 'ui/game/score/$ratingName');
        if (!loaded) {
            loaded = AssetHelper.loadGraphicSafely(ratingSpr, 'ui/ratings/$ratingName');
        }

        ratingSpr.screenCenter();
        ratingSpr.x = (FlxG.width * 0.55) - 40;
        ratingSpr.y -= 60;
        ratingSpr.acceleration.y = 550;
        ratingSpr.velocity.y = -FlxG.random.int(140, 175);
        ratingSpr.velocity.x = -FlxG.random.int(0, 10);
        ratingSpr.alpha = 1.0;
        ratingSpr.scale.set(0.7, 0.7);
        ratingSpr.visible = true;
        add(ratingSpr);

        if (activeTweens.exists(ratingSpr)) {
            activeTweens.get(ratingSpr).cancel();
            activeTweens.remove(ratingSpr);
        }

        var twn = FlxTween.tween(ratingSpr, {alpha: 0}, 0.2, {
            startDelay: 0.35,
            onComplete: function(_) {
                ratingSpr.kill();
                activeTweens.remove(ratingSpr);
            }
        });
        activeTweens.set(ratingSpr, twn);

        if (currentCombo > 0 && result != MISS) {
            var comboDigits = Std.string(currentCombo).split("");
            var startX:Float = ratingSpr.x + 20;

            for (i in 0...comboDigits.length) {
                var numSpr:FlxSprite = recycle(FlxSprite);
                var numLoaded = AssetHelper.loadGraphicSafely(numSpr, 'ui/game/score/num' + comboDigits[i]);
                if (!numLoaded) {
                    AssetHelper.loadGraphicSafely(numSpr, 'ui/ratings/num' + comboDigits[i]);
                }

                numSpr.setPosition(startX + (i * 24), ratingSpr.y + 70);
                numSpr.acceleration.y = 550;
                numSpr.velocity.y = -FlxG.random.int(120, 150);
                numSpr.velocity.x = FlxG.random.float(-5, 5);
                numSpr.alpha = 1.0;
                numSpr.scale.set(0.5, 0.5);
                numSpr.visible = true;
                add(numSpr);

                if (activeTweens.exists(numSpr)) {
                    activeTweens.get(numSpr).cancel();
                    activeTweens.remove(numSpr);
                }

                var numTwn = FlxTween.tween(numSpr, {alpha: 0}, 0.2, {
                    startDelay: 0.35,
                    onComplete: function(_) {
                        numSpr.kill();
                        activeTweens.remove(numSpr);
                    }
                });
                activeTweens.set(numSpr, numTwn);
            }
        }
    }

    private function dispatchHit(result:Judgment, difference:Float):Void {
        try {
            var bus:Dynamic = EventBus;
            if (Reflect.hasField(bus, "instance") && Reflect.field(bus, "instance") != null) {
                var inst = Reflect.field(bus, "instance");
                if (Reflect.hasField(inst, "emit")) {
                    inst.emit("judgement/hit", {judgement: result, difference: difference, combo: combo, accuracy: accuracy});
                } else if (Reflect.hasField(inst, "publish")) {
                    inst.publish("judgement/hit", {judgement: result, difference: difference, combo: combo, accuracy: accuracy});
                }
            } else if (Reflect.hasField(bus, "emit")) {
                Reflect.callMethod(bus, Reflect.field(bus, "emit"), ["judgement/hit", {judgement: result, difference: difference, combo: combo, accuracy: accuracy}]);
            }
        } catch (e:Dynamic) {}
    }

    private function dispatchMiss():Void {
        try {
            var bus:Dynamic = EventBus;
            if (Reflect.hasField(bus, "instance") && Reflect.field(bus, "instance") != null) {
                var inst = Reflect.field(bus, "instance");
                if (Reflect.hasField(inst, "emit")) {
                    inst.emit("judgement/miss", {misses: misses, accuracy: accuracy});
                } else if (Reflect.hasField(inst, "publish")) {
                    inst.publish("judgement/miss", {misses: misses, accuracy: accuracy});
                }
            } else if (Reflect.hasField(bus, "emit")) {
                Reflect.callMethod(bus, Reflect.field(bus, "emit"), ["judgement/miss", {misses: misses, accuracy: accuracy}]);
            }
        } catch (e:Dynamic) {}
    }

    public function reset():Void {
        for (twn in activeTweens) twn.cancel();
        activeTweens.clear();
        forEach(function(spr:FlxSprite) spr.kill());

        combo = 0;
        misses = 0;
        totalNotesHit = 0;
        totalNotesJudged = 0;
        totalWeight = 0.0;
        accuracy = 0.0;
        health = 1.0;
    }

    override public function destroy():Void {
        for (twn in activeTweens) twn.cancel();
        activeTweens.clear();
        super.destroy();
    }
}