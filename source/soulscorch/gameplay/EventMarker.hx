package soulscorch.gameplay;

import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;

class EventMarker extends FlxSprite {
    public var time:Float;
    public var type:String;
    public var value:Float;
    public var displayLabel:FlxText;

    public function new(time:Float, type:String, value:Float) {
        super(0, 0);
        this.time = time;
        this.type = type;
        this.value = value;

        makeGraphic(40, 40, type == "BPM" ? 0xFFE04040 : 0xFF4080E0);
        
        displayLabel = new FlxText(0, 0, 0, Std.string(value), 12);
        displayLabel.alignment = CENTER;
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        displayLabel.setPosition(x + (width / 2) - (displayLabel.width / 2), y + (height / 2) - (displayLabel.height / 2));
    }

    override public function draw():Void {
        super.draw();
        displayLabel.draw();
    }
}