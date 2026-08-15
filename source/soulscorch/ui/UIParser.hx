package soulscorch.ui;

import haxe.xml.Access;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import soulscorch.assets.AssetResolver;
import soulscorch.ui.HealthBar;
import soulscorch.ui.Alphabet;

class UIParser {
    public var uiGroup:FlxTypedGroup<FlxSprite>;
    public var elements:Map<String, Dynamic> = new Map();

    public function new(xmlPath:String) {
        uiGroup = new FlxTypedGroup<FlxSprite>();
        
        var rawXml = AssetResolver.getText(xmlPath);
        if (rawXml != null) {
            parseXml(Xml.parse(rawXml).firstElement());
        }
    }

    private function parseXml(xml:Xml):Void {
        var access = new Access(xml);
        
        for (node in access.elements) {
            var id = node.has.id ? node.att.id : "element_" + Std.random(9999);
            var x = node.has.x ? Std.parseFloat(node.att.x) : 0;
            var y = node.has.y ? Std.parseFloat(node.att.y) : 0;
            
            switch (node.name) {
                case "HealthBar":
                    var p1 = node.has.player1 ? node.att.player1 : "bf";
                    var p2 = node.has.player2 ? node.att.player2 : "dad";
                    var bar = new HealthBar(x, y, p1, p2);
                    elements.set(id, bar);
                    uiGroup.add(bar);
                    
                case "Text":
                    var content = node.has.text ? node.att.text : "";
                    var isBold = node.has.bold ? (node.att.bold == "true") : false;
                    var textObj = new Alphabet(x, y, content, isBold);
                    elements.set(id, textObj);
                    uiGroup.add(textObj);
                    
                case "Sprite":
                    var image = node.has.image ? node.att.image : "";
                    var sprite = new FlxSprite(x, y);
                    if (image != "") sprite.loadGraphic('assets/images/ui/$image.png');
                    elements.set(id, sprite);
                    uiGroup.add(sprite);
            }
        }
    }

    public function getElement<T>(id:String):Null<T> {
        return cast elements.get(id);
    }
}