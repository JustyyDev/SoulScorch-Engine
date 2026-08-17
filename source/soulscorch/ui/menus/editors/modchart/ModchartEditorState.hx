package soulscorch.ui.menus.editors.modchart;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.input.Controls;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.gameplay.modchart.BasicModifiers;
import soulscorch.gameplay.modchart.ModchartManager;
import soulscorch.gameplay.notes.Strumline;
import soulscorch.ui.menus.editors.EditorPickerMenu;

class ModchartEditorState extends MusicBeatState {
    public var playerStrumline:Strumline;
    public var opponentStrumline:Strumline;
    public var modchartManager:ModchartManager;

    public var availableMods:Array<String> = ["drunk", "tipsy", "tornado", "beat", "bumpy"];
    public var curModIndex:Int = 0;
    public var modValues:Map<String, Float> = new Map();

    private var infoText:FlxText;
    private var timelineText:FlxText;
    private var isSimulating:Bool = true;

    override public function create():Void {
        super.create();

        DiscordRPC.changePresence("Modchart Editor", "Graphing Strum Modifiers");

        var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF14121F);
        add(bg);

        // Strumlines
        opponentStrumline = new Strumline(92, 100, false, false);
        playerStrumline = new Strumline(FlxG.width - 480, 100, true, false);
        add(opponentStrumline);
        add(playerStrumline);

        modchartManager = new ModchartManager(playerStrumline, opponentStrumline);

        for (m in availableMods) {
            modValues.set(m, 0.0);
        }

        setupUI();
    }

    private function setupUI():Void {
        var topBar = new FlxSprite(0, 0).makeGraphic(FlxG.width, 40, 0xDD0D111A);
        add(topBar);

        infoText = new FlxText(15, 8, FlxG.width - 30, "", 18);
        infoText.setFormat(Paths.font("vcr"), 18, FlxColor.WHITE, LEFT);
        add(infoText);

        timelineText = new FlxText(40, FlxG.height - 120, FlxG.width - 80, "", 20);
        timelineText.setFormat(Paths.font("vcr"), 20, 0xFFFFCC00, LEFT, OUTLINE, FlxColor.BLACK);
        add(timelineText);

        var help = new FlxText(15, FlxG.height - 40, FlxG.width - 30, "[W/S] Select Mod | [A/D] Adjust Strength | [SPACE] Toggle Song Clock Simulation | [ESC] Exit", 16);
        help.setFormat(Paths.font("vcr"), 16, FlxColor.WHITE, LEFT);
        add(help);

        updateText();
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (isSimulating) {
            Conductor.songPosition += elapsed * 1000.0;
        }

        // Switch active modifier
        if (FlxG.keys.justPressed.W) changeMod(-1);
        if (FlxG.keys.justPressed.S) changeMod(1);

        // Adjust modifier value
        var curMod = availableMods[curModIndex];
        var curVal = modValues.get(curMod);

        if (FlxG.keys.pressed.A) {
            curVal -= elapsed * 2.0;
            modValues.set(curMod, curVal);
            modchartManager.set(curMod, curVal);
        }
        if (FlxG.keys.pressed.D) {
            curVal += elapsed * 2.0;
            modValues.set(curMod, curVal);
            modchartManager.set(curMod, curVal);
        }

        if (FlxG.keys.justPressed.SPACE) {
            isSimulating = !isSimulating;
        }

        if (Controls.instance.BACK) {
            MusicBeatState.switchState(new EditorPickerMenu());
        }

        modchartManager.update(elapsed);
        updateText();
    }

    private function changeMod(change:Int):Void {
        curModIndex = FlxMath.wrap(curModIndex + change, 0, availableMods.length - 1);
        updateText();
    }

    private function updateText():Void {
        var curMod = availableMods[curModIndex];
        var curVal = modValues.get(curMod);
        infoText.text = 'Active Modifier: ${curMod.toUpperCase()} | Value: ${Math.round(curVal * 100) / 100} | Simulating: $isSimulating';

        var summary = "Active Values:\n";
        for (m in availableMods) {
            summary += '$m: ${Math.round(modValues.get(m) * 100) / 100} | ';
        }
        timelineText.text = summary;
    }
}