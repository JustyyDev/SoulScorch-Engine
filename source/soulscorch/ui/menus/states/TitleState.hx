package soulscorch.ui.menus.states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.input.Controls;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.ui.hud.Alphabet;
import soulscorch.ui.menus.states.MainMenuState;

using StringTools;

class TitleState extends MusicBeatState {
    public static var initialized:Bool = false;

    private var gfDance:FlxSprite;
    private var danceLeft:Bool = false;
    private var titleText:FlxSprite;
    private var logoBl:FlxSprite;
    private var ngLogo:FlxSprite;

    private var textGroup:FlxTypedGroup<Alphabet>;
    private var curWacky:Array<String> = [];
    private var skippedIntro:Bool = false;
    private var transitioning:Bool = false;

    override public function create():Void {
        super.create();

        #if desktop
        DiscordRPC.changePresence("Title Screen", "Igniting Engine");
        #end

        curWacky = FlxG.random.getObject(getIntroText());
        Conductor.changeBPM(102.0);

        if (FlxG.sound.music == null || !FlxG.sound.music.playing) {
            FlxG.sound.playMusic(Paths.music("freakyMenu"), 0.7);
        }

        // 1. Girlfriend Dance Sprite
        gfDance = new FlxSprite(FlxG.width * 0.4, FlxG.height * 0.07);
        var gfLoaded = AssetHelper.loadSparrowSafely(gfDance, "ui/titlescreen/gf");
        if (!gfLoaded) gfLoaded = AssetHelper.loadSparrowSafely(gfDance, "ui/menus/title/gfDanceTitle");
        if (!gfLoaded) gfLoaded = AssetHelper.loadSparrowSafely(gfDance, "gfDanceTitle");

        if (gfLoaded && gfDance.frames != null) {
            var hasIndices = false;
            for (prefix in ["GF Dancing Beat", "gfDance", "dance", "GF"]) {
                if (tryAddDanceIndices(gfDance, prefix)) {
                    hasIndices = true;
                    break;
                }
            }
            if (!hasIndices) {
                gfDance.animation.addByPrefix("danceLeft", "danceLeft", 24, false);
                gfDance.animation.addByPrefix("danceRight", "danceRight", 24, false);
            }
        } else {
            gfDance.makeGraphic(250, 400, 0xFFFF0055);
        }
        gfDance.antialiasing = true;
        gfDance.visible = false;
        add(gfDance);

        // 2. Main Logo Sprite
        logoBl = new FlxSprite(-150, -100);
        var logoLoaded = AssetHelper.loadSparrowSafely(logoBl, "ui/titlescreen/logo");
        if (!logoLoaded) logoLoaded = AssetHelper.loadSparrowSafely(logoBl, "ui/menus/title/logoBumpin");
        if (!logoLoaded) logoLoaded = AssetHelper.loadSparrowSafely(logoBl, "logoBumpin");
        if (!logoLoaded) logoLoaded = AssetHelper.loadGraphicSafely(logoBl, "ui/titlescreen/logo");

        if (logoLoaded && logoBl.frames != null && logoBl.frames.frames.length > 1) {
            logoBl.animation.addByPrefix("bump", "logo bumpin", 24, false);
            if (logoBl.animation.getByName("bump") == null) logoBl.animation.addByPrefix("bump", "bump", 24, false);
            if (logoBl.animation.getByName("bump") == null) logoBl.animation.addByPrefix("bump", "logo", 24, false);
            logoBl.animation.play("bump");
        }
        logoBl.antialiasing = true;
        logoBl.visible = false;
        add(logoBl);

        // 3. Newgrounds Logo Sprite
        ngLogo = new FlxSprite(0, FlxG.height * 0.52);
        if (!AssetHelper.loadGraphicSafely(ngLogo, "ui/titlescreen/newgrounds_logo")) {
            AssetHelper.loadGraphicSafely(ngLogo, "newgrounds_logo");
        }
        ngLogo.scale.set(0.8, 0.8);
        ngLogo.updateHitbox();
        ngLogo.screenCenter(X);
        ngLogo.visible = false;
        add(ngLogo);

        // 4. Press Enter Prompt Sprite
        titleText = new FlxSprite(100, FlxG.height * 0.8);
        var enterLoaded = AssetHelper.loadSparrowSafely(titleText, "ui/titlescreen/titleEnter");
        if (!enterLoaded) enterLoaded = AssetHelper.loadSparrowSafely(titleText, "ui/menus/title/titleEnter");
        if (!enterLoaded) enterLoaded = AssetHelper.loadSparrowSafely(titleText, "titleEnter");

        if (enterLoaded && titleText.frames != null) {
            titleText.animation.addByPrefix("idle", "Press Enter to Begin", 24);
            titleText.animation.addByPrefix("press", "ENTER PRESSED", 24);
            titleText.animation.play("idle");
        }
        titleText.antialiasing = true;
        titleText.visible = false;
        add(titleText);

        // 5. Alphabet Intro Text Group
        textGroup = new FlxTypedGroup<Alphabet>();
        add(textGroup);

        if (initialized) {
            skipIntro();
        } else {
            initialized = true;
        }
    }

    private function getIntroText():Array<Array<String>> {
        var fullText:String = "";
        var textPath = AssetResolver.resolveFile("data/introText", [".txt", ""]);
        if (textPath != null) {
            fullText = AssetResolver.getText(textPath);
        }

        if (fullText == null || fullText.trim().length == 0) {
            return [
                ["SoulScorch Team", "by Justy"],
                ["High Performance", "Rhythm Engine"],
                ["Not just another fork", "A total powerhouse"],
                ["Shoutouts to", "Newgrounds community"]
            ];
        }

        var lines = fullText.trim().split("\n");
        var result:Array<Array<String>> = [];

        for (line in lines) {
            var clean = line.trim();
            if (clean.length > 0 && clean.contains("--")) {
                var parts = clean.split("--");
                result.push([parts[0].trim(), parts[1].trim()]);
            }
        }

        return result.length > 0 ? result : [["SoulScorch Team", "by Justy"]];
    }

    private function createCoolText(textArray:Array<String>, ?offsetY:Float = 0):Void {
        for (i in 0...textArray.length) {
            var money:Alphabet = new Alphabet(0, 0, textArray[i], true);
            money.screenCenter(X);
            money.y += (i * 60) + 200 + offsetY;
            textGroup.add(money);
        }
    }

    private function addMoreText(text:String, ?offsetY:Float = 0):Void {
        var coolText:Alphabet = new Alphabet(0, 0, text, true);
        coolText.screenCenter(X);
        coolText.y += (textGroup.length * 60) + 200 + offsetY;
        textGroup.add(coolText);
    }

    private function deleteCoolText():Void {
        while (textGroup.members.length > 0) {
            var item = textGroup.members[0];
            textGroup.remove(item, true);
            item.destroy();
        }
    }

    private function skipIntro():Void {
        if (!skippedIntro) {
            remove(ngLogo);
            deleteCoolText();

            FlxG.camera.flash(FlxColor.WHITE, 2.0);

            gfDance.visible = true;
            logoBl.visible = true;
            titleText.visible = true;

            skippedIntro = true;
        }
    }

    private function tryAddDanceIndices(spr:FlxSprite, prefix:String):Bool {
        if (spr.frames == null || spr.frames.frames == null) return false;
        var pLower = prefix.toLowerCase();
        var matches = false;

        for (f in spr.frames.frames) {
            if (f.name != null && f.name.toLowerCase().startsWith(pLower)) {
                matches = true;
                break;
            }
        }

        if (matches) {
            spr.animation.addByIndices('danceLeft', prefix, [30, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], "", 24, false);
            spr.animation.addByIndices('danceRight', prefix, [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29], "", 24, false);
            return true;
        }
        return false;
    }

    override public function update(elapsed:Float):Void {
        if (FlxG.sound.music != null) Conductor.songPosition = FlxG.sound.music.time;

        if (Controls.instance.ACCEPT) {
            if (!skippedIntro) {
                skipIntro();
            } else if (!transitioning) {
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
        }

        super.update(elapsed);
    }

    override public function beatHit(beat:Int):Void {
        super.beatHit(beat);

        if (logoBl != null && logoBl.animation != null && logoBl.animation.exists("bump")) {
            logoBl.animation.play("bump", true);
        }

        if (gfDance != null && gfDance.animation != null) {
            danceLeft = !danceLeft;
            if (danceLeft && gfDance.animation.exists("danceLeft")) {
                gfDance.animation.play("danceLeft", true);
            } else if (!danceLeft && gfDance.animation.exists("danceRight")) {
                gfDance.animation.play("danceRight", true);
            }
        }

        if (!skippedIntro) {
            switch (beat) {
                case 1:
                    createCoolText(['SoulScorch Team', 'ninjamuffin99', 'phantomArcade']);
                case 3:
                    addMoreText('present');
                case 4:
                    deleteCoolText();
                case 5:
                    createCoolText(['In association', 'with']);
                case 7:
                    addMoreText('newgrounds');
                    if (ngLogo != null) ngLogo.visible = true;
                case 8:
                    deleteCoolText();
                    if (ngLogo != null) ngLogo.visible = false;
                case 9:
                    createCoolText([curWacky[0]]);
                case 11:
                    addMoreText(curWacky[1]);
                case 12:
                    deleteCoolText();
                case 13:
                    addMoreText('SoulScorch');
                case 14:
                    addMoreText('Engine');
                case 15:
                    addMoreText('Alpha Build');
                case 16:
                    skipIntro();
            }
        }
    }
}