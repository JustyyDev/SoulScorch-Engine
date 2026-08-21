package soulscorch.gameplay;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import haxe.xml.Access;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.system.EventBus;
import soulscorch.backend.system.XMSoul;
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

    // --- Dynamic .xmsoul Popup Physics Config ---
    public var popupScale:Float = 0.7;
    public var numScale:Float = 0.5;
    public var popupGravity:Float = 550.0;
    public var popupFadeDuration:Float = 0.2;
    public var popupHoldTime:Float = 0.35;
    public var numSpacing:Float = 24.0;
    public var baseOffsetX:Float = 0.55;
    public var baseOffsetY:Float = -40.0;

    public var onJudgement:Judgment->Float->Void;
    public var onHealthChange:Float->Void;
    public var onMiss:Note->Void;

    public var targetCamera:FlxCamera;
    private var activeTweens:Map<FlxSprite, FlxTween> = new Map<FlxSprite, FlxTween>();

    public function new(?camera:FlxCamera) {
        super();
        this.targetCamera = camera;
        maxHealth = GameplayFlags.getFloat("maxHealth", 2.0);
        loadConfigFromXMSoul();
        updateWindows();
    }

    public function loadConfigFromXMSoul():Void {
        var access:Access = XMSoul.parse("config/judgments");
        if (access == null) access = XMSoul.parse("data/config/judgments");

        if (access != null) {
            for (node in access.nodes.judgment) {
                var name = XMSoul.getAttr(node, "name", "").toLowerCase();
                var thresh = XMSoul.getFloatAttr(node, "threshold", 45.0);
                switch (name) {
                    case "sick": SICK_WINDOW = thresh;
                    case "good": GOOD_WINDOW = thresh;
                    case "bad": BAD_WINDOW = thresh;
                    case "shit": SHIT_WINDOW = thresh;
                }
            }
        }

        var comboAccess:Access = XMSoul.parse("config/comboPopup");
        if (comboAccess == null) comboAccess = XMSoul.parse("data/config/comboPopup");
        if (comboAccess == null) comboAccess = XMSoul.parse("config/combo");
        if (comboAccess == null) comboAccess = XMSoul.parse("data/config/combo");

        if (comboAccess != null) {
            baseOffsetX = XMSoul.getFloatAttr(comboAccess, "offsetX", 0.55);
            baseOffsetY = XMSoul.getFloatAttr(comboAccess, "offsetY", -40.0);
            popupScale = XMSoul.getFloatAttr(comboAccess, "scale", 0.7);
            popupFadeDuration = XMSoul.getFloatAttr(comboAccess, "alphaFadeDuration", 0.2);

            if (comboAccess.hasNode.numberVelocity) {
                var numNode = comboAccess.node.numberVelocity;
                numSpacing = XMSoul.getFloatAttr(numNode, "spacing", 24.0);
                numScale = XMSoul.getFloatAttr(numNode, "scale", 0.5);
                popupGravity = XMSoul.getFloatAttr(numNode, "gravity", 550.0);
            }
        }
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

        var loaded = AssetHelper.loadGraphicSafely(ratingSpr, 'ui/game/ratings/$ratingName');
        if (!loaded) loaded = AssetHelper.loadGraphicSafely(ratingSpr, 'ui/game/score/$ratingName');
        if (!loaded) loaded = AssetHelper.loadGraphicSafely(ratingSpr, 'ui/ratings/$ratingName');
        if (!loaded) loaded = AssetHelper.loadGraphicSafely(ratingSpr, ratingName);

        ratingSpr.cameras = (targetCamera != null) ? [targetCamera] : (cameras != null ? cameras : null);
        ratingSpr.scrollFactor.set(0, 0);
        ratingSpr.scale.set(popupScale, popupScale);
        ratingSpr.updateHitbox();

        // Exact HUD-relative placement
        var startX:Float = (FlxG.width * baseOffsetX) - (ratingSpr.width * 0.5);
        var startY:Float = (FlxG.height * 0.5) + baseOffsetY - (ratingSpr.height * 0.5);

        ratingSpr.setPosition(startX, startY);
        ratingSpr.acceleration.y = popupGravity;
        ratingSpr.velocity.y = -FlxG.random.int(140, 175);
        ratingSpr.velocity.x = -FlxG.random.int(0, 10);
        ratingSpr.alpha = 1.0;
        ratingSpr.visible = true;
        add(ratingSpr);

        if (activeTweens.exists(ratingSpr)) {
            var oldTwn = activeTweens.get(ratingSpr);
            if (oldTwn != null) oldTwn.cancel();
            activeTweens.remove(ratingSpr);
        }

        var twn = FlxTween.tween(ratingSpr, {alpha: 0.0}, popupFadeDuration, {
            startDelay: popupHoldTime,
            ease: FlxEase.cubeIn,
            onComplete: function(_) {
                ratingSpr.kill();
                activeTweens.remove(ratingSpr);
            }
        });
        activeTweens.set(ratingSpr, twn);

        if (currentCombo >= 0 && result != MISS) {
            var comboStr = Std.string(currentCombo);
            while (comboStr.length < 3) comboStr = "0" + comboStr;

            var numStartX:Float = startX + (ratingSpr.width * 0.5) - ((comboStr.length * numSpacing) * 0.5);
            var numStartY:Float = startY + ratingSpr.height + 4.0;

            for (i in 0...comboStr.length) {
                var digit = comboStr.charAt(i);
                var numSpr:FlxSprite = recycle(FlxSprite);

                var numLoaded = AssetHelper.loadGraphicSafely(numSpr, 'ui/game/ratings/num$digit');
                if (!numLoaded) numLoaded = AssetHelper.loadGraphicSafely(numSpr, 'ui/game/score/num$digit');
                if (!numLoaded) numLoaded = AssetHelper.loadGraphicSafely(numSpr, 'ui/ratings/num$digit');
                if (!numLoaded) numLoaded = AssetHelper.loadGraphicSafely(numSpr, 'num$digit');

                numSpr.cameras = (targetCamera != null) ? [targetCamera] : (cameras != null ? cameras : null);
                numSpr.scrollFactor.set(0, 0);
                numSpr.scale.set(numScale, numScale);
                numSpr.updateHitbox();

                numSpr.setPosition(numStartX + (i * numSpacing), numStartY);
                numSpr.acceleration.y = popupGravity;
                numSpr.velocity.y = -FlxG.random.int(120, 150);
                numSpr.velocity.x = FlxG.random.float(-5, 5);
                numSpr.alpha = 1.0;
                numSpr.visible = true;
                add(numSpr);

                if (activeTweens.exists(numSpr)) {
                    var oldNumTwn = activeTweens.get(numSpr);
                    if (oldNumTwn != null) oldNumTwn.cancel();
                    activeTweens.remove(numSpr);
                }

                var numTwn = FlxTween.tween(numSpr, {alpha: 0.0}, popupFadeDuration, {
                    startDelay: popupHoldTime + 0.05,
                    ease: FlxEase.cubeIn,
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
        for (twn in activeTweens) {
            if (twn != null) twn.cancel();
        }
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
        for (twn in activeTweens) {
            if (twn != null) twn.cancel();
        }
        activeTweens.clear();
        targetCamera = null;
        super.destroy();
    }
}