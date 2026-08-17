package soulscorch.menus.states;

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
import soulscorch.backend.assets.Paths;
import soulscorch.backend.input.Controls;
import soulscorch.backend.system.engine.Version;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.menus.credits.CreditsState;
import soulscorch.menus.option.OptionsMenuState;

class MainMenuState extends MusicBeatState {
    public static var curSelected:Int = 0;

    private var menuItems:Array<String> = ["story_mode", "freeplay", "options", "credits"];
    private var grpMenuItems:FlxTypedGroup<FlxSprite>;
    private var bg:FlxSprite;
    private var magenta:FlxSprite;
    private var versionText:FlxText;

    private var selectedSomethin:Bool = false;

    override public function create():Void {
        super.create();

        DiscordRPC.changePresence("Main Menu", "In the Menus");

        persistentUpdate = persistentDraw = true;

        bg = new FlxSprite(-80);
        AssetHelper.loadGraphicSafely(bg, "menus/menuBG");
        bg.scrollFactor.set(0, 0.15);
        bg.setGraphicSize(Std.int(bg.width * 1.175));
        bg.updateHitbox();
        bg.screenCenter();
        bg.antialiasing = true;
        add(bg);

        magenta = new FlxSprite(-80);
        AssetHelper.loadGraphicSafely(magenta, "menus/menuDesat");
        magenta.scrollFactor.set(0, 0.15);
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
            var offset:Float = 108 - (Math.max(menuItems.length, 4) - 4) * 80;
            var menuItem:FlxSprite = new FlxSprite(0, (i * 140) + offset);
            AssetHelper.loadSparrowSafely(menuItem, "menus/mainmenu/menu_" + menuItems[i]);
            menuItem.animation.addByPrefix("idle", menuItems[i] + " basic", 24);
            menuItem.animation.addByPrefix("selected", menuItems[i] + " white", 24);
            menuItem.animation.play("idle");
            menuItem.ID = i;
            menuItem.screenCenter(X);
            menuItem.antialiasing = true;
            grpMenuItems.add(menuItem);
        }

        versionText = new FlxText(12, FlxG.height - 24, 0, Version.fullVersion(), 12);
        versionText.setFormat(Paths.font("vcr"), 12, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
        versionText.scrollFactor.set();
        add(versionText);

        changeItem();
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
        curSelected = FlxMath.wrap(curSelected + huh, 0, menuItems.length - 1);

        grpMenuItems.forEach(function(spr:FlxSprite) {
            spr.animation.play("idle");
            spr.updateHitbox();

            if (spr.ID == curSelected) {
                spr.animation.play("selected");
                spr.centerOffsets();
            }
        });
    }

    private function goToState(choice:String):Void {
        switch (choice) {
            case "story_mode":
                MusicBeatState.switchState(new StoryMenuState());
            case "freeplay":
                MusicBeatState.switchState(new FreeplayState());
            case "options":
                MusicBeatState.switchState(new OptionsMenuState());
            case "credits":
                MusicBeatState.switchState(new CreditsState());
            default:
                MusicBeatState.switchState(new FreeplayState());
        }
    }
}