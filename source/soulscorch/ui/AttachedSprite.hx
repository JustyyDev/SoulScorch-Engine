package soulscorch.ui;

import flixel.FlxSprite;

class AttachedSprite extends FlxSprite {
    public var sprTracker:FlxSprite;
    public var xAdd:Float = 0;
    public var yAdd:Float = 0;

    public function new(path:String = "") {
        super();
        if (path != "") {
            loadGraphic(path);
        }
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (sprTracker != null) {
            setPosition(sprTracker.x + xAdd, sprTracker.y + yAdd);
            scrollFactor.set(sprTracker.scrollFactor.x, sprTracker.scrollFactor.y);
        }
    }
}