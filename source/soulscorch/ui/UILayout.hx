package soulscorch.ui;

import flixel.FlxSprite;
import flixel.group.FlxGroup;
import haxe.xml.Access;
import soulscorch.modding.ModManager;
import soulscorch.core.Logger;
#if sys
import sys.io.File;
import sys.FileSystem;
#end

class UILayout extends FlxGroup {
    public var sprites:Map<String, FlxSprite> = new Map();
    private var unnamedCount:Int = 0; // Added counter for unnamed sprites

    public function new(xmlPath:String) {
        super();
        loadLayout(xmlPath);
    }

    public function loadLayout(localPath:String):Void {
        var fullPath = ModManager.getPath(localPath);
        
        #if sys
        if (!FileSystem.exists(fullPath)) {
            Logger.error("ui", 'Layout missing: ' + fullPath);
            return;
        }

        var rawXml = File.getContent(fullPath);
        var parsed = Xml.parse(rawXml);
        var access = new Access(parsed.firstElement());

        for (node in access.elements) {
            parseNode(node);
        }
        #end
    }

    private function parseNode(node:Access):Void {
        var type = node.name;
        // Replaced iterator length with our own integer counter
        var id = node.has.id ? node.att.id : "unnamed_" + (unnamedCount++);
        
        var x:Float = node.has.x ? Std.parseFloat(node.att.x) : 0;
        var y:Float = node.has.y ? Std.parseFloat(node.att.y) : 0;

        if (type == "sprite") {
            var spr = new FlxSprite(x, y);
            
            if (node.has.image) {
                var imgPath = ModManager.getPath('images/' + node.att.image + '.png');
                spr.loadGraphic(imgPath);
            }
            
            if (node.has.scale) {
                var s = Std.parseFloat(node.att.scale);
                spr.scale.set(s, s);
                spr.updateHitbox();
            }

            if (node.has.alpha) spr.alpha = Std.parseFloat(node.att.alpha);
            if (node.has.antialiasing) spr.antialiasing = (node.att.antialiasing == "true");

            sprites.set(id, spr);
            add(spr);
        } 
        else if (type == "alphabet") {
            var text = node.has.text ? node.att.text : "";
            var isBold = node.has.bold ? (node.att.bold == "true") : false;
            
            var alpha = new Alphabet(x, y, text, isBold);
            add(alpha);
            
            // Storing the first letter as reference in the map just in case
            if (alpha.members.length > 0) sprites.set(id, alpha.members[0]);
        }
    }
}