package soulscorch.ui.menus.option;

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
import soulscorch.backend.system.engine.Runtime;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.backend.utils.EngineUtils;
import soulscorch.gameplay.GameplayFlags;
import soulscorch.ui.menus.option.OptionCategory.OptionData;
import soulscorch.ui.menus.states.MainMenuState;

class OptionsMenuState extends MusicBeatState {
    public static var curSelected:Int = 0;
    public static var curCategory:Int = 0;

    private var categories:Array<OptionCategory> = [];
    private var grpRows:FlxTypedGroup<OptionRow>;
    private var categoryTabs:Array<FlxText> = [];

    private var bg:FlxSprite;
    private var descBox:FlxSprite;
    private var descText:FlxText;
    private var categoryHeader:FlxSprite;

    override public function create():Void {
        super.create();

        DiscordRPC.changePresence("Options Menu", "Adjusting Preferences");

        bg = new FlxSprite();
        AssetHelper.loadGraphicSafely(bg, "menuDesat");
        bg.color = 0xFF384252;
        bg.screenCenter();
        bg.antialiasing = true;
        add(bg);

        initCategories();

        categoryHeader = new FlxSprite(0, 0).makeGraphic(FlxG.width, 60, 0xDD0E1722);
        add(categoryHeader);

        for (i in 0...categories.length) {
            var tabText = new FlxText((i * 220) + 40, 16, 200, categories[i].name.toUpperCase(), 22);
            tabText.setFormat(Paths.font("vcr"), 22, FlxColor.WHITE, CENTER);
            tabText.ID = i;
            categoryTabs.push(tabText);
            add(tabText);
        }

        grpRows = new FlxTypedGroup<OptionRow>();
        add(grpRows);

        descBox = new FlxSprite(0, FlxG.height - 85).makeGraphic(FlxG.width, 85, 0xDD0E1722);
        add(descBox);

        descText = new FlxText(20, FlxG.height - 70, FlxG.width - 40, "", 18);
        descText.setFormat(Paths.font("vcr"), 18, FlxColor.WHITE, CENTER);
        add(descText);

        rebuildRows();
        changeSelection();
    }

    private function initCategories():Void {
        categories = [
            new OptionCategory("Gameplay", [
                {
                    name: "Downscroll",
                    description: "Receptors and incoming notes scroll downwards to the bottom edge.",
                    type: "bool",
                    getValue: function() return Runtime.config != null ? Runtime.config.downscroll : false,
                    setValue: function(v) {
                        if (Runtime.config != null) Runtime.config.downscroll = v;
                        GameplayFlags.set("downscroll", v);
                    }
                },
                {
                    name: "Ghost Tapping",
                    description: "Allows tapping directional inputs freely without triggering misses.",
                    type: "bool",
                    getValue: function() return Runtime.config != null ? Runtime.config.ghostTapping : true,
                    setValue: function(v) {
                        if (Runtime.config != null) Runtime.config.ghostTapping = v;
                        GameplayFlags.set("ghostTapping", v);
                    }
                },
                {
                    name: "Botplay",
                    description: "Enables autonomous perfect-hit inputs for song testing and showcasing.",
                    type: "bool",
                    getValue: function() return GameplayFlags.getBool("botplay", false),
                    setValue: function(v) GameplayFlags.set("botplay", v)
                }
            ]),
            new OptionCategory("Visuals", [
                {
                    name: "Framerate Cap",
                    description: "Sets the maximum game rendering refresh frequency.",
                    type: "int",
                    min: 60,
                    max: 360,
                    step: 10,
                    getValue: function() return Runtime.config != null ? Runtime.config.framerate : 120,
                    setValue: function(v) {
                        var val = Std.int(v);
                        if (Runtime.config != null) Runtime.config.framerate = val;
                        EngineUtils.setFramerate(val);
                    }
                },
                {
                    name: "Antialiasing",
                    description: "Smooths sprite edges and reduces pixel stepping across actors and notes.",
                    type: "bool",
                    getValue: function() return Runtime.config != null ? Runtime.config.antialiasing : true,
                    setValue: function(v) {
                        if (Runtime.config != null) Runtime.config.antialiasing = v;
                        GameplayFlags.set("antialiasing", v);
                    }
                },
                {
                    name: "Flashing Lights",
                    description: "Enables camera flashes during dramatic beat drops and cutscenes.",
                    type: "bool",
                    getValue: function() return Runtime.config != null ? Runtime.config.flashingLights : true,
                    setValue: function(v) {
                        if (Runtime.config != null) Runtime.config.flashingLights = v;
                        GameplayFlags.set("flashingLights", v);
                    }
                }
            ]),
            new OptionCategory("Audio", [
                {
                    name: "Vocal Volume",
                    description: "Adjusts the balance volume of individual character voice tracks.",
                    type: "float",
                    min: 0.0,
                    max: 1.0,
                    step: 0.1,
                    getValue: function() return 1.0,
                    setValue: function(v) {}
                },
                {
                    name: "Hit Sound Volume",
                    description: "Sets the audio gain for note confirmation click ticks.",
                    type: "float",
                    min: 0.0,
                    max: 1.0,
                    step: 0.1,
                    getValue: function() return 0.0,
                    setValue: function(v) {}
                }
            ])
        ];
    }

    private function rebuildRows():Void {
        while (grpRows.members.length > 0) {
            var row = grpRows.members[0];
            grpRows.remove(row, true);
            row.destroy();
        }

        var currentOptions = categories[curCategory].options;
        var rowWidth = FlxG.width * 0.85;
        var rowX = (FlxG.width - rowWidth) * 0.5;

        for (i in 0...currentOptions.length) {
            var row = new OptionRow(rowX, (i * 44) + 90, rowWidth, currentOptions[i].name);
            grpRows.add(row);
        }

        for (i in 0...categoryTabs.length) {
            categoryTabs[i].color = (i == curCategory ? 0xFF7AD1FF : FlxColor.WHITE);
            categoryTabs[i].alpha = (i == curCategory ? 1.0 : 0.45);
        }

        updateRowValues();
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        var currentOptions = categories[curCategory].options;

        if (Controls.instance.UI_UP_P) changeSelection(-1);
        if (Controls.instance.UI_DOWN_P) changeSelection(1);

        if (FlxG.keys.justPressed.TAB) {
            curCategory = FlxMath.wrap(curCategory + 1, 0, categories.length - 1);
            curSelected = 0;
            AssetHelper.playSoundSafely("scrollMenu", 0.7);
            rebuildRows();
            changeSelection();
            return;
        }

        if (currentOptions.length > 0) {
            var currentOpt = currentOptions[curSelected];

            if (currentOpt.type == "bool") {
                if (Controls.instance.ACCEPT || Controls.instance.UI_LEFT_P || Controls.instance.UI_RIGHT_P) {
                    var cur = currentOpt.getValue();
                    currentOpt.setValue(!cur);
                    AssetHelper.playSoundSafely("scrollMenu", 0.7);
                    updateRowValues();
                }
            } else if (currentOpt.type == "int" || currentOpt.type == "float") {
                if (Controls.instance.UI_LEFT_P) {
                    var step = (currentOpt.step != null) ? currentOpt.step : 1.0;
                    var next = Math.max(currentOpt.min, currentOpt.getValue() - step);
                    currentOpt.setValue(next);
                    AssetHelper.playSoundSafely("scrollMenu", 0.7);
                    updateRowValues();
                }
                if (Controls.instance.UI_RIGHT_P) {
                    var step = (currentOpt.step != null) ? currentOpt.step : 1.0;
                    var next = Math.min(currentOpt.max, currentOpt.getValue() + step);
                    currentOpt.setValue(next);
                    AssetHelper.playSoundSafely("scrollMenu", 0.7);
                    updateRowValues();
                }
            }
        }

        if (Controls.instance.BACK) {
            if (Runtime.config != null) Runtime.config.save();
            AssetHelper.playSoundSafely("cancelMenu", 0.7);
            MusicBeatState.switchState(new MainMenuState());
        }
    }

    private function changeSelection(change:Int = 0):Void {
        var currentOptions = categories[curCategory].options;
        if (currentOptions.length == 0) return;

        curSelected = FlxMath.wrap(curSelected + change, 0, currentOptions.length - 1);
        AssetHelper.playSoundSafely("scrollMenu", 0.7);

        for (i in 0...grpRows.members.length) {
            grpRows.members[i].setActive(i == curSelected);
        }

        descText.text = currentOptions[curSelected].description;
    }

    private function updateRowValues():Void {
        var currentOptions = categories[curCategory].options;

        for (i in 0...grpRows.members.length) {
            var opt = currentOptions[i];
            var val = opt.getValue();

            if (opt.type == "bool") {
                grpRows.members[i].setValue(val ? "ON" : "OFF", val);
            } else {
                grpRows.members[i].setValue(Std.string(val), null);
            }
        }
    }
}