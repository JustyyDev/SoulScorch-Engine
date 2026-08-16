package soulscorch.ui.menus.credits;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import soulscorch.core.Scene;
import soulscorch.core.Runtime;
import soulscorch.assets.Paths;
import soulscorch.assets.AssetHelper;
import soulscorch.ui.Alphabet;
import soulscorch.ui.menus.MainMenuState;

class SoulCreditsState extends Scene {
    var curSelected:Int = 0;
    var grpCategories:FlxTypedGroup<Alphabet>;
    var memberTexts:FlxTypedGroup<FlxText>;
    
    var bg:FlxSprite;
    var descPanel:FlxSprite;
    var headerText:FlxText;
    var categorySubtitle:FlxText;
    var memberRoleText:FlxText;
    var memberDescText:FlxText;

    override public function create():Void {
        super.create();
        #if desktop
        soulscorch.backend.DiscordRPC.changePresence("In the Menus", "SoulScorch Credits");
        #end

        // Dark atmospheric background matching SoulScorch identity
        bg = new FlxSprite();
        AssetHelper.loadGraphicSafely(bg, 'images/menus/menuBG');
        bg.scrollFactor.set(0, 0);
        bg.color = 0xFF1A1830;
        bg.screenCenter();
        bg.antialiasing = Runtime.engine.config.antialiasing;
        add(bg);

        var accentPanel = new FlxSprite(70, 60).makeGraphic(FlxG.width - 140, FlxG.height - 120, 0x16000000);
        add(accentPanel);

        headerText = new FlxText(0, 70, 0, "CREDITS", 28);
        headerText.setFormat(null, 28, 0xFFBEEBFF, CENTER, FlxTextBorderStyle.OUTLINE, 0xFF123D7A);
        headerText.borderSize = 2;
        headerText.screenCenter(X);
        add(headerText);

        // Bottom description panel background
        descPanel = new FlxSprite(0, FlxG.height - 180).makeGraphic(FlxG.width, 180, 0xFF0A1223);
        descPanel.alpha = 0.9;
        add(descPanel);

        categorySubtitle = new FlxText(40, FlxG.height - 165, FlxG.width - 80, "", 20);
        categorySubtitle.setFormat(null, 20, 0xFF7AE8FF, LEFT, FlxTextBorderStyle.OUTLINE, 0xFF123D7A);
        categorySubtitle.borderSize = 1;
        add(categorySubtitle);

        memberRoleText = new FlxText(40, FlxG.height - 130, FlxG.width - 80, "", 26);
        memberRoleText.setFormat(null, 26, 0xFFFFFFFF, LEFT, FlxTextBorderStyle.OUTLINE, 0xFF123D7A);
        memberRoleText.borderSize = 1;
        add(memberRoleText);

        memberDescText = new FlxText(40, FlxG.height - 90, FlxG.width - 80, "", 18);
        memberDescText.setFormat(null, 18, 0xFFB8D6FF, LEFT, FlxTextBorderStyle.OUTLINE, 0xFF123D7A);
        memberDescText.borderSize = 1;
        add(memberDescText);

        grpCategories = new FlxTypedGroup<Alphabet>();
        add(grpCategories);

        for (i in 0...SoulCreditsData.categories.length) {
            var cat = SoulCreditsData.categories[i];
            var catItem = new Alphabet(0, (i * 90) + 120, cat.title, true);
            catItem.ID = i;
            catItem.x += 80;
            grpCategories.add(catItem);
        }

        updateSelection();
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (FlxG.keys.justPressed.UP) {
            FlxG.sound.play(Paths.sound('sounds/menu/scroll'));
            changeSelection(-1);
        }
        if (FlxG.keys.justPressed.DOWN) {
            FlxG.sound.play(Paths.sound('sounds/menu/scroll'));
            changeSelection(1);
        }

        if (FlxG.keys.justPressed.BACKSPACE || FlxG.keys.justPressed.ESCAPE) {
            FlxG.sound.play(Paths.sound('sounds/menu/cancel'));
            FlxG.switchState(new MainMenuState());
        }
    }

    function changeSelection(change:Int = 0):Void {
        curSelected += change;
        if (curSelected < 0) curSelected = SoulCreditsData.categories.length - 1;
        if (curSelected >= SoulCreditsData.categories.length) curSelected = 0;

        updateSelection();
    }

    function updateSelection():Void {
        var activeCategory = SoulCreditsData.categories[curSelected];
        
        categorySubtitle.text = "> " + activeCategory.subtitle;
        
        if (activeCategory.members.length > 0) {
            memberRoleText.text = activeCategory.members[0].name + " — " + activeCategory.members[0].role;
            memberDescText.text = activeCategory.members[0].desc;
        }

        var bullShit:Int = 0;
        grpCategories.forEach(function(item:Alphabet) {
            item.y = (bullShit - curSelected) * 90 + 200;
            bullShit++;
            item.alpha = 0.6;
            item.color = 0xFFD8EEFF;
            
            if (item.ID == curSelected) {
                item.alpha = 1.0;
                item.color = 0xFF7AE8FF;
            }
        });
    }
}