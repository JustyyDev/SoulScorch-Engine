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
    var ?icon:String;
}

class Achievements {
    public static var instance(get, null):Achievements;
    private static var _instance:Achievements;

    public var definitions:Map<String, AchievementDef> = new Map<String, AchievementDef>();
    public var unlockedAchievements:Map<String, Bool> = new Map<String, Bool>();
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

    public function add(id:String, title:String, description:String, hidden:Bool = false, ?icon:String = "achievements/default"):Void {
        definitions.set(id, {
            id: id,
            title: title,
            description: description,
            hidden: hidden,
            icon: icon
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
        Logger.info('Achievement Unlocked: ${def.title} (${def.id})', "achievements");

        try {
            var bus:Dynamic = EventBus;
            if (Reflect.hasField(bus, "publish")) {
                bus.publish("achievement/unlocked", def);
            } else if (Reflect.hasField(bus, "emit")) {
                bus.emit("achievement/unlocked", def);
            }
        } catch (e:Dynamic) {}

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
        if (FlxG.save != null && FlxG.save.data != null && FlxG.save.data.unlockedAchievements != null) {
            try {
                var saved:Array<Dynamic> = cast FlxG.save.data.unlockedAchievements;
                for (id in saved) {
                    unlockedAchievements.set(Std.string(id), true);
                }
            } catch (e:Dynamic) {
                Logger.warn('Failed restoring unlocked achievements: $e', "achievements");
            }
        }
    }

    private function saveAchievements():Void {
        if (FlxG.save != null && FlxG.save.data != null) {
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
}

class AchievementPopup extends FlxSpriteGroup {
    private var onFinished:Void->Void;

    public function new(def:AchievementDef, onFinished:Void->Void) {
        super(20, FlxG.height);
        this.onFinished = onFinished;

        var bg = new flixel.FlxSprite().makeGraphic(390, 80, 0xEE11101D);
        add(bg);

        var accent = new flixel.FlxSprite().makeGraphic(6, 80, 0xFFFFCC00);
        add(accent);

        var title = new FlxText(20, 10, 355, "ACHIEVEMENT UNLOCKED", 11);
        title.setFormat(Paths.font("vcr"), 11, 0xFFFFCC00, LEFT);
        add(title);

        var name = new FlxText(20, 26, 355, def.title, 16);
        name.setFormat(Paths.font("vcr"), 16, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
        name.borderSize = 1.25;
        add(name);

        var desc = new FlxText(20, 48, 355, def.description, 12);
        desc.setFormat(Paths.font("vcr"), 12, 0xFFCCCCCC, LEFT);
        add(desc);

        scrollFactor.set(0, 0);

        var targetY = FlxG.height - 100;
        FlxTween.tween(this, {y: targetY}, 0.45, {
            ease: FlxEase.backOut,
            onComplete: function(_) {
                FlxTween.tween(this, {y: FlxG.height + 10, alpha: 0}, 0.4, {
                    ease: FlxEase.quadIn,
                    startDelay: 3.0,
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