package soulscorch.ui.menus;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxe.xml.Access;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.system.XMSoul;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.ScriptManager;
import soulscorch.ui.hud.Alphabet;
import soulscorch.ui.menus.editors.editorui.*;

class XMSoulState extends MusicBeatState {
    public var layoutPath:String;
    public var script:ScriptManager;
    public var elements:Map<String, Dynamic> = new Map<String, Dynamic>();

    private var camUI:FlxCamera;

    public function new(layoutPath:String) {
        super();
        this.layoutPath = layoutPath;
    }

    override public function create():Void {
        super.create();

        camUI = new FlxCamera();
        camUI.bgColor = FlxColor.TRANSPARENT;
        FlxG.cameras.add(camUI, false);

        var xml = XMSoul.parse(layoutPath);
        if (xml == null) {
            Logger.error('Failed to parse menu layout: $layoutPath', "xmsoul");
            return;
        }

        buildFromXML(xml);

        var scriptPath = XMSoul.getAttr(xml, "script", "");
        if (scriptPath != "") {
            script = new ScriptManager();
            script.loadScript(scriptPath);
            script.setAll("menu", this);
            script.callAll("onCreate");
        }

        FlxG.mouse.visible = true;
    }

    private function buildFromXML(root:Access):Void {
        for (node in root.elements) {
            switch (node.name.toLowerCase()) {
                case "theme":
                    var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.fromString(XMSoul.getAttr(node, "bg", "0xFF110D1B")));
                    bg.scrollFactor.set();
                    add(bg);

                case "window":
                    var win = new EditorWindow(
                        XMSoul.getFloatAttr(node, "x", 0),
                        XMSoul.getFloatAttr(node, "y", 0),
                        XMSoul.getIntAttr(node, "width", 300),
                        XMSoul.getIntAttr(node, "height", 200),
                        XMSoul.getAttr(node, "title", "Window")
                    );
                    win.cameras = [camUI];
                    add(win);
                    elements.set(XMSoul.getAttr(node, "id", "win"), win);

                    for (child in node.elements) {
                        var elem = parseUIElement(child);
                        if (elem != null) win.addElement(elem);
                    }

                case "cards":
                    parseCards(node);
            }
        }
    }

    private function parseUIElement(node:Access):Dynamic {
        var id = XMSoul.getAttr(node, "id", "");
        var x = XMSoul.getFloatAttr(node, "x", 0);
        var y = XMSoul.getFloatAttr(node, "y", 0);
        var action = XMSoul.getAttr(node, "action", "");

        switch (node.name.toLowerCase()) {
            case "text":
                var txt = new FlxText(x, y, XMSoul.getFloatAttr(node, "width", 280), XMSoul.getAttr(node, "text", ""), XMSoul.getIntAttr(node, "size", 12));
                txt.setFormat(Paths.font("vcr"), XMSoul.getIntAttr(node, "size", 12), FlxColor.fromString(XMSoul.getAttr(node, "color", "0xFFFFFFFF")), LEFT);
                if (id != "") elements.set(id, txt);
                return txt;

            case "button":
                var btn = new EditorButton(x, y, XMSoul.getIntAttr(node, "width", 120), XMSoul.getIntAttr(node, "height", 26), XMSoul.getAttr(node, "text", "Button"), function() {
                    triggerAction(action);
                });
                if (id != "") elements.set(id, btn);
                return btn;

            case "checkbox":
                var chk = new EditorCheckbox(x, y, XMSoul.getAttr(node, "label", "Check"), XMSoul.getBoolAttr(node, "checked", false), function(val) {
                    if (script != null) script.callAll(action, [val]);
                });
                if (id != "") elements.set(id, chk);
                return chk;

            case "stepper":
                var stp = new EditorNumericStepper(
                    x, y, XMSoul.getIntAttr(node, "width", 140),
                    XMSoul.getAttr(node, "label", "Value"),
                    XMSoul.getFloatAttr(node, "min", 0),
                    XMSoul.getFloatAttr(node, "min", 0),
                    XMSoul.getFloatAttr(node, "max", 100),
                    XMSoul.getFloatAttr(node, "step", 1),
                    XMSoul.getIntAttr(node, "precision", 0),
                    function(val) {
                        if (script != null) script.callAll(action, [val]);
                    }
                );
                if (id != "") elements.set(id, stp);
                return stp;

            case "input":
                var inp = new EditorInputText(x, y, XMSoul.getIntAttr(node, "width", 280), XMSoul.getAttr(node, "label", "Input"), XMSoul.getAttr(node, "text", ""));
                if (id != "") elements.set(id, inp);
                return inp;
        }
        return null;
    }

    private function parseCards(node:Access):Void {
        var startX = XMSoul.getFloatAttr(node, "x", 50);
        var startY = XMSoul.getFloatAttr(node, "y", 88);
        var spacing = XMSoul.getFloatAttr(node, "spacing", 125);
        var cardW = XMSoul.getFloatAttr(node, "width", 600);
        var cardH = XMSoul.getFloatAttr(node, "height", 110);

        var idx = 0;
        for (cardNode in node.nodes.card) {
            var group = new FlxSpriteGroup(startX, startY + (idx * spacing));
            var border = new FlxSprite(-1, -1).makeGraphic(Std.int(cardW + 2), Std.int(cardH + 2), EditorTheme.PANEL_BORDER);
            var bg = new FlxSprite(0, 0).makeGraphic(Std.int(cardW), Std.int(cardH), EditorTheme.PANEL_BG);
            
            var title = new Alphabet(16, 38, XMSoul.getAttr(cardNode, "title", ""), true);
            title.scale.set(0.75, 0.75);

            var desc = new FlxText(20, 82, cardW - 40, XMSoul.getAttr(cardNode, "desc", ""), 11);
            desc.setFormat(Paths.font("vcr"), 11, EditorTheme.TEXT_MUTED, LEFT);

            group.add(border);
            group.add(bg);
            group.add(title);
            group.add(desc);
            add(group);

            idx++;
        }
    }

    public function triggerAction(action:String):Void {
        if (action.startsWith("openEditor:")) {
            var target = action.split(":")[1];
            switch (target) {
                case "actor": MusicBeatState.switchState(new XMSoulState("config/ui/menus/actorStudio.xmsoul"));
                case "modchart": MusicBeatState.switchState(new XMSoulState("config/ui/menus/modchartMatrix.xmsoul"));
            }
            return;
        }

        if (script != null) {
            script.callAll(action, []);
        }
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        if (script != null) script.callAll("onUpdate", [elapsed]);
    }
}