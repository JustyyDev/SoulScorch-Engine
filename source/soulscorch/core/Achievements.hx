package soulscorch.core;

import flixel.FlxG;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;

/**
 * Global achievement registry and popup manager.
 * Achievements are defined statically and unlocked at runtime.
 */
class Achievements {
    public static var instance(default, null):Achievements;

    public var definitions:Map<String, AchievementDef> = new Map();
    public var queue:Array<String> = [];
    public var popups:FlxGroup;

    public function new() {
        instance = this;
        popups = new FlxGroup();
        registerDefaults();
    }

    public function registerDefaults():Void {
        add("first_clear", "First Clear", "Clear any song.");
        add("fc_master", "Full Combo", "Clear a song with zero misses.");
        add("s_rank", "S Rank", "Earn an S rating or higher.");
        add("score_100k", "Centurion", "Score over 100,000 points in one song.");
        add("no_miss_streak", "Flawless", "Clear a song with 100% accuracy.");
    }

    public function add(id:String, title:String, description:String):Void {
        definitions.set(id, {id: id, title: title, description: description});
    }

    /**
     * Attempts to unlock an achievement. Returns true if newly unlocked.
     */
    public function unlock(id:String):Bool {
        if (!definitions.exists(id)) return false;
        if (SaveData.instance == null) return false;

        var newly = SaveData.instance.unlockAchievement(id);
        if (newly) {
            queue.push(id);
            showPopup(definitions.get(id));
        }
        return newly;
    }

    function showPopup(def:AchievementDef):Void {
        if (popups == null) return;
        var popup = new AchievementPopup(def);
        popup.y = FlxG.height;
        popups.add(popup);
        for (label in popup.getLabels()) {
            label.cameras = popup.cameras;
            popups.add(label);
        }
        FlxTween.tween(popup, {y: FlxG.height - 120}, 0.4, {ease: FlxEase.circOut});
        FlxTween.tween(popup, {alpha: 0}, 0.4, {ease: FlxEase.quadIn, startDelay: 3.0, onComplete: function(_) {
            popup.destroy();
        }});
    }

    public function update(elapsed:Float):Void {
        if (popups != null) popups.update(elapsed);
    }
}

typedef AchievementDef = {
    var id:String;
    var title:String;
    var description:String;
}

class AchievementPopup extends flixel.FlxSprite.FlxSprite {
    var titleLbl:FlxText;
    var descLbl:FlxText;

    public function new(def:AchievementDef) {
        super(20, 0);
        makeGraphic(360, 100, 0xCC111133);
        titleLbl = new FlxText(34, 10, 320, "Achievement Unlocked: " + def.title, 16);
        titleLbl.setFormat(null, 16, FlxColor.YELLOW, LEFT);
        descLbl = new FlxText(34, 36, 320, def.description, 12);
        descLbl.setFormat(null, 12, FlxColor.WHITE, LEFT);
    }

    public function getLabels():Array<FlxText> {
        return [titleLbl, descLbl];
    }
}
