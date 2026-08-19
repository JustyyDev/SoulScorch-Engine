package soulscorch.ui.menus.states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.input.Controls;
import soulscorch.backend.system.engine.Engine;
import soulscorch.backend.system.engine.GameConfig;
import soulscorch.backend.system.engine.Version;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.scripting.mod.ModManager;
import soulscorch.ui.hud.Alphabet;
import soulscorch.ui.menus.states.MainMenuState;

using StringTools;

class TitleState extends MusicBeatState {
    public static var initialized:Bool = false;
    public static var closedIntro:Bool = false;

    private var blackScreen:FlxSprite;
    private var textGroup:FlxTypedGroup<Alphabet>;
    private var ngSpr:FlxSprite;
    private var logoBump:FlxSprite;
    private var gfDance:FlxSprite;
    private var titleText:FlxSprite;

    private var curWacky:Array<String> = [];
    private var wackyIntroText:Array<Array<String>> = [];
    private var transitioning:Bool = false;
    private var danceLeft:Bool = false;

    override public function create():Void {
        super.create();

        if (!initialized) {
            try {
                ModManager.reloadMods();
                var config = new GameConfig();
                var engine = Engine.boot(config);
                engine.init();
            } catch (e:Dynamic) {
                trace('Engine boot notice: $e');
            }

            #if desktop
            try {
                DiscordRPC.changePresence("Title Screen", "In the Menus");
            } catch (e:Dynamic) {}
            #end

            Conductor.changeBPM(102.0);

            try {
                var menuMusic = Paths.music("freakyMenu");
                if (menuMusic != null) {
                    FlxG.sound.playMusic(menuMusic, 0.7);
                }
            } catch (e:Dynamic) {
                trace('Could not load menu music: $e');
            }

            initialized = true;
        }

        wackyIntroText = getIntroText();
        curWacky = (wackyIntroText.length > 0) ? wackyIntroText[FlxG.random.int(0, wackyIntroText.length - 1)] : ["SoulScorch", "Engine"];
        persistentUpdate = true;

        logoBump = new FlxSprite(-150, -100);
        var loadedLogo = AssetHelper.loadSparrowSafely(logoBump, "ui/titlescreen/logo");
        if (!loadedLogo) loadedLogo = AssetHelper.loadSparrowSafely(logoBump, "logoBumpin");

        if (loadedLogo && logoBump.frames != null) {
            logoBump.animation.addByPrefix("bump", "logo bumpin", 24, false);
            logoBump.animation.play("bump");
        }
        logoBump.updateHitbox();
        logoBump.antialiasing = true;
        add(logoBump);

        gfDance = new FlxSprite(FlxG.width * 0.4, 40);
        var loadedGf = AssetHelper.loadSparrowSafely(gfDance, "ui/titlescreen/gf");
        if (!loadedGf) loadedGf = AssetHelper.loadSparrowSafely(gfDance, "gfDanceTitle");

        if (loadedGf && gfDance.frames != null) {
            gfDance.animation.addByIndices("danceLeft", "gfDance", [30, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], "", 24, false);
            gfDance.animation.addByIndices("danceRight", "gfDance", [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29], "", 24, false);
            gfDance.animation.play("danceLeft");
        }
        gfDance.antialiasing = true;
        add(gfDance);

        titleText = new FlxSprite(100, FlxG.height * 0.8);
        var loadedTitle = AssetHelper.loadSparrowSafely(titleText, "ui/titlescreen/titleEnter");
        if (!loadedTitle) loadedTitle = AssetHelper.loadSparrowSafely(titleText, "titleEnter");

        if (loadedTitle && titleText.frames != null) {
            titleText.animation.addByPrefix("idle", "Press Enter to Begin", 24);
            titleText.animation.addByPrefix("press", "ENTER PRESSED", 24);
            titleText.animation.play("idle");
        }
        titleText.updateHitbox();
        titleText.antialiasing = true;
        add(titleText);

        textGroup = new FlxTypedGroup<Alphabet>();
        add(textGroup);

        blackScreen = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);

        ngSpr = new FlxSprite(0, FlxG.height * 0.52);
        var loadedNG = AssetHelper.loadImageSafely(ngSpr, "ui/titlescreen/newgrounds_logo");
        if (!loadedNG) loadedNG = AssetHelper.loadImageSafely(ngSpr, "newgrounds_logo");

        if (!loadedNG) {
            ngSpr.makeGraphic(1, 1, FlxColor.TRANSPARENT);
        }
        ngSpr.setGraphicSize(Std.int(ngSpr.width * 0.8));
        ngSpr.updateHitbox();
        ngSpr.screenCenter(X);
        ngSpr.antialiasing = true;
        ngSpr.visible = false;

        if (!closedIntro) {
            add(blackScreen);
            add(ngSpr);
        } else {
            skipIntro();
        }
    }

    override public function update(elapsed:Float):Void {
        if (FlxG.sound.music != null) {
            Conductor.songPosition = FlxG.sound.music.time;
        }

        var pressedEnter:Bool = FlxG.keys.justPressed.ENTER;
        if (Controls.instance != null && Controls.instance.ACCEPT) {
            pressedEnter = true;
        }

        #if mobile
        for (touch in FlxG.touches.list) {
            if (touch.justPressed) {
                pressedEnter = true;
            }
        }
        #end

        if (pressedEnter && !closedIntro) {
            skipIntro();
        } else if (pressedEnter && closedIntro && !transitioning) {
            transitioning = true;
            if (titleText != null && titleText.animation != null && titleText.animation.exists("press")) {
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
        var t = new Alphabet(0, (FlxG.height * 0.4) + offset, text, true);
        t.alignment = CENTER;
        t.screenCenter(X);
        t.color = FlxColor.WHITE;
        textGroup.add(t);
    }

    private function addMoreIntroText(text:String, offset:Float = 0):Void {
        var t = new Alphabet(0, (FlxG.height * 0.4) + (textGroup.length * 60) + offset, text, true);
        t.alignment = CENTER;
        t.screenCenter(X);
        t.color = FlxColor.WHITE;
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

        if (logoBump != null && logoBump.animation != null && logoBump.animation.exists("bump")) {
            logoBump.animation.play("bump", true);
        }

        if (gfDance != null && gfDance.animation != null && gfDance.animation.exists("danceLeft")) {
            danceLeft = !danceLeft;
            gfDance.animation.play(danceLeft ? "danceLeft" : "danceRight", true);
        }

        if (!closedIntro) {
            switch (beat) {
                case 1:
                    createIntroText("SoulScorch Team", -40);
                case 3:
                    addMoreIntroText("Presents", -40);
                case 4:
                    deleteIntroText();
                case 5:
                    createIntroText("In collaboration with", -40);
                case 7:
                    addMoreIntroText("Newgrounds", -40);
                    if (ngSpr != null && ngSpr.graphic != null) ngSpr.visible = true;
                case 8:
                    deleteIntroText();
                    if (ngSpr != null) ngSpr.visible = false;
                case 9:
                    createIntroText(curWacky[0], -40);
                case 11:
                    addMoreIntroText(curWacky[1], -40);
                case 12:
                    deleteIntroText();
                case 13:
                    createIntroText("SoulScorch Engine", -60);
                case 14:
                    addMoreIntroText(Version.CODENAME, -60);
                case 15:
                    addMoreIntroText("v" + Version.MAJOR + "." + Version.MINOR + "." + Version.PATCH, -60);
                case 16:
                    skipIntro();
            }
        }
    }

    private function skipIntro():Void {
        if (!closedIntro) {
            if (ngSpr != null) remove(ngSpr);
            if (blackScreen != null) remove(blackScreen);
            deleteIntroText();
            FlxG.camera.flash(FlxColor.WHITE, 1.5);
            closedIntro = true;
        }
    }

    private function getIntroText():Array<Array<String>> {
        var fullText:String = AssetResolver.getText("data/config/introText");
        if (fullText.length == 0) {
            fullText = AssetResolver.getText("assets/preload/data/config/introText.txt");
        }
        if (fullText.length == 0) {
            fullText = AssetResolver.getText("assets/data/introText.txt");
        }

        var lines:Array<Array<String>> = [];

        if (fullText != null && fullText.trim().length > 0) {
            var splitted = fullText.split("\n");
            for (line in splitted) {
                var trimmed = line.trim();
                if (trimmed.length > 0 && trimmed.indexOf("--") != -1) {
                    var parts = trimmed.split("--");
                    if (parts.length >= 2) {
                        lines.push([parts[0].trim(), parts[1].trim()]);
                    }
                }
            }
        }

        if (lines.length == 0) {
            lines = [
                ["Uncapped power", "Ignited rhythms"],
                ["Modding redefined", "Run anything"],
                ["Built with Haxe", "Flixel powered"],
                ["Scorching charts", "Zero input lag"],
                ["Friday Night Funkin", "SoulScorch Engine"]
            ];
        }

        return lines;
    }
}