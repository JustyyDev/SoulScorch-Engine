package soulscorch.ui.menus;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import soulscorch.core.Scene;
import soulscorch.core.Runtime;

class OptionsState extends Scene {
    var options:Array<String> = ['Downscroll', 'Ghost Tapping', 'Flashing Lights', 'Antialiasing'];
    var grpOptions:FlxTypedGroup<Alphabet>;
    var checkboxGroup:FlxTypedGroup<FlxSprite>;
    var curSelected:Int = 0;

    override public function create():Void {
        super.create();

        var bg:FlxSprite = new FlxSprite().loadGraphic('assets/images/ui/menuDesat.png');
        bg.color = 0xFFea71fd;
        bg.screenCenter();
        add(bg);

        grpOptions = new FlxTypedGroup<Alphabet>();
        add(grpOptions);

        checkboxGroup = new FlxTypedGroup<FlxSprite>();
        add(checkboxGroup);

        for (i in 0...options.length) {
            var optionText:Alphabet = new Alphabet(150, (70 * i) + 50, options[i], true, false);
            grpOptions.add(optionText);

            var checkbox:FlxSprite = new FlxSprite(optionText.x - 100, optionText.y);
            checkbox.frames = flixel.graphics.frames.FlxAtlasFrames.fromSparrow('assets/images/ui/checkbox.png', 'assets/images/ui/checkbox.xml');
            checkbox.animation.addByPrefix('unchecked', 'checkbox0', 24, false);
            checkbox.animation.addByPrefix('checked', 'checkbox finish', 24, false);
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
            FlxG.switchState(new MainMenuState());
        }
    }

    function changeSelection(change:Int = 0):Void {
        curSelected += change;
        if (curSelected < 0) curSelected = options.length - 1;
        if (curSelected >= options.length) curSelected = 0;

        for (i in 0...grpOptions.length) {
            grpOptions.members[i].alpha = 0.6;
        }
        grpOptions.members[curSelected].alpha = 1;

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
        FlxG.sound.play('assets/sounds/scrollMenu.ogg');
        updateCheckboxes();
    }

    function updateCheckboxes():Void {
        checkboxGroup.forEach(function(box:FlxSprite) {
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