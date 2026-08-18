package soulscorch.scripting.backends;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import haxe.xml.Parser;
import haxe.xml.Access;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.system.EventBus;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.mod.ModLoader;
import soulscorch.scripting.ScriptInstance;

class SoulScript implements ScriptInstance {
    public var active:Bool = false;
    public var path(default, null):String;

    public var variables:Map<String, Dynamic> = new Map();
    public var uiElements:Map<String, Dynamic> = new Map();
    public var customCallbacks:Map<String, String> = new Map();
    
    private var rawLines:Array<String> = [];

    public function new(scriptPath:String) {
        this.path = (scriptPath == null) ? "" : scriptPath;
        load();
    }

    public function load():Bool {
        var fullPath = ModLoader.getPath(path);
        if (!AssetResolver.exists(fullPath)) {
            active = false;
            return false;
        }

        try {
            var rawText = AssetResolver.getText(fullPath);
            parseScript(rawText);
            
            // Automatically look for and parse a matching XML layout file if available
            var xmlPath = fullPath.substr(0, fullPath.lastIndexOf(".")) + ".xml";
            if (AssetResolver.exists(xmlPath)) {
                parseXML(AssetResolver.getText(xmlPath));
            }

            active = true;
            call("create");
            call("onCreate");
            return true;
        } catch (e:Dynamic) {
            Logger.error('Failed to initialize SoulScript ($path): $e', "soulscript");
            active = false;
            return false;
        }
    }

    private function parseScript(raw:String):Void {
        rawLines = [];
        var lines = raw.split("\n");
        for (i in 0...lines.length) {
            var line = StringTools.trim(lines[i]);
            if (line.length == 0 || StringTools.startsWith(line, "//") || StringTools.startsWith(line, "#")) continue;
            rawLines.push(line);
        }
    }

    private function parseXML(rawXml:String):Void {
        try {
            var xml = Parser.parse(rawXml);
            var fast = new Access(xml.firstElement());

            if (fast.has.bgColor) {
                FlxG.camera.bgColor = FlxColor.fromString(fast.att.bgColor);
            }

            for (node in fast.elements) {
                var id = node.has.id ? node.att.id : "unnamed_" + Std.random(99999);
                var x = node.has.x ? Std.parseFloat(node.att.x) : 0;
                var y = node.has.y ? Std.parseFloat(node.att.y) : 0;
                var alpha = node.has.alpha ? Std.parseFloat(node.att.alpha) : 1.0;
                var scale = node.has.scale ? Std.parseFloat(node.att.scale) : 1.0;
                var antialiasing = node.has.antialiasing ? (node.att.antialiasing == "true") : true;

                switch (node.name.toLowerCase()) {
                    case "sprite":
                        var spr = new FlxSprite(x, y);
                        if (node.has.image) {
                            AssetHelper.loadGraphicSafely(spr, node.att.image);
                        }
                        spr.scale.set(scale, scale);
                        spr.updateHitbox();
                        spr.alpha = alpha;
                        spr.antialiasing = antialiasing;
                        
                        if (FlxG.state != null) FlxG.state.add(spr);
                        uiElements.set(id, spr);

                    case "button":
                        var width = node.has.width ? Std.parseFloat(node.att.width) : 100;
                        var height = node.has.height ? Std.parseFloat(node.att.height) : 50;
                        var btn = new FlxSprite(x, y).makeGraphic(Std.int(width), Std.int(height), 0x00000000);
                        btn.alpha = alpha;

                        if (node.has.onClick) {
                            customCallbacks.set(id, node.att.onClick);
                        }

                        if (FlxG.state != null) FlxG.state.add(btn);
                        uiElements.set(id, btn);
                }
            }
        } catch (e:Dynamic) {
            Logger.error('SoulScript XML layout parsing error: $e', "soulscript");
        }
    }

    public function call(func:String, ?args:Array<Dynamic>):Dynamic {
        var targetFunc = func.toLowerCase();
        
        for (line in rawLines) {
            if (StringTools.startsWith(line.toLowerCase(), 'on $targetFunc') || StringTools.startsWith(line.toLowerCase(), '$targetFunc:')) {
                // Execute basic embedded macro commands matching this state hook
                executeMacroBlock(targetFunc);
                return true;
            }
        }
        return null;
    }

    private function executeMacroBlock(blockName:String):Void {
        // Simple internal hook runner for custom layout scripting
        if (blockName == "create" || blockName == "oncreate") {
            for (id in uiElements.keys()) {
                var el = uiElements.get(id);
                if (Std.isOfType(el, FlxSprite) && blockName == "create") {
                    // Pre-configured hooks can trigger here
                }
            }
        }
    }

    public function set(key:String, value:Dynamic):Void {
        variables.set(key, value);
    }

    public function get(key:String):Dynamic {
        if (variables.exists(key)) return variables.get(key);
        if (uiElements.exists(key)) return uiElements.get(key);
        return null;
    }

    public function destroy():Void {
        active = false;
        variables.clear();
        uiElements.clear();
        customCallbacks.clear();
        rawLines = [];
    }
}