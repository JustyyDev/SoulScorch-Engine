package soulscorch.ui.hud;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
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
    private static var glyphPrefixCache:Map<String, String> = new Map<String, String>();

    // Cached rendered fallback glyphs (avoids re-rendering FlxText on every character).
    private static var fallbackCache:Map<String, FlxGraphic> = new Map<String, FlxGraphic>();
    // Characters cycled through during the scramble/typewriter intro effect.
    public static var scrambleChars:String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#@%&*?!$";

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
                if (cachedBoldFrames == null) cachedBoldFrames = Paths.getSparrowAtlas("alphabet");
            }
            this.frames = cachedBoldFrames;
        } else {
            if (cachedFrames == null) {
                cachedFrames = Paths.getSparrowAtlas("ui/alphabet");
                if (cachedFrames == null) cachedFrames = Paths.getSparrowAtlas("alphabet");
                if (cachedFrames == null) cachedFrames = Paths.getSparrowAtlas("ui/alphabet-bold");
                if (cachedFrames == null) cachedFrames = Paths.getSparrowAtlas("alphabet-bold");
            }
            this.frames = cachedFrames;
        }
    }

    private function setupBold(char:String):Void {
        var upper = char.toUpperCase();
        var lower = char.toLowerCase();

        var candidates:Array<String> = switch (char) {
            case "&": ["& bold", "&", "character-ampersand", "ampersand bold"];
            case "<": ["< bold", "<", "character-anglebracket-left"];
            case ">": ["> bold", ">", "character-anglebracket-right"];
            case "@": ["@ bold", "@", "character-at"];
            case "\\": ["\\ bold", "\\", "character-backslash"];
            case "/": ["/ bold", "/", "character-slash"];
            case ":": [": bold", ":", "character-colon"];
            case ",": [", bold", ",", "character-comma"];
            case "$": ["$ bold", "$", "character-dollar"];
            case "\"", "“", "”": ["\" bold", "\"", "character-doublequote"];
            case "=": ["= bold", "=", "character-equal"];
            case "!": ["! bold", "!", "exclamation bold", "character-exclamationmark"];
            case "-": ["- bold", "-", "dash bold", "character-hyphen", "character-minus"];
            case "_": ["_ bold", "_", "character-underscore"];
            case "%": ["% bold", "%", "character-percent"];
            case ".": [". bold", ".", "period bold", "character-period"];
            case "+": ["+ bold", "+", "character-plus"];
            case "#": ["# bold", "#", "hashtag bold", "character-pound"];
            case "?": ["? bold", "?", "question bold", "character-questionmark"];
            case "(": ["( bold", "(", "character-roundbracket-left"];
            case ")": [") bold", ")", "character-roundbracket-right"];
            case ";": ["; bold", ";", "character-semicolon"];
            case "'", "’": ["' bold", "'", "apostrophe bold", "character-singlequote"];
            case "[": ["[ bold", "[", "character-squarebracket-left"];
            case "]": ["] bold", "]", "character-squarebracket-right"];
            case "*": ["* bold", "*", "character-asterisk"];
            default:
                if (isNumber(char)) {
                    var idx = Std.parseInt(char);
                    ['$char bold', char, '$upper bold', "character-" + numberWords[idx], numberWords[idx] + " bold"];
                } else {
                    ['$upper bold', '$char bold', '$lower bold', upper, "character-" + lower];
                }
        };

        isValid = tryAddAnimation(candidates);
    }

    private function setupNormal(char:String):Void {
        var isLower = (char == char.toLowerCase() && isAlpha(char));
        var upper = char.toUpperCase();
        var lower = char.toLowerCase();

        var candidates:Array<String> = switch (char) {
            case "&": ["&", "ampersand", "character-ampersand"];
            case "<": ["<", "character-anglebracket-left"];
            case ">": [">", "character-anglebracket-right"];
            case "@": ["@", "character-at"];
            case "\\": ["\\", "character-backslash"];
            case "/": ["/", "character-slash"];
            case ":": [":", "character-colon"];
            case ",": [",", "comma", "character-comma"];
            case "$": ["$", "character-dollar"];
            case "\"": ["\"", "character-doublequote-start", "character-doublequote"];
            case "=": ["=", "character-equal"];
            case "!": ["!", "exclamation point", "character-exclamationmark"];
            case "-": ["-", "dash", "character-minus", "character-hyphen"];
            case "_": ["_", "character-underscore"];
            case "%": ["%", "character-percent"];
            case ".": [".", "period", "character-period"];
            case "+": ["+", "character-plus"];
            case "#": ["#", "hashtag", "character-pound"];
            case "?": ["?", "question mark", "character-questionmark"];
            case "(": ["(", "character-roundbracket-left"];
            case ")": [")", "character-roundbracket-right"];
            case ";": [";", "character-semicolon"];
            case "'", "’": ["'", "apostrophe", "character-singlequote"];
            case "[": ["[", "character-squarebracket-left"];
            case "]": ["]", "character-squarebracket-right"];
            case "*": ["*", "character-asterisk"];
            default:
                if (isAlpha(char)) {
                    var casing = isLower ? "lowercase" : "capital";
                    [
                        '$char $casing',
                        '$char lowercase',
                        '$char capital',
                        '$casing $char',
                        'character-$lower-$casing',
                        'character-$lower',
                        char,
                        upper,
                        lower
                    ];
                } else if (isNumber(char)) {
                    var idx = Std.parseInt(char);
                    [char, "character-" + numberWords[idx], numberWords[idx]];
                } else {
                    [char, 'character-$lower'];
                }
        };

        isValid = tryAddAnimation(candidates);
    }

    private function tryAddAnimation(targetPrefixes:Array<String>):Bool {
        if (frames == null || frames.frames == null) return false;

        var cacheBase = isBold ? "b:" : "n:";

        for (target in targetPrefixes) {
            var targetTrimmed = target.trim().toLowerCase();
            var cacheKey = cacheBase + targetTrimmed;
            var cachedPrefix = glyphPrefixCache.get(cacheKey);
            if (cachedPrefix != null) {
                animation.addByPrefix("idle", cachedPrefix, 24, false);
                var anim = animation.getByName("idle");
                if (anim != null && anim.numFrames > 0) {
                    animation.play("idle");
                    return true;
                }
            }
        }

        for (target in targetPrefixes) {
            var targetTrimmed = target.trim().toLowerCase();

            for (f in frames.frames) {
                if (f.name == null) continue;

                var frameClean = f.name.trim();
                // Strip trailing frame numbers (e.g. "A bold 0000" -> "A bold")
                var prefixMatch = ~/[0-9]+$/;
                var baseName = prefixMatch.replace(frameClean, "").trim().toLowerCase();

                if (baseName == targetTrimmed) {
                    var resolvedPrefix = prefixMatch.replace(frameClean, "").trim();
                    glyphPrefixCache.set(cacheBase + targetTrimmed, resolvedPrefix);
                    // Fix: Set animated to FALSE so it displays as a single static character glyph
                    animation.addByPrefix("idle", resolvedPrefix, 24, false);
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
        var cacheKey = (bold ? "b_" : "n_") + char;
        if (fallbackCache.exists(cacheKey) && fallbackCache.get(cacheKey) != null) {
            loadGraphic(fallbackCache.get(cacheKey));
            isValid = true;
            return;
        }

        var size:Int = bold ? 48 : 36;
        var renderText = new FlxText(0, 0, 0, char, size);
        renderText.setFormat(Paths.font("vcr"), size, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
        renderText.borderSize = 2;
        renderText.drawFrame(true);

        if (renderText.framePixels != null) {
            loadGraphic(renderText.framePixels);
            if (graphic != null && !fallbackCache.exists(cacheKey)) {
                fallbackCache.set(cacheKey, graphic);
            }
        } else {
            makeGraphic(Std.int(Math.max(24, size * 0.6)), size, FlxColor.TRANSPARENT);
        }

        renderText.destroy();
        isValid = true;
    }

    // Reconfigure this sprite to display a different character WITHOUT allocating a new object.
    public function setCharacter(char:String, bold:Bool = false):Void {
        this.character = char;
        this.isBold = bold;
        animation.destroyAnimations();

        // A fallback glyph replaces this sprite's atlas frames. Restore the
        // requested atlas before reusing the pooled character.
        loadAtlasFrames(bold);
        isValid = false;
        if (frames == null) {
            createFallbackCharacter(char, bold);
            return;
        }
        if (bold) setupBold(char); else setupNormal(char);
        if (!isValid) createFallbackCharacter(char, bold);
        scale.set(0.85, 0.85);
        updateHitbox();
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
    private var _rowLetters:Array<Array<AlphaCharacter>> = [[]];

    public var isTyping:Bool = false;
    public var typingSpeed:Float = 0.05;
    public var typingSound:String = "scrollMenu";
    public var onTypingComplete:Void->Void = null;

    private var typingTimer:FlxTimer;
    private var fullTextBuffer:String = "";
    private var visibleCharCount:Int = 0;
    private var letterTextIndices:Array<Int> = [];

    public static inline var X_SPACING:Float = 2.0;
    public static inline var Y_SPACING:Float = 75.0;
    public static inline var SPACE_WIDTH:Float = 28.0;

    public function new(x:Float, y:Float, text:String = "", bold:Bool = false) {
        super(x, y);
        this.bold = bold;
        this.trackerOffset = FlxPoint.get(0, 0);
        this.text = text != null ? text : "";
    }

    public function set_text(newText:String):String {
        newText = newText != null ? newText : "";

        var wasTyping = isTyping;
        if (typingTimer != null) {
            typingTimer.cancel();
            typingTimer.destroy();
            typingTimer = null;
        }
        isTyping = false;
        fullTextBuffer = "";
        visibleCharCount = 0;
        letterTextIndices = [];
        _rowLetters = [[]];

        // Rebuild even when the string is unchanged if a scramble was active,
        // because the visible glyphs may still contain temporary characters.
        if (newText == text && !wasTyping) return text;
        text = newText;
        createAlphabet(text);
        return text;
    }

    // The "cool" randomized character intro. Reuses the existing letter sprites and only
    // swaps glyphs on a timer, so it never allocates or destroys sprites per frame.
    public function scrambleTo(newText:String, ?speed:Float = 0.022):Void {
        newText = newText != null ? newText : "";
        if (typingTimer != null) {
            typingTimer.cancel();
            typingTimer.destroy();
            typingTimer = null;
        }
        isTyping = true;
        fullTextBuffer = newText;
        visibleCharCount = 0;
        text = newText;
        createAlphabet(newText);

        if (newText.length == 0) {
            isTyping = false;
            if (onTypingComplete != null) onTypingComplete();
            return;
        }

        updateScramble();
        typingTimer = new FlxTimer().start(speed, function(tmr:FlxTimer) {
            visibleCharCount++;
            updateScramble();
            if (visibleCharCount >= newText.length) {
                isTyping = false;
                if (typingTimer != null) {
                    typingTimer.destroy();
                    typingTimer = null;
                }
                if (onTypingComplete != null) onTypingComplete();
            }
        }, newText.length);
    }

    private function updateScramble():Void {
        for (i in 0...letters.length) {
            if (i >= letterTextIndices.length) {
                break;
            }
            var letter = letters[i];
            var textIndex = letterTextIndices[i];
            if (textIndex < visibleCharCount) {
                letter.visible = true;
                // Only update the newly revealed glyph; settled glyphs stay untouched.
                if (textIndex == visibleCharCount - 1 || visibleCharCount >= fullTextBuffer.length) {
                    letter.setCharacter(fullTextBuffer.charAt(textIndex), bold);
                }
            } else {
                var rc = AlphaCharacter.scrambleChars.charAt(FlxG.random.int(0, AlphaCharacter.scrambleChars.length - 1));
                letter.visible = true;
                letter.setCharacter(rc, bold);
            }
        }
        // Re-align once the reveal completes so centered/right text settles cleanly.
        if (visibleCharCount >= fullTextBuffer.length && _rowLetters != null) {
            applyAlignment(_rowLetters);
        }
    }

    public function clearLetters():Void {
        while (letters.length > 0) {
            var letter = letters.pop();
            remove(letter, true);
            letter.destroy();
        }
        letterTextIndices = [];
        rows = 0;
    }

    private function createAlphabet(targetText:String):Void {
        if (targetText == null) targetText = "";

        // Rebuild from a clean slate so pooled menu titles cannot retain stale
        // letter sprites, rows, or timer state from a previous string.
        clearLetters();
        _rowLetters = [[]];
        fullTextBuffer = targetText;
        visibleCharCount = 0;

        var curX:Float = 0;
        var curY:Float = 0;
        var rowLetters:Array<Array<AlphaCharacter>> = [[]];
        var nextIndices:Array<Int> = [];
        var usedLetters:Int = 0;
        rows = 0;

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

            var letter:AlphaCharacter = null;
            if (usedLetters < letters.length) {
                letter = letters[usedLetters];
                if (letter.character != char || letter.isBold != bold) {
                    letter.setCharacter(char, bold);
                }
                letter.visible = true;
            } else {
                letter = new AlphaCharacter(curX, curY, char, bold);
                letters.push(letter);
                add(letter);
            }

            letter.setPosition(curX, curY);
            letter.row = rows;
            letter.alpha = this.alpha;
            letter.color = this.color;
            letter.letterOffset.x = curX;
            rowLetters[rows].push(letter);
            nextIndices.push(i);
            usedLetters++;

            curX += letter.width + X_SPACING;
        }

        while (letters.length > usedLetters) {
            var extra = letters.pop();
            remove(extra, true);
            extra.destroy();
        }

        letterTextIndices = nextIndices;

        _rowLetters = rowLetters;
        applyAlignment(rowLetters);
    }

    private function applyAlignment(rowLetters:Array<Array<AlphaCharacter>>):Void {
        if (alignment == LEFT) return;

        for (row in rowLetters) {
            if (row.length == 0) continue;

            var rowWidth:Float = (row[row.length - 1].letterOffset.x + row[row.length - 1].width) - row[0].letterOffset.x;
            var offset:Float = (alignment == CENTER) ? -(rowWidth * 0.5) : -rowWidth;

            for (letter in row) {
                letter.x = letter.letterOffset.x + offset;
            }
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
        if (isMenuItem && changeX && changeY && tracker == null) {
            // If FreeplayState is already controlling x, y and targetY lerp directly,
            // skip the redundant duplicate lerp calculation here.
            super.update(elapsed);
            return;
        }

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