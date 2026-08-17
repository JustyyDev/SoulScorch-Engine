package soulscorch.backend.localization;

import flixel.text.FlxText;
import flixel.util.FlxColor;

class LocalizedText extends FlxText {
    public var localizationKey(default, set):String;
    public var tokens:Map<String, Dynamic> = new Map();

    public function new(x:Float = 0, y:Float = 0, fieldWidth:Float = 0, key:String = "", size:Int = 16) {
        super(x, y, fieldWidth, "", size);
        this.localizationKey = key;
        LanguageManager.instance.onLanguageChanged(onLanguageChanged);
        refresh();
    }

    private function set_localizationKey(value:String):String {
        localizationKey = (value == null) ? "" : value;
        refresh();
        return localizationKey;
    }

    /**
     * Sets or updates a dynamic replacement token and refreshes the display.
     */
    public function setToken(tokenName:String, value:Dynamic):LocalizedText {
        tokens.set(tokenName, value);
        refresh();
        return this;
    }

    /**
     * Clears all replacement tokens and updates text.
     */
    public function clearTokens():LocalizedText {
        tokens.clear();
        refresh();
        return this;
    }

    public function refresh():Void {
        if (LanguageManager.instance != null && localizationKey.length > 0) {
            text = LanguageManager.instance.get(localizationKey, tokens);
        }
    }

    private function onLanguageChanged(_language:String):Void {
        refresh();
    }

    override public function destroy():Void {
        if (LanguageManager.instance != null) {
            LanguageManager.instance.offLanguageChanged(onLanguageChanged);
        }
        tokens.clear();
        super.destroy();
    }
}