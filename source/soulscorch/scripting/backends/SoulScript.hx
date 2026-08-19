package soulscorch.scripting.backends;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.ui.FlxBar;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import hscript.Interp;
import hscript.Parser;
import openfl.filters.ShaderFilter;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.input.Controls;
import soulscorch.backend.system.EventBus;
import soulscorch.backend.utils.Logger;
import soulscorch.graphics.shaders.SoulShader;
import soulscorch.scripting.ScriptInstance;
import soulscorch.scripting.mod.ModCustomState;
import soulscorch.scripting.mod.ModManager;
import soulscorch.scripting.mod.SoulGlobalScript;

using StringTools;

class SoulScript implements ScriptInstance {
    public var active:Bool = false;
    public var path(default, null):String;

    public var uiElements:Map<String, FlxSprite> = new Map<String, FlxSprite>();
    private var interp:Interp;

    public function new(scriptPath:String) {
        this.path = (scriptPath == null) ? "" : scriptPath;
        load();
    }

    public function load():Bool {
        var fullPath = ModManager.getPath(path);
        if (!AssetResolver.exists(fullPath)) {
            active = false;
            return false;
        }

        try {
            var rawText = AssetResolver.getText(fullPath);
            initScript(rawText);
            
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

    private function initScript(code:String):Void {
        var sanitized = preprocessScript(code);
        var parser = new Parser();
        parser.allowTypes = true;
        parser.allowJSON = true;
        var program = parser.parseString(sanitized);

        interp = new Interp();
        interp.variables.set("FlxG", FlxG);
        interp.variables.set("FlxSprite", FlxSprite);
        interp.variables.set("FlxText", FlxText);
        interp.variables.set("FlxBar", FlxBar);
        interp.variables.set("FlxMath", FlxMath);
        interp.variables.set("FlxTween", FlxTween);
        interp.variables.set("FlxEase", FlxEase);
        interp.variables.set("Conductor", Conductor);
        interp.variables.set("Paths", Paths);
        interp.variables.set("AssetHelper", AssetHelper);
        interp.variables.set("AssetResolver", AssetResolver);
        interp.variables.set("Controls", Controls.instance);
        interp.variables.set("SoulShader", SoulShader);

        interp.variables.set("ShaderFilter", function(shaderOrFilter:Dynamic) {
            if (Std.isOfType(shaderOrFilter, ShaderFilter)) {
                return shaderOrFilter;
            } else if (Std.isOfType(shaderOrFilter, SoulShader)) {
                var s:SoulShader = cast shaderOrFilter;
                return s.filter;
            } else if (Std.isOfType(shaderOrFilter, flixel.system.FlxAssets.FlxShader)) {
                return new ShaderFilter(cast shaderOrFilter);
            }
            return null;
        });

        interp.variables.set("FlxColor", {
            WHITE: 0xFFFFFFFF, BLACK: 0xFF000000, RED: 0xFFFF0000,
            GREEN: 0xFF00FF00, BLUE: 0xFF0000FF, CYAN: 0xFF00FFFF,
            MAGENTA: 0xFFFF00FF, YELLOW: 0xFFFFFF00, TRANSPARENT: 0x00000000,
            fromRGB: FlxColor.fromRGB, fromString: FlxColor.fromString
        });

        interp.variables.set("lerp", function(a:Float, b:Float, ratio:Float):Float return FlxMath.lerp(a, b, ratio));
        interp.variables.set("getElement", function(id:String):Null<FlxSprite> return uiElements.get(id));
        interp.variables.set("openURL", function(url:String):Void FlxG.openURL(url));
        interp.variables.set("trace", function(v:Dynamic):Void Logger.info(Std.string(v), "soulscript"));

        interp.variables.set("add", function(obj:Dynamic):Void {
            if (FlxG.state != null) FlxG.state.add(obj);
        });

        interp.variables.set("remove", function(obj:Dynamic):Void {
            if (FlxG.state != null) FlxG.state.remove(obj);
        });

        interp.variables.set("switchState", function(target:Dynamic):Void {
            if (Std.isOfType(target, String)) {
                var targetName:String = cast target;
                var redirect = SoulGlobalScript.getRedirect(targetName);
                if (redirect != null) {
                    MusicBeatState.switchState(new ModCustomState(redirect));
                } else {
                    switch (targetName.toLowerCase()) {
                        case "mainmenustate" | "mainmenu": MusicBeatState.switchState(new soulscorch.ui.menus.states.MainMenuState());
                        case "titlestate" | "title": MusicBeatState.switchState(new soulscorch.ui.menus.states.TitleState());
                        case "freeplaystate" | "freeplay": MusicBeatState.switchState(new soulscorch.ui.menus.states.FreeplayState());
                        case "storymenustate" | "storymenu": MusicBeatState.switchState(new soulscorch.ui.menus.states.StoryMenuState());
                        case "optionsstate" | "optionsmenustate": MusicBeatState.switchState(new soulscorch.ui.menus.option.OptionsMenuState());
                        case "creditsstate" | "credits": MusicBeatState.switchState(new soulscorch.ui.menus.credits.CreditsState());
                        default: MusicBeatState.switchState(new ModCustomState(targetName));
                    }
                }
            } else {
                MusicBeatState.switchState(target);
            }
        });

        interp.execute(program);
    }

    private function preprocessScript(code:String):String {
        var rPackage = ~/package\s+[\w\.]*;/g;
        code = rPackage.replace(code, "");

        var rImport = ~/import\s+[\w\.\*]+;/g;
        code = rImport.replace(code, "");

        var rModifiers = ~/\b(public|private|static|override)\s+(var|function)\b/g;
        code = rModifiers.replace(code, "$2");

        return code;
    }

    private function parseXML(rawXml:String):Void {
        if (rawXml.length == 0) return;
        try {
            var xml = Xml.parse(rawXml).firstElement();
            if (xml.get("bgColor") != null) {
                var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.fromString(xml.get("bgColor")));
                bg.scrollFactor.set();
                if (FlxG.state != null) FlxG.state.add(bg);
            }

            for (node in xml.elements()) {
                var nodeName = node.nodeName.toLowerCase();
                var id = node.get("id");
                var xPos = (node.get("x") != null) ? Std.parseFloat(node.get("x")) : 0.0;
                var yPos = (node.get("y") != null) ? Std.parseFloat(node.get("y")) : 0.0;
                var scaleVal = (node.get("scale") != null) ? Std.parseFloat(node.get("scale")) : 1.0;
                var alphaVal = (node.get("alpha") != null) ? Std.parseFloat(node.get("alpha")) : 1.0;

                switch (nodeName) {
                    case "sprite":
                        var spr = new FlxSprite(xPos, yPos);
                        var img = node.get("image");
                        if (img != null) AssetHelper.loadImageSafely(spr, img);
                        spr.scale.set(scaleVal, scaleVal);
                        spr.updateHitbox();
                        spr.alpha = alphaVal;
                        if (id != null) uiElements.set(id, spr);
                        if (FlxG.state != null) FlxG.state.add(spr);

                    case "text":
                        var content = (node.get("content") != null) ? node.get("content") : "";
                        var size = (node.get("size") != null) ? Std.parseInt(node.get("size")) : 16;
                        var width = (node.get("width") != null) ? Std.parseFloat(node.get("width")) : 0;
                        var txt = new FlxText(xPos, yPos, width, content, size);
                        var col = (node.get("color") != null) ? FlxColor.fromString(node.get("color")) : FlxColor.WHITE;
                        txt.setFormat(Paths.font("vcr"), size, col, LEFT);
                        txt.alpha = alphaVal;
                        if (id != null) uiElements.set(id, txt);
                        if (FlxG.state != null) FlxG.state.add(txt);

                    case "button":
                        var w = (node.get("width") != null) ? Std.parseInt(node.get("width")) : 100;
                        var h = (node.get("height") != null) ? Std.parseInt(node.get("height")) : 40;
                        var onClickName = node.get("onClick");

                        var btn = new FlxButton(xPos, yPos, "", function() {
                            if (onClickName != null) call(onClickName, []);
                        });
                        btn.makeGraphic(w, h, FlxColor.TRANSPARENT);
                        btn.alpha = alphaVal;
                        if (id != null) uiElements.set(id, btn);
                        if (FlxG.state != null) FlxG.state.add(btn);
                }
            }
        } catch (e:Dynamic) {
            Logger.error('SoulScript XML layout parsing error: $e', "soulscript");
        }
    }

    public function call(func:String, ?args:Array<Dynamic>):Dynamic {
        if (interp != null && interp.variables.exists(func)) {
            var fn = interp.variables.get(func);
            if (Reflect.isFunction(fn)) {
                return Reflect.callMethod(null, fn, (args != null) ? args : []);
            }
        }
        return null;
    }

    public function set(key:String, value:Dynamic):Void {
        if (interp != null) interp.variables.set(key, value);
    }

    public function get(key:String):Dynamic {
        if (interp != null && interp.variables.exists(key)) return interp.variables.get(key);
        if (uiElements.exists(key)) return uiElements.get(key);
        return null;
    }

    public function destroy():Void {
        active = false;
        call("onDestroy", []);
        uiElements.clear();
        interp = null;
    }
}