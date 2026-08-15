package soulscorch.ui.menus;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.effects.FlxFlicker;
import soulscorch.core.Scene;
import soulscorch.assets.AssetHelper;
import soulscorch.input.InputMap;
import soulscorch.gameplay.PlayState;
import soulscorch.ui.ScriptedState;

class MainMenuState extends Scene {
    var optionShit:Array<String> = ['story_mode', 'freeplay', 'options'];
    var curSelected:Int = 0;
    var menuItems:FlxTypedGroup<FlxSprite>;
    var bg:FlxSprite;
    var magenta:FlxSprite;
    var selectedSomethin:Bool = false;

    override public function create():Void {
        super.create();

        #if desktop
        soulscorch.backend.DiscordRPC.changePresence("In the Menus", "Main Menu");
        #end

        bg = new FlxSprite(-80).loadGraphic('assets/images/menuBG.png');
        bg.scrollFactor.set(0, 0.18);
        bg.setGraphicSize(Std.int(bg.width * 1.175));
        bg.updateHitbox();
        bg.screenCenter();
        bg.antialiasing = true;
        add(bg);

        magenta = new FlxSprite(-80).loadGraphic('assets/images/menuDesat.png');
        magenta.scrollFactor.set(0, 0.18);
        magenta.setGraphicSize(Std.int(magenta.width * 1.175));
        magenta.updateHitbox();
        magenta.screenCenter();
        magenta.visible = false;
        magenta.antialiasing = true;
        magenta.color = 0xFFFD719B;
        add(magenta);

        menuItems = new FlxTypedGroup<FlxSprite>();
        add(menuItems);

        for (i in 0...optionShit.length) {
            var menuItem:FlxSprite = new FlxSprite(0, 60 + (i * 160));
            AssetHelper.loadSparrowSafely(menuItem, 'assets/images/mainmenu/menu_' + optionShit[i] + '.png', 'assets/images/mainmenu/menu_' + optionShit[i] + '.xml');
            menuItem.animation.addByPrefix('idle', optionShit[i] + " basic", 24);
            menuItem.animation.addByPrefix('selected', optionShit[i] + " white", 24);
            menuItem.animation.play('idle');
            menuItem.ID = i;
            menuItem.screenCenter(X);
            menuItems.add(menuItem);
            menuItem.antialiasing = true;
        }

        changeItem(0);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (!selectedSomethin) {
            if (InputMap.justPressed("up")) changeItem(-1);
            if (InputMap.justPressed("down")) changeItem(1);

            if (InputMap.justPressed("accept")) {
                selectedSomethin = true;
                AssetHelper.playSoundSafely('assets/sounds/confirmMenu.ogg', 0.7);

                if (magenta != null) FlxFlicker.flicker(magenta, 1.1, 0.15, false);

                menuItems.forEach(function(spr:FlxSprite) {
                    if (curSelected != spr.ID) {
                        FlxTween.tween(spr, {alpha: 0}, 0.4, {ease: FlxEase.quadOut});
                    } else {
                        FlxFlicker.flicker(spr, 1, 0.06, false, false, function(flick:FlxFlicker) {
                            var daChoice:String = optionShit[curSelected];
                            switch (daChoice) {
                                case 'story_mode' | 'freeplay':
                                    FlxG.switchState(new PlayState());
                                case 'options':
                                    FlxG.switchState(new ScriptedState("OptionsState"));
                            }
                        });
                    }
                });
            }
        }
    }

    function changeItem(huh:Int = 0):Void {
        curSelected += huh;
        if (curSelected >= menuItems.length) curSelected = 0;
        if (curSelected < 0) curSelected = menuItems.length - 1;

        menuItems.forEach(function(spr:FlxSprite) {
            spr.animation.play('idle');
            spr.updateHitbox();
            if (spr.ID == curSelected) {
                spr.animation.play('selected');
                spr.centerOffsets();
            }
        });
    }
}