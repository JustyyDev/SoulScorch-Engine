package soulscorch.ui;

import flixel.group.FlxSpriteGroup;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.math.FlxMath;
import soulscorch.assets.AssetResolver;

class Alphabet extends FlxSpriteGroup {
    public var text(default, set):String;
    public var isBold:Bool = false;
    public var letters:Array<FlxSprite> = [];
    
    public var targetY:Float = 0;
    public var isMenuItem:Bool = false;
    
    public function new(x:Float, y:Float, text:String = "", isBold:Bool = false, isMenuItem:Bool = false) {
        super(x, y);
        this.isBold = isBold;
        this.isMenuItem = isMenuItem;
        this.text = text;
    }

    private function set_text(newText:String):String {
        if (this.text != newText) {
            this.text = newText;
            generateText();
        }
        return newText;
    }

    private function generateText():Void {
        for (letter in letters) {
            remove(letter);
            letter.destroy();
        }
        letters = [];

        var xPos:Float = 0;
        var yPos:Float = 0;
        var spaceWidth:Float = 40;

        var path = 'assets/images/ui/alphabet';
        if (!AssetResolver.exists('$path.xml')) return;
        
        var frames = FlxAtlasFrames.fromSparrow('$path.png', '$path.xml');

        for (i in 0...text.length) {
            var char = text.charAt(i);
            
            if (char == " ") {
                xPos += spaceWidth;
                continue;
            }
            
            if (char == "\n") {
                xPos = 0;
                yPos += 60;
                continue;
            }

            var letterSprite = new FlxSprite(xPos, yPos);
            letterSprite.frames = frames;
            
            var prefix = getPrefix(char, isBold);
            letterSprite.animation.addByPrefix('idle', prefix, 24, true);
            letterSprite.animation.play('idle');
            letterSprite.updateHitbox();

            add(letterSprite);
            letters.push(letterSprite);

            xPos += letterSprite.width;
        }
    }

    private function getPrefix(char:String, bold:Bool):String {
        var lower = char.toLowerCase();
        var upper = char.toUpperCase();
        
        if (bold) {
            if (~/[a-z]/i.match(char)) return '$upper bold';
            return '$char bold';
        }
        
        if (~/[A-Z]/.match(char)) return '$upper capital';
        if (~/[a-z]/.match(char)) return '$lower lowercase';
        
        return switch (char) {
            case '.': 'period';
            case "'": 'apostrophe';
            case '?': 'question mark';
            case '!': 'exclamation point';
            case ',': 'comma';
            case '-': 'dash';
            default: 'question mark';
        };
    }

    override public function update(elapsed:Float):Void {
        if (isMenuItem) {
            var scaledY = FlxMath.lerp(y, (targetY * 120) + 480, elapsed * 9);
            y = scaledY;
        }
        super.update(elapsed);
    }
}