package soulscorch.ui.menus;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import soulscorch.core.Scene;
import soulscorch.core.Runtime;
import soulscorch.core.NotificationManager;
import soulscorch.assets.Paths;
import soulscorch.assets.AssetHelper;
import soulscorch.ui.Alphabet;

class OptionsState extends Scene {
    var options:Array<String> = ['Downscroll', 'Ghost Tapping', 'Flashing Lights', 'Antialiasing'];
    var grpOptions:FlxTypedGroup<Alphabet>;
    var checkboxGroup:FlxTypedGroup<FlxSprite>;
    var headerText:FlxText;
    var panel:FlxSprite;
    var curSelected:Int = 0;

    override public function create():Void {
        super.create();

        var bg:FlxSprite = new FlxSprite();
        AssetHelper.loadGraphicSafely(bg, 'images/menus/menuDesat');
        bg.color = 0xFF1B1531;
        bg.screenCenter();
        add(bg);

        panel = new FlxSprite(120, 80).makeGraphic(FlxG.width - 240, FlxG.height - 160, 0x16000000);
        add(panel);

        headerText = new FlxText(0, 52, 0, "SETTINGS", 28);
        headerText.setFormat(null, 28, 0xFFBFE8FF, CENTER, FlxTextBorderStyle.OUTLINE, 0xFF123D7A);
        headerText.borderSize = 2;
        headerText.screenCenter(X);
        add(headerText);

        grpOptions = new FlxTypedGroup<Alphabet>();
        add(grpOptions);

        checkboxGroup = new FlxTypedGroup<FlxSprite>();
        add(checkboxGroup);

        for (i in 0...options.length) {
            var optionText:Alphabet = new Alphabet(150, (70 * i) + 50, options[i], true);
            grpOptions.add(optionText);

            var checkbox:FlxSprite = new FlxSprite(optionText.x - 100, optionText.y);
            checkbox.frames = Paths.getFrames('images/menus/options/checkboxThingie');
            checkbox.animation.addByPrefix('unchecked', 'Check Box unselected', 24, false);
            checkbox.animation.addByPrefix('checked', 'Check Box Selected Static', 24, false);
            checkbox.antialiasing = Runtime.engine.config.antialiasing;
            checkbox.ID = i;
            checkboxGroup.add(checkbox);
        }

        changeSelection();
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (FlxG.keys.justPressed.UP) changeSelection(-1);
        if (FlxG.keys.justPressed.DOWN) changeSelection(1);

        if (FlxG.keys.justPressed.ENTER) {
            toggleOption();
        }

        if (FlxG.keys.justPressed.ESCAPE) {
            Runtime.engine.config.save();
            if (NotificationManager.instance != null) {
                NotificationManager.instance.notify("Settings Saved", "Your preferences were saved.");
            }
            FlxG.switchState(new MainMenuState());
        }
    }

    function changeSelection(change:Int = 0):Void {
        curSelected += change;
        if (curSelected < 0) curSelected = options.length - 1;
        if (curSelected >= options.length) curSelected = 0;

        for (i in 0...grpOptions.length) {
            grpOptions.members[i].alpha = 0.6;
            grpOptions.members[i].color = 0xFFCFEAFF;
        }
        grpOptions.members[curSelected].alpha = 1;
        grpOptions.members[curSelected].color = 0xFF7AE8FF;

        updateCheckboxes();
    }

    function toggleOption():Void {
        switch (options[curSelected]) {
            case 'Downscroll':
                Runtime.engine.config.downscroll = !Runtime.engine.config.downscroll;
            case 'Ghost Tapping':
                Runtime.engine.config.ghostTapping = !Runtime.engine.config.ghostTapping;
            case 'Flashing Lights':
                Runtime.engine.config.flashingLights = !Runtime.engine.config.flashingLights;
            case 'Antialiasing':
                Runtime.engine.config.antialiasing = !Runtime.engine.config.antialiasing;
        }
        FlxG.sound.play(Paths.sound('sounds/menu/scroll'));
        updateCheckboxes();
    }

    function updateCheckboxes():Void {
        checkboxGroup.forEach(function(basic:flixel.FlxBasic):Void {
            var box:FlxSprite = cast basic;
            if (box == null) return;
            var isChecked:Bool = false;
            switch (options[box.ID]) {
                case 'Downscroll': isChecked = Runtime.engine.config.downscroll;
                case 'Ghost Tapping': isChecked = Runtime.engine.config.ghostTapping;
                case 'Flashing Lights': isChecked = Runtime.engine.config.flashingLights;
                case 'Antialiasing': isChecked = Runtime.engine.config.antialiasing;
            }
            box.animation.play(isChecked ? 'checked' : 'unchecked');
        });
    }
}