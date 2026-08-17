package soulscorch.ui.hud;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.util.FlxColor;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.Paths;

enum abstract Alignment(String) from String to String {
    var LEFT = "left";
    var CENTER = "center";
    var RIGHT = "right";
}

class AlphaCharacter extends FlxSprite {
    public static inline var ALPHABET_SHEET:String = "ui/alphabet";

    public var character:String = "";
    public var row:Int = 0;

    public function new(x:Float, y:Float, char:String, bold:Bool = false) {
        super(x, y);
        this.character = char;
        antialiasing = true;

        AssetHelper.loadSparrowSafely(this, ALPHABET_SHEET);

        if (bold) {
            createBoldLetter(char);
        } else {
            createLetter(char);
        }

        updateHitbox();
    }

    private function createBoldLetter(char:String):Void {
        var cleanChar = char.toUpperCase();
        switch (cleanChar) {
            case ".":
                animation.addByPrefix("letter", "period bold", 24);
            case "'":
                animation.addByPrefix("letter", "apostrophe bold", 24);
            case "?":
                animation.addByPrefix("letter", "question bold", 24);
            case "!":
                animation.addByPrefix("letter", "exclamation bold", 24);
            case "-":
                animation.addByPrefix("letter", "dash bold", 24);
            default:
                if (isAlpha(cleanChar)) {
                    animation.addByPrefix("letter", cleanChar + " bold", 24);
                } else if (isNumber(cleanChar)) {
                    animation.addByPrefix("letter", "bold " + cleanChar, 24);
                } else {
                    animation.addByPrefix("letter", "bold " + cleanChar, 24);
                }
        }
        animation.play("letter");
    }

    private function createLetter(char:String):Void {
        switch (char) {
            case ".":
                animation.addByPrefix("letter", "period", 24);
            case "'":
                animation.addByPrefix("letter", "apostrophe", 24);
            case "?":
                animation.addByPrefix("letter", "question mark", 24);
            case "!":
                animation.addByPrefix("letter", "exclamation point", 24);
            case ",":
                animation.addByPrefix("letter", "comma", 24);
            case "-":
                animation.addByPrefix("letter", "dash", 24);
            default:
                if (isAlpha(char)) {
                    var isLower = (char == char.toLowerCase());
                    animation.addByPrefix("letter", char + " " + (isLower ? "lowercase" : "uppercase"), 24);
                } else if (isNumber(char)) {
                    animation.addByPrefix("letter", char, 24);
                } else {
                    animation.addByPrefix("letter", char, 24);
                }
        }
        animation.play("letter");
    }

    private static inline function isAlpha(char:String):Bool {
        var code = StringTools.fastCodeAt(char, 0);
        return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
    }

    private static inline function isNumber(char:String):Bool {
        var code = StringTools.fastCodeAt(char, 0);
        return (code >= 48 && code <= 57);
    }
}

class Alphabet extends FlxSpriteGroup {
    public var text(default, set):String = "";
    public var isMenuItem:Bool = false;
    public var targetY:Float = 0;
    public var changeX:Bool = true;
    public var changeY:Bool = true;
    public var alignment:Alignment = LEFT;
    public var bold:Bool = false;

    public var letters:Array<AlphaCharacter> = [];
    public var rows:Int = 0;

    public static inline var X_SPACING:Float = 2.0;
    public static inline var Y_SPACING:Float = 60.0;
    public static inline var SPACE_WIDTH:Float = 28.0;

    public function new(x:Float, y:Float, text:String = "", bold:Bool = false) {
        super(x, y);
        this.bold = bold;
        this.text = text;
    }

    private function set_text(newText:String):String {
        text = newText;
        clearLetters();
        createAlphabet();
        return text;
    }

    private function clearLetters():Void {
        while (letters.length > 0) {
            var letter = letters.pop();
            remove(letter, true);
            letter.destroy();
        }
        rows = 0;
    }

    private function createAlphabet():Void {
        if (text == null || text.length == 0) return;

        var curX:Float = 0;
        var curY:Float = 0;
        var rowLetters:Array<Array<AlphaCharacter>> = [[]];

        for (i in 0...text.length) {
            var char = text.charAt(i);

            if (char == "\n") {
                curX = 0;
                curY += Y_SPACING;
                rows++;
                rowLetters.push([]);
                continue;
            }

            if (char == " ") {
                curX += SPACE_WIDTH;
                continue;
            }

            var letter = new AlphaCharacter(curX, curY, char, bold);
            letter.row = rows;
            letters.push(letter);
            rowLetters[rows].push(letter);
            add(letter);

            curX += letter.width + X_SPACING;
        }

        applyAlignment(rowLetters);
    }

    private function applyAlignment(rowLetters:Array<Array<AlphaCharacter>>):Void {
        if (alignment == LEFT) return;

        for (row in rowLetters) {
            if (row.length == 0) continue;

            var rowWidth:Float = (row[row.length - 1].x + row[row.length - 1].width) - row[0].x;
            var offset:Float = (alignment == CENTER) ? -(rowWidth * 0.5) : -rowWidth;

            for (letter in row) {
                letter.x += offset;
            }
        }
    }

    override public function update(elapsed:Float):Void {
        if (isMenuItem) {
            var scaledY = FlxMath.remapToRange(targetY, 0, 1, 0, 1.3);
            var lerpVal = Math.exp(-elapsed * 9.6);

            if (changeX) {
                x = FlxMath.lerp((targetY * 20) + 90, x, lerpVal);
            }
            if (changeY) {
                y = FlxMath.lerp((scaledY * 120) + (FlxG.height * 0.48), y, lerpVal);
            }
        }

        super.update(elapsed);
    }
}