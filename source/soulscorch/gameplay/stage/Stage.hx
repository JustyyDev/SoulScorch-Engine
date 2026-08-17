package soulscorch.gameplay.stage;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import haxe.Json;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.actors.Character;
import soulscorch.scripting.ScriptInstance;
import soulscorch.scripting.backends.ScriptBackendType;
import soulscorch.scripting.mod.ModLoader;

typedef StageSpriteDef = {
    var image:String;
    var x:Float;
    var y:Float;
    var ?id:String;
    var ?layer:String;
    var ?scrollX:Float;
    var ?scrollY:Float;
    var ?scaleX:Float;
    var ?scaleY:Float;
    var ?antialiasing:Bool;
}

typedef StageData = {
    var ?defaultZoom:Float;
    var ?boyfriend:Array<Float>;
    var ?opponent:Array<Float>;
    var ?girlfriend:Array<Float>;
    var ?cameraSpeed:Float;
    var ?sprites:Array<StageSpriteDef>;
}

class Stage extends FlxGroup {
    public var stageId:String;
    public var defaultZoom:Float = 0.9;
    public var bfPosition:Array<Float> = [770.0, 100.0];
    public var dadPosition:Array<Float> = [100.0, 100.0];
    public var gfPosition:Array<Float> = [400.0, 130.0];
    public var cameraSpeed:Float = 1.0;
    public var script:ScriptInstance = null;

    public var layers:Map<String, FlxTypedGroup<FlxBasic>> = new Map();
    public var stageSprites:Map<String, FlxSprite> = new Map();

    public function new(stageId:String = "stage") {
        super();
        this.stageId = stageId;

        var layerNames = ["background", "behindGF", "behindDad", "behindBF", "foreground"];
        for (l in layerNames) {
            var grp = new FlxTypedGroup<FlxBasic>();
            layers.set(l, grp);
            add(grp);
        }
    }

    public function load():Void {
        var jsonPath = ModLoader.getPath('assets/data/stages/$stageId.json');
        if (!AssetResolver.exists(jsonPath)) {
            jsonPath = ModLoader.getPath('data/stages/$stageId.json');
        }

        var stageScriptPath = ModLoader.getPath('assets/data/stages/$stageId.hx');
        if (AssetResolver.exists(stageScriptPath)) {
            script = ScriptBackendType.createInstance(stageScriptPath);
            if (script != null) {
                script.set("stage", this);
                script.call("onCreate");
            }
        }

        if (!AssetResolver.exists(jsonPath)) {
            Logger.warn('Stage descriptor not found for "$stageId", building fallback default stage.', "stage");
            buildDefaultStage();
            return;
        }

        try {
            var rawJson = AssetResolver.getText(jsonPath);
            var data:StageData = Json.parse(rawJson);

            if (data.defaultZoom != null) defaultZoom = data.defaultZoom;
            if (data.boyfriend != null && data.boyfriend.length >= 2) bfPosition = data.boyfriend;
            if (data.opponent != null && data.opponent.length >= 2) dadPosition = data.opponent;
            if (data.girlfriend != null && data.girlfriend.length >= 2) gfPosition = data.girlfriend;
            if (data.cameraSpeed != null) cameraSpeed = data.cameraSpeed;

            if (data.sprites != null) {
                for (s in data.sprites) {
                    var spr = new FlxSprite(s.x, s.y);
                    AssetHelper.loadGraphicSafely(spr, s.image);

                    if (s.scrollX != null || s.scrollY != null) {
                        spr.scrollFactor.set(s.scrollX != null ? s.scrollX : 1.0, s.scrollY != null ? s.scrollY : 1.0);
                    }
                    if (s.scaleX != null || s.scaleY != null) {
                        spr.scale.set(s.scaleX != null ? s.scaleX : 1.0, s.scaleY != null ? s.scaleY : 1.0);
                        spr.updateHitbox();
                    }

                    spr.antialiasing = (s.antialiasing != null) ? s.antialiasing : true;

                    var targetLayer = (s.layer != null && layers.exists(s.layer)) ? s.layer : "background";
                    layers.get(targetLayer).add(spr);
                    if (s.id != null) stageSprites.set(s.id, spr);
                }
            }
        } catch (e:Dynamic) {
            Logger.error('Failed to parse stage layout for $stageId: $e', "stage");
            buildDefaultStage();
        }
    }

    public function positionCharacters(bf:Character, dad:Character, ?gf:Character):Void {
        if (bf != null) bf.setPosition(bfPosition[0] + bf.positionOffset[0], bfPosition[1] + bf.positionOffset[1]);
        if (dad != null) dad.setPosition(dadPosition[0] + dad.positionOffset[0], dadPosition[1] + dad.positionOffset[1]);
        if (gf != null) gf.setPosition(gfPosition[0] + gf.positionOffset[0], gfPosition[1] + gf.positionOffset[1]);
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

    public function beatHit(beat:Int):Void {
        if (script != null) script.call("onBeatHit", [beat]);
    }

    public function stepHit(step:Int):Void {
        if (script != null) script.call("onStepHit", [step]);
    }
}