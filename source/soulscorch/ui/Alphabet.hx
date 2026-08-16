package soulscorch.ui;

import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxSpriteGroup;
import soulscorch.assets.Paths;

class Alphabet extends FlxSpriteGroup {
    public var text:String = "";
    public var isBold:Bool = false;

    public function new(x:Float, y:Float, text:String, ?isBold:Bool = false) {
        super(x, y);
        this.text = text;
        this.isBold = isBold;
        reloadAlphabet();
    }

    public function reloadAlphabet():Void {
        // Clear existing letters if reloading
        clear();

        var xPos:Float = 0;
        var yPos:Float = 0;

        // Determine correct paths based on whether it's bold or regular font sheet
        var imagePath = isBold ? 'images/menus/alphabet-bold.png' : 'images/menus/alphabet.png';
        var xmlPath = isBold ? 'images/menus/alphabet-bold.xml' : 'images/menus/alphabet.xml';

        var resolvedImage = Paths.getPath(imagePath);
        var resolvedXml = Paths.getPath(xmlPath);

        #if sys
        if (!sys.FileSystem.exists(resolvedImage) || !sys.FileSystem.exists(resolvedXml)) {
            // Fallback check for root images directory if menus folder is bypassed
            resolvedImage = Paths.getPath(isBold ? 'images/alphabet-bold.png' : 'images/alphabet.png');
            resolvedXml = Paths.getPath(isBold ? 'images/alphabet-bold.xml' : 'images/alphabet.xml');
        }
        #end

        var dadText:Array<String> = text.split("");

        for (character in dadText) {
            if (character == "\n") {
                xPos = 0;
                yPos += 40;
                continue;
            }

            if (character != " ") {
                var letter:FlxSprite = new FlxSprite(xPos, yPos);
                
                #if sys
                if (sys.FileSystem.exists(resolvedImage) && sys.FileSystem.exists(resolvedXml)) {
                    letter.frames = FlxAtlasFrames.fromSparrow(resolvedImage, resolvedXml);
                    letter.animation.addByPrefix('idle', character, 24);
                    letter.animation.play('idle');
                } else {
                    // Fallback block graphic if alphabet asset is entirely missing
                    letter.makeGraphic(20, 20, 0xFFFF00FF);
                }
                #end

                add(letter);
                xPos += 30; // Spacing adjustment per character
            } else {
                xPos += 20; // Space width
            }
        }
    }
}