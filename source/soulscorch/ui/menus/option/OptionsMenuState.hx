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
import soulscorch.ui.menus.editors.editorui.EditorTheme;
import soulscorch.ui.menus.option.KeybindRow;
import soulscorch.ui.menus.option.OptionCategory;
import soulscorch.ui.menus.option.OptionRow;
import soulscorch.ui.menus.states.MainMenuState;

using StringTools;

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
        DiscordRPC.changePresence("Options Menu", "Configuring Preferences");
        #end

        initCategories();

        bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, EditorTheme.BG_DARK);
        bg.scrollFactor.set(0, 0);
        add(bg);

        // Grid Background lines
        var grid = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.TRANSPARENT);
        for (i in 0...Std.int(FlxG.width / 40)) {
            grid.pixels.fillRect(new openfl.geom.Rectangle(i * 40, 0, 1, FlxG.height), 0x08FFFFFF);
        }
        for (i in 0...Std.int(FlxG.height / 40)) {
            grid.pixels.fillRect(new openfl.geom.Rectangle(0, i * 40, FlxG.width, 1), 0x08FFFFFF);
        }
        grid.dirty = true;
        grid.scrollFactor.set(0, 0);
        add(grid);

        categoryHeader = new FlxSprite(0, 0).makeGraphic(FlxG.width, 68, EditorTheme.PANEL_HEADER);
        categoryHeader.scrollFactor.set(0, 0);
        add(categoryHeader);

        var topBorder = new FlxSprite(0, 67).makeGraphic(FlxG.width, 1, EditorTheme.PANEL_BORDER);
        topBorder.scrollFactor.set(0, 0);
        add(topBorder);

        tabSelectorHighlight = new FlxSprite(0, 64).makeGraphic(140, 4, EditorTheme.ACCENT_CYAN);
        tabSelectorHighlight.scrollFactor.set(0, 0);
        add(tabSelectorHighlight);

        var tabWidth = FlxG.width / categories.length;
        for (i in 0...categories.length) {
            var tabText = new FlxText(i * tabWidth, 20, tabWidth, categories[i].name.toUpperCase(), 16);
            tabText.setFormat(Paths.font("vcr"), 16, EditorTheme.TEXT_PRIMARY, CENTER, OUTLINE, FlxColor.BLACK);
            tabText.borderSize = 1.0;
            tabText.scrollFactor.set(0, 0);
            tabText.ID = i;
            categoryTabs.push(tabText);
            add(tabText);
        }

        grpRows = new FlxTypedGroup<FlxSprite>();
        add(grpRows);

        descBox = new FlxSprite(0, FlxG.height - 70).makeGraphic(FlxG.width, 70, EditorTheme.PANEL_HEADER);
        descBox.scrollFactor.set(0, 0);
        add(descBox);

        var descBorder = new FlxSprite(0, FlxG.height - 70).makeGraphic(FlxG.width, 1, EditorTheme.PANEL_BORDER);
        descBorder.scrollFactor.set(0, 0);
        add(descBorder);

        descText = new FlxText(30, FlxG.height - 48, FlxG.width - 60, "", 15);
        descText.setFormat(Paths.font("vcr"), 15, EditorTheme.ACCENT_CYAN, CENTER, OUTLINE, FlxColor.BLACK);
        descText.borderSize = 1.0;
        descText.scrollFactor.set(0, 0);
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
                    description: "Notes scroll downwards toward the strumline receptors at the bottom.",
                    type: "bool",
                    getValue: function() return Runtime.config != null ? Runtime.config.downscroll : false,
                    setValue: function(v) {
                        if (Runtime.config != null) Runtime.config.downscroll = v;
                        GameplayFlags.set("downscroll", v);
                    }
                },
                {
                    name: "Middlescroll",
                    description: "Centers your player strumline receptor lane in the middle of the display.",
                    type: "bool",
                    getValue: function() return GameplayFlags.getBool("middlescroll", false),
                    setValue: function(v) GameplayFlags.set("middlescroll", v)
                },
                {
                    name: "Ghost Tapping",
                    description: "Allows tapping inputs freely without penalizing misses when no notes exist.",
                    type: "bool",
                    getValue: function() return Runtime.config != null ? Runtime.config.ghostTapping : true,
                    setValue: function(v) {
                        if (Runtime.config != null) Runtime.config.ghostTapping = v;
                        GameplayFlags.set("ghostTapping", v);
                    }
                },
                {
                    name: "Scroll Speed Multiplier",
                    description: "Scales the default chart scrolling velocity across all songs.",
                    type: "float",
                    min: 0.5,
                    max: 4.0,
                    step: 0.1,
                    formatValue: function(v) return Math.round(v * 10) / 10 + "x",
                    getValue: function() return GameplayFlags.getFloat("songSpeedMultiplier", 1.0),
                    setValue: function(v) GameplayFlags.set("songSpeedMultiplier", v)
                },
                {
                    name: "Audio Latency Offset",
                    description: "Calibrates audio hardware-to-visual latency in milliseconds.",
                    type: "int",
                    min: -250,
                    max: 250,
                    step: 1,
                    formatValue: function(v) return v + " ms",
                    getValue: function() return GameplayFlags.getInt("noteOffset", 0),
                    setValue: function(v) GameplayFlags.set("noteOffset", Std.int(v))
                },
                {
                    name: "Botplay Demonstration",
                    description: "Automates perfect inputs for demonstration, charting, and testing.",
                    type: "bool",
                    getValue: function() return GameplayFlags.getBool("botplay", false),
                    setValue: function(v) GameplayFlags.set("botplay", v)
                },
                {
                    name: "Hit Particle Splashes",
                    description: "Emits dynamic particle splashes on 'Sick!' and 'Marvelous!' note hits.",
                    type: "bool",
                    getValue: function() return GameplayFlags.getBool("noteSplash", true),
                    setValue: function(v) GameplayFlags.set("noteSplash", v)
                }
            ]),
            new OptionCategory("Visuals", "options", 0xFF1A2A30, [
                {
                    name: "Framerate Cap",
                    description: "Configures the maximum rendering refresh frequency cap.",
                    type: "int",
                    min: 60,
                    max: 360,
                    step: 10,
                    formatValue: function(v) return v + " FPS",
                    getValue: function() return Runtime.config != null ? Runtime.config.framerate : 120,
                    setValue: function(v) {
                        var val = Std.int(v);
                        if (Runtime.config != null) Runtime.config.framerate = val;
                        EngineUtils.setFramerate(val);
                    }
                },
                {
                    name: "FPS & Memory Overlay",
                    description: "Displays real-time FPS, frame duration, and memory utilization monitors.",
                    type: "bool",
                    getValue: function() return Main.fpsCounter != null ? Main.fpsCounter.visible : true,
                    setValue: function(v) {
                        if (Main.fpsCounter != null) Main.fpsCounter.visible = v;
                    }
                },
                {
                    name: "Hardware Antialiasing",
                    description: "Enables smoothing filters across 2D sprites, stage textures, and character atlases.",
                    type: "bool",
                    getValue: function() return Runtime.config != null ? Runtime.config.antialiasing : true,
                    setValue: function(v) {
                        if (Runtime.config != null) Runtime.config.antialiasing = v;
                        GameplayFlags.set("antialiasing", v);
                    }
                },
                {
                    name: "Flashing Light Effects",
                    description: "Controls screen flashes, strobe pulses, and lightning shader effects.",
                    type: "bool",
                    getValue: function() return Runtime.config != null ? Runtime.config.flashingLights : true,
                    setValue: function(v) {
                        if (Runtime.config != null) Runtime.config.flashingLights = v;
                        GameplayFlags.set("flashingLights", v);
                    }
                },
                {
                    name: "Camera Beat Bops",
                    description: "Triggers rhythmic camera zoom pulses on quarter beat marks.",
                    type: "bool",
                    getValue: function() return GameplayFlags.getBool("cameraZoomOnBeat", true),
                    setValue: function(v) GameplayFlags.set("cameraZoomOnBeat", v)
                }
            ]),
            new OptionCategory("Audio", "options", 0xFF301A1A, [
                {
                    name: "Master Volume",
                    description: "Sets the master sound mixer volume level across all channels.",
                    type: "float",
                    min: 0.0,
                    max: 1.0,
                    step: 0.05,
                    formatValue: function(v) return Math.round(v * 100) + "%",
                    getValue: function() return FlxG.sound.volume,
                    setValue: function(v) FlxG.sound.volume = v
                },
                {
                    name: "Music Channel Volume",
                    description: "Adjusts instrumental tracks and background music volume levels.",
                    type: "float",
                    min: 0.0,
                    max: 1.0,
                    step: 0.05,
                    formatValue: function(v) return Math.round(v * 100) + "%",
                    getValue: function() return FlxG.sound.music != null ? FlxG.sound.music.volume : 1.0,
                    setValue: function(v) {
                        if (FlxG.sound.music != null) FlxG.sound.music.volume = v;
                    }
                },
                {
                    name: "Mute On Focus Loss",
                    description: "Mutes all active audio playback when the engine window loses focus.",
                    type: "bool",
                    getValue: function() return FlxG.autoPause,
                    setValue: function(v) FlxG.autoPause = v
                }
            ]),
            new OptionCategory("Controls", "options", 0xFF1A3022, [
                {
                    name: "Left Lane Note",
                    description: "Rebind key assigned to the Left direction lane.",
                    type: "keybind",
                    getValue: function() return "note_left",
                    setValue: function(v) {}
                },
                {
                    name: "Down Lane Note",
                    description: "Rebind key assigned to the Down direction lane.",
                    type: "keybind",
                    getValue: function() return "note_down",
                    setValue: function(v) {}
                },
                {
                    name: "Up Lane Note",
                    description: "Rebind key assigned to the Up direction lane.",
                    type: "keybind",
                    getValue: function() return "note_up",
                    setValue: function(v) {}
                },
                {
                    name: "Right Lane Note",
                    description: "Rebind key assigned to the Right direction lane.",
                    type: "keybind",
                    getValue: function() return "note_right",
                    setValue: function(v) {}
                },
                {
                    name: "Reset Controls To Default",
                    description: "Restores directional inputs and key mappings back to defaults (D-F-J-K).",
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
        var rowWidth = FlxG.width * 0.84;
        var rowX = (FlxG.width - rowWidth) * 0.5;

        for (i in 0...currentOptions.length) {
            var opt = currentOptions[i];
            if (opt.type == "keybind") {
                var row = new KeybindRow(rowX, 0, rowWidth, opt.getValue(), opt.name);
                row.y = (i * 64) + 96;
                row.targetY = row.y;
                grpRows.add(row);
            } else {
                var row = new OptionRow(rowX, 0, rowWidth, opt.name);
                row.y = (i * 64) + 96;
                row.targetY = row.y;
                grpRows.add(row);
            }
        }

        var tabWidth = FlxG.width / categories.length;
        FlxTween.cancelTweensOf(tabSelectorHighlight);
        FlxTween.tween(tabSelectorHighlight, {x: (curCategory * tabWidth) + (tabWidth - 140) * 0.5}, 0.25, {ease: FlxEase.quartOut});

        for (i in 0...categoryTabs.length) {
            categoryTabs[i].color = (i == curCategory ? EditorTheme.ACCENT_CYAN : EditorTheme.TEXT_PRIMARY);
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

        // Switch category tabs using Q/E, Tab, or PageUp/Down
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
                        if (holdTimer > 0.35) {
                            repeatTimer += elapsed;
                            if (repeatTimer > 0.04) {
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
        AssetHelper.playSoundSafely("scrollMenu", 0.5);
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
                row.targetY = ((i - curSelected) * 64) + (FlxG.height * 0.44);
            } else if (Std.isOfType(member, KeybindRow)) {
                var row:KeybindRow = cast member;
                row.setActive(isCur);
                row.targetY = ((i - curSelected) * 64) + (FlxG.height * 0.44);
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