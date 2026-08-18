package soulscorch.ui.menus.states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.effects.FlxFlicker;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.input.Controls;
import soulscorch.backend.input.MobilePad;
import soulscorch.backend.system.engine.Version;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.ui.hud.Alphabet;
import soulscorch.ui.menus.credits.CreditsState;
import soulscorch.ui.menus.option.OptionsMenuState;
import soulscorch.ui.menus.states.FreeplayState;
import soulscorch.ui.menus.states.StoryMenuState;
import soulscorch.ui.menus.states.TitleState;

using StringTools;

class MainMenuState extends MusicBeatState {
    public static var curSelected:Int = 0;

    private var menuItems:Array<String> = [];
    private var grpMenuItems:FlxTypedGroup<FlxSprite>;
    private var bg:FlxSprite;
    private var magenta:FlxSprite;
    private var versionText:FlxText;
    private var mobileControls:MobilePad;

    private var selectedSomethin:Bool = false;

    override public function create():Void {
        super.create();

        #if desktop
        DiscordRPC.changePresence("Main Menu", "In the Menus");
        #end
        persistentUpdate = persistentDraw = true;

        loadMenuItems();

        bg = new FlxSprite(-80);
        if (!AssetHelper.loadGraphicSafely(bg, "menuBG")) {
            bg.makeGraphic(FlxG.width, FlxG.height, 0xFF282828);
        }
        bg.scrollFactor.set(0, 0.12);
        bg.setGraphicSize(Std.int(bg.width * 1.175));
        bg.updateHitbox();
        bg.screenCenter();
        bg.antialiasing = true;
        add(bg);

        magenta = new FlxSprite(-80);
        if (!AssetHelper.loadGraphicSafely(magenta, "menuDesat")) {
            magenta.makeGraphic(FlxG.width, FlxG.height, 0xFFFD719B);
        }
        magenta.scrollFactor.set(0, 0.12);
        magenta.setGraphicSize(Std.int(magenta.width * 1.175));
        magenta.updateHitbox();
        magenta.screenCenter();
        magenta.visible = false;
        magenta.color = 0xFFFD719B;
        magenta.antialiasing = true;
        add(magenta);

        grpMenuItems = new FlxTypedGroup<FlxSprite>();
        add(grpMenuItems);

        for (i in 0...menuItems.length) {
            var itemKey = menuItems[i].trim().toLowerCase();
            var offset:Float = 108 - (Math.max(menuItems.length, 4) - 4) * 80;
            var menuItem:FlxSprite = new FlxSprite(0, (i * 140) + offset);

            var loaded = AssetHelper.loadSparrowSafely(menuItem, "menus/mainmenu/menu_" + itemKey);
            if (loaded && menuItem.frames != null) {
                menuItem.animation.addByPrefix("idle", itemKey + " basic", 24);
                menuItem.animation.addByPrefix("selected", itemKey + " white", 24);
                menuItem.animation.play("idle");
                menuItem.ID = i;
                menuItem.screenCenter(X);
                menuItem.antialiasing = true;
                grpMenuItems.add(menuItem);
            } else {
                var alphaLabel = new Alphabet(0, (i * 140) + offset, itemKey.replace("_", " ").toUpperCase(), true);
                alphaLabel.screenCenter(X);
                alphaLabel.ID = i;
                grpMenuItems.add(alphaLabel);
            }
        }

        versionText = new FlxText(12, FlxG.height - 24, 0, Version.fullVersion(), 12);
        versionText.setFormat(Paths.font("vcr"), 12, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
        versionText.scrollFactor.set();
        add(versionText);

        #if (mobile || debug)
        mobileControls = new MobilePad(FULL, A_B);
        add(mobileControls);
        Controls.instance.bindMobilePad(mobileControls);
        #end

        changeItem();
    }

    private function loadMenuItems():Void {
        var rawText:String = AssetResolver.getText("data/config/menuItems");
        if (rawText.length == 0) {
            rawText = AssetResolver.getText("assets/preload/data/config/menuItems.txt");
        }

        menuItems = [];
        if (rawText.trim().length > 0) {
            for (line in rawText.split("\n")) {
                var clean = line.trim();
                if (clean.length > 0 && !clean.startsWith("//") && !clean.startsWith("#")) {
                    menuItems.push(clean);
                }
            }
        }

        if (menuItems.length == 0) {
            menuItems = ["story_mode", "freeplay", "options", "credits"];
        }
    }

    override public function update(elapsed:Float):Void {
        if (!selectedSomethin) {
            if (Controls.instance.UI_UP_P) {
                AssetHelper.playSoundSafely("scrollMenu", 0.7);
                changeItem(-1);
            }
            if (Controls.instance.UI_DOWN_P) {
                AssetHelper.playSoundSafely("scrollMenu", 0.7);
                changeItem(1);
            }
            if (Controls.instance.BACK) {
                AssetHelper.playSoundSafely("cancelMenu", 0.7);
                MusicBeatState.switchState(new TitleState());
            }

            if (Controls.instance.ACCEPT) {
                selectedSomethin = true;
                AssetHelper.playSoundSafely("confirmMenu", 0.7);

                if (magenta != null) {
                    FlxFlicker.flicker(magenta, 1.1, 0.15, false);
                }

                grpMenuItems.forEach(function(spr:FlxSprite) {
                    if (curSelected != spr.ID) {
                        FlxTween.tween(spr, {alpha: 0}, 0.4, {
                            ease: FlxEase.quadOut,
                            onComplete: function(_) spr.kill()
                        });
                    } else {
                        FlxFlicker.flicker(spr, 1.0, 0.06, false, false, function(_) {
                            goToState(menuItems[curSelected]);
                        });
                    }
                });
            }
        }

        super.update(elapsed);

        grpMenuItems.forEach(function(spr:FlxSprite) {
            spr.screenCenter(X);
        });
    }

    private function changeItem(huh:Int = 0):Void {
        if (menuItems.length == 0) return;
        curSelected = FlxMath.wrap(curSelected + huh, 0, menuItems.length - 1);

        grpMenuItems.forEach(function(spr:FlxSprite) {
            if (spr.animation != null && spr.animation.getByName("idle") != null) {
                spr.animation.play("idle");
                spr.updateHitbox();
            }

            spr.alpha = (spr.ID == curSelected ? 1.0 : 0.6);

            if (spr.ID == curSelected) {
                if (spr.animation != null && spr.animation.getByName("selected") != null) {
                    spr.animation.play("selected");
                    spr.centerOffsets();
                }
            }
        });
    }

    private function goToState(choice:String):Void {
        var clean = choice != null ? choice.trim().toLowerCase() : "";
        switch (clean) {
            case "story_mode" | "story" | "storymode":
                MusicBeatState.switchState(new StoryMenuState());
            case "freeplay":
                MusicBeatState.switchState(new FreeplayState());
            case "options" | "settings":
                MusicBeatState.switchState(new OptionsMenuState());
            case "credits":
                MusicBeatState.switchState(new CreditsState());
            default:
                MusicBeatState.switchState(new FreeplayState());
        }
    }

    override public function destroy():Void {
        Controls.instance.unbindMobilePad();
        super.destroy();
    }
}