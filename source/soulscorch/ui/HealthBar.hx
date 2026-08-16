package soulscorch.ui;

import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.ui.FlxBar;
import flixel.util.FlxColor;
import soulscorch.assets.AssetResolver;
import soulscorch.assets.Paths;

class HealthBar extends FlxSpriteGroup {
    public var bg:FlxSprite;
    public var bar:FlxBar;
    public var iconP1:HealthIcon;
    public var iconP2:HealthIcon;
    
    public var value:Float = 1.0;

    public function new(x:Float, y:Float, charP1:String, charP2:String) {
        super(x, y);

        bg = new FlxSprite(0, 0);
        if (AssetResolver.exists(Paths.image('images/ui/healthBar'))) {
            bg.loadGraphic(Paths.image('images/ui/healthBar'));
        } else {
            bg.makeGraphic(600, 19, FlxColor.BLACK);
        }
        add(bg);

        bar = new FlxBar(bg.x + 4, bg.y + 4, RIGHT_TO_LEFT, Std.int(bg.width - 8), Std.int(bg.height - 8), this, "value", 0, 2);
        bar.createFilledBar(0xFFFF0000, 0xFF66FF33);
        add(bar);

        iconP1 = new HealthIcon(charP1, true);
        iconP2 = new HealthIcon(charP2, false);
        
        add(iconP2);
        add(iconP1);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        
        var percent = (value / 2.0);
        
        iconP1.x = bar.x + (bar.width * (1 - percent)) - 26;
        iconP2.x = bar.x + (bar.width * (1 - percent)) - (iconP2.width - 26);
        
        iconP1.y = bar.y - (iconP1.height / 2) + (bar.height / 2);
        iconP2.y = bar.y - (iconP2.height / 2) + (bar.height / 2);

        iconP1.animation.curAnim.curFrame = value < 0.4 ? 1 : 0;
        iconP2.animation.curAnim.curFrame = value > 1.6 ? 1 : 0;
    }
    
    public function bop():Void {
        iconP1.bop();
        iconP2.bop();
    }
}