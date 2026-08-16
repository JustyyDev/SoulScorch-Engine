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
import soulscorch.core.Logger;
import soulscorch.assets.Paths;
import soulscorch.ui.Alphabet;
import soulscorch.gameplay.Conductor;

class TitleState extends Scene {
    var initialized:Bool = false;
    var skippedIntro:Bool = false;

    var blackScreen:FlxSprite;
    var credGroup:FlxGroup;
    var textGroup:FlxGroup;
    
    var logoBl:FlxSprite;
    var gfDance:FlxSprite;
    var titleText:FlxText;
    var titleGlow:FlxText;
    
    var curWacky:Array<String> = [];
    var transitioning:Bool = false;

    override public function create():Void {
        super.create();
        #if desktop
        soulscorch.backend.DiscordRPC.changePresence("In the Menus", "Title Screen");
        #end

        curWacky = FlxG.random.getObject(getIntroTextShit());

        var musicPath = Paths.sound('music/freakyMenu');
        #if sys
        if (sys.FileSystem.exists(musicPath)) {
            if (FlxG.sound.music == null || !FlxG.sound.music.playing) {
                FlxG.sound.playMusic(musicPath, 0);
                FlxG.sound.music.fadeIn(4, 0, 0.7);
            }
        } else {
            Logger.warn("title", "Missing freakyMenu.ogg! Music skipped.");
        }
        #end

        startIntro();
    }

    function getIntroTextShit():Array<Array<String>> {
        var path = Paths.txt('data/config/introText');
        var fullText:String = "SoulScorch Engine--Working Code\nCodename Style--Framework Active";
        
        #if sys
        if (sys.FileSystem.exists(path)) {
            fullText = sys.io.File.getContent(path);
        }
        #end

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
        } else {
            arrayToAppend.push(["SoulScorch", "Engine"]);
        }
    }

    function startIntro():Void {
        if (!initialized) {
            persistentUpdate = true;

            var blackBg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
            add(blackBg);

            var glowBar = new FlxSprite(0, FlxG.height * 0.82).makeGraphic(FlxG.width, 2, 0xFF3F8FFF);
            glowBar.alpha = 0.75;
            add(glowBar);

            gfDance = new FlxSprite(FlxG.width * 0.38, FlxG.height * 0.12);
            var gfPng = Paths.image('images/menus/titlescreen/gf');
            var gfXml = Paths.xml('images/menus/titlescreen/gf');
            
            #if sys
            if (sys.FileSystem.exists(gfPng) && sys.FileSystem.exists(gfXml)) {
                gfDance.frames = FlxAtlasFrames.fromSparrow(gfPng, gfXml);
                gfDance.animation.addByIndices('danceLeft', 'gfDance', [30, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], "", 24, false);
                gfDance.animation.addByIndices('danceRight', 'gfDance', [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29], "", 24, false);
                gfDance.animation.play('danceLeft');
            } else {
                gfDance.makeGraphic(160, 220, 0xFF8718D8);
            }
            #end
            gfDance.antialiasing = Runtime.engine.config.antialiasing;
            add(gfDance);

            logoBl = new FlxSprite(FlxG.width * 0.5 - 250, FlxG.height * 0.05);
            var logoPng = Paths.image('images/menus/titlescreen/logo');
            var logoXml = Paths.xml('images/menus/titlescreen/logo');
            
            #if sys
            if (sys.FileSystem.exists(logoPng) && sys.FileSystem.exists(logoXml)) {
                logoBl.frames = FlxAtlasFrames.fromSparrow(logoPng, logoXml);
                logoBl.animation.addByPrefix('bump', 'logo bumpin', 24, false);
                logoBl.animation.play('bump');
            } else {
                logoBl.makeGraphic(300, 180, 0xFFB317FF);
                logoBl.color = 0xFFB317FF;
            }
            #end
            logoBl.antialiasing = Runtime.engine.config.antialiasing;
            add(logoBl);

            titleGlow = new FlxText(0, FlxG.height * 0.72, 0, "Press Enter to Begin", 42);
            titleGlow.setFormat(null, 42, 0xFF7AD1FF, CENTER, FlxTextBorderStyle.OUTLINE, 0xFF123D7A);
            titleGlow.borderSize = 2;
            titleGlow.screenCenter(X);
            titleGlow.alpha = 0.65;
            add(titleGlow);

            titleText = new FlxText(0, FlxG.height * 0.72, 0, "Press Enter to Begin", 42);
            titleText.setFormat(null, 42, 0xFFB4E9FF, CENTER, FlxTextBorderStyle.OUTLINE, 0xFF2753A5);
            titleText.borderSize = 2;
            titleText.screenCenter(X);
            add(titleText);

            credGroup = new FlxGroup();
            add(credGroup);
            textGroup = new FlxGroup();

            blackScreen = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
            blackScreen.alpha = 0.55;
            add(blackScreen);
        }

        initialized = true;
        createCoolText(["SoulScorch Crew presents"]);
    }

    function createCoolText(textArray:Array<String>):Void {
        for (i in 0...textArray.length) {
            var money = new Alphabet(0, 0, textArray[i], true);
            money.screenCenter(X);
            money.y += (i * 60) + 200;
            credGroup.add(money);
        }
    }

    function addMoreText(text:String):Void {
        var coolText = new Alphabet(0, 0, text, true);
        coolText.screenCenter(X);
        coolText.y += (credGroup.length * 60) + 200;
        credGroup.add(coolText);
    }

    function deleteCoolText():Void {
        while (credGroup.members.length > 0) {
            credGroup.remove(credGroup.members[0], true);
        }
    }

    function skipIntro():Void {
        if (!skippedIntro) {
            remove(blackScreen);
            remove(credGroup);
            FlxG.camera.flash(FlxColor.WHITE, 2);
            skippedIntro = true;
        }
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (FlxG.sound.music != null) {
            Conductor.songPosition = FlxG.sound.music.time;
        }

        if (FlxG.keys.justPressed.ENTER) {
            if (!skippedIntro) {
                skipIntro();
            } else if (!transitioning) {
                transitioning = true;
                if (titleText != null && titleText.text != null && titleText.text.length > 0) {
                    titleText.text = "ENTER PRESSED";
                }

                FlxG.camera.flash(FlxColor.WHITE, 1);
                var confirmSound = Paths.sound('sounds/confirmMenu');
                #if sys
                if (sys.FileSystem.exists(confirmSound)) {
                    FlxG.sound.play(confirmSound, 0.7);
                }
                #end

                new FlxTimer().start(2.0, function(tmr:FlxTimer) {
                    switchScene(new MainMenuState());
                });
            }
        }
    }

    override public function beatHit(beat:Int):Void {
        super.beatHit(beat);

        if (logoBl != null && logoBl.frames != null) logoBl.animation.play('bump', true);
        if (gfDance != null && gfDance.frames != null) {
            if (beat % 2 == 0) gfDance.animation.play('danceLeft', true);
            else gfDance.animation.play('danceRight', true);
        }

        switch (beat) {
            case 1: createCoolText(["SoulScorch Engine"]);
            case 3: addMoreText("present");
            case 4: deleteCoolText();
            case 5: createCoolText([curWacky[0]]);
            case 7: addMoreText(curWacky[1]);
            case 8: deleteCoolText();
            case 9: createCoolText(["Codename Style"]);
            case 11: addMoreText("Engine Framework");
            case 12: deleteCoolText();
            case 13: addMoreText("SoulScorch");
            case 14: addMoreText("Engine");
            case 15: skipIntro();
        }
    }
}