package soulscorch.gameplay.stage;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.util.FlxColor;
import haxe.Json;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.actors.Character;
import soulscorch.gameplay.stage.StageJson;
import soulscorch.scripting.ScriptInstance;
import soulscorch.scripting.backends.ScriptBackendType;
import soulscorch.scripting.mod.ModManager;

using StringTools;

class Stage extends FlxGroup {
    public var stageId:String;
    public var defaultZoom:Float = 0.9;
    public var cameraSpeed:Float = 1.0;

    public var bfPosition:Array<Float> = [770.0, 100.0];
    public var dadPosition:Array<Float> = [100.0, 100.0];
    public var gfPosition:Array<Float> = [400.0, 130.0];

    public var hideGirlfriend:Bool = false;
    public var script:ScriptInstance = null;

    public var layers:Map<String, FlxTypedGroup<FlxBasic>> = new Map<String, FlxTypedGroup<FlxBasic>>();
    public var stageSprites:Map<String, FlxSprite> = new Map<String, FlxSprite>();

    public function new(stageId:String = "stage") {
        super();
        this.stageId = (stageId != null && stageId.trim().length > 0) ? stageId.trim() : "stage";

        var layerNames = ["background", "behindGF", "behindDad", "behindBF", "foreground"];
        for (l in layerNames) {
            var grp = new FlxTypedGroup<FlxBasic>();
            layers.set(l, grp);
            add(grp);
        }
    }

    public function load():Void {
        var jsonCandidates = [
            'stages/$stageId.json',
            'data/stages/$stageId.json',
            'stages/$stageId/$stageId.json',
            'data/stages/$stageId/$stageId.json'
        ];

        var resolvedJson:String = null;
        for (candidate in jsonCandidates) {
            resolvedJson = AssetResolver.resolveFile(candidate, [".json", ""]);
            if (resolvedJson != null) break;
        }

        // Script loading across supported extensions (.hx, .soul, .lua)
        var scriptCandidates = [
            'stages/$stageId',
            'data/stages/$stageId',
            'stages/$stageId/$stageId',
            'data/stages/$stageId/$stageId'
        ];

        for (candidate in scriptCandidates) {
            var resolvedScript = AssetResolver.resolveFile(candidate, [".hx", ".soul", ".lua"]);
            if (resolvedScript != null) {
                script = ScriptBackendType.createInstance(resolvedScript);
                if (script != null) {
                    script.set("stage", this);
                    script.set("game", FlxG.state);
                    script.call("onCreate");
                }
                break;
            }
        }

        if (resolvedJson == null) {
            Logger.warn('Stage descriptor not found for "$stageId", building fallback default stage.', "stage");
            buildDefaultStage();
            if (script != null) script.call("onCreatePost");
            return;
        }

        try {
            var rawJson = AssetResolver.getText(resolvedJson);
            var data:StageJson = Json.parse(rawJson);

            if (data.defaultZoom != null && data.defaultZoom > 0) defaultZoom = data.defaultZoom;
            
            var speedVal = (data.cameraSpeed != null) ? data.cameraSpeed : data.camera_speed;
            if (speedVal != null && speedVal > 0) cameraSpeed = speedVal;

            hideGirlfriend = (data.hideGirlfriend != null) ? data.hideGirlfriend : ((data.hide_girlfriend != null) ? data.hide_girlfriend : false);

            bfPosition = parseSpawnPosition(data.boyfriend, [770.0, 100.0]);
            
            var oppData = (data.opponent != null) ? data.opponent : data.dad;
            dadPosition = parseSpawnPosition(oppData, [100.0, 100.0]);

            var gfData = (data.girlfriend != null) ? data.girlfriend : data.gf;
            gfPosition = parseSpawnPosition(gfData, [400.0, 130.0]);

            var piecesList = (data.pieces != null) ? data.pieces : ((data.sprites != null) ? data.sprites : data.objects);
            if (piecesList != null) {
                for (piece in piecesList) {
                    loadPiece(piece);
                }
            }
        } catch (e:Dynamic) {
            Logger.error('Failed to parse stage layout for $stageId: $e', "stage");
            buildDefaultStage();
        }

        if (script != null) script.call("onCreatePost");
    }

    private function loadPiece(piece:StagePieceJson):Void {
        var posX:Float = (piece.position != null && piece.position.length >= 1) ? piece.position[0] : ((piece.x != null) ? piece.x : 0.0);
        var posY:Float = (piece.position != null && piece.position.length >= 2) ? piece.position[1] : ((piece.y != null) ? piece.y : 0.0);

        var spr = new FlxSprite(posX, posY);

        if (piece.animated == true || (piece.animations != null && piece.animations.length > 0)) {
            AssetHelper.loadSparrowSafely(spr, piece.image);
            if (piece.animations != null) {
                for (anim in piece.animations) {
                    var fps = (anim.fps != null) ? Std.int(anim.fps) : 24;
                    var loop = (anim.loop != null) ? anim.loop : true;
                    if (anim.indices != null && anim.indices.length > 0) {
                        spr.animation.addByIndices(anim.anim, anim.name, anim.indices, "", fps, loop);
                    } else {
                        spr.animation.addByPrefix(anim.anim, anim.name, fps, loop);
                    }
                }
                if (piece.animations.length > 0) {
                    spr.animation.play(piece.animations[0].anim);
                }
            }
        } else {
            AssetHelper.loadGraphicSafely(spr, piece.image);
        }

        var scrollX:Float = (piece.scroll != null && piece.scroll.length >= 1) ? piece.scroll[0] : ((piece.scrollX != null) ? piece.scrollX : 1.0);
        var scrollY:Float = (piece.scroll != null && piece.scroll.length >= 2) ? piece.scroll[1] : ((piece.scrollY != null) ? piece.scrollY : 1.0);
        spr.scrollFactor.set(scrollX, scrollY);

        var scaleX:Float = (piece.scale != null && piece.scale.length >= 1) ? piece.scale[0] : ((piece.scaleX != null) ? piece.scaleX : 1.0);
        var scaleY:Float = (piece.scale != null && piece.scale.length >= 2) ? piece.scale[1] : ((piece.scaleY != null) ? piece.scaleY : 1.0);
        spr.scale.set(scaleX, scaleY);
        spr.updateHitbox();

        if (piece.alpha != null) spr.alpha = piece.alpha;
        if (piece.color != null) spr.color = FlxColor.fromString(piece.color);
        spr.antialiasing = (piece.antialiasing != null) ? piece.antialiasing : true;

        var targetLayer = (piece.layer != null && layers.exists(piece.layer)) ? piece.layer : "background";
        layers.get(targetLayer).add(spr);

        var pieceId = (piece.id != null) ? piece.id : piece.name;
        if (pieceId != null && pieceId.trim().length > 0) {
            stageSprites.set(pieceId, spr);
        }
    }

    private function parseSpawnPosition(raw:Dynamic, fallback:Array<Float>):Array<Float> {
        if (raw == null) return fallback;

        if (Std.isOfType(raw, Array)) {
            var arr:Array<Dynamic> = cast raw;
            if (arr.length >= 2) {
                return [Std.parseFloat(Std.string(arr[0])), Std.parseFloat(Std.string(arr[1]))];
            }
        } else if (Reflect.isObject(raw) && Reflect.hasField(raw, "position")) {
            var posArr:Array<Dynamic> = cast Reflect.field(raw, "position");
            if (posArr != null && posArr.length >= 2) {
                return [Std.parseFloat(Std.string(posArr[0])), Std.parseFloat(Std.string(posArr[1]))];
            }
        }
        return fallback;
    }

    public function positionCharacters(bf:Character, dad:Character, ?gf:Character):Void {
        if (bf != null) bf.setPosition(bfPosition[0] + bf.positionOffset[0], bfPosition[1] + bf.positionOffset[1]);
        if (dad != null) dad.setPosition(dadPosition[0] + dad.positionOffset[0], dadPosition[1] + dad.positionOffset[1]);
        if (gf != null) {
            gf.setPosition(gfPosition[0] + gf.positionOffset[0], gfPosition[1] + gf.positionOffset[1]);
            gf.visible = !hideGirlfriend;
        }
    }

    private function buildDefaultStage():Void {
        var bg = new FlxSprite(-600, -200);
        if (!AssetHelper.loadGraphicSafely(bg, "stages/default/stageback")) {
            bg.makeGraphic(2560, 1400, 0xFF353846);
        }
        bg.scrollFactor.set(0.9, 0.9);
        layers.get("background").add(bg);

        var stageFront = new FlxSprite(-650, 600);
        if (!AssetHelper.loadGraphicSafely(stageFront, "stages/default/stagefront")) {
            stageFront.makeGraphic(2700, 450, 0xFF242733);
        }
        stageFront.scrollFactor.set(0.9, 0.9);
        layers.get("background").add(stageFront);
    }

    public function updateStage(elapsed:Float):Void {
        if (script != null) script.call("onUpdate", [elapsed]);
    }

    public function beatHit(beat:Int):Void {
        if (script != null) script.call("onBeatHit", [beat]);
    }

    public function stepHit(step:Int):Void {
        if (script != null) script.call("onStepHit", [step]);
    }

    override public function destroy():Void {
        if (script != null) {
            script.call("onDestroy");
            script.destroy();
            script = null;
        }
        stageSprites.clear();
        super.destroy();
    }
}