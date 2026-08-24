package soulscorch.gameplay.stage;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import haxe.Json;
import haxe.xml.Access;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.system.XMSoul;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.PlayState;
import soulscorch.gameplay.actors.Character;
import soulscorch.graphics.shaders.ShaderManager;
import soulscorch.graphics.shaders.SoulShader;
import soulscorch.scripting.ScriptManager;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

class Stage extends FlxTypedGroup<FlxBasic> {
    public var stageId:String = "stage";
    public var defaultZoom:Float = 0.9;
    public var startCamPos:FlxPoint = new FlxPoint(1000, 600);

    public var layers:Map<String, FlxTypedGroup<FlxBasic>> = new Map<String, FlxTypedGroup<FlxBasic>>();
    public var namedSprites:Map<String, FlxSprite> = new Map<String, FlxSprite>();
    public var beatSprites:Array<FlxSprite> = [];
    public var loopSprites:Array<FlxSprite> = [];

    public var boyfriendPosition:FlxPoint = new FlxPoint(770, 450);
    public var dadPosition:FlxPoint = new FlxPoint(100, 100);
    public var gfPosition:FlxPoint = new FlxPoint(400, 130);

    public var stageScript:ScriptManager;

    public function new(stageId:String = "stage") {
        super();
        this.stageId = (stageId != null && stageId.trim().length > 0) ? stageId.trim() : "stage";
        initLayers();
    }

    private function initLayers():Void {
        var layerNames = ["bg", "behindGF", "behindDad", "behindBF", "fg", "top"];
        for (l in layerNames) {
            var grp = new FlxTypedGroup<FlxBasic>();
            layers.set(l, grp);
            add(grp);
        }
    }

    public function load():Void {
        clearStage();

        var xmsoulLoaded = loadXMSoulStage(stageId);
        if (!xmsoulLoaded) {
            var xmlLoaded = loadCodenameXMLStage(stageId);
            if (!xmlLoaded) {
                var jsonLoaded = loadJSONStage(stageId);
                if (!jsonLoaded) {
                    loadDefaultFallbackStage();
                }
            }
        }

        initStageScript();
    }

    private function loadXMSoulStage(id:String):Bool {
        var possiblePaths = [
            'stages/$id/$id.xmsoul',
            'stages/$id.xmsoul',
            'data/stages/$id/$id.xmsoul',
            'data/stages/$id.xmsoul',
            'assets/preload/data/stages/$id/$id.xmsoul',
            'assets/preload/stages/$id/$id.xmsoul'
        ];

        for (p in possiblePaths) {
            var stageNode = XMSoul.parse(p);
            if (stageNode != null) {
                return parseStageNode(stageNode, 'stages/$id/');
            }
        }
        return false;
    }

    private function loadCodenameXMLStage(id:String):Bool {
        var possibleXmlPaths = [
            'stages/$id/$id.xml',
            'stages/$id.xml',
            'data/stages/$id/$id.xml',
            'data/stages/$id.xml',
            'assets/preload/data/stages/$id/$id.xml',
            'assets/preload/data/stages/$id.xml',
            'assets/preload/stages/$id/$id.xml'
        ];

        for (p in possibleXmlPaths) {
            var resolved = AssetResolver.resolveFile(p, [".xml", ""]);
            if (resolved != null) {
                var content = AssetResolver.getText(resolved);
                if (content != null && content.length > 0) {
                    try {
                        var xml = Xml.parse(content);
                        var stageNode = new Access(xml.firstElement());
                        var folder = stageNode.has.folder ? stageNode.att.folder : 'stages/$id/';
                        return parseStageNode(stageNode, folder);
                    } catch (e:Dynamic) {
                        Logger.warn('Failed parsing Codename XML stage: $e', "stage");
                    }
                }
            }
        }
        return false;
    }

    private function parseStageNode(stageNode:Access, baseFolder:String):Bool {
        try {
            if (stageNode.has.zoom) defaultZoom = Std.parseFloat(stageNode.att.zoom);
            if (stageNode.has.startCamPosX) startCamPos.x = Std.parseFloat(stageNode.att.startCamPosX);
            if (stageNode.has.startCamPosY) startCamPos.y = Std.parseFloat(stageNode.att.startCamPosY);

            if (!baseFolder.endsWith("/")) baseFolder += "/";
            var currentLayerTarget = "bg";

            for (node in stageNode.elements) {
                var tag = node.name.toLowerCase();

                switch (tag) {
                    case "positions":
                        for (positionNode in node.elements) {
                            var targetPosition = switch (positionNode.name.toLowerCase()) {
                                case "girlfriend", "gf": gfPosition;
                                case "dad", "opponent": dadPosition;
                                case "boyfriend", "bf", "player": boyfriendPosition;
                                default: null;
                            };
                            if (targetPosition != null) {
                                if (positionNode.has.x) targetPosition.x = Std.parseFloat(positionNode.att.x);
                                if (positionNode.has.y) targetPosition.y = Std.parseFloat(positionNode.att.y);
                            }
                        }

                    case "girlfriend", "gf":
                        if (node.has.x) gfPosition.x = Std.parseFloat(node.att.x);
                        if (node.has.y) gfPosition.y = Std.parseFloat(node.att.y);
                        currentLayerTarget = "behindDad";

                    case "dad", "opponent":
                        if (node.has.x) dadPosition.x = Std.parseFloat(node.att.x);
                        if (node.has.y) dadPosition.y = Std.parseFloat(node.att.y);
                        currentLayerTarget = "behindBF";

                    case "boyfriend", "bf", "player":
                        if (node.has.x) boyfriendPosition.x = Std.parseFloat(node.att.x);
                        if (node.has.y) boyfriendPosition.y = Std.parseFloat(node.att.y);
                        currentLayerTarget = "fg";

                    case "sprite":
                        parseSpriteElement(node, baseFolder, currentLayerTarget);

                    case "layer":
                        var targetLayer = node.has.name ? node.att.name : currentLayerTarget;
                        for (subNode in node.elements) {
                            if (subNode.name.toLowerCase() == "sprite") {
                                parseSpriteElement(subNode, baseFolder, targetLayer);
                            }
                        }

                    case "box", "solid":
                        var bx = node.has.x ? Std.parseFloat(node.att.x) : 0.0;
                        var by = node.has.y ? Std.parseFloat(node.att.y) : 0.0;
                        var bw = node.has.width ? Std.parseInt(node.att.width) : 100;
                        var bh = node.has.height ? Std.parseInt(node.att.height) : 100;
                        var bColor = node.has.color ? FlxColor.fromString(node.att.color) : FlxColor.WHITE;

                        var boxSpr = new FlxSprite(bx, by).makeGraphic(bw, bh, bColor);
                        if (node.has.name) namedSprites.set(node.att.name, boxSpr);
                        layers.get(currentLayerTarget).add(boxSpr);
                }
            }
            return true;
        } catch (e:Dynamic) {
            Logger.warn('Failed parsing stage definition node: $e', "stage");
            return false;
        }
    }

    private function parseSpriteElement(elem:Access, folder:String, layer:String):Void {
        var sprName = elem.has.name ? elem.att.name : "spr_" + FlxG.random.int(0, 9999);
        var spriteFile = elem.has.sprite ? elem.att.sprite : sprName;
        var posX = elem.has.x ? Std.parseFloat(elem.att.x) : 0.0;
        var posY = elem.has.y ? Std.parseFloat(elem.att.y) : 0.0;

        var spr = new FlxSprite(posX, posY);
        var assetPath = folder + spriteFile;

        var loaded = AssetHelper.loadSparrowSafely(spr, assetPath);
        if (!loaded) loaded = AssetHelper.loadGraphicSafely(spr, assetPath);
        if (!loaded) loaded = AssetHelper.loadSparrowSafely(spr, spriteFile);
        if (!loaded) loaded = AssetHelper.loadGraphicSafely(spr, spriteFile);

        if (elem.has.scroll) {
            var sc = Std.parseFloat(elem.att.scroll);
            spr.scrollFactor.set(sc, sc);
        } else {
            var scX = elem.has.scrollx ? Std.parseFloat(elem.att.scrollx) : 1.0;
            var scY = elem.has.scrolly ? Std.parseFloat(elem.att.scrolly) : 1.0;
            spr.scrollFactor.set(scX, scY);
        }

        if (elem.has.scale) {
            var s = Std.parseFloat(elem.att.scale);
            spr.scale.set(s, s);
        }

        if (elem.has.angle) spr.angle = Std.parseFloat(elem.att.angle);
        if (elem.has.alpha) spr.alpha = Std.parseFloat(elem.att.alpha);

        if (elem.has.updateHitbox && elem.att.updateHitbox == "true") {
            spr.updateHitbox();
        }

        var type = elem.has.type ? elem.att.type.toLowerCase() : "static";
        if (type == "onbeat") {
            beatSprites.push(spr);
            if (spr.frames != null && spr.animation.getByName("idle") == null) {
                spr.animation.addByPrefix("idle", "idle", 24, false);
                if (spr.animation.getByName("idle") == null) spr.animation.addByPrefix("idle", spriteFile, 24, false);
                spr.animation.play("idle");
            }
        } else if (type == "loop") {
            loopSprites.push(spr);
            if (spr.frames != null) {
                spr.animation.addByPrefix("loop", "idle", 24, true);
                if (spr.animation.getByName("loop") == null) spr.animation.addByPrefix("loop", spriteFile, 24, true);
                spr.animation.play("loop");
            }
        }

        spr.antialiasing = true;
        namedSprites.set(sprName, spr);
        layers.get(layer).add(spr);
    }

    private function loadJSONStage(id:String):Bool {
        var possibleJsonPaths = [
            'stages/$id.json',
            'data/stages/$id.json',
            'assets/preload/data/stages/$id.json',
            'assets/preload/stages/$id.json'
        ];

        for (p in possibleJsonPaths) {
            var resolved = AssetResolver.resolveFile(p, [".json", ""]);
            if (resolved != null) {
                var content = AssetResolver.getText(resolved);
                if (content != null && content.length > 0) {
                    try {
                        var json:Dynamic = Json.parse(content);
                        if (json.defaultZoom != null) defaultZoom = json.defaultZoom;
                        else if (json.zoom != null) defaultZoom = json.zoom;

                        if (json.boyfriend != null && json.boyfriend.length >= 2) {
                            boyfriendPosition.set(json.boyfriend[0], json.boyfriend[1]);
                        }
                        if (json.opponent != null && json.opponent.length >= 2) {
                            dadPosition.set(json.opponent[0], json.opponent[1]);
                        }
                        if (json.girlfriend != null && json.girlfriend.length >= 2) {
                            gfPosition.set(json.girlfriend[0], json.girlfriend[1]);
                        }

                        var pieces:Array<Dynamic> = json.pieces != null ? cast json.pieces : (json.sprites != null ? cast json.sprites : []);
                        for (p in pieces) {
                            var posX = p.position != null ? p.position[0] : (p.x != null ? p.x : 0.0);
                            var posY = p.position != null ? p.position[1] : (p.y != null ? p.y : 0.0);
                            var spr = new FlxSprite(posX, posY);
                            AssetHelper.loadGraphicSafely(spr, p.image);

                            if (p.scroll != null) {
                                spr.scrollFactor.set(p.scroll[0], p.scroll[1]);
                            } else if (p.scrollX != null || p.scrollY != null) {
                                spr.scrollFactor.set(p.scrollX != null ? p.scrollX : 1.0, p.scrollY != null ? p.scrollY : 1.0);
                            }

                            if (p.scale != null) {
                                spr.scale.set(p.scale[0], p.scale[1]);
                            } else if (p.scaleX != null || p.scaleY != null) {
                                spr.scale.set(p.scaleX != null ? p.scaleX : 1.0, p.scaleY != null ? p.scaleY : 1.0);
                            }

                            if (p.alpha != null) spr.alpha = p.alpha;
                            if (p.antialiasing != null) spr.antialiasing = p.antialiasing;

                            var layer = p.layer != null ? (p.layer == "foreground" ? "fg" : p.layer) : "bg";
                            if (!layers.exists(layer)) layer = "bg";
                            layers.get(layer).add(spr);
                        }
                        return true;
                    } catch (e:Dynamic) {
                        Logger.warn('Failed parsing stage JSON for $id: $e', "stage");
                    }
                }
            }
        }
        return false;
    }

    private function loadDefaultFallbackStage():Void {
        var bg = new FlxSprite(-600, -200);
        if (!AssetHelper.loadGraphicSafely(bg, "stages/default/stageback")) {
            AssetHelper.loadGraphicSafely(bg, "stageback");
        }
        bg.scrollFactor.set(0.9, 0.9);
        layers.get("bg").add(bg);

        var front = new FlxSprite(-650, 600);
        if (!AssetHelper.loadGraphicSafely(front, "stages/default/stagefront")) {
            AssetHelper.loadGraphicSafely(front, "stagefront");
        }
        front.scrollFactor.set(0.9, 0.9);
        layers.get("bg").add(front);

        var curtains = new FlxSprite(-500, -300);
        if (!AssetHelper.loadGraphicSafely(curtains, "stages/default/stagecurtains")) {
            AssetHelper.loadGraphicSafely(curtains, "stagecurtains");
        }
        curtains.scrollFactor.set(1.3, 1.3);
        layers.get("top").add(curtains);
    }

    private function initStageScript():Void {
        stageScript = new ScriptManager();
        var scriptPath = AssetResolver.resolveFile('stages/$stageId/$stageId', [".hx", ".soul", ".lua", ".py", ".js"]);
        if (scriptPath == null) scriptPath = AssetResolver.resolveFile('stages/$stageId', [".hx", ".soul", ".lua", ".py", ".js"]);

        if (scriptPath != null) {
            stageScript.loadScript(scriptPath);

            // Register sprite handles
            for (key in namedSprites.keys()) {
                stageScript.setAll(key, namedSprites.get(key));
            }

            // Bind environment objects & engines
            stageScript.setAll("stage", this);
            stageScript.setAll("FlxG", FlxG);
            stageScript.setAll("FlxTween", FlxTween);
            stageScript.setAll("FlxEase", FlxEase);
            stageScript.setAll("FlxTimer", FlxTimer);
            stageScript.setAll("FlxMath", FlxMath);
            stageScript.setAll("ShaderManager", ShaderManager.instance);

            // Bind cameras & game references safely
            if (PlayState.instance != null) {
                stageScript.setAll("game", PlayState.instance);
                stageScript.setAll("PlayState", PlayState);
                stageScript.setAll("camGame", PlayState.instance.camGame);
                stageScript.setAll("camHUD", PlayState.instance.camHUD);
                stageScript.setAll("camOther", PlayState.instance.camOther);
                stageScript.setAll("boyfriend", PlayState.instance.boyfriend);
                stageScript.setAll("dad", PlayState.instance.dad);
                stageScript.setAll("gf", PlayState.instance.gf);
            } else {
                stageScript.setAll("camGame", FlxG.camera);
            }

            stageScript.callAll("postCreate", []);
            stageScript.callAll("create", []);
        }
    }

    public function positionCharacters(bf:Character, dad:Character, gf:Character):Void {
        if (gf != null) gf.setPosition(gfPosition.x, gfPosition.y);
        if (dad != null) dad.setPosition(dadPosition.x, dadPosition.y);
        if (bf != null) bf.setPosition(boyfriendPosition.x, boyfriendPosition.y);
    }

    public function addCharacters(bf:Character, dad:Character, gf:Character):Void {
        if (gf != null) layers.get("behindGF").add(gf);
        if (dad != null) layers.get("behindDad").add(dad);
        if (bf != null) layers.get("behindBF").add(bf);
    }

    public function updateStage(elapsed:Float):Void {
        if (stageScript != null) stageScript.callAll("update", [elapsed]);
    }

    public function beatHit(beat:Int):Void {
        for (spr in beatSprites) {
            if (spr != null && spr.animation.curAnim != null) {
                spr.animation.play(spr.animation.curAnim.name, true);
            }
        }
        if (stageScript != null) stageScript.callAll("beatHit", [beat]);
    }

    public function stepHit(step:Int):Void {
        if (stageScript != null) stageScript.callAll("stepHit", [step]);
    }

    public function clearStage():Void {
        for (l in layers) l.clear();
        namedSprites.clear();
        beatSprites = [];
        loopSprites = [];
    }

    override public function destroy():Void {
        if (stageScript != null) {
            stageScript.callAll("onDestroy", []);
            stageScript.clear();
        }
        startCamPos = null;
        boyfriendPosition = null;
        dadPosition = null;
        gfPosition = null;
        clearStage();
        super.destroy();
    }
}