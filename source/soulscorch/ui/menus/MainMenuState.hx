package soulscorch.ui.menus;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.effects.FlxFlicker;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.math.FlxMath;
import soulscorch.backend.MusicBeatState;
import soulscorch.core.Runtime;
import soulscorch.core.Version;
import soulscorch.assets.Paths;
import soulscorch.assets.AssetHelper;
import soulscorch.ui.menus.credits.SoulCreditsState;

class MainMenuState extends MusicBeatState {
    var curSelected:Int = 0;
    var menuItems:FlxGroup;
    var optionShit:Array<String> = ["story mode", "freeplay", "credits", "options"];
    
    var bg:FlxSprite;
    var magenta:FlxSprite;
    var camFollow:FlxSprite;
    var headerText:FlxText;
    var accentBar:FlxSprite;
    var selectedSomethin:Bool = false;

    override public function create():Void {
        super.create();
        #if desktop
        soulscorch.backend.DiscordRPC.changePresence("In the Menus", "Main Menu");
        #end

        bg = new FlxSprite(-80);
        AssetHelper.loadGraphicSafely(bg, 'images/menus/menuBG');
        bg.scrollFactor.set(0, 0.18);
        bg.setGraphicSize(Std.int(bg.width * 1.1));
        bg.updateHitbox();
        bg.screenCenter();
        bg.antialiasing = Runtime.engine.config.antialiasing;
        add(bg);

        var panel = new FlxSprite(60, 50).makeGraphic(FlxG.width - 120, FlxG.height - 100, 0x29000000);
        panel.alpha = 0.7;
        add(panel);

        accentBar = new FlxSprite(90, 110).makeGraphic(FlxG.width - 180, 4, 0xFF6BE7FF);
        accentBar.alpha = 0.8;
        add(accentBar);

        headerText = new FlxText(0, 52, 0, "SOULSCORCH", 26);
        headerText.setFormat(null, 26, 0xFFBCEBFF, CENTER, FlxTextBorderStyle.OUTLINE, 0xFF1B3B7C);
        headerText.borderSize = 2;
        headerText.screenCenter(X);
        add(headerText);

        var subtitle:FlxText = new FlxText(0, 86, 0, "RHYTHM // MODS // MOTION", 12);
        subtitle.setFormat(null, 12, 0xFF79B9D8, CENTER);
        subtitle.screenCenter(X);
        add(subtitle);

        var versionText = new FlxText(0, FlxG.height - 28, 0, Version.fullVersion(), 14);
        versionText.setFormat(null, 14, 0x88BEEBFF, CENTER);
        versionText.screenCenter(X);
        add(versionText);

        var watermark:FlxText = new FlxText(FlxG.width - 250, FlxG.height - 42, 230, "SoulScorch Engine\nCodename UI Base", 11);
        watermark.setFormat(null, 11, 0xFF84A6B9, RIGHT);
        add(watermark);

        magenta = new FlxSprite(-80);
        AssetHelper.loadGraphicSafely(magenta, 'images/menus/menuBGMagenta');
        magenta.scrollFactor.set(0, 0.18);
        magenta.setGraphicSize(Std.int(magenta.width * 1.1));
        magenta.updateHitbox();
        magenta.screenCenter();
        magenta.antialiasing = Runtime.engine.config.antialiasing;
        magenta.visible = false;
        add(magenta);

        menuItems = new FlxGroup();
        add(menuItems);

        var scale:Float = 1;
        if (optionShit.length > 6) {
            scale = 6 / optionShit.length;
        }

        for (i in 0...optionShit.length) {
            var offset:Float = 170 - (Math.max(optionShit.length, 4) - 4) * 80;
            var menuItem:FlxSprite = new FlxSprite(0, (i * 120) + offset);
            menuItem.scale.x = scale;
            menuItem.scale.y = scale;
            var menuPath:String = 'images/menus/mainmenu/' + optionShit[i];
            menuItem.frames = Paths.getFrames(menuPath);
            menuItem.animation.addByPrefix('idle', optionShit[i] + " basic", 24);
            menuItem.animation.addByPrefix('selected', optionShit[i] + " white", 24);
            menuItem.animation.play('idle');
            menuItem.ID = i;
            menuItem.alpha = 0.72;
            menuItem.screenCenter(X);
            menuItems.add(menuItem);
            menuItem.antialiasing = Runtime.engine.config.antialiasing;
        }

        FlxG.camera.follow(bg, LOCKON, 0.15);

        changeItem();
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (!selectedSomethin) {
            if (FlxG.keys.justPressed.UP) {
                FlxG.sound.play(Paths.sound('sounds/menu/scroll'));
                changeItem(-1);
            }
            if (FlxG.keys.justPressed.DOWN) {
                FlxG.sound.play(Paths.sound('sounds/menu/scroll'));
                changeItem(1);
            }

            if (FlxG.keys.justPressed.BACKSPACE) {
                FlxG.switchState(new TitleState());
            }

            if (FlxG.keys.justPressed.M) {
                openSubState(new ModSwitchMenu());
            }

            if (FlxG.keys.justPressed.ENTER) {
                selectedSomethin = true;
                FlxG.sound.play(Paths.sound('sounds/menu/confirm'));

                if (Runtime.engine.config.antialiasing) {
                    FlxFlicker.flicker(magenta, 1.1, 0.15, false);
                }

                menuItems.forEach(function(basic:flixel.FlxBasic) {
                    var spr:FlxSprite = cast basic;
                    if (curSelected != spr.ID) {
                        FlxTween.tween(spr, {alpha: 0}, 0.4, {
                            ease: FlxEase.quadOut
                        });
                    } else {
                        FlxFlicker.flicker(spr, 1, 0.06, false, false, function(flick:FlxFlicker) {
                            var daChoice:String = optionShit[curSelected];
                            switch (daChoice) {
                                case 'story mode':
                                    FlxG.switchState(new StoryMenuState());
                                case 'freeplay':
                                    FlxG.switchState(new FreeplayState());
                                case 'credits':
                                    FlxG.switchState(new SoulCreditsState());
                                case 'mods':
                                    openSubState(new ModSwitchMenu());
                                case 'options':
                                    FlxG.switchState(new OptionsMenuState());
                            }
                        });
                    }
                });
            }
        }
    }

    function changeItem(huh:Int = 0):Void {
        curSelected += huh;
        if (curSelected >= optionShit.length) curSelected = 0;
        if (curSelected < 0) curSelected = optionShit.length - 1;

        menuItems.forEach(function(basic:flixel.FlxBasic) {
            var spr:FlxSprite = cast basic;
            spr.animation.play('idle');
            spr.alpha = 0.7;
            spr.color = 0xFFB8D9FF;
            spr.updateHitbox();

            if (spr.ID == curSelected) {
                spr.animation.play('selected');
                spr.alpha = 1;
                spr.color = 0xFF7AE8FF;
                spr.centerOffsets();
                FlxG.camera.follow(spr, LOCKON, 0.15);
            }
        });
    }
}