package soulscorch.ui.menus.credits;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import haxe.Json;
import haxe.xml.Access;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.input.Controls;
import soulscorch.backend.input.MobilePad;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.ScriptManager;
import soulscorch.scripting.mod.ModManager;
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
}

class CreditsState extends MusicBeatState {
    public static var curSelected:Int = 0;

    private var credits:Array<CreditEntry> = [];
    private var grpCredits:FlxTypedGroup<FlxText>;
    private var grpIcons:FlxTypedGroup<FlxSprite>;
    private var bg:FlxSprite;
    private var descBox:FlxSprite;
    private var descText:FlxText;
    private var roleText:FlxText;
    private var scripts:ScriptManager;
    private var mobileControls:MobilePad;
    private var colorTween:FlxTween;

    override public function create():Void {
        super.create();

        #if desktop
        DiscordRPC.changePresence("Credits Menu", "Browsing Developers");
        #end

        scripts = new ScriptManager();
        initCreditsScripts();

        loadCreditsData();

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

        var headerTitle = new FlxText(38, 17, 450, "SOULSCORCH // CREDITS & COLLABORATORS", 18);
        headerTitle.setFormat(Paths.font("vcr"), 18, EditorTheme.TEXT_PRIMARY, LEFT);
        headerTitle.scrollFactor.set(0, 0);
        add(headerTitle);

        grpIcons = new FlxTypedGroup<FlxSprite>();
        add(grpIcons);

        grpCredits = new FlxTypedGroup<FlxText>();
        add(grpCredits);

        for (i in 0...credits.length) {
            var item = new FlxText(160, (i * 80) + 120, 0, credits[i].name, 32);
            item.setFormat(Paths.font("vcr"), 32, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
            item.borderSize = 2.0;
            item.ID = i;
            grpCredits.add(item);

            var iconSpr = new FlxSprite(80, (i * 80) + 115);
            var iconKey = (credits[i].icon != null && credits[i].icon.length > 0) ? credits[i].icon : "default";
            var loaded = AssetHelper.loadGraphicSafely(iconSpr, 'ui/credits/$iconKey');
            if (!loaded) loaded = AssetHelper.loadGraphicSafely(iconSpr, 'credits/$iconKey');
            if (!loaded) iconSpr.makeGraphic(48, 48, EditorTheme.ACCENT_CYAN);
            iconSpr.setGraphicSize(48, 48);
            iconSpr.updateHitbox();
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
        var paths = [
            "data/scripts/menus/credits",
            "scripts/menus/credits",
            "data/scripts/creditsState"
        ];
        for (p in paths) {
            var file = AssetResolver.resolveFile(p, [".soul", ".hx", ".lua", ".py", ".js"]);
            if (file != null) scripts.loadScript(file);
        }
        scripts.setAll("state", this);
        scripts.setAll("credits", credits);
        scripts.callAll("onCreate");
    }

    private function loadCreditsData():Void {
        credits = [];

        #if sys
        var searchPaths = [
            "data/credits.xmsoul",
            "data/credits.xml",
            "data/credits.json",
            "assets/preload/data/credits.json"
        ];

        if (ModManager.activeMods != null) {
            for (m in ModManager.activeMods) {
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
                                name: access.has.name ? entry.att.name : "Unknown",
                                role: entry.has.role ? entry.att.role : "Contributor",
                                description: entry.has.description ? entry.att.description : "",
                                icon: entry.has.icon ? entry.att.icon : "default",
                                color: entry.has.color ? entry.att.color : null,
                                url: entry.has.url ? entry.att.url : null
                            });
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
                    name: "JustyyDev",
                    role: "Lead Programmer & Director",
                    description: "Creator and architectural designer of SoulScorch Engine.",
                    icon: "justy",
                    color: "#00FFCC",
                    url: "https://github.com/JustyyDev"
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
                }
            ];
        }
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        if (scripts != null) scripts.callAll("onUpdate", [elapsed]);

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
        roleText.text = entry.role.toUpperCase();
        descText.text = entry.description;

        if (entry.color != null && entry.color.length > 0) {
            var targetColor = FlxColor.fromString(entry.color);
            if (colorTween != null) colorTween.cancel();
            colorTween = FlxTween.color(bg, 0.3, bg.color, targetColor, {ease: FlxEase.quartOut});
        }

        if (scripts != null) scripts.callAll("onChangeCredit", [curSelected, entry]);
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