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
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.ui.hud.Alphabet;

using StringTools;

class TitleState extends MusicBeatState {
    public static var initialized:Bool = false;

    private var gfDance:FlxSprite;
    private var danceLeft:Bool = false;
    private var titleText:FlxSprite;
    private var logoBl:FlxSprite;

    private var skippedIntro:Bool = false;
    private var transitioning:Bool = false;

    override public function create():Void {
        super.create();

        #if desktop
        DiscordRPC.changePresence("Title Screen", "Starting Up");
        #end

        Conductor.changeBPM(102.0);

        if (FlxG.sound.music == null || !FlxG.sound.music.playing) {
            FlxG.sound.playMusic(Paths.music("freakyMenu"), 0.7);
        }

        gfDance = new FlxSprite(FlxG.width * 0.4, FlxG.height * 0.07);
        var gfLoaded = AssetHelper.loadSparrowSafely(gfDance, "ui/menus/title/gfDanceTitle");
        if (!gfLoaded) gfLoaded = AssetHelper.loadSparrowSafely(gfDance, "ui/title/gfDanceTitle");
        if (!gfLoaded) gfLoaded = AssetHelper.loadSparrowSafely(gfDance, "gfDanceTitle");

        if (gfLoaded && gfDance.frames != null) {
            // Proper 30-frame index split prevents restarting frames on each beat
            gfDance.animation.addByIndices('danceLeft', 'gfDance', [30, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], "", 24, false);
            gfDance.animation.addByIndices('danceRight', 'gfDance', [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29], "", 24, false);
        } else {
            gfDance.makeGraphic(250, 400, 0xFFFF0055);
        }
        gfDance.antialiasing = true;
        add(gfDance);

        logoBl = new FlxSprite(-150, -100);
        var logoLoaded = AssetHelper.loadSparrowSafely(logoBl, "ui/menus/title/logoBumpin");
        if (!logoLoaded) logoLoaded = AssetHelper.loadSparrowSafely(logoBl, "logoBumpin");
        if (logoLoaded) {
            logoBl.animation.addByPrefix("bump", "logo bumpin", 24, false);
            logoBl.animation.play("bump");
        }
        logoBl.antialiasing = true;
        add(logoBl);

        titleText = new FlxSprite(100, FlxG.height * 0.8);
        var enterLoaded = AssetHelper.loadSparrowSafely(titleText, "ui/menus/title/titleEnter");
        if (!enterLoaded) enterLoaded = AssetHelper.loadSparrowSafely(titleText, "titleEnter");
        if (enterLoaded) {
            titleText.animation.addByPrefix("idle", "Press Enter to Begin", 24);
            titleText.animation.addByPrefix("press", "ENTER PRESSED", 24);
            titleText.animation.play("idle");
        }
        titleText.antialiasing = true;
        add(titleText);
    }

    override public function update(elapsed:Float):Void {
        if (FlxG.sound.music != null) Conductor.songPosition = FlxG.sound.music.time;

        if (Controls.instance.ACCEPT && !transitioning) {
            transitioning = true;
            AssetHelper.playSoundSafely("confirmMenu", 0.7);

            if (titleText != null && titleText.animation.exists("press")) {
                titleText.animation.play("press");
            }

            FlxG.camera.flash(FlxColor.WHITE, 1.0);

            new FlxTimer().start(1.2, function(_) {
                MusicBeatState.switchState(new MainMenuState());
            });
        }

        super.update(elapsed);
    }

    override public function beatHit(beat:Int):Void {
        super.beatHit(beat);

        if (logoBl != null && logoBl.animation.exists("bump")) {
            logoBl.animation.play("bump", true);
        }

        if (gfDance != null && gfDance.animation != null) {
            danceLeft = !danceLeft;
            if (danceLeft) {
                if (gfDance.animation.exists("danceLeft")) gfDance.animation.play("danceLeft", true);
            } else {
                if (gfDance.animation.exists("danceRight")) gfDance.animation.play("danceRight", true);
            }
        }
    }
}