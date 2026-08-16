package soulscorch.backend.localization;

import flixel.text.FlxText;

class LocalizedText extends FlxText {
    public var localizationKey(default, set):String;
    public var tokens:Map<String, Dynamic> = new Map();
    public function new(x:Float, y:Float, width:Float, key:String, size:Int = 16) {
        super(x, y, width, "", size); localizationKey = key; LanguageManager.instance.onLanguageChanged(onLanguageChanged); refresh();
    }
    private function set_localizationKey(value:String):String { localizationKey = value == null ? "" : value; if (LanguageManager.instance != null) refresh(); return localizationKey; }
    public function refresh():Void if (LanguageManager.instance != null) text = LanguageManager.instance.get(localizationKey, tokens);
    private function onLanguageChanged(_language:String):Void refresh();
    override public function destroy():Void { if (LanguageManager.instance != null) LanguageManager.instance.offLanguageChanged(onLanguageChanged); super.destroy(); }
}
