package soulscorch.ui.menus;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.effects.FlxFlicker;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import soulscorch.core.Scene;
import soulscorch.core.Runtime;
import soulscorch.gameplay.PlayState;

class MainMenuState extends Scene {
    var menuItems:FlxTypedGroup<FlxSprite>;
    var optionShit:Array<String> = ['story_mode', 'freeplay', 'options'];
    var curSelected:Int = 0;
    var magenta:FlxSprite;
    var camFollow:FlxSprite;

    override public function create():Void {
        super.create();

        persistentUpdate = persistentDraw = true;

        var bg:FlxSprite = new FlxSprite(-80).loadGraphic('assets/images/ui/menuBG.png');
        bg.scrollFactor.set(0, 0.18);
        bg.setGraphicSize(Std.int(bg.width * 1.1));
        bg.updateHitbox();
        bg.screenCenter();
        bg.antialiasing = Runtime.engine.config.antialiasing;
        add(bg);

        magenta = new FlxSprite(-80).loadGraphic('assets/images/ui/menuDesat.png');
        magenta.scrollFactor.set(0, 0.18);
        magenta.setGraphicSize(Std.int(magenta.width * 1.1));
        magenta.updateHitbox();
        magenta.screenCenter();
        magenta.visible = false;
        magenta.antialiasing = Runtime.engine.config.antialiasing;
        magenta.color = 0xFFfd719b;
        add(magenta);

        camFollow = new FlxSprite(0, 0).makeGraphic(1, 1, 0x00000000);
        add(camFollow);

        menuItems = new FlxTypedGroup<FlxSprite>();
        add(menuItems);

        for (i in 0...optionShit.length) {
            var menuItem:FlxSprite = new FlxSprite(0, (i * 140) + 90);
            menuItem.frames = flixel.graphics.frames.FlxAtlasFrames.fromSparrow('assets/images/ui/main_menu.png', 'assets/images/ui/main_menu.xml');
            menuItem.animation.addByPrefix('idle', optionShit[i] + " basic", 24);
            menuItem.animation.addByPrefix('selected', optionShit[i] + " white", 24);
            menuItem.animation.play('idle');
            menuItem.ID = i;
            menuItem.screenCenter(X);
            menuItems.add(menuItem);
            menuItem.scrollFactor.set(0, 0.25);
            menuItem.antialiasing = Runtime.engine.config.antialiasing;
        }

        FlxG.camera.follow(camFollow, null, 0.06);
        changeItem();
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (!isTransitioning) {
            if (FlxG.keys.justPressed.UP) changeItem(-1);
            if (FlxG.keys.justPressed.DOWN) changeItem(1);

            if (FlxG.keys.justPressed.ENTER) {
                isTransitioning = true;
                FlxG.sound.play('assets/sounds/confirmMenu.ogg');

                if (Runtime.engine.config.flashingLights) {
                    FlxFlicker.flicker(magenta, 1.1, 0.15, false);
                }

                menuItems.forEach(function(spr:FlxSprite) {
                    if (curSelected != spr.ID) {
                        FlxTween.tween(spr, {alpha: 0}, 0.4, {
                            ease: FlxEase.quadOut,
                            onComplete: function(twn:FlxTween) {
                                spr.kill();
                            }
                        });
                    } else {
                        FlxFlicker.flicker(spr, 1, 0.06, false, false, function(flick:FlxFlicker) {
                            var daChoice:String = optionShit[curSelected];
                            switch (daChoice) {
                                case 'story_mode':
                                    switchScene(new StoryMenuState());
                                case 'freeplay':
                                    switchScene(new FreeplayState());
                                case 'options':
                                    switchScene(new OptionsState());
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
                var add:Float = 0;
                if (menuItems.length > 4) add = menuItems.length * 8;
                camFollow.setPosition(spr.getGraphicMidpoint().x, spr.getGraphicMidpoint().y - add);
                spr.centerOffsets();
            }
        });
    }
}