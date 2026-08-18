package soulscorch.ui.menus.option;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import openfl.events.KeyboardEvent;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.input.Controls;
import soulscorch.backend.input.InputMap;
import soulscorch.backend.system.engine.Runtime;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.backend.utils.EngineUtils;
import soulscorch.gameplay.GameplayFlags;
import soulscorch.ui.menus.option.KeybindRow;
import soulscorch.ui.menus.option.OptionCategory;
import soulscorch.ui.menus.option.OptionRow;
import soulscorch.ui.menus.states.MainMenuState;

class OptionsMenuState extends MusicBeatState {
    public static var curSelected:Int = 0;
    public static var curCategory:Int = 0;

    private var categories:Array<OptionCategory> = [];
    private var grpRows:FlxTypedGroup<FlxSprite> = new FlxTypedGroup<FlxSprite>();
    private var categoryTabs:Array<FlxText> = [];

    private var bg:FlxSprite;
    private var descBox:FlxSprite;
    private var descText:FlxText;
    private var categoryHeader:FlxSprite;
    private var tabSelectorHighlight:FlxSprite;

    private var isRebinding:Bool = false;
    private var activeKeybindRow:KeybindRow = null;

    private var categoryColors:Array<FlxColor> = [
        0xFF221A30, // Gameplay - Deep Purple
        0xFF1A2A30, // Visuals - Deep Teal
        0xFF301A1A, // Audio - Deep Crimson
        0xFF1A3022  // Controls - Deep Emerald
    ];

    override public function create():Void {
        super.create();

        #if desktop
        DiscordRPC.changePresence("Options Menu", "Adjusting Preferences");
        #end

        bg = new FlxSprite();
        if (!AssetHelper.loadGraphicSafely(bg, "menuDesat")) {
            bg.makeGraphic(FlxG.width, FlxG.height, 0xFF1A1424);
        }
        bg.color = categoryColors[curCategory];
        bg.screenCenter();
        bg.antialiasing = true;
        add(bg);

        initCategories();

        categoryHeader = new FlxSprite(0, 0).makeGraphic(FlxG.width, 70, 0xEE0B0910);
        add(categoryHeader);

        tabSelectorHighlight = new FlxSprite(0, 62).makeGraphic(140, 6, 0xFF00FFCC);
        add(tabSelectorHighlight);

        var tabWidth = FlxG.width / categories.length;
        for (i in 0...categories.length) {
            var tabText = new FlxText(i * tabWidth, 22, tabWidth, categories[i].name.toUpperCase(), 16);
            tabText.setFormat(Paths.font("vcr"), 16, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
            tabText.borderSize = 1.0;
            tabText.ID = i;
            categoryTabs.push(tabText);
            add(tabText);
        }

        add(grpRows);

        descBox = new FlxSprite(0, FlxG.height - 75).makeGraphic(FlxG.width, 75, 0xEE0B0910);
        add(descBox);

        descText = new FlxText(20, FlxG.height - 50, FlxG.width - 40, "", 16);
        descText.setFormat(Paths.font("vcr"), 16, 0xFFCCCCCC, CENTER, OUTLINE, FlxColor.BLACK);
        descText.borderSize = 1.0;
        add(descText);

        rebuildRows();
        changeSelection();
    }

    private function initCategories():Void {
        categories = [
            new OptionCategory("Gameplay", "options", [
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
                    name: "Scroll Speed",
                    description: "Multiplies default chart scroll velocity globally.",
                    type: "float",
                    min: 1.0,
                    max: 4.0,
                    step: 0.1,
                    getValue: function() return GameplayFlags.getFloat("songSpeedMultiplier", 1.0),
                    setValue: function(v) GameplayFlags.set("songSpeedMultiplier", v)
                },
                {
                    name: "Note Offset (MS)",
                    description: "Adjusts input timing window offset to compensate for audio latency.",
                    type: "int",
                    min: -100,
                    max: 100,
                    step: 2,
                    getValue: function() return GameplayFlags.getInt("noteOffset", 0),
                    setValue: function(v) GameplayFlags.set("noteOffset", Std.int(v))
                },
                {
                    name: "Botplay",
                    description: "Enables autonomous perfect-hit inputs for song testing and showcasing.",
                    type: "bool",
                    getValue: function() return GameplayFlags.getBool("botplay", false),
                    setValue: function(v) GameplayFlags.set("botplay", v)
                },
                {
                    name: "Note Splashes",
                    description: "Spawns dynamic particle bursts when hitting 'Sick!' judgments.",
                    type: "bool",
                    getValue: function() return GameplayFlags.getBool("noteSplash", true),
                    setValue: function(v) GameplayFlags.set("noteSplash", v)
                }
            ]),
            new OptionCategory("Visuals", "options", [
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
                    name: "FPS Counter",
                    description: "Toggles the performance monitor display in the top-left corner.",
                    type: "bool",
                    getValue: function() return Main.fpsCounter != null ? Main.fpsCounter.visible : true,
                    setValue: function(v) {
                        if (Main.fpsCounter != null) Main.fpsCounter.visible = v;
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
                },
                {
                    name: "Camera Zooms",
                    description: "Zooms the game camera in and out dynamically on beat hits.",
                    type: "bool",
                    getValue: function() return GameplayFlags.getBool("cameraZoomOnBeat", true),
                    setValue: function(v) GameplayFlags.set("cameraZoomOnBeat", v)
                }
            ]),
            new OptionCategory("Audio", "options", [
                {
                    name: "Instrumental Volume",
                    description: "Adjusts the master volume level of song instrumentals.",
                    type: "float",
                    min: 0.0,
                    max: 1.0,
                    step: 0.05,
                    getValue: function() return FlxG.sound.music != null ? FlxG.sound.music.volume : 1.0,
                    setValue: function(v) {
                        if (FlxG.sound.music != null) FlxG.sound.music.volume = v;
                    }
                },
                {
                    name: "Mute on Focus Loss",
                    description: "Mutes game audio automatically when window loses focus.",
                    type: "bool",
                    getValue: function() return FlxG.autoPause,
                    setValue: function(v) FlxG.autoPause = v
                }
            ]),
            new OptionCategory("Controls", "options", [
                {
                    name: "Note Left",
                    description: "Primary key assigned to the Left note lane.",
                    type: "keybind",
                    getValue: function() return "note_left",
                    setValue: function(v) {}
                },
                {
                    name: "Note Down",
                    description: "Primary key assigned to the Down note lane.",
                    type: "keybind",
                    getValue: function() return "note_down",
                    setValue: function(v) {}
                },
                {
                    name: "Note Up",
                    description: "Primary key assigned to the Up note lane.",
                    type: "keybind",
                    getValue: function() return "note_up",
                    setValue: function(v) {}
                },
                {
                    name: "Note Right",
                    description: "Primary key assigned to the Right note lane.",
                    type: "keybind",
                    getValue: function() return "note_right",
                    setValue: function(v) {}
                }
            ])
        ];
    }

    private function rebuildRows():Void {
        grpRows.clear();

        var currentOptions = categories[curCategory].options;
        var rowWidth = FlxG.width * 0.8;
        var rowX = (FlxG.width - rowWidth) * 0.5;

        for (i in 0...currentOptions.length) {
            var opt = currentOptions[i];
            if (opt.type == "keybind") {
                var row = new KeybindRow(rowX, (i * 56) + 95, rowWidth, opt.getValue(), opt.name);
                grpRows.add(row);
            } else {
                var row = new OptionRow(rowX, (i * 56) + 95, rowWidth, opt.name);
                grpRows.add(row);
            }
        }

        var tabWidth = FlxG.width / categories.length;
        FlxTween.cancelTweensOf(tabSelectorHighlight);
        FlxTween.tween(tabSelectorHighlight, {x: (curCategory * tabWidth) + (tabWidth - 140) * 0.5}, 0.25, {ease: FlxEase.quartOut});

        if (bg != null) {
            FlxTween.cancelTweensOf(bg);
            FlxTween.color(bg, 0.3, bg.color, categoryColors[curCategory]);
        }

        for (i in 0...categoryTabs.length) {
            categoryTabs[i].color = (i == curCategory ? 0xFF00FFCC : FlxColor.WHITE);
            categoryTabs[i].alpha = (i == curCategory ? 1.0 : 0.5);
        }

        updateRowValues();
    }

    override public function update(elapsed:Float):Void {
        if (isRebinding) {
            handleKeybindInput();
            return;
        }

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
                var step = (currentOpt.step != null) ? currentOpt.step : 1.0;
                if (Controls.instance.UI_LEFT_P) {
                    var next = Math.max(currentOpt.min, currentOpt.getValue() - step);
                    currentOpt.setValue(next);
                    AssetHelper.playSoundSafely("scrollMenu", 0.7);
                    updateRowValues();
                }
                if (Controls.instance.UI_RIGHT_P) {
                    var next = Math.min(currentOpt.max, currentOpt.getValue() + step);
                    currentOpt.setValue(next);
                    AssetHelper.playSoundSafely("scrollMenu", 0.7);
                    updateRowValues();
                }
            } else if (currentOpt.type == "keybind") {
                if (Controls.instance.ACCEPT) {
                    isRebinding = true;
                    activeKeybindRow = cast grpRows.members[curSelected];
                    if (activeKeybindRow != null) {
                        activeKeybindRow.setListening(true);
                    }
                    AssetHelper.playSoundSafely("confirmMenu", 0.7);
                }
            }
        }

        if (Controls.instance.BACK) {
            if (Runtime.config != null) Runtime.config.save();
            AssetHelper.playSoundSafely("cancelMenu", 0.7);
            MusicBeatState.switchState(new MainMenuState());
        }
    }

    private function handleKeybindInput():Void {
        if (FlxG.keys.firstJustPressed() != flixel.input.keyboard.FlxKey.NONE) {
            var pressedKey = FlxG.keys.firstJustPressed();
            if (pressedKey != flixel.input.keyboard.FlxKey.ESCAPE && activeKeybindRow != null) {
                InputMap.bindKey(activeKeybindRow.actionName, pressedKey, 0);
                activeKeybindRow.setListening(false);
                AssetHelper.playSoundSafely("confirmMenu", 0.7);
            } else if (activeKeybindRow != null) {
                activeKeybindRow.setListening(false);
                AssetHelper.playSoundSafely("cancelMenu", 0.7);
            }
            isRebinding = false;
            activeKeybindRow = null;
        }
    }

    private function changeSelection(change:Int = 0):Void {
        var currentOptions = categories[curCategory].options;
        if (currentOptions.length == 0) return;

        curSelected = FlxMath.wrap(curSelected + change, 0, currentOptions.length - 1);
        AssetHelper.playSoundSafely("scrollMenu", 0.7);

        for (i in 0...grpRows.members.length) {
            var member = grpRows.members[i];
            if (Std.isOfType(member, OptionRow)) {
                cast(member, OptionRow).setActive(i == curSelected);
            } else if (Std.isOfType(member, KeybindRow)) {
                cast(member, KeybindRow).setActive(i == curSelected);
            }
        }

        descText.text = currentOptions[curSelected].description;
    }

    private function updateRowValues():Void {
        var currentOptions = categories[curCategory].options;

        for (i in 0...grpRows.members.length) {
            var opt = currentOptions[i];
            var member = grpRows.members[i];

            if (opt.type == "bool") {
                var val = opt.getValue();
                cast(member, OptionRow).setValue(val ? "ENABLED" : "DISABLED", val);
            } else if (opt.type == "float") {
                var val = opt.getValue();
                cast(member, OptionRow).setValue(Std.string(Math.round(val * 100) / 100), null);
            } else if (opt.type == "int") {
                var val = opt.getValue();
                cast(member, OptionRow).setValue(Std.string(val), null);
            } else if (opt.type == "keybind") {
                cast(member, KeybindRow).refreshKeyLabel();
            }
        }
    }
}