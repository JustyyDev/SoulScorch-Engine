package soulscorch.ui.menus.states;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.effects.FlxFlicker;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.input.Controls;
import soulscorch.backend.input.MobilePad;
import soulscorch.backend.localization.LanguageManager;
import soulscorch.backend.system.engine.Version;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.scripting.ScriptManager;
import soulscorch.scripting.mod.SoulGlobalScript;
import soulscorch.ui.hud.Alphabet;
import soulscorch.ui.menus.credits.CreditsState;
import soulscorch.ui.menus.option.OptionsMenuState;
import soulscorch.ui.menus.states.FreeplayState;
import soulscorch.ui.menus.states.HomeSoulState;
import soulscorch.ui.menus.states.StoryMenuState;
import soulscorch.ui.menus.states.TitleState;
import soulscorch.ui.menus.substate.ModSwitchMenu;

using StringTools;

class MainMenuState extends MusicBeatState {
    public static var curSelected:Int = 0;

    private var menuItems:Array<String> = [];
    private var grpMenuItems:FlxTypedGroup<FlxSprite>;
    private var bg:FlxSprite;
    private var magenta:FlxSprite;
    private var camFollow:FlxObject;
    private var camFollowPos:FlxObject;
    private var versionText:FlxText;
    private var mobileControls:MobilePad;
    private var scripts:ScriptManager;

    private var selectedSomethin:Bool = false;

    override public function create():Void {
        super.create();

        #if desktop
        DiscordRPC.changePresence("Main Menu", "In the Menus");
        #end
        persistentUpdate = persistentDraw = true;

        if (FlxG.sound.music == null || !FlxG.sound.music.playing) {
            FlxG.sound.playMusic(Paths.music("freakyMenu"), 0.7);
        }

        scripts = new ScriptManager();
        initMenuScripts();

        loadMenuItems();

        bg = new FlxSprite(-80);
        if (!AssetHelper.loadGraphicSafely(bg, "ui/menubgs/menuBG")) {
            if (!AssetHelper.loadGraphicSafely(bg, "menuBG")) {
                bg.makeGraphic(Std.int(FlxG.width), Std.int(FlxG.height), 0xFF282828);
            }
        }
        bg.scrollFactor.set(0, 0.15);
        bg.setGraphicSize(Std.int(bg.width * 1.175));
        bg.updateHitbox();
        bg.screenCenter();
        bg.antialiasing = true;
        add(bg);

        magenta = new FlxSprite(-80);
        if (!AssetHelper.loadGraphicSafely(magenta, "ui/menubgs/menuBGMagenta")) {
            if (!AssetHelper.loadGraphicSafely(magenta, "ui/menubgs/menuDesat")) {
                if (!AssetHelper.loadGraphicSafely(magenta, "menuDesat")) {
                    magenta.makeGraphic(Std.int(FlxG.width), Std.int(FlxG.height), 0xFFFD719B);
                }
            }
        }
        magenta.scrollFactor.set(0, 0.15);
        magenta.setGraphicSize(Std.int(magenta.width * 1.175));
        magenta.updateHitbox();
        magenta.screenCenter();
        magenta.visible = false;
        magenta.color = 0xFFFD719B;
        magenta.antialiasing = true;
        add(magenta);

        camFollow = new FlxObject(0, 0, 1, 1);
        camFollowPos = new FlxObject(0, 0, 1, 1);
        add(camFollow);
        add(camFollowPos);

        grpMenuItems = new FlxTypedGroup<FlxSprite>();
        add(grpMenuItems);

        for (i in 0...menuItems.length) {
            var rawKey = menuItems[i].trim().toLowerCase();
            var keyNormalized = rawKey.replace("_", " ");
            var keyUnderscore = rawKey.replace(" ", "_");

            var offset:Float = 108 - (Math.max(menuItems.length, 4) - 4) * 80;
            var menuItem:FlxSprite = new FlxSprite(0, (i * 140) + offset);

            var loaded = AssetHelper.loadSparrowSafely(menuItem, "ui/mainmenu/menu_" + rawKey);
            if (!loaded) loaded = AssetHelper.loadSparrowSafely(menuItem, "ui/mainmenu/menu_" + keyNormalized);
            if (!loaded) loaded = AssetHelper.loadSparrowSafely(menuItem, "ui/mainmenu/menu_" + keyUnderscore);
            if (!loaded) loaded = AssetHelper.loadSparrowSafely(menuItem, "menus/mainmenu/menu_" + rawKey);

            if (loaded && menuItem.frames != null) {
                menuItem.animation.addByPrefix("idle", keyNormalized + " basic", 24);
                if (menuItem.animation.getByName("idle") == null) menuItem.animation.addByPrefix("idle", keyUnderscore + " basic", 24);
                if (menuItem.animation.getByName("idle") == null) menuItem.animation.addByPrefix("idle", rawKey + " basic", 24);
                if (menuItem.animation.getByName("idle") == null) menuItem.animation.addByPrefix("idle", "basic", 24);

                menuItem.animation.addByPrefix("selected", keyNormalized + " white", 24);
                if (menuItem.animation.getByName("selected") == null) menuItem.animation.addByPrefix("selected", keyUnderscore + " white", 24);
                if (menuItem.animation.getByName("selected") == null) menuItem.animation.addByPrefix("selected", rawKey + " white", 24);
                if (menuItem.animation.getByName("selected") == null) menuItem.animation.addByPrefix("selected", "white", 24);

                menuItem.animation.play("idle");
                menuItem.ID = i;
                menuItem.screenCenter(X);
                menuItem.antialiasing = true;
                grpMenuItems.add(menuItem);
            } else {
                var alphaLabel = new Alphabet(0, (i * 140) + offset, keyNormalized.toUpperCase(), false);
                alphaLabel.screenCenter(X);
                alphaLabel.ID = i;
                grpMenuItems.add(cast alphaLabel);
            }
        }

        FlxG.camera.follow(camFollowPos, null, 1.0);

        var modsHint = LanguageManager.getString("mainMenu.modsHint", "[TAB] Mods & HomeSoulDB");
        versionText = new FlxText(12, FlxG.height - 24, 0, 'SoulScorch Engine ${Version.fullVersion()} | $modsHint', 12);
        versionText.setFormat(Paths.font("vcr"), 12, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
        versionText.scrollFactor.set();
        add(versionText);

        #if (mobile || debug)
        mobileControls = new MobilePad(FULL, A_B);
        add(mobileControls);
        Controls.instance.bindMobilePad(mobileControls);
        #end

        changeItem();
        if (scripts != null) scripts.callAll("onPostCreate");
    }

    private function initMenuScripts():Void {
        var paths = [
            "data/scripts/menus/main",
            "scripts/menus/main",
            "data/scripts/mainMenu"
        ];
        for (p in paths) {
            var file = AssetResolver.resolveFile(p, [".soul", ".hx", ".lua", ".py", ".js"]);
            if (file != null) scripts.loadScript(file);
        }
        scripts.setAll("state", this);
        scripts.callAll("onCreate");
    }

    private function loadMenuItems():Void {
        var rawText:String = AssetResolver.getText("data/config/menuItems");
        if (rawText.length == 0) {
            rawText = AssetResolver.getText("assets/preload/data/config/menuItems.txt");
        }

        menuItems = [];
        if (rawText.trim().length > 0) {
            for (line in rawText.split("\n")) {
                var clean = line.trim();
                if (clean.length > 0 && !clean.startsWith("//") && !clean.startsWith("#")) {
                    menuItems.push(clean);
                }
            }
        }

        if (menuItems.length == 0) {
            menuItems = ["story_mode", "freeplay", "options", "credits"];
        }
    }

    override public function update(elapsed:Float):Void {
        var lerpFactor = FlxMath.bound(elapsed * 9.0, 0, 1);
        camFollowPos.x = FlxMath.lerp(camFollowPos.x, camFollow.x, lerpFactor);
        camFollowPos.y = FlxMath.lerp(camFollowPos.y, camFollow.y, lerpFactor);

        if (scripts != null) scripts.callAll("onUpdate", [elapsed]);

        if (!selectedSomethin) {
            if (Controls.instance.UI_UP_P) {
                AssetHelper.playSoundSafely("scrollMenu", 0.7);
                changeItem(-1);
            }
            if (Controls.instance.UI_DOWN_P) {
                AssetHelper.playSoundSafely("scrollMenu", 0.7);
                changeItem(1);
            }
            if (Controls.instance.BACK) {
                AssetHelper.playSoundSafely("cancelMenu", 0.7);
                MusicBeatState.switchState(new TitleState());
            }

            if (FlxG.keys.justPressed.TAB) {
                AssetHelper.playSoundSafely("confirmMenu", 0.7);
                openSubState(new ModSwitchMenu());
            }

            if (Controls.instance.ACCEPT) {
                selectedSomethin = true;
                AssetHelper.playSoundSafely("confirmMenu", 0.7);

                if (magenta != null) {
                    FlxFlicker.flicker(magenta, 1.1, 0.15, false);
                }

                if (scripts != null) scripts.callAll("onSelectOption", [menuItems[curSelected]]);

                grpMenuItems.forEach(function(spr:FlxSprite) {
                    if (curSelected != spr.ID) {
                        FlxTween.tween(spr, {alpha: 0}, 0.4, {
                            ease: FlxEase.quadOut,
                            onComplete: function(_) spr.kill()
                        });
                    } else {
                        FlxFlicker.flicker(spr, 1.0, 0.06, false, false, function(_) {
                            goToState(menuItems[curSelected]);
                        });
                    }
                });
            }
        }

        super.update(elapsed);

        grpMenuItems.forEach(function(spr:FlxSprite) {
            spr.screenCenter(X);
        });
    }

    private function changeItem(huh:Int = 0):Void {
        if (menuItems.length == 0) return;
        curSelected = FlxMath.wrap(curSelected + huh, 0, menuItems.length - 1);

        grpMenuItems.forEach(function(spr:FlxSprite) {
            if (Std.isOfType(spr, Alphabet)) {
                var alphaItem:Alphabet = cast spr;
                alphaItem.alpha = (alphaItem.ID == curSelected ? 1.0 : 0.6);
                if (alphaItem.ID == curSelected) {
                    camFollow.setPosition(alphaItem.getGraphicMidpoint().x, alphaItem.getGraphicMidpoint().y);
                }
            } else {
                if (Reflect.hasField(spr, "animation") && spr.animation != null && spr.animation.getByName("idle") != null) {
                    spr.animation.play("idle");
                    spr.updateHitbox();
                }

                spr.alpha = (spr.ID == curSelected ? 1.0 : 0.6);

                if (spr.ID == curSelected) {
                    if (Reflect.hasField(spr, "animation") && spr.animation != null && spr.animation.getByName("selected") != null) {
                        spr.animation.play("selected");
                        spr.centerOffsets();
                    }
                    camFollow.setPosition(spr.getGraphicMidpoint().x, spr.getGraphicMidpoint().y);
                }
            }
        });

        if (scripts != null) scripts.callAll("onChangeItem", [curSelected]);
    }

    private function goToState(choice:String):Void {
        var clean = choice != null ? choice.trim().toLowerCase() : "";
        var redirect = SoulGlobalScript.getRedirect(clean);
        if (redirect != null && redirect != clean) {
            MusicBeatState.switchState(new soulscorch.scripting.ScriptedState(redirect));
            return;
        }

        switch (clean) {
            case "story_mode" | "story" | "storymode":
                MusicBeatState.switchState(new StoryMenuState());
            case "freeplay":
                MusicBeatState.switchState(new FreeplayState());
            case "options" | "settings":
                MusicBeatState.switchState(new OptionsMenuState());
            case "credits":
                MusicBeatState.switchState(new CreditsState());
            case "workshop" | "homesouldb":
                MusicBeatState.switchState(new HomeSoulState());
            default:
                MusicBeatState.switchState(new FreeplayState());
        }
    }

    override public function destroy():Void {
        Controls.instance.unbindMobilePad();
        if (scripts != null) {
            scripts.callAll("onDestroy");
            scripts.clear();
        }
        super.destroy();
    }
}