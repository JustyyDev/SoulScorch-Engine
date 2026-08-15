package soulscorch.ui;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import soulscorch.core.Scene;
import soulscorch.assets.AssetResolver;
import soulscorch.modding.ModLoader;
import soulscorch.assets.AssetHelper;
import haxe.xml.Access;

class XMLState extends Scene {
    public var xmlPath:String;
    public var uiElements:Map<String, Dynamic>;

    public function new(xmlFile:String) {
        super();
        this.xmlPath = xmlFile;
        this.uiElements = new Map<String, Dynamic>();
    }

    override public function create():Void {
        super.create();
        parseXML();
    }

    private function parseXML():Void {
        var resolvedPath = ModLoader.getPath('assets/data/ui/' + xmlPath + '.xml');
        
        if (!AssetResolver.exists(resolvedPath)) {
            Sys.println('[ERROR] XML UI file not found: $resolvedPath');
            var errorText = new FlxText(0, 0, FlxG.width, 'MISSING XML: $xmlPath', 32);
            errorText.screenCenter();
            errorText.color = FlxColor.RED;
            add(errorText);
            return;
        }

        try {
            var rawXml = AssetResolver.getText(resolvedPath);
            var xmlData = Xml.parse(rawXml).firstElement();
            var access = new Access(xmlData);

            for (node in access.elements) {
                buildElement(node);
            }
        } catch (e:Dynamic) {
            Sys.println('[ERROR] Failed to parse XML UI $xmlPath: $e');
        }
    }

    private function buildElement(node:Access):Void {
        var id = node.has.id ? node.att.id : "element_" + Std.random(9999);
        var x:Float = node.has.x ? Std.parseFloat(node.att.x) : 0;
        var y:Float = node.has.y ? Std.parseFloat(node.att.y) : 0;
        
        switch (node.name.toLowerCase()) {
            case "sprite":
                var sprite = new FlxSprite(x, y);
                if (node.has.image) {
                    AssetHelper.loadGraphicSafely(sprite, 'assets/images/' + node.att.image + '.png');
                }
                if (node.has.scale) {
                    var sc = Std.parseFloat(node.att.scale);
                    sprite.scale.set(sc, sc);
                    sprite.updateHitbox();
                }
                if (node.has.antialiasing) {
                    sprite.antialiasing = node.att.antialiasing == "true";
                }
                uiElements.set(id, sprite);
                add(sprite);

            case "text":
                var content = node.has.text ? node.att.text : "";
                var size = node.has.size ? Std.parseInt(node.att.size) : 16;
                var textObj = new FlxText(x, y, 0, content, size);
                if (node.has.color) {
                    textObj.color = Std.parseInt(node.att.color);
                }
                uiElements.set(id, textObj);
                add(textObj);
                
            case "alphabet":
                var content = node.has.text ? node.att.text : "";
                var isBold = node.has.bold ? (node.att.bold == "true") : false;
                var alphaObj = new Alphabet(x, y, content, isBold);
                uiElements.set(id, alphaObj);
                add(alphaObj);
        }
    }

    public function getElement(id:String):Dynamic {
        return uiElements.get(id);
    }
}