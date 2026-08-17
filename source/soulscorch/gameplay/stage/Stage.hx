package soulscorch.gameplay.stage;

import away3d.loaders.Loader3D;
import flixel.FlxBasic;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import haxe.Json;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.interfaces.IBeatReceiver;
import soulscorch.backend.interfaces.IScriptable;
import soulscorch.backend.system.EventBus;
import soulscorch.backend.system.apis.ModelAPI;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.actors.Character;
import soulscorch.gameplay.stage.StageData;
import soulscorch.graphics.threed.Away3DManager;
import soulscorch.scripting.ModLoader;
import soulscorch.scripting.ScriptManager;

class Stage extends FlxGroup implements IBeatReceiver implements IScriptable {
    public var id:String;
    public var defaultZoom:Float = 1.0;
    public var cameraSpeed:Float = 1.0;
    public var hideGirlfriend:Bool = false;

    public var bfPosition:Array<Float> = [770.0, 100.0];[cite: 75]
    public var dadPosition:Array<Float> = [100.0, 100.0];[cite: 75]
    public var gfPosition:Array<Float> = [400.0, 130.0];[cite: 75]

    public var layers:Map<String, FlxGroup> = new Map();[cite: 75]
    public var stageSprites:Map<String, FlxSprite> = new Map();[cite: 75]
    public var model3D:Loader3D = null;
    public var script:ScriptInstance = null;

    public function new(id:String) {
        super();
        this.id = id;

        // Structured Z-layer hierarchy[cite: 75]
        layers.set("background", new FlxGroup());[cite: 75]
        layers.set("behindGF", new FlxGroup());[cite: 75]
        layers.set("inFrontGF", new FlxGroup());[cite: 75]
        layers.set("behindDad", new FlxGroup());
        layers.set("behindBF", new FlxGroup());
        layers.set("foreground", new FlxGroup());[cite: 75]

        add(layers.get("background"));[cite: 75]
        add(layers.get("behindGF"));[cite: 75]
        add(layers.get("inFrontGF"));[cite: 75]
        add(layers.get("behindDad"));
        add(layers.get("behindBF"));
        add(layers.get("foreground"));[cite: 75]

        loadStageData();
        loadStageScript();
    }

    private function loadStageData():Void {
        var stageJsonPath = ModLoader.getPath('assets/data/stages/$id.json');
        if (!AssetResolver.exists(stageJsonPath)) {
            stageJsonPath = ModLoader.getPath('assets/stages/$id.json');
        }

        if (AssetResolver.exists(stageJsonPath)) {
            try {
                var rawJson:StageJson = Json.parse(AssetResolver.getText(stageJsonPath));

                if (rawJson.defaultZoom != 0) defaultZoom = rawJson.defaultZoom;
                if (rawJson.cameraSpeed != null) cameraSpeed = rawJson.cameraSpeed;
                if (rawJson.boyfriend != null && rawJson.boyfriend.length >= 2) bfPosition = rawJson.boyfriend;
                if (rawJson.girlfriend != null && rawJson.girlfriend.length >= 2) gfPosition = rawJson.girlfriend;
                if (rawJson.opponent != null && rawJson.opponent.length >= 2) dadPosition = rawJson.opponent;
                if (rawJson.hideGirlfriend != null) hideGirlfriend = rawJson.hideGirlfriend;

                // Build 2D sprites from stage schema
                if (rawJson.sprites != null) {
                    for (sprData in rawJson.sprites) {
                        buildSpriteFromData(sprData);
                    }
                }

                // Load optional Stage3D Away3D scene model
                if (rawJson.model3D != null && rawJson.model3D.length > 0) {
                    load3DBackground(rawJson.model3D, rawJson.modelTexture);
                }

                Logger.info('Parsed stage schema: $id', "stage");
            } catch (e:Dynamic) {
                Logger.error('Failed parsing stage JSON ($stageJsonPath): $e', "stage");
            }
        } else {
            Logger.warn('Stage schema not found for: $id. Initializing blank fallback.', "stage");
        }
    }

    private function buildSpriteFromData(sprData:StageSpriteData):Void {
        var sprite = new FlxSprite(sprData.x != null ? sprData.x : 0, sprData.y != null ? sprData.y : 0);
        var targetLayer = sprData.layer != null ? sprData.layer : "background";

        if (sprData.animated == true) {
            AssetHelper.loadSparrowSafely(sprite, sprData.image);
            if (sprData.animations != null) {
                for (anim in sprData.animations) {
                    if (anim.indices != null && anim.indices.length > 0) {
                        sprite.animation.addByIndices(anim.name, anim.prefix, anim.indices, "", anim.fps, anim.loop);
                    } else {
                        sprite.animation.addByPrefix(anim.name, anim.prefix, anim.fps, anim.loop);
                    }
                }
            }
            if (sprData.firstAnimation != null) {
                sprite.animation.play(sprData.firstAnimation);
            }
        } else {
            AssetHelper.loadGraphicSafely(sprite, sprData.image);
        }

        if (sprData.scaleX != null || sprData.scaleY != null) {
            sprite.scale.set(
                sprData.scaleX != null ? sprData.scaleX : 1.0,
                sprData.scaleY != null ? sprData.scaleY : 1.0
            );
            sprite.updateHitbox();
        }

        sprite.scrollFactor.set(
            sprData.scrollX != null ? sprData.scrollX : 1.0,
            sprData.scrollY != null ? sprData.scrollY : 1.0
        );

        if (sprData.alpha != null) sprite.alpha = sprData.alpha;
        if (sprData.antialiasing != null) sprite.antialiasing = sprData.antialiasing;

        addSprite(sprData.name, sprite, targetLayer);
    }

    private function load3DBackground(modelName:String, ?textureName:String):Void {
        Away3DManager.init();
        model3D = ModelAPI.loadOBJ(modelName, textureName, function(loader) {
            Away3DManager.scene.addChild(loader);
            Logger.info('Attached 3D stage model: $modelName', "stage");
        });
    }

    private function loadStageScript():Void {
        var scriptPath = 'assets/data/stages/$id.hx';
        if (!AssetResolver.exists(ModLoader.getPath(scriptPath))) {
            scriptPath = 'assets/stages/$id.hx';
        }

        if (AssetResolver.exists(ModLoader.getPath(scriptPath))) {
            script = new ScriptInstance(scriptPath);
            script.set("stage", this);
            script.set("addSprite", addSprite);
            script.set("getSprite", getSprite);
            script.call("onCreate");
        }
    }

    public function addSprite(name:String, sprite:FlxSprite, layer:String = "background"):Void {[cite: 75]
        stageSprites.set(name, sprite);[cite: 75]
        if (layers.exists(layer)) {[cite: 75]
            layers.get(layer).add(sprite);[cite: 75]
        } else {
            add(sprite);[cite: 75]
        }
    }

    public function getSprite(name:String):FlxSprite {[cite: 75]
        return stageSprites.get(name);[cite: 75]
    }

    public function positionCharacters(bf:Character, dad:Character, ?gf:Character):Void {
        if (bf != null) {
            bf.setPosition(
                bfPosition[0] + bf.positionOffset[0],
                bfPosition[1] + bf.positionOffset[1]
            );
        }
        if (dad != null) {
            dad.setPosition(
                dadPosition[0] + dad.positionOffset[0],
                dadPosition[1] + dad.positionOffset[1]
            );
        }
        if (gf != null) {
            gf.setPosition(
                gfPosition[0] + gf.positionOffset[0],
                gfPosition[1] + gf.positionOffset[1]
            );
            if (hideGirlfriend) gf.visible = false;
        }
    }

    public function load():Void {[cite: 75]
        var count = Lambda.count(stageSprites);[cite: 75]
        Logger.info('Stage "$id" ready with $count active sprites.', "stage");
        EventBus.emit("stage/loaded", {id: id, count: count});[cite: 75]
        call("onLoad");
    }

    public function stepHit(step:Int):Void {[cite: 75]
        forEachAlive(function(basic:FlxBasic) {[cite: 75]
            if (Std.isOfType(basic, IBeatReceiver)) {[cite: 75]
                cast(basic, IBeatReceiver).stepHit(step);[cite: 75]
            }
        });
        call("onStepHit", [step]);
    }

    public function beatHit(beat:Int):Void {[cite: 75]
        forEachAlive(function(basic:FlxBasic) {[cite: 75]
            if (Std.isOfType(basic, IBeatReceiver)) {[cite: 75]
                cast(basic, IBeatReceiver).beatHit(beat);[cite: 75]
            }
        });
        call("onBeatHit", [beat]);
    }

    public function measureHit(measure:Int):Void {[cite: 75]
        forEachAlive(function(basic:FlxBasic) {[cite: 75]
            if (Std.isOfType(basic, IBeatReceiver)) {[cite: 75]
                cast(basic, IBeatReceiver).measureHit(measure);[cite: 75]
            }
        });
        call("onMeasureHit", [measure]);
    }

    // --- IScriptable Implementation ---

    public function call(func:String, ?args:Array<Dynamic>):Dynamic {
        if (script != null && script.alive) {
            return script.call(func, args);
        }
        return null;
    }

    public function set(variable:String, value:Dynamic):Void {
        if (script != null && script.alive) {
            script.set(variable, value);
        }
    }

    public function get(variable:String):Dynamic {
        if (script != null && script.alive) {
            return script.get(variable);
        }
        return null;
    }

    override public function destroy():Void {
        if (model3D != null) {
            Away3DManager.removeMesh(cast model3D);
            model3D = null;
        }
        if (script != null) {
            script.destroy();
            script = null;
        }
        stageSprites.clear();
        super.destroy();
    }
}