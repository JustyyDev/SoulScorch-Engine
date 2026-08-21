package soulscorch.ui;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import haxe.xml.Access;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.system.Scene;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.ScriptManager;
import soulscorch.ui.hud.Alphabet;

using StringTools;

class XMLState extends Scene {
    public var xmlPath:String;
    public var uiElements:Map<String, Dynamic> = new Map<String, Dynamic>();
    public var scripts:ScriptManager;

    public function new(xmlFile:String) {
        super();
        this.xmlPath = (xmlFile != null) ? xmlFile.trim() : "";
    }

    override public function create():Void {
        super.create();
        scripts = new ScriptManager();
        initScript();
        parseXML();
        if (scripts != null) scripts.callAll("onCreatePost");
    }

    private function initScript():Void {
        var clean = xmlPath;
        if (clean.endsWith(".xml")) clean = clean.substr(0, clean.length - 4);

        var scriptCandidates = [
            'data/ui/$clean',
            'ui/$clean',
            clean
        ];

        for (candidate in scriptCandidates) {
            var resolved = AssetResolver.resolveFile(candidate, [".soul", ".hx", ".lua", ".py", ".js"]);
            if (resolved != null) {
                scripts.loadScript(resolved);
            }
        }
        scripts.setAll("state", this);
        scripts.setAll("ui", this);
        scripts.setAll("getElement", getElement);
        scripts.callAll("onCreate");
    }

    private function parseXML():Void {
        var clean = xmlPath;
        if (clean.endsWith(".xml")) clean = clean.substr(0, clean.length - 4);

        var xmlCandidates = [
            'data/ui/$clean',
            'ui/$clean',
            clean
        ];

        var resolvedPath:String = null;
        for (candidate in xmlCandidates) {
            resolvedPath = AssetResolver.resolveFile(candidate, [".xml", ".xmsoul", ""]);
            if (resolvedPath != null) break;
        }

        if (resolvedPath == null) {
            Logger.error('XML UI file not found: $xmlPath', "xml");
            var errorText = new FlxText(0, 0, FlxG.width, 'MISSING XML: $xmlPath', 28);
            errorText.setFormat(Paths.font("vcr"), 28, FlxColor.RED, CENTER, OUTLINE, FlxColor.BLACK);
            errorText.screenCenter();
            add(errorText);
            return;
        }

        try {
            var rawXml = AssetResolver.getText(resolvedPath);
            var parsed = Xml.parse(rawXml);
            var xmlData = parsed.firstElement();
            if (xmlData == null) return;
            var access = new Access(xmlData);

            if (access.has.bgColor) {
                var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.fromString(access.att.bgColor));
                bg.scrollFactor.set(0, 0);
                add(bg);
            }

            for (node in access.elements) {
                buildElement(node);
            }
        } catch (e:Dynamic) {
            Logger.error('Failed parsing XML UI ($xmlPath): $e', "xml");
        }
    }

    private function buildElement(node:Access):Void {
        var id:String = node.has.id ? node.att.id : "element_" + Std.random(99999);
        var x:Float = node.has.x ? Std.parseFloat(node.att.x) : 0.0;
        var y:Float = node.has.y ? Std.parseFloat(node.att.y) : 0.0;
        var alphaVal:Float = node.has.alpha ? Std.parseFloat(node.att.alpha) : 1.0;
        var scaleVal:Float = node.has.scale ? Std.parseFloat(node.att.scale) : 1.0;

        switch (node.name.toLowerCase()) {
            case "sprite":
                var sprite = new FlxSprite(x, y);
                if (node.has.image) {
                    AssetHelper.loadGraphicSafely(sprite, node.att.image);
                }
                sprite.scale.set(scaleVal, scaleVal);
                sprite.updateHitbox();
                sprite.alpha = alphaVal;
                if (node.has.antialiasing) sprite.antialiasing = (node.att.antialiasing == "true");
                if (node.has.color) sprite.color = FlxColor.fromString(node.att.color);

                uiElements.set(id, sprite);
                add(sprite);

            case "animatedsprite":
                var animSpr = new FlxSprite(x, y);
                if (node.has.image) {
                    AssetHelper.loadSparrowSafely(animSpr, node.att.image);
                }
                if (node.hasNode.anim) {
                    for (anim in node.nodes.anim) {
                        var name = anim.att.name;
                        var prefix = anim.att.prefix;
                        var fps = anim.has.fps ? Std.parseInt(anim.att.fps) : 24;
                        var loop = anim.has.loop ? (anim.att.loop == "true") : true;
                        animSpr.animation.addByPrefix(name, prefix, fps, loop);
                    }
                }
                if (node.has.firstAnim) {
                    animSpr.animation.play(node.att.firstAnim);
                }
                animSpr.scale.set(scaleVal, scaleVal);
                animSpr.updateHitbox();
                animSpr.alpha = alphaVal;
                uiElements.set(id, animSpr);
                add(animSpr);

            case "box":
                var w:Int = node.has.width ? Std.parseInt(node.att.width) : 100;
                var h:Int = node.has.height ? Std.parseInt(node.att.height) : 100;
                var col:FlxColor = node.has.color ? FlxColor.fromString(node.att.color) : FlxColor.WHITE;
                var box = new FlxSprite(x, y).makeGraphic(w, h, col);
                box.alpha = alphaVal;
                uiElements.set(id, box);
                add(box);

            case "alphabet":
                var text = node.has.text ? node.att.text : "";
                var bold = node.has.bold ? (node.att.bold == "true") : false;
                var alpha = new Alphabet(x, y, text, bold);
                alpha.alpha = alphaVal;
                uiElements.set(id, alpha);
                add(alpha);

            case "text":
                var content = node.has.text ? node.att.text : "";
                var size = node.has.size ? Std.parseInt(node.att.size) : 18;
                var fontName = node.has.font ? node.att.font : "vcr";
                var textObj = new FlxText(x, y, node.has.width ? Std.parseFloat(node.att.width) : 0, content, size);
                textObj.setFormat(Paths.font(fontName), size, node.has.color ? FlxColor.fromString(node.att.color) : FlxColor.WHITE);
                textObj.alpha = alphaVal;
                uiElements.set(id, textObj);
                add(textObj);

            case "button":
                var label = node.has.label ? node.att.label : "";
                var onClickHook = node.has.onClick ? node.att.onClick : id + "_onClick";
                var button = new FlxButton(x, y, label, function() {
                    callScript(onClickHook);
                });
                button.alpha = alphaVal;
                uiElements.set(id, button);
                add(button);
        }
    }

    public function getElement<T>(id:String):Null<T> {
        return cast uiElements.get(id);
    }

    public function callScript(func:String, ?args:Array<Dynamic>):Dynamic {
        if (scripts != null) return scripts.callAll(func, args);
        return null;
    }

    override public function update(elapsed:Float):Void {
        callScript("onUpdate", [elapsed]);
        super.update(elapsed);
        callScript("onUpdatePost", [elapsed]);
    }

    override public function destroy():Void {
        callScript("onDestroy");
        if (scripts != null) {
            scripts.clear();
            scripts = null;
        }
        uiElements.clear();
        super.destroy();
    }
}