package soulscorch.ui.menus.option;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.input.keyboard.FlxKey;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.input.Controls;
import soulscorch.backend.input.InputMap;
import soulscorch.backend.input.MobilePad;
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
    private var grpRows:FlxTypedGroup<FlxSprite>;
    private var categoryTabs:Array<FlxText> = [];

    private var bg:FlxSprite;
    private var descBox:FlxSprite;
    private var descText:FlxText;
    private var categoryHeader:FlxSprite;
    private var tabSelectorHighlight:FlxSprite;
    private var mobileControls:MobilePad;

    private var isRebinding:Bool = false;
    private var activeKeybindRow:KeybindRow = null;

    private var holdTimer:Float = 0.0;
    private var repeatTimer:Float = 0.0;

    override public function create():Void {
        super.create();

        #if desktop
        DiscordRPC.changePresence("Options Menu", "Adjusting Preferences");
        #end

        initCategories();

        bg = new FlxSprite();
        if (!AssetHelper.loadGraphicSafely(bg, "menuDesat")) {
            bg.makeGraphic(FlxG.width, FlxG.height, 0xFF1A1424);
        }
        bg.color = categories[curCategory].color;
        bg.screenCenter();
        bg.antialiasing = true;
        add(bg);

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

        grpRows = new FlxTypedGroup<FlxSprite>();
        add(grpRows);

        descBox = new FlxSprite(0, FlxG.height - 75).makeGraphic(FlxG.width, 75, 0xEE0B0910);
        add(descBox);

        descText = new FlxText(20, FlxG.height - 52, FlxG.width - 40, "", 16);
        descText.setFormat(Paths.font("vcr"), 16, 0xFFCCCCCC, CENTER, OUTLINE, FlxColor.BLACK);
        descText.borderSize = 1.0;
        add(descText);

        #if (mobile || debug)
        mobileControls = new MobilePad(FULL, A_B);
        add(mobileControls);
        Controls.instance.bindMobilePad(mobileControls);
        #end

        rebuildRows();
        changeSelection();
    }

    private function initCategories():Void {
        categories = [
            new OptionCategory("Gameplay", "options", 0xFF221A30, [
                {
                    name: "Downscroll",
                    description: "Receptors and incoming notes scroll downwards toward the bottom of the screen.",
                    type: "bool",
                    getValue: function() return Runtime.config != null ? Runtime.config.downscroll : false,
                    setValue: function(v) {
                        if (Runtime.config != null) Runtime.config.downscroll = v;
                        GameplayFlags.set("downscroll", v);
                    }
                },
                {
                    name: "Middlescroll",
                    description: "Centers your strumline receptor lane in the middle of the screen.",
                    type: "bool",
                    getValue: function() return GameplayFlags.getBool("middlescroll", false),
                    setValue: function(v) GameplayFlags.set("middlescroll", v)
                },
                {
                    name: "Ghost Tapping",
                    description: "Allows pressing directional inputs freely without incurring miss penalties.",
                    type: "bool",
                    getValue: function() return Runtime.config != null ? Runtime.config.ghostTapping : true,
                    setValue: function(v) {
                        if (Runtime.config != null) Runtime.config.ghostTapping = v;
                        GameplayFlags.set("ghostTapping", v);
                    }
                },
                {
                    name: "Scroll Speed",
                    description: "Global multiplier applied to the default scroll velocity of charts.",
                    type: "float",
                    min: 0.5,
                    max: 4.0,
                    step: 0.1,
                    getValue: function() return GameplayFlags.getFloat("songSpeedMultiplier", 1.0),
                    setValue: function(v) GameplayFlags.set("songSpeedMultiplier", v)
                },
                {
                    name: "Note Offset (MS)",
                    description: "Calibrates audio-to-visual latency compensation in milliseconds.",
                    type: "int",
                    min: -150,
                    max: 150,
                    step: 1,
                    getValue: function() return GameplayFlags.getInt("noteOffset", 0),
                    setValue: function(v) GameplayFlags.set("noteOffset", Std.int(v))
                },
                {
                    name: "Botplay",
                    description: "Enables automated perfect inputs for demonstration and charting review.",
                    type: "bool",
                    getValue: function() return GameplayFlags.getBool("botplay", false),
                    setValue: function(v) GameplayFlags.set("botplay", v)
                },
                {
                    name: "Note Splashes",
                    description: "Displays dynamic particle splash bursts on 'Sick!' and 'Marvelous!' hits.",
                    type: "bool",
                    getValue: function() return GameplayFlags.getBool("noteSplash", true),
                    setValue: function(v) GameplayFlags.set("noteSplash", v)
                }
            ]),
            new OptionCategory("Visuals", "options", 0xFF1A2A30, [
                {
                    name: "Framerate Cap",
                    description: "Sets the maximum rendering refresh frequency cap.",
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
                    description: "Toggles the performance and memory usage monitor in the corner.",
                    type: "bool",
                    getValue: function() return Main.fpsCounter != null ? Main.fpsCounter.visible : true,
                    setValue: function(v) {
                        if (Main.fpsCounter != null) Main.fpsCounter.visible = v;
                    }
                },
                {
                    name: "Antialiasing",
                    description: "Enables texture smoothing across 2D characters, assets, and UI components.",
                    type: "bool",
                    getValue: function() return Runtime.config != null ? Runtime.config.antialiasing : true,
                    setValue: function(v) {
                        if (Runtime.config != null) Runtime.config.antialiasing = v;
                        GameplayFlags.set("antialiasing", v);
                    }
                },
                {
                    name: "Flashing Lights",
                    description: "Toggles screen flashes and strobe effects during events.",
                    type: "bool",
                    getValue: function() return Runtime.config != null ? Runtime.config.flashingLights : true,
                    setValue: function(v) {
                        if (Runtime.config != null) Runtime.config.flashingLights = v;
                        GameplayFlags.set("flashingLights", v);
                    }
                },
                {
                    name: "Camera Zooms",
                    description: "Enables rhythmic camera zooming bops on quarter beat hits.",
                    type: "bool",
                    getValue: function() return GameplayFlags.getBool("cameraZoomOnBeat", true),
                    setValue: function(v) GameplayFlags.set("cameraZoomOnBeat", v)
                }
            ]),
            new OptionCategory("Audio", "options", 0xFF301A1A, [
                {
                    name: "Master Volume",
                    description: "Sets the global audio volume multiplier across all sounds and music.",
                    type: "float",
                    min: 0.0,
                    max: 1.0,
                    step: 0.05,
                    getValue: function() return FlxG.sound.volume,
                    setValue: function(v) FlxG.sound.volume = v
                },
                {
                    name: "Music Volume",
                    description: "Adjusts background music and instrumental playback volume.",
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
                    description: "Automatically mutes all audio when the application window loses focus.",
                    type: "bool",
                    getValue: function() return FlxG.autoPause,
                    setValue: function(v) FlxG.autoPause = v
                }
            ]),
            new OptionCategory("Controls", "options", 0xFF1A3022, [
                {
                    name: "Note Left",
                    description: "Rebind key assigned to the Left lane note.",
                    type: "keybind",
                    getValue: function() return "note_left",
                    setValue: function(v) {}
                },
                {
                    name: "Note Down",
                    description: "Rebind key assigned to the Down lane note.",
                    type: "keybind",
                    getValue: function() return "note_down",
                    setValue: function(v) {}
                },
                {
                    name: "Note Up",
                    description: "Rebind key assigned to the Up lane note.",
                    type: "keybind",
                    getValue: function() return "note_up",
                    setValue: function(v) {}
                },
                {
                    name: "Note Right",
                    description: "Rebind key assigned to the Right lane note.",
                    type: "keybind",
                    getValue: function() return "note_right",
                    setValue: function(v) {}
                },
                {
                    name: "Reset Keybinds",
                    description: "Restores directional inputs and gameplay keys back to engine defaults (D-F-J-K).",
                    type: "button",
                    getValue: function() return "EXECUTE",
                    setValue: function(_) {
                        InputMap.resetToDefaults();
                        updateRowValues();
                    }
                }
            ])
        ];
    }

    private function rebuildRows():Void {
        grpRows.clear();

        var currentOptions = categories[curCategory].options;
        var rowWidth = FlxG.width * 0.82;
        var rowX = (FlxG.width - rowWidth) * 0.5;

        for (i in 0...currentOptions.length) {
            var opt = currentOptions[i];
            if (opt.type == "keybind") {
                var row = new KeybindRow(rowX, 0, rowWidth, opt.getValue(), opt.name);
                row.y = (i * 60) + 100;
                row.targetY = row.y;
                grpRows.add(row);
            } else {
                var row = new OptionRow(rowX, 0, rowWidth, opt.name);
                row.y = (i * 60) + 100;
                row.targetY = row.y;
                grpRows.add(row);
            }
        }

        var tabWidth = FlxG.width / categories.length;
        FlxTween.cancelTweensOf(tabSelectorHighlight);
        FlxTween.tween(tabSelectorHighlight, {x: (curCategory * tabWidth) + (tabWidth - 140) * 0.5}, 0.25, {ease: FlxEase.quartOut});

        if (bg != null) {
            FlxTween.cancelTweensOf(bg);
            FlxTween.color(bg, 0.3, bg.color, categories[curCategory].color);
        }

        for (i in 0...categoryTabs.length) {
            categoryTabs[i].color = (i == curCategory ? 0xFF00FFCC : FlxColor.WHITE);
            categoryTabs[i].alpha = (i == curCategory ? 1.0 : 0.45);
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

        // Switch category tabs using Q/E, Tab, or Gamepad Shoulder Buttons
        if (FlxG.keys.justPressed.Q || FlxG.keys.justPressed.PAGEUP) {
            changeCategory(-1);
            return;
        }
        if (FlxG.keys.justPressed.E || FlxG.keys.justPressed.PAGEDOWN || FlxG.keys.justPressed.TAB) {
            changeCategory(1);
            return;
        }

        if (currentOptions.length > 0) {
            var currentOpt = currentOptions[curSelected];

            switch (currentOpt.type) {
                case "bool":
                    if (Controls.instance.ACCEPT || Controls.instance.UI_LEFT_P || Controls.instance.UI_RIGHT_P) {
                        var cur:Bool = currentOpt.getValue();
                        currentOpt.setValue(!cur);
                        AssetHelper.playSoundSafely("scrollMenu", 0.7);
                        updateRowValues();
                    }

                case "int", "float":
                    var step = (currentOpt.step != null) ? currentOpt.step : 1.0;
                    var holdingLeft = Controls.instance.UI_LEFT;
                    var holdingRight = Controls.instance.UI_RIGHT;

                    if (Controls.instance.UI_LEFT_P) {
                        modifyNumericOption(currentOpt, -step);
                    } else if (Controls.instance.UI_RIGHT_P) {
                        modifyNumericOption(currentOpt, step);
                    } else if (holdingLeft || holdingRight) {
                        holdTimer += elapsed;
                        if (holdTimer > 0.4) {
                            repeatTimer += elapsed;
                            if (repeatTimer > 0.05) {
                                modifyNumericOption(currentOpt, (holdingLeft ? -step : step));
                                repeatTimer = 0.0;
                            }
                        }
                    } else {
                        holdTimer = 0.0;
                        repeatTimer = 0.0;
                    }

                case "enum":
                    if (currentOpt.options != null && currentOpt.options.length > 0) {
                        if (Controls.instance.UI_LEFT_P || Controls.instance.UI_RIGHT_P || Controls.instance.ACCEPT) {
                            var curVal = Std.string(currentOpt.getValue());
                            var idx = currentOpt.options.indexOf(curVal);
                            var nextIdx = (Controls.instance.UI_LEFT_P) 
                                ? FlxMath.wrap(idx - 1, 0, currentOpt.options.length - 1)
                                : FlxMath.wrap(idx + 1, 0, currentOpt.options.length - 1);
                            currentOpt.setValue(currentOpt.options[nextIdx]);
                            AssetHelper.playSoundSafely("scrollMenu", 0.7);
                            updateRowValues();
                        }
                    }

                case "button":
                    if (Controls.instance.ACCEPT) {
                        currentOpt.setValue(null);
                        AssetHelper.playSoundSafely("confirmMenu", 0.7);
                        updateRowValues();
                    }

                case "keybind":
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

    private function modifyNumericOption(opt:OptionData, delta:Float):Void {
        var curVal:Float = opt.getValue();
        var nextVal:Float = curVal + delta;
        if (opt.min != null) nextVal = Math.max(opt.min, nextVal);
        if (opt.max != null) nextVal = Math.min(opt.max, nextVal);

        opt.setValue(opt.type == "int" ? Math.round(nextVal) : nextVal);
        AssetHelper.playSoundSafely("scrollMenu", 0.6);
        updateRowValues();
    }

    private function changeCategory(delta:Int):Void {
        curCategory = FlxMath.wrap(curCategory + delta, 0, categories.length - 1);
        curSelected = 0;
        AssetHelper.playSoundSafely("scrollMenu", 0.7);
        rebuildRows();
        changeSelection();
    }

    private function handleKeybindInput():Void {
        var pressedKey = FlxG.keys.firstJustPressed();
        if (pressedKey != FlxKey.NONE) {
            if (pressedKey == FlxKey.ESCAPE) {
                if (activeKeybindRow != null) activeKeybindRow.setListening(false);
                AssetHelper.playSoundSafely("cancelMenu", 0.7);
            } else if (pressedKey == FlxKey.BACKSPACE || pressedKey == FlxKey.DELETE) {
                InputMap.bindKey(activeKeybindRow.actionName, FlxKey.NONE, 0);
                if (activeKeybindRow != null) activeKeybindRow.setListening(false);
                AssetHelper.playSoundSafely("cancelMenu", 0.7);
            } else {
                InputMap.bindKey(activeKeybindRow.actionName, pressedKey, 0);
                if (activeKeybindRow != null) activeKeybindRow.setListening(false);
                AssetHelper.playSoundSafely("confirmMenu", 0.7);
            }
            isRebinding = false;
            activeKeybindRow = null;
            updateRowValues();
        }
    }

    private function changeSelection(change:Int = 0):Void {
        var currentOptions = categories[curCategory].options;
        if (currentOptions.length == 0) return;

        curSelected = FlxMath.wrap(curSelected + change, 0, currentOptions.length - 1);
        AssetHelper.playSoundSafely("scrollMenu", 0.7);

        for (i in 0...grpRows.members.length) {
            var member = grpRows.members[i];
            var isCur = (i == curSelected);

            if (Std.isOfType(member, OptionRow)) {
                var row:OptionRow = cast member;
                row.setActive(isCur);
                row.targetY = ((i - curSelected) * 60) + (FlxG.height * 0.44);
            } else if (Std.isOfType(member, KeybindRow)) {
                var row:KeybindRow = cast member;
                row.setActive(isCur);
                row.targetY = ((i - curSelected) * 60) + (FlxG.height * 0.44);
            }
        }

        descText.text = currentOptions[curSelected].description;
    }

    private function updateRowValues():Void {
        var currentOptions = categories[curCategory].options;

        for (i in 0...grpRows.members.length) {
            var opt = currentOptions[i];
            var member = grpRows.members[i];

            switch (opt.type) {
                case "bool":
                    var val = opt.getValue();
                    cast(member, OptionRow).setValue(val ? "ENABLED" : "DISABLED", val);

                case "float":
                    var val:Float = opt.getValue();
                    var formatted = opt.formatValue != null ? opt.formatValue(val) : Std.string(Math.round(val * 100) / 100);
                    cast(member, OptionRow).setValue(formatted, null);

                case "int":
                    var val:Int = opt.getValue();
                    var formatted = opt.formatValue != null ? opt.formatValue(val) : Std.string(val);
                    cast(member, OptionRow).setValue(formatted, null);

                case "enum":
                    var val = Std.string(opt.getValue());
                    cast(member, OptionRow).setValue('< $val >', null);

                case "button":
                    cast(member, OptionRow).setValue("[ PRESS ENTER ]", null);

                case "keybind":
                    cast(member, KeybindRow).refreshKeyLabel();
            }
        }
    }

    override public function destroy():Void {
        Controls.instance.unbindMobilePad();
        super.destroy();
    }
}