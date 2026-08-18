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
import soulscorch.scripting.Script;
import soulscorch.scripting.mod.ModLoader;
import soulscorch.ui.hud.Alphabet;

class XMLState extends Scene {
    public var xmlPath:String;
    public var uiElements:Map<String, Dynamic> = new Map();
    public var script:Script;

    public function new(xmlFile:String) {
        super();
        this.xmlPath = xmlFile != null ? xmlFile : "";
    }

    override public function create():Void {
        super.create();
        initScript();
        parseXML();
        callScript("onCreatePost");
    }

    private function initScript():Void {
        var scriptPath = 'data/ui/$xmlPath.hx';
        var resolved = ModLoader.getPath(scriptPath);

        if (AssetResolver.exists(resolved)) {
            script = new Script(resolved);
            script.set("state", this);
            script.set("ui", this);
            script.set("getElement", getElement);
            script.call("onCreate");
        }
    }

    private function parseXML():Void {
        var resolvedPath = ModLoader.getPath('data/ui/$xmlPath.xml');
        if (!AssetResolver.exists(resolvedPath)) {
            resolvedPath = ModLoader.getPath('assets/data/ui/$xmlPath.xml');
        }

        if (!AssetResolver.exists(resolvedPath)) {
            Logger.error('XML UI file not found: $resolvedPath', "xml");
            var errorText = new FlxText(0, 0, FlxG.width, 'MISSING XML: $xmlPath', 28);
            errorText.setFormat(Paths.font("vcr"), 28, FlxColor.RED, CENTER);
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
                add(bg);
            }

            for (node in access.elements) {
                buildElement(node);
            }
        } catch (e:Dynamic) {
            Logger.error('Failed to parse XML UI ($xmlPath): $e', "xml");
        }
    }

    private function buildElement(node:Access):Void {
        var id:String = node.has.id ? node.att.id : "element_" + Std.random(9999);
        var x:Float = node.has.x ? Std.parseFloat(node.att.x) : 0.0;
        var y:Float = node.has.y ? Std.parseFloat(node.att.y) : 0.0;

        switch (node.name.toLowerCase()) {
            case "sprite":
                var sprite = new FlxSprite(x, y);
                if (node.has.image) {
                    AssetHelper.loadGraphicSafely(sprite, node.att.image);
                }
                if (node.has.scale) {
                    var sc = Std.parseFloat(node.att.scale);
                    sprite.scale.set(sc, sc);
                    sprite.updateHitbox();
                }
                if (node.has.alpha) sprite.alpha = Std.parseFloat(node.att.alpha);
                if (node.has.antialiasing) sprite.antialiasing = (node.att.antialiasing == "true");

                uiElements.set(id, sprite);
                add(sprite);

            case "animatedsprite":
                var animSpr = new FlxSprite(x, y);
                if (node.has.image) {
                    AssetHelper.loadSparrowSafely(animSpr, node.att.image);
                }
                if (node.has.anim) {
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
                uiElements.set(id, animSpr);
                add(animSpr);

            case "alphabet":
                var text = node.has.text ? node.att.text : "";
                var bold = node.has.bold ? (node.att.bold == "true") : false;
                var alpha = new Alphabet(x, y, text, bold);
                uiElements.set(id, alpha);
                add(alpha);

            case "text":
                var content = node.has.text ? node.att.text : "";
                var size = node.has.size ? Std.parseInt(node.att.size) : 18;
                var textObj = new FlxText(x, y, node.has.width ? Std.parseFloat(node.att.width) : 0, content, size);
                textObj.setFormat(Paths.font("vcr"), size, node.has.color ? FlxColor.fromString(node.att.color) : FlxColor.WHITE);
                uiElements.set(id, textObj);
                add(textObj);

            case "button":
                var label = node.has.label ? node.att.label : "";
                var onClickHook = node.has.onClick ? node.att.onClick : id + "_onClick";
                var button = new FlxButton(x, y, label, function() {
                    callScript(onClickHook);
                });
                uiElements.set(id, button);
                add(button);
        }
    }

    public function getElement<T>(id:String):Null<T> {
        return cast uiElements.get(id);
    }

    public function callScript(func:String, ?args:Array<Dynamic>):Dynamic {
        if (script != null && script.active) {
            return script.call(func, args);
        }
        return null;
    }

    override public function update(elapsed:Float):Void {
        callScript("onUpdate", [elapsed]);
        super.update(elapsed);
        callScript("onUpdatePost", [elapsed]);
    }

    override public function destroy():Void {
        callScript("onDestroy");
        if (script != null) {
            script.destroy();
            script = null;
        }
        uiElements.clear();
        super.destroy();
    }
}