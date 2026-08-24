package soulscorch.scripting;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import haxe.xml.Access;
import haxe.xml.Parser;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.system.EventBus;
import soulscorch.backend.system.Scene;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.backends.ScriptBackendType;
import soulscorch.scripting.mod.ModLoader;
import soulscorch.scripting.mod.SoulGlobalScript;

using StringTools;

class ScriptedState extends Scene {
    public var scriptName:String;
    public var script:ScriptInstance;
    public var uiElements:Map<String, Dynamic> = new Map();

    private static final SUPPORTED_EXTENSIONS:Array<String> = [
        "hx", "soul", "lua", "py", "hscript", "iris", "js"
    ];

    private static final SEARCH_DIRECTORIES:Array<String> = [
        "states/", "data/ui/", "data/states/", "scripts/states/", "data/"
    ];

    public function new(scriptName:String) {
        super();
        this.scriptName = scriptName;
    }

    override public function create():Void {
        super.create();

        var possibleXmlPaths = [
            'states/$scriptName.xmsoul',
            'states/$scriptName.xml',
            'data/ui/$scriptName.xmsoul',
            'data/ui/$scriptName.xml',
            'data/states/$scriptName.xmsoul',
            'data/states/$scriptName.xml',
            'data/$scriptName.xmsoul',
            'data/$scriptName.xml'
        ];

        for (p in possibleXmlPaths) {
            var resolvedXml = ModLoader.getPath(p);
            if (AssetResolver.exists(resolvedXml)) {
                parseXML(AssetResolver.getText(resolvedXml));
                break;
            }
        }

        var finalScriptPath:String = null;
        for (dir in SEARCH_DIRECTORIES) {
            for (ext in SUPPORTED_EXTENSIONS) {
                var testPath = ModLoader.getPath('$dir$scriptName.$ext');
                if (AssetResolver.exists(testPath)) {
                    finalScriptPath = testPath;
                    break;
                }
            }
            if (finalScriptPath != null) break;
        }

        if (finalScriptPath != null) {
            this.script = ScriptBackendType.createInstance(finalScriptPath);

            if (this.script != null && this.script.active) {
                script.set("state", this);
                script.set("game", this);
                script.set("camera", FlxG.camera);
                script.set("cameras", FlxG.cameras);
                script.set("add", add);
                script.set("remove", remove);
                script.set("insert", insert);
                script.set("members", members);
                script.set("Paths", Paths);
                script.set("Conductor", Conductor);
                script.set("EventBus", EventBus.instance);
                
                script.set("getElement", function(id:String):Dynamic {
                    return uiElements.get(id);
                });

                script.set("switchState", function(nextState:Dynamic) {
                    if (Std.isOfType(nextState, String)) {
                        var requested:String = cast nextState;
                        var redirected = SoulGlobalScript.getRedirect(requested);
                        var targetName = (redirected != null && redirected.trim().length > 0) ? redirected : requested;
                        MusicBeatState.switchState(new ScriptedState(targetName));
                    } else {
                        MusicBeatState.switchState(nextState);
                    }
                });

                script.set("openSubState", function(subState:Dynamic) {
                    if (Std.isOfType(subState, String)) {
                        openSubState(new ScriptedSubState(cast subState));
                    } else {
                        openSubState(subState);
                    }
                });

                script.call("create", []);
                script.call("onCreate", []);
                script.call("createPost", []);
                script.call("onCreatePost", []);
            } else {
                Logger.warn('ScriptBackend failed to initialize for: $finalScriptPath', "scripting");
            }
        } else {
            Logger.warn('ScriptedState could not find any supported script file for "$scriptName".', "scripting");
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
                        add(spr);
                        uiElements.set(id, spr);

                    case "text":
                        var content = node.has.content ? node.att.content : (node.has.text ? node.att.text : "");
                        var size = node.has.size ? Std.parseInt(node.att.size) : 16;
                        var width = node.has.width ? Std.parseFloat(node.att.width) : 0;
                        var txt = new FlxText(x, y, width, content, size);
                        var col = node.has.color ? FlxColor.fromString(node.att.color) : FlxColor.WHITE;
                        txt.setFormat(Paths.font("vcr"), size, col, LEFT);
                        txt.alpha = alpha;
                        add(txt);
                        uiElements.set(id, txt);

                    case "label":
                        var labelText = node.has.content ? node.att.content : (node.has.text ? node.att.text : "");
                        var labelSize = node.has.size ? Std.parseInt(node.att.size) : 16;
                        var labelWidth = node.has.width ? Std.parseFloat(node.att.width) : 0;
                        var label = new FlxText(x, y, labelWidth, labelText, labelSize);
                        var labelCol = node.has.color ? FlxColor.fromString(node.att.color) : FlxColor.WHITE;
                        label.setFormat(Paths.font("vcr"), labelSize, labelCol, LEFT);
                        label.alpha = alpha;
                        add(label);
                        uiElements.set(id, label);

                    case "button":
                        var width = node.has.width ? Std.parseInt(node.att.width) : 100;
                        var height = node.has.height ? Std.parseInt(node.att.height) : 50;
                        var onClickName = node.has.onClick ? node.att.onClick : null;
                        var btn = new FlxButton(x, y, "", function() {
                            if (onClickName != null && script != null && script.active) {
                                script.call(onClickName, []);
                            }
                        });
                        btn.makeGraphic(width, height, FlxColor.TRANSPARENT);
                        btn.alpha = alpha;
                        add(btn);
                        uiElements.set(id, btn);
                }
            }
        } catch (e:Dynamic) {
            Logger.error('Failed to parse XML for $scriptName: $e', "scripting");
        }
    }

    override public function update(elapsed:Float):Void {
        if (script != null && script.active) {
            script.call("update", [elapsed]);
            script.call("onUpdate", [elapsed]);
        }

        super.update(elapsed);

        if (script != null && script.active) {
            script.call("updatePost", [elapsed]);
            script.call("onUpdatePost", [elapsed]);
        }
    }

    override public function stepHit(step:Int):Void {
        super.stepHit(step);
        if (script != null && script.active) {
            script.call("stepHit", [step]);
            script.call("onStepHit", [step]);
        }
    }

    override public function beatHit(beat:Int):Void {
        super.beatHit(beat);
        if (script != null && script.active) {
            script.call("beatHit", [beat]);
            script.call("onBeatHit", [beat]);
        }
    }

    override public function destroy():Void {
        if (script != null && script.active) {
            script.call("destroy", []);
            script.call("onDestroy", []);
            script.destroy();
            script = null;
        }
        
        uiElements.clear();
        super.destroy();
    }
}