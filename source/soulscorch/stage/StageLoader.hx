package soulscorch.stage;

import haxe.Json;
import flixel.FlxSprite;
import soulscorch.assets.AssetResolver;
import soulscorch.stage.Stage;

typedef StageLayer = {
    var name:String;
    var image:String;
    var position:Array<Float>;
    var scroll:Array<Float>;
    var scale:Null<Float>;
    var antialiasing:Null<Bool>;
    var active:Null<Bool>;
}

typedef StageFile = {
    var defaultZoom:Null<Float>;
    var bfPosition:Array<Float>;
    var dadPosition:Array<Float>;
    var gfPosition:Array<Float>;
    var layers:Array<StageLayer>;
}

class StageLoader {
    static inline var STAGE_ROOT:String = "assets/data/stages";
    static inline var IMAGE_ROOT:String = "assets/images/stages";

    public static function load(stageId:String):Stage {
        var stage = new Stage(stageId);
        var jsonPath = '$STAGE_ROOT/$stageId.json';

        if (!AssetResolver.exists(jsonPath)) {
            return buildFallbackStage(stage);
        }

        var rawJson = AssetResolver.getText(jsonPath);
        var data:StageFile = cast Json.parse(rawJson);

        stage.defaultZoom = data.defaultZoom != null ? data.defaultZoom : 1.0;
        if (data.bfPosition != null) stage.bfPosition = data.bfPosition;
        if (data.dadPosition != null) stage.dadPosition = data.dadPosition;
        if (data.gfPosition != null) stage.gfPosition = data.gfPosition;

        if (data.layers != null) {
            for (layer in data.layers) {
                var sprite = new FlxSprite();
                
                var posX = layer.position != null ? layer.position[0] : 0;
                var posY = layer.position != null ? layer.position[1] : 0;
                sprite.x = posX;
                sprite.y = posY;

                if (layer.image != null && layer.image != "") {
                    sprite.loadGraphic('$IMAGE_ROOT/${layer.image}.png');
                }

                if (layer.scroll != null && layer.scroll.length >= 2) {
                    sprite.scrollFactor.set(layer.scroll[0], layer.scroll[1]);
                } else {
                    sprite.scrollFactor.set(1, 1);
                }

                if (layer.scale != null && layer.scale != 1.0) {
                    sprite.setGraphicSize(Std.int(sprite.width * layer.scale));
                    sprite.updateHitbox();
                }

                sprite.antialiasing = layer.antialiasing != null ? layer.antialiasing : true;
                sprite.active = layer.active != null ? layer.active : false;

                var spriteName = layer.name != null ? layer.name : layer.image;
                stage.addSprite(spriteName, sprite);
            }
        }

        return stage;
    }

    private static function buildFallbackStage(stage:Stage):Stage {
        stage.defaultZoom = 0.9;
        
        var bg = new FlxSprite(-600, -200);
        bg.loadGraphic('$IMAGE_ROOT/stageback.png');
        bg.scrollFactor.set(0.9, 0.9);
        bg.antialiasing = true;
        bg.active = false;
        stage.addSprite("stageback", bg);

        var front = new FlxSprite(-650, 600);
        front.loadGraphic('$IMAGE_ROOT/stagefront.png');
        front.scrollFactor.set(0.9, 0.9);
        front.setGraphicSize(Std.int(front.width * 1.1));
        front.updateHitbox();
        front.antialiasing = true;
        front.active = false;
        stage.addSprite("stagefront", front);
        
        return stage;
    }
}