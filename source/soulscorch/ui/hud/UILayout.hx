package soulscorch.ui.hud;

import flixel.FlxSprite;
import flixel.group.FlxGroup;
import haxe.xml.Access;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.ModLoader;

class UILayout extends FlxGroup {
    public var sprites:Map<String, FlxSprite> = new Map();
    public var alphabets:Map<String, Alphabet> = new Map();
    private var unnamedCount:Int = 0;

    public function new(xmlPath:String) {
        super();
        loadLayout(xmlPath);
    }

    public function loadLayout(localPath:String):Void {
        var resolvedPath = ModLoader.getPath(localPath);

        if (!AssetResolver.exists(resolvedPath)) {
            Logger.error('Layout XML missing at path: $resolvedPath', "ui");
            return;
        }

        try {
            var rawXml = AssetResolver.getText(resolvedPath);
            var parsed = Xml.parse(rawXml);
            var access = new Access(parsed.firstElement());

            for (node in access.elements) {
                parseNode(node);
            }
        } catch (e:Dynamic) {
            Logger.error('Failed to parse Layout XML ($localPath): $e', "ui");
        }
    }

    private function parseNode(node:Access):Void {
        var type = node.name.toLowerCase();
        var id = node.has.id ? node.att.id : "unnamed_" + (unnamedCount++);

        var x:Float = node.has.x ? Std.parseFloat(node.att.x) : 0.0;
        var y:Float = node.has.y ? Std.parseFloat(node.att.y) : 0.0;

        switch (type) {
            case "sprite":
                var spr = new FlxSprite(x, y);

                if (node.has.image) {
                    var imgPath = 'images/' + node.att.image;
                    AssetHelper.loadGraphicSafely(spr, imgPath);
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

            case "alphabet":
                var text = node.has.text ? node.att.text : "";
                var isBold = node.has.bold ? (node.att.bold == "true") : false;

                var alpha = new Alphabet(x, y, text, isBold);
                alphabets.set(id, alpha);
                add(alpha);

                if (alpha.letters.length > 0) {
                    sprites.set(id, alpha.letters[0]);
                }
        }
    }

    public function getSprite(id:String):Null<FlxSprite> {
        return sprites.get(id);
    }

    public function getAlphabet(id:String):Null<Alphabet> {
        return alphabets.get(id);
    }
}