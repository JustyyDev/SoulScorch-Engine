package soulscorch.ui.menus;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.util.FlxColor;
import soulscorch.core.Scene;
import soulscorch.gameplay.PlayState;

class FreeplayState extends Scene {
    var songs:Array<String> = [];
    var grpSongs:FlxTypedGroup<Alphabet>;
    var iconArray:Array<HealthIcon> = [];
    var curSelected:Int = 0;
    var bg:FlxSprite;

    override public function create():Void {
        super.create();
        
        songs = ["tutorial", "bopeebo", "fresh", "dadbattle"]; 

        bg = new FlxSprite().loadGraphic('assets/images/ui/menuDesat.png');
        bg.color = 0xFF9271FD;
        add(bg);

        grpSongs = new FlxTypedGroup<Alphabet>();
        add(grpSongs);

        for (i in 0...songs.length) {
            var songText:Alphabet = new Alphabet(0, (70 * i) + 30, songs[i], true, true);
            songText.targetY = i;
            grpSongs.add(songText);

            var icon:HealthIcon = new HealthIcon("face");
            iconArray.push(icon);
            add(icon);
        }

        changeSelection(0);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (FlxG.keys.justPressed.UP) changeSelection(-1);
        if (FlxG.keys.justPressed.DOWN) changeSelection(1);

        for (i in 0...iconArray.length) {
            var icon = iconArray[i];
            var item = grpSongs.members[i];
            icon.setPosition(item.x + item.width + 10, item.y - 30);
        }

        if (FlxG.keys.justPressed.ENTER) {
            FlxG.switchState(new PlayState(songs[curSelected], "normal"));
        }
        if (FlxG.keys.justPressed.ESCAPE) {
            FlxG.switchState(new MainMenuState());
        }
    }

    function changeSelection(change:Int = 0):Void {
        FlxG.sound.play('assets/sounds/scrollMenu.ogg', 0.4);

        curSelected += change;

        if (curSelected < 0) curSelected = songs.length - 1;
        if (curSelected >= songs.length) curSelected = 0;

        var index:Int = 0;

        for (i in 0...iconArray.length) {
            iconArray[i].alpha = 0.6;
        }
        iconArray[curSelected].alpha = 1;

        for (item in grpSongs.members) {
            item.targetY = index - curSelected;
            index++;
            item.alpha = 0.6;
            
            if (item.targetY == 0) {
                item.alpha = 1;
            }
        }
    }
}