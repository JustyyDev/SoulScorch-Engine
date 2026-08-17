package soulscorch.ui.menus.states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.input.Controls;
import soulscorch.backend.system.engine.Runtime;
import soulscorch.backend.system.engine.Version;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.ui.menus.states.MainMenuState;

class TitleState extends MusicBeatState {
    public static var initialized:Bool = false;
    public static var closedIntro:Bool = false;

    private var blackScreen:FlxSprite;
    private var textGroup:FlxGroup;
    private var logoBump:FlxSprite;
    private var gfDance:FlxSprite;
    private var titleText:FlxSprite;

    private var curWacky:Array<String> = [];
    private var transitioning:Bool = false;
    private var danceLeft:Bool = false;

    override public function create():Void {
        super.create();

        if (Controls.instance == null) {
            Controls.instance = new Controls();
        }

        #if desktop
        try {
            DiscordRPC.changePresence("Title Screen", "In the Menus");
        } catch (e:Dynamic) {}
        #end

        curWacky = getIntroText();

        if (!initialized) {
            Conductor.changeBPM(102.0);
            var menuMusic = Paths.music("freakyMenu");
            if (menuMusic != null) {
                FlxG.sound.playMusic(menuMusic, 0.7);
            }
            initialized = true;
        }

        persistentUpdate = true;

        logoBump = new FlxSprite(-150, -100);
        AssetHelper.loadSparrowSafely(logoBump, "menus/titlescreen/logo");
        if (logoBump.frames != null) {
            logoBump.animation.addByPrefix("bump", "logo bumpin", 24, false);
            logoBump.animation.play("bump");
        }
        logoBump.updateHitbox();
        logoBump.antialiasing = true;

        gfDance = new FlxSprite(FlxG.width * 0.4, 40);
        AssetHelper.loadSparrowSafely(gfDance, "menus/titlescreen/gf");
        if (gfDance.frames != null) {
            gfDance.animation.addByIndices("danceLeft", "gfDance", [30, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], "", 24, false);
            gfDance.animation.addByIndices("danceRight", "gfDance", [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29], "", 24, false);
            gfDance.animation.play("danceLeft");
        }
        gfDance.antialiasing = true;

        titleText = new FlxSprite(100, FlxG.height * 0.8);
        AssetHelper.loadSparrowSafely(titleText, "menus/titlescreen/titleEnter");
        if (titleText.frames != null) {
            titleText.animation.addByPrefix("idle", "Press Enter to Begin", 24);
            titleText.animation.addByPrefix("press", "ENTER PRESSED", 24);
            titleText.animation.play("idle");
        }
        titleText.updateHitbox();
        titleText.antialiasing = true;

        add(gfDance);
        add(logoBump);
        add(titleText);

        textGroup = new FlxGroup();
        add(textGroup);

        blackScreen = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        if (!closedIntro) {
            add(blackScreen);
        } else {
            skipIntro();
        }
    }

    override public function update(elapsed:Float):Void {
        if (FlxG.sound.music != null) {
            Conductor.songPosition = FlxG.sound.music.time;
        }

        var pressedEnter:Bool = (Controls.instance != null) ? Controls.instance.ACCEPT : FlxG.keys.justPressed.ENTER;

        if (pressedEnter && !closedIntro) {
            skipIntro();
        } else if (pressedEnter && closedIntro && !transitioning) {
            transitioning = true;
            if (titleText != null && titleText.animation.exists("press")) {
                titleText.animation.play("press");
            }
            FlxG.camera.flash(FlxColor.WHITE, 1.0);
            AssetHelper.playSoundSafely("confirmMenu", 0.7);

            new FlxTimer().start(1.5, function(_) {
                MusicBeatState.switchState(new MainMenuState());
            });
        }

        super.update(elapsed);
    }

    private function createIntroText(text:String, offset:Float = 0):Void {
        var t = new FlxText(0, (FlxG.height * 0.4) + offset, FlxG.width, text, 32);
        t.setFormat(Paths.font("vcr"), 32, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        t.borderSize = 2.0;
        textGroup.add(t);
    }

    private function deleteIntroText():Void {
        while (textGroup.members.length > 0) {
            var item = textGroup.members[0];
            textGroup.remove(item, true);
            item.destroy();
        }
    }

    override public function beatHit(beat:Int):Void {
        super.beatHit(beat);

        if (logoBump != null && logoBump.animation.exists("bump")) {
            logoBump.animation.play("bump", true);
        }

        if (gfDance != null && gfDance.animation.exists("danceLeft")) {
            danceLeft = !danceLeft;
            gfDance.animation.play(danceLeft ? "danceLeft" : "danceRight", true);
        }

        if (!closedIntro) {
            switch (beat) {
                case 1:
                    createIntroText("SoulScorch Team", -40);
                case 3:
                    createIntroText("Presents", 20);
                case 4:
                    deleteIntroText();
                case 5:
                    createIntroText("In collaboration with", -40);
                case 7:
                    createIntroText("Open Source Community", 20);
                case 8:
                    deleteIntroText();
                case 9:
                    createIntroText(curWacky[0], -40);
                case 11:
                    createIntroText(curWacky[1], 20);
                case 12:
                    deleteIntroText();
                case 13:
                    createIntroText("SoulScorch Engine", -40);
                case 14:
                    createIntroText(Version.CODENAME, 20);
                case 15:
                    createIntroText("v" + Version.MAJOR + "." + Version.MINOR + "." + Version.PATCH, 70);
                case 16:
                    skipIntro();
            }
        }
    }

    private function skipIntro():Void {
        if (!closedIntro) {
            remove(blackScreen);
            deleteIntroText();
            FlxG.camera.flash(FlxColor.WHITE, 1.5);
            closedIntro = true;
        }
    }

    private function getIntroText():Array<String> {
        var lines:Array<Array<String>> = [
            ["Uncapped power", "Ignited rhythms"],
            ["Modding redefined", "Run anything"],
            ["Built with Haxe", "Flixel powered"],
            ["Scorching charts", "Zero input lag"]
        ];
        return lines[FlxG.random.int(0, lines.length - 1)];
    }
}