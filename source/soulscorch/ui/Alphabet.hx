package soulscorch.ui;

import flixel.group.FlxSpriteGroup;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import soulscorch.assets.AssetHelper;

class AlphaCharacter extends FlxSprite {
    public static var alphabet:String = "abcdefghijklmnopqrstuvwxyz";
    public static var numbers:String = "1234567890";
    public static var symbols:String = "|~#$%()*+-:;<=>@[]^_.,'!?";

    public var row:Int = 0;

    public function new(x:Float, y:Float) {
        super(x, y);
        AssetHelper.loadSparrowSafely(this, "assets/images/alphabet.png", "assets/images/alphabet.xml");
        antialiasing = true;
    }

    public function createLetter(letter:String, isBold:Bool = false):Void {
        var letterLower = letter.toLowerCase();
        
        if (isBold) {
            if (alphabet.indexOf(letterLower) != -1) {
                animation.addByPrefix('letter', letter.toUpperCase() + " bold", 24);
            } else if (numbers.indexOf(letterLower) != -1 || symbols.indexOf(letterLower) != -1) {
                animation.addByPrefix('letter', letter + " bold", 24);
            }
        } else {
            if (alphabet.indexOf(letterLower) != -1) {
                if (letter == letter.toLowerCase()) {
                    animation.addByPrefix('letter', letter + " lowercase", 24);
                } else {
                    animation.addByPrefix('letter', letter + " uppercase", 24);
                }
            } else {
                animation.addByPrefix('letter', letter, 24);
            }
        }

        if (animation.getByName('letter') != null) {
            animation.play('letter');
            updateHitbox();
        }
    }
}

class Alphabet extends FlxSpriteGroup {
    public var text:String = "";
    public var isBold:Bool = false;
    public var spacing:Float = 20;

    public function new(x:Float, y:Float, text:String = "", isBold:Bool = false) {
        super(x, y);
        this.isBold = isBold;
        setText(text);
    }

    public function setText(newText:String):Void {
        clearLetters();
        this.text = newText;
        var curX:Float = 0;

        for (i in 0...newText.length) {
            var char = newText.charAt(i);
            if (char == " ") {
                curX += spacing * 1.5;
                continue;
            }

            var letter = new AlphaCharacter(curX, 0);
            letter.createLetter(char, isBold);
            add(letter);
            curX += letter.width + (isBold ? 2 : 4);
        }
    }

    public function clearLetters():Void {
        while (members.length > 0) {
            var member = members.pop();
            if (member != null) member.destroy();
        }
    }
}