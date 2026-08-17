package soulscorch.menus.credits;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.input.Controls;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.menus.states.MainMenuState;

typedef CreditEntry = {
    var name:String;
    var role:String;
    var description:String;
    var icon:String;
    var ?url:String;
}

class CreditsState extends MusicBeatState {
    public static var curSelected:Int = 0;

    private var credits:Array<CreditEntry> = [
        {
            name: "JustyyDev",
            role: "Lead Programmer & Director",
            description: "Creator and architectural designer of SoulScorch Engine.",
            icon: "justy",
            url: "https://github.com/JustyyDev"
        },
        {
            name: "HaxeFlixel Team",
            role: "Engine Framework",
            description: "The underlying 2D game engine power.",
            icon: "flixel",
            url: "https://haxeflixel.com"
        },
        {
            name: "Away3D Team",
            role: "Stage3D Framework",
            description: "3D scene and mesh acceleration pipeline.",
            icon: "away3d",
            url: "http://away3d.com"
        }
    ];

    private var grpCredits:FlxTypedGroup<FlxText>;
    private var bg:FlxSprite;
    private var descBox:FlxSprite;
    private var descText:FlxText;
    private var roleText:FlxText;

    override public function create():Void {
        super.create();

        DiscordRPC.changePresence("Credits Menu", "Browsing Developers");

        bg = new FlxSprite();
        AssetHelper.loadGraphicSafely(bg, "menus/menuDesat");
        bg.color = 0xFF2A2A38;
        bg.screenCenter();
        bg.antialiasing = true;
        add(bg);

        grpCredits = new FlxTypedGroup<FlxText>();
        add(grpCredits);

        for (i in 0...credits.length) {
            var item = new FlxText(100, (i * 80) + 120, 0, credits[i].name, 36);
            item.setFormat(Paths.font("vcr"), 36, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
            item.borderSize = 2.0;
            item.ID = i;
            grpCredits.add(item);
        }

        descBox = new FlxSprite(0, FlxG.height - 110).makeGraphic(FlxG.width, 110, 0xDD000000);
        add(descBox);

        roleText = new FlxText(20, FlxG.height - 100, FlxG.width - 40, "", 22);
        roleText.setFormat(Paths.font("vcr"), 22, 0xFFFFCC00, CENTER);
        add(roleText);

        descText = new FlxText(20, FlxG.height - 68, FlxG.width - 40, "", 18);
        descText.setFormat(Paths.font("vcr"), 18, FlxColor.WHITE, CENTER);
        add(descText);

        changeSelection();
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

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
            }
        }

        if (Controls.instance.BACK) {
            AssetHelper.playSoundSafely("cancelMenu", 0.7);
            MusicBeatState.switchState(new MainMenuState());
        }

        for (i in 0...grpCredits.members.length) {
            var item = grpCredits.members[i];
            var targetY = ((i - curSelected) * 70) + (FlxG.height * 0.38);
            item.y = FlxMath.lerp(targetY, item.y, Math.exp(-elapsed * 12.0));
            item.alpha = (i == curSelected ? 1.0 : 0.4);
        }
    }

    private function changeSelection(change:Int = 0):Void {
        curSelected = FlxMath.wrap(curSelected + change, 0, credits.length - 1);
        AssetHelper.playSoundSafely("scrollMenu", 0.7);

        var entry = credits[curSelected];
        roleText.text = entry.role;
        descText.text = entry.description;
    }
}