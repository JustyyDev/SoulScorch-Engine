package soulscorch.backend.system;

import flixel.FlxG;
import flixel.group.FlxGroup;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.system.EventBus;
import soulscorch.backend.utils.Logger;

typedef AchievementDef = {
    var id:String;
    var title:String;
    var description:String;
    var ?hidden:Bool;
}

class Achievements {
    public static var instance(get, null):Achievements;
    private static var _instance:Achievements;

    public var definitions:Map<String, AchievementDef> = new Map();
    public var unlockedAchievements:Map<String, Bool> = new Map();
    public var popupGroup:FlxGroup;

    private var popupQueue:Array<AchievementDef> = [];
    private var isDisplayingPopup:Bool = false;

    public function new() {
        popupGroup = new FlxGroup();
        registerDefaults();
        loadSavedAchievements();
    }

    public static inline function get_instance():Achievements {
        if (_instance == null) {
            _instance = new Achievements();
        }
        return _instance;
    }

    public function registerDefaults():Void {
        add("first_clear", "First Clear", "Clear any song.");
        add("fc_master", "Full Combo", "Clear a song with zero misses.");
        add("s_rank", "S Rank", "Earn an S rating or higher.");
        add("score_100k", "Centurion", "Score over 100,000 points in one song.");
        add("no_miss_streak", "Flawless", "Clear a song with 100% accuracy.");
    }

    public function add(id:String, title:String, description:String, hidden:Bool = false):Void {
        definitions.set(id, {
            id: id,
            title: title,
            description: description,
            hidden: hidden
        });
    }

    public function isUnlocked(id:String):Bool {
        return unlockedAchievements.get(id) == true;
    }

    public function unlock(id:String):Bool {
        if (!definitions.exists(id) || isUnlocked(id)) {
            return false;
        }

        unlockedAchievements.set(id, true);
        saveAchievements();

        var def = definitions.get(id);
        Logger.info('Achievement Unlocked: ${def.title} (${def.id})');
        EventBus.emit("achievement/unlocked", def);

        popupQueue.push(def);
        if (!isDisplayingPopup) {
            displayNextPopup();
        }

        return true;
    }

    private function displayNextPopup():Void {
        if (popupQueue.length == 0) {
            isDisplayingPopup = false;
            return;
        }

        isDisplayingPopup = true;
        var def = popupQueue.shift();

        var popup = new AchievementPopup(def, function() {
            displayNextPopup();
        });

        popupGroup.add(popup);
        AssetHelper.playSoundSafely("confirmMenu", 0.7);
    }

    public function update(elapsed:Float):Void {
        if (popupGroup != null) {
            popupGroup.update(elapsed);
        }
    }

    private function loadSavedAchievements():Void {
        if (FlxG.save.data.unlockedAchievements != null) {
            var saved:Array<String> = cast FlxG.save.data.unlockedAchievements;
            for (id in saved) {
                unlockedAchievements.set(id, true);
            }
        }
    }

    private function saveAchievements():Void {
        var list:Array<String> = [];
        for (id in unlockedAchievements.keys()) {
            if (unlockedAchievements.get(id)) {
                list.push(id);
            }
        }
        FlxG.save.data.unlockedAchievements = list;
        FlxG.save.flush();
    }
}

class AchievementPopup extends FlxSpriteGroup {
    private var onFinished:Void->Void;

    public function new(def:AchievementDef, onFinished:Void->Void) {
        super(20, FlxG.height);
        this.onFinished = onFinished;

        var bg = new flixel.FlxSprite().makeGraphic(380, 80, 0xDD111122);
        add(bg);

        var accent = new flixel.FlxSprite().makeGraphic(6, 80, 0xFFFFCC00);
        add(accent);

        var title = new FlxText(20, 12, 345, "ACHIEVEMENT UNLOCKED", 11);
        title.setFormat(Paths.font("vcr"), 11, 0xFFFFCC00, LEFT);
        add(title);

        var name = new FlxText(20, 28, 345, def.title, 16);
        name.setFormat(Paths.font("vcr"), 16, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
        name.borderSize = 1.25;
        add(name);

        var desc = new FlxText(20, 50, 345, def.description, 12);
        desc.setFormat(Paths.font("vcr"), 12, 0xFFCCCCCC, LEFT);
        add(desc);

        var targetY = FlxG.height - 100;
        FlxTween.tween(this, {y: targetY}, 0.45, {
            ease: FlxEase.backOut,
            onComplete: function(_) {
                FlxTween.tween(this, {y: FlxG.height + 10, alpha: 0}, 0.4, {
                    ease: FlxEase.quadIn,
                    startDelay: 2.8,
                    onComplete: function(_) {
                        destroy();
                        if (this.onFinished != null) {
                            this.onFinished();
                        }
                    }
                });
            }
        });
    }
}