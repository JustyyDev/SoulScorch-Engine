package soulscorch.stage;

import flixel.group.FlxGroup;
import flixel.FlxSprite;

class Stage extends FlxGroup {
    public var id:String;
    public var defaultZoom:Float = 1.0;
    
    public var bfPosition:Array<Float> = [770, 100];
    public var dadPosition:Array<Float> = [100, 100];
    public var gfPosition:Array<Float> = [400, 130];
    
    public var stageSprites:Map<String, FlxSprite>;

    public function new(id:String) {
        super();
        this.id = id;
        stageSprites = new Map<String, FlxSprite>();
    }

    public function addSprite(name:String, sprite:FlxSprite):Void {
        stageSprites.set(name, sprite);
        add(sprite);
    }
    
    public function getSprite(name:String):FlxSprite {
        return stageSprites.get(name);
    }

    public function load():Void {
    }
}