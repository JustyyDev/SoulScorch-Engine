package soulscorch.ui.menus.credits;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import soulscorch.scripting.ScriptAPI;
import haxe.Json;
import haxe.xml.Access;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.input.Controls;
import soulscorch.backend.input.MobilePad;
import soulscorch.backend.localization.LanguageManager;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.backend.utils.ColorUtil;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.ScriptManager;
import soulscorch.scripting.mod.ModManager;
import soulscorch.ui.hud.Alphabet;
import soulscorch.ui.menus.editors.editorui.EditorTheme;
import soulscorch.ui.menus.states.MainMenuState;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

typedef CreditEntry = {
    var name:String;
    var role:String;
    var description:String;
    var icon:String;
    var ?color:String;
    var ?url:String;
    var ?effect:String;
    var ?shader:String;
}

class CreditsState extends MusicBeatState {
    public static var curSelected:Int = 0;

    private var credits:Array<CreditEntry> = [];
    private var grpCredits:FlxTypedGroup<Alphabet>;
    private var grpIcons:FlxTypedGroup<FlxSprite>;
    private var bg:FlxSprite;
    private var descBox:FlxSprite;
    private var descText:FlxText;
    private var roleText:FlxText;
    private var scripts:ScriptManager;
    private var mobileControls:MobilePad;
    private var colorTween:FlxTween;
    private var effectParticles:FlxTypedGroup<FlxSprite>;
    private var effectTimer:Float = 0.0;

    override public function create():Void {
        super.create();

        #if desktop
        DiscordRPC.changePresence("Credits Menu", "Browsing Developers");
        #end

        loadCreditsData();

        scripts = new ScriptManager();
        initCreditsScripts();

        bg = new FlxSprite();
        if (!AssetHelper.loadGraphicSafely(bg, "ui/menubgs/menuDesat")) {
            if (!AssetHelper.loadGraphicSafely(bg, "menuDesat")) {
                bg.makeGraphic(FlxG.width, FlxG.height, 0xFF2A2A38);
            }
        }
        bg.color = 0xFF2A2A38;
        bg.screenCenter();
        bg.antialiasing = true;
        add(bg);

        var topBar = new FlxSprite(0, 0).makeGraphic(FlxG.width, 60, EditorTheme.PANEL_HEADER);
        topBar.scrollFactor.set(0, 0);
        add(topBar);

        var topBorder = new FlxSprite(0, 59).makeGraphic(FlxG.width, 1, EditorTheme.PANEL_BORDER);
        topBorder.scrollFactor.set(0, 0);
        add(topBorder);

        var accentTag = new FlxSprite(25, 16).makeGraphic(4, 28, EditorTheme.ACCENT_CYAN);
        accentTag.scrollFactor.set(0, 0);
        add(accentTag);

        var headerTitle = new FlxText(38, 17, 450, LanguageManager.getString("credits.header", null), 18);
        headerTitle.setFormat(Paths.font("vcr"), 18, EditorTheme.TEXT_PRIMARY, LEFT);
        headerTitle.scrollFactor.set(0, 0);
        add(headerTitle);

        grpIcons = new FlxTypedGroup<FlxSprite>();
        add(grpIcons);

        grpCredits = new FlxTypedGroup<Alphabet>();
        add(grpCredits);

        effectParticles = new FlxTypedGroup<FlxSprite>();
        add(effectParticles);

        for (i in 0...credits.length) {
            var item = new Alphabet(160, (i * 80) + 120, credits[i].name, true);
            item.xMult = 0;
            item.yMult = 0;
            var entryColor = credits[i].color != null && credits[i].color.length > 0
                ? ColorUtil.fromHexSafe(credits[i].color, FlxColor.WHITE)
                : FlxColor.WHITE;
            item.setTextColor(entryColor);
            if (credits[i].effect != null && credits[i].effect.trim().length > 0) item.setEffect(credits[i].effect);
            item.ID = i;
            grpCredits.add(item);

            var iconSpr = new FlxSprite(80, (i * 80) + 115);
            var iconKey = (credits[i].icon != null && credits[i].icon.length > 0) ? credits[i].icon : "default";
            var loaded = AssetHelper.loadGraphicSafely(iconSpr, 'ui/credits/$iconKey');
            if (!loaded) loaded = AssetHelper.loadGraphicSafely(iconSpr, 'credits/$iconKey');
            if (!loaded) loaded = AssetHelper.loadGraphicSafely(iconSpr, 'ui/game/icons/$iconKey/icon');
            if (!loaded) loaded = AssetHelper.loadGraphicSafely(iconSpr, 'ui/game/icons/icon-$iconKey');
            if (!loaded) loaded = AssetHelper.loadGraphicSafely(iconSpr, 'icons/icon-$iconKey');
            if (!loaded) iconSpr.makeGraphic(48, 48, EditorTheme.ACCENT_CYAN);

            // Fit every icon inside the same box without stretching custom portrait art.
            if (iconSpr.graphic != null && iconSpr.graphic.width > 0 && iconSpr.graphic.height > 0) {
                var fitScale = Math.min(48.0 / iconSpr.graphic.width, 48.0 / iconSpr.graphic.height);
                iconSpr.setGraphicSize(
                    Std.int(Math.max(1, iconSpr.graphic.width * fitScale)),
                    Std.int(Math.max(1, iconSpr.graphic.height * fitScale))
                );
            }
            iconSpr.updateHitbox();
            iconSpr.x = 80 + (48 - iconSpr.width) * 0.5;
            iconSpr.y = (i * 80) + 115 + (48 - iconSpr.height) * 0.5;
            iconSpr.antialiasing = true;
            iconSpr.ID = i;
            grpIcons.add(iconSpr);
        }

        descBox = new FlxSprite(0, FlxG.height - 120).makeGraphic(FlxG.width, 120, EditorTheme.PANEL_HEADER);
        descBox.scrollFactor.set(0, 0);
        add(descBox);

        var descBorder = new FlxSprite(0, FlxG.height - 120).makeGraphic(FlxG.width, 1, EditorTheme.PANEL_BORDER);
        descBorder.scrollFactor.set(0, 0);
        add(descBorder);

        roleText = new FlxText(20, FlxG.height - 105, FlxG.width - 40, "", 22);
        roleText.setFormat(Paths.font("vcr"), 22, EditorTheme.ACCENT_YELLOW, CENTER, OUTLINE, FlxColor.BLACK);
        roleText.borderSize = 1.2;
        add(roleText);

        descText = new FlxText(30, FlxG.height - 68, FlxG.width - 60, "", 16);
        descText.setFormat(Paths.font("vcr"), 16, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        descText.borderSize = 1.0;
        add(descText);

        #if (mobile || debug)
        mobileControls = new MobilePad(UP_DOWN, A_B);
        add(mobileControls);
        Controls.instance.bindMobilePad(mobileControls);
        #end

        changeSelection(0);
        if (scripts != null) scripts.callAll("onPostCreate");
    }

    private function initCreditsScripts():Void {
        scripts.setAll("state", this);
        scripts.setAll("credits", credits);
        scripts.setAll("ScriptAPI", ScriptAPI);
        scripts.setAll("createShader", ScriptAPI.createShader);
        scripts.setAll("setSpriteShader", ScriptAPI.setSpriteShader);
        scripts.setAll("setShaderFloat", ScriptAPI.setShaderFloat);
        scripts.setAll("setShaderFloatArray", ScriptAPI.setShaderFloatArray);
        scripts.setAll("addShaderToCam", ScriptAPI.addShaderToCamera);
        scripts.setAll("removeShaderFromCam", ScriptAPI.removeShaderFromCamera);
        scripts.setAll("clearCameraShaders", ScriptAPI.clearCameraShaders);
        scripts.setAll("spawnCreditConfetti", spawnCreditConfetti);

        var paths = [
            "data/scripts/menus/credits",
            "scripts/menus/credits",
            "data/scripts/creditsState"
        ];
        for (p in paths) {
            var file = AssetResolver.resolveFile(p, [".soul", ".hx", ".hscript", ".iris", ".lua", ".py"]);
            if (file != null) scripts.loadScript(file);
        }
    }

    private function loadCreditsData():Void {
        credits = [];

        #if sys
        var searchPaths = [
            "assets/preload/data/config/credits.xmsoul",
            "assets/preload/data/config/credits.xml",
            "data/config/credits.xmsoul",
            "data/config/credits.xml",
            "data/credits.xmsoul",
            "data/credits.xml",
            "data/credits.json",
            "assets/preload/data/credits.json"
        ];

        if (ModManager.activeMods != null) {
            for (m in ModManager.activeMods) {
                searchPaths.unshift('mods/$m/assets/preload/data/config/credits.xmsoul');
                searchPaths.unshift('mods/$m/assets/preload/data/config/credits.xml');
                searchPaths.unshift('mods/$m/data/config/credits.xmsoul');
                searchPaths.unshift('mods/$m/data/config/credits.xml');
                searchPaths.unshift('mods/$m/data/credits.xmsoul');
                searchPaths.unshift('mods/$m/data/credits.xml');
                searchPaths.unshift('mods/$m/data/credits.json');
            }
        }

        for (p in searchPaths) {
            if (FileSystem.exists(p)) {
                try {
                    var content = File.getContent(p);
                    if (p.endsWith(".xmsoul") || p.endsWith(".xml") || content.trim().startsWith("<")) {
                        var xml = Xml.parse(content);
                        var access = new Access(xml.firstElement());
                        for (entry in access.nodes.resolve("credit")) {
                            credits.push({
                                name: entry.has.name ? entry.att.name : "Unknown",
                                role: entry.has.role ? entry.att.role : "Contributor",
                                description: entry.has.description ? entry.att.description : "",
                                icon: entry.has.icon ? entry.att.icon : "default",
                                color: entry.has.color ? entry.att.color : null,
                                url: entry.has.url ? entry.att.url : (entry.has.link ? entry.att.link : null),
                                effect: entry.has.effect ? entry.att.effect : null,
                                shader: entry.has.shader ? entry.att.shader : null
                            });
                        }
                        for (category in access.nodes.resolve("category")) {
                            for (entry in category.nodes.resolve("dev")) {
                                credits.push({
                                    name: entry.has.name ? entry.att.name : "Unknown",
                                    role: entry.has.role ? entry.att.role : (category.has.name ? category.att.name : "Contributor"),
                                    description: entry.has.description ? entry.att.description : "",
                                    icon: entry.has.icon ? entry.att.icon : "default",
                                    color: entry.has.color ? entry.att.color : (category.has.color ? category.att.color : null),
                                    url: entry.has.url ? entry.att.url : (entry.has.link ? entry.att.link : null),
                                    effect: entry.has.effect ? entry.att.effect : null,
                                    shader: entry.has.shader ? entry.att.shader : null
                                });
                            }
                        }
                    } else {
                        var parsed:Array<CreditEntry> = cast Json.parse(content);
                        if (parsed != null && parsed.length > 0) credits = parsed;
                    }
                    if (credits.length > 0) break;
                } catch (e:Dynamic) {
                    Logger.warn('Failed parsing credit file $p: $e', "credits");
                }
            }
        }
        #end

        if (credits.length == 0) {
            credits = [
                {
                    name: "JustyTCCD",
                    role: "Lead Programmer & Director",
                    description: "Creator and architectural designer of SoulScorch Engine, silly goober ok??",
                    icon: "dev_justy",
                    color: "#00FFCC",
                    url: "https://github.com/JustyyDev"
                },
                {
                    name: "Cryoptera",
                    role: "Contributor, Ideas & Lead Programmer",
                    description: "Programming help and some ideas! Mainly for lua support! Thank you Cryo :D",
                    icon: "con_cryo",
                    color: "#654321", // bat color, dark brown!!!!
                    url: "https://github.com/Cryoptera"
                },
                {
                    name: "CookieCreator",
                    role: "Contributor, Main Idea Writer and Artist",
                    description: "Main idea writer and artist for the SoulScorch Engine. We love you Cookie!",
                    icon: "con_cookiecrumbs",
                    color: "#FFB6C1", // light pink, cause we love you cookie <3
                    url: "https://x.com/_CookieCreator_"
                },
                {
                    name: "PatoPatongas",
                    role: "Contributor, Ideas & Programmer",
                    description: "Amazing coder, helped a bunch and had some amazing ideas for this engine aswell!",
                    icon: "con_pato",
                    color: "#00FF00", // green color, green aura /j
                    url: "https://github.com/PatoPatongas"
                },
                {
                    name: "L0F1",
                    role: "Contributor in Ideas",
                    description: "Gave the idea of adding FMOD support to the engine, which can be used now\n(hardcoded in project.xml at source)!",
                    icon: "con_l0f1",
                    color: "#808080",
                    url: "https://x.com/L0F1_musict2"
                },
                {
                    name: "Kilnec",
                    role: "Contributor, Ideas, Artist & Playtester",
                    description: "Kilnec is so talented, they also gave the idea for the freeplay shuffle feature!",
                    icon: "con_kilnec",
                    effect: "confetti",
                    color: "#B1BCA0",
                    url: "https://twitch.tv/kilnec"
                },
                {
                    name: "DripPro",
                    role: "Contributor, Bug Fixes, Ideas & Playtester",
                    description: "DripPro is a talented contributor who helped with bug fixes and provided valuable ideas!",
                    icon: "con_drippro",
                    color: "#FF0000", // red vibrant!! drippro hi
                    url: "https://www.youtube.com/channel/UCAD4SwUyHknYRwV9iOGvEiw"
                },
                {
                    name: "mohammad.whb",
                    role: "Contributor, Ideas & Playtester",
                    description: "mohammad.whb is a talented contributor who provided valuable ideas, like the note colors!",
                    icon: "con_mohammad",
                    color: "#00FFFF", // cyan color yay
                    url: ""
                },
                {
                    name: "Alucardseibie",
                    role: "Contributor, Lua Ideas",
                    description: "Alu provided ideas and feedback on the lua side of the modding system. :D",
                    icon: "con_alucardseibie",
                    color: "#B1BCA0",
                    effect: "confetti",
                    url: ""
                },
                {
                    name: "DaisyBun",
                    role: "Art Contributor & Ideas",
                    description: "DaisyBun is a talented artist who made the Senpai Winning Icon!",
                    icon: "con_daisybun",
                    color: "#FFC4E3",
                    url: "https://x.com/Daisy_Bun07"
                },
                {
                    name: "Codename Engine",
                    role: "Inspiration",
                    description: "For being a big inspiration! Definitely check this engine out too!",
                    icon: "con_codenameengine",
                    color: "#800080", // ily cne <3
                    url: "https://codename-engine.com/"
                },
                {
                    name: "Psych Engine",
                    role: "Inspiration",
                    description: "For being yet another big inspiration! Definitely check this engine out too!",
                    icon: "con_psychengine",
                    color: "#D8BFD8", // lightly purple, cause we love you psych engine <3
                    url: "https://github.com/ShadowMario/psych-engine"
                },
                {
                    name: "HaxeFlixel Team",
                    role: "Engine Framework",
                    description: "The underlying 2D game engine power.",
                    icon: "flixel",
                    color: "#00BFFF",
                    url: "https://haxeflixel.com"
                },
                {
                    name: "OpenFL Team",
                    role: "Multimedia Core",
                    description: "Cross-platform hardware rendering backend.",
                    icon: "openfl",
                    color: "#EA1E24",
                    url: "https://www.openfl.org"
                },
                {
                    name: "All of You!",
                    role: "Motivation & Support",
                    description: "Thank you for playing and supporting SoulScorch Engine!\nYou are the reason this engine exists and continues to grow!\nDiscord Link if you press Enter!",
                    icon: "con_allofyou",
                    color: "#FF0000", // engine color, cause we love you all.
                    url: "https://discord.gg/9FZXq7e9pQ"
                }
            ];
        }
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        if (scripts != null) scripts.callAll("onUpdate", [elapsed]);

        updateCreditEffect(elapsed);

        if (Controls.instance.UI_UP_P) changeSelection(-1);
        if (Controls.instance.UI_DOWN_P) changeSelection(1);

        if (Controls.instance.ACCEPT) {
            var entry = credits[curSelected];
            if (entry.url != null && entry.url.length > 0) {
                #if linux
                Sys.command("xdg-open", [entry.url]);
                #else
                FlxG.openURL(entry.url);
                #end
                if (scripts != null) scripts.callAll("onOpenCreditURL", [entry.url]);
            }
        }

        if (Controls.instance.BACK) {
            AssetHelper.playSoundSafely("cancelMenu", 0.7);
            MusicBeatState.switchState(new MainMenuState());
        }

        for (i in 0...grpCredits.members.length) {
            var item = grpCredits.members[i];
            var icon = grpIcons.members[i];
            var targetY = ((i - curSelected) * 75) + (FlxG.height * 0.38);

            item.y = FlxMath.lerp(targetY, item.y, Math.exp(-elapsed * 15.0));
            item.alpha = (i == curSelected ? 1.0 : 0.4);

            if (icon != null) {
                icon.y = item.y - 6;
                icon.alpha = item.alpha;
            }
        }
    }

    private function changeSelection(change:Int = 0):Void {
        if (credits.length == 0) return;
        curSelected = FlxMath.wrap(curSelected + change, 0, credits.length - 1);
        if (change != 0) AssetHelper.playSoundSafely("scrollMenu", 0.7);

        var entry = credits[curSelected];
        roleText.text = entry.role != null ? entry.role.toUpperCase() : LanguageManager.getString("credits.roleFallback", null);
        descText.text = entry.description != null ? entry.description : "";

        var entryColor = entry.color != null && entry.color.length > 0
            ? ColorUtil.fromHexSafe(entry.color, FlxColor.WHITE)
            : FlxColor.WHITE;
        if (grpCredits.members[curSelected] != null) {
            grpCredits.members[curSelected].setTextColor(entryColor);
            grpCredits.members[curSelected].setGlyphShader(null);
            grpCredits.members[curSelected].clearEffect();
            if (entry.effect != null && entry.effect.trim().length > 0) grpCredits.members[curSelected].setEffect(entry.effect);
            if (entry.shader != null && entry.shader.trim().length > 0) {
                var creditShader = ScriptAPI.createShader(entry.shader);
                if (creditShader != null) {
                    grpCredits.members[curSelected].setGlyphShader(creditShader);
                    ScriptAPI.setShaderFloatArray(entry.shader, "redOff", [-0.0015, 0.0]);
                    ScriptAPI.setShaderFloatArray(entry.shader, "greenOff", [0.0, 0.0]);
                    ScriptAPI.setShaderFloatArray(entry.shader, "blueOff", [0.0015, 0.0]);
                }
            }
        }

        if (entry.color != null && entry.color.length > 0) {
            var targetColor = ColorUtil.fromHexSafe(entry.color, bg.color);
            if (colorTween != null) colorTween.cancel();
            colorTween = FlxTween.color(bg, 0.3, bg.color, targetColor, {ease: FlxEase.quartOut});
        }

        if (scripts != null) scripts.callAll("onChangeCredit", [curSelected, entry]);
    }

    private function updateCreditEffect(elapsed:Float):Void {
        if (effectParticles == null) return;

        for (i in 0...effectParticles.members.length) {
            var particle = effectParticles.members[i];
            if (particle == null) continue;
            particle.velocity.y += 260.0 * elapsed;
            particle.angle += particle.angularVelocity * elapsed;
            particle.alpha -= elapsed * 0.55;
            if (particle.alpha <= 0 || particle.y > FlxG.height) {
                effectParticles.remove(particle, true);
                particle.destroy();
            }
        }

        var entry = credits.length > 0 ? credits[curSelected] : null;
        if (entry == null || entry.effect == null || entry.effect.toLowerCase().trim() != "confetti") return;
        effectTimer -= elapsed;
        if (effectTimer <= 0) {
            effectTimer = 0.12;
            spawnCreditConfetti(3);
        }
    }

    public function spawnCreditConfetti(amount:Int = 6):Void {
        if (effectParticles == null || grpCredits == null || grpCredits.members[curSelected] == null) return;
        var anchor = grpCredits.members[curSelected];
        var entry = credits[curSelected];
        var tint = entry.color != null ? ColorUtil.fromHexSafe(entry.color, EditorTheme.ACCENT_CYAN) : EditorTheme.ACCENT_CYAN;
        for (_ in 0...Std.int(Math.max(1, Math.min(amount, 12)))) {
            var particle = new FlxSprite(anchor.x + FlxG.random.float(-10, anchor.width + 10), anchor.y + FlxG.random.float(4, anchor.height));
            particle.makeGraphic(Std.int(FlxG.random.float(4, 8)), Std.int(FlxG.random.float(7, 14)), tint);
            particle.color = FlxG.random.getObject([tint, EditorTheme.ACCENT_YELLOW, EditorTheme.ACCENT_MAGENTA, FlxColor.WHITE]);
            particle.velocity.set(FlxG.random.float(-80, 80), FlxG.random.float(-190, -90));
            particle.angularVelocity = FlxG.random.float(-240, 240);
            particle.alpha = 0.95;
            effectParticles.add(particle);
        }
    }

    override public function destroy():Void {
        if (colorTween != null) colorTween.cancel();
        Controls.instance.unbindMobilePad();
        if (scripts != null) {
            scripts.callAll("onDestroy");
            scripts.clear();
        }
        super.destroy();
    }
}