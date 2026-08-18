package soulscorch.ui.hud;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.util.FlxColor;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;

enum abstract Alignment(String) from String to String {
    var LEFT = "left";
    var CENTER = "center";
    var RIGHT = "right";
}

class AlphaCharacter extends FlxSprite {
    public static var cachedFrames:FlxAtlasFrames = null;
    public static var cachedBoldFrames:FlxAtlasFrames = null;

    public var character:String = "";
    public var row:Int = 0;

    public function new(x:Float, y:Float, char:String, bold:Bool = false) {
        super(x, y);
        this.character = char;
        antialiasing = true;

        var imageKey = bold ? "ui/alphabet-bold" : "ui/alphabet";
        
        // Direct asset resolution fallback check
        var xmlPath = Paths.xml(imageKey);
        var pngPath = Paths.image(imageKey);

        if (cachedFrames == null && !bold) {
            cachedFrames = FlxAtlasFrames.fromSparrow(pngPath, xmlPath);
        } else if (cachedBoldFrames == null && bold) {
            cachedBoldFrames = FlxAtlasFrames.fromSparrow(pngPath, xmlPath);
        }

        this.frames = bold ? cachedBoldFrames : cachedFrames;

        if (this.frames == null) {
            // Absolute fallback to standard asset paths if 'ui/' prefix fails
            var altXml = bold ? Paths.xml("alphabet-bold") : Paths.xml("alphabet");
            var altPng = bold ? Paths.image("alphabet-bold") : Paths.image("alphabet");
            this.frames = FlxAtlasFrames.fromSparrow(altPng, altXml);
        }

        if (this.frames == null) {
            makeGraphic(24, 38, FlxColor.TRANSPARENT);
            return;
        }

        if (bold) {
            setupBold(char);
        } else {
            setupNormal(char);
        }

        updateHitbox();
    }

    private function setupBold(char:String):Void {
        var clean = char.toUpperCase();
        var added:Bool = false;

        switch (clean) {
            case ".":
                added = tryAddPrefix(["period bold", "bold period", "period0", "."]);
            case "'":
                added = tryAddPrefix(["apostrophe bold", "bold apostrophe", "apostrophe0", "'"]);
            case "?":
                added = tryAddPrefix(["question bold", "bold question", "question0", "?"]);
            case "!":
                added = tryAddPrefix(["exclamation bold", "bold exclamation", "exclamation0", "!"]);
            case "-":
                added = tryAddPrefix(["dash bold", "bold dash", "dash0", "-"]);
            case "/":
                added = tryAddPrefix(["forward slash bold", "slash bold", "bold slash", "/"]);
            default:
                added = tryAddPrefix([
                    clean + " bold",
                    "bold " + clean,
                    clean + "0",
                    clean + " uppercase",
                    clean
                ]);
        }

        if (!added) {
            makeGraphic(24, 38, FlxColor.TRANSPARENT);
        }
    }

    private function setupNormal(char:String):Void {
        var added:Bool = false;
        var isLower:Bool = (char == char.toLowerCase());

        switch (char) {
            case ".":
                added = tryAddPrefix(["period", "period0"]);
            case "'":
                added = tryAddPrefix(["apostrophe", "apostrophe0"]);
            case "?":
                added = tryAddPrefix(["question mark", "question", "question0"]);
            case "!":
                added = tryAddPrefix(["exclamation point", "exclamation", "exclamation0"]);
            case ",":
                added = tryAddPrefix(["comma", "comma0"]);
            case "-":
                added = tryAddPrefix(["dash", "dash0"]);
            default:
                if (isAlpha(char)) {
                    var caseSuffix = isLower ? "lowercase" : "uppercase";
                    added = tryAddPrefix([
                        char + " " + caseSuffix,
                        char + caseSuffix,
                        char + (isLower ? " lower" : " upper"),
                        char + "0",
                        char
                    ]);
                } else if (isNumber(char)) {
                    added = tryAddPrefix([char + "0", char, "number " + char]);
                } else {
                    added = tryAddPrefix([char, char + "0"]);
                }
        }

        if (!added) {
            makeGraphic(24, 38, FlxColor.TRANSPARENT);
        }
    }

    private function tryAddPrefix(prefixes:Array<String>):Bool {
        if (frames == null || frames.frames == null) return false;

        for (p in prefixes) {
            for (f in frames.frames) {
                if (f.name != null && (f.name == p || StringTools.startsWith(f.name, p))) {
                    animation.addByPrefix("anim", f.name, 24, true);
                    animation.play("anim");
                    return true;
                }
            }
        }
        return false;
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
        this.text = text != null ? text : "";
    }

    private function set_text(newText:String):String {
        text = newText != null ? newText : "";
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
            var lerpVal = Math.exp(-elapsed * 10.2);

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