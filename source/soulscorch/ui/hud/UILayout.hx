package soulscorch.ui.hud;

import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import haxe.xml.Access;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.utils.ColorUtil;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.mod.ModManager;

class UILayout extends FlxGroup {
    public var sprites:Map<String, FlxSprite> = new Map<String, FlxSprite>();
    public var alphabets:Map<String, Alphabet> = new Map<String, Alphabet>();
    private var unnamedCount:Int = 0;

    public function new(xmlPath:String) {
        super();
        if (xmlPath != null && xmlPath.length > 0) {
            loadLayout(xmlPath);
        }
    }

    public function loadLayout(localPath:String):Void {
        var resolvedPath = ModManager.getPath(localPath);

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
                    var imgPath = node.att.image;
                    AssetHelper.loadGraphicSafely(spr, imgPath);
                }

                if (node.has.scale) {
                    var s = Std.parseFloat(node.att.scale);
                    spr.scale.set(s, s);
                    spr.updateHitbox();
                }

                if (node.has.alpha) spr.alpha = Std.parseFloat(node.att.alpha);
                if (node.has.width && node.has.height) {
                    spr.setGraphicSize(Std.parseInt(node.att.width), Std.parseInt(node.att.height));
                    spr.updateHitbox();
                }
                if (node.has.antialiasing) spr.antialiasing = (node.att.antialiasing == "true");

                sprites.set(id, spr);
                add(spr);

            case "box":
                var w:Int = node.has.width ? Std.parseInt(node.att.width) : 100;
                var h:Int = node.has.height ? Std.parseInt(node.att.height) : 100;
                var col:FlxColor = node.has.color ? ColorUtil.fromHexSafe(node.att.color, FlxColor.WHITE) : FlxColor.WHITE;
                var box = new FlxSprite(x, y).makeGraphic(w, h, col);
                sprites.set(id, box);
                add(box);

            case "alphabet":
                var text = node.has.text ? node.att.text : "";
                var isBold = node.has.bold ? (node.att.bold == "true") : false;

                var alpha = new Alphabet(x, y, text, isBold);
                if (node.has.scale) {
                    var s = Std.parseFloat(node.att.scale);
                    alpha.scale.set(s, s);
                }
                if (node.has.align) alpha.alignment = cast node.att.align;
                alphabets.set(id, alpha);
                add(alpha);

            case "text":
                var content = node.has.text ? node.att.text : "";
                var size = node.has.size ? Std.parseInt(node.att.size) : 16;
                var width = node.has.width ? Std.parseFloat(node.att.width) : 0;
                var color = node.has.color ? ColorUtil.fromHexSafe(node.att.color, FlxColor.WHITE) : FlxColor.WHITE;
                var txt = new FlxText(x, y, width, content, size);
                txt.setFormat(Paths.font(node.has.font ? node.att.font : "vcr"), size, color);
                sprites.set(id, cast txt);
                add(txt);
        }
    }

    public function getSprite(id:String):Null<FlxSprite> {
        return sprites.get(id);
    }

    public function getAlphabet(id:String):Null<Alphabet> {
        return alphabets.get(id);
    }
}