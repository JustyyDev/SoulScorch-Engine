package soulscorch.ui;

import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxSpriteGroup;
import soulscorch.assets.AssetResolver;
import soulscorch.modding.ModManager;
#if sys
import sys.FileSystem;
#end

class Alphabet extends FlxSpriteGroup {
    private static var frameCache:Map<String, FlxAtlasFrames> = new Map();
    private static var nameSetCache:Map<String, Map<String, Bool>> = new Map();

    public var text(default, set):String = "";
    public var isBold(default, set):Bool = false;
    public var scaleMultiplier(default, set):Float = 1.0;
    public var letterSpacing:Float = 2.0;
    public var lineHeight:Float = 64.0;
    public var kerning:Map<String, Float> = new Map();

    public function new(x:Float, y:Float, text:String, isBold:Bool = false) {
        super(x, y);
        this.isBold = isBold;
        this.text = text == null ? "" : text;
        reloadAlphabet();
    }

    private function set_text(value:String):String {
        text = value == null ? "" : value;
        if (members != null) reloadAlphabet();
        return text;
    }

    private function set_isBold(value:Bool):Bool {
        isBold = value;
        if (members != null && text != null) reloadAlphabet();
        return value;
    }

    private function set_scaleMultiplier(value:Float):Float {
        scaleMultiplier = Math.max(0.05, value);
        if (members != null && text != null) reloadAlphabet();
        return scaleMultiplier;
    }

    public function reloadAlphabet():Void {
        clear();
        var xPos:Float = 0.0;
        var yPos:Float = 0.0;
        var previous:String = "";
        var atlasKey:String = isBold ? "bold" : "regular";
        var atlas:FlxAtlasFrames = loadAtlas(atlasKey);
        var names:Map<String, Bool> = nameSetCache.get(atlasKey);

        for (character in text.split("")) {
            if (character == "\n") {
                xPos = 0.0;
                yPos += lineHeight * scaleMultiplier;
                previous = "";
                continue;
            }
            if (character == " ") {
                xPos += (isBold ? 30.0 : 24.0) * scaleMultiplier;
                previous = "";
                continue;
            }

            var prefix:String = symbolPrefix(character, isBold);
            var glyph:FlxSprite = new FlxSprite(xPos, yPos);
            var advance:Float = (isBold ? 38.0 : 32.0) * scaleMultiplier;
            var valid:Bool = atlas != null && names != null && names.exists(prefix);
            if (valid) {
                glyph.frames = atlas;
                glyph.animation.addByPrefix("idle", prefix, 24, false);
                glyph.animation.play("idle");
                advance = Math.max(8.0, glyph.width + letterSpacing) * scaleMultiplier;
            } else {
                glyph.makeGraphic(Std.int(Math.max(8.0, advance)), Std.int(42.0 * scaleMultiplier), isBold ? 0xFF6BE7FF : 0xFFB8D9FF);
            }
            glyph.scale.set(scaleMultiplier, scaleMultiplier);
            glyph.updateHitbox();
            glyph.y += Math.max(0.0, lineHeight * scaleMultiplier - glyph.height) * 0.5;
            add(glyph);
            xPos += advance + kerningValue(previous, character) * scaleMultiplier;
            previous = character;
        }
    }

    private function loadAtlas(key:String):FlxAtlasFrames {
        if (frameCache.exists(key)) return frameCache.get(key);
        var base:String = isBold ? "alphabet-bold" : "alphabet";
        var imagePath:String = ModManager.getPath("images/menus/" + base + ".png");
        var xmlPath:String = ModManager.getPath("images/menus/" + base + ".xml");
        #if sys
        if (imagePath == null || xmlPath == null || !FileSystem.exists(imagePath) || !FileSystem.exists(xmlPath)) return null;
        #end
        try {
            var xml:String = AssetResolver.getText(xmlPath);
            var frames:FlxAtlasFrames = FlxAtlasFrames.fromSparrow(imagePath, xml);
            frameCache.set(key, frames);
            nameSetCache.set(key, buildNameSet(xml));
            return frames;
        } catch (error:Dynamic) {
            return null;
        }
    }

    // Parses all name="..." attributes once so per-character lookups are O(1) instead of scanning the whole XML string.
    // Sparrow atlases store numbered animation frames per glyph (e.g. "character-a0000"), so the trailing digits are stripped
    // to recover the shared prefix used by symbolPrefix()/animation.addByPrefix().
    private static var trailingDigits:EReg = ~/[0-9]+$/;

    private static function buildNameSet(xml:String):Map<String, Bool> {
        var names:Map<String, Bool> = new Map();
        var nameRegex:EReg = ~/name="([^"]+)"/;
        var rest:String = xml;
        while (nameRegex.match(rest)) {
            names.set(trailingDigits.replace(nameRegex.matched(1), ""), true);
            rest = nameRegex.matchedRight();
        }
        return names;
    }

    private function kerningValue(previous:String, current:String):Float {
        if (previous == null || previous.length == 0) return 0.0;
        var pair:String = previous + current;
        return kerning.exists(pair) ? kerning.get(pair) : 0.0;
    }

    private static function symbolPrefix(character:String, bold:Bool):String {
        var lower:String = character.toLowerCase();
        var name:String = switch (character) {
            case ".": "period";
            case ",": "comma";
            case "?": "questionmark";
            case "!": "exclamationmark";
            case "0": "zero";
            case "1": "one";
            case "2": "two";
            case "3": "three";
            case "4": "four";
            case "5": "five";
            case "6": "six";
            case "7": "seven";
            case "8": "eight";
            case "9": "nine";
            case "+": "plus";
            case "-": "dash";
            case "=": "equals";
            case "&": "ampersand";
            case "<": "anglebracket-left";
            case ">": "anglebracket-right";
            case "(": "parenthesis-left";
            case ")": "parenthesis-right";
            case "[": "bracket-left";
            case "]": "bracket-right";
            case "/": "slash";
            case "\\": "backslash";
            case ":": "colon";
            case "'": "apostrophe";
            case '"': "quote";
            case "*": "asterisk";
            case "@": "at";
            case "#": "hash";
            case "$": "dollar";
            case "%": "percent";
            case "_": "underscore";
            default: lower;
        };
        if (bold) return "character-" + name;
        if (character >= "A" && character <= "Z") return "character-" + lower + "-capital";
        if (character >= "a" && character <= "z") return "character-" + lower + "-lowercase";
        return "character-" + name;
    }
}
