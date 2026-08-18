package soulscorch.scripting.mod;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import hscript.Interp;
import hscript.Parser;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.input.Controls;
import soulscorch.backend.utils.Logger;

using StringTools;

class ModCustomState extends MusicBeatState {
    public var scriptName:String;
    private var interp:Interp;
    private var isScriptLoaded:Bool = false;

    public function new(scriptName:String) {
        super();
        this.scriptName = scriptName;
    }

    override public function create():Void {
        super.create();

        // 1. Check for companion XML UI layout
        var xmlPath = AssetResolver.resolveFile('data/ui/$scriptName.xml');
        if (xmlPath == null) xmlPath = AssetResolver.resolveFile('$scriptName.xml');
        if (xmlPath != null) {
            loadXmlLayout(AssetResolver.getText(xmlPath));
        }

        // 2. Load and execute companion .soul logic
        var soulPath = AssetResolver.resolveFile('data/ui/$scriptName.soul');
        if (soulPath == null) soulPath = AssetResolver.resolveFile('$scriptName.soul');

        if (soulPath != null) {
            var code = AssetResolver.getText(soulPath);
            if (code.length > 0) {
                initScript(code);
            }
        }

        callScriptFunction("create", []);
    }

    private function initScript(code:String):Void {
        try {
            var parser = new Parser();
            parser.allowTypes = true;
            parser.allowJSON = true;
            var program = parser.parseString(code);

            interp = new Interp();
            interp.variables.set("this", this);
            interp.variables.set("FlxG", FlxG);
            interp.variables.set("FlxSprite", FlxSprite);
            interp.variables.set("FlxText", FlxText);
            
            // Expose FlxColor utility methods and presets safely
            interp.variables.set("FlxColor", {
                WHITE: 0xFFFFFFFF,
                BLACK: 0xFF000000,
                RED: 0xFFFF0000,
                GREEN: 0xFF00FF00,
                BLUE: 0xFF0000FF,
                YELLOW: 0xFFFFFF00,
                CYAN: 0xFF00FFFF,
                MAGENTA: 0xFFFF00FF,
                TRANSPARENT: 0x00000000,
                fromRGB: function(r:Int, g:Int, b:Int, a:Int = 255):Int return FlxColor.fromRGB(r, g, b, a),
                fromString: function(str:String):Int return FlxColor.fromString(str)
            });

            interp.variables.set("Paths", Paths);
            interp.variables.set("AssetHelper", AssetHelper);
            interp.variables.set("Controls", Controls.instance);
            interp.variables.set("add", function(obj:Dynamic) add(obj));
            interp.variables.set("remove", function(obj:Dynamic) remove(obj));
            interp.variables.set("switchState", function(target:Dynamic) {
                if (Std.isOfType(target, String)) {
                    MusicBeatState.switchState(new ModCustomState(cast target));
                } else {
                    MusicBeatState.switchState(target);
                }
            });

            interp.execute(program);
            isScriptLoaded = true;
        } catch (e:Dynamic) {
            Logger.error('Error running script ($scriptName.soul): $e', "scripting");
        }
    }

    private function loadXmlLayout(rawXml:String):Void {
        if (rawXml.length == 0) return;
        try {
            var xml = Xml.parse(rawXml).firstElement();
            for (node in xml.elements()) {
                switch (node.nodeName.toLowerCase()) {
                    case "sprite":
                        var spr = new FlxSprite(Std.parseFloat(node.get("x")), Std.parseFloat(node.get("y")));
                        var imageKey = node.get("image");
                        if (imageKey != null) {
                            AssetHelper.loadImageSafely(spr, imageKey);
                        }
                        add(spr);
                    case "box":
                        var box = new FlxSprite(Std.parseFloat(node.get("x")), Std.parseFloat(node.get("y")));
                        var colStr = node.get("color");
                        var colVal:Int = (colStr != null) ? FlxColor.fromString(colStr) : 0xFFFFFFFF;
                        box.makeGraphic(Std.parseInt(node.get("width")), Std.parseInt(node.get("height")), colVal);
                        add(box);
                }
            }
        } catch (e:Dynamic) {
            Logger.error('Failed parsing XML ($scriptName.xml): $e', "xml");
        }
    }

    public function callScriptFunction(funcName:String, args:Array<Dynamic>):Dynamic {
        if (isScriptLoaded && interp != null && interp.variables.exists(funcName)) {
            var fn = interp.variables.get(funcName);
            if (Reflect.isFunction(fn)) {
                return Reflect.callMethod(null, fn, args);
            }
        }
        return null;
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        callScriptFunction("update", [elapsed]);
    }
}