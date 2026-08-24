package soulscorch.scripting.mod;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import hscript.Interp;
import hscript.Parser;
import openfl.filters.ShaderFilter;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.input.Controls;
import soulscorch.backend.utils.ColorUtil;
import soulscorch.graphics.shaders.SoulShader;
import soulscorch.backend.utils.Logger;

using StringTools;

class ModCustomState extends MusicBeatState {
    public var scriptName:String;
    private var interp:Interp;
    private var isScriptLoaded:Bool = false;
    private var elementsById:Map<String, FlxSprite> = new Map<String, FlxSprite>();

    public function new(scriptName:String) {
        super();
        this.scriptName = scriptName;
    }

    override public function create():Void {
        super.create();

        // 1. Initialize script engine first so event methods and setup are loaded
        var soulPath = AssetResolver.resolveFile('data/ui/$scriptName.soul');
        if (soulPath == null) soulPath = AssetResolver.resolveFile('$scriptName.soul');

        if (soulPath != null) {
            var code = AssetResolver.getText(soulPath);
            if (code != null && code.length > 0) initScript(code);
        }

        // 2. Load companion XML Layout
        var xmlPath = AssetResolver.resolveFile('data/ui/$scriptName.xml');
        if (xmlPath == null) xmlPath = AssetResolver.resolveFile('$scriptName.xml');
        if (xmlPath != null) {
            var xmlText = AssetResolver.getText(xmlPath);
            if (xmlText != null && xmlText.length > 0) loadXmlLayout(xmlText);
        }

        callScriptFunction("create", []);
        callScriptFunction("postCreate", []);
    }

    private function initScript(code:String):Void {
        try {
            var sanitized = preprocessScript(code);

            var parser = new Parser();
            parser.allowTypes = true;
            parser.allowJSON = true;
            var program = parser.parseString(sanitized);

            interp = new Interp();
            interp.variables.set("this", this);
            interp.variables.set("FlxG", FlxG);
            interp.variables.set("FlxSprite", FlxSprite);
            interp.variables.set("FlxText", FlxText);
            interp.variables.set("FlxMath", FlxMath);
            interp.variables.set("FlxTween", FlxTween);
            
            interp.variables.set("FlxEase", {
                quadIn: FlxEase.quadIn,
                quadOut: FlxEase.quadOut,
                quadInOut: FlxEase.quadInOut,
                smoothStepIn: FlxEase.smoothStepIn,
                smoothStepOut: FlxEase.smoothStepOut,
                smoothStepInOut: FlxEase.smoothStepInOut,
                cubeIn: FlxEase.cubeIn,
                cubeOut: FlxEase.cubeOut,
                cubeInOut: FlxEase.cubeInOut,
                sineIn: FlxEase.sineIn,
                sineOut: FlxEase.sineOut,
                sineInOut: FlxEase.sineInOut,
                linear: FlxEase.linear
            });

            interp.variables.set("SoulShader", SoulShader);
            interp.variables.set("ShaderFilter", function(shaderOrFilter:Dynamic) {
                if (Std.isOfType(shaderOrFilter, openfl.filters.ShaderFilter)) {
                    return shaderOrFilter;
                } else if (Std.isOfType(shaderOrFilter, SoulShader)) {
                    var s:SoulShader = cast shaderOrFilter;
                    return s.filter;
                } else if (Std.isOfType(shaderOrFilter, flixel.system.FlxAssets.FlxShader)) {
                    return new openfl.filters.ShaderFilter(cast shaderOrFilter);
                }
                return null;
            });

            interp.variables.set("lerp", function(a:Float, b:Float, ratio:Float):Float return FlxMath.lerp(a, b, ratio));
            interp.variables.set("getElement", function(id:String):Null<FlxSprite> return elementsById.get(id));
            interp.variables.set("openURL", function(url:String):Void FlxG.openURL(url));
            interp.variables.set("trace", function(v:Dynamic):Void Logger.info(Std.string(v), "script-" + scriptName));

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
                fromString: function(str:String):Int return ColorUtil.fromHexSafe(str, FlxColor.WHITE)
            });

            interp.variables.set("Paths", Paths);
            interp.variables.set("AssetHelper", AssetHelper);
            interp.variables.set("AssetResolver", AssetResolver);
            interp.variables.set("Controls", Controls.instance);
            interp.variables.set("add", function(obj:Dynamic) add(obj));
            interp.variables.set("remove", function(obj:Dynamic) remove(obj));
            
            interp.variables.set("switchState", function(target:Dynamic) {
                if (Std.isOfType(target, String)) {
                    var targetName:String = cast target;
                    var redirect:Null<String> = SoulGlobalScript.getRedirect(targetName);
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
            isScriptLoaded = true;
        } catch (e:Dynamic) {
            Logger.error('Error running script ($scriptName.soul): $e', "scripting");
        }
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

    private function loadXmlLayout(rawXml:String):Void {
        if (rawXml.length == 0) return;
        try {
            var xml = Xml.parse(rawXml).firstElement();
            if (xml.get("bgColor") != null) {
                var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, ColorUtil.fromHexSafe(xml.get("bgColor"), FlxColor.BLACK));
                bg.scrollFactor.set();
                add(bg);
            }

            for (node in xml.elements()) {
                var nodeName = node.nodeName.toLowerCase();
                var id = node.get("id");
                var xPos = node.get("x") != null ? Std.parseFloat(node.get("x")) : 0.0;
                var yPos = node.get("y") != null ? Std.parseFloat(node.get("y")) : 0.0;
                var scaleVal = node.get("scale") != null ? Std.parseFloat(node.get("scale")) : 1.0;
                var alphaVal = node.get("alpha") != null ? Std.parseFloat(node.get("alpha")) : 1.0;
                var angleVal = node.get("angle") != null ? Std.parseFloat(node.get("angle")) : 0.0;

                switch (nodeName) {
                    case "sprite":
                        var spr = new FlxSprite(xPos, yPos);
                        var img = node.get("image");
                        if (img != null) AssetHelper.loadImageSafely(spr, img);
                        spr.scale.set(scaleVal, scaleVal);
                        spr.updateHitbox();
                        spr.alpha = alphaVal;
                        spr.angle = angleVal;
                        if (node.get("color") != null) spr.color = ColorUtil.fromHexSafe(node.get("color"), FlxColor.WHITE);
                        if (id != null) elementsById.set(id, spr);
                        add(spr);

                    case "button":
                        var w = node.get("width") != null ? Std.parseInt(node.get("width")) : 100;
                        var h = node.get("height") != null ? Std.parseInt(node.get("height")) : 40;
                        var onClickName = node.get("onClick");

                        var btn = new FlxButton(xPos, yPos, "", function() {
                            if (onClickName != null) callScriptFunction(onClickName, []);
                        });
                        btn.makeGraphic(w, h, FlxColor.TRANSPARENT);
                        btn.alpha = alphaVal;
                        if (id != null) elementsById.set(id, btn);
                        add(btn);

                    case "box":
                        var w = node.get("width") != null ? Std.parseInt(node.get("width")) : 100;
                        var h = node.get("height") != null ? Std.parseInt(node.get("height")) : 100;
                        var colorVal = node.get("color") != null ? ColorUtil.fromHexSafe(node.get("color"), FlxColor.WHITE) : FlxColor.WHITE;
                        var box = new FlxSprite(xPos, yPos).makeGraphic(w, h, colorVal);
                        box.alpha = alphaVal;
                        if (id != null) elementsById.set(id, box);
                        add(box);

                    case "text":
                        var content = node.get("text") != null ? node.get("text") : "";
                        var size = node.get("size") != null ? Std.parseInt(node.get("size")) : 16;
                        var txt = new FlxText(xPos, yPos, node.get("width") != null ? Std.parseFloat(node.get("width")) : 0, content, size);
                        txt.setFormat(Paths.font(node.get("font") != null ? node.get("font") : "vcr"), size, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
                        if (node.get("color") != null) txt.color = ColorUtil.fromHexSafe(node.get("color"), FlxColor.WHITE);
                        txt.alpha = alphaVal;
                        if (id != null) elementsById.set(id, txt);
                        add(txt);
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

    override public function stepHit(step:Int):Void {
        super.stepHit(step);
        callScriptFunction("stepHit", [step]);
    }

    override public function beatHit(beat:Int):Void {
        super.beatHit(beat);
        callScriptFunction("beatHit", [beat]);
    }

    override public function measureHit(measure:Int):Void {
        super.measureHit(measure);
        callScriptFunction("measureHit", [measure]);
    }

    override public function destroy():Void {
        callScriptFunction("destroy", []);
        super.destroy();
    }
}