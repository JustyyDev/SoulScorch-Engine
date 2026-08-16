package soulscorch.ui.menus;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;

// Debug-only menu (key 7) for jumping straight into any engine editor.
class EditorPickerMenu extends FlxSubState {
    var bg:FlxSprite;
    var grpText:FlxTypedGroup<FlxText>;
    var curSelected:Int = 0;

    var entryNames:Array<String> = ["Character Editor", "Charting Editor"];

    override public function create():Void {
        super.create();

        bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        bg.alpha = 0.75;
        add(bg);

        var titleText = new FlxText(50, 40, 0, "EDITOR PICKER (Debug)", 24);
        titleText.setFormat(null, 24, FlxColor.WHITE, LEFT);
        add(titleText);

        var hintText = new FlxText(50, 70, 0, "UP/DOWN Select   ENTER Open   ESC Close", 14);
        hintText.setFormat(null, 14, 0xFFAAAAAA, LEFT);
        add(hintText);

        grpText = new FlxTypedGroup<FlxText>();
        add(grpText);

        for (i in 0...entryNames.length) {
            var txt = new FlxText(80, 120 + (i * 40), 0, entryNames[i], 24);
            txt.ID = i;
            grpText.add(txt);
        }

        updateSelection();
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (FlxG.keys.justPressed.UP) {
            curSelected--;
            if (curSelected < 0) curSelected = entryNames.length - 1;
            updateSelection();
        }
        if (FlxG.keys.justPressed.DOWN) {
            curSelected++;
            if (curSelected >= entryNames.length) curSelected = 0;
            updateSelection();
        }

        if (FlxG.keys.justPressed.ENTER) {
            openEditor(curSelected);
        }

        if (FlxG.keys.justPressed.ESCAPE || FlxG.keys.justPressed.SEVEN) {
            close();
        }
    }

    function openEditor(index:Int):Void {
        close();
        switch (index) {
            case 0: FlxG.switchState(new CharacterEditorState());
            case 1: FlxG.switchState(new ChartingState());
        }
    }

    function updateSelection():Void {
        grpText.forEach(function(txt:FlxText) {
            txt.color = (txt.ID == curSelected) ? FlxColor.YELLOW : FlxColor.WHITE;
        });
    }
}
