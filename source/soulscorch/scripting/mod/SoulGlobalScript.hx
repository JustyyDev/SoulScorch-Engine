package soulscorch.scripting.mod;

import hscript.Interp;
import hscript.Parser;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.utils.Logger;

class SoulGlobalScript {
    public static var stateRedirects:Map<String, String> = new Map<String, String>();
    public static var interp:Interp;
    public static var isLoaded:Bool = false;

    public static function init():Void {
        stateRedirects.clear();
        isLoaded = false;

        var globalPath = AssetResolver.resolveFile("data/global.soul");
        if (globalPath == null) {
            globalPath = AssetResolver.resolveFile("global.soul");
        }

        if (globalPath == null) return;

        var code = AssetResolver.getText(globalPath);
        if (code.length == 0) return;

        try {
            var parser = new Parser();
            parser.allowTypes = true;
            parser.allowJSON = true;
            var program = parser.parseString(code);

            interp = new Interp();
            interp.variables.set("redirectState", function(originalState:String, targetScriptOrXml:String):Void {
                if (originalState != null && targetScriptOrXml != null) {
                    stateRedirects.set(StringTools.trim(originalState).toLowerCase(), StringTools.trim(targetScriptOrXml));
                    Logger.info('State redirected: $originalState -> $targetScriptOrXml', "global-script");
                }
            });

            interp.variables.set("trace", function(v:Dynamic):Void {
                Logger.info(Std.string(v), "global-script");
            });

            interp.execute(program);
            isLoaded = true;
            Logger.info('Loaded global script from: $globalPath', "global-script");
        } catch (e:Dynamic) {
            Logger.error('Failed executing global script: $e', "global-script");
        }
    }

    public static function getRedirect(stateName:String):Null<String> {
        if (stateName == null) return null;
        
        var clean:String = StringTools.trim(stateName).toLowerCase();
        if (stateRedirects.exists(clean)) {
            return stateRedirects.get(clean);
        }

        var testSoul = AssetResolver.resolveFile('data/ui/$stateName.soul');
        if (testSoul != null) return stateName;

        var testXml = AssetResolver.resolveFile('data/ui/$stateName.xml');
        if (testXml != null) return stateName;

        return null;
    }
}