package soulscorch.ui.hud;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.Paths;

using StringTools;

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
    public var isValid:Bool = false;
    public var isBold:Bool = false;
    public var letterOffset:FlxPoint;

    private static var numberWords:Array<String> = [
        "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"
    ];

    public function new(x:Float, y:Float, char:String, bold:Bool = false) {
        super(x, y);
        this.character = char;
        this.isBold = bold;
        this.letterOffset = FlxPoint.get(0, 0);
        antialiasing = true;

        loadAtlasFrames(bold);

        if (this.frames == null) {
            createFallbackCharacter(char, bold);
            return;
        }

        if (bold) {
            setupBold(char);
        } else {
            setupNormal(char);
        }

        if (!isValid) {
            createFallbackCharacter(char, bold);
        }

        scale.set(0.85, 0.85);
        updateHitbox();
    }

    private function loadAtlasFrames(bold:Bool):Void {
        if (bold) {
            if (cachedBoldFrames == null) {
                cachedBoldFrames = Paths.getSparrowAtlas("ui/alphabet-bold");
                if (cachedBoldFrames == null) cachedBoldFrames = Paths.getSparrowAtlas("alphabet-bold");
                if (cachedBoldFrames == null) cachedBoldFrames = Paths.getSparrowAtlas("ui/alphabet");
            }
            this.frames = cachedBoldFrames;
        } else {
            if (cachedFrames == null) {
                cachedFrames = Paths.getSparrowAtlas("ui/alphabet");
                if (cachedFrames == null) cachedFrames = Paths.getSparrowAtlas("alphabet");
                if (cachedFrames == null) cachedFrames = Paths.getSparrowAtlas("ui/alphabet-bold");
            }
            this.frames = cachedFrames;
        }
    }

    private function setupBold(char:String):Void {
        var lower = char.toLowerCase();
        var candidates:Array<String> = switch (char) {
            case "&": ["character-ampersand"];
            case "<": ["character-anglebracket-left"];
            case ">": ["character-anglebracket-right"];
            case "@": ["character-at"];
            case "\\": ["character-backslash"];
            case "/": ["character-slash"];
            case "`": ["character-backtick"];
            case "^": ["character-caret"];
            case ":": ["character-colon"];
            case ",": ["character-comma"];
            case "{": ["character-curlybracket-left"];
            case "}": ["character-curlybracket-right"];
            case "$": ["character-dollar"];
            case "\"", "“", "”": ["character-doublequote", "character-doublequote-alt"];
            case "=": ["character-equal"];
            case "!": ["character-exclamationmark", "character-exclamationmark-alt"];
            case "-": ["character-hyphen", "character-minus"];
            case "_": ["character-underscore"];
            case "%": ["character-percent"];
            case ".": ["character-period"];
            case "+": ["character-plus"];
            case "#": ["character-pound"];
            case "?": ["character-questionmark", "character-questionmark-alt"];
            case "(": ["character-roundbracket-left"];
            case ")": ["character-roundbracket-right"];
            case ";": ["character-semicolon"];
            case "'", "’": ["character-singlequote", "character-apostophe"];
            case "[": ["character-squarebracket-left"];
            case "]": ["character-squarebracket-right"];
            case "~": ["character-tilde"];
            case "|": ["character-verticalbar"];
            case "*": ["character-asterisk", "character-multiply"];
            default:
                if (isNumber(char)) {
                    var idx = Std.parseInt(char);
                    ["character-" + numberWords[idx]];
                } else if (isAlpha(char)) {
                    ["character-" + lower];
                } else {
                    ["character-" + lower];
                }
        };

        isValid = tryAddAnimation(candidates);
    }

    private function setupNormal(char:String):Void {
        var isLower = (char == char.toLowerCase());
        var lower = char.toLowerCase();
        var candidates:Array<String> = switch (char) {
            case "&": ["character-ampersand"];
            case "<": ["character-anglebracket-left"];
            case ">": ["character-anglebracket-right"];
            case "@": ["character-at"];
            case "\\": ["character-backslash"];
            case "/": ["character-slash"];
            case "`": ["character-backtick"];
            case "^": ["character-caret"];
            case ":": ["character-colon"];
            case ",": ["character-comma"];
            case "{": ["character-curlybracket-left"];
            case "}": ["character-curlybracket-right"];
            case "$": ["character-dollar"];
            case "\"": ["character-doublequote-start", "character-doublequote-end"];
            case "=": ["character-equal"];
            case "!": ["character-exclamationmark"];
            case "-": ["character-minus", "character-hyphen"];
            case "_": ["character-underscore"];
            case "%": ["character-percent"];
            case ".": ["character-period"];
            case "+": ["character-plus"];
            case "#": ["character-pound"];
            case "?": ["character-questionmark"];
            case "(": ["character-roundbracket-left"];
            case ")": ["character-roundbracket-right"];
            case ";": ["character-semicolon"];
            case "'", "’": ["character-singlequote"];
            case "[": ["character-squarebracket-left"];
            case "]": ["character-squarebracket-right"];
            case "~": ["character-tilde"];
            case "|": ["character-verticalbar"];
            case "*": ["character-asterisk", "character-multiply"];
            default:
                if (isAlpha(char)) {
                    var casing = isLower ? "lowercase" : "capital";
                    ["character-" + lower + "-" + casing, "character-" + lower];
                } else if (isNumber(char)) {
                    var idx = Std.parseInt(char);
                    ["character-" + numberWords[idx]];
                } else {
                    ["character-" + lower];
                }
        };

        isValid = tryAddAnimation(candidates);
    }

    private function tryAddAnimation(targetPrefixes:Array<String>):Bool {
        if (frames == null || frames.frames == null) return false;

        var reg = ~/[0-9]+$/;

        for (target in targetPrefixes) {
            var targetLower = target.toLowerCase();

            for (f in frames.frames) {
                if (f.name == null) continue;

                var basePrefix = reg.replace(f.name, "");
                if (basePrefix.toLowerCase() == targetLower) {
                    animation.addByPrefix("idle", basePrefix, 24, true);
                    if (animation.getByName("idle") != null && animation.getByName("idle").numFrames > 0) {
                        animation.play("idle");
                        return true;
                    }
                }
            }
        }
        return false;
    }

    private function createFallbackCharacter(char:String, bold:Bool):Void {
        var size:Int = bold ? 48 : 36;
        var renderText = new FlxText(0, 0, 0, char, size);
        renderText.setFormat(Paths.font("vcr"), size, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
        renderText.borderSize = 2;
        renderText.drawFrame(true);

        if (renderText.framePixels != null) {
            loadGraphic(renderText.framePixels);
        } else {
            makeGraphic(Std.int(Math.max(24, size * 0.6)), size, FlxColor.TRANSPARENT);
        }

        renderText.destroy();
        isValid = true;
    }

    private static inline function isAlpha(char:String):Bool {
        var code = char.fastCodeAt(0);
        return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
    }

    private static inline function isNumber(char:String):Bool {
        var code = char.fastCodeAt(0);
        return (code >= 48 && code <= 57);
    }

    override public function destroy():Void {
        if (letterOffset != null) {
            letterOffset.put();
            letterOffset = null;
        }
        super.destroy();
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

    public var xAdd:Float = 0;
    public var yAdd:Float = 0;
    public var xMult:Float = 20;
    public var yMult:Float = 120;

    public var tracker:FlxSprite = null;
    public var trackerOffset:FlxPoint;

    public var letters:Array<AlphaCharacter> = [];
    public var rows:Int = 0;

    public var isTyping:Bool = false;
    public var typingSpeed:Float = 0.05;
    public var typingSound:String = "scrollMenu";
    public var onTypingComplete:Void->Void = null;

    private var typingTimer:FlxTimer;
    private var fullTextBuffer:String = "";
    private var visibleCharCount:Int = 0;

    public static inline var X_SPACING:Float = 4.0;
    public static inline var Y_SPACING:Float = 75.0;
    public static inline var SPACE_WIDTH:Float = 36.0;

    public function new(x:Float, y:Float, text:String = "", bold:Bool = false) {
        super(x, y);
        this.bold = bold;
        this.trackerOffset = FlxPoint.get(0, 0);
        this.text = text != null ? text : "";
    }

    public function set_text(newText:String):String {
        text = newText != null ? newText : "";
        if (!isTyping) {
            clearLetters();
            createAlphabet(text);
        }
        return text;
    }

    public function clearLetters():Void {
        while (letters.length > 0) {
            var letter = letters.pop();
            remove(letter, true);
            letter.destroy();
        }
        rows = 0;
    }

    private function createAlphabet(targetText:String):Void {
        if (targetText == null || targetText.length == 0) return;

        var curX:Float = 0;
        var curY:Float = 0;
        var rowLetters:Array<Array<AlphaCharacter>> = [[]];

        for (i in 0...targetText.length) {
            var char = targetText.charAt(i);

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
            letter.alpha = this.alpha;
            letter.color = this.color;
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

    public function startTyping(dialogue:String, speed:Float = 0.04, ?sound:String = "scrollMenu", ?onComplete:Void->Void):Void {
        isTyping = true;
        fullTextBuffer = dialogue;
        typingSpeed = speed;
        typingSound = sound;
        onTypingComplete = onComplete;
        visibleCharCount = 0;

        clearLetters();

        if (typingTimer != null) {
            typingTimer.cancel();
            typingTimer.destroy();
        }

        typingTimer = new FlxTimer().start(typingSpeed, onTypeTick, 0);
    }

    private function onTypeTick(timer:FlxTimer):Void {
        if (visibleCharCount < fullTextBuffer.length) {
            visibleCharCount++;
            var currentStr = fullTextBuffer.substr(0, visibleCharCount);
            clearLetters();
            createAlphabet(currentStr);

            if (typingSound != null && typingSound.length > 0 && visibleCharCount % 2 == 0) {
                AssetHelper.playSoundSafely(typingSound, 0.4);
            }
        } else {
            finishTyping();
        }
    }

    public function finishTyping():Void {
        if (typingTimer != null) {
            typingTimer.cancel();
            typingTimer.destroy();
            typingTimer = null;
        }
        isTyping = false;
        clearLetters();
        createAlphabet(fullTextBuffer);

        if (onTypingComplete != null) {
            onTypingComplete();
            onTypingComplete = null;
        }
    }

    public function snapToPosition():Void {
        if (isMenuItem) {
            var scaledY = FlxMath.remapToRange(targetY, 0, 1, 0, 1.3);
            if (changeX) x = (targetY * xMult) + 90 + xAdd;
            if (changeY) y = (scaledY * yMult) + (FlxG.height * 0.48) + yAdd;
        }
    }

    override public function update(elapsed:Float):Void {
        if (isMenuItem) {
            var scaledY = FlxMath.remapToRange(targetY, 0, 1, 0, 1.3);
            var lerpFactor = FlxMath.bound(elapsed * 9.6, 0, 1);

            if (changeX) {
                x = FlxMath.lerp(x, (targetY * xMult) + 90 + xAdd, lerpFactor);
            }
            if (changeY) {
                y = FlxMath.lerp(y, (scaledY * yMult) + (FlxG.height * 0.48) + yAdd, lerpFactor);
            }
        }

        if (tracker != null) {
            tracker.x = this.x + trackerOffset.x;
            tracker.y = this.y + trackerOffset.y;
            tracker.alpha = this.alpha;
            tracker.visible = this.visible;
        }

        super.update(elapsed);
    }

    override public function destroy():Void {
        if (typingTimer != null) {
            typingTimer.cancel();
            typingTimer.destroy();
            typingTimer = null;
        }
        if (trackerOffset != null) {
            trackerOffset.put();
            trackerOffset = null;
        }
        super.destroy();
    }
}