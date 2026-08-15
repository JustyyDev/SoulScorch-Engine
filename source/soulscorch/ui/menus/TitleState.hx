package soulscorch.ui.menus;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import soulscorch.core.Scene;
import soulscorch.core.Runtime;
import soulscorch.assets.AssetResolver;
import soulscorch.modding.ModLoader;
import soulscorch.gameplay.Conductor;

class TitleState extends Scene {
    var initialized:Bool = false;

    var blackScreen:FlxSprite;
    var credGroup:FlxGroup;
    var textGroup:FlxGroup;
    
    var logoBl:FlxSprite;
    var gfDance:FlxSprite;
    var titleText:FlxSprite;
    
    var curWacky:Array<String> = [];

    var transitioning:Bool = false;

    override public function create():Void {
        super.create();
        #if desktop
        soulscorch.backend.DiscordRPC.changePresence("In the Menus", "Title Screen");
        #end

        curWacky = FlxG.random.getObject(getIntroTextShit());

        if (FlxG.sound.music == null || !FlxG.sound.music.playing) {
            FlxG.sound.playMusic('assets/music/freakyMenu.ogg', 0);
            FlxG.sound.music.fadeIn(4, 0, 0.7);
        }

        startIntro();
    }

    function getIntroTextShit():Array<Array<String>> {
        var path = ModLoader.getPath('assets/data/config/introText.txt');
        var fullText:String = "";
        
        if (AssetResolver.exists(path)) {
            fullText = AssetResolver.getText(path);
        }

        var firstMString:Array<String> = fullText.split('\n');
        var swagGoodBoy:Array<Array<String>> = [];

        for (i in firstMString) {
            stageArray(StringTools.replace(i, '\r', ''), swagGoodBoy);
        }

        return swagGoodBoy;
    }

    function stageArray(daText:String, arrayToAppend:Array<Array<String>>):Void {
        var garray:Array<String> = daText.split('--');
        if (garray.length >= 2) {
            arrayToAppend.push(garray);
        }
    }

    function startIntro():Void {
        if (!initialized) {
            persistentUpdate = true;

            gfDance = new FlxSprite(FlxG.width * 0.4, FlxG.height * 0.07);
            gfDance.frames = FlxAtlasFrames.fromSparrow('assets/images/gfDanceTitle.png', 'assets/images/gfDanceTitle.xml');
            gfDance.animation.addByIndices('danceLeft', 'gfDance', [30, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], "", 24, false);
            gfDance.animation.addByIndices('danceRight', 'gfDance', [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29], "", 24, false);
            gfDance.antialiasing = Runtime.engine.config.antialiasing;
            add(gfDance);

            logoBl = new FlxSprite(-150, -100);
            logoBl.frames = FlxAtlasFrames.fromSparrow('assets/images/logoBumpin.png', 'assets/images/logoBumpin.xml');
            logoBl.animation.addByPrefix('bump', 'logo bumpin', 24, false);
            logoBl.antialiasing = Runtime.engine.config.antialiasing;
            add(logoBl);

            titleText = new FlxSprite(100, FlxG.height * 0.8);
            titleText.frames = FlxAtlasFrames.fromSparrow('assets/images/titleEnter.png', 'assets/images/titleEnter.xml');
            titleText.animation.addByPrefix('idle', "Press Enter to Begin", 24);
            titleText.animation.addByPrefix('press', "ENTER PRESSED", 24);
            titleText.animation.play('idle');
            titleText.antialiasing = Runtime.engine.config.antialiasing;
            add(titleText);

            credGroup = new FlxGroup();
            add(credGroup);
            textGroup = new FlxGroup();

            blackScreen = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
            add(blackScreen);
        }

        initialized = true;
        credGroup.add(new Alphabet(0, 600, "SoulScorch Crew", true));
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (FlxG.sound.music != null) {
            Conductor.songPosition = FlxG.sound.music.time;
        }

        if (FlxG.keys.justPressed.ENTER && !transitioning) {
            transitioning = true;
            titleText.animation.play('press');

            FlxG.camera.flash(FlxColor.WHITE, 1);
            FlxG.sound.play('assets/sounds/confirmMenu.ogg', 0.7);

            new FlxTimer().start(2.0, function(tmr:FlxTimer) {
                switchScene(new MainMenuState());
            });
        }
    }

    override public function beatHit(beat:Int):Void {
        super.beatHit(beat);

        if (logoBl != null) logoBl.animation.play('bump', true);
        if (gfDance != null) {
            if (beat % 2 == 0) gfDance.animation.play('danceLeft', true);
            else gfDance.animation.play('danceRight', true);
        }
    }
}